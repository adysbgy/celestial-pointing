#!/usr/bin/env python3
"""Jangkar tiap harness mutasi harus masih ada di berkas sasarannya.

Gerbang ini menutup kelas cacat yang **sudah dua kali** menjatuhkan `main`, dan
yang paling sulit dilihat karena tidak ada galat kompilasi, tidak ada langkah
merah, tidak ada berkas yang hilang.

Bentuk cacatnya. Setiap harness di `Tools/bukti-mutasi-*.py` memutasi berkas
**produksi** dengan sepasang string: `find` (jangkar, harus ada di sumber) dan
`replace` (penggantinya). Harness memulihkan berkasnya di `finally` plus handler
`SIGINT`/`SIGTERM` — tetapi **`SIGKILL` dan timeout melewati keduanya**
(docstring `bukti-mutasi-inti-gugus.py` mencatatnya sendiri). Mutasi lalu
tertinggal hidup di berkas produksi.

Kenapa penjaga yang ada tidak cukup. `mutasi_sumber.require_clean_sources`
membandingkan berkas dengan `git HEAD` dan menolak jalan di atas pohon kotor.
Itu benar dan bekerja — tetapi **begitu mutasi yang bocor ikut ter-commit**,
berkas itu *menjadi* HEAD, dan penjaganya puas selamanya. Terukur, bukan
teoretis: `CLUSTER_CORE_HALO_SCALE = 40.0` adalah mutasi keadaan 2
`bukti-mutasi-inti-gugus.py` yang tertinggal, ikut ter-commit di `cf3c56b`
(commit yang pesannya tentang ciri planet), dan baru tertangkap berjam-jam
kemudian — lewat gerbang drift `port == view`, yang berhasil hanya karena view
kebetulan memegang angka yang benar.

**Yang diperiksa di sini, dan kenapa arahnya dua.**

  * jangkar `find` ada di berkas sasaran  -> kalau hilang, kemungkinan besar
    yang ada di sana adalah `replace`: mutasi yang bocor.
  * `replace` tidak ada ketika `find` hilang -> itu bukti bocornya, bukan
    sekadar "komentar dirapikan orang".

Arah pertama sendirian akan merah setiap kali seseorang memperbarui jangkar
sebuah harness dengan sengaja (dan itu terjadi di repo ini: harness dijaga
tetap cocok dengan sumbernya). Dua arah bersama-sama hanya merah pada keadaan
yang memang salah: **`find` sudah tidak ada, sementara penggantinya ada.**

Cakupan diambil dari **harness-nya sendiri** (parsing AST `STATES`), bukan dari
daftar tangan: konstanta string tingkat modul di-resolve, begitu juga konstanta
**path** (`VIEW = os.path.join(ROOT, ...)`, `_sources = (VIEW,)`), supaya
berkas sasaran tiap jangkar diketahui persis. Daftar tangan akan jadi salinan
kedua yang menyusut diam-diam saat harness bertambah — kelas yang sudah berulang
di repo ini.

Pakai:
    python3 Tools/check-jangkar-harness.py        # 0 = tak ada mutasi bocor
"""
from __future__ import annotations

import ast
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "Tools")
PATTERN = "bukti-mutasi-*.py"

#: Nama berkas yang **boleh** dibaca sebagai sasaran mutasi. Sengaja sempit:
#: hanya berkas produksi, bukan berkas `.pyc`, cache, atau berkas di `out/`.
#: Sebuah jangkar yang tidak ketemu di berkas mana pun di sini dilaporkan
#: sebagai "sasaran tak terbaca", bukan diabaikan — jangkar yang diabaikan
#: membuat gerbang ini hijau karena tidak memeriksa apa pun.
MAX_SOURCE_BYTES = 2_000_000


def _string(node, consts):
    """Nilai string sebuah simpul AST, atau None."""
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, ast.Name) and node.id in consts:
        return consts[node.id]
    return None


def _path_expr(node, consts, inside_join=False):
    """Nilai sebuah ekspresi **path** (`os.path.join(...)`, konstanta, literal).

    Dikembalikan sebagai string absolut, atau None bila tidak bisa diselesaikan.
    Dipakai supaya berkas sasaran tiap jangkar diketahui, bukan ditebak dari
    daftar tetap.

    `inside_join=True` berarti simpul ini adalah **komponen** dari
    `os.path.join(...)`; di sana string literal harus tetap relatif, karena
    `os.path.join(ROOT, "Tools", "render-visuals.py")` berarti tiga komponen —
    bukan "ganti ROOT dengan yang absolut". Tanpa pembedaan ini, komponen
    terakhir yang absolut akan menelan seluruh jalur di depannya, dan gerbang
    mencari berkas di tempat yang salah (lalu melaporkannya "tak terbaca").
    """
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        value = node.value
        if inside_join or os.path.isabs(value):
            return value
        return os.path.join(ROOT, value)
    if isinstance(node, ast.Name):
        if node.id == "ROOT":
            return ROOT
        if node.id == "TOOLS":
            return TOOLS
        if node.id in consts:
            inner = consts[node.id]
            if inside_join or os.path.isabs(inner):
                return inner
            return os.path.join(ROOT, inner)
        return None
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) \
            and node.func.attr == "join":
        parts = [_path_expr(arg, consts, inside_join=True) for arg in node.args]
        if any(part is None for part in parts):
            return None
        resolved_parts = [part for part in parts if part is not None]
        out = ""
        for part in resolved_parts:
            out = part if os.path.isabs(part) else os.path.join(out, part)
        return out
    return None


def _module_constants(tree):
    """Nama -> nilai untuk konstanta string DAN konstanta path tingkat modul."""
    consts = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name):
            continue
        if isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
            consts[target.id] = node.value.value
            continue
        resolved = _path_expr(node.value, consts)
        if resolved is not None and ("/" in resolved or "\\" in resolved):
            consts[target.id] = resolved
    return consts


def _collect_edits(tree, consts):
    """Seluruh `(anchor, replacement, target_path)` dari tiap bentuk `STATES`.

    Tiga bentuk yang dipakai repo ini:
      (anchor, replacement)                 -> berkas tunggal, dari `_sources`
      (path, anchor, replacement)           -> berkas eksplisit per keadaan
      (anchor_const, replace_const)         -> konstanta tingkat modul
    Bentuk yang tidak dikenali **dilewati dengan suara** (dilaporkan sebagai
    tak terbaca), bukan diam-diam tidak diperiksa.
    """
    edits = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.List):
            continue
        for item in node.elts:
            if not isinstance(item, ast.Tuple) or len(item.elts) < 2:
                continue
            state_edits = item.elts[1]
            if not isinstance(state_edits, ast.List) or not state_edits.elts:
                continue
            for edit in state_edits.elts:
                if not isinstance(edit, ast.Tuple):
                    continue
                parts = edit.elts
                if len(parts) == 2:
                    target, anchor, replacement = None, parts[0], parts[1]
                elif len(parts) == 3:
                    target, anchor, replacement = parts
                else:
                    continue
                a = _string(anchor, consts)
                r = _string(replacement, consts)
                if a is None or r is None:
                    continue
                path = _path_expr(target, consts) if target is not None else None
                edits.append((a, r, path))
    return edits


def _load_library(path):
    try:
        return ast.parse(open(path, encoding="utf-8").read()), None
    except (SyntaxError, UnicodeDecodeError) as error:
        return None, error


def collect_harness_edits():
    """(harness, anchor, replacement, target) untuk seluruh harness di disk."""
    out, unreadable = [], []
    for path in sorted(glob.glob(os.path.join(TOOLS, PATTERN))):
        tree, error = _load_library(path)
        name = os.path.basename(path)
        if tree is None:
            unreadable.append((name, str(error)))
            continue
        consts = _module_constants(tree)
        edits = _collect_edits(tree, consts)
        if not edits:
            unreadable.append((name, "tidak ada pasangan (jangkar, pengganti) terbaca"))
            continue
        for anchor, replacement, target in edits:
            out.append((name, anchor, replacement, target))
    return out, unreadable


def _read(path):
    try:
        if os.path.getsize(path) > MAX_SOURCE_BYTES:
            return None
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except (OSError, UnicodeDecodeError):
        return None


def main():
    edits, unreadable = collect_harness_edits()
    harness_count = len(glob.glob(os.path.join(TOOLS, PATTERN)))
    print(f"harness di disk        : {harness_count}")
    print(f"pasangan jangkar       : {len(edits)}")
    with_target = sum(1 for _, _, _, t in edits if t)
    print(f"  dengan berkas sasaran: {with_target}")

    # Cakupan nol adalah **kegagalan**, bukan keberhasilan.
    #
    # Tanpa pemeriksaan ini, gerbang yang pembacanya rusak (mis. `STATES` berubah
    # bentuk, atau berkas harness-nya tidak terbaca) akan mencetak
    # "OK: 0 jangkar; tidak ada mutasi tertinggal" dan keluar 0 — hijau dengan
    # alasan yang salah, tepat kelas cacat yang gerbang ini ada untuk menutup.
    # Terukur: melumpuhkan `_collect_edits` menghasilkan persis keluaran itu,
    # dan `bukti-mutasi-jangkar-harness.py` keadaan 3 menangkapnya.
    if not edits:
        print()
        print("GAGAL: tidak ada satu pun pasangan (jangkar, pengganti) yang "
              "terbaca dari harness mana pun.")
        print("       Gerbang ini mengukur nol hal; ia tidak bisa menyatakan "
              "apa pun tentang mutasi tertinggal.")
        print("       Periksa apakah bentuk `STATES` di Tools/bukti-mutasi-*.py "
              "berubah sehingga _collect_edits berhenti mengenalinya.")
        return 1

    leaks, missing, unreadable_target = [], [], []
    cache = {}
    for name, anchor, replacement, target in edits:
        candidates = []
        if target:
            text = cache.get(target)
            if text is None:
                text = cache[target] = _read(target)
            if text is None:
                unreadable_target.append((name, anchor, target))
                continue
            candidates = [text]
        else:
            # Tak ada berkas eksplisit: uji terhadap seluruh berkas produksi
            # yang dikenal repo ini. `find` hilang di **semua** yang diperiksa
            # baru berarti bocor.
            for rel in KNOWN_TARGETS:
                path = os.path.join(ROOT, rel)
                text = cache.get(path)
                if text is None:
                    text = cache[path] = _read(path)
                if text is not None:
                    candidates.append(text)
        if not candidates:
            unreadable_target.append((name, anchor, target or "(tanpa sasaran)"))
            continue

        anchor_present = any(anchor in text for text in candidates)
        replace_present = any(replacement in text for text in candidates)
        if not anchor_present and replace_present:
            leaks.append((name, anchor, replacement))
        elif not anchor_present:
            missing.append((name, anchor))

    for name, anchor, target in sorted(set(unreadable_target)):
        print(f"  TAK TERBACA  {name}: sasaran {target} tidak bisa dibaca")

    # Dedup: satu harness sering memakai jangkar yang sama di beberapa keadaan,
    # dan mencetaknya berkali-kali menyamarkan berapa banyak jangkar yang
    # sesungguhnya hilang.
    seen = set()
    for name, anchor in sorted(set(missing)):
        line = f"  jangkar hilang (pengganti tidak ada) : {name} -> {anchor[:60]!r}"
        if line not in seen:
            seen.add(line)
            print(line)
    for name, anchor, replacement in leaks:
        print(f"  MUTASI BOCOR : {name}")
        print(f"      jangkar hilang : {anchor[:70]!r}")
        print(f"      pengganti ada  : {replacement[:70]!r}")

    print()
    if leaks:
        print(f"GAGAL: {len(leaks)} mutasi harness tertinggal di sumber produksi.")
        print("       Pulihkan berkasnya (nilai yang benar = yang dipakai kode, "
              "bukan yang tertinggal):")
        print("           git log -p -- <berkas>   # lihat nilai sebelum mutasi")
        return 1
    print(f"OK: {len(edits)} jangkar; tidak ada mutasi tertinggal.")
    if missing:
        print(f"    ({len(missing)} jangkar tidak ditemukan tanpa penggantinya — "
              "bukan kebocoran, tapi harness itu mungkin perlu diperbarui.)")
    return 0


#: Berkas produksi yang boleh menjadi sasaran mutasi. Dipakai hanya untuk
#: jangkar yang harness-nya tidak menyebut berkas sasaran eksplisit.
KNOWN_TARGETS = (
    "Tools/render-visuals.py",
    "Tools/check-visuals.py",
    "Apps/Shared/CelestialVisualView.swift",
    "Apps/Shared/SlewVerdictBanner.swift",
    "Apps/Shared/OnboardingView.swift",
    "Apps/Shared/PointingEngine.swift",
    "Apps/Shared/MotionLogger.swift",
    "Apps/Shared/Resources/Localizable.xcstrings",
    "Apps/PointAndKnowWatch/Sources/PointingView.swift",
    "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift",
    "Packages/PointingKit/Sources/PointingKit/NightVisual.swift",
    "swift-ui-lint.sh",
)


if __name__ == "__main__":
    sys.exit(main())
