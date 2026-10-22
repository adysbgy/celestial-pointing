#!/usr/bin/env python3
"""Aturan 96: skalar yang DIHITUNG dari model wajib juga DIPAKAI sebagai nilai.

Kenapa aturan ini ada.

`CelestialVisualView.swift` menghitung 21 nilai dari model (`CelestialVisual.*`)
lalu menggambarnya: kekuatan earthshine, opasitas tepi tudung kutub, warna pita,
indeks warna bintang. Pola yang berulang di repo ini adalah **nilai yang
dihitung, diperiksa, lalu tidak dipakai** — dan setiap gerbang yang ada tetap
hijau, karena semuanya mengukur hal lain:

  - `check_earthshine_strength_matches_the_model` (di `check-visuals.py`)
    memeriksa bahwa view **memanggil** `CelestialVisual.earthshineStrength(`.
    Ia tidak memeriksa apakah hasilnya sampai ke `.opacity(...)`. Terukur:
    `.opacity(earthshine)` diganti `.opacity(1)` atau `.opacity(0.5)` →
    **0 merah** di `swift-ui-lint.sh` dan **0 merah** di seluruh gerbang
    Bulan. Yang tinggal hanya `if earthshine > 0` di atasnya, jadi gerbang
    teks pun puas: nama fungsinya masih ada di berkas.
  - Gerbang piksel (`check-visuals.py`) mengukur **port Python**, bukan view.
    Port tetap benar, jadi tidak ada piksel yang berubah.
  - Compiler diam: `.opacity(1)` sah, dan `earthshine` tetap "terpakai"
    karena muncul di `if earthshine > 0`.
  - Teks di layar tidak berubah.

Bentuk cacatnya persis kelas yang sudah berulang di repo ini: **nilai yang
tidak pernah diperiksa adalah nilai yang boleh berarti apa saja.** Bedanya
dengan Aturan 95 hanya letaknya — yang satu opasitas animasi, yang satu
opasitas gambar.

Yang diperiksa.

Untuk setiap `let NAMA = CelestialVisual.<fungsi>(` di view, hitung
kemunculan `NAMA` sesudah deklarasinya, lalu klasifikasikan tiap kemunculan:

  * **nilai** — dipakai sebagai argumen panggilan (`(NAMA`, `, NAMA`),
    anggota (`NAMA.`), atau operand aritmetika (`NAMA *`, `- NAMA`).
  * **syarat** — hanya dibandingkan/diuji (`if NAMA`, `NAMA >`, `!NAMA`).

Aturannya: **minimal satu kemunculan bernilai**. Skalar yang hanya muncul
sebagai syarat berarti ia dipakai untuk memutuskan *apakah* menggambar, dan
yang digambar adalah angka lain — persis mutasi yang lolos seluruh gerbang
di atas.

Kenapa bukan "setiap kemunculan wajib bernilai": satu nilai sah dipakai
berkali-kali sebagai syarat juga (`if fade.edgeOpacity > 0`). Yang dilarang
adalah **tidak pernah** sampai ke gambar.

Kenapa nol temuan = GAGAL: kalau pola `let NAMA = CelestialVisual.` hilang
seluruhnya (mis. view dipecah), aturan ini berhenti mengukur tanpa berbunyi.
Aturan yang diam karena tidak menemukan apa-apa lebih berbahaya daripada
tidak ada aturan.

Batasnya jujur: ini sapuan **teks**, bukan render. Ia tidak bisa membuktikan
bahwa `earthshine` terasa pas di layar 38 pt, dan tidak bisa membuktikan
SwiftUI menggambar `.opacity(earthshine)` sebagaimana dimaksud. Yang
dibuktikan: nilai yang dihitung dari model benar-benar muncul di posisi nilai,
bukan diganti literal. Kebenaran rumusnya sendiri dijaga uji Swift di Linux
(`testEarthshineOnlyOnPartiallyLitMoon`) dan gerbang piksel port.
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW = "Apps/Shared/CelestialVisualView.swift"

#: Pola deklarasi: `let nama = CelestialVisual.sesuatu(`
DEKLARASI = re.compile(r"\blet\s+([A-Za-z_]\w*)\s*=\s*CelestialVisual\.(\w+)\s*\(")

#: Operator pembanding — kemunculan sesudahnya adalah **syarat**, bukan nilai.
PEMBANDING = ("<", ">", "==", "!=", "<=", ">=")


def strip_komentar(source: str) -> str:
    """Buang komentar `//` supaya nama di prosa tidak dihitung sebagai kode."""
    return re.sub(r"//[^\n]*", "", source)


def kemunculan(source: str, nama: str, mulai: int):
    """Posisi setiap kemunculan `nama` sesudah `mulai`, sebagai (indeks, teks)."""
    pola = re.compile(r"\b" + re.escape(nama) + r"\b")
    return [(m.start(), m.group(0)) for m in pola.finditer(source, mulai)]


def klasifikasi(source: str, posisi: int, nama: str) -> str:
    """`nilai` bila dipakai sebagai nilai, `syarat` bila hanya diuji."""
    sebelum = source[max(0, posisi - 40):posisi]
    sesudah = source[posisi + len(nama):posisi + len(nama) + 40]

    # Anggota: `NAMA.sesuatu`
    if sesudah.startswith("."):
        return "nilai"

    # Syarat: `if NAMA`, `guard NAMA`, `!NAMA`, atau `NAMA <op> ...`
    if re.search(r"\b(if|guard|while)\s*$", sebelum):
        return "syarat"
    if sebelum.rstrip().endswith("!"):
        return "syarat"
    for op in PEMBANDING:
        if sesudah.lstrip().startswith(op):
            return "syarat"
    for op in PEMBANDING:
        if sebelum.rstrip().endswith(op):
            return "syarat"

    # Nilai: argumen panggilan, anggota, subskrip, cabang ternary, atau
    # operand aritmetika. `upperColour` dipakai sebagai cabang ternary
    # (`stop.location < 0.5 ? upperColour : lowerColour`) dan `relief`
    # sebagai subskrip (`relief[index]`) — keduanya posisi nilai, dan versi
    # pertama aturan ini salah menyebutnya "syarat".
    if re.search(r"[(,]\s*$", sebelum):
        return "nilai"
    if sesudah.lstrip()[:1] in (".", "[", "?", ":", ",", ")"):
        return "nilai"
    if sebelum.rstrip()[-1:] in ("?", ":", "=") or re.search(r"[+\-*/]\s*$", sebelum):
        return "nilai"
    if sesudah.lstrip()[:1] in ("+", "-", "*", "/"):
        return "nilai"
    if sebelum.rstrip().endswith("return"):
        return "nilai"

    return "lain"


def main() -> int:
    path = os.path.join(ROOT, VIEW)
    try:
        source = strip_komentar(open(path, encoding="utf-8").read())
    except OSError as exc:
        print(f"FAIL {VIEW} tidak terbaca: {exc}")
        return 1

    deklarasi = list(DEKLARASI.finditer(source))
    if not deklarasi:
        print("FAIL tidak ada satu pun `let NAMA = CelestialVisual.…(` di view.")
        print("     Aturan 96 berhenti mengukur, dan skalar yang dihitung dari")
        print("     model bisa diganti literal tanpa satu pun gerbang berbunyi.")
        return 1

    gagal = []
    for m in deklarasi:
        nama, fungsi = m.group(1), m.group(2)
        semua = kemunculan(source, nama, m.end())
        if not semua:
            gagal.append(f"{nama} = CelestialVisual.{fungsi}(…) tidak dipakai "
                         f"sama sekali sesudah dihitung")
            continue
        jenis = [klasifikasi(source, p, nama) for p, _ in semua]
        if "nilai" not in jenis:
            hitung = jenis.count("syarat")
            gagal.append(
                f"{nama} = CelestialVisual.{fungsi}(…) hanya muncul sebagai "
                f"syarat ({hitung}×), tidak pernah sebagai nilai — angka yang "
                f"digambar adalah literal lain")

    if gagal:
        for baris in gagal:
            print(f"FAIL {baris}")
        print("-> Setiap skalar yang dihitung dari model wajib sampai ke posisi")
        print("   nilai (argumen/anggota/operand), bukan diganti literal di")
        print("   tempat menggambar. Perbaiki view-nya, jangan longgarkan")
        print("   aturannya.")
        return 1

    print(f"OK {len(deklarasi)} skalar model dipakai sebagai nilai "
          f"(bukan hanya syarat) di {VIEW}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
