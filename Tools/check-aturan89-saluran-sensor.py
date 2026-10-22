#!/usr/bin/env python3
"""Aturan 89: setiap jalur "sensor hilang" di MotionLogger wajib melewati publishSensorLoss().

Kenapa aturan ini ada.

Aturan 53 menjaga tiga bentuk jujur di `MotionLogger`, dan salah satunya
adalah perintah `let events = controller.setSensorAvailable(false)` — yang
hidup **di dalam** `publishSensorLoss()`. Aturan itu menghitung bentuknya
muncul tepat sekali, dan itu benar untuk apa yang ia ukur.

Yang tidak diukur siapa pun: **apakah fungsi itu dipanggil dari setiap jalur
yang menyatakan sensor hilang.** Ada dua jalur seperti itu —

    start(controller:)  guard manager.isDeviceMotionAvailable else { … }
    handleFailure(_:)   error dari CoreMotion di tengah pemakaian

— dan keduanya menulis `unavailableReason` lebih dulu. Menghapus pemanggilan
`publishSensorLoss()` dari salah satunya **tidak** mengubah hitungan Aturan 53
sama sekali: perintahnya masih ada, tepat sekali, di dalam fungsi yang kini
tidak dipanggil jalur itu.

Terukur (`Tools/sapu-buta-apps.py`, ketiga gerbang lokal, proses baru):
menghapus pemanggilan di `handleFailure` **lolos ketiga gerbang** — ui-lint,
typecheck, dan `swift test`. Cacatnya bukan teks yang hilang, melainkan
**sambungan** yang putus, dan seluruh gerbang repo ini membaca teks atau
menjalankan fungsi murni; tidak ada yang menjalankan `MotionLogger` (butuh
CoreMotion, hanya ada di macOS).

Kenapa akibatnya serius, bukan sekadar rapi. `PointingEngine.snapshot` —
satu-satunya sumber yang dibaca semua layar — hanya ditulis lewat
`onUpdate`, dan `onUpdate` hanya dipanggil dari `consume(_:)` dan
`publishSensorLoss()`. Sampel sudah berhenti karena CoreMotion melaporkan
galat, jadi `consume` tidak akan datang lagi. Tanpa `publishSensorLoss()`:

  * `controller.setSensorAvailable(false)` **tidak pernah dijalankan**, jadi
    `PointingController.isSensorAvailable` tetap `true`;
  * alur (`machine`) tidak dihentikan, jadi ia tetap memegang kunci terakhir;
  * `PointingEngine.snapshot` tetap berisi objek terakhir dengan tingkat
    keyakinan lamanya.

Layar lalu menampilkan objek yang sama, dengan keyakinan yang sama, seolah
sensor masih hidup — persis "false confidence" yang dilarang PRD. Dan ia
tidak bisa dibantah dari layar: tidak ada teks yang berubah.

Yang diperiksa, dan kenapa persis itu.

1. Setiap blok yang **menyatakan sensor hilang** — ditandai penulisan
   `unavailableReason = …` yang bukan `nil` — wajib memuat pemanggilan
   `publishSensorLoss()` di dalam blok yang sama. Penandanya sengaja
   `unavailableReason`, bukan nama fungsi: `start` dan `handleFailure` punya
   bentuk berbeda (satu `guard … else`, satu badan fungsi), dan aturan yang
   mengunci nama fungsi akan diam begitu salah satunya diganti nama.

2. `publishSensorLoss()` wajib tetap memanggil
   `controller.setSensorAvailable(false)` **dan** `onUpdate?` — fungsi yang
   dipanggil tapi isinya dikosongkan sama saja dengan tidak dipanggil.

3. Hitungan jalur wajib **tepat 2**. Kalau berkas ini tumbuh jalur ketiga
   yang menyatakan sensor hilang tanpa pemanggilan, aturan memerah. Kalau
   jumlahnya menyusut jadi 1, itu juga memerah: bukan karena cacat, tapi
   karena aturan ini berhenti mengukur apa yang ia kira diukur, dan gerbang
   yang diam-diam menyempit adalah gerbang yang tidak menjaga apa pun.

Fail-closed. Berkas hilang = merah. Nol jalur ditemukan = merah (bukan
"bersih karena tidak ada yang dilanggar"). Ini pembeda yang penting: sapuan
`sapu-buta-apps.py` sendiri pernah mencetak "LOLOS SELURUH GERBANG" untuk
cacat ini, jadi gerbang yang bisa hijau pada masukan kosong tidak boleh
dipercaya.

Jalankan dari akar repo. Exit 0 = bersih, 1 = ada yang putus.
"""
import re
import sys

MOTION = "Apps/Shared/MotionLogger.swift"

#: Jumlah jalur "sensor hilang" yang sah. Dua: sensor tidak ada sejak awal
#: (`start`) dan galat di tengah pemakaian (`handleFailure`). Angka ini
#: **dihitung dari kode**, bukan dikarang: lihat `grep -n "unavailableReason"`.
JUMLAH_JALUR = 2

#: Penanda sebuah jalur menyatakan sensor hilang. `unavailableReason = nil`
#: adalah kebalikannya (sensor pulih), jadi ia tidak dihitung.
#:
#: Nilainya ditangkap lewat grup, **bukan** lookahead `(?!nil\b)`. Versi
#: pertama aturan ini memakai lookahead dan menghitung 3 jalur, bukan 2:
#: `\s*` yang rakus bisa mundur satu karakter, sehingga `(?!nil\b)` diperiksa
#: pada spasi sebelum `nil` dan lolos. Lookahead yang bergantung pada
#: kemunduran kuantifier adalah lookahead yang mengukur tempat yang salah.
PENANDA = re.compile(r"unavailableReason\s*=\s*([^\n]*)")


def buang_komentar(kode: str) -> str:
    """Buang komentar supaya docstring yang mengutip bentuk cacat tidak dihitung."""
    kode = re.sub(r"/\*.*?\*/", "", kode, flags=re.S)
    kode = re.sub(r"//[^\n]*", "", kode)
    return kode


def blok_sekitar(kode: str, posisi: int) -> tuple[int, int]:
    """Rentang blok ({…}) yang **memuat** `posisi`, ditelusuri ke luar.

    Versi pertama fungsi ini mencari kurung buka **sesudah** `posisi`, dan itu
    salah untuk penanda yang letaknya di dalam badan fungsi: ia menemukan
    `{` milik `guard … else {` berikutnya, sehingga jalur yang benar terbaca
    "tidak memanggil publishSensorLoss" dan aturan memerah pada kode yang
    benar. Aturan yang memerah pada kode benar akan dimatikan orang, jadi
    arah penelusurannya harus ke luar, bukan ke depan.

    Ditelusuri dengan menghitung kurung kurawal: badan `guard … else { }` dan
    badan fungsi punya bentuk berbeda, dan keduanya harus tertangkap aturan
    yang sama.
    """
    kedalaman = 0
    buka = -1
    for i in range(posisi, -1, -1):
        if kode[i] == "}":
            kedalaman += 1
        elif kode[i] == "{":
            if kedalaman == 0:
                buka = i
                break
            kedalaman -= 1
    if buka == -1:
        return posisi, posisi

    kedalaman = 0
    for i in range(buka, len(kode)):
        if kode[i] == "{":
            kedalaman += 1
        elif kode[i] == "}":
            kedalaman -= 1
            if kedalaman == 0:
                return buka, i
    return buka, len(kode)


def main() -> int:
    try:
        with open(MOTION, encoding="utf-8") as fh:
            mentah = fh.read()
    except FileNotFoundError:
        print(f"FAIL {MOTION} tidak ada: aturan saluran sensor-hilang tidak mengukur apa pun.")
        return 1

    kode = buang_komentar(mentah)
    masalah: list[str] = []

    # Jalur "sensor hilang" = penulisan `unavailableReason` yang **bukan** `nil`.
    # `unavailableReason = nil` adalah kebalikannya (sensor pulih), dan ia sah
    # ada di `start` saat sensor berhasil menyala.
    jalur = [m.start() for m in PENANDA.finditer(kode)
             if not m.group(1).strip().startswith("nil")]
    if len(jalur) != JUMLAH_JALUR:
        masalah.append(
            f"  {MOTION}: {len(jalur)} jalur \"sensor hilang\" ditemukan, "
            f"harus {JUMLAH_JALUR}.\n"
            f"    Kalau jalur baru memang ditambahkan, pastikan ia memanggil "
            f"publishSensorLoss(),\n"
            f"    lalu perbarui JUMLAH_JALUR di aturan ini. Kalau jumlahnya "
            f"menyusut, aturan ini\n"
            f"    berhenti mengukur apa yang ia kira diukur.")

    for pos in jalur:
        buka, tutup = blok_sekitar(kode, pos)
        badan = kode[buka:tutup]
        nomor_baris = kode.count("\n", 0, pos) + 1
        if "publishSensorLoss()" not in badan:
            potongan = " ".join(kode[pos:pos + 90].split())
            masalah.append(
                f"  {MOTION}:{nomor_baris}: jalur \"sensor hilang\" tidak "
                f"memanggil publishSensorLoss().\n"
                f"    penandanya: {potongan}\n"
                f"    Akibatnya controller.setSensorAvailable(false) tidak "
                f"pernah dijalankan, alur tidak\n"
                f"    dihentikan, dan PointingEngine.snapshot tetap memegang "
                f"objek terakhir seolah\n"
                f"    sensor masih hidup — false confidence yang dilarang PRD.")

    # Fungsi yang dipanggil tapi isinya dikosongkan sama saja tidak dipanggil.
    m = re.search(r"func\s+publishSensorLoss\s*\([^)]*\)\s*\{", kode)
    if not m:
        masalah.append(f"  {MOTION}: `publishSensorLoss` tidak ada — aturan ini "
                       f"tidak mengukur apa pun.")
    else:
        buka, tutup = blok_sekitar(kode, m.start())
        badan = kode[buka:tutup]
        if "controller.setSensorAvailable(false)" not in badan:
            masalah.append(
                f"  {MOTION}: `publishSensorLoss` tidak lagi memanggil "
                f"controller.setSensorAvailable(false)\n"
                f"    — alur tidak dihentikan, dan kunci terakhir tetap "
                f"dipegang mesin.")
        if "onUpdate?" not in badan:
            masalah.append(
                f"  {MOTION}: `publishSensorLoss` tidak lagi memanggil "
                f"onUpdate?\n"
                f"    — cuplikan yang dibaca layar tidak pernah diperbarui, "
                f"jadi layar tidak tahu.")

    if masalah:
        print("\n".join(masalah))
        return 1

    print(f"Bersih: {JUMLAH_JALUR} jalur \"sensor hilang\" di MotionLogger "
          f"melewati publishSensorLoss(),\n"
          f"dan fungsi itu masih menghentikan alur + memberi tahu layar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
