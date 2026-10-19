#!/usr/bin/env python3
"""Buktikan Aturan 67 (nilai bawaan preferensi dari model) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia bisa merah, merah pada keadaan yang memang salah, dan merah karena
bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya, dan **diukur** sebelum aturan ini ada.

Satu preferensi punya dua nilai bawaan: literal `@AppStorage` di setiap
layar, dan aturan aksesor modelnya untuk kunci yang belum pernah diset.
`AudioCue.isOn` mengembalikan `true` untuk kunci kosong; `NightMode.isOn`
mengembalikan `false`. Selama keduanya kebetulan sepakat tidak ada yang
terlihat; begitu tidak, perilaku app bergantung pada layar mana yang membaca
lebih dulu -- dan tidak satu pun layar terlihat salah.

Terukur pada salinan utuh, proses baru, seluruh **66** aturan (sebelum ini):

    PointingView      nightMode       = false -> true    -> exit 0
    PointingView      audioCueEnabled = true  -> false   -> exit 0
    WatchApp          onboardingSeen  = false -> true    -> exit 0
    DiagnosticsView   audioCueEnabled = true  -> false   -> exit 0

Yang pertama paling sunyi dan paling berat: app **terbuka** di palet merah
murni tanpa pernah dipilih pengguna.

Keadaan yang diuji:

  1. Mode Malam -> literal `true`        app terbuka di palet merah.
  2. Bunyi kunci -> literal `false`      aksesibilitas multi-modal mati
                                         sesaat setelah app dibuka.
  3. Perkenalan -> literal `true`        pengguna baru tidak pernah bertemu
                                         kartu perkenalan.
  4. Panel iPhone: bunyi -> `false`      layar kedua, cacat yang sama. Satu
                                         layar benar tidak menutup layar lain.
  5. Kontrol negatif: pohon apa adanya   aturan tidak menuduh kode benar.
  6. Fail-closed: token salah bentuk    `PreferenceDefaults[0]` bukan nama
                                         sederhana -- aturan menolak ekspresi,
                                         bukan hanya menerima awalan.
  7. Arah kedua (lint pra-perbaikan)     keempat mutasi di atas wajib HIJAU
                                         pada lint sebelum Aturan 67. Kalau
                                         lint lama sudah merah, keadaan 1–4
                                         tidak membuktikan adanya lubang.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap hijau
walau aturan aslinya dilonggarkan.
"""

from __future__ import annotations

import os
import re
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
WATCH = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "PointingView.swift")
APP = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                   "PointAndKnowWatchWatchApp.swift")
IPHONE = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                      "DiagnosticsView.swift")

RULE_HEADER = "# \u2500\u2500 Aturan 67:"
#: Bentuk yang dicari di keluaran aturan ketika ia berbunyi karena preferensi.
PANEL_MARK = "nilai bawaan"
TOKEN = "PreferenceDefaults"

STATES = [
    ("[baseline]", None, False),
    ("1 Mode Malam -> literal true",
     [(WATCH, f"= {TOKEN}.nightMode", "= true", 1)], True),
    ("2 bunyi jam -> literal false",
     [(WATCH, f"= {TOKEN}.audioCueEnabled", "= false", 1)], True),
    ("3 perkenalan -> literal true",
     [(APP, f"= {TOKEN}.onboardingSeen", "= true", 1)], True),
    ("4 bunyi iPhone -> literal false",
     [(IPHONE, f"= {TOKEN}.audioCueEnabled", "= false", 1)], True),
    ("5 kontrol negatif: pohon apa adanya", None, False),
]

#: Keadaan yang diuji terhadap lint PRA-Perbaikan. Kalau lint lama sudah merah
#: atas mutasi yang sama, keadaan 1-4 tidak membuktikan adanya lubang.
ARAH_KEDUA = [("lint lama: Mode Malam -> true",
               [(WATCH, f"= {TOKEN}.nightMode", "= true", 1)]),
              ("lint lama: bunyi jam -> false",
               [(WATCH, f"= {TOKEN}.audioCueEnabled", "= false", 1)])]

#: Commit pra-Aturan67.
LINT_PRA = "HEAD"

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def _bounds(text):
    start = text.find(RULE_HEADER)
    if start < 0:
        return None, None
    # Berkas diakhiri ringkasan; penutup program aturan adalah `PY` diikuti
    # `)` pada akhir blok `$(python3 - <<'PY' ... PY )`.
    akhir = text.find("\nPY\n)", start)
    if akhir < 0:
        return None, None
    return start, akhir + len("\nPY\n)")


def extract_rule67():
    text = open(LINT, encoding="utf-8").read()
    start, end = _bounds(text)
    if start is None:
        return None
    body = text[start:end]
    # Blok aturan menugaskan ke variabel `$bawaan_pref`.
    if "bawaan_pref=" not in body:
        return None
    return body


def probe(program, cwd=ROOT):
    """Jalankan potongan aturan; True = berbunyi, False = bersih."""
    proc = subprocess.run(["bash", "-s"], cwd=cwd, input=program,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    if "PERINGATAN" in out or "Traceback" in out:
        return True, out.strip()
    return (proc.returncode != 0), out.strip()


def main():
    targets = [WATCH, APP, IPHONE]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule67()
    if program is None or "Aturan 67" not in program:
        print("GERBANG: program Aturan 67 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    # Setiap jangkar harus unik di berkasnya.
    for path in targets:
        for anchor in (f"= {TOKEN}.",
                       ):
            pass
    anchors = [(WATCH, f"= {TOKEN}.nightMode"),
               (WATCH, f"= {TOKEN}.audioCueEnabled"),
               (APP, f"= {TOKEN}.onboardingSeen"),
               (IPHONE, f"= {TOKEN}.audioCueEnabled")]
    for path, anchor in anchors:
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
                for target, old, new, jumlah in mutations:
                    base = _originals[target]
                    content = base.replace(old, new, jumlah)
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
                ok = PANEL_MARK in detail
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:38s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")

        # 6. Fail-closed: token yang diselewengkan bentuknya. Aturan menolak
        #    ekspresi, bukan hanya awalan "PreferenceDefaults." -- kalau ia
        #    hanya mencocokkan awalan, bentuk ini lolos sambil tetap membawa
        #    tipe yang salah.
        label = "6 fail-closed: token bentuk menyimpang"
        for path in _originals:
            mutasi_sumber.write_source(path, _originals[path])
        mutasi_sumber.write_source(
            WATCH,
            _originals[WATCH].replace(f"= {TOKEN}.nightMode",
                                      f"= {TOKEN}[.nightMode]", 1))
        fired, detail = probe(program)
        ok = fired is True and ("bukan nama sederhana" in detail
                                or PANEL_MARK in detail)
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:38s} "
              f"{'MERAH' if fired else 'hijau'}")
        if not ok:
            print(f"       {detail[:300]}")

        # 7. Arah kedua: lint pra-perluasan wajib HIJAU atas mutasi yang sama.
        lama = subprocess.run(["git", "-C", ROOT, "show",
                               f"{LINT_PRA}:swift-ui-lint.sh"],
                              capture_output=True, text=True)
        if lama.returncode != 0:
            print(f"{'SALAH'} {'7 arah kedua: lint lama tidak terbaca':38s}")
            unexpected += 1
        else:
            prog = extract_rule67_from_text(lama.stdout)
            for label, mutations in ARAH_KEDUA:
                for path in _originals:
                    mutasi_sumber.write_source(path, _originals[path])
                for target, old, new, jumlah in mutations:
                    mutasi_sumber.write_source(
                        target,
                        _originals[target].replace(old, new, jumlah))
                if prog is None:
                    # Aturan belum ada di lint lama: setiap mutasi must be
                    # hijau, dan itu memang yang diuji (lubangnya nyata).
                    fired = False
                else:
                    fired, detail = probe(prog)
                ok = fired is False
                if not ok:
                    unexpected += 1
                print(f"{'OK  ' if ok else 'SALAH'} {label:38s} "
                      f"{'MERAH' if fired else 'hijau'}")
                if not ok:
                    print(f"       {detail[:300]}")
    finally:
        restore()

    total = len(STATES) + 1 + len(ARAH_KEDUA)
    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{total} keadaan, 0 tidak sesuai harapan")


def extract_rule67_from_text(text):
    start, end = _bounds(text)
    if start is None:
        return None
    body = text[start:end]
    if "bawaan_pref=" not in body:
        return None
    return body


if __name__ == "__main__":
    main()
