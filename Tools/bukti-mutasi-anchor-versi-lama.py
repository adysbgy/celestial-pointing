#!/usr/bin/env python3
"""Buktikan `Tools/check-anchor-versi-lama.py` **berbunyi**, bukan sekadar "OK".

Kenapa harness ini ada.

Gerbang yang baru ditulis selalu hijau pada hari ia ditulis, dan itu bukan
bukti apa pun. Gerbang ini punya bentuk kebutaan yang khas: ia membaca AST,
jadi ia bisa hijau karena **tidak menemukan berkas apa pun**, atau karena
detektornya tidak pernah mengenali bentuk cacat yang nyata. Keduanya
menghasilkan keluaran yang sama persis dengan gerbang yang benar: "OK".

Yang diukur, dan kenapa semuanya perlu:

  1. **Cacat nyata yang sudah menjatuhkan `main`.** Dua bentuk yang benar-benar
     ada di riwayat repo ini ditanamkan ke salinan pohon: `subprocess.run([
     "git", "show", ...])` tanpa `safe.directory` (menghasilkan 0 karakter di
     CI → hijau palsu) dan penambat `origin/main` (membandingkan perbaikan
     dengan dirinya sendiri). Gerbang wajib keluar 1 dan **menyebut berkasnya**.

  2. **Kode yang benar harus diam.** Prosa yang menjelaskan kenapa
     `origin/main` salah tidak boleh dianggap cacat — dan itu bukan hiasan:
     kedua harness ini memang memuat penjelasan itu, jadi gerbang yang
     memerah di sana akan memerah pada berkas yang sudah benar, lalu dimatikan
     orang.

  3. **Non-vakuositas.** Gerbang yang tidak menemukan berkas apa pun akan
     mencetak "OK: 0 harness" dan keluar 0. Keadaan 3 memutasi **pola globnya**
     dan menuntut gerbang menghentikan dirinya alih-alih melaporkan sukses
     kosong.

Dijalankan atas **salinan** pohon di direktori sementara, di proses baru:
gerbang yang dijalankan di proses yang sama dengan pemutasi bisa membaca
modul yang sudah di-cache.

Pakai:
    python3 Tools/bukti-mutasi-anchor-versi-lama.py
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GERBANG = os.path.join("Tools", "check-anchor-versi-lama.py")
HARNESS = os.path.join("Tools", "bukti-mutasi-label-bawaan.py")

#: Yang disalin: gerbangnya + harness mutasi + modul bersama (impor gerbang).
COPY = ("Tools",)

#: Bentuk cacat 1: pembacaan git langsung, tanpa `safe.directory`.
CACAT_MENTAH = (
    '    p = subprocess.run(["git", "show", "HEAD:swift-ui-lint.sh"],\n'
    '                       cwd=ROOT, capture_output=True, text=True)\n'
    '    return p.stdout\n'
)
#: Bentuk cacat 2: penambat yang mengikuti cabang.
CACAT_CABANG = (
    '    p = subprocess.run(["git", "show", "origin/main:x"],\n'
    '                       cwd=ROOT, capture_output=True, text=True)\n'
    '    return p.stdout\n'
)


def salin_pohon(dest):
    for rel in COPY:
        src = os.path.join(ROOT, rel)
        dst = os.path.join(dest, rel)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        elif os.path.isfile(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)


def run_gerbang(cwd):
    proc = subprocess.run([sys.executable, GERBANG], cwd=cwd,
                          capture_output=True, text=True, timeout=600)
    return proc.returncode, proc.stdout + proc.stderr


def sisipkan(tmp, teks_baru):
    """Ganti isi `old_lint()` di salinan harness dengan bentuk cacat."""
    path = os.path.join(tmp, HARNESS)
    src = open(path, encoding="utf-8").read()
    m = re.search(r"def old_lint\(\) -> str:.*?\n(    return text\n)", src,
                  re.S)
    if not m:
        return None
    # Sisipkan sebelum `return text`, supaya cacatnya benar-benar dieksekusi.
    patched = src[:m.start(1)] + teks_baru + m.group(1) + src[m.end(1):]
    open(path, "w", encoding="utf-8").write(patched)
    return patched


def main():
    failures = []

    # --- Keadaan 1: pohon utuh (harus hijau) ---
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        code, out = run_gerbang(tmp)
        print("=== Keadaan 1: pohon utuh (harus hijau) ===")
        print(out.strip())
        if code != 0:
            failures.append(
                f"Keadaan 1: gerbang merah pada pohon utuh (exit {code}). "
                "Gerbang yang merah pada kode benar akan dimatikan orang.")

    # --- Keadaan 2 & 3: dua cacat nyata, masing-masing harus merah ---
    for label, teks in [("2. subprocess langsung tanpa safe.directory",
                         CACAT_MENTAH),
                        ("3. penambat origin/main", CACAT_CABANG)]:
        with tempfile.TemporaryDirectory() as tmp:
            salin_pohon(tmp)
            if sisipkan(tmp, teks) is None:
                print(f"FATAL: tidak bisa menyisipkan ke `old_lint()` — "
                      f"harness ini mengukur bentuk yang sudah berubah.")
                return 2
            code, out = run_gerbang(tmp)
            print(f"\n=== Keadaan {label} (harus merah) ===")
            print(out.strip())
            if code == 0:
                failures.append(
                    f"Keadaan {label}: gerbang hijau padahal bentuk "
                    "gagal-terbuka ada di disk. Ini bentuk yang sudah "
                    "menjatuhkan `main`.")
            else:
                if "bukti-mutasi-label-bawaan.py" not in out:
                    failures.append(
                        f"Keadaan {label}: gerbang merah tetapi tidak "
                        "menyebut berkasnya — orang yang membacanya tidak "
                        "tahu apa yang harus diperbaiki.")

    # --- Keadaan 4: non-vakuositas (pola glob dilumpuhkan) ---
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        g = os.path.join(tmp, GERBANG)
        src = open(g, encoding="utf-8").read()
        lumpuh = src.replace('PATTERN = "bukti-mutasi-*.py"',
                             'PATTERN = "tidak-ada-*.py"', 1)
        if lumpuh == src:
            print("FATAL: tidak bisa melumpuhkan pola glob — harness ini "
                  "mengukur bentuk yang sudah berubah.")
            return 2
        open(g, "w", encoding="utf-8").write(lumpuh)
        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 4: pola glob dilumpuhkan (wajib NON-vakuos) ===")
        print(out.strip())
        if code == 0:
            failures.append(
                "Keadaan 4: gerbang melaporkan sukses dengan nol harness "
                "diperiksa — ia hijau karena tidak mengukur apa pun.")

    print()
    if failures:
        print(f"GAGAL: {len(failures)} keadaan tidak sesuai harapan.")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("OK: gerbang berbunyi pada kedua bentuk gagal-terbuka, dan diam "
          "pada pohon yang benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
