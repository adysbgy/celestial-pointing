#!/usr/bin/env python3
"""Buktikan gerbang **skala magnitudo** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

`check_magnitude_scale_matches_the_model` adalah salah satu dari 18 gerbang
di `check-visuals.py` yang **tidak dirujuk satu pun** harness
`bukti-mutasi-*.py` — jadi walaupun docstringnya mengutip audit mutasi yang
panjang, tidak ada satu pun keadaan rusak yang dijalankan terhadapnya di CI.
Audit yang dilaporkan di docstring itu terjadi **sekali, di mesin orang**,
dan tidak pernah diulang.

Bedanya penting: docstring yang mengutip "nol dari 296 pemeriksaan berbunyi"
adalah klaim tentang masa lalu. Harness ini menjalankan keadaan itu
**sekarang**, di CI, setiap kali.

### Kenapa gerbang ini yang dipilih dari 17 sisanya

Docstringnya menyebut ini "yang paling berbahaya dari ketiga celah", dan
alasannya terukur: `relative_size` (hasil `sizeFromMagnitude`) dipakai untuk
**warna mode malam** (`NIGHT_FLOOR_BRIGHTNESS + range * relative`) **dan**
untuk geometri bintang. Skala yang menyimpang karena itu mengubah kecerahan
mode malam yang diukur `check_night_mode_purity` — pada piksel yang tidak
pernah ada di jam. Ia juga mengubah ukuran glow setiap bintang, dan urutan
terang bintang adalah satu-satunya informasi yang tersisa setelah mode malam
membuang hue seluruhnya.

### Yang diukur harness ini

Semua keadaan dimutasi **tetap bisa dibaca** parser gerbangnya. Itu
disengaja: mutasi yang membuat fungsi tak terbaca (`raw = 1.0`) memerahkan
pemeriksaan "bentuk terbaca", dan itu **bukan** bukti bahwa pemeriksaan
angkanya bekerja — ia hanya membuktikan parser menyerah. Keadaan yang
menuntut pengukuran angka yang sesungguhnya harus membiarkan bentuknya utuh.

    [baseline]                                hijau, 7 pemeriksaan
    1. port coefficient -0.2 -> -0.1          MERAH (coefficient, rentang)
    2. port base 10 -> 2                      MERAH (base, rentang)
    3. port penjepit 0.15 -> 0.05             MERAH (penjepit, rentang)
    4. model penjepit 0.15 -> 0.10            MERAH (penjepit, rentang)
    5. model coefficient -0.2 -> +0.2         MERAH (coefficient, rentang,
                                                      urutan terang)
    6. port coefficient -0.2 -> +0.2          MERAH (coefficient, rentang)

Keadaan 5 adalah satu-satunya yang menyalakan **"bintang terang digambar
lebih besar"**, dan itu sebabnya ia ada: tanpa keadaan itu, pemeriksaan
urutan tidak pernah terbukti menahan apa pun. Perbedaan 5 dan 6 juga
menyatakan arah: model yang dibalik terbaca sebagai penyimpangan **dan**
urutan yang salah, port yang dibalik hanya sebagai penyimpangan — karena
pemeriksaan urutan membaca parameter **model**, bukan port. Itu batas yang
dinyatakan, bukan kelonggaran.

### Yang TIDAK diklaim

- Gerbang ini mengikat **parameter** dan **hasil perhitungan** kedua bahasa.
  Ia tidak membaca piksel app mana pun; tidak ada klaim bahwa perangkat
  Apple menggambar glow dengan ukuran persis ini. `check_star_size_follows_
  magnitude` yang mengukur gambar port untuk itu.
- Ia tidak menahan **nilai** yang benar secara astronomis: 10^(−0.2·Δm) sudah
  benar dan tidak diubah. Yang dijaga adalah model, port, dan urutannya
  tidak boleh bercerai.

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus
handler `SIGINT`/`SIGTERM`. `require_clean_sources` menolak jalan bila
berkas produksi sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-skala-magnitudo.py   # 0 = sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                           "CelestialVisual.swift")

GATE = "check_magnitude_scale_matches_the_model"

HIJAU = "hijau"
MERAH = "merah"

# Nama pemeriksaan di dalam gerbang, supaya harness bisa menuntut **yang mana**
# berbunyi, bukan sekadar "ada yang merah". Dua keadaan yang menyalakan
# pemeriksaan yang sama tidak membuktikan kedua pemeriksaan itu menjaga hal
# yang berbeda.
BENTUK = "skala magnitudo: bentuk terbaca dari kedua bahasa"
BASE = "skala magnitudo: base"
COEFF = "skala magnitudo: coefficient"
BRIGHTEST = "skala magnitudo: brightest"
PENJEPIT = "skala magnitudo: penjepit"
RENTANG = "skala magnitudo: ukuran hasil sama di seluruh rentang katalog"
URUTAN = "skala magnitudo: bintang terang digambar lebih besar"

# ── Jangkar ──────────────────────────────────────────────────────────────
# Semuanya unik di berkasnya (diperiksa sebelum memutasi).
PORT_RAW = "    raw = 10.0 ** (-0.2 * (m - (-1.5)))\n"
PORT_CLAMP = "    return min(1.0, max(0.15, raw))\n"
MODEL_RAW = "        let raw = pow(10.0, -0.2 * (magnitude - brightest))\n"
MODEL_CLAMP = "        return min(1, max(0.15, raw))\n"

# Dijalankan di proses baru: mengimpor ulang `check-visuals` dari berkas yang
# **sudah dimutasi** di disk. Mengimpor sekali di dalam proses ini akan
# memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "cv_probe", os.path.join(sys.argv[1], "Tools", "check-visuals.py"))
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)

results = []
try:
    C.check_magnitude_scale_matches_the_model(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    # Catatan: `expected` memakai **nama pemeriksaan per-check**, bukan nama
    # gerbang. Probe menulis tiap `results` dengan nama itu, jadi kehadirannya
    # di keluaran *adalah* bukti bahwa gerbang `check_magnitude_scale_
    # matches_the_model` benar-benar dijalankan dan mengisi results — gerbang
    # kosong tidak akan pernah memenuhi keadaan apa pun.
    ("[baseline] berkas bersih", None,
     {BENTUK: HIJAU, BASE: HIJAU, COEFF: HIJAU, BRIGHTEST: HIJAU,
      PENJEPIT: HIJAU, RENTANG: HIJAU, URUTAN: HIJAU}),

    # ── 1-2. Port berubah, model tidak ikut ──────────────────────────────
    # Arah "port menyimpang". Koefisien dan basis dipisah karena keduanya
    # bisa bergeser sendiri-sendiri, dan gerbang menamai keduanya terpisah.
    # Kalau satu keadaan menyalakan keduanya, berarti keduanya mengukur hal
    # yang sama.
    ("1. port: koefisien -0.2 -> -0.1 (model tetap)",
     [(RENDER, PORT_RAW, "    raw = 10.0 ** (-0.1 * (m - (-1.5)))\n")],
     {BENTUK: HIJAU, COEFF: MERAH, RENTANG: MERAH,
      BASE: HIJAU, PENJEPIT: HIJAU, BRIGHTEST: HIJAU, URUTAN: HIJAU}),

    ("2. port: basis 10 -> 2 (model tetap)",
     [(RENDER, PORT_RAW, "    raw = 2.0 ** (-0.2 * (m - (-1.5)))\n")],
     {BENTUK: HIJAU, BASE: MERAH, RENTANG: MERAH,
      COEFF: HIJAU, PENJEPIT: HIJAU, URUTAN: HIJAU}),

    # ── 3-4. Penjepit, kedua arah ────────────────────────────────────────
    # 0.15 adalah lantai yang membuat bintang paling redup masih terlihat
    # sebagai titik, bukan menghilang. Pergeserannya diuji di **kedua**
    # bahasa karena penjepit hidup di keduanya: 3 = port menyimpang,
    # 4 = model menyimpang (arah yang paling mungkin di repo dua bahasa ini).
    # Keduanya menyalakan pemeriksaan rentang pada magnitudo redup (6.0, 20.0)
    # — satu-satunya tempat lantainya menggigit.
    ("3. port: penjepit 0.15 -> 0.05 (lantai bintang redup)",
     [(RENDER, PORT_CLAMP, "    return min(1.0, max(0.05, raw))\n")],
     {BENTUK: HIJAU, PENJEPIT: MERAH, RENTANG: MERAH,
      BASE: HIJAU, COEFF: HIJAU, URUTAN: HIJAU}),

    ("4. model: penjepit 0.15 -> 0.10 (port tidak ikut)",
     [(MODEL, MODEL_CLAMP, "        return min(1, max(0.10, raw))\n")],
     {BENTUK: HIJAU, PENJEPIT: MERAH, RENTANG: MERAH,
      BASE: HIJAU, COEFF: HIJAU, URUTAN: HIJAU}),

    # ── 5. Model dibalik: ukuran tumbuh bersama magnitudo ────────────────
    # Keadaan terpenting kedua setelah baseline, dan satu-satunya yang
    # menyalakan URUTAN. Inversi tanda membuat setiap bintang lebih redup
    # digambar **lebih besar** — langit terbalik, dan tidak satu pun uji
    # format atau teks di layar yang bisa membantahnya.
    #
    # Tetap bisa dibaca parser (tanda saja yang berubah), jadi pemeriksaan
    # angkanya benar-benar diukur — bukan "bentuknya tidak dikenali".
    ("5. model: koefisien -0.2 -> +0.2 (skala terbalik, tetap terbaca)",
     [(MODEL, MODEL_RAW,
       "        let raw = pow(10.0, 0.2 * (magnitude - brightest))\n")],
     {BENTUK: HIJAU, COEFF: MERAH, RENTANG: MERAH, URUTAN: MERAH,
      BASE: HIJAU, PENJEPIT: HIJAU}),

    # ── 6. Arah cermin: port dibalik, model tetap ────────────────────────
    # Terukur: URUTAN tetap **hijau** di sini, karena pemeriksaan itu membaca
    # parameter **model**. Itu batas cakupan yang dinyatakan, bukan
    # kelemahan — dan menyatakannya menuntut keadaan ini ada. Tanpa dia,
    # "URUTAN merah di keadaan 5" bisa dibaca sebagai "URUTAN menangkap
    # pembalikan di kedua bahasa", padahal tidak.
    ("6. port: koefisien -0.2 -> +0.2 (model tetap; URUTAN harus tetap hijau)",
     [(RENDER, PORT_RAW, "    raw = 10.0 ** (0.2 * (m - (-1.5)))\n")],
     {BENTUK: HIJAU, COEFF: MERAH, RENTANG: MERAH, URUTAN: HIJAU,
      BASE: HIJAU, PENJEPIT: HIJAU}),
]


def run_probe():
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    return out.stdout, None


def classify(stdout):
    verdicts = {}
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        state, _, name = stripped.partition(" ")
        name = name.strip()
        if state in ("OK", "GAGAL") and name:
            verdicts[name] = "hijau" if state == "OK" else "merah"
    return verdicts


def main():
    files = [RENDER, MODEL]
    mutasi_sumber.require_clean_sources(files)
    originals = {path: open(path, "rb").read() for path in files}
    baseline_md5 = {path: hashlib.md5(data).hexdigest()
                    for path, data in originals.items()}
    failures = []

    def restore():
        for path, data in originals.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for state in STATES:
            name, edits, expected = state[0], state[1], state[2]
            restore()
            if edits is not None:
                pending = {}
                for path, find, replace in edits:
                    content = pending.get(path, originals[path].decode())
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: "
                            f"{find[:70]!r}")
                        break
                    pending[path] = content.replace(find, replace)
                else:
                    for path, content in pending.items():
                        mutasi_sumber.write_source(path, content)

            stdout, error = run_probe()
            if stdout is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            verdicts = classify(stdout)
            wrong = [(check, want, verdicts.get(check, "TIDAK ADA"))
                     for check, want in expected.items()
                     if verdicts.get(check, "TIDAK ADA") != want]

            # Gerbang yang mengisi 0 results tidak boleh terbaca hijau:
            # setiap keadaan menuntut nama pemeriksaan tertentu, jadi tidak
            # ada satunya yang bisa terpenuhi bila gerbang diam saja.
            # (Ini menggantikan penjaga lama `GATE in expected`, yang tidak
            # pernah bernilai True — `GATE` bukan nama pemeriksaan yang
            # ditulis gerbang, jadi penjaga itu tidak pernah menjaga apa pun.)
            if not verdicts:
                failures.append(f"{name}: gerbang mengisi 0 results")

            if wrong:
                # Wajib: ketidakcocokan harus **dicatat**, bukan sekadar
                # dicetak. Versi pertama harness ini hanya mencetak, jadi ia
                # keluar 0 (hijau) sementara semua keadaan gagal — harness
                # yang membuktikan apa pun justru karena ia selalu hijau.
                for check, want, got in wrong:
                    failures.append(
                        f"{name}: {check} diharapkan {want}, terukur {got}")
                print(f"{name}: TIDAK SESUAI HARAPAN")
                for check, want, got in wrong:
                    print(f"    {check}\n      diharapkan {want}, "
                          f"terukur {got}")
            else:
                red = sum(1 for v in verdicts.values() if v == "merah")
                print(f"{name}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} pemeriksaan)")
    finally:
        restore()

    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        print(f"\nmd5 {os.path.relpath(path, ROOT)}: {digest} -> {after} "
              f"({'pulih persis' if after == digest else 'TIDAK PULIH'})")
        if after != digest:
            failures.append(f"sumber produksi tidak pulih persis: {path}")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
