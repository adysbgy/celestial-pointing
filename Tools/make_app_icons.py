#!/usr/bin/env python3
"""Hasilkan ikon app (PNG) + Contents.json untuk katalog aset Xcode.

Kenapa digenerate, bukan disimpan sebagai biner: ikon harus ada supaya
`actool` tidak menggagalkan build, dan berkas PNG biner tidak bisa ditinjau
lewat diff. Skrip ini deterministik — gambar yang sama selalu menghasilkan
berkas yang sama, jadi bisa dijalankan ulang kapan saja.

Satu gambar 1024x1024 per app, bukan dua puluh ukuran. Sejak Xcode 14, katalog
aset hanya butuh satu gambar sumber; Xcode menurunkan ukuran lainnya sendiri.
Daftar ukuran lama (22pt, 24pt, 29pt, …) justru menghasilkan peringatan
"unassigned children" karena slot-slotnya sudah tidak dipakai lagi.

**Kenapa ikonnya diganti (22 Okt 2026).** Versi sebelumnya adalah bidang
bintang acak: 140 titik tersebar merata di atas gradien, tanpa satu pun bentuk
utama. Diukur pada berkas yang di-commit saat itu — hanya **6,0 persen** massa
terang berada di dekat pusat (r < 0,30), dan tidak ada puncak kecerahan di
cincin mana pun. Itu bukan selera: ikon app adalah permukaan pertama yang
dilihat pengguna, dan pada 40 pt bidang titik acak kehilangan seluruh
detailnya lalu terbaca sebagai kotak abu-abu. Tidak ada gerbang yang
mengukurnya, jadi bentuk itu bertahan melewati 99 aturan UI dan 1317 uji.

Yang menggantikannya bukan hiasan, melainkan **satu bentuk utama**: planet
bercincin, digambar prosedural dengan pencahayaan dari kiri-atas. Cincin
dipilih karena siluetnya satu-satunya yang masih terbaca sebagai "astronomi"
ketika tingginya tinggal 40 piksel — dan karena ia benda yang benar-benar
ditampilkan app ini, bukan lambang generik.

Pakai:
    python3 Tools/make_app_icons.py            # tulis kedua appiconset
    python3 Tools/make_app_icons.py --preview  # hanya PNG pratinjau
"""

from __future__ import annotations

import argparse
import json
import math
import os
import struct
import zlib

# ── Palet ──────────────────────────────────────────────────────────────────
#
# Latar memakai dua warna permukaan yang sama dengan app (#0A0A0F → #121216),
# supaya ikon dan layar pertama tidak terlihat berasal dari produk berbeda.
# Warna planet sengaja jauh lebih terang daripada latar: satu-satunya kontras
# yang tersisa pada 40 pt adalah kontras bentuk, bukan detail.
BG_TOP = (10, 10, 15)
BG_BOTTOM = (18, 18, 22)
NEBULA = (58, 72, 138)
BAND_LIGHT = (233, 216, 181)
BAND_MID = (196, 158, 114)
BAND_DARK = (136, 98, 66)
BAND_DEEP = (98, 68, 48)
RING_NEAR = (222, 205, 172)
RING_FAR = (150, 136, 116)
RING_SHADOWED = (58, 48, 40)
STAR = (222, 233, 255)

# ── Geometri ───────────────────────────────────────────────────────────────
#
# Planet mengisi ~47 persen lebar; cincin ~87 persen. Sisanya margin, karena
# iOS memotong ikon menjadi superellipse — bentuk yang menyentuh tepi akan
# kehilangan siluetnya di sudut.
PLANET_RADIUS = 0.252
RING_INNER = 1.28
RING_OUTER = 1.86
RING_TILT_DEG = -17.0
RING_SQUASH = 0.30
CENTRE = (0.5, 0.505)

# Pergeseran bayangan cincin di piringan planet, dalam koordinat cakram
# (satuan radius planet). Arahnya **berlawanan** dengan arah datang cahaya:
# cincin menghalangi cahaya dari kiri-atas, jadi bayangannya jatuh ke
# kanan-bawah. Tanpa pergeseran ini bayangan menempel tepat di bawah cincin
# dan terbaca sebagai pita gelap yang dicat, bukan sebagai bayangan.
RING_SHADOW_OFFSET = 0.26

# Ukuran sumber tunggal untuk kedua platform.
SOURCE_SIZE = 1024


def _png(width: int, height: int, pixels: bytes) -> bytes:
    """Bungkus data RGBA mentah menjadi berkas PNG."""
    raw = b"".join(
        b"\x00" + pixels[y * width * 4 : (y + 1) * width * 4] for y in range(height)
    )

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def _stars(count: int, size: int, seed: int = 20261022):
    """Bintang deterministik: LCG sederhana supaya hasilnya bisa diulang.

    **Semua bintang berada di luar `STAR_CLEAR_RADIUS`.** Bukan demi
    kerapian: bintang yang boleh jatuh di atas piringan planet membuat massa
    terang menyebar lagi, dan itulah cacat ikon lama. Bentuk utama harus
    memegang pusat gambar sendirian.
    """
    state = seed
    out = []
    cx, cy = CENTRE[0] * size, CENTRE[1] * size
    clear = STAR_CLEAR_RADIUS * size
    while len(out) < count:
        state = (1103515245 * state + 12345) % (2**31)
        x = state / (2**31)
        state = (1103515245 * state + 12345) % (2**31)
        y = state / (2**31)
        state = (1103515245 * state + 12345) % (2**31)
        r = state / (2**31)
        px, py = x * size, y * size
        if (px - cx) ** 2 + (py - cy) ** 2 < clear * clear:
            continue
        out.append((px, py, 0.9 + r * 2.1))
    return out


# Bintang tidak boleh masuk lebih dekat dari ini ke pusat (fraksi lebar).
STAR_CLEAR_RADIUS = 0.44


def _band_luminance(latitude: float) -> tuple[float, float, float]:
    """Warna pita pada lintang planet, `latitude` ∈ [-1, 1].

    Pita digambar sebagai fungsi sinus yang tidak rata — cukup untuk terbaca
    sebagai "planet bergaris" di 40 pt, dan tidak berpura-pura menjadi
    fotografi. `CelestialVisual` di app memakai pita yang sama gagasannya.
    """
    t = (math.sin(latitude * 7.4) + 1.0) / 2.0
    u = (math.sin(latitude * 13.1 + 1.7) + 1.0) / 2.0
    if t < 0.34:
        a, b, k = BAND_DEEP, BAND_DARK, t / 0.34
    elif t < 0.67:
        a, b, k = BAND_DARK, BAND_MID, (t - 0.34) / 0.33
    else:
        a, b, k = BAND_MID, BAND_LIGHT, (t - 0.67) / 0.33
    # Pita halus di atas pita lebar: Jupiter tidak pernah dua warna saja.
    mix = 0.22 * u
    return (
        (a[0] + (b[0] - a[0]) * k) * (1.0 - mix) + BAND_LIGHT[0] * mix,
        (a[1] + (b[1] - a[1]) * k) * (1.0 - mix) + BAND_LIGHT[1] * mix,
        (a[2] + (b[2] - a[2]) * k) * (1.0 - mix) + BAND_LIGHT[2] * mix,
    )


def render(size: int, ss: int = 2) -> bytes:
    """Gambar ikon: latar malam, planet bercincin, bintang di luar bentuk.

    `ss` adalah supersampling per sumbu. Ikon diturunkan ke 40 pt di layar
    jam, jadi tepi cincin yang bergerigi akan terlihat sebagai garis patah —
    bukan sebagai tepi.
    """
    big = size * ss
    cx, cy = CENTRE[0] * big, CENTRE[1] * big
    radius = PLANET_RADIUS * big
    tilt = math.radians(RING_TILT_DEG)
    cos_t, sin_t = math.cos(tilt), math.sin(tilt)
    stars = _stars(120, big)

    # Cahaya dari kiri-atas, dinormalisasi supaya `dot` langsung jadi 0…1.
    lx, ly, lz = -0.55, -0.62, 0.56
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    lx, ly, lz = lx / ln, ly / ln, lz / ln

    # ── Bingkai bidang cincin ────────────────────────────────────────────────
    # Cincin bukan elips yang dicat di layar; ia bidang datar yang dilihat
    # miring. Supaya bayangannya benar, kita butuh bingkai 3D-nya: e1 (sumbu
    # mayor), e2 (sumbu minor yang juga naik keluar layar), dan normal N.
    # Dengan RING_SQUASH = cos(kemiringan), titik cincin berjari-jari r pada
    # sudut θ terproyeksi ke (u, v) = (r cosθ, r sinθ) — persis rumus elips
    # yang dipakai di bawah, jadi geometri layar dan geometri 3D konsisten.
    s_q = RING_SQUASH
    h_q = math.sqrt(max(0.0, 1.0 - s_q * s_q))
    e1 = (cos_t, sin_t, 0.0)
    e2 = (-s_q * sin_t, s_q * cos_t, h_q)
    nrm = (h_q * sin_t, -h_q * cos_t, s_q)

    def _ring_radius_at(px, py, pz):
        """Jari-jari (satuan radius planet) tempat berkas P→matahari menembus
        bidang cincin. None bila berkas tidak menembusnya ke arah matahari."""
        denom = lx * nrm[0] + ly * nrm[1] + lz * nrm[2]
        if abs(denom) < 1e-6:
            return None
        dist = px * nrm[0] + py * nrm[1] + pz * nrm[2]
        t_hit = -dist / denom
        if t_hit <= 0.0:
            return None
        qx = px + t_hit * lx
        qy = py + t_hit * ly
        qz = pz + t_hit * lz
        qu = qx * e1[0] + qy * e1[1] + qz * e1[2]
        qv = qx * e2[0] + qy * e2[1] + qz * e2[2]
        return math.sqrt(qu * qu + qv * qv)

    def _in_planet_shadow(qu, qv):
        """Titik di bidang cincin (koordinat layar) jatuh di bayangan planet
        bila berkasnya ke matahari terhalang bola planet."""
        qx = qu * e1[0] + qv * e2[0]
        qy = qu * e1[1] + qv * e2[1]
        qz = qu * e1[2] + qv * e2[2]
        par = qx * lx + qy * ly + qz * lz
        if par >= 0.0:
            # Matahari di sisi yang sama dengan titik ini: tidak mungkin
            # terhalang planet yang justru berada di belakangnya.
            return False
        perp2 = (qx * qx + qy * qy + qz * qz) - par * par
        return perp2 < radius * radius

    buf = bytearray(big * big * 3)

    for y in range(big):
        bg_t = y / max(1, big - 1)
        # Gradien latar + atmosfer nebula lembut di belakang planet.
        for x in range(big):
            dx = (x - cx) / big
            dy = (y - cy) / big
            d2 = dx * dx + dy * dy
            base = [
                BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * bg_t for i in range(3)
            ]
            neb = max(0.0, 1.0 - d2 / 0.30) ** 2 * 0.55
            r = base[0] + (NEBULA[0] - base[0]) * neb
            g = base[1] + (NEBULA[1] - base[1]) * neb
            b = base[2] + (NEBULA[2] - base[2]) * neb

            # ── Cincin, belahan jauh (di belakang planet) ──────────────────
            u = (x - cx) * cos_t + (y - cy) * sin_t
            v = -(x - cx) * sin_t + (y - cy) * cos_t
            rho = math.sqrt(u * u + (v / RING_SQUASH) ** 2) / radius
            ring_alpha = 0.0
            if RING_INNER <= rho <= RING_OUTER:
                # Celah Cassini + pita tipis: cincin yang rata terbaca
                # sebagai satu garis tebal dan kehilangan kedalaman.
                ring_alpha = 0.55 + 0.30 * math.sin(rho * 34.0)
                if 1.53 <= rho <= 1.62:
                    ring_alpha *= 0.18
                edge = min(rho - RING_INNER, RING_OUTER - rho)
                ring_alpha *= min(1.0, edge / 0.035)

            in_planet = (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius

            # Cincin jauh digambar lebih dulu, lalu planet menutupinya.
            if ring_alpha > 0.0 and v < 0:
                tint = RING_FAR
                a_ring = ring_alpha
                # **Bayangan planet di cincin.** Cincin di belakang planet
                # tetapi di sisi yang menghadap matahari tetap terang; yang
                # benar-benar gelap hanya bagian yang berada dalam kerucut
                # bayangan planet. Tanpa ini cincin tampak menyala menembus
                # planet — cacat yang paling mencolok di ukuran besar.
                if _in_planet_shadow(u, v):
                    tint = RING_SHADOWED
                    a_ring *= 0.92
                r += (tint[0] - r) * a_ring
                g += (tint[1] - g) * a_ring
                b += (tint[2] - b) * a_ring

            if in_planet:
                nx = (x - cx) / radius
                ny = (y - cy) / radius
                nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
                lam = max(0.0, nx * lx + ny * ly + nz * lz)
                # Ambient rendah: terminator yang tegas membuat bola terbaca
                # sebagai bola, bukan sebagai cakram datar.
                shade = 0.20 + 0.95 * lam
                cr, cg, cb = _band_luminance(ny)
                # **Bayangan cincin di piringan planet.** Cincin yang
                # digambar terang di atas belahan malam planet terbaca
                # sebagai plastik yang menyala sendiri — dan itu satu-satunya
                # cacat fisika yang terlihat di ukuran ikon. Cincin menghalangi
                # cahaya dari kiri-atas, jadi bayangannya jatuh di bawah garis
                # proyeksi cincin, bukan tepat di atasnya.
                if nz > 0.0 and lam > 0.0:
                    # Bayangan cincin = jejak berkas titik ini ke matahari yang
                    # menembus bidang cincin. Ini bukan "geser ke kanan-bawah":
                    # bayangan yang benar melengkung mengikuti kemiringan
                    # cincin, dan hanya cara ray-plane yang menghasilkannya.
                    rho_p = _ring_radius_at(nx, ny, nz)
                    if rho_p is not None and RING_INNER <= rho_p <= RING_OUTER:
                        shadow = 0.46 + 0.22 * math.sin(rho_p * 34.0)
                        if 1.53 <= rho_p <= 1.62:
                            shadow *= 0.30
                        # Bayangan memudar di terminator: cahaya yang datang
                        # makin miring, makin sedikit yang terhalang.
                        shadow *= min(1.0, lam * 1.6)
                        cr *= 1.0 - shadow
                        cg *= 1.0 - shadow
                        cb *= 1.0 - shadow
                r = cr * shade
                g = cg * shade
                b = cb * shade
                # Tepi planet sedikit lebih gelap: limb darkening.
                limb = 1.0 - 0.35 * (1.0 - nz) ** 2
                r *= limb
                g *= limb
                b *= limb

            # ── Cincin, belahan dekat (di depan planet) ───────────────────
            if ring_alpha > 0.0 and v >= 0:
                tint = RING_NEAR
                r += (tint[0] - r) * ring_alpha
                g += (tint[1] - g) * ring_alpha
                b += (tint[2] - b) * ring_alpha

            i = (y * big + x) * 3
            buf[i] = int(min(255, r))
            buf[i + 1] = int(min(255, g))
            buf[i + 2] = int(min(255, b))

    # Bintang digambar setelah badan, dan hanya di luar bentuk utama.
    for sx, sy, sr in stars:
        reach = int(sr * 3.2) + 1
        for yy in range(max(0, int(sy) - reach), min(big, int(sy) + reach + 1)):
            for xx in range(max(0, int(sx) - reach), min(big, int(sx) + reach + 1)):
                dist = math.hypot(xx - sx, yy - sy)
                if dist > sr * 3.2:
                    continue
                strength = max(0.0, 1.0 - dist / (sr * 3.2)) ** 2 * 0.95
                i = (yy * big + xx) * 3
                buf[i] = int(min(255, buf[i] + (STAR[0] - buf[i]) * strength))
                buf[i + 1] = int(min(255, buf[i + 1] + (STAR[1] - buf[i + 1]) * strength))
                buf[i + 2] = int(min(255, buf[i + 2] + (STAR[2] - buf[i + 2]) * strength))

    # Turunkan ke ukuran akhir: kotak `ss`×`ss`, rata.
    out = bytearray(size * size * 4)
    n = ss * ss
    for y in range(size):
        for x in range(size):
            tr = tg = tb = 0
            for dy in range(ss):
                base = ((y * ss + dy) * big + x * ss) * 3
                for dx in range(ss):
                    i = base + dx * 3
                    tr += buf[i]
                    tg += buf[i + 1]
                    tb += buf[i + 2]
            o = (y * size + x) * 4
            out[o] = tr // n
            out[o + 1] = tg // n
            out[o + 2] = tb // n
            out[o + 3] = 255

    return _png(size, size, bytes(out))


def write(path: str, size: int) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(render(size))
    print(f"{path}  {size}x{size}")


def appiconset(directory: str, *, platform: str) -> None:
    """Tulis satu PNG sumber + Contents.json bentuk satu-ukuran.

    - `platform`: "ios" atau "watchos". Xcode menulisnya huruf kecil, dan
      untuk watchOS nilai ini yang membedakan app icon jam dari app icon iOS
      yang kebetulan sama ukurannya.
    """
    name = "AppIcon-1024.png"
    write(os.path.join(directory, name), SOURCE_SIZE)

    contents = {
        "images": [
            {
                "filename": name,
                "idiom": "universal",
                "platform": platform,
                "size": f"{SOURCE_SIZE}x{SOURCE_SIZE}",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, "Contents.json"), "w") as handle:
        json.dump(contents, handle, indent=2)
        handle.write("\n")
    print(f"{directory}/Contents.json")


def catalog_root(directory: str) -> None:
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, "Contents.json"), "w") as handle:
        json.dump({"info": {"author": "xcode", "version": 1}}, handle, indent=2)
        handle.write("\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", metavar="PATH",
                        help="tulis satu PNG pratinjau ke PATH, tanpa menyentuh katalog")
    parser.add_argument("--size", type=int, default=SOURCE_SIZE,
                        help="ukuran PNG pratinjau (bawaan 1024)")
    parser.add_argument("--ss", type=int, default=2, help="supersampling per sumbu")
    args = parser.parse_args()

    if args.preview:
        with open(args.preview, "wb") as handle:
            handle.write(render(args.size, ss=args.ss))
        print(f"{args.preview}  {args.size}x{args.size}")
        return

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    watch = os.path.join(root, "Apps/PointAndKnowWatch/Resources/Assets.xcassets")
    catalog_root(watch)
    appiconset(os.path.join(watch, "AppIcon.appiconset"), platform="watchos")

    ios = os.path.join(root, "Apps/PointAndKnowiOS/Resources/Assets.xcassets")
    catalog_root(ios)
    appiconset(os.path.join(ios, "AppIcon.appiconset"), platform="ios")


if __name__ == "__main__":
    main()
