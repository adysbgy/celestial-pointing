#!/usr/bin/env python3
"""Buktikan cangkang `.planetaryNebula` **bersambung**, bukan untaian manik.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Dan gerbang ini punya riwayat yang membuatnya lebih perlu dibuktikan
daripada kebanyakan: **dua versi sebelumnya hijau pada kode yang jelas
salah.**

  - Versi pertama membandingkan kecerahan **terang** dan **gelap** pada
    radius cangkang. Opasitas blob terbesar 0.54, jadi jumlah blob yang
    tumpang tindih berhenti menambah kecerahan begitu totalnya melewati
    0.54: puncaknya tersaturasi sementara celahnya tidak. Akibatnya versi
    16-blob terukur **lebih buruk** (1.13) daripada versi 8-blob (0.15)
    oleh metrik itu — persis terbalik dari kenyataan gambarnya.
  - Yang benar-benar membedakan cangkang dari manik adalah **bagian
    gelapnya**: pada manik, sudut di antara blob turun hampir ke latar.
    Karena itu gerbangnya mengukur profil angular, dan harness ini
    membuktikan bahwa profil itu benar-benar berbunyi.

Keadaan yang diuji:

  [baseline]              gerbang hijau (kalau tidak, harness salah)
  1. tata letak 8-blob    tata letak lama (45°, lebar 0.30) — gerbang harus
     @45° lebar 0.30      **merah**, karena itulah cacat yang ditutupnya
  2. lebar 0.20           blob yang sama tapi lebih kecil — gerbang merah,
                          membuktikan ambangnya tidak sekadar "ada blob"
  3. 8 titik @ lebar      mutasi paling tajam: **ukuran blob sama persis**
     0.26 (lebar sekarang) dengan kode sekarang, yang berbeda hanya
                          **jaraknya**. Gerbang harus tetap merah — kalau
                          hijau, berarti yang diukurnya ukuran blob, bukan
                          kesinambungan cangkangnya.
  4. 16 titik @22.5°      tata letak yang **benar-benar dipakai** sampai
     lebar 0.26           cangkangnya dirapatkan. Pada kasus rujukan (f=0.8)
                          lantainya **0.83** — cangkang ini nyaris sebersambung
                          dengan 24-blob (0.85), jadi di situ ia BOLEH hijau:
                          keadaan #4 bukan "16-blob harus merah di mana pun",
                          melainkan "16-blob murni (tanpa elongasi) tidak boleh
                          menyamar sebagai cangkang yang jujur". Tempat yang
                          memisahkan keduanya adalah **fuzziness katalog** —
                          pada M57 (0.40) lantai 16-blob jatuh ke **0.65**
                          (manik), sementara 24-blob tetap 0.84. Jadi keadaan
                          ini menuntut **merah pada M57**, hijau pada rujukan.
                          Kalau baris M57-nya hijau, gerbangnya sudah mundur ke
                          lubang lama (cangkang palsu tampil sebagai cangkang).

Yang **tidak** dipakai sebagai keadaan: 8 titik @45° dengan lebar **0.40**.
Sempat dicoba dan gerbangnya hijau — dan itu benar: delapan blob selebar itu
saling menjangkau 1.48x tali busurnya, jadi cangkangnya memang bersambung.
Menuntutnya merah akan menuntut gerbang menyalak pada kode yang benar.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
pelajaran yang sudah dibayar di repo ini, `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-cangkang.py      # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import importlib.util
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
results = []
C.check_planetary_nebula_shell_is_continuous(results)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Blok `planetaryNebula` yang sekarang, apa adanya. Kalau modelnya dirapikan
# dan jangkar ini tidak lagi cocok, harness **berhenti** — bukan diam-diam
# menguji himpunan kosong.
CURRENT_LAYOUT = """    "planetaryNebula": [(0.4200000000000000, 0.0000000000000000, 0.26, 1.0, 0.0, 0.54),
                        (0.4056888470414087, 0.1087039989430587, 0.26, 1.0, 0.0, 0.48),
                        (0.3637306695894643, 0.2100000000000000, 0.26, 1.0, 0.0, 0.52),
                        (0.2969848480983500, 0.2969848480983499, 0.26, 1.0, 0.0, 0.46),
                        (0.2100000000000000, 0.3637306695894642, 0.26, 1.0, 0.0, 0.50),
                        (0.1087039989430587, 0.4056888470414087, 0.26, 1.0, 0.0, 0.44),
                        (0.0000000000000000, 0.4200000000000000, 0.26, 1.0, 0.0, 0.53),
                        (-0.1087039989430588, 0.4056888470414087, 0.26, 1.0, 0.0, 0.47),
                        (-0.2099999999999999, 0.3637306695894643, 0.26, 1.0, 0.0, 0.51),
                        (-0.2969848480983499, 0.2969848480983500, 0.26, 1.0, 0.0, 0.45),
                        (-0.3637306695894643, 0.2100000000000000, 0.26, 1.0, 0.0, 0.49),
                        (-0.4056888470414086, 0.1087039989430588, 0.26, 1.0, 0.0, 0.44),
                        (-0.4200000000000000, 0.0000000000000001, 0.26, 1.0, 0.0, 0.52),
                        (-0.4056888470414087, -0.1087039989430587, 0.26, 1.0, 0.0, 0.46),
                        (-0.3637306695894642, -0.2100000000000000, 0.26, 1.0, 0.0, 0.50),
                        (-0.2969848480983500, -0.2969848480983499, 0.26, 1.0, 0.0, 0.45),
                        (-0.2100000000000002, -0.3637306695894641, 0.26, 1.0, 0.0, 0.54),
                        (-0.1087039989430587, -0.4056888470414087, 0.26, 1.0, 0.0, 0.48),
                        (-0.0000000000000001, -0.4200000000000000, 0.26, 1.0, 0.0, 0.52),
                        (0.1087039989430585, -0.4056888470414087, 0.26, 1.0, 0.0, 0.46),
                        (0.2100000000000000, -0.3637306695894642, 0.26, 1.0, 0.0, 0.50),
                        (0.2969848480983499, -0.2969848480983500, 0.26, 1.0, 0.0, 0.44),
                        (0.3637306695894641, -0.2100000000000002, 0.26, 1.0, 0.0, 0.53),
                        (0.4056888470414087, -0.1087039989430587, 0.26, 1.0, 0.0, 0.47)],"""

# Tata letak **lama** (8 blob @45°, lebar 0.30) — cacat yang ditutup gerbang.
OLD_LAYOUT = """    "planetaryNebula": [(0.4200000000000000, 0.0000000000000000, 0.30, 1.0, 0.0, 0.54),
                        (0.2969848483038187, 0.2969848483038187, 0.30, 1.0, 0.0, 0.48),
                        (0.0000000000000000, 0.4200000000000000, 0.30, 1.0, 0.0, 0.52),
                        (-0.2969848483038187, 0.2969848483038187, 0.30, 1.0, 0.0, 0.46),
                        (-0.4200000000000000, 0.0000000000000000, 0.30, 1.0, 0.0, 0.50),
                        (-0.2969848483038187, -0.2969848483038187, 0.30, 1.0, 0.0, 0.44),
                        (0.0000000000000000, -0.4200000000000000, 0.30, 1.0, 0.0, 0.53),
                        (0.2969848483038187, -0.2969848483038187, 0.30, 1.0, 0.0, 0.47)]"""


def _with_width(layout, width):
    """Ganti kolom lebar (indeks 2) pada tiap baris tata letak."""
    out = []
    for line in layout.splitlines():
        head, tail = line.split("(", 1)
        fields = tail.split(",")
        fields[2] = f" {width}"
        out.append(head + "(" + ",".join(fields))
    return _same_terminator("\n".join(out), CURRENT_LAYOUT)


def _same_terminator(layout, anchor):
    """Samakan penutup tata letak dengan penutup jangkar yang digantikannya.

    **Kenapa ini perlu, dan kenapa ia cacat yang membunuh seluruh harness.**
    Jangkar `CURRENT_LAYOUT` diakhiri `)],` — koma tertinggal, karena di
    dalam port ia diikuti entri lain. Semua tata letak pengganti ditulis
    tangan dan diakhiri `)]`. Mengganti yang pertama dengan yang kedua
    karena itu membuang koma itu, dan hasilnya **bukan kode Python yang
    sah**: `SyntaxError` di baris 319, di **setiap** keadaan mutasi.

    Akibatnya bukan "satu keadaan merah", melainkan harness yang **crash
    alih-alih membuktikan apa pun** — keempat keadaannya gagal sebelum
    menyentuh satu piksel pun, sejak `1e28591` mengubah model 16 → 24 blob.
    Gerbang `check_planetary_nebula_shell_is_continuous` tetap hijau
    sendiri, jadi tidak ada yang melihat pembuktiannya sudah mati.

    Menambahkan koma ke keempat tata letak satu per satu akan menyelesaikan
    kejadian ini dan membiarkan **kelasnya** hidup: begitu jangkarnya
    berhenti memakai koma tertinggal, keempat penggantinya menjadi salah
    dengan arah yang berlawanan. Karena itu penutupnya **diturunkan dari
    jangkar**, bukan diketik — jangkarnya yang menentukan, dan penyimpangan
    tidak bisa lagi ditulis.
    """
    return layout[: -len(")]")] + anchor[-len(")],") :]



NARROW = _with_width(OLD_LAYOUT, "0.20")
# 8 titik @45° pada lebar **sekarang** (0.26): blobnya identik dengan kode
# sekarang, yang berbeda hanya jaraknya. Ini mutasi paling tajam — kalau
# gerbang hijau di sini, yang diukurnya ukuran blob, bukan kesinambungan.
CURRENT_WIDTH_OLD_SPACING = _with_width(OLD_LAYOUT, "0.26")
# Enam belas titik @22.5° pada lebar sekarang — **tata letak yang benar-benar
# dipakai kode sampai cangkangnya dirapatkan**. Inilah keadaan yang paling
# penting di berkas ini: ia bukan karangan, ia versi yang pernah tampil di
# layar, dan ia **lolos** uji geometri Swift (`testPlanetaryNebulaShellIs
# ContinuousNotBeaded`) karena blobnya memang beririsan. Yang menangkapnya
# hanya ukuran piksel — dan hanya setelah gerbangnya diukur pada fuzziness
# **katalog M57 (0.40)**, bukan pada kasus rujukan (0.8). Kalau keadaan ini
# hijau lagi, gerbangnya sudah mundur ke lubang yang sama.
SIXTEEN = """    "planetaryNebula": [
                        (0.4200000000000000, 0.0000000000000000, 0.26, 1.0, 0.0, 0.54),
                        (0.3880294036547404, 0.1607270415933377, 0.26, 1.0, 0.0, 0.48),
                        (0.2969848480983500, 0.2969848480983499, 0.26, 1.0, 0.0, 0.52),
                        (0.1607270415933377, 0.3880294036547404, 0.26, 1.0, 0.0, 0.46),
                        (0.0000000000000000, 0.4200000000000000, 0.26, 1.0, 0.0, 0.50),
                        (-0.1607270415933377, 0.3880294036547404, 0.26, 1.0, 0.0, 0.44),
                        (-0.2969848480983499, 0.2969848480983500, 0.26, 1.0, 0.0, 0.53),
                        (-0.3880294036547404, 0.1607270415933378, 0.26, 1.0, 0.0, 0.47),
                        (-0.4200000000000000, 0.0000000000000001, 0.26, 1.0, 0.0, 0.51),
                        (-0.3880294036547405, -0.1607270415933376, 0.26, 1.0, 0.0, 0.45),
                        (-0.2969848480983500, -0.2969848480983499, 0.26, 1.0, 0.0, 0.49),
                        (-0.1607270415933376, -0.3880294036547405, 0.26, 1.0, 0.0, 0.44),
                        (-0.0000000000000001, -0.4200000000000000, 0.26, 1.0, 0.0, 0.52),
                        (0.1607270415933378, -0.3880294036547404, 0.26, 1.0, 0.0, 0.46),
                        (0.2969848480983499, -0.2969848480983500, 0.26, 1.0, 0.0, 0.50),
                        (0.3880294036547405, -0.1607270415933376, 0.26, 1.0, 0.0, 0.45)]"""

# Keempat pengganti dipakai **langsung** sebagai pengganti jangkar, jadi
# penutupnya harus disamakan dengan penutup jangkar — satu aturan untuk
# semuanya, bukan empat koma yang ditulis tangan dan bisa basi sendiri.
# (`NARROW` dan `CURRENT_WIDTH_OLD_SPACING` sudah lewat `_same_terminator`
# di dalam `_with_width`; ketiga di bawah ini tidak.)
OLD_LAYOUT = _same_terminator(OLD_LAYOUT, CURRENT_LAYOUT)
SIXTEEN = _same_terminator(SIXTEEN, CURRENT_LAYOUT)

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang
# membuat berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
CONTINUOUS = "cangkang nebula planetari bersambung"


def _checks(verdicts):
    return [name for name in verdicts if name.startswith(CONTINUOUS)]


STATES = [
    # (nama, edit, harapan: nama pemeriksaan -> "hijau"/"merah")
    ("[baseline]", None, None),
    ("1. tata letak lama 8-blob @45°, lebar 0.30",
     [(CURRENT_LAYOUT, OLD_LAYOUT)], "merah"),
    ("2. lebar 0.20 (blob kecil, 8 titik)",
     [(CURRENT_LAYOUT, NARROW)], "merah"),
    ("3. 8 titik @45° pada lebar sekarang (0.26)",
     [(CURRENT_LAYOUT, CURRENT_WIDTH_OLD_SPACING)], "merah"),
    ("4. 16 titik @22.5° (tata letak lama yang benar-benar dipakai)",
     [(CURRENT_LAYOUT, SIXTEEN)],
     # Bukan \"harus merah di mana pun\": pada fuzziness rujukan (0.8) lantai
     # 16-blob memang **0.83** — cangkang yang hampir sebersambung dengan
     # 24-blob (0.85), jadi di situ hijau itu BENAR. Yang memisahkan cangkang
     # jujur dari manik adalah **fuzziness katalog**: pada M57 (0.40) lantai
     # 16-blob jatuh ke 0.65 (manik) sementara 24-blob tetap 0.84. Jadi baris
     # M57-nya harus MERAH; kalau hijau, gerbang mundur ke lubang lama.
     {"cangkang nebula planetari bersambung (76px, rujukan f=0.8)": "hijau",
      "cangkang nebula planetari bersambung (132px, rujukan f=0.8)": "hijau",
      "cangkang nebula planetari bersambung (76px, M57 katalog f=0.40)": "merah",
      "cangkang nebula planetari bersambung (132px, M57 katalog f=0.40)": "merah"}),
]


def run_probe():
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        state, rest = line.split(" ", 1)
        name = rest.split("  | ")[0].strip()
        verdicts[name] = "hijau" if state == "OK" else "merah"
    return verdicts, None


def main():
    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        # Tulis atomik + verifikasi (`mutasi_sumber`): harness ini dan enam
        # saudaranya memutasi berkas produksi yang sama, dan setiap prob
        # membacanya dari proses baru.
        mutasi_sumber.restore_verified(RENDER, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected in STATES:
            if edits is None:
                restore()
            else:
                source = original.decode()
                for find, replace in edits:
                    if find not in source:
                        failures.append(f"{name}: jangkar tidak ditemukan")
                        break
                    source = source.replace(find, replace)
                else:
                    mutasi_sumber.write_source(RENDER, source)

            verdicts, error = run_probe()
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            checks = _checks(verdicts)
            if not checks:
                failures.append(f"{name}: tidak ada pemeriksaan "
                                f"'{CONTINUOUS}' di keluaran gerbang")
                print(f"{name}: TIDAK ADA PEMERIKSAAN")
                continue

            if expected is None:
                bad = [c for c in checks if verdicts[c] != "hijau"]
                if bad:
                    failures.append(f"{name}: baseline tidak hijau: {bad}")
                    print(f"{name}: BASELINE TIDAK HIJAU -> {bad}")
                else:
                    print(f"{name}: hijau di {len(checks)} pemeriksaan (benar)")
                continue

            # Harapan per-pemeriksaan (dict nama -> "hijau"/"merah") diperlukan
            # bila satu keadaan harus merah di sebagian kasus dan hijau di
            # sisanya (lihat keadaan #4: 16-blob merah pada M57, hijau pada
            # rujukan). Harapan tunggal (string) dipakai keadaan lain.
            if isinstance(expected, dict):
                want = expected
                wrong = [c for c in want if verdicts.get(c) != want[c]]
                if wrong:
                    for check in wrong:
                        failures.append(
                            f"{name}: '{check}' harus {want[check]}, "
                            f"dapat {verdicts.get(check)}")
                        print(f"{name}: '{check}' harus {want[check]}, "
                              f"dapat {verdicts.get(check)}")
                else:
                    print(f"{name}: sesuai harapan per-kasus "
                          f"({len(want)} pemeriksaan, benar)")
            else:
                wrong = [c for c in checks if verdicts[c] != expected]
                if wrong:
                    for check in wrong:
                        failures.append(f"{name}: '{check}' harus {expected}, "
                                        f"dapat {verdicts[check]}")
                        print(f"{name}: '{check}' harus {expected}, "
                              f"dapat {verdicts[check]}")
                else:
                    print(f"{name}: {expected} di {len(checks)} "
                          f"pemeriksaan (benar)")
    finally:
        restore()
        if hashlib.md5(open(RENDER, "rb").read()).hexdigest() != baseline_md5:
            failures.append("sumber produksi TIDAK kembali ke semula")

    print()
    if failures:
        print(f"GAGAL ({len(failures)}):")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("OK: gerbang berbunyi pada setiap cacat, dan hijau saat kode benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
