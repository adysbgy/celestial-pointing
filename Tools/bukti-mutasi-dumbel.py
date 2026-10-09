#!/usr/bin/env python3
"""Buktikan gerbang M27 berbunyi pada setiap cara ia bisa salah.

Kenapa harness ini ada.

`check_dumbbell_nebula_is_an_elongated_shell` menjaga dua sifat sekaligus, dan
setiap sifat punya **cara gagal sendiri yang tidak tertangkap sifat lain**:

  - siluet tidak memipih   → M27 tampil bulat, sama seperti M57 (cacat aslinya)
  - siluet terlalu pipih   → bentuknya lensa tipis, bukan Dumbel
  - lubangnya menutup      → cangkang berongga jadi gumpalan pipih

Yang terakhir itu bukan kejadian teoretis. Ia persis yang terjadi kalau
`elongation` diterapkan pada **posisi** blob saja tanpa **tingginya**: siluetnya
memenuhi syarat pertama sambil pusatnya terisi. Harness ini membuktikan
gerbangnya benar-benar membedakan ketiganya — bukan hijau pada semuanya karena
salah mengukur.

Keadaan yang diuji:

  [baseline]                gerbang hijau (kalau tidak, harness salah)
  1. elongasi 1.0           pemipihan dimatikan — siluet kembali bulat;
                            gerbang "M27 memanjang" harus **merah**
  2. elongasi 0.20          terlalu pipih — siluet jatuh ke ~0.22; gerbang
                            "M27 memanjang" harus **merah** lewat batas bawah
  3. pipihkan posisi saja   **mutasi paling tajam**: siluetnya tetap memipih
                            (syarat 1 terpenuhi) tetapi pusatnya menutup.
                            Gerbang "tetap berongga" harus **merah**, dan
                            gerbang siluet tetap **hijau** — kalau keduanya
                            merah, yang diukur bukan lubangnya.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
pelajaran yang sudah dibayar di repo ini, `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup. Penulisan atomik + penjaga "sumber bersih" dipakai
bersama lewat `Tools/mutasi_sumber.py`.

Pakai:
    python3 Tools/bukti-mutasi-dumbel.py      # 0 = semua sesuai harapan
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
MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")

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
C.check_dumbbell_nebula_is_an_elongated_shell(results)
# Drift antar-bahasa: satu-satunya pemeriksaan yang melihat **model**
# berhenti memetkan cangkangnya; semua pemeriksaan siluet membaca port.
C.check_deep_sky_layouts_match_the_model(results)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Blok elongasi yang sekarang, apa adanya. Kalau modelnya dirapikan dan jangkar
# ini tidak lagi cocok, harness **berhenti** — bukan diam-diam menguji himpunan
# kosong.
CURRENT_ELONGATION = '''DEEP_SKY_ELONGATION = {
    "m27": 0.60,
}'''

# 1. Pemipihan dimatikan: kembali ke siluet bulat (cacat aslinya).
NO_ELONGATION = '''DEEP_SKY_ELONGATION = {
    "m27": 1.0,
}'''

# 2. Terlalu pipih: melewati batas bawah, bentuknya jadi lensa tipis.
TOO_FLAT = '''DEEP_SKY_ELONGATION = {
    "m27": 0.20,
}'''

# 3. Hanya **posisi** yang dipetkan, tingginya dibiarkan — siluet memipih
#    sambil lubangnya menutup. Ini yang paling penting: ia membuktikan gerbang
#    "berongga" mengukur hal yang tidak diukur gerbang siluet.
POSITION_ONLY = '''def deep_sky_blobs(morphology, fuzziness, frame_half_extent=1.0, object_id=None):
    """`VisualFrame.deepSky` / `buildDeepSky` — tidak pernah keluar frame."""
    layout = DEEP_SKY_LAYOUT.get(morphology or "nebula", DEEP_SKY_LAYOUT["nebula"])
    if morphology == "planetaryNebula":
        elongation = DEEP_SKY_ELONGATION.get(object_id or "", 1.0)
        layout = [(ox, oy * elongation, w, a, ang, op)
                  for (ox, oy, w, a, ang, op) in layout]
    clamped = min(1.0, max(0.0, fuzziness))
    growth = 0.62 + 0.38 * clamped'''

CURRENT_FUNCTION_HEAD = '''def deep_sky_blobs(morphology, fuzziness, frame_half_extent=1.0, object_id=None):
    """`VisualFrame.deepSky` / `buildDeepSky` — tidak pernah keluar frame."""
    layout = DEEP_SKY_LAYOUT.get(morphology or "nebula", DEEP_SKY_LAYOUT["nebula"])
    # MODEL: `.planetaryNebula` mengalikan `offset.1` **dan** `aspect` dengan
    # `elongation`; di sini hal yang sama dilakukan pada layoutnya. Kedua
    # komponen y dipetkan sekaligus supaya lubang tengahnya ikut terskala —
    # memetkan salah satu saja menutup lubangnya (lihat komentar di model).
    if morphology == "planetaryNebula":
        elongation = DEEP_SKY_ELONGATION.get(object_id or "", 1.0)
        layout = [(ox, oy * elongation, w, a * elongation, ang, op)
                  for (ox, oy, w, a, ang, op) in layout]
    clamped = min(1.0, max(0.0, fuzziness))
    growth = 0.62 + 0.38 * clamped'''

# 4. **Sisi model**: skala **lebar** blob cangkang diubah dari `0.26` menjadi
#    `0.10`, dan hanya itu. Pembaca gerbang **tetap berhasil mengurai**
#    (`(offset.0, offset.1 * elongation, <skala>,` masih cocok), jadi yang
#    berbunyi adalah perbandingan **nilainya**: tabel yang dihitung model kini
#    tidak sama dengan tabel port. Cacat yang dijaga: cangkang masih mengikuti
#    `ring` dan masih dipetakan elongasi, tetapi tiap blob jadi ramping —
#    gerbang siluet tetap hijau (port tidak disentuh), hanya gerbang drift
#    antar-bahasa yang melihatnya.
#
#    **Kenapa angkanya `0.10`, dan kenapa bukan `1.0 * elongation`.** Versi
#    pertama keadaan ini mengganti **tinggi** (`offset.1`) dengan konstanta, dan
#    itu bertahan benar sampai model dirapikan. Pemapian cangkang lalu berubah
#    bentuk: `zip(ring, shellOpacity)` diganti `ring.enumerated()` dengan
#    opasitas berputar, supaya 24 posisi tidak lagi terpotong jadi 16 blob oleh
#    `zip`. Setelah perubahan itu, mengganti `offset.1` **tidak lagi** membuat
#    tabel menyimpang diam-diam — ia membuat pembaca gagal mengurai
#    `(offset.0, offset.1 * elongation, …)`, jadi keadaan ini dan keadaan 5
#    jatuh ke **gerbang yang sama** dan tidak ada lagi yang membedakan
#    "nilai salah" dari "bentuk salah". Keadaan ini karena itu dipindahkan ke
#    komponen yang **dibaca sebagai angka**: ia tetap terurai, dan gerbang yang
#    menyalakannya adalah gerbang nilai (drift), bukan gerbang pembacaan.
CONSTANT_WIDTH = '''            let layout: [(Double, Double, Double, Double, Double, Double)] =
                ring.enumerated().map { index, offset in
                    (offset.0, offset.1 * elongation, 0.10, 1.0 * elongation,
                     0.0, shellOpacity[index % shellOpacity.count])
                }'''

# 5. **Sisi model**: `offset.1` berhenti dipetkan sama sekali — pembaca gerbang
#    **gagal mengurai dengan bersih** (menyebut jangkarnya), bukan melempar
#    `AttributeError`. Inilah gerbang "terbaca dari model" yang menjaga pembaca
#    tetap cocok dengan bentuk sumbernya. Cacat yang dijaga: model berhenti
#    memetkan sementara port tetap memetkan — port menggambar M27 memanjang,
#    jam menggambarnya bulat, dan tidak satu pun pemeriksaan siluet di sini
#    bisa melihatnya karena keduanya membaca **port**.
NO_MODEL_MAPPING = '''            let layout: [(Double, Double, Double, Double, Double, Double)] =
                ring.enumerated().map { index, offset in
                    (offset.0, offset.1, 0.26, 1.0 * elongation,
                     0.0, shellOpacity[index % shellOpacity.count])
                }'''

# Cuplikan **persis** branch `.planetaryNebula` model pada saat harness ini
# ditulis. Indentasi ikut apa adanya karena yang diganti adalah teks sumbernya.
#
# **Jangkar ini boleh SENSITIF.** Harness membandingkan string ini dengan isi
# model untuk memutuskan apakah mutasi benar-benar mendarat; kalau model
# dirapikan dan jangkar ini tidak lagi cocok, yang terjadi bukan mutasi gagal
# diam-diam — `for find, replace in edits` menambah
# `"jangkar tidak ditemukan"` ke `failures` dan harness **merah**. Itu
# persis yang terjadi pada keadaan 4 dan 5 di commit `1e28591`: keduanya
# masih mengutip `zip(ring, shellOpacity).map { offset, opacity in`, jadi
# tidak ada yang berubah di disk dan gerbang drift **hijau tanpa alasan**.
# Batas ini sengaja dibiarkan keras: harness yang jangkarnya basi harus
# gagal, bukan-evaluation kosong yang terlihat lulus.
CURRENT_MODEL_MAPPING = '''            let layout: [(Double, Double, Double, Double, Double, Double)] =
                ring.enumerated().map { index, offset in
                    (offset.0, offset.1 * elongation, 0.26, 1.0 * elongation,
                     0.0, shellOpacity[index % shellOpacity.count])
                }'''

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang
# membuat berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
SHAPE = "M27 memanjang, bukan bulat"
HOLLOW = "cangkang M27 tetap berongga di tengah"
#: Pemeriksaan **drift antar-bahasa**, dari `check_deep_sky_layouts_match_the_model`.
#: Ia satu-satunya yang bisa melihat model berhenti memetkan cangkangnya,
#: karena seluruh pemeriksaan siluet di atas membaca **port**.
DRIFT = "tata letak planetaryNebula: tiap blob sama dengan model"
#: Gerbang **pembacaan** — menyala ketika bentuk sumber model tidak lagi bisa
#: diurai dengan bersih, alih-alih melempar `AttributeError`.
READS = "tata letak objek langit dalam: terbaca dari model"
#: Cabang **cangkang tak terbaca** — nama pemeriksaan yang berbeda dari
#: `HOLLOW`, dan menyala ketika terang cangkang tidak lagi melewati ambang
#: keterbacaan. Pada keadaan 2 (elongasi 0.20) cangkangnya memipih sampai
#: hilang, jadi gerbang berhenti di cabang ini alih-alih mengukur rongga.
UNREADABLE = "cangkang M27 berongga"


#: Penanda harapan yang hanya berlaku pada ukuran jam.
#:
#: Keadaan 3 menutup lubang M27 pada 76 px (pusat terisi 0.571) tetapi **tidak**
#: pada 200 px (0.078) — pada 200 px blobnya lebih rapat dari jaring sampel
#: pusat, jadi lubangnya tidak benar-benar tertutup di ukuran itu. Harapan
#: "merah di mana saja" akan merah pada kode yang benar; harapan ini menyatakan
#: ukuran mana yang memisahkan kode sehat dari cacatnya.
WATCH_SIZE = "(76px)"


def _by_kind(verdicts, prefix):
    return {name: state for name, state in verdicts.items()
            if name.startswith(prefix)}


STATES = [
    # (nama, berkas, edit, harapan)
    #
    # Harapan bisa tiga bentuk:
    #   "merah"/"hijau"  -> berlaku untuk **setiap** ukuran
    #   WATCH_SIZE+":"+… -> hanya ukuran jam; ukuran lain tak diuji di keadaan ini
    #   None             -> baseline, semuanya harus hijau
    ("[baseline]", None, None, None),
    ("1. elongasi 1.0 (pemipihan dimatikan)",
     "port", [(CURRENT_ELONGATION, NO_ELONGATION)],
     {SHAPE: "merah", HOLLOW: "hijau"}),
    # Elongasi 0.20 memipihkan cangkangnya sampai hilang, jadi gerbang berhenti
    # di cabang "cangkang tak terbaca" dan tidak pernah sampai ke pengukuran
    # rongga — cabang itu sendiri yang harus berbunyi.
    ("2. elongasi 0.20 (terlalu pipih)",
     "port", [(CURRENT_ELONGATION, TOO_FLAT)],
     {SHAPE: "merah", UNREADABLE: "merah"}),
    # Lubangnya hanya benar-benar tertutup di ukuran jam — pada 200 px blobnya
    # lebih rapat dari jaring sampel pusat, jadi cacatnya tidak muncul di sana.
    # Siluetnya sendiri tetap sehat di kedua ukuran (0.700 / 0.696).
    ("3. pipihkan posisi saja (lubang menutup)",
     "port", [(CURRENT_FUNCTION_HEAD, POSITION_ONLY)],
     {SHAPE: "hijau", HOLLOW: WATCH_SIZE + ":merah"}),
    # Keadaan 4 dan 5 menyentuh **model**, jadi yang menuntutnya merah adalah
    # gerbang drift antar-bahasa — dan justru itu buktinya: cacat "model
    # berhenti memetkan, port tetap memetkan" tidak bisa dilihat pemeriksaan
    # siluet, karena keduanya membaca port.
    ("4. model: skala lebar blob jadi 0.10 (bukan 0.26)",
     "model", [(CURRENT_MODEL_MAPPING, CONSTANT_WIDTH)],
     {DRIFT: "merah"}),
    ("5. model: offset.1 berhenti dipetkan (pembaca gagal bersih)",
     "model", [(CURRENT_MODEL_MAPPING, NO_MODEL_MAPPING)],
     {READS: "merah"}),
]


def run_probe():
    # `check_deep_sky_layouts_match_the_model` membaca berkas **model**, jadi
    # probe harus dijalankan dari proses baru setelah mutasi apa pun mendarat
    # di disk — baik mutasi port maupun mutasi model.
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
    # Harness ini memutasi **dua** berkas produksi: port gambar *dan* model
    # cangkang. Keduanya dijaga penjaga sumber-bersih yang sama.
    mutasi_sumber.require_clean_sources([RENDER, MODEL])
    original = open(RENDER, "rb").read()
    original_model = open(MODEL, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    model_md5 = hashlib.md5(original_model).hexdigest()
    failures = []

    def restore():
        # Tulis atomik + verifikasi (`mutasi_sumber`): harness ini dan enam
        # saudaranya memutasi berkas produksi yang sama, dan setiap prob
        # membacanya dari proses baru.
        mutasi_sumber.restore_verified(RENDER, original)
        mutasi_sumber.restore_verified(MODEL, original_model)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, target, edits, expected in STATES:
            if edits is None:
                restore()
            else:
                path = RENDER if target == "port" else MODEL
                source = (original if target == "port" else original_model).decode()
                for find, replace in edits:
                    if find not in source:
                        failures.append(f"{name}: jangkar tidak ditemukan "
                                        f"di {os.path.basename(path)}")
                        break
                    source = source.replace(find, replace)
                else:
                    mutasi_sumber.write_source(path, source)

            verdicts, error = run_probe()
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            shape = _by_kind(verdicts, SHAPE)
            hollow = _by_kind(verdicts, HOLLOW)
            if not shape and not hollow:
                failures.append(f"{name}: tidak ada pemeriksaan '{SHAPE}' / "
                                f"'{HOLLOW}' di keluaran gerbang")
                print(f"{name}: TIDAK ADA PEMERIKSAAN")
                continue

            if expected is None:
                bad = [c for c, s in verdicts.items() if s != "hijau"]
                if bad:
                    failures.append(f"{name}: baseline tidak hijau: {bad}")
                    print(f"{name}: BASELINE TIDAK HIJAU -> {bad}")
                else:
                    print(f"{name}: hijau di {len(verdicts)} pemeriksaan (benar)")
                continue

            wrong = []
            untested = []
            for prefix, want in expected.items():
                scoped = want.startswith(WATCH_SIZE + ":")
                if scoped:
                    want = want[len(WATCH_SIZE) + 1:]
                for check, state in _by_kind(verdicts, prefix).items():
                    if scoped and WATCH_SIZE not in check:
                        untested.append(check)
                        continue
                    if state != want:
                        wrong.append(f"'{check}' harus {want}, dapat {state}")
            if wrong:
                for item in wrong:
                    failures.append(f"{name}: {item}")
                    print(f"{name}: {item}")
            else:
                note = f" (ukuran lain tidak diuji: {len(untested)})" if untested else ""
                print(f"{name}: sesuai harapan "
                      f"({', '.join(f'{p} {w}' for p, w in expected.items())})"
                      f"{note}")
    finally:
        restore()
        if hashlib.md5(open(RENDER, "rb").read()).hexdigest() != baseline_md5:
            failures.append("sumber produksi (port) TIDAK kembali ke semula")
        if hashlib.md5(open(MODEL, "rb").read()).hexdigest() != model_md5:
            failures.append("sumber produksi (model) TIDAK kembali ke semula")

    print()
    if failures:
        print(f"GAGAL ({len(failures)}):")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("OK: gerbang berbunyi pada setiap cara M27 bisa salah.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
