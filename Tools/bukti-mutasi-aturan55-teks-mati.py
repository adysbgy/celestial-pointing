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

  7. hanya diumumkan, tidak tampil  baris `Text(note)` dibuang tetapi
                                    `.onChange` yang mengumumkannya tetap ada
                                    -> merah. Inilah lubang yang ditemukan
                                    harness ini sendiri pada percobaan pertama
                                    aturan: pengumuman VoiceOver adalah
                                    saluran **tambahan**, bukan pengganti
                                    tampilan. Tanpa keadaan ini, aturan bisa
                                    dilonggarkan ke arah itu dan tetap tampak
                                    hijau -- dan cacat aslinya kembali utuh
                                    satu tingkat lebih dalam.

  8. fail-closed: Apps/ hilang      (lihat keadaan 5)

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
#:
#: **Kenapa bukan `private var linkNote: some View {`.** Percobaan pertama di
#: bawah pohon ini memakai header komponen itu -- satu baris, unik, dan
#: memang terlihat seperti "tempat catatan ditampilkan". Terukur: keadaan 1
#: dan 7 **hijau**. Aturan 55 menentukan "teks ditampilkan" dari pembacaan
#: propertinya di **berkas lain**, bukan dari bentuk deklarasinya; membuang
#: header komponen tidak menghapus pembacaan `link.lastMessageNote` di
#: dalamnya, jadi yang diukur bukan yang dimutasi.
#:
#: **Kenapa keadaan 1 dan 7 tetap menunjuk baris itu, padahal ia jarang
#: berubah.** Jangkar di sini harus baris yang **dibaca aturan**: Aturan 55
#: menghitung pembacaan `<link>.lastMessageNote` di berkas lain, jadi
#: mengganti header komponen `linkNote` (percobaan pertama) tidak memeras
#: apa pun — keadaan 1 dan 7 tetap hijau. Mengubah baris ini, sebaliknya,
#: langsung menghapus pembacaan terakhir yang dihitung.
READ_IN_VIEW = "        if let note = link.lastMessageNote {"
#: Deklarasi yang ditambahkan untuk keadaan 2/3/4.
NEW_PROP = ("    @Published public private(set) var lastRouteNote: String?\n")
NEW_PROP_NAME = "lastRouteNote"
#: Penulis properti baru: diletakkan sesudah deklarasi supaya bentuknya sama
#: dengan properti lain (ditulis di dalam kelas, bukan di luar).
NEW_WRITE = ("    @Published public private(set) var lastRouteNote: String?\n"
             "    private func markRoute(_ text: String) { lastRouteNote = text }\n")

#: Jangkar yang **ditulis di tempat** oleh harness ini, dinyatakan di tingkat
#: modul bernama `STATES`.
#:
#: Kenapa tabel ini ada di sini, padahal `main()` tidak membacanya untuk
#: memutuskan mutasi: `Tools/check-jangkar-harness.py` membaca tabel keadaan
#: tingkat modul untuk mengetahui pasangan (berkas, jangkar) yang bisa
#: **tertinggal di sumber produksi** bila harness ini dihentikan di tengah
#: jalan (timeout, `SIGTERM`, `SIGKILL` — jalur yang sudah nyata terjadi di
#: repo ini). Harness ini merakit mutasinya dengan `.replace()` di dalam
#: `main()`, jadi pembaca statis tidak menemukan pasangan apa pun dan
#: melaporkan "nol jangkar": gerbangnya buta, dan pohon bersih tampak merah.
#:
#: Daftar ini **bukan** daftar keadaan kedua yang menentukan hasil. Ia
#: menyatakan jangkar mana yang ditulis, dan `_assert_states_are_real()`
#: menuntut setiap jangkar di sini benar-benar ada di berkasnya — supaya
#: tabel yang basi memerahkan harness ini, bukan menjadi dekorasi.
#:
#: Bentuk: `(berkas, jangkar, pengganti)`. Pengganti `None` berarti jangkar
#: hanya dihapus/disisipi (keadaan 1 dan 7 membuang baris tampilan).
STATES = [
    (VIEW, READ_IN_VIEW, "        // (catatan tautan dibuang: baris tampilan dihapus)"),
    (VIEW, READ_IN_VIEW, "        // (baris tampilan dibuang, pengumuman tetap)"),
    (LINK, "    @Published public private(set) var lastMessageNote: String?\n",
     "    @Published public private(set) var lastMessageNote: String?\n" + NEW_PROP),
    (VIEW, "                    linkNote\n",
     "                    linkNote\n"
     "                    if let r = link.lastRouteNote { Text(r) }\n"),
    (LINK, "    @Published public private(set) var lastMessageNote: String?\n",
     "    @Published public private(set) var lastMessageNote: String?\n" + NEW_WRITE),
]


def _assert_states_are_real():
    """Setiap jangkar di `STATES` wajib ada di berkasnya, tepat satu kali.

    Tanpa ini, `STATES` bisa menyebut jangkar yang sudah tidak ada dan tetap
    terlihat seperti dokumentasi yang sah — sementara gerbang jangkar
    melaporkan "jangkar hilang" yang sebenarnya hanya tabel basi. Harness
    yang mengukur dirinya sendiri lebih murah daripada pembaca yang menebak.
    """
    for path, anchor, _ in STATES:
        try:
            isi = open(path, encoding="utf-8").read()
        except OSError as galat:
            print(f"GERBANG: {path} tidak terbaca ({galat}) -- harness tidak "
                  "boleh jalan.", file=sys.stderr)
            sys.exit(2)
        jumlah = isi.count(anchor)
        if jumlah != 1:
            print(f"GERBANG: jangkar {anchor!r} muncul {jumlah}x di {path}, "
                  "harus 1 -- tabel STATES basi, harness tidak boleh jalan.",
                  file=sys.stderr)
            sys.exit(2)


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
    _assert_states_are_real()

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
                                           "        // (catatan tautan dibuang: baris tampilan dihapus)", 1))
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

        # 7. Hanya diumumkan, tidak ditampilkan.
        reset()
        mutasi_sumber.write_source(
            VIEW, _originals[VIEW].replace(READ_IN_VIEW,
                                           "        // (baris tampilan dibuang, pengumuman tetap)", 1))
        fired, detail = probe(program)
        ok = fired is True
        print(f"{'OK  ' if ok else 'SALAH'} "
              f"{'7. hanya diumumkan, tidak tampil':56s} "
              f"{'MERAH' if fired else 'hijau'}")
        if not ok:
            print("       pengumuman VoiceOver dihitung sebagai tampilan -- "
                  "cacat aslinya kembali satu tingkat lebih dalam")
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
