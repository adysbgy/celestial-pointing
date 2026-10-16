#!/usr/bin/env python3
"""Ukur: apakah uji yang **dikutip** sumber produksi benar-benar ada?

**Pertanyaan yang belum pernah diajukan repo ini.** Repo ini punya gerbang
untuk nama **gerbang** yang menggantung (`check_gate_names_mentioned_in_code_exist`:
referensi `check_*` yang tidak terdefinisi) dan gerbang untuk **jangkar
harness** yang menggantung (`check-jangkar-harness.py`). Yang belum diperiksa
siapa pun adalah bentuk ketiga, dan ia jenis yang sama: nama **uji** yang
dikutip sebagai penjaga, padahal tidak ada ujinya.

Kenapa ini lebih buruk daripada dua yang lain. Nama gerbang yang menggantung
disebut di komentar; nama uji yang menggantung disebut sebagai **alasan sebuah
nilai boleh dibiarkan apa adanya** — "nilainya dijaga `testX`". Pembaca yang
menemukan angka mencurigakan akan mencari `testX`, tidak menemukannya, dan
tidak punya cara membedakan "ujinya bernama lain" dari "ujinya tidak ada".
Gerbang yang disebut tapi tidak ada adalah janji; uji yang disebut tapi tidak
ada adalah **izin**.

Alat ini mengukur cakupannya: berapa nama uji yang dikutip, berapa yang tidak
punya definisi, dan di berkas mana.

Pakai:
    python3 Tools/ukur-uji-menggantung.py
"""

from __future__ import annotations

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: Berkas yang **menjalankan** atau **dijalankan** uji, sama seperti batas
#: `check_gate_names_mentioned_in_code_exist`: sumber produksi dan app. Prosa
#: di `Tools/*.py` (docstring harness, komentar gerbang) sengaja tidak
#: dihitung — lihat catatan "DUA JENIS" di bawah.
TARGET_GLOBS = [
    "Packages/PointingKit/Sources/**/*.swift",
    "Packages/CelestialEngine/Sources/**/*.swift",
    "Apps/**/*.swift",
]

#: Direktori uji — sumber definisi.
TEST_GLOBS = [
    "Packages/*/Tests/**/*.swift",
]


def _files(patterns):
    out = []
    for pattern in patterns:
        out += glob.glob(os.path.join(ROOT, pattern), recursive=True)
    return sorted(set(p for p in out if "/.build/" not in p))


def defined_test_names():
    names = set()
    for path in _files(TEST_GLOBS):
        source = open(path, encoding="utf-8", errors="replace").read()
        names |= set(re.findall(r"\bfunc\s+(test\w+)", source))
    return names


def cited_test_names():
    """Nama uji yang disebut sumber produksi, dengan lokasinya."""
    out = {}
    for path in _files(TARGET_GLOBS):
        source = open(path, encoding="utf-8", errors="replace").read()
        for match in re.finditer(r"\btest[A-Z][A-Za-z0-9_]+", source):
            name = match.group(0)
            line = source[: match.start()].count("\n") + 1
            out.setdefault(name, []).append(
                (os.path.relpath(path, ROOT), line))
    return out


def main():
    defined = defined_test_names()
    cited = cited_test_names()

    print(f"uji terdefinisi            : {len(defined)}")
    print(f"nama uji dikutip produksi  : {len(cited)}")

    dangling = {n: locs for n, locs in cited.items() if n not in defined}
    print(f"nama uji TANPA definisi    : {len(dangling)}")
    for name in sorted(dangling):
        for path, line in dangling[name]:
            print(f"    {name}  -> {path}:{line}")
    if not dangling:
        print("    (tidak ada)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
