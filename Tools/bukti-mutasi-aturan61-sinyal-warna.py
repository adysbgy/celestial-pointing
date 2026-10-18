#!/usr/bin/env python3
"""Buktikan Aturan 61 (sinyal yang hanya dibedakan warna) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
karena bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya.

WCAG 1.4.1 (Use of Color). Sapuan `foregroundStyle(<kondisi> ? … : …)` atas
seluruh `Apps/` menemukan lima situs. Tiga membawa penanda kedua; dua tidak:

  PointingView:279      laju sudut -- angka yang sama, kata yang sama, hanya
                        warnanya berubah. Jam yang bergetar terlalu cepat dan
                        jam yang diam terbaca identik bagi pengguna buta warna,
                        padahal seluruh guna baris itu adalah memberi tahu
                        bahwa arah tunjuk belum boleh dipercaya.
  Experiment1View:142   lokasi darurat -- teksnya bercabang pada fakta yang
                        sama, tetapi tidak satu katanya menyebut bahwa
                        tingginya dihitung untuk tempat lain.

Keduanya lolos seluruh 60 aturan sebelumnya, dan keduanya mengompilasi.

Keadaan yang diuji:

  [baseline]                            gerbang hijau (kalau tidak, harness salah)

  1. laju: kata "Cepat" dihapus         kembali ke warna-saja. Ini keadaan
                                        asli sebelum siklus ini.
  2. laju: cabang kata -> `if false`    kata ada di kode, tetapi tidak pernah
                                        tampil -- bentuk yang paling mudah
                                        lolos pemeriksaan naif "ada `if`".
  3. kalibrasi: angka pembanding hilang kedua angka yang dibandingkan adalah
                                        penanda keduanya; menampilkan satu saja
                                        mengembalikan warna-saja.
  4. kontrol negatif: repo apa adanya   tetap hijau.
  5. fail-closed: seluruh sinyal hilang aturan harus merah karena tidak
                                        mengukur apa pun (PERINGATAN).

Kenapa programnya diekstrak dari `swift-ui-lint.sh`: menyalin aturannya membuat
harness mengukur **salinan**, yang tetap hijau walau aturan aslinya
dilonggarkan.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
WATCH = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "PointingView.swift")
CALIB = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "CalibrationView.swift")

RULE_HEADER = "== Aturan 61:"
CLEAN_MARK = "semuanya punya penanda kedua"

KATA_CEPAT = """                    if tooFast {
                        Text(TextLocalization.text(.pointingRateTooFast))"""
SPREAD = """                            .foregroundStyle(spread <= maxSpread
                                             ? PointingTone.success.color
                                             : PointingTone.warning.color)"""

STATES = [
    ("[baseline]", None, False),
    ("1 laju: kata Cepat dihapus",
     [(WATCH, KATA_CEPAT,
       """                    if false {
                        Text(TextLocalization.text(.pointingRateTooFast))""", 1)],
     True),
    ("2 kalibrasi: angka pembanding hilang",
     [(CALIB,
       "Text(CalibrationText.spreadDisplay(spreadDeg: spread,\n                                                           maxDeg: maxSpread))",
       "Text(CalibrationText.offsetDisplay(degrees: spread))", 1)],
     True),
    ("3 kontrol negatif: repo apa adanya", None, False),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def extract_rule61():
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 61")
    if start < 0:
        return None
    end = text.find('if [ "$status" -eq 0 ]; then', start)
    if end < 0:
        return None
    return text[start:end]


def probe(program):
    proc = subprocess.run(["bash", "-s"], cwd=ROOT, input=program,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    return (CLEAN_MARK not in out), out.strip()


def main():
    targets = [WATCH, CALIB]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule61()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 61 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    for path, anchor in ((WATCH, KATA_CEPAT), (CALIB, SPREAD)):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar muncul {count}x di {path}, harus 1 -- "
                  "harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutations, must_fire in STATES:
            for path, content in _originals.items():
                mutasi_sumber.write_source(path, content)

            if mutations is not None:
                bad = False
                for target, old, replacement, jumlah in mutations:
                    base = _originals[target]
                    content = base.replace(old, replacement, jumlah)
                    if content == base:
                        print(f"{label:40s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(target, content)
                if bad:
                    unexpected += 1
                    continue

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:40s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            ok = (fired == must_fire)
            if fired and must_fire:
                ok = ("buta warna" in detail or "penanda kedua" in detail
                      or "PERINGATAN" in detail)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:40s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")

        # 5. Fail-closed: setiap `foregroundStyle(` yang berkondisi diganti
        # nama, sehingga aturan tidak menemukan satu sinyal pun. Harus merah
        # karena PERINGATAN, bukan hijau kosong.
        label = "5 fail-closed: sinyal warna hilang"
        for path in targets:
            isi = _originals[path]
            isi = isi.replace(".foregroundStyle(", ".warnaLama(")
            mutasi_sumber.write_source(path, isi)
        fired, detail = probe(program)
        ok = fired is True and "PERINGATAN" in (detail or "")
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:40s} "
              f"{'MERAH' if fired else 'hijau'}")
        if not ok:
            print(f"       {detail[:300]}")
    finally:
        restore()

    total = len(STATES) + 1
    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{total} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
