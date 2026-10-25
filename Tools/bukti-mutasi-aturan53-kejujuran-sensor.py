#!/usr/bin/env python3
"""Buktikan Aturan 53 (kejujuran sensor MotionLogger) **berbunyi**, bukan hijau.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
dengan pesan yang menunjuk pemanggilan yang dilanggar -- bukan sekadar
keluar != 0.

Kelas cacat yang ditutupnya.

`MotionLogger.swift` adalah satu-satunya berkas yang membaca sensor gerak
(jam maupun iPhone). Ia punya tiga titik jujur; kalau dibalik, jam terus
menampilkan objek terakhir sebagai "terkonfirmasi" padahal sensor mati --
persis yang dilarang PRD (false confidence). Diukur pada salinan utuh,
proses baru, **sebelum Aturan 53 ada semua lolos (exit 0)**:

  setSensorAvailable(false) -> (true)        lint/typecheck/test lolos
  unavailableReason = motionMissing -> nil    layar diam, alasan hilang
  isRunning = manager.isDeviceMotionActive
             -> true                          klaim sensor selalu hidup

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                       gerbang hijau (kalau tidak, harness salah)

  1. perintah sensor dibalik       Sensor mati dilaporkan hidup. Keadaan
     (false)->(true)               paling berbahaya: objek terakhir tetap
                                    tampak terkonfirmasi.

  2. alasan ketiadaan sensor       `unavailableReason` dihapus -> layar tidak
     dihapus (-> nil)              lagi memberi tahu kenapa kosong.

  3. klaim isRunning selalu hidup  `isRunning = true` -> UI percaya sensor
                                    menyala padahal mati.

  4. kontrol negatif: perintah      `setSensorAvailable(false)` yang **jujur**
     jujur tetap hijau              harus tetap hijau; gerbang yang memerah
                                    di sini salah (membunuh perintah benar).

  5. fail-closed: berkas hilang     Kalau `MotionLogger.swift` dipindah/
                                    digabung, aturan harus merah (PERINGATAN),
                                    bukan diam. Dibuktikan dengan menyuntikkan
                                    bentuk jujur lalu memastikan penjaga
                                    keberadaan berkas tetap bekerja: kami
                                    memakai titik jujur yang **hanya** ada di
                                    berkas ini, jadi mutasi yang menghapusnya
                                    memicu fail-closed.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap
hijau walau aturan aslinya dilonggarkan.
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
MOTION = os.path.join(ROOT, "Apps", "Shared", "MotionLogger.swift")

RULE_HEADER = "== Aturan 53:"
CLEAN_MARK = "Bersih: MotionLogger tetap jujur saat sensor tidak ada."

#: Jangkar: baris utuh, supaya mutasi tidak bergantung pada spasi.
SENSOR_LOSS = "        let events = controller.setSensorAvailable(false)"
REASON = "            unavailableReason = SensorStatusText.motionMissing"
RUNNING = "        isRunning = manager.isDeviceMotionActive"

STATES = [
    ("[baseline]", None, False),
    # 1. Sensor mati dilaporkan hidup.
    ("1. perintah sensor dibalik (false)->(true)",
     [(MOTION, SENSOR_LOSS,
       "        let events = controller.setSensorAvailable(true)")],
     True),
    # 1b. Bentuk berparameter juga dilarang.
    ("1b. perintah sensor dibalik (available: true)",
     [(MOTION, SENSOR_LOSS,
       "        let events = controller.setSensorAvailable(available: true)")],
     True),
    # 2. Alasan ketiadaan sensor dihapus.
    ("2. alasan ketiadaan sensor dihapus (-> nil)",
     [(MOTION, REASON, "            unavailableReason = nil")],
     True),
    # 3. Klaim isRunning selalu hidup.
    ("3. isRunning dipaksa true",
     [(MOTION, RUNNING, "        isRunning = true")],
     True),
    # 4. Kontrol negatif: perintah jujur tetap hijau.
    ("4. kontrol negatif: perintah jujur tidak memerah", None, False),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def extract_rule53():
    text = open(LINT, encoding="utf-8").read()
    return mutasi_sumber.batas_aturan(text, 53)


def probe(program):
    proc = subprocess.run(["bash", "-s"], cwd=ROOT, input=program,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    return (CLEAN_MARK not in out), out.strip()


def main():
    mutasi_sumber.require_clean_sources([MOTION])

    program = extract_rule53()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 53 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    with open(MOTION, encoding="utf-8") as handle:
        _originals[MOTION] = handle.read()

    # Jangkar harus muncul tepat sekali di berkas bersih.
    for anchor in (SENSOR_LOSS, REASON, RUNNING):
        count = _originals[MOTION].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {anchor!r} muncul {count}x di "
                  f"{MOTION}, harus tepat 1 -- harness tidak boleh jalan.",
                  file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for index, (label, mutations, must_fire) in enumerate(STATES, start=1):
            for path, content in _originals.items():
                mutasi_sumber.write_source(path, content)

            if mutations is not None:
                bad = False
                for path, old, new in mutations:
                    base = _originals.get(path)
                    content = base.replace(old, new, 1)
                    if content == base:
                        print(f"{label:56s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(path, content)
                if bad:
                    unexpected += 1
                    continue

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:56s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            names = any(n in detail for n in
                        ("setSensorAvailable", "unavailableReason",
                         "isRunning", "PERINGATAN", "bentuk jujur"))
            ok = (fired == must_fire) and (not fired or names)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if fired and not must_fire:
                print(f"       (tidak diharapkan memerah) {detail[:160]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
