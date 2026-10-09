#!/usr/bin/env python3
"""Buktikan gerbang inti gugus berbunyi — dan bahwa ia berbunyi **dua kelas**.

Kenapa harness ini ada.

Gerbang ini punya cacat yang paling sulit dilihat: **versi pertamanya hijau
pada gambar yang jelas salah.** Ia hanya mengukur puncak inti di atas
lengkungan sekitarnya (`cluster_core_sharpness`), diukur pada **satu** render.
Dengan inti dihapus seluruhnya dari port (`for star in []:`), keempat
pemeriksaannya tetap hijau — gugus bola 38 pt pada **0.2035** terhadap ambang
0.20. Lengkungan yang diukurnya memang milik **kabut** yang menaungi inti,
bukan intinya; jadi gerbang itu mengesahkan gugus tanpa satu pun bintang, dan
melaporkannya sebagai "inti bintang gugus terbaca".

Karena itu gerbangnya sekarang mengukur **dua** nisbah, dan harness ini
membuktikan masing-masing benar-benar berbunyi:

  - `cluster_core_contrast` — kecerahan pusat inti **dengan** inti dibagi
    **tanpa** inti. Menjaga *keberadaan*: 1.000 berarti intinya tidak
    ditambahkan sama sekali. Inilah yang menangkap `for star in []:`.
  - `cluster_core_sharpness` — puncak di atas lengkungan, proporsi puncak.
    Menjaga *bentuk*: inti yang digambar tetapi **menyatu** dengan kabutnya
    tetap punya kontras (ia memang menambah terang) sementara puncaknya rata.
    Inilah satu-satunya kelas yang tidak dijaga kontras.

Keadaan yang diuji:

  [baseline]                 gerbang hijau di kedelapan pemeriksaan (kalau
                             tidak, harness ini salah, bukan gerbangnya)
  1. port tidak menggambar   `for star in []:` — inti hilang dari gambar.
     inti sama sekali        Keempat pemeriksaan **kontras** harus MERAH.
                             Keempat pemeriksaan **ketajaman** harus tetap
                             HIJAU, dan itu **bukan** kegagalan harness: itu
                             justru bukti bahwa ambang lama buta, direkam
                             sebagai harapan. Kalau suatu saat keempatnya ikut
                             merah, yang berubah bukan gerbangnya melainkan
                             salah satu metriknya, dan baris ini memberi tahu
                             bahwa perbandingannya sudah tidak seperti yang
                             didokumentasikan.
  2. halo inti 40x           `CLUSTER_CORE_HALO_SCALE = 40.0` — inti tetap
                             ada dan tetap menambah terang, jadi **kontras
                             tetap HIJAU**; yang runtuh bentuknya: puncaknya
                             tenggelam ke lengkungan halonya sendiri. Diukur
                             pada gugus bola: ketajaman 0.53 → 0.09 (200 pt)
                             dan 0.53 → 0.06 (38 pt), sementara kontras naik
                             sedikit (1.66 → 1.75) karena halonya menambah
                             terang di pusat. Keadaan ini **wajib** ada: tanpa
                             dia, `MIN_CLUSTER_CORE_SHARPNESS` tidak dijaga
                             siapa pun, dan satu-satunya alasan ambang itu
                             masih dipertahankan adalah kelas cacat ini.

Yang **tidak** dipakai sebagai keadaan: menulis inti tanpa penajaman
(`min(1.0, op + 0.25)` → `min(1.0, op)`). Sempat dicoba dan gerbangnya hijau —
dan itu benar: halonya sendiri masih memberi puncak yang menonjol (ketajaman
0.48–0.79). Menuntutnya merah akan menuntut gerbang menyalak pada gambar yang
masih terbaca.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
`SIGKILL` melewati `finally` dan meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-inti-gugus.py      # 0 = semua sesuai harapan
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

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
results = []
C.check_cluster_cores_reach_the_picture(results, 2)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Gelung yang menggambar inti gugus, apa adanya. Kalau modelnya dirapikan dan
# jangkar ini tidak lagi cocok, harness **berhenti** — bukan diam-diam
# menguji himpunan kosong.
CORE_LOOP = """    for star in cluster_cores(morphology, kw.get("fuzziness", 0.6),
                              frame_half_extent=radius):"""

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang
# membuat berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
SHARP = "inti bintang gugus terbaca"
CONTRAST = "inti bintang gugus ditambahkan ke gambar"

# Delapan pemeriksaan gerbang itu, ditulis lengkap: nama adalah bagian dari
# kontrak, dan menurunkannya dari daftar lain akan membuat keadaan #1 bisa
# "lulus" dengan membandingkan pemeriksaan yang tidak ada.
OPEN_200_S = f"{SHARP} (gugus terbuka, 200pt)"
OPEN_200_C = f"{CONTRAST} (gugus terbuka, 200pt)"
OPEN_38_S = f"{SHARP} (gugus terbuka, 38pt)"
OPEN_38_C = f"{CONTRAST} (gugus terbuka, 38pt)"
GLOB_200_S = f"{SHARP} (gugus bola, 200pt)"
GLOB_200_C = f"{CONTRAST} (gugus bola, 200pt)"
GLOB_38_S = f"{SHARP} (gugus bola, 38pt)"
GLOB_38_C = f"{CONTRAST} (gugus bola, 38pt)"

STATES = [
    # (nama, edit, harapan: nama pemeriksaan -> "hijau"/"merah")
    ("[baseline]", None, None),

    # Keadaan #1: cacat yang **menutup** gerbang versi pertama. Empat baris
    # ketajaman sengaja diharapkan hijau — itu rekaman cacatnya, bukan
    # kelonggaran.
    ("1. port tidak menggambar inti sama sekali (for star in [])",
     [(CORE_LOOP, "    for star in []:")],
     {OPEN_200_S: "hijau", OPEN_38_S: "hijau",
      GLOB_200_S: "hijau", GLOB_38_S: "hijau",
      OPEN_200_C: "merah", OPEN_38_C: "merah",
      GLOB_200_C: "merah", GLOB_38_C: "merah"}),

    # Keadaan #2: inti ada dan menambah terang, tetapi menyatu dengan halonya.
    # Satu-satunya penjaga kelas ini adalah ambang ketajaman.
    ("2. halo inti 40x (inti menyatu dengan kabutnya)",
     [("CLUSTER_CORE_HALO_SCALE = 2.4", "CLUSTER_CORE_HALO_SCALE = 40.0")],
     {GLOB_200_S: "merah", GLOB_38_S: "merah",
      OPEN_200_C: "hijau", OPEN_38_C: "hijau",
      GLOB_200_C: "hijau", GLOB_38_C: "hijau"}),
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


def _checks(verdicts):
    """Kedelapan pemeriksaan inti gugus, dari keluaran gerbangnya sendiri."""
    return [name for name in verdicts
            if name.startswith(SHARP) or name.startswith(CONTRAST)]


def main():
    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        # Tulis atomik + verifikasi (`mutasi_sumber`): harness ini dan delapan
        # saudaranya memutasi berkas produksi yang sama, dan setiap prob
        # membacanya dari proses baru.
        mutasi_sumber.restore_verified(RENDER, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected in STATES:
            if edits is None:
                restore()
            else:
                source = original.decode()
                for find, replace in edits:
                    if find not in source:
                        failures.append(f"{name}: jangkar tidak ditemukan")
                        break
                    source = source.replace(find, replace)
                else:
                    mutasi_sumber.write_source(RENDER, source)

            verdicts, error = run_probe()
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            checks = _checks(verdicts)
            if len(checks) != 8:
                failures.append(f"{name}: gerbang melaporkan {len(checks)} "
                                f"pemeriksaan inti gugus, harusnya 8 — nama "
                                f"pemeriksaan berubah?")
                print(f"{name}: JUMLAH PEMERIKSAAN {len(checks)}, HARUS 8")
                continue

            if expected is None:
                bad = [c for c in checks if verdicts[c] != "hijau"]
                if bad:
                    failures.append(f"{name}: baseline tidak hijau: {bad}")
                    print(f"{name}: BASELINE TIDAK HIJAU -> {bad}")
                else:
                    print(f"{name}: hijau di {len(checks)} pemeriksaan (benar)")
                continue

            # Harapan per-pemeriksaan: setiap keadaan harus merah di sebagian
            # baris dan hijau di sisanya, karena itulah yang membedakan kedua
            # metrik. Harapan tunggal tidak bisa menyatakan itu.
            wrong = [c for c in expected if verdicts.get(c) != expected[c]]
            if wrong:
                for check in wrong:
                    failures.append(
                        f"{name}: '{check}' harus {expected[check]}, "
                        f"dapat {verdicts.get(check)}")
                    print(f"{name}: '{check}' harus {expected[check]}, "
                          f"dapat {verdicts.get(check)}")
            else:
                print(f"{name}: sesuai harapan per-kasus "
                      f"({len(expected)} pemeriksaan, benar)")
    finally:
        restore()
        if hashlib.md5(open(RENDER, "rb").read()).hexdigest() != baseline_md5:
            failures.append("sumber produksi TIDAK kembali ke semula")

    print()
    if failures:
        print(f"GAGAL ({len(failures)}):")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("OK: gerbang berbunyi di dua kelas cacat, dan hijau saat kode benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
