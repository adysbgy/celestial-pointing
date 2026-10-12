#!/usr/bin/env python3
"""Buktikan gerbang setengah-lebar spike bintang **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah.

Kelas cacat yang ditutupnya: `spikeRootWidthFactor` (0.18) dan
`spikeTipWidthFactor` (0.035) adalah lebar **penuh**. Kedua bahasa
mengalikannya dengan `0.5` sebelum dipakai sebagai setengah-lebar — angka
itulah yang menjaga spike tetap terbaca sebagai **cahaya**, bukan sebagai
penanda bidik. Sampai siklus ini hanya **port** yang dijaga
(`check_port_constants_reach_the_drawing` menuntut `SPIKE_ROOT_WIDTH_FACTOR *
0.5`), sedangkan sisi view tidak dijaga apa pun.

Terukur sebelum gerbangnya ada: menghapus `* 0.5` dari **kedua** baris view
meninggalkan **22 pemeriksaan bintang hijau, 0 merah** — termasuk
`check_star_geometry_matches_the_model` dan `check_star_pulse_reaches_the_picture`.
Itu yang membuat harness ini wajib: kalau tidak ada satu keadaan pun yang
membuktikan gerbang barunya berbunyi, ia hanya menambah entri hijau.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                      gerbang hijau (kalau tidak, harness salah)

  1. view: pembagi dua `rootHalf`  `* 0.5` dihapus dari baris **pangkal** saja.
     dihapus                       Hanya pemeriksaan pangkal view yang boleh
                                   berbunyi; pemeriksaan ujung wajib tetap
                                   hijau. Ini yang membuktikan kedua baris
                                   diukur **terpisah**, bukan satu.

  2. view: pembagi dua `tipHalf`   Arah sebaliknya dari keadaan 1. Tanpa
     dihapus                       pasangan ini, gerbang yang hanya membaca
                                   satu baris akan hijau pada cacat yang lain.

  3. view: kedua pembagi dihapus   Cacatnya persis (spike dua kali lebih berat
                                   di app). Kedua pemeriksaan view wajib
                                   berbunyi — dan **inilah keadaan yang
                                   membuktikan gerbang lama buta**: seluruh
                                   pemeriksaan tetangga (model & denyut)
                                   dijalankan di sini dan wajib tetap hijau.

  4. port: pembagi dua dihapus     Sisi bahasa kedua. Gerbangnya mengukur
                                   kedua bahasa; kalau hanya view yang
                                   diperiksa, mutasi port lolos.

  5. view: `rootHalf` diganti nama  Baris yang tidak lagi terbaca harus
                                   **merah**, bukan hijau. Pemeriksaan yang
                                   kehilangan subjeknya tidak boleh diam —
                                   itu kontrol negatif untuk pembacanya.

**Keadaan 1, 2, dan 3 tidak bisa saling menggantikan.** 1 dan 2 menguji bahwa
kedua baris diukur terpisah; 3 menguji cacat penuhnya sekaligus klaim "gerbang
tetangga buta pada angka ini". Kalau salah satunya dilewat, gerbangnya bisa
dibalik tanpa berbunyi di sisi itu.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
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
# Gerbang baru: lima hasil (root/tip × view/port, plus kesamaan kedua bahasa).
C.check_star_spike_halving_reaches_both_languages(results)
# **Tetangga yang wajib tetap hijau**: inilah bukti hidup untuk klaim
# "gerbang lama buta pada pembagi duanya".
C.check_star_geometry_matches_the_model(results)
C.check_star_pulse_reaches_the_picture(results, 200, 2)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Jangkar di view. Dua baris **utuh**, supaya pemisahan pangkal/ujung tidak
#: bergantung pada spasi di sekitarnya. `str.replace` atas jangkar yang muncul
#: dua kali akan mengubah keduanya, dan harness lalu melaporkan keadaan yang
#: tidak pernah ia uji — jadi jumlah kemunculannya diperiksa eksplisit.
VIEW_ROOT_HALF = ("        let rootHalf = coreRadius * "
                  "CGFloat(geometry.spikeRootWidthFactor) * 0.5 * pulseFactor")
VIEW_TIP_HALF = ("        let tipHalf = coreRadius * "
                 "CGFloat(geometry.spikeTipWidthFactor) * 0.5 * pulseFactor")

#: Jangkar di port (satu baris, karena bentuknya memang satu baris).
PORT_ROOT_HALF = ("    root_half = core_radius * SPIKE_ROOT_WIDTH_FACTOR * "
                  "0.5 * pulse_factor")

#: Nama pemeriksaan yang dikutip di `must_fire`, sebagai potongan unik.
VIEW_ROOT = "setengah-lebar root dibagi dua (view)"
VIEW_TIP = "setengah-lebar tip dibagi dua (view)"
PORT_ROOT = "setengah-lebar root dibagi dua (port)"
#: Perbandingan kedua bahasa. Ia **memang** ikut berbunyi di setiap keadaan
#: yang memutasi satu sisi, dan itu benar: kalau salah satu bahasa berhenti
#: membagi dua, kedua bahasa tidak lagi sama. Diukur, bukan dikira: draf
#: pertama harness ini tidak menyebutnya, dan kelima keadaan dilaporkan
#: "MERAH YANG TIDAK DIMINTA" — gerbangnya benar, harapan harness-nya yang
#: kurang lengkap.
BOTH_SAME = "setengah-lebar view == port"

#: Tetangga yang **wajib tetap hijau** saat cacatnya dipasang. Inilah klaim
#: "gerbang lama buta pada pembagi duanya", dan ini satu-satunya tempat ia
#: diukur.
NEIGHBOURS = [
    "geometri bintang: spikeScale",
    "denyut bintang: puncak > diam > palung",
]

#: Setiap keadaan: (nama, daftar (berkas, jangkar, pengganti), pemeriksaan
#: yang **wajib** merah, pemeriksaan yang **wajib tetap hijau**).
#:
#: `None` = jalankan apa adanya (baseline) dan wajib **nol** merah.
#:
#: Yang dituntut bukan «ada yang merah», melainkan **yang mana**: gerbang yang
#: berbunyi pada pemeriksaan yang salah mengukur hal lain daripada yang
#: diklaimnya. Karena itu tiap keadaan menyebut pemeriksaan mana yang harus
#: berbunyi, dan `probe()` menuntut yang **tidak** disebut tetap hijau.
STATES = [
    ("[baseline]", None, [], []),
    ("1. view: pembagi dua pangkal dihapus",
     [(VIEW, VIEW_ROOT_HALF, VIEW_ROOT_HALF.replace(" * 0.5 *", " * "))],
     [VIEW_ROOT, BOTH_SAME], [VIEW_TIP]),
    ("2. view: pembagi dua ujung dihapus",
     [(VIEW, VIEW_TIP_HALF, VIEW_TIP_HALF.replace(" * 0.5 *", " * "))],
     [VIEW_TIP, BOTH_SAME], [VIEW_ROOT]),
    ("3. view: kedua pembagi dihapus (cacat penuh)",
     [(VIEW, VIEW_ROOT_HALF, VIEW_ROOT_HALF.replace(" * 0.5 *", " * ")),
      (VIEW, VIEW_TIP_HALF, VIEW_TIP_HALF.replace(" * 0.5 *", " * "))],
     # Gerbang tetangga dijalankan di keadaan yang sama dan wajib tetap
     # hijau — itulah bukti bahwa 22 pemeriksaan lama memang buta di sini.
     [VIEW_ROOT, VIEW_TIP, BOTH_SAME], NEIGHBOURS),
    ("4. port: pembagi dua pangkal dihapus",
     [(RENDER, PORT_ROOT_HALF, PORT_ROOT_HALF.replace(" * 0.5 *", " * "))],
     [PORT_ROOT, BOTH_SAME], [VIEW_ROOT, VIEW_TIP]),
    ("5. view: baris `rootHalf` diganti nama (kontrol negatif)",
     [(VIEW, "        let rootHalf = coreRadius *",
       "        let rootHalfWidth = coreRadius *")],
     # Baris yang tidak lagi terbaca harus **merah**: gerbang yang kehilangan
     # subjeknya tidak boleh diam.
     [VIEW_ROOT, BOTH_SAME], [VIEW_TIP]),
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
                          capture_output=True, text=True, cwd=ROOT,
                          env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
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
            (VIEW, VIEW_ROOT_HALF, "baris setengah-lebar pangkal di view"),
            (VIEW, VIEW_TIP_HALF, "baris setengah-lebar ujung di view"),
            (RENDER, PORT_ROOT_HALF, "baris setengah-lebar pangkal di port")):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x "
                  "— harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutations, must_fire, must_stay in STATES:
            for path in _sources:
                mutasi_sumber.write_source(path, _originals[path])
            if mutations is not None:
                # Mutasi dirantai **per berkas**, bukan selalu dari aslinya:
                # suntingan kedua pada berkas yang sama akan **menimpa** yang
                # pertama kalau setiap putaran kembali ke `_originals`, dan
                # yang diuji lalu bukan keadaan yang dilaporkan.
                pending = {path: _originals[path] for path in _sources}
                for path, old, new in mutations:
                    content = pending[path].replace(old, new, 1)
                    if content == pending[path]:
                        print(f"{label:48s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                        unexpected += 1
                        continue
                    pending[path] = content
                for path, content in pending.items():
                    if content != _originals[path]:
                        mutasi_sumber.write_source(path, content)

            failed, lines = probe()
            if failed is None:
                print(f"{label:48s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            names = " | ".join(line.split("  ")[0][6:].strip() for line in failed)
            # Yang dituntut bukan «ada yang merah», melainkan **yang mana**.
            # Arah kedua: pemeriksaan yang **tidak** disebut di sini wajib
            # tetap hijau. Tanpa itu, satu keadaan yang menyalakan seluruh
            # pemeriksaan akan terlihat "sesuai harapan", padahal artinya
            # gerbangnya tidak memisahkan apa pun — ia cuma berisik.
            missing = [want for want in must_fire
                       if not any(want in line for line in failed)]
            spurious = [line for line in failed
                        if not any(want in line for want in must_fire)]
            # Arah ketiga: pemeriksaan yang **wajib tetap hijau**. Ini yang
            # menahan klaim tentang gerbang lain ("gerbang lama buta pada
            # pembagi duanya"). Tanpa kolom ini, klaim seperti itu hanya hidup
            # di docstring dan akan basi tanpa suara.
            stayed = [want for want in must_stay
                      if any(want in line for line in failed)]
            ok = not missing and not spurious and not stayed
            if not ok:
                unexpected += 1
            detail = f"{len(failed)} merah" if failed else "0 merah"
            print(f"{'OK  ' if ok else 'SALAH'} {label:48s} {detail}")
            if names:
                print(f"       {names}")
            for want in missing:
                print(f"       HARUSNYA MERAH, TIDAK: {want}")
            for want in stayed:
                print(f"       HARUSNYA TETAP HIJAU, TIDAK: {want}")
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
