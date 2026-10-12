#!/usr/bin/env python3
"""Buktikan gerbang "setiap harness memanggil gerbang yang ADA" bisa merah.

Kenapa harness ini ada.

`check-harness-terdaftar.py` menutup celah **daftar**: berkas harness yang
ada di `Tools/` wajib dirujuk alur kerja. Itu perlu, tetapi tidak cukup —
terbukti dari kejadian nyata pada 12 Okt 2026.

Pada commit `fbb67f7`, `main` **merah** di `Engine Tests (Linux)` selama 37
menit. Bukan karena kodenya salah, melainkan karena:

  - `Tools/bukti-mutasi-setengah-spike.py` **dikomit** (dan dirujuk CI), dan
    ia memanggil `C.check_star_spike_halving_reaches_both_languages(results)`.
  - Fungsi gerbang yang dipanggilnya hidup di `Tools/check-visuals.py` —
    yang saat itu **belum dikomit** (84 baris WIP agen paralel, untracked).

Terukur pada checkout bersih commit itu:

    $ git archive fbb67f7 | tar -x -C /tmp/x && grep -c \\
          check_star_spike_halving_reaches_both_languages /tmp/x/Tools/check-visuals.py
    0

dan di CI:

    [baseline]            PROBE GAGAL JALAN: AttributeError: module 'cv_probe'
                          has no attribute 'check_star_spike_halving_...'
    ... 6 keadaan tidak sesuai harapan

`check-harness-terdaftar.py` **tetap hijau** sepanjang kejadian itu: kedua
arah yang diauditnya (berkas ada di disk, berkas dirujuk alur kerja) sama-sama
terpenuhi. Yang tidak ada justru **isi** berkas yang menjadi sandaran
harness-nya. Daftar lengkap, eksekusi gagal.

Ini occurrence ketiga dari pola yang sama (13/12, 17/16, sekarang 12/10) —
dan ketiganya berbeda dari yang diaudit gerbang meta: bukan berkas yang hilang,
melainkan **fungsi yang dirujuk hilang dari berkas yang ada**.

Yang diaudit gerbang baru (`audit_called_gates`):

  Untuk setiap `Tools/bukti-mutasi-*.py`, kumpulkan nama
  `check_*` yang dipanggilnya (dari tubuh PROBE maupun dari kode langsung),
  lalu pastikan **setiap** nama itu benar-benar didefinisikan di
  `Tools/check-visuals.py` sebagai `def <nama>(`.

Kenapa cukup membaca definisi, bukan menjalankan: harness yang dijalankan
memakan 12 menit dan sebagian memerlukan `git`. Yang diaudit di sini adalah
kegagalan yang **paling murah dan paling sering**: atribut yang tidak ada,
yang membuat seluruh enam keadaan harness gagal jalan sekaligus dengan
`AttributeError` — persis yang terjadi di CI.

Bukti-diri di bawah menjalankan `audit_called_gates` atas daftar rekaan,
supaya gerbang yang salah diekspresikan tidak bisa lolos dengan mengembalikan
nol masalah.
"""

from __future__ import annotations

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "Tools")
CHECK_VISUALS = os.path.join(TOOLS, "check-visuals.py")

#: Pola nama harness: sama dengan `check-harness-terdaftar.py`, sengaja.
PATTERN = "bukti-mutasi-*.py"

#: Hanya harness yang **benar-benar memuat** `check-visuals.py` yang diaudit.
#: Tanpa ini, pola pemanggilan ikut menangkap gerbang harness lain
#: (`bukti-mutasi-aturan18-redlint.py` mendefinisikan `check_rule_18` dan
#: `check_red_lint` sebagai funesinya sendiri, dan keduanya tidak ada hubungannya
#: dengan `check-visuals.py`) serta prosa di docstring. Batasnya dinyatakan di
#: sini, bukan disembunyikan: harness yang memanggil gerbang dari modul lain
#: **tidak** diaudit oleh gerbang ini.
LOADS_CHECK_VISUALS = "check-visuals.py"

#: Pemanggilan gerbang: `C.check_sesuatu(...)`, `CV.check_sesuatu(...)`, atau
#: `getattr(C, "check_sesuatu")`. Ketiganya adalah nama yang harus terikat
#: ke modul `check-visuals`.
CALL = re.compile(
    r"\b(?:C|CV)\.(check_[A-Za-z0-9_]+)\s*\("
    r"|getattr\(\s*(?:C|CV)\s*,\s*[\"'](check_[A-Za-z0-9_]+)[\"']"
    r"|[\"'](check_[A-Za-z0-9_]+)[\"']\s*\]\s*,?\s*results"
)

#: Definisi gerbang di berkas yang disandari seluruh harness.
DEF = re.compile(r"^def\s+(check_[A-Za-z0-9_]+)\s*\(", re.MULTILINE)

#: Definisi lokal di dalam harness sendiri — bukan rujukan ke `check-visuals`.
LOCAL_DEF = re.compile(r"^def\s+(check_[A-Za-z0-9_]+)\s*\(", re.MULTILINE)

#: Harness ini sendiri tidak diaudit: nama gerbang yang ia sebutkan ada di
#: docstring dan bukti-dirinya sebagai **teks**, bukan sebagai pemanggilan.
SELF = "bukti-mutasi-gerbang-dijalankan.py"

#: Nama gerbang yang memang **tidak** hidup di `check-visuals.py`. Daftar
#: ini sengaja kosong dan sengaja eksplisit: kalau suatu hari sebuah harness
#: memanggil gerbang dari modul lain, keputusannya harus ditulis di sini
#: beserta alasannya — bukan dengan melonggarkan pola `CALL`.
DEFINED_ELSEWHERE: set[str] = set()


def gates_defined(source: str) -> set[str]:
    """Nama gerbang yang didefinisikan di sumber `check-visuals.py`."""
    return set(DEF.findall(source))


def gates_called(source: str) -> set[str]:
    """Nama gerbang yang **dipanggil** sebuah harness terhadap `check-visuals`.

    Nama yang didefinisikan di dalam harness itu sendiri dikurangi: fungsi
    miliknya sendiri bukan rujukan lintas modul (lihat `LOCAL_DEF`).
    """
    called = set()
    for match in CALL.finditer(source):
        called.update(group for group in match.groups() if group)
    return called - set(LOCAL_DEF.findall(source))


def audit_called_gates(called_by_file: dict[str, set[str]],
                       defined: set[str]) -> list[str]:
    """Kembalikan daftar masalah; kosong berarti setiap panggilan punya gerbang."""
    problems = []
    for name in sorted(called_by_file):
        missing = sorted(called_by_file[name] - defined - DEFINED_ELSEWHERE)
        for gate in missing:
            problems.append(
                f"{name}: memanggil {gate}() yang tidak didefinisikan di "
                "Tools/check-visuals.py — harness-nya gagal jalan dengan "
                "AttributeError di CI, dan seluruh keadaannya gagal bersama")
    return problems


def _mutate(called_by_file: dict[str, set[str]], defined: set[str]) -> list[str]:
    """Dipakai bukti-diri: jalankan `audit_called_gates` atas daftar rekaan."""
    return audit_called_gates(called_by_file, defined)


def prove_itself() -> list[str]:
    """Buktikan auditnya bisa merah pada **tiga** arah, bukan cuma hijau.

    Tanpa ini, `audit_called_gates` yang selalu mengembalikan daftar kosong
    (mis. karena pola `CALL` tidak pernah cocok) akan terlihat sama persis
    dengan audit yang benar: nol masalah, exit 0 — persis cacat yang
    ditutupnya, menimpa dirinya sendiri.
    """
    cases = [
        ("gerbang yang dipanggil tidak ada",
         {"bukti-mutasi-a.py": {"check_ada", "check_hilang"}},
         {"check_ada"}, 1),
        ("semua panggilan punya gerbang",
         {"bukti-mutasi-a.py": {"check_ada"}},
         {"check_ada"}, 0),
        ("pola CALL tidak cocok apa pun (kontrol negatif)",
         {"bukti-mutasi-a.py": set()},
         {"check_ada"}, 0),
    ]
    failures = []
    for label, called, defined, want in cases:
        got = len(_mutate(called, defined))
        mark = "OK  " if got == want else "SALAH"
        if got != want:
            failures.append(f"{label}: {got} masalah, seharusnya {want}")
        print(f"{mark} bukti-diri: {label:52s} {got} masalah (harap {want})")

    # Kontrol yang paling penting: audit harus **menggigit** pada keadaan
    # yang persis terjadi di CI pada 12 Okt — nama gerbang setengah-lebar
    # spike dipanggil harness-nya, tetapi tidak ada di berkas yang disandari.
    real = {"bukti-mutasi-setengah-spike.py":
            {"check_star_spike_halving_reaches_both_languages"}}
    got = len(_mutate(real, set()))
    mark = "OK  " if got == 1 else "SALAH"
    if got != 1:
        failures.append(
            f"reproduksi CI 12 Okt: {got} masalah, seharusnya 1 — gerbang ini "
            "tidak akan menangkap kejadian yang menurunkannya")
    print(f"{mark} bukti-diri: reproduksi CI 12 Okt (gerbang hilang)          "
          f"{got} masalah (harap 1)")
    return failures


def main() -> int:
    with open(CHECK_VISUALS, encoding="utf-8") as handle:
        defined = gates_defined(handle.read())

    called_by_file: dict[str, set[str]] = {}
    for path in sorted(glob.glob(os.path.join(TOOLS, PATTERN))):
        name = os.path.basename(path)
        if name == SELF:
            continue
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        # Hanya harness yang benar-benar memuat `check-visuals.py`: pemanggilan
        # `check_*` di harness lain menunjuk modul lain (lihat `LOADS_CHECK_VISUALS`).
        if LOADS_CHECK_VISUALS not in text:
            continue
        called_by_file[name] = gates_called(text)

    problems = audit_called_gates(called_by_file, defined)

    total_calls = sum(len(v) for v in called_by_file.values())
    print(f"harness dipindai        : {len(called_by_file)}")
    print(f"panggilan gerbang       : {total_calls}")
    print(f"gerbang di check-visuals: {len(defined)}")

    print()
    failures = prove_itself()

    print()
    if problems:
        print(f"{len(problems)} masalah:")
        for item in problems:
            print(f"  - {item}")
    for item in failures:
        print(f"  - {item}")
    if problems or failures:
        return 1
    print("0 masalah: setiap harness memanggil gerbang yang benar-benar ada.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
