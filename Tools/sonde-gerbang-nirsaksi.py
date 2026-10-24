#!/usr/bin/env python3
"""Sonde kecil untuk menguji SATU keadaan mutasi terhadap gerbang yang disebut.

Kenapa ini ada: harness `bukti-mutasi-gerbang-nirsaksi.py` menjalankan tujuh
keadaan, masing-masing memprobe keenam gerbang — total ~35 menit. Saat hanya
satu keadaan tidak sesuai harapan, menunggu seluruh rangkaian untuk mengulang
satu pengukuran itu 35 menit per iterasi.

Sonde ini memutasi berkas yang sama, menjalankan probe yang sama, dan
memulihkan berkas. Ia **tidak** menggantikan harness: harness yang menjaga
enam gerbang bersama-sama, dan yang ini hanya jalan memilih satu keadaan.

Pakai:
    python3 Tools/sonde-gerbang-nirsaksi.py <nama-keadaan-berkas-konfig>
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

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
    getattr(C, name)(results)
    ok = bool(results) and all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""


def run_probe(checks):
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, checks],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-2000:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        state, name = line.split(" ", 1)
        verdicts[name.strip()] = "hijau" if state == "OK" else "merah"
    return verdicts, None


def main():
    # Keadaan dibaca dari argumen: "nama|||cari===ganti|||cari===ganti"
    spec = sys.argv[1]
    name, _, edits_blob = spec.partition("|||")
    edits = []
    for pair in filter(None, edits_blob.split("|||")):
        find, _, replace = pair.partition("===")
        edits.append((find, replace))

    checks = ",".join(sys.argv[2:])

    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    md5_before = hashlib.md5(original).hexdigest()
    try:
        if edits:
            content = original.decode()
            for find, replace in edits:
                hits = content.count(find)
                if hits != 1:
                    print(f"JANGKAR GAGAL ({hits}x): {find[:80]!r}")
                    return 2
                content = content.replace(find, replace)
            mutasi_sumber.write_source(RENDER, content)
        verdicts, error = run_probe(checks)
        if verdicts is None:
            print(f"PROBE GAGAL: {error}")
            return 3
        for check, verdict in verdicts.items():
            print(f"  {verdict:6s} {check}")
    finally:
        mutasi_sumber.restore_verified(RENDER, original)
    after = hashlib.md5(open(RENDER, "rb").read()).hexdigest()
    print(f"md5: {md5_before} -> {after} ({'pulih' if after == md5_before else 'TIDAK PULIH'})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
