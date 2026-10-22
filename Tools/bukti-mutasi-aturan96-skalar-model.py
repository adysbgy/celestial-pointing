#!/usr/bin/env python3
"""Bukti mutasi Aturan 96: skalar model yang dihitung lalu diganti literal.

Kenapa harness ini ada.

Gerbang baru yang hijau pada hari ia ditulis tidak membuktikan apa pun. Yang
harus dibuktikan adalah bahwa ia **bisa** merah, dan merah pada keadaan yang
memang salah — bukan pada kode yang benar.

Yang dimutasi adalah cacat yang terukur di repo ini: `CelestialVisualView`
menghitung `earthshine` dari `CelestialVisual.earthshineStrength(…)`, memakai
hasilnya di `if earthshine > 0`, lalu mengopasitaskan sisi gelap Bulan dengan
nilai itu. Mutasi mengganti **pemakaian nilainya** dengan literal, sementara
`if earthshine > 0` dibiarkan. Itu bentuk yang paling mungkin ditulis orang:
nama fungsinya masih ada di berkas, syaratnya masih membaca model, dan yang
berubah hanya angka yang sampai ke kanvas.

Setiap mutasi dijalankan di **salinan** berkas di direktori sementara; berkas
produksi tidak pernah disentuh, dan `finally` memulihkannya apa pun yang
terjadi.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW = os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")
CHECK = os.path.join(ROOT, "Tools/check-aturan96-skalar-model.py")

#: (nama, ((dari, ke), …)) — setiap mutasi wajib membuat Aturan 96 merah.
#: Entri boleh berisi lebih dari satu penggantian: bentuk "skalar dibuang
#: seluruhnya" menuntut dua suntingan, dan memaksakan satu penggantian akan
#: membuat harness menguji keadaan yang tidak melanggar aturannya.
MUTASI = (
    ("opasitas earthshine jadi literal 1",
     (("CelestialVisual.accents.moonEarthshine).opacity(earthshine)",
       "CelestialVisual.accents.moonEarthshine).opacity(1)"),)),
    ("opasitas earthshine jadi literal 0,5",
     (("CelestialVisual.accents.moonEarthshine).opacity(earthshine)",
       "CelestialVisual.accents.moonEarthshine).opacity(0.5)"),)),
    # Arah kedua: skalar yang **sama sekali** tidak dipakai. Bentuk yang lebih
    # kasar, dan harus merah juga — kalau tidak, aturan hanya menangkap satu
    # bentuk kebetulan. Syaratnya ikut diganti supaya `earthshine` benar-benar
    # hilang dari badan fungsi; mengganti syaratnya saja tidak melanggar
    # aturan ini (nilainya masih sampai ke kanvas) dan harness yang
    # mengharapkan merah di situ akan menguji hal lain.
    ("earthshine dibuang seluruhnya",
     (("if earthshine > 0 {", "if true {"),
      ("CelestialVisual.accents.moonEarthshine).opacity(earthshine)",
       "CelestialVisual.accents.moonEarthshine).opacity(0.15)"))),
)


def jalankan_gerbang() -> tuple[int, str]:
    hasil = subprocess.run([sys.executable, CHECK], cwd=ROOT,
                           capture_output=True, text=True)
    return hasil.returncode, (hasil.stdout + hasil.stderr).strip()


def main() -> int:
    asli = open(VIEW, encoding="utf-8").read()

    kode, keluaran = jalankan_gerbang()
    if kode != 0:
        print("FAIL baseline sudah merah — harness ini tidak mengukur apa pun:")
        print(keluaran)
        return 1
    print("OK baseline hijau (kode produksi saat ini)")

    gagal = []
    for nama, suntingan in MUTASI:
        hilang = [dari for dari, _ in suntingan if dari not in asli]
        if hilang:
            print(f"FAIL mutasi '{nama}': pola tidak ditemukan di view:")
            for pola in hilang:
                print(f"       {pola}")
            print("     Harness yang tidak menemukan polanya diam, dan diam")
            print("     terbaca sebagai lulus.")
            gagal.append(nama)
            continue
        isi = asli
        for dari, ke in suntingan:
            isi = isi.replace(dari, ke, 1)
        with tempfile.TemporaryDirectory() as tmp:
            cadangan = os.path.join(tmp, "view.swift")
            shutil.copy2(VIEW, cadangan)
            try:
                open(VIEW, "w", encoding="utf-8").write(isi)
                kode, keluaran = jalankan_gerbang()
            finally:
                shutil.copy2(cadangan, VIEW)
        if kode == 0:
            print(f"FAIL mutasi '{nama}' TIDAK tertangkap Aturan 96:")
            print(f"     {keluaran}")
            gagal.append(nama)
        else:
            baris = next((l for l in keluaran.splitlines() if l.startswith("FAIL")),
                         keluaran.splitlines()[0] if keluaran else "")
            print(f"OK tertangkap: {nama}")
            print(f"   {baris}")

    # Berkas produksi wajib kembali persis seperti semula.
    if open(VIEW, encoding="utf-8").read() != asli:
        print("FAIL view tidak pulih setelah harness — periksa git diff.")
        return 1

    if gagal:
        print(f"\n{len(gagal)} mutasi lolos: Aturan 96 tidak menjaga apa yang "
              f"diklaimnya.")
        return 1

    print(f"\nOK {len(MUTASI)} mutasi tertangkap, view pulih.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
