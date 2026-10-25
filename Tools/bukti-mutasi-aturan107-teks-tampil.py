#!/usr/bin/env python3
"""Buktikan Aturan 107 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 107 menjaga **kelengkapan** katalog terjemahan: setiap literal statis
yang menjadi argumen pertama `Label(`, `Text(`, `Button(`, `Toggle(`,
`Section(`, atau `navigationTitle(` di `Apps/` harus punya kunci di
`Localizable.xcstrings`. Aturan 91 sudah menjaga **pemasangan** sumber
terjemahan di `init()` setiap `@main`; yang tidak dijaga siapa pun adalah
apakah teks yang benar-benar ditulis di view ada di katalog itu.

Cacat yang ditutupnya terukur di pohon ini: dua teks tampil tanpa kunci —
nama tab `"Experiment 1"` dan `"Point & Know"` di complication kosong. Keduanya
mengompilasi bersih, lolos seluruh 106 gerbang lain, dan tidak punya satu pun
gejala: yang terlihat hanya satu label yang tidak ikut berganti bahasa pada
perangkat berbahasa Inggris. Kunci yang tidak ada di katalog tidak punya nilai
`en`, jadi tidak ada yang bisa diterjemahkan.

Gerbang yang hijau pada hari ia ditulis tidak membuktikan apa pun. Harness ini
karena itu menyunting berkas **sungguhan** lalu mengembalikannya, dan menuntut
gerbangnya MERAH pada setiap keadaan cacat — termasuk dua keadaan yang
menuntut **HIJAU**, karena gerbang yang merah atas kode yang benar akan
dimatikan orang, dan itu cara gerbang mati yang paling umum.

Keadaan, karena satu mutasi hanya menutup satu jalan:

  1. **`Label("Experiment 1")` dihapus dari katalog** — cacat intinya, bentuk
     yang benar-benar ada di pohon ini sebelum Aturan 107. Harus MERAH, dan
     harus menyebut berkas + barisnya.
  2. **`"Point & Know"` dihapus dari katalog** — cacat yang sama di berkas
     lain (complication). Membuktikan gerbang memindai seluruh `Apps/`, bukan
     satu view.
  3. **Teks baru tanpa kunci disisipkan ke sebuah view** — arah yang paling
     penting: gerbang harus berbunyi pada teks yang **belum pernah** ada,
     bukan hanya pada dua teks yang sudah dikenal. Harus MERAH.
  4. **Kunci kosong (`""`)** — `Label("")` tidak menampilkan apa pun dan bukan
     teks yang perlu diterjemahkan; ia harus tetap HIJAU. Kontrol negatif
     terhadap gerbang yang menuduh setiap literal.
  5. **`Label(teksDinamis)` dan `Label(verbatim:)`** — teksnya baru diketahui
     saat berjalan, jadi tidak bisa punya kunci. Harus HIJAU; menuduhnya
     berarti merah pada kode yang benar.
  6. **Interpolasi `Label("\\(nama)")`** — bentuk yang paling mudah salah
     tuduh: literalnya ada, tapi isinya berjalan. Harus HIJAU.
  7. **Katalog dikosongkan** — fail-closed: gerbang yang tidak menemukan
     subjeknya sudah berhenti mengukur, dan harus MERAH, bukan hijau atas
     katalog kosong.
  8. **Komentar menyebut `Label("Teks Tanpa Kunci")`** — dokumentasi yang
     benar harus tetap HIJAU. Gerbang yang merah atas komentar akan dimatikan
     orang.
  9. **Berkas Swift dikosongkan seluruhnya** — cakupan nol. Gerbang harus
     MERAH ("tidak ada berkas Swift"), bukan hijau dengan alasan yang salah;
     hijau atas nol berkas adalah bentuk paling sunyi dari gerbang yang tidak
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
GATE = os.path.join(ROOT, "Tools", "check-aturan107-teks-tampil.py")
CATALOG = os.path.join(ROOT, "Apps", "Shared", "Resources",
                       "Localizable.xcstrings")
DIAGNOSTICS = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                           "DiagnosticsView.swift")
COMPLICATION = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Complications",
                            "ComplicationWidget.swift")

#: Jangkar: baris yang memuat literal tanpa kunci sebelum Aturan 107 ada.
#: Keduanya dibaca dari sumber **sekarang**, jadi kalau teksnya berubah bentuk
#: harness ini berhenti dengan pesan yang jelas alih-alih "lulus" tanpa
#: menyunting apa pun.
TAB_LABEL = 'Label("Experiment 1", systemImage: "target")'
COMPLICATION_LABEL = 'Label("Point & Know", systemImage: "scope")'

#: Tempat menyisipkan teks baru: di dalam `body` sebuah view yang sudah ada.
#: `TabView {` dipilih karena ia hanya muncul **sekali** di berkas ini (tiga
#: `var body: some View {` membuat jangkar itu ambigu, dan harness ini memang
#: menolak jangkar yang tidak unik — penjaganya berbunyi saat ditulis).
INSERT_ANCHOR = "    var body: some View {\n        TabView {"

#: Kunci katalog yang dihapus, persis seperti tertulis di JSON.
KEY_EXPERIMENT = '''    "Experiment 1": {
      "comment": "Nama tab Experiment 1 di iPhone. Istilah ini nama percobaan (proper noun), jadi tidak diterjemahkan ke bahasa lain.",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Experiment 1"
          }
        }
      }
    },
'''
KEY_POINT_AND_KNOW = '''    "Point & Know": {
      "comment": "Nama app yang tampil di complication saat belum ada data sama sekali. Nama produk, jadi tidak diterjemahkan.",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Point & Know"
          }
        }
      }
    }'''


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

    asli_katalog, teks_katalog = baca(CATALOG)
    asli_diag, teks_diag = baca(DIAGNOSTICS)
    asli_comp, teks_comp = baca(COMPLICATION)

    # Jangkar wajib unik dan hadir — jangkar basi berarti setiap keadaan
    # "lulus" tanpa menyunting apa pun.
    for nama, teks, jangkar in (
            ("tab Experiment 1", teks_diag, TAB_LABEL),
            ("complication Point & Know", teks_comp, COMPLICATION_LABEL),
            ("sisipan body", teks_diag, INSERT_ANCHOR),
            ("kunci Experiment 1", teks_katalog, KEY_EXPERIMENT),
            ("kunci Point & Know", teks_katalog, KEY_POINT_AND_KNOW)):
        if teks.count(jangkar) != 1:
            print(f"FAIL jangkar {nama} tidak unik/hilang ({teks.count(jangkar)} "
                  f"kecocokan)")
            print("     Harness ini bekerja pada teks; jangkar yang basi")
            print("     berarti ia tidak menyunting apa pun dan setiap")
            print("     keadaan akan «lulus» tanpa menguji apa pun.")
            return 1

    #: (nama, [(path, teks_mutasi)], harap)
    keadaan: list[tuple[str, list[tuple[str, str]], int]] = []

    # 1. Cacat intinya: kunci tab dihapus dari katalog.
    keadaan.append((
        "katalog: kunci 'Experiment 1' dihapus (tab tanpa terjemahan)",
        [(CATALOG, teks_katalog.replace(KEY_EXPERIMENT, ""))],
        1))

    # 2. Cacat yang sama di berkas lain — gerbang harus memindai seluruh Apps/.
    keadaan.append((
        "katalog: kunci 'Point & Know' dihapus (complication tanpa terjemahan)",
        [(CATALOG, teks_katalog.replace(KEY_POINT_AND_KNOW, ""))],
        1))

    # 3. Arah yang paling penting: teks yang **belum pernah** ada.
    keadaan.append((
        "view: Label(\"Teks Tanpa Kunci\") baru disisipkan",
        [(DIAGNOSTICS, teks_diag.replace(
            INSERT_ANCHOR,
            INSERT_ANCHOR + '\n        Label("Teks Tanpa Kunci", systemImage: "star")'
            " .hidden()"))],
        1))

    # 4. Kontrol negatif: kunci kosong bukan teks yang perlu diterjemahkan.
    keadaan.append((
        "view: Label(\"\") kosong (harus HIJAU)",
        [(DIAGNOSTICS, teks_diag.replace(
            INSERT_ANCHOR,
            INSERT_ANCHOR + '\n        Label("", systemImage: "star").hidden()'))],
        0))

    # 5. Teks dinamis dan verbatim tidak bisa punya kunci katalog.
    keadaan.append((
        "view: Label(verbatim:) & Label(teksDinamis) (harus HIJAU)",
        [(DIAGNOSTICS, teks_diag.replace(
            INSERT_ANCHOR,
            INSERT_ANCHOR + '\n        Label(verbatim: "Bukan kunci", '
            'systemImage: "star").hidden()'
            '\n        Label(namaDinamis, systemImage: "star").hidden()'))],
        0))

    # 6. Interpolasi: literalnya ada, isinya berjalan.
    keadaan.append((
        'view: Label("\\(nama)") berinterpolasi (harus HIJAU)',
        [(DIAGNOSTICS, teks_diag.replace(
            INSERT_ANCHOR,
            INSERT_ANCHOR + '\n        Label("\\(namaDinamis)", '
            'systemImage: "star").hidden()'))],
        0))

    # 7. Fail-closed: katalog tanpa kunci sama sekali.
    keadaan.append((
        "katalog: dikosongkan (fail-closed)",
        [(CATALOG, '{\n  "sourceLanguage": "id",\n  "strings": {},\n'
                   '  "version": "1.0"\n}\n')],
        1))

    # 8. Kontrol positif: dokumentasi yang menyebut bentuk terlarang tetap
    #    hijau. Gerbang yang merah atas komentar akan dimatikan orang.
    keadaan.append((
        'view: komentar menyebut Label("Teks Tanpa Kunci") (harus HIJAU)',
        [(DIAGNOSTICS, teks_diag.replace(
            INSERT_ANCHOR,
            INSERT_ANCHOR + '\n        // Jangan tulis Label("Teks Tanpa Kunci",'
            ' systemImage: "star") di sini.'))],
        0))

    # 9. Satu berkas dikosongkan: 28 berkas lain masih dipindai, jadi gerbang
    #    harus tetap **hijau** dan tidak boleh melempar. Ini kontrol negatif
    #    terhadap gerbang yang membaca satu berkas saja.
    keadaan.append((
        "satu berkas Swift dikosongkan (28 lain tetap dipindai, harus HIJAU)",
        [(DIAGNOSTICS, "")],
        0))

    # 10. Cakupan **nol**: seluruh berkas Swift dikosongkan. Gerbang yang
    #     tidak menemukan subjeknya sudah berhenti mengukur, dan hijau atas
    #     nol berkas adalah bentuk paling sunyi dari gerbang yang tidak
    #     mengukur apa pun. Harus MERAH.
    semua_swift = sorted(glob.glob(os.path.join(ROOT, "Apps", "**", "*.swift"),
                                   recursive=True))
    keadaan.append((
        f"seluruh {len(semua_swift)} berkas Swift dikosongkan (cakupan nol, "
        "fail-closed)",
        [(path, "") for path in semua_swift],
        1))

    hasil: list[tuple[str, bool, str]] = []

    kode, keluaran = jalankan()
    if kode != 0:
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
                l.strip() for l in keluaran.splitlines()
                if l.strip().startswith("FAIL"))[:300]
        hasil.append((nama, kode == harap, f"exit={kode} (harap {harap}){sebab}"))

    pulih = (open(CATALOG, "rb").read() == asli_katalog
             and open(DIAGNOSTICS, "rb").read() == asli_diag
             and open(COMPLICATION, "rb").read() == asli_comp)
    hasil.append(("sumber produksi pulih byte-per-byte", pulih,
                  "identik" if pulih else "BERBEDA — pulihkan manual"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'OK  ' if lolos else 'FAIL'} {nama} — {detail}")

    print()
    if gagal:
        print(f"Aturan 107: {len(gagal)} dari {len(hasil)} keadaan tidak sesuai.")
        return 1
    print(f"Aturan 107: {len(hasil)} keadaan sesuai harapan — teks tampil yang "
          f"lupa didaftarkan tidak bisa kembali hilang dari katalog tanpa "
          f"gerbang merah, sementara teks dinamis, interpolasi, dan komentar "
          f"tetap hijau.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
