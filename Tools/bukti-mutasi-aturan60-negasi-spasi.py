#!/usr/bin/env python3
"""Buktikan Aturan 60 menangkap **negasi** penanda kejujuran, bukan hanya
penandanya yang dihapus.

Kenapa berkas ini ada.

`Tools/bukti-mutasi-aturan60-penanda-jujur.py` membuktikan Aturan 60 berbunyi
untuk delapan keadaan -- semuanya berbentuk "penanda dihapus"
(`if false`, `!isStale` dicabut, literal `false` dikirim pemanggil). Itu bentuk
paling kasar, dan memang layak diuji. Tapi ada bentuk kedua yang sama
berbahayanya dan belum pernah diukur: **predikatnya dibalik**. Kalau itu lolos,
layar menampilkan penanda "ragu" justru pada objek yang **yakin** dan
membungkamnya pada objek yang ragu -- kebalikan dari yang dituntut PRD, dan
lebih sulit dikenali dari `if false` karena kodenya tetap tampak "memeriksa
sesuatu".

Keadaan yang diukur di sini (masing-masing harus MERAH):

  1. `if engine.carriesUncertaintyMarker` -> `if ! engine.carriesUncertaintyMarker`
     (spasi setelah `!`) -- layar redup.
  2. `if !engine.carriesUncertaintyMarker` (tanpa spasi) -- varian yang sama.
  3. `if isStale` -> `if ! isStale` (spasi) pada panel jam -- penanda sisa
     dibalik: objek **segar** ditandai sisa, objek **basi** tidak.
  4. `if let level, !isStale` -> `if let level, isStale` pada badge keyakinan
     di panel jam -- badge "Yakin" menempel pada objek basi (sudah ada di
     probe lama sebagai keadaan 2/11; diulang di sini sebagai pengunci arah,
     karena harness ini adalah satu-satunya yang membaca varian spasi).
  5. `if engine.isDisplayingStaleObject` -> `if ! engine.isDisplayingStaleObject`
     (spasi) -- penanda sisa di layar redup dibalik.

Kenapa urutan `!`/spasi diperlakukan sebagai kelas terpisah: pemeriksaan lama
memakai `(?<![!])\\b<predikat>\\b` untuk memutusikan "predikat ini dibaca
positif". Lookbehind itu memandang **satu karakter** di belakang awal kata.
Dengan `if ! engine.carriesUncertaintyMarker` (spasi setelah `!`), karakter di
belakang kata adalah spasi, bukan `!` -- jadi predikat terbaca positif dan
mutasi lolos. Itu bukan hipotesis: terukur, seluruh 66 aturan hijau (exit 0)
untuk keadaan 1 dan 2 di atas. Karena itu probe ini **gagal** pada aturan yang
belum diperbaiki, dan lulus setelah perbaikannya.
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
REDUP = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "ReducedLuminanceView.swift")

RULE_HEADER = "== Aturan 60:"

# Bentuk **kondisi** di dalam `if` yang menggambar penanda. Sengaja ditulis
# lengkap dengan `{` supaya jangkarnya tidak cocok dengan pemanggilan fungsi
# lain yang memakai kata yang sama.
RAGU_REDUP_SPASI = "                    if engine.carriesUncertaintyMarker {"
RAGU_REDUP_TANPA_SPASI = "                    if engine.carriesUncertaintyMarker {"
SISA_REDUP_SPASI = "                    if engine.isDisplayingStaleObject {"
SISA_JAM = "            if isStale {\n                Text(TextLocalization.text(.objectDetailStaleNoteDisplay))"
BADGE_JAM = "                if let level, !isStale {"

STATES = [
    ("[baseline]", None, False),
    # 1: negasi **dengan** spasi. Inilah yang lolos pemeriksaan lama.
    ("1 redup: ragu dibalik '! ' (spasi)",
     [(REDUP, RAGU_REDUP_SPASI,
       "                    if ! engine.carriesUncertaintyMarker {", 1)],
     True),
    # 2: negasi tanpa spasi. Lookbehind `(?<![!])` menangkap ini, jadi
    #    keadaan ini harus tetap MERAH **sebelum dan sesudah** perbaikan --
    #    ia mengunci agar perbaikan tidak melonggarkan bentuk yang sudah benar.
    ("2 redup: ragu dibalik '!' (rapat)",
     [(REDUP, RAGU_REDUP_TANPA_SPASI,
       "                    if !engine.carriesUncertaintyMarker {", 1)],
     True),
    # 3: penanda sisa di layar redup dibalik, bentuk berspasi.
    ("3 redup: sisa dibalik '! ' (spasi)",
     [(REDUP, SISA_REDUP_SPASI,
       "                    if ! engine.isDisplayingStaleObject {", 1)],
     True),
    # 4: panel jam -- `if isStale` jadi `if ! isStale`. Bentuk ini juga
    #    berspasi, dan yang disalahkan adalah penanda sisa di panel utama.
    ("4 jam: sisa dibalik '! ' (spasi)",
     [(WATCH, SISA_JAM,
       "            if ! isStale {\n"
       "                Text(TextLocalization.text(.objectDetailStaleNoteDisplay))", 1)],
     True),
    # 5: badge keyakinan di panel jam -- `!isStale` dicabut. Bentuk rapats,
    #    sudah tertangkap; diulang sebagai pengunci arah.
    ("5 jam: badge 'Yakin' pada objek basi",
     [(WATCH, BADGE_JAM, "                if let level, isStale {", 1)],
     True),
    ("6 kontrol negatif: repo apa adanya", None, False),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def extract_rule60():
    text = open(LINT, encoding="utf-8").read()
    return mutasi_sumber.batas_aturan(text, 60)


def probe(program):
    proc = subprocess.run(["bash", "-s"], cwd=ROOT, input=program,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    # "Bersih: N penanda kejujuran dijaga predikatnya" == hijau.
    fired = "penanda kejujuran dijaga predikatnya" not in out
    return fired, out.strip()


def main():
    targets = [WATCH, REDUP]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule60()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 60 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    for target, anchor in ((REDUP, RAGU_REDUP_SPASI), (REDUP, SISA_REDUP_SPASI),
                           (WATCH, SISA_JAM), (WATCH, BADGE_JAM)):
        count = _originals[target].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar muncul {count}x di {target}, harus 1 -- "
                  f"harness tidak boleh jalan.", file=sys.stderr)
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
                        print(f"{label:38s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(target, content)
                if bad:
                    unexpected += 1
                    continue

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:38s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            ok = (fired == must_fire)
            if fired and must_fire:
                ok = ("penanda" in detail or "predikat" in detail
                      or "PERINGATAN" in detail)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:38s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")
    finally:
        restore()

    total = len(STATES)
    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{total} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
