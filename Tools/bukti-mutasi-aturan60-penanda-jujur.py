#!/usr/bin/env python3
"""Buktikan Aturan 60 (penanda kejujuran yang digambar) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
karena bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya.

59 aturan sebelumnya menjaga **dari mana** fakta kejujuran datang (Aturan
34/35/38/42/52 menelusuri argumen pemanggil dan badan penerus). Tidak satu pun
membaca **tempat penandanya digambar**. Diukur pada salinan utuh, proses baru,
sebelum Aturan 60 ada: **seluruh 59 aturan lulus (exit 0)** untuk ketujuh
mutasi di bawah -- semuanya mengompilasi, semuanya mencabut satu-satunya hal di
layar yang memberi tahu pengguna bahwa engine tidak yakin.

Keadaan yang diuji:

  [baseline]                              gerbang hijau (kalau tidak, harness salah)

  1. panel jam: catatan sisa -> `if false`     objek sisa tampil seperti hasil
                                              pengukuran sekarang.
  2. panel jam: `!isStale` dicabut             badge "Yakin" menempel pada objek
                                              basi -- klaim keyakinan atas
                                              pengukuran yang tidak berlaku.
  3. layar redup: penanda sisa -> `if false`   nama objek basi jadi huruf
                                              terbesar di layar, tanpa penanda.
  4. layar redup: penanda ragu -> `if false`   nama **kandidat** tampil sebagai
                                              temuan.
  5. panel iPhone: `!isStale` dicabut          layar kedua, cacat yang sama. Satu
                                              layar benar tidak menutup layar lain.
  6. panel iPhone: `stale: isStale` -> `false` arah kedua: badannya benar, yang
                                              berbohong pemanggilnya.
  7. panel jam: label a11y sisa -> `if false`  VoiceOver berhenti menyebut
                                              "sisa" -- yang melihat layar dan
                                              yang mendengarnya berbeda.
  8. kontrol negatif: repo apa adanya          tetap hijau.
  9. fail-closed: penanda diganti nama         aturan harus merah karena tidak
                                              mengukur apa pun (PERINGATAN), bukan
                                              hijau kosong.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap hijau
walau aturan aslinya dilonggarkan.

Kenapa berkas produksi dipulihkan lewat `mutasi_sumber`: tujuh harness lain
memutasi berkas yang sama, dan pemulihan yang gagal diam-diam pernah membuat
harness berikutnya mengukur berkas yang masih termutasi.
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
IPHONE = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                      "DiagnosticsView.swift")
KOMPLIKASI = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Complications",
                          "ComplicationWidget.swift")

RULE_HEADER = "== Aturan 60:"
CLEAN_MARK = "penanda kejujuran dijaga predikatnya"

CATATAN_SISA = "                if isStale {\n                    Text(TextLocalization.text(.objectDetailStaleNoteDisplay))"
BADGE_WATCH = "                    if let level, !isStale {"
SISA_REDUP = "                    if engine.isDisplayingStaleObject {"
RAGU_REDUP = "                    if engine.carriesUncertaintyMarker {"
BADGE_IPHONE = "                        if let level, !isStale {"
SISA_IPHONE = "                    stale: isStale,"
SISA_SUARA = "        if isStale {\n            parts.append(ObjectSpeech.staleNote)"

STATES = [
    ("[baseline]", None, False),
    ("1 panel jam: catatan sisa -> false",
     [(WATCH, CATATAN_SISA,
       "                if false {\n                    Text(TextLocalization.text(.objectDetailStaleNoteDisplay))", 1)],
     True),
    ("2 panel jam: !isStale dicabut",
     [(WATCH, BADGE_WATCH, "                    if let level {", 1)], True),
    ("3 redup: penanda sisa -> false",
     [(REDUP, SISA_REDUP, "                    if false {", 1)], True),
    ("4 redup: penanda ragu -> false",
     [(REDUP, RAGU_REDUP, "                    if false {", 1)], True),
    ("5 panel iPhone: !isStale dicabut",
     [(IPHONE, BADGE_IPHONE, "                        if let level {", 1)], True),
    ("6 panel iPhone: stale -> false",
     [(IPHONE, SISA_IPHONE, "                    stale: false,", 1)], True),
    ("7 panel jam: label a11y sisa -> false",
     [(WATCH, SISA_SUARA,
       "        if false {\n            parts.append(ObjectSpeech.staleNote)", 1)], True),
    ("8 kontrol negatif: repo apa adanya", None, False),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def extract_rule60():
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 60")
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
    targets = [WATCH, REDUP, IPHONE]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule60()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 60 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    for path, anchor in ((WATCH, CATATAN_SISA), (WATCH, BADGE_WATCH),
                         (WATCH, SISA_SUARA), (REDUP, SISA_REDUP),
                         (REDUP, RAGU_REDUP), (IPHONE, BADGE_IPHONE),
                         (IPHONE, SISA_IPHONE)):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {anchor!r} muncul {count}x di {path}, "
                  f"harus 1 -- harness tidak boleh jalan.", file=sys.stderr)
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

        # 9. Fail-closed: seluruh bentuk penanda diganti nama. Yang tersisa
        # hanya `Text(level.displayName)` (badge) -- dan itu memang bentuk yang
        # tidak bisa diganti nama, jadi aturan **masih mengukur** sesuatu.
        # Yang diuji di sini bukan "nol", melainkan bahwa cakupannya menyusut
        # dan angka yang dilaporkan jujur: bukan hijau kosong yang berpura-pura
        # memeriksa delapan penanda.
        label = "9 cakupan menyusut: penanda diganti nama"
        for path in targets:
            isi = _originals[path]
            isi = isi.replace(".objectDetailStaleNoteDisplay",
                              ".objectDetailStaleNoteLama")
            isi = isi.replace("ObjectSpeech.staleShortNote",
                              "ObjectSpeech.staleShortLama")
            isi = isi.replace("ObjectSpeech.staleNote",
                              "ObjectSpeech.staleLama")
            isi = isi.replace("TextLocalization.text(.confidenceUncertainMarker)",
                              "TextLocalization.text(.confidenceUncertainLama)")
            mutasi_sumber.write_source(path, isi)
        fired, detail = probe(program)
        ok = fired is False and "3 penanda kejujuran dijaga" in (detail or "")
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:38s} "
              f"{'MERAH' if fired else 'hijau'}")
        if not ok:
            print(f"       {detail[:300]}")

        # 10. Fail-closed sejati: **semua** bentuk diganti nama. Aturan harus
        # merah karena tidak mengukur apa pun (PERINGATAN), bukan hijau kosong.
        label = "10 fail-closed: semua penanda hilang"
        for path in targets + [KOMPLIKASI]:
            if path not in _originals:
                with open(path, encoding="utf-8") as handle:
                    _originals[path] = handle.read()
            isi = _originals[path]
            isi = isi.replace("level.displayName", "level.namaLama")
            isi = isi.replace(".objectDetailStaleNoteDisplay",
                              ".objectDetailStaleNoteLama")
            isi = isi.replace("ObjectSpeech.staleShortNote",
                              "ObjectSpeech.staleShortLama")
            isi = isi.replace("ObjectSpeech.staleNote",
                              "ObjectSpeech.staleLama")
            isi = isi.replace("TextLocalization.text(.confidenceUncertainMarker)",
                              "TextLocalization.text(.confidenceUncertainLama)")
            mutasi_sumber.write_source(path, isi)
        fired, detail = probe(program)
        ok = fired is True and "PERINGATAN" in (detail or "")
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:38s} "
              f"{'MERAH' if fired else 'hijau'}")
        if not ok:
            print(f"       {detail[:300]}")
    finally:
        restore()

    total = len(STATES) + 2
    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{total} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
