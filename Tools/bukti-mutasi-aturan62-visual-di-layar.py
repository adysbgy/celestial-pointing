#!/usr/bin/env python3
"""Buktikan Aturan 62 (layar yang mengenali objek wajib menggambar visualnya)
**berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia bisa merah, merah pada keadaan yang memang salah, dan merah karena
bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya, dan ini yang membuatnya layak jadi gerbang:
kedua mutasi di bawah **mengompilasi**, aplikasinya tetap berjalan, engine
tetap mengunci objek dengan benar, namanya tetap tertulis di layar, dan
seluruh **61** aturan sebelumnya tetap hijau. Yang hilang hanya gambarnya --
persis hal yang seluruh misi poles ini minta.

Keadaan yang diuji:

  [baseline]                            gerbang hijau (kalau tidak, harness salah)

  1. kartu jam: `if let visual` -> `if false`
        Visual objek hilang dari satu-satunya tempat pengguna melihatnya saat
        `.lock`. Ini keadaan yang diukur sebelum aturan ini ada.
  2. panel iPhone: pemanggilan diganti `EmptyView()`
        Panel detail kehilangan gambarnya, teksnya utuh.
  3. kartu jam: pemanggilan dibungkus `if false { … }`
        Bentuk ketiga: pemanggilan masih ADA di berkas (jadi pemeriksaan
        "apakah nama itu muncul" akan hijau), tetapi tidak pernah tampil.
        Ini yang membedakan aturan ini dari grep.
  4. kontrol negatif: repo apa adanya   tetap hijau.

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
IPHONE = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                      "DiagnosticsView.swift")

RULE_HEADER = "== Aturan 62:"
CLEAN_MARK = "Bersih: 2 permukaan"

KARTU = """            if let visual {
                // Visual + denyutnya dipegang `PulsingCelestialVisual`: denyut"""
KARTU_MATI = """            if false {
                // Visual + denyutnya dipegang `PulsingCelestialVisual`: denyut"""

PANEL = """                CelestialVisualView(visual: visual,
                                     diameter: visualDiameter,"""
PANEL_MATI = """                EmptyView() // CelestialVisualView(visual: visual,
                                     diameter: visualDiameter,"""

BUNGKUS = """                CelestialVisualView(visual: visual,
                                    diameter: diameter,
                                    isConfirmed: isConfirmed,
                                    pulse: MotionPolicy.staticPulsePhase)
            }"""
BUNGKUS_MATI = """                if false {
                CelestialVisualView(visual: visual,
                                    diameter: diameter,
                                    isConfirmed: isConfirmed,
                                    pulse: MotionPolicy.staticPulsePhase)
                }
            }"""

STATES = [
    ("[baseline]", None, False),
    ("1 kartu jam: if let visual -> if false",
     [(WATCH, KARTU, KARTU_MATI, 1)], True),
    ("2 panel iPhone: pemanggilan -> EmptyView()",
     [(IPHONE, PANEL, PANEL_MATI, 1)], True),
    ("3 kartu jam: pemanggilan di bawah if false",
     [(WATCH, BUNGKUS, BUNGKUS_MATI, 1)], True),
    ("4 kontrol negatif: repo apa adanya", None, False),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def extract_rule62():
    text = open(LINT, encoding="utf-8").read()
    return mutasi_sumber.batas_aturan(text, 62)


def probe(program):
    proc = subprocess.run(["bash", "-s"], cwd=ROOT, input=program,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    return (CLEAN_MARK not in out), out.strip()


def main():
    targets = [WATCH, IPHONE]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule62()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 62 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    for path, anchor in ((WATCH, KARTU), (IPHONE, PANEL), (WATCH, BUNGKUS)):
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
                        print(f"{label:44s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(target, content)
                if bad:
                    unexpected += 1
                    continue

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:44s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            ok = (fired == must_fire)
            if fired and must_fire:
                ok = ("tidak memanggil" in detail or "selalu salah" in detail
                      or "tidak ada" in detail)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:44s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES) + 1} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
