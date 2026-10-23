#!/usr/bin/env python3
"""Buktikan Aturan 100 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 100 lahir dari cacat yang **lolos seluruh 99 aturan UI dan kedua uji
Swift glif**: badan `drawCandidateMarker` diubah supaya garis glif tidak
pernah digambar, dan tidak satu pun gerbang merah. Bentuk glif sudah pindah
ke model dan teruji di Linux — tetapi setiap gerbang yang ada membaca model
atau port Python, dan tidak satu pun membaca badan view.

Gerbang yang hijau tidak membuktikan apa pun. Yang membuktikan adalah gerbang
yang **memerah ketika cacatnya dikembalikan**.

Lima keadaan, karena lima jalan berbeda menuju "glif tidak sampai ke kanvas",
dan satu mutasi hanya menutup satu jalan:

  1. **Loop titik diganti daftar kosong.** Ini bentuk aslinya: bentuk dibaca,
     `.points` tidak dipakai. Terukur lolos 99 aturan UI sebelum Aturan 100
     ada.
  2. **Tetes memakai angka tulis-ulang** (`badgeRadius * 0.13`) alih-alih
     `dotRadius` model. Garisnya tetap tergambar, jadi pemeriksaan titik
     hijau — dan justru inilah bentuk yang paling mungkin ditulis orang yang
     menyalin baris tetangganya. Model dan layar bisa berbeda pendapat tanpa
     gerbang berbunyi.
  3. **Bentuk dibuang seluruhnya** (`_ = marker.glyph`, tanpa variabel
     penampung). Pemeriksaan pembacaan harus merah; tanpa itu aturan ini
     berhenti mengukur dan melaporkan hijau.
  4. **Hanya disebut di komentar.** Nama ada di berkas, tidak di kode. Sapuan
     teks yang tidak membuang komentar akan hijau di sini.
  5. **Kontrol negatif:** komentar di dalam badan diubah, kode tidak. Gerbang
     harus tetap hijau — kalau ia memerah di sini, ia mengukur prosa, bukan
     kode.

Keadaan 5 penting khusus untuk berkas ini: badan `drawCandidateMarker`
didahului komentar panjang yang **menyebut** `marker.glyph` dan
`glyphShape.points` untuk menjelaskan cacat lama. Aturan yang tidak membuang
komentar akan hijau di keadaan 1 dan 2 sekaligus, dan tidak menjaga apa pun.

Setiap keadaan menyunting berkas **sungguhan** lalu mengembalikannya, dan
pemulihannya diverifikasi byte-per-byte. Harness menolak berjalan di atas
sumber yang sudah kotor: kalau tidak, ia akan mengadopsi penyimpangan itu
sebagai «aslinya» dan melaporkan «pulih persis» atas dirinya sendiri.
"""

from __future__ import annotations

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True

import mutasi_sumber as M  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GERBANG = "Tools/check-aturan100-glif-sampai-kanvas.py"
VIEW = "Apps/Shared/CelestialVisualView.swift"
MODEL = "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift"

#: Loop titik glif — jangkar mutasi 1.
LOOP = "        for (index, point) in glyphShape.points.enumerated() {"
LOOP_MATI = ("        for (index, point) in "
             "[VisualFrame.CandidateMarker.GlyphPoint]().enumerated() {")

#: Radius tetes dari model — jangkar mutasi 2.
DOT = "        let dotRadius = CGFloat(glyphShape.dotRadius) * radius"
DOT_MATI = "        let dotRadius = badgeRadius * 0.13"

#: Pembacaan bentuk — jangkar mutasi 3.
BACA = "        let glyphShape = marker.glyph"
BACA_MATI = "        _ = marker.glyph"


def jalankan() -> tuple[int, str]:
    """Jalankan gerbangnya, kembalikan (kode keluar, keluaran)."""
    hasil = subprocess.run([sys.executable, GERBANG], cwd=ROOT,
                           capture_output=True, text=True)
    return hasil.returncode, (hasil.stdout + hasil.stderr).strip()


def main() -> int:
    M.require_clean_sources([VIEW, MODEL])

    asli_view = open(os.path.join(ROOT, VIEW), encoding="utf-8").read()
    asli_model = open(os.path.join(ROOT, MODEL), encoding="utf-8").read()

    for nama, jangkar in (("loop titik", LOOP), ("radius tetes", DOT),
                          ("pembacaan bentuk", BACA)):
        if jangkar not in asli_view:
            print(f"FAIL jangkar `{nama}` tidak ditemukan di view — harness "
                  f"ini tidak mengukur apa pun.")
            print("     Perbaiki jangkarnya; jangan dihapus.")
            return 1

    # (label, isi view baru, harapan kode keluar)
    keadaan = [
        ("[baseline] pohon apa adanya", asli_view, 0),
        ("1. loop titik diganti daftar kosong",
         asli_view.replace(LOOP, LOOP_MATI, 1), 1),
        ("2. radius tetes ditulis ulang di view",
         asli_view.replace(DOT, DOT_MATI, 1), 1),
        ("3. bentuk dibuang: `_ = marker.glyph`",
         asli_view.replace(BACA, BACA_MATI, 1), 1),
        ("4. hanya disebut di komentar",
         asli_view.replace(BACA,
                           "        // marker.glyph dipakai di sini\n"
                           "        let glyphShape = VisualFrame.CandidateMarker"
                           ".Glyph(points: [], dotCenter: .init(x: 0, y: 0), "
                           "dotRadius: 0, strokeWidth: 0)", 1), 1),
        ("5. kontrol negatif: komentar diubah, kode tidak",
         asli_view.replace(BACA, "        // " + BACA.strip() + "  // catatan\n"
                           + BACA, 1), 0),
    ]

    gagal = 0
    for label, view_baru, harap in keadaan:
        if label.startswith("[baseline]"):
            kode, keluaran = jalankan()
        else:
            if view_baru == asli_view:
                print(f"{label:52s} LEWAT  mutasinya tidak mengubah apa pun "
                      f"— jangkar basi?")
                gagal += 1
                continue
            M.write_source(os.path.join(ROOT, VIEW), view_baru)
            try:
                kode, keluaran = jalankan()
            finally:
                M.write_source(os.path.join(ROOT, VIEW), asli_view)
                M.restore_verified(os.path.join(ROOT, VIEW), asli_view)

        sesuai = (kode == harap)
        tanda = "OK   " if sesuai else "SALAH"
        merah = [b for b in keluaran.splitlines() if b.startswith("FAIL")]
        ringkas = merah[0] if merah else (
            keluaran.splitlines()[0] if keluaran else "(tanpa keluaran)")
        print(f"{label:52s} {tanda} exit={kode} (harap {harap}) {ringkas[:80]}")
        if not sesuai:
            gagal += 1

    print()
    if gagal:
        print(f"{gagal} keadaan tidak sesuai harapan — Aturan 100 tidak "
              f"membuktikan apa yang diklaimnya.")
        return 1
    print(f"{len(keadaan)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
