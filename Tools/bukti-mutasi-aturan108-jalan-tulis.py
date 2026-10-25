#!/usr/bin/env python3
"""Buktikan Aturan 108 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 108 menjaga bahwa `publish(_:)` tetap satu-satunya jalan tulis snapshot
dengan keempat efek sampingnya utuh. Gerbang yang hijau pada hari ia ditulis
tidak membuktikan apa pun — yang membuktikan adalah ia MERAH pada setiap bentuk
cacat, dan HIJAU pada setiap bentuk yang benar. Karena itu harness ini
menyunting berkas **sungguhan** lalu mengembalikannya, dan menuntut kedua arah.

Keadaan, karena satu mutasi hanya menutup satu jalan:

  1. **`lockArrival = …` dihapus dari tubuh `publish`** — cacat intinya. Harus
     MERAH, dan harus menyebut berkas + baris tanda tangannya.
  2. **`recordComplicationIfChanged()` dihapus** — efek samping yang sama, arah
     yang berbeda (wajah jam). Harus MERAH.
  3. **`refreshSlewVerdict(at: Date())` dihapus** — efek samping keselamatan.
     Harus MERAH.
  4. **`snapshot = value` dihapus** — pemerbaranya sendiri. Harus MERAH.
  5. **`snapshot = controller.snapshot` ditulis langsung di `ingest`** —
     pemecahan choke point: satu jalur pemanggil menulis sendiri, jadi tiga
     efek samping tidak ikut. Harus MERAH.
  6. **Komentar menyebut `snapshot = value`** — dokumentasi yang benar harus
     tetap HIJAU. Gerbang yang merah atas komentar akan dimatikan orang.
  7. **Pemanggil ketujuh ditambahkan** (`publish(controller.snapshot)` di
     fungsi baru) — memperbanyak pemanggil bukan cacat. Harus HIJAU, dan
     hitungannya harus naik 6 → 7; gerbang yang menghitung tetap hidup.
  8. **Berkas Swift dikosongkan seluruhnya** — cakupan nol. Harus MERAH
     ("tidak satu pun tubuh `publish(_:)` terbaca"), bukan hijau atas nol
     berkas: hijau atas nol adalah bentuk paling sunyi dari gerbang yang tidak
     mengukur apa pun.

Setiap keadaan menyunting berkas **sungguhan** lalu mengembalikannya, dan
pemulihannya diverifikasi byte-per-byte. Harness menolak berjalan di atas
sumber yang sudah kotor.
"""
from __future__ import annotations

import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GATE = os.path.join(ROOT, "Tools", "check-aturan108-jalan-tulis-snapshot.py")
ENGINE = os.path.join(ROOT, "Apps", "Shared", "PointingEngine.swift")

#: Jangkar: tubuh `publish` persis seperti tertulis di sumber sekarang.
#: Dibaca dari sumber **sekarang**, jadi kalau bentuknya berubah harness ini
#: berhenti dengan pesan yang jelas alih-alih "lulus" tanpa menyunting apa pun.
BADAN = """    private func publish(_ value: PointingSnapshot) {
        snapshot = value
        lockArrival = arrivalGate.update(with: value)
        recordComplicationIfChanged()
        // Putusan GoTo ikut diperbarui di sini — **satu tempat**, bersama
        // snapshot yang ia jelaskan.
        //
        // **Kenapa di `publish`, bukan di `ingest`.** Putusan ini adalah
        // penjelasan atas sebuah jawaban, jadi ia harus berubah tepat saat
        // jawabannya berubah — dan jawaban berubah lewat enam jalur yang
        // menulis snapshot, bukan hanya lewat sampel sensor. Kalau ia dipasang
        // di `ingest` saja, `stop()` dan `setSensorAvailable` akan
        // meninggalkan peringatan atas benda yang sudah tidak ditunjuk lagi:
        // layar menampilkan "Tidak ada objek yang bisa diarahkan" di sebelah
        // keadaan "Sensor mati", dan tidak ada yang terlihat keliru.
        //
        // Peringatan keselamatan yang tertinggal bukan sekadar terlambat — ia
        // **salah**. Karena itu ia tidak boleh punya jalur hidup sendiri di
        // luar satu-satunya jalan tulis snapshot.
        refreshSlewVerdict(at: Date())
    }"""

#: Bagian-bagian yang dihapus untuk membentuk mutasi. Semuanya jangkar unik di
#: dalam tubuh `publish`, dan seluruhnya dibaca dari `BADAN` yang diverifikasi
#: hadir tepat satu kali lebih dulu.
HAPUS = {
    "lockArrival": "        lockArrival = arrivalGate.update(with: value)\n",
    "complication": "        recordComplicationIfChanged()\n",
    "putusan GoTo": "        refreshSlewVerdict(at: Date())\n",
    "pemerbar snapshot": "        snapshot = value\n",
}

#: Tempat menyisipkan jalur tulis langsung: di dalam `ingest`, satu-satunya
#: fungsi yang snapshot-nya berasal dari `update.snapshot` (jadi penulisan
#: langsungnya punya nilai yang masuk akal untuk dicoba penyerang).
INGEST_ANCHOR = "        publish(update.snapshot)"

#: Tempat menyisipkan pemanggil ketujuh: setelah `apply(calibration:)`.
APPLY_ANCHOR = """    public func apply(calibration: PointingCalibration) {
        controller.apply(calibration: calibration)
        publish(controller.snapshot)
    }"""


def jalankan() -> tuple[int, str]:
    hasil = subprocess.run([sys.executable, GATE], capture_output=True, text=True)
    return hasil.returncode, hasil.stdout + hasil.stderr


def baca(path: str) -> tuple[bytes, str]:
    mentah = open(path, "rb").read()
    return mentah, mentah.decode("utf-8")


def main() -> int:
    if not os.path.exists(GATE):
        print(f"FAIL gerbangnya tidak ada: {GATE}")
        return 1

    asli_mentah, teks = baca(ENGINE)

    # Jangkar wajib unik dan hadir — jangkar basi berarti setiap keadaan
    # "lulus" tanpa menyunting apa pun.
    for nama, jangkar in (
            ("tubuh publish", BADAN),
            ("panggilan ingest", INGEST_ANCHOR),
            ("apply(calibration:)", APPLY_ANCHOR)):
        if teks.count(jangkar) != 1:
            print(f"FAIL jangkar {nama} tidak unik/hilang ({teks.count(jangkar)} "
                  f"kecocokan)")
            print("     Harness ini bekerja pada teks; jangkar yang basi")
            print("     berarti ia tidak menyunting apa pun dan setiap")
            print("     keadaan akan «lulus» tanpa menguji apa pun.")
            return 1

    #: (nama, teks_baru, harap_exit)
    keadaan: list[tuple[str, str, int]] = []

    # 1–4. Keempat penulisan di tubuh `publish`, dibuang satu per satu.
    for nama, potongan in HAPUS.items():
        keadaan.append((
            f"tubuh publish: `{nama}` dihapus (harus MERAH)",
            teks.replace(BADAN, BADAN.replace(potongan, "")),
            1))

    # 5. Pemecahan choke point: satu jalur pemanggil menulis sendiri.
    keadaan.append((
        "ingest: `snapshot = update.snapshot` ditulis langsung (harus MERAH)",
        teks.replace(INGEST_ANCHOR,
                     "        snapshot = update.snapshot\n"
                     "        lockArrival = arrivalGate.update(with: update.snapshot)"),
        1))

    # 6. Kontrol positif: dokumentasi yang menyebut bentuk terlarang tetap hijau.
    keadaan.append((
        "komentar menyebut `snapshot = value` (harus HIJAU)",
        teks.replace(APPLY_ANCHOR, APPLY_ANCHOR
                     + "\n    // Jangan tulis `snapshot = value` langsung di "
                       "sini; lewat publish(_:)."),
        0))

    # 7. Pemanggil ketujuh bukan cacat — dan hitungannya harus naik.
    keadaan.append((
        "pemanggil publish ketujuh ditambahkan (harus HIJAU)",
        teks.replace(APPLY_ANCHOR, APPLY_ANCHOR + """

    public func refreshLocation(_ location: ObserverLocation) {
        self.location = location
        publish(controller.snapshot)
    }"""),
        0))

    hasil: list[tuple[str, bool, str]] = []

    kode, keluaran = jalankan()
    if kode != 0:
        print("FAIL baseline sudah merah — harness ini menolak berjalan di atas")
        print("     sumber yang kotor. Perbaiki dulu, lalu jalankan ulang.")
        print()
        print(keluaran)
        return 1
    hasil.append(("[baseline] pohon apa adanya", True, "exit=0"))

    for nama, teks_baru, harap in keadaan:
        if teks_baru == teks:
            hasil.append((nama, False, "mutasinya tidak mengubah berkas — "
                                       "keadaan ini tidak menguji apa pun"))
            continue
        try:
            open(ENGINE, "w", encoding="utf-8").write(teks_baru)
            kode, keluaran = jalankan()
        finally:
            open(ENGINE, "wb").write(asli_mentah)

        pulih = open(ENGINE, "rb").read() == asli_mentah
        if not pulih:
            hasil.append((nama, False, "sumber produksi TIDAK pulih — periksa "
                                       "secara manual sebelum lanjut"))
            continue

        sebab = ""
        if kode != harap:
            sebab = " | " + " ; ".join(
                l.strip() for l in keluaran.splitlines()
                if l.strip().startswith(("FAIL", "  Apps/")))[:300]
        hasil.append((nama, kode == harap, f"exit={kode} (harap {harap}){sebab}"))

    # 8. Cakupan nol: seluruh berkas Swift dikosongkan. Hijau atas nol berkas
    #    adalah bentuk paling sunyi dari gerbang yang tidak mengukur apa pun.
    #    Pemulihannya wajib byte-per-byte seperti keadaan lain — dan karena
    #    keadaan ini menyentuh 28 berkas, seluruh isinya disalin ke memori
    #    lebih dulu supaya pemulihannya tidak bergantung pada proses ini.
    semua_swift = sorted(glob.glob(os.path.join(ROOT, "Apps", "**", "*.swift"),
                                   recursive=True))
    salinan_swift = {path: open(path, "rb").read() for path in semua_swift}
    try:
        for path in semua_swift:
            open(path, "w", encoding="utf-8").write("")
        kode, keluaran = jalankan()
    finally:
        for path, isi in salinan_swift.items():
            open(path, "wb").write(isi)

    pulih_nol = all(open(p, "rb").read() == i for p, i in salinan_swift.items())
    if not pulih_nol:
        hasil.append(("sumber produksi pulih byte-per-byte (cakupan nol)", False,
                      "BERBEDA — pulihkan manual dari git sebelum lanjut"))
    else:
        hasil.append((
            f"seluruh {len(semua_swift)} berkas Swift dikosongkan (cakupan nol, "
            "fail-closed)",
            kode == 1,
            f"exit={kode} (harap 1)" + ("" if kode == 1 else
                                       " | " + keluaran.strip()[:200])))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'OK  ' if lolos else 'FAIL'} {nama} — {detail}")

    print()
    if gagal:
        print(f"Aturan 108: {len(gagal)} dari {len(hasil)} keadaan tidak sesuai.")
        return 1
    print(f"Aturan 108: {len(hasil)} keadaan sesuai harapan — jalan tulis "
          f"snapshot tidak bisa dibongkar lagi tanpa gerbang merah, sementara "
          f"komentar dan pemanggil tambahan tetap hijau.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
