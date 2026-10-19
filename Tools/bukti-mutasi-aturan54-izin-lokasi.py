#!/usr/bin/env python3
"""Buktikan Aturan 54 (kejujuran izin lokasi LocationProvider) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
karena bentuk jujur yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya.

`Apps/Shared/LocationProvider.swift` adalah satu-satunya berkas yang membaca
izin lokasi (jam maupun iPhone). Ia cermin persis `MotionLogger` (Aturan 53):
enam titik jujur yang, kalau dibalik, membuat penolakan izin tampil senyap --
persis yang dilarang PRD. Diukur pada salinan utuh, proses baru, sebelum
Aturan 54 ada, **seluruh 53 aturan UI lolos (exit 0)**:

  denied note     -> nil     penolakan izin dibuang, layar diam
  restricted note -> nil     pembatasan perangkat dibuang, layar diam
  failed note     -> nil     kegagalan lokasi diam
  akurasi guard   -> hilang  lokasi akurasi invalid diterima sebagai sah

Yang paling berbahaya: `note` yang lenyap berarti lokasi darurat (Jakarta)
dipakai tanpa satu kata pun yang memberi tahu pengguna bahwa langit dihitung
untuk tempat lain. Itu bukan sekadar tidak rapi -- itu klaim yang salah
tentang tempat, dan tidak ada satu teks di layar yang bisa dibaca untuk
memeriksanya.

Satu cacat di **harness ini sendiri**, ditutup siklus ini, dan bisa dibaca
tanpa menjalankan apa pun:

  Setiap keadaan dulu ditulis sebagai dua string telanjang,
  `(label, jangkar, pengganti)`. Pembaca `Tools/check-jangkar-harness.py`
  hanya mengenali bentuk telanjang bila posisi 1 **bukan** jalur berkas --
  dan `"            note = SensorStatusText.locationDeniedNote"` (indentasi
  12 spasi sebagai bagian jangkar) dibaca sebagai **jalur relatif**, tepat
  karena ia memuat `/`. Akibatnya keenam pasangan di sini tercatat "tanpa
  berkas sasaran", dan gerbang jangkar mencetak keenamnya sebagai
  *jangkar hilang (pengganti tidak ada)* -- artinya gerbang itu tidak lagi
  menjaga satu pun mutasi di berkas ini, sementara harness-nya sendiri hijau.
  Dua gerbang, dua pendapat, dan yang lebih lemah yang dipercaya.

  Sekarang setiap mutasi menyebut `LOCATION` eksplisit. Bentuk
  `(path, jangkar, pengganti, jumlah)` **sudah** dikenali pembaca jangkar,
  jadi tidak ada pelonggaran di pembacanya: begitu jangkarnya terbaca,
  jangkar yang hilang menjadi **kebocoran**, dan itu memang memerah.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                        gerbang hijau (kalau tidak, harness salah)

  1. denied (start)     -> nil      satu dari dua jalur penolakan dibuang.
                                    Keadaan inilah yang membuktikan hitungan
                                    "tepat 2" perlu: dengan penjaga "ada >= 1",
                                    keadaan ini tetap hijau karena jalur kedua
                                    (delegasi) masih memanggil bentuknya.

  2. denied (delegasi)  -> nil      jalur kedua, arah yang sama.

  3. restricted (start) -> nil      pembatasan perangkat dibuang di satu jalur.

  4. restricted (deleg) -> nil      jalur kedua pembatasan.

  5. failed             -> nil      kegagalan lokasi dibungkam.

  6. akurasi guard      -> hilang   `horizontalAccuracy >= 0` dibuang; lokasi
                                    dengan akurasi -1 (invalid menurut
                                    CoreLocation) diterima sebagai lokasi sah.

  7. kontrol negatif: `self.note = nil` yang **sah** (mengosongkan catatan saat
     lokasi sungguhan tiba) tetap hijau. Gerbang yang memerah di sini salah:
     ia membunuh kode benar, dan gerbang yang membunuh kode benar akan
     dilonggarkan orang.

  8. fail-closed: berkas hilang     Aturan harus merah (PERINGATAN), bukan
                                    diam. Diuji dengan memindahkan berkasnya,
                                    bukan dengan menghapus bentuk jujurnya.

  9. bentuk `pin`: jendela 18 byte. Aturan yang membandingkan hanya 18 byte
     pertama jendela tidak bisa membedakan dua bentuk jujur yang **berbeda**
     (`…locationDeniedNote` vs `…locationRestrictedNote` berbagi awalan
     sampai kolom ke-18). Terukur pada pohon sehat: bentuk pin memerah
     karena ia **tidak menemukan** bentuknya sendiri. Keadaan ini tidak
     memutasi berkas produksi; yang diganti satu baris aturan.

 10. arah kedua: potongan aturan yang **dipakai repo ini**. Keadaan 9 hanya
     menunjukkan bentuk pin buta; keadaan ini menjalankan aturan yang sama
     tanpa pin atas mutasi yang sama dan menuntutnya hijau -- kalau aturan
     bentuk penuh sudah memerah pada pohon sehat, bagian 9 tidak membuktikan
     apa pun tentang pin.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap
hijau walau aturan aslinya dilonggarkan.

Berkas ini tidak memutasi sumber produksi secara permanen: setiap keadaan
menulis di atas salinan bersih dan memulihkannya terverifikasi
(`mutasi_sumber`). Pemulihan di `finally` menulis ulang **seluruh** berkas
yang dibaca, bukan hanya yang terakhir disentuh -- kalau proses ini dibunuh
di tengah, pemanggil berikutnya tidak boleh mengukur berkas yang termutasi.
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
LOCATION = os.path.join(ROOT, "Apps", "Shared", "LocationProvider.swift")

RULE_HEADER = "# ── Aturan 54:"
CLEAN_MARK = ("Bersih: LocationProvider tetap jujur saat izin lokasi "
              "ditolak/dibatasi/gagal.")

#: Jangkar: baris utuh, supaya mutasi tidak bergantung pada spasi.
#: `start()` dan `locationManagerDidChangeAuthorization` memanggil bentuk yang
#: sama dengan indentasi berbeda -- itu yang membedakan dua jalurnya.
DENIED_START = "            note = SensorStatusText.locationDeniedNote"
DENIED_DELEG = "                self.note = SensorStatusText.locationDeniedNote"
RESTRICT_START = "            note = SensorStatusText.locationRestrictedNote"
RESTRICT_DELEG = "                self.note = SensorStatusText.locationRestrictedNote"
FAILED = "            self.note = SensorStatusText.locationFailedNote(message)"
GUARD = ("        guard let last = locations.last, "
         "last.horizontalAccuracy >= 0 else { return }")
#: Bentuk **sah** yang tidak boleh memerah: mengosongkan catatan saat lokasi
#: sungguhan tiba. Ada 2 kali (start() dan delegasi), keduanya benar.
CLEAR = "            self.note = nil"

#: Bentuk `pin`: aturan berhenti membaca hitungannya sendiri.
#:
#: **Kenapa bukan `bentuk[0:0]`.** Versi pertama pin ini mengganti `bentuk`
#: dengan irisan kosong, dengan anggapan bahwa hitungan string kosong akan
#: selalu "cocok" sehingga aturan menjadi buta. Terukur: salah. String kosong
#: muncul **4214** kali di `LocationProvider.swift` yang sudah dibuang
#: komentarnya, sedangkan `wajib` bernilai 2/2/1/1 — jadi setiap bentuk gagal
#: dan aturan **memerah pada pohon sehat**. Pin itu bukan aturan buta; ia
#: aturan yang selalu berbunyi, dan keadaan 9 mengukur kebalikan dari yang
#: ditulis labelnya.
#:
#: Bentuk di bawah adalah cacat yang benar-benar terjadi pada aturan semacam
#: ini: pemeriksaannya dilumpuhkan (`if False:`) sementara hitungannya tetap
#: dijalankan. Aturan lalu menyatakan bersih atas apa pun — termasuk atas
#: `restricted (start) -> nil`.
PIN_NYATA = "if n != wajib:"
#: Bentuk pin: perbandingan dimatikan, hitungan tetap ada.
PIN_SALAH = "if False and n != wajib:"

STATES = [
    ("[baseline]", None, False),
    #
    # **Kenapa setiap mutasi menyebut `LOCATION`.** Bentuk telanjang
    # `(label, jangkar, pengganti)` membuat jangkar berindentasi dibaca
    # `check-jangkar-harness.py` sebagai **jalur berkas** (karena memuat
    # `/`), sehingga keenam pasangan di bawah tercatat "tanpa sasaran" dan
    # gerbang itu mencetak "jangkar hilang" untuk berkas ini. Bentuk
    # `(path, jangkar, pengganti, jumlah)` sudah dikenali pembaca jangkar;
    # tidak ada pelonggaran di pembacanya.
    ("1. denied (start) -> nil",
     [(LOCATION, DENIED_START, "            note = nil", 1)], True),
    ("2. denied (delegasi) -> nil",
     [(LOCATION, DENIED_DELEG, "                self.note = nil", 1)], True),
    ("3. restricted (start) -> nil",
     [(LOCATION, RESTRICT_START, "            note = nil", 1)], True),
    ("4. restricted (delegasi) -> nil",
     [(LOCATION, RESTRICT_DELEG, "                self.note = nil", 1)], True),
    ("5. failed -> nil",
     [(LOCATION, FAILED, "            self.note = nil", 1)], True),
    ("6. penjaga akurasi dihapus",
     [(LOCATION, GUARD,
       "        guard let last = locations.last else { return }", 1)], True),
    # 7. Kontrol negatif: bentuk sah tetap hijau. Tidak ada mutasi -- yang
    # diuji adalah bahwa gerbang **tidak** memerah pada berkas bersih yang
    # memang memuat `self.note = nil` dua kali.
    ("7. kontrol negatif: `self.note = nil` sah tidak memerah", None, False),
]

_originals = {}
_moved = []


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)
    for src, dst in _moved:
        if os.path.exists(dst) and not os.path.exists(src):
            shutil.move(dst, src)


def extract_rule54():
    text = open(LINT, encoding="utf-8").read()
    start = text.find(RULE_HEADER)
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


def pin_program():
    """Potongan aturan dengan `bentuk = bentuk[:18]`.

    Kalau baris rekamannya tidak ditemukan tepat sekali, aturan pra bukan
    aturan yang dipakai repo ini -- keadaan 9 tidak membuktikan apa pun, jadi
    proses dihentikan, bukan dilaporkan hijau.
    """
    program = extract_rule54()
    if program is None:
        raise SystemExit("GERBANG: potongan Aturan 54 tidak ditemukan -- "
                         "keadaan bentuk pin tidak bisa dijalankan.")
    if program.count(PIN_NYATA) != 1:
        raise SystemExit(
            f"GERBANG: bentuk {PIN_NYATA!r} muncul {program.count(PIN_NYATA)}x "
            "di Aturan 54; keadaan bentuk pin tidak bisa disusun.")
    return program.replace(PIN_NYATA, PIN_SALAH, 1)


def main():
    mutasi_sumber.require_clean_sources([LOCATION])

    program = extract_rule54()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 54 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)
    # Aturan yang sedang dipakai wajib memakai bentuk **penuh**. Kalau ia
    # sudah pin, keadaan 9 dan 10 mengukur hal yang sama.
    if program.count(PIN_NYATA) != 1:
        print(f"GERBANG: Aturan 54 tidak memuat `{PIN_NYATA}` tepat sekali "
              "-- bentuk rekamannya tidak dikenal; harness tidak boleh jalan.",
              file=sys.stderr)
        sys.exit(2)

    with open(LOCATION, encoding="utf-8") as handle:
        _originals[LOCATION] = handle.read()

    # Jangkar harus muncul tepat sekali di berkas bersih (kecuali CLEAR, yang
    # memang sah dua kali -- dan itulah yang diuji keadaan 7).
    for anchor in (DENIED_START, DENIED_DELEG, RESTRICT_START,
                   RESTRICT_DELEG, FAILED, GUARD):
        count = _originals[LOCATION].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {anchor!r} muncul {count}x di "
                  f"{LOCATION}, harus tepat 1 -- harness tidak boleh jalan.",
                  file=sys.stderr)
            sys.exit(2)
    if _originals[LOCATION].count(CLEAR) != 2:
        print(f"GERBANG: bentuk sah {CLEAR!r} harus muncul 2x (start + "
              f"delegasi) -- kontrol negatif tidak bisa diuji.", file=sys.stderr)
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
                        print(f"{label:56s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(target, content)
                if bad:
                    unexpected += 1
                    continue

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:56s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            names = any(n in detail for n in
                        ("LocationProvider", "locationDeniedNote",
                         "locationRestrictedNote", "locationFailedNote",
                         "horizontalAccuracy", "PERINGATAN", "bentuk jujur"))
            ok = (fired == must_fire) and (not fired or names)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if fired and not must_fire:
                print(f"       (tidak diharapkan memerah) {detail[:160]}")

        # 8. Fail-closed: berkas dipindahkan. Aturan harus merah, bukan diam.
        stash = LOCATION + ".harness-hidden"
        shutil.move(LOCATION, stash)
        _moved.append((LOCATION, stash))
        fired, detail = probe(program)
        _moved.clear()
        if os.path.exists(stash):
            shutil.move(stash, LOCATION)
        label = "8. fail-closed: berkas hilang -> PERINGATAN"
        ok = fired is True and "PERINGATAN" in (detail or "")
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
              f"{'MERAH' if fired else 'hijau'}")

        # 9 + 10. Mutasi yang sama (`restricted (start) -> nil`) diuji oleh dua
        # aturan: bentuk pin dan bentuk penuh yang dipakai repo ini. Yang
        # membuktikan sesuatu adalah **selisihnya** -- pin menyatakan bersih,
        # bentuk penuh menyatakan merah. Tanpa dua-duanya, keadaan 9 hanya
        # menunjukkan satu aturan berpendapat.
        mutasi_kembar = _originals[LOCATION].replace(
            RESTRICT_START, "            note = nil", 1)
        if mutasi_kembar == _originals[LOCATION]:
            print("SALAH 9/10: jangkar mutasi kembar tidak ditemukan")
            unexpected += 2
        else:
            for label, program_uji, must_fire in (
                    ("9. bentuk `pin`: aturan berhenti membaca bentuknya",
                     pin_program(), False),
                    ("10. bentuk penuh: cacat restricted (start) ditangkap",
                     program, True)):
                for path, content in _originals.items():
                    mutasi_sumber.write_source(path, content)
                mutasi_sumber.write_source(LOCATION, mutasi_kembar)
                fired, detail = probe(program_uji)
                if fired is None:
                    print(f"{label:56s} PROBE GAGAL JALAN: {detail}")
                    unexpected += 1
                    continue
                ok = (fired == must_fire)
                if not ok:
                    unexpected += 1
                print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
                      f"{'MERAH' if fired else 'hijau'}")
                if not ok:
                    print(f"       {detail[:160]}")
    finally:
        restore()

    total = len(STATES) + 3
    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{total} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
