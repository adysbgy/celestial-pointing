#!/usr/bin/env python3
"""Buktikan Aturan 20 (permukaan kartu tidak dirakit dari warna yang tak diuji) **berbunyi**.

Kenapa berkas ini ada.

Aturan 20 menjaga janji kontras yang paling keras di app ini: brief menuntut
**>= 4.5:1 (WCAG)** untuk teks, dan satu-satunya cara janji itu bertahan adalah
kalau setiap permukaan kartu datang dari `SurfacePalette` yang kontrasnya sudah
dihitung terhadap semua nada. View yang merakit latarnya sendiri dengan
`tone.color.opacity(0.12)` menghasilkan warna yang **tidak ada di palet**, jadi
tidak ada satu pun uji kontras yang melihatnya.

Cacat itu nyata dan sudah dibayar repo ini. Kartu tahap kalibrasi dulu memakai
`phaseTone.color.opacity(0.12)`; di mode malam nada paling redup yang benar-benar
dipakai (`.neutral`, merah 0.94) di atas latar malam jatuh ke **4.32:1** — di
bawah ambang 4.5. Yang membuatnya sunyi: katalognya benar, `shortLabel`-nya
benar, teksnya sendiri berwarna nada yang sama. Yang salah hanya warnanya, dan
tidak ada gerbang lain yang menghitung campuran itu.

Sampai siklus ini Aturan 20 **tidak punya satu pun rekam jejak bahwa ia bisa
keluar merah**. Ia hijau sejak hari ditulis, dan di repo ini "hijau sejak hari
ditulis" sudah berkali-kali berarti "tidak mengukur apa pun".

Cacat yang ditemukan dengan mengukur, bukan membaca.

Versi lama aturan ini mencocokkan polanya atas **satu baris** pada satu waktu.
Terukur, cacat asli yang **sama** lolos begitu ia diformat berbeda:

    Text("x").background(
        tone.color.opacity(0.12))          <-- HIJAU pada versi lama

dan begitu juga `.color` yang diakhiri baris lalu `.opacity(0.12)`. Jadi yang
menentukan apakah aturan ini menggigit adalah **gaya pemformatan**, bukan ada
tidaknya cacat — dan repo ini menulis rantai modifier multi-baris di banyak
tempat. Cacat yang sama sudah bisa masuk `main` tanpa satu pun gerbang berbunyi.

Perbaikannya: argumen `.(background|fill)(` diambil **secara berimbang** (kurung
dihitung, jadi pemanggilan bersarang ikut terbaca), komentar dibuang, isi literal
string dikosongkan, lalu polanya diuji di dalam teks argumen itu.

Yang diukur tiap keadaan, dan kenapa bukan sekadar "ada yang merah".

Harness ini menuntut **badan Aturan 20** yang merah, dan tiap keadaan merah wajib
**menyebut berkas yang disuntik**. Alasannya bukan kerapian: salinan pohon yang
tidak lengkap membuat aturan lain berbunyi, dan harness yang hanya menuntut
"ada yang merah" tidak akan bisa membedakan aturan mana yang menangkap cacatnya.

Keadaan yang diuji:

  1. kode benar                          -> diam
     (aturan tidak memerah pada kepatuhan yang sah)
  2. cacat satu baris (bentuk aslinya)   -> berbunyi
     (aturan masih menggigit pada bentuk yang selama ini dikenalnya)
  3. cacat **diformat multi-baris**      -> berbunyi
     (**inti siklus ini**: keadaan ini hijau pada versi lama, jadi ia yang
      mengunci perbaikan — kembalikan pencocokan per-baris dan keadaan ini
      mulai tidak sesuai harapan)
  4. `.color` diakhiri baris             -> berbunyi
     (jalan kedua ke cacat yang sama, dan versi lama juga buta padanya)
  5. pemanggilan bersarang               -> berbunyi
     (pola lama memakai `[^)]*`, yang tidak bisa melewati satu `)` pun)
  6. `Color.black.opacity(…)`            -> diam
     (bayangan di dalam gambar prosedural **bukan** permukaan bertoken;
      tanpa kontrol ini aturan akan memaksa setiap bayangan jadi token)
  7. `.surfaceCard(level:)`              -> diam
     (bentuk yang benar harus tetap benar, kalau tidak gerbangnya akan
      dimatikan orang yang menabraknya)
  8. kalimat memuat `.color.opacity(`    -> diam
     (di dalam literal string, bukan kode — tanpa ini setiap kalimat yang
      menyebut pola itu dilaporkan)

Keadaan 6, 7, dan 8 adalah **kontrol negatif**, dan ketiganya bukan hiasan:
gerbang yang memerah pada kode yang benar akan dilonggarkan orang, dan gerbang
yang dilonggarkan tidak menjaga apa pun.

Yang TIDAK diklaim harness ini.

  - Ia mengukur **teks** `Apps/`, bukan piksel perangkat. Yang dibuktikan:
    aturan berbunyi pada kedelapan bentuk cacat di atas dan diam pada tiga
    bentuk yang sah.
  - Ia **tidak** menghitung kontras. Angka 4.32:1 dan ambang 4.5 itu milik
    `TonePaletteTests`/`SurfacePaletteTests` di Linux; yang dijaga di sini
    adalah bahwa permukaan yang tak teruji tidak boleh dirakit di view.
  - Cakupannya `background`/`fill` saja, sesuai docstring aturannya.
    `.overlay(warna)` yang mencampur token dengan `.opacity(` tidak diperiksa —
    belum ada situsnya di `Apps/`.
  - Ia **tidak** melihat view yang memindahkan nilai campurannya ke variabel
    perantara (`let bg = tone.color.opacity(0.12)` lalu `background(bg)`);
    melacaknya menuntut pelacakan aliran, dan batas ini dinyatakan di docstring
    aturannya, bukan disangka tertutup.

Berkas ini tidak memutasi sumber produksi: ia menyuntik di atas salinan bersih
per keadaan, supaya tidak ada pemulihan yang bisa gagal.
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

RULE = "20"

# Situs suntik: berkas yang memuat cacat aslinya, dan tidak disentuh WIP
# siklus lain. Jangkar dibaca dari berkas saat jalan; kegagalannya dilaporkan
# sebagai keadaan yang tidak sesuai harapan, bukan dilaporkan lulus.
TARGET = "Apps/PointAndKnowWatch/Sources/CalibrationView.swift"

failures: list[str] = []


def copy_repo() -> str:
    """Salin seluruh pohon yang dibaca aturan, kecuali `.git`/`.build`.

    Kenapa utuh, bukan hanya `Apps/`: aturan lain membaca `Packages/`,
    `project.yml`, dan `Tools/`; salinan parsial membuat semuanya berbunyi dan
    menenggelamkan tanda yang dicari — cacat yang sama persis dengan versi
    pertama `bukti-mutasi-aturan-ui.py`.
    """
    workdir = tempfile.mkdtemp(prefix="gerbang-permukaan-")
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
    yang ada di repo dengan `cwd=workdir` akan tetap memeriksa repo sungguhan —
    seluruh keadaan lalu dilaporkan hijau, termasuk keadaan cacat. Gejalanya
    persis "semuanya lulus".
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

    Setiap aturan selalu mencetak `== Aturan N: …` entah ia menemukan sesuatu
    atau tidak, jadi mencocokkan judulnya akan membuat setiap keadaan tampak
    "berbunyi". Yang diambil adalah badan **sesudah** judul sampai judul
    berikutnya.
    """
    marks = list(re.finditer(r"^== Aturan \d+:.*$", out, re.M))
    for i, m in enumerate(marks):
        if re.match(rf"^== Aturan {rule}:", m.group(0)):
            nxt = marks[i + 1].start() if i + 1 < len(marks) else len(out)
            body = out[m.end():nxt].strip()
            return None if body.startswith("Bersih") else body
    return "TANPA-JUDUL"


def expect(nama: str, kondisi: bool, diharapkan: bool) -> None:
    if kondisi == diharapkan:
        print(f"  OK   {nama}")
        return
    kata = "merah" if diharapkan else "hijau"
    nyata = "merah" if kondisi else "hijau"
    failures.append(f"  Aturan {RULE} / {nama}: {nyata} padahal diharapkan {kata}")


def inject(workdir: str, snippet: str) -> bool:
    """Sisipkan `snippet` sesudah baris `import` terakhir di `TARGET`.

    Sesudah `import` terakhir pasti bagian kode, bukan komentar dan bukan di
    dalam tipe, jadi suntingannya tetap berbentuk Swift yang wajar.
    """
    path = os.path.join(workdir, TARGET)
    if not os.path.exists(path):
        return False
    lines = open(path, encoding="utf-8").read().split("\n")
    imports = [i for i, l in enumerate(lines) if l.startswith("import ")]
    if not imports:
        return False
    last = imports[-1]
    out = lines[:last + 1] + [""] + snippet.split("\n") + lines[last + 1:]
    open(path, "w", encoding="utf-8").write("\n".join(out))
    return True


def keadaan(nama: str, snippet: str | None, diharapkan_merah: bool) -> None:
    """Suntik satu keadaan lalu nilai Aturan 20 di atasnya.

    `snippet=None` berarti kode apa adanya (baseline).
    """
    wd = copy_repo()
    try:
        if snippet is not None and not inject(wd, snippet):
            failures.append(f"  Aturan {RULE} / {nama}: tidak bisa menyuntik ke "
                            f"{TARGET} — harness perlu disesuaikan")
            return
        _, out = run_lint(wd)
        body = finding(out, RULE)
        if body == "TANPA-JUDUL":
            failures.append(f"  Aturan {RULE} / {nama}: judul aturan tidak "
                            "ditemukan di keluaran — aturannya hilang atau "
                            "berubah nama")
            return
        merah = body is not None
        if merah and diharapkan_merah and TARGET not in body:
            # Merah karena aturan lain bukan bukti apa pun tentang aturan ini.
            failures.append(f"  Aturan {RULE} / {nama}: berbunyi tetapi tidak "
                            f"menyebut {TARGET} — kemungkinan aturan lain "
                            "yang merah")
            return
        expect(nama, merah, diharapkan_merah)
    finally:
        shutil.rmtree(wd, ignore_errors=True)


# Cacat yang sama, ditulis lima cara berbeda. Empat yang terakhir adalah
# bentuk yang **lolos** dari pencocokan per-baris.
CACAT = {
    "2 cacat satu baris (bentuk asli)":
        '    func ujiSatuBaris(_ tone: PointingTone) -> some View {\n'
        '        Text("x").background(tone.color.opacity(0.12))\n'
        '    }\n',
    "3 cacat multi-baris (inti siklus ini)":
        '    func ujiMultiBaris(_ tone: PointingTone) -> some View {\n'
        '        Text("x").background(\n'
        '            tone.color.opacity(0.12))\n'
        '    }\n',
    "4 `.color` diakhiri baris":
        '    func ujiBarisGanjil(_ tone: PointingTone) -> some View {\n'
        '        Text("x").background(tone.color\n'
        '            .opacity(0.12))\n'
        '    }\n',
    "5 pemanggilan bersarang":
        '    func ujiBersarang(_ tone: PointingTone) -> some View {\n'
        '        Text("x").background(pilih(tone.color.opacity(0.12)))\n'
        '    }\n',
    "5b `.fill` di Rectangle":
        '    func ujiFill(_ tone: PointingTone) -> some View {\n'
        '        Rectangle().fill(tone.color.opacity(0.12))\n'
        '    }\n',
}

KONTROL = {
    "6 Color.black.opacity (bukan token)":
        '    func ujiBayangan() -> some View {\n'
        '        Rectangle().fill(Color.black.opacity(0.18))\n'
        '    }\n',
    "7 .surfaceCard (bentuk yang benar)":
        '    func ujiBenar() -> some View {\n'
        '        Text("x").surfaceCard(level: .card)\n'
        '    }\n',
    "8 pola di dalam literal string":
        '    func ujiKalimat() -> some View {\n'
        '        Text("pakai tone.color.opacity(0.12) untuk latar")\n'
        '    }\n',
}


def main() -> int:
    mutasi_sumber.require_clean_sources(WATCHED)

    print(f"== Buktikan Aturan {RULE} berbunyi pada permukaan yang dirakit di view ==")
    print(f"  situs suntik: {TARGET}")

    # 1. kode benar -> diam
    keadaan("1 kode benar (harus diam)", None, False)

    # 2-5. kelima bentuk cacat -> berbunyi
    for nama, snippet in CACAT.items():
        keadaan(f"{nama} (harus merah)", snippet, True)

    # 6-8. kontrol negatif -> diam
    for nama, snippet in KONTROL.items():
        keadaan(f"{nama} (harus diam)", snippet, False)

    if failures:
        print("\nGERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        for f in failures:
            print(f)
        return 1
    print(f"\nBersih: Aturan {RULE} berbunyi pada kelima bentuk cacat — termasuk "
          "yang diformat multi-baris, yang versi lama lewatkan — dan diam pada "
          "bayangan, token permukaan, serta kalimat di dalam string.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
