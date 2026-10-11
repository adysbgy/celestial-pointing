#!/usr/bin/env python3
"""Buktikan gerbang Aturan 31 (kawat sudut sisi terang) **berbunyi**.

Kelas cacat yang ditutup: `brightLimbAngleRadians` di
`Apps/Shared/PointingEngine.swift` -- kawat sudut sisi terang untuk planet
berfase. Versi pertama Aturan 31 mengutip jalur ini di komentarnya
(`planetBrightLimbAngles` "dihitung tiap 30 detik, lalu tidak pernah dipakai
gambar apa pun") tetapi hanya mengukur kawat `waxing`. Diukur: mematikan
kawat sudut membuat seluruh 31 aturan UI tetap hijau, sementara 10.254 dari
40.000 piksel (25,6%) sabit Venus berubah -- sisi terangnya berhenti
menghadap Matahari.

Dua bentuk cacat diuji, karena bentuk kedua yang paling mungkin terjadi saat
menyunting: argumennya di-`nil`-kan, dan nilainya di-`nil`-kan di baris
penugasan dengan argumen tetap utuh.

**Dua kesalahan pengukuran di harness ini sendiri, keduanya tertangkap
sebelum push.**

  1. Versi pertama menyalin seluruh pohon repo ke sandbox lalu menjalankan
     `swift-ui-lint.sh` di sana, dan menganggap **keluar != 0** sebagai
     "gerbang berbunyi". Lint itu butuh `project.yml` (dan berkas lain) yang
     tidak ikut tersalin, jadi ia **crash** -- dan crash itu terbaca sebagai
     "berbunyi" untuk kedua keadaan mutasi. Keadaan 1 dan 2 tampak OK
     padahal yang diukur adalah lint yang gagal start, bukan gerbang yang
     menangkap mutasinya. Ini persis kelas cacat yang sudah berulang di repo
     ini: gerbang yang merah karena sebab lain daripada yang diklaimnya.
     Harness ini karena itu **mengekstrak program Aturan 31 itu sendiri**
     dari `swift-ui-lint.sh` dan menjalankannya langsung, sehingga tidak ada
     pra-syarat lain yang bisa menggagalkannya -- dan `returncode != 0`
     sekarang berarti **galat**, bukan "berbunyi".

  2. Keluaran bersih/kotor ditentukan dengan mencari string penanda di
     keluaran lint. Program Aturan 31 mencetak daftar masalah atau **string
     kosong**, jadi yang dibaca sekarang adalah stdout-nya langsung.

Harness ini **tidak** memutasi sumber produksi (berbeda dari
`bukti-mutasi-cembung-mengecil.py`): yang diuji adalah program pemeriksa di
dalam `swift-ui-lint.sh`, dijalankan terhadap salinan `PointingEngine.swift`
yang dimutasi di **direktori sementara**. Sumber repo tidak pernah tersentuh,
jadi tidak ada pemulihan yang bisa gagal.

Pakai:
    python3 Tools/bukti-mutasi-aturan31-sudut.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")
WIRE = os.path.join("Apps", "Shared", "PointingEngine.swift")

#: Jangkar di kawat: satu baris yang menyalurkan sudut sisi terang ke gambar.
ANCHOR_ARG = "brightLimbAngleRadians: isMoon ? limbAngle : planetLimbAngle"
ANCHOR_BINDING = "let planetLimbAngle = planet.flatMap { planetBrightLimbAngles[$0] }"

#: Keadaan: (nama, (cari, ganti) atau None untuk baseline).
STATES = [
    ("[baseline]", None),
    ("1. argumen sudut -> nil",
     (ANCHOR_ARG, "brightLimbAngleRadians: isMoon ? limbAngle : nil")),
    ("2. binding sudut -> nil (argumen utuh)",
     (ANCHOR_BINDING, "let planetLimbAngle: Double? = nil")),
]

#: Pembuka blok program Aturan 31 di dalam `swift-ui-lint.sh`.
BLOCK_OPEN = "waxing=$(python3 - <<'PY' 2>&1"


def extract_rule_program() -> str:
    """Ambil program Python Aturan 31 dari `swift-ui-lint.sh`.

    Diambil sebagai **teks**, bukan dengan menjalankan seluruh lint: lint itu
    punya pra-syarat lain (`project.yml`, aturan 1..30) yang tidak ada
    hubungannya dengan yang diuji di sini, dan kegagalan pra-syarat itulah
    yang dulu terbaca palsu sebagai "gerbang berbunyi".
    """
    lines = open(LINT, encoding="utf-8").read().splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() == BLOCK_OPEN:
            start = i + 1
            break
    if start is None:
        raise SystemExit("GERBANG: pembuka program Aturan 31 tidak ditemukan "
                         f"di {LINT} — harness tidak boleh jalan.")
    for j in range(start, len(lines)):
        if lines[j].rstrip() == "PY":
            return "\n".join(lines[start:j])
    raise SystemExit("GERBANG: penutup program Aturan 31 (`PY`) tidak "
                     "ditemukan — harness tidak boleh jalan.")


def run_rule(sandbox: str, program: str) -> tuple[bool, str]:
    """Jalankan program Aturan 31 di sandbox; kembalikan (bersih?, keluaran).

    `returncode != 0` berarti programnya **galat**, bukan gerbang berbunyi:
    galat dibedakan dari temuan supaya kegagalan menjalankan gerbang tidak
    pernah terbaca sebagai gerbang yang menangkap cacat.
    """
    proc = subprocess.run([sys.executable, "-c", program],
                          capture_output=True, text=True, cwd=sandbox)
    if proc.returncode != 0:
        tail = (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
        return False, f"GALAT menjalankan gerbang: {tail}"
    return proc.stdout.strip() == "", proc.stdout.strip()


def main() -> int:
    program = extract_rule_program()
    original = open(os.path.join(ROOT, WIRE), encoding="utf-8").read()
    for anchor, label in ((ANCHOR_ARG, "argumen sudut"),
                          (ANCHOR_BINDING, "penugasan planetLimbAngle")):
        count = original.count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x "
                  "— harness tidak boleh jalan.", file=sys.stderr)
            return 2

    failures = []
    for label, mutation in STATES:
        sandbox = tempfile.mkdtemp(prefix="aturan31-")
        try:
            target = os.path.join(sandbox, WIRE)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            content = original
            if mutation is not None:
                old, new = mutation
                if old not in content:
                    failures.append(f"{label}: ANCHOR TIDAK DITEMUKAN: {old!r}")
                    print(f"SALAH {label}: jangkar tidak ditemukan")
                    continue
                content = content.replace(old, new, 1)
            with open(target, "w", encoding="utf-8") as handle:
                handle.write(content)

            clean, detail = run_rule(sandbox, program)
            if detail.startswith("GALAT"):
                failures.append(f"{label}: {detail}")
                print(f"SALAH {label}: {detail}")
            elif mutation is None:
                if clean:
                    print(f"OK   {label:44s} bersih")
                else:
                    failures.append(f"{label}: merah pada kode benar")
                    print(f"SALAH {label}: gerbang merah pada kode benar:\n{detail}")
            else:
                if clean:
                    failures.append(f"{label}: gerbang TIDAK berbunyi")
                    print(f"SALAH {label}: gerbang tetap hijau padahal kawat "
                          "sudut sudah mati")
                else:
                    print(f"OK   {label:44s} berbunyi")
                    for line in detail.splitlines()[:4]:
                        print(f"       {line}")
        finally:
            shutil.rmtree(sandbox, ignore_errors=True)

    print()
    if failures:
        print(f"{len(failures)} keadaan tidak sesuai harapan:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
