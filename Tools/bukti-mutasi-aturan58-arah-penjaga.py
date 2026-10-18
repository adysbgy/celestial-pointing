#!/usr/bin/env python3
"""Buktikan Aturan 58 (arah penjaga gerak) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
karena bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya.

Aturan 7 menuntut **adanya** penjaga reduce-motion di blok yang sama, tetapi
tidak pernah menanyakan **arahnya**. Blok yang sama juga menyebut
`MotionPolicy.LockArrival.responseSeconds` di argumen `withAnimation`, dan
`MotionPolicy` cocok dengan penjaga Aturan 7 -- jadi mengganti penjaganya
dengan literal tetap hijau di sana.

Diukur pada salinan utuh, proses baru, sebelum Aturan 58 ada: **seluruh 57
aturan lulus (exit 0)** untuk ketiga mutasi di bawah.

Keadaan yang diuji:

  [baseline]                          gerbang hijau (kalau tidak, harness salah)

  1. transisi: guard -> `true`        gerak berjalan untuk semua orang, termasuk
                                      yang meminta berhenti.
  2. transisi: guard dibalik `!`      gerak berjalan **hanya** untuk pengguna
                                      yang meminta reduksi gerak. Ini yang
                                      paling berbahaya: cacatnya tidak bisa
                                      dilihat oleh orang yang tidak memakai
                                      preferensi itu -- termasuk pengembangnya.
  3. denyut: kondisi -> `true`        `TimelineView` 30 fps tanpa gerbang:
                                      baterai jam untuk piksel identik.
  4. iPhone: transisi dibalik `!`     layar kedua, arah yang sama. Satu layar
                                      benar tidak menutup layar lain.
  5. penjaga mentah tanpa `!`         `if reduceMotion {` -- bentuk yang
                                      **tampak** membaca preferensi, tetapi
                                      menghadap ke arah yang salah.
  6. kontrol negatif: repo apa adanya tetap hijau.
  7. fail-closed: seluruh API gerak diganti nama. Aturan harus merah
     (PERINGATAN), bukan hijau karena tidak mengukur apa pun.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap hijau
walau aturan aslinya dilonggarkan.
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
POINTING = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                        "PointingView.swift")
IPHONE = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                      "DiagnosticsView.swift")
ONBOARD = os.path.join(ROOT, "Apps", "Shared", "OnboardingView.swift")

RULE_HEADER = "== Aturan 58:"
CLEAN_MARK = "Bersih: setiap penjaga gerak menghadap arah yang benar."

TRANSISI = "guard motion.allowsTransitions else { return }"
DENYUT = "if motion.allowsContinuousMotion && visual.hasPulse {"

STATES = [
    ("[baseline]", None, False),
    ("1. transisi: guard -> true",
     [(POINTING, TRANSISI, "guard true else { return }", 1)], True),
    ("2. transisi: guard dibalik !",
     [(POINTING, TRANSISI, "guard !motion.allowsTransitions else { return }", 1)],
     True),
    ("3. denyut: kondisi -> true",
     [(POINTING, DENYUT, "if true && visual.hasPulse {", 1)], True),
    ("4. iPhone: transisi dibalik !",
     [(IPHONE, TRANSISI, "guard !motion.allowsTransitions else { return }", 1)],
     True),
    ("5. penjaga mentah tanpa !",
     [(POINTING, TRANSISI, "guard reduceMotion else { return }", 1)], True),
    ("6. kontrol negatif: repo apa adanya", None, False),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def extract_rule58():
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 58")
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
    targets = [POINTING, IPHONE, ONBOARD]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule58()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 58 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    for path, anchor, diharapkan in ((POINTING, TRANSISI, 1),
                                     (POINTING, DENYUT, 1),
                                     (IPHONE, TRANSISI, 1)):
        count = _originals[path].count(anchor)
        if count != diharapkan:
            print(f"GERBANG: jangkar {anchor!r} muncul {count}x di {path}, "
                  f"harus {diharapkan} -- harness tidak boleh jalan.",
                  file=sys.stderr)
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
                ok = ("gerak" in detail or "penjaga" in detail
                      or "reduceMotion" in detail or "allows" in detail)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:38s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")

        # 7. Fail-closed: seluruh API gerak diganti nama, sehingga aturan
        # berhenti mengukur satu penjaga pun. Harus merah, bukan hijau kosong.
        label = "7. fail-closed: tanpa API gerak"
        for path in targets:
            mutasi_sumber.write_source(
                path, _originals[path].replace("withAnimation", "withAnim"))
        fired, detail = probe(program)
        ok = fired is True and "PERINGATAN" in (detail or "")
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:38s} "
              f"{'MERAH' if fired else 'hijau'}")
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
