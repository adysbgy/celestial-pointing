#!/usr/bin/env python3
"""Buktikan Aturan 55 (teks status wajib dibaca satu layar) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia bisa merah, merah pada keadaan yang memang salah, dan hijau pada
keadaan yang memang benar.

Kelas cacat yang ditutupnya.

Sebuah properti `@Published` berakhiran Note/Reason/Message/Label/Speech ditulis
berkali-kali -- tiap jalur kegagalan, tiap penolakan izin -- lalu tidak pernah
dibaca satu view pun. Terukur di `main` sebelum Aturan 55 ada:

    WatchLinkService.lastMessageNote   ditulis 7x, dibaca 0x

Tujuh jalur: kalibrasi tidak terkirim, pesan tidak terkirim, kirim gagal,
ambang tidak sah, permintaan keadaan terlalu dini, aktivasi sesi gagal, dan
catatan pesan masuk. Kembarannya di iPhone (`PhoneLinkService.lastNote`)
dibaca `LinkView` -- jadi membandingkan kedua service tidak mencurigakan:
keduanya punya properti catatan, hanya satu yang tersambung ke layar.

Yang membuat ini bukan kerapian: `link.send(calibration:)` satu-satunya jalan
hasil kalibrasi sampai ke iPhone. Saat sesi belum aktif ia menulis
`calibrationNotSent`, dan pengguna di jam melihat "Kalibrasi terpasang" dari
`statusMessage` lokal -- dua kalimat bertentangan, dan yang salah adalah yang
terlihat.

Keadaan yang diuji:

  [baseline]                        gerbang hijau (kalau tidak, harness salah)

  1. catatan dibuang dari layar     `link.lastMessageNote` tidak lagi dibaca
                                    berkas lain -> gerbang merah. Ini persis
                                    cacat aslinya, dan satu-satunya keadaan
                                    yang membuktikan aturan mengukur cacat
                                    nyata, bukan hanya mutasi buatan.

  2. properti teks status baru      `@Published ... lastRouteNote` ditambahkan
     yang tidak pernah dibaca       ke `WatchLinkService` tanpa pembaca ->
                                    merah. Membuktikan daftarnya **diturunkan
                                    dari sumber** (akhiran nama), bukan daftar
                                    nama yang ditulis tangan: properti baru
                                    ikut terjaga tanpa didaftarkan.

  3. properti baru yang dibaca      properti yang sama, tapi dibaca dari
                                    berkas lain -> hijau. Kontrol negatif:
                                    aturan tidak memerah pada teks status yang
                                    memang tersambung.

  4. pembacaan di berkas sendiri    properti dibaca **hanya** di berkas
     tidak dihitung                 deklarasinya (menulis lalu membaca di
                                    tempat yang sama, layar tetap tidak
                                    menerimanya) -> merah. Ini yang membuat
                                    `lastMessageNote` bisa lolos berbulan-bulan:
                                    `handle(_:)` membacanya untuk menyusun
                                    nilai berikutnya.

  5. fail-closed: Apps/ hilang      aturan harus merah (PERINGATAN), bukan
                                    diam. Hijau tanpa mengukur apa pun adalah
                                    hijau yang kosong.

  6. berkas view hilang             `CalibrationView.swift` dipindahkan:
                                    `lastMessageNote` kembali tanpa pembaca ->
                                    merah. Membuktikan sambungannya ada di
                                    view, bukan di suatu tempat lain.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: salinan akan tetap hijau walau aturan aslinya dilonggarkan.

Harness ini memutasi sumber sungguhan (aturan membacanya dari `Apps/`), jadi
setiap keadaan memakai `mutasi_sumber` untuk menulis dan memulihkan dengan
verifikasi.
"""

from __future__ import annotations

import os
import re
import shutil
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
LINK = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources", "WatchLinkService.swift")
VIEW = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources", "CalibrationView.swift")
APPS = os.path.join(ROOT, "Apps")

CLEAN_MARK = "Bersih: setiap teks status dibaca minimal satu layar."
RULE_HEADER = "== Aturan 55:"

#: Jangkar: baris utuh supaya mutasi tidak bergantung pada spasi.
READ_IN_VIEW = "        if let note = link.lastMessageNote {"
#: Deklarasi yang ditambahkan untuk keadaan 2/3/4.
NEW_PROP = ("    @Published public private(set) var lastRouteNote: String?\n")
NEW_PROP_NAME = "lastRouteNote"
#: Penulis properti baru: diletakkan sesudah deklarasi supaya bentuknya sama
#: dengan properti lain (ditulis di dalam kelas, bukan di luar).
NEW_WRITE = ("    @Published public private(set) var lastRouteNote: String?\n"
             "    private func markRoute(_ text: String) { lastRouteNote = text }\n")


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)
    for src, dst in _moved:
        if os.path.exists(dst) and not os.path.exists(src):
            shutil.move(dst, src)


def extract_rule55():
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 55")
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
    return (CLEAN_MARK not in proc.stdout), proc.stdout.strip()


_originals = {}
_moved = []


def main():
    mutasi_sumber.require_clean_sources([LINK, VIEW])

    program = extract_rule55()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 55 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in (LINK, VIEW):
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    if _originals[VIEW].count(READ_IN_VIEW) != 1:
        print(f"GERBANG: jangkar {READ_IN_VIEW!r} harus muncul tepat 1x di "
              f"{VIEW} -- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    results = []

    def reset():
        for path, content in _originals.items():
            mutasi_sumber.write_source(path, content)

    def run(label, must_fire):
        fired, detail = probe(program)
        if fired is None:
            print(f"{label:56s} PROBE GAGAL JALAN: {detail}")
            return False
        ok = (fired == must_fire)
        print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
              f"{'MERAH' if fired else 'hijau'}")
        if fired and not must_fire:
            print(f"       (tidak diharapkan memerah) {detail[:200]}")
        return ok

    try:
        # [baseline]
        reset()
        results.append(run("[baseline]", False))

        # 1. Cacat aslinya: catatan dibuang dari layar.
        reset()
        mutasi_sumber.write_source(
            VIEW, _originals[VIEW].replace(READ_IN_VIEW,
                                           "        // (catatan tautan dibuang)", 1))
        results.append(run("1. catatan tautan dibuang dari layar", True))

        # 2. Properti teks status BARU yang tidak pernah dibaca.
        reset()
        mutasi_sumber.write_source(LINK, _originals[LINK].replace(
            "    @Published public private(set) var lastMessageNote: String?\n",
            "    @Published public private(set) var lastMessageNote: String?\n" + NEW_PROP, 1))
        results.append(run("2. properti teks status baru, tanpa pembaca", True))

        # 3. Kontrol negatif: properti baru yang dibaca dari berkas lain.
        reset()
        mutasi_sumber.write_source(LINK, _originals[LINK].replace(
            "    @Published public private(set) var lastMessageNote: String?\n",
            "    @Published public private(set) var lastMessageNote: String?\n" + NEW_PROP, 1))
        mutasi_sumber.write_source(VIEW, _originals[VIEW].replace(
            "                    linkNote\n",
            "                    linkNote\n"
            f"                    if let r = link.{NEW_PROP_NAME} {{ Text(r) }}\n", 1))
        results.append(run("3. kontrol negatif: properti baru dibaca", False))

        # 4. Dibaca HANYA di berkas deklarasinya sendiri.
        reset()
        mutasi_sumber.write_source(LINK, _originals[LINK].replace(
            "    @Published public private(set) var lastMessageNote: String?\n",
            "    @Published public private(set) var lastMessageNote: String?\n"
            + NEW_WRITE + f"    private var routeEcho: String? {{ {NEW_PROP_NAME} }}\n", 1))
        results.append(run("4. dibaca hanya di berkas sendiri", True))

        # 5. Fail-closed: Apps/ hilang.
        stash = APPS + ".harness-hidden"
        shutil.move(APPS, stash)
        _moved.append((APPS, stash))
        fired, detail = probe(program)
        _moved.clear()
        if os.path.exists(stash):
            shutil.move(stash, APPS)
        ok = fired is True and "PERINGATAN" in (detail or "")
        print(f"{'OK  ' if ok else 'SALAH'} "
              f"{'5. fail-closed: Apps/ hilang -> PERINGATAN':56s} "
              f"{'MERAH' if fired else 'hijau'}")
        results.append(ok)

        # 6. Berkas view hilang: sambungannya memang ada di sana.
        reset()
        stash = VIEW + ".harness-hidden"
        shutil.move(VIEW, stash)
        _moved.append((VIEW, stash))
        fired, detail = probe(program)
        _moved.clear()
        if os.path.exists(stash):
            shutil.move(stash, VIEW)
        ok = fired is True
        print(f"{'OK  ' if ok else 'SALAH'} "
              f"{'6. berkas view hilang -> catatan tanpa pembaca':56s} "
              f"{'MERAH' if fired else 'hijau'}")
        results.append(ok)
    finally:
        restore()

    unexpected = sum(1 for r in results if not r)
    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(results)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
