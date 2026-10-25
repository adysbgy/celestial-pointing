#!/usr/bin/env python3
"""Buktikan Aturan 105 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 105 menutup cacat yang bentuknya paling sulit dilihat di repo ini:
bunyi kunci yang rusak tidak mengubah satu piksel pun, tidak mengubah satu baris
teks pun, dan **tidak gagal mengompilasi**. Yang rusak hanya terdengar — dan
bunyi adalah satu-satunya saluran bagi pengguna yang tidak melihat layar, yaitu
tepat pengguna yang fitur ini ada untuknya.

Angka-angka itu dulu ditulis langsung di `Apps/Shared/AudioCue.swift`, tempat
`./swift-test.sh` tidak pernah membangunnya:

    let sampleRate: Double = 44100
    let duration: Double = 0.13
    let envelope = sin(.pi * Double(i) / Double(frameCount))
    samples[i] = Float(0.28 * sin(2 * .pi * 880 * t) * envelope)

Diukur pada pohon sebelum Aturan 105 ada: nol pemeriksaan di `Tools/` menyebut
`sampleRate`, `880`, atau rumus amplopnya.

Empat bentuk rusak yang semuanya mengompilasi bersih:

    amplop dibalik (1 - sin(...))   -> klik di kedua ujung buffer
    frequency = 0                   -> BISU TOTAL, tanpa satu pun galat
    peakAmplitude > 1.0             -> terpotong (clip) di mixer
    duration terlalu pendek         -> potongan gelombang, tinggi berubah

Keadaan, karena satu mutasi hanya menutup satu jalan:

  1. **`ToneSynth.sample(atIndex:...)` dibuang** — bentuk yang paling menipu:
     buffer terisi nol, `ToneSynth.sampleRate` dan `ToneSynth.frameCount`
     masih ada, dan gerbang substring telanjang **tetap hijau**. Harus MERAH.
  2. **`ToneSynth.sampleRate` -> literal `44100`** — salinan kedua angka
     bentuk nada kembali ke `Apps/`. Harus merah (dua kali: literal + pemakaian).
  3. **`ToneSynth.frameCount` -> literal `5733`** — panjang buffer tidak lagi
     diturunkan dari durasi. Harus merah (pemakaian hilang; `5733` sengaja
     dipilih karena ia **bukan** salah satu dari empat angka yang diperiksa,
     jadi hanya pemeriksaan pemakaian yang bisa menangkapnya).
  4. **Rumus amplop `sin(.pi * ...)` ditulis ulang di `Apps/`** — amplop hidup
     kembali di tempat yang tidak diuji Linux. Harus merah.
  5. **`frequency` di model digeser (880 -> 440)** — gerbang menjaga angka
     bentuk nada, bukan hanya keberadaan model. Harus merah.
  6. **Uji `testEnvelopeIsSilentAtBothEnds` dihapus** — sifat yang diklaim
     tidak lagi dijaga siapa pun. Harus merah.
  7. **`AudioCue.swift` dibuang jangkarnya** — gerbang kehilangan subjeknya.
     Harus GAGAL (fail-closed), bukan hijau.
  8. **`ToneSynth.swift` dibuang** — model hilang. Harus merah, bukan hijau
     atas berkas kosong.
  9. **Komentar menyebut angka itu** — gerbang harus tetap **hijau**: angka di
     dalam komentar bukan literal kode. Ini menjaga gerbang dari merah atas
     dokumentasi yang benar, karena gerbang yang merah pada kebenaran akan
     dimatikan orang.

Setiap keadaan menyunting berkas **sungguhan** lalu mengembalikannya, dan
pemulihannya diverifikasi byte-per-byte. Harness menolak berjalan di atas
sumber yang sudah kotor.
"""

from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "Apps", "Shared", "AudioCue.swift")
MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "ToneSynth.swift")
TESTS = os.path.join(ROOT, "Packages", "PointingKit", "Tests",
                     "PointingKitTests", "ToneSynthTests.swift")
GATE = os.path.join(ROOT, "Tools", "check-aturan105-bentuk-nada.py")

#: Pemanggilan satu-satunya baris yang benar-benar menghasilkan isi buffer.
PANGGIL_SAMPEL = (
    "                samples[i] = Float(ToneSynth.sample(atIndex: i,\n"
    "                                                    frameCount: Int(frameCount)))")
#: Deklarasi laju sampel di `Apps/`.
DEKLARASI_SAMPLERATE = "private let sampleRate: Double = ToneSynth.sampleRate"
#: Panjang buffer di `Apps/`.
PANGGIL_FRAMECOUNT = "AVAudioFrameCount(ToneSynth.frameCount)"
#: Deklarasi frekuensi di model.
DEKLARASI_FREKUENSI = "public static let frequency: Double = 880"
#: Uji yang menjaga amplop nol di kedua ujung.
UJI_AMPLOP = (
    "    func testEnvelopeIsSilentAtBothEnds() {")


def jalankan() -> tuple[int, str]:
    hasil = subprocess.run([sys.executable, GATE], capture_output=True, text=True)
    return hasil.returncode, hasil.stdout


def baca(path: str) -> tuple[bytes, str]:
    mentah = open(path, "rb").read()
    return mentah, mentah.decode("utf-8")


def main() -> int:
    if not os.path.exists(GATE):
        print(f"FAIL gerbangnya tidak ada: {GATE}")
        return 1

    asli_app, teks_app = baca(APP)
    asli_model, teks_model = baca(MODEL)
    asli_tes, teks_tes = baca(TESTS)

    # Jangkar wajib unik dan hadir — jangkar basi berarti setiap keadaan
    # "lulus" tanpa menyunting apa pun.
    for nama, teks, jangkar in (("Apps", teks_app, PANGGIL_SAMPEL),
                                ("model", teks_model, DEKLARASI_FREKUENSI),
                                ("uji", teks_tes, UJI_AMPLOP)):
        if jangkar not in teks:
            print(f"FAIL jangkar {nama} tidak ditemukan: {jangkar!r}")
            print("     Harness ini bekerja pada teks; jangkar yang basi")
            print("     berarti ia tidak menyunting apa pun dan setiap")
            print("     keadaan akan «lulus» tanpa menguji apa pun.")
            return 1

    #: (nama, [(path, teks_mutasi)], harap)
    keadaan: list[tuple[str, list[tuple[str, str]], int]] = []

    # 1. Isi buffer dibuang — gigi yang dulu nol.
    keadaan.append((
        "Apps: ToneSynth.sample() dibuang (buffer terisi nol)",
        [(APP, teks_app.replace(
            PANGGIL_SAMPEL,
            "                samples[i] = Float(0)"))],
        1))

    # 2. Laju sampel kembali jadi literal.
    keadaan.append((
        "Apps: sampleRate -> literal 44100 (salinan kedua angka)",
        [(APP, teks_app.replace(
            DEKLARASI_SAMPLERATE,
            "private let sampleRate: Double = 44100"))],
        1))

    # 3. Panjang buffer jadi literal yang bukan salah satu angka terdaftar.
    keadaan.append((
        "Apps: frameCount -> literal 5733 (bukan angka terdaftar)",
        [(APP, teks_app.replace(
            PANGGIL_FRAMECOUNT, "AVAudioFrameCount(5733)"))],
        1))

    # 4. Rumus amplop ditulis ulang di Apps/.
    keadaan.append((
        "Apps: rumus amplop sin(.pi * ...) ditulis ulang",
        [(APP, teks_app.replace(
            "                samples[i] = Float(ToneSynth.sample(atIndex: i,\n"
            "                                                    frameCount: Int(frameCount)))",
            "                samples[i] = Float(ToneSynth.peakAmplitude"
            " * sin(2 * .pi * 880 * t) * sin(.pi * Double(i)"
            " / Double(frameCount)))"))],
        1))

    # 5. Angka bentuk nada di model digeser.
    keadaan.append((
        "model: frequency 880 -> 440 (angka bentuk nada dijaga)",
        [(MODEL, teks_model.replace(
            DEKLARASI_FREKUENSI,
            "public static let frequency: Double = 440"))],
        1))

    # 6. Sifat yang diklaim tidak lagi diuji.
    keadaan.append((
        "uji: testEnvelopeIsSilentAtBothEnds dihapus",
        [(TESTS, teks_tes.replace(
            UJI_AMPLOP,
            "    func testEnvelopeIsSilentAtBothEnds_dihapus() {"))],
        1))

    # 7. Apps kehilangan jangkarnya -> fail-closed.
    keadaan.append((
        "Apps: deklarasi sampleRate dibuang (fail-closed)",
        [(APP, teks_app.replace(
            DEKLARASI_SAMPLERATE, ""))],
        1))

    # 8. Model dibuang -> subjek gerbang hilang.
    keadaan.append((
        "model: ToneSynth.swift dibuang (fail-closed)",
        [(MODEL, "")],
        1))

    # 9. Kontrol negatif: angka di komentar harus tetap hijau.
    keadaan.append((
        "Apps: angka 44100 hanya di komentar (harus HIJAU)",
        [(APP, teks_app.replace(
            "    // MARK: - Sintesis nada (prosedural, tanpa aset)",
            "    // MARK: - Sintesis nada (prosedural, tanpa aset)\n"
            "    // Catatan dokumentasi: laju 44100 dan frekuensi 880 dipakai\n"
            "    // ToneSynth; angka 0.13 detik dan amplitudo 0.28 juga di sana."))],
        0))

    hasil: list[tuple[str, bool, str]] = []

    kode, keluaran = jalankan()
    if kode != 0:
        # Baseline merah = pohon sudah kotor. Menjalankan mutasi di atasnya
        # akan membuat setiap keadaan «lulus» dengan alasan yang salah.
        print("FAIL baseline sudah merah — harness ini menolak berjalan di atas")
        print("     sumber yang kotor. Perbaiki dulu, lalu jalankan ulang.")
        print()
        print(keluaran)
        return 1
    hasil.append(("[baseline] pohon apa adanya", True, f"exit={kode}"))

    for nama, suntingan, harap in keadaan:
        mentah = {path: open(path, "rb").read() for path, _ in suntingan}
        bersih = True
        for path, teks_baru in suntingan:
            if teks_baru == mentah[path].decode("utf-8"):
                hasil.append((nama, False, "mutasinya tidak mengubah berkas — "
                                           "keadaan ini tidak menguji apa pun"))
                bersih = False
                break
        if not bersih:
            continue
        try:
            for path, teks_baru in suntingan:
                open(path, "w", encoding="utf-8").write(teks_baru)
            kode, keluaran = jalankan()
        finally:
            for path, isi in mentah.items():
                open(path, "wb").write(isi)
        pulih = all(open(path, "rb").read() == mentah[path] for path, _ in suntingan)
        if not pulih:
            hasil.append((nama, False, "sumber produksi TIDAK pulih — periksa "
                                       "secara manual sebelum lanjut"))
            continue
        sebab = ""
        if kode != harap:
            sebab = " | " + " ; ".join(
                l.strip() for l in keluaran.splitlines() if l.startswith("FAIL"))[:300]
        hasil.append((nama, kode == harap, f"exit={kode} (harap {harap}){sebab}"))

    pulih = (open(APP, "rb").read() == asli_app
             and open(MODEL, "rb").read() == asli_model
             and open(TESTS, "rb").read() == asli_tes)
    hasil.append(("sumber produksi pulih byte-per-byte", pulih,
                  "identik" if pulih else "BERBEDA — pulihkan manual"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'OK  ' if lolos else 'FAIL'} {nama} — {detail}")

    print()
    if gagal:
        print(f"Aturan 105: {len(gagal)} dari {len(hasil)} keadaan tidak sesuai.")
        return 1
    print(f"Aturan 105: {len(hasil)} keadaan sesuai harapan — bentuk nada tidak "
          f"bisa kembali ditulis di Apps/ tanpa gerbang merah, sementara angka "
          f"yang hanya hidup di komentar tetap hijau.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
