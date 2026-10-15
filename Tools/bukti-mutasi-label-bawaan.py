#!/usr/bin/env python3
"""Buktikan Aturan 28 berbunyi pada label yang salah di parameter bernilai bawaan.

Kenapa berkas ini ada.

Aturan 28 mengklaim memeriksa 55 pemanggilan `TipePaket.metode(Label:)` di
`Apps/`. Terukur pada 15 Okt 2026, klaim itu **lebih sempit dari yang
terbaca**: 4 argumen berlabel di `Apps/` hari ini lolos dengan label yang
salah, dan 94 dari 1489 statika terindeks punya celah yang sama.

Penyebabnya satu baris di `matches()`:

    if not ddef and gl != dl:
        return False

`ddef` = parameter punya nilai bawaan. Jadi untuk **setiap** parameter bawaan,
label pemanggil **tidak pernah dibandingkan**. `VisualFrame.deepSky` — tiga
dari empat parameternya punya nilai bawaan — menerima label yang tidak ada:

    VisualFrame.deepSky(morphology:, fuzziness:, salahLabel:)
    -> "Bersih: 55 pemanggilan ... cocok dengan deklarasi"

Dan yang membuatnya berbahaya: ia melaporkan "55 pemanggilan cocok",
kalimat yang terdengar seperti bukti bahwa semuanya diperiksa.

**Yang membuat perbaikannya bukan sekadar menghapus `not ddef`.** Swift
mengizinkan argumen berlabel diberikan dalam **urutan apa pun**. Mencocokkan
per posisi memerahkan pemanggilan yang **sah**:

    EngineFactory.makeController(location: location, config: config)

`config` ada di posisi 1 pemanggil, berhadapan dengan `calibration` di
deklarasi — jadi pencocokan per posisi melaporkan "label salah" pada kode yang
dikompilasi hari ini. Terukur: dengan `matches()` per posisi, situs itu
**merah**. Gerbang yang memerah pada kode benar akan dimatikan orang, jadi
perbaikannya mencocokkan **per nama**, bukan per posisi.

Keadaan yang diukur (jalan di salinan bersih per keadaan, tidak menyentuh
sumber produksi — pelajaran dari harness yang pernah meninggalkan mutasi
hidup):

| # | keadaan                                     | harap  | kenapa |
|---|---|---|---|
| 0 | kode apa adanya                             | hijau  | gerbang tak boleh memerah pada kode benar |
| 1 | `deepSky` `elongation:` -> `salahLabel:`    | MERAH  | parameter bawaan: cacat asli            |
| 2 | `makeController` `config:` -> `salahLabel:` | MERAH  | idem, di situs lain                     |
| 3 | `makeController(location:config:)` dibalik  | hijau  | urutan argumen berlabel sah di Swift    |
| 4 | `jupiterBands(count:)` -> `salahLabel:`     | MERAH  | parameter TANPA bawaan: jangkar lama    |

Keadaan 3 dan 4 bukan hiasan, dan keduanya yang menjaga gerbangnya jujur:

- **Keadaan 3** satu-satunya yang membedakan "mencocokkan per nama" dari
  "mencocokkan per posisi". Tanpanya, perbaikan yang memerahkan kode benar
  lulus keadaan 1, 2, dan 4 dengan sempurna.
- **Keadaan 4** membuktikan arah yang **sudah** dijaga sebelum siklus ini
  masih dijaga. Perbaikan yang hanya menambah parameter bawaan dan merusak
  parameter wajib akan lulus 1 dan 2 — dan itu regresi.

**Non-vakum, diukur.** Setiap keadaan cacat dijalankan juga terhadap
`swift-ui-lint.sh` versi `origin/main`. Kalau versi lama juga merah, cacatnya
bukan yang ditutup perbaikan ini dan harness berhenti (exit 1). Tanpa arah
kedua, harness ini hanya membuktikan bahwa ia sepakat dengan dirinya sendiri.

Yang TIDAK diklaim
- Yang diukur **teks** `Apps/`, bukan kompilasi Swift. Gerbang ini sapu teks:
  ia tahu "label ini tidak ada di deklarasi", bukan "argumennya bertipe salah".
- Argumen **posisional** tetap dilewati (150 di `Apps/`), dengan alasan yang
  sama seperti sebelum siklus ini: urutannya tidak bisa dipastikan tanpa
  compiler.
- Tipe yang dideklarasi di `Apps/` tetap tidak diindeks — aturan ini menjaga
  pemakaian API **paket** dari view.
- `PointingLinkMessage.state(at:sigmaDeg:)` terukur lolos di kedua versi:
  penerimanya adalah **nilai**, bukan kualifikasi statis, jadi `QF` tidak
  melihatnya. Batas itu tidak ditutup siklus ini dan dinyatakan di sini
  alih-alih disangka tertutup.
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

sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penjaga sumber bersih, sama dgn harness lain)

WATCHED = [LINT, os.path.join(ROOT, "Apps"), os.path.join(ROOT, "Packages")]

RULE = "28"

# ── Jangkar ────────────────────────────────────────────────────────────────
# Jangkar **dibaca dari berkas yang disalin**, bukan ditulis mati: jangkar yang
# ditulis mati mengukur pohon kerja penulisnya, dan itu pernah membuat sebuah
# keadaan cacat dilaporkan hijau (Aturan 10, "PointingKit 787" vs 785).
DEEP_SKY = ("Apps/Shared/CelestialVisualView.swift",
            "elongation:", "salahLabel:")
MAKE_CONTROLLER = ("Apps/Shared/PointingEngine.swift",
                   "config: config)", "salahLabel: config)")
MAKE_CONTROLLER_SWAP = ("Apps/Shared/PointingEngine.swift",
                        "location: location, config: config)",
                        "config: config, location: location)")
JUPITER_BANDS = ("Apps/Shared/CelestialVisualView.swift",
                 "jupiterBands(count:", "jupiterBands(salahLabel:")


def require_clean() -> None:
    mutasi_sumber.require_clean_sources(WATCHED)


def copy_repo() -> str:
    """Salin pohon utuh. Salinan parsial membuat aturan lain berbunyi dan
    menenggelamkan tanda yang dicari (lihat docstring Aturan 10)."""
    workdir = tempfile.mkdtemp(prefix="label-bawaan-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build -cf - . '
         '| (cd "$2" && tar -xf -)', "copy", ROOT, workdir],
        check=True)
    return workdir


def run_lint(workdir: str, script_text: str | None = None) -> str:
    """Jalankan **salinan** skrip di dalam `workdir`.

    Kenapa salinannya: `swift-ui-lint.sh` melakukan `cd "$(dirname "$0")"`,
    jadi ia selalu memeriksa repo sungguhan apa pun `cwd`-nya. Versi pertama
    harness semacam ini menjalankan skrip repo dan seluruh keadaan dilaporkan
    hijau — harness-nya mengukur repo, bukan salinan yang disuntik.
    """
    script = os.path.join(workdir, "swift-ui-lint.sh")
    if script_text is not None:
        open(script, "w", encoding="utf-8").write(script_text)
        os.chmod(script, 0o755)
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run(["bash", script], cwd=workdir, capture_output=True,
                       text=True, env=env)
    return p.stdout + p.stderr


def finding(out: str) -> str:
    """Isi seksi Aturan 28 **sesudah judulnya**, bukan judulnya.

    Setiap aturan selalu mencetak `== Aturan N:` entah ia menemukan sesuatu
    atau tidak. Mencocokkan judulnya berarti tiap keadaan tampak berbunyi.
    """
    lines = out.splitlines()
    marks = [i for i, l in enumerate(lines) if l.startswith("== Aturan ")]
    for i, m in enumerate(marks):
        if not lines[m].startswith(f"== Aturan {RULE}:"):
            continue
        end = marks[i + 1] if i + 1 < len(marks) else len(lines)
        body = "\n".join(lines[m:end]).strip()
        if "Bersih" in body:
            return ""
        return body
    return ""


def fired(out: str) -> bool:
    return "GAGAL" in finding(out)


def old_lint() -> str:
    """Versi `origin/main`, untuk arah "cacat ini dulu lolos"."""
    p = subprocess.run(["git", "show", "origin/main:swift-ui-lint.sh"],
                       cwd=ROOT, capture_output=True, text=True)
    if p.returncode != 0:
        p = subprocess.run(["git", "show", "HEAD:swift-ui-lint.sh"],
                           cwd=ROOT, capture_output=True, text=True)
    return p.stdout


CASES = [
    # (nama, target, cari, ganti, harus_merah)
    ("0. kode apa adanya", None, None, None, False),
    ("1. deepSky elongation: -> salahLabel: (bawaan)",
     *DEEP_SKY, True),
    ("2. makeController config: -> salahLabel: (bawaan)",
     *MAKE_CONTROLLER, True),
    ("3. KONTROL: makeController(location:config:) dibalik — urutan sah",
     *MAKE_CONTROLLER_SWAP, False),
    ("4. jupiterBands count: -> salahLabel: (tanpa bawaan)",
     *JUPITER_BANDS, True),
]


def main() -> int:
    require_clean()
    old = old_lint()
    failures: list[str] = []

    for name, target, find, repl, must_fire in CASES:
        workdir = copy_repo()
        try:
            if target is not None:
                path = os.path.join(workdir, target)
                src = open(path, encoding="utf-8").read()
                if find not in src:
                    failures.append(
                        f"  {name}: jangkar {find!r} tak ditemukan di {target} "
                        f"— harness perlu disesuaikan, bukan aturannya")
                    continue
                open(path, "w", encoding="utf-8").write(
                    src.replace(find, repl, 1))

            out_new = run_lint(workdir)
            got = fired(out_new)
            if got != must_fire:
                failures.append(
                    f"  {name}: {'MERAH' if got else 'hijau'} padahal "
                    f"diharapkan {'merah' if must_fire else 'hijau'}")
                continue

            # Arah kedua: cacat yang wajib merah **harus lolos** di versi lama.
            # Kalau versi lama juga merah, cacatnya bukan milik perbaikan ini.
            if must_fire:
                out_old = run_lint(workdir, old)
                if fired(out_old):
                    failures.append(
                        f"  {name}: versi origin/main SUDAH merah — cacatnya "
                        f"bukan yang ditutup perbaikan ini")
                print(f"  {name}")
                print(f"      baru: MERAH (sesuai)   lama: hijau (lolos)")
                for line in finding(out_new).splitlines()[1:3]:
                    print("      " + line.strip())
            else:
                print(f"  {name}")
                print(f"      baru: hijau (sesuai)")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    print()
    if failures:
        print(f"GAGAL: {len(failures)} keadaan tak sesuai harapan")
        print("\n".join(failures))
        return 1
    print(f"SEMUA SESUAI: {len(CASES)} keadaan Aturan {RULE}, "
          f"arah dua (cacat merah, kode benar diam)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
