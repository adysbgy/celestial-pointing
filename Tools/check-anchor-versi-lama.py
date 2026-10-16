#!/usr/bin/env python3
"""Penambat "versi lama" harness harus eksplisit dan gagal-tertutup.

Kenapa gerbang ini ada.

Dua harness (`bukti-mutasi-label-bawaan.py`, `bukti-mutasi-anggota-bertahap.py`)
membuktikan **arah kedua**: cacat yang ditutup sebuah perbaikan dulu lolos.
Itu butuh `swift-ui-lint.sh` versi **sebelum** perbaikan. Membaca versi itu
punya dua cara yang tampak benar dan keduanya **berhenti mengukur tanpa suara**:

  1. `subprocess.run(["git", "show", ...])` langsung, tanpa
     `-c safe.directory=`. Di job CI berkas di-checkout sebagai uid lain
     sementara langkah berjalan sebagai **root**, jadi `git` menolak repo
     ("dubious ownership") dan `p.stdout` kosong. Skrip kosong yang dijalankan
     sebagai "versi lama" menemukan **nol** temuan — yaitu hijau. Terukur di
     kontainer: pembacaan tanpa `safe.directory` mengembalikan **0 karakter**
     dari 228.017.

  2. `git show origin/main:<berkas>` — penambat yang mengikuti cabang. Ia benar
     hanya selama perbaikannya belum ter-push; begitu sampai ke `main`,
     `origin/main` **memuat perbaikan itu sendiri**, dan arah kedua
     membandingkan perbaikan dengan dirinya sendiri. Terukur: `main` merah
     dengan "versi origin/main SUDAH merah" pada keadaan yang justru harus
     membuktikan cacatnya.

Keduanya menutupi satu sama lain — di mesin pengembang yang berbunyi gejala
(2), di CI gejala (1) — sehingga memperbaiki satu saja selalu menyisakan yang
lain. Karena itu yang dijaga di sini **bentuk pembacaannya**: versi lama wajib
lewat `mutasi_sumber.git_show`, satu-satunya jalur yang memakai
`safe.directory` **dan** berhenti keras pada isi kosong, dan ref yang
diberikan padanya wajib **commit SHA**, bukan nama cabang.

Cakupannya sengaja "ref yang **diberikan ke git**", bukan "string yang memuat
`origin/main`". Harness mutasi memang **menyimpan teks cacat sebagai data uji**
— `bukti-mutasi-anchor-versi-lama.py` memuat `["git", "show", "origin/main:x"]`
sebagai bahan yang ditanamkan ke salinan — dan menuduh fixture itu sebagai
cacat akan memerah pada berkas yang benar. Gerbang yang memerah pada kode
benar akan dimatikan orang, dan setelah dimatikan ia tidak menjaga apa pun.
Karena itu detektornya bekerja atas **pemanggilan** (AST `Call`), bukan atas
setiap konstanta string.

Non-vakuositas dibuktikan di dalam (`prove_itself`): detektornya dijalankan
atas sumber rekaan yang berisi tiap cacat, dan atas sumber bersih. Tanpa itu,
detektor yang rusak (mis. tidak mengenali bentuk apa pun) terlihat sama persis
dengan detektor yang benar: nol temuan.

Pakai:
    python3 Tools/check-anchor-versi-lama.py     # 0 = tak ada pembacaan mentah
"""
from __future__ import annotations

import ast
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "Tools")

#: Hanya harness mutasi. Alat lain di `Tools/` boleh membaca git sesukanya;
#: yang dijaga adalah harness yang **arah keduanya** bergantung pada bacaan itu.
PATTERN = "bukti-mutasi-*.py"

#: Ref yang mengikuti cabang — haram sebagai penambat "versi lama".
FORBIDDEN_REF = "origin/main"

#: Fungsi yang **menjalankan git**. Hanya argumen pemanggilan ini yang dinilai:
#: string cacat yang disimpan sebagai data uji bukan cacat.
GIT_CALLERS = frozenset({"run", "call", "check_output", "check_call", "Popen",
                         "_git", "git_show"})

#: SHA commit penuh — satu-satunya bentuk penambat yang tidak bisa bergerak.
SHA = re.compile(r"^[0-9a-f]{40}$")


def _called_name(node):
    """Nama fungsi yang dipanggil, tanpa kualifikasi (`m._git` -> `_git`)."""
    func = node.func
    if isinstance(func, ast.Attribute):
        return func.attr
    if isinstance(func, ast.Name):
        return func.id
    return None


def _string_args(node):
    """Seluruh konstanta string di dalam argumen sebuah pemanggilan."""
    out = []
    for sub in ast.walk(node):
        if isinstance(sub, ast.Constant) and isinstance(sub.value, str):
            out.append(sub.value)
    return out


def _resolve_refs(node, consts):
    """Nilai yang mungkin dari argumen **pertama** sebuah pemanggilan.

    Konstanta tingkat modul di-resolve (`OLD_REF = "..."` lalu
    `git_show(OLD_REF, ...)`), karena itulah bentuk yang dipakai kedua
    harness ini. Yang tidak bisa diselesaikan dikembalikan sebagai
    `None`-bertanda supaya pemanggil bisa membedakan "bukan SHA" dari
    "tidak tahu".
    """
    if not node.args:
        return []
    first = node.args[0]
    if isinstance(first, ast.Constant) and isinstance(first.value, str):
        return [first.value]
    if isinstance(first, ast.Name) and first.id in consts:
        return [consts[first.id]]
    return []


def audit_tree(tree):
    """`(baris, deskripsi)` untuk setiap pembacaan versi yang gagal-terbuka."""
    consts = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 \
                and isinstance(node.targets[0], ast.Name) \
                and isinstance(node.value, ast.Constant) \
                and isinstance(node.value.value, str):
            consts[node.targets[0].id] = node.value.value

    problems = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        name = _called_name(node)
        if name not in GIT_CALLERS:
            continue
        args = _string_args(node)
        line = getattr(node, "lineno", 0)

        # (1) `git show` lewat subprocess langsung: tanpa `safe.directory`
        #     hasilnya kosong di CI, dan kosong berarti hijau.
        if name in ("run", "call", "check_output", "check_call", "Popen") \
                and "git" in args and "show" in args:
            problems.append((
                line,
                "`subprocess` langsung untuk `git show` — tanpa "
                "`safe.directory` git menolak repo CI dan hasilnya kosong "
                "(hijau palsu). Pakai `mutasi_sumber.git_show(...)`."))
            continue

        # (2) Ref yang mengikuti cabang, diberikan ke pemanggil git mana pun.
        if any(FORBIDDEN_REF in a for a in args):
            problems.append((
                line,
                f"`{FORBIDDEN_REF}` diberikan ke `{name}` sebagai penambat "
                "versi lama — ia memuat perbaikan itu sendiri setelah "
                "ter-push. TAMBAT commit SHA yang eksplisit."))
            continue

        # (3) Ref yang bukan SHA: penambat apa pun selain commit penuh bisa
        #     bergerak, dan gerbang yang penambatnya bergerak berhenti
        #     mengukur tanpa suara.
        if name == "git_show":
            for ref in _resolve_refs(node, consts):
                if not SHA.match(ref):
                    problems.append((
                        line,
                        f"penambat `{ref!r}` bukan commit SHA penuh — hanya "
                        "SHA yang tidak bisa bergerak. Penambat yang "
                        "mengikuti cabang berhenti mengukur tepat pada commit "
                        "yang memperkenalkan perbaikan."))
    return problems


def audit_sources(pairs):
    """`pairs` = (nama, teks sumber). Kembalikan daftar masalah."""
    problems = []
    for name, text in pairs:
        try:
            tree = ast.parse(text)
        except SyntaxError as error:
            problems.append((name, 0, f"tidak bisa di-parse: {error}"))
            continue
        for line, why in audit_tree(tree):
            problems.append((name, line, why))
    return problems


#: SHA palsu untuk bukti-diri (bukan commit di repo ini).
FAKE_SHA = "a" * 40


def prove_itself():
    """Detektornya harus berbunyi pada tiap cacat, dan diam pada yang benar."""
    cases = [
        ("bentuk benar: git_show(SHA)",
         "def f():\n"
         f"    return mutasi_sumber.git_show('{FAKE_SHA}', 'x.sh')\n",
         0),
        ("bentuk benar: SHA lewat konstanta modul",
         f"OLD_REF = '{FAKE_SHA}'\n"
         "def f():\n"
         "    return mutasi_sumber.git_show(OLD_REF, 'x.sh')\n",
         0),
        ("subprocess langsung tanpa safe.directory",
         "def f():\n"
         "    p = subprocess.run(['git', 'show', 'HEAD:x'], "
         "capture_output=True)\n"
         "    return p.stdout\n",
         1),
        ("penambat origin/main lewat subprocess",
         "def f():\n"
         "    p = subprocess.run(['git', 'show', 'origin/main:x'])\n"
         "    return p.stdout\n",
         1),
        ("penambat origin/main lewat konstanta + git_show",
         f"OLD_REF = '{FORBIDDEN_REF}'\n"
         "def f():\n"
         "    return mutasi_sumber.git_show(OLD_REF, 'x.sh')\n",
         1),
        ("penambat bukan-SHA (nama cabang lokal)",
         "def f():\n"
         "    return mutasi_sumber.git_show('main', 'x.sh')\n",
         1),
        ("FIXTURE: teks cacat disimpan sebagai data uji, bukan dijalankan",
         "CACAT = ('    p = subprocess.run([\"git\", \"show\", "
         "\"origin/main:x\"])\\n')\n",
         0),
        ("prosa di docstring boleh menyebut origin/main",
         'def f():\n'
         '    """Kenapa `origin/main` tidak dipakai: ia mengikuti cabang."""\n'
         f"    return mutasi_sumber.git_show('{FAKE_SHA}', 'x.sh')\n",
         0),
    ]
    failures = []
    for label, text, want in cases:
        got = len(audit_sources([("uji.py", text)]))
        if got != want:
            failures.append(f"bukti-diri «{label}»: {got} temuan, harap {want}")
        print(f"{'OK  ' if got == want else 'SALAH'} bukti-diri: "
              f"{label:58s} {got} (harap {want})")
    return failures


def main():
    files = sorted(glob.glob(os.path.join(TOOLS, PATTERN)))
    pairs = []
    unreadable = []
    for path in files:
        try:
            pairs.append((os.path.basename(path),
                          open(path, encoding="utf-8").read()))
        except (OSError, UnicodeDecodeError) as error:
            unreadable.append((os.path.basename(path), str(error)))

    print(f"harness diperiksa : {len(pairs)}")
    failures = prove_itself()
    problems = audit_sources(pairs)

    for name, error in unreadable:
        print(f"  TAK TERBACA {name}: {error}")
    for name, line, why in problems:
        print(f"  {name}:{line}  {why}")

    print()
    if unreadable:
        print(f"GAGAL: {len(unreadable)} harness tidak bisa dibaca — gerbang "
              "ini tidak mengukur apa pun atas berkas itu.")
        return 1
    if not pairs:
        print("GAGAL: tidak ada harness ditemukan — pola globnya salah, jadi "
              "gerbang ini hijau karena tidak memeriksa apa pun.")
        return 1
    if problems or failures:
        for item in failures:
            print(f"  - {item}")
        print(f"GAGAL: {len(problems)} pembacaan versi-lama yang "
              "gagal-terbuka.")
        return 1
    print(f"OK: {len(pairs)} harness; penambat versi lama semuanya commit SHA "
          "lewat `mutasi_sumber.git_show`, tanpa pembacaan git mentah.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
