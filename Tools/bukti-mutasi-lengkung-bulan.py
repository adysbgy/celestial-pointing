#!/usr/bin/env python3
"""Buktikan gerbang **lengkung piringan Bulan** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

`check_moon_disc_keeps_its_curvature` menutup cacat nyata, dan ia mengukur
piksel pada tiga kasus Bulan dengan ambang yang punya jarak di kedua sisi.
Tetapi dua pemeriksaan terakhirnya — yang mengklaim *"view membaca radius
akhir gradien dari model, bukan menulis angkanya"* — mencari
`CelestialVisual.moonSphereGradientEndRadius` di **seluruh berkas** view.
Berkas itu memuat **dua** pemanggil konstanta yang sama:

    CelestialVisualView.swift:178   sphereGradient   <- jalur BULAN
    CelestialVisualView.swift:265   drawPlanet       <- jalur planet dalam

Akibatnya terukur di siklus ini (`ukur5.py` keadaan 1): mengganti **baris
178 saja** menjadi `endRadius: radius * CGFloat(1.15))` membiarkan ketiga
gerbang hijau — `check_moon_disc_keeps_its_curvature`,
`check_port_matches_swift_constants` dan
`check_planet_phase_limb_reads_the_model_constant`. Baris 265 menyumbang
tokennya, gerbang planet hanya melihat `drawPlanet`, dan pikselnya
menunjukkan **port**, yang tidak diubah. Pemeriksaan yang menyebut dirinya
"bukan menulis angkanya" lalu hijau pada kode yang menulis angkanya.

Ini persis kelas cacat yang ditutup
`check_planet_phase_limb_reads_the_model_constant` untuk jalur planet —
bedanya, jalur Bulan luput karena ia yang **pertama** membaca konstanta itu,
jadi tidak ada yang curiga.

Perbaikan yang dibuktikan di sini: dua pemeriksaan baru di
`check_moon_disc_keeps_its_curvature` mengulang klaim yang sama **terbatas
pada tubuh `sphereGradient`**, lewat `_function_body` + `swift_code_only`
yang sama dengan yang dipakai gerbang planet.

Sisi **port** tidak boleh tinggal. Keadaan 3 di bawah memutasi pemakaian di
`_moon_sphere_gradient` (jalur Bulan di port) menjadi literal, dan — seperti
keadaan 1 sebelum diperbaiki — tidak ada gerbang yang berbunyi. Karena itu
gerbangnya juga mendapat pemeriksaan **kepekaan piksel**: konstanta diganti
1.15 -> 1.45, dan piksel pita Bulan yang menyala harus bergerak. Terukur
4,79…15,06/255 pada 200 px dan 4,79…15,06 pada 38 px, versus **0,00** pada
render ulang dengan nilai yang sama. Itu yang membedakan "port membaca
konstantanya" dari "port kebetulan memakai angka yang sama hari ini".

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
    python3 Tools/bukti-mutasi-lengkung-bulan.py    # 0 = semua sesuai harapan
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
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")

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
# Masing-masing unik, dan harness memeriksa jumlah kemunculannya sebelum
# memutasi: jangkar yang menjadi ambigu dilaporkan sebagai kelemahan bukti,
# bukan dipakai diam-diam. Kedua jangkar pemakaian dibedakan oleh
# **indentasi + baris sebelahnya** — tanpa itu kedua pemanggil konstanta ini
# identik kata per kata dan penyuntingan "satu jalur saja" tak mungkin.
MODEL_ANCHOR = "static let moonSphereGradientEndRadius: Double = 1.15"
MODEL_DEEPER = "static let moonSphereGradientEndRadius: Double = 1.35"
PORT_ANCHOR = "MOON_SPHERE_GRADIENT_END_RADIUS = 1.15"
PORT_DEEPER = "MOON_SPHERE_GRADIENT_END_RADIUS = 1.35"

# Jalur BULAN di view (`sphereGradient`, baris 178): `startRadius: 0,` dengan
# 12 spasi, diikuti `endRadius` dengan 12 spasi.
VIEW_MOON_USE = (
    "            startRadius: 0,\n"
    "            endRadius: radius * CGFloat("
    "CelestialVisual.moonSphereGradientEndRadius))",
    "            startRadius: 0,\n"
    "            endRadius: radius * CGFloat(1.15))")

# Jalur PLANET di view (`drawPlanet`, baris 265): `center: center,` sebaris
# dengan `startRadius`, lalu `endRadius` dengan 32 spasi.
VIEW_PLANET_USE = (
    "center: center, startRadius: 0,\n"
    "                                endRadius: radius * CGFloat("
    "CelestialVisual.moonSphereGradientEndRadius)))",
    "center: center, startRadius: 0,\n"
    "                                endRadius: radius * CGFloat(1.15)))")

# Jalur BULAN di port (`_moon_sphere_gradient`, baris 1680): `center=(cx, cy)`
# sebaris dengan `start_radius`, lalu `end_radius` dengan 27 spasi.
PORT_MOON_USE = (
    "center=(cx, cy), start_radius=0.0,\n"
    "                           end_radius=radius * "
    "MOON_SPHERE_GRADIENT_END_RADIUS)",
    "center=(cx, cy), start_radius=0.0,\n"
    "                           end_radius=radius * 1.15)")

# Jalur PLANET di port (`_draw_planet`, baris 1209): `center`, `start_radius`
# dan `end_radius` masing-masing pada baris sendiri, 35 spasi.
PORT_PLANET_USE = (
    "center=(cx, cy),\n"
    "                                   start_radius=0.0,\n"
    "                                   end_radius=radius * "
    "MOON_SPHERE_GRADIENT_END_RADIUS)",
    "center=(cx, cy),\n"
    "                                   start_radius=0.0,\n"
    "                                   end_radius=radius * 1.15)")

MOON = "check_moon_disc_keeps_its_curvature"
PORT_CONST = "check_port_matches_swift_constants"
PLANET = "check_planet_phase_limb_reads_the_model_constant"

# Nama pemeriksaan tingkat-isi (bukan tingkat-fungsi).
V_NAMED = "sphereGradient (jalur Bulan) membaca radius akhir dari model"
V_LITERAL = ("sphereGradient (jalur Bulan) tidak menulis radius "
             "akhirnya sendiri")
P_NAMED = "drawPlanet membaca radius akhir gradien dari model"

HIJAU = "hijau"
MERAH = "merah"

ALL = ",".join((MOON, PORT_CONST, PLANET))

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline]", None,
     {MOON: HIJAU, PORT_CONST: HIJAU, PLANET: HIJAU,
      V_NAMED: HIJAU, V_LITERAL: HIJAU, P_NAMED: HIJAU}),

    # ── 1. Jalur BULAN di view menulis angkanya sendiri ──────────────────
    #
    # Cacat yang ditemukan siklus ini. Sebelum diperbaiki, keadaan ini
    # **hijau** di ketiga gerbang (terukur): baris 265 menyumbang token
    # konstantanya untuk pemeriksaan seluruh-berkas, gerbang planet hanya
    # melihat `drawPlanet`, dan pikselnya mengukur port yang tak diubah.
    #
    # Yang diharapkan merah hanyalah dua pemeriksaan bertubuh
    # `sphereGradient`. Gerbang planet sengaja tetap **hijau**: `drawPlanet`
    # memang tidak disentuh, dan kalau ia ikut memerah berarti kedua
    # pemeriksaan masih membaca seluruh berkas -- cacat yang sedang ditutup.
    ("1. view: jalur BULAN -> literal 1.15 (jalur planet utuh)",
     [(VIEW, VIEW_MOON_USE[0], VIEW_MOON_USE[1])],
     {MOON: MERAH, V_NAMED: MERAH, V_LITERAL: MERAH,
      PORT_CONST: HIJAU, PLANET: HIJAU, P_NAMED: HIJAU}),

    # ── 2. Jalur PLANET di view menulis angkanya sendiri ─────────────────
    #
    # Keadaan cermin, untuk memastikan pemeriksaan baru tidak cuma
    # menyalin gerbang planet: kalau *kedua* keadaan memerahkan *kedua*
    # pemeriksaan, pembatasan tubuh fungsi tidak bekerja dan harness ini
    # harus merah.
    ("2. view: jalur PLANET -> literal 1.15 (jalur Bulan utuh)",
     [(VIEW, VIEW_PLANET_USE[0], VIEW_PLANET_USE[1])],
     {PLANET: MERAH, P_NAMED: MERAH,
      MOON: HIJAU, V_NAMED: HIJAU, V_LITERAL: HIJAU, PORT_CONST: HIJAU}),

    # ── 3. Jalur BULAN di port menulis angkanya sendiri ──────────────────
    #
    # Sisi yang dikirim ke CI lewat piksel. Terukur sebelum diperbaiki:
    # semua gerbang hijau. Yang menangkapnya sekarang adalah pemeriksaan
    # **kepekaan piksel** — konstanta diganti, pita Bulan harus bergerak.
    ("3. port: jalur BULAN -> literal 1.15",
     [(RENDER, PORT_MOON_USE[0], PORT_MOON_USE[1])],
     {MOON: MERAH, PORT_CONST: HIJAU, PLANET: HIJAU}),

    # ── 4. Jalur PLANET di port menulis angkanya sendiri ─────────────────
    #
    # Sudah ditangkap gerbang planet sebelum siklus ini (terukur 0,00/255
    # versus 8,90…15,47). Ada di sini supaya kalau kelak gerbang planet
    # melemah, harness **ini** yang berbunyi lebih dulu.
    ("4. port: jalur PLANET -> literal 1.15",
     [(RENDER, PORT_PLANET_USE[0], PORT_PLANET_USE[1])],
     {PLANET: MERAH, MOON: HIJAU, PORT_CONST: HIJAU}),

    # ── 5. Model berubah, port & view tidak ikut ─────────────────────────
    #
    # Keadaan yang paling mungkin terjadi di dunia nyata: orang yang
    # memperbaiki tampilan Bulan menyunting **model** di Mac. Harus
    # berbunyi kalau konstanta itu benar-benar mengatur gambar.
    ("5. model 1.15 -> 1.35, port & view tidak ikut",
     [(MODEL, MODEL_ANCHOR, MODEL_DEEPER)],
     {PORT_CONST: MERAH, MOON: HIJAU, PLANET: HIJAU}),

    # ── 6. Model dan port berubah bersama ────────────────────────────────
    #
    # Pembeda "mengukur penyimpangan" dari "mengukur nilainya". Di sini
    # tidak ada penyimpangan, jadi gerbang kesamaan angkanya **hijau** --
    # dan itu benar. Gambarnya memang berubah, tetapi kedua bahasa sepakat.
    #
    # **Kenapa kedua pemeriksaan drift ikut merah, bukan hijau.** Keduanya
    # menyematkan **nilai** 1.15, bukan hanya kesamaan antarbahasa:
    # `sumber memuat` menuntut teks `moonSphereGradientEndRadius: Double =
    # 1.15` masih tertulis di model, dan `port sejalan` membandingkan nilai
    # port dengan 1.15. Jadi dua angka yang sama-sama salah tetap berbunyi —
    # persis sifat yang dicari `bukti-mutasi-jangkauan-corona` dari
    # pemeriksaan **rentang**-nya. Kalau keduanya hijau di sini, berarti
    # gerbang drift hanya mengukur kesamaan dan nilai 1.15 bisa hilang
    # tanpa suara.
    #
    # **Kenapa `check_planet_phase_limb_…` juga merah.** Ia mengukur kepekaan
    # piksel dengan probe 1.45 terhadap konstanta yang sekarang 1.35: jaraknya
    # tinggal 0.10, jadi pergeserannya jatuh di bawah ambang 4.0. Itu bukan
    # penyimpangan — itu probe yang kehilangan jarak. Dicatat apa adanya:
    # kalau kelak 1.15 diubah, keadaan ini yang mengingatkan bahwa probe 1.45
    # harus diukur ulang.
    ("6. model DAN port 1.15 -> 1.35 (sepakat, sama-sama berbeda)",
     [(MODEL, MODEL_ANCHOR, MODEL_DEEPER),
      (RENDER, PORT_ANCHOR, PORT_DEEPER)],
     {"sumber memuat: radius akhir gradien bola Bulan": MERAH,
      "port sejalan: radius akhir gradien bola Bulan": MERAH,
      PLANET: MERAH}),
]


def run_probe(checks):
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, checks],
                         capture_output=True, text=True, timeout=2400)
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
    mutasi_sumber.require_clean_sources([MODEL, RENDER, VIEW])
    originals = {path: open(path, "rb").read()
                 for path in (MODEL, RENDER, VIEW)}
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
