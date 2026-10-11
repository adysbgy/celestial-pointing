#!/usr/bin/env python3
"""Buktikan gerbang "cembung mengecil masih berbentuk cembung" **berbunyi**.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah.

Kelas cacat yang ditutupnya. Jalur fase `waning` dibentuk dua besaran: sisi
terang (`lit_side`) dan posisi terminator (`terminator_offset`). Untuk sabit
(f < 0.5) jalur itu dijaga `check_phase_direction_on_the_waning_half`. Tetapi
**cembung mengecil** (f > 0.5) berada di luar cakupannya: kasus
`moon-waning-gibbous` tidak pernah ia baca, dan `check_moon_phase_fraction`
hanya menjalankan kasus `is_waxing=True`.

Terukur dengan mutasi yang membalikkan tanda `terminator_offset` pada fase
cembung mengecil **saja**:

    13.944 piksel berubah dari 40.000
    luas tersinari 0,715 -> 0,275
    nol dari 14 pemeriksaan fase yang ada menjadi merah

Jadi terminator bisa menyeberang ke sisi yang salah — cembung berubah jadi
sabit semu — dan seluruh gerbang fase tetap hijau. Tidak ada teks layar yang
membantahnya: yang tampil tetap piringan Bulan dengan fase.

**Dua kesalahan pengukuran saya sendiri, keduanya tertangkap sebelum push.**

  1. Dugaan pertama adalah bahwa cacat ini akan membalik **arah** sabit.
     Diukur, dan itu salah: pada sudut -pi/2 mutasi itu menghasilkan
     dy = +0,613, masih "bawah", sama seperti kode yang benar (dy = +0,237).
     Pusat massa tidak membalik karena geometri cermin (`lit_side`
     berlawanan) mengimbangi terminatornya. Yang runtuh adalah **luasnya**.
     Gerbangnya karena itu mengukur keduanya, dan yang menggigit cacat ini
     adalah luasnya — bukan arahnya.

  2. Percobaan pertama membuktikan "nol dari 14 pemeriksaan merah" dengan
     **menimpa `R.phase_geometry` pada modul yang salah**. `check-visuals.py`
     memuat `render-visuals.py` lewat `_load()`-nya sendiri, jadi modul yang
     saya mutasi bukan modul yang dibaca gerbangnya. Angkanya tampak sah
     (nol merah) padahal yang diukur adalah berkas yang tidak tersentuh.
     Harness ini karena itu memutasi **berkas di disk** dan menjalankan
     gerbangnya di proses baru — persis seperti saudara-saudaranya.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, lewat `mutasi_sumber` (tulis atomik +
pemulihan terverifikasi). Kegagalan di tengah tidak boleh meninggalkan mutasi
hidup — pelajaran yang sudah dibayar di repo ini (`SIGKILL` melewati
`finally`, jadi ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-cembung-mengecil.py
"""

from __future__ import annotations

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
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong —
# itulah persis kesalahan kedua yang dicatat di docstring berkas ini.
PROBE = r"""
import importlib.util, os, sys
ROOT = sys.argv[1]

def load(name, filename):
    path = os.path.join(ROOT, "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
results = []
C.check_waning_gibbous_lit_side(results)
# `TAK: ` / `YA: ` — dipisah supaya kelasnya dihitung di proses ini, atas
# **semua** pemeriksaan (bukan cuma yang merah). Tanpa itu, gerbang yang
# berhenti mengukur tidak bisa dibedakan dari gerbang yang hijau.
for r in results:
    print(("YA: " if r.ok else "TAK: ") + r.name + "  " + r.detail)
"""

#: Jangkar di port: baris yang menghitung `terminator_offset`. Muncul tepat
#: sekali — diperiksa eksplisit di `main()`, karena jangkar yang muncul dua
#: kali mengubah lebih banyak daripada yang dimaksud dan harness lalu
#: melaporkan keadaan yang tidak pernah ia uji.
PORT_TERMINATOR = '    return dict(terminator_offset=lit_side * (1 - 2 * f), lit_side=lit_side, is_gibbous=f > 0.5)'

#: Keadaan 1 — tanda terminator dibalik **hanya untuk cembung mengecil**.
#:
#: Kenapa bersyarat, bukan dibalik untuk semua fase: membaliknya untuk
#: **semua** fase juga akan menyalakan gerbang sabit yang sudah ada
#: (`check_phase_direction_on_the_waning_half` 5 pemeriksaan,
#: `check_crescent_direction` 4). Keadaan seperti itu terlihat "sesuai
#: harapan" padahal ia tidak membuktikan bahwa gerbang **baru** ini yang
#: menangkap kelas cembung — ia hanya membuktikan gerbang lama masih hidup.
#: Yang harus dibuktikan adalah celah **spesifik** pada f > 0.5.
PORT_TERMINATOR_WANING_GIBBOUS_FLIP = (
    '    offset = lit_side * (1 - 2 * f)\n'
    '    if f > 0.5 and not waxing:\n'
    '        offset = -offset\n'
    '    return dict(terminator_offset=offset, lit_side=lit_side, is_gibbous=f > 0.5)')

#: Keadaan 2 — arah sebaliknya, dan ini yang menjaga makna "cembung".
#:
#: Tanpa pasangan ini, cara termurah memenuhi "luasnya masih cembung" adalah
#: menggambar **piringan penuh** untuk setiap fase: luasnya 1,0, jauh di atas
#: lantai 0,60, dan gerbang luasnya hijau selamanya. Keadaan ini menuntut
#: pemeriksaan **arah** yang berbunyi — dan hanya dia.
#:
#: **Mutasi pertamanya salah, tertangkap oleh harness ini sendiri.**
#: `offset = lit_side * 1.0` menaruh terminator **tepat di limb**, dan itu
#: menghasilkan piringan **gelap** (terukur 0,000), bukan penuh — kebalikan
#: dari maksudnya. Yang membuat piringan penuh adalah terminator di kutub
#: berlawanan, `offset = -lit_side`. Dua-duanya "satu baris", dan hanya yang
#: kedua menguji kelas yang dimaksud.
PORT_TERMINATOR_FULL_DISC = (
    '    offset = lit_side * (1 - 2 * f)\n'
    '    offset = -lit_side\n'
    '    return dict(terminator_offset=offset, lit_side=lit_side, is_gibbous=f > 0.5)')

#: **Kelas** pemeriksaan, bukan nama satu per satu — alasan yang sama dengan
#: `bukti-mutasi-maria.py`: daftar nama membusuk sendiri tiap kali katalog
#: kasusnya bertambah, sedangkan kelas mengikuti gerbangnya.
AREA_CLASS = "luasnya masih cembung"
DIRECTION_CLASS = "sisi terang menghadap bawah"

#: Setiap keadaan: (nama, daftar (berkas, jangkar, pengganti), kelas yang
#: **wajib** merah).
#:
#: `None` = jalankan apa adanya (baseline) dan wajib **nol** merah.
#:
#: Yang dituntut bukan «ada yang merah», melainkan **yang mana**. Gerbang
#: yang berbunyi pada pemeriksaan yang salah mengukur hal lain daripada yang
#: diklaimnya — kelas cacat yang sudah berulang di repo ini.
STATES = [
    ("[baseline]", None, []),
    ("1. port: terminator cembung mengecil dibalik",
     [(RENDER, PORT_TERMINATOR, PORT_TERMINATOR_WANING_GIBBOUS_FLIP)],
     [AREA_CLASS]),
    ("2. port: terminator ke kutub jauh (piringan penuh)",
     [(RENDER, PORT_TERMINATOR, PORT_TERMINATOR_FULL_DISC)],
     [DIRECTION_CLASS]),
]

_originals = {}
_sources = (RENDER,)


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(path, "w")`: belasan harness di
    `Tools/` memutasi berkas produksi yang sama dan setiap prob membacanya
    dari proses baru, jadi penulisan biasa membuat pembaca bisa melihat
    berkas setengah jadi. Pemulihannya juga **diverifikasi** — kegagalan
    pemulihan bersifat diam dan lalu menyalahkan kode yang benar.
    """
    for path, content in _originals.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)


def probe():
    """Jalankan gerbangnya langsung → (daftar (ok, nama), galat).

    Mengembalikan **semua** pemeriksaan beserta keadaannya, bukan cuma yang
    merah: yang dituntut harness ini adalah **cakupan** sebuah kelas, dan
    kelas yang berhenti mengukur terlihat persis seperti kelas yang hijau
    kalau yang merah saja yang dikembalikan.
    """
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None, (proc.stderr.strip().splitlines()[-1:] or ["(tanpa galat)"])
    checks = []
    for line in proc.stdout.splitlines():
        if line.startswith("YA: "):
            checks.append((True, line[4:]))
        elif line.startswith("TAK: "):
            checks.append((False, line[5:]))
    if not checks:
        return None, ["probe tidak melaporkan satu pemeriksaan pun"]
    return checks, None


def main():
    mutasi_sumber.require_clean_sources(list(_sources))

    # Jangkar diperiksa **sebelum** apa pun dimutasi. Jangkar yang muncul dua
    # kali mengubah lebih banyak daripada yang dimaksud, dan jangkar yang
    # hilang membuat seluruh harness melaporkan "keadaan tidak sesuai
    # harapan" tanpa pernah menjalankan mutasinya.
    for path in _sources:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()
    for path, anchor, label in (
            (RENDER, PORT_TERMINATOR, "perhitungan terminator di port"),):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x "
                  "— harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    def run_state(mutations):
        """Pasang mutasi (kalau ada), jalankan probe, pulihkan."""
        for path in _sources:
            mutasi_sumber.write_source(path, _originals[path])
        if mutations is not None:
            for path, old, new in mutations:
                content = _originals[path].replace(old, new, 1)
                if content == _originals[path]:
                    return None, [f"ANCHOR TIDAK DITEMUKAN: {old!r}"]
                # `_originals` tetap memegang aslinya supaya `finally`
                # memulihkan yang benar walau keadaan ini gagal di tengah;
                # yang ditulis ke disk adalah salinan yang termutasi.
                mutasi_sumber.write_source(path, content)
        try:
            return probe()
        finally:
            restore()

    failures = []
    try:
        for label, mutations, must_fire in STATES:
            checks, err = run_state(mutations)
            if err is not None:
                failures.append(f"{label}: {err[0]}")
                print(f"SALAH {label}: {err[0]}")
                continue
            red = [name for ok, name in checks if not ok]
            # Kelas yang dituntut dihitung dari **nama pemeriksaannya**, bukan
            # dari daftar yang diketik ulang: gerbang yang menambah
            # pemeriksaan baru otomatis ikut tertuntut.
            expected = [name for _, name in checks
                        if any(c in name for c in must_fire)]
            unexpected = [n for n in red
                          if not any(c in n for c in must_fire)]
            if must_fire:
                if not expected:
                    failures.append(
                        f"{label}: kelas {must_fire} tidak punya pemeriksaan "
                        f"yang cocok — gerbangnya berhenti mengukur kelas ini")
                    print(f"SALAH {label}: kelas {must_fire} tidak cocok "
                          f"dengan satu pemeriksaan pun")
                    continue
                missing = [n for n in expected if n not in red]
                if missing:
                    failures.append(
                        f"{label}: gerbang TIDAK berbunyi — "
                        f"{len(missing)} dari {len(expected)} tetap hijau")
                    print(f"SALAH {label}: {len(missing)}/{len(expected)} "
                          f"tidak merah:")
                    for n in missing:
                        print(f"       - {n}")
                elif unexpected:
                    failures.append(
                        f"{label}: {len(unexpected)} pemeriksaan di luar kelas "
                        f"ikut merah — gerbangnya tidak memisahkan kelas")
                    print(f"SALAH {label}: merah di luar kelas yang diminta:")
                    for n in unexpected:
                        print(f"       - {n}")
                else:
                    print(f"OK   {label:44s} {len(red)} merah")
                    for n in red:
                        print(f"       {n}")
            else:
                if red:
                    failures.append(
                        f"{label}: {len(red)} merah pada kode yang benar — "
                        f"gerbangnya salah, bukan kodenya")
                    print(f"SALAH {label}: {len(red)} merah pada kode benar:")
                    for n in red:
                        print(f"       - {n}")
                else:
                    print(f"OK   {label:44s} 0 merah")
    finally:
        restore()

    print()
    if failures:
        print(f"{len(failures)} keadaan tidak sesuai harapan:")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")
    sys.exit(0)


if __name__ == "__main__":
    main()
