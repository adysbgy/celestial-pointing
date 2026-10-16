#!/usr/bin/env python3
"""Buktikan Aturan 36 berbunyi pada kelasnya, dan **diam pada kode benar**.

Kenapa berkas ini ada.

Aturan 34 sudah lama melarang **literal** di posisi penjaga identitas
(`isConfirmed: true`), dan Aturan 24 sudah menuntut nama penjaganya disebut.
Terukur di awal siklus ini, keduanya hijau pada dua bentuk yang
**mengompilasi** dan mematahkan larangan paling keras PRD
("uncertainty > false confidence") dengan arah yang paling parah:

    isConfirmed: !isConfirmed     ->  swift-ui-lint.sh  LULUS (exit 0)
                                      swift-typecheck.sh LULUS (exit 0)
    isConfirmed: isStale          ->  swift-ui-lint.sh  LULUS (exit 0)

Bentuk pertama memaksa ciri pengenal tampil **tepat saat engine ragu**; bentuk
kedua memakai fakta yang tidak ada hubungannya dengan keyakinan. Yang terbaca
di layar sama pada keduanya: bintang tetap berwarna Betelgeuse, galaksi tetap
berpaluk, badge di sebelahnya tetap bertuliskan "Ragu".

Kenapa dua aturan yang ada diam di sana:

  * Aturan 34 hanya menguji apakah nilainya **literal** `true`/`false`. Semua
    ekspresi non-literal lolos, entah benar entah salah.
  * Aturan 24 menguji **substring**: nama `drawableStarColorIndex` ada, dan
    `isConfirmed` ada di dalam daftar argumen — jadi "Bersih". Warna yang
    justru paling mahal (warna spektral adalah ciri pengenal) tidak pernah
    diperiksa nilainya.

Yang diukur berkas ini, dua arah:

  a. **Sasaran** — setiap bentuk cacat harus memerahkan Aturan 36, dan
     temuannya harus menyebut **berkas yang disuntik**. Menuntut "ada yang
     merah" saja tidak cukup: aturan lain bisa berbunyi karena salinan pohon
     yang tidak lengkap, dan laporan ini akan menyalahkan yang salah.
  b. **Ketepatan** — kode yang benar harus tetap hijau. Ini bukan hiasan:
     gerbang yang memerah pada kode benar akan dilonggarkan orang, dan
     pelonggarannya akan menghapus cakupan yang baru saja ditambahkan.

**Non-vakuositas diukur, bukan diklaim.** Harness menjalankan keadaan cacat
sekali lagi dengan **program Aturan 36 dikembalikan ke bentuk "hanya
literal"** (perilaku Aturan 34). Kalau keadaan-keadaan itu berbalik hijau di
sana, maka yang berbunyi memang perbaikannya — bukan sebab lain.

**Kenapa salinannya Utuh (`Apps/` + `Packages/`).** Aturan 36 membaca
**deklarasi aksesor** dari `Packages/PointingKit` untuk tahu fungsi mana yang
harus diawasi, lalu memindai pemanggilannya di `Apps/`. Salinan yang hanya
memuat `Apps/` membuat daftar aksesornya kosong, dan aturan itu melaporkan
"tidak mengukur apa pun" untuk **setiap** keadaan cacat — persis cacat
salinan-parsial yang sudah pernah mengukur ulang indeks 69 -> 6 di repo ini.

**Kenapa penyuntikan tidak ke berkas produksi.** Harness ini menyalin pohon
ke direktori sementara dan menyuntik di sana. Hanya itu yang membuat
"pulih persis" tidak perlu dipercaya: tidak ada yang dimutasi untuk dipulihkan.

Pakai: python3 Tools/bukti-mutasi-penjaga-faktor.py
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
import mutasi_sumber  # noqa: E402  (butuh ROOT dulu)

#: Berkas yang dibaca harness ini — lewat penjaga yang **sama** dengan semua
#: harness `bukti-mutasi-*.py`, bukan salinan penjaga sendiri.
WATCHED = [LINT,
           os.path.join(ROOT, "Apps"),
           os.path.join(ROOT, "Packages", "PointingKit")]

#: Berkas yang disuntik untuk setiap keadaan.
TARGET = "Apps/Shared/CelestialVisualView.swift"

#: Tiga penjaga identitas di berkas itu, dengan nilainya yang benar hari ini.
#: Sengaja tiga, bukan satu: cacat yang sama pernah hidup di ketiganya
#: (`drawable` planet, `drawableStarColorIndex` bintang, `drawableMorphology`
#: objek langit dalam), dan harness yang hanya menguji satu akan melaporkan
#: "tertutup" untuk kelas yang masih terbuka di dua tempat lain.
GUARDS = [
    ("palet planet", "planet.palette.drawable(isConfirmed: isConfirmed)"),
    ("warna bintang",
     "CelestialVisual.drawableStarColorIndex(\n"
     "            visual.colorIndexBV, isConfirmed: isConfirmed)"),
    ("bentuk langit dalam",
     "DeepSkyCatalogue.drawableMorphology(forObjectID: $0, "
     "isConfirmed: isConfirmed)"),
]

#: Keadaan cacat: (nama, pengganti nilai penjaga, harus_berbunyi).
#:
#: `None` berarti "tidak diubah" (baseline). Dua bentuk pertama adalah cacat
#: yang ditemukan siklus ini, dan keduanya **mengompilasi**.
DEFECT_CASES = [
    ("baseline (kode apa adanya)", None, False),
    ("penjaga dibalik  !isConfirmed", "!isConfirmed", True),
    ("nama lain  isStale", "isStale", True),
    ("nama lain  verifikasi (bukan keyakinan)", "verifikasi", True),
    ("kualifikasi asing  object.sudahDikonfirmasi", "object.sudahDikonfirmasi", True),
    ("baseline ulang (pulih)", None, False),
]

#: Keadaan **sah** yang harus tetap hijau. Kalau salah satu memerah, aturannya
#: menolak pekerjaan yang benar — dan itu cara paling cepat membuatnya
#: dilonggarkan sampai tidak menjaga apa pun.
ALLOWED_CASES = [
    ("diteruskan apa adanya", "isConfirmed"),
    ("kualifikasi keyakinan engine", "engine.confirmsDisplayedIdentity"),
    ("kualifikasi keyakinan snapshot", "snapshot.confirmsIdentity"),
]

#: Berkas & badan `confirmsDisplayedIdentity` — saklar tunggal yang
#: memutuskan apakah gambar boleh mengklaim identitas.
#:
#: Kenapa diawasi **badannya**, bukan cuma pemanggilnya: nilai ini hidup di
#: `Apps/Shared/PointingEngine.swift`, yang tidak pernah dibangun
#: `swift-test.sh`, jadi tidak ada uji Linux yang bisa menahannya. Terukur:
#: mengganti badannya jadi `!isDisplayingStaleObject` membiarkan seluruh 37
#: aturan lulus. `.uncertain` ikut `hasAnswer`, sehingga `!isStale` benar
#: tepat saat engine menyatakan ragu — cincin Saturnus tampil di sebelah
#: badge "Ragu".
BODY_TARGET = "Apps/Shared/PointingEngine.swift"
BODY_OLD = ("    public var confirmsDisplayedIdentity: Bool {\n"
            "        snapshot.confirmsIdentity(lastLocked: lastLockedObject)\n"
            "    }")

#: (nama, badan pengganti, harus_berbunyi). `None` = baseline.
BODY_CASES = [
    ("baseline (badan apa adanya)", None, False),
    ("turun dari !isStale", "    public var confirmsDisplayedIdentity: Bool {\n"
                            "        !isDisplayingStaleObject\n"
                            "    }", True),
    ("negasi fakta keyakinan",
     "    public var confirmsDisplayedIdentity: Bool {\n"
     "        !snapshot.confirmsIdentity(lastLocked: lastLockedObject)\n"
     "    }", True),
    ("literal true", "    public var confirmsDisplayedIdentity: Bool {\n"
                     "        true\n"
                     "    }", True),
    ("nama lain  isCalibrated", "    public var confirmsDisplayedIdentity: Bool {\n"
                                "        snapshot.isCalibrated\n"
                                "    }", True),
    ("baseline ulang (pulih)", None, False),
]

#: Versi lama aturan: **hanya** menolak literal — yaitu perilaku yang setara
#: dengan Aturan 34. Dipakai untuk mengukur non-vakuositas.
LEGACY_ONLY_LITERAL = (
    "                ekspresi = nilai.group(1).strip()\n"
    "                if re.match(r'^\\\\s*(true|false)\\\\s*$', ekspresi):\n"
    "                    baris = kode[:m.start()].count('\\n') + 1\n"
    "                    masalah.append('  %s:%d: LEGACY' % (path, baris))\n"
)


def require_clean() -> None:
    """Hentikan kalau yang dibaca sudah menyimpang dari HEAD.

    Laporan di sini mengklaim sesuatu tentang **kode yang dikomit**. Dijalankan
    di atas WIP orang lain, ia akan melaporkan hasil atas kode yang tidak
    pernah ada di `main`.
    """
    mutasi_sumber.require_clean_sources(WATCHED)


def extract_rule(number: str) -> str:
    """Ambil program Python Aturan `number` dari `swift-ui-lint.sh`.

    Batasnya header aturan berikutnya — aturan terakhir membentang sampai EOF.
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
            sys.exit(f"GERBANG: Aturan {number} tidak menjalankan "
                     f"python3 - <<'PY' — pembaca ini perlu disesuaikan.")
        return prog.group(1)
    sys.exit(f"GERBANG: Aturan {number} tidak ditemukan di swift-ui-lint.sh.")


def run_rule(program: str, workdir: str) -> tuple[int, str]:
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run([sys.executable, "-c", program], cwd=workdir,
                       capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def copy_repo() -> str:
    """Salin **utuh**: `Apps/` untuk pemanggil, `Packages/` untuk deklarasi.

    Salinan parsial bukan kerapian — ia mengubah hasil. Aturan 36 belajar
    fungsi mana yang harus diawasi dari `Packages/PointingKit`; tanpa pohon
    itu, daftar aksesornya kosong dan aturannya melaporkan "tidak mengukur
    apa pun" untuk setiap keadaan cacat.
    """
    workdir = tempfile.mkdtemp(prefix="penjaga-faktor-")
    shutil.copytree(os.path.join(ROOT, "Apps"), os.path.join(workdir, "Apps"))
    shutil.copytree(os.path.join(ROOT, "Packages"),
                    os.path.join(workdir, "Packages"),
                    ignore=shutil.ignore_patterns(".build", ".swiftpm"))
    return workdir


def inject_guard(workdir: str, old: str, new: str) -> None:
    """Ganti nilai penjaga `old` -> `new` di salinan berkas target.

    Menghentikan harness kalau jangkarnya tidak ketemu **tepat satu**. Jangkar
    yang meleset pernah membuat sebuah harness melaporkan keadaan cacatnya
    hijau — bukan karena aturannya buta, melainkan karena berkasnya tidak
    pernah berubah.
    """
    path = os.path.join(workdir, TARGET)
    text = open(path, encoding="utf-8").read()
    n = text.count(old)
    if n != 1:
        sys.exit(f"GERBANG: jangkar penjaga tidak unik ({n} kali) di {TARGET}: "
                 f"{old!r} — harness ini tidak bisa mengukur.\n"
                 f"Jangkarnya mungkin berubah di sumber; perbarui GUARDS.")
    open(path, "w", encoding="utf-8").write(text.replace(old, new))


def inject_body(workdir: str, old: str, new: str) -> None:
    """Ganti **badan** `confirmsDisplayedIdentity` di salinan berkasnya.

    Sama seperti `inject_guard`, jangkar yang tidak muncul tepat satu kali
    menghentikan harness: jangkar yang meleset membuat keadaan cacat
    dilaporkan hijau padahal berkasnya tidak pernah berubah.
    """
    path = os.path.join(workdir, BODY_TARGET)
    text = open(path, encoding="utf-8").read()
    n = text.count(old)
    if n != 1:
        sys.exit(f"GERBANG: jangkar badan tidak unik ({n} kali) di "
                 f"{BODY_TARGET}: {old!r} — harness ini tidak bisa mengukur.")
    open(path, "w", encoding="utf-8").write(text.replace(old, new))


def to_legacy(program: str) -> str:
    """Kembalikan aturannya ke bentuk **hanya-literal** (perilaku Aturan 34).

    Potongan lama menggantikan blok pengambilan keputusan; nama-nama variabel
    di sekitarnya dipertahankan supaya yang berubah hanya keputusannya.
    """
    marker = "                ekspresi = nilai.group(1).strip()\n"
    if marker not in program:
        sys.exit("GERBANG: program Aturan 36 tidak memuat penanda keputusan "
                 "yang diharapkan; harness non-vakuositas ini perlu "
                 "disesuaikan sebelum ia bisa mengukur apa pun.")
    head, _, tail = program.partition(marker)
    # Buang sisa blok keputusan sampai baris `if diperiksa == 0:`.
    _, sep, rest = tail.partition("if diperiksa == 0:")
    if not sep:
        sys.exit("GERBANG: tidak menemukan blok penutup Aturan 36.")
    return head + LEGACY_ONLY_LITERAL + "if diperiksa == 0:" + rest


def main() -> int:
    require_clean()
    program = extract_rule("36")

    failures: list[str] = []
    ran = 0

    # ── a. Sasaran: cacat harus berbunyi, dan menyebut berkasnya. ──────────
    for guard_name, guard_text in GUARDS:
        workdir = copy_repo()
        try:
            for case_name, replacement, must_fire in DEFECT_CASES:
                # Salinan bersih tiap keadaan: tanpa itu suntikan keadaan
                # sebelumnya masih ada, dan "baseline ulang" akan diukur di
                # atas berkas yang masih memuat cacat.
                shutil.rmtree(os.path.join(workdir, "Apps"))
                shutil.copytree(os.path.join(ROOT, "Apps"),
                                os.path.join(workdir, "Apps"))
                if replacement is not None:
                    inject_guard(workdir, guard_text,
                                 guard_text.replace("isConfirmed: isConfirmed",
                                                    f"isConfirmed: {replacement}"))
                # Untuk penjaga ber-argumen ganda, ganti bentuk `..., guard)`.
                _, out = run_rule(program, workdir)
                fired = bool(out.strip())
                ran += 1
                if fired != must_fire:
                    failures.append(
                        f"  {guard_name} / {case_name}: "
                        f"{'hijau' if not fired else 'merah'} pada keadaan "
                        f"yang seharusnya "
                        f"{'berbunyi' if must_fire else 'diam'}")
                # Temuannya harus menyebut berkas yang disuntik: salinan yang
                # tidak lengkap membuat aturan **lain** berbunyi, dan harness
                # yang hanya menuntut "ada yang merah" tidak bisa membedakan.
                if fired and must_fire and TARGET not in out:
                    failures.append(
                        f"  {guard_name} / {case_name}: berbunyi, tetapi "
                        f"temuannya tidak menyebut {TARGET} — yang merah "
                        f"bukan aturan ini")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # ── b. Ketepatan: tiga bentuk sah harus tetap hijau. ──────────────────
    for guard_name, guard_text in GUARDS:
        workdir = copy_repo()
        try:
            for case_name, replacement in ALLOWED_CASES:
                shutil.rmtree(os.path.join(workdir, "Apps"))
                shutil.copytree(os.path.join(ROOT, "Apps"),
                                os.path.join(workdir, "Apps"))
                inject_guard(workdir, guard_text,
                             guard_text.replace("isConfirmed: isConfirmed",
                                                f"isConfirmed: {replacement}"))
                _, out = run_rule(program, workdir)
                ran += 1
                if out.strip():
                    failures.append(
                        f"  {guard_name} / bentuk sah `{replacement}`: "
                        f"MERAH padahal harus diam — {out.strip().splitlines()[0]}")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # ── b2. Badan `confirmsDisplayedIdentity` sendiri. ─────────────────────
    #
    # Kenapa keadaan-keadaan ini terpisah dari (a): yang dimutasi di sini
    # **bukan** argumen pemanggil, melainkan badan properti yang
    # menghasilkan faktanya. Aturan versi sebelumnya hanya membaca argumen,
    # jadi seluruh keadaan di bawah ini **hijau** di sana — terukur, bukan
    # ditebak (lihat docstring cabangnya di `swift-ui-lint.sh`).
    for case_name, body, must_fire in BODY_CASES:
        workdir = copy_repo()
        try:
            if body is not None:
                inject_body(workdir, BODY_OLD, body)
            _, out = run_rule(program, workdir)
            ran += 1
            fired = bool(out.strip())
            if fired != must_fire:
                failures.append(
                    f"  badan confirmsDisplayedIdentity / {case_name}: "
                    f"{'hijau' if not fired else 'merah'} pada keadaan yang "
                    f"seharusnya {'berbunyi' if must_fire else 'diam'}")
            # Temuan harus menyebut berkasnya: kalau yang merah aturan lain,
            # harness ini akan mengklaim kemenangan yang bukan miliknya.
            if fired and must_fire and BODY_TARGET not in out:
                failures.append(
                    f"  badan confirmsDisplayedIdentity / {case_name}: "
                    f"berbunyi, tetapi temuannya tidak menyebut "
                    f"{BODY_TARGET}")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # ── c. Non-vakuositas: dengan aturannya dikembalikan ke hanya-literal,
    #       keadaan cacat harus **berbalik hijau**. ─────────────────────────
    legacy = to_legacy(program)
    guard_name, guard_text = GUARDS[0]
    workdir = copy_repo()
    try:
        for case_name, replacement, must_fire in DEFECT_CASES:
            if not must_fire:
                continue
            shutil.rmtree(os.path.join(workdir, "Apps"))
            shutil.copytree(os.path.join(ROOT, "Apps"),
                            os.path.join(workdir, "Apps"))
            inject_guard(workdir, guard_text,
                         guard_text.replace("isConfirmed: isConfirmed",
                                            f"isConfirmed: {replacement}"))
            _, out = run_rule(legacy, workdir)
            ran += 1
            if out.strip():
                failures.append(
                    f"  non-vakuositas / {case_name}: versi hanya-literal "
                    f"juga berbunyi — keadaan ini tidak membuktikan "
                    f"perbaikan siklus ini mengukur apa pun")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    if ran < 3:
        sys.exit("GERBANG: kurang dari tiga keadaan benar-benar dijalankan; "
                 "'sesuai harapan' atas hampir nol pembuktian bukan bukti.")

    konteks = f"Aturan 36: penjaga identitas menerima faktornya"
    if failures:
        print(f"{konteks} — {len(failures)} keadaan TIDAK sesuai harapan "
              f"(dari {ran}):")
        print("\n".join(failures))
        return 1
    print(f"{konteks} — {ran} keadaan, semuanya sesuai harapan "
          f"({len(GUARDS)} penjaga x {len(DEFECT_CASES)} keadaan cacat, "
          f"{len(GUARDS)} x {len(ALLOWED_CASES)} bentuk sah, "
          f"{len(BODY_CASES)} keadaan badan confirmsDisplayedIdentity, "
          f"{len([c for c in DEFECT_CASES if c[2]])} non-vakuositas).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
