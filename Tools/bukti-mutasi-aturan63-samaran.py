#!/usr/bin/env python3
"""Buktikan samaran "engine ragu" di **Swift** dijaga, bukan hanya port Python-nya.

Kenapa berkas ini ada
=====================

Ada dua samaran di repo ini, dan selama ini hanya satu yang diukur:

  * `Tools/render-visuals.py`  `VIEW_UNCERTAIN_BLUR_FRACTION = 0.06`
    Port Python. Diukur `Tools/check-visuals.py` (piksel bertepi keras), dan
    `Tools/bukti-mutasi-objek-samar.py` membuktikan gerbang itu berbunyi.

  * `Apps/Shared/CelestialVisualView.swift`  `diameter * 0.06`
    Yang **benar-benar menggambar di perangkat**. Tidak diukur siapa pun.

Kedua angka itu sama hari ini, dan tidak ada satu pun gerbang yang menuntut
mereka sama. Terukur pada pohon utuh, proses baru, dengan `swift-ui-lint.sh`
di `HEAD`:

    CelestialVisualView.swift:  diameter * 0.06  ->  diameter * 0.0
    CelestialVisualView.swift:  uncertainBlurOpacity 0.75  ->  1.0
    CelestialVisualView.swift:  guard NightMode.isOn else  ->  guard false else
    -> ketiganya exit 0, "SEMUA GERBANG UI LULUS"

Akibatnya, di jam dan di iPhone, kandidat yang engine **belum kunci** digambar
tajam dan penuh — cincin Saturnus, pita Jupiter, warna spektral bintang —
tepat di samping badge "Ragu". Seluruh 62 aturan tetap hijau, karena semuanya
memeriksa **cabang** yang memutuskan menyamar (`UncertainBlur.allows`,
Aturan 50/51), bukan **kekuatan** samarannya. Dan port Python tetap hijau
karena ia membaca konstantanya sendiri.

Kelas cacat ini sudah tercatat dua kali di repo ini: gerbang yang mengukur
salinan, bukan yang dipakai.

Yang diuji
==========

  1. radius samaran Swift = 0                          MERAH
  2. opasitas samaran Swift = 1.0 (tanpa peredupan)    MERAH
  3. radius Swift menyimpang dari port Python          MERAH
  4. kontrol negatif: pohon apa adanya                 hijau

Keadaan 3 adalah intinya: ia menuntut **dua angka itu sama**, sehingga
mengubah salah satunya saja memerahkan gerbang. Tanpa keadaan itu, seseorang
bisa "memperbaiki" port Python dan meninggalkan Swift di angka lama — atau
sebaliknya — dan tidak ada yang tahu.

Arah kedua
==========

Ketiga keadaan cacat dijalankan lagi atas lint pra-perbaikan (`git show`,
bukan dikarang) dan wajib HIJAU di sana.

Yang TIDAK dibuktikan
=====================

Aturan ini menjaga **angka** samaran. Ia tidak membuktikan bahwa `blur`/`opacity` itu benar-benar
dipasang pada gambar (itu wilayah Aturan 32/60), dan tidak membuktikan bahwa
6% diameter adalah angka yang tepat — hanya bahwa angka yang dipakai Swift
sama dengan yang dipakai port Python yang terukur, dan bahwa ia bukan nol.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")

RULE_HEADER = "== Aturan 63:"
CLEAN_MARK = "Bersih: samaran"

RADIUS_BENAR = "        diameter * 0.06"
RADIUS_NOL = "        diameter * 0.0"
RADIUS_LAIN = "        diameter * 0.12"

OPACITY_BENAR = "    private static let uncertainBlurOpacity: Double = 0.75"
OPACITY_SATU = "    private static let uncertainBlurOpacity: Double = 1.0"

#: Revisi **pra-perbaikan** untuk arah kedua: commit terakhir yang belum punya
#: blok Aturan 63 sama sekali.
#:
#: Kenapa bukan `HEAD`. Versi pertama harness ini memakai `HEAD`, dengan alasan
#: "lint di HEAD hari ini belum punya aturan ini" — benar **sampai** aturannya
#: di-commit, lalu `HEAD` memuat perbaikannya dan arah kedua menuntut HIJAU dari
#: gerbang yang justru sedang menguji cacat. Itu persis kelas cacat yang
#: menjatuhkan `main` di siklus Aturan 52: jangkar bergerak tanpa ada yang
#: menulis apa pun. Revisi tetap tidak bisa bergerak.
PRA = "4302081"  # `Aturan 52: daftar situs diturunkan…` — sebelum Aturan 63

#: Tabel keadaan, di **tingkat modul** dan bernama `STATES`.
#:
#: Kenapa di sini, bukan di dalam `main()`: `Tools/check-jangkar-harness.py`
#: membaca tabel keadaan tingkat modul untuk mengetahui pasangan (jangkar,
#: pengganti) yang bisa **tertinggal di sumber produksi** bila harness ini
#: dihentikan di tengah. Tabel yang hidup di dalam fungsi terbaca sebagai
#: "nol jangkar", dan gerbangnya lalu menuduh harness ini buta — merah pada
#: pohon bersih. Nama `STATES` juga bagian dari kontraknya, bukan selera.
#:
#: Bentuk `(label, [(cari, ganti), …], harus_merah)`; `harus_merah = False`
#: adalah kontrol negatif (pohon apa adanya), dan ia tidak ikut dijalankan di
#: arah kedua.
STATES = [
    ("1 radius samaran Swift = 0", [(RADIUS_BENAR, RADIUS_NOL)], True),
    ("2 opasitas samaran = 1.0", [(OPACITY_BENAR, OPACITY_SATU)], True),
    ("3 radius Swift menyimpang dari port Python",
     [(RADIUS_BENAR, RADIUS_LAIN)], True),
    ("4 kontrol negatif: pohon apa adanya", [], False),
]


def _baca_lint(rev):
    hasil = subprocess.run(["git", "show", f"{rev}:swift-ui-lint.sh"],
                           cwd=ROOT, capture_output=True, text=True)
    return hasil.stdout if hasil.returncode == 0 else None


def _program(teks):
    awal = teks.find("# ── Aturan 63")
    if awal < 0:
        return None
    sisa = teks[awal + 10:]
    akhir = -1
    for penanda in ("# ── Aturan ", 'if [ "$status" -eq 0 ]; then'):
        pos = sisa.find(penanda)
        if pos >= 0 and (akhir < 0 or pos < akhir):
            akhir = pos
    if akhir < 0:
        return None
    return teks[awal:awal + 10 + akhir]


def _jalankan(program):
    skrip = "status=0\n" + program + "\nprintf 'STATUS:%s\\n' \"$status\"\n"
    hasil = subprocess.run(["bash", "-s"], cwd=ROOT, input=skrip,
                           capture_output=True, text=True, timeout=600)
    if hasil.returncode != 0:
        return None, (hasil.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    return "STATUS:1" in hasil.stdout, hasil.stdout.strip()


def _jalankan_lint_lama(teks_lint):
    """Jalankan lint pra-perbaikan **utuh**, dari salinan sementara.

    Arah kedua tidak bisa memakai `_program` di sini: revisi pra-perbaikan
    belum punya blok Aturan 63 sama sekali, jadi tidak ada yang bisa dipotong.
    Yang harus dibuktikan justru sebaliknya — bahwa **seluruh** lint lama
    melaporkan LULUS atas mutasi yang sekarang memerah. Kalau ia sudah memerah
    sendiri (karena mutasi menyentuh aturan lain), keadaan itu tidak
    membuktikan apa pun tentang aturan baru ini.
    """
    salinan = os.path.join(ROOT, ".lint-pra-63.sh")
    try:
        with open(salinan, "w", encoding="utf-8") as berkas:
            berkas.write(teks_lint)
        os.chmod(salinan, 0o755)
        hasil = subprocess.run(["bash", salinan], cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        return hasil.returncode != 0, hasil.stdout.strip()
    finally:
        if os.path.exists(salinan):
            os.remove(salinan)


def main():
    mutasi_sumber.require_clean_sources([VIEW])
    asli = open(VIEW, encoding="utf-8").read()

    for nama, jangkar in (("RADIUS_BENAR", RADIUS_BENAR),
                          ("OPACITY_BENAR", OPACITY_BENAR)):
        jumlah = asli.count(jangkar)
        if jumlah != 1:
            print(f"GERBANG: jangkar {nama} muncul {jumlah}x, harus 1 -- "
                  "harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    program = _program(open(LINT, encoding="utf-8").read())
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 63 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    lint_lama = _baca_lint(PRA)
    if lint_lama is None:
        print("GERBANG: lint pra-perbaikan tidak terbaca -- arah kedua tidak "
              "bisa dijalankan.", file=sys.stderr)
        sys.exit(2)

    salah = 0
    try:
        print("── Aturan 63 sekarang ──")
        for label, mutasi, harap in STATES:
            isi = asli
            for cari, ganti in mutasi:
                if cari not in isi:
                    print(f"JANGKAR TIDAK DITEMUKAN: {label}")
                    salah += 1
                    isi = None
                    break
                isi = isi.replace(cari, ganti, 1)
            if isi is None:
                continue
            mutasi_sumber.write_source(VIEW, isi)
            menyala, detail = _jalankan(program)
            if menyala is None:
                print(f"PROBE GAGAL: {label}: {detail}")
                salah += 1
                continue
            ok = menyala == harap
            salah += 0 if ok else 1
            print(f"{'OK   ' if ok else 'SALAH'} {label:46s} "
                  f"{'MERAH' if menyala else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")

        print("\n── arah kedua: lint pra-perbaikan (wajib HIJAU) ──")
        for label, mutasi, harap in STATES:
            if not harap:
                continue
            isi = asli
            for cari, ganti in mutasi:
                if cari not in isi:
                    isi = None
                    break
                isi = isi.replace(cari, ganti, 1)
            if isi is None:
                continue
            mutasi_sumber.write_source(VIEW, isi)
            menyala, detail = _jalankan_lint_lama(lint_lama)
            if menyala is None:
                print(f"PROBE GAGAL: {label}: {detail}")
                salah += 1
                continue
            ok = not menyala
            salah += 0 if ok else 1
            print(f"{'OK   ' if ok else 'SALAH'} pra: {label:40s} "
                  f"{'MERAH' if menyala else 'hijau'}")
    finally:
        mutasi_sumber.write_source(VIEW, asli)

    print()
    if salah:
        print(f"{salah} keadaan tidak sesuai harapan")
        sys.exit(1)
    print("0 keadaan tidak sesuai harapan")


if __name__ == "__main__":
    main()
