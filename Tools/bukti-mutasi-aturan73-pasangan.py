#!/usr/bin/env python3
"""Buktikan Aturan 73 berbunyi: nama yang diurai dari sebuah pasangan wajib dipakai.

Aturan 73 menutup kelas cacat yang **terukur**, bukan diklaim.

`aaba2d4` ("Pita Jupiter: naungan bola dipotong ke tiap pita") mengganti loop
pita Jupiter dari `bands.enumerated()` menjadi iterasi langsung, tetapi
membiarkan pengurai pasangannya:

    for (index, band) in bands.enumerated() {

`index` tidak lagi dibaca di badan loop -- dan itu **peringatan compiler**:

    Apps/Shared/CelestialVisualView.swift:487:14: warning:
        immutable value 'index' was never used; consider replacing with '_' ...

`ios-build.yml` punya gerbang "Peringatan compiler (kode sendiri)" yang
memerahkan build karena peringatan ini. Terukur: **Apple Build MERAH**
(`39352810184`) pada commit itu, sementara seluruh gerbang lokal hijau.

Kenapa sebelumnya tidak terlihat. Tiga lapis, dan ketiganya buta dengan cara
berbeda:

  * `swift-ui-lint.sh` membaca **teks** `Apps/`, dan nol dari 72 aturannya
    membaca pemakaian nama di dalam badan loop. Terukur: pohon yang sama,
    proses baru, Aturan 73 belum ada -> exit 0.
  * `swift-typecheck.sh` hanya `-parse` berkas SwiftUI; `swiftc -parse`
    memeriksa sintaks, bukan pemakaian nama.
  * `Apps/` **tidak pernah dibangun** `swift-test.sh` di Linux. Peringatan
    compiler hanya bisa dilihat runner macOS, satu siklus penuh kemudian.

Jadi cacatnya bukan "bug Jupiter": ia kelas yang menjatuhkan `main` lewat satu
nama sisa, dan biayanya satu siklus CI (~4 menit build + giliran antrean)
setiap kali.

Bentuk yang diputuskan, dan yang **sengaja tidak** diputuskan. Versi pertama
detektornya ikut memeriksa `if let`/`guard let` tanpa penugasan, dan itu
melaporkan **7 temuan pada kode yang benar**: ketujuhnya memakai nama yang
sama di klausa lanjutan atau di kondisi, bukan di badan kurung kurawal
(`guard let session, session.activationState != .activated else { return }`).
Gerbang yang menuduh kode benar akan dimatikan orang. Karena itu Aturan 73
hanya memutuskan yang benar-benar bisa diputuskan dari teks: **loop `for`
dengan pasangan** -- di sana badan loop adalah satu-satunya tempat nama itu
bisa dipakai.

Empat keadaan, dan ketiganya harus benar sekaligus:

  1. mutasi `for (_, band)` -> `for (index, band)` -> Aturan 73 wajib MERAH
     dan wajib menyebut `index`.
  2. kontrol negatif (pohon utuh) -> wajib HIJAU. Tanpa ini, aturan yang
     selalu merah akan lulus keadaan 1 tanpa membuktikan apa pun.
  3. `_` sebagai pembuangan SAH -> wajib HIJAU. `_` memang cara menyatakan
     "bagian ini tidak saya pakai"; aturan yang menolaknya akan memerahkan
     kode idiomatik.
  4. aturan pra-perbaikan (induk commit yang MEMPERKENALKAN aturan ini) pada mutasi yang
     **sama** -> wajib HIJAU. Ini bukti non-vakuitas: kalau lint lama juga
     merah di sini, cacat ini sudah terjaga dan Aturan 73 tidak menambah apa
     pun.

Keadaan dijalankan dari salinan pohon kerja di direktori sementara supaya
berkas repo tidak pernah tersentuh; `swift-ui-lint.sh` dijalankan sebagai
skrip, bukan diimpor, karena ia memang gerbang teks -- dan gerbang yang tidak
pernah dieksekusi selalu hijau.

Pakai:
    python3 Tools/bukti-mutasi-aturan73-pasangan.py   # 0 = sesuai
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")
TARGET = os.path.join("Apps", "Shared", "CelestialVisualView.swift")

#: Jangkar: bentuk SAH yang dipakai pohon hari ini. Harus muncul **tepat
#: sekali**; nol berarti berkasnya berubah dan harness tidak lagi mengukur
#: cacat yang diklaimnya.
ANCHOR = "for band in CelestialVisual.jupiterBands()"
#: Mutasi: nama yang diurai tetapi tidak dipakai -- persis yang ada di
#: `aaba2d4` dan yang memerahkan Apple Build.
MUTASI = ("let bands = CelestialVisual.jupiterBands()\n"
          "        for (index, band) in bands.enumerated()")

#: Penanda aturan di naskah gerbang; tanpa ini Aturan 73 belum diterapkan.
RULE_MARK = "Aturan 73: nama yang diurai dari sebuah pasangan wajib dipakai"


def commit_pengenal(penanda):
    """Commit yang pertama kali memuat `penanda` di swift-ui-lint.sh.

    `git log -S` mencocokkan perubahan jumlah kemunculan, jadi entri terakhir
    (paling tua) adalah commit yang menambahkannya. `None` berarti penanda
    tidak pernah masuk riwayat -- non-vakuitas tidak bisa dibuktikan.
    """
    proc = subprocess.run(
        ["git", "log", "--format=%H", "-S", penanda, "--", "swift-ui-lint.sh"],
        capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None
    baris = [b for b in proc.stdout.split() if b]
    return baris[-1] if baris else None


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


def main():
    print("Aturan 73: nama yang diurai dari sebuah pasangan juga dipakai\n")

    teks = open(LINT, encoding="utf-8").read()
    if RULE_MARK not in teks:
        print("GAGAL: penanda Aturan 73 tidak ada di swift-ui-lint.sh -- "
              "aturan belum diterapkan, harness ini tidak boleh hijau.")
        return 2

    asal = os.path.join(ROOT, TARGET)
    isi = open(asal, encoding="utf-8").read()
    jumlah = isi.count(ANCHOR)
    if jumlah != 1:
        print(f"GAGAL: jangkar muncul {jumlah}x di {TARGET} (harus 1). "
              "Berkasnya berubah; harness ini tidak lagi mengukur cacat yang "
              "diklaimnya.")
        return 2

    kerja = tempfile.mkdtemp(prefix="aturan73-")
    hasil = []
    try:
        salin_pohon(kerja)
        sasaran = os.path.join(kerja, TARGET)

        # Keadaan 2 lebih dulu: pohon utuh wajib hijau. Kalau tidak, merah pada
        # keadaan 1 tidak membedakan apa pun.
        keluar, out = jalankan_lint(kerja)
        ok = keluar == 0
        print(f"{'OK  ' if ok else 'SALAH'} pohon utuh            -> "
              f"{'hijau' if ok else 'MERAH'} (harap hijau)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 1: nama diurai dari pasangan lalu tidak dipakai.
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(ANCHOR, MUTASI))
        keluar, out = jalankan_lint(kerja)
        menyebut = "index" in out
        ok = keluar != 0 and menyebut
        print(f"{'OK  ' if ok else 'SALAH'} nama tak dipakai       -> "
              f"{'MERAH' if keluar else 'hijau'}"
              f"{', menyebut index' if menyebut else ', TIDAK menyebut index'}"
              " (harap MERAH + menyebut)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 3: `_` sebagai pembuangan adalah bentuk sah, wajib hijau.
        pembuangan = ("let bands = CelestialVisual.jupiterBands()\n"
                      "        for (_, band) in bands.enumerated()")
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(ANCHOR, pembuangan))
        keluar, out = jalankan_lint(kerja)
        ok = keluar == 0
        print(f"{'OK  ' if ok else 'SALAH'} `_` pembuangan sah     -> "
              f"{'hijau' if ok else 'MERAH'} (harap hijau)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 4: aturan pra-perbaikan pada mutasi yang sama wajib hijau.
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(ANCHOR, MUTASI))
        lama = os.path.join(kerja, "lint-lama.sh")
        # Pra-perbaikan = induk commit yang MEMPERKENALKAN aturan ini, bukan
        # HEAD. HEAD bergerak maju sesudah aturan mendarat; begitu ia memuat
        # aturan ini sendiri, "HEAD" berhenti berarti "sebelum aturan ini" dan
        # keadaan ini berbalik jadi lawannya tanpa satu baris pun diubah.
        proc = subprocess.run(
            ["git", "show", f"{commit_pengenal(RULE_MARK)}^:swift-ui-lint.sh"],
            capture_output=True, text=True, cwd=ROOT)
        if proc.returncode != 0 or not proc.stdout.strip():
            print("SALAH aturan pra-perbaikan tidak terbaca dari git -- "
                  "non-vakuitas tidak bisa dibuktikan.")
            hasil.append(False)
        else:
            with open(lama, "w", encoding="utf-8") as handle:
                handle.write(proc.stdout)
            keluar, out = jalankan_lint(kerja, "lint-lama.sh")
            ok = keluar == 0
            print(f"{'OK  ' if ok else 'SALAH'} aturan pra-perbaikan   -> "
                  f"{'hijau' if ok else 'MERAH'} pada mutasi yang sama "
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
