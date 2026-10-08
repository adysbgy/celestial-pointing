#!/usr/bin/env python3
"""Buktikan `check_phase_direction_on_the_waning_half` **berbunyi**, bukan cuma hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan
adalah bahwa ia bisa merah — dan merah pada keadaan yang memang salah. Di sini
keadaannya justru yang paling halus di seluruh repo ini: sebuah sabit yang
**tercermin** tetap berbentuk sabit, tetap punya terminator, dan tetap
menghadap "ke suatu arah". Tidak ada teks di layar mana pun yang bisa
membuktikan bahwa arahnya terbalik.

Harness ini memanggil fungsi pemeriksaan yang **sama**
(`check_phase_direction_on_the_waning_half`) atas tiga keadaan yang berbeda,
dan mencetak **pemeriksaan mana** yang berbunyi — bukan berapa yang merah.
Menghitung jumlah menyembunyikan keadaan yang berbunyi karena alasan yang
salah; di sini itu penting, karena dua dari tiga keadaan juga menyalakan
gerbang arah lama, sementara keadaan yang membuktikan celahnya tidak.

Keadaan yang diuji:

  [baseline]                              gerbang hijau (kalau tidak, harness salah)
  1. `+ pi` dihapus dari port             cabang `lit_side = -1` hilang.
                                          **Keadaan inilah buktinya**: hanya
                                          gerbang baru yang berbunyi, gerbang
                                          arah lama 0 merah.
  2. kondisi `lit_side` dibalik           kedua arah rusak sekaligus.
  3. kedua jalur dibalik (`selalu + pi`)  yang membesar ikut terbalik; ini yang
                                          menuntut pemeriksaan penjaga arah
                                          sebaliknya.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`
(`SIGKILL` tetap bisa melewati keduanya — itu batas yang diketahui, bukan
klaim bahwa harness ini kebal).

Pakai:
    python3 Tools/bukti-mutasi-fase.py
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

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

# Gerbang lama ikut diukur supaya keadaan 1 bisa membuktikan **celahnya**:
# cacat yang hanya ditangkap gerbang baru adalah cacat yang sebelumnya tidak
# ada satu pun gerbang yang menjaga.
#
# Keempatnya adalah gerbang yang **dikutip docstring gerbang baru** sebagai
# "tetap 0 merah saat `+ pi` dihapus". Dua yang terakhir (`check_moon_phase_*`)
# dulu dikutip tanpa pernah dijalankan di sini — kelas cacat yang berulang di
# repo ini (gerbang mengutip angka yang tidak pernah ia ukur). Sekarang
# keempatnya dijalankan, jadi klaimnya terbukti atau terbantah di CI.
for fn in ("check_phase_direction_on_the_waning_half",
           "check_crescent_direction",
           "check_inner_planet_phase",
           "check_moon_phase_fraction",
           "check_moon_phase_survives_uncertainty"):
    results = []
    try:
        getattr(C, fn)(results)
    except Exception as exc:
        print("ERROR %s %s" % (fn, type(exc).__name__))
        continue
    for r in results:
        print(("GAGAL " if not r.ok else "OK    ") + fn + " :: " + r.name)
"""

# (nama keadaan, (cari, ganti)) — `None` berarti jalankan apa adanya.
STATES = [
    ("[baseline]", None),
    ("1. `+ pi` dihapus (litSide diabaikan)",
     ('    if phase["lit_side"] < 0:\n'
      '        return bright_limb_angle + math.pi\n'
      '    return bright_limb_angle',
      '    return bright_limb_angle')),
    ("2. kondisi litSide dibalik",
     ('    if phase["lit_side"] < 0:',
      '    if phase["lit_side"] > 0:')),
    ("3. kedua jalur dibalik (selalu + pi)",
     ('    if phase["lit_side"] < 0:\n'
      '        return bright_limb_angle + math.pi\n'
      '    return bright_limb_angle',
      '    return bright_limb_angle + math.pi')),
]

NEW_GATE = "check_phase_direction_on_the_waning_half"
# Keadaan yang **harus** menyalakan gerbang baru. Sisanya harus hijau.
# Keadaan 1 sengaja menuntut gerbang lama **tetap hijau** — itulah buktinya
# bahwa celahnya nyata, dan harness yang menuntutnya merah akan menuntut
# sesuatu yang tidak benar.
WANT_RED = {
    "[baseline]": set(),
    "1. `+ pi` dihapus (litSide diabaikan)": {NEW_GATE},
    "2. kondisi litSide dibalik": {NEW_GATE, "check_crescent_direction",
                                   "check_inner_planet_phase"},
    "3. kedua jalur dibalik (selalu + pi)": {NEW_GATE,
                                             "check_crescent_direction",
                                             "check_inner_planet_phase"},
}

_original = None


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal."""
    if _original is not None:
        with open(RENDER, "w", encoding="utf-8") as handle:
            handle.write(_original)


def probe():
    """Jalankan pemeriksaan → (himpunan_gate_merah, baris_mentah)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None, proc.stderr.strip().splitlines()[-1:] or ["(tanpa galat)"]
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    if any(line.startswith("ERROR ") for line in lines):
        return None, [line for line in lines if line.startswith("ERROR ")]
    red = {line.split(" :: ")[0].replace("GAGAL ", "")
           for line in lines if line.startswith("GAGAL ")}
    return red, lines


def main():
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
                    print(f"{label:42s} ANCHOR TIDAK DITEMUKAN")
                    unexpected += 1
                    continue
                content = _original.replace(old, new, 1)
            with open(RENDER, "w", encoding="utf-8") as handle:
                handle.write(content)

            red, lines = probe()
            if red is None:
                print(f"{label:42s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            want = WANT_RED[label]
            mark = "OK  " if red == want else "SALAH"
            if mark == "SALAH":
                unexpected += 1
            print(f"{mark} {label:42s} merah: {sorted(red) or '—'}")
            if red != want:
                print(f"       diharapkan: {sorted(want) or '—'}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
