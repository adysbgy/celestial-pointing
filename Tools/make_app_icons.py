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

Pakai:
    python3 Tools/make_app_icons.py
"""

from __future__ import annotations

import json
import os
import struct
import zlib

# Palet: malam biru tua → ungu, dengan bintang.
TOP = (14, 18, 48)
BOTTOM = (58, 32, 92)
GLOW = (120, 90, 190)
STAR = (255, 250, 235)

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


def _stars(count: int, size: int, seed: int = 20261003):
    """Bintang deterministik: LCG sederhana supaya hasilnya bisa diulang."""
    state = seed
    out = []
    for _ in range(count):
        state = (1103515245 * state + 12345) % (2**31)
        x = state / (2**31)
        state = (1103515245 * state + 12345) % (2**31)
        y = state / (2**31)
        state = (1103515245 * state + 12345) % (2**31)
        r = state / (2**31)
        out.append((x * size, y * size, 1.0 + r * 2.5))
    return out


def render(size: int) -> bytes:
    """Gambar ikon: gradien malam + bintang + cahaya lembut di tengah."""
    stars = _stars(140, size)
    center = size * 0.5
    pixels = bytearray()

    for y in range(size):
        t = y / max(1, size - 1)
        base = tuple(TOP[i] + (BOTTOM[i] - TOP[i]) * t for i in range(3))
        for x in range(size):
            # Cahaya lembut di tengah supaya ikon tidak terlihat datar.
            dx, dy = (x - center) / size, (y - center) / size
            glow = max(0.0, 1.0 - (dx * dx + dy * dy) * 6.0)
            r, g, b = (base[i] + (GLOW[i] - base[i]) * glow * 0.35 for i in range(3))

            for sx, sy, sr in stars:
                d2 = (x - sx) ** 2 + (y - sy) ** 2
                if d2 < sr * sr * 16:
                    strength = max(0.0, 1.0 - (d2**0.5) / (sr * 4))
                    r += (STAR[0] - r) * strength
                    g += (STAR[1] - g) * strength
                    b += (STAR[2] - b) * strength

            pixels += bytes((int(min(255, r)), int(min(255, g)), int(min(255, b)), 255))

    return _png(size, size, bytes(pixels))


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
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    watch = os.path.join(root, "Apps/PointAndKnowWatch/Resources/Assets.xcassets")
    catalog_root(watch)
    appiconset(os.path.join(watch, "AppIcon.appiconset"), platform="watchos")

    ios = os.path.join(root, "Apps/PointAndKnowiOS/Resources/Assets.xcassets")
    catalog_root(ios)
    appiconset(os.path.join(ios, "AppIcon.appiconset"), platform="ios")


if __name__ == "__main__":
    main()
