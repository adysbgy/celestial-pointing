#!/usr/bin/env python3
"""Buktikan `_gradient_end_factors` masih menggigit **setelah** ia diajari
mengenali bentuk konstanta.

Kenapa harness ini ada.

Siklus ini memperbaiki cacat nyata: jalur limb menulis `1.15` sendiri di view
dan di port, jadi `moonSphereGradientEndRadius` tidak mengatur apa pun di
separuh pemanggilnya. Perbaikannya mengganti literal itu dengan konstanta —
dan perbaikan itu **mematahkan gerbangnya sendiri**: pembaca
`_gradient_end_factors` hanya mengenali `radius * 1.15`, jadi pada kode yang
sudah benar ia melaporkan "limb tidak terbaca" (2 merah dari 580 periksa).

Kelas cacatnya terbalik dari yang biasa dicari repo ini: bukan gerbang yang
hijau pada kode salah, melainkan **gerbang yang merah pada kode benar**. Bentuk
kegagalan ini lebih berbahaya dari yang tampak, karena orang yang menemukannya
dalam keadaan terburu-buru akan "memperbaiki" kodenya kembali ke bentuk salah
supaya gerbangnya hijau.

Jadi pembacanya diperluas: ia kini mengenali literal **dan** konstanta, dan
menyelesaikan nilai konstanta dari sumber model. Harness ini membuktikan
perluasan itu tidak membuatnya tumpul.

Keadaan yang diuji:

  [baseline]                            7 hijau (kalau tidak, harness salah)
  1. view: gradien limb kembali ke literal     2 merah (view vs port)
  2. port: gradien limb kembali ke literal     2 merah
  3. view: limb memakai 1.35 (bola)            2 merah — pasangannya tertukar
  4. port: bola 1.35 -> 1.60                   2 merah (view vs port)
  5. kedua bahasa sepakat memakai 1.60         1 merah ("dua gradien berbeda")
  6. view: piringan Bulan 1.15, pita planet
     1.35 (dua pemanggil tak sepakat)          1 merah ("tidak sepakat")

Keadaan 5 dan 6 sengaja menguji **arah yang berbeda dari drift antar bahasa**:
kedua bahasa sepakat, jadi tidak ada perbandingan view-lawan-port yang bisa
berbunyi. Hanya pemeriksaan "dua gradien berbeda" (5) dan "para pemanggil
sepakat" (6) yang melihatnya.

Perbaikan pembaca ini tidak membuat keadaan 1–2 kehilangan giginya: konstanta
diselesaikan dari **model**, jadi literal yang menyimpang tetap terdeteksi.
Itulah yang diuji baris 1–4.

Berkas sumber produksi dimutasi dengan sengaja lalu dipulihkan di `finally`
per keadaan, plus handler `SIGINT`/`SIGTERM` (`SIGKILL` tetap bisa melewati
keduanya — batas yang diketahui, bukan klaim bahwa harness ini kebal).

Pakai:
    python3 Tools/bukti-mutasi-radius-gradasi.py
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")

# Dijalankan di proses baru: mengimpor ulang berkas yang **sudah dimutasi** di
# disk. Mengimpor sekali di dalam proses ini akan memakai salinan lama, dan
# seluruh harness berbohong.
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
    C.check_gradient_end_radii_match(results)
except Exception as exc:
    print("ERROR %s: %s" % (type(exc).__name__, exc))
    sys.exit(0)
for r in results:
    print(("GAGAL " if not r.ok else "OK    ") + r.name)
"""

# Mutasi **kedua** pemanggil sekaligus memakai inti yang tak ambigu.
#
# Jangkar berbasis lekukan **tidak** bisa dipakai untuk itu: `MOON_VIEW`
# (12 spasi) adalah anak-string dari `BAND_VIEW` (32 spasi), jadi
# `replace(MOON_VIEW, …, 1)` menyunting baris mana yang lebih dulu
# ditemukan, dan mutasi kedua lalu gagal menemukan jangkarnya — persis
# `AssertionError` yang muncul di sini sebelum diperbaiki. Inti di bawah
# tidak punya lekukan, jadi ia kena di kedua baris dan urutannya tidak
# penting.
VIEW_LIMB_CORE = "radius * CGFloat(CelestialVisual.moonSphereGradientEndRadius)"
VIEW_LIMB_DRIFT = "radius * 1.45"
PORT_LIMB_CORE = "end_radius=radius * MOON_SPHERE_GRADIENT_END_RADIUS)"
PORT_LIMB_DRIFT = "end_radius=radius * 1.45)"

# Mutasi **satu** pemanggil (keadaan 6) butuh jangkar yang menyertai
# lekukannya. 32 spasi itu unik untuk pita planet dalam: `sphereGradient`
# memakai 12.
BAND_VIEW = ("                                endRadius: radius * "
             "CGFloat(CelestialVisual.moonSphereGradientEndRadius)))")
BAND_VIEW_DRIFT = "                                endRadius: radius * 1.45)))"

BALL_PORT = "        start_radius=radius * 0.1, end_radius=radius * 1.35)"
BALL_PORT_WIDE = "        start_radius=radius * 0.1, end_radius=radius * 1.60)"
BALL_VIEW = "            startRadius: radius * 0.1,\n            endRadius: radius * 1.35))"
BALL_VIEW_WIDE = ("            startRadius: radius * 0.1,\n"
                  "            endRadius: radius * 1.60))")
MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit",
                     "CelestialVisual.swift")
MODEL_ANCHOR = "    public static let moonSphereGradientEndRadius: Double = 1.15"

# (nama keadaan, [(berkas, cari, ganti, jumlah)]) — jumlah 0 = semua kemunculan.
STATES = [
    ("[baseline]", []),
    # Keadaan 1–2: satu sisi berhenti membaca konstanta dan menulis angkanya
    # sendiri, lalu angkanya menyimpang. Ini drift klasik, dan pembaca yang
    # diperluas **masih** harus melihatnya — kalau tidak, memperbaiki cacat
    # aslinya justru membutakan gerbang yang lama.
    ("1. view: kedua pemanggil limb menulis literal 1.45",
     [(VIEW, VIEW_LIMB_CORE, VIEW_LIMB_DRIFT, 0)]),
    ("2. port: kedua pemanggil limb menulis literal 1.45",
     [(RENDER, PORT_LIMB_CORE, PORT_LIMB_DRIFT, 0)]),
    # Keadaan 3: model berubah, dan hanya **view** yang mengikuti (karena port
    # menyimpan konstantanya sendiri). Inilah sebabnya konstanta diselesaikan
    # dari sumber sisi masing-masing — kalau kedua sisi diselesaikan dari nilai
    # port, keadaan ini hijau dan satu-satunya sumber kebenaran jadi port.
    ("3. model: konstanta 1.15 -> 1.45",
     [(MODEL, MODEL_ANCHOR,
       "    public static let moonSphereGradientEndRadius: Double = 1.45", 1)]),
    ("4. port: bola 1.35 -> 1.60",
     [(RENDER, BALL_PORT, BALL_PORT_WIDE, 1)]),
    # Sengaja **diharapkan hijau**: kedua bahasa sepakat, jadi tidak ada drift
    # untuk diberitakan. Gerbang ini menjaga kesamaan antar bahasa, bukan
    # kebenaran angkanya — menuntutnya merah akan menuntutnya berbunyi tanpa
    # alasan, dan gerbang seperti itu dimatikan orang.
    ("5. kedua bahasa sepakat memakai 1.60 pada bola",
     [(RENDER, BALL_PORT, BALL_PORT_WIDE, 1), (VIEW, BALL_VIEW, BALL_VIEW_WIDE, 1)]),
    # Keadaan 6: dua pemanggil gradien limb tidak sepakat. Perbandingan
    # view-lawan-port tidak bisa melihatnya (nilainya `None`), jadi pemeriksaan
    # "terbaca" itulah yang berbunyi — dan pesannya menyebut ketidaksepakatan.
    ("6. view: dua pemanggil limb tidak sepakat",
     [(VIEW, BAND_VIEW, BAND_VIEW_DRIFT, 1)]),
]

WANT_RED = {
    "[baseline]": set(),
    "1. view: kedua pemanggil limb menulis literal 1.45": {
        "radius akhir gradien limb (view == port)"},
    "2. port: kedua pemanggil limb menulis literal 1.45": {
        "radius akhir gradien limb (view == port)"},
    "3. model: konstanta 1.15 -> 1.45": {
        "radius akhir gradien limb (view == port)"},
    "4. port: bola 1.35 -> 1.60": {
        "radius akhir gradien bola (view == port)"},
    "5. kedua bahasa sepakat memakai 1.60 pada bola": set(),
    "6. view: dua pemanggil limb tidak sepakat": {
        "radius akhir gradien limb terbaca di view Swift"},
}


_originals = {}


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal."""
    for path, content in _originals.items():
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(content)


def probe():
    """Jalankan pemeriksaan -> (himpunan_nama_gagal, baris_mentah)."""
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

    for path in (RENDER, VIEW, MODEL):
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    unexpected = 0
    try:
        for label, mutations in STATES:
            missing = [(path, old) for path, old, _, _ in mutations
                       if old not in _originals[path]]
            if missing:
                for path, old in missing:
                    print(f"{label:52s} ANCHOR TIDAK DITEMUKAN di "
                          f"{os.path.basename(path)}: {old.splitlines()[0]!r}")
                unexpected += 1
                continue

            # Setiap berkas dimutasi dari **aslinya**, bukan dari berkas yang
            # sudah dimutasi keadaan sebelumnya.
            for path in (RENDER, VIEW, MODEL):
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(_originals[path])
            # **Satu berkas, banyak suntingan.** Mutasi kedua pada berkas yang
            # sama harus diterapkan di atas **hasil** mutasi pertama —
            # membacanya lagi dari `_originals` akan menghapus suntingan
            # pertama, dan keadaan "kedua pemanggil menulis literal" akan
            # terukur sebagai "satu pemanggil menulis literal". Kelas cacat
            # yang sama dengan `continue` yang tidak memulihkan: harness yang
            # mengaku menguji satu keadaan, padahal menguji keadaan lain.
            pending = {}
            for path, old, new, count in mutations:
                content = pending.get(path, _originals[path])
                assert old in content, (path, old)
                content = (content.replace(old, new) if count == 0
                           else content.replace(old, new, count))
                pending[path] = content
            for path, content in pending.items():
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(content)

            red, lines = probe()
            if red is None:
                print(f"{label:52s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            want = WANT_RED[label]
            extra = {name for name in red if name not in want}
            satisfied = want <= red
            mark = "OK  " if satisfied and not extra else "SALAH"
            if mark == "SALAH":
                unexpected += 1
            print(f"{mark} {label:52s} merah: {sorted(red) or '—'}")
            if mark == "SALAH":
                print(f"       diharapkan: {sorted(want) or '—'}")

            for path, _, _, _ in mutations:
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
