#!/usr/bin/env python3
"""Bukti bahwa `Tools/check-jangkar-harness.py` **berbunyi**, bukan sekadar mencetak "OK".

Gerbang tanpa saksi adalah gerbang yang tidak diketahui bisa merah. Di repo ini
"hijau sejak hari ditulis" berkali-kali berarti "tidak mengukur apa pun", dan
gerbang jangkar punya bentuk kebutaan yang khas: ia membandingkan **teks**, jadi
ia bisa hijau karena berkasnya tidak berubah, bukan karena tidak ada mutasi
tertinggal.

Yang diukur di sini, dan kenapa ketiganya perlu:

  1. **Mutasi bocor yang nyata** — nilai model diganti persis dengan `replace`
     milik sebuah keadaan harness (`clusterCoreBrighten: Double = 0.25` ->
     `0.0`). Ini bentuk yang sudah dua kali mendarat di `main`. Gerbang wajib
     keluar 1 dan **menyebut harness-nya**; "ada yang merah" tidak cukup,
     karena keluaran gerbang ini juga memuat baris "jangkar hilang", dan baris
     itu **bukan** temuan.

  2. **Kode yang benar harus diam.** Menyunting sumber secara sah (mis. nilai
     yang berbeda dari kedua sisi mutasi) tidak boleh merah. Gerbang yang
     merah pada pohon bersih adalah gerbang yang akan dimatikan orang, dan
     setelah dimatikan ia tidak menjaga apa pun.

  3. **Non-vakuositas.** Gerbang ini membaca `STATES` dari AST. Kalau
     pembacanya rusak sehingga tidak menemukan satu pun pasangan, ia akan
     mencetak "0 jangkar" dan keluar 0 — hijau dengan alasan yang salah.
     Keadaan 3 memutasi **pembacanya**, bukan sumbernya, dan menuntut gerbang
     menghentikan dirinya alih-alih melaporkan sukses kosong.

Menjalankan gerbang ini atas salinan pohon di direktori sementara, di proses
baru: gerbang yang dijalankan di dalam proses yang sama dengan pemutasi bisa
membaca modul yang sudah di-cache, dan itu jenis pengukuran yang salah modul
yang sudah pernah menipu sesi ini.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GERBANG = os.path.join("Tools", "check-jangkar-harness.py")
MODEL = os.path.join("Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")

MODEL_ANCHOR = "clusterCoreBrighten: Double = 0.25"
MODEL_LEAKED = "clusterCoreBrighten: Double = 0.0"

#: Berkas yang ikut disalin: cukup untuk gerbang (AST `STATES` + sumber sasaran).
#: Salinan parsial membuat gerbang melaporkan "TAK TERBACA" untuk berkas yang
#: tidak disalin; itu bukan temuan, dan menuntutnya merah akan mengukur
#: kelengkapan salinan, bukan gerbangnya.
COPY = (
    "Tools",
    "Packages/PointingKit/Sources/PointingKit",
    "Apps/Shared",
    "Apps/PointAndKnowWatch/Sources",
)


def run_gerbang(cwd):
    proc = subprocess.run([sys.executable, GERBANG], cwd=cwd,
                          capture_output=True, text=True, timeout=600)
    return proc.returncode, proc.stdout + proc.stderr


def salin_pohon(dest):
    for rel in COPY:
        src = os.path.join(ROOT, rel)
        dst = os.path.join(dest, rel)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        elif os.path.isfile(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)


def main():
    failures = []

    # --- Keadaan 1 & 2: pohon utuh, lalu mutasi bocor nyata ditanamkan. ---
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        model = os.path.join(tmp, MODEL)

        code, out = run_gerbang(tmp)
        print("=== Keadaan 1: pohon utuh (harus hijau) ===")
        print(out.strip())
        if code != 0:
            failures.append(
                f"Keadaan 1: gerbang merah pada pohon utuh (exit {code}). "
                "Gerbang yang merah pada kode benar akan dimatikan orang.")

        text = open(model, encoding="utf-8").read()
        if MODEL_ANCHOR not in text:
            print(f"FATAL: jangkar {MODEL_ANCHOR!r} tidak ada di {MODEL} — "
                  "harness ini mengukur nilai yang sudah bergeser.")
            return 2
        open(model, "w", encoding="utf-8").write(
            text.replace(MODEL_ANCHOR, MODEL_LEAKED, 1))

        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 2: mutasi bocor ditanamkan (harus merah) ===")
        print(out.strip())
        if code == 0:
            failures.append(
                "Keadaan 2: gerbang hijau padahal nilai model sama persis "
                "dengan `replace` sebuah keadaan harness. Ini bentuk cacat "
                "yang sudah dua kali mendarat di `main`.")
        else:
            if "MUTASI BOCOR" not in out:
                failures.append(
                    "Keadaan 2: gerbang merah, tetapi tidak menyebut "
                    "'MUTASI BOCOR' — merah karena sebab lain, bukan karena "
                    "mutasi tertinggal.")
            if MODEL_LEAKED not in out:
                failures.append(
                    "Keadaan 2: gerbang tidak menyebut nilai yang bocor, jadi "
                    "orang yang membacanya tidak tahu apa yang harus "
                    "dipulihkan.")

    # --- Keadaan 3: pembaca jangkar dilumpuhkan (non-vakuositas). ---
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        g = os.path.join(tmp, GERBANG)
        src = open(g, encoding="utf-8").read()
        # Lumpuhkan pengumpulan pasangan: gerbang lalu memeriksa nol jangkar.
        # Bentuk ini yang paling berbahaya — ia tetap mencetak "OK".
        lumpuh = re.sub(r"(def _collect_edits\(tree, consts\):\n)",
                        r"\1    return []\n", src, count=1)
        if lumpuh == src:
            print("FATAL: tidak bisa melumpuhkan `_collect_edits` — harness "
                  "ini mengukur bentuk yang sudah berubah.")
            return 2
        open(g, "w", encoding="utf-8").write(lumpuh)

        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 3: pembaca jangkar dilumpuhkan (wajib NON-vakuos) ===")
        print(out.strip())
        if code == 0 and "0 jangkar" in out:
            failures.append(
                "Keadaan 3: gerbang melaporkan sukses dengan nol jangkar "
                "diperiksa. Ia hijau karena tidak mengukur apa pun.")
        if "0 jangkar" not in out and code == 0:
            # Bukan kegagalan keras, tapi harus terlihat: artinya pelumpuhan
            # tidak sampai ke jalur yang diukur.
            print("CATATAN: pelumpuhan tidak terlihat di keluaran — cakupan "
                  "keadaan ini perlu diperiksa.")

    print()
    if failures:
        print(f"GAGAL: {len(failures)} keadaan tidak sesuai harapan.")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("OK: gerbang jangkar berbunyi pada mutasi bocor, dan diam pada "
          "pohon yang benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
