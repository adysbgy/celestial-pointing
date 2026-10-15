#!/usr/bin/env python3
"""Apakah Aturan 21 berbunyi pada **satu** kelas cacat, atau pada keempatnya?

Kenapa pengukuran ini ada, dan kenapa ia berkas terpisah.

`Tools/bukti-mutasi-gerbang-denyut.py` menguji empat keadaan cacat pada
Aturan 21 dan menuntut **keempatnya** merah. Dijalankan di atas `HEAD`
(commit `a229176`), ia keluar **exit 1** dengan empat keluhan:

    Aturan 21 / hasPulse dinegasikan (harus merah): hijau padahal diharapkan merah
    Aturan 21 / cabang hasPulse=true nol (harus merah): hijau padahal diharapkan merah
    Aturan 21 / hasPulse di argumen visual: (harus merah): hijau padahal diharapkan merah
    Aturan 21 / hasPulse sebagai label argumen (harus merah): hijau padahal diharapkan merah

Empat keadaan itu bukan karangan penulisnya. Docstring aturannya sendiri
mendaftarnya sebagai cacat yang **harus** ditangkapnya ("menyebut hasPulse"
tidak sama dengan "menggerbangi denyut"), dan dua di antaranya (3 dan 4)
adalah cerminan baterai yang sudah dibayar: denyut pada planet memaksa
`Canvas` digambar ulang 20x/detik untuk piksel yang identik.

Jadi berkas ini menjawab satu pertanyaan yang tidak bisa dijawab harness itu:
**cacat yang mana** yang benar-benar berbunyi hari ini? Ia mencetak satu baris
per keadaan supaya cakupan aturannya terukur, bukan disangka.

Cara mengukur: tiap keadaan disuntik ke **salinan pohon bersih** sendiri
(salinan baru per keadaan, jadi tidak ada mutasi keadaan sebelumnya yang bisa
terbawa), lalu `swift-ui-lint.sh` **di dalam salinan itu** dijalankan, dan
badan temuan Aturan 21 dibaca. Salinan utuh — bukan hanya `Apps/` — karena
aturan lain membaca `Packages/`, `project.yml`, dan `Tools/`; salinan parsial
membuat aturan-aturan itu berbunyi dan menenggelamkan tanda yang dicari.

Tidak ada berkas produksi yang disentuh: seluruh mutasi hidup di direktori
sementara. Karena itu berkas ini tidak perlu penjaga `require_clean_sources` —
ia mengukur salinan, bukan repo.

Pakai:
    python3 Tools/ukur-cakupan-aturan21.py        # 0 = semua sesuai harapan
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
RULE = "21"

# Situs suntik: pemanggilan `CelestialVisualView` di kartu jam — jalur yang
# benar-benar berdenyut. Jangkar dibaca dari berkas **pada saat jalan**; kalau
# ia tidak ada, berkas ini berhenti alih-alih melaporkan "sesuai harapan" atas
# keadaan yang tidak pernah disuntik.
TARGET = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
ANCHOR = "pulse: visual.hasPulse ? pulsePhase : 0)"

# (nama, harapan, penyuntik). `sunting` menulis ulang TARGET di dalam salinan;
# `injeksi` menambah satu view baru — itu membedakan "aturan berbunyi pada
# situs yang sudah ada" dari "aturan berbunyi pada baris yang ditulis besok".
KEADAAN = [
    ("kode benar (harus diam)", False, ("sunting", None)),
    ("gerbang dibuang (harus merah)", True, ("sunting", "pulse: pulsePhase)")),
    ("hasPulse dinegasikan (harus merah)", True,
     ("sunting", "pulse: !visual.hasPulse ? pulsePhase : 0)")),
    ("cabang hasPulse=true nol (harus merah)", True,
     ("sunting", "pulse: visual.hasPulse ? 0 : pulsePhase)")),
    ("hasPulse di argumen visual: (harus merah)", True,
     ("injeksi", "visual: CelestialVisual(kind: .moon).hasPulse "
                 "? CelestialVisual(kind: .moon) "
                 ": CelestialVisual(kind: .moon), pulse: 0.8")),
    ("hasPulse sebagai label argumen (harus merah)", True,
     ("injeksi", "visual: CelestialVisual(kind: .planet(.mars)), "
                 "hasPulse: true, pulse: 0.7")),
    ("pulse: 0 — kontrol negatif (harus diam)", False,
     ("sunting", "pulse: 0)")),
]

failures: list[str] = []


def copy_repo() -> str:
    workdir = tempfile.mkdtemp(prefix="cakupan21-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build '
         '--exclude="*/cangkang-tmp" -cf - . | (cd "$2" && tar -xf -)',
         "copy", ROOT, workdir],
        check=True)
    return workdir


def run_lint(workdir: str) -> str:
    """Jalankan **salinan** `swift-ui-lint.sh` di dalam `workdir`.

    Skripnya `cd "$(dirname "$0")"` di baris 24 — menjalankan yang ada di repo
    dengan `cwd=workdir` akan tetap memeriksa repo sungguhan, dan seluruh
    keadaan lalu dilaporkan hijau.
    """
    lint = os.path.join(workdir, "swift-ui-lint.sh")
    os.chmod(lint, 0o755)
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run(["bash", lint], cwd=workdir,
                       capture_output=True, text=True, env=env)
    return p.stdout + p.stderr


def finding(out: str) -> str | None:
    """Badan temuan Aturan 21, atau None kalau ia bersih.

    Setiap aturan selalu mencetak judulnya; yang menentukan berbunyi atau
    tidak adalah **badannya**. Mencocokkan judulnya saja akan membuat setiap
    keadaan tampak "berbunyi".
    """
    marks = list(re.finditer(r"^== Aturan \d+:.*$", out, re.M))
    header = re.compile(rf"^== Aturan {RULE}:.*$", re.M)
    for i, m in enumerate(marks):
        if not header.match(m.group(0)):
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(out)
        body = out[m.end():end].strip()
        if not body or body.startswith("Bersih"):
            return None
        return body
    return None


def jalankan(nama: str, cara: str, argumen: str | None) -> str | None:
    wd = copy_repo()
    try:
        path = os.path.join(wd, TARGET)
        src = open(path, encoding="utf-8").read()
        if cara == "sunting":
            if argumen is None:
                pass
            elif ANCHOR not in src:
                raise SystemExit(
                    f"  STOP: jangkar {ANCHOR!r} tidak ada di {TARGET} — "
                    "harness ini perlu disesuaikan, bukan aturannya")
            else:
                src = src.replace(ANCHOR, argumen, 1)
        else:
            view = ("\nstruct ZzzProbeDenyutView: View {\n"
                    "    var body: some View {\n        "
                    f"CelestialVisualView({argumen})\n"
                    "    }\n}\n")
            src = src.replace("import SwiftUI", "import SwiftUI" + view, 1)
        open(path, "w", encoding="utf-8").write(src)
        return finding(run_lint(wd))
    finally:
        shutil.rmtree(wd, ignore_errors=True)


def main() -> int:
    src = open(os.path.join(ROOT, TARGET), encoding="utf-8").read()
    if ANCHOR not in src:
        print(f"STOP: jangkar {ANCHOR!r} tidak ada di {TARGET}")
        return 1

    print("== Cakupan Aturan 21: cacat mana yang benar-benar berbunyi? ==")
    print(f"   aturan  : {LINT}")
    print(f"   jangkar : {TARGET}\n")

    berdiri = 0
    for nama, diharapkan, (cara, argumen) in KEADAAN:
        hasil = jalankan(nama, cara, argumen)
        nyata = hasil is not None
        tanda = "OK  " if nyata == diharapkan else "BEDA"
        if nyata:
            berdiri += 1
            baris = hasil.splitlines()[0].strip()
        else:
            baris = "(bersih — tidak ada temuan)"
        print(f"  {tanda} {nama}")
        print(f"       {baris[:110]}")
        if nyata != diharapkan:
            kata = "merah" if diharapkan else "hijau"
            failures.append(
                f"  Aturan {RULE} / {nama}: {'merah' if nyata else 'hijau'} "
                f"padahal diharapkan {kata}")

    cacat = [k for k in KEADAAN if k[1]]
    print(f"\n  {len(cacat)} keadaan cacat dinyatakan; {berdiri} dari "
          f"{len(KEADAAN)} keadaan total berbunyi hari ini.")

    if failures:
        print("\nCAKUPAN BELUM LENGKAP:")
        for f in failures:
            print(f)
        return 1
    print("\nBersih: cakupan Aturan 21 sesuai harapan pada seluruh keadaan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
