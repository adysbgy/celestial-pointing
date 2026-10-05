#!/usr/bin/env python3
"""Render `CelestialVisualView` ke PNG — supaya lapisan gambar bisa DILIHAT.

Kenapa alat ini ada, dan kenapa di Python.

`CelestialVisualView` tidak bisa dijalankan di Linux: ia butuh SwiftUI. Yang
bisa diuji di Linux adalah **model**-nya (`CelestialVisual` di `PointingKit`),
dan itu sudah diuji dengan rapi. Yang tidak pernah diuji apa pun adalah
**langkah menggambarnya** — dan repo ini sudah dua kali menuliskan batas itu di
STATUS.md ("belum pernah dilihat di perangkat").

Bentuk cacat yang hidup persis di celah itu sudah pernah terjadi di sini, dan
sudah pernah ditemukan dengan cara ini: sabit Bulan yang **tercermin vertikal**
karena `GraphicsContext.rotate` berkoordinat layar sementara `brightLimbAngle`
berkonvensi matematis. Modelnya benar, ujinya hijau, 22 gerbang UI hijau, CI
macOS hijau — dan gambarnya salah. Yang menemukannya bukan uji, melainkan
**gambar modelnya diport ke Python lalu dilihat dengan mata**.

Alat itu dulu sekali pakai dan tidak pernah dikomit. Berkas ini adalah
versi tetapnya: satu port dari lapisan menggambar, supaya setiap bentuk yang
belum pernah dilihat — pita Jupiter, cincin Saturnus, glow bintang, kabut
galaksi, lencana ragu — bisa diperiksa mata sebelum dikirim.

Batasnya jujur dan harus dibaca sebelum mempercayai hasilnya:

- Ini port **dari membaca kode**, bukan dari menjalankan SwiftUI. Kalau
  gambarnya berbeda dari perangkat, yang salah bisa jadi port ini.
- Yang diport adalah **geometri dan urutan menggambar**. Yang tidak diport:
  anti-aliasing SwiftUI yang sesungguhnya, `Material`, `blendMode`, dan
  `Canvas` yang memotong di frame (di sini frame tidak memotong, jadi
  luberan justru **terlihat** — itu disengaja, lihat `--frame`).
- Semua angka geometri diambil dari `PointingKit`, **tidak ada yang diketik
  ulang di sini** untuk nilai yang sudah ada di sana: palet planet, tabel
  warna bintang, `VisualFrame.saturnRing`, `star`, `deepSky`,
  `candidateMarker`, `polarCaps`, `phaseGeometry`, `NightVisual`. Nilai yang
  memang hidup di view (opasitas glow, susunan pita) ikut ditulis di sini dan
  ditandai komentar `VIEW:` — itu bagian yang paling mungkin menyimpang.

Pakai:
    python3 Tools/render-visuals.py                 # semua kasus → out/
    python3 Tools/render-visuals.py --frame         # tandai batas frame
    python3 Tools/render-visuals.py --night         # palet mode malam
"""

from __future__ import annotations

import argparse
import json
import math
import os
import struct
import zlib

OUT_DIR = "out/visuals"

# Path berkas ini, supaya pemeriksa drift bisa membaca sumbernya sendiri.
SOURCE = os.path.abspath(__file__)

# ══════════════════════════════════════════════════════════════════════════
# Port dari `PointingKit/NightVisual.swift`
# ══════════════════════════════════════════════════════════════════════════

NIGHT_FLOOR_BRIGHTNESS = 0.35
NIGHT_RANGE_BRIGHTNESS = 0.65
NIGHT_SHADOW_FRACTION = 0.5


def night_surface(day):
    """`NightVisual.surface` — hijau & biru dibuang total, bukan diredupkan."""
    b = NIGHT_FLOOR_BRIGHTNESS + NIGHT_RANGE_BRIGHTNESS * min(1, max(0, day[0]))
    return (b, 0.0, 0.0)


def night_shadow(day):
    """`NightVisual.shadow` — bagian yang tidak memancarkan cahaya."""
    return (min(1, max(0, day[0])) * NIGHT_SHADOW_FRACTION, 0.0, 0.0)


def night_mapped(day, is_shadow):
    return night_shadow(day) if is_shadow else night_surface(day)


# ══════════════════════════════════════════════════════════════════════════
# Port dari `PointingKit/CelestialVisual.swift` — palet & rumus
# ══════════════════════════════════════════════════════════════════════════

PLANET_PALETTE = {
    "mercury": dict(light=(0.72, 0.70, 0.68), dark=(0.26, 0.25, 0.24), feature="craters"),
    "venus":   dict(light=(0.99, 0.94, 0.76), dark=(0.62, 0.53, 0.30), feature="haze"),
    "mars":    dict(light=(0.88, 0.42, 0.26), dark=(0.38, 0.13, 0.08), feature="polarCaps"),
    "jupiter": dict(light=(0.90, 0.78, 0.61), dark=(0.45, 0.29, 0.17), feature="bands"),
    "saturn":  dict(light=(0.93, 0.84, 0.62), dark=(0.44, 0.36, 0.22), feature="rings"),
}

NEUTRAL_BODY = (0.74, 0.72, 0.68)
NEUTRAL_SHADOW = (0.28, 0.27, 0.26)

# `CelestialVisual.accents` — satu konstanta di paket, disalin apa adanya.
ACCENTS = dict(
    jupiterBandCream=(0.90, 0.83, 0.72),
    jupiterBandRust=(0.72, 0.52, 0.38),
    jupiterBandTan=(0.85, 0.76, 0.62),
    jupiterSpot=(0.85, 0.35, 0.25),
    saturnRing=(0.86, 0.78, 0.60),
    marsPolarCap=(0.97, 0.95, 0.93),
    venusHaze=(0.99, 0.96, 0.82),
    moonLit=(0.97, 0.95, 0.90),
    moonUnlit=(0.13, 0.13, 0.16),
    sunCore=(1.00, 0.93, 0.62),
    sunPhotosphere=(1.00, 0.72, 0.24),
    deepSky=(0.72, 0.78, 0.95),
    candidateFill=(0.10, 0.10, 0.13),
)

STAR_COLOR_INDEX = {
    "sirius": 0.00, "canopus": 0.15, "arcturus": 1.23, "vega": 0.00,
    "capella": 0.80, "rigel": -0.03, "procyon": 0.42, "achernar": -0.16,
    "betelgeuse": 1.85, "hadar": -0.23, "altair": 0.22, "acrux": -0.24,
    "aldebaran": 1.54, "spica": -0.23, "antares": 1.83, "pollux": 1.00,
    "fomalhaut": 0.09, "deneb": 0.09, "regulus": -0.11, "castor": 0.03,
    "bellatrix": -0.22, "alioth": -0.02, "alnitak": -0.21, "dubhe": 1.07,
    "polaris": 0.60,
}


def unit(v):
    return min(1.0, max(0.0, v))


def star_rgb(index):
    """`CelestialVisual.starRGB(forColorIndex:)`."""
    clamped = min(2.0, max(-0.5, index))
    warmth = (clamped + 0.35) / 1.70
    return (unit(0.62 + 0.38 * warmth),
            unit(0.78 - 0.16 * warmth),
            unit(1.00 - 0.72 * warmth))


def size_from_magnitude(m):
    """`CelestialVisual.sizeFromMagnitude` — skala logaritmik terbalik."""
    raw = 10.0 ** (-0.2 * (m - (-1.5)))
    return min(1.0, max(0.15, raw))


def phase_geometry(fraction, waxing):
    """`CelestialVisual.phaseGeometry(waxing:)`."""
    if fraction is None or waxing is None:
        return None
    f = min(1.0, max(0.0, fraction))
    lit_side = 1.0 if waxing else -1.0
    return dict(terminator_offset=lit_side * (1 - 2 * f), lit_side=lit_side, is_gibbous=f > 0.5)


def polar_caps(cap_height_fraction=0.26, half_width_fraction=0.55):
    """`CelestialVisual.polarCaps` — kutub selatan adalah cermin kutub utara."""
    height = 2 * cap_height_fraction
    return dict(height=height,
                half_width=half_width_fraction,
                north_top=-1.0,
                south_top=1.0 - height)


def saturn_ring(frame_half_extent=1.0, axial_ratio=1.0 / 3.2):
    """`VisualFrame.saturnRing`."""
    return dict(half_width=frame_half_extent, half_height=frame_half_extent * axial_ratio)


def saturn_body_radius(ring, body_fraction=0.53):
    """`VisualFrame.saturnBodyRadius`."""
    return ring["half_width"] * body_fraction


def star_geometry(relative_size, pulse_amplitude=0.10, glow_scales=(3.0, 1.9, 1.0),
                  spike_scale=3.2, frame_half_extent=1.0,
                  outer_fraction=(0.62, 0.92)):
    """`VisualFrame.star` — inti dihitung MUNDUR dari ruang yang tersedia."""
    clamped = min(1.0, max(0.0, relative_size))
    outer = frame_half_extent * (outer_fraction[0]
                                 + (outer_fraction[1] - outer_fraction[0]) * clamped)
    growth = max(max(glow_scales), spike_scale) * (1 + pulse_amplitude)
    return dict(core_radius=outer / growth, glow_scales=list(glow_scales),
                spike_scale=spike_scale, pulse_amplitude=pulse_amplitude)


DEEP_SKY_LAYOUT = {
    "nebula": [(-0.18, 0.12, 1.00, 1.0, 0.0, 0.42),
               (0.22, -0.16, 0.68, 1.0, 0.0, 0.30),
               (0.05, -0.04, 0.40, 1.0, 0.0, 0.55)],
    "galaxy": [(0.0, 0.0, 1.00, 0.34, -18.0, 0.30),
               (0.0, 0.0, 0.66, 0.30, -18.0, 0.26),
               (0.0, 0.0, 0.26, 0.42, -18.0, 0.60)],
    "openCluster": [(0.000000, -0.620000, 0.34, 1.0, 0.0, 0.55),
                    (-0.560000, -0.300000, 0.31, 1.0, 0.0, 0.50),
                    (0.520000, -0.340000, 0.33, 1.0, 0.0, 0.45),
                    (-0.680000, 0.180000, 0.29, 1.0, 0.0, 0.52),
                    (0.620000, 0.220000, 0.31, 1.0, 0.0, 0.48),
                    (-0.340000, 0.580000, 0.33, 1.0, 0.0, 0.42),
                    (0.300000, 0.620000, 0.29, 1.0, 0.0, 0.55)],
    "globularCluster": [(0.000000, 0.000000, 0.46, 1.0, 0.0, 0.55),
                        (0.289778, 0.077646, 0.22, 1.0, 0.0, 0.38),
                        (0.077646, 0.289778, 0.22, 1.0, 0.0, 0.38),
                        (-0.212132, 0.212132, 0.22, 1.0, 0.0, 0.38),
                        (-0.289778, -0.077646, 0.22, 1.0, 0.0, 0.38),
                        (-0.077646, -0.289778, 0.22, 1.0, 0.0, 0.38),
                        (0.212132, -0.212132, 0.22, 1.0, 0.0, 0.38),
                        (0.325269, 0.325269, 0.17, 1.0, 0.0, 0.22),
                        (-0.119057, 0.444326, 0.17, 1.0, 0.0, 0.22),
                        (-0.444326, 0.119057, 0.17, 1.0, 0.0, 0.22),
                        (-0.325269, -0.325269, 0.17, 1.0, 0.0, 0.22),
                        (0.119057, -0.444326, 0.17, 1.0, 0.0, 0.22),
                        (0.444326, -0.119057, 0.17, 1.0, 0.0, 0.22)],
}


def deep_sky_blobs(morphology, fuzziness, frame_half_extent=1.0):
    """`VisualFrame.deepSky` / `buildDeepSky` — tidak pernah keluar frame."""
    layout = DEEP_SKY_LAYOUT.get(morphology or "nebula", DEEP_SKY_LAYOUT["nebula"])
    clamped = min(1.0, max(0.0, fuzziness))
    growth = 0.62 + 0.38 * clamped
    blobs = []
    for offset_x, offset_y, width_scale, aspect, angle, opacity in layout:
        headroom_x = frame_half_extent - abs(offset_x)
        headroom_y = frame_half_extent - abs(offset_y)
        theta = math.radians(angle)
        cos_t, sin_t = abs(math.cos(theta)), abs(math.sin(theta))
        room_x = headroom_x / max(cos_t + aspect * sin_t, 1e-9)
        room_y = headroom_y / max(sin_t + aspect * cos_t, 1e-9)
        half_width = min(room_x, room_y) * growth * width_scale
        blobs.append(dict(offset_x=offset_x, offset_y=offset_y,
                          half_width=half_width, half_height=half_width * aspect,
                          angle_degrees=angle, opacity=opacity))
    return blobs


def candidate_marker(frame_half_extent=1.0, corner_fraction=0.34, inset=0.06,
                     glyph_fraction=0.52):
    """`VisualFrame.candidateMarker` — pusat + radius = sudut, jadi tidak bisa keluar."""
    corner = max(0.0, frame_half_extent * (1 - min(1.0, max(0.0, inset))))
    radius = corner * min(1.0, max(0.0, corner_fraction))
    d = corner - radius
    return dict(center_x=d, center_y=-d, radius=radius, glyph_fraction=glyph_fraction)


def candidate_marker_glyph(marker=None):
    """Geometri glif tanda tanya + tetesnya, dalam satuan radius frame.

    **Satu sumber untuk menggambar dan untuk mengukur.** Pemeriksa butuh tahu
    seberapa jauh lencana menjulur, dan cara termurah untuk mendapat angka itu
    adalah menanyakan fungsi yang menggambarnya. Kalau dua tempat menghitung
    sendiri-sendiri, keduanya bisa sepakat salah — pola yang sudah nyata di
    berkas ini.

    Konvensi satuannya yang pernah salah: `glyph_fraction` adalah pecahan dari
    radius **lencana**, bukan radius frame (lihat `CandidateMarker.glyphRadius`
    di model, dan `CGFloat(marker.glyphRadius) * radius` di view).
    """
    marker = candidate_marker() if marker is None else marker
    badge_radius = marker["radius"]
    r = badge_radius * marker["glyph_fraction"]
    cx, cy = marker["center_x"], marker["center_y"]
    top = cy - r * 0.55
    points = [(cx - r, top)]
    for i in range(1, 13):
        t = i / 12.0
        u = 1 - t
        x = (u ** 3 * (cx - r) + 3 * u * u * t * (cx - r * 0.1)
             + 3 * u * t * t * (cx + r * 0.55) + t ** 3 * cx)
        y = (u ** 3 * top + 3 * u * u * t * (top - r * 0.35)
             + 3 * u * t * t * (top + r * 0.05) + t ** 3 * (top + r * 0.55))
        points.append((x, y))
    points.append((cx, cy + r * 0.05))
    # **Satuan: radius frame (ternormalisasi), bukan piksel.**
    #
    # Versi pertama menulis `max(1.0, badge_radius * 0.28)`. Lantai 1.0 itu
    # masuk akal dalam **piksel** — view memakai `max(1, badgeRadius * 0.28)`
    # dan di sana `badgeRadius` memang piksel. Di sini `badge_radius` adalah
    # pecahan radius frame, jadi lantai 1.0 berarti "lebar garis selebar
    # radius frame": 6x lipat, dan `candidate_marker_footprint()` mewarisi
    # luberan itu sehingga kotak pengecualiannya menelan hampir seluruh
    # gambar. Penerjemahan satuan milik **pemanggil**, bukan fungsi geometri:
    # penggambar memakai `max(1.0, badgeRadiusPiksel * 0.28)`.
    stroke_width = badge_radius * 0.28
    # Tetes glif, sebagai **pergeseran dari pusat lencana** — bukan posisi
    # mutlak. Versi pertama menyimpannya mutlak (`cy + r*0.42`) lalu
    # menambahkannya ke pusat lagi di penggambar, sehingga tetesnya tergeser
    # dua kali. Bentuk yang menyebut perannya tidak bisa salah pakai.
    dot_offset = (0.0, r * 0.42)
    dot_radius = badge_radius * 0.13
    return (points, stroke_width, dot_offset, dot_radius,
            badge_radius, (cx, cy))


def candidate_marker_footprint(frame_half_extent=1.0):
    """Kotak yang ditempati lencana "?", sebagai pecahan setengah-sisi frame.

    Mengembalikan `(x0, y0, x1, y1)` dengan 0 = pusat dan 1 = tepi frame.
    Dipakai pemeriksa untuk mengabaikan lencana saat mengukur **ciri
    pengenal** — supaya "ciri hilang saat ragu" mengukur cirinya, bukan
    lencananya.

    Isinya **gabungan** dari segala yang digambar lencana: cakram lencana,
    glif tanda tanya beserta lebar garisnya, dan tetesnya. Versi pertama
    hanya mengembalikan cakramnya, dan itu tidak cukup: glif yang salah
    satuan menjulur **keluar** cakram, jadi kotak yang hanya menutup cakram
    tidak mengecualikan luberannya — persis cacat yang pengecualian ini ada
    untuk menutup.
    """
    marker = candidate_marker(frame_half_extent)
    points, stroke_width, dot_offset, dot_radius, badge_radius, center = \
        candidate_marker_glyph(marker)
    half_stroke = stroke_width / 2.0
    xs = [center[0] - badge_radius, center[0] + badge_radius]
    ys = [center[1] - badge_radius, center[1] + badge_radius]
    for x, y in points:
        xs += [x - half_stroke, x + half_stroke]
        ys += [y - half_stroke, y + half_stroke]
    dot_dx, dot_dy = dot_offset
    xs += [center[0] + dot_dx - dot_radius, center[0] + dot_dx + dot_radius]
    ys += [center[1] + dot_dy - dot_radius, center[1] + dot_dy + dot_radius]
    return (min(xs), min(ys), max(xs), max(ys))


def draw_rotation_radians(bright_limb_angle_radians):
    """`CelestialVisual.drawRotationRadians` — pembalikan tanda konvensi layar."""
    return -bright_limb_angle_radians


# ══════════════════════════════════════════════════════════════════════════
# Kanvas: rasterizer kecil dengan supersampling
# ══════════════════════════════════════════════════════════════════════════

class Canvas:
    """Buffer RGBA float 0…1, dengan penggabungan alfa `source-over`.

    Supersampling `ss` kali per sumbu dipakai untuk **cakupan** (coverage)
    piksel; gradien dihitung di titik sampel supaya tepi halus tidak
    menggeser warnanya.
    """

    def __init__(self, width, height, background, ss=3):
        self.w, self.h, self.ss = width, height, ss
        self.buf = [list(background) for _ in range(width * height)]

    # -- penggabungan --------------------------------------------------

    def _blend(self, index, rgb, alpha):
        if alpha <= 0:
            return
        if alpha > 1:
            alpha = 1.0
        dst = self.buf[index]
        for k in range(3):
            dst[k] = dst[k] + (rgb[k] - dst[k]) * alpha

    def fill(self, inside, color_at, alpha=1.0):
        """Isi daerah yang `inside(x, y)` benar dengan warna dari `color_at(x, y)`.

        `color_at` mengembalikan `(rgb, alpha)`; `alpha` argumen adalah
        pengali tambahan (opasitas `.opacity(n)` di SwiftUI).

        **Alfa dari `color_at` wajib ikut dikalikan.** Beberapa bentuk di view
        menggambar dengan warna yang **sebagian transparan**, dan satu di
        antaranya memakai alfa nol sebagai cara "tidak menggambar sama sekali"
        (maria Bulan hanya tergambar di dalam pita yang menyala, dengan
        `(lit, 0.0)` di luarnya). Kalau alfa itu dibuang, bercak maria yang
        seharusnya gelap 12% justru tergambar **penuh** sebagai permukaan
        terang — dan itu terbaca sebagai sabit yang jauh lebih lebar daripada
        fasenya. Cacatnya ada di alat ukur, bukan di view.
        """
        for py in range(self.h):
            for px in range(self.w):
                hits, samples = 0, []
                for sy in range(self.ss):
                    for sx in range(self.ss):
                        x = px + (sx + 0.5) / self.ss
                        y = py + (sy + 0.5) / self.ss
                        if inside(x, y):
                            hits += 1
                            samples.append((x, y))
                if not hits:
                    continue
                rgb = [0.0, 0.0, 0.0]
                alpha_sum = 0.0
                for x, y in samples:
                    c, a = color_at(x, y)
                    for k in range(3):
                        rgb[k] += c[k] * a
                    alpha_sum += a
                if alpha_sum <= 0:
                    continue
                # Warna = rata-rata berbobot alfa; alfa = rata-rata alfa.
                for k in range(3):
                    rgb[k] /= alpha_sum
                self._blend(py * self.w + px, rgb,
                            alpha * (alpha_sum / (self.ss * self.ss)))

    # -- bentuk --------------------------------------------------------

    def ellipse(self, cx, cy, rx, ry, color_at, alpha=1.0):
        def inside(x, y):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            return dx * dx + dy * dy <= 1.0
        self.fill(inside, color_at, alpha)

    def disc(self, cx, cy, r, color_at, alpha=1.0):
        self.ellipse(cx, cy, r, r, color_at, alpha)

    def polygon(self, points, color_at, alpha=1.0):
        n = len(points)

        def inside(x, y):
            # Ray casting, sisi atas ikut supaya tepi tidak bocor.
            c = False
            j = n - 1
            for i in range(n):
                xi, yi = points[i]
                xj, yj = points[j]
                if ((yi > y) != (yj > y)) and \
                        (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
                    c = not c
                j = i
            return c
        self.fill(inside, color_at, alpha)

    def rect(self, x0, y0, x1, y1, color_at, alpha=1.0):
        self.fill(lambda x, y: x0 <= x <= x1 and y0 <= y <= y1, color_at, alpha)

    def stroke_line(self, x0, y0, x1, y1, width, color_at, alpha=1.0):
        half = width / 2.0

        def inside(x, y):
            dx, dy = x1 - x0, y1 - y0
            length2 = dx * dx + dy * dy
            if length2 <= 0:
                return math.hypot(x - x0, y - y0) <= half
            t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / length2))
            return math.hypot(x - (x0 + t * dx), y - (y0 + t * dy)) <= half
        self.fill(inside, color_at, alpha)

    def stroke_circle(self, cx, cy, r, width, color_at, alpha=1.0):
        half = width / 2.0
        self.fill(lambda x, y: abs(math.hypot(x - cx, y - cy) - r) <= half,
                  color_at, alpha)

    def stroke_polyline(self, points, width, color_at, alpha=1.0):
        for i in range(len(points) - 1):
            self.stroke_line(points[i][0], points[i][1],
                             points[i + 1][0], points[i + 1][1],
                             width, color_at, alpha)

    # -- keluaran ------------------------------------------------------

    def to_png(self):
        # Baris mentah **tanpa** byte filter: `_png()` di bawah yang
        # menyisipkan satu byte filter 0 per baris. Menyisipkannya di sini
        # juga akan membuat `_png` memotong ulang buffer seolah tak ada
        # filter — hasilnya setiap baris bergeser satu byte dan PNG-nya rusak.
        raw = bytearray()
        for y in range(self.h):
            for x in range(self.w):
                r, g, b = self.buf[y * self.w + x]
                raw += bytes((int(unit(r) * 255 + 0.5),
                              int(unit(g) * 255 + 0.5),
                              int(unit(b) * 255 + 0.5), 255))
        return _png(self.w, self.h, bytes(raw))


def _png(width, height, pixels):
    """Bungkus RGBA mentah jadi PNG — sama seperti `Tools/make_app_icons.py`.

    Byte filter 0 **wajib** ada di awal setiap baris: itu bagian dari
    spesifikasi PNG, bukan pilihan. Tanpa byte itu arus IDAT berukuran
    `h * w * 4`, sedangkan pembaca mana pun menuntut `h * (w * 4 + 1)` dan
    membaca byte pertama baris sebagai tipe filter — nilainya di luar 0…4,
    jadi berkasnya ditolak (`ffmpeg`, Preview, browser). `decode_png` di
    `check-visuals.py` dulu mentoleransi bentuk yang salah itu, sehingga
    pembaca dan penulis repo ini sepakat satu sama lain sementara dunia luar
    tidak; lihat `check_png_is_well_formed`.
    """
    raw = b"".join(b"\x00" + pixels[y * width * 4:(y + 1) * width * 4]
                   for y in range(height))

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


# ══════════════════════════════════════════════════════════════════════════
# Port dari `Apps/Shared/CelestialVisualView.swift` — lapisan menggambar
# ══════════════════════════════════════════════════════════════════════════

GLOW_OPACITIES = [0.10, 0.22, 1.0]          # VIEW: `CelestialVisualView.glowOpacities`
BAND_COUNT = 7                              # MODEL: `CelestialVisual.jupiterBands(count:)`
BAND_HEIGHT_FRACTION = 0.11                 # MODEL: `CelestialVisual.jupiterBands(heightFraction:)`
BAND_OPACITY = 0.55                         # VIEW: `drawBands`
# Nama aturan geometri pita, dipakai `check-visuals.py` untuk menahan kedua
# bahasa agar memakai rumus bola yang sama. Kalau salah satu sisi kembali
# memakai aproksimasi kosinus, nama ini tidak akan ditemukan di sumbernya.
BAND_HALF_WIDTH_RULE = "sqrt"
# Lencana "?" — dipakai `check_features_disappear_when_uncertain` untuk
# **mengecualikan** daerah lencana dari pengukuran ciri. Lihat catatan di
# sana: tanpa pengecualian, selisih "terkunci vs ragu" selalu > 0 karena
# lencananya sendiri, sehingga ciri yang **tidak pernah digambar** pun lulus.
CANDIDATE_CORNER_FRACTION = 0.34                # MODEL: `VisualFrame.candidateMarker`
CANDIDATE_INSET = 0.06                          # MODEL: `VisualFrame.candidateMarker`
CANDIDATE_GLYPH_FRACTION = 0.52                 # MODEL: `VisualFrame.candidateMarker`
# Bintik Merah Besar: **pusat**, bukan sudut — satuan radius bola, relatif
# terhadap pusat bola. Model yang memilikinya (`CelestialVisual.jupiterSpot`),
# dan `check-visuals.py` menjaga keempat angkanya tetap sama dengan sumber
# Swift-nya. Sebelumnya larik ini diperlakukan sebagai **pusat** di sini
# sementara view Swift menulisnya ke `CGRect` (jadi **sudut**), sehingga
# gambar yang diukur semua gerbang menaruh bintiknya 0.26 R di sebelah kiri
# tempat bintik itu benar-benar tergambar di jam.
SPOT_CENTER = (-0.10, 0.31)                  # MODEL: `CelestialVisual.jupiterSpot`
SPOT_SIZE = (0.52, 0.26)                     # MODEL: `CelestialVisual.jupiterSpot`
CRATERS = [(-0.30, -0.22, 0.20), (0.28, -0.05, 0.15), (-0.12, 0.32, 0.17),
           (0.34, 0.34, 0.11), (0.02, -0.48, 0.13)]      # VIEW: `drawCraters`
MARIA = [(-0.28, -0.30, 0.26), (0.10, -0.44, 0.20),
         (-0.34, 0.06, 0.22), (0.22, 0.26, 0.16)]        # VIEW: `drawMoon`
MOON_PATH_STEPS = 72                                     # VIEW: `drawMoon`
SPIKE_OPACITY = 0.45                                     # VIEW: `drawStar`
# Pita cincin Saturnus. Batasnya **radius cincin nyata** dalam satuan radius
# Saturnus, dipetakan ke frame oleh `saturn_ring_bands()`; opasitas mengikuti
# kepadatan pita sebenarnya (D sangat tipis, B paling pekat, celah hampir
# kosong). MODEL: `VisualFrame.saturnRingBands`
SATURN_RING_REAL_EDGES = [1.11, 1.236, 1.525, 1.95, 2.025, 2.269]
SATURN_RING_BAND_OPACITIES = [0.14, 0.34, 0.78, 0.04, 0.62]
# MODEL: `VisualFrame.saturnRingBands(cassiniWidth:)` — sengaja lebih lebar
# dari kenyataan supaya masih terbaca di kartu jam.
SATURN_CASSINI_WIDTH = 0.06
# MODEL: `CelestialVisual.ringBackHalfOpacityScale`
RING_BACK_HALF_OPACITY_SCALE = 0.55
POLAR_CAP_OPACITY = 0.85                                 # VIEW: `drawPolarCaps`
CRATER_OPACITY = 0.18                                    # VIEW: `drawCraters`
MARIA_OPACITY = 0.12                                     # VIEW: `drawMoon`


class VisualCase:
    """Satu gambar yang akan dirender, dengan nama & catatan."""

    def __init__(self, name, note, kind, **kw):
        self.name, self.note, self.kind, self.kw = name, note, kind, kw


def color_fn(day_rgb, night_mode, is_shadow=False, opacity=1.0):
    """Port dari `CelestialVisualView.color(_:isShadow:)` + `.opacity()`."""
    rgb = night_mapped(day_rgb, is_shadow) if night_mode else day_rgb
    return lambda x, y: (rgb, opacity)


def accent_fn(day_rgb, night_mode, opacity=1.0):
    return color_fn(day_rgb, night_mode, is_shadow=False, opacity=opacity)


def shadow_fn(day_rgb, night_mode, opacity=1.0):
    return color_fn(day_rgb, night_mode, is_shadow=True, opacity=opacity)


def radial_gradient(colors, center, start_radius, end_radius):
    """Port dari `.radialGradient(Gradient(colors:), center:startRadius:endRadius:)`."""
    cx, cy = center
    stops = list(colors)

    def at(x, y):
        d = math.hypot(x - cx, y - cy)
        span = end_radius - start_radius
        t = 0.0 if span <= 0 else min(1.0, max(0.0, (d - start_radius) / span))
        pos = t * (len(stops) - 1)
        i = min(int(pos), len(stops) - 2)
        frac = pos - i
        c0, a0 = stops[i]
        c1, a1 = stops[i + 1]
        rgb = tuple(c0[k] + (c1[k] - c0[k]) * frac for k in range(3))
        return rgb, a0 + (a1 - a0) * frac
    return at


def linear_gradient(colors, start_point, end_point):
    """Port dari `.linearGradient(_:startPoint:endPoint:)`."""
    x0, y0 = start_point
    x1, y1 = end_point
    dx, dy = x1 - x0, y1 - y0
    length2 = dx * dx + dy * dy
    stops = list(colors)

    def at(x, y):
        if length2 <= 0:
            t = 0.0
        else:
            t = min(1.0, max(0.0, ((x - x0) * dx + (y - y0) * dy) / length2))
        pos = t * (len(stops) - 1)
        i = min(int(pos), len(stops) - 2)
        frac = pos - i
        c0, a0 = stops[i]
        c1, a1 = stops[i + 1]
        rgb = tuple(c0[k] + (c1[k] - c0[k]) * frac for k in range(3))
        return rgb, a0 + (a1 - a0) * frac
    return at


def solid(rgb, opacity=1.0):
    return lambda x, y: (rgb, opacity)


def render(case, size=256, night_mode=False, show_frame=False, ss=3):
    """Gambar satu `VisualCase` menjadi `Canvas`."""
    if night_mode:
        background = night_mapped((0.04, 0.04, 0.06), is_shadow=False)
        background = (background[0] * 0.35, 0.0, 0.0)
    else:
        background = (0.039, 0.039, 0.059)   # #0A0A0F — token latar app
    canvas = Canvas(size, size, background, ss=ss)
    cx = cy = size / 2.0
    radius = size / 2.0
    kind = case.kind
    kw = case.kw

    if kind == "planet":
        _draw_planet(canvas, cx, cy, radius, kw, night_mode)
    elif kind == "moon":
        _draw_moon(canvas, cx, cy, radius, kw, night_mode)
    elif kind == "star":
        _draw_star(canvas, cx, cy, radius, kw, night_mode)
    elif kind == "sun":
        _draw_sun(canvas, cx, cy, radius, kw, night_mode)
    elif kind == "deepSky":
        _draw_deep_sky(canvas, cx, cy, radius, kw, night_mode)
    else:
        raise ValueError(f"kind tidak dikenal: {kind}")

    if kw.get("is_confirmed") is False:
        _draw_candidate_marker(canvas, size, night_mode)
    if show_frame:
        _draw_frame(canvas, size, radius)
    return canvas


def _draw_frame(canvas, size, radius):
    """Batas `Canvas` — di sini **terlihat**, bukan memotong.

    `Canvas` SwiftUI memotong apa pun di luar frame dengan tepi lurus. Di
    render ini frame tidak memotong, justru supaya luberan terlihat: bentuk
    yang keluar batas adalah cacat, dan menyembunyikannya di sini akan
    mengulang persis kesalahan yang alat ini dibuat untuk menemukannya.
    """
    canvas.rect(0, 0, size, 0.6, solid((1.0, 0.25, 0.25)))
    canvas.rect(0, size - 0.6, size, size, solid((1.0, 0.25, 0.25)))
    canvas.rect(0, 0, 0.6, size, solid((1.0, 0.25, 0.25)))
    canvas.rect(size - 0.6, 0, size, size, solid((1.0, 0.25, 0.25)))


def _draw_sphere(canvas, cx, cy, radius, light, dark, night_mode):
    """`drawSphere` — gradien bola, cahaya dari kiri-atas."""
    gradient = radial_gradient(
        [(light if not night_mode else night_surface(light), 1.0),
         (dark if not night_mode else night_surface(dark), 1.0)],
        center=(cx - radius * 0.32, cy - radius * 0.32),
        start_radius=radius * 0.1, end_radius=radius * 1.35)
    canvas.disc(cx, cy, radius, gradient)


def _draw_planet(canvas, cx, cy, radius, kw, night_mode):
    planet = kw.get("planet")
    if planet is None:
        _draw_sphere(canvas, cx, cy, radius, NEUTRAL_BODY, NEUTRAL_SHADOW, night_mode)
        return
    palette = PLANET_PALETTE[planet]
    # **Bola dulu, dengan radius penuh — sama di kedua keadaan keyakinan.**
    #
    # Versi lama menggambar cincin Saturnus (dan bola kecil di dalamnya)
    # **sebelum** memeriksa `is_confirmed`, jadi cincin tetap tergambar pada
    # gambar "ragu". Itu dua cacat sekaligus:
    #
    # 1. Aturan PRD — ciri pengenal tidak boleh tampil saat engine ragu —
    #    dilanggar di port, yaitu gambar yang dipakai pemeriksa untuk
    #    membuktikan aturan itu ditegakkan.
    # 2. Bola Saturnus jadi lebih kecil (0,53 R) hanya pada gambar "ragu",
    #    sehingga selisih "terkunci vs ragu" terukur ~3900 piksel di seluruh
    #    piringan. Selisih itu membuat pemeriksaan "cincin hilang saat ragu"
    #    lulus **walaupun cincinnya tidak pernah digambar** — dibuktikan
    #    dengan menghapus cincinnya: tetap "OK, 3904 piksel berbeda".
    #
    # Urutan view Swift adalah sumber kebenarannya: `drawPlanet` menggambar
    # bola radius penuh lebih dulu, lalu `guard isConfirmed` **sebelum**
    # cabang ciri — jadi saat ragu yang tersisa memang hanya bola.
    _draw_sphere(canvas, cx, cy, radius, palette["light"], palette["dark"], night_mode)
    if kw.get("is_confirmed") is False:
        return
    feature = palette["feature"]
    if feature == "rings":
        _draw_rings(canvas, cx, cy, radius, palette, night_mode)
    elif feature == "bands":
        _draw_bands(canvas, cx, cy, radius, night_mode)
    elif feature == "polarCaps":
        _draw_polar_caps(canvas, cx, cy, radius, night_mode)
    elif feature == "craters":
        _draw_craters(canvas, cx, cy, radius, night_mode)
    elif feature == "haze":
        _draw_haze(canvas, cx, cy, radius, night_mode)


def jupiter_bands(count=BAND_COUNT, height_fraction=BAND_HEIGHT_FRACTION):
    """Port dari `CelestialVisual.jupiterBands()` — geometri pita dari bola.

    **Kenapa rumusnya ada di sini, bukan di `_draw_bands`.** Versi lama
    memakai `cos((t - 0.5) * pi * 0.92)` sambil berkomentar "pita mengikuti
    keliling bola". Kosinus itu bukan keliling bola: ia kebetulan sama di
    ekuator dan menyimpang makin jauh ke kutub, sehingga pita teratas
    berhenti 19% radius di dalam piringan. Kalau rumusnya hidup di dua
    tempat, perbaikannya juga harus dikerjakan dua kali — dan yang di Python
    adalah yang dipakai `check-visuals.py` untuk mengukur gambar. Sekarang
    satu rumus (`sqrt(1 - y^2)`), ditulis di kedua bahasa, dan
    `check_port_matches_swift_constants` yang menahan keduanya agar sama.
    """
    half_height = height_fraction / 2.0
    bands = []
    for index in range(count):
        t = (index + 0.5) / count
        y = -1 + 2 * t
        half_width = math.sqrt(max(0.0, 1 - y * y))
        bands.append((y, half_width, half_height))
    return bands


def _draw_bands(canvas, cx, cy, radius, night_mode):
    for index, (band_y, half_width, half_height) in enumerate(jupiter_bands()):
        y = cy + band_y * radius
        half_width *= radius
        if half_width <= 1:
            continue
        rx = half_width
        ry = radius * half_height
        name = ("jupiterBandTan", "jupiterBandRust", "jupiterBandCream")[index % 3]
        canvas.ellipse(cx, y, rx, ry,
                       accent_fn(ACCENTS[name], night_mode, BAND_OPACITY))
    dx, dy = SPOT_CENTER
    w, h = SPOT_SIZE
    canvas.ellipse(cx + dx * radius, cy + dy * radius,
                   w * radius / 2.0, h * radius / 2.0,
                   accent_fn(ACCENTS["jupiterSpot"], night_mode))


def saturn_ring_bands(body_fraction=0.53, cassini_width=0.06):
    """Pita cincin Saturnus — port `VisualFrame.saturnRingBands()`.

    Batas pita nyata (D 1.11-1.236, C 1.236-1.525, B 1.525-1.95, celah
    Cassini 1.95-2.025, A 2.025-2.269) dipetakan ke rentang yang tersedia:
    tepi dalam = tepi bola, tepi luar = 1.0. Rasio antar-pita dipertahankan.

    Celah Cassini dilebarkan (bukan angka nyata) dengan pusat tetap, karena
    lebar sebenarnya hanya 0.6 pt di kartu jam 38 pt dan akan hilang.
    """
    edges = list(SATURN_RING_REAL_EDGES)
    inner, outer = edges[0], edges[-1]

    def mapped(r):
        return body_fraction + (r - inner) / (outer - inner) * (1 - body_fraction)

    edges = [mapped(r) for r in edges]
    center = (edges[3] + edges[4]) / 2.0
    half = cassini_width / 2.0
    edges[3] = center - half
    edges[4] = center + half
    return [(edges[i], edges[i + 1], SATURN_RING_BAND_OPACITIES[i])
            for i in range(len(SATURN_RING_BAND_OPACITIES))]


def _draw_rings(canvas, cx, cy, radius, palette, night_mode):
    """Cincin sebagai pita, bukan satu elips pekat.

    Urutannya penting dan sama dengan view: pita **belakang** dulu (paruh
    atas), lalu bola, lalu pita **depan** (paruh bawah) di atas bola. Itu
    yang membuat cincin benar-benar melintas di muka ekuator bola, bukan
    mengapung di atasnya.

    Tiap pita adalah **cincin** (elips luar dikurangi elips dalam), bukan
    elips lalu elips hitam di atasnya — elips hitam akan menghapus bola yang
    ada di bawahnya di paruh depan.
    """
    ring = saturn_ring()
    body_radius = saturn_body_radius(ring)
    ring_color = ACCENTS["saturnRing"]
    full_width = ring["half_width"] * radius
    axial = ring["half_height"] / ring["half_width"]
    bands = saturn_ring_bands()

    def annulus(outer_r, inner_r, color, half):
        """Isi cincin antara outer_r dan inner_r, dibatasi paruh atas/bawah."""
        orx, ory = outer_r, outer_r * axial
        irx, iry = inner_r, inner_r * axial

        def inside(x, y):
            if half == "back" and y > cy:
                return False
            if half == "front" and y < cy:
                return False
            dx, dy = (x - cx) / orx, (y - cy) / ory
            if dx * dx + dy * dy > 1.0:
                return False
            if inner_r <= 0:
                return True
            ix, iy = (x - cx) / irx, (y - cy) / iry
            return ix * ix + iy * iy > 1.0
        canvas.fill(inside, color)

    # Paruh belakang: seluruhnya di bawah bola yang digambar sesudahnya.
    for inner_r, outer_r, opacity in bands:
        annulus(outer_r * full_width, inner_r * full_width,
                accent_fn(ring_color, night_mode,
                          opacity * RING_BACK_HALF_OPACITY_SCALE), "back")

    _draw_sphere(canvas, cx, cy, body_radius * radius,
                 palette["light"], palette["dark"], night_mode)

    # Paruh depan: di atas bola.
    for inner_r, outer_r, opacity in bands:
        annulus(outer_r * full_width, inner_r * full_width,
                accent_fn(ring_color, night_mode, opacity), "front")


def _draw_polar_caps(canvas, cx, cy, radius, night_mode):
    caps = polar_caps()
    cap = accent_fn(ACCENTS["marsPolarCap"], night_mode, POLAR_CAP_OPACITY)
    for top_y in (caps["north_top"], caps["south_top"]):
        canvas.ellipse(cx,
                       cy + (top_y + caps["height"] / 2.0) * radius,
                       caps["half_width"] * radius,
                       caps["height"] * radius / 2.0,
                       cap)


def _draw_craters(canvas, cx, cy, radius, night_mode):
    crater = solid((0.0, 0.0, 0.0), CRATER_OPACITY)
    for dx, dy, size in CRATERS:
        canvas.disc(cx + dx * radius, cy + dy * radius, size * radius, crater)


def _draw_haze(canvas, cx, cy, radius, night_mode):
    haze = ACCENTS["venusHaze"]
    rgb = night_surface(haze) if night_mode else haze
    gradient = linear_gradient([(rgb, 0.0), (rgb, 0.7)],
                               start_point=(cx, cy - radius),
                               end_point=(cx, cy))
    canvas.ellipse(cx, cy + radius * 0.14, radius * 0.55, radius * 0.72, gradient)


def _draw_moon(canvas, cx, cy, radius, kw, night_mode):
    unlit = ACCENTS["moonUnlit"]
    canvas.disc(cx, cy, radius, shadow_fn(unlit, night_mode))
    phase = phase_geometry(kw.get("illumination"), kw.get("is_waxing"))
    if phase is None:
        return
    # Bangun pita terang di ruang gambar (sisi terang ke kanan), lalu putar.
    lit_side = phase["lit_side"]
    offset = phase["terminator_offset"]
    angle = kw.get("bright_limb_angle")
    rotate = draw_rotation_radians(angle) if angle is not None else 0.0
    cos_r, sin_r = math.cos(rotate), math.sin(rotate)

    def to_screen(x_model, y_model):
        """Titik model (satuan radius, y ke bawah) → koordinat piksel, diputar."""
        # `rotate(by:)` di koordinat layar: positif = searah jarum jam.
        sx = x_model * cos_r - y_model * sin_r
        sy = x_model * sin_r + y_model * cos_r
        return cx + sx * radius, cy + sy * radius

    steps = MOON_PATH_STEPS
    points = []
    for step in range(steps + 1):
        t = step / steps
        h = -1 + 2 * t
        points.append(to_screen(lit_side * math.sqrt(max(0.0, 1 - h * h)), h))
    for step in range(steps, -1, -1):
        t = step / steps
        h = -1 + 2 * t
        points.append(to_screen(offset * math.sqrt(max(0.0, 1 - h * h)), h))

    lit_color = ACCENTS["moonLit"]
    lit_rgb = night_surface(lit_color) if night_mode else lit_color

    def inside_lit(x, y):
        if math.hypot(x - cx, y - cy) > radius:
            return False
        return _point_in_polygon(x, y, points)
    canvas.fill(inside_lit, solid(lit_rgb))

    maria = solid((0.0, 0.0, 0.0), MARIA_OPACITY)
    for dx, dy, size in MARIA:
        mx, my = to_screen(dx, dy)
        canvas.disc(mx, my, size * radius,
                    lambda x, y: maria(x, y) if _point_in_polygon(x, y, points)
                    else (lit_rgb, 0.0))


def _point_in_polygon(x, y, points):
    c = False
    j = len(points) - 1
    for i in range(len(points)):
        xi, yi = points[i]
        xj, yj = points[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            c = not c
        j = i
    return c


def drawable_star_color_index(color_index, is_confirmed):
    """`CelestialVisual.drawableStarColorIndex` — warna hanya saat yakin.

    Warna spektral bintang adalah ciri pengenal (biru Rigel vs merah
    Betelgeuse), jadi saat engine ragu ia tidak boleh tampil. Nilai "tidak
    mengklaim" adalah indeks bintang yang tidak ada di tabel — sama dengan
    yang sudah dipakai `colorIndex(forStarID:)` untuk id tak dikenal.
    """
    if not is_confirmed:
        return STAR_COLOR_INDEX.get("", 0.0)
    return color_index


def _draw_star(canvas, cx, cy, radius, kw, night_mode):
    geometry = star_geometry(kw.get("relative_size", 0.5))
    core_radius = radius * geometry["core_radius"]
    # VIEW: `starColor` memakai `drawableStarColorIndex` lebih dulu.
    color_index = drawable_star_color_index(kw.get("color_index", 0.0),
                                            kw.get("is_confirmed", True))
    base = star_rgb(color_index)
    if night_mode:
        relative = kw.get("relative_size", 0.5)
        brightness = NIGHT_FLOOR_BRIGHTNESS + NIGHT_RANGE_BRIGHTNESS * min(1, max(0, relative))
        color = (brightness, 0.0, 0.0)
    else:
        color = base
    pulse_factor = 1 + geometry["pulse_amplitude"] * math.sin(kw.get("pulse", 0.0))
    for index, scale in enumerate(geometry["glow_scales"]):
        r = core_radius * scale * pulse_factor
        opacity = GLOW_OPACITIES[min(index, len(GLOW_OPACITIES) - 1)]
        canvas.disc(cx, cy, r,
                    radial_gradient([(color, opacity), (color, 0.0)],
                                    center=(cx, cy), start_radius=0, end_radius=r))
    spike = core_radius * geometry["spike_scale"] * pulse_factor
    width = max(0.5, core_radius * 0.18)
    line = solid(color, SPIKE_OPACITY)
    canvas.stroke_line(cx - spike, cy, cx + spike, cy, width, line)
    canvas.stroke_line(cx, cy - spike, cx, cy + spike, width, line)


def _draw_sun(canvas, cx, cy, radius, kw, night_mode):
    core = ACCENTS["sunCore"]
    photo = ACCENTS["sunPhotosphere"]
    core_rgb = night_surface(core) if night_mode else core
    photo_rgb = night_surface(photo) if night_mode else photo
    inner = core_rgb if night_mode else (1.0, 1.0, 1.0)
    canvas.disc(cx, cy, radius * 0.72,
                radial_gradient([(inner, 1.0), (core_rgb, 1.0), (photo_rgb, 1.0)],
                                center=(cx, cy), start_radius=0, end_radius=radius * 0.72))
    canvas.disc(cx, cy, radius,
                radial_gradient([(core_rgb, 0.42), (core_rgb, 0.0)],
                                center=(cx, cy), start_radius=radius * 0.6,
                                end_radius=radius))


def _draw_deep_sky(canvas, cx, cy, radius, kw, night_mode):
    core = ACCENTS["deepSky"]
    core_rgb = night_surface(core) if night_mode else core
    morphology = kw.get("morphology") if kw.get("is_confirmed", True) else None
    blobs = deep_sky_blobs(morphology, kw.get("fuzziness", 0.6))
    for blob in blobs:
        half_w = blob["half_width"] * radius
        half_h = blob["half_height"] * radius
        if half_w <= 0 or half_h <= 0:
            continue
        bx = cx + blob["offset_x"] * radius
        by = cy + blob["offset_y"] * radius
        angle = math.radians(blob["angle_degrees"])
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        opacity = blob["opacity"]

        def at(x, y, bx=bx, by=by, half_w=half_w, cos_a=cos_a, sin_a=sin_a,
               opacity=opacity):
            dx, dy = x - bx, y - by
            # Skala sumbu y, bukan elips: gradien radial selalu melingkar.
            lx = dx * cos_a + dy * sin_a
            ly = -dx * sin_a + dy * cos_a
            ly /= (half_h / half_w)
            d = math.hypot(lx, ly)
            t = min(1.0, d / half_w) if half_w > 0 else 1.0
            return core_rgb, opacity * (1 - t)
        canvas.fill(lambda x, y, bx=bx, by=by, half_w=half_w, half_h=half_h,
                    cos_a=cos_a, sin_a=sin_a:
                    _inside_rotated_ellipse(x, y, bx, by, half_w, half_h, cos_a, sin_a),
                    at)


def _inside_rotated_ellipse(x, y, bx, by, half_w, half_h, cos_a, sin_a):
    dx, dy = x - bx, y - by
    lx = dx * cos_a + dy * sin_a
    ly = -dx * sin_a + dy * cos_a
    return (lx / half_w) ** 2 + (ly / half_h) ** 2 <= 1.0


def _draw_candidate_marker(canvas, size, night_mode):
    marker = candidate_marker()
    radius = size / 2.0
    badge_radius = marker["radius"] * radius
    center = (size / 2.0 + marker["center_x"] * radius,
              size / 2.0 + marker["center_y"] * radius)
    canvas.disc(center[0], center[1], badge_radius,
                shadow_fn(ACCENTS["candidateFill"], night_mode))
    warning = _warning_color(night_mode)
    canvas.stroke_circle(center[0], center[1], badge_radius, 1.5, solid(warning))
    # Glif tanda tanya — Path, bukan teks (lihat `drawCandidateMarker`).
    #
    # **Geometrinya dari `candidate_marker_glyph`, bukan dihitung di sini.**
    # Versi lama menulis `r = marker["glyph_fraction"] * radius`, yaitu pecahan
    # dari radius **frame**; view memakai pecahan dari radius **lencana**
    # (`marker.glyphRadius * radius`). Selisihnya 3.1x, dan glifnya menjulur
    # keluar lencana lalu terpotong tepi frame. Pemeriksa butuh bentuk yang
    # sama untuk mengukur, jadi bentuknya hanya boleh hidup di satu tempat.
    glyph = candidate_marker_glyph(marker)
    points, _, dot_offset, dot_radius, _, _ = glyph
    points = [(center[0] + gx * radius, center[1] + gy * radius)
              for gx, gy in points]
    canvas.stroke_polyline(points, max(1.0, badge_radius * 0.28), solid(warning))
    dot_dx, dot_dy = dot_offset
    canvas.disc(center[0] + dot_dx * radius, center[1] + dot_dy * radius,
                dot_radius * radius, solid(warning))


def _warning_color(night_mode):
    """`PointingTone.warning.color` dari `TonePalette` (mode terang) / malam."""
    if night_mode:
        return night_surface((0.94, 0.62, 0.20))
    return (0.94, 0.62, 0.20)


# ══════════════════════════════════════════════════════════════════════════
# Kasus-kasus yang dirender
# ══════════════════════════════════════════════════════════════════════════

def build_cases():
    cases = []

    # ── Planet ────────────────────────────────────────────────────────
    for planet in ("mercury", "venus", "mars", "jupiter", "saturn"):
        cases.append(VisualCase(f"planet-{planet}-confirmed",
                                f"{planet} — terkunci, ciri pengenal boleh tampil",
                                "planet", planet=planet, is_confirmed=True))
    # Pasangan "terkunci / ragu" untuk **setiap** planet berciri, bukan hanya
    # dua. Aturan "ciri pengenal hilang saat ragu" berlaku untuk semua planet
    # (satu `guard isConfirmed` di view menutup kelimanya), tapi hanya dua
    # yang pernah diukur — jadi Mars, Merkurius, dan Venus bisa kehilangan
    # gerbangnya tanpa ada yang tahu. Menambah pasangannya di sini membuat
    # aturan yang sama terukur di kelimanya.
    for planet, feature in (("jupiter", "pita"), ("saturn", "cincin"),
                            ("mars", "kutub"), ("mercury", "kawah"),
                            ("venus", "kabut")):
        cases.append(VisualCase(f"planet-{planet}-uncertain",
                                f"{planet} saat engine RAGU — {feature} harus hilang",
                                "planet", planet=planet, is_confirmed=False))
    cases.append(VisualCase("planet-unknown-confirmed",
                            "planet yang id-nya tak dikenal — bola netral",
                            "planet", planet=None, is_confirmed=True))

    # ── Bulan ─────────────────────────────────────────────────────────
    for label, fraction, waxing, angle, note in (
        ("crescent-jakarta", 0.18, True, -math.pi / 2,
         "sabit muda Jakarta — sisi terang ke BAWAH (ke arah Matahari terbenam)"),
        ("crescent-jakarta-unrotated", 0.18, True, None,
         "sabit yang sama tanpa sudut — pembanding arah"),
        ("gibbous", 0.72, True, 0.0, "gibbous — pita lebar, terminator lewat pusat"),
        ("full", 1.0, True, 0.0, "purnama — piringan penuh"),
        ("new", 0.0, True, 0.0, "bulan baru — piringan gelap"),
        ("unknown-phase", None, None, None,
         "fase tidak diketahui — piringan polos, TIDAK memihak sisi"),
    ):
        cases.append(VisualCase(f"moon-{label}", note, "moon",
                                illumination=fraction, is_waxing=waxing,
                                bright_limb_angle=angle, is_confirmed=True))
    cases.append(VisualCase("moon-crescent-uncertain",
                            "sabit saat engine RAGU — lencana tanya di atasnya",
                            "moon", illumination=0.18, is_waxing=True,
                            bright_limb_angle=-math.pi / 2, is_confirmed=False))

    # ── Bintang ───────────────────────────────────────────────────────
    for star in ("sirius", "betelgeuse", "rigel", "vega"):
        cases.append(VisualCase(
            f"star-{star}", f"{star} — B−V {STAR_COLOR_INDEX[star]:+.2f}",
            "star", color_index=STAR_COLOR_INDEX[star],
            relative_size=size_from_magnitude(0.0), is_confirmed=True))
    cases.append(VisualCase("star-faint", "bintang redup — ukuran mengikuti magnitudo",
                            "star", color_index=0.0,
                            relative_size=size_from_magnitude(3.5), is_confirmed=True))
    cases.append(VisualCase("star-pulse-peak", "bintang pada puncak denyut",
                            "star", color_index=0.0,
                            relative_size=size_from_magnitude(-1.4),
                            pulse=math.pi / 2, is_confirmed=True))
    # Saat engine ragu, warna spektral tidak boleh lagi tampil: Betelgeuse
    # (B−V +1.85, merah) dan Rigel (−0.03, biru) harus jadi titik yang sama.
    # Kalau keduanya masih berbeda di sini, artinya identitas masih diklaim.
    cases.append(VisualCase(
        "star-betelgeuse-uncertain",
        "Betelgeuse saat engine RAGU — warna spektral harus hilang",
        "star", color_index=STAR_COLOR_INDEX["betelgeuse"],
        relative_size=size_from_magnitude(0.0), is_confirmed=False))
    cases.append(VisualCase(
        "star-rigel-uncertain",
        "Rigel saat engine RAGU — harus sama persis dengan Betelgeuse di atas",
        "star", color_index=STAR_COLOR_INDEX["rigel"],
        relative_size=size_from_magnitude(0.0), is_confirmed=False))
    cases.append(VisualCase(
        "star-unknown-id",
        "bintang yang tidak ada di katalog — warna netral, tidak mengklaim",
        "star", color_index=STAR_COLOR_INDEX.get("", 0.0),
        relative_size=size_from_magnitude(0.0), is_confirmed=True))

    # ── Matahari ──────────────────────────────────────────────────────
    cases.append(VisualCase("sun", "Matahari — fotosfer + corona", "sun",
                            is_confirmed=True))

    # ── Objek langit dalam ────────────────────────────────────────────
    for morph, note in (("nebula", "nebula emisi (M42)"),
                        ("galaxy", "galaksi (M31/M51)"),
                        ("openCluster", "gugus terbuka (Pleiades)"),
                        ("globularCluster", "gugus bola (M13)")):
        cases.append(VisualCase(f"deepsky-{morph}", note, "deepSky",
                                morphology=morph, fuzziness=0.8, is_confirmed=True))
    cases.append(VisualCase("deepsky-uncertain",
                            "objek langit dalam saat RAGU — kabut netral, bukan bentuknya",
                            "deepSky", morphology="galaxy", fuzziness=0.8,
                            is_confirmed=False))
    cases.append(VisualCase("deepsky-unknown-id",
                            "id tak dikenal — morfologi nil, kabut netral",
                            "deepSky", morphology=None, fuzziness=0.6,
                            is_confirmed=True))
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--size", type=int, default=256, help="ukuran gambar (px)")
    parser.add_argument("--night", action="store_true", help="palet mode malam")
    parser.add_argument("--frame", action="store_true", help="gambar batas frame")
    parser.add_argument("--ss", type=int, default=3, help="supersampling per sumbu")
    parser.add_argument("--out", default=OUT_DIR, help="direktori keluaran")
    parser.add_argument("--only", default=None, help="saring nama kasus (substring)")
    args = parser.parse_args()

    suffix = "-night" if args.night else ""
    os.makedirs(args.out, exist_ok=True)
    cases = [c for c in build_cases()
             if args.only is None or args.only in c.name]

    tiles = []
    for case in cases:
        canvas = render(case, size=args.size, night_mode=args.night,
                        show_frame=args.frame, ss=args.ss)
        name = f"{case.name}{suffix}.png"
        path = os.path.join(args.out, name)
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        tiles.append((name, case.note))
        print(f"{path}  {case.note}")

    index = os.path.join(args.out, f"index{suffix}.html")
    with open(index, "w", encoding="utf-8") as handle:
        handle.write("<!doctype html><meta charset='utf-8'>\n")
        handle.write(f"<title>CelestialVisual{suffix}</title>\n")
        handle.write("<style>body{background:#0A0A0F;color:#e8e8ee;"
                     "font:14px/1.5 -apple-system,system-ui,sans-serif;padding:24px}"
                     "figure{display:inline-block;margin:12px;text-align:center;"
                     "width:264px;vertical-align:top}"
                     "img{image-rendering:auto;border:1px solid #2a2a33;"
                     "border-radius:12px;background:#121216}"
                     "figcaption{color:#9a9aa8;font-size:12px;margin-top:6px}"
                     "h1{font-size:18px}</style>\n")
        handle.write(f"<h1>CelestialVisual — {'mode malam' if args.night else 'mode terang'}"
                     f" ({len(tiles)} kasus)</h1>\n")
        for name, note in tiles:
            handle.write(f"<figure><img src='{name}' width='{args.size}'"
                         f" height='{args.size}'><figcaption>{name}<br>{note}"
                         f"</figcaption></figure>\n")
    print(f"\n{index}  ({len(tiles)} kasus)")


if __name__ == "__main__":
    main()
