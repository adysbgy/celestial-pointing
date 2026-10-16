#!/usr/bin/env python3
"""Buktikan gerbang **berkas alat yang dirujuk** berbunyi.

Kenapa harness ini ada.

`check_cited_tool_files_exist` lahir dari pengukuran: membandingkan setiap
jalur `Tools/…` yang dirujuk sumber terhadap isi `Tools/` menemukan **satu**
alamat yang kosong — `Tools/ukur-gugus.py`, dikutip di empat tempat, termasuk
satu di sumber produksi. Keempatnya sudah diperbaiki, jadi gerbangnya **hijau**
sekarang. Gerbang yang hijau tanpa satu pun keadaan rusak yang pernah
dijalankan terhadapnya tidak membuktikan apa pun; berkas ini yang menjalankan
keadaan rusaknya.

### Tiga arah, dan kenapa ketiganya perlu

Gerbang ini membaca **dua** himpunan (rujukan `Tools/…` di sumber produksi,
isi direktori `Tools/`) dan menyimpulkan dari keduanya. Setiap himpunan bisa
berhenti terbaca sendiri-sendiri, dan tiap cara gagal terlihat sama di layar:
hijau.

    [baseline]                              hijau, 1 pemeriksaan
    1. rujukan ke berkas alat yang tidak ada  MERAH
    2. rujukan ditulis tanpa jalur `Tools/`   hijau (batas cakupan)
    3. pembaca rujukan berhenti cocok         MERAH (fail-closed, 0 rujukan)

Keadaan 3 yang paling penting, dan alasannya terukur: gerbang yang bergantung
pada pola teks bisa **berhenti mengukur tanpa memberi tahu**. Kalau polanya
tidak lagi cocok dengan berkasnya, himpunan rujukannya kosong, tidak ada yang
menggantung, dan gerbangnya hijau — hijau karena tidak ada yang diperiksa.
Karena itu gerbangnya **fail-closed**: nol rujukan = merah. Keadaan 3
membuktikan cabang itu benar-benar ada dan benar-benar berbunyi.

Keadaan 2 adalah **batas yang dinyatakan**, dan ia harus hijau. Gerbang ini
hanya menghitung rujukan berbentuk jalur (`Tools/berkas.py`), bukan
penyebutan nama berkas tanpa jalur — kalimat seperti "ukur-gugus" di dalam
prosa bisa berarti banyak hal, sementara jalur adalah alamat. Menuntut
keduanya akan menuduh prosa biasa. Keadaan ini menjaga agar batas itu tidak
diam-diam berubah menjadi lebih ketat tanpa ada yang memutuskan.

### Yang TIDAK diklaim

- Yang diuji adalah gerbang **statis** ini: alamatnya menunjuk sesuatu.
  Berkas alat yang **ada** tetapi angkanya sudah kedaluwarsa lolos di sini —
  memeriksa itu menuntut menjalankan alatnya, dan beberapa di antaranya
  memakan puluhan menit.
- Cakupan gerbangnya hanya sumber produksi (`Packages/*/Sources`, `Apps/`),
  bukan `Tools/` atau alur kerja. Situs di sana sudah diperbaiki tetapi tidak
  ditegakkan — alasannya di `_cited_tool_files`. Keadaan 1 karena itu menanam
  cacatnya di sumber produksi, tempat cakupan itu memang berlaku.

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus
handler `SIGINT`/`SIGTERM`. `require_clean_sources` menolak jalan bila
berkas produksi sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-tool-dirujuk.py   # 0 = sesuai harapan
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
MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit",
                            "CelestialVisual.swift")

HIJAU = "hijau"
MERAH = "merah"

#: Nama pemeriksaan ringkas yang ditulis gerbang. Kehadirannya di keluaran
#: probe **adalah** bukti bahwa gerbangnya benar-benar dijalankan dan mengisi
#: results — gerbang yang mengisi 0 results tidak boleh terbaca hijau.
GERBANG = "berkas alat yang dirujuk ada"

# ── Jangkar ──────────────────────────────────────────────────────────────
# Semuanya unik di berkasnya (diperiksa sebelum memutasi).

# 1. Rujukan yang **sudah diperbaiki** dikembalikan ke alamat kosongnya.
#    Inilah cacat aslinya, persis seperti yang ditemukan pengukuran.
RUJUKAN_BAIK = "    /// (`Tools/bukti-mutasi-inti-opasitas.py`): mengganti literal di **view**\n"
RUJUKAN_BURUK = "    /// (`Tools/ukur-gugus.py`): mengganti literal di **view**\n"

# 2. Rujukan yang sama ditulis **tanpa jalur** `Tools/`. Gerbangnya harus tetap
#    hijau: yang diperiksa adalah alamat, bukan setiap penyebutan nama.
RUJUKAN_TANPA_JALUR = "    /// (`bukti-mutasi-inti-opasitas.py`): mengganti literal di **view**\n"

# 3. Pembaca rujukan dibuat tidak cocok lagi dengan bentuk berkasnya: pola
#    jalurnya diubah supaya tidak pernah cocok. Gerbang harus **merah** karena
#    nol rujukan, bukan hijau karena tidak ada yang menggantung.
POLA_JALUR = r'''        for match in re.finditer(r"Tools/([A-Za-z0-9_\-]+\.(?:py|sh))", source):'''
POLA_RUSAK = r'''        for match in re.finditer(r"Tools/NOMATCHATALL([A-Za-z0-9_\-]+\.(?:py|sh))", source):'''

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
    C.check_cited_tool_files_exist(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline] berkas bersih", None, {GERBANG: HIJAU}),

    # 1. Cacat aslinya dikembalikan: rujukan ke berkas alat yang tidak ada.
    #    Inilah satu-satunya keadaan yang membuktikan gerbangnya membaca
    #    **alamat** dan memeriksa keberadaannya.
    ("1. rujukan ke berkas alat yang tidak ada",
     [(MODEL, RUJUKAN_BAIK, RUJUKAN_BURUK)],
     {GERBANG: MERAH}),

    # 2. Batas cakupan yang dinyatakan: nama berkas tanpa jalur `Tools/` tidak
    #    dihitung. Wajib **hijau** — kalau gerbangnya memerah di sini, ia
    #    menuduh prosa biasa, dan orang akan melonggarkannya.
    ("2. nama alat tanpa jalur Tools/ tidak dihitung (batas)",
     [(MODEL, RUJUKAN_BAIK, RUJUKAN_TANPA_JALUR)],
     {GERBANG: HIJAU}),

    # 3. Fail-closed. Pola pembaca rujukan dibuat tidak cocok; kalau gerbangnya
    #    hijau di sini, ia hijau karena tidak mengukur apa pun — dan seluruh
    #    pemeriksaan di atasnya jadi tidak berarti.
    ("3. pembaca rujukan berhenti cocok (fail-closed)",
     [(CHECKS, POLA_JALUR, POLA_RUSAK)],
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
    files = [CHECKS, MODEL]
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
