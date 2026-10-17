#!/usr/bin/env python3
"""Bukti non-vakuositas: uji politik bunyi HARUS merah saat sumbernya dimutasi.

Kenapa arah ini, bukan uji tambahan.

`AudioEventPolicy` (PointingKit) memindahkan keputusan "peristiwa mana yang
boleh berbunyi" keluar dari `Apps/`, yang tidak pernah dibangun
`swift-test.sh` di Linux. Tapi memindahkan kode ke paket teruji **belum**
berarti ia terjaga: uji yang hanya memanggil fungsi bisa lulus untuk politik
yang terbalik, selama fixture-nya ikut terbalik. Yang dibuktikan di sini
adalah arah yang mudah hilang: **ujinya masih berbunyi saat politiknya
salah.**

Cacat yang ditutup, diukur sebelum `AudioEventPolicy` ada (salinan utuh,
proses baru, ke-45 aturan UI dijalankan atas `Apps/Shared/AudioCue.swift`):

    guard ... events.contains(.lockSucceeded) ...    HIJAU
    guard ... .lockSucceeded || .uncertain ...       HIJAU  (buta)
    guard AudioCue.isOn                              HIJAU  (buta)
    return                                           HIJAU  (buta)

Yang kedua adalah yang berbahaya: engine ragu berbunyi persis seperti engine
yakin, dan bunyi adalah satu-satunya saluran bagi pengguna yang tidak melihat
layar — tidak ada teks yang bisa membantahnya.

Harness ini memutasi sumber produksinya di container yang sama dengan CI
(Docker Swift 6.0), menjalankan `AudioEventPolicyTests` untuk tiap keadaan,
dan menuntut merah pada tiga politik yang salah serta hijau pada pohon apa
adanya.

Penulisan & pemulihan lewat `mutasi_sumber`, sama seperti harness lain:

  * `require_clean_sources` menolak jalan bila sumber sudah menyimpang dari
    HEAD — kalau tidak, harness akan mengadopsi mutasi yang tertinggal
    sebagai «aslinya» dan melaporkan «pulih persis» atas dirinya sendiri;
  * `write_source` menulis atomik, jadi `swift test` hanya pernah melihat
    versi lama atau versi baru;
  * `restore_verified` membaca balik byte demi byte dan **melempar** bila
    tidak cocok.

Lingkungan: `swift` langsung, atau docker + image `swift:6.0`. Kalau tidak
ada keduanya, harness **berhenti** (exit 2) alih-alih melaporkan hijau atas
nol pembuktian.

Pakai: python3 Tools/bukti-mutasi-suara.py
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
                   "AudioEventPolicy.swift")
TESTS = os.path.join(ROOT, "Packages", "PointingKit", "Tests",
                     "PointingKitTests", "AudioEventPolicyTests.swift")

#: Jangkar yang benar hari ini. Kalau ini hilang dari sumber, harness berhenti
#: daripada melaporkan "sesuai harapan" atas nol pembuktian.
ANCHOR = "public static let audibleEvents: Set<HapticEvent> = [.lockSucceeded]"
#: Gerbang saklar pengguna. Penggantinya **non-kosong**: mutasi berupa
#: penghapusan (`""`) membuat `check-jangkar-harness.py` membacanya sebagai
#: mutasi bocor — pemeriksa itu tidak bisa membedakan "harness yang sengaja
#: menghapus baris" dari "harness yang lupa memulihkan". Salah satu yang
#: dibutuhkan bukan mematikan pemeriksanya, melainkan cacat yang **tetap
#: terlihat di sumber**: baris yang selalu bernilai tetap menggantikan
#: gerbangnya.
GATE = "        guard isAudioEnabled else { return false }"
GATE_BUTA = "        _ = isAudioEnabled\n        if false { return false }"

RULE = "AudioEventPolicyTests"

#: Jalur relatif, dipakai bentuk `(path, find, replace)` yang dibaca
#: `check-jangkar-harness.py` sebagai pasangan jangkar.
SRC_REL = "Packages/PointingKit/Sources/PointingKit/AudioEventPolicy.swift"

#: (label, edit, harus_merah). `edit` = `None` (baseline) atau
#: `(path, find, replace)` — bentuk yang dikenali gerbang jangkar. Setiap
#: keadaan menyasar **satu** jangkar tertentu.
STATES = [
    ("baseline (kode apa adanya)", None, False),
    ("ragu ikut audible",
     (SRC_REL, ANCHOR,
      "public static let audibleEvents: Set<HapticEvent> = [.lockSucceeded, .uncertain]"),
     True),
    ("selalu diam",
     (SRC_REL, ANCHOR,
      "public static let audibleEvents: Set<HapticEvent> = []"),
     True),
    ("saklar tak digerbangi", (SRC_REL, GATE, GATE_BUTA), True),
    ("basil ulang (pulih)", None, False),
]


def run_tests() -> tuple[bool, str]:
    """Jalankan hanya uji politik bunyi, di lingkungan yang sama dengan CI."""
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
    for jangkar in (ANCHOR, GATE):
        if teks.count(jangkar) != 1:
            print(f"GERBANG: jangkar {jangkar!r} muncul {teks.count(jangkar)}x, "
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
