#!/usr/bin/env python3
"""Buktikan gerbang **jangkauan corona Matahari** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

`Tools/render-visuals.py` menulis, di komentarnya sendiri:

    # Corona menjangkau ini x radius gambar -- **sama dengan**
    # `VisualFrame.sunCoronaReach` di model Swift. Satu angka, satu sumber,
    # supaya dua bahasa tidak menyimpang.
    SUN_CORONA_REACH = 1.45

Kalimat "satu angka, satu sumber" itu **klaim**, dan sampai siklus ini tidak
ada satu pun gerbang yang menjaganya. Diukur, bukan diasumsikan: konstanta
`sunCoronaReach` di model Swift diubah 1.45 -> 1.60 dan **seluruh** gerbang
Matahari tetap hijau:

    check_sun_profile_matches_the_model       ok
    check_sun_edge_is_soft                    ok
    check_sun_corona_reaches_beyond_the_disk  ok
    check_night_accents_match_the_model       ok

Sebabnya kelas yang sudah dibayar repo ini berkali-kali: setiap gerbang
Matahari mengukur **gambar port**, dan port-nya tidak ikut berubah. Yang
menyimpang adalah **view** (`CelestialVisualView.swift`), yang membaca
`VisualFrame.sunCoronaReach`. Jadi yang diuji di Linux dan yang tampil di jam
perlahan-lahan menjadi dua Matahari berbeda, sementara kedua sisi hijau.

Arah yang paling berbahaya justru arah itu. Orang yang memperbaiki tampilan
Matahari menyunting **model** di Mac, bukan port Python di Linux -- jadi
"model berubah, port tidak ikut" adalah keadaan yang paling mungkin terjadi,
bukan yang paling tidak mungkin. Karena itu keadaan 1 dan 2 di bawah memutasi
**kedua bahasa secara terpisah**, dan keduanya harus berbunyi.

Tiga tingkat verdict, dan itu bukan kerapian:

  * **hijau** -- gerbangnya tidak berbunyi, dan pada keadaan itu memang
    seharusnya tidak berbunyi.
  * **merah** -- gerbangnya berbunyi.
  * **TIDAK ADA** -- pemeriksaan yang dituntut tidak ada sama sekali. Ini
    sengaja bukan hijau: gerbang yang hilang akan terbaca sebagai lulus.

Keadaan 3 sengaja memutasi **kedua bahasa bersama-sama** (1.45 -> 1.60 di
model *dan* port). Di situ gerbang kesamaan angkanya **hijau** -- dan itu
benar, karena tidak ada penyimpangan. Yang berbunyi adalah pemeriksaan
**rentang** dan `check_sun_edge_is_soft`: dua angka yang sama-sama salah
masih salah. Tanpa keadaan ini, harness tidak bisa membedakan "gerbang ini
mengukur penyimpangan" dari "gerbang ini mengukur nilainya".

Berkas sumber produksi dimutasi dengan sengaja lalu dipulihkan di `finally`
per keadaan, plus handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup. Penulisan & pemulihannya lewat `mutasi_sumber`,
sama seperti harness lain -- dan `require_clean_sources` menolak jalan kalau
berkas produksi sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-jangkauan-corona.py    # 0 = semua sesuai harapan
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

MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                            "CelestialVisual.swift")
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

# Hijau tingkat fungsi = pemeriksaannya **ada** DAN semuanya lolos. Himpunan
# kosong sengaja **bukan** hijau: gerbang yang hijau karena tidak mengukur
# apa pun adalah kelas cacat yang seluruh repo ini kejar.
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

# ── Jangkar di dalam sumber ──────────────────────────────────────────────
# Keduanya unik: `sunCoronaReach` hanya dideklarasikan sekali di model, dan
# `SUN_CORONA_REACH = ` hanya sekali di port. Harness memeriksa jumlah
# kemunculannya sebelum memutasi, jadi jangkar yang menjadi ambigu akan
# dilaporkan sebagai kelemahan bukti -- bukan dipakai diam-diam.
MODEL_ANCHOR = "sunCoronaReach: Double = 1.45"
MODEL_TOO_FAR = "sunCoronaReach: Double = 1.60"
MODEL_TOO_NEAR = "sunCoronaReach: Double = 1.20"
PORT_ANCHOR = "SUN_CORONA_REACH = 1.45"
PORT_TOO_FAR = "SUN_CORONA_REACH = 1.60"
# Literal menggantikan nama konstanta di **pemakaian**-nya: angkanya masih
# benar hari ini, jadi setiap pemeriksaan angka tetap hijau -- yang hilang
# adalah ikatannya. Ini bentuk yang paling sunyi dari semua keadaan.
PORT_LITERAL_USE = ("_draw_sun(canvas, cx, cy, radius / SUN_CORONA_REACH, kw, night_mode)",
                    "_draw_sun(canvas, cx, cy, radius / 1.45, kw, night_mode)")

REACH = "check_sun_corona_reach_matches_the_model"
EDGE = "check_sun_edge_is_soft"
PROFILE = "check_sun_profile_matches_the_model"

HIJAU = "hijau"
MERAH = "merah"

ALL = ",".join((REACH, EDGE, PROFILE))

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline]", None,
     {REACH: HIJAU, EDGE: HIJAU, PROFILE: HIJAU}),

    # ── 1. Model berubah, port tidak ikut ────────────────────────────────
    #
    # Keadaan yang paling mungkin terjadi di dunia nyata: yang menyunting
    # tampilan Matahari memperbaiki **model** di Mac. Sebelum gerbang ini,
    # keadaan ini tidak menghasilkan satu pun merah.
    #
    # `check_sun_profile_matches_the_model` sengaja diharapkan **hijau**:
    # ia mengikat isi *profil*, dan `sunCoronaReach` bukan bagian profil itu.
    # Kalau ia ikut memerah, kedua gerbang sedang mengukur hal yang sama --
    # dan salah satunya tidak menjaga apa pun.
    ("1. model 1.45 -> 1.60, port tidak ikut",
     [(MODEL, MODEL_ANCHOR, MODEL_TOO_FAR)],
     {REACH: MERAH,
      "jangkauan corona: model dan port memakai angka yang sama": MERAH,
      "jangkauan corona: di dalam rentang yang terbaca sebagai glow": MERAH,
      # Pemakaian bernama di view tetap benar -- ia memang tidak diubah.
      "jangkauan corona: view memakai konstanta model (bukan literal)": HIJAU,
      EDGE: HIJAU, PROFILE: HIJAU}),

    # ── 2. Port berubah, model tidak ikut ────────────────────────────────
    #
    # Arah sebaliknya. Di sini `check_sun_edge_is_soft` **ikut** merah --
    # dan itu benar: port-nya memang menggambar Matahari yang berbeda, jadi
    # gambar yang diukur gerbang piksel itu memang berubah.
    #
    # Keadaan ini juga yang membuktikan gerbang baru **tidak mubazir**: ada
    # satu cacat nyata yang hanya gerbang angka ini yang menamainya dengan
    # tepat ("model dan port menyimpang"), sementara gerbang piksel menyebut
    # gejala ("tepi tidak halus") tanpa menyebut sebabnya.
    ("2. port 1.45 -> 1.60, model tidak ikut",
     [(RENDER, PORT_ANCHOR, PORT_TOO_FAR)],
     {REACH: MERAH,
      "jangkauan corona: model dan port memakai angka yang sama": MERAH,
      EDGE: MERAH, PROFILE: HIJAU}),

    # ── 3. Kedua bahasa berubah bersama (1.45 -> 1.60) ───────────────────
    #
    # Pembeda "mengukur penyimpangan" dari "mengukur nilainya". Di sini
    # tidak ada penyimpangan sama sekali, jadi gerbang kesamaan angkanya
    # **hijau** -- dan yang berbunyi adalah pemeriksaan **rentang** plus
    # gerbang piksel. Dua angka yang sama-sama salah tetap salah.
    ("3. model DAN port 1.45 -> 1.60 (sepakat, sama-sama salah)",
     [(MODEL, MODEL_ANCHOR, MODEL_TOO_FAR),
      (RENDER, PORT_ANCHOR, PORT_TOO_FAR)],
     {REACH: MERAH,
      "jangkauan corona: model dan port memakai angka yang sama": HIJAU,
      "jangkauan corona: di dalam rentang yang terbaca sebagai glow": MERAH,
      EDGE: MERAH, PROFILE: HIJAU}),

    # ── 4. Di bawah rentang: 1.45 -> 1.20 ────────────────────────────────
    #
    # Arah ketiga dari rentang. Tanpa keadaan ini, "rentang" bisa dipenuhi
    # oleh batas atas saja, dan nilai yang terlalu kecil -- corona yang
    # hampir tak terlihat, persis yang ditolak komentar model -- lolos.
    ("4. model DAN port 1.45 -> 1.20 (di bawah rentang)",
     [(MODEL, MODEL_ANCHOR, MODEL_TOO_NEAR),
      (RENDER, PORT_ANCHOR, "SUN_CORONA_REACH = 1.20")],
     {REACH: MERAH,
      "jangkauan corona: di dalam rentang yang terbaca sebagai glow": MERAH}),

    # ── 5. Pemakaian diganti literal (angka masih benar) ─────────────────
    #
    # Bentuk paling sunyi: `radius / SUN_CORONA_REACH` ditulis `radius / 1.45`.
    # Setiap angka di repo masih 1.45, jadi gerbang **kesamaan angka** tetap
    # hijau, begitu pula kedua gerbang piksel -- gambarnya identik. Yang
    # hilang adalah **ikatannya**: sejak baris itu, mengubah konstanta tidak
    # lagi mengubah gambar, dan tidak ada yang tahu.
    #
    # Karena itu pemeriksaan "memakai konstantanya sendiri" ada, dan karena
    # itu pula keadaan ini ada: tanpa keduanya, harness ini akan melaporkan
    # bahwa gerbangnya menutup kelas cacat yang sebenarnya masih terbuka.
    ("5. pemakaian diganti literal (angka masih 1.45)",
     [(RENDER, PORT_LITERAL_USE[0], PORT_LITERAL_USE[1])],
     {REACH: MERAH,
      "jangkauan corona: port memakai konstantanya sendiri (bukan literal)": MERAH,
      "jangkauan corona: model dan port memakai angka yang sama": HIJAU,
      EDGE: HIJAU, PROFILE: HIJAU}),
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
        state, name = line.split(" ", 1)
        verdicts[name.strip()] = "hijau" if state == "OK" else "merah"
    return verdicts, None


def main():
    mutasi_sumber.require_clean_sources([MODEL, RENDER])
    originals = {path: open(path, "rb").read() for path in (MODEL, RENDER)}
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
                            f"{name}: jangkar muncul {hits}x, butuh 1: {find[:70]!r}")
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
