#!/usr/bin/env python3
"""Buktikan `check_planet_phase_limb_reads_the_model_constant` **berbunyi**.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan
adalah bahwa ia bisa merah — dan merah pada keadaan yang memang salah. Di sini
keadaan salahnya diam: konstanta `MOON_SPHERE_GRADIENT_END_RADIUS` ada,
dinamai, dibandingkan gerbang drift terhadap model Swift, dan diuji di Linux,
sementara jalur **planet dalam** menulis angkanya sendiri. Tidak ada galat
kompilasi, tidak ada uji yang merah, dan pikselnya bergerak **nol**.

Harness ini memanggil fungsi pemeriksaan yang **sama** lewat proses baru yang
mengimpor ulang berkas yang sudah dimutasi di disk, lalu mencetak
**pemeriksaan mana** yang berbunyi — bukan berapa yang merah. Menghitung
jumlah menyembunyikan keadaan yang berbunyi karena alasan yang salah.

Keadaan yang diuji:

  [baseline]                        gerbang hijau (kalau tidak, harness salah)
  1. port: jalur planet pakai literal 1.15    5 pemeriksaan piksel merah
  2. view: `drawPlanet` pakai literal 1.15    2 pemeriksaan teks merah
  3. keduanya                                 7 merah
  4. port: jalur **Bulan** pakai literal      **DIHARAPKAN HIJAU** — gerbang
     ini mengukur planet dalam, bukan Bulan. Keadaan ini ada supaya batas
     cakupannya tertulis di sini dan teruji, bukan tersirat.

Berkas sumber produksi (`Tools/render-visuals.py`,
`Apps/Shared/CelestialVisualView.swift`) **dimutasi dengan sengaja** lalu
dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`
(`SIGKILL` tetap bisa melewati keduanya — batas yang diketahui, bukan klaim
bahwa harness ini kebal).

Pakai:
    python3 Tools/bukti-mutasi-radius-akhir.py
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")

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
try:
    C.check_planet_phase_limb_reads_the_model_constant(results)
except Exception as exc:
    print("ERROR %s: %s" % (type(exc).__name__, exc))
    sys.exit(0)
for r in results:
    print(("GAGAL " if not r.ok else "OK    ") + r.name)
"""

PLANET_ANCHOR = ("        gradient = radial_gradient([(light, 1.0), (dark, 1.0)],\n"
                 "                                   center=(cx, cy),\n"
                 "                                   start_radius=0.0,\n"
                 "                                   end_radius=radius * MOON_SPHERE_GRADIENT_END_RADIUS)")
PLANET_LITERAL = ("        gradient = radial_gradient([(light, 1.0), (dark, 1.0)],\n"
                  "                                   center=(cx, cy),\n"
                  "                                   start_radius=0.0,\n"
                  "                                   end_radius=radius * 1.15)")

MOON_ANCHOR = ("                           center=(cx, cy), start_radius=0.0,\n"
               "                           end_radius=radius * MOON_SPHERE_GRADIENT_END_RADIUS)")
MOON_LITERAL = ("                           center=(cx, cy), start_radius=0.0,\n"
                "                           end_radius=radius * 1.15)")

VIEW_ANCHOR = "endRadius: radius * CGFloat(CelestialVisual.moonSphereGradientEndRadius)))"
VIEW_LITERAL = "endRadius: radius * 1.15))"

# (nama keadaan, [(berkas, cari, ganti)]) — daftar kosong = jalankan apa adanya.
STATES = [
    ("[baseline]", []),
    ("1. port: jalur planet pakai literal 1.15",
     [(RENDER, PLANET_ANCHOR, PLANET_LITERAL)]),
    ("2. view: drawPlanet pakai literal 1.15",
     [(VIEW, VIEW_ANCHOR, VIEW_LITERAL)]),
    ("3. keduanya",
     [(RENDER, PLANET_ANCHOR, PLANET_LITERAL), (VIEW, VIEW_ANCHOR, VIEW_LITERAL)]),
    ("4. port: jalur Bulan pakai literal (di luar cakupan)",
     [(RENDER, MOON_ANCHOR, MOON_LITERAL)]),
]

# Pemeriksaan yang **harus** merah. Awalan, bukan nama lengkap: nama
# pemeriksaannya memuat nama kasus render, dan mendaftar kelimanya di sini
# berarti mendaftar ulang katalog di tempat kedua.
WANT_RED = {
    "[baseline]": set(),
    "1. port: jalur planet pakai literal 1.15": {"radius akhir gradien planet-"},
    "2. view: drawPlanet pakai literal 1.15": {
        "drawPlanet membaca radius akhir gradien dari model",
        "drawPlanet tidak menulis radius akhirnya sendiri"},
    "3. keduanya": {
        "radius akhir gradien planet-",
        "drawPlanet membaca radius akhir gradien dari model",
        "drawPlanet tidak menulis radius akhirnya sendiri"},
    "4. port: jalur Bulan pakai literal (di luar cakupan)": set(),
}

_originals = {}


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal."""
    for path, content in _originals.items():
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(content)


def probe():
    """Jalankan pemeriksaan → (himpunan_nama_gagal, baris_mentah)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT)
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    if any(line.startswith("ERROR ") for line in lines):
        return None, [line for line in lines if line.startswith("ERROR ")]
    red = {line.replace("GAGAL ", "", 1).strip()
           for line in lines if line.startswith("GAGAL ")}
    return red, lines


def main():
    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    for path in (RENDER, VIEW):
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    unexpected = 0
    try:
        for label, mutations in STATES:
            missing = [(path, old) for path, old, _ in mutations
                       if old not in _originals[path]]
            if missing:
                for path, old in missing:
                    print(f"{label:52s} ANCHOR TIDAK DITEMUKAN di "
                          f"{os.path.basename(path)}: {old.splitlines()[0]!r}")
                unexpected += 1
                continue

            # Setiap berkas dimutasi dari **aslinya**, bukan dari berkas yang
            # sudah dimutasi keadaan sebelumnya: mutasi dua berkas dalam satu
            # keadaan tidak boleh bergantung pada urutannya.
            for path in (RENDER, VIEW):
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(_originals[path])
            for path, old, new in mutations:
                content = _originals[path].replace(old, new, 1)
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(content)

            red, lines = probe()
            if red is None:
                print(f"{label:52s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            want = WANT_RED[label]
            # `want` memuat awalan: sebuah nama merah cocok bila ia sama
            # persis dengan salah satu entri **atau** berawalan dengannya.
            got = {name for name in red
                   if any(name == w or name.startswith(w) for w in want)}
            extra = {name for name in red if name not in got}
            # Perbandingan yang benar: setiap entri `want` harus punya
            # pemeriksaan merah yang cocok, dan tidak ada merah di luarnya.
            satisfied = all(any(name == w or name.startswith(w) for name in red)
                            for w in want)
            mark = "OK  " if satisfied and not extra else "SALAH"
            if mark == "SALAH":
                unexpected += 1
            print(f"{mark} {label:52s} merah: {sorted(red) or '—'}")
            if mark == "SALAH":
                print(f"       diharapkan: {sorted(want) or '—'}")

            for path, _, _ in mutations:
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(_originals[path])
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
