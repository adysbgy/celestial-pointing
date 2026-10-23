#!/usr/bin/env python3
"""Bukti bahwa Aturan 49 berbunyi pada cacatnya, dan tidak pada kode benar.

Kenapa berkas ini ada
=====================

Aturan 49 (`swift-ui-lint.sh`) menuntut: setiap berkas `Apps/**` yang
mendeklarasikan sebuah `View` **dan** menyentuh latar aplikasi harus memakai
`appBackdrop()`, bukan `SurfacePalette.appBackground` mentah.

Aturan itu lahir dari cacat nyata yang **terukur hijau** pada 48 aturan
sebelumnya: `OnboardingView` — layar pertama yang dilihat pengguna — adalah
satu-satunya layar penuh tanpa langit berbintang. Lima layar lain benar, jadi
setiap sapuan "apakah layar memakai latar aplikasi" hijau; yang tidak
terlihat adalah **ketiadaan** di berkas keenam.

Harness ini menjawab satu pertanyaan: apakah Aturan 49 memerah tepat pada
kelas cacat itu, dan diam pada bentuk yang sah? Aturan yang tidak pernah
terbukti memerah pada cacatnya adalah aturan yang tidak mengukur apa pun.

Kenapa salinan utuh, bukan mutasi di tempat
===========================================

`swift-ui-lint.sh` membaca `Apps/`, `Packages/`, `README.md`, dan `Tools/`
sekaligus; memutasi pohon tempat harness ini hidup akan membuat gerbang lain
mengukur pohon yang setengah-mutasi. Setiap keadaan mendapat salinan penuh di
direktori sementara, dijalankan di proses baru, lalu dihapus.

Kenapa ada keadaan yang **wajib hijau**
=======================================

Tanpa mereka, aturan yang melaporkan setiap baris `Apps/` akan lulus semua
keadaan cacat. Keadaan sah di bawah ini yang membedakan "menangkap cacat"
dari "berbunyi pada apa pun".

Yang TIDAK dibuktikan harness ini
=================================

Ini sapu teks **per berkas**, bukan pelacakan aliran. Layar yang membangun
latarnya di berkas lain (mis. lewat container bersama) tidak terlihat oleh
aturan ini. Yang juga tidak dibuktikan: bahwa langit itu **terlihat** di
perangkat — tidak ada Xcode di mesin ini, dan `Apps/` tidak pernah dibangun
oleh `swift-test.sh`.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

import mutasi_sumber  # noqa: E402

ONBOARDING = "Apps/Shared/OnboardingView.swift"
KALIBRASI = "Apps/PointAndKnowWatch/Sources/CalibrationView.swift"
DIAGNOSTIK = "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"

#: Jangkar produksi — bentuk yang **harus** ada, supaya keadaan cacat di bawah
#: benar-benar mengubah sesuatu. Kalau jangkar ini hilang, harness menolak
#: jalan alih-alih melaporkan "sesuai harapan" atas nol mutasi.
ONBOARDING_BENAR = "            AppBackdropView()"

#: Bentuk lama yang persis menghasilkan cacatnya: gradien polos, tanpa langit.
ONBOARDING_CACAT = """            SurfacePalette.appBackground
                .ignoresSafeArea()"""

SKY_KONTEKS = "Apps/PointAndKnowWatch/Sources/PointingView.swift"

#: Komit terakhir sebelum arah ketiga (latar hilang, bukan latar salah) ada.
#: Dipakai arah kedua: gerbang lama **wajib hijau** pada cacat yang sama,
#: kalau tidak lubangnya cuma dikarang oleh aturan yang selalu berbunyi.
PRA_ARAH_KETIGA = "b51482604f792f51d35372502090384f980775e0"

# ── Arah ketiga: latar yang **tidak ada sama sekali** ──────────────────────
#
# Dua arah pertama menanyakan "apakah `appBackground` dipakai mentah".
# Keduanya menjawab **tidak** untuk layar yang tidak menyentuh latar — dan
# bentuk itulah yang terukur exit 0 pada 51 aturan:
#
#   `SkyContextView` (jam) membungkus isinya dalam `List { … }` tanpa
#   `.scrollContentBackground(.hidden)`; `CalibrationView` membungkus isinya
#   dalam `ScrollView { … }` tanpa `.appBackdrop()`.
#
# Kenapa itu cacat, bukan selera: mode malam dibangun dari palet tanpa cahaya
# biru/hijau (rod ~498-530 nm). `List` di watchOS menggambar latar bawaan
# sistem, jadi satu layar penuh permukaan terang muncul justru di tengah mode
# yang dibuat untuk mencegahnya. Di mode siang, layar yang sama kehilangan
# langit berbintang, persis cacat yang Aturan 49 tutup untuk onboarding.
SKY_BENAR = ("        .scrollContentBackground(.hidden)\n"
             "        .appBackdrop()\n"
             "        .navigationTitle(TextLocalization.text"
             "(.pointingSkyContextLabel))\n")

#: Hijau palsu: latar terpasang, tetapi latar bawaan `List` menutupinya.
SKY_BACKDROP_TERTUTUP = ("        .appBackdrop()\n"
                         "        .navigationTitle(TextLocalization.text"
                         "(.pointingSkyContextLabel))\n")

#: Jangkar kalibrasi. Dua bentuk, dan keduanya **dibaca dari berkasnya**,
#: bukan dikarang:
#:
#:   `CAL_ADA`   pohon sekarang: baris `.appBackdrop()`.
#:   `CAL_TIDAK` bentuk cacatnya: baris itu dihapus.
#:
#: Jangkar pertama yang dicoba (`"            .navigationTitle(...)"`) tidak
#: pernah cocok: baris judul di berkas itu didahului `}\n` tanpa spasi, jadi
#: teksnya diawali 12 spasi. Harness melaporkan JANGKAR HILANG — perilaku
#: yang benar (lebih baik berhenti daripada mengukur nol mutasi), dan yang
#: membuat kesalahannya terlihat di putaran pertama.
#:
#: Jangkar semula menjulur melewati `.appBackdrop()` ke komentar penjelas di
#: bawahnya. Itu cacat: keadaan **cacat** (tanpa latar) tidak pernah cocok,
#: karena menghapus `.appBackdrop()` membuat baris berikutnya menjadi
#: komentar — harness melaporkan JANGKAR HILANG, bukan berdiri di atas cacat
#: yang benar. Yang diukur harness harus **satu baris penuh**, bukan sampai
#: komentar penjelas. Terukur: dua keadaan melaporkan JANGKAR HILANG sebelum
#: dibetulkan; sesudahnya keduanya berjalan.
CAL_JUDUL = "            .appBackdrop()\n"
CAL_ADA = CAL_JUDUL
CAL_TIDAK = ""  # mengganti `.appBackdrop()` yang hanya barisnya sendiri

STATES = [
    # ── Keadaan cacat: aturan WAJIB berbunyi ────────────────────────────────
    # Cacat aslinya, dikembalikan persis ke bentuk yang pernah dikirim.
    ("onboarding: kembali ke gradien polos (cacat asli)",
     {ONBOARDING: (ONBOARDING_BENAR, ONBOARDING_CACAT)}, True),
    # Bentuk yang lebih halus: `appBackdrop()` tetap dipanggil, tapi sebuah
    # cabang menggambar gradien mentah di sebelahnya.
    #
    # Ini **cacat**, bukan kontrol. Aturan versi pertama (yang menuntut
    # "menyebut appBackdrop") meloloskannya, dan harness ini yang menemukan
    # itu: keadaan ini dulu diharapkan hijau, lalu berubah merah setelah
    # aturannya ditegaskan. Cabang itu tetap tampil tanpa langit, terlepas
    # dari apa yang dipanggil cabang lain.
    ("cabang lain menggambar gradien mentah, appBackdrop tetap ada",
     {ONBOARDING: (ONBOARDING_BENAR,
                   """            SurfacePalette.appBackground
            AppBackdropView()""")}, True),
    # Layar ketiga yang lupa: bukan onboarding, supaya aturan tidak bisa lulus
    # dengan menghafal satu nama berkas.
    ("kalibrasi: latar mentah disuntikkan",
     {KALIBRASI: ("    private var referenceList: some View {",
                  """    private var latarPolos: some View {
        SurfacePalette.appBackground
    }

    private var referenceList: some View {""")}, True),
    # iPhone juga, supaya aturan tidak hanya melihat target jam.
    ("iPhone: latar mentah disuntikkan",
     {DIAGNOSTIK: ("        .appBackdrop()",
                   """        .background(SurfacePalette.appBackground)""")}, True),

    # ── Keadaan sah: aturan WAJIB diam ──────────────────────────────────────
    # Kalau keadaan-keadaan ini merah, aturannya menuduh kode benar.
    #
    # `appBackdrop()` dengan argumen eksplisit — bentuk sah yang berbeda teks.
    ("kontrol: appBackdrop dengan argumen eksplisit",
     {DIAGNOSTIK: ("        .appBackdrop()",
                   "        .appBackdrop(starfield: true)")}, False),
    # Berkas yang **tidak** menyentuh latar sama sekali tidak boleh diperiksa:
    # view kecil (kartu, lencana) memang tidak punya latar sendiri.
    #
    # Teksnya lewat `TextLocalization` — bukan `Text("x")`. Versi pertama
    # keadaan ini memakai literal, dan yang memerah adalah Aturan 4 (teks tanpa
    # entri katalog), bukan Aturan 49. Keadaan kontrol yang merah karena
    # **aturan lain** tidak membuktikan apa pun tentang aturan yang diuji; ia
    # hanya terbaca seperti itu kalau alasannya tidak dibaca.
    #
    # `.foregroundStyle(...)`, dan itu bukan hiasan: Aturan 87 (ditambahkan
    # sesudah keadaan ini ditulis) menuntut setiap `Text` berwarna, jadi
    # kontrol ini memerah pada aturan yang **sama sekali tidak berhubungan
    # dengan latar**. Gejalanya identik dengan kegagalan Aturan 4 di atas, dan
    # itulah sebabnya keadaan ini diperbaiki dengan memberi warna, bukan dengan
    # melonggarkan Aturan 49: yang diuji adalah "view yang tidak menyentuh
    # latar tidak boleh dituntut berlatar", dan view kecil yang **berwarna**
    # tetap memenuhi maksud itu. Melonggarkan Aturan 49 akan membuang
    # pengukurannya sendiri.
    ("kontrol: view tanpa latar sama sekali",
     {KALIBRASI: ("    private var referenceList: some View {",
                  """    private var lencana: some View {
        Text(TextLocalization.text(.pointingNightModeOn))
            .foregroundStyle(SurfacePalette.primaryText)
    }

    private var referenceList: some View {""")}, False),

    # ── Arah ketiga: latar yang tidak ada (bukan latar yang salah) ──────────
    # Cacat asli #1: `List` di watchOS tanpa latar aplikasi dan tanpa
    # menyembunyikan latar bawaannya. Terukur exit 0 sebelum arah ini ada.
    ("skyContext: List tanpa latar aplikasi (cacat asli)",
     {SKY_KONTEKS: (SKY_BENAR, "")}, True),
    # Cacat asli #2: `ScrollView` tanpa latar apa pun.
    ("kalibrasi: ScrollView tanpa appBackdrop (cacat asli)",
     {KALIBRASI: (CAL_ADA, CAL_TIDAK)}, True),
    # Hijau palsu: `.appBackdrop()` **terpasang** tetapi latar `List` masih
    # menutupinya. Inilah alasan gerbangnya `.scrollContentBackground(.hidden)`
    # dan bukan keberadaan `appBackdrop`. Bentuk ini dulu diloloskan.
    ("skyContext: appBackdrop tertutup latar bawaan List",
     {SKY_KONTEKS: (SKY_BENAR, SKY_BACKDROP_TERTUTUP)}, True),

    # Arah kedua untuk arah ketiga: gerbang **pra-perbaikan** wajib hijau pada
    # cacat yang sama. Tanpa ini, ketiga keadaan di atas hanya membuktikan
    # bahwa sebuah aturan berbunyi, bukan bahwa lubangnya nyata.
    ("pra-perbaikan: List tanpa latar (wajib HIJAU = lubang nyata)",
     {SKY_KONTEKS: (SKY_BENAR, "")}, False, PRA_ARAH_KETIGA),
    ("pra-perbaikan: ScrollView tanpa latar (wajib HIJAU)",
     {KALIBRASI: (CAL_ADA, CAL_TIDAK)}, False, PRA_ARAH_KETIGA),
]


def run_lint(tree):
    return subprocess.run(["./swift-ui-lint.sh"], cwd=tree,
                          capture_output=True, text=True)


def apply_edits(tree, edits):
    """Terapkan `{path: (find, replace)}`; kembalikan nama berkas yang gagal.

    Setiap jangkar wajib muncul **tepat sekali** — kalau tidak, mutasinya
    ambigu dan hasilnya tidak mengukur apa pun.
    """
    gagal = []
    for path, (find, replace) in edits.items():
        target = os.path.join(tree, path)
        sumber = open(target, encoding="utf-8").read()
        if sumber.count(find) != 1:
            gagal.append("%s (%d kecocokan)" % (path, sumber.count(find)))
            continue
        if find != replace:
            mutasi_sumber.write_source(target, sumber.replace(find, replace, 1))
    return gagal


def buang_aturan_10(tree):
    """Hapus **langkah Aturan 10** dari lint yang dipasang di `tree`.

    Kenapa ini perlu untuk arah kedua. Aturan 10 menuntut angka aturan di
    README sama dengan jumlah aturan di `swift-ui-lint.sh`, jadi gerbang lama
    bisa merah di Aturan 10 karena alasan yang tidak ada hubungannya dengan
    latar layar — dan arah kedua berhenti membuktikan lubangnya. Yang dihapus
    hanya pemeriksa hitungannya; aturan lain tetap berjalan utuh, jadi
    keadaan pra-perbaikan tetap membuktikan "seluruh gerbang lama lulus pada
    cacat ini".
    """
    target = os.path.join(tree, "swift-ui-lint.sh")
    teks = open(target, encoding="utf-8").read()
    awal = teks.find('echo "== Aturan 10:')
    akhir = teks.find('echo "== Aturan 11:')
    if awal < 0 or akhir < 0 or akhir <= awal:
        raise SystemExit("GAGAL: tidak bisa memisahkan Aturan 10 dari lint "
                         "pra-perbaikan; arah kedua tidak bisa dijalankan.")
    mutasi_sumber.write_source(target, teks[:awal] + teks[akhir:])


#: Nama keadaan arah ketiga yang **harus** memerahkan Aturan 49. Tanpa ini,
#: "merah" bisa berarti aturan lain yang kebetulan gagal, dan harness akan
#: melaporkan bukti yang tidak ia miliki.
WAJIB_MENYALA = {
    "skyContext: List tanpa latar aplikasi (cacat asli)": "Aturan 49",
    "kalibrasi: ScrollView tanpa appBackdrop (cacat asli)": "Aturan 49",
    "skyContext: appBackdrop tertutup latar bawaan List": "Aturan 49",
}


def main():
    if not os.path.isfile(os.path.join(ROOT, "swift-ui-lint.sh")):
        print("Tidak menemukan swift-ui-lint.sh di %s" % ROOT)
        return 2

    # Versi lint **pra-perbaikan**, dibaca lewat git — bukan dikarang. Kalau
    # ini gagal terbaca, gerbang lama akan tampak hijau karena kosong, dan
    # arah kedua berhenti membuktikan apa pun.
    lama = mutasi_sumber.git_show(PRA_ARAH_KETIGA, "swift-ui-lint.sh",
                                  min_bytes=10000)

    gagal = []
    for nama, edits, harus_merah, *sisa in STATES:
        work = tempfile.mkdtemp(prefix="bukti-latar-")
        tree = os.path.join(work, "repo")
        try:
            shutil.copytree(
                ROOT, tree, symlinks=True,
                ignore=shutil.ignore_patterns(".build", ".git", "__pycache__",
                                              "out"))
            if sisa:
                mutasi_sumber.write_source(
                    os.path.join(tree, "swift-ui-lint.sh"), lama)
                buang_aturan_10(tree)

            # Arah kedua: acuan diukur **sebelum** mutasi, atas pohon yang
            # sama. Dulu arah kedua menuntut lint pra-perbaikan HIJAU secara
            # mutlak; itu membusuk karena lint lama memeriksa seluruh `Apps/`,
            # dan `Apps/` berubah sesudah revisi itu di-commit — setiap aturan
            # baru yang lebih ketat memerahkan arah kedua tanpa ada cacat yang
            # diuji. Yang benar: bandingkan **himpunan aturan yang memerah**
            # sebelum dan sesudah mutasi. Kalau sama, gerbang lama memang buta
            # pada cacat ini, dan itu berlaku berapa pun aturan usang yang
            # sudah merah.
            sebelum = (mutasi_sumber.aturan_yang_merah(run_lint(tree).stdout)
                       if sisa else set())

            rusak = apply_edits(tree, edits)
            if rusak:
                print("%-56s JANGKAR HILANG: %s" % (nama, "; ".join(rusak)))
                gagal.append(nama)
                continue

            hasil = run_lint(tree)
            merah = hasil.returncode != 0
            if sisa:
                sesudah = mutasi_sumber.aturan_yang_merah(hasil.stdout)
                sesuai = sesudah == sebelum
                print("%-56s %s (merah %s -> %s)" % (
                    nama, "BUTA, sesuai harapan" if sesuai else "TIDAK BUTA",
                    sorted(sebelum), sorted(sesudah)))
            else:
                sesuai = merah == harus_merah
                print("%-56s %s (exit %d)" % (
                    nama,
                    "MERAH, sesuai harapan" if merah else "HIJAU, sesuai harapan",
                    hasil.returncode))
            if not sesuai:
                gagal.append(nama)
                if sisa:
                    print("    gerbang lama berubah pikiran: %s -> %s"
                          % (sorted(sebelum), sorted(sesudah)))
                else:
                    print("    diharapkan %s, dapat %s"
                          % ("MERAH" if harus_merah else "HIJAU",
                             "MERAH" if merah else "HIJAU"))
                if merah and not harus_merah:
                    # Tampilkan alasan merahnya: tanpa ini, "menuduh kode
                    # benar" tidak bisa dibedakan dari gerbang lain yang
                    # kebetulan merah.
                    for baris in hasil.stdout.split("\n"):
                        if "Aturan 49" in baris or "appBackdrop" in baris:
                            print("    %s" % baris.strip())
            # Aturan yang menyala harus **yang dimaksud**.
            wajib = WAJIB_MENYALA.get(nama)
            if merah and harus_merah and wajib and wajib not in hasil.stdout:
                gagal.append(nama)
                print("    merah, tetapi %s tidak menyala di keluaran" % wajib)
        finally:
            shutil.rmtree(work, ignore_errors=True)

    print()
    if gagal:
        print("%d keadaan TIDAK sesuai harapan:" % len(gagal))
        for nama in gagal:
            print("  - %s" % nama)
        return 1
    print("%d keadaan, semuanya sesuai harapan." % len(STATES))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
