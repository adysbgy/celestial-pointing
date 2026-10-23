#!/usr/bin/env python3
"""Aturan 101: setiap ciri planet di model harus punya cabang gambar di view.

Kenapa aturan ini ada.

Siklus Venus menutup satu celah nyata: `haze.opacity(0.7)` bisa menjadi
`opacity(0.0)` tanpa satu pun gerbang berbunyi, karena seluruh pemeriksaan
menjaga **geometri** kabut dan tidak satu pun menyentuh **seberapa pekat**
ia. Perbaikannya menuntut setiap `static let *Opacity: Double` di model
benar-benar **dipakai** penggambarnya.

Itu menutup opasitas. Ia tidak menutup **pemanggilnya**.

Diukur, bukan disangka. `case .blueDisk: drawBlueDisk(…)` di
`drawPlanet` diganti `case .blueDisk: break` — bintik gelap Neptunus hilang
seluruhnya dari app, Neptunus kembali menjadi piringan biru polos:

    ./swift-ui-lint.sh                          exit 0, 99 aturan, nol merah
    check_port_matches_swift_constants          203 pemeriksaan, 0 gagal
    pemeriksaan "opasitas dipakai penggambarnya" hijau

Kenapa yang terakhir hijau: `neptuneSpotOpacity` masih disebut di dalam
`drawBlueDisk`, dan fungsinya masih ada di berkas. Gerbang itu bertanya
"apakah tokennya dipakai di suatu tempat", bukan "apakah fungsinya
**dipanggil**". Sebuah fungsi gambar yang tidak pernah dipanggil adalah token
yang dipakai oleh kode mati — dan kode mati menggambar nol piksel.

Bentuknya persis kelas yang sudah berulang di repo ini: **gerbang yang
mengukur keberadaan, bukan sambungan.** Aturan 100 menutup versi glif;
ini versi ciri planet, dan cakupannya lebih luas karena menyentuh tujuh
planet, bukan satu lencana.

Kenapa daftarnya **diturunkan**, bukan ditulis tangan.

Sumbernya `enum DistinguishingFeature` di model. Setiap `case` di sana
adalah ciri yang **bisa** dipilih `palette.feature` untuk sebuah planet.
Kalau satu `case` tidak punya cabang di `drawPlanet`, planet yang memakai
ciri itu kehilangan ciri pengenalnya di layar — dan tidak ada yang tahu.
Daftar tangan akan basi pada ciri berikutnya, dan justru ciri berikutnya
itu yang paling mungkin lupa dipasang; itu alasan yang sama dengan Aturan 98.

Yang diperiksa, dan kenapa berbentuk begitu.

1. `enum DistinguishingFeature` terbaca dari model, dan berisi ≥ 2 `case`.
   Nol temuan = GAGAL: kalau parser berhenti mengenali enum-nya, aturan ini
   akan melaporkan hijau tanpa mengukur apa pun.
2. Di dalam badan `drawPlanet`, setiap `case .X` dari enum itu punya cabang
   `case .X` yang **tidak** kosong: isinya harus memanggil sesuatu
   (`draw…(`), bukan `break`/`{}`. `case .blueDisk: break` adalah bentuk
   cacatnya, jadi ia harus merah.
3. `case .none` dikecualikan, dan itu bukan pelonggaran: `.none` berarti
   "planet ini tidak punya ciri", jadi `break` justru benar. Ia tetap
   dihitung di pemeriksaan 1 supaya enum-nya terbaca utuh.

Yang TIDAK diklaim. Ini sapuan **teks**, bukan render: ia tidak bisa
membuktikan bintik Neptunus terlihat benar di layar, dan tidak bisa
membuktikan `drawBlueDisk` menggambar sesuatu yang terlihat (itu milik
gerbang piksel port). Yang dijaga: **sambungan** dari `palette.feature` ke
penggambarnya tidak bisa diputus tanpa gerbang merah. Ia juga tidak membaca
`Packages/PointingKit` sebagai pohon Swift yang dikompilasi — hanya sebagai
teks.
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


def badan(source: str, jangkar: str) -> str:
    """Isi fungsi mulai dari `jangkar`, dibatasi penutup kurawalnya sendiri.

    Menyalin pendekatan `_function_body` di `check-visuals.py`: kurung buka
    pertama sesudah jangkar adalah pembuka badannya, dan depth dihitung dari
    situ. Regex malas akan berhenti di `{}` pertama milik `Path`/`CGRect` dan
    aturan ini akan mengukur potongan yang salah.
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
        view = open(os.path.join(ROOT, VIEW), encoding="utf-8").read()
        model = open(os.path.join(ROOT, MODEL), encoding="utf-8").read()
    except OSError as exc:
        print(f"FAIL berkas tidak terbaca: {exc}")
        return 1

    hasil: list[tuple[str, bool, str]] = []

    # (1) Enum cirinya terbaca utuh dari model.
    # Jangkar **berakhir titik dua**, bukan nama saja. Diukur: dengan jangkar
    # `"enum DistinguishingFeature"`, mengganti nama enum menjadi
    # `DistinguishingFeature2` tetap cocok sebagai awalan, dan aturan tetap
    # hijau sambil mengukur enum yang sudah tidak ada. Titik dua membuat
    # jangkarnya berhenti tepat di deklarasi yang dimaksud.
    enum_badan = badan(tanpa_komentar(model), "enum DistinguishingFeature:")
    kasus = re.findall(r"^\s*case\s+(\w+)\s*$", enum_badan, re.M)
    hasil.append((
        "enum ciri planet terbaca dari model",
        len(kasus) >= 2,
        f"case: {kasus}" if kasus else
        "`enum DistinguishingFeature` tidak terbaca (atau < 2 case) — Aturan "
        "101 berhenti mengukur, jadi ini GAGAL, bukan lolos"))

    if len(kasus) < 2:
        for nama, lolos, detail in hasil:
            print(f"{'ok  ' if lolos else 'FAIL'} {nama} — {detail}")
        print()
        print("Aturan 101: daftar cirinya tidak terbaca, aturan ini tidak "
              "bisa mengukur lebih jauh.")
        return 1

    # (2) Setiap ciri punya cabang yang benar-benar menggambar.
    planet = badan(tanpa_komentar(view), "private func drawPlanet(")
    if not planet:
        hasil.append((
            "badan drawPlanet terbaca",
            False,
            "`private func drawPlanet(` tidak ditemukan di view — aturan "
            "tidak mengukur apa pun, jadi ini GAGAL"))
    else:
        # Cabang yang dibaca hanya milik switch **terluar** di `drawPlanet`.
        #
        # Ini bukan kerapian, ini cacat yang tertangkap saat aturan ini
        # ditulis. Versi pertamanya mencari `case .ciri:` dengan regex malas
        # di seluruh badan `drawPlanet`, dan `drawPlanet` punya switch
        # **kedua** di dalam jalur sabit (`switch palette.feature` untuk
        # memotong ciri ke bagian yang menyala) yang menyebut `.craters` dan
        # `.haze` lagi. Mengosongkan cabang terluar `.craters` lalu tetap
        # hijau, karena regex-nya berhenti di salinan yang dalam:
        #
        #     case .craters: {}        -> "ok, cabang memanggil penggambar"
        #
        # Aturan yang tidak bisa membedakan dua switch di satu fungsi akan
        # meloloskan cacat yang justru jadi alasan ia ditulis. Karena itu
        # switch terluar dikenali dari **indentasi terkecil** di antara semua
        # `case .` di badan ini — bentuk yang bisa diputuskan dari teks, bukan
        # ditebak.
        baris = [
            (len(m.group(1)), m.start(), m.group(2))
            for m in re.finditer(r"^([ \t]*)case\s+\.(\w+)\s*:", planet, re.M)
        ]
        indentasi = min((b[0] for b in baris), default=-1)
        terluar = [b for b in baris if b[0] == indentasi]

        if not terluar:
            hasil.append((
                "switch terluar drawPlanet terbaca",
                False,
                "tidak ada `case .…:` di badan drawPlanet — aturan tidak "
                "mengukur apa pun, jadi ini GAGAL"))

        for ciri in kasus:
            if ciri == "none":
                continue  # `.none` = tidak punya ciri; `break` justru benar.
            # Badan cabang: dari sesudah `case .ciri:` sampai `case` terluar
            # berikutnya, atau sampai ujung switch.
            awal = next((b[1] for b in terluar if b[2] == ciri), None)
            if awal is None:
                hasil.append((
                    f"ciri '{ciri}' punya cabang menggambar",
                    False,
                    f"TIDAK ada `case .{ciri}:` di switch terluar drawPlanet — "
                    f"planet dengan ciri ini kehilangan ciri pengenalnya di "
                    f"layar"))
                continue
            sesudah = [b[1] for b in terluar if b[1] > awal]
            akhir = min(sesudah) if sesudah else len(planet)
            isi = planet[awal:akhir]
            isi = isi.split(":", 1)[1] if ":" in isi else ""
            isi = isi.strip()
            menggambar = re.search(r"\bdraw\w+\s*\(", isi) is not None
            hasil.append((
                f"ciri '{ciri}' punya cabang menggambar",
                menggambar,
                "cabang memanggil penggambar" if menggambar else
                f"cabang ada tetapi tidak memanggil penggambar: {isi[:40]!r}"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'ok  ' if lolos else 'FAIL'} {nama} — {detail}")

    if gagal:
        print()
        print(f"Aturan 101: {len(gagal)} dari {len(hasil)} pemeriksaan gagal.")
        print("Setiap ciri di `DistinguishingFeature` harus punya cabang yang")
        print("memanggil penggambarnya di `drawPlanet`. Sambungkan cabangnya;")
        print("jangan menghapus cirinya dari model.")
        return 1

    print()
    print(f"Aturan 101: {len(hasil)} pemeriksaan lolos — {len(kasus) - 1} ciri "
          f"planet tersambung ke penggambarnya.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
