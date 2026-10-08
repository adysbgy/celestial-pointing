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
    # Pasangan cekungan kawah Merkurius. Lihat `NightVisual.Accents.craterFloor`
    # untuk kenapa bayangan ini **bukan** `planetUnlit`: dasar kawah adalah
    # permukaan berdebu yang masih memantulkan cahaya sekeliling, dan hitam
    # murni di atas abu-abu terbaca sebagai lubang, bukan cekungan.
    craterFloor=(0.16, 0.155, 0.15),
    craterRim=(0.86, 0.84, 0.81),
    planetUnlit=(0.06, 0.06, 0.08),
    moonLit=(0.97, 0.95, 0.90),
    moonUnlit=(0.13, 0.13, 0.16),
    moonEarthshine=(0.30, 0.30, 0.37),
    moonPhaseUnknown=(0.52, 0.52, 0.55),
    sunCore=(1.00, 0.93, 0.62),
    sunPhotosphere=(1.00, 0.72, 0.24),
    deepSky=(0.72, 0.78, 0.95),
    # MODEL: `NightVisual.Accents.deepSky*` — warna kabut per morfologi.
    # Satu warna untuk enam benda adalah cacat yang ditutup siklus ini; lihat
    # komentar di `NightVisual.swift`.
    deepSkyNebula=(0.88, 0.44, 0.50),
    deepSkyPlanetaryNebula=(0.42, 0.78, 0.86),
    deepSkyGalaxy=(0.82, 0.78, 0.70),
    deepSkySpiralGalaxy=(0.48, 0.58, 0.96),
    deepSkyOpenCluster=(0.95, 0.97, 1.00),
    deepSkyGlobularCluster=(0.93, 0.74, 0.42),
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
    """`CelestialVisual.phaseGeometry(fraction:waxing:)`."""
    if fraction is None or waxing is None:
        return None
    f = min(1.0, max(0.0, fraction))
    lit_side = 1.0 if waxing else -1.0
    return dict(terminator_offset=lit_side * (1 - 2 * f), lit_side=lit_side, is_gibbous=f > 0.5)


def terminator_rotation_radians(bright_limb_angle, phase):
    """`CelestialVisual.terminatorRotationRadians`.

    **Kenapa port ini wajib ada.** Sampai siklus ini, gambar Bulan Python
    memakai sudut Matahari mentah sebagai putaran. Itu **salah** untuk pita
    yang dasarnya ada di kiri (cembung mengecil): sisi terang lalu menghadap
    menjauhi Matahari. Selama `check-visuals.py` memakai rumus yang berbeda
    dari view, seluruh pemeriksaan arah di berkas itu mengukur gambar yang
    tidak pernah digambar aplikasi.
    """
    if bright_limb_angle is None or phase is None:
        return 0.0
    if phase["lit_side"] < 0:
        return bright_limb_angle + math.pi
    return bright_limb_angle


def planet_shows_phase(planet):
    """`CelestialVisual.Planet.showsPhase` — hanya planet dalam."""
    return planet in ("mercury", "venus")


def planet_phase_fraction(planet, illumination):
    """`planetIlluminationFraction` — planet luar tidak pernah berfase."""
    if not planet_shows_phase(planet):
        return None
    if illumination is None or not (0.0 <= illumination <= 1.0):
        return None
    return illumination


# Kutub Mars. **Lebarnya sengaja tidak ada di sini**: ia diturunkan dari tepi
# bola (`sqrt(1 - y^2)`) di `polar_caps()`, jadi menyalinnya sebagai konstanta
# justru akan mengembalikan cacat yang baru saja ditutup. Yang dijaga
# `check-visuals.py` karena itu **rumusnya** (`POLAR_CAP_WIDTH_RULE`), bukan
# angkanya. MODEL: `CelestialVisual.polarCaps(pinchY:depthFraction:)`
POLAR_CAP_PINCH_Y = -0.74
POLAR_CAP_DEPTH_FRACTION = 0.26
POLAR_CAP_WIDTH_RULE = "sqrt"


def polar_caps(pinch_y=POLAR_CAP_PINCH_Y, depth_fraction=POLAR_CAP_DEPTH_FRACTION):
    """`CelestialVisual.polarCaps` — kutub selatan adalah cermin kutub utara.

    Lebarnya **diturunkan** dari tepi bola (`sqrt(1 - y^2)`), bukan ditulis
    sebagai konstanta: itulah yang membuat kutub menyentuh tepi, bukan
    mengambang di dalam piringan. Lihat `_draw_polar_caps` untuk irisan
    piringannya — elips selebar ini tetap menjulur keluar bola di baris lain,
    jadi ia harus dipotong.
    """
    half_width = math.sqrt(max(0.0, 1 - pinch_y * pinch_y))
    return dict(half_width=half_width,
                half_height=depth_fraction,
                north_center=pinch_y,
                south_center=-pinch_y)


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


# Warna kabut per morfologi — MODEL: `CelestialVisual.deepSkyColour(for:)`.
# Kuncinya adalah nama `DeepSkyCatalogue.Morphology`; `None` (id tak dikenal
# atau engine belum pasti) jatuh ke kabut netral.
DEEP_SKY_COLOUR_KEY = {
    "nebula": "deepSkyNebula",
    "planetaryNebula": "deepSkyPlanetaryNebula",
    "galaxy": "deepSkyGalaxy",
    "spiralGalaxy": "deepSkySpiralGalaxy",
    "openCluster": "deepSkyOpenCluster",
    "globularCluster": "deepSkyGlobularCluster",
}

DEEP_SKY_LAYOUT = {
    "nebula": [(-0.18, 0.12, 1.00, 1.0, 0.0, 0.42),
               (0.22, -0.16, 0.68, 1.0, 0.0, 0.30),
               (0.05, -0.04, 0.40, 1.0, 0.0, 0.55)],
    # MODEL: `VisualFrame.deepSky(.planetaryNebula)` — cangkang berongga.
    # Semua blob pada radius yang sama, dan **tidak ada yang di tengah**:
    # kebalikan dari nebula emisi di atas, yang blobnya justru paling besar &
    # paling terang di pusat. Dua bentuk bertolak belakang, jadi port yang
    # tidak menggambar cabang ini akan membuat setiap pemeriksaan gambar
    # mengukur bentuk yang tidak pernah tampil.
    "planetaryNebula": [(0.4200000000000000, 0.0000000000000000, 0.30, 1.0, 0.0, 0.54),
                        (0.2969848483038187, 0.2969848483038187, 0.30, 1.0, 0.0, 0.48),
                        (0.0000000000000000, 0.4200000000000000, 0.30, 1.0, 0.0, 0.52),
                        (-0.2969848483038187, 0.2969848483038187, 0.30, 1.0, 0.0, 0.46),
                        (-0.4200000000000000, 0.0000000000000000, 0.30, 1.0, 0.0, 0.50),
                        (-0.2969848483038187, -0.2969848483038187, 0.30, 1.0, 0.0, 0.44),
                        (0.0000000000000000, -0.4200000000000000, 0.30, 1.0, 0.0, 0.53),
                        (0.2969848483038187, -0.2969848483038187, 0.30, 1.0, 0.0, 0.47)],
    "galaxy": [(0.0, 0.0, 1.00, 0.34, -18.0, 0.30),
               (0.0, 0.0, 0.66, 0.30, -18.0, 0.26),
               (0.0, 0.0, 0.26, 0.42, -18.0, 0.60)],
    # MODEL: `VisualFrame.deepSky(.spiralGalaxy)` — dua lengan pada spiral
    # logaritmik, ditambah tonjolan inti & kabut cakram. Kebalikan dari
    # `galaxy` di atas, yang **seluruh** blobnya di titik pusat: di sini
    # lengan adalah seluruh isinya, jadi port yang tidak menggambar cabang
    # ini membuat setiap pemeriksaan gambar mengukur cakram yang tidak
    # pernah tampil untuk M51/M101.
    #
    # **Kenapa 5 titik per lengan, bukan 4.** Jarak antar-titik **membesar**
    # ke luar (Δr = 0.078 → 0.105 → 0.142) sementara lebar blob menyusut
    # (0.24 → 0.16), jadi dengan 4 titik lengkungnya **bolong** tepat di
    # antara dua titik terluar. Diukur pada 76 px: r=0.45 punya 38° di atas
    # ambang, r=0.50 hanya 6°, r=0.55 kembali 12°. Titik sisipan (θ = 2.85)
    # memakai lebar & opasitas yang diinterpolasi dari tetangganya.
    # Dijaga `check_spiral_arms_stay_continuous`.
    "spiralGalaxy": [(0.000000, 0.000000, 0.32, 1.0, 0.0, 0.60),
                     (0.000000, 0.000000, 0.45, 1.0, 0.0, 0.13),
                     (0.208674, 0.076172, 0.24, 1.0, 0.0, 0.34),
                     (0.065671, 0.292581, 0.22, 1.0, 0.0, 0.32),
                     (-0.284437, 0.287983, 0.19, 1.0, 0.0, 0.28),
                     (-0.450423, 0.135194, 0.18, 1.0, 0.0, 0.26),
                     (-0.534559, -0.113047, 0.17, 1.0, 0.0, 0.24),
                     (-0.208674, -0.076172, 0.24, 1.0, 0.0, 0.34),
                     (-0.065671, -0.292581, 0.22, 1.0, 0.0, 0.32),
                     (0.284437, -0.287983, 0.19, 1.0, 0.0, 0.28),
                     (0.450423, -0.135194, 0.18, 1.0, 0.0, 0.26),
                     (0.534559, 0.113047, 0.17, 1.0, 0.0, 0.24)],
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


# Geometri lencana "?" — candidateMarker.
#
# **Kenapa konstanta ini berdiri di sini, di atas pemakainya.** Python
# mengevaluasi nilai bawaan parameter saat fungsi **didefinisikan**, jadi
# `corner_fraction=CANDIDATE_CORNER_FRACTION` hanya sah kalau namanya sudah
# ada. Sebelumnya angka yang sama ditulis dua kali — konstanta di bawah
# berkas, dan bawaan literal di tanda tangan `candidate_marker` — dan yang
# menggambar adalah yang kedua. Gerbang drift membandingkan yang pertama
# dengan model Swift dan hijau, jadi mengubah konstanta itu tidak mengubah
# satu piksel pun: satu angka hidup di dua tempat di dalam satu berkas, dan
# gerbangnya menjaga yang salah. Sekarang hanya ada satu.
CANDIDATE_CORNER_FRACTION = 0.34
CANDIDATE_INSET = 0.06
CANDIDATE_GLYPH_FRACTION = 0.52


def candidate_marker(frame_half_extent=1.0, corner_fraction=CANDIDATE_CORNER_FRACTION,
                     inset=CANDIDATE_INSET,
                     glyph_fraction=CANDIDATE_GLYPH_FRACTION):
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

    def ellipse(self, cx, cy, rx, ry, color_at, alpha=1.0, clip_disc=None):
        def inside(x, y):
            # `clip_disc` = potong ke cakram lain. Dipakai kawah: bibir yang
            # menghadap cahaya digambar sebagai cakram yang digeser, lalu
            # dipotong oleh cakram kawahnya sendiri supaya yang tersisa hanya
            # sabitnya.
            if clip_disc is not None:
                ccx, ccy, cr = clip_disc
                if (x - ccx) ** 2 + (y - ccy) ** 2 > cr * cr:
                    return False
            dx, dy = (x - cx) / rx, (y - cy) / ry
            return dx * dx + dy * dy <= 1.0
        self.fill(inside, color_at, alpha)

    def disc(self, cx, cy, r, color_at, alpha=1.0, clip_disc=None):
        self.ellipse(cx, cy, r, r, color_at, alpha, clip_disc)

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
# MODEL: `CelestialVisual.bandLimbShadingStrength` — pemulihan peredupan limb
# di atas pita. Pita digambar rata, jadi ia menghapus lengkung bola; gradien
# bola digambar ulang di atasnya dengan kekuatan ini.
BAND_LIMB_SHADING_STRENGTH = 0.6
# Nama aturan geometri pita, dipakai `check-visuals.py` untuk menahan kedua
# bahasa agar memakai rumus bola yang sama. Kalau salah satu sisi kembali
# memakai aproksimasi kosinus, nama ini tidak akan ditemukan di sumbernya.
BAND_HALF_WIDTH_RULE = "sqrt"
# Lencana "?" — geometrinya (CANDIDATE_CORNER_FRACTION, CANDIDATE_INSET,
# CANDIDATE_GLYPH_FRACTION) tinggal di atas `candidate_marker()`, satu-satunya
# tempat yang menggambarnya. Dipakai `check_features_disappear_when_uncertain`
# untuk **mengecualikan** daerah lencana dari pengukuran ciri: tanpa
# pengecualian, selisih "terkunci vs ragu" selalu > 0 karena lencananya
# sendiri, sehingga ciri yang **tidak pernah digambar** pun lulus.
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
# Tebal diffraction spike: **pangkal dan ujung**, bukan satu lebar.
#
# Versi sebelumnya punya satu angka (`coreRadius * 0.18`) yang di-stroke
# sebagai `lineWidth` tetap — batang sama tebal dari pangkal ke ujung, yang
# pada ukuran kartu jam terbaca sebagai penanda bidik, bukan cahaya. Sekarang
# tiap spike adalah baji yang menyempit ke ujung; yang dijaga karena itu
# **nisbahnya** (`ujung < pangkal`), bukan satu angka.
SPIKE_ROOT_WIDTH_FACTOR = 0.18    # MODEL: `StarGeometry.spikeRootWidthFactor`
SPIKE_TIP_WIDTH_FACTOR = 0.035    # MODEL: `StarGeometry.spikeTipWidthFactor`
# Pita cincin Saturnus. Batasnya **radius cincin nyata** dalam satuan radius
# Saturnus, dipetakan ke frame oleh `saturn_ring_bands()`; opasitas mengikuti
# kepadatan pita sebenarnya (D sangat tipis, B paling pekat, celah hampir
# kosong). MODEL: `VisualFrame.saturnRingBands`
SATURN_RING_REAL_EDGES = [1.11, 1.236, 1.525, 1.95, 2.025, 2.269]
SATURN_RING_BAND_OPACITIES = [0.14, 0.34, 0.78, 0.04, 0.62]
# MODEL: `VisualFrame.saturnRingBands(cassiniWidth:)` — sengaja lebih lebar
# dari kenyataan supaya masih terbaca di kartu jam. Dibaca oleh
# `saturn_ring_bands()` sebagai bawaan, bukan disalin ke tanda tangannya:
# angka yang ditulis dua kali adalah dua angka yang akan berbeda, dan yang
# menggambar adalah salinan yang tidak dijaga gerbang drift mana pun.
SATURN_CASSINI_WIDTH = 0.06
# MODEL: `CelestialVisual.ringBackHalfOpacityScale`
RING_BACK_HALF_OPACITY_SCALE = 0.55
POLAR_CAP_OPACITY = 0.85                                 # VIEW: `drawPolarCaps`
MARIA_OPACITY = 0.12                                     # VIEW: `drawMoon`
# Kabut Venus: **pusat** elips, satuan radius. MODEL: `CelestialVisual.venusHaze`
# Sebelumnya kedua situs di berkas ini memakai `cy + radius * 0.14` sementara
# view Swift menaruh pusatnya di `center.y` — 0.14 R lebih tinggi. Port dan
# view karena itu menggambar Venus yang berbeda, dan gerbang piksel mengukur
# yang tidak pernah tampil di jam. `check-visuals.py` sekarang menahan
# keduanya terhadap `CelestialVisual.venusHaze`.
VENUS_HAZE_CENTER_Y = 0.0                    # MODEL: `CelestialVisual.venusHaze`
VENUS_HAZE_HALF_WIDTH = 0.55                 # MODEL: `CelestialVisual.venusHaze`
VENUS_HAZE_HALF_HEIGHT = 0.72                # MODEL: `CelestialVisual.venusHaze`
# MODEL: `CelestialVisual.sphereLightOffset` — arah datang cahaya pada bola,
# satuan radius, y positif ke bawah. Dipakai **dua** hal: titik pusat gradien
# bola dan arah bibir terang kawah. Satu konstanta, karena dua salinan angka
# ini berarti kawah yang terangnya menghadap arah yang salah — dan kawah
# terbalik tetap terlihat seperti kawah.
MOON_LIMB_SHADING_STRENGTH = 0.40                    # MODEL: `moonLimbShadingStrength`
# Radius akhir gradien bola Bulan — **bukan 1.35 seperti bola planet**.
# Piringan Bulan diputar sebesar sudut sisi terangnya, jadi pada sabit seluruh
# pita menyala jatuh dekat tepi. Terukur 200 px, kekuatan 0.40: purnama +33.5%
# (1.15) vs +28.5% (1.35), sabit 24.1 vs 20.9. Lihat `moonSphereGradientEndRadius`.
MOON_SPHERE_GRADIENT_END_RADIUS = 1.15               # MODEL: `moonSphereGradientEndRadius`
SPHERE_LIGHT_OFFSET = (-0.32, -0.32)                     # MODEL: `sphereLightOffset`


def moon_sphere_dark(base):
    """`CelestialVisual.moonSphereDark` — ujung gelap gradien bola Bulan."""
    k = 1.0 - min(1.0, max(0.0, MOON_LIMB_SHADING_STRENGTH))
    return (base[0] * k, base[1] * k, base[2] * k)
# MODEL: `CelestialVisual.craterRelief` — kekuatan bibir & kedalaman dasar.
CRATER_RIM_STRENGTH = 0.55                               # MODEL: `craterRelief`
CRATER_FLOOR_DEPTH = 0.22                                # MODEL: `craterRelief`
# VIEW: `drawCraters` — opasitas lapisan kawah, urut sesuai penggambarannya.
#
# **Kenapa tidak ada `CRATER_FLOOR_OPACITY` di sini.** Dulu ada, bernilai 0.85,
# dan dipakai sebagai kelegapan cakram dasar kawah — padahal model sudah
# menghitung `floor_depth` per kawah dan mendokumentasikan dirinya sendiri
# sebagai "dipakai sebagai kelegapan lapisan hitam". Konstanta itu menutupi
# nilai model (0.85 adalah 3,9× kedalaman maksimum 0.22), sehingga sabit bibir
# yang membuat kawah terbaca **cekung** tenggelam di bawahnya: kawahnya
# tergambar sebagai cakram gelap rata, bukan cekungan. Sekarang kelegapan
# dasar diambil langsung dari `floor_depth`, dan tidak ada konstanta tetap
# yang bisa menyimpang dari model lagi.
CRATER_RIM_OPACITY = 0.90                                # VIEW: `drawCraters`
CRATER_INNER_FLOOR_OPACITY = 0.75                        # VIEW: `drawCraters`
CRATER_RIM_OFFSET = 0.45                                 # VIEW: `drawCraters`
CRATER_INNER_SCALE = 0.5                                 # VIEW: `drawCraters`


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
    """Port dari `.radialGradient(Gradient(stops:), center:startRadius:endRadius:)`.

    Menerima dua bentuk entri, supaya **kedua** varian SwiftUI bisa dinyatakan:

      - `(rgb, alpha)` — `Gradient(colors:)`, stop tersebar **merata**
        sepanjang rentang radius.
      - `(location, rgb, alpha)` — `Gradient(stops:)`, stop di lokasi yang
        **ditentukan** (0…1, seperti `Gradient.Stop.location`).

    **Kenapa bentuk kedua ada.** Versi sebelumnya hanya menerima bentuk
    pertama dan menyebarkan stop secara merata. Untuk gradient yang stopnya
    memang berjarak sama itu kebetulan benar — dan itulah sebabnya cacat ini
    tidak pernah terlihat sampai ada gradient pertama di proyek ini yang
    stopnya **tidak** merata: profil Matahari, yang punya batas fotosfer tegas
    di 0.72 R. Dengan penyebaran merata, port menggambar profil itu dengan
    alpha 0.13 di 0.72 R sementara SwiftUI menggambarnya 0.94 — jadi gerbang
    piksel mengukur Matahari yang **tidak pernah tampil di jam**, dan
    perbaikannya akan dilaporkan sebagai "tidak berpengaruh" apa pun hasilnya.
    """
    cx, cy = center
    span = end_radius - start_radius

    if colors and len(colors[0]) == 3:
        stops = sorted(((float(loc), rgb, float(a)) for loc, rgb, a in colors),
                       key=lambda s: s[0])
    else:
        pairs = list(colors)
        n = len(pairs) - 1
        stops = [(0.0 if n <= 0 else i / n, rgb, a)
                 for i, (rgb, a) in enumerate(pairs)]

    def at(x, y):
        d = math.hypot(x - cx, y - cy)
        t = 0.0 if span <= 0 else min(1.0, max(0.0, (d - start_radius) / span))
        if t <= stops[0][0]:
            return stops[0][1], stops[0][2]
        if t >= stops[-1][0]:
            return stops[-1][1], stops[-1][2]
        for i in range(len(stops) - 1):
            l0, c0, a0 = stops[i]
            l1, c1, a1 = stops[i + 1]
            if t <= l1:
                frac = 0.0 if l1 <= l0 else (t - l0) / (l1 - l0)
                rgb = tuple(c0[k] + (c1[k] - c0[k]) * frac for k in range(3))
                return rgb, a0 + (a1 - a0) * frac
        return stops[-1][1], stops[-1][2]
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


def _draw_sphere(canvas, cx, cy, radius, light, dark, night_mode, opacity=1.0):
    """`drawSphere` — gradien bola, cahaya dari kiri-atas.

    `opacity` dipakai **dua** pemanggil dan keduanya harus memakai gradien yang
    sama persis: `_draw_planet` menggambar bola, lalu `_draw_bands`
    menggambarnya **lagi** di atas pita untuk memulihkan lengkung yang tadi
    terhapus pita (lihat `_draw_bands`). Karena yang ditumpuk adalah gradien
    yang sama, daerah di luar pita tidak berubah sama sekali.
    """
    gradient = radial_gradient(
        [(light if not night_mode else night_surface(light), 1.0 * opacity),
         (dark if not night_mode else night_surface(dark), 1.0 * opacity)],
        center=(cx + radius * SPHERE_LIGHT_OFFSET[0],
                cy + radius * SPHERE_LIGHT_OFFSET[1]),
        start_radius=radius * 0.1, end_radius=radius * 1.35)
    canvas.disc(cx, cy, radius, gradient)


def _draw_planet(canvas, cx, cy, radius, kw, night_mode):
    planet = kw.get("planet")
    if planet is None:
        _draw_sphere(canvas, cx, cy, radius, NEUTRAL_BODY, NEUTRAL_SHADOW, night_mode)
        return
    palette = PLANET_PALETTE[planet]

    # **Fase planet dalam (Venus, Merkurius).** Sama dengan view Swift: bila
    # fase-nya diketahui dan objeknya sudah terkunci, piringan digambar
    # sebagai bagian yang menyala + bagian gelap, bukan bola penuh. Tanpa
    # cabang ini, port menggambar bola penuh sementara aplikasi menggambar
    # sabit — dan setiap pemeriksaan yang mengukur gambar planet dalam akan
    # mengukur gambar yang tidak pernah ada.
    phase = None
    if planet_shows_phase(planet) and kw.get("is_confirmed") is not False:
        phase = phase_geometry(planet_phase_fraction(planet, kw.get("illumination")),
                               kw.get("is_waxing"))
    if phase is not None:
        unlit = ACCENTS["planetUnlit"]
        canvas.disc(cx, cy, radius, shadow_fn(unlit, night_mode))
        points, to_screen = _lit_band_polygon(cx, cy, radius, phase,
                                              kw.get("bright_limb_angle"))

        def inside_lit(x, y):
            if math.hypot(x - cx, y - cy) > radius:
                return False
            return _point_in_polygon(x, y, points)

        # Gradien peredupan limb **berpusat di pusat piringan**, bukan digeser
        # ke kiri-atas seperti bola penuh: gradien yang digeser ikut berputar
        # bersama pita, sehingga "cahaya dari kiri-atas" menghadap arah yang
        # salah begitu sisi terangnya ke bawah.
        light = palette["light"] if not night_mode else night_surface(palette["light"])
        dark = palette["dark"] if not night_mode else night_surface(palette["dark"])
        gradient = radial_gradient([(light, 1.0), (dark, 1.0)],
                                   center=(cx, cy),
                                   start_radius=0.0, end_radius=radius * 1.15)

        def limb_shaded(x, y):
            return inside_lit(x, y)
        canvas.fill(limb_shaded, gradient)

        feature = palette["feature"]
        if feature == "craters":
            # Ciri pengenal ikut terpotong ke bagian piringan yang menyala,
            # jadi kawah tidak pernah menonjol keluar dari sabit.
            _draw_craters(canvas, cx, cy, radius, night_mode,
                          inside_lit=lambda x, y: _point_in_polygon(x, y, points))
        elif feature == "haze":
            haze = ACCENTS["venusHaze"]
            rgb = night_surface(haze) if night_mode else haze
            gradient = linear_gradient([(rgb, 0.0), (rgb, 0.7)],
                                       start_point=(cx, cy - radius),
                                       end_point=(cx, cy))

            def haze_clipped(x, y):
                # Di luar pita yang menyala: alfa nol, bukan warna yang
                # berbeda — supaya kabutnya tidak pernah menonjol keluar dari
                # sabit dan membuatnya tampak lebih lebar daripada fraksi yang
                # dihitung engine.
                if not _point_in_polygon(x, y, points):
                    return (rgb, 0.0)
                return gradient(x, y)
            center_y, half_w, half_h = venus_haze()
            canvas.ellipse(cx, cy + radius * center_y, radius * half_w, radius * half_h, haze_clipped)
        return

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
        _draw_bands(canvas, cx, cy, radius, night_mode, palette)
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


def band_half_width(height):
    """Port `CelestialVisual.bandHalfWidthAt(height:)` — tepi bola di ketinggian.

    Satu rumus bola (`sqrt(1 - y^2)`), dipakai bersama view, port, dan uji
    Linux. **Tandanya berarti**: `height` negatif = belahan utara layar, dan
    itulah yang menentukan sisi mana yang lebih dalam. Lihat
    `CelestialVisual.bandHalfWidthAt(height:)` untuk cacat yang ditutupnya.
    """
    return math.sqrt(max(0.0, 1 - height * height))


def _draw_bands(canvas, cx, cy, radius, night_mode, palette=None):
    for index, (band_y, half_width, half_height) in enumerate(jupiter_bands()):
        y = cy + band_y * radius
        if half_width * radius <= 1:
            continue
        # **Pita digambar sebagai tali busur, bukan elips.** Tepi pita
        # mengikuti busur limb: pada ketinggian `yc ± half_height` bola sudah
        # menyempit, sementara elips mempertahankan lebarnya sampai ujung.
        # Diukur sebagai IoU pada render 200 px, elips hanya menutupi 79%
        # pita yang benar. Ketinggiannya **bertanda** — memulihkannya dengan
        # `sqrt(1 - hw^2)` kehilangan sisi, dan pita utara jadi miring ke arah
        # yang salah.
        # MODEL: `CelestialVisual.bandHalfWidthAt(height:)`
        top = cx + radius * band_half_width(band_y - half_height)
        bottom = cx + radius * band_half_width(band_y + half_height)
        half_h = radius * half_height
        points = [(cx - (top - cx), y - half_h), (top, y - half_h),
                  (bottom, y + half_h), (cx - (bottom - cx), y + half_h)]
        name = ("jupiterBandTan", "jupiterBandRust", "jupiterBandCream")[index % 3]
        canvas.polygon(points, accent_fn(ACCENTS[name], night_mode, BAND_OPACITY))
    # **Restorasi peredupan limb.** Pita di atas digambar sebagai **tali
    # busur** warna rata, jadi tiap pita menghapus lengkung bola di bawahnya. Diukur pada
    # baris ekuator render 200 px: selisih terang pusat-ke-limb turun dari
    # 50.6% (bola polos) ke 20.8% (bola ber-pita), dan pada 0.96 R pitanya
    # justru +62.6 lebih terang daripada bola tanpa pita. Yang terlihat karena
    # itu bukan bola berpita, melainkan **stiker rata** di atas piringan.
    #
    # Yang dipakai kembali adalah **gradien bola yang sama persis** — pusat,
    # warna, dan radius yang sama seperti `_draw_planet` di atas. Dua akibat,
    # dan keduanya yang membuat cara ini dipilih daripada \"gelapkan pita di
    # tepi\": (1) di daerah yang tidak tertutup pita gradien ini menumpuk di
    # atas dirinya sendiri, dan itu identitas — jadi piksel di luar pita tidak
    # berubah sama sekali; (2) arah cahayanya tidak bisa berbeda pendapat
    # dengan bolanya, karena keduanya membaca `SPHERE_LIGHT_OFFSET` yang sama.
    # MODEL: `CelestialVisual.bandLimbShadingStrength`
    if palette is not None:
        # Tidak ada klip tambahan yang perlu: `_draw_sphere` mengisi cakram
        # dengan radius yang sama persis, jadi bentuknya sudah terbatas pada
        # piringan. Menambahkan klip di sini hanya akan menambah satu operasi
        # yang tidak mengubah apa pun — dan satu lagi yang bisa berbeda dari
        # sisi Swift-nya.
        _draw_sphere(canvas, cx, cy, radius, palette["light"], palette["dark"],
                     night_mode, opacity=BAND_LIMB_SHADING_STRENGTH)
    dx, dy = SPOT_CENTER
    w, h = SPOT_SIZE
    canvas.ellipse(cx + dx * radius, cy + dy * radius,
                   w * radius / 2.0, h * radius / 2.0,
                   accent_fn(ACCENTS["jupiterSpot"], night_mode))


def saturn_ring_bands(body_fraction=0.53, cassini_width=SATURN_CASSINI_WIDTH):
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
    """Kutub = elips selebar tepi bola, **diiris dengan piringan**.

    Irisan itu bukan hiasan: elips selebar tepi bola pada `north_center`
    tetap menjulur keluar bola di baris lain (pada y = -0.9 R lebarnya
    0.530 R, bola hanya 0.436 R). Tanpa irisan, kutubnya meluber ke latar.
    """
    caps = polar_caps()
    cap = accent_fn(ACCENTS["marsPolarCap"], night_mode, POLAR_CAP_OPACITY)
    erx = caps["half_width"] * radius
    ery = caps["half_height"] * radius
    for center in (caps["north_center"], caps["south_center"]):
        ecy = cy + center * radius

        def inside(x, y, ecy=ecy):
            if (x - cx) ** 2 + (y - cy) ** 2 > radius * radius:
                return False
            dx, dy = (x - cx) / erx, (y - ecy) / ery
            return dx * dx + dy * dy <= 1.0

        canvas.fill(inside, cap)


def crater_relief(craters, light_direction=SPHERE_LIGHT_OFFSET,
                  strength=CRATER_RIM_STRENGTH, depth=CRATER_FLOOR_DEPTH):
    """`CelestialVisual.craterRelief` — arah & kekuatan bayangan tiap kawah.

    Mengembalikan `(cx, cy, radius, rim_x, rim_y, rim_strength, floor_depth)`
    per kawah. Arah bibir terang **selalu** menghadap sumber cahaya
    (`-light`), untuk semua kawah: Matahari praktis tak terhingga jauhnya
    dibanding lebar piringan, jadi vektor cahayanya sama di seluruh
    permukaan. Yang berkurang di sisi gelap adalah kontrasnya, bukan
    arahnya — kawah dengan bibir terbalik tetap terbaca sebagai kawah,
    hanya terbaca menonjol keluar, jadi ini dihitung, bukan dilihat.
    """
    length = math.hypot(light_direction[0], light_direction[1])
    if length <= 1e-9:
        return []
    lx, ly = light_direction[0] / length, light_direction[1] / length
    out = []
    for dx, dy, size in craters:
        distance = min(1.0, math.hypot(dx, dy))
        alignment = dx * lx + dy * ly
        fade = 0.6 + 0.4 * alignment
        limb = 1 - 0.6 * distance
        out.append((dx, dy, size, -lx, -ly,
                    strength * fade * limb, depth * (1 - 0.5 * distance)))
    return out


def _draw_craters(canvas, cx, cy, radius, night_mode, inside_lit=None):
    """`CelestialVisualView.drawCraters` — cekungan tiga lapisan.

    Satu cakram gelap rata tidak cukup: di ukuran sebenarnya di jam (38 pt,
    76 px @2x) hasilnya terbaca sebagai **stiker abu-abu yang ditempel**,
    bukan permukaan berkawah. Cekungan terbaca sebagai cekungan karena ia
    punya dua dinding yang berlawanan terang-gelap. Jadi: seluruh cakram
    dinaungi, lalu **sabit** bibir yang menghadap cahaya di atasnya, lalu
    dasar yang lebih gelap di tengah.

    `inside_lit` dipakai oleh planet berfase: ciri pengenalnya harus ikut
    terpotong ke bagian piringan yang menyala, jadi kawah tidak pernah
    menonjol keluar dari sabit.
    """
    # `accent_fn` (bukan `color_fn` + `solid`): keduanya sudah mengembalikan
    # fungsi `(x, y) -> (rgb, alpha)`, dan yang menentukan terangnya adalah
    # aturan **permukaan** — sama dengan `Self.accent(...)` di view.
    def clipped(fn):
        # `color_at` selalu dipanggil sebagai fungsi `(x, y) -> (rgb, alpha)`;
        # jadi pembungkusnya meneruskan panggilan itu, bukan mengembalikan
        # `fn` yang belum dipanggil.
        if inside_lit is None:
            return fn
        return lambda x, y: fn(x, y) if inside_lit(x, y) else ((0.0, 0.0, 0.0), 0.0)

    for dx, dy, size, rim_x, rim_y, rim_strength, floor_depth in crater_relief(CRATERS):
        mx, my = cx + dx * radius, cy + dy * radius
        mr = size * radius
        # 1. Seluruh cakram dinaungi (dasar cekungan). Kelegapannya **bukan**
        #    angka tetap: `floor_depth` dari model adalah kedalaman cekungan
        #    ini, dan model mendokumentasikan dirinya sendiri sebagai "dipakai
        #    sebagai kelegapan lapisan hitam" (`CraterRelief.floorDepth`).
        #    Selama baris ini menulis konstanta tetap, nilai model itu
        #    dihitung lalu dibuang — dan kawahnya tergambar sebagai cakram
        #    gelap rata, bukan cekungan.
        canvas.disc(mx, my, mr,
                    clipped(accent_fn(ACCENTS["craterFloor"], night_mode, floor_depth)))
        # 2. Bibir yang menghadap cahaya: cakram yang digeser ke arah sumber
        #    cahaya, dipotong oleh cakram kawah — yang tersisa hanya sabit.
        #    `offset` dibuat cukup besar (≈0.45·mr) supaya sabitnya terlihat
        #    di ukuran jam 76 px; terlalu kecil ia tertelan dasar cakram.
        #
        #    Faktor diambil dari konstanta, bukan ditulis ulang sebagai angka:
        #    `CRATER_RIM_OFFSET` pernah bernilai 0,55 — menyimpang dari diskret
        #    view — dan **tidak pernah dirujuk**, sehingga angka yang benar
        #    (0,45) ditulis tangan di sini. Tidak ada yang bisa melihatnya.
        offset = mr * CRATER_RIM_OFFSET
        canvas.disc(mx + rim_x * offset, my + rim_y * offset, mr * 0.92,
                    clipped(accent_fn(ACCENTS["craterRim"], night_mode,
                                      min(1.0, CRATER_RIM_OPACITY * max(rim_strength, 0.2)))),
                    clip_disc=(mx, my, mr))
        # 3. Dasar yang lebih gelap di tengah, jelas di dalam sabit bibirnya.
        canvas.disc(mx, my, mr * CRATER_INNER_SCALE,
                    clipped(accent_fn(ACCENTS["craterFloor"], night_mode,
                                      CRATER_INNER_FLOOR_OPACITY)))


def venus_haze():
    """Port dari `CelestialVisual.venusHaze()` — geometri kabut Venus.

    Mengembalikan `(center_y, half_width, half_height)` dalam satuan radius.

    **Kenapa fungsinya ada, bukan dua kali angka.** Kedua situs di berkas ini
    pernah memakai `cy + radius * 0.14` sementara view Swift menaruh pusatnya
    di `center.y`. Port dan view karena itu menggambar Venus yang **berbeda**,
    dan seluruh gerbang piksel untuk Venus berfase mengukur gambar yang tidak
    pernah tampil di jam. `check-visuals.py` menahan fungsi ini dan view
    terhadap `CelestialVisual.venusHaze` supaya pergeserannya tidak bisa
    terulang tanpa suara.
    """
    return VENUS_HAZE_CENTER_Y, VENUS_HAZE_HALF_WIDTH, VENUS_HAZE_HALF_HEIGHT


def _draw_haze(canvas, cx, cy, radius, night_mode):
    haze = ACCENTS["venusHaze"]
    rgb = night_surface(haze) if night_mode else haze
    gradient = linear_gradient([(rgb, 0.0), (rgb, 0.7)],
                               start_point=(cx, cy - radius),
                               end_point=(cx, cy))
    center_y, half_w, half_h = venus_haze()
    canvas.ellipse(cx, cy + radius * center_y, radius * half_w, radius * half_h, gradient)


def _lit_band_polygon(cx, cy, radius, phase, bright_limb_angle):
    """Poligon pita terang, sudah diputar — port dari `drawLitBand`.

    Dipakai bersama Bulan dan planet berfase supaya keduanya digambar oleh
    rumus yang sama; kalau tidak, dua salinan kurva akan cepat atau lambat
    berbeda, dan yang salah tetap tampak seperti sabit yang meyakinkan.
    """
    lit_side = phase["lit_side"]
    offset = phase["terminator_offset"]
    rotate = draw_rotation_radians(terminator_rotation_radians(bright_limb_angle, phase))
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
    return points, to_screen


def _moon_sphere_gradient(cx, cy, radius, base, night_mode, is_shadow=False):
    """Gradien bola piringan Bulan — **berpusat di pusat piringan**.

    Kenapa pusat, bukan digeser ke arah cahaya seperti `_draw_sphere`: piringan
    berfase digambar di dalam `drawLayer` yang **diputar** sebesar sudut sisi
    terang. Gradien yang digeser ikut berputar bersama pita, sehingga "cahaya
    dari kiri-atas" menghadap arah yang salah begitu sisi terangnya ke bawah —
    persis alasan yang sudah tertulis di `_draw_planet` untuk planet dalam.
    Gradien terpusat tidak punya arah, jadi ia kebal terhadap putaran itu, dan
    arah cahaya Bulan memang sudah dinyatakan oleh **terminatornya**.

    Radius akhirnya dibaca dari `MOON_SPHERE_GRADIENT_END_RADIUS` (1.15), bukan
    1.35 seperti bola planet: pada sabit, pita menyala jatuh dekat tepi
    piringan, dan gradien yang lebih dalam membuatnya nyaris rata lagi.
    """
    dark = moon_sphere_dark(base)
    color = (lambda c: night_shadow(c) if night_mode else c) if is_shadow \
        else (lambda c: night_surface(c) if night_mode else c)
    return radial_gradient([(color(base), 1.0), (color(dark), 1.0)],
                           center=(cx, cy), start_radius=0.0,
                           end_radius=radius * MOON_SPHERE_GRADIENT_END_RADIUS)


def _fill_moon_sphere(canvas, cx, cy, radius, base, night_mode, is_shadow=False):
    """Isi cakram Bulan sebagai bola. Lihat `moonLimbShadingStrength`."""
    canvas.disc(cx, cy, radius,
                _moon_sphere_gradient(cx, cy, radius, base, night_mode, is_shadow))


def _draw_moon(canvas, cx, cy, radius, kw, night_mode):
    unlit = ACCENTS["moonUnlit"]
    phase = phase_geometry(kw.get("illumination"), kw.get("is_waxing"))
    if phase is None:
        # **Fase tidak diketahui: piringan abu netral, bukan piringan gelap.**
        # Versi lama menggambar `moonUnlit` lalu berhenti, dan hasilnya
        # identik piksel demi piksel dengan bulan baru -- gambar yang
        # menyatakan "bulan baru" setiap kali efemeris gagal. Lihat
        # `moonPhaseUnknown` di `NightVisual.swift`.
        unknown = ACCENTS["moonPhaseUnknown"]
        # **Bola, bukan cakram rata.** Lihat `moonLimbShadingStrength`: tanpa
        # gradien ini seluruh piringan Bulan terukur rata 0.0% sementara planet
        # di sebelahnya melengkung 55%.
        _fill_moon_sphere(canvas, cx, cy, radius, unknown, night_mode)
        return
    canvas.disc(cx, cy, radius, shadow_fn(unlit, night_mode))
    # **Piringan gelap sengaja tetap rata.** Percobaan memberi gradien bola di
    # sini diukur dan dibuang, dengan dua alasan:
    #
    #   1. Earthshine dilukis di bawah sebagai cakram warna **rata** di atas
    #      seluruh piringan, jadi gradiennya terhapus justru di fase tempat
    #      sisi gelap paling terlihat. Terukur pada 200 px, ss=2: `moon-new`
    #      tetap +0.0% pada **setiap** kekuatan 0…0.80.
    #   2. Memperdalamnya mematikan gerbang `check_earthshine` pada kekuatan
    #      0.20 (4/5 lulus, yang merah tepat "sisi gelap sabit lebih terang
    #      dari piringan gelap") — karena gerbang itu memakai luminans rata
    #      sliver terjauh kiri sebagai ukuran earthshine, dan peredupan limb
    #      menurunkannya.
    #
    # Dan itu memang gambar yang benar: sisi gelap Bulan disinari Bumi, sumber
    # yang **lebar**, jadi piringan rata di sana bukan kesalahan — sedangkan
    # pita terangnya disinari sumber titik. Lihat `moonLimbShadingStrength`.
    # Earthshine: sisi gelap Bulan yang disinar Bumi. Kekuatan mengikuti
    # `1 - f` (sama seperti `CelestialVisual.earthshineStrength` di Swift),
    # jadi nol saat purnama (f = 1) dan paling kuat saat sabit tipis. Dilukis
    # sebelum pita terang supaya hanya terlihat di sisi gelap.
    f = kw.get("illumination")
    if f is not None and f < 1.0:
        strength = 1.0 - f
        es = ACCENTS["moonEarthshine"]
        # Aturan `shadow`, sama seperti piringan gelap `moonUnlit` di atas:
        # earthshine memantulkan cahaya yang **tidak memancar sendiri**, jadi
        # ia mengikuti aturan bayangan, bukan aturan permukaan. Versi lama
        # memakai `night_surface`, yang menaikkan kanal merah ke 0.4475 —
        # enam kali `night_shadow` yang 0.075. Cacatnya tidak terlihat di
        # layar siang (jalur itu dikunci `if night_mode`), dan tidak terlihat
        # di gerbang mana pun: `check_earthshine` merender dengan
        # `night_mode=False`, sementara `check_night_mode_purity` hanya menyapu
        # hijau/biru — sedangkan 0.4475 di kanal merah adalah merah murni,
        # murni.
        es_rgb = night_shadow(es) if night_mode else es
        earth = lambda x, y, c=es_rgb, s=strength: (c, s)
        canvas.disc(cx, cy, radius, earth)
    points, to_screen = _lit_band_polygon(cx, cy, radius, phase,
                                          kw.get("bright_limb_angle"))

    lit_color = ACCENTS["moonLit"]
    # Warna "tidak menggambar apa-apa" untuk maria di luar pita (alfa 0).
    lit_rgb = night_surface(lit_color) if night_mode else lit_color

    def inside_lit(x, y):
        if math.hypot(x - cx, y - cy) > radius:
            return False
        return _point_in_polygon(x, y, points)
    # Pita terang digambar sebagai **bola**, bukan warna rata: tanpa gradien
    # ini piringan Bulan terukur rata 0.0% sementara planet melengkung 55%.
    canvas.fill(inside_lit,
                _moon_sphere_gradient(cx, cy, radius, lit_color, night_mode))

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
    # Lebar **penuh** dibagi dua: `SPIKE_ROOT_WIDTH_FACTOR` memakai angka yang
    # sama dengan `lineWidth` lama, jadi ia lebar penuh — bukan setengah.
    root_half = core_radius * SPIKE_ROOT_WIDTH_FACTOR * 0.5 * pulse_factor
    tip_half = core_radius * SPIKE_TIP_WIDTH_FACTOR * 0.5 * pulse_factor
    # VIEW: `drawStar` menggambar **baji** per spike (menyempit + memudar),
    # bukan satu `Path` yang di-stroke. Dijaga sama supaya gerbang piksel di
    # bawahnya mengukur bentuk yang benar-benar tampil di jam.
    for dx, dy in ((1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)):
        tip = (cx + dx * spike, cy + dy * spike)
        px, py = -dy, dx
        canvas.polygon([(cx + px * root_half, cy + py * root_half),
                        (tip[0] + px * tip_half, tip[1] + py * tip_half),
                        (tip[0] - px * tip_half, tip[1] - py * tip_half),
                        (cx - px * root_half, cy - py * root_half)],
                       radial_gradient([(color, SPIKE_OPACITY), (color, 0.0)],
                                       center=(cx, cy), start_radius=0,
                                       end_radius=spike))


def sun_profile(core, photosphere):
    """`VisualFrame.sunProfile(core:photosphere:)` — **satu** gradient, bukan
    dua piringan.

    Mengembalikan larik (radius_fraction, rgb, opacity). Opasitasnya turun
    monoton, dan batas fotosfer di 0.72 R **bukan** tempat kelegapan terjun:
    stop 0.72 R hanya turun 0.05 dari stop sebelumnya, supaya tepi keras yang
    lama (1.0 -> 0.42 dalam satu piksel) tidak kembali; lihat catatan cacatnya
    di sumber Swift.

    **Angka-angka ini bukan pilihan bebas.** Ia harus sama dengan
    `VisualFrame.sunProfile` di `CelestialVisual.swift`; kalau tidak, seluruh
    gerbang piksel di bawahnya mengukur Matahari yang tidak pernah tampil di
    jam. Kesamaannya tidak dijaga komentar melainkan
    `check_sun_profile_matches_the_model`, karena versi pertama port ini
    memang menyimpang (0.94/0.62/0.30/0.10 lawan 0.95/0.66/0.34/0.13) dan
    tidak ada satu pun pemeriksaan yang berbunyi.
    """
    return [(0.00, core, 1.00),
            (0.55, core, 1.00),
            (0.72, core, 0.95),
            (0.80, core, 0.66),
            (0.88, photosphere, 0.34),
            (0.94, photosphere, 0.13),
            (1.00, photosphere, 0.00)]


def _draw_sun(canvas, cx, cy, radius, kw, night_mode):
    core = ACCENTS["sunCore"]
    photo = ACCENTS["sunPhotosphere"]
    core_rgb = night_surface(core) if night_mode else core
    photo_rgb = night_surface(photo) if night_mode else photo
    # Inti putih hanya di mode terang — sama dengan `drawSun` di view.
    inner = core_rgb if night_mode else (1.0, 1.0, 1.0)
    stops = sun_profile(core_rgb, photo_rgb)
    # Lokasi stop ikut dikirim: `radial_gradient` menerima bentuk
    # `(location, rgb, alpha)` untuk `Gradient(stops:)`. Tanpa lokasi, port
    # menyebarkan stop merata dan batas fotosfer 0.72 R hilang.
    stops = [(r, (inner if r == 0.0 else c), a) for (r, c, a) in stops]
    canvas.disc(cx, cy, radius,
                radial_gradient(stops, center=(cx, cy), start_radius=0,
                                end_radius=radius))


def _draw_deep_sky(canvas, cx, cy, radius, kw, night_mode):
    morphology = kw.get("morphology") if kw.get("is_confirmed", True) else None
    # MODEL: `CelestialVisual.deepSkyColour(for:)` — warna mengikuti morfologi
    # yang **boleh diklaim**. `morphology` di sini sudah `None` saat belum
    # terkunci, jadi warna morfologi tidak pernah muncul di kartu ragu.
    core = ACCENTS[DEEP_SKY_COLOUR_KEY.get(morphology or "", "deepSky")]
    core_rgb = night_surface(core) if night_mode else core
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

    # Fase planet dalam. Venus dan Merkurius berfase sungguhan, dan sampai
    # siklus ini keduanya digambar sebagai bola penuh — gambar yang menyatakan
    # sesuatu yang tidak ada di langit. Kasus-kasus ini yang membuat
    # perbaikannya terukur, bukan hanya diklaim: satu sabit tipis, satu
    # cembung, satu tanpa arah, dan satu **planet luar dengan angka fase**
    # yang harus diabaikan (Mars tidak pernah tampak berfase).
    for label, planet, fraction, waxing, angle, note in (
        ("venus-crescent", "venus", 0.22, True, -math.pi / 2,
         "Venus sabit — sisi terang ke BAWAH, seperti sabit muda"),
        ("venus-gibbous", "venus", 0.78, True, 0.0,
         "Venus cembung — pita lebar, terminator lewat pusat"),
        ("venus-no-direction", "venus", 0.4, None, 0.0,
         "Venus tanpa arah fase — piringan polos, TIDAK memihak sisi"),
        ("mercury-crescent", "mercury", 0.3, True, 0.0,
         "Merkurius sabit — kawah terpotong ke bagian yang menyala"),
        ("mars-with-a-phase-number", "mars", 0.3, True, 0.0,
         "Mars dengan angka fase — harus DIABAIKAN (planet luar tak berfase)"),
    ):
        cases.append(VisualCase(f"planet-{label}", note, "planet", planet=planet,
                                illumination=fraction, is_waxing=waxing,
                                bright_limb_angle=angle, is_confirmed=True))

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
                        ("planetaryNebula", "nebula planetari (M27/M57)"),
                        ("galaxy", "galaksi (M31/M33) — cakram miring"),
                        ("spiralGalaxy", "galaksi berlengan (M51/M101)"),
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
