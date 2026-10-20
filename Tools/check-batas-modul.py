#!/usr/bin/env python3
"""Tipe yang dikembalikan fungsi publik wajib bisa dibaca pemakai modul.

Kenapa gerbang ini ada.

`a951cb9` membuat `jupiterBandEdges` publik supaya `Apps/Shared/CelestialVisualView.swift`
bisa memakainya, tetapi **tidak** membuat tipe kembaliannya publik:

    public static func jupiterBandEdges(...) -> [BandEdge] { ... }
    struct BandEdge { var height: Double; var halfWidth: Double }   <- internal

Hasilnya `Apple Build` merah (`39462501088`, macos-15) dengan empat galat
`'halfWidth' is inaccessible due to 'internal' protection level`, dan `main`
merah. Yang penting bukan galatnya, melainkan **kenapa tidak ada gerbang lokal
yang melihatnya**:

  * `swift build` pada paket itu **lulus** (terukur: `BUILD_EXIT=0` atas
    `git archive HEAD`). Diagnostik akses baru berbunyi di **titik pakai
    lintas modul**; paket yang membangun dirinya sendiri tidak punya titik itu.
  * `-enable-library-evolution` juga **tidak** membunyikannya (terukur: exit 0).
  * `swift-typecheck.sh` hanya `-parse` berkas SwiftUI — sintaks, bukan tipe.
  * Seluruh 77 berkas uji memakai `@testable import PointingKit`, jadi `internal`
    **terlihat** oleh uji. Uji yang membaca `edge.halfWidth` hijau walaupun app
    tidak bisa. Ini bukan kebetulan: `@testable` sengaja membuka `internal`, dan
    justru itulah yang membuat kelas cacat ini tak terlihat dari Linux.

Jadi cacatnya bukan "lupa menulis `public`". Cacatnya adalah **tidak ada yang
memeriksa batas modul dari sisi pemakai**, sementara satu-satunya pemeriksa
yang benar (compiler di titik pakai) hanya hidup di macOS.

Bentuk gerbangnya karena itu **bukan** sapu teks yang menebak akses. Menebak
salah dua arah: terlalu sempit (melewatkan bentuk deklarasi lain) atau terlalu
lebar (menuduh kode benar, lalu dimatikan orang). Yang dipakai adalah compiler
Swift yang sesungguhnya, di dalam Docker, atas modul yang sudah dibangun:

    impor modul sebagai pemakai luar (tanpa `@testable`)
    sentuh setiap anggota dari setiap tipe yang muncul di tanda-tangan publik
    compiler wajib diam

Kalau compiler tidak bisa dijalankan, gerbang **merah** — bukan hijau. Gerbang
yang berhenti mengukur terbaca sama persis dengan gerbang yang tidak menemukan
apa-apa.

Pakai:
    python3 Tools/check-batas-modul.py            # 0 = batas modul utuh
    python3 Tools/check-batas-modul.py --verbose  # cetak apa yang disentuh
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = "Packages/PointingKit"
MODULE = "PointingKit"
SOURCES = os.path.join(ROOT, PACKAGE, "Sources", MODULE)

# Tipe yang memang tidak boleh dipakai app: ia sengaja `internal` dan tidak
# pernah muncul di tanda-tangan publik. Daftar ini kosong secara bawaan, dan
# **diukur** oleh `self_check()` — kalau sebuah nama di sini ternyata muncul di
# tanda-tangan publik, gerbang merah. Daftar yang tumbuh tanpa ukuran adalah
# cara paling mudah mematikan gerbang tanpa ada yang sadar.
ALLOWED_INTERNAL: set[str] = set()

VERBOSE = "--verbose" in sys.argv


def read(path: str) -> str:
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def strip_comments(text: str) -> str:
    """Buang komentar supaya prosa docstring tidak dibaca sebagai kode.

    Prosa repo ini padat dan memuat contoh kode; tanpa ini, `public struct X`
    yang hanya **disebut** di dokumentasi ikut terhitung sebagai deklarasi.
    """
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def declared_types(text: str) -> dict[str, dict]:
    """Tipe yang dideklarasikan, dengan tingkat akses dan anggotanya.

    Akses sebuah tipe nested di dalam `public extension` **mewarisi** publik
    dari extension itu (Swift tidak menuntut kata `public` diulang). Karena itu
    `struct BandEdge` di dalam `public extension CelestialVisual` **adalah**
    tipe publik — persis kasus yang menjatuhkan `main`, dan persis yang akan
    dilewatkan pembaca yang hanya mencari kata `public` di depan `struct`.

    **Nama disimpan dengan jalur lengkap** (`CelestialVisual.CandidateMarker`),
    bukan nama pendek. Dua tipe berbeda di paket ini memakai nama pendek yang
    sama: ada `public enum CandidateMarker` di akar modul **dan**
    `CelestialVisual.CandidateMarker` yang berupa struct. Dengan nama pendek,
    yang satu menimpa yang lain dan probe menulis nama yang tidak ada — gerbang
    lalu menuduh kode benar, bentuk kegagalan yang sudah dua kali membuat aturan
    di repo ini dimatikan orang.
    """
    lines = strip_comments(text).splitlines()
    found: dict[str, dict] = {}
    depth = 0
    # Jalur tipe yang sedang dibuka, per kedalaman kurung kurawal.
    open_types: list[tuple[int, str]] = []
    extensions: list[tuple[int, bool, str]] = []
    for index, line in enumerate(lines):
        stripped = line.strip()
        extension = re.match(
            r"^(?:public\s+|internal\s+|private\s+|fileprivate\s+)?extension\s+([\w.]+)", stripped
        )
        if extension and "{" in stripped:
            extensions.append(
                (depth + 1, bool(re.match(r"^public\s+extension", stripped)), extension.group(1))
            )
        # Modifier boleh lebih dari satu dan boleh apa saja sebelum kata kunci
        # tipe: `public final class`, `public indirect enum`, `public actor`.
        # Bentuk `public final class ConfidenceTrace` itulah yang dulu membuat
        # `UncertainReason` (nested di dalamnya) terbaca sebagai tipe akar
        # modul — nama yang tidak ada di ruang lingkup itu — sehingga probe
        # gagal karena sebab yang salah.
        match = re.match(
            r"^(\s*)((?:\w+\s+)*?)(?:struct|enum|class|actor)\s+(\w+)", line
        )
        if match:
            modifiers = (match.group(2) or "").split()
            explicit = next(
                (m for m in modifiers if m in ("public", "internal", "private", "fileprivate")),
                "",
            )
            if explicit in ("internal", "private", "fileprivate"):
                depth += line.count("{") - line.count("}")
                continue
            inherited_public = any(body_depth == depth and public for body_depth, public, _ in extensions)
            if explicit == "public" or (not explicit and inherited_public):
                name = match.group(3)
                enclosing = [path for level, path in open_types if level <= depth]
                if not enclosing:
                    # Tipe di dalam `public extension X` mewarisi awalan `X`.
                    enclosing = [path for body_depth, _, path in extensions if body_depth == depth]
                qualified = ".".join(enclosing + [name])
                body_depth = depth + 1
                cursor = depth
                members: list[str] = []
                for offset in range(index, len(lines)):
                    row = lines[offset]
                    previous = cursor
                    cursor += row.count("{") - row.count("}")
                    if offset > index and previous == body_depth:
                        candidate = row.strip()
                        member = re.match(r"^(?:public\s+)?(?:var|let)\s+(\w+)\s*:", candidate)
                        if member and "{" not in candidate:
                            members.append(member.group(1))
                    if cursor < body_depth:
                        break
                found[qualified] = {
                    "line": index + 1,
                    "explicit": explicit or "(warisan extension)",
                    "members": members,
                }
                open_types.append((body_depth, qualified))
        depth += line.count("{") - line.count("}")
        open_types = [(level, path) for level, path in open_types if level <= depth]
        extensions = [(level, public, path) for level, public, path in extensions if level <= depth]
    return found


def public_return_types(text: str, known: set[str]) -> dict[str, list[str]]:
    """Fungsi publik yang tanda-tangannya menyebut tipe dari paket ini.

    Yang dicari hanya **nama tipe**, bukan akses anggotanya: pertanyaan gerbang
    ini adalah "tipe mana yang diserahkan ke pemakai luar", dan itu dibaca dari
    tanda-tangan. Akses anggotanya diputuskan compiler, bukan regex.

    Dua hal yang harus benar di sini, dan keduanya pernah salah:

      * **Tanda-tangan boleh membungkus baris.** `jupiterBandEdges` menulis
        parameter dan `-> [BandEdge]` di baris berikutnya. Pencocokan
        per-baris melewatkannya, dan justru fungsi itulah yang menjatuhkan
        `main`. Karena itu teksnya diratakan lebih dulu.
      * **Nama pendek harus dipetakan ke jalur yang benar.** Di dalam
        `CelestialVisual`, `-> CandidateMarker` berarti
        `CelestialVisual.CandidateMarker`, bukan `enum CandidateMarker` di akar
        modul. Resolusinya mengikuti ruang lingkup tempat fungsi itu ditulis:
        tipe yang membungkusnya lebih dulu, baru akar modul.
    """
    clean = strip_comments(text)
    flat = re.sub(r"\s+", " ", clean)
    short_names: dict[str, list[str]] = {}
    for qualified in known:
        short_names.setdefault(qualified.split(".")[-1], []).append(qualified)

    # Ruang lingkup tiap fungsi publik, dibaca dari teks aslinya. Sekaligus
    # menandai baris mana yang berada di dalam `public extension`, karena
    # anggota di sana **mewarisi** publik tanpa menulis kata `public`.
    scopes: list[str] = []
    public_scope: list[bool] = []
    depth = 0
    open_types: list[tuple[int, str]] = []
    extensions: list[tuple[int, str, bool]] = []
    for line in clean.splitlines():
        stripped = line.strip()
        extension = re.match(
            r"^(public\s+|internal\s+|private\s+|fileprivate\s+)?extension\s+([\w.]+)", stripped
        )
        if extension and "{" in stripped:
            extensions.append(
                (depth + 1, extension.group(2), (extension.group(1) or "").strip() == "public")
            )
        match = re.match(
            r"^(\s*)(?:public\s+)?(?:struct|enum|class|actor)\s+(\w+)", line
        )
        if match and "{" in line:
            enclosing = [path for level, path in open_types if level <= depth]
            if not enclosing:
                enclosing = [path for level, path, _ in extensions if level == depth + 1]
            open_types.append((depth + 1, ".".join(enclosing + [match.group(2)])))
        scopes.append(".".join([path for level, path in open_types if level <= depth]))
        public_scope.append(any(level == depth and public for level, _, public in extensions))
        depth += line.count("{") - line.count("}")
        open_types = [(level, path) for level, path in open_types if level <= depth]
        extensions = [(level, path, public) for level, path, public in extensions if level <= depth]

    # Tanda-tangan fungsi yang **efektif publik**: menulis `public`, atau
    # berada di dalam `public extension`. Bentuk kedua yang menjatuhkan `main`:
    # `jupiterBandEdges` di HEAD ditulis `static func` tanpa kata `public`,
    # lalu mewarisi publik dari extension-nya, sementara `BandEdge` di dalam
    # extension yang sama tetap punya anggota internal.
    signature_starts: list[tuple[int, str, str]] = []
    for line_index, line in enumerate(clean.splitlines()):
        found = re.match(
            r"^(\s*)(public\s+)?(?:static\s+)?func\s+(\w+)", line
        )
        if not found:
            continue
        explicit_public = bool(found.group(2))
        if not (explicit_public or public_scope[line_index]):
            continue
        tail = " ".join(row.strip() for row in clean.splitlines()[line_index : line_index + 4])
        signature_starts.append((line_index, found.group(3), tail))

    uses: dict[str, list[str]] = {}
    for line_index, name, tail in signature_starts:
        match = re.match(r"(?:public\s+)?(?:static\s+)?func\s+\w+\s*\((.*?)\)\s*(?:async\s*)?(?:throws\s*)?(?:->\s*([^{]+?))?\s*\{", tail)
        if not match:
            continue
        signature = (match.group(1) or "") + " " + (match.group(2) or "")
        for short, qualified_list in short_names.items():
            if not re.search(r"\b" + re.escape(short) + r"\b", signature):
                continue
            resolved = qualified_list[0]
            if len(qualified_list) > 1:
                resolved = _resolve(short, qualified_list, name, scopes, clean)
            uses.setdefault(resolved, []).append(name)
    return uses


def _resolve(short: str, candidates: list[str], func: str, scopes: list[str], text: str) -> str:
    """Pilih tipe yang dimaksud ketika nama pendeknya dipakai lebih dari sekali.

    Urutannya mengikuti aturan Swift: tipe yang membungkus lebih dulu, baru
    yang di akar modul. Kalau tetap tak bisa diputuskan, gerbang **tidak**
    menebak — ia memakai yang pertama dan membiarkan compiler memutuskan, karena
    salah tebak di sini hanya membuat probe gagal, bukan lolos.
    """
    for line_index, line in enumerate(text.splitlines()):
        if re.search(r"func " + re.escape(func) + r"\b", line):
            scope = scopes[line_index] if line_index < len(scopes) else ""
            for qualified in candidates:
                if qualified.startswith(scope + ".") and scope:
                    return qualified
            break
    nested = [name for name in candidates if "." in name]
    return nested[0] if nested else candidates[0]


def run_swift(shell_command: str, mount: str | None = None) -> tuple[bool, str]:
    """Jalankan perintah Swift, di dalam Docker bila perlu.

    Ada dua tempat gerbang ini hidup, dan keduanya harus mengukur hal yang
    sama:

      * **VPS Linux (di sini)** — Swift hanya ada di image `swift:6.0`, jadi
        perintahnya dibungkus `docker run`.
      * **CI `engine-tests.yml`** — langkahnya sudah berjalan *di dalam*
        `swift:6.0`. Docker tidak tersedia di sana, dan memanggilnya akan
        membuat langkah merah karena sebab yang salah (tipe `docker: not
        found`), bukan karena batas modulnya rusak.

    Karena itu keberadaan `swiftc` yang menentukan, bukan nama mesin.

    `mount` adalah direktori yang dipasang di `/src`. Harness mutasi
    menjalankan gerbang atas **salinan** pohon di luar repo, dan tanpa
    pemasangan eksplisit container tidak bisa melihatnya sama sekali — yang
    muncul sebagai "modul tidak terbangun", yaitu merah karena sebab yang salah
    dan karena itu tidak membuktikan apa pun.
    """
    if shutil.which("swiftc"):
        command = ["bash", "-lc", shell_command]
        wrapper = "swift lokal"
    else:
        source = mount or ROOT
        command = [
            "sudo", "-n", "docker", "run", "--rm",
            "-v", f"{source}:/src", "-w", "/src",
            "swift:6.0", "bash", "-lc", shell_command,
        ]
        wrapper = "docker swift:6.0"
    if VERBOSE:
        print(f"  (lewat {wrapper})")
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=1800)
    except (OSError, subprocess.SubprocessError) as error:
        return False, f"tidak bisa menjalankan swift ({wrapper}): {error}"
    output = (result.stdout or "") + (result.stderr or "")
    return result.returncode == 0, output


def build_module(sources_root: str | None = None) -> tuple[bool, str]:
    """Bangun modul. Gagal = gerbang merah, bukan hijau."""
    root = sources_root or ROOT
    return run_swift(f"cd /src/{PACKAGE} && swift build 2>&1 | tail -30", mount=root)


def compile_probe(source: str, path: str, sources_root: str | None = None) -> tuple[bool, str]:
    root = sources_root or ROOT
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(source)
    probe_in_root = os.path.relpath(path, root)
    return run_swift(
        f"cd /src/{PACKAGE} && "
        "ARCH=$(uname -m) && "
        "CA=.build/checkouts/AstronomyKit/Sources/CLibAstronomy && "
        "swiftc -typecheck -swift-version 5 "
        "-I .build/$ARCH-unknown-linux-gnu/debug/Modules "
        "-I $CA -Xcc -fmodule-map-file=$CA/module.modulemap "
        f"/src/{probe_in_root} 2>&1",
        mount=root,
    )


def probe_source(types: dict[str, dict], uses: dict[str, list[str]]) -> str:
    """Berkas pemakai luar: impor tanpa `@testable`, lalu sentuh anggotanya.

    Setiap anggota **dibaca**, bukan sekadar disebut namanya. Itu penting:
    galat yang menjatuhkan `main` adalah `'halfWidth' is inaccessible`, yaitu
    galat pada **akses anggota**, dan hanya akses yang memicunya.
    """
    lines = ["import " + MODULE, ""]
    for type_name, info in sorted(types.items()):
        if type_name in ALLOWED_INTERNAL:
            continue
        funcs = uses.get(type_name)
        if not funcs:
            continue
        # Nama fungsi tidak boleh mengandung titik; tipenya tetap jalur penuh.
        handle = "sentuh" + re.sub(r"\W", "_", type_name)
        lines.append(f"// {type_name}: diserahkan oleh {', '.join(sorted(set(funcs)))}")
        lines.append(f"func {handle}(_ nilai: {type_name}) {{")
        for member in info["members"]:
            lines.append(f"    _ = nilai.{member}")
        lines.append("}")
        lines.append("")
    return "\n".join(lines)


def self_check(types: dict[str, dict], uses: dict[str, list[str]]) -> list[str]:
    """Gerbang ini wajib bisa merah, dan wajib tidak menuduh kode benar.

    Tiga hal diukur di sini, semuanya tanpa menyentuh berkas produksi:

      1. pembaca **menemukan** tipe warisan-extension (kasus `BandEdge`) —
         kalau nol, pembacanya rusak dan hijau di bawah tidak berarti apa-apa;
      2. pembaca **tidak** menemukan tipe yang hanya disebut di komentar;
      3. `ALLOWED_INTERNAL` tidak memuat nama yang benar-benar dipakai publik.
    """
    problems: list[str] = []

    sample = """
public extension Contoh {
    struct Warisan { var a: Double }
}
public struct Tegas { public var b: Double }
internal struct Tersembunyi { var c: Double }
"""
    found = declared_types(sample)
    if not any(name.endswith(".Warisan") for name in found):
        problems.append(
            "pembaca tidak menemukan `struct` di dalam `public extension` — "
            "inilah bentuk yang menjatuhkan main, dan ia tak terbaca"
        )
    if "Tegas" not in found:
        problems.append("pembaca tidak menemukan `public struct` biasa")
    if any(name.endswith("Tersembunyi") for name in found):
        problems.append("pembaca menganggap `internal struct` sebagai publik")

    commented = """
/// public struct Hantu { var d: Double }
public struct Nyata { public var e: Double }
"""
    if any(name.endswith("Hantu") for name in declared_types(commented)):
        problems.append("pembaca membaca tipe yang hanya disebut di komentar")

    for name in sorted(ALLOWED_INTERNAL):
        if name in uses:
            problems.append(
                f"`{name}` ada di ALLOWED_INTERNAL padahal diserahkan tanda-tangan publik"
            )
    if problems and VERBOSE:
        for problem in problems:
            print("  self-check:", problem)
    return problems


def analyze() -> tuple[dict[str, dict], dict[str, list[str]], list[str]]:
    """Baca paket dan kembalikan (tipe, pemakaian, masalah pembaca)."""
    types: dict[str, dict] = {}
    uses: dict[str, list[str]] = {}
    if not os.path.isdir(SOURCES):
        return types, uses, [f"sumber {SOURCES} tidak ada"]
    for name in sorted(os.listdir(SOURCES)):
        if not name.endswith(".swift"):
            continue
        types.update(declared_types(read(os.path.join(SOURCES, name))))
    for name in sorted(os.listdir(SOURCES)):
        if not name.endswith(".swift"):
            continue
        text = read(os.path.join(SOURCES, name))
        for type_name, funcs in public_return_types(text, set(types)).items():
            uses.setdefault(type_name, []).extend(funcs)
    return types, uses, self_check(types, uses)


def fixture_mode() -> int:
    """Mode `--fixture`: ukur **pembacanya**, tanpa membangun modul.

    Dipakai harness mutasi. Membangun `PointingKit` butuh ~2 menit, dan
    harness yang butuh 2 menit per keadaan tidak akan dijalankan orang. Yang
    dibuktikan mode ini adalah bagian yang paling mudah salah dan paling mahal
    bila salah: apakah pembaca benar-benar **menemukan** `BandEdge` di dalam
    `public extension`, memetakan `CandidateMarker` ke jalur yang benar, dan
    mengaitkannya ke `jupiterBandEdges`. Compiler tetap diuji mode penuh.
    """
    types, uses, problems = analyze()
    print(f"tipe publik : {len(types)}")
    print(f"tipe diserahkan tanda-tangan: {len(uses)}")
    for name in sorted(uses):
        print(f"  {name} <- {', '.join(sorted(set(uses[name])))}")
    for name in sorted(types):
        if "BandEdge" in name or "CandidateMarker" in name:
            print(f"  anggota {name}: {types[name]['members']}")
    if problems:
        for problem in problems:
            print("  -", problem)
        return 1
    # Hijau di sini berarti kosong bila tidak ada yang terbaca.
    return 0 if uses else 1


def main() -> int:
    if "--fixture" in sys.argv:
        return fixture_mode()

    if not os.path.isdir(SOURCES):
        print(f"GAGAL: sumber {SOURCES} tidak ada — gerbang tidak bisa mengukur")
        return 1

    types, uses, problems = analyze()

    if problems:
        print("GAGAL: gerbang ini tidak bisa dipercaya atas dirinya sendiri")
        for problem in problems:
            print("  -", problem)
        return 1

    exposed = {name: info for name, info in types.items() if name in uses}
    if not exposed:
        print(
            "GAGAL: nol tipe publik terbaca di tanda-tangan — "
            "hijau di sini berarti kosong, bukan utuh"
        )
        return 1

    if VERBOSE:
        for name, info in sorted(exposed.items()):
            print(
                f"  {name} ({info['explicit']}, baris {info['line']}): "
                f"{len(info['members'])} anggota, diserahkan oleh "
                f"{', '.join(sorted(set(uses[name])))}"
            )

    print("== Build modul ==")
    built, build_output = build_module()
    if not built:
        print("GAGAL: modul tidak terbangun; batas modul tidak bisa diperiksa")
        print(build_output)
        return 1

    source = probe_source(exposed, uses)
    touched = sum(len(info["members"]) for name, info in exposed.items() if name not in ALLOWED_INTERNAL)
    if touched == 0:
        print("GAGAL: nol anggota disentuh — probe kosong tidak membuktikan batas modul")
        return 1

    print(f"== Typecheck pemakai luar: {len(exposed)} tipe, {touched} anggota ==")
    probe_path = os.path.join(ROOT, "Tools", ".probe-batas-modul.swift")
    try:
        ok, output = compile_probe(source, probe_path)
    finally:
        if os.path.exists(probe_path):
            os.remove(probe_path)

    if not ok:
        print("GAGAL: pemakai luar tidak bisa membaca tanda-tangan publik")
        for line in output.splitlines():
            if "error:" in line:
                print("   ", line)
        return 1

    print(f"OK: {len(exposed)} tipe publik terbaca dari luar modul, {touched} anggota")
    return 0


if __name__ == "__main__":
    sys.exit(main())
