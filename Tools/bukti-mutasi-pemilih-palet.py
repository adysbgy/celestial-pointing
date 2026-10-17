#!/usr/bin/env python3
"""Bukti non-vakuositas: uji pemilih palet HARUS merah saat sumbernya dimutasi.

Dijalankan di container yang sama dengan CI (Docker Swift 6.0), atas salinan
yang dimutasi. Menjalankan `SurfacePaletteTests` dan menuntut merah.
"""
import os, subprocess, shutil, sys

SRC = "Packages/PointingKit/Sources/PointingKit/NightPaletteSelector.swift"
ANCHOR = "isNightModeEnabled ? .night : .day"

# (label, pengganti, harus_merah)
STATES = [
    ("1. selalu .day",    ".day", True),
    ("2. selalu .night",  ".night", True),
    ("3. dibalik",        "!isNightModeEnabled ? .night : .day", True),
]


def main():
    repo = os.getcwd()
    bersih = open(SRC, encoding="utf-8").read()
    if ANCHOR not in bersih:
        print("JANGKAR HILANG: %s" % ANCHOR)
        return 1
    gagal = 0
    try:
        # baseline: sumber apa adanya harus HIJAU
        rc = run_tests()
        print("%-18s %s" % ("[baseline] asli", "HIJAU" if rc == 0 else "MERAH"))
        if rc != 0:
            gagal += 1
        for label, rep, harus_merah in STATES:
            open(SRC, "w", encoding="utf-8").write(bersih.replace(ANCHOR, rep, 1))
            rc = run_tests()
            merah = rc != 0
            ok = merah == harus_merah
            if not ok:
                gagal += 1
            print("%-18s %-6s %s" % (label, "MERAH" if merah else "HIJAU",
                                     "sesuai" if ok else "TIDAK SESUAI"))
    finally:
        open(SRC, "w", encoding="utf-8").write(bersih)
    print()
    print("0 tidak sesuai harapan" if gagal == 0 else "%d TIDAK SESUAI" % gagal)
    return 1 if gagal else 0


def run_tests():
    cmd = ["sudo", "-n", "docker", "run", "--rm", "-v", "%s:/src" % os.getcwd(),
           "-w", "/src/Packages/PointingKit", "swift:6.0", "swift", "test",
           "--filter", "SurfacePaletteTests"]
    return subprocess.run(cmd, capture_output=True, text=True).returncode


if __name__ == "__main__":
    sys.exit(main())
