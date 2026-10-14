#!/usr/bin/env python3
"""Buktikan Aturan 3 (aksara non-Latin) **berbunyi**, dan pada kelas berkas
mana ia berbunyi.

Koreksi yang pertama-tama, karena versi pertama berkas ini salah.

Metode sapuan yang dipakai repo ini untuk memutuskan "aturan mana yang belum
punya saksi" adalah menyilangkan `== Aturan N:` di `swift-ui-lint.sh` dengan
sebutan `Aturan N` di seluruh `Tools/bukti-mutasi-*.py`. Dengan metode itu
Aturan 3 terbaca **nirsaksi** — dan itu salah. Aturan 3 sudah punya saksi
sejak lama: satu langkah `./red-lint.sh … 'Aturan 3'` di
`.github/workflows/engine-tests.yml` (langkah 8). Metodenya yang buta, bukan
gerbangnya: saksi berbentuk langkah `red-lint.sh` tidak hidup di berkas
`bukti-mutasi-*.py` mana pun, jadi pembaca yang hanya memindai berkas-berkas
itu **menjatuhkan** hasilnya diam-diam. Itu kelas cacat yang sama dengan yang
seluruh direktori ini ada untuk menutup, kali ini terjadi pada pengukuran
saya sendiri.

Jadi yang benar: Aturan 3 punya saksi **satu arah**, dan dua hal yang tidak
pernah diukur siapa pun.

  (1) Langkah `red-lint.sh` itu membuktikan aturan **berbunyi** pada satu
      bentuk cacat (huruf Arab di sebuah `.swift` di `Apps/`). Ia tidak
      menyatakan apa pun tentang **cakupan berkasnya** — dan cakupan itu
      adalah lubang kedua, yang lebih besar dari yang pertama. Terukur di
      pohon bersih: **74 berkas `.py` di `Tools/` dan 2 berkas `.yml` di
      `.github/workflows/` tidak pernah dipindai satu kali pun** (cakupan
      168 -> 245 berkas sesudah diperluas). Padahal justru di sanalah prosa
      Indonesia repo ini paling padat — setiap harness `bukti-mutasi-*.py`
      menulis penjelasan panjang tentang apa yang ia buktikan — dan huruf
      Arab yang dulu benar-benar menyelinap masuk datang lewat **komentar**,
      yaitu bentuk yang persis sama. Keadaan 2 dan 3 di bawah karena itu
      dijalankan atas **dua** cakupan: keduanya wajib hijau pada cakupan lama
      dan merah pada cakupan baru, sehingga perluasan cakupannya terbukti
      yang menutupnya.

  (2) Tidak ada satu pun kontrol negatif yang menyatakan **batas** aturannya.
      Batas itu bukan kelengkapan, dan ia perlu dikunci: Yunani dipakai
      sebagai simbol matematis di repo ini (`sigma`, `Delta`), `.md` mengutip
      aksara CJK dan Cyrillic **sebagai bukti** cacat yang pernah terjadi
      (STATUS.md memuatnya apa adanya), dan komentar repo ini memakai tanda
      baca non-ASCII (`─ ▸ ° × ≥ •`) sebagai tata letak. Gerbang yang merah
      pada keempatnya adalah gerbang yang akan dimatikan orang — jadi
      keempatnya diukur di sini, bukan diasumsikan.

Berkas ini **tidak** memutasi sumber produksi: program Aturan 3 **diekstrak**
dari `swift-ui-lint.sh` dan dijalankan atas salinan pohon di direktori
sementara. Menyalinnya ke sini akan membuat harness mengukur salinan yang
tetap hijau walau aturan aslinya dilonggarkan.

Batas yang dinyatakan: yang diperiksa adalah **huruf** (`L*`). Simbol dan
tanda baca non-ASCII sengaja tidak ditandai (keadaan kontrol keenam).

Pakai:
    python3 Tools/bukti-mutasi-aturan3-aksara.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penjaga sumber bersih, sama dengan harness lain)

#: Pembuka/penutup program Aturan 3 di dalam `swift-ui-lint.sh`.
BLOCK_OPEN = "cjk=$(python3 - <<'PY'"

#: Cakupan yang **diperluas** oleh siklus ini, dan cakupan sebelumnya.
#: Ditulis sebagai teks sumber yang bisa dicari, supaya harness bisa
#: menjalankan ulang program yang sama dengan cakupan lama.
DIRS_NEW = 'DIRS = ["Apps", "Packages", "Tools", ".github"]'
DIRS_OLD = 'DIRS = ["Apps", "Packages", "Tools"]'
EXTS_NEW = 'EXTS = (".swift", ".sh", ".yml", ".yaml", ".py")'
EXTS_OLD = 'EXTS = (".swift", ".sh", ".yml", ".yaml")'

#: Karakter uji ditulis sebagai **escape**, bukan literal.
#:
#: Bukan kerapian: Aturan 3 memindai berkas `.py` di `Tools/` (itu perluasan
#: yang sedang dibuktikan di sini), jadi harness yang menulis aksara ujinya
#: sebagai literal akan **memerah pada dirinya sendiri**. Escape-nya ASCII di
#: sumber dan tetap menghasilkan aksara yang dimaksud saat dijalankan.
ARAB = "\u0627"        # ARABIC LETTER ALEF — cacat yang pernah benar-benar lolos
CJK = "\u6f22"         # CJK UNIFIED IDEOGRAPH-6F22
YUNANI = "\u03c3"      # GREEK SMALL LETTER SIGMA — simbol matematis yang sah
CYRILLIC = "\u043a"    # CYRILLIC SMALL LETTER KA

#: (nama, berkas, baris yang disuntikkan, harus merah pada cakupan baru?,
#:  harus merah pada cakupan lama?)
STATES = [
    ("[baseline] kode apa adanya", None, None, False, False),
    ("1. Arab di Apps/ (kelas asli, komentar .swift)",
     "Apps/PointAndKnowWatch/Sources/PointingView.swift",
     "// uji: " + ARAB, True, True),
    ("2. Cyrillic di Tools/*.py — 74 berkas tak dipindai",
     "Tools/bersihkan-public-berlebih.py",
     "# uji: " + CYRILLIC, True, False),
    ("3. CJK di .github/workflows/*.yml — 2 berkas tak dipindai",
     ".github/workflows/engine-tests.yml",
     "# uji: " + CJK, True, False),
    ("4. [kontrol] Arab di STATUS.md — bukti cacat, harus diam",
     "STATUS.md", "uji: " + ARAB, False, False),
    ("5. [kontrol] Yunani di Apps/ — simbol matematis yang sah",
     "Apps/PointAndKnowWatch/Sources/PointingView.swift",
     "let uji = \"" + YUNANI + "\"", False, False),
    ("6. [kontrol] tanda baca non-ASCII (bukan huruf)",
     "Apps/PointAndKnowWatch/Sources/PointingView.swift",
     "// uji \u2500\u25b8\u00b0", False, False),
]


def extract_rule_program() -> str:
    """Ambil program Python Aturan 3 dari `swift-ui-lint.sh`.

    Diambil sebagai teks, bukan dengan menjalankan seluruh lint: lint itu
    punya 34 aturan lain dan pra-syaratnya, dan kegagalan pra-syarat itulah
    yang dulu terbaca palsu sebagai "gerbang berbunyi" di harness lain.
    """
    lines = open(LINT, encoding="utf-8").read().splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip().startswith(BLOCK_OPEN):
            start = i + 1
            break
    if start is None:
        raise SystemExit("GERBANG: pembuka program Aturan 3 tidak ditemukan "
                         f"di {LINT} — harness tidak boleh jalan.")
    for j in range(start, len(lines)):
        if lines[j].rstrip() == "PY":
            return "\n".join(lines[start:j])
    raise SystemExit("GERBANG: penutup program Aturan 3 (`PY`) tidak "
                     "ditemukan — harness tidak boleh jalan.")


def narrowed(program: str) -> str:
    """Program yang sama dengan cakupan berkas **sebelum** perluasan.

    Kalau keadaan 2 dan 3 tetap merah di sini, perluasan cakupannya bukan
    yang menutupnya — dan harness yang mengklaim sebaliknya akan lulus tanpa
    membuktikan apa pun.
    """
    for new, old in ((DIRS_NEW, DIRS_OLD), (EXTS_NEW, EXTS_OLD)):
        if new not in program:
            raise SystemExit(
                f"GERBANG: cakupan Aturan 3 berubah bentuk — `{new}` tidak "
                "ditemukan di programnya. Harness ini harus disesuaikan, "
                "bukan dilewati: tanpa itu ia tidak bisa membedakan cakupan "
                "baru dari cakupan lama.")
        program = program.replace(new, old, 1)
    return program


def sandbox() -> str:
    """Salin pohon yang dibaca aturan (tanpa `.git`/`.build`) ke tmp."""
    workdir = tempfile.mkdtemp(prefix="aturan3-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build -cf - . '
         '| (cd "$2" && tar -xf -)', "copy", ROOT, workdir],
        check=True)
    return workdir


def run_rule(workdir: str, program: str) -> tuple[bool, str]:
    """Jalankan program aturan di `workdir`; kembalikan (bersih?, keluaran).

    `returncode != 0` berarti programnya **galat**, bukan gerbang berbunyi:
    kegagalan menjalankan gerbang tidak boleh terbaca sebagai gerbang yang
    menangkap cacat.
    """
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    proc = subprocess.run([sys.executable, "-c", program],
                          capture_output=True, text=True, cwd=workdir, env=env)
    if proc.returncode != 0:
        tail = (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
        return False, f"GALAT menjalankan gerbang: {tail}"
    return proc.stdout.strip() == "", proc.stdout.strip()


def inject(workdir: str, target: str, line: str) -> None:
    path = os.path.join(workdir, target)
    if not os.path.exists(path):
        raise SystemExit(f"GERBANG: berkas uji {target} tidak ada — "
                         "harness perlu disesuaikan, bukan aturannya.")
    with open(path, "a", encoding="utf-8") as handle:
        handle.write("\n" + line + "\n")


def main() -> int:
    mutasi_sumber.require_clean_sources([LINT, os.path.join(ROOT, "Apps"),
                                         os.path.join(ROOT, "Packages"),
                                         os.path.join(ROOT, "Tools")])
    full = extract_rule_program()
    weak = narrowed(full)

    failures: list[str] = []
    for label, target, line, want_new, want_old in STATES:
        for variant, program, want in (("cakupan baru", full, want_new),
                                       ("cakupan lama", weak, want_old)):
            workdir = sandbox()
            try:
                if target is not None:
                    inject(workdir, target, line)
                clean, detail = run_rule(workdir, program)
                fired = not clean
                if detail.startswith("GALAT"):
                    failures.append(f"{label} / {variant}: {detail}")
                    print(f"SALAH {label:52s} {variant}: {detail}")
                    continue
                if fired != want:
                    failures.append(
                        f"{label} / {variant}: {'MERAH' if fired else 'hijau'} "
                        f"padahal diharapkan {'merah' if want else 'hijau'}")
                    print(f"SALAH {label:52s} {variant}: "
                          f"{'MERAH' if fired else 'hijau'} "
                          f"(harap {'merah' if want else 'hijau'})")
                else:
                    print(f"OK   {label:52s} {variant}: "
                          f"{'MERAH' if fired else 'hijau'}")
                    if fired:
                        first = detail.splitlines()[0]
                        print(f"       {first[:100]}")
            finally:
                shutil.rmtree(workdir, ignore_errors=True)

    print()
    if failures:
        print(f"{len(failures)} keadaan tidak sesuai harapan:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"{len(STATES)} keadaan x 2 cakupan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
