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


def check_features_disappear_when_uncertain(results, size=200, ss=2):
    """Ciri pengenal wajib hilang saat engine ragu — diukur dari piksel.

    Aturan 18 menjaga **nilai bawaan**-nya, dan `palette.feature` diuji di
    Linux. Yang tidak pernah diperiksa: apakah view benar-benar **berhenti
    menggambar** ciri itu. Di sini dua render dibandingkan piksel demi piksel.
    """
    pairs = [
        ("planet-jupiter-confirmed", "planet-jupiter-uncertain",
         "Bintik Merah Besar Jupiter"),
        ("planet-saturn-confirmed", "planet-saturn-uncertain", "cincin Saturnus"),
    ]
    for confirmed_name, uncertain_name, label in pairs:
        _, confirmed = render_case(confirmed_name, size=size, ss=ss)
        _, uncertain = render_case(uncertain_name, size=size, ss=ss)
        w, h, rows_a = confirmed
        _, _, rows_b = uncertain
        diff = 0
        for y in range(h):
            ra, rb = rows_a[y], rows_b[y]
            for x in range(w):
                if ra[x * 4:x * 4 + 3] != rb[x * 4:x * 4 + 3]:
                    diff += 1
        results.append(Result(
            f"{label} hilang saat ragu", diff > 0,
            f"{diff} piksel berbeda antara terkunci & ragu"))

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
        ("jumlah pita Jupiter", R.BAND_COUNT, 7,
         "let bandCount = 7", view),
        ("tinggi pita Jupiter", R.BAND_HEIGHT_FRACTION, 0.11,
         "radius * 0.11", view),
        ("busur separuh-lebar pita", R.BAND_HALF_WIDTH_ARC, 0.92,
         "cos((t - 0.5) * .pi * 0.92)", view),
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
    ]
    for label, port_value, expected, source_text, source in checks:
        results.append(Result(
            f"port sejalan: {label}", port_value == expected,
            f"port={port_value}, seharusnya {expected}"))
        results.append(Result(
            f"sumber Swift memuat: {label}", source_text in source,
            f"'{source_text}' {'ditemukan' if source_text in source else 'TIDAK ditemukan'}"
            f" di sumber Swift"))


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
