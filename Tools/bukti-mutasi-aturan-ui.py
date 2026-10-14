#!/usr/bin/env python3
"""Buktikan tujuh gerbang sapu UI **berbunyi pada hal yang mereka klaim**.

Kenapa berkas ini ada.

`swift-ui-lint.sh` memuat 35 aturan yang **tidak dikompilasi siapa pun** dan
tidak punya uji Swift. Aturan 1, 3, 7, 15, 18, 23, 24, 31, 32, 33, 34, 35
sudah punya pembuktian (langkah `red-lint.sh` di CI atau harness khusus).
Dua puluh dua aturan sisanya tidak punya satu pun rekam jejak bahwa ia bisa
keluar merah — dan gerbang yang tidak pernah diukur merah persis sama dengan
gerbang yang tidak mengukur apa pun.

Siklus ini menutup tujuh di antaranya, yang semuanya punya situs suntik nyata
di `Apps/` dan kegagalan yang terlihat pengguna:

  - Aturan 4  — teks UI literal tanpa entri katalog (Bahasa Inggris diam)
  - Aturan 9  — WidgetKit tanpa pemanggil reload (complication membeku)
  - Aturan 10 — hitungan uji di README menyimpang dari kenyataan
  - Aturan 14 — izin sistem tanpa terjemahan InfoPlist.strings
  - Aturan 22 — judul baris memakai kunci nilainya (tampil "Gelap: Gelap")
  - Aturan 25 — CelestialVisual.X yang bukan anggota (build merah di macOS)
  - Aturan 27 — label salah pada `TipePaket(Label:)` **berkualifikasi**, bentuk
                yang repo ini benar-benar tulis (`CelestialVisual.RGBComponents`).
                Sebelum siklus ini ia hanya melihat bentuk tak-berkualifikasi,
                sehingga `objectID:` -> `objectId:` di
                `Apps/Shared/PointingEngine.swift` lolos seluruh 35 aturan
                dengan exit 0 — padahal itu galat kompilasi yang pasti.

Yang diukur tiap keadaan: cacat yang diklaim disuntik, aturan **dinamai**
benar-benar melaporkan temuan (bukan aturan lain yang kebetulan berbunyi),
dan keadaan kontrol negatif (kode benar) tetap diam. Tanpa keadaan kontrol,
harness yang memerah pada segala sesuatu akan lulus — kelas cacat yang sama
persis dengan yang sedang ditutup.

Berkas ini **tidak** memutasi sumber produksi: ia menyuntik di atas salinan
bersih per keadaan, supaya tidak ada pemulihan yang bisa gagal (pelajaran dari
harness mutasi yang pernah meninggalkan mutasi hidup).

Kenapa tidak memakai `red-lint.sh` untuk semua. `red-lint.sh` menyuntik satu
cacat lalu menuntut `swift-ui-lint.sh` keluar bukan-nol; ia tidak membedakan
aturan mana yang berbunyi. Enam aturan di sini punya bentuk cacat berbeda, dan
masing-masing wajib berbunyi atas cacatnya sendiri — bukan sekadar "ada yang
merah".
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
import mutasi_sumber  # noqa: E402  (penjaga sumber bersih, sama dengan harness lain)

WATCHED = [LINT, os.path.join(ROOT, "Apps"),
           os.path.join(ROOT, "README.md")]


def require_clean() -> None:
    """Hentikan kalau yang dibaca sudah menyimpang dari HEAD."""
    mutasi_sumber.require_clean_sources(WATCHED)


def run_lint(workdir: str) -> tuple[int, str]:
    """Jalankan **salinan** `swift-ui-lint.sh` di dalam `workdir`.

    Kenapa salinannya, bukan yang di repo: skripnya melakukan
    `cd "$(dirname "$0")"` di baris 24, jadi ia **selalu** memeriksa repo
    sungguhan apa pun `cwd` yang diberikan. Versi pertama harness ini
    menjalankan skrip repo dengan `cwd=workdir` dan karena itu seluruh
    keadaan dilaporkan hijau — harness-nya mengukur repo, bukan salinan
    yang disuntik. Salinan skripnya yang membuat `dirname "$0"` menunjuk
    ke `workdir`.
    """
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    script = os.path.join(workdir, "swift-ui-lint.sh")
    p = subprocess.run(["bash", script], cwd=workdir, capture_output=True,
                       text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def finding(out: str, rule: str) -> str:
    """Ambil **temuan** Aturan `rule`, bukan judulnya.

    Setiap aturan selalu mencetak `== Aturan N: …` entah ia menemukan sesuatu
    atau tidak. Mencocokkan judul itu berarti setiap keadaan tampak "berbunyi"
    — kelas cacat yang persis ditutup `bukti-mutasi-aturan18-redlint.py` untuk
    `red-lint.sh`. Yang diambil di sini adalah baris **sesudah** judul, sampai
    judul aturan berikutnya; kalau bagian itu kosong atau berawalan "Bersih",
    aturannya diam.
    """
    header = re.compile(rf'^== Aturan {rule}:.*$', re.M)
    marks = list(re.finditer(r'^== Aturan \d+:.*$', out, re.M))
    for i, m in enumerate(marks):
        if not header.match(m.group(0)):
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(out)
        body = out[m.end():end].strip()
        if not body or body.startswith("Bersih"):
            return ""
        return body
    return ""


def fired_on(out: str, rule: str, token: str) -> bool:
    """Aturan `rule` melaporkan temuan yang memuat `token`."""
    body = finding(out, rule)
    return bool(body) and token in body


def inject(workdir: str, target: str, snippet: str) -> None:
    path = os.path.join(workdir, target)
    lines = open(path, encoding="utf-8").read().split("\n")
    last = max(i for i, l in enumerate(lines) if l.startswith("import "))
    out = lines[:last + 1] + [""] + snippet.split("\n") + lines[last + 1:]
    open(path, "w", encoding="utf-8").write("\n".join(out))


def copy_repo() -> str:
    """Salin **seluruh pohon** yang dibaca gerbang sapu, kecuali `.git`/`.build`.

    Kenapa tidak hanya `Apps/`. Versi pertama menyalin `Apps/` saja, dan
    akibatnya aturan yang membaca `Packages/`, `project.yml`, `Tools/`, atau
    `.github/` **semuanya berbunyi** di salinan itu — Aturan 5 (kunci
    XcodeGen), 6 (paritas katalog paket), 10 (hitungan README), 14, 19, 25,
    30, 34, 35. Gejalanya menipu: Aturan 10 dan 25 dilaporkan "sudah merah
    pada kode benar", padahal yang merah adalah salinan yang tidak lengkap —
    dan keadaan cacatnya jadi tidak bisa dibedakan dari kebisingan itu.

    Jadi yang disalin adalah pohon utuh. `Tools/bukti-mutasi-*` ikut; itu tidak
    apa-apa, dan mengecualikannya berarti memilih-milih isi yang dibaca
    aturan.
    """
    workdir = tempfile.mkdtemp(prefix="gerbang-aturan-ui-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build '
         '--exclude="*/cangkang-tmp" -cf - . | (cd "$2" && tar -xf -)',
         "copy", ROOT, workdir],
        check=True)
    return workdir


def expect(rule: str, name: str, fired: bool, must_fire: bool,
           failures: list[str]) -> None:
    if fired != must_fire:
        failures.append(
            f"  Aturan {rule} / {name}: {'MERAH' if fired else 'hijau'} "
            f"padahal diharapkan {'merah' if must_fire else 'hijau'}")


# ── Aturan 4: teks UI literal tanpa entri katalog ──────────────────────────
# Suntik baris yang memakai judul literal yang tidak ada di katalog.
R4_TARGET = "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"
R4_ANCHOR = "row(DiagnosticsText.rowState, engine.snapshot.state.shortLabel)"


def check_rule_4(failures: list[str]) -> None:
    """Cacat (judul literal tanpa kunci) harus berbunyi; kode benar harus diam."""
    workdir = copy_repo()
    path = os.path.join(workdir, R4_TARGET)
    try:
        clean = open(path, encoding="utf-8").read()

        # Kontrol negatif: kode apa adanya harus DIAM pada aturan ini.
        _, out = run_lint(workdir)
        expect("4", "kode benar (harus diam)",
               bool(finding(out, "4")), False, failures)

        # Cacat: judul baris diganti literal yang tidak ada di katalog.
        open(path, "w", encoding="utf-8").write(
            clean.replace(R4_ANCHOR,
                          'row(Text("ZzzStateXYZ"), '
                          'engine.snapshot.state.shortLabel)', 1))
        _, out = run_lint(workdir)
        expect("4", "literal tanpa kunci (harus merah)",
               fired_on(out, "4", "ZzzStateXYZ"), True, failures)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


# ── Aturan 9: WidgetKit tanpa pemanggil reload ─────────────────────────────
R9_TARGET = "Apps/PointAndKnowWatch/Sources/PointAndKnowWatchWatchApp.swift"
R9_ANCHOR = ("engine.complicationReload = "
             "{ WidgetCenter.shared.reloadAllTimelines() }")


def check_rule_9(failures: list[str]) -> None:
    workdir = copy_repo()
    path = os.path.join(workdir, R9_TARGET)
    try:
        clean = open(path, encoding="utf-8").read()

        _, out = run_lint(workdir)
        expect("9", "kode benar (harus diam)",
               bool(finding(out, "9")), False, failures)

        open(path, "w", encoding="utf-8").write(
            clean.replace(R9_ANCHOR, "engine.complicationReload = { }", 1))
        _, out = run_lint(workdir)
        expect("9", "reload dihapus (harus merah)",
               fired_on(out, "9", "ComplicationWidget"), True, failures)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


# ── Aturan 10: hitungan uji di README menyimpang ───────────────────────────
def check_rule_10(failures: list[str]) -> None:
    workdir = copy_repo()
    readme = os.path.join(workdir, "README.md")
    try:
        clean = open(readme, encoding="utf-8").read()

        _, out = run_lint(workdir)
        expect("10", "kode benar (harus diam)",
               bool(finding(out, "10")), False, failures)

        # Angkanya dibaca dari README **yang disalin**, bukan ditulis mati.
        # Versi pertama menulis `PointingKit 787`, angka dari pohon kerja saat
        # harness ditulis — di HEAD angkanya 785, jadi penggantiannya tidak
        # cocok, README tetap benar, dan keadaan cacatnya dilaporkan hijau.
        # Jangkar yang ditulis mati mengukur pohon kerja penulisnya.
        m = re.search(r"(PointingKit )(\d+)", clean)
        if not m:
            failures.append("  Aturan 10: 'PointingKit <n>' tidak ditemukan di "
                            "README — harness perlu disesuaikan")
            return
        bumped = f"{m.group(1)}{int(m.group(2)) + 1}"
        open(readme, "w", encoding="utf-8").write(
            clean[:m.start()] + bumped + clean[m.end():])
        _, out = run_lint(workdir)
        expect("10", f"hitungan +1 ({bumped}, harus merah)",
               fired_on(out, "10", bumped), True, failures)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


# ── Aturan 14: izin sistem tanpa terjemahan InfoPlist.strings ──────────────
R14_TARGET = "Apps/Shared/Resources/en.lproj/InfoPlist.strings"
R14_ANCHOR = 'NSLocalNetworkUsageDescription = "Local network access is used'


def check_rule_14(failures: list[str]) -> None:
    workdir = copy_repo()
    path = os.path.join(workdir, R14_TARGET)
    try:
        clean = open(path, encoding="utf-8").read()

        _, out = run_lint(workdir)
        expect("14", "kode benar (harus diam)",
               bool(finding(out, "14")), False, failures)

        open(path, "w", encoding="utf-8").write(
            clean.replace(R14_ANCHOR, "// " + R14_ANCHOR, 1))
        _, out = run_lint(workdir)
        expect("14", "terjemahan en dihapus (harus merah)",
               fired_on(out, "14", "NSLocalNetworkUsageDescription"),
               True, failures)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


# ── Aturan 22: judul baris memakai kunci nilainya ──────────────────────────
R22_TARGET = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
R22_ANCHOR = ("row(TextLocalization.text(.skyContextMoonPhase),\n"
              "                        NumberFormat.percent(fraction, "
              "fractionDigits: 0))")
R22_DEFECT = ("row(TextLocalization.text(.skyContextMoonPhase),\n"
              "                        TextLocalization.text("
              ".skyContextMoonPhase))")


def check_rule_22(failures: list[str]) -> None:
    workdir = copy_repo()
    path = os.path.join(workdir, R22_TARGET)
    try:
        clean = open(path, encoding="utf-8").read()
        if R22_ANCHOR not in clean:
            failures.append("  Aturan 22: jangkar hilang — harness perlu "
                            "disesuaikan, bukan aturannya")
            return

        _, out = run_lint(workdir)
        expect("22", "kode benar (harus diam)",
               bool(finding(out, "22")), False, failures)

        open(path, "w", encoding="utf-8").write(
            clean.replace(R22_ANCHOR, R22_DEFECT, 1))
        _, out = run_lint(workdir)
        expect("22", "judul==nilai (harus merah)",
               fired_on(out, "22", "skyContextMoonPhase"), True, failures)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


# ── Aturan 25: CelestialVisual.X yang bukan anggota ────────────────────────
R25_TARGET = "Apps/Shared/CelestialVisualView.swift"
R25_ANCHOR = "let dark = CelestialVisual.moonSphereDark(base)"


def check_rule_25(failures: list[str]) -> None:
    workdir = copy_repo()
    path = os.path.join(workdir, R25_TARGET)
    try:
        clean = open(path, encoding="utf-8").read()
        if R25_ANCHOR not in clean:
            failures.append("  Aturan 25: jangkar hilang — harness perlu "
                            "disesuaikan, bukan aturannya")
            return

        _, out = run_lint(workdir)
        expect("25", "kode benar (harus diam)",
               bool(finding(out, "25")), False, failures)

        open(path, "w", encoding="utf-8").write(
            clean.replace(R25_ANCHOR,
                          "let dark = CelestialVisual.ZzzNonMemberXYZ(base)",
                          1))
        _, out = run_lint(workdir)
        expect("25", "anggota palsu (harus merah)",
               fired_on(out, "25", "ZzzNonMemberXYZ"), True, failures)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


# ── Aturan 27: label argumen `TipePaket(Label:)` — bentuk BERKUALIFIKASI ────
#
# Kenapa keadaan ini ada, dan kenapa dua cacat sekaligus.
#
# Bentuk yang repo ini benar-benar tulis adalah bentuk **berkualifikasi**
# (`CelestialVisual.RGBComponents(…)`), karena `CelestialVisual` adalah tipe
# bersarang di paket. Versi Aturan 27 sebelum siklus ini hanya mencocokkan
# pemanggilan tak-berkualifikasi, jadi dua cacat nyata lolos seluruh 35 aturan
# dengan exit 0:
#
#   - `Apps/Shared/PointingEngine.swift` — `objectID:` menjadi `objectId:`
#   - `Apps/Shared/CelestialVisualView.swift` — `blue:` dibuang
#
# Keduanya bukan galat yang *mungkin* lolos kompilasi; keduanya galat
# kompilasi yang **pasti**. Yang pertama adalah yang paling mahal: ia menahan
# CI macOS penuh (~4 menit) ditambah satu push untuk kesalahan yang bisa
# ditangkap dalam 10 detik.
#
# Dua cacat diuji, bukan satu, karena keduanya menempuh jalur berbeda di dalam
# aturan: yang pertama adalah `init` yang hidup di dalam `extension`, yang
# kedua adalah `init` tipe bersarang biasa. Perbaikan yang hanya menangani satu
# di antaranya akan lulus kalau harness ini hanya memeriksa satu.
#
# Kontrol negatifnya dua lapis: kode benar harus diam (menangkap perbaikan yang
# terlalu longgar), dan cacat yang sama ditulis **tanpa kualifikasi**
# (`RGBComponents(red: 1, green: 1)`) harus tetap merah — kalau tidak, perbaikan
# ini bisa saja menyempitkan gerbang tanpa suara, dan gerbang yang menyempit
# selalu hijau.
R27_ENGINE = "Apps/Shared/PointingEngine.swift"
R27_ENGINE_ANCHOR = "CelestialVisual.Planet(objectID: object.id)"
R27_ENGINE_DEFECT = "CelestialVisual.Planet(objectId: object.id)"

R27_VIEW = "Apps/Shared/CelestialVisualView.swift"
R27_VIEW_ANCHOR = "CelestialVisual.RGBComponents(red: 1, green: 1, blue: 1)"
R27_VIEW_DEFECT = "CelestialVisual.RGBComponents(red: 1, green: 1)"
R27_VIEW_UNQUALIFIED = "RGBComponents(red: 1, green: 1)"


def check_rule_27(failures: list[str]) -> None:
    """Label salah pada pemanggilan berkualifikasi harus berbunyi."""
    workdir = copy_repo()
    engine = os.path.join(workdir, R27_ENGINE)
    view = os.path.join(workdir, R27_VIEW)
    try:
        engine_clean = open(engine, encoding="utf-8").read()
        view_clean = open(view, encoding="utf-8").read()
        for path, anchor in ((R27_ENGINE, R27_ENGINE_ANCHOR),
                             (R27_VIEW, R27_VIEW_ANCHOR)):
            if anchor not in open(os.path.join(workdir, path),
                                  encoding="utf-8").read():
                failures.append(
                    f"  Aturan 27: jangkar `{anchor}` hilang di {path} — "
                    "harness perlu disesuaikan, bukan aturannya")
                return

        _, out = run_lint(workdir)
        expect("27", "kode benar (harus diam)",
               bool(finding(out, "27")), False, failures)

        # Cacat 1: label salah pada init di dalam `extension`.
        open(engine, "w", encoding="utf-8").write(
            engine_clean.replace(R27_ENGINE_ANCHOR, R27_ENGINE_DEFECT, 1))
        _, out = run_lint(workdir)
        expect("27", "objectID: -> objectId: (harus merah)",
               fired_on(out, "27", "objectId"), True, failures)
        open(engine, "w", encoding="utf-8").write(engine_clean)

        # Cacat 2: label sah dibuang pada tipe bersarang biasa.
        open(view, "w", encoding="utf-8").write(
            view_clean.replace(R27_VIEW_ANCHOR, R27_VIEW_DEFECT, 1))
        _, out = run_lint(workdir)
        expect("27", "blue: dibuang (harus merah)",
               fired_on(out, "27", "RGBComponents(red:, green:)"),
               True, failures)
        open(view, "w", encoding="utf-8").write(view_clean)

        # Non-vakum: jalur LAMA tak-berkualifikasi harus tetap berbunyi.
        open(view, "w", encoding="utf-8").write(
            view_clean.replace(R27_VIEW_ANCHOR, R27_VIEW_UNQUALIFIED, 1))
        _, out = run_lint(workdir)
        expect("27", "jalur lama tak-berkualifikasi (harus tetap merah)",
               fired_on(out, "27", "RGBComponents(red:, green:)"),
               True, failures)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def main() -> int:
    require_clean()
    failures: list[str] = []
    check_rule_4(failures)
    check_rule_9(failures)
    check_rule_10(failures)
    check_rule_14(failures)
    check_rule_22(failures)
    check_rule_25(failures)
    check_rule_27(failures)
    if failures:
        print("GERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        print("\n".join(failures))
        return 1
    print("Bersih: Aturan 4, 9, 10, 14, 22, 25, 27 masing-masing berbunyi "
          "pada cacat yang diklaimnya (dan diam pada kode yang benar).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
