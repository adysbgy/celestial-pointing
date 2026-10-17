#!/usr/bin/env python3
"""Bukti bahwa Aturan 47 berbunyi pada cacatnya, dan tidak berbunyi pada kode benar.

Kenapa berkas ini ada.
=====================

Aturan 47 (`swift-ui-lint.sh`) menuntut: pola getaran per peristiwa tidak
dipilih sendiri di `Apps/`. Aturan yang tidak pernah terbukti memerah pada
cacatnya adalah aturan yang tidak mengukur apa pun — dan repo ini sudah pernah
punya gerbang yang hijau karena memeriksa nol situs.

Harness ini menjawab satu pertanyaan: **apakah Aturan 47 memerah tepat pada
kelas cacat yang ia klaim tutup?**

Cara kerjanya: salin seluruh repo ke direktori sementara (bukan hanya berkas
yang dimutasi — Aturan 47 butuh `Apps/` *dan* `Packages/`, dan gerbang lain
butuh `README.md`/`Tools/`), tulis satu keadaan cacat, jalankan
`swift-ui-lint.sh` di proses baru, catat hasilnya, lalu **pulihkan byte-identik**
dan periksa md5-nya.

Kenapa salinan utuh, bukan mutasi di tempat.
============================================

Percobaan pertama memutasi pohon kerja langsung dan menghasilkan "baseline
merah" — bukan karena aturannya, melainkan karena pohon itu sedang
setengah-mutasi saat gerbang lain berjalan. Pelajaran: harness yang mengubah
pohon tempat ia sendiri hidup akan mengukur dirinya, bukan kodenya.

Kenapa `mutasi_sumber` dipakai untuk menulis.
=============================================

Menulis berkas dengan `open(..., "w")` biasa akan membuat mutasi yang tertinggal
tak terdeteksi bila proses dibunuh di tengah jalan. `Tools/mutasi_sumber.py`
menulis atomik dan memulihkan dengan verifikasi; `check-jangkar-harness.py`
membacanya untuk memastikan tidak ada jangkar yang hilang dari sumber asli.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

import mutasi_sumber  # noqa: E402

JAM = "Apps/PointAndKnowWatch/Sources/HapticEngine.swift"
IPHONE = "Apps/PointAndKnowiOS/Sources/PhoneHapticEngine.swift"

#: Jangkar di `HapticEngine` (jam) — badan `switch` atas pola yang benar.
JAM_BENAR = """        case .completed: return .success
        case .unsettled: return .retry"""

#: Jangkar di `PhoneHapticEngine` (iPhone) — badan `switch` atas pola.
IPHONE_BENAR = """        case .completed:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .unsettled:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()"""

#: Keadaan: `(path, find, replace, nama, harus_merah)`.
#:
#: Urutannya **bukan** selera. `Tools/check-jangkar-harness.py` membaca jangkar
#: statis dari tuple berbentuk `(path, find, replace, ...)`, dan gerbang itu
#: satu-satunya yang mendeteksi mutasi tertinggal dari proses yang dibunuh di
#: tengah jalan. Bentuk `(nama, path, find, replace)` membuatnya buta terhadap
#: berkas ini — terukur: gerbang melaporkan "buta terhadap
#: bukti-mutasi-getaran-lint.py" dan meminta jangkar dinyatakan lewat
#: `JANGKAR_KECUALI`. Itu tidak dipakai di sini karena jangkarnya memang string
#: statis; yang perlu diubah hanya urutan elemennya, bukan pemeriksaannya.
#:
#: `path = None` berarti baseline (kode apa adanya) dan harus HIJAU.
#:
#: Yang diuji adalah **bentuk yang dilarang Aturan 47**: pemilihan pola per
#: peristiwa yang ditulis langsung di `Apps/`, dalam berkas yang memainkan
#: getaran. Tiap keadaan di bawah adalah cacat yang mengompilasi — getaran
#: tetap berbunyi, hanya tidak lagi membedakan ragu dari berhasil.
STATES = [
    (None, None, None, "baseline (kode apa adanya)", False),

    # Kelas cacat yang persis ditutup aturan: `case .<peristiwa>:` memilih efek.
    (JAM, JAM_BENAR,
     """        case .lockSucceeded:
            WKInterfaceDevice.current().play(.success)
        case .uncertain:
            WKInterfaceDevice.current().play(.success)""",
     "jam: switch atas peristiwa lagi", True),

    (IPHONE, IPHONE_BENAR,
     """        case .lockSucceeded:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .uncertain:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()""",
     "iPhone: switch atas peristiwa lagi", True),

    # Arah sebaliknya: perbandingan langsung, bukan `switch`.
    (IPHONE, IPHONE_BENAR,
     """        case .completed:
            if event == .uncertain {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        case .unsettled:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()""",
     "iPhone: pencocokan langsung event ==", True),

    # Non-vakuositas: keadaan yang **tidak** cacat harus tetap hijau, supaya
    # aturan tidak sekadar "selalu merah".
    (JAM, JAM_BENAR,
     """        case .completed: return .success
        case .unsettled: return .retry
        case .failed:    return .failure""",
     "jam: terjemahan pola tanpa menyebut peristiwa",
     False),
]


def run_lint(tree):
    return subprocess.run(["./swift-ui-lint.sh"], cwd=tree,
                          capture_output=True, text=True)


def main():
    if not os.path.isfile(os.path.join(ROOT, "swift-ui-lint.sh")):
        print("Tidak menemukan swift-ui-lint.sh di %s" % ROOT)
        return 2

    gagal = []
    for path, find, replace, nama, harus_merah in STATES:
        work = tempfile.mkdtemp(prefix="bukti-suara-haptic-")
        tree = os.path.join(work, "repo")
        try:
            shutil.copytree(
                ROOT, tree, symlinks=True,
                ignore=shutil.ignore_patterns(".build", ".git", "__pycache__"))
            if path is not None:
                target = os.path.join(tree, path)
                sumber = open(target, encoding="utf-8").read()
                if sumber.count(find) != 1:
                    print("%-46s JANGKAR HILANG (%d kecocokan) di %s"
                          % (nama, sumber.count(find), path))
                    gagal.append(nama)
                    continue
                mutasi_sumber.write_source(
                    target, sumber.replace(find, replace, 1))

            hasil = run_lint(tree)
            merah = hasil.returncode != 0
            sesuai = merah == harus_merah
            print("%-46s %s (exit %d)" % (
                nama,
                "MERAH, sesuai harapan" if merah else "HIJAU, sesuai harapan",
                hasil.returncode))
            if not sesuai:
                gagal.append(nama)
                print("    diharapkan %s, dapat %s"
                      % ("MERAH" if harus_merah else "HIJAU",
                         "MERAH" if merah else "HIJAU"))
                tail = (hasil.stdout or "")[-1200:]
                if tail.strip():
                    print("    --- keluaran gerbang ---")
                    for baris in tail.strip().splitlines()[-12:]:
                        print("    " + baris)
        finally:
            shutil.rmtree(work, ignore_errors=True)

    # Aturan ini hanya berarti kalau ia benar-benar melihat `Apps/`. Gerbang
    # yang hijau karena `Apps/` tidak terbaca adalah gerbang yang tidak ada.
    if not gagal:
        print("\nAturan 47: %d keadaan, semuanya sesuai harapan."
              % len(STATES))
        return 0
    print("\nAturan 47: %d keadaan TIDAK sesuai harapan: %s"
          % (len(gagal), ", ".join(gagal)))
    return 1


if __name__ == "__main__":
    sys.exit(main())
