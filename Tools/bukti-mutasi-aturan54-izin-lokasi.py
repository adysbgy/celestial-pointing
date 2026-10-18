#!/usr/bin/env python3
"""Buktikan Aturan 54 (kejujuran izin lokasi LocationProvider) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
karena bentuk jujur yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya.

`Apps/Shared/LocationProvider.swift` adalah satu-satunya berkas yang membaca
izin lokasi (jam maupun iPhone). Ia cermin persis `MotionLogger` (Aturan 53):
empat titik jujur yang, kalau dibalik, membuat penolakan izin tampil senyap --
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

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap
hijau walau aturan aslinya dilonggarkan.

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
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
LOCATION = os.path.join(ROOT, "Apps", "Shared", "LocationProvider.swift")

RULE_HEADER = "== Aturan 54:"
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

STATES = [
    ("[baseline]", None, False),
    ("1. denied (start) -> nil", [(DENIED_START, "            note = nil")], True),
    ("2. denied (delegasi) -> nil", [(DENIED_DELEG, "                self.note = nil")], True),
    ("3. restricted (start) -> nil", [(RESTRICT_START, "            note = nil")], True),
    ("4. restricted (delegasi) -> nil", [(RESTRICT_DELEG, "                self.note = nil")], True),
    ("5. failed -> nil", [(FAILED, "            self.note = nil")], True),
    ("6. penjaga akurasi dihapus",
     [(GUARD, "        guard let last = locations.last else { return }")], True),
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
    start = text.find("# ── Aturan 54")
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
    mutasi_sumber.require_clean_sources([LOCATION])

    program = extract_rule54()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 54 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
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
                for old, new in mutations:
                    base = _originals.get(LOCATION)
                    content = base.replace(old, new, 1)
                    if content == base:
                        print(f"{label:56s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(LOCATION, content)
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
