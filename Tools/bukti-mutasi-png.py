#!/usr/bin/env python3
"""Buktikan dua gerbang PNG berbunyi — dan bahwa keduanya **tidak** mubazir.

Kenapa harness ini ada.

`check_png_is_well_formed` dan `check_png_roundtrip` adalah dua gerbang yang
menjaga berkas keluaran `Tools/render-visuals.py` benar-benar PNG yang bisa
dibaca dunia luar. Keduanya hijau pada hari ditulis, dan — sampai siklus ini —
**tidak dirujuk satu pun** harness `bukti-mutasi-*.py`. Dari 84 `check_*` di
`check-visuals.py`, 16 masih nirsaksi; kedua ini termasuk di dalamnya.

Kenapa keduanya layak, bukan gerbang pinggiran: cacat yang ditutupnya **sudah
pernah nyata** dan pernah bertahan lama. `Canvas.to_png` dulu menulis barisnya
tanpa byte filter sementara `_png()` mengklaim menyisipkannya; arus IDAT jadi
`h · w · 4` sedangkan spesifikasi menuntut `h · (w · 4 + 1)`, sehingga Preview,
browser, dan `ffmpeg` menolak berkasnya — sementara `check_png_roundtrip`
**lulus**, karena `decode_png` sengaja toleran terhadap bentuk yang salah itu.
Pembaca dan penulis repo ini sepakat satu sama lain; dunia luar tidak.

Yang diukur harness ini adalah **verdict dua gerbang**, dijalankan langsung
lewat `check-visuals` yang di-import ulang dari berkas yang sudah dimutasi:

  keadaan                                            well_formed   roundtrip
  [baseline]                                         hijau         hijau
  1. byte filter dihapus dari `_png`                 MERAH         hijau
  2. byte filter di luar 0…4 (0x05)                  MERAH         hijau
  3. byte filter dideklarasikan, barisnya tidak      hijau         MERAH
     difilter (filter 1)
  4. `to_png` ikut menyisipkan filter (ganda)        hijau         MERAH
  5. level kompresi 9 -> 1                           hijau         hijau

### Kenapa keadaan 1 dan 2 harus **hijau** di `roundtrip`

Ini bagian yang paling mudah salah, dan ia ditemukan dengan mengukur, bukan
dengan berpikir: pada keadaan 1 dan 2 `check_png_roundtrip` memang **hijau**,
dan itu **benar**. `decode_png` memilih cabang "tanpa byte filter" ketika
panjang arusnya `h · w · 4`, lalu memakai `ftype = 0` untuk setiap baris —
sehingga pembaca dan penulisnya tetap sepakat dan pikselnya tetap persis.
Artinya `check_png_roundtrip` **tidak bisa** menangkap byte filter yang hilang;
itu pekerjaan `check_png_is_well_formed`, dan itulah alasan gerbang kedua ada
terpisah.

Harness yang menuntut `roundtrip` merah di keadaan 1 dan 2 akan merah pada kode
yang benar, dan orang berikutnya akan "memperbaiki" gerbangnya. Arah yang
sebenarnya justru lebih sempit: masing-masing gerbang merah di keadaan yang
**berbeda**, jadi kedua-duanya menjaga sesuatu.

### Keadaan 3 dan 4: bentuk yang paling sunyi

Keadaan 1 dan 2 keduanya terlihat dari **panjang arus**. Keadaan 3 menutup
bentuk yang tidak: panjangnya tepat `h · (w · 4 + 1)` — jadi
`check_png_is_well_formed` **hijau** — tetapi setiap baris mendeklarasikan
filter 1 (Sub) tanpa benar-benar menyubtitusi tetangganya. PNG-nya **sah menurut
struktur** dan **salah menurut isi**: `decode_png` menerapkan filter 1 dan
mengembalikan baris yang tergeser. Diukur: **4032 piksel** berbeda dari buffer
di memori pada setiap kasus (dari 4096). Gerbang yang mengukur bentuk saja akan
hijau di sini, dan berkasnya tidak bisa dibuka siapa pun.

Keadaan 4 adalah cacat aslinya dari arah sebaliknya — `to_png` ikut
menyisipkan filter **dan** `_png` menyisipkannya lagi, persis kekeliruan yang
pernah menjatuhkan gambar ke "setiap baris bergeser satu byte". `well_formed`
tetap hijau (panjang dan tipe filternya sah), `roundtrip` merah di keempat
kasus dengan jumlah piksel yang **berbeda-beda** (3978/3400/3456/3691) — karena
yang bergeser adalah isi gambar, bukan bentuk berkasnya.

### Keadaan 5: satu mekanisme, format tetap sah

`zlib.compress(raw, 9)` → `1`. Panjang arus tetap, jumlah baris tetap, tipe
filter tetap 0…4, dan bolak-baliknya tetap persis — jadi **kedua** gerbang hijau.
Itu dinyatakan di sini supaya batas cakupannya tertulis: **tidak ada satu pun**
pemeriksaan di repo ini yang menjaga tingkat kompresi berkas keluaran. Keadaan
ini juga **kontrol negatif** untuk keadaan 1–4: kalau ia memerah, yang berubah
bukan mekanisme yang saya kira, dan seluruh himpunan harapan di atas tidak
berarti.

### Yang TIDAK diklaim

  - Gerbang ini **tidak** membaca PNG yang dibuka manusia di layar, dan tidak
    membuktikan gambarnya benar — hanya bahwa berkasnya sah dan bolak-baliknya
    persis. Kebenaran gambarnya dijaga 80+ gerbang piksel lain.
  - Keadaan 3 dan 4 **tidak** membuktikan `check_png_is_well_formed` menangkap
    setiap PNG yang rusak: keduanya sengaja dibuat **sah menurut struktur**.
    Yang dibuktikan justru pembagian tugasnya: satu gerbang menjaga bentuk,
    satu menjaga isi.
  - `decode_png` di `check-visuals.py` tetap toleran terhadap bentuk tanpa byte
    filter (untuk membaca berkas lama di `out/`). Toleransi itu tidak diubah,
    dan karena itu `check_png_is_well_formed` tidak boleh dihapus: ia
    satu-satunya yang menegakkan spesifikasinya.

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus handler
`SIGINT`/`SIGTERM`. `require_clean_sources` menolak jalan bila berkasnya sudah
menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-png.py     # 0 = sesuai harapan
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

# ── Nama hasil di dalam kedua gerbang ────────────────────────────────────
# Dituntut **persis**, per kasus render: perubahan nama hasil di gerbang harus
# membuat berkas ini merah, bukan diam-diam mencocokkan himpunan kosong.
# Himpunan kosong selalu "sesuai harapan", dan itu bentuk paling sunyi dari
# harness yang tidak mengukur apa pun.
WELL_FORMED = "check_png_is_well_formed"
ROUNDTRIP = "check_png_roundtrip"

#: Kasus render yang diperiksa kedua gerbang — dibaca dari `build_cases()`
#: saat harness jalan, bukan ditulis ulang di sini, supaya menambah kasus di
#: gerbang tidak meninggalkan daftar tangan yang basi.
def _case_names():
    probe = (
        "import importlib.util, os, sys\n"
        "sys.path.insert(0, os.path.join(sys.argv[1], 'Tools'))\n"
        "sys.dont_write_bytecode = True\n"
        "spec = importlib.util.spec_from_file_location('r', "
        "os.path.join(sys.argv[1], 'Tools', 'render-visuals.py'))\n"
        "m = importlib.util.module_from_spec(spec)\n"
        "spec.loader.exec_module(m)\n"
        "print('\\n'.join(c.name for c in m.build_cases()))\n"
    )
    out = subprocess.run([sys.executable, "-c", probe, ROOT],
                         capture_output=True, text=True, timeout=600)
    if out.returncode != 0:
        raise SystemExit("tidak bisa membaca build_cases(): " + out.stderr[-800:])
    return [line.strip() for line in out.stdout.splitlines() if line.strip()]


CASES = _case_names()

HIJAU = "hijau"
MERAH = "merah"


def _well_formed(verdict=HIJAU):
    """Verdict `check_png_is_well_formed` untuk keempat kasusnya."""
    names = [f"PNG sah: {name}" for name in
             ("planet-jupiter-confirmed", "moon-crescent-jakarta",
              "star-betelgeuse", "deepsky-nebula")]
    return {WELL_FORMED: verdict, **{n: verdict for n in names}}


def _roundtrip(verdict=HIJAU):
    """Verdict `check_png_roundtrip` untuk keempat kasusnya."""
    names = [f"PNG bolak-balik: {name}" for name in
             ("planet-jupiter-confirmed", "moon-crescent-jakarta",
              "star-betelgeuse", "deepsky-nebula")]
    return {ROUNDTRIP: verdict, **{n: verdict for n in names}}


def _expect(well_formed=HIJAU, roundtrip=HIJAU):
    return {**_well_formed(well_formed), **_roundtrip(roundtrip)}


# ── Jangkar di dalam port ────────────────────────────────────────────────
# Keduanya diperiksa jumlah kemunculannya (harus 1) sebelum dipakai. Jangkar
# yang menjadi ambigu dilaporkan sebagai kelemahan bukti, bukan dipakai
# diam-diam.

#: Baris yang menyisipkan satu byte filter 0 per baris — inti spesifikasi PNG.
FILTER_INSERT = (
    '    raw = b"".join(b"\\x00" + pixels[y * width * 4:(y + 1) * width * 4]\n'
    '                   for y in range(height))')

#: Sama, tanpa byte filternya. Bentuk inilah yang dulu ada di repo.
FILTER_MISSING = (
    '    raw = b"".join(pixels[y * width * 4:(y + 1) * width * 4]\n'
    '                   for y in range(height))')

#: Sama, dengan byte filter **di luar** 0…4.
FILTER_OUT_OF_RANGE = (
    '    raw = b"".join(b"\\x05" + pixels[y * width * 4:(y + 1) * width * 4]\n'
    '                   for y in range(height))')

#: Filter 1 (Sub) **dideklarasikan** tanpa isinya benar-benar difilter.
#: Panjangnya tepat `h · (w · 4 + 1)` — sah menurut struktur, salah menurut isi.
FILTER_DECLARED_SUB = (
    '    raw = b"".join(b"\\x01" + pixels[y * width * 4:(y + 1) * width * 4]\n'
    '                   for y in range(height))')

#: Gelung penulis baris di `to_png`, sebelum `_png` menyisipkan filternya.
TO_PNG_ROWS = ('        for y in range(self.h):\n'
               '            for x in range(self.w):\n'
               '                r, g, b = self.buf[y * self.w + x]')
#: Cacat aslinya: `to_png` ikut menyisipkan byte filter, lalu `_png` lagi.
TO_PNG_ROWS_FILTERED = ('        for y in range(self.h):\n'
                        '            raw += b"\\x00"\n'
                        '            for x in range(self.w):\n'
                        '                r, g, b = self.buf[y * self.w + x]')

#: Tingkat kompresi. Tidak dijaga gerbang mana pun — lihat keadaan 5.
COMPRESS = "zlib.compress(raw, 9)"
COMPRESS_FAST = "zlib.compress(raw, 1)"

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
# **Dua tingkat verdict, dan itu bukan kerapian.**
#
# Versi pertama PROBE ini hanya mencetak nama **hasil** di dalam tiap gerbang,
# sehingga kedua kunci berbentuk fungsi tidak pernah muncul dan seluruh enam
# keadaan melaporkan "hasil hilang: [check_png_is_well_formed,
# check_png_roundtrip]" — harness yang tidak akan pernah bisa hijau. Yang
# menangkapnya adalah disiplin himpunan **persis**: kalau harness ini hanya
# menuntut "ada yang merah", kekeliruan itu akan lolos sebagai laporan hijau.
#
# Tingkat fungsi juga **dibutuhkan** oleh keadaan 3: di sana
# `check_png_is_well_formed` harus **hijau** sementara `check_png_roundtrip`
# merah. Tanpa baris tingkat fungsi, pembeda "bentuk sah" dari "isi salah"
# tidak bisa dinyatakan — dan justru pembeda itulah temuannya.
#
# Hijau tingkat fungsi = gerbangnya **ada** DAN semuanya lolos. Himpunan
# kosong sengaja **bukan** hijau: gerbang yang hijau karena tidak mengukur
# apa pun adalah kelas cacat yang seluruh repo ini kejar, dan di sini ia
# akan tampak sebagai gerbang yang lulus tanpa satu pun hasil.
for name in sys.argv[2].split(","):
    results = []
    try:
        getattr(C, name)(results)
    except Exception as exc:
        print("ERR " + name + ": " + type(exc).__name__ + ": " + str(exc)[:200])
        continue
    ok = bool(results) and all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  | " + r.detail)
"""

NAMES = f"{WELL_FORMED},{ROUNDTRIP}"

# (nama keadaan, [(cari, ganti), ...] atau None, {nama hasil: harapan})
STATES = [
    ("[baseline] sumber bersih", None, _expect()),

    # ── 1. Byte filter dihapus seluruhnya ────────────────────────────────
    # Cacat aslinya. Panjang arus jatuh ke `h · w · 4`, dan hanya
    # `check_png_is_well_formed` yang membacanya **secara langsung**.
    # `roundtrip` **wajib hijau** di sini: `decode_png` memilih cabang tanpa
    # filter dan tetap mengembalikan piksel yang persis. Lihat docstring.
    ("1. byte filter dihapus dari _png (cacat aslinya)",
     [(FILTER_INSERT, FILTER_MISSING)],
     _expect(well_formed=MERAH, roundtrip=HIJAU)),

    # ── 2. Byte filter di luar 0…4 ───────────────────────────────────────
    # Panjangnya benar, tipenya tidak. Pembaca mana pun menolaknya.
    ("2. byte filter di luar 0..4 (0x05)",
     [(FILTER_INSERT, FILTER_OUT_OF_RANGE)],
     _expect(well_formed=MERAH, roundtrip=HIJAU)),

    # ── 3. Bentuk sah, isi salah ─────────────────────────────────────────
    # Filter 1 dideklarasikan tanpa isinya difilter. `well_formed` **wajib
    # hijau** — panjang dan tipe filternya memang sah — dan justru itu yang
    # membuktikan kedua gerbang tidak mengukur hal yang sama.
    ("3. filter 1 dideklarasikan, barisnya tidak difilter",
     [(FILTER_INSERT, FILTER_DECLARED_SUB)],
     _expect(well_formed=HIJAU, roundtrip=MERAH)),

    # ── 4. Filter ganda (cacat aslinya, arah sebaliknya) ─────────────────
    # `to_png` menyisipkan filter, `_png` menyisipkannya lagi: setiap baris
    # bergeser satu byte. Bentuk berkasnya tetap sah, isinya tidak.
    ("4. to_png ikut menyisipkan byte filter (ganda)",
     [(TO_PNG_ROWS, TO_PNG_ROWS_FILTERED)],
     _expect(well_formed=HIJAU, roundtrip=MERAH)),

    # ── 5. Kontrol negatif: mekanisme lain, format tetap sah ─────────────
    # Tingkat kompresi 9 -> 1. Kedua gerbang **wajib hijau**: tidak ada satu
    # pun pemeriksaan di repo ini yang menjaganya. Kalau keadaan ini memerah,
    # yang berubah bukan mekanisme yang saya kira, dan seluruh himpunan
    # harapan di atas tidak berarti.
    ("5. kontrol negatif: level kompresi 9 -> 1 (tidak dijaga)",
     [(COMPRESS, COMPRESS_FAST)],
     _expect()),
]


def run_probe():
    """Jalankan kedua gerbang di proses baru. → (verdicts, galat)."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, NAMES],
                         capture_output=True, text=True, timeout=1800)
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
    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        mutasi_sumber.restore_verified(RENDER, original)

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
                content = original.decode()
                for find, replace in edits:
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: "
                            f"{find[:70]!r}")
                        break
                    content = content.replace(find, replace)
                else:
                    mutasi_sumber.write_source(RENDER, content)

            verdicts, error = run_probe()
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            # Himpunan hasilnya dibandingkan **persis**. Ini menangkap tiga
            # hal sekaligus, dan ketiganya berbeda: hasil yang hilang
            # (gerbang berhenti lebih awal), hasil yang muncul tanpa
            # diharapkan (gerbang mengubah cakupannya), dan verdict yang
            # salah. Himpunan kosong tidak pernah lulus.
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
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
