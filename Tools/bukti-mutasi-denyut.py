#!/usr/bin/env python3
"""Buktikan `check_star_pulse_reaches_the_picture` **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang gambar baru selalu hijau pada hari ia ditulis — itu bukan bukti apa
pun. Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada
keadaan yang memang salah. Kelas cacat yang harness ini tutup lebih tajam
dari biasanya: gerbang ini mengukur **animasi**, dan animasi adalah hal yang
paling mudah lolos dari pemeriksaan gambar — setiap gerbang lain di repo ini
mengukur gambar **diam** pada satu fase. Denyut yang dihapus dari port tidak
mengubah satu pun dari 17 pemeriksaan bintang yang sudah ada (terukur: 0
merah), karena semuanya menggambar pada fase 0.0 dan pada fase itu denyutnya
memang bernilai nol.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                 gerbang hijau (kalau tidak, harness salah)
  1. `sin` -> `cos`          puncak berpindah ke fase 0.0: **tidak ada
                             denyut** pada fase yang diuji (1.000/1.000).
                             Terlihat oleh nisbah puncak **dan** palung.
  2. `sin` -> `sin**2`       denyut hanya ke atas: puncaknya sama tinggi,
                             jadi nisbah **puncak** buta (1.210 = benar).
                             Hanya nisbah **palung** yang melihatnya
                             (1.210, bukan 0.810). Keadaan ini ada khusus
                             untuk membuktikan pemeriksaan palung tidak
                             berlebih: tanpa dia, keduanya bisa saja
                             memeriksa hal yang sama.
  3. denyut diabaikan        `pulse_factor = 1.0` — cacat yang paling
                             mungkin terjadi (port disederhanakan). Nisbah
                             puncak dan palung sama-sama 1.000, jadi kedua
                             pemeriksaan berbunyi. **Keadaan ini hijau di
                             seluruh 17 pemeriksaan bintang yang sudah ada.**
  4. amplitudo diubah 2x     model bilang 0.10, port memakai 0.20. Yang
                             dijaga bukan angkanya (itu sudah dijaga
                             `check_star_geometry_matches_the_model`),
                             melainkan bahwa ambang gerbang ini **dibaca
                             dari model**: kalau port dinaikkan diam-diam,
                             nisbahnya keluar dari `(1.10)²` dan gerbangnya
                             berbunyi alih-alih ikut menyesuaikan diri.
  5. bintang diam saja       `pulse` tidak dipakai sama sekali di penggambar
                             (bukan diset 1.0, tapi diabaikan sebagai
                             parameter). Keadaan ini memastikan ketiga
                             pemeriksaan berbunyi **tanpa bergantung** pada
                             bentuk `pulse_factor` tertentu.

Berkas sumber produksi (`Tools/render-visuals.py`) **dimutasi dengan sengaja**
lalu dipulihkan di `finally` per keadaan. Kegagalan di tengah tidak boleh
meninggalkan mutasi hidup — pelajaran yang sudah dibayar di repo ini
(`SIGKILL` melewati `finally`, jadi ada handler sinyal juga).

Pakai:
    python3 Tools/bukti-mutasi-denyut.py
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
GATE = os.path.join(ROOT, "Tools", "check-visuals.py")

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
C.check_star_pulse_reaches_the_picture(results)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

#: Baris denyut di port — jangkar semua mutasi di bawah.
#:
#: **Jangkar yang harus muncul tepat satu kali.** `str.replace` atas jangkar
#: yang muncul dua kali akan mengubah keduanya, dan harness lalu melaporkan
#: keadaan yang tidak pernah ia uji. Diperiksa eksplisit di `main()`.
ANCHOR = '    pulse_factor = 1 + geometry["pulse_amplitude"] * math.sin(kw.get("pulse", 0.0))'

#: Baris amplitudo di model Swift. Harness ini **tidak** memutasi berkas
#: Swift (gerbang membacanya sebagai sumber kebenaran), tapi keadaan #4
#: menuntut jangkarnya ada supaya mutasinya benar-benar mengubah yang
#: dimaksud: kalau `pulseAmplitude` pindah baris, harness berhenti berisik
#: alih-alih diam-diam menguji keadaan lain.
SWIFT_ANCHOR = "                            pulseAmplitude: Double = 0.10,"

#: Setiap keadaan: (nama, mutasi, pemeriksaan yang **wajib** merah).
#:
#: `None` = jalankan apa adanya (baseline) dan wajib **nol** merah.
#:
#: Yang dituntut bukan «ada yang merah», melainkan **yang mana**. Gerbang
#: yang berbunyi pada pemeriksaan yang salah mengukur hal lain daripada yang
#: diklaimnya — kelas cacat yang sudah berulang di repo ini. Karena itu
#: tiap keadaan menyebut pemeriksaan mana yang harus berbunyi, dan `probe()`
#: menuntut yang **tidak** disebut tetap hijau. Daftar di bawah karena itu
#: **lengkap**: kalau sebuah pemeriksaan ikut merah dan tidak disebut di
#: sini, harness melaporkannya sebagai «merah yang tidak diminta».
#:
#: Keadaan 1 dan 2 sengaja berpasangan, dan **pasangan itulah buktinya**:
#: keduanya menyalakan pemeriksaan amplitudo yang **berbeda**. Amplitudo
#: puncak buta terhadap `sin²` (ia memberinya +0.10, persis seperti `sin`),
#: jadi kalau suatu saat keadaan 2 berhenti menyalakan amplitudo palung,
#: artinya pasangan itu sudah tidak memisahkan apa pun — dan seluruh
#: pemeriksaan amplitudo bisa digantikan satu saja tanpa ada yang tahu.
STATES = [
    ("[baseline]", None, []),
    ("1. sin -> cos (tidak berdenyut)",
     (ANCHOR,
      '    pulse_factor = 1 + geometry["pulse_amplitude"] * math.cos(kw.get("pulse", 0.0))'),
     ["puncak > diam > palung", "amplitudo puncak", "terbaca di kartu jam"]),
    ("2. sin -> sin**2 (denyut hanya ke atas)",
     (ANCHOR,
      '    pulse_factor = 1 + geometry["pulse_amplitude"] * math.sin(kw.get("pulse", 0.0)) ** 2'),
     ["puncak > diam > palung", "amplitudo palung", "terbaca di kartu jam"]),
    ("3. denyut diabaikan (pulse_factor = 1.0)",
     (ANCHOR, "    pulse_factor = 1.0  # MUTASI: denyut diabaikan"),
     ["menghasilkan tiga gambar", "puncak > diam > palung",
      "amplitudo puncak", "amplitudo palung", "terbaca di kartu jam"]),
    ("4. amplitudo port dinaikkan 2x",
     ('    pulse_factor = 1 + geometry["pulse_amplitude"]',
      '    pulse_factor = 1 + 2 * geometry["pulse_amplitude"]'),
     ["amplitudo puncak", "amplitudo palung"]),
    # Keadaan batas, dan satu-satunya yang **wajib hijau**. Ia mengubah
    # sumber tanpa mengubah perilaku sama sekali: sukunya dibalik urutannya
    # (`a·sin + 1` alih-alih `1 + a·sin`). Gerbang yang mengukur gambar
    # tidak boleh peduli — hasilnya identik sampai bit terakhir. Gerbang yang
    # membaca **teks** akan berbunyi di sini. Tanpa keadaan ini, gerbang yang
    # cuma mencocokkan tulisan `1 + ... sin(` akan lolos seluruh keadaan di
    # atas, dan kelima keadaan lainnya akan terlihat seperti bukti yang kuat.
    ("5. suku dibalik, hasil identik (wajib hijau)",
     ('    pulse_factor = 1 + geometry["pulse_amplitude"] * math.sin(kw.get("pulse", 0.0))',
      '    pulse_factor = geometry["pulse_amplitude"] * math.sin(kw.get("pulse", 0.0)) + 1'),
     []),
]

_original = None


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(RENDER, "w")`: sepuluh harness di
    `Tools/` memutasi berkas produksi yang sama dan setiap prob membacanya
    dari proses baru, jadi penulisan biasa membuat pembaca bisa melihat
    berkas setengah jadi. Pemulihannya juga **diverifikasi** — kegagalan
    pemulihan bersifat diam dan lalu menyalahkan kode yang benar.
    """
    if _original is not None:
        mutasi_sumber.restore_verified(RENDER, _original)


def probe():
    """Jalankan gerbangnya langsung → (daftar_baris_gagal, semua_baris)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
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
    if _original.count(ANCHOR) != 1:
        print(f"GERBANG: jangkar denyut muncul {_original.count(ANCHOR)}x, "
              "harus tepat 1x — harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)
    swift = open(os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                              "CelestialVisual.swift"), encoding="utf-8").read()
    if swift.count(SWIFT_ANCHOR) != 1:
        print(f"GERBANG: jangkar amplitudo model muncul {swift.count(SWIFT_ANCHOR)}x, "
              "harus tepat 1x.", file=sys.stderr)
        sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutation, must_fire in STATES:
            if mutation is None:
                content = _original
            else:
                old, new = mutation
                if old not in _original:
                    print(f"{label:46s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                    unexpected += 1
                    continue
                content = _original.replace(old, new, 1)
            mutasi_sumber.write_source(RENDER, content)

            failed, lines = probe()
            if failed is None:
                print(f"{label:46s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            names = " | ".join(line.split("  ")[0][6:].strip() for line in failed)
            # Yang dituntut bukan «ada yang merah», melainkan **yang mana**
            # yang merah. Gerbang yang berbunyi pada pemeriksaan yang salah
            # mengukur hal lain daripada yang diklaimnya — kelas cacat yang
            # sudah berulang di repo ini (gerbang yang hijau karena alasan
            # yang salah, dan gerbang yang merah pada kode benar).
            #
            # Dua arah diperiksa, dan arah kedua itu yang paling mudah
            # terlupa: pemeriksaan yang **tidak** disebut di sini wajib tetap
            # hijau. Tanpa itu, satu keadaan yang menyalakan seluruh delapan
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
            print(f"{'OK  ' if ok else 'SALAH'} {label:46s} {detail}")
            if names:
                print(f"       {names}")
            for want in missing:
                print(f"       HARUSNYA MERAH, TIDAK: {want}")
            for line in spurious:
                print(f"       MERAH YANG TIDAK DIMINTA: {line.split('  ')[0]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
