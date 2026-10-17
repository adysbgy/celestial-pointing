#!/usr/bin/env python3
"""Bukti non-vakuositas: uji pemilih palet HARUS merah saat sumbernya dimutasi.

Kenapa arah ini, bukan uji tambahan.

`NightPaletteSelector` (PointingKit) memindahkan keputusan palet mode malam
keluar dari `Apps/`, yang tidak pernah dibangun `swift-test.sh` di Linux.
Tapi memindahkan kode ke paket teruji **belum** berarti ia terjaga: uji yang
hanya memanggil fungsi dan mencocokkan hasil pada `UserDefaults` tiruan bisa
lulus untuk pemetaan yang terbalik, selama fixture-nya ikut terbalik. Yang
dibuktikan di sini adalah arah yang mudah hilang: **ujinya masih berbunyi
saat pemetaannya salah.**

Harness ini memutasi sumber produksinya di container yang sama dengan CI
(Docker Swift 6.0), menjalankan `SurfacePaletteTests` untuk tiap keadaan, dan
menuntut merah pada tiga pemetaan yang salah serta hijau pada pohon apa
adanya.

Penulisan & pemulihan lewat `mutasi_sumber`, sama seperti harness lain:

  * `require_clean_sources` menolak jalan bila sumber sudah menyimpang dari
    HEAD — kalau tidak, harness akan mengadopsi mutasi yang tertinggal
    sebagai «aslinya» dan melaporkan «pulih persis» atas dirinya sendiri;
  * `write_source` menulis atomik, jadi `swift test` hanya pernah melihat
    versi lama atau versi baru;
  * `restore_verified` membaca balik byte demi byte dan **melempar** bila
    tidak cocok.

Tanpa ketiganya, SIGKILL di tengah keadaan ketiga meninggalkan
`NightPaletteSelector.swift` termutasi, dan siklus berikutnya mengukur
keadaan yang tidak pernah ada.

Lingkungan: `swift` langsung, atau docker + image `swift:6.0`. Kalau tidak
ada keduanya, harness **berhenti** (exit 2) alih-alih melaporkan hijau atas
nol pembuktian.

Pakai: python3 Tools/bukti-mutasi-pemilih-palet.py
"""

from __future__ import annotations

import hashlib
import os
import shutil
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

SRC = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                   "NightPaletteSelector.swift")
TESTS = os.path.join(ROOT, "Packages", "PointingKit", "Tests",
                     "PointingKitTests", "SurfacePaletteTests.swift")

#: Jangkar pemetaan yang benar. Kalau ini hilang dari sumber, harness berhenti
#: daripada melaporkan "sesuai harapan" atas nol pembuktian.
ANCHOR = "isNightModeEnabled ? .night : .day"

RULE = "SurfacePaletteTests"

#: Jalur relatif, dipakai bentuk `(path, find, replace)`.
#:
#: **Kenapa bentuk ini, bukan `(label, pengganti, harus_merah)`.** Bentuk
#: ringkas itu terbaca di sini, tetapi `Tools/check-jangkar-harness.py` tidak
#: bisa memetik pasangan jangkar darinya: `_edit_pairs` membaca elemen pertama
#: tuple panjang-3 sebagai **jalur berkas**, dan label keadaan bukan jalur.
#: Akibatnya harness ini terhitung "memutasi sumber produksi tetapi
#: menyumbang nol jangkar", dan gerbang itu merah — bukan karena ada mutasi
#: bocor, melainkan karena bentuk datanya tidak dikenali pemeriksanya.
#: Gerbangnya **tidak** boleh dilonggarkan untuk menutupi itu (ia satu-satunya
#: yang mendeteksi mutasi tertinggal), jadi bentuk datanya yang disesuaikan.
SRC_REL = "Packages/PointingKit/Sources/PointingKit/NightPaletteSelector.swift"

#: (label, edit, harus_merah). `edit` = `None` (baseline) atau
#: `(path, find, replace)` — bentuk yang dikenali gerbang jangkar.
STATES = [
    ("baseline (kode apa adanya)", None, False),
    ("selalu .day", (SRC_REL, ANCHOR, ".day"), True),
    ("selalu .night", (SRC_REL, ANCHOR, ".night"), True),
    ("dibalik",
     (SRC_REL, ANCHOR, "!isNightModeEnabled ? .night : .day"), True),
    ("basil ulang (pulih)", None, False),
]


def run_tests() -> tuple[bool, str]:
    """Jalankan hanya uji palet, di lingkungan yang sama dengan CI.

    `--filter` dipakai supaya keadaan yang tidak dimaksud tidak ikut
    menentukan hasil: harness ini mengklaim tentang `SurfacePaletteTests`,
    bukan tentang seluruh paket (itu tugas `swift-test.sh`).
    """
    if shutil.which("swift"):
        cmd = ["swift", "test", "--package-path", "Packages/PointingKit",
               "--filter", RULE]
    else:
        cmd = ["sudo", "-n", "docker", "run", "--rm",
               "-v", f"{ROOT}:/src",
               "-w", "/src/Packages/PointingKit",
               "swift:6.0", "swift", "test", "--filter", RULE]
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                             timeout=1800)
    except subprocess.TimeoutExpired:
        return False, "swift test melewati batas waktu"
    output = proc.stdout + proc.stderr
    # Gagal build bukan "uji merah": kalau tidak dibedakan, keadaan merah
    # karena alasan yang salah akan dihitung sebagai bukti.
    if "unable to load standard library" in output:
        return False, output
    if f"Test Suite '{RULE}'" not in output and RULE not in output:
        return False, output
    return proc.returncode == 0, output


def main() -> int:
    if not (shutil.which("swift") or shutil.which("docker")):
        print("docker/swift tidak ditemukan: harness tidak bisa membuktikan "
              "apa pun.", file=sys.stderr)
        return 2

    mutasi_sumber.require_clean_sources([SRC, TESTS])
    original = open(SRC, "rb").read()
    teks = original.decode("utf-8")
    if teks.count(ANCHOR) != 1:
        print(f"GERBANG: jangkar {ANCHOR!r} muncul {teks.count(ANCHOR)}x, "
              f"harus tepat 1x — harness tidak boleh jalan.", file=sys.stderr)
        return 2
    baseline_md5 = hashlib.md5(original).hexdigest()

    def restore():
        mutasi_sumber.restore_verified(SRC, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    unexpected = 0
    try:
        for label, edit, harus_merah in STATES:
            restore()
            if edit is not None:
                _, jangkar, ganti = edit
                mutasi_sumber.write_source(SRC, teks.replace(jangkar, ganti, 1))
            hijau, output = run_tests()
            merah = not hijau
            ok = merah == harus_merah
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:28s} "
                  f"{'MERAH' if merah else 'hijau'}")
            if not ok:
                for baris in output.splitlines():
                    if "error:" in baris or "XCTAssert" in baris:
                        print(f"      {baris.strip()[:160]}")
                        break
    finally:
        restore()

    after = hashlib.md5(open(SRC, "rb").read()).hexdigest()
    pulih = after == baseline_md5
    print(f"\nmd5 {os.path.relpath(SRC, ROOT)}: {baseline_md5} -> {after} "
          f"({'pulih persis' if pulih else 'TIDAK PULIH'})")
    if not pulih:
        unexpected += 1

    print()
    print("0 tidak sesuai harapan" if unexpected == 0
          else f"{unexpected} TIDAK SESUAI")
    return 1 if unexpected else 0


if __name__ == "__main__":
    sys.exit(main())
