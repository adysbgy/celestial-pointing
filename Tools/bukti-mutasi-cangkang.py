#!/usr/bin/env python3
"""Buktikan cangkang `.planetaryNebula` **bersambung**, bukan untaian manik.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Dan gerbang ini punya riwayat yang membuatnya lebih perlu dibuktikan
daripada kebanyakan: **dua versi sebelumnya hijau pada kode yang jelas
salah.**

  - Versi pertama membandingkan kecerahan **terang** dan **gelap** pada
    radius cangkang. Opasitas blob terbesar 0.54, jadi jumlah blob yang
    tumpang tindih berhenti menambah kecerahan begitu totalnya melewati
    0.54: puncaknya tersaturasi sementara celahnya tidak. Akibatnya versi
    16-blob terukur **lebih buruk** (1.13) daripada versi 8-blob (0.15)
    oleh metrik itu — persis terbalik dari kenyataan gambarnya.
  - Yang benar-benar membedakan cangkang dari manik adalah **bagian
    gelapnya**: pada manik, sudut di antara blob turun hampir ke latar.
    Karena itu gerbangnya mengukur profil angular, dan harness ini
    membuktikan bahwa profil itu benar-benar berbunyi.

Keadaan yang diuji:

  [baseline]              gerbang hijau (kalau tidak, harness salah)
  1. tata letak 8-blob    tata letak lama (45°, lebar 0.30) — gerbang harus
     @45° lebar 0.30      **merah**, karena itulah cacat yang ditutupnya
  2. lebar 0.20           blob yang sama tapi lebih kecil — gerbang merah,
                          membuktikan ambangnya tidak sekadar "ada blob"
  3. 8 titik @ lebar      mutasi paling tajam: **ukuran blob sama persis**
     0.26 (lebar sekarang) dengan kode sekarang, yang berbeda hanya
                          **jaraknya**. Gerbang harus tetap merah — kalau
                          hijau, berarti yang diukurnya ukuran blob, bukan
                          kesinambungan cangkangnya.

Yang **tidak** dipakai sebagai keadaan: 8 titik @45° dengan lebar **0.40**.
Sempat dicoba dan gerbangnya hijau — dan itu benar: delapan blob selebar itu
saling menjangkau 1.48x tali busurnya, jadi cangkangnya memang bersambung.
Menuntutnya merah akan menuntut gerbang menyalak pada kode yang benar.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
pelajaran yang sudah dibayar di repo ini, `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-cangkang.py      # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import importlib.util
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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
C.check_planetary_nebula_shell_is_continuous(results)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Blok `planetaryNebula` yang sekarang, apa adanya. Kalau modelnya dirapikan
# dan jangkar ini tidak lagi cocok, harness **berhenti** — bukan diam-diam
# menguji himpunan kosong.
CURRENT_LAYOUT = """    "planetaryNebula": [(0.4200000000000000, 0.0000000000000000, 0.26, 1.0, 0.0, 0.54),
                        (0.3880294036547404, 0.1607270415933377, 0.26, 1.0, 0.0, 0.48),
                        (0.2969848480983499, 0.2969848480983499, 0.26, 1.0, 0.0, 0.52),
                        (0.1607270415933377, 0.3880294036547404, 0.26, 1.0, 0.0, 0.46),
                        (0.0000000000000000, 0.4200000000000000, 0.26, 1.0, 0.0, 0.50),
                        (-0.1607270415933377, 0.3880294036547404, 0.26, 1.0, 0.0, 0.44),
                        (-0.2969848480983499, 0.2969848480983499, 0.26, 1.0, 0.0, 0.53),
                        (-0.3880294036547404, 0.1607270415933377, 0.26, 1.0, 0.0, 0.47),
                        (-0.4200000000000000, 0.0000000000000000, 0.26, 1.0, 0.0, 0.51),
                        (-0.3880294036547404, -0.1607270415933377, 0.26, 1.0, 0.0, 0.45),
                        (-0.2969848480983499, -0.2969848480983499, 0.26, 1.0, 0.0, 0.49),
                        (-0.1607270415933377, -0.3880294036547404, 0.26, 1.0, 0.0, 0.44),
                        (0.0000000000000000, -0.4200000000000000, 0.26, 1.0, 0.0, 0.52),
                        (0.1607270415933377, -0.3880294036547404, 0.26, 1.0, 0.0, 0.46),
                        (0.2969848480983499, -0.2969848480983499, 0.26, 1.0, 0.0, 0.50),
                        (0.3880294036547404, -0.1607270415933377, 0.26, 1.0, 0.0, 0.45)]"""

# Tata letak **lama** (8 blob @45°, lebar 0.30) — cacat yang ditutup gerbang.
OLD_LAYOUT = """    "planetaryNebula": [(0.4200000000000000, 0.0000000000000000, 0.30, 1.0, 0.0, 0.54),
                        (0.2969848483038187, 0.2969848483038187, 0.30, 1.0, 0.0, 0.48),
                        (0.0000000000000000, 0.4200000000000000, 0.30, 1.0, 0.0, 0.52),
                        (-0.2969848483038187, 0.2969848483038187, 0.30, 1.0, 0.0, 0.46),
                        (-0.4200000000000000, 0.0000000000000000, 0.30, 1.0, 0.0, 0.50),
                        (-0.2969848483038187, -0.2969848483038187, 0.30, 1.0, 0.0, 0.44),
                        (0.0000000000000000, -0.4200000000000000, 0.30, 1.0, 0.0, 0.53),
                        (0.2969848483038187, -0.2969848483038187, 0.30, 1.0, 0.0, 0.47)]"""


def _with_width(layout, width):
    """Ganti kolom lebar (indeks 2) pada tiap baris tata letak."""
    out = []
    for line in layout.splitlines():
        head, tail = line.split("(", 1)
        fields = tail.split(",")
        fields[2] = f" {width}"
        out.append(head + "(" + ",".join(fields))
    return "\n".join(out)


NARROW = _with_width(OLD_LAYOUT, "0.20")
# 8 titik @45° pada lebar **sekarang** (0.26): blobnya identik dengan kode
# sekarang, yang berbeda hanya jaraknya. Ini mutasi paling tajam — kalau
# gerbang hijau di sini, yang diukurnya ukuran blob, bukan kesinambungan.
CURRENT_WIDTH_OLD_SPACING = _with_width(OLD_LAYOUT, "0.26")

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang
# membuat berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
CONTINUOUS = "cangkang nebula planetari bersambung"


def _checks(verdicts):
    return [name for name in verdicts if name.startswith(CONTINUOUS)]


STATES = [
    # (nama, edit, harapan: nama pemeriksaan -> "hijau"/"merah")
    ("[baseline]", None, None),
    ("1. tata letak lama 8-blob @45°, lebar 0.30",
     [(CURRENT_LAYOUT, OLD_LAYOUT)], "merah"),
    ("2. lebar 0.20 (blob kecil, 8 titik)",
     [(CURRENT_LAYOUT, NARROW)], "merah"),
    ("3. 8 titik @45° pada lebar sekarang (0.26)",
     [(CURRENT_LAYOUT, CURRENT_WIDTH_OLD_SPACING)], "merah"),
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
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        with open(RENDER, "wb") as handle:
            handle.write(original)

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
                    with open(RENDER, "w") as handle:
                        handle.write(source)

            verdicts, error = run_probe()
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            checks = _checks(verdicts)
            if not checks:
                failures.append(f"{name}: tidak ada pemeriksaan "
                                f"'{CONTINUOUS}' di keluaran gerbang")
                print(f"{name}: TIDAK ADA PEMERIKSAAN")
                continue

            if expected is None:
                bad = [c for c in checks if verdicts[c] != "hijau"]
                if bad:
                    failures.append(f"{name}: baseline tidak hijau: {bad}")
                    print(f"{name}: BASELINE TIDAK HIJAU -> {bad}")
                else:
                    print(f"{name}: hijau di {len(checks)} pemeriksaan (benar)")
                continue

            wrong = [c for c in checks if verdicts[c] != expected]
            if wrong:
                for check in wrong:
                    failures.append(f"{name}: '{check}' harus {expected}, "
                                    f"dapat {verdicts[check]}")
                    print(f"{name}: '{check}' harus {expected}, "
                          f"dapat {verdicts[check]}")
            else:
                print(f"{name}: {expected} di {len(checks)} pemeriksaan (benar)")
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
    print("OK: gerbang berbunyi pada setiap cacat, dan hijau saat kode benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
