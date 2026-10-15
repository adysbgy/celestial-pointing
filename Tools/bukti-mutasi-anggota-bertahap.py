#!/usr/bin/env python3
"""Buktikan Aturan 26 berbunyi pada anggota berkualifikasi bertingkat.

Kenapa berkas ini ada.

Aturan 26 mengklaim memeriksa keanggotaan `TipePaket.anggota` di `Apps/`.
Hingga siklus ini ia **belum pernah dibuktikan bisa merah** — 34 aturan
lint lainnya sudah punya harness, ia yang terakhir. Terukur di siklus ini,
ia punya cacat diam: `PAIR` memakai awalan negatif `(?<![A-Za-z0-9_.])`, jadi
dari `CelestialVisual.Planet.saturn` ia hanya membaca `CelestialVisual.Planet`
— anggota yang **paling spesifik** (`saturn`) tidak pernah diperiksa.

Mengganti `CelestialVisual.Planet.saturn` menjadi `.salahAnggota` (galat
kompilasi yang **pasti**) membiarkan aturan ini melaporkan "Bersih". Yang
hilang bukan satu nama, melainkan satu tingkat kedalaman — dan tingkat
terdalam adalah yang paling sering disunting.

Perbaikan (di `swift-ui-lint.sh`): `PAIR` diganti `DEEP` yang menangkap
awalan berkualifikasi berapa pun tingkatnya, lalu anggotanya diperiksa pada
tipe **terdalam** (`CelestialVisual.Planet`), bukan pada akar. Agar tidak
memerah pada kode benar, dua hal ditambahkan:

  - anggota yang **disintesis compiler** (`allCases` dari `CaseIterable`)
    dilewati bila konformansinya tertulis; tanpanya `Planet.allCases` —
    baris yang dikompilasi hari ini — dilaporkan sebagai anggota hilang;
  - kualifikasi yang tidak seluruhnya ada di indeks paket dilewati (bukan
    ditebak), supaya gerbang tidak memerah pada tipe yang tak dikenali.

Keadaan yang diukur (jalur di salinan bersih per keadaan, tidak menyentuh
sumber produksi — pelajaran dari harness yang pernah meninggalkan mutasi
hidup):

| # | keadaan                                          | harap | kenapa |
|---|---|---|---|
| 0 | kode apa adanya                                  | hijau | gerbang tak boleh memerah pada kode benar |
| 1 | `Planet.saturn` -> `.salahAnggota` (3 tingkat)   | MERAH | cacat asli: tingkat terdalam lolos |
| 2 | `Planet.allCases` -> `.salahAnggota` (3 tingkat) | MERAH | idem, anggota diwariskan (CaseIterable) |
| 3 | `NumberFormat.decimal` -> `.salahAnggota` (2 tkt)| MERAH | arah yang **sudah** dijaga sebelum siklus ini |
| 4 | cabut `CaseIterable` di model                    | MERAH | `allCases` hanya sah krn konformansinya |
| 5 | mutasi di KOMENTAR                               | hijau | baris, bukan kode |
| 6 | mutasi di STRING literal                         | hijau | kalimat, bukan kode |

Keadaan 3, 4, 5, 6 bukan hiasan — semuanya yang menjaga gerbangnya jujur:

- **Keadaan 3** membuktikan arah "2 tingkat" yang sudah dijaga sebelum
  siklus ini tetap dijaga. Tanpanya, perbaikan yang kebetulan hanya
  memperlebar cakupan 3 tingkat bisa melaporkan "kontrol hijau" padahal
  arah lama rusak.
- **Keadaan 4** membuktikan pelewatan sintesis itu **bersyarat**, bukan
  lubang. `Planet.allCases` sah **hanya** karena `Planet` mengonformasi
  `CaseIterable`; cabut konformansinya di model dan baris yang sama menjadi
  cacat sungguhan. Keadaan ini harus merah. Versi lama tidak dilibatkan di
  sini: `origin/main` tidak pernah melihat tingkat kedua, jadi ia diam di
  kedua arah — membandingkannya akan mengukur ketidaktahuan, bukan
  kebenaran.
- **Keadaan 5 & 6** menahan bahwa gerbang ini tetap sapu teks: komentar
  dan string tidak boleh dihitung sebagai kode.

**Non-vakuositas, diukur.** Setiap keadaan cacat dijalankan juga terhadap
`swift-ui-lint.sh` versi `origin/main`. Kalau versi lama **sudah** merah di
keadaan yang sengaja baru ditutup (1, 2), itu berarti cacatnya bukan yang
ditutup perbaikan ini — harness berhenti (exit 1). Kalau versi lama **hijau**
di keadaan yang seharusnya tetap dijaga (3), perbaikan ini merusak arah lama
— juga berhenti. Keadaan 4–6 memang hijau di kedua versi (kontrol negatif),
jadi tidak dilibatkan ke arah "versi lama".

Yang TIDAK diklaim
- Yang diukur **teks** `Apps/`, bukan kompilasi Swift. Gerbang ini sapu teks:
  ia tahu "anggota dengan nama ini tidak ada di tipe terdalam", bukan
  "tipenya bertipe salah".
- Tipe yang dideklarasi **di `Apps/`** tetap tidak diindeks — aturan ini
  menjaga pemakaian API **paket** dari view.
- Cacat "awalan negatif memotong tingkat kedalaman" hanya berlaku untuk
  akses **berkualifikasi**; pemanggilan bebas dan `self.member` tidak terlihat
  — batas itu sama seperti sebelum siklus ini dan dinyatakan di sini.
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

RULE = "26"

# ── Jangkar ────────────────────────────────────────────────────────────────
# Jangkar **dibaca dari berkas yang disalin**, bukan ditulis mati: jangkar yang
# ditulis mati mengukur pohon kerja penulisnya (lihat docstring Aturan 10).
DEEP_SATURN = ("Apps/Shared/CelestialVisualView.swift",
               "CelestialVisual.Planet.saturn",
               "CelestialVisual.Planet.salahAnggota")
DEEP_ALLCASES = ("Apps/Shared/PointingEngine.swift",
                 "CelestialVisual.Planet.allCases",
                 "CelestialVisual.Planet.salahAnggota")
SHALLOW_DECIMAL = ("Apps/Shared/LocationProvider.swift",
                   "NumberFormat.decimal(",
                   "NumberFormat.salahAnggota(")
# KONTROL yang **bisa salah**: `allCases` hanya sah karena `Planet`
# mengonformasi `CaseIterable`. Cabut konformansinya di **model** dan
# `Planet.allCases` di `Apps/` menjadi cacat sungguhan — jadi keadaan ini
# benar-benar mengukur "pelewatan sintesis" dan bukan sekadar "tidak ada
# yang diubah". Mengubah `allCases` menjadi `allCases` (no-op) akan lulus
# tanpa mengukur apa pun, dan itu kelas cacat yang dicari repo ini.
DROP_CASEITERABLE = ("Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift",
                     "public enum Planet: String, Equatable, Sendable, CaseIterable {",
                     "public enum Planet: String, Equatable, Sendable {")
# Komentar & string: cari fragmen netral yang pasti ada di view.
COMMENT_ANCHOR = ("Apps/Shared/CelestialVisualView.swift",
                  "/// Visual prosedural untuk benda langit",
                  "/// Visual prosedural NumberFormat.salahAnggota")
STRING_ANCHOR = ("Apps/Shared/CelestialVisualView.swift",
                 'var isConfirmed: Bool = false',
                 'var isConfirmed: Bool = false // "NumberFormat.salahAnggota"')


def require_clean() -> None:
    mutasi_sumber.require_clean_sources(WATCHED)


def copy_repo() -> str:
    """Salin pohon utuh. Salinan parsial membuat aturan lain berbunyi dan
    menenggelamkan tanda yang dicari (lihat docstring Aturan 10)."""
    workdir = tempfile.mkdtemp(prefix="anggota-bertahap-")
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
    """Isi seksi Aturan 26 **sesudah judulnya**, bukan judulnya.

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
    """Aturan 26 berbunyi bila seksinya **tidak** memuat penanda "Bersih".

    `finding()` sudah mengembalikan "" untuk seksi yang bersih, jadi cukup
    uji tidak-kosong. Detektor berbasis kata kunci (mis. "GAGAL") akan
    **diam** di sini: tidak ada satu pun temuan Aturan 26 yang memuat kata
    itu, sehingga setiap keadaan cacat dilaporkan hijau — persis kelas cacat
    harness yang berkas ini ada untuk mencegah.
    """
    return finding(out) != ""


def old_lint() -> str:
    """Versi `origin/main`, untuk arah "cacat ini dulu lolos"."""
    p = subprocess.run(["git", "show", "origin/main:swift-ui-lint.sh"],
                       cwd=ROOT, capture_output=True, text=True)
    if p.returncode != 0:
        p = subprocess.run(["git", "show", "HEAD:swift-ui-lint.sh"],
                           cwd=ROOT, capture_output=True, text=True)
    return p.stdout


# (nama, relpath, cari, ganti, harus_merah, old_must_red)
# `old_must_red` hanya untuk keadaan cacat (bool):
#   True  -> versi origin/main HARUS merah. Dipakai untuk arah yang **sudah**
#            dijaga sebelum siklus ini (2 tingkat, keadaan 3): kalau versi lama
#            hijau di sana, perbaikan ini merusak arah lama — berhenti.
#   False -> versi origin/main HARUS hijau. Dipakai untuk cacat yang **baru**
#            ditemukan siklus ini (3 tingkat, keadaan 1, 2): kalau versi lama
#            sudah merah, cacatnya bukan yang ditutup perbaikan ini — berhenti.
#   None  -> kontrol negatif, tidak dibandingkan ke versi lama.
CASES = [
    ("0. kode apa adanya", None, None, None, False, None),
    ("1. Planet.saturn -> .salahAnggota (3 tingkat, cacat baru)",
     *DEEP_SATURN, True, False),
    ("2. Planet.allCases -> .salahAnggota (3 tingkat, diwariskan, cacat baru)",
     *DEEP_ALLCASES, True, False),
    ("3. NumberFormat.decimal -> .salahAnggota (2 tingkat, lama)",
     *SHALLOW_DECIMAL, True, True),
    ("4. cabut CaseIterable di model: Planet.allCases jadi cacat",
     *DROP_CASEITERABLE, True, None),
    ("5. KONTROL: mutasi di KOMENTAR (hijau)",
     *COMMENT_ANCHOR, False, None),
    ("6. KONTROL: mutasi di STRING literal (hijau)",
     *STRING_ANCHOR, False, None),
]


def main() -> int:
    require_clean()
    old = old_lint()
    failures: list[str] = []

    for name, target, find, repl, must_fire, old_must_red in CASES:
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

            # Arah kedua: khusus keadaan cacat (old_must_red tidak None).
            if must_fire:
                out_old = run_lint(workdir, old)
                old_red = fired(out_old)
                if old_must_red and not old_red:
                    failures.append(
                        f"  {name}: versi origin/main hijau padahal arah ini "
                        f"sudah dijaga sebelum siklus ini — perbaikan ini "
                        f"merusak arah lama")
                elif old_must_red is False and old_red:
                    failures.append(
                        f"  {name}: versi origin/main SUDAH merah — cacatnya "
                        f"bukan yang ditutup perbaikan ini")
                print(f"  {name}")
                print(f"      baru: {'MERAH' if got else 'hijau'} (sesuai)   "
                      f"lama: {'MERAH' if old_red else 'hijau'}")
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
