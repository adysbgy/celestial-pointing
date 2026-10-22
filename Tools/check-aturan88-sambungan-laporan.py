#!/usr/bin/env python3
"""Aturan 88: LinkView wajib MERENDER keputusan LinkReport, bukan menulisnya sendiri.

Kenapa aturan ini ada.

`LinkReport` (`Packages/PointingKit/Sources/PointingKit/LinkReport.swift`) ada
justru karena isi `LinkView` dulu ditulis di badan `view` dan tidak satu pun
dari 86 aturan UI melihatnya: gerbang repo ini membaca **teks** berkas dan
**piksel** render, dan kolom yang tidak pernah ditulis tidak punya keduanya.

Memindahkan kolom ke fungsi murni **tidak menutup** celah itu sendirian. Uji
PointingKit membuktikan `LinkReport` benar; ia tidak bisa membuktikan bahwa
`LinkView` memanggilnya. Kalau view kembali menulis kolomnya sendiri — atau
memanggil `stateRows` lalu membuang hasilnya — seluruh 1065 uji PointingKit
tetap hijau dan tiga kolom itu bisa hilang lagi tanpa satu gerbang berbunyi.
Jadi aturan ini mengukur **sambungannya**, bukan isinya.

Yang diperiksa, dan kenapa persis itu:

1. `LinkView` memanggil `LinkReport.stateRows` DAN `LinkReport.calibrationRows`.
   Kedua bagian yang punya fungsi murni wajib lewat fungsi itu.

2. Hasil panggilan itu benar-benar dipakai oleh `ForEach` — bukan disimpan ke
   `_` atau `let _ =`. Pemakaian diukur dengan mencari `ForEach` yang
   memuat panggilan tersebut di dalam rentang tanda kurungnya.

3. Tidak ada lagi kolom laporan yang ditulis langsung. Bentuk cacatnya persis
   yang pernah dikirim: `row(TextLocalization.text(.linkRowYawOffset), ...)`
   di badan view. Setiap `row(` yang judulnya `link.row.*` adalah kolom yang
   ditulis tangan — dan itu dilarang, karena kolom seperti itu tidak diuji
   siapa pun.

Aturan ini sengaja **tidak** memeriksa `LinkView` lain atau view lain: ia
mengukur satu sambungan yang pernah putus, dan sambungan itu punya satu nama.
Melebarkannya ke seluruh `Apps/` akan membuatnya memeriksa tampilan yang
memang tidak punya fungsi murni untuk dipanggil, dan aturan yang berbunyi
untuk hal yang benar akan dimatikan orang.

Jalankan dari akar repo. Exit 0 = bersih, 1 = ada yang putus.
"""
import pathlib
import re
import sys

VIEW = pathlib.Path("Apps/PointAndKnowiOS/Sources/LinkView.swift")

# Setiap bagian laporan yang punya fungsi murni, beserta nama fungsinya.
WAJIB_DIPANGGIL = ["stateRows", "calibrationRows"]

# Judul baris yang dulu ditulis tangan di badan view. `row(...)` yang memakai
# salah satu kunci ini adalah kolom yang tidak diuji siapa pun.
#
# Daftarnya SENGAJA hanya kunci yang dimiliki `LinkReport` — kunci status
# tautan (`linkRowStatus`, `linkRowReachable`, …) dan kunci sampel
# (`linkRowRecorded`) memang ditulis di view dan bukan bagian laporan ini.
# Aturan yang berbunyi untuk hal yang benar akan dimatikan orang.
KUNCI_KOLOM_TANGAN = re.compile(
    r"\brow\s*\(\s*TextLocalization\s*\.\s*text\s*\(\s*\."
    r"(linkRowState|linkRowObject|linkRowConfidence|linkRowSigma"
    r"|linkRowDirection|linkRowRate|linkRowYawOffset|linkRowSpread"
    r"|linkRowReferenceCount|linkRowTime)\b")


def buang_komentar(isi):
    """Buang komentar supaya contoh di dokumentasi tidak dihitung sebagai kode."""
    isi = re.sub(r"/\*.*?\*/", "", isi, flags=re.S)
    return re.sub(r"//[^\n]*", "", isi)


def rentang_for_each(isi):
    """Rentang (mulai, selesai) badan setiap `ForEach { ... }` di berkas.

    Dipakai untuk membuktikan hasil `LinkReport.*Rows` benar-benar **dirender**:
    panggilannya harus berada di dalam badan sebuah `ForEach`. Panggilan yang
    hasilnya dibuang (`_ = ...`) atau disimpan ke variabel yang tak dipakai
    lolos dari pemeriksaan "ada panggilan" tapi tidak lolos dari ini.
    """
    rentang = []
    for m in re.finditer(r"\bForEach\s*\(", isi):
        buka = isi.find("{", m.end())
        if buka == -1:
            continue
        dalam = 0
        for i in range(buka, len(isi)):
            if isi[i] == "{":
                dalam += 1
            elif isi[i] == "}":
                dalam -= 1
                if dalam == 0:
                    rentang.append((m.start(), i))
                    break
    return rentang


def main():
    if not VIEW.exists():
        print(f"GAGAL {VIEW} tidak ada: Aturan 88 tidak mengukur apa pun,")
        print("      dan kolom laporan bisa kembali ditulis di badan view.")
        return 1

    isi = buang_komentar(VIEW.read_text(encoding="utf-8"))
    rentang = rentang_for_each(isi)
    masalah = []

    for fungsi in WAJIB_DIPANGGIL:
        pola = re.compile(rf"\bLinkReport\s*\.\s*{fungsi}\s*\(")
        panggilan = list(pola.finditer(isi))
        if not panggilan:
            masalah.append(
                f"LinkView tidak memanggil LinkReport.{fungsi} — bagian itu "
                f"kembali ditulis di badan view, dan tidak ada uji yang melihatnya.")
            continue
        # Setiap panggilan harus berada di dalam badan sebuah ForEach.
        for p in panggilan:
            if not any(mulai <= p.start() <= selesai for mulai, selesai in rentang):
                masalah.append(
                    f"panggilan LinkReport.{fungsi} tidak berada di dalam ForEach — "
                    f"hasilnya tidak dirender, jadi barisnya tidak sampai ke layar.")

    tangan = KUNCI_KOLOM_TANGAN.findall(isi)
    if tangan:
        masalah.append(
            f"{len(tangan)} kolom laporan ditulis langsung di LinkView "
            f"(row(TextLocalization.text(.linkRow…))) — kolom itu tidak diuji "
            f"siapa pun. Pakai LinkReport.")

    if masalah:
        for m in masalah:
            print(f"  - {m}")
        return 1

    print(f"Aturan 88: LinkView merender {len(WAJIB_DIPANGGIL)} bagian laporan "
          f"lewat LinkReport, tanpa kolom tulis tangan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
