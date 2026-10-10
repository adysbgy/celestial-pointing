#!/usr/bin/env python3
"""Buktikan `check_saturn_has_no_extra_disc` **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah.

Kelas cacat yang ditutupnya: `drawPlanet` menggambar bola **radius penuh**
(1.0 R) lebih dulu, lalu — pada cabang cincin — `drawRings` menggambar
bolanya **sendiri** pada `saturnBodyRadius` (0.53 R). Yang sampai ke layar
jadi **dua** piringan bersarang: cakram 1.0 R yang bocor ke seluruh frame di
luar bidang cincin, di bawah bola 0.53 R milik cincinnya. Di kartu jam itu
terbaca sebagai "dua bola bersarang", bukan Saturnus.

Kenapa tidak ada gerbang lain yang menangkapnya — dan **ini yang membuat
harness ini wajib**. Gerbang terdekat, "cincin Saturnus lebih lebar dari
bola", hanya menuntut jangkauan `> 0.8 R`. Cakram bocor itu sendiri
menjangkau 1.0 R, jadi ambangnya dilewati. Dibuktikan di sini, bukan
diklaim: keadaan 1 menghapus cincinnya **seluruhnya** sambil
mempertahankan bola radius penuh, dan keadaan itulah satu-satunya yang
membuat gerbang lama tetap hijau (`jangkauan 1.003 R`) sementara gerbang
baru merah di 14 144 dari 14 144 piksel.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                      gerbang hijau (kalau tidak, harness salah)

  1. port: bola penuh kembali      syarat `is_confirmed and feature == rings`
     pada jalur cincin dihapus     di port dibatalkan, jadi bola 1.0 R
                                   digambar **di bawah** cincin 0.53 R.
                                   Ini keadaan pra-perbaikan yang persis:
                                   gerbang gambar merah di kedua ukuran,
                                   sekaligus pemeriksaan teks port — yang
                                   memang harus melihat syaratnya hilang.

  2. port: cincin dihapus,         cincin tidak digambar sama sekali,
     piringan bocor tetap          piringan 1.0 R tetap. Piringan bocornya
                                   **sama** (14 144 piksel), jadi gerbangnya
                                   tidak boleh bergantung pada cincinnya ada
                                   — kalau ia hijau di sini, yang diukurnya
                                   cincin, bukan piringan kedua. Keadaan ini
                                   juga yang mengukur klaim "gerbang lama
                                   buta": `cincin Saturnus lebih lebar dari
                                   bola` wajib tetap **hijau** di sini.
                                   **Dua suntingan wajib**, dan itu bukan
                                   detail: menghapus panggilan cincinnya saja
                                   menyisakan syarat yang utuh, sehingga bola
                                   1.0 R-nya juga tidak digambar dan yang
                                   terukur 0 piksel — gerbangnya hijau, kebalikan
                                   dari klaim ini. Terukur pada kedua bentuk:
                                   0/14144 (cincin saja) lawan 14144/14144
                                   (syarat dibatalkan + cincin dihapus).

  3. port: cincin digeser          cincin digambar, tetapi pusatnya digeser
     dari pusat bola               `+0.6 R` ke kanan. Piringan 1.0 R tetap di
                                   pusat, jadi separuh frame jadi piringan
                                   bocor yang tidak tertutup cincin yang
                                   sudah pindah (terukur 2 372 piksel).
                                   Membuktikan gerbangnya mengukur
                                   **hubungan** cincin–bola, bukan sekadar
                                   "ada sesuatu yang lebar" — dan gerbang
                                   lama, yang cuma melihat jangkauan, tetap
                                   hijau di sini (terukur 1.056 R).

  4. port: cincin dikecilkan       cincin digambar pada `0.55 R`, di bawah
                                   bola 0.53 R + margin. Ini **kontrol
                                   negatif**: tidak ada piringan bocor, jadi
                                   gerbang baru wajib **diam** sementara
                                   gerbang lama merah (jangkauan 0.546 R).
                                   Tanpa keadaan ini, gerbang baru yang
                                   sebenarnya cuma berbunyi pada "ada yang
                                   berubah" akan terlihat sesuai harapan.

  5. view: syarat dibatalkan       syarat `!(isConfirmed && palette.feature
                                   == .rings)` di view dikembalikan ke
                                   `drawSphere` tanpa syarat. Piksel port
                                   **tidak berubah** (gerbang gambar mengukur
                                   port), jadi hanya pemeriksaan teks di
                                   `check_port_matches_swift_constants` yang
                                   bisa melihatnya. Keadaan ini ada khusus
                                   untuk membuktikan sisi view memang
                                   diperiksa, bukan cuma diklaim — tanpa
                                   ini, view bisa kembali menggambar dua
                                   piringan sementara seluruh gerbang
                                   gambar hijau.
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
C.check_saturn_has_no_extra_disc(results, 200, 2)
# Gerbang tetangga, dijalankan di keadaan yang sama: inilah bukti hidup
# untuk klaim "gerbang lama tidak bisa melihat cacat ini".
C.check_planet_features_present(results, 200, 2)
# **Dan sisi teks.** Dua keadaan di `STATES` (1 dan 5) menuntut pemeriksaan
# yang hanya hidup di sini — `check_port_matches_swift_constants` membaca
# sumber view dan port dari disk, bukan dari piksel. Tanpa baris ini, `probe()`
# tidak pernah menjalankannya, jadi `must_fire` yang menyebut nama
# pemeriksaannya **tidak mungkin** terpenuhi: harness melaporkan "HARUSNYA
# MERAH, TIDAK" untuk keadaan yang sebenarnya sudah benar. Terukur sebelum
# perbaikan ini: keadaan 1 dan 5 sama-sama dilaporkan SALAH, dan keadaan 5
# (yang sengaja hanya mengubah view) melaporkan 0 merah sama sekali.
C.check_port_matches_swift_constants(results)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Jangkar di port. `str.replace` atas jangkar yang muncul dua kali akan
#: mengubah keduanya, dan harness lalu melaporkan keadaan yang tidak pernah
#: ia uji — jadi jumlah kemunculannya diperiksa eksplisit di `main()`.
PORT_GUARD = ('    if not (kw.get("is_confirmed") is not False '
              'and palette["feature"] == "rings"):\n'
              '        _draw_sphere(canvas, cx, cy, radius, palette["light"], '
              'palette["dark"], night_mode)\n')
PORT_RING_CALL = ('        _draw_rings(canvas, cx, cy, radius, palette, '
                  'night_mode)\n')

#: Jangkar di view. Syarat yang sama, dalam ejaan Swift-nya.
VIEW_GUARD = ('        if !(isConfirmed && palette.feature == .rings) {\n'
              '            drawSphere(context: context, center: center, '
              'radius: radius,\n'
              '                       from: palette.light, to: palette.dark)\n'
              '        }\n')

#: Nama pemeriksaan yang dikutip di `must_fire`. Ditulis sebagai potongan
#: unik, bukan kalimat penuh: kalimatnya memuat angka yang berubah bersama
#: ambangnya, dan harness yang ikut berubah bersama gerbangnya tidak menjaga
#: apa pun.
NO_EXTRA_DISC = "tidak ada piringan kedua"
OLD_RING_GATE = "cincin Saturnus lebih lebar dari bola"
VIEW_GUARD_ANCHOR = "view melewatkan bola penuh"
PORT_GUARD_ANCHOR = "port melewatkan bola penuh"

#: Setiap keadaan: (nama, daftar (berkas, jangkar, pengganti), pemeriksaan
#: yang **wajib** merah, pemeriksaan yang **wajib tetap hijau**).
#:
#: `None` = jalankan apa adanya (baseline) dan wajib **nol** merah.
#:
#: Yang dituntut bukan «ada yang merah», melainkan **yang mana**. Gerbang
#: yang berbunyi pada pemeriksaan yang salah mengukur hal lain daripada yang
#: diklaimnya — kelas cacat yang sudah berulang di repo ini. Karena itu tiap
#: keadaan menyebut pemeriksaan mana yang harus berbunyi, dan `probe()`
#: menuntut yang **tidak** disebut tetap hijau.
#:
#: Kolom keempat ada karena keadaan 2 dan 4 mengklaim sesuatu tentang gerbang
#: **lain**, bukan tentang gerbang ini: "gerbang lama tidak bisa melihat cacat
#: ini" (2) dan "gerbang baru tidak ikut menyala saat cincinnya cuma
#: mengecil" (4). Tanpa kolom ini, klaim itu hanya tinggal di docstring —
#: dan klaim yang tidak diukur adalah klaim yang akan basi tanpa suara.
#:
#: **Keadaan 1 dan 2 memakai harapan yang sama tetapi mutasi yang berbeda**,
#: dan pasangan itulah buktinya: keadaan 1 adalah cacatnya apa adanya
#: (bola radius penuh + cincin tergambar), keadaan 2 mempertahankan piringan
#: bocornya tetapi **menghapus cincinnya**. Kalau gerbangnya sebenarnya
#: mengukur "cincinnya ada", keadaan 2 akan hijau dan harness ini merah.
#: Bersama-sama keduanya membuktikan yang diukur memang **piringan kedua**.
STATES = [
    ("[baseline]", None, [], []),
    ("1. port: bola penuh kembali di jalur cincin",
     [(RENDER, PORT_GUARD,
       '    _draw_sphere(canvas, cx, cy, radius, palette["light"], '
       'palette["dark"], night_mode)\n')],
     [NO_EXTRA_DISC, PORT_GUARD_ANCHOR], []),
    ("2. port: cincin dihapus, piringan bocor tetap",
     # **Dua suntingan, dan keduanya wajib.** Menghapus panggilan cincinnya
     # saja tidak cukup: syarat `is_confirmed and feature == "rings"` masih
     # utuh, jadi bola 1.0 R-nya **juga** tidak digambar dan yang terukur
     # 0 piksel bocor — gerbangnya justru hijau, kebalikan dari yang
     # diklaim di sini. Terukur (probe siklus ini): cincin-dihapus-saja →
     # 0/14144, gerbang lama MERAH (0.000 R); syarat-dibatalkan **dan**
     # cincin-dihapus → 14144/14144, gerbang lama HIJAU (1.003 R).
     [(RENDER, PORT_GUARD,
       '    _draw_sphere(canvas, cx, cy, radius, palette["light"], '
       'palette["dark"], night_mode)\n'),
      (RENDER, PORT_RING_CALL, '        pass  # CINCIN DIHAPUS\n')],
     # Kedua pemeriksaan teks port ikut berbunyi, dan memang harus: satu-satunya
     # cara mempertahankan piringan 1.0 R sementara cincinnya dihapus adalah
     # membatalkan syaratnya, dan syarat itulah yang dijaga keduanya.
     [NO_EXTRA_DISC, PORT_GUARD_ANCHOR],
     # Inilah klaim "gerbang lama buta" — dan satu-satunya tempat ia diukur.
     [OLD_RING_GATE]),
    ("3. port: cincin digeser dari pusat bola",
     [(RENDER, PORT_RING_CALL,
       '        _draw_rings(canvas, cx + radius * 0.6, cy, radius, palette, '
       'night_mode)\n')],
     [NO_EXTRA_DISC], [OLD_RING_GATE]),
    ("4. port: cincin dikecilkan sampai di bawah bola",
     [(RENDER, PORT_RING_CALL,
       '        _draw_rings(canvas, cx, cy, radius * 0.55, palette, '
       'night_mode)\n')],
     # Kontrol negatif: cincin 0.55 R **tidak** menyisakan piringan bocor
     # (bola 0.53 R), jadi gerbang baru wajib diam. Kalau ia menyala di sini,
     # yang diukurnya "ada yang berubah", bukan kebocorannya.
     [OLD_RING_GATE], [NO_EXTRA_DISC]),
    ("5. view: syarat jalur cincin dibatalkan",
     [(VIEW, VIEW_GUARD,
       '        if true {\n'
       '            drawSphere(context: context, center: center, '
       'radius: radius,\n'
       '                       from: palette.light, to: palette.dark)\n'
       '        }\n')],
     # Piksel port **tidak berubah** (gerbang gambar mengukur port), jadi
     # hanya pemeriksaan teks yang bisa melihatnya — dan itu memang gunanya
     # keadaan ini: membuktikan sisi view diperiksa, bukan cuma diklaim.
     [VIEW_GUARD_ANCHOR], [NO_EXTRA_DISC, PORT_GUARD_ANCHOR]),
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
            (RENDER, PORT_GUARD, "syarat jalur cincin di port"),
            (RENDER, PORT_RING_CALL, "pemanggilan cincin di port"),
            (VIEW, VIEW_GUARD, "syarat jalur cincin di view")):
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
                # Mutasi dirantai **per berkas**, bukan selalu dari aslinya.
                #
                # Versi sebelumnya menulis `content = _originals[path]` di
                # setiap putaran, jadi suntingan kedua pada berkas yang sama
                # **menimpa** yang pertama dan yang diuji bukan keadaan yang
                # dilaporkan. Terukur pada keadaan 2 di bawah: suntingan
                # penghapus-cincinnya saja menghasilkan 0 piksel bocor
                # (bukan 14 144), dan gerbangnya justru **hijau** — persis
                # kebalikan dari yang diklaim docstring-nya. Kesalahan yang
                # sama pernah dibuat di luar repo ini; rantai eksplisit di
                # sini yang menutupnya.
                pending = {path: _originals[path] for path in _sources}
                for path, old, new in mutations:
                    content = pending[path].replace(old, new, 1)
                    if content == pending[path]:
                        print(f"{label:44s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                        unexpected += 1
                        continue
                    # `_originals` tetap memegang aslinya supaya `finally`
                    # memulihkan yang benar walau keadaan ini gagal di tengah;
                    # yang ditulis ke disk adalah salinan yang termutasi.
                    pending[path] = content
                for path, content in pending.items():
                    if content != _originals[path]:
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
            # Arah ketiga: pemeriksaan yang **wajib tetap hijau**. Ini yang
            # menahan klaim tentang gerbang lain ("gerbang lama buta pada
            # cacat ini", "gerbang baru diam pada kontrol negatif"). Tanpa
            # kolom ini, klaim seperti itu hanya hidup di docstring dan akan
            # basi tanpa suara.
            stayed = [want for want in must_stay
                      if any(want in line for line in failed)]
            ok = not missing and not spurious and not stayed
            if not ok:
                unexpected += 1
            detail = f"{len(failed)} merah" if failed else "0 merah"
            print(f"{'OK  ' if ok else 'SALAH'} {label:44s} {detail}")
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
