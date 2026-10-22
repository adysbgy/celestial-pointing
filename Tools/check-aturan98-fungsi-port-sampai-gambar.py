#!/usr/bin/env python3
"""Aturan 98: fungsi model yang punya kembaran port wajib **sampai ke gambar**.

Kenapa aturan ini ada.

`Tools/render-visuals.py` adalah port Python dari `CelestialVisual.swift`, dan
setiap gerbang gambar di repo ini mengukur **port**-nya, bukan view SwiftUI —
karena `Apps/` tidak dibangun di Linux. Akibatnya setiap fungsi model yang
punya kembaran port bisa **hilang dari app** tanpa satu pun gerbang berbunyi:
port tetap benar, gerbang piksel tetap hijau, teks di layar tidak berubah.

**Diukur, bukan disangka.** Badan `starCoreColor` di
`Apps/Shared/CelestialVisualView.swift` — seluruh pemanggilan
`CelestialVisual.starCoreRGB(forColorIndex:relativeSize:)` beserta dua
`drawable*` di atasnya — diganti satu baris `return starColor`. Artinya
**seluruh** pemutihan inti bintang di app dimatikan; yang tersisa hanya tint
spektral, jadi Sirius dan bintang magnitudo +3,5 kembali berpuncak sama
terangnya — persis cacat yang fungsi itu ada untuk menutupnya. Hasil
pengukuran:

    ./swift-ui-lint.sh                  exit 0, 96 aturan, nol merah
    grep starCoreRGB /tmp/lint.log      0 baris
    check_star_spike_halving…           HIJAU (membaca view, tapi bukan ini)

Nol. Seluruh suite gerbang gambar, seluruh 96 aturan UI, dan gerbang yang
secara eksplisit membaca berkas itu semuanya diam.

**Kenapa bukan memperluas Aturan 96.** Aturan 96 memeriksa
`let NAMA = CelestialVisual.…(`, yaitu **variabel lokal**. `starCoreColor`
adalah **computed property**, jadi ia tidak pernah masuk jangkauan Aturan 96 —
dan memperluasnya ke `var` akan tetap tidak menangkap kasus yang paling
mungkin terjadi (badan fungsi diganti), karena penggantian badan tidak
meninggalkan `let` apa pun untuk diperiksa.

**Kenapa daftarnya diturunkan, bukan ditulis tangan.** Yang diperiksa adalah
**irisan** dua pengakuan yang sudah ada di repo:

  * model mengaku `public static func NAMA` — jangkauan yang boleh dipanggil
    `Apps/`;
  * port mengaku `CelestialVisual.NAMA(` di docstring-nya — jangkauan yang
    diukur gerbang piksel.

Irisannya (5 hari ini: `drawsMoonSurfaceShading`, `earthshineStrength`,
`phaseGeometry`, `starCoreRGB`, `starRGB`) adalah tepat himpunan fungsi yang
"diuji di Linux" **dan** "tampil di layar". Fungsi model yang baru ditambahkan
ikut terjaga dengan sendirinya begitu port memportnya; fungsi yang tidak
pernah diport tidak diklaim. Daftar tangan akan basi pada fungsi berikutnya —
dan justru fungsi berikutnya itu yang paling mungkin lupa dipasang di view.

**Yang diperiksa, dan kenapa dua bentuk.** Untuk setiap fungsi di irisan:

  1. nama itu muncul di `Apps/` — kalau tidak, fungsinya tidak pernah dipanggil
     app sama sekali;
  2. nama itu muncul sebagai **nilai**, bukan hanya di dalam komentar. Ini
     menutup bentuk yang paling sunyi: memanggilnya lalu membuang hasilnya
     (`_ = CelestialVisual.starCoreRGB(…)`), atau menyebutnya di prosa
     sementara gambar memakai angka lain.

**Kenapa nol temuan = GAGAL.** Kalau irisan itu kosong — mis. port berhenti
menyebut nama Swift, atau semua fungsi berhenti `public` — aturan ini berhenti
mengukur tanpa berbunyi. Aturan yang diam karena tidak menemukan apa-apa lebih
berbahaya daripada tidak ada aturan.

**Yang TIDAK diklaim.** Ini sapuan **teks**, bukan render: ia tidak bisa
membuktikan hasilnya terlihat benar di layar, dan tidak bisa membuktikan
`Self.color(...)` memetakan kanal merah dengan tepat. Ia juga tidak membaca
`Packages/PointingKit` sebagai pohon Swift yang dikompilasi — hanya sebagai
teks. Kebenaran rumusnya tetap milik uji Swift di Linux dan gerbang piksel
port; yang dijaga di sini hanya bahwa rumus itu **sampai** ke app.
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift"
PORT = "Tools/render-visuals.py"
APPS = "Apps"


def strip_komentar(source: str) -> str:
    """Buang komentar `//` supaya nama di prosa tidak dihitung sebagai kode."""
    return re.sub(r"//[^\n]*", "", source)


def baca_apps() -> dict[str, str]:
    """Seluruh berkas `.swift` di `Apps/`, dinormalisasi komentarnya."""
    hasil: dict[str, str] = {}
    for akar, _, berkas in os.walk(os.path.join(ROOT, APPS)):
        if ".build" in akar:
            continue
        for nama in berkas:
            if not nama.endswith(".swift"):
                continue
            jalur = os.path.join(akar, nama)
            try:
                hasil[os.path.relpath(jalur, ROOT)] = strip_komentar(
                    open(jalur, encoding="utf-8").read())
            except OSError:
                continue
    return hasil


def main() -> int:
    try:
        model = open(os.path.join(ROOT, MODEL), encoding="utf-8").read()
        port = open(os.path.join(ROOT, PORT), encoding="utf-8").read()
    except OSError as exc:
        print(f"FAIL berkas tidak terbaca: {exc}")
        return 1

    apps = baca_apps()
    if not apps:
        print(f"FAIL tidak ada berkas .swift di {APPS}/ — Aturan 98 berhenti "
              f"mengukur.")
        return 1

    # Pengakuan model: fungsi yang boleh dipanggil `Apps/`.
    publik = set(re.findall(r"public static func (\w+)", model))
    # Pengakuan port: fungsi yang diukur gerbang piksel.
    diport = set(re.findall(r"CelestialVisual\.(\w+)\s*\(", port))
    irisan = sorted(publik & diport)

    if not irisan:
        print("FAIL irisan model∩port kosong — tidak ada satu pun fungsi yang "
              "diuji di Linux")
        print("     sekaligus tampil di layar. Aturan 98 berhenti mengukur; "
              "periksa apakah")
        print("     docstring port masih menyebut nama Swift, atau apakah "
              "fungsinya masih `public`.")
        return 1

    gagal: list[str] = []
    for fungsi in irisan:
        pola = re.compile(r"\b" + re.escape(fungsi) + r"\s*\(")
        pemakai = [jalur for jalur, isi in apps.items() if pola.search(isi)]
        if not pemakai:
            gagal.append(
                f"{fungsi}() diport dan diukur gerbang piksel, tetapi tidak "
                f"dipanggil satu berkas pun di {APPS}/ — fungsi yang diuji di "
                f"Linux tidak sampai ke app")
            continue

        # Bentuk kedua: dipakai sebagai **nilai**, bukan dibuang. `_ = f(…)`
        # dan `if f(…)` sama-sama "memakai", tetapi `_ =` membuang hasilnya
        # tanpa jejak di layar — itu yang dilarang.
        dibuang = []
        for jalur in pemakai:
            isi = apps[jalur]
            for m in pola.finditer(isi):
                sebelum = isi[max(0, m.start() - 12):m.start()]
                if re.search(r"_\s*=\s*$", sebelum):
                    dibuang.append(jalur)
                    break
        if dibuang:
            gagal.append(
                f"{fungsi}() hasilnya dibuang (`_ = …`) di "
                f"{', '.join(sorted(set(dibuang)))} — dipanggil supaya gerbang "
                f"teks puas, tetapi tidak pernah sampai ke gambar")

    if gagal:
        for baris in gagal:
            print(f"FAIL {baris}")
        print("-> Setiap fungsi model yang punya kembaran port wajib benar-benar "
              "dipakai")
        print("   view-nya sebagai nilai. Perbaiki view-nya, jangan longgarkan "
              "aturannya.")
        return 1

    print(f"OK {len(irisan)} fungsi model∩port dipakai sebagai nilai di "
          f"{APPS}/: {', '.join(irisan)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
