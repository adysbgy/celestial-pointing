#!/usr/bin/env python3
"""Buktikan gerbang **«setiap kasus katalog menggambar sesuatu»** berbunyi.

Kenapa harness ini ada.

`check_every_catalog_case_draws_something` ditulis untuk menutup cacat yang
sudah terukur: `planet-saturn-no-feature` menghasilkan frame **kosong** — 0
piksel menyala dari 1 444 di 38 px, 0 dari 40 000 di 200 px. Gerbang baru selalu
hijau pada hari ia ditulis; yang harus dibuktikan adalah bahwa ia **bisa
merah**, dan merah **tepat pada keadaan yang ia klaim jaga**.

### Kenapa cacat ini bukan satu gambar jelek

`planet-saturn-no-feature` adalah *pembanding*:
`check_features_survive_the_watch_size` mengukur selisih
`planet-saturn-confirmed` terhadapnya. Membandingkan lawan frame kosong membuat
selisihnya selalu besar, jadi gerbang keterbacaan ciri Saturnus **mustahil
gagal** — sementara 123 pemeriksaan lain tetap hijau, termasuk
`check_night_mode_purity` (frame kosong: hijau & biru nol, benar secara
harfiah) dan `check_night_mode_never_exceeds_day` (nol <= nol, benar).

### Yang diukur harness ini, bukan dikutip dari docstring

    [baseline]                                   hijau penuh
    1. bola Saturnus `feature_off` hilang lagi   MERAH, tepat 2 hasil
                                                 (siang & malam), menyebut
                                                 `planet-saturn-no-feature`
    2. kontrol negatif: prosa lain diubah        hijau penuh

Keadaan 1 **persis** cacat yang dikirim ke `main`: cabang `feature_off` untuk
planet bercincin kembali `return` tanpa menggambar bola. Mutasinya menghapus
dua baris `_draw_sphere` yang baru ditambahkan, bukan mengarang cacat lain.

Keadaan 2 bukan hiasan: kalau harness merah di sana, ia merah karena
**berkasnya berubah**, bukan karena ada frame kosong — dan ia tidak mengukur
apa pun.

### Kenapa kedua mode dituntut

Cacat ini sempat terlihat hanya di satu mode pada percobaan pertama, karena
`render()` memilih latar berbeda untuk siang dan malam. Gerbang yang mengukur
satu mode akan hijau pada separuh cacatnya, jadi harness ini menuntut **dua**
hasil merah — satu per mode — dan himpunannya persis.

### Yang TIDAK diklaim

- Harness ini tidak membuktikan bahwa yang tergambar adalah **benda yang
  benar**. Satu bintik acak di tengah frame lolos gerbangnya; yang menjaga
  isinya adalah gerbang ciri. Batas itu dinyatakan di docstring gerbangnya
  sendiri.
- Ia tidak membaca piksel app Apple, dan tidak membuktikan bahwa 38 px adalah
  ukuran yang dipakai perangkat — itu klaim `WatchMetrics.visualDiameter`,
  dijaga gerbang lain (`_watch_diameter_token`).
- Mutasinya di `render-visuals.py` (port Python), bukan di view Swift. Yang
  dibuktikan adalah gambar yang dipakai gerbang memang berubah; view Swift
  dijaga gerbang lint dan gerbang geometris lain.

Berkas produksi dimutasi lalu dipulihkan di `finally`, plus handler
`SIGINT`/`SIGTERM`. `require_clean_sources` menolak jalan bila berkas produksi
sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-katalog-kosong.py   # 0 = sesuai harapan
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

HIJAU = "hijau"
MERAH = "merah"

#: Nama hasil di dalam gerbang, dituntut **persis** supaya perubahan nama tidak
#: terbaca sebagai "gerbangnya masih ada". Satu per mode, karena gerbangnya
#: mengisi satu hasil per mode.
SIANG = "katalog tidak kosong: planet-saturn-no-feature (siang)"
MALAM = "katalog tidak kosong: planet-saturn-no-feature (malam)"

# ── Jangkar: potongan yang benar-benar ada di `render-visuals.py` ──────────
# Jumlah kemunculannya diperiksa sebelum memutasi; jangkar yang meleset
# dilaporkan sebagai kelemahan bukti, bukan dipakai diam-diam.
BOLA_SATURN = (
    '        if palette["feature"] == "rings":\n'
    '            _draw_sphere(canvas, cx, cy, radius * saturn_body_radius(saturn_ring()),\n'
    '                         palette["light"], palette["dark"], night_mode)\n'
)
PROSA = "# `feature_off` pada planet bercincin tetap harus punya bola."

# Dijalankan di proses baru: mengimpor ulang `check-visuals` dari berkas yang
# **sudah dimutasi** di disk. Mengimpor sekali di dalam proses ini akan memakai
# salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))

path = os.path.join(sys.argv[1], "Tools", "check-visuals.py")
spec = importlib.util.spec_from_file_location("cv_probe", path)
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)

results = []
try:
    C.check_every_catalog_case_draws_something(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
    print("     " + r.detail)
"""

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama hasil: harapan})
STATES = [
    ("[baseline] berkas bersih", None,
     {SIANG: HIJAU, MALAM: HIJAU}),

    # ── 1. Bola Saturnus hilang lagi dari cabang `feature_off` ───────────
    # Persis cacat yang dikirim ke `main`: cabang itu `return` tanpa
    # menggambar apa pun, jadi frame-nya kosong. Kedua mode dituntut merah,
    # karena `render()` memilih latar berbeda per mode.
    ("1. bola Saturnus `feature_off` hilang lagi",
     [(RENDER, BOLA_SATURN, '        if palette["feature"] == "rings":\n'
                            '            pass  # MUT: bola Saturnus hilang\n')],
     {SIANG: MERAH, MALAM: MERAH}),

    # ── 2. Kontrol negatif: prosa yang tidak dibaca gerbang ──────────────
    # Harus hijau penuh: kalau merah, harness merah karena berkasnya berubah,
    # bukan karena ada frame kosong.
    ("2. kontrol negatif: prosa lain diubah",
     [(RENDER, PROSA, PROSA + " (diubah)")],
     {SIANG: HIJAU, MALAM: HIJAU}),
]


def run_probe():
    """Jalankan gerbang di proses baru. -> (stdout atau None, galat)."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    return out.stdout, None


def classify(stdout):
    """Petakan keluaran prob -> {nama hasil: hijau|merah}."""
    verdicts = {}
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("ERR"):
            continue
        state, _, name = stripped.partition(" ")
        name = name.strip()
        if state in ("OK", "GAGAL") and name:
            verdicts[name] = HIJAU if state == "OK" else MERAH
    return verdicts


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

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, want in STATES:
            restore()
            if edits is not None:
                pending = {}
                broken = False
                for path, find, replace in edits:
                    content = pending.get(path, original.decode())
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: "
                            f"{find[:70]!r}")
                        broken = True
                        break
                    pending[path] = content.replace(find, replace)
                if broken:
                    continue
                for path, content in pending.items():
                    mutasi_sumber.write_source(path, content)

            stdout, error = run_probe()
            if stdout is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            verdicts = classify(stdout)

            # Himpunan hasilnya dituntut **persis**: hasil yang hilang dan
            # hasil yang muncul tiba-tiba keduanya bagian dari bukti. Gerbang
            # yang memerahkan seluruh katalog saat satu bola hilang akan
            # terlihat di sini sebagai himpunan yang tidak sesuai harapan.
            wrong = {k: (verdicts.get(k, "TIDAK ADA"), v)
                     for k, v in want.items()
                     if verdicts.get(k, "TIDAK ADA") != v}
            missing = sorted(set(want) - set(verdicts))
            if missing:
                failures.append(
                    f"{name}: hasil tidak dihasilkan gerbang: {missing}")
            if wrong:
                failures.append(f"{name}: tidak sesuai harapan: {wrong}")

            ok = not missing and not wrong
            detail = ""
            for line in stdout.splitlines():
                if line.startswith("     "):
                    detail = line.strip()
            print(f"{name}: "
                  + ("sesuai harapan" if ok else "TIDAK SESUAI HARAPAN")
                  + (f" ({detail})" if detail else ""))
    finally:
        restore()

    after = hashlib.md5(open(RENDER, "rb").read()).hexdigest()
    print(f"\nmd5 Tools/render-visuals.py: {baseline_md5} -> {after} "
          f"({'pulih persis' if after == baseline_md5 else 'TIDAK PULIH'})")
    if after != baseline_md5:
        failures.append("sumber produksi tidak pulih persis: "
                        "Tools/render-visuals.py")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
