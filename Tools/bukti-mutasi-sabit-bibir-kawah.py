#!/usr/bin/env python3
"""Buktikan gerbang sabit bibir kawah berbunyi — dan bahwa cakupannya sempit.

Kenapa harness ini ada.

`check_crater_drawing_constants` adalah salah satu dari **14 gerbang nirsaksi**
di `Tools/check-visuals.py` — gerbang yang tidak dirujuk satu pun dari 41
berkas `Tools/bukti-mutasi-*.py`, jadi tidak ada bukti bahwa ia bisa merah.
Audit di awal siklus ini menemukan 84 gerbang, 14 nirsaksi (sebelumnya 15/16 di
dua siklus terakhir; `check_mars_caps_fade_into_the_surface` dan
`check_png_is_well_formed` / `check_png_roundtrip` sudah ditutup lebih dulu, WIP
yang belum dikomit di pohon kerja).

Gerbang itu menjaga **rasio yang dinyatakan dalam dua satuan** — di **dua**
tempat gambar, dan keduanya harus sama:

    view  drawCraters      Path(… width: size * 1.84, height: size * 1.84 …)  diameter
    view  drawMoonCraters  Path(… width: size * 1.84, height: size * 1.84 …)  diameter
    port  kawah planet     canvas.disc(…, mr * 0.92, …)                       radius
    port  kawah Bulan      canvas.disc(…, mr * 0.92, …)                       radius

`1.84 = 2 × 0.92`. Perubahan pada salah satunya berarti gambar kawah di PNG
(yang diukur **seluruh** gerbang piksel repo ini) menyimpang dari gambar kawah
di jam — tanpa satu pun pemeriksaan yang berbunyi.

**Situs kedua adalah temuan siklus ini, dan ia temuan tentang gerbangnya, bukan
tentang angka.** Sampai `27dd677` cakram sabit bibir kawah digambar di satu
tempat. Commit itu menambahkan `drawMoonCraters` (view) + blok kawah Bulan
(port), dan gerbangnya — yang memakai `re.search`, jadi hanya membaca kemunculan
**pertama** — sejak itu mengukur kawah **planet** saja sambil tetap mencetak
"kawah: diameter view = dua kali radius port" seolah seluruh kelasnya terjaga.
Terukur atas pohon bersih, **hanya** situs Bulan dimutasi, tujuh gerbang
kawah/Bulan dijalankan di proses baru:

    view  Bulan  1.84 -> 1.60    7 gerbang, 0 gagal   <- buta
    port  Bulan  0.92 -> 0.70    7 gerbang, 0 gagal   <- buta

Dua akibat yang berbeda, dan keduanya ditutup di sini:

  - **Harness menolak jalan.** Jangkar lamanya (`width: size * 1.84 …`) kini
    muncul 2x, dan `verify_anchors` menuntut tepat 1x — itulah yang memerahkan
    `Engine Tests (Linux)`. Jangkar sekarang menyebut pembeda yang benar-benar
    ada di kode (`crater.rimDirectionY` vs `r.rimDirectionY`,
    `CRATER_RIM_OFFSET` vs `mr * 0.45`), bukan nomor baris.
  - **Gerbangnya buta pada situs kedua.** Diperbaiki jadi `findall`, dan
    **jumlah situs di kedua bahasa wajib sama** — syarat yang menutup arah
    paling senyap (satu bahasa dapat situs gambar baru, yang lain tidak), di
    mana tidak ada angka yang menyimpang dan hanya *banyaknya* yang berbeda.

### Yang diukur, bukan dikira-kira

Harness ini menjalankan gerbangnya di proses baru (mengimpor ulang
`check-visuals.py` dari berkas yang sudah dimutasi) dan membandingkan **himpunan
nama hasil yang dituntut**, bukan sekadar "ada yang merah": verdict yang
salah dapat dibedakan dari hasil yang hilang.

  keadaan                                                     hasil
  [baseline]                                                  hijau
  1. view PLANET: diameter 1.84 -> 1.70                       MERAH 1
       "kawah: diameter view = dua kali radius port"
  2. view PLANET: tinggi 1.84 -> 1.50 (cakram jadi elips)     MERAH 1
       "kawah: sabit bibir digambar sebagai lingkaran (view)"
  3. port PLANET: radius 0.92 -> 0.80                         MERAH 1
       "kawah: diameter view = dua kali radius port"
  4. view 1.70 + port 0.80 (dua-duanya 0.92×)           MERAH 1
  4b. view 1.84 + port 0.99 (dua-duanya 1.08×)          MERAH 1
  4c. view 1.9992 + port 0.9936 (dua-duanya 1.08×)      MERAH 1
  4d. view 2.0 + port 1.0 (tempat kedudukan lain)        hijau penuh
  5. kontrol negatif: baris view ditambah komentar di ujungnya hijau penuh
  6. view BULAN: diameter 1.84 -> 1.60                  MERAH 1  <- dulu buta
  7. port BULAN: radius 0.92 -> 0.70                    MERAH 1  <- dulu buta
  8. view BULAN: 1.84 × 1.50 (elips)                    MERAH 1
  9. situs BULAN dihapus dari view                      MERAH 1
  10. view BULAN 2.0 + port BULAN 1.0                    hijau penuh

Keadaan 4, 4b, 4c, 4d bersama-sama mengukur **himpunan tempat kedudukan** yang
sebenarnya dijaga gerbang ini — dan itu bukan yang dibilangkan docstring-nya.

Yang diuji `abs(view_diameter - 2 * port_radius) < 1e-9`: himpunan tempat
kedudukan **A = 2·B** secara **tepat**, bukan skala. Empat keadaan di atas
membuktikannya dengan mengubah kedua sisi bersama-sama:

  - **4** (`1.70`, `0.80`): keduanya dikali ≈0.924. Kalau aturannya "rasio",
    ini hijau. Terukur: **merah** (2·0.80 ≠ 1.70).
  - **4b** (`1.84`, `0.99`): keduanya dikali 1.08. Terukur: **merah**
    (2·0.99 ≠ 1.84).
  - **4c** (`1.9992`, `0.9936`): keduanya dikali 1.08 **dan** ditala supaya
    tempat kedudukan terpenuhi secara persis (1.9992 = 2·0.9996, bukan
    2·0.9936). Terukur: **merah** — karena yang dijaga `A = 2B`, bukan
    "`A = B × 2.0208`".
  - **4d** (`2.0`, `1.0`): satu-satunya arah di mana kedua sisi bergerak bersama
    dan **lulus** — karena `2·1.0 = 2.0` mendarat tepat di tempat kedudukan
    lainnya. Bukan karena "skala", melainkan karena ia adalah titik diskrit kedua
    yang diizinkan. Setiap faktor antara 1.0 dan 1.087 gagal; hanya lompatan
    tepat ke (2.0, 1.0) yang hijau.

Empat keadaan ini menunjukkan bahwa himpunan tempat kedudukan yang dijaga adalah
**hanya dua titik diskrit**: (1.84, 0.92) dan (2.0, 1.0) — sama sekali bukan
sifat invarian skala yang docstring gerbangnya klaim ("kalau kedua sisi diubah
bersama, gerbang ini tetap hijau"). Klaim itu **salah** untuk setiap faktor
kecuali kelipatan yang kebetulan mendarat tepat di (2.0, 1.0). Harness ini
memakai angka yang **diukur**, bukan diwarisi dari komentar — lihat STATUS untuk
kelanjutannya.

Keadaan 5 adalah kontrol negatif untuk mekanisme pengukurannya sendiri: `1.84`
mengambil nilainya dari **regex**, jadi teks yang berubah di sekitar angkanya
harus terbukti tidak menggeser hasilnya. Kalau keadaan ini memerah, yang berubah
bukan kode produksi, dan seluruh himpunan harapan di atas tidak berarti.

### Cacat yang ditemukan dengan mengukur, bukan dengan membaca

Harness ini awalnya ditulis untuk membuktikan **kelas kawah penuh** terjaga
(bentuk cakram, sabitnya benar-benar tergambar, kelegapannya mengikuti kekuatan
bibir). Yang terukur justru sebaliknya, dan itu bagian yang paling berharga di
sini — tiga mutasi yang mengubah gambar kawah di jam, semuanya **hijau** di
gerbang ini **dan** di kedua gerbang kawah piksel:

  a. view: `lit.fill(rimDisc, …)` dihapus — sabitnya tidak pernah tergambar,
     kawahnya jadi cakram gelap rata
  b. port: `clip_disc` dilepas dari cakram bibir — sabitnya jadi cakram penuh
     yang meluber keluar kawah
  c. port: `CRATER_RIM_OPACITY * rim_strength` -> `CRATER_RIM_OPACITY` —
     semua kawah sama terangnya, termasuk yang di sisi gelap

Ketiganya hijau karena **tidak satu pun** dari ketiga gerbang kawah membaca
sabitnya sebagai gambar. Yang dijaga hanya bentuk elips di view (`1.84`, lingkaran
vs elips) dan rasio terhadap port. Itu batas cakupan yang **dinyatakan**, bukan
dibiarkan terbaca sebagai "kelas kawah sudah terjaga". Harness ini karena itu
juga memuat keadaan (a)–(c) sebagai bukti batas itu, dengan harapan **hijau** yang
eksplisit: kalau kelak ada gerbang yang mulai membaca sabitnya, keadaan ini akan
mulai tidak sesuai harapan — dan itu tanda cakupannya meluas, bukan harnessnya
rusak.

Keadaan (c) diperiksa di dua tempat sekaligus: gerbangnya **dan** dua gerbang
kawah piksel tetangganya. Tiga-tiganya hijau, dan itu yang membuatnya layak
dilaporkan: gambar yang diukur semua gerbang PNG repo ini bisa kehilangan
perbedaan terang/gelap antar-kawah tanpa satu pun suara.

### Batas lain yang tidak diklaim

  - Harness ini mengukur **teks** kedua sisi, bukan piksel app Apple. Yang
    dibuktikan: rasio 1.84 : 0.92 terbaca dan merah kalau salah satu sisinya
    bergeser. Tidak ada klaim bahwa perangkat menggambar kawah dengan lebar
    persis itu.
  - `check_crater_rim_opacity_is_not_clamped` (klem `max(rs, 0.2)`) sudah
    dijaga **di siklus ini** — keadaan 11–14 di bawah menutupnya setelah
    gerbangnya diperbaiki supaya membaca situs kedua.
  - `check_no_loop_variable_leaks_into_a_call` dan sisa **12 gerbang nirsaksi
    lain** belum punya harness. Siklus ini menutup satu, bukan kelasnya.

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus handler
`SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally` dan meninggalkan mutasi hidup.
`require_clean_sources` menolak jalan bila berkasnya sudah menyimpang dari HEAD —
dan itu **bukan hiasan**: siklus ini sempat menemukan sebuah probe yang memulihkan
`render-visuals.py` ke isi pra-mutasi sambil menimpa WIP siklus lain yang belum
dikomit; kejadian itu tercatat di STATUS, dan penjagaan di `mutasi_sumber`
sekarang menolak mengembalikan berkas ke keadaan mana pun selain HEAD.

Pakai:
    python3 Tools/bukti-mutasi-sabit-bibir-kawah.py    # 0 = sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import re
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

HIJAU = "hijau"
MERAH = "merah"

GATE = "check_crater_drawing_constants"
#: Dua gerbang kawah piksel yang mengukur gambar **port**. Dijalankan bersama
#: keadaan (c) untuk membuktikan mereka pun tidak melihat kekuatan bibir.
PIXEL_GATES = (
    "check_crater_floor_opacity_comes_from_the_model",
    "check_crater_relief_matches_the_model",
)

#: Nama hasil kawah **di dalam** `check_crater_drawing_constants`, dibaca dari
#: sumber saat harness jalan. Alasan ia dinamis, bukan ditulis di sini:
#: gerbang itu sedang dikerjakan siklus lain (WIP di pohon kerja), jadi daftar
#: tangan akan menjadi basi. Yang dijamin oleh pembaca ini adalah **jumlahnya
#: tidak nol** — gerbang yang berhenti mengisi hasil tidak boleh terlihat
#: sebagai baseline yang bersih.
def _gate_result_names(gate, prefix):
    source = open(os.path.join(ROOT, "Tools", "check-visuals.py"),
                  encoding="utf-8").read()
    start = source.index("def " + gate + "(")
    end = source.find("\ndef ", start + 1)
    body = source[start:end if end != -1 else len(source)]
    return sorted(set(re.findall(r'"(' + prefix + r'[^"]*)"', body)))


#: Hasil gabungan ketiga gerbang pada keadaan (a)–(c), diambil dari
#: `PIXEL_GATES` supaya daftarnya tidak perlu dirawat tangan.
def _pixel_gate_result_names():
    source = open(os.path.join(ROOT, "Tools", "check-visuals.py"),
                  encoding="utf-8").read()
    names = set()
    for gate in PIXEL_GATES:
        start = source.index("def " + gate + "(")
        end = source.find("\ndef ", start + 1)
        body = source[start:end if end != -1 else len(source)]
        names.update(re.findall(r'Result\(\s*[fr]?"([^"]+)"', body))
    return sorted(names)


#: Hasil yang **menangkap** masing-masing arah. Dituntut **persis**: hasil yang
#: hilang (gerbang berhenti lebih awal) harus gagal, bukan diam-diam cocok
#: dengan himpunan kosong.
RATIO = "kawah: diameter view = dua kali radius port"
CIRCLE = "kawah: sabit bibir digambar sebagai lingkaran (view)"
#: Empat pemeriksaan konstanta yang selalu hijau di setiap keadaan — dipakai
#: supaya keadaan yang **wajib hijau** (4 dan 5) menuntut himpunan yang penuh,
#: bukan satu baris.
KONSTANTA = [name for name in _gate_result_names(
    "check_crater_drawing_constants", "kawah: CRATER_")]

#: (nama keadaan, [(berkas, cari, ganti), …] atau None, {nama hasil: harapan})

#: ── Jangkar sumber ──────────────────────────────────────────────────────
#: **Dua situs, dan keduanya harus unik.** Sampai `27dd677` cakram sabit
#: bibir kawah digambar di satu tempat saja, jadi satu jangkar `width: size *
#: 1.84 …` cukup. Commit itu menambahkan situs **kedua** (kawah Bulan),
#: dan sejak itu kedua jangkar lama muncul **2x** — `verify_anchors` menolak
#: seluruh harness (`JANGKAR TIDAK TERBACA`), dan itulah yang memerahkan
#: `Engine Tests (Linux)`.
#:
#: Pelajaran yang menentukan bentuk jangkar baru ini: **jangkar yang sama di
#: dua tempat bukan sekadar masalah penghitung.** Selama jangkarnya ambigu,
#: mutasi selalu mengenai situs **pertama** — jadi kawah Bulan tidak pernah
#: diukur, dan harness ini akan melaporkan "sesuai harapan" sambil tidak
#: pernah menyentuh subjek yang baru. Karena itu setiap jangkar di sini
#: menyebut **nama variabel medan arahnya** (`crater.rimDirectionY` vs
#: `r.rimDirectionY`) dan **baris pemakaian offsetnya** (`CRATER_RIM_OFFSET`
#: vs `mr * 0.45`) — pembeda yang benar-benar ada di kode, bukan nomor baris.
#: Situs kawah **planet** (`drawCraters`): medan `crater.…`.
VIEW_CIRCLES_PLANET = ("                y: cy + CGFloat(crater.rimDirectionY) * offset - size,\n"
                       "                width: size * 1.84, height: size * 1.84))")
#: Situs kawah **Bulan** (`drawMoonCraters`): medan `r.…` dari `craterRelief`.
VIEW_CIRCLES_MOON = ("                y: cy + CGFloat(r.rimDirectionY) * offset - size,\n"
                     "                width: size * 1.84, height: size * 1.84))")
#: Blok sabit bibir Bulan **utuh**, dipakai keadaan 9: yang diganti adalah
#: seluruh tiga barisnya, supaya situsnya benar-benar lenyap dari berkas.
VIEW_CIRCLES_MOON_WHOLE = (
    "            let rimDisc = Path(ellipseIn: CGRect(\n"
    "                x: cx + CGFloat(r.rimDirectionX) * offset - size,\n"
    "                y: cy + CGFloat(r.rimDirectionY) * offset - size,\n"
    "                width: size * 1.84, height: size * 1.84))\n"
    "            var lit = context\n"
    "            lit.clip(to: disc)\n"
    "            lit.fill(rimDisc, with: .color(rim.opacity(0.9 * strength)))")
#: Penggantinya: cakram penuh menggantikan sabit bibir. Masih Swift yang sah,
#: dan `width: size * N` tidak lagi ada di sana — jadi jumlah situs view
#: berkurang satu sementara port tetap dua.
VIEW_CIRCLES_MOON_REFACTORED = (
    "            let rimDisc = Path(ellipseIn: CGRect(\n"
    "                x: cx - size, y: cy - size,\n"
    "                width: size * 2, height: size * 2))\n"
    "            var lit = context\n"
    "            lit.clip(to: disc)\n"
    "            lit.fill(rimDisc, with: .color(rim.opacity(0.9 * strength)))")
#: Cakram sabit bibir di port (dipakai mutasi 3 dan 4).
PORT_DISC = ("canvas.disc(mx + rim_x * offset, my + rim_y * offset, "
             "mr * 0.92,")
#: Situs port untuk kawah planet: offsetnya dari `CRATER_RIM_OFFSET`.
PORT_DISC_PLANET = ("        offset = mr * CRATER_RIM_OFFSET\n"
                    "        canvas.disc(mx + rim_x * offset, my + rim_y * offset, mr * 0.92,")
#: Situs port untuk kawah Bulan: offsetnya literal `mr * 0.45`.
PORT_DISC_MOON = ("        offset = mr * 0.45\n"
                  "        canvas.disc(mx + rim_x * offset, my + rim_y * offset, mr * 0.92,")
#: Baris yang menggambar sabitnya di view; dipakai mutasi (a), yang **tidak**
#: ditangkap gerbang mana pun — lihat docstring.
VIEW_RIM_FILL = ("lit.fill(rimDisc, with: .color(rim.opacity(0.9 * "
                 "CGFloat(crater.rimStrength))))")
#: Cakram bibir di port **beserta** irisan ke cakram kawah.
PORT_RIM_FULL = (
    "        canvas.disc(mx + rim_x * offset, my + rim_y * offset, mr * 0.92,\n"
    '                    clipped(accent_fn(ACCENTS["craterRim"], night_mode,\n'
    "                                      min(1.0, CRATER_RIM_OPACITY"
    " * rim_strength))),\n"
    "                    clip_disc=(mx, my, mr))")
PORT_RIM_UNCLIPPED = (
    "        canvas.disc(mx + rim_x * offset, my + rim_y * offset, mr * 0.92,\n"
    '                    clipped(accent_fn(ACCENTS["craterRim"], night_mode,\n'
    "                                      min(1.0, CRATER_RIM_OPACITY"
    " * rim_strength))))")
#: Kekuatan bibir di port dibuat rata: 0.9 × rim_strength menjadi 0.9 tetap.
PORT_RIM_FLAT = ("min(1.0, CRATER_RIM_OPACITY * rim_strength))),",
                 "min(1.0, CRATER_RIM_OPACITY))),")

#: ── Gerbang opasitas bibir: situs kedua, yang dulu buta ──────────────────
#: `check_crater_rim_opacity_is_not_clamped` adalah gerbang **lain** dari
#: kelas yang sama, dan sampai siklus ini ia nirsaksi — tidak dirujuk satu pun
#: harness. Ia memakai `re.search`, jadi ia membaca kemunculan **pertama**
#: (`rim.opacity` kawah planet, `CRATER_RIM_OPACITY *` kawah planet) dan
#: tidak pernah melihat situs Bulan.
#:
#: Terukur atas pohon bersih, **hanya** situs Bulan dimutasi, tiga gerbang
#: kawah dijalankan di proses baru — semuanya **0 gagal**:
#:
#:     view Bulan  rim.opacity(0.9 * strength) -> 0.9 * max(strength, 0.2)
#:     port Bulan  min(1.0, 0.9 * strength)    -> 0.50 * strength
#:
#: Klem yang sama di situs **planet** memerahkan gerbang itu. Jadi cacatnya
#: pembacanya, bukan angkanya.
#:
#: Situs Bulan juga menulis `0,9` sebagai **literal** di kedua bahasa,
#: sementara situs planet memakai konstanta bernama `CRATER_RIM_OPACITY`.
#: Akibatnya menggeser `0,9` di situs Bulan — di bahasa mana pun, bahkan di
#: kedua-duanya sekaligus — juga tidak digigit apa pun. Keadaan 12 dan 13
#: menuntut keduanya MERAH **sesudah** gerbangnya diperbaiki.
OPACITY = "check_crater_rim_opacity_is_not_clamped"
#: Nama hasil yang menangkap "situs kedua tidak dibaca".
OPACITY_VIEW_CLAMP = "kawah: opasitas bibir view tetap memakai rimStrength apa adanya"
OPACITY_PORT_NAMED = "kawah: setiap situs opasitas bibir port memakai konstantanya"
OPACITY_PORT_CLAMP = "kawah: opasitas bibir port tidak memakai klem yang tidak ada di view"
OPACITY_SITES_EQUAL = "kawah: jumlah situs opasitas bibir sama di kedua bahasa"
#: Situs **kedua** menurut urutan pembacaan (`port.split(...)`): kawah planet
#: dulu, kawah Bulan kemudian. Namanya deterministik karena urutannya berasal
#: dari urutan di berkas, bukan dari himpunan.
OPACITY_FACTOR_MOON = "kawah: situs 1 memakai faktor yang sama di kedua bahasa"

#: Situs **view** kawah Bulan (`drawMoonCraters`): medan `r.…`, kekuatannya
#: variabel lokal `strength` — bukan `crater.rimStrength`.
VIEW_RIM_FILL_MOON = "            lit.fill(rimDisc, with: .color(rim.opacity(0.9 * strength)))"
#: Situs **port** kawah Bulan, sesudah perbaikan: konstanta yang sama dengan
#: situs planet. Sebelum perbaikan barisnya memuat literal `0.9`.
PORT_RIM_FILL_MOON = ("                    lambda x, y, a=min(1.0, CRATER_RIM_OPACITY"
                      " * strength): (rim_rgb, a),")

STATES = [
    ("[baseline] sumber bersih", None,
     {GATE: HIJAU, RATIO: HIJAU, CIRCLE: HIJAU, **{n: HIJAU for n in KONSTANTA}}),

    # ── 1. View mengecil, port tidak ─────────────────────────────────────
    # Arah yang paling mungkin terjadi: orang menyunting gambar kawah di Mac,
    # dan port Python di Linux tidak ikut. Cakram sabit menyempit di jam dan
    # tetap lebar di PNG — gambar yang diukur setiap gerbang piksel repo ini
    # bukan gambar yang tampil di perangkat.
    #
    # `CIRCLE` sengaja **tidak** diharapkan di sini: yang berubah hanya
    # diameter, dan tinggi ikut berubah bersamanya. Kalau ia ikut merah,
    # kedua pemeriksaan sedang mengukur hal yang sama — dan salah satunya
    # tidak menjaga apa pun.
    ("1. view PLANET: diameter 1.84 -> 1.70 (port tidak ikut)",
     [(VIEW, VIEW_CIRCLES_PLANET,
       "                y: cy + CGFloat(crater.rimDirectionY) * offset - size,\n"
       "                width: size * 1.70, height: size * 1.70))")],
     {GATE: MERAH, RATIO: MERAH}),

    # ── 2. Cakram jadi elips ─────────────────────────────────────────────
    # Lebar dan tinggi ditulis terpisah di view, jadi satu angka yang lupa
    # diubah menghasilkan **bentuk lain** — bukan lagi bibir kawah. Rasio
    # terhadap port tetap 1:2 di sini, jadi `RATIO` wajib hijau: itulah yang
    # membuktikan kedua pemeriksaan itu tidak mubazir.
    ("2. view PLANET: tinggi 1.84 -> 1.50 (cakram jadi elips)",
     [(VIEW, VIEW_CIRCLES_PLANET,
       "                y: cy + CGFloat(crater.rimDirectionY) * offset - size,\n"
       "                width: size * 1.84, height: size * 1.50))")],
     {GATE: MERAH, RATIO: HIJAU, CIRCLE: MERAH}),

    # ── 3. Port mengecil, view tidak ─────────────────────────────────────
    # Arah sebaliknya. Sifat simetrisnya penting: kalau hanya satu arah yang
    # dijaga, `view 1.70 + port 0.80` (dua-duanya diperkecil) lolos sebagai
    # "keseimbangan", padahal tidak ada yang mengatakannya sama.
    ("3. port PLANET: radius 0.92 -> 0.80 (view tidak ikut)",
     [(RENDER, PORT_DISC_PLANET, PORT_DISC_PLANET.replace("0.92", "0.80"))],
     {GATE: MERAH, RATIO: MERAH}),

    # ── 4. Kedua sisi diperkecil bersama (faktor sama) ───────────────────
    # Ini keadaan yang **paling sering dikira hijau**. Gerbangnya menguji
    # `view_diameter == 2 * port_radius` — keseimbangan, bukan skala. View
    # 1.70 dan port 0.80 sama-sama dikali ≈0.924 dari aslinya, jadi kalau
    # gerbangnya benar-benar mengikat "rasio", keadaan ini hijau. Terukur:
    # merah 1. Yang dijaganya himpunan tempat kedudukan `view = 2 × port`,
    # dan mengecil dengan satu faktor membawa view keluar dari tempat
    # kedudukan itu (2 × 0.80 = 1.60, bukan 1.70).
    # Ini bukan keluhan: hasil ini yang membuat 4b berarti — 4b adalah
    # satu-satunya arah di mana kedua sisi boleh bergerak bersama.
    ("4. view 1.70 + port 0.80 (dua-duanya 0.92×) — terukur MERAH",
     [(VIEW, VIEW_CIRCLES_PLANET,
       "                y: cy + CGFloat(crater.rimDirectionY) * offset - size,\n"
       "                width: size * 1.70, height: size * 1.70))"),
      (RENDER, PORT_DISC_PLANET, PORT_DISC_PLANET.replace("0.92", "0.80"))],
     {GATE: MERAH, RATIO: MERAH}),

    # ── 4b–4d. Dua sisi bergerak bersama, dan gerbangnya tetap merah ──────
    # Empat keadaan ini yang membuktikan klaim docstring gerbangnya **salah**.
    # Docstring-nya menulis: "kalau **kedua** sisi diubah bersama (`view 1.60 +
    # port 0.80`), gerbang ini tetap hijau" — sifat invariansi skala. Terukur:
    # tidak ada satu pun faktor skala (kecuali 1.0) yang hijau, karena yang
    # diuji `abs(view - 2*port) < 1e-9` secara **tepat**. `view 1.60 + port
    # 0.80` hanya kebetulan cocok karena 2·0.80 = 1.60 — angka yang dipilih
    # untuk contohnya, bukan sifat aturannya.
    #
    # 4b: dikali 1.08 → 2·0.99 = 1.98 ≠ 1.84. MERAH.
    ("4b. view 1.84 + port 0.99 (dua-duanya 1.08×)",
     [(RENDER, PORT_DISC_PLANET, PORT_DISC_PLANET.replace("0.92", "0.99"))],
     {GATE: MERAH, RATIO: MERAH}),

    # 4c: dikali 1.08 **dan** tempat kedudukan dipenuhi lewat angka lain —
    # 1.9992 di view vs 0.9936 di port. Kalau gerbangnya mengikat "view =
    # port × 2.0208" (rasio), ini hijau. Terukur: MERAH, karena yang dijaga
    # `view = 2 × port` dengan **kedua** angka, bukan rasio bebas.
    ("4c. view 1.9992 + port 0.9936 (rasio 2.0208, bukan 2)",
     [(VIEW, VIEW_CIRCLES_PLANET,
       "                y: cy + CGFloat(crater.rimDirectionY) * offset - size,\n"
       "                width: size * 1.9992, height: size * 1.9992))"),
      (RENDER, PORT_DISC_PLANET, PORT_DISC_PLANET.replace("0.92", "0.9936"))],
     {GATE: MERAH, RATIO: MERAH}),

    # 4d: satu-satunya lompatan bersama yang **lulus** — (2.0, 1.0) mendarat
    # tepat di tempat kedudukan A = 2B. Dipakai sebagai kontrol bahwa 4b/4c
    # bukan "semua mutasi merah karena regex rusak": satu arah yang sah
    # memang hijau, dan itu terukur.
    ("4d. view 2.0 + port 1.0 (tempat kedudukan lain) — wajib hijau",
     [(VIEW, VIEW_CIRCLES_PLANET,
       "                y: cy + CGFloat(crater.rimDirectionY) * offset - size,\n"
       "                width: size * 2.0, height: size * 2.0))"),
      (RENDER, PORT_DISC_PLANET, PORT_DISC_PLANET.replace("0.92", "1.0"))],
     {GATE: HIJAU, RATIO: HIJAU, CIRCLE: HIJAU, **{n: HIJAU for n in KONSTANTA}}),

    # ── 5. Kontrol negatif: mekanisme pengukurannya sendiri ─────────────
    # Angka 1.84 dibaca lewat regex. Teks yang berubah di sekitarnya tidak boleh
    # menggeser hasil bacanya — kalau keadaan ini memerah, yang berubah bukan
    # kode produksi, dan seluruh himpunan harapan di atas tidak berarti.
    ("5. kontrol negatif: komentar ditambahkan di ujung baris view",
     [(VIEW, VIEW_CIRCLES_PLANET,
       "                y: cy + CGFloat(crater.rimDirectionY) * offset - size,\n"
       "                width: size * 1.84, height: size * 1.84))  // sama")],
     {GATE: HIJAU, RATIO: HIJAU, CIRCLE: HIJAU, **{n: HIJAU for n in KONSTANTA}}),

    # ── 6–9. Situs **kedua** (kawah Bulan): yang selama ini tak terukur ──
    #
    # Empat keadaan ini ada karena diukur, bukan dikira. Atas pohon bersih,
    # **hanya** situs Bulan yang dimutasi, lalu ketujuh gerbang kawah/Bulan
    # repo ini dijalankan di proses baru:
    #
    #     view  Bulan  1.84 -> 1.60    7 gerbang, 0 gagal   <- buta
    #     port  Bulan  0.92 -> 0.70    7 gerbang, 0 gagal   <- buta
    #
    # Sebabnya bukan gerbangnya salah, melainkan pembacanya: `re.search`
    # mengembalikan kemunculan **pertama**, dan yang pertama selalu kawah
    # planet. Karena itu keadaan 6 dan 7 menuntut MERAH — dan keduanya
    # diverifikasi merah **sesudah** gerbangnya diperbaiki.
    ("6. view BULAN: diameter 1.84 -> 1.60 (situs kedua, dulu buta)",
     [(VIEW, VIEW_CIRCLES_MOON,
       "                y: cy + CGFloat(r.rimDirectionY) * offset - size,\n"
       "                width: size * 1.60, height: size * 1.60))")],
     {GATE: MERAH, RATIO: MERAH}),

    ("7. port BULAN: radius 0.92 -> 0.70 (situs kedua, dulu buta)",
     [(RENDER, PORT_DISC_MOON, PORT_DISC_MOON.replace("0.92", "0.70"))],
     {GATE: MERAH, RATIO: MERAH}),

    ("8. view BULAN: 1.84 × 1.50 (elips di situs kedua)",
     [(VIEW, VIEW_CIRCLES_MOON,
       "                y: cy + CGFloat(r.rimDirectionY) * offset - size,\n"
       "                width: size * 1.84, height: size * 1.50))")],
     {GATE: MERAH, CIRCLE: MERAH, RATIO: HIJAU}),

    # Keadaan 9 adalah arah **paling senyap** dari kelas ini, dan alasan syarat
    # "jumlah situs sama" ada: satu bahasa mendapat situs gambar baru dan
    # bahasa lain tidak. Di situ tidak ada angka yang menyimpang — yang
    # berbeda hanya **berapa banyak** yang digambar, sehingga tidak ada
    # perbandingan nilai pun yang bisa melihatnya. Tanpa syarat jumlah,
    # gerbangnya hijau selama himpunan angka yang **tersisa** cocok.
    #
    # Mutasinya sengaja berbentuk refaktor yang **sah secara Swift** — sabit
    # bibir Bulan diganti cakram penuh, jadi situsnya benar-benar hilang —
    # bukan penghapusan baris yang meninggalkan kode rusak. Yang diukur di sini
    # adalah hitungan situs, dan itu hanya berarti kalau kodenya masih kode.
    ("9. situs BULAN di view jadi cakram penuh (jumlah situs berbeda)",
     [(VIEW, VIEW_CIRCLES_MOON_WHOLE, VIEW_CIRCLES_MOON_REFACTORED)],
     {GATE: MERAH, RATIO: MERAH}),

    # ── 10. Kontrol negatif: situs kedua bergerak **bersama** ────────────
    # Pasangan 4d untuk situs Bulan. Kedua sisi naik ke (2.0, 1.0) bersama,
    # jadi himpunannya tetap cocok dan gerbangnya wajib hijau. Inilah yang
    # membedakan "membaca semua situs" dari "memerahkan apa pun yang
    # menyentuh situs kedua" — tanpa keadaan ini, perbaikan yang cuma
    # menghitung situs akan lulus 6–9 dengan sempurna.
    ("10. kontrol negatif: view BULAN 2.0 + port BULAN 1.0 — wajib hijau",
     [(VIEW, VIEW_CIRCLES_MOON,
       "                y: cy + CGFloat(r.rimDirectionY) * offset - size,\n"
       "                width: size * 2.0, height: size * 2.0))"),
      (RENDER, PORT_DISC_MOON, PORT_DISC_MOON.replace("0.92", "1.0"))],
     {GATE: HIJAU, RATIO: HIJAU, CIRCLE: HIJAU, **{n: HIJAU for n in KONSTANTA}}),

    # ── (a)–(c). Batas cakupan, dan diukur supaya tidak jadi klaim ───────
    # Ketiga mutasi ini mengubah gambar kawah di jam. Tiga-tiganya **hijau**,
    # di gerbang ini maupun di dua gerbang kawah piksel. Yang dicatat bukan
    # "gerbangnya salah", melainkan **apa yang tidak dijaganya** — supaya
    # "hijau" di atas tidak dibaca lebih luas daripada yang benar-benar diukur.
    # Kuncinya `PIXEL_GATES` — kita hanya menuntut kedua gerbang itu hijau
# **secara keseluruhan**, bukan nama hasil di dalamnya. Hasil itu berupa
# f-string (`bayangan kawah: {label}`), jadi nama persisnya baru diketahui
# saat gerbang jalan; yang relevan di sini hanyalah "kedua gerbang tetap
# hijau" sebagai bukti bahwa kelas itu tidak terbaca sebagai gambar.
    ("(a) batas: view berhenti menggambar sabitnya (hijau di ketiganya)",
     [(VIEW, VIEW_RIM_FILL,
       "context.stroke(rimDisc, with: .color(rim.opacity(0.9 * "
       "CGFloat(crater.rimStrength))), lineWidth: 1)")],
     {GATE: HIJAU, RATIO: HIJAU, CIRCLE: HIJAU,
      **{n: HIJAU for n in KONSTANTA},
      **{gate: HIJAU for gate in PIXEL_GATES}}),

    ("(b) batas: irisan cakram bibir di port dilepas",
     [(RENDER, PORT_RIM_FULL, PORT_RIM_UNCLIPPED)],
     {GATE: HIJAU, RATIO: HIJAU, CIRCLE: HIJAU,
      **{n: HIJAU for n in KONSTANTA},
      **{gate: HIJAU for gate in PIXEL_GATES}}),

    ("(c) batas: kekuatan bibir di port jadi rata (tidak ikut rim_strength)",
     [(RENDER, PORT_RIM_FLAT[0], PORT_RIM_FLAT[1])],
     {GATE: HIJAU, RATIO: HIJAU, CIRCLE: HIJAU,
      **{n: HIJAU for n in KONSTANTA},
      **{gate: HIJAU for gate in PIXEL_GATES}}),

    # ── 11–14. Gerbang **lain** dari kelas yang sama: opasitas bibir ──────
    #
    # Empat keadaan ini menutup gerbang yang sampai siklus ini **nirsaksi**:
    # tidak dirujuk satu pun dari 76 harness. Ia memakai `re.search`, jadi ia
    # hanya membaca situs **pertama** — dan sejak `27dd677` menambahkan situs
    # Bulan, situs itu tidak diukur siapa pun.
    #
    # Semua keadaan di bawah **hanya** menyentuh situs Bulan. Itu syaratnya:
    # kalau salah satunya juga menggeser situs planet, yang terbukti merah
    # adalah gerbang yang sudah bekerja, bukan cakupan barunya.
    #
    # 11: klem yang hidup di satu bahasa saja, di situs kedua. Inilah cacat
    #     asli gerbangnya, dipindahkan ke situs yang dulu buta.
    ("11. view BULAN: klem max(strength, 0.2) yang tidak ada di port",
     [(VIEW, VIEW_RIM_FILL_MOON,
       "            lit.fill(rimDisc, with: .color(rim.opacity(0.9 * "
       "max(strength, 0.2))))")],
     {OPACITY: MERAH, OPACITY_VIEW_CLAMP: MERAH}),

    # 12: faktor di **port** situs Bulan bergeser. Gerbang ini yang paling
    #     perlu melihatnya: gambar kawah Bulan di PNG menyimpang dari gambar
    #     di jam, dan seluruh gerbang piksel repo ini mengukur PNG itu.
    ("12. port BULAN: faktor opasitas 0.90 -> 0.50 (konstanta ditinggalkan)",
     [(RENDER, PORT_RIM_FILL_MOON,
       PORT_RIM_FILL_MOON.replace("CRATER_RIM_OPACITY * strength",
                                  "0.50 * strength"))],
     {OPACITY: MERAH, OPACITY_PORT_NAMED: MERAH}),

    # 13: faktor **view** situs Bulan bergeser, port tetap memakai konstanta.
    #     Ini yang paling perlu ditangkap di sisi view: gambar kawah Bulan di
    #     jam menyimpang dari yang diukur PNG. Port tetap memakai
    #     `CRATER_RIM_OPACITY`, jadi pemeriksaan faktor per situs (situs 1)
    #     tetap membacanya dan harus memerah.
    ("13. view BULAN: faktor opasitas 0.90 -> 0.50 (port tetap konstanta)",
     [(VIEW, VIEW_RIM_FILL_MOON,
       "            lit.fill(rimDisc, with: .color(rim.opacity(0.50 * strength)))")],
     {OPACITY: MERAH, OPACITY_FACTOR_MOON: MERAH}),

    # 14: kontrol negatif untuk situs kedua. Komentar ditambahkan di ujung
    #     baris view Bulan — angka dan bentuknya tidak berubah, jadi gerbang
    #     wajib tetap hijau. Ini yang membedakan "membaca situs kedua" dari
    #     "memerahkan apa pun yang menyentuh situs kedua": tanpa dia,
    #     perbaikan yang cuma menyapu seluruh berkas akan lulus 11–13.
    ("14. kontrol negatif: komentar di ujung baris view BULAN — wajib hijau",
     [(VIEW, VIEW_RIM_FILL_MOON, VIEW_RIM_FILL_MOON + "  // sama")],
     {OPACITY: HIJAU, OPACITY_VIEW_CLAMP: HIJAU, OPACITY_SITES_EQUAL: HIJAU,
      OPACITY_PORT_NAMED: HIJAU}),
]

# Dijalankan di proses baru: memuat ulang `check-visuals.py` (dan
# `render-visuals.py` di dalamnya) dari berkas yang **sudah dimutasi** di disk.
PROBE = r"""
import importlib.util, os, sys

root = sys.argv[1]
names = [n for n in sys.argv[2].split(",") if n]

def load(mod, filename):
    path = os.path.join(root, "Tools", filename)
    spec = importlib.util.spec_from_file_location(mod, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[mod] = module
    spec.loader.exec_module(module)
    return module

sys.path.insert(0, os.path.join(root, "Tools"))
sys.dont_write_bytecode = True
try:
    C = load("cv_probe", "check-visuals.py")
except BaseException as exc:
    print("ERR <import>: " + type(exc).__name__ + ": " + str(exc)[:400])
    raise SystemExit(0)

for name in names:
    fn = getattr(C, name, None)
    if fn is None:
        print("ERR " + name + ": gerbang tidak ada")
        continue
    results = []
    try:
        fn(results)
    except BaseException as exc:
        print("ERR " + name + ": " + type(exc).__name__ + ": " + str(exc)[:300])
        continue
    if not results:
        # Bukan hijau: gerbang yang tidak mengembalikan hasil tidak mengukur
        # apa pun, dan himpunan kosong harus terlihat.
        print("KOSONG " + name)
        continue
    ok = all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + "  " + str(r.name) + "  | " +
              str(r.detail))
"""

#: (nama keadaan, [(berkas, cari, ganti), …] atau None, {nama hasil: harapan})

#: Nama hasil yang harus ada di himpunan harapan keadaan (a)–(c); dipakai untuk
#: memastikan keadaan yang memeriksa dua gerbang piksel benar-benar menyebutnya.
for _name, _edits, _expected in STATES:
    if _expected.get(PIXEL_GATES[0]) is not None:
        for _gate in PIXEL_GATES:
            _expected.setdefault(_gate, HIJAU)


def _gate_names(state):
    """Gerbang yang dijalankan pada satu keadaan, terurut & unik."""
    expected = state[2]
    return [name for name in expected if name.startswith("check_")]


def run_probe(gate_names):
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, ",".join(gate_names)],
                         capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        return None, (out.stderr or out.stdout).strip()[-1200:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("ERR "):
            return None, line
        if line.startswith("KOSONG "):
            verdicts[line.split(" ", 1)[1]] = "kosong"
            continue
        state, rest = line.split(" ", 1)
        name = rest.split("  | ")[0].strip()
        verdicts[name] = HIJAU if state == "OK" else MERAH
    return verdicts, None


def verify_anchors(edits, label):
    """Setiap jangkar harus muncul **persis sekali** di berkasnya."""
    problems = []
    for path, find, _replace in edits:
        text = open(path, encoding="utf-8").read()
        hits = text.count(find)
        if hits != 1:
            problems.append(f"{label}: jangkar muncul {hits}x (butuh 1) di "
                            f"{os.path.basename(path)}: {find[:70]!r}")
    return problems


def main():
    mutasi_sumber.require_clean_sources([VIEW, RENDER])
    originals = {path: open(path, "rb").read() for path in (VIEW, RENDER)}
    baseline_md5 = {path: hashlib.md5(data).hexdigest()
                    for path, data in originals.items()}
    failures = []

    def restore():
        for path, data in originals.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for label, edits, expected in STATES:
            restore()
            if edits:
                problems = verify_anchors(edits, label)
                if problems:
                    failures.extend(problems)
                    print(f"{label}: JANGKAR TIDAK TERBACA")
                    for item in problems:
                        print(f"    {item}")
                    continue
                for path, find, replace in edits:
                    text = open(path, encoding="utf-8").read()
                    mutasi_sumber.write_source(path, text.replace(find, replace))

            verdicts, error = run_probe(_gate_names((label, edits, expected)))
            if verdicts is None:
                failures.append(f"{label}: probe gagal: {error}")
                print(f"{label}: PROBE GAGAL\n{error}")
                continue

            # **Subset, bukan kesamaan persis.** Harapan tiap keadaan menyebut
            # hasil yang **menangkap** arah mutasinya, bukan seluruh isi
            # gerbang. Menuntut kesamaan akan merah pada kode yang benar
            # setiap kali gerbangnya menambah satu pemeriksaan — dan itu
            # mengajarkan orang untuk melonggarkan daftar harapan, bukan untuk
            # mempercayainya. Yang tetap tidak bisa lolos: nama yang
            # diharapkan **hilang** (gerbang berhenti lebih awal), verdict yang
            # salah, dan gerbang yang mengembalikan **nol** hasil (dilaporkan
            # `KOSONG` oleh probe dan menjadi hasil hilang di sini).
            problems = []
            missing = sorted(set(expected) - set(verdicts))
            if missing:
                problems.append(f"hasil hilang: {missing}")
            wrong = [(n, expected[n], verdicts[n]) for n in sorted(expected)
                     if n in verdicts and verdicts[n] != expected[n]]
            if wrong:
                problems.append("verdict salah: " + "; ".join(
                    f"{n} diharapkan {w}, terukur {g}" for n, w, g in wrong))

            if problems:
                failures.append(f"{label}: " + " | ".join(problems))
                print(f"{label}: TIDAK SESUAI HARAPAN")
                for item in problems:
                    print(f"    {item}")
            else:
                red = sum(1 for v in verdicts.values() if v == MERAH)
                merah = [n for n, v in sorted(verdicts.items())
                         if v == MERAH and n.startswith("check_")]
                print(f"{label}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} hasil)" +
                      (f" — merah: {', '.join(merah)}" if merah else ""))
    finally:
        restore()

    print()
    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        state = "pulih persis" if after == digest else "TIDAK PULIH"
        print(f"md5 {os.path.relpath(path, ROOT)}: {digest} -> {after} ({state})")
        if after != digest:
            failures.append(f"berkas tidak pulih: {path}")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
