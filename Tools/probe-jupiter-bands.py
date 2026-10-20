#!/usr/bin/env python3
"""Probe: jalankan HANYA dua pemeriksaan pita Jupiter yang merah.

Kenapa ini ada: `check-visuals.py` merender seluruh katalog (~10 menit+)
sebelum satu pun hasil dicetak, sehingga mengukur satu cacat berarti
menunggu seluruh katalog. Probe ini mengimpor modul yang sama (jadi
`render_case` dan `R.*` persis sama), memanggil hanya dua fungsi gerbang,
dan mencetak hasilnya. Tidak ada angka yang diketik ulang di sini.
"""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import importlib.util

spec = importlib.util.spec_from_file_location(
    "check_visuals",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "check-visuals.py"))
cv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cv)

want = sys.argv[1:] or ["reach", "arc"]
results = []
t0 = time.time()
if "reach" in want:
    cv.check_jupiter_bands_reach_the_limb(results, 200, 2)
    print(f"[reach] {time.time()-t0:.1f}s", flush=True)
if "arc" in want:
    cv.check_bands_follow_the_limb_arc(results, 200, 2)
    print(f"[arc] {time.time()-t0:.1f}s", flush=True)
if "separate" in want:
    cv.check_jupiter_bands_read_as_separate_stripes(results, 200, 2)
    print(f"[separate] {time.time()-t0:.1f}s", flush=True)

width = max((len(r.name) for r in results), default=1)
for r in results:
    print(f"{'OK  ' if r.ok else 'GAGAL'} {r.name.ljust(width)}  {r.detail}")
print(f"\n{len(results)} pemeriksaan, {sum(1 for r in results if not r.ok)} gagal")
