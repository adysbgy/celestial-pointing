#!/usr/bin/env python3
"""Buktikan gerbang **penambahan opasitas inti gugus** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

Penambahan opasitas inti bintang gugus hidup sebagai literal `0.25` di **dua**
bahasa sekaligus -- `core.opacity(min(1, star.opacity + 0.25))` di view dan
`op + 0.25` di port -- tanpa satu pun gerbang yang menjaganya. Terukur di
siklus ini (`Tools/bukti-mutasi-inti-opasitas.py`):

    view  'star.opacity + 0.25' -> 'star.opacity + 0.55'   0 merah baru
    port  'op + 0.25'           -> 'op + 0.55'             4 merah baru

Arah **view** buta total: 22 gerbang yang membaca berkas view semuanya hijau
saat angka yang benar-benar menggambar di jam diubah. Dan arah **port** hanya
berbunyi karena **kebetulan**: yang merah adalah
`check_cluster_core_docstring_quotes_measured_values`, yang mengutip angka
piksel yang kebetulan bergeser -- bukan pemeriksaan yang menyebut angka itu.
Gerbang yang berbunyi karena sebab lain akan berhenti berbunyi begitu docstring
itu disunting, dan tidak ada yang akan tahu.

Bentuk cacatnya sama persis dengan `moonSphereGradientEndRadius`:
**satu angka, dua bahasa, nol penjaga**. Yang membedakan hanya kelas objeknya.

Perbaikan yang dibuktikan di sini: angka itu pindah ke model
(`VisualFrame.clusterCoreBrighten`), dan tiga pemeriksaan baru mengikatnya
-- port == model, teks model masih tertulis, dan view **membacanya dari model**
alih-alih menulisnya sendiri.

**Yang diperbaiki pada 16 Okt 2026: harapan yang tidak pernah diukur.** Ketiga
keadaan di berkas ini menyebut harapan yang diwarisi dari siklus saat gerbangnya
masih beda bentuk — dan diukur ulang ternyata **salah di tiga tempat**. Harness
yang hijau palsu lebih berbahaya daripada harness yang merah jujur: yang merah
jujur memaksa orang memperbaikinya, yang hijau-palsu menonaktifkan ceritanya.

Jadi yang dikerjakan bukan melonggarkan harapan sampai cocok. Yang dikerjakan:

  1. Setiap keadaan **diukur** dengan probe proses baru (sumber dimutasi,
     dipulihkan terverifikasi, md5 dicocokkan) sebelum harapannya ditulis.
  2. Keadaan **baru** ditambahkan: boost **dibuang sepenuhnya**
     (`0.25 -> 0.0`). Harapan lama mengklaim `CORE` menangkap perubahan angka
     ini; keadaan 5 membuktikan sebaliknya — kontras terkecil hanya jatuh
     1.687 → 1.537 menghadap ambang 1.10. Jadi `check_cluster_cores_reach_the_
     picture` menjaga **keberadaan** inti, bukan **kekuatan** boost-nya, dan
     yang mencatat kekuatannya adalah `DOC`.

Matriks terukurnya ada di deklarasi `STATES`.

Tiga tingkat verdict, dan itu bukan kerapian:

  * **hijau** -- gerbangnya tidak berbunyi, dan pada keadaan itu memang
    seharusnya tidak berbunyi.
  * **merah** -- gerbangnya berbunyi.
  * **TIDAK ADA** -- pemeriksaan yang dituntut tidak ada sama sekali. Ini
    sengaja bukan hijau: gerbang yang hilang akan terbaca sebagai lulus.

Berkas sumber produksi dimutasi dengan sengaja lalu dipulihkan di `finally`
per keadaan, plus handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup. Penulisan & pemulihannya lewat `mutasi_sumber`,
sama seperti harness lain -- dan `require_clean_sources` menolak jalan kalau
berkas produksi sudah menyimpang dari HEAD. Itu bukan teori di berkas ini:
mutasi nyasar `0.7 -> 0.4` pada kabut Venus pernah tertinggal di view karena
siklus sebelumnya mati di tengah probe.

Pakai:
    python3 Tools/bukti-mutasi-inti-opasitas.py    # 0 = semua sesuai harapan
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
# bukan dipakai diam-diam.
MODEL_ANCHOR = "clusterCoreBrighten: Double = 0.25"
MODEL_DEEPER = "clusterCoreBrighten: Double = 0.55"
PORT_ANCHOR = "CLUSTER_CORE_BRIGHTEN = 0.25"
PORT_DEEPER = "CLUSTER_CORE_BRIGHTEN = 0.55"

# Jalur inti gugus di view. Keadaan inilah yang **buta total** sebelum siklus
# ini: mengganti pemakaian model menjadi literal tidak menggerakkan satu pun
# dari 22 gerbang yang membaca berkas view.
VIEW_USE = (
    "star.opacity + CGFloat(VisualFrame.clusterCoreBrighten)",
    "star.opacity + CGFloat(0.25)")

PORT_CONST = "check_port_matches_swift_constants"
CORE = "check_cluster_cores_reach_the_picture"
DOC = "check_cluster_core_docstring_quotes_measured_values"

# Nama pemeriksaan tingkat-isi (bukan tingkat-fungsi).
P_BRIGHTEN = "port sejalan: inti gugus: penambahan opasitas (port == model)"
S_BRIGHTEN = "sumber memuat: inti gugus: penambahan opasitas (port == model)"
P_READS = ("port sejalan: inti gugus: view membaca penambahan opasitas "
           "dari model")
S_READS = ("sumber memuat: inti gugus: view membaca penambahan opasitas "
           "dari model")

HIJAU = "hijau"
MERAH = "merah"

ALL = ",".join((PORT_CONST, CORE, DOC))

# ── Harapan yang DIUKUR, bukan diwarisi ──────────────────────────────────
#
# Sebelum siklus ini empat keadaan di bawah menyebut harapan yang **tidak
# pernah diukur ulang** — diwarisi dari siklus saat gerbangnya masih beda
# bentuk. Yang terukur di siklus ini (probe proses baru, sumber dimutasi,
# dipulihkan terverifikasi) adalah matriks berikut. Perhatikan bahwa ia
# **berbeda** dari yang tertulis sebelumnya di tiga tempat.
#
#   keadaan        port sejalan  sumber memuat   CORE   DOC   view membaca
#   baseline       OK            OK               OK     OK    OK
#   1 view→lit     OK            OK               OK     OK    MERAH
#   2 model→.55    OK            MERAH            OK     OK    OK
#   3 port→.55     MERAH         OK               OK     MERAH OK
#   4 model+port   MERAH         MERAH            OK     MERAH OK
#   5 boost→0      MERAH         MERAH            OK     MERAH OK
#
# Tiga hal yang perlu dicatat, karena ketiganya terukur dan ketiganya
# bertentangan dengan harapan lama:
#
# 1. **`port sejalan` tidak merah di keadaan 2.** Gerbang itu membandingkan
#    `R.CLUSTER_CORE_BRIGHTEN` dengan **literal 0.25 yang ditulis di dalam
#    tabelnya sendiri**, bukan dengan nilai model. Jadi mengubah model saja
#    memang membuat model dan port berbeda, tetapi gerbang itu tidak melihat
#    model — ia melihat teks `clusterCoreBrighten: Double = 0.25`. Yang
#    menangkap keadaan 2 adalah `sumber memuat` (teksnya hilang).
# 2. **`CORE` tidak pernah merah.** Angka ini **sampai ke gambar** — itu
#    dipakai `canvas.fill` di port — tetapi gerbang gambarnya buta terhadap
#    besarnya. Diukur, dengan `clusterCoreBrighten` **dibuang sepenuhnya**
#    (keadaan 5): kontras terkecil jatuh dari 1.687 ke 1.537 menghadap
#    ambang 1.10, ketajaman terkecil dari 0.526 ke 0.476 menghadap ambang
#    0.20. Keduanya tetap hijau. Jadi kehilangan boost 25% tidak bergerak
#    di bawah ambang mana pun — dan harapan lama yang menuntut `CORE` merah
#    adalah harapan yang tidak bisa dipenuhi oleh gerbang yang benar.
# 3. **`DOC` merah di keadaan 3, 4, dan 5 — bukan cuma keadaan 3.** Angka
#    kutipan docstring dihitung dari piksel, jadi begitu boost berubah
#    nilainya ikut bergeser. Itu bukan efek samping yang mengganggu: ia
#    justru bukti bahwa angka docstring benar-benar keluar dari penyampel
#    yang sama. Yang lama tidak menyebutnya sama sekali di keadaan 4 dan 5.

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline]", None,
     {PORT_CONST: HIJAU, CORE: HIJAU, DOC: HIJAU,
      P_BRIGHTEN: HIJAU, S_BRIGHTEN: HIJAU, P_READS: HIJAU, S_READS: HIJAU}),

    # ── 1. View menulis angkanya sendiri ─────────────────────────────────
    #
    # Keadaan yang **buta total** sebelum siklus ini: 0 merah dari 22 gerbang.
    # Sekarang dua pemeriksaan `view membaca … dari model` yang menangkapnya.
    #
    # Gerbang gambar sengaja tetap **hijau**: mereka mengukur render **port**,
    # dan port memang tidak disentuh. Kalau mereka ikut merah, yang berubah
    # bukan gerbangnya melainkan arti metriknya.
    #
    # Terukur: 3 merah (PORT_CONST karena `StarGlow`-nya ikut tertulis dua kali
    # di berkas yang sama, P_READS + S_READS). Lihat matriks di atas.
    ("1. view: pemakaian model -> literal 0.25",
     [(VIEW, VIEW_USE[0], VIEW_USE[1])],
     {P_READS: MERAH, S_READS: MERAH,
      PORT_CONST: MERAH, P_BRIGHTEN: HIJAU, S_BRIGHTEN: HIJAU,
      CORE: HIJAU, DOC: HIJAU}),

    # ── 2. Model berubah, port & view tidak ikut ─────────────────────────
    #
    # Keadaan yang paling mungkin terjadi di dunia nyata: orang yang
    # memperbaiki tampilan gugus menyunting **model** di Mac.
    #
    # Terukur: **satu** merah — `sumber memuat`, bukan `port sejalan`.
    # Harapan lama menuntut `port sejalan` merah, dan itu harapan yang salah:
    # gerbang itu membandingkan `R.CLUSTER_CORE_BRIGHTEN` dengan literal 0.25
    # di tabelnya sendiri, jadi model yang berubah tidak terlihat olehnya.
    # Yang membuat keadaan ini tetap tertangkap adalah `sumber memuat` — teks
    # `clusterCoreBrighten: Double = 0.25` memang hilang dari model, dan
    # pemeriksaan itu menuntut teks itu ada. Itu menangkap **penghapusan**,
    # bukan perubahan: `= 0.55` lolos `sumber memuat` karena bacaannya
    # masih `= 0.25` → GAGAL. Perhatikan bahwa ini berarti perubahan model
    # **ke angka apa pun** yang tidak 0.25 membuat `sumber memuat` merah.
    ("2. model 0.25 -> 0.55, port & view tidak ikut",
     [(MODEL, MODEL_ANCHOR, MODEL_DEEPER)],
     {PORT_CONST: MERAH, S_BRIGHTEN: MERAH,
      P_BRIGHTEN: HIJAU, P_READS: HIJAU, S_READS: HIJAU,
      CORE: HIJAU, DOC: HIJAU}),

    # ── 3. Port berubah, model & view tidak ikut ─────────────────────────
    #
    # Arah "orang menyunting gambar di Linux". Sebelum siklus ini arah ini
    # berbunyi, tetapi **bukan karena gerbang yang menyebut angka ini** --
    # melainkan karena docstring yang mengutip piksel. Dibedakan di sini:
    # yang diharapkan merah adalah pemeriksaan pasangan angkanya.
    #
    # Terukur: `port sejalan` MERAH (angka port sekarang 0.55 ≠ literal 0.25),
    # dan `DOC` ikut merah karena angka kutipannya dihitung dari piksel.
    # `CORE` **hijau**, dan itu benar — lihat keadaan 5 untuk batasnya.
    ("3. port 0.25 -> 0.55, model & view tidak ikut",
     [(RENDER, PORT_ANCHOR, PORT_DEEPER)],
     {P_BRIGHTEN: MERAH, CORE: HIJAU, DOC: MERAH,
      S_BRIGHTEN: HIJAU, PORT_CONST: MERAH,
      P_READS: HIJAU, S_READS: HIJAU}),

    # ── 4. Model dan port berubah bersama ────────────────────────────────
    #
    # Pembeda "mengukur penyimpangan" dari "mengukur nilainya". Di sini tidak
    # ada penyimpangan antarbahasa, jadi pemeriksaan **kesamaan**-nya hijau --
    # dan itu benar. Yang merah adalah yang menyematkan **nilai** 0.25.
    #
    # Terukur: `port sejalan` MERAH juga. Alasannya sama dengan keadaan 2 —
    # yang dibandingkan adalah literal 0.25, dan kedua bahasa kini 0.55.
    # Dua merah isi (`P_` + `S_`) plus `DOC` yang menggeser angkanya.
    ("4. model DAN port 0.25 -> 0.55 (sepakat, sama-sama berbeda)",
     [(MODEL, MODEL_ANCHOR, MODEL_DEEPER),
      (RENDER, PORT_ANCHOR, PORT_DEEPER)],
     {S_BRIGHTEN: MERAH, P_BRIGHTEN: MERAH, CORE: HIJAU, DOC: MERAH,
      PORT_CONST: MERAH, P_READS: HIJAU, S_READS: HIJAU}),

    # ── 5. Boost dibuang sepenuhnya ──────────────────────────────────────
    #
    # Keadaan **baru** di siklus ini, dan ia ada karena harapan lama
    # mengklaim `CORE` menangkap perubahan angka ini. Diukur: tidak.
    #
    # `clusterCoreBrighten` **sampai ke gambar** — dipakai `canvas.fill` di
    # port untuk inti tiap bintang gugus. Tapi menggesernya tidak membuat
    # satu pun gerbang gambarnya berbunyi, karena yang diukur ambangnya
    # bukan besarnya:
    #
    #                    kontras terkecil          ketajaman terkecil
    #   baseline         1.687  (ambang 1.10)      0.526 (ambang 0.20)
    #   boost 0.25→0     1.537  (ambang 1.10)      0.476 (ambang 0.20)
    #
    # Keduanya jatuh ~9% dan tetap jauh di atas ambang. Jadi keadaan ini
    # **membuktikan** bahwa `check_cluster_cores_reach_the_picture` menjaga
    # **keberadaan** inti, bukan **kekuatan** boost-nya — dan `DOC` yang
    # mencatat pergeserannya, bukan `CORE`.
    #
    # Batas yang jujur: angka di atas adalah margin, bukan bukti bahwa boost
    # ini tidak berpengaruh visual. Ia berpengaruh; yang tidak punya penjaga
    # adalah **ambang** bawahnya. Itu cacat yang bisa diperbaiki, tetapi
    # memperbaikinya berarti memilih ambang baru — keputusan yang layak
    # diukur di siklusnya sendiri, bukan didiami di sini.
    ("5. model DAN port: boost dibuang (0.25 -> 0.0)",
     [(MODEL, MODEL_ANCHOR, "clusterCoreBrighten: Double = 0.0"),
      (RENDER, PORT_ANCHOR, "CLUSTER_CORE_BRIGHTEN = 0.0")],
     {S_BRIGHTEN: MERAH, P_BRIGHTEN: MERAH, CORE: HIJAU, DOC: MERAH,
      PORT_CONST: MERAH, P_READS: HIJAU, S_READS: HIJAU}),
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
