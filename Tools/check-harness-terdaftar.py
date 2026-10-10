#!/usr/bin/env python3
"""Setiap harness `bukti-mutasi-*.py` di disk wajib benar-benar dijalankan CI.

Kenapa gerbang ini ada.

Gerbang yang tidak pernah dieksekusi **selalu hijau**, dan ia menutupi persis
cacat yang ditulisnya untuk menangkap — tanpa satu pun jejak di laporan CI.
Itu bukan kemungkinan teoretis di repo ini: `Tools/bukti-mutasi-piringan.py`
ada di disk, isinya benar, membuktikan gerbang "piringan kedua Saturnus"
berbunyi — dan **tidak dirujuk satu pun langkah** di
`.github/workflows/engine-tests.yml`. Tiga belas berkas di disk, dua belas
dirujuk. Selama itu, cacat yang ia tutup (bola 1.0 R bocor di bawah cincin
0.53 R) bisa kembali ke `main` sementara seluruh langkah hijau.

Bentuk kegagalan ini yang membuatnya layak jadi gerbang tersendiri: tidak ada
galat kompilasi, tidak ada langkah merah, tidak ada berkas yang hilang. Yang
salah hanyalah **daftar** — dan daftar tidak diuji siapa pun.

Dua arah diperiksa, dan arah kedua sama pentingnya:

  * harness di disk tetapi tak dirujuk  → gerbangnya tidak pernah berbunyi
  * langkah CI merujuk berkas tak ada   → langkah itu merah di CI karena
                                          sebab yang salah (berkas hilang),
                                          dan orang akan menghapus langkahnya,
                                          bukan memulihkan berkasnya

Gerbang ini juga mengukur **dirinya sendiri**: `_mutate` di bawah dipakai
untuk membuktikan ia bisa merah pada kedua arah, dengan berkas di
`cache`/direktori sementara — bukan berkas produksi. Gerbang baru yang hijau
pada hari ia ditulis tidak membuktikan apa pun; yang harus dibuktikan adalah
bahwa ia **bisa** merah, dan merah pada keadaan yang memang salah.
"""

from __future__ import annotations

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "engine-tests.yml")
TOOLS = os.path.join(ROOT, "Tools")

#: Pola nama harness. Sengaja sempit: yang dijaga adalah harness **mutasi**,
#: bukan setiap skrip di `Tools/` (banyak di antaranya alat, bukan gerbang,
#: dan menuntut alat dijalankan CI akan memaksa langkah yang tidak mengukur
#: apa pun).
PATTERN = "bukti-mutasi-*.py"

#: `python3 Tools/<nama>.py` — bentuk pemanggilan yang dipakai alur kerja.
#: `run:` boleh memuat argumen lain; yang diambil hanya nama berkasnya.
CALL = re.compile(r"Tools/(bukti-mutasi-[A-Za-z0-9_-]+\.py)")


def harness_on_disk():
    """Nama berkas harness mutasi yang ada di `Tools/`, terurut."""
    found = glob.glob(os.path.join(TOOLS, PATTERN))
    return sorted(os.path.basename(path) for path in found)


def harness_referenced(workflow_text):
    """Nama berkas harness mutasi yang disebut alur kerja, terurut unik."""
    return sorted(set(CALL.findall(workflow_text)))


def audit(disk, referenced):
    """Kembalikan daftar masalah; kosong berarti kedua arah sepakat."""
    problems = []
    for name in disk:
        if name not in referenced:
            problems.append(
                f"{name}: ada di Tools/ tetapi tidak dirujuk "
                "engine-tests.yml — gerbangnya tidak pernah dijalankan, dan "
                "gerbang yang tidak dijalankan selalu hijau")
    for name in referenced:
        if name not in disk:
            problems.append(
                f"{name}: dirujuk engine-tests.yml tetapi tidak ada di "
                "Tools/ — langkahnya merah karena berkas hilang, bukan "
                "karena gerbangnya berbunyi")
    return problems


def _mutate(disk, referenced):
    """Dipakai bukti-diri di bawah: jalankan `audit` atas daftar rekaan."""
    return audit(disk, referenced)


def prove_itself():
    """Buktikan `audit` bisa merah pada **kedua** arah, bukan cuma hijau.

    Tanpa ini, `audit` yang selalu mengembalikan daftar kosong — mis. karena
    pola globnya salah dan tidak menemukan berkas apa pun — akan terlihat
    sama persis dengan audit yang benar: nol masalah.
    """
    cases = [
        ("harness di disk tak dirujuk",
         ["bukti-mutasi-a.py", "bukti-mutasi-b.py"], ["bukti-mutasi-a.py"], 1),
        ("langkah CI merujuk berkas hilang",
         ["bukti-mutasi-a.py"], ["bukti-mutasi-a.py", "bukti-mutasi-hantu.py"], 1),
        ("kedua arah sepakat", ["bukti-mutasi-a.py"], ["bukti-mutasi-a.py"], 0),
    ]
    failures = []
    for label, disk, referenced, want in cases:
        got = len(_mutate(disk, referenced))
        mark = "OK  " if got == want else "SALAH"
        if got != want:
            failures.append(f"{label}: {got} masalah, seharusnya {want}")
        print(f"{mark} bukti-diri: {label:38s} {got} masalah (harap {want})")
    return failures


def main():
    with open(WORKFLOW, encoding="utf-8") as handle:
        workflow_text = handle.read()

    disk = harness_on_disk()
    referenced = harness_referenced(workflow_text)
    problems = audit(disk, referenced)

    print(f"harness di Tools/        : {len(disk)}")
    print(f"dirujuk engine-tests.yml : {len(referenced)}")
    for name in disk:
        print(f"  {'OK ' if name in referenced else 'TIDAK DIRUJUK'}  {name}")

    print()
    failures = prove_itself()

    print()
    if problems:
        print(f"{len(problems)} masalah:")
        for item in problems:
            print(f"  - {item}")
    if failures:
        for item in failures:
            print(f"  - {item}")
    if problems or failures:
        return 1

    # Penjaga terakhir: pola glob yang salah akan melaporkan "0 harness, 0
    # masalah" dan terlihat seperti kesuksesan. Kalau disknya kosong, itu
    # bukan hasil yang bersih — itu gerbang yang tidak mengukur apa pun.
    if not disk:
        print("Tidak ada satu pun harness ditemukan — pola globnya salah, "
              "jadi gerbang ini tidak mengukur apa pun.")
        return 1
    print(f"{len(disk)} harness, semuanya dirujuk alur kerja")
    return 0


if __name__ == "__main__":
    sys.exit(main())
