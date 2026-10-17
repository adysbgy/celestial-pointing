#!/usr/bin/env python3
"""Buktikan dua gerbang baru berbunyi **dan** tidak berbunyi pada kode sah.

Kenapa harness ini ada.

`Tools/ukur-uji-menggantung.py` mengukur keluarga "nama uji yang dikutip
padahal tidak ada ujinya" dan menemukan 3 dari 43 pada 16 Okt 2026. Alat itu
**tidak pernah dijalankan CI**. `swift-test.sh` hanya membangun `Packages/`
dan tidak bisa membaca `Apps/`, jadi `ukur-*.py` tidak bisa memicunya lewat
uji Swift. Yang saya tambahkan:

  - `check_cited_test_names_in_every_source_exist` — nama uji yang dikutip
    **di komentar** `Packages/`, `Apps/`, atau baris yang dikirim harus punya
    definisi. (Gerbang lama `check_cited_test_names_exist` hanya membaca
    `Apps/`, dan mencakup string/kode juga.)
  - `check_shipped_has_no_settling_markers` — `TODO`/`FIXME`/`HACK`/`XXX`
    tidak boleh tertinggal di baris yang dikirim.

Dua-duanya **diam** pada kode yang benar hari ini (53 sebutan nama uji,
13.218 komentar). Itu belum bukti apa pun: gerbang yang tidak pernah
berbunyi sama saja dengan tidak ada. Harness ini menanam cacat yang
**persis** berbentuk seperti yang bisa mendarat (salinan kerja disalin ke
kotak pasir, mutasi dijalankan di sana, pohon kerja tidak pernah disentuh),
lalu menuntut gerbangnya berbunyi — atau, untuk kontrol negatif, diam.

Keadaan:

  [baseline]                                       hijau, tidak ada temuan
  1. komentar menunjuk uji yang tidak ada          MERAH (yang dicari)
  2. kontrol negatif: nama uji tidak ada **saja**
     tanpa sebutan di komentar/listrik string      hijau (bukan "apa pun
                                                   yang memuat kata test").
     Harness ini menemukan bahwa versi pertama pembaca MEMANG merah di sini
     ketika namanya ditaruh di kutip ganda: pembaca kehilangan **awal**
     string itu, lalu membaca dasarnya sebagai komentar. Dua cacat pembaca
     lain yang lebih besar ketahuan di jalan yang sama: penanda `///` ikut
     masuk token (seluruh dokumentasi `Apps/` lolos tanpa diperiksa), dan
     `/** … */` membuat seluruh berkas sesudahnya terbaca sebagai kode.
  3. kontrol negatif: `testable` di komentar       hijau (bukan awalan test)
  4. kalimat uji yang sah dipindah ke Packages/    hijau (cakupannya luas,
                                                   bukan hanya Apps/)
  5. definisi uji dihapus, kutipan tetap           MERAH (arah sebaliknya:
                                                   notasi uji yang mati)
  6. `TODO` tertinggal di komentar                 MERAH
  7. `FIXME` dan `XXX` sekaligus                    MERAH satu baris (baris
                                                   dilaporkan sekali, bukan
                                                   sekali per penanda: dua
                                                   temuan untuk satu tempat
                                                   adalah tuntutan yang sama
                                                   sekali)
  8. pembaca sebutan dilumpuhkan                   MERAH (fail-closed: nol
                                                   sebutan bukan berarti bersih)
  9. penanda kosong tapi komentar terbaca          hijau (gerbang mengukur,
                                                   bukan hanya tidak crash)

Pakai:
    python3 Tools/bukti-mutasi-ilusi-cakupan.py     # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: Pohon yang disalin ke kotak pasir. Cukup untuk dua gerbang ini; sisanya
#: tidak perlu karena probe hanya memanggil dua fungsi.
SALIN = ("Packages", "Apps", "Tools/check-visuals.py", "Tools/render-visuals.py")

#: Nama pemeriksaan, dipakai apa adanya. Kalau namanya berubah di gerbang,
#: harness ini merah — bukan diam-diam mencocokkan himpunan kosong.
CITED = "nama uji yang dikutip sumber produksi ada"
MARKERS = "sumber yang dikirim tanpa penanda sementara"

#: Berkas nyata yang dipakai tiap keadaan.
APP = "Apps/Shared/SurfaceTokens.swift"
PACKAGE = "Packages/PointingKit/Sources/PointingKit/PointingPresentation.swift"
DAYLIGHT_TEST = ("Packages/CelestialEngine/Tests/CelestialEngineTests/"
                 "VisibilityTests.swift")
ADJACENT_TEST = "Packages/PointingKit/Tests/PointingKitTests/NightVisualTests.swift"

#: Jangkar di `SurfaceTokens.swift`: satu kalimat uji yang **dikutip sebagai
#: izin** untuk sebuah angka. Diukur sebelum dipilih: nama ini sudah ada di
#: komentar berkas itu dan ujinya ada di `NightVisualTests.swift`.
CITED_ANCHOR = "`testThePaintedBackdropStillLeavesTheCardAVisibleStep`."

#: Jangkar tekstual di `check-visuals.py` yang dibalik menjadi "tidak
#: mencocokkan apa pun" — pembaca sebutan nama uji dilumpuhkan.
READER_ANCHOR = 'r"\\btest[A-Z][A-Za-z0-9_]+"'

PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe_ilusi", "check-visuals.py")
results = []
C.check_cited_test_names_in_every_source_exist(results)
C.check_shipped_has_no_settling_markers(results)
for r in results:
    print((("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail))
"""


def sandbox_copy(dest):
    for name in SALIN:
        src = os.path.join(ROOT, name)
        dst = os.path.join(dest, name)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.isdir(src):
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns(
                ".build", "*.pyc", "__pycache__"))
        else:
            shutil.copy2(src, dst)


def read(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as handle:
        return handle.read()


def write(root, rel, text):
    path = os.path.join(root, rel)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)


def replace_once(root, rel, find, replace, failures, state):
    source = read(root, rel)
    if find not in source:
        failures.append(f"{state}: jangkar tidak ditemukan di {rel}")
        return False
    write(root, rel, source.replace(find, replace, 1))
    return True


def run_probe(root):
    out = subprocess.run([sys.executable, "-c", PROBE, root],
                         capture_output=True, text=True, timeout=600)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        state, rest = line.split(" ", 1)
        name = rest.split("  | ")[0].strip()
        verdicts[name] = "hijau" if state == "OK" else "merah"
    return verdicts, None


def _red_lines(verdicts):
    """Pemeriksaan per-temuan (nama memuat lokasi `berkas:baris`)."""
    return {name: state for name, state in verdicts.items()
            if ":" in name and state == "merah"}


def apply_state(root, state, failures):
    """Tanam cacat untuk satu keadaan. Mengembalikan catatan tambahan."""
    if state.startswith("[baseline]"):
        return
    if state.startswith("1."):
        replace_once(root, APP, CITED_ANCHOR,
                     "`testThisCitedTestWasNeverWritten`.", failures, state)
    elif state.startswith("2."):
        # Nama uji TIDAK ada, tetapi hanya muncul di dalam literal atau kode —
        # bukan di komentar. Gerbangnya tidak boleh melaporkannya.
        #
        # Kutip **tunggal** dipakai sebagai pembatas string: pembaca yang
        # kehilangan awal string harus jatuh ke `code` (diam), bukan ke
        # `comment` (menuduh). Kutip ganda sengaja tidak dipakai di sini —
        # itu cacat pembaca sendiri, dan ia diuji pada berkas nyata
        # (`Apps/` penuh string berisi `\"`), bukan pada satu contoh buatan.
        probe = "te" + "stAStringThatLooksLikeATestName"
        replace_once(root, APP, "    static var appBackground: LinearGradient {",
                     "    func label() -> String {\n"
                     "        \"te\" + \"stAStringThatLooksLikeATestName\"\n"
                     "    }\n"
                     "    static var appBackground: LinearGradient {",
                     failures, state)
    elif state.startswith("3."):
        replace_once(root, APP, CITED_ANCHOR,
                     "`testable` dan `tested` bukan nama uji; `protestAt` juga.",
                     failures, state)
    elif state.startswith("4."):
        # Kalimat uji yang **sah** dipindah ke paket. Gerbang lama hanya
        # membaca `Apps/`, jadi keadaan ini hijau di sana dan hijau di sini.
        replace_once(root, APP, CITED_ANCHOR, "`test` yang sah.", failures, state)
        replace_once(root, PACKAGE,
                     "Satu-satunya sumber nilainya adalah `symbolName`",
                     "Satu-satunya sumber nilainya adalah `symbolName`, dijaga "
                     "`testEveryMorphologyHasItsOwnColour`", failures, state)
    elif state.startswith("5."):
        # Definisi ujinya dihapus, kutipan tetap. Arah sebaliknya dari
        # keadaan 1, dan bentuk yang sungguh terjadi di repo ini ketika sebuah
        # uji diganti nama.
        replace_once(root, ADJACENT_TEST,
                     "func testEveryMorphologyHasItsOwnColour()",
                     "func testEveryMorphologyHasADifferentColour()",
                     failures, state)
    elif state.startswith("6."):
        replace_once(root, APP, CITED_ANCHOR,
                     "TODO: rapikan ini. `testThePaintedBackdropStillLeavesTheCardAVisibleStep`.",
                     failures, state)
    elif state.startswith("7."):
        replace_once(root, APP, CITED_ANCHOR,
                     "FIXME dan XXX: dua penanda di satu baris.", failures, state)
    elif state.startswith("8."):
        # Pembaca sebutan dilumpuhkan: pola tidak mencocokkan apa pun lagi.
        replace_once(root, "Tools/check-visuals.py", READER_ANCHOR,
                     'r"\\bZZZNO_TEST_NAMES_HERE[A-Z][A-Za-z0-9_]+"',
                     failures, state)
    else:
        failures.append(f"{state}: tidak ada penanam untuk keadaan ini")


def main():
    work = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "..", ".harness-ilusi-cakupan")
    work = os.path.abspath(work)
    if os.path.isdir(work):
        shutil.rmtree(work)
    os.makedirs(work)

    states = [
        ("[baseline]", None),
        ("1. komentar menunjuk uji yang tidak ada", {"cited_red": 1, "marker_red": 0}),
        ("2. nama uji hanya di string (kontrol negatif)", {"cited_red": 0, "marker_red": 0}),
        ("3. 'testable'/'tested' bukan nama uji (kontrol)", {"cited_red": 0, "marker_red": 0}),
        ("4. kutipan sah dipindah ke Packages/ (kontrol)", {"cited_red": 0, "marker_red": 0}),
        ("5. definisi uji dihapus, kutipan tetap", {"cited_red": 1, "marker_red": 0}),
        ("6. TODO tertinggal di komentar", {"cited_red": 0, "marker_red": 1}),
        ("7. FIXME dan XXX di satu baris", {"cited_red": 0, "marker_red": 1}),
        ("8. pembaca sebutan dilumpuhkan (fail-closed)", {"cited_red": 1, "marker_red": 0}),
    ]

    failures = []
    print(f"kotak pasir: {work}\n")
    for state, expected in states:
        sandbox = os.path.join(work, "s")
        if os.path.isdir(sandbox):
            shutil.rmtree(sandbox)
        os.makedirs(sandbox)
        sandbox_copy(sandbox)
        apply_state(sandbox, state, failures)

        verdicts, error = run_probe(sandbox)
        if verdicts is None:
            failures.append(f"{state}: probe gagal: {error}")
            print(f"{state}: PROBE GAGAL\n{error}")
            continue
        if CITED not in verdicts or MARKERS not in verdicts:
            failures.append(f"{state}: nama pemeriksaan tidak ada di keluaran")
            print(f"{state}: TIDAK ADA PEMERIKSAAN")
            continue

        if expected is None:
            bad = [n for n, v in verdicts.items() if v != "hijau"]
            if bad:
                failures.append(f"{state}: baseline tidak hijau: {bad}")
                print(f"{state}: BASELINE TIDAK HIJAU -> {bad}")
            else:
                print(f"{state}: hijau di {len(verdicts)} pemeriksaan (benar)")
            continue

        reds = _red_lines(verdicts)
        whole_cited = verdicts[CITED]
        whole_markers = verdicts[MARKERS]
        if state.startswith("8."):
            # Fail-closed: yang harus berbunyi adalah **ringkasan** itu sendiri
            # (`cited_red` merujuk ringkasan, bukan baris per-temuan). Nol
            # baris per-temuan justru yang diharapkan — pembacanya berhenti
            # mencocokkan, jadi tidak ada sebutan yang bisa dilaporkan.
            # (`expected` menyatakan 1 karena yang dinilai adalah ringkasan.)
            cited_red = 1 if whole_cited == "merah" else -1
        else:
            cited_red = sum(1 for n in reds if "nama uji yang dikutip ada" in n)
        marker_red = sum(1 for n in reds if "penanda sementara:" in n)
        got = {"cited_red": cited_red, "marker_red": marker_red}
        wrong = []
        if expected["cited_red"]:
            if whole_cited != "merah" or cited_red != expected["cited_red"]:
                wrong.append(f"kutipan: {expected['cited_red']} baris merah, "
                             f"dapat {cited_red} (ringkasan {whole_cited})")
        elif whole_cited != "hijau" or cited_red:
            wrong.append(f"kutipan harus hijau, dapat {cited_red} baris merah")
        if expected["marker_red"]:
            if whole_markers != "merah" or marker_red != expected["marker_red"]:
                wrong.append(f"penanda: {expected['marker_red']} baris merah, "
                             f"dapat {marker_red} (ringkasan {whole_markers})")
        elif whole_markers != "hijau" or marker_red:
            wrong.append(f"penanda harus hijau, dapat {marker_red} baris merah")
        if wrong:
            for item in wrong:
                failures.append(f"{state}: {item}")
                print(f"{state}: {item}")
        else:
            print(f"{state}: sesuai harapan ({got})")

    shutil.rmtree(work, ignore_errors=True)
    print()
    if failures:
        print(f"GAGAL ({len(failures)}):")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"OK: {len(states)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
