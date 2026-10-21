#!/usr/bin/env python3
"""Aturan 85: permukaan **skalar** di `Apps/` juga meneruskan faktanya.

Kenapa aturan ini ada, dan kenapa ia bukan pengulangan Aturan 42.

Aturan 42 mengawal badan permukaan kejujuran di `Apps/`, tetapi **hanya yang
bertipe `T?`**:

    var displayedObject: CelestialObject? { ... }
    var pointing: HorizontalCoord? { ... }

Saudaranya yang bertipe skalar (`String`, `Int`, `Double`, …) tidak pernah
dibaca satu gerbang pun. Yang paling berharga di antaranya adalah kalimat
putusan Experiment 1 — satu-satunya tempat di app ini yang menyatakan apakah
alat bantu tunjuk ini **lulus syarat keselamatan**:

    Apps/PointAndKnowiOS/Sources/ExperimentRecorder.swift:181
        public var verdict: String { harness.verdict }

Terukur pada salinan utuh (proses baru), dengan mutasi yang **mengompilasi**
dan yang justru menghapus sumbernya:

    verdict -> ExperimentText.summaryPassed(trialCount: ..., accuracy: "100%", ...)
    swift-ui-lint.sh  ->  exit 0, "SEMUA GERBANG UI LULUS"

yaitu: layar Experiment 1 dapat mencetak "Lulus, akurasi 100%" tanpa pernah
membaca satu pun percobaan, dan seluruh 84 aturan tetap hijau. Seluruh mesin
kejujuran di bawahnya (`safetyVerdict`, ambang 20 percobaan, asimetri
gagal/lulus) tetap benar dan tetap teruji — yang hilang adalah **kaitannya ke
layar**. Ini kelas cacat yang berulang di repo ini: bagian yang memutuskan
benar, bagian yang menampilkan tidak, dan tidak ada gerbang yang
menghubungkan keduanya.

Kenapa `verdict` tidak tertangkap tes mana pun. `ExperimentSafetyVerdictTests`
menguji `ExperimentHarness.verdict` — milik paket, bukan milik app. Berkas
`Apps/` tidak pernah dibangun `swift-test.sh` di Linux, dan `swift-typecheck.sh`
hanya `-parse` berkas SwiftUI: tidak ada galat kompilasi, tidak ada tes.
Persis kelas yang tidak bisa dijangkau gate mana pun sebelum aturan ini.

**Kenapa menurunkan permukaannya, bukan mendaftar namanya.** Daftar nama tangan
akan basi diam-diam — itu sudah dua kali menjatuhkan `main` di repo ini (daftar
gerbang, daftar jangkar). Sumber kebenarannya sama dengan Aturan 42: setiap
`var <nama>: <Tipe> { ... }` di `Apps/` yang namanya **ada sebagai anggota
model** di `Packages/PointingKit`. Nama yang bukan anggota model (mis.
`let name: String?` milik view, `@AppStorage` sendiri) bukan keputusan engine
dan tidak diawasi — gerbang yang menuduh kode benar akan dilonggarkan orang.

**Kenapa hanya tipe skalar.** Untuk `T?` Aturan 42 sudah memeriksanya, dan
mengulanginya di sini berarti dua aturan yang bisa berbeda pendapat. Tipe
non-skalar non-opsional (mis. `some View`, `Color`, `SurfacePalette`) adalah
hiasan atau pembungkus tampilan, bukan fakta pengukuran; menuntutnya menyebut
namanya sendiri akan menuduh kode yang benar (`var color: Color { return
Color(...) }`). Batas ini **terukur**, bukan disangka: memperluas aturan ke
tipe non-skalar menghasilkan tepat dua temuan di pohon ini, dan keduanya kode
yang benar — `SurfaceTokens.color` (membungkus tuple RGB mentah) dan
`SurfaceTokens.active` (memilih palet lewat `NightPaletteSelector`, sumber
yang memang berbeda). Keduanya akan jadi positif palsu.

**Batas yang dinyatakan, bukan disangka tertutup.** Ini sapu teks, bukan
pemeriksa tipe: ia tahu **bentuk** badannya, tidak tahu nilai yang
dihasilkannya. `harness.verdict + " Lulus"` lolos, dan `?? "Lulus"` juga.
Yang ditutup adalah bentuk yang paling senyap dan yang terbukti lolos seluruh
gerbang: badan yang **sama sekali tidak** menyebut faktanya, termasuk literal
yang menggantikannya.
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PK = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit")
APPS = os.path.join(ROOT, "Apps")

#: Tipe yang nilainya adalah **satu fakta** yang bisa dicetak di layar.
#: `Bool` sengaja tidak di sini: ia milik Aturan 38.
SKALAR = {"String", "Int", "Double", "Float", "CGFloat", "UInt", "Int64"}


def kode_saja(teks: str) -> str:
    """Buang komentar `//` dan isi literal string.

    Keduanya tidak menjalankan apa pun. Berkas di `Apps/` mendokumentasikan
    bentuk yang salah panjang lebar; tanpa pembersihan ini, komentar penjelas
    akan memuaskan aturannya sendiri.
    """
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam_str, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam_str:
                if esc:
                    esc = False
                    buf.append(" ")
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam_str = False
                    buf.append('"')
                else:
                    buf.append(" ")
            else:
                if ch == '"':
                    dalam_str = True
                    buf.append('"')
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


def anggota_model() -> set:
    """Nama properti **dan** fungsi di paket — semua tipe, bukan hanya Bool."""
    if not os.path.isdir(PK):
        return set()
    anggota = set()
    for root, _, files in os.walk(PK):
        for name in sorted(files):
            if not name.endswith(".swift"):
                continue
            src = kode_saja(open(os.path.join(root, name), encoding="utf-8").read())
            anggota |= set(re.findall(r"\bvar\s+([A-Za-z_]\w*)\s*:", src))
            anggota |= set(re.findall(r"\bfunc\s+([A-Za-z_]\w*)\s*\(", src))
    return anggota


#: Nama sisi-UI untuk anggota model yang dinamai lain (sama dengan Aturan 42).
PASANGAN = {"pointing": "reportedPointing"}

DEKL = re.compile(r"\bvar\s+([A-Za-z_]\w*)\s*:\s*([A-Za-z_][\w.<>?, ]*?)\s*\{")


def main() -> int:
    if not os.path.isdir(APPS):
        print("FAIL Apps/ tidak ada: aturan ini tidak mengukur apa pun.")
        return 1
    anggota = anggota_model()
    if not anggota:
        print("FAIL tidak bisa membaca anggota model dari %s: aturan ini tidak "
              "bisa memutuskan." % os.path.relpath(PK, ROOT))
        return 1

    masalah = []
    diperiksa = 0
    for root, _, files in os.walk(APPS):
        for name in sorted(files):
            if not name.endswith(".swift"):
                continue
            path = os.path.join(root, name)
            rel = os.path.relpath(path, ROOT)
            kode = kode_saja(open(path, encoding="utf-8").read())
            for m in DEKL.finditer(kode):
                nama, tipe = m.group(1), m.group(2).strip()
                # `T?` milik Aturan 42; `Bool` milik Aturan 38.
                if tipe.endswith("?") or tipe.strip() == "Bool":
                    continue
                if tipe.strip() not in SKALAR:
                    continue
                if nama not in anggota and nama not in PASANGAN:
                    continue  # bukan keputusan engine
                i, d, j = m.end(), 1, m.end()
                while j < len(kode) and d:
                    if kode[j] == "{":
                        d += 1
                    elif kode[j] == "}":
                        d -= 1
                    j += 1
                badan = " ".join(kode[i:j - 1].split())
                if not badan:
                    continue  # `{ get }` / protokol: tidak punya badan di sini
                diperiksa += 1
                baris = kode[:m.start()].count("\n") + 1
                sumber = PASANGAN.get(nama, nama)
                if not re.search(r"\b" + re.escape(sumber) + r"\b", badan):
                    masalah.append(
                        "  %s:%d: `var %s: %s` berbadan `%s` -- tidak menyebut "
                        "`%s`, jadi nilainya bukan hasil pengukuran yang "
                        "berlaku sekarang" % (rel, baris, nama, tipe, badan[:90],
                                              sumber))

    if diperiksa == 0:
        print("FAIL tidak ada permukaan skalar di Apps/ yang diperiksa: aturan "
              "ini tidak mengukur apa pun. Kalau bentuk permukaannya memang "
              "berubah, perbarui aturannya -- jangan biarkan hijau.")
        return 1
    if masalah:
        print("\n".join(masalah))
        print("-> Teruskan faktanya apa adanya dari sumber yang sama "
              "(`harness.verdict`, `recordedTrials.recordedCount`, "
              "`motion.pulsePhase(...)`): permukaan inilah yang memberi tahu "
              "pengguna hasil pengukuran yang berlaku sekarang. Kalau sebuah "
              "permukaan memang tidak meneruskan fakta engine, ganti namanya "
              "supaya tidak menyamar sebagai anggota model.")
        return 1

    print("Bersih: %d permukaan skalar di Apps/ meneruskan anggota model yang "
          "namanya dipakainya." % diperiksa)
    return 0


if __name__ == "__main__":
    sys.exit(main())
