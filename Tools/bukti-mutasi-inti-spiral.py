#!/usr/bin/env python3
"""Buktikan dua gerbang inti spiral benar-benar berbunyi.

Kenapa harness ini ada.

Audit `check-visuals.py` menemukan **tiga** gerbang tanpa satu pun bukti
mutasi. Yang ditutup di sini dua sekaligus, karena keduanya mengukur **hal
yang sama dari dua sisi yang tidak bisa saling menggantikan**:

  - `check_spiral_core_reads_as_one_body` — tonjolan inti galaksi spiral
    benar-benar menerangi pusatnya (diukur sebagai selisih cakupan cincin
    dengan vs tanpa tonjolan, pada ukuran jam 76 px).
  - `check_spiral_core_docstring_quotes_measured_values` — angka yang dikutip
    docstring gerbang pertama (+124°/+106°/+44°, batas 0.2725 R) harus keluar
    dari penyampelnya sendiri, bukan dari komentar yang ditulis sekali.

Hijau pada hari ditulis bukan bukti apa pun. Yang membedakan gerbang yang
menjaga dari gerbang yang hanya *terlihat* menjaga adalah apakah ia bisa
dibuat merah, dan merah pada keadaan yang memang salah.

**Temuan utama, diukur bukan dikira.** Docstring gerbang pertama menyatakan
bahwa mutasi "tonjolan diperkecil" dan "tonjolan diredupkan" berbunyi lewat
pemeriksaan *selisih*. Terukur: yang berbunyi adalah pemeriksaan **"sampel
inti ada"** — batas sampel dihitung dari `halfWidth · (1 − ambang /
(opasitas · 255))`, jadi memperkecil atau meredupkan tonjolan memindahkan
batas itu ke bawah seluruh sampel dan himpunan sampelnya **runtuh**. Gerbang
pertama lalu melaporkan satu hasil ("tonjolan inti menyinari pusat (ukuran
jam)"), bukan tiga hasil per-radius. Itu sesuai dengan catatan di docstring
yang sudah diperbaiki siklus lalu — dan harness ini menjadikannya **harapan
yang dieksekusi**, bukan cerita.

Keadaan-keadaannya diukur satu per satu sebelum ditulis, dan dua harapan
versi pertama yang salah diperbaiki ke yang terukur — bukan gerbangnya yang
dilonggarkan.

Berkas sumber produksi (`Tools/render-visuals.py`) dimutasi lalu dipulihkan
di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati
`finally` dan meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-inti-spiral.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
for name in sys.argv[2].split(","):
    results = []
    getattr(C, name)(results)
    ok = bool(results) and all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

# ── Jangkar: blob tonjolan inti di tata letak `.spiralGalaxy` ─────────────
# Baris pertama `DEEP_SKY_LAYOUT["spiralGalaxy"]`: (offset 0,0, lebar 0.32,
# aspek 1.0, sudut 0, opasitas 0.60). Tonjolan terang di titik pusat; tanpa
# dia pusat galaksi terbaca sebagai donat. Satu-satunya kemunculan (terukur).
BULGE = "(0.000000, 0.000000, 0.32, 1.0, 0.0, 0.60)"
BULGE_SHRUNK = "(0.000000, 0.000000, 0.10, 1.0, 0.0, 0.60)"
BULGE_DIMMED = "(0.000000, 0.000000, 0.32, 1.0, 0.0, 0.20)"
# Hapus blob-nya berikut barisnya: daftar jadi kehilangan elemen pertama.
BULGE_LINE = "(0.000000, 0.000000, 0.32, 1.0, 0.0, 0.60),\n"

HIJAU = "hijau"
MERAH = "merah"

ONE_BODY = "check_spiral_core_reads_as_one_body"
DOCSTRING = "check_spiral_core_docstring_quotes_measured_values"
ALL = ",".join((ONE_BODY, DOCSTRING))

STATES = [
    ("[baseline]", None,
     {ONE_BODY: HIJAU, DOCSTRING: HIJAU,
      "tonjolan inti menyinari pusat pada r=0.24 (ukuran jam)": HIJAU,
      "tonjolan inti menyinari pusat pada r=0.25 (ukuran jam)": HIJAU,
      "tonjolan inti menyinari pusat pada r=0.27 (ukuran jam)": HIJAU,
      "inti spiral: selisih docstring r=0.2377 cocok (124° vs 124°)": HIJAU,
      "inti spiral: selisih docstring r=0.2532 cocok (106° vs 106°)": HIJAU,
      "inti spiral: selisih docstring r=0.2688 cocok (44° vs 44°)": HIJAU,
      "inti spiral: batas sampel inti = 0.2725 R (dari model)": HIJAU,
      "inti spiral: r=0.2843 di luar sampel inti (batas bekerja)": HIJAU}),

    # ── 1. Tonjolan diperkecil 0.32 -> 0.10 ──────────────────────────────
    #
    # Batas sampel inti dihitung dari `halfWidth`-nya, jadi memperkecil
    # tonjolan memindahkan batas itu ke bawah seluruh sampel: himpunan
    # sampelnya **runtuh**, dan gerbang pertama melaporkan **satu** hasil
    # ("tonjolan inti menyinari pusat (ukuran jam)"), bukan tiga per-radius.
    # Himpunan hasil yang berbeda itu sendiri adalah bagian dari bukti —
    # karena itu keadaan ini menuntut hasilnya **persis**.
    ("1. tonjolan diperkecil 0.32 -> 0.10",
     [(BULGE, BULGE_SHRUNK)],
     {ONE_BODY: MERAH, DOCSTRING: MERAH,
      "tonjolan inti menyinari pusat (ukuran jam)": MERAH,
      "inti spiral: selisih docstring r=0.2377 cocok (124° vs 0°)": MERAH,
      "inti spiral: selisih docstring r=0.2532 cocok (106° vs 0°)": MERAH,
      "inti spiral: selisih docstring r=0.2688 cocok (44° vs 0°)": MERAH,
      "inti spiral: batas sampel inti = 0.2725 R (dari model)": MERAH,
      "inti spiral: selisih docstring r=0.2843 cocok (0° vs 0°)": HIJAU,
      "inti spiral: r=0.2843 di luar sampel inti (batas bekerja)": HIJAU}),

    # ── 2. Tonjolan diredupkan 0.60 -> 0.20 ──────────────────────────────
    #
    # Arah yang berbeda dari keadaan 1 (opasitas, bukan lebar), tapi jalurnya
    # sama — batas sampel runtuh. Bedanya terukur dan dituntut: selisihnya
    # **tidak** nol lagi (12°/7°/6°), karena blob yang kecil tapi masih ada
    # tetap menyumbang sedikit, sedangkan keadaan 1 memberi 0°/0°/0°.
    ("2. tonjolan diredupkan 0.60 -> 0.20",
     [(BULGE, BULGE_DIMMED)],
     {ONE_BODY: MERAH, DOCSTRING: MERAH,
      "tonjolan inti menyinari pusat (ukuran jam)": MERAH,
      "inti spiral: selisih docstring r=0.2377 cocok (124° vs 12°)": MERAH,
      "inti spiral: selisih docstring r=0.2532 cocok (106° vs 7°)": MERAH,
      "inti spiral: selisih docstring r=0.2688 cocok (44° vs 6°)": MERAH,
      "inti spiral: batas sampel inti = 0.2725 R (dari model)": MERAH,
      "inti spiral: selisih docstring r=0.2843 cocok (0° vs 0°)": HIJAU,
      "inti spiral: r=0.2843 di luar sampel inti (batas bekerja)": HIJAU}),

    # ── 3. Tonjolan dihapus seluruhnya ───────────────────────────────────
    #
    # Tata letak kehilangan blob intinya. Yang menarik: indeks tonjolan lalu
    # jatuh ke kabut cakram (0.13), sehingga `spiral_core_samples()` tidak
    # kosong — ia menghitung dari blob **yang salah**. Terukur: r=0.2688
    # (44° vs 41°) dan r=0.2843 (0° vs 38°) berbalik arah, dan r=0.2843 yang
    # seharusnya **di luar** sampel inti kini ikut berubah. Jadi penghapusan
    # tonjolan tidak ditangkap oleh "sampel runtuh" — ia ditangkap oleh
    # angka-angka docstring yang tidak lagi cocok.
    ("3. tonjolan dihapus dari tata letak",
     [(BULGE_LINE, "")],
     {ONE_BODY: MERAH, DOCSTRING: MERAH,
      "tonjolan inti menyinari pusat (ukuran jam)": MERAH,
      "inti spiral: selisih docstring r=0.2377 cocok (124° vs 44°)": MERAH,
      "inti spiral: selisih docstring r=0.2532 cocok (106° vs 45°)": MERAH,
      "inti spiral: selisih docstring r=0.2843 cocok (0° vs 38°)": MERAH,
      "inti spiral: batas sampel inti = 0.2725 R (dari model)": MERAH,
      "inti spiral: selisih docstring r=0.2688 cocok (44° vs 41°)": HIJAU,
      "inti spiral: r=0.2843 di luar sampel inti (batas bekerja)": HIJAU}),

    # ── 4. Kontrol negatif: komentar di ujung baris ──────────────────────
    #
    # Tata letaknya byte-identik secara makna; hanya ada komentar tambahan.
    # Keduanya harus tetap hijau penuh. Gerbang yang memerah di sini akan
    # dilonggarkan orang, dan gerbang yang dilonggarkan tidak menjaga apa pun.
    ("4. kontrol negatif: komentar di ujung baris tonjolan",
     [(BULGE, BULGE + ",  # catatan")],
     {ONE_BODY: HIJAU, DOCSTRING: HIJAU,
      "tonjolan inti menyinari pusat pada r=0.24 (ukuran jam)": HIJAU,
      "inti spiral: selisih docstring r=0.2377 cocok (124° vs 124°)": HIJAU,
      "inti spiral: r=0.2843 di luar sampel inti (batas bekerja)": HIJAU}),
]


def run_probe(checks):
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, checks],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        state, name = line.split(" ", 1)
        verdicts[name.strip()] = "hijau" if state == "OK" else "merah"
    return verdicts, None


def main():
    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        mutasi_sumber.restore_verified(RENDER, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected in STATES:
            # Pulihkan di setiap keadaan: kalau tidak, mutasi keadaan sebelumnya
            # ikut terbawa dan keadaan ini mengukur berkas yang salah.
            restore()
            if edits is not None:
                content = original.decode()
                for find, replace in edits:
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: {find[:70]!r}")
                        break
                    content = content.replace(find, replace)
                else:
                    mutasi_sumber.write_source(RENDER, content)

            verdicts, error = run_probe(ALL)
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            wrong = [(res, want, verdicts.get(res, "TIDAK ADA"))
                     for res, want in expected.items()
                     if verdicts.get(res, "TIDAK ADA") != want]
            if wrong:
                for res, want, got in wrong:
                    failures.append(f"{name}: {res!r} diharapkan {want}, "
                                    f"terukur {got}")
                print(f"{name}: {len(wrong)} TIDAK SESUAI HARAPAN")
                for res, want, got in wrong:
                    print(f"    {res}\n      diharapkan {want}, terukur {got}")
            else:
                red = sum(1 for v in verdicts.values() if v == "merah")
                print(f"{name}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} pemeriksaan)")
    finally:
        restore()

    after = hashlib.md5(open(RENDER, "rb").read()).hexdigest()
    print(f"\nmd5 render-visuals.py: {baseline_md5} -> {after} "
          f"({'pulih persis' if after == baseline_md5 else 'TIDAK PULIH'})")
    if after != baseline_md5:
        failures.append("sumber produksi tidak pulih persis")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("\nSemua keadaan sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
