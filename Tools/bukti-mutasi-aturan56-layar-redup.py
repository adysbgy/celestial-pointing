#!/usr/bin/env python3
"""Buktikan Aturan 56 (layar redup menerima versi hemat) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
karena bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya.

`NightAwareContainer` memilih **isi** mana yang tampil saat watchOS
meredupkan layar. Sebelum Aturan 56 ada, pemilihan itu berbunyi
`if isLuminanceReduced` di `Apps/PointAndKnowWatch/Sources/ReducedLuminanceView.swift`
-- berkas yang tidak pernah dibangun `swift-test.sh` di Linux dan tidak dibaca
badan satu pun dari 55 aturan UI yang ada saat itu.

Diukur pada salinan utuh, proses baru, sebelum Aturan 56 ada: **seluruh 55
aturan lulus (exit 0)** untuk keenam keadaan di bawah. Yang paling berbahaya
bukan yang mengosongkan layar, melainkan yang mengisinya kembali dengan layar
penuh: animasi, tombol, dan gestur yang justru diabaikan watchOS saat redup
kembali ke Always-On, dan tidak satu pun dari itu bisa terlihat dari layar
lain -- layar ini hanya tampil saat pergelangan diturunkan.

Keadaan yang diuji:

  [baseline]                       gerbang hijau (kalau tidak, harness salah)

  1. isi: layar penuh              `ReducedLuminanceView(engine:)` -> `fullView`.
                                   Layar redup menjadi layar interaktif penuh.

  2. isi: mesin baru               `ReducedLuminanceView(engine: PointingEngine())`.
                                   Mengompilasi, tampil rapi, dan **selalu**
                                   berbunyi "Mencari" -- mesin baru belum
                                   menerima satu sampel pun. Layar redup yang
                                   diam-diam berbohong tentang jam yang sedang
                                   terkunci.

  3. isi: kosong                   `EmptyView()`. Layar yang dibuat untuk
                                   dibaca sekilas menjadi kosong.

  4. kalibrasi: layar penuh        jalur kedua (`CalibrationView`), bukan hanya
                                   `PointingView`. Satu layar benar tidak
                                   menutup layar lain.

  5. pemilihan: if isLuminanceReduced
                                   keputusan isi kembali ditulis sendiri di
                                   view, melewati model yang diuji di Linux.

  6. pemilihan: selalu penuh       `choose(isLuminanceReduced: false)` -- bentuk
                                   yang **tampak** memakai model, tetapi
                                   membuang faktanya. Ini yang membuktikan
                                   Aturan 56 harus menuntut pengenalnya,
                                   bukan hanya nama fungsinya: dengan penjaga
                                   "ada `AlwaysOnContent.choose(`", keadaan ini
                                   hijau. (Aturan 35 juga menangkapnya; kedua
                                   gerbang merah, dan harness menuntut 56 ikut.)

  7. kontrol negatif: repo apa adanya tetap hijau. Gerbang yang memerah di sini
     salah -- ia membunuh kode benar, dan gerbang yang membunuh kode benar akan
     dilonggarkan orang.

  8. fail-closed: kedua pemanggil dilepas dari `NightAwareContainer`. Aturan
     harus merah (PERINGATAN), bukan hijau karena tidak mengukur apa pun.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap hijau
walau aturan aslinya dilonggarkan.

Berkas ini tidak memutasi sumber produksi secara permanen: setiap keadaan
menulis di atas salinan bersih dan memulihkannya terverifikasi
(`mutasi_sumber`).
"""

from __future__ import annotations

import os
import shutil
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
POINTING = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                        "PointingView.swift")
CALIBRATION = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                           "CalibrationView.swift")
REDUCED = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                       "ReducedLuminanceView.swift")

RULE_HEADER = "== Aturan 56:"
CLEAN_MARK = ("Bersih: setiap layar redup memakai versi hemat dari mesinnya "
              "sendiri.")

#: Jangkar di `PointingView.swift`: blok `reduced:` yang sah.
POINTING_REDUCED = (
    "        } reduced: {\n"
    "            ReducedLuminanceView(engine: engine)\n"
    "        }"
)
#: Jangkar di `CalibrationView.swift`: isi `reduced:` yang sah.
CALIBRATION_REDUCED = "            ReducedLuminanceView(engine: engine)\n        }"
#: Jangkar di `ReducedLuminanceView.swift`: keputusan isi.
SWITCH = (
    "        switch AlwaysOnContent.choose(isLuminanceReduced: isLuminanceReduced) {\n"
    "        case .reduced:\n"
    "            reduced()\n"
    "        case .full:\n"
    "            content()\n"
    "        }"
)
SWITCH_LAMA = (
    "        if isLuminanceReduced {\n"
    "            reduced()\n"
    "        } else {\n"
    "            content()\n"
    "        }"
)
CHOOSE = "AlwaysOnContent.choose(isLuminanceReduced: isLuminanceReduced)"

STATES = [
    ("[baseline]", None, False),
    ("1. isi: layar penuh",
     [(POINTING, POINTING_REDUCED,
       "        } reduced: {\n            fullView\n        }")], True),
    ("2. isi: mesin baru",
     [(POINTING, POINTING_REDUCED,
       "        } reduced: {\n            ReducedLuminanceView(engine: "
       "PointingEngine())\n        }")], True),
    ("3. isi: kosong",
     [(POINTING, POINTING_REDUCED,
       "        } reduced: {\n            EmptyView()\n        }")], True),
    ("4. kalibrasi: layar penuh",
     [(CALIBRATION, CALIBRATION_REDUCED,
       "            calibrationContent\n        }")], True),
    ("5. pemilihan: if isLuminanceReduced",
     [(REDUCED, SWITCH, SWITCH_LAMA)], True),
    ("6. pemilihan: selalu penuh",
     [(REDUCED, CHOOSE,
       "AlwaysOnContent.choose(isLuminanceReduced: false)")], True),
    ("7. kontrol negatif: repo apa adanya", None, False),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def extract_rule56():
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 56")
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
    targets = [POINTING, CALIBRATION, REDUCED]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule56()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 56 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    # Jangkar harus muncul tepat sekali di berkas bersih.
    for path, anchor in ((POINTING, POINTING_REDUCED),
                         (CALIBRATION, CALIBRATION_REDUCED),
                         (REDUCED, SWITCH)):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {anchor!r} muncul {count}x di {path}, "
                  f"harus tepat 1 -- harness tidak boleh jalan.",
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
                for target, old, replacement in mutations:
                    base = _originals[target]
                    content = base.replace(old, replacement, 1)
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
                # Harus merah karena bentuk yang dilanggar, bukan karena
                # aturan lain di dalam program yang sama ikut memerah.
                ok = ("redup" in detail or "reduced" in detail
                      or "NightAwareContainer" in detail)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:40s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")

        # 8. Fail-closed: kedua pemanggil dilepas seluruhnya dari
        # `NightAwareContainer` (pembungkusnya ikut dibuang, supaya yang
        # memerah benar-benar "tidak ada pemanggil" dan bukan kode yang tidak
        # mengompilasi).
        label = "8. fail-closed: tanpa pemanggil"
        for path, anchor, replacement in (
                (POINTING,
                 "        NightAwareContainer {\n"
                 "            fullView\n"
                 "        } reduced: {\n"
                 "            ReducedLuminanceView(engine: engine)\n"
                 "        }",
                 "        fullView"),
                (CALIBRATION,
                 "        NightAwareContainer {\n"
                 "            calibrationContent\n"
                 "        } reduced: {\n"
                 "            // Saat layar redup, alur kalibrasi tidak bisa dijalankan (gestur\n"
                 "            // diabaikan sistem), dan layar ini memang tidak punya apa pun yang\n"
                 "            // harus terbaca sekilas selain nama objek & status. Karena itu\n"
                 "            // tampilan jam yang dipakai — bukan versi khusus kedua.\n"
                 "            ReducedLuminanceView(engine: engine)\n"
                 "        }",
                 "        calibrationContent")):
            base = _originals[path]
            if anchor not in base:
                print(f"{label:40s} JANGKAR FAIL-CLOSED TIDAK DITEMUKAN")
                unexpected += 1
                continue
            mutasi_sumber.write_source(path, base.replace(anchor, replacement, 1))
        fired, detail = probe(program)
        ok = fired is True and "PERINGATAN" in (detail or "")
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:40s} "
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
