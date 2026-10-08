#!/usr/bin/env python3
"""Buktikan `check_star_size_follows_magnitude` **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah. Gerbang yang mengukur **teks** sumber lalu
menyimpulkan sesuatu tentang gambar paling mudah salah di sini: gerbang teks
yang salah membaca akan hijau selamanya, dan tidak ada satu pun gambar yang
bisa memberitahunya.

Harness ini menempuh jalur yang sama dengan gerbang penuh — memanggil fungsi
pemeriksaan yang **sama** (`check_star_size_follows_magnitude`) — tetapi
hanya atas satu pemeriksaan itu, jadi ia berjalan dalam hitungan detik alih-
alih ~6 menit. Gerbang yang terlalu lambat untuk dijalankan adalah gerbang
yang dilewati.

Keadaan yang diuji:

  [baseline]                       gerbang hijau (kalau tidak, harness salah)
  1. fixture kembali ke m=0.0      cacat aslinya: semua bintang satu ukuran
  2. penggambar mengabaikan ukuran `star_geometry(0.5)` — `relative_size`
                                   benar tapi tidak sampai ke gambar
  3. pembaca magnitudo bergeser    `catalogue_magnitudes` mengembalikan nilai
                                   yang salah, jadi fixture menyimpang dari
                                   katalog tanpa ada yang tahu

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan. Kegagalan di tengah tidak boleh
meninggalkan mutasi hidup — pelajaran yang sudah dibayar di repo ini
(`SIGKILL` melewati `finally`, jadi ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-bintang.py
"""

from __future__ import annotations

import os
import re
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
GATE = os.path.join(ROOT, "Tools", "check-visuals.py")

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
C.check_star_size_follows_magnitude(results)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

# (nama keadaan, (cari, ganti)) — `None` berarti jalankan apa adanya.
STATES = [
    ("[baseline]", None),
    ("1. fixture kembali ke m=0.0",
     ("relative_size=size_from_magnitude(_MAG[star]), is_confirmed=True))",
      "relative_size=size_from_magnitude(0.0), is_confirmed=True))")),
    ("2. penggambar mengabaikan relative_size",
     ('geometry = star_geometry(kw.get("relative_size", 0.5))',
      "geometry = star_geometry(0.5)")),
    ("3. pembaca magnitudo bergeser +1",
     ("    return {name: float(value) for name, value in found}",
      "    return {name: float(value) + 1.0 for name, value in found}")),
]

_original = None


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(RENDER, "w")`: tujuh harness di
    `Tools/` memutasi berkas produksi yang sama dan setiap prob membacanya
    dari proses baru, jadi penulisan biasa membuat pembaca bisa melihat
    berkas setengah jadi. Pemulihannya juga **diverifikasi** — kegagalan
    pemulihan bersifat diam dan lalu menyalahkan kode yang benar.
    """
    if _original is not None:
        mutasi_sumber.restore_verified(RENDER, _original)


def probe():
    """Jalankan pemeriksaan langsung → (jumlah_gagal, daftar_baris)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None, proc.stderr.strip().splitlines()[-1:] or ["(tanpa galat)"]
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    failed = [line for line in lines if line.startswith("GAGAL")]
    return failed, lines


def main():
    mutasi_sumber.require_clean_sources([RENDER])
    global _original
    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    with open(RENDER, encoding="utf-8") as handle:
        _original = handle.read()

    unexpected = 0
    try:
        for label, mutation in STATES:
            if mutation is None:
                content = _original
            else:
                old, new = mutation
                if old not in _original:
                    print(f"{label:38s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                    unexpected += 1
                    continue
                content = _original.replace(old, new, 1)
            mutasi_sumber.write_source(RENDER, content)

            failed, lines = probe()
            if failed is None:
                print(f"{label:38s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            count = len(failed)
            want_red = mutation is not None
            mark = "OK  " if (count > 0) == want_red else "SALAH"
            if mark == "SALAH":
                unexpected += 1
            detail = (f"{count} pemeriksaan merah"
                      if count else "0 merah")
            print(f"{mark} {label:38s} {detail}")
            for line in failed:
                print(f"       {line}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
