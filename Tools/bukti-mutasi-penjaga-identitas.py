#!/usr/bin/env python3
"""Buktikan Aturan 34 (penjaga identitas) **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
karena **menyebut pemanggilan yang dilanggar** -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya.

Model `PointingKit` punya enam aksesor yang sengaja menerima `isConfirmed:`
supaya bisa menolak mengklaim identitas saat engine ragu:

    CelestialVisual.drawableStarColorIndex(_:isConfirmed:)      warna bintang
    DeepSkyCatalogue.drawableMorphology(forObjectID:isConfirmed:) bentuk kabut
    Palette.drawable(isConfirmed:)                              palet planet
    spokenStarColor(isConfirmed:)                               suara warna
    spokenPhase(isConfirmed:)                                   suara fase
    spokenDeepSkyMorphology(isConfirmed:)                       suara morfologi

Rumusnya benar dan masing-masing punya uji Swift. Yang tidak diperiksa siapa
pun adalah **nilai yang dikirim dari `Apps/`**: `swift-test.sh` hanya membangun
`Packages/`, dan `Tools/check-visuals.py` merender **port Python**-nya, bukan
view Swift-nya. Jadi berkas yang bisa salah justru berkas yang tidak dilihat
kedua gerbang itu.

Diukur sebelum Aturan 34 ada, pada kawat yang memutuskan apakah bentuk objek
langit dalam boleh diklaim:

    `isConfirmed: isConfirmed` -> `isConfirmed: true`
        swift-ui-lint.sh    LULUS (exit 0)
        swift-typecheck.sh  LULUS (exit 0)
        swift-test.sh       755 uji, 0 gagal

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                       gerbang hijau (kalau tidak, harness salah)

  1. jalur gambar: morfologi       Cacat aslinya. Bentuk adalah ciri pengenal
                                   objek langit dalam -- galaksi berpalung di
                                   sebelah badge "Ragu" menyatakan "ini
                                   galaksi" sama kerasnya dengan menulisnya.

  2. jalur gambar: warna bintang   Aksesor kedua, berkas yang sama. Warna
                                   spektral adalah ciri pengenal (biru Rigel
                                   vs merah Betelgeuse).

  3. jalur gambar: palet planet    Aksesor ketiga -- pita Jupiter, cincin
                                   Saturnus, kutub Mars.

  4. jalur suara: fase Bulan       **Berkas yang berbeda**, dan itu disengaja:
                                   VoiceOver adalah jalur yang paling mudah
                                   terlupakan, karena satu-satunya penjaganya
                                   adalah kode yang tidak terlihat di layar.
                                   Kalau harness ini hanya memutasi satu
                                   berkas, gerbang yang hanya membaca berkas
                                   itu akan tetap lolos.

  5. jalur suara: morfologi        Aksesor kelima, berkas ketiga.

  6. jalur suara: warna bintang    Aksesor keenam.

  7. arah fase (dua situs)         **Argumen yang berbeda, kelas cacat yang
                                   sama.** `phaseGeometry(waxing:)` tidak
                                   punya parameter `isConfirmed:` -- ia
                                   menerima `Bool?`, dan `nil` berarti "jangan
                                   pilih sisi". Mengirim `true` berarti
                                   memilih sisi terang untuk benda yang
                                   arahnya tidak diketahui engine, dan sisi
                                   terang adalah ciri pengenal: sabit yang
                                   menghadap ke arah salah menyatakan "ini
                                   bulan sabit awal" saat engine hanya tahu
                                   "ada sabit". Keadaan ini ada di sini justru
                                   karena gerbang yang mencari `isConfirmed:`
                                   akan melewatkannya sepenuhnya -- dan
                                   keadaan 1-6 tidak menggantikannya. Kedua
                                   situs di view (jalur kandidat dan jalur
                                   terkunci) ikut bermutasi sekaligus: satu
                                   situs yang memihak sudah cukup untuk
                                   menggambar arah yang tidak dihitung.

  8. kontrol negatif: literal di    Literal yang **sah** harus tetap hijau.
     view, bukan aksesor model      `OnboardingView` memakai
                                   `isConfirmed: true` pada `CelestialVisualView`
                                   (struktur view, bukan aksesor model) untuk
                                   ilustrasi statis, dan `#Preview` complication
                                   memakai literal untuk data contoh. Gerbang
                                   yang memerah di sini akan memaksa orang
                                   melonggarkannya, dan pelonggaran itu yang
                                   membunuh gerbangnya.

  9. kontrol negatif: aksesor      Nama aksesor yang muncul tanpa argumen
     dipanggil tanpa `isConfirmed`  `isConfirmed:` harus **tidak** memerah --
                                   bukan karena itu boleh, melainkan karena
                                   gerbang ini mengukur nilai argumen, bukan
                                   kehadirannya. Kehadiran dijaga Aturan 24.

**Keadaan 1-3 tidak bisa saling menggantikan**, begitu pula 4-6, dan 7 berdiri
sendiri: masing-masing aksesor punya kawatnya sendiri, dan satu aksesor yang
dijaga tidak menjaga yang lain. Keadaan 8-9 menjaga arah sebaliknya -- gerbang
yang memerah pada kode yang benar akan dilonggarkan orang, dan gerbang yang
dilonggarkan tidak menjaga apa pun.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap hijau
walau aturan aslinya dilonggarkan.
"""

from __future__ import annotations

import os
import re
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
WATCH = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "PointingView.swift")

RULE_HEADER = "== Aturan 34:"
CLEAN_MARK = "Bersih: penjaga identitas menerima keyakinan engine."

#: Jangkar: baris **utuh**, supaya mutasinya tidak bergantung pada spasi dan
#: supaya kemunculannya bisa diperiksa eksplisit.
ANCHORS = {
    "morphology": (VIEW,
                   "DeepSkyCatalogue.drawableMorphology(forObjectID: $0, "
                   "isConfirmed: isConfirmed)"),
    "starColour": (VIEW, "visual.colorIndexBV, isConfirmed: isConfirmed)"),
    "planetPalette": (VIEW, "planet.palette.drawable(isConfirmed: isConfirmed)"),
    "spokenPhase": (WATCH, "spokenPhase(isConfirmed: isConfirmed)"),
    "spokenMorphology": (WATCH, "spokenDeepSkyMorphology(isConfirmed: isConfirmed)"),
    "spokenStarColour": (WATCH, "spokenStarColor(isConfirmed: isConfirmed)"),
    # Arah fase: kelas yang sama, argumen yang berbeda. `phaseGeometry`
    # tidak punya parameter `isConfirmed:`, jadi gerbang yang hanya mencari
    # `isConfirmed:` akan melewatkannya -- dan itulah sebabnya keadaan ini
    # ada di sini, bukan diasumsikan tertutup oleh keadaan 1-6.
    "phaseDirection": (VIEW, "phaseGeometry(waxing: visual.isWaxing)"),
}

SOURCES = (VIEW, WATCH)


def mutate(key):
    """Ganti argumen gerbang di jangkar jadi literal `true`.

    Jangkar `phaseDirection` muncul **dua kali** di view (jalur kandidat dan
    jalur terkunci), dan keduanya harus ikut bermutasi: gerbang yang hanya
    memeriksa satu situs akan hijau saat situs lainnya memihak ke satu sisi.
    Karena itu penggantiannya `replace` penuh, bukan `replace(..., 1)`.
    """
    path, anchor = ANCHORS[key]
    if "isConfirmed" in anchor:
        return [(path, anchor,
                 anchor.replace("isConfirmed: isConfirmed", "isConfirmed: true"))]
    return [(path, anchor,
             anchor.replace("waxing: visual.isWaxing", "waxing: true"))]


STATES = [
    ("[baseline]", None, False),
    ("1. jalur gambar: morfologi langit dalam dipaksa pasti", mutate("morphology"), True),
    ("2. jalur gambar: warna bintang dipaksa pasti", mutate("starColour"), True),
    ("3. jalur gambar: palet planet dipaksa pasti", mutate("planetPalette"), True),
    ("4. jalur suara: fase Bulan dipaksa pasti", mutate("spokenPhase"), True),
    ("5. jalur suara: morfologi langit dalam dipaksa pasti", mutate("spokenMorphology"), True),
    ("6. jalur suara: warna bintang dipaksa pasti", mutate("spokenStarColour"), True),
    ("7. arah fase dipilih untuk engine (dua situs)", mutate("phaseDirection"), True),
    ("8. kontrol negatif: literal sah di view tetap hijau", None, False),
    ("9. kontrol negatif: aksesor tanpa argumen keyakinan", None, False),
]

#: Keadaan 8 dan 9 menyuntik kode yang **tidak boleh** memerah. Keduanya
#: suntikan sungguhan (bukan no-op): yang diuji adalah bahwa gerbang ini
#: **tidak** menyala pada kode yang benar. Gerbang yang memerah di sini akan
#: dilonggarkan orang, dan gerbang yang dilonggarkan tidak menjaga apa pun.
ONBOARDING = os.path.join(ROOT, "Apps", "Shared", "OnboardingView.swift")
NEGATIVE_STATES = {
    # 8. `CelestialVisualView(isConfirmed: true)` adalah **struktur view**,
    #    bukan aksesor model: ilustrasi statis yang memang bukan hasil
    #    pengukuran. Bentuk ini sudah ada di OnboardingView; di sini ia
    #    disuntikkan ulang sebagai baris baru supaya keadaannya benar-benar
    #    berbeda dari baseline.
    8: [(ONBOARDING,
         "                Text(TextLocalization.text(.onboardingTitle))",
         "                CelestialVisualView(\n"
         "                    visual: CelestialVisual(kind: .star, "
         "relativeSize: 0.5),\n"
         "                    diameter: 32,\n"
         "                    isConfirmed: true)\n"
         "                Text(TextLocalization.text(.onboardingTitle))")],
    # 9. Aksesor model yang dipanggil **tanpa** argumen `isConfirmed:` sama
    #    sekali. Aturan 34 mengukur **nilai** argumennya, bukan kehadirannya
    #    (kehadiran dijaga Aturan 24), jadi ini harus hijau di sini.
    9: [(VIEW,
         "DeepSkyCatalogue.drawableMorphology(forObjectID: $0, "
         "isConfirmed: isConfirmed)",
         "DeepSkyCatalogue.drawableMorphology(forObjectID: $0)")],
}

#: Jangkar yang **memang** muncul lebih dari sekali, beserta jumlahnya.
#: `phaseDirection` ada di dua jalur gambar (kandidat dan terkunci); keduanya
#: wajib ikut bermutasi, jadi jumlahnya diperiksa sebagai angka, bukan
#: dipaksa 1.
EXPECTED_COUNTS = {"phaseDirection": 2}

_originals = {}
#: Berkas di luar `SOURCES` yang ikut disuntik (mis. `OnboardingView.swift`),
#: berisi isi **aslinya**. Dipakai untuk memulihkan dan untuk menghitung
#: keadaan berikutnya dari keadaan bersih, bukan dari keadaan tercemar.
_extra = {}


def restore(*_):
    for path, content in _originals.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)
    for path, content in _extra.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)


def extract_rule34():
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 34")
    if start < 0:
        return None
    end = text.find('if [ "$status" -eq 0 ]; then', start)
    if end < 0:
        return None
    return text[start:end]


def probe(program):
    proc = subprocess.run(["bash", "-c", program], cwd=ROOT,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    return (CLEAN_MARK not in out), out.strip()


def main():
    mutasi_sumber.require_clean_sources(list(SOURCES))

    program = extract_rule34()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 34 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in SOURCES:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()
    for key, (path, anchor) in ANCHORS.items():
        count = _originals[path].count(anchor)
        want = EXPECTED_COUNTS.get(key, 1)
        if count != want:
            print(f"GERBANG: jangkar '{key}' muncul {count}x di {path}, harus "
                  f"tepat {want}x -- harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for index, (label, mutations, must_fire) in enumerate(STATES, start=1):
            for path in SOURCES:
                mutasi_sumber.write_source(path, _originals[path])
            applied = mutations
            if applied is None and index in NEGATIVE_STATES:
                applied = NEGATIVE_STATES[index]

            # Mulai dari keadaan **bersih** tiap keadaan: menumpuk mutasi
            # membuat keadaan berikutnya mengukur campuran, dan kegagalan
            # pemulihan bersifat diam lalu menyalahkan kode yang benar.
            for path, content in _originals.items():
                mutasi_sumber.write_source(path, content)
            for path, content in _extra.items():
                mutasi_sumber.write_source(path, content)

            if applied is not None:
                bad = False
                for path, old, new in applied:
                    base = _originals.get(path) or _extra.get(path)
                    if base is None:
                        base = open(path, encoding="utf-8").read()
                        _extra[path] = base
                    content = base.replace(old, new, 1)
                    if content == base:
                        print(f"{label:56s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(path, content)
                if bad:
                    unexpected += 1
                    continue

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:56s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            # Yang dituntut bukan sekadar «merah»: gerbang ini harus menyebut
            # pemanggilan yang dilanggar. Merah dengan pesan kosong berarti ia
            # berbunyi tanpa mengukur.
            #
            # Kedua keluarga gerbang punya kata sendiri -- `isConfirmed` untuk
            # penjaga identitas, `waxing` untuk arah fase -- jadi menuntut
            # salah satunya saja akan membuat keadaan 7 "SALAH" walaupun
            # gerbangnya benar-benar menyebut pelanggarannya.
            names = "isConfirmed" in detail or "waxing" in detail
            ok = (fired == must_fire) and (not fired or names)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if fired and not must_fire:
                print(f"       (tidak diharapkan memerah) {detail[:160]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
