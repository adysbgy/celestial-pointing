#!/usr/bin/env python3
"""Buktikan gerbang **nama uji yang dikutip produksi** berbunyi.

Kenapa harness ini ada.

`check_cited_test_names_exist` adalah gerbang yang lahir dari pengukuran:
`Tools/ukur-uji-menggantung.py` menemukan **3 dari 43** nama uji yang dikutip
sumber produksi tidak punya definisi (`testCraterRimIsBrighterThanItsFloor`,
`testJupiterSpotIsInTheSouthernHemisphere`,
`testSunCoronaReachesBeyondTheDisk`). Ketiganya sudah diperbaiki, jadi
gerbangnya **hijau** sekarang — dan gerbang yang hijau tanpa satu pun keadaan
rusak yang pernah dijalankan terhadapnya adalah gerbang yang tidak
membuktikan apa pun. Berkas ini yang menjalankan keadaan rusaknya.

### Tiga arah, dan kenapa ketiganya perlu

Gerbang ini membaca **dua** himpunan (kutipan di sumber produksi, definisi di
berkas uji) dan menyimpulkan dari keduanya. Setiap himpunan bisa berhenti
terbaca sendiri-sendiri, dan tiap cara gagal terlihat sama di layar: hijau.

    [baseline]                              hijau, 1 pemeriksaan
    1. uji yang dikutip DIGANTI NAMA        MERAH (kutipannya menggantung)
    2. kutipan baru yang tidak ada ujinya   MERAH (kutipannya menggantung)
    3. pembaca kutipan berhenti cocok       MERAH (fail-closed, 0 kutipan)

Keadaan 3 adalah yang paling penting dari ketiganya, dan alasannya terukur:
gerbang yang bergantung pada pola teks bisa **berhenti mengukur tanpa
memberi tahu**. Kalau polanya tidak lagi cocok dengan berkasnya, himpunan
kutipannya kosong, tidak ada yang menggantung, dan gerbangnya hijau — hijau
karena tidak ada yang diperiksa. Karena itu gerbangnya **fail-closed**:
nol kutipan = merah. Keadaan 3 membuktikan cabang itu benar-benar ada dan
benar-benar berbunyi, bukan sekadar ditulis di docstring.

### Yang TIDAK diklaim

- Yang diuji adalah gerbang **statis** ini: nama yang ada vs nama yang
  dikutip. Ia tidak membuktikan uji yang ada itu **mengukur** hal yang
  diklaim komentarnya — uji hampa (`XCTAssertTrue(true)`) lolos di sini.
- Keadaan 1 mengganti nama uji di berkas uji, bukan di sumber produksi. Itu
  disengaja: ia meniru **uji yang dinamai ulang** sementara kutipannya
  tertinggal — arah yang paling mungkin terjadi di repo ini, dan yang tidak
  bisa ditangkap gerbang mana pun yang hanya membaca satu sisi.

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus
handler `SIGINT`/`SIGTERM`. `require_clean_sources` menolak jalan bila
berkas produksi sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-uji-menggantung.py   # 0 = sesuai harapan
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

CHECKS = os.path.join(ROOT, "Tools", "check-visuals.py")
NIGHT = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit",
                             "NightVisual.swift")
TESTS = os.path.join(ROOT, "Packages/PointingKit/Tests/PointingKitTests",
                             "NightVisualTests.swift")

HIJAU = "hijau"
MERAH = "merah"

#: Nama pemeriksaan yang ditulis gerbang. Dipakai sebagai kunci harapan, jadi
#: kehadirannya di keluaran probe **adalah** bukti bahwa gerbangnya benar-benar
#: dijalankan dan mengisi results.
GERBANG = "uji yang dikutip produksi ada"

# ── Jangkar ──────────────────────────────────────────────────────────────
# Semuanya unik di berkasnya (diperiksa sebelum memutasi).

# 1. Definisi uji yang dikutip produksi, diganti nama. Kutipannya di
#    `NightVisual.swift` menunjuk nama lama, jadi ia menggantung.
UJI_DEFINISI = "    func testCraterRimIsBrighterThanItsFloor() {\n"
UJI_NAMA_BARU = "    func testCraterRimIsBrighterThanItsFloorRenamed() {\n"

# 2. Kutipan baru di sumber produksi untuk uji yang tidak ada. Ditulis di
#    komentar `NightVisual.swift`, tempat yang sama dengan tiga cacat aslinya.
KUTIPAN_BAIK = ("        /// `testCraterRimIsBrighterThanItsFloor` supaya tidak bisa diam-diam\n")
KUTIPAN_BURUK = ("        /// `testCraterRimIsBrighterThanItsFloor` dan\n"
                 "        /// `testRimOrderIsCheckedSomewhereElse` supaya tidak bisa diam-diam\n")

# 3. Pembaca kutipan dibuat tidak cocok lagi dengan bentuk berkasnya: pola
#    namanya diubah supaya tidak pernah cocok. Gerbang harus **merah** karena
#    nol kutipan, bukan hijau karena tidak ada yang menggantung.
POLA_KUTIPAN = r'''        for match in re.finditer(r"\btest[A-Z][A-Za-z0-9_]*", source):'''
POLA_RUSAK = r'''        for match in re.finditer(r"\btestNOMATCHATALL[A-Z][A-Za-z0-9_]*", source):'''

PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "cv_probe", os.path.join(sys.argv[1], "Tools", "check-visuals.py"))
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)

results = []
try:
    C.check_cited_test_names_exist(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline] berkas bersih", None, {GERBANG: HIJAU}),

    # 1. Uji dinamai ulang, kutipannya tertinggal. Ini arah yang paling
    #    mungkin terjadi pada repo ini — dan satu-satunya keadaan yang
    #    membuktikan gerbangnya membaca **definisi** uji, bukan hanya
    #    mengumpulkan nama yang disebut di suatu tempat.
    ("1. uji yang dikutip diganti nama di berkas uji",
     [(TESTS, UJI_DEFINISI, UJI_NAMA_BARU)],
     {GERBANG: MERAH}),

    # 2. Kutipan baru untuk uji yang tidak pernah ada. Membuktikan arah
    #    sebaliknya: membaca **kutipan** di sumber produksi. Keadaan 1 dan 2
    #    harus berbunyi masing-masing; kalau salah satunya hijau, berarti
    #    gerbangnya hanya membaca satu sisi.
    ("2. kutipan baru tanpa ujinya di sumber produksi",
     [(NIGHT, KUTIPAN_BAIK, KUTIPAN_BURUK)],
     {GERBANG: MERAH}),

    # 3. Fail-closed. Pola pembaca kutipan dibuat tidak cocok; kalau gerbangnya
    #    hijau di sini, ia hijau karena tidak mengukur apa pun — dan seluruh
    #    pemeriksaan di atasnya jadi tidak berarti.
    ("3. pembaca kutipan berhenti cocok (fail-closed)",
     [(CHECKS, POLA_KUTIPAN, POLA_RUSAK)],
     {GERBANG: MERAH}),
]


def run_probe():
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    return out.stdout, None


def classify(stdout):
    verdicts = {}
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        state, _, name = stripped.partition(" ")
        name = name.strip()
        # Nama pemeriksaan per-temuan memuat lokasi (`…: path:line`), jadi
        # hanya nama **ringkasnya** yang dipakai sebagai kunci harapan.
        if state in ("OK", "GAGAL"):
            verdicts[name] = "hijau" if state == "OK" else "merah"
            base = name.split(":")[0].strip()
            verdicts.setdefault(base, verdicts[name])
    return verdicts


def main():
    files = [CHECKS, NIGHT, TESTS]
    mutasi_sumber.require_clean_sources(files)
    originals = {path: open(path, "rb").read() for path in files}
    baseline_md5 = {path: hashlib.md5(data).hexdigest()
                    for path, data in originals.items()}
    failures = []

    def restore():
        for path, data in originals.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected in STATES:
            restore()
            if edits is not None:
                pending = {}
                for path, find, replace in edits:
                    content = pending.get(path, originals[path].decode())
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: "
                            f"{find[:70]!r}")
                        break
                    pending[path] = content.replace(find, replace)
                else:
                    for path, content in pending.items():
                        mutasi_sumber.write_source(path, content)

            stdout, error = run_probe()
            if stdout is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            verdicts = classify(stdout)
            wrong = [(check, want, verdicts.get(check, "TIDAK ADA"))
                     for check, want in expected.items()
                     if verdicts.get(check, "TIDAK ADA") != want]

            # Gerbang yang mengisi 0 results tidak boleh terbaca hijau.
            if not verdicts:
                failures.append(f"{name}: gerbang mengisi 0 results")

            if wrong:
                for check, want, got in wrong:
                    failures.append(
                        f"{name}: {check} diharapkan {want}, terukur {got}")
                print(f"{name}: TIDAK SESUAI HARAPAN")
                for check, want, got in wrong:
                    print(f"    {check}\n      diharapkan {want}, "
                          f"terukur {got}")
            else:
                red = sum(1 for v in verdicts.values() if v == "merah")
                print(f"{name}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} pemeriksaan)")
    finally:
        restore()

    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        print(f"\nmd5 {os.path.relpath(path, ROOT)}: {digest} -> {after} "
              f"({'pulih persis' if after == digest else 'TIDAK PULIH'})")
        if after != digest:
            failures.append(f"sumber produksi tidak pulih persis: {path}")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
