#!/usr/bin/env python3
"""Buktikan gerbang **peran @Published** (ObservedProperty) berbunyi.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis, dan siklus ini adalah bukti
lokalnya: `ObservedPropertyTests` ditulis sebagai berkas **belum ter-commit**,
dan versi pertamanya gagal di dua arah sekaligus -- pembacanya hanya menangkap
28 deklarasi `@Published` menjadi 2. Yang harus dibuktikan bukan "ia hijau",
melainkan bahwa ia **merah** pada hal yang memang salah, dan bahwa setiap arah
pinang-pinang peran ditangkap secara terpisah, karena satu mutasi bisa lolos
di sisi lain.

Tiga kelas cacat yang diuji, dan tiap kelas punya kontrol negatif:

  * properti `@Published` **baru** lahir tanpa peran   -> uji 1 berbunyi
  * peran menyebut properti yang sudah dihapus        -> uji 2 berbunyi
  * properti pembukuan masih `@Published`             -> uji 3 berbunyi
  * peran renderInput pada properti yang TIDAK
    `@Published` -- janji render yang bohong          -> uji 2 berbunyi

Keadaan "kontrol negatif" wajib hijau (berkas apa adanya): gerbang yang merah
pada kode yang benar akan dilonggarkan orang, bukan diperbaiki -- itu kelas
cacat yang paling mahal di repo ini.

Kenapa probe menjalankan `swift test`, bukan mengimpor Python: yang diuji
adalah uji Swift dan model Swift-nya. Mutasinya ada di **dua** tempat, dan
keduanya perlu: model (`roles`) menentukan apa yang dijanjikan, kode
(`MotionLogger.swift`) menentukan apa yang benar.

Pakai:
    python3 Tools/bukti-mutasi-peran-published.py
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "ObservedProperty.swift")
MOTION = os.path.join(ROOT, "Apps", "Shared", "MotionLogger.swift")
SWIFT_TEST = "ObservedPropertyTests"

# ── Jangkar ───────────────────────────────────────────────────────────────
# Jangkar yang tidak cocok membuat harness **berhenti** (SystemExit), bukan
# diam-diam menguji himpunan kosong.

# Peran yang benar untuk properti pembukuan.
ROLE_BOOKKEEPING = '"isRunning": .bookkeeping,'
# Peran renderInput yang sah, di berkas yang sama dengan `isRunning`.
ROLE_RENDER = '"unavailableReason": .renderInput,'
# Deklarasi yang diperbaiki: ada, tapi bukan @Published.
DECL = "public private(set) var isRunning = false"
# Bentuk lama: masih @Published.
DECL_PUBLISHED = "@Published public private(set) var isRunning = false"

STATES = [
    # Baseline wajib hijau: kalau tidak, harnessnya menuduh kode yang benar.
    ("0. baseline (tanpa mutasi)",
     None, None, False),

    # 1. Properti @Published BARU tanpa peran: `unavailableReason` dibuat
    #    `@Published` di berkas yang perannya sudah terdaftar, tetapi nama
    #    propertunya berbeda -> uji 1 berbunyi atas properti itu sendiri.
    ("1. properti @Published baru tanpa peran di daftar",
     None,
     (MOTION, "public private(set) var isRunning = false",
      "public private(set) var isRunning = false\n    @Published public private(set) var barusan: Int = 0"),
     True),

    # 2. Peran renderInput atas properti yang TIDAK @Published: janji render
    #    yang bohong. Inilah arah yang paling sunyi -- `isRunning` sudah
    #    diperbaiki menjadi bukan @Published, dan perannya kembali ke
    #    renderInput berarti daftarnya mengatakan "layar ikut berubah" padahal
    #    tidak ada saluran render sama sekali.
    ("2. peran renderInput untuk properti yang bukan @Published",
     (MODEL, ROLE_BOOKKEEPING, '"isRunning": .renderInput,'),
     None,
     True),

    # 3. Properti pembukuan masih @Published: cacat aslinya yang diperbaiki
    #    siklus ini. Model tetap benar (bookkeeping), kode yang menyimpang.
    ("3. properti pembukuan masih @Published",
     None,
     (MOTION, DECL, DECL_PUBLISHED),
     True),

    # 4. Peran menyebut properti yang sudah tidak ada: menghapus properti dari
    #    kode sementara daftar masih menyebutnya -> uji 2 berbunyi, dan uji 3
    #    TIDAK boleh berbunyi (sudah bukan @Published, jadi tidak ada yang
    #    dilarang di sana). Dua sisi yang berbeda harus berbunyi berbeda.
    ("4. properti di daftar dihapus dari kode",
     None,
     (MOTION, "    public private(set) var isRunning = false\n", ""),
     True),
    # 5. Kontrol negatif: properti renderInput yang sah dan @Published.
    #    Menjadikannya `.bookkeeping` (padahal ia @Published dan dibaca UI)
    #    harus MERAH -- itu menguji arah sebalik dari keadaan 2.
    ("5. renderInput sah diubah menjadi bookkeeping",
     (MODEL, ROLE_RENDER, '"unavailableReason": .bookkeeping,'),
     None,
     True),
]


def run_swift():
    """Jalankan uji Swift-nya. -> (dijalankan, gagal, detail)."""
    if subprocess.run(["which", "swift"], capture_output=True).returncode == 0:
        cmd = ["swift", "test", "--package-path", "Packages/PointingKit",
               "--filter", SWIFT_TEST]
        how = "swift langsung"
    else:
        cmd = ["sudo", "-n", "docker", "run", "--rm", "-v", f"{ROOT}:/src",
               "-w", "/src/Packages/PointingKit", "swift:6.0",
               "swift", "test", "--filter", SWIFT_TEST]
        how = "docker swift:6.0"

    try:
        out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                              timeout=1800)
    except subprocess.TimeoutExpired:
        return True, False, "timeout 1800s -- anggap LULUS, bukan gagal"
    text = (out.stdout or "") + (out.stderr or "")
    failed = out.returncode != 0 and SWIFT_TEST in text
    # Nama uji yang berbunyi: yang dibutuhkan bukan "ada error", tapi
    # **uji mana** yang menangkap keadaan itu. Dua keadaan yang sama-sama
    # menyalakan satu uji berarti separuh gerbangnya tidak mengukur apa pun.
    names = sorted({l.split("'")[1].split(".")[-1]
                    for l in text.splitlines()
                    if "Test Case '" in l and "failed" in l})
    detail = f"{how}: {'gagal seperti dituntut' if failed else 'LULUS'} (exit {out.returncode})"
    if names:
        detail += f" | berbunyi: {', '.join(names)}"
    return True, failed, detail


def main():
    for path in (MODEL, MOTION):
        mutasi_sumber.require_clean_sources([path])
    originals = {p: open(p, "rb").read() for p in (MODEL, MOTION)}

    failures = []

    def restore():
        for path, content in originals.items():
            mutasi_sumber.restore_verified(path, content)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, model_edit, motion_edit, expect_red in STATES:
            edits = [("model", MODEL, model_edit), ("kode", MOTION, motion_edit)]
            for label, default_path, edit in edits:
                if edit is None:
                    continue
                # Pola: `(find, replace)` dipakai pada berkas ikutannya; `(path,
                # find, replace)` mengubah berkasnya sendiri.
                if len(edit) == 2:
                    find, replace = edit
                    path = default_path
                else:
                    path, find, replace = edit
                text = open(path, encoding="utf-8").read()
                if text.count(find) != 1:
                    raise SystemExit(
                        f"{name}: jangkar pada {label} tidak unik "
                        f"({text.count(find)}×). Sumber berubah; perbarui "
                        "harness ini, jangan melonggarkan ujinya.")
                mutasi_sumber.write_source(path, text.replace(find, replace))

            ran, failed, detail = run_swift()
            restore()
            if any(open(p, "rb").read() != originals[p] for p in (MODEL, MOTION)):
                raise SystemExit(f"{name}: pemulihan gagal")

            if not ran:
                print(f"  {name}: {detail}")
                failures.append(f"{name}: {detail}")
                continue

            ok = (failed == expect_red)
            print(f"  {'OK  ' if ok else 'SALAH'} {name}  | {detail}")
            if not ok:
                failures.append(
                    f"{name}: uji {'tidak' if expect_red else ''} berbunyi "
                    f"padahal {'seharusnya' if expect_red else 'tidak boleh'}")
    finally:
        restore()

    if failures:
        print("\n== GERBANG PERAN @Published TIDAK TERBUKTI ==")
        for f in failures:
            print("  - " + f)
        return 1
    print("\n== semua keadaan sesuai harapan: gerbang peran menangkap cacatnya ==")
    return 0


if __name__ == "__main__":
    sys.exit(main())
