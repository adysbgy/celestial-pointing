#!/usr/bin/env python3
"""Buktikan Aturan 101 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 101 lahir dari cacat yang **lolos 99 aturan UI, 203 pemeriksaan
paritas port, dan pemeriksaan opasitas yang baru ditambahkan siklus lalu**:
`case .blueDisk: drawBlueDisk(…)` di `drawPlanet` diganti `case .blueDisk:
break`. Bintik gelap Neptunus hilang seluruhnya dari app — Neptunus kembali
menjadi piringan biru polos — dan tidak satu pun gerbang berbunyi.

Siklus Venus sudah menutup versi *token* dari kelas ini: setiap
`static let *Opacity` harus dipakai penggambarnya. Itu tidak menutup
*pemanggilnya*. `neptuneSpotOpacity` masih disebut di dalam `drawBlueDisk`,
dan `drawBlueDisk` masih ada di berkas; yang hilang hanya satu baris di
switch. Gerbang yang bertanya "apakah token ini dipakai di suatu tempat"
menjawab ya untuk kode mati — dan kode mati menggambar nol piksel.

Lima keadaan, karena lima jalan berbeda menuju "ciri planet tidak sampai ke
layar", dan satu mutasi hanya menutup satu jalan:

  1. **Cabang dikosongkan** (`case .blueDisk: {}`) — bentuk yang lolos 99
     aturan. Ciri hilang, enum tetap utuh, penggambarnya tetap ada.
  2. **Cabang di-`break`** — sama akibatnya, bentuk asli yang terukur.
  3. **Cabang dihapus** — switch tidak lagi menyebut ciri itu sama sekali.
     Gerbang harus menyebut **ciri mana** yang hilang, bukan sekadar merah.
  4. **Enum di model diganti nama** — gerbang berhenti bisa menurunkan daftar
     cirinya. Ini harus GAGAL, bukan hijau: gerbang yang tidak menemukan
     apa pun untuk diperiksa sudah berhenti mengukur, dan hijau di sini
     adalah hijau yang tidak berarti.
  5. **Ciri baru ditambahkan ke enum tanpa cabang** — jalan yang paling
     mungkin terjadi berikutnya, dan justru yang paling mudah terlewat:
     menambah `case dustStorms` di model dan lupa memasang cabangnya. Gerbang
     harus memerah tanpa siapa pun memperbarui daftar tangan, karena
     daftarnya diturunkan dari enum.

Keadaan 3 sengaja menghapus **satu baris** cabang, bukan badan
`drawBlueDisk`: menghapus penggambarnya membuat view tidak bisa
dikompilasi, dan harness ini bekerja pada teks — yang diuji adalah sambungan
switch, karena itulah yang dibaca gerbang.

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
GERBANG = "Tools/check-aturan101-ciri-planet-tersambung.py"
VIEW = "Apps/Shared/CelestialVisualView.swift"
MODEL = "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift"

#: Baris cabang asli — jangkar keadaan 1, 2, dan 3.
CABANG = ("        case .blueDisk: drawBlueDisk(context: context, "
          "center: center, radius: radius)")


def jalankan() -> tuple[int, str]:
    """Jalankan gerbangnya, kembalikan (kode keluar, keluaran)."""
    hasil = subprocess.run([sys.executable, GERBANG], cwd=ROOT,
                           capture_output=True, text=True)
    return hasil.returncode, (hasil.stdout + hasil.stderr).strip()


def main() -> int:
    M.require_clean_sources([VIEW, MODEL])

    asli_view = open(os.path.join(ROOT, VIEW), encoding="utf-8").read()
    asli_model = open(os.path.join(ROOT, MODEL), encoding="utf-8").read()

    if CABANG not in asli_view:
        print("FAIL jangkar `case .blueDisk:` tidak ditemukan di view — "
              "harness ini tidak mengukur apa pun.")
        print("     Perbaiki jangkarnya; jangan dihapus.")
        return 1

    # Ciri baru di enum, tanpa cabang di view — keadaan 5.
    enum_lama = "        /// Piringan biru dengan titik gelap (Neptunus).\n" \
                "        case blueDisk\n"
    if enum_lama not in asli_model:
        print("FAIL jangkar `case blueDisk` tidak ditemukan di model — "
              "keadaan 5 tidak bisa diuji.")
        return 1

    # (label, isi view baru, isi model baru, harapan)
    # `harap` = kode keluar, atau ("memuat", teks) untuk gerbang yang harus
    # merah **dan** menyebut nama cirinya.
    keadaan = [
        ("[baseline] pohon apa adanya", asli_view, asli_model, 0),
        ("1. cabang dikosongkan: `case .blueDisk: {}`",
         asli_view.replace(CABANG, "        case .blueDisk: {}", 1),
         asli_model, ("memuat", "blueDisk")),
        ("2. cabang di-break: `case .blueDisk: break`",
         asli_view.replace(CABANG, "        case .blueDisk: break", 1),
         asli_model, ("memuat", "blueDisk")),
        ("3. cabang dihapus sama sekali",
         asli_view.replace(CABANG + "\n", "", 1),
         asli_model, ("memuat", "blueDisk")),
        # 4. Enum diganti nama: gerbang kehilangan daftarnya. Hijau di sini
        #    berarti gerbang berhenti mengukur tanpa memberi tahu siapa pun.
        ("4. enum diganti nama: daftar ciri tak terbaca",
         asli_view,
         asli_model.replace("enum DistinguishingFeature:",
                            "enum DistinguishingFeatureLama:", 1),
         ("memuat", "tidak terbaca")),
        # 5. Ciri baru tanpa cabang — jalan berikutnya, dan alasan daftarnya
        #    diturunkan dari enum alih-alih ditulis tangan.
        ("5. ciri baru `dustStorms` tanpa cabang",
         asli_view,
         asli_model.replace(
             enum_lama,
             enum_lama + "        /// Badai debu (uji harness).\n"
                         "        case dustStorms\n", 1),
         ("memuat", "dustStorms")),
    ]

    gagal = 0
    for label, view_baru, model_baru, harap in keadaan:
        if label.startswith("[baseline]"):
            kode, keluaran = jalankan()
        else:
            if view_baru == asli_view and model_baru == asli_model:
                print(f"{label:58s} LEWAT  mutasinya tidak mengubah apa pun — "
                      f"jangkar basi?")
                gagal += 1
                continue
            if view_baru != asli_view:
                M.write_source(os.path.join(ROOT, VIEW), view_baru)
            if model_baru != asli_model:
                M.write_source(os.path.join(ROOT, MODEL), model_baru)
            try:
                kode, keluaran = jalankan()
            finally:
                M.write_source(os.path.join(ROOT, VIEW), asli_view)
                M.write_source(os.path.join(ROOT, MODEL), asli_model)
                M.restore_verified(os.path.join(ROOT, VIEW), asli_view)
                M.restore_verified(os.path.join(ROOT, MODEL), asli_model)

        if isinstance(harap, tuple) and harap[0] == "memuat":
            sesuai = (kode != 0 and harap[1] in keluaran)
            harap_teks = f"merah, memuat {harap[1]!r}"
        else:
            sesuai = (kode == harap)
            harap_teks = f"exit={harap}"
        tanda = "OK   " if sesuai else "SALAH"
        # Baris yang menyebut cacatnya lebih berguna daripada baris pertama,
        # yang pada keadaan merah adalah daftar `ok` milik ciri lain.
        baris = [b for b in keluaran.splitlines() if b.startswith("FAIL")]
        ringkas = baris[0] if baris else (keluaran.splitlines()[0] if keluaran else "(tanpa keluaran)")
        print(f"{label:58s} {tanda} exit={kode} (harap {harap_teks}) {ringkas[:100]}")
        if not sesuai:
            gagal += 1

    print()
    if gagal:
        print(f"{gagal} keadaan tidak sesuai harapan — Aturan 101 tidak "
              f"membuktikan apa yang diklaimnya.")
        return 1
    print(f"{len(keadaan)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
