#!/usr/bin/env python3
"""Sapu `moonEarthshine` — cari nilainya dari ukuran, bukan dari selera.

**Kenapa alat ini ada, dan bukan sekadar catatan di STATUS.md.** Nilai
`moonEarthshine` menentukan apakah piringan Bulan **terlihat sama sekali** di
kartu jam: pada f = 0 kekuatan earthshine `1 - f` = 1.0, jadi seluruh piringan
bulan baru adalah warna token itu apa adanya. Terukur pada 38 px (token
`WatchMetrics.visualDiameter`), nilai lamanya 0.15 memberi **1.32:1** terhadap
latar kartu #0A0A0F — di bawah ambang keterbacaan mana pun, dan setara "kartu
kosong". Sisi gelap sabit pun 1.30:1, jadi yang hilang bukan satu kartu langka
melainkan bagian gelap Bulan di **setiap** fase.

Yang dicari bukan angka terbesar yang masih hijau, melainkan angka yang
**plafonnya diukur**: sapuan ini melaporkan, untuk tiap nilai, kontras piringan
di ukuran jam **dan** kelima gerbang earthshine yang sudah ada, supaya tidak ada
yang dikorbankan diam-diam.

Batas yang mengikat, terukur (`python3 Tools/sapu-earthshine.py`):

    earthshine   kontras jam   gerbang   malam (plafon 45%)   margin ke unknown
    0.15           1.32:1      6/6 OK        24.15%               94/255
    0.24           1.85:1      6/6 OK        33.04%               71/255
    0.30           2.39:1      6/6 OK        39.11%               55/255   <- dipakai
    0.34           2.80:1      6/6 OK        42.30%               45/255
    0.36           3.03:1      6/6 OK        44.58%               40/255
    0.37           3.13:1      5/6 GAGAL     45.32%               38/255   <- plafon
    0.44           4.11:1      5/6 GAGAL     50.19%               20/255

Jadi yang mengikat **bukan** gerbang earthshine (semuanya hijau sampai 0.36)
melainkan plafon malam 45% (`check_earthshine`, "rasio gelap/terang di bawah
plafon mutlak") yang tembus di **0.37** — dan margin kejujuran ke
`moonPhaseUnknown` (jarak kanal merah harus > 25,
`check_unknown_phase_is_not_a_new_moon`) yang baru menggigit di **0.44**. Dua
batas itu **berbeda jauh**, dan sebelum disapu tidak ada yang tahu mana yang
lebih dulu menyerah.

Dua jebakan pengukuran yang alat ini pernah jatuh ke dalamnya, dan sekarang
ditutup: (1) menghitung margin secara **analitik** dari token (`round(f * 255)`)
alih-alih dari piksel yang diukur gerbang; dan (2) memakai kanal **biru**
(0.37 di token) alih-alih merah (0.30) — selisih 18/255, cukup untuk membuat
tabel yang salah tampak masuk akal. Sekarang gerbangnya dipanggil langsung.

Nilai yang dipakai dijaga `check_moon_new_disc_reads_on_the_watch` (ambang
2.0:1), jadi angka ini tidak bisa diturunkan kembali tanpa gerbang merah.

Pakai:

    python3 Tools/sapu-earthshine.py            # sapuan penuh
    python3 Tools/sapu-earthshine.py 0.30 0.36  # nilai tertentu saja
"""

import importlib.util
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


C = load("check_visuals", os.path.join(ROOT, "Tools", "check-visuals.py"))
R = C.R

#: Nilai yang disapu. 0.37+ sengaja ikut supaya plafonnya **terlihat**
#: ditembus, bukan hanya diklaim ada.
SWEEP = (0.15, 0.18, 0.24, 0.30, 0.34, 0.36, 0.37, 0.40, 0.44)


def relative_luminance(rgb):
    def channel(value):
        v = value / 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return (0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1])
            + 0.0722 * channel(rgb[2]))


def contrast(a, b):
    la, lb = relative_luminance(a), relative_luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def render(name, size, ss, case=None, night=False):
    if case is None:
        case = next(c for c in R.build_cases() if c.name == name)
    canvas = R.render(case, size=size, night_mode=night, show_frame=False, ss=ss)
    path = os.path.join(R.OUT_DIR, f"_sap-{name}.png")
    os.makedirs(R.OUT_DIR, exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(canvas.to_png())
    return C.decode_png(path)


def centre(rows, w, h):
    """3x3 pusat — penyampel yang sama dengan gerbang jam."""
    cx, cy = w // 2, h // 2
    acc = [0, 0, 0]
    for y in range(cy - 1, cy + 2):
        for x in range(cx - 1, cx + 2):
            p = rows[y][x * 4:x * 4 + 3]
            for i in range(3):
                acc[i] += p[i]
    return tuple(v // 9 for v in acc)


def side_luminance(rows, w, h, lit_side, r0=0.55, r1=0.92):
    """`side_luminance` dari `check_earthshine` — disalin apa adanya.

    Disalin, bukan diimpor, karena versi di gerbang itu fungsi **bersarang**
    (ia menutup atas `size`/`ss`). Salinan ini harus ikut berubah kalau
    penyampelnya berubah; angka yang dilaporkan alat ini hanya berguna kalau ia
    mengukur sliver yang sama dengan gerbang.
    """
    cx, cy, radius = w / 2.0, h / 2.0, w / 2.0
    tot, n = 0.0, 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            d = math.hypot(x - cx, y - cy)
            if d > radius * r1 or d < radius * r0:
                continue
            if lit_side:
                if x < cx:
                    continue
            elif x > cx - 0.75 * radius:
                continue
            r, g, b = rows[y][x * 4:x * 4 + 3]
            tot += 0.2126 * r + 0.7152 * g + 0.0722 * b
            n += 1
    return tot / max(1, n)


def dark_side_luminance(rows, w, h):
    """`dark_side_luminance` dari `check_earthshine` — disalin apa adanya."""
    cx = w / 2.0
    threshold = cx - 0.75 * (w / 2.0)
    tot, n = 0.0, 0
    for y in range(0, h, 2):
        for x in range(0, int(threshold), 2):
            if math.hypot(x - cx, y - h / 2) > cx:
                continue
            r, g, b = rows[y][x * 4:x * 4 + 3]
            tot += 0.2126 * r + 0.7152 * g + 0.0722 * b
            n += 1
    return tot / max(1, n)


def moon_case(name, illumination):
    return R.VisualCase(name, "sementara", "moon", illumination=illumination,
                        is_waxing=True, bright_limb_angle=0.0, is_confirmed=True)


def report(value):
    R.ACCENTS["moonEarthshine"] = (value, value, value * 1.23)
    _, unlit = C.moon_colors()
    unlit_lum = 0.2126 * unlit[0] + 0.7152 * unlit[1] + 0.0722 * unlit[2]

    crescent = moon_case("__sap-cr", 0.15)
    gibbous = moon_case("__sap-gb", 0.85)

    # Gerbang 1 & 2 — siang, sliver terjauh kiri.
    w, h, rows = render("__sap-cr", 200, 2, case=crescent)
    crescent_dark = dark_side_luminance(rows, w, h)
    _, _, rows_g = render("__sap-gb", 200, 2, case=gibbous)
    gibbous_dark = dark_side_luminance(rows_g, w, h)

    # Gerbang 3, 4, 5 — malam, cincin 0.55…0.92 R.
    _, _, rows_n = render("__sap-cr", 200, 2, case=crescent, night=True)
    night_dark = side_luminance(rows_n, w, h, lit_side=False)
    night_lit = side_luminance(rows_n, w, h, lit_side=True)
    night_ratio = night_dark / night_lit * 100.0
    _, _, rows_d = render("__sap-cr", 200, 2, case=crescent, night=False)
    day_ratio = (side_luminance(rows_d, w, h, lit_side=False)
                 / side_luminance(rows_d, w, h, lit_side=True) * 100.0)
    _, _, rows_gn = render("__sap-gb", 200, 2, case=gibbous, night=True)
    gibbous_night = side_luminance(rows_gn, w, h, lit_side=False)

    # Keterbacaan di ukuran kartu jam.
    w38, h38, rows_new = render("moon-new", 38, 8)
    disc = centre(rows_new, w38, h38)
    background = C.background_of(w38, h38, rows_new)

    # Margin kejujuran **dari gerbangnya sendiri**, bukan dihitung ulang.
    #
    # Versi pertama alat ini menghitungnya analitik (`round(f * 255)`): meleset
    # dari gerbang, dan sempat memakai kanal **biru** (0.37) alih-alih merah
    # (0.30) sehingga menghasilkan 39 alih-alih 57 — dan dua tabel di repo ini
    # sempat mengutip angka yang tidak diukur siapa pun. Versi kedua menyampel
    # kanal merah sendiri, tapi di **38 px**, sedangkan gerbang mengukur di
    # **200 px** (rasterisasi berbeda). Sekarang gerbangnya dipanggil langsung
    # dan detailnya diurai, jadi angka yang dilaporkan alat ini adalah angka
    # yang sama dengan yang dipakai gerbang untuk memutuskan.
    probe = []
    C.check_unknown_phase_is_not_a_new_moon(probe, 200, 2)
    margin_detail = next(r.detail for r in probe
                         if r.name == "piringan tak-diketahui di antara gelap & terang")
    nums = [int(n) for n in re.findall(r"\d+", margin_detail)]
    unknown_red, new_red = nums[0], nums[1]
    margin = unknown_red - new_red

    gates = [
        crescent_dark > unlit_lum + 1.0,
        gibbous_dark < crescent_dark,
        night_ratio <= day_ratio,
        night_ratio <= 45.0,
        gibbous_night < night_dark,
        margin > 25,
    ]
    flag = " " if all(gates) else "  <- GAGAL"
    print(f"es={value:.2f}  jam {contrast(disc, background):5.2f}:1 "
          f"{str(disc):>16}  | gerbang "
          f"{' '.join('OK ' if g else 'MERAH' for g in gates)} | "
          f"malam {night_ratio:5.2f}%  margin {margin:3d}/255{flag}")
    return all(gates)


if __name__ == "__main__":
    values = [float(a) for a in sys.argv[1:]] or list(SWEEP)
    print("── moonEarthshine: kontras kartu jam vs 5 gerbang earthshine ──")
    print("   (gerbang: 1 sabit>unlit, 2 cembung<sabit, 3 malam<=siang, "
          "4 malam<=45%, 5 malam meredup, 6 margin ke unknown>25)")
    all_ok = True
    for v in values:
        all_ok &= report(v)
    print("\nsemua hijau" if all_ok else "\nada yang merah di sapuan ini")
