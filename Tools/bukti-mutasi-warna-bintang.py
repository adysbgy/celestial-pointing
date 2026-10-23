#!/usr/bin/env python3
"""Buktikan gerbang **warna spektral bintang** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

Warna spektral adalah **ciri pengenal** bintang: merah Betelgeuse dan biru
Rigel adalah penanda yang sama meyakinkannya dengan cincin Saturnus. Dua
gerbang mengukurnya, dan keduanya **tanpa bukti mutasi** sejak ditulis:

  - `check_star_colour_order` — "Betelgeuse lebih merah dari Rigel", diukur
    dari piksel paling terang.
  - `check_star_colour_not_a_claim_when_uncertain` — warna itu **hilang** saat
    engine ragu, dan kedua bintang yang ragu tampil identik.

Keduanya hijau pada hari ditulis. Itu bukan bukti apa pun: gerbang gambar baru
selalu hijau, dan dua kelas cacat di bawah ini adalah alasan mengapa hijau
tidak cukup.

  - Gerbang **urutan** bisa lulus karena kebetulan. Ia membandingkan
    `R − B` piksel paling terang. Kalau penggambar membuang warna spektral
    dan menggambar **semua** bintang dengan satu warna hangat, urutannya bisa
    tetap benar untuk satu pasangan sementara identitasnya sudah lenyap.
    Arah sebaliknya karena itu harus diukur: Rigel **tidak** lebih merah dari
    Betelgeuse, dan jarak antar-bintang **bukan nol**.
  - Gerbang **keraguan** punya lubang yang lebih dalam. Ia menuntut dua
    bintang berbeda tampil **identik** saat ragu (`diff == 0`). Gerbang yang
    menuntut "identik" selalu bisa dipenuhi dengan menggambar **semuanya
    sama** — termasuk saat yakin. Karena itu arah kedua di dalam fungsi yang
    sama (saat yakin, keduanya **harus** berbeda) wajib ikut berbunyi; tanpa
    itu, penggambar yang mengabaikan `color_index` sepenuhnya lolos
    pemeriksaan pertama.

Keadaan yang diuji:

  [baseline]                        kedua gerbang hijau (kalau tidak, harness
                                    salah, bukan kodenya)
  1. warna spektral dibuang di       `star_rgb` selalu mengembalikan satu warna.
     sumber                         Gerbang urutan **merah** (jarak nol), dan
                                    arah "tetap berbeda saat yakin" di gerbang
                                    keraguan **merah** — dua-duanya menangkap
                                    identitas yang lenyap.
  2. penjaga keraguan dilewati       `drawable_star_color_index` mengembalikan
                                    indeks apa pun tanpa melihat
                                    `is_confirmed`. Gerbang keraguan **merah**
                                    di pemeriksaan pertama (dua bintang ragu
                                    tidak lagi identik).
  3. urutan warna dibalik            tabel `star_rgb` dibalik (panas ↔ dingin).
                                    Gerbang urutan **merah** di arah pertama,
                                    sementara gerbang keraguan tetap hijau —
                                    dan itu benar: keduanya masih berbeda
                                    ketika yakin, dan masih identik ketika
                                    ragu. Inilah pembeda "warna salah" dari
                                    "warna hilang".
  4. warna netral jadi spektral      `NEUTRAL_STAR_BODY` dikembalikan menjadi
                                    warna ber-hue (putih kebiruan kelas A).
                                    Gerbang akromatik **merah**, dan gerbang
                                    "Sirius ≠ tak dikenal" **merah**. Ini
                                    regresi yang paling mudah kembali tanpa
                                    terlihat: yang salah bukan urutannya,
                                    melainkan **bahwa netral itu sendiri
                                    mengklaim satu kelas spektral.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
pelajaran yang sudah dibayar di repo ini, `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-warna-bintang.py     # 0 = semua sesuai harapan
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
C.check_star_colour_order(results)
C.check_star_colour_not_a_claim_when_uncertain(results)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Warna spektral bintang: satu tabel, satu penerjemah.
#
# **Kenapa bukan lagi `base = star_rgb(color_index)`.** Jangkar lama itu
# memutasi **satu pemanggil** di `_draw_star`, dan `star_core_rgb` punya
# pemanggil sendiri (`tint = star_rgb(index)`). Mutasinya karenanya hanya
# membuang tint glow, sementara inti tetap berwarna — dan gerbang
# "dua bintang berbeda tetap berbeda saat yakin" membaca gambar yang **masih**
# berbeda, jadi ia tetap hijau. Terukur: dengan mutasi lama, keadaan 1
# melaporkan 2 dari 3 pemeriksaan hijau padahal warna spektral sudah dibuang.
#
# Nama keadaan ini "warna spektral dibuang di **sumber**", jadi mutasinya
# memang harus di sumber: `warmth` yang menerjemahkan B−V menjadi hangat.
# Diratakan berarti tidak ada lagi warna spektral di mana pun — glow maupun
# inti — dan setiap gerbang yang mengaku mengukur warna harus memerah.
WARMTH_LINE = "    warmth = (clamped + 0.35) / 2.45"
WARMTH_FLAT = "    warmth = 0.5"

# Penjaga keraguan: warna hanya boleh sampai ke gambar saat engine yakin.
#
# Jangkar ini **ikut berubah** ketika sentinel warna netral pindah dari
# B−V 0,00 ke `UNKNOWN_STAR_COLOR_INDEX` (di luar rentang B−V). Jangkar lama
# (`return STAR_COLOR_INDEX.get("", 0.0)`) sudah tidak ada di sumber, dan
# harness yang jangkarnya hilang berhenti mengukur apa pun — ia melaporkan
# "jangkar muncul 0x", bukan lulus. Aturan repo ini berlaku di sini: yang
# bergerak adalah jangkarnya, bukan harapannya.
GUARD = ('    if not is_confirmed:\n'
         '        return UNKNOWN_STAR_COLOR_INDEX\n'
         '    return color_index')
GUARD_OFF = '    return color_index'

# Tabel warna: `warmth` menerjemahkan indeks B−V menjadi hangat/dingin.
# Baris jangkarnya sama dengan `WARMTH_LINE` di atas — satu baris, dua mutasi
# (diratakan / dibalik), jadi ia tidak ditulis dua kali.
WARMTH = WARMTH_LINE
WARMTH_FLIPPED = "    warmth = 1.0 - (clamped + 0.35) / 2.45"

# Warna "tidak mengklaim" untuk bintang. Harus **akromatik** (R=G=B): nilai
# ber-hue apa pun adalah warna spektral, dan warna spektral mengklaim kelas
# bintang.
#
# Keadaan 4 memutasi **cabang sentinel** di `star_rgb`, bukan konstanta
# netralnya: itulah bentuk cacat aslinya — sentinel B−V 0,00 yang **lolos ke
# rumus warna biasa**, sehingga keluarannya `star_rgb(0,0)`, warna spektral
# kelas A (Sirius/Vega). Mutasi lewat konstanta hanya menyalin angkanya; yang
# ini menjalankan rumusnya, jadi hasilnya persis seperti dulu.
NEUTRAL_STAR = "    if math.isnan(index):\n        return NEUTRAL_STAR_BODY"
NEUTRAL_STAR_SPECTRAL = "    if math.isnan(index):\n        index = 0.0"

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang
# membuat berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
ORDER = ("betelgeuse lebih merah dari rigel", "betelgeuse lebih merah dari sirius")
IDENTICAL_WHEN_UNSURE = "dua bintang berbeda tampil sama saat ragu"
DIFFERENT_WHEN_SURE = "dua bintang berbeda tetap berbeda saat yakin"
NEUTRAL_WHEN_UNSURE = "warna ragu = warna bintang tak dikenal"
ACHROMATIC_NEUTRAL = "warna tak dikenal benar-benar akromatik (R=G=B)"
SIRIUS_NOT_UNKNOWN = "Sirius terkonfirmasi ≠ bintang tak dikenal (ukuran disamakan)"

HIJAU = "hijau"
MERAH = "merah"


def _expect(**verdicts):
    return verdicts


# (nama keadaan, [(cari, ganti), ...] atau None, {nama pemeriksaan: harapan})
STATES = [
    ("[baseline]", None,
     _expect(**{ORDER[0]: HIJAU, ORDER[1]: HIJAU,
                IDENTICAL_WHEN_UNSURE: HIJAU, DIFFERENT_WHEN_SURE: HIJAU,
                NEUTRAL_WHEN_UNSURE: HIJAU,
                ACHROMATIC_NEUTRAL: HIJAU, SIRIUS_NOT_UNKNOWN: HIJAU})),

    # Warna spektral dibuang: seluruh bintang digambar dengan warna indeks 0.
    # Gerbang urutan memerah karena jaraknya menjadi **nol** — inilah arah yang
    # membuatnya tidak bisa lulus karena kebetulan. Gerbang keraguan memerah di
    # arah "tetap berbeda saat yakin", yang justru ditambahkan untuk menutup
    # penggambar yang membuang warna. Pemeriksaan "sama saat ragu" tetap hijau,
    # dan itu benar: keduanya memang masih identik — sekarang karena keduanya
    # sama-sama tidak berwarna.
    ("1. warna spektral dibuang di sumber",
     [(WARMTH_LINE, WARMTH_FLAT)],
     _expect(**{ORDER[0]: MERAH, ORDER[1]: MERAH,
                IDENTICAL_WHEN_UNSURE: HIJAU, DIFFERENT_WHEN_SURE: MERAH,
                NEUTRAL_WHEN_UNSURE: HIJAU})),

    # Penjaga keraguan dilewati: warna identitas bocor ke gambar yang belum
    # mengklaim apa pun. Dua bintang ragu yang seharusnya identik kini berbeda.
    # Gerbang urutan tetap hijau — ia mengukur bintang **terkunci**, dan
    # bintang terkunci tidak berubah oleh mutasi ini.
    ("2. penjaga keraguan dilewati",
     [(GUARD, GUARD_OFF)],
     _expect(**{ORDER[0]: HIJAU, ORDER[1]: HIJAU,
                IDENTICAL_WHEN_UNSURE: MERAH, DIFFERENT_WHEN_SURE: HIJAU,
                NEUTRAL_WHEN_UNSURE: MERAH})),

    # Urutan dibalik: panas menjadi dingin. Warna **ada**, hanya salah arah.
    # Gerbang urutan memerah; gerbang keraguan hijau di seluruh arahnya —
    # keduanya masih berbeda saat yakin dan masih identik saat ragu. Itulah
    # yang membedakan "warna salah" dari "warna hilang", dan kenapa kedua
    # gerbang itu memang harus ada.
    ("3. urutan warna dibalik",
     [(WARMTH, WARMTH_FLIPPED)],
     _expect(**{ORDER[0]: MERAH, ORDER[1]: MERAH,
                IDENTICAL_WHEN_UNSURE: HIJAU, DIFFERENT_WHEN_SURE: HIJAU,
                NEUTRAL_WHEN_UNSURE: HIJAU})),

    # 4. Warna "tidak mengklaim" dikembalikan menjadi warna **spektral**
    # (putih kebiruan kelas A, yaitu warna Sirius dan Vega). Inilah cacat yang
    # baru ditutup: dulu sentinel-nya memang B−V 0,00, jadi tidak ada
    # pemeriksaan yang bisa melihatnya — ketiganya hanya membandingkan nilai
    # dengan nilai lain. Gerbang baru `ACHROMATIC_NEUTRAL` memerah karena
    # R≠B, dan `SIRIUS_NOT_UNKNOWN` memerah karena Sirius terkonfirmasi
    # kembali tampil sama dengan bintang tak dikenal. Gerbang lain tetap hijau,
    # dan itu benar: urutannya tidak berubah, dan keraguannya masih identik.
    ("4. warna netral dikembalikan jadi spektral",
     [(NEUTRAL_STAR, NEUTRAL_STAR_SPECTRAL)],
     _expect(**{ORDER[0]: HIJAU, ORDER[1]: HIJAU,
                IDENTICAL_WHEN_UNSURE: HIJAU, DIFFERENT_WHEN_SURE: HIJAU,
                NEUTRAL_WHEN_UNSURE: HIJAU,
                ACHROMATIC_NEUTRAL: MERAH, SIRIUS_NOT_UNKNOWN: MERAH})),
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
        # delapan belas saudaranya memutasi berkas produksi yang sama, dan
        # setiap prob membacanya dari proses baru.
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
