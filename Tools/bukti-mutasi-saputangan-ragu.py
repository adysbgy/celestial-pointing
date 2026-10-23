#!/usr/bin/env python3
"""Bukti bahwa Aturan 51 berbunyi pada cacatnya, dan diam pada kode benar.

Kenapa berkas ini ada
=====================

Aturan 51 (`swift-ui-lint.sh`) menuntut dua situs di `drawPlanet` membaca
keyakinan engine:

  1. `phaseGeometry(waxing:)` — **fase planet dalam** (sabit Venus &
     Merkurius). Sabit adalah bentuk pengenal, sama seperti cincin Saturnus.
  2. `planet.palette.drawable(isConfirmed:)` — **warna** planet. Warna adalah
     ciri yang paling cepat dibaca mata, lebih cepat daripada teks di bawahnya.

Aturan itu lahir dari cacat yang **terukur hijau** pada 50 aturan sebelumnya.
Dua mutasi dijalankan pada pohon yang benar, lalu seluruh lint dijalankan di
proses baru:

    penjaga fase dihapus   -> exit 0, "SEMUA GERBANG UI LULUS"
    drawable() tanpa args  -> exit 0, "SEMUA GERBANG UI LULUS"

`swift test` tidak bisa menolong: `Apps/` tidak pernah dibangun di Linux.

Kenapa Aturan 34 tidak cukup, dan itu bagian dari yang dibuktikan
=================================================================

Aturan 34 menangkap `drawable(isConfirmed: true)` — **literal** yang mengganti
keyakinan engine. Ia tidak menangkap argumen yang **hilang**: `drawable()` di
Swift berarti palet penuh, jadi warnanya diklaim tanpa satu pun literal `true`
yang bisa ditangkap. Pembeda itu ada di daftar keadaan di bawah (C dan D):
keduanya wajib MERAH di Aturan 51, dan C juga merah di Aturan 34.

Kenapa ada keadaan yang **wajib hijau**
=======================================

Tanpa mereka, aturan yang menuduh setiap baris `Apps/` akan lulus semua
keadaan. Dua situs sah yang paling mudah tersalah tuduh:

  - `phaseGeometry(waxing: visual.isWaxing)` di `drawMoon`, **tanpa**
    `isConfirmed`: fase Bulan adalah fakta tanggal, bukan hasil pencarian id,
    dan `check_moon_phase_survives_uncertainty` menuntutnya tetap tampil saat
    ragu. Kalau aturan ini menyapu seluruh berkas, keadaan inilah yang akan
    memerahkannya pada kode benar.
  - `CelestialVisual.Planet.saturn.palette` di `drawRings`, dipakai untuk
    warna cincin (token `accents`), sementara cincinnya sendiri sudah ditahan
    Aturan 50 dan 32.

Keduanya ada di keadaan kontrol pertama: **kalau aturan ini memperlebar
cakupannya ke luar `drawPlanet`, kontrol itu langsung merah.**

Arah kedua: gerbang **pra-perbaikan**
=====================================

Seluruh keadaan di atas lulus sempurna pada gerbang yang lulus selamanya.
Karena itu ada keadaan yang menukar `swift-ui-lint.sh` dengan versi
**sebelum** Aturan 51 ditambahkan (`git show <commit>:swift-ui-lint.sh`) dan
menuntut **HIJAU pada cacat yang sama** — membuktikan bahwa lubangnya nyata,
bukan dikarang oleh aturan yang selalu berbunyi.

Yang TIDAK dibuktikan harness ini
=================================

Ini sapu teks, bukan pelacakan aliran. Ia membuktikan situsnya **menyebut**
keyakinan engine, bukan bahwa piksel yang dihasilkan berhenti berubah di
perangkat — tidak ada Xcode di mesin ini dan `Apps/` tidak pernah dibangun
`swift-test.sh`.

Pakai:
    python3 Tools/bukti-mutasi-saputangan-ragu.py     # 0 = semua sesuai harapan
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

import mutasi_sumber  # noqa: E402

VIEW = "Apps/Shared/CelestialVisualView.swift"
LINT = "swift-ui-lint.sh"

# ── Jangkar produksi ───────────────────────────────────────────────────────
# Bentuk yang **harus** ada di pohon. Kalau salah satunya hilang, harness
# menolak jalan alih-alih melaporkan "sesuai harapan" atas nol mutasi.
FASE_PENJAGA = ("if isConfirmed, let phase = visual.phaseGeometry("
                "waxing: visual.isWaxing) {")
FASE_TANPA_PENJAGA = ("if let phase = visual.phaseGeometry("
                      "waxing: visual.isWaxing) {")
FASE_TERBALIK = ("if !isConfirmed, let phase = visual.phaseGeometry("
                 "waxing: visual.isWaxing) {")

PALET = "let palette = planet.palette.drawable(isConfirmed: isConfirmed)"
PALET_TANPA_ARGS = "let palette = planet.palette.drawable()"
PALET_TANPA_DRAWABLE = "let palette = planet.palette"
PALET_LITERAL = "let palette = planet.palette.drawable(isConfirmed: true)"

#: Komit terakhir sebelum Aturan 51 ada. Dipakai arah kedua: gerbang lama
#: **wajib hijau** pada cacat yang sama, kalau tidak lubangnya tidak nyata.
PRA_ATURAN51 = "4a0a15d9717483bf973aed4381200bc921cd0ad3"

STATES = [
    # ── Keadaan cacat: Aturan 51 WAJIB berbunyi ────────────────────────────
    ("A penjaga fase planet dalam dihapus (terukur exit 0 pada 50 aturan)",
     [(VIEW, (FASE_PENJAGA, FASE_TANPA_PENJAGA))], "merah"),
    ("B penjaga fase dibalik: sabit hanya saat ragu",
     [(VIEW, (FASE_PENJAGA, FASE_TERBALIK))], "merah"),
    ("C drawable() tanpa argumen isConfirmed",
     [(VIEW, (PALET, PALET_TANPA_ARGS))], "merah"),
    ("D planet.palette tanpa drawable sama sekali",
     [(VIEW, (PALET, PALET_TANPA_DRAWABLE))], "merah"),

    # ── Keadaan sah: Aturan 51 WAJIB diam ──────────────────────────────────
    # Kontrol yang sama bentuknya dengan pohon, dan itu satu-satunya yang
    # membedakan "menangkap cacat" dari "berbunyi pada apa pun".
    ("E kontrol: pohon utuh tanpa perubahan", [], "hijau"),

    # ── Arah kedua: gerbang pra-perbaikan pada cacat yang sama ─────────────
    ("G pra-Aturan51: penjaga fase dihapus (wajib HIJAU = lubangnya nyata)",
     [(VIEW, (FASE_PENJAGA, FASE_TANPA_PENJAGA))], "hijau", PRA_ATURAN51),
    ("H pra-Aturan51: drawable() tanpa argumen (wajib HIJAU)",
     [(VIEW, (PALET, PALET_TANPA_ARGS))], "hijau", PRA_ATURAN51),
]

#: Aturan yang **harus** menyala untuk tiap keadaan cacat. Tanpa ini, "merah"
#: bisa berarti aturan lain yang kebetulan gagal (mis. Aturan 10 saat README
#: menyimpang) — dan harness akan melaporkan bukti yang tidak ia miliki.
WAJIB_MENYALA = {
    "A penjaga fase planet dalam dihapus (terukur exit 0 pada 50 aturan)":
        "Aturan 51",
    "B penjaga fase dibalik: sabit hanya saat ragu": "Aturan 51",
    "C drawable() tanpa argumen isConfirmed": "Aturan 51",
    "D planet.palette tanpa drawable sama sekali": "Aturan 51",
}


def run_lint(tree):
    return subprocess.run(["./swift-ui-lint.sh"], cwd=tree,
                          capture_output=True, text=True)


def apply_edits(tree, edits):
    """Terapkan `[(path, (find, replace))]`; kembalikan daftar kegagalan.

    Setiap jangkar wajib muncul **tepat sekali** — kalau tidak, mutasinya
    ambigu dan hasilnya tidak mengukur apa pun.
    """
    gagal = []
    for path, (find, replace) in edits:
        target = os.path.join(tree, path)
        sumber = open(target, encoding="utf-8").read()
        if sumber.count(find) != 1:
            gagal.append("%s: %d kecocokan untuk %r"
                         % (path, sumber.count(find), find[:60]))
            continue
        if find != replace:
            mutasi_sumber.write_source(target, sumber.replace(find, replace, 1))
    return gagal


def periksa_jangkar():
    """Jangkar produksi harus ada di pohon sebelum apa pun dimutasi."""
    sumber = open(os.path.join(ROOT, VIEW), encoding="utf-8").read()
    hilang = [nama for nama, teks in (("fase berpenjaga", FASE_PENJAGA),
                                      ("palet lewat drawable", PALET))
              if sumber.count(teks) != 1]
    return hilang


def buang_aturan_10(tree):
    """Hapus **langkah Aturan 10** dari lint yang dipasang di `tree`.

    Kenapa ini perlu untuk arah kedua. Aturan 10 menuntut angka aturan di
    README sama dengan jumlah aturan di `swift-ui-lint.sh`. Gerbang lama
    punya 50 aturan sementara README (yang di-checkout bersama pohon ini)
    menyebut 51, jadi **setiap** keadaan di gerbang lama merah di Aturan 10 —
    terukur — dan arah kedua berhenti membuktikan lubangnya: yang terbaca
    "merah" bukan karena cacat identitasnya tertangkap.

    Yang dihapus hanya pemeriksa hitungannya, bukan gerbang lainnya: 50
    aturan lain tetap berjalan utuh, jadi keadaan G/H tetap membuktikan
    "seluruh gerbang pra-perbaikan lulus pada cacat ini".
    """
    target = os.path.join(tree, LINT)
    teks = open(target, encoding="utf-8").read()
    awal = teks.find('echo "== Aturan 10:')
    akhir = teks.find('echo "== Aturan 11:')
    if awal < 0 or akhir < 0 or akhir <= awal:
        raise SystemExit("GAGAL: tidak bisa memisahkan Aturan 10 dari lint "
                         "pra-perbaikan; arah kedua tidak bisa dijalankan.")
    mutasi_sumber.write_source(target, teks[:awal] + teks[akhir:])


def main():
    if not os.path.isfile(os.path.join(ROOT, LINT)):
        print("Tidak menemukan %s di %s" % (LINT, ROOT))
        return 2

    hilang = periksa_jangkar()
    if hilang:
        print("Jangkar produksi hilang dari pohon: %s" % ", ".join(hilang))
        print("Harness tidak tahu apa yang dimutasi, jadi ia berhenti.")
        return 1

    # Versi lint **pra-perbaikan**, dibaca lewat git — bukan dikarang. Kalau
    # ini gagal terbaca, gerbang lama akan tampak hijau karena kosong, dan
    # arah kedua berhenti membuktikan apa pun.
    lama = mutasi_sumber.git_show(PRA_ATURAN51, LINT, min_bytes=10000)

    gagal = []
    for nama, edits, harap, *sisa in STATES:
        work = tempfile.mkdtemp(prefix="bukti-saputangan-")
        tree = os.path.join(work, "repo")
        try:
            shutil.copytree(
                ROOT, tree, symlinks=True,
                ignore=shutil.ignore_patterns(".build", ".git", "__pycache__",
                                              "out"))
            if sisa:
                mutasi_sumber.write_source(os.path.join(tree, LINT), lama)
                buang_aturan_10(tree)

            rusak = apply_edits(tree, edits)
            if rusak:
                print("%-62s JANGKAR HILANG: %s" % (nama, "; ".join(rusak)))
                gagal.append(nama)
                continue

            hasil = run_lint(tree)
            merah = hasil.returncode != 0
            sesuai = merah == (harap == "merah")
            print("%-62s %s (exit %d)" % (
                nama,
                "MERAH, sesuai harapan" if merah else "HIJAU, sesuai harapan",
                hasil.returncode))
            if not sesuai:
                gagal.append(nama)
                print("    diharapkan %s, dapat %s"
                      % (harap.upper(), "MERAH" if merah else "HIJAU"))
            # Aturan yang menyala harus **yang dimaksud**. Merah karena
            # aturan lain bukan bukti bahwa aturan ini berbunyi.
            if merah and harap == "merah" and nama in WAJIB_MENYALA:
                if WAJIB_MENYALA[nama] not in hasil.stdout:
                    gagal.append(nama)
                    print("    merah, tetapi %s tidak menyala di keluaran"
                          % WAJIB_MENYALA[nama])
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
