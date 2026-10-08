#!/usr/bin/env python3
"""Buktikan dua gerbang bintik Jupiter **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Siklus ini menutup satu kelas cacat yang sudah berulang di repo ini: ciri
permukaan digambar **rata** di atas bola yang sudah dinaungi gradien, jadi ia
menghapus lengkung bola di dalamnya. Untuk pita, cacat itu sudah dijaga
`check_banded_disc_keeps_its_curvature` — tetapi gerbang itu mengukur **baris
ekuator**, dan Bintik Merah Besar duduk di `centerY = +0.31`. Jadi bintiknya
punya lubang yang **sama** dengan pita, satu lapis lebih dalam.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah. Dua gerbang diuji di sini:

  A. `check_jupiter_spot_keeps_its_curvature`  — pemeriksaan **piksel**
  B. `check_port_matches_swift_constants`      — pemeriksaan **teks** (tiga
     entri baru di dalamnya, bukan seluruh tabelnya)

Keduanya dipanggil lewat jalur yang **sama** dengan gerbang penuh, tetapi hanya
atas pemeriksaan itu saja, jadi harness berjalan dalam hitungan detik alih-alih
~6 menit. Gerbang yang terlalu lambat untuk dijalankan adalah gerbang yang
dilewati.

Keadaan yang diuji (semuanya **harus merah**, kecuali baseline):

  A1. kekuatan 0.6 -> 0.0        cacat aslinya: bintik rata lagi
  A2. kekuatan 0.6 -> 1.0        berlebihan: bintiknya tertutup bola
  A3. bintiknya tidak digambar   hanya pemulihannya yang tersisa
  B1. port 0.6 -> 0.9            drift port vs model
  B2. view menulis 0.6 langsung  view berhenti membaca konstanta model
  B3. model 0.6 -> 0.4           drift model vs port

A3 dan A2 **terukur memberi angka yang sama** (0.14% / 0.20% penyimpangan) untuk
alasan yang berbeda: A2 menutup bintiknya dengan gradien bola, A3 tidak
menggambarnya sama sekali — keduanya meninggalkan piringan yang praktis polos.
Keduanya tetap diuji karena keduanya keadaan yang berbeda di dalam kode.

**Keadaan yang sengaja TIDAK ada di sini: "`clip_ellipse` dihapus".** Percobaan
pertama siklus ini menambahkan parameter `clip_ellipse` ke `Canvas.ellipse`,
dan keadaan itu diharapkan merah. Terukur lewat `out/ukur-klip.py`: menghapusnya
mengubah **0 piksel**, di dalam maupun di luar elips bintik — karena
`Canvas.ellipse` sudah membatasi diri ke bentuk elipsnya, jadi klip kedua ke
elips yang **sama persis** tidak melakukan apa pun. Itu bukan keadaan yang
"lolos dari gerbang"; itu **kode mati**, dan parameternya sudah dihapus dari
port. Harapan yang menuntut merah di sana akan menuntut gerbang berbunyi tanpa
alasan — bentuk kegagalan yang paling sulit terlihat karena tampak seperti
ketaatan. (Di view Swift klipnya memang perlu dan tetap ada: di sana
`GraphicsContext.clip` yang memotong **gradien** ke elips.)

Berkas sumber produksi (`Tools/render-visuals.py`,
`Apps/Shared/CelestialVisualView.swift`,
`Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift`) **dimutasi
dengan sengaja** lalu dipulihkan di `finally` per keadaan. Kegagalan di tengah
tidak boleh meninggalkan mutasi hidup — pelajaran yang sudah dibayar di repo ini
(`SIGKILL` melewati `finally`, jadi ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-bintik.py
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
#
# Keluarannya **disaring** ke nama pemeriksaan yang diuji: seluruh tabel
# `check_port_matches_swift_constants` punya ~200 entri, dan menggemukannya ke
# layar justru menyembunyikan yang penting.
PROBE = r"""
import importlib.util, os, sys
ROOT = sys.argv[1]

def load(name, filename):
    path = os.path.join(ROOT, "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")

WANTED = {
    "Bintik Merah Besar tetap melengkung (bukan stiker rata)",
    "bintik Jupiter masih terbaca setelah pemulihan lengkung",
    # Tabel `check_port_matches_swift_constants` memancarkan **dua** hasil per
    # entri, dengan awalan yang berbeda; keduanya diperiksa supaya arah drift
    # (port vs model) dan arah "sumber memuat" tidak bisa lolos bersama-sama.
    "port sejalan: kekuatan pemulihan limb di atas bintik",
    "sumber memuat: kekuatan pemulihan limb di atas bintik",
    "port sejalan: pemulihan limb bintik dipanggil di view (bukan ditulis ulang)",
    "sumber memuat: pemulihan limb bintik dipanggil di view (bukan ditulis ulang)",
    "port sejalan: port memakai konstanta JUPITER_SPOT_LIMB_SHADING_STRENGTH-nya sendiri",
    "sumber memuat: port memakai konstanta JUPITER_SPOT_LIMB_SHADING_STRENGTH-nya sendiri",
}

results = []
C.check_jupiter_spot_keeps_its_curvature(results)
C.check_port_matches_swift_constants(results)
found = 0
for r in results:
    if r.name in WANTED:
        found += 1
        print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  ::  " + r.detail)
print("DIPERIKSA " + str(found) + "/" + str(len(WANTED)))
"""

# (nama keadaan, {berkas: (cari, ganti)}) — `None` berarti jalankan apa adanya.
STATES = [
    ("[baseline]", None),
    ("A1. kekuatan 0.6 -> 0.0 (bintik rata lagi)", {
        RENDER: ("JUPITER_SPOT_LIMB_SHADING_STRENGTH = 0.6",
                 "JUPITER_SPOT_LIMB_SHADING_STRENGTH = 0.0")}),
    ("A2. kekuatan 0.6 -> 1.0 (bintik tertutup bola)", {
        RENDER: ("JUPITER_SPOT_LIMB_SHADING_STRENGTH = 0.6",
                 "JUPITER_SPOT_LIMB_SHADING_STRENGTH = 1.0")}),
    ("A3. bintiknya tidak digambar (hanya pemulihannya)", {
        RENDER: ("""    canvas.ellipse(spot_cx, spot_cy, spot_rx, spot_ry,
                   accent_fn(ACCENTS["jupiterSpot"], night_mode))""",
                 """    _spot_dropped = accent_fn(ACCENTS["jupiterSpot"], night_mode)""")}),
    ("B1. port 0.6 -> 0.9 (drift port vs model)", {
        RENDER: ("JUPITER_SPOT_LIMB_SHADING_STRENGTH = 0.6",
                 "JUPITER_SPOT_LIMB_SHADING_STRENGTH = 0.9")}),
    ("B2. view menulis 0.6 langsung (berhenti membaca model)", {
        VIEW: ("opacity: CelestialVisual.jupiterSpotLimbShadingStrength",
               "opacity: 0.6")}),
    ("B3. model 0.6 -> 0.4 (drift model vs port)", {
        MODEL: ("jupiterSpotLimbShadingStrength: Double = 0.6",
                "jupiterSpotLimbShadingStrength: Double = 0.4")}),
]

_original = {}


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber` (tulis atomik + verifikasi pemulihan), bukan
    `open(path, "w")`: harness ini dan enam saudaranya memutasi berkas
    produksi yang sama dan setiap prob membacanya dari proses baru.
    """
    for path, content in _original.items():
        mutasi_sumber.restore_verified(path, content)


def probe():
    """Jalankan pemeriksaan langsung → (daftar_gagal, galat)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        error = (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
        return [], error
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    return [line for line in lines if line.startswith("GAGAL")], None


def main():
    mutasi_sumber.require_clean_sources([RENDER, VIEW, MODEL])
    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    for path in (RENDER, VIEW, MODEL):
        with open(path, encoding="utf-8") as handle:
            _original[path] = handle.read()

    unexpected = 0
    try:
        for label, mutations in STATES:
            # Selalu mulai dari sumber asli: keadaan sebelumnya tidak boleh
            # menumpuk di keadaan berikutnya.
            for path, content in _original.items():
                mutasi_sumber.restore_verified(path, content)

            if mutations is not None:
                missing = []
                for path, (old, new) in mutations.items():
                    content = _original[path].replace(old, new, 1)
                    if old not in _original[path]:
                        missing.append(f"{os.path.basename(path)}: {old[:50]!r}")
                        continue
                    mutasi_sumber.write_source(path, content)
                if missing:
                    print(f"{label:52s} ANCHOR TIDAK DITEMUKAN: {'; '.join(missing)}")
                    unexpected += 1
                    continue

            failed, error = probe()
            if error is not None:
                print(f"{label:52s} PROBE GAGAL JALAN: {error}")
                unexpected += 1
                continue

            count = len(failed)
            want_red = mutations is not None
            mark = "OK  " if (count > 0) == want_red else "SALAH"
            if mark == "SALAH":
                unexpected += 1
            detail = f"{count} pemeriksaan merah" if count else "0 merah"
            print(f"{mark} {label:52s} {detail}")
            for line in failed:
                print(f"       {line}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
