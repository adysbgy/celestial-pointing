#!/usr/bin/env python3
"""Buktikan Aturan 75 berbunyi: ikon complication wajib membaca umur cuplikan.

Aturan 75 menutup kelas cacat yang **terukur**, bukan diklaim.

`ComplicationWidget` menggambar lima cabang complication, dan keempat yang
menampilkan nama objek (`accessoryInline`, `accessoryCircular`,
`accessoryRectangular`, `accessoryCorner`, plus `default`) memakai ikon dari
`digest.presentedSymbolName(at: Date())`. Varian `at:` itu yang memutuskan
apakah cuplikan sudah basi, dan menggeser ikon lock/ragu yang kedaluwarsa
menjadi `clock.badge.exclamationmark`.

Model sudah benar dan sudah diuji di Linux:
`Packages/PointingKit/Tests/.../ComplicationStaleSymbolTests.swift`
menyatakan bentuk tanpa waktu kedaluwarsa. Yang tidak dijaga satu pun gerbang
adalah **pemakaiannya di view**. Aturan 23 (`setiap cabang complication
memakai kanal ikon`) hanya menuntut sebuah `presentedSymbolName` muncul di
cabang -- bentuk tanpa `at:` lulus di sana.

Terukur pada salinan utuh repo ini, proses baru, sebelum Aturan 75 ada --
mengganti kelima `presentedSymbolName(at: Date())` menjadi bentuk tanpa waktu
membiarkan seluruh aturan yang ada saat itu lulus (exit 0), sementara centang
hijau "kunci berhasil" kini berdiri di pergelangan berjam-jam sesudah
pandangan pengguna berpindah. Complication hanya menerima cuplikan baru saat
ada perubahan, jadi ia memang tempat di mana "basi" paling lama bertahan.

Kenapa ini bukan cacat kosmetik: yang dibaca pengguna di pergelangan bukan
angka, melainkan **apakah jam masih mengenali langitnya**. Ikon hijau yang
tidak tahu umurnya adalah false confidence dalam bentuk paling ringkas.

Empat keadaan, dan keempatnya harus benar sekaligus:

  1. pohon utuh -> HIJAU. Tanpa ini, aturan yang selalu merah akan lulus
     keadaan 2 tanpa membuktikan apa pun.
  2. kelima panggilan diganti bentuk tanpa waktu -> MERAH, dan pesannya wajib
     menyebut `presentedSymbolName` beserta sebabnya.
  3. satu cabang saja (`accessoryCircular`) dikembalikan ke bentuk tanpa
     waktu -> MERAH. Ini memisahkan "membaca cabang" dari "menghitung
     occurrence di berkas": gerbang yang hanya mencocokkan tulisan akan hijau
     di sini karena empat panggilan lain masih benar.
  4. aturan pra-perbaikan pada mutasi yang **sama** -> HIJAU. Bukti
     non-vakuitas: kalau lint lama sudah merah di sini, cacat ini sudah
     terjaga dan Aturan 75 tidak menambah apa pun.

Keadaan 4 mengambil aturan pra-perbaikan dari commit **yang memperkenalkan
Aturan 75** (`git log -S <penanda>` -> `^`), bukan dari `HEAD`. HEAD bergerak
maju sesudah aturan ini mendarat, dan begitu ia memuat aturan ini sendiri,
"HEAD" berhenti berarti "sebelum aturan ini" -- janji di atas berubah jadi
lawan dari dirinya tanpa satu baris pun diubah. Lima harness Aturan 70-74
sempat patah persis begitu, dan itu terbaca sebagai "aturan lama sudah merah"
padahal yang salah hanya jangkarnya.

Pakai:
    python3 Tools/bukti-mutasi-aturan75-ikon-umur.py   # 0 = sesuai
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

TARGET = os.path.join("Apps", "PointAndKnowWatch", "Complications",
                      "ComplicationWidget.swift")

#: Bentuk yang diterima gerbang hari ini (varian yang membaca waktu).
WAKTU = "presentedSymbolName(at: Date())"
#: Mutasi: bentuk tanpa waktu -- tipe tetap sah (`public var`), jadi tidak ada
#: compiler yang melihatnya, tetapi ikonnya berhenti tahu umur cuplikan.
TANPA_WAKTU = "presentedSymbolName"

#: Penanda aturan di naskah gerbang; tanpa ini Aturan 75 belum diterapkan.
RULE_MARK = ("Aturan 75: ikon complication wajib membaca umur cuplikan "
             "(presentedSymbolName(at:))")

#: Jumlah panggilan yang wajib ikut bermutasi di keadaan 2. Nol berarti
#: berkasnya berubah dan harness tidak lagi mengukur cacat yang diklaimnya.
HARAP_JANGKAR = 5


def jalankan_lint(cwd, skrip="swift-ui-lint.sh"):
    proc = subprocess.run(["bash", skrip], capture_output=True, text=True,
                          cwd=cwd, env=dict(os.environ, PYTHONWARNINGS="ignore"))
    return proc.returncode, proc.stdout + proc.stderr


def salin_pohon(tujuan):
    """Salin berkas yang dibutuhkan gerbang ke direktori sementara."""
    for nama in ("Apps", "Packages", "Tools", ".github"):
        asal = os.path.join(ROOT, nama)
        if os.path.isdir(asal):
            shutil.copytree(asal, os.path.join(tujuan, nama),
                            ignore=shutil.ignore_patterns(".build", "out"))
    for nama in ("swift-ui-lint.sh", "README.md", "project.yml", "STATUS.md"):
        asal = os.path.join(ROOT, nama)
        if os.path.isfile(asal):
            shutil.copy2(asal, os.path.join(tujuan, nama))


def commit_pengenal(penanda):
    """Commit yang pertama kali memuat `penanda` di swift-ui-lint.sh.

    `git log -S` mencocokkan perubahan jumlah kemunculan, jadi hasil pertama
    (terbaru) adalah commit yang menambahkannya. `None` berarti penanda tidak
    pernah masuk riwayat -- non-vakuitas tidak bisa dibuktikan.
    """
    proc = subprocess.run(
        ["git", "log", "--format=%H", "-S", penanda, "--", "swift-ui-lint.sh"],
        capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None
    baris = [b for b in proc.stdout.split() if b]
    # Yang terakhir = yang paling tua = yang memperkenalkan.
    return baris[-1] if baris else None


def mutasi_satu_cabang(isi):
    """Kembalikan `accessoryCircular` saja ke bentuk tanpa waktu.

    Cabang lain dibiarkan benar, jadi gerbang yang hanya menghitung
    kemunculan tulisan di berkas akan tetap hijau di sini.
    """
    pola = re.compile(
        r"(case\s+\.accessoryCircular\s*:.*?)"
        + re.escape(WAKTU),
        re.S)
    baru, jumlah = pola.subn(r"\1" + TANPA_WAKTU, isi, count=1)
    return baru if jumlah == 1 else None


def main():
    print("Aturan 75: ikon complication membaca umur cuplikan\n")

    teks = open(LINT, encoding="utf-8").read()
    if RULE_MARK not in teks:
        print("GAGAL: penanda Aturan 75 tidak ada di swift-ui-lint.sh -- "
              "aturan belum diterapkan, harness ini tidak boleh hijau.")
        return 2

    asal = os.path.join(ROOT, TARGET)
    isi = open(asal, encoding="utf-8").read()
    jumlah = isi.count(WAKTU)
    if jumlah != HARAP_JANGKAR:
        print(f"GAGAL: jangkar `{WAKTU}` muncul {jumlah}x di {TARGET} "
              f"(harus {HARAP_JANGKAR}). Berkasnya berubah; harness ini tidak "
              "lagi mengukur cacat yang diklaimnya.")
        return 2

    satu_cabang = mutasi_satu_cabang(isi)
    if satu_cabang is None:
        print("GAGAL: cabang `accessoryCircular` tidak terbaca -- keadaan 3 "
              "tidak bisa membedakan gerbang cabang dari pencocok tulisan.")
        return 2

    kerja = tempfile.mkdtemp(prefix="aturan75-")
    hasil = []
    try:
        salin_pohon(kerja)
        sasaran = os.path.join(kerja, TARGET)

        # Keadaan 1 lebih dulu: pohon utuh wajib hijau. Kalau tidak, merah
        # pada keadaan 2 tidak membedakan apa pun.
        keluar, out = jalankan_lint(kerja)
        ok = keluar == 0
        print(f"{'OK  ' if ok else 'SALAH'} pohon utuh                -> "
              f"{'hijau' if ok else 'MERAH'} (harap hijau)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 2: kelima panggilan kehilangan `at:`.
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(WAKTU, TANPA_WAKTU))
        keluar, out = jalankan_lint(kerja)
        menyebut = "presentedSymbolName" in out and "umur" in out
        ok = keluar != 0 and menyebut
        print(f"{'OK  ' if ok else 'SALAH'} ikon tanpa waktu (semua)  -> "
              f"{'MERAH' if keluar else 'hijau'}"
              f"{', menyebut sebab' if menyebut else ', TIDAK menyebut sebab'} "
              "(harap MERAH + menyebut)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 3: satu cabang saja yang buta umur. Gerbang yang membaca
        # **cabang** merah di sini; pencocok tulisan di berkas tidak.
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(satu_cabang)
        keluar, out = jalankan_lint(kerja)
        menyebut = "accessoryCircular" in out
        ok = keluar != 0 and menyebut
        print(f"{'OK  ' if ok else 'SALAH'} ikon tanpa waktu (1 cabang) -> "
              f"{'MERAH' if keluar else 'hijau'}"
              f"{', menyebut accessoryCircular' if menyebut else ''} "
              "(harap MERAH + menyebut)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 4: aturan pra-perbaikan pada mutasi keadaan 2 wajib hijau.
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(WAKTU, TANPA_WAKTU))
        pengenal = commit_pengenal(RULE_MARK)
        lama = os.path.join(kerja, "lint-lama.sh")
        if not pengenal:
            print("SALAH aturan pra-perbaikan tidak terlacak dari git -- "
                  "non-vakuitas tidak bisa dibuktikan.")
            hasil.append(False)
        else:
            proc = subprocess.run(
                ["git", "show", f"{pengenal}^:swift-ui-lint.sh"],
                capture_output=True, text=True, cwd=ROOT)
            if proc.returncode != 0 or not proc.stdout.strip():
                print(f"SALAH induk {pengenal[:8]}^ tidak terbaca -- "
                      "non-vakuitas tidak bisa dibuktikan.")
                hasil.append(False)
            else:
                if RULE_MARK in proc.stdout:
                    print("SALAH 'pra-perbaikan' ternyata sudah memuat "
                          "Aturan 75 -- jangkarnya salah, keadaan ini tidak "
                          "membuktikan apa pun.")
                    hasil.append(False)
                else:
                    with open(lama, "w", encoding="utf-8") as handle:
                        handle.write(proc.stdout)
                    keluar, out = jalankan_lint(kerja, "lint-lama.sh")
                    ok = keluar == 0
                    print(f"{'OK  ' if ok else 'SALAH'} aturan pra-perbaikan "
                          f"({pengenal[:8]}^) -> {'hijau' if ok else 'MERAH'} "
                          "pada mutasi yang sama "
                          "(harap hijau = dulu buta)")
                    if not ok:
                        for baris in out.strip().splitlines()[-8:]:
                            print(f"       {baris}")
                    hasil.append(ok)
    finally:
        shutil.rmtree(kerja, ignore_errors=True)

    print()
    if not all(hasil):
        print(f"{hasil.count(False)} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(hasil)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
