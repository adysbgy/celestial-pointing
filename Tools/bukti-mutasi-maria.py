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
                                   maria di port. Harus menyalakan gerbang
                                   kebocoran pada **kedua ukuran** — bukan
                                   hanya 200 px — karena ukuran kartu jam
                                   adalah satu-satunya ukuran yang penting
                                   bagi pengguna, dan cacat yang tidak
                                   terlihat di satu ukuran bisa dominan di
                                   ukuran lain.
  2. port: maria dihapus total     `MARIA` dikosongkan, jadi bercaknya tidak
                                   pernah digambar. Ini keadaan **arah
                                   sebaliknya**, dan justru yang paling
                                   penting: tanpa gerbang pasangannya, cara
                                   termurah memenuhi "nol piksel di belahan
                                   gelap" adalah berhenti menggambar cirinya
                                   sama sekali. Yang berbunyi di sini harus
                                   "masih tergambar di sisi menyala",
                                   **bukan** "tidak bocor" — kalau keduanya
                                   berbunyi, gerbangnya tidak memisahkan
                                   "dipotong" dari "dihapus", dan itu dua
                                   perbaikan yang berlawanan arah.

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
#: Keadaan 1: potongan maria dilepas. Yang dihapus hanya syaratnya, bukan
#: penggambarnya — `canvas.disc` tetap menggambar, jadi kalau gerbangnya tetap
#: hijau, artinya yang diukur bukan "apakah ciri dipotong".
PORT_MARIA_CLIP = ('        canvas.disc(mx, my, size * radius,\n'
                   '                    lambda x, y: maria(x, y) if '
                   '_point_in_polygon(x, y, points)\n'
                   '                    else (lit_rgb, 0.0))')
PORT_MARIA_NOCLIP = ('        canvas.disc(mx, my, size * radius,\n'
                     '                    lambda x, y: maria(x, y))')

#: Keadaan 2: maria tidak digambar sama sekali. Lariknya dikosongkan, jadi
#: gelungnya tidak menggambar apa pun tanpa mengubah satu baris kode pun di
#: fungsi penggambarnya.
PORT_MARIA_ARRAY = ('MARIA = [(-0.28, -0.30, 0.26), (0.10, -0.44, 0.20),\n'
                    '         (-0.34, 0.06, 0.22), (0.22, 0.26, 0.16)]')
PORT_MARIA_EMPTY = 'MARIA = []'

#: Keadaan 3: larik maria dihidupkan digeser, sementara `MARIA_REFERENCE` yang
#: dibekukan di gerbang tidak ikut.
#:
#: `MARIA_REFERENCE` adalah **salinan**, jadi ia bisa membusuk diam-diam:
#: gerbang kebocoran lalu menyaring kasus memakai susunan bercak yang tidak
#: pernah digambar, dan ia tetap hijau selamanya. Keadaan ini menuntut
#: `check_moon_maria_reference_matches_the_model` berbunyi — dan **hanya** dia,
#: karena menggeser satu bercak tidak memindahkan maria ke belahan gelap.
PORT_MARIA_REFERENCE = ('MARIA_REFERENCE = [(-0.28, -0.30, 0.26), '
                        '(0.10, -0.44, 0.20),\n'
                        '                   (-0.34, 0.06, 0.22), '
                        '(0.22, 0.26, 0.16)]')
PORT_MARIA_REFERENCE_DRIFT = ('MARIA_REFERENCE = [(-0.28, -0.30, 0.26), '
                              '(0.10, -0.44, 0.20),\n'
                              '                   (-0.34, 0.06, 0.22), '
                              '(0.22, 0.26, 0.99)]')

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
     [(RENDER, PORT_MARIA_CLIP, PORT_MARIA_NOCLIP)],
     [DARK_CLASS]),
    ("2. port: maria tidak digambar sama sekali",
     [(RENDER, PORT_MARIA_ARRAY, PORT_MARIA_EMPTY)],
     [LIT_CLASS]),
    ("3. gerbang: MARIA_REFERENCE menyimpang dari model",
     [(CHECK, PORT_MARIA_REFERENCE, PORT_MARIA_REFERENCE_DRIFT)],
     [REFERENCE_CLASS]),
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
            (RENDER, PORT_MARIA_ARRAY, "larik `MARIA` di port"),
            (CHECK, PORT_MARIA_REFERENCE, "`MARIA_REFERENCE` di gerbang")):
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
                  for cls in (DARK_CLASS, LIT_CLASS, REFERENCE_CLASS)}
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
            # Kalau jumlah anggotanya berbeda dari baseline, katalognya
            # bergerak di tengah harness — itu sendiri layak merah.
            for cls in must_fire:
                if len(expected) != counts[cls]:
                    spurious.append(
                        f"kelas «{cls}»: {len(expected)} pemeriksaan, "
                        f"baseline {counts[cls]}")
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
