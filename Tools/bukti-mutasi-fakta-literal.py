#!/usr/bin/env python3
"""Buktikan Aturan 35 (fakta vs literal) **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia **bisa merah**, merah pada keadaan yang memang salah, dan merah
dengan pesan yang menunjuk pemanggilan yang dilanggar -- bukan sekadar
keluar != 0.

Kelas cacat yang ditutupnya.

`PointingView.swift` menampilkan status tautan ke iPhone di dua kanal yang
membaca **satu fakta yang sama**:

    ikon : link.isReachable ? "iphone.gen3.radiowaves..." : "iphone.slash"
    suara: LinkStatusText.linkSpeech(isReachable: link.isReachable, ...)

Diukur sebelum Aturan 35 ada, pada kawat yang memutuskan apa yang dibacakan
VoiceOver:

    `isReachable: link.isReachable` -> `isReachable: true`
        swift-ui-lint.sh    LULUS (exit 0)
        swift-typecheck.sh  LULUS (exit 0)
        ./swift-test.sh     755 uji, 0 gagal

Jadi ikon bisa berkata "iPhone tidak terjangkau" sementara pembaca layar
membacakan "iPhone terhubung", dan tidak ada satu pun gerbang yang berbunyi.

Kenapa Aturan 34 tidak menangkapnya: daftar aksesornya dibaca dari deklarasi
ber-parameter `isConfirmed:`, dan `linkSpeech` menerima `isReachable`.
Cacatnya bukan pada keyakinan identitas, melainkan pada **satu berkas yang
bertentangan dengan dirinya sendiri**.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                        gerbang hijau (kalau tidak, harness salah)

  1. jalur suara tautan             Cacat aslinya, persis bentuk yang diukur
     (berkas jam)                   di atas. Satu kata di satu tempat.

  2. arah fase planet               **Aksesor lain, argumen lain, berkas
     (berkas gambar bersama)        lain.** `phaseGeometry(waxing:)` menerima
                                    `Bool?`; `waxing: visual.isWaxing`
                                    diganti `waxing: true` di **kedua** situs
                                    (jalur kandidat dan jalur terkunci).
                                    Kalau harness ini hanya menguji keadaan 1,
                                    gerbang yang hanya mencari `isReachable`
                                    akan lolos.

  3. rekaman dari jam               **Parameter ketiga, berkas ketiga**, dan
     (berkas iPhone)                inilah keadaan yang membuktikan daftar
                                    parameternya **dibaca dari model**:
                                    `record(...)` menerima `fromWatch:`, dan
                                    `LinkView.swift` sudah membaca `.fromWatch`
                                    untuk memisahkan sampel yang datang dari
                                    jam. Aturan yang menuliskan `isReachable`
                                    sebagai satu-satunya nama yang dicari akan
                                    hijau di sini.

  4. kontrol negatif: literal sah   Literal yang **sah** harus tetap hijau.
     di ilustrasi statis            `OnboardingView` memakai
                                    `isConfirmed: true` pada
                                    `CelestialVisualView` -- **struktur view**,
                                    bukan aksesor model. Gerbang yang memerah
                                    di sini akan memaksa orang melonggarkannya,
                                    dan pelonggaran itu yang membunuh
                                    gerbangnya.

  5. kontrol negatif: perintah,     `setSensorAvailable(available: false)` di
     bukan klaim                    `MotionLogger` adalah **perintah**
                                    ("hentikan sensor"), dan berkas itu tidak
                                    membaca `.available` sama sekali. Bentuk
                                    ini yang memisahkan "kontradiksi berkas
                                    yang sama" dari "literal dilarang" --
                                    larangan menyeluruh akan memerah di sini,
                                    dan itu salah.

  6. fakta yang namanya             **Kelas cacat kedua, dan ini yang paling
     berbeda dari                    senyap.** Layar redup (Always-On) mengirim
     nama parameternya              tiga fakta ke `ReducedLuminanceLabel.text`,
                                    dan nama parameternya **tidak sama** dengan
                                    nama properti yang membacanya:

                                        isStale:        engine.isDisplayingStaleObject
                                        safetyWarning:  engine.slewVerdict?.safetyWarningText
                                        sensorNote:     motionNote  (-> engine.sensorNote)

                                    Diukur pada salinan utuh, proses baru:
                                    masing-masing diganti literal `false`/`nil`
                                    -> `swift-ui-lint.sh` LULUS (exit 0).
                                    Artinya **keempat** salinan fakta di layar
                                    redup bisa dijadikan tetapan dan tidak satu
                                    pun gerbang berbunyi -- termasuk sebelum
                                    Aturan 35 ada, karena `dibaca` hanya
                                    mencocokkan nama parameter persis.

                                    Yang paling berbahaya `isStale: false`:
                                    Always-On lalu membungkam peringatan "ini
                                    sisa pandangan lama" selamanya, di layar
                                    yang justru paling sedikit diberi konteks.

  7. kontrol negatif: parameter      `isStale:` yang memang **tidak** punya
     tanpa sumber di berkas itu     sumber di berkas itu tidak boleh dipaksa
                                    menyebut fakta apa pun. Bentuk ini menjaga
                                    arah sebaliknya: gerbang yang menuntut
                                    setiap literal `nil`/`false` menyebut
                                    anggota model akan memerah pada kode benar.

**Keadaan 1-3 tidak bisa saling menggantikan.** 1 menguji jalur suara tautan di
berkas jam, 2 aksesor fase di berkas gambar, 3 aksesor rekaman di berkas
iPhone. Satu aksesor yang dijaga tidak menjaga yang lain, dan keadaan 3
khususnya adalah satu-satunya yang membuktikan daftar parameternya tidak
disalin ke dalam aturan. Keadaan 4-5 menjaga arah sebaliknya.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap hijau
walau aturan aslinya dilonggarkan.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
WATCH = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "PointingView.swift")
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
PHONE_LINK = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                          "LinkView.swift")
ONBOARDING = os.path.join(ROOT, "Apps", "Shared", "OnboardingView.swift")
MOTION = os.path.join(ROOT, "Apps", "Shared", "MotionLogger.swift")

RULE_HEADER = "== Aturan 35:"
CLEAN_MARK = "Bersih: fakta Bool yang dibaca berkasnya sampai apa adanya."

REDUCED = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                       "ReducedLuminanceView.swift")

#: Jangkar: baris **utuh**, supaya mutasinya tidak bergantung pada spasi dan
#: supaya kemunculannya bisa diperiksa eksplisit.
LINK_SPEECH = "LinkStatusText.linkSpeech(isReachable: link.isReachable,"
PHASE = "phaseGeometry(waxing: visual.isWaxing)"
WATCH_SAMPLE = "                    let fromWatch = trace.samples.filter(\\.fromWatch)"
#: Unik: situs visual kedua diiringi `pulse:` statis. Situs pertama memakai
#: `isConfirmed: true,` juga, tetapi diikuti blok `// Gerbang hasPulse`, jadi
#: jangkar satu-baris akan muncul 2x dan harness menolak jalan.
ONBOARDING_VISUAL = ("                                isConfirmed: true,\n"
                     "                                pulse: MotionPolicy.staticPulsePhase)")

SENSOR_LOSS = "        let events = controller.setSensorAvailable(false)"

#: Layar redup: fakta yang namanya **berbeda** dari nama parameter tujuan.
REDUCED_STALE = "isStale: engine.isDisplayingStaleObject)"
REDUCED_SAFETY = "safetyWarning: engine.slewVerdict?.safetyWarningText,"
REDUCED_SENSOR = "sensorNote: motionNote,"


STATES = [
    ("[baseline]", None, False),
    # 1. Cacat aslinya: fakta yang sudah dibaca berkas itu diganti tetapan di
    #    kanal lain. Ikon dan suara lalu bisa berbeda di layar yang sama.
    ("1. jalur suara tautan dipaksa \"terhubung\"",
     [(WATCH, LINK_SPEECH,
       "LinkStatusText.linkSpeech(isReachable: true,")],
     True),
    # 2. Aksesor lain, argumen lain, berkas lain. Kedua situs sekaligus: satu
    #    situs yang memihak sudah cukup untuk menggambar arah yang tidak
    #    dihitung engine.
    ("2. arah fase planet dipilih untuk engine (dua situs)",
     [(VIEW, PHASE, "phaseGeometry(waxing: true)")],
     True),
    # 3. Parameter ketiga, berkas ketiga. Ini yang membuktikan daftar
    #    parameternya dibaca dari model, bukan disalin ke dalam aturan.
    ("3. rekaman dipaksa \"dari jam\" di berkas iPhone",
     [(PHONE_LINK, WATCH_SAMPLE,
       WATCH_SAMPLE + "\n"
       "                    trace.record(state: .searching, level: nil,\n"
       "                                 objectID: nil, objectName: nil,\n"
       "                                 separationDeg: nil, sigmaDeg: 0,\n"
       "                                 fromWatch: true)")],
     True),
    ("4. kontrol negatif: literal sah di ilustrasi statis", None, False),
    ("5. kontrol negatif: perintah sensor, bukan klaim", None, False),
    # 6. Fakta yang namanya berbeda dari nama parameternya. Tiga situs, tiga
    #    jenis: `Bool` (isStale), `String?` terekam (safetyWarning), dan
    #    `String?` lewat properti perantara (sensorNote). Semuanya lolos
    #    Aturan 35 sebelum keadaan ini ada, karena `dibaca` mencocokkan nama
    #    parameter persis.
    ("6a. layar redup: sisa pandangan dibungkam", [(REDUCED, REDUCED_STALE,
                                                   "isStale: false)")], True),
    ("6b. layar redup: peringatan keselamatan dihapus",
     [(REDUCED, REDUCED_SAFETY, "safetyWarning: nil,")], True),
    ("6c. layar redup: catatan sensor dihapus",
     [(REDUCED, REDUCED_SENSOR, "sensorNote: nil,")], True),
    ("7. kontrol negatif: literal di berkas tanpa faktanya", None, False),
]

#: Keadaan 4-5 menyuntik kode yang **tidak boleh** memerah. Keduanya suntikan
#: sungguhan (bukan no-op): yang diuji adalah bahwa gerbang ini **tidak**
#: menyala pada kode yang benar.
NEGATIVE_STATES = {
    # 4. `CelestialVisualView(isConfirmed: true)` adalah **struktur view**,
    #    bukan aksesor model: ilustrasi statis yang memang bukan hasil
    #    pengukuran. Sudah ada di OnboardingView; disuntikkan ulang sebagai
    #    baris baru supaya keadaannya benar-benar berbeda dari baseline.
    4: [(ONBOARDING, ONBOARDING_VISUAL,
         ONBOARDING_VISUAL + "\n"
         "                CelestialVisualView(\n"
         "                    visual: CelestialVisual(kind: .star, "
         "relativeSize: 0.5),\n"
         "                    diameter: 32,\n"
         "                    isConfirmed: true)")],
    # 5. Perintah berlabel ke berkas yang **tidak** membaca `.available`.
    #    Bentuk ini yang membedakan "kontradiksi berkas yang sama" dari
    #    "literal dilarang": larangan menyeluruh akan memerah di sini.
    5: [(MOTION, SENSOR_LOSS,
         SENSOR_LOSS + "\n"
         "        _ = controller.setSensorAvailable(available: false)")],
    # 7. Literal untuk parameter yang berkasnya **tidak punya** sumbernya.
    #    `ReducedLuminanceView` tidak membaca fase apa pun, jadi `waxing: true`
    #    yang disuntikkan ke sana tidak menyembunyikan fakta yang tersedia --
    #    gerbang yang menuntut setiap `true`/`false` menyebut anggota model
    #    akan memerah di sini, dan itu menuduh kode yang benar.
    7: [(REDUCED, REDUCED_STALE,
         REDUCED_STALE + "\n"
         "        _ = phaseGeometry(waxing: true)")],
}

_originals = {}
_extra = {}


def restore(*_):
    for path, content in _originals.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)
    for path, content in _extra.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)


def extract_rule35():
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 35")
    if start < 0:
        return None
    end = text.find('if [ "$status" -eq 0 ]; then', start)
    if end < 0:
        return None
    return text[start:end]


def probe(program):
    # Lewat **stdin**, bukan argv: `Program Argumen terlalu panjang` (E2BIG)
    # muncul begitu program Aturan 35 melewati batas satu argumen Linux
    # (~128 KiB). Diukur pada saat keadaan 6-7 ditambahkan: programnya 148.829
    # byte, dan `bash -c` menolak jalan -- harness lalu gagal karena alasan
    # yang tidak ada hubungannya dengan aturan yang diuji. Batas itu akan
    # tercapai lagi tanpa perubahan ini setiap kali aturan tumbuh.
    proc = subprocess.run(["bash", "-s"], cwd=ROOT, input=program,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    return (CLEAN_MARK not in out), out.strip()


def main():
    mutasi_sumber.require_clean_sources(
        [WATCH, VIEW, PHONE_LINK, ONBOARDING, MOTION, REDUCED])


    program = extract_rule35()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 35 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in (WATCH, VIEW, PHONE_LINK, ONBOARDING, MOTION, REDUCED):
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    # Jangkar harus muncul tepat sekali, kecuali yang memang berjumlah lain.
    # `phaseGeometry(waxing: visual.isWaxing)` ada di **dua** jalur gambar
    # (kandidat dan terkunci) dan keduanya wajib ikut bermutasi.
    expected = {PHASE: 2, REDUCED_STALE: 1}
    for path, anchor in ((WATCH, LINK_SPEECH), (VIEW, PHASE),
                         (PHONE_LINK, WATCH_SAMPLE),
                         (ONBOARDING, ONBOARDING_VISUAL),
                         (MOTION, SENSOR_LOSS),
                         (REDUCED, REDUCED_STALE),
                         (REDUCED, REDUCED_SAFETY),
                         (REDUCED, REDUCED_SENSOR)):
        count = _originals[path].count(anchor)
        want = expected.get(anchor, 1)
        if count != want:
            print(f"GERBANG: jangkar {anchor[:48]!r} muncul {count}x di "
                  f"{path}, harus tepat {want}x -- harness tidak boleh jalan.",
                  file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for index, (label, mutations, must_fire) in enumerate(STATES, start=1):
            # Mulai dari keadaan **bersih** tiap keadaan: menumpuk mutasi
            # membuat keadaan berikutnya mengukur campuran, dan kegagalan
            # pemulihan bersifat diam lalu menyalahkan kode yang benar.
            for path, content in _originals.items():
                mutasi_sumber.write_source(path, content)
            for path, content in _extra.items():
                mutasi_sumber.write_source(path, content)

            applied = mutations
            if applied is None and index in NEGATIVE_STATES:
                applied = NEGATIVE_STATES[index]

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
            names = any(n in detail for n in
                        ("isReachable", "waxing", "fromWatch",
                         "isStale", "safetyWarning", "sensorNote"))

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
