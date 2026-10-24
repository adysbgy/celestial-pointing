#!/usr/bin/env python3
"""Buktikan Aturan 76 (nama objek wajib punya kebijakan luapan) **berbunyi**.

Kenapa harness ini ada.

Aturan 76 lahir dari pengukuran, bukan dari bacaan. Sebelum ia ada,
`grep -ro 'lineLimit\\|minimumScaleFactor' Apps/` menemukan **4** kemunculan
di seluruh pohon: dua di `ComplicationWidget` (keluarga circular dan corner),
dua di `ReducedLuminanceView`. Nama objek — teks yang paling sering berubah dan
paling panjang di app ini — tidak punya satu pun di tiga tempat yang
menampilkannya:

    Apps/PointAndKnowWatch/Sources/PointingView.swift:526
    Apps/PointAndKnowWatch/Sources/CalibrationView.swift:278
    Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift:920

Panjangnya bukan pilihan view. Ia ditentukan katalog 30 entri dua bahasa
(`ObjectDisplayName.catalogueKeys`), dan Bahasa Indonesia yang lebih panjang:
"Galaksi Kincir Angin" (20 karakter), "Gugus Kupu-kupu" (17). Diukur dengan
metrik DejaVu Sans Bold 20 pt — ukuran `.title3` — keduanya butuh **227 pt**
dan **200 pt**.

Ruang yang tersedia di kartu status jam 40 mm: layar 162 pt, dikurangi
`ScrollView` horizontal padding 2 pt di kedua sisi = 158 pt, dikurangi
`WatchMetrics.cardPadding` 10 pt di kedua sisi = 138 pt, dikurangi visual 38 pt
dan `HStack` spacing 8 pt = 92 pt, dikurangi badge keyakinan "Ragu" ~45 pt =
**~48 pt**. Nama terpanjang lima kali kolomnya. Tanpa batas, `Text` membungkus
jadi empat-lima baris; karena kartu itu berada di dalam `ScrollView`, status
dan panduan terdorong keluar layar.

Kenapa kelas cacat ini tidak dijaga gerbang lain.

`check-visuals.py` merender **objek**, bukan layar: tidak ada satu pun
`VIEW:` untuk layar penuh, dan teks tidak pernah masuk kanvas. `swift-ui-lint.sh`
sebelum aturan ini tidak punya satu pun aturan yang membaca `.lineLimit`.
`swift-typecheck.sh` hanya `-parse` berkas SwiftUI, jadi tidak ada galat
kompilasi. Ini persis kelas yang tidak bisa dijangkau gate mana pun di Linux.

Keadaan yang diuji, dan apa yang masing-masing buktikan.

  [baseline]  pohon apa adanya -> hijau. Tanpa ini, harness yang selalu merah
              akan lulus seluruh keadaan di bawah.

  1  `.lineLimit` + `.minimumScaleFactor` dihapus dari kartu status jam
     -> MERAH. Ini cacat aslinya, bentuk yang persis ada di `main` sebelum
     aturan ini ditulis.

  2  kebijakan dihapus dari panel iPhone -> MERAH. Keadaan ini membuktikan
     aturan tidak hanya membaca satu berkas; ia menyapu `Apps/**`.

  3  kebijakan dihapus dari daftar acuan kalibrasi -> MERAH. Situs ketiga,
     dan yang paling mudah terlewat karena barisnya pendek.

  4  KONTROL: complication `circular` yang sudah punya `.minimumScaleFactor`
     sejak awal -> tetap hijau. Aturan yang menuduh baris sah akan dimatikan
     orang, dan kontrol ini yang menahannya.

  5  KONTROL: `Text` biasa tanpa nama katalog (`Text("Ragu")`) -> hijau.
     Aturan ini menargetkan teks yang panjangnya ditentukan katalog, bukan
     setiap `Text` di app.

  6  fail-closed: `Apps/` kosong -> MERAH dengan PERINGATAN, bukan "Bersih".
     Indeks kosong yang dilaporkan bersih adalah bentuk gerbang hijau paling
     berbahaya, dan Aturan 76 menyatakannya sendiri.

Harness menjalankan **program Python milik Aturan 76 apa adanya**, diambil
dari `swift-ui-lint.sh`, di dalam sandbox yang hanya berisi `Apps/` hasil
mutasi. Lint utuh tidak dipanggil: ia punya pra-syarat lain (`project.yml`,
README, Packages/) dan kegagalan pra-syarat akan terbaca palsu sebagai
"gerbang berbunyi". `returncode != 0` dari program itu sendiri di sini berarti
**galat harness**, bukan keberhasilan.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

WATCH = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
IOS = "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"
CALIB = "Apps/PointAndKnowWatch/Sources/CalibrationView.swift"
COMP = "Apps/PointAndKnowWatch/Complications/ComplicationWidget.swift"

MULAI = 'nama_luapan=$(python3 - <<\'PY\' 2>&1\n'


def program_aturan76():
    """Ambil program Python milik Aturan 76 dari lint, apa adanya."""
    teks = open(LINT, encoding="utf-8").read()
    i = teks.index(MULAI) + len(MULAI)
    j = teks.index("\nPY\n)", i)
    return teks[i:j]


def jalankan(program, mutasi=None, kosongkan_apps=False):
    """Jalankan program aturan di sandbox; kembalikan (stdout, stderr).

    `mutasi` boleh satu `(rel, anchor, ganti)` atau daftar dari bentuk itu.
    Daftar diperlukan oleh keadaan 1b, yang mengubah **dua** tempat di berkas
    yang sama: mencabut kebijakan dari nama *dan* menempelkannya ke badge.
    Dengan satu mutasi saja, nama masih punya kebijakannya dan aturan diam
    dengan benar — harness akan melaporkan "tidak menangkap bentuk" padahal
    yang salah adalah mutasinya.
    """
    d = tempfile.mkdtemp(prefix="rule76-")
    try:
        tujuan_apps = os.path.join(d, "Apps")
        if kosongkan_apps:
            os.makedirs(tujuan_apps)
        else:
            shutil.copytree(os.path.join(ROOT, "Apps"), tujuan_apps,
                            ignore=shutil.ignore_patterns("*.xcodeproj",
                                                          "*.xcworkspace"))
        if mutasi:
            daftar = mutasi if isinstance(mutasi, list) else [mutasi]
            for rel, anchor, ganti in daftar:
                path = os.path.join(d, rel)
                teks = open(path, encoding="utf-8").read()
                assert anchor in teks, "anchor tidak ditemukan di %s: %r" % (
                    rel, anchor[:60])
                teks = teks.replace(anchor, ganti, 1)
                open(path, "w", encoding="utf-8").write(teks)
        p = subprocess.run([sys.executable, "-c", program], cwd=d,
                           capture_output=True, text=True)
        if p.returncode not in (0, 1):
            print("Aturan 76 gagal dijalankan (returncode %d), bukan berbunyi:"
                  % p.returncode)
            print((p.stderr or p.stdout)[-2000:])
            sys.exit(1)
        # **Keputusan dari exit code, bukan dari keluaran kosong.** Program ini
        # mencetak "Bersih: ..." saat lulus, jadi `bool(stdout)` akan membaca
        # SETIAP keadaan sebagai "berbunyi" -- termasuk baseline yang harus
        # diam. Itu tepat bug yang harness ini ada untuk menangkap, dan ia
        # sempat ada di versi pertama harness ini.
        return p.returncode, p.stdout, p.stderr
    finally:
        shutil.rmtree(d)


# Jangkar = blok kebijakan yang baru ditambahkan. Kalau baris produksi ini
# berubah, harness harus ikut — dan `assert` di `jalankan` membuat perubahan
# itu merah karena sebab yang jelas, bukan diam-diam melewati keadaan.
#
# Jangkar kartu jam **berubah di siklus 21 Okt**: badge keyakinan dipindah ke
# baris meta, jadi nama kini duduk di kolom teks penuh (92 pt, bukan 48 pt)
# dan rantai modifier-nya turun satu indentasi. Jangkar ikut pindah ke bentuk
# yang baru — yang **tidak** boleh dilakukan adalah melonggarkan pencocokan
# sampai kedua bentuk cocok, karena itu menghapus bukti bahwa kebijakannya
# masih ada di baris yang benar.
WATCH_BLOK = """                .lineLimit(ObjectCardLayout.nameLineLimit(at: textSize))
                .minimumScaleFactor(ObjectCardLayout.nameScaleFloor)"""
IOS_BLOK = """                            .lineLimit(ObjectCardLayout.detailNameLineLimit)
                            .minimumScaleFactor(ObjectCardLayout.detailNameScaleFloor)"""
CALIB_BLOK = """                                    .lineLimit(ObjectCardLayout.calibrationLineLimit(at: textSize))
                                    .minimumScaleFactor(ObjectCardLayout.calibrationScaleFloor)"""

#: Keadaan 1b: kebijakan **dipindah** dari nama ke badge keyakinan di
#: bawahnya. `BADGE_SESUDAH` adalah teks badge di pohon ini (dengan
#: `.fixedSize()` sebagai jangkar terakhirnya); `BADGE_TANPA_POLICY` adalah
#: badge yang sama dengan kebijakan luapan ditempel padanya. Keduanya
#: ditulis lengkap supaya perubahannya terbaca di diff, bukan tersembunyi
#: dalam potongan string.
BADGE_SESUDAH = """                        .foregroundStyle(level.tone.color)
                        // Badge tidak boleh ikut menyusut: teksnya pendek
                        // dan tetap, dan badge yang mengecil sampai tak
                        // terbaca sama saja dengan badge yang hilang.
                        .fixedSize()"""

BADGE_TANPA_POLICY = """                        .foregroundStyle(level.tone.color)
                        .fixedSize()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)"""



def main():
    program = program_aturan76()
    gagal = []

    def periksa(label, seharusnya_berbunyi, mutasi=None, kosongkan_apps=False):
        code, out, _ = jalankan(program, mutasi, kosongkan_apps)
        berbunyi = code != 0
        tanda = "OK   " if berbunyi == seharusnya_berbunyi else "GAGAL"
        if berbunyi == seharusnya_berbunyi:
            print("%s %-52s %s" % (tanda, label,
                                   "berbunyi" if berbunyi else "diam"))
        else:
            print("%s %-52s seharusnya %s, ternyata %s"
                  % (tanda, label,
                     "berbunyi" if seharusnya_berbunyi else "diam",
                     "berbunyi" if berbunyi else "diam"))
            if not berbunyi and seharusnya_berbunyi:
                print("     -> aturan ini tidak menangkap bentuk yang ada di "
                      "main sebelum ia ditulis.")
            if berbunyi:
                print("     -> " + out.strip().splitlines()[0][:200])
            gagal.append(label)
        return out

    # 1. Cacat aslinya: kebijakan dihapus dari kartu status jam.
    periksa("1 kartu status jam tanpa kebijakan luapan", True,
            (WATCH, WATCH_BLOK, ""))

    # 1b. **Vakum yang sempat lolos.** Kebijakan dihapus dari nama, lalu
    #     ditempel pada badge keyakinan di bawahnya. Bentuk ini sah secara
    #     Swift dan salah secara makna, dan aturan 76 versi pertama
    #     melaporkannya "Bersih" — karena `modifier_block` menghitung
    #     indentasi dasar dari potongan `code[start:]` yang selalu berindentasi
    #     0, sehingga blok nama menelan seluruh sisa fungsi dan membaca
    #     `.lineLimit` milik badge.
    #
    #     Keadaan ini **bukan** variasi dari keadaan 1: keadaan 1 menguji
    #     apakah aturan melihat situsnya, keadaan 1b menguji apakah ia membaca
    #     modifier **milik situs itu**. Aturan yang lulus 1 tapi gagal 1b tetap
    #     hijau pada kode yang tidak punya kebijakan luapan di nama sama sekali.
    periksa("1b kebijakan dipindah ke badge di bawahnya", True,
            [(WATCH, WATCH_BLOK, ""),
             (WATCH, BADGE_SESUDAH, BADGE_TANPA_POLICY)])

    # 2. Panel detail iPhone.
    periksa("2 panel detail iPhone tanpa kebijakan", True,
            (IOS, IOS_BLOK, ""))

    # 3. Daftar acuan kalibrasi.
    periksa("3 daftar acuan kalibrasi tanpa kebijakan", True,
            (CALIB, CALIB_BLOK, ""))

    # 4. KONTROL: complication `circular` sudah berpolicy sejak awal -> diam.
    #    Jangkar ini sengaja tidak diubah; yang dibuktikan adalah aturan tidak
    #    menuduh baris yang sah.
    #
    #    **Catatan 21 Okt.** Keadaan ini dulu lulus karena alasan yang salah:
    #    keluarga `accessoryRectangular` (baris 192) ternyata TIDAK berpolicy,
    #    dan yang membuatnya terbaca "diam" adalah `modifier_block` yang
    #    menghitung indentasi dasar dari potongan (selalu 0) sehingga bloknya
    #    menelan `.minimumScaleFactor` milik keluarga `circular` di bawahnya.
    #    Cacat itu sudah ditutup di sumbernya dan di baris 192; kontrol ini
    #    kini menguji yang benar-benar dimaksud.
    out = periksa("4 kontrol: complication berpolicy tetap diam", False)
    if "ComplicationWidget" in out:
        print("GAGAL kontrol: aturan menuduh complication yang sudah "
              "berpolicy.")
        gagal.append("kontrol complication")

    # 5. KONTROL: `Text` biasa tanpa nama katalog -> diam.
    periksa("5 kontrol: Text(\"Ragu\") bukan nama katalog", False,
            (WATCH, '                Text(state.shortLabel)',
             '                Text("Ragu")'))

    # 6. Fail-closed: `Apps/` kosong harus MERAH, bukan "Bersih".
    out = periksa("6 Apps/ kosong -> PERINGATAN, bukan Bersih", True,
                  kosongkan_apps=True)
    if "PERINGATAN" not in out:
        print("GAGAL fail-closed: nol nama terbaca tidak dilaporkan sebagai "
              "PERINGATAN.")
        gagal.append("fail-closed")

    # 7. Baseline: pohon apa adanya harus hijau.
    periksa("7 baseline pohon apa adanya", False)

    if gagal:
        print("\nHARNESS ATURAN 76 GAGAL: " + ", ".join(gagal))
        sys.exit(1)
    print("\nAturan 76 berbunyi pada ketiga situs yang tidak dijaga, dan diam "
          "pada kode sah.")


if __name__ == "__main__":
    main()
