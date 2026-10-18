#!/usr/bin/env python3
"""Buktikan Aturan 52 menutup **jalur kartu jam**, bukan hanya pemanggil
langsungnya.

Kenapa berkas ini ada
=====================

Aturan 52 menuntut setiap pemanggil yang meneruskan keyakinan engine ke gambar
membacanya **langsung** (`engine.confirmsDisplayedIdentity` atau parameter
`isConfirmed`), bukan lewat nama yang di `Apps/` bisa berarti apa saja.

`SITUS`-nya menyebut tiga nama: `CelestialVisualView(`, `LockArrivalPanel(`,
`ObjectDetailView(`. Ketiganya benar, dan ketiganya sudah dijaga.

**Yang tidak disebut adalah pembungkus yang berdiri di antaranya.**
`PulsingCelestialVisual` (kartu jam, `PointingView.swift`) menerima
`isConfirmed` lalu meneruskannya ke **dua** pemanggilan `CelestialVisualView`
di dalamnya — satu di jalur berdenyut, satu di jalur diam. Ia tidak
menggambar apa pun sendiri; seluruh gunanya meneruskan. Karena namanya tidak
ada di `SITUS`, satu-satunya tempat keyakinan masuk ke kartu jam **tidak
diperiksa siapa pun**.

Cacatnya terukur, bukan hipotetis. Pada pohon utuh, salinan penuh, proses
baru, dengan `swift-ui-lint.sh` di `HEAD`:

    PointingView.swift:  isConfirmed: isConfirmed,  ->  isConfirmed: true
                         (pada pemanggilan `PulsingCelestialVisual`)
                         -> exit 0, "SEMUA GERBANG UI LULUS"

Baris itu **mengompilasi**, dan akibatnya persis yang dilarang PRD: saat
engine berkeadaan `.uncertain`, kartu jam menggambar cincin Saturnus dan pita
Jupiter — ciri pengenal yang mengklaim identitas — sementara badge di
sebelahnya bertuliskan "Ragu". Enam aturan lain (18, 32, 34, 50, 51, 52)
tetap hijau, karena semuanya memeriksa **pemanggil yang mereka kenal**;
pembungkus ini bukan salah satunya.

Mengapa tidak tertangkap Aturan 34/50/51
========================================

  * Aturan 34 menuntut argumen `isConfirmed:` **ada** pada pemanggilan yang
    dikenal. Di sini ia ada, dan nilainya bahkan bernama benar.
  * Aturan 50 menjaga `Palette.drawable(isConfirmed:)` di dalam penggambar.
    Penggambar tidak berubah — yang berubah hanya nilai yang sampai ke sana.
  * Aturan 51 menjaga saputangan yang mengklaim identitas membaca keyakinan.
    Sama: di dalam `CelestialVisualView`, dan di sana ia benar.

Yang hilang adalah satu simpul di rantai, dan tidak ada gerbang yang membaca
rantai itu sebagai rantai.

Keadaan yang diuji
==================

  1. kartu jam: `PulsingCelestialVisual` menerima literal `true`   MERAH
  2. kartu jam: keyakinan lewat nama perantara di kartu            MERAH
  3. panel jam (`ObjectDetailView`): literal `true`                MERAH
        (sudah dijaga hari ini — keadaan ini menjaga agar perluasan `SITUS`
        tidak diam-diam menghapus cakupan yang sudah ada)
  4. kontrol negatif: pohon apa adanya                             hijau
  5. kontrol negatif: parameter `isConfirmed` diteruskan apa adanya hijau

Arah kedua
==========

Keempat keadaan cacat dijalankan lagi atas lint **pra-perbaikan**, dibaca dari
`git show` (bukan dikarang), dan wajib HIJAU di sana. Tanpa arah ini, "aturan
berbunyi" hanya klaim: merah bisa datang dari sebab lain yang kebetulan
berubah bersamaan.

Yang TIDAK dibuktikan
=====================

Ini sapu teks atas **nama pemanggil**. Pembungkus baru yang meneruskan
keyakinan tidak tertangkap sampai namanya ditambahkan ke `SITUS` — dan itu
satu-satunya cara lubang ini kembali. Yang dijaga di sini adalah bahwa
pembungkus yang **sudah ada** tidak bisa lagi melemahkan keyakinan tanpa
gerbang berbunyi.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
WATCH = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "PointingView.swift")

RULE_HEADER = "== Aturan 52:"
CLEAN_MARK = "Bersih: setiap gambar membaca keyakinan engine secara langsung."

#: Jangkar: pemanggilan pembungkus di kartu jam. Wajib muncul tepat sekali.
KARTU_BENAR = """                PulsingCelestialVisual(visual: visual,
                                       diameter: visualDiameter,"""

#: Cacat 1: keyakinan dipaksa yakin tepat di simpul yang tidak dijaga.
KARTU_SALAH = """                PulsingCelestialVisual(visual: visual,
                                       diameter: visualDiameter,"""

#: Baris `isConfirmed:` milik kartu (indentasi 39 spasi) — berbeda dari milik
#: `ObjectDetailView` (41 spasi) dan `CelestialVisualView` di dalam pembungkus
#: (40 spasi). Dipakai untuk mengganti **hanya** yang di kartu.
KARTU_NILAI = "                                       isConfirmed: isConfirmed,\n                                       motion: motion)"
KARTU_NILAI_SALAH = "                                       isConfirmed: true,\n                                       motion: motion)"

#: Keadaan terpenting: pembungkus yang **belum pernah ada** saat aturan ini
#: ditulis, dan tidak pernah masuk daftar nama mana pun. Kalau keadaan ini
#: hijau, daftar situsnya masih ditulis tangan dan lubangnya akan kembali
#: bersama pembungkus berikutnya.
#:
#: Bentuknya **dua tingkat**, dan itu bukan hiasan. Percobaan pertama memakai
#: satu pembungkus yang langsung memanggil `CelestialVisualView(...,
#: isConfirmed: true)`; arah kedua memerah, karena `CelestialVisualView` sudah
#: ada di daftar lama — jadi keadaan itu tidak membuktikan apa pun tentang
#: derivasi. Di sini `PembungkusBaru` meneruskan keyakinan **dengan benar**
#: (jadi aturan lama hijau), dan yang berbuat salah adalah pemanggilnya
#: (`PembungkusLuar`), yang tidak pernah terdaftar di daftar tangan mana pun.
PEMBUNGKUS_BARU = """struct PembungkusLuar: View {
    var body: some View {
        PembungkusBaru(isConfirmed: true)
    }
}

struct PembungkusBaru: View {
    let isConfirmed: Bool
    var body: some View {
        CelestialVisualView(visual: CelestialVisual(kind: .star),
                            diameter: 10,
                            isConfirmed: isConfirmed)
    }
}

struct PulsingCelestialVisual: View {"""

PEMBUNGKUS_BARU_JANGKAR = "struct PulsingCelestialVisual: View {"

#: Cacat 2: nama perantara yang tidak menyebut fakta keyakinan.
KARTU_PERANTARA = ("                                       isConfirmed: keyakinan,\n"
                   "                                       motion: motion)")

#: Cacat 3: panel jam (`ObjectDetailView`) — sudah dijaga hari ini.
PANEL_BENAR = "                                         isConfirmed: engine.confirmsDisplayedIdentity,"
PANEL_SALAH = "                                         isConfirmed: true,"

#: Sah: parameter diteruskan apa adanya (bentuk yang dipakai hari ini).
PARAMETER_SAH = ("                                       isConfirmed: isConfirmed,\n"
                 "                                       motion: motion)")

#: Arah kedua memakai **lint pra-perbaikan yang berbeda per keadaan**, karena
#: tiap keadaan menutup lubang yang lahir pada waktu berbeda. Memakai satu
#: revisi untuk semuanya membuat keadaan 3 "merah" di arah kedua — panel jam
#: memang sudah dijaga sejak `29ca41b`, jadi revisi itu bukan pra-perbaikan
#: bagi keadaan 3, melainkan sesudahnya.
#:
#:   keadaan 1 & 2 -> lint di `HEAD` hari ini (sebelum `SITUS` diperluas)
#:   keadaan 3     -> lint sebelum `29ca41b` (sebelum panel ikut dijaga)
PRA_KEADAAN_3 = "29ca41b^"

STATES = [
    ("1 kartu jam: pembungkus menerima literal `true`", True),
    ("2 kartu jam: keyakinan lewat nama perantara", True),
    ("3 panel jam: literal `true` (cakupan lama)", True),
    ("4 kontrol negatif: pohon apa adanya", False),
    ("5 kontrol negatif: parameter diteruskan apa adanya", False),
]


def _baca_lint_dari(rev):
    hasil = subprocess.run(["git", "show", f"{rev}:swift-ui-lint.sh"],
                           cwd=ROOT, capture_output=True, text=True)
    if hasil.returncode != 0:
        return None
    return hasil.stdout


def _program_aturan52(teks_lint):
    awal = teks_lint.find("# ── Aturan 52")
    if awal < 0:
        return None
    # Batas akhir dicari sebagai **aturan berikutnya**, bukan nama tetap
    # `Aturan 53`: pada revisi lama aturan 53 belum ada, dan memakai nama
    # tetap membuat arah kedua gagal terbaca justru pada revisi yang paling
    # dibutuhkan.
    sisa = teks_lint[awal + 10:]
    akhir = -1
    for penanda in ("# ── Aturan 53", "# ── Aturan ", 'if [ "$status" -eq 0 ]; then'):
        pos = sisa.find(penanda)
        if pos >= 0 and (akhir < 0 or pos < akhir):
            akhir = pos
    if akhir < 0:
        return None
    return teks_lint[awal:awal + 10 + akhir]


def _jalankan(program):
    """Jalankan blok aturan sebagai skrip bash, kembalikan (menyala, keluaran).

    Blok itu memakai `status=1` (variabel lint), jadi ia dijalankan sebagai
    potongan skrip dengan `status=0` di depannya — persis seperti di dalam
    `swift-ui-lint.sh`.
    """
    skrip = "status=0\n" + program + "\nprintf 'STATUS:%s\\n' \"$status\"\n"
    hasil = subprocess.run(["bash", "-s"], cwd=ROOT, input=skrip,
                           capture_output=True, text=True, timeout=600)
    if hasil.returncode != 0:
        return None, (hasil.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    menyala = "STATUS:1" in hasil.stdout
    return menyala, hasil.stdout.strip()


def main():
    mutasi_sumber.require_clean_sources([WATCH])
    asli = open(WATCH, encoding="utf-8").read()

    for nama, jangkar in (("KARTU_BENAR", KARTU_BENAR),
                          ("KARTU_NILAI", KARTU_NILAI),
                          ("PANEL_BENAR", PANEL_BENAR)):
        jumlah = asli.count(jangkar)
        if jumlah != 1:
            print(f"GERBANG: jangkar {nama} muncul {jumlah}x, harus 1 -- "
                  "harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    lint_sekarang = open(LINT, encoding="utf-8").read()
    program = _program_aturan52(lint_sekarang)
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 52 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    induk = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                           capture_output=True, text=True).stdout.strip()
    lint_lama = _baca_lint_dari(induk)
    program_lama = _program_aturan52(lint_lama) if lint_lama else None
    lint_lama3 = _baca_lint_dari(PRA_KEADAAN_3)
    program_lama3 = _program_aturan52(lint_lama3) if lint_lama3 else None
    if program_lama is None or program_lama3 is None:
        print("GERBANG: lint pra-perbaikan tidak terbaca -- arah kedua tidak "
              "bisa dijalankan.", file=sys.stderr)
        sys.exit(2)

    # (label, mutasi) — mutasi: daftar (cari, ganti)
    def mutasi_kartu(nilai_baru):
        return [(KARTU_NILAI, nilai_baru)]

    kasus = [
        ("1 kartu jam: pembungkus menerima literal `true`",
         mutasi_kartu(KARTU_NILAI_SALAH)),
        ("2 kartu jam: keyakinan lewat nama perantara",
         [(KARTU_BENAR,
           "                let keyakinan = true\n" + KARTU_BENAR),
          (KARTU_NILAI, KARTU_PERANTARA)]),
        ("3 panel jam: literal `true` (cakupan lama)",
         [(PANEL_BENAR, PANEL_SALAH)]),
        ("4 pembungkus BARU yang tidak terdaftar: literal `true`",
         [(PEMBUNGKUS_BARU_JANGKAR, PEMBUNGKUS_BARU)]),
        ("5 kontrol negatif: pohon apa adanya", []),
        ("6 kontrol negatif: parameter diteruskan apa adanya",
         [(KARTU_NILAI, PARAMETER_SAH)]),
    ]

    salah = 0
    try:
        print("── Aturan 52 sekarang ──")
        for label, mutasi in kasus:
            isi = asli
            for cari, ganti in mutasi:
                if cari not in isi:
                    print(f"JANGKAR TIDAK DITEMUKAN: {label}")
                    salah += 1
                    isi = None
                    break
                isi = isi.replace(cari, ganti, 1)
            if isi is None:
                continue
            mutasi_sumber.write_source(WATCH, isi)
            menyala, detail = _jalankan(program)
            harap_menyala = not label.startswith(("5", "6"))
            if menyala is None:
                print(f"PROBE GAGAL: {label}: {detail}")
                salah += 1
                continue
            ok = menyala == harap_menyala
            salah += 0 if ok else 1
            print(f"{'OK   ' if ok else 'SALAH'} {label:48s} "
                  f"{'MERAH' if menyala else 'hijau'}")

        print("\n── arah kedua: lint pra-perbaikan (wajib HIJAU) ──")
        for label, mutasi in kasus:
            if label.startswith(("5", "6")):
                continue
            isi = asli
            for cari, ganti in mutasi:
                if cari not in isi:
                    print(f"JANGKAR TIDAK DITEMUKAN: {label}")
                    salah += 1
                    isi = None
                    break
                isi = isi.replace(cari, ganti, 1)
            if isi is None:
                continue
            # Keadaan 3 menutup lubang yang lahir sebelum `29ca41b`; keadaan
            # 1 & 2 menutup lubang yang masih terbuka di `HEAD` hari ini.
            acuan = program_lama3 if label.startswith("3") else program_lama
            mutasi_sumber.write_source(WATCH, isi)
            menyala, detail = _jalankan(acuan)
            if menyala is None:
                print(f"PROBE GAGAL: {label}: {detail}")
                salah += 1
                continue
            ok = not menyala
            salah += 0 if ok else 1
            print(f"{'OK   ' if ok else 'SALAH'} pra: {label:42s} "
                  f"{'MERAH' if menyala else 'hijau'}")
    finally:
        mutasi_sumber.write_source(WATCH, asli)

    print()
    if salah:
        print(f"{salah} keadaan tidak sesuai harapan")
        sys.exit(1)
    print("0 keadaan tidak sesuai harapan")


if __name__ == "__main__":
    main()
