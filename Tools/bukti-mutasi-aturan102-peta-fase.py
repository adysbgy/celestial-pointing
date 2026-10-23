#!/usr/bin/env python3
"""Buktikan Aturan 102 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 102 lahir dari cacat yang sudah **ada di pohon** dan lolos 101 aturan
UI: `planetWaxing` hanya pernah ditambahi `planetWaxing[planet] = waxing`,
sementara dua kamus fase saudaranya dibangun di variabel lokal lalu ditugaskan
utuh. Docstringnya menjanjikan ketiganya sejajar; yang berlaku hanya dua.

Bentuk cacatnya halus dan itu alasannya butuh gerbang: menambah satu kunci ke
kamus terlihat sama benarnya dengan membangun ulang kamus, dan keduanya
menghasilkan kode yang **berjalan**. Bedanya baru muncul pada sampel yang
gagal — di sana yang kedua mengosongkan entri lama, yang pertama tidak.

Enam keadaan, karena satu mutasi hanya menutup satu jalan:

  1. **Kembali ke bentuk aslinya** — tulisan subskrip di loop, tanpa penugasan
     utuh. Ini cacat yang benar-benar terukur di pohon, jadi ia harus merah.
  2. **Hanya tulisan subskrip dihapus** — `planetWaxing = waxing` tidak pernah
     ada dan kamusnya tidak pernah diisi. Kode ini tidak berguna, tetapi ia
     **juga** tidak menggambar apa pun yang salah; gerbang tetap harus merah
     karena kamusnya tidak dibangun ulang sama sekali.
  3. **Penugasan utuh dihapus, subskrip tetap** — jalan yang paling mungkin
     terjadi saat seseorang "merapikan" baris terakhir fungsi.
  4. **Deklarasi kamus diganti nama** — gerbang berhenti bisa menurunkan
     daftarnya. Ini harus GAGAL, bukan hijau: gerbang yang tidak menemukan
     apa pun untuk diperiksa sudah berhenti mengukur.
  5. **Kamus keempat ditambahkan** dan dibaca tetapi tidak dibangun ulang —
     jalan yang paling mungkin berikutnya, dan justru yang paling mudah
     terlewat. Gerbang harus memerah tanpa siapa pun memperbarui daftar
     tangan, karena daftarnya diturunkan dari deklarasi.
  6. **Nama variabel lokalnya sama dengan nama propertinya** — bentuk yang
     membuat `planetWaxing = waxing` mustahil ditulis dan mendorong penulis
     kembali ke tulisan subskrip. Gerbang harus tetap menuntut penugasan utuh,
     bukan menerima `planetWaxing[planet] = …` sebagai pengganti.

Setiap keadaan menyunting berkas **sungguhan** lalu mengembalikannya, dan
pemulihannya diverifikasi byte-per-byte. Harness menolak berjalan di atas
sumber yang sudah kotor: kalau tidak, ia akan mengadopsi penyimpangan itu
sebagai «aslinya» dan melaporkan «pulih persis» atas dirinya sendiri.
"""

from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ROOT, "Apps/Shared/PointingEngine.swift")
GATE = os.path.join(ROOT, "Tools/check-aturan102-peta-fase-dibangun-ulang.py")

#: Jangkar tulisan subskrip — bentuk cacat yang terukur di pohon.
ANCHOR_SUB = "                waxing[planet] = isWaxing"
#: Jangkar penugasan utuh.
ANCHOR_WHOLE = "        planetWaxing = waxing"
#: Deklarasi kamus.
ANCHOR_DECL = "    private var planetWaxing: [CelestialVisual.Planet: Bool] = [:]"
#: Deklarasi kamus ketiga, tempat menambahkan kamus keempat.
ANCHOR_DECL3 = ("    private var planetBrightLimbAngles: "
                "[CelestialVisual.Planet: Double] = [:]")
#: Pengikatan `planet` di pembaca, tempat kamus keempat dibaca.
ANCHOR_READ = ("        let waxing = isMoon ? moonIsWaxing : "
               "planet.flatMap { planetWaxing[$0] }")


def jalankan() -> int:
    hasil = subprocess.run([sys.executable, GATE], capture_output=True, text=True)
    return hasil.returncode


def main() -> int:
    if not os.path.exists(GATE):
        print(f"FAIL gerbangnya tidak ada: {GATE}")
        return 1

    asli = open(ENGINE, "rb").read()
    teks = asli.decode("utf-8")

    for jangkar in (ANCHOR_SUB, ANCHOR_WHOLE, ANCHOR_DECL, ANCHOR_DECL3,
                    ANCHOR_READ):
        if jangkar not in teks:
            print(f"FAIL jangkar tidak ditemukan: {jangkar!r}")
            print("     Harness ini bekerja pada teks; jangkar yang basi")
            print("     berarti ia tidak menyunting apa pun dan setiap")
            print("     keadaan akan «lulus» tanpa menguji apa pun.")
            return 1

    # Keadaan: (nama, teks mutasi, harapan exit).
    keadaan: list[tuple[str, str, int]] = []

    # 1. Bentuk aslinya: subskrip, tanpa penugasan utuh.
    keadaan.append((
        "kembali ke bentuk asli (tulisan subskrip, tanpa penugasan utuh)",
        teks.replace(ANCHOR_WHOLE, ""),
        1))

    # 2. Subskrip dihapus, penugasan utuh juga tidak ada -> kamus tak pernah
    #    diisi. Merah: tidak ada penugasan utuh.
    keadaan.append((
        "subskrip dihapus tanpa penugasan utuh (kamus tak pernah diisi)",
        teks.replace(ANCHOR_WHOLE, "").replace(ANCHOR_SUB + "\n", ""),
        1))

    # 3. Penugasan utuh dihapus, subskrip tetap.
    keadaan.append((
        "penugasan utuh dihapus, tulisan subskrip tetap",
        teks.replace(ANCHOR_WHOLE + "\n", ""),
        1))

    # 4. Deklarasi diganti nama -> gerbang berhenti menurunkan daftarnya.
    keadaan.append((
        "deklarasi kamus diganti nama (gerbang berhenti mengukur)",
        teks.replace(ANCHOR_DECL,
                     "    private var planetWaxingX: "
                     "[CelestialVisual.Planet: Bool] = [:]")
            .replace(ANCHOR_READ,
                     "        let waxing = isMoon ? moonIsWaxing : "
                     "planet.flatMap { planetWaxingX[$0] }"),
        1))

    # 5. Kamus keempat ditambahkan, dibaca, tetapi hanya ditambahi.
    teks5 = teks.replace(
        ANCHOR_DECL3,
        ANCHOR_DECL3 + "\n"
        "    private var planetExtras: [CelestialVisual.Planet: Double] = [:]")
    teks5 = teks5.replace(
        ANCHOR_READ,
        "        let extra = planet.flatMap { planetExtras[$0] }\n" + ANCHOR_READ)
    teks5 = teks5.replace(
        "                waxing[planet] = isWaxing",
        "                waxing[planet] = isWaxing\n"
        "                planetExtras[planet] = 0")
    keadaan.append((
        "kamus keempat ditambahkan dan dibaca, tetapi hanya ditambahi",
        teks5,
        1))

    # 6. Nama lokal disamakan dengan properti -> penugasan utuh mustahil,
    #    penulis didorong kembali ke subskrip.
    keadaan.append((
        "variabel lokal dinamai sama dengan properti, subskrip dipakai",
        teks.replace(ANCHOR_WHOLE, "")
            .replace("        var waxing: [CelestialVisual.Planet: Bool] = [:]",
                     "        planetWaxing = [:]")
            .replace("                waxing[planet] = isWaxing",
                     "                planetWaxing[planet] = isWaxing"),
        1))

    hasil: list[tuple[str, bool, str]] = []

    # Baseline dulu: pohon apa adanya harus hijau. Tanpa ini, setiap keadaan
    # merah karena sebab lain akan terbaca sebagai "gerbangnya bekerja".
    kode = jalankan()
    hasil.append(("[baseline] pohon apa adanya", kode == 0, f"exit={kode}"))

    for nama, mutasi, harap in keadaan:
        if mutasi == teks:
            hasil.append((nama, False,
                          "mutasinya tidak mengubah berkas — keadaan ini tidak "
                          "menguji apa pun"))
            continue
        open(ENGINE, "w", encoding="utf-8").write(mutasi)
        try:
            kode = jalankan()
        finally:
            open(ENGINE, "wb").write(asli)
        hasil.append((nama, kode == harap, f"exit={kode} (harap {harap})"))

    # Pemulihan diverifikasi byte-per-byte.
    pulih = open(ENGINE, "rb").read() == asli
    hasil.append(("sumber produksi pulih byte-per-byte", pulih,
                  "identik" if pulih else "BERBEDA — pulihkan manual"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'OK  ' if lolos else 'FAIL'} {nama} — {detail}")

    print()
    if gagal:
        print(f"Aturan 102: {len(gagal)} dari {len(hasil)} keadaan tidak sesuai.")
        return 1
    print(f"Aturan 102: {len(hasil)} keadaan sesuai harapan — gerbang berbunyi "
          f"pada setiap jalan menuju kamus fase yang tidak dibangun ulang.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
