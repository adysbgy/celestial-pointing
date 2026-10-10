#!/usr/bin/env python3
"""Buktikan `check_spiral_arms_actually_spiral` **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis — itu bukan bukti apa pun. Yang
harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada keadaan yang
memang salah.

Kelas cacat yang ditutupnya lebih halus dari biasanya, dan itulah alasannya.
Gerbang lengan yang sudah ada, `check_spiral_arms_stay_continuous`, mengukur
apakah lengan **menyambung** sepanjang jari-jari. Ia benar, dan ia merah kalau
lengannya dihapus. Tapi ia buta terhadap **bentuk**: tata letak `.spiralGalaxy`
diganti dengan **cincin** — jari-jari blob lengan sama persis, tiap jari-jari
disebar merata ke delapan arah — dan seluruh **45 pemeriksaannya hijau**
(terukur, lihat keadaan 1 di bawah). Cincin adalah bentuk yang **salah** untuk
M51/M101, dan justru itu bentuk yang dihasilkan cacat yang paling mungkin
terjadi saat menyunting spiral: menyalin satu titik lengan dan memutarnya,
bukan melanjutkan kurvanya.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                 gerbang hijau (kalau tidak, harness salah)
  1. cincin 8 arah            cacat yang **tidak bisa dilihat** gerbang lama:
                             jari-jari sama, disebar merata. Terukur +0°
                             sapuan, punggungan 26.1 — lengan "ada" di setiap
                             jari-jari, jadi ukuran "ada goresan terang" buta.
  2. cincin 4 arah            cincin yang lebih jarang. Membuktikan gerbangnya
                             tidak bergantung pada jumlah blob cincinnya.
  3. cakram polos (.galaxy)   tata letak `.galaxy` apa adanya. Yang diukur
                             bukan "spiral != cakram" (itu sudah dijaga uji
                             Swift), melainkan bahwa gerbangnya benar-benar
                             menolak cakram di jalur gambar. **Kedua**
                             pemeriksaan berbunyi di sini: cakram tiga blob
                             juga tidak punya punggungan yang berarti di
                             r=0.30…0.50 R, dan itu memang bentuknya.
  4. lengan dihapus           hanya blob inti yang tersisa. Kedua pemeriksaan
                             berbunyi: sapuan ~0° **dan** punggungan 0.0.
  5. lengan diredupkan 10%    lengan masih di tempatnya, tapi tidak terlihat.
                             **Hanya** lantai punggungan yang melihatnya:
                             sapuannya justru +160° — kebisingan, bukan
                             lengkungan. Keadaan inilah yang membuktikan lantai
                             itu tidak mubazir.
  6. lengan diratakan         semua titik lengan dipindah ke **satu** jari-jari
                             (sudutnya tetap). Lengan menyambung di lingkaran
                             itu, jadi gerbang lama hijau; yang hilang adalah
                             pergeseran sudutnya.
  7. dicerminkan (WAJIB HIJAU) spiral yang dicerminkan — tetap spiral, arah
                             putarannya kebalikan. Gerbang yang "lulus" di sini
                             memang benar; keadaan ini ada supaya itu tercatat,
                             bukan kebetulan. Ia juga menangkap gerbang yang
                             diam-diam menguji tanda sapuan alih-alih besarnya.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan. Kegagalan di tengah tidak boleh
meninggalkan mutasi hidup — pelajaran yang sudah dibayar di repo ini
(`SIGKILL` melewati `finally`, jadi ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-lengan.py
"""

from __future__ import annotations

import importlib.util
import math
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
ROOT = sys.argv[1]

def load(name, filename):
    path = os.path.join(ROOT, "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
results = []
C.check_spiral_arms_actually_spiral(results)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

# Gerbang paritas docstring, dijalankan di proses baru dari berkas yang
# **sudah dimutasi** — sama alasannya dengan `PROBE` di atas.
PROBE_PARITY = r"""
import importlib.util, os, sys
ROOT = sys.argv[1]

def load(name, filename):
    path = os.path.join(ROOT, "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")
results = []
C.check_spiral_arm_docstring_quotes_measured_values(results)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Awal blok tata letak `spiralGalaxy` di port — jangkar semua mutasi di bawah.
#:
#: **Jangkar yang harus muncul tepat satu kali.** `str.replace` atas jangkar
#: yang muncul dua kali akan mengubah keduanya, dan harness lalu melaporkan
#: keadaan yang tidak pernah ia uji. Diperiksa eksplisit di `main()`.
ANCHOR_START = '    "spiralGalaxy": [(0.000000, 0.000000, 0.32, 1.0, 0.0, 0.60),'

#: Baris terakhir blok yang sama. Blok diganti **utuh** dari awal sampai akhir
#: ini, bukan baris per baris: mutan yang menambah/mengurangi jumlah blob
#: (cincin, lengan dihapus) tidak bisa ditulis sebagai penyuntingan satu baris.
ANCHOR_END = "                     (0.534559, 0.113047, 0.17, 1.0, 0.0, 0.24)],"

#: Dua blob pusat: tonjolan inti (0.60) dan kabut cakram (0.13).
CORE_BLOBS = [(0.0, 0.0, 0.32, 0.60), (0.0, 0.0, 0.45, 0.13)]

#: Satu lengan, (x, y, lebar, opasitas), persis seperti di tata letak aslinya.
ARM_BLOBS = [
    (0.208674, 0.076172, 0.24, 0.34),
    (0.065671, 0.292581, 0.22, 0.32),
    (-0.284437, 0.287983, 0.19, 0.28),
    (-0.450423, 0.135194, 0.18, 0.26),
    (-0.534559, -0.113047, 0.17, 0.24),
]

#: Lengan B = cermin lengan A melalui titik pusat (seperti di tata letak asli).
ARM_BLOBS_B = [(-x, -y, w, op) for (x, y, w, op) in ARM_BLOBS]

#: Nama pemeriksaan yang boleh berbunyi, dipakai `STATES` di bawah.
SWEEP = "punggungan bergeser"
RIDGE = "punggungan terang masih ada"

#: Gerbang **paritas docstring** lengan, dan dua kalimat yang dikutipnya.
#:
#: Yang diuji di sini bukan gambarnya melainkan **angka yang ditulis tentang
#: gambar itu**: tabel di komentar `SPIRAL_ARM_SWEEP_DEGREES` dan tabel di
#: docstring `check_spiral_arms_actually_spiral`. Keduanya lahir dengan angka
#: yang saling bertentangan (+111° lawan +88°, +22.5 lawan +26.1) dan tidak
#: satu pun cocok dengan render — kelas cacat "komentar mengutip angka yang
#: tidak pernah ia ukur" yang sudah berulang di repo ini.
#:
#: Keadaan 8–10 memakai **jangkar tabel yang sama**, jadi keadaan mana pun
#: hanya sah kalau tiap tabel masih terbaca utuh; kalau tidak, keadaan itu
#: tidak memutasi apa pun dan laporannya bohong. Diperiksa eksplisit di
#: `main()` lewat pengurai gerbangnya sendiri.
PARITY_SOURCE = os.path.join(ROOT, "Tools", "check-visuals.py")

#: Berapa **baris tabel** yang harus terbaca dari tiap docstring (5 baris:
#: spiral asli, cincin 8, cincin 4, cakram polos, lengan dihapus). Dipakai
#: `main()` untuk memastikan keadaan 8–10 benar-benar punya sasaran: kalau
#: salah satu tabel sudah hilang, keadaan itu memutasi berkas yang tidak lagi
#: memuat apa yang mereka klaim, dan laporannya bohong.
ANCHOR_TABLE_ROWS = 5

#: Keadaan untuk gerbang paritas: (nama, [(lama, baru), …], wajib merah).
#:
#: Keadaan 8 **tidak menyentuh gambar sama sekali** — ia mengubah kalimat
#: komentar lantai dari "5.0" ke "4.0", sementara punggungan yang benar-benar
#: terukur tetap 5.0. Itu tepat bentuk cacatnya: angka di komentar tidak lagi
#: keluar dari penyampelnya. Kalau gerbang paritas ini hanya membandingkan
#: kedua tabelnya sendiri (arah 1) dan tidak mengukur ulang (arah 2), keadaan
#: ini akan hijau.
#:
#: Keadaan 9 menyentuh **satu** dari dua tabel, jadi tabelnya tidak lagi
#: sepakat sementara gambarnya tidak berubah: hanya arah 1 yang berbunyi.
#:
#: Keadaan 10 menggeser **kedua** tabel bersama-sama ke angka yang sama-sama
#: salah. Tabelnya sepakat (arah 1 hijau) dan nilainya tetap salah (arah 2
#: merah). Keadaan inilah yang membuktikan arah 1 saja tidak cukup: tanpa
#: pengukuran ulang, dua tabel yang sepakat pada angka yang tidak pernah
#: keluar dari penyampelnya akan lolos selamanya.
#:
#: Keadaan 11 **wajib hijau**: ambang lantai digeser 3.0 → 3.5, dan angka itu
#: tidak dikutip di tabel mana pun. Ia menangkap gerbang yang berbunyi pada
#: **setiap** suntingan berkas ini, bukan pada angka yang melenceng.
PARITY_AGREE = "dua tabel docstring di berkas ini sepakat"
PARITY_FLOOR40 = "lantai 'lengan diredupkan ke 40%'"
PARITY_CINCIN8 = "docstring 'cincin 8 arah' cocok dengan ukurannya"
PARITY_STATES = [
    ("8. komentar lantai: punggungan 5.0 -> 4.0 (gambar tak berubah)",
     [("diredupkan ke 40%    5.0", "diredupkan ke 40%    4.0")], [PARITY_FLOOR40]),
    ("9. tabel komentar: cincin 8 arah 26.1 -> 22.5 (satu tabel saja)",
     [("cincin 8 arah            sapuan   +0°   punggungan terlemah 26.1",
       "cincin 8 arah            sapuan   +0°   punggungan terlemah 22.5")],
     [PARITY_AGREE]),
    ("10. kedua tabel digeser bersama (sepakat, tapi sama-sama salah)",
     [("cincin 8 arah            sapuan   +0°   punggungan terlemah 26.1",
       "cincin 8 arah            sapuan   +0°   punggungan terlemah 22.5"),
      ("cincin 8 arah            sapuan  +0°    punggungan terlemah 26.1",
       "cincin 8 arah            sapuan  +0°    punggungan terlemah 22.5")],
     [PARITY_CINCIN8]),
    ("11. ambang lantai 3.0 -> 3.5 (tak dikutip; wajib hijau)",
     [("\nSPIRAL_ARM_RIDGE_FLOOR = 3.0", "\nSPIRAL_ARM_RIDGE_FLOOR = 3.5")], []),
]


def block(blobs):
    """Bangun blok `"spiralGalaxy": [...],` dari daftar (x, y, lebar, opasitas)."""
    lines = ['    "spiralGalaxy": [']
    for index, (x, y, width, opacity) in enumerate(blobs):
        tail = "," if index < len(blobs) - 1 else "],"
        lines.append(f"                     ({x:.6f}, {y:.6f}, "
                     f"{width}, 1.0, 0.0, {opacity:.6f}){tail}")
    return "\n".join(lines)


def ring(rays):
    """Jari-jari lengan sama, disebar merata ke `rays` arah — nol lengkungan."""
    blobs = list(CORE_BLOBS)
    for (x, y, width, opacity) in ARM_BLOBS:
        radius = math.hypot(x, y)
        for i in range(rays):
            theta = math.radians(360.0 * i / rays)
            blobs.append((radius * math.cos(theta), radius * math.sin(theta),
                          width, opacity))
    return block(blobs)


def flattened():
    """Semua titik lengan dipindah ke jari-jari titik pertama; sudutnya tetap."""
    radius = math.hypot(ARM_BLOBS[0][0], ARM_BLOBS[0][1])
    blobs = list(CORE_BLOBS)
    for (x, y, width, opacity) in ARM_BLOBS + ARM_BLOBS_B:
        theta = math.atan2(y, x)
        blobs.append((radius * math.cos(theta), radius * math.sin(theta),
                      width, opacity))
    return block(blobs)


def dimmed(factor):
    """Kedua lengan diredupkan sampai nyaris tak terlihat; inti dibiarkan."""
    blobs = list(CORE_BLOBS)
    for (x, y, width, opacity) in ARM_BLOBS + ARM_BLOBS_B:
        blobs.append((x, y, width, opacity * factor))
    return block(blobs)


def mirrored():
    """Spiral dicerminkan: tetap spiral, arah putarannya kebalikan."""
    blobs = list(CORE_BLOBS)
    for (x, y, width, opacity) in ARM_BLOBS + ARM_BLOBS_B:
        blobs.append((-x, y, width, opacity))
    return block(blobs)


#: Setiap keadaan: (nama, pengganti blok tata letak, pemeriksaan yang **wajib**
#: merah).
#:
#: `None` = jalankan apa adanya (baseline) dan wajib **nol** merah.
#:
#: Yang dituntut bukan «ada yang merah», melainkan **yang mana**. Gerbang yang
#: berbunyi pada pemeriksaan yang salah mengukur hal lain daripada yang
#: diklaimnya — kelas cacat yang sudah berulang di repo ini. Karena itu tiap
#: keadaan menyebut pemeriksaan mana yang harus berbunyi, dan `probe()`
#: menuntut yang **tidak** disebut tetap hijau.
STATES = [
    ("[baseline]", None, []),
    ("1. cincin 8 arah (cacat yang tak terlihat gerbang lama)",
     ring(8), [SWEEP]),
    ("2. cincin 4 arah", ring(4), [SWEEP]),
    ("3. cakram polos (tata letak .galaxy apa adanya)",
     block([(0.0, 0.0, 0.32, 0.60), (0.0, 0.0, 0.45, 0.13),
            (0.0, 0.0, 0.20, 0.40)]), [SWEEP, RIDGE]),
    ("4. lengan dihapus (hanya blob inti)", block(CORE_BLOBS), [SWEEP, RIDGE]),
    ("5. lengan diredupkan 10% (tak terlihat)",
     dimmed(0.10), [RIDGE]),
    ("6. lengan diratakan (satu jari-jari)",
     flattened(), [SWEEP, RIDGE]),
    ("7. dicerminkan, tetap spiral (wajib hijau)",
     mirrored(), []),
]

_original = None


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(RENDER, "w")`: sebelas harness di
    `Tools/` memutasi berkas produksi yang sama dan setiap prob membacanya
    dari proses baru, jadi penulisan biasa membuat pembaca bisa melihat
    berkas setengah jadi. Pemulihannya juga **diverifikasi** — kegagalan
    pemulihan bersifat diam dan lalu menyalahkan kode yang benar.
    """
    if _original is not None:
        mutasi_sumber.restore_verified(RENDER, _original)


def probe(parity=False):
    """Jalankan gerbangnya langsung → (daftar_baris_gagal, semua_baris).

    `parity=True` menjalankan gerbang **paritas docstring** alih-alih gerbang
    piksel: keadaan 8–10 memutasi angka yang ditulis tentang gambar, jadi yang
    bisa melihatnya gerbang itu, bukan gerbang pikselnya.
    """
    script = PROBE_PARITY if parity else PROBE
    proc = subprocess.run([sys.executable, "-c", script, ROOT],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None, proc.stderr.strip().splitlines()[-1:] or ["(tanpa galat)"]
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    failed = [line for line in lines if line.startswith("GAGAL")]
    return failed, lines


def main():
    mutasi_sumber.require_clean_sources([RENDER])

    # Jangkar diperiksa **sebelum** apa pun dimutasi. Jangkar yang muncul dua
    # kali mengubah lebih banyak daripada yang dimaksud, dan jangkar yang
    # hilang membuat seluruh harness melaporkan "keadaan tidak sesuai
    # harapan" tanpa pernah menjalankan mutasinya.
    global _original
    with open(RENDER, encoding="utf-8") as handle:
        _original = handle.read()
    for label, anchor in (("awal", ANCHOR_START), ("akhir", ANCHOR_END)):
        if _original.count(anchor) != 1:
            print(f"GERBANG: jangkar {label} tata letak spiral muncul "
                  f"{_original.count(anchor)}x, harus tepat 1x — harness "
                  "tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)
    head = _original.index(ANCHOR_START)
    tail = _original.index(ANCHOR_END) + len(ANCHOR_END)

    # Jangkar tabel paritas: tiap docstring harus masih memuat **tabel utuh**
    # (lima baris). Kalau salah satu tabel sudah hilang atau menyusut, keadaan
    # 8–10 memutasi berkas yang tidak lagi memuat apa yang mereka klaim, dan
    # laporannya bohong. Diukur dengan pengurai yang sama dengan gerbangnya —
    # bukan dengan mencacah string, yang akan lolos pada tabel yang rusak.
    parity_rows = None
    with open(PARITY_SOURCE, encoding="utf-8") as handle:
        parity_original = handle.read()
    try:
        spec = importlib.util.spec_from_file_location(
            "cv_rows", PARITY_SOURCE)
        if spec is not None and spec.loader is not None:
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            gate = module.spiral_arm_doc_rows(
                module.check_spiral_arms_actually_spiral.__doc__ or "")
            anchor = "SPIRAL_ARM_RIDGE_FLOOR = 3.0"
            constant = module.spiral_arm_doc_rows("\n".join(
                parity_original[:parity_original.index(anchor)]
                .splitlines()[-40:]))
            parity_rows = (len(gate), len(constant))
    except Exception as error:  # noqa: BLE001  (dilaporkan, bukan ditelan)
        print(f"GERBANG: tabel paritas tidak bisa diurai: {error}",
              file=sys.stderr)
        sys.exit(2)
    if parity_rows != (ANCHOR_TABLE_ROWS, ANCHOR_TABLE_ROWS):
        print(f"GERBANG: tabel paritas terbaca {parity_rows[0]} baris "
              f"(docstring gerbang) dan {parity_rows[1]} baris (komentar "
              f"konstanta), harus {ANCHOR_TABLE_ROWS} masing-masing — "
              "harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, replacement, must_fire in STATES:
            content = _original if replacement is None \
                else _original[:head] + replacement + _original[tail:]
            if replacement is not None and content == _original:
                print(f"{label:52s} MUTASI TIDAK MENGUBAH BERKAS")
                unexpected += 1
                continue
            mutasi_sumber.write_source(RENDER, content)

            failed, lines = probe()
            if failed is None:
                print(f"{label:52s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            names = " | ".join(line.split("  ")[0][6:].strip() for line in failed)
            # Dua arah diperiksa, dan arah kedua itu yang paling mudah
            # terlupa: pemeriksaan yang **tidak** disebut di sini wajib tetap
            # hijau. Tanpa itu, satu keadaan yang menyalakan seluruh
            # pemeriksaan akan terlihat "sesuai harapan", padahal artinya
            # gerbangnya tidak memisahkan apa pun — ia cuma berisik.
            missing = [want for want in must_fire
                       if not any(want in line for line in failed)]
            spurious = [line for line in failed
                        if not any(want in line for want in must_fire)]
            ok = not missing and not spurious
            if not ok:
                unexpected += 1
            detail = f"{len(failed)} merah" if failed else "0 merah"
            print(f"{'OK  ' if ok else 'SALAH'} {label:52s} {detail}")
            if names:
                print(f"       {names}")
            for want in missing:
                print(f"       HARUSNYA MERAH, TIDAK: {want}")
            for line in spurious:
                print(f"       MERAH YANG TIDAK DIMINTA: {line.split('  ')[0]}")

        # ── Gerbang paritas docstring ────────────────────────────────────
        # Keadaan di sini memutasi **berkas gerbangnya sendiri**
        # (`check-visuals.py`), bukan port render: yang diukur adalah angka
        # yang ditulis tentang gambar, jadi hanya berkas itu yang bisa
        # menggerakkannya.
        #
        # Port render **dipulihkan lebih dulu**, dan itu bukan kerapian: blok
        # di atas meninggalkan `render-visuals.py` dalam bentuk keadaan
        # terakhirnya (keadaan 7 = spiral dicerminkan), dan keadaan 8–10
        # mengukur "spiral asli (model)" lewat port itu. Tanpa pemulihan ini,
        # ketiga keadaan melaporkan merah pada baris `spiral asli (model)`
        # yang sebenarnya benar — harness yang mengukur gambar yang tidak
        # pernah tampil, persis kelas cacat yang ia tutup. Ditemukan sendiri
        # oleh harness ini, bukan oleh pembacaan.
        restore()
        for label, edits, must_fire in PARITY_STATES:
            content = parity_original
            for old, new in edits:
                if content.count(old) != 1:
                    print(f"{label:52s} JANGKAR '{old[:34]}…' MUNCUL "
                          f"{content.count(old)}x, HARUS 1x")
                    content = None
                    break
                content = content.replace(old, new)
            if content is None or content == parity_original:
                if content is not None:
                    print(f"{label:52s} MUTASI TIDAK MENGUBAH BERKAS")
                unexpected += 1
                continue
            mutasi_sumber.write_source(PARITY_SOURCE, content)

            failed, lines = probe(parity=True)
            if failed is None:
                print(f"{label:52s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            names = " | ".join(line.split("  ")[0][6:].strip() for line in failed)
            missing = [want for want in must_fire
                       if not any(want in line for line in failed)]
            spurious = [line for line in failed
                        if not any(want in line for want in must_fire)]
            ok = not missing and not spurious
            if not ok:
                unexpected += 1
            detail = f"{len(failed)} merah" if failed else "0 merah"
            print(f"{'OK  ' if ok else 'SALAH'} {label:52s} {detail}")
            if names:
                print(f"       {names}")
            for want in missing:
                print(f"       HARUSNYA MERAH, TIDAK: {want}")
            for line in spurious:
                print(f"       MERAH YANG TIDAK DIMINTA: {line.split('  ')[0]}")
    finally:
        restore()
        mutasi_sumber.restore_verified(PARITY_SOURCE, parity_original)

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES) + len(PARITY_STATES)} keadaan, "
          "0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
