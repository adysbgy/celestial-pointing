#!/usr/bin/env python3
"""Aturan 90: tidak ada jalur ekspor yang menggabung JSON dengan tangan.

Kenapa aturan ini ada.

Dua view membangun berkas pengganti saat encoding gagal dengan menggabung
string:

    let message = "{\\"error\\": \\"gagal meng-encode dataset: \\(error.localizedDescription)\\"}"

Itu bukan JSON. `localizedDescription` datang dari sistem dan boleh memuat
tanda kutip; satu kutip saja membuat berkas `.json` yang dibagikan **tidak
sah**, padahal namanya `experiment1-….json` dan penerimanya membukanya
sebagai dataset. Kerusakannya senyap: berkasnya ada, ukurannya wajar, baru
ketahuan saat dibuka.

Kedua jalur itu tinggal di badan view, yang tidak bisa dijalankan di Linux.
`ExportErrorDocumentTests` membuktikan penggantinya benar; ia tidak bisa
membuktikan bahwa view memakainya. Aturan ini mengukur sambungannya.

Yang diperiksa:

1. Setiap view yang membangun `JSONArchiveDocument` **wajib** memanggil
   `ExportErrorDocument.data(...)` di cabang `catch`-nya. View yang punya
   ekspor tapi tidak memakainya berarti masih menggabung string sendiri.

2. Tidak ada lagi literal JSON yang dibangun dengan interpolasi string.
   Bentuknya: string literal yang memuat `{` dan `\\"` sekaligus, dengan
   `\\(` di dalamnya — yaitu JSON yang disusun dari potongan. Literal JSON
   statis tanpa interpolasi tidak dilarang: ia tidak bisa rusak karena isi
   variabel.

3. Tidak ada `Data(...utf8)` yang menerima string berawalan `{"`. Itu bentuk
   persis cacat yang pernah dikirim, terlepas dari namanya.

Aturan ini sengaja **tidak** memeriksa seluruh `Apps/`: ia mengukur satu
bentuk cacat yang punya satu nama. Melebarkannya ke setiap pemakaian string
akan membuatnya berbunyi untuk hal yang benar, dan aturan seperti itu
dimatikan orang.

Jalankan dari akar repo. Exit 0 = bersih, 1 = ada yang putus.
"""
import pathlib
import re
import sys

APPS = pathlib.Path("Apps")

# Berkas yang membangun JSONArchiveDocument — yaitu punya jalur ekspor.
PEMBANGUN_EKSPOR = re.compile(r"\bJSONArchiveDocument\s*\(")

# Literal string yang memuat JSON hasil interpolasi: ada `{`, ada `\"`, dan
# ada `\(`. Urutannya tidak dipatok; yang dicari keberadaan ketiganya.
LITERAL_JSON_INTERPOLASI = re.compile(
    r'"(?:[^"\\]|\\.)*\{(?:[^"\\]|\\.)*\\"(?:[^"\\]|\\.)*\\\((?:[^"\\]|\\.)*"',
    re.S)

# `Data("...utf8")` yang isinya JSON — bentuk cacat aslinya.
DATA_DARI_JSON = re.compile(r'\bData\s*\(\s*"(?:[^"\\]|\\.)*\{\\?"[^)]*utf8', re.S)


def buang_komentar(isi):
    """Buang komentar supaya contoh di dokumentasi tidak dihitung sebagai kode."""
    isi = re.sub(r"/\*.*?\*/", "", isi, flags=re.S)
    return re.sub(r"//[^\n]*", "", isi)


def main():
    if not APPS.is_dir():
        print(f"GAGAL {APPS} tidak ada: Aturan 90 tidak mengukur apa pun,")
        print("      dan jalur ekspor bisa kembali menggabung JSON dengan tangan.")
        return 1

    berkas = sorted(APPS.rglob("*.swift"))
    if not berkas:
        print("GAGAL tidak ada berkas .swift di Apps/: Aturan 90 tidak mengukur apa pun.")
        return 1

    masalah = []
    pembangun = 0

    for path in berkas:
        isi = buang_komentar(path.read_text(encoding="utf-8"))

        if PEMBANGUN_EKSPOR.search(isi):
            pembangun += 1
            if "ExportErrorDocument" not in isi:
                masalah.append(
                    f"{path} membangun JSONArchiveDocument tanpa memakai "
                    f"ExportErrorDocument — cabang gagal-encode-nya menggabung "
                    f"JSON sendiri, dan berkasnya bisa tidak sah.")

        for m in LITERAL_JSON_INTERPOLASI.finditer(isi):
            baris = isi[:m.start()].count("\n") + 1
            masalah.append(
                f"{path}:{baris} membangun JSON dengan interpolasi string — "
                f"isi variabel boleh memuat kutip dan merusak berkasnya. "
                f"Pakai ExportErrorDocument.data(message:).")

        for m in DATA_DARI_JSON.finditer(isi):
            baris = isi[:m.start()].count("\n") + 1
            masalah.append(
                f"{path}:{baris} membuat Data dari literal JSON — bentuk cacat "
                f"yang tidak bisa dijamin sah. Pakai ExportErrorDocument.data(message:).")

    if pembangun == 0:
        # Nol pembangun berarti aturan ini tidak mengukur apa pun. Berkas
        # ekspor yang hilang lebih mungkin berarti jalurnya dipindah atau
        # diganti nama daripada produknya berhenti mengekspor — jadi ini
        # dilaporkan, bukan dilewati diam-diam.
        print("GAGAL tidak ada view yang membangun JSONArchiveDocument: "
              "Aturan 90 tidak mengukur apa pun (jalur ekspor hilang atau berganti nama?).")
        return 1

    if masalah:
        for m in masalah:
            print(f"  - {m}")
        return 1

    print(f"Aturan 90: {pembangun} jalur ekspor memakai ExportErrorDocument, "
          f"tanpa JSON gabungan string.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
