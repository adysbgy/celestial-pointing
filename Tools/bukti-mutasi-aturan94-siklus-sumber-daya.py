#!/usr/bin/env python3
"""Bukti mutasi Aturan 94: apakah gerbangnya benar-benar mengukur?

Gerbang yang hijau di pohon yang seharusnya hijau belum membuktikan apa pun.
Yang membuktikan adalah: rusakkan siklus hidup sumber daya dengan cara yang
**wajar** dilakukan orang, lalu lihat apakah gerbang berbunyi.

Enam keadaan. Semuanya mutasi teks pada berkas asli yang dipulihkan dan
diverifikasi setelah setiap keadaan.

1. `setActive(false)` dihapus dari `AudioCueEngine.stop()` → bunyi. Ini cacat
   aslinya: sesi audio tidak pernah dilepas di mana pun.
2. Seluruh `stop()` dihapus dari `AudioCueEngine` → bunyi. Tipe yang memiliki
   akuisisi tanpa metode pelepasan sama sekali.
3. `audioCue.stop()` dihapus dari app **jam** saja → bunyi. Satu app yang
   melepas tidak menutupi app lain yang tidak. Ini keadaan yang paling penting:
   ia persis mutasi yang **membuat versi pertama gerbang ini hijau**, karena
   `motion.stop()` dan `engine.stop()` di berkas yang sama cocok dengan pola
   `stop()` yang tidak memeriksa penerimanya.
4. `audioCue.stop()` dihapus dari app **iPhone** saja → bunyi. Sisi lain dari
   keadaan 3: aturan ini tidak boleh hanya mengukur app jam.
5. `audioCue.stop()` dihapus dari **keduanya** → bunyi. Bentuk paling sunyi.
6. Pohon apa adanya → **diam**. Tanpa keadaan ini, gerbang yang selalu berbunyi
   akan tampak sama berhasilnya dengan gerbang yang mengukur.

Jalankan dari akar repo. Exit 0 = gerbang terbukti mengukur.
"""
import pathlib
import shutil
import subprocess
import sys

AKAR = pathlib.Path(".").resolve()
GERBANG = AKAR / "Tools/check-aturan94-siklus-sumber-daya.py"
CUE = AKAR / "Apps/Shared/AudioCue.swift"
JAM = AKAR / "Apps/PointAndKnowWatch/Sources/PointAndKnowWatchWatchApp.swift"
IPHONE = AKAR / "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"

PANGGIL_JAM = "        audioCue.stop()\n"
PANGGIL_IPHONE = "        audioCue.stop()\n"

LEPAS_SESI = """        try? AVAudioSession.sharedInstance().setActive(false,
                                                       options: .notifyOthersOnDeactivation)
"""


def jalankan():
    hasil = subprocess.run([sys.executable, str(GERBANG)],
                           cwd=AKAR, capture_output=True, text=True)
    return hasil.returncode, hasil.stdout + hasil.stderr


def baca(path):
    return path.read_text(encoding="utf-8")


def tulis(path, isi):
    path.write_text(isi, encoding="utf-8")


def keadaan(nama, mutasi, harus_bunyi):
    """Terapkan mutasi, jalankan gerbang, pulihkan, laporkan."""
    asli = {p: baca(p) for p in (CUE, JAM, IPHONE)}
    pulih_ok = True
    try:
        mutasi()
        kode, keluaran = jalankan()
    finally:
        for path, isi in asli.items():
            tulis(path, isi)
        # Verifikasi pemulihan, byte demi byte. Harness yang gagal pulih akan
        # mengadopsi kerusakannya sendiri sebagai "asli" pada keadaan
        # berikutnya — dan seluruh laporannya menjadi tak berarti.
        for path, isi in asli.items():
            if baca(path) != isi:
                print(f"FATAL pemulihan gagal untuk {path} setelah keadaan {nama}")
                pulih_ok = False

    if not pulih_ok:
        return False

    bunyi = kode != 0
    benar = bunyi == harus_bunyi
    tanda = "BUNYI" if bunyi else "DIAM "
    status = "benar" if benar else "SALAH"
    print(f"[{nama}] {tanda} ({status})")
    if not benar:
        print("  keluaran gerbang:")
        for baris in keluaran.strip().splitlines():
            print(f"    {baris}")
    return benar


def hapus_set_active_false():
    isi = baca(CUE)
    assert LEPAS_SESI in isi, "jangkar setActive(false) tidak ditemukan"
    tulis(CUE, isi.replace(LEPAS_SESI, ""))


def hapus_stop_cue():
    isi = baca(CUE)
    awal = isi.index("    func stop() {")
    akhir = isi.index("\n    }\n", awal) + len("\n    }\n")
    tulis(CUE, isi[:awal] + isi[akhir:])


def hapus_panggilan_jam():
    isi = baca(JAM)
    assert PANGGIL_JAM in isi, "jangkar audioCue.stop() jam tidak ditemukan"
    tulis(JAM, isi.replace(PANGGIL_JAM, "        // MUTASI: dihapus\n"))


def hapus_panggilan_iphone():
    isi = baca(IPHONE)
    assert PANGGIL_IPHONE in isi, "jangkar audioCue.stop() iPhone tidak ditemukan"
    tulis(IPHONE, isi.replace(PANGGIL_IPHONE, "        // MUTASI: dihapus\n"))


def hapus_panggilan_keduanya():
    hapus_panggilan_jam()
    hapus_panggilan_iphone()


def main():
    if not GERBANG.is_file():
        print(f"FATAL {GERBANG} tidak ada")
        return 1

    keadaan_uji = [
        ("1 setActive(false) dihapus", hapus_set_active_false, True),
        ("2 stop() cue dihapus", hapus_stop_cue, True),
        ("3 audioCue.stop() hilang di jam", hapus_panggilan_jam, True),
        ("4 audioCue.stop() hilang di iPhone", hapus_panggilan_iphone, True),
        ("5 audioCue.stop() hilang di keduanya", hapus_panggilan_keduanya, True),
        ("6 pohon apa adanya", lambda: None, False),
    ]

    semua_benar = True
    for nama, mutasi, harus_bunyi in keadaan_uji:
        semua_benar &= keadaan(nama, mutasi, harus_bunyi)

    print()
    if semua_benar:
        print("SEMUA SESUAI: Aturan 94 berbunyi pada kelima cacat dan diam pada "
              "pohon yang bersih.")
        return 0
    print("GAGAL: Aturan 94 tidak mengukur seperti yang diklaim.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
