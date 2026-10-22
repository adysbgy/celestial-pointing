#!/usr/bin/env python3
"""Aturan 94: setiap sumber daya bersama yang diakuisisi wajib punya pelepasan
yang benar-benar **dipanggil** dari jalur teardown.

Kenapa aturan ini ada.

Aturan 93 mengukur pasangan start/stop **sensor** di badan `start()` app jam.
Itu menutup satu keluarga cacat, tetapi hanya keluarga yang diakuisisi di
`start()`. Repo ini punya sumber daya yang diakuisisi dengan cara lain:

    try? AVAudioSession.sharedInstance().setActive(true)

Baris itu ada di `Apps/Shared/AudioCue.swift`, di dalam `ensureResources()` —
dipanggil **malas**, saat bunyi pertama diputar. Diukur dengan menyapu seluruh
`Apps/` untuk pasangan akuisisi/pelepasan:

    pembaruan lokasi   startUpdatingLocation / stopUpdatingLocation      berpasangan
    device motion      startDeviceMotionUpdates / stopDeviceMotionUpdates berpasangan
    sesi audio         setActive(true) / setActive(false)                TIDAK ADA

Nol `setActive(false)` di seluruh pohon. Konsekuensinya bukan abstrak: bunyi
kunci berdurasi 0,13 detik menahan sesi audio aktif sampai watchOS mematikan
prosesnya. Pada jam yang dipakai sepanjang malam di lapangan, itu baterai yang
dibayar untuk suara yang sudah lama habis. Di iPhone, `.playback` yang tetap
aktif menahan audio app lain lebih lama dari yang seharusnya.

**Kenapa tidak ada gerbang yang berbunyi.** Compiler diam: tidak ada yang salah
secara sintaks — `setActive(true)` adalah kode yang benar. Aturan 93 diam: ia
memanen pasangan dari badan `start()`, dan akuisisi ini tidak ada di sana.
Ke-93 aturan UI lainnya diam: teks di layar tidak berubah sama sekali.

**Kegagalan versi pertama aturan ini, dan kenapa bentuknya penting.**

Versi pertama memeriksa "apakah `stop()` dipanggil dari berkas lain". Itu
**buta pada mutasi yang paling penting**: menghapus `audioCue.stop()` dari
kedua app tetap hijau, karena `motion.stop()`, `engine.stop()`, dan
`location.stop()` ada di berkas yang sama dan cocok dengan pola `\\bstop\\(`.
Tiga panggilan ke objek lain dipakai sebagai bukti bahwa panggilan ke objek
ini ada. Gerbangnya hijau, dan yang dibuktikannya nol.

Karena itu yang diukur sekarang adalah **penerima** panggilan, bukan namanya:

  1. Tipe mana yang memiliki akuisisi? (`setActive(true)` di dalam
     `AudioCueEngine` → `AudioCueEngine`.)
  2. Tipe itu wajib punya metode pelepasan yang memuat pola pelepasan.
  3. Ada properti bertipe itu? (`private let audioCue = AudioCueEngine()` →
     `audioCue`.)
  4. `audioCue.stop()` wajib dipanggil di **setiap berkas yang membuat**
     instance itu, atau pelepasannya dipanggil dari `deinit` milik tipe itu.

Langkah [4] tidak bisa dipenuhi `motion.stop()`: penerimanya `motion`, bukan
`audioCue`. Itu satu-satunya perbedaan antara gerbang yang mengukur dan gerbang
yang kebetulan hijau.

Langkah [4] juga **per-berkas-pemilik**, bukan "di mana pun di pohon". Versi
kedua menerima satu panggilan di berkas mana saja, dan itu tetap buta: kedua
app mendeklarasikan `private let audioCue = AudioCueEngine()` dengan nama yang
sama, jadi menghapus pelepasan dari app jam tetap hijau karena app iPhone
memanggilnya. Satu panggilan dipakai sebagai bukti untuk dua pemilik.

Langkah [3] membedakan **pemilik** dari **peminjam**. `@ObservedObject var
motion: MotionLogger` adalah dependensi yang disuntikkan: `PointingView` tidak
membuatnya, dan kalau ia memanggil `motion.stop()` sensornya mati untuk app jam
seluruhnya. Hanya berkas yang **membuat** instance (`= AudioCueEngine()`) yang
dituntut melepasnya. Tanpa pemisahan ini aturan berbunyi pada pohon yang benar
— tiga temuan palsu pada `PointingView` dan `CalibrationView`.

Batasnya jujur. Ini sapuan **teks**, bukan analisis aliran kendali. Ia tidak
membuktikan `stop()` benar-benar dieksekusi watchOS, tidak memeriksa urutan
akuisisi/pelepasan, dan tidak mengukur konsumsi baterai. Ia juga tidak
mengenali properti yang tipenya di-infer dari nilai balik fungsi. Ia
membuktikan hal yang tadinya tidak diukur siapa pun: **tidak ada sumber daya
bersama di `Apps/` yang diakuisisi tanpa pelepasan yang dipanggil lewat
penerimanya sendiri.**

Jalankan dari akar repo. Exit 0 = bersih, 1 = ada yang putus.
"""
import pathlib
import re
import sys

AKAR = pathlib.Path(".")
APPS = AKAR / "Apps"

#: (nama manusia, pola akuisisi, pola pelepasan, wajib?)
#:
#: `wajib=True` berarti pola itu **harus** ditemukan; kalau tidak, aturan ini
#: berhenti mengukur dan harus berbunyi.
PASANGAN = [
    ("sesi audio bersama",
     r"\.setActive\s*\(\s*true",
     r"\.setActive\s*\(\s*false",
     True),
    ("pembaruan lokasi",
     r"\.startUpdatingLocation\s*\(",
     r"\.stopUpdatingLocation\s*\(",
     False),
    ("device motion",
     r"startDeviceMotionUpdates\s*\(",
     r"stopDeviceMotionUpdates\s*\(",
     False),
]

#: Deklarasi tipe yang bisa memiliki sumber daya.
DEKLARASI_TIPE = re.compile(
    r"^[ \t]*(?:(?:public|internal|private|fileprivate|final|open)\s+)*"
    r"(?:class|struct|actor|enum)\s+(\w+)[^{]*\{", re.M)

#: Deklarasi metode pelepasan. Nama dipanen, bukan dibekukan.
DEKLARASI_PELEPAS = re.compile(
    r"^[ \t]*(?:(?:private|internal|public|fileprivate|static|override|mutating)\s+)*"
    r"func\s+(stop|invalidate|deactivate|teardown|release)\s*\(\s*\)[^{]*\{",
    re.M)

#: Properti yang tipenya eksplisit atau di-infer dari inisialisasi tanpa argumen:
#:     private let audioCue = AudioCueEngine()
#:     @StateObject private var engine = PointingEngine()
#: Awalan atribut (`@StateObject`, `@ObservedObject`, …) ikut ditelan: tanpa
#: itu, sumber daya yang paling penting justru yang terlewat — dan yang
#: terlewat membuat aturan ini berbunyi pada pohon yang benar.
ATRIBUT = r"(?:@\w+(?:\([^)]*\))?\s+)*"
PROPERTI = re.compile(
    r"^[ \t]*" + ATRIBUT +
    r"(?:(?:private|internal|public|fileprivate|static|weak|lazy)\s+)*"
    r"(?:let|var)\s+(\w+)\s*(?::\s*(\w+))?\s*=\s*(\w+)\s*\(\s*\)",
    re.M)

PROPERTI_BERTIPE = re.compile(
    r"^[ \t]*" + ATRIBUT +
    r"(?:(?:private|internal|public|fileprivate|static|weak|lazy)\s+)*"
    r"(?:let|var)\s+(\w+)\s*:\s*(\w+)", re.M)

DEINIT = re.compile(r"\bdeinit\s*\{")


def buang_komentar(isi):
    """Buang komentar supaya docstring yang menyebut `.setActive(true)` tidak dihitung."""
    isi = re.sub(r"/\*.*?\*/", "", isi, flags=re.S)
    return re.sub(r"//[^\n]*", "", isi)


def blok_kurawal(isi, brace_buka):
    """Teks dari `{` di `brace_buka` sampai pasangannya, inklusif."""
    depth, i = 0, brace_buka
    while i < len(isi):
        if isi[i] == "{":
            depth += 1
        elif isi[i] == "}":
            depth -= 1
            if depth == 0:
                return isi[brace_buka:i + 1]
        i += 1
    return isi[brace_buka:]


def tipe_dengan_badan(isi):
    """[(nama_tipe, badan, path)] untuk setiap tipe yang dideklarasikan."""
    hasil = []
    for m in DEKLARASI_TIPE.finditer(isi):
        buka = isi.index("{", m.start())
        hasil.append((m.group(1), blok_kurawal(isi, buka)))
    return hasil


def main():
    if not APPS.is_dir():
        print(f"GAGAL {APPS} tidak ada: Aturan 94 tidak mengukur apa pun.")
        return 1

    berkas = {}
    for path in sorted(APPS.rglob("*.swift")):
        berkas[path] = buang_komentar(path.read_text(encoding="utf-8"))
    if not berkas:
        print("GAGAL tidak ada berkas Swift di Apps/: Aturan 94 tidak mengukur apa pun.")
        return 1

    # Peta tipe -> (path, badan) untuk seluruh pohon.
    tipe_peta = {}
    for path, isi in berkas.items():
        for nama, badan in tipe_dengan_badan(isi):
            tipe_peta.setdefault(nama, (path, badan))

    # Peta properti -> [(tipe, path, dimiliki)], untuk seluruh pohon.
    #
    # **Kenapa daftar, bukan satu nilai.** Dua app mendeklarasikan properti
    # dengan nama yang **sama** (`private let audioCue = AudioCueEngine()` di
    # jam dan di iPhone). Peta `nama -> satu nilai` menyimpan yang terakhir
    # dipindai dan membuang yang lain, sehingga melepas di satu app tampak
    # seperti melepas di kedua. Itu persis cacat yang harness keadaan [3]
    # temukan: `audioCue.stop()` dihapus dari jam, gerbang tetap diam.
    #
    # **`dimiliki` memisahkan pemilik dari peminjam.** `@ObservedObject var
    # motion: MotionLogger` adalah dependensi yang **disuntikkan**: view itu
    # tidak membuatnya dan tidak boleh menghentikannya — `PointingView` yang
    # memanggil `motion.stop()` akan mematikan sensor untuk app jam seluruhnya.
    # Yang wajib melepas hanyalah berkas yang **membuat** instance-nya
    # (`= AudioCueEngine()`). Tanpa pemisahan ini, aturan berbunyi pada pohon
    # yang benar — tiga temuan palsu pada `PointingView` dan `CalibrationView`.
    properti_peta = {}
    for path, isi in berkas.items():
        for m in PROPERTI.finditer(isi):
            nama, tipe_eksplisit, tipe_infer = m.groups()
            properti_peta.setdefault(nama, []).append(
                (tipe_eksplisit or tipe_infer, path, True))
        for m in PROPERTI_BERTIPE.finditer(isi):
            nama, tipe = m.groups()
            properti_peta.setdefault(nama, []).append((tipe, path, False))

    masalah = []
    diperiksa = 0

    for nama, pola_akuisisi, pola_lepas, wajib in PASANGAN:
        akuisisi = re.compile(pola_akuisisi)
        lepas = re.compile(pola_lepas)

        # [1] Tipe mana yang memiliki akuisisi ini?
        pemilik = [(t, path, badan) for t, (path, badan) in tipe_peta.items()
                   if akuisisi.search(badan)]

        if not pemilik:
            if wajib:
                masalah.append(
                    f"[{nama}] tidak ada tipe di Apps/ yang mengakuisisi ini. "
                    f"Aturan ini kemungkinan berhenti mengukur (polanya berubah "
                    f"nama?), bukan pohonnya yang bersih.")
            continue

        diperiksa += 1

        for tipe, path_tipe, badan in pemilik:
            # [2] Tipe itu wajib punya metode pelepasan yang memuat pola lepas.
            pelepas = []
            for m in DEKLARASI_PELEPAS.finditer(badan):
                buka = badan.index("{", m.start())
                isi_metode = blok_kurawal(badan, buka)
                if lepas.search(isi_metode):
                    pelepas.append(m.group(1))

            if not pelepas:
                masalah.append(
                    f"[{nama}] diakuisisi di `{tipe}` ({path_tipe}) tetapi tipe "
                    f"itu tidak punya metode pelepasan yang memuat "
                    f"`{pola_lepas}`. Sumber daya ini hidup sampai sistem "
                    f"mematikan prosesnya.")
                continue

            # [3] Ada properti bertipe itu, dan berkas mana yang **membuatnya**?
            semua_instance = [(p, path_p, milik)
                              for p, daftar in properti_peta.items()
                              for (t, path_p, milik) in daftar if t == tipe]
            instances = [(p, path_p) for p, path_p, milik in semua_instance if milik]
            if not semua_instance:
                # Tidak ada properti bertipe itu: mungkin ia dipakai sebagai
                # nilai statis/global. Pelepasan lewat `deinit` masih sah.
                if not DEINIT.search(badan):
                    masalah.append(
                        f"[{nama}] `{tipe}` punya pelepasan "
                        f"({', '.join(sorted(set(pelepas)))}) tetapi tidak ada "
                        f"properti bertipe `{tipe}` di Apps/ dan tipe itu tidak "
                        f"punya `deinit`. Tidak ada yang bisa memanggilnya.")
                continue

            # [4] Pelepasan wajib dipanggil lewat penerima itu, dari **setiap
            # berkas yang memiliki instance-nya**.
            #
            # **Kenapa per-berkas, bukan "di mana pun di pohon".** Versi
            # sebelumnya menerima satu panggilan di berkas mana saja. Terukur:
            # `audioCue.stop()` dihapus dari app jam tetap hijau, karena app
            # iPhone memanggilnya — padahal kedua app punya instance sendiri
            # (`private let audioCue = AudioCueEngine()`), jadi melepas di satu
            # app tidak melepas apa pun di app lain. Satu panggilan dipakai
            # sebagai bukti untuk dua pemilik. Harness keadaan [3] dan [4]
            # menangkapnya.
            for nama_metode in sorted(set(pelepas)):
                for nama_prop, path_prop in instances:
                    pola_panggil = re.compile(
                        rf"\b{re.escape(nama_prop)}\s*\.\s*{re.escape(nama_metode)}"
                        rf"\s*\(\s*\)")
                    terpanggil = bool(pola_panggil.search(berkas[path_prop]))
                    if not terpanggil and not DEINIT.search(badan):
                        masalah.append(
                            f"[{nama}] `{tipe}.{nama_metode}()` ada, tetapi "
                            f"`{nama_prop}.{nama_metode}()` tidak dipanggil di "
                            f"{path_prop}, tempat instance itu hidup. Pelepasan "
                            f"yang tidak pernah dipanggil sama saja dengan tidak "
                            f"ada — dan `motion.stop()` atau `engine.stop()` "
                            f"bukan penggantinya. Panggilan di berkas lain tidak "
                            f"melepas instance di sini.")

    # [5] Nol yang diperiksa = GAGAL, bukan lolos.
    if diperiksa == 0:
        masalah.append(
            "tidak ada satu pun pasangan sumber daya yang diperiksa: Aturan 94 "
            "tidak mengukur apa pun.")

    if masalah:
        for m in masalah:
            print(f"  - {m}")
        return 1

    nama_nama = [n for n, pola, _, _ in PASANGAN
                 if any(re.search(pola, isi) for isi in berkas.values())]
    print(f"Aturan 94: {diperiksa} sumber daya bersama berpasangan dan "
          f"dipanggil lewat penerimanya ({', '.join(nama_nama)}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
