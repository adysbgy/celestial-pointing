#!/usr/bin/env python3
"""Buktikan gerbang **angka docstring inti bintang** berbunyi, bukan hijau saja.

Kenapa harness ini ada.

`check_star_core_docstring_quotes_measured_values` lahir dari cacat yang nyata
di working tree: docstring `starCoreRGB` mengutip angka "sebelum" yang tidak
pernah dihasilkan render mana pun.

    dikutip (set A):  Sirius 196,7   redup 196,3   Betelgeuse 164,7
    dikutip (set B):  Sirius 190,1   redup 189,3   Betelgeuse —
    terukur:          Sirius 190,03  redup 189,59  Betelgeuse 173,39

Dua set angka yang saling bertentangan **di berkas yang sama**, dan tidak satu
pun cocok. Gerbang paritasnya sekarang menghitung ulang keenam angka itu dari
piksel — tetapi gerbang yang hijau pada hari ia ditulis tidak membuktikan apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada angka
yang memang salah.

Kenapa empat keadaan, bukan satu. Keempat jalan menuju angka yang salah
berbeda, dan satu mutasi hanya membuktikan satu jalan:

  1. kolom "sebelum" Sirius salah  -> persis angka 196,7 yang dulu dikutip.
                                      Ini bukan angka karangan: ia **pernah
                                      ada** di berkas ini. Kalau gerbang
                                      meloloskannya, cacat aslinya kembali.
  2. kolom "sebelum" redup salah   -> 189,3, angka dari set B. Set B lahir
                                      dari pengukuran di titik lain; mengutip
                                      angka dari titik ukur yang berbeda
                                      adalah cara paling mudah membuat tabel
                                      yang tampak benar dan tidak bisa
                                      direproduksi.
  3. kolom "sesudah" salah         -> arah yang **berlawanan**: kolom
                                      "sebelum" adalah keadaan yang sudah tidak
                                      ada di kode, sedangkan "sesudah" adalah
                                      keadaan sekarang. Gerbang yang hanya
                                      memeriksa kolom "sebelum" akan hijau
                                      selamanya walaupun perbaikannya dibatalkan
                                      dan kolom "sesudah" jadi dusta. Keadaan
                                      ini mengikat arah itu.
  4. baris keempat tabel salah     -> Rigel. Gerbang versi pertama **tidak**
                                      mengikat baris ini dan hanya menyatakan
                                      di docstringnya bahwa ia "tidak
                                      diklaim". Baris yang tampil di tabel
                                      yang sama dan tidak diikat adalah baris
                                      yang boleh membusuk sambil gerbangnya
                                      hijau — jadi keadaan ini membuktikan
                                      baris itu benar-benar diukur.

Tiap keadaan menuntut pemeriksaan **bernama**, bukan sekadar "ada yang merah":
gerbang yang berbunyi pada pemeriksaan yang salah mengukur hal lain daripada
yang diklaimnya. Karena itu `must_fire` menyebut satu nama, dan `probe()`
menuntut yang **tidak** disebut tetap hijau.

Pakai:
    python3 Tools/bukti-mutasi-angka-inti-bintang.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

TARGET = os.path.join(ROOT, "Tools", "check-visuals.py")
SOURCE = os.path.join(ROOT, "Packages", "PointingKit", "Sources",
                      "PointingKit", "CelestialVisual.swift")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
#
# Yang dimutasi di sini bukan `check-visuals.py` melainkan **docstring di
# sumber Swift**, karena itulah masukan gerbangnya. `check-visuals.py` ikut
# ditulis ulang dengan isi yang sama supaya `mutasi_sumber` punya berkas
# tunggal yang dipulihkan dan diverifikasi.
PROBE = r"""
import importlib.util, os, sys
ROOT = sys.argv[1]

def load(name, filename):
    path = os.path.join(ROOT, "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
results = []
C.check_star_core_docstring_quotes_measured_values(results, 200, 2)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Nama pemeriksaan yang dikutip di `must_fire`, ditulis sebagai potongan
#: unik. Kalimat penuh memuat toleransi yang bisa berubah; harness yang ikut
#: berubah bersama gerbangnya tidak menjaga apa pun.
QUOTED = "mengutip angka terukur"

#: Setiap keadaan: (nama, jangkar_lama, jangkar_baru, pemeriksaan yang WAJIB
#: merah). Jangkar harus muncul tepat sekali; jumlahnya diperiksa sebelum apa
#: pun dimutasi, karena `str.replace` atas jangkar yang muncul dua kali akan
#: mengubah keduanya dan harness lalu melaporkan keadaan yang tidak pernah ia
#: uji.
STATES = [
    ("[baseline]", None, None, []),
    # 1. Angka 196,7 — persis yang dulu dikutip, dan tidak bisa direproduksi.
    ("1. Sirius sebelum 190,03 -> 196,70",
     "Sirius (m −1,46)  190,03    251,56",
     "Sirius (m −1,46)  196,70    251,56",
     [QUOTED]),
    # 2. Angka 189,3 — set B, dari titik ukur yang berbeda.
    ("2. redup sebelum 189,59 -> 189,30",
     "redup  (m +3,50)  189,59    214,61",
     "redup  (m +3,50)  189,30    214,61",
     [QUOTED]),
    # 3. Kolom "sesudah" — arah yang berlawanan.
    ("3. Betelgeuse sesudah 218,52 -> 220,00",
     "Betelgeuse (+0,50) 173,39   218,52",
     "Betelgeuse (+0,50) 173,39   220,00",
     [QUOTED]),
    # 4. Baris keempat tabel. Gerbang versi pertama **tidak** mengikat baris
    #    ini dan menyatakannya sebagai batas yang tidak diklaim; keadaan ini
    #    membuktikan baris itu sekarang benar-benar diukur, bukan sekadar
    #    dinyatakan terjaga.
    ("4. Rigel sebelum 190,06 -> 190,60",
     "Rigel    (+0,13)  190,06    229,00",
     "Rigel    (+0,13)  190,60    229,00",
     [QUOTED]),
]

_original = None


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(path, "w")`: belasan harness di
    `Tools/` memutasi berkas produksi yang sama dan setiap prob membacanya
    dari proses baru, jadi penulisan biasa membuat pembaca bisa melihat
    berkas setengah jadi. Pemulihannya juga **diverifikasi** — kegagalan
    pemulihan bersifat diam dan lalu menyalahkan kode yang benar.
    """
    if _original is not None:
        mutasi_sumber.restore_verified(SOURCE, _original)


def probe():
    """Jalankan gerbangnya langsung → (daftar_baris_gagal, semua_baris)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT,
                          env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
    if proc.returncode != 0:
        return None, proc.stderr.strip().splitlines()[-1:] or ["(tanpa galat)"]
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    failed = [line for line in lines if line.startswith("GAGAL")]
    return failed, lines


def main():
    # Dua berkas: yang dibaca gerbang (docstring Swift) dan yang memuat
    # gerbangnya. Keduanya harus bersih sebelum apa pun ditulis.
    mutasi_sumber.require_clean_sources([SOURCE, TARGET])

    with open(SOURCE, encoding="utf-8") as handle:
        _original = handle.read()
    globals()["_original"] = _original

    # Jangkar diperiksa **sebelum** apa pun dimutasi.
    for label, old, new, _ in STATES:
        if old is None:
            continue
        count = _original.count(old)
        if count != 1:
            print(f"GERBANG: jangkar keadaan «{label}» muncul {count}x, "
                  "harus tepat 1x — harness tidak boleh jalan.",
                  file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, old, new, must_fire in STATES:
            mutasi_sumber.write_source(
                SOURCE, _original if old is None else _original.replace(old, new, 1))
            failed, lines = probe()
            if failed is None:
                print(f"{label:44s} PROB GAGAL JALAN: {lines}")
                unexpected += 1
                continue

            fired = [name for name in (QUOTED,)
                     if any(name in line for line in failed)]
            unexpected_fire = [name for name in fired if name not in must_fire]

            if old is None:
                # Baseline: gerbang wajib hijau. Kalau tidak, harnessnya yang
                # salah, bukan kodenya.
                ok = not failed
                print(f"{label:44s} {'OK  ' if ok else 'SALAH'} "
                      f"{len(failed)} merah")
            else:
                # Yang dituntut bukan «ada yang merah», melainkan **yang mana**:
                # himpunan yang menyala harus persis `must_fire`. Pemeriksaan
                # lain yang ikut menyala berarti gerbangnya berbunyi pada hal
                # yang tidak diklaimnya.
                ok = sorted(fired) == sorted(must_fire)
                print(f"{label:44s} {'OK  ' if ok else 'SALAH'} "
                      f"{len(fired)} merah: {', '.join(fired) or '(tidak ada)'}")
                if not ok:
                    print(f"       harap merah: {', '.join(must_fire)}; "
                          f"tak terduga: {', '.join(unexpected_fire) or '(tidak ada)'}"
                          f"; tidak menyala: "
                          f"{', '.join(n for n in must_fire if n not in fired) or '(tidak ada)'}")
            if not ok:
                unexpected += 1
    finally:
        restore()

    print(f"\n{len(STATES)} keadaan, {unexpected} tidak sesuai harapan")
    sys.exit(1 if unexpected else 0)


if __name__ == "__main__":
    main()
