#!/usr/bin/env python3
"""Buktikan gerbang **"keraguan tidak boleh paling terang"** berbunyi.

Kenapa harness ini ada.

`UncertainDeepSkyIsNotTheLoudestTests` menjaga satu sifat: kabut yang tampil
saat engine RAGU memancarkan lebih sedikit cahaya daripada **setiap** morfologi
yang boleh diklaim. Sifat itu bisa patah lewat beberapa jalan yang berbeda, dan
jalan-jalan itu tidak saling menangkap:

  * `deepSky` kembali memanggil `nebula()` untuk `nil`  → kabut ragu identik
    dengan bentuk paling terang (cacat aslinya, terukur 1.197 lawan 0.368)
  * `uncertainFog` sendiri dinaikkan                    → bentuknya benar,
    terangnya salah
  * `nebula()` diturunkan                              → kabut ragu "menang"
    bukan karena ia redup, melainkan karena jawabannya dipadamkan
  * uji berhenti mengukur                             → hijau karena kosong

Keadaan 3 adalah yang paling berharga dan paling mudah terlewat: ia membuat uji
**hijau** sambil memperbaiki hal yang salah. Kalau hanya keadaan 1 dan 2 yang
diuji, harness akan menyatakan sifatnya terjaga padahal jalan pintasnya terbuka.

Kenapa probe menjalankan `swift test`, bukan mengimpor Python. Sifat ini hidup
di **model Swift**; port Python hanya menyalin tata letaknya. Menguji port akan
membuktikan salinan itu, bukan yang dipakai app. Jadi probe menjalankan uji
Swift yang sama dengan yang dijalankan CI, dan menuntutnya **gagal**.

Sumber produksi dimutasi dengan sengaja lalu dipulihkan di `finally` per
keadaan, plus handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup. Penulisan & pemulihan lewat `mutasi_sumber`, sama
seperti harness lain.

Pakai:
    python3 Tools/bukti-mutasi-kabut-ragu.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import shutil
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")
SWIFT_TEST = "UncertainDeepSkyIsNotTheLoudestTests"

# ── Jangkar di dalam model ────────────────────────────────────────────────
# Badan `deepSky` untuk morfologi `nil`, apa adanya. Kalau modelnya dirapikan
# dan jangkar ini tidak lagi cocok, harness **berhenti** — bukan diam-diam
# menguji himpunan kosong.
CURRENT_FALLBACK = """            return uncertainFog(fuzziness: fuzziness,
                                frameHalfExtent: frameHalfExtent)"""

# 1. Cacat aslinya: kabut ragu kembali memakai bentuk nebula emisi.
OLD_FALLBACK = """            return nebula(fuzziness: fuzziness,
                                frameHalfExtent: frameHalfExtent)"""

# 2. Bentuknya benar tetapi terangnya dinaikkan: opasitas kabut ragu dinaikkan
#    sampai melewati morfologi paling redup. Ini menguji **ambang**, bukan
#    sekadar identitas fungsi.
CURRENT_FOG_OPACITY = """        let layout: [(Double, Double, Double, Double, Double, Double)] = [
            // (offsetX, offsetY, skala lebar, rasio sumbu, sudut°, opasitas)
            ( 0.00,  0.00, 0.34, 1.0, 0.0, 0.14),
            ( 0.10,  0.06, 0.26, 1.0, 0.0, 0.10),
            (-0.08, -0.05, 0.20, 1.0, 0.0, 0.11)
        ]"""

LOUD_FOG_OPACITY = """        let layout: [(Double, Double, Double, Double, Double, Double)] = [
            // (offsetX, offsetY, skala lebar, rasio sumbu, sudut°, opasitas)
            ( 0.00,  0.00, 0.34, 1.0, 0.0, 0.90),
            ( 0.10,  0.06, 0.26, 1.0, 0.0, 0.90),
            (-0.08, -0.05, 0.20, 1.0, 0.0, 0.90)
        ]"""

STATES = [
    ("0. baseline (tanpa mutasi)",
     None, True),
    ("1. deepSky(nil) kembali memakai nebula() — cacat aslinya",
     [(CURRENT_FALLBACK, OLD_FALLBACK)], True),
    ("2. uncertainFog dinaikkan sampai mengalahkan morfologi paling redup",
     [(CURRENT_FOG_OPACITY, LOUD_FOG_OPACITY)], True),
]


def run_swift():
    """Jalankan uji Swift-nya. → (dijalankan, gagal, detail).

    `swift` dipakai langsung bila ada di PATH (itulah yang terjadi di CI, yang
    berjalan di dalam citra `swift:6.0`). Di VPS ini tidak ada Swift, hanya
    Docker — jalur keduanya memakai citra yang sama lewat `swift-test.sh`
    supaya yang diukur tetap toolchain yang sama.
    """
    if shutil.which("swift"):
        cmd = ["swift", "test", "--package-path", "Packages/PointingKit",
               "--filter", SWIFT_TEST]
        how = "swift langsung"
    elif shutil.which("docker"):
        cmd = ["sudo", "-n", "docker", "run", "--rm", "-v", f"{ROOT}:/src",
               "-w", "/src/Packages/PointingKit", "swift:6.0",
               "swift", "test", "--filter", SWIFT_TEST]
        how = "docker swift:6.0"
    else:
        return False, False, "dilewati: tidak ada `swift` maupun `docker`"

    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                         timeout=1800)
    text = (out.stdout or "") + (out.stderr or "")
    failed = out.returncode != 0 and SWIFT_TEST in text
    detail = (f"{how}: {'gagal seperti dituntut' if failed else 'LULUS'}"
              f" (exit {out.returncode})")
    if not failed:
        tail = [l for l in text.splitlines() if "error:" in l][:2]
        detail += "; " + (" | ".join(tail) if tail else text.strip()[-200:])
    return True, failed, detail


def main():
    mutasi_sumber.require_clean_sources([MODEL])
    original = open(MODEL, "rb").read()
    md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        mutasi_sumber.restore_verified(MODEL, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expect_red in STATES:
            if edits is None:
                ran, failed, detail = run_swift()
            else:
                for find, replace in edits:
                    text = open(MODEL, encoding="utf-8").read()
                    if text.count(find) != 1:
                        raise SystemExit(
                            f"{name}: jangkar tidak unik ({text.count(find)}×). "
                            "Model berubah; perbarui harness ini, jangan "
                            "melonggarkan ujinya.")
                    mutasi_sumber.write_source(MODEL,
                                               text.replace(find, replace))
                ran, failed, detail = run_swift()
                restore()
                if hashlib.md5(open(MODEL, "rb").read()).hexdigest() != md5:
                    raise SystemExit(f"{name}: pemulihan gagal")

            if not ran:
                print(f"  {name}: {detail}")
                failures.append(f"{name}: {detail}")
                continue

            ok = (failed == expect_red)
            mark = "OK  " if ok else "SALAH"
            print(f"  {mark} {name}  | {detail}")
            if not ok:
                failures.append(
                    f"{name}: uji {'tidak' if expect_red else ''} berbunyi "
                    f"padahal {'seharusnya' if expect_red else 'tidak boleh'}")
    finally:
        restore()

    if failures:
        print("\n== GERBANG KABUT RAGU TIDAK TERBUKTI ==")
        for f in failures:
            print("  - " + f)
        return 1
    print("\n== semua keadaan sesuai harapan: uji ini menangkap cacatnya ==")
    return 0


if __name__ == "__main__":
    sys.exit(main())
