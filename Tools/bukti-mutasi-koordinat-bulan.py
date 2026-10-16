#!/usr/bin/env python3
"""Buktikan uji **koordinat Bulan dari efemeris** berbunyi — dan bahwa ia
tidak bisa hijau karena kebetulan.

Kenapa harness ini ada.

`testMoonCataloguePositionIsNotItsCurrentPosition` (`MoonDaylightHonestyTests`)
mengunci satu asumsi struktural yang menopang **seluruh** jalur benda tata
surya: posisinya datang dari `EphemerisSample` (apparent of-date), bukan dari
`raDeg`/`decDeg` tetap yang menempel pada `CelestialObject`.

Bentuk cacat yang dijaga. `PointingResolver.consider` menerima sebuah objek
dan sebuah posisi horizontal. Untuk bintang, pemanggilnya meneruskan pasangan
(objek katalog, posisi hasil presesi J2000). Untuk benda tata surya,
pasangannya (objek hasil `catalogueObject(for:sample:)`, posisi dari
`sample`). Kedua cabang itu **terlihat identik** di layar kode — itulah
kenapa cacat ini berbahaya: satu argumen tertukar tidak mengubah bentuk apa
pun, tidak menghasilkan peringatan compiler, dan tidak menyentuh satu pun
dari empat uji kejujuran Bulan yang sudah ada (`testMoonDaytimeNeverLocks`,
`testMoonDaytimeRefusalIsHonest`, `testMoonAtNightIsNotRejectedForDaylight`,
`testMoonBelowHorizonNeverLocks`) — terukur di harness ini, lihat keadaan 1.

Kenapa uji Swift lain tidak bisa menggantikannya. Seluruh tes kejujuran di
repo ini menguji **penolakan** ("tidak boleh lock"). Yang diuji di sini
adalah **posisinya**. Benda bisa benar ditolak, dan tetap dihitung dari
tempat yang salah.

Apa yang diukur harness ini.

**Empat keadaan**, dan dua di antaranya menutup arah yang berbeda:

  keadaan                                                       harapan
  [baseline] sumber bersih                                      HIJAU 5/5
  1. resolver: posisi benda tata surya dipaku koordinat tetap    MERAH 1/5
     (cacat aslinya; empat uji Bulan lain tetap hijau)
  2. resolver: koordinat tetap DIAM, efemeris yang bergerak      HIJAU 5/5
     (kontrol negatif — bukan koordinat tetapnya yang dibenci)
  3. uji: fixture malam dipindah ke siang                        MERAH 1/5
     (kontrol kecukupan fixture)

Keadaan 1 dan 2 dipisah karena arahnya berlawanan, dan itu bukan kerapian.
Keadaan 2 mengubah medan `raDeg`/`decDeg` yang **tetap** justru tidak
mengubah apa pun di mesin: satu-satunya jalur yang bisa menggagalkan uji itu
adalah jalur yang benar-benar **dipakai**, bukan jalur yang kebetulan ada.
Tanpa keadaan 2, "hijau" pada keadaan baseline tidak membedakan uji yang
mengukur perilaku mesin dari uji yang mengukur salinan teks.

Keadaan 3 menjaga **kecukupan fixture**, arah yang tidak dijaga keadaan 1.
Kalau fixture-nya bukan malam lagi, uji berhenti menguji apa pun yang berarti
tentang mesin: yang tersisa hanyalah perbandingan dua angka yang tidak pernah
bertemu mesin. Keadaan 3 membuktikan uji itu sendiri yang berbunyi.

**Dua tebakan untuk keadaan 3 terukur salah dan diperbaiki di harapannya,
bukan dengan melonggarkan ujinya.** (a) `epoch.addingTimeInterval(0)` disangka
fixture malam "pertama"; terukur bukan — fixture malam pertama baru muncul
pada hari ke-8 pukul 07.0 (epok sendiri justru siang, Matahari 75°). (b)
Menaikkan penjaga `30` → `88` terukur hijau, karena Bulan memang melewati 88°
dalam 120 hari. Pelajarannya sama dengan `bukti-mutasi-kasus-planet.py`:
tebakan tentang keadaan yang belum pernah dijalankan adalah tebakan.

### Kelemahan yang diakui

  - Harness ini menjalankan **uji Swift**, bukan gerbang Python. Berkas yang
    dimutasi adalah sumber produksi (`PointingResolver.swift`) dan berkas uji
    (`MoonDaylightHonestyTests.swift`); keduanya dipulihkan di `finally` per
    keadaan plus handler `SIGINT`/`SIGTERM`, dan `require_clean_sources`
    menolak jalan bila salah satunya sudah menyimpang dari HEAD.
  - Ia **tidak** membuktikan bahwa `Catalogue.brightStars` bebas dari koordinat
    tetap yang salah; ia membuktikan bahwa jalur benda tata surya tidak
    bergantung padanya.
  - Ambang 10° di uji itu sengaja renggang (lihat docstring ujinya). Harness
    ini membuktikan ujinya berbunyi pada cacat berukuran puluhan derajat,
    bukan bahwa ujinya peka pada penggeseran satu derajat — dan itu memang
    bukan yang dijaganya.

Berkas produksi dimutasi lalu dipulihkan:
    Packages/CelestialEngine/Sources/CelestialEngine/PointingResolver.swift
    Packages/PointingKit/Tests/PointingKitTests/MoonDaylightHonestyTests.swift

Pakai:
    python3 Tools/bukti-mutasi-koordinat-bulan.py     # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

RESOLVER = os.path.join(ROOT, "Packages/CelestialEngine/Sources/CelestialEngine/"
                              "PointingResolver.swift")
TESTS = os.path.join(ROOT, "Packages/PointingKit/Tests/PointingKitTests/"
                           "MoonDaylightHonestyTests.swift")
FILES = [RESOLVER, TESTS]

SUITE = "MoonDaylightHonestyTests"
CASE = "testMoonCataloguePositionIsNotItsCurrentPosition"

# ── Jangkar: jalur yang benar-benar dipakai benda tata surya ─────────────
# Jangkar ini adalah **badan** baris pemanggilan `consider` untuk benda tata
# surya. Yang disuntikkan keadaan 1 adalah kebalikannya: posisi benda diambil
# dari koordinat tetap, bukan dari `sample`. Ia harus persis satu kemunculan —
# kalau tidak, harness berhenti dengan KELEMAHAN BUKTI (bukan lulus).
EFEMERIS_POSITION = """                    let horizontal = SkyMath.equatorialToHorizontal(
                        EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
                        observer: observer, jd: jd
                    )
"""
FIXED_POSITION = """                    let horizontal = SkyMath.equatorialToHorizontal(
                        SkyMath.precessJ2000ToDate(
                            EquatorialCoord(raDeg: 218.0, decDeg: -19.0), jd: jd),
                        observer: observer, jd: jd
                    )
"""

#: Keadaan 2: koordinat tetap itu **tidak diubah**, yang berubah adalah
#: sampel efemerisnya sendiri. Kalau uji hijau di sini — padahal angka tetap
#: di berkas uji tidak bergerak — maka yang diukur uji adalah perilaku mesin,
#: bukan kesamaan teks. Ini satu-satunya keadaan yang membedakan keduanya.
MOON_RA = "raDeg: 218.0, decDeg: -19.0"
MOON_RA_NEW = "raDeg: 218.7, decDeg: -18.4"

# ── Jangkar: fixture uji (kontrol kecukupan) ─────────────────────────────
#: Keadaan 3: fixture dipindah ke **siang hari**, sehingga "fixture malam"
#: tidak lagi malam dan penjaga ketat di uji itu berbunyi.
#:
#: **Dua tebakan pertama untuk keadaan ini terukur SALAH, dan keduanya
#: dicatat di sini karena itu bagian dari buktinya.**
#:
#:  1. `epoch.addingTimeInterval(0)` — disangka sama dengan fixture malam
#:     "pertama". Terukur **salah**: `moonNightFixture()` baru menemukan
#:     Bulan di atas 30° saat gelap pada hari ke-8 pukul 07.0 (199 jam
#:     sesudah epok), bukan pada epok. Epok sendiri (15 Jan 2026 12:00 WIB)
#:     justru **siang** (`isDark == false`, Matahari 75°) — dan itulah jam
#:     pertama yang ditemukan `moonDaytimeFixture()`.
#:  2. Naikkan penjaga `30` → `88`. Terukur hijau: dalam 120 hari Bulan
#:     memang melewati 88°, jadi fixture-nya masih sah. Yang tidak dibuktikan
#:     apa pun adalah keadaan yang tidak mengubah berkas, sekalipun ia hijau.
#:
#: Yang dipakai sekarang benar-benar mengubah perilaku uji: fixture siang
#: dipakai di tempat yang menuntut fixture malam. Bulan di sana punya
#: altitudin 42,6° (bukan 37,7°), dan penjaga `> 30` tetap lolos — jadi
#: yang berbunyi di keadaan ini **bukan** penjaga itu, melainkan bagian
#: berikutnya yang menuntut langit gelap. Itu dinyatakan di sini alih-alih
#: disangka.
NIGHT_SCAN = """        // Prasyarat fixture: Bulan tinggi saat langit gelap. Kalau tidak ada,
        // tes ini tidak menguji apa pun dan harus gagal keras.
        let when = try XCTUnwrap(moonNightFixture(),
                                 "tidak ada saat Bulan di atas 30° saat malam dalam 120 hari")"""

NIGHT_SCAN_LOW = """        // Prasyarat fixture: Bulan tinggi saat langit gelap. Kalau tidak ada,
        // tes ini tidak menguji apa pun dan harus gagal keras.
        let when = try XCTUnwrap(epoch.addingTimeInterval(8 * 86400 + 7 * 3600),
                                 "tidak ada saat Bulan di atas 30° saat siang dalam 120 hari")"""

PROBE = r"""
import os, subprocess, sys

root = sys.argv[1]
result = subprocess.run(
    ["sudo", "-n", "docker", "run", "--rm", "-v", root + ":/src",
     "-w", "/src/Packages/PointingKit", "swift:6.0",
     "swift", "test", "--filter", sys.argv[2]],
    capture_output=True, text=True, timeout=1800)

out = result.stdout + result.stderr
emitted = False
for line in out.splitlines():
    if "Test Case '" in line and ("passed" in line or "failed" in line):
        emitted = True
        print("SWIFT|" + line.strip()[:200])
if not emitted:
    print("SWIFT|ERR tidak ada hasil uji yang terbaca")
    print(out[-2000:])
"""


def run_swift():
    """Jalankan suite di Docker. → daftar baris `Test Case '…' passed/failed`."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, SUITE],
                         capture_output=True, text=True, timeout=2400)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    # Baris `Test Case '<Suite>.<nama>' passed (…)` → nama uji saja.
    results = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line.startswith("SWIFT|Test Case '"):
            continue
        body = line[len("SWIFT|Test Case '"):]
        name, _, rest = body.partition("' ")
        verdict = "passed" if rest.startswith("passed") else "failed"
        results[name.split(".")[-1]] = verdict
    return results, None


def mutate(path, old, new):
    """Suntikkan `old` → `new`; satu kemunculan, atau hentikan harness."""
    text = open(path, encoding="utf-8").read()
    count = text.count(old)
    if count != 1:
        return (f"KELEMAHAN BUKTI: {os.path.basename(path)}: jangkar muncul "
                f"{count}x, butuh 1")
    text = text.replace(old, new)
    if new not in text:
        return "KELEMAHAN BUKTI: hasil suntikan tidak ditemukan"
    mutasi_sumber.write_source(path, text)
    return None


#: (nama, [(berkas, cari, ganti), …] atau None, {nama uji: harapan}, catatan)
STATES = [
    ("[baseline] sumber bersih", None, None, "semua hijau"),

    # Cacat aslinya, dan satu-satunya keadaan yang membuktikan ujinya berbunyi.
    # Terukur: tepat satu uji merah (`testMoonCataloguePositionIsNot…`),
    # empat uji Bulan lainnya **hijau** — bukti bahwa celahnya nyata dan tidak
    # tertutup uji mana pun yang sudah ada.
    ("1. resolver: posisi benda tata surya dipaku koordinat tetap",
     [(RESOLVER, EFEMERIS_POSITION, FIXED_POSITION)],
     {CASE: "failed", "testMoonDaytimeNeverLocks": "passed",
      "testMoonDaytimeRefusalIsHonest": "passed",
      "testMoonAtNightIsNotRejectedForDaylight": "passed",
      "testMoonBelowHorizonNeverLocks": "passed"},
     "ujinya berbunyi; empat uji Bulan lain tetap hijau"),

    # Kontrol negatif: bukan koordinat tetapnya yang dibenci, melainkan
    # **dipakainya**. Di sini koordinat tetap di uji justru digeser, dan
    # perilaku mesin tidak berubah — jadi harapannya hijau.
    ("2. resolver: koordinat tetap digeser (kontrol negatif)",
     [(TESTS, MOON_RA, MOON_RA_NEW)],
     None,
     "menggeser angka tetap di uji tidak mengubah apa pun di mesin"),

    # Kontrol kecukupan fixture: kalau Bulan tidak lagi tinggi di fixture,
    # penjaga 30° di uji itu satu-satunya yang melihatnya.
    ("3. uji: fixture malam dipindah ke siang (penjaga fixture)",
     [(TESTS, NIGHT_SCAN, NIGHT_SCAN_LOW)],
     {CASE: "failed"},
     "uji menolak run bila fixture-nya bukan malam"),
]


def main():
    mutasi_sumber.require_clean_sources(FILES)
    originals = {path: open(path, "rb").read() for path in FILES}
    baseline_md5 = {path: hashlib.md5(data).hexdigest()
                    for path, data in originals.items()}
    failures = []

    def restore():
        for path, data in originals.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected, note in STATES:
            restore()
            problems = []
            results = None
            if edits is not None:
                for path, find, replace in edits:
                    problem = mutate(path, find, replace)
                    if problem:
                        problems.append(problem)
                        break
            if not problems:
                results, error = run_swift()
                if results is None:
                    problems.append(f"suite tidak bisa dijalankan: {error}")
                elif not results:
                    problems.append("suite tidak melaporkan satu hasil pun; "
                                    "himpunan kosong selalu 'sesuai harapan'")
                else:
                    if expected is None:
                        wrong = [n for n, v in results.items() if v != "passed"]
                        if wrong:
                            problems.append("verdict salah: " +
                                            ", ".join(f"{n} failed" for n in wrong))
                    else:
                        # Himpunan hasil dibandingkan persis: uji yang hilang
                        # (suite berhenti lebih awal) harus merah, bukan lulus.
                        missing = sorted(set(expected) - set(results))
                        if missing:
                            problems.append(f"hasil hilang: {missing}")
                        wrong = [f"{n} diharapkan {w} terukur {results[n]}"
                                 for n, w in expected.items()
                                 if n in results and results[n] != w]
                        if wrong:
                            problems.append("verdict salah: " + "; ".join(wrong))
            if problems:
                failures.append(f"{name}: " + " | ".join(problems))
                print(f"{name}: TIDAK SESUAI HARAPAN")
                for item in problems:
                    print(f"    {item}")
            else:
                n = len(results) if results else 0
                merah = sum(1 for v in (results or {}).values() if v != "passed")
                print(f"{name}: sesuai harapan "
                      f"({merah} merah dari {n} uji; {note})")
    finally:
        restore()

    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        rel = os.path.relpath(path, ROOT)
        print(f"md5 {rel}: {digest} -> {after} "
              f"({'pulih persis' if after == digest else 'TIDAK PULIH'})")
        if after != digest:
            failures.append(f"sumber tidak pulih persis: {path}")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
