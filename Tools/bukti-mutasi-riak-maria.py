#!/usr/bin/env python3
"""Buktikan gerbang «riak maria» berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang `check_maria_ripple_matches_the_view` ditulis bersama perubahan
"bercak maria beriak, bukan lingkaran", dan gerbang baru selalu hijau pada
hari ia ditulis. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan
merah pada keadaan yang memang salah — di **kedua arah**, karena dua arahnya
punya akibat yang berbeda:

  * view menyimpang dari port  → jam menggambar siluet yang tidak pernah
                                 diukur satu pun pemeriksaan piksel (seluruh
                                 `--check` mengukur port)
  * port menyimpang dari view  → kebalikannya: gerbang piksel mengukur
                                 susunan bercak yang tidak pernah tampil

Keduanya terdengar sama ("angka tidak sama di dua bahasa") tetapi **bukan**
keadaan yang sama: kalau hanya satu arah yang berbunyi, gerbang itu
sebenarnya hanya membaca satu berkas dan menyebut dirinya "paritas".

**Kenapa jangkar dipilih di elemen ke-3, bukan ke-0.** Elemen pertama maria
sudah dijaga `check_port_matches_swift_constants` dan
`check_feature_arrays_match_the_view`. Memutasi elemen yang sudah dijaga akan
menyalakan tiga gerbang sekaligus, dan harness lalu tidak bisa membedakan
apakah gerbang baru ini mengukur apa pun. Memutasi elemen yang **tidak**
dijaga siapa pun adalah satu-satunya cara mengukur gerbang ini sendirian.

**Batas yang dinyatakan.** Yang dijaga gerbang ini adalah **paritas angka
antara dua bahasa**, bukan kebenaran astronomi susunan maria, dan bukan
kualitas visual riaknya. Kalau kelak lariknya disunting bersama di kedua
bahasa, gerbang ini hijau — yang dijaganya adalah *kesepakatan*, bukan
nilainya. Harness ini tidak mengklaim lebih dari itu.

Berkas sumber produksi dimutasi dengan sengaja lalu dipulihkan di `finally`
per keadaan, plus handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally`
dan meninggalkan mutasi hidup — pelajaran yang sudah dibayar di repo ini.
Penulisan & pemulihannya lewat `mutasi_sumber`, sama seperti harness lain,
dan `require_clean_sources` menolak jalan di atas pohon kotor.

Pakai:
    python3 Tools/bukti-mutasi-riak-maria.py    # 0 = semua sesuai harapan
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

VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
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

# Tiga tingkat verdict, dan itu bukan kerapian:
#
#   hijau     gerbangnya tidak berbunyi, dan pada keadaan itu memang
#             seharusnya tidak berbunyi
#   merah     gerbangnya berbunyi
#   TIDAK ADA pemeriksaan yang dituntut tidak ada sama sekali. Ini sengaja
#             **bukan** hijau: gerbang yang hilang akan terbaca sebagai lulus.
for name in sys.argv[2].split(","):
    results = []
    try:
        getattr(C, name)(results)
    except Exception as exc:
        print("ERR " + name + " " + type(exc).__name__ + ": " + str(exc)[:200])
        continue
    ok = bool(results) and all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

# ── Jangkar ──────────────────────────────────────────────────────────────
# Elemen ke-3 dipilih, bukan ke-0: elemen pertama sudah dijaga dua gerbang
# lain, jadi memutasinya tidak mengukur gerbang **ini**.
VIEW_RIPPLE = "        (0.19, 5.3), (0.24, 3.0), (0.16, 0.3), (0.21, 2.9),"
VIEW_RIPPLE_2 = "        (0.19, 5.3), (0.91, 3.0), (0.16, 0.3), (0.21, 2.9),"

PORT_RIPPLE = "                (0.19, 5.3), (0.24, 3.0), (0.16, 0.3), (0.21, 2.9),\n"
PORT_RIPPLE_2 = "                (0.19, 5.3), (0.91, 3.0), (0.16, 0.3), (0.21, 2.9),\n"

# Pelunakan tepi: satu angka, hidup di dua bahasa.
VIEW_SOFT = "private static let mariaEdgeSoftness: CGFloat = 0.35"
VIEW_SOFT_2 = "private static let mariaEdgeSoftness: CGFloat = 0.75"
PORT_SOFT = "MARIA_EDGE_SOFTNESS = 0.35"
PORT_SOFT_2 = "MARIA_EDGE_SOFTNESS = 0.75"

RIPPLE = "check_maria_ripple_matches_the_view"
#: Gerbang tetangga yang **sudah** menjaga larik maria. Diharapkan tetap
#: hijau di keadaan 1–2, karena yang dimutasi di sana adalah larik **riak**,
#: bukan larik bercaknya. Kalau ia ikut merah, mutasinya menyentuh lebih
#: dari yang diklaim dan keadaan itu tidak mengukur apa yang ia katakan.
ARRAYS = "check_feature_arrays_match_the_view"
PORTCONST = "check_port_matches_swift_constants"

HIJAU = "hijau"
MERAH = "merah"

ALL = ",".join((RIPPLE, ARRAYS, PORTCONST))

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline]", None,
     {RIPPLE: HIJAU, ARRAYS: HIJAU, PORTCONST: HIJAU}),

    # ── 1. Riak di view menyimpang dari port ─────────────────────────────
    #
    # Arah yang paling mungkin di dunia nyata: orang menyunting tampilan di
    # Mac. Gerbang tetangga sengaja tetap **hijau** — larik bercaknya tidak
    # disentuh, dan kalau mereka ikut merah, mutasinya bukan mutasi riak.
    ("1. view: riak bercak ke-5 berubah, port tidak ikut",
     [(VIEW, VIEW_RIPPLE, VIEW_RIPPLE_2)],
     {RIPPLE: MERAH, ARRAYS: HIJAU, PORTCONST: HIJAU}),

    # ── 2. Riak di port menyimpang dari view ─────────────────────────────
    #
    # Arah "orang menyunting gambar di Linux". Sama-sama harus merah; tanpa
    # keadaan ini, gerbang yang hanya membaca berkas view akan lolos dengan
    # menyebut dirinya gerbang paritas.
    ("2. port: riak bercak ke-5 berubah, view tidak ikut",
     [(RENDER, PORT_RIPPLE, PORT_RIPPLE_2)],
     {RIPPLE: MERAH, ARRAYS: HIJAU, PORTCONST: HIJAU}),

    # ── 3. Pelunakan tepi di view berubah ────────────────────────────────
    #
    # Satu angka, bukan larik. Yang membuktikan bagian kedua gerbang ini
    # hidup: gerbang yang hanya membandingkan larik riak akan tetap hijau di
    # sini, dan pelunakan tepi lalu bisa berubah tanpa suara.
    ("3. view: pelunakan tepi 0.35 -> 0.75",
     [(VIEW, VIEW_SOFT, VIEW_SOFT_2)],
     {RIPPLE: MERAH, ARRAYS: HIJAU, PORTCONST: HIJAU}),

    # ── 4. Kedua bahasa berubah bersama ──────────────────────────────────
    #
    # Pembeda "mengukur penyimpangan" dari "mengukur nilainya". Tidak ada
    # penyimpangan di sini, jadi gerbangnya hijau — dan itu **benar**, bukan
    # lubang: kalau keadaan ini merah, gerbangnya sedang menyematkan nilai,
    # dan ia akan memaksa setiap penyuntingan yang sah.
    ("4. view DAN port sepakat mengubah pelunakan tepi",
     [(VIEW, VIEW_SOFT, VIEW_SOFT_2), (RENDER, PORT_SOFT, PORT_SOFT_2)],
     {RIPPLE: HIJAU, ARRAYS: HIJAU, PORTCONST: HIJAU}),
]


def run_probe(checks):
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, checks],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("ERR "):
            # Pemeriksaan yang melempar exception: catat sebagai merah agar
            # ia tidak pernah terbaca sebagai lulus.
            verdicts[line[4:].split(" ")[0]] = "merah"
            continue
        state, name = line.split(" ", 1)
        verdicts[name.strip()] = "hijau" if state == "OK" else "merah"
    return verdicts, None


def main():
    sources = [VIEW, RENDER]
    mutasi_sumber.require_clean_sources(sources)
    originals = {path: open(path, "rb").read() for path in sources}
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

            verdicts, error = run_probe(ALL)
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            wrong = [(check, want, verdicts.get(check, "TIDAK ADA"))
                     for check, want in expected.items()
                     if verdicts.get(check, "TIDAK ADA") != want]
            if wrong:
                for check, want, got in wrong:
                    failures.append(f"{name}: {check!r} diharapkan {want}, "
                                    f"terukur {got}")
                print(f"{name}: {len(wrong)} TIDAK SESUAI HARAPAN")
                for check, want, got in wrong:
                    print(f"    {check}\n      diharapkan {want}, terukur {got}")
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
