#!/usr/bin/env python3
"""Ukur cepat: apakah bola sebuah planet ber-pita atau bola polos.

Kenapa ada alat ini. `Tools/check-visuals.py --check` menjalankan ratusan
kasus pada supersampling tinggi dan butuh ~20 menit di mesin ini — terlalu
lambat untuk mengukur satu perubahan. Alat ini merender **satu** kasus dan
mengukur hal yang membedakan pita dari bola polos.

**Kenapa bukan "variasi terang di kolom tengah".** Bola polos pun bergradien
(terang kiri-atas, gelap kanan-bawah), jadi simpangan bakunya sudah besar:
diukur pada Saturnus polos, 26.7/255 — lebih besar dari yang terlihat pada
pita Jupiter. Angka itu tidak membedakan apa pun.

Yang membedakan pita adalah **pita berganti nada bolak-balik**, sementara
gradien bola berubah **satu arah** dari kutub atas ke kutub bawah. Jadi:

  * `belok` — berapa kali turunan pertama profil berganti tanda. Gradien
    monoton: 0. Tujuh pita: beberapa.
  * `sisa` — simpangan baku terhadap **garis lurus** terbaik yang dipasang
    pada profil. Gradien bola nyaris lurus; pita meninggalkan sisa besar.

Keduanya diukur pada kasus yang sama supaya sebanding: Jupiter (pasti
ber-pita) dipakai sebagai kalibrasi, Saturnus sebagai tersangka.
"""

import importlib.util
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def _load(name, filename):
    """Muat berkas ber-tanda-hubung sebagai modul (namanya bukan pengenal).

    Sama dengan cara `check-visuals.py` memuat portnya, dan **wajib** sama:
    `sys.dont_write_bytecode` + purge di sana ada karena harness mutasi
    menulis ulang berkas produksi, dan `.pyc` basi pernah menjatuhkan `main`.
    """
    sys.dont_write_bytecode = True
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


R = _load("render_visuals", "render-visuals.py")
C = _load("check_visuals", "check_visuals.py".replace("_", "-"))


def profile(case_name, size=200, ss=2, night=False):
    """Luminans sepanjang kolom tengah, di dalam piringan bola."""
    case = next(c for c in R.build_cases() if c.name == case_name)
    canvas = R.render(case, size=size, night_mode=night, show_frame=False, ss=ss)
    path = os.path.join(R.OUT_DIR, f"_probe-{case_name}.png")
    os.makedirs(R.OUT_DIR, exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(canvas.to_png())
    w, h, rows = C.decode_png(path)

    # Radius bola: Saturnus menggambar bolanya sendiri pada 0.53 R (cincin),
    # planet lain memakai radius penuh. Dibaca dari model, bukan ditulis.
    body = 1.0
    if "saturn" in case_name:
        body = R.saturn_body_radius(R.saturn_ring())

    cx, cy = w / 2.0, h / 2.0
    radius = min(w, h) / 2.0
    x = int(round(cx))
    values = []
    for y in range(int(round(cy - 0.9 * body * radius)),
                   int(round(cy + 0.9 * body * radius)) + 1):
        px = rows[y][x * 4:x * 4 + 3]
        values.append(0.2126 * px[0] + 0.7152 * px[1] + 0.0722 * px[2])
    return path, values


def turning_points(values, smooth=5):
    """Berapa kali turunan pertama berganti tanda, setelah dihaluskan."""
    if len(values) < smooth * 2:
        return 0
    window = [sum(values[i:i + smooth]) / smooth
              for i in range(len(values) - smooth + 1)]
    diffs = [b - a for a, b in zip(window, window[1:])]
    # Abaikan riak di bawah satu tingkat kuantisasi (1/255): itu derau
    # pembulatan, bukan tepi pita.
    diffs = [d for d in diffs if abs(d) > 0.4]
    return sum(1 for a, b in zip(diffs, diffs[1:]) if (a > 0) != (b > 0))


def linear_residual(values):
    """Simpangan baku terhadap garis lurus terbaik pada profil."""
    n = len(values)
    xs = list(range(n))
    mx = sum(xs) / n
    my = sum(values) / n
    denom = sum((x - mx) ** 2 for x in xs)
    slope = sum((x - mx) * (y - my) for x, y in zip(xs, values)) / max(denom, 1e-9)
    intercept = my - slope * mx
    residuals = [y - (intercept + slope * x) for x, y in zip(xs, values)]
    return (sum(r * r for r in residuals) / n) ** 0.5


def report(case_name, night=False):
    path, values = profile(case_name, night=night)
    mean = sum(values) / len(values)
    print(f"{case_name}{' (malam)' if night else ''}")
    print(f"  berkas    : {path}")
    print(f"  sampel    : {len(values)} baris kolom tengah")
    print(f"  rata-rata : {mean:.1f}/255")
    print(f"  belok     : {turning_points(values)}  (0 = monoton, pita > 0)")
    print(f"  sisa garis: {linear_residual(values):.2f}/255")
    return turning_points(values), linear_residual(values)


if __name__ == "__main__":
    names = sys.argv[1:] or ["planet-jupiter-confirmed", "planet-saturn-confirmed"]
    for name in names:
        report(name)
        print()
