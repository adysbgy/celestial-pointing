#!/usr/bin/env python3
"""Hapus `public` yang berlebih pada anggota **langsung** `public extension`.

Aturan yang dipakai compiler Apple (dibuktikan lewat probe `swiftc`):

    'public' modifier is redundant for <kind> declared in a public extension

Hanya berlaku untuk **anggota langsung** badan `public extension`. Anggota dari
tipe bersarang di dalamnya (`struct X { public var y }`) **tidak** berlebih —
probe membuktikan keduanya tidak berbunyi, dan itu memang benar: `public` pada
`public extension` memberi `public` ke anggota langsungnya saja, bukan ke
anggota dari tipe yang dideklarasikan di dalamnya.

**Batas itu bukan detail.** `Apps/` memakai simbol-simbol ini dari modul lain
(`CelestialVisual.jupiterBands()`, `.Spot`, `.moonSphereDark`, …). Menghapus
`public` dari anggota **tipe bersarang** tidak memicu peringatan compiler, tapi
membuat `Apps/` gagal dikompilasi — peringatan yang "diperbaiki" berubah jadi
galat build. Karena itu `prove_itself()` di bawah menguji klaim itu secara
otomatis, bukan mengandalkannya pada ingatan.

Karena itu pengurai ini **bukan** pencocokan teks: ia menghitung kurung kurawal
sungguhan, dengan komentar `//` dan literal string dibuang lebih dulu. Versi
pertama saya menghitung kurung mentah dan meleset — `{` di dalam string
menggeser kedalamannya, dan seluruh berkas dilaporkan bersih padahal 120
peringatan masih ada. Persis kelas cacat yang repo ini sebut "gerbang hijau
karena alasan yang salah". Keadaan 3 di `prove_itself()` menahan regresi itu.

Pakai:
    python3 Tools/bersihkan-public-berlebih.py            # laporan; exit 1 bila ada
    python3 Tools/bersihkan-public-berlebih.py --tulis    # tulis perubahan
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Kind yang benar-benar diperingatkan compiler. Daftar ini **diukur**, bukan
# ditebak: probe `swiftc` atas satu `public extension` yang memuat semuanya
# mengeluarkan tepat enam peringatan —
#
#     instance method, static property, property, struct,
#     initializer, subscript
#
# Versi pertama gerbang ini mengecualikan `init`/`subscript` dengan alasan
# "probe menunjukkan keduanya tidak berbunyi". Itu **salah**, dan probe di atas
# membuktikannya: keduanya berbunyi (baris 15 dan 16). Kelalaian itu tidak
# berbunyi hari ini hanya karena kebetulan — nol `public init`/`subscript`
# berada langsung di badan `public extension` di paket ini. Kebetulan bukan
# gerbang, jadi keduanya masuk daftar, dan `SELF_PROOF` di bawah menguncinya.
#
# Keduanya **aman** dimasukkan karena pemeriksaannya dibatasi kedalaman 1:
# `public init` milik anggota tipe bersarang (kedalaman 2) tidak disentuh, dan
# justru itu `public` yang diperlukan.
KINDS = ("func", "let", "var", "struct", "enum", "class", "typealias",
         "init", "subscript")

#: Berkas yang boleh punya `public` berlebih tersisa tanpa menggagalkan laporan.
#: Kosong, dan itu disengaja: seluruh paket sudah bersih di siklus yang
#: menambahkan gerbang ini. Daftar pengecualian yang tidak kosong akan
#: memindahkan gerbangnya dari "menutup kelas cacat" ke "mendokumentasikan
#: utang", dan utang yang didokumentasikan adalah utang yang tidak dibayar.
ALLOWED: tuple[str, ...] = ()


def strip_code(line: str) -> str:
    """Buang komentar `//` dan isi literal string dari satu baris."""
    out = []
    i = 0
    in_string = False
    while i < len(line):
        c = line[i]
        if in_string:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
            continue
        if c == '"':
            in_string = True
            i += 1
            continue
        if c == "/" and i + 1 < len(line) and line[i + 1] == "/":
            break
        out.append(c)
        i += 1
    return "".join(out)


def redundant_publics_in(source: str) -> list[int]:
    """Nomor baris (1-based) `public` yang berlebih di sumber ini.

    Kedalaman dihitung **per baris utuh** (`{` dikurangi `}`), dan
    deklarasinya diperiksa pada kedalaman **awal** baris itu. Urutan itu yang
    benar, dan versi pertama salah di sini: ia menambahkan `{` baris ini dulu,
    baru memeriksa `depth == 1`, sehingga setiap anggota yang membuka kurung di
    barisnya sendiri (`public func bar() {}`, `public struct Band {`) terbaca
    di kedalaman 2 dan **tidak pernah dilaporkan**. Gejalanya persis "0
    peringatan" pada berkas yang penuh peringatan — hijau karena alasan yang
    salah. Ditangkap `prove_itself()`, bukan oleh pembacaan.
    """
    lines = source.split("\n")
    hits = []
    n = len(lines)
    i = 0
    while i < n:
        if not re.match(r"^public\s+extension\s+[A-Za-z_][\w.]*\s*\{",
                        strip_code(lines[i])):
            i += 1
            continue
        depth = 0
        j = i
        while j < n:
            code = strip_code(lines[j])
            # Kedalaman **awal** baris ini: 1 berarti anggota langsung badan
            # `public extension` (kedalaman 0 = baris `public extension` itu
            # sendiri, ≥ 2 = di dalam tipe bersarang).
            if j > i and depth == 1:
                if re.match(
                        r"^\s+public\s+(?:static\s+|final\s+|class\s+)*("
                        + "|".join(KINDS) + r")\b", code):
                    hits.append(j + 1)
            depth += code.count("{") - code.count("}")
            if j > i and depth <= 0:
                break
            j += 1
        i = j + 1
    return hits


def redundant_publics(path: str) -> list[int]:
    """Nomor baris `public` berlebih di berkas ini."""
    with open(path, encoding="utf-8") as handle:
        return redundant_publics_in(handle.read())


def rewrite_line(line: str) -> str:
    """Hapus `public ` pertama pada baris deklarasi anggota."""
    return re.sub(r"^(\s+)public\s+", r"\1", line, count=1)


#: Keadaan bukti-diri: (nama, sumber, jumlah yang harus ditemukan).
#:
#: Gerbang baru selalu hijau pada hari ia ditulis — itu bukan bukti apa pun.
#: Yang harus dibuktikan adalah bahwa ia **bisa** merah, dan bahwa ia **tidak**
#: merah pada hal yang salah. Keadaan 2 dan 3 yang paling penting di sini:
#: keduanya merah kalau pengurainya terlalu rajin, dan pengurai yang terlalu
#: rajin di berkas ini berarti `Apps/` tidak bisa dikompilasi.
SELF_PROOF = [
    ("anggota langsung public extension", """\
public extension Foo {
    public func bar() {}
    public static let baz: Double = 1.0
}
""", 2),
    # Klaim inti, dan yang paling mudah salah: `public` pada **deklarasi tipe
    # bersarang** (kedalaman 1) memang berlebih — compiler memperingatkannya,
    # dan itulah yang dihapus di `CelestialVisual.swift` (`public struct Band`
    # -> `struct Band`). Yang **tidak** berlebih adalah `public` pada anggota
    # dari tipe itu (kedalaman 2): `public extension` hanya memberi `public`
    # ke anggota langsungnya, jadi `public var field` di sana **diperlukan**.
    # Kalau pengurainya salah di sini, `Apps/` kehilangan
    # `CelestialVisual.Band.centerY` dan build-nya merah.
    ("deklarasi tipe bersarang (kedalaman 1) DItemukan", """\
public extension Foo {
    public struct Nested {
        public var field: Double
        public init(field: Double) { self.field = field }
    }
}
""", 1),
    # Sisi lain dari keadaan di atas, dan inilah yang mahal bila salah.
    ("anggota tipe bersarang (kedalaman 2) TIDAK ditemukan", """\
public extension Foo {
    struct Nested {
        public var field: Double
        public func method() {}
    }
}
""", 0),
    # Klaim pengurai: `{` di dalam literal string tidak boleh menggeser
    # kedalaman. Hitungan kurung mentah melewatkan `bar()` di sini, dan
    # seluruh berkas dilaporkan bersih.
    ("kurung di dalam string tidak menggeser kedalaman", """\
public extension Foo {
    static let template = "halo {dunia"
    public func bar() {}
}
""", 1),
    # `init`/`subscript` **juga** diperingatkan compiler — probe swiftc
    # membuktikannya (dua dari enam peringatan). Versi pertama gerbang ini
    # mengira keduanya tidak berbunyi; keadaan ini mengunci koreksinya.
    ("init/subscript LANGSUNG di public extension DItemukan", """\
public extension Foo {
    public init() {}
    public subscript(i: Int) -> Int { i }
}
""", 2),
    # …dan sisi mahalnya: `public init` milik tipe bersarang (kedalaman 2)
    # TIDAK boleh disentuh. Menghapusnya membuat `Apps/` gagal membangun
    # tipe itu dari modul lain.
    ("init milik tipe bersarang (kedalaman 2) TIDAK ditemukan", """\
public extension Foo {
    struct Nested {
        public init() {}
    }
}
""", 0),
    ("extension non-public tidak disentuh", """\
extension Foo {
    public func bar() {}
}
""", 0),
    ("berkas bersih", """\
public extension Foo {
    func bar() {}
}
""", 0),
]


def prove_itself() -> list[str]:
    """Buktikan `redundant_publics_in` benar pada **kedua** arah.

    Arah pertama: menemukan yang berlebih. Arah kedua — yang paling mudah
    terlupa, dan yang paling mahal bila salah — **tidak** menemukan yang
    diperlukan. Pengurai yang selalu mengembalikan daftar kosong akan terlihat
    persis sama dengan pengurai yang benar: nol masalah.
    """
    failures = []
    for label, source, want in SELF_PROOF:
        got = len(redundant_publics_in(source))
        mark = "OK  " if got == want else "SALAH"
        if got != want:
            failures.append(f"{label}: {got} ditemukan, seharusnya {want}")
        print(f"{mark} bukti-diri: {label:48s} {got} (harap {want})")
    return failures


def main() -> int:
    write = "--tulis" in sys.argv[1:]
    print("== Bukti-diri pengurai ==")
    failures = prove_itself()
    print()

    total = 0
    offenders = []
    for pkg in ("CelestialEngine", "PointingKit"):
        base = os.path.join(ROOT, "Packages", pkg, "Sources")
        for root, _, files in os.walk(base):
            for name in sorted(files):
                if not name.endswith(".swift"):
                    continue
                path = os.path.join(root, name)
                hits = redundant_publics(path)
                if not hits:
                    continue
                rel = os.path.relpath(path, ROOT)
                print(f"{rel}: {len(hits)} anggota langsung public extension")
                if write:
                    with open(path, encoding="utf-8") as handle:
                        lines = handle.read().split("\n")
                    for ln in hits:
                        before = lines[ln - 1]
                        lines[ln - 1] = rewrite_line(before)
                        assert lines[ln - 1] != before, (rel, ln, before)
                    with open(path, "w", encoding="utf-8") as fh:
                        fh.write("\n".join(lines))
                    left = redundant_publics(path)
                    print(f"    -> ditulis; sisa {len(left)}")
                    assert not left, f"masih ada {left} di {rel}"
                else:
                    offenders.append(rel)
                total += len(hits)

    print()
    if failures:
        for item in failures:
            print(f"  - {item}")
        return 1

    if write:
        print(f"{total} `public` berlebih dihapus")
        return 0

    # Penjaga terakhir: direktori yang kosong atau glob yang salah melaporkan
    # "0 peringatan" dan terlihat seperti kesuksesan. Kalau tidak satu pun
    # berkas sumber ditemukan, itu bukan hasil yang bersih.
    scanned = sum(1 for pkg in ("CelestialEngine", "PointingKit")
                  for root, _, files in os.walk(
                      os.path.join(ROOT, "Packages", pkg, "Sources"))
                  for name in files if name.endswith(".swift"))
    if scanned == 0:
        print("Tidak ada berkas .swift ditemukan — jalurnya salah, jadi "
              "gerbang ini tidak mengukur apa pun.")
        return 1

    if total:
        print(f"{total} `public` berlebih di {len(offenders)} berkas. Jalankan "
              "`--tulis` untuk menghapusnya; peringatan ini adalah kegagalan "
              "build di `ios-build.yml`.")
        return 1

    print(f"{total} `public` berlebih di {scanned} berkas — bersih")
    return 0


if __name__ == "__main__":
    sys.exit(main())
