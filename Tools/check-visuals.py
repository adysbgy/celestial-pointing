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
        ("Bintik Merah Besar x", R.SPOT_RECT[0], -0.36,
         "center.x - radius * 0.36", view),
        ("Bintik Merah Besar y", R.SPOT_RECT[1], 0.18,
         "center.y + radius * 0.18", view),
        ("Bintik Merah Besar lebar", R.SPOT_RECT[2], 0.52,
         "width: radius * 0.52", view),
        ("Bintik Merah Besar tinggi", R.SPOT_RECT[3], 0.26,
         "height: radius * 0.26", view),
        ("opasitas cincin belakang", R.RING_BACK_OPACITY, 0.45,
         "ringColor.opacity(0.45)", view),
        ("opasitas cincin depan", R.RING_FRONT_OPACITY, 0.8,
         "ringColor.opacity(0.8)", view),
        ("opasitas celah Cassini", R.RING_GAP_OPACITY, 0.28,
         "Color.black.opacity(0.28)", view),
        ("opasitas kutub Mars", R.POLAR_CAP_OPACITY, 0.85,
         "capColor.opacity(0.85)", view),
        ("opasitas kawah", R.CRATER_OPACITY, 0.18,
         "Color.black.opacity(0.18)", view),
        ("kawah pertama Merkurius", tuple(R.CRATERS[0]), (-0.30, -0.22, 0.20),
         "(-0.30, -0.22, 0.20)", view),
        ("maria pertama Bulan", tuple(R.MARIA[0]), (-0.28, -0.30, 0.26),
         "(-0.28, -0.30, 0.26)", view),
        ("opasitas spike bintang", R.SPIKE_OPACITY, 0.45,
         "color.opacity(0.45)", view),
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
    ]
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
    check_moon_phase_survives_uncertainty(results, args.size, args.ss)
    check_candidate_marker_stays_inside_its_badge(results, args.size, args.ss)
    check_jupiter_bands_reach_the_limb(results, args.size, args.ss)
    check_png_is_well_formed(results)
    check_png_roundtrip(results)
    check_port_matches_swift_constants(results)
    check_night_mode_purity(results, args.size, args.ss)
    check_star_colour_order(results, args.size, args.ss)
    check_star_colour_not_a_claim_when_uncertain(results, args.size, args.ss)

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
