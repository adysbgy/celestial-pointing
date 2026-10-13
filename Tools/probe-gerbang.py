#!/usr/bin/env python3
"""Cetak verdict satu/list gerbang `check-visuals.py` pada sumber **saat ini**.

Dipakai harness bukti-mutasi untuk mengukur, bukan mengira-ngira: satu gerbang
yang merah karena tidak pernah berjalan, dan gerbang yang hijau karena tidak
mengukur apa pun, sama-sama terlihat sebagai satu baris di sini.

Kenapa proses terpisah: `check-visuals.py` (dan `render-visuals.py` di
dalamnya) adalah modul; mengimpornya sekali di dalam proses pemanggil membuat
seluruh pengukuran berikutnya memakai salinan lama dari berkas yang **sudah
dimutasi** di disk. Setiap keadaan harus mengimpor ulang dari disk.

Pakai:
    python3 Tools/probe-gerbang.py NAMA_GERBANG,NAMA_LAIN
Keluar 0 selalu (verdict-nya yang dibaca, bukan kode keluar), kecuali bila
gerbangnya tidak bisa dijalankan sama sekali (impor gagal, gerbang tidak ada):
itu dilaporkan sebagai `ERR` supaya tidak terbaca sebagai "hijau".
"""

from __future__ import annotations

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PROBE = r"""
import importlib.util, os, sys, traceback

root = sys.argv[1]
names = [n for n in sys.argv[2].split(",") if n]

def load(mod, filename):
    path = os.path.join(root, "Tools", filename)
    spec = importlib.util.spec_from_file_location(mod, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[mod] = module
    spec.loader.exec_module(module)
    return module

sys.path.insert(0, os.path.join(root, "Tools"))
sys.dont_write_bytecode = True
try:
    C = load("cv_probe", "check-visuals.py")
except BaseException as exc:
    print("ERR <import>: " + type(exc).__name__ + ": " + str(exc)[:500])
    traceback.print_exc(file=sys.stdout)
    raise SystemExit(0)

try:
    R = load("rv_probe", "render-visuals.py")
except BaseException as exc:
    R = None
    print("WARN render-visuals import: " + type(exc).__name__ + ": " + str(exc)[:200])

for name in names:
    fn = getattr(C, name, None)
    if fn is None:
        print("ERR " + name + ": gerbang tidak ada di check-visuals.py")
        continue
    results = []
    try:
        fn(results)
    except BaseException as exc:
        print("ERR " + name + ": " + type(exc).__name__ + ": " + str(exc)[:400])
        continue
    if not results:
        # **Bukan hijau.** Gerbang yang mengembalikan nol hasil tidak
        # mengukur apa pun; himpunan kosong harus terlihat, bukan lulus.
        print("KOSONG " + name)
        continue
    ok = all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name + "  (" +
          str(sum(1 for r in results if r.ok)) + "/" + str(len(results)) + ")")
    for r in results:
        if not r.ok:
            print("    GAGAL " + str(r.name) + "  | " + str(r.detail))
"""


def main():
    names = sys.argv[1] if len(sys.argv) > 1 else ""
    import subprocess
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT, names],
                          capture_output=True, text=True)
    sys.stdout.write(proc.stdout)
    if proc.returncode != 0:
        sys.stdout.write(proc.stderr[-2000:])
    return 0


if __name__ == "__main__":
    sys.exit(main())
