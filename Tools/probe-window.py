#!/usr/bin/env python3
"""Probe: di ketinggian berapa bola benar-benar selebar jendela ukur?

Dipakai untuk memutuskan apakah `check_bands_follow_the_limb_arc` masih
punya sampel yang bisa diukur di pita kutub, atau harus melonggarkan
jendelanya. Dibaca dari piksel, bukan dari geometri.
"""
import importlib.util
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("cv", os.path.join(HERE, "check-visuals.py"))
cv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cv)
R = cv.R

_, (w, h, rows_c) = cv.render_case("planet-jupiter-confirmed", size=200, ss=2)
_, (_, _, rows_s) = cv.render_case("planet-jupiter-bare", size=200, ss=2)
cx, cy = w / 2.0, h / 2.0
radius = min(w, h) / 2.0

# Tepi bola: piksel pertama yang berbeda dari latar.
def disc_edge(py):
    for px in range(w):
        a = rows_c[py][px*4:px*4+3]
        if sum(a[k] for k in range(3)) > 30:
            return (px + 0.5 - cx) / radius
    return None

def band_left(py):
    for px in range(w):
        a = rows_c[py][px*4:px*4+3]
        b = rows_s[py][px*4:px*4+3]
        if sum(abs(a[k]-b[k]) for k in range(3)) > 8:
            return (px + 0.5 - cx) / radius
    return None

print("baris   y_norm  bola_kiri  pita_kiri   x<=-0.20  x<=-0.30  x<=-0.40")
for py in range(6, 26):
    y = (py + 0.5 - cy) / radius
    print(f"{py:5d}  {y:+.3f}   {disc_edge(py)!s:>8}   {band_left(py)!s:>8}"
          f"    {'y' if abs(y) <= 0.980 else 'n':>4}"
          f"      {'y' if abs(y) <= 0.954 else 'n':>4}"
          f"      {'y' if abs(y) <= 0.9165 else 'n':>4}")

print("\nY di mana bola mencapai tiap batas x:")
for xlim in (-0.20, -0.30, -0.40, -0.50):
    print(f"  x = {xlim}: |y| <= {math.sqrt(max(0, 1-xlim*xlim)):.4f}")
