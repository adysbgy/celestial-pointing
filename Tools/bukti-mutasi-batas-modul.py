#!/usr/bin/env python3
"""Bukti bahwa gerbang batas modul (`check-batas-modul.py`) bisa berbunyi.

Kenapa harness ini ada.

`Tools/check-batas-modul.py` lahir dari `main` yang merah: `a951cb9` membuat
`jupiterBandEdges` publik, tetapi `BandEdge` di dalam `public extension` yang
sama tetap punya anggota internal. `swift build` atas pohon itu **lulus**
(terukur `BUILD_EXIT=0`), `-enable-library-evolution` juga lulus, dan 77 berkas
uji melihat anggotanya lewat `@testable import` — jadi dari Linux semuanya
hijau sementara `Apple Build` merah dengan empat galat `'halfWidth' is
inaccessible due to 'internal' protection level`.

Gerbang baru yang hijau pada hari ia ditulis tidak membuktikan apa pun. Yang
harus dibuktikan ada tiga, dan ketiganya bisa gagal terpisah:

  1. **Pembaca menemukan bentuk yang menjatuhkan `main`.** `BandEdge` ditulis
     `struct BandEdge` — tanpa kata `public` — di dalam `public extension`.
     Pembaca yang mencari kata `public` di depan `struct` akan melaporkan nol
     temuan, dan nol temuan terbaca sama persis dengan "tidak ada cacat".
  2. **Pembaca memetakan nama pendek ke jalur yang benar.** `CandidateMarker`
     ada dua: `enum CandidateMarker` di akar modul dan
     `VisualFrame.CandidateMarker`. Salah petakan membuat probe menulis nama
     yang tidak ada, lalu gerbang menuduh kode benar.
  3. **Gerbang berbunyi pada pohon yang memang rusak.** Ini yang paling
     penting, dan satu-satunya yang butuh compiler sungguhan: `--fixture`
     tidak bisa membuktikannya, karena akses `internal` tidak terlihat dari
     teks. Karena itu keadaan 3 menjalankan mode penuh atas salinan
     `git show a951cb9` dan menuntut galat `is inaccessible`.

Keadaan 3 dilewati (bukan diluluskan) bila Docker tidak tersedia — dan
"dilewati" dicetak, supaya tidak terbaca sebagai bukti.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GATE = os.path.join(ROOT, "Tools", "check-batas-modul.py")
SOURCES = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit")

#: Commit yang membuat `main` merah. Salinannya dipakai sebagai pohon rusak
#: yang **nyata**, bukan rekaan: cacat yang dibuktikan harus cacat yang pernah
#: terjadi, bukan cacat yang saya bayangkan.
BROKEN_COMMIT = "a951cb9"


def have_docker() -> bool:
    if shutil.which("swiftc"):
        return True
    return shutil.which("docker") is not None


def run_fixture(package_root: str) -> tuple[int, str]:
    """Jalankan mode `--fixture` atas salinan paket di `package_root`."""
    gate = os.path.join(package_root, "Tools", "check-batas-modul.py")
    result = subprocess.run(
        [sys.executable, gate, "--fixture"],
        capture_output=True, text=True, cwd=package_root,
    )
    return result.returncode, (result.stdout or "") + (result.stderr or "")


def copy_tree(commit: str) -> str | None:
    """Salin `Packages/` pada commit tertentu ke direktori sementara."""
    target = tempfile.mkdtemp(prefix="bukti-batas-modul-")
    archive = subprocess.run(
        ["git", "archive", commit, "Packages"],
        capture_output=True, cwd=ROOT,
    )
    if archive.returncode != 0:
        shutil.rmtree(target, ignore_errors=True)
        return None
    extract = subprocess.run(
        ["tar", "-x", "-C", target], input=archive.stdout, capture_output=True,
    )
    if extract.returncode != 0:
        shutil.rmtree(target, ignore_errors=True)
        return None
    os.makedirs(os.path.join(target, "Tools"), exist_ok=True)
    shutil.copy2(GATE, os.path.join(target, "Tools", "check-batas-modul.py"))
    return target


def check(name: str, ok: bool, detail: str = "") -> bool:
    print(f"{'OK  ' if ok else 'SALAH'} {name}")
    if not ok and detail:
        for line in detail.strip().splitlines()[:6]:
            print("      ", line)
    return ok


def main() -> int:
    failures = 0
    current = copy_tree("HEAD")
    broken = copy_tree(BROKEN_COMMIT)
    if current is None or broken is None:
        print("SALAH tidak bisa menyalin pohon dari git")
        return 1

    try:
        # 1. Pembaca menemukan `BandEdge` di dalam `public extension`, dan
        #    mengaitkannya ke `jupiterBandEdges` — bukan sekadar menemukan
        #    tipenya, karena yang menjatuhkan main adalah **penyerahannya**.
        code, out = run_fixture(current)
        found = "CelestialVisual.BandEdge <- jupiterBandEdges" in out
        failures += not check(
            "pembaca menemukan BandEdge di public extension dan mengaitkannya "
            "ke jupiterBandEdges", found, out)

        # 2. Nama pendek dipetakan ke jalur yang benar. `VisualFrame.
        #    CandidateMarker` punya empat anggota; `enum CandidateMarker` di
        #    akar modul tidak punya anggota. Kalau salah petakan, salah satu
        #    dari dua baris ini hilang.
        mapped = (
            "VisualFrame.CandidateMarker <- candidateMarker" in out
            and "anggota VisualFrame.CandidateMarker: ['centerX', 'centerY', 'radius', 'glyphFraction']" in out
        )
        failures += not check(
            "nama pendek CandidateMarker dipetakan ke VisualFrame.CandidateMarker",
            mapped, out)

        # 3. Anggota `BandEdge` terbaca — inilah yang harus disentuh probe.
        members = "anggota CelestialVisual.BandEdge: ['height', 'halfWidth']" in out
        failures += not check(
            "anggota BandEdge (height, halfWidth) terbaca", members, out)

        # 4. Mode penuh atas pohon RUSAK wajib merah, dan merahnya harus
        #    menyebut `is inaccessible` — galat yang sama dengan CI. Merah
        #    karena sebab lain (mis. docker mati) tidak membuktikan apa pun,
        #    jadi diperiksa isinya, bukan cuma kode keluarnya.
        if not have_docker():
            print("LEWAT keadaan 4: Docker tidak tersedia — mode penuh tidak "
                  "dijalankan, jadi akses `internal` TIDAK terbukti di sini")
        else:
            result = subprocess.run(
                [sys.executable, os.path.join(broken, "Tools", "check-batas-modul.py")],
                capture_output=True, text=True, cwd=broken,
            )
            out_broken = (result.stdout or "") + (result.stderr or "")
            spoke = "is inaccessible due to 'internal' protection level" in out_broken
            failures += not check(
                "mode penuh atas a951cb9 merah dengan galat 'is inaccessible'",
                result.returncode != 0 and spoke, out_broken)
    finally:
        for path in (current, broken):
            if path:
                shutil.rmtree(path, ignore_errors=True)

    print()
    if failures:
        print(f"{failures} keadaan tidak sesuai")
        return 1
    print("SEMUA SESUAI: gerbang batas modul berbunyi pada bentuk yang menjatuhkan main")
    return 0


if __name__ == "__main__":
    sys.exit(main())
