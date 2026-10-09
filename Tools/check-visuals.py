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
import ast
import math
import os
import re
import struct
import sys
import zlib

import importlib.util

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Jangan pernah menulis bytecode `.pyc`. Lihat `_load` untuk alasannya.
sys.dont_write_bytecode = True


def _purge_stale_bytecode(path):
    """Buang `.pyc` untuk `path` supaya sumbernya dibaca ulang dari disk.

    **Cacat yang ditutup ini, dan kenapa ia tidak terlihat.** CPython
    memvalidasi cache bytecode lewat (ukuran berkas, mtime) — **bukan isi**.
    Harness mutasi menulis versi yang dimutasi ke berkas produksi yang sama
    berkali-kali dalam satu detik, dan dua keadaan berbeda bisa menghasilkan
    **panjang berkas yang identik**: token `MOON_SPHERE_GRADIENT_END_RADIUS)`
    (33 byte) diganti `1.15)` (4 byte) di dua tempat, jadi keadaan 3
    ("keduanya") dan keadaan 4 ("jalur Bulan") menulis berkas sepanjang sama.
    Bila keduanya jatuh pada detik yang sama, `.pyc` keadaan 3 dianggap masih
    sah dan probe keadaan 4 membaca **kode keadaan 3** — gerbang lalu memerah
    pada keadaan yang sebenarnya benar.

    Itu pernah menjatuhkan `main`: keadaan 4 merah dengan lima pemeriksaan
    piksel planet yang sama persis dengan keadaan 1, sementara pemeriksaan
    teks `drawPlanet` hijau — tanda yang jelas bahwa yang dibaca adalah kode
    keadaan sebelumnya, bukan kode di disk. Cacatnya **flaky** (bergantung
    detik), jadi ia lolos berkali-kali sebelum menjatuhkan CI sekali.
    """
    base = os.path.basename(path).rsplit(".", 1)[0]
    cache = os.path.join(os.path.dirname(path), "__pycache__")
    try:
        entries = os.listdir(cache)
    except OSError:
        return
    for entry in entries:
        if entry.startswith(base + ".") and entry.endswith(".pyc"):
            try:
                os.remove(os.path.join(cache, entry))
            except OSError:
                pass


def _load(name, filename):
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)
    _purge_stale_bytecode(path)
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


def luminance_field(path):
    """Seluruh luminans render dalam urutan baris — untuk dua render banding.

    Mengembalikan daftar datar supaya dua ukuran bisa dibandingkan dengan
    `zip` tanpa penyesuaian indeks. Koefisien WCAG (Rec. 709), sama dengan
    yang dipakai gerbang kontras lain di berkas ini supaya "terang" berarti
    satu hal yang sama di semua gerbang.
    """
    width, height, rows = decode_png(path)
    field = []
    for y in range(height):
        row = rows[y]
        for x in range(width):
            field.append(0.2126 * row[x * 4] + 0.7152 * row[x * 4 + 1]
                         + 0.0722 * row[x * 4 + 2])
    return field


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


# ── Ambang yang diukur, bukan dirasakan ───────────────────────────────────
#
# Keduanya dikalibrasi terhadap gambar yang ada sekarang, lalu diturunkan
# sedikit. Gerbang "diff > 0" tidak bisa gagal (satu piksel pun lolos), jadi
# ambangnya harus angka yang benar-benar bisa dilanggar oleh cacat yang
# dimaksud — bukan angka yang membuat setiap gambar hijau.

#: Proporsi piksel minimum yang harus berbeda antara dua morfologi.
#: Pasangan termirip saat ini (galaxy vs spiralGalaxy, keduanya cakram
#: miring) menghasilkan ~13%; ambang 8% masih menangkap penyorotan ke satu
#: bentuk (yang menghasilkan ~0%) tanpa merah karena anti-aliasing.
MIN_MORPHOLOGY_DIFF = 0.08

#: Berapa piksel paling terang yang dirata-ratakan saat mengukur warna kabut.
#: **Anggaran tetap, bukan proporsi**: gugus hanya menutupi sebagian kecil
#: frame, jadi rata-rata seluruh frame didominasi latar gelap dan justru
#: menyembunyikan warna yang membedakannya. Dengan anggaran tetap, gugus
#: yang jarang dan nebula yang padat diukur pada skala yang sama.
COLOUR_SAMPLE_PIXELS = 300

#: Jarak kanal minimum antar warna kabut. Dikalibrasi terhadap gambar yang
#: ada sekarang: pasangan terdekat (galaxy vs openCluster, keduanya hampir
#: putih) berjarak 0.115 dan setiap morfologi ≥ 0.188 dari kabut netral.
#: Ambang 0.08 menangkap "satu warna untuk semua morfologi" (jarak ~0.00)
#: dengan margin, tanpa bergantung pada rasa.
MIN_DEEP_SKY_COLOUR_DIFF = 0.08

#: Selisih minimum dari latar sebelum sebuah piksel disebut "terbaca".
#:
#: Angka yang sama dengan yang dipakai gerbang celah cincin Saturnus (`- 12`)
#: dan yang mendasari ambang di gerbang bentuk pita: 12 dari 255. Ditulis
#: **sekali** di sini karena sekarang dipakai tiga tempat; tiga salinan angka
#: yang sama adalah tiga angka yang akan berbeda.
READABILITY_THRESHOLD = 12

#: Berapa derajat pada satu jari-jari yang harus di atas ambang supaya sebuah
#: **goresan** lengan spiral dinyatakan menyambung.
#:
#: Bukan "ada piksel terang": di ukuran jam satu titik anti-aliasing atau satu
#: bintang latar sudah cukup untuk itu, dan lengan yang bolong tetap lolos.
#: Diukur pada 76 px, `ss=8`, tata letak 4-titik yang lama: lengan yang
#: menyambung memberi 38-59°, yang bolong memberi 6-12°. Ambang 12° duduk di
#: antara keduanya — **tetapi dengan margin yang tipis**, dan itu sebabnya
#: gerbangnya menyampel di 16 jari-jari, bukan di dua jari-jari yang kebetulan
#: berbeda.
MIN_ARM_DEGREES = 12

#: Seberapa terang **celah terburuk** cangkang nebula planetari, sebagai
#: pecahan puncaknya (0 = sama terang, 1 = turun sampai latar).
#:
#: Angka ini memisahkan **cangkang bersambung** dari **untaian manik**, dan
#: itulah satu-satunya hal yang membedakan nebula planetari dari gugus
#: bintang di layar. Diukur (`Tools/bukti-mutasi-cangkang.py`):
#:
#:   - 8 blob @45°, lebar 0.30 R (tata letak lama) — 0.00…0.18  MANIK
#:   - 16 blob @22.5°, lebar 0.26 R                 — 0.60…0.77  manik di M57
#:   - 24 blob @15°,   lebar 0.26 R (sekarang)      — 0.84…0.85  CANGKANG
#:
#: **Kenapa 0.75, bukan 0.50.** Ambang lama duduk di antara 0.18 dan 0.77,
#: dan itu cukup selama **hanya kasus rujukan** (fuzziness 0.8) yang diukur —
#: di sana angkanya 0.77. Begitu M57 ikut diukur pada fuzziness katalognya
#: sendiri (0.40), angkanya jatuh ke **0.60** dan tetap dinyatakan lulus
#: padahal di layar ia masih untaian manik. Selisih 0.60 vs 0.50 terlalu tipis
#: untuk memisahkan keduanya. Angka-angka di atas menunjukkan pemisahan yang
#: sesungguhnya ada di sekitar 0.7, bukan 0.5: yang rusak ≤ 0.60, yang benar
#: ≥ 0.83. Ambang 0.75 duduk di tengah celah itu dengan margin ~0.08 ke dua
#: arah — cukup lebar sehingga tidak merah karena perubahan kecil di tempat
#: lain, dan cukup rendah sehingga tidak menuntut cangkang yang mustahil.
MIN_SHELL_CONTINUITY = 0.75

#: Seberapa pipih siluet M27 boleh, sebagai rasio tinggi:lebar kotak pembatasnya.
#:
#: M27 dilihat dari samping: 8.0′ × 5.7′, rasio 0.71. Yang benar-benar terukur
#: pada gambar yang digambar kode sekarang adalah 0.673 (200 px) dan 0.650
#: (76 px), karena tepi gradien tidak setajam kotak yang dijanjikan angkanya.
#: Ambang 0.80 duduk di antara 0.67 dan 1.0 (M57) dengan margin ~0.13 ke arah
#: cacatnya. Yang dijaga "jelas memanjang, bukan bulat" — bukan nilai ketiga
#: desimal yang tidak ada artinya di layar jam.
MAX_DUMBBELL_ASPECT = 0.80

#: Seberapa **pipih** siluet M27 boleh — batas bawahnya.
#:
#: Gerbang satu sisi membiarkan cacat yang lain lolos: mengecilkan elongasi
#: sampai 0.20 menghasilkan siluet rasio ~0.22, yang tetap "<= 0.80" dan
#: karena itu hijau — padahal bentuknya sudah lensa tipis, bukan Dumbel.
#: Batas bawah 0.45 duduk di antara 0.22 (terlalu pipih) dan 0.673 (sekarang)
#: dengan margin ~0.22 ke arah cacatnya. Rasio nyata M27 (0.71) ada di atasnya.
MIN_DUMBBELL_ASPECT = 0.45

#: Seberapa bulat siluet M57 harus tetap, rasio tinggi:lebar.
#:
#: M57 dilihat hampir tepat dari kutubnya: 1.4′ × 1.0′. Terukur 1.000 pada
#: kedua ukuran. Ambang 0.92 menjaga sisi sebaliknya — memperlebar pemipihan
#: sampai kena ke semua objek `.planetaryNebula` akan memerahkannya.
MIN_RING_ASPECT = 0.92

#: Nama kasus M27, ditulis sekali.
#:
#: Dipakai di dua tempat di `check_dumbbell_nebula_is_an_elongated_shell`:
#: siluet dan pusat cangkang. Sebelumnya tempat kedua memakai `case_name`,
#: variabel gelung yang setelah gelung bernilai `deepsky-m57` — jadi
#: pemeriksaan berlabel M27 mengukur pusat M57 dan hijau di setiap keadaan.
#: Konstanta ini membuat kesalahan itu tidak bisa terulang tanpa terlihat.
M27_CASE = "deepsky-m27"

#: Seberapa penuh pusat cangkang M27 boleh, sebagai bagian dari terang cangkang.
#:
#: Ini bukan formalitas: memipihkan **posisi** blob tanpa memipihkan
#: **tingginya** memenuhi syarat siluet sambil menutup lubangnya. Diukur pada
#: keadaan itu (`Tools/bukti-mutasi-dumbel.py`, keadaan 3) pada ukuran jam:
#: pusat terisi **0.571** dari terang cangkang — cangkang berongga berubah jadi
#: gumpalan pipih. Kode sekarang **0.081** (0.000 pada 200 px, tempat blobnya
#: lebih rapat dari jaring sampel). Ambang 0.25 duduk di antaranya, dekat ke
#: kode sehat supaya cacatnya tidak perlu jadi parah dulu untuk tertangkap.
MAX_CENTRE_FILL = 0.25

#: Berapa derajat **sumbangan** tonjolan inti yang harus terbaca di ukuran jam.
#:
#: Sumbangan, bukan cakupan mutlak: yang diukur adalah selisih cakupan cincin
#: dengan vs tanpa tonjolan inti (lihat `check_spiral_core_reads_as_one_body`).
#: Cakupan mutlaknya bergantung pada seberapa dekat lingkarnya ke tepi piringan,
#: jadi ambang mutlak akan merah pada kode yang benar — versi pertama gerbang
#: itu menuntut 340° dan merah pada sampel tepi yang sehat (266°).
#:
#: Diukur pada 76 px, `ss=8`: sehat memberi +124°/+106°/+44°, tonjolan yang
#: dihilangkan atau diperkecil memberi +0°, dan yang diredupkan (0.60 → 0.20)
#: memberi paling banyak +12°. Ambang 30° duduk di antaranya dengan margin
#: 2,5x ke bawah dan 1,5x ke atas.
SPIRAL_CORE_MIN_DEGREES = 30


def _rgb_text(colour):
    """(0.88, 0.44, 0.50) -> '0.88/0.44/0.50' untuk pesan kegagalan."""
    return "/".join(f"{c:.2f}" for c in colour)


def brightest_colour(rows, width, height, budget=COLOUR_SAMPLE_PIXELS):
    """Warna rata-rata `budget` piksel paling terang — warna kabutnya sendiri.

    Bukan rata-rata seluruh frame: kabut digambar sebagai gradien tipis di
    atas latar gelap, dan sebagian morfologi hanya menutupi sudut kecil
    frame. Rata-rata frame akan didominasi latar dan menyembunyikan warna
    yang justru sedang diukur.
    """
    pixels = []
    for y in range(height):
        row = rows[y]
        for x in range(width):
            r, g, b = row[x * 4], row[x * 4 + 1], row[x * 4 + 2]
            pixels.append((r + g + b, (r / 255.0, g / 255.0, b / 255.0)))
    pixels.sort(reverse=True)
    top = pixels[:budget]
    if not top:
        return None
    return tuple(sum(p[1][i] for p in top) / len(top) for i in range(3))


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
    for confirmed_name, uncertain_name, label in pairs:
        _, confirmed = render_case(confirmed_name, size=size, ss=ss)
        _, uncertain = render_case(uncertain_name, size=size, ss=ss)
        w, h, rows_a = confirmed
        _, _, rows_b = uncertain
        diff = badge_excluded_diff(rows_a, rows_b, w, h,
                                   (fx0, fy0, fx1, fy1))
        results.append(Result(
            f"{label} hilang saat ragu", diff > 0,
            f"{diff} piksel berbeda di luar lencana (terkunci vs ragu)"))

    # Dan arah sebaliknya: saat engine **ragu**, bentuk objek langit dalam tidak
    # boleh sampai ke gambar sama sekali. Dipisah ke fungsinya sendiri supaya
    # harness mutasi bisa memanggilnya tanpa merender seluruh katalog —
    # gerbang penuh ~6 menit, satu pemeriksaan ini ~30 detik.
    check_deep_sky_shape_suppression(results, size, ss)


def check_deep_sky_shape_suppression(results, size=200, ss=2):
    """Saat engine ragu, bentuk objek langit dalam tidak boleh terlihat.

    **Kenapa pemeriksaan ini ada, dan kenapa dua versi sebelumnya gagal.**

    Versi pertama memakai `diff > 0` mentah antara `deepsky-galaxy` (terkunci,
    tanpa lencana) dan `deepsky-uncertain` (ragu, berlencana). Karena hanya
    yang ragu memakai lencana, seluruh selisihnya bisa **hanya** lencana —
    diukur: dengan penekanan bentuk saat ragu dihapus seluruhnya dari port,
    pemeriksaan itu tetap hijau (`raw_diff` 3434, semuanya lencana) sementara
    bentuknya jelas masih tergambar.

    Versi kedua memperbaiki lencananya (`badge_excluded_diff`) dan memperluas
    ke keenam morfologi — tapi membandingkan semuanya terhadap **satu** kabut
    netral ber-morfologi `galaxy`. Diukur lewat mutasi (penekanan bentuk
    dihapus dari port): hanya `galaxy` yang memerah, dengan 0 piksel berbeda
    karena ia memang dibandingkan dengan **dirinya sendiri**. Kelima morfologi
    lain tetap hijau pada 6073…6881 piksel — dan selisih itu seluruhnya
    **warna**, bukan bentuk. Gerbang yang menamai dirinya "bentuk … hilang
    saat ragu" sedang mengukur warna.

    Versi ini mengukur aturannya langsung, dari dua sisi:

      1. **Saat ragu, morfologi tidak mengubah gambar sama sekali.** Keenam
         render `.uncertain` harus identik dengan render ragu ber-morfologi
         `None`. Ini menangkap kedua bentuk cacat sekaligus: penekanan yang
         hilang seluruhnya, dan penekanan yang hanya menutup warna sementara
         bentuknya bocor.

         **Kenapa referensinya `None`, bukan salah satu dari keenamnya.**
         Versi pertama fungsi ini memakai `galaxy` sebagai acuan, dan `galaxy`
         lalu dibandingkan dengan **dirinya sendiri** — nol piksel selamanya,
         hijau bahkan ketika penekanannya hilang. Keadaan itu ditemukan
         `Tools/bukti-mutasi-langit-dalam.py`, bukan dibaca: di bawah mutasi
         "penekanan dihapus seluruhnya", kelima morfologi lain memerah sementara
         `galaxy` tetap hijau. Referensi `None` membuat keenam perbandingan
         sama-sama bermakna. Lencana identik di semua render ragu (ia hanya
         bergantung pada ukuran), jadi perbandingan penuh di sini sah.
      2. **Saat terkunci, bentuk morfologi itu benar-benar sampai ke gambar** —
         dibandingkan **bentuk-saja**: warna dipaksa netral supaya perbandingan
         ini tidak bisa dipenuhi oleh warna. Ini arah yang menangkap
         kebalikannya — penggambar yang mengabaikan morfologi untuk **bentuk**
         (terkunci maupun ragu) akan hijau di keenam pemeriksaan (1) **dan**
         hijau di seluruh 42 pemeriksaan `check_deep_sky_morphologies_render_
         distinct`, karena keenam morfologi tetap berbeda warna. Diukur: pada
         mutasi itu, kedua gerbang tersebut hijau sementara bentuknya jelas
         sama. Hanya pemeriksaan ini yang memerah.

         **`nebula` dikecualikan, dan itu fakta model, bukan kelonggaran.**
         `CelestialVisual.deepSky(morphology:)` memetakan `.nebula` ke
         `nebula(fuzziness:)` — fungsi yang **sama** dengan yang dipanggil
         untuk morfologi `nil`. Jadi kabut emisi memang berbentuk identik
         dengan kabut netral; yang membedakan keduanya hanya warna. Diukur:
         bentuk-saja `nebula` = 0 piksel di semua keadaan, dan itu benar.
         Menuntutnya bukan-nol berarti menuntut model diubah.
    """
    fx0, fy0, fx1, fy1 = R.candidate_marker_footprint()
    morphologies = ("nebula", "planetaryNebula", "galaxy",
                    "spiralGalaxy", "openCluster", "globularCluster")
    # `nebula` berbentuk sama dengan netral (lihat docstring) — perbandingan
    # bentuk-saja tidak bisa dan tidak boleh menuntut apa pun darinya.
    shape_morphologies = tuple(m for m in morphologies if m != "nebula")

    def render_case_for(morphology, confirmed, colour_neutral=False):
        """Render satu morfologi lewat PNG yang sama dengan `render_case`.

        Lewat `to_png()` + `decode_png`, bukan buffer float mentah: semua
        perbandingan di bawah membandingkan byte 8-bit, dan representasi yang
        berbeda akan mengukur selisih pembulatan, bukan bentuknya.

        `colour_neutral` memaksa setiap morfologi memakai warna kabut netral,
        sehingga yang tersisa di gambar hanya **bentuknya**. Pemaksaan itu
        dikembalikan di `finally` — kalau tidak, ia bocor ke gerbang lain yang
        berjalan sesudahnya dan seluruh sisa berkas ini mengukur gambar yang
        salah.
        """
        case = R.VisualCase(f"probe-{'locked' if confirmed else 'uncertain'}"
                            f"-{morphology}", "probe", "deepSky",
                            morphology=morphology, fuzziness=0.8,
                            is_confirmed=confirmed)
        saved = dict(R.DEEP_SKY_COLOUR_KEY) if colour_neutral else None
        if colour_neutral:
            for key in R.DEEP_SKY_COLOUR_KEY:
                R.DEEP_SKY_COLOUR_KEY[key] = "deepSky"
        try:
            canvas = R.render(case, size=size, night_mode=False,
                              show_frame=False, ss=ss)
        finally:
            if saved is not None:
                R.DEEP_SKY_COLOUR_KEY.clear()
                R.DEEP_SKY_COLOUR_KEY.update(saved)
        os.makedirs(R.OUT_DIR, exist_ok=True)
        path = os.path.join(R.OUT_DIR, f"{case.name}.png")
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        return decode_png(path)

    uncertain_rows = {}
    for morphology in morphologies:
        w0, h0, uncertain_rows[morphology] = render_case_for(morphology, False)
    # Acuan netral: morfologi `None`. Bukan salah satu dari keenam di atas,
    # justru supaya tidak ada perbandingan yang membandingkan diri sendiri.
    _, _, rows_neutral = render_case_for(None, False)

    # (1) Aturan itu sendiri: ragu → morfologi tidak mengubah apa pun.
    for morphology in morphologies:
        rows_u = uncertain_rows[morphology]
        diff = sum(1 for y in range(h0) for x in range(w0)
                   if rows_u[y][x * 4:x * 4 + 3] != rows_neutral[y][x * 4:x * 4 + 3])
        results.append(Result(
            f"saat ragu, morfologi {morphology} tidak mengubah gambar",
            diff == 0,
            f"{diff} piksel berbeda dari kabut ragu bermorfologi None "
            f"(harus 0 — bentuk tidak boleh bocor saat engine ragu)"))

    # (2) Arah sebaliknya, bentuk-saja: saat terkunci, bentuk morfologi itu
    # benar-benar sampai ke gambar.
    _, _, rows_locked_neutral = render_case_for(None, True, colour_neutral=True)
    for morphology in shape_morphologies:
        _, _, rows_shape = render_case_for(morphology, True, colour_neutral=True)
        diff = badge_excluded_diff(rows_shape, rows_locked_neutral,
                                   w0, h0, (fx0, fy0, fx1, fy1))
        results.append(Result(
            f"bentuk {morphology} sampai ke gambar saat terkunci", diff > 0,
            f"{diff} piksel berbeda di luar lencana terhadap netral, "
            f"warna dipaksa sama (harus > 0 — kalau 0, bentuk morfologinya "
            f"tidak pernah digambar)"))


def badge_excluded_diff(rows_a, rows_b, w, h, footprint, margin_px=4.0):
    """Piksel berbeda di **luar** kotak lencana "?".

    Lencana digambar hanya pada gambar "ragu", jadi ia ikut terhitung di
    setiap selisih dan membuat `diff > 0` selalu benar — termasuk ketika
    cirinya tidak pernah digambar sama sekali. Kotak itu karena itu
    dikecualikan, dengan margin untuk garis tepi + anti-aliasingnya.

    Satu implementasi dipakai dua gerbang: `check_features_disappear_when_uncertain`
    (pada ukuran render) dan `check_features_survive_the_watch_size` (pada
    ukuran jam). Kalau keduanya menyalin aritmetika indeksnya sendiri, satu
    koreksi di satu tempat akan membuat yang lain mengukur kotak yang berbeda.
    """
    fx0, fy0, fx1, fy1 = footprint
    radius = min(w, h) / 2.0
    cx, cy = w / 2.0, h / 2.0
    margin = margin_px / radius
    ex0, ey0, ex1, ey1 = fx0 - margin, fy0 - margin, fx1 + margin, fy1 + margin
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
    return diff


def watch_visual_diameter():
    """`WatchMetrics.visualDiameter` (poin), dibaca dari token — atau `None`.

    Dibaca dari token, bukan diketik di pemanggilnya: kalau kartu jam melebar,
    setiap gerbang yang memakainya ikut. `None` (bukan angka bawaan) supaya
    gerbang yang kehilangan ukurannya jadi **merah**, bukan diam-diam berhenti
    mengukur apa pun. Satu pembaca, dua pemakai: `check_features_survive_the_watch_size`
    dan `check_saturn_gap_reads_at_the_watch_size`.
    """
    theme_path = os.path.join(
        ROOT, "Apps/PointAndKnowWatch/Sources/WatchTheme.swift")
    try:
        source = open(theme_path, encoding="utf-8").read()
    except OSError:
        return None
    match = re.search(r"visualDiameter\s*:\s*CGFloat\s*=\s*(\d+(?:\.\d+)?)",
                      source)
    if match is None:
        return None
    return int(round(float(match.group(1))))


def check_features_survive_the_watch_size(results, ss=8):
    """Ciri pengenal harus masih terukur pada ukuran yang **benar-benar tampil**.

    **Cacat yang ditutup pemeriksaan ini.** `check_features_disappear_when_uncertain`
    membuktikan kelima ciri planet (Bintik Merah Jupiter, cincin Saturnus, kutub
    Mars, kawah Merkurius, kabut Venus) hilang saat engine ragu — dan ia benar.
    Tapi ia, dan **seluruh** gerbang gambar lain di berkas ini, hanya pernah
    berjalan pada `--size 200` ke atas. Jam menggambar visualnya pada
    `WatchMetrics.visualDiameter` = 38 poin, yaitu lebih dari **5x lebih kecil**.

    Ciri yang masih terukur pada 200 px bisa menyusut jadi nol piksel pada
    38 px, dan setiap gerbang di berkas ini tetap hijau — karena tidak satu pun
    pernah melihat gambar seukuran jam. Itu kelas cacat yang sama dengan
    "0.14 R Venus" yang dulu ditutup: gerbang yang mengukur gambar yang **tidak
    tampil**. Bedanya di sini arahnya bukan "bentuk yang salah", melainkan
    "ukuran yang salah".

    **Ukurannya dibaca dari token, bukan diketik di sini.** 38 hidup di
    `WatchMetrics.visualDiameter`; kalau kartu jam melebar, gerbang ini ikut
    membesar. Kalau tokennya tidak terbaca, pemeriksaan ini **merah** — bukan
    diam-diam jatuh ke angka bawaan, karena gerbang yang kehilangan ukurannya
    adalah gerbang yang berhenti mengukur apa pun.
    """
    watch = watch_visual_diameter()
    if watch is None:
        results.append(Result(
            "ukuran visual jam terbaca dari token", False,
            "WatchMetrics.visualDiameter tidak ditemukan di WatchTheme.swift"))
        return

    footprint = R.candidate_marker_footprint()
    pairs = [
        ("planet-jupiter-confirmed", "planet-jupiter-uncertain", "Bintik Merah Besar Jupiter"),
        ("planet-saturn-confirmed", "planet-saturn-uncertain", "cincin Saturnus"),
        ("planet-mars-confirmed", "planet-mars-uncertain", "kutub Mars"),
        ("planet-mercury-confirmed", "planet-mercury-uncertain", "kawah Merkurius"),
        ("planet-venus-confirmed", "planet-venus-uncertain", "kabut Venus"),
    ]
    for confirmed_name, uncertain_name, label in pairs:
        _, confirmed = render_case(confirmed_name, size=watch, ss=ss)
        _, uncertain = render_case(uncertain_name, size=watch, ss=ss)
        w, h, rows_a = confirmed
        _, _, rows_b = uncertain
        diff = badge_excluded_diff(rows_a, rows_b, w, h, footprint)
        results.append(Result(
            f"{label} masih terukur pada {watch} pt (ukuran jam)", diff > 0,
            f"{diff} piksel berbeda di luar lencana pada {watch}x{watch} px "
            f"(nol berarti cirinya lenyap di ukuran yang tampil)"))


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


def _stroke_width_factors(source, radius_name, patterns):
    """Faktor **lebar garis** yang mengikuti radius — hanya yang stroking.

    Kata kunci `patterns` bukan detail gaya. Badge kandidat punya **tiga**
    besaran yang semuanya ditulis `badge_radius * N`, dan ketiganya berbeda:

    | besaran | nilainya | lebar garis? |
    |---|---|---|
    | `stroke_width` (geometri) | 0.28 | ya |
    | `dot_radius` (tetes glif) | 0.13 | bukan |
    | lebar garis di penggambar | 0.28 | ya |

    Dua pembacaan gagal, masing-masing sudah dicoba di siklus ini:

    - **Singular** (`badge_radius * N` pertama saja) — mutasi di
      `_draw_candidate_marker` tidak terlihat sama sekali, karena pembaca
      selalu berhenti di yang geometri.
    - **Plural tanpa konteks** (`semua badge_radius * N`) — menelan
      `dot_radius` dan membuat perbandingan himpunan **merah pada kode yang
      benar**. Gerbang yang lebih ketat daripada yang diklaimnya akan
      dimatikan orang dalam sehari.

    Jadi yang dicari adalah **konteks stroking**, dan tetes glif (0.13) tetap
    dijaga lewat jalur yang sudah ada sebelumnya.

    Komentar dibuang per baris lebih dulu: badan fungsi di repo ini memuat
    angka di komentarnya, dan pembacaan tanpa membuangnya mengambil angka
    prosa sebagai parameter.
    """
    body = "\n".join(line.split("//")[0] if "//" in line else line.split("#")[0]
                     for line in source.split("\n"))
    found = []
    for pattern in patterns:
        found += [float(v) for v in
                  re.findall(pattern.format(r=re.escape(radius_name)), body)]
    # **Tidak melempar.** Daftar `checks` di bawah dibangun **saat fungsi
    # berjalan**, jadi pembaca yang melempar `ValueError` akan menggagalkan
    # seluruh gerbang dengan traceback — dan traceback tidak menyebut apa yang
    # harus diperbaiki. Pola yang dipakai berkas ini: jangkar hilang adalah
    # **pemeriksaan yang gagal dan menyebut jangkarnya**, bukan exception.
    # `None` yang membuat perbandingan di bawah salah dan pesannya menyebut
    # kedua sisi, jadi sumber dan tujuannya masih terlihat.
    return found or None


def badge_stroke(source):
    """Tebal glif kandidat "?" — dua tempat stroking, dua satuan.

    Yang dijaga keduanya: assignment di fungsi geometri (satuan radius
    frame) dan pemanggilan `stroke_polyline` di penggambar (satuan piksel).
    Menggabungkan keduanya jadi satu daftar membuat mutasi di salah satunya
    tidak terlihat kalau yang lain dibaca.
    """
    name = "badge_radius" if re.search(r"badge_radius", source) else "badgeRadius"
    # Tiga tempat stroking, masing-masing satu di dua bahasa:
    #   Swift view   `lineWidth: max(1, badgeRadius * 0.28)`
    #   Python geometri `stroke_width = badge_radius * 0.28`
    #   Python penggambar `stroke_polyline(…, max(1.0, badge_radius * 0.28), …)`
    return _stroke_width_factors(source, name, [
        r"\w*[Ww]idth\s*[:=]\s*max\([\d.]+,\s*{r}\s*\*\s*(?<![\w.])(\d+\.\d+)",
        r"stroke_width\s*=\s*{r}\s*\*\s*(?<![\w.])(\d+\.\d+)",
        r"stroke_polyline\([^)]*?{r}\s*\*\s*(?<![\w.])(\d+\.\d+)",
    ])


def _same_stroke_factors(view_factors, port_factors):
    """Apakah kedua sisi punya **nilai** faktor yang sama.

    `None` berarti salah satu sisi tidak punya faktor yang bisa dibaca, dan
    itu harus merah — tapi **dengan bentuk yang bisa dibaca**, karena
    pemeriksaan yang membandingkan `None` dengan `True` hanya menghasilkan
    "port=None, seharusnya True" tanpa menyebut berkas mana.
    Nilai yang dibandingkan adalah himpunan unik: jumlah situs memang
    berbeda (port punya glif di dua satuan, view cuma satu), yang wajib sama
    adalah **angka** yang dipakai di sana.
    """
    if view_factors is None or port_factors is None:
        return False
    return set(view_factors) == set(port_factors)


def _function_body(source, anchor):
    """Isi sebuah fungsi Swift, dibatasi penutup kurawalnya sendiri.

    **Kenapa tidak `split` sampai akhir berkas.** Sudah dua kali di repo ini
    pembaca yang membaca melewati batas fungsinya meloloskan token dari fungsi
    lain di bawahnya (`read_deep_sky_drawing_from_swift`, dan
    `read_planet_switch_cases_from_swift` yang harus memotong di penutup
    pertama). Pemeriksaan "view tidak menulis warnanya sendiri" yang membaca
    seluruh berkas akan menemukan `Color(red:…)` milik cabang lain dan merah
    pada kode yang benar.

    Jangkar yang tidak ditemukan mengembalikan string kosong — bukan
    exception: pemanggilnya membandingkan dengan `not`, dan exception akan
    menggagalkan seluruh gerbang dengan traceback yang tidak menyebut apa
    yang harus diperbaiki.
    """
    if anchor not in source:
        return ""
    start = source.index(anchor) + len(anchor)
    # Kurung buka **pertama** sesudah jangkar adalah pembuka tubuhnya; depth
    # dimulai dari situ, bukan dari 1 — menghitungnya dua kali membuat
    # penutup pertama hanya menurunkan depth kembali ke 1, dan wilayahnya
    # melebar ke fungsi berikutnya.
    opening = source.find("{", start)
    if opening < 0:
        return ""
    depth, i = 1, opening + 1
    while i < len(source) and depth:
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
        i += 1
    return source[opening + 1:i]


def swift_code_only(source):
    """Buang komentar dari sumber Swift — dipakai pemeriksaan "dipakai kode".

    **Kenapa ini harus ada.** Gerbang pemakaian yang membaca sumber **mentah**
    akan menghitung sebuah nama yang hanya muncul di dalam komentar sebagai
    "dipakai". Token yang tidak menggambar apa pun lalu hijau, dan bentuknya
    yang paling berbahaya adalah yang paling wajar: `// TODO kembalikan
    CelestialVisual.accents.moonPhaseUnknown` di atas baris yang sudah
    diganti. Diukur di repo ini: dengan pembaca mentah, keadaan itu **hijau**.

    Isi tanda kutip ikut dibuang, karena string tidak menggambar apa pun juga.
    Ini menutup lubang yang sama satu lapis lebih dalam — dan sekaligus
    membuat pemeriksaan di bawah tidak bisa ditipu oleh `"nama token"` yang
    ditulis di pesan galat atau di nama kasus render.

    Bukan pemindai Swift sungguhan: komentar di dalam string (mis. `"http://"`)
    tidak dikenali, dan di berkas ini tidak ada.
    """
    out, i, n = [], 0, len(source)
    while i < n:
        if source.startswith("//", i):
            j = source.find("\n", i)
            i = n if j < 0 else j
        elif source.startswith("/*", i):
            j = source.find("*/", i)
            i = n if j < 0 else j + 2
        elif source[i] == '"':
            # String literal: buang isinya, sisakan pembatasnya supaya batas
            # antar-token tetap terjaga.
            out.append('"')
            i += 1
            while i < n and source[i] != '"':
                i += 2 if source[i] == "\\" else 1
            out.append('"')
            i += 1
        else:
            out.append(source[i])
            i += 1
    return "".join(out)


def accent_names_in_view_code(view_code):
    """Nama aksen yang benar-benar dirujuk di kode view, termasuk lewat alias.

    **Kenapa alias ikut.** `let aksen = CelestialVisual.accents` lalu
    `aksen.moonPhaseUnknown` adalah kode yang benar, dan gerbang yang merah
    padanya akan dimatikan orang. Pola `accents\\.(\\w+)` saja tidak melihatnya —
    diukur, dan itu satu-satunya keadaan "kode benar" yang merah di harness
    (`out/bukti-gerbang-aksen.py`). Yang dijaga adalah **tokennya sampai ke
    gambar**, bukan ejaan jalan yang ditempuh.

    Aliasnya dibaca dari sumber, bukan dari daftar: `<nama> = …accents` di
    mana pun menambahkan `<nama>` sebagai jalan masuk yang sah.
    """
    names = set(re.findall(r"accents\.(\w+)", view_code))
    aliases = re.findall(r"\b(\w+)\s*=\s*[\w.]*accents\b", view_code)
    for alias in aliases:
        names |= set(re.findall(re.escape(alias) + r"\.(\w+)", view_code))
    return names


def accents_reaching_the_view(model_source, view_code):
    """Nama aksen yang sampai ke gambar di `CelestialVisualView.swift`.

    **Cacat yang ditutup fungsi ini, dan kenapa daftar tangan tidak cukup.**
    `NightVisual.Accents` memuat 24 warna. Dua puluh tiga di antaranya dipakai
    view lewat namanya, jadi pemeriksaan `"<nama>" in view` biasa menangkapnya.
    Tujuh sisanya — warna langit dalam per morfologi — **tidak pernah** ditulis
    di view: ia dibaca lewat `deepSkyColour(for:)`, satu fungsi yang memetakan
    morfologi ke warnanya. Memakai daftar tangan berisi tujuh nama itu berarti
    gerbang ini menjadi **salinan ke-25** dari peta yang sudah ada, dan
    mengubah peta itu tidak membuat apa pun berbunyi.

    Jadi yang dipakai adalah **penutupan**: nama aksen yang benar-benar
    menggambar adalah yang muncul di view (termasuk lewat alias), **ditambah**
    yang muncul di dalam tubuh fungsi yang view panggil. Diturunkan dari
    sumber, bukan diketik — fungsi baru yang ditambahkan besok langsung
    terjangkau.

    Batas yang jujur: yang diukur adalah **jangkauan nama**, bukan apakah
    pikselnya benar. Fungsi yang mengembalikan warna lalu dibuang pemanggilnya
    tetap terhitung "sampai". Yang menutup itu adalah gerbang piksel
    (`check_night_mode_purity`, `check_deep_sky_layouts_match_the_model`),
    bukan fungsi ini.
    """
    reached = accent_names_in_view_code(view_code)
    # Fungsi di model yang mengembalikan aksen: nama + nama aksen di tubuhnya.
    for match in re.finditer(
            r"func\s+(\w+)\s*\([^)]*\)\s*(?:->[^{]*)?\{", model_source):
        body_start = match.end()
        depth, i = 1, body_start
        while i < len(model_source) and depth:
            if model_source[i] == "{":
                depth += 1
            elif model_source[i] == "}":
                depth -= 1
            i += 1
        body = model_source[body_start:i]
        body_accents = set(re.findall(r"accents\.(\w+)", body))
        if not body_accents:
            continue
        # Dipakai view bila **namanya** disebut di kode view.
        if re.search(r"\b" + re.escape(match.group(1)) + r"\b", view_code):
            reached |= body_accents
    return reached


def check_night_accents_reach_the_view(results, view_source=None, night_source=None):
    """Setiap warna aksen di model harus benar-benar **menggambar** di view.

    **Cacat yang ditutup.** Sampai siklus ini yang dijaga
    `check_night_accents_match_the_model` adalah **paritas nilai** antara
    `NightVisual.Accents` dan `ACCENTS` di port Python — 24 warna, dua bahasa,
    angka yang sama. Itu benar, dan ia tidak mengatakan apa pun tentang apakah
    warnanya **sampai ke layar**. Aksen yang ada di model, sama di port, dan
    tidak pernah dibaca view adalah warna yang hijau di dua gerbang sekaligus
    dan tidak menggambar apa pun.

    **Kenapa tidak `"<nama>" in view` saja.** Tujuh dari dua puluh empat warna
    (langit dalam per morfologi) memang **tidak pernah** ditulis di view: ia
    dibaca lewat `deepSkyColour(for:)`. Pemeriksaan keanggotaan biasa akan
    melaporkan tujuh warna sehat sebagai tidak terpakai, dan gerbang yang merah
    pada kode benar akan dimatikan orang. Yang dipakai karena itu penutupan
    dari sumber (`accents_reaching_the_view`), bukan daftar nama.

    **Kenapa ini bukan pemeriksaan teks biasa.** Ia mengukur satu arah yang
    tidak diukur apa pun: **himpunan** token yang sampai ke gambar. Aksen baru
    yang ditambahkan ke `Accents` tetapi tidak pernah dipakai view langsung
    berbunyi di sini — dan itu tepat kelas yang paling sunyi, karena setiap
    gerbang lain tetap hijau sementara warna itu tidak pernah tampil.
    """
    view = view_source if view_source is not None else open(
        os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()
    night = night_source if night_source is not None else open(
        os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                          "NightVisual.swift")).read()
    try:
        in_model = set(swift_night_accents(night))
    except ValueError as error:
        results.append(Result(
            "aksen gambar: blok `accents` terbaca dari model", False, str(error)))
        return
    if not in_model:
        results.append(Result(
            "aksen gambar: blok `accents` terbaca dari model", False,
            "blok `static let accents = Accents(` terbaca tetapi nol warna "
            "terurai — gerbang yang tidak menemukan apa pun tidak boleh lulus"))
        return
    # Sumber penutupan: **NightVisual.swift**, tempat `Accents` dan
    # `deepSkyColour(for:)` sama-sama tinggal. Membacanya dari CelestialVisual
    # melewatkan pemetaan morfologinya, dan tujuh warna langit dalam akan
    # dilaporkan tidak terpakai.
    reached = accents_reaching_the_view(night, swift_code_only(view))
    missing = sorted(in_model - reached)
    results.append(Result(
        "aksen gambar: setiap warna model sampai ke view", not missing,
        f"{len(reached)} dari {len(in_model)} terjangkau"
        + (f", tidak dipakai: {missing}" if missing else "")))
    # Arah sebaliknya: nama yang view pakai tetapi tidak ada di model berarti
    # view membaca aksen yang tidak pernah didefinisikan — warna yang jatuh ke
    # nilai bawaan tanpa ada yang tahu.
    unknown = sorted(reached - in_model)
    results.append(Result(
        "aksen gambar: view tidak memakai nama di luar model", not unknown,
        f"{unknown} dipakai view tetapi tidak ada di NightVisual.Accents"
        if unknown else "semua nama yang dipakai view ada di model"))


def check_unknown_moon_disc_uses_the_token(results, view_source=None):
    """Piringan "fase tidak diketahui" harus menggambar lewat token model.

    **Cacat yang ditutup, dan kenapa ia tidak boleh menjadi pemeriksaan teks
    biasa.** Piringan ini dulu digambar `Self.accent(CelestialVisual.accents.
    moonPhaseUnknown)`. Sampai commit `7ae4845` ada entri gerbang yang menuntut
    potongan itu **tertulis di view** — dan commit berikutnya menggantinya
    dengan `Self.fillSphere(…, base: CelestialVisual.accents.moonPhaseUnknown)`.
    Faktanya tetap, gambarnya malah lebih benar (bola, bukan cakram), dan
    **`main` merah di CI selama dua commit**. Yang merah bukan pemakaiannya,
    melainkan ejaan yang sudah dibuang.

    Kelas cacatnya sudah berulang di repo ini: gerbang yang mengukur **cara
    menulis** sesuatu, bukan **hal yang ditulisnya**. Ia lulus selama bentuknya
    tidak berubah, dan menghukum setiap perbaikan bentuk sesudahnya — jadi
    biaya menjaganya lebih besar dari yang dijaganya.

    Penggantinya dua keadaan yang tidak bisa dipenuhi bersama oleh warna tetap:

      1. `accents.moonPhaseUnknown` muncul di **kode** view — komentar dan
         string dibuang lebih dulu (`swift_code_only`). Tanpa itu,
         `// TODO kembalikan CelestialVisual.accents.moonPhaseUnknown` di atas
         baris yang sudah diganti akan hijau.
      2. Tidak ada `Color(red:…)` di dalam `drawMoon` — warna tetap yang
         menyerupai token adalah bentuk paling sunyi dari cacat ini: tokennya
         masih "dipakai" di tempat lain, dan piringannya kembali kelabu tetap.

    Batas yang jujur: yang diukur adalah **token sampai ke fungsi menggambar**,
    bukan bahwa piringannya kelabu 0.52. Yang menutup itu gerbang piksel
    (`check_unknown_phase_is_not_a_new_moon`), yang mengukur PNG-nya.

    `view_source` hanya dipakai harness mutasi supaya ia bisa menjalankan
    pemeriksaan yang **sama** tanpa merender seluruh katalog (gerbang penuh
    ~6 menit; memanggil langsung <1 detik). Bukan jalur kedua yang bisa
    berbeda: nilai bawaannya membaca berkas yang sama.
    """
    view = view_source if view_source is not None else open(
        os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()
    in_code = "moonPhaseUnknown" in accent_names_in_view_code(swift_code_only(view))
    results.append(Result(
        "piringan fase tak diketahui: dipakai di kode view", in_code,
        "'CelestialVisual.accents.moonPhaseUnknown' "
        f"{'ditemukan' if in_code else 'TIDAK ditemukan'} di kode "
        "CelestialVisualView.swift (komentar & string dibuang)"))
    body = _function_body(view, "func drawMoon(")
    if not body:
        results.append(Result(
            "piringan fase tak diketahui: view tidak menulis warnanya sendiri", False,
            "'func drawMoon(' TIDAK ditemukan di CelestialVisualView.swift — "
            "pemeriksaan ini tidak bisa dijalankan, dan itu merah, bukan lulus"))
        return
    literal = re.search(r"Color\(\s*red:", body)
    results.append(Result(
        "piringan fase tak diketahui: view tidak menulis warnanya sendiri",
        literal is None,
        "drawMoon memuat `Color(red:…)` yang ditulis langsung: "
        f"{body[literal.start():literal.start() + 40]!r}" if literal else
        "drawMoon menggambar lewat token model, tanpa warna tetap"))


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
        # Kekuatan pemulihan peredupan limb di atas pita. Angka ini **bukan**
        # hiasan: pada 0 pita menghapus lengkung bola (cacat terukur 20.8% vs
        # 50.6%), pada 1 pitanya tertutup bola. Ia hidup di model supaya view,
        # port Python, dan uji Linux membaca angka yang sama — dan supaya
        # mengubahnya di satu tempat saja membuat pemeriksaan ini merah.
        ("kekuatan pemulihan limb di atas pita", R.BAND_LIMB_SHADING_STRENGTH, 0.6,
         "bandLimbShadingStrength: Double = 0.6", model),
        # Peredupan limb piringan Bulan. Dua angka, keduanya diukur terhadap
        # render: 0.40 adalah kekuatan yang dipakai (purnama +33.5% lengkung,
        # gerbang fase 9/9), dan 1.15 adalah radius akhir gradiennya (purnama
        # +33.5%, sabit 24.1; dengan 1.35 milik bola planet keduanya melemah
        # jadi +28.5% dan 20.9).
        ("kekuatan peredupan limb Bulan", R.MOON_LIMB_SHADING_STRENGTH, 0.40,
         "moonLimbShadingStrength: Double = 0.40", model),
        ("radius akhir gradien bola Bulan", R.MOON_SPHERE_GRADIENT_END_RADIUS, 1.15,
         "moonSphereGradientEndRadius: Double = 1.15", model),
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
        # Arah kedua: piringan "fase tidak diketahui" harus benar-benar
        # menggambar lewat token model, bukan warna tetap di view.
        #
        # **Entri ini dulu menuntut sebuah ejaan, dan `main` merah karenanya.**
        # Bunyinya `"Self.accent(CelestialVisual.accents.moonPhaseUnknown)" in
        # view` — potongan yang dipakai view *sebelum* piringan itu menjadi
        # bola. Commit berikutnya menggantinya dengan `Self.fillSphere(…, base:
        # CelestialVisual.accents.moonPhaseUnknown)`: **faktanya tetap**, dan
        # justru lebih kuat (bola, bukan cakram). Yang merah bukan pemakaiannya,
        # melainkan ejaan yang sudah dibuang — dan gerbang yang menuntut ejaan
        # akan menghukum setiap perbaikan bentuk sesudahnya.
        #
        # Pemeriksaannya pindah ke `check_unknown_moon_disc_uses_the_token()`,
        # di luar tabel `checks`, karena tabel itu membandingkan satu potongan
        # teks di **dua** tempat: di sini (potongan harus tertulis di view) dan
        # di `check_port_matches_swift_constants` (potongan yang sama harus
        # tertulis di model). Penggantinya bukan satu potongan melainkan
        # **predikat atas kode view**, jadi ia tidak bisa dibentuk sebagai
        # pasangan `port_value`/`source_text` tanpa mengarang salah satunya.
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
        # Pemulihan peredupan limb di atas bintik. **Kelas cacat yang sama
        # dengan pita**, dan gerbang piksel yang menjaganya punya lubang yang
        # sama: `check_banded_disc_keeps_its_curvature` mengukur baris ekuator,
        # sementara bintiknya duduk di +0.31 R. Angka ini hidup di model supaya
        # view, port Python, dan uji Linux membaca angka yang sama — dan supaya
        # mengubahnya di satu tempat saja membuat pemeriksaan ini merah.
        ("kekuatan pemulihan limb di atas bintik", R.JUPITER_SPOT_LIMB_SHADING_STRENGTH,
         0.6, "jupiterSpotLimbShadingStrength: Double = 0.6", model),
        # Arah kedua: pemulihan itu harus benar-benar **dipanggil** di view dan
        # di port. Pemeriksaan piksel di atas mengukur port; ia tidak bisa
        # melihat view berhenti memanggilnya, atau memanggilnya dengan angka
        # yang ditulis ulang alih-alih dibaca dari model.
        ("pemulihan limb bintik dipanggil di view (bukan ditulis ulang)",
         "opacity: CelestialVisual.jupiterSpotLimbShadingStrength" in view, True,
         "opacity: CelestialVisual.jupiterSpotLimbShadingStrength", view),
        ("port memakai konstanta JUPITER_SPOT_LIMB_SHADING_STRENGTH-nya sendiri",
         "opacity=JUPITER_SPOT_LIMB_SHADING_STRENGTH" in port
         and "JUPITER_SPOT_LIMB_SHADING_STRENGTH = " in port, True,
         "opacity=JUPITER_SPOT_LIMB_SHADING_STRENGTH", port),
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
        # Opasitas spike: **pangkal**-nya, karena ujungnya selalu nol. Ujung
        # yang berhenti dengan opasitas sisa tampak terpotong, bukan memudar.
        ("opasitas spike bintang: port == model", R.SPIKE_OPACITY, 0.45,
         "spikeOpacity: Double = 0.45", model),
        # **Baji, bukan batang.** Versi lama menggambar keempat spike sebagai
        # satu `Path` yang di-stroke dengan `lineWidth` tetap: batang sama
        # tebal dari pangkal ke ujung, berujung rata. Pada ukuran kartu jam
        # (38 pt) bentuk itu terbaca sebagai penanda bidik, bukan cahaya.
        #
        # Dua entri lama di sini (`tebal spike bintang: port == view` dan
        # `...: view menulisnya`) **dihapus, bukan diperbarui**: keduanya
        # menjaga sebuah angka lebar dengan mencari ejaan `coreRadius * 0.18`,
        # dan bentuk yang dijaganya sudah tidak digambar lagi. Yang
        # menggantikannya mengukur fakta yang menentukan — ujung spike harus
        # lebih tipis daripada pangkalnya — karena satu angka lebar tidak bisa
        # lagi menyatakan bentuk ini. Sisi Linux-nya dijaga
        # `testStarSpikesTaperTowardsTheirTips`.
        ("spike bintang: ujung lebih tipis dari pangkal (model)",
         "spikeRootWidthFactor: Double = 0.18" in model
         and "spikeTipWidthFactor: Double = 0.035" in model, True,
         "spikeTipWidthFactor: Double = 0.035", model),
        ("spike bintang: ujung lebih tipis dari pangkal (port)",
         R.SPIKE_TIP_WIDTH_FACTOR < R.SPIKE_ROOT_WIDTH_FACTOR
         and abs(R.SPIKE_ROOT_WIDTH_FACTOR - 0.18) < 1e-9
         and abs(R.SPIKE_TIP_WIDTH_FACTOR - 0.035) < 1e-9, True,
         "SPIKE_TIP_WIDTH_FACTOR = 0.035", port),
        ("spike bintang: view mengisi baji, bukan men-stroke garis",
         "context.fill(wedge, with: .linearGradient(" in view, True,
         "context.fill(wedge, with: .linearGradient(", view),
        # Glif "?" kandidat tetap satu faktor lebar garis. `0.28` mengatur
        # menebalkan **tanda ketidakpastian**: glif yang terlalu tipis hilang
        # di layar jam, dan itu menghapus satu-satunya penanda visual bahwa
        # engine sedang **ragu** — PRD v0.4: jangan pernah menampilkan visual
        # yang mengklaim identitas saat engine ragu. Menipiskan glif sampai
        # tak terlihat menghapus penanda itu secara senyap.
        # Bukti audit mutasi: VIEW 0.28 -> 0.60 → 313 pemeriksaan, 0 gagal.
        # Badge: **himpunan**, bukan satu angka — dan bukan himpunan yang
        # harus sama, karena jumlah situsnya memang berbeda (port punya dua:
        # geometri bersatuan radius frame dan penggambar bersatuan piksel;
        # view cuma satu). Bandingkan **nilai yang unik dari masing-masing**:
        # `{0.28}` vs `{0.28}` benar, `{0.28}` vs `{0.28, 0.12}` salah.
        # Membandingkan hanya yang pertama membuat mutasi di
        # `_draw_candidate_marker` sunyi — dibuktikan sebelum himpunan dipakai:
        # `0.28 -> 0.12` di sana tidak membuat satu pun pemeriksaan merah.
        ("tebal glif kandidat: port == view",
         _same_stroke_factors(badge_stroke(view), badge_stroke(port)),
         True, "badge_radius * 0.28", port, "render-visuals.py"),
        ("tebal glif kandidat: view menulisnya",
         view.count("badgeRadius * 0.28") == 1, True,
         "lineWidth: max(1, badgeRadius * 0.28))", view,
         "CelestialVisualView.swift"),
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
        #
        # **Opasitas dasar kawah: entri ini dulu berbunyi `0.85` di kedua
        # sisi**, dan justru itu cacatnya. Ia menjaga sebuah konstanta tetap
        # (`CRATER_FLOOR_OPACITY = 0.85`) yang **menutupi** nilai model: view
        # dan port sama-sama menulis 0.85, sementara `craterRelief` sudah
        # menghitung `floorDepth` per kawah (maksimum 0.22) dan
        # mendokumentasikannya sebagai "kelegapan lapisan hitam". Karena kedua
        # bahasa sepakat pada angka yang salah, gerbang ini hijau sambil
        # mengunci gambar yang cacat — kawah tergambar sebagai cakram gelap
        # rata, bukan cekungan. Sekarang yang dijaga adalah **pemakaian** nilai
        # model itu, bukan keberadaan konstanta tetap. Lihat
        # `check_crater_floor_opacity_comes_from_the_model`.
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
        # Nilai boolean tidak ditampilkan sebagai `True`/`False`: pesannya
        # jadi tidak mengatakan apa pun. Untuk pemeriksaan yang memang
        # membandingkan nilai, tampilkan angkanya; untuk yang membandingkan
        # syarat, tampilkan syaratnya.
        shown = (f"port={port_value}, seharusnya {expected}"
                 if not isinstance(port_value, bool)
                 else "terpenuhi" if port_value else "TIDAK terpenuhi")
        results.append(Result(
            f"port sejalan: {label}", port_value == expected,
            f"{shown}, seharusnya {expected}"))
        results.append(Result(
            f"sumber memuat: {label}", source_text in source,
            f"'{source_text}' {'ditemukan' if source_text in source else 'TIDAK ditemukan'}"
            f" di {where}"))


def read_planet_switch_cases_from_swift(source):
    """Nama planet dari `case .nama:` di dalam `switch` `var palette`.

    **Kenapa dari `switch`, bukan dari `Planet.allCases`.** Nama kasus enum
    tidak muncul sebagai teks di berkas sumber: `Planet.allCases` adalah
    ekspresi, jadi membaca teksnya hanya membuktikan bahwa *sesuatu* memakai
    `allCases`, bukan planet mana saja yang ada. Yang benar-benar tertulis
    per planet adalah cabang `switch`-nya, dan itulah daftar yang harus
    sepakat dengan daftar kasus render.
    """
    anchor = "var palette: CelestialVisual.Palette {"
    if anchor not in source:
        raise ValueError("'var palette' tidak ditemukan di CelestialVisual.swift")
    region = source[source.index(anchor):]
    # Wilayahnya berhenti di penutup fungsi, bukan di EOF. Tanpa batas ini,
    # `case .nama:` dari **switch mana pun** di bawahnya ikut terbaca — dan
    # `CelestialVisual.swift` punya beberapa. Membaca melewati batas fungsi
    # adalah jebakan yang sama yang baru saja ditemukan di pembaca kunci
    # penggambar langit dalam.
    closing = region.find("\n    }")
    if closing != -1:
        region = region[:closing]
    names = re.findall(r"case \.(\w+):", region)
    if not names:
        raise ValueError("tidak ada 'case .nama:' di dalam switch palet")
    return names


def check_every_planet_in_the_model_has_render_cases(results):
    """Setiap planet di model harus punya **pasangan kasus render**-nya.

    **Cacat yang ditutup pemeriksaan ini.** Dua daftar planet ditulis dengan
    tangan di `render-visuals.py` — lima nama di `build_cases()`, dan lima
    pasangan lagi di `check_features_disappear_when_uncertain` — sementara
    sumber kebenarannya adalah `switch` di `CelestialVisual.Planet.palette`.
    Tidak ada satu pun pemeriksaan yang mengikat ketiganya.

    **Keadaan yang benar-benar sunyi — diukur, bukan ditebak.** Harness
    `out/bukti-planet-uranus.py` bagian B menjalankan `main()` penuh dengan
    gerbang ini dikeluarkan, di atas sumber yang dimutasi:

    ```
    [baseline]                          409 pemeriksaan, 0 gagal  <- hijau
    uranus di model saja                410 pemeriksaan, 1 gagal  <- MERAH
      GAGAL palet planet: uranus ada di kedua sisi
    uranus di model + port              412 pemeriksaan, 0 gagal  <- hijau
    ```

    Baris kedua penting karena ia **membantah versi pertama docstring ini**,
    yang mengklaim planet baru "membiarkan seluruh 409 pemeriksaan hijau".
    Menambah `.uranus` di model saja memang **merah** — tapi oleh gerbang drift
    yang sudah ada (`palet planet: uranus ada di kedua sisi`), bukan oleh
    gerbang ini. Jadi klaim itu salah, dan yang benar justru lebih sempit
    sekaligus lebih berbahaya: keadaan sunyinya adalah ketika **kedua bahasa
    sepakat**. Di sana drift tidak ada untuk diberitakan, seluruh 412
    pemeriksaan hijau, dan `uranus` tidak pernah muncul di satu pun gambar
    yang diukur.

    Yang hilang di keadaan itu bukan gerbang baru, melainkan **gerbang yang
    berlaku untuk planet itu**: aturan "ciri pengenal hilang saat ragu" dan
    aturan "ciri pengenal masih terukur pada 38 pt" keduanya hanya berjalan
    pada pasangan kasus yang ada. Planet baru tampil di jam dengan pita
    Uranus yang **tidak pernah diukur hilang** saat engine ragu — klaim
    identitas di layar, dan pelanggaran PRD yang paling sulit terlihat karena
    tidak ada yang salah untuk dilihat.

    Tiga hal diperiksa, semuanya diturunkan dari model:

      1. Setiap planet di `switch` palet punya kasus `planet-<nama>-confirmed`.
      2. Setiap planet dengan ciri **bukan** `.none` punya pasangan
         `planet-<nama>-uncertain` — tanpa itu, aturan kejujuran tidak
         berlaku untuk planet itu.
      3. Kedua gerbang ciri (`check_features_disappear_when_uncertain` dan
         `check_features_survive_the_watch_size`) memuat **pasangan yang
         sama** dengan yang diturunkan. Gerbang yang kehilangan satu pasangan
         akan tetap hijau untuk empat planet sisanya.

    Daftar `pairs` dibaca dari **sumber berkas ini sendiri**, bukan dari
    variabel lokal — variabel lokal sudah hilang saat gerbang lain selesai.
    """
    model_path = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                                   "CelestialVisual.swift")
    try:
        planets = read_planet_palettes_from_swift(open(model_path, encoding="utf-8").read())
        switch_names = read_planet_switch_cases_from_swift(
            open(model_path, encoding="utf-8").read())
    except ValueError as exc:
        results.append(Result("kasus render planet: terbaca dari model", False, str(exc)))
        return

    if set(planets) != set(switch_names):
        results.append(Result(
            "kasus render planet: switch palet & tabel palet sepakat",
            False,
            f"hanya di tabel: {sorted(set(planets) - set(switch_names))}, "
            f"hanya di switch: {sorted(set(switch_names) - set(planets))}"))
    else:
        results.append(Result(
            "kasus render planet: switch palet & tabel palet sepakat",
            True, f"{len(planets)} planet"))

    names = {case.name for case in R.build_cases()}
    missing_confirmed = sorted(n for n in planets if f"planet-{n}-confirmed" not in names)
    results.append(Result(
        "kasus render planet: setiap planet di model punya kasus terkunci",
        not missing_confirmed,
        f"{len(planets)} planet" if not missing_confirmed
        else f"tidak ada kasus render: {missing_confirmed} — planet itu tampil di jam "
             "tanpa satu pun gerbang gambar"))

    featured = sorted(n for n, (_, _, feature) in planets.items() if feature != "none")
    missing_uncertain = sorted(n for n in featured if f"planet-{n}-uncertain" not in names)
    results.append(Result(
        "kasus render planet: setiap planet berciri punya kasus ragu",
        not missing_uncertain,
        f"{len(featured)} planet berciri: {featured}" if not missing_uncertain
        else f"tidak ada kasus 'ragu': {missing_uncertain} — aturan 'ciri hilang saat ragu' "
             "tidak berlaku untuk planet itu"))

    # Ciri yang tidak dimiliki planet mana pun adalah ciri mati: ia ada di
    # enum, tidak digambar siapa pun, dan menambahkannya ke planet baru akan
    # tampak seperti pekerjaan yang sudah selesai.
    used = {feature for _, _, feature in planets.values()}
    dead = sorted({"bands", "rings", "polarCaps", "craters", "haze"} - used)
    results.append(Result(
        "kasus render planet: tidak ada ciri yang tidak dipakai planet mana pun",
        not dead, "kelimanya dipakai" if not dead else f"ciri tanpa planet: {dead}"))

    # Kedua gerbang ciri harus memuat pasangan yang sama dengan model.
    self_source = open(os.path.abspath(__file__), encoding="utf-8").read()
    expected = {(f"planet-{n}-confirmed", f"planet-{n}-uncertain") for n in featured}
    for fn, label in (("check_features_disappear_when_uncertain", "gerbang ciri hilang saat ragu"),
                      ("check_features_survive_the_watch_size", "gerbang ciri pada ukuran jam")):
        if f"def {fn}(" not in self_source:
            results.append(Result(f"kasus render planet: {label} terbaca", False,
                                  f"'def {fn}(' tidak ditemukan"))
            continue
        region = self_source[self_source.index(f"def {fn}("):]
        following = region.find("\ndef ", 1)
        if following != -1:
            region = region[:following]
        found = set(re.findall(
            r'\("planet-(\w+)-confirmed",\s*"planet-\w+-uncertain"', region))
        pairs = {(f"planet-{n}-confirmed", f"planet-{n}-uncertain") for n in found}
        # Nama pasangan yang tertukar (mis. `-confirmed` dipasangkan dengan
        # planet lain) juga harus tertangkap, jadi kedua sisi diperiksa.
        found_uncertain = set(re.findall(
            r'\("planet-(\w+)-confirmed",\s*"planet-(\w+)-uncertain"', region))
        swapped = sorted(a for a, b in found_uncertain if a != b)
        results.append(Result(
            f"kasus render planet: {label} memuat semua pasangan model",
            pairs == expected and not swapped,
            f"{len(pairs)} pasangan" if pairs == expected and not swapped
            else (f"hilang: {sorted(expected - pairs)}, "
                  f"berlebih: {sorted(pairs - expected)}"
                  + (f", tertukar: {swapped}" if swapped else ""))))


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


def read_venus_haze_from_swift(source):
    """Baca **ketiga** bawaan `CelestialVisual.venusHaze()` dari teks Swift.

    **Kenapa pembaca ini ada.** Geometri kabut Venus hidup di tiga tempat:
    bawaan parameter `CelestialVisual.venusHaze` di Swift (dipakai view), tiga
    konstanta `VENUS_HAZE_*` di port Python (dipakai `venus_haze()`), dan
    pemanggilannya di kedua situs port. Sampai pembaca ini ditulis, hanya
    **keberadaan pemanggilan** yang dijaga — `venus_haze()` memang dipanggil
    di `_draw_haze` dan `_draw_planet`, jadi pemeriksaan itu hijau — sementara
    **angkanya sendiri tidak dibandingkan siapa pun**. Mutasi terbukti:
    `VENUS_HAZE_HALF_WIDTH 0.55 -> 0.70`, `HALF_HEIGHT 0.72 -> 0.45`, dan
    `CENTER_Y 0.0 -> 0.30` masing-masing membiarkan seluruh 348 pemeriksaan
    hijau, dan mutasi bawaannya di Swift (`0.55 -> 0.70`, `0.72 -> 0.50`)
    membiarkan 348 pemeriksaan hijau sekaligus **tiga uji Swift merah** —
    jadi sisi port benar-benar tanpa penjaga apa pun.

    Yang hilang kalau angkanya bergeser: elips kabut Venus pindah atau
    berubah bentuk di PNG, sementara gerbang piksel Venus berfase terus
    mengukur gambar yang **tidak** tampil di jam — persis cacat 0.14 R yang
    dulu ditutup, hanya dari arah lain.

    Mengembalikan `(center_y, half_width, half_height)` sebagai `float`, atau
    `None` bila bentuk fungsinya tidak dikenali (pemanggil yang memutuskan
    apa artinya, bukan pengecualian tersembunyi).
    """
    match = re.search(
        r"public static func venusHaze\([\s\S]{0,400}?\)\s*->\s*HazeGeometry",
        source)
    if match is None:
        return None
    signature = match.group(0)
    values = {}
    for name in ("centerY", "halfWidth", "halfHeight"):
        found = re.search(
            rf"{name}:\s*Double\s*=\s*(-?\d+(?:\.\d+)?)", signature)
        if found is None:
            return None
        values[name] = float(found.group(1))
    return values["centerY"], values["halfWidth"], values["halfHeight"]


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
    # Nilai **bawaan** parameter `elongation`, dibaca dari tanda tangannya.
    # Port menyimpan cangkang `.planetaryNebula` **sebelum** dipetkan, jadi
    # pembandingnya adalah cabang model pada bawaan itu — bukan 1.0 yang
    # ditulis ulang di sini (itu akan jadi salinan yang tidak pernah
    # dibandingkan, persis kelas cacat yang sedang ditutup gerbang ini).
    default_elongation = re.search(r"elongation: Double = ([\d.]+)", region)
    if default_elongation is None:
        raise ValueError(
            "'elongation: Double = <angka>' tidak ditemukan di "
            "CelestialVisual.swift — pembanding cangkang butuh bawaannya")
    default_elongation = float(default_elongation.group(1))
    for name in ("planetaryNebula", "galaxy", "spiralGalaxy", "openCluster",
                 "globularCluster"):
        marker = f"case .{name}:"
        if marker not in region:
            raise ValueError(f"'{marker}' tidak ditemukan di CelestialVisual.swift")
        tail = region[region.index(marker):]
        # `.planetaryNebula` menyusun layout lewat `zip` dari `ring`, jadi
        # angkanya tidak berbentuk larik segi-enam — ia punya pembacaan
        # sendiri, dan tanpa itu bentuk ini akan dilaporkan "hilang".
        if "let ring:" in tail[:tail.index("return buildDeepSky")]:
            out[name] = _shell_layout_from_swift(tail, default_elongation)
            continue
        out[name] = swift_sextuples(tail, "let layout: [(Double, Double, "
                                          "Double, Double, Double, Double)] = [")
    return out


def _shell_layout_from_swift(tail, default_elongation):
    """Layout cangkang `.planetaryNebula` dari `ring` + `shellOpacity`.

    Modelnya **tidak** menulis enam angka per blob: ia menulis posisi
    (`ring`) dan opasitasnya (`shellOpacity`), lalu menggabungkannya dengan
    skala lebar `0.26`, rasio sumbu `1.0`, sudut `0.0`. Port Python menyimpan
    hasil gabungan itu. Jadi yang dibandingkan di sini adalah **hasil** yang
    sama, dihitung dari bentuk sumbernya — bukan angka yang disalin.

    **Kenapa `ring` tidak lagi dibaca sebagai daftar pasangan literal.**
    Sejak cangkangnya dirapatkan (16 → 24 titik @15°), posisinya **dihitung**
    dari satu radius dan satu langkah sudut, bukan ditulis satu per satu:
    `(0..<24).map { ... cos(angle), sin(angle) }`. Yang bisa salah karena itu
    berpindah — bukan lagi "apakah dua puluh empat pasangan angkanya sama",
    melainkan "apakah radius, langkah sudut, dan jumlahnya sama". Pembacaan
    pun mengikuti: ketiganya dibaca dari sumber, dan **rumusnya** ikut
    dijaga. Jangkar `(shellRadius * cos(angle), shellRadius * sin(angle))`
    sengaja dicari: tanpa itu, sebuah suntingan yang mengembalikan daftar
    literal akan membuat pembacaan ini menghitung dua puluh empat posisi yang
    **tidak** dipakai model — dan gerbangnya akan membandingkan tabel port
    dengan angka karangan sendiri.

    **Kenapa `default_elongation`, dan kenapa dua faktor terakhir dibaca
    dari sumbernya.** Sejak M27 (Dumbel) dan M57 (Cincin) berbagi morfologi
    `.planetaryNebula` tetapi berbeda bentuk di layar, kedua komponen y tiap
    blob dikalikan `elongation` **saat menggambar**. Port menyimpan
    cangkangnya **bulat** (itulah bentuknya sebelum dipetkan) dan menerapkan
    pemetaan yang sama di `deep_sky_blobs` lewat `DEEP_SKY_ELONGATION`. Jadi
    yang setara dengan tabel port adalah cabang model pada **bawaan**
    `elongation`, bukan pada nilai M27. Kalau faktornya tidak dibaca dari
    sumber, gerbang ini akan merah pada kode yang benar begitu modelnya
    dirapikan — dan gerbang yang berisik seperti itu dihapus orang.

    Dua faktor itu sendiri **tidak dibandingkan nilainya** di sini (keduanya
    sama-sama `elongation`); yang dijaga tetap ada dan berbentuk `* <nama>`,
    supaya tidak ada satu pun komponen y yang diam-diam berhenti dipetkan
    tanpa membuat pembacaan ini gagal bersih.
    """
    # Posisi blob kini **dihitung**, bukan didaftar: satu radius, satu langkah
    # sudut, satu jumlah. Ketiganya dibaca dari sumber, lalu posisinya
    # dibangun ulang dengan rumus yang sama. Jangkar rumusnya
    # (`(shellRadius * cos(angle), shellRadius * sin(angle))`) dicari lebih
    # dulu supaya daftar literal yang kembali tidak diam-diam "dibaca" sebagai
    # dua puluh empat posisi hasil hitungan sendiri.
    formula = ("(shellRadius * cos(angle), shellRadius * sin(angle))")
    if formula not in tail:
        raise ValueError(
            "'(shellRadius * cos(angle), shellRadius * sin(angle))' tidak "
            "ditemukan di cabang .planetaryNebula — posisi blob cangkang harus "
            "tetap dihitung dari satu radius dan satu langkah sudut")
    # `_required` bukan hiasan: tanpa itu `re.search(...).group(1)` melempar
    # `AttributeError: 'NoneType'` — kegagalan yang tidak menyebut jangkar
    # mana yang hilang, dan gerbang yang berisik seperti itu dihapus orang
    # begitu ia berbunyi. Pola yang sama dengan `read_planet_switch_cases_from_swift`.
    def _required(pattern, label):
        match = re.search(pattern, tail)
        if match is None:
            raise ValueError(
                f"'{label}' tidak ditemukan di cabang .planetaryNebula")
        return float(match.group(1))

    shell_radius = _required(r"let shellRadius = ([\d.]+)", "let shellRadius")
    shell_step = _required(r"let shellStep = ([\d.]+)", "let shellStep")
    ring_count = int(_required(r"\(0\.\.<(\d+)\)\.map", "(0..<N).map"))
    pairs = [(shell_radius * math.cos(math.radians(shell_step * i)),
              shell_radius * math.sin(math.radians(shell_step * i)))
             for i in range(ring_count)]
    # Opasitas diambil **berputar** lewat `index % shellOpacity.count`, jadi
    # yang menentukan panjang gelombangnya adalah jumlah entri di
    # `shellOpacity` — bukan `ring`. Dibaca dari sumbernya supaya menambah
    # atau mengurangi entri di sana tidak membuat tabel ini diam-diam salah
    # panjang.
    opacities = [float(v) for v in re.search(
        r"let shellOpacity = \[([\d.,\s]+)\]", tail).group(1).split(",")]
    if not re.search(r"shellOpacity\[index % shellOpacity\.count\]", tail):
        raise ValueError(
            "'shellOpacity[index % shellOpacity.count]' tidak ditemukan di "
            "cabang .planetaryNebula — opasitas harus diambil berputar, bukan "
            "di-zip (zip memotong cangkangnya jadi 16 blob lagi)")
    # `aspect` dan `angle` masih ditulis apa adanya (angka), tetapi `offset.1`
    # dan `aspect` kini dikalikan `elongation` — jadi keduanya dibaca dari
    # sumbernya, dengan nilai bawaannya disubstitusi supaya hasilnya setara
    # dengan tabel port yang belum dipetakan.
    width_scale = _required(r"\(offset\.0, offset\.1 \* elongation, ([\d.]+),",
                            "skala lebar blob cangkang")
    rest = re.search(
        r"([\d.]+) \* elongation,\s*(-?[\d.]+),\s*shellOpacity", tail)
    if rest is None:
        raise ValueError(
            "'<aspect> * elongation, <sudut>, shellOpacity[...]' tidak "
            "ditemukan di cabang .planetaryNebula — kedua komponen y harus "
            "tetap dipetakan elongasi supaya tabel ini setara dengan port")
    aspect, angle = float(rest.group(1)), float(rest.group(2))
    out = []
    for index, (xs, ys) in enumerate(pairs):
        out.append((float(xs), float(ys) * default_elongation, width_scale,
                    aspect, angle, opacities[index % len(opacities)]))
    return out


def read_deep_sky_morphology_cases_from_swift(source):
    """Nama kasus `Morphology` dari teks `DeepSkyCatalogue.swift`.

    **Kenapa dari `case .nama:` di dalam enum, bukan dari `allCases`.**
    Sama persis dengan `read_planet_switch_cases_from_swift`: nama kasus enum
    tidak muncul sebagai teks di berkas sumber, jadi membaca `allCases` hanya
    membuktikan bahwa *sesuatu* memakai `allCases`, bukan morfologi mana saja
    yang ada. Yang benar-benar tertulis per morfologi adalah `case`-nya, dan
    itulah daftar yang harus sepakat dengan daftar kasus render.

    Wilayahnya dipotong di penutup enum — tanpa itu, `case .nama:` dari
    `switch` mana pun di bawahnya ikut terbaca, dan berkas ini punya
    beberapa.
    """
    anchor = "public enum Morphology: String, Equatable, Sendable, CaseIterable {"
    if anchor not in source:
        raise ValueError(
            "'public enum Morphology' tidak ditemukan di DeepSkyCatalogue.swift")
    region = source[source.index(anchor):]
    closing = region.find("\n    }")
    if closing != -1:
        region = region[:closing]
    names = re.findall(r"case (\w+)", region)
    if not names:
        raise ValueError("tidak ada 'case .nama' di dalam enum Morphology")
    return names


def swift_star_colour_index(source):
    """Tabel `starColorIndex` dari teks Swift → `{id: indeks B−V}`.

    Dibaca dari sumber, bukan ditulis ulang: tabel ini 25 entri, dan tabel
    tangan di gerbang akan menjadi **entri ke-26 yang tidak pernah
    dibandingkan** — persis lubang yang sedang ditutup di sini.
    """
    anchor = "static let starColorIndex: [String: Double] = ["
    if anchor not in source:
        raise ValueError(
            "'static let starColorIndex' tidak ditemukan di CelestialVisual.swift")
    start = source.index(anchor) + len(anchor)
    region = source[start:source.index("\n    ]", start)]
    return {name: float(value) for name, value in re.findall(
        r'"(\w+)":\s*(-?[\d.]+)', region)}


def check_star_colour_index_matches_the_model(results):
    """Tabel B−V per bintang tidak boleh menyimpang antar bahasa.

    **Cacat yang ditutup pemeriksaan ini.** 25 indeks warna hidup di
    `CelestialVisual.starColorIndex` dan lagi di `STAR_COLOR_INDEX` pada
    port. Tidak ada yang membandingkan keduanya — dan setiap pemeriksaan
    warna bintang yang ada sekarang mengukur **gambar port**, jadi
    mengubah salah satu nilai di Swift membiarkan semuanya hijau sambil
    mengukur warna yang tidak pernah ada. Itu kelas cacat yang sama
    persis dengan palet planet, kawah, maria, profil Matahari, relief
    kawah, dan tata letak langit dalam.

    Yang membuatnya lebih dari sekadar daftar yang panjang: **tanda**-nya
    adalah identitas. Betelgeuse +1.85 harus merah, Rigel −0.03 biru.
    Tanda yang terbalik tidak akan pernah dilaporkan pengguna — bintang
    tetap tampak sebagai titik bercahaya — karena itu ia diuji di sini,
    bukan dibiarkan sampai ada yang melihatnya di layar.

    Dua arah, seperti gerbang tetangganya: merah kalau port menyimpang,
    kalau model kehilangan bintang yang masih ada di port, dan kalau
    port punya bintang sisa. Tidak ada yang merah kalau keduanya diubah
    bersama dengan nilai yang sama — dan itu memang bukan cacat.
    """
    source = open(os.path.join(
        ROOT, "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift")).read()
    try:
        swift = swift_star_colour_index(source)
    except ValueError as exc:
        results.append(Result("indeks warna bintang: terbaca dari model",
                              False, str(exc)))
        return

    port = R.STAR_COLOR_INDEX

    missing = sorted(set(swift) - set(port))
    results.append(Result(
        "indeks warna bintang: setiap bintang model ada di port",
        not missing,
        f"semua {len(swift)} bintang ada" if not missing
        else f"tidak ada di port: {missing}"))

    extra = sorted(set(port) - set(swift))
    results.append(Result(
        "indeks warna bintang: tidak ada bintang sisa di port",
        not extra,
        "tidak ada" if not extra else f"hanya ada di port: {extra}"))

    # Per bintang, bukan "tabel sama": kalau ada yang menyimpang, pesannya
    # harus menyebut **bintang mana** — perbandingan satu kalimat akan
    # mengharuskan pembaca membedakan 25 angka sendiri.
    drifted = sorted(n for n in set(swift) & set(port)
                     if abs(swift[n] - port[n]) > 1e-9)
    for name in sorted(set(swift) & set(port)):
        results.append(Result(
            f"indeks warna {name}",
            name not in drifted,
            f"{swift[name]:+.2f}" if name not in drifted
            else f"model {swift[name]:+.2f}, port {port[name]:+.2f}"))

    # Tanda adalah identitas: bintang hangat harus positif, dingin negatif.
    # Diperiksa di sisi **model**, karena port-lah yang akan mengikuti.
    wrong_sign = sorted(n for n, v in swift.items()
                        if n in port and ((v > 0) != (port[n] > 0)))
    results.append(Result(
        "indeks warna bintang: tanda hangat/dingin sama di kedua bahasa",
        not wrong_sign,
        "semua tanda cocok" if not wrong_sign
        else f"tanda terbalik: {wrong_sign}"))


def star_rgb_parameters(source, anchor):
    """Koefisien `starRGB`/`star_rgb` dari teks sumber → dict.

    Membaca **bentuknya**, bukan menulis ulang angkanya: tujuh koefisien
    warna, dua batas penjepit B−V, dan pengali `warmth` hidup di **dua**
    bahasa (`CelestialVisual.starRGB` dan `star_rgb` pada port). Daftar
    tangan di gerbang akan menjadisalinan yang tidak pernah dibandingkan —
    persis lubang yang ditutup di sini.

    Komentari `//` dibuang lebih dulu. Fungsi ini punya komentar yang
    **memuat angka** ("kanal merah 1,11", "B−V >= ~1.35"), dan pembacaan
    tanpa membuangnya bisa mengambil angka komentar sebagai koefisien.
    Tidak ada string literal di dalam badan fungsi ini, jadi `//` di
    baris yang sama selalu berarti komentar.
    """
    if anchor not in source:
        raise ValueError(f"jangkar tidak ditemukan: {anchor!r}")
    start = source.index(anchor)
    # Batas wilayah **harus** mengikuti gaya badan fungsi pada bahasa itu:
    # `\ndef ` untuk Python, `\n    }` untuk Swift (badan fungsi diakhiri
    # kurung penutup pada indentasi yang sama). Tanpa batas, wilayah Swift
    # membentang sampai akhir berkas dan pembacaan akan ikut menelan fungsi
    # **berikutnya** yang kebetulan memakai pola serupa — gerbang yang akan
    # memerah pada model yang benar.
    terminators = ["\ndef ", "\n    }", "\n}"]
    cuts = [source.index(t, start) for t in terminators if t in source[start:]]
    region = source[start:min(cuts)] if cuts else source[start:]
    body = "\n".join(line.split("//")[0] for line in region.split("\n"))

    # `let` opsional: Swift menuliskannya, Python tidak. Tanpa ini pembaca
    # gagal tepat di sisi port — dan pemeriksaan yang gagal karena **bacaan**
    # akan terlihat seperti pemeriksaannya yang salah.
    clamp = re.search(
        r"(?:let )?clamped = min\(\s*(-?[\d.]+)\s*,\s*max\(\s*(-?[\d.]+)\s*,"
        r"\s*index\s*\)",
        body)
    warmth = re.search(
        r"(?:let )?warmth = \(clamped ([-+]) ([\d.]+)\) / ([\d.]+)", body)
    channels = re.findall(
        r"unit\(\s*([\d.]+)\s*([-+])\s*([\d.]+)\s*\*\s*warmth\s*\)", body)
    if not (clamp and warmth and len(channels) == 3):
        raise ValueError(
            f"bentuk starRGB tidak dikenali di jangkar {anchor!r}: "
            f"clamp={bool(clamp)}, warmth={bool(warmth)}, "
            f"kanal={len(channels)} (harus 3)")

    def slope(sign, magnitude):
        return -magnitude if sign == "-" else magnitude

    return {
        "clamp_low": float(clamp.group(2)),
        "clamp_high": float(clamp.group(1)),
        "warmth_offset": slope(warmth.group(1), float(warmth.group(2))),
        "warmth_span": float(warmth.group(3)),
        "channels": [
            (float(base), slope(sign, float(magnitude)))
            for base, sign, magnitude in channels],
    }


def star_rgb_from_parameters(params, index):
    """Bentukkan RGB dari koefisien yang dibaca dari sumber.

    `unit` ditulis ulang di sini, bukan diambil dari port: kalau gerbang
    memakai penjepit milik port yang sedang diukur, maka penjepit yang
    salah ikut lolos bersama rumusnya.
    """
    clamped = min(params["clamp_high"], max(params["clamp_low"], index))
    warmth = (clamped + params["warmth_offset"]) / params["warmth_span"]
    return tuple(
        min(1.0, max(0.0, base + slope * warmth))
        for base, slope in params["channels"])


def check_star_rgb_conversion_matches_the_model(results):
    """Konversi indeks B−V → RGB tidak boleh menyimpang antara model & port.

    **Cacat yang ditutup pemeriksaan ini.** `check_star_colour_index_matches_the_model`
    menjaga 25 **indeks** B−V. Tapi indeks itu bukan warna — warna lahir
    dari tujuh koefisien di `starRGB`, dan itulah yang benar-benar sampai ke
    piksel. Tujuh koefisien itu hidup lagi di `star_rgb` pada port Python,
    dan **tidak satu pun** dibandingkan.

    Buktinya diukur, bukan diasumsikan: `red: unit(0.62 + 0.38 * warmth)`
    diubah jadi `0.20` di model, dan **287 pemeriksaan visual, 637 uji
    Swift, 28 aturan lint, dan typecheck semuanya tetap hijau**. Alasannya
    bukan kebetulan: seluruh pemeriksaan warna bintang yang ada mengukur
    **gambar port**, jadi mengubah model tidak mengubah satu piksel pun
    yang sedang diukur.

    Dua arah, seperti gerbang tetangganya. Yang menentukan adalah arah
    kedua: mutasi di **kedua** bahasa sekaligus tidak membuat gerbang ini
    merah — dan memang seharusnya tidak, karena itu bukan penyimpangan.
    Yang tidak bisa dilihat gerbang ini adalah apakah warna itu benar
    secara astronomi; itu tetap milik `check_star_colour_order` dan
    `testStarColourIsMonotonicInColorIndex`, yang mengukur **hasilnya**.
    Gerbang ini mengikat angkanya; mereka mengukur artinya.
    """
    swift = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                               "CelestialVisual.swift")).read()
    port_source = open(R.SOURCE, encoding="utf-8").read()

    try:
        model = star_rgb_parameters(
            swift, "static func starRGB(forColorIndex index: Double)")
        port = star_rgb_parameters(port_source, "def star_rgb(index):")
    except ValueError as exc:
        results.append(Result("konversi warna bintang: bentuk terbaca", False,
                              str(exc)))
        return

    results.append(Result(
        "konversi warna bintang: bentuk terbaca dari kedua bahasa", True,
        f"{len(model['channels'])} kanal, penjepit "
        f"{model['clamp_low']:+.2f}…{model['clamp_high']:+.2f}, "
        f"span {model['warmth_span']}"))

    scalars = ("clamp_low", "clamp_high", "warmth_offset", "warmth_span")
    for key in scalars:
        results.append(Result(
            f"konversi warna bintang: {key}",
            abs(model[key] - port[key]) <= 1e-9,
            f"{model[key]:+.2f}" if abs(model[key] - port[key]) <= 1e-9
            else f"model {model[key]:+.2f}, port {port[key]:+.2f}"))

    for i, name in enumerate(("merah", "hijau", "biru")):
        (mb, ms), (pb, ps) = model["channels"][i], port["channels"][i]
        same = abs(mb - pb) <= 1e-9 and abs(ms - ps) <= 1e-9
        results.append(Result(
            f"konversi warna bintang: koefisien kanal {name}", same,
            f"{mb:.2f} {ms:+.2f}·warmth" if same
            else f"model {mb:.2f} {ms:+.2f}, port {pb:.2f} {ps:+.2f}"))

    # Koefisien sama belum tentu cukup: yang diuji adalah **hasilnya**, di
    # seluruh indeks katalog plus kedua ujung penjepit. Ini menangkap
    # perubahan bentuk (mis. penjepit hilang) yang daftar koefisien di atas
    # tidak akan lihat.
    #
    # Pengekspresian pesan tetap eksplisit, bukan f-string multi-baris:
    # gerbang ini berjalan di python3 distro Ubuntu (3.12) dan di runner
    # yang lebih tua, dan PEP 701 hanya masuk di 3.12.
    def rgb3(value):
        return tuple(round(c, 3) for c in value)

    probes = sorted(set(R.STAR_COLOR_INDEX.values())
                    | {model["clamp_low"], model["clamp_high"],
                       model["clamp_low"] - 5, model["clamp_high"] + 5, 0.0})
    mismatched = [i for i in probes
                  if max(abs(a - b) for a, b
                         in zip(star_rgb_from_parameters(model, i),
                                 R.star_rgb(i))) > 1e-6]
    detail = "{} indeks diuji".format(len(probes))
    if mismatched:
        detail = ("beda di B−V {}: model {}, port {}"
                  .format([round(i, 2) for i in mismatched][:6],
                          [rgb3(star_rgb_from_parameters(model, i))
                           for i in mismatched[:2]],
                          [rgb3(R.star_rgb(i)) for i in mismatched[:2]]))
    results.append(Result(
        "konversi warna bintang: warna hasil sama di seluruh indeks katalog",
        not mismatched, detail))


def star_geometry_parameters(source, anchor, terminator, comment_marker, names):
    """Parameter `VisualFrame.star` / `star_geometry` dari teks sumber.

    Dibaca dari sumber di kedua bahasa, bukan ditulis ulang di gerbang:
    daftar tangan di sini akan menjadi **entri yang tidak pernah
    dibandingkan** — persis lubang yang gerbang-gerbang tetangganya tutup,
    dan persis lubang yang ditemukan audit mutasi untuk kelompok ini.

    `comment_marker` (`//` untuk Swift, `#` untuk Python) dibuang per baris
    lebih dulu: dokumen fungsi ini memuat angka, dan pembacaan tanpa
    membuangnya akan mengambil angka prosa sebagai parameter.

    `names` memetakan kunci kanonik ke ejaan di bahasa itu (`glowScales`
    vs `glow_scales`), supaya satu pembaca bisa dipakai dua arah tanpa
    menebak konvensi penamaan.
    """
    if anchor not in source:
        raise ValueError(f"jangkar tidak ditemukan: {anchor!r}")
    start = source.index(anchor)
    cut = source.index(terminator, start) if terminator in source[start:] else len(source)
    region = source[start:cut]
    body = "\n".join(line.split(comment_marker)[0] for line in region.split("\n"))

    def default_of(name):
        """Teks nilai bawaan `name`, sesudah tanda `=`.

        Tipe Swift (`Double = 0.10`, `[Double] = [...]`) dilewati: yang
        dicari adalah nilai **sesudah** `=`, bukan sesudah nama.
        """
        found = re.search(re.escape(name) + r"\s*(?::\s*[\w\[\]() :,]*?)?=\s*", body)
        return body[found.end():] if found else None

    def scalar(name):
        tail = default_of(name)
        if tail is None:
            return None
        found = re.match(r"(-?[\d.]+)", tail)
        if found:
            return float(found.group(1))
        # Nilai bawaan bisa berupa **nama konstanta** (`frameHalfExtent:
        # Double = halfExtent`). Diurai ke definisinya di berkas yang sama,
        # bukan ditulis ulang di sini: `halfExtent` memang 1.0 di kedua
        # bahasa hari ini, dan menyalinnya akan mengembalikan daftar tangan.
        symbol = re.match(r"([A-Za-z_]\w*)", tail)
        if not symbol:
            return None
        defined = re.search(
            r"(?:static\s+)?let\s+" + re.escape(symbol.group(1))
            + r"\s*:\s*\w+\s*=\s*(-?[\d.]+)", source)
        return float(defined.group(1)) if defined else None

    def group_of(name):
        """Isi kurung `[...]` / `(...)` pada nilai bawaan `name`."""
        tail = default_of(name)
        if tail is None:
            return None
        found = re.match(r"[\[(]\s*([^\])]*)\s*[\])]", tail)
        if not found:
            return None
        return [float(v) for v in found.group(1).split(",")]

    glow = group_of(names["glowScales"])
    outer = group_of(names["outerFraction"])
    values = {
        "pulseAmplitude": scalar(names["pulseAmplitude"]),
        "spikeScale": scalar(names["spikeScale"]),
        "frameHalfExtent": scalar(names["frameHalfExtent"]),
        "glowScales": glow,
        "outerFaint": outer[0] if outer and len(outer) == 2 else None,
        "outerBright": outer[1] if outer and len(outer) == 2 else None,
    }
    missing = sorted(k for k, v in values.items() if v is None)
    if missing:
        raise ValueError(f"bentuk tidak dikenali di jangkar {anchor!r}: {missing}")
    return values


def magnitude_scale_parameters(source, anchor, comment_marker):
    """Parameter `sizeFromMagnitude` / `size_from_magnitude` dari teks sumber.

    Sama alasannya dengan pembaca tetangganya: dibaca dari sumber di kedua
    bahasa, bukan ditulis ulang. Yang dijaga di sini **skala logaritmiknya**
    — basis, koefisien, magnitudo terang, dan kedua penjepit — karena
    keempatnya hidup terpisah di dua bahasa dan tidak satu pun yang
    dibandingkan siapa pun.
    """
    if anchor not in source:
        raise ValueError(f"jangkar tidak ditemukan: {anchor!r}")
    start = source.index(anchor)
    # Wilayah dibatasi seperti pembaca `star_rgb`: tanpa batas, wilayah
    # Swift membentang sampai akhir berkas dan menelan fungsi berikutnya.
    terminators = ["\ndef ", "\n    }", "\n}"]
    cuts = [source.index(t, start) for t in terminators if t in source[start:]]
    region = source[start:min(cuts)] if cuts else source[start:]
    body = "\n".join(line.split(comment_marker)[0] for line in region.split("\n"))

    # `magnitude - brightest` (Swift) dan `m - (-1.5)` (Python) harus berarti
    # hal yang sama, dan begitu juga `pow(10.0, …)` lawan `10.0 ** …`. Jadi
    # yang dibaca adalah bentuknya, dan konstanta terang yang ditulis sebagai
    # **nama** (`let brightest: Double = -1.5`) diurai ke definisinya —
    # menyalin `-1.5` ke gerbang akan mengembalikan daftar tangan yang tidak
    # pernah dibandingkan.
    raw = re.search(
        r"(?:let\s+)?raw\s*=\s*(?:pow\(|math\.pow\()?\s*([\d.]+)\s*"
        r"(?:,\s*\(?|\s*\*\*\s*\()\s*(-?[\d.]+)\s*\*\s*\(\s*\w+\s*-\s*"
        r"\(?\s*([-\w.]+)\s*\)?\s*\)\s*\)?", body)
    bounds = re.findall(r"\b(?:min|max)\(\s*([\d.]+)\s*,\s*(?:min|max)\("
                        r"\s*([\d.]+)\s*,", body)
    if raw is None or not bounds:
        raise ValueError(
            f"bentuk sizeFromMagnitude tidak dikenali di jangkar {anchor!r}: "
            f"raw={'ada' if raw is not None else 'TIDAK'}, penjepit={len(bounds)}")

    def resolve(text):
        try:
            return float(text)
        except ValueError:
            pass
        defined = re.search(r"(?:static\s+)?let\s+" + re.escape(text)
                            + r"\s*:\s*\w+\s*=\s*(-?[\d.]+)", source)
        if defined is None:
            raise ValueError(
                f"konstanta terang {text!r} tidak berangka di jangkar {anchor!r}")
        return float(defined.group(1))

    return {
        "base": float(raw.group(1)),
        "coefficient": float(raw.group(2)),
        "brightest": resolve(raw.group(3)),
        # Urutan (min|max) ditulis terbalik di dua bahasa: Swift
        # `min(1, max(0.15, raw))`, Python `min(1.0, max(0.15, raw))`. Yang
        # dibandingkan karena itu himpunannya, bukan urutannya — kalau tidak,
        # gerbang akan merah pada salah satu bahasa yang benar.
        "bounds": tuple(sorted(float(v) for pair in bounds for v in pair)),
    }


def magnitude_scale_from_parameters(params, magnitude):
    """Ukuran relatif dari parameter yang dibaca — salinan rumusnya.

    Ditulis ulang, bukan dipanggil dari `R.size_from_magnitude`: gerbang
    yang memakai fungsi yang sedang diukur akan membiarkan kesalahan di
    fungsi itu lolos bersama pengukurannya.
    """
    raw = params["base"] ** (params["coefficient"]
                             * (magnitude - params["brightest"]))
    low, high = params["bounds"]
    return min(high, max(low, raw))


def check_magnitude_scale_matches_the_model(results):
    """Skala magnitudo → ukuran tidak boleh menyimpang antara model & port.

    **Cacat yang ditutup pemeriksaan ini — dan cara menemukannya.**
    Audit mutasi mengganti isi `size_from_magnitude` di port dengan
    `raw = 1.0` — setiap bintang jadi ukuran yang sama — dan **nol dari 296
    pemeriksaan** berbunyi:

    ```
    hijau  size from magnitude
    ```

    Ini yang paling berbahaya dari ketiga celah yang ditemukan audit itu,
    karena alasannya bukan "parameter tidak terpakai": uji Swift memang
    menjaga `sizeFromMagnitude` (`testSizeScaleIsLogarithmicNotLinear`,
    `testBrighterStarIsDrawnLarger`), dan gerbang gambar memang mengukur
    bintang. Yang tidak ada adalah **pengikat antara keduanya** — jadi model
    dan port bisa menyimpang, dan kedua lapis tetap hijau sambil mengukur
    dua hal yang berbeda.

    Kenapa ia sampai ke piksel: `relative_size` dipakai untuk warna mode
    malam port (`NIGHT_FLOOR_BRIGHTNESS + range * relative`) **dan** untuk
    geometri bintang. Skala yang menyimpang karena itu mengubah kecerahan
    mode malam yang diukur `check_night_mode_purity` pada piksel yang tidak
    pernah ada di jam.
    """
    swift = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                              "CelestialVisual.swift")).read()
    port_source = open(R.SOURCE, encoding="utf-8").read()

    try:
        model = magnitude_scale_parameters(
            swift, "public static func sizeFromMagnitude(_ magnitude: Double)", "//")
        port = magnitude_scale_parameters(
            port_source, "def size_from_magnitude(m):", "#")
    except ValueError as exc:
        results.append(Result("skala magnitudo: bentuk terbaca", False, str(exc)))
        return

    results.append(Result(
        "skala magnitudo: bentuk terbaca dari kedua bahasa", True,
        f"{model['base']:g}^({model['coefficient']:g}·(m{model['brightest']:+.2g})), "
        f"dijepit {model['bounds']}"))

    for key in ("base", "coefficient", "brightest"):
        same = abs(model[key] - port[key]) <= 1e-9
        results.append(Result(
            f"skala magnitudo: {key}", same,
            f"{model[key]:g}" if same
            else f"model {model[key]:g}, port {port[key]:g}"))
    results.append(Result(
        "skala magnitudo: penjepit",
        model["bounds"] == port["bounds"],
        f"{model['bounds']}" if model["bounds"] == port["bounds"]
        else f"model {model['bounds']}, port {port['bounds']}"))

    # Dan hasilnya, di seluruh rentang magnitudo katalog plus kedua ujung.
    # Pemeriksaan bentuk di atas tidak akan melihat skala yang dipakai di
    # tempat yang salah (mis. `-0.2` jadi `+0.2`).
    probes = sorted(set(v for v in R.STAR_COLOR_INDEX.values())) + [-1.46, 0.0, 1.25, 6.0, 20.0, -30.0]
    bad = [m for m in probes
           if abs(magnitude_scale_from_parameters(model, m)
                  - magnitude_scale_from_parameters(port, m)) > 1e-9]
    results.append(Result(
        "skala magnitudo: ukuran hasil sama di seluruh rentang katalog",
        not bad,
        f"{len(probes)} magnitudo diuji" if not bad
        else f"beda di mag {[round(m, 2) for m in bad][:6]}"))

    # Urutan terang: Sirius harus lebih besar dari Deneb. Diukur dari
    # parameter **model**, bukan dari gambar, karena gambar itu port.
    sirius = magnitude_scale_from_parameters(model, -1.46)
    deneb = magnitude_scale_from_parameters(model, 1.25)
    results.append(Result(
        "skala magnitudo: bintang terang digambar lebih besar",
        sirius > deneb, f"Sirius {sirius:.3f} > Deneb {deneb:.3f}"))


def star_geometry_outer(params, relative_size):
    """Ujung terluar bintang dari parameter yang dibaca — salinan rumusnya.

    Rumusnya ditulis ulang di sini, **bukan** dipanggil dari
    `R.star_geometry`: kalau gerbang memakai fungsi yang sedang diukur,
    maka kesalahan di fungsi itu ikut lolos bersama pengukurannya. Yang
    dibandingkan karena itu `VisualFrame.star` (model Swift) melawan
    `star_geometry` (port), dengan pengekspresian ketiga yang independen.
    """
    clamped = min(1.0, max(0.0, relative_size))
    return params["frameHalfExtent"] * (
        params["outerFaint"]
        + (params["outerBright"] - params["outerFaint"]) * clamped)


def check_star_geometry_matches_the_model(results):
    """Geometri bintang tidak boleh menyimpang antara model & port.

    **Cacat yang ditutup pemeriksaan ini — dan cara menemukannya.**
    Audit mutasi: setiap konstanta di port diubah satu per satu, lalu
    seluruh gerbang dijalankan. Empat parameter bintang
    (`glowScales`, `spikeScale`, `pulseAmplitude`, `outerFraction`)
    menghasilkan **nol** pemeriksaan merah untuk **setiap** mutasi:

    ```
    hijau  star geometry glow scales
    hijau  star geometry spike
    hijau  star geometry pulse
    hijau  star geometry outer frac
    ```

    Padahal uji Swift yang mengukur nilai yang sama ada
    (`testEnlargingTheGlowCannotPushTheStarOutOfFrame`,
    `testStarPulsePeakStaysInsideTheFrame`) — jadi ini bukan "sudah dijaga
    di tempat lain", melainkan **celah antara dua lapis**: uji Swift
    mengukur model, gerbang gambar mengukur port, dan tidak ada yang
    mengukur apakah keduanya masih angka yang sama.

    Kenapa ini lebih dari sekadar empat angka: seluruh gerbang gambar
    bintang (`check_star_colour_order`,
    `check_star_colour_not_a_claim_when_uncertain`) mengukur **gambar
    port**. Kalau port menggambar bintang dengan glow yang berbeda dari
    aplikasi, warna yang diukur berasal dari piksel yang tidak pernah
    tampil di jam.

    **Yang sengaja tidak dijaga: `MOON_PATH_STEPS`.** Konstanta itu sudah
    digigit oleh mutasi (2 pemeriksaan merah), jadi ia tidak butuh gerbang
    baru — membuatnya ikut di sini hanya menambah entri yang tidak bisa
    memerah.
    """
    swift = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                              "CelestialVisual.swift")).read()
    port_source = open(R.SOURCE, encoding="utf-8").read()

    # Nama parameter berbeda ejaan per bahasa (`glowScales` vs
    # `glow_scales`). Pemetaannya diberikan ke pembaca, bukan ditebak di
    # dalamnya: pembaca yang menebak "snake_case di Python" akan menelan
    # `frame_half_extent` yang memang ada, tapi akan gagal diam-diam begitu
    # ada parameter baru dengan ejaan lain.
    swift_names = {"pulseAmplitude": "pulseAmplitude", "spikeScale": "spikeScale",
                   "frameHalfExtent": "frameHalfExtent", "glowScales": "glowScales",
                   "outerFraction": "outerFraction"}
    port_names = {"pulseAmplitude": "pulse_amplitude", "spikeScale": "spike_scale",
                  "frameHalfExtent": "frame_half_extent", "glowScales": "glow_scales",
                  "outerFraction": "outer_fraction"}
    try:
        model = star_geometry_parameters(
            swift, "public static func star(relativeSize: Double,", "\n    }", "//",
            swift_names)
        port = star_geometry_parameters(
            port_source, "def star_geometry(relative_size,", "\ndef ", "#",
            port_names)
    except ValueError as exc:
        results.append(Result("geometri bintang: bentuk terbaca", False, str(exc)))
        return

    results.append(Result(
        "geometri bintang: bentuk terbaca dari kedua bahasa", True,
        f"{len(model['glowScales'])} lapis glow, ujung "
        f"{model['outerFaint']:.2f}…{model['outerBright']:.2f}"))

    for key in ("pulseAmplitude", "spikeScale", "frameHalfExtent"):
        same = abs(model[key] - port[key]) <= 1e-9
        results.append(Result(
            f"geometri bintang: {key}", same,
            f"{model[key]:.2f}" if same
            else f"model {model[key]:.2f}, port {port[key]:.2f}"))

    glow_same = (len(model["glowScales"]) == len(port["glowScales"])
                 and all(abs(a - b) <= 1e-9
                         for a, b in zip(model["glowScales"], port["glowScales"])))
    results.append(Result(
        "geometri bintang: pengali tiap lapis glow", glow_same,
        f"{model['glowScales']}" if glow_same
        else f"model {model['glowScales']}, port {port['glowScales']}"))

    for key in ("outerFaint", "outerBright"):
        same = abs(model[key] - port[key]) <= 1e-9
        results.append(Result(
            f"geometri bintang: ujung terluar {key}", same,
            f"{model[key]:.2f}" if same
            else f"model {model[key]:.2f}, port {port[key]:.2f}"))

    # Koefisien sama belum tentu cukup: yang diuji adalah **hasilnya**, di
    # seluruh rentang 0…1. Ini menangkap perubahan bentuk (mis. salah satu
    # parameter dipakai di tempat yang lain) yang daftar angka di atas tidak
    # akan lihat.
    probes = [i / 20.0 for i in range(21)]
    bad = [i for i in probes
           if abs(star_geometry_outer(model, i)
                  - star_geometry_outer(port, i)) > 1e-9]
    results.append(Result(
        "geometri bintang: ujung terluar sama di seluruh rentang ukuran",
        not bad,
        f"{len(probes)} ukuran diuji" if not bad
        else f"beda di {[round(i, 2) for i in bad][:6]}"))


def swift_night_accents(source):
    """Palet aksen `NightVisual.Accents` dari teks Swift → `{nama: (r,g,b)}`.

    Dibaca dari sumber, bukan ditulis ulang: 17 warna, dan daftar tangan di
    gerbang akan menjadi **warna ke-18 yang tidak pernah dibandingkan**.
    """
    anchor = "static let accents = Accents("
    if anchor not in source:
        raise ValueError(
            "'static let accents = Accents(' tidak ditemukan di NightVisual.swift")
    start = source.index(anchor) + len(anchor)
    region = source[start:source.index("\n}", start)]
    out = {}
    for name, r, g, b in re.findall(
            r"(\w+):\s*\.init\(red:\s*([\d.]+),\s*green:\s*([\d.]+),"
            r"\s*blue:\s*([\d.]+)\)", region):
        out[name] = (float(r), float(g), float(b))
    return out


def check_night_accents_match_the_model(results):
    """Setiap warna aksen tidak boleh menyimpang antar bahasa, dan urutan
    kecerahan yang hanya hidup sebagai komentar kini diukur.

    **Cacat yang ditutup pemeriksaan ini.** `NightVisual.Accents` memuat 17
    warna gambar (pita Jupiter, cincin Saturnus, kutub Mars, kabut Venus,
    kawah Merkurius, inti Matahari, piringan Bulan, ...). Semuanya hidup
    lagi di `ACCENTS` pada port Python. Sampai siklus ini yang dijaga hanya
    **lima** di antaranya (`craterFloor`, `craterRim`, `moonLit`,
    `moonUnlit`, `moonPhaseUnknown`) — dua belas sisanya, termasuk seluruh
    warna planet dan Matahari, tidak dibandingkan siapa pun. Mengubah warna
    cincin Saturnus di Swift membiarkan setiap pemeriksaan gambar hijau
    sambil mengukur warna yang tidak pernah ada.

    Yang kedua, dan yang lebih mudah hilang: **hubungan** antar warna itu
    hari ini hanya hidup sebagai komentar di sumber Swiftnya.

    | Hubungan | Kenapa ada |
    |---|---|
    | `moonUnlit` < `moonPhaseUnknown` < `moonLit` | kalau `moonPhaseUnknown` bergeser sampai menempel `moonUnlit`, cacat "fase tak diketahui = bulan baru" kembali tanpa suara — gambarnya masih piringan polos |
    | `craterRim` > `craterFloor` | bibir kawah harus menonjol dari dasarnya; kalau terbalik, kawah tampak menonjol keluar |
    | `sunCore` > `sunPhotosphere` | inti harus lebih terang dari fotosfer; kalau terbalik, Matahari tampak seperti cincin |

    Ketiganya sudah tertulis sebagai niat di `NightVisual.swift`. Niat yang
    tidak diukur adalah niat yang bisa hilang saat warnanya disunting —
    persis kelas "aturan yang hanya hidup sebagai prosa" yang sudah
    tercatat di repo ini. Diukur dari **model**, karena port-lah yang
    mengikuti.

    Arahnya dua bahasa seperti gerbang tetangganya: merah kalau port
    menyimpang, kalau model kehilangan warna yang masih ada di port, dan
    kalau port punya warna sisa.
    """
    night = open(os.path.join(
        ROOT, "Packages/PointingKit/Sources/PointingKit/NightVisual.swift")).read()
    try:
        swift = swift_night_accents(night)
    except ValueError as exc:
        results.append(Result("aksen gambar: terbaca dari model", False, str(exc)))
        return

    port = R.ACCENTS

    missing = sorted(set(swift) - set(port))
    results.append(Result(
        "aksen gambar: setiap warna model ada di port",
        not missing,
        f"semua {len(swift)} warna ada" if not missing
        else f"tidak ada di port: {missing}"))
    extra = sorted(set(port) - set(swift))
    results.append(Result(
        "aksen gambar: tidak ada warna sisa di port",
        not extra,
        "tidak ada" if not extra else f"hanya ada di port: {extra}"))

    def brightness(rgb):
        return sum(rgb) / 3.0

    for name in sorted(set(swift) & set(port)):
        same = all(abs(a - b) < 1e-9 for a, b in zip(swift[name], port[name]))
        results.append(Result(
            f"aksen gambar {name}",
            same,
            f"{swift[name]}" if same
            else f"model {swift[name]}, port {port[name]}"))

    ordering = [
        ("piringan fase tak diketahui di antara gelap dan terang",
         "moonUnlit", "moonPhaseUnknown", "moonLit"),
        ("bibir kawah lebih terang dari dasarnya",
         "craterFloor", "craterRim", None),
        ("inti Matahari lebih terang dari fotosfernya",
         "sunPhotosphere", "sunCore", None),
    ]
    for label, low, high, ceiling in ordering:
        if low not in swift or high not in swift:
            results.append(Result(f"aksen gambar: {label}", False,
                                  f"{low}/{high} tidak ada di model"))
            continue
        ok = brightness(swift[low]) < brightness(swift[high])
        if ceiling is not None:
            ok = ok and (ceiling not in swift
                         or brightness(swift[high]) < brightness(swift[ceiling]))
        results.append(Result(
            f"aksen gambar: {label}", ok,
            f"{brightness(swift[low]):.3f} < {brightness(swift[high]):.3f}"
            + (f" < {brightness(swift[ceiling]):.3f}" if ceiling in swift else "")))


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


def check_every_morphology_in_the_model_has_render_cases(results):
    """Setiap morfologi di model harus punya **kasus render** dan **pembacaan**.

    **Cacat yang ditutup pemeriksaan ini — dan cara menemukannya.** Gerbang
    tetangganya, `check_deep_sky_layouts_match_the_model`, membandingkan
    model dengan port **per nama yang ia temukan di kedua sisi**. Jadi ia
    benar, dan ia tidak bisa melihat bentuk yang **tidak ada di kedua sisi
    sekaligus** — yang sunyi justru keadaan di mana model dan port sama-sama
    tidak punya bentuk itu.

    Diukur, bukan diasumsikan (`out/probe-morfologi-baru.py`). Menambahkan
    satu morfologi baru (`.comet`) ke enum **dan** ke `switch` gambar:

    ```
    [baseline]                                  415 pemeriksaan, 0 gagal  <- hijau
    A. enum + switch gambar                     415 pemeriksaan, 0 gagal  <- hijau
    ```

    Gerbang gambar tidak berbunyi sama sekali, karena yang dibacanya
    (`read_deep_sky_layouts_from_swift`) memakai **daftar nama yang ditulis
    tangan**: `("planetaryNebula", "galaxy", "openCluster", "globularCluster")`.
    Nama kelima tidak ada di daftar itu, jadi bentuknya tidak pernah dibaca —
    dan bentuk yang tidak dibaca tidak pernah bisa menyimpang.

    Keadaan itu **tidak bertahan** sampai ke gambar: uji Swift
    `testEveryMorphologyIsUsedByTheCatalogue` menolaknya lebih dulu, dan
    probe membuktikannya (`switch must be exhaustive` di `DeepSkySpeech`).
    Tapi yang menjaga jalur itu adalah uji Swift, dan uji Swift tidak tahu
    apa pun soal **gambar**. Ia hijau pada keadaan yang tidak pernah
    menggambar bentuk itu.

    Yang hilang karena itu bukan gerbang baru untuk sebuah cacat yang hidup,
    melainkan **gerbang yang berlaku untuk morfologi itu**: aturan "bentuknya
    ada di port", "ada kasus render-nya", dan "bentuknya berbeda dari kabut
    netral di layar" hanya berjalan pada nama yang ada di daftar tangan.

    Empat hal diperiksa, semuanya **diturunkan dari model**:

      1. Setiap `case` di enum `Morphology` **terbaca** oleh pembaca gerbang.
         Pembaca yang kehilangan satu nama akan melaporkan bentuk itu
         "hilang" — atau lebih buruk, tidak melaporkannya sama sekali.
      2. Setiap `case` di enum punya **kasus render** `deepsky-<nama>`. Tanpa
         itu, bentuknya tidak pernah muncul di satu pun PNG yang diukur.
      3. Setiap `case` punya **layout di port** — kalau tidak, jam menggambar
         bentuk yang tidak pernah diukur gerbang gambar mana pun.
      4. **Tidak ada bentuk sisa di port** yang tidak ada di enum. Port yang
         punya bentuk yang tidak bisa dipilih objek mana pun adalah kode mati
         yang tampak seperti pekerjaan selesai: ia ada, ia tidak salah, dan
         ia tidak pernah menggambar apa pun. Arah ini yang menutup "bentuk
         ditambahkan ke port saja" — keadaan yang, tanpa pemeriksaan ini,
         hanya terlihat oleh pembaca yang membandingkan dua berkas dengan
         mata. `"nebula"` dikecualikan karena ia bentuk **netral** (dipakai
         saat morfologi `nil`), bukan kasus enum.

    Daftar `cases` dibaca dari `DeepSkyCatalogue.swift` (tempat enum-nya),
    bukan dari `Planet`-style `allCases` — lihat
    `read_deep_sky_morphology_cases_from_swift`.
    """
    catalogue_path = os.path.join(
        ROOT, "Packages/PointingKit/Sources/PointingKit/DeepSkyCatalogue.swift")
    model_path = os.path.join(
        ROOT, "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift")
    try:
        declared = read_deep_sky_morphology_cases_from_swift(
            open(catalogue_path, encoding="utf-8").read())
    except ValueError as exc:
        results.append(Result(
            "kasus render morfologi: enum terbaca dari model", False, str(exc)))
        return

    # 1. Pembaca gerbang harus menjangkau setiap kasus enum. Daftarnya
    #    ditulis tangan di dalam `read_deep_sky_layouts_from_swift`, jadi
    #    inilah tempat nama yang ditambahkan belakangan tertinggal.
    read_names = set(read_deep_sky_layouts_from_swift(
        open(model_path, encoding="utf-8").read()))
    unread = sorted(set(declared) - read_names)
    results.append(Result(
        "kasus render morfologi: setiap kasus enum terbaca pembaca gerbang",
        not unread,
        f"{len(declared)} morfologi terbaca" if not unread
        else f"tidak pernah dibaca: {unread} — bentuknya tidak bisa menyimpang "
             "karena tidak ada yang membandingkannya"))

    # 2. Kasus render: bentuk yang tidak punya kasus tidak pernah muncul di
    #    satu pun PNG yang diukur.
    names = {case.name for case in R.build_cases()}
    missing_cases = sorted(n for n in declared if f"deepsky-{n}" not in names)
    results.append(Result(
        "kasus render morfologi: setiap kasus enum punya kasus render",
        not missing_cases,
        f"{len(declared)} kasus render" if not missing_cases
        else f"tidak ada kasus render: {missing_cases} — bentuk itu tidak pernah "
             "muncul di satu pun gambar yang diukur"))

    # 3. Layout di port: kalau tidak ada, jam menggambar bentuk yang tidak
    #    pernah diukur.
    port_names = set(R.DEEP_SKY_LAYOUT)
    missing_port = sorted(n for n in declared if n not in port_names)
    results.append(Result(
        "kasus render morfologi: setiap kasus enum punya layout di port",
        not missing_port,
        f"{len(declared)} layout" if not missing_port
        else f"tidak ada di port: {missing_port} — penggambar jatuh ke kabut "
             "netral, dan gambar yang diukur bukan gambar yang tampil"))

    # 4. Nama-nama yang **tidak** berasal dari model. Port yang punya bentuk
    #    yang tidak ada di enum adalah bentuk yang tidak bisa dipilih objek
    #    mana pun — kode mati yang tampak seperti pekerjaan selesai.
    extra_port = sorted(port_names - set(declared) - {"nebula"})
    results.append(Result(
        "kasus render morfologi: tidak ada bentuk sisa di port",
        not extra_port,
        "tidak ada" if not extra_port
        else f"hanya ada di port: {extra_port} — tidak bisa dipilih objek mana pun"))


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

    # **Cacat keempat di berkas kawah ini — bentuk yang belum pernah ada.**
    #
    # Dua konstanta di atas dijaga karena keduanya **memakai notasi yang
    # sama** di kedua bahasa: `0.45·ukuran` ditulis `size * 0.45` dan `mr *
    # CRATER_RIM_OFFSET`. Cakram bibir kawah tidak seperti itu — bentuknya
    # sama, tapi **notasinya berbeda**:
    #
    # | | sisi | apa yang ditulis |
    # |---|---|---|
    # | view | `Path(ellipseIn: CGRect(… width: size * 1.84 …))` | **diameter** |
    # | port | `canvas.disc(…, mr * 0.92, …)` | **radius** |
    #
    # Satu angka (0,92) dalam dua satuan. `1.84 = 2 × 0.92`, jadi kodenya
    # benar — dan karena itu **tidak ada yang bisa melihatnya**: gerbang
    # `check_crater_drawing_constants` di atas hanya menguji dua konstanta
    # yang notasinya sama, dan tidak ada gerbang lain yang menyebut `1.84`
    # maupun `0.92` sama sekali.
    #
    # Bukti kedua yang menentukan (audit mutasi, dua arah terpisah):
    #
    #     VIEW  1.84 -> 1.60   313 pemeriksaan, 0 gagal
    #     PORT  0.92 -> 0.70   313 pemeriksaan, 0 gagal
    #
    # Dua mutasi mengubah **lebar sabit bibir kawah** — kontur yang menentukan
    # apakah kawah terbaca sebagai cekung bergerigi atau sebagai stiker rata
    # — dan seluruh gerbang diam. Menggeser `0.92` di port membuat gambar
    # kawah di PNG menyimpang dari gambar kawah di jam tanpa satu pun
    # pemeriksaan yang menyebutnya.
    #
    # Perbaikannya **bukan** menyamakan angkanya secara harfiah, karena
    # keduanya memang harus berbeda (diameter vs radius). Yang diikat
    # adalah **rasio yang dihitung ulang**: diameter view harus persis dua
    # kali radius port. Menulis ulang rumusnya di gerbang, bukan memanggil
    # fungsi view yang sedang diukur.
    #
    # Dua arah tetap wajib: merah kalau view berubah tanpa port, **dan**
    # merah kalau port berubah tanpa view. Sifat simetrisnya penting di
    # sini — kalau hanya satu arah, `view 1.84 + port 0.70` (yang keduanya
    # diperkecil) lolos sebagai "keseimbangan", padahal tidak ada yang
    # mengatakannya sama.
    #
    # **Yang TIDAK ditutup, dan sengaja.** Kalau **kedua** sisi diubah
    # bersama (`view 1.60 + port 0.80`), gerbang ini tetap hijau. Itu benar:
    # ia mengikat **rasio** (satu angka dalam dua satuan), bukan nilai
    # absolutnya. Mengikat nilai absolut berarti menulis "1.84 adalah angka
    # yang benar" ke dalam gerbang, dan daftar seperti itu menjadi **entri
    # yang tidak pernah dibandingkan** — persis lubang yang gerbang-gerbang
    # tetangganya tutup. `1.84` juga tidak punya model di `PointingKit`, jadi
    # tidak ada sumber kebenaran ketiga selain kedua sisi itu sendiri.
    #
    # Dinyatakan di sini supaya gerbang ini tidak dibaca lebih kuat dari yang
    # diukurnya: ia menangkap **drift**, dan keputusan "kawah ini harus lebih
    # lebar" tetap milik review manusia.
    #
    # `(?<![\w.])` dipakai supaya angka yang dimaksud tidak tertangkap sebagai
    # digit terakhir pengenal — versi pertama regex ini membaca "diameter 2"
    # dari `size * 1.84` dan membuat gerbang merah **pada kode yang benar**.
    # Gerbang yang merah pada kode benar akan dimatikan orang, jadi ini bukan
    # gangguan: ini syarat agar gerbang ini bisa hidup.
    view_rim = re.search(r"width:\s*size\s*\*\s*(?<![\w.])(\d+\.\d+)\s*,\s*"
                         r"height:\s*size\s*\*\s*(?<![\w.])(\d+\.\d+)\s*\)", view)
    if not view_rim:
        results.append(Result(
            "kawah: diameter sabit bibir terbaca dari view", False,
            "'width: size * N, height: size * N)' tidak ditemukan di "
            "CelestialVisualView.drawCraters — faktor cakram sabit tidak "
            "lagi terbaca"))
        return

    port_rim = re.search(r"canvas\.disc\(mx \+ rim_x \* offset, "
                         r"my \+ rim_y \* offset, mr \s*\*\s*(?<![\w.])(\d+\.\d+),", port)
    if not port_rim:
        results.append(Result(
            "kawah: radius sabit bibir terbaca dari port", False,
            "'canvas.disc(…, mr * N,' tidak ditemukan di render-visuals — "
            "faktor cakram sabit tidak lagi terbaca"))
        return

    view_diameter = float(view_rim.group(1))
    view_height = float(view_rim.group(2))
    # View menulis `width` dan `height` terpisah; dua angka itu harus sama,
    # karena elips yang lebar != tinggi bukan cakram dan bukan lagi "bibir
    # kawah" — ia jadi bentuk lain tanpa satu pun yang menyadarinya.
    results.append(Result(
        "kawah: sabit bibir digambar sebagai lingkaran (view)",
        abs(view_diameter - view_height) < 1e-9,
        f"diameter {view_diameter:g} × tinggi {view_height:g}"))

    port_radius = float(port_rim.group(1))
    same_disc = abs(view_diameter - 2 * port_radius) < 1e-9
    results.append(Result(
        "kawah: diameter view = dua kali radius port",
        same_disc,
        f"view {view_diameter:g} = 2 × port {port_radius:g}" if same_disc
        else f"view {view_diameter:g} vs 2 × port {2 * port_radius:g}"))



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


def crater_shading_terms(source, anchor):
    """Empat angka rumus peredupan kawah dari teks sumber → dict.

    Membaca **bentuknya**, bukan menulis ulang angkanya. Rumus bayangan kawah
    hidup di dua bahasa dengan ejaan yang berbeda:

        Swift   let fade = 0.6 + 0.4 * alignment
                let limb = 1 - 0.6 * distance
                floorDepth: depth * (1 - 0.5 * distance)

        Python  fade = 0.6 + 0.4 * alignment
                limb = 1 - 0.6 * distance
                depth * (1 - 0.5 * distance)

    Ketiganya punya **arti**: `fade` menentukan berapa kontras yang tersisa di
    sisi gelap bola (1,0 di sisi terang, 0,2 di sisi tergelap), `limb`
    meredupkan kawah di tepi piringan, dan suku terakhir mendangkalkan dasar
    cekungan di tepi. Angka-angka ini tidak punya sumber ketiga di model —
    sama seperti `1.84` pada bibir kawah — jadi satu-satunya cara menjaganya
    adalah membandingkan kedua bahasa yang memang memakainya.

    Daftar tetap di gerbang tidak akan berhasil di sini: angka-angka ini
    dulu memang hidup sebagai angka tetap di gerbang, dan itulah cacatnya —
    gerbang mengukur rumusnya sendiri, bukan rumus yang dikompilasi.
    """
    if anchor not in source:
        raise ValueError(f"jangkar tidak ditemukan: {anchor!r}")
    start = source.index(anchor)
    terminators = ["\ndef ", "\n    }", "\n}\n", "\n\n\n"]
    cuts = [source.index(t, start) for t in terminators if t in source[start:]]
    region = source[start:min(cuts)] if cuts else source[start:]
    # Komentar dibuang: badan `craterRelief` memuat prosa yang **menyebut
    # angka** ("kekuatan penuh di sisi terang dan 20% di sisi tergelap"), dan
    # pembacaan tanpa membuangnya bisa mengambil angka komentar sebagai
    # koefisien. Tidak ada string literal di badan fungsi ini, jadi `//` dan
    # `#` di baris yang sama selalu berarti komentar.
    body = "\n".join(line.split("//")[0].split("#")[0] for line in region.split("\n"))

    fade = re.search(
        r"(?:let )?fade\s*=\s*([\d.]+)\s*\+\s*([\d.]+)\s*\*\s*alignment", body)
    limb = re.search(
        r"(?:let )?limb\s*=\s*1\s*-\s*([\d.]+)\s*\*\s*distance", body)
    floor = re.search(
        r"depth\s*\*\s*\(\s*1\s*-\s*([\d.]+)\s*\*\s*distance\s*\)", body)
    if not (fade and limb and floor):
        raise ValueError(
            f"bentuk rumus bayangan kawah tidak dikenali di jangkar {anchor!r}: "
            f"fade={bool(fade)}, limb={bool(limb)}, dasar={bool(floor)}")

    return {
        "fade_base": float(fade.group(1)),
        "fade_span": float(fade.group(2)),
        "limb_slope": float(limb.group(1)),
        "floor_slope": float(floor.group(1)),
    }


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
    #
    # **Cacat di gerbang ini sendiri, ditemukan audit mutasi.** Sampai
    # siklus ini `want_strength` dibangun dari `R.CRATER_RIM_STRENGTH` dan
    # dibandingkan dengan `relief[i][5]`, yang dihitung oleh `crater_relief`
    # dari **konstanta yang sama**. Jadi yang dibandingkan adalah port
    # melawan port, dan tidak ada mutasi yang bisa membuatnya merah:
    #
    #     hijau  crater rim strength   (0.55 -> 0.05)
    #     hijau  crater floor depth    (0.22 -> 0.02)
    #
    # Dua-duanya mengubah bayangan kawah yang benar-benar tergambar, dan
    # dua-duanya sunyi. Karena itu kedua koefisien dibaca dari **model
    # Swift** dan dibandingkan ke port — bukan dibaca dari port dan
    # dibandingkan ke port.
    crater_coefficients = re.search(
        r"static func craterRelief\(craters:.*?"
        r"strength:\s*Double\s*=\s*(-?[\d.]+)\s*,\s*"
        r"depth:\s*Double\s*=\s*(-?[\d.]+)", model, re.S)
    if not crater_coefficients:
        results.append(Result(
            "bayangan kawah: koefisien terbaca dari model", False,
            "'static func craterRelief(... strength:depth:' tidak ditemukan "
            "— kekuatan bibir & kedalaman dasar tidak lagi terbaca"))
        return
    model_strength = float(crater_coefficients.group(1))
    model_depth = float(crater_coefficients.group(2))

    results.append(Result(
        "bayangan kawah: kekuatan bibir sama dengan model",
        abs(model_strength - R.CRATER_RIM_STRENGTH) <= 1e-9,
        f"{model_strength:.2f}" if abs(model_strength - R.CRATER_RIM_STRENGTH) <= 1e-9
        else f"model {model_strength:.2f}, port {R.CRATER_RIM_STRENGTH:.2f}"))
    results.append(Result(
        "bayangan kawah: kedalaman dasar sama dengan model",
        abs(model_depth - R.CRATER_FLOOR_DEPTH) <= 1e-9,
        f"{model_depth:.2f}" if abs(model_depth - R.CRATER_FLOOR_DEPTH) <= 1e-9
        else f"model {model_depth:.2f}, port {R.CRATER_FLOOR_DEPTH:.2f}"))

    # Dan rumusnya sendiri: dihitung ulang dari koefisien **model**, lalu
    # dibandingkan ke hasil port. Tanpa langkah ini, dua pemeriksaan di atas
    # hanya menjaga dua angka, bukan bahwa keduanya dipakai di tempat yang
    # benar (`fade` di kekuatan, `(1 - 0.5 * distance)` di kedalaman).
    #
    # **Cacat kedua di gerbang ini, ditemukan audit mutasi.** Rumus di bawah
    # semula ditulis sebagai tiga angka tetap di dalam gerbang:
    #
    #     want_strength = model_strength * (0.6 + 0.4 * alignment) * (1 - 0.6 * distance)
    #     want_depth    = model_depth * (1 - 0.5 * distance)
    #
    # Ketiga angka itu — `0.6 + 0.4`, `1 - 0.6`, `1 - 0.5` — **tidak dibaca
    # dari mana pun**, jadi mengubahnya di model Swift tidak menyentuh rumus
    # yang dipakai gerbang untuk mengukur, dan hasilnya hijau. Yang paling
    # penting: keduanya juga tidak dijaga uji Swift mana pun. Mutasi
    # `0.6 + 0.4` → `0.7 + 0.3` (tetap positif di semua kawah) membuat
    # **seluruh** 124 uji `CelestialVisualTests` hijau *dan* gerbang ini hijau;
    # yang menangkap `0.2 + 0.8` hanyalah pemeriksaan tanda `rimStrength > 0`,
    # bukan pemeriksaan rumus. Jadi kontras kawah sisi gelap — satu-satunya
    # yang membedakan kawah cekung dari kawah yang hilang — hidup hanya
    # sebagai komentar di dua bahasa.
    #
    # Karena itu ketiga angka itu dibaca dari **teks kedua bahasa** dan
    # dibandingkan, persis seperti koefisien di atas. Membaca dari sumber
    # berarti tidak ada daftar yang bisa tertinggal separuh saat rumusnya
    # disunting.
    try:
        model_terms = crater_shading_terms(model, "static func craterRelief(")
        port_terms = crater_shading_terms(
            open(R.SOURCE, encoding="utf-8").read(), "def crater_relief(")
    except ValueError as exc:
        results.append(Result("bayangan kawah: bentuk rumus terbaca", False, str(exc)))
        return

    for name, label in (("fade_base", "dasar peredupan sisi gelap"),
                        ("fade_span", "rentang peredupan terang→gelap"),
                        ("limb_slope", "kemiringan kawah di tepi piringan"),
                        ("floor_slope", "kemiringan dasar cekungan")):
        same = abs(model_terms[name] - port_terms[name]) <= 1e-9
        results.append(Result(
            f"bayangan kawah: {label}",
            same,
            f"{model_terms[name]:.2f}" if same
            else f"model {model_terms[name]:.2f}, port {port_terms[name]:.2f}"))

    mismatched = []
    for i, (dx, dy, size) in enumerate(R.CRATERS):
        distance = min(1.0, (dx * dx + dy * dy) ** 0.5)
        alignment = dx * (lx / length) + dy * (ly / length)
        want_strength = model_strength * (
            model_terms["fade_base"] + model_terms["fade_span"] * alignment) * (
            1 - model_terms["limb_slope"] * distance)
        want_depth = model_depth * (1 - model_terms["floor_slope"] * distance)
        if (abs(relief[i][5] - want_strength) > 1e-9
                or abs(relief[i][6] - want_depth) > 1e-9):
            mismatched.append(i)
    results.append(Result(
        "bayangan kawah: kekuatan bibir & kedalaman dasar mengikuti model",
        not mismatched,
        f"rumus sama di kedua bahasa (model {model_strength:.2f}/{model_depth:.2f})"
        if not mismatched
        else f"kawah {mismatched} menyimpang dari rumus "
             f"(kekuatan {model_strength}, kedalaman {model_depth})"))

    # Akhirnya: artinya, bukan angkanya. Ketiga angka di atas boleh saja
    # ditulis ulang **bersama di kedua bahasa** — itu bukan penyimpangan, dan
    # dua pemeriksaan sebelumnya memang tidak boleh memerah karenanya. Yang
    # tidak boleh terjadi adalah kawah sisi gelap menghilang atau berbalik
    # tanda, karena itu membuat kawah terbaca sebagai tonjolan alih-alih
    # cekungan. Diukur dari **model**, bukan dari port, supaya gerbang ini
    # tetap berbunyi walau kedua bahasa disunting bersama.
    dark = model_terms["fade_base"] - model_terms["fade_span"]
    bright = model_terms["fade_base"] + model_terms["fade_span"]
    results.append(Result(
        "bayangan kawah: sisi gelap tidak hilang, sisi terang tidak tenggelam",
        dark > 0 and bright > dark,
        f"terang {bright:.2f}× , gelap {dark:.2f}× (rasio {bright / dark:.2f})"
        if dark > 0 and bright > dark
        else f"peredupan terbalik atau nol: terang {bright:.2f}×, gelap {dark:.2f}×"))


def read_deep_sky_catalogue_from_swift(source):
    """Katalog objek langit dalam dari teks Swift: id → (fuzziness, morfologi).

    Dibaca dari sumber, bukan ditulis sebagai daftar di gerbang. Daftar
    tangan di sini akan menjadi **salinan ke-18 yang tidak pernah
    dibandingkan** — persis lubang yang gerbang ini ada untuk menutup, dan
    yang sudah berulang di repo ini untuk palet planet, warna bintang,
    maria, dan tata letak langit dalam.

    Tiga hal dibaca sekaligus karena ketiganya harus sepakat soal **himpunan
    id yang sama**: daftar objek (`CelestialObject(id:)`), tabel `fuzziness`,
    dan tabel `morphology`. Objek yang punya entri di satu tabel tapi tidak
    di tabel lain akan tampil dengan nilai bawaan yang **tampak sah**.
    """
    ids = re.findall(r'CelestialObject\(id:\s*"(\w+)"', source)
    if not ids:
        raise ValueError("tidak ada 'CelestialObject(id: \"…\")' di DeepSkyCatalogue.swift")

    anchors = (("fuzzinessByID: [String: Double] = [", r'"(\w+)":\s*([\d.]+)'),
               ("morphologyByID: [String: Morphology] = [", r'"(\w+)":\s*\.(\w+)'))
    tables = []
    for anchor, pattern in anchors:
        if anchor not in source:
            raise ValueError(f"jangkar tidak ditemukan di DeepSkyCatalogue.swift: {anchor!r}")
        block = source.split(anchor, 1)[1].split("]", 1)[0]
        table = dict(re.findall(pattern, block))
        if not table:
            raise ValueError(f"tabel kosong di jangkar {anchor!r}")
        tables.append(table)

    fuzziness = {k: float(v) for k, v in tables[0].items()}
    morphology = tables[1]
    return ids, fuzziness, morphology


def deep_sky_growth_parameters(source, anchor):
    """Dua angka rumus `growth` dari teks sumber: `(base, span)`.

    `buildDeepSky` memperbesar setiap blob sebesar `base + span · fuzziness`.
    Rumus itu hidup **dua kali** — `CelestialVisual.swift` dan
    `render-visuals.py` — dan sampai gerbang ini tidak satu pun dari kedua
    angkanya dibandingkan. Yang menggambar di jam adalah yang pertama; yang
    diukur setiap gerbang gambar adalah yang kedua.

    Wilayahnya dipotong **dulu** pada fungsi yang memilikinya. Tanpa itu
    `re.search` mengambil kecocokan pertama di seluruh berkas, dan
    `CelestialVisual.swift` sudah punya `let growth = max(...)` di
    `starGeometry` — rumus yang sah tapi bukan rumus ini. Pencarian yang
    bergantung pada "yang pertama kebetulan benar" adalah gerbang yang
    berhenti benar begitu ada fungsi baru di atasnya.
    """
    if anchor not in source:
        raise ValueError(f"jangkar tidak ditemukan: {anchor!r}")
    start = source.index(anchor)
    match = re.search(r"\bgrowth\s*=\s*([\d.]+)\s*\+\s*([\d.]+)\s*\*", source[start:])
    if match is None:
        raise ValueError(f"bentuk rumus growth tidak ditemukan di dalam {anchor!r}")
    return float(match.group(1)), float(match.group(2))


def deep_sky_growth(params, fuzziness):
    """Ukuran relatif blob dari parameter yang dibaca — salinan rumusnya.

    Ditulis ulang, bukan dipanggil dari `R.deep_sky_blobs`: gerbang yang
    memakai fungsi yang sedang diukur akan membiarkan kesalahan di fungsi
    itu lolos bersama pengukurannya.
    """
    clamped = min(1.0, max(0.0, fuzziness))
    return params[0] + params[1] * clamped


def read_deep_sky_drawing_from_swift(source):
    """Dua argumen `_draw_deep_sky` di port: nama kunci morfologi & fuzziness.

    Yang dibaca adalah **kunci kamus yang benar-benar diambil penggambar**,
    bukan nama argumennya. Port memanggil
    `deep_sky_blobs(morphology, kw.get("fuzziness", 0.6))`; kalau kuncinya
    berubah (`"fuzziness"` → `"spread"`) sementara kasus render masih mengisi
    `fuzziness`, setiap gambar akan jatuh ke nilai bawaan 0.6 dan **seluruh**
    tabel katalog berhenti sampai ke kertas tanpa satu pun pemeriksaan lain
    menyala — kelas cacat yang sama dengan `row("Keadaan", …)` di layar
    Diagnostik, hanya di lapisan gambar.

    Karena itu yang diuji bukan "fungsi ini ada", melainkan bahwa kunci yang
    diambil sama dengan kunci yang diisi.
    """
    if "def _draw_deep_sky(" not in source:
        raise ValueError("'def _draw_deep_sky(' tidak ditemukan di render-visuals.py")
    region = source[source.index("def _draw_deep_sky("):]
    # Wilayahnya dipotong pada `def` berikutnya supaya pembaca ini benar-benar
    # membaca fungsi yang ia sebut namanya. **Efeknya diukur, dan lebih kecil
    # dari yang tampak.** Pada mutasi "penggambar berhenti membaca fuzziness,
    # `kw.get("fuzziness")` hidup di fungsi lain" (out/bukti-pembaca-lama-ds.py):
    # pembaca lama sampai EOF → 2 gagal, pembaca ini → 3 gagal. Dua pemeriksaan
    # piksel di bawah tetap menggigit apa pun isi pembaca ini, jadi yang
    # ditambahkan di sini adalah **sebab yang disebut namanya**, bukan cakupan
    # baru. Tetap diperbaiki karena pembaca yang membaca melewati batas
    # fungsinya adalah jebakan yang menganggur — bukan karena ia menutup lubang.
    following = region.find("\ndef ", 1)
    if following != -1:
        region = region[:following]
    keys = re.findall(r"kw\.get\(\s*\"(\w+)\"", region)
    if not keys:
        raise ValueError("_draw_deep_sky tidak membaca kw.get(\"…\") sama sekali")
    return keys


def check_deep_sky_catalogue_values_reach_the_picture(results, size=38, ss=8):
    """Setiap objek langit dalam digambar dengan **angkanya sendiri**, di ukuran jam.

    **Cacat yang ditutup pemeriksaan ini — dan cara menemukannya.** Seluruh
    gerbang gambar yang ada merender kasus langit dalam dengan `fuzziness=0.8`
    yang **sama untuk semua** (`build_cases()`), sementara katalog produksi
    membawa 17 angka pilihan — 0.30 untuk M22 sampai 1.00 untuk M31. Diukur:
    gambar yang diukur gerbang menyimpang dari gambar yang tampil di jam
    sebesar **312 piksel rata-rata (21,7% dari frame)** pada 38 pt, dan
    **819 piksel (56,7%)** untuk M42. Jadi tidak satu pun dari 399
    pemeriksaan itu pernah melihat gambar objek langit dalam yang benar-benar
    muncul.

    Dua akibat, keduanya sunyi. (1) Mengubah satu nilai di `fuzzinessByID`
    tidak membuat apa pun merah — dibuktikan: `"m13": 0.35` → `1.00`
    meninggalkan 399 pemeriksaan dan 29 aturan lint hijau. (2) Rumus
    `growth` yang mengubah angka itu menjadi ukuran blob hidup dua kali dan
    **tidak dibandingkan sama sekali**: `0.38` → `0.10` di port, dan di
    model Swift, keduanya hijau di seluruh 399 pemeriksaan **dan** 662 uji
    Swift — termasuk `testNebulaGrowsWithFuzziness`, yang hanya menuntut
    "lebar lebih besar dari sempit" sehingga tetap benar berapa pun
    span-nya.

    Yang diukur karena itu bukan "nilai sama di dua tabel" (keduanya memang
    satu tabel), melainkan **empat jalur yang berbeda**:

      1. `growth` model == `growth` port, dan span-nya **tidak nol** —
         kalau span nol, `fuzziness` tidak lagi mengubah apa pun dan seluruh
         tabel katalog menjadi hiasan.
      2. Kunci kamus yang diambil penggambar == kunci yang diisi kasus
         render. Kalau tidak, seluruh tabel jatuh ke nilai bawaan 0.6.
      3. Nilai katalog benar-benar punya **efek pada gambar**: untuk setiap
         objek, gambar pada nilai katalognya harus berbeda dari gambar pada
         nilai bawaan netral (0.6). Ini yang menangkap penggambar yang
         mengabaikan argumennya.
      4. Di dalam satu morfologi, nilai katalog yang berbeda harus
         menghasilkan gambar yang **berbeda di ukuran jam** — bukan cuma
         berbeda secara aritmetika. Klaim "seberapa menyebar" di katalog
         hanya berarti kalau bedanya terlihat.

    **Ukurannya 38 pt, dibaca dari token** lewat `watch_visual_diameter()`,
    sama seperti gerbang ciri planet: sebuah beda yang terukur pada 200 px
    bisa habis total pada ukuran yang benar-benar tampil.
    """
    swift = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                               "DeepSkyCatalogue.swift")).read()
    model_source = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                                     "CelestialVisual.swift")).read()
    port_source = open(R.SOURCE, encoding="utf-8").read()

    try:
        ids, fuzziness, morphology = read_deep_sky_catalogue_from_swift(swift)
        model_growth = deep_sky_growth_parameters(
            model_source, "private static func buildDeepSky(")
        port_growth = deep_sky_growth_parameters(port_source, "def deep_sky_blobs(")
        drawn_keys = read_deep_sky_drawing_from_swift(port_source)
    except ValueError as exc:
        results.append(Result("katalog langit dalam: terbaca dari sumber", False, str(exc)))
        return

    # Katalog yang tidak lengkap dilaporkan **di sini**, bukan dibiarkan
    # meledak sebagai `KeyError` saat menggambar. Gerbang yang melempar
    # traceback saat tabelnya disunting akan dihapus orang.
    missing = {label: sorted(set(ids) - set(table))
               for label, table in (("fuzziness", fuzziness), ("morfologi", morphology))}
    incomplete = any(missing.values())
    for label, absent in missing.items():
        results.append(Result(
            f"katalog langit dalam: setiap objek punya entri {label}",
            not absent,
            f"{len(ids)} objek" if not absent else f"tanpa entri {label}: {absent}"))

    orphan = sorted(set(fuzziness) - set(ids))
    results.append(Result(
        "katalog langit dalam: tidak ada entri tanpa objeknya",
        not orphan, "tidak ada" if not orphan else f"entri tanpa objek: {orphan}"))

    results.append(Result(
        "katalog langit dalam: angka fuzziness-nya tidak seragam",
        len(set(fuzziness.values())) > 1,
        f"{len(set(fuzziness.values()))} nilai berbeda dari {len(fuzziness)} objek"
        if len(set(fuzziness.values())) > 1
        else "seluruh objek memakai satu angka: 'seberapa menyebar' tidak lagi per objek"))

    # ── 1. Rumus yang mengubah angka itu menjadi ukuran blob ──────────────
    same_growth = model_growth == port_growth
    results.append(Result(
        "katalog langit dalam: rumus growth sama di kedua bahasa",
        same_growth,
        f"{model_growth[0]:g} + {model_growth[1]:g}·fuzziness" if same_growth
        else f"model {model_growth}, port {port_growth}"))

    results.append(Result(
        "katalog langit dalam: fuzziness benar-benar memperlebar kabut",
        model_growth[1] != 0,
        f"span {model_growth[1]:g} (0 = angka katalog tidak mengubah apa pun)"
        if model_growth[1] != 0 else f"span 0: growth tetap {model_growth[0]:g}"))

    steps = [i / 10 for i in range(11)]
    widths = [deep_sky_growth(model_growth, f) for f in steps]
    results.append(Result(
        "katalog langit dalam: growth naik seiring fuzziness",
        all(a < b for a, b in zip(widths, widths[1:])),
        f"{widths[0]:.3f} … {widths[-1]:.3f} pada fuzziness 0…1"))

    # ── 2. Kunci yang diambil penggambar == kunci yang diisi kasus render ──
    results.append(Result(
        "katalog langit dalam: penggambar membaca kunci fuzziness yang benar",
        "fuzziness" in drawn_keys,
        f"kw.get: {drawn_keys}" if "fuzziness" in drawn_keys
        else f"_draw_deep_sky mengambil {drawn_keys}, bukan \"fuzziness\" — "
             "seluruh tabel katalog jatuh ke nilai bawaan"))

    if incomplete:
        return

    watch = watch_visual_diameter()
    if watch is None:
        results.append(Result(
            "katalog langit dalam: ukuran visual jam terbaca dari token", False,
            "WatchMetrics.visualDiameter tidak terbaca di WatchTheme.swift — "
            "tanpa itu gerbang ini tidak mengukur ukuran yang tampil"))
        return

    # ── 3 & 4. Angkanya sampai ke gambar, dan bedanya terlihat ────────────
    def picture(morph, fuzz):
        canvas = R.render(R.VisualCase("probe", "", "deepSky", morphology=morph,
                                       fuzziness=fuzz, is_confirmed=True),
                          size=watch, ss=ss)
        return [tuple(px) for px in canvas.buf]

    # Kabut netral: satu render per morfologi, bukan per objek — port
    # menggambar dari (morfologi, fuzziness) saja, jadi hasilnya sama.
    neutral = {morph: picture(morph, 0.6) for morph in set(morphology.values())}

    ineffective = [oid for oid in ids
                   if picture(morphology[oid], fuzziness[oid]) == neutral[morphology[oid]]]
    results.append(Result(
        "katalog langit dalam: angka katalog punya efek pada gambar jam",
        not ineffective,
        f"{len(ids)} objek di {watch} pt" if not ineffective
        else f"gambar identik dengan kabut netral 0.6: {ineffective}"))

    # Di dalam satu morfologi, nilai yang berbeda harus terlihat berbeda.
    # Kalau tidak, tabel per objek hanya berbeda di atas kertas.
    collisions = []
    by_morph = {}
    for object_id in ids:
        by_morph.setdefault(morphology[object_id], []).append(object_id)
    for morph, group in sorted(by_morph.items()):
        rendered = {oid: picture(morph, fuzziness[oid]) for oid in group}
        for i, first in enumerate(group):
            for second in group[i + 1:]:
                if fuzziness[first] != fuzziness[second] and rendered[first] == rendered[second]:
                    collisions.append(f"{first}/{second} ({morph})")
    results.append(Result(
        "katalog langit dalam: nilai berbeda terlihat berbeda di ukuran jam",
        not collisions,
        "semua pasangan terbedakan" if not collisions
        else f"nilai berbeda, gambar identik: {collisions}"))


def check_night_mode_purity(results, size=200, ss=2):
    """Mode malam: hijau & biru harus **nol**, bukan "kecil" — di **setiap** kasus.

    Ini janji produknya, dan satu-satunya cara mengetahuinya adalah mengukur
    kanal yang benar-benar sampai ke piksel. `NightVisualTests` menguji
    fungsinya; di sini yang diukur adalah gambar yang jadi.

    **Kenapa daftar kasusnya tidak lagi ditulis tangan.** Versi sebelumnya
    menguji **tujuh** nama yang dipilih dengan tangan, sementara katalognya
    berisi 40 kasus. Tiga puluh tiga di antaranya — termasuk bahan paling
    terang di seluruh katalog, `craterRim` di `(0.86, 0.84, 0.81)` dengan
    kanal biru 0.81 — tidak pernah diukur dalam mode malam sama sekali.
    Warnanya *kebetulan* lewat `NightVisual` hari ini, jadi tidak ada cacat
    yang hidup; tapi "kebetulan benar" dan "dijaga" adalah dua hal berbeda,
    dan yang pertama berhenti benar tanpa memberi tahu siapa pun.

    Karena itu daftarnya **diturunkan dari `build_cases()`**: kasus render
    baru ikut terukur pada hari ia ditambahkan, bukan pada hari seseorang
    ingat menambahkannya ke sebuah daftar. Kalau katalognya kosong, gerbang
    ini merah — bukan hijau karena tidak ada yang diperiksa.
    """
    cases = R.build_cases()
    if not cases:
        results.append(Result("malam murni: katalog terbaca", False,
                              "build_cases() mengembalikan nol kasus"))
        return
    for case in cases:
        name = case.name
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


def check_night_mode_never_exceeds_day(results, size=120, ss=2):
    """Mode malam tidak boleh membuat satu pun piksel lebih terang.

    `check_night_mode_purity` menyapu hijau/biru sampai **nol** di seluruh
    katalog. Itu menutup kelas cacat yang lain: "buang warna" dijaga,
    "turunkan terang" tidak. Yang kedua tidak punya gerbang piksel sama
    sekali, jadi nilai lantai mode malam (`NIGHT_FLOOR_BRIGHTNESS`) bisa
    dinaikkan sewenang-wenang tanpa satu pun alarm — dan itulah yang diuji
    di sini.

    Invarian yang dipakai bukan angka tertentu melainkan **hubungan**:
    untuk setiap koordinat, malam <= siang. Daftar kasusnya diturunkan dari
    `build_cases()`, jadi kasus render baru ikut terukur pada hari ia
    ditambahkan, bukan pada hari seseorang ingat menambahkannya ke daftar.
    Katalog kosong menghasilkan merah, bukan hijau.

    **Yang tidak diukur gerbang ini**, supaya tidak dikira lebih dari
    kemampuannya: earthshine. Pada bulan sabit, malam memang lebih redup
    dari siang — earthshine tidak pernah membuat malam lebih terang. Cacat
    yang pernah hidup di sana enam kali terlalu terang lolos bukan karena
    invarian ini lemah, tapi karena tak ada yang mengukurnya di malam sama
    sekali. Yang mengukurnya `check_earthshine`, yang sekarang merender
    kedua modenya.
    """
    cases = R.build_cases()
    if not cases:
        results.append(Result("malam <= siang: katalog terbaca", False,
                              "build_cases() mengembalikan nol kasus"))
        return
    for case in cases:
        render = {}
        for malam in (False, True):
            canvas = R.render(case, size=size, night_mode=malam,
                              show_frame=False, ss=ss)
            path = os.path.join(R.OUT_DIR, f"__nd-{case.name}-{int(malam)}.png")
            with open(path, "wb") as handle:
                handle.write(canvas.to_png())
            render[malam] = luminance_field(path)
            os.remove(path)
        day, night = render[False], render[True]
        if len(day) != len(night):
            results.append(Result(f"malam <= siang: {case.name}", False,
                                  f"ukuran render berbeda: {len(day)} vs {len(night)}"))
            continue
        terparah, naiknya = 0.0, 0
        for d, n in zip(day, night):
            if n > d:
                naiknya += 1
                terparah = max(terparah, n - d)
        results.append(Result(
            f"malam <= siang: {case.name}", naiknya == 0,
            f"{naiknya} piksel lebih terang, puncak +{terparah:.1f}"))


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


def check_phase_direction_on_the_waning_half(results, size=200, ss=2):
    """Bulan **mengecil** harus menghadap sudut yang diminta, bukan cerminnya.

    **Cacat yang ditutup pemeriksaan ini.** `terminatorRotationRadians` punya
    dua jalur: pita yang dasarnya ada di kanan (membesar) memakai sudut
    Matahari apa adanya, dan pita yang dasarnya ada di **kiri** (mengecil)
    membalikkannya dengan `+ pi`. **Sebelum** lima kasus `is_waxing=False`
    ditambahkan bersama pemeriksaan ini, seluruh katalog render repo ini hanya
    berisi `waxing=True` — dan di seluruh `check-visuals.py` tidak ada satu pun
    `is_waxing=False`. Jadi jalur kedua tidak pernah digambar, tidak pernah
    diukur, dan tidak ada gerbang yang berbunyi kalau ia hilang.

    Terukur: dengan `+ pi` dihapus dari port, gerbang arah yang sudah ada
    (`check_crescent_direction` 4 pemeriksaan, `check_inner_planet_phase` 5,
    `check_moon_phase_fraction` 9, `check_moon_phase_survives_uncertainty` 3)
    tetap **0 merah**. Yang terjadi bukan pemeriksaan merah, melainkan Bulan
    yang mengecil menghadap **berlawanan arah** — sabit yang masih berbentuk
    sabit, sehingga tidak ada teks di layar mana pun yang bisa membuktikannya.

    **Kenapa sudutnya harus berasal dari satu kasus saja.** Pada sudut `0`
    (kanan) pembalikan `pi` memindahkan pita dari kiri ke kanan, jadi ia
    memang terukur. Tetapi justru di situlah penggantian `+ pi` dengan
    `+ 0` **tidak** menimbulkan cacat — pita dasarnya sudah di kiri. Karena
    itu kasus yang menentukan memakai sudut `-pi/2`: di sana satu-satunya
    arah yang benar adalah "bawah" pada kedua jalur, dan pita yang tidak
    dibalik menghadap **atas**. Pemeriksaan ini mengukur keduanya.

    Bulan dan Venus diukur bersama karena keduanya melewati
    `terminatorRotationRadians` yang sama: satu gerbang, dua pemanggil, jadi
    kesalahan yang diperbaiki di satu tempat tidak bisa bertahan di tempat lain.
    """
    # (nama kasus, palet, sudut yang diminta, arah yang diharapkan)
    lit_moon, unlit_moon = moon_colors()
    venus = tuple(tuple(round(c * 255) for c in R.PLANET_PALETTE["venus"][k])
                  for k in ("light", "dark"))

    cases = [
        ("moon-waning-crescent", lit_moon, unlit_moon, 0.0, "kanan"),
        ("moon-waning-crescent-pointing-down", lit_moon, unlit_moon,
         -math.pi / 2, "bawah"),
        ("planet-venus-waning-crescent", venus[0], venus[1], 0.0, "kanan"),
        ("planet-venus-waning-crescent-pointing-down", venus[0], venus[1],
         -math.pi / 2, "bawah"),
    ]
    for name, lit, unlit, angle, expected in cases:
        _, (w, h, rows) = render_case(name, size=size, ss=ss)
        dx, dy, _ = classify_centroid(w, h, rows, lit, unlit)
        measured = ("bawah" if dy > abs(dx) else
                    "atas" if -dy > abs(dx) else
                    "kanan" if dx > 0 else "kiri")
        results.append(Result(
            f"{name}: sisi terang menghadap {expected}",
            measured == expected,
            f"terukur {measured} (dx={dx:+.3f}, dy={dy:+.3f}) pada sudut "
            f"{angle:+.2f} — salah arah berarti pembalikan `+ pi` untuk pita "
            f"yang dasarnya di kiri hilang"))

    # Dan arah sebaliknya: Bulan yang **membesar** tidak boleh ikut dibalik.
    # Tanpa ini, pengganti yang membalikkan kedua jalur akan lolos keempat
    # pemeriksaan di atas dengan sempurna.
    _, (w, h, rows) = render_case("moon-crescent-jakarta", size=size, ss=ss)
    dx, dy, _ = classify_centroid(w, h, rows, lit_moon, unlit_moon)
    measured = ("bawah" if dy > abs(dx) else
                "atas" if -dy > abs(dx) else
                "kanan" if dx > 0 else "kiri")
    results.append(Result(
        "moon-crescent-jakarta (membesar) tidak ikut dibalik",
        measured == "bawah",
        f"terukur {measured} (dx={dx:+.3f}, dy={dy:+.3f}) pada sudut −pi/2"))


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


def check_moon_new_disc_reads_on_the_watch(results, size=38, ss=8):
    """Piringan bulan baru harus **terbaca** di ukuran kartu jam.

    **Cacat yang ditutup pemeriksaan ini.** Diukur pada 38 px (token jam
    `WatchMetrics.visualDiameter`), piringan `moon-new` dulu **1.32:1**
    terhadap latar kartu #0A0A0F — di bawah ambang keterbacaan mana pun, dan
    setara "kartu kosong": kartu jam yang tidak menyampaikan apa pun. Akarnya
    satu token, `moonEarthshine` (0.15) — pada f = 0 kekuatan earthshine
    `1 - f` = 1.0, jadi seluruh piringan bulan baru **adalah** warna itu.

    **Kenapa gerbang ini perlu ada padahal piringan itu "sengaja rata".** Yang
    tercatat di `check_moon_disc_keeps_its_curvature` adalah bahwa piringan
    gelap Bulan sengaja **tidak** diberi gradien — keputusan tentang *bentuk*.
    "Rata" bukan "tak terlihat", dan tidak ada gerbang mana pun yang mengukur
    yang kedua: `check_unknown_phase_is_not_a_new_moon` hanya menuntut bulan
    baru **berbeda** dari fase tak diketahui, jadi piringan yang sama-sama
    hitam di kedua sisi lolos — selama selisihnya 1/255.

    **Ambangnya dari WCAG, dan itu sebabnya 2.0.** Rasio kontras
    `(L_terang + 0.05) / (L_gelap + 0.05)` adalah ukuran keterbacaan standar
    yang sudah dipakai repo ini; 2.0 adalah titik di mana piringan berhenti
    menjadi noda dan mulai terbaca sebagai bentuk pada 38 px. Kalibrasinya
    diukur (`Tools/sapu-earthshine.py`): earthshine 0.30 → **2.39:1** (nilai
    yang dipakai), 0.24 → 1.85:1 (di bawah ambang, ditolak), 0.15 → 1.32:1
    (cacat asalnya). Ambang ini menahan nilainya **dan** menahan arah:
    menurunkannya kembali ke 0.15 membuat gerbang ini merah lagi.
    """
    _, (w, h, rows) = render_case("moon-new", size=size, ss=ss)
    cx, cy = w // 2, h // 2
    background = background_of(w, h, rows)
    # 3x3 pusat — penyampel yang sama dengan probe yang menemukan cacatnya.
    acc = [0, 0, 0]
    for y in range(cy - 1, cy + 2):
        for x in range(cx - 1, cx + 2):
            p = rows[y][x * 4:x * 4 + 3]
            for k in range(3):
                acc[k] += p[k]
    disc = tuple(v // 9 for v in acc)

    def relative_luminance(rgb):
        def channel(value):
            v = value / 255.0
            return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
        return (0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1])
                + 0.0722 * channel(rgb[2]))

    la, lb = relative_luminance(disc), relative_luminance(background)
    ratio = (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    results.append(Result(
        "bulan baru terbaca di ukuran jam (kontras >= 2.0:1)",
        ratio >= 2.0,
        f"{ratio:.2f}:1 pada {size} px — piringan {tuple(disc)} vs latar "
        f"{tuple(background)}"))


def saturn_ring_band_values(size, ss):
    """Median kanal merah pita cincin Saturnus, per paruh: `(celah, B, A)`.

    **Kenapa ini fungsi, bukan badan pemeriksaan.** Ia dipakai oleh
    `check_saturn_ring_bands_render` (yang memeriksa bentuknya di ukuran
    render) **dan** oleh `check_saturn_gap_reads_at_the_watch_size` (yang
    memeriksa apakah celahnya masih terbaca di ukuran yang benar-benar
    tampil). Kalau yang kedua menyampel dengan caranya sendiri, ia hanya
    membuktikan komentarnya cocok dengan alat ukur yang **berbeda** — persis
    kelas cacat yang sudah pernah nyata di berkas ini (`crater_wall_contrast`
    lahir dengan alasan yang sama).

    Cincin adalah elips, jadi memindai **baris** atau **kolom** menembusnya
    pada lintasan diagonal: nilainya berubah karena elipsnya menyempit, bukan
    karena pitanya berganti. Yang benar adalah mencuplik **sepanjang elips
    cincin itu sendiri** pada radius tertentu, lalu mengambil nilai
    tengahnya (median, bukan maksimum — maksimum tertarik oleh tepi yang
    di-antialias). Cuplikan di dalam proyeksi bola dibuang: di sana yang
    terlihat adalah permukaan planet, bukan cincin.
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

    out = {}
    for label, half in (("belakang", -1.0), ("depan", 1.0)):
        out[label] = (ring_value(band_radius(3), half),   # celah Cassini
                      ring_value(band_radius(2), half),   # pita B
                      ring_value(band_radius(4), half))   # pita A
    return out


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
    values = saturn_ring_band_values(size, ss)

    for label in ("belakang", "depan"):
        gap, bright_b, outer_a = values[label]
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
    back_b = values["belakang"][1]
    front_b = values["depan"][1]
    if back_b is not None and front_b is not None:
        results.append(Result(
            "cincin: paruh belakang lebih redup dari depan",
            back_b < front_b,
            f"belakang {back_b} < depan {front_b}"))
    else:
        results.append(Result("cincin: paruh belakang lebih redup dari depan",
                              False, "pita B tidak terukur di salah satu paruh"))


def check_saturn_gap_reads_at_the_watch_size(results, ss=8):
    """Celah Cassini harus terbaca pada ukuran yang **benar-benar tampil**.

    **Cacat yang ditutup pemeriksaan ini.** `check_saturn_ring_bands_render`
    menjalankan ambang `celah < pita - 12` pada `--size 200`. Di ukuran itu
    **kedua** lebar celah lulus: yang nyata (0.0304) dan yang dilebarkan
    (0.06). Artinya gerbang itu tidak bisa membedakan keduanya, dan
    `SATURN_CASSINI_WIDTH` boleh dikembalikan ke angka nyata tanpa satu pun
    pemeriksaan berubah warna — padahal di kartu jam hasilnya cincin **tanpa
    pemisah**.

    Diukur, bukan diasumsikan (selisih median kanal merah terhadap pita di
    kedua sisinya, pada 76 px = 38 pt @2x, `ss=8`):

        lebar celah      paruh belakang   paruh depan
        0.0304 (nyata)   +12              +5      <- gagal
        0.0600 (dipakai) +22              +23     <- lulus

    Ambangnya **sama** dengan gerbang bentuk di atas (`- 12`), bukan angka
    baru: yang berbeda hanya ukurannya. Kalau ambangnya diketik ulang di sini,
    dua gerbang bisa berhenti sepakat tanpa ada yang tahu.

    **Ukurannya dari token, bukan dari sini.** `WatchMetrics.visualDiameter`
    adalah 38 **poin**; yang dirender adalah 76 **piksel** karena jam Apple
    Watch menggambar @2x. Dua dikalikan di sini, di satu tempat, dengan
    alasan yang tertulis — bukan disebar sebagai `76` ke dalam pemeriksaan.
    Kalau tokennya hilang, pemeriksaan ini **merah**, bukan hijau tanpa
    mengukur apa pun.
    """
    diameter = watch_visual_diameter()
    if diameter is None:
        results.append(Result(
            "ukuran visual jam terbaca dari token (celah cincin)", False,
            "WatchMetrics.visualDiameter tidak ditemukan di WatchTheme.swift"))
        return
    # Poin → piksel. Apple Watch menggambar @2x; 38 pt adalah 76 px di layar.
    pixels = diameter * 2

    values = saturn_ring_band_values(pixels, ss)
    for label in ("belakang", "depan"):
        gap, bright_b, outer_a = values[label]
        if gap is None or bright_b is None or outer_a is None:
            results.append(Result(
                f"celah cincin terbaca pada {pixels} px (ukuran jam)", False,
                "tidak cukup piksel cincin di luar bola"))
            continue
        # Ambang yang sama dengan `check_saturn_ring_bands_render`.
        margin = min(bright_b - gap, outer_a - gap)
        results.append(Result(
            f"celah cincin terbaca pada {pixels} px (ukuran jam)", margin > 12,
            f"selisih terkecil {margin:+d} terhadap pita B {bright_b} / "
            f"pita A {outer_a} (celah {gap}); lebar nyata 0.0304 hanya "
            f"menghasilkan +5…+12 di ukuran ini"))


def spiral_arm_radii_all():
    """**Seluruh** cuplikan antar-titik lengan, termasuk yang jatuh di dalam inti.

    Dipisahkan dari `spiral_arm_radii()` supaya batas inti tidak menghapus
    sampel dari pengukuran mana pun: `check_spiral_arms_stay_continuous`
    memakai yang di luar inti, `check_spiral_core_reads_as_one_body` memakai
    yang di dalamnya.
    """
    arm = [(b[0], b[1]) for b in R.DEEP_SKY_LAYOUT["spiralGalaxy"][2:]]
    half = len(arm) // 2                 # satu lengan; lengan B cerminnya
    radii = sorted(math.hypot(x, y) for x, y in arm[:half])
    # Lima cuplikan di tiap celah antar-titik, supaya lubang di tengah celah
    # tidak bisa lolos di antara dua sampel.
    samples = []
    for inner, outer in zip(radii, radii[1:]):
        samples.extend(inner + (outer - inner) * (i / 5.0) for i in range(1, 5))
    return samples


def spiral_core_bulge_index():
    """Indeks blob **tonjolan inti** di tata letak `.spiralGalaxy`.

    Inti galaksi disinari dua blob di titik pusat: tonjolan terang (opasitas
    0.60) dan kabut cakram (0.13). Yang pertama itulah yang membuat pusatnya
    terbaca sebagai inti — kabut cakram lebih **lebar** tapi lebih redup, jadi
    memilih "yang terjauh di pusat" akan memilih kabut, dan pemeriksaannya lalu
    mengukur blob yang salah (versi pertama melakukan itu: indeks 1, bukan 0).
    Dipilih dari **opasitas tertinggi di pusat**, bukan dari urutan daftar.
    """
    centre = [(i, b) for i, b in enumerate(R.DEEP_SKY_LAYOUT["spiralGalaxy"])
              if b[0] == 0.0 and b[1] == 0.0]
    if not centre:
        return None
    return max(centre, key=lambda pair: pair[1][5])[0]


def spiral_core_samples():
    """Sampel di dalam jangkauan tonjolan inti yang **benar-benar terbaca**.

    Batasnya bukan `halfWidth` blob inti, melainkan jari-jari tempat
    sumbangannya turun ke bawah `READABILITY_THRESHOLD`. Diukur: `halfWidth`
    tonjolan 0.2957 R, tapi pada r=0.2843 sumbangannya hanya
    0.60·(1 − 0.2843/0.2957)·255 = **5.9** dari 255 — di bawah ambang 12, jadi
    menghapus tonjolannya memang tidak mengubah gambar di sana (+0°, diukur di
    `out/probe-inti-selisih.py`). Batas yang dipakai karena itu
    `halfWidth · (1 − ambang / (opasitas · 255))` = 0.2725 R, dan ketiga sampel
    yang tersisa memberi +124°/+106°/+44°.
    """
    index = spiral_core_bulge_index()
    if index is None:
        return []
    case = next(c for c in R.build_cases() if c.name == "deepsky-spiralGalaxy")
    blobs = R.deep_sky_blobs("spiralGalaxy", case.kw.get("fuzziness", 0.6))
    blob = blobs[index]
    opacity = blob["opacity"]
    if opacity <= 0:
        return []
    reach = blob["half_width"] * (1 - READABILITY_THRESHOLD / (opacity * 255))
    return [r for r in spiral_arm_radii_all() if r <= reach]


def spiral_arm_radii():
    """Jari-jari **di antara** titik lengan — tempat lengkungnya harus menyambung.

    **Kenapa bukan jari-jari titik lengan itu sendiri.** Versi pertama gerbang
    ini menyampel tepat di titik-titik lengan, dan hasilnya hijau pada tata
    letak yang rusak: yang bolong justru **antar** titik, bukan di titiknya.
    Titik lengan selalu punya piksel terang (di situlah blobnya), jadi mengukur
    di sana membuktikan hal yang tidak pernah diragukan.

    Jari-jari diambil dari model, bukan diketik di sini: kalau lengan
    dipendekkan atau ditambah titik, sampelnya ikut menyesuaikan.

    Sampel yang jatuh **di dalam inti** dibuang di sini; ia diukur oleh
    `check_spiral_core_reads_as_one_body`, di bawah klaim yang benar untuknya.
    """
    core = set(spiral_core_samples())
    return [r for r in spiral_arm_radii_all() if r not in core]


def spiral_arm_degrees(size, ss, radius):
    """Berapa derajat pada jari-jari itu yang di atas ambang terbaca."""
    _, (w, h, rows) = render_case("deepsky-spiralGalaxy", size=size, ss=ss)
    background = rows[0][0]
    cx, cy = w / 2.0, h / 2.0
    above = 0
    for degree in range(360):
        angle = math.radians(degree)
        x = int(round(cx + radius * math.cos(angle) * min(w, h) / 2.0))
        y = int(round(cy + radius * math.sin(angle) * min(w, h) / 2.0))
        if 0 <= x < w and 0 <= y < h:
            if rows[y][x * 4] - background > READABILITY_THRESHOLD:
                above += 1
    return above


def check_spiral_arms_stay_continuous(results):
    """Lengan `.spiralGalaxy` harus **menyambung** sepanjang jangkauannya.

    **Cacat yang ditutup pemeriksaan ini.** Tata letak lengan diuji sebagai
    *titik*: `testSpiralGalaxyHasArmsThatThePlainDiscDoesNot` menuntut lengan
    terjauh > 0.3 R dan tidak tertimbun tonjolan inti — keduanya benar dan
    keduanya tetap benar sekarang. Yang tidak dijaga siapa pun adalah apakah
    titik-titik itu **bertemu di layar**.

    Spiral logaritmik `r = 0.20·e^(0.30θ)` memberi jarak antar-titik yang
    **membesar** ke luar (Δr = 0.078 → 0.105 → 0.142), sementara lebar blob
    justru **menyusut** (0.24 → 0.22 → 0.19 → 0.16). Gradien radial tiap blob
    sudah meredup sebelum bertemu tetangganya, jadi lengkungnya terputus tepat
    di antara dua titik terluar. Diukur pada ukuran jam (76 px, `ss=8`),
    tata letak 4-titik yang lama:

        r      +di atas latar   derajat di atas ambang   (kolom diukur di
                                                          out/probe-lengan-latar.py)
        0.40   +28               59°   menyambung
        0.45   +20               38°   menyambung
        0.48   +16                8°   PUTUS
        0.50   +16                6°   PUTUS
        0.52   +16                6°   PUTUS
        0.55   +20               12°   menyambung

    Jadi lengan bukan "redup" — ia **bolong**: satu jari-jari penuh tanpa
    goresan, di antara dua jari-jari yang bergoresan. Di layar itu terbaca
    sebagai gumpalan yang bergerigi, bukan galaksi berlengan, dan itulah satu-
    satunya hal yang membedakan M51 dari M31.

    **Kenapa 16 jari-jari, bukan satu.** Ambang 12° sengaja duduk di tengah
    antara 6-12° (bolong) dan 38-59° (menyambung), jadi ambangnya sendiri
    **tidak** memisahkan keduanya di r=0.55. Yang memisahkan adalah bentuk
    lengkungnya: dengan 4 titik, tiga jari-jari berurutan (0.48, 0.50, 0.52)
    jatuh di bawah ambang sekaligus; dengan 5 titik, **tidak satu pun** dari
    16 jari-jari itu turun di bawah 17°.

    **Kenapa ukuran jam.** Bentuk yang lulus di 200 px bisa hilang di ukuran
    yang benar-benar tampil — alasan yang sama dengan
    `check_saturn_gap_reads_at_the_watch_size`.

    **Kenapa "derajat di atas ambang", bukan "ada piksel terang".** Goresan
    lengan di ukuran jam selebar beberapa piksel. Satu piksel terang bisa
    datang dari anti-aliasing atau dari bintang latar; yang membuktikan ada
    **goresan** adalah beberapa derajat berurutan yang di atas ambang.

    **Batas yang dinyatakan.** Gerbang ini menggambar pada fuzziness kasus
    render (`deepsky-spiralGalaxy`, 0.8), sementara katalog menggambar M51
    pada 0.92 dan M101 pada 0.88. Diukur di ketiganya
    (`out/probe-fuzz-lengan.py`): cacatnya ada di **ketiganya** (6-8° pada
    0.48-0.52 untuk tata letak lama) dan perbaikannya juga di ketiganya
    (>= 20°), jadi yang diukur bukan gambar yang tidak pernah tampil. Yang
    **tidak** diklaim: gerbang ini tidak menyapu seluruh rentang fuzziness
    katalog; fuzziness baru yang jauh berbeda tidak otomatis terukur.
    """
    diameter = watch_visual_diameter()
    if diameter is None:
        results.append(Result(
            "lengan spiral menyambung di ukuran jam", False,
            "WatchMetrics.visualDiameter tidak ditemukan di WatchTheme.swift"))
        return
    pixels = diameter * 2          # poin -> piksel, jam menggambar @2x

    radii = spiral_arm_radii()
    if len(radii) < 2:
        results.append(Result(
            "lengan spiral menyambung di ukuran jam", False,
            "kurang dari dua titik lengan di model — tidak ada yang bisa diukur"))
        return

    for radius in radii:
        degrees = spiral_arm_degrees(pixels, 8, radius)
        results.append(Result(
            f"lengan spiral menyambung pada r={radius:.2f} (ukuran jam)",
            degrees >= MIN_ARM_DEGREES,
            f"{degrees}° di atas ambang {READABILITY_THRESHOLD} pada {pixels} px; "
            f"butuh >= {MIN_ARM_DEGREES}° — di bawah itu lengkungnya bolong "
            f"dan yang tampil gumpalan bergerigi"))


def check_planetary_nebula_shell_is_continuous(results):
    """Cangkang `.planetaryNebula` harus **bersambung**, bukan untaian manik.

    **Cacat yang ditutup pemeriksaan ini.** Bentuk ini diuji sebagai
    *lingkaran*: `testPlanetaryNebulaShellSitsOnOneRadius` menuntut semua
    blobnya sejauh sama dari pusat, `testPlanetaryNebulaIsHollowAtTheCentre`
    menuntut bagian tengahnya kosong. Keduanya benar, dan keduanya tetap benar
    pada gambar yang rusak — **untaian delapan manik juga duduk pada satu
    radius dan juga berongga di tengah.** Yang tidak dijaga siapa pun adalah
    apakah manik-manik itu **bertemu**.

    Delapan blob pada radius 0.42 R berjarak 0.3215 R (tali busur 45°),
    sementara tiap pasangan bertetangga menjangkau 0.239…0.385 R tergantung
    fuzziness. Sebagai kelipatan tali busurnya: **0.74x (fuzziness 0), 0.92x
    (0.40), 1.05x (0.68), 1.20x (1.0)** — dan dua nilai tengah itu justru
    fuzziness katalog (M57 0.40, M27 0.68). Pada 0.40 maniknya berjarak, pada
    0.68 baru tepat bersinggungan: nol cadangan. Diukur pada 132 pt, celah di
    antara blob turun ke **0.18** dari puncaknya di atas latar. Di layar itu
    delapan titik terpisah yang kebetulan melingkar, dan penilaian atas
    gambarnya menyebutnya persis begitu: "string of pearls". Cangkang nyata
    (cincin M57) adalah **satu** kulit; yang membedakannya dari gugus bintang
    justru kesinambungannya.

    **Kenapa diukur sebagai profil angular, bukan min/max.** Versi pertama
    gerbang ini membandingkan kecerahan **terang** dan **gelap** pada radius
    cangkang, dan ia **buta justru pada cacat yang diklaimnya**: opasitas
    blob terbesar 0.54, jadi jumlah blob yang tumpang tindih berhenti
    menambah kecerahan begitu totalnya melewati 0.54 — puncaknya tersaturasi
    sementara celahnya tidak. Versi 16-blob karena itu sempat terukur
    **lebih buruk** daripada versi 8-blob (1.13 vs 0.15) oleh metrik itu,
    padahal gambarnya jelas lebih bersambung. Yang benar-benar membedakan
    cangkang dari manik adalah **bagian gelapnya**: pada manik, sudut di
    antara blob turun hampir ke latar.

    **Batas yang dinyatakan.** Gerbang ini menggambar pada fuzziness kasus
    render (`deepsky-planetaryNebula`, 0.8), sementara katalog menggambar M57
    pada 0.40 dan M27 pada 0.68. Dua keadaan itu diuji terpisah: uji model
    `testPlanetaryNebulaShellIsContinuousNotBeaded` menyapu kelimanya
    (0.0/0.4/0.68/0.8/1.0) pada geometrinya, dan harness
    `Tools/bukti-mutasi-cangkang.py` membuktikan gerbang **berbunyi** pada
    tata letak lama (merah) dan **diam** pada kode sekarang (hijau). Yang
    **tidak** diklaim: gerbang ini sendiri tidak menyapu seluruh rentang
    fuzziness katalog — itu tugas uji model.
    """
    diameter = watch_visual_diameter()
    if diameter is None:
        results.append(Result(
            "cangkang nebula planetari bersambung", False,
            "WatchMetrics.visualDiameter tidak ditemukan di WatchTheme.swift"))
        return
    pixels = diameter * 2          # poin -> piksel, jam menggambar @2x

    # Diukur di dua ukuran: ukuran jam (tempat bentuk ini paling sering
    # dilihat) dan ukuran panel iPhone (tempat ia paling besar). Yang lulus
    # di satu ukuran belum tentu lulus di ukuran lain — itu pelajaran yang
    # sudah dua kali dibayar di repo ini.
    #
    # **Dan di dua fuzziness, bukan satu.** Sampai siklus ini pemeriksaan ini
    # hanya pernah menggambar `deepsky-planetaryNebula` (fuzziness 0.8) —
    # sementara katalog menggambar **M57 pada 0.40**. Itu bukan perbedaan
    # kecil: 0.8 membuat blobnya 1.75× lebih lebar dari jaraknya, 0.40 hanya
    # 1.46×. Gerbangnya hijau di kasus rujukan sementara objek yang
    # **benar-benar tampil** di layar masih berupa untaian manik — kelas cacat
    # yang sama dengan "0.14 R Venus" yang dulu ditutup: gerbang yang mengukur
    # gambar yang **tidak tampil**. Sekarang keduanya diukur, jadi melonggarkan
    # tata letak rujukan tidak bisa lagi menyembunyikan M57.
    for case_name, label in (("deepsky-planetaryNebula", "rujukan f=0.8"),
                             ("deepsky-m57", "M57 katalog f=0.40")):
        for size, ss in ((pixels, 8), (132, 4)):
            background, tenth, top = shell_angular_profile(size, ss,
                                                           case_name=case_name)
            if top - background <= READABILITY_THRESHOLD:
                results.append(Result(
                    f"cangkang nebula planetari bersambung ({size}px, {label})",
                    False,
                    f"cangkangnya tidak terbaca sama sekali (puncak {top}, "
                    f"latar {background})"))
                continue
            fraction = (tenth - background) / (top - background)
            results.append(Result(
                f"cangkang nebula planetari bersambung ({size}px, {label})",
                fraction >= MIN_SHELL_CONTINUITY,
                f"celah terburuk {fraction:.2f} dari puncak (butuh "
                f">= {MIN_SHELL_CONTINUITY}) — di bawah itu yang tampil untaian "
                f"manik, bukan cangkang gas"))


def shell_angular_profile(size, ss, radius=0.42, case_name="deepsky-planetaryNebula"):
    """Profil kecerahan sepanjang radius cangkang, diringkas jadi tiga angka.

    **Kenapa `case_name` bisa diganti.** Cangkang planetari punya dua kasus
    render dengan fuzziness yang berbeda jauh — rujukan (0.8) dan **M57
    katalog (0.40)**. Fuzziness menentukan seberapa lebar blobnya, jadi
    kesinambungan yang terukur pada satu nilai tidak berlaku untuk yang lain.
    Sebelum parameter ini ada, hanya kasus rujukan yang pernah diukur.

    **Kenapa dirata-rata pada radius kecil (0.39…0.45 R), bukan satu piksel.**
    Cangkangnya hanya beberapa piksel tebal pada ukuran jam. Satu piksel bisa
    meleset ke dalam lubang atau ke luar tepi, dan hasilnya mengukur posisi
    sampel, bukan bentuknya. Rata-rata tujuh radius membuat angkanya mewakili
    **tebal cangkangnya**, bukan satu baris piksel yang kebetulan meleset.

    **Kenapa persentil, bukan min/max.** Cangkangnya bergradien; yang
    menentukan apakah ia terbaca sebagai kulit yang bersambung adalah
    **lantai** kecerahannya di antara blob, dan lantai itu lebih jujur
    diukur sebagai persentil ke-10 daripada sebagai piksel tergelap tunggal,
    yang bisa saja satu piksel anti-aliasing di tepi lubang.
    """
    _, (w, h, rows) = render_case(case_name, size=size, ss=ss)
    background = rows[0][0]
    cx, cy = w / 2.0, h / 2.0
    samples = []
    # Setengah derajat, bukan satu: pada ukuran jam satu derajat hanya
    # beberapa piksel, jadi resolusi sudutnya terlalu kasar untuk melihat
    # celah di antara blob yang berjarak 15°.
    for step in range(720):
        angle = math.radians(step * 0.5)
        band = []
        for fraction in (0.39, 0.40, 0.41, 0.42, 0.43, 0.44, 0.45):
            x = int(round(cx + fraction * radius / 0.42 * math.cos(angle) * min(w, h) / 2.0))
            y = int(round(cy + fraction * radius / 0.42 * math.sin(angle) * min(w, h) / 2.0))
            if 0 <= x < w and 0 <= y < h:
                band.append(rows[y][x * 4])
        if band:
            samples.append(sum(band) / len(band))
    if not samples:
        return background, background, background
    samples.sort()
    return (background,
            samples[int(0.10 * len(samples))],
            samples[int(0.98 * len(samples))])


def check_dumbbell_nebula_is_an_elongated_shell(results):
    """M27 harus benar-benar tampil **memanjang** — dan lubangnya tetap terbuka.

    **Cacat yang ditutup pemeriksaan ini.** Katalog memetakan M27 (Dumbel) dan
    M57 (Cincin) ke morfologi yang sama, `.planetaryNebula`, dan sampai siklus
    ini keduanya digambar **identik**: siluet 1.000 (bulat sempurna) pada
    setiap fuzziness. Ukuran nyatanya berbeda jauh — M27 8.0′ × 5.7′ (rasio
    sumbu 0.71, dilihat dari samping), M57 1.4′ × 1.0′ (hampir tepat dari
    kutubnya). Dua objek katalog yang seharusnya berbeda bentuk digambar sama:
    kelas cacat yang sama dengan yang pernah ditutup untuk M31/M51.

    Uji model (`testDumbbellNebulaIsAnElongatedShellNotARoundOne`) mengunci
    **geometrinya**; gerbang ini mengukur **gambarnya**, karena geometri yang
    benar bisa hilang di jalur gambar — persis alasan berkas ini ada.

    **Dua sifat sekaligus, karena satu saja menghasilkan cacat lain.**

    1. *Siluet memipih pada sumbu yang benar.* Diukur sebagai kotak pembatas
       piksel di atas `READABILITY_THRESHOLD`. Diukur di **dua** ukuran — 200 px
       (panel iPhone) dan 76 px (ukuran jam, tempat ia paling sering dilihat):
       yang lulus di satu ukuran belum tentu lulus di ukuran lain.

           kasus                   200 px          76 px
           M27 (elongasi 0.60)     104×70 (0.673)   40×26 (0.650)
           M57 (elongasi 1.0)      102×102 (1.000)  38×38 (1.000)

       Ambang 0.80 dan 0.92 sengaja duduk di antara keduanya dengan margin,
       bukan tepat di angkanya: yang dijaga "jelas memanjang vs jelas bulat",
       bukan nilai ketiga desimal yang tidak ada artinya di layar.

    2. *Lubangnya tetap terbuka.* Ini bukan formalitas: memipihkan **posisi**
       blob tanpa memipihkan **tingginya** memenuhi sifat (1) sambil menutup
       pusatnya. Diukur pada keadaan itu (`Tools/bukti-mutasi-dumbel.py`,
       keadaan 3 — harness yang di-track dan dijalankan CI, bukan prob di
       `out/` yang di-gitignore), pada ukuran jam: pusat terisi **0.571** dari
       terang cangkang, dari **0.081** pada kode sekarang. Ambang 0.25 duduk di
       antaranya. Ukuran 200 px tidak memisahkan keduanya (0.000 vs 0.078) —
       blobnya lebih rapat dari jaring sampel pusat, jadi keadaan itu memang
       dituntut merah hanya di 76 px.

       **Cacat kedua di dalam pemeriksaan ini, ditemukan oleh harness itu.**
       Sampai siklus ini baris pusat memakai `case_name`, sisa variabel gelung
       yang setelah gelung bernilai `deepsky-m57`. Pemeriksaan berlabel M27
       karena itu mengukur pusat **M57**, yang tetap berongga dalam setiap
       keadaan — hijau pada kode benar dan pada cacat, yaitu lulus karena
       alasan yang salah. Harness menunjukkannya: keadaan 3 "dapat hijau" untuk
       pemeriksaan yang seharusnya merah. Sekarang namanya `M27_CASE`.

    **Batas yang dinyatakan.** Gerbang ini tidak menyapu seluruh rentang
    fuzziness katalog: ia menggambar M27 pada fuzziness katalognya (0.68) dan
    M57 pada 0.40. Fuzziness lain tidak otomatis terukur.
    """
    for size, ss in ((200, 2), (76, 8)):
        measured = {}
        for case_name, label in (("deepsky-m27", "M27 (Dumbel, dari samping)"),
                                 ("deepsky-m57", "M57 (Cincin, dari kutub)")):
            extent = bright_extent(case_name, size=size, ss=ss)
            if extent is None:
                results.append(Result(
                    f"{label} punya siluet terukur ({size}px)", False,
                    "tidak ada piksel di atas ambang — tidak ada yang bisa diukur"))
                return
            width, height = extent
            measured[case_name] = height / width

        ratio27 = measured["deepsky-m27"]
        ratio57 = measured["deepsky-m57"]
        results.append(Result(
            f"M27 memanjang, bukan bulat ({size}px)",
            MIN_DUMBBELL_ASPECT <= ratio27 <= MAX_DUMBBELL_ASPECT,
            f"siluet M27 {ratio27:.3f} (butuh {MIN_DUMBBELL_ASPECT}…"
            f"{MAX_DUMBBELL_ASPECT}); rasio nyatanya 0.71 (8.0′ : 5.7′) — di "
            f"atas ambang atas ia tampil bulat seperti M57, di bawah ambang "
            f"bawah ia lensa tipis"))
        results.append(Result(
            f"M57 tetap bulat ({size}px)",
            ratio57 >= MIN_RING_ASPECT,
            f"siluet M57 {ratio57:.3f} (butuh >= {MIN_RING_ASPECT}) — "
            f"memipihkannya berarti sudut pandangnya salah"))

        # Lubang tengah: terang pusat dibagi terang cangkang — **M27**, bukan
        # kasus terakhir dari gelung di atas.
        #
        # Kenapa ini ditulis dengan nama, bukan `case_name`: sampai siklus ini
        # baris ini memakai `case_name`, yang setelah gelung bernilai
        # `deepsky-m57`. Jadi pemeriksaan berlabel "cangkang M27 tetap berongga"
        # mengukur **pusat M57** — dan hijau di setiap keadaan, termasuk pada
        # cacat yang seharusnya ditangkapnya (pusat M27 terisi 0.571 pada 76 px,
        # jauh di atas ambang 0.25). Pemeriksaan yang lulus karena alasan yang
        # salah: kelas cacat yang sama dengan variabel bocor pada `_shell_layout`.
        background, centre, shell = nebula_centre_and_shell(M27_CASE,
                                                            size=size, ss=ss)
        if shell - background <= READABILITY_THRESHOLD:
            results.append(Result(
                f"cangkang M27 berongga ({size}px)", False,
                f"cangkangnya tidak terbaca (pusat {centre}, cangkang {shell})"))
            return
        fill = (centre - background) / (shell - background)
        results.append(Result(
            f"cangkang M27 tetap berongga di tengah ({size}px)",
            fill <= MAX_CENTRE_FILL,
            f"pusat terisi {fill:.3f} dari terang cangkang (butuh <= "
            f"{MAX_CENTRE_FILL}) — di atas itu cangkang berongga sudah jadi "
            f"gumpalan pipih"))

    # Port-parity: angka yang digambar harus sama di kedua sumber.
    swift = swift_elongation("m27")
    port = R.DEEP_SKY_ELONGATION.get("m27")
    results.append(Result(
        "elongasi M27 sama di model dan di port",
        swift is not None and port is not None and abs(swift - port) < 1e-9,
        f"Swift elongationByID[\"m27\"]={swift}, port DEEP_SKY_ELONGATION[\"m27\"]={port}"))


def swift_elongation(object_id):
    """`DeepSkyCatalogue.elongationByID["m27"]` dibaca dari berkas Swift.

    **Kenapa dicari di dalam blok `elongationByID`, bukan `"m27":` begitu saja.**
    Id yang sama muncul di **tiga** tabel (`morphologyByID`, `fuzzinessByID`,
    `elongationByID`). `source.index('"m27":')` mengembalikan yang **pertama**
    ditemukan — `morphologyByID` — dan pembaca angka di bawahnya akan menerima
    `.planetaryNebula`, bukan angka. Gerbang yang membandingkan hal itu dengan
    port akan merah pada kode yang benar, atau (lebih buruk) hijau karena kedua
    sisinya kebetulan sama-sama salah.
    """
    path = os.path.join(ROOT, "Packages", "PointingKit", "Sources",
                        "PointingKit", "DeepSkyCatalogue.swift")
    with open(path, encoding="utf-8") as handle:
        source = handle.read()
    table = "elongationByID"
    if table not in source:
        return None
    block = source[source.index(table):]
    marker = f'"{object_id}":'
    if marker not in block:
        return None
    tail = block[block.index(marker) + len(marker):]
    number = ""
    for char in tail.strip():
        if char.isdigit() or (char == "." and number):
            number += char
        else:
            break
    return float(number) if number else None


def bright_extent(case_name, size, ss):
    """Kotak pembatas piksel di atas ambang, sebagai `(lebar, tinggi)`."""
    _, (w, h, rows) = render_case(case_name, size=size, ss=ss)
    background = rows[0][0]
    xs, ys = [], []
    for y in range(h):
        row = rows[y]
        for x in range(w):
            if row[x * 4] - background > READABILITY_THRESHOLD:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return max(xs) - min(xs) + 1, max(ys) - min(ys) + 1


def nebula_centre_and_shell(case_name, size, ss, radius=0.36):
    """Terang di pusat vs terang rata-rata pada cincin cangkang.

    **Kenapa `max` di pusat, bukan rata-rata.** Versi pertama memakai rata-rata
    di dalam radius kecil dan **buta pada cacat yang diklaimnya**: begitu
    pusatnya mulai terisi, yang terang hanya sebagian kecil dari lingkaran
    sampelnya, jadi rata-ratanya masih ditarik ke bawah oleh sisanya yang
    kosong. Nilai terburuk (`max`) tidak punya tempat untuk bersembunyi.
    """
    _, (w, h, rows) = render_case(case_name, size=size, ss=ss)
    background = rows[0][0]
    cx, cy = w / 2.0, h / 2.0

    def channel(px, py):
        x, y = int(round(px)), int(round(py))
        if 0 <= x < w and 0 <= y < h:
            return rows[y][x * 4]
        return background

    centre = max(channel(cx + dx, cy + dy)
                 for dy in range(-4, 5) for dx in range(-4, 5)
                 if dx * dx + dy * dy <= 16)
    ring = radius * min(w, h) / 2.0
    samples = [channel(cx + ring * math.cos(2 * math.pi * step / 360.0),
                       cy + ring * math.sin(2 * math.pi * step / 360.0))
               for step in range(360)]
    return background, centre, sum(samples) / len(samples)


def check_spiral_core_reads_as_one_body(results):
    """Tonjolan inti `.spiralGalaxy` harus **benar-benar menerangi pusatnya**.

    **Cacat yang ditutup pemeriksaan ini.** Sampel gerbang lengan yang jatuh di
    dalam inti selalu hijau — intinya memang menutupi sebagian besar cincin,
    jadi derajatnya 266-360°. Tiga dari enam belas sampel dulu seperti itu
    (r=0.2377 → 360°, r=0.2532 → 340°, r=0.2688 → 266°), dan **tidak satu pun
    bisa merah untuk alasan yang ditulis di namanya**: yang diukur inti, bukan
    lengan. Gerbang yang lulus karena mengukur bagian lain dari gambar adalah
    kelas yang sama dengan "gerbang yang mengukur gambar yang tidak tampil",
    hanya saja yang salah di sini **apa** yang diukur, bukan ukurannya.

    **Kenapa selisih, bukan ambang mutlak.** Versi pertama pemeriksaan ini
    menuntut cakupan cincin >= 340° pada setiap sampel inti. Itu **merah pada
    kode yang benar**: sampel di tepi tonjolan (r=0.2688) sehat pada 266°,
    karena di beberapa derajat lingkarnya sudah melewati piringan. Menaikkan
    ambang sampai hijau berarti menebak satu angka dari luar gambar, dan angka
    itu merah lagi begitu tata letaknya bergeser. Yang benar-benar penting
    bukan cakupan mutlaknya, melainkan **apakah tonjolan inti menyumbang
    sesuatu** — jadi yang diukur adalah selisih cakupan **dengan** vs **tanpa**
    tonjolan, dan selisih itu tidak butuh ambang yang ditebak.

    Diukur pada ukuran jam (76 px, `ss=8`) — `out/probe-inti-selisih.py`:

        r        dengan tonjolan   tanpa tonjolan   selisih
        0.2377   360°              236°             +124°
        0.2532   340°              234°             +106°
        0.2688   266°              222°              +44°
        0.2843   200°              200°               +0°   <- bukan sampel inti

    Baris terakhir itu yang menunjukkan batasnya: r=0.2843 masih di dalam
    `halfWidth` tonjolan (0.2957 R), tapi sumbangannya sudah di bawah ambang
    terbaca (+0°, diukur), jadi menghapus tonjolannya tidak mengubah gambar di
    sana dan sampel itu **bukan** sampel inti. Sampelnya karena itu diambil
    dari `spiral_core_samples()`, yang menghitung batas itu dari model
    (0.2725 R) — bukan dari angka yang ditulis di sini.

    **Cacat yang ditangkapnya nyata, tapi jalurnya perlu dinyatakan persis.**
    Diukur ulang lewat gerbangnya sendiri (`out/bukti-mutasi-spiral.py`), dan
    hasilnya **bukan** yang versi pertama docstring ini klaim:

        mutasi                        yang berbunyi
        tonjolan dihapus              +0° di ketiga sampel (delta)
        tonjolan diperkecil 0.32→0.10 0 sampel — himpunan sampelnya runtuh
        tonjolan diredupkan 0.60→0.20 0 sampel — himpunan sampelnya runtuh

    Untuk dua mutasi terakhir yang berbunyi adalah pemeriksaan "sampel inti
    ada", **bukan** pemeriksaan selisih: batas sampel dihitung dari
    `halfWidth · (1 − ambang / (opasitas · 255))`, jadi memperkecil tonjolan
    atau meredupkannya memindahkan batas itu ke bawah seluruh sampel, dan
    gerbangnya berkata "tidak ada sampel di dalam tonjolan inti" — bukan
    "sumbangannya terlalu kecil". Keduanya merah, dan itu memang yang harus
    terjadi, tapi pesannya menunjuk tempat yang berbeda dari yang dikutip
    (+0°/+12° adalah delta yang **tidak pernah** terukur oleh gerbang itu).

    Ini kelas yang sama dengan angka-angka yang salah kutip di docstring
    gerbang lain di berkas ini: komentar adalah satu-satunya bukti yang dibaca
    orang yang menilai apakah gerbangnya layak dipercaya, jadi ia harus
    berbentuk hasil ukur yang bisa dibantah — bukan penjelasan yang masuk akal.
    Yang benar-benar dijaga gerbang ini diukur sebagai berikut:

        keadaan                        lengan merah   inti merah
        [baseline]                     0/13            0/3
        titik sisipan dihapus          1/9  (r=0.49)   0/3
        tonjolan 0.32 → 0.10           0/16            1/1
        tonjolan 0.60 → 0.20           0/16            1/1

    Dan `r=0.2843` — sampel yang bukan sampel inti — **tetap hijau di keempat
    keadaan**, yang membuktikan batas "sampel inti" itu bekerja: kalau batasnya
    longgar, keempat sampel akan diukur sebagai inti dan gerbang lengan akan
    merah pada gambar yang benar.

    **Kenapa bukan sekadar menghapus sampelnya dari gerbang lengan.**
    Menghapus berarti cakupannya berkurang tanpa pengganti: inti menjadi
    satu-satunya bagian galaksi yang tidak diukur apa pun.
    """
    diameter = watch_visual_diameter()
    if diameter is None:
        results.append(Result(
            "inti spiral padat di ukuran jam", False,
            "WatchMetrics.visualDiameter tidak ditemukan di WatchTheme.swift"))
        return
    pixels = diameter * 2

    index = spiral_core_bulge_index()
    samples = spiral_core_samples()
    if index is None or not samples:
        # Bukan merah: gerbang lengan yang menyapu seluruh celah antar-titik
        # tetap mengukur bentuknya. Yang hilang hanya klaim tentang intinya,
        # dan itu dinyatakan sebagai pemeriksaan yang tidak dijalankan —
        # bukan dihitung sebagai lulus.
        results.append(Result(
            "tonjolan inti menyinari pusat (ukuran jam)", False,
            f"tidak ada sampel di dalam tonjolan inti (indeks {index}, "
            f"{len(samples)} sampel) — `spiral_core_bulge_index()` / "
            f"`spiral_core_samples()` kehilangan blob intinya"))
        return

    layout = list(R.DEEP_SKY_LAYOUT["spiralGalaxy"])
    for radius in samples:
        with_bulge = spiral_arm_degrees(pixels, 8, radius)
        R.DEEP_SKY_LAYOUT["spiralGalaxy"] = [
            b for i, b in enumerate(layout) if i != index]
        try:
            without = spiral_arm_degrees(pixels, 8, radius)
        finally:
            R.DEEP_SKY_LAYOUT["spiralGalaxy"] = layout
        delta = with_bulge - without
        results.append(Result(
            f"tonjolan inti menyinari pusat pada r={radius:.2f} (ukuran jam)",
            delta >= SPIRAL_CORE_MIN_DEGREES,
            f"cakupan cincin {with_bulge}° dengan tonjolan vs {without}° "
            f"tanpanya — sumbangan {delta}°, butuh >= {SPIRAL_CORE_MIN_DEGREES}°; "
            f"di bawah itu pusatnya hanya disinari kabut cakram dan pada ukuran "
            f"jam terbaca sebagai donat"))


def check_spiral_core_docstring_quotes_measured_values(results):
    """Angka di docstring check_spiral_core_reads_as_one_body harus keluar
    dari penyampelnya sendiri.

    Cacat yang ditutup: STATUS.md (entri 8 Okt 2026, baris ~1660) mencatatnya
    sebagai "Belum dikerjakan". Docstring gerbang inti spiral mengutip tabel
    selisih (+124/+106/+44 derajat) dan batas 0.2725 R yang tidak pernah
    diverifikasi ulang. Kelas yang sama dengan
    check_crater_contrast_numbers_come_from_the_sampler: komentar mengutip
    angka yang tidak keluar dari penyampel. Komentar adalah satu-satunya bukti
    yang dibaca orang yang menilai gerbangnya, jadi harus berbentuk hasil ukur.

    Diukur ulang lewat jalur menggambar yang sama (spiral_arm_degrees,
    spiral_core_samples), bukan dilarisasi dari teks.
    """
    fn = check_spiral_core_reads_as_one_body
    doc = fn.__doc__ or ""

    quoted = re.findall(
        r"([0-9.]+)\s+(\d+)°\s+(\d+)°\s+\+(\d+)°", doc)
    if len(quoted) < 3:
        results.append(Result(
            'inti spiral: docstring mengutip tabel selisih (3 baris)',
            False,
            f'{len(quoted)} baris selisih terbaca dari docstring '
            f'check_spiral_core_reads_as_one_body — butuh >= 3 '
            f'(r, dengan, tanpa, delta)'))

    diameter = watch_visual_diameter()
    if diameter is None:
        results.append(Result(
            'inti spiral: parity docstring butuh ukuran jam', False,
            'WatchMetrics.visualDiameter tidak ditemukan'))
        return
    pixels = diameter * 2

    index = spiral_core_bulge_index()
    layout = list(R.DEEP_SKY_LAYOUT['spiralGalaxy'])
    for r_str, with_s, without_s, delta_s in quoted:
        r = float(r_str)
        expected_delta = int(delta_s)
        with_bulge = spiral_arm_degrees(pixels, 8, r)
        R.DEEP_SKY_LAYOUT['spiralGalaxy'] = [
            b for i, b in enumerate(layout) if i != index]
        try:
            without = spiral_arm_degrees(pixels, 8, r)
        finally:
            R.DEEP_SKY_LAYOUT['spiralGalaxy'] = layout
        recomputed = with_bulge - without
        ok = abs(recomputed - expected_delta) <= 3
        results.append(Result(
            f'inti spiral: selisih docstring r={r:.4f} cocok ({expected_delta}° vs {recomputed}°)',
            ok,
            f'docstring +{expected_delta}°, dihitung ulang +{recomputed}° '
            f'(dengan {with_bulge}° vs tanpa {without}°) — toleransi 3°'))

    samples = spiral_core_samples()
    # `0.2725 R` di docstring adalah **reach** berkelanjutan (batas tempat
    # sumbangan inti turun ke ambang terbaca), dihitung dari blob inti dengan
    # rumus yang sama persis dengan `spiral_core_samples()` (half_width · (1 −
    # READABILITY_THRESHOLD / (opacity·255))). Ia bukan jari-jari sampel
    # diskrit terbesar, jadi dihitung ulang langsung dari blob, bukan dari
    # `max(samples)`.
    index = spiral_core_bulge_index()
    case = next(c for c in R.build_cases() if c.name == 'deepsky-spiralGalaxy')
    blobs = R.deep_sky_blobs('spiralGalaxy', case.kw.get('fuzziness', 0.6))
    blob = blobs[index]
    opacity = blob['opacity']
    continuous_reach = blob['half_width'] * (1 - READABILITY_THRESHOLD / (opacity * 255))
    boundary_ok = 0.27 <= continuous_reach <= 0.28
    results.append(Result(
        'inti spiral: batas sampel inti = 0.2725 R (dari model)',
        boundary_ok,
        f'reach berkelanjutan = {continuous_reach:.4f} R — docstring '
        f'mengutip 0.2725 R; di luar 0.27…0.28 berarti batasnya melenceng'))

    reach = max(samples) if samples else 0.0
    r_out = 0.2843
    not_core = r_out not in samples and r_out > reach
    results.append(Result(
        'inti spiral: r=0.2843 di luar sampel inti (batas bekerja)',
        not_core,
        f'r=0.2843 {"ada" if r_out in samples else "tidak ada"} di '
        f'samples (reach {reach:.4f} R) — harus di luar supaya batasnya '
        f'tidak longgar'))


def drift_compared_constants(source):
    """Konstanta port yang **nilainya dibandingkan** `check_port_matches_swift_constants`.

    Dibaca dari **AST** fungsi itu, bukan dari daftar nama yang ditulis tangan
    di sini: setiap `R.<NAMA>` di dalamnya adalah konstanta yang gerbang drift
    sudah menjanjikan sejalan dengan model Swift. Menyalin daftar itu ke sini
    akan melahirkan daftar kedua yang bisa tertinggal separuh — persis kelas
    cacat yang gerbang ini tutup.

    Nama yang bukan konstanta literal (fungsi seperti `saturn_ring()`, dan
    penanda aturan berupa string seperti `"sqrt"`) disaring di pemanggilnya.
    """
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if (isinstance(node, ast.FunctionDef)
                and node.name == "check_port_matches_swift_constants"):
            return sorted({
                sub.attr
                for sub in ast.walk(node)
                if isinstance(sub, ast.Attribute)
                and isinstance(sub.value, ast.Name)
                and sub.value.id == "R"
            })
    return None


def name_loads_by_scope(source):
    """`{nama: {"signature", "body", "module"}}` — **di mana** nama dibaca.

    **Kenapa `tokenize` saja tidak cukup, dan ini cacat yang sudah nyata.**
    Versi pertama gerbang ini (`name_tokens_by_line`) hanya menghitung
    **kemunculan** nama di mana pun. Itu bisa dipuaskan oleh rujukan mati:
    satu baris `_UNUSED = SATURN_CASSINI_WIDTH` di tingkat modul membuat nama
    itu "dipakai" sambil penggambarnya tetap menulis `cassini_width=0.06`.
    Terbukti di `out/probe-konstanta-mati.py`: gerbangnya **hijau** pada
    keadaan itu.

    Yang menentukan bukan "apakah namanya muncul", melainkan **apakah nilainya
    bisa sampai ke gambar**. Dua jalan yang sah, dan hanya dua:

      - dibaca sebagai **bawaan parameter** (`def f(x=NAMA)`) — jalan yang
        dipakai `candidate_marker` dan `saturn_ring_bands`;
      - dibaca di dalam **badan sebuah fungsi** — jalan yang dipakai
        `_draw_bands`, `drawCraters`, dan seterusnya.

    Rujukan di tingkat modul **tidak** dihitung, karena modul tidak
    menggambar apa pun: nilai yang hanya lewat di sana adalah nilai yang
    berhenti sebelum kertas. Itulah satu-satunya pembeda antara "dipakai"
    dan "dipakai menggambar", dan pembeda itu yang membuat gerbangnya
    menggigit.

    Diukur dari AST, bukan token, supaya cakupannya struktural: komentar,
    docstring, dan string tidak pernah bisa dihitung sebagai pemakaian — di
    berkas yang penuh prosa ini, itu bukan kemewahan.
    """
    tree = ast.parse(source)
    out = {}

    # Bawaan parameter: dibaca saat fungsi **didefinisikan**, jadi ia jalan
    # yang sah menuju gambar. Dihitung terpisah dari badan supaya pesan
    # kegagalan bisa mengatakan jalan mana yang hilang.
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        arguments = node.args
        defaults = list(arguments.defaults) + [
            d for d in arguments.kw_defaults if d is not None]
        for default in defaults:
            for sub in ast.walk(default):
                if isinstance(sub, ast.Name) and isinstance(sub.ctx, ast.Load):
                    entry = out.setdefault(
                        sub.id, {"signature": 0, "body": 0, "module": 0})
                    entry["signature"] += 1

    # Badan fungsi: pernyataan-pernyataan yang benar-benar menggambar.
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        for statement in node.body:
            for sub in ast.walk(statement):
                if isinstance(sub, ast.Name) and isinstance(sub.ctx, ast.Load):
                    entry = out.setdefault(
                        sub.id, {"signature": 0, "body": 0, "module": 0})
                    entry["body"] += 1

    # Tingkat modul, di luar definisi apa pun. Dihitung **hanya untuk
    # dilaporkan**, bukan untuk dianggap sampai ke gambar — rujukan di sini
    # persis bentuk yang membuat versi lama hijau di atas cacatnya.
    for statement in tree.body:
        if isinstance(statement, (ast.FunctionDef, ast.AsyncFunctionDef,
                                  ast.ClassDef)):
            continue
        for sub in ast.walk(statement):
            if isinstance(sub, ast.Name) and isinstance(sub.ctx, ast.Load):
                entry = out.setdefault(
                    sub.id, {"signature": 0, "body": 0, "module": 0})
                entry["module"] += 1

    return out


def check_port_constants_reach_the_drawing(results):
    """Konstanta yang gerbang drift jaga harus **dipakai menggambar**.

    **Cacat yang ditutup pemeriksaan ini.** `check_port_matches_swift_constants`
    membandingkan nilai konstanta port dengan sumber Swift, dan ia hijau. Tapi
    nilai yang dibandingkannya belum tentu nilai yang **menggambar**: konstanta
    bisa punya angka **kedua** yang ditulis langsung sebagai bawaan parameter
    fungsi gambar, dan yang dipakai penggambar adalah yang kedua.

    Empat konstanta hidup dalam keadaan itu:

        CANDIDATE_CORNER_FRACTION = 0.34   vs  def candidate_marker(corner_fraction=0.34)
        CANDIDATE_INSET           = 0.06   vs  def candidate_marker(inset=0.06)
        CANDIDATE_GLYPH_FRACTION  = 0.52   vs  def candidate_marker(glyph_fraction=0.52)
        SATURN_CASSINI_WIDTH      = 0.06   vs  def saturn_ring_bands(cassini_width=0.06)

    Karena itu mengubah konstanta itu tidak mengubah satu piksel pun. Yang lebih
    berbahaya: `check_saturn_gap_reads_at_the_watch_size` menuntut celah Cassini
    masih terbaca di ukuran jam, dan ia mengukur **PNG yang menggambar celah
    lebar** sementara jam menggambar celah yang konstanta itu janjikan. Dua
    bahasa yang berbeda dipisahkan — dan pemisahnya di dalam **satu berkas**,
    tempat yang paling tidak akan dicurigai siapa pun.

    **Cakupannya dari gerbang drift, bukan dari daftar di sini.** Konstanta
    yang diperiksa adalah yang nilainya sudah dibandingkan
    `check_port_matches_swift_constants` (lewat `drift_compared_constants`),
    jadi konstanta baru yang ditambahkan ke sana langsung ikut diperiksa, dan
    tidak ada daftar kedua yang bisa tertinggal separuh. Versi pertama gerbang
    ini membaca anotasi `# MODEL:` di komentar, dan itu **salah**: menghapus
    anotasi mematikannya tanpa suara, karena katalog yang hidup di prosa adalah
    katalog yang bisa menyusut sendiri. Bukti mutasinya ada di
    `out/mutasi-konstanta-mati.py` — baris "anotasi MODEL dihapus" hijau pada
    versi itu dan merah pada versi ini.

    **Dua lapis, karena yang pertama saja bisa dipuaskan rujukan mati.**
    Versi kedua gerbang ini menghitung kemunculan nama di mana pun, dan itu
    **hijau** atas keadaan "bawaan kembali jadi literal + satu rujukan mati di
    tingkat modul" (`out/probe-konstanta-mati.py`). Sekarang yang diuji
    **jalannya**: nama harus dibaca di badan fungsi atau sebagai bawaan
    parameter. Lapis kedua menjaga bentuk cacat yang tidak lewat nama sama
    sekali: sebuah parameter menggambar yang bawaannya literal **dengan nilai
    yang sama** seperti konstanta yang dijaga. Pada keadaan itu namanya tidak
    hilang — angkanya yang berhenti dipakai, dan hanya nilai yang bisa
    melihatnya.

    Yang disaring: konstanta yang nilainya string. `BAND_HALF_WIDTH_RULE` dan
    `POLAR_CAP_WIDTH_RULE` bernilai `"sqrt"` — penanda **rumus**, bukan angka
    gambar; yang memeriksanya adalah gerbang "rumus dipakai di kedua bahasa".
    Memeriksa mereka di sini akan memerah pada kode yang benar, dan gerbang yang
    memerah pada kode benar akan dimatikan orang.
    """
    source = open(R.SOURCE, encoding="utf-8").read()
    try:
        tree = ast.parse(source)
    except SyntaxError as error:
        results.append(Result(
            "konstanta port terbaca sebagai AST", False,
            f"render-visuals.py tidak bisa di-parse: {error}"))
        return
    loads = name_loads_by_scope(source)

    compared = drift_compared_constants(open(__file__, encoding="utf-8").read())
    if not compared:
        results.append(Result(
            "konstanta yang dibandingkan gerbang drift terbaca", False,
            "`check_port_matches_swift_constants` tidak ditemukan di check-visuals.py"))
        return

    # Nilai tiap konstanta dibaca dari **teksnya sendiri**, bukan dari modul
    # yang sudah dimuat: konstanta yang didefinisikan setelah fungsi yang
    # memakainya sebagai bawaan belum ada di modul saat berkas ini dimuat, dan
    # pemeriksaan yang gagal karena bacaan akan terlihat seperti pemeriksaannya
    # yang salah — persis kelas "gerbang merah pada kode benar" yang harus
    # dihindari supaya gerbang ini tidak dimatikan orang.
    definition_lines = {}
    constant_values = {}
    for index, line in enumerate(source.splitlines()):
        match = re.match(r"^([A-Z][A-Z0-9_]*)\s*=\s*(.*)$", line)
        if match is None:
            continue
        definition_lines[match.group(1)] = index + 1
        try:
            constant_values[match.group(1)] = ast.literal_eval(
                match.group(2).split("#")[0].strip())
        except (ValueError, SyntaxError):
            # Bukan literal (mis. hasil pemanggilan). Bukan konstanta angka.
            constant_values[match.group(1)] = None

    checked = []
    for name in compared:
        line_number = definition_lines.get(name)
        if line_number is None:
            # `R.saturn_ring()` dan sejenisnya: fungsi, bukan konstanta.
            continue
        if isinstance(constant_values.get(name), str):
            # Penanda rumus (`"sqrt"`), bukan angka gambar.
            continue
        if constant_values.get(name) is None:
            continue
        checked.append((name, line_number))

    if not checked:
        results.append(Result(
            "konstanta yang dibandingkan gerbang drift terbaca", False,
            "tidak satu pun konstanta bernilai angka ditemukan di render-visuals.py"))
        return

    # Lapis 1: nilainya harus benar-benar bisa sampai ke gambar — dibaca di
    # badan sebuah fungsi atau sebagai bawaan parameter. Rujukan di tingkat
    # modul tidak dihitung; itu satu-satunya pembeda antara "dipakai" dan
    # "dipakai menggambar", dan pembeda itulah yang membuat gerbang ini
    # menggigit.
    dead = []
    for name, line_number in checked:
        scopes = loads.get(name, {"signature": 0, "body": 0, "module": 0})
        if scopes["signature"] + scopes["body"] > 0:
            continue
        # Bawaan penggambarnya ikut dilaporkan: tanpa itu, pembaca tahu
        # konstanta ini mati tapi tidak tahu **angka mana** yang benar-benar
        # menggambar, sehingga perbaikannya menebak.
        drawn = re.search(
            r"^\s*def \w+\([^)]*\b" + name.lower() + r"\w*\s*=\s*([^,)]+)",
            source, re.MULTILINE | re.DOTALL)
        hint = (f"; penggambarnya memakai bawaan {drawn.group(1).strip()}"
                if drawn else "")
        where = ("hanya dirujuk di tingkat modul"
                 if scopes["module"] else "tidak pernah dipakai")
        dead.append(Result(
            f"konstanta `{name}` sampai ke penggambar", False,
            f"nilainya dijaga gerbang drift, tapi {where} — tidak dibaca di "
            f"badan fungsi mana pun dan bukan bawaan parameter "
            f"(baris {line_number}){hint}"))

    # Lapis 2: bentuk cacat yang **tidak lewat nama sama sekali**. Sebuah
    # parameter penggambar bisa menulis bawaannya sebagai literal yang
    # **nilainya sama** dengan konstanta yang dijaga. Namanya tidak hilang,
    # jadi lapis 1 hijau — yang berhenti dipakai adalah angkanya, dan hanya
    # nilai yang bisa melihatnya. Inilah sebabnya dua lapis ini komplementer,
    # bukan berlebihan: lapis 2 hanya memeriksa konstanta yang lapis 1 sudah
    # nyatakan sampai ke gambar.
    #
    # **Kenapa pasangannya lewat nama parameter, bukan lewat nilai saja.**
    # Versi pertama lapis ini membandingkan nilai saja, dan ia **merah pada
    # kode yang benar**: `saturn_ring_bands(cassini_width=0.06)` cocok dengan
    # `CANDIDATE_INSET` yang kebetulan juga 0.06. Dua konstanta berbeda boleh
    # bernilai sama; yang membuat sebuah bawaan literal itu cacat adalah kalau
    # ada konstanta **untuk parameter itu** yang seharusnya dibaca. Jadi
    # pasangannya dicari dari namanya — `cassini_width` ↔
    # `SATURN_CASSINI_WIDTH`, `corner_fraction` ↔
    # `CANDIDATE_CORNER_FRACTION` — dan itu cukup: nama parameter di berkas ini
    # adalah akhiran nama konstantanya. Gerbang yang merah pada kode benar akan
    # dimatikan orang, jadi kesempitan ini syarat hidupnya, bukan kemewahan.
    alive = {name for name, _ in checked} - {r.name.split("`")[1]
                                             for r in dead}
    literal_shadows = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        arguments = node.args
        named = list(zip(
            arguments.args[len(arguments.args) - len(arguments.defaults):],
            arguments.defaults))
        named += list(zip(arguments.kwonlyargs, arguments.kw_defaults))
        for argument, default in named:
            if not isinstance(default, ast.Constant):
                continue
            if not isinstance(default.value, (int, float)) or isinstance(
                    default.value, bool):
                continue
            for name in alive:
                value = constant_values.get(name)
                if not isinstance(value, (int, float)) or isinstance(value, bool):
                    continue
                lowered = name.lower()
                if not (lowered == argument.arg
                        or lowered.endswith("_" + argument.arg)):
                    continue
                if abs(default.value - value) > 1e-12:
                    continue
                literal_shadows.append(
                    f"`{node.name}({argument.arg}={default.value})` menulis "
                    f"angka yang sama dengan konstanta `{name}`")

    for shadow in literal_shadows:
        results.append(Result(
            "bawaan penggambar memakai konstanta, bukan salinan angkanya",
            False, f"{shadow} — dua angka yang sama akan berbeda begitu salah "
                   f"satu disunting, dan yang menggambar adalah salinannya"))

    results.extend(dead)
    if not dead and not literal_shadows:
        results.append(Result(
            "setiap konstanta yang dijaga gerbang drift sampai ke penggambar",
            True, f"{len(checked)} konstanta dibaca di badan fungsi atau "
                  f"sebagai bawaan parameter"))


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


def check_bands_follow_the_limb_arc(results, size=200, ss=2):
    """Pita harus berbentuk **tali busur** bola, bukan elips berlebar tetap.

    **Cacat yang ditutup pemeriksaan ini.** Pita digambar sebagai elips: tepi
    kirinya adalah dinding vertikal di `x = −sqrt(1 − yc²)`. Yang benar di bola
    tidak begitu — lingkaran lintang pada lintang φ memproyeksi ke ruas garis
    `y = sin φ`, `|x| ≤ sqrt(1 − y²)`, jadi tepi pita pada tiap ketinggian
    mengikuti **busur limb**. Akibatnya dua sudut di dekat limb tetap polos
    sementara pitanya sudah berhenti: diukur sebagai IoU pada render 200 px,
    tiap elips hanya menutupi **79%** pita yang benar, dan yang hilang
    20,5–22,1%. Bentuk itulah yang membuat piringan terbaca sebagai stiker
    rata, dan pada pita bawah ia juga menggantung di luar tepi bola.

    **Kenapa dari piksel.** Uji model mengunci rumusnya
    (`testBandHalfWidthFollowsTheLimbArc`), tapi yang dikirim ke layar adalah
    gambar: view bisa berhenti memakainya dan menggambar elips lagi, dan
    rumusnya tetap benar. Yang membuktikan bentuknya adalah mengukur
    piringannya sendiri terhadap bentuk yang benar.

    **Kenapa dibandingkan dengan bentuk yang dihitung di sini.** Bentuk yang
    benar adalah **proyeksi bola** — bukan pilihan, jadi tidak boleh diambil
    dari fungsi yang sedang menggambar pita. Kalau diambil dari sana, elips
    yang kembali muncul akan menyeret pembandingnya ikut mengecil dan
    pemeriksaan ini akan selalu hijau. Itu persis cacat yang pernah nyata di
    `check_jupiter_bands_reach_the_limb` (pembanding dibaca dari fungsi yang
    diukur), dan alasan yang sama berlaku di sini.

    Ambangnya **0.95**: bentuk yang benar secara analitik bertemu dirinya
    sendiri (1.0), selisih yang tersisa hanya anti-aliasing; elips memberi
    0.79. Kedua sisinya jauh dari ambangnya.

    **Kenapa hanya x ≤ −0,40.** Dua benda lain juga berbeda antara gambar
    "terkunci" dan "ragu", dan keduanya **bukan pita**: Bintik Merah Besar
    (`centerX = −0,10`, lebar 0,52 → tepi kiri x = −0,36) dan lencana
    tanda-tanya di sudut kanan atas. Versi pertama pemeriksaan ini mengukur
    seluruh piringan, dan hasilnya **lebih buruk setelah perbaikannya**
    (pita 4 turun ke 0,65) — bukan karena bentuknya salah, melainkan karena
    yang terukur sebagian adalah bintiknya. Mengukur tepi kiri jauh
    memisahkan pitanya dari keduanya, dan itu memang wilayah tempat cacat
    "dinding vertikal vs busur" berada.
    """
    _, (w, h, rows_c) = render_case("planet-jupiter-confirmed", size=size, ss=ss)
    _, (_, _, rows_s) = render_case("planet-jupiter-uncertain", size=size, ss=ss)
    cx = w / 2.0
    cy = h / 2.0
    radius = min(w, h) / 2.0
    x_limit = -0.40

    def elliptical_half_width(band_centre):
        """Setengah-lebar **elips**: lebar bola di pusat pita, dipakai di tepinya.

        Ini bukan `CelestialVisual.bandHalfWidthAt`. Ia sengaja **salah** — ia
        bentuk yang dipakai sebelum perbaikan (lebar konstan sepanjang tinggi
        pita), dan ia ditulis ulang di sini justru supaya tidak bisa menyeret
        pembandingnya ikut benar. Kalau diambil dari fungsi yang sedang
        menggambar, elips yang kembali muncul akan selalu "cocok" dengan
        dirinya sendiri.
        """
        return math.sqrt(max(0.0, 1 - band_centre * band_centre))

    def differs(px, py):
        a = rows_c[py][px * 4:px * 4 + 3]
        b = rows_s[py][px * 4:px * 4 + 3]
        return sum(abs(a[k] - b[k]) for k in range(3)) > 8

    def band_edge(y_norm):
        """x tepi kiri pita pada baris `y_norm`, atau `None` kalau tak ada."""
        py = min(h - 1, max(0, int(round(cy + y_norm * radius))))
        for px in range(w):
            x = (px + 0.5 - cx) / radius
            if x > x_limit:
                break
            if differs(px, py):
                return x
        return None

    # **Kenapa diukur terhadap bentuk yang dihitung di sini, bukan terhadap
    # rumus yang menggambar.** Bentuk yang benar adalah **proyeksi bola** —
    # bukan pilihan, jadi tidak boleh diambil dari fungsi yang sedang
    # menggambar pita. Kalau diambil dari sana, elips yang kembali muncul akan
    # menyeret pembandingnya ikut mengecil dan pemeriksaan ini akan selalu
    # hijau.
    #
    # **Kenapa dibandingkan pada ketinggian yang sama, bukan lebar pita.**
    # Sampelnya digeser **dua piksel** ke dalam tepi. Alasannya pembulatan:
    # tepi pita jatuh tepat di batas baris (mis. y = +0,055 → py = 105,5 pada
    # render 200 px), jadi `round` menaruh baris sampelnya **di luar** pita —
    # pita 3 dan 4 tidak ditemukan sama sekali walaupun bentuknya benar.
    # Karena pembandingnya dihitung pada **ketinggian sampel yang sama**, yang
    # diuji tetap bentuk tepinya, bukan lebarnya.
    inset = 2.0 / radius
    for index, (band_y, _, half_height) in enumerate(R.jupiter_bands()):
        top = band_y - half_height + inset
        bottom = band_y + half_height - inset
        measured_top = band_edge(top)
        measured_bottom = band_edge(bottom)
        # Bentuk yang benar: tepi kiri busur bola di ketinggian sampel.
        want_top = -math.sqrt(max(0.0, 1 - top * top))
        want_bottom = -math.sqrt(max(0.0, 1 - bottom * bottom))
        # Pita harus punya **dua** tepi, dan keduanya di dalam wilayah ukur.
        # `None` berarti pita tidak tergambar di situ — itu kegagalan, bukan
        # angka yang boleh dilewati.
        if measured_top is None or measured_bottom is None:
            results.append(Result(
                f"pita Jupiter {index} mengikuti busur limb (tali busur, bukan elips)",
                False,
                f"tepi pita tidak ditemukan di x ≤ {x_limit} "
                f"(atas {measured_top}, bawah {measured_bottom})"))
            continue
        error = max(abs(measured_top - want_top), abs(measured_bottom - want_bottom))
        # **Angka pembanding dihitung, bukan dikutip.** Versi pertama pesannya
        # berbunyi "elips 20% R" — angka yang tidak pernah muncul dari metrik
        # ini. Galat yang **benar-benar** diukur di sini adalah jarak **tepi**
        # pada ketinggian sampel (di dalam pita), dan di situ busur dan elips
        # masih berdekatan: dihitung dari geometri produksi, elips memberi
        # 0,1% R pada pita ekuator sampai 6,3% R pada pita terluar. Angka 20%
        # itu milik **luas** (IoU 79%, selisih 20,6–21,3% union), bukan jarak
        # tepi. Karena itu ia dihitung di sini dari geometri yang sama — pesan
        # tidak boleh mengklaim beda yang tidak diukur pemeriksaannya sendiri.
        #
        # Dan batas itu dinyatakan, bukan disembunyikan: dengan ambang 3% R,
        # pemeriksaan ini membedakan tali busur dari elips pada pita **0, 1, 5,
        # 6** (2,6–6,3% R) dan **tidak** pada pita 2–4 (0,1–1,1% R), karena di
        # dekat ekuator busurnya memang nyaris lurus. Yang menjaga pita tengah
        # adalah gerbang pemakaian di bawah, bukan ambang ini.
        elliptical_error = max(abs(elliptical_half_width(band_y) - abs(want_top)),
                               abs(elliptical_half_width(band_y) - abs(want_bottom)))
        results.append(Result(
            f"pita Jupiter {index} mengikuti busur limb (tali busur, bukan elips)",
            error <= 0.03,
            f"tepi atas {measured_top:+.3f} (busur {want_top:+.3f}), "
            f"bawah {measured_bottom:+.3f} (busur {want_bottom:+.3f}), "
            f"galat {error * 100:.1f}% R (ambang 3% R; elips "
            f"{elliptical_error * 100:.1f}% R di ketinggian sampel)"))

    # **Pemakaian di view dan di port.** Pemeriksaan piksel di atas mengukur
    # **port**; ia tidak bisa melihat view berhenti memakai busurnya dan
    # kembali menggambar elips (gambar di jam rata, PNG tetap tali busur),
    # atau memakainya dengan angka yang ditulis ulang alih-alih dibaca dari
    # model. Keduanya persis kelas "satu rumus, dua bahasa, tidak ada yang
    # membandingkan" yang sudah berkali-kali tercatat di repo ini.
    #
    # **Kenapa dua nama, bukan satu.** View menulis
    # `CelestialVisual.bandHalfWidthAt(height:)` (nama berkualifikasi), port
    # menulis `band_half_width(` (nama lokalnya). Menuntut satu ejaan yang sama
    # berarti salah satu sisi merah pada kode yang benar — dan gerbang yang
    # merah pada kode benar akan dimatikan orang.
    view = open(os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()
    port = open(R.SOURCE, encoding="utf-8").read()
    results.append(Result(
        "tepi pita dibaca dari model di view (bukan elips ditulis ulang)",
        "CelestialVisual.bandHalfWidthAt(height:" in view,
        "view memanggil 'CelestialVisual.bandHalfWidthAt(height:' = "
        f"{'ada' if 'CelestialVisual.bandHalfWidthAt(height:' in view else 'TIDAK'}"))
    # **Kenapa pemanggilannya yang diperiksa, bukan keberadaan fungsinya.**
    # Versi pertama menuntut `def band_half_width(` dan `band_half_width(`
    # ada. Keduanya **benar** pada port yang kembali menggambar elips: nama
    # fungsinya tetap ada di berkas, hanya tidak lagi dipanggil dari
    # `_draw_bands`. Gerbang yang memeriksa keberadaan akan hijau di atas
    # port yang menggambar bentuk lama — persis kelas "gerbang yang mengklaim
    # lebih dari yang diukurnya" yang sudah berulang di repo ini. Yang
    # dipanggil adalah baris `_draw_bands` sendiri, jadi itu yang dibaca.
    port_bands = re.search(r"def _draw_bands\(.*?\n(?=\ndef |\n# )", port, re.S)
    calls_model = (port_bands is not None
                   and "band_half_width(" in port_bands.group(0))
    results.append(Result(
        "port memanggil band_half_width di _draw_bands (bukan elips)",
        calls_model and "def band_half_width(" in port,
        f"_draw_bands memanggil 'band_half_width(' = "
        f"{'ada' if calls_model else 'TIDAK'}, "
        f"fungsi 'def band_half_width(' = "
        f"{'ada' if 'def band_half_width(' in port else 'TIDAK'}"))

    # **Kenapa urutan tepinya juga diikat.** Tanda `height` hanya berpengaruh
    # lewat **urutan** tepi atas vs tepi bawah. Versi pertama `bandHalfWidthAt`
    # menerima jarak dari pusat pita dan memulihkan ketinggiannya dengan
    # `sqrt(1 − hw²)`; akar itu kehilangan tanda, jadi untuk pita utara tepi
    # **atas** dihitung dengan lebar tepi **bawah**-nya (0,597 alih-alih 0,410)
    # dan piringannya terlihat miring. View yang menulis `abs(band.centerY)`
    # untuk tepi atas menghasilkan bentuk yang **sama** salahnya — dan itu
    # tidak terlihat oleh pemeriksaan piksel mana pun, karena piksel itu milik
    # port. Terbukti: `abs(...)` dipasang di view, dan ke-9 pemeriksaan di
    # fungsi ini **semuanya tetap hijau**. Yang mengikatnya adalah bentuk
    # rumusnya sendiri, dibaca dari sumber.
    top_arg = "height: band.centerY - band.halfHeight"
    bottom_arg = "height: band.centerY + band.halfHeight"
    results.append(Result(
        "tepi atas memakai ketinggian bertanda (bukan nilai absolutnya)",
        top_arg in view and bottom_arg in view,
        f"view memakai '{top_arg}' = {'ada' if top_arg in view else 'TIDAK'}, "
        f"'{bottom_arg}' = {'ada' if bottom_arg in view else 'TIDAK'}"))

    # Dan fungsi modelnya sendiri harus **menjepit**, bukan hanya mengakar:
    # `sqrt` dari bilangan negatif adalah NaN, dan NaN di `Canvas` menghapus
    # piringannya alih-alih memberi galat. Pita yang ditambah melewati kutub
    # adalah cara paling mudah mencapai itu, dan tidak ada teks di layar yang
    # bisa membedakannya dari \"planetnya tidak digambar\".
    model_src = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                                          "CelestialVisual.swift")).read()
    results.append(Result(
        "bandHalfWidthAt menjepit ketinggian sebelum mengakar (anti-NaN)",
        "min(1, max(0, 1 - height * height)).squareRoot()" in model_src,
        "model memuat penjepit 'min(1, max(0, 1 - height * height)).squareRoot()' = "
        f"{'ada' if 'min(1, max(0, 1 - height * height)).squareRoot()' in model_src else 'TIDAK'}"))

    # ── Kabut Venus ────────────────────────────────────────────────────
    #
    # **Cacat yang ditutup pemeriksaan ini — nyata, dan satu-satunya ciri
    # planet yang tidak dijaga apa pun.** Port Python menggambar elips kabut
    # di `cy + radius * 0.14`, sementara view Swift menaruh sudut atas
    # `CGRect`-nya di `center.y - radius * 0.72` — yaitu **pusat** `center.y`
    # dengan separuh tinggi 0.72 R. Selisihnya **0.14 R ke bawah**: seluruh
    # gambar Venus berfase yang diukur gerbang piksel adalah gambar yang
    # **tidak pernah tampil di jam**. `grep haze Tools/check-visuals.py`
    # sebelum ini tidak menemukan apa pun, jadi kabut Venus satu-satunya
    # ciri planet yang bisa bergeser tanpa suara — dan memang bergeser.
    #
    # Bentuknya penulisan satuan, bukan rasa: `CGRect` memuat **sudut**,
    # `Canvas.ellipse` memuat **pusat**. Kesalahan yang sama pernah terjadi
    # pada Bintik Merah Besar, dan itu sebabnya `Spot` sudah menyebut
    # satuannya sebagai pusat.
    #
    # Ketiga angkanya dibaca dari sumber kedua bahasa **dan** dari model,
    # karena satu angka yang hidup di tiga tempat adalah tiga angka yang
    # akan berbeda. Yang dijaga di sini adalah **keberadaan pemanggilan
    # modelnya**, bukan sekadar angkanya: view yang menulis ulang 0.55/0.72
    # sebagai literal akan lolos pemeriksaan angka dan tetap bisa bergeser
    # sendiri dari port.
    haze_call = "CelestialVisual.venusHaze()"
    results.append(Result(
        "kabut Venus dibaca dari model di view (bukan sudut CGRect ditulis ulang)",
        haze_call in view,
        f"view memanggil '{haze_call}' = {'ada' if haze_call in view else 'TIDAK'}"))
    haze_model = "public static func venusHaze(" in model_src
    haze_port_fn = "def venus_haze(" in port
    # **Kenapa `_draw_haze` dan cabang berfase diperiksa terpisah.** Keduanya
    # situs yang berbeda, dan keduanya pernah memuat angka yang salah. Satu
    # pemeriksaan "port memanggil venus_haze" saja akan hijau walaupun hanya
    # satu yang diperbaiki.
    port_haze_fn = re.search(r"def _draw_haze\(.*?\n(?=\ndef |\n# )", port, re.S)
    calls_in_fn = (port_haze_fn is not None
                   and "venus_haze()" in port_haze_fn.group(0))
    port_phase = re.search(r"def _draw_planet\(.*?\n(?=\ndef |\n# )", port, re.S)
    calls_in_phase = (port_phase is not None
                      and "venus_haze()" in port_phase.group(0))
    results.append(Result(
        "port memanggil venus_haze di kedua situs (bola & berfase)",
        haze_model and haze_port_fn and calls_in_fn and calls_in_phase,
        f"model 'def venusHaze(' = {'ada' if haze_model else 'TIDAK'}, "
        f"port 'def venus_haze(' = {'ada' if haze_port_fn else 'TIDAK'}, "
        f"dipanggil di _draw_haze = {'ada' if calls_in_fn else 'TIDAK'}, "
        f"di _draw_planet = {'ada' if calls_in_phase else 'TIDAK'}"))
    # ── Kabut Venus: angkanya sendiri ──────────────────────────────────
    #
    # **Celah yang ditutup di sini — dan kenapa yang lama belum cukup.**
    # Pemeriksaan di atas menjaga **keberadaan pemanggilan** `venus_haze()`
    # di kedua situs port. Itu perlu, tapi tidak menyentuh satu angka pun:
    # selama `venus_haze()` dipanggil, ia boleh mengembalikan apa saja.
    # Dibuktikan sebelum gerbang ini ditulis — ketiga mutasi ini masing-masing
    # membiarkan **348 dari 348** pemeriksaan hijau:
    #
    #     VENUS_HAZE_HALF_WIDTH  0.55 -> 0.70
    #     VENUS_HAZE_HALF_HEIGHT 0.72 -> 0.45
    #     VENUS_HAZE_CENTER_Y    0.0  -> 0.30
    #
    # Mutasi bawaannya di Swift (`halfWidth 0.55 -> 0.70`, `halfHeight
    # 0.72 -> 0.50`) juga membiarkan 348 pemeriksaan hijau — tapi menyalakan
    # **tiga uji Swift**. Jadi sisi model punya penjaga (uji itu), sisi port
    # tidak punya sama sekali; gambar yang diukur gerbang piksel Venus berfase
    # bisa bergeser tanpa satu pun pemeriksaan merah.
    #
    # Yang dijaga: **port == model**, ketiga angka, dua arah. Arah ketiga
    # (view memakai model, bukan menulis ulang literalnya) sudah dijaga
    # `haze_call` di atas.
    haze_port_values = R.venus_haze()
    haze_model_values = read_venus_haze_from_swift(model_src)
    if haze_model_values is None:
        results.append(Result(
            "kabut Venus: bawaan model terbaca", False,
            "tiga bawaan 'centerY/halfWidth/halfHeight: Double = ' di "
            "CelestialVisual.venusHaze tidak terbaca — pembaca angkanya perlu "
            "diselaraskan dengan bentuk fungsinya"))
    else:
        for label, port_value, model_value in zip(
                ("pusat", "separuh lebar", "separuh tinggi"),
                haze_port_values, haze_model_values):
            results.append(Result(
                f"kabut Venus: {label} (port == model)",
                abs(port_value - model_value) < 1e-9,
                f"port={port_value}, model={model_value}"))
    # Angka lama harus **hilang dari kode**, bukan hanya ditambah yang baru:
    # kalau satu situs masih memakai `cy + radius * 0.14`, ia menggambar Venus
    # yang berbeda dari situs yang lain.
    #
    # **Kenapa komentar dibuang dulu.** Versi pertama pemeriksaan ini mencari
    # `radius * 0.14` di seluruh berkas, dan ia **merah pada kode yang sudah
    # benar** — karena angka itu masih disebut di komentar yang menerangkan
    # justru kenapa ia dibuang. Gerbang yang merah pada kode benar akan
    # dimatikan orang, jadi yang dicari adalah kodenya: komentar dan docstring
    # dibuang lebih dulu.
    code_only = re.sub(r"#[^\n]*", "", port)
    code_only = re.sub(r'""".*?"""', "", code_only, flags=re.S)
    stale = "radius * 0.14" in code_only
    results.append(Result(
        "geseran lama 0.14 R sudah tidak ada di kode port",
        not stale,
        f"kode port masih memuat 'radius * 0.14' = {'YA' if stale else 'tidak'} "
        f"(komentar tidak dihitung)"))


def check_jupiter_spot_keeps_its_curvature(results, size=200, ss=2):
    """Bintik Merah Besar harus **ikut melengkung**, bukan stiker rata.

    **Cacat yang ditutup pemeriksaan ini, dan kenapa gerbang lama tidak
    melihatnya.** Kelasnya sama persis dengan pita Jupiter: ciri digambar
    sebagai elips warna **rata** di atas bola yang sudah dinaungi gradien, jadi
    ia menghapus lengkung bola di dalamnya. Untuk pita, cacat itu sudah dijaga
    `check_banded_disc_keeps_its_curvature` — tapi gerbang itu mengukur
    **baris ekuator** (`y = cy`), sementara bintiknya duduk di
    `centerY = +0.31`. Diukur pada baris pusat bintik (200 px, ss=4):

        bola di bawah bintik (tanpa ciri) : 0.580 → 0.532   lengkung **+8.4%**
        baris yang sama, dengan bintik    : 0.449 → 0.532   lengkung **−18.4%**

    Tandanya **terbalik**: barisnya lebih terang di sisi yang seharusnya
    gelap. Yang terbaca karena itu bukan bola berbintik melainkan **stiker**
    yang ditempel — dan tidak ada satu pun gerbang di berkas ini yang
    mengukurnya, karena semuanya mengukur **keberadaan** ciri
    (`check_planet_features_present` menghitung piksel merah), bukan
    **lengkungnya**.

    **Kenapa sampelnya `frac = 0.85`, bukan tepi elipsnya.** Pada `frac = 1.00`
    sampel terakhir jatuh **tepat di tepi** elips, tempat anti-aliasing
    mencampurnya dengan warna rata di luarnya — diukur, rasionya hanya 1.5%
    walaupun perbaikannya bekerja penuh (66% di dalam). Yang diukur karena itu
    **bagian dalam** bintik, yang memang miliknya.

    **Kenapa bola pembandingnya kasus "ragu".** Kasus itu menggambar bola
    Jupiter yang sama **tanpa** ciri pengenal (aturan PRD: ciri hilang saat
    engine ragu), jadi selisihnya adalah bintiknya sendiri — dan lengkung bola
    yang benar bisa diukur tanpa menuliskan angka lengkung ke dalam gerbang
    ini. Itu sebabnya ambangnya **rasio**, bukan nilai absolut.

    Ambangnya **55% dari lengkung bola**: perbaikan ini memberi 66%, cacat
    aslinya 0% (rata sempurna) sampai −18% (tanda terbalik). Yang dijaga adalah
    bahwa pemulihannya **ada dan sebagian besar**, bukan nilai persisnya.
    """
    _, (w, h, rows_c) = render_case("planet-jupiter-confirmed", size=size, ss=ss)
    _, (_, _, rows_b) = render_case("planet-jupiter-uncertain", size=size, ss=ss)
    cx, cy = w / 2.0, h / 2.0
    radius = min(w, h) / 2.0
    spot_x, spot_y = R.SPOT_CENTER
    spot_w, spot_h = R.SPOT_SIZE
    y = int(round(cy + spot_y * radius))

    def lum(rows, x):
        px = rows[y][x * 4:x * 4 + 3]
        return 0.2126 * px[0] + 0.7152 * px[1] + 0.0722 * px[2]

    def curvature(rows):
        # `frac = 0.85`: di dalam elips bintik, jauh dari tepinya.
        xa = spot_x - 0.85 * spot_w / 2
        xb = spot_x + 0.85 * spot_w / 2
        samples = [lum(rows, int(round(cx + (xa + (xb - xa) * i / 20) * radius)))
                   for i in range(21)]
        return 100.0 * (samples[0] - samples[-1]) / max(samples[0], 1e-9)

    bare = curvature(rows_b)
    spot = curvature(rows_c)
    ratio = spot / max(bare, 1e-9)
    results.append(Result(
        "Bintik Merah Besar tetap melengkung (bukan stiker rata)",
        ratio >= 0.55,
        f"lengkung bintik {spot:.1f}% vs bola di bawahnya {bare:.1f}% "
        f"(rasio {ratio * 100:.0f}%, ambang 55%)"))

    # Arah kedua: bintiknya **tidak boleh hilang**. Tanpa ini, pemulihan penuh
    # (kekuatan 1.0) akan lulus pemeriksaan di atas dengan sempurna sambil
    # menghapus ciri pengenal Jupiter itu sendiri — bola polos juga melengkung
    # sempurna.
    #
    # **Metriknya diukur, bukan dipilih.** Versi pertama memakai hitungan
    # piksel merah di kotak bintiknya (`count_reddish`), dan ia **tidak pernah
    # menggigit**: pada kekuatan 1.0 masih ada 64 piksel merah — di atas ambang
    # 20 mana pun yang masih waras — jadi pemulihan penuh lolos sambil
    # menghapus bintiknya. Penyebabnya bintiknya cukup besar, dan warnanya
    # masih menyisakan selisih merah-biru yang terukur di piksel tepinya.
    #
    # Yang benar adalah **menyelisihkan terhadap bola tanpa ciri** pada daerah
    # bintiknya sendiri: gradien bola saling menghapus, dan yang tersisa adalah
    # bintiknya. Monoton terhadap kekuatannya — 17.8 / 12.5 / 7.2 / 3.6 / 0.1%
    # pada kekuatan 0.0 / 0.3 / 0.6 / 0.8 / 1.0 — dan **nol** pada 1.0, karena
    # gradien yang sama memang meniadakan bintiknya. Persis metrik yang dipakai
    # `band_deviation_from_bare` untuk pita, dengan alasan yang sama.
    deviation = spot_deviation_from_bare(rows_c, rows_b, w, h)
    results.append(Result(
        "bintik Jupiter masih terbaca setelah pemulihan lengkung",
        deviation >= 2.0,
        f"bintik menyimpang {deviation:.2f}% dari bola polos (ambang 2.0%; "
        f"kekuatan 1.0 memberi 0.14%)"))


def spot_deviation_from_bare(rows_spot, rows_bare, w, h):
    """Seberapa jauh bintik menyimpang dari **bola polos**, dalam persen terang.

    **Kenapa bukan hitungan piksel merah.** Versi pertama memakai
    `count_reddish` di kotak bintiknya, dan itu **tidak pernah menggigit**:
    pada pemulihan penuh (kekuatan 1.0) masih ada 64 piksel merah, sementara
    ambangnya 20 — jadi bintik yang sudah tertutup bola sepenuhnya tetap lolos.

    **Kenapa hanya daerah bintiknya, dan kenapa dipotong ke piringan.** Di
    luar bintik tidak ada yang berubah antara kedua gambar, jadi menyertakannya
    hanya mengencerkan angka dengan nol. Pemotongan ke piringan perlu karena
    elips bintiknya menjulur keluar bola: `centerX = -0.10`, `width = 0.52`
    berarti tepi kirinya di −0.36 R, sedangkan pada `centerY = +0.31` bola
    hanya selebar 0.95 R — jadi sebagian elipsnya ada di latar, dan latar
    memang sama di kedua gambar (nol), bukan bagian dari klaimnya.

    Rata-rata `|Lum(spot) − Lum(bare)|` dibagi terang pusat piringan, supaya
    angkanya tidak bergantung pada skala warna paletnya.
    """
    cx, cy = w / 2.0, h / 2.0
    radius = min(w, h) / 2.0
    spot_x, spot_y = R.SPOT_CENTER
    spot_w, spot_h = R.SPOT_SIZE
    half_w, half_h = spot_w * radius / 2.0, spot_h * radius / 2.0

    deviations = []
    for y in range(h):
        for x in range(w):
            px, py = x + 0.5, y + 0.5
            if (px - cx) ** 2 + (py - cy) ** 2 > radius * radius:
                continue
            ex, ey = (px - cx - spot_x * radius) / half_w, \
                     (py - cy - spot_y * radius) / half_h
            if ex * ex + ey * ey > 1.0:
                continue
            pa = rows_spot[y][x * 4:x * 4 + 3]
            pb = rows_bare[y][x * 4:x * 4 + 3]
            lum_a = 0.2126 * pa[0] + 0.7152 * pa[1] + 0.0722 * pa[2]
            lum_b = 0.2126 * pb[0] + 0.7152 * pb[1] + 0.0722 * pb[2]
            deviations.append(abs(lum_a - lum_b))
    if not deviations:
        return 0.0
    centre_px = rows_spot[int(cy)][int(cx) * 4:int(cx) * 4 + 3]
    centre = 0.2126 * centre_px[0] + 0.7152 * centre_px[1] + 0.0722 * centre_px[2]
    return 100.0 * (sum(deviations) / len(deviations)) / max(centre, 1e-9)


def check_banded_disc_keeps_its_curvature(results, size=200, ss=2):
    """Piringan ber-pita harus **tetap melengkung**, bukan jadi stiker rata.

    **Cacat yang ditutup pemeriksaan ini.** Pita Jupiter digambar sebagai elips
    warna **rata** di atas bola yang sudah dinaungi gradien. Karena tiap pita
    menutupi 55% piksel di bawahnya, ia menghapus lengkung bola di situ.
    Diukur pada baris ekuator render 200 px: selisih terang pusat-ke-limb turun
    dari **50.6%** (bola polos) ke **20.8%** (bola ber-pita), dan pada 0.96 R
    pitanya justru **+62.6** lebih terang daripada bola tanpa pita di titik
    yang sama. Yang terlihat karena itu bukan bola berpita, melainkan stiker
    rata yang ditempel di piringan.

    **Kenapa harus dari piksel.** Uji model mengunci bahwa kekuatannya
    sebagian (`testBandLimbShadingIsPartial`), dan itu benar. Tapi yang dikirim
    ke layar adalah gambar: kalau view lupa memanggil pemulihannya, atau
    memanggilnya dengan kekuatan yang salah, modelnya tetap benar sementara
    gambarnya rata. Yang membuktikan lengkungnya kembali adalah mengukur baris
    ekuatornya sendiri.

    **Bola pembanding diambil dari kasus "ragu"**, yang menggambar bola Jupiter
    yang sama **tanpa** pita (ciri pengenal wajib hilang saat ragu). Jadi
    selisih keduanya adalah pita, dan lengkung bola yang benar bisa diukur
    tanpa menuliskan angka lengkung ke dalam pemeriksaan ini.

    Ambangnya **70% dari lengkung bola**: pemulihan 0.6 memberi 75% pada
    pengukuran ini, dan cacat aslinya 41%. Yang dijaga adalah bahwa pemulihan
    itu **ada dan sebagian besar**, bukan nilai persisnya.

    **Kenapa dua pemeriksaan terakhir memeriksa teks, bukan piksel.** Piksel
    di atas membuktikan **port** menggambar lengkungnya. Yang dikirim ke jam
    adalah **view**, dan view punya cara gagalnya sendiri: ia bisa berhenti
    memanggil pemulihan itu (gambar di jam rata, PNG tetap melengkung), atau
    memanggilnya dengan angka yang ditulis ulang alih-alih dibaca dari model.
    Keduanya tidak bisa dilihat oleh pemeriksaan piksel mana pun, karena
    piksel itu milik port. Kelas cacat yang sama berulang di repo ini —
    \"satu angka, dua bahasa, tidak ada yang membandingkan\" — jadi yang diikat
    di sini adalah **pemakaian** di kedua sisi, dengan nama konstanta yang
    harus benar-benar disebut.
    """
    _, (w, h, rows_c) = render_case("planet-jupiter-confirmed", size=size, ss=ss)
    _, (_, _, rows_b) = render_case("planet-jupiter-uncertain", size=size, ss=ss)
    cy = h // 2
    cx = w / 2.0
    radius = min(w, h) / 2.0
    x_limb = min(w - 1, int(round(cx + 0.96 * radius)))

    def lum(rows, x, y):
        px = rows[y][x * 4:x * 4 + 3]
        return 0.2126 * px[0] + 0.7152 * px[1] + 0.0722 * px[2]

    def curvature(rows):
        centre = lum(rows, int(cx), cy)
        limb = lum(rows, x_limb, cy)
        return 100.0 * (centre - limb) / max(centre, 1e-9)

    bare = curvature(rows_b)
    banded = curvature(rows_c)
    ratio = banded / max(bare, 1e-9)
    results.append(Result(
        "piringan ber-pita tetap melengkung (bukan stiker rata)",
        ratio >= 0.70,
        f"lengkung ber-pita {banded:.1f}% vs bola polos {bare:.1f}% "
        f"(rasio {ratio * 100:.0f}%, ambang 70%)"))

    # Arah kedua: pitanya sendiri **tidak boleh hilang**. Tanpa ini, pemulihan
    # penuh (kekuatan 1.0) akan lulus pemeriksaan di atas dengan sempurna
    # sambil menghapus seluruh pita Jupiter.
    #
    # **Metriknya diukur, bukan dipilih.** Versi pertama memakai kontras
    # terang-gelap di sepanjang kolom tengah belahan utara, dan ia **tidak
    # pernah menggigit**: nilainya 18.3% pada kekuatan 0.6 dan 17.0% pada 1.0,
    # sedangkan ambangnya 15% — jadi pemulihan penuh lolos sambil menghapus
    # seluruh pita. Penyebabnya metrik itu mengukur **gradien bola sendiri**
    # (yang ada dengan atau tanpa pita), bukan pitanya. Diukur pada rentang
    # penuh, kolom itu hampir tidak bergerak: 24.7 / 21.0 / 18.3 / 16.2 / 17.0.
    #
    # Yang benar adalah menyelisihkan terhadap **bola tanpa pita** pada kolom
    # yang sama — selisih itu adalah pitanya sendiri, dan gradien bola saling
    # menghapus di kedua gambar. Hasilnya monoton terhadap kekuatannya:
    #
    #     kekuatan   0.0   0.3   0.6   0.9   1.0
    #     selisih   3.5%  2.5%  1.5%  0.4%  0.0%
    #
    # Pada 1.0 selisihnya **nol persis** — pemulihan dengan gradien yang sama
    # memang meniadakan pitanya, jadi tidak ada lagi yang membedakan piringan
    # ber-pita dari bola polos. Itulah cacat yang dijaga ambang 0.75%.
    deviation = band_deviation_from_bare(rows_c, rows_b, cx, cy, radius)
    results.append(Result(
        "pita Jupiter masih terbaca setelah pemulihan lengkung",
        deviation >= 0.75,
        f"pita menyimpang {deviation:.2f}% dari bola polos (ambang 0.75%; "
        f"kekuatan 1.0 memberi 0.00%)"))

    # **Pemakaian di view dan di port.** Pemeriksaan piksel di atas mengukur
    # port; ia tidak bisa melihat view berhenti memanggil pemulihannya, atau
    # memanggilnya dengan angka yang ditulis ulang. Yang diikat di sini adalah
    # bahwa **nama konstanta model** benar-benar muncul di kedua sisi, dan
    # bahwa sisi port memakai konstanta port-nya sendiri — bukan `0.6` yang
    # kebetulan sama hari ini.
    view = open(os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()
    port = open(R.SOURCE, encoding="utf-8").read()
    results.append(Result(
        "pemulihan lengkung dipanggil di view (bukan ditulis ulang)",
        "opacity: CelestialVisual.bandLimbShadingStrength" in view,
        "view memanggil 'opacity: CelestialVisual.bandLimbShadingStrength' = "
        f"{'ada' if 'opacity: CelestialVisual.bandLimbShadingStrength' in view else 'TIDAK'}"))
    results.append(Result(
        "port memakai konstanta BAND_LIMB_SHADING_STRENGTH-nya sendiri",
        "opacity=BAND_LIMB_SHADING_STRENGTH" in port
        and "BAND_LIMB_SHADING_STRENGTH = " in port,
        "port memakai 'opacity=BAND_LIMB_SHADING_STRENGTH' = "
        f"{'ada' if 'opacity=BAND_LIMB_SHADING_STRENGTH' in port else 'TIDAK'}"))


def band_deviation_from_bare(rows_banded, rows_bare, cx, cy, radius):
    """Seberapa jauh pita menyimpang dari **bola polos**, dalam persen terang.

    **Kenapa bukan kontras terang-gelap di sepanjang kolom.** Versi pertama
    fungsi ini memakai `max(vals) - min(vals)` di kolom tengah, dan itu
    **tidak pernah menggigit**: nilainya 18.3% pada kekuatan 0.6 dan 17.0%
    pada 1.0, sementara ambangnya 15%. Alasannya metrik itu mengukur
    **gradien bola sendiri** — yang ada dengan atau tanpa pita, karena
    `_draw_sphere` selalu menggambar lengkung dari kiri-atas. Pita jadi
    bagian kecil dari angka itu, dan pemulihan penuh (yang menghapus seluruh
    pita) tetap lolos.

    Yang benar adalah **menyelisihkan kedua gambar pada kolom yang sama**:
    gradien bola saling menghapus, dan yang tersisa adalah pitanya sendiri.
    Diukur pada rentang penuh, hasilnya monoton — 3.5 / 2.5 / 1.5 / 0.4 / 0.0%
    pada kekuatan 0.0 / 0.3 / 0.6 / 0.9 / 1.0 — dan nol persis pada 1.0.

    Belahan **utara** dipakai karena Bintik Merah Besar ada di selatan
    (`jupiterSpot().centerY = +0.31`): mengukur seluruh kolom akan mencampur
    kontras pita dengan bintiknya, dan angka itu bergerak saat bintiknya
    disetel — bukan saat pitanya berubah.
    """
    x = int(cx)
    deviations = []
    for y in range(int(cy - 0.85 * radius), int(cy - 0.05 * radius)):
        px_a = rows_banded[y][x * 4:x * 4 + 3]
        px_b = rows_bare[y][x * 4:x * 4 + 3]
        lum_a = 0.2126 * px_a[0] + 0.7152 * px_a[1] + 0.0722 * px_a[2]
        lum_b = 0.2126 * px_b[0] + 0.7152 * px_b[1] + 0.0722 * px_b[2]
        deviations.append(abs(lum_a - lum_b))
    px_c = rows_banded[int(cy)][x * 4:x * 4 + 3]
    centre = 0.2126 * px_c[0] + 0.7152 * px_c[1] + 0.0722 * px_c[2]
    return 100.0 * (sum(deviations) / len(deviations)) / max(centre, 1e-9)


def check_star_size_follows_magnitude(results, size=38, ss=8):
    """Ukuran bintang harus mengikuti magnitudo katalog — diukur dari piksel.

    **Cacat yang ditutup pemeriksaan ini.** Kasus bintang di `build_cases()`
    ditulis dengan `relative_size=size_from_magnitude(0.0)` untuk **setiap**
    bintang bernama — satu magnitudo yang sama untuk Sirius (−1.46) dan Vega
    (+0.03). Sirius 4,3× lebih terang dari Rigel, dan pada ukuran kartu jam
    (38 pt) keduanya terukur **0 piksel berbeda**: tidak ada satu pun gambar
    di repo ini yang pernah membuktikan ukuran mengikuti magnitudo. Yang
    berbohong bukan jamnya — `CelestialVisual(object:)` memakai
    `object.magnitude` sungguhan — melainkan perlengkapan render inilah yang
    diukur gerbang gambar. Kelas yang sudah berulang di repo ini: gerbang
    yang mengukur gambar yang tidak pernah tampil.

    Ukuran dibaca dari `Catalogue.swift`, bukan dari daftar tangan di sini:
    daftar tangan akan menjadi salinan ke-26 yang tidak pernah dibandingkan,
    dan bintang yang ditambahkan besok akan tampil dengan ukuran lama yang
    **tampak sah**.
    """
    magnitudes = R.catalogue_magnitudes()
    cases = {c.name: c for c in R.build_cases()}

    # (0) Pembaca magnitudo diuji terhadap **angkanya**, bukan terhadap dirinya
    #     sendiri. Tiga pemeriksaan di bawah semuanya membandingkan pembaca
    #     dengan dirinya sendiri: kalau `catalogue_magnitudes()` mengembalikan
    #     angka yang sama-sama bergeser, fixture tetap "cocok" dengan katalog
    #     versi salah, ukuran tetap mengikuti urutannya, dan seluruh
    #     pemeriksaan hijau sambil bintang tergambar dengan ukuran yang keliru.
    #     Ini beda jenis dari "daftar tangan" yang dikritik di atas: daftar
    #     tangan di sana **menyalin** katalog; angka di sini adalah **fakta
    #     langit** yang tidak berasal dari kode mana pun — satu-satunya jalan
    #     sebuah pemeriksaan bisa tahu pembacanya melenceng.
    anchored = {"sirius": -1.46, "vega": 0.03, "rigel": 0.13, "betelgeuse": 0.50}
    drifted = [f"{star}: {magnitudes.get(star)} ≠ {want:+.2f}"
               for star, want in anchored.items()
               if magnitudes.get(star) is None
               or abs(magnitudes[star] - want) > 0.005]
    results.append(Result(
        "magnitudo terbaca cocok dengan fakta langit", not drifted,
        "; ".join(drifted) if drifted else "Sirius −1.46 … Betelgeuse +0.50"))

    # (1) Perlengkapan tidak boleh menyimpang dari katalog: tiap kasus
    #     `star-<id>` memakai `relative_size` dari magnitudo katalognya.
    mismatched = []
    for star in ("sirius", "vega", "rigel", "betelgeuse"):
        name = f"star-{star}"
        case = cases.get(name)
        if case is None:
            mismatched.append(f"{name} tidak ada")
            continue
        want = R.size_from_magnitude(magnitudes[star])
        got = case.kw.get("relative_size")
        if got is None or abs(got - want) > 1e-9:
            mismatched.append(f"{star}: {got} ≠ {want:.4f}")
    results.append(Result(
        "ukuran kasus bintang dari magnitudo katalog", not mismatched,
        "; ".join(mismatched) if mismatched
        else f"4 bintang, m {magnitudes['sirius']:+.2f}…{magnitudes['betelgeuse']:+.2f}"))

    # (2) Efeknya sampai ke gambar: Sirius harus menutupi lebih banyak piksel
    #     daripada Rigel. Yang dijaga **arah**, bukan angka absolut —
    #     `relative_size` yang benar tapi dibuang penggambar lolos (1).
    def footprint(star):
        case = cases[f"star-{star}"]
        buf = R.render(case, size=size, night_mode=False,
                       show_frame=False, ss=ss).buf
        return sum(1 for p in buf if sum(p) > 0.3)

    sirius, rigel = footprint("sirius"), footprint("rigel")
    results.append(Result(
        "Sirius menutupi lebih banyak piksel dari Rigel", sirius > rigel,
        f"piksel menyala @38pt: sirius={sirius}, rigel={rigel}"))

    # (3) Arah sebaliknya, pada rentang penuh: gambar berbeda di tiap ukuran.
    #     `sizeFromMagnitude` boleh benar sementara penggambar mengabaikannya;
    #     tanpa pemeriksaan ini, satu gambar untuk semua ukuran bisa lolos
    #     (1) dan (2) sekaligus kalau kebetulan cocok.
    seen = {}
    for relative in (0.2, 0.5, 0.8, 1.0):
        case = R.VisualCase("probe", "probe", "star", color_index=0.0,
                            relative_size=relative, is_confirmed=True)
        buf = R.render(case, size=size, night_mode=False,
                       show_frame=False, ss=ss).buf
        seen[relative] = tuple(round(c, 6) for p in buf for c in p)
    keys = list(seen)
    duplicates = [f"{a}&{b}" for i, a in enumerate(keys)
                  for b in keys[i + 1:] if seen[a] == seen[b]]
    results.append(Result(
        "empat ukuran bintang menghasilkan empat gambar", not duplicates,
        f"ukuran kembar: {', '.join(duplicates)}" if duplicates
        else "0.2/0.5/0.8/1.0 semuanya berbeda"))


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


def check_crater_floor_opacity_comes_from_the_model(results, size=76, ss=6):
    """Kelegapan dasar kawah harus **nilai model**, bukan angka tetap.

    **Cacat yang ditutup pemeriksaan ini.** `CelestialVisual.craterRelief`
    menghitung `floorDepth` untuk tiap kawah dan mendokumentasikan field itu
    sebagai *"dipakai sebagai kelegapan lapisan hitam"*. Kedua penggambar —
    `drawCraters` di view Swift dan `_draw_craters` di port Python —
    **mendestrukturisasi `floorDepth` lalu membuangnya**: keduanya menulis
    angka tetap `0.85`.

    Angka itu bukan sekadar tidak terpakai, ia **menenggelamkan** tanda yang
    membuat kawah terbaca cekung. Kedalaman maksimum model adalah 0.22, jadi
    0.85 adalah 3,9× lipatnya. Sabit bibir yang menghadap cahaya digambar
    dengan kelegapan 0.9·rimStrength (≈0.3–0.5) **di atas** dasar yang
    kelegapannya 0.85: dasar itu praktis menutupi seluruh piringan, dan sabit
    terangnya tinggal samar. Hasilnya — **setiap** bagian setiap kawah lebih
    gelap daripada permukaan sekitarnya:

        dinding sisi cahaya − permukaan   −46,6 … −21,7
        dinding sisi bayangan − permukaan −91,3 … −47,6

    Itu tanda tangan **stiker gelap yang ditempel**, bukan cekungan. Cekungan
    butuh dua dinding yang berlawanan tanda: satu lebih terang dari permukaan,
    satu lebih gelap. Setelah dasar memakai `floorDepth`:

        dinding sisi cahaya − permukaan    +0,8 … +9,6
        dinding sisi bayangan − permukaan −35,6 … −14,2

    **Angka di atas diukur, bukan diperkirakan** — dengan penyampel yang sama
    persis yang dipakai pemeriksaan di bawah (`_sample`, `size=76`, `ss=6`),
    pada keadaan sumber sebelum dan sesudah perbaikan. Versi pertama komentar
    ini menulis −45,2 … −5,1 / −93,1 … −49,7, dan **tidak satu pun angka itu
    pernah keluar dari penyampel ini**: rentangnya tidak muncul di ukuran
    mana pun (diukur 76/100/152/200/240/300/400/500 px). Itu kelas cacat yang
    sudah berulang di repo ini — gerbang mengutip angka yang tidak pernah ia
    ukur, persis seperti "elips 20% R" yang ternyata milik luas, bukan jarak
    tepi. Karena itu angka di sini ditulis apa adanya dari hasil ukur, dan
    batas atas dinding sisi cahaya (−21,7) sengaja dibiarkan **tidak** enak
    dilihat: itu angka sebenarnya, dan memperbaikinya berarti mengubah
    geometri kawah, bukan komentarnya.

    **Kenapa dua sisi diperiksa.** Gerbang ini dulu tidak ada, dan yang ada
    (`check_port_matches_swift_constants`) justru **mengunci cacatnya**: ia
    membandingkan `R.CRATER_FLOOR_OPACITY` dengan `0.85` **dan** mencari
    string `floor.opacity(0.85)` di view. Dua bahasa yang sepakat pada angka
    yang sama-sama salah adalah gerbang yang hijau sambil menjaga gambar yang
    tidak pernah benar. Karena itu di sini yang diperiksa bukan keberadaan
    konstanta, melainkan (1) bahwa kelegapan itu **dibaca dari model** di
    kedua bahasa, dan (2) bahwa **pikselnya benar-benar cekung**. Yang pertama
    menangkap penyimpangan teks, yang kedua menangkap bentuk gambar apa pun
    sebabnya — termasuk sebab yang belum terpikirkan.

    Diukur di 76 px, bukan 200 px: inilah ukuran piringan di kartu jam, dan
    inilah satu-satunya ukuran yang penting bagi pengguna. Di 200 px cacat
    yang sama terlihat jauh lebih ringan.
    """
    view = open(os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()
    port = open(R.SOURCE, encoding="utf-8").read()

    # (1) Struktur: kedua penggambar harus menyebut `floorDepth` di tempat
    #     kelegapan dasar ditentukan. Dibandingkan sebagai teks karena
    #     inilah yang membedakan "memakai nilai model" dari "kebetulan
    #     angkanya sama".
    results.append(Result(
        "kawah: view memakai floorDepth dari model untuk dasar cekungan",
        "floor.opacity(crater.floorDepth)" in view,
        "mencari 'floor.opacity(crater.floorDepth)' di CelestialVisualView.swift"))
    results.append(Result(
        "kawah: port memakai floor_depth dari model untuk dasar cekungan",
        'night_mode, floor_depth))' in port,
        "mencari 'night_mode, floor_depth))' di render-visuals.py"))
    # Dan konstanta tetap itu harus **hilang** sebagai nilai, bukan sekadar
    # tidak dipakai: nilai mati yang masih ada akan dipakai lagi oleh orang
    # berikutnya. Yang dicari adalah **penetapan** nilainya (`NAME = ...`),
    # bukan penyebutan namanya — nama itu memang masih disebut di komentar
    # yang menjelaskan kenapa ia dihapus, dan gerbang yang merah karena
    # dokumentasinya sendiri adalah gerbang yang akan dihapus orang.
    floor_constant = re.search(r"^\s*CRATER_FLOOR_OPACITY\s*=", port, re.M)
    results.append(Result(
        "kawah: tidak ada lagi konstanta opasitas dasar tetap di port",
        floor_constant is None,
        "mencari penetapan 'CRATER_FLOOR_OPACITY =' di render-visuals.py "
        "(harus tidak ada)"))

    # (2) Gambar: ukur tanda kontras dinding kawah terhadap permukaannya.
    lit_side, shadow_side, names = crater_wall_contrast(size, ss)

    # Setiap kawah harus punya dinding yang lebih terang dari permukaan.
    # Inilah yang hilang saat dasar cekungan ditutup opasitas 0.85.
    dim = [names[i] for i, v in enumerate(lit_side) if v <= 0]
    results.append(Result(
        "kawah: dinding sisi cahaya lebih terang dari permukaan",
        not dim,
        f"selisih {min(lit_side):+.1f} … {max(lit_side):+.1f} luminansi "
        f"pada {len(R.CRATERS)} kawah @{size}px"
        + (f"; gelap di {dim}" if dim else "")))
    # Dan setiap kawah harus punya dinding yang lebih gelap dari permukaan:
    # tanpa sisi gelap, yang tergambar cembung (menonjol), bukan cekung.
    bright = [names[i] for i, v in enumerate(shadow_side) if v >= 0]
    results.append(Result(
        "kawah: dinding sisi bayangan lebih gelap dari permukaan",
        not bright,
        f"selisih {min(shadow_side):+.1f} … {max(shadow_side):+.1f} luminansi "
        f"pada {len(R.CRATERS)} kawah @{size}px"
        + (f"; terang di {bright}" if bright else "")))


def crater_wall_contrast(size=76, ss=6):
    """Selisih luminansi dinding tiap kawah terhadap permukaan sekitarnya.

    **Kenapa ini fungsi, bukan badan pemeriksaan.** Ia dipakai oleh
    `check_crater_floor_opacity_comes_from_the_model` **dan** oleh
    `check_crater_contrast_numbers_come_from_the_sampler`. Kalau yang kedua
    menyampel dengan caranya sendiri, ia hanya membuktikan komentarnya cocok
    dengan alat ukur yang **berbeda** dari yang dipakai yang pertama — persis
    cacat yang ia ada untuk menutup. Satu penyampel, dua pembaca.

    Mengembalikan `(lit_side, shadow_side, names)`: selisih luminansi
    (piksel 0…255) dinding yang menghadap cahaya dan dinding yang
    membelakanginya, satu angka per kawah.

    Permukaan acuan diambil dari cincin di **luar** kawah (1,45–1,95×
    jari-jarinya), supaya yang dibandingkan bukan kawah melawan dirinya
    sendiri. Dinding menghadap cahaya ada di sisi **jauh** dari sumber cahaya,
    karena bibirnya digeser ke arah cahaya dan yang tersisa di dalam adalah
    dinding seberangnya.
    """
    _, (w, h, rows) = render_case("planet-mercury-confirmed", size=size, ss=ss)
    radius = min(w, h) / 2.0
    light_x, light_y = R.SPHERE_LIGHT_OFFSET
    length = math.hypot(light_x, light_y)
    ux, uy = light_x / length, light_y / length

    def lum_at(x, y):
        xi = max(0, min(w - 1, int(round(x))))
        yi = max(0, min(h - 1, int(round(y))))
        r, g, b = rows[yi][xi * 4:xi * 4 + 3]
        return 0.299 * r + 0.587 * g + 0.114 * b

    def sample(points):
        return sum(lum_at(x, y) for x, y in points) / len(points)

    lit_side, shadow_side, names = [], [], []
    for dx, dy, crater_r in R.CRATERS:
        cx, cy = w / 2.0 + dx * radius, h / 2.0 + dy * radius
        rp = crater_r * radius
        ring = [(cx + math.cos(a) * rp * f, cy + math.sin(a) * rp * f)
                for a in [i * math.pi / 24 for i in range(48)]
                for f in (1.45, 1.7, 1.95)]
        surface = sample(ring)
        lit_side.append(sample([(cx - ux * rp * t, cy - uy * rp * t)
                                for t in (0.55, 0.7, 0.85)]) - surface)
        shadow_side.append(sample([(cx + ux * rp * t, cy + uy * rp * t)
                                   for t in (0.55, 0.7, 0.85)]) - surface)
        names.append(f"({dx:+.2f},{dy:+.2f})")
    return lit_side, shadow_side, names


def check_crater_contrast_numbers_come_from_the_sampler(results):
    """Angka di dokumentasi kawah harus **keluar dari penyampelnya sendiri**.

    **Cacat yang ditutup pemeriksaan ini.** Versi pertama docstring
    `check_crater_floor_opacity_comes_from_the_model` mengutip empat rentang
    kontras sebagai bukti, dan **tidak satu pun** keluar dari penyampel yang
    dipakai pemeriksaan di bawahnya:

        dikutip   dinding sisi cahaya   −45,2 …  −5,1   →  +3,4 … +10,3
        sebenarnya                     −46,6 … −21,7   →  +0,8 …  +9,6

    Dua-duanya salah di **kedua** ujung, dan yang paling menyesatkan adalah
    `−5,1`: ia menyatakan hampir tidak ada dinding terang yang hilang,
    padahal seluruh lima kawah menjadi **lebih gelap** dari permukaannya
    (−21,7). Argumen yang justru menjadi alasan pemeriksaan itu ada jadi
    terdengar lemah oleh angkanya sendiri. Rentang itu juga tidak muncul di
    ukuran mana pun (diukur 76/100/152/200/240/300/400/500 px).

    Ini kelas yang sudah berulang di repo ini — gerbang mengutip angka yang
    tidak pernah ia ukur, persis "elips 20% R" yang ternyata milik **luas**
    sementara metriknya mengukur jarak tepi. Bahayanya bukan angka salah di
    komentar: komentar itu **satu-satunya bukti** yang dibaca orang yang
    menilai apakah pemeriksaan ini layak dipercaya.

    **Kenapa "sebelum" tidak perlu dikutip dari riwayat git.** Keadaan
    "sebelum" direproduksi dari **kode port itu sendiri**: `crater_relief`
    dibungkus sementara supaya `floor_depth` tiap kawah dipaksa ke `0.85`,
    lalu scene yang sama digambar ulang lewat jalur produksi. Jadi kedua
    keadaan diukur oleh satu penyampel yang sama (`crater_wall_contrast`),
    dan tidak ada angka yang datang dari luar pengukuran.

    Batas yang jujur: pemeriksaan ini menjaga **komentar cocok dengan
    pengukuran**, bukan bahwa komentarnya bagus. Angka yang jelek tapi benar
    tetap lolos — dan memang harus lolos, karena memperbaikinya berarti
    mengubah geometri kawah, bukan prosa.
    """
    doc = check_crater_floor_opacity_comes_from_the_model.__doc__ or ""
    pattern = (r"dinding sisi (cahaya|bayangan)\s+[−-]\s*permukaan\s+"
               r"([+−-]?[\d,]+)\s*…\s*([+−-]?[\d,]+)")
    quoted = re.findall(pattern, doc)

    def number(text):
        return float(text.replace("−", "-").replace(",", "."))

    # Empat kutipan = dua sisi × dua keadaan (sebelum & sesudah). Kurang dari
    # itu berarti salah satu keadaan berhenti didokumentasikan, dan itu
    # kehilangan bukti, bukan penyederhanaan.
    if len(quoted) != 4:
        results.append(Result(
            "kawah: docstring mengutip empat rentang kontras (sebelum & sesudah)",
            False,
            f"{len(quoted)} kutipan terbaca dari docstring "
            f"check_crater_floor_opacity_comes_from_the_model — butuh 4 "
            f"(dinding cahaya & bayangan, untuk keadaan sebelum dan sesudah)"))

    measured_after = crater_wall_contrast()
    original = R.crater_relief

    def forced(craters, *args, **kwargs):
        # `floor_depth` adalah elemen terakhir tupel `crater_relief`. Memaksa
        # ke 0.85 mereproduksi keadaan sebelum perbaikan **lewat jalur
        # menggambar yang sama**, bukan lewat salinan angka.
        return [t[:6] + (0.85,) for t in original(craters, *args, **kwargs)]

    try:
        setattr(R, "crater_relief", forced)
        measured_before = crater_wall_contrast()
    finally:
        setattr(R, "crater_relief", original)

    # Urutan kutipan di docstring: sebelum (cahaya, bayangan), lalu sesudah.
    expected = [
        ("sebelum", "dinding sisi cahaya", measured_before[0]),
        ("sebelum", "dinding sisi bayangan", measured_before[1]),
        ("sesudah", "dinding sisi cahaya", measured_after[0]),
        ("sesudah", "dinding sisi bayangan", measured_after[1]),
    ]
    if len(quoted) != len(expected):
        return
    for (state, side, values), (q_side, low, high) in zip(expected, quoted):
        want_low, want_high = min(values), max(values)
        got_low, got_high = number(low), number(high)
        # `q_side` hanya menangkap kata terakhir ("cahaya"/"bayangan"),
        # sedangkan `side` adalah frasa penuhnya — dibandingkan sebagai kata
        # terakhir, bukan sebagai string utuh, supaya tidak merah pada kode
        # yang benar (bug yang sudah dua kali tercatat di repo ini).
        side_word = side.split()[-1]
        same = (abs(got_low - want_low) <= 0.05
                and abs(got_high - want_high) <= 0.05
                and q_side == side_word)
        results.append(Result(
            f"kawah: angka {state} (dinding {side_word}) sama dengan hasil ukur",
            same,
            f"docstring {got_low:+.1f} … {got_high:+.1f}, "
            f"terukur {want_low:+.1f} … {want_high:+.1f} @76px"
            + ("" if q_side == side_word else f" (sisi tertukar: {q_side})")))


def check_moon_disc_keeps_its_curvature(results, size=200, ss=2):
    """Pita terang Bulan harus **melengkung**, bukan isian warna rata.

    **Cacat yang ditutup pemeriksaan ini.** Pita terang Bulan digambar sebagai
    satu warna `moonLit` penuh dari pusat sampai limb, sementara `drawSphere`
    memberi planet gradien bola. Diukur pada 200 px, ss=2, kekuatan 0.40:

        kasus               metrik                 rata (0)   dipakai (0.40)
        Bulan purnama       lengkung ekuator        +0.0%        +33.5%
        Fase tak diketahui  lengkung ekuator        +0.0%        +33.4%
        Bulan sabit         sebaran pita             0.0          24.1
        Mars (pembanding)   lengkung ekuator       +54.8%        +54.8%

    **Kenapa dua metrik, bukan satu.** Baris ekuator hanya menyampel pita
    terang kalau pita itu **melintasi** ekuator. `moon-crescent-jakarta` punya
    sisi terang ke bawah, jadi seluruh baris ekuatornya jatuh di piringan
    gelap dan metrik itu mengembalikan **+0.0%** untuk gambar yang benar.
    Angka itu sempat dipakai sebagai bukti di sini dan gerbangnya merah pada
    kode yang benar — kelas cacat yang sudah tercatat berkali-kali di repo ini.
    Untuk kasus itu metriknya diganti: sebaran luminans (p95 − p5) piksel yang
    terklasifikasi **menyala** oleh cara yang sama yang dipakai
    `classify_centroid`. Pita rata → sebaran 0.0; pita yang dinaungi bola →
    24.1. Sebaran itu **tidak tercemar maria** di kasus sabit: pada kekuatan 0
    ia terukur 0.0, jadi yang menggerakkannya memang gradiennya.

    **Batas atas kekuatan diukur, bukan dipilih.** `classify_centroid`
    memutuskan "menyala" versus "gelap" pada jarak-warna RGB, jadi pada gradien
    yang terlalu dalam piksel limb jatuh ke sisi gelap dan luas pita yang
    terukur menyusut. Disapu pada 200 px, ss=2, toleransi gerbang fase 0.10:

        kekuatan   luas pita merah   lengkung purnama
        0.45            0/9              +37.6%
        0.50            0/9              +41.6%
        0.60            7/9              +50.2%   <- gerbang merah

    **Kenapa `moon-new` tidak diukur.** Piringan gelap Bulan sengaja tetap
    rata — earthshine dilukis di atasnya sebagai cakram warna rata, jadi
    gradiennya terhapus justru di fase tempat sisi gelap paling terlihat
    (terukur: `moon-new` tetap +0.0% pada setiap kekuatan 0…0.80), dan
    memperdalamnya mematikan `check_earthshine` pada kekuatan 0.20. Yang
    melengkung adalah bagian yang **disinari sumber titik** — pita terangnya
    dan piringan "fase tak diketahui" — bukan sisi gelap yang disinari Bumi.
    Piringan rata itu sendiri diukur **keterbacaannya**, bukan lengkungnya:
    lihat `check_moon_new_disc_reads_on_the_watch` (dulu 1.32:1 — tak terlihat).

    **Ambang lengkung relatif terhadap Mars.** Mars adalah bola yang sudah
    memakai `drawSphere`, jadi lengkungnya adalah patokan lengkung yang benar
    di render yang sama. Yang dijaga adalah bahwa Bulan **mendekati** patokan
    itu, bukan bahwa ia menyamainya.

    Dua pemeriksaan terakhir memeriksa **teks, bukan piksel**: piksel di atas
    membuktikan **port** menggambar lengkungnya, sedangkan yang dikirim ke jam
    adalah **view**. View bisa berhenti memanggil shading itu (jam rata, PNG
    tetap melengkung) atau memanggilnya dengan angka yang ditulis ulang.
    """
    _, (w, h, rows) = render_case("planet-mars-confirmed", size=size, ss=ss)
    cx = w / 2.0
    cy = h // 2          # indeks baris, bukan koordinat
    radius = min(w, h) / 2.0
    x_limb = min(w - 1, int(round(cx + 0.96 * radius)))

    def lum(rows_, x, y):
        px = rows_[y][x * 4:x * 4 + 3]
        return 0.2126 * px[0] + 0.7152 * px[1] + 0.0722 * px[2]

    def curvature(rows_):
        centre = lum(rows_, int(cx), cy)
        limb = lum(rows_, x_limb, cy)
        return 100.0 * (centre - limb) / max(centre, 1e-9)

    def lit_spread(rows_):
        """Sebaran luminans piksel menyala — metrik yang tidak butuh ekuator."""
        lit = tuple(round(c * 255) for c in R.ACCENTS["moonLit"])
        unlit = tuple(round(c * 255) for c in R.ACCENTS["moonUnlit"])
        values = []
        for y in range(h):
            for x in range(w):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 > radius * radius:
                    continue
                p = rows_[y][x * 4:x * 4 + 3]
                da = sum((p[k] - lit[k]) ** 2 for k in range(3))
                db = sum((p[k] - unlit[k]) ** 2 for k in range(3))
                if da < db:
                    values.append(0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2])
        if len(values) < 20:
            return None, len(values)
        values.sort()
        return (values[int(0.95 * (len(values) - 1))] - values[int(0.05 * (len(values) - 1))],
                len(values))

    mars = curvature(rows)
    # Ambang 30% lengkung Mars = 16.4: terukur 33.5 dan 33.4 versus 54.8, jadi
    # ambangnya punya jarak di kedua sisi, dan ia menangkap keadaan rata
    # (0.0%) dengan margin yang jauh lebih lebar dari noise rasterisasi.
    threshold = 0.30 * mars
    for name, label in (("moon-full", "purnama"),
                        ("moon-unknown-phase", "fase tak diketahui")):
        _, (_, _, rows_) = render_case(name, size=size, ss=ss)
        value = curvature(rows_)
        results.append(Result(
            f"pita terang Bulan ({label}) melengkung, bukan warna rata",
            value >= threshold,
            f"lengkung {value:.1f}% vs Mars {mars:.1f}% "
            f"(ambang {threshold:.1f}% = 30% lengkung Mars; rata = +0.0%)"))

    # Sabit: sisi terang ke bawah, jadi baris ekuator **tidak** menyampel
    # pitanya. Metriknya sebaran, bukan lengkung. Ambang 8.0 duduk di antara
    # 0.0 (pita rata, kekuatan 0) dan 24.1 (kekuatan 0.40) — jaraknya lebar di
    # kedua sisi.
    _, (_, _, rows_c) = render_case("moon-crescent-jakarta", size=size, ss=ss)
    spread, count = lit_spread(rows_c)
    results.append(Result(
        "pita terang Bulan sabit bernaung bola (sebaran, bukan warna rata)",
        spread is not None and spread >= 8.0,
        f"sebaran luminans pita {spread:.1f} dari {count} piksel "
        f"(ambang 8.0; pita rata 0.0, kekuatan 0.40 memberi 24.1)"))

    # Piksel membuktikan **port**. View bisa lupa memanggilnya sama sekali.
    view = open(os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")).read()
    results.append(Result(
        "view memanggil shading bola Bulan (bukan cakram rata)",
        "Self.sphereGradient(center: center, radius: radius," in view,
        "view memanggil 'Self.sphereGradient(center: center, radius: radius,' = "
        f"{'ada' if 'Self.sphereGradient(center: center, radius: radius,' in view else 'TIDAK'}"))
    results.append(Result(
        "view membaca radius akhir gradien dari model, bukan menulis angkanya",
        "CelestialVisual.moonSphereGradientEndRadius" in view,
        "view menyebut 'CelestialVisual.moonSphereGradientEndRadius' = "
        f"{'ada' if 'CelestialVisual.moonSphereGradientEndRadius' in view else 'TIDAK'}"))


def inner_planet_phase_cases():
    """Kasus render planet dalam yang **benar-benar berfase**.

    Diturunkan dari `R.build_cases()` lewat **fungsi port yang sama** yang
    dipakai penggambar untuk memutuskan apakah ia menggambar fase
    (`planet_shows_phase` + `phase_geometry`). Daftar yang ditulis tangan di
    sini akan menjadi salinan yang bisa tertinggal separuh: menambah kasus
    fase baru tidak akan membuat gerbang ini berlaku untuknya, padahal
    menambah kasus adalah satu-satunya cara sebuah planet baru bisa diukur.
    """
    out = []
    for case in R.build_cases():
        if case.kind != "planet":
            continue
        planet = case.kw.get("planet")
        if not R.planet_shows_phase(planet):
            continue
        fraction = R.planet_phase_fraction(planet, case.kw.get("illumination"))
        if R.phase_geometry(fraction, case.kw.get("is_waxing")) is None:
            continue
        out.append((case, planet))
    return out


def check_planet_phase_limb_reads_the_model_constant(results, size=None, ss=2):
    """Peredupan limb sabit planet dalam membaca radius akhirnya dari model.

    **Cacat yang ditutup pemeriksaan ini.** `CelestialVisual.moonSphereGradient
    EndRadius` (1.15) mengklaim dipakai di **kedua** bahasa, dan gerbang drift
    memang membandingkannya dengan `MOON_SPHERE_GRADIENT_END_RADIUS` di port.
    Kenyataannya, sampai siklus ini, jalur **planet dalam** menulis `1.15`
    sebagai literal di dalam `drawPlanet` — di view — dan `1.15` sebagai
    literal di dalam `_draw_planet` — di port. Yang membaca konstantanya
    hanya `sphereGradient`, pemanggilnya **Bulan**.

    Akibatnya terukur: mengubah konstanta itu memindahkan
    **nol piksel** pada Venus dan Merkurius berfase, di kedua ukuran (200 px
    dan 38 px), sementara `moon-full` bergeser 31 532 piksel pada 200 px.
    Konstanta itu ada, dinamai, dibandingkan gerbang drift, diuji di Linux
    (`testMoonSphereGradientIsShallowerThanThePlanetSphere`) — dan tidak
    mengatur apa pun di tempat yang dipakai separuh planet dalam.

    Kenapa ini lebih dari sekadar "angka kedua": nilai 1.15 **dipilih dengan
    alasan yang diukur** (radius bola planet 1.35 melemahkan lengkung sabit
    jadi +28,5% dan 20,9 berbanding +33,5% dan 24,1). Kalau 1.15 kelak
    diukur ulang dan diubah, Bulan akan mengikuti dan Venus/Merkurius tidak —
    dua benda yang digambar oleh **fungsi yang sama** (`drawLitBand`) lalu
    berbeda tanpa satu pun galat kompilasi. Yang salah bukan angkanya,
    melainkan bahwa hanya satu dari dua pemanggil yang membacanya.

    **Kenapa diukur lewat konstanta, bukan lewat nilainya.** Pemeriksaan yang
    menuntut "gradiennya ada" akan lolos oleh gradien **apa pun**, termasuk
    yang radius akhirnya ditulis sendiri. Yang diuji di sini adalah
    **kepekaan gambar terhadap konstanta**: nilainya diganti, dan piksel pita
    yang menyala harus bergerak. Gradien yang menulis angkanya sendiri tidak
    bergerak sama sekali — terukur 0,00 berbanding 8,9…15,6 pada 200 px.

    Piksel membuktikan **port**. Yang dikirim ke jam adalah **view**, jadi dua
    pemeriksaan terakhir memeriksa teks `drawPlanet`: konstantanya disebut,
    dan `radius * 1.15` tidak ditulis sendiri. Keduanya memakai
    `swift_code_only` — tanpa itu komentar yang **menjelaskan** cacat ini akan
    dihitung sebagai pemakaian konstantanya.
    """
    cases = inner_planet_phase_cases()
    if not cases:
        results.append(Result(
            "kasus fase planet dalam terbaca dari katalog render", False,
            "tidak ada kasus planet dalam berfase di build_cases() — gerbang ini "
            "tidak mengukur apa pun, dan itu merah, bukan lulus"))
        return

    if size is None:
        size = watch_visual_diameter() or 38
    original = R.MOON_SPHERE_GRADIENT_END_RADIUS
    # 1.45, bukan nilai yang lebih dekat: selisih yang terlalu kecil
    # mendekati noise rasterisasi dan membuat ambangnya sewenang-wenang.
    # Nilai ini **bukan** usulan perbaikan — ia hanya pengubah yang cukup
    # besar untuk terukur di 38 px, tempat seluruh frame cuma 1444 piksel.
    probe = 1.45

    def lit_pixels(canvas, light):
        """Piksel pita yang menyala — klasifikasi yang sama dengan
        `classify_centroid`, terhadap palet planetnya sendiri."""
        unlit = R.ACCENTS["planetUnlit"]
        w, h = canvas.w, canvas.h
        cx = cy = size / 2.0
        radius = size / 2.0
        out = []
        for y in range(h):
            for x in range(w):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 > radius * radius:
                    continue
                p = canvas.buf[y * w + x]
                da = sum((p[k] - light[k]) ** 2 for k in range(3))
                db = sum((p[k] - unlit[k]) ** 2 for k in range(3))
                if da < db:
                    out.append((x, y))
        return out

    def luminance(px):
        return 0.2126 * px[0] + 0.7152 * px[1] + 0.0722 * px[2]

    try:
        for case, planet in cases:
            light = R.PLANET_PALETTE[planet]["light"]
            base = R.render(case, size=size, night_mode=False, show_frame=False, ss=ss)
            pixels = lit_pixels(base, light)
            if not pixels:
                results.append(Result(
                    f"pita {case.name} punya piksel menyala untuk diukur", False,
                    f"0 piksel terklasifikasi menyala pada {size} px — penyampel "
                    "tidak melihat pitanya, dan gerbang ini akan lulus karena "
                    "tidak ada yang diukur"))
                continue
            try:
                R.MOON_SPHERE_GRADIENT_END_RADIUS = probe
                moved = R.render(case, size=size, night_mode=False,
                                 show_frame=False, ss=ss)
            finally:
                R.MOON_SPHERE_GRADIENT_END_RADIUS = original
            deltas = [abs(luminance(base.buf[y * base.w + x])
                          - luminance(moved.buf[y * base.w + x])) * 255
                      for x, y in pixels]
            mean = sum(deltas) / len(deltas)
            # Ambang 4.0/255: terukur 0,00 (konstanta diabaikan — cacat
            # aslinya) berbanding 8,90…15,56 pada 200 px dan 8,90…15,47 pada
            # 38 px. Jaraknya lebar di kedua sisi, dan render ulang dengan
            # nilai yang **sama** terukur 0,00 — jadi ambang ini tidak
            # terpengaruh noise rasterisasi.
            results.append(Result(
                f"radius akhir gradien {case.name} bergerak saat konstanta diubah",
                mean >= 4.0,
                f"rerata pergeseran {mean:.2f}/255 atas {len(pixels)} piksel "
                f"menyala pada {size} px (ambang 4.0; konstanta yang diabaikan "
                f"= 0.00, render ulang identik = 0.00)"))
    finally:
        R.MOON_SPHERE_GRADIENT_END_RADIUS = original

    view_path = os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")
    view = open(view_path, encoding="utf-8").read()
    body = _function_body(view, "func drawPlanet(")
    if not body:
        results.append(Result(
            "drawPlanet terbaca di view", False,
            "'func drawPlanet(' TIDAK ditemukan di CelestialVisualView.swift — "
            "pemeriksaan ini tidak bisa dijalankan, dan itu merah, bukan lulus"))
        return
    code = swift_code_only(body)
    named = "CelestialVisual.moonSphereGradientEndRadius" in code
    results.append(Result(
        "drawPlanet membaca radius akhir gradien dari model", named,
        "'CelestialVisual.moonSphereGradientEndRadius' "
        f"{'ada' if named else 'TIDAK ada'} di kode drawPlanet "
        "(komentar & string dibuang)"))
    literal = re.search(r"radius\s*\*\s*1\.15", code)
    results.append(Result(
        "drawPlanet tidak menulis radius akhirnya sendiri", literal is None,
        "drawPlanet memuat `radius * 1.15` yang ditulis langsung"
        if literal else
        "drawPlanet tanpa literal `radius * 1.15` — angkanya satu, di model"))


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


def _gradient_end_factors(source):
    """Radius akhir dua gradien piringan, dibaca dari sumber.

    Dua gradien yang dijaga, dan keduanya **tidak punya konstanta**: sampai
    gerbang ini ada, `1.35` (gradien bola) dan `1.15` (peredupan limb pada
    piringan berfase) ditulis sebagai literal di `Apps/Shared/CelestialVisual
    View.swift` **dan** di port Python, dan tidak disebut satu pun pemeriksaan
    di berkas ini.

    Bukti mutasi yang membuka celah ini (`out/mutasi-radius-gradasi.py`,
    diukur bukan diasumsikan): keempat mutasi — 1.35→1.60 dan 1.15→1.45, di
    kedua bahasa — membiarkan **seluruh 22 pemeriksaan hijau**. Dan mutasinya
    benar-benar mengubah gambar: 200 dari 200 baris piksel berbeda pada
    ukuran 200 (`out/ukur-radius-gradasi.py`). Jadi bukan gerbang yang tidak
    menyentuh kasusnya; gerbangnya memang tidak pernah melihat angkanya.

    Kenapa ini bukan sekadar dua entri baru di `checks`:
    radius akhir gradien menentukan **berapa jauh peredupan limb menjalar ke
    dalam piringan**. Di situlah letak bahayanya yang tidak terlihat — ia
    tidak mengubah bentuk apa pun, hanya tingkat kecerahan, dan seluruh
    gerbang piksel di berkas ini mengukur **keberadaan** ciri dengan ambang
    yang longgar terhadap kecerahan. Pita Jupiter tetap "ada" walau
    kecerahannya melenceng; yang berubah adalah apakah piringan terbaca
    sebagai **bola**.

    Dua bahasa, dua ejaan, dan keduanya dibaca — bukan ditebak dari
    ekstensi berkas, karena `render-visuals.py` dan `check-visuals.py` sama-
    sama Python dan yang dicari hanya ada di yang pertama:

    | gradien | Swift | Python |
    |---|---|---|
    | bola (drawSphere) | `endRadius: radius * 1.35` | `end_radius=radius * 1.35` |
    | limb berfase | `endRadius: radius * CGFloat(CelestialVisual.moonSphereGradientEndRadius)` | `end_radius=radius * MOON_SPHERE_GRADIENT_END_RADIUS` |

    **Kenapa bentuk konstanta harus dikenali juga.** Kedua jalur limb
    (`drawMoon` lewat `sphereGradient`, dan pita terang planet dalam) sampai
    siklus ini menulis `1.15` sebagai literal; sekarang keduanya membaca
    konstanta model. Pembaca yang hanya mengenali literal akan melaporkan
    "limb tidak terbaca" pada kode yang **benar** — kelas cacat yang sudah
    berulang di repo ini (gerbang yang menuntut ejaan yang sudah dibuang).
    Karena itu nilainnya kini diselesaikan dari **sumber model**, bukan
    ditulis ulang di sini: menyalin `1.15` ke dalam gerbang akan membuatnya
    angka ketiga yang tidak pernah dibandingkan.

    Pengali yang diselesaikan dari konstanta tidak membuat perbandingan ini
    sia-sia. Kalau salah satu bahasa kembali menulis angkanya sendiri
    (`radius * 1.35`, atau `radius * 1.10`), di situlah nilainya berbeda dan
    gerbang ini merah — persis drift yang ia ada untuk menangkap.
    """
    # Komentar dibuang per baris: prosa di repo ini memuat angka, dan
    # pembacaan tanpa membuangnya akan mengambil angka contoh sebagai
    # parameter — cacat yang sudah dua kali terjadi di berkas ini.
    body = "\n".join((line.split("//")[0] if "//" in line else line.split("#")[0])
                     for line in source.split("\n"))
    # Dua gradien memakai kata kunci yang sama (`endRadius: radius * N`),
    # jadi keduanya tidak bisa dibedakan dari pola akhirnya. Pembeda yang
    # dipakai di sini **struktural**, bukan urutan nilai:
    #   - gradien bola  : `startRadius: radius * 0.1`, pusatnya digeser
    #                     mengikuti `sphereLightOffset`
    #   - gradien limb  : `startRadius: 0`, berpusat di pusat piringan
    #
    # Pembeda ini dipilih setelah pembeda yang lebih lemah **diuji dan
    # gagal**: versi pertama mengurutkan dua angka dan menganggap yang besar
    # "bola". Mutasi limb 1.15 -> 1.45 membuat urutan itu terbalik, dan
    # gerbang melaporkan `bola=1.45, port=1.35` — merah, tapi menyalahkan
    # gradien yang tidak diubah. Gerbang yang memberi nama yang salah pada
    # kegagalan akan mengirim orang ke tempat yang salah; kegagalan kedua
    # dalam bukti ini (kasus 6 dan 7) malah berbunyi lewat jalur "kurang
    # dari dua gradien", yang tidak menyebut gradien mana pun.
    # Pengali bisa berupa **literal** (`radius * 1.15`) atau **konstanta**
    # (`radius * CelestialVisual.moonSphereGradientEndRadius` /
    # `radius * MOON_SPHERE_GRADIENT_END_RADIUS`). Keduanya dikenali, karena
    # setelah kedua jalur limb berhenti menulis literal, pembaca yang hanya
    # mengenali literal akan melaporkan "tidak terbaca" pada kode yang benar.
    #
    # Nilai konstanta diselesaikan dari **sumber model**, bukan disalin ke
    # sini: menyalin 1.15 ke gerbang menjadikannya angka ketiga yang tidak
    # pernah dibandingkan. Bila konstantanya tidak terbaca (nama diubah),
    # pemeriksaannya tetap merah dan menyebut namanya — bukan diam.
    model_path = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit",
                              "CelestialVisual.swift")
    model_text = open(model_path, encoding="utf-8").read() if \
        os.path.exists(model_path) else ""
    constants = {"MOON_SPHERE_GRADIENT_END_RADIUS":
                 R.MOON_SPHERE_GRADIENT_END_RADIUS}

    def resolve(factor):
        """Nilai sebuah pengali: literal dipakai apa adanya, konstanta
        diselesaikan. `None` bila tidak bisa ditentukan.

        **Konstanta diselesaikan dari sumber sisi masing-masing.** Nama Swift
        (`CelestialVisual.…`) dibaca dari `CelestialVisual.swift`; nama port
        dibaca dari nilai port. Ini yang membuat gerbang ini bukan sekadar
        perbandingan dirinya sendiri: kalau kedua sisi diselesaikan dari nilai
        port, model Swift bisa berubah tanpa ada yang melihatnya, dan
        perbandingan view-lawan-port akan hijau selamanya.
        """
        factor = factor.strip()
        if re.fullmatch(r"\d+\.\d+", factor):
            return float(factor)
        if factor in constants:
            return constants[factor]
        match = re.search(
            r"moonSphereGradientEndRadius:\s*Double\s*=\s*(\d+\.\d+)",
            model_text)
        if match and "moonSphereGradientEndRadius" in factor:
            return float(match.group(1))
        return None

    found = {"bola": [], "limb": []}
    for m in re.finditer(
            r"[Ee]nd_?[Rr]adius\s*[:=]\s*radius\s*\*\s*"
            r"(?:CGFloat\(\s*)?(?<![\w.])((?:[\w.]+)|\d+\.\d+)", body):
        # Jendela mundur dipakai karena di Swift `startRadius` dan
        # `endRadius` bisa terpisah baris (lihat `drawSphere`), sementara di
        # port Python keduanya sebaris. Jendela 260 karakter cukup untuk
        # keduanya dan tidak menjangkau gradien sebelumnya.
        window = body[max(0, m.start() - 260):m.start()]
        starts = re.findall(r"[Ss]tart_?[Rr]adius\s*[:=]\s*([^,\n)]+)", window)
        if not starts:
            continue
        start = starts[-1].strip()
        if re.fullmatch(r"radius\s*\*\s*0\.1", start):
            label = "bola"
        elif re.fullmatch(r"0(?:\.0)?", start):
            label = "limb"
        else:
            continue
        value = resolve(m.group(1))
        if value is not None:
            found[label].append(value)
    # Tidak melempar: daftar `checks` dibangun saat fungsi berjalan, dan
    # exception menggagalkan seluruh gerbang dengan traceback yang tidak
    # menyebut apa yang harus diperbaiki. Pola berkas ini: jangkar hilang
    # adalah **pemeriksaan merah yang menyebut jangkarnya**. Karena dua
    # gradien sekarang dibedakan secara struktural, `None` juga bisa
    # dilaporkan **per gradien**, bukan untuk seluruh sisi.
    #
    # Setiap label bisa punya **lebih dari satu** pemanggil: gradien limb
    # dipakai piringan Bulan **dan** pita terang planet dalam. Keduanya harus
    # sepakat — dua pemanggil dengan radius akhir yang berbeda adalah cacat
    # yang tidak terlihat di layar mana pun (dua benda yang digambar fungsi
    # yang sama lalu beredup berbeda). Karena itu yang dikembalikan bukan
    # nilai pertamanya, melainkan nilai **tunggal**nya: bila para pemanggil
    # berbeda pendapat, hasilnya `None` dan pemeriksaannya merah.
    out = {}
    for label, values in found.items():
        distinct = {round(v, 6) for v in values}
        out[label] = values[0] if len(distinct) == 1 else None
        out[label + "_count"] = len(values)
    return out


def check_gradient_end_radii_match(results):
    """Radius akhir gradien piringan harus sama di view Swift dan di port.

    **Kenapa gerbang ini, bukan daftar di `checks`.** Dua angka ini tidak
    punya konstanta di port, jadi `check_port_matches_swift_constants`
    tidak bisa menjangkaunya: ia membandingkan nilai konstanta bernama, dan
    `1.35`/`1.15` hidup sebagai literal di badan penggambar kedua bahasa.
    Menambahkannya ke `checks` berarti menulis ulang angkanya **ketiga**
    kalinya di dalam gerbang — menjadi entri yang tidak pernah dibandingkan
    dengan apa pun, persis kelas lubang yang seluruh berkas ini tutup.

    Tiga hal yang dijaga, dan tiap pemeriksaan menggigit pada keadaan yang
    berbeda:

    1. **Kedua sisi terbaca.** Jumlah gradien yang ditemukan view dan port
       harus sama. Kalau salah satu kehilangan satu gradien (mis. cabang
       berfase dihapus dari port), perbandingan nilai di bawah akan
       membandingkan dua hal yang bukan pasangannya.
    2. **Pasangannya cocok.** Gradien bola lawan bola, limb lawan limb —
       bukan "ada dua angka yang sama di kedua sisi".
    3. **Keduanya berbeda satu sama lain.** Kalau keduanya menjadi sama
       (`1.35` dan `1.35`, atau `1.15` dan `1.15`), salah satu dari dua
       gradien sudah kehilangan perannya; perbandingan himpunan apa pun akan
       tetap hijau pada keadaan itu, karena keduanya masih sama di kedua
       bahasa.

    Yang **tidak** diklaim: gerbang ini menjaga **kesamaan antar bahasa**,
    bukan bahwa 1.35/1.15 adalah angka yang benar. Tidak ada model di
    `PointingKit` untuk keduanya, jadi satu-satunya sumber kebenaran adalah
    kesepakatan kedua sisi itu sendiri — sama seperti rasio diameter/radius
    cakram bibir kawah yang batasnya sudah dicatat jujur di berkas ini.
    """
    view = open(os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift"),
                encoding="utf-8").read()
    port = open(R.SOURCE, encoding="utf-8").read()
    v = _gradient_end_factors(view)
    p = _gradient_end_factors(port)
    # Dilaporkan **per gradien**, bukan per sisi: kalau gradien limb hilang
    # dari port, yang harus muncul adalah "limb tidak terbaca di port
    # Python", bukan "kurang dari dua gradien". Nama yang salah pada
    # kegagalan mengirim orang ke tempat yang salah.
    for label in ("bola", "limb"):
        for where, factors in (("view Swift", v), ("port Python", p)):
            value = factors[label]
            count = factors.get(label + "_count", 0)
            # `None` bisa berarti dua hal, dan keduanya harus bisa dibedakan
            # dari pesannya: tidak ada gradien yang terbaca sama sekali, atau
            # ada **lebih dari satu** pemanggil yang tidak sepakat. Yang
            # kedua adalah cacat yang tidak terlihat di layar mana pun.
            if value is None and count > 1:
                detail = (f"{count} pemanggil ditemukan tetapi tidak sepakat "
                          "— gradien limb dipakai piringan Bulan **dan** pita "
                          "terang planet dalam, dan keduanya harus sama")
            else:
                detail = f"ditemukan {value if value is not None else 'tidak ada'}"
            results.append(Result(
                f"radius akhir gradien {label} terbaca di {where}",
                value is not None, detail))
    known = [label for label in ("bola", "limb")
             if v[label] is not None and p[label] is not None]
    for label in known:
        results.append(Result(
            f"radius akhir gradien {label} (view == port)", v[label] == p[label],
            f"view={v[label]}, port={p[label]}"))
    # Hanya berlaku kalau **kedua** gradien terbaca di kedua sisi: pembeda
    # dua gradien sekarang struktural, jadi kalau salah satunya hilang
    # pemeriksaan di atas sudah merah dan membandingkan yang tersisa dengan
    # dirinya sendiri tidak menambah apa pun.
    if len(known) == 2:
        results.append(Result(
            "dua gradien punya radius akhir yang berbeda", v["bola"] != v["limb"],
            f"bola={v['bola']}, limb={v['limb']}"))


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


def check_sun_corona_reaches_beyond_the_disk(results, size=256, ss=2):
    """Corona Matahari harus **bercahaya di luar** piringan, bukan disk tepi keras.

    **Cacat yang ditutup pemeriksaan ini.** Sebelum siklus ini, `sunProfile`
    memudar ke kelegapan 0.0 tepat di 1.0 R dan view memotong gradientnya ke
    piringan — jadi Matahari adalah disk terang dengan tepi yang habis ke
    latar secara tiba-tiba. Tidak ada glow sama sekali: diukur sepanjang
    radius, luminans mencapai latar persis di r = 1.0 R (r = 0.69 R setelah
    piringan menyusut untuk memberi ruang corona), dan nol di luar. Brief
    meminta "disk bercahaya **dengan corona**"; yang tampil malah disk polos.

    **Kenapa diukur di sini, bukan lewat uji model.** Model memang sudah punya
    `sunCoronaReach` (teruji di `testSunCoronaReachIsBeyondTheDisk`), tapi
    yang bisa mengunci bahwa view **benar-benar melukis halo itu** hanyalah
    piksel. View yang lupa menyusutkan piringan akan memotong corona oleh
    `Canvas` dan lolos semua uji model — persis cacat di atas.

    Diukur sebagai luminans rata-rata sepanjang cincin di luar piringan:
    antara tepi piringan (~0.72 R setelah penyusutan) dan tepi frame (1.0 R),
    gambar harus tetap lebih terang dari latar, lalu habis di ujungnya.
    """
    _, (w, h, rows) = render_case("sun", size=size, ss=ss)

    def lum(x, y):
        x = min(max(x, 0), w - 1)
        y = min(max(y, 0), h - 1)
        i = x * 4
        r, g, b = rows[y][i], rows[y][i + 1], rows[y][i + 2]
        return 0.299 * r + 0.587 * g + 0.114 * b

    cx = (w - 1) / 2
    cy = (h - 1) / 2
    radius = w / 2
    # Piringan menyusut oleh `sunCoronaReach` (1.45), jadi tepinya di
    # r_disk = radius / 1.45 ≈ 0.69 R. Corona berjalan dari situ ke radius.
    reach = R.SUN_CORONA_REACH
    r_disk = radius / reach

    def ring_lum(frac):
        f = frac * radius
        tot = 0.0
        n = 0
        for k in range(48):
            a = 2 * math.pi * k / 48
            x = int(round(cx + f * math.cos(a)))
            y = int(round(cy + f * math.sin(a)))
            if 0 <= x < w and 0 <= y < h:
                tot += lum(x, y)
                n += 1
        return tot / n if n else 0.0

    # Latar (10,10,15) ≈ 10.6 luminans. Ambang corona di tengah jangkauan:
    # harus jelas di atas latar, kalau tidak "corona" hanyalah sisa pudar
    # piringan yang tidak terbaca sebagai cahaya.
    mid = ring_lum(0.85)
    results.append(Result(
        "corona Matahari bercahaya di luar piringan",
        mid > 25,
        f"luminans cincin di 0.85 R = {mid:.1f} (harus > 25; latar ≈ 10.6)"))

    # Dan corona harus benar-benar habis di tepi luar (1.0 R) — bukan
    # membanjiri frame. Kalau > latar di sini, piringan tidak menyusut dan
    # `Canvas` memotongnya; itu cacat penyusutan, bukan corona.
    outer = ring_lum(0.99)
    results.append(Result(
        "corona Matahari habis di tepi frame (tidak menabrak bingkai)",
        outer < 30,
        f"luminans di 0.99 R = {outer:.1f} (harus kembali mendekati latar)"))

    # Jangkauan corona harus melewati piringan: cincin di luar piringan
    # (0.85 R) harus jelas lebih terang dari latar — ia bercahaya, bukan
    # sekadar sisa pudar yang tak terbaca. (Puncak corona ada di limb 0.69 R,
    # jadi 0.85 R wajar lebih redup dari limb; yang diuji di sini adalah
    # "masih bercahaya di luar piringan", bukan "lebih terang dari limb".)
    bg = ring_lum(0.99)
    results.append(Result(
        "corona lebih lebar dari piringan (masih bercahaya di luar)",
        mid > bg + 20,
        f"0.85R={mid:.1f} jauh di atas latar 0.99R={bg:.1f}"))


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
    tanya), jadi seluruh frame adil untuk dibandingkan.

    **Ambang "berbeda" bukan nol.** Versi sebelumnya menuntut `diff > 0` —
    satu piksel berbeda sudah hijau. Gerbang yang begitu tidak bisa gagal:
    menggeser satu bentuk satu piksel pun lolos, jadi ia mengukur "ada
    sesuatu di layar", bukan "bentuknya berbeda". Ambangnya sekarang proporsi
    piksel yang benar-benar berbeda, dan angkanya dinaikkan sampai tepat di
    bawah nilai yang dihasilkan gambar sekarang (lihat `MIN_MORPHOLOGY_DIFF`)
    — cukup ketat untuk menangkap penyorotan ke satu bentuk, cukup longgar
    untuk tidak merah karena anti-aliasing.

    **Warna, bukan hanya bentuk.** Bentuk bisa berbeda sementara seluruh
    kabut tetap satu warna — itu keadaan sebelum siklus ini: keenam morfologi
    berhue 0.636-0.642. Karena itu warna rata-rata tiap morfologi
    dibandingkan dengan kabut netral di kanal warna (bukan hue: hue tidak
    terdefinisi untuk warna hampir netral).

    **Dua arah sekaligus.** Tanpa arah sebaliknya (setiap morfologi terkunci
    berbeda dari kabut netral), view yang menyoroti *semua* ke kabut netral
    akan lolos pemeriksaan pasangan di atas — keempatnya sama-sama netral,
    jadi pasangan mana pun juga bertepatan.
    """
    names = [c.name for c in R.build_cases()
             if c.name.startswith("deepsky-")
             and c.name not in ("deepsky-uncertain", "deepsky-unknown-id")]
    rendered = {name: render_case(name, size=size, ss=ss) for name in names}

    # Setiap pasang berbeda — diukur sebagai proporsi piksel, bukan > 0.
    total = size * size
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            _, (w1, h1, rows_a) = rendered[names[i]]
            _, (_, _, rows_b) = rendered[names[j]]
            diff = sum(1 for y in range(h1)
                       for x in range(w1)
                       if rows_a[y][x * 4:x * 4 + 3] != rows_b[y][x * 4:x * 4 + 3])
            fraction = diff / total
            results.append(Result(
                f"morfologi berbeda: {names[i]} vs {names[j]}",
                fraction >= MIN_MORPHOLOGY_DIFF,
                f"{diff} piksel ({fraction:.1%}) berbeda; ambang "
                f"{MIN_MORPHOLOGY_DIFF:.0%} (kalau ~0, kedua bentuk sama di layar)"))

    # Setiap morfologi terkunci berbeda dari kabut netral.
    _, (w0, h0, rows_neutral) = render_case("deepsky-unknown-id",
                                            size=size, ss=ss)
    for name in names:
        _, (_, _, rows_m) = rendered[name]
        diff = sum(1 for y in range(h0)
                   for x in range(w0)
                   if rows_m[y][x * 4:x * 4 + 3] != rows_neutral[y][x * 4:x * 4 + 3])
        fraction = diff / total
        results.append(Result(
            f"{name} berbeda dari kabut netral",
            fraction >= MIN_MORPHOLOGY_DIFF,
            f"{diff} piksel ({fraction:.1%}) berbeda dari kabut netral; ambang "
            f"{MIN_MORPHOLOGY_DIFF:.0%}"))

    # Dan warnanya — arah yang tidak terlihat oleh perbandingan piksel di atas.
    neutral_hue_rgb = brightest_colour(rows_neutral, w0, h0)
    if neutral_hue_rgb is None:
        results.append(Result("warna kabut netral terbaca", False,
                              "kabut netral tidak punya piksel terlihat"))
        return
    for name in names:
        _, (w, h, rows) = rendered[name]
        colour = brightest_colour(rows, w, h)
        if colour is None:
            results.append(Result(f"warna {name} berbeda dari kabut netral",
                                  False, "tidak ada piksel terlihat"))
            continue
        distance = max(abs(a - b) for a, b in zip(colour, neutral_hue_rgb))
        results.append(Result(
            f"warna {name} berbeda dari kabut netral",
            distance >= MIN_DEEP_SKY_COLOUR_DIFF,
            f"jarak kanal {distance:.3f} (rata-rata {_rgb_text(colour)} vs "
            f"netral {_rgb_text(neutral_hue_rgb)}); ambang "
            f"{MIN_DEEP_SKY_COLOUR_DIFF:.2f}"))

    # Dan antar **morfologi** — supaya tidak ada dua yang bertabrakan.
    #
    # Yang dibandingkan adalah **satu wakil per morfologi**, bukan setiap
    # kasus. Warna mengodekan **jenis** objek, dan sejak M27/M57 masuk sebagai
    # kasus render sendiri (`deepsky-m27`, `deepsky-m57`) ketiganya sengaja
    # berwarna sama: ketiganya nebula planetari. Yang membedakan M27 dari M57
    # adalah **bentuk** (sudut pandang), bukan rona — dan itu diukur gerbang
    # siluetnya (`check_dumbbell_nebula_is_an_elongated_shell`), bukan di sini.
    # Membandingkan setiap kasus akan menuntut warna berbeda untuk objek yang
    # **sama jenisnya**, dan satu-satunya cara memenuhinya adalah mengarang
    # rona yang tidak ada di langit.
    #
    # Wakilnya diambil dari nama kasus `deepsky-<morfologi>` — kasus per
    # morfologi yang sudah ada — bukan daftar tangan: morfologi baru yang
    # ditambahkan ke `build_cases()` otomatis ikut diukur.
    representative = {}
    for case in R.build_cases():
        if not case.name.startswith("deepsky-"):
            continue
        morph = case.kw.get("morphology")
        if morph is None:
            continue
        if morph not in representative or case.name == f"deepsky-{morph}":
            representative[morph] = case.name
    morph_names = sorted(representative)
    measured = {}
    for morph in morph_names:
        _, (w, h, rows) = rendered[representative[morph]]
        measured[morph] = (representative[morph], brightest_colour(rows, w, h))
    for i in range(len(morph_names)):
        for j in range(i + 1, len(morph_names)):
            name_a, a = measured[morph_names[i]]
            name_b, b = measured[morph_names[j]]
            if a is None or b is None:
                continue
            distance = max(abs(x - y) for x, y in zip(a, b))
            results.append(Result(
                f"warna berbeda: {morph_names[i]} vs {morph_names[j]}",
                distance >= MIN_DEEP_SKY_COLOUR_DIFF,
                f"jarak kanal {distance:.3f} ({name_a} vs {name_b}; ambang "
                f"{MIN_DEEP_SKY_COLOUR_DIFF:.2f})"))


def check_earthshine(results, size=200, ss=2):
    """Sisi gelap Bulan sabit harus bercahaya samar (earthshine), bukan hitam.

    Cahaya ini dipantulkan Bumi, jadi sisi gelap bulan sabit tampak redup tapi
    tidak hitam — berbeda dengan planet dalam yang sisinya gelap praktis
    hitam. Pemeriksaan ini mengukur luminans rata-rata sisi gelap sebuah sabit
    dan membandingkannya dengan luminans token `moonUnlit` (piringan gelap
    tanpa earthshine). Earthshine harus **menaikkan** sisi gelap sabit di atas
    `moonUnlit`, dan harus **meredup** saat mendekati purnama.

    Rasio yang dicari longgar: yang dicegah adalah cacat "earthshine tidak
    pernah digambar" (sisi gelap sabit = hitam rata) maupun "earthshine
    menyala penuh" (sabit terbaca sebagai piringan terang).
    """
    lit, unlit = moon_colors()
    # Luminans piringan gelap Bulan (token `moonUnlit`), rujukan tanpa
    # earthshine. Earthshine harus **menaikkan** sisi gelap sabit di atas ini.
    unlit_lum = 0.2126 * unlit[0] + 0.7152 * unlit[1] + 0.0722 * unlit[2]

    def dark_side_luminance(illumination, angle, night=False):
        name = f"__es-{int(illumination * 100)}-{int(night)}"
        case = R.VisualCase(name, "sementara", "moon",
                            illumination=illumination, is_waxing=True,
                            bright_limb_angle=angle, is_confirmed=True)
        canvas = R.render(case, size=size, night_mode=night, show_frame=False, ss=ss)
        path = os.path.join(R.OUT_DIR, f"{name}.png")
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        w, h, rows = decode_png(path)
        # Sisi gelap = belahan yang **tidak** menghadap Matahari. Untuk sabit
        # waxing sisi terang ada di kanan (angle=0). Sisi gelap selalu di
        # kiri, dan tepinya paling kiri (dekat x=0) tetap gelap untuk **setiap**
        # fase (0<f<1): sabit (f<0.5) gelapnya mayoritas kiri, cembung (f>0.5)
        # gelapnya hanya sliver kiri tipis. Jadi hanya sampling sliver jauh
        # kiri (x < cx - 0.75*radius) yang pasti gelap di semua fase, sehingga
        # perbandingan "sabit tipis vs cembung" tidak tercemar piksel menyala.
        cx = w / 2.0
        threshold = cx - 0.75 * (w / 2.0)
        tot, n = 0.0, 0
        for y in range(0, h, 2):
            for x in range(0, int(threshold), 2):
                if math.hypot(x - cx, y - h / 2) > cx:
                    continue
                r, g, b = rows[y][x * 4:x * 4 + 3]
                tot += (0.2126 * r + 0.7152 * g + 0.0722 * b)
                n += 1
        os.remove(path)
        return tot / max(1, n)

    crescent_dark = dark_side_luminance(0.15, 0.0)
    results.append(Result(
        "earthshine: sisi gelap sabit lebih terang dari piringan gelap",
        crescent_dark > unlit_lum + 1.0,
        f"sabit f=0.15: {crescent_dark:.1f}, moonUnlit: {unlit_lum:.1f} "
        f"(0-255 luminans rata-rata sisi gelap)"))

    # Earthshine meredup saat mendekati purnama: sabit tipis (f=0.15) punya
    # sisi gelap lebih luas → earthshine lebih kuat daripada celah (f=0.85).
    gibbous_dark = dark_side_luminance(0.85, 0.0)
    results.append(Result(
        "earthshine: lebih kuat pada sabit tipis daripada celah",
        gibbous_dark < crescent_dark,
        f"sabit f=0.15: {crescent_dark:.1f}, f=0.85: {gibbous_dark:.1f}"))

    # ── Mode malam ─────────────────────────────────────────────────────────
    #
    # Earthshine adalah bagian yang **tidak memancarkan** cahaya: ia memantulkan
    # cahaya Bumi. Jadi di mode malam ia mengikuti aturan `shadow`, bukan
    # `surface` — persis seperti piringan gelap `moonUnlit` di sebelahnya.
    #
    # Bagian ini sebelumnya tidak ada, dan kekosongannya itulah yang membuat
    # earthshine bisa enam kali terlalu terang tanpa satu pun alarm: gerbang
    # ini merender dengan `night_mode=False` saja, jadi jalur malam tak
    # pernah diukur; `check_night_mode_purity` yang merender malam hanya
    # menyapu hijau/biru; dan kanal merah yang dinaikkan `surface` tetap
    # merah murni, jadi ia lolos dari penyapuan itu. Dua gerbang, dua
    # butiran yang saling menutupi — bukan dua gerbang yang saling menguatkan.
    # ── Mode malam ─────────────────────────────────────────────────────────
    #
    # Earthshine adalah bagian yang **tidak memancarkan** cahaya: ia memantulkan
    # cahaya Bumi. Jadi di mode malam ia mengikuti aturan `shadow`, bukan
    # `surface` — persis seperti piringan gelap `moonUnlit` di sebelahnya.
    #
    # Bagian ini sebelumnya tidak ada, dan kekosongannya itulah yang membuat
    # earthshine bisa terlalu terang tanpa satu pun alarm: gerbang ini
    # merender dengan `night_mode=False` saja, jadi jalur malam tak pernah
    # diukur; `check_night_mode_purity` yang merender malam hanya menyapu
    # hijau/biru; dan kanal merah yang dinaikkan `surface` tetap merah
    # murni, jadi ia lolos dari penyapuan itu. Dua gerbang, dua butiran yang
    # saling menutupi — bukan dua gerbang yang saling menguatkan.
    #
    # **Invarian yang dipakai: rasio, bukan angka.** Versi pertama membandingkan
    # luminans **terukur** sisi gelap dengan luminans **analitik** token
    # `night_shadow(moonUnlit)` (3.5). Itu dua besaran berbeda: di antara
    # keduanya ada komposit dan tekstur, jadi hasilnya meleset ~17 poin —
    # dan ambangnya jadi 4.5 terhadap nilai terukur 4.0, hanya 0.5 margin.
    # Versi ini membandingkan **dua render** dari penyampel yang sama: sisi
    # gelap dan sisi terang piringan yang sama. Tidak ada konstanta karangan.
    #
    # Dan bentuk pertanyaannya fisis: earthshine adalah pantulan, bukan emisi,
    # jadi mode malam **tidak boleh** menaikkan rasio gelap/terang di atas
    # apa yang siang sudah tunjukkan. Angka di docstring ini diukur oleh
    # penyampel yang sama (`side_luminance` di bawah), bukan dikutip:
    #
    #     rasio malam, keadaan benar : 20.25 %
    #     rasio siang                : 36.28 %
    #     rasio malam, cacat surface : 66.93 %
    #
    # Ketiganya diukur pada 200 px, sliver `x < cx - 0.75R` untuk sisi gelap
    # dan `x > cx` untuk sisi terang, cincin 0.55 R…0.92 R (di luar pita
    # maria, di dalam limb). Ambang mutlak 45 % ligger di tengah antara
    # siang (36,28) dan cacat (66,93) — penutup kalau rasio siang ikut
    # berubah, karena invarian perbandingan tidak boleh sendirian.
    def side_luminance(illumination, night, lit_side):
        name = f"__esr-{int(illumination * 100)}-{int(night)}-{int(lit_side)}"
        case = R.VisualCase(name, "sementara", "moon",
                            illumination=illumination, is_waxing=True,
                            bright_limb_angle=0.0, is_confirmed=True)
        canvas = R.render(case, size=size, night_mode=night, show_frame=False, ss=ss)
        path = os.path.join(R.OUT_DIR, f"{name}.png")
        with open(path, "wb") as handle:
            handle.write(canvas.to_png())
        w, h, rows = decode_png(path)
        os.remove(path)
        cx, cy, radius = w / 2.0, h / 2.0, w / 2.0
        tot, n = 0.0, 0
        for y in range(0, h, 2):
            for x in range(0, w, 2):
                d = math.hypot(x - cx, y - cy)
                if d > radius * 0.92 or d < radius * 0.55:
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

    def dark_lit_ratio(night):
        dark = side_luminance(0.15, night, lit_side=False)
        lit = side_luminance(0.15, night, lit_side=True)
        return dark / lit * 100.0, dark, lit

    night_ratio, night_dark, night_lit = dark_lit_ratio(True)
    day_ratio, day_dark, day_lit = dark_lit_ratio(False)
    results.append(Result(
        "earthshine malam: rasio gelap/terang tidak melebihi siang",
        night_ratio <= day_ratio,
        f"malam {night_ratio:.2f}% (gelap {night_dark:.1f} / terang {night_lit:.1f}), "
        f"siang {day_ratio:.2f}% (gelap {day_dark:.1f} / terang {day_lit:.1f})"))
    results.append(Result(
        "earthshine malam: rasio gelap/terang di bawah plafon mutlak",
        night_ratio <= 45.0,
        f"malam {night_ratio:.2f}%, plafon 45% (siang {day_ratio:.2f}%, "
        f"cacat surface 66.93%)"))

    # Dan earthshine di malam tetap punya arah: tetap meredup mendekati
    # purnama. Tanpa pemeriksaan ini earthshine bisa hilang sepenuhnya di mode
    # malam — lampu mati, bukan "terang tak perlu". Marginnya memang tipis
    # (4.0 vs 3.6, karena tekstur piringan menutupi sebagian earthshine), dan
    # angka itu diukur oleh `dark_side_luminance` yang sama dengan bagian
    # siang, jadi keduanya tidak bisa berhenti sepakat tanpa ada yang tahu.
    gibbous_night = dark_side_luminance(0.85, 0.0, night=True)
    results.append(Result(
        "earthshine malam: meredup mendekati purnama",
        gibbous_night < night_dark,
        f"sabit malam f=0.15: {night_dark:.1f}, f=0.85: {gibbous_night:.1f}"))


def _rebound_between(func, loop, call, name):
    """Apakah `name` ditugaskan ulang antara akhir `loop` dan `call`."""
    loop_end = loop.end_lineno or loop.lineno
    for node in ast.walk(func):
        if not isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign,
                                 ast.For)):
            continue
        if not (loop_end < node.lineno < call.lineno):
            continue
        if isinstance(node, ast.Assign):
            names = [t.id for t in node.targets if isinstance(t, ast.Name)]
        elif isinstance(node, ast.For):
            names = [t.id for t in ast.walk(node.target)
                     if isinstance(t, ast.Name)]
        else:
            names = [node.target.id] if isinstance(node.target, ast.Name) else []
        if name in names:
            return True
    return False


def _bound_by_comprehension(func, call, name):
    """Apakah `call` berada di dalam pemahaman yang sendiri mengikat `name`.

    `[i for i in probes]` memakai nama yang sama dengan gelung luar tanpa
    mewarisi nilainya — pemahaman punya lingkupnya sendiri, jadi ini bukan
    kebocoran. Dibedakan lewat AST, bukan lewat bentuk barisnya.
    """
    for node in ast.walk(func):
        if not isinstance(node, (ast.ListComp, ast.SetComp, ast.DictComp,
                                 ast.GeneratorExp)):
            continue
        inside = ((node.lineno, node.col_offset) <= (call.lineno, call.col_offset)
                  and (call.end_lineno, call.end_col_offset)
                  <= (node.end_lineno, node.end_col_offset))
        if not inside:
            continue
        for gen in node.generators:
            if name in {t.id for t in ast.walk(gen.target)
                        if isinstance(t, ast.Name)}:
                return True
    return False


#: Fungsi yang boleh memakai variabel gelung setelah gelungnya.
#:
#: Kosong, dan itu disengaja: satu-satunya cara menambah pengecualian adalah
#: menulis alasannya di sini, tempat orang berikutnya bisa membacanya.
LOOP_LEAK_ALLOWED = {}


def check_no_loop_variable_leaks_into_a_call(results):
    """Variabel gelung tidak boleh dipakai sebagai argumen setelah gelungnya.

    **Cacat yang ditutup pemeriksaan ini.**
    `check_dumbbell_nebula_is_an_elongated_shell` mengukur siluet M27 dan M57
    di dalam satu gelung `for case_name, label in (...)`, lalu **setelah**
    gelung memanggil `nebula_centre_and_shell(case_name, ...)` untuk memeriksa
    rongga. Setelah gelung, `case_name` bernilai `deepsky-m57` — jadi
    pemeriksaan berlabel "cangkang M27 tetap berongga di tengah" mengukur pusat
    **M57**. Ia hijau pada kode yang benar *dan* pada cacat yang seharusnya
    ditangkapnya (memipihkan posisi tanpa memipihkan tinggi: pusat M27 terisi
    0.571 pada 76 px, ambang 0.25).

    Itu bentuk kegagalan yang paling mahal di berkas ini: bukan merah pada kode
    yang benar, melainkan **hijau pada kode yang salah** — dan namanya tetap
    berbunyi seperti yang diperiksa.

    **Yang dicari**: variabel target `for` yang muncul sebagai argumen sebuah
    panggilan setelah gelungnya berakhir, tanpa penugasan ulang di antaranya.
    Penugasan ulang dikecualikan karena itu memang cara yang benar memakai nama
    yang sama dua kali — `check_deep_sky_shape_suppression` menugaskan ulang
    `morphology` di gelung keduanya, dan tanpa pengecualian ini gerbangnya akan
    merah pada kode yang benar.

    **Batas yang dinyatakan.** Analisis ini tidak mengikuti aliran lewat
    struktur data: `rows = {}` yang diisi di dalam gelung lalu dibaca sebagai
    `rows[key]` **tidak** tertangkap, begitu pula variabel yang dikembalikan
    dari sebuah fungsi. Yang dijaga adalah bentuk yang benar-benar terjadi di
    berkas ini — dan setiap pengecualian di `LOOP_LEAK_ALLOWED` kosong.
    """
    with open(__file__) as handle:
        source = handle.read()
    tree = ast.parse(source)
    leaks = []
    for func in ast.walk(tree):
        if not isinstance(func, ast.FunctionDef):
            continue
        if func.name in LOOP_LEAK_ALLOWED:
            continue
        for loop in ast.walk(func):
            if not isinstance(loop, ast.For):
                continue
            targets = {t.id for t in ast.walk(loop.target)
                       if isinstance(t, ast.Name)}
            if not targets:
                continue
            for call in ast.walk(func):
                if not isinstance(call, ast.Call):
                    continue
                if call.lineno <= (loop.end_lineno or loop.lineno):
                    continue
                for arg in call.args:
                    if not (isinstance(arg, ast.Name) and arg.id in targets):
                        continue
                    if _bound_by_comprehension(func, call, arg.id):
                        continue
                    if _rebound_between(func, loop, call, arg.id):
                        continue
                    leaks.append(f"{func.name}: '{arg.id}' dari gelung baris "
                                 f"{loop.lineno} dipakai lagi di baris "
                                 f"{arg.lineno}")
    results.append(Result(
        "tidak ada variabel gelung yang bocor ke pemeriksaan lain",
        not leaks,
        "; ".join(leaks) if leaks
        else f"{len(LOOP_LEAK_ALLOWED)} pengecualian, tidak ada yang bocor"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="keluar != 0 bila ada pemeriksaan yang gagal")
    parser.add_argument("--size", type=int, default=200)
    parser.add_argument("--ss", type=int, default=2)
    args = parser.parse_args()

    os.makedirs(R.OUT_DIR, exist_ok=True)
    results = []
    check_gradient_end_radii_match(results)
    check_moon_phase_fraction(results, args.size, args.ss)
    check_crescent_direction(results, args.size, args.ss)
    check_features_disappear_when_uncertain(results, args.size, args.ss)
    check_planet_features_present(results, args.size, args.ss)
    check_inner_planet_phase(results, args.size, args.ss)
    check_phase_direction_on_the_waning_half(results, args.size, args.ss)
    check_saturn_ring_bands_render(results, args.size, args.ss)
    check_saturn_gap_reads_at_the_watch_size(results)
    check_spiral_arms_stay_continuous(results)
    check_planetary_nebula_shell_is_continuous(results)
    check_dumbbell_nebula_is_an_elongated_shell(results)
    check_spiral_core_reads_as_one_body(results)
    check_spiral_core_docstring_quotes_measured_values(results)
    check_moon_phase_survives_uncertainty(results, args.size, args.ss)
    check_earthshine(results, args.size, args.ss)
    check_unknown_phase_is_not_a_new_moon(results, args.size, args.ss)
    check_feature_arrays_match_the_view(results)
    check_features_survive_the_watch_size(results)
    check_every_planet_in_the_model_has_render_cases(results)
    check_crater_drawing_constants(results)
    check_sun_profile_matches_the_model(results)
    check_crater_relief_matches_the_model(results)
    check_crater_floor_opacity_comes_from_the_model(results)
    check_crater_contrast_numbers_come_from_the_sampler(results)
    check_unknown_moon_disc_uses_the_token(results)
    check_candidate_marker_stays_inside_its_badge(results, args.size, args.ss)
    check_jupiter_bands_reach_the_limb(results, args.size, args.ss)
    check_bands_follow_the_limb_arc(results, args.size, args.ss)
    check_banded_disc_keeps_its_curvature(results, args.size, args.ss)
    check_jupiter_spot_keeps_its_curvature(results, args.size, args.ss)
    check_moon_disc_keeps_its_curvature(results, args.size, args.ss)
    check_planet_phase_limb_reads_the_model_constant(results)
    check_moon_new_disc_reads_on_the_watch(results)
    check_mars_caps_touch_the_limb(results)
    check_sun_edge_is_soft(results)
    check_sun_corona_reaches_beyond_the_disk(results)
    check_png_is_well_formed(results)
    check_png_roundtrip(results)
    check_port_matches_swift_constants(results)
    check_port_constants_reach_the_drawing(results)
    check_night_mode_purity(results, args.size, args.ss)
    check_night_mode_never_exceeds_day(results, 120, args.ss)
    check_star_colour_order(results, args.size, args.ss)
    check_star_size_follows_magnitude(results)
    check_star_colour_not_a_claim_when_uncertain(results, args.size, args.ss)
    check_deep_sky_morphologies_render_distinct(results, args.size, args.ss)
    check_deep_sky_catalogue_values_reach_the_picture(results)
    check_deep_sky_layouts_match_the_model(results)
    check_every_morphology_in_the_model_has_render_cases(results)
    check_star_colour_index_matches_the_model(results)
    check_star_rgb_conversion_matches_the_model(results)
    check_night_accents_match_the_model(results)
    check_night_accents_reach_the_view(results)
    check_star_geometry_matches_the_model(results)
    check_magnitude_scale_matches_the_model(results)
    # Terakhir, dan atas berkasnya sendiri: kelas cacat yang membuat pemeriksaan
    # di atas bisa hijau karena alasan yang salah.
    check_no_loop_variable_leaks_into_a_call(results)

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
