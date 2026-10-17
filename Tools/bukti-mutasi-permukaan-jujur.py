#!/usr/bin/env python3
"""Buktikan Aturan 38 berbunyi pada kelasnya, dan **diam pada kode benar**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, merah dengan
pesan yang menunjuk berkas yang disuntik, dan **diam** pada kode yang benar.
Empat syarat, bukan satu: harness yang hanya menuntut "ada yang merah" akan
lulus meski yang berbunyi adalah aturan lain di salinan pohon yang tidak
lengkap.

Kelas cacat yang ditutupnya, **diukur** bukan ditebak.

`Apps/Shared/PointingEngine.swift` punya tiga permukaan kejujuran yang lahir
dari satu keputusan `PointingSnapshot` yang teruji di Linux:

    isDisplayingStaleObject   -> snapshot.isDisplayingStaleObject(lastLocked:)
    confirmsDisplayedIdentity -> snapshot.confirmsIdentity(lastLocked:)
    carriesUncertaintyMarker  -> snapshot.carriesUncertaintyMarker(lastLocked:)

Aturan 36 menambat **satu** nama di antaranya (`confirmsDisplayedIdentity`).
Terukur pada pohon sebelum Aturan 38, dengan salinan utuh dan proses baru:

    isDisplayingStaleObject   -> !snapshot.isDisplayingStaleObject(...)   HIJAU
    isDisplayingStaleObject   -> true                                     HIJAU
    isDisplayingStaleObject   -> snapshot.isCalibrated                    HIJAU
    carriesUncertaintyMarker  -> !snapshot.carriesUncertaintyMarker(...)  HIJAU
    carriesUncertaintyMarker  -> true                                     HIJAU
    carriesUncertaintyMarker  -> snapshot.isCalibrated                    HIJAU

Enam keadaan, **nol** yang berbunyi. Dua di antaranya lebih parah daripada
yang ditutup Aturan 36, dan keduanya tidak simetris dengan pasangannya:

  * `isDisplayingStaleObject -> true` membuat peringatan "sisa pandangan
    sebelumnya" menyala **terus-menerus** pada jam: setiap hasil, betapapun
    segar, dituduh basi. Pasangannya (`false`) membungkamnya selamanya.
  * `carriesUncertaintyMarker -> false` membuat **nama kandidat** tampil
    sebagai temuan di layar redup — persis keadaan yang menurut docstring
    properti ini paling berbahaya, karena di sanalah nama kandidat menjadi
    huruf terbesar di layar.

Kenapa aturan ini **menurunkan** permukaannya dari model, bukan mendaftar
namanya: daftar tiga nama akan hijau lagi besok pagi begitu permukaan keempat
ditambahkan. Karena itu harness ini menguji **ketiga** permukaan sekaligus,
dan menuntut masing-masing berbunyi.

**Non-vakuositas diukur, bukan diklaim.** Setiap keadaan cacat dijalankan
sekali lagi dengan program Aturan 38 **tanpa** cabang badannya (versi yang
hanya mengawal argumen pemanggil, seperti Aturan 36). Kalau keadaan-keadaan
itu berbalik hijau di sana, maka yang berbunyi memang cabang yang ditambahkan
siklus ini — bukan sebab lain.

**Kenapa salinannya utuh (`Apps/` + `Packages/`).** Aturan 38 membaca
keanggotaan `Bool` model dari `Packages/PointingKit`; tanpa pohon itu
himpunannya kosong dan aturan melaporkan "tidak mengukur apa pun" untuk
setiap keadaan — persis cacat salinan-parsial yang sudah pernah mengukur
ulang indeks 69 -> 6 di repo ini.

**Kenapa penyuntikan tidak ke berkas produksi.** Harness ini menyalin pohon ke
direktori sementara dan menyuntik di sana. Hanya itu yang membuat "pulih
persis" tidak perlu dipercaya: tidak ada yang dimutasi untuk dipulihkan.

Pakai: python3 Tools/bukti-mutasi-permukaan-jujur.py
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

TARGET = "Apps/Shared/PointingEngine.swift"

#: Tiga permukaan kejujuran, dengan badannya yang benar hari ini.
#:
#: Sengaja tiga, bukan satu: cacat yang sama bisa hidup di masing-masing, dan
#: harness yang hanya menguji satu akan melaporkan "tertutup" untuk kelas yang
#: masih terbuka di dua tempat lain.
PERMUKAAN = {
    "isDisplayingStaleObject":
        "        snapshot.isDisplayingStaleObject(lastLocked: lastLockedObject)\n",
    "confirmsDisplayedIdentity":
        "        snapshot.confirmsIdentity(lastLocked: lastLockedObject)\n",
    "carriesUncertaintyMarker":
        "        snapshot.carriesUncertaintyMarker(lastLocked: lastLockedObject)\n",
}

#: Keadaan cacat: (nama, badan pengganti, harus_berbunyi). `None` = baseline.
#:
#: Format `%s` diisi nama anggota model yang bersangkutan, supaya keadaan
#: "negasi" benar-benar menegasikan **faktanya sendiri** dan bukan menyalin
#: nama tetangganya — keadaan yang secara kebetulan juga berbunyi.
KEADAAN = [
    ("baseline (kode apa adanya)", None, False),
    ("negasi faktanya sendiri", "        !snapshot.%s(lastLocked: lastLockedObject)\n", True),
    ("literal true", "        true\n", True),
    ("literal false", "        false\n", True),
    ("fakta lain: isCalibrated", "        snapshot.isCalibrated\n", True),
    ("fakta tetangga: hasAnswer", "        snapshot.hasAnswer\n", True),
    ("baseline ulang (pulih)", None, False),
]

#: Keadaan **sah** yang harus tetap hijau. Kalau salah satu memerah, aturannya
#: menolak pekerjaan yang benar — dan itu cara paling cepat membuatnya
#: dilonggarkan sampai tidak menjaga apa pun.
#:
#: Yang terpenting di sini adalah bentuk **keempat**: `confirmsDisplayedIdentity`
#: namanya memang tidak ada di model (ia penamaan sisi UI untuk
#: `confirmsIdentity`), jadi kalau aturannya hanya mencocokkan nama, permukaan
#: yang paling penting justru lolos.
SAH = [
    ("diteruskan apa adanya (isDisplayingStaleObject)",
     "isDisplayingStaleObject",
     "        snapshot.isDisplayingStaleObject(lastLocked: lastLockedObject)\n"),
    ("penamaan sisi UI: confirmsDisplayedIdentity -> confirmsIdentity",
     "confirmsDisplayedIdentity",
     "        snapshot.confirmsIdentity(lastLocked: lastLockedObject)\n"),
]

#: Nama anggota model untuk tiap permukaan — dipakai mengisi `%s` pada
#: keadaan negasi. `carriesUncertaintyMarker` dan `isDisplayingStaleObject`
#: namanya sama dengan anggotanya; `confirmsDisplayedIdentity` tidak.
ANGGOTA = {
    "isDisplayingStaleObject": "isDisplayingStaleObject",
    "confirmsDisplayedIdentity": "confirmsIdentity",
    "carriesUncertaintyMarker": "carriesUncertaintyMarker",
}


def require_clean() -> None:
    """Hentikan kalau yang dibaca sudah menyimpang dari HEAD.

    Laporan di sini mengklaim sesuatu tentang **kode yang dikomit**.
    Dijalankan di atas WIP orang lain, ia akan melaporkan hasil atas kode
    yang tidak pernah ada di `main`.
    """
    mutasi_sumber.require_clean_sources(WATCHED)


def extract_rule(number: str) -> str:
    """Ambil program Python Aturan `number` dari `swift-ui-lint.sh`.

    Batasnya header aturan berikutnya — aturan terakhir membentang sampai
    `PY\\n)` penutupnya.
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
    """Salin **utuh**: `Apps/` untuk permukaannya, `Packages/` untuk model.

    Salinan parsial bukan kerapian — ia mengubah hasil. Aturan 38 belajar
    anggota `Bool` mana yang ada di model dari `Packages/PointingKit`; tanpa
    pohon itu himpunannya kosong dan aturannya berhenti mengukur.
    """
    workdir = tempfile.mkdtemp(prefix="permukaan-jujur-")
    shutil.copytree(os.path.join(ROOT, "Apps"), os.path.join(workdir, "Apps"))
    shutil.copytree(os.path.join(ROOT, "Packages"),
                    os.path.join(workdir, "Packages"),
                    ignore=shutil.ignore_patterns(".build", ".swiftpm"))
    return workdir


def inject_body(workdir: str, prop: str, new_body: str) -> None:
    """Ganti badan `var <prop>: Bool` di salinan berkasnya.

    Jangkar yang tidak muncul **tepat satu** kali menghentikan harness:
    jangkar yang meleset membuat keadaan cacat dilaporkan hijau padahal
    berkasnya tidak pernah berubah.
    """
    path = os.path.join(workdir, TARGET)
    text = open(path, encoding="utf-8").read()
    old = "    public var %s: Bool {\n%s    }" % (prop, PERMUKAAN[prop])
    n = text.count(old)
    if n != 1:
        sys.exit(f"GERBANG: jangkar badan tidak unik ({n} kali) di {TARGET}: "
                 f"{prop!r} — harness ini tidak bisa mengukur.\n"
                 f"Jangkarnya mungkin berubah di sumber; perbarui PERMUKAAN.")
    new = "    public var %s: Bool {\n%s    }" % (prop, new_body)
    open(path, "w", encoding="utf-8").write(text.replace(old, new))


def to_legacy(program: str) -> str:
    """Cabang badan dikosongkan — aturan hanya mengawal argumen pemanggil.

    Itu perilaku Aturan 36. Kalau keadaan-keadaan cacat tetap berbunyi di
    sini, maka yang berbunyi bukan cabang yang ditambahkan siklus ini, dan
    harness ini tidak membuktikan apa pun tentang perbaikannya.
    """
    marker = 'DEKL = re.compile(r"\\bvar\\s+([A-Za-z_]\\w*)\\s*:\\s*Bool\\s*\\{")'
    if marker not in program:
        sys.exit("GERBANG: program Aturan 38 tidak memuat penanda `DEKL`; "
                 "harness non-vakuositas ini perlu disesuaikan sebelum ia "
                 "bisa mengukur apa pun.")
    return program[:program.index(marker)] + (
        "DEKL = re.compile(r'(?!x)x')\n"   # tidak pernah cocok: nol situs
    )


def main() -> int:
    require_clean()
    program = extract_rule("38")

    failures: list[str] = []
    ran = 0

    # ── a. Sasaran: setiap permukaan x setiap keadaan cacat harus berbunyi. ─
    for prop in sorted(PERMUKAAN):
        workdir = copy_repo()
        try:
            for nama, body, must_fire in KEADAAN:
                # Salinan bersih tiap keadaan: tanpa itu suntikan keadaan
                # sebelumnya masih ada, dan "baseline ulang" akan diukur di
                # atas berkas yang masih memuat cacat.
                shutil.rmtree(os.path.join(workdir, "Apps"))
                shutil.copytree(os.path.join(ROOT, "Apps"),
                                os.path.join(workdir, "Apps"))
                if body is not None:
                    inject_body(workdir, prop,
                                body % ANGGOTA[prop] if "%s" in body else body)
                _, out = run_rule(program, workdir)
                fired = bool(out.strip())
                ran += 1
                if fired != must_fire:
                    failures.append(
                        f"  {prop} / {nama}: "
                        f"{'hijau' if not fired else 'merah'} pada keadaan "
                        f"yang seharusnya {'berbunyi' if must_fire else 'diam'}")
                # Temuannya harus menyebut berkas yang disuntik: salinan yang
                # tidak lengkap membuat aturan **lain** berbunyi, dan harness
                # yang hanya menuntut "ada yang merah" tidak bisa membedakan.
                if fired and must_fire and TARGET not in out:
                    failures.append(
                        f"  {prop} / {nama}: berbunyi, tetapi temuannya "
                        f"tidak menyebut {TARGET} — yang merah bukan aturan ini")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # ── b. Ketepatan: bentuk sah harus tetap hijau. ────────────────────────
    for nama, prop, body in SAH:
        workdir = copy_repo()
        try:
            inject_body(workdir, prop, body)
            _, out = run_rule(program, workdir)
            ran += 1
            if out.strip():
                failures.append(
                    f"  bentuk sah `{nama}`: MERAH padahal harus diam — "
                    f"{out.strip().splitlines()[0]}")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # ── c. Non-vakuositas: tanpa cabang badannya, keadaan cacat berbalik
    #       hijau — jadi yang berbunyi memang cabang yang ditambahkan. ──────
    legacy = to_legacy(program)
    workdir = copy_repo()
    try:
        for nama, body, must_fire in KEADAAN:
            if not must_fire:
                continue
            shutil.rmtree(os.path.join(workdir, "Apps"))
            shutil.copytree(os.path.join(ROOT, "Apps"),
                            os.path.join(workdir, "Apps"))
            prop = "isDisplayingStaleObject"
            inject_body(workdir, prop,
                        body % ANGGOTA[prop] if "%s" in body else body)
            _, out = run_rule(legacy, workdir)
            ran += 1
            if out.strip():
                failures.append(
                    f"  non-vakuositas / {nama}: versi tanpa cabang badan "
                    f"juga berbunyi — keadaan ini tidak membuktikan bahwa "
                    f"perbaikan siklus ini mengukur apa pun")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    if ran < 3:
        sys.exit("GERBANG: kurang dari tiga keadaan benar-benar dijalankan; "
                 "'sesuai harapan' atas hampir nol pembuktian bukan bukti.")

    konteks = "Aturan 38: permukaan kejujuran di Apps/ meneruskan faktanya"
    if failures:
        print(f"{konteks} — {len(failures)} keadaan TIDAK sesuai harapan "
              f"(dari {ran}):")
        print("\n".join(failures))
        return 1
    print(f"{konteks} — {ran} keadaan, semuanya sesuai harapan "
          f"({len(PERMUKAAN)} permukaan x {len(KEADAAN)} keadaan, "
          f"{len(SAH)} bentuk sah, "
          f"{len([c for c in KEADAAN if c[2]])} non-vakuositas).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
