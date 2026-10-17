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

FILL_LINE = ("        .init(red: isNight ? nightRed : dayRed, "
             "green: 0, blue: 0)")
GLYPH_LINE = '    public static let glyph = "?"'

STATES = [
    ("[baseline] sumber apa adanya", None),
    ("1. isi lencana membawa hijau & biru", [
        (FILL_LINE, "        .init(red: isNight ? nightRed : dayRed, "
                    "green: 0.10, blue: 0.13)")]),
    ("2. cabang malam mengembalikan merah siang", [
        (FILL_LINE, "        .init(red: dayRed, green: 0, blue: 0)")]),
    ("3. simbol ? diganti huruf biasa", [
        (GLYPH_LINE, '    public static let glyph = "i"')]),
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

    original = open(TARGET, encoding="utf-8").read()
    for label, mutations in STATES:
        for old, _new in mutations or ():
            count = original.count(old)
            if count != 1:
                print(f"GERBANG: jangkar {label!r} muncul {count}x, harus "
                      f"tepat 1x — harness tidak boleh jalan.", file=sys.stderr)
                return 2

    unexpected = 0
    try:
        for index, (label, mutations) in enumerate(STATES):
            must_be_red = index != 0 or BASELINE_MUST_BE_RED
            text = original
            for old, new in mutations or ():
                text = text.replace(old, new, 1)
            with open(TARGET, "w", encoding="utf-8") as handle:
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
        with open(TARGET, "w", encoding="utf-8") as handle:
            handle.write(original)

    if open(TARGET, encoding="utf-8").read() != original:
        print("PEMULIHAN GAGAL — periksa CandidateMarker.swift",
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
