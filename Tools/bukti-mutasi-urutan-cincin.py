#!/usr/bin/env python3
"""Buktikan gerbang urutan cincin Saturnus **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah.

Kelas cacat yang ditutupnya: `_draw_rings` (port) dan `drawRings` (view)
harus menggambar paruh **belakang** cincin, lalu **bola**, lalu paruh
**depan**. Urutan itulah yang membuat cincin terbaca melingkupi planet:
paruh belakang yang jatuh di belahan atas terhalang bola di bagian tengahnya
dan hanya menonjol di kiri-kanan. Kalau urutannya dibalik, paruh belakang
menimpa bola dan cincinnya terbaca mengambang di muka planet.

Kenapa tidak ada gerbang lain yang menangkapnya — dan **ini yang membuat
harness ini wajib**. Dua pemeriksaan cincin yang sudah ada menyampel hanya
**di luar** bola (`saturn_ring_band_values` membuang `abs(xr) <= body + 0.02`),
jadi keduanya buta pada urutannya. Yang paling dekat,
`check_saturn_has_no_extra_disc`, mengukur "tidak ada yang menyala **di luar**
cincin dan bola" — ia menutup bentuk yang **menonjol keluar**, sedangkan
cacat ini **menutupi ke dalam**. Diukur, bukan diklaim: keadaan 1 menjalankan
seluruh pemeriksaan Saturnus lain dan menuntut keenamnya tetap hijau.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                      gerbang hijau (kalau tidak, harness salah)

  1. port: paruh belakang          `_draw_rings` port diubah menggambar paruh
     digambar paling akhir         depan dulu, bola, lalu paruh belakang di
                                   atasnya. Ini cacatnya persis. Gerbang baru
                                   merah di kedua ukuran (1 533 piksel di
                                   dalam bola @200px, 232 @76px), dan enam
                                   pemeriksaan Saturnus lain wajib tetap
                                   hijau — itulah klaim "gerbang lain buta".

  2. port: paruh belakang          `RING_BACK_HALF_OPACITY_SCALE` -> 0. Paruh
     dimatikan sama sekali         belakang tidak digambar, jadi **nol** piksel
                                   di dalam bola — arah pertama gerbang
                                   terpenuhi dengan sempurna. Arah keduanya
                                   (ada piksel di **luar** bola) yang menahan
                                   keadaan ini. Tanpa pasangan itu, cara
                                   termurah memenuhi "nol di dalam" adalah
                                   berhenti menggambar paruh belakang, dan
                                   gerbangnya akan hijau selamanya.

  3. view: paruh belakang          panggilan `back.fill(ringPath(...)` di view
     dipindah ke bawah bola        dipindah ke bawah `drawSphere`. Piksel port
                                   **tidak berubah** (gerbang gambar mengukur
                                   port), jadi hanya pemeriksaan urutan teks
                                   yang bisa melihatnya — dan itu memang
                                   gunanya keadaan ini: membuktikan sisi view
                                   diperiksa, bukan cuma diklaim.

  4. view: `drawRings` dihapus     kontrol negatif. Gerbangnya harus merah
                                   karena tidak menemukan fungsinya, **bukan**
                                   hijau tanpa mengukur apa pun. Gerbang yang
                                   kehilangan subjeknya harus berbunyi.

**Keadaan 2 dan 3 adalah dua sisi yang tidak bisa saling menggantikan.**
Keadaan 2 menguji arah "masih digambar"; keadaan 3 menguji bahasa kedua.
Kalau salah satunya dilewat, gerbangnya bisa dibalik tanpa berbunyi: matikan
paruh belakang (2), atau rusakkan sisi view (3).
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
# Gerbang baru: dua hasil (panel 200 px + ukuran kartu jam).
C.check_saturn_ring_passes_behind_the_globe(results, 200, 2)
# Sisi view: urutan teks di dalam `drawRings`.
C.check_saturn_ring_order_in_the_view(results)
# **Enam pemeriksaan Saturnus tetangga**, dijalankan di keadaan yang sama:
# inilah bukti hidup untuk klaim "gerbang lain buta pada urutannya".
C.check_saturn_ring_bands_render(results, 200, 2)
C.check_saturn_gap_reads_at_the_watch_size(results)
C.check_saturn_has_no_extra_disc(results, 200, 2)
C.check_planet_features_present(results, 200, 2)
C.check_features_survive_the_watch_size(results)
C.check_features_disappear_when_uncertain(results, 200, 2)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Jangkar di port. `str.replace` atas jangkar yang muncul dua kali akan
#: mengubah keduanya, dan harness lalu melaporkan keadaan yang tidak pernah
#: ia uji — jadi jumlah kemunculannya diperiksa eksplisit di `main()`.
#:
#: **Blok urutan, bukan dua jangkar terpisah.** Versi pertama menempelkan
#: panggilan bola langsung ke loop paruh belakang, dan jangkarnya **tidak
#: ditemukan** — sumbernya punya satu baris kosong di antara keduanya.
#: Keadaan 1 lalu melaporkan "0 merah" dan harness menandainya SALAH, yaitu
#: persis yang seharusnya terjadi: mutasi yang tidak jalan bukan keadaan yang
#: terbukti. Diukur, bukan dikira: `sed -n '1452,1466p'`.
PORT_BACK_LOOP = ('    for inner_r, outer_r, opacity in bands:\n'
                  '        annulus(outer_r * full_width, inner_r * full_width,\n'
                  '                accent_fn(ring_color, night_mode,\n'
                  '                          opacity * RING_BACK_HALF_OPACITY_SCALE), "back")\n')

PORT_SPHERE_CALL = ('    _draw_sphere(canvas, cx, cy, body_radius * radius,\n'
                    '                 palette["light"], palette["dark"], night_mode)\n')

#: Urutan produksi di port: paruh belakang, **baris kosong**, bola.
PORT_ORDER_BLOCK = PORT_BACK_LOOP + "\n" + PORT_SPHERE_CALL

#: Urutan terbalik: bola dulu, lalu paruh belakang di atasnya.
PORT_ORDER_FLIPPED = PORT_SPHERE_CALL + "\n" + PORT_BACK_LOOP

#: Jangkar di view. Dua blok utuh, supaya pemindahannya tidak bergantung pada
#: komentar di sekitarnya.
VIEW_BACK_LOOP = """        var back = context
        back.clip(to: Path(CGRect(x: 0, y: 0,
                                  width: center.x * 2, height: center.y)))
        for band in bands {
            back.fill(ringPath(CGFloat(band.outerRadius) * fullWidth,
                               CGFloat(band.innerRadius) * fullWidth),
                      with: .color(ringColor.opacity(
                        band.opacity * VisualFrame.ringBackHalfOpacityScale)),
                      style: FillStyle(eoFill: true))
        }
"""

#: **Panggilan bola di view, bukan komentar di atasnya.** Versi pertama
#: menyisipkan blok paruh belakang sesudah baris komentar
#: (`// Bola Saturnus, di antara paruh belakang dan paruh depan.`) — dan
#: komentar itu duduk **sebelum** `drawSphere`, jadi bloknya tetap di atas
#: bola dan pemeriksaannya hijau. Keadaan 3 melaporkan "0 merah" dan
#: harness menandainya SALAH. Yang benar adalah menyisipkan sesudah
#: panggilannya sendiri.
VIEW_SPHERE_CALL = """        drawSphere(context: context, center: center, radius: CGFloat(bodyRadius) * radius,
                   from: palette.light, to: palette.dark)
"""

#: Nama pemeriksaan yang dikutip di `must_fire`. Ditulis sebagai potongan
#: unik, bukan kalimat penuh: kalimatnya memuat angka yang berubah bersama
#: ambangnya, dan harness yang ikut berubah bersama gerbangnya tidak menjaga
#: apa pun.
RING_ORDER = "cincin lewat di belakang bola"
RING_ORDER_VIEW = "urutan cincin di view"
RING_ORDER_TOKEN = "ukuran jam terbaca dari token (urutan cincin)"

#: Tetangga yang **wajib tetap hijau** saat urutannya dibalik. Inilah klaim
#: "gerbang lain buta pada urutannya", dan ini satu-satunya tempat ia diukur.
NEIGHBOURS = [
    "cincin: celah Cassini",
    "cincin: paruh belakang lebih redup",
    "Saturnus: tidak ada piringan kedua",
]

#: Setiap keadaan: (nama, daftar (berkas, jangkar, pengganti), pemeriksaan
#: yang **wajib** merah, pemeriksaan yang **wajib tetap hijau**).
#:
#: `None` = jalankan apa adanya (baseline) dan wajib **nol** merah.
#:
#: Yang dituntut bukan «ada yang merah», melainkan **yang mana**: gerbang
#: yang berbunyi pada pemeriksaan yang salah mengukur hal lain daripada yang
#: diklaimnya. Karena itu tiap keadaan menyebut pemeriksaan mana yang harus
#: berbunyi, dan `probe()` menuntut yang **tidak** disebut tetap hijau.
#:
#: **Keadaan 1 dan 2 memakai harapan yang berbeda, dan itu hasil pengukuran.**
#: Draf pertama memberi keduanya `must_stay=NEIGHBOURS`, dan keadaan 2
#: **SALAH**: mematikan paruh belakang memang membuat `cincin: celah Cassini
#: paruh belakang` ikut merah, karena celah Cassini hidup di paruh itu juga.
#: Itu temuan yang benar tentang gerbang tetangganya, bukan cacat harness —
#: jadi yang diperbaiki adalah **klaimnya**: buta-urutan hanya berlaku untuk
#: keadaan 1 (mutasi urutan), dan keadaan 2 (paruh belakang hilang) justru
#: memang terlihat oleh gerbang celah, karena itu cacat yang berbeda
#: (cincinnya tidak lengkap, bukan cincinnya salah urutan).
STATES = [
    ("[baseline]", None, [], []),
    ("1. port: paruh belakang digambar paling akhir",
     [(RENDER, PORT_ORDER_BLOCK, PORT_ORDER_FLIPPED)],
     # Hanya gerbang urutan yang boleh berbunyi di sini — dan itu satu-satunya
     # tempat klaim "gerbang tetangga buta pada urutannya" diukur.
     [RING_ORDER], NEIGHBOURS),
    ("2. port: paruh belakang dimatikan sama sekali",
     [(RENDER, "RING_BACK_HALF_OPACITY_SCALE = 0.55",
       "RING_BACK_HALF_OPACITY_SCALE = 0.0")],
     # Arah pertama gerbang terpenuhi dengan sempurna di sini (nol piksel di
     # dalam bola, karena tidak ada yang digambar). Arah keduanya yang
     # menahannya — dan justru itu yang dibuktikan keadaan ini.
     #
     # Gerbang celah Cassini **ikut** merah, dan itu benar: celahnya hidup di
     # paruh belakang, jadi mematikannya menghapus celahnya juga. Itu cacat
     # yang berbeda (cincin tidak lengkap), dan ia menyebut dirinya sendiri.
     [RING_ORDER, "cincin: celah Cassini", "celah cincin terbaca"], []),
    ("3. view: paruh belakang dipindah ke bawah bola",
     [(VIEW, VIEW_BACK_LOOP, ""),
      (VIEW, VIEW_SPHERE_CALL, VIEW_SPHERE_CALL + VIEW_BACK_LOOP)],
     # Piksel port **tidak berubah** (gerbang gambar mengukur port), jadi
     # hanya pemeriksaan urutan teks yang bisa melihatnya.
     [RING_ORDER_VIEW], [RING_ORDER]),
    ("4. view: drawRings dihapus (kontrol negatif)",
     [(VIEW, "    private func drawRings(context: GraphicsContext, center: CGPoint, radius: CGFloat) {",
       "    private func drawRingsGONE(context: GraphicsContext, center: CGPoint, radius: CGFloat) {")],
     # Kontrol negatif: gerbangnya harus merah karena **tidak menemukan
     # fungsinya**, bukan hijau tanpa mengukur apa pun. Gerbang yang
     # kehilangan subjeknya harus berbunyi.
     [RING_ORDER_VIEW], [RING_ORDER]),
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
            (RENDER, PORT_BACK_LOOP, "panggilan paruh belakang di port"),
            (RENDER, PORT_SPHERE_CALL, "panggilan bola di port"),
            (VIEW, VIEW_BACK_LOOP, "blok paruh belakang di view")):
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
            # menahan klaim tentang gerbang lain ("gerbang tetangga buta pada
            # urutannya"). Tanpa kolom ini, klaim seperti itu hanya hidup di
            # docstring dan akan basi tanpa suara.
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
