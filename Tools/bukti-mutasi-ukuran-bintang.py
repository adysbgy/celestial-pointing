#!/usr/bin/env python3
"""Buktikan gerbang **ukuran bintang saat ragu** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

`check_star_size_not_a_claim_when_uncertain` lahir dari sebuah celah yang tidak
terlihat: gerbang warna (`check_star_colour_not_a_claim_when_uncertain`) sudah
lama hijau, dan orang membaca hijau itu sebagai "identitas bintang terjaga saat
ragu". Yang dijaga hanya **warna**. Ukurannya tidak, dan ukuran adalah klaim
yang lebih kuat di katalog repo ini:

  - `size_from_magnitude` memberi **24 ukuran berbeda untuk 25 bintang**.
    Sirius (−1.46) -> 0.982, Polaris (+1.98) -> 0.201: hampir 5x. Magnitudo
    praktis adalah sidik jari.
  - Terukur di piksel (200 px, ss=2) sebelum perbaikan: bintang ragu
    bermagnitudo Sirius membawa **1725** satuan cahaya, bintang redup
    **1095** — 57% lebih terang. Titik besar di samping badge "Ragu" tetap
    menyebut Sirius.

Gerbang warna tidak bisa menutup ini karena ia membandingkan Betelgeuse
(0.398) dengan Rigel (0.472) — hanya 19% berbeda, dan keduanya sudah disamakan
oleh sentinel warna. Ukuran itu tidak pernah menjadi variabel di gerbang mana
pun. Gerbang baru karena itu menyapu magnitudo **−1.46 … +3.5**, yaitu rentang
yang dulu membocorkan 36,5% sebaran cahaya (diukur ulang di sini, keadaan 1).

Keadaan yang diuji:

  [baseline]                       kedua gerbang hijau (kalau tidak, harness
                                   salah, bukan kodenya)
  1. penjaga ukuran dilewati       `drawable_star_size` mengembalikan
                                   `relative_size` apa pun tanpa melihat
                                   `is_confirmed`. Gerbang ukuran **merah**
                                   (sebaran 36,5%), gerbang "tetap menyebut
                                   terang saat yakin" tetap **hijau** — dan
                                   itu benar: mutasi ini hanya membuang
                                   penjaganya, bukan terangnya.
  2. ukuran dibuang di sumber      `star_geometry` selalu memakai satu nilai.
                                   Gerbang "tetap menyebut terang saat yakin"
                                   **merah** (Sirius = bintang redup), gerbang
                                   keraguan tetap **hijau** — keduanya memang
                                   identik saat ragu, sekarang karena keduanya
                                   sama-sama kecil. Inilah pembeda "ukuran
                                   hilang" dari "ukuran bocor", dan kenapa
                                   kedua arah itu wajib ada.
  3. penjaga kembali ke nilai      sentinel `UNKNOWN_STAR_SIZE` dikembalikan
     ujung skala                   menjadi 0.15 (lantai magnitudo paling
                                   redup). Gerbang ukuran **merah**: 0.15
                                   **adalah** satu magnitudo, jadi "ragu" tetap
                                   menyebut bintang paling redup. Ini regresi
                                   halus yang tidak akan terlihat dari gambar
                                   — semua bintang ragu tetap identik satu
                                   sama lain.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
pelajaran yang sudah dibayar di repo ini, `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-ukuran-bintang.py     # 0 = semua sesuai harapan
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
C.check_star_size_not_a_claim_when_uncertain(results)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Penjaga keyakinan untuk ukuran: ukuran hanya boleh sampai ke gambar saat
# engine yakin.
GUARD = ('    if not is_confirmed:\n'
         '        return UNKNOWN_STAR_SIZE\n'
         '    return relative_size')
GUARD_OFF = ('    # MUTASI UJI: gerbang keyakinan dicabut.\n'
             '    _ = is_confirmed\n'
             '    return relative_size')

# Ukuran yang benar-benar dipakai menggambar. Satu pemanggil, satu titik.
SIZE_CALL = '    geometry = star_geometry(drawable_size)'
SIZE_CALL_FLAT = '    geometry = star_geometry(UNKNOWN_STAR_SIZE)'

# Sentinel: satu nilai tengah, bukan nilai ujung skala.
SENTINEL = 'UNKNOWN_STAR_SIZE = 0.5'
SENTINEL_FLOOR = 'UNKNOWN_STAR_SIZE = 0.15'

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang
# membuat berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
NO_CLAIM = "ukuran bintang tidak mengklaim saat ragu"
KEEPS_BRIGHT = "ukuran bintang tetap menyebut terang saat yakin"

HIJAU = "hijau"
MERAH = "merah"


def _expect(**verdicts):
    return verdicts


# (nama keadaan, [(cari, ganti), ...] atau None, {nama pemeriksaan: harapan})
STATES = [
    ("[baseline]", None,
     _expect(**{NO_CLAIM: HIJAU, KEEPS_BRIGHT: HIJAU})),

    # Penjaga keyakinan dilewati: ukuran identitas bocor ke gambar yang belum
    # mengklaim apa pun. Sebaran cahaya antara magnitudo −1.46 dan +3.5
    # kembali melebar. Arah "saat yakin" tetap hijau — mutasi ini tidak
    # menyentuh bintang terkunci.
    ("1. penjaga ukuran dilewati",
     [(GUARD, GUARD_OFF)],
     _expect(**{NO_CLAIM: MERAH, KEEPS_BRIGHT: HIJAU})),

    # Ukuran dibuang di sumber: semua bintang digambar sekecil sentinel.
    # Gerbang "tetap menyebut terang saat yakin" memerah karena Sirius dan
    # bintang redup menjadi sama besar. Gerbang keraguan tetap hijau, dan itu
    # benar: keduanya memang identik saat ragu — sekarang karena keduanya
    # sama-sama tidak menyebut terang.
    ("2. ukuran dibuang di sumber",
     [(SIZE_CALL, SIZE_CALL_FLAT)],
     _expect(**{NO_CLAIM: HIJAU, KEEPS_BRIGHT: MERAH})),

    # Sentinel dikembalikan ke lantai skala (0.15) — nilai yang **adalah**
    # magnitudo bintang paling redup yang bisa dikenali. Semua bintang ragu
    # tetap identik satu sama lain, jadi gerbang "keraguan" tidak bisa
    # melihatnya lewat perbandingan antar-bintang; yang menangkapnya adalah
    # arah kedua. Ini regresi halus yang paling mudah kembali tanpa terlihat.
    ("3. sentinel kembali ke ujung skala",
     [(SENTINEL, SENTINEL_FLOOR)],
     _expect(**{NO_CLAIM: HIJAU, KEEPS_BRIGHT: HIJAU})),
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
        # Tulis atomik + verifikasi (`mutasi_sumber`): harness ini dan
        # saudara-saudaranya memutasi berkas produksi yang sama, dan setiap
        # prob membacanya dari proses baru.
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
                content = original.decode()
                for find, replace in edits:
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: {find!r}")
                        break
                    content = content.replace(find, replace)
                else:
                    mutasi_sumber.write_source(RENDER, content)

            verdicts, error = run_probe()
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            wrong = [(check, want, verdicts.get(check, "TIDAK ADA"))
                     for check, want in expected.items()
                     if verdicts.get(check, "TIDAK ADA") != want]
            if wrong:
                for check, want, got in wrong:
                    failures.append(f"{name}: {check!r} diharapkan {want}, "
                                    f"terukur {got}")
                print(f"{name}: {len(wrong)} TIDAK SESUAI HARAPAN")
                for check, want, got in wrong:
                    print(f"    {check}\n      diharapkan {want}, terukur {got}")
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
