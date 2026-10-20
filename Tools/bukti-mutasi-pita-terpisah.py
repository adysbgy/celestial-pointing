#!/usr/bin/env python3
"""Buktikan gerbang keterpisahan pita Jupiter **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

`check_jupiter_bands_read_as_separate_stripes` lahir dari cacat yang diukur,
bukan dari keinginan menambah gerbang: sampai siklus ini **tidak satu pun**
gerbang pita bertanya apakah dua pita bersebelahan bisa dibedakan. Keempat
gerbang yang ada (sampai ke limb, mengikuti busur, tidak menghapus lengkung,
masih terbaca setelah pemulihan limb) semuanya lulus pada pola tan->rust->cream
berulang yang terukur memberi residual **0.006** — praktis tidak terpisah, dan
dinilai manusia 3/10 atas PNG yang sama.

Gerbang gambar selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, dan merah karena alasan yang benar.

Keadaan yang diuji:

  1. pohon utuh                     -> HIJAU (kontrol negatif)
  2. palet lama (cream/rust/tan)    -> MERAH, kedua mode
  3. pola lama (tan->rust->cream)   -> MERAH, kedua mode
  4. keduanya lama                  -> MERAH, kedua mode
  5. satu nada (semua `zone`)       -> MERAH, kedua mode
  6. bintik kembali jadi lubang     -> MERAH (gerbang terang bintik)

Keadaan 2 dan 3 sengaja **dipisah**: palet dan pola adalah dua sumbu yang
berbeda, dan keduanya bisa dikembalikan sendiri-sendiri. Kalau hanya "keduanya
lama" yang diuji, gerbang yang hanya membaca salah satu sumbu akan tetap
lulus — dan sumbu yang lain bisa kembali tanpa ada yang tahu.

Keadaan 5 adalah batas bawahnya: pola yang sah secara tipe tetapi seragam.
Residualnya **nol persis** di kedua mode, jadi tidak ada ambang yang bisa
membuatnya hijau.

Keadaan 6 menjaga **sisi lain** dari perubahan palet yang sama. Menggelapkan
pita memaksa bintiknya ikut digelapkan supaya tetap "15% lebih gelap dari
setiap pita"; pada 0.26/0.05/0.04 seluruh gerbang bintik lama tetap hijau,
tetapi terang hasil render jatuh ke 0.519 dan bintiknya terbaca sebagai
**lubang**, bukan badai. `check_jupiter_spot_is_not_a_hole` menutupnya, dan
keadaan ini membuktikan gerbang itu berbunyi.

Yang dijalankan adalah **fungsi pemeriksaan yang sama** dengan gerbang penuh,
bukan salinan. `render_case` di dalamnya menulis PNG ke `out/` seperti biasa,
jadi biayanya beberapa detik per keadaan, bukan ~40 menit gerbang penuh.

Pakai:
    python3 Tools/bukti-mutasi-pita-terpisah.py    # 0 = semua sesuai harapan
"""
from __future__ import annotations

import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

spec = importlib.util.spec_from_file_location(
    "check_visuals", os.path.join(ROOT, "Tools/check-visuals.py"))
CV = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CV)
R = CV.R

#: Palet **sebelum** siklus ini. Angka-angka ini bukan tebakan: ia dibaca dari
#: `git show HEAD:Packages/PointingKit/Sources/PointingKit/NightVisual.swift`
#: dan disalin apa adanya ke `ACCENTS` port.
OLD_ACCENTS = {
    "jupiterBandCream": (0.90, 0.83, 0.72),
    "jupiterBandRust": (0.72, 0.52, 0.38),
    "jupiterBandTan": (0.85, 0.76, 0.62),
}

#: Pola **sebelum** siklus ini: tan -> rust -> cream berulang, yaitu yang
#: dihasilkan `switch index % 3` di view dan larik yang sama di port.
OLD_TONES = (["pole", "zone", "belt"] * 3)[:7]

#: Nama hasil yang diharapkan merah. Dibaca dari gerbangnya sendiri, bukan
#: ditulis ulang di sini — kalau namanya berubah, harness ini merah dan bukan
#: diam-diam membandingkan dengan nama yang tidak pernah muncul.
EXPECTED_PREFIX = "pita Jupiter terpisah di mata"


def jalankan(tones=None, accents=None):
    """Jalankan gerbang pada keadaan tertentu → daftar (nama, ok, detail)."""
    saved_tones = R.BAND_TONES
    saved_accents = dict(R.ACCENTS)
    try:
        if tones is not None:
            R.BAND_TONES = list(tones)
        if accents is not None:
            R.ACCENTS.update(accents)
        results = []
        CV.check_jupiter_bands_read_as_separate_stripes(results, 200, 2)
        return [(r.name, r.ok, r.detail) for r in results]
    finally:
        R.BAND_TONES = saved_tones
        R.ACCENTS.clear()
        R.ACCENTS.update(saved_accents)


def periksa(label, harap_merah, tones=None, accents=None):
    hasil = jalankan(tones=tones, accents=accents)
    if len(hasil) != 2:
        print(f"SALAH {label:22s} -> {len(hasil)} pemeriksaan, harus 2 "
              "(siang + malam); gerbangnya berhenti mengukur salah satu mode")
        return False
    merah = [h for h in hasil if not h[1]]
    nama_benar = all(h[0].startswith(EXPECTED_PREFIX) for h in hasil)
    if harap_merah:
        ok = len(merah) == 2 and nama_benar
        print(f"{'OK  ' if ok else 'SALAH'} {label:22s} -> "
              f"{len(merah)}/2 MERAH (harap 2)"
              + ("" if nama_benar else ", nama pemeriksaan tidak dikenal"))
        for nama, _, detail in hasil:
            if not ok:
                print(f"       {nama}: {detail}")
    else:
        ok = len(merah) == 0 and nama_benar
        print(f"{'OK  ' if ok else 'SALAH'} {label:22s} -> "
              f"{len(merah)}/2 merah (harap 0)")
        for nama, hijau, detail in hasil:
            if not ok:
                print(f"       {nama}: {detail}")
    return ok


def jalankan_bintik(accents=None):
    """Jalankan gerbang terang bintik pada keadaan tertentu -> [(nama, ok, detail)]."""
    saved = dict(R.ACCENTS)
    try:
        if accents is not None:
            R.ACCENTS.update(accents)
        results = []
        CV.check_jupiter_spot_is_not_a_hole(results)
        return [(r.name, r.ok, r.detail) for r in results]
    finally:
        R.ACCENTS.clear()
        R.ACCENTS.update(saved)


def periksa_bintik(label, harap_merah, accents=None):
    hasil = jalankan_bintik(accents=accents)
    if len(hasil) != 1:
        print(f"SALAH {label:22s} -> {len(hasil)} pemeriksaan, harus 1")
        return False
    nama, ok, detail = hasil[0]
    benar = not ok if harap_merah else ok
    print(f"{'OK  ' if benar else 'SALAH'} {label:22s} -> "
          f"{'MERAH' if not ok else 'hijau'} (harap {'MERAH' if harap_merah else 'hijau'})")
    if not benar:
        print(f"       {nama}: {detail}")
    return benar


def main():
    print("Gerbang keterpisahan pita Jupiter\n")
    hasil = []

    # Kontrol negatif lebih dulu: kalau pohon utuh sudah merah, merah pada
    # keadaan lain tidak membedakan apa pun.
    hasil.append(periksa("pohon utuh", harap_merah=False))
    hasil.append(periksa("palet lama", harap_merah=True, accents=OLD_ACCENTS))
    hasil.append(periksa("pola lama", harap_merah=True, tones=OLD_TONES))
    hasil.append(periksa("keduanya lama", harap_merah=True,
                         tones=OLD_TONES, accents=OLD_ACCENTS))
    hasil.append(periksa("satu nada", harap_merah=True, tones=["zone"] * 7))

    # Sisi lain dari palet yang sama: bintiknya tidak boleh jadi lubang.
    print()
    hasil.append(periksa_bintik("bintik apa adanya", harap_merah=False))
    hasil.append(periksa_bintik("bintik jadi lubang", harap_merah=True,
                                accents={"jupiterSpot": (0.26, 0.05, 0.04)}))

    print()
    if not all(hasil):
        print(f"{hasil.count(False)} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(hasil)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
