#!/usr/bin/env python3
"""Buktikan `check_candidate_marker_stays_inside_its_badge` **berbunyi**.

Kenapa harness ini ada.

Gerbang ini menjaga **satu-satunya penanda di layar** yang mengatakan
"engine ragu" — lencana tanda tanya. Kalau ia hanya hijau, yang tersisa
adalah gambar objek tanpa penanda, dan gambar tanpa penanda terbaca
sebagai identitas yang pasti. Itu pelanggaran paling keras di PRD.

Dan ia belum pernah dibuktikan: dari 83 gerbang di `check-visuals.py`,
ini satu dari **8** yang tidak dirujuk satu pun harness `bukti-mutasi-*`.

### Cacat yang ditemukan dengan menjalankannya, bukan dengan membacanya

Versi pertama harness ini menemukan cacat **di dalam gerbangnya sendiri**,
dan cacat itu lebih besar daripada yang gerbangnya klaim tutup:

`_draw_candidate_marker` menulis

    points = [(center[0] + gx * radius, center[1] + gy * radius) ...]

padahal titik-titik dari `candidate_marker_glyph()` sudah **absolut** dalam
satuan radius frame (`center ± 0.17`). Pusat lencana ditambahkan **dua
kali**, sehingga glif mendarat di (207, −35) pada kanvas 200 px — jauh di
luar frame, dan tidak satu piksel pun tergambar.

Terukur, bukan diklaim:

    mutasi                              piksel berubah   gerbang lama
    glif dihapus (`pass`)               **0**            hijau, 247
    glif digeser +0.12 R                **0**            hijau, 247
    glif diskalakan 3x                  **0**            hijau, 247

Gerbang lama tetap **247 di semua keadaan**, karena 247 itu piksel
**lencananya** — cakram isi, lingkaran tepi, dan tetes — yang memang
berada di dalam kotak yang diukur gerbangnya. Pemeriksaan "glif tanda
tanya tergambar" tidak pernah bisa membedakan glif dari lencana.

Perbaikannya ada dua, dan keduanya perlu:
  - port: `size / 2.0 + gx * radius` (titiknya absolut),
  - gerbang: pemeriksaan baru yang mengukur **selisih** piksel dengan vs
    tanpa glif, bukan jumlah piksel peringatan di dalam kotak.

### Yang diukur harness ini

    [baseline]                                hijau, 5 pemeriksaan
    1. port: pusat ditambahkan dua kali       MERAH (sumbangan glif)
       (keadaan cacat yang asli)              — gerbang lama tetap hijau
    2. port: glif dihapus seluruhnya          MERAH (sumbangan glif)
    3. port: glif digeser +0.12 R             MERAH (sumbangan glif)
    4. port: glif diskalakan 3x               MERAH (sumbangan glif,
                                                      keluar lencana)
    5. port: titik jadi pergeseran dari pusat MERAH (sumbangan glif)
       (konvensi satuan salah, arah lain)
    6. kontrol negatif: komentar diubah       hijau penuh

Keadaan 1 adalah yang paling penting: ia keadaan yang **benar-benar hidup
di repo ini** sampai siklus ini, dan gerbang lamanya hijau di sana.
Keadaan 6 membuktikan harness tidak merah sekadar karena berkasnya
berubah.

### Yang TIDAK diklaim

- Gerbang ini mengukur **gambar port Python**, bukan app Apple. Yang
  dibuktikan: glifnya ikut menggambar di port, dan gerbangnya berbunyi
  kalau tidak. Bahwa view Swift benar dijamin `drawCandidateMarker`
  membangun path-nya relatif terhadap `center` (dibaca, bukan diuji di
  sini).
- Ambang 40 piksel pada pemeriksaan "sumbangan glif" diukur pada keadaan
  benar (316 piksel). Ia bukan ambang penerbangan luar angkasa: yang
  dijaga adalah bahwa sumbangannya **tidak nol**, dan 0 vs 316 adalah
  selisih yang tidak mungkin tertutup rasterisasi.
- **7 gerbang nirsaksi lainnya belum dikerjakan** (terukur: 8 → 7).

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus
handler `SIGINT`/`SIGTERM`. `require_clean_sources` menolak jalan bila
berkas produksi sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-glif-lencana.py   # 0 = sesuai harapan
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

HIJAU = "hijau"
MERAH = "merah"

# Nama pemeriksaan di dalam gerbang, supaya harness bisa menuntut **yang
# mana** berbunyi, bukan sekadar "ada yang merah".
SATURN = "lencana saturn: glif tidak keluar lencana"
JUPITER = "lencana jupiter: glif tidak keluar lencana"
MARS = "lencana mars: glif tidak keluar lencana"
TERGAMBAR = "lencana: glif tanda tanya tergambar"
SUMBANGAN = "lencana: glif menyumbang pikselnya sendiri (bukan lencana)"

# ── Jangkar ──────────────────────────────────────────────────────────────
# Semuanya unik di berkasnya (diperiksa sebelum memutasi).
GLYPH_POINTS = (
    "    points = [(size / 2.0 + gx * radius, size / 2.0 + gy * radius)\n"
    "              for gx, gy in points]\n")
GLYPH_STROKE = (
    "    canvas.stroke_polyline(points, max(1.0, badge_radius * 0.28),"
    " solid(warning))\n")
COMMENT = (
    "    # Glif tanda tanya — Path, bukan teks (lihat `drawCandidateMarker`).\n")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` dari berkas yang
# **sudah dimutasi** di disk. Mengimpor sekali di dalam proses ini akan
# memakai salinan lama, dan seluruh harness berbohong.
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
    C.check_candidate_marker_stays_inside_its_badge(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

ALL_HIJAU = {SATURN: HIJAU, JUPITER: HIJAU, MARS: HIJAU, TERGAMBAR: HIJAU,
             SUMBANGAN: HIJAU}

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline] berkas bersih", None, dict(ALL_HIJAU)),

    # ── 1. Cacat yang asli: pusat lencana ditambahkan dua kali ────────────
    # Titik glif sudah absolut; menambahkan `center` membuatnya mendarat di
    # luar kanvas, sehingga nol piksel tergambar. TERGAMBAR **sengaja
    # diharapkan tetap hijau** — justru itulah buktinya: gerbang lama tidak
    # bisa melihat cacat ini sama sekali, karena ia menghitung piksel
    # lencana. Kalau keadaan ini memerahkan TERGAMBAR, berarti cacatnya
    # sudah bukan cacat yang diklaim di atas.
    ("1. port: pusat lencana ditambahkan dua kali (cacat asli)",
     [(RENDER, GLYPH_POINTS,
       "    points = [(center[0] + gx * radius, center[1] + gy * radius)\n"
       "              for gx, gy in points]\n")],
     {SUMBANGAN: MERAH, TERGAMBAR: HIJAU,
      SATURN: HIJAU, JUPITER: HIJAU, MARS: HIJAU}),

    # ── 2. Glif dihapus seluruhnya ────────────────────────────────────────
    # Arah paling kasar: tidak ada glif sama sekali. Kalau pemeriksaan
    # sumbangan hijau di sini, ia mengukur lencana (cacat yang ia ada untuk
    # menutup), bukan glif.
    ("2. port: glif dihapus seluruhnya",
     [(RENDER, GLYPH_STROKE, "    pass\n")],
     {SUMBANGAN: MERAH, TERGAMBAR: HIJAU,
      SATURN: HIJAU, JUPITER: HIJAU, MARS: HIJAU}),

    # ── 3. Glif digeser sedikit ke dalam kanvas ───────────────────────────
    # Berbeda dari keadaan 1: glifnya **tetap tergambar**, hanya bergeser
    # 0.12 R dari tempatnya. Keadaan 1 tidak bisa membedakan "glif hilang"
    # dari "glif salah tempat"; yang ini membuktikan gerbangnya peka
    # terhadap tempatnya, bukan sekadar keberadaannya.
    ("3. port: glif digeser +0.12 R (tetap tergambar, salah tempat)",
     [(RENDER, GLYPH_POINTS,
       "    points = [(size / 2.0 + gx * radius + 0.12 * radius,\n"
       "              size / 2.0 + gy * radius)\n"
       "              for gx, gy in points]\n")],
     {SUMBANGAN: MERAH, SATURN: HIJAU, JUPITER: HIJAU, MARS: HIJAU}),

    # ── 4. Glif diskalakan 3x: harus keluar lencana ───────────────────────
    # Satu-satunya keadaan yang menyalakan pemeriksaan **posisi** (glif
    # tidak keluar lencana), bukan cuma sumbangan. Tanpanya, tiga keadaan
    # di atas semuanya mengukur satu hal yang sama.
    ("4. port: glif diskalakan 3x (keluar lencana)",
     [(RENDER, GLYPH_POINTS,
       "    points = [(size / 2.0 + gx * radius * 3.0,\n"
       "              size / 2.0 + gy * radius * 3.0)\n"
       "              for gx, gy in points]\n")],
     {SUMBANGAN: MERAH, SATURN: MERAH, JUPITER: MERAH, MARS: MERAH}),

    # ── 5. Konvensi satuan salah, arah sebaliknya ─────────────────────────
    # Titik absolut diperlakukan sebagai **pergeseran** dari pusat. Berbeda
    # dari keadaan 1 (yang menambahkan pusat dua kali): di sini glifnya
    # mendarat di tempat yang berbeda, dan hanya pemeriksaan sumbangan yang
    # bisa menangkapnya.
    ("5. port: titik absolut dipakai sebagai pergeseran dari pusat",
     [(RENDER, GLYPH_POINTS,
       "    points = [(size / 2.0 + (center[0] + gx) * radius,\n"
       "              size / 2.0 + (center[1] + gy) * radius)\n"
       "              for gx, gy in points]\n")],
     {SUMBANGAN: MERAH, SATURN: MERAH, JUPITER: MERAH, MARS: MERAH}),

    # ── 6. Kontrol negatif: suntingan yang tidak mengubah gambar ──────────
    # Kalau harness merah di sini, ia merah karena berkasnya berubah, bukan
    # karena cacatnya — dan seluruh harness tidak mengukur apa pun.
    ("6. kontrol negatif: komentar diubah (gambar identik)",
     [(RENDER, COMMENT,
       "    # Glif tanda tanya — Path, bukan teks (komentar diubah).\n")],
     dict(ALL_HIJAU)),
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
        if state in ("OK", "GAGAL") and name:
            verdicts[name] = "hijau" if state == "OK" else "merah"
    return verdicts


def main():
    files = [RENDER]
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
        for state in STATES:
            name, edits, expected = state[0], state[1], state[2]
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
