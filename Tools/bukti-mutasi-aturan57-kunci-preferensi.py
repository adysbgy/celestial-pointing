#!/usr/bin/env python3
"""Buktikan Aturan 57 (kunci preferensi lewat token) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
karena bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya.

`@AppStorage("nightModeEnabled")` di satu layar dan `@AppStorage("nightMode")`
di layar lain. Keduanya mengompilasi, keduanya berjalan, dan **keduanya
menyimpan ke tempat berbeda**. Pengguna menyalakan Mode Malam di jam, membuka
iPhone, dan mendapati Mode Malam mati -- sementara tidak satu pun layar
salah, dan tidak ada yang bisa dibaca untuk menyadarinya.

Diukur pada salinan utuh, proses baru, sebelum Aturan 57 ada: **seluruh 56
aturan lulus (exit 0)** untuk ketiga mutasi di bawah. Pada mode malam ini
bukan cacat kosmetik: palet merah satu-satunya yang menjaga rhodopsin, dan
pengguna yang mengira sudah menyalakannya mendapat layar putih di gelap.

Keadaan yang diuji:

  [baseline]                        gerbang hijau (kalau tidak, harness salah)

  1. Watch: night mode -> literal   kunci berubah di satu layar saja.
  2. iPhone: audio -> literal       bunyi kunci: aksesibilitas multi-modal.
  3. Watch: audio -> literal        sisi lain, arah yang sama.
  4. iPhone: night mode -> literal  layar kedua, preferensi yang sama.
  5. dua layar menulis literal yang sama
                                    bentuk yang **tampak** konsisten: kedua
                                    layar menyimpan "nightMode". Tetap merah,
                                    karena yang dijaga adalah satu sumber,
                                    bukan kesamaan hari ini.

  6. kontrol negatif: repo apa adanya tetap hijau.
  7. fail-closed: seluruh `@AppStorage` diganti `@SceneStorage`. Aturan harus
     merah (PERINGATAN), bukan hijau karena tidak mengukur apa pun.

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
WATCHAPP = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                        "PointAndKnowWatchWatchApp.swift")
IPHONE = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                      "DiagnosticsView.swift")

RULE_HEADER = "== Aturan 57:"
CLEAN_MARK = "Bersih: setiap preferensi memakai token penyimpanan yang sama."

NIGHT_WATCH = "@AppStorage(NightModeStorage.key) private var nightMode"
AUDIO_WATCH = "@AppStorage(AudioCueStorage.key) private var audioCueEnabled"
ONBOARD_WATCH = "@AppStorage(OnboardingStorage.key) private var onboardingSeen"

#: `DiagnosticsView.swift` memuat **dua** view yang masing-masing punya
#: `@AppStorage(NightModeStorage.key) private var nightMode` (layar diagnostik
#: dan layar pengaturan). Jangkar yang sah muncul lebih dari sekali di sana;
#: mutasinya mengganti **semua** kemunculan, karena itulah bentuk nyatanya
#: bila kuncinya diubah di sisi iPhone.
STATES = [
    ("[baseline]", None, False),
    ("1. Watch: night mode -> literal",
     [(POINTING, NIGHT_WATCH,
       '@AppStorage("nightMode") private var nightMode', 1)], True),
    ("2. iPhone: audio -> literal",
     [(IPHONE, AUDIO_WATCH,
       '@AppStorage("soundOn") private var audioCueEnabled', 1)], True),
    ("3. Watch: audio -> literal",
     [(POINTING, AUDIO_WATCH,
       '@AppStorage("audio") private var audioCueEnabled', 1)], True),
    ("4. iPhone: night mode -> literal",
     [(IPHONE, NIGHT_WATCH,
       '@AppStorage("nightModeOn") private var nightMode', -1)], True),
    ("5. dua layar menulis literal yang sama",
     [(POINTING, NIGHT_WATCH,
       '@AppStorage("nightMode") private var nightMode', 1),
      (IPHONE, NIGHT_WATCH,
       '@AppStorage("nightMode") private var nightMode', -1)], True),
    ("6. kontrol negatif: repo apa adanya", None, False),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def extract_rule57():
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 57")
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
    targets = [POINTING, WATCHAPP, IPHONE]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule57()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 57 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    # Setiap jangkar harus muncul sebanyak yang diharapkan. `IPHONE` memang
    # memuat dua view dengan `@AppStorage(NightModeStorage.key) private var
    # nightMode`; jumlah lain berarti kode berubah dan harness perlu ditinjau.
    for path, anchor, diharapkan in (
            (POINTING, NIGHT_WATCH, 1), (POINTING, AUDIO_WATCH, 1),
            (WATCHAPP, ONBOARD_WATCH, 1), (IPHONE, NIGHT_WATCH, 2),
            (IPHONE, AUDIO_WATCH, 1)):
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
                    # `-1` = ganti semua kemunculan.
                    content = base.replace(old, replacement, jumlah)
                    if content == base:
                        print(f"{label:42s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(target, content)
                if bad:
                    unexpected += 1
                    continue

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:42s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            ok = (fired == must_fire)
            if fired and must_fire:
                ok = ("AppStorage" in detail or "literal" in detail
                      or "sumber" in detail)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:42s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")

        # 7. Fail-closed: seluruh `@AppStorage` diganti `@SceneStorage`. Aturan
        # harus merah karena tidak lagi mengukur satu preferensi pun, bukan
        # hijau karena kosong.
        label = "7. fail-closed: tanpa @AppStorage"
        for path in targets:
            mutasi_sumber.write_source(
                path, _originals[path].replace("@AppStorage", "@SceneStorage"))
        fired, detail = probe(program)
        ok = fired is True and "PERINGATAN" in (detail or "")
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:42s} "
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
