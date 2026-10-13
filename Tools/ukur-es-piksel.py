#!/usr/bin/env python3
"""Ukur: keadaan apa yang membuat `check_earthshine` (gerbang piksel) memerah?

**Kenapa alat ini ada.** Saat gerbang `check_earthshine_strength_matches_the_model`
ditulis, harness mutasinya menyatakan satu harapan yang **salah**: bahwa
mengubah rumus di **port** (`1 - f` -> `0.5 * (1 - f)`) akan memerahkan
`check_earthshine` juga. Harness itu memerah, dan yang salah bukan gerbangnya
melainkan harapannya.

Dari mana harapan itu datang: docstring gerbangnya sendiri mengklaim "terukur
5 merah" untuk arah itu. Klaim itu **tidak pernah dihasilkan alat ukur apa
pun** — persis kelas cacat yang gerbang paritas di repo ini tutup untuk angka
di docstring (`check_spiral_arm_docstring_quotes_measured_values`,
`check_saturn_ring_order_docstring_quotes_measured_values`). Angka di docstring
adalah klaim, dan klaim harus diukur.

Alat ini yang mengukurnya. Hasilnya, luminans rata-rata sisi gelap sabit
`f=0.15` pada skala 0–255, dengan `moonUnlit` (piringan gelap tanpa earthshine)
= 33.6 sebagai rujukan:

    earthshine dihapus  (`return 0.0`)        33.6   -> MERAH (2 pemeriksaan)
    earthshine separuh  (`0.5 * (1 - f)`)     52.8   -> HIJAU
    earthshine penuh    (`return 1.0`)        78.2   -> MERAH (1 pemeriksaan)

Jadi batas cakupan `check_earthshine` **bukan** "tidak mengukur apa pun": ia
menangkap "tidak digambar" (sisi gelap jatuh persis ke `moonUnlit`) dan
"menyala penuh" (sisi gelap melampaui sisi terang). Yang tidak ditangkapnya
adalah **separuh kekuatan** — dan itu memang disengaja: docstring gerbang itu
menyatakan rasionya longgar, karena yang dicegahnya adalah dua cacat ekstrem,
bukan kalibrasi.

Yang menutup celah separuh itu adalah
`check_earthshine_strength_matches_the_model` (membandingkan rumus, bukan
gambar). Kedua gerbang karena itu saling melengkapi, dan pembagian tugasnya
diukur di sini, bukan diasumsikan.

Pakai:
    python3 Tools/ukur-es-piksel.py     # selalu 0; ini alat ukur, bukan gerbang
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                           "CelestialVisual.swift")

# Dijalankan di proses baru supaya `check-visuals` (dan `R` di dalamnya)
# diimpor dari berkas yang **sudah** dimutasi di disk.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
for name in sys.argv[2].split(","):
    results = []
    try:
        getattr(C, name)(results)
    except Exception as exc:
        print("ERR " + name + " " + type(exc).__name__ + ": " + str(exc)[:200])
        continue
    ok = bool(results) and all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + " " + r.name + " :: "
              + str(r.detail)[:90])
"""

GATE = "check_earthshine_strength_matches_the_model"
EARTHSHINE = "check_earthshine"
ALL = ",".join((GATE, EARTHSHINE))

#: Jangkar diambil dari **badan `earthshineStrength`**, bukan dari bentuk yang
#: kebetulan mirip di fungsi lain: `terminatorRotationRadians` juga memakai
#: `min(1, max(0, fraction))`, tetapi menamai hasilnya `clamped`. Jangkar yang
#: salah tempat membuat mutasi mendarat di fungsi yang tidak diukur.
PORT_FORMULA = "    return 1 - f\n"

STATES = [
    ("A. port: earthshine dihapus (`return 0.0`)",
     [(RENDER, PORT_FORMULA, "    return 0.0\n")]),
    ("B. port: earthshine penuh (`return 1.0`)",
     [(RENDER, PORT_FORMULA, "    return 1.0\n")]),
    ("C. port: earthshine separuh (`0.5 * (1 - f)`)",
     [(RENDER, PORT_FORMULA, "    return 0.5 * (1 - f)\n")]),
]

FILES = [RENDER, MODEL]


def main():
    mutasi_sumber.require_clean_sources(FILES)
    originals = {path: open(path, "rb").read() for path in FILES}

    def restore():
        for path, data in originals.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits in STATES:
            restore()
            pending, ok = {}, True
            for path, find, replace in edits:
                content = pending.get(path, originals[path].decode())
                hits = content.count(find)
                if hits != 1:
                    print(f"\n=== {name}: jangkar muncul {hits}x -> DILEWATI")
                    ok = False
                    break
                pending[path] = content.replace(find, replace)
            if not ok:
                continue
            for path, content in pending.items():
                mutasi_sumber.write_source(path, content)

            out = subprocess.run([sys.executable, "-c", PROBE, ROOT, ALL],
                                 capture_output=True, text=True, timeout=1800)
            print(f"\n=== {name}")
            if out.returncode != 0:
                print(f"   PROBE GAGAL\n{out.stderr[-500:]}")
                continue
            for line in out.stdout.splitlines():
                if line.startswith(("OK", "GAGAL", "ERR")):
                    print("   " + line)
    finally:
        restore()

    for path, data in originals.items():
        same = open(path, "rb").read() == data
        print(f"{os.path.relpath(path, ROOT)}: "
              f"{'pulih persis' if same else 'TIDAK PULIH'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
