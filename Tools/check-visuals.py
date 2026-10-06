#!/usr/bin/env python3
"""Ukur hasil render `Tools/render-visuals.py` — mata sebagai angka.

Kenapa ada, padahal sudah ada `render-visuals.py`.

Alat itu membuat gambar; gambar itu untuk **manusia**. Tapi sebagian
pertanyaan tentang lapisan menggambar punya jawaban yang **terukur**, dan
selama jawabannya bisa diukur, ia tidak perlu dipercayakan pada mata yang
sedang lelah:

  - fraksi luas sabit Bulan yang benar-benar tergambar ≈ fraksi iluminasi?
  - sisi terang sabit menghadap ke mana?
  - cincin Saturnus utuh di dalam frame?
  - ciri pengenal planet **hilang** saat engine ragu?

Semuanya bisa dihitung dari piksel. Kalau bisa dihitung, ia bisa jadi gerbang:
`--check` keluar != 0 saat invariannya rusak, jadi regresi visual tertangkap
tanpa perlu ada yang membuka gambar.

Yang **tidak** diklaim di sini: bahwa hasilnya sama dengan SwiftUI di
perangkat. Yang diuji adalah port-nya konsisten dengan dirinya sendiri dan
dengan model `PointingKit` — dua hal yang memang bisa diperiksa di Linux.
Batas itu tetap harus ditulis, bukan disembunyikan.

Pakai:
    python3 Tools/check-visuals.py            # ukur semua, lapor
    python3 Tools/check-visuals.py --check    # keluar != 0 kalau ada yang gagal
"""

from __future__ import annotations

import argparse
import math
import os
import re
import struct
import sys
import zlib

import importlib.util

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def _load(name, filename):
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


R = _load("render_visuals", "render-visuals.py")

# Akar repo: `Tools/` ada di bawahnya.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ══════════════════════════════════════════════════════════════════════════
# Pembaca PNG (hanya yang ditulis alat ini: RGBA8, filter 0…4)
# ══════════════════════════════════════════════════════════════════════════

def decode_png(path):
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"bukan PNG: {path}")
    pos, idat, width, height = 8, bytearray(), 0, 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if tag == b"IHDR":
            width, height, depth, ctype = struct.unpack(">IIBB", body[:10])
            if depth != 8 or ctype != 6:
                raise ValueError("hanya RGBA8 yang didukung")
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break
        pos += 12 + length
    raw = zlib.decompress(bytes(idat))
    stride = width * 4
    # Toleransi ini **tidak** boleh dianggap izin: bentuk tanpa byte filter
    # bukan PNG yang sah, dan `check_png_is_well_formed` yang menegakkannya.
    # Cabang "tanpa filter" tinggal untuk membaca berkas lama yang sudah
    # tersimpan di `out/` sebelum cacatnya diperbaiki.
    filtered = len(raw) == height * (stride + 1)
    out, prev = [], bytearray(stride)
    p = 0
    for _ in range(height):
        if filtered:
            ftype = raw[p]
            line = bytearray(raw[p + 1:p + 1 + stride])
            p += 1 + stride
        else:
            ftype = 0
            line = bytearray(raw[p:p + stride])
            p += stride
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            if ftype == 1:
                line[i] = (line[i] + a) & 0xFF
            elif ftype == 2:
                line[i] = (line[i] + b) & 0xFF
            elif ftype == 3:
                line[i] = (line[i] + (a + b) // 2) & 0xFF
            elif ftype == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out.append(bytes(line))
        prev = line
    return width, height, out


def background_of(width, height, rows):
    """Warna latar = piksel sudut (0,0)."""
    return rows[0][0:3]


def is_bright(pixel, background, threshold=0.06):
    """Piksel dianggap 'menyala' bila cukup jauh dari latar."""
    d = sum((pixel[k] - background[k]) ** 2 for k in range(3)) ** 0.5
    return d > threshold * 255


# ══════════════════════════════════════════════════════════════════════════
# Pengukuran
# ══════════════════════════════════════════════════════════════════════════

def lit_centroid(width, height, rows, background, radius_fraction=1.0):
    """Pusat massa piksel menyala di dalam piringan, satuan radius.

    Mengembalikan `(dx, dy, area_fraction)` dengan y ke **bawah** (konvensi
    layar, sama seperti koordinat `GraphicsContext`) — supaya arah yang
    dilaporkan di sini bisa dibandingkan langsung dengan yang digambar.
    """
    cx, cy = width / 2.0, height / 2.0
    radius = min(width, height) / 2.0 * radius_fraction
    sx = sy = count = 0
    for y in range(height):
        row = rows[y]
        for x in range(width):
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) > radius:
                continue
            if is_bright(row[x * 4:x * 4 + 3], background):
                sx += x + 0.5 - cx
                sy += y + 0.5 - cy
                count += 1
    if count == 0:
        return 0.0, 0.0, 0.0
    disc_area = math.pi * radius * radius
    return sx / count / radius, sy / count / radius, count / disc_area


def classify_centroid(width, height, rows, color_a, color_b, radius_fraction=1.0):
    """Pusat massa piksel yang lebih dekat ke `color_a` daripada `color_b`.

    Untuk Bulan, "tersinari" **tidak bisa** diukur terhadap latar: piringan
    yang tidak tersinari tetap jauh lebih terang dari langit malam, jadi
    ambang terhadap latar akan menghitung seluruh piringan sebagai terang
    dan menyembunyikan fasenya sepenuhnya. Yang benar adalah membandingkan
    ke dua warna yang memang ada di gambar — sisi tersinari vs sisi gelap.
    """
    cx, cy = width / 2.0, height / 2.0
    radius = min(width, height) / 2.0 * radius_fraction
    sx = sy = count = 0
    for y in range(height):
        row = rows[y]
        for x in range(width):
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) > radius:
                continue
            p = row[x * 4:x * 4 + 3]
            da = sum((p[k] - color_a[k]) ** 2 for k in range(3))
            db = sum((p[k] - color_b[k]) ** 2 for k in range(3))
            if da < db:
                sx += x + 0.5 - cx
                sy += y + 0.5 - cy
                count += 1
    if count == 0:
        return 0.0, 0.0, 0.0
    disc_area = math.pi * radius * radius
    return sx / count / radius, sy / count / radius, count / disc_area


def edge_touch(width, height, rows, background):
    """Jarak-warna terjauh piksel di cincin terluar dari latar.

    `Canvas` memotong dengan tepi lurus, jadi bentuk yang keluar batas
    berakhir dengan piksel menyala **tepat di pinggir**, bukan memudar ke
    latar. Nilai yang mendekati nol berarti gambar selesai sebelum tepi.
    """
    worst = 0.0
    for x in range(width):
        for y in (0, height - 1):
            p = rows[y][x * 4:x * 4 + 3]
            worst = max(worst, sum((p[k] - background[k]) ** 2
                                   for k in range(3)) ** 0.5)
    for y in range(height):
        for x in (0, width - 1):
            p = rows[y][x * 4:x * 4 + 3]
            worst = max(worst, sum((p[k] - background[k]) ** 2
                                   for k in range(3)) ** 0.5)
    return worst


def brightest_pixel(rows, width, height, x0, y0, x1, y1):
    best, best_d = None, -1
    for y in range(max(0, y0), min(height, y1)):
        row = rows[y]
        for x in range(max(0, x0), min(width, x1)):
            p = row[x * 4:x * 4 + 3]
            d = sum(p)
            if d > best_d:
                best_d, best = d, (p, x, y)
    return best


def max_radius_of_bright(width, height, rows, background):
    """Jarak terjauh piksel menyala dari pusat, satuan radius frame."""
    cx, cy = width / 2.0, height / 2.0
    radius = min(width, height) / 2.0
    best = 0.0
    for y in range(height):
        row = rows[y]
        for x in range(width):
            if is_bright(row[x * 4:x * 4 + 3], background):
                best = max(best, math.hypot(x + 0.5 - cx, y + 0.5 - cy) / radius)
    return best


def band_left_reach(confirmed, sphere_only, band_center_y):
    """Seberapa jauh **pita** menjangkau ke kiri, pada satu ketinggian.

    Mengembalikan `(reach, row)` — jarak dari pusat ke tepi kiri pita, dalam
    satuan radius frame.

    **Kenapa dua gambar, bukan satu.** Versi pertama mengukur "jauh piksel
    menyala" pada baris pita di `planet-jupiter-confirmed` saja, dan hasilnya
    selalu hijau: yang terukur adalah **piringan bola**, yang memang selalu
    sampai tepi di ketinggian mana pun. Cacat yang sebenarnya ada di pita,
    dan pita itu hanya terlihat kalau bolanya dikurangkan.

    `planet-jupiter-uncertain` menggambar bola Jupiter yang **persis sama**
    tanpa pita (ciri pengenal wajib hilang saat ragu — itu aturan yang sudah
    ada), jadi selisih dua gambar itu **hanya** pita. Sisi kiri dipakai
    karena lencana tanda-tanya berada di sudut kanan atas dan akan ikut
    terhitung sebagai pita kalau sisi itu yang diukur.
    """
    w, h, rows_c = confirmed
    _, _, rows_s = sphere_only
    y = min(h - 1, max(0, int(round(band_center_y))))
    row_c, row_s = rows_c[y], rows_s[y]
    cx = w / 2.0
    radius = min(w, h) / 2.0
    for x in range(int(cx)):
        a = row_c[x * 4:x * 4 + 3]
        b = row_s[x * 4:x * 4 + 3]
        # Piksel pita: gambar ber-pita berbeda dari gambar tanpa pita.
        if sum(abs(a[k] - b[k]) for k in range(3)) > 8:
            return (cx - (x + 0.5)) / radius, y
    return 0.0, y


def count_reddish(width, height, rows, x0, y0, x1, y1):
    """Berapa piksel di kotak itu yang kanal merahnya jelas di atas hijau/biru.

    Dipakai untuk mencari **Bintik Merah Besar** dan pita Jupiter: keduanya
    jauh lebih merah dari bola di sekitarnya.
    """
    n = 0
    for y in range(max(0, y0), min(height, y1)):
        row = rows[y]
        for x in range(max(0, x0), min(width, x1)):
            r, g, b = row[x * 4], row[x * 4 + 1], row[x * 4 + 2]
            if r > 90 and r > g + 45 and r > b + 45:
                n += 1
    return n


# ══════════════════════════════════════════════════════════════════════════
# Pemeriksaan
# ══════════════════════════════════════════════════════════════════════════

class Result:
    def __init__(self, name, ok, detail):
        self.name, self.ok, self.detail = name, ok, detail


def render_case(name, night=False, size=200, ss=2):
    case = next(c for c in R.build_cases() if c.name == name)
    canvas = R.render(case, size=size, night_mode=night, show_frame=False, ss=ss)
    path = os.path.join(R.OUT_DIR, f"{name}.png")
    os.makedirs(R.OUT_DIR, exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(canvas.to_png())
    return case, decode_png(path)


def moon_colors():
    """Warna tersinari & gelap Bulan dalam skala 0…255, dari port render."""
    lit = tuple(round(c * 255) for c in R.ACCENTS["moonLit"])
    unlit = tuple(round(c * 255) for c in R.ACCENTS["moonUnlit"])
    return lit, unlit


def check_moon_phase_fraction(results, size=200, ss=2):
    """Luas pita yang benar-benar tergambar harus mengikuti fraksi iluminasi.

    **Ini pemeriksaan yang tidak bisa dilakukan uji model.** `PhaseGeometry`
    sudah diuji di Linux — tetapi yang diuji di sana adalah **rumus kurvanya**,
    bukan luas daerah yang benar-benar diisi setelah dipotong ke piringan dan
    diputar. Cacat yang pernah nyata di repo ini (pita yang menjadi
    **komplemen** untuk f > 0.5, sehingga bulan 85% tampil sebagai sabit 15%)
    lolos semua uji model justru karena kurvanya benar satu per satu.
    """
    lit, unlit = moon_colors()
    for fraction in (0.0, 0.05, 0.18, 0.35, 0.5, 0.65, 0.85, 0.98, 1.0):
        name = f"__moon-{int(fraction * 100)}"
        case = R.VisualCase(name, "sementara", "moon", illumination=fraction,
                            is_waxing=True, bright_limb_angle=None, is_confirmed=True)
        canvas = R.render(case, size=size, night_mode=False, show_frame=False, ss=ss)
        path = os.path.join(R.OUT_DIR, f"{name}.png")
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        width, height, rows = decode_png(path)
        _, _, area = classify_centroid(width, height, rows, lit, unlit)
        # Toleransi longgar: yang dicari bukan presisi, tapi cacat yang
        # membalik komplemen (15% vs 85%) -- selisih yang tidak mungkin
        # tertutup oleh perbedaan rasterisasi.
        ok = abs(area - fraction) < 0.10
        results.append(Result(
            f"luas sabit f={fraction:.2f}", ok,
            f"tergambar {area:.3f}, seharusnya ≈ {fraction:.2f}"))
        os.remove(path)


def check_crescent_direction(results, size=200, ss=2):
    """Sisi terang sabit harus menghadap sudut yang diminta, bukan kebalikannya.

    Kasusnya persis cacat yang ditemukan lewat gambar Python dulu: sudut
    model `-pi/2` (sisi terang ke bawah, seperti sabit muda Jakarta) diteruskan
    apa adanya ke `GraphicsContext.rotate` yang berkoordinat layar akan
    mencerminkannya jadi ke **atas**. Di sini arahnya diukur dari piksel,
    dan yang diukur adalah pusat massa sisi **tersinari** — bukan piksel yang
    lebih terang dari latar, karena seluruh piringan Bulan lebih terang dari
    latar dan ukuran itu tidak membedakan fase sama sekali.
    """
    lit, unlit = moon_colors()
    expectations = [
        (-math.pi / 2, "bawah"),
        (math.pi / 2, "atas"),
        (0.0, "kanan"),
        (math.pi, "kiri"),
    ]
    for angle, expected in expectations:
        name = f"__dir-{expected}"
        case = R.VisualCase(name, "sementara", "moon", illumination=0.15,
                            is_waxing=True, bright_limb_angle=angle,
                            is_confirmed=True)
        canvas = R.render(case, size=size, night_mode=False, show_frame=False, ss=ss)
        path = os.path.join(R.OUT_DIR, f"{name}.png")
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        width, height, rows = decode_png(path)
        dx, dy, _ = classify_centroid(width, height, rows, lit, unlit)
        measured = ("bawah" if dy > abs(dx) else
                    "atas" if -dy > abs(dx) else
                    "kanan" if dx > 0 else "kiri")
        results.append(Result(
            f"sabit sudut {angle:+.2f} → sisi terang", measured == expected,
            f"terukur {measured} (centroid dx={dx:+.3f}, dy={dy:+.3f}), "
            f"seharusnya {expected}"))
        os.remove(path)


def check_moon_phase_survives_uncertainty(results, size=200, ss=2):
    """Fase Bulan harus **tetap tampil** saat engine ragu — dan itu keputusan.

    **Aturan ini dulu hanya prosa.** `STATUS.md` mencatatnya panjang: fase
    Bulan **bukan** ciri yang dicari dari id, jadi ia satu-satunya ciri
    pengenal yang sengaja **tidak** disembunyikan saat ragu. Tapi aturan yang
    tidak diukur adalah aturan yang bisa hilang tanpa suara — dan yang paling
    mungkin menghapusnya justru pembaca yang teliti: tabelnya terlihat seperti
    daftar ciri yang *seharusnya* hilang, dan baris "fase Bulan" di dalamnya
    mudah terbaca sebagai kelalaian.

    Bahayanya konkret dan berlawanan arah dengan semua pemeriksaan lain di
    berkas ini. Semua gerbang lain menuntut **lebih sedikit** yang tampil saat
    ragu; yang ini menuntut satu hal tetap tampil. Kalau `drawMoon` suatu saat
    "diperbaiki" agar menghormati `isConfirmed` seperti planet, tidak ada
    pemeriksaan mana pun yang akan berbunyi — dan yang hilang adalah satu-
    satunya bagian gambar yang **masih benar** saat engine ragu: pengguna
    melihat Bulan sabit dengan mata kepalanya sendiri, dan fase itu fakta
    tentang tanggal, bukan hasil pencarian id.

    Tiga pengukuran, semuanya dari piksel:

    1. **Fase tetap tampil saat ragu.** Bulan sabit yang ragu harus **identik**
       dengan Bulan sabit yang sama saat yakin, di luar kotak lencana. Kalau
       pita fasenya ikut disembunyikan, gambar "ragu" akan menyusut jadi
       piringan gelap dan selisihnya besar.
    2. **Dan itu bukan karena fase tidak pernah digambar.** Bulan sabit harus
       benar-benar berbeda dari Bulan purnama dan dari Bulan cembung — kalau
       pita fasenya hilang di **semua** keadaan, pengukuran 1 akan lolos
       dengan sempurna.
    3. **Arahnya ikut bertahan.** Sabit yang ragu harus tetap menghadap ke
       arah yang sama seperti saat yakin; fase yang tampil tapi terbalik
       lebih buruk daripada fase yang tidak tampil.
    """
    fx0, fy0, fx1, fy1 = R.candidate_marker_footprint()
    margin = 4.0 / (size / 2.0)
    ex0, ey0, ex1, ey1 = (fx0 - margin, fy0 - margin, fx1 + margin, fy1 + margin)

    def outside_badge_diff(a, b):
        """Piksel berbeda di luar kotak lencana antara dua render."""
        w, h, rows_a = a
        _, _, rows_b = b
        radius = min(w, h) / 2.0
        cx, cy = w / 2.0, h / 2.0
        count = 0
        for y in range(h):
            uy = (y + 0.5 - cy) / radius
            if ey0 <= uy <= ey1:
                continue
            ra, rb = rows_a[y], rows_b[y]
            for x in range(w):
                if ra[x * 4:x * 4 + 3] == rb[x * 4:x * 4 + 3]:
                    continue
                ux = (x + 0.5 - cx) / radius
                if not (ex0 <= ux <= ex1):
                    count += 1
        return count

    _, crescent = render_case("moon-crescent-jakarta", size=size, ss=ss)
    _, crescent_uncertain = render_case("moon-crescent-uncertain", size=size, ss=ss)
    diff = outside_badge_diff(crescent, crescent_uncertain)
    results.append(Result(
        "fase Bulan tetap tampil saat ragu", diff == 0,
        f"{diff} piksel berbeda di luar lencana antara sabit yakin & ragu"))

    # Arah sebaliknya: fase memang digambar, dan bentuknya berbeda per fase.
    # Tanpa ini, membuang pita fase di **semua** keadaan akan lolos di atas.
    _, full = render_case("moon-full", size=size, ss=ss)
    _, gibbous = render_case("moon-gibbous", size=size, ss=ss)
    vs_full = outside_badge_diff(crescent_uncertain, full)
    vs_gibbous = outside_badge_diff(crescent_uncertain, gibbous)
    results.append(Result(
        "fase Bulan bukan piringan seragam", vs_full > 0 and vs_gibbous > 0,
        f"sabit vs purnama {vs_full} piksel, sabit vs cembung {vs_gibbous} piksel"))

    # Arah: sabit yang ragu harus menghadap sisi yang sama dengan yang yakin.
    # Diukur lewat selisih terhadap versi yang **tidak diputar**
    # (`moon-crescent-jakarta-unrotated`), bukan lewat centroid: centroid
    # sabit bisa jatuh di sisi mana saja tergantung lebar pita, sedangkan
    # "identik dengan yang yakin" adalah pernyataan yang tepat.
    _, unrotated = render_case("moon-crescent-jakarta-unrotated", size=size, ss=ss)
    turned_away = outside_badge_diff(crescent_uncertain, unrotated)
    results.append(Result(
        "arah sabit bertahan saat ragu", turned_away > 0,
        f"{turned_away} piksel berbeda dari sabit tanpa putaran "
        f"(kalau 0, sudutnya hilang)"))


def check_features_disappear_when_uncertain(results, size=200, ss=2):
    """Ciri pengenal wajib hilang saat engine ragu — diukur dari piksel.

    Aturan 18 menjaga **nilai bawaan**-nya, dan `palette.feature` diuji di
    Linux. Yang tidak pernah diperiksa: apakah view benar-benar **berhenti
    menggambar** ciri itu. Di sini dua render dibandingkan piksel demi piksel.
    """
    pairs = [
        ("planet-jupiter-confirmed", "planet-jupiter-uncertain", "Bintik Merah Besar Jupiter"),
        ("planet-saturn-confirmed", "planet-saturn-uncertain", "cincin Saturnus"),
        # Kelima planet berciri, bukan hanya dua yang kebetulan punya kasus
        # render. Satu `guard isConfirmed` di view menutup kelimanya, tapi
        # aturan yang tidak diukur adalah aturan yang bisa hilang tanpa suara.
        ("planet-mars-confirmed", "planet-mars-uncertain", "kutub Mars"),
        ("planet-mercury-confirmed", "planet-mercury-uncertain", "kawah Merkurius"),
        ("planet-venus-confirmed", "planet-venus-uncertain", "kabut Venus"),
    ]
    # **Lencana "?" dikecualikan.** Ia digambar hanya pada gambar "ragu", jadi
    # ia ikut terhitung di setiap selisih dan membuat `diff > 0` selalu benar
    # — termasuk ketika cirinya tidak pernah digambar sama sekali. Dibuktikan:
    # cincin Saturnus dihapus seluruhnya dari port (bola tetap), dan
    # pemeriksaan ini **tetap hijau** dengan "3904 piksel berbeda", yang
    # seluruhnya lencana. Gerbang yang lulus pada gambar yang jelas salah.
    #
    # Jadi yang diukur hanya piksel di luar kotak lencana. Kotak itu dihitung
    # dari model yang sama dengan yang menggambar lencana, dan konstanta
    # modelnya dijaga pemeriksa drift di bawah — kalau lencananya membesar di
    # view dan kotak ini tidak, pengecualiannya berhenti menutupi lencana dan
    # pemeriksaan ini mulai gagal, bukan diam-diam salah.
    fx0, fy0, fx1, fy1 = R.candidate_marker_footprint()
    # Margin beberapa piksel. Kotak dari model adalah kotak **isi** lencana;
    # lencana digambar dengan garis tepi dan anti-aliasing yang menonjol
    # sedikit di luarnya. Tanpa margin, tepi itu ikut terhitung sebagai
    # "ciri" — dan memang terukur: 93 piksel sisa saat cincin Saturnus
    # dihapus seluruhnya, yang membuat pemeriksaan ini tetap hijau pada
    # gambar yang jelas salah. Marginnya dinyatakan dalam piksel lalu
    # dibagi radius di dalam loop, karena radiusnya baru diketahui setelah
    # gambar pertama dirender.
    margin_px = 4.0
    for confirmed_name, uncertain_name, label in pairs:
        _, confirmed = render_case(confirmed_name, size=size, ss=ss)
        _, uncertain = render_case(uncertain_name, size=size, ss=ss)
        w, h, rows_a = confirmed
        _, _, rows_b = uncertain
        radius = min(w, h) / 2.0
        cx, cy = w / 2.0, h / 2.0
        margin = margin_px / radius
        ex0, ey0, ex1, ey1 = (fx0 - margin, fy0 - margin,
                              fx1 + margin, fy1 + margin)
        diff = 0
        for y in range(h):
            # Baris yang seluruhnya di dalam pita lencana dilewati.
            uy = (y + 0.5 - cy) / radius
            if ey0 <= uy <= ey1:
                continue
            ra, rb = rows_a[y], rows_b[y]
            for x in range(w):
                ux = (x + 0.5 - cx) / radius
                if ex0 <= ux <= ex1:
                    continue
                if ra[x * 4:x * 4 + 3] != rb[x * 4:x * 4 + 3]:
                    diff += 1
        results.append(Result(
            f"{label} hilang saat ragu", diff > 0,
            f"{diff} piksel berbeda di luar lencana (terkunci vs ragu)"))

    # Dan arah sebaliknya: kabut netral pada objek langit dalam harus berbeda
    # dari bentuk galaksinya, bukan kebetulan sama.
    _, galaxy = render_case("deepsky-galaxy", size=size, ss=ss)
    _, neutral = render_case("deepsky-uncertain", size=size, ss=ss)
    w, h, rows_a = galaxy
    _, _, rows_b = neutral
    diff = sum(1 for y in range(h) for x in range(w)
               if rows_a[y][x * 4:x * 4 + 3] != rows_b[y][x * 4:x * 4 + 3])
    results.append(Result("bentuk galaksi hilang saat ragu", diff > 0,
                          f"{diff} piksel berbeda dari kabut netral"))


def check_png_is_well_formed(results, size=64, ss=2):
    """PNG yang ditulis alat render harus **sah menurut spesifikasi PNG**.

    Ini cacat yang sudah nyata, dan yang membuatnya bertahan justru alat
    pemeriksa di sebelahnya. `Canvas.to_png` menulis barisnya **tanpa** byte
    filter per baris, sementara `_png()` — menurut komentarnya sendiri di
    `render-visuals.py` — "menyisipkan satu byte filter 0 per baris". Ia tidak
    melakukannya: `_png()` hanya menggabungkan baris apa adanya. Hasilnya
    arus IDAT berukuran `h * w * 4`, sedangkan spesifikasi PNG menuntut
    `h * (w * 4 + 1)`.

    `check_png_roundtrip` di bawah **lulus** untuk berkas itu, karena
    `decode_png` sengaja dibuat toleran: ia mengukur panjang arus, lalu
    memilih "tidak ada byte filter" kalau panjangnya kurang. Jadi pembaca
    repo ini dan penulis repo ini sepakat satu sama lain, sementara setiap
    pembaca PNG di dunia — Preview, browser, `ffmpeg`, `sips` — menolak
    berkasnya. Persis kelas cacat yang dijaga berkas ini: gerbang yang
    diam-diam mengukur hal lain, dan gambarnya "kelihatan seperti planet"
    sehingga tidak ada yang mencurigainya.

    Pemeriksaan ini karena itu **tidak** memakai `decode_png`. Ia membaca
    arus IDAT dan menguji invarian spesifikasinya secara langsung: panjang
    arus harus `h * (w * 4 + 1)`, dan setiap byte filter di awal baris harus
    0…4. Itu definisi yang akan dipakai pembaca mana pun.
    """
    for name in ("planet-jupiter-confirmed", "moon-crescent-jakarta",
                 "star-betelgeuse", "deepsky-nebula"):
        case = next(c for c in R.build_cases() if c.name == name)
        canvas = R.render(case, size=size, night_mode=False, show_frame=False, ss=ss)
        png = canvas.to_png()

        pos, idat, width, height = 8, bytearray(), 0, 0
        while pos < len(png):
            length = struct.unpack(">I", png[pos:pos + 4])[0]
            tag = png[pos + 4:pos + 8]
            body = png[pos + 8:pos + 8 + length]
            if tag == b"IHDR":
                width, height = struct.unpack(">II", body[:8])
            elif tag == b"IDAT":
                idat += body
            elif tag == b"IEND":
                break
            pos += 12 + length
        raw = zlib.decompress(bytes(idat))
        stride = width * 4
        expected = height * (stride + 1)
        if len(raw) != expected:
            results.append(Result(
                f"PNG sah: {name}", False,
                f"arus IDAT {len(raw)} byte, spesifikasi menuntut {expected} "
                f"(byte filter per baris hilang)"))
            continue
        bad = [y for y in range(height) if raw[y * (stride + 1)] > 4]
        results.append(Result(
            f"PNG sah: {name}", not bad,
            f"{len(bad)} baris dengan byte filter di luar 0…4" if bad
            else f"{height} baris, filter 0…4"))


def check_png_roundtrip(results, size=64, ss=2):
    """PNG yang ditulis alat render harus terbaca kembali **persis** sama.

    Ini uji regresi untuk cacat yang sudah nyata: `Canvas.to_png` pernah
    menulis byte filter 0 per baris **dan** menyerahkannya ke `_png()`, yang
    menulis byte filter lagi lalu memotong ulang buffer seolah tidak ada
    filter. Akibatnya setiap baris bergeser satu byte: gambar yang tersimpan
    buram, dan setiap pengukuran di atasnya mengukur sampah.

    Yang membuat cacat itu bertahan adalah sifatnya: alat ini hanya dipakai
    kalau ada yang membuka PNG-nya, dan hasilnya "kelihatan seperti planet" —
    cukup untuk tidak dicurigai. Uji ini membandingkan buffer di memori
    dengan hasil encode-decode, jadi pergeseran satu byte sekalipun tertangkap
    tanpa perlu ada yang melihat gambarnya.
    """
    for name in ("planet-jupiter-confirmed", "moon-crescent-jakarta",
                 "star-betelgeuse", "deepsky-nebula"):
        case = next(c for c in R.build_cases() if c.name == name)
        canvas = R.render(case, size=size, night_mode=False, show_frame=False, ss=ss)
        path = os.path.join(R.OUT_DIR, "__roundtrip.png")
        os.makedirs(R.OUT_DIR, exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        width, height, rows = decode_png(path)
        mismatched = 0
        for y in range(height):
            for x in range(width):
                expected = tuple(min(255, max(0, int(c * 255 + 0.5)))
                                 for c in canvas.buf[y * width + x])
                if tuple(rows[y][x * 4:x * 4 + 3]) != expected:
                    mismatched += 1
        results.append(Result(
            f"PNG bolak-balik: {name}", mismatched == 0,
            f"{mismatched} piksel berbeda dari buffer di memori"))
        os.remove(path)


def check_port_matches_swift_constants(results):
    """Konstanta port harus masih sama dengan yang ada di view Swift.

    Ini pemeriksaan **pergeseran (drift)**, bukan pemeriksaan gambar. Port ini
    hidup di Python dan view-nya di Swift; keduanya memuat angka yang sama
    (opasitas glow, rasio cincin, fraksi bola). Kalau seseorang mengubah view
    dan lupa port-nya, semua pemeriksaan di atas akan tetap hijau sambil
    mengukur gambar yang **sudah tidak ada lagi** — gerbang yang paling
    berbahaya justru yang diam-diam mengukur hal lain.

    Angka-angka ini dibaca langsung dari sumber Swift, jadi perubahannya
    tertangkap di sini alih-alih menunggu ada yang menyadarinya.
    """
    view = open(os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()
    # Isi berkas port-nya sendiri, bukan path-nya: `source_text in source`
    # terhadap sebuah path selalu salah, dan pemeriksaan yang selalu salah
    # adalah gerbang yang selalu merah — sama tidak bergunanya dengan gerbang
    # yang selalu hijau, hanya lebih berisik.
    port = open(R.SOURCE, encoding="utf-8").read()
    model = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                             "CelestialVisual.swift")).read()
    # Berkas aksen warna, terpisah dari `model`: token mode malam & palet
    # aksen tinggal di sini, dan membaca berkas yang salah akan membuat
    # pemeriksaan "sumber memuat" selalu merah — sama tidak bergunanya dengan
    # yang selalu hijau, hanya lebih berisik.
    night = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                              "NightVisual.swift")).read()
    # `source_text` adalah potongan yang **harus** masih tertulis di sumber
    # Swift-nya, ditulis seperti aslinya (`1.0 / 3.2`, bukan `0.3125`) — kalau
    # ditulis sebagai hasil hitungannya, pemeriksaan ini hanya akan lulus
    # untuk bentuk penulisan yang kebetulan sama.
    checks = [
        ("opasitas glow", R.GLOW_OPACITIES, [0.10, 0.22, 1.0],
         "[0.10, 0.22, 1.0]", view),
        ("rasio sumbu cincin Saturnus", R.saturn_ring()["half_height"], 1.0 / 3.2,
         "1.0 / 3.2", model),
        ("fraksi bola Saturnus", R.saturn_body_radius(R.saturn_ring()), 0.53,
         "bodyFraction: Double = 0.53", model),
        ("opasitas maria", R.MARIA_OPACITY, 0.12,
         "Color.black.opacity(0.12)", view),
        ("langkah jalur Bulan", R.MOON_PATH_STEPS, 72,
         "let steps = 72", view),
        # Sisa angka lapisan gambar. Sampai di sini hanya lima dari sekitar
        # delapan belas konstanta port yang dijaga — jadi mengubah pita
        # Jupiter, cincin Saturnus, kutub Mars, kawah, atau spike bintang di
        # view akan **membiarkan setiap pemeriksaan di atas hijau** sambil
        # mengukur gambar yang sudah tidak ada lagi. Itu persis cacat yang
        # berkas ini ada untuk mencegah, hanya saja lubangnya di gerbangnya
        # sendiri.
        # Dua angka ini pindah bersama rumusnya ke model: `jupiterBands`
        # yang memilikinya, view hanya memakainya. Sumber yang dibaca karena
        # itu `model`, bukan `view` — dan kalau seseorang mengembalikannya ke
        # view, pemeriksaan ini merah, yang memang benar: satu angka yang
        # hidup di dua tempat adalah dua angka yang akan berbeda.
        ("jumlah pita Jupiter", R.BAND_COUNT, 7,
         "count: Int = 7", model),
        ("tinggi pita Jupiter", R.BAND_HEIGHT_FRACTION, 0.11,
         "heightFraction: Double = 0.11", model),
        # Rumus separuh-lebar pita pindah dari view ke model: satu rumus bola
        # (`sqrt(1 - y^2)`) dipakai bersama oleh view, port Python, dan uji
        # Linux. Yang dijaga di sini karena itu **rumusnya**, bukan angkanya —
        # dan arahnya dua bahasa, supaya perbaikan yang dikerjakan di satu
        # tempat tidak bisa diam-diam tidak dikerjakan di tempat lain.
        ("rumus separuh-lebar pita (Swift)", R.BAND_HALF_WIDTH_RULE, "sqrt",
         "(1 - y * y).squareRoot()", model, "CelestialVisual.swift"),
        ("rumus separuh-lebar pita (Python)", R.BAND_HALF_WIDTH_RULE, "sqrt",
         "math.sqrt(max(0.0, 1 - y * y))", port, "render-visuals.py"),
        ("opasitas pita Jupiter", R.BAND_OPACITY, 0.55,
         "opacity(0.55)", view),
        # Pita cincin Saturnus. **Kelas cacat yang sama** dengan Bintik Merah
        # Besar di bawah: struktur yang punya nama di data nyata hidup di
        # dalam view, jadi tidak ada uji Linux yang bisa memeriksanya. Yang
        # dijaga di sini karena itu bukan angkanya saja, melainkan **dari mana
        # view membacanya**: batas pita dan opasitasnya harus datang dari
        # `saturnRingBands()`, bukan ditulis ulang sebagai elips pekat.
        ("pita cincin: batas nyata", R.SATURN_RING_REAL_EDGES,
         [1.11, 1.236, 1.525, 1.95, 2.025, 2.269],
         "let realEdges = [1.11, 1.236, 1.525, 1.95, 2.025, 2.269]", model),
        ("pita cincin: opasitas per pita", R.SATURN_RING_BAND_OPACITIES,
         [0.14, 0.34, 0.78, 0.04, 0.62],
         "let opacities = [0.14, 0.34, 0.78, 0.04, 0.62]", model),
        ("pita cincin: lebar celah Cassini", R.SATURN_CASSINI_WIDTH, 0.06,
         "cassiniWidth: Double = 0.06", model),
        ("pita cincin: skala paruh belakang", R.RING_BACK_HALF_OPACITY_SCALE,
         0.55, "ringBackHalfOpacityScale: Double = 0.55", model),
        # Piringan "fase tidak diketahui". Dijaga **di kedua berkas** dengan
        # alasan yang sama seperti pita cincin: nilainya hidup di dua bahasa,
        # dan perbaikan yang dikerjakan di satu tempat tidak boleh bisa
        # diam-diam tidak dikerjakan di tempat lain. Yang lebih penting lagi:
        # kalau angkanya bergeser sampai menempel ke `moonUnlit`, cacat lama
        # (fase tak diketahui = bulan baru) kembali tanpa suara — karena
        # gambarnya memang masih "piringan polos".
        ("piringan fase tak diketahui (Swift)", R.ACCENTS["moonPhaseUnknown"],
         (0.52, 0.52, 0.55), "moonPhaseUnknown: .init(red: 0.52, green: 0.52, blue: 0.55)",
         night, "NightVisual.swift"),
        ("piringan fase tak diketahui (view memakainya)",
         "CelestialVisual.accents.moonPhaseUnknown" in view, True,
         "Self.accent(CelestialVisual.accents.moonPhaseUnknown)", view),
        # Arah kedua: view harus benar-benar memakai pita, dan menggambarnya
        # **di kedua paruh**. Tanpa pemeriksaan ini, view bisa kembali ke satu
        # elips pekat dengan celah hanya di paruh bawah — bentuk yang sudah
        # terbukti salah — sementara seluruh angka di atas tetap benar.
        ("pita cincin: view memakai saturnRingBands()",
         "VisualFrame.saturnRingBands()" in view, True,
         "let bands = VisualFrame.saturnRingBands()", view),
        ("pita cincin: view menggambar paruh belakang",
         view.count("back.fill(ringPath(") >= 1, True,
         "back.fill(ringPath(CGFloat(band.outerRadius) * fullWidth,", view),
        ("pita cincin: view menggambar paruh depan",
         view.count("front.fill(ringPath(") >= 1, True,
         "front.fill(ringPath(CGFloat(band.outerRadius) * fullWidth,", view),
        ("pita cincin: view tidak lagi memakai elips hitam sebagai celah",
         "Color.black.opacity(0.28)" not in view, True,
         "style: FillStyle(eoFill: true)", view),
        # Bintik Merah Besar. **Empat** angka ini dijaga, dan gerbang yang
        # `SPOT_RECT[0]` (-0.36) — nilai yang **kebetulan sama** di kedua
        # tafsir. Lariknya diperlakukan sebagai **pusat** di port Python,
        # sementara view Swift menulisnya ke `CGRect` sehingga angkanya
        # menjadi **sudut**; jadi gambar yang diukur seluruh gerbang visual
        # menaruh bintiknya 0.26 R (setengah lebarnya sendiri) di sebelah kiri
        # tempat bintik itu benar-benar tergambar di jam. Kedua tafsir
        # menggambar elips yang sama besarnya, jadi tidak ada pemeriksaan
        # bentuk yang bisa membedakannya: yang salah adalah **letaknya**.
        #
        # Karena itu yang dijaga sekarang bukan hanya angkanya, melainkan
        # **konvensinya**: view harus benar-benar menghitung pusat dari
        # `spot.centerX - spot.width / 2`, bukan meneruskan `spot.centerX`
        # apa adanya ke `CGRect`. Rumus yang sama diuji di Linux
        # (`testJupiterSpotIsCenteredNotCornered`), jadi tiga sisi — model,
        # view, port — tidak bisa lagi menyimpang tanpa gerbang berbunyi.
        ("Bintik Merah Besar pusat x", R.SPOT_CENTER[0], -0.10,
         "centerX: Double = -0.10", model),
        ("Bintik Merah Besar pusat y", R.SPOT_CENTER[1], 0.31,
         "centerY: Double = 0.31", model),
        ("Bintik Merah Besar lebar", R.SPOT_SIZE[0], 0.52,
         "width: Double = 0.52", model),
        ("Bintik Merah Besar tinggi", R.SPOT_SIZE[1], 0.26,
         "height: Double = 0.26", model),
        # Arah kedua, dan yang benar-benar menutup cacatnya: **view memakai
        # pusat, bukan sudut**. Tanpa pemeriksaan ini, view bisa kembali ke
        # `CGRect(x: center.x - radius * 0.10, …)` — memakai angka yang benar
        # dengan tafsir yang salah — dan seluruh gerbang di atas tetap hijau.
        ("Bintik Merah Besar: view menghitung pusat (bukan sudut)",
         "spot.centerX - spot.width / 2" in view, True,
         "center.x + CGFloat(spot.centerX - spot.width / 2) * radius", view),
        ("opasitas kutub Mars", R.POLAR_CAP_OPACITY, 0.85,
         "capColor.opacity(0.85)", view),
        # Geometri kutub Mars. **Tiga** hal dijaga, karena angkanya saja tidak
        # cukup: nilai `pinchY`/`depth` yang benar dengan rumus lebar yang
        # dikembalikan ke konstanta akan menghasilkan cacat lama tanpa suara —
        # gambarnya memang masih "elips putih di kutub".
        ("kutub Mars: ketinggian pinch (Swift)",
         R.POLAR_CAP_PINCH_Y, -0.74, "pinchY: Double = -0.74", model),
        ("kutub Mars: kedalaman (Swift)",
         R.POLAR_CAP_DEPTH_FRACTION, 0.26, "depthFraction: Double = 0.26", model),
        ("kutub Mars: lebar diturunkan dari tepi bola (Swift)",
         R.POLAR_CAP_WIDTH_RULE, "sqrt",
         "(1 - pinchY * pinchY).squareRoot()", model),
        ("kutub Mars: lebar diturunkan dari tepi bola (Python)",
         R.POLAR_CAP_WIDTH_RULE, "sqrt",
         "math.sqrt(max(0.0, 1 - pinch_y * pinch_y))", port),
        # Arah kedua: view harus benar-benar **mengiris** elipsnya dengan
        # piringan. Tanpa klip, lebar yang baru (sengaja lebih lebar dari bola
        # di dekat kutub) meluber ke latar — cacat yang sama, arah berlawanan.
        ("kutub Mars: view mengiris dengan piringan",
         "inner.clip(to: disc)" in view, True,
         "var inner = context\n            inner.clip(to: disc)", view),
        ("kutub Mars: view memakai pusat (bukan tepi)",
         "cap.centerY - cap.halfHeight" in view, True,
         "y: center.y + CGFloat(cap.centerY - cap.halfHeight) * radius", view),
        # Matahari: **satu** gradient dari model. Dua hal dijaga, dan keduanya
        # perlu — profil yang benar di model tidak menolong kalau view tidak
        # memakainya, dan view yang memakai profil bisa kehilangan bentuknya
        # kalau ia menggambar piringan kedua di atasnya.
        #
        # Arah "view memakai profil" dijaga oleh pemeriksaan **gambar**
        # (`check_sun_edge_is_soft`), bukan oleh pencarian teks `sunProfile(`
        # yang dulu berdiri di sini. Pencarian teks itu hijau walaupun
        # hasilnya dibuang: yang menentukan bukan namanya dipanggil, melainkan
        # apa yang sampai ke piksel.
        ("Matahari: view memakai Gradient(stops:)", True, True,
         "radialGradient(Gradient(stops: stops),", view),
        ("Matahari: view tidak menggambar piringan kedua",
         "core.opacity(0.42)" not in view, True,
         "let stops = profile.map { stop -> Gradient.Stop in", view),
        # Kawah: warna & arah datangnya dari model. Entri lama di sini
        # ("opasitas kawah" → `Color.black.opacity(0.18)`) sudah **dihapus**,
        # bukan diperbarui: kawahnya memang tidak lagi digambar sebagai satu
        # cakram hitam. Menggantinya dengan angka baru akan menjadikan gerbang
        # ini penjaga bentuk yang sudah ditinggalkan. Bentuk barunya dijaga
        # `check_crater_relief_matches_the_model`.
        ("warna dasar kawah (Swift)", R.ACCENTS["craterFloor"], (0.16, 0.155, 0.15),
         "craterFloor: .init(red: 0.16, green: 0.155, blue: 0.15)", night),
        ("warna bibir kawah (Swift)", R.ACCENTS["craterRim"], (0.86, 0.84, 0.81),
         "craterRim: .init(red: 0.86, green: 0.84, blue: 0.81)", night),
        # Arah kedua, dan yang paling penting untuk kawah: view harus
        # **memakai** kedua token itu dan menurunkan arah bibirnya dari model.
        # Kalau tidak, warna yang benar di atas tetap menghasilkan cakram
        # gelap rata — bentuk yang sudah terbukti salah di ukuran jam.
        ("kawah: view memakai warna dasar dari model",
         "Self.accent(CelestialVisual.accents.craterFloor)" in view, True,
         "let floor = Self.accent(CelestialVisual.accents.craterFloor)", view),
        ("kawah: view memakai warna bibir dari model",
         "Self.accent(CelestialVisual.accents.craterRim)" in view, True,
         "let rim = Self.accent(CelestialVisual.accents.craterRim)", view),
        ("kawah: view menurunkan arah bibir dari model",
         "CelestialVisual.craterRelief(" in view, True,
         "let relief = CelestialVisual.craterRelief(", view),
        ("kawah: view tidak lagi menggambar cakram hitam rata",
         ".color(Color.black.opacity(0.18))" not in view, True,
         "let relief = CelestialVisual.craterRelief(", view),
        # Arah cahaya bola. Angka ini dulu ditulis **dua kali** — sekali
        # sebagai pusat gradien di view, sekali lagi di port Python — dan
        # keduanya harus sama supaya bibir kawah yang terang menghadap sisi
        # yang benar. Sekarang satu konstanta di model; pemeriksaan ini yang
        # memastikan tidak ada salinan ketiga yang muncul kembali.
        ("arah cahaya bola: model punya konstantanya",
         R.SPHERE_LIGHT_OFFSET, (-0.32, -0.32),
         "sphereLightOffset = (x: -0.32, y: -0.32)", model),
        ("arah cahaya bola: view memakainya, bukan menulis ulang",
         view.count("0.32") == 1, True,
         "CelestialVisual.sphereLightOffset.x", view),
        ("kawah pertama Merkurius", tuple(R.CRATERS[0]), (-0.30, -0.22, 0.20),
         "(-0.30, -0.22, 0.20)", view),
        ("maria pertama Bulan", tuple(R.MARIA[0]), (-0.28, -0.30, 0.26),
         "(-0.28, -0.30, 0.26)", view),
        ("opasitas spike bintang", R.SPIKE_OPACITY, 0.45,
         "color.opacity(0.45)", view),
        # Gambar kawah Merkurius. Kelima angka ini ada di **dua bahasa** dan
        # sampai sini **tidak dijaga siapa pun**: mutasi empat di antaranya di
        # view membuat seluruh 195 pemeriksaan tetap hijau (dibuktikan saat
        # penyuntingan). Yang hilang bukan cuma "kawah jadi lebih redup" —
        # `check_mars_caps_touch_the_limb` dan pengukuran relief kawah yang
        # membaca gambar ini ikut mengukur gambar yang tidak pernah tampil
        # di jam.
        #
        # Dua di antaranya (**geseran** dan **skala dasar**) sengaja dihapus
        # dari port: nilainya tidak pernah dipakai di sana, jadi mengunci
        # "nilai port yang tidak dihitung" akan menjaga larik mati sebagai
        # seolah-olah ia dihitung. Lihat `check_crater_drawing_constants` —
        # pemeriksaan yang menghapus konstanta mati itu.
        ("opasitas dasar kawah", R.CRATER_FLOOR_OPACITY, 0.85,
         "floor.opacity(0.85)", view),
        ("opasitas bibir kawah", R.CRATER_RIM_OPACITY, 0.90,
         "rim.opacity(0.9 * CGFloat(crater.rimStrength))", view),
        ("opasitas dasar dalam kawah", R.CRATER_INNER_FLOOR_OPACITY, 0.75,
         "with: .color(floor.opacity(0.75)))", view),
        # Lencana "?" — angkanya dipakai untuk **mengecualikan** daerah lencana
        # dari pengukuran ciri di atas. Kalau lencananya berubah di view tanpa
        # port ini ikut berubah, kotak pengecualiannya tidak lagi menutupi
        # lencana, dan selisih "terkunci vs ragu" mulai dihitung dari piksel
        # lencana lagi — persis cacat yang pengecualian ini tutup.
        ("lencana: fraksi sudut", R.CANDIDATE_CORNER_FRACTION, 0.34,
         "cornerFraction: Double = 0.34", model),
        ("lencana: jarak tepi", R.CANDIDATE_INSET, 0.06,
         "inset: Double = 0.06", model),
        ("lencana: fraksi glif", R.CANDIDATE_GLYPH_FRACTION, 0.52,
         "glyphFraction: Double = 0.52", model),
        # Palet mode malam. Tiga angka ini tinggal di `NightVisual.swift` dan
        # **diport** Python untuk menggambar ulang mode malam pada PNG, dan
        # sampai sini tidak dijaga. Yang hilang bukan cuma warnanya: seluruh
        # `check_night_mode_purity` — yang menyapu mode malam untuk hijau/biru
        # — tidak bisa melihat perubahan yang **bukan** hijau/biru. Menggeser
        # `floorBrightness` tidak membuat satu pun pemeriksaan merah, padahal
        # ia mengubah seluruh kecerahan mode malam.
        #
        # Arah kedua (port == model) yang dijaga; arah ketiga (view memakainya)
        # dijaga oleh `SurfacePaletteTests` di Linux lewat kontras.
        ("mode malam: batas bawah kecerahan", R.NIGHT_FLOOR_BRIGHTNESS, 0.35,
         "floorBrightness: Double = 0.35", night),
        ("mode malam: rentang kecerahan", R.NIGHT_RANGE_BRIGHTNESS, 0.65,
         "rangeBrightness: Double = 0.65", night),
        ("mode malam: fraksi bayangan", R.NIGHT_SHADOW_FRACTION, 0.5,
         "shadowFraction: Double = 0.5", night),
        # Bola netral untuk benda yang **tidak dikenali**. Dipakai view sebagai
        # `neutralBody`/`neutralShadow` dan diport untuk gambar yang sama.
        # Yang berbahaya di sini justru nilai warna: bola ungu atau ungu
        # kebiruan akan terlihat seperti "planet tertentu", padahal yang
        # diketahui hanya "planet yang tidak kita kenal" — persis klaim
        # identitas yang dilarang PRD. Angka tuannya sudah menjaga netralitas;
        # yang belum dijaga adalah **letaknya**, dan letaknya ada di view.
        ("bola netral: terang", R.NEUTRAL_BODY, (0.74, 0.72, 0.68),
         "neutralBody = CelestialVisual.RGBComponents(red: 0.74, green: 0.72, blue: 0.68)",
         view),
        ("bola netral: bayangan", R.NEUTRAL_SHADOW, (0.28, 0.27, 0.26),
         "neutralShadow = CelestialVisual.RGBComponents(red: 0.28, green: 0.27, blue: 0.26)",
         view),
    ]
    # Palet planet. Hingga sini **tidak dijaga siapa pun**: `PLANET_PALETTE`
    # di port Python dan `Planet.palette` di Swift memuat warna + pemetaan
    # ciri yang sama untuk kelima planet, dan mengubah salah satu sisi
    # membiarkan seluruh pemeriksaan di atas hijau sambil mengukur gambar
    # yang sudah tidak ada lagi. (STATUS.md — "sisa yang paling bernilai".)
    #
    # Dua arah dijaga: (1) tiap planet di model harus cocok warnanya di port,
    # (2) tiap planet di port harus ada di model — jadi penambahan planet
    # baru ke satu sisi tanpa pasangannya ikut merah, bukan diam.
    swift_planets = read_planet_palettes_from_swift(model)
    for name, (light, dark, feature) in swift_planets.items():
        if name not in R.PLANET_PALETTE:
            results.append(Result(
                f"palet planet: {name} ada di kedua sisi", False,
                f"{name} hilang dari PLANET_PALETTE port"))
            continue
        port_entry = R.PLANET_PALETTE[name]
        results.append(Result(
            f"palet planet: {name} terang (port == model)",
            all(abs(a - b) < 1e-6 for a, b in zip(light, port_entry["light"])),
            f"port={port_entry['light']}, model={light}"))
        results.append(Result(
            f"palet planet: {name} gelap (port == model)",
            all(abs(a - b) < 1e-6 for a, b in zip(dark, port_entry["dark"])),
            f"port={port_entry['dark']}, model={dark}"))
        results.append(Result(
            f"palet planet: {name} ciri (port == model)",
            feature == port_entry["feature"],
            f"port={port_entry['feature']}, model={feature}"))
    for name in R.PLANET_PALETTE:
        if name not in swift_planets:
            results.append(Result(
                f"palet planet: {name} di port ada di model", False,
                f"{name} tidak ada di Planet.palette Swift"))

    for check in checks:
        label, port_value, expected, source_text, source = check[:5]
        # Nama berkas sumber ikut, bukan "sumber Swift" yang dipaku: dua
        # pemeriksaan di bawah menjaga **dua** berkas (view/model Swift dan
        # port Python), dan pesan yang menyebut berkas yang salah adalah
        # pesan yang mengirim orang ke tempat yang tidak berisi apa-apa.
        where = check[5] if len(check) > 5 else "sumber Swift"
        results.append(Result(
            f"port sejalan: {label}", port_value == expected,
            f"port={port_value}, seharusnya {expected}"))
        results.append(Result(
            f"sumber memuat: {label}", source_text in source,
            f"'{source_text}' {'ditemukan' if source_text in source else 'TIDAK ditemukan'}"
            f" di {where}"))


def swift_tuple_triples(source, anchor, terminator="]"):
    """Semua `(a, b, c)` dari sumber Swift, mulai setelah `anchor`.

    Dipakai untuk membandingkan **seluruh** larik, bukan elemen pertamanya.
    Angka dikembalikan sebagai `float` supaya `0.10` dan `0.1` dianggap sama —
    yang dibandingkan nilainya, bukan cara menulisnya.
    """
    start = source.index(anchor) + len(anchor)
    end = source.index(terminator, start)
    region = source[start:end]
    return [tuple(float(v) for v in match)
            for match in re.findall(
                r"\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,"
                r"\s*(-?\d+(?:\.\d+)?)\s*\)", region)]


def read_planet_palettes_from_swift(source):
    """Baca seluruh `Planet.palette` dari teks Swift, per planet.

    Pemetaan planet → warna + ciri hidup di **dua bahasa** (`Planet.palette`
    di Swift dan `PLANET_PALETTE` di port Python). Yang dijaga di sini bukan
    satu angka, melainkan **tiap** `case` di dalam `switch` — sehingga
    perubahan warna pada satu planet di salah satu sisi merah, bukan diam.

    Pembacaan mengikuti bentuk yang sudah ditulis di `CelestialVisual.swift`:
    tiap cabang `case .<nama>:` mengembalikan `.init(light: .init(red: r,
    green: g, blue: b), dark: .init(red: r, green: g, blue: b), feature:
    .<ciri>)`. Nama berkas yang salah akan membuat `source.index(...)` lempas
    — itu kegagalan yang disengaja, bukan pengecualian tersembunyi: pesannya
    menyebut `var palette` supaya pembaca tahu apa yang harus dikembalikan.
    """
    anchor = "var palette: CelestialVisual.Palette {"
    if anchor not in source:
        raise ValueError("'var palette' tidak ditemukan di CelestialVisual.swift")
    region = source[source.index(anchor):]
    out: dict[str, tuple[tuple[float, float, float],
                          tuple[float, float, float], str]] = {}
    for m in re.finditer(
            r"case \.(\w+):\s*"
            r"return \.init\(\s*"
            r"light:\s*\.init\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\)"
            r"[\s\S]*?"
            r"dark:\s*\.init\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\)"
            r"[\s\S]*?"
            r"feature: \.(\w+)\)", region):
        name = m.group(1)
        light = (float(m.group(2)), float(m.group(3)), float(m.group(4)))
        dark = (float(m.group(5)), float(m.group(6)), float(m.group(7)))
        feature = m.group(8)
        out[name] = (light, dark, feature)
    return out


def swift_sextuples(source, anchor, terminator="]"):
    """Semua `(a, b, c, d, e, f)` dari sumber Swift, mulai setelah `anchor`.

    Padanan `swift_tuple_triples` untuk layout objek langit dalam: enam
    angka per blob (geser x, geser y, skala lebar, rasio sumbu, sudut,
    opasitas). Alasannya sama persis — yang dibandingkan **seluruh** larik,
    dan angkanya sebagai `float` supaya `0.30` sama dengan `0.3`.
    """
    start = source.index(anchor) + len(anchor)
    end = source.index(terminator, start)
    region = source[start:end]
    number = r"\s*(-?\d+(?:\.\d+)?)\s*"
    return [tuple(float(v) for v in match)
            for match in re.findall(r"\(" + ",".join([number] * 6) + r"\)",
                                    region)]


def read_deep_sky_layouts_from_swift(source):
    """Baca **tiap** layout objek langit dalam dari teks Swift.

    Tata letak blob hidup di dua bahasa: `VisualFrame.nebula` / `.deepSky`
    di Swift dan `DEEP_SKY_LAYOUT` di port Python. Sampai pemeriksaan ini
    ada, **tidak satu pun** dari ~60 angka itu dijaga: menggeser satu blob
    galaksi di model akan membiarkan setiap pemeriksaan gambar hijau sambil
    mengukur bentuk yang sudah tidak ada lagi — cacat yang berkas ini ada
    untuk mencegah, dan yang sudah muncul untuk palet planet, kawah, dan
    maria.

    Nama kuncinya sama dengan `Morphology.rawValue`, ditambah `"nebula"`
    untuk bentuk netral (`VisualFrame.nebula`, yang dipakai saat morfologi
    `nil`). Dibaca dari sumber, bukan ditulis sebagai daftar: daftar tangan
    adalah daftar yang bisa tertinggal separuh saat bentuk baru ditambah.
    """
    out: dict[str, list[tuple[float, ...]]] = {}

    # Bentuk netral: fungsi `nebula(fuzziness:...)`.
    anchor = "public static func nebula(fuzziness: Double,"
    if anchor not in source:
        raise ValueError(
            "'public static func nebula(' tidak ditemukan di CelestialVisual.swift")
    region = source[source.index(anchor):]
    out["nebula"] = swift_sextuples(region, "let layout: [(Double, Double, "
                                            "Double, Double, Double, Double)] = [")

    # Empat bentuk bermorfolgi di dalam `switch morphology`.
    switch = "public static func deepSky(morphology:"
    if switch not in source:
        raise ValueError(
            "'public static func deepSky(' tidak ditemukan di CelestialVisual.swift")
    region = source[source.index(switch):]
    for name in ("planetaryNebula", "galaxy", "openCluster", "globularCluster"):
        marker = f"case .{name}:"
        if marker not in region:
            raise ValueError(f"'{marker}' tidak ditemukan di CelestialVisual.swift")
        tail = region[region.index(marker):]
        # `.planetaryNebula` menyusun layout lewat `zip` dari `ring`, jadi
        # angkanya tidak berbentuk larik segi-enam — ia punya pembacaan
        # sendiri, dan tanpa itu bentuk ini akan dilaporkan "hilang".
        if "let ring:" in tail[:tail.index("return buildDeepSky")]:
            out[name] = _shell_layout_from_swift(tail)
            continue
        out[name] = swift_sextuples(tail, "let layout: [(Double, Double, "
                                          "Double, Double, Double, Double)] = [")
    return out


def _shell_layout_from_swift(tail):
    """Layout cangkang `.planetaryNebula` dari `ring` + `shellOpacity`.

    Modelnya **tidak** menulis enam angka per blob: ia menulis delapan posisi
    (`ring`), lalu menggabungkannya dengan `shellOpacity` lewat `zip`, dengan
    skala lebar `0.30`, rasio sumbu `1.0`, sudut `0.0`. Port Python menyimpan
    hasilnya yang sudah di-`zip`. Jadi yang dibandingkan di sini adalah
    **hasil** yang sama, dihitung dari bentuk sumbernya — bukan angka yang
    disalin.
    """
    # Isi `ring` diambil **setelah** `[` pembuka: anotasinya sendiri
    # (`[(Double, Double)]`) juga berbentuk pasangan, dan ikut terbaca
    # kalau potongannya dimulai dari `let ring:` — `float("Double")`.
    ring_start = tail.index("let ring:")
    ring_open = tail.index("= [", ring_start) + len("= [")
    ring_region = tail[ring_open:tail.index("]", ring_open)]
    pairs = re.findall(r"\(\s*(-?[\w.]+)\s*,\s*(-?[\w.]+)\s*\)", ring_region)
    shell_radius = float(re.search(r"let shellRadius = ([\d.]+)", tail).group(1))
    diagonal = shell_radius / 2.0 ** 0.5
    names = {"shellRadius": shell_radius, "diagonal": diagonal}
    opacities = [float(v) for v in re.search(
        r"let shellOpacity = \[([\d.,\s]+)\]", tail).group(1).split(",")]
    width_scale = float(re.search(
        r"\(offset\.0, offset\.1, ([\d.]+),", tail).group(1))
    aspect = float(re.search(
        r"\(offset\.0, offset\.1, [\d.]+, ([\d.]+),", tail).group(1))
    angle = float(re.search(
        r"\(offset\.0, offset\.1, [\d.]+, [\d.]+, (-?[\d.]+),", tail).group(1))
    out = []
    for (xs, ys), opacity in zip(pairs, opacities):
        def value(token):
            token = token.strip()
            if token.lstrip("-") in names:
                sign = -1 if token.startswith("-") else 1
                return sign * names[token.lstrip("-")]
            return float(token)
        out.append((value(xs), value(ys), width_scale, aspect, angle, opacity))
    return out


def check_deep_sky_layouts_match_the_model(results):
    """Tata letak objek langit dalam tidak boleh menyimpang antar bahasa.

    **Cacat yang ditutup pemeriksaan ini.** Lima bentuk objek langit dalam
    (nebula netral + empat morfologi) hidup sebagai ~60 angka di
    `CelestialVisual.swift` dan lagi di `DEEP_SKY_LAYOUT` pada
    `render-visuals.py`. `check_deep_sky_morphologies_render_distinct`
    mengukur bahwa bentuk-bentuk itu **berbeda satu sama lain** — dan itu
    tetap hijau meski seluruh 60 angkanya berubah, selama mereka tetap
    berbeda. Jadi tidak ada satu pun yang menjaga bahwa port menggambar
    bentuk yang sama dengan model.

    Akibatnya persis yang sudah dua kali terjadi di repo ini: mengubah
    model tanpa port membuat **setiap pemeriksaan gambar mengukur gambar
    yang tidak pernah ada** — dan tidak ada layar yang berubah, karena
    tidak ada yang tampil di Linux.

    Dibaca dari sumber di kedua sisi, elemen per elemen, dua arah: merah
    kalau port menyimpang **atau** kalau model berubah tanpa port-nya ikut,
    dan merah juga kalau salah satu bentuk hilang dari salah satu sisi.
    """
    source = open(os.path.join(
        ROOT, "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift")).read()
    try:
        swift = read_deep_sky_layouts_from_swift(source)
    except ValueError as exc:
        # Jangkar hilang = kegagalan bersih yang menyebut jangkarnya. Gerbang
        # yang melempar traceback saat modelnya dirapikan akan dihapus orang.
        results.append(Result("tata letak objek langit dalam: terbaca dari model",
                              False, str(exc)))
        return

    port = R.DEEP_SKY_LAYOUT

    missing_in_port = sorted(set(swift) - set(port))
    results.append(Result(
        "tata letak objek langit dalam: setiap bentuk model ada di port",
        not missing_in_port,
        "semua bentuk ada" if not missing_in_port
        else f"tidak ada di port: {missing_in_port}"))

    extra_in_port = sorted(set(port) - set(swift))
    results.append(Result(
        "tata letak objek langit dalam: tidak ada bentuk sisa di port",
        not extra_in_port,
        "tidak ada" if not extra_in_port
        else f"hanya ada di port: {extra_in_port}"))

    for name in sorted(set(swift) & set(port)):
        a, b = swift[name], [tuple(float(v) for v in row) for row in port[name]]
        if len(a) != len(b):
            results.append(Result(
                f"tata letak {name}: jumlah blob sama",
                False, f"model {len(a)}, port {len(b)}"))
            continue
        # Dibandingkan per elemen supaya pesannya menyebut **indeks**: "tidak
        # sama" tidak memberi tahu apakah ada blob yang hilang, salah tempat,
        # atau bertambah di akhir.
        bad = [i for i, (x, y) in enumerate(zip(a, b))
               if any(abs(p - q) > 1e-9 for p, q in zip(x, y))]
        results.append(Result(
            f"tata letak {name}: tiap blob sama dengan model",
            not bad,
            f"semua {len(a)} blob cocok" if not bad
            else f"beda di indeks {bad}: model {[a[i] for i in bad]}, "
                 f"port {[b[i] for i in bad]}"))


def check_feature_arrays_match_the_view(results):
    """Larik kawah & maria harus cocok **seluruhnya**, bukan elemen pertamanya.

    **Cacat yang ditutup pemeriksaan ini.** Gerbang pergeseran di atas menjaga
    `CRATERS[0]` dan `MARIA[0]` — satu elemen dari lima dan satu dari empat.
    Sisa tujuh angka tidak dijaga siapa pun: mengubah kawah keempat Merkurius
    di view akan **membiarkan setiap pemeriksaan hijau** sambil mengukur
    gambar yang sudah tidak ada lagi. Itu persis cacat yang berkas ini ada
    untuk mencegah, dan polanya sama dengan yang sudah dua kali muncul:
    gerbang yang mengukur sebagian dari apa yang diklaimnya.

    Elemen pertama saja yang dijaga kemungkinan besar karena menulis sepuluh
    pemeriksaan satu per satu terasa berlebihan — dan itu tepat alasan yang
    membuat lubangnya tidak terlihat. Di sini kedua sisi **dibaca dari
    sumbernya**: larik port dari berkas port, larik view dari teks Swift-nya.
    Tidak ada daftar yang harus diperbarui dengan tangan, jadi tidak ada
    daftar yang bisa tertinggal separuh.

    Arahnya juga dua bahasa: pemeriksaan ini merah kalau port menyimpang
    **atau** kalau view berubah tanpa port-nya ikut — yang kedua tidak bisa
    dilihat oleh pemeriksaan gambar mana pun, karena gambar itu sendiri yang
    ikut berubah.
    """
    view = open(os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()
    for label, port_array, anchor in (
            ("kawah Merkurius", R.CRATERS,
             "let craters: [(CGFloat, CGFloat, CGFloat)] = ["),
            ("maria Bulan", R.MARIA, "for (dx, dy, size) in [")):
        # Jangkar yang hilang adalah **kegagalan**, bukan pengecualian. Gerbang
        # yang melempar traceback saat view-nya dirapikan akan dihapus orang,
        # dan aturan yang dihapus tidak menjaga apa pun. Pesannya menyebut
        # jangkarnya supaya yang membacanya tahu apa yang harus diperbarui.
        if anchor not in view:
            results.append(Result(
                f"larik {label}: jangkar masih ada di view", False,
                f"'{anchor}' TIDAK ditemukan di CelestialVisualView.swift"))
            continue
        swift_array = swift_tuple_triples(view, anchor)
        results.append(Result(
            f"larik {label}: jumlah sama dengan view",
            len(swift_array) == len(port_array),
            f"port {len(port_array)}, view {len(swift_array)}"))
        # Dibandingkan elemen per elemen supaya pesannya menyebut **indeks**
        # yang berbeda: "lariknya tidak sama" tidak memberi tahu apakah ada
        # yang salah tempat, hilang, atau bertambah di akhir.
        mismatched = [i for i, (a, b) in enumerate(zip(port_array, swift_array))
                      if any(abs(x - y) > 1e-9 for x, y in zip(a, b))]
        results.append(Result(
            f"larik {label}: tiap elemen sama dengan view",
            not mismatched and len(swift_array) == len(port_array),
            "semua elemen cocok" if not mismatched
            else f"beda di indeks {mismatched}: port "
                 f"{[port_array[i] for i in mismatched]}, view "
                 f"{[swift_array[i] for i in mismatched]}"))


def check_crater_drawing_constants(results):
    """Konstanta gambar kawah di port harus **dipakai**, dan dalam view.

    **Cacat yang ditutup pemeriksaan ini.** Port punya lima konstanta
    `CRATER_*`. Dua di antaranya — `CRATER_RIM_OFFSET` (0.55) dan
    `CRATER_INNER_SCALE` (0.62) — **tidak pernah dirujuk** di mana pun di
    berkas port: nilainya ada di view sebagai `size * 0.45` dan
    `size * 0.5`, jadi pada view diskretnya `0.45` dan `0.5`, bukan `0.55`
    dan `0.62`.

    Dua arah yang sama-sama salah, dan justru karena itu tidak terlihat:

    - **Angkanya sudah menyimpang** dari view yang ia gambarkan (0.55 vs
      0.45; 0.62 vs 0.5) — bukan hanya tidak terpakai. Kalau suatu saat ada yang
      "mengaktifkan" konstanta itu di port, gambar kawah di PNG akan langsung
      menyimpang dari gambar kawah di jam.
    - **Menjaganya akan menjebak cacat.** Kalau konstanta mati ini ikut
      dimasukkan ke gerbang pergeseran di atas, gerbang itu akan hijau
      selama port dan view **saling menyimpang** — persis "penulis dan
      pembaca repo ini sepakat satu sama lain".

    Port harus memakai diskret yang sama dengan view, dan pemeriksaannya
    memverifikasi **pemakaian**, bukan hanya keberadaannya: konstanta yang
    ada tapi tidak dirujuk adalah nilai yang tidak diukur siapa pun.
    """
    port = open(R.SOURCE, encoding="utf-8").read()
    view = open(os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()

    # (nama konstanta port, faktor yang dipakai view, baris pemakaian di port,
    #  baris yang harus tetap hidup di view)
    used = (
        ("CRATER_RIM_OFFSET", 0.45,
         "offset = mr * CRATER_RIM_OFFSET",
         "let offset = size * 0.45"),
        ("CRATER_INNER_SCALE", 0.5,
         "mr * CRATER_INNER_SCALE,",
         "let innerSize = size * 0.5"),
    )
    for name, view_value, port_use, view_text in used:
        # 1. Angkanya harus sama dengan diskret view. Ini yang menangkap
        #    keliruan "0.55 = 0.45 + 0,1 pengaman" yang terlihat masuk akal.
        results.append(Result(
            f"kawah: {name} sama dengan diskret view",
            abs(R.__dict__[name] - view_value) < 1e-9,
            f"port={R.__dict__[name]}, view memakai {view_value}"))
        # 2. Dan pemakaiannya harus benar-benar **menyebut konstanta itu**,
        #    bukan angka yang sama ditulis ulang. Tanpa baris ini, port dan view
        #    bisa saling menyimpang di belakang gerbang — persis kelas cacat
        #    yang pemeriksaan pergeseran lain ada untuk mencegah.
        results.append(Result(
            f"kawah: {name} dihitung dari konstantanya sendiri",
            port_use in port and view_text in view,
            f"port memakai '{port_use}' = "
            f"{'ada' if port_use in port else 'TIDAK'}, view memakai '{view_text}' = "
            f"{'ada' if view_text in view else 'TIDAK'}"))


def check_sun_profile_matches_the_model(results):
    """Profil Matahari di port Python harus sama dengan model Swift — angkanya.

    **Cacat yang ditutup pemeriksaan ini.** Port gambar hidup di Python,
    modelnya di `CelestialVisual.swift`. Versi pertama port menulis stop
    Matahari sebagai 0.94/0.62/0.30/0.10 sementara model memakai
    0.95/0.66/0.34/0.13 — dan **tidak satu pun** dari 163 pemeriksaan yang
    berbunyi, termasuk `check_sun_edge_is_soft` yang ditulis persis untuk
    bentuk baru ini. Ia hijau karena pergeseran 0.01–0.04 tidak melewati
    ambangnya, dan ambang itu memang tidak boleh diperketat sampai di situ.

    Jadi yang salah bukan ambangnya, melainkan **ketiadaan gerbang**: selama
    angka port tidak diikat ke model, seluruh pemeriksaan gambar Matahari
    mengukur gambar yang tidak pernah tampil di jam, dan perbaikan di model
    akan dilaporkan sebagai "tidak berpengaruh" apa pun hasilnya.

    Yang dibandingkan hanya **radius dan kelegapan**. Warnanya sengaja tidak
    ikut: port menerjemahkan warna mode malam lebih dulu (`night_surface`),
    jadi bentuk yang sah di kedua sisi memang berbeda.

    Arahnya dua bahasa, sama seperti `check_feature_arrays_match_the_view`:
    merah kalau port menyimpang, **atau** kalau model berubah tanpa port-nya
    ikut — yang kedua tidak bisa dilihat pemeriksaan gambar mana pun, karena
    gambar acuannya sendiri yang ikut berubah.
    """
    model = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                             "CelestialVisual.swift")).read()
    port = open(R.SOURCE, encoding="utf-8").read()

    # Jangkar hilang = gagal bersih yang menyebut jangkarnya, bukan traceback.
    # Gerbang yang melempar pengecualian saat berkasnya dirapikan akan dihapus
    # orang, dan aturan yang dihapus tidak menjaga apa pun.
    anchors = (
        ("model", model, "sunProfile(core: CelestialVisual.RGBComponents,"),
        ("port", port, "def sun_profile(core, photosphere):"),
    )
    regions = {}
    for label, source, anchor in anchors:
        if anchor not in source:
            results.append(Result(
                f"profil Matahari: jangkar {label} masih ada", False,
                f"'{anchor}' TIDAK ditemukan"))
            return
        regions[label] = source[source.index(anchor):]

    swift_pairs = [(float(r), float(o)) for r, o in re.findall(
        r"radiusFraction:\s*(-?\d+(?:\.\d+)?)\s*,\s*color:[^,]+,\s*"
        r"opacity:\s*(-?\d+(?:\.\d+)?)", regions["model"])]
    python_pairs = [(float(r), float(o)) for r, o in re.findall(
        r"\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(?:core|photosphere)\s*,\s*"
        r"(-?\d+(?:\.\d+)?)\s*\)", regions["port"])]

    results.append(Result(
        "profil Matahari: jumlah stop sama",
        len(swift_pairs) == len(python_pairs) and len(swift_pairs) >= 3,
        f"model {len(swift_pairs)} stop, port {len(python_pairs)} stop"))
    mismatched = [i for i, (a, b) in enumerate(zip(python_pairs, swift_pairs))
                  if abs(a[0] - b[0]) > 1e-9 or abs(a[1] - b[1]) > 1e-9]
    results.append(Result(
        "profil Matahari: tiap stop sama dengan model",
        not mismatched and len(swift_pairs) == len(python_pairs),
        "semua stop cocok" if not mismatched
        else f"beda di indeks {mismatched}: port "
             f"{[python_pairs[i] for i in mismatched]}, model "
             f"{[swift_pairs[i] for i in mismatched]}"))


def check_crater_relief_matches_the_model(results):
    """Bayangan kawah di port Python harus sama dengan model Swift — arahnya.

    **Cacat yang ditutup pemeriksaan ini.** Bibir kawah yang terang harus
    menghadap **sumber cahaya**, dan sisi itu ditentukan oleh
    `CelestialVisual.sphereLightOffset`. Kalau arahnya terbalik — misalnya
    karena sumbu y dikira positif ke atas, atau karena bibirnya dibalik untuk
    kawah di sisi gelap bola — hasilnya tetap terbaca sebagai kawah oleh mata,
    hanya terbaca sebagai kawah yang **menonjol keluar** alih-alih cekung.
    Tidak ada pemeriksaan gambar yang bisa menangkapnya: gambar acuannya ikut
    berubah, dan keduanya "terlihat seperti kawah".

    Karena itu yang diuji di sini adalah **bilangannya**, bukan gambarnya:
    setiap kawah harus punya arah bibir yang sama dengan `-light` yang
    dinormalkan, dan kekuatannya harus mengikuti rumus yang sama di kedua
    bahasa. Pemeriksaan ini merah kalau port menyimpang **atau** kalau model
    berubah tanpa port-nya ikut.
    """
    model = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                             "CelestialVisual.swift")).read()

    # Jangkar hilang = gagal bersih yang menyebut jangkarnya, bukan traceback.
    if "sphereLightOffset = (x: -0.32, y: -0.32)" not in model:
        results.append(Result(
            "bayangan kawah: jangkar model masih ada", False,
            "'sphereLightOffset = (x: -0.32, y: -0.32)' TIDAK ditemukan di "
            "CelestialVisual.swift — arah cahaya bola tidak lagi terbaca"))
        return

    relief = R.crater_relief(R.CRATERS)
    results.append(Result(
        "bayangan kawah: satu relief per kawah",
        len(relief) == len(R.CRATERS),
        f"{len(relief)} relief untuk {len(R.CRATERS)} kawah"))

    lx, ly = R.SPHERE_LIGHT_OFFSET
    length = (lx * lx + ly * ly) ** 0.5
    want_x, want_y = -lx / length, -ly / length
    wrong_direction = [i for i, r in enumerate(relief)
                       if abs(r[3] - want_x) > 1e-9 or abs(r[4] - want_y) > 1e-9]
    results.append(Result(
        "bayangan kawah: bibir terang menghadap cahaya di semua kawah",
        not wrong_direction,
        f"semua {len(relief)} kawah memakai arah "
        f"({want_x:.4f}, {want_y:.4f})" if not wrong_direction
        else f"kawah {wrong_direction} memakai arah lain: "
             f"{[(round(relief[i][3], 4), round(relief[i][4], 4)) for i in wrong_direction]}"))

    # Rumus kekuatannya harus sama, bukan hanya arahnya: kawah di sisi gelap
    # kehilangan kontras, dan kawah di tepi piringan kehilangan lebih banyak.
    mismatched = []
    for i, (dx, dy, size) in enumerate(R.CRATERS):
        distance = min(1.0, (dx * dx + dy * dy) ** 0.5)
        alignment = dx * (lx / length) + dy * (ly / length)
        want_strength = R.CRATER_RIM_STRENGTH * (0.6 + 0.4 * alignment) * (1 - 0.6 * distance)
        want_depth = R.CRATER_FLOOR_DEPTH * (1 - 0.5 * distance)
        if (abs(relief[i][5] - want_strength) > 1e-9
                or abs(relief[i][6] - want_depth) > 1e-9):
            mismatched.append(i)
    results.append(Result(
        "bayangan kawah: kekuatan bibir & kedalaman dasar mengikuti model",
        not mismatched,
        "rumus sama di kedua bahasa" if not mismatched
        else f"kawah {mismatched} menyimpang dari rumus "
             f"(kekuatan {R.CRATER_RIM_STRENGTH}, kedalaman {R.CRATER_FLOOR_DEPTH})"))


def check_night_mode_purity(results, size=200, ss=2):
    """Mode malam: hijau & biru harus **nol**, bukan "kecil".

    Ini janji produknya, dan satu-satunya cara mengetahuinya adalah mengukur
    kanal yang benar-benar sampai ke piksel. `NightVisualTests` menguji
    fungsinya; di sini yang diukur adalah gambar yang jadi.
    """
    for name in ("planet-jupiter-confirmed", "planet-saturn-confirmed",
                 "moon-crescent-jakarta", "star-betelgeuse", "sun",
                 "deepsky-nebula", "moon-crescent-uncertain"):
        case = next(c for c in R.build_cases() if c.name == name)
        canvas = R.render(case, size=size, night_mode=True, show_frame=False, ss=ss)
        path = os.path.join(R.OUT_DIR, f"__night-{name}.png")
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        width, height, rows = decode_png(path)
        worst = 0
        for y in range(height):
            row = rows[y]
            for x in range(width):
                worst = max(worst, row[x * 4 + 1], row[x * 4 + 2])
        results.append(Result(
            f"malam murni: {name}", worst == 0,
            f"kanal hijau/biru tertinggi = {worst} (harus 0)"))
        os.remove(path)


def check_planet_features_present(results, size=200, ss=2):
    """Ciri yang **seharusnya** ada juga harus benar-benar tergambar.

    Arah sebaliknya dari `check_features_disappear_when_uncertain`: tanpa
    pemeriksaan ini, view yang berhenti menggambar **semua** ciri akan lolos
    uji "ciri hilang saat ragu" dengan sempurna.
    """
    _, (w, h, rows) = render_case("planet-jupiter-confirmed", size=size, ss=ss)
    # Bintik Merah Besar: elips merah di kuadran bawah-tengah.
    spot = count_reddish(w, h, rows, int(w * 0.28), int(h * 0.52),
                         int(w * 0.62), int(h * 0.78))
    results.append(Result("Bintik Merah Besar tergambar", spot > 20,
                          f"{spot} piksel merah di kuadran bawah-tengah"))

    _, (w, h, rows) = render_case("planet-saturn-confirmed", size=size, ss=ss)
    background = background_of(w, h, rows)
    reach = max_radius_of_bright(w, h, rows, background)
    # Cincin harus **lebih lebar** dari bolanya; bola saja hanya ~0.53 R.
    results.append(Result("cincin Saturnus lebih lebar dari bola", reach > 0.8,
                          f"jangkauan {reach:.3f} R (bola saja 0.53 R)"))

    _, (w, h, rows) = render_case("planet-mars-confirmed", size=size, ss=ss)
    # Kutub es: piksel terang di dekat tepi atas & bawah piringan.
    top = brightest_pixel(rows, w, h, int(w * 0.4), 0, int(w * 0.6), int(h * 0.18))
    bottom = brightest_pixel(rows, w, h, int(w * 0.4), int(h * 0.82),
                             int(w * 0.6), h)
    results.append(Result(
        "kutub Mars di kedua sisi", top is not None and bottom is not None
        and sum(top[0]) > 500 and sum(bottom[0]) > 500,
        f"utara={top[0] if top else None}, selatan={bottom[0] if bottom else None}"))


def check_inner_planet_phase(results, size=200, ss=2):
    """Venus & Merkurius harus **berfase**, dan planet luar tidak boleh ikut.

    **Cacat yang dijaga di sini.** Sampai siklus ini `drawPlanet` menggambar
    setiap planet sebagai bola penuh yang menyala, dan itu benar untuk Mars
    sampai Saturnus — tapi salah untuk dua planet dalam. Dari Bumi, Venus
    berayun dari sabit ~1% ke cakram ~99%; bentuk sabit itu justru ciri paling
    khasnya, dan di langit nyata ia **tidak pernah** tampak bulat saat berada
    di dekat Matahari. Sebuah Venus yang tergambar penuh adalah gambar yang
    menyatakan hal yang tidak ada, persis yang dilarang aturan "kejujuran >
    rasa percaya diri": bukan karena mesinnya salah hitung, tapi karena
    gambarnya menyampaikan lebih dari yang dihitung.

    Empat pengukuran, semuanya dari piksel:

    1. **Sabit benar-benar sempit.** Luas piksel menyala pada f=0.22 harus
       mendekati 0.22 — bukan mendekati 1.0 seperti bola penuh.
    2. **Arah sisi terang benar.** Sabit Venus pada sudut `-pi/2` harus
       menghadap **bawah**; ini mengukur jalur yang sama dengan Bulan, jadi
       kesalahan koordinat layar di satu tempat akan tertangkap di sini juga.
    3. **Cembung tetap cembung.** Pada f=0.78 luasnya harus **di atas**
       setengah. Tanpa ini, "sabut tipis untuk semua fraksi" akan lolos.
    4. **Yang seharusnya bulat tetap bulat.** Dua kasus: Mars yang diberi
       angka fase (planet luar tidak pernah berfase dari Bumi — angkanya harus
       diabaikan), dan Venus tanpa arah fase (arah tak diketahui ≠ izin
       menebak arah). Keduanya harus tetap piringan penuh.
    """
    _, (w, h, rows) = render_case("planet-venus-crescent", size=size, ss=ss)
    background = background_of(w, h, rows)
    _, _, thin = lit_centroid(w, h, rows, background)
    results.append(Result(
        "sabit Venus benar-benar sempit", thin < 0.45,
        f"luas menyala {thin:.3f} dari piringan (f=0.22, bola penuh ≈ 1.0)"))

    lit, unlit = (tuple(round(c * 255) for c in R.PLANET_PALETTE["venus"][k])
                  for k in ("light", "dark"))
    dx, dy, _ = classify_centroid(w, h, rows, lit, unlit)
    measured = ("bawah" if dy > abs(dx) else
                "atas" if -dy > abs(dx) else
                "kanan" if dx > 0 else "kiri")
    results.append(Result(
        "sisi terang sabit Venus menghadap sudut yang diminta",
        measured == "bawah",
        f"terukur {measured} (dx={dx:+.3f}, dy={dy:+.3f}), seharusnya bawah"))

    _, (w, h, rows) = render_case("planet-venus-gibbous", size=size, ss=ss)
    background = background_of(w, h, rows)
    _, _, wide = lit_centroid(w, h, rows, background)
    results.append(Result(
        "cembung Venus lebih dari setengah", wide > 0.55,
        f"luas menyala {wide:.3f} dari piringan (f=0.78)"))

    # Planet **luar** tidak berfase dari Bumi: Mars nyaris bulat sepanjang
    # waktu, dan angka fase yang sampai ke view harus diabaikan, bukan dipakai.
    _, (w, h, rows) = render_case("planet-mars-with-a-phase-number", size=size, ss=ss)
    background = background_of(w, h, rows)
    _, _, outer = lit_centroid(w, h, rows, background)
    results.append(Result(
        "angka fase pada planet luar diabaikan", outer > 0.85,
        f"luas menyala {outer:.3f} — Mars tetap piringan penuh"))

    # Arah tak diketahui bukan izin menebak: piringan penuh, tanpa memihak sisi.
    _, (w, h, rows) = render_case("planet-venus-no-direction", size=size, ss=ss)
    background = background_of(w, h, rows)
    _, _, undirected = lit_centroid(w, h, rows, background)
    results.append(Result(
        "Venus tanpa arah fase tidak memihak sisi", undirected > 0.85,
        f"luas menyala {undirected:.3f} — piringan penuh, bukan sabit karangan"))


def check_unknown_phase_is_not_a_new_moon(results, size=200, ss=2):
    """Fase tak diketahui **bukan** bulan baru — diukur dari piksel.

    **Cacat yang dijaga di sini.** `drawMoon` menggambar piringan *tidak
    menyala* saat fasenya tidak diketahui, lalu berhenti. Hasilnya **identik
    piksel demi piksel** dengan bulan baru — diukur sebelum perbaikan: 0 dari
    40.000 piksel berbeda. Bulan baru adalah fakta tentang langit (f = 0, dan
    pengguna bisa memeriksanya dengan mata sendiri); "fase tidak dihitung"
    bukan fakta tentang apa pun. Menggambar yang kedua sebagai yang pertama
    berarti gambar itu **menyatakan** bulan baru setiap kali efemeris gagal
    atau arahnya tidak tersedia — dan kartu jam tidak punya teks lain untuk
    membantahnya.

    Dua pengukuran, keduanya dari piksel:

    1. **Berbeda dari bulan baru.** Tanpa ini, "piringan polos" yang sama
       dengan piringan gelap akan lolos sempurna — dan itu justru cacatnya.
    2. **Dan tidak menyamar jadi purnama.** Sisi lain: piringan yang terlalu
       terang akan terbaca sebagai bulan penuh, klaim yang sama-sama salah.
       Warnanya harus di **antara** keduanya, dan diukur sebagai jarak — bukan
       tanda, karena selisih 0.01 lolos pertidaksamaan sambil tetap identik
       di layar.
    """
    _, new_moon = render_case("moon-new", size=size, ss=ss)
    _, unknown = render_case("moon-unknown-phase", size=size, ss=ss)
    _, full = render_case("moon-full", size=size, ss=ss)

    def pixel_diff(a, b):
        w, h, rows_a = a
        _, _, rows_b = b
        count = 0
        for y in range(h):
            ra, rb = rows_a[y], rows_b[y]
            for x in range(w):
                if ra[x * 4:x * 4 + 3] != rb[x * 4:x * 4 + 3]:
                    count += 1
        return count

    vs_new = pixel_diff(unknown, new_moon)
    results.append(Result(
        "fase tak diketahui bukan bulan baru", vs_new > 0,
        f"{vs_new} piksel berbeda dari moon-new (kalau 0, keduanya gambar "
        f"yang sama: klaim bulan baru saat fase tidak dihitung)"))

    vs_full = pixel_diff(unknown, full)
    results.append(Result(
        "fase tak diketahui bukan purnama", vs_full > 0,
        f"{vs_full} piksel berbeda dari moon-full"))

    # Jarak yang berarti, bukan sekadar "tidak sama": kanal merah piringan
    # tak-diketahui harus terletak di antara gelap dan terang, dengan margin
    # yang terlihat.
    w, h, rows = unknown
    cx, cy = w // 2, h // 2
    unknown_red = rows[cy][cx * 4]
    _, _, rows_new = new_moon
    _, _, rows_full = full
    new_red = rows_new[cy][cx * 4]
    full_red = rows_full[cy][cx * 4]
    margin = 25  # dari 255
    results.append(Result(
        "piringan tak-diketahui di antara gelap & terang",
        unknown_red > new_red + margin and unknown_red < full_red - margin,
        f"kanal merah {unknown_red} (bulan baru {new_red}, purnama {full_red})"))


def check_saturn_ring_bands_render(results, size=200, ss=2):
    """Cincin Saturnus harus tergambar sebagai **pita**, dan di kedua paruh.

    **Cacat yang ditutup pemeriksaan ini.** Sampai siklus ini cincin digambar
    sebagai satu elips pekat (opasitas 0.45 belakang, 0.8 depan) dengan
    sebuah elips hitam 0.28 sebagai "pembelah Cassini". Pemeriksaan lama
    menjaga **angkanya** (`RING_BACK_OPACITY == 0.45`) dan itu hijau — jadi
    tiga hal salah sekaligus tidak terlihat:

      - tidak ada pita D/C/B/A sama sekali;
      - celahnya diletakkan 0.34 x radius bola dari tepi luar (≈0.75 R
        cincin), sedangkan pembelah Cassini nyata di 0.886 R — jadi ia
        memotong pita A, bukan memisahkan B dari A;
      - celahnya digambar hanya di dalam klip paruh bawah, jadi paruh
        belakang tidak punya celah sama sekali.

    **Cara mengukurnya, dan kenapa bukan cara yang lebih sederhana.** Cincin
    adalah elips, jadi memindai **baris** atau **kolom** menembusnya pada
    lintasan diagonal: nilainya berubah karena elipsnya menyempit, bukan
    karena pitanya berganti. Versi pertama pemeriksaan ini melakukan itu dan
    melaporkan celahnya di 0.57 R (belakang) dan 0.94 R (depan) — dua angka
    yang keduanya artefak lintasan, bukan celahnya. Yang benar adalah
    mencuplik **sepanjang elips cincin itu sendiri** pada radius tertentu,
    lalu mengambil nilai tengahnya (median, bukan maksimum — maksimum
    tertarik oleh tepi yang di-antialias).

    Cuplikan di dalam proyeksi bola dibuang: di sana yang terlihat adalah
    permukaan planet, bukan cincin. Ambangnya **relatif** terhadap pita
    terang di paruh yang sama, bukan angka mutlak, karena opasitas cincin
    bergantung mode malam.
    """
    _, (w, h, rows) = render_case("planet-saturn-confirmed", size=size, ss=ss)
    radius = min(w, h) / 2.0
    cx, cy = w / 2.0, h / 2.0
    ring = R.saturn_ring()
    axial = ring["half_height"] / ring["half_width"]
    body = R.saturn_body_radius(ring)
    bands = R.saturn_ring_bands()

    def ring_value(r, half):
        """Median kanal merah sepanjang elips cincin pada radius `r`."""
        samples = []
        for degree in range(2, 89, 2):
            angle = math.radians(degree)
            xr = r * math.cos(angle)
            yr = r * axial * math.sin(angle)
            # Lewati bagian yang terhalang bola: di sana bukan cincin.
            if abs(xr) <= body + 0.02:
                continue
            x = int(round(cx + xr * radius))
            y = int(round(cy + half * yr * radius))
            if 0 <= x < w and 0 <= y < h:
                samples.append(rows[y][x * 4])
        if len(samples) < 4:
            return None
        samples.sort()
        return samples[len(samples) // 2]

    def band_radius(index):
        band = bands[index]
        return (band[0] + band[1]) / 2.0

    for label, half in (("belakang", -1.0), ("depan", 1.0)):
        gap = ring_value(band_radius(3), half)      # celah Cassini
        bright_b = ring_value(band_radius(2), half)  # pita B
        outer_a = ring_value(band_radius(4), half)   # pita A
        if gap is None or bright_b is None or outer_a is None:
            results.append(Result(f"cincin: celah Cassini paruh {label}", False,
                                  "tidak cukup piksel cincin di luar bola"))
            continue
        # Celah harus **lebih gelap dari pita di kedua sisinya**. Itu yang
        # membuatnya terbaca sebagai pemisah, bukan sebagai tepi cincin.
        results.append(Result(
            f"cincin: celah Cassini paruh {label}",
            gap < bright_b - 12 and gap < outer_a - 12,
            f"celah {gap}, pita B {bright_b}, pita A {outer_a}"))

    # Paruh belakang lebih redup: diukur pada pita B, pita terpekat, supaya
    # yang dibandingkan cincin dengan cincin (bukan cincin dengan latar).
    back_b = ring_value(band_radius(2), -1.0)
    front_b = ring_value(band_radius(2), 1.0)
    if back_b is not None and front_b is not None:
        results.append(Result(
            "cincin: paruh belakang lebih redup dari depan",
            back_b < front_b,
            f"belakang {back_b} < depan {front_b}"))
    else:
        results.append(Result("cincin: paruh belakang lebih redup dari depan",
                              False, "pita B tidak terukur di salah satu paruh"))


def check_candidate_marker_stays_inside_its_badge(results, size=200, ss=2):
    """Glif tanda tanya harus berada **di dalam** lencananya.

    **Cacat yang ditutup pemeriksaan ini.** Port menghitung radius glif dari
    **radius frame**, sedangkan view menghitungnya dari **radius lencana**:

        view :  let r = CGFloat(marker.glyphRadius) * radius   // radius = frame
        port :  r = marker["glyph_fraction"] * radius          // radius = frame

    `marker.glyphRadius` adalah `radius * glyphFraction` — radius **lencana**
    dikali 0.52. Jadi bentuk yang benar adalah `0.52 · badgeRadius`, dan port
    yang menulis `0.52 · frameRadius` membuat glifnya 3.1x terlalu besar
    (0.52 R lawan 0.166 R). Akibatnya glif menjulur keluar lencana di
    kiri-atas dan **terpotong tepi frame** — lencana "?" yang justru
    satu-satunya penanda "engine ragu" di layar, tergambar sebagai busur yang
    berhenti mendadak.

    **Kenapa tak satu pun gerbang lama melihatnya.** Yang salah adalah
    **konvensi satuan**, dan tidak ada yang membacanya:

    | Gerbang | Kenapa hijau |
    |---|---|
    | `check_port_matches_swift_constants` | tidak ada yang membandingkan `glyph_fraction`; konstanta itu memang sama di kedua sisi (0.52) |
    | uji model `VisualFrame` | menguji `glyphRadius` di model — dan modelnya benar |
    | Aturan 24 / lint UI | tidak melihat aritmetika gambar |
    | `check_features_disappear_when_uncertain` | baru saja **mengecualikan** kotak lencana, jadi luberan glif justru disaring keluar dari pengukuran itu |

    Dua pengukuran, keduanya dari piksel **gambar "ragu" saja**:

    1. **Tidak ada piksel peringatan di luar lencana.** Setiap piksel yang
       berwarna dekat warna peringatan — garis tepi lencana, glif, dan
       tetesnya — harus berada di dalam kotak lencana. Glif yang 3.1x terlalu
       besar meninggalkan garis-garis jauh di luar kotak itu.
    2. **Glif ada.** Tanpa ini, menghapus glifnya seluruhnya akan lolos
       pengukuran pertama dengan sempurna.

    **Kenapa tidak membandingkan "terkunci" dengan "ragu" seperti pemeriksaan
    ciri di atas.** Versi pertama melakukan itu dan gagal dengan 12.470 piksel
    "di luar lencana" — yang ternyata **cincin Saturnus**, bukan glif. Cincin
    memang menjulur ke seluruh lebar frame (sampai 1.003 R) dan memang harus
    hilang saat ragu, jadi ia sah berada di luar kotak lencana. Membandingkan
    dua gambar mengukur *segala* yang berubah; yang ingin dijaga di sini hanya
    **glif terhadap lencananya**, dan itu bisa diukur langsung pada satu
    gambar. Pemeriksaan yang mengukur lebih banyak daripada yang diklaimnya
    akan gagal karena alasan yang bukan cacatnya.
    """
    fx0, fy0, fx1, fy1 = R.candidate_marker_footprint()
    # Margin untuk garis tepi + anti-aliasing, dalam satuan radius.
    margin = 4.0 / (size / 2.0)
    ex0, ey0, ex1, ey1 = (fx0 - margin, fy0 - margin, fx1 + margin, fy1 + margin)

    warning = R._warning_color(False)
    for planet in ("saturn", "jupiter", "mars"):
        _, uncertain = render_case(f"planet-{planet}-uncertain", size=size, ss=ss)
        w, h, rows = uncertain
        radius = min(w, h) / 2.0
        cx, cy = w / 2.0, h / 2.0
        outside = 0
        far = None
        for y in range(h):
            uy = (y + 0.5 - cy) / radius
            row = rows[y]
            for x in range(w):
                px = row[x * 4:x * 4 + 3]
                # Warna peringatan adalah oranye pekat; toleransi lebar supaya
                # tepi anti-aliasing tidak dihitung sebagai "keluar".
                if not all(abs(px[k] - warning[k] * 255) < 40 for k in range(3)):
                    continue
                ux = (x + 0.5 - cx) / radius
                if not (ex0 <= ux <= ex1 and ey0 <= uy <= ey1):
                    outside += 1
                    if far is None or ux < far[0]:
                        far = (ux, uy)
        results.append(Result(
            f"lencana {planet}: glif tidak keluar lencana", outside == 0,
            f"{outside} piksel peringatan di luar kotak lencana "
            f"(x {ex0:.3f}..{ex1:.3f}, y {ey0:.3f}..{ey1:.3f})"
            + (f", terjauh ({far[0]:.3f}, {far[1]:.3f})" if far else "")))

    # Arah sebaliknya: glifnya harus benar-benar ada di dalam lencana.
    _, uncertain = render_case("planet-saturn-uncertain", size=size, ss=ss)
    w, h, rows = uncertain
    radius = min(w, h) / 2.0
    cx, cy = w / 2.0, h / 2.0
    glyph_pixels = 0
    for y in range(h):
        uy = (y + 0.5 - cy) / radius
        row = rows[y]
        for x in range(w):
            ux = (x + 0.5 - cx) / radius
            if not (ex0 <= ux <= ex1 and ey0 <= uy <= ey1):
                continue
            px = row[x * 4:x * 4 + 3]
            if all(abs(px[k] - warning[k] * 255) < 40 for k in range(3)):
                glyph_pixels += 1
    # Ambang lebar: garis glif dengan lebar `badgeRadius * 0.28` pada 200 px
    # adalah ~9 px. Yang dijaga adalah **keberadaannya**, bukan ketebalannya.
    results.append(Result(
        "lencana: glif tanda tanya tergambar", glyph_pixels > 40,
        f"{glyph_pixels} piksel glif di dalam lencana"))


def check_jupiter_bands_reach_the_limb(results, size=200, ss=2):
    """Pita Jupiter harus menjangkau **sampai tepi bola** — diukur dari piksel.

    **Cacat yang ditutup pemeriksaan ini.** View memakai
    `cos((t - 0.5) * .pi * 0.92)` sebagai separuh lebar pita sambil
    berkomentar "pita mengikuti keliling bola: makin dekat kutub, makin
    pendek". Kosinus itu bukan keliling bola: di ekuator keduanya sama
    (1.0), dan di pita teratas tepi pita berhenti 19% radius di dalam
    piringan. Di kartu jam 38 pt itu 3.6 pt — bola berwarna polos di kedua
    kutub, dengan pita mengambang di tengahnya.

    **Kenapa harus dari piksel.** Uji model (`testJupiterBandsReachTheLimb`)
    mengunci rumusnya, dan itu benar. Tapi yang dikirim ke layar adalah
    gambar, dan gambar itu bisa salah walaupun rumusnya benar — misalnya
    kalau view lupa memakai model, atau memakai separuh lebar sebagai lebar
    penuh. Yang membuktikan pita benar-benar sampai tepi adalah mengukur
    baris pita itu sendiri.

    Ambangnya 0.02 R: pita berhenti karena **anti-aliasing** boleh sedikit di
    dalam tepi, tapi cacat yang nyata (0.19 R) jauh di atas itu.
    """
    _, confirmed = render_case("planet-jupiter-confirmed", size=size, ss=ss)
    # Bola tanpa pita, dari kasus "ragu" — gambar bola yang sama persis.
    _, sphere_only = render_case("planet-jupiter-uncertain", size=size, ss=ss)
    w, h, _ = confirmed
    radius = min(w, h) / 2.0
    for index, (band_y, _, _) in enumerate(R.jupiter_bands()):
        # Baris pusat pita, di koordinat piksel (y ke bawah, seperti `Canvas`).
        py = h / 2.0 + band_y * radius
        reach, row = band_left_reach(confirmed, sphere_only, py)
        # **Tepi bola dihitung di sini, bukan dibaca dari port.**
        #
        # Versi pertama pemeriksaan ini mengambil `half_width` dari
        # `R.jupiter_bands()` — yaitu fungsi yang **menggambar** pita itu.
        # Akibatnya pemeriksaan selalu hijau: kalau port kembali memakai
        # kosinus, gambar mengecil dan angka pembandingnya ikut mengecil,
        # sehingga keduanya sepakat satu sama lain sementara tepi bola yang
        # sesungguhnya tidak pernah disebut. Persis kelas cacat yang sudah
        # pernah nyata di berkas ini (PNG yang penulis dan pembacanya
        # sama-sama salah). Yang tidak boleh jadi parameter bebas adalah
        # **proyeksi bola** — ia satu-satunya nilai yang benar, dan ia
        # dihitung dari rumusnya langsung.
        sphere = math.sqrt(max(0.0, 1 - band_y * band_y))
        results.append(Result(
            f"pita Jupiter {index} menjangkau tepi bola",
            sphere - reach <= 0.02,
            f"jangkauan {reach:.3f} R, bola {sphere:.3f} R, "
            f"selisih {(sphere - reach) * 100:.1f}% R (baris {row})"))


def check_star_colour_order(results, size=200, ss=2):
    """Betelgeuse harus lebih merah dari Rigel — diukur dari piksel.

    Tabel B−V diuji di Linux, dan `starRGB` juga. Yang belum: apakah warna itu
    benar-benar jadi piksel, dan apakah urutannya masih terbaca setelah
    digambar di atas latar gelap.
    """
    for star, warmer_than in (("betelgeuse", "rigel"), ("betelgeuse", "sirius")):
        _, (w, h, rows) = render_case(f"star-{star}", size=size, ss=ss)
        a = brightest_pixel(rows, w, h, 0, 0, w, h)
        _, (w2, h2, rows2) = render_case(f"star-{warmer_than}", size=size, ss=ss)
        b = brightest_pixel(rows2, w2, h2, 0, 0, w2, h2)
        # "Lebih merah" = selisih R−B lebih besar.
        a_warmth = a[0][0] - a[0][2]
        b_warmth = b[0][0] - b[0][2]
        results.append(Result(
            f"{star} lebih merah dari {warmer_than}", a_warmth > b_warmth,
            f"R−B {star}={a_warmth}, {warmer_than}={b_warmth}"))


def check_star_colour_not_a_claim_when_uncertain(results, size=200, ss=2):
    """Warna bintang harus hilang saat engine ragu — diukur dari piksel.

    Warna spektral adalah **ciri pengenal**: biru pada Rigel dan merah pada
    Betelgeuse adalah penanda yang sama meyakinkannya dengan cincin Saturnus.
    Aturan "ciri hilang saat ragu" sudah berlaku untuk pita planet dan bentuk
    objek langit dalam; bintang sempat tertinggal, dan kesalahannya tidak
    terlihat — badge "Ragu" bisa berada persis di sebelah titik yang masih
    berwarna merah khas Betelgeuse, dan mata membaca gambar lebih dulu.

    Diukur dari piksel, bukan dari fungsi: yang diperiksa adalah gambar yang
    benar-benar jadi. Bintang yang ragu harus **identik** dengan bintang lain
    yang ragu — kalau warnanya masih ikut, keduanya akan berbeda.
    """
    _, (w1, _, rows_betelgeuse) = render_case("star-betelgeuse-uncertain",
                                              size=size, ss=ss)
    _, (w2, _, rows_rigel) = render_case("star-rigel-uncertain",
                                         size=size, ss=ss)
    diff = sum(1 for y in range(len(rows_betelgeuse))
               for x in range(w1)
               if rows_betelgeuse[y][x * 4:x * 4 + 3]
               != rows_rigel[y][x * 4:x * 4 + 3])
    results.append(Result(
        "dua bintang berbeda tampil sama saat ragu", diff == 0,
        f"{diff} piksel berbeda antara Betelgeuse & Rigel saat ragu"))

    # Dan arah sebaliknya: saat yakin, keduanya memang berbeda. Tanpa ini,
    # view yang membuang warna bintang **selalu** akan lolos uji di atas.
    _, (w3, _, rows_betelgeuse_ok) = render_case("star-betelgeuse", size=size, ss=ss)
    _, (w4, _, rows_rigel_ok) = render_case("star-rigel", size=size, ss=ss)
    diff_ok = sum(1 for y in range(len(rows_betelgeuse_ok))
                  for x in range(w3)
                  if rows_betelgeuse_ok[y][x * 4:x * 4 + 3]
                  != rows_rigel_ok[y][x * 4:x * 4 + 3])
    results.append(Result(
        "dua bintang berbeda tetap berbeda saat yakin", diff_ok > 0,
        f"{diff_ok} piksel berbeda antara Betelgeuse & Rigel saat yakin"))

    # Warna saat ragu harus warna "tidak mengklaim" yang sama dengan bintang
    # tak dikenal di katalog -- bukan warna spektral yang kebetulan netral.
    #
    # Dibandingkan **di sekitar inti saja** (masker radial), bukan seluruh
    # frame: bintang yang ragu juga membawa lencana tanda tanya di sudut,
    # sedangkan bintang tak dikenal -- yang sudah lama dianggap tidak
    # mengklaim apa pun -- tidak. Lencana itu memang perbedaan yang
    # disengaja, dan membandingkan seluruh frame akan mengukur lencananya,
    # bukan warnanya. Radiusnya dipilih di luar glow inti tapi di dalam
    # jangkauan lencana.
    _, (w5, h5, rows_unknown) = render_case("star-unknown-id", size=size, ss=ss)
    _, (w6, h6, rows_rigel2) = render_case("star-rigel-uncertain", size=size, ss=ss)
    cx5, cy5 = w5 / 2.0, h5 / 2.0
    mask_radius = 0.25 * w5
    diff_unknown = 0
    for y in range(h5):
        for x in range(w5):
            if math.hypot(x + 0.5 - cx5, y + 0.5 - cy5) > mask_radius:
                continue
            if rows_unknown[y][x * 4:x * 4 + 3] != rows_rigel2[y][x * 4:x * 4 + 3]:
                diff_unknown += 1
    results.append(Result(
        "warna ragu = warna bintang tak dikenal", diff_unknown == 0,
        f"{diff_unknown} piksel berbeda dari bintang tak dikenal (inti saja)"))


def check_mars_caps_touch_the_limb(results, size=400, ss=2):
    """Kutub Mars harus **menyentuh tepi bola**, bukan mengambang di dalamnya.

    **Cacat yang ditutup pemeriksaan ini.** Kutub digambar sebagai elips
    dengan lebar tetap 0.55 R, tepinya ditempelkan di tepi bola. Karena lebar
    itu lebih sempit dari bola pada baris mana pun di sekitar kutub, yang
    tergambar bukan kap es di permukaan bola melainkan elips yang ditempel
    agak ke dalam: selalu ada rim merah di atas dan di sisi kiri-kanan
    kutubnya. Diukur pada render 400 px: pada baris terlebar kutub, tepi bola
    0.675 R sementara tepi kutub 0.550 R — selisih 0.125 R, 25 px.

    **Kenapa harus dari piksel.** Uji model mengunci rumus lebarnya, dan itu
    benar. Tapi yang dikirim ke layar adalah gambar: kalau view lupa
    mengalikan lebar model dengan radius, atau memakai `topY` lama, modelnya
    tetap benar sementara gambarnya tidak. Yang membuktikan kutub benar-benar
    menempel adalah mengukur baris kutubnya sendiri.

    **Dua arah sekaligus**, karena keduanya bisa salah sendiri-sendiri:
    kutub yang terlalu sempit mengambang di dalam (rim merah), dan kutub yang
    terlalu lebar meluber ke latar di dekat kutub. Yang pertama diukur di
    baris terlebar; yang kedua di baris dekat ujung.
    """
    _, (w, h, rows) = render_case("planet-mars-confirmed", size=size, ss=ss)
    background = background_of(w, h, rows)
    cx = cy = w / 2.0
    radius = min(w, h) / 2.0

    def pixel(x, y):
        return rows[y][x * 4:x * 4 + 3]

    def is_cap(c):
        # Kutub 0.97/0.95/0.93 × 255 = 247/242/237; bola Mars jauh lebih
        # merah (0.88/0.42/0.26). Ambang di antara keduanya, bukan di tepi.
        return c[0] > 215 and c[1] > 200 and c[2] > 190

    def half_width_of(predicate, y):
        n = 0
        for x in range(int(cx), w):
            c = pixel(x, y)
            if c == background or not predicate(c):
                break
            n += 1
        return n

    caps = R.polar_caps()
    # Baris pusat kutub: di sinilah tepi kutub harus bertemu tepi bola.
    y_center = int(round(cy + caps["north_center"] * radius))
    disc = half_width_of(lambda c: True, y_center)
    cap = half_width_of(is_cap, y_center)
    results.append(Result(
        "kutub Mars menyentuh tepi bola di baris pusatnya",
        disc - cap <= 0.02 * radius,
        f"bola {disc / radius:.3f} R, kutub {cap / radius:.3f} R, "
        f"rim {disc - cap} px ({(disc - cap) / radius * 100:.1f}% R)"))

    # Arah kedua: dekat ujung kutub, tidak boleh ada piksel kutub di luar bola.
    outside = 0
    for y in range(h):
        for x in range(w):
            if not is_cap(pixel(x, y)):
                continue
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) > radius + 0.5:
                outside += 1
    results.append(Result(
        "kutub Mars tidak meluber keluar bola",
        outside == 0,
        f"{outside} piksel kutub di luar piringan"))

    # Ketiga: kutubnya benar-benar ada **dan** hilang saat ragu — dua arah
    # sekaligus. Tanpa yang pertama, view yang berhenti menggambar kutub lolos
    # dua pemeriksaan di atas dengan sempurna; tanpa yang kedua, ciri pengenal
    # tergambar pada kandidat yang belum dipastikan.
    _, (w2, h2, rows2) = render_case("planet-mars-uncertain", size=size, ss=ss)
    cap_pixels = sum(1 for y in range(h) for x in range(w)
                     if is_cap(pixel(x, y)))
    results.append(Result(
        "kutub Mars benar-benar tergambar",
        cap_pixels > 100,
        f"{cap_pixels} piksel kutub (cukup > 100)"))
    uncertain_caps = sum(1 for y in range(h2) for x in range(w2)
                         if is_cap(rows2[y][x * 4:x * 4 + 3]))
    results.append(Result(
        "kutub Mars hilang saat engine ragu",
        uncertain_caps == 0,
        f"{uncertain_caps} piksel kutub pada kandidat (harus 0)"))


def check_sun_edge_is_soft(results, size=256, ss=2):
    """Tepi piringan Matahari harus **halus**, bukan tepi keras dua piringan.

    **Cacat yang ditutup pemeriksaan ini.** Matahari digambar sebagai dua
    piringan bertumpuk: fotosfer pekat selebar 0.72 R, lalu corona yang mulai
    di 0.6 R dengan kelegapan 0.42. Di tepi fotosfer kelegapannya melompat
    1.0 -> 0.42 dalam satu piksel — terukur 175 dari 255 langkah antar-piksel,
    dan yang terlihat bukan tepi Matahari melainkan dua benda bertumpuk.

    **Kenapa diukur di sini, bukan lewat uji model.** Uji model
    (`testSunProfileOpacityNeverIncreases`) menjaga profilnya; yang tidak
    dijaganya adalah apakah view benar-benar **memakai** profil itu. View yang
    kembali menggambar dua piringan akan lolos semua uji model. Hanya gambar
    yang bisa membedakannya.

    Diukur **sepanjang radius**, bukan rata-rata sekeliling: rata-rata
    sekeliling justru menyembunyikan lompatan karena ia menghaluskan cincin
    pada radius itu.
    """
    _, (w, h, rows) = render_case("sun", size=size, ss=ss)

    def pixel(x, y):
        # Dijepit ke dalam gambar: pemanggil memakai pecahan radius yang bisa
        # sedikit melewati tepi, dan pembacaan di luar gambar bukan temuan.
        x = min(max(x, 0), w - 1)
        y = min(max(y, 0), h - 1)
        i = x * 4
        return (rows[y][i], rows[y][i + 1], rows[y][i + 2])

    cx = (w - 1) / 2
    cy = (h - 1) / 2
    radius = w / 2
    # Sepanjang beberapa jari-jari, ambil langkah terbesar antar piksel
    # bersebelahan. Satu jari saja bisa kebetulan melewati arah yang mulus.
    worst = 0
    worst_r = 0.0
    for k in range(24):
        angle = 2 * math.pi * k / 24
        dx, dy = math.cos(angle), math.sin(angle)
        previous = None
        for i in range(int(radius * 1.06) + 1):
            x = int(round(cx + i * dx))
            y = int(round(cy + i * dy))
            if not (0 <= x < w and 0 <= y < h):
                break
            current = pixel(x, y)
            if previous is not None:
                step = max(abs(current[c] - previous[c]) for c in range(3))
                if step > worst:
                    worst, worst_r = step, i / radius
            previous = current

    # Ambang 30/255. Profil baru mengukur 12; bentuk lama 175. Batasnya
    # diletakkan jauh dari keduanya supaya ia menangkap "dua piringan" tanpa
    # ikut merah hanya karena pergeseran stop yang wajar.
    results.append(Result(
        "tepi Matahari halus, bukan tepi keras dua piringan",
        worst < 30,
        f"langkah terbesar {worst}/255 pada r={worst_r:.2f}R (ambang 30, bentuk lama 175)"))

    # Arah kedua: inti harus benar-benar terang dan tepi benar-benar habis.
    # Tanpa ini, "halus" bisa dipenuhi oleh piringan gelap rata.
    center = pixel(int(cx), int(cy))
    results.append(Result(
        "inti Matahari terang",
        min(center) > 200,
        f"rgb inti = {center} (semua kanal harus > 200)"))
    edge = pixel(int(cx + radius * 1.02), int(cy))
    results.append(Result(
        "tepi Matahari habis di luar piringan",
        max(edge) < 40,
        f"rgb di 1.02 R = {edge} (harus mendekati latar)"))
    # Arah ketiga: piringan harus membentang sampai 1.0 R, bukan berhenti di
    # 0.72 R. Kalau berhenti, "halus" tercapai dengan mengorbankan ukuran.
    at_090 = pixel(int(cx + radius * 0.90), int(cy))
    results.append(Result(
        "piringan Matahari masih menyala di 0.90 R",
        min(at_090) > 20,
        f"rgb di 0.90 R = {at_090} (harus jelas di atas latar 10,10,15)"))


def check_deep_sky_morphologies_render_distinct(results, size=200, ss=2):
    """Keempat morfologi objek langit dalam harus tergambar sebagai bentuk yang
    berbeda — diukur dari piksel.

    **Cacat yang ditutup pemeriksaan ini.** `testDeepSkyMorphologyDistinguishes
    ThreeTypes` di Linux mengunci bahwa model mengembalikan morfologi berbeda
    untuk berbagai id — dan itu benar. Tapi yang dikirim ke layar adalah
    gambar, dan gambarnya bisa salah walaupun modelnya benar: kalau view suatu
    saat memetakan seluruh `DeepSkyKind` ke satu bentuk (misal kabut bulat
    tanpa pemusatan), uji model tetap hijau sementara keempat objek tampak
    sebagai gumpalan yang sama di layar. Persis kelas cacat yang berkas ini
    ada untuk mencegah: gerbang yang mengukur hal yang bukan yang diklaimnya.

    Diukur dari piksel penuh. Kasus-kasus ini **terkunci** (tanpa lencana tanda
    tanya), jadi seluruh frame adil untuk dibandingkan. Setiap pasang morfologi
    harus berbeda paling tidak satu piksel; kalau view menyoroti semuanya ke
    satu bentuk, seluruh pasangan bertepatan dan pemeriksaan ini merah.

    **Dua arah sekaligus.** Tanpa arah sebaliknya (setiap morfologi terkunci
    berbeda dari kabut netral), view yang menyoroti *semua* ke kabut netral
    akan lolos pemeriksaan pasangan di atas — keempatnya sama-sama netral,
    jadi pasangan mana pun juga bertepatan.
    """
    names = [c.name for c in R.build_cases()
             if c.name.startswith("deepsky-")
             and c.name not in ("deepsky-uncertain", "deepsky-unknown-id")]
    rendered = {name: render_case(name, size=size, ss=ss) for name in names}

    # Setiap pasang berbeda.
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            _, (w1, h1, rows_a) = rendered[names[i]]
            _, (_, _, rows_b) = rendered[names[j]]
            diff = sum(1 for y in range(h1)
                       for x in range(w1)
                       if rows_a[y][x * 4:x * 4 + 3] != rows_b[y][x * 4:x * 4 + 3])
            results.append(Result(
                f"morfologi berbeda: {names[i]} vs {names[j]}", diff > 0,
                f"{diff} piksel berbeda (kalau 0, kedua bentuk sama di layar)"))

    # Setiap morfologi terkunci berbeda dari kabut netral.
    _, (w0, h0, rows_neutral) = render_case("deepsky-unknown-id",
                                            size=size, ss=ss)
    for name in names:
        _, (_, _, rows_m) = rendered[name]
        diff = sum(1 for y in range(h0)
                   for x in range(w0)
                   if rows_m[y][x * 4:x * 4 + 3] != rows_neutral[y][x * 4:x * 4 + 3])
        results.append(Result(
            f"{name} berbeda dari kabut netral", diff > 0,
            f"{diff} piksel berbeda dari kabut netral"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="keluar != 0 bila ada pemeriksaan yang gagal")
    parser.add_argument("--size", type=int, default=200)
    parser.add_argument("--ss", type=int, default=2)
    args = parser.parse_args()

    os.makedirs(R.OUT_DIR, exist_ok=True)
    results = []
    check_moon_phase_fraction(results, args.size, args.ss)
    check_crescent_direction(results, args.size, args.ss)
    check_features_disappear_when_uncertain(results, args.size, args.ss)
    check_planet_features_present(results, args.size, args.ss)
    check_inner_planet_phase(results, args.size, args.ss)
    check_saturn_ring_bands_render(results, args.size, args.ss)
    check_moon_phase_survives_uncertainty(results, args.size, args.ss)
    check_unknown_phase_is_not_a_new_moon(results, args.size, args.ss)
    check_feature_arrays_match_the_view(results)
    check_crater_drawing_constants(results)
    check_sun_profile_matches_the_model(results)
    check_crater_relief_matches_the_model(results)
    check_candidate_marker_stays_inside_its_badge(results, args.size, args.ss)
    check_jupiter_bands_reach_the_limb(results, args.size, args.ss)
    check_mars_caps_touch_the_limb(results)
    check_sun_edge_is_soft(results)
    check_png_is_well_formed(results)
    check_png_roundtrip(results)
    check_port_matches_swift_constants(results)
    check_night_mode_purity(results, args.size, args.ss)
    check_star_colour_order(results, args.size, args.ss)
    check_star_colour_not_a_claim_when_uncertain(results, args.size, args.ss)
    check_deep_sky_morphologies_render_distinct(results, args.size, args.ss)
    check_deep_sky_layouts_match_the_model(results)

    width = max(len(r.name) for r in results)
    failures = [r for r in results if not r.ok]
    for r in results:
        mark = "OK  " if r.ok else "GAGAL"
        print(f"{mark} {r.name.ljust(width)}  {r.detail}")
    print(f"\n{len(results)} pemeriksaan, {len(failures)} gagal")
    if args.check and failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
