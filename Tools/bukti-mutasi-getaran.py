#!/usr/bin/env python3
"""Bukti bahwa uji `HapticPolicy` memerah pada sumber yang menyimpang.

Kenapa berkas ini ada.
=====================

`HapticPolicyTests` (Packages/PointingKit) menuntut satu hal: getaran "ragu"
tidak boleh terasa seperti getaran "berhasil". Uji yang tidak pernah terbukti
memerah pada mutasi adalah uji yang tidak menahan apa pun.

Harness ini memutasi `HapticPolicy.swift`, menjalankan `./swift-test.sh`, dan
memastikan uji **memerah**. Setelah tiap keadaan, sumber dipulihkan dan md5-nya
diperiksa — harness yang meninggalkan mutasi akan merusak pohon untuk semua
gerbang sesudahnya.

Kenapa `mutasi_sumber` dipakai.
==============================

Menulis dengan `open(..., "w")` membuat mutasi bisa tertinggal bila proses
dibunuh di tengah. `Tools/mutasi_sumber.py` menulis atomik dan memulihkan
dengan verifikasi; `Tools/check-jangkar-harness.py` membacanya untuk memastikan
tidak ada jangkar yang hilang dari sumber asli.

Kenapa tiap keadaan menuntut **jumlah uji merah** yang berbeda.
==============================================================

"Merah" saja terlalu lemah: satu uji yang selalu gagal akan memerahkan setiap
keadaan tanpa membuktikan apa pun tentang yang lain. Karena itu keadaan
pertama menuntut tepat 3 kegagalan (yang menjawab langsung "ragu ≠ berhasil"),
sedangkan keadaan yang menghapus semua pola menuntut lebih banyak.
"""

import hashlib
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

import mutasi_sumber  # noqa: E402

SRC = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/HapticPolicy.swift")

#: Jangkar yang harus ada di sumber. Kalau salah satunya hilang, harness ini
#: berhenti: memutasi teks yang tidak ada akan "lulus" tanpa menguji apa pun.
JANGKAR = "public static func pattern(for event: HapticEvent) -> HapticPattern? {"

#: Keadaan: (nama, find, replace, jumlah_kegagalan_minimum).
#:
#: `find`/`replace` selalu non-kosong: `check-jangkar-harness.py` membaca
#: pengganti kosong sebagai "mutasi tertinggal", karena ia tidak bisa
#: membedakan penghapusan yang disengaja dari pemulihan yang gagal.
STATES = [
    ("ragu mendapat pola yang sama dengan berhasil",
     "        case .uncertain:\n            // **Wajib berbeda dari `.success`.** Ini inti dari berkas ini:\n            // kalau dua peristiwa ini bertemu di pola yang sama, pengguna\n            // yang tidak melihat layar kehilangan satu-satunya pembeda yang\n            // mereka punya.\n            return .unsettled",
     "        case .uncertain:\n            return .completed",
     3),

    ("semua peristiwa mendapat pola yang sama",
     "        case .sensorUnavailable:\n            return .failed\n        case .returnedToIdle:\n            return .tick",
     "        case .sensorUnavailable:\n            return .completed\n        case .returnedToIdle:\n            return .completed",
     3),

    ("tidak ada peristiwa yang bergetar",
     JANGKAR,
     JANGKAR + "\n        return nil",
     3),
]


def md5(path):
    with open(path, "rb") as handle:
        return hashlib.md5(handle.read()).hexdigest()


def run_tests():
    hasil = subprocess.run(["./swift-test.sh"], cwd=ROOT,
                           capture_output=True, text=True)
    keluaran = (hasil.stdout or "") + (hasil.stderr or "")
    gagal = None
    for baris in keluaran.splitlines():
        if "Executed" in baris and "failures" in baris:
            # "Executed 891 tests, with 3 failures (0 unexpected) in ..."
            bagian = baris.split("Executed", 1)[1]
            angka = bagian.strip().split(" ", 1)[0]
            if angka.isdigit():
                gagal = int(angka)
                sisa = bagian.split("with", 1)[1]
                gagal = int(sisa.strip().split(" ", 1)[0])
    return hasil.returncode, gagal, keluaran


def main():
    sumber_asli = open(SRC, encoding="utf-8").read()
    if JANGKAR not in sumber_asli:
        print("JANGKAR HILANG: `%s` tidak ada di %s" % (JANGKAR, SRC))
        return 2

    asli_md5 = md5(SRC)
    print("md5 sumber asli: %s" % asli_md5)

    kode, gagal, _ = run_tests()
    if kode != 0 or gagal:
        print("BASELINE TIDAK HIJAU (exit %s, %s kegagalan) — harness ini tidak "
              "bisa membuktikan apa pun." % (kode, gagal))
        return 2
    print("baseline: HIJAU (%d kegagalan)" % (gagal or 0))

    masalah = []
    for nama, find, replace, minimum in STATES:
        try:
            terkini = open(SRC, encoding="utf-8").read()
            if terkini.count(find) != 1:
                print("%-48s JANGKAR HILANG (%d kecocokan)"
                      % (nama, terkini.count(find)))
                masalah.append(nama)
                continue
            mutasi_sumber.write_source(SRC, terkini.replace(find, replace, 1))

            kode, gagal, keluaran = run_tests()
            merah = kode != 0 or bool(gagal)
            cukup = (gagal or 0) >= minimum
            print("%-48s %s (%d kegagalan, minimum %d)"
                  % (nama, "MERAH, sesuai harapan" if merah else "HIJAU (BOCOR)",
                     gagal or 0, minimum))
            if not merah or not cukup:
                masalah.append(nama)
                for baris in keluaran.splitlines():
                    if "error:" in baris or "failed" in baris:
                        print("    " + baris.strip()[:150])
        finally:
            mutasi_sumber.write_source(SRC, sumber_asli)

    pulih = md5(SRC)
    if pulih != asli_md5:
        print("SUMBER TIDAK PULIH: %s != %s" % (pulih, asli_md5))
        return 2
    print("sumber pulih byte-identik: %s" % pulih)

    if masalah:
        print("\nHapticPolicy: %d keadaan TIDAK sesuai harapan: %s"
              % (len(masalah), ", ".join(masalah)))
        return 1
    print("\nHapticPolicy: %d keadaan, semuanya sesuai harapan." % len(STATES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
