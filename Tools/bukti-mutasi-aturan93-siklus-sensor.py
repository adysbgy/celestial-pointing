#!/usr/bin/env python3
"""Bukti mutasi Aturan 93: apakah gerbangnya benar-benar mengukur?

Gerbang yang hijau di pohon yang seharusnya hijau belum membuktikan apa pun.
Yang membuktikan adalah: rusakkan siklus hidup sensor dengan cara yang
**wajar** dilakukan orang, lalu lihat apakah gerbang berbunyi.

Lima keadaan, semuanya mutasi teks pada berkas asli yang dipulihkan setelah
setiap keadaan:

1. `stop()` dikosongkan seluruhnya → bunyi. Ini mutasi yang **terbukti lolos**
   dari 92 aturan UI sebelum aturan ini ada: sensor tetap hidup saat
   pergelangan diturunkan, dan tidak satu pun gerbang berbunyi.
2. Hanya `motion.stop()` dihapus → bunyi. Satu sumber yang tertinggal sudah
   cukup: motion 20 Hz adalah penguras baterai terbesar, dan
   `PointingEngine.stop()` tetap membatalkan objek sehingga cacatnya tidak
   akan terlihat di layar — hanya di baterai.
3. Hanya `location.stop()` dihapus → bunyi. Sumber berbeda, cacat sama.
4. `scenePhase` berhenti memanggil `stop()` (cabang latar jadi `break`) →
   bunyi. `stop()` yang benar tetapi tidak pernah dipanggil adalah bentuk
   paling menipu: kodenya terbaca sempurna.
5. Sensor kelima ditambahkan ke `start()` tanpa `stop()` → bunyi. Ini yang
   membuktikan daftarnya **dipanen** dari badan `start()`, bukan dua nama
   yang dibekukan: menambah sensor langsung menuntut pasangannya.
6. Pohon apa adanya → **diam**. Tanpa keadaan ini, gerbang yang selalu
   berbunyi akan tampak sama berhasilnya.

Jalankan dari akar repo. Exit 0 = gerbang terbukti mengukur.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

AKAR = pathlib.Path(".").resolve()
GERBANG = AKAR / "Tools/check-aturan93-siklus-sensor.py"
TITIK_MASUK = AKAR / "Apps/PointAndKnowWatch/Sources/PointAndKnowWatchWatchApp.swift"

STOP_PENUH = """    private func stop() {
        motion.stop()
        engine.stop()
        location.stop()
    }"""

STOP_KOSONG = """    private func stop() {
        // MUTASI: sensor dibiarkan hidup di latar
    }"""

CABANG_LATAR = """            case .inactive, .background:
                stop()"""

CABANG_LATAR_MATI = """            case .inactive, .background:
                break"""

# Titik sisip untuk sumber kelima: tepat setelah `location.start()`, di dalam
# `start()` — bukan di akhir berkas, yang akan menaruhnya di luar fungsi dan
# tidak terpanen sama sekali.
JANGKAR_START = "        location.start()"


def jalankan():
    hasil = subprocess.run([sys.executable, str(GERBANG)],
                           cwd=AKAR, capture_output=True, text=True)
    return hasil.returncode, hasil.stdout + hasil.stderr


def ganti(path, lama, baru):
    isi = path.read_text(encoding="utf-8")
    if lama not in isi:
        raise SystemExit(f"mutasi tidak bisa diterapkan: pola tidak ada di {path}")
    path.write_text(isi.replace(lama, baru, 1), encoding="utf-8")


def main():
    if not GERBANG.is_file():
        print(f"GAGAL {GERBANG} tidak ada: tidak ada yang bisa dibuktikan.")
        return 1
    if not TITIK_MASUK.is_file():
        print(f"GAGAL {TITIK_MASUK} tidak ada: tidak ada yang bisa dibuktikan.")
        return 1

    # Cadangan di luar repo supaya `git status` tidak ikut kotor.
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="bukti93-"))
    cadangan = tmp / TITIK_MASUK.name
    shutil.copy2(TITIK_MASUK, cadangan)

    def pulihkan():
        shutil.copy2(cadangan, TITIK_MASUK)

    # Keadaan bersih dulu: gerbang harus diam. Kalau tidak, semua "bunyi" di
    # bawah tidak membedakan apa pun.
    kode, keluaran = jalankan()
    if kode != 0:
        pulihkan()
        print("GAGAL gerbang sudah berbunyi di pohon bersih — bukti mutasi tidak")
        print("      bisa membedakan apa pun. Keluarannya:")
        print(keluaran)
        return 1
    print("  [0] pohon apa adanya ......................... DIAM (benar)")

    keadaan = [
        ("[1] stop() dikosongkan seluruhnya",
         lambda: ganti(TITIK_MASUK, STOP_PENUH, STOP_KOSONG)),
        ("[2] hanya motion.stop() dihapus",
         lambda: ganti(TITIK_MASUK, "        motion.stop()\n", "")),
        ("[3] hanya location.stop() dihapus",
         lambda: ganti(TITIK_MASUK, "        location.stop()\n", "")),
        ("[4] scenePhase berhenti memanggil stop()",
         lambda: ganti(TITIK_MASUK, CABANG_LATAR, CABANG_LATAR_MATI)),
    ]

    gagal = []
    for nama, mutasi in keadaan:
        pulihkan()
        try:
            mutasi()
        except SystemExit as e:
            gagal.append(f"{nama}: {e}")
            continue
        kode, keluaran = jalankan()
        if kode == 0:
            gagal.append(f"{nama}: gerbang tetap HIJAU padahal siklus hidupnya putus")
            print(f"  {nama:46s} HIJAU (salah)")
        else:
            print(f"  {nama:46s} BUNYI (benar)")

    # Keadaan 5: sumber kelima tanpa pasangan stop. Inilah bukti daftarnya
    # dipanen dari badan `start()`, bukan dibekukan.
    pulihkan()
    isi = TITIK_MASUK.read_text(encoding="utf-8")
    if JANGKAR_START not in isi:
        gagal.append("[5] prasyarat: `location.start()` tidak ditemukan di start()")
    else:
        TITIK_MASUK.write_text(
            isi.replace(JANGKAR_START,
                        JANGKAR_START + "\n        magnetometer.start()", 1),
            encoding="utf-8")
        kode, keluaran = jalankan()
        if kode == 0:
            gagal.append("[5] sumber kelima tanpa stop: gerbang tetap HIJAU — "
                         "daftarnya dibekukan, bukan dipanen")
            print("  [5] sumber kelima tanpa pasangan stop ........... HIJAU (salah)")
        else:
            print("  [5] sumber kelima tanpa pasangan stop ........... BUNYI (benar)")

    pulihkan()

    # Pastikan pemulihan benar-benar bersih sebelum keluar.
    kode, _ = jalankan()
    if kode != 0:
        print("GAGAL pohon tidak kembali bersih setelah mutasi — periksa git status.")
        return 1

    if gagal:
        print()
        for g in gagal:
            print(f"  GAGAL {g}")
        return 1

    print()
    print("Aturan 93 terbukti non-vakum: 6 keadaan, 5 berbunyi, pohon bersih diam.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
