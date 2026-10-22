#!/usr/bin/env python3
"""Aturan 93: setiap sumber sensor yang di-start wajib di-stop di jalur teardown.

Kenapa aturan ini ada.

App jam memegang empat sumber daya yang hidup di luar pandangan layar:
pembaruan motion 20 Hz, pembaruan lokasi, alur sesi `WCSession`, dan
`PointingEngine` yang mempertahankan objek terakhir. Semuanya di-start di
`start()` dan di-stop di `stop()`. `stop()` dipanggil dari `.onDisappear` dan
dari `scenePhase` — jalur yang tidak pernah dijalankan tes mana pun, karena
tidak ada tes yang bisa menurunkan pergelangan tangan.

Diukur dengan mutasi pada pohon yang seharusnya hijau: isi `stop()` di
`PointAndKnowWatchWatchApp.swift` diganti dengan komentar kosong, lalu
`./swift-ui-lint.sh` dijalankan — **92 aturan hijau, exit 0**. Artinya seluruh
siklus hidup sensor bisa dihapus dan tidak satu pun gerbang berbunyi. Ini
kelas cacat yang paling mahal di repo ini karena tiga hal sekaligus:

1. **Baterai.** Motion 20 Hz dan GPS yang tidak berhenti saat pergelangan
   diturunkan menguras jam yang justru dipakai sepanjang malam di luar.
2. **Kejujuran identifikasi.** `PointingEngine.stop()` membatalkan objek
   terakhir. Tanpa itu, objek terakhir tetap tersisa di layar dan di
   complication seolah masih terkonfirmasi — persis "false confidence" yang
   dilarang PRD v0.4, dan tidak terlihat sebagai bug: layarnya hanya
   *terlalu yakin*.
3. **Tidak terdeteksi.** Compiler tidak protes (metodenya tetap ada), 92
   aturan UI tidak protes (teksnya tidak berubah), dan tes Linux tidak bisa
   menjangkau `scenePhase`.

Kenapa yang diukur adalah **pasangan start/stop**, bukan daftar nama.

Menuliskan `motion.stop()` dan `location.stop()` di sini akan membuat aturan
ini berhenti mengukur tepat saat sumber kelima ditambahkan — saat ia paling
dibutuhkan. Karena itu daftarnya **dipanen dari badan `start()`**: setiap
`X.start(...)` di `start()` menuntut `X.stop()` di `stop()`. Menambah sensor
berarti menambah tuntutan, tanpa menyentuh berkas ini.

Yang diperiksa:

1. `start()` dan `stop()` sama-sama ada di berkas titik masuk app jam.
2. Setiap `X.start(` di `start()` punya `X.stop()` di `stop()`.
3. Nol pasangan = GAGAL, bukan lolos. `start()` yang hilang atau berganti
   nama lebih mungkin berarti aturan ini berhenti mengukur daripada app
   berhenti punya sensor.
4. `scenePhase` masih memetakan `.inactive`/`.background` ke `stop()`. Tanpa
   itu `stop()` benar tetapi tidak pernah dipanggil, dan aturan ini akan
   hijau untuk app yang tetap menguras baterai.

Batasnya jujur: ini sapuan **teks**, bukan analisis aliran kendali. Ia tidak
bisa membuktikan `stop()` benar-benar dieksekusi watchOS, tidak bisa
membuktikan urutan start/stop tepat, dan tidak memeriksa app iPhone (yang
tidak memegang sensor). Ia membuktikan hal yang tadinya tidak diukur siapa
pun: **tidak ada sumber sensor yang di-start tanpa pasangan stop di jalur
teardown**, dan jalur itu masih tersambung ke `scenePhase`.

Jalankan dari akar repo. Exit 0 = bersih, 1 = ada yang putus.
"""
import pathlib
import re
import sys

TITIK_MASUK = pathlib.Path(
    "Apps/PointAndKnowWatch/Sources/PointAndKnowWatchWatchApp.swift")

# `private func start() {` / `func stop()` — deklarasi, bukan pemanggilan.
DEKLARASI = re.compile(
    r"^[ \t]*(?:(?:private|internal|public|fileprivate|static)\s+)*"
    r"func\s+(start|stop)\s*\(\s*\)[^{]*\{", re.M)

# `location.start()` / `motion.start(controller: ...)` / `engine.start()`.
# Sengaja **tidak** mencocokkan `location.start` tanpa kurung kurawal, supaya
# penyebutan di komentar tidak dihitung.
MULAI = re.compile(r"\b(\w+)\.start\s*\(")
HENTI = re.compile(r"\b(\w+)\.stop\s*\(")

# `case .inactive, .background:` -> `stop()`
CABANG_LATAR = re.compile(
    r"case\s+[^:\n]*\.(?:inactive|background)[^:\n]*:\s*\n?\s*stop\s*\(\s*\)")


def buang_komentar(isi):
    """Buang komentar supaya docstring yang menyebut `.start()` tidak dihitung."""
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


def badan(isi, nama):
    """Badan fungsi `nama()` pertama, atau None."""
    for m in DEKLARASI.finditer(isi):
        if m.group(1) == nama:
            return blok_kurawal(isi, isi.index("{", m.start()))
    return None


def main():
    if not TITIK_MASUK.is_file():
        print(f"GAGAL {TITIK_MASUK} tidak ada: Aturan 93 tidak mengukur apa pun,")
        print("      dan siklus hidup sensor bisa lepas tanpa satu pun galat.")
        return 1

    isi = buang_komentar(TITIK_MASUK.read_text(encoding="utf-8"))

    badan_start = badan(isi, "start")
    badan_stop = badan(isi, "stop")
    if badan_start is None or badan_stop is None:
        print(f"GAGAL `start()` atau `stop()` tidak ditemukan di {TITIK_MASUK}:")
        print("      Aturan 93 tidak mengukur apa pun (namanya berubah?).")
        print("      Tanpa pasangan start/stop, sensor tetap hidup saat app")
        print("      ditinggal — baterai habis dan objek terakhir tetap tampak")
        print("      terkonfirmasi.")
        return 1

    dimulai = sorted({m.group(1) for m in MULAI.finditer(badan_start)})
    dihentikan = {m.group(1) for m in HENTI.finditer(badan_stop)}

    if not dimulai:
        print("GAGAL tidak ada `X.start(` di dalam `start()`:")
        print("      Aturan 93 tidak mengukur apa pun. App jam wajib punya")
        print("      setidaknya satu sumber sensor.")
        return 1

    masalah = []
    for nama in dimulai:
        if nama not in dihentikan:
            masalah.append(
                f"`{nama}.start(` dipanggil di `start()` tetapi `{nama}.stop()` "
                f"tidak ada di `stop()`: sumber ini tetap hidup saat "
                f"pergelangan diturunkan (baterai) dan keadaannya tidak "
                f"dibatalkan (objek terakhir tetap tampak terkonfirmasi).")

    if not CABANG_LATAR.search(isi):
        masalah.append(
            "`scenePhase` tidak lagi memetakan `.inactive`/`.background` ke "
            "`stop()`: `stop()` benar tetapi tidak pernah dipanggil, jadi "
            "aturan ini akan hijau untuk app yang tetap menguras baterai.")

    if masalah:
        for m in masalah:
            print(f"  - {m}")
        return 1

    print(f"Aturan 93: {len(dimulai)} sumber sensor di-start dan di-stop "
          f"berpasangan ({', '.join(dimulai)}), dan `scenePhase` memanggil "
          f"`stop()`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
