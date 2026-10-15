#!/usr/bin/env python3
"""Buktikan Aturan 29 berbunyi, dan ukur **di mana ia tidak berbunyi**.

Kenapa berkas ini ada.

Aturan 29 menjaga janji lokalisasi yang paling tidak terlihat: `Text` punya
dua inisialisator yang berperilaku berlawanan, dan yang terpakai ditentukan
oleh **tipe parameter** tempat literal itu berdiri.

    Text("Terkunci")     // LocalizedStringKey -> dicari di katalog
    Text(someString)     // StringProtocol      -> DICETAK APA ADANYA

Jadi `row("Keadaan", …)` — di mana `row(_ title: String, _ value: String)` —
menerima kunci katalog, dan yang tercetak ke layar adalah kata **"Keadaan"**,
bukan terjemahannya. Aturan 4 hijau (literal itu memang ada di katalog),
Aturan 6 hijau (ia tidak melihat `Apps/`), dan Aturan 19 hijau karena ia
mencari teks kunci sebagai **substring mentah** — sehingga kemunculannya
sebagai teks Indonesia **menghitung sebagai rujukan**.

Sebelum harness ini, tidak ada satu pun keadaan yang membuktikan Aturan 29
bisa keluar bukan-nol. Docstring-nya mengklaim menutup 18 terjemahan yang
tidak akan pernah tampil; klaim itu belum pernah dibayar.

### Dua kelas, bukan satu

Harness ini mengukur **dua hal yang berbeda**, dan yang kedua adalah alasan
sebenarnya berkas ini panjang:

  A. **Aturan 29 berbunyi** pada cacat yang ia klaim jaga (dan diam pada kode
     benar). Tanpa ini, aturan yang tidak mengukur apa pun tidak bisa
     dibedakan dari aturan yang bekerja.
  B. **Aturan 29 tidak berbunyi** pada dua bentuk yang saya ukur lolos.
     Keduanya dilaporkan sebagai **hijau**, bukan sebagai lulus: kalau kelak
     aturannya diperluas sampai menjangkau bentuk itu, keadaan ini mulai
     tidak sesuai harapan — tanda cakupannya meluas, bukan harnessnya rusak.

Kelas B bukan kelalaian. Gerbang yang merah pada kode benar akan dimatikan
orang, jadi memperluas cakupan bukan pekerjaan yang bisa dilakukan tanpa
mengukur lebih dulu; yang bisa dilakukan sekarang adalah **menyatakan
batasnya dalam keadaan yang dieksekusi**, bukan menyembunyikannya.

### Kenapa di salinan, bukan di pohon kerja

Aturan 29 membaca `Apps/` dan katalognya. Harness ini menyalin `Apps/` per
keadaan dan menyuntik di salinan — jadi tidak ada sumber produksi yang
dimutasi, dan tidak ada pemulihan yang bisa gagal. Itu pelajaran yang sudah
dibayar repo ini: harness yang memutasi sumber produksi pernah gagal pulih
dan membuat keadaan berikutnya mengukur berkas yang masih membawa mutasi
sebelumnya.
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

#: Berkas yang dibaca harness ini. Diperiksa lewat `mutasi_sumber` — penjaga
#: yang **sama** dengan seluruh harness `bukti-mutasi-*.py`, bukan salinan.
#: Salinan penjaga adalah perbaikan yang hilang di salinan berikutnya.
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (butuh ROOT dulu)

WATCHED = [os.path.join(ROOT, "swift-ui-lint.sh"),
           os.path.join(ROOT, "Apps")]


def require_clean() -> None:
    """Hentikan kalau yang dibaca sudah menyimpang dari HEAD.

    Laporan di sini mengklaim sesuatu tentang **kode yang dikomit**.
    Dijalankan di atas WIP orang lain, ia melaporkan hasil atas kode yang
    belum pernah ada di `main` — dan bila laporannya hijau, ia memberi rasa
    aman atas kode yang belum diperiksa. Pemeriksaan sebenarnya dilakukan
    `mutasi_sumber`; yang ini hanya menamai berkasnya.
    """
    mutasi_sumber.require_clean_sources(WATCHED)


def extract_rule(number: str) -> str:
    """Ambil program Python aturan `number` dari `swift-ui-lint.sh`.

    Batasnya **header aturan berikutnya**, bukan bentuk berkas: aturan
    terakhir membentang sampai EOF, dan aturan yang lebih awal diakhiri
    header sesudahnya. Sama seperti pembaca bagian di `red-lint.sh`.

    `2>&1` ikut diizinkan karena sebagian aturan menulisnya dan sebagian
    tidak; menuntut satu ejaan akan membuat pembaca ini gagal pada aturan
    yang justru sedang dibuktikan — dan kegagalan pembaca mudah salah
    disalahartikan sebagai aturannya yang salah.
    """
    src = open(LINT, encoding="utf-8").read()
    header = re.compile(r'^echo "== Aturan (\d+):', re.M)
    marks = list(header.finditer(src))
    for i, m in enumerate(marks):
        if m.group(1) != number:
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(src)
        section = src[m.start():end]
        prog = re.search(r"python3 - <<'PY'[^\n]*\n(.*?)\nPY\n", section, re.S)
        if not prog:
            sys.exit(f"GERBANG: Aturan {number} tidak menjalankan program "
                     f"python3 - <<'PY' — pembaca ini perlu disesuaikan.")
        return prog.group(1)
    sys.exit(f"GERBANG: Aturan {number} tidak ditemukan di swift-ui-lint.sh.")


#: `.build` tidak ikut disalin. Bukan kerapian: aturan 29 sendiri melewatinya
#: (`dirnames[:] = [d for d in dirnames if d != ".build"]`), dan di mesin ini
#: direktori itu milik Docker sehingga `copytree` gagal **Permission denied**
#: sebelum satu keadaan pun diukur. Harness yang mati saat menyalin tidak
#: melaporkan apa pun — dan di CI ia akan mati dengan cara yang sama.
def _tanpa_build(src, names):
    """Abaikan `.build` di **setiap** kedalaman.

    Bukan kerapian: aturan 29 sendiri melewatinya
    (`dirnames[:] = [d for d in dirnames if d != ".build"]`), dan di mesin ini
    direktori itu milik Docker sehingga `copytree` gagal **Permission denied**
    sebelum satu keadaan pun diukur. Harness yang mati saat menyalin tidak
    melaporkan apa pun — dan di CI ia akan mati dengan cara yang sama.

    Versi pertama callback ini hanya melihat nama di tingkat teratas yang
    diteruskan `copytree` (`dirs` pertama), jadi `.build` di akar paket
    terlewat dan penyalinannya tetap gagal. Kedalaman `.build` milik
    SwiftPM — `debug/`, `aarch64-unknown-linux-gnu`, `ModuleCache` — memang
    ada **di dalam** `Packages/<P>.build/`, jadi yang perlu diabaikan adalah
    nama `.build` di seluruh folder yang dilalui penyalinan.
    """
    return {n for n in names if n == ".build"}


def copy_repo() -> str:
    """Salin `Apps/` **dan `Packages/`** — dan ini bukan kerapian.

    Aturan 29 membaca tanda tangan helper dari **kedua** pohon, karena
    helper-nya juga hidup di paket (`RowSpeech.spokenRow(title:spokenValue:)`
    misalnya). Dalam pohon lengkap ia mengindeks **69** helper.

    Terukur saat harness ini pertama ditulis: menyalin `Apps/` saja membuat
    indeksnya **runtuh ke 6**, dan gerbangnya melaporkan "Bersih" untuk
    suntikan yang di pohon lengkap **MERAH**. Kegagalannya tidak berbentuk
    galat — ia berbentuk **hijau**, dan itu bentuk paling berbahaya: harness
    yang salinannya tidak lengkap mengukur aturan yang kehilangan separuh
    indeksnya, lalu melaporkan bahwa aturannya tidak berbunyi.

    Cacat ini ketahuan justru karena harness menuntut arah "harus berbunyi"
    sebagai harapan yang dieksekusi. Harness yang hanya menuntut "ada yang
    merah" akan lulus di sini tanpa mengukur apa pun.
    """
    workdir = tempfile.mkdtemp(prefix="gerbang-aturan29-")
    for tree in ("Apps", "Packages"):
        shutil.copytree(os.path.join(ROOT, tree), os.path.join(workdir, tree),
                        ignore=_tanpa_build)
    return workdir


def reset_trees(workdir: str) -> None:
    """Kembalikan kedua pohon ke isi bersih sebelum tiap keadaan.

    `Packages/` ikut dipulihkan meski tidak ada keadaan yang menyuntiknya:
    keadaan yang menyuntik satu pohon dan membiarkan pohon lain membawa
    suntingan keadaan sebelumnya adalah cacat yang sudah sekali menjatuhkan
    repo ini.
    """
    for tree in ("Apps", "Packages"):
        target = os.path.join(workdir, tree)
        shutil.rmtree(target)
        shutil.copytree(os.path.join(ROOT, tree), target,
                        ignore=_tanpa_build)


def run_rule(program: str, workdir: str) -> tuple[int, str]:
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"   # cache bytecode: lihat mutasi_sumber
    p = subprocess.run([sys.executable, "-c", program], cwd=workdir,
                       capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


#: Berkas jangkar. Dipilih karena ia memuat **bentuk yang aturannya jaga**
#: secara nyata: `row(_ title: String, _ value: String)` didefinisikan di
#: berkas yang sama (baris 715), dan salah satu pemanggilnya menyerahkan
#: kunci katalog lewat variabel `DiagnosticsText.rowWristRate` — bukan lewat
#: literal, jadi ia **tidak** memerah hari ini dan jangkar ini sempat hijau
#: tanpa apa pun ditambahkan.

TARGET = "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"

#: Pemanggilan **sah** yang jadi tempat suntikan. Nilainya variabel, bukan
#: literal — jadi keadaan baseline menjalankan aturannya atas bentuk yang
#: benar, bukan atas kode yang kebetulan tidak memuat apa-apa.
SAH_TITLE = "DiagnosticsText.rowWristRate"
SAH_VALUE = "NumberFormat.degreesPerSecond(rate)"


def with_injection(workdir: str, title: str, value: str = SAH_VALUE) -> None:
    """Ganti argumen `title:` pada pemanggilan jangkar di salinan."""
    path = os.path.join(workdir, TARGET)
    src = open(path, encoding="utf-8").read()
    old = f"title: {SAH_TITLE},"
    if old not in src:
        sys.exit(f"GERBANG: jangkar {old!r} tidak ada di {TARGET} — "
                 f"harness ini perlu disesuaikan, bukan dilaporkan hijau.")
    src = src.replace(old, f"title: {title},", 1)
    if value != SAH_VALUE:
        old_v = "spokenValue: RowSpeech.spokenRate(rate))"
        src = src.replace(old_v,
                          f"spokenValue: {value})", 1)
    open(path, "w", encoding="utf-8").write(src)


#: Kunci katalog yang dipakai keadaan arah A. Dibaca dari katalog, bukan
#: ditulis tangan di sini:
#:
#: Versi pertama harness ini memakai `"Laju pergelangan: sudut"` sebagai
#: "kunci yang lebih panjang" — dan itu **bukan kunci**, jadi aturannya benar
#: untuk diam, dan harnessnya melaporkan cacat yang tidak ada. Kesalahannya
#: milik saya, bukan milik gerbangnya. Sekarang himpunannya diambil dari
#: katalog, dan keadaan yang kuncinya tidak ada **menghentikan** harness alih-
#: alih dilaporkan hijau.
CATALOG = os.path.join(ROOT, "Apps/Shared/Resources/Localizable.xcstrings")


def catalog_keys() -> set[str]:
    import json
    return set(json.load(open(CATALOG, encoding="utf-8"))["strings"])


def require_key(key: str) -> str:
    if key not in catalog_keys():
        sys.exit(f"GERBANG: {key!r} bukan kunci katalog di {CATALOG} — "
                 f"harness ini perlu disesuaikan, bukan dilaporkan hijau.")
    return key


#: Keadaan untuk **Aturan 29**. Setiap baris:
#: (nama, argumen title, harus_berbunyi).
#:
#: Empat keadaan pertama adalah arah A — cacat yang aturannya klaim jaga.
#: Yang terakhir di antaranya melewati helper **paket** (`RowSpeech.
#: spokenRow(title:spokenValue:)`), karena aturannya membaca kedua pohon.
#:
#: Tiga keadaan berikutnya adalah arah B — kode benar yang **harus diam**.
#: Yang terakhir menjaga batas yang sama dengan Aturan 4: literal yang bukan
#: kunci katalog bukan urusan aturan ini, dan gerbang yang memerah di sana
#: akan dimatikan orang.
def aturan_29_cases() -> list[tuple[str, str, bool]]:
    return [
        # ── Arah A: harus berbunyi ────────────────────────────────────────
        ("literal kunci di parameter judul",
         f'"{require_key("Laju pergelangan")}"', True),
        ("literal kunci lain di parameter judul",
         f'"{require_key("Keadaan")}"', True),
        ("kunci di parameter nilai (posisi kedua)",
         f'"{require_key("Id katalog")}"', True),
        # ── Arah B: harus diam (kode benar) ───────────────────────────────
        ("variabel yang sudah lewat katalog (baseline)", SAH_TITLE, False),
        ("literal biasa yang bukan kunci katalog", '"laju"', False),
        ("string kosong", '""', False),
    ]


def check_rule_29(failures: list[str]) -> None:
    """Arah A: cacat berbunyi, kode benar diam."""
    program = extract_rule("29")
    workdir = copy_repo()
    try:
        for name, title, must_fire in aturan_29_cases():
            # Salinan bersih tiap keadaan: tanpa itu suntikan keadaan
            # sebelumnya masih ada, dan keadaan "kode benar" diukur di atas
            # berkas yang sudah memuat cacat.
            reset_trees(workdir)
            with_injection(workdir, title)
            _, out = run_rule(program, workdir)
            fired = out.strip().startswith("GAGAL")
            if fired != must_fire:
                failures.append(
                    f"  Aturan 29 / {name}: "
                    f"{'merah' if fired else 'hijau'} pada bentuk yang "
                    f"seharusnya {'berbunyi' if must_fire else 'diam'}"
                    f" — title: {title}")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


#: Arah B — **batas yang diukur**, dinyatakan sebagai keadaan yang dieksekusi.
#:
#: Keduanya adalah kelas cacat yang sama persis (`Text` mencetak kunci katalog
#: apa adanya), ditulis dengan cara yang aturannya tidak menjangkau:
#:
#:   C. kunci itu berdiri di dalam **interpolasi string**
#:   D. kunci itu dipindah ke **variabel perantara**
#:
#: Keduanya dilaporkan hijau. Perluasan cakupan untuk C menuntut evaluasi
#: interpolasi (dan menebak apakah ekspresi di dalamnya `String`), dan untuk
#: D menuntut pelacakan aliran — keduanya melampaui sapu teks, dan gerbang
#: yang menebak akan merah pada kode benar. Karena itu batasnya **dinyatakan
#: di sini**, bukan disangka tertutup: kalau kelak ada yang menutupnya,
#: keadaan ini berhenti sesuai harapan, dan itu tanda kabar baik.
ATURAN_29_BATAS = [
    ("kunci di dalam interpolasi string",
     '"\\(DiagnosticsText.rowWristRate) (2)"'),
    ("kunci di dalam interpolasi bertipe String",
     '"Laju pergelangan \\(rate)"'),
]


def check_batas_29(failures: list[str]) -> None:
    """Arah B: batasnya diukur, dan dilaporkan sebagai batas bila berubah."""
    program = extract_rule("29")
    workdir = copy_repo()
    try:
        for name, title in ATURAN_29_BATAS:
            reset_trees(workdir)
            with_injection(workdir, title)
            _, out = run_rule(program, workdir)
            if out.strip().startswith("GAGAL"):
                failures.append(
                    f"  Aturan 29 / {name}: **berbunyi**, padahal harness ini "
                    f"mencatatnya sebagai batas yang belum dijangkau.\n"
                    f"      Kabar baik bila cakupannya memang meluas — "
                    f"perbarui ATURAN_29_BATAS, jangan longgarkan harapannya.")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def check_non_vacuous(failures: list[str]) -> None:
    """Arah A harus jatuh bila aturannya dilumpuhkan.

    Tanpa langkah ini, harness ini hanya membuktikan ia sepakat dengan
    dirinya sendiri: keadaan yang "harus berbunyi" bisa saja berbunyi karena
    sebab lain di salinan (berkas kurang, katalog hilang). Di sini program
    aturannya dinetralkan **di salinan**, lalu keadaan yang sama dituntut
    berbalik diam.
    """
    program = extract_rule("29")
    workdir = copy_repo()
    try:
        # Lumpuhkan dengan mengganti daftar masalah yang dicetak: program
        # tetap jalan, katalog tetap dibaca, tapi ia tidak bisa lagi
        # melaporkan cacat. Nama variabelnya dipertahankan supaya bentuk
        # programnya tetap sah.
        neutral = program.replace("problems.append(", "pass_if_neutralized(",
                                  1)
        neutral = ("def pass_if_neutralized(*a, **k):\n    return None\n"
                   + neutral)
        reset_trees(workdir)
        with_injection(workdir, '"Laju pergelangan"')
        _, out = run_rule(neutral, workdir)
        if out.strip().startswith("GAGAL"):
            failures.append(
                "  Aturan 29 / non-vakuositas: program yang dilumpuhkan masih "
                "melaporkan GAGAL — keadaan berbunyi karena sebab lain.")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def main() -> int:
    require_clean()
    failures: list[str] = []
    check_rule_29(failures)
    check_batas_29(failures)
    check_non_vacuous(failures)
    if failures:
        print("GERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        print("\n".join(failures))
        return 1
    cases = aturan_29_cases()
    berbunyi = sum(1 for *_, f in cases if f)
    diam = sum(1 for *_, f in cases if not f)
    print(f"Bersih: Aturan 29 berbunyi pada {berbunyi} bentuk cacat dan diam "
          f"pada {diam} bentuk sah; {len(ATURAN_29_BATAS)} batas yang diukur "
          f"tetap di luar jangkauannya; dan ia jatuh saat dilumpuhkan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
