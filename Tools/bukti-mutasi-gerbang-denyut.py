#!/usr/bin/env python3
"""Buktikan Aturan 21 (denyut gambar digerbangi `hasPulse`) **berbunyi**.

Kenapa berkas ini ada.

Aturan 21 menjaga dua hal sekaligus, dan keduanya tentang baterai pada
perangkat yang paling peduli baterai:

  - `Canvas` digambar ulang setiap kali nilai yang ditangkapnya berubah.
    `pulse` yang bergerak 20x/detik memaksa planet, Bulan, dan Matahari
    digambar ulang 20x/detik untuk piksel yang identik — denyut hanya
    dibaca `drawStar`.
  - Bintang yang seharusnya berdenyut halus menjadi diam bila gerbangnya
    terbalik.

Keduanya tidak menghasilkan *warning*, tidak bisa diuji di Linux (`Apps/`
tidak pernah dibangun di sana), dan tidak terlihat di tangkapan layar
statis. Jadi satu-satunya penjaganya adalah sapu teks, dan sebelum harness
ini ia tidak punya rekam jejak bahwa ia bisa keluar merah.

Cacat yang ditemukan saat menulisnya, dan lebih berbahaya dari yang dikejar.

Versi pertama aturan ini menjalankan `re.search(r"\\bhasPulse\\b", args)`
atas **seluruh** daftar argumen. Terukur, empat keadaan cacat — masing-masing
menyebut kata `hasPulse`, masing-masing **hijau**:

  1. `pulse: !visual.hasPulse ? pulsePhase : 0`
     Denyut justru mengalir ke planet/Bulan/Matahari dan mati pada bintang:
     kebalikan dari maksud aturan ini.
  2. `pulse: visual.hasPulse ? 0 : pulsePhase`
     Cabang benarnya nol, jadi bintang tidak pernah berdenyut.
  3. `visual: v.hasPulse ? v : v, pulse: 0.8`
     `hasPulse` hidup di argumen `visual:`; denyutnya tanpa gerbang.
  4. `hasPulse: true, pulse: 0.7`
     Sebuah **label argumen** bernama `hasPulse`, bukan gerbang.

Keempatnya punya kesamaan yang membuatnya bertahan: teksnya **menyebut**
`hasPulse`, jadi tinjauan kode membacanya sebagai sudah digerbangi. Yang
membedakan gerbang sungguhan bukan keberadaan nama itu, melainkan
**posisinya** — di dalam ekspresi yang menghasilkan nilai denyutnya.

Yang diukur tiap keadaan: cacatnya disuntik, Aturan 21 **dinamai**
benar-benar melaporkan temuan (bukan aturan lain yang kebetulan berbunyi),
dan keadaan kontrol negatif tetap diam. Tanpa kontrol negatif, harness yang
memerah pada segala sesuatu akan lulus — kelas cacat yang sama persis
dengan yang sedang ditutup.

Kenapa keadaan 5 dan 6 (diinjeksi sebagai view baru) ikut diuji.
Keadaan 1–4 menyunting **situs yang sudah ada**. Itu membuktikan aturan
berbunyi hari ini, tetapi tidak membuktikan ia berbunyi pada **baris yang
ditulis besok** di berkas lain — dan kelas cacat ini (aturan UI yang kembali
muncul di berkas yang ditambahkan belakangan) sudah beberapa kali
menutup siklus di repo ini.

Yang TIDAK diklaim harness ini.

  - Ia mengukur **teks** `Apps/`, bukan piksel perangkat. Yang dibuktikan:
    keempat keadaan cacat berbunyi, dan kode yang benar diam.
  - Gerbang yang sah namun ditulis di variabel perantara (`let p =
    visual.hasPulse ? fase : 0` lalu `pulse: p`) tetap hijau — batas yang
    dinyatakan di docstring aturannya, bukan disangka tertutup.
  - Ia **tidak** membuktikan `CelestialVisual.hasPulse` benar secara
    tampilan; itu milik `CelestialVisualTests` di Linux.

Berkas ini tidak memutasi sumber produksi: ia menyuntik di atas salinan
bersih per keadaan, supaya tidak ada pemulihan yang bisa gagal.
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

WATCHED = [LINT, os.path.join(ROOT, "Apps")]

RULE = "21"

# Situs suntik: pemanggilan `CelestialVisualView` di kartu jam, jalur yang
# benar-benar berdenyut. Jangkar dibaca dari berkas pada saat jalan dan
# kegagalannya dicetak sebagai LEWAT — bukan dilaporkan lulus.
TARGET = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
ANCHOR = "pulse: visual.hasPulse ? pulsePhase : 0)"

failures: list[str] = []


def copy_repo() -> str:
    """Salin seluruh pohon yang dibaca gerbang sapu, kecuali `.git`/`.build`.

    Kenapa utuh, bukan hanya `Apps/`. Aturan lain membaca `Packages/`,
    `project.yml`, dan `Tools/`; salinan parsial membuat semuanya berbunyi
    dan menenggelamkan tanda yang dicari — cacat yang sama persis dengan
    versi pertama `bukti-mutasi-aturan-ui.py`.
    """
    workdir = tempfile.mkdtemp(prefix="gerbang-denyut-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build '
         '--exclude="*/cangkang-tmp" -cf - . | (cd "$2" && tar -xf -)',
         "copy", ROOT, workdir],
        check=True)
    return workdir


def run_lint(workdir: str) -> tuple[int, str]:
    """Jalankan **salinan** `swift-ui-lint.sh` di dalam `workdir`.

    Skripnya melakukan `cd "$(dirname "$0")"` di baris 24, jadi menjalankan
    yang ada di repo dengan `cwd=workdir` akan tetap memeriksa repo
    sungguhan — seluruh keadaan lalu dilaporkan hijau.
    """
    lint = os.path.join(workdir, "swift-ui-lint.sh")
    os.chmod(lint, 0o755)
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run(["bash", lint], cwd=workdir,
                       capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def finding(out: str, rule: str) -> str | None:
    """Ambil badan temuan Aturan `rule`, atau None kalau ia bersih.

    Setiap aturan selalu mencetak `== Aturan N: …` entah ia menemukan
    sesuatu atau tidak. Mencocokkan judulnya berarti setiap keadaan tampak
    "berbunyi". Yang diambil di sini adalah badan **sesudah** judul, sampai
    judul aturan berikutnya.
    """
    marks = list(re.finditer(r"^== Aturan \d+:.*$", out, re.M))
    header = re.compile(rf"^== Aturan {rule}:.*$", re.M)
    for i, m in enumerate(marks):
        if not header.match(m.group(0)):
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(out)
        body = out[m.end():end].strip()
        if not body or body.startswith("Bersih"):
            return None
        return body
    return None


def expect(nama: str, fired: bool, diharapkan: bool) -> None:
    if fired == diharapkan:
        print(f"  OK   {nama}")
        return
    kata = "merah" if diharapkan else "hijau"
    nyata = "merah" if fired else "hijau"
    failures.append(f"  Aturan {RULE} / {nama}: {nyata} padahal diharapkan {kata}")


def keadaan_sunting(nama: str, baru: str, diharapkan: bool) -> None:
    """Sunting `ANCHOR` di salinan bersih, lalu jalankan aturannya."""
    wd = copy_repo()
    try:
        path = os.path.join(wd, TARGET)
        src = open(path, encoding="utf-8").read()
        if ANCHOR not in src:
            failures.append(f"  Aturan {RULE} / {nama}: jangkar hilang — "
                            "harness perlu disesuaikan, bukan aturannya")
            return
        open(path, "w", encoding="utf-8").write(src.replace(ANCHOR, baru, 1))
        _, out = run_lint(wd)
        expect(nama, finding(out, RULE) is not None, diharapkan)
    finally:
        shutil.rmtree(wd, ignore_errors=True)


def keadaan_injeksi(nama: str, argumen: str, diharapkan: bool) -> None:
    """Suntik satu view baru ke `TARGET`, lalu jalankan aturannya.

    Kenapa injeksi, bukan suntingan situs yang sudah ada: keadaan 1–4
    membuktikan aturan berbunyi **hari ini**. Yang tidak dibuktikannya adalah
    baris yang ditulis **besok** di berkas lain — dan kelas cacat "aturan UI
    kembali muncul di berkas yang ditambahkan belakangan" sudah beberapa kali
    menutup siklus di repo ini.
    """
    wd = copy_repo()
    try:
        path = os.path.join(wd, TARGET)
        src = open(path, encoding="utf-8").read()
        view = ("\nstruct ZzzProbeDenyutView: View {\n"
                "    var body: some View {\n        "
                f"CelestialVisualView({argumen})\n"
                "    }\n}\n")
        open(path, "w", encoding="utf-8").write(
            src.replace("import SwiftUI", "import SwiftUI" + view, 1))
        _, out = run_lint(wd)
        expect(nama, finding(out, RULE) is not None, diharapkan)
    finally:
        shutil.rmtree(wd, ignore_errors=True)


def cek() -> None:
    # Pra-syarat jangkar. Kalau ini tidak ada, seluruh harness di bawah
    # mengukur keadaan yang tidak pernah disuntik — dan melaporkan hijau
    # atas ketiadaan.
    src = open(os.path.join(ROOT, TARGET), encoding="utf-8").read()
    if ANCHOR not in src:
        print(f"LEWAT: jangkar {ANCHOR!r} tidak ada di {TARGET} — "
              "harness perlu disesuaikan")
        sys.exit(1)
    print(f"  jangkar: {ANCHOR!r} ada di {TARGET}")

    # ── Keadaan 1: kode benar -> diam ───────────────────────────────────
    # Ini yang paling penting. Aturan yang memerah pada kode yang benar akan
    # dimatikan orang, dan aturan yang dimatikan tidak menjaga apa pun.
    wd = copy_repo()
    try:
        _, out = run_lint(wd)
        expect("kode benar (harus diam)", finding(out, RULE) is not None, False)
    finally:
        shutil.rmtree(wd, ignore_errors=True)

    # ── Keadaan 2: gerbang dinegasikan -> merah ─────────────────────────
    # Satu-satunya dari keempat yang mengubah layar **sekaligus** mengosongkan
    # baterai: denyut mengalir ke planet/Bulan/Matahari, mati pada bintang.
    keadaan_sunting("hasPulse dinegasikan (harus merah)",
                    "pulse: !visual.hasPulse ? pulsePhase : 0)", True)

    # ── Keadaan 3: cabang benar nol -> merah ────────────────────────────
    # `hasPulse` ada dan tidak dinegasikan, tetapi bintangnya tidak pernah
    # berdenyut. Tanpa keadaan ini, "menyebut hasPulse" sudah cukup untuk
    # lolos walau denyutnya mati.
    keadaan_sunting("cabang hasPulse=true nol (harus merah)",
                    "pulse: visual.hasPulse ? 0 : pulsePhase)", True)

    # ── Keadaan 4: gerbang dibuang -> merah ─────────────────────────────
    keadaan_sunting("gerbang dibuang (harus merah)",
                    "pulse: pulsePhase)", True)

    # ── Keadaan 5: `hasPulse` di argumen `visual:` -> merah ─────────────
    keadaan_injeksi("hasPulse di argumen visual: (harus merah)",
                    "visual: CelestialVisual(kind: .moon).hasPulse "
                    "? CelestialVisual(kind: .moon) "
                    ": CelestialVisual(kind: .moon), pulse: 0.8", True)

    # ── Keadaan 6: `hasPulse` sebagai label argumen -> merah ────────────
    keadaan_injeksi("hasPulse sebagai label argumen (harus merah)",
                    "visual: CelestialVisual(kind: .planet(.mars)), "
                    "hasPulse: true, pulse: 0.7", True)

    # ── Keadaan 7: kontrol negatif — `pulse: 0` harus diam ──────────────
    # Denyut nol adalah keadaan yang **sah**: itulah yang dikirim jam saat
    # layar redup. Aturan yang memerah di sini memaksa setiap pemanggil
    # menulis gerbang untuk nilai yang memang nol.
    keadaan_sunting("pulse: 0 — kontrol negatif (harus diam)",
                    "pulse: 0)", False)


def main() -> int:
    mutasi_sumber.require_clean_sources(WATCHED)
    print("== Buktikan Aturan 21 berbunyi pada denyut yang tak digerbangi ==")
    cek()
    if failures:
        print("\nGERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        for f in failures:
            print(f)
        return 1
    print("\nBersih: Aturan 21 berbunyi pada keempat keadaan cacat denyut, "
          "dan diam pada kode yang benar serta pada pulse yang memang nol.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
