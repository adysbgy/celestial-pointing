#!/usr/bin/env python3
"""Aturan 107: setiap teks yang dibaca pengguna di `Apps/` punya kunci katalog.

**Cacat yang ditutup, terukur di pohon ini.**

`Localizable.xcstrings` berisi 523 kunci, dan Aturan 91 memastikan setiap
`@main` memasang sumber terjemahan di `init()`. Yang tidak pernah diperiksa:
apakah teks yang **benar-benar ditulis di view** ada di katalog itu. Terukur
dengan menyapu literal argumen pertama `Label(`, `Button(`, `Text(`,
`Toggle(`, `Section(`, `navigationTitle(` di seluruh `Apps/` lalu
membandingkannya dengan kunci katalog — dua teks lolos tanpa kunci:

    Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift:72
        .tabItem { Label("Experiment 1", systemImage: "target") }

    Apps/PointAndKnowWatch/Complications/ComplicationWidget.swift:329
        AnyView(Label("Point & Know", systemImage: "scope"))

Keduanya adalah teks yang dibaca pengguna di layar utama: nama tab, dan teks
yang muncul di complication saat belum ada data — justru keadaan pertama yang
dilihat orang setelah memasang app. Keduanya juga tidak akan pernah
diterjemahkan: `SWIFT_EMIT_LOC_STRINGS` mengumpulkan literal ke katalog, tetapi
kunci yang tidak ada di katalog tidak punya nilai `en`, jadi pada perangkat
berbahasa Inggris teksnya tetap "Experiment 1" dan "Point & Know".

Ini kelas yang berbeda dari Aturan 91. Aturan 91 menjaga **pemasangan**
sumber terjemahan: kalau `init()` lupa memanggilnya, seluruh katalog mati dan
gejalanya seragam. Aturan ini menjaga **kelengkapan**: satu teks yang lupa
didaftarkan hanya kehilangan dirinya sendiri, jadi tidak ada gejala yang
mengarah ke sana. Compiler diam, 106 aturan lain hijau, dan yang terlihat
hanya satu label yang tidak ikut berganti bahasa.

**Kenapa bukan regex "ada literal di Label(".** Itu akan merah pada 200+
temuan yang sah: `Label(teksDinamis, ...)`, `Label(verbatim: ...)`,
`Label("\\(variabel)")` — semuanya memang bukan kunci katalog karena teksnya
baru diketahui saat berjalan. Yang diperiksa hanya literal **statis**: string
yang seluruhnya teks, tanpa interpolasi. Literal statis adalah satu-satunya
bentuk yang bisa dan harus punya kunci.

**Kenapa kunci boleh berupa teks Indonesia.** Katalog ini memakai teks
Indonesia sebagai kunci (`"Diagnostik"` → en `"Diagnostics"`), jadi yang
dituntut bukan "kunci harus bahasa Inggris", melainkan "teks yang tampil
harus ada di katalog". Memeriksa yang kedua berarti gerbang ini tidak
memaksa penamaan ulang 523 kunci yang sudah bekerja.

**Cacat yang ditemukan gerbangnya sendiri, dan ditutup.** Saat harness
mutasinya ditulis, keadaan "seluruh berkas Swift dikosongkan" menuntut MERAH
dan terukur **hijau**: gerbangnya melaporkan `29 berkas Swift, setiap teks
tampil punya kunci katalog` dan exit 0. Sebabnya `scanned` menghitung berkas
yang **dibuka**, bukan yang **berisi** — jadi hijau karena tidak ada satu pun
baris untuk diperiksa, bukan karena teksnya terdaftar. Itu persis kelas cacat
yang aturan ini ada untuk menutup, satu tingkat di atas dirinya sendiri.
Sekarang `berisi == 0` adalah kegagalan eksplisit.

**Yang TIDAK diklaim.** Gerbang ini tidak memeriksa apakah nilai `en` sudah
diisi, tidak memeriksa tata bahasa, dan tidak memeriksa teks yang datang dari
`PointingKit` lewat `TextLocalization` (itu urusan Aturan 91). Ia juga tidak
menangkap literal yang dirakit lebih dulu ke variabel lalu diteruskan ke
`Label(variabel)` — bentuk itu tidak bisa dibedakan dari teks dinamis tanpa
analisis aliran data, dan menebaknya akan menghasilkan merah palsu.
"""

from __future__ import annotations

import glob
import json
import os
import re
import sys

CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"

#: View API yang argumen pertamanya adalah teks yang dibaca pengguna.
#: `Label` ikut karena nama tab dan baris pengaturan memakainya.
TEXT_CALLS = ("Label", "Text", "Button", "Toggle", "Section", "navigationTitle")

_CALL = re.compile(
    r"\b(?:" + "|".join(TEXT_CALLS) + r")\s*\(\s*\"((?:[^\"\\\n]|\\.)*)\"")


def static_literal(raw: str):
    r"""Literal yang seluruhnya teks statis, atau `None` kalau ada interpolasi.

    `\(` di dalam literal adalah interpolasi Swift: teksnya baru diketahui
    saat berjalan, jadi ia tidak bisa punya kunci katalog dan tidak boleh
    dilaporkan.
    """
    if "\\(" in raw:
        return None
    # Escape lain (`\n`, `\"`) tetap teks statis; bandingkan bentuk aslinya.
    if not raw.strip():
        return None
    return raw


def unescape(raw: str) -> str:
    """Bentuk yang dicocokkan ke katalog: escape Swift yang umum dibuka."""
    return (raw.replace('\\"', '"')
               .replace("\\n", "\n")
               .replace("\\t", "\t"))


def main() -> int:
    if not os.path.exists(CATALOG):
        print(f"FAIL {CATALOG} tidak ada: Aturan 107 tidak mengukur apa pun")
        return 1
    with open(CATALOG, encoding="utf-8") as handle:
        catalog = json.load(handle)
    keys = set(catalog.get("strings", {}))

    findings = []
    scanned = 0
    #: Berkas yang **berisi** kode. `scanned` menghitung berkas yang dibuka;
    #: angka itu tidak cukup untuk membuktikan gerbang ini mengukur sesuatu.
    #: Terukur saat harness ditulis: seluruh 29 berkas Swift dikosongkan
    #: menghasilkan `29 berkas, setiap teks tampil punya kunci katalog` dan
    #: exit 0 — hijau karena tidak ada satu pun baris untuk diperiksa, bukan
    #: karena teksnya terdaftar. Itu bentuk paling sunyi dari gerbang yang
    #: berhenti mengukur, dan ia hanya tertangkap karena keadaan cakupan-nol
    #: di `Tools/bukti-mutasi-aturan107-teks-tampil.py` menuntutnya merah.
    berisi = 0
    for path in sorted(glob.glob("Apps/**/*.swift", recursive=True)):
        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
        scanned += 1
        if any(line.strip() for line in lines):
            berisi += 1
        for number, line in enumerate(lines, 1):
            stripped = line.lstrip()
            # Komentar tidak pernah sampai ke layar.
            if stripped.startswith("//") or stripped.startswith("///"):
                continue
            for match in _CALL.finditer(line):
                text = static_literal(match.group(1))
                if text is None:
                    continue
                text = unescape(text)
                if text in keys:
                    continue
                findings.append((path, number, text))

    if scanned == 0:
        print("FAIL tidak ada berkas Swift di Apps/: Aturan 107 buta")
        return 1

    if berisi == 0:
        print(f"FAIL {scanned} berkas Swift ada tetapi tidak satu pun berisi: "
              "Aturan 107 tidak memeriksa satu baris pun")
        return 1

    if findings:
        for path, number, text in findings:
            print(f"  FAIL {path}:{number}  {text!r} tidak ada di {CATALOG}")
        print(f"\n{len(findings)} teks tampil tanpa kunci katalog: "
              "teks itu tidak akan pernah diterjemahkan")
        return 1

    print(f"  OK   {berisi} berkas Swift berisi (dari {scanned} terbaca), "
          f"setiap teks tampil punya kunci katalog")
    return 0


if __name__ == "__main__":
    sys.exit(main())
