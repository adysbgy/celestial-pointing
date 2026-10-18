#!/usr/bin/env python3
"""Bukti bahwa Aturan 52 berbunyi pada cacatnya, dan tidak pada kode benar.

Kenapa berkas ini ada
=====================

Aturan 52 (`swift-ui-lint.sh`) menuntut setiap `CelestialVisualView(...)` di
`Apps/` meneruskan keyakinan engine **secara langsung** — lewat
`confirmsDisplayedIdentity` atau parameter `isConfirmed` — bukan lewat nama
perantara yang di `Apps/` bisa berarti apa saja.

Cacatnya **terukur**, bukan hipotetis. Pada pohon utuh, satu baris di
`ReducedLuminanceView.swift` (layar Always-On) diganti:

    isConfirmed: engine.confirmsDisplayedIdentity
 -> isConfirmed: CelestialVisualView.defaultConfirmation

Seluruh 51 aturan yang ada saat itu dijalankan di proses baru: **exit 0,
"SEMUA GERBANG UI LULUS"**. Baris itu bahkan tidak bisa dikompilasi
(`defaultConfirmation` tidak ada) — tapi ia lolos setiap gerbang tulisan, dan
`Apps/` hanya dikompilasi di runner macOS **setelah** push. Tambahkan satu
`static let defaultConfirmation = true` dan tidak ada yang tersisa untuk
menangkap cincin Saturnus di bawah badge "Ragu".

Yang dibuktikan
===============

1. Cacat itu **merah** pada aturan sekarang, dan merahnya berasal dari
   Aturan 52 — bukan aturan lain yang kebetulan gagal.
2. Bentuk sah (`engine.confirmsDisplayedIdentity`, parameter `isConfirmed`,
   literal `true` di ilustrasi onboarding) **hijau**.
3. Arah kedua: lint **pra-perbaikan** (`PRA_ATURAN52`, dibaca lewat `git
   show`, bukan dikarang) **hijau** pada cacat yang sama. Tanpa arah ini,
   "aturan berbunyi" cuma klaim: merah bisa datang dari sebab lain.

Yang TIDAK dibuktikan
=====================

Ini sapu teks. Ia tidak membuktikan sifat `defaultConfirmation` di perangkat;
ia membuktikan bahwa **nama** yang dipakai sebagai keyakinan tidak lolos tanpa
dibaca. Nama yang dibuat di berkas lain lalu diteruskan sebagai parameter
bernama lain tetap tidak terlihat — itu batas yang dinyatakan, bukan
disembunyikan.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

import mutasi_sumber  # noqa: E402

REDUCED = "Apps/PointAndKnowWatch/Sources/ReducedLuminanceView.swift"
ONBOARDING = "Apps/Shared/OnboardingView.swift"

#: Komit terakhir sebelum Aturan 52 ada. Arah kedua membaca lint dari sini.
PRA_ATURAN52 = "b514826"

#: Jangkar produksi. Wajib ada tepat sekali; kalau tidak, harness berhenti
#: alih-alih melaporkan "sesuai harapan" atas nol mutasi.
BENAR = "                                        isConfirmed: engine.confirmsDisplayedIdentity,\n                                        // Diam karena layar redup"

#: Cacat aslinya: keyakinan dibaca lewat nama yang tidak ada di tipe itu.
NAMA_AKAR = "                                        isConfirmed: CelestialVisualView.defaultConfirmation,\n                                        // Diam karena layar redup"

#: Cacat kedua: keyakinan disalin ke variabel perantara lebih dulu.
NAMA_PERANTARA_ATAS = ("                    let keyakinan = engine.confirmsDisplayedIdentity\n"
                       "                    CelestialVisualView(visual: visual,")
NAMA_PERANTARA = ("                    let keyakinan = CelestialVisualView.defaultConfirmation\n"
                  "                    CelestialVisualView(visual: visual,")

#: Cacat ketiga: keyakinan yang **menyamar dari argumen lain** — `visual`
#: tidak menyatakan apa pun soal keyakinan, dan aturan menolaknya karena
#: bentuknya tidak menyebut fakta keyakinan.
MENYAMAR = "                                        isConfirmed: visual.isConfirmed,\n                                        // Diam karena layar redup"

#: Sah: diteruskan sebagai parameter dengan nama yang sama.
PARAMETER = "                                        isConfirmed: isConfirmed,\n                                        // Diam karena layar redup"

#: Ilustrasi onboarding: bintang generik, bukan benda langit engine.
ILUSTRASI_SAH = """                CelestialVisualView(visual: illustration,
                                    diameter: VisualImageMetrics.onboardingIllustrationDiameter,
                                    isConfirmed: true,"""

STATES = [
    # ── Keadaan cacat: aturan WAJIB berbunyi ────────────────────────────────
    ("latar redup: keyakinan lewat `defaultConfirmation` (cacat asli)",
     {REDUCED: (BENAR, NAMA_AKAR)}, True),
    ("latar redup: keyakinan disalin ke variabel perantara",
     {REDUCED: [("                    CelestialVisualView(visual: visual,",
                 "                    let keyakinan = engine.confirmsDisplayedIdentity\n"
                 "                    CelestialVisualView(visual: visual,"),
                (BENAR, "                                        isConfirmed: keyakinan,\n"
                        "                                        // Diam karena layar redup")]}, True),
    ("latar redup: keyakinan dibaca dari `visual.isConfirmed`",
     {REDUCED: (BENAR, MENYAMAR)}, True),

    # ── Keadaan sah: aturan WAJIB diam ──────────────────────────────────────
    ("kontrol: pohon utuh tanpa perubahan", {}, False),
    ("kontrol: parameter `isConfirmed` diteruskan apa adanya",
     {REDUCED: (BENAR, PARAMETER)}, False),
    ("kontrol: ilustrasi onboarding boleh `true` (bukan benda engine)",
     {ONBOARDING: (ILUSTRASI_SAH, ILUSTRASI_SAH)}, False),
]

#: Keadaan yang wajib memerahkan **Aturan 52** secara khusus. Tanpa ini,
#: "merah" bisa berarti aturan lain yang kebetulan gagal.
WAJIB_MENYALA = {
    "latar redup: keyakinan lewat `defaultConfirmation` (cacat asli)",
    "latar redup: keyakinan disalin ke variabel perantara",
    "latar redup: keyakinan dibaca dari `visual.isConfirmed`",
}

#: Arah kedua: keempat keadaan cacat dijalankan lagi atas lint pra-Aturan52
#: dan **wajib HIJAU** — kalau tidak, lubangnya tidak nyata, aturan ini hanya
#: mengulang gerbang yang sudah ada.
ARAH_KEDUA = [
    ("pra-52: keyakinan lewat `defaultConfirmation` (wajib HIJAU)",
     {REDUCED: (BENAR, NAMA_AKAR)}),
    ("pra-52: keyakinan disalin ke variabel perantara (wajib HIJAU)",
     {REDUCED: [("                    CelestialVisualView(visual: visual,",
                 "                    let keyakinan = engine.confirmsDisplayedIdentity\n"
                 "                    CelestialVisualView(visual: visual,"),
                (BENAR, "                                        isConfirmed: keyakinan,\n"
                        "                                        // Diam karena layar redup")]}),
    ("pra-52: keyakinan dibaca dari `visual.isConfirmed` (wajib HIJAU)",
     {REDUCED: (BENAR, MENYAMAR)}),
]


def run_lint(tree):
    return subprocess.run(["./swift-ui-lint.sh"], cwd=tree,
                          capture_output=True, text=True)


def apply_edits(tree, edits):
    """Terapkan `{path: (find, replace) | [(find, replace), …]}`.

    Setiap jangkar wajib muncul **tepat sekali** — kalau tidak, mutasinya
    ambigu dan hasilnya tidak mengukur apa pun. Bentuk daftar dipakai bila
    satu keadaan butuh dua suntingan di berkas yang sama; bentuk pasangan
    tunggal dipertahankan supaya harness ini sama mudahnya dibaca dengan
    harness Aturan 50.
    """
    gagal = []
    for path, spec in edits.items():
        target = os.path.join(tree, path)
        sumber = open(target, encoding="utf-8").read()
        pasangan = (spec if isinstance(spec, list)
                    else [spec[0] if isinstance(spec[0], tuple) else spec])
        for find, replace in pasangan:
            if sumber.count(find) != 1:
                gagal.append("%s (%d kecocokan)" % (path, sumber.count(find)))
                continue
            if find != replace:
                sumber = sumber.replace(find, replace, 1)
        if not gagal:
            mutasi_sumber.write_source(target, sumber)
    return gagal


def main():
    if not os.path.isfile(os.path.join(ROOT, "swift-ui-lint.sh")):
        print("Tidak menemukan swift-ui-lint.sh di %s" % ROOT)
        return 2

    lama = mutasi_sumber.git_show(PRA_ATURAN52, "swift-ui-lint.sh",
                                  min_bytes=10000)

    gagal = []
    rencana = ([(nama, edits, True) for nama, edits, merah in STATES
                if merah] +
               [(nama, edits, False) for nama, edits, merah in STATES
                if not merah] +
               [(nama, edits, False, True) for nama, edits in ARAH_KEDUA])

    for rencana_satu in rencana:
        nama, edits, harus_merah = rencana_satu[:3]
        pra = len(rencana_satu) > 3
        work = tempfile.mkdtemp(prefix="bukti-keyakinan-")
        tree = os.path.join(work, "repo")
        try:
            shutil.copytree(
                ROOT, tree, symlinks=True,
                ignore=shutil.ignore_patterns(".build", ".git", "__pycache__",
                                              "out"))
            if pra:
                mutasi_sumber.write_source(
                    os.path.join(tree, "swift-ui-lint.sh"), lama)
                # Aturan 10 membaca hitungan aturan di README; lint lama akan
                # merah di sana karena angka README sudah 52, dan arah kedua
                # berhenti membuktikan lubangnya. Yang dihapus hanya
                # pemeriksa hitungannya, aturan lain tetap utuh.
                buang_aturan_10(tree)

            rusak = apply_edits(tree, edits)
            if rusak:
                print("%-60s JANGKAR HILANG: %s" % (nama, "; ".join(rusak)))
                gagal.append(nama)
                continue

            hasil = run_lint(tree)
            merah = hasil.returncode != 0
            sesuai = merah == harus_merah
            print("%-60s %s (exit %d)" % (
                nama,
                "MERAH, sesuai harapan" if merah else "HIJAU, sesuai harapan",
                hasil.returncode))
            if not sesuai:
                gagal.append(nama)
                print("    diharapkan %s, dapat %s"
                      % ("MERAH" if harus_merah else "HIJAU",
                         "MERAH" if merah else "HIJAU"))
            if merah and harus_merah and not pra and nama in WAJIB_MENYALA:
                if "Aturan 52" not in hasil.stdout:
                    gagal.append(nama)
                    print("    merah, tetapi Aturan 52 tidak menyala")
        finally:
            shutil.rmtree(work, ignore_errors=True)

    print()
    if gagal:
        print("%d keadaan TIDAK sesuai harapan:" % len(gagal))
        for nama in gagal:
            print("  - %s" % nama)
        return 1
    print("%d keadaan, semuanya sesuai harapan." % len(rencana))
    return 0


def buang_aturan_10(tree):
    """Hapus **langkah Aturan 10** dari lint yang dipasang di `tree`."""
    target = os.path.join(tree, "swift-ui-lint.sh")
    teks = open(target, encoding="utf-8").read()
    awal = teks.find('echo "== Aturan 10:')
    akhir = teks.find('echo "== Aturan 11:')
    if awal < 0 or akhir < 0 or akhir <= awal:
        raise SystemExit("GAGAL: tidak bisa memisahkan Aturan 10 dari lint "
                         "pra-perbaikan; arah kedua tidak bisa dijalankan.")
    mutasi_sumber.write_source(target, teks[:awal] + teks[akhir:])


if __name__ == "__main__":
    raise SystemExit(main())
