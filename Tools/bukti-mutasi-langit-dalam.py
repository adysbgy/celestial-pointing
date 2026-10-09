#!/usr/bin/env python3
"""Buktikan `check_deep_sky_shape_suppression` **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Dan gerbang ini khususnya punya riwayat: **dua versi sebelumnya hijau
pada kode yang jelas salah**, masing-masing dengan cara yang berbeda.

  - Versi pertama memakai `diff > 0` mentah. Karena hanya gambar "ragu" yang
    memakai lencana "?", seluruh selisihnya bisa **hanya** lencana. Terukur:
    dengan penekanan bentuk dihapus seluruhnya dari port, pemeriksaan itu
    tetap hijau (`raw_diff` 3434, semuanya lencana).
  - Versi kedua memperbaiki lencananya, dan memperluas ke keenam morfologi —
    tapi membandingkan semuanya terhadap **satu** kabut netral ber-morfologi
    `galaxy`. Terukur: hanya `galaxy` yang memerah (0 piksel, karena ia
    dibandingkan dengan dirinya sendiri); kelima morfologi lain tetap hijau
    pada 6073…6881 piksel, dan selisih itu seluruhnya **warna**. Gerbang yang
    menamai dirinya "bentuk … hilang" sedang mengukur warna.

Jadi yang dibuktikan di sini bukan "gerbangnya hijau", melainkan bahwa ia
**berbunyi pada keenam morfologi** — bukan hanya pada galaksi — saat bentuknya
bocor, dan **diam** saat kode benar.

Keadaan yang diuji:

  [baseline]                          gerbang hijau (kalau tidak, harness salah)
  1. penekanan bentuk saat ragu       bentuk bocor saat ragu; warna tetap
     dihapus                          ditekan. Arah (1) memerah untuk
                                      keenamnya. Arah (2) tetap hijau, dan itu
                                      benar: ia membandingkan dua render
                                      **terkunci**, yang pada mutasi ini tidak
                                      berubah.
  2. bentuk bocor saat ragu,          mutasi paling licik: gerbang versi kedua
     warna tetap ditekan              hijau di sini untuk 5 dari 6 morfologi.
                                      Arah (1) harus memerah untuk kelimanya.
                                      `nebula` tetap hijau karena bentuknya
                                      memang sama dengan kabut netral (diukur),
                                      jadi mutasi ini tak mengubah gambarnya.
  3. bentuk diabaikan **selamanya**   morfologi tidak pernah dipakai untuk
     (warna tetap benar)              bentuk, terkunci maupun ragu. Arah (1)
                                      hijau (penekanan tetap benar) dan seluruh
                                      42 pemeriksaan
                                      `check_deep_sky_morphologies_render_
                                      distinct` juga hijau (warnanya tetap
                                      berbeda). Hanya arah (2) yang memerah —
                                      inilah satu-satunya gerbang yang
                                      menangkapnya.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
pelajaran yang sudah dibayar di repo ini, `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-langit-dalam.py     # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import importlib.util
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
results = []
C.check_deep_sky_shape_suppression(results, 200, 2)
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Baris yang menekan **bentuk** saat engine ragu.
SHAPE_ANCHOR = ('    morphology = kw.get("morphology") if kw.get("is_confirmed", True)'
                ' else None')
# Argumen yang menentukan bentuk, di dalam panggilan penggambarnya.
#
# **Kenapa hanya potongan ini, bukan seluruh panggilan.** Versi pertama
# menjangkarkan diri pada panggilan utuh —
# `blobs = deep_sky_blobs(morphology, kw.get("fuzziness", 0.6))`. Itu benar
# sampai `deep_sky_blobs` **mendapat argumen baru**: pekerjaan elongasi M27
# menambahkan `object_id=…`, dan sejak itu jangkarnya tidak ditemukan lagi.
# Harness berhenti dengan "jangkar tidak ditemukan" dan **seluruh job CI
# merah** — bukan karena gerbangnya salah, melainkan karena harness-nya
# mematok bentuk panggilan yang tidak dijanjikannya.
#
# Yang dimutasi selalu **satu argumen**, jadi jangkarnya pun satu argumen —
# ditambah awalan `blobs = ` supaya ia tidak cocok dengan **definisi**
# fungsinya (`def deep_sky_blobs(morphology, …)`), yang akan membuat
# `str.replace` merusak tanda tangannya. Menambah argumen lain di belakang
# pemanggilan tidak lagi merusak harness; mengganti nama fungsinya tetap
# memerahkan — yang memang benar.
SHAPE_CALL = 'blobs = deep_sky_blobs(morphology,'
SHAPE_CALL_NONE = 'blobs = deep_sky_blobs(None,'

# Pemanggilan **kedua** yang memakai morfologi untuk bentuk, di dalam fungsi
# yang sama: inti bintang di dalam gugus (`cluster_cores`) menggambar titik
# yang bisa dipisahkan mata, dan ia diturunkan dari blob yang sama.
#
# Kenapa ia harus ikut dinetralkan di keadaan 3. Keadaan 3 membuktikan "bentuk
# morfologi tidak pernah sampai ke gambar". Kalau hanya `deep_sky_blobs` yang
# dinetralkan, inti gugus **masih** memakai morfologi — jadi untuk
# `openCluster` dan `globularCluster` bentuknya tetap sampai ke gambar, arah
# (2) tetap hijau untuk keduanya, dan harness melaporkan keadaan yang tidak
# pernah ia buat. Yang dibuktikan harus seluruh jalur bentuk, bukan satu
# pemanggilan yang kebetulan mudah dijangkau.
CLUSTER_CORES_CALL = 'for star in cluster_cores(morphology,'
CLUSTER_CORES_CALL_NONE = 'for star in cluster_cores(None,'

# Penjaga: jangkar harus muncul **tepat sekali** — tetapi di dalam **fungsi
# penggambarnya**, bukan di seluruh berkas.
#
# Kenapa cakupannya fungsi, bukan berkas. `blobs = deep_sky_blobs(morphology,`
# adalah bentuk panggilan yang wajar, dan berkas ini kini memanggilnya dari
# **dua** tempat: penggambar langit dalam (`_draw_deep_sky`) dan pengukur inti
# gugus (`cluster_cores`, ditambahkan untuk lantai keterbacaan inti). Penjaga
# "tepat sekali di seluruh berkas" lalu memerahkan job — dan penjaga itu
# **benar**: `str.replace` akan memutasi kedua panggilan sekaligus, sehingga
# yang diukur bukan gambar yang dimaksudkannya.
#
# Memperpendek jangkarnya lagi tidak bisa menyelesaikan ini: yang membedakan
# kedua panggilan adalah nama variabel argumen pertamanya (`kw.get(…)` versus
# `fuzziness`) — dan argumen pertama itu justru hal yang **dimutasi**. Jangkar
# yang membedakan keadaan benar dari keadaan termutasi tidak boleh ikut
# berubah saat dimutasi.
#
# Jadi yang dijaga bukan "muncul sekali di berkas", melainkan "muncul sekali
# di dalam fungsi yang menggambar". Batas fungsi dibaca dari baris `def`
# sampai baris berikutnya yang **tidak menjorok** — cukup untuk berkas ini,
# dan bila `_draw_deep_sky` diganti nama, harness memerah (yang memang benar:
# ia tidak lagi tahu gambar mana yang dimutasi).
DRAW_HEADER = "def _draw_deep_sky(canvas, cx, cy, radius, kw, night_mode):"


def _scope_span(source, header):
    """Potong `source` jadi (sebelum, badan, sesudah) untuk fungsi `header`.

    `None` bila `header` tidak ada — pemanggil memperlakukannya sebagai
    kegagalan jangkar, bukan sebagai "tidak ada yang perlu di-scope".
    """
    lines = source.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if header in line), None)
    if start is None:
        return None
    end = len(lines)
    for j in range(start + 1, len(lines)):
        line = lines[j]
        if line.strip() and not line[:1].isspace():
            end = j
            break
    return "".join(lines[:start + 1]), "".join(lines[start + 1:end]), "".join(lines[end:])

# Mutasi 1: bentuk **dan** warna sama-sama tidak ditekan.
M1_SHAPE = '    morphology = kw.get("morphology")'
# Mutasi 2: bentuk tidak ditekan, warna tetap ditekan. Ini keadaan yang
# membedakan gerbang versi kedua (hijau untuk 5 dari 6) dari versi ini.
M2_SHAPE = SHAPE_ANCHOR + '\n    _shape_morphology = kw.get("morphology")'
M2_CALL = 'blobs = deep_sky_blobs(_shape_morphology,'

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang
# membuat berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
MORPHOLOGIES = ("nebula", "planetaryNebula", "galaxy",
                "spiralGalaxy", "openCluster", "globularCluster")
# `nebula` berbentuk identik dengan kabut netral: `deep_sky_blobs("nebula", f)`
# **sama persis** dengan `deep_sky_blobs(None, f)` di semua fuzziness (diukur),
# karena `CelestialVisual.deepSky(morphology:)` memetakan `.nebula` ke fungsi
# yang sama dengan `nil`. Konsekuensinya, pemeriksaan berbasis **bentuk**
# memang tidak bisa menuntut apa pun dari `nebula` — dan itu fakta model.
# Yang membedakan nebula emisi dari kabut netral hanyalah **warna**.
SHAPE_MORPHOLOGIES = tuple(m for m in MORPHOLOGIES if m != "nebula")
SUPPRESSED = [f"saat ragu, morfologi {m} tidak mengubah gambar"
              for m in MORPHOLOGIES]
SUPPRESSED_SHAPE = [f"saat ragu, morfologi {m} tidak mengubah gambar"
                    for m in SHAPE_MORPHOLOGIES]
VISIBLE = [f"bentuk {m} sampai ke gambar saat terkunci"
           for m in SHAPE_MORPHOLOGIES]


def _hijau(names):
    return {n: "hijau" for n in names}


# (nama keadaan, [(cari, ganti), ...] atau None untuk apa adanya,
#  {nama pemeriksaan: 'merah'|'hijau'})
STATES = [
    ("[baseline]", None, _hijau(SUPPRESSED + VISIBLE)),
    # Mutasi ini menghapus penekanan **saat ragu**. Arah (1) memerah untuk
    # keenamnya. Arah (2) tetap hijau — bukan kelonggaran: arah (2)
    # membandingkan dua render **terkunci**, dan pada mutasi ini render
    # terkunci masih memakai bentuk morfologi seperti sebelumnya. Yang berubah
    # hanya sisi ragu. Diukur, bukan ditebak: 5 hijau.
    ("1. penekanan bentuk saat ragu dihapus",
     [(SHAPE_ANCHOR, M1_SHAPE)],
     {**_hijau(VISIBLE), **{n: "merah" for n in SUPPRESSED}}),
    # Mutasi paling licik: warna tetap ditekan (gerbang versi kedua hijau di
    # sini untuk lima dari enam morfologi), tapi bentuknya bocor saat ragu.
    # Arah (1) memerah untuk kelima morfologi yang bentuknya berbeda dari
    # netral. `nebula` tetap hijau karena bentuknya memang sama dengan netral
    # (diukur) — mutasi ini tidak mengubah gambar nebula sama sekali.
    ("2. bentuk bocor saat ragu, warna tetap ditekan",
     [(SHAPE_ANCHOR, M2_SHAPE), (SHAPE_CALL, M2_CALL)],
     {**_hijau(VISIBLE + [f"saat ragu, morfologi nebula tidak mengubah gambar"]),
      **{n: "merah" for n in SUPPRESSED_SHAPE}}),
    # Bentuk diabaikan **selamanya**: morfologi tidak pernah dipakai untuk
    # bentuk. Penekanan warna tetap benar, jadi arah (1) hijau seluruhnya;
    # keenam morfologi pun tetap berbeda warna, jadi 42 pemeriksaan
    # `check_deep_sky_morphologies_render_distinct` juga hijau. Hanya arah (2)
    # yang melihat bentuknya tidak pernah digambar.
    #
    # **Dua jangkar, bukan satu.** Sejak inti bintang gugus ada, morfologi
    # masuk ke gambar lewat **dua** pemanggilan di fungsi yang sama:
    # `deep_sky_blobs` (kabut) dan `cluster_cores` (titik yang bisa
    # dipisahkan mata). Menetralkan yang pertama saja meninggalkan yang kedua
    # hidup, jadi untuk `openCluster`/`globularCluster` bentuknya masih sampai
    # ke gambar — arah (2) tetap hijau untuk keduanya, dan harness akan
    # melaporkan keadaan yang tidak pernah ia buat. Keadaan ini membuktikan
    # "tidak ada jalur bentuk", jadi kedua jalurnya harus ditutup.
    ("3. bentuk diabaikan selalu (warna tetap benar)",
     [(SHAPE_CALL, SHAPE_CALL_NONE),
      (CLUSTER_CORES_CALL, CLUSTER_CORES_CALL_NONE)],
     {**_hijau(SUPPRESSED), **{n: "merah" for n in VISIBLE}}),
]


def run_probe():
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=900)
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


def main():
    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        # Tulis atomik + verifikasi (`mutasi_sumber`): harness ini dan enam
        # saudaranya memutasi berkas produksi yang sama, dan setiap prob
        # membacanya dari proses baru.
        mutasi_sumber.restore_verified(RENDER, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected in STATES:
            if edits is None:
                restore()
            else:
                source = original.decode()
                span = _scope_span(source, DRAW_HEADER)
                if span is None:
                    failures.append(
                        f"{name}: fungsi penggambar tidak ditemukan: "
                        f"{DRAW_HEADER!r} — harness tidak tahu gambar mana "
                        f"yang dimutasi, jadi ia berhenti")
                    # Pulihkan dulu: tanpa ini keadaan berikutnya membaca
                    # berkas yang masih membawa mutasi keadaan sebelumnya —
                    # kelas cacat "mengadopsi kerusakannya sendiri" yang
                    # sudah dibayar di repo ini.
                    restore()
                    continue
                before, body, after = span
                for find, replace in edits:
                    hits = body.count(find)
                    if hits == 0:
                        failures.append(
                            f"{name}: jangkar tidak ditemukan di dalam "
                            f"{DRAW_HEADER!r}: {find!r}")
                        break
                    if hits > 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}× di dalam "
                            f"{DRAW_HEADER!r}, butuh 1 (replace akan "
                            f"memutasi yang lain): {find!r}")
                        break
                    body = body.replace(find, replace)
                else:
                    mutasi_sumber.write_source(RENDER, before + body + after)

            verdicts, error = run_probe()
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

    after = hashlib.md5(open(RENDER, "rb").read()).hexdigest()
    print(f"\nmd5 render-visuals.py: {baseline_md5} -> {after} "
          f"({'pulih persis' if after == baseline_md5 else 'TIDAK PULIH'})")
    if after != baseline_md5:
        failures.append("sumber produksi tidak pulih persis")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("\nSemua keadaan sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
