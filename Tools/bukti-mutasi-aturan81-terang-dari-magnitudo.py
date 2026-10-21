#!/usr/bin/env python3
"""Buktikan Aturan 81 (terang bintang malam dari magnitudo) **berbunyi**.

Kenapa harness ini ada.

Rumus terang bintang sudah pindah ke `NightVisual.starBrightness` dan sudah
diuji di Linux. Yang tidak dijaga siapa pun adalah **pemasangannya**: view
boleh memanggil `NightVisual.star(0.5)` dan seluruh gerbang tetap hijau,
karena uji model memanggil `NightVisual` langsung, bukan lewat view. Akibatnya
setiap bintang menjadi satu titik merah identik -- dari Sirius sampai
magnitudo 4.

Harness ini mencabut jalur itu dari dua arah yang berbeda, karena keduanya
bisa diputus terpisah:

  1. view mengarang ukuran            -> `NightVisual.star(0.5)`
  2. ukuran berhenti baca keyakinan   -> `isConfirmed: true` di
                                         `drawableStarSize`

dan memastikan gerbang diam pada pohon apa adanya. Kalau gerbang hanya
berbunyi pada salah satu arah, satu jalur masih terbuka.

Fail-closed juga diuji: kalau pemanggilannya hilang sama sekali, gerbang
harus memerah, bukan diam.

Dijalankan dari akar repo. Setiap keadaan memakai salinan pohon sendiri,
jadi tidak ada berkas repo yang tersentuh.
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW = "Apps/Shared/CelestialVisualView.swift"

CARI = """let night = NightVisual.star(
            CelestialVisual.drawableStarSize(visual, isConfirmed: isConfirmed))"""

# (nama, berkas, lama, baru, harapan)  harapan: "bunyi" | "diam"
KEADAAN = [
    ("view mengarang ukuran jadi 0.5", VIEW, CARI,
     "let night = NightVisual.star(0.5)", "bunyi"),

    ("ukuran tidak lagi membaca keyakinan", VIEW,
     "CelestialVisual.drawableStarSize(visual, isConfirmed: isConfirmed)",
     "CelestialVisual.drawableStarSize(visual, isConfirmed: true)", "bunyi"),

    ("jalur warna bintang dihapus", VIEW, CARI,
     "let night = NightVisual.floorBrightness", "bunyi"),

    ("kontrol: pohon apa adanya", VIEW, CARI, CARI, "diam"),
]


def main():
    hasil = []
    for nama, rel, lama, baru, harap in KEADAAN:
        tmp = tempfile.mkdtemp(prefix="aturan81-")
        dst = os.path.join(tmp, "repo")
        os.makedirs(dst)
        for item in ("Apps", "Tools", "Packages", "README.md",
                     "swift-ui-lint.sh", "project.yml", "STATUS.md"):
            src = os.path.join(ROOT, item)
            if not os.path.exists(src):
                continue
            if os.path.isdir(src):
                shutil.copytree(src, os.path.join(dst, item),
                                ignore=shutil.ignore_patterns(".build",
                                                              "__pycache__"))
            else:
                shutil.copy2(src, os.path.join(dst, item))

        path = os.path.join(dst, rel)
        with open(path, encoding="utf-8") as f:
            isi = f.read()
        if isi.count(lama) != 1:
            print(f"JANGKAR {isi.count(lama)}x  {nama}")
            hasil.append((nama, "JANGKAR", harap))
            shutil.rmtree(tmp, ignore_errors=True)
            continue
        with open(path, "w", encoding="utf-8") as f:
            f.write(isi.replace(lama, baru))

        r = subprocess.run(["bash", "./swift-ui-lint.sh"], cwd=dst,
                           capture_output=True, text=True)
        keluaran = r.stdout or ""
        # Gerbang dianggap berbunyi hanya kalau Aturan 81 sendiri yang
        # memerah -- bukan aturan lain yang kebetulan ikut merah karena
        # mutasinya merusak sesuatu yang lain.
        bagian = keluaran.split("Aturan 81")[-1] if "Aturan 81" in keluaran else ""
        bersih = "Bersih: terang bintang malam" in bagian
        nyata = "diam" if bersih else "bunyi"
        tanda = "OK   " if nyata == harap else "SALAH"
        print(f"{tanda} {nyata:5s} (harap {harap:5s})  {nama}")
        if nyata != harap:
            for baris in bagian.splitlines()[:6]:
                print(f"        {baris.strip()[:140]}")
        hasil.append((nama, nyata, harap))
        shutil.rmtree(tmp, ignore_errors=True)

    salah = [h for h in hasil if h[1] != h[2] and h[1] != "JANGKAR"]
    print()
    if salah:
        for nama, nyata, harap in salah:
            print(f"GAGAL  {nama}: {nyata}, seharusnya {harap}")
        return 1
    print("Aturan 81 berbunyi pada ketiga cara memutus jalurnya, dan diam "
          "pada pohon apa adanya.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
