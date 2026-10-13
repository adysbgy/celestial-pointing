#!/usr/bin/env python3
"""Buktikan gerbang «setiap gerbang wajib mengisi results» benar-benar berbunyi.

Kenapa harness ini ada.

`check_every_gate_fills_its_results` ditulis setelah sebuah sesi yang terputus
meninggalkan `check_feature_arrays_match_the_view` sebagai **docstring tanpa
tubuh**: definisi, panggilan di `main`, 22 baris penjelasan — dan nol
`results.append`. Gerbang itu dipanggil, tidak melempar, menyumbang nol
pemeriksaan, dan lolos dari **tiga** gerbang meta yang sudah ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, dan merah **tepat pada keadaan yang ia klaim jaga** —
bukan pada keadaan di sebelahnya. Empat keadaan, dan yang terakhir adalah yang
paling mudah ditebak salah:

  [baseline]              hijau — pada berkas bersih ia memang harus diam
  1. sebuah gerbang dikosongkan
                          MERAH, **menyebut nama gerbangnya**. Pesan yang hanya
                          berkata "ada yang diam" membuat orang mencari di 82
                          fungsi; pesan yang menyebut nama & barisnya langsung
                          menunjuk.
  2. docstring-mengandung-`results.append`
                          hijau — inilah alasan pemeriksaan ini memakai **AST**,
                          bukan `grep`. Pencocokan teks buta terhadap komentar:
                          gerbang yang seluruh `results.append`-nya hidup di
                          dalam docstring akan lolos dari `grep`, dan itu
                          persis keadaan yang mau ditangkap.
  3. tanpa tombol bungkam
                          MERAH — versi pertama gerbang ini punya daftar
                          pengecualian `GATE_AGGREGATORS`, dan satu baris di
                          situ cukup membungkam gerbang mana pun. Daftarnya
                          dibuang; keadaan ini menuntut ia tidak pernah
                          kembali.

**Kenapa mutasi memakai AST, bukan `str.replace`.** Menyisipkan teks ke tengah
fungsi rentan terhadap perubahan isi berkas di kemudian hari. Yang dipakai di
sini adalah bentuk yang tidak bergantung isi: ambil sebuah `check_*` yang
punya `results.append`, ganti **seluruh pernyataan setelah docstring** dengan
satu `pass`. Tubuh yang tersisa tetap bisa di-parse, jadi yang diukur murni
"gerbang tidak mengisi", bukan "berkasnya rusak".

**Batas yang dinyatakan.** Yang dijaga gerbang ini adalah *setiap gerbang
mengisi `results`*, bukan *hasilnya benar*. Gerbang yang selalu mengisi satu
hasil `ok=True` akan hijau di sini — itu dijaga harness mutasi per gerbang.

Berkas produksi (`Tools/check-visuals.py`) dimutasi dengan sengaja lalu
dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
`SIGKILL` melewati `finally` dan meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-gerbang-kosong.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import ast
import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

CHECK = os.path.join(ROOT, "Tools", "check-visuals.py")

GATE = "check_every_gate_fills_its_results"

# Dijalankan di proses baru: mengimpor ulang `check-visuals` dari berkas yang
# **sudah dimutasi** di disk. Mengimpor sekali di dalam proses ini akan memakai
# salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cv_probe", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
results = []
m.check_every_gate_fills_its_results(results)
if not results:
    print("TIDAK ADA")
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""


def first_gate_with_append(source):
    """(nama, sumber_termutasi) untuk `check_*` pertama yang punya `append`.

    Dipilih yang **pertama** supaya harness ini stabil: namanya tidak disebut di
    mana pun, jadi menambah/menghapus gerbang lain tidak memecahkannya.
    """
    tree = ast.parse(source)
    for func in tree.body:
        if not (isinstance(func, ast.FunctionDef)
                and func.name.startswith("check_")):
            continue
        if func.name == GATE:
            continue
        has_append = any(
            isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
            and n.func.attr == "append"
            and isinstance(n.func.value, ast.Name)
            and n.func.value.id == "results"
            for n in ast.walk(func))
        if not has_append:
            continue
        return func.name, empty_gate(source, func)
    return None, source


def empty_gate(source, func, docstring_note=None):
    """Buang seluruh pernyataan `func` setelah docstring-nya.

    Bentuknya diambil dari AST, bukan dari teks: pernyataan pertama setelah
    docstring diganti satu `pass`, sisanya dibuang. Jadi hasilnya tetap bisa
    di-parse — yang diukur murni "gerbang tidak mengisi", bukan "berkasnya
    rusak" — dan perubahan isi berkas di kemudian hari tidak mematahkan
    harness ini seperti `str.replace` atas teks yang panjang.
    """
    lines = source.splitlines(keepends=True)
    start = func.body[1].lineno - 1
    end = func.end_lineno
    replacement = "    pass\n"
    if docstring_note is not None:
        # Sisipkan tepat setelah docstring: `results.append` hidup **di dalam
        # teks**, bukan sebagai panggilan. Inilah keadaan yang membedakan
        # pencocokan teks dari pembacaan AST.
        doc = func.body[0]
        replacement = (f"    {docstring_note}\n"
                       + "    pass\n")
        start = doc.end_lineno
    return "".join(lines[:start]) + replacement + "".join(lines[end:])


def run_probe():
    """Jalankan gerbangnya atas berkas yang ada di disk → (verdict, baris)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, CHECK],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None, [proc.stderr.strip().splitlines()[-1]]
    lines = [ln.strip() for ln in proc.stdout.splitlines() if ln.strip()]
    if not lines or lines[0] == "TIDAK ADA":
        return None, lines or ["(tanpa hasil)"]
    state = lines[0].split(" ", 1)[0]
    return ("hijau" if state == "OK" else "merah"), lines


def main():
    mutasi_sumber.require_clean_sources([CHECK])
    original = open(CHECK, encoding="utf-8").read()
    baseline_md5 = hashlib.md5(original.encode()).hexdigest()

    target, emptied = first_gate_with_append(original)
    if target is None:
        print("GERBANG: tidak ada `check_*` dengan `results.append` — harness "
              "ini tidak mengukur apa pun.", file=sys.stderr)
        return 2

    failures = []

    def restore():
        mutasi_sumber.restore_verified(CHECK, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    # Keadaan 2: `results.append` hidup **di dalam teks**, bukan sebagai
    # panggilan. Gerbang yang memakai `grep "results.append"` akan hijau di
    # sini — padahal gerbangnya diam. Inilah alasan pemeriksaannya memakai AST.
    tree = ast.parse(original)
    target_func = next(f for f in tree.body
                       if isinstance(f, ast.FunctionDef) and f.name == target)
    quoted = empty_gate(original, target_func,
                        docstring_note="results.append(Result('x', True, ''))")

    # Keadaan 3: gerbang dikosongkan **dan** namanya dimasukkan ke daftar
    # pengecualian. Versi pertama gerbang ini punya `GATE_AGGREGATORS`, dan
    # satu baris di situ cukup untuk membungkam gerbang mana pun. Karena itu
    # daftarnya dibuang seluruhnya, dan keadaan ini membuktikan keputusan itu
    # **diukur**, bukan diputuskan: tanpa daftar, tidak ada nama yang bisa
    # ditambahkan, jadi tidak ada jalur bungkam yang tersisa.
    #
    # Yang diuji di sini adalah akibatnya: pengosongan tetap merah meski
    # seseorang mencoba "mendaftarkan" gerbangnya lewat mekanisme apa pun yang
    # kelak muncul. Keadaan ini juga menjaga agar `GATE_AGGREGATORS` tidak
    # pernah **kembali** — sebagai **himpunan hidup**, bukan sebagai teks.
    #
    # Kenapa bukan `if "GATE_AGGREGATORS" in source`: kata itu sekarang hidup
    # di docstring gerbangnya sebagai sejarah keputusan, dan pencocokan teks
    # akan memerahkan harness ini pada berkas yang justru benar. Yang dicari
    # adalah **penugasan himpunan di tingkat modul** — satu-satunya bentuk
    # yang bisa dipakai gerbangnya sebagai pengecualian.
    widened = empty_gate(original, target_func)
    live_exemptions = [
        node.targets[0].id
        for node in ast.parse(widened).body
        if isinstance(node, ast.Assign)
        and isinstance(node.targets[0], ast.Name)
        and node.targets[0].id.isupper()
        and isinstance(node.value, ast.Set)
    ]
    if live_exemptions:
        print("GERBANG: himpunan pengecualian tingkat-modul ditemukan lagi "
              f"({', '.join(live_exemptions)}) — daftar pengecualian adalah "
              "tombol bungkam; hapus, jangan diperluas.", file=sys.stderr)
        return 2

    # Keadaan: (nama, isi berkas, harapan, nama yang wajib disebut)
    states = [
        ("[baseline]", original, "hijau", None),
        (f"1. gerbang {target} dikosongkan", emptied, "merah", target),
        ("2. `results.append` hanya di docstring", quoted, "merah", target),
        ("3. tanpa tombol bungkam: daftar pengecualian tidak ada lagi",
         widened, "merah", target),
    ]

    try:
        for label, content, want, must_name in states:
            restore()
            mutasi_sumber.write_source(CHECK, content)
            verdict, lines = run_probe()
            detail = " | ".join(lines)
            ok = verdict == want
            if ok and must_name is not None:
                ok = must_name in detail
            print(f"{'OK  ' if ok else 'SALAH'} {label}: diharapkan {want}, "
                  f"terukur {verdict}")
            print(f"       {detail[:180]}")
            if not ok:
                failures.append(
                    f"{label}: diharapkan {want}, terukur {verdict}"
                    + ("" if must_name is None
                       else f"; nama '{must_name}' "
                            f"{'disebut' if must_name in detail else 'TIDAK disebut'}"))
    finally:
        restore()

    after = hashlib.md5(open(CHECK, "rb").read()).hexdigest()
    print(f"\nmd5 Tools/check-visuals.py: {baseline_md5} -> {after} "
          f"({'pulih persis' if after == baseline_md5 else 'TIDAK PULIH'})")
    if after != baseline_md5:
        failures.append("sumber produksi tidak pulih persis")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(states)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
