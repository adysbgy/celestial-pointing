#!/usr/bin/env python3
"""Buktikan gerbang **konversi warna bintang** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

`check_star_rgb_conversion_matches_the_model` menjaga **tujuh koefisien** yang
mengubah indeks B−V menjadi warna: dua batas penjepit, `warmth_offset`,
`warmth_span`, dan tiga pasangan (basis, kemiringan) kanal. Tujuh angka itu
hidup **dua kali** — `CelestialVisual.starRGB(forColorIndex:)` di Swift dan
`star_rgb` di `render-visuals.py` — dan inilah satu-satunya pemeriksaan yang
membandingkan keduanya.

Sampai siklus ini ia **belum pernah merah**. Dari 83 gerbang di
`check-visuals.py`, 16 tidak dirujuk harness mana pun, dan gerbang yang belum
pernah dijalankan dalam keadaan rusak tidak bisa dibedakan dari gerbang yang
tidak mengukur apa pun. Docstring-nya mengutip satu angka mutasi ("297
pemeriksaan visual, 637 uji Swift, 28 aturan lint tetap hijau") untuk cacat
yang ia tutup — angka yang **diwarisi**, bukan diukur ulang di sini.

Yang diukur harness ini, dijalankan langsung lewat `check-visuals` yang
di-import ulang dari berkas yang sudah dimutasi:

  keadaan                                        hasil gerbang
  [baseline]                                     hijau (0 merah dari 9)
  1. port: penjepit bawah -0.5 -> -0.4           MERAH clamp_low + hasil
  2. model: span 1.70 -> 1.60, port merah -0.02  MERAH span + kanal + hasil
  3. model DAN port: span 1.70 -> 1.75           hijau  <- bukan cacat
  4. model: penjepit B−V dibuang                 MERAH bentuk (1 hasil)
  5. port: baris tambahan menyalakan warmth      MERAH hasil saja
  6. port: penjepit B−V dibuang                  MERAH bentuk (1 hasil)

Keadaan 3 adalah yang paling penting, dan ia **wajib hijau**. Dua bahasa yang
berubah bersama dengan nilai yang sama **bukan penyimpangan**: tidak ada yang
tampil di jam berbeda dari yang digerbangi. Harness yang memerah di sana akan
mengajarkan orang bahwa "gerbang ini menolak setiap suntingan warna" — dan
gerbang yang dilonggarkan tidak menjaga apa pun.

Keadaan 5 adalah bentuk paling sunyi yang bisa menimpa rumus ini, dan ia
satu-satunya alasan pemeriksaan **hasil** ada terpisah dari daftar koefisien.
Seluruh deklarasi yang dibaca gerbang tetap utuh — penjepit `-0.5…2.0`,
`warmth_offset` 0.35, `warmth_span` 1.70, ketiga basis kanal — dan sebuah baris
tambahan **di bawahnya** menyalakan ulang `warmth` dengan faktor 0.9.
Perbandingan koefisien **hijau seluruhnya**; yang berbunyi hanya pemeriksaan
hasil, karena ia membandingkan `star_rgb(i)` sungguhan lawan rumus yang dibaca
dari sumber. Gerbang yang hanya membandingkan teks akan hijau di sini, dan
warna di jam akan berbeda dari warna yang digerbangi.

Keadaan 4 dan 6 masing-masing membuktikan **pemeriksaan bentuk** bukan hiasan,
dan di dua bahasa yang berbeda: penjepit yang hilang membuat pembaca bentuk
berhenti, dan gerbangnya melaporkan **satu** hasil merah — bukan diam-diam
melewatkan seluruh sisa pemeriksaan seolah lulus. Harness ini menuntut himpunan
hasilnya **persis**, jadi gerbang yang berhenti lebih awal terbaca sebagai
perbedaan bentuk, bukan sebagai kelulusan.

### Arah yang sengaja TIDAK diklaim

  - **Dua bahasa sepakat dan sama-sama salah secara astronomi** (mis. merah
    dan biru ditukar di **kedua** berkas) tidak ditangkap gerbang ini — dan
    memang bukan tugasnya. Yang menjaga arti warnanya `check_star_colour_order`
    (piksel: "Betelgeuse lebih merah dari Rigel") dan
    `testStarColourIsMonotonicInColorIndex`. Gerbang ini mengikat **angkanya**;
    keduanya mengukur **artinya**. Pemisahan itu disengaja: mengubah nilai
    kosmetik tidak memaksa dua tempat berubah.
  - Gerbang ini **tidak** membaca piksel app. `Apps/CelestialVisualView.swift`
    memanggil `CelestialVisual.starRGB` dari paket, jadi yang dijaga di sini
    adalah sisi **port** terhadap **model**. Kalau view berhenti memanggil
    fungsinya, tak satu pun pemeriksaan di sini berbunyi — batas yang
    dinyatakan, bukan disangka tertutup.

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus handler
`SIGINT`/`SIGTERM`: pelajaran yang sudah dibayar repo ini, `SIGKILL` melewati
`finally` dan meninggalkan mutasi hidup. `require_clean_sources` menolak jalan
bila salah satu berkas sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-konversi-warna.py     # 0 = sesuai harapan
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
                           "CelestialVisual.swift")

# ── Nama hasil di dalam gerbang ──────────────────────────────────────────
# Dituntut **persis**. Perubahan nama di gerbang harus membuat berkas ini
# merah, bukan diam-diam mencocokkan himpunan kosong — himpunan kosong selalu
# "sesuai harapan", dan itu bentuk paling sunyi dari harness yang tidak
# mengukur apa pun.
SHAPE_OK = "konversi warna bintang: bentuk terbaca dari kedua bahasa"
#: Nama yang dipakai gerbang saat bentuknya **tidak** terbaca. Gerbangnya
#: berhenti lebih awal di keadaan itu, jadi hanya satu hasil ini yang
#: dilaporkan — dan perbedaan himpunan itulah yang diperiksa harness.
SHAPE_FAIL = "konversi warna bintang: bentuk terbaca"
CLAMP_LOW = "konversi warna bintang: clamp_low"
CLAMP_HIGH = "konversi warna bintang: clamp_high"
WARMTH_OFFSET = "konversi warna bintang: warmth_offset"
WARMTH_SPAN = "konversi warna bintang: warmth_span"
RED_CHANNEL = "konversi warna bintang: koefisien kanal merah"
GREEN_CHANNEL = "konversi warna bintang: koefisien kanal hijau"
BLUE_CHANNEL = "konversi warna bintang: koefisien kanal biru"
SAMPLED = "konversi warna bintang: warna hasil sama di seluruh indeks katalog"

#: Gerbang yang berhasil membaca bentuk selalu melaporkan **sembilan** hasil
#: ini, dalam keadaan apa pun.
FULL_SET = (SHAPE_OK, CLAMP_LOW, CLAMP_HIGH, WARMTH_OFFSET, WARMTH_SPAN,
            RED_CHANNEL, GREEN_CHANNEL, BLUE_CHANNEL, SAMPLED)

HIJAU = "hijau"
MERAH = "merah"

# ── Jangkar ──────────────────────────────────────────────────────────────
# Semuanya diperiksa jumlah kemunculannya sebelum dipakai (harus 1); jangkar
# yang menjadi ambigu dilaporkan sebagai kelemahan bukti, bukan dipakai
# diam-diam. Bentuknya sengaja **berbeda antara kedua bahasa** (`let` di
# Swift, tidak di Python) supaya suntingan tidak bisa tertukar berkas.

MODEL_CLAMP = "        let clamped = min(2.0, max(-0.5, index))"
PORT_CLAMP = "    clamped = min(2.0, max(-0.5, index))"

MODEL_WARMTH = "        let warmth = (clamped + 0.35) / 2.45"
PORT_WARMTH = "    warmth = (clamped + 0.35) / 2.45"

MODEL_RED = "        return RGBComponents(red: unit(0.62 + 0.38 * warmth),"
PORT_RED = "    return (unit(0.62 + 0.38 * warmth),"

#: Dua baris berurutan di port: deklarasi `warmth` **dan** pemakaiannya di
#: kanal merah. Dipakai keadaan 5 untuk menyisipkan baris di antaranya —
#: setelah deklarasi yang dibaca gerbang, sebelum hasil yang dipakai warna.
PORT_WARMTH_THEN_RED = PORT_WARMTH + "\n" + PORT_RED

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
results = []
try:
    C.check_star_rgb_conversion_matches_the_model(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""


def _full(*red):
    """Himpunan hasil lengkap; nama yang disebut di `red` memerah, sisanya hijau."""
    return {name: (MERAH if name in red else HIJAU) for name in FULL_SET}


# ── Keadaan ──────────────────────────────────────────────────────────────
# (nama, [(berkas, cari, ganti), ...] atau None, {nama hasil: harapan})
#
# Himpunan harapannya **lengkap**: gerbang yang berhenti lebih awal (mis.
# karena bentuknya rusak) menghasilkan himpunan yang berbeda, dan perbedaan
# itu sendiri diperiksa — bukan dianggap lulus karena hasil yang tersisa hijau.

STATES = [
    ("[baseline] sumber bersih", None, _full()),

    # ── 1. Arah "port menyimpang", satu angka ────────────────────────────
    # Batas bawah penjepit digeser 0.1. Efeknya pada warna kecil — hanya
    # bintang paling biru yang menyentuh batas itu — jadi keadaan ini juga
    # membuktikan pemeriksaan **koefisien** bekerja, bukan hanya pemeriksaan
    # hasil, yang bisa saja belum berubah pada satu indeks.
    ("1. port: penjepit bawah -0.5 -> -0.4 (port menyimpang)",
     [(RENDER, PORT_CLAMP, "    clamped = min(2.0, max(-0.4, index))")],
     _full(CLAMP_LOW, SAMPLED)),

    # ── 2. Arah "model berubah, port tidak ikut" ─────────────────────────
    # Arah yang **paling mungkin terjadi** di repo dua bahasa ini: warna
    # disunting di model Swift di Mac, port Python tertinggal di Linux.
    # Penyebut span model diubah, dan kanal merah port digeser sekaligus,
    # supaya pemeriksaan **per kanal** ikut terbukti dibaca satu per satu
    # (bukan hanya pemeriksaan penyebut). Hijau & biru tetap hijau, karena
    # memang tidak disentuh: pengikatannya per kanal, bukan sepasang.
    ("2. model: span 2.45 -> 1.60, port kanal merah -0.02",
     [(MODEL, MODEL_WARMTH, "        let warmth = (clamped + 0.35) / 1.60"),
      (RENDER, PORT_RED, PORT_RED.replace("0.62", "0.60"))],
     _full(WARMTH_SPAN, RED_CHANNEL, SAMPLED)),

    # ── 3. Dua bahasa sepakat, nilai berubah — WAJIB HIJAU ───────────────
    # Bukan penyimpangan: tidak ada yang tampil di jam berbeda dari yang
    # digerbangi. Inilah keadaan yang membedakan "gerbang ini mengukur
    # kesamaan antarbahasa" dari "gerbang ini mengunci nilai tertentu".
    # Tanpa keadaan ini, gerbang yang memerah pada setiap suntingan warna
    # akan dilonggarkan orang — dan gerbang yang dilonggarkan tidak menjaga
    # apa pun.
    ("3. model DAN port: span 2.45 -> 1.75 (sepakat, bukan cacat)",
     [(MODEL, MODEL_WARMTH, "        let warmth = (clamped + 0.35) / 1.75"),
      (RENDER, PORT_WARMTH, "    warmth = (clamped + 0.35) / 1.75")],
     _full()),

    # ── 4. Bentuk rusak di **model** ─────────────────────────────────────
    # Penjepit B−V dibuang. Tanpa penjepit, Betelgeuse (B−V 1.85) menghasilkan
    # kanal merah di luar 0…1 — nilai yang lebih terang dari putih, dan
    # luminance-nya ikut terangkat sehingga urutannya terhadap bintang lain
    # berubah. Yang diukur di sini bukan angkanya, melainkan bahwa pembaca
    # bentuk **berhenti** dan gerbangnya melaporkan satu hasil merah, bukan
    # diam-diam melaporkan sisanya seolah lulus.
    ("4. model: penjepit B−V dibuang (bentuk rusak, satu hasil)",
     [(MODEL, MODEL_CLAMP, "        let clamped = index")],
     {SHAPE_FAIL: MERAH}),

    # ── 5. Bentuk paling sunyi: deklarasi utuh, hasil berubah ────────────
    # Seluruh yang dibaca gerbang masih utuh, dan sebuah baris **di bawah**
    # deklarasi menyalakan ulang `warmth` dengan faktor 0.9. Perbandingan
    # koefisien hijau seluruhnya; hanya pemeriksaan hasil yang berbunyi —
    # karena ia membandingkan `star_rgb(i)` sungguhan lawan rumus yang dibaca
    # dari sumber. Gerbang yang hanya membandingkan teks akan hijau di sini,
    # dan warna di jam akan berbeda dari warna yang digerbangi.
    ("5. port: baris tambahan menyalakan ulang warmth (deklarasi utuh)",
     [(RENDER, PORT_WARMTH_THEN_RED,
       PORT_WARMTH + "\n    warmth = warmth * 0.9\n" + PORT_RED)],
     _full(SAMPLED)),

    # ── 6. Bentuk rusak di **port** ──────────────────────────────────────
    # Cerminan keadaan 4 di bahasa yang lain. Keduanya perlu: pembaca bentuk
    # dipanggil dua kali dengan jangkar berbeda, dan satu arah saja tidak
    # membuktikan sisi yang lain benar-benar terbaca.
    ("6. port: penjepit B−V dibuang (bentuk rusak, satu hasil)",
     [(RENDER, PORT_CLAMP, "    clamped = index")],
     {SHAPE_FAIL: MERAH}),
]


def run_probe():
    """Jalankan gerbang di proses baru. → (verdicts, galat)."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=600)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("ERR "):
            continue
        state, rest = line.split(" ", 1)
        name = rest.split("  | ")[0].strip()
        verdicts[name] = HIJAU if state == "OK" else MERAH
    return verdicts, None


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
        for name, edits, expected in STATES:
            restore()
            if edits is not None:
                # Mutasi dikumpulkan per berkas supaya dua suntingan di
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

            verdicts, error = run_probe()
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            # Himpunan hasilnya dibandingkan **persis**. Ini menangkap tiga
            # hal sekaligus, dan ketiganya berbeda: hasil yang hilang
            # (gerbang berhenti lebih awal), hasil yang muncul tanpa
            # diharapkan (gerbang mengubah cakupannya), dan verdict yang
            # salah. Himpunan kosong tidak pernah lulus — gerbang yang tidak
            # menghasilkan apa pun adalah kelas cacat yang seluruh repo ini
            # kejar.
            problems = []
            missing = sorted(set(expected) - set(verdicts))
            extra = sorted(set(verdicts) - set(expected))
            if missing:
                problems.append(f"hasil hilang: {missing}")
            if extra:
                problems.append(f"hasil tak terduga: {extra}")
            wrong = [(n, want, verdicts[n]) for n, want in expected.items()
                     if n in verdicts and verdicts[n] != want]
            if wrong:
                problems.append("verdict salah: " + "; ".join(
                    f"{n} diharapkan {w} terukur {g}" for n, w, g in wrong))

            if problems:
                failures.append(f"{name}: " + " | ".join(problems))
                print(f"{name}: TIDAK SESUAI HARAPAN")
                for item in problems:
                    print(f"    {item}")
            else:
                red = sum(1 for v in verdicts.values() if v == MERAH)
                print(f"{name}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} pemeriksaan)")
    finally:
        restore()

    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        print(f"md5 {os.path.relpath(path, ROOT)}: {digest} -> {after} "
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
