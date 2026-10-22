#!/usr/bin/env python3
"""Bukti mutasi Aturan 92: apakah gerbangnya benar-benar mengukur?

Gerbang yang hijau di pohon yang seharusnya hijau belum membuktikan apa pun.
Yang membuktikan adalah: rusakkan sambungannya dengan cara yang **wajar**
dilakukan orang, lalu lihat apakah gerbang berbunyi.

Enam keadaan diuji, semuanya mutasi teks pada berkas asli yang dipulihkan
setelah setiap keadaan:

1. Cabang fase Bulan dihapus dari `PointingView.swift` (app jam) → bunyi.
   Ini mutasi yang **terbukti lolos** dari 91 aturan UI sebelum aturan ini
   ada: gambar tetap menunjukkan sabit, suara tidak menyebutnya.
2. Cabang morfologi objek langit dalam dihapus dari `DiagnosticsView.swift`
   (app iPhone) → bunyi. Perangkat yang berbeda, berkas yang berbeda.
3. Cabang warna bintang dihapus dari **kedua** app → bunyi.
4. Pemanggilan dipertahankan tetapi `.accessibilityLabel` dihapus dari berkas
   itu → bunyi. Bentuk ini lolos dari sapuan yang hanya menghitung kemunculan
   nama aksesor, jadi ia diuji terpisah.
5. Aksesor kelima ditambahkan ke `public extension CelestialVisual` tanpa
   pemanggil di app mana pun → bunyi. Ini yang membuktikan daftarnya
   **dipanen**, bukan empat nama yang dibekukan: katalog visual yang bertambah
   langsung menuntut sambungan baru.
6. Pohon apa adanya → **diam**. Tanpa keadaan ini, gerbang yang selalu berbunyi
   akan tampak sama berhasilnya.

Jalankan dari akar repo. Exit 0 = gerbang terbukti mengukur.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

AKAR = pathlib.Path(".").resolve()
GERBANG = AKAR / "Tools/check-aturan92-suara-visual.py"

PV = AKAR / "Apps/PointAndKnowWatch/Sources/PointingView.swift"
DV = AKAR / "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"
PAKET = AKAR / "Packages/PointingKit/Sources/PointingKit/MoonPhaseSpeech.swift"
m_ekstensi = re.compile(r"public\s+extension\s+CelestialVisual\s*\{", re.M)

CABANG_FASE_PV = """        if let phase = visual?.spokenPhase(isConfirmed: isConfirmed) {
            parts.append(phase)
        }
"""
CABANG_FASE_DV = """        if let phase = visual?.spokenPhase(isConfirmed: isConfirmed) {
            parts.append(phase)
        }
"""
CABANG_MORFO_DV = """        if let morphology = visual?.spokenDeepSkyMorphology(isConfirmed: isConfirmed) {
            parts.append(morphology)
        }
"""
CABANG_WARNA_PV = """        if let color = visual?.spokenStarColor(isConfirmed: isConfirmed) {
            parts.append(color)
        }
"""
CABANG_WARNA_DV = """        if let color = visual?.spokenStarColor(isConfirmed: isConfirmed) {
            parts.append(color)
        }
"""


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

    # Cadangan di luar repo supaya `git status` tidak ikut kotor.
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="bukti92-"))
    cadangan = {}
    for p in (PV, DV, PAKET):
        cadangan[p] = tmp / p.name
        shutil.copy2(p, cadangan[p])

    def pulihkan():
        for p, b in cadangan.items():
            shutil.copy2(b, p)

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
        ("[1] cabang fase dihapus (app jam)", lambda: ganti(PV, CABANG_FASE_PV, "        // MUTASI\n")),
        ("[2] cabang morfologi dihapus (iPhone)", lambda: ganti(DV, CABANG_MORFO_DV, "        // MUTASI\n")),
        ("[3a] cabang warna dihapus (app jam)", lambda: ganti(PV, CABANG_WARNA_PV, "        // MUTASI\n")),
        ("[3b] cabang warna dihapus (iPhone)", lambda: ganti(DV, CABANG_WARNA_DV, "        // MUTASI\n")),
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
            gagal.append(f"{nama}: gerbang tetap HIJAU padahal sambungannya putus")
            print(f"  {nama:46s} HIJAU (salah)")
        else:
            print(f"  {nama:46s} BUNYI (benar)")

    # Keadaan 4: aksesor dipanggil, tapi hasilnya tidak pernah sampai ke
    # pembaca layar. Dipisah karena syaratnya berbeda: berkas ini punya
    # delapan `.accessibilityLabel` lain, jadi syarat "berkasnya memuat
    # `.accessibilityLabel`" lolos walau rantainya putus. Versi pertama
    # checker ini memang lolos di sini — itu yang membuat keadaan ini ada.
    pulihkan()
    isi = PV.read_text(encoding="utf-8")
    lama = ".accessibilityLabel(detailAccessibilityLabel)"
    if lama not in isi:
        gagal.append("[4] prasyarat: `.accessibilityLabel(detailAccessibilityLabel)` "
                     "tidak ditemukan di PointingView")
    else:
        # Labelnya tetap ada, tetapi tidak lagi menerima kalimat yang memuat
        # fase/warna/kelas — persis bentuk "dipanggil lalu dibuang".
        PV.write_text(isi.replace(lama, ".accessibilityLabel(\"objek\")", 1),
                      encoding="utf-8")
        kode, keluaran = jalankan()
        if kode == 0:
            gagal.append("[4] label tidak lagi memakai kalimat aksesor: gerbang tetap HIJAU")
            print("  [4] label tidak lagi memakai kalimat aksesor ...... HIJAU (salah)")
        else:
            print("  [4] label tidak lagi memakai kalimat aksesor ...... BUNYI (benar)")

    # Keadaan 5: aksesor kelima tanpa pemanggil. Inilah bukti daftarnya
    # dipanen dari paket, bukan dibekukan. Disisipkan **di dalam** ekstensi
    # `CelestialVisual` — bukan di akhir berkas, yang akan menaruhnya di
    # ekstensi katalog dan tidak terpanen sama sekali.
    pulihkan()
    isi = PAKET.read_text(encoding="utf-8")
    m = m_ekstensi.search(isi)
    if not m:
        gagal.append("[5] prasyarat: `public extension CelestialVisual` tidak "
                     "ditemukan di MoonPhaseSpeech.swift")
    else:
        brace = isi.index("{", m.start())
        # Sisipkan tepat setelah kurawal pembuka ekstensi.
        isi_baru = (isi[:brace + 1]
                    + "\n    /// MUTASI: aksesor kelima yang belum dipanggil app mana pun."
                    + "\n    func spokenJumlahLengan(isConfirmed: Bool) -> String? { nil }\n"
                    + isi[brace + 1:])
        PAKET.write_text(isi_baru, encoding="utf-8")
        kode, keluaran = jalankan()
        if kode == 0:
            gagal.append("[5] aksesor kelima tanpa pemanggil: gerbang tetap HIJAU — "
                         "daftarnya dibekukan, bukan dipanen")
            print("  [5] aksesor kelima tanpa pemanggil .............. HIJAU (salah)")
        else:
            print("  [5] aksesor kelima tanpa pemanggil .............. BUNYI (benar)")

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
    print("Aturan 92 terbukti non-vakum: 6 keadaan, 5 berbunyi, pohon bersih diam.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
