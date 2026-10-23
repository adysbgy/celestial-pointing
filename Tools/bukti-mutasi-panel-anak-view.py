#!/usr/bin/env python3
"""Buktikan Aturan 35 versi baru (panel `struct` di Apps/) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia bisa merah, merah pada keadaan yang memang salah, dan merah karena
bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya, dan **diukur** di siklus ini.

Aturan 35 menjaga fakta yang **dibaca** sebuah berkas supaya tidak diganti
literal di berkas yang sama. Tetapi daftar "aksesor"-nya dibaca dari `func`
di PointingKit, jadi penerima fakta yang dideklarasikan sebagai `struct` di
`Apps/` tidak pernah terdaftar. Terukur pada pohon utuh, proses baru, sebelum
perubahan ini:

    Apps/PointAndKnowWatch/Sources/PointingView.swift:80
        isStale: engine.isDisplayingStaleObject   -> isStale: false
            swift-ui-lint.sh   LULUS (exit 0)   <- CELAH
    bandingkan kembarannya, yang sudah dijaga:
    Apps/PointAndKnowWatch/Sources/ReducedLuminanceView.swift
        isStale: engine.isDisplayingStaleObject   -> isStale: false
            swift-ui-lint.sh   MERAH

Dua baris yang sama bentuknya, dua berkas berbeda, dua hasil berbeda. Yang
membedakan bukan cacatnya melainkan **di mana penerimanya dideklarasikan**:
`ReducedLuminanceLabel.text(isStale:)` adalah `func` PointingKit (maka
terdaftar), `ObjectDetailView(isStale:)` adalah `struct` di `Apps/` (maka
tidak). Akibatnya kartu jawaban jam bisa dibungkam: `ObjectDetailView` tidak
menggambar catatan sisa **dan** tidak menyembunyikan badge keyakinan,
sehingga objek dari pandangan sebelumnya tampil persis seperti hasil
pengukuran sekarang.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                                  gerbang hijau (kalau tidak,
                                              harness salah)
  1. kartu jam: isStale -> false              cacat aslinya, persis yang
                                              terukur di atas.
  2. panel jam: isConfirmed -> true           parameter kedua, struct yang
                                              sama. Tanpa keadaan ini, aturan
                                              yang hanya mencari satu nama
                                              fakta akan lolos.
  3. panel iPhone: isStale -> false           **berkas kedua**: layar kedua,
                                              cacat yang sama. Satu layar
                                              benar tidak menutup layar lain.
  4. panel iPhone: isConfirmed -> true        arah kedua, berkas kedua.
  5. layar redup (kembar)                     tetangga yang sebelumnya sudah
     : isStale -> false                       merah -- membuktikan keempat
                                              keadaan di atas berbunyi di
                                              aturan yang **sama**, bukan di
                                              aturan lain yang kebetulan merah.
  6. kontrol negatif: repo apa adanya         tetap hijau.
  7. fail-closed: struct tidak terbaca        kalau pembaca deklarasi
                                              berhenti bekerja, aturan harus
                                              berbunyi -- bukan diam-diam
                                              kembali menjaga hanya `func`
                                              PointingKit sambil melaporkan
                                              "Bersih" (dua bug berturut,
                                              lihat catatan keadaan 7).
  8. arah kedua (lint pra-perbaikan)          lint SEBELUM perluasan wajib
                                              HIJAU atas keadaan 1 dan 3.
                                              Kalau lint lama sudah merah, ke 1
                                              dan 3 tidak membuktikan adanya
                                              lubang.

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
IPHONE = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                      "DiagnosticsView.swift")
REDUP = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "ReducedLuminanceView.swift")

RULE_HEADER = "# ── Aturan 35:"
WATCH_STALE = "isStale: engine.isDisplayingStaleObject,"
WATCH_CONFIRM = ("isConfirmed: engine.confirmsDisplayedIdentity,")
IPHONE_STALE = "isStale: engine.isDisplayingStaleObject,"
IPHONE_CONFIRM = ("isConfirmed: engine.confirmsDisplayedIdentity,")
REDUP_STALE = "isStale: engine.isDisplayingStaleObject)"
#: Bentuk yang dicari di keluaran aturan ketika ia berbunyi karena panel.
PANEL_MARK = "ObjectDetailView" if False else "diganti literal"

#: Nama `struct` di `Apps/` yang menerima fakta kejujuran (`let isStale:`),
#: dibaca dari sumber — bukan ditulis tangan. Dipakai keadaan 7 untuk
#: mengosongkan daftar panel: cabang fail-closed hanya tercapai kalau
#: **semua** penerima fakta lenyap, jadi mutasi satu nama saja tidak
#: menyentuhnya (terukur: dengan satu nama, keadaan 7 lulus hijau palsu).
PANEL_STRUCTS = ["ObjectDetailView", "DiagnosticsView", "LockArrivalPanel"]
#: Fakta kejujuran yang dibaca pembaca Panel — sama dengan `FAKTA_PANEL` di
#: `swift-ui-lint.sh`. Keadaan 7 mencabut deklarasi ini, bukan nama tipenya.
FAKTA_DIBACA = ["isStale", "isConfirmed"]

STATES = [
    ("[baseline]", None, False),
    ("1 kartu jam: isStale -> false",
     [(WATCH, WATCH_STALE, "isStale: false,", 1)], True),
    ("2 panel jam: isConfirmed -> true",
     [(WATCH, WATCH_CONFIRM, "isConfirmed: true,", 1)], True),
    ("3 panel iPhone: isStale -> false",
     [(IPHONE, IPHONE_STALE, "isStale: false,", 1)], True),
    ("4 panel iPhone: isConfirmed -> true",
     [(IPHONE, IPHONE_CONFIRM, "isConfirmed: true,", 1)], True),
    ("5 layar redup: isStale -> false (kembar)",
     [(REDUP, REDUP_STALE, "isStale: false)", 1)], True),
    ("6 kontrol negatif: repo apa adanya", None, False),
]

#: Keadaan yang diuji terhadap lint PRA-Perbaikan. Kalau lint lama sudah merah
#: atas mutasi yang sama, keadaan 1 dan 3 di atas tidak membuktikan adanya
#: lubang — ia hanya membuktikan aturan ini ada.
ARAH_KEDUA = [("2 lint lama: kartu jam isStale -> false",
               [(WATCH, WATCH_STALE, "isStale: false,", 1)]),
              ("3 lint lama: panel iPhone isStale -> false",
               [(IPHONE, IPHONE_STALE, "isStale: false,", 1)])]

#: Commit pra-perluasan: sebelum derivasi panel `struct` lahir.
#:
#: **Bukan `HEAD`.** Nilai itu adalah bug, dan bug-nya senyap: `HEAD` bergerak
#: bersama setiap commit, jadi sesudah harness ini di-commit, "lint lama" yang
#: dijalankan adalah lint **baru** — yang tentu saja melihat cacatnya, karena
#: itulah yang baru saja ditambahkan. Arah kedua lalu memerah pada setiap
#: keadaan, dan penyebabnya terbaca sebagai "lubangnya tidak nyata" padahal
#: yang salah adalah acuannya. Terukur 23 Okt 2026: `d392f92` (induk dari
#: `20b1d7b`, commit yang menambahkan harness ini) — Aturan 35 di sana hanya
#: membaca `func` PointingKit, tanpa satu pun `struct`; jadi ia memang **buta**
#: pada `ObjectDetailView`, dan itulah yang harus dibuktikan.
#:
#: SHA penuh, bukan singkat: `git show` menerima keduanya, tetapi SHA singkat
#: bisa menjadi ambigu saat repo tumbuh, dan kegagalannya akan muncul sebagai
#: "lint lama tidak terbaca" — terbaca seperti repo rusak, bukan seperti
#: acuan yang usang.
LINT_PRA = "d392f92fb2ba886315c30495d97deda21a793563"

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


_kontradiksi_var = "kontradiksi_literal=$(python3 - <<'PY' 2>&1"


def _bounds(text):
    start = text.find(RULE_HEADER)
    if start < 0:
        return None, None
    # Skrip Python pemeriksaannya ada di dalam `$(python3 - <<'PY' ... PY)`.
    # Blok aturan berakhir tepat sebelum `fi` yang menutup keputusan
    # merah/hijau, dan header aturan berikutnya adalah batas pengaman.
    #
    # **Kenapa program ditutup dengan `exit "$status"`.** Di
    # `swift-ui-lint.sh`, keputusan aturan ini baru diterjemahkan menjadi kode
    # keluar di **akhir berkas** (`exit "$status"`), jauh dari blok ini.
    # Program yang diekstrak untuk harness berhenti di `fi`, jadi `status=1`
    # di dalamnya tidak pernah menjadi kode keluar: mutasi yang membuat aturan
    # memerah akan "lulus" karena `bash -s` mengembalikan 0. Karena itu
    # program ini diakhiri `exit "$status"` supaya yang diukur harness sama
    # dengan yang dilihat CI.
    nxt = text.find("\n# ── Aturan 36:", start)
    if nxt < 0:
        return None, None
    fi = text.rfind("\nfi\n", start, nxt)
    if fi < 0:
        return None, None
    return start, fi + len("\nfi\n")


def extract_rule35():
    text = open(LINT, encoding="utf-8").read()
    start, end = _bounds(text)
    if start is None:
        return None
    body = text[start:end]
    # Aturan 35 menugaskan ke variabel `$kontradiksi_literal`; kalau nama itu
    # berubah, ekstraksi sudah tidak mengukur aturan yang sama.
    if _kontradiksi_var not in body:
        return None
    # `status=0` ditulis lebih dulu karena di berkas aslinya `status` sudah
    # diisi aturan-aturan sebelumnya (blok ini menambah, bukan memulai). Di
    # potongan ini belum ada yang mengisinya, dan `exit "$status"` dengan
    # `status` kosong membuat bash keluar dengan "numeric argument required"
    # — setiap keadaan jadi "PROBE GAGAL JALAN", persis kebalikan yang
    # diukur.
    return body + '\nstatus="${status:-0}"\nexit "$status"\n'


def probe(program, cwd=ROOT):
    """Jalankan program aturan; True = berbunyi, False = bersih."""
    proc = subprocess.run(["bash", "-s"], cwd=cwd, input=program,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    if "PERINGATAN" in out or "tidak mengukur" in out or "GAGAL" in out:
        return True, out.strip()
    return (re.search(r"^  Apps/", out, re.M) is not None), out.strip()


def jalankan_penuh():
    return subprocess.run(["bash", "swift-ui-lint.sh"], cwd=ROOT,
                          capture_output=True, text=True)


def main():
    targets = [WATCH, IPHONE, REDUP]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule35()
    if program is None or "Aturan 35" not in program:
        print("GERBANG: program Aturan 35 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    anchors = [(WATCH, WATCH_STALE), (WATCH, WATCH_CONFIRM),
               (IPHONE, IPHONE_STALE), (IPHONE, IPHONE_CONFIRM),
               (REDUP, REDUP_STALE)]
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
                ok = PANEL_MARK in detail or "faktanya" in detail
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:42s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")

        # 7. Fail-closed: seluruh `struct` penerima fakta diberi nama yang
        #    tidak dikenali pembaca. Aturan harus tidak menemukan panel apa
        #    pun, lalu memiringkan diri (PERINGATAN) — bukan hijau yang
        #    berpura-pura memeriksa panel yang sudah tidak ada.
        #
        #    **Kenapa seluruh nama, bukan satu.** Keadaan ini awalnya hanya
        #    mengganti `ObjectDetailView` -> `PanelLama`, dan itu terbukti
        #    tidak menguji apa pun: pembaca `struct` masih menemukan
        #    `LockArrivalPanel` dan `DiagnosticsView`, jadi `panel_terbaca`
        #    tetap berisi dan cabang fail-closed tidak pernah tercapai. Keadaan
        #    yang lulus "hijau" padahal mutasinya hanya menyentuh satu dari
        #    tiga penerima bukan bukti; kalau ia tetap di berkas ini, ia akan
        #    dikutip sebagai bukti oleh siklus berikutnya. Karena itu seluruh
        #    nama dikeluarkan sekaligus -- ini satu-satunya cara membuat
        #    cabang itu benar-benar tercapai.
        label = "7 fail-closed: panel Tidak dikenal"
        for path in _originals:
            mutasi_sumber.write_source(path, _originals[path])
        # **Yang dimutasi adalah fakta kejujurannya, bukan nama tipenya.**
        # Versi pertama mengganti nama struct (`ObjectDetailView` ->
        # `PanelLama`), dan itu terbukti tidak pernah mencapai cabang
        # fail-closed: pembaca menandai panel berdasarkan `let isStale:`
        # **di dalam** badan struct, bukan dari namanya, jadi struktur
        # bernama apa pun tetap terbaca — bahkan dengan tiga nama unik,
        # `panel_terbaca` terukur tetap berisi tiga entri. Nama yang sama
        # (`PanelLama` untuk ketiganya) malah membuat set-nya tinggal satu
        # entri. Jadi keadaan ini dinyatakan dengan mencabut **deklarasi
        # fakta**-nya, yang memang satu-satunya tanda yang dibaca pembaca:
        # itulah bentuk "pembaca berhenti mengenali apa pun", dan cabang
        # yang menjaga aturan supaya tidak melaporkan "Bersih" karenanya.
        for path in targets:
            kode = open(path, encoding="utf-8").read()
            for fakta in FAKTA_DIBACA:
                kode = re.sub(r"(?m)^(\s*)let\s+" + fakta + r"\s*:",
                              r"\1let faktaDihapus_%s:" % fakta, kode)
            mutasi_sumber.write_source(path, kode)
        fired, detail = probe(program)
        ok = fired is True and ("GAGAL" in (detail or "")
                                or "tidak mengukur" in (detail or ""))
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:42s} "
              f"{'MERAH' if fired else 'hijau'}")
        if not ok:
            print(f"       {detail[:300]}")

        # 8. Arah kedua: lint pra-perluasan wajib HIJAU atas mutasi yang
        #    sama. Kalau lint lama sudah merah, keadaan 1 dan 3 tidak
        #    membuktikan lubang.
        lama = mutasi_sumber._git(["show", f"{LINT_PRA}:swift-ui-lint.sh"])
        if lama.returncode != 0:
            print(f"{'SALAH'} {'8 arah kedua: lint lama tidak terbaca':42s}")
            unexpected += 1
        else:
            prog = extract_rule35_from_text(lama.stdout)
            for label, mutations in ARAH_KEDUA:
                for path, content in _originals.items():
                    mutasi_sumber.write_source(path, content)
                for target, old, new, jumlah in mutations:
                    mutasi_sumber.write_source(
                        target,
                        _originals[target].replace(old, new, jumlah))
                fired, detail = probe(prog)
                ok = fired is False
                if not ok:
                    unexpected += 1
                print(f"{'OK  ' if ok else 'SALAH'} {label:42s} "
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


def extract_rule35_from_text(text):
    start, end = _bounds(text)
    if start is None:
        return None
    body = text[start:end]
    if _kontradiksi_var not in body:
        return None
    return body


if __name__ == "__main__":
    main()
