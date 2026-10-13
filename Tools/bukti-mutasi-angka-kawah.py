#!/usr/bin/env python3
"""Buktikan gerbang **angka kontras kawah keluar dari penyampelnya** berbunyi.

Kenapa harness ini ada.

`check_crater_contrast_numbers_come_from_the_sampler` adalah satu dari
**7 gerbang tersisa** di `check-visuals.py` yang tidak dirujuk satu pun
harness `bukti-mutasi-*` — gerbang yang belum pernah dijalankan dalam
keadaan rusak, dan karena itu tidak bisa dibedakan dari gerbang yang tidak
mengukur apa pun. Itu persis kelas cacat yang seluruh repo ini kejar, dan di
sini ia hidup di **dalam** perangkat pengawasnya sendiri.

Yang membuatnya layak dipilih lebih dulu: gerbang ini menjaga **satu-satunya
bukti yang dibaca orang** saat menilai apakah gerbang kontras kawah layak
dipercaya, yaitu angka di docstring-nya. Docstring itu pernah mengutip
empat rentang yang **tidak satu pun keluar dari penyampelnya** — `−5,1`
menyatakan hampir tidak ada dinding terang yang hilang, padahal seluruh lima
kawah menjadi lebih gelap dari permukaannya. Angka yang salah di komentar
bukan sekadar salah ketik: komentar itu argumen yang dipakai untuk
mempertahankan gerbangnya.

### Yang diukur harness ini, bukan dikutip dari docstring

    [baseline]                                        hijau, 0 merah / 4
    1. sebelum/cahaya −27,7 -> −26,0                  MERAH 1: angka sebelum (cahaya)
    2. sesudah/bayangan −14,9 -> −15,5                MERAH 1: angka sesudah (bayangan)
    3. sisi sebelum/cahaya ditulis "bayangan"         MERAH 1: angka sebelum (cahaya)
    4. satu baris kutipan dihapus (4 -> 3)            MERAH 1 hasil saja: "empat rentang"
    5. kontrol negatif: prosa lain diubah             hijau penuh

Empat keadaan pertama tidak saling menggantikan:

  * **1 dan 2** mengubah **angka**, pada dua keadaan yang berbeda (sebelum &
    sesudah). Gerbang yang hanya memeriksa keadaan "sesudah" akan hijau di
    keadaan 1, karena angka "sebelum" adalah bagian dari argumen sejarahnya.
  * **3** mengubah **sisi**, bukan angkanya: rentangnya tetap benar, tetapi
    diklaim untuk dinding yang salah. Ini arah yang tidak bisa ditangkap oleh
    pemeriksaan yang hanya menghitung kemunculan pola.
  * **4** mengubah **bentuk** kutipannya: gerbangnya berhenti lebih awal dan
    melaporkan **satu** hasil, bukan empat. Harness menuntut himpunan hasilnya
    **persis**, jadi perbedaan himpunan itu sendiri menjadi bagian bukti —
    kalau kelak gerbangnya diubah untuk "melewati saja" keadaan bentuk rusak,
    keadaan 4 mulai tidak sesuai harapan.

Negatif kontrol (5) bukan hiasan: kalau harness merah di sana, ia merah
karena **berkasnya berubah**, bukan karena cacatnya, dan ia tidak mengukur
apa pun.

### Kenapa mutasinya di `check-visuals.py`, dan kenapa itu aman

Gerbang ini membaca `__doc__` milik `check_crater_floor_opacity_comes_from_the_model`,
jadi keadaan rusaknya hidup di **docstring gerbang lain di berkas yang sama**.
Tidak satu pun berkas di `Apps/` atau `Packages/` yang disentuh — jadi
harness ini tidak bisa bertabrakan dengan WIP siklus lain yang sedang
menyunting model visual di `Packages/`.

Konsekuensinya harus dinyatakan: yang dibuktikan di sini adalah bahwa
**docstring dan penyampel tidak boleh bercerai**, bukan bahwa geometri
kawahnya benar. Geometrinya dijaga `check_crater_floor_opacity_comes_from_the_model`
sendiri, yang mengukur piksel.

### Yang TIDAK diklaim

- Harness ini mengukur **teks docstring** lawan **hasil ukur penyampel**.
  Ia tidak membaca piksel app Apple, dan tidak membuktikan bahwa ukuran
  76 px adalah ukuran yang dipakai perangkat — itu klaim
  `WatchMetrics.visualDiameter`, dijaga gerbang lain.
- Keadaan "penyampel sendiri berubah" (mis. `crater_wall_contrast` diganti
  rumusnya) tidak diuji: di sana gerbang dan docstring akan sama-sama
  bergeser dan tetap hijau. Itu batas cakupan yang dibiarkan terbuka.
- **6 gerbang nirsaksi lainnya belum dikerjakan** (terukur: 7 -> 6).

Berkas produksi dimutasi lalu dipulihkan di `finally`, plus handler
`SIGINT`/`SIGTERM`. `require_clean_sources` menolak jalan bila berkas
produksi sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-angka-kawah.py   # 0 = sesuai harapan
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

CHECK = os.path.join(ROOT, "Tools", "check-visuals.py")

HIJAU = "hijau"
MERAH = "merah"

# ── Nama hasil di dalam gerbang ───────────────────────────────────────────
# Dituntut **persis**, supaya perubahan nama tidak terbaca sebagai "gerbangnya
# masih ada".
SEBELUM_CAHAYA = "kawah: angka sebelum (dinding cahaya) sama dengan hasil ukur"
SEBELUM_BAYANGAN = "kawah: angka sebelum (dinding bayangan) sama dengan hasil ukur"
SESUDAH_CAHAYA = "kawah: angka sesudah (dinding cahaya) sama dengan hasil ukur"
SESUDAH_BAYANGAN = "kawah: angka sesudah (dinding bayangan) sama dengan hasil ukur"
EMPAT_RENTANG = "kawah: docstring mengutip empat rentang kontras (sebelum & sesudah)"

SEMUA = [SEBELUM_CAHAYA, SEBELUM_BAYANGAN, SESUDAH_CAHAYA, SESUDAH_BAYANGAN]

# ── Jangkar ──────────────────────────────────────────────────────────────
# Diambil **apa adanya** dari docstring `check_crater_floor_opacity_comes_from_the_model`.
# Indentasinya 4 spasi (docstring, bukan tingkat berkas) dan tanda minusnya
# U+2212 — keduanya pernah membuat jangkar versi pertama muncul 0x, dan
# harness memeriksa jumlah kemunculan sebelum memutasi, jadi kegagalan itu
# dilaporkan sebagai kelemahan bukti, bukan dipakai diam-diam.
LIT_SEBELUM_CAHAYA = "    dinding sisi cahaya − permukaan   −46,6 … −27,7"
LIT_SESUDAH_BAYANGAN = "    dinding sisi bayangan − permukaan −35,6 … −14,9"
PROSA = "Kenapa dua sisi diperiksa."

# Dijalankan di proses baru: mengimpor ulang `check-visuals` dari berkas yang
# **sudah dimutasi** di disk. Mengimpor sekali di dalam proses ini akan
# memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))

path = os.path.join(sys.argv[1], "Tools", "check-visuals.py")
spec = importlib.util.spec_from_file_location("cv_probe", path)
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)

results = []
try:
    C.check_crater_contrast_numbers_come_from_the_sampler(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
    print("     " + r.detail)
"""

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama hasil: harapan})
STATES = [
    ("[baseline] berkas bersih", None,
     {name: HIJAU for name in SEMUA}),

    # ── 1. Angka keadaan "sebelum" digeser ────────────────────────────────
    # Batas atas dinding sisi cahaya sebelum perbaikan (−27,7) digeser 1,7
    # luminans. Ini keadaan yang gerbangnya **ada untuk** menangkap: angka
    # docstring yang tidak keluar dari penyampel. Kalau ia hijau di sini,
    # gerbangnya tidak menjaga apa pun.
    ("1. docstring: sebelum/cahaya −27,7 -> −26,0",
     [(CHECK, LIT_SEBELUM_CAHAYA,
       "    dinding sisi cahaya − permukaan   −46,6 … −26,0")],
     {SEBELUM_CAHAYA: MERAH, SEBELUM_BAYANGAN: HIJAU,
      SESUDAH_CAHAYA: HIJAU, SESUDAH_BAYANGAN: HIJAU}),

    # ── 2. Angka keadaan "sesudah" digeser ────────────────────────────────
    # Arah yang tidak bisa digantikan keadaan 1: rentang "sesudah" adalah
    # yang dipakai untuk membuktikan perbaikannya bekerja. Gerbang yang hanya
    # memeriksa keadaan "sebelum" akan hijau di sini.
    ("2. docstring: sesudah/bayangan −14,9 -> −15,5",
     [(CHECK, LIT_SESUDAH_BAYANGAN,
       "    dinding sisi bayangan − permukaan −35,6 … −15,5")],
     {SESUDAH_BAYANGAN: MERAH, SEBELUM_CAHAYA: HIJAU,
      SEBELUM_BAYANGAN: HIJAU, SESUDAH_CAHAYA: HIJAU}),

    # ── 3. Sisi tertukar, angkanya tetap benar ────────────────────────────
    # Rentangnya tidak diubah sama sekali; yang salah adalah **dinding mana**
    # yang diklaim. Pemeriksaan yang hanya menghitung kemunculan pola akan
    # lolos di sini, karena polanya tetap cocok empat kali.
    ("3. docstring: sisi sebelum/cahaya ditulis 'bayangan'",
     [(CHECK, LIT_SEBELUM_CAHAYA,
       "    dinding sisi bayangan − permukaan −46,6 … −27,7")],
     {SEBELUM_CAHAYA: MERAH, SEBELUM_BAYANGAN: HIJAU,
      SESUDAH_CAHAYA: HIJAU, SESUDAH_BAYANGAN: HIJAU}),

    # ── 4. Satu baris kutipan hilang ──────────────────────────────────────
    # Gerbangnya berhenti lebih awal dan melaporkan **satu** hasil, bukan
    # empat. Himpunan hasilnya karena itu berbeda, dan harness menuntutnya
    # persis: kalau kelak gerbangnya diubah untuk melewati saja keadaan
    # bentuk-rusak, keadaan ini mulai tidak sesuai harapan.
    ("4. docstring: satu baris kutipan dihapus (4 -> 3)",
     [(CHECK, LIT_SESUDAH_BAYANGAN, "")],
     {EMPAT_RENTANG: MERAH}),

    # ── 5. Kontrol negatif: prosa yang tidak dikutip ──────────────────────
    # Mengubah kalimat biasa di docstring yang sama. Harus tetap hijau penuh:
    # kalau harness merah di sini, ia merah karena berkasnya berubah, bukan
    # karena cacatnya, dan ia tidak mengukur apa pun.
    ("5. kontrol negatif: prosa lain diubah (bukan angka)",
     [(CHECK, PROSA, "Kenapa dua sisi diperiksa!")],
     {name: HIJAU for name in SEMUA}),
]


def run_probe():
    """Jalankan gerbang di proses baru. -> (stdout atau None, galat)."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    return out.stdout, None


def classify(stdout):
    """Petakan keluaran prob -> {nama hasil: hijau|merah}."""
    verdicts = {}
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("ERR"):
            continue
        state, _, name = stripped.partition(" ")
        name = name.strip()
        if state in ("OK", "GAGAL") and name:
            verdicts[name] = HIJAU if state == "OK" else MERAH
    return verdicts


def main():
    mutasi_sumber.require_clean_sources([CHECK])
    original = open(CHECK, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        mutasi_sumber.restore_verified(CHECK, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, want in STATES:
            restore()
            if edits is not None:
                pending = {}
                broken = False
                for path, find, replace in edits:
                    content = pending.get(path, original.decode())
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: "
                            f"{find[:70]!r}")
                        broken = True
                        break
                    pending[path] = content.replace(find, replace)
                if broken:
                    continue
                for path, content in pending.items():
                    mutasi_sumber.write_source(path, content)

            stdout, error = run_probe()
            if stdout is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            verdicts = classify(stdout)

            # Himpunan hasilnya dituntut **persis**: hasil yang hilang
            # (gerbang berhenti lebih awal) dan hasil yang muncul tiba-tiba
            # keduanya bagian dari bukti, bukan kebisingan.
            missing = sorted(set(want) - set(verdicts))
            if missing:
                failures.append(
                    f"{name}: hasil tidak dihasilkan gerbang: {missing}")

            wrong = {k: (verdicts.get(k, "TIDAK ADA"), v)
                     for k, v in want.items()
                     if verdicts.get(k, "TIDAK ADA") != v}
            if wrong:
                failures.append(f"{name}: tidak sesuai harapan: {wrong}")

            ok = not missing and not wrong
            detail = ""
            for line in stdout.splitlines():
                if line.startswith("     "):
                    detail = line.strip()
            print(f"{name}: "
                  + ("sesuai harapan" if ok else "TIDAK SESUAI HARAPAN")
                  + (f" ({detail})" if detail else ""))
    finally:
        restore()

    after = hashlib.md5(open(CHECK, "rb").read()).hexdigest()
    print(f"\nmd5 Tools/check-visuals.py: {baseline_md5} -> {after} "
          f"({'pulih persis' if after == baseline_md5 else 'TIDAK PULIH'})")
    if after != baseline_md5:
        failures.append("sumber produksi tidak pulih persis: "
                        "Tools/check-visuals.py")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
