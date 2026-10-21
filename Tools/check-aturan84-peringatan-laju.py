#!/usr/bin/env python3
"""Aturan 84: peringatan "terlalu cepat" dan keadaan kalibrasi tidak boleh dibuang.

Aturan ini ditulis SETELAH disapu, bukan sebelum. Tujuh mutasi di
`Apps/PointAndKnowWatch/Sources/PointingView.swift` dijalankan pada salinan
pohon utuh di proses baru, masing-masing dengan `swift-ui-lint.sh` +
`swift-typecheck.sh`. Empat lolos **seluruh 83 aturan**:

    aksen kartu: `if state == .lock`  -> `if true`              HIJAU
    ikon kalibrasi: scope/seru dibalik                          HIJAU
    ambang laju:  `rate >  max`       -> `rate >= max`          HIJAU
    ambang laju:  `let tooFast = ...` -> `let tooFast = false`  HIJAU

(`isStale: false`, `nightMode.toggle()`, dan `audioCueEnabled.toggle()` memang
tertangkap — yang pertama oleh Aturan 35, dua sisanya oleh Aturan 66.)

Dua yang paling berbahaya adalah `tooFast`:

  * `let tooFast = false` mematikan satu-satunya peringatan di layar yang
    memberi tahu bahwa arah tunjuk **belum boleh dipercaya**. Kartu tetap
    menampilkan angka laju, tetap berwarna normal, tetap mengucapkan panduan
    "arahkan jam" — dan pengguna menunjuk langit sambil percaya pada hipotesis
    yang sedang dinyatakan tidak sah oleh perangkatnya sendiri.
  * `>=` menggantikan `>` adalah cacat satu-satuan yang lebih sunyi: pada
    tepat ambang, peringatan muncul (atau hilang) bertentangan dengan
    `maxAngularRateDegPerSec` yang sudah diuji di Linux.

Ini bukan soal gaya. Aturan keras PRD v0.4 adalah **uncertainty > false
confidence**; peringatan laju adalah tempat aturan itu menyentuh layar.

Cacat ikon kalibrasi berkelas sama dengan yang sudah ditutup Aturan 61 untuk
`foregroundStyle`: bentuk ikon adalah pembeda **kedua** setelah warna. Kalau
bentuknya dibalik, satu-satunya kanal yang tersisa bagi pengguna buta warna
adalah `accessibilityLabel` — dan itu hanya sampai ke pembaca layar, bukan ke
mata yang sedang menunjuk langit.

Yang diperiksa, dan kenapa bentuknya begitu:

  1. `tooFast` di `PointingView` dibandingkan dengan **`>`** terhadap
     `maxAngularRateDegPerSec` dari cuplikan engine — bukan literal, bukan
     `>=`, bukan `false`. Ambangnya sendiri sudah dijaga di Linux; yang tidak
     terjaga adalah apakah layar masih memakainya.
  2. Setiap `if tooFast` yang memuat teks peringatan harus tetap ada: cabang
     `if tooFast { Text(...) }` tidak boleh hilang atau dibalik jadi
     `if !tooFast`. Kalau tidak ada satu pun cabang yang menampilkan kata,
     peringatan itu tidak sampai ke layar.
  3. Ikon kalibrasi: `isCalibrated` benar → `"scope"`, salah →
     `"exclamationmark.circle"`. Arahnya dituntut, bukan hanya keberadaan
     kedua nama — membalik keduanya tetap memakai kedua nama.
  4. Angka yang **digambar** harus `rate`, argumen yang sama dengan yang
     dibandingkan di (1). Diperiksa karena probe menemukan `degreesPerSecond(0)`
     dan `degreesPerSecond(maxAngular)` lolos seluruh 83 aturan **dan** aturan
     ini: peringatan tetap benar, tetapi angka di layar bukan laju yang
     diperingatkan. Dua kanal, dua nilai — kelas cacat yang berulang di proyek
     ini.
  5. Warna peringatan: ternary `tooFast ? PointingTone.warning.color : ...`
     dan `foregroundStyle` di cabang `if tooFast` harus tetap
     `PointingTone.warning.color`. Menggantinya dengan warna sekunder membuat
     kata peringatan ada tetapi tidak ada satu pun sinyal yang menonjol —
     hijau di seluruh gerbang.
  6. Kata di cabang `if tooFast` harus `TextLocalization.text(.pointingRateTooFast)`,
     bukan literal bebas. `Text("")` dan `Text("aman")` sama-sama lolos aturan
     versi pertama (pembersih string mengosongkan keduanya); kunci katalog
     mengikat kata itu ke string yang sudah dimiliki gerbang lokalisasi.

Fail-closed: kalau berkas atau cabangnya tidak terbaca, aturan ini GAGAL.
Hijau yang berarti "tidak ada yang diperiksa" adalah kegagalan yang aturan ini
ada untuk mencegah.

Yang TIDAK diklaim: ini pemeriksaan **teks**. Ia tidak menjalankan SwiftUI,
tidak tahu apakah `tooFast` benar-benar sampai ke `HStack` yang tampil, dan
tidak mengukur apakah peringatan itu terbaca di layar 41mm. Angka yang
diperiksa adalah **argumen yang tertulis di sumber**, bukan nilai yang
dirender: `degreesPerSecond(rate * 0)` lolos, karena bentuk itu tidak bisa
dibedakan dari kode yang benar tanpa menjalankan Swift. Aksen kartu
(`if state == .lock`) juga **tidak** diperiksa di sini: ia hiasan, bukan
kejujuran, dan memberinya gerbang akan menyamakan bobotnya dengan peringatan
yang menyangkut keselamatan pengamatan.
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW = os.path.join(ROOT, "Apps/PointAndKnowWatch/Sources/PointingView.swift")


def kode_saja(teks: str) -> str:
    """Buang komentar dan isi string.

    Keduanya tidak menjalankan apa pun. Berkas ini dan `PointingView.swift`
    sama-sama mendokumentasikan bentuk yang salah panjang lebar; tanpa
    pembersihan ini, komentar penjelas akan memuaskan aturannya sendiri.
    """
    teks = re.sub(r"/\*.*?\*/", "", teks, flags=re.S)
    teks = re.sub(r"//[^\n]*", "", teks)
    return teks


def kode_tanpa_string(teks: str) -> str:
    """Buang komentar **dan** isi string."""
    return re.sub(r'"(?:[^"\\]|\\.)*"', '""', kode_saja(teks))


def main() -> int:
    if not os.path.exists(VIEW):
        print(f"FAIL {os.path.relpath(VIEW, ROOT)} tidak ada: aturan ini tidak "
              f"mengukur apa pun.")
        return 1

    kode = kode_saja(open(VIEW, encoding="utf-8").read())
    # `systemName:` dibaca dari kode **dengan** string utuh: nama SF Symbol
    # adalah isi string, jadi pembersih string akan menghapus justru nilai
    # yang diperiksa. Komentar tetap dibuang — berkas ini mendokumentasikan
    # bentuk yang salah, dan tanpa pembersihan komentar, aturannya memuaskan
    # dirinya sendiri.
    kode_berstring = kode
    kode = kode_tanpa_string(kode)
    masalah = []

    # (1) Ambang laju: `>` terhadap ambang dari cuplikan, bukan literal.
    ambang = re.search(
        r"let\s+tooFast\s*=\s*([^\n]*)", kode)
    if ambang is None:
        masalah.append(
            "FAIL `let tooFast = ...` tidak ada di PointingView: peringatan "
            "laju tidak lagi diputuskan di layar yang menampilkannya.")
    else:
        expr = " ".join(ambang.group(1).split())
        # `>(?!=)` bukan `>`: tanpa lookahead, `rate >= ...` cocok karena
        # `>` adalah awalan `>=`. Terukur: mutasi `>` -> `>=` tetap hijau
        # pada versi pertama aturan ini — cacat satu-satuan yang justru
        # menjadi alasan aturan ini ditulis.
        if not re.search(r"\brate\s*>(?!=)\s*[^\n]*maxAngularRateDegPerSec", expr):
            masalah.append(
                f"FAIL `tooFast` bukan `rate > ...maxAngularRateDegPerSec` "
                f"({expr!r}): ambang yang diuji di Linux harus tetap dipakai "
                f"layar, dan `>=`/literal/`false` mengubah kapan peringatan "
                f"muncul.")

    # (2) Cabang peringatan harus menampilkan kata, dan tidak dibalik.
    cabang = re.findall(r"if\s+(!?)\s*tooFast\s*\{([^}]*)\}", kode, re.S)
    if not cabang:
        masalah.append(
            "FAIL tidak ada `if tooFast { ... }`: peringatan \"terlalu cepat\" "
            "tidak sampai ke layar sama sekali.")
    else:
        benar = [isi for negasi, isi in cabang if negasi == ""]
        salah = [isi for negasi, isi in cabang if negasi == "!"]
        if not any(re.search(r"Text\s*\(", isi) for isi in benar):
            masalah.append(
                "FAIL cabang `if tooFast` tidak menampilkan `Text(...)`: "
                "warnanya saja bukan peringatan yang bisa dibaca tanpa warna "
                "(kelas yang ditutup Aturan 61).")
        if salah:
            masalah.append(
                "FAIL ada `if !tooFast`: cabang terbalik menampilkan "
                "peringatan justru saat laju aman, dan menyembunyikannya saat "
                "laju terlalu cepat.")

    # (3) Ikon kalibrasi: arahnya, bukan hanya kedua nama.
    #
    # Jendelanya dua baris, seperti ternary di view: `isCalibrated` ada di
    # baris pertama dan kedua nama SF Symbol di baris berikutnya. Versi
    # pertama aturan ini memakai `[^\n]*` dan karena itu hanya membaca
    # `engine.snapshot.isCalibrated` — aturan menuduh kode yang benar.
    ikon = re.search(r"systemName\s*:\s*([^)]{0,200}isCalibrated[^)]{0,200})\)",
                     kode_berstring, re.S)
    if ikon is None:
        masalah.append(
            "FAIL ikon kalibrasi tidak membaca `isCalibrated` di "
            "`systemName:`: keadaan kalibrasi kehilangan pembeda bentuknya.")
    else:
        expr = " ".join(ikon.group(1).split())
        scope_dulu = re.search(
            r'isCalibrated\s*\?\s*"scope"\s*:\s*"exclamationmark\.circle"',
            expr)
        if not scope_dulu:
            masalah.append(
                f"FAIL ikon kalibrasi bukan `isCalibrated ? \"scope\" : "
                f"\"exclamationmark.circle\"` ({expr!r}): bentuk terbalik "
                f"membuat jam yang belum terkalibrasi terlihat siap dipakai.")

    # (4)-(5) Angka dan warna: kanal yang tampil, bukan hanya ambangnya.
    #
    # Probe menemukan tiga mutasi yang lolos seluruh 83 aturan: angka diganti
    # `0`, angka diganti properti lain, dan warna peringatan diganti warna
    # sekunder. Ketiganya mempertahankan ambang yang benar di (1) — jadi
    # peringatan tetap "ada", tetapi angka yang dibaca pengguna bukan laju
    # yang diperingatkan, dan tidak ada sinyal yang menonjol.
    if "let tooFast" in kode:
        awal = kode.index("let tooFast")
        akhir = kode.find("if tooFast", awal)
        if akhir == -1:
            akhir = len(kode)
        kanal = kode[awal:akhir]
        angka = re.findall(r"degreesPerSecond\s*\(\s*([^,)]*)", kanal)
        if not angka:
            masalah.append(
                "FAIL tidak ada `NumberFormat.degreesPerSecond(...)` di antara "
                "`let tooFast` dan `if tooFast`: peringatan membandingkan laju "
                "yang tidak ditampilkan.")
        else:
            salah = [a.strip() for a in angka if a.strip() != "rate"]
            if salah:
                masalah.append(
                    f"FAIL angka laju digambar dari {salah!r}, bukan `rate`: "
                    f"angka di layar bukan laju yang diperingatkan (dua kanal, "
                    f"dua nilai).")
        if not re.search(r"tooFast\s*\?\s*PointingTone\.warning\.color", kanal):
            masalah.append(
                "FAIL angka tidak memakai `tooFast ? PointingTone.warning.color "
                ": ...`: laju terlalu cepat terlihat sama dengan laju aman.")

    # (6) Kata peringatan harus dari katalog, bukan literal.
    #
    # `kode_tanpa_string` mengosongkan isi string, jadi `Text("")` dan
    # `Text("aman")` sama-sama menjadi `Text("")` — itulah sebabnya versi
    # pertama aturan ini meloloskan keduanya.
    if cabang:
        benar = [isi for negasi, isi in cabang if negasi == ""]
        for isi in benar:
            if not re.search(r"Text\s*\(\s*TextLocalization\.text\s*\(\s*"
                             r"\.pointingRateTooFast\s*\)", isi):
                masalah.append(
                    "FAIL cabang `if tooFast` tidak memakai "
                    "`TextLocalization.text(.pointingRateTooFast)`: kata "
                    "peringatan bebas literal bisa berbunyi apa saja, termasuk "
                    "kosong atau \"aman\", dan gerbang lokalisasi tidak "
                    "menjangkaunya.")
            if not re.search(r"foregroundStyle\s*\(\s*PointingTone\.warning\.color",
                             isi):
                masalah.append(
                    "FAIL kata peringatan tidak memakai "
                    "`foregroundStyle(PointingTone.warning.color)`: warnanya "
                    "menjadi sama dengan teks sekunder, sehingga peringatan "
                    "hanya berbeda dari angka biasa oleh satu kata kecil.")

    if masalah:
        print("\n".join(masalah))
        return 1

    print("Bersih: peringatan laju memakai ambang engine dengan `>`, cabangnya "
          "menampilkan kata,\n        dan ikon kalibrasi memetakan "
          "isCalibrated -> scope.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
