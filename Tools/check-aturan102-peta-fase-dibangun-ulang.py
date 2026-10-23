#!/usr/bin/env python3
"""Aturan 102: peta fase planet wajib dibangun ulang, bukan ditambahi.

Kenapa aturan ini ada.

`PointingEngine.refreshSkyContext` mengisi tiga kamus yang sejajar:

    planetPhases             fraksi iluminasi planet dalam
    planetWaxing             arah membesar/mengecil
    planetBrightLimbAngles   sudut sisi terang

Docstring `planetWaxing` menyatakan janjinya dengan kalimat tegas: "Sejajar
dengan `planetPhases`, dan diisi dari sampel efemeris yang sama", dan
docstring `planetBrightLimbAngles` menambahkan akibatnya bila janji itu
dilanggar — "Ketidakcocokan keduanya menghasilkan sabit dengan lebar dan arah
dari dua menit berbeda".

Diukur pada pohon ini, janji itu **tidak** berlaku untuk ketiganya:

    planetPhases             whole-assign=1  subscript-write=0
    planetWaxing             whole-assign=0  subscript-write=1
    planetBrightLimbAngles   whole-assign=1  subscript-write=0

Dua kamus dibangun di variabel lokal lalu **menggantikan** isi properti, jadi
entri yang tidak terisi pada sampel kali ini ikut hilang — itulah arti "tidak
diketahui". `planetWaxing` tidak begitu: ia hanya pernah **ditambahi**
`planetWaxing[planet] = waxing`. Entri yang berhasil dihitung sekali tinggal
di sana selamanya, karena tidak ada satu baris pun yang mengosongkannya.

Akibatnya bukan teoretis. Bila `isPlanetWaxing` mengembalikan `nil` pada
sampel berikutnya (efemeris gagal sesaat, atau planet itu tidak lagi
berfase), `planetPhases` kehilangan Venus dan `planetBrightLimbAngles` juga —
tetapi `planetWaxing` **masih memegang arah dari 30 detik lalu**. Lalu
`phaseGeometry(waxing:)` memasangkan fraksi yang segar dengan arah yang basi.
Tepat di sekitar elongasi 180° — satu-satunya tempat arah itu berbalik, dan
karena itu satu-satunya tempat ia paling salah — sabitnya menghadap ke sisi
yang keliru.

Kenapa tidak ada uji yang menangkapnya: kamus-kamus ini hidup di
`Apps/Shared/PointingEngine.swift`, yang mengimpor `Combine` dan `@MainActor`
sehingga tidak bisa dikompilasi di Linux. Seluruh uji fase di `PointingKit`
menguji **rumus** (`phaseGeometry`, `fractionForPhase`), bukan **pengisi**
kamusnya. Dan tidak satu pun dari 101 aturan UI membaca fungsi ini — Aturan 31
memeriksa *kunci* yang dipakai saat membaca (`$0`, bukan `.venus`), bukan
apakah isinya pernah dikosongkan.

Bentuk yang diperiksa, dan kenapa begitu.

Daftar kamusnya **diturunkan** dari deklarasi di `PointingEngine.swift`
(`private var <nama>: [CelestialVisual.Planet: …]`), bukan ditulis tangan.
Daftar tangan akan basi pada kamus keempat, dan justru kamus keempat itu yang
paling mungkin lupa dibangun ulang — alasan yang sama dengan Aturan 98/101.

Untuk setiap kamus yang **dibaca** di `visualForDisplayedObject`:

1. `refreshSkyContext` wajib memuat penugasan **utuh** `nama = …`.
2. `refreshSkyContext` **tidak boleh** memuat tulisan subskrip `nama[ … ] = …`.
   Tulisan subskrip adalah bentuk cacatnya: ia menambah, tidak menggantikan.

Yang TIDAK diklaim. Ini sapuan **teks**, bukan eksekusi: ia tidak membuktikan
kamusnya berisi nilai yang benar, dan tidak bisa menilai apakah sabit di layar
menghadap arah yang benar — itu milik gerbang piksel port. Yang dijaga:
**bentuk pengisiannya** tidak bisa kembali menjadi "tambahi saja" tanpa gerbang
merah. Ia juga tidak memeriksa `PointingKit` sebagai pohon yang dikompilasi,
hanya sebagai teks — sama seperti Aturan 101.
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = "Apps/Shared/PointingEngine.swift"

#: Nama fungsi tempat kamus **dibaca** untuk digambar.
READER = "public var visualForDisplayedObject"
#: Nama fungsi tempat kamus **diisi**.
FILLER = "public func refreshSkyContext"

#: Deklarasi kamus: `private var <nama>: [CelestialVisual.Planet: <tipe>] = [:]`
DECL = re.compile(
    r"^[ \t]*private\s+var\s+(\w+)\s*:\s*\[\s*CelestialVisual\.Planet\s*:",
    re.M)


def tanpa_komentar(source: str) -> str:
    """Buang komentar `//` supaya prosa tidak terbaca sebagai kode.

    Wajib, bukan kerapian: docstring di berkas ini sendiri menyebut
    `planetWaxing[planet] = waxing` sebagai bentuk yang **salah**. Tanpa
    penyaringan, prosa itu terbaca sebagai tulisan subskrip dan gerbangnya
    menuduh kode yang benar.
    """
    return re.sub(r"//[^\n]*", "", source)


def badan(source: str, jangkar: str) -> str:
    """Isi fungsi mulai dari `jangkar`, dibatasi penutup kurawalnya sendiri.

    Menyalin pendekatan `badan()` di `check-aturan101-ciri-planet-tersambung.py`:
    kurung buka pertama sesudah jangkar adalah pembuka badannya. Regex malas
    akan berhenti di `{}` pertama milik literal kamus `[:]` dan aturan ini
    akan mengukur potongan yang salah.
    """
    if jangkar not in source:
        return ""
    mulai = source.index(jangkar) + len(jangkar)
    buka = source.find("{", mulai)
    if buka < 0:
        return ""
    depth, i = 1, buka + 1
    while i < len(source) and depth:
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
        i += 1
    return source[buka:i]


def main() -> int:
    try:
        mentah = open(os.path.join(ROOT, ENGINE), encoding="utf-8").read()
    except OSError as exc:
        print(f"FAIL berkas tidak terbaca: {exc}")
        return 1

    code = tanpa_komentar(mentah)
    hasil: list[tuple[str, bool, str]] = []

    # (1) Daftar kamusnya terbaca dari deklarasi. Nol temuan = GAGAL: kalau
    # parser berhenti mengenali deklarasinya, aturan ini akan melaporkan hijau
    # tanpa mengukur apa pun.
    kamus = DECL.findall(code)
    hasil.append((
        "kamus fase planet terbaca dari deklarasi",
        len(kamus) >= 1,
        f"kamus: {kamus}" if kamus else
        "tidak ada `private var <nama>: [CelestialVisual.Planet: …]` — Aturan "
        "102 berhenti mengukur, jadi ini GAGAL, bukan lolos"))

    if not kamus:
        for nama, lolos, detail in hasil:
            print(f"{'ok  ' if lolos else 'FAIL'} {nama} — {detail}")
        print()
        print("Aturan 102: daftar kamusnya tidak terbaca, aturan ini tidak "
              "bisa mengukur lebih jauh.")
        return 1

    pengisi = badan(code, FILLER)
    pembaca = badan(code, READER)

    if not pengisi:
        hasil.append(("badan refreshSkyContext terbaca", False,
                      f"`{FILLER}` tidak ditemukan — aturan tidak mengukur "
                      "apa pun, jadi ini GAGAL"))
    if not pembaca:
        hasil.append(("badan visualForDisplayedObject terbaca", False,
                      f"`{READER}` tidak ditemukan — aturan tidak mengukur "
                      "apa pun, jadi ini GAGAL"))

    # (2) Setiap kamus yang dibaca wajib dibangun ulang saat diisi.
    for nama in kamus:
        dibaca = re.search(r"\b%s\s*\[" % re.escape(nama), pembaca) is not None
        if not dibaca:
            # Kamus yang tidak pernah dibaca untuk digambar bukan urusan
            # aturan ini — dan menghukumnya akan menyembunyikan sebab yang
            # benar (kawat mati) di balik pesan tentang pengisian.
            hasil.append((f"kamus '{nama}' dibaca untuk digambar", True,
                          "tidak dibaca di visualForDisplayedObject — "
                          "bukan urusan Aturan 102"))
            continue

        utuh = re.search(r"^[ \t]*%s\s*=(?!=)" % re.escape(nama),
                         pengisi, re.M) is not None
        hasil.append((
            f"kamus '{nama}' dibangun ulang utuh",
            utuh,
            "ada penugasan utuh di refreshSkyContext" if utuh else
            f"TIDAK ada `{nama} = …` di refreshSkyContext — entri yang tidak "
            f"terisi pada sampel berikutnya tidak pernah hilang, jadi arah "
            f"basi bertahan"))

        subskrip = re.search(
            r"^[ \t]*%s\s*\[[^\]]*\]\s*=(?!=)" % re.escape(nama),
            pengisi, re.M) is not None
        hasil.append((
            f"kamus '{nama}' tidak ditambahi per kunci",
            not subskrip,
            "tidak ada tulisan subskrip" if not subskrip else
            f"ADA `{nama}[ … ] = …` di refreshSkyContext — itu menambah, "
            f"bukan menggantikan, sehingga nilai dari sampel lama bertahan"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'ok  ' if lolos else 'FAIL'} {nama} — {detail}")

    if gagal:
        print()
        print(f"Aturan 102: {len(gagal)} dari {len(hasil)} pemeriksaan gagal.")
        print("Bangun kamusnya di variabel lokal lalu tugaskan utuh, sama")
        print("seperti dua kamus fase yang lain. Jangan mengosongkannya")
        print("secara manual di awal fungsi: penugasan utuh membuat kamus")
        print("kosong secara otomatis, sehingga tidak ada yang bisa lupa.")
        return 1

    print()
    print(f"Aturan 102: {len(hasil)} pemeriksaan lolos — setiap kamus fase "
          f"planet dibangun ulang, bukan ditambahi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
