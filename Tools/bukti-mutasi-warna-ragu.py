#!/usr/bin/env python3
"""Buktikan `check_uncertain_planet_loses_its_identity_colour` **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah. Gerbang ini menjaga satu aturan PRD yang keras:

    saat engine ragu, tidak boleh ada satu pun warna yang menunjuk planet
    tertentu.

Sebelum gerbangnya ada, `drawPlanet` sudah menutup **ciri** planet saat ragu
(`guard isConfirmed` sebelum pita/cincin/kutub) sementara **warna bolanya**
diteruskan apa adanya. Terukur dari piksel: Mars tampil (120, 55, 36) — merah
khas Mars — di sebelah lencana "Ragu", dan jarak antar-kandidat tetap 62…112.
Jadi engine bisa menyatakan identitas yang belum ia kunci, dan tidak satu pun
dari 654 pemeriksaan waktu itu berbunyi. Kelas cacat yang sama sudah ditutup
untuk tiga permukaan lain (Bulan, bintang, benda langit dalam); planet yang
tertinggal, dan gerbang inilah penutupnya.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                          gerbang hijau (kalau tidak, harness
                                      salah, bukan gerbangnya)
  1. port: ragu pakai palet planet    **cacat aslinya**, dikembalikan persis:
                                      `_draw_planet` mengabaikan keyakinan dan
                                      memakai `PLANET_PALETTE[planet]` apa
                                      adanya. Harus menyalakan
                                      "== bola netral" di **kedua** ukuran —
                                      bukan hanya panel 200 px — karena
                                      ukuran kartu jam satu-satunya yang
                                      penting bagi pengguna.
  2. port: semua planet jadi netral   arah sebaliknya, dan justru yang paling
                                      penting: cara termurah memenuhi
                                      "kandidat == netral" adalah **selalu**
                                      menggambar bola netral. Tanpa keadaan
                                      ini, aplikasi yang tidak pernah
                                      membedakan planet mana pun akan lolos.
                                      Yang berbunyi harus "planet terkunci
                                      membawa warnanya kembali", **bukan**
                                      "== bola netral".
  3. view: `drawable` dilepas        sisi **view**-nya. Piksel port tidak
                                      bergerak satu pun (yang diukur gerbang
                                      adalah port), jadi hanya pemeriksaan
                                      teks yang bisa melihatnya — dan itu
                                      memang satu-satunya yang melihatnya.
                                      Keadaan ini ada khusus untuk
                                      membuktikan sisi view diperiksa, bukan
                                      cuma diklaim.
  4. model: token netral digeser      `CelestialVisual.neutralBody` digeser
                                      menjauh dari nilai yang digambar port.
                                      Membuktikan gerbang membandingkan
                                      **piksel yang digambar** dengan token
                                      yang dibaca dari **model** — bukan
                                      dengan salinan angka yang kebetulan
                                      ikut terkunci di dalam gerbangnya.
  5. port: hanya `light` dinetralkan  **batas yang dinyatakan, dan diukur.**
                                      Gerbang ini membaca **piksel paling
                                      terang** piringan, jadi menetralkan
                                      `light` saja sudah cukup memenuhi
                                      "kandidat == netral" walaupun `dark`
                                      masih membawa palet planetnya. Keadaan
                                      ini **wajib hijau**, dan ia ada supaya
                                      batas itu tidak berubah dari "tidak
                                      diketahui" menjadi "diklaim tertutup".
                                      Kalau suatu hari gerbangnya diperkuat,
                                      keadaan ini merah dan batasnya harus
                                      dinyatakan ulang — bukan dihapus.

**Batas yang dinyatakan.** Keadaan 1, 2, dan 5 memutasi **port Python**,
bukan view Swift: yang diukur gerbang ini adalah piksel port, jadi hanya port
yang bisa menggerakkannya. Sisi view dijaga pemeriksaan teks (keadaan 3), dan
harness ini tidak mengklaim lebih dari itu — kalimat yang sama sudah ditulis
di `bukti-mutasi-bola-netral.py` dan `bukti-mutasi-fase-ciri.py` untuk keadaan
yang bentuknya sama.

**Kenapa label ukuran di `must_fire` ditulis harfiah.** "@38pt" berasal dari
`watch_visual_diameter()` dan "@200pt" dari nilai bawaan `detail`. Kalau
keduanya bergeser, harness ini **merah** dengan "HARUSNYA MERAH, TIDAK" —
berisik, dan itu memang yang diinginkan: label yang tidak lagi cocok berarti
gerbangnya tidak lagi memeriksa ukuran yang diklaim harness ini, dan itu harus
dibaca manusia, bukan ditelan.

Berkas sumber produksi (`Tools/render-visuals.py`,
`Apps/Shared/CelestialVisualView.swift`, `Packages/PointingKit/Sources/
PointingKit/CelestialVisual.swift`) **dimutasi dengan sengaja** lalu dipulihkan
di `finally` per keadaan, lewat `mutasi_sumber` (tulis atomik + pemulihan
terverifikasi). Kegagalan di tengah tidak boleh meninggalkan mutasi hidup —
pelajaran yang sudah dibayar di repo ini (`SIGKILL` melewati `finally`, jadi
ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-warna-ragu.py
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
MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")

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
C.check_uncertain_planet_loses_its_identity_colour(results)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Jangkar di port. `str.replace` atas jangkar yang muncul dua kali akan
#: mengubah keduanya, dan harness lalu melaporkan keadaan yang tidak pernah
#: ia uji — jadi jumlah kemunculannya diperiksa eksplisit di `main()`.
#:
#: Keadaan 1: syarat keyakinan dibuang seluruhnya — inilah bentuk kode
#: **sebelum** siklus ini, dan bentuk yang membuat Mars tampil merah di
#: sebelah lencana "Ragu".
PORT_PALETTE = ('    palette = (PLANET_PALETTE[planet]\n'
                '               if (kw.get("is_confirmed") is not False\n'
                '                   or kw.get("bare_sphere"))\n'
                '               else dict(light=NEUTRAL_BODY, '
                'dark=NEUTRAL_SHADOW, feature="none"))')
PORT_PALETTE_RAW = '    palette = PLANET_PALETTE[planet]'

#: Keadaan 2: `is_confirmed` tidak lagi menentukan apa pun — setiap planet,
#: terkunci maupun ragu, digambar sebagai bola netral.
PORT_PALETTE_ALWAYS_NEUTRAL = (
    '    palette = dict(light=NEUTRAL_BODY, dark=NEUTRAL_SHADOW, '
    'feature="none")')

#: Keadaan 5: **hanya `light` jalur ragu** yang dinetralkan; `dark` masih
#: membawa palet planetnya, dan jalur **terkunci tidak disentuh** (kalau
#: ikut disentuh, arah "planet terkunci" akan merah dan keadaan ini berhenti
#: mengukur batas yang dimaksud). Batas yang dinyatakan, dan keadaan yang
#: **wajib hijau**.
PORT_PALETTE_LIGHT_ONLY = (
    '    palette = (PLANET_PALETTE[planet]\n'
    '               if (kw.get("is_confirmed") is not False\n'
    '                   or kw.get("bare_sphere"))\n'
    '               else dict(light=NEUTRAL_BODY, '
    'dark=PLANET_PALETTE[planet]["dark"], feature="none"))')

#: Jangkar di view: satu baris yang membuat view sadar keyakinan.
VIEW_PALETTE = ('        let palette = planet.palette.drawable('
                'isConfirmed: isConfirmed)')
VIEW_PALETTE_RAW = '        let palette = planet.palette'

#: Jangkar di model: token bola netral. Digeser sedikit (bukan diganti palet
#: planet) supaya keadaan ini **hanya** menyalakan arah "kandidat == netral",
#: bukan ikut menyalakan arah "planet terkunci" — Merkurius adalah planet
#: terdekat ke netral (jarak 0.0435 lawan lantai 0.015), dan pergeseran
#: 0.04/0.04/0.04 menjaganya tetap di atas lantai itu.
MODEL_NEUTRAL_BODY = ('    static let neutralBody = RGBComponents('
                      'red: 0.74, green: 0.72, blue: 0.68)')
MODEL_NEUTRAL_BODY_SHIFTED = ('    static let neutralBody = RGBComponents('
                              'red: 0.70, green: 0.68, blue: 0.64)')

#: Nama pemeriksaan yang dikutip di `must_fire`. Ditulis sebagai potongan
#: unik, bukan kalimat penuh: kalimatnya memuat angka yang berubah bersama
#: ambangnya, dan harness yang ikut berubah bersama gerbangnya tidak menjaga
#: apa pun.
NEUTRAL_EQ_WATCH = "kandidat planet == bola netral @38pt"
NEUTRAL_EQ_PANEL = "kandidat planet == bola netral @200pt"
LOCKED_BACK_WATCH = "planet terkunci membawa warnanya kembali @38pt"
LOCKED_BACK_PANEL = "planet terkunci membawa warnanya kembali @200pt"
VIEW_AWARE = "view memakai palet sadar keyakinan"

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
#: Keadaan 1 dan 2 sengaja berlawanan arah, dan **pasangan itulah buktinya**:
#: 1 adalah "kandidat membawa identitas", 2 adalah "tidak ada identitas yang
#: pernah dibawa". Gerbang yang hanya bisa melihat salah satunya akan hijau
#: pada aplikasi yang tidak pernah membedakan planet mana pun.
STATES = [
    ("[baseline]", None, []),
    ("1. port: ragu pakai palet planet (cacat aslinya)",
     [(RENDER, PORT_PALETTE, PORT_PALETTE_RAW)],
     [NEUTRAL_EQ_WATCH, NEUTRAL_EQ_PANEL]),
    ("2. port: semua planet jadi bola netral",
     [(RENDER, PORT_PALETTE, PORT_PALETTE_ALWAYS_NEUTRAL)],
     [LOCKED_BACK_WATCH, LOCKED_BACK_PANEL]),
    ("3. view: `drawable` dilepas",
     [(VIEW, VIEW_PALETTE, VIEW_PALETTE_RAW)],
     [VIEW_AWARE]),
    ("4. model: token netral digeser",
     [(MODEL, MODEL_NEUTRAL_BODY, MODEL_NEUTRAL_BODY_SHIFTED)],
     [NEUTRAL_EQ_WATCH, NEUTRAL_EQ_PANEL]),
    ("5. port: hanya `light` dinetralkan (batas)",
     [(RENDER, PORT_PALETTE, PORT_PALETTE_LIGHT_ONLY)],
     []),
]

_originals = {}
_sources = (RENDER, VIEW, MODEL)


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
            (RENDER, PORT_PALETTE, "palet sadar keyakinan di port"),
            (VIEW, VIEW_PALETTE, "`drawable` di view"),
            (MODEL, MODEL_NEUTRAL_BODY, "token netral di model")):
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
                        print(f"{label:48s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                        unexpected += 1
                        continue
                    # `_originals` tetap memegang aslinya supaya `finally`
                    # memulihkan yang benar walau keadaan ini gagal di tengah;
                    # yang ditulis ke disk adalah salinan yang termutasi.
                    mutasi_sumber.write_source(path, content)

            failed, lines = probe()
            if failed is None:
                print(f"{label:48s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            names = " | ".join(line.split("  ")[0][6:].strip()
                               for line in failed)
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
            print(f"{'OK  ' if ok else 'SALAH'} {label:48s} {detail}")
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
