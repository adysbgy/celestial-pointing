#!/usr/bin/env python3
"""Buktikan kedua gerbang sapu UI **berbunyi pada hal yang mereka klaim**.

Kenapa berkas ini ada.

`swift-ui-lint.sh` (31 aturan) dan `red-lint.sh` (pembuktinya) adalah dua
gerbang yang **tidak dikompilasi siapa pun** dan tidak punya uji Swift. Yang
menjaga mereka selama ini hanya teks: aturan ditulis, dijalankan, dan hijau —
dan hijau itu diperlakukan sebagai bukti. Dua cacat di bawah terukur, dan
keduanya hidup di `main`:

  1. **Aturan 18 buta pada bentuk deklarasi yang normal.** Regex-nya menuntut
     `var`/`let` sebagai token **pertama** di baris, sehingga
     `private var isConfirmed: Bool = true` — bentuk yang dipakai seluruh
     properti SwiftUI — **hijau**. Diukur satu per satu: `private`, `static`,
     `@State`, `private(set)`, `@AppStorage("k")` semuanya lolos; hanya
     `var isConfirmed: Bool = true` (tanpa pengubah apa pun) yang tertangkap.
     Artinya aturan yang menegakkan aturan PRD paling keras — "JANGAN pernah
     menampilkan visual yang mengklaim identitas saat engine RAGU" — hijau
     **bukan karena nilainya sudah `false`**, melainkan karena ia tidak pernah
     membaca baris yang memuat nilai itu.

  2. **`red-lint.sh` membuktikan judulnya sendiri.** Syarat keduanya dulu
     `grep -qF "$NEEDLE"` ke seluruh keluaran — dan setiap aturan **mencetak
     judulnya** entah ia menemukan sesuatu atau tidak. Jadi
     `./red-lint.sh WatchTheme.swift '<cacat font>' 'Aturan 31'` melaporkan
     "MERAH: gerbang gagal pada 'Aturan 31'" dengan exit 0, padahal yang
     disuntik adalah cacat font (Aturan 1) dan Aturan 31 soal arah fase tidak
     ada hubungannya. Seluruh empat langkah `red-lint.sh` di CI karena itu
     hanya membuktikan satu hal: `swift-ui-lint.sh` keluar bukan-nol.

Bentuk kegagalannya sama, dan itu alasan berkas ini ada sebagai satu berkas:
keduanya **hijau karena tidak mengukur apa pun** — kelas yang sudah berulang
di repo ini, kali ini pada gerbang yang menjaga gerbangnya.

Yang diukur di sini, untuk **setiap** aturan:

  a. **Sasaran** — cacatnya disuntik, aturannya yang dinamai benar-benar
     melaporkan temuan (bukan aturan lain yang kebetulan berbunyi).
  b. **Ketepatan** — kode yang benar tidak memerah.
  c. **Hampa** — keluaran bersih tidak melaporkan apa pun.

Pemeriksaan (a) menjalankan program Python aturannya **langsung**, bukan lewat
`red-lint.sh`, dan itu disengaja: yang sedang diuji adalah aturannya. Kalau
`red-lint.sh` yang dipakai, cacat di `red-lint.sh` akan membuat laporan ini
menyalahkan aturannya.

Berkas ini **tidak** memutasi sumber produksi. Ia menyalin berkas uji ke
direktori sementara, menyuntik di sana, dan menjalankan aturannya atas salinan
itu — jadi tidak ada pemulihan yang bisa gagal. Itu pelajaran dari
`bukti-mutasi-*.py`: harness yang memutasi sumber produksi pernah gagal pulih
dan membuat harness berikutnya mengukur berkas yang sudah termutasi.
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
#: yang **sama** dengan semua harness `bukti-mutasi-*.py`, bukan salinan.
#:
#: **Kenapa tidak menulis penjaga sendiri.** Salinan penjaga adalah perbaikan
#: yang hilang di salinan berikutnya — dan penjaga ini sudah pernah jatuh
#: karena `git diff --quiet HEAD` memakai exit 1 untuk dua hal yang berbeda
#: (berkas menyimpang, dan HEAD tidak terbaca). Versi yang menyalahkan berkas
#: bersih sudah menjatuhkan `main` dua kali. `mutasi_sumber` sudah memisahkan
#: keduanya lewat preflight `rev-parse`; menyalinnya ke sini berarti membuang
#: perbaikan itu dan menunggu cacatnya lahir kembali.
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (butuh ROOT dulu)

WATCHED = [os.path.join(ROOT, "swift-ui-lint.sh"),
           os.path.join(ROOT, "red-lint.sh"),
           os.path.join(ROOT, "Apps")]


def require_clean() -> None:
    """Hentikan harness kalau yang dibacanya sudah menyimpang dari HEAD.

    Alasannya sama dengan harness mutasi: laporan di sini mengklaim sesuatu
    tentang **kode yang dikomit**. Dijalankan di atas WIP orang lain, ia akan
    melaporkan hasil atas kode yang tidak pernah ada di `main` — dan bila
    laporannya hijau, ia memberi rasa aman atas kode yang belum diperiksa.
    """
    mutasi_sumber.require_clean_sources(WATCHED)


def extract_rule(number: str) -> str:
    """Ambil program Python aturan `number` dari `swift-ui-lint.sh`.

    Batasnya **header aturan berikutnya**, bukan bentuk berkas — aturan
    terakhir (31) membentang sampai EOF, dan aturan yang lebih awal diakhiri
    oleh header aturan sesudahnya. Sama seperti pembaca bagian di
    `red-lint.sh`, karena keduanya harus membaca berkas yang sama dengan cara
    yang sama.
    """
    src = open(LINT, encoding="utf-8").read()
    header = re.compile(r'^echo "== Aturan (\d+):', re.M)
    marks = list(header.finditer(src))
    for i, m in enumerate(marks):
        if m.group(1) != number:
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(src)
        section = src[m.start():end]
        # `2>&1` ikut diizinkan: Aturan 18 menulis
        # `claim_default=$(python3 - <<'PY' 2>&1`, sementara Aturan 1 menulis
        # `python3 - <<'PY'` polos. Menuntut satu ejaan akan membuat pembaca
        # ini gagal pada aturan yang justru sedang dibuktikan — dan kegagalan
        # pembaca mudah disalahartikan sebagai aturannya yang salah.
        prog = re.search(r"python3 - <<'PY'[^\n]*\n(.*?)\nPY\n", section, re.S)
        if not prog:
            sys.exit(f"GERBANG: Aturan {number} tidak menjalankan program "
                     f"python3 - <<'PY' — pembaca ini perlu disesuaikan.")
        return prog.group(1)
    sys.exit(f"GERBANG: Aturan {number} tidak ditemukan di swift-ui-lint.sh.")


def run_rule(number: str, program: str, workdir: str) -> tuple[int, str]:
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"   # cache bytecode: lihat mutasi_sumber
    p = subprocess.run([sys.executable, "-c", program], cwd=workdir,
                       capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def inject(workdir: str, target: str, snippet: str) -> None:
    """Suntik `snippet` setelah baris `import` terakhir di berkas target."""
    path = os.path.join(workdir, target)
    lines = open(path, encoding="utf-8").read().split("\n")
    last = max(i for i, l in enumerate(lines) if l.startswith("import "))
    out = lines[:last + 1] + [""] + snippet.split("\n") + lines[last + 1:]
    open(path, "w", encoding="utf-8").write("\n".join(out))


def copy_repo() -> str:
    """Salin yang dibutuhkan aturan: `Apps/` dan katalog stringnya."""
    workdir = tempfile.mkdtemp(prefix="gerbang-aturan-")
    shutil.copytree(os.path.join(ROOT, "Apps"), os.path.join(workdir, "Apps"))
    return workdir


#: Keadaan untuk **Aturan 18**. Setiap baris: (nama, cuplikan, harus_berbunyi).
#:
#: Yang "harus berbunyi" adalah bentuk cacat — nilai bawaan `true` untuk nama
#: yang menyatakan klaim identitas. Yang "tidak" adalah dua arah penjaga:
#: `isStale` (nama yang sengaja di luar cakupan), dan nilai `false`.
#:
#: **Lima bentuk pertama adalah cacat yang versi lama meloloskannya.** Itulah
#: angka-angka yang membuat berkas ini ada; kalau salah satunya kembali hijau,
#: aturan itu kembali tidak mengukur apa pun.
ATURAN_18_CASES = [
    ("var polos", '    var isConfirmed: Bool = true', True),
    ("private var", '    private var isConfirmed: Bool = true', True),
    ("static var", '    static var isConfirmed: Bool = true', True),
    ("private let", '    private let claimIdentity: Bool = true', True),
    ("private(set)", '    private(set) var isConfirmed: Bool = true', True),
    ("@State private", '    @State private var isConfirmed: Bool = true', True),
    ("@AppStorage berargumen",
     '    @AppStorage("x") private var isConfirmed: Bool = true', True),
    ("komentar di ujung",
     '    private var isConfirmed: Bool = true // alasan', True),
    ("confirmsIdentity",
     '    private var confirmsIdentity: Bool = true', True),
    ("isStale (di luar cakupan)",
     '    private var isStale: Bool = true', False),
    ("nilai false", '    private var isConfirmed: Bool = false', False),
    ("bukan Bool = true",
     '    private var includeTechnicalDetails: Bool = true', False),
]

ATURAN_18_TARGET = "Apps/PointAndKnowWatch/Sources/WatchTheme.swift"


def check_rule_18(failures: list[str]) -> None:
    """Aturan 18: bentuk deklarasi + ketepatan, satu per satu."""
    program = extract_rule("18")
    workdir = copy_repo()
    try:
        for name, snippet, must_fire in ATURAN_18_CASES:
            # Salinan bersih tiap keadaan: tanpa itu suntikan keadaan
            # sebelumnya masih ada, dan keadaan "nilai false" akan diukur di
            # atas berkas yang sudah memuat cacat.
            shutil.rmtree(os.path.join(workdir, "Apps"))
            shutil.copytree(os.path.join(ROOT, "Apps"),
                            os.path.join(workdir, "Apps"))
            inject(workdir, ATURAN_18_TARGET, f"struct ProbeStor {{\n{snippet}\n}}")
            _, out = run_rule("18", program, workdir)
            fired = bool(out.strip())
            if fired != must_fire:
                failures.append(
                    f"  Aturan 18 / {name}: {'hijau' if not fired else 'merah'}"
                    f" pada bentuk yang seharusnya "
                    f"{'berbunyi' if must_fire else 'diam'}"
                    f" — {snippet.strip()}")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


#: **Fungsi berpenjaga** yang menjadi umpan untuk Aturan 15. Ia memuat
#: `NightMode.isOn` yang sah, dan itu bukan hiasan: ia yang membuat keadaan
#: di bawah non-vakum. Kalau Aturan 15 tidak mengenali bentuk deklarasi
#: berikutnya, cacat di fungsi berikutnya jatuh ke rentang fungsi **ini**, dan
#: penjaganya membela cacat itu — persis cacat yang ditemukan.
#:
#: Karena itu urutannya penting: penjaga dulu, cacat sesudahnya. Dengan
#: cacat di fungsi **pertama** dan penjaga di kedua, rentangnya jatuh ke
#: seluruh berkas dan aturannya tampak berbunyi walau deklarasinya buta —
#: gerbang hampa, dan pengukurannya akan salah menyimpulkan "sudah aman".
ATURAN_15_GUARD = (
    "private func warnaSah() -> Color {\n"
    "    if NightMode.isOn { return Color(red: 0.9, green: 0.0, blue: 0.0) }\n"
    "    return Color(white: 1)\n"
    "}\n")

#: Warna yang **tidak** lewat penjaga mode malam. Nilainya sengaja sama dengan
#: contoh yang dipakai CI (`red-lint.sh`) untuk Aturan 15, supaya keadaan di
#: sini dan keadaan di sana mengukur cacat yang sama.
ATURAN_15_DEFECT = "Color(red: 0.62, green: 0.30, blue: 0.16)"

#: Keadaan untuk **Aturan 15** (warna prosedural wajib lewat penjaga mode
#: malam). Setiap baris: (nama, deklarasi fungsi yang memuat cacat, harus_berbunyi).
#:
#: **Empat bentuk pertama adalah cacat yang versi lama meloloskannya**, dan
#: semuanya bentuk deklarasi yang normal di berkas SwiftUI. Yang terakhir
#: adalah arah penjaga: fungsi yang **berpenjaga sendiri** tidak boleh
#: memerah, karena aturan yang merah pada kode benar akan dimatikan orang.
ATURAN_15_CASES = [
    ("private func", "private func warnaUji() -> some View", True),
    ("@ViewBuilder func", "@ViewBuilder private func warnaUji() -> some View", True),
    ("override func", "override func warnaUji() -> Color", True),
    ("nonisolated func", "nonisolated private func warnaUji() -> Color", True),
    ("@MainActor static func",
     "@MainActor static func warnaUji() -> Color", True),
    ("fungsi berpenjaga sendiri (harus diam)",
     "private func warnaUji() -> some View", False),
]


def check_rule_15(failures: list[str]) -> None:
    """Aturan 15: cacat di fungsi kedua tidak boleh dibela penjaga fungsi pertama."""
    program = extract_rule("15")
    workdir = copy_repo()
    try:
        for name, decl, must_fire in ATURAN_15_CASES:
            shutil.rmtree(os.path.join(workdir, "Apps"))
            shutil.copytree(os.path.join(ROOT, "Apps"),
                            os.path.join(workdir, "Apps"))
            if must_fire:
                body = f"    Circle().fill({ATURAN_15_DEFECT})"
            else:
                body = ("    if NightMode.isOn { return AnyView(Circle()"
                        f".fill({ATURAN_15_DEFECT})) }}\n"
                        "    return AnyView(Color(white: 1))")
            inject(workdir, ATURAN_18_TARGET,
                   ATURAN_15_GUARD + decl + " {\n" + body + "\n}")
            _, out = run_rule("15", program, workdir)
            fired = bool(out.strip())
            if fired != must_fire:
                failures.append(
                    f"  Aturan 15 / {name}: {'hijau' if not fired else 'merah'}"
                    f" pada bentuk yang seharusnya "
                    f"{'berbunyi' if must_fire else 'diam'} — {decl}")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


#: Keadaan untuk **`red-lint.sh`**. Yang diukur bukan aturannya, melainkan
#: pembuktinya: apakah ia menerima "gerbang gagal karena sebab lain" sebagai
#: bukti. Tiga keadaan, dan yang ketiga adalah cacat yang ditemukan.
#:
#: Aturan 1 (font tetap) memakai `Text("https://example.com/x")` sengaja:
#: bentuk itu — `//` di dalam literal — adalah cacat nyata yang pernah
#: menembus Aturan 1 versi pertama, jadi ia sekaligus membuktikan aturannya
#: masih mengenal bentuk yang paling mudah terlewat.
RED_LINT_CASES = [
    ("sasaran benar",
     ["Apps/PointAndKnowWatch/Sources/WatchTheme.swift",
      'private func mutasiUji() -> some View {\n'
      '    Text("x").font(.system(size: 11))\n}\n', "Aturan 1"], 0),
    ("sasaran benar (URL di literal)",
     ["Apps/PointAndKnowWatch/Sources/WatchTheme.swift",
      'private func mutasiUji() -> some View {\n'
      '    Text("https://example.com/x").font(.system(size: 11))\n}\n',
      "Aturan 1"], 0),
    ("salah sasaran: minta aturan yang tidak berbunyi",
     ["Apps/PointAndKnowWatch/Sources/WatchTheme.swift",
      'private func mutasiUji() -> some View {\n'
      '    Text("x").font(.system(size: 11))\n}\n', "Aturan 31"], 1),
    ("salah sasaran: aturan 18 tidak berbunyi pada cacat font",
     ["Apps/PointAndKnowWatch/Sources/WatchTheme.swift",
      'private func mutasiUji() -> some View {\n'
      '    Text("x").font(.system(size: 11))\n}\n', "Aturan 18"], 1),
]


def check_red_lint(failures: list[str]) -> None:
    """`red-lint.sh` harus menolak "merah karena sebab lain" sebagai bukti."""
    red_lint = os.path.join(ROOT, "red-lint.sh")
    for name, args, expected in RED_LINT_CASES:
        p = subprocess.run([red_lint, *args], cwd=ROOT,
                           capture_output=True, text=True)
        if p.returncode != expected:
            failures.append(
                f"  red-lint.sh / {name}: exit {p.returncode}, "
                f"diharapkan {expected}\n"
                + "\n".join("      " + l
                            for l in (p.stdout + p.stderr).split("\n")[-6:]))


#: Keluaran `red-lint.sh` yang **palsu**: sebuah gerbang yang merah karena
#: sebab lain diterima sebagai bukti. Dirakit di sini, bukan diambil dari
#: menjalankan gerbang sungguhan, supaya keadaannya deterministik dan
#: pembaca bisa melihat persis apa yang ditolaknya.
FAKE_LINT_OUT = """== Aturan 1: tidak ada ukuran font tetap di Apps/ ==
Ukuran font tetap ditemukan (abaikan Dynamic Type):
Apps/Foo.swift:6: Text("x").font(.system(size: 11))
== Aturan 31: arah fase harus sampai ke gambar untuk tiap benda berfase ==
Bersih: arah fase diteruskan untuk setiap benda berfase.
== GERBANG UI GAGAL ==
"""


def check_fake_acceptance(failures: list[str]) -> None:
    """Pembaca bagian di `red-lint.sh` harus **menolak** temuan aturan lain.

    Ini pengukuran paling langsung atas cacat aslinya: keluaran di atas
    memuat temuan **Aturan 1** dan tidak satu pun temuan Aturan 31. Versi
    lama `red-lint.sh` menerimanya sebagai bukti untuk 'Aturan 31' karena
    judulnya tercetak. Yang diuji di sini adalah logikanya, lewat program
    yang sama yang dipakai `red-lint.sh`.
    """
    src = open(os.path.join(ROOT, "red-lint.sh"), encoding="utf-8").read()
    prog = re.search(
        r'if ! LINT_OUT="\$out" LINT_NEEDLE="\$NEEDLE" python3 - <<\'PY\'\n'
        r"(.*?)\nPY\n", src, re.S)
    if not prog:
        failures.append("  red-lint.sh: program pembaca bagian tidak ditemukan "
                        "— pembaca ini perlu disesuaikan.")
        return
    for needle, must_accept in (("Aturan 31", False), ("Aturan 1", True)):
        env = dict(os.environ, LINT_OUT=FAKE_LINT_OUT, LINT_NEEDLE=needle)
        p = subprocess.run([sys.executable, "-c", prog.group(1)],
                           capture_output=True, text=True, env=env)
        accepted = p.returncode == 0
        if accepted != must_accept:
            failures.append(
                f"  red-lint.sh / pembaca bagian: '{needle}' "
                f"{'diterima' if accepted else 'ditolak'}, diharapkan "
                f"{'diterima' if must_accept else 'ditolak'}")


def main() -> int:
    require_clean()
    failures: list[str] = []
    check_rule_18(failures)
    check_rule_15(failures)
    check_red_lint(failures)
    check_fake_acceptance(failures)
    if failures:
        print("GERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        print("\n".join(failures))
        return 1
    print(f"Bersih: Aturan 18 berbunyi pada {len(ATURAN_18_CASES)} bentuk "
          f"deklarasi (dan diam pada yang di luar cakupannya); "
          f"Aturan 15 berbunyi pada {len(ATURAN_15_CASES) - 1} bentuk "
          f"deklarasi (dan diam pada fungsi yang berpenjaga sendiri); "
          f"red-lint.sh menolak {len(RED_LINT_CASES) - 2} keadaan "
          f"'merah karena sebab lain'.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
