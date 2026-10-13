#!/usr/bin/env python3
"""Buktikan gerbang **keterbacaan piringan bulan baru** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

`check_moon_new_disc_reads_on_the_watch` menutup cacat yang terukur dan
berbahaya: pada `moonEarthshine` 0.15 piringan bulan baru terukur **1.32:1**
terhadap latar kartu — secara efektif **kartu kosong** pada ukuran jam
(38 px). Gerbangnya punya ambang yang dikalibrasi (2.0:1) dan docstring yang
mengutip tiga angka sapuan (0.30 → 2.39:1, 0.24 → 1.85:1, 0.15 → 1.32:1).

Tetapi sampai siklus ini **tidak ada satu pun harness** yang membuktikan
gerbang itu bisa merah. Dari 83 gerbang di `check-visuals.py`, 18 tidak
dirujuk harness mana pun — dan gerbang yang belum pernah merah tidak bisa
dibedakan dari gerbang yang tidak mengukur apa pun. Itu persis kelas cacat
yang seluruh repo ini kejar, dan di sini ia hidup di **dalam** perangkat
pengawasnya sendiri.

Yang diukur harness ini, bukan dikutip dari docstring:

    [baseline]                          hijau, 2.39:1
    1. port 0.30 -> 0.15 (cacat asli)   MERAH 1.33:1
    2. port 0.30 -> 0.24 (batas bawah)  MERAH 1.86:1
    3. port 0.30 -> 0.45 (dinaikkan)    hijau 4.25:1   <- kontrol negatif
    4. ukuran 76 px (bukan 38)          hijau          <- kontrol ukuran

Keadaan 3 dan 4 sengaja **diharapkan hijau**, dan keduanya bukan hiasan:

  * Keadaan 3 membuktikan gerbangnya mengukur **arah dan besaran**, bukan
    sekadar "ada piringan". Gerbang yang memerah saat nilainya dinaikkan
    akan dilonggarkan orang, dan gerbang yang dilonggarkan tidak menjaga
    apa pun. Tanpanya, "merah di 0.15" bisa saja berarti "merah pada setiap
    perubahan", yang tidak mengukur keterbacaan sama sekali.
  * Keadaan 4 membuktikan gerbangnya masih hijau pada ukuran yang dipakai
    render lebih besar — cacat keterbacaan yang hanya ada di 38 px tidak
    akan ketahuan di 76 px, dan sebaliknya gerbang yang hanya lulus di satu
    ukuran tidak bisa diklaim menjaga "ukuran jam".

### Yang TIDAK diklaim, dan diukur untuk membuktikannya

Gerbang ini mengukur **gambar port Python** (`render-visuals.py`), bukan
view Swift. Jadi arah yang paling mungkin terjadi di repo dua bahasa ini —
**model Swift berubah, port tidak ikut** — masih **tidak** ditangkap oleh
gerbang ini. Terukur pada keadaan 5:

    5. model Swift 0.30 -> 0.15, port tetap    gerbang tetap HIJAU (2.39:1)

Keadaan 5 ada justru supaya batas itu **tercatat dan teruji**, bukan
tersangka. Kalau kelak ada gerbang yang mengikat model ke port untuk token
ini, keadaan 5 akan mulai tidak sesuai harapan — dan itu tanda bahwa
cakupannya sudah meluas, bukan bahwa harnessnya rusak. Menulis keadaan 5
sebagai "hijau" bukan pembiaran: yang membedakan pembiaran dari batas yang
dinyatakan adalah bahwa batasnya **dijalankan**.

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus
handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally` dan meninggalkan
mutasi hidup. Penulisan & pemulihan lewat `mutasi_sumber`, sama seperti
harness lain — dan `require_clean_sources` menolak jalan bila berkas
produksi sudah menyimpang dari HEAD (yang di VPS ini berarti mutasi WIP
siklus lain tidak akan diam-diam diadopsi sebagai "aslinya").

Pakai:
    python3 Tools/bukti-mutasi-piringan-bulan-baru.py   # 0 = sesuai harapan
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

RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                           "NightVisual.swift")

GATE = "check_moon_new_disc_reads_on_the_watch"
#: Nama hasil di dalam gerbang — dituntut **persis**, supaya perubahan nama
#: tidak terbaca sebagai "gerbangnya masih ada".
RESULT = "bulan baru terbaca di ukuran jam (kontras >= 2.0:1)"

HIJAU = "hijau"
MERAH = "merah"

# ── Jangkar ──────────────────────────────────────────────────────────────
# Keduanya unik di berkasnya (terukur); harness memeriksa jumlah kemunculan
# sebelum memutasi, jadi jangkar yang menjadi ambigu dilaporkan sebagai
# kelemahan bukti, bukan dipakai diam-diam.
PORT_TOKEN = "    moonEarthshine=(0.30, 0.30, 0.37),\n"
MODEL_TOKEN = ("        moonEarthshine: .init(red: 0.30, green: 0.30, "
               "blue: 0.37),\n")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
#
# `size` ikut dikirim supaya keadaan 4 bisa menjalankan gerbang yang sama
# pada ukuran render yang berbeda — satu-satunya cara membuktikan klaim
# "ukuran jam" tanpa menyalin gerbangnya ke harness ini.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
name, size = sys.argv[2], int(sys.argv[3])

# Hijau tingkat hasil = hasilnya **ada** DAN lolos. Himpunan kosong sengaja
# bukan hijau: gerbang yang hijau karena tidak mengukur apa pun adalah kelas
# cacat yang seluruh repo ini kejar.
results = []
try:
    C.check_moon_new_disc_reads_on_the_watch(results, size=size)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
    print("     " + r.detail)
"""

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, ukuran, harapan)
STATES = [
    ("[baseline] berkas bersih", None, 38, HIJAU),

    # ── 1. Cacat aslinya ─────────────────────────────────────────────────
    # `moonEarthshine` dikembalikan ke 0.15, nilai yang membuat piringan
    # bulan baru terukur 1.32:1 — kartu kosong di pergelangan tangan. Ini
    # keadaan yang gerbangnya **ada untuk** menangkap; kalau ia hijau di
    # sini, gerbangnya tidak menjaga apa pun.
    ("1. port: moonEarthshine 0.30 -> 0.15 (cacat asli: kartu kosong)",
     [(RENDER, PORT_TOKEN, "    moonEarthshine=(0.15, 0.15, 0.22),\n")],
     38, MERAH),

    # ── 2. Batas bawah ambang ────────────────────────────────────────────
    # 0.24 terukur 1.85:1 — hanya 0.15 di bawah ambang 2.0. Keadaan ini
    # yang membuktikan gerbangnya mengukur **besaran**, bukan keberadaan:
    # perubahan kecil yang masih membuat piringan tak terbaca harus tetap
    # berbunyi. Tanpa keadaan ini, "merah di 0.15" bisa berarti gerbangnya
    # hanya menolak nilai yang persis salah.
    ("2. port: moonEarthshine 0.30 -> 0.24 (1.85:1, di bawah ambang 2.0)",
     [(RENDER, PORT_TOKEN, "    moonEarthshine=(0.24, 0.24, 0.31),\n")],
     38, MERAH),

    # ── 3. Kontrol negatif: nilai dinaikkan ──────────────────────────────
    # Piringan **lebih** terbaca (4.25:1), jadi gerbang wajib hijau. Ini
    # keadaan terpenting setelah keadaan 1: gerbang yang memerah pada
    # perbaikan akan dilonggarkan orang, dan gerbang yang dilonggarkan
    # tidak menjaga apa pun. Keadaan 1 dan 3 bersama-sama membuktikan
    # arahnya, bukan sekadar kepekaannya.
    ("3. port: moonEarthshine 0.30 -> 0.45 (lebih terbaca, wajib hijau)",
     [(RENDER, PORT_TOKEN, "    moonEarthshine=(0.45, 0.45, 0.52),\n")],
     38, HIJAU),

    # ── 4. Kontrol ukuran: klaim "di ukuran jam" ─────────────────────────
    # Gerbangnya memakai `size=38` bawaan (token `WatchMetrics.visualDiameter`).
    # Dijalankan pada 76 px hasilnya harus tetap hijau — kalau ia hanya
    # lulus di satu ukuran, klaim "terbaca di ukuran jam" tidak terukur.
    # Sebaliknya, cacat keterbacaan yang hanya muncul di 38 px juga tidak
    # akan ketahuan di sini, dan itu batas yang sengaja dicatat.
    ("4. ukuran 76 px (bukan 38): klaim ukuran jam",
     None, 76, HIJAU),

    # ── 5. Batas cakupan yang dinyatakan: model berubah, port tidak ──────
    # Arah yang paling mungkin terjadi di dunia nyata (penyuntingan model
    # di Mac), dan terukur **tidak** berbunyi: gerbang ini mengukur gambar
    # port. Hijau di sini bukan kelulusan, melainkan batas cakupan yang
    # dijalankan supaya tidak disangka tertutup.
    ("5. model Swift 0.30 -> 0.15, port tidak ikut (batas cakupan)",
     [(MODEL, MODEL_TOKEN,
       "        moonEarthshine: .init(red: 0.15, green: 0.15, "
       "blue: 0.22),\n")],
     38, HIJAU),
]


def run_probe(size):
    """Jalankan gerbang di proses baru. → (verdict atau None, galat)."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, GATE, str(size)],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    return out.stdout, None


def classify(stdout):
    """Petakan keluaran prob → {nama hasil: hijau|merah}."""
    verdicts = {}
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        state, _, name = stripped.partition(" ")
        name = name.strip()
        if state in ("OK", "GAGAL") and name and not name.startswith(":"):
            verdicts[name] = "hijau" if state == "OK" else "merah"
    return verdicts


def main():
    files = [RENDER, MODEL]
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
        for name, edits, size, want in STATES:
            restore()
            if edits is not None:
                # Mutasi dikumpulkan per berkas supaya beberapa suntingan di
                # berkas yang sama tidak saling menimpa.
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

            stdout, error = run_probe(size)
            if stdout is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            verdicts = classify(stdout)
            got = verdicts.get(RESULT, "TIDAK ADA")
            # Hasilnya harus **ada**: gerbang yang tidak mengisi results
            # tidak boleh terbaca sebagai hijau.
            if RESULT not in verdicts:
                failures.append(f"{name}: hasil {RESULT!r} tidak dihasilkan "
                                f"gerbang — gerbang kosong")
            if got != want:
                failures.append(f"{name}: diharapkan {want}, terukur {got}")

            detail = ""
            for line in stdout.splitlines():
                if line.startswith("     "):
                    detail = line.strip()
            if got != want or not detail:
                print(f"{name}: TIDAK SESUAI HARAPAN")
                print(f"    diharapkan {want}, terukur {got}")
                if detail:
                    print(f"    {detail}")
            else:
                print(f"{name}: sesuai harapan ({got}, {detail})")
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
