#!/usr/bin/env python3
"""Buktikan gerbang **penambahan opasitas inti gugus** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

Penambahan opasitas inti bintang gugus hidup sebagai literal `0.25` di **dua**
bahasa sekaligus -- `core.opacity(min(1, star.opacity + 0.25))` di view dan
`op + 0.25` di port -- tanpa satu pun gerbang yang menjaganya. Terukur di
siklus ini (`Tools/ukur-gugus.py`):

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
    ("1. view: pemakaian model -> literal 0.25",
     [(VIEW, VIEW_USE[0], VIEW_USE[1])],
     {P_READS: MERAH, S_READS: MERAH,
      PORT_CONST: MERAH, P_BRIGHTEN: HIJAU, S_BRIGHTEN: HIJAU,
      CORE: HIJAU, DOC: HIJAU}),

    # ── 2. Model berubah, port & view tidak ikut ─────────────────────────
    #
    # Keadaan yang paling mungkin terjadi di dunia nyata: orang yang
    # memperbaiki tampilan gugus menyunting **model** di Mac.
    ("2. model 0.25 -> 0.55, port & view tidak ikut",
     [(MODEL, MODEL_ANCHOR, MODEL_DEEPER)],
     {PORT_CONST: MERAH, S_BRIGHTEN: MERAH, P_BRIGHTEN: MERAH,
      CORE: HIJAU, DOC: HIJAU}),

    # ── 3. Port berubah, model & view tidak ikut ─────────────────────────
    #
    # Arah "orang menyunting gambar di Linux". Sebelum siklus ini arah ini
    # berbunyi, tetapi **bukan karena gerbang yang menyebut angka ini** --
    # melainkan karena docstring yang mengutip piksel. Dibedakan di sini:
    # yang diharapkan merah adalah pemeriksaan pasangan angkanya.
    ("3. port 0.25 -> 0.55, model & view tidak ikut",
     [(RENDER, PORT_ANCHOR, PORT_DEEPER)],
     {P_BRIGHTEN: MERAH, CORE: MERAH,
      S_BRIGHTEN: HIJAU, DOC: HIJAU}),

    # ── 4. Model dan port berubah bersama ────────────────────────────────
    #
    # Pembeda "mengukur penyimpangan" dari "mengukur nilainya". Di sini tidak
    # ada penyimpangan antarbahasa, jadi pemeriksaan **kesamaan**-nya hijau --
    # dan itu benar. Yang merah adalah yang menyematkan **nilai** 0.25.
    ("4. model DAN port 0.25 -> 0.55 (sepakat, sama-sama berbeda)",
     [(MODEL, MODEL_ANCHOR, MODEL_DEEPER),
      (RENDER, PORT_ANCHOR, PORT_DEEPER)],
     {S_BRIGHTEN: MERAH, CORE: MERAH,
      P_BRIGHTEN: HIJAU, DOC: HIJAU}),
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
