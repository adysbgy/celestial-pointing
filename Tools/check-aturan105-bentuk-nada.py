#!/usr/bin/env python3
"""Bentuk nada kunci harus datang dari model teruji, bukan ditulis di `Apps/`.

**Cacat yang ditutup aturan ini, dan kenapa ia tidak terlihat.**

`AudioCueEngine.ensureResources()` di `Apps/Shared/AudioCue.swift` dulu
menyintesis nada kunci dengan empat angka dan satu rumus yang ditulis langsung
di dalam gelung sampel:

    let sampleRate: Double = 44100
    let duration: Double = 0.13
    let envelope = sin(.pi * Double(i) / Double(frameCount))
    samples[i] = Float(0.28 * sin(2 * .pi * 880 * t) * envelope)

`Apps/` **tidak pernah dibangun** `./swift-test.sh` di Linux, dan tidak satu
pun dari 45 aturan UI membacanya. Diukur: nol pemeriksaan di `Tools/`
menyebut `sampleRate`, `880`, atau rumus amplopnya. Politik **peristiwa**
mana yang berbunyi sudah dipindah ke `AudioEventPolicy`, dan politik
**saklar** ke `AudioPreference` — tetapi bagian yang paling mudah rusak tanpa
terlihat justru tertinggal di sini, karena rusaknya hanya **terdengar**.

Bentuk rusaknya, semuanya mengompilasi bersih dan lolos setiap gerbang teks:

    amplop dibalik (1 - sin(...))      -> klik di kedua ujung buffer
    frequency = 0                      -> BISU TOTAL, tanpa satu pun galat
    peakAmplitude > 1.0                -> terpotong (clip) di mixer
    duration terlalu pendek            -> potongan gelombang, tinggi berubah

Yang paling berbahaya adalah yang kedua: bunyi adalah **satu-satunya saluran**
bagi pengguna yang tidak melihat layar — tepat pengguna yang fitur ini ada
untuknya — dan bisu tidak bisa dibedakan dari "tidak ada yang dikunci".

**Yang diperiksa, dan kenapa arahnya dua.**

1. `ToneSynth` ada dan memuat kelima angka bentuk nada. Gerbang yang
   kehilangan subjeknya akan hijau selamanya, jadi keberadaannya diperiksa
   eksplisit, bukan diasumsikan.
2. `Apps/` **tidak** memuat angka-angka itu sebagai literal. Nol literal,
   bukan "sebagian besar literal": yang dijaga adalah perjanjian bahwa
   bentuk nada punya satu sumber, dan perjanjian yang dipenuhi sebagian akan
   menyimpang lagi.
3. `Apps/` benar-benar **memakai** `ToneSynth` — gerbang yang hanya melarang
   literal akan hijau atas berkas yang berhenti menyintesis sama sekali.
4. `ToneSynthTests` menyebut setiap sifat yang diklaim (amplop nol di ujung,
   frekuensi audible, amplitudo berruang kepala, osilasi). Tanpa ini,
   memindahkan angka ke model tanpa uji hanya memindahkan lubangnya.

**Batas yang diakui.** Gerbang ini membaca **teks**, jadi yang diukur adalah
perjanjian antar-teks, bukan bunyi di perangkat. Apakah nada itu terdengar
nyaman pada jam 40 mm tetap belum terukur di sini — itu butuh perangkat.
Yang bisa diklaim: kelima angka bentuk nada tidak bisa lagi berubah sendiri
di `Apps/` tanpa ada yang berbunyi, dan sifat-sifat yang membuatnya terdengar
seperti konfirmasi (bukan klik, bukan bisu) dijalankan di Linux.

Pakai:
    python3 Tools/check-aturan105-bentuk-nada.py     # 0 = patuh
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

APP = os.path.join(ROOT, "Apps", "Shared", "AudioCue.swift")
MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "ToneSynth.swift")
TESTS = os.path.join(ROOT, "Packages", "PointingKit", "Tests",
                     "PointingKitTests", "ToneSynthTests.swift")

#: Angka bentuk nada yang dulu hidup di `Apps/`, dan nama modelnya.
#: Dipakai untuk mencari **literal** di `Apps/`: nilai apa pun yang sama
#: dengan salah satu angka ini di berkas `Apps/` adalah salinan kedua.
NUMERIC_TOKENS = [
    ("sampleRate", "44100"),
    ("duration", "0.13"),
    ("frequency", "880"),
    ("peakAmplitude", "0.28"),
]

#: Angka yang **boleh** muncul di `Apps/` karena ia bukan bentuk nada:
#: 0 dan 1 dipakai di mana-mana (indeks, kanal, boolean), dan `2 * .pi`
#: adalah konstanta matematis. Yang dilarang adalah angka **khas** di atas.

#: Nama model yang harus dipakai `Apps/`.
#: Bentuknya **terkunci dengan tanda kurung**, bukan nama telanjang, dan itu
#: bukan kerapian: `ToneSynth.sample` adalah awalan dari `ToneSynth.sampleRate`,
#: jadi pemeriksaan substring telanjang `"ToneSynth.sample" in code` tetap
#: hijau walaupun satu-satunya baris yang benar-benar menghasilkan isi buffer
#: (`ToneSynth.sample(atIndex:...)`) dibuang — terukur: berkas yang
#: `samples[i] = Float(0)` masih memuat kedua nama itu. Yang dijaga bukan
#: adanya nama, melainkan **pemanggilannya**.
MODEL_SYMBOLS = ["ToneSynth.sampleRate", "ToneSynth.frameCount", "ToneSynth.sample("]

#: Sifat yang harus diuji di `ToneSynthTests`, dan nama ujinya.
REQUIRED_TESTS = [
    "testEnvelopeIsSilentAtBothEnds",
    "testFrequencyIsAudible",
    "testPeakAmplitudeLeavesHeadroom",
    "testTheToneActuallyOscillates",
    "testDurationIsLongEnoughToBeATone",
]


def read(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return None


def strip_comments(source: str) -> str:
    """Buang komentar supaya angka di dalam komentar tidak dihitung literal.

    Ini penting dan bukan kerapian: docstring `AudioCue.swift` **menyebut**
    angka-angka itu ketika menjelaskan kenapa ia dipindah. Gerbang yang
    membaca komentar akan merah pada dokumentasi yang benar, dan gerbang yang
    merah pada kebenaran akan dihapus orang.
    """
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", source)


def main() -> int:
    failures: list[str] = []

    # --- 1. Model ada dan memuat kelima angka ------------------------------
    model = read(MODEL)
    if model is None:
        failures.append(
            "ToneSynth.swift TIDAK ada di PointingKit — bentuk nada tidak "
            "punya sumber yang bisa diuji di Linux")
        model = ""
    else:
        for name, value in NUMERIC_TOKENS:
            declaration = re.search(
                rf"public\s+static\s+let\s+{name}\s*:\s*Double\s*=\s*{re.escape(value)}\b",
                model)
            if declaration is None:
                failures.append(
                    f"ToneSynth.{name} tidak dideklarasikan sebagai {value} — "
                    f"gerbang ini menjaga angka itu, dan modelnya tidak "
                    f"memuatnya lagi")

    # --- 2. `Apps/` tidak memuat angka itu sebagai literal -----------------
    app = read(APP)
    if app is None:
        failures.append(f"{os.path.relpath(APP, ROOT)} TIDAK ada")
        app = ""
    else:
        code = strip_comments(app)
        for name, value in NUMERIC_TOKENS:
            # Cocokkan angka sebagai token utuh: `0.13` tidak boleh cocok
            # dengan `0.130`, dan `44100` tidak boleh cocok dengan `441000`.
            pattern = rf"(?<![\d.]){re.escape(value)}(?![\d])"
            if re.search(pattern, code):
                failures.append(
                    f"`{value}` (bentuk nada `{name}`) masih ditulis sebagai "
                    f"literal di Apps/Shared/AudioCue.swift — pindahkan ke "
                    f"ToneSynth, tempat ia diuji di Linux")

        # --- 3. `Apps/` benar-benar memakai model --------------------------
        for symbol in MODEL_SYMBOLS:
            if symbol not in code:
                failures.append(
                    f"Apps/Shared/AudioCue.swift tidak memakai `{symbol}` — "
                    f"gerbang yang hanya melarang literal akan hijau atas "
                    f"berkas yang berhenti menyintesis nada")

        # Rumus amplop tidak boleh hidup lagi di sini.
        if re.search(r"\bsin\s*\(\s*\.pi\s*\*", code):
            failures.append(
                "rumus amplop `sin(.pi * ...)` masih ada di Apps/ — bentuk "
                "amplop hidup di ToneSynth.envelope, bukan di view")

    # --- 4. Sifat yang diklaim benar-benar diuji ---------------------------
    tests = read(TESTS)
    if tests is None:
        failures.append(
            "ToneSynthTests.swift TIDAK ada — memindahkan angka ke model "
            "tanpa uji hanya memindahkan lubangnya")
    else:
        for name in REQUIRED_TESTS:
            if f"func {name}(" not in tests:
                failures.append(
                    f"uji `{name}` tidak ada di ToneSynthTests — sifat itu "
                    f"tidak lagi dijaga siapa pun")

    # --- Laporan ----------------------------------------------------------
    if failures:
        for failure in failures:
            print(f"FAIL {failure}")
        print()
        print("-> Bentuk nada kunci (frekuensi, amplitudo, amplop, durasi) "
              "harus datang dari ToneSynth.")
        print("   Rusaknya tidak mengompilasi gagal dan tidak terlihat di "
              "layar: amplop terbalik = klik,")
        print("   frekuensi nol = bisu total tanpa galat. Bunyi adalah "
              "satu-satunya saluran bagi pengguna")
        print("   yang tidak melihat layar, jadi ia tidak boleh jadi "
              "satu-satunya bagian tanpa uji.")
        return 1

    print(f"OK Apps/Shared/AudioCue.swift — bentuk nada dipanggil dari "
          f"ToneSynth, nol literal ({len(NUMERIC_TOKENS)} angka diperiksa)")
    print(f"OK ToneSynth — {len(NUMERIC_TOKENS)} angka bentuk nada "
          f"dideklarasikan di model teruji")
    print(f"OK ToneSynthTests — {len(REQUIRED_TESTS)} sifat dijaga "
          f"(amplop, frekuensi, amplitudo, durasi, osilasi)")
    print()
    print("Aturan 105: bentuk nada kunci punya satu sumber yang diuji di "
          "Linux — klik, bisu, dan clip tidak bisa kembali tanpa gerbang "
          "berbunyi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
