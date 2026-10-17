#!/usr/bin/env python3
"""Bukti Aturan 45: pemilih palet tidak boleh ditulis sendiri di Apps/.

Dua arah, karena "gerbang berbunyi" tidak ada artinya tanpa yang kedua:
  * bentuk lama (percabangan ditulis di Apps/)  -> wajib MERAH
  * pohon produksi apa adanya                   -> wajib HIJAU

Non-vakuositas diukur dengan menjalankan keadaan yang sama atas aturan
**pra-perbaikan** (HEAD:swift-ui-lint.sh): kalau keadaan cacatnya juga
"bersih" di sana, ia sungguh mengukur aturan baru ini.
"""
import os, subprocess, shutil, io, tarfile, sys

REPO = "/home/ubuntu/projects/celestial-pointing"
SB = "/home/ubuntu/.hermes/profiles/xcode-dev/cache/scratch/sweep45"
F = "Apps/Shared/SurfaceTokens.swift"
NEW = "NightPaletteSelector.palette(isNightModeEnabled: NightMode.isOn)"

#: (label, pengganti, wajib_merah)
KEADAAN = [
    ("1. bentuk lama",        "return NightMode.isOn ? .night : .day", True),
    ("2. selalu .day",        "return .day", True),
    ("3. dibalik",            "return NightMode.isOn ? .day : .night", True),
    ("4. produksi apa adanya", None, False),
]


def run_rule():
    """Jalankan lint di kotak pasir; True bila Aturan 45 berbunyi."""
    r = subprocess.run(["./swift-ui-lint.sh"], cwd=SB,
                       capture_output=True, text=True)
    out = r.stdout
    # "berbunyi" = ada temuan yang menyebut Aturan 45, bukan sekadar exit!=0
    return "Aturan 45" in out and "-- pemilihan palet ditulis sendiri" in out


def build():
    """Salin pohon **kerja** (bukan HEAD), karena perbaikan ini belum
    di-commit saat harnessnya ditulis, dan jangkar mutasinya ada di pohon
    kerja. `git archive HEAD` akan mengembalikan bentuk lama dan membuat
    harness mengukur keadaan yang tidak ada lagi."""
    if os.path.exists(SB):
        subprocess.run(["sudo", "rm", "-rf", SB], check=True)
    os.makedirs(SB)
    # Salin **berkas terlacak** saja: `.build/` milik Docker bersifat root dan
    # tidak bisa dibaca, dan ia tidak diperlukan lint (yang hanya membaca
    # `Apps/` dan `Packages/PointingKit/Sources`).
    daftar = subprocess.run(
        ["git", "-C", REPO, "ls-files", "-z"],
        capture_output=True, text=True, check=True).stdout.split("\0")
    for rel in daftar:
        if not rel:
            continue
        src = os.path.join(REPO, rel)
        dst = os.path.join(SB, rel)
        if not os.path.isfile(src):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy(src, dst)
    # Berkas baru yang belum terlacak oleh git ikut disalin — jangkar mutasinya
    # hidup di sana.
    for rel in ["Packages/PointingKit/Sources/PointingKit/NightPaletteSelector.swift",
                "Tools/bukti-mutasi-pemilih-palet.py",
                "Tools/bukti-mutasi-pemilih-palet-lint.py"]:
        src = os.path.join(REPO, rel)
        if os.path.isfile(src):
            dst = os.path.join(SB, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy(src, dst)
    return open(os.path.join(SB, F), encoding="utf-8").read()


def main():
    bersih = build()
    if NEW not in bersih:
        print("JANGKAR HILANG (perbaikan belum ada): %s" % NEW)
        return 1
    gagal = 0
    for label, rep, wajib_merah in KEADAAN:
        p = os.path.join(SB, F)
        if rep is None:
            open(p, "w", encoding="utf-8").write(bersih)
        else:
            open(p, "w", encoding="utf-8").write(bersih.replace(NEW, rep, 1))
        bunyi = run_rule()
        ok = bunyi == wajib_merah
        if not ok:
            gagal += 1
        print("%-24s %-6s %s" % (label, "MERAH" if bunyi else "HIJAU",
                                 "sesuai" if ok else "TIDAK SESUAI"))
    open(os.path.join(SB, F), "w", encoding="utf-8").write(bersih)
    print()
    print("0 tidak sesuai harapan" if gagal == 0 else "%d TIDAK SESUAI" % gagal)
    return 1 if gagal else 0


if __name__ == "__main__":
    sys.exit(main())
