#!/usr/bin/env python3
"""Buktikan gerbang bentuk bayangan cincin **bisa** merah.

Kenapa harness ini ada.

Gerbang `check_ring_shadow_shape_matches_the_port` lahir dari cacat yang tidak
tertangkap **980 pemeriksaan piksel**: bayangan bola pada cincin Saturnus
digambar dua kali, di port Python (yang diukur gerbang piksel) dan di view
SwiftUI (yang digambar jam). Versi pertama view menggambar **satu elips** di
ujung ruas bayangan; port menggambar **kapsul**. Keduanya hijau di gerbang
masing-masing, dan yang dikirim ke jam adalah bentuk yang tidak pernah diukur.

Gerbang piksel tidak bisa menutup ini, dan bukan karena ia kurang teliti: ia
membaca PNG yang dihasilkan port. Selama kedua sisi tidak dibandingkan,
kesepakatan dua sisi hanya diukur di satu sisi.

Kenapa cacat ini layak gerbang tersendiri, bukan cukup diperbaiki sekali.

Bentuknya sudah diperbaiki (view kini menyusun kapsul dari model), dan
perbaikan yang tidak dijaga akan kembali. Yang lebih penting: gerbang ini
mengukur **bentuk**, bukan ejaan. Ia tidak menuntut baris tertentu; ia
menuntut tiga sifat yang membedakan kapsul dari elips tergeser, jadi
penulisan ulang yang setia tetap hijau.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]              Gerbang hijau pada pohon nyata.

  1. elips tunggal         **Cacat aslinya**, persis bentuk yang pernah
     (gelung dibuang)      dikirim ke jam: satu `addEllipse` di ujung ruas.
                           **Wajib merah.** Elips ini 30% lebih sempit dan
                           tidak mencapai tepi luar cincin.

  2. radius mengecil       Bentuk "ada gelung" yang **salah**: sembilan elips
     sepanjang gelung     berderet dengan radius yang menyusut — kerucut,
                           bukan kapsul. Gerbang yang hanya mencari `for step`
                           akan hijau di sini, dan jam menggambar bayangan
                           yang mengecil ke ujung.

  3. geometri model        `VisualFrame.saturnRingShadow` diganti panggilan
     tidak dipakai         lain. **Wajib merah**: tanpa geometri model, arah
                           bayangan dan arah gradien bola bisa berbeda
                           pendapat tentang dari mana cahaya datang.

  4. `drawRings` hilang    Kontrol untuk sisi **pembaca**: kalau fungsinya
                           berganti nama, gerbang harus melapor, bukan
                           diam-diam hijau karena `_function_body` memulangkan
                           string kosong.

Ketiga mutasi memakai `view_source=`, bukan menulis berkas produksi: yang
diuji adalah kemampuan gerbang membaca bentuk, dan menulis ulang view akan
menguji hal yang berbeda (dan menyentuh berkas yang dipakai gerbang lain).
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

spec = importlib.util.spec_from_file_location(
    "check_visuals", os.path.join(HERE, "check-visuals.py"))
CV = importlib.util.module_from_spec(spec)
sys.argv = ["check-visuals.py"]
spec.loader.exec_module(CV)

VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")

#: Nama hasil yang diharapkan, dibaca dari gerbangnya sendiri lewat awalan.
PREFIX = "Saturnus: bayangan cincin di view berbentuk kapsul"


def jalankan(view_source=None):
    results = []
    CV.check_ring_shadow_shape_matches_the_port(results, view_source=view_source)
    return [(r.name, r.ok, r.detail) for r in results]


def laporkan(label, hasil, harap_merah, harap=1, wajib_sebut=None):
    """Periksa satu keadaan: jumlah pemeriksaan, jumlah merah, dan isinya."""
    if len(hasil) != harap:
        print(f"SALAH {label:30s} -> {len(hasil)} pemeriksaan, harus {harap}")
        return False
    merah = [h for h in hasil if not h[1]]
    nama_benar = all(h[0].startswith(PREFIX) for h in hasil)
    ok = len(merah) == harap_merah and nama_benar
    if ok and wajib_sebut is not None and merah:
        ok = all(wajib_sebut in h[2] for h in merah)
    print(f"{'OK  ' if ok else 'SALAH'} {label:30s} -> "
          f"{len(merah)}/{harap} MERAH (harap {harap_merah})"
          + ("" if nama_benar else ", nama pemeriksaan tidak dikenal"))
    if not ok:
        for nama, _, detail in hasil:
            print(f"       {nama}: {detail[:160]}")
    return ok


def ganti(teks, lama, baru, label):
    """Ganti satu potongan, dan **buktikan** ia terganti.

    Tanpa ini, keadaan bisa "lulus" karena penggantiannya tidak menemukan apa
    pun — lalu yang diukur adalah berkas yang tidak berubah, dan gerbangnya
    hijau karena alasan yang salah.
    """
    if lama not in teks:
        raise SystemExit(f"GAGAL: `{lama[:60]}` tidak ada di view — keadaan "
                         f"«{label}» tidak bisa membuktikan apa pun.")
    return teks.replace(lama, baru, 1)


def main():
    print("Gerbang bentuk bayangan cincin Saturnus\n")
    hasil = []
    asli = open(VIEW, encoding="utf-8").read()

    # 0. Kontrol negatif lebih dulu.
    hasil.append(laporkan("pohon utuh", jalankan(), 0))

    # 1. Elips tunggal di ujung ruas — cacat aslinya.
    start = asli.index("for step in 0...8")
    ellipse = asli.index("capsule.addEllipse")
    tunggal = (asli[:start]
               + "let cx = tailX\n            let cy = tailY\n            "
               + asli[ellipse:])
    hasil.append(laporkan("elips tunggal (gelung dibuang)",
                          jalankan(tunggal), 1, wajib_sebut="gelung TIDAK ADA"))

    # 2. Gelung tetap ada, radius menyusut: kerucut, bukan kapsul.
    kerucut = ganti(asli, "width: bodyRadiusPx * 2,",
                    "width: bodyRadiusPx * 2 * (0.3 + 0.7 * t),",
                    "radius mengecil")
    hasil.append(laporkan("radius mengecil sepanjang gelung",
                          jalankan(kerucut), 1,
                          wajib_sebut="radius tetap TIDAK ADA"))

    # 3. Geometri model tidak dipakai lagi.
    tanpa_model = ganti(asli, "VisualFrame.saturnRingShadow(for: ring)",
                        "someOtherShadow(for: ring)", "geometri model")
    hasil.append(laporkan("geometri model tidak dipakai",
                          jalankan(tanpa_model), 1,
                          wajib_sebut="tidak lagi memakai geometri model"))

    # 4. `drawRings` berganti nama: gerbang harus melapor, bukan diam.
    hasil.append(laporkan("`drawRings` hilang",
                          jalankan(ganti(asli, "private func drawRings(",
                                         "private func drawRingz(",
                                         "drawRings hilang")),
                          1, wajib_sebut="tidak ditemukan"))

    print()
    if not all(hasil):
        print(f"{hasil.count(False)} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(hasil)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
