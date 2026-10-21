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
  5. **kutipan 76 px dihapus** — satu-satunya angka yang membuktikan pelembutan
     masih terukur di kartu jam. Gerbang **wajib merah**, tetapi **hanya pada
     pemeriksaan 76 px**: kutipan 200 px masih utuh, jadi menuntut dua merah
     di sini akan menuntut gerbangnya berbunyi tentang angka yang benar. Itu
     sebabnya `harap_merah` dihitung, bukan boolean — keadaan ini satu-satunya
     yang mengharapkan **sebagian** merah, dan bentuk boolean lama tidak bisa
     mengatakannya (ia menuntut 2/2, lalu merah pada pohon yang benar).

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


def laporkan(label, hasil, harap_merah, awalan, harap=2, merah_wajib=None,
             quiet=False):
    """Periksa satu keadaan harness.

    Tiga besaran yang **berbeda** dan tidak boleh saling menumpang:

      * `harap`      — berapa pemeriksaan yang dikeluarkan gerbangnya. Kalau
                       jumlahnya berubah, gerbangnya berhenti mengukur salah
                       satu keadaan, dan itu merah.
      * `harap_merah`— berapa di antaranya yang **wajib** merah. Sebagian
                       merah itu keadaan yang sah (mutasi yang hanya merusak
                       satu ukuran), jadi ini angka, bukan boolean.
      * `merah_wajib`— potongan nama yang harus dimiliki pemeriksaan yang
                       merah. Tanpa ini, "1 dari 2 merah" juga terpenuhi bila
                       yang merah justru pemeriksaan yang salah — dan harness
                       akan melaporkan sesuai harapan sambil membuktikan
                       kebalikannya.

    `quiet` hanya dipakai `bukti_diri()`: di sana `laporkan` dipanggil atas
    data rekaan untuk membuktikan ia bisa merah, dan cetakan "SALAH" milik
    panggilan itu bukan kegagalan harness — tanpa `quiet`, laporan bukti-diri
    akan terbaca seperti empat gerbang merah padahal semuanya sesuai harapan.
    """
    def emit(line):
        if not quiet:
            print(line)

    if len(hasil) != harap:
        emit(f"SALAH {label:26s} -> {len(hasil)} pemeriksaan, harus {harap}; "
             "gerbangnya berhenti mengukur salah satu keadaan")
        return False
    merah = [h for h in hasil if not h[1]]
    nama_benar = all(h[0].startswith(awalan) for h in hasil)
    ok = len(merah) == harap_merah and nama_benar
    if ok and merah_wajib is not None:
        ok = all(merah_wajib in h[0] for h in merah)
    if harap_merah:
        emit(f"{'OK  ' if ok else 'SALAH'} {label:26s} -> "
             f"{len(merah)}/{harap} MERAH (harap {harap_merah})"
             + ("" if nama_benar else ", nama pemeriksaan tidak dikenal")
             + ("" if merah_wajib is None or not merah else
                f" [{', '.join(h[0] for h in merah)}]"))
    else:
        emit(f"{'OK  ' if ok else 'SALAH'} {label:26s} -> "
             f"{len(merah)}/{harap} merah (harap 0)")
    if not ok:
        for nama, hijau, detail in hasil:
            emit(f"       {nama}: {detail}")
    return ok


def bukti_diri():
    """Buktikan `laporkan` **bisa** merah pada tiap besaran yang ia pisahkan.

    Kenapa ini ada. Sampai siklus ini `laporkan` menerima `harap_merah` sebagai
    boolean, dan keadaan 5 mengharapkan **sebagian** merah (hanya kutipan
    76 px yang dipatahkan). Boolean tidak bisa mengatakannya: `True` berarti
    "semua merah", jadi harness itu menuntut 2/2 merah pada pohon yang benar
    dan **merah sendiri**. Cacatnya tidak pernah terlihat CI karena commit
    yang memuatnya belum pernah di-push.

    Yang dibuktikan di sini adalah tiga kesalahan yang **berbeda**, karena
    ketiganya bisa lolos dengan laporan hijau kalau hanya jumlah merah yang
    diperiksa:

      1. jumlah merah benar, tetapi yang merah pemeriksaan yang salah
         -> `merah_wajib` menolaknya.
      2. jumlah pemeriksaan berubah (gerbangnya berhenti mengukur satu
         keadaan) -> `harap` menolaknya.
      3. nama pemeriksaan tidak dikenal (gerbangnya berganti nama, dan
         harness membandingkan dengan nama yang tidak pernah muncul)
         -> `awalan` menolaknya.

    Tanpa keadaan 1, `merah_wajib` adalah hiasan: ia hanya berjalan saat
    hijau, dan tidak ada yang membuktikan ia pernah berbunyi.
    """
    dua = [("tepi pita: docstring mengutip ukuran 200 px", False, "x"),
           ("tepi pita: docstring mengutip ukuran 76 px", True, "y")]
    # Fixture yang **benar**: hanya kutipan 76 px yang patah, persis keadaan 5.
    # Tanpa fixture ini, kasus 4 di bawah hanya mengulang kasus 1 dengan
    # harapan terbalik — dan `merah_wajib` tidak terbukti pernah **menerima**.
    benar = [("tepi pita: docstring mengutip ukuran 200 px", True, "x"),
             ("tepi pita: docstring mengutip ukuran 76 px", False, "y")]
    kasus = [
        ("jumlah merah cocok, pemeriksaan salah yang merah",
         dict(label="diri", hasil=dua, harap_merah=1, awalan=PARITY_PREFIX,
              harap=2, merah_wajib="76 px"), False),
        ("jumlah pemeriksaan berubah",
         dict(label="diri", hasil=dua[:1], harap_merah=0,
              awalan=PARITY_PREFIX, harap=2), False),
        ("nama pemeriksaan tidak dikenal",
         dict(label="diri", hasil=dua, harap_merah=1, awalan="gerbang lain",
              harap=2, merah_wajib="76 px"), False),
        ("sebagian merah, pada pemeriksaan yang benar",
         dict(label="diri", hasil=benar, harap_merah=1, awalan=PARITY_PREFIX,
              harap=2, merah_wajib="76 px"), True),
    ]
    gagal = []
    for label, kwargs, want in kasus:
        got = laporkan(quiet=True, **kwargs)
        mark = "OK  " if got == want else "SALAH"
        if got != want:
            gagal.append(f"{label}: {got}, seharusnya {want}")
        print(f"{mark} bukti-diri: {label:52s} {got} (harap {want})")
    return gagal


def main():
    print("Gerbang pelembutan tepi pita Jupiter\n")
    hasil = []

    # 1. Kontrol negatif lebih dulu. Gerbang ketajaman mengambil satu ukuran
    #    per panggilan (bukan 2 seperti gerbang kutipan), jadi `harap=1`.
    hasil.append(laporkan("pohon utuh (pelembutan)",
                          jalankan_soften(), 0, SOFTEN_PREFIX, harap=1))
    hasil.append(laporkan("pohon utuh (kutipan)",
                          jalankan_parity(), 0, PARITY_PREFIX))

    # 2. Pelembutan dimatikan -> gerbang ketajaman wajib merah.
    hasil.append(laporkan("pelembutan dimatikan",
                          jalankan_soften(feather=0.0), 1, SOFTEN_PREFIX,
                          harap=1))

    # 3..5 memutasi docstring model, lalu menjalankan prob di **proses baru**.
    MS.require_clean_sources([MODEL])
    asli = open(MODEL, encoding="utf-8").read()

    try:
        before_200, after_200 = ukuran(200)
        before_76, after_76 = ukuran(76)

        # 3. Angka lama yang tidak pernah diukur — **keempatnya**, seperti
        #    cacat aslinya: docstring lama salah di 200 px dan 76 px sekaligus,
        #    jadi hanya memutasi satu ukuran akan membuktikan separuhnya saja.
        lama = ganti_kutipan(
            ganti_kutipan(
                ganti_kutipan(
                    ganti_kutipan(asli, f"{before_200:.2f}", "117.4"),
                    f"{after_200:.2f}", "23.3"),
                f"{before_76:.2f}", "76.4"),
            f"{after_76:.2f}", "37.2")
        MS.write_source(MODEL, lama)
        hasil.append(laporkan("kutipan angka lama",
                              jalankan_parity(), 2, PARITY_PREFIX))

        # 4. Pembulatan sah satu desimal -> wajib tetap hijau.
        bulat = ganti_kutipan(
            ganti_kutipan(asli, f"{before_200:.2f}", f"{before_200:.1f}"),
            f"{after_200:.2f}", f"{after_200:.1f}")
        MS.write_source(MODEL, bulat)
        hasil.append(laporkan("kutipan dibulatkan 1 desimal",
                              jalankan_parity(), 0, PARITY_PREFIX))

        # 5. Kutipan 76 px dihapus. Hanya pemeriksaan 76 px yang boleh merah —
        #    yang 200 px angkanya masih utuh, jadi menuntut dua merah di sini
        #    akan menuntut gerbangnya berbunyi tentang angka yang benar.
        tanpa = ganti_kutipan(
            ganti_kutipan(asli, f"{before_76:.2f}", ""),
            f"{after_76:.2f}", "")
        MS.write_source(MODEL, tanpa)
        hasil.append(laporkan("kutipan 76 px dihapus",
                              jalankan_parity(), 1, PARITY_PREFIX,
                              harap=2, merah_wajib="76 px"))
    finally:
        MS.restore_verified(MODEL, asli)

    print()
    diri = bukti_diri()
    print()
    if not all(hasil) or diri:
        if not all(hasil):
            print(f"{hasil.count(False)} keadaan tidak sesuai harapan")
        if diri:
            print(f"{len(diri)} bukti-diri gagal")
        return 1
    print(f"{len(hasil)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())