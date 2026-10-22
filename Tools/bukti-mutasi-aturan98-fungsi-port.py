#!/usr/bin/env python3
"""Buktikan Aturan 98 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 98 lahir dari cacat yang **lolos 96 aturan UI dan seluruh gerbang
piksel**: badan `starCoreColor` di `Apps/Shared/CelestialVisualView.swift`
diganti `return starColor`, sehingga seluruh pemutihan inti bintang di app
mati. Gerbang yang hijau selamanya tidak membuktikan apa pun; yang membuktikan
adalah gerbang yang **memerah ketika cacatnya dikembalikan**.

Empat keadaan, karena empat jalan berbeda menuju "fungsi tidak sampai ke app",
dan satu mutasi hanya menutup satu jalan:

  1. **Badan dihapus sama sekali** — pemanggilan `CelestialVisual.starCoreRGB(`
     hilang dari `Apps/`. Ini bentuk aslinya, yang terukur lolos 96 aturan.
  2. **Hasilnya dibuang** (`_ = CelestialVisual.starCoreRGB(…)`) — fungsi
     dipanggil, jadi sapuan "apakah namanya ada" akan hijau, tetapi tidak ada
     yang sampai ke gambar. Bentuk paling sunyi dari kelas ini.
  3. **Hanya disebut di komentar** — nama ada di berkas, tidak di kode.
     Sapuan teks yang tidak membuang komentar akan hijau di sini.
  4. **Fungsi berhenti `public`** di model — irisan model∩port menyusut tanpa
     satu pun gerbang berbunyi, dan Aturan 98 akan "lulus" atas himpunan yang
     lebih kecil. Keadaan ini memastikan himpunan yang mengecil **tidak** lolos
     diam-diam.

Keadaan 4 sengaja tidak diuji dengan menghapus fungsi dari model: itu akan
membuat berkasnya tidak bisa dikompilasi, dan harness ini bekerja pada teks.
Yang diuji adalah pengakuannya (`public`), karena itulah yang dibaca gerbang.

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
GERBANG = "Tools/check-aturan98-fungsi-port-sampai-gambar.py"
VIEW = "Apps/Shared/CelestialVisualView.swift"
MODEL = "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift"

#: Badan asli `starCoreColor` — jangkar mutasi 1 dan 3.
BADAN = """        guard !NightMode.isOn else { return starColor }
        let index = CelestialVisual.drawableStarColorIndex(
            visual.colorIndexBV, isConfirmed: isConfirmed)
        let size = CelestialVisual.drawableStarSize(visual, isConfirmed: isConfirmed)
        return Self.color(CelestialVisual.starCoreRGB(forColorIndex: index,
                                                       relativeSize: size))"""


def jalankan() -> tuple[int, str]:
    """Jalankan gerbangnya, kembalikan (kode keluar, keluaran)."""
    hasil = subprocess.run([sys.executable, GERBANG], cwd=ROOT,
                           capture_output=True, text=True)
    return hasil.returncode, (hasil.stdout + hasil.stderr).strip()


def main() -> int:
    M.require_clean_sources([VIEW, MODEL])

    asli_view = open(os.path.join(ROOT, VIEW), encoding="utf-8").read()
    asli_model = open(os.path.join(ROOT, MODEL), encoding="utf-8").read()

    if BADAN not in asli_view:
        print("FAIL jangkar `starCoreColor` tidak ditemukan di view — harness "
              "ini tidak mengukur apa pun.")
        print("     Perbaiki jangkarnya; jangan dihapus.")
        return 1

    # (label, isi view baru, isi model baru, harapan kode keluar)
    keadaan = [
        ("[baseline] pohon apa adanya", asli_view, asli_model, 0),
        ("1. badan starCoreColor -> `return starColor`",
         asli_view.replace(BADAN, "        return starColor", 1),
         asli_model, 1),
        ("2. hasil dibuang: `_ = CelestialVisual.starCoreRGB(…)`",
         asli_view.replace(BADAN, BADAN.replace(
             "        return Self.color(CelestialVisual.starCoreRGB(",
             "        _ = CelestialVisual.starCoreRGB(")
             .replace("                                                       relativeSize: size))",
                      "                                                relativeSize: size)\n        return starColor"), 1),
         asli_model, 1),
        ("3. hanya disebut di komentar",
         asli_view.replace(BADAN, "        // CelestialVisual.starCoreRGB(forColorIndex:relativeSize:)\n"
                                  "        return starColor", 1),
         asli_model, 1),
        # 4. `public` dicabut — irisan menyusut 5 -> 4. Ini BUKAN kegagalan
        #    gerbang, dan mengharapkan merah di sini adalah kesalahan harness
        #    ini sendiri: mencabut `public` membuat `Apps/` gagal dikompilasi,
        #    jadi yang menangkapnya compiler, bukan sapuan teks. Yang bisa dan
        #    perlu dibuktikan adalah bahwa gerbang **melihat** penyusutannya —
        #    kalau ia tetap melaporkan 5 fungsi, ia membaca daftar lain.
        ("4. `public` dicabut: irisan menyusut 5 -> 4",
         asli_view,
         asli_model.replace("public static func starCoreRGB(",
                            "static func starCoreRGB(", 1), "menyusut:4"),
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

        # `harap` boleh int (kode keluar) atau "menyusut:N" (gerbang hijau
        # tetapi melaporkan N fungsi — membuktikan ia melihat penyusutan).
        if isinstance(harap, str) and harap.startswith("menyusut:"):
            jumlah = int(harap.split(":")[1])
            sesuai = (kode == 0 and f"OK {jumlah} fungsi" in keluaran)
        else:
            sesuai = (kode == harap)
        tanda = "OK   " if sesuai else "SALAH"
        ringkas = keluaran.splitlines()[0] if keluaran else "(tanpa keluaran)"
        print(f"{label:58s} {tanda} exit={kode} (harap {harap}) {ringkas[:90]}")
        if not sesuai:
            gagal += 1
    print()
    if gagal:
        print(f"{gagal} keadaan tidak sesuai harapan — Aturan 98 tidak "
              f"membuktikan apa yang diklaimnya.")
        return 1
    print(f"{len(keadaan)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
