#!/usr/bin/env python3
"""Bukti bahwa Aturan 50 berbunyi pada cacatnya, dan tidak pada kode benar.

Kenapa berkas ini ada
=====================

Aturan 50 (`swift-ui-lint.sh`) menuntut: ketujuh ciri pengenal planet di
`drawPlanet` — pita Jupiter, cincin Saturnus, tudung es Mars, kawah
Merkurius, kabut Venus, piringan Uranus, piringan Neptunus — **berhenti**
saat engine belum yakin (`guard isConfirmed else { return }` sebelum
`switch palette.feature`).

Aturan itu lahir dari cacat nyata yang **terukur hijau** pada 49 aturan
sebelumnya. Baris penjaganya dihapus, lalu seluruh 49 aturan dijalankan di
proses baru: **exit 0, "SEMUA GERBANG UI LULUS"**. Tidak ada uji Linux yang
bisa menolong, karena `Apps/` tidak pernah dibangun `swift-test.sh`.

Harness ini menjawab satu pertanyaan: apakah Aturan 50 memerah tepat pada
kelas cacat itu, dan diam pada bentuk yang sah? Aturan yang tidak pernah
terbukti memerah pada cacatnya adalah aturan yang tidak mengukur apa pun.

Kenapa Aturan 32 tidak cukup, dan itu bagian dari yang dibuktikan
==================================================================

Aturan 32 memeriksa lencana `drawCandidateMarker` dan penjaga `drawSphere`
untuk cincin Saturnus. Keduanya **tetap hijau** saat penjaga ciri pengenal
dihapus: lencananya masih digambar, dan bolanya masih dijaga. Yang bocor
adalah ciri pengenalnya sendiri — sehingga kandidat yang belum terkunci
tampil dengan cincin Saturnus **dan** tanda tanya di atasnya. Lencana di
atas ciri bukan kejujuran: mata membaca cincin lebih dulu.

Kenapa ada keadaan yang **wajib hijau**
======================================

Tanpa mereka, aturan yang melaporkan setiap baris `Apps/` akan lulus semua
keadaan. Keadaan sah di bawah ini yang membedakan "menangkap cacat" dari
"berbunyi pada apa pun". Yang terpenting: `switch palette.feature` di dalam
klip pita terang (yang sudah terlindungi `if isConfirmed`) **tidak** boleh
dituduh — itulah sebabnya aturan memakai `rfind`.

Yang TIDAK dibuktikan harness ini
=================================

Ini sapu teks, bukan pelacakan aliran. Ia tidak membuktikan bahwa gambar
yang dihasilkan benar-benar berhenti berubah di perangkat — tidak ada Xcode
di mesin ini dan `Apps/` tidak pernah dibangun. Yang dibuktikan: penjaga
**ada**, mengandung `isConfirmed`, dan mendahului switch ciri pengenal.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

import mutasi_sumber  # noqa: E402

VISUAL = "Apps/Shared/CelestialVisualView.swift"

#: Jangkar produksi — bentuk yang **harus** ada. Kalau ia hilang, harness
#: menolak jalan alih-alih melaporkan "sesuai harapan" atas nol mutasi.
#: Ini persis baris yang lolos dari 49 aturan sebelumnya.
PENJAGA = """        guard isConfirmed else { return }
        switch palette.feature {"""

#: Cacat aslinya: penjaga dihapus, ciri pengenal digambar tanpa syarat.
TANPA_PENJAGA = """        switch palette.feature {"""

#: Kebalikannya — berhenti saat engine **yakin**, sehingga ciri justru
#: tampil hanya pada kandidat. Sama cacatnya, berlawanan arah.
TERBALIK = """        guard !isConfirmed else { return }
        switch palette.feature {"""

STATES = [
    # ── Keadaan cacat: aturan WAJIB berbunyi ────────────────────────────────
    # Cacat yang terukur lolos dari seluruh 49 aturan sebelumnya.
    ("penjaga ciri pengenal dihapus (cacat asli, lolos 49 aturan)",
     {VISUAL: (PENJAGA, TANPA_PENJAGA)}, True),
    # Penjaga dibalik: ciri tampil hanya saat ragu — klaim identitas pada
    # kandidat, dan justru polos pada objek yang sudah terkunci.
    ("penjaga dibalik: ciri tampil hanya saat engine ragu",
     {VISUAL: (PENJAGA, TERBALIK)}, True),
    # Penjaga diganti `if` yang tidak menghentikan fungsi: switch tetap
    # dieksekusi walau syaratnya salah.
    ("penjaga dilonggarkan jadi if tanpa return",
     {VISUAL: (PENJAGA,
               """        if isConfirmed {
        switch palette.feature {""")}, True),

    # ── Keadaan sah: aturan WAJIB diam ──────────────────────────────────────
    # Kalau keadaan-keadaan ini merah, aturannya menuduh kode benar.
    #
    # Pohon utuh: penjaga ada, ciri pengenal terhenti saat ragu.
    ("kontrol: pohon utuh tanpa perubahan",
     {}, False),
    # Bentuk ekuivalen yang ditulis lain: `== false` bukan `else`.
    ("kontrol: penjaga ditulis dengan isConfirmed == false",
     {VISUAL: (PENJAGA,
               """        if isConfirmed == false { return }
        switch palette.feature {""")}, False),
]


def run_lint(tree):
    return subprocess.run(["./swift-ui-lint.sh"], cwd=tree,
                          capture_output=True, text=True)


def apply_edits(tree, edits):
    """Terapkan `{path: (find, replace)}`; kembalikan nama berkas yang gagal.

    Setiap jangkar wajib muncul **tepat sekali** — kalau tidak, mutasinya
    ambigu dan hasilnya tidak mengukur apa pun.
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
        work = tempfile.mkdtemp(prefix="bukti-ciri-")
        tree = os.path.join(work, "repo")
        try:
            shutil.copytree(
                ROOT, tree, symlinks=True,
                ignore=shutil.ignore_patterns(".build", ".git", "__pycache__",
                                              "out"))
            rusak = apply_edits(tree, edits)
            if rusak:
                print("%-56s JANGKAR HILANG: %s" % (nama, "; ".join(rusak)))
                gagal.append(nama)
                continue

            hasil = run_lint(tree)
            merah = hasil.returncode != 0
            sesuai = merah == harus_merah
            print("%-56s %s (exit %d)" % (
                nama,
                "MERAH, sesuai harapan" if merah else "HIJAU, sesuai harapan",
                hasil.returncode))
            if not sesuai:
                gagal.append(nama)
                print("    diharapkan %s, dapat %s"
                      % ("MERAH" if harus_merah else "HIJAU",
                         "MERAH" if merah else "HIJAU"))
                # Tampilkan alasan merahnya: tanpa ini, "menuduh kode benar"
                # tidak bisa dibedakan dari gerbang lain yang kebetulan merah.
                if merah and not harus_merah:
                    for baris in hasil.stdout.split("\n"):
                        if "Aturan 50" in baris or "ciri pengenal" in baris:
                            print("    %s" % baris.strip())
        finally:
            shutil.rmtree(work, ignore_errors=True)

    print()
    if gagal:
        print("%d keadaan TIDAK sesuai harapan:" % len(gagal))
        for nama in gagal:
            print("  - %s" % nama)
        return 1
    print("%d keadaan, semuanya sesuai harapan." % len(STATES))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
