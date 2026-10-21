#!/usr/bin/env python3
"""Buktikan dua gerbang pelembutan tepi pita bisa **merah**.

Kenapa harness ini ada.

Siklus ini menambahkan `bandFeatherFraction` ke model, view, dan port — dan
dua gerbang yang mengukurnya di piksel. Gerbang yang hijau pada hari ia
ditulis tidak membuktikan apa pun: yang harus dibuktikan adalah bahwa ia
**bisa** merah, dan merah pada keadaan yang memang salah.

Keadaan yang diuji, dan mengapa masing-masing ada:

  1. **pohon utuh** — kontrol negatif. Kalau keadaan ini sudah merah, merah
     pada keadaan lain tidak membedakan apa pun; harness akan melaporkan
     "sesuai harapan" untuk gerbang yang rusak total.
  2. **pelembutan dimatikan** (`BAND_FEATHER_FRACTION = 0.0`) — keadaan yang
     gerbangnya ada untuk menangkap: pita kembali jadi poligon warna rata
     dan batasnya dinding satu piksel lagi. Gerbang `softens_the_edge`
     **wajib merah** di sini; kalau hijau, ia tidak mengukur pelembutan.
  3. **docstring mengutip angka lama** (117.4 -> 23.3) — angka yang benar-
     benar ada di pohon ini sebelum siklus ini dan **tidak pernah dihasilkan
     pengukuran mana pun**. Gerbang paritas **wajib merah** di sini. Ini
     arah yang paling penting: tanpa keadaan ini, gerbang paritas bisa saja
     membandingkan docstring dengan dirinya sendiri dan selalu hijau.
  4. **docstring mengutip angka yang sedikit bergeser** (132.3 -> 32.4) —
     pembulatan satu desimal, bukan angka karangan. Gerbang memakai toleransi
     0.05, jadi ini **wajib hijau**: gerbang yang merah pada pembulatan sah
     akan dimatikan orang, dan setelah dimatikan ia tidak menjaga apa pun.
  5. **docstring hilang** — deklarasi tanpa `///` di atasnya. Gerbang
     **wajib merah**: tanpa docstring tidak ada yang dikutip, dan "tidak ada
     angka untuk diperiksa" tidak boleh terbaca sebagai "angka benar".

Angka yang dipakai keadaan 3 dan 4 dibaca dari pohon itu sendiri
(`BAND_EDGE_QUOTED`), bukan ditulis ulang di sini — kalau pengukurannya
berubah, harness ini ikut berubah alih-alih membandingkan dengan angka
yang tidak pernah muncul.
"""

from __future__ import annotations

import importlib.util
import os
import sys

sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import mutasi_sumber as MS  # noqa: E402

spec = importlib.util.spec_from_file_location(
    "check_visuals", os.path.join(HERE, "check-visuals.py"))
CV = importlib.util.module_from_spec(spec)
sys.argv = ["check-visuals.py"]
spec.loader.exec_module(CV)
R = CV.R

MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                           "CelestialVisual.swift")

#: Nama hasil yang diharapkan. Dibaca dari gerbangnya sendiri lewat awalan,
#: bukan ditulis ulang: kalau namanya berubah, harness ini merah dan bukan
#: diam-diam membandingkan dengan nama yang tidak pernah muncul.
SOFTEN_PREFIX = "tepi pita Jupiter dilembutkan"
PARITY_PREFIX = "tepi pita: docstring mengutip ukuran"


def ukuran(label):
    """(sebelum, sesudah) yang dikutip `BAND_EDGE_QUOTED` untuk satu ukuran."""
    want = CV.BAND_EDGE_QUOTED[label]
    return want["sebelum"], want["sesudah"]


def ganti_kutipan(teks, lama, baru):
    """Ganti satu angka kutipan di docstring, dan **buktikan** ia terganti.

    Tanpa pemeriksaan ini, keadaan 3/4 bisa "lulus" karena penggantiannya
    tidak menemukan apa pun — lalu yang diukur adalah docstring yang tidak
    berubah, dan gerbangnya hijau karena alasan yang salah.
    """
    if lama not in teks:
        raise SystemExit(
            f"GAGAL: `{lama}` tidak ada di docstring — keadaan harness ini "
            "tidak bisa membuktikan apa pun. Perbarui harness setelah "
            "docstring berubah.")
    return teks.replace(lama, baru, 1)


def jalankan_soften(feather=None):
    saved = R.BAND_FEATHER_FRACTION
    try:
        if feather is not None:
            R.BAND_FEATHER_FRACTION = feather
        results = []
        CV.check_band_feather_softens_the_edge(results, 200)
        return [(r.name, r.ok, r.detail) for r in results]
    finally:
        R.BAND_FEATHER_FRACTION = saved


def jalankan_parity():
    results = []
    CV.check_band_feather_docstring_quotes_measured_values(results)
    return [(r.name, r.ok, r.detail) for r in results]


def laporkan(label, hasil, harap_merah, awalan, harap=2):
    if len(hasil) != harap:
        print(f"SALAH {label:26s} -> {len(hasil)} pemeriksaan, harus {harap}; "
              "gerbangnya berhenti mengukur salah satu keadaan")
        return False
    merah = [h for h in hasil if not h[1]]
    nama_benar = all(h[0].startswith(awalan) for h in hasil)
    if harap_merah:
        ok = len(merah) == harap and nama_benar
        print(f"{'OK  ' if ok else 'SALAH'} {label:26s} -> "
              f"{len(merah)}/{harap} MERAH (harap {harap})"
              + ("" if nama_benar else ", nama pemeriksaan tidak dikenal"))
    else:
        ok = len(merah) == 0 and nama_benar
        print(f"{'OK  ' if ok else 'SALAH'} {label:26s} -> "
              f"{len(merah)}/{harap} merah (harap 0)")
    if not ok:
        for nama, hijau, detail in hasil:
            print(f"       {nama}: {detail}")
    return ok


def main():
    print("Gerbang pelembutan tepi pita Jupiter\n")
    hasil = []

    # 1. Kontrol negatif lebih dulu. Gerbang ketajaman mengambil satu ukuran
    #    per panggilan (bukan 2 seperti gerbang kutipan), jadi `harap=1`.
    hasil.append(laporkan("pohon utuh (pelembutan)",
                          jalankan_soften(), False, SOFTEN_PREFIX, harap=1))
    hasil.append(laporkan("pohon utuh (kutipan)",
                          jalankan_parity(), False, PARITY_PREFIX))

    # 2. Pelembutan dimatikan -> gerbang ketajaman wajib merah.
    hasil.append(laporkan("pelembutan dimatikan",
                          jalankan_soften(feather=0.0), True, SOFTEN_PREFIX,
                          harap=1))

    # 3..5 memutasi docstring model, lalu menjalankan prob di **proses baru**.
    MS.require_clean_sources([MODEL])
    asli = open(MODEL, encoding="utf-8").read()

    try:
        before_200, after_200 = ukuran(200)
        before_76, after_76 = ukuran(76)

        # 3. Angka lama yang tidak pernah diukur.
        lama = ganti_kutipan(
            ganti_kutipan(asli, f"{before_200:.2f}", "117.4"),
            f"{after_200:.2f}", "23.3")
        MS.write_source(MODEL, lama)
        hasil.append(laporkan("kutipan angka lama",
                              jalankan_parity(), True, PARITY_PREFIX))

        # 4. Pembulatan sah satu desimal -> wajib tetap hijau.
        bulat = ganti_kutipan(
            ganti_kutipan(asli, f"{before_200:.2f}", f"{before_200:.1f}"),
            f"{after_200:.2f}", f"{after_200:.1f}")
        MS.write_source(MODEL, bulat)
        hasil.append(laporkan("kutipan dibulatkan 1 desimal",
                              jalankan_parity(), False, PARITY_PREFIX))

        # 5. Docstring hilang sama sekali.
        tanpa = ganti_kutipan(
            ganti_kutipan(asli, f"{before_76:.2f}", ""),
            f"{after_76:.2f}", "")
        MS.write_source(MODEL, tanpa)
        hasil.append(laporkan("kutipan 76 px dihapus",
                              jalankan_parity(), True, PARITY_PREFIX))
    finally:
        MS.restore_verified(MODEL, asli)

    print()
    if not all(hasil):
        print(f"{hasil.count(False)} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(hasil)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
