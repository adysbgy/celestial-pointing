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
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402
LINT = os.path.join(ROOT, "swift-ui-lint.sh")
TARGET = os.path.join("Apps", "Shared", "CelestialVisualView.swift")

#: Jangkar: bentuk SAH yang dipakai pohon hari ini. Harus muncul **tepat
#: sekali**; nol berarti berkasnya berubah dan harness tidak lagi mengukur
#: cacat yang diklaimnya.
#:
#: Jangkar ini dua kali harus dipindah, dan sebabnya sama: ia menempel pada
#: baris yang **memang dipakai** untuk membaca nama, sehingga setiap kali
#: pembacaan itu ditulis ulang, harness berhenti di gerbangnya sendiri
#: (`exit 2`) dan berhenti membuktikan apa pun — diam, bukan merah.
#:
#:   * `for band in CelestialVisual.jupiterBands()` — hilang sejak `d5bf654`.
#:   * pembacaan tetangga pita `allBands[(index ± 1) …]` — **tidak bisa
#:     dipakai**, karena loop pita berisi loop `edges` yang mengurai `index`
#:     juga. Aturan 73 memindai seluruh badan loop luar, jadi `index` dari
#:     loop dalam terbaca sebagai "dipakai" dan mutasinya hijau. Terukur:
#:     badan loop pita dimutasi sampai `index` benar-benar mati, Aturan 73
#:     tetap melaporkan "6 loop berpasangan, semua nama yang diurai dipakai".
#:     Gerbangnya benar; jangkarnya yang salah tempat.
#:
#: Yang dipakai sekarang: loop maria di `drawMoonSurfaceShading`. Di sana
#: `index` dibaca **tepat satu kali** dan tidak ada loop dalam yang menutupinya.
ANCHOR = "let ripple = index < mariaRipple.count ? mariaRipple[index] : (0, 0)"

#: Mutasi: `index` tetap diurai dari pasangan tetapi berhenti dibaca. Bentuk
#: yang paling dekat dengan cacat aslinya (`aaba2d4`): kepala loop tidak
#: berubah, hanya badannya yang berhenti memakai nama itu — dan itulah yang
#: memerahkan Apple Build sebagai `immutable value 'index' was never used`.
MUTASI = "let ripple = mariaRipple.first ?? (0, 0)"

#: Mutasi keadaan `_`: pembuangan yang **sengaja**. `_` hanya sah kalau tidak
#: ada yang membacanya, jadi namanya ikut hilang dari kepala loop.
PEMBUANGAN = "let ripple = mariaRipple.first ?? (0, 0)"

#: Jangkar kepala loop. Keadaan 1 dan keadaan 3 memakai badan yang sama
#: persis; yang membedakan keduanya hanya apakah `index` masih diurai.
#: Tanpa jangkar ini, "nama tak dipakai" tidak bisa dibedakan dari "nama
#: tidak ada" — dan hanya yang pertama dilaporkan compiler.
ANCHOR_KEPALA = "for (index, blob) in maria.enumerated() {"
KEPALA_TETAP = ANCHOR_KEPALA
KEPALA_BUANG = "for (_, blob) in maria.enumerated() {"

#: Penanda aturan di naskah gerbang; tanpa ini Aturan 73 belum diterapkan.
RULE_MARK = "Aturan 73: nama yang diurai dari sebuah pasangan wajib dipakai"


def commit_pengenal(penanda):
    """Commit yang pertama kali memuat `penanda` di swift-ui-lint.sh.

    `git log -S` mencocokkan perubahan jumlah kemunculan, jadi entri terakhir
    (paling tua) adalah commit yang menambahkannya. `None` berarti penanda
    tidak pernah masuk riwayat -- non-vakuitas tidak bisa dibuktikan.
    """
    proc = mutasi_sumber._git(["log", "--format=%H", "-S", penanda, "--", "swift-ui-lint.sh"])
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

        # Keadaan 1: nama diurai dari pasangan lalu tidak dipakai. Kepala loop
        # **tetap** mengurai `index`; hanya badannya berhenti membacanya.
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(ANCHOR, MUTASI).replace(
                ANCHOR_KEPALA, KEPALA_TETAP))
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
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(ANCHOR, PEMBUANGAN).replace(
                ANCHOR_KEPALA, KEPALA_BUANG))
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
        proc = mutasi_sumber._git(["show", f"{commit_pengenal(RULE_MARK)}^:swift-ui-lint.sh"])
        if proc.returncode != 0 or not proc.stdout.strip():
            print("SALAH aturan pra-perbaikan tidak terbaca dari git -- "
                  "non-vakuitas tidak bisa dibuktikan.")
            hasil.append(False)
        else:
            with open(lama, "w", encoding="utf-8") as handle:
                handle.write(proc.stdout)
            def jalankan_lama(teks_lint, _kerja=kerja, _lama=lama):
                with open(_lama, "w", encoding="utf-8") as handle:
                    handle.write(teks_lint)
                return jalankan_lint(_kerja, "lint-lama.sh")

            def terapkan(_sasaran=sasaran, _isi=isi):
                # `False` bila jangkarnya hilang: mutasi yang tidak pernah terpasang
                # membuat kedua pengukuran identik, dan itu hijau yang paling kosong.
                baru = _isi.replace(ANCHOR, MUTASI)
                if baru == _isi:
                    return False
                with open(_sasaran, "w", encoding="utf-8") as handle:
                    handle.write(baru)
                return True

            def pulihkan(_sasaran=sasaran, _isi=isi):
                with open(_sasaran, "w", encoding="utf-8") as handle:
                    handle.write(_isi)

            buta, sebelum, sesudah = mutasi_sumber.arah_kedua_buta_di_pohon_salinan(
                jalankan_lama, proc.stdout, terapkan, pulihkan)
            if buta is None:
                print("SALAH aturan pra-perbaikan: jangkar mutasi tidak ditemukan")
                hasil.append(False)
            else:
                print(f"{'OK  ' if buta else 'SALAH'} aturan pra-perbaikan   -> "
                      f"merah {sorted(sebelum)} -> {sorted(sesudah)} "
                      f"(harap sama = dulu buta)")
                hasil.append(buta)
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
