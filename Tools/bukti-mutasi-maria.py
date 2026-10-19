#!/usr/bin/env python3
"""Buktikan gerbang "maria Bulan tidak bocor ke belahan gelap" **berbunyi**.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah.

Kelas cacat yang ditutupnya. Bercak gelap Bulan (maria) digambar **di dalam**
pita yang menyala di kedua bahasa (`lambda x, y: maria(x, y) if
_point_in_polygon(...)` di port, `inner.clip(to: lit)` di
`CelestialVisualView.drawLitBand`). Sampai gerbang ini ada, **tidak satu pun**
dari 672 pemeriksaan mengukur akibat potongan itu: melepas klip maria membuat
bercak itu muncul di belahan yang **tidak** disinari — terukur **5516 piksel
pada panel 200 px** dan **236 piksel di ukuran kartu jam (38 px)** untuk
`moon-crescent-jakarta` — dan seluruh `check-visuals.py --check` tetap
melaporkan **672 pemeriksaan, 0 gagal**.

Kenapa gerbang planet berfase yang sudah ada **tidak** bisa dipakai ulang.
`check_phase_feature_stays_inside_the_lit_band` mengukur piksel **menyala** di
belahan gelap, dan ambang "menyala" itu diukur terhadap latar sudut frame.
Piringan gelap Bulan (`moonUnlit` = 0.13) **lebih terang** dari latar
(0.058) — jadi kalau Bulan dimasukkan ke daftar kasusnya, gerbang itu
melaporkan **14714 piksel menyala di belahan gelap pada berkas yang BERSIH**:
seluruh piringan gelapnya, bukan maria. Terukur, dan itu sebabnya
`PHASE_FEATURE_CASES` berisi Merkurius & Venus saja. Kelas "bercak **gelap**
yang bocor ke sisi gelap" karena itu butuh ukuran yang berbeda: bukan "piksel
menyala", melainkan **selisih terhadap gambar tanpa ciri itu**.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                       kedua gerbang hijau (kalau tidak, harness
                                   ini salah, bukan gerbangnya)
  1. port: klip maria dilepas      `_point_in_polygon` dilepas dari penggambar
                                   maria di port — **keduanya**, di dalam `at`
                                   dan pada `canvas.fill` (potongannya
                                   redundan; lihat `PORT_MARIA_CLIP`). Harus
                                   menyalakan gerbang kebocoran pada **kedua
                                   ukuran** — bukan hanya 200 px — karena
                                   ukuran kartu jam adalah satu-satunya ukuran
                                   yang penting bagi pengguna, dan cacat yang
                                   tidak terlihat di satu ukuran bisa dominan
                                   di ukuran lain.
  2. port: maria tidak digambar     gelung penggambarnya berhenti
                                   beriterasi (`for dx, dy, size in []:`) —
                                   lariknya **tidak** disentuh. Ini keadaan
                                   **arah sebaliknya**, dan justru yang
                                   paling penting: tanpa gerbang
                                   pasangannya, cara termurah memenuhi "nol
                                   piksel di belahan gelap" adalah berhenti
                                   menggambar cirinya sama sekali. Yang
                                   berbunyi di sini harus "masih tergambar di
                                   sisi menyala", **bukan** "tidak bocor" —
                                   kalau keduanya berbunyi, gerbangnya tidak
                                   memisahkan "dipotong" dari "dihapus", dan
                                   itu dua perbaikan yang berlawanan arah.
                                   Lariknya sengaja dibiarkan utuh: versi
                                   pertama mengosongkan `MARIA` dan itu
                                   menyalakan gerbang paritas referensi juga
                                   (mengubah **data**, bukan gambar) — dua
                                   gerbang berbunyi untuk satu kelas.
  4. port: peredupan digambar       penjaga `is_confirmed` di `_draw_moon`
     walau engine ragu             dilepas; yang wajib berbunyi hanya
                                   "hilang saat ragu".
  5. port: peredupan tidak          kedua gelung peredupan berhenti
     digambar sama sekali          beriterasi. Arah sebaliknya dari 2, dan
                                   yang wajib berbunyi "tampil saat yakin" di
                                   **kedua** ukuran (38 & 200 px) **dan**
                                   "masih tergambar di belahan menyala"
                                   **penuh** (terukur 4 dari 4). "Hilang
                                   saat ragu" **tidak** ikut berbunyi, dan
                                   itu bukan celah — lihat
                                   `SHOWN_AT_BOTH_SIZES`.

**Batas yang dinyatakan.** Keadaan 1–2 memutasi **port Python**, bukan view
Swift: yang diukur kedua gerbang itu adalah piksel port, jadi hanya port yang
bisa menggerakkannya. Sisi view (`.clip(to: lit)` di
`CelestialVisualView.drawLitBand`) dijaga pemeriksaan teks lain, dan harness
ini tidak mengklaim lebih dari itu — kalimat yang sama sudah ditulis di
`bukti-mutasi-fase-ciri.py` untuk keadaan yang sama bentuknya.

**Cacat yang ditemukan harness ini pada dirinya sendiri, terukur.** Versi
pertama `check_moon_feature_stays_inside_the_lit_band` menuntut **setiap** kasus
Bulan berfase, dan keadaan 1 membuktikan itu menuntut kebohongan: empat
pemeriksaan tetap hijau pada port yang klipnya **sungguh dilepas** —
`moon-waning-gibbous` di kedua ukuran dan `moon-full` di kedua ukuran.

Sebabnya geometri, bukan ambang, dan terukur sebagai *piksel maria yang
berada di belahan gelap sebelum dipotong* (200 px / 38 px):

    moon-waning-gibbous (f = .72, mengecil)        0 /     0
    moon-full           (f = 1.0)                  0 /     0
    moon-gibbous        (f = .72, membesar)    2 806 / 1 579
    moon-crescent-*     (f = .18)            22 836 / 13 189

Maria terletak di belahan kiri piringan (dx −0,34…+0,22). Pada
`moon-waning-gibbous` pita terangnya justru **menutupi** sisi itu, jadi
bercaknya tak punya satu piksel pun di belahan gelap — klip yang dilepas tidak
memindahkan apa pun, karena tak ada tempat untuk bocor. `moon-full` bahkan
tidak punya belahan gelap. Menuntut keduanya merah berarti menuntut gerbang
berbunyi pada gambar yang **benar**; gerbang seperti itu dimatikan orang,
bukan diperbaiki.

Perbaikannya bukan merelaksasi ambangnya, melainkan **menyatakan syarat
mampunya**: daftar kasusnya kini disaring oleh `_moon_dark_overlap() > 0`,
yaitu fase yang belahan gelapnya sungguh menaungi bercaknya. Purnama dan
purnama-sebelah yang mengecil keluar dari kelas ini **dengan alasan yang
diukur**, dan kedua arah tetap terpisah — keadaan 2 masih menyalakan **hanya**
gerbang "masih tergambar".

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, lewat `mutasi_sumber` (tulis atomik +
pemulihan terverifikasi). Kegagalan di tengah tidak boleh meninggalkan mutasi
hidup — pelajaran yang sudah dibayar di repo ini (`SIGKILL` melewati `finally`,
jadi ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-maria.py
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
#: Keadaan 3 memutasi **gerbangnya**, bukan port: `MARIA_REFERENCE` hidup di
#: `check-visuals.py`, jadi hanya berkas itu yang bisa menggerakkannya.
CHECK = os.path.join(ROOT, "Tools", "check-visuals.py")

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
C.check_moon_feature_stays_inside_the_lit_band(results)
C.check_moon_feature_still_reaches_the_lit_side(results)
C.check_moon_maria_reference_matches_the_model(results)
# Gerbang keyakinan peredupan permukaan: maria & kawah menyebut **muka** yang
# mana, jadi ia tunduk pada gerbang yang sama dengan pita Jupiter. Ukuran
# dipilih dari dua ujung: 38 px (kartu jam, satu-satunya ukuran yang penting
# bagi pengguna) dan 200 px (panel iPhone). Gerbang yang hanya mengukur satu
# ukuran akan buta di ukuran lain — kelas cacat yang sudah dibayar di repo ini.
for _size in (38, 200):
    C.check_moon_surface_hides_when_uncertain(results, size=_size, ss=2)
# `TAK: ` / `YA: ` — dipisah supaya kelasnya dihitung di proses ini, atas
# **semua** pemeriksaan (bukan cuma yang merah). Tanpa itu, gerbang yang
# berhenti mengukur (mis. daftar kasusnya kosong) tidak bisa dibedakan dari
# gerbang yang hijau.
for r in results:
    print(("YA: " if r.ok else "TAK: ") + r.name + "  " + r.detail)
"""

#: Jangkar di port. `str.replace` atas jangkar yang muncul dua kali akan
#: mengubah keduanya, dan harness lalu melaporkan keadaan yang tidak pernah
#: ia uji — jadi jumlah kemunculannya diperiksa eksplisit di `main()`.
#:
#: **Jangkar ini mengikuti bentuk kodenya, dan itulah sebabnya ia pernah
#: patah.** Sampai perubahan "bercak maria beriak, bukan lingkaran",
#: penggambar maria di port adalah satu `canvas.disc` dengan `lambda x, y:
#: maria(x, y) if _point_in_polygon(...) else (lit_rgb, 0.0)` di dalam gelung
#: `for dx, dy, size in MARIA:`. Ketiga jangkar di bawah menyebut **bentuk
#: itu**, dan setelah perubahan itu tidak satu pun ada lagi di
#: `render-visuals.py` — terukur: `count` 0 untuk ketiganya, dan harness ini
#: keluar 2 di `main()` sambil melaporkan "jangkar muncul 0x, harus tepat 1x".
#: Keadaan yang berisik itu bagus; yang **tidak** berisik adalah
#: `check_feature_arrays_match_the_view`, yang ditinggalkan WIP yang sama
#: sebagai **docstring tanpa tubuh** dan karena itu diam selamanya. Keduanya
#: lahir dari satu sesi yang terputus — lihat
#: `check_every_gate_fills_its_results`.
#:
#: Bentuknya sekarang: gelung `enumerate(MARIA)` dengan sebuah `at(x, y)`
#: bersarang yang memotong ke `_point_in_polygon` **dua** kali — sekali pada
#: dirinya sendiri, sekali pada `canvas.fill` yang memanggilnya.
#:
#: Keadaan 1: potongan maria dilepas. **Keduanya** harus dilepas, dan itu
#: bukan kerapian — diukur, bukan disimpulkan:
#:
#:     hanya syarat di dalam `at` dilepas      0 merah dari 16
#:     hanya topeng `canvas.fill` dilepas      0 merah dari 16
#:     KEDUANYA dilepas                        16 merah dari 16
#:
#: Karena potongannya **redundan**: selama salah satunya masih ada, bercaknya
#: tetap terbatas pada pita terang, jadi tidak ada yang bocor dan gerbangnya
#: benar untuk tetap hijau. Versi pertama harness ini melepas **satu** saja —
#: jadi ia menjalankan keadaan yang tidak merusak apa pun, lalu melaporkan
#: "gerbangnya buta" atas kerusakan yang tidak pernah ia buat. Pelajarannya
#: umum: keadaan mutasi yang tidak mengubah perilaku akan selalu terbaca
#: sebagai gerbang yang buta, dan tidak ada cara membedakan keduanya kecuali
#: mengukur apa yang sebenarnya berubah.
#:
#: Keadaan 2 **tidak** melepas potongannya: gelung penggambarnya berhenti
#: beriterasi, jadi maria tidak digambar sama sekali. Itu arah yang berlawanan —
#: yang berbunyi di sana adalah kelas "ciri masih sampai ke sisi terang", bukan
#: kelas kebocoran. Dua keadaan itu sengaja tidak saling menggantikan: keadaan 1
#: membuktikan gerbang kebocoran bisa berbunyi, keadaan 2 membuktikan gerbang
#: arah-sebaliknya bisa berbunyi, dan gerbang yang hanya bisa merah di satu arah
#: akan melewatkan cacat di arah yang lain tanpa suara.
PORT_MARIA_CLIP = ('        def at(x, y, mx=mx, my=my, edge=edge, ripple=ripple):\n'
                   '            # Riak tepi + pelunakan tepi. Lihat '
                   '`MARIA_RIPPLE` dan\n'
                   '            # `MARIA_EDGE_SOFTNESS`: lingkaran bertepi '
                   'keras terbaca sebagai\n'
                   '            # polka dot pada ukuran kartu jam, bukan '
                   'dataran gelap.\n'
                   '            if not _point_in_polygon(x, y, points):\n'
                   '                return (lit_rgb, 0.0)\n')
PORT_MARIA_NOCLIP = ('        def at(x, y, mx=mx, my=my, edge=edge, ripple=ripple):\n'
                     '            # Riak tepi + pelunakan tepi. Lihat '
                     '`MARIA_RIPPLE` dan\n'
                     '            # `MARIA_EDGE_SOFTNESS`: lingkaran bertepi '
                     'keras terbaca sebagai\n'
                     '            # polka dot pada ukuran kartu jam, bukan '
                     'dataran gelap.\n')

#: Potongan **kedua**, di pemanggilnya: `canvas.fill(lambda x, y:
#: _point_in_polygon(x, y, points), at)`.
#:
#: Ini yang membuat keadaan 1 harus melepas dua jangkar, bukan satu — dan ia
#: yang paling mudah terlewat, karena `at` sudah memotong dan pembacaannya
#: berhenti di situ. Jangkar ini juga yang mengubah makna keadaan 1: sebelum
#: ia ada, melepas syarat di dalam `at` **memang** membuat bercak bocor;
#: sesudah ia ada, tidak lagi.
PORT_MARIA_OUTER_MASK = (
    '        canvas.fill(lambda x, y: _point_in_polygon(x, y, points), at)')
PORT_MARIA_OUTER_NOMASK = '        canvas.fill(lambda x, y: True, at)'

#: Keadaan 2: maria tidak digambar sama sekali. **Gelungnya** yang
#: dikosongkan, bukan lariknya.
#:
#: Versi pertama mengosongkan `MARIA` (`MARIA = []`) dan itu **salah**,
#: terukur: ia menyalakan dua gerbang, bukan satu. `MARIA` adalah larik hidup
#: yang dibandingkan `check_moon_maria_reference_matches_the_model` dengan
#: `MARIA_REFERENCE` yang dibekukan di gerbang — mengosongkannya mengubah
#: **data**, jadi gerbang paritas itu ikut merah, padahal keadaan ini
#: mengklaim hanya kelas "masih tergambar". Dua gerbang berbunyi bersama
#: berarti gerbangnya tidak memisahkan "tidak digambar" dari "referensi
#: basi".
#:
#: Yang dimutasi sekarang adalah **penggambarnya**: gelungnya berhenti
#: beriterasi sementara lariknya utuh, jadi data tidak tersentuh dan hanya
#: gerbang "masih tergambar" yang berbunyi. Bentuknya kini `enumerate`, jadi
#: yang dikosongkan adalah argumennya — **bukan** `MARIA` itu sendiri.
PORT_MARIA_LOOP = '    for index, (dx, dy, size) in enumerate(MARIA):'
PORT_MARIA_NOLOOP = '    for index, (dx, dy, size) in enumerate([]):'

#: Keadaan 3: larik maria dihidupkan digeser, sementara `MARIA_REFERENCE` yang
#: dibekukan di gerbang tidak ikut.
#:
#: `MARIA_REFERENCE` adalah **salinan**, jadi ia bisa membusuk diam-diam:
#: gerbang kebocoran lalu menyaring kasus memakai susunan bercak yang tidak
#: pernah digambar, dan ia tetap hijau selamanya. Keadaan ini menuntut
#: `check_moon_maria_reference_matches_the_model` berbunyi — dan **hanya** dia,
#: karena menggeser satu bercak tidak memindahkan maria ke belahan gelap.
#:
#: Isinya sekarang **sebelas** bercak (dulu empat): susunannya mengikuti
#: `MARIA` di port, karena gerbang ini membandingkan `MARIA_REFERENCE` dengan
#: larik yang hidup. Menyalin empat bercak lama ke sini membuat jangkarnya
#: tidak pernah cocok, dan `main()` menolak jalan sebelum itu terjadi.
PORT_MARIA_REFERENCE = ('MARIA_REFERENCE = [(-0.72, 0.02, 0.30), '
                        '(-0.46, -0.36, 0.28),\n'
                        '                   (-0.18, -0.44, 0.22), '
                        '(0.06, -0.26, 0.22),\n'
                        '                   (0.36, -0.06, 0.18), '
                        '(0.62, -0.34, 0.13),\n'
                        '                   (0.24, 0.18, 0.15), '
                        '(-0.26, 0.34, 0.24),\n'
                        '                   (-0.56, 0.38, 0.20), '
                        '(-0.34, -0.70, 0.13),\n'
                        '                   (-0.24, -0.16, 0.14)]')
PORT_MARIA_REFERENCE_DRIFT = ('MARIA_REFERENCE = [(-0.72, 0.02, 0.30), '
                              '(-0.46, -0.36, 0.28),\n'
                              '                   (-0.18, -0.44, 0.22), '
                              '(0.06, -0.26, 0.22),\n'
                              '                   (0.36, -0.06, 0.18), '
                              '(0.62, -0.34, 0.13),\n'
                              '                   (0.24, 0.18, 0.15), '
                              '(-0.26, 0.34, 0.24),\n'
                              '                   (-0.56, 0.38, 0.20), '
                              '(-0.34, -0.70, 0.13),\n'
                              '                   (-0.24, -0.16, 0.99)]')

#: **Kelas** pemeriksaan, bukan nama satu per satu.
#:
#: Versi pertama harness ini menyebut nama kasus satu per satu
#: (`... moon-crescent-jakarta ...`) dan itu **salah**: gerbangnya memang
#: berbunyi pada **setiap** kasus Bulan, jadi daftar tiga nama membuat
#: sebelas pemeriksaan yang benar dituduh "merah yang tidak diminta". Daftar
#: nama juga membusuk sendiri: menambah satu kasus Bulan ke `build_cases()`
#: memecahkan harness ini walaupun gerbangnya masih benar.
#:
#: Yang dituntut sekarang adalah **cakupannya**, dan jumlahnya diukur dari
#: gerbang itu sendiri (lihat `baseline_counts`): pada berkas bersih,
#: hitung berapa pemeriksaan yang cocok dengan tiap pola, lalu tuntut
#: keadaan termutasi menyalakan **tepat sebanyak itu** untuk kelas tersebut.
#: Gerbang yang hanya mengukur satu ukuran, atau yang berhenti pada satu
#: kasus, akan ketahuan — dan gerbang yang benar tidak perlu diperbarui tiap
#: kali katalognya tumbuh.
DARK_CLASS = "tidak bocor ke belahan gelap"
LIT_CLASS = "masih tergambar di belahan menyala"
#: Gerbang paritas `MARIA_REFERENCE` — bukan kelas piksel, satu pemeriksaan.
REFERENCE_CLASS = "referensi maria sama dengan model"
#: Gerbang keyakinan peredupan permukaan, dua arah. Kelas "hides" == maria &
#: kawah tidak tampil saat ragu; kelas "shows" == keduanya tetap tampil saat
#: Bulan terkunci. Keduanya dijaga terpisah karena cara termurah memenuhi
#: "hilang saat ragu" adalah berhenti menggambarnya sama sekali — dan gerbang
#: yang hanya punya satu arah tidak bisa membedakan keduanya.
SHADING_HIDDEN_CLASS = "peredupan permukaan Bulan hilang saat ragu"
SHADING_SHOWN_CLASS = "peredupan permukaan Bulan tampil saat yakin"
#: Kelas bantu keadaan 5: "tampil saat yakin" wajib berbunyi di **kedua**
#: ukuran (38 px kartu jam & 200 px panel), bukan salah satunya. Namanya
#: membawa kedua angka, jadi keempat pemeriksaan (2 ukuran x 2 sisi
#: pembanding) ikut terhitung — dan itulah yang dituntut keadaan 5.
SHOWN_AT_BOTH_SIZES = "38 px|200 px"
#: **Kenapa keadaan 5 menuntut kelas yang MENYEBUT ukurannya, bukan "hilang
#: saat ragu".**
#:
#: Bentuk lain keadaan ini — rebind global yang mematikan maria & kawah di
#: **kedua** jalur (`MARIA = []; MOON_CRATERS = []` di kepala `_draw_moon`) —
#: diukur di salinan repo, proses baru, dua ukuran:
#:
#:     "hilang saat ragu"          hijau di 38 & 200  (0 piksel, sah)
#:     "tampil saat yakin"         MERAH di 38 & 200  (0 piksel, seharusnya > 0)
#:     "masih tergambar…menyala"   MERAH 2 dari 6
#:
#: "Hilang saat ragu" memang tidak bisa berbunyi di sana, dan itu benar: ia
#: membandingkan sabit ragu berperedupan lawan sabit ragu tanpa peredupan;
#: kalau peredupan tidak pernah digambar, keduanya identik dan selisihnya nol
#: — nol yang sah, bukan kebocoran. Gerbang yang hanya punya dua jalur tidak
#: bisa berbicara tentang keadaan yang menghapus keduanya, dan menuntutnya
#: merah berarti menuntutnya menebak. Arah itu ditutup keadaan 4.
#:
#: Bentuk yang dipakai sekarang (`enumerate([])` / `zip([], …)`) melemahkan
#: gelung di port sehingga jalur **yakin** kehilangan peredupan; karena itu
#: "tampil saat yakin" dan "masih tergambar" yang wajib berbunyi, di kedua
#: ukuran. Kelas di bawah menyebut **kedua ukuran** itu di namanya: gerbang
#: yang berhenti mengukur satu ukuran tidak bisa lulus lagi.

#: Jangkar gerbang keyakinan peredupan di port.
#:
#: Keadaan 4 melepas **penjaga keyakinan** di `_draw_moon`: maria & kawah lalu
#: digambar walaupun `is_confirmed` False. Itu cacat yang persis dijaga
#: `check_moon_surface_hides_when_uncertain`, jadi hanya kelas "hides" yang
#: boleh berbunyi. Penjaga `surface_shading` **tidak** ikut dilepas: ia
#: pembanding pembaca, bukan keputusan produksi.
#:
#: Keadaan 5 adalah arah sebaliknya: seluruh peredupan permukaan dimatikan
#: (bukan hanya saat ragu). Yang wajib berbunyi kelas "shows", dan kelas
#: "hides" wajib tetap hijau — peredupan yang tidak pernah digambar memang
#: tidak pernah bocor, dan menuntut keduanya merah berarti harness tidak bisa
#: membedakan "disembunyikan" dari "dihapus".
PORT_SHADING_CERTAINTY = ('    if kw.get("is_confirmed") is False:\n'
                          '        return\n'
                          '    maria = solid((0.0, 0.0, 0.0), MARIA_OPACITY)')
PORT_SHADING_NOCERTAINTY = ('    maria = solid((0.0, 0.0, 0.0), MARIA_OPACITY)')
PORT_SHADING_LOOP = '    for index, (dx, dy, size) in enumerate(MARIA):\n        mx, my = to_screen(dx, dy)\n        edge = size * radius\n        ripple = MARIA_RIPPLE[index] if index < len(MARIA_RIPPLE) else (0.0, 0.0)'
PORT_SHADING_NOLOOP = '    for index, (dx, dy, size) in enumerate([]):\n        mx, my = to_screen(dx, dy)\n        edge = size * radius\n        ripple = MARIA_RIPPLE[index] if index < len(MARIA_RIPPLE) else (0.0, 0.0)'

#: **Kawah Bulan juga peredupan permukaan, dan keadaan 5 wajib mematikannya
#: bersama maria.**
#:
#: `check_moon_surface_hides_when_uncertain` berpasangan dengan dirinya
#: sendiri: "hilang saat ragu" lawan "tampil saat yakin". Yang pertama
#: memakai `moon-crescent-uncertain` (penjaga keyakinan mengembalikan lebih
#: awal, jadi maria **dan** kawah tidak digambar). Yang kedua memakai
#: `moon-crescent-jakarta` lawan `-plain`, yang bedanya hanya
#: `surface_shading=False` — **kedua** gelung dilewati di sana.
#:
#: Mengosongkan gelung maria saja karena itu menyisakan kawah tergambar:
#: "tampil saat yakin" lalu membaca 1535 piksel (200 px) dan 74 piksel
#: (38 px) — sisa cekungan kawah — dan tetap **hijau**. Keadaan 5 lalu
#: melaporkan "HARUSNYA MERAH, TIDAK" pada ukuran yang justru paling
#: penting, sementara penyebabnya ada di keadaan ini, bukan di gerbangnya.
#: Terukur sebelum perbaikan: 4 merah, 2 di kelas yang dituntut.
#:
#: Pilihan lain — menurunkan ambang "tampil saat yakin" ke piksel kawah
#: — ditolak: itu akan membuat gerbang itu hijau walau maria dihapus,
#: persis kelas cacat yang ia tulis untuk ditangkap.
PORT_CRATER_LOOP = '    for (dx, dy, size, darkness), relief in zip(MOON_CRATERS, relief_all):'
PORT_CRATER_NOLOOP = '    for (dx, dy, size, darkness), relief in zip([], relief_all):'

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
#: Keadaan 1 menyebut dua ukuran untuk satu kasus: kalau hanya panel 200 px
#: yang disebut, gerbang yang mengukur panel itu saja akan lolos, padahal
#: cacatnya justru paling penting di kartu jam. Keadaan 2 adalah arah
#: sebaliknya: ia harus menyalakan **hanya** gerbang "masih tergambar",
#: bukan gerbang kebocoran.
#: Keadaan 3: hanya gerbang paritas referensi. Susunan bercak yang dibekukan
#: menyimpang dari yang digambar; tanpa keadaan ini, `MARIA_REFERENCE` bisa
#: membusuk diam-diam sementara kedua gerbang piksel tetap hijau.
STATES = [
    ("[baseline]", None, []),
    ("1. port: klip maria dilepas",
     [(RENDER, PORT_MARIA_CLIP, PORT_MARIA_NOCLIP),
      (RENDER, PORT_MARIA_OUTER_MASK, PORT_MARIA_OUTER_NOMASK)],
     [DARK_CLASS]),
    ("2. port: maria tidak digambar sama sekali",
     [(RENDER, PORT_MARIA_LOOP, PORT_MARIA_NOLOOP)],
     [LIT_CLASS]),
    ("3. gerbang: MARIA_REFERENCE menyimpang dari model",
     [(CHECK, PORT_MARIA_REFERENCE, PORT_MARIA_REFERENCE_DRIFT)],
     [REFERENCE_CLASS]),
    # Keadaan 4 & 5: keyakinan peredupan permukaan. Anchor pertama ada di
    # penjaga `_draw_moon` yang **baru**; ia akan hilang bila orang menulis
    # ulang fungsi itu — dan jangkar yang hilang membuat harness keluar 2,
    # bukan hijau diam-diam.
    ("4. port: peredupan digambar walau engine ragu",
     [(RENDER, PORT_SHADING_CERTAINTY, PORT_SHADING_NOCERTAINTY)],
     [SHADING_HIDDEN_CLASS]),
    ("5. port: peredupan tidak digambar sama sekali",
     [(RENDER, PORT_SHADING_LOOP, PORT_SHADING_NOLOOP),
      # Kedua gelung, bukan satu — lihat `PORT_CRATER_LOOP`. Mengosongkan
      # gelung maria saja menyisakan **kawah** tergambar, dan
      # "peredupan tampil saat yakin" lalu membaca 1535 px (200) / 74 px
      # (38) sisa cekungan itu — hijau, padahal keadaan ini mengklaim
      # seluruh peredupan permukaan dimatikan.
      (RENDER, PORT_CRATER_LOOP, PORT_CRATER_NOLOOP)],
     # Tiga hal yang dituntut, dan ketiganya **terukur** pada keadaan ini
     # (bukan dugaan): mematikan kedua gelung peredupan permukaan mengosongkan
     # maria **dan** kawah dari kedua jalur, sehingga
     #   1. "tampil saat yakin" berbunyi di **kedua** ukuran (38 & 200 px) —
     #      itu yang ditegakkan `SHOWN_AT_BOTH_SIZES`;
     #   2. "masih tergambar di belahan menyala" berbunyi **penuh** (4 dari 4),
     #      karena tidak ada satu pun maria/kawah yang lagi tercetak di sisi
     #      terang — bukan hanya sebagian kasus. Versi lama harness mengira
     #      hanya "2 dari 6" dan karena itu **tidak** menuntut kelas ini,
     #      sehingga keadaannya yang benar dilaporkan "MERAH YANG TIDAK
     #      DIMINTA" tepat di run CI. Angka 4 dari 4 di sini adalah hasil
     #      pengukuran di atas, bukan tebakan.
     #   3. "hilang saat ragu" **tidak** ikut berbunyi — peredupan yang tidak
     #      pernah digambar memang tidak pernah bocor; arah itu ditutup
     #      keadaan 4.
     [SHADING_SHOWN_CLASS, SHOWN_AT_BOTH_SIZES, LIT_CLASS]),
]

_originals = {}
#: Keadaan 3 memutasi berkas gerbang, jadi ia ikut dipulihkan.
_sources = (RENDER, CHECK)


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
            (RENDER, PORT_MARIA_CLIP, "penggambar maria berklip di port"),
            (RENDER, PORT_MARIA_OUTER_MASK, "topeng poligon pada `canvas.fill`"),
            (RENDER, PORT_MARIA_LOOP, "gelung penggambar maria di port"),
            (RENDER, PORT_SHADING_CERTAINTY, "penjaga keyakinan peredupan permukaan"),
            (RENDER, PORT_SHADING_LOOP, "gelung peredupan permukaan di port"),
            (RENDER, PORT_CRATER_LOOP, "gelung kawah Bulan di port"),
            (CHECK, PORT_MARIA_REFERENCE, "`MARIA_REFERENCE` di gerbang")):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x "
                  "— harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    def run_state(mutations):
        """Pasang mutasi (kalau ada), jalankan probe, pulihkan.

        Suntingan **ditumpuk di atas isi yang sudah dimutasi**, bukan selalu
        diambil dari `_originals`. Versi pertama menulis ulang dari
        `_originals` untuk setiap jangkar, jadi dua suntingan pada berkas yang
        sama saling membatalkan — suntingan kedua menimpa yang pertama — dan
        keadaan yang seharusnya melepas **dua** potongan hanya melepas satu.
        Cacat itu diam: `content != _originals[path]` tetap benar, jadi tidak
        ada yang dilaporkan, dan keadaannya hanya tidak merusak apa pun.

        Penuntutan "jangkar berubah" tetap ada, dan itu bukan hiasan: jangkar
        yang tidak mengubah apa-apa berarti keadaannya tidak menguji apa pun.
        """
        for path in _sources:
            mutasi_sumber.write_source(path, _originals[path])
        if mutations is not None:
            edited = {path: _originals[path] for path in _sources}
            for path, old, new in mutations:
                if edited[path].count(old) != 1:
                    return None, [f"ANCHOR muncul "
                                  f"{edited[path].count(old)}x, butuh 1: {old!r}"]
                before = edited[path]
                edited[path] = edited[path].replace(old, new, 1)
                if edited[path] == before:
                    return None, [f"ANCHOR TIDAK MENGUBAH APA PUN: {old!r}"]
            for path, content in edited.items():
                if content != _originals[path]:
                    mutasi_sumber.write_source(path, content)
        return probe()

    unexpected = 0
    try:
        # Baseline dulu: dari situ **diukur** berapa banyak pemeriksaan yang
        # ada di tiap kelas. Menulis jumlahnya sebagai konstanta akan membuat
        # harness ini pecah setiap kali katalog Bulan tumbuh, dan — lebih
        # buruk — tetap hijau kalau gerbangnya sendiri menyusut.
        checks, error = run_state(None)
        if checks is None:
            print(f"[baseline] PROBE GAGAL JALAN: {error[-1]}")
            sys.exit(1)
        baseline_red = [name for ok, name in checks if not ok]
        if baseline_red:
            print("[baseline] GERBANG SUDAH MERAH pada berkas bersih "
                  "— perbaiki gerbangnya dulu, bukan harness ini:")
            for name in baseline_red:
                print(f"       {name}")
            sys.exit(1)
        counts = {cls: sum(1 for _, name in checks if cls in name)
                  for cls in (DARK_CLASS, LIT_CLASS, REFERENCE_CLASS,
                              SHADING_HIDDEN_CLASS, SHADING_SHOWN_CLASS)}
        # `SHOWN_AT_BOTH_SIZES` **bukan** kelas substring dan sengaja tidak
        # masuk hitungan ini. Nilainya `"38 px|200 px"` — pola alternatif yang
        # tidak pernah muncul sebagai isi nama pemeriksaan, jadi
        # `SHOWN_AT_BOTH_SIZES in must_fire` hanya dibaca sebagai **penanda**
        # oleh blok "kedua ukuran" di bawah, bukan lewat pencocokan `in`.
        # Kalau ikut dihitung di sini, ia selalu nol dan kelas beranggota nol
        # akan menggagalkan fail-closed tanpa alasan.
        #
        # Jumlah "tampil saat yakin" tetap dijaga lewat
        # `SHADING_SHOWN_CLASS`, yang namanya kini **menyebut ukuran**
        # ("...tampil saat yakin (38 px)") — itu yang membuat keadaan 5 bisa
        # menuntut "kedua ukuran" tanpa menebak, karena setiap ukuran punya
        # barisnya sendiri di baseline.

        for cls, n in counts.items():
            if n == 0:
                print(f"GERBANG: kelas «{cls}» tidak punya satu pun "
                      "pemeriksaan di berkas bersih — harness ini tidak "
                      "mengukur apa pun.", file=sys.stderr)
                sys.exit(2)
        print(f"[baseline] {len(checks)} pemeriksaan, 0 merah "
              f"(kelas kebocoran {counts[DARK_CLASS]}, "
              f"kelas tergambar {counts[LIT_CLASS]})")

        for label, mutations, must_fire in STATES[1:]:
            checks, error = run_state(mutations)
            if checks is None:
                print(f"{label:44s} PROBE GAGAL JALAN: {error[-1]}")
                unexpected += 1
                continue

            fired = [name for ok, name in checks if not ok]
            # Yang dituntut bukan «ada yang merah», melainkan **yang mana**,
            # dan **selengkap apa**. Kelas yang wajib berbunyi harus berbunyi
            # pada **semua** anggotanya — bukan satu-dua yang kebetulan
            # disebut: gerbang yang hanya mengukur satu ukuran atau berhenti
            # pada satu kasus harus ketahuan. Dan pemeriksaan di luar kelas
            # itu wajib tetap hijau; tanpa itu, keadaan yang menyalakan
            # seluruh pemeriksaan akan terlihat "sesuai harapan", padahal
            # artinya gerbangnya tidak memisahkan apa pun — ia cuma berisik.
            expected = [name for _, name in checks
                        if any(cls in name for cls in must_fire)]
            missing = [name for name in expected if name not in fired]
            spurious = [name for name in fired
                        if not any(cls in name for cls in must_fire)]
            # Kalau jumlah anggota **tiap kelas** berbeda dari baseline,
            # katalognya bergerak di tengah harness — itu sendiri layak merah.
            #
            # Perbandingannya **per kelas**, bukan satu angka untuk seluruh
            # `must_fire`. Versi pertama membandingkan `len(expected)` dengan
            # `counts[cls]` untuk tiap kelas, padahal `expected` adalah
            # gabungan semua kelas yang dituntut — jadi pada keadaan yang
            # menuntut dua kelas (keadaan 5) keduanya dibandingkan dengan
            # ukuran gabungan dan **semuanya** salah, termasuk keadaan yang
            # benar. Terukur di `main` merah: keadaan 5 melaporkan "kelas
            # «…tampil saat yakin»: 6 pemeriksaan, baseline 2" padahal
            # keadaannya benar — yang 6 itu gabungan dua kelas.
            # `SHOWN_AT_BOTH_SIZES` **bukan** kelas substring dan tidak ada
            # di `counts` — penanda, bukan pemeriksaan — jadi dilewati di
            # sini (dibaca oleh blok "kedua ukuran" di bawah). Tanpa lompatan
            # ini namanya memicu `KeyError` karena tidak punya hitungan
            # baseline.
            for cls in must_fire:
                if cls not in counts:
                    continue
                dalam_kelas = sum(1 for name in expected if cls in name)
                if dalam_kelas != counts[cls]:
                    spurious.append(
                        f"kelas «{cls}»: {dalam_kelas} pemeriksaan, "
                        f"baseline {counts[cls]}")
            # Keadaan 5 menuntut "tampil saat yakin" berbunyi di **kedua** ukuran.
            #
            # Blok ini menolak keadaan yang hanya menyalakan satu ukuran —
            # kelas yang sudah tercatat di repo ini (salah satu ukuran
            # diukur, ukuran yang-important tidak). Cara menghitungnya
            # bergantung pada nama pemeriksaan yang **menyebut ukuran**,
            # jadi inilah alasan nama gerbang di `check-visuals.py` ditulis
            # sebagai "...tampil saat yakin (38 px)": tanpa ukuran di nama,
            # dua pemeriksaan yang sama-sama bernama itu tidak bisa
            # dibedakan dan "kedua ukuran" tidak dapat dinyatakan.
            #
            # Angka "2 dari 6" yang pernah tertulis di sini **salah**, dan
            # kesalahannya terukur: di run CI yang merah, keadaan 5
            # menyalakan 6 pemeriksaan total = 2 "tampil saat yakin"
            # (38 & 200 px) + 4 "masih tergambar di belahan menyala". Karena
            # itu kelas kedua ikut dituntut di `STATES`.
            if SHOWN_AT_BOTH_SIZES in must_fire:
                fired_sizes = sorted(
                    "38" if "38 px" in name else "200"
                    for name in fired if SHADING_SHOWN_CLASS in name)
                if fired_sizes != ["200", "38"]:
                    spurious.append(
                        'peredupan mati tetapi "tampil saat yakin" hanya '
                        f"berbunyi di ukuran {fired_sizes or '—'}, bukan "
                        "kedua ukuran")
            ok = not missing and not spurious
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:44s} "
                  f"{len(fired)} merah, {len(expected)} di kelas yang dituntut")
            for name in missing:
                print(f"       HARUSNYA MERAH, TIDAK: {name}")
            for name in spurious:
                print(f"       MERAH YANG TIDAK DIMINTA: {name}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
