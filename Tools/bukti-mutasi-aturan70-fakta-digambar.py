#!/usr/bin/env python3
"""Buktikan Aturan 70 berbunyi: fakta yang diucapkan layar redup wajib digambar.

Aturan 70 menutup celah yang **terukur**, bukan diklaim.

Di `Apps/PointAndKnowWatch/Sources/ReducedLuminanceView.swift` setiap fakta
punya **dua saluran**: ia digambar sebagai baris, dan ia diucapkan lewat
argumen `ReducedLuminanceLabel.text(...)`. Keduanya membaca properti yang
sama, jadi selama keduanya ada, layar terlihat benar **dan** terdengar benar.

Yang tidak dijaga satu pun aturan lama: **salah satu saluran dibuang.**
Terukur pada salinan utuh repo ini, proses baru, sebelum Aturan 70 ada —
seluruh 69 aturan UI lulus (exit 0) pada

    baris gambar   if let warning = engine.slewVerdict?.safetyWarningText {
                -> if let warning = String?.none {                 -> exit 0

Itu bukan sekadar informasi yang lenyap dari mata: peringatan keselamatan
hilang dari layar sementara VoiceOver tetap mengucapkannya, sehingga dua
saluran di layar yang sama saling membantah — dan yang dibantah adalah satu-
satunya penolakan yang mencegah cahaya Matahari masuk ke lensa. Layar redup
paling sering tampil (pergelangan miring sedikit, tanpa menyentuh layar),
jadi cacatnya paling sering muncul di tempat yang paling sedikit diperiksa.

Arah sebaliknya (label diucapkan, baris tetap ada) **tidak** diuji di sini:
mutasi itu sudah tertangkap Aturan 35. Harness yang menguji keadaan yang
sudah dijaga aturan lain akan hijau karena aturan lain itu, bukan karena
Aturan 70 — dan hijau karena sebab yang salah adalah bukti nol.

Tiga keadaan diuji:

  1. mutasi hilang-gambar  -> Aturan 70 wajib MERAH, dan pesannya wajib
                              menyebut `safetyWarning`.
  2. kontrol negatif (pohon utuh) -> wajib HIJAU. Tanpa keadaan ini, aturan
     yang selalu merah (mis. karena regex pemanggilan labelnya salah) akan
     lulus keadaan 1 tanpa membuktikan apa pun.
  3. aturan pra-perbaikan (induk commit yang MEMPERKENALKAN aturan ini),
     pada mutasi yang **sama** -> wajib HIJAU. Ini bukti non-vakuitas: kalau
     aturan lama juga merah di sini, cacat ini sudah terjaga dan Aturan 70
     tidak menambah apa pun.

Keadaan 3 dijalankan dari salinan pohon kerja di direktori sementara supaya
berkas repo tidak pernah tersentuh; `swift-ui-lint.sh` dijalankan sebagai
skrip, bukan diimpor, karena ia memang gerbang teks — dan gerbang yang tidak
pernah dieksekusi selalu hijau.

Pakai:
    python3 Tools/bukti-mutasi-aturan70-fakta-digambar.py   # 0 = sesuai
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")
TARGET = os.path.join("Apps", "PointAndKnowWatch", "Sources",
                      "ReducedLuminanceView.swift")

#: Jangkar yang diganti. Harus muncul **tepat sekali** di berkas sasaran;
#: nol berarti berkasnya berubah dan harness ini tidak lagi mengukur apa pun.
ANCHOR = "if let warning = engine.slewVerdict?.safetyWarningText {"
#: Pengganti: baris peringatan berhenti digambar, label suara dibiarkan utuh.
REPLACEMENT = "if let warning = String?.none {"

#: Penanda aturan di naskah gerbang; tanpa ini Aturan 70 belum diterapkan.
RULE_MARK = "Aturan 70: fakta yang DIUCAPKAN layar redup wajib juga DIGAMBAR"


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
    """Salin berkas yang dibutuhkan gerbang ke direktori sementara.

    `swift-ui-lint.sh` membaca `Apps/`, `Packages/`, `Tools/`, README, dan
    `project.yml`; `.build`/`out` tidak dibaca siapa pun dan besar, jadi
    dilewati. Penyalinan manual (bukan `rsync`) karena rsync tidak ada di
    semua mesin, dan `cp -a` gagal pada `.build` milik Docker.
    """
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
    print("Aturan 70: fakta yang diucapkan layar redup juga digambar\n")

    teks = open(LINT, encoding="utf-8").read()
    if RULE_MARK not in teks:
        print(f"GAGAL: penanda Aturan 70 tidak ada di swift-ui-lint.sh -- "
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

    kerja = tempfile.mkdtemp(prefix="aturan70-")
    hasil = []
    try:
        salin_pohon(kerja)

        # Keadaan 2 lebih dulu: pohon utuh wajib hijau. Kalau tidak, merah
        # pada keadaan 1 tidak membedakan apa pun.
        keluar, out = jalankan_lint(kerja)
        ok = keluar == 0
        print(f"{'OK  ' if ok else 'SALAH'} pohon utuh            -> "
              f"{'hijau' if ok else 'MERAH'} (harap hijau)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 1: baris peringatan berhenti digambar.
        sasaran = os.path.join(kerja, TARGET)
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(ANCHOR, REPLACEMENT))
        keluar, out = jalankan_lint(kerja)
        menyebut = "safetyWarning" in out
        ok = keluar != 0 and menyebut
        print(f"{'OK  ' if ok else 'SALAH'} peringatan tak digambar -> "
              f"{'MERAH' if keluar else 'hijau'}"
              f"{', menyebut safetyWarning' if menyebut else ', TIDAK menyebut safetyWarning'}"
              " (harap MERAH + menyebut)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 3: aturan pra-perbaikan pada mutasi yang sama wajib hijau.
        # Kalau merah, cacat ini sudah dijaga dan aturan baru tidak menambah.
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
