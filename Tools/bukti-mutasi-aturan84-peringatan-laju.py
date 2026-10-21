#!/usr/bin/env python3
"""Bukti bahwa Aturan 84 bisa MERAH — dan merah pada cacat yang benar.

Aturan 84 hijau pada hari ia ditulis tidak membuktikan apa pun. Gerbang teks
paling mudah gagal dengan cara: regex-nya tidak cocok dengan apa pun, tidak ada
yang dilaporkan, dan "Bersih" tercetak. Bentuk hijau itu identik dengan hijau
yang benar.

Jadi berkas ini menuntut **tiga** hal dari setiap keadaan:

  1. `swift-typecheck.sh` **hijau** — cacatnya lolos compiler. Kalau typecheck
     sudah merah, keadaan itu bukan bukti untuk aturan teks apa pun.
  2. `swift-ui-lint.sh` **dengan blok Aturan 84 dicabut** tetap hijau —
     artinya cacatnya memang lolos seluruh 83 aturan lama. Klaim ini diukur,
     bukan dikutip dari komentar: salinan skrip dipotong tepat pada penanda
     Aturan 84, lalu dijalankan. Versi pertama harness ini menuntut
     `ui-lint=0` pada skrip **utuh**, dan tuntutan itu menjadi salah begitu
     aturannya didaftarkan — harness memerah bukan karena gerbangnya rusak,
     melainkan karena model harapannya basi. Memotong bloknya mengukur klaim
     yang sebenarnya: "83 aturan lama tidak melihat ini".
  3. `swift-ui-lint.sh` **utuh** merah, dan `check-aturan84-...` merah —
     aturannya terdaftar dan berbunyi. Kalau hanya checker-nya yang merah
     sementara lint hijau, aturan itu tidak dijaga siapa pun di CI.

Keadaan 7 dan 8 adalah kontrol arah sebaliknya, dan keduanya sama penting:
komentar yang menyebut bentuk **salah** tidak boleh memerahkan pohon benar
(aturan harus membersihkan komentar), dan komentar yang menyebut bentuk
**benar** tidak boleh menyelamatkan kode yang salah (aturan tidak boleh
mempercayai komentar). Tanpa dua kontrol ini, aturan bisa "bekerja" hanya
karena berkasnya kebetulan menyebut kedua bentuk di docstring.

Cacat yang diukur di sini pernah lolos, bukan direka: ketujuh keadaan
dijalankan pada salinan pohon utuh di proses baru sebelum aturan ini ada, dan
keenam keadaan pertama hijau di seluruh gerbang.

Yang TIDAK diklaim: ini tidak menjalankan SwiftUI. Ia membuktikan gerbangnya
bisa berbunyi, bukan bahwa peringatan laju terlihat di layar 41mm. Pemotongan
blok memakai penanda komentar; kalau penanda itu berubah nama, harness ini
GAGAL pada baseline — bukan diam-diam mengukur skrip yang sama dua kali.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW_REL = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
ATURAN84 = "Tools/check-aturan84-peringatan-laju.py"

AMBANG = "let tooFast = rate > engine.snapshot.maxAngularRateDegPerSec"
IKON = '? "scope"\n                              : "exclamationmark.circle"'
CABANG = ("if tooFast {\n                        "
          "Text(TextLocalization.text(.pointingRateTooFast))")

#: (label, cari, ganti, kenapa keadaan ini penting)
STATES = [
    ("tooFast selalu false", AMBANG, "let tooFast = false",
     "mematikan satu-satunya peringatan bahwa arah tunjuk belum sah"),
    ("ambang > jadi >=", AMBANG,
     "let tooFast = rate >= engine.snapshot.maxAngularRateDegPerSec",
     "cacat satu-satuan: peringatan muncul/hilang di tepat ambang"),
    ("ambang jadi literal", AMBANG, "let tooFast = rate > 8",
     "memutus ambang yang sudah diuji di Linux dari layar"),
    ("cabang dibalik", "if tooFast {", "if !tooFast {",
     "peringatan tampil saat laju aman, hilang saat terlalu cepat"),
    ("cabang tanpa kata", CABANG, "if tooFast {\n                        EmptyView()",
     "warna saja bukan peringatan yang terbaca tanpa warna"),
    ("ikon dibalik", IKON,
     '? "exclamationmark.circle"\n                              : "scope"',
     "jam belum terkalibrasi terlihat siap dipakai"),
]

CONTROLS = [
    ("komentar bentuk-benar + kode salah",
     AMBANG,
     "// let tooFast = rate > engine.snapshot.maxAngularRateDegPerSec\n"
     "    let tooFast = false",
     1, "komentar tidak boleh menyelamatkan kode yang salah"),
    ("komentar ikon-terbalik + kode benar",
     "    let tooFast",
     '    // isCalibrated ? "exclamationmark.circle" : "scope"\n    let tooFast',
     0, "komentar tidak boleh memerahkan pohon yang benar"),
]


def run(cmd, cwd):
    proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


#: Penanda blok Aturan 84 di `swift-ui-lint.sh`. Blok dicabut dari **salinan**
#: untuk membuktikan cacatnya memang lolos 83 aturan lama — klaim itu diukur,
#: bukan dikutip. Penanda yang hilang adalah kegagalan keras: tanpa potongan
#: itu, "lint lama hijau" hanya berarti "lint utuh hijau", yang tidak
#: membuktikan apa pun tentang aturan lama.
PENANDA_AWAL = "# ── Aturan 84 ──"
PENANDA_AKHIR = "\n\nif [ \"$status\" -eq 0 ]; then"


def potong_aturan84(skrip):
    """Kembalikan (skrip tanpa blok Aturan 84, jumlah blok yang dicabut)."""
    awal = skrip.find(PENANDA_AWAL)
    if awal == -1:
        return None, 0
    akhir = skrip.find(PENANDA_AKHIR, awal)
    if akhir == -1:
        return None, 0
    return skrip[:awal] + skrip[akhir:], 1


def main() -> int:
    failures = []
    # `swift-typecheck.sh` membuat `.build/` di dalam salinan, dan berkas di
    # sana tidak bisa di-chmod di tmpfs ini. `TemporaryDirectory` lalu
    # melempar `PermissionError` **dari `__exit__`**, sesudah semua keadaan
    # diukur — dan Python melaporkan itu sebagai exit 1. Terukur: seluruh
    # delapan keadaan sesuai harapan, lalu harness keluar 1 karena
    # pembersihan, bukan karena gerbangnya.
    #
    # Itu bentuk kegagalan paling menipu untuk sebuah bukti: merah yang
    # datang dari tempat lain membuat merah yang sungguhan tidak bisa
    # dibedakan. Jadi salinan dibuang dengan `ignore_errors`, dan hasil
    # pengukuran tetap satu-satunya yang menentukan kode keluar.
    tmp = tempfile.mkdtemp(prefix="aturan84-")
    try:
        copy = os.path.join(tmp, "repo")
        # Salinan utuh: `swift-ui-lint.sh` membaca `Apps/` **dan** `Packages/`,
        # dan salinan separuh membuat baseline merah karena sebab yang salah.
        shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns(
            ".git", "out", ".build", "__pycache__", "*.log"))

        view_path = os.path.join(copy, VIEW_REL)
        pristine = open(view_path, encoding="utf-8").read()

        rc, out = run(["bash", "swift-ui-lint.sh"], copy)
        if rc != 0:
            print("BASELINE swift-ui-lint.sh merah pada pohon benar — "
                  "keadaan di bawah tidak membuktikan apa pun.")
            print(out[-800:])
            return 1
        rc, out = run(["bash", "swift-typecheck.sh"], copy)
        if rc != 0:
            print("BASELINE swift-typecheck.sh merah pada pohon benar.")
            print(out[-800:])
            return 1

        # Skrip tanpa blok Aturan 84, untuk mengukur klaim "83 aturan lama
        # tidak melihat cacat ini". Dibuat SEKALI, dari salinan yang sama.
        lint_path = os.path.join(copy, "swift-ui-lint.sh")
        lint_utuh = open(lint_path, encoding="utf-8").read()
        lint_lama, dicabut = potong_aturan84(lint_utuh)
        if dicabut != 1 or lint_lama is None:
            print("BASELINE blok Aturan 84 tidak ditemukan di swift-ui-lint.sh "
                  f"(penanda {PENANDA_AWAL!r}). Tanpa potongan itu, harness ini "
                  "hanya mengukur skrip yang sama dua kali.")
            return 1
        open(os.path.join(copy, "swift-ui-lint-tanpa-84.sh"), "w",
             encoding="utf-8").write(lint_lama)
        rc, out = run(["bash", "swift-ui-lint-tanpa-84.sh"], copy)
        if rc != 0:
            print("BASELINE skrip tanpa blok Aturan 84 merah pada pohon benar "
                  "— potongannya merusak skrip, jadi keadaan di bawah tidak "
                  "membuktikan apa pun.")
            print(out[-800:])
            return 1
        print("OK   baseline: pohon benar hijau di ui-lint + typecheck, dan "
              "skrip tanpa blok Aturan 84 juga hijau")

        for label, old, new, why in STATES:
            if old not in pristine:
                failures.append(f"{label}: jangkar tidak cocok — keadaan ini "
                                f"tidak mengukur apa pun")
                print(f"GAGAL {label:32s} jangkar tidak cocok")
                continue
            open(view_path, "w", encoding="utf-8").write(
                pristine.replace(old, new, 1))
            rc_lint, _ = run(["bash", "swift-ui-lint.sh"], copy)
            rc_lama, out_lama = run(["bash", "swift-ui-lint-tanpa-84.sh"], copy)
            rc_type, _ = run(["bash", "swift-typecheck.sh"], copy)
            rc_84, out84 = run([sys.executable, ATURAN84], copy)
            ok = (rc_lint != 0 and rc_lama == 0 and rc_type == 0
                  and rc_84 != 0)
            if not ok:
                failures.append(
                    f"{label}: ui-lint={rc_lint} lint-tanpa-84={rc_lama} "
                    f"typecheck={rc_type} aturan84={rc_84} — harap "
                    f"non-0/0/0/non-0 ({why})")
            print(f"{'OK  ' if ok else 'GAGAL'} {label:32s} "
                  f"lint={rc_lint} tanpa84={rc_lama} type={rc_type} "
                  f"aturan84={rc_84}  ({why})")
            if rc_lama != 0:
                print("       cacat ini TIDAK lolos aturan lama — keadaan ini "
                      "bukti untuk aturan lain, bukan Aturan 84: "
                      f"{out_lama[-200:]}")
            if rc_84 == 0:
                print(f"       aturan84 HIJAU padahal harus merah: {out84[-200:]}")
            if rc_lint == 0:
                print("       blok Aturan 84 tidak berbunyi di ui-lint — "
                      "checker-nya benar, tetapi tidak dijaga CI.")

        for label, old, new, want_red, why in CONTROLS:
            if old not in pristine:
                failures.append(f"kontrol {label}: jangkar tidak cocok")
                continue
            open(view_path, "w", encoding="utf-8").write(
                pristine.replace(old, new, 1))
            rc_84, _ = run([sys.executable, ATURAN84], copy)
            ok = (rc_84 != 0) == bool(want_red)
            if not ok:
                failures.append(f"kontrol {label}: aturan84={rc_84}, "
                                f"harap {'merah' if want_red else 'hijau'}")
            print(f"{'OK  ' if ok else 'GAGAL'} kontrol: {label:32s} "
                  f"aturan84={rc_84}  ({why})")

        open(view_path, "w", encoding="utf-8").write(pristine)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    if failures:
        print(f"GAGAL: {len(failures)} keadaan tidak seperti yang dituntut")
        for line in failures:
            print(f"  - {line}")
        return 1
    print(f"LULUS: {len(STATES)} cacat merah di Aturan 84 (dan hijau di 83 "
          f"aturan lama), {len(CONTROLS)} kontrol berperilaku benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
