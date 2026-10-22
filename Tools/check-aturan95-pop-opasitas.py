#!/usr/bin/env python3
"""Aturan 95: animasi "muncul" harus benar-benar menggerakkan kedua propertinya.

Kenapa aturan ini ada.

Kartu jam dan panel iPhone sama-sama memegang dua `@State` untuk pop saat
kunci baru tiba: `appearScale` dan `appearOpacity`. Keduanya dipasang ke view
lewat `.scaleEffect(appearScale)` dan `.opacity(appearOpacity)`.

Selama ini hanya **satu** dari keduanya yang bergerak. `appearOpacity` lahir
sebagai `= 1`, dan di dalam `withAnimation` ditulis `appearOpacity = 1` lagi —
animasi yang kedua ujungnya nilai yang sama. Core Animation tidak punya
perubahan untuk dianimasikan, jadi `.opacity` selalu 1 dan yang terlihat
pengguna hanya pembesaran. Docstring di kedua berkas sudah menjanjikan
"memudar + membesar" sejak lama, jadi dokumentasinya menggambarkan perilaku
yang tidak ada.

Kenapa tidak ada gerbang yang menangkapnya, dan itu bukan kebetulan:

  - `swift-ui-lint.sh` tidak punya aturan yang membaca opasitas sama sekali.
    Aturan 7 memeriksa **adanya** penjaga reduce-motion, bukan apakah geraknya
    menggerakkan sesuatu.
  - `Tools/bukti-mutasi-gerak-angka.py` memutasi `appearScale` (0.90/0.30/
    1.60) dan `minimumInterval`. Opasitas tidak pernah disebut, jadi tidak ada
    keadaan cacat yang mengukurnya.
  - Compiler diam: `appearOpacity = 1` sah secara tipe di kedua sisi.
  - Teks di layar tidak berubah, jadi tidak ada pemeriksaan teks yang bisa
    melihatnya.

Ini kelas cacat yang sudah berulang di repo ini: **nilai yang tidak pernah
diperiksa adalah nilai yang boleh berarti apa saja**. Bedanya dengan
`settledScale` hanya bahwa yang satu kelihatan saat dua layar dibandingkan,
dan yang satu tidak kelihatan sama sekali.

Yang diperiksa, dan kenapa berbentuk begitu.

1. Nilai diam `@State` opasitas **harus** `MotionPolicy.LockArrival.
   settledOpacity`, bukan literal `1`. Literal `1` adalah bentuk asli cacat
   ini, dan bentuk yang paling mungkin ditulis ulang orang yang menyalin baris
   tetangganya (`appearScale: CGFloat = 1`).

2. Di dalam animasi, opasitas harus diberi **dua** nilai yang berbeda:
   `peakOpacity` lebih dulu, lalu `settledOpacity`. Hanya `peakOpacity`
   tanpa tahap tenang meninggalkan kartu pada opasitas puncak selamanya —
   kartu yang pernah terkunci jadi lebih pudar daripada kartu yang tidak
   pernah. Hanya `settledOpacity` adalah cacat aslinya: tidak ada perubahan.

   Urutannya penting dan karena itu diukur: `peakOpacity` **sesudah**
   `settledOpacity` membuat pegas kedua menimpa yang pertama, dan hasil akhir
   kartu bergantung pada urutan internal SwiftUI alih-alih pada nilai yang
   ditulis di sini.

3. Nol temuan = GAGAL. Kalau nama `appearOpacity` hilang dari salah satu
   berkas, aturan ini berhenti mengukur — dan aturan yang berhenti mengukur
   tanpa berbunyi lebih berbahaya daripada tidak ada aturan. Lebih mungkin
   seseorang mengganti nama variabelnya daripada kedua app berhenti punya
   animasi muncul.

Batasnya jujur: ini sapuan **teks**, bukan pemeriksaan render. Ia tidak bisa
membuktikan bahwa `peakOpacity` terasa enak, dan tidak bisa membuktikan
SwiftUI benar-benar menganimasikan transisinya — itu di luar jangkauan Linux.
Yang dibuktikan: kedua ujung animasi **berbeda dan berurutan**, dan nilainya
datang dari model yang diuji (`testPopActuallyMovesOpacity` di
`LockArrivalMotionTests`).
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

JAM = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
IPHONE = "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"

#: Nilai diam yang sah: dari model, bukan literal.
DIAM_SAH = "MotionPolicy.LockArrival.settledOpacity"
#: Nilai puncak yang sah di dalam animasi.
PUNCAK_SAH = "MotionPolicy.LockArrival.peakOpacity"


def baca(rel):
    path = os.path.join(ROOT, rel)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def tanpa_komentar(source):
    """Buang komentar `//` supaya prosa tidak terbaca sebagai kode.

    **Bukan kerapian.** Versi pertama pemeriksa ini membaca kalimat docstring
    yang berbunyi ``menulis `appearOpacity = 1` `` sebagai penetapan sungguhan,
    lalu melaporkan temuan yang tidak ada di kode. Aturan yang berbunyi untuk
    hal benar akan dimatikan orang, dan aturan yang dimatikan tidak menjaga
    apa pun. Komentar juga satu-satunya tempat di berkas ini yang boleh
    menyebut bentuk lama tanpa menjadi bentuk lama itu.
    """
    baris = []
    for satu in source.splitlines():
        # `//` di dalam string literal akan ikut terpotong, tapi berkas yang
        # diukur tidak punya URL/string berisi `//` di dekat `appearOpacity`;
        # dan kalau nanti punya, pemeriksaan akan GAGAL (bukan lolos), jadi
        # arah kelirunya aman.
        idx = satu.find("//")
        baris.append(satu if idx < 0 else satu[:idx])
    return "\n".join(baris)


def deklarasi_diam(source):
    """Nilai awal `@State private var appearOpacity`, atau None."""
    pola = re.compile(
        r"@State\s+private\s+var\s+appearOpacity\s*:\s*\w+\s*=\s*([^\n]+)")
    cocok = pola.search(source)
    return cocok.group(1).strip() if cocok else None


def penetapan(source):
    """Semua nilai yang diberikan ke `appearOpacity`, berurutan.

    `appearOpacity` yang muncul di `.opacity(appearOpacity)` bukan penetapan,
    jadi ia tersaring oleh `=` yang wajib ada sesudahnya.
    """
    pola = re.compile(r"appearOpacity\s*=\s*([^\n]+)")
    return [m.group(1).strip() for m in pola.finditer(source)]


def periksa(sumber, label, hasil):
    if sumber is None:
        hasil.append((f"{label}: berkas terbaca", False,
                      "berkas tidak ditemukan — aturan tidak mengukur apa pun"))
        return

    kode = tanpa_komentar(sumber)

    diam = deklarasi_diam(kode)
    hasil.append((
        f"{label}: opasitas diam dari model, bukan literal",
        diam is not None and diam.startswith(DIAM_SAH),
        f"deklarasi = {diam!r}" if diam is not None
        else "deklarasi `@State private var appearOpacity` TIDAK ditemukan "
             "— aturan berhenti mengukur, jadi ini GAGAL, bukan lolos"))

    tetapan = penetapan(kode)
    puncak = [i for i, t in enumerate(tetapan) if t.startswith(PUNCAK_SAH)]
    tenang = [i for i, t in enumerate(tetapan) if t.startswith(DIAM_SAH)]

    hasil.append((
        f"{label}: animasi mencapai nilai puncak",
        len(puncak) == 1,
        f"penetapan: {tetapan}" if tetapan
        else "tidak ada penetapan `appearOpacity =` — animasinya tidak "
             "menggerakkan opasitas sama sekali"))

    hasil.append((
        f"{label}: animasi kembali ke opasitas diam",
        len(tenang) == 1,
        f"penetapan: {tetapan}" if tetapan
        else "kartu akan tinggal pada opasitas puncak selamanya"))

    # Urutan: puncak dulu, baru tenang. Kalau dibalik, pegas kedua menimpa
    # yang pertama dan hasil akhirnya bergantung pada urutan internal SwiftUI.
    hasil.append((
        f"{label}: puncak mendahului keadaan tenang",
        bool(puncak) and bool(tenang) and puncak[0] < tenang[0],
        f"indeks puncak {puncak}, indeks tenang {tenang}"))


def main():
    hasil = []
    for rel, label in ((JAM, "jam"), (IPHONE, "iPhone")):
        periksa(baca(rel), label, hasil)

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        tanda = "ok  " if lolos else "FAIL"
        print(f"{tanda} {nama} — {detail}")

    if gagal:
        print()
        print(f"Aturan 95: {len(gagal)} dari {len(hasil)} pemeriksaan gagal.")
        print("Animasi 'muncul' yang kedua ujungnya sama berjalan tanpa")
        print("menggerakkan satu piksel. Perbaiki nilainya di model")
        print("(MotionPolicy.LockArrival), jangan longgarkan aturannya.")
        return 1

    print()
    print(f"Aturan 95: {len(hasil)} pemeriksaan lolos — pop opasitas di jam "
          "dan iPhone bergerak dari puncak ke keadaan tenang, dan kedua "
          "ujungnya dari model.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
