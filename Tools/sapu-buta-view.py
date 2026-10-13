#!/usr/bin/env python3
"""Sapu buta: literal angka di view yang **tidak** berbunyi di gerbang teks.

Siklus ini mulai dari pertanyaan yang belum pernah diajukan repo ini: dari
sekian puluh angka di `Apps/Shared/CelestialVisualView.swift` yang punya
pasangan di port Python, **mana** yang perubahannya tidak menyalakan satu pun
gerbang teks?

Cara mengukurnya:

  1. Kumpulkan gerbang yang **membaca sumber view** dari `Tools/check-visuals.py`
     -- daftar itu dibaca dari AST modulnya (fungsi yang badannya menyebut
     `CelestialVisualView`), bukan ditulis tangan di sini, supaya gerbang baru
     ikut terhitung.
  2. Untuk tiap literal `d.d` di view yang **juga muncul** di port, ubah
     literal itu saja (mis. 1.35 -> 1.08), lalu jalankan seluruh gerbang itu di
     **proses baru**.
  3. Laporkan yang **nol merah baru**: itulah angka yang bergerak di jam tanpa
     satu pun pemeriksaan berbunyi.

**Kenapa cakupannya 18 gerbang itu, bukan 41.** Yang bisa menangkap drift
view<->port adalah gerbang yang **membaca berkas view**. Gerbang yang hanya
membaca port dan model akan hijau pada mutasi view **karena sebab yang benar**
-- port-nya memang tidak berubah. Menghitungnya sebagai "buta" akan melahirkan
gerbang baru yang tidak bisa memerah, dan itu lebih buruk daripada tidak ada
gerbang. Tiga di antaranya (`check_uncertain_planet_loses_its_identity_colour`,
`check_unknown_planet_is_a_neutral_sphere`, `check_moon_disc_keeps_its_curvature`)
merender PNG **sekaligus** membaca view, jadi keduanya harus lulus.

Berkas produksi dimutasi **di tempat** (lewat `mutasi_sumber`, penulisan
atomik) lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/
`SIGTERM`; `SIGKILL` melewati `finally` dan meninggalkan mutasi hidup, jadi
`require_clean_sources` menolak jalan di atas sumber yang sudah kotor.

Pakai:
    python3 Tools/sapu-buta-view.py            # sapu penuh
    python3 Tools/sapu-buta-view.py 1.35 0.55  # literal tertentu saja
"""

from __future__ import annotations

import ast
import os
import re
import signal
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

VIEW = os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")
PORT = os.path.join(ROOT, "Tools", "render-visuals.py")
GATE = os.path.join(ROOT, "Tools", "check-visuals.py")

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
        print("ERR " + name + " " + type(exc).__name__ + ": " + str(exc)[:160])
        continue
    for r in results:
        if not r.ok:
            print("GAGAL " + name + ": " + str(r.name) + " -- " + str(r.detail)[:200])
"""


def view_reading_checks():
    """Gerbang di `check-visuals.py` yang badannya menyebut berkas view.

    Dibaca dari AST: fungsi yang tidak menyebut `CelestialVisualView` dilewati,
    karena gerbang seperti itu hijau pada mutasi view **karena sebab yang
    benar** -- port-nya memang tidak berubah.
    """
    source = open(GATE, encoding="utf-8").read()
    tree = ast.parse(source)
    lines = source.splitlines()
    out = []
    for node in tree.body:
        if not isinstance(node, ast.FunctionDef) or not node.name.startswith("check_"):
            continue
        body = "\n".join(lines[node.lineno - 1:node.end_lineno or node.lineno])
        if "CelestialVisualView" in body:
            out.append(node.name)
    return sorted(out)


def view_literals():
    """Literal `d.d` di view (**tanpa komentar**) yang juga ada di port."""
    view = open(VIEW, encoding="utf-8").read()
    port = open(PORT, encoding="utf-8").read()
    code = "\n".join(re.sub(r"//.*", "", line) for line in view.splitlines())
    found = {}
    for match in re.finditer(r"(?<![\w.])(\d+\.\d+)(?![\w.])", code):
        literal = match.group(1)
        if literal in port:
            found[literal] = found.get(literal, 0) + 1
    return found


def alternate(literal):
    """Nilai lain yang tetap masuk akal sebagai angka gambar."""
    value = float(literal)
    for candidate in (value * 0.8, value * 1.25, value - 0.05, value + 0.05):
        if candidate <= 0:
            continue
        text = f"{candidate:.2f}"
        if text != literal:
            return text
    return None


def substitute_literal(source, literal, replacement):
    """Ganti **hanya** literal `literal` sebagai angka utuh, bukan sebagai awalan.

    **Cacat yang ditutup fungsi ini, ditemukan oleh sapuan pertama.**
    Versi pertama memakai `str.replace`, jadi menyapu `0.7` juga menyunting
    `0.75` -- dan `0.75` adalah `CRATER_INNER_FLOOR_OPACITY`, yang **memang**
    dijaga. Sapuannya karena itu melaporkan `0.7` "bunyi", padahal yang
    berbunyi adalah gerbang milik angka tetangganya. Gerbang yang mengukur
    angka lain sambil terlihat mengukur angka ini adalah bentuk paling sunyi
    dari kelas cacat ini.

    Mengembalikan `None` bila tidak ada yang berubah, supaya pemanggil bisa
    melewatinya alih-alih menjalankan seluruh gerbang untuk mutasi kosong.
    """
    pattern = re.compile(r"(?<![\w.])" + re.escape(literal) + r"(?![\w.])")
    mutated = pattern.sub(replacement, source)
    return mutated if mutated != source else None


def main():
    wanted = sys.argv[1:]
    checks = view_reading_checks()
    literals = view_literals()
    if wanted:
        literals = {key: value for key, value in literals.items() if key in wanted}
    if not literals:
        print("tidak ada literal yang cocok.")
        return 2

    mutasi_sumber.require_clean_sources([VIEW])
    original = open(VIEW, encoding="utf-8").read()

    def restore():
        mutasi_sumber.restore_verified(VIEW, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] view dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    probe = os.path.join(tempfile.mkdtemp(prefix="sapu-buta-"), "probe.py")
    with open(probe, "w", encoding="utf-8") as handle:
        handle.write(PROBE)

    def run():
        out = subprocess.run([sys.executable, probe, ROOT, ",".join(checks)],
                             capture_output=True, text=True, cwd=ROOT,
                             env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
                             timeout=1800)
        if out.returncode != 0:
            return None, out.stderr.strip()[-400:]
        return [line for line in out.stdout.splitlines()
                if line.startswith(("GAGAL", "ERR"))], None

    print(f"gerbang yang membaca view: {len(checks)}")
    print(f"literal view yang juga ada di port: {len(literals)}")
    silent = []
    try:
        baseline, error = run()
        if baseline is None:
            print(f"[baseline] PROBE GAGAL: {error}")
            return 2
        print(f"[baseline] {len(baseline)} merah")
        for line in baseline:
            print(f"    {line}")

        for literal in sorted(literals, key=lambda key: -literals[key]):
            replacement = alternate(literal)
            if replacement is None:
                continue
            mutated = substitute_literal(original, literal, replacement)
            if mutated is None:
                continue
            mutasi_sumber.write_source(VIEW, mutated)
            reds, error = run()
            if reds is None:
                print(f"{literal} -> {replacement}: PROBE GAGAL {error}")
                continue
            extra = [line for line in reds if line not in baseline]
            print(f"{'BUTA ' if not extra else 'bunyi'} {literal:>6s} -> "
                  f"{replacement:<6s} ({literals[literal]}x di view): "
                  f"{len(extra)} merah baru")
            for line in extra[:3]:
                print(f"        {line}")
            if not extra:
                silent.append(literal)
    finally:
        restore()

    on_disk = open(VIEW, encoding="utf-8").read()
    print(f"\nview: {'pulih persis' if on_disk == original else 'TIDAK PULIH'}")
    print(f"{len(silent)} literal tanpa gerbang teks: {silent}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
