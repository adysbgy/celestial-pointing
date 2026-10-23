#!/usr/bin/env python3
"""Buktikan ukuran gambar objek dijaga di **kedua sisi**: pemanggil dan token.

Kenapa berkas ini ada
=====================

Seluruh misi produk ini adalah pengguna **mengenali** objek dari bentuknya —
pita Jupiter, cincin Saturnus, kutub Mars. Gambar yang terlalu kecil untuk
memperlihatkan itu tetap lolos setiap gerbang lain: ia menggambar sesuatu, ia
memakai keyakinan yang benar, ia disamarkan saat ragu. Yang hilang hanya
keterbacaannya, dan tidak ada teks di layar yang bisa membantahnya.

Terukur pada pohon utuh, proses baru, seluruh **63** aturan hijau:

    PointingView.swift      diameter: visualDiameter -> diameter: 1    exit 0
    PointingView.swift      diameter: visualDiameter -> diameter: 0    exit 0
    DiagnosticsView.swift   diameter: visualDiameter -> diameter: 1    exit 0
    WatchTheme.swift        visualDiameter 38 -> 16                    exit 0
    PointingView.swift      = WatchMetrics.visualDiameter -> = 38      exit 0

Empat yang pertama sudah ditutup `check-visuals.py`
(`check_drawn_visual_sizes_keep_features`) dan Aturan 64. Yang terakhir
adalah celah **berbeda**: nilai bawaan parameter. Ia tidak menyentuh satu pun
pemanggilan, jadi gerbang pemanggil tetap hijau, dan ia tidak menyentuh token,
jadi pengukuran token juga tetap hijau — tetapi setiap `#Preview` dan setiap
pemakaian baru mewarisi angka yang tidak dibaca siapa pun.

Yang diuji
==========

  1. pemanggil menulis literal (`diameter: 1`)        MERAH
  2. nilai bawaan parameter jadi literal (`= 38`)     MERAH
  3. token `WatchMetrics.visualDiameter` hilang       MERAH
  4. kontrol negatif: pohon apa adanya                hijau

Keadaan 3 penting dan mudah terlewat. Kalau tokennya berganti nama, gerbang
pemanggil tetap hijau — ia hanya memeriksa bahwa yang diteruskan **bukan
literal**, dan sebuah nama tetap nama. Tanpa keadaan 3, aturan ini bisa
menjadi hijau abadi sementara tidak ada lagi satu tempat yang menentukan
ukuran gambar.

Arah kedua
==========

Ketiga keadaan cacat dijalankan lagi atas lint pra-perbaikan (`git show`,
bukan dikarang) dan wajib HIJAU di sana.

Yang TIDAK dibuktikan
=====================

Aturan ini menjaga **asal angka**, bukan nilai estetiknya: ia tidak
membuktikan 38 pt adalah ukuran yang tepat, dan tidak membuktikan gambar
benar-benar digambar pada ukuran itu (itu wilayah Aturan 52/60 dan
`check-visuals.py`). Ia juga tidak membaca pemanggil yang **tidak** menyebut
`diameter:` sama sekali — pemanggil seperti itu memakai nilai bawaan, dan
nilai bawaan itulah yang dijaga keadaan 2.
"""

from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
POINTING = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                        "PointingView.swift")
THEME = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "WatchTheme.swift")

RULE_HEADER = "== Aturan 64:"
CLEAN_MARK = "Bersih: "

PEMANGGIL_BENAR = "diameter: visualDiameter,"
PEMANGGIL_NOL = "diameter: 1,"

BAWAAN_BENAR = "var visualDiameter: CGFloat = WatchMetrics.visualDiameter"
BAWAAN_LITERAL = "var visualDiameter: CGFloat = 38"

TOKEN_BENAR = "static let visualDiameter: CGFloat = 38"
TOKEN_HILANG = "static let lebarGambar: CGFloat = 38"

#: Jumlah aturan sebelum dan sesudah Aturan 64 ditambahkan. Dipakai arah kedua
#: untuk mengembalikan README ke hitungan lama selama lint lama dijalankan —
#: Aturan 10 membaca angka itu dari README.
JUMLAH_ATURAN_KINI = 64
JUMLAH_ATURAN_LAMA = 63

#: Revisi **pra-perbaikan** untuk arah kedua: commit terakhir yang belum punya
#: blok Aturan 64.
#:
#: Kenapa bukan `HEAD`. `HEAD` bergerak setiap kali aturannya di-commit, dan
#: arah kedua lalu menuntut HIJAU dari gerbang yang justru sedang menguji
#: cacat. Kelas cacat ini sudah menjatuhkan `main` di siklus Aturan 52.
PRA = "276e6ec"  # `Aturan 63: …` — sebelum Aturan 64

#: Tabel keadaan, di **tingkat modul** dan bernama `STATES`.
#:
#: `Tools/check-jangkar-harness.py` membaca tabel tingkat modul untuk tahu
#: pasangan (jangkar, pengganti) yang bisa tertinggal di sumber produksi bila
#: harness ini dihentikan di tengah. Tabel di dalam fungsi terbaca sebagai
#: "nol jangkar", dan gerbangnya menuduh harness ini buta — merah pada pohon
#: bersih.
#:
#: Bentuk `(label, [(berkas, cari, ganti), …], harus_merah)`.
STATES = [
    ("1 pemanggil menulis literal", [(POINTING, PEMANGGIL_BENAR, PEMANGGIL_NOL)], True),
    ("2 nilai bawaan parameter jadi literal",
     [(POINTING, BAWAAN_BENAR, BAWAAN_LITERAL)], True),
    ("3 token WatchMetrics hilang", [(THEME, TOKEN_BENAR, TOKEN_HILANG)], True),
    ("4 kontrol negatif: pohon apa adanya", [], False),
]

BERKAS = (POINTING, THEME)


def _baca_lint(rev):
    hasil = mutasi_sumber._git(["show", f"{rev}:swift-ui-lint.sh"])
    return hasil.stdout if hasil.returncode == 0 else None


def _program(teks):
    awal = teks.find("# ── Aturan 64")
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
    """Jalankan lint pra-perbaikan **utuh**, kembalikan (exit!=0, stdout).

    Dipertahankan sebagai pembungkus tipis di atas
    `mutasi_sumber.jalankan_lint`. Arah kedua tidak memotong blok dari lint
    lama — revisi itu belum punya blok Aturan 64 sama sekali — jadi yang
    dijalankan memang seluruh lint lama.

    **Kenapa `swift-ui-lint.sh` dan `README.md` tidak lagi ditukar di sini.**
    Dulu keduanya ditulis ulang: lint lama dibaca Aturan 10 **dari cakram**,
    dan hitungan aturannya dibandingkan dengan angka di README (lint lama
    punya 63, README baru bilang 64). Itu perlu karena syarat lama
    adalah lint lama harus **HIJAU** secara mutlak, sehingga selisih hitungan
    saja sudah memerahkannya.

    Syarat itu sudah dibuang (lihat `mutasi_sumber.arah_kedua_buta`): yang
    dibandingkan sekarang adalah **putusan** lint lama atas pohon bersih dan
    atas pohon termutasi. Aturan 10 memerah pada **kedua** pengukuran dengan
    angka yang sama, jadi ia tidak bisa menyamar sebagai "gerbang lama
    menangkap cacat ini", dan penukaran README tidak lagi mengubah apa pun.
    Menukarnya tetap dilakukan berarti menguji lint yang berbeda dari yang
    benar-benar ada di revisi itu — persis jenis selisih yang membuat arah
    kedua membusuk diam-diam.

    **Yang TIDAK diklaim.** Pembungkus ini tidak membuktikan lint lama hijau
    pada pohon hari ini; ia hanya menjalankannya. Kesimpulannya ada di
    `arah_kedua_buta`, dan kesimpulan itu berbunyi "gerbang lama tidak
    berubah pikiran", bukan "gerbang lama bersih".
    """
    return mutasi_sumber.jalankan_lint(teks_lint, ROOT)

def main():
    mutasi_sumber.require_clean_sources(list(BERKAS))
    asli = {jalur: open(jalur, encoding="utf-8").read() for jalur in BERKAS}

    for nama, jalur, jangkar in (("PEMANGGIL_BENAR", POINTING, PEMANGGIL_BENAR),
                                 ("BAWAAN_BENAR", POINTING, BAWAAN_BENAR),
                                 ("TOKEN_BENAR", THEME, TOKEN_BENAR)):
        jumlah = asli[jalur].count(jangkar)
        if jumlah != 1:
            print(f"GERBANG: jangkar {nama} muncul {jumlah}x, harus 1 -- "
                  "harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    program = _program(open(LINT, encoding="utf-8").read())
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 64 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    lint_lama = _baca_lint(PRA)
    if lint_lama is None:
        print("GERBANG: lint pra-perbaikan tidak terbaca -- arah kedua tidak "
              "bisa dijalankan.", file=sys.stderr)
        sys.exit(2)

    def terapkan(mutasi):
        isi = dict(asli)
        for jalur, cari, ganti in mutasi:
            if cari not in isi[jalur]:
                return None
            isi[jalur] = isi[jalur].replace(cari, ganti, 1)
        for jalur in BERKAS:
            mutasi_sumber.write_source(jalur, isi[jalur])
        return isi

    salah = 0
    try:
        print("── Aturan 64 sekarang ──")
        for label, mutasi, harap in STATES:
            if terapkan(mutasi) is None:
                print(f"JANGKAR TIDAK DITEMUKAN: {label}")
                salah += 1
                continue
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

        print("\n── arah kedua: gerbang lama buta pada mutasi yang sama ──")
        # Syaratnya bukan "lint lama HIJAU" (itu membusuk: lint lama memeriksa
        # seluruh `Apps/`, dan `Apps/` berubah sesudah revisi itu di-commit).
        # Yang diuji: apakah mutasi ini **mengubah putusan** gerbang lama.
        # Himpunan aturan yang memerah dibandingkan sebelum dan sesudah.
        for label, mutasi, harap in STATES:
            if not harap:
                continue
            if terapkan(mutasi) is None:
                continue
            buta, sebelum, sesudah = mutasi_sumber.arah_kedua_buta(
                lint_lama, ROOT,
                lambda: [mutasi_sumber.write_source(j, asli[j]) for j in BERKAS],
                lambda m=mutasi: terapkan(m) is not None)
            if buta is None:
                print(f"JANGKAR TIDAK DITEMUKAN: pra: {label}")
                salah += 1
                continue
            salah += 0 if buta else 1
            print(f"{'OK   ' if buta else 'SALAH'} pra: {label:40s} "
                  f"merah {sorted(sebelum)} -> {sorted(sesudah)}")
    finally:
        for jalur in BERKAS:
            mutasi_sumber.write_source(jalur, asli[jalur])

    print()
    if salah:
        print(f"{salah} keadaan tidak sesuai harapan")
        sys.exit(1)
    print("0 keadaan tidak sesuai harapan")


if __name__ == "__main__":
    main()
