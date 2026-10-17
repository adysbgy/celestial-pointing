#!/usr/bin/env python3
"""Bukti bahwa Aturan 48 berbunyi pada cacatnya, dan tidak pada kode benar.

Kenapa berkas ini ada
=====================

Aturan 48 (`swift-ui-lint.sh`) menuntut: angka gerak — interval penyegar
`TimelineView` dan bentuk pegas `withAnimation` — tidak ditulis sendiri di
`Apps/`, melainkan dibaca dari `MotionPolicy` (PointingKit, teruji di Linux).

Aturan itu lahir dari pengukuran, bukan dari niat. Dua keadaan cacat yang
dijaganya **terukur hijau** pada 47 aturan sebelumnya:

    .spring(response: 0.90, dampingFraction: 0.30) + appearScale = 1.60
        di PointingView.swift                  -> SEMUA GERBANG UI LULUS
    minimumInterval: 1.0 / 30.0 -> 1.0 / 60.0  di DiagnosticsView.swift
                                               -> SEMUA GERBANG UI LULUS

Harness ini menjawab satu pertanyaan: **apakah Aturan 48 memerah tepat pada
kelas cacat itu, dan diam pada bentuk yang sah?** Aturan yang tidak pernah
terbukti memerah pada cacatnya adalah aturan yang tidak mengukur apa pun.

Kenapa salinan utuh, bukan mutasi di tempat
===========================================

`swift-ui-lint.sh` membaca `Apps/`, `Packages/`, `README.md`, dan `Tools/`
sekaligus; memutasi pohon tempat harness ini hidup akan membuat gerbang lain
mengukur pohon yang setengah-mutasi. Setiap keadaan mendapat salinan penuh di
direktori sementara, dijalankan di proses baru, lalu dihapus.

Kenapa ada keadaan yang **wajib hijau**
=======================================

Tanpa mereka, aturan yang melaporkan setiap baris `Apps/` akan lulus semua
keadaan cacat. Keadaan sah di bawah ini yang membedakan "menangkap cacat" dari
"berbunyi pada apa pun":

  * pembacaan model (`MotionPolicy.LockArrival…`, `MotionPolicy.pulseFrameInterval`)
  * angka di dalam **komentar** — docstring yang mengutip bentuk lama
  * `.spring(response: duration)` dengan variabel, bukan angka
  * `TimelineView(.periodic(from: .now, by: 30))` di layar kalibrasi: itu
    detak 30 **detik**, bukan frame denyut, dan tidak dimiliki `MotionPolicy`

Yang TIDAK dibuktikan harness ini
=================================

Ini sapu teks. Ia tidak membuktikan bahwa view **memakai** nilai model dengan
benar — hanya bahwa ia tidak menulis angkanya sendiri. Angka yang lewat
variabel perantara (`let r = 0.42; .spring(response: r)`) tetap tidak terlihat,
dan itu dinyatakan di docstring aturannya.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

import mutasi_sumber  # noqa: E402

JAM = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
IPHONE = "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"
ONBOARDING = "Apps/Shared/OnboardingView.swift"
KALIBRASI = "Apps/PointAndKnowWatch/Sources/CalibrationView.swift"

#: Jangkar produksi — bentuk yang **harus** ada, supaya keadaan cacat di bawah
#: benar-benar mengubah sesuatu. Kalau jangkar ini hilang, harness menolak
#: jalan alih-alih melaporkan "sesuai harapan" atas nol mutasi.
SPRING_BENAR = """            withAnimation(.spring(response: MotionPolicy.LockArrival.responseSeconds,
                                  dampingFraction: MotionPolicy.LockArrival.dampingFraction)) {
                appearScale = MotionPolicy.LockArrival.peakScale"""

SPRING_CACAT = """            withAnimation(.spring(response: 0.90, dampingFraction: 0.30)) {
                appearScale = 1.60"""

FRAME_BENAR = "TimelineView(.animation(minimumInterval: MotionPolicy.pulseFrameInterval))"
FRAME_CACAT = "TimelineView(.animation(minimumInterval: 1.0 / 60.0))"

STATES = [
    # ── Keadaan cacat: aturan WAJIB berbunyi ────────────────────────────────
    ("jam: angka pop ditulis sendiri (0.90/0.30/1.60)",
     {JAM: (SPRING_BENAR, SPRING_CACAT)}, True),
    ("iPhone: interval frame ditulis sendiri (60 fps)",
     {IPHONE: (FRAME_BENAR, FRAME_CACAT)}, True),
    ("jam: interval frame ditulis sendiri (60 fps)",
     {JAM: (FRAME_BENAR, FRAME_CACAT)}, True),
    ("onboarding: interval frame ditulis sendiri (60 fps)",
     {ONBOARDING: (FRAME_BENAR, FRAME_CACAT)}, True),
    # Bentuk yang lebih halus: hanya redamannya yang jadi angka, `response`
    # tetap dari model. Ini bentuk yang paling mungkin ditulis orang yang
    # "cuma ingin sedikit lebih memantul". Jangkar menyebut baris `withAnimation`
    # supaya hanya **satu** kecocokan (pasangan yang sama muncul dua kali:
    # tahap puncak dan tahap tenang).
    ("jam: hanya redaman yang jadi angka (0.55)",
     {JAM: ("""            withAnimation(.spring(response: MotionPolicy.LockArrival.responseSeconds,
                                  dampingFraction: MotionPolicy.LockArrival.dampingFraction)) {""",
            """            withAnimation(.spring(response: MotionPolicy.LockArrival.responseSeconds,
                                  dampingFraction: 0.55)) {""")}, True),
    # `.spring` dengan bentuk satu-baris — penulisan ulang yang wajar, dan
    # justru karena itu harus tertangkap.
    ("iPhone: pegas satu-baris dengan angka",
     {IPHONE: ("""                withAnimation(.spring(response: MotionPolicy.LockArrival.responseSeconds,
                                      dampingFraction: MotionPolicy.LockArrival.dampingFraction)) {""",
               """                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {""")}, True),

    # ── Keadaan sah: aturan WAJIB diam ──────────────────────────────────────
    # Kalau keadaan-keadaan ini merah, aturannya menuduh kode benar.
    #
    # Pembacaan model yang **ditulis ulang** (bukan identik): jangkar harus
    # benar-benar berubah, kalau tidak harness mengukur nol mutasi dan
    # melaporkan "sesuai harapan" tanpa membuktikan apa pun. Bentuk ini sah
    # karena ia masih membaca `MotionPolicy`; yang berubah hanya tata letaknya.
    ("kontrol: pembacaan model, ditulis ulang multi-baris",
     {JAM: (SPRING_BENAR,
            """            withAnimation(.spring(
                response: MotionPolicy.LockArrival.responseSeconds,
                dampingFraction: MotionPolicy.LockArrival.dampingFraction)) {
                appearScale = MotionPolicy.LockArrival.peakScale""")}, False),
    # Komentar yang mengutip bentuk lama. Aturan 45 pernah menuduh dirinya
    # sendiri karena membaca komentarnya sendiri; yang ini tidak boleh.
    ("kontrol: angka di dalam komentar",
     {JAM: ("            if motion.allowsContinuousMotion && visual.hasPulse {",
            "            // dulu: minimumInterval: 1.0 / 30.0\n"
            "            if motion.allowsContinuousMotion && visual.hasPulse {")}, False),
    # Variabel, bukan angka. Tidak dimiliki `MotionPolicy` karena nilainya
    # dihitung di tempat lain — dan aturan ini tidak boleh menebak.
    ("kontrol: pegas lewat variabel perantara",
     {JAM: (SPRING_BENAR,
            """            let respons = MotionPolicy.LockArrival.responseSeconds
            withAnimation(.spring(response: respons,
                                  dampingFraction: MotionPolicy.LockArrival.dampingFraction)) {
                appearScale = MotionPolicy.LockArrival.peakScale""")}, False),
    # Detak 30 **detik** di layar kalibrasi — `TimelineView` yang sama sekali
    # lain, dan sengaja tidak memakai `MotionPolicy` (ia bukan denyut). Nilai
    # `by:` diubah ke 20 supaya keadaan ini benar-benar memutasi sesuatu;
    # keduanya tetap angka detik, bukan frame.
    ("kontrol: TimelineView periodik 20 detik (bukan denyut)",
     {KALIBRASI: ("TimelineView(.periodic(from: .now, by: 30))",
                  "TimelineView(.periodic(from: .now, by: 20))")}, False),
]


def run_lint(tree):
    return subprocess.run(["./swift-ui-lint.sh"], cwd=tree,
                          capture_output=True, text=True)


def apply_edits(tree, edits):
    """Terapkan `{path: (find, replace)}`; kembalikan nama berkas yang gagal.

    Satu keadaan boleh menyentuh lebih dari satu berkas, dan setiap jangkar
    wajib muncul **tepat sekali** — kalau tidak, mutasinya ambigu dan hasilnya
    tidak mengukur apa pun.
    """
    gagal = []
    for path, (find, replace) in edits.items():
        target = os.path.join(tree, path)
        sumber = open(target, encoding="utf-8").read()
        if sumber.count(find) != 1:
            gagal.append("%s (%d kecocokan)" % (path, sumber.count(find)))
            continue
        if find != replace:
            mutasi_sumber.write_source(target, sumber.replace(find, replace, 1))
    return gagal


def main():
    if not os.path.isfile(os.path.join(ROOT, "swift-ui-lint.sh")):
        print("Tidak menemukan swift-ui-lint.sh di %s" % ROOT)
        return 2

    gagal = []
    for nama, edits, harus_merah in STATES:
        work = tempfile.mkdtemp(prefix="bukti-gerak-")
        tree = os.path.join(work, "repo")
        try:
            shutil.copytree(
                ROOT, tree, symlinks=True,
                ignore=shutil.ignore_patterns(".build", ".git", "__pycache__",
                                              "out"))
            rusak = apply_edits(tree, edits)
            if rusak:
                print("%-52s JANGKAR HILANG: %s" % (nama, "; ".join(rusak)))
                gagal.append(nama)
                continue

            hasil = run_lint(tree)
            merah = hasil.returncode != 0
            sesuai = merah == harus_merah
            print("%-52s %s (exit %d)" % (
                nama,
                "MERAH, sesuai harapan" if merah else "HIJAU, sesuai harapan",
                hasil.returncode))
            if not sesuai:
                gagal.append(nama)
                print("    diharapkan %s, dapat %s"
                      % ("MERAH" if harus_merah else "HIJAU",
                         "MERAH" if merah else "HIJAU"))
                # Hanya temuan Aturan 48 yang relevan; gerbang lain yang merah
                # berarti keadaan ini mengukur sebab lain (pelajaran yang sama
                # dengan harness Aturan 47).
                for baris in (hasil.stdout or "").splitlines():
                    if "minimumInterval" in baris or "dampingFraction" in baris \
                            or ".spring(response:" in baris:
                        print("    " + baris.strip())
        finally:
            shutil.rmtree(work, ignore_errors=True)

    # Non-vakuositas: keadaan cacat harus merah karena **Aturan 48**, bukan
    # karena gerbang lain. Diukur dengan mematikan pola Aturan 48 di salinan,
    # lalu menjalankan keadaan yang sama: kalau tetap merah, keadaan itu tidak
    # mengukur aturan ini.
    if not gagal:
        vakuos = []
        for nama, edits, harus_merah in STATES:
            if not harus_merah:
                continue
            work = tempfile.mkdtemp(prefix="bukti-gerak-nir-")
            tree = os.path.join(work, "repo")
            try:
                shutil.copytree(
                    ROOT, tree, symlinks=True,
                    ignore=shutil.ignore_patterns(".build", ".git",
                                                  "__pycache__", "out"))
                rusak = apply_edits(tree, edits)
                if rusak:
                    vakuos.append(nama)
                    print("%-52s JANGKAR HILANG di salinan nir: %s"
                          % (nama, "; ".join(rusak)))
                    continue
                # Matikan Aturan 48: ketiga polanya diganti pola yang tidak
                # pernah cocok. Kalau keadaan ini masih merah, yang berbunyi
                # bukan Aturan 48.
                lint = os.path.join(tree, "swift-ui-lint.sh")
                isi = open(lint, encoding="utf-8").read()
                for pola in (r'minimumInterval\s*:\s*[0-9]',
                             r'\.spring\s*\(\s*response\s*:\s*[0-9]',
                             r'dampingFraction\s*:\s*[0-9]'):
                    isi = isi.replace('re.compile(r"%s")' % pola,
                                      're.compile(r"(?!x)x")')
                mutasi_sumber.write_source(lint, isi)
                hasil = run_lint(tree)
                if hasil.returncode != 0:
                    vakuos.append(nama)
                    print("%-52s MERAH juga tanpa Aturan 48 (mengukur sebab "
                          "lain)" % nama)
            finally:
                shutil.rmtree(work, ignore_errors=True)
        if vakuos:
            print("\nAturan 48: %d keadaan TIDAK mengukur Aturan 48: %s"
                  % (len(vakuos), ", ".join(vakuos)))
            return 1

    if not gagal:
        print("\nAturan 48: %d keadaan, semuanya sesuai harapan."
              % len(STATES))
        return 0
    print("\nAturan 48: %d keadaan TIDAK sesuai harapan: %s"
          % (len(gagal), ", ".join(gagal)))
    return 1


if __name__ == "__main__":
    sys.exit(main())
