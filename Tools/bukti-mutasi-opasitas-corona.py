#!/usr/bin/env python3
"""Buktikan gerbang **opasitas corona Matahari** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada, dan kenapa ia berbeda dari `bukti-mutasi-jangkauan-corona.py`.

Saudaranya menjaga **jangkauan** corona (`sunCoronaReach`). Yang ini menjaga
angka yang tertinggal satu tingkat di dalamnya: **kelegapan puncaknya**.
`drawSun` di `CelestialVisualView.swift` dulu menulis

    let coronaOpacity: Double = 0.40 // VIEW:

dengan komentar bahwa angka itu "dijaga oleh gerbang piksel
`check_sun_corona_reaches_beyond_the_disk`". Komentar itu **salah**, dan
salahnya tidak bisa dilihat dari hijau. Diukur di proses baru: angka di
**view** diubah `0.40 -> 0.02` — corona praktis hilang dari jam — dan ketiga
pemeriksaan piksel Matahari tetap hijau:

    corona Matahari bercahaya di luar piringan   ok  (0.85 R = 45.4)
    corona Matahari habis di tepi frame          ok  (0.99 R = 12.7)
    corona lebih lebar dari piringan             ok  (0.85R=45.4)

Nol merah. Angka yang sama diubah di **port** dan gerbangnya berbunyi
(0.85 R: 45.4 -> 12.4). Jadi gerbang piksel itu jujur: ia benar-benar
mengukur gambar, dan gambar yang ia ukur adalah gambar **port Python**.
Yang tampil di pergelangan adalah gambar **view**, dan angka itu tidak
dijaga siapa pun.

Keadaan 5 adalah inti harness ini, dan ia bentuk yang paling sunyi:
pemakaian bernama diganti literal **dengan angka yang masih benar**
(`VisualFrame.sunCoronaOpacity` -> `0.40`). Setiap gerbang angka tetap
hijau — angkanya memang masih 0.40 — dan gambarnya identik. Yang hilang
hanya **ikatannya**. Sejak baris itu, menyetel konstanta model tidak lagi
mengubah apa pun di jam, dan tidak ada satu pun yang tahu.

Keadaan 5 itu juga yang pernah menipu pemeriksaan ini sendiri. Versi pertama
"view membaca konstanta model" membaca **seluruh berkas**, jadi komentar di
atas `drawSun` — yang menyebut `VisualFrame.sunCoronaOpacity` — sudah cukup
memenuhinya sementara baris yang dipakai tetap literal. Terukur: mutasi itu
membuat pemeriksaan berkas-utuh tetap OK. Karena itu pemeriksaan bernama
sekarang dipotong ke **badan fungsi** lewat `_function_body`. Komentar bukan
kode, dan gerbang yang bisa dipuaskan komentar adalah gerbang yang mengukur
niat, bukan perilaku.

Tiga tingkat verdict, dan itu bukan kerapian:

  * **hijau** -- gerbangnya tidak berbunyi, dan pada keadaan itu memang
    seharusnya tidak berbunyi.
  * **merah** -- gerbangnya berbunyi.
  * **TIDAK ADA** -- pemeriksaan yang dituntut tidak ada sama sekali. Ini
    sengaja bukan hijau: gerbang yang hilang akan terbaca sebagai lulus.

Berkas sumber produksi dimutasi dengan sengaja lalu dipulihkan di `finally`
per keadaan, plus handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally`
dan meninggalkan mutasi hidup. Penulisan & pemulihannya lewat `mutasi_sumber`,
sama seperti harness lain -- dan `require_clean_sources` menolak jalan kalau
berkas produksi sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-opasitas-corona.py    # 0 = semua sesuai harapan
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
VIEW = os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")

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
# Ketiganya unik. Harness memeriksa jumlah kemunculannya sebelum memutasi,
# jadi jangkar yang menjadi ambigu dilaporkan sebagai kelemahan bukti --
# bukan dipakai diam-diam.
MODEL_ANCHOR = "sunCoronaOpacity: Double = 0.40"
MODEL_FAINT = "sunCoronaOpacity: Double = 0.02"
MODEL_OPAQUE = "sunCoronaOpacity: Double = 0.95"
PORT_ANCHOR = "SUN_CORONA_OPACITY = 0.40"
PORT_FAINT = "SUN_CORONA_OPACITY = 0.02"

# Pemakaian bernama di view diganti literal **yang angkanya masih benar**.
# Ini keadaan paling sunyi dari semuanya: tidak ada angka yang berubah, jadi
# setiap gerbang angka dan setiap gerbang piksel tetap hijau. Yang hilang
# cuma ikatannya.
VIEW_NAMED = "        let coronaOpacity = VisualFrame.sunCoronaOpacity\n"
VIEW_LITERAL = "        let coronaOpacity: Double = 0.40 // VIEW:\n"

OPACITY = "check_sun_corona_opacity_matches_the_model"
REACH = "check_sun_corona_reach_matches_the_model"

HIJAU = "hijau"
MERAH = "merah"

ALL = ",".join((OPACITY, REACH))

# Nama pemeriksaan di dalam gerbang baru, dipakai berulang di STATES.
SAMA = "opasitas corona: model dan port memakai angka yang sama"
PORT_NAMED = "opasitas corona: port memakai konstantanya sendiri (bukan literal)"
VIEW_NAMED_CHECK = "opasitas corona: view membaca konstanta model (bukan literal)"
BODY_NAMED = "opasitas corona: drawSun membaca konstanta model (bukan literal)"
BODY_LITERAL = "opasitas corona: drawSun tidak menulis ulang angkanya"
RENTANG = "opasitas corona: di rentang yang terbaca sebagai glow"

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline]", None,
     {OPACITY: HIJAU, REACH: HIJAU,
      SAMA: HIJAU, PORT_NAMED: HIJAU, VIEW_NAMED_CHECK: HIJAU,
      BODY_NAMED: HIJAU, BODY_LITERAL: HIJAU, RENTANG: HIJAU}),

    # ── 1. Model berubah, port tidak ikut ────────────────────────────────
    #
    # Keadaan yang paling mungkin terjadi di dunia nyata: yang menyunting
    # tampilan Matahari memperbaiki **model** di Mac, bukan port Python di
    # Linux. `check_sun_corona_reach_matches_the_model` sengaja diharapkan
    # **hijau**: jangkauan tidak diubah, dan kalau ia ikut memerah kedua
    # gerbang sedang mengukur hal yang sama.
    ("1. model 0.40 -> 0.02, port tidak ikut",
     [(MODEL, MODEL_ANCHOR, MODEL_FAINT)],
     {OPACITY: MERAH, SAMA: MERAH, RENTANG: MERAH,
      # Pemakaian bernama di ketiga bahasa tetap benar -- ia memang tidak
      # diubah. Yang menyimpang hanya angkanya.
      PORT_NAMED: HIJAU, VIEW_NAMED_CHECK: HIJAU,
      BODY_NAMED: HIJAU, BODY_LITERAL: HIJAU,
      REACH: HIJAU}),

    # ── 2. Port berubah, model tidak ikut ────────────────────────────────
    #
    # Arah sebaliknya. Gerbang piksel **tidak** ikut di sini, dan itu bukan
    # kelalaian: `SUN_CORONA_OPACITY` mengubah luminans gambar port, dan
    # pemeriksaan piksel corona mengukur ambang yang lebar (0.85 R harus
    # > 25 terhadap latar 10.6). Corona 0.02 memang akan memerahkannya, tetapi
    # ambang itu milik gerbang lain; yang diuji di sini adalah apakah
    # **gerbang angka** menamai penyimpangannya dengan tepat.
    ("2. port 0.40 -> 0.02, model tidak ikut",
     [(RENDER, PORT_ANCHOR, PORT_FAINT)],
     {OPACITY: MERAH, SAMA: MERAH,
      PORT_NAMED: HIJAU, BODY_LITERAL: HIJAU,
      RENTANG: HIJAU,
      REACH: HIJAU}),

    # ── 3. Kedua bahasa berubah bersama (0.40 -> 0.02) ───────────────────
    #
    # Pembeda "mengukur penyimpangan" dari "mengukur nilainya". Tidak ada
    # penyimpangan sama sekali di sini, jadi gerbang **kesamaan angka**
    # hijau -- dan yang berbunyi adalah pemeriksaan **rentang**. Dua angka
    # yang sama-sama salah tetap salah, dan corona 0.02 adalah tepat yang
    # komentar model sebut sebagai "tak lagi terbaca sebagai cahaya".
    ("3. model DAN port 0.40 -> 0.02 (sepakat, sama-sama salah)",
     [(MODEL, MODEL_ANCHOR, MODEL_FAINT),
      (RENDER, PORT_ANCHOR, PORT_FAINT)],
     {OPACITY: MERAH, SAMA: HIJAU, RENTANG: MERAH,
      PORT_NAMED: HIJAU, VIEW_NAMED_CHECK: HIJAU,
      REACH: HIJAU}),

    # ── 4. Di atas rentang: 0.40 -> 0.95 ─────────────────────────────────
    #
    # Arah ketiga dari rentang. Tanpa keadaan ini, "rentang" bisa dipenuhi
    # oleh batas bawah saja, dan corona yang menelan piringan fotosfer --
    # Matahari sebagai gumpalan cahaya rata -- lolos.
    ("4. model DAN port 0.40 -> 0.95 (di atas rentang)",
     [(MODEL, MODEL_ANCHOR, MODEL_OPAQUE),
      (RENDER, PORT_ANCHOR, "SUN_CORONA_OPACITY = 0.95")],
     {OPACITY: MERAH, SAMA: HIJAU, RENTANG: MERAH,
      REACH: HIJAU}),

    # ── 5. Pemakaian di view diganti literal (angka masih benar) ─────────
    #
    # Bentuk paling sunyi, dan satu-satunya yang **tidak** terlihat oleh
    # gerbang piksel mana pun: angkanya masih 0.40, jadi gambar port tidak
    # berubah, gambarnya identik, dan setiap gerbang angka tetap hijau.
    # Yang hilang adalah ikatan antara model dan yang tampil di jam.
    #
    # Dua pemeriksaan harus berbunyi di sini, dan keduanya perlu:
    # `BODY_NAMED` menangkap "berhenti memakai nama", `BODY_LITERAL`
    # menangkap "menulis ulang angkanya". `VIEW_NAMED_CHECK` (berkas-utuh)
    # sengaja diharapkan **hijau** -- dan justru itu yang membuktikan
    # pemeriksaan berkas-utuh tidak cukup: komentar di atas `drawSun`
    # menyebut `VisualFrame.sunCoronaOpacity`, jadi ia tetap terpuaskan
    # sementara baris yang dipakai adalah literal. Keadaan ini yang membuat
    # `BODY_NAMED` ada.
    ("5. view: pemakaian diganti literal (angka masih 0.40)",
     [(VIEW, VIEW_NAMED, VIEW_LITERAL)],
     {OPACITY: MERAH, BODY_NAMED: MERAH, BODY_LITERAL: MERAH,
      VIEW_NAMED_CHECK: HIJAU,
      SAMA: HIJAU, PORT_NAMED: HIJAU, RENTANG: HIJAU,
      REACH: HIJAU}),
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
    mutasi_sumber.require_clean_sources([MODEL, RENDER, VIEW])
    originals = {path: open(path, "rb").read() for path in (MODEL, RENDER, VIEW)}
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
