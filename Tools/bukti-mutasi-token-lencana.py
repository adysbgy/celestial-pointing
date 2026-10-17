#!/usr/bin/env python3
"""Buktikan `CandidateMarkerTests` **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

`CandidateMarkerTests` lahir sesudah cacatnya diperbaiki, dan uji yang ditulis
sesudah perbaikan tidak membuktikan apa pun tentang cacatnya: uji yang selalu
hijau sama tidak bergunanya dengan gerbang yang tidak pernah berbunyi. Yang
harus dibuktikan adalah bahwa uji-uji itu **bisa merah**, merah pada bentuk
cacat yang memang pernah nyata, dan dengan pesan yang menunjuk ke klaim yang
dilanggar.

Berkas ini beda dari `Tools/bukti-mutasi-lencana-ragu.py`. Yang itu menjaga
**aturan lint** (Aturan 32) atas jangkar di view; yang ini menjaga **token
warna** di PointingKit lewat `swift test`. Keduanya menyebut "lencana ragu",
tetapi cacat yang bisa lolos darinya berbeda: aturan lint tetap hijau walau
angka warnanya diganti, karena Aturan 32 hanya menuntut lencana itu digambar
di bawah `!isConfirmed`.

Kelas cacat yang ditutupnya.

Lencana itu satu-satunya penanda di layar yang berkata "engine belum pasti".
Ia dipakai di mode malam — satu-satunya mode yang rhodopsin izinkan (rod
~498-530nm; cahaya >620nm aman). Sebelum tokennya pindah ke model, warnanya
`Color.black.opacity(0.55)` lewat `shadowAccent(...)`, dan `shadowAccent`
tidak memetakan apa pun: di mode malam lencana itu jadi satu-satunya piksel
bukan-merah di layar. Gerbang warna Aturan 15 tidak bisa melihatnya karena
`Color.black` adalah nama, bukan angka prosedural.

Keadaan yang diukur, dan apa yang masing-masing buktikan:

  [baseline]   salinan tanpa mutasi -> uji HIJAU.
               Kalau ini merah, harness yang selalu merah akan "lulus"
               semua keadaan di bawah tanpa membuktikan apa pun, jadi
               baseline wajib ikut diukur.

  1. isi lencana membawa hijau=0.10, biru=0.13
               Bentuk cacat aslinya: warna lama yang tidak murni merah.
               Wajib MERAH. Menutup dua klaim sekaligus: merah murni di
               mode malam, dan penanda yang tetap lebih gelap dari cincin
               yang ditutupinya.

  2. cabang malam mengembalikan merah **siang**
               Arah sebaliknya, dan tanpa ini cacat 1 bisa "diselesaikan"
               dengan menyamakan kedua mode. Regresi yang lebih halus: kanal
               hijau/biru tetap nol, tetapi mode malam kehilangan alasan
               lencananya lebih terang (latar malam mendekati hitam, jadi
               merah siang 0.38 tenggelam). Wajib MERAH.

  3. simbol `?` diganti huruf biasa
               Sisi bentuk. Mode malam membuang hue, jadi lencana yang
               dibedakan warna saja menghilang bersama hue-nya; yang
               tersisa harus tanda tanya. Wajib MERAH.

  4. garis lencana = isi lencana
               Garis yang sama dengan isinya berarti cincin hilang. Dulu garis
               ini memakai `PointingTone.warning.color`, jalur di luar palet
               gambar, jadi tidak ada uji yang menjaganya. Wajib MERAH.

  5. token garis malam dibawa **turun** sampai menyentuh isinya
               Nilainya diubah di palet (`NightVisual.swift`), bukan di
               `CandidateMarker`. Itu disengaja: keadaan ini harus dibuktikan
               oleh **jarak** (`testStrokeIsBrighterThanTheFillItOutlines`),
               bukan oleh uji "satu pemilik". Kalau mutasinya di
               `CandidateMarker`, uji pemilik yang lebih dulu berbunyi, dan
               klaim jaraknya tidak pernah terbukti bisa merah.

**Yang TIDAK diklaim harness ini.** Ia tidak menjalankan lint, tidak
membangun `Apps/` (Linux tidak punya SwiftUI), dan tidak membuktikan bahwa
`CelestialVisualView` benar-benar **memakai** `CandidateMarker.badgeFill` —
itu dijaga terpisah oleh `Tools/check-harness-terdaftar.py` (harness yang tak
dirujuk = gerbang mati) dan oleh pembacaan diff. Ia juga tidak menyentuh
aturan Aturan 32; lihat `Tools/bukti-mutasi-lencana-ragu.py`.

Lingkungan: docker + image `swift:6.0`, sama dengan `swift-test.sh`. Kalau
docker tidak ada, harness berhenti (exit 2) alih-alih melaporkan hijau atas
nol pembuktian.

Jalankan:  python3 Tools/bukti-mutasi-token-lencana.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, "Packages", "PointingKit", "Sources",
                      "PointingKit", "CandidateMarker.swift")
#: Palet — tujuan mutasi keadaan 5. Nilai token diubah **di sini** supaya yang
#: berbunyi adalah uji jarak, bukan uji "satu pemilik".
PALETTE = os.path.join(ROOT, "Packages", "PointingKit", "Sources",
                       "PointingKit", "NightVisual.swift")
STROKE_TOKEN = "        candidateStroke: .init(red: 1.0, green: 0, blue: 0)"

FILL_LINE = ("        .init(red: isNight ? nightRed : dayRed, "
             "green: 0, blue: 0)")
GLYPH_LINE = '    public static let glyph = "?"'
#: Cabang malam `stroke`, satu baris utuh (termasuk nama token) supaya
#: penggantinya tidak ikut menyisipkan nama aksen yang mengubah hasil gerbang
#: jangkauan — harness ini mengukur **uji lencana**, bukan gerbang lint.
STROKE_NIGHT = ("            let token = CelestialVisual.accents.candidateStroke\n"
                "            return CelestialVisual.RGBComponents("
                "red: token.red, green: token.green,\n"
                "                                                 "
                "blue: token.blue)")

STATES = [
    ("[baseline] sumber apa adanya", None),
    ("1. isi lencana membawa hijau & biru", {TARGET: [
        (FILL_LINE, "        .init(red: isNight ? nightRed : dayRed, "
                    "green: 0.10, blue: 0.13)")]}),
    ("2. cabang malam mengembalikan merah siang", {TARGET: [
        (FILL_LINE, "        .init(red: dayRed, green: 0, blue: 0)")]}),
    ("3. simbol ? diganti huruf biasa", {TARGET: [
        (GLYPH_LINE, '    public static let glyph = "i"')]}),
    # 4 & 5 menjaga **garis** lencana, bagian yang sampai siklus ini tidak
    # dijaga apa pun: ia dulu memakai `PointingTone.warning.color`, jalur di
    # luar palet gambar yang diukur pemeriksa visual.
    ("4. garis lencana = isi lencana", {TARGET: [
        (STROKE_NIGHT, "            return badgeFill(isNight: true)")]}),
    ("5. token garis menyentuh isinya", {PALETTE: [
        (STROKE_TOKEN, "        candidateStroke: .init(red: 0.75, green: 0, blue: 0)")]}),
]

#: Satu-satunya keadaan yang wajib HIJAU: baseline. Sisanya wajib merah —
#: diturunkan dari posisinya, bukan diketik ulang, supaya tidak ada keadaan
#: yang bisa "lupa" ditandai merah dan diam-diam lulus sebagai hijau.
BASELINE_MUST_BE_RED = False

RULE = "CandidateMarkerTests"


def run_tests() -> tuple[bool, str]:
    """Jalankan hanya uji lencana, di container yang sama dengan CI.

    `--filter` dipakai supaya keadaan yang tidak dimaksud tidak ikut
    menentukan hasil: harness ini mengklaim tentang `CandidateMarkerTests`,
    bukan tentang seluruh paket (itu tugas `swift-test.sh`).
    """
    cmd = [
        "sudo", "-n", "docker", "run", "--rm",
        "-v", f"{ROOT}:/src",
        "-w", "/src/Packages/PointingKit",
        "swift:6.0", "swift", "test", "--filter", RULE,
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    except subprocess.TimeoutExpired:
        return False, "swift test melewati batas waktu"
    output = proc.stdout + proc.stderr
    if "error:" in output and "unable to load standard library" in output:
        # Gagal build bukan "uji merah": kalau tidak dibedakan, keadaan merah
        # karena alasan yang salah akan dihitung sebagai bukti.
        return False, output
    if f"Test Suite '{RULE}'" not in output:
        return False, output
    return proc.returncode == 0, output


def main() -> int:
    if shutil.which("sudo") is None or shutil.which("docker") is None:
        print("docker/sudo tidak ditemukan: harness tidak bisa membuktikan "
              "apa pun.", file=sys.stderr)
        return 2

    originals = {path: open(path, encoding="utf-8").read()
                 for path in (TARGET, PALETTE)}
    for label, per_file in STATES:
        for path, mutations in (per_file or {}).items():
            for old, _new in mutations:
                count = originals[path].count(old)
                if count != 1:
                    print(f"GERBANG: jangkar {label!r} di "
                          f"{os.path.basename(path)} muncul {count}x, harus "
                          f"tepat 1x — harness tidak boleh jalan.",
                          file=sys.stderr)
                    return 2

    unexpected = 0
    try:
        for index, (label, per_file) in enumerate(STATES):
            must_be_red = index != 0 or BASELINE_MUST_BE_RED
            for path in (TARGET, PALETTE):
                text = originals[path]
                for old, new in (per_file or {}).get(path, ()):
                    text = text.replace(old, new, 1)
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(text)
            green, output = run_tests()
            got_red = not green
            ok = got_red == must_be_red
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:44s} "
                  f"{'MERAH' if got_red else 'hijau'}")
            if got_red:
                for line in output.splitlines():
                    if "error:" in line:
                        print(f"       {line.strip()[:160]}")
                        break
    finally:
        for path, text in originals.items():
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(text)

    for path, text in originals.items():
        if open(path, encoding="utf-8").read() != text:
            print(f"PEMULIHAN GAGAL — periksa {os.path.basename(path)}",
                  file=sys.stderr)
            return 2

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan", file=sys.stderr)
        return 1
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
