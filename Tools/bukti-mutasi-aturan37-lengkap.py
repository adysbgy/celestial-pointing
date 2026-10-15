#!/usr/bin/env python3
"""Bukti bahwa Aturan 37 (`switch` di Apps/ wajib lengkap) benar-benar berbunyi.

Cacat yang gerbang ini tutup **sudah mendarat di `main`**: commit `27dd677`
menambahkan `.paleDisk` dan `.blueDisk` ke `enum DistinguishingFeature`
(PointingKit) dan memperbarui satu dari dua `switch` atas `palette.feature` di
`Apps/Shared/CelestialVisualView.swift`. Yang terlewat ada di jalur sabit
(`showsPhase`). Pada commit itu:

    CelestialEngine 216 uji   hijau
    PointingKit     799 uji   hijau
    ./swift-typecheck.sh      hijau
    ./swift-ui-lint.sh        hijau (seluruh aturan saat itu)

Yang merah hanya Apple Build (macos-15):

    Apps/Shared/CelestialVisualView.swift:269:29:
      error: switch must be exhaustive

Kenapa Linux memang tidak bisa melihatnya: runner Linux hanya membangun
`Packages/`, tidak pernah `Apps/`, dan kelengkapan `switch` adalah pemeriksaan
**semantik** yang butuh seluruh tipe diketahui. `swiftc -parse` (dipakai
`swift-typecheck.sh`) hanya membaca sintaks, jadi ia tidak pernah menolak
`switch` yang kurang satu `case`.

Harness ini **tidak** memutasi sumber produksi. Ia mengekstrak program Aturan
37 dari `swift-ui-lint.sh` — bukan menyalinnya, karena salinan akan tetap
hijau walau aturan aslinya dilonggarkan — lalu menjalankannya di dalam pohon
salinan sementara yang dimutasi. Pohon salinan itu wajib ada karena aturan ini
membaca **dua** tempat sekaligus (`Packages/PointingKit/Sources/` untuk
himpunan kasusnya, `Apps/` untuk `switch`-nya), jadi memutasi salah satunya
saja akan mengukur hal yang berbeda.

Keadaan yang diukur:

  1. satu `case` ciri dihapus dari `switch` jalur sabit — persis cacat yang
     mendarat di `main` pada `27dd677`. Harus MERAH.
  2. satu `case` ciri dihapus dari `switch` jalur gambar (`drawFeature`).
     Situs yang berbeda, kelas cacat yang sama. Harus MERAH.
  3. kasus baru ditambahkan ke `enum DistinguishingFeature` sementara kedua
     `switch` dibiarkan — bentuk cacat yang **berikutnya**, dan alasan
     aturannya membaca himpunan kasus dari model alih-alih mencocokkan nama
     `.paleDisk`/`.blueDisk`. Harus MERAH.
  4. `default:` ditambahkan ke `switch` jalur sabit tanpa mengubah `case`-nya.
     Di sana compiler memang tidak menuntut kelengkapan, jadi aturan **wajib
     tetap hijau** — kalau tidak, gerbang ini akan memerah pada kode yang
     benar dan orang akan melonggarkannya.
  5. pohon utuh tanpa mutasi. Kontrol negatif: gerbang yang merah pada kode
     benar tidak menjaga apa pun.

Yang TIDAK diklaim. Harness ini membuktikan aturannya **berbunyi** pada lima
keadaan itu; ia tidak membuktikan aturan itu lengkap, dan tidak membuktikan
`switch` yang lengkap menggambar hal yang benar. Ia juga tidak menyentuh
`Apps/` sungguhan — jadi ia tidak bisa membuktikan apa pun tentang berkas di
disk saat ini selain lewat keadaan 5.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

#: Judul yang dicetak Aturan 37. Dibaca dari keluaran lint, bukan ditulis
#: ulang di sini, supaya perubahan pesannya tidak membuat harness ini
#: berbohong tentang apa yang diukur.
RULE_HEADER = "== Aturan 37:"

#: Tanda "bersih" Aturan 37. Kalau gerbang berhenti mencetaknya, harness ini
#: harus berhenti — bukan menyimpulkan hijau dari keluaran yang tidak dibaca.
CLEAN_MARK = "Bersih: setiap switch di Apps/ memuat seluruh kasus enum model."

VIEW = os.path.join("Apps", "Shared", "CelestialVisualView.swift")
MODEL = os.path.join("Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")

#: Baris utuh, supaya mutasinya tidak bergantung pada spasi.
#:
#: Yang pertama ada di jalur **sabit** — situs yang terlewat di `27dd677`, dan
#: justru yang paling mudah terlewat karena Uranus/Neptunus `showsPhase ==
#: false`, jadi cabangnya tidak pernah dieksekusi dan cacatnya tidak terlihat
#: dari perilaku.
CRESCENT_CASE = "                            case .paleDisk, .blueDisk:"

#: Yang kedua ada di jalur **gambar**. Situs berbeda, kelas cacat sama: `switch`
#: di sana sudah lengkap di `27dd677`, jadi kalau aturannya hanya melihat satu
#: situs, keadaan ini akan hijau.
DRAW_CASE = ("        case .paleDisk: drawPaleDisk(context: context, "
             "center: center, radius: radius)")

#: Kasus baru untuk keadaan 3. Nama sengaja tidak ada di model mana pun.
NEW_CASE_ANCHOR = "        case blueDisk\n"


def extract_rule37():
    """Ambil program Aturan 37 dari `swift-ui-lint.sh`.

    Kenapa diekstrak, bukan disalin: harness yang menyalin aturannya akan tetap
    hijau walau aturan aslinya dilonggarkan — persis kelas cacat yang ditutup
    `check-harness-terdaftar.py` (gerbang yang tidak pernah dieksekusi selalu
    hijau).
    """
    with open(LINT, encoding="utf-8") as handle:
        text = handle.read()
    start = text.find("# ── Aturan 37")
    if start < 0:
        return None
    end = text.find('if [ "$status" -eq 0 ]; then', start)
    if end < 0:
        return None
    return text[start:end]


def build_tree(destination):
    """Salin hanya yang dibaca Aturan 37.

    Sengaja sempit: menyalin seluruh repo (termasuk `.build/`, ratusan MB)
    membuat harness ini lambat tanpa mengukur apa pun tambahan.
    """
    for relative in ("Apps", "Packages"):
        shutil.copytree(os.path.join(ROOT, relative),
                        os.path.join(destination, relative),
                        symlinks=True,
                        ignore=shutil.ignore_patterns(".build", "*.o", "index",
                                                      "ModuleCache", "*.swiftmodule"))
    shutil.copy2(LINT, os.path.join(destination, "swift-ui-lint.sh"))


def probe(program, tree):
    """Jalankan Aturan 37 sendiri di dalam `tree` → (merah?, detail)."""
    proc = subprocess.run(["bash", "-c", program], cwd=tree,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    return (CLEAN_MARK not in out), out.strip()


def apply_edits(tree, edits):
    """Terapkan mutasi; kembalikan False bila ada jangkar yang tidak ada."""
    for relative, old, new in edits:
        path = os.path.join(tree, relative)
        with open(path, encoding="utf-8") as handle:
            content = handle.read()
        if content.count(old) != 1:
            print(f"  JANGKAR TIDAK UNIK/TIDAK ADA di {relative}: {old!r} "
                  f"({content.count(old)}x)")
            return False
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(content.replace(old, new, 1))
    return True


#: (label, suntingan, harus_merah)
STATES = [
    ("[baseline] pohon utuh (kontrol negatif)", [], False),
    ("1. case ciri dihapus dari switch jalur sabit",
     [(VIEW, CRESCENT_CASE,
       "                            // MUTASI: case ciri dihapus")],
     True),
    ("2. case ciri dihapus dari switch jalur gambar",
     [(VIEW, DRAW_CASE, "        // MUTASI: gambar ciri dihapus")],
     True),
    ("3. kasus baru di enum model, kedua switch dibiarkan",
     [(MODEL, NEW_CASE_ANCHOR, "        case blueDisk\n        case newFeature\n")],
     True),
    ("4. `default:` ditambahkan ke switch jalur sabit",
     [(VIEW, "                            switch palette.feature {",
       "                            switch palette.feature {\n"
       "                            default: break")],
     False),
]


def main():
    program = extract_rule37()
    if program is None:
        print("GERBANG: program Aturan 37 tidak ditemukan di swift-ui-lint.sh "
              "— harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)
    if RULE_HEADER not in program:
        print("GERBANG: Aturan 37 tidak mencetak judulnya sendiri; harness "
              "tidak bisa membedakan aturan ini dari yang lain.",
              file=sys.stderr)
        sys.exit(2)

    with tempfile.TemporaryDirectory(prefix="aturan37-") as scratch:
        tree = os.path.join(scratch, "tree")
        os.makedirs(tree)
        build_tree(tree)

        # Jangkar diperiksa pada pohon salinan **sebelum** keadaan apa pun,
        # supaya kegagalan jangkar tidak menyamar sebagai keberhasilan.
        for relative, anchor in ((VIEW, CRESCENT_CASE), (VIEW, DRAW_CASE),
                                 (MODEL, NEW_CASE_ANCHOR)):
            with open(os.path.join(tree, relative), encoding="utf-8") as handle:
                count = handle.read().count(anchor)
            if count != 1:
                print(f"GERBANG: jangkar di {relative} muncul {count}x, harus "
                      "tepat 1x — harness tidak boleh jalan.", file=sys.stderr)
                sys.exit(2)

        baseline = None
        unexpected = 0
        for label, edits, must_fire in STATES:
            # Pohon segar untuk setiap keadaan: mutasi sebelumnya tidak boleh
            # menumpuk, karena keadaan 3 dan 4 berbicara tentang hal yang
            # berbeda dan tumpukan membuat hasilnya tidak bisa dibaca.
            fresh = os.path.join(scratch, "run")
            if os.path.exists(fresh):
                shutil.rmtree(fresh)
            shutil.copytree(tree, fresh, symlinks=True)

            if not apply_edits(fresh, edits):
                unexpected += 1
                continue

            fired, detail = probe(program, fresh)
            if fired is None:
                print(f"{label:56s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            if baseline is None:
                baseline = fired

            ok = (fired == must_fire)
            # Gerbang yang berbunyi tanpa menyebut apa pun tidak mengukur.
            if fired and not detail.strip():
                ok = False
            if not ok:
                unexpected += 1
            state = "MERAH" if fired else "hijau"
            print(f"{'OK  ' if ok else 'SALAH'} {label:56s} {state}")
            if fired:
                for line in detail.splitlines():
                    if line.strip() and RULE_HEADER not in line:
                        print(f"       {line.strip()[:140]}")

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
