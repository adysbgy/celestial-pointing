#!/usr/bin/env python3
"""Buktikan `check_unknown_planet_is_a_neutral_sphere` **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah.

Kelas cacat yang ditutupnya adalah jalur jujur PRD di kelas planet:
`CelestialVisual.Planet(objectID:)` mengembalikan `nil` untuk id yang tidak
dikenal, dan view lalu menggambar bola tanpa ciri. Seluruh `build_cases()`
disaring terhadap nama yang pernah disebut `check-visuals.py`: dua kasus
tidak pernah disebut siapa pun, dan `planet-unknown-confirmed` adalah salah
satunya. Terukur: mengganti cabang `planet is None` dengan palet Mars di
port **dan** di view menghasilkan 0 piksel berbeda dari gambar Mars, dan
`check-visuals.py --check` tetap melaporkan **654 pemeriksaan, 0 gagal** —
gerbangnya tidak melihatnya sama sekali. Setelah gerbang ini ditambahkan,
hitungannya 660.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                     gerbang hijau (kalau tidak, harness salah)
  1. port: tak dikenal -> Mars   cabang `planet is None` di port memakai
                                 palet Mars. Harus menyalakan pemeriksaan
                                 "== token netral" pada kedua ukuran, karena
                                 bola netral sekarang berwarna Mars.
  2. view: tak dikenal -> Mars   cabang `guard let planet = visual.planet
                                 else` di view memakai palet Mars. Pikselnya
                                 **tidak berubah** (yang diukur gerbang
                                 adalah port), jadi hanya pemeriksaan teks
                                 yang bisa melihatnya. Keadaan ini ada
                                 khusus untuk membuktikan sisi view memang
                                 diperiksa, bukan cuma diklaim.
  3. port: `if True:`            cabang "tak dikenal" dibuat menangkap
                                 **semua** planet, jadi setiap planet nyata
                                 digambar sebagai bola netral. Arah
                                 sebaliknya: tanpa keadaan ini, gerbang yang
                                 cuma menuntut "tak dikenal == netral" akan
                                 hijau pada aplikasi yang tidak pernah
                                 membedakan planet mana pun. Terukur:
                                 kelima planet jatuh ke 0.003.
  4. palet Merkurius -> netral    penggantian paling halus: Merkurius memang
                                 dunia abu (jarak 0.0435, planet terdekat
                                 dari token netral). Keadaan ini membuktikan
                                 ambangnya **tidak** bergantung pada planet
                                 yang kebetulan berwarna jauh.
  5. token netral port -> Mars    `NEUTRAL_BODY` di port diganti palet Mars.
                                 Bola tak dikenal jadi planet. Menyalakan
                                 arah pertama saja — dan itu **temuan**,
                                 bukan cacat: arah kedua membandingkan
                                 planet terhadap token **view**, yang tidak
                                 ikut berubah. Kedua arah membaca sumber
                                 kebenaran yang berbeda (piksel lawan token
                                 view), jadi keadaan yang menggerakkan satu
                                 sisi memang hanya boleh menyalakan satu
                                 arah.
  6. view: token -> palet Mars    `neutralBody` di view diganti palet Mars
                                 (nilainya, bukan pemakaiannya). Piksel port
                                 tetap 0.74, tokennya jadi 0.88 — jadi arah
                                 pertama berbunyi, arah kedua tetap hijau.
                                 Pasangan keadaan 2 pada sisi token, bukan
                                 sisi cabang.

**Batas yang dinyatakan.** Arah kedua diukur pada **piksel paling terang**
piringan, dan pada Merkurius piksel itu milik bibir kawah, bukan permukaan
bolanya. Jadi mengganti hanya `light` Merkurius menjadi token netral
**tidak** menyalakan apa pun (terukur 0 merah) — yang menangkapnya adalah
mengganti `light` **dan** `dark` (terukur 1 merah, 0.003). Itu bukan lubang
yang perlu ditutup sekarang: bola netral penuh memang berarti keduanya, dan
itulah keadaan yang diuji keadaan 4. Dicatat supaya orang berikutnya tidak
mengira cakupannya lebih luas daripada ini.

Berkas sumber produksi (`Tools/render-visuals.py` dan
`Apps/Shared/CelestialVisualView.swift`) **dimutasi dengan sengaja** lalu
dipulihkan di `finally` per keadaan. Kegagalan di tengah tidak boleh
meninggalkan mutasi hidup — pelajaran yang sudah dibayar di repo ini
(`SIGKILL` melewati `finally`, jadi ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-bola-netral.py
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
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")

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
C.check_unknown_planet_is_a_neutral_sphere(results)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Jangkar di port. `str.replace` atas jangkar yang muncul dua kali akan
#: mengubah keduanya, dan harness lalu melaporkan keadaan yang tidak pernah
#: ia uji — jadi jumlah kemunculannya diperiksa eksplisit di `main()`.
PORT_BRANCH = ('    if planet is None:\n'
               '        _draw_sphere(canvas, cx, cy, radius, NEUTRAL_BODY, '
               'NEUTRAL_SHADOW, night_mode)\n'
               '        return')
PORT_MERCURY = ('    "mercury": dict(light=(0.72, 0.70, 0.68), '
                'dark=(0.26, 0.25, 0.24), feature="craters"),')
PORT_NEUTRAL_BODY = 'NEUTRAL_BODY = (0.74, 0.72, 0.68)'

#: Jangkar di view. Cabang "tak dikenal" dan tokennya, dua hal berbeda.
VIEW_BRANCH = ('            drawSphere(context: context, center: center, radius: radius,\n'
               '                       from: Self.neutralBody, to: Self.neutralShadow)')
VIEW_TOKEN = ('    private static let neutralBody = CelestialVisual.RGBComponents('
              'red: 0.74, green: 0.72, blue: 0.68)')

#: Nama pemeriksaan yang dikutip di `must_fire`. Ditulis sebagai potongan
#: unik, bukan kalimat penuh: kalimatnya memuat angka yang berubah bersama
#: ambangnya, dan harness yang ikut berubah bersama gerbangnya tidak menjaga
#: apa pun.
NEUTRAL_EQ = "== token netral"
PLANET_NOT_NEUTRAL = "planet nyata bukan bola netral"
VIEW_TOKEN_USED = "view memakai token netral"
VIEW_NO_PALETTE = "view tidak meminjam palet planet"

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
#: Keadaan 2 dan 3 sengaja berpasangan, dan **pasangan itulah buktinya**:
#: keduanya mengubah cabang yang sama di dua berkas berbeda. Keadaan 2 tidak
#: menggerakkan satu piksel pun (gerbang mengukur port), jadi kalau ia
#: berhenti menyalakan pemeriksaan teks, artinya sisi view sudah tidak
#: diperiksa siapa pun — dan seluruh pemeriksaan piksel tetap hijau.
STATES = [
    ("[baseline]", None, []),
    ("1. port: tak dikenal -> palet Mars",
     [(RENDER, PORT_BRANCH,
       '    if planet is None:\n'
       '        _draw_sphere(canvas, cx, cy, radius, PLANET_PALETTE["mars"]["light"],\n'
       '                     PLANET_PALETTE["mars"]["dark"], night_mode)\n'
       '        return')],
     [NEUTRAL_EQ]),
    ("2. view: tak dikenal -> palet Mars",
     [(VIEW, VIEW_BRANCH,
       '            drawSphere(context: context, center: center, radius: radius,\n'
       '                       from: CelestialVisual.Planet.mars.palette.light,\n'
       '                       to: CelestialVisual.Planet.mars.palette.dark)')],
     [VIEW_TOKEN_USED, VIEW_NO_PALETTE]),
    ("3. port: `if True:` — semua planet jadi bola netral",
     [(RENDER, PORT_BRANCH,
       PORT_BRANCH.replace('    if planet is None:', '    if True:'))],
     [PLANET_NOT_NEUTRAL]),
    ("4. port: palet Merkurius -> bola netral",
     [(RENDER, PORT_MERCURY,
       '    "mercury": dict(light=(0.74, 0.72, 0.68), dark=(0.74, 0.72, 0.68), '
       'feature="craters"),')],
     [PLANET_NOT_NEUTRAL]),
    ("5. port: token netral -> palet Mars",
     [(RENDER, PORT_NEUTRAL_BODY,
       'NEUTRAL_BODY = (0.88, 0.42, 0.26)')],
     [NEUTRAL_EQ]),
    ("6. view: token netral -> palet Mars",
     [(VIEW, VIEW_TOKEN,
       '    private static let neutralBody = CelestialVisual.RGBComponents('
       'red: 0.88, green: 0.42, blue: 0.26)')],
     [NEUTRAL_EQ]),
]

_originals = {}
_sources = (RENDER, VIEW)


def restore(*_):
    """Pulihkan kedua sumber produksi — juga saat dihentikan sinyal.

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
            (RENDER, PORT_BRANCH, "cabang planet tak dikenal di port"),
            (RENDER, PORT_MERCURY, "palet Merkurius di port"),
            (RENDER, PORT_NEUTRAL_BODY, "token netral di port"),
            (VIEW, VIEW_BRANCH, "cabang planet tak dikenal di view"),
            (VIEW, VIEW_TOKEN, "token netral di view")):
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
