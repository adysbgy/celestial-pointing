#!/usr/bin/env python3
"""Buktikan uji sebaran radial gugus terbuka **bisa merah** — dan merahnya
di uji yang menjaganya, bukan di uji lain.

Kenapa berkas ini ada.

`testOpenClusterStarsSitAtDifferentRadii` lahir di siklus ini untuk menutup
satu cacat yang sudah terukur: ketujuh bintang `openCluster` duduk pada radius
0.620…0.703 (sebaran **0.083 R**), yaitu sebuah cincin — persis bentuk yang
docstring `.planetaryNebula` sebut sebagai pembeda nebula planetari, bukan
gugus terbuka. Tiga uji yang sudah ada hijau di atas cincin itu, jadi cincin
itu bertahan beberapa siklus tanpa satu pun gerbang berbunyi.

Uji baru yang hijau pada hari ia ditulis tidak membuktikan apa pun. Yang harus
dibuktikan ada dua arah:

  * ia **merah** pada tata letak cincin yang lama (cacatnya), dan
  * ia **hijau** pada tata letak sekarang (bukan uji yang selalu merah).

Arah ketiga juga diukur, karena kelas cacat yang berulang di repo ini adalah
"gerbang hijau karena tidak mengukur apa pun": uji ini harus **merah pada
cacat yang berbeda bentuknya** — bukan hanya pada satu susunan yang kebetulan
sama dengan yang lama. Karena itu ada dua tata letak cincin: yang asli
(radius 0.62–0.70) dan sebuah cincin sempit buatan (radius 0.55–0.60, tidak
pernah ada di riwayat). Kalau uji hanya menangkap susunan yang persis lama,
keadaan 2 akan hijau dan harness ini melaporkannya.

Kenapa `./swift-test.sh`, bukan `swift test` langsung: skrip itu memakai image
Docker yang sama dengan CI. Gerbang yang mengukur toolchain lain bukan gerbang
— pelajaran yang sudah tercatat di `bukti-mutasi-elongasi-ragu.py`.

Kenapa nama ujinya dituntut, bukan sekadar "suite merah": harness yang hanya
menuntut suite merah akan hijau bila uji lain yang kebetulan rusak. Itu
cakupan palsu yang paling mudah terjadi saat suite berisi >1000 uji.

Yang **TIDAK** diklaim berkas ini:

  * Tidak membuktikan susunan barunya cocok dengan M7/M41 yang sebenarnya.
    Katalog ini tidak menyimpan posisi bintang anggota; yang dijaga uji adalah
    **tersebar**, bukan **akurat**.
  * Tidak membuktikan bentuknya terbaca di kartu 38 pt — itu gerbang piksel
    (`check-visuals.py`).
  * Tidak membuktikan port Python (`render-visuals.py`) ikut berubah. Itu
    dijaga `check_deep_sky_layouts_match_the_model`, yang membandingkan port
    terhadap model per blob.

Pakai:
    python3 Tools/bukti-mutasi-sebaran-gugus.py     # 0 = semua sesuai harapan
"""

from __future__ import annotations

import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

from mutasi_sumber import require_clean_sources, restore_verified, write_source  # noqa: E402

MODEL = "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift"
TEST_FILE = "Packages/PointingKit/Tests/PointingKitTests/CelestialVisualTests.swift"

# Uji yang **wajib** berbunyi. Ditulis namanya, bukan hanya "ada kegagalan".
NUTUP_UJI = "testOpenClusterStarsSitAtDifferentRadii"

#: Tata letak sekarang (tujuh bintang, sebaran radial 0.488 R).
SEKARANG = """            let stars: [(Double, Double, Double, Double, Double, Double)] = [
                ( 0.000000, -0.440000, 0.34, 1.0, 0.0, 0.55),
                ( 0.600000, -0.260000, 0.30, 1.0, 0.0, 0.50),
                (-0.500000, -0.360000, 0.32, 1.0, 0.0, 0.45),
                ( 0.240000,  0.620000, 0.28, 1.0, 0.0, 0.52),
                (-0.260000,  0.560000, 0.31, 1.0, 0.0, 0.48),
                ( 0.780000,  0.140000, 0.22, 1.0, 0.0, 0.42),
                (-0.760000,  0.200000, 0.24, 1.0, 0.0, 0.55)
            ]"""

# 1. Tata letak cincin **asli** — persis yang dikirim beberapa siklus.
#    Sebaran 0.083 R. Ini cacat yang uji baru tutup.
CINCIN_ASLI = """            let stars: [(Double, Double, Double, Double, Double, Double)] = [
                ( 0.000000, -0.620000, 0.34, 1.0, 0.0, 0.55),
                (-0.560000, -0.300000, 0.31, 1.0, 0.0, 0.50),
                ( 0.520000, -0.340000, 0.33, 1.0, 0.0, 0.45),
                (-0.680000,  0.180000, 0.29, 1.0, 0.0, 0.52),
                ( 0.620000,  0.220000, 0.31, 1.0, 0.0, 0.48),
                (-0.340000,  0.580000, 0.33, 1.0, 0.0, 0.42),
                ( 0.300000,  0.620000, 0.29, 1.0, 0.0, 0.55)
            ]"""

# 2. Cincin sempit **buatan** — tidak pernah ada di riwayat. Radius 0.55–0.60,
#    sebaran 0.05 R. Ada untuk membuktikan uji ini menangkap *kelas* cacatnya
#    (semua bintang pada satu radius), bukan hanya satu susunan yang kebetulan
#    sama dengan yang lama.
CINCIN_SEMPIT = """            let stars: [(Double, Double, Double, Double, Double, Double)] = [
                ( 0.000000, -0.580000, 0.34, 1.0, 0.0, 0.55),
                (-0.520000, -0.260000, 0.31, 1.0, 0.0, 0.50),
                ( 0.490000, -0.300000, 0.33, 1.0, 0.0, 0.45),
                (-0.560000,  0.140000, 0.29, 1.0, 0.0, 0.52),
                ( 0.540000,  0.190000, 0.31, 1.0, 0.0, 0.48),
                (-0.300000,  0.500000, 0.33, 1.0, 0.0, 0.42),
                ( 0.280000,  0.530000, 0.29, 1.0, 0.0, 0.55)
            ]"""

# 3. Semua bintang di pusat — sebaran 0.000 R. Kebalikan ekstremnya: bukan
#    cincin, tapi juga bukan gugus terbuka (itu gugus bola). Harus MERAH,
#    karena "tersebar pada radius berbeda" juga berarti "tidak menumpuk".
MENUMPUK = """            let stars: [(Double, Double, Double, Double, Double, Double)] = [
                ( 0.000000,  0.000000, 0.34, 1.0, 0.0, 0.55),
                ( 0.000000,  0.000000, 0.31, 1.0, 0.0, 0.50),
                ( 0.000000,  0.000000, 0.33, 1.0, 0.0, 0.45),
                ( 0.000000,  0.000000, 0.29, 1.0, 0.0, 0.52),
                ( 0.000000,  0.000000, 0.31, 1.0, 0.0, 0.48),
                ( 0.000000,  0.000000, 0.33, 1.0, 0.0, 0.42),
                ( 0.000000,  0.000000, 0.29, 1.0, 0.0, 0.55)
            ]"""


def baca(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
        return handle.read()


def jalankan_suite():
    """Jalankan uji kedua paket, kembalikan (lulus, teks keluaran)."""
    out = subprocess.run(["./swift-test.sh"], cwd=ROOT, capture_output=True,
                         text=True, timeout=3000)
    return out.returncode == 0, out.stdout + out.stderr


def gagal_dengan_uji(output, nama_uji):
    """Apakah keluaran memuat **kegagalan** pada uji bernama ini.

    Dicocokkan lewat `... failed`, bukan lewat substring namanya saja:
    pencarian polos akan selalu cocok dan setiap keadaan "merah" akan lolos
    tanpa ada yang merah. Nama di keluaran berkualifikasi suite
    (`CelestialVisualTests.<uji>`), jadi awalan itu dibuat opsional.
    """
    return re.search(rf"\b(?:[A-Za-z_][A-Za-z0-9_]*\.)*{re.escape(nama_uji)}\b"
                     r"[^\n]*?\bfailed\b", output) is not None


def main():
    paths = [MODEL]
    require_clean_sources(paths)

    asli = baca(MODEL)
    if asli.count(SEKARANG) != 1:
        print("GAGAL: jangkar tata letak gugus terbuka tidak ditemukan tepat "
              f"satu kali di {MODEL}.")
        print("Harness ini menguji perilaku; kalau tata letaknya diubah, "
              "perbarui jangkar SEKARANG -- jangan hapus keadaannya.")
        return 1

    # Uji harus benar-benar ada. Kalau namanya berubah, seluruh keadaan merah
    # di bawah akan "lulus" karena tidak ada yang perlu gagal.
    if NUTUP_UJI not in baca(TEST_FILE):
        print(f"GAGAL: uji {NUTUP_UJI} tidak ada di {TEST_FILE}.")
        return 1

    cacat = [
        ("1. tata letak cincin ASLI (r 0.62-0.70)", CINCIN_ASLI),
        ("2. cincin sempit buatan (r 0.55-0.60, tak pernah ada)", CINCIN_SEMPIT),
        ("3. semua bintang menumpuk di pusat (r 0.00)", MENUMPUK),
    ]

    hasil = []
    try:
        # Baseline: pohon bersih harus hijau. Tanpa ini, uji yang selalu merah
        # akan lolos setiap keadaan cacat di bawah.
        bersih, keluaran = jalankan_suite()
        hasil.append(("[baseline: pohon bersih]", bersih,
                      "" if bersih else "suite tidak hijau pada kode benar"))

        for nama, mutasi in cacat:
            write_source(os.path.join(ROOT, MODEL), asli.replace(SEKARANG, mutasi))
            lulus, keluaran = jalankan_suite()
            if lulus:
                hasil.append((nama, False, "suite tetap hijau -- cacat lolos"))
            elif not gagal_dengan_uji(keluaran, NUTUP_UJI):
                hasil.append((nama, False,
                              "suite merah, tetapi bukan di uji yang menjaganya"))
            else:
                baris = next((l.strip() for l in keluaran.splitlines()
                              if NUTUP_UJI in l and ("error:" in l or "failed" in l)),
                             "")
                hasil.append((nama, True, baris[:148]))
    finally:
        restore_verified(os.path.join(ROOT, MODEL), asli)

    print()
    for nama, lulus, catatan in hasil:
        print(f"{'LULUS' if lulus else 'GAGAL'}  {nama}")
        if catatan:
            print(f"        {catatan}")

    gagal = [nama for nama, lulus, _ in hasil if not lulus]
    print()
    if gagal:
        print(f"HARNESS GAGAL: {len(gagal)} keadaan tidak terbukti: "
              + ", ".join(gagal))
        return 1
    print(f"SEMUA {len(hasil)} KEADAAN TERBUKTI: gerbang sebaran radial gugus "
          f"terbuka dijaga uji {NUTUP_UJI}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
