#!/usr/bin/env python3
"""Buktikan Aturan 33 (bobot putusan GoTo) **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis -- itu bukan bukti apa pun.
Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada keadaan
yang memang salah, dengan pesan yang menunjuk ke klaim yang dilanggar.

Kelas cacat yang ditutupnya.

`Apps/Shared/SlewVerdictBanner.swift` punya dua baris yang menentukan apakah
dua kelas bahaya **terlihat berbeda**:

    `let tone = decision.verdictTone`               warna
    `Image(systemName: decision.verdictSymbolName)` ikon

Terukur sebelum Aturan 33 ada: keduanya dikembalikan ke bentuk lamanya (ikon
tetap `exclamationmark.triangle.fill`, nada tetap `PointingTone.warning`),
lalu dijalankan -- seluruh aturan UI saat itu lulus, `./swift-typecheck.sh`
lulus (exit 0), dan `./swift-test.sh` melaporkan **755 uji, 0 gagal**. Jadi
memundurkan pemisahan bobot itu ke bentuk yang `SlewVerdict.verdictTone`
sebut sebagai cacatnya tidak menghasilkan satu pun kegagalan.

`SlewVerdictTests` menguji **nilai** `verdictTone`/`verdictSymbolName`
(`testDangerAndWarningUseDifferentSymbols` memang menuntut keduanya berbeda),
tetapi tidak ada uji yang menuntut **view membacanya**. Rumus yang benar dan
tidak pernah dipakai tetap hijau selamanya -- kelas yang sama dengan
setengah-lebar spike yang hilang hanya di sisi view.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                     gerbang hijau (kalau tidak, harness salah)

  1. ikon kembali ke literal     Cacat aslinya. Ikon tetap membuat kelas
                                 keselamatan dan kelas mutu tergambar sama;
                                 di Mode Malam ikon satu-satunya pembeda yang
                                 tersisa, karena seluruh palet nada menyempit
                                 jadi satu merah.

  2. nada kembali ke literal     Arah sebaliknya. Warna peringatan tetap
                                 menyamakan "terlalu dekat Matahari" dengan
                                 "terlalu redup" -- dan tanpa keadaan ini,
                                 cacat 1 bisa "diselesaikan" dengan hanya
                                 memperbaiki ikonnya.

  3. nada dihitung lalu dibuang  Arah ketiga, dan yang paling halus:
                                 `decision.verdictTone` tetap dihitung, tetapi
                                 `foregroundStyle` memakai warna tetap. Nilai
                                 ada, layar tidak berubah -- gerbang yang
                                 hanya mencari nama `verdictTone` akan hijau.

  4. baris `Image` diganti nama  Kontrol negatif. Gerbang yang kehilangan
                                 subjeknya harus **merah**, bukan hijau tanpa
                                 mengukur apa pun.

**Keadaan 1-3 tidak bisa saling menggantikan.** 1 menguji ikon, 2 menguji
warna, 3 menguji bahwa warna itu benar-benar **sampai** ke gambar. Kalau
salah satunya dilewat, gerbang bisa dibalik tanpa berbunyi di sisi itu.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang akan tetap
hijau walau aturan aslinya dilonggarkan. Yang diukur harus aturan yang CI
jalankan.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
VIEW = os.path.join(ROOT, "Apps", "Shared", "SlewVerdictBanner.swift")

#: Tanda yang dicetak Aturan 33. Dibaca dari keluaran lint, bukan ditulis
#: ulang, supaya perubahan pesannya tidak membuat harness ini berbohong.
RULE_HEADER = "== Aturan 33:"
CLEAN_MARK = "Bersih: bobot putusan GoTo datang dari putusannya."

#: Jangkar di view. Baris **utuh** supaya mutasinya tidak bergantung pada
#: spasi; kemunculannya diperiksa eksplisit karena jangkar yang muncul dua
#: kali mengubah lebih banyak daripada yang dilaporkan.
ICON_LINE = "                Image(systemName: decision.verdictSymbolName)"
TONE_LINE = "            let tone = decision.verdictTone"
PAINT_LINE = "            .foregroundStyle(tone.color)"

STATES = [
    ("[baseline]", None, False),
    ("1. ikon kembali ke literal tetap",
     [(VIEW, ICON_LINE,
       '                Image(systemName: "exclamationmark.triangle.fill")')],
     True),
    ("2. nada kembali ke literal tetap",
     [(VIEW, TONE_LINE, "            let tone = PointingTone.warning")],
     True),
    ("3. nada dihitung lalu dibuang dari warna",
     [(VIEW, PAINT_LINE, "            .foregroundStyle(PointingTone.warning.color)")],
     True),
    ("4. baris `Image` diganti nama (kontrol negatif)",
     [(VIEW, ICON_LINE, "                Icon(systemName: decision.verdictSymbolName)")],
     True),
]

_originals = {}
_sources = (VIEW,)


def restore(*_):
    """Pulihkan sumber produksi -- juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(path, "w")`: belasan harness di
    `Tools/` memutasi berkas produksi, jadi penulisan biasa membuat pembaca
    bisa melihat berkas setengah jadi. Pemulihannya **diverifikasi** --
    kegagalan pemulihan bersifat diam dan lalu menyalahkan kode yang benar.
    """
    for path, content in _originals.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)


def extract_rule33():
    """Ambil program Aturan 33 dari `swift-ui-lint.sh`.

    Kenapa diekstrak, bukan disalin: harness yang menyalin aturannya akan
    tetap hijau walau aturan aslinya dilonggarkan -- persis kelas cacat yang
    ditutup `check-harness-terdaftar.py` (gerbang yang tidak pernah
    dieksekusi selalu hijau).
    """
    text = open(LINT, encoding="utf-8").read()
    return mutasi_sumber.batas_aturan(text, 33)


def probe(program):
    """Jalankan Aturan 33 sendiri -> (merah?, detail)."""
    proc = subprocess.run(["bash", "-c", program], cwd=ROOT,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    clean = CLEAN_MARK in out
    return (not clean), out.strip()


def main():
    mutasi_sumber.require_clean_sources(list(_sources))

    program = extract_rule33()
    if program is None:
        print("GERBANG: program Aturan 33 tidak ditemukan di "
              "swift-ui-lint.sh -- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)
    if RULE_HEADER not in program:
        print("GERBANG: Aturan 33 tidak mencetak judulnya sendiri; harness "
              "tidak bisa membedakan aturan ini dari yang lain.",
              file=sys.stderr)
        sys.exit(2)

    for path in _sources:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()
    for path, anchor, label in (
            (VIEW, ICON_LINE, "baris ikon"),
            (VIEW, TONE_LINE, "baris nada"),
            (VIEW, PAINT_LINE, "baris foregroundStyle")):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x "
                  "-- harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutations, must_fire in STATES:
            for path in _sources:
                mutasi_sumber.write_source(path, _originals[path])
            if mutations is not None:
                pending = {path: _originals[path] for path in _sources}
                anchor_missing = False
                for path, old, new in mutations:
                    content = pending[path].replace(old, new, 1)
                    if content == pending[path]:
                        print(f"{label:52s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                        anchor_missing = True
                        continue
                    pending[path] = content
                if anchor_missing:
                    unexpected += 1
                    continue
                for path, content in pending.items():
                    if content != _originals[path]:
                        mutasi_sumber.write_source(path, content)

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:52s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            # Yang dituntut bukan «merah» melainkan **merah karena alasan
            # yang benar**: aturan ini harus menyebut klaim yang dilanggar.
            # Pesan yang kosong berarti ia berbunyi tanpa mengukur.
            ok = (fired == must_fire)
            if fired and not detail.strip():
                ok = False
            if not ok:
                unexpected += 1
            state = "MERAH" if fired else "hijau"
            print(f"{'OK  ' if ok else 'SALAH'} {label:52s} {state}")
            if fired:
                for line in detail.splitlines():
                    if line.strip() and not line.startswith(
                            RULE_HEADER.split("==")[1].strip()):
                        print(f"       {line.strip()[:150]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
