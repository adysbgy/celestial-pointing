#!/usr/bin/env python3
"""Buktikan gerbang **angka docstring urutan cincin** berbunyi, bukan hijau saja.

Kenapa harness ini ada.

`check_saturn_ring_passes_behind_the_globe` lahir dengan lima angka di
docstringnya, dan **empat di antaranya tidak pernah dihasilkan oleh alat ukur
di bawahnya**. Diukur ulang:

    49,7% (24 064 dari 48 400)      dikutip: 50% (110 dari 220)
    36 hasil tetangga               dikutip: 35   (kini 42 — enam
                                                  pemeriksaan tumbuh)
    margin 0 -> 14 px @200 / 6 @76  dikutip: "nol piksel"
    cacat @76px -> 232 px           dikutip: 245 px

Gerbang paritas `check_saturn_ring_order_docstring_quotes_measured_values`
menutupnya dengan **menghitung ulang** keempat angka itu. Ia hijau pada hari
ditulis — dan itu bukan bukti apa pun. Yang harus dibuktikan adalah bahwa ia
**bisa merah**, dan merah pada angka yang memang salah.

Kenapa empat keadaan, bukan satu. Keempat angka punya jalan yang berbeda menuju
kesalahan, dan satu mutasi hanya membuktikan satu jalan:

  1. jumlah hasil tetangga salah   -> pemeriksaan "jumlah hasil tetangga" merah.
                                      Ini yang menangkap angka yang ditulis
                                      dari ingatan saat enam pemeriksaan
                                      tetangga berubah jumlah hasilnya.
  2. persentase geometri salah     -> pemeriksaan "persentase geometri" merah.
                                      Angka ini turun dari geometri cincin;
                                      mengubah rasio cincin mengubahnya tanpa
                                      satu pun baris kode lain berbunyi.
  3. sel tabel `margin 0` salah    -> pemeriksaan tabel "200 px" merah. Ini
                                      arah yang **terbalik** di docstring
                                      aslinya ("nol piksel pada margin 0"),
                                      jadi keadaan ini adalah cacat yang
                                      benar-benar pernah ada, bukan karangan.
  4. sel tabel `cacat` salah       -> pemeriksaan tabel "76 px" merah. Ini
                                      mengikat arah kedua: gerbangnya menuntut
                                      cacatnya **terbaca**, dan angka itu satu-
                                      satunya tempat besarnya cacat dinyatakan.

Tiap keadaan menuntut pemeriksaan **bernama**, bukan sekadar "ada yang merah":
gerbang yang berbunyi pada pemeriksaan yang salah mengukur hal lain daripada
yang diklaimnya. Karena itu `must_fire` menyebut satu nama, dan `probe()`
menuntut yang **tidak** disebut tetap hijau.

Pakai:
    python3 Tools/bukti-mutasi-angka-urutan-cincin.py    # 0 = semua sesuai harapan
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

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
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
C.check_saturn_ring_order_docstring_quotes_measured_values(results)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Nama pemeriksaan yang dikutip di `must_fire`, ditulis sebagai potongan
#: unik. Kalimat penuh memuat angka yang berubah bersama ambangnya, dan
#: harness yang ikut berubah bersama gerbangnya tidak menjaga apa pun.
COUNTED = "mengutip jumlah hasil tetangga"
FRACTION = "mengutip persentase geometri"
TABLE_200 = "tabel margin '200 px'"
TABLE_76 = "tabel margin '76 px'"

#: Setiap keadaan: (nama, jangkar_lama, jangkar_baru, pemeriksaan yang WAJIB
#: merah). Jangkar harus muncul tepat sekali; jumlahnya diperiksa sebelum apa
#: pun dimutasi, karena `str.replace` atas jangkar yang muncul dua kali akan
#: mengubah keduanya dan harness lalu melaporkan keadaan yang tidak pernah ia
#: uji.
STATES = [
    ("[baseline]", None, None, []),
    ("1. jumlah hasil tetangga 42 -> 35", "**42** hasil enam", "**35** hasil enam",
     [COUNTED]),
    ("2. persentase geometri 49,7% -> 50%", "**49,7%** titik", "**50%** titik",
     [FRACTION]),
    ("3. tabel 200 px: margin 0 14 -> 0",
     "\n        200 px    14          1533\n",
     "\n        200 px    0           1533\n",
     [TABLE_200]),
    ("4. tabel 76 px: cacat 232 -> 245",
     "\n        76 px     6           232\n",
     "\n        76 px     6           245\n",
     [TABLE_76]),
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
        mutasi_sumber.restore_verified(TARGET, _original)


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
    mutasi_sumber.require_clean_sources([TARGET])

    with open(TARGET, encoding="utf-8") as handle:
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
                TARGET, _original if old is None else _original.replace(old, new, 1))
            failed, lines = probe()
            if failed is None:
                print(f"{label:44s} PROB GAGAL JALAN: {lines}")
                unexpected += 1
                continue

            fired = [name for name in
                     (COUNTED, FRACTION, TABLE_200, TABLE_76)
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
