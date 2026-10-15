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
  6. `case .altitudeAzimuth:` dihapus dari `switch capability.axes`
     (`TelescopeHandoffView.swift:81`). `MountAxis` hidup di
     **CelestialEngine**, bukan PointingKit, jadi sebelum cakupan diperluas
     `switch` ini tidak pernah diperiksa sama sekali. Harus MERAH — dan hijau
     pada versi aturan sebelumnya, yang diukur di sini juga.
  7. `case .derotator` ditambahkan ke `enum MountAxis` sementara `switch`-nya
     dibiarkan. Bentuk cacat yang **berikutnya** untuk enum itu, dan alasan
     cakupannya diperluas alih-alih daftar nama yang diperpanjang.
  8. `case .deepSky:` dihapus dari `switch visual.kind`
     (`CelestialVisualView.swift:73`). Situs ini punya **dua** kandidat enum
     dengan himpunan kasus identik — `CelestialVisual.Kind` (PointingKit) dan
     `ObjectKind` (CelestialEngine), keduanya
     `{moon, planet, star, sun, deepSky}`. Dengan syarat lama ("tepat satu
     kandidat") memperluas cakupan membuat situs ini **hilang** dari
     pemeriksaan; syarat baru ("semua kandidat punya kasus sama") justru
     menahannya. Harus MERAH, dan hijau pada versi aturan sebelumnya.
  9. `default:` ditambahkan ke `switch capability.axes`. Sama seperti keadaan
     4, tetapi di situs yang baru masuk cakupan: compiler memang tidak
     menuntut kelengkapan di sana. Harus hijau.

Dua keadaan terakhir dari keadaan-keadaan di atas (6 dan 8) diukur **dua
kali**: sekali dengan program Aturan 37 dari `swift-ui-lint.sh` hari ini, dan
sekali dengan versi aturan sebelumnya (`PACKAGE_SOURCES` tunggal, syarat
"tepat satu kandidat", pembaca per-baris). Harapan pada kedua jalannya
berbeda dan itu ditulis eksplisit di bawah — tanpa itu, harness ini hanya akan
membuktikan bahwa versi barunya sepakat dengan dirinya sendiri.

Yang TIDAK diklaim. Harness ini membuktikan aturannya **berbunyi** pada
keadaan-keadaan itu; ia tidak membuktikan aturan itu lengkap, dan tidak
membuktikan `switch` yang lengkap menggambar hal yang benar. Ia juga tidak
menyentuh `Apps/` sungguhan — jadi ia tidak bisa membuktikan apa pun tentang
berkas di disk saat ini selain lewat kontrol negatifnya.
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

#: `MountAxis` hidup di **CelestialEngine**, bukan PointingKit. `switch` ini
#: karena itu tidak pernah masuk cakupan aturan sampai `PACKAGE_SOURCES`
#: diperluas — dan itu bukan cacat hipotetis: menghapus `case
#: .altitudeAzimuth:` membiarkan seluruh aturan hijau sebelum perluasan.
AXES_VIEW = os.path.join("Apps", "PointAndKnowiOS", "Sources",
                         "TelescopeHandoffView.swift")
AXES_CASE = ("        case .altitudeAzimuth:\n"
             "            return TextLocalization.text(.telescopeAxisAltAz)\n")

#: Model `MountAxis`, untuk keadaan 7 (kasus baru di enum, `switch` dibiarkan).
AXES_MODEL = os.path.join("Packages", "CelestialEngine", "Sources",
                          "CelestialEngine", "TelescopeBridge.swift")
AXES_NEW_CASE_ANCHOR = "    case equatorial\n"

#: `switch visual.kind` — situs dengan **dua** kandidat enum yang himpunan
#: kasusnya identik (`CelestialVisual.Kind` dan `ObjectKind`).
KIND_CASE = "        case .deepSky:\n"

#: Model `Plan` — enum **bermuatan** (`case identifiable(CelestialVisual)`).
#: `switch` atasnya di `ReducedLuminanceView.swift:57` tidak pernah diperiksa
#: sampai pembacanya mengenali `case nama(muatan)`: versi lama membuang
#: seluruh enumnya, jadi keadaan 10 hijau di sana.
PLAN_MODEL = os.path.join("Packages", "PointingKit", "Sources", "PointingKit",
                          "ReducedLuminanceVisual.swift")
PLAN_NEW_CASE_ANCHOR = "        case identifiable(CelestialVisual)\n"

#: Aturan versi **sebelum** perluasan cakupan: `PACKAGE_SOURCES` tunggal
#: (PointingKit saja) dan syarat "tepat satu kandidat". Dipakai untuk
#: menuntut bahwa keadaan 6-7 hijau di sana — tanpa itu, harness ini hanya
#: membuktikan versi barunya sepakat dengan dirinya sendiri.
OLD_SCOPE_REPLACEMENTS = [
    (
        'PACKAGE_SOURCES = [os.path.join("Packages", "PointingKit", "Sources"),\n'
        '                   os.path.join("Packages", "CelestialEngine", "Sources")]',
        'PACKAGE_SOURCES = [os.path.join("Packages", "PointingKit", "Sources")]',
    ),
    (
        '            candidates = [name for name, values in cases.items()\n'
        '                          if labels <= values]\n'
        '            full = {frozenset(cases[name]) for name in candidates}\n'
        '            if len(full) != 1:\n'
        '                continue\n'
        '            examined += 1\n'
        '            complete = next(iter(full))\n'
        '            if labels >= complete:\n'
        '                continue\n'
        '            missing = sorted(complete - labels)\n'
        '            problems.append(\n'
        '                "  %s:%d: `switch %s` melewatkan %s dari `%s` -- compiler "\n'
        '                "menolaknya di macOS (`switch must be exhaustive`), tetapi "\n'
        '                "tidak ada gerbang Linux yang melihatnya"\n'
        '                % (path, line, expr.replace("\\n", " ").strip(),\n'
        '                   missing, sorted(set(candidates))))',
        '            candidates = [name for name, values in cases.items()\n'
        '                          if labels <= values]\n'
        '            if len(candidates) != 1:\n'
        '                continue\n'
        '            examined += 1\n'
        '            name = candidates[0]\n'
        '            if labels >= cases[name]:\n'
        '                continue\n'
        '            missing = sorted(cases[name] - labels)\n'
        '            problems.append(\n'
        '                "  %s:%d: `switch %s` melewatkan %s dari `%s` -- compiler "\n'
        '                "menolaknya di macOS (`switch must be exhaustive`), tetapi "\n'
        '                "tidak ada gerbang Linux yang melihatnya"\n'
        '                % (path, line, expr.replace("\\n", " ").strip(),\n'
        '                   missing, name))',
    ),
]

#: Perluasan cakupan **tanpa** melonggarkan syarat kandidat. Ini bukan versi
#: yang pernah ada di `main`; ia dibentuk di sini untuk mengukur satu hal:
#: apakah syarat kandidat memang yang menahan situs 73 (`switch visual.kind`,
#: dua kandidat enum berhimpunan kasus identik). Kalau perluasan cakupan saja
#: sudah cukup, fungsi ini akan berperilaku sama dengan aturan sekarang — dan
#: keadaan 8 akan hijau, yang berarti syaratnya tidak perlu diubah.
NAIVE_WIDENING_REPLACEMENTS = [
    (
        '            full = {frozenset(cases[name]) for name in candidates}\n'
        '            if len(full) != 1:\n'
        '                continue\n'
        '            examined += 1\n'
        '            complete = next(iter(full))\n'
        '            if labels >= complete:\n'
        '                continue\n'
        '            missing = sorted(complete - labels)\n'
        '            problems.append(\n'
        '                "  %s:%d: `switch %s` melewatkan %s dari `%s` -- compiler "\n'
        '                "menolaknya di macOS (`switch must be exhaustive`), tetapi "\n'
        '                "tidak ada gerbang Linux yang melihatnya"\n'
        '                % (path, line, expr.replace("\\n", " ").strip(),\n'
        '                   missing, sorted(set(candidates))))',
        '            if len(candidates) != 1:\n'
        '                continue\n'
        '            examined += 1\n'
        '            complete = frozenset(cases[candidates[0]])\n'
        '            if labels >= complete:\n'
        '                continue\n'
        '            missing = sorted(complete - labels)\n'
        '            problems.append(\n'
        '                "  %s:%d: `switch %s` melewatkan %s dari `%s` -- compiler "\n'
        '                "menolaknya di macOS (`switch must be exhaustive`), tetapi "\n'
        '                "tidak ada gerbang Linux yang melihatnya"\n'
        '                % (path, line, expr.replace("\\n", " ").strip(),\n'
        '                   missing, candidates))',
    ),
]


#: Aturan versi **sebelum** kasus bermuatan dibaca. Dipakai untuk menuntut
#: bahwa keadaan 10 hijau di sana — tanpa itu, keadaan itu hanya sepakat
#: dengan dirinya sendiri.
ASSOC_REPLACEMENTS = [
    (
        '                match = re.fullmatch(\n'
        '                    r"([A-Za-z_][A-Za-z0-9_]*)\\s*(?:\\((?:[^()]|\\([^()]*\\))*\\))?",\n'
        '                    part, re.S)\n'
        '                if match:\n'
        '                    cases.add(match.group(1))\n'
        '                else:\n'
        '                    readable = False\n',
        '                if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", part):\n'
        '                    cases.add(part)\n'
        '                else:\n'
        '                    readable = False\n',
    ),
]


def demote_to_old_rule(program):
    """Cakupan **sebelum** perluasan: PointingKit saja, syarat tepat-satu.

    Kalau potongannya tidak lagi ada, kembalikan None: harness ini harus
    berhenti alih-alih mengukur program yang berbeda dari yang diklaimnya.
    """
    out = program
    for old, new in OLD_SCOPE_REPLACEMENTS:
        if out.count(old) != 1:
            return None
        out = out.replace(old, new, 1)
    return out


def demote_to_no_assoc(program):
    """Aturan versi **sebelum** kasus bermuatan dibaca.

    Kalau potongannya tidak lagi ada, kembalikan None — harness berhenti
    alih-alih mengukur program yang berbeda dari yang diklaimnya.
    """
    out = program
    for old, new in ASSOC_REPLACEMENTS:
        if out.count(old) != 1:
            return None
        out = out.replace(old, new, 1)
    return out


def naive_widening(program):
    """Cakupan diperluas **tanpa** melonggarkan syarat kandidat.

    Ini bukan versi yang pernah ada di `main`; ia dibentuk di sini untuk
    mengukur satu hal: apakah syarat kandidat itu memang menahan situs 73
    (`switch visual.kind`, dua kandidat enum berhimpunan kasus identik).
    Kalau perluasan cakupan saja sudah cukup, fungsi ini akan menghasilkan
    perilaku yang sama dengan aturan sekarang — dan keadaan 8 akan hijau,
    yang berarti syaratnya tidak perlu diubah.
    """
    out = program
    for old, new in NAIVE_WIDENING_REPLACEMENTS:
        if out.count(old) != 1:
            return None
        out = out.replace(old, new, 1)
    return out


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


#: (label, suntingan, harus_merah, harapan_pada_versi_lain)
#:
#: `harapan_pada_versi_lain` adalah dict {nama program: harus_merah}. Dua
#: program lain diukur supaya keadaan di sini tidak hanya sepakat dengan
#: dirinya sendiri:
#:
#:   "aturan lama"     — `PACKAGE_SOURCES` tunggal (PointingKit saja) +
#:                       syarat "tepat satu kandidat". Ini yang menjaga
#:                       keadaan 6-7: di sana ia **hijau**, jadi keduanya
#:                       memang menambah cakupan.
#:   "perluasan naif"  — cakupan diperluas **tanpa** melonggarkan syarat
#:                       kandidat. Ini yang menjaga keadaan 8: situs 73 punya
#:                       dua kandidat enum berhimpunan kasus identik, jadi
#:                       perluasan naif **membuangnya** dari pemeriksaan.
#:                       Keadaan 8 hijau di sana — dan itu alasan syaratnya
#:                       harus berubah, bukan sekadar cakupannya.
STATES = [
    ("[baseline] pohon utuh (kontrol negatif)", [], False, {}),
    ("1. case ciri dihapus dari switch jalur sabit",
     [(VIEW, CRESCENT_CASE,
       "                            // MUTASI: case ciri dihapus")],
     True, {"aturan lama": True}),
    ("2. case ciri dihapus dari switch jalur gambar",
     [(VIEW, DRAW_CASE, "        // MUTASI: gambar ciri dihapus")],
     True, {"aturan lama": True}),
    ("3. kasus baru di enum model, kedua switch dibiarkan",
     [(MODEL, NEW_CASE_ANCHOR, "        case blueDisk\n        case newFeature\n")],
     True, {"aturan lama": True}),
    ("4. `default:` ditambahkan ke switch jalur sabit",
     [(VIEW, "                            switch palette.feature {",
       "                            switch palette.feature {\n"
       "                            default: break")],
     False, {}),
    # Keadaan 6-9: kelas cacat yang cakupan lama tidak bisa lihat sama sekali.
    ("6. `case .altitudeAzimuth` dihapus (enum di paket lain)",
     [(AXES_VIEW, AXES_CASE, "")],
     True, {"aturan lama": False}),
    ("7. kasus baru di `MountAxis`, switch dibiarkan",
     [(AXES_MODEL, AXES_NEW_CASE_ANCHOR,
       "    case equatorial\n    case derotator\n")],
     True, {"aturan lama": False}),
    ("8. `case .deepSky` dihapus (dua kandidat enum identik)",
     [(VIEW, KIND_CASE, "        // MUTASI: deepSky dihapus")],
     True, {"perluasan naif": False}),
    ("9. `default:` ditambahkan ke switch capability.axes",
     [(AXES_VIEW, "        switch capability.axes {",
       "        switch capability.axes {\n        default: break")],
     False, {"aturan lama": False}),
    # Keadaan 10: kelas cacat pada enum **bermuatan**. Versi yang tidak
    # membaca `case nama(muatan)` membuang seluruh enumnya, jadi `switch`
    # atasnya tidak pernah diperiksa — kelas yang sama dengan `27dd677`,
    # pada enum yang kebetulan punya muatan.
    ("10. kasus baru di `Plan` (enum bermuatan), switch dibiarkan",
     [(PLAN_MODEL, PLAN_NEW_CASE_ANCHOR,
       "        case identifiable(CelestialVisual)\n"
       "        case candidate(CelestialVisual)\n")],
     True, {"tanpa kasus bermuatan": False}),
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

    # Dua program pembanding. Keduanya wajib bisa dibentuk; kalau potongan
    # aturannya berubah sehingga tidak lagi cocok, harness ini berhenti
    # alih-alih diam-diam melewatkan pengukuran yang diklaimnya.
    old_program = demote_to_old_rule(program)
    if old_program is None:
        print("GERBANG: potongan aturan versi lama tidak ditemukan di "
              "swift-ui-lint.sh — harness tidak bisa membuktikan bahwa "
              "keadaan 6-7 memang menambah cakupan.", file=sys.stderr)
        sys.exit(2)
    naive_program = naive_widening(program)
    if naive_program is None:
        print("GERBANG: potongan perluasan-naif tidak ditemukan di "
              "swift-ui-lint.sh — harness tidak bisa membuktikan bahwa "
              "syarat kandidat memang menahan keadaan 8.", file=sys.stderr)
        sys.exit(2)
    no_assoc_program = demote_to_no_assoc(program)
    if no_assoc_program is None:
        print("GERBANG: potongan pembaca-tanpa-kasus-bermuatan tidak "
              "ditemukan di swift-ui-lint.sh — harness tidak bisa "
              "membuktikan bahwa keadaan 10 memang menambah cakupan.",
              file=sys.stderr)
        sys.exit(2)
    comparisons = {"aturan lama": old_program,
                   "perluasan naif": naive_program,
                   "tanpa kasus bermuatan": no_assoc_program}

    with tempfile.TemporaryDirectory(prefix="aturan37-") as scratch:
        tree = os.path.join(scratch, "tree")
        os.makedirs(tree)
        build_tree(tree)

        # Jangkar diperiksa pada pohon salinan **sebelum** keadaan apa pun,
        # supaya kegagalan jangkar tidak menyamar sebagai keberhasilan.
        anchors = [(VIEW, CRESCENT_CASE), (VIEW, DRAW_CASE),
                   (MODEL, NEW_CASE_ANCHOR), (AXES_VIEW, AXES_CASE),
                   (AXES_MODEL, AXES_NEW_CASE_ANCHOR), (VIEW, KIND_CASE),
                   (PLAN_MODEL, PLAN_NEW_CASE_ANCHOR)]
        for relative, anchor in anchors:
            with open(os.path.join(tree, relative), encoding="utf-8") as handle:
                count = handle.read().count(anchor)
            if count != 1:
                print(f"GERBANG: jangkar di {relative} muncul {count}x, harus "
                      "tepat 1x — harness tidak boleh jalan.", file=sys.stderr)
                sys.exit(2)

        baseline = None
        unexpected = 0
        for index, (label, edits, must_fire, other_expectations) in enumerate(STATES):
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

            # Arah kedua: setiap keadaan boleh menuntut hasil tertentu pada
            # program pembandingnya. Tanpa pengukuran ini, keadaan 6-8 hanya
            # sepakat dengan dirinya sendiri.
            other_state = ""
            for name, expected_fired in other_expectations.items():
                other_fired, _ = probe(comparisons[name], fresh)
                if other_fired is None:
                    print(f"{label:56s} PROBE {name.upper()} GAGAL JALAN")
                    unexpected += 1
                    continue
                other_state += f" | {name}: {'MERAH' if other_fired else 'hijau'}"
                if other_fired != expected_fired:
                    ok = False
                    other_state += (f" (HARUS {'MERAH' if expected_fired else 'hijau'}"
                                    " di sana)")

            if not ok:
                unexpected += 1
            state = "MERAH" if fired else "hijau"
            print(f"{'OK  ' if ok else 'SALAH'} {label:56s} {state}{other_state}")
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
