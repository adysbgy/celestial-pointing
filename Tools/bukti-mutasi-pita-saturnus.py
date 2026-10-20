#!/usr/bin/env python3
"""Buktikan gerbang pita Saturnus berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

`check_saturn_globe_is_banded` lahir dari klaim tanpa gerbang: uji Swift
menyebut nama itu, tetapi `grep` di `Tools/check-visuals.py` menemukan **nol**
kemunculan. Bola Saturnus memang berpita di port, tetapi tidak ada satu pun
pemeriksaan yang bisa memerah kalau pitanya dihapus. Gerbang yang lahir dari
riwayat seperti itu wajib dibuktikan bisa gagal, karena bentuk kegagalannya
paling mudah: hijau karena tidak ada yang diukur.

Tiga arah yang diuji, semuanya mutasi pada sumber produksi
(`Tools/render-visuals.py`):

  [baseline]                     semua hijau (kalau tidak, harness salah)
  1. pita Saturnus tidak digambar
                                 `_draw_saturn_bands` dilewati. Gerbang pita
                                 **merah** di kedua mode. Ini arah yang
                                 membuktikan gerbangnya menyentuh gambar.
  2. nada pita diseragamkan       `SATURN_BAND_TONES` menjadi satu warna.
                                 Gerbang pita **merah** (pita tidak lagi
                                 terbedakan), gerbang nada **merah**. Arah
                                 yang membuktikan residual-nya datang dari
                                 **nada**, bukan dari lengkung bola — bola
                                 polos memberi residual nol.
  3. opasitas dinaikkan ke Jupiter
                                 `SATURN_BAND_OPACITY` 0.55 -> 0.85. Gerbang
                                 konstanta **merah**; gerbang pita dan nada
                                 tetap hijau. Ini pembeda "nilai menyimpang"
                                 dari "gambar rusak", dan alasan gerbang
                                 konstanta harus berdiri sendiri.

Berkas sumber dimutasi dengan sengaja lalu dipulihkan di `finally` per
keadaan, plus handler `SIGINT`/`SIGTERM`.

Pakai:
    python3 Tools/bukti-mutasi-pita-saturnus.py     # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
results = []
C.check_saturn_globe_is_banded(results, 200, 2)
C.check_saturn_band_tones_stay_apart(results)
C.check_saturn_band_constants_match_the_model(results)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Panggilan gambar pita, di dalam `_draw_rings`. Anjarnya harus **persis**
# seperti di sumber, termasuk `body_radius * radius`: versi pertama harness ini
# menulis `radius` saja, jangkar tidak pernah cocok, dan keadaan 1 diam-diam
# **tidak memutasi apa pun** — probe lalu mengukur pohon utuh dan melaporkan
# keempat gerbang hijau. Kegagalannya terbaca sebagai "gerbang tidak berbunyi",
# padahal yang gagal adalah jangkarnya. Karena itu jangkar yang hilang sekarang
# menghentikan keadaan itu, bukan diteruskan.
BANDS_CALL = "    _draw_saturn_bands(canvas, cx, cy, body_radius * radius, palette, night_mode)"
BANDS_CALL_OFF = ("    # MUTASI UJI: pita tidak digambar.\n"
                  "    pass")

TONES = 'SATURN_BAND_TONES = ("saturnBand", "saturnBandDeep")'
TONES_FLAT = 'SATURN_BAND_TONES = ("saturnBand", "saturnBand")'

OPACITY = "SATURN_BAND_OPACITY = 0.55                   # MODEL: `CelestialVisual.saturnBandOpacity`"
OPACITY_JUPITER = "SATURN_BAND_OPACITY = 0.85                   # MODEL: `CelestialVisual.saturnBandOpacity`"

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang
# membuat berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
BANDED_DAY = "bola Saturnus berpita (siang)"
BANDED_NIGHT = "bola Saturnus berpita (malam)"
APART_DAY = "dua nada pita Saturnus tetap terbedakan (siang)"
APART_NIGHT = "dua nada pita Saturnus tetap terbedakan (malam)"
NOT_JUPITER = "nada pita Saturnus bukan Jupiter (siang)"
COUNT_OK = "jumlah pita Saturnus sama dengan model"
OPACITY_OK = "opasitas pita Saturnus sama dengan model"

HIJAU = "hijau"
MERAH = "merah"


STATES = [
    ("[baseline]", None,
     {BANDED_DAY: HIJAU, BANDED_NIGHT: HIJAU, APART_DAY: HIJAU,
      APART_NIGHT: HIJAU, NOT_JUPITER: HIJAU, COUNT_OK: HIJAU,
      OPACITY_OK: HIJAU}),

    # Pita tidak digambar sama sekali. Gerbang pita harus memerah: residual
    # antara "berpita" dan "satu nada" menjadi nol, karena keduanya sekarang
    # gambar yang sama persis.
    ("1. pita Saturnus tidak digambar",
     [(BANDS_CALL, BANDS_CALL_OFF)],
     {BANDED_DAY: MERAH, BANDED_NIGHT: MERAH, APART_DAY: MERAH,
      APART_NIGHT: MERAH, NOT_JUPITER: HIJAU, COUNT_OK: HIJAU,
      OPACITY_OK: HIJAU}),

    # Kedua nada disamakan. Gerbang pita memerah karena pitanya lenyap,
    # gerbang nada memerah karena kedua nada berimpit. Gerbang konstanta
    # tetap hijau — nilainya memang tidak berubah.
    ("2. nada pita diseragamkan",
     [(TONES, TONES_FLAT)],
     {BANDED_DAY: MERAH, BANDED_NIGHT: MERAH, APART_DAY: MERAH,
      APART_NIGHT: MERAH, NOT_JUPITER: HIJAU, COUNT_OK: HIJAU,
      OPACITY_OK: HIJAU}),

    # Opasitas dinaikkan ke nilai Jupiter. Pita tetap ada dan tetap
    # terbedakan, jadi gerbang gambar tetap hijau; yang menangkapnya adalah
    # gerbang konstanta. Tanpa gerbang itu, keadaan ini lulus tanpa merah.
    ("3. opasitas dinaikkan ke Jupiter",
     [(OPACITY, OPACITY_JUPITER)],
     {BANDED_DAY: HIJAU, BANDED_NIGHT: HIJAU, APART_DAY: HIJAU,
      APART_NIGHT: HIJAU, NOT_JUPITER: HIJAU, COUNT_OK: HIJAU,
      OPACITY_OK: MERAH}),
]


def run_probe():
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        state, rest = line.split(" ", 1)
        name = rest.split("  | ")[0].strip()
        verdicts[name] = "hijau" if state == "OK" else "merah"
    return verdicts, None


def main():
    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        mutasi_sumber.restore_verified(RENDER, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, on_signal)

    try:
        for name, edits, expected in STATES:
            if edits:
                text = original.decode()
                missing = False
                for old, new in edits:
                    if old not in text:
                        print(f"GAGAL {name}: jangkar tidak ditemukan: {old[:60]!r}")
                        failures.append(name)
                        missing = True
                        break
                    text = text.replace(old, new, 1)
                # Jangkar yang hilang berarti keadaan itu **tidak menguji apa
                # pun**: tanpa `continue` di sini, probe mengukur pohon utuh,
                # seluruh gerbang hijau, dan baris "OK" di bawah tetap tercetak
                # — persis kegagalan yang membuat keadaan 1 hijau palsu.
                if missing:
                    restore()
                    continue
                mutasi_sumber.write_source(RENDER, text.encode())
            verdicts, err = run_probe()
            if verdicts is None:
                print(f"GAGAL {name}: probe gagal: {err}")
                failures.append(name)
                restore()
                continue
            for check, want in expected.items():
                got = verdicts.get(check)
                if got is None:
                    print(f"GAGAL {name}: pemeriksaan tidak muncul: {check}")
                    failures.append(name)
                elif got != want:
                    print(f"GAGAL {name}: '{check}' diharapkan {want}, dapat {got}")
                    failures.append(name)
            print(f"OK    {name}")
            restore()
            if hashlib.md5(open(RENDER, "rb").read()).hexdigest() != baseline_md5:
                print(f"GAGAL {name}: sumber tidak kembali ke byte semula")
                failures.append(name)
                break
    finally:
        restore()

    print(f"\n{len(STATES)} keadaan, {len(failures)} kegagalan")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
