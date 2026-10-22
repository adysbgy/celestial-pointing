#!/usr/bin/env python3
"""Aturan 91: setiap `@main` App wajib memasang sumber terjemahan di `init()`.

Kenapa aturan ini ada.

`TextLocalization` di `PointingKit` menghasilkan label yang **paling sering
dibaca sekilas** ("Siap", "Arahkan", "Terkunci", "Kurang yakin", "Sensor
mati"). Label itu tidak pernah muncul sebagai literal `Text("...")` di
`Apps/`, jadi tidak ada gerbang UI lain yang bisa melihatnya — aturan 4
tetap hijau karena memang tidak ada literalnya. Yang membuatnya berbahasa
Inggris hanyalah satu hal: sumber terjemahan yang dipasang saat app mulai.

Sampai siklus ini, satu-satunya penjaga bahwa pemasangan itu ada adalah
**kalimat di docstring**. Diukur: menghapus panggilan itu dari **kedua**
entry point app membuat `swift-ui-lint.sh` (90 aturan),
`swift-typecheck.sh`, dan seluruh 1301 uji tetap **hijau** — sementara di
perangkat setiap label tetap Bahasa Indonesia di semua bahasa, tanpa satu
pun galat. Itu kelas cacat yang sama dengan yang berulang di repo ini: kode
yang benar di paket, tidak tersambung di app.

Kenapa `init()`, bukan tempat lain.

Label dibaca sebelum `body` pertama selesai dirender. Sumber yang dipasang
dari dalam `body`, dari `.task`, atau dari layar yang dibuka belakangan
datang **terlambat**: label pertama sudah jatuh ke nilai bawaan, dan tidak
ada yang memperbaikinya karena tidak ada yang menggambar ulang. `init()`
milik tipe `@main` adalah satu-satunya titik yang dijamin berjalan sebelum
tampilan pertama.

**Kenapa dua simbol, bukan satu.** Repo ini punya dua target dengan dua
bridge: app memasang `LocalizationBridge.install()`, sedangkan complication
memasang `ComplicationLocalization.install()` karena ia target terpisah yang
tidak menarik `Apps/Shared` dan `Bundle.main`-nya menunjuk bundel widget
sendiri. Menuntut satu nama tertentu akan membuat aturan ini berbunyi untuk
sambungan yang justru benar — dan aturan seperti itu dimatikan orang. Yang
diukur adalah **invariannya**: ada sumber terjemahan yang dipasang di
`init()` sebelum layar pertama.

Yang diperiksa:

1. Setiap berkas yang memuat `@main` wajib memuat salah satu pemasangan di
   `SUMBER_TERJEMAHAN`. Aturannya per-berkas, bukan per-struct: `@main`
   menandai tepat satu tipe per target, dan memisahkan berkas itu dari
   pemanggilnya justru bentuk kesalahan yang ingin dicegah.

2. Pemasangan itu harus berada **di dalam badan `init(...)`**, bukan di
   `body` atau `.task`. Kurung kurawal dihitung seimbang supaya `init()` yang
   memuat closure bersarang tidak terpotong di kurawal pertama.

3. Nol `@main` = GAGAL, bukan lolos. Entry point yang hilang atau berganti
   nama lebih mungkin berarti aturan ini berhenti mengukur daripada app
   berhenti punya entry point.

Batasnya jujur: ini sapuan **teks**, bukan pemeriksaan tipe — sama seperti
aturan UI lain di repo ini. Ia tidak bisa membuktikan `Bundle` benar-benar
membaca `.xcstrings` di perangkat, dan tidak bisa membuktikan katalog ikut
terbawa ke bundel target. Ia membuktikan **sambungannya ada dan berada di
tempat yang dijanjikan** — bagian yang tadinya tidak diukur siapa pun.

Jalankan dari akar repo. Exit 0 = bersih, 1 = ada yang putus.
"""
import pathlib
import re
import sys

APPS = pathlib.Path("Apps")

MAIN = re.compile(r"@main\b")

# Pemasangan sumber terjemahan yang dikenal. Dua target, dua bridge.
SUMBER_TERJEMAHAN = (
    "LocalizationBridge.install()",
    "ComplicationLocalization.install()",
)


def buang_komentar(isi):
    """Buang komentar supaya docstring yang menyebut aturan ini tidak dihitung."""
    isi = re.sub(r"/\*.*?\*/", "", isi, flags=re.S)
    return re.sub(r"//[^\n]*", "", isi)


def badan_init(isi):
    """Kembalikan badan setiap deklarasi `init(...)` di berkas ini."""
    badan = []
    for m in re.finditer(r"\binit\s*\(", isi):
        # `.init(` adalah pemanggilan penginisialisasi, bukan deklarasi:
        # `.sheet(isPresented: .init(get:...))` memakai bentuk itu dan badannya
        # bukan badan `init` milik tipe @main.
        if m.start() > 0 and isi[m.start() - 1] == ".":
            continue
        # Kurung pembuka sudah dimakan regex, jadi kedalamannya mulai dari 1.
        depth, i = 1, m.end()
        while i < len(isi):
            c = isi[i]
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        if i >= len(isi):
            continue
        brace = isi.find("{", i)
        if brace == -1:
            continue
        # `init()` tanpa badan (deklarasi protokol) bukan tempat memasang apa pun.
        antara = isi[i + 1:brace]
        if "}" in antara or ";" in antara:
            continue
        depth, j = 0, brace
        while j < len(isi):
            if isi[j] == "{":
                depth += 1
            elif isi[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        badan.append(isi[brace:j + 1])
    return badan


def main():
    if not APPS.is_dir():
        print(f"GAGAL {APPS} tidak ada: Aturan 91 tidak mengukur apa pun,")
        print("      dan sumber terjemahan bisa lepas tanpa satu pun galat.")
        return 1

    berkas = sorted(APPS.rglob("*.swift"))
    if not berkas:
        print("GAGAL tidak ada berkas .swift di Apps/: Aturan 91 tidak mengukur apa pun.")
        return 1

    masalah = []
    entry_points = 0

    for path in berkas:
        isi = buang_komentar(path.read_text(encoding="utf-8"))
        if not MAIN.search(isi):
            continue
        entry_points += 1

        dipakai = [s for s in SUMBER_TERJEMAHAN if s in isi]
        if not dipakai:
            masalah.append(
                f"{path} punya `@main` tanpa sumber terjemahan "
                f"({' / '.join(SUMBER_TERJEMAHAN)}) — label dari PointingKit "
                f"akan tampil Bahasa Indonesia di semua bahasa, tanpa galat apa pun.")
            continue

        badan = badan_init(isi)
        if not badan:
            masalah.append(
                f"{path} memasang {', '.join(dipakai)} tapi tidak di dalam "
                f"`init()` — tidak ada badan `init(...)` yang ditemukan di "
                f"berkas ini. Label bisa terbaca sebelum sumbernya terpasang.")
            continue
        if not any(s in b for s in dipakai for b in badan):
            masalah.append(
                f"{path} memasang {', '.join(dipakai)} di luar `init()` — "
                f"kalau ia berada di `body`/`.task`, label pertama sudah "
                f"terbaca sebelum sumbernya terpasang.")

    if entry_points == 0:
        print("GAGAL tidak ada berkas dengan `@main` di Apps/: Aturan 91 tidak")
        print("      mengukur apa pun (entry point hilang atau berganti nama?).")
        return 1

    if masalah:
        for m in masalah:
            print(f"  - {m}")
        return 1

    print(f"Aturan 91: {entry_points} entry point memasang sumber terjemahan "
          f"di dalam init().")
    return 0


if __name__ == "__main__":
    sys.exit(main())
