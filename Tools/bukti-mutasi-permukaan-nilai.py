#!/usr/bin/env python3
"""Buktikan Aturan 42 berbunyi pada kelasnya, dan **diam pada kode benar**.

Kenapa berkas ini ada, dan kenapa bukan tambahan pada
`bukti-mutasi-permukaan-jujur.py`.

Aturan 38 dan Aturan 42 mengawal kelas yang sama dari dua sisi yang
**berbeda tipe**: 38 membaca `var x: Bool { ... }`, 42 membaca `var x: T? {
... }` dengan `T` non-Bool. Keduanya hidup di berkas yang sama
(`Apps/Shared/PointingEngine.swift`), dan keduanya lahir dari satu kesalahan
yang sama — **permukaan di `Apps/` tidak dibangun `swift-test.sh` di Linux**.

Karena badan 42 berbeda tipe, badan 38 tidak bisa mengukurnya: regex `Bool`
tidak pernah cocok pada `CelestialObject?`. Menyatukan keduanya dalam satu
harness akan menyembunyikan justru fakta yang paling penting — bahwa kelas
ini punya **dua** tipe dan hanya satu yang dijaga sampai siklus ini.

Yang terukur sebelum Aturan 42 ada (salinan utuh, proses baru, `Apps/` +
`Packages/` dibawa, mutasi yang **mengompilasi**):

    displayedObject  -> lastLockedObject                     swift-ui-lint.sh LULUS
    displayedObject  -> nil                                  swift-ui-lint.sh LULUS
    pointing         -> snapshot.calibratedPointing          swift-ui-lint.sh LULUS
    answeredIntent   -> nil                                  swift-ui-lint.sh LULUS

Empat keadaan, **nol** yang berbunyi. Yang paling berbahaya bukan yang
`nil`, melainkan yang **mengembalikan nilai lain yang sah**: `displayedObject
-> lastLockedObject` membuat jam, panel iPhone, layar redup, dan Diagnostics
serentak menyatakan objek yang terakhir terkunci sebagai jawaban **sekarang**
— persis pelanggaran PRD yang paling keras (objek lama tidak boleh tampil
seolah hasil pengukuran sekarang). Panel yang bergantung pada
`confirmsDisplayedIdentity` tetap tenang, karena ia membaca `snapshot`,
bukan `displayedObject`; hanya objek yang salah yang tampil, lengkap dengan
badge keyakinan yang benar.

Kenapa tidak ada gerbang yang menangkapnya: Aturan 34/35/36/38 mengawal
**argumen pemanggil** dan **badan Bool**. Keempatnya membaca nama
`engine.displayedObject` yang tidak berubah — yang berubah adalah apa yang
`engine.displayedObject` **kembalikan**, dan itu tidak dibaca siapa pun.

**Non-vakuositas diukur, bukan diklaim.** Setiap keadaan cacat dijalankan
sekali lagi dengan program Aturan 42 **dimatikan** (regex deklarasi diganti
pola yang tidak pernah cocok). Kalau keadaan-keadaan itu berbalik hijau di
sana, maka yang berbunyi memang aturan ini — bukan sebab lain.

Pakai: python3 Tools/bukti-mutasi-permukaan-nilai.py
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

#: Tiga permukaan bukan-Bool, dengan badan benar hari ini.
#:
#: Sengaja tiga, bukan satu: ketiganya permukaan penerusan yang sama bentuknya,
#: dan harness yang hanya menguji satu akan melaporkan "tertutup" untuk kelas
#: yang masih terbuka di dua tempat lain.
PERMUKAAN = {
    "displayedObject": (
        "CelestialObject?",
        "        snapshot.displayedObject(lastLocked: lastLockedObject)\n"),
    "pointing": (
        "HorizontalCoord?",
        "        snapshot.reportedPointing\n"),
    "answeredIntent": (
        "CelestialIntent?",
        "        controller.answeredIntent\n"),
}

#: Keadaan cacat: (nama, badan pengganti, harus_berbunyi). `None` = baseline.
#:
#: `%s` diisi deklarasi yang benar; kedua bentuk di bawah adalah bentuk
#: `nil` (permukaan mati) dan "nilai lain yang sah" (permukaan menyatakan
#: fakta yang salah, tanpa terlihat kosong).
KEADAAN = [
    ("baseline (kode apa adanya)", None, False),
    ("literal nil", "        nil\n", True),
    ("literal .none", "        .none\n", True),
    ("fakta lain: lastLockedObject", "        lastLockedObject\n", True),
    ("basil ulang (pulih)", None, False),
]

#: Substitusi per permukaan untuk keadaan "fakta lain" — dipilih supaya
#: **mengompilasi** dan tetap salah. `displayedObject -> lastLockedObject`
#: adalah mutasi yang diukur buta sebelum aturan ini ada.
FAKTA_LAIN = {
    "displayedObject": "        lastLockedObject\n",
    "pointing": "        snapshot.calibratedPointing\n",
    "answeredIntent": "        controller.snapshot.intent\n",
}

#: Keadaan **sah** yang harus tetap hijau. Kalau salah satu memerah,
#: aturannya menolak pekerjaan yang benar — dan itu cara paling cepat
#: membuatnya dilonggarkan sampai tidak menjaga apa pun.
SAH = [
    ("diteruskan apa adanya", None),
]


def require_clean() -> None:
    mutasi_sumber.require_clean_sources(WATCHED)


def extract_rule(number: str) -> str:
    """Ambil program Python Aturan `number` dari `swift-ui-lint.sh`."""
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
    # Aturan yang **mati** (traceback / NameError) menulis ke stderr, dan
    # keluaran itu tidak boleh dibaca sebagai "berbunyi": keadaan
    # non-vakuositas versi pertama dilaporkan gagal justru karena aturan
    # yang sudah dimatikan itu melempar `NameError`. Gerbang yang
    # mati-terbuka di dalam harness-nya sendiri.
    if "Traceback (most recent call last)" in (p.stdout + p.stderr):
        sys.exit("GERBANG: program aturan mati dengan traceback — harness ini "
                 "tidak bisa mengukur apa pun.\n" + p.stdout + p.stderr)
    return p.returncode, p.stdout + p.stderr


def copy_repo() -> str:
    """Salin **utuh**: `Apps/` untuk permukaan, `Packages/` untuk model.

    Aturan 42 belajar nama anggota model dari `Packages/PointingKit`; tanpa
    pohon itu himpunannya kosong dan aturannya berhenti mengukur.
    """
    workdir = tempfile.mkdtemp(prefix="permukaan-nilai-")
    shutil.copytree(os.path.join(ROOT, "Apps"), os.path.join(workdir, "Apps"))
    shutil.copytree(os.path.join(ROOT, "Packages"),
                    os.path.join(workdir, "Packages"),
                    ignore=shutil.ignore_patterns(".build", ".swiftpm"))
    return workdir


def inject_body(workdir: str, prop: str, new_body: str) -> None:
    """Ganti badan `var <prop>: T?` di salinan berkasnya.

    Dua bentuk deklarasi hidup di berkas itu — multi-baris (mayoritas) dan
    satu-baris (`answeredIntent`). Keduanya dicoba, dan harus **tepat satu**
    yang cocok: jangkar yang meleset membuat keadaan cacat dilaporkan hijau
    padahal berkasnya tidak pernah berubah.
    """
    tipe, badan = PERMUKAAN[prop]
    path = os.path.join(workdir, TARGET)
    text = open(path, encoding="utf-8").read()
    kandidat = [
        ("    public var %s: %s {\n%s    }" % (prop, tipe, badan),
         "    public var %s: %s {\n%s    }" % (prop, tipe, new_body)),
        # Satu baris: `<badan>` tanpa baris baru, dan badan baru dipipihkan.
        ("    public var %s: %s { %s }" % (prop, tipe, badan.strip()),
         "    public var %s: %s { %s }" % (prop, tipe, new_body.strip())),
    ]
    for old, new in kandidat:
        n = text.count(old)
        if n == 1:
            open(path, "w", encoding="utf-8").write(text.replace(old, new))
            return
    sys.exit(f"GERBANG: jangkar badan tidak unik (0 kali) di {TARGET}: "
             f"{prop!r} — harness ini tidak bisa mengukur.\n"
             f"Jangkarnya mungkin berubah di sumber; perbarui PERMUKAAN.")


def to_legacy(program: str) -> str:
    """Matikan regex deklarasinya — aturan berhenti mengukur permukaan.

    Itu keadaan pohon sebelum Aturan 42 ada. Kalau keadaan-keadaan cacat
    tetap berbunyi di sini, maka yang berbunyi bukan aturan ini.
    """
    marker = "DEKL = re.compile("
    if marker not in program:
        sys.exit("GERBANG: program Aturan 42 tidak memuat penanda `DEKL`; "
                 "harness non-vakuositas ini perlu disesuaikan sebelum ia "
                 "bisa mengukur apa pun.")
    head = program[:program.index(marker)]
    rest = program[program.index(marker):]
    _, newline, tail = rest.partition("\n")
    # `re.compile(r'(?!x)x')` tidak pernah cocok, tetapi **tetap** atribut
    # `DEKL` yang sah. Versi pertama menghapus penugasannya seluruhnya, dan
    # akibatnya programnya mati dengan `NameError: DEKL` — keluaran traceback,
    # yang oleh harness ini dibaca sebagai "aturan berbunyi". Itu gerbang
    # mati-terbuka di dalam harness-nya sendiri: keadaan non-vakuositas
    # dilaporkan gagal padahal aturannya memang sudah dimatikan.
    return head + "DEKL = re.compile(r'(?!x)x')\n" + tail


def main() -> int:
    require_clean()
    program = extract_rule("42")

    failures: list[str] = []
    ran = 0

    # ── a. Sasaran: setiap permukaan x setiap keadaan cacat berbunyi. ─────
    for prop in sorted(PERMUKAAN):
        for nama, body, must_fire in KEADAAN:
            if body == "        lastLockedObject\n":
                body = FAKTA_LAIN[prop]
            workdir = copy_repo()
            try:
                if body is not None:
                    inject_body(workdir, prop, body)
                _, out = run_rule(program, workdir)
                fired = bool(out.strip())
                ran += 1
                if fired != must_fire:
                    failures.append(
                        f"  {prop} / {nama}: "
                        f"{'hijau' if not fired else 'merah'} pada keadaan "
                        f"yang seharusnya "
                        f"{'berbunyi' if must_fire else 'diam'}")
                if fired and must_fire and TARGET not in out:
                    failures.append(
                        f"  {prop} / {nama}: berbunyi, tetapi temuannya "
                        f"tidak menyebut {TARGET} — yang merah bukan aturan ini")
            finally:
                shutil.rmtree(workdir, ignore_errors=True)

    # ── b. Ketepatan: bentuk sah harus tetap hijau. ───────────────────────
    for nama, _ in SAH:
        for prop in sorted(PERMUKAAN):
            workdir = copy_repo()
            try:
                _, out = run_rule(program, workdir)
                ran += 1
                if out.strip():
                    failures.append(
                        f"  bentuk sah `{nama}` / {prop}: MERAH padahal harus "
                        f"diam — {out.strip().splitlines()[0]}")
            finally:
                shutil.rmtree(workdir, ignore_errors=True)

    # ── c. Non-vakuositas: dengan aturan dimatikan, cacat berbalik hijau. ──
    legacy = to_legacy(program)
    for prop in sorted(PERMUKAAN):
        for nama, body, must_fire in KEADAAN:
            if not must_fire:
                continue
            if body == "        lastLockedObject\n":
                body = FAKTA_LAIN[prop]
            workdir = copy_repo()
            try:
                inject_body(workdir, prop, body)
                _, out = run_rule(legacy, workdir)
                ran += 1
                if out.strip():
                    failures.append(
                        f"  non-vakuositas / {prop} / {nama}: versi tanpa "
                        f"pembaca deklarasi juga berbunyi — keadaan ini tidak "
                        f"membuktikan Aturan 42 mengukur apa pun")
            finally:
                shutil.rmtree(workdir, ignore_errors=True)

    if ran < 3:
        sys.exit("GERBANG: kurang dari tiga keadaan benar-benar dijalankan; "
                 "'sesuai harapan' atas hampir nol pembuktian bukan bukti.")

    konteks = "Aturan 42: permukaan bukan-Bool di Apps/ meneruskan faktanya"
    if failures:
        print(f"{konteks} — {len(failures)} keadaan TIDAK sesuai harapan "
              f"(dari {ran}):")
        print("\n".join(failures))
        return 1
    print(f"{konteks} — {ran} keadaan, semuanya sesuai harapan "
          f"({len(PERMUKAAN)} permukaan x {len(KEADAAN)} keadaan, "
          f"{len(SAH) * len(PERMUKAAN)} bentuk sah, "
          f"{len(PERMUKAAN) * len([c for c in KEADAAN if c[2]])} "
          f"non-vakuositas).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
