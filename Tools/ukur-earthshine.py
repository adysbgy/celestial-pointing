#!/usr/bin/env python3
"""Ukur SEBELUM menulis gerbang: apakah `earthshineStrength` dijaga apa pun?

Siklus ini mulai dari lead yang ditinggalkan STATUS.md: model punya fungsi
bernama `CelestialVisual.earthshineStrength(illuminationFraction:)`, sedangkan
port Python menulis rumusnya **inline** (`strength = 1.0 - f`) sambil
mengklaim di komentarnya "sama seperti `CelestialVisual.earthshineStrength`
di Swift". Nol gerbang menyebut namanya.

Skrip ini TIDAK menulis gerbang apa pun. Ia hanya mengukur: mutasi satu arah
(mengubah **model**, membiarkan port), lalu jalankan gerbang Bulan yang ada.
Yang diukur adalah berapa banyak gerbang yang berbunyi -- dan kalau nol, lead
itu terbukti, bukan diwarisi dari STATUS.md.

Pakai:
    python3 Tools/ukur-earthshine.py     # 0 = lead terbukti (ada yang perlu dijaga)
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                            "CelestialVisual.swift")
VIEW = os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

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
"""

# Gerbang Bulan yang ada. Kalau salah satunya berbunyi saat MODEL berubah,
# lead di STATUS.md sudah basi -- dan itu justru temuan yang lebih penting.
MOON = ",".join((
    "check_earthshine",
    "check_moon_phase_fraction",
    "check_crescent_direction",
    "check_moon_phase_survives_uncertainty",
    "check_unknown_phase_is_not_a_new_moon",
    "check_moon_new_disc_reads_on_the_watch",
    "check_moon_disc_keeps_its_curvature",
    "check_unknown_moon_disc_uses_the_token",
))

# Rumus earthshine di model: `return 1 - f`. Mutasi yang paling mungkin
# terjadi di dunia nyata adalah orang menyunting **model** (yang dibaca view)
# dan lupa port-nya.
MODEL_FORMULA = "        return 1 - f\n"
MODEL_MUTATED = "        return (1 - f) * 0.5\n"

STATES = [
    ("[baseline] berkas bersih", None),
    ("1. model `1 - f` -> `(1 - f) * 0.5`, port tidak ikut",
     (MODEL, MODEL_FORMULA, MODEL_MUTATED)),
    ("2. model dibalik `1 - f` -> `f`, port tidak ikut",
     (MODEL, MODEL_FORMULA, "        return f\n")),
]


def main():
    mutasi_sumber.require_clean_sources([MODEL])
    originals = {MODEL: open(MODEL, "rb").read()}

    def restore():
        for path, data in originals.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    print("Jangkar mutasi:")
    for label, anchor in (("model", MODEL_FORMULA),):
        hits = originals[MODEL].decode().count(anchor)
        print(f"  {label}: {hits}x  {anchor.strip()!r}")
        if hits != 1:
            print("  jangkar tidak unik -- harness ini tidak bisa dipercaya.")
            return 2

    try:
        for name, edit in STATES:
            restore()
            if edit is not None:
                path, find, replace = edit
                content = originals[path].decode()
                if content.count(find) != 1:
                    print(f"{name}: JANGKAR TIDAK UNIK, dilewati")
                    continue
                mutasi_sumber.write_source(path, content.replace(find, replace))
            out = subprocess.run([sys.executable, "-c", PROBE, ROOT, MOON],
                                 capture_output=True, text=True, timeout=1800)
            if out.returncode != 0:
                print(f"{name}: PROBE GAGAL\n{out.stderr.strip()[-1200:]}")
                continue
            reds = [line for line in out.stdout.splitlines()
                    if line.startswith("GAGAL") or line.startswith("ERR")]
            print(f"\n{name}: {len(reds)} gerbang berbunyi dari "
                  f"{len(MOON.split(','))} gerbang Bulan")
            for line in reds:
                print(f"    {line}")
            if not reds:
                print("    (nol -- model bisa menyimpang tanpa satu pun alarm)")
    finally:
        restore()

    for path, data in originals.items():
        now = open(path, "rb").read()
        print(f"\n{os.path.relpath(path, ROOT)}: "
              f"{'pulih persis' if now == data else 'TIDAK PULIH'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
