#!/usr/bin/env python3
"""Buktikan Aturan 74 berbunyi: pengumuman keadaan wajib lewat gerbang.

Aturan 74 menutup kelas cacat yang **terukur**, bukan diklaim.

Keputusan "berbunyi hanya saat nilai berubah" dulu hidup sebagai tiga baris
`guard ... else { return }` di dalam tiga view:

    Apps/PointAndKnowWatch/Sources/PointingView.swift:223
    Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift:109
    Apps/PointAndKnowWatch/Sources/CalibrationView.swift:117,136

Tiga baris itu tidak dijaga apa pun. Terukur pada salinan utuh repo ini,
proses baru: membalik `!=` menjadi `==` pada `PointingView` membuat **seluruh
73 aturan UI lulus (exit 0)** -- lalu aplikasi berhenti berbunyi saat
keadaan berubah, dan berbunyi 20x per detik saat keadaan diam, karena
cuplikan ditulis 20 Hz. Tidak ada layar yang tampak salah, tidak ada teks
yang berbohong, dan tidak ada compiler yang melihatnya.

Kenapa cacat ini lebih mahal dari "cacat diam". Lock adalah satu-satunya
peristiwa yang ditunggu pengguna VoiceOver. Tanpa suaranya, satu-satunya
cara tahu hasil pengukuran adalah mengusap layar -- dan itu berarti justru
pengguna yang paling bergantung pada aplikasi ini (mereka tidak melihat
langit) yang paling sedikit menerima.

Bentuk yang diputuskan, dan yang **sengaja tidak** diputuskan:

  * yang diputuskan: apakah badan `onChange` yang memuat panggilan
    `Announcement` menyebut `AnnouncementGate` -- gerbangnya, bukan nama
    aksesornya, jadi `remember`/`shouldSpeak` boleh berganti nama;
  * yang tidak diputuskan: apakah kalimatnya kosong, apakah mutasi ada di
    `PointingView` atau di layar lain, dan apakah gerbangnya dipakai
    **benar**. Yang terakhir adalah wilayah `AnnouncementGateTests`
    (Linux); aturan ini hanya menuntut keputusan itu tidak ditulis ulang
    di tempat yang tidak pernah dibangun.

Empat keadaan, dan keempatnya harus benar sekaligus:

  1. mutasi `announcedState != newState` (guard tulisan sendiri) -> MERAH
     dan wajib menyebut `Guard`-nya.
  2. pohon utuh -> HIJAU. Tanpa ini, aturan yang selalu merah akan lulus
     keadaan 1 tanpa membuktikan apa pun.
  3. `.post()` **di luar** `onChange` -> HIJAU. Itu bukan pengumuman
     perubahan keadaan; menuntutnya lewat gerbang keadaan adalah salah tuduh.
  4. aturan pra-perbaikan (induk commit yang MEMPERKENALKAN aturan ini) pada mutasi yang
     **sama** -> HIJAU. Bukti non-vakuitas: kalau lint lama sudah merah di
     sini, cacat ini sudah terjaga dan Aturan 74 tidak menambah apa pun.

Pakai:
    python3 Tools/bukti-mutasi-aturan74-announcement.py   # 0 = sesuai
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

TARGET = os.path.join("Apps", "PointAndKnowWatch", "Sources", "PointingView.swift")

#: Bentuk yang diterima gerbang hari ini. Harus muncul **tepat sekali**; nol
#: berarti berkasnya berubah dan harness tidak lagi mengukur cacat yang
#: diklaimnya.
ANCHOR = ("let step = AnnouncementGate.step(announced: announcedState,\n"
          "                                             current: newState)")

#: Mutasi: kembali ke guard tulisan sendiri -- persis bentuk yang lolos
#: seluruh 73 aturan sebelumnya.
MUTASI = ("guard announcedState != newState else { return }\n"
          "                announcedState = newState")

#: Penanda aturan di naskah gerbang; tanpa ini Aturan 74 belum diterapkan.
RULE_MARK = "Aturan 74: pengumuman keadaan harus lewat AnnouncementGate"


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
    print("Aturan 74: pengumuman keadaan lewat gerbang, bukan guard sendiri\n")

    teks = open(LINT, encoding="utf-8").read()
    if RULE_MARK not in teks:
        print("GAGAL: penanda Aturan 74 tidak ada di swift-ui-lint.sh -- "
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

    kerja = tempfile.mkdtemp(prefix="aturan74-")
    hasil = []
    try:
        salin_pohon(kerja)
        sasaran = os.path.join(kerja, TARGET)

        # Keadaan 2 lebih dulu: pohon utuh wajib hijau. Kalau tidak, merah
        # pada keadaan 1 tidak membedakan apa pun.
        keluar, out = jalankan_lint(kerja)
        ok = keluar == 0
        print(f"{'OK  ' if ok else 'SALAH'} pohon utuh                -> "
              f"{'hijau' if ok else 'MERAH'} (harap hijau)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 1: guard tulisan sendiri di dalam onChange keadaan.
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(ANCHOR, MUTASI))
        keluar, out = jalankan_lint(kerja)
        menyebut = "announcedState" in out and "guard" in out.lower()
        ok = keluar != 0 and menyebut
        print(f"{'OK  ' if ok else 'SALAH'} guard tulisan sendiri      -> "
              f"{'MERAH' if keluar else 'hijau'}"
              f"{', menyebut announcedState' if menyebut else ''} "
              "(harap MERAH + menyebut)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # Keadaan 3: `.post()` **di luar** onChange wajib hijau. Di luar
        # onChange ia tidak mengawasi perubahan keadaan, jadi menuntutnya
        # lewat gerbang keadaan adalah salah tuduh.
        #
        # Berkas target dipulihkan **lebih dulu**: keadaan 1 meninggalkan
        # mutasinya di sana, dan clone itu persis alasan pemulihannya di sini.
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi)
        luar = os.path.join(kerja, "Apps", "Shared", "AnnouncementProbe.swift")
        with open(luar, "w", encoding="utf-8") as handle:
            handle.write(
                "import SwiftUI\n\n"
                "struct AnnouncementProbeView: View {\n"
                "    let message: String\n"
                "    var body: some View {\n"
                "        Text(message)\n"
                "            .onAppear {\n"
                "                AccessibilityNotification.Announcement(message).post()\n"
                "            }\n"
                "    }\n"
                "}\n")
        keluar, out = jalankan_lint(kerja)
        ok = keluar == 0
        print(f"{'OK  ' if ok else 'SALAH'} post() di luar onChange      -> "
              f"{'hijau' if ok else 'MERAH'} (harap hijau)")
        if not ok:
            for baris in out.strip().splitlines()[-12:]:
                print(f"       {baris}")
        hasil.append(ok)
        os.remove(luar)

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
            print("SALAH aturan pra-perbaikan tidak terlacak dari git -- "
                  "non-vakuitas tidak bisa dibuktikan.")
            hasil.append(False)
        elif RULE_MARK in proc.stdout:
            print("SALAH 'pra-perbaikan' ternyata sudah memuat aturan ini -- "
                  "jangkarnya salah, keadaan ini tidak membuktikan apa pun.")
            hasil.append(False)
        else:
            with open(lama, "w", encoding="utf-8") as handle:
                handle.write(proc.stdout)
            keluar, out = jalankan_lint(kerja, "lint-lama.sh")
            ok = keluar == 0
            print(f"{'OK  ' if ok else 'SALAH'} aturan pra-perbaikan        -> "
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
