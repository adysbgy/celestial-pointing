#!/usr/bin/env python3
"""Buktikan `check_view_blur_predicate_matches_the_model` **berbunyi**.

Kenapa berkas ini ada.

Gerbang itu menjaga satu predikat di `CelestialVisualView` yang menentukan
apakah gambar objek disamarkan saat engine ragu. Cacat yang ditutupnya adalah
predikat yang **terbalik** (`isConfirmed || allows`) — planet tetap tajam saat
ragu, Bulan ikut kabur. Ia bertahan di `main` karena **119 gerbang gambar
lain mengukur port Python**, dan port-nya benar. Tidak ada yang membaca baris
Swift-nya.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia bisa merah, merah pada keadaan yang memang salah, dan diam pada
keadaan yang benar. Empat keadaan di bawah adalah empat cara berbeda
mematahkan predikat itu — masing-masing mengompilasi, masing-masing lolos
seluruh gerbang UI lain, dan masing-masing menghasilkan gambar yang salah di
layar:

  1. arah lama: `!isConfirmed && allows` -> `isConfirmed || allows`
        Planet & deepSky tidak disamarkan saat ragu; Bulan/bintang/Matahari
        justru disamarkan. Ini cacat aslinya, diukur sebelum perbaikan.
  2. `&&` dihapus, tinggal `UncertainBlur.allows(kind)`
        Bentuk yang "terlihat benar": jenis yang eligible disamarkan
        **selamanya**, termasuk saat gambar sudah pasti. Gerbang yang hanya
        mencari nama `allows` akan meloloskannya.
  3. `!isConfirmed` diganti `true`
        Predikat selalu menyala untuk jenis eligible — sama dengan (2) tetapi
        lewat jalur yang berbeda, dan tetap mengompilasi.
  4. `.opacity` tidak lagi memakai predikat (dipaku `true`)
        Blur masih dipasang, opasitas tidak. Samaran jadi setengah: bentuk
        kehilangan ketegasan tetapi tidak meredup, dan lencana tanda tanya
        kehilangan kontras terhadap latar — cacat yang tidak bisa dibaca dari
        kode tanpa membandingkan kedua pemakai predikat.
  5. kontrol negatif: pohon apa adanya harus **diam**.

Kenapa probe-nya proses baru, dan kenapa ia membaca berkas dari disk.
`check_visuals` dibaca sebagai modul, dan modul yang sudah di-import tidak
melihat perubahan berkas. Setiap keadaan karena itu menjalankan proses Python
baru yang me-`import` ulang modulnya — sama seperti CI.

Kenapa `mutasi_sumber`, bukan `open(path, "w")`. Berkas yang dimutasi di sini
(`CelestialVisualView.swift`) juga dimutasi harness lain di `Tools/`, di CI
yang sama. `mutasi_sumber` menolak jalan bila berkasnya sudah menyimpang dari
`git HEAD`, menulis atomik, dan memulihkan terverifikasi.

Cara pakai: python3 Tools/bukti-mutasi-samaran-terbalik.py
Keluar 0 kalau semua keadaan sesuai harapan, 1 kalau ada yang tidak.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
CHECKER = os.path.join(ROOT, "Tools", "check-visuals.py")

# Jangkar yang wajib ada **tepat sekali**. Bila salah satunya berubah bentuk,
# harness menolak jalan (exit 2) alih-alih melaporkan "pulih" untuk mutasi
# yang tidak pernah terpasang — kelas cacat yang sudah dua kali menjatuhkan
# `main` di repo ini.
PREDIKAT = "!isConfirmed && UncertainBlur.allows(kind)"
OPACITY_CALL = ("Self.dimmedForUncertainty(isConfirmed: isConfirmed, "
                "kind: visual.kind)\n                 ? Self.uncertainBlurOpacity")

STATES = [
    ("[baseline]", None, False),
    ("1 arah lama: isConfirmed || allows",
     (PREDIKAT, "isConfirmed || UncertainBlur.allows(kind)"), True),
    ("2 tanpa &&: allows(kind) saja",
     (PREDIKAT, "UncertainBlur.allows(kind)"), True),
    ("3 lupa isConfirmed: !isConfirmed -> true",
     (PREDIKAT, "true && UncertainBlur.allows(kind)"), True),
    ("4 .opacity tak memakai predikat",
     (OPACITY_CALL,
      "true\n                 ? Self.uncertainBlurOpacity"), True),
    ("5 kontrol negatif: pohon apa adanya", None, False),
]

# Probe dijalankan sebagai **proses baru** tiap keadaan: modul yang sudah
# di-import tidak melihat berkas yang baru ditulis.
PROBE = """
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cv", sys.argv[1])
cv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cv)
res = []
cv.check_view_blur_predicate_matches_the_model(res)
if not res:
    print("KOSONG"); sys.exit(3)
print("MERAH" if not res[0].ok else "HIJAU")
print(res[0].detail)
"""

_original = None


def restore(*_):
    if _original is not None:
        mutasi_sumber.restore_verified(VIEW, _original)


def probe():
    """(status, detail) — status 'MERAH' / 'HIJAU' / None bila probe gagal."""
    proc = subprocess.run([sys.executable, "-c", PROBE, CHECKER],
                          cwd=ROOT, capture_output=True, text=True,
                          env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
    lines = [l for l in proc.stdout.strip().splitlines() if l.strip()]
    if proc.returncode != 0 or not lines:
        detail = (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
        return None, detail
    return lines[0], (lines[1] if len(lines) > 1 else "")


def main():
    global _original

    mutasi_sumber.require_clean_sources([VIEW])

    with open(VIEW, encoding="utf-8") as handle:
        _original = handle.read()

    # Jangkar harus ada tepat sekali. Kalau tidak, harness ini akan melaporkan
    # "JANGKAR TIDAK DITEMUKAN" untuk setiap keadaan dan itu terbaca seperti
    # gerbang yang rusak — padahal yang berubah adalah bentuk kodenya.
    for anchor, label in ((PREDIKAT, "predikat"), (OPACITY_CALL, "pemanggilan .opacity")):
        count = _original.count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x di {VIEW}, harus 1 "
                  f"-- harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutation, must_fire in STATES:
            mutasi_sumber.write_source(VIEW, _original)

            if mutation is not None:
                old, new = mutation
                mutated = _original.replace(old, new, 1)
                if mutated == _original:
                    print(f"{label:44s} JANGKAR TIDAK DITEMUKAN")
                    unexpected += 1
                    continue
                mutasi_sumber.write_source(VIEW, mutated)

            status, detail = probe()
            if status is None:
                print(f"{label:44s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            fired = (status == "MERAH")
            ok = (fired == must_fire)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:44s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES) + 1} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
