#!/usr/bin/env python3
"""Bukti mutasi: gerbang jangkar WAJIB merah terhadap jangkar basi yang
hanya hidup di berkas harness itu sendiri.

Kelas cacat yang dijaga di sini: sebuah harness menyimpan jangkar yang
bentuknya sudah tidak ada lagi di sumber produksi. Selama teks itu masih
**ada di berkas harnessnya sendiri**, gerbang jangkar menjawab "jangkar
masih ada" -- karena kandidatnya seluruh berkas sumber, termasuk
`Tools/bukti-mutasi-*.py` tempat pasangan (jangkar, pengganti) itu
dituliskan. Jangkar basi karena itu tidak pernah terlihat, dan harness
yang memakainya memerah pada pohon sehat tanpa satu pun mutasinya
terbukti mendarat.

Bentuk ini nyata, bukan karangan: `Tools/bukti-mutasi-bintang.py` keadaan 2
memakai jangkar `star_geometry(kw.get("relative_size", 0.5))` yang sudah
digantikan `drawable_star_size(...)` --- dan gerbang jangkar mencetak
"OK: 499 jangkar; tidak ada mutasi tertinggal" atas keduanya.

Yang TIDAK diklaim: keadaan di sini memakai jangkar tiruan, bukan jangkar
harvest repo supaya ukurnannya tetap stabil kalau suntingan lain bergeser.
Yang diukur urutan "harness mengeluarkan jangkar baru" -> "sumber
produksi berubah" -> "gerbang harus merah".
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TARGET = "Tools/bukti-mutasi-uji-jangkar-basi.py"
GATE = "Tools/check-jangkar-harness.py"

#: Jangkar yang **tidak** ada di `Tools/render-visuals.py` -- sengaja bukan
#: bentuk apa pun yang dipakai kode hari ini, supaya keadaan ini mengukur
#: kelas cacatnya, bukan teks yang kebetulan masih cocok.
ANCHOR = "JANGKAR_YANG_TIDAK_ADA_DI_PRODUKSI = 3.5"
REPLACEMENT = "JANGKAR_YANG_TIDAK_ADA_DI_PRODUKSI = 3.5\n" + "x" * 40

HARVEST_TEMPLATE = '''from __future__ import annotations

# Keadaan uji jangkar basi: pasangan di bawah hanya bisa ditemukan di berkas
# ini sendiri, sehingga ia meniru bentuk cacat asli secara tepat. Ditulis
# sebagai literal (bukan dirakit saat jalan) supaya gerbang bisa membacanya
# secara statis -- kalau tidak, keadaan 0 tidak membuktikan apa pun.

STATES = [
    ("jangkar hanya hidup di harness",
     ("JANGKAR_YANG_TIDAK_ADA_DI_PRODUKSI = 3.5",
      "JANGKAR_YANG_TIDAK_ADA_DI_PRODUKSI = 3.5\\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")),
]
'''


def run_python(*args):
    return subprocess.run([sys.executable, *args],
                          cwd=ROOT, capture_output=True, text=True)


def main() -> int:
    print("=" * 72)
    print("Gerbang jangkar vs jangkar BASI yang hanya hidup di berkas harness")
    print("=" * 72)

    failures = []

    # --- Keadaan 0: harness baru menyumbang jangkar (sanity, WAJIB HIJAU) ---
    #
    # Tanpa ini, merah di keadaan 1 bisa berarti "harnessnya tidak terbaca
    # sama sekali" -- yang bukan cacat jangkar basi.
    with tempfile.TemporaryDirectory() as tmp:
        salin(tmp)
        # Keadaan 0 mengukur pohon yang **tidak** memuat harness tiruan ini:
        # gerbang harus hijau atas pohon yang benar. Kalau harness tiruan
        # ikut disalin, jangkar buatannya sendiri sudah membuat hijau itu
        # tidak berarti apa pun.
        os.remove(os.path.join(tmp, TARGET))
        code, out = run_gate(tmp)

        print("\n=== Keadaan 0: pohon tanpa harness tiruan ini "
              "(wajib HIJAU) ===")
        print(out.strip()[-400:])
        if code != 0:
            failures.append(
                "Keadaan 0: gerbang merah pada pohon bersih, jadi merah di "
                "keadaan 1 tidak bisa dibaca -- merah yang sama juga "
                "dihasilkan oleh berkas lain yang harus diperbaiki.")

    # --- Keadaan 1: sumber produksi berubah, jangkar ikut usang (MERAH) ---
    #
    # `render-visuals.py` (produksi) tidak memuat jangkar sama sekali:
    # satu-satunya berkas yang memuatnya adalah harness-nya sendiri. Inilah
    # bentuk persis yang membuat `bukti-mutasi-bintang.py` keadaan 2 diam.
    with tempfile.TemporaryDirectory() as tmp:
        salin(tmp)
        code, out = run_gate(tmp)

        print("\n=== Keadaan 1: jangkar hanya ada di berkas harness "
              "(wajib MERAH) ===")
        print(out.strip()[-400:])
        if code == 0:
            failures.append(
                "Keadaan 1: gerbang HIJAU padahal jangkar "
                f"{ANCHOR!r} tidak ada di sumber produksi mana pun. "
                "Jangkar basi yang masih hidup di berkas harnessnya sendiri "
                "terhitung 'masih ada', sehingga mutasinya tidak pernah "
                "terbukti mendarat -- bentuk yang memerahkan "
                "`bukti-mutasi-bintang.py` keadaan 2 pada pohon sehat.")
        else:
            if TARGET.split("/")[-1] not in out:
                failures.append(
                    "Keadaan 1: gerbang merah tanpa menyebut harness yang "
                    "memakai jangkar basi, jadi pembaca tahu ada yang salah "
                    "tetapi tidak tahu berkas mana yang harus diperbaiki.")
            if "harness" not in out.lower():
                failures.append(
                    "Keadaan 1: merah tanpa menyebut kata 'harness'. Merah "
                    "yang tidak menyebut sebabnya akan diperlakukan sebagai "
                    "noise dan dimatikan.")

    print()
    if failures:
        print(f"GAGAL: {len(failures)} keadaan tidak sesuai harapan.")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("OK: gerbang jangkar memerah pada jangkar basi yang hanya hidup "
          "di berkas harness, dan diam pada pohon yang benar.")
    return 0


def salin(tmp: str) -> None:
    """Salin pohon repo, lalu pasang harness tiruan dengan jangkar basinya.

    Salin **pohon kerja**, bukan `git archive HEAD`: yang diukur adalah
    gerbang yang sedang dikerjakan, dan mereproduksi cacatnya memakai gerbang
    dari commit sebelumnya akan mengukur kode mati.

    Tidak ada berkas produksi yang disunting: jangkar keadaan ini memang
    tidak ada di sumber produksi mana pun, itulah cacad yang diukur.
    Menyunting `render-visuals.py` (misalnya) akan memecahkan jangkar
    harness lain dan memerahkan gerbang karena sebab yang lain.
    """
    pohon = subprocess.run(
        ["tar", "-c", "--exclude=.git", "--exclude=.build", "-C", ROOT, "."],
        capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", tmp], input=pohon, check=True)
    target = os.path.join(tmp, TARGET)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as f:
        f.write(HARVEST_TEMPLATE)


def run_gate(tmp: str):
    hasil = subprocess.run(
        [sys.executable, "Tools/check-jangkar-harness.py"],
        cwd=tmp, capture_output=True, text=True)
    return hasil.returncode, (hasil.stdout + hasil.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
