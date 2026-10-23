#!/usr/bin/env python3
"""Aturan 100: glif lencana "?" harus **digambar** view, bukan hanya disebut.

Kenapa aturan ini ada.

Siklus ini memindahkan bentuk glif tanda tanya dari delapan literal di
`drawCandidateMarker` ke `VisualFrame.CandidateMarker.glyph`, dan menambah
dua uji Swift yang menguji bentuknya di Linux. Itu perbaikan yang benar:
bentuknya sekarang satu sumber, dan lengkungnya tidak bisa diluruskan tanpa
membuat uji merah.

Tetapi ia memindahkan cacatnya, bukan menutupnya. Diukur, bukan disangka —
badan `drawCandidateMarker` diubah supaya **tidak menggambar garis glif sama
sekali** (loop titik diganti daftar kosong, tetes dibiarkan):

    ./swift-ui-lint.sh                      exit 0, 100 aturan, nol merah
    Tools/bukti-mutasi-glif-lencana.py      exit 0 (ia mengukur port Python)
    uji Swift glif                         hijau (mereka menguji model)

Nol. Bentuk glif sudah benar dan teruji, dan app tetap bisa berhenti
menggambarnya tanpa satu pun gerbang berbunyi — karena setiap gerbang yang
ada mengukur **model** atau **port Python**, dan tidak satu pun membaca
badan view.

Kenapa bukan memperluas Aturan 98. Aturan 98 memeriksa **irisan** fungsi
model yang juga disebut port Python, dan menuntut namanya muncul sebagai
nilai di `Apps/`. `glyph` adalah *computed property* pada struct bersarang,
bukan `public static func`, jadi ia tidak pernah masuk irisan itu. Dan
seandainya masuk, Aturan 98 hanya menuntut nama itu **muncul** — sedangkan
cacat di sini adalah nama itu muncul lalu hasilnya dibuang, yang sudah
ditutup Aturan 98 untuk fungsi dan tidak untuk properti.

Kenapa bukan menambah keadaan di `bukti-mutasi-glif-lencana.py`. Harness
itu memutasi `Tools/render-visuals.py` dan mengukur piksel port. Memutasi
`Apps/` di sana akan membuat harness yang mengukur dua hal berbeda dengan
dua metodologi berbeda, dan ia tidak bisa: view SwiftUI tidak bisa
dijalankan di Linux. Yang bisa dibaca dari sini hanya **bentuk kode**-nya.

Yang diperiksa, dan kenapa berbentuk begitu.

1. `marker.glyph` (atau nama properti bentuk yang menggantikannya) dibaca
   view menjadi sebuah nilai — bukan disebut di komentar.
2. Nilai itu benar-benar **dipakai menggambar**: minimal satu
   `Path`/`context.stroke`/`context.fill` di badan yang sama memakai
   titik-titik glif. Diperiksa dengan mencari `.points` dari variabel yang
   menampung bentuk glif.
3. Tetesnya digambar dari `dotCenter`/`dotRadius` model, bukan dari angka
   yang ditulis ulang di view. Kalau view menghitung pusat tetes sendiri,
   model dan layar bisa berbeda pendapat tanpa gerbang berbunyi.
4. Nol temuan = GAGAL. Kalau `marker.glyph` hilang dari view, aturan ini
   berhenti mengukur — dan aturan yang diam lebih berbahaya daripada tidak
   ada aturan.

Yang TIDAK diklaim. Ini sapuan **teks**, bukan render: ia tidak bisa
membuktikan glifnya terlihat seperti tanda tanya di layar (itu milik uji
Swift bentuknya dan gerbang piksel port), dan tidak bisa membuktikan
`context.stroke` benar-benar menghasilkan piksel di watchOS. Yang dijaga:
garis dari model ke kanvas tidak bisa diputus tanpa gerbang merah.
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW = "Apps/Shared/CelestialVisualView.swift"
MODEL = "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift"


def tanpa_komentar(source: str) -> str:
    """Buang komentar `//` supaya prosa tidak terbaca sebagai kode."""
    return re.sub(r"//[^\n]*", "", source)


def badan_fungsi(source: str, nama: str) -> str:
    """Badan fungsi `nama` dari `func nama(` sampai penutup sejajar.

    Penutupnya dicari dengan menghitung kurung kurawal, bukan dengan regex
    malas: badan fungsi ini berisi banyak `{}` (Path, CGRect, closure), dan
    regex malas akan berhenti di yang pertama — lalu aturan ini mengukur
    potongan yang salah dan melaporkan lolos.
    """
    pola = re.compile(r"\bfunc\s+" + re.escape(nama) + r"\s*\(")
    cocok = pola.search(source)
    if not cocok:
        return ""
    awal = source.find("{", cocok.end())
    if awal < 0:
        return ""
    dalam = 0
    for i in range(awal, len(source)):
        if source[i] == "{":
            dalam += 1
        elif source[i] == "}":
            dalam -= 1
            if dalam == 0:
                return source[awal:i + 1]
    return ""


def main() -> int:
    try:
        view = open(os.path.join(ROOT, VIEW), encoding="utf-8").read()
        model = open(os.path.join(ROOT, MODEL), encoding="utf-8").read()
    except OSError as exc:
        print(f"FAIL berkas tidak terbaca: {exc}")
        return 1

    hasil: list[tuple[str, bool, str]] = []

    # Model harus masih menyediakan bentuknya. Kalau tidak, aturan ini tidak
    # punya apa pun untuk diukur, dan itu GAGAL, bukan lolos.
    model_punya_bentuk = bool(re.search(r"\bvar\s+glyph\s*:\s*Glyph\b", model))
    hasil.append((
        "model menyediakan bentuk glif",
        model_punya_bentuk,
        "`var glyph: Glyph` ada di model"
        if model_punya_bentuk else
        "`var glyph: Glyph` TIDAK ada di model — Aturan 100 berhenti "
        "mengukur, jadi ini GAGAL, bukan lolos"))

    kode = tanpa_komentar(view)

    # (1) View membaca bentuknya menjadi nilai.
    pola_baca = re.compile(r"\blet\s+(\w+)\s*=\s*[\w.]*\bglyph\b")
    cocok = pola_baca.search(kode)
    hasil.append((
        "view membaca bentuk glif dari model",
        cocok is not None,
        f"variabel penampung = {cocok.group(1)!r}" if cocok else
        "tidak ada `let X = ….glyph` di view — bentuknya teruji di model "
        "dan tidak pernah sampai ke kanvas"))

    if cocok is None:
        for nama, lolos, detail in hasil:
            print(f"{'ok  ' if lolos else 'FAIL'} {nama} — {detail}")
        print()
        print("Aturan 100: bentuk glif tidak dibaca view. Aturan ini tidak "
              "bisa mengukur lebih jauh.")
        return 1

    variabel = cocok.group(1)
    badan = badan_fungsi(kode, "drawCandidateMarker")
    if not badan:
        # Nama fungsi bisa berubah; jatuhkan ke seluruh berkas supaya aturan
        # ini tetap mengukur sesuatu, dan catat bahwa cakupannya melebar.
        badan = kode
        cakupan = "seluruh berkas (badan drawCandidateMarker tidak ditemukan)"
    else:
        cakupan = "badan drawCandidateMarker"

    # (2) Titik-titiknya dipakai menggambar.
    pola_titik = re.compile(re.escape(variabel) + r"\.points\b")
    hasil.append((
        "titik glif dipakai menggambar",
        pola_titik.search(badan) is not None,
        f"`{variabel}.points` dipakai di {cakupan}" if pola_titik.search(badan)
        else f"`{variabel}.points` TIDAK dipakai di {cakupan} — view membaca "
             "bentuknya lalu membuangnya; glif tidak tergambar"))

    # (3) Tetesnya dari model, bukan angka tulis-ulang di view.
    pakai_dot_center = re.search(re.escape(variabel) + r"\.dotCenter\b", badan)
    pakai_dot_radius = re.search(re.escape(variabel) + r"\.dotRadius\b", badan)
    hasil.append((
        "tetes glif dari model",
        pakai_dot_center is not None and pakai_dot_radius is not None,
        f"dotCenter={'ya' if pakai_dot_center else 'TIDAK'}, "
        f"dotRadius={'ya' if pakai_dot_radius else 'TIDAK'} di {cakupan}"))

    # (4) Ada pemanggilan gambar yang memakai jalur itu. Tanpa ini, titik
    # boleh dipakai untuk menghitung sesuatu (mis. panjang) lalu tidak
    # pernah digores.
    gambar = re.search(r"\.(stroke|fill)\s*\(", badan)
    hasil.append((
        "jalur glif benar-benar digores",
        gambar is not None,
        f"`{gambar.group(1)}` dipanggil di {cakupan}" if gambar else
        "tidak ada `.stroke(`/`.fill(` di badan — titiknya dihitung, "
        "tidak digambar"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'ok  ' if lolos else 'FAIL'} {nama} — {detail}")

    if gagal:
        print()
        print(f"Aturan 100: {len(gagal)} dari {len(hasil)} pemeriksaan gagal.")
        print("Bentuk glif ada di model, teruji di Linux, dan tidak sampai ke")
        print("kanvas. Gambar glifnya di view dari `marker.glyph`; jangan")
        print("menulis ulang bentuknya di sana.")
        return 1

    print()
    print(f"Aturan 100: {len(hasil)} pemeriksaan lolos — glif \"?\" dibaca")
    print("dari model, digores, dan tetesnya memakai titik dari model.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
