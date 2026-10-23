#!/usr/bin/env python3
"""Buktikan gerbang **opasitas kabut Venus** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

Dua pemeriksaan baru hidup di dalam `check_bands_follow_the_limb_arc`:

  * `setiap opasitas ciri di model dipakai penggambarnya` — setiap
    `static let *Opacity: Double` di `CelestialVisual.swift` harus benar-benar
    dibaca oleh penggambarnya (view atau model sendiri).
  * `kabut Venus: opasitas view dari model, bukan literal` — `drawHaze` harus
    memakai `CelestialVisual.venusHazeOpacity`, dan tidak boleh menyisakan
    literal opasitas selain 0.

Keduanya hijau pada hari ditulis. Itu bukan bukti apa pun. Yang harus
dibuktikan adalah bahwa keduanya **bisa merah**, dan merah pada keadaan yang
memang salah.

**Kenapa cacat ini tidak terlihat dengan mata.** Keadaan 2 menulis
`haze.opacity(0.7)` alih-alih `haze.opacity(CelestialVisual.venusHazeOpacity)`.
Hasil di layar **identik piksel demi piksel** — 0.7 adalah nilai konstanta itu
hari ini. Yang hilang bukan gambarnya, melainkan **ikatan** ke model: sejak
detik itu mengubah konstanta di model tidak lagi mengubah jam, dan tidak ada
satu pun gerbang gambar yang bisa melihatnya karena port Python tetap
menggambar kabut yang benar. Inilah bentuk cacat yang hanya bisa ditangkap
dengan membaca sumber, dan karena itu harus dibuktikan lewat sumber.

Keadaan yang diuji:

  [baseline]                       gerbang hijau (kalau tidak, harness salah)

  1. view: token diganti literal    `opacity(CelestialVisual.venusHazeOpacity)`
     `0.7`                          -> `opacity(0.7)`. Piksel tidak berubah.
                                    Kedua pemeriksaan baru wajib merah:
                                    yang satu karena konstantanya berhenti
                                    dipakai, yang lain karena literalnya
                                    kembali. Dua arah, dua alasan berbeda.

  2. view: kabut dimatikan          `opacity(...)` -> `opacity(0.0)`. Ini
     (`0.0`)                        cacat aslinya: Venus kembali menjadi bola
                                    kuning polos. Hanya pemeriksaan **pemakaian**
                                    yang boleh berbunyi di sini — pemeriksaan
                                    literal sengaja mengizinkan 0.0 (gradien
                                    kabut memang mulai dari nol di tepi atas),
                                    jadi keadaan ini membuktikan arah kedua
                                    punya gigi sendiri.

  3. model: konstanta *Opacity      menambah `static let fakeFeatureOpacity`
     baru yang tidak dipakai       ke model. Kalau gerbangnya daftar tangan
                                    (Venus, Jupiter, Saturnus, ...), keadaan
                                    ini **hijau** — dan planet berikutnya lolos
                                    dengan alasan yang sama. Yang dituntut di
                                    sini: merah, karena gerbangnya membaca
                                    model, bukan daftar.

  4. view: `drawHaze` dihapus       kontrol negatif. Gerbang harus merah
     (kontrol negatif)              karena **tidak menemukan subjeknya**, bukan
                                    hijau tanpa mengukur apa pun. Gerbang yang
                                    kehilangan subjeknya harus berbunyi.

**Yang TIDAK diklaim harness ini.** Ia tidak menjalankan seluruh suite
`check-visuals.py` (itu tugas CI) dan tidak mengukur piksel. Ia hanya
membuktikan keempat pemeriksaan di atas bereaksi terhadap empat mutasi yang
disebut, di proses baru, pada berkas yang benar-benar ditulis ke disk.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` dari berkas yang
# **sudah dimutasi** di disk. Mengimpor sekali di dalam proses ini akan memakai
# salinan lama, dan seluruh harness berbohong.
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
C.check_bands_follow_the_limb_arc(results)
C.check_modeled_port_constants_match_the_model(results)
for r in results:
    print(("OK  " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""

# ── Jangkar ───────────────────────────────────────────────────────────────
# Ketiganya diperiksa jumlah kemunculannya **sebelum** apa pun dimutasi:
# jangkar yang muncul dua kali mengubah lebih banyak daripada yang dimaksud,
# dan jangkar yang hilang membuat harness melaporkan "keadaan tidak sesuai
# harapan" tanpa pernah menjalankan mutasinya.
VIEW_TOKEN = "haze.opacity(CelestialVisual.venusHazeOpacity)"
VIEW_HAZE_FUNC = "    private func drawHaze(context: GraphicsContext, center: CGPoint, radius: CGFloat) {"
MODEL_CONST = "static let venusHazeOpacity: Double = 0.7"

#: Titik sisip konstanta palsu: sesudah konstanta Venus, di dalam `struct`
#: yang sama, jadi ia terbaca oleh regex model tanpa mengubah apa pun yang
#: sudah ada.
MODEL_INSERT_AFTER = MODEL_CONST + "\n"

# ── Nama pemeriksaan ──────────────────────────────────────────────────────
# Ditulis sebagai potongan unik, bukan kalimat penuh: kalimatnya memuat angka
# yang berubah bersama ambangnya, dan harness yang ikut berubah bersama
# gerbangnya tidak menjaga apa pun.
USED = "setiap opasitas ciri di model dipakai penggambarnya"
NOT_LITERAL = "kabut Venus: opasitas view dari model, bukan literal"
PARITY = "model→port: VENUS_HAZE_OPACITY"

#: Tetangga di fungsi yang sama: bentuk pita, geometri kabut. Semuanya wajib
#: tetap hijau di setiap keadaan — kalau tidak, harness ini cuma membuktikan
#: bahwa fungsinya berisik.
NEIGHBOURS = [
    "pita mengikuti busur limb",
    "kabut Venus: pusat (port == model)",
    "kabut Venus: separuh lebar (port == model)",
    "kabut Venus: separuh tinggi (port == model)",
]

#: (nama, [(berkas, jangkar, pengganti)], wajib_merah, wajib_tetap_hijau)
STATES = [
    ("[baseline]", None, [], []),
    ("1. view: token diganti literal 0.7",
     [(VIEW, VIEW_TOKEN, "haze.opacity(0.7)")],
     # Dua arah, dua alasan: konstantanya berhenti dipakai, dan literalnya
     # kembali. Kalau salah satu pemeriksaan hilang, keadaan ini tetap
     # "hijau" untuk sisanya — karena itu keduanya dituntut.
     [USED, NOT_LITERAL], NEIGHBOURS),
    ("2. view: kabut dimatikan (0.0)",
     [(VIEW, VIEW_TOKEN, "haze.opacity(0.0)")],
     # Pemeriksaan literal **sengaja** mengizinkan 0.0: gradien kabut memang
     # mulai dari nol di tepi atasnya. Jadi yang harus berbunyi di sini hanya
     # pemeriksaan pemakaian — dan itulah bukti bahwa ia punya gigi sendiri,
     # bukan menumpang pada pemeriksaan literal.
     [USED], NEIGHBOURS + [NOT_LITERAL]),
    ("3. model: konstanta *Opacity baru tanpa pemakai",
     [(MODEL, MODEL_INSERT_AFTER,
       MODEL_INSERT_AFTER + "    static let fakeFeatureOpacity: Double = 0.5\n")],
     # Gerbang daftar-tangan akan hijau di sini, karena `fakeFeatureOpacity`
     # tidak ada di daftar mana pun. Gerbang yang membaca model memerah.
     [USED], NEIGHBOURS + [NOT_LITERAL, PARITY]),
    ("4. view: drawHaze dihapus (kontrol negatif)",
     [(VIEW, VIEW_HAZE_FUNC, VIEW_HAZE_FUNC.replace("drawHaze", "drawHazeGONE"))],
     # Gerbang yang kehilangan subjeknya harus berbunyi, bukan hijau tanpa
     # mengukur apa pun.
     [NOT_LITERAL], NEIGHBOURS + [USED]),
]

_originals = {}
_sources = (VIEW, MODEL)


def restore(*_):
    """Pulihkan kedua sumber produksi — juga saat dihentikan sinyal."""
    for path, content in _originals.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)


def probe():
    """Jalankan gerbangnya langsung → (daftar_baris_gagal, semua_baris)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT,
                          env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
    if proc.returncode != 0:
        return None, proc.stderr.strip().splitlines()[-1:] or ["(tanpa galat)"]
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    failed = [line for line in lines if line.startswith("GAGAL")]
    return failed, lines


def main():
    mutasi_sumber.require_clean_sources(list(_sources))

    for path in _sources:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()
    for path, anchor, label in (
            (VIEW, VIEW_TOKEN, "pemakaian token opasitas kabut di view"),
            (VIEW, VIEW_HAZE_FUNC, "deklarasi drawHaze di view"),
            (MODEL, MODEL_CONST, "konstanta venusHazeOpacity di model")):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x "
                  "— harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutations, must_fire, must_stay in STATES:
            for path in _sources:
                mutasi_sumber.write_source(path, _originals[path])
            if mutations is not None:
                # Mutasi dirantai per berkas, bukan selalu dari aslinya.
                pending = {path: _originals[path] for path in _sources}
                for path, old, new in mutations:
                    content = pending[path].replace(old, new, 1)
                    if content == pending[path]:
                        print(f"{label:46s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                        unexpected += 1
                        continue
                    pending[path] = content
                for path, content in pending.items():
                    if content != _originals[path]:
                        mutasi_sumber.write_source(path, content)

            failed, lines = probe()
            if failed is None:
                print(f"{label:46s} PROBE GAGAL JALAN: {lines[-1]}")
                unexpected += 1
                continue

            names = " | ".join(line.split("  ")[0][6:].strip() for line in failed)
            # Yang dituntut bukan «ada yang merah», melainkan **yang mana**.
            missing = [want for want in must_fire
                       if not any(want in line for line in failed)]
            spurious = [line for line in failed
                        if not any(want in line for want in must_fire)]
            stayed = [want for want in must_stay
                      if any(want in line for line in failed)]
            ok = not missing and not spurious and not stayed
            if not ok:
                unexpected += 1
            detail = f"{len(failed)} merah" if failed else "0 merah"
            print(f"{'OK  ' if ok else 'SALAH'} {label:46s} {detail}")
            if names:
                print(f"       {names}")
            for want in missing:
                print(f"       HARUSNYA MERAH, TIDAK: {want}")
            for want in stayed:
                print(f"       HARUSNYA TETAP HIJAU, TIDAK: {want}")
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
