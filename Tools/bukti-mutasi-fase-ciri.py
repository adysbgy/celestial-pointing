#!/usr/bin/env python3
"""Buktikan gerbang "ciri planet berfase tidak bocor" **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

`check_phase_feature_stays_inside_the_lit_band` dan
`check_phase_feature_still_draws_on_the_lit_side` ditambahkan ke
`Tools/check-visuals.py` dalam siklus yang sama dengan gerbangnya. Gerbang
gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa pun. Yang
harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada keadaan yang
memang salah.

Kelas cacat yang ditutupnya. Kawah Merkurius dan kabut Venus memang digambar
**di dalam** pita yang menyala di kedua bahasa (`_draw_craters(...,
inside_lit=...)` di port, `inner.clip(to: lit)` di view). Sampai gerbang ini
ada, tidak satu pun dari 666 pemeriksaan mengukur **akibat** pemotongan itu:
melepas `inside_lit` dari pemanggilan `_draw_craters` membuat kawah melompat
keluar sabit — **2004** piksel menyala di belahan gelap pada 200 px, **71** di
ukuran kartu jam — dan seluruh `check-visuals.py --check` tetap melaporkan
**0 gagal**. Untuk Venus, melepas potongan kabutnya mengisi seluruh belahan
gelap: **14714** piksel pada 200 px.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                        kedua gerbang hijau (kalau tidak, harness
                                    ini salah, bukan gerbangnya)
  1. port: kawah tak dipotong       `inside_lit` dilepas dari pemanggilan
                                    `_draw_craters` di port. Harus menyalakan
                                    **kedua ukuran** — bukan hanya 200 px —
                                    karena ukuran kartu jam adalah satu-satunya
                                    ukuran yang penting bagi pengguna, dan
                                    cacat yang tidak terlihat di satu ukuran
                                    bisa dominan di ukuran lain.
  2. port: kabut Venus tak dipotong `haze_clipped` meneruskan gradien tanpa
                                    memeriksa poligon pita. Harus menyalakan
                                    kedua ukuran untuk Venus.
  3. port: kawah tidak digambar     `_draw_craters` kembali lebih awal, jadi
                                    kawah hilang sama sekali. Ini keadaan
                                    **arah sebaliknya**, dan justru yang paling
                                    penting: tanpa gerbang pasangannya, cara
                                    termurah memenuhi "nol piksel di belahan
                                    gelap" adalah berhenti menggambar cirinya.
                                    Yang berbunyi di sini harus
                                    "masih tergambar di sisi menyala", **bukan**
                                    "tidak bocor ke sisi gelap" — kalau keduanya
                                    berbunyi, gerbangnya tidak memisahkan
                                    "dipotong" dari "dihapus", dan itu dua
                                    perbaikan yang berlawanan arah.

**Batas yang dinyatakan.** Keadaan 1–3 memutasi **port Python**, bukan view
Swift: yang diukur kedua gerbang itu adalah piksel port, jadi hanya port yang
bisa menggerakkannya. Sisi view (`.clip(to: lit)` di
`CelestialVisualView.swift`) dijaga pemeriksaan teks lain, dan harness ini
tidak mengklaim lebih dari itu — kalimat yang sama sudah ditulis di
`bukti-mutasi-bola-netral.py` untuk keadaan yang sama bentuknya.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, lewat `mutasi_sumber` (tulis atomik +
pemulihan terverifikasi). Kegagalan di tengah tidak boleh meninggalkan mutasi
hidup — pelajaran yang sudah dibayar di repo ini (`SIGKILL` melewati `finally`,
jadi ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-fase-ciri.py
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
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
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
C.check_phase_feature_stays_inside_the_lit_band(results)
C.check_phase_feature_still_draws_on_the_lit_side(results)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Jangkar di port. `str.replace` atas jangkar yang muncul dua kali akan
#: mengubah keduanya, dan harness lalu melaporkan keadaan yang tidak pernah
#: ia uji — jadi jumlah kemunculannya diperiksa eksplisit di `main()`.
#:
#: Keadaan 1: potongan kawah dilepas. Yang dihapus hanya argumennya, bukan
#: pemanggilannya — `_draw_craters` tetap menggambar, jadi kalau gerbangnya
#: tetap hijau, artinya yang diukur bukan "apakah ciri dipotong".
PORT_CRATER_CLIP = ('            _draw_craters(canvas, cx, cy, radius, night_mode,\n'
                    '                          inside_lit=lambda x, y: '
                    '_point_in_polygon(x, y, points))')
PORT_CRATER_NOCLIP = '            _draw_craters(canvas, cx, cy, radius, night_mode)'

#: Keadaan 2: potongan kabut Venus dilepas. Syaratnya diganti `False` sehingga
#: gradien diteruskan untuk **setiap** piksel elipsnya, bukan hanya yang di
#: dalam pita.
PORT_HAZE_CLIP = ('                if not _point_in_polygon(x, y, points):\n'
                  '                    return (rgb, 0.0)')
PORT_HAZE_NOCLIP = ('                if False:\n'
                    '                    return (rgb, 0.0)')

#: Keadaan 3: kawah tidak digambar sama sekali — kembali tepat setelah
#: docstring. Jangkar komentarnya dipakai karena ia baris pertama badan fungsi,
#: dan menyisipkan `return` di situ tidak mengubah apa pun yang lain.
PORT_CRATER_BODY = ('    # `accent_fn` (bukan `color_fn` + `solid`): keduanya '
                    'sudah mengembalikan\n'
                    '    # fungsi `(x, y) -> (rgb, alpha)`, dan yang menentukan '
                    'terangnya adalah')
PORT_CRATER_RETURN = ('    return\n'
                      + PORT_CRATER_BODY)

#: Nama pemeriksaan yang dikutip di `must_fire`. Ditulis sebagai potongan
#: unik, bukan kalimat penuh: kalimatnya memuat angka yang berubah bersama
#: ambangnya, dan harness yang ikut berubah bersama gerbangnya tidak menjaga
#: apa pun.
DARK_MERCURY_200 = "ciri mercury tidak bocor ke sisi gelap (panel 200 px)"
DARK_MERCURY_WATCH = "ciri mercury tidak bocor ke sisi gelap (kartu jam 38 px)"
DARK_VENUS_200 = "ciri venus tidak bocor ke sisi gelap (panel 200 px)"
DARK_VENUS_WATCH = "ciri venus tidak bocor ke sisi gelap (kartu jam 38 px)"
LIT_MERCURY = "ciri mercury masih tergambar di sisi menyala"
LIT_VENUS = "ciri venus masih tergambar di sisi menyala"

#: Setiap keadaan: (nama, daftar (berkas, jangkar, pengganti), pemeriksaan
#: yang **wajib** merah).
#:
#: `None` = jalankan apa adanya (baseline) dan wajib **nol** merah.
#:
#: Yang dituntut bukan «ada yang merah», melainkan **yang mana**. Gerbang
#: yang berbunyi pada pemeriksaan yang salah mengukur hal lain daripada yang
#: diklaimnya — kelas cacat yang sudah berulang di repo ini. Karena itu tiap
#: keadaan menyebut pemeriksaan mana yang harus berbunyi, dan `probe()`
#: menuntut yang **tidak** disebut tetap hijau.
#:
#: Keadaan 1 dan 2 sengaja terpisah, dan **pemisahan itulah buktinya**: kalau
#: satu keadaan menyalakan kedua planet, gerbangnya tidak membedakan kawah
#: dari kabut, dan laporan "ciri Mercury bocor" bisa datang dari kabut Venus.
#: Keadaan 3 adalah arah sebaliknya: ia harus menyalakan **hanya** gerbang
#: "masih tergambar", bukan gerbang pemotongan.
STATES = [
    ("[baseline]", None, []),
    ("1. port: kawah Merkurius tak dipotong",
     [(RENDER, PORT_CRATER_CLIP, PORT_CRATER_NOCLIP)],
     [DARK_MERCURY_200, DARK_MERCURY_WATCH]),
    ("2. port: kabut Venus tak dipotong",
     [(RENDER, PORT_HAZE_CLIP, PORT_HAZE_NOCLIP)],
     [DARK_VENUS_200, DARK_VENUS_WATCH]),
    ("3. port: kawah tidak digambar sama sekali",
     [(RENDER, PORT_CRATER_BODY, PORT_CRATER_RETURN)],
     [LIT_MERCURY]),
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
    """Jalankan gerbangnya langsung → (daftar_baris_gagal, semua_baris)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None, proc.stderr.strip().splitlines()[-1:] or ["(tanpa galat)"]
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    failed = [line for line in lines if line.startswith("GAGAL")]
    return failed, lines


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
            (RENDER, PORT_CRATER_CLIP, "pemanggilan `_draw_craters` berfase di port"),
            (RENDER, PORT_HAZE_CLIP, "potongan kabut Venus di port"),
            (RENDER, PORT_CRATER_BODY, "baris pertama badan `_draw_craters` di port")):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x "
                  "— harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutations, must_fire in STATES:
            for path in _sources:
                mutasi_sumber.write_source(path, _originals[path])
            if mutations is not None:
                for path, old, new in mutations:
                    content = _originals[path].replace(old, new, 1)
                    if content == _originals[path]:
                        print(f"{label:44s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                        unexpected += 1
                        continue
                    # `_originals` tetap memegang aslinya supaya `finally`
                    # memulihkan yang benar walau keadaan ini gagal di tengah;
                    # yang ditulis ke disk adalah salinan yang termutasi.
                    mutasi_sumber.write_source(path, content)

            failed, lines = probe()
            if failed is None:
                print(f"{label:44s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            names = " | ".join(line.split("  ")[0][6:].strip() for line in failed)
            # Yang dituntut bukan «ada yang merah», melainkan **yang mana**.
            # Dua arah diperiksa, dan arah kedua itu yang paling mudah
            # terlupa: pemeriksaan yang **tidak** disebut di sini wajib tetap
            # hijau. Tanpa itu, satu keadaan yang menyalakan seluruh
            # pemeriksaan akan terlihat "sesuai harapan", padahal artinya
            # gerbangnya tidak memisahkan apa pun — ia cuma berisik.
            missing = [want for want in must_fire
                       if not any(want in line for line in failed)]
            spurious = [line for line in failed
                        if not any(want in line for want in must_fire)]
            ok = not missing and not spurious
            if not ok:
                unexpected += 1
            detail = f"{len(failed)} merah" if failed else "0 merah"
            print(f"{'OK  ' if ok else 'SALAH'} {label:44s} {detail}")
            if names:
                print(f"       {names}")
            for want in missing:
                print(f"       HARUSNYA MERAH, TIDAK: {want}")
            for line in spurious:
                print(f"       MERAH YANG TIDAK DIMINTA: {line.split('  ')[0]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
