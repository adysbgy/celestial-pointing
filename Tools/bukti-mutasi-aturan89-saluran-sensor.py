#!/usr/bin/env python3
"""Bukti Aturan 89 berbunyi: tiga cacat, satu per satu, di salinan terpisah.

Kenapa harness ini ada.

Aturan 89 ditulis untuk cacat yang **lolos ketiga gerbang lokal** sebelum ia
ada (`Tools/sapu-buta-apps.py`, kandidat [0]). Gerbang baru yang hijau pada
hari ia ditulis tidak membuktikan apa pun; yang harus dibuktikan adalah bahwa
ia **bisa** merah, dan merah pada keadaan yang memang salah — bukan merah
karena berkasnya hilang atau karena regexnya salah tempat.

Dua kesalahan pertama versi aturan ini justru ditemukan dengan cara ini:
lookahead `(?!nil\\b)` menghitung 3 jalur, dan penelusuran blok ke depan
membuat jalur yang benar terbaca salah. Keduanya memerah pada kode yang
**benar**. Harness ini menahan keduanya: ada keadaan yang wajib hijau.

Keadaan yang diuji:

  0. pohon bersih                          -> HIJAU  (aturan tidak memerah
                                                      pada kode yang benar)
  1. `handleFailure` berhenti memberi tahu -> MERAH  (cacat aslinya)
  2. `start` berhenti memberi tahu         -> MERAH  (jalur kedua, bukan
                                                      hanya yang disapu)
  3. `publishSensorLoss` kehilangan
     `setSensorAvailable(false)`           -> MERAH  (dipanggil tapi isinya
                                                      dikosongkan)
  4. `MotionLogger.swift` dihapus          -> MERAH  (fail-closed, bukan
                                                      "bersih karena kosong")

Setiap keadaan memakai salinan pohon sendiri, dijalankan di proses baru, dan
berkas asli tidak pernah disentuh. Kalau ada keadaan yang hasilnya tidak
sesuai harapan, skrip ini keluar 1.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOTION = "Apps/Shared/MotionLogger.swift"
ATURAN = "Tools/check-aturan89-saluran-sensor.py"

# (nama, berkas, potongan lama, potongan baru, harus_merah, kata_kunci_pesan)
KEADAAN = [
    ("handleFailure berhenti memberi tahu", MOTION,
     "        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }\n        publishSensorLoss()\n    }",
     "        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }\n    }",
     True, "tidak memanggil publishSensorLoss"),

    ("start berhenti memberi tahu", MOTION,
     "            unavailableReason = SensorStatusText.motionMissing\n            // Lewat saluran yang sama dengan sampel: cuplikan UI harus ikut\n            // berubah, bukan hanya controller di belakangnya.\n            publishSensorLoss()\n            return",
     "            unavailableReason = SensorStatusText.motionMissing\n            return",
     True, "tidak memanggil publishSensorLoss"),

    ("publishSensorLoss kehilangan perintah henti", MOTION,
     "        let events = controller.setSensorAvailable(false)",
     "        let events: [HapticEvent] = []",
     True, "setSensorAvailable(false)"),

    ("MotionLogger dihapus", MOTION, None, None,
     True, "tidak ada"),
]


def jalankan(tree: str) -> tuple[int, str]:
    proc = subprocess.run(["python3", os.path.join(tree, ATURAN)],
                          cwd=tree, capture_output=True, text=True, timeout=120)
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def salin() -> str:
    """Salin hanya yang dibutuhkan aturan: satu berkas Apps + satu alat."""
    tmp = tempfile.mkdtemp(prefix="bukti89-")
    tree = os.path.join(tmp, "repo")
    os.makedirs(os.path.join(tree, "Apps", "Shared"), exist_ok=True)
    os.makedirs(os.path.join(tree, "Tools"), exist_ok=True)
    shutil.copy2(os.path.join(ROOT, MOTION), os.path.join(tree, MOTION))
    shutil.copy2(os.path.join(ROOT, ATURAN), os.path.join(tree, ATURAN))
    return tmp


def main() -> int:
    gagal = 0

    # Keadaan 0: pohon bersih wajib HIJAU. Tanpa ini, "merah" di bawah bisa
    # berarti aturannya salah tempat, bukan cacatnya tertangkap.
    tmp = salin()
    try:
        kode, pesan = jalankan(os.path.join(tmp, "repo"))
        sesuai = kode == 0
        print(f"[0] pohon bersih: exit {kode} "
              f"{'HIJAU (sesuai)' if sesuai else 'MERAH (TIDAK sesuai)'}")
        if not sesuai:
            print(f"    {pesan}")
            gagal += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    for i, (nama, rel, lama, baru, harus_merah, kata) in enumerate(KEADAAN, 1):
        tmp = salin()
        try:
            tree = os.path.join(tmp, "repo")
            path = os.path.join(tree, rel)
            if lama is None:
                os.remove(path)
            else:
                with open(path, encoding="utf-8") as fh:
                    isi = fh.read()
                if isi.count(lama) != 1:
                    print(f"[{i}] LEWAT (jangkar tidak unik/hilang): {nama}")
                    gagal += 1
                    continue
                with open(path, "w", encoding="utf-8") as fh:
                    fh.write(isi.replace(lama, baru, 1))
            kode, pesan = jalankan(tree)
            merah = kode != 0
            benar = merah == harus_merah and kata in pesan
            print(f"[{i}] {nama}: exit {kode} "
                  f"{'MERAH' if merah else 'HIJAU'} "
                  f"{'(sesuai)' if benar else '(TIDAK sesuai)'}")
            if not benar:
                print(f"    diharapkan merah={harus_merah} memuat {kata!r}")
                print(f"    dapat: {pesan[:400]}")
                gagal += 1
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    print(f"\n=== {len(KEADAAN) + 1 - gagal} dari {len(KEADAAN) + 1} keadaan sesuai harapan ===")
    return 1 if gagal else 0


if __name__ == "__main__":
    sys.exit(main())
