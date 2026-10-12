#!/usr/bin/env python3
"""Buktikan Aturan 32 (lencana "engine ragu") **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis — itu bukan bukti apa pun.
Yang harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada keadaan
yang memang salah, dengan pesan yang menunjuk ke klaim yang dilanggar.

Kelas cacat yang ditutupnya.

Dua baris di `Apps/Shared/CelestialVisualView.swift` adalah satu-satunya
penanda di layar yang mengatakan "engine tidak yakin":

    baris 63  `if !isConfirmed { drawCandidateMarker(...) }`
    baris 308 `if !(isConfirmed && palette.feature == .rings)`

Terukur sebelum Aturan 32 ada: baris 63 **dihapus seluruhnya**, lalu seluruh
31 aturan UI dan `./swift-typecheck.sh` dijalankan — keduanya lulus, exit 0.
`swift test` di Linux tidak bisa menolong karena ia hanya membangun
`Packages/`, sedangkan berkas ini hidup di `Apps/`. Jadi menghapus satu-satunya
penanda keraguan di layar tidak menghasilkan satu pun kegagalan. Itu yang
membuat harness ini wajib: tanpa keadaan yang membuktikan gerbangnya berbunyi,
Aturan 32 hanya menambah satu entri hijau.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                     gerbang hijau (kalau tidak, harness salah)

  1. lencana ragu dihapus        Cacat aslinya. Kandidat yang belum terkunci
                                 digambar tanpa tanda tanya, jadi gambar
                                 terbaca sebagai identitas pasti di sebelah
                                 badge teks "Ragu".

  2. lencana tanpa syarat        Arah sebaliknya, dan tanpa itu cacat nomor 1
     `!isConfirmed`              bisa "diselesaikan" dengan menggambar lencana
                                 **selalu**: penanda ada, tetapi ia kini
                                 tampil pada objek yang **sudah** terkunci —
                                 kebohongan pada arah yang berlawanan, dan
                                 pemeriksaan yang hanya mencari nama fungsinya
                                 akan hijau.

  3. cincin bocor ke kandidat    Sisi ciri pengenal. Tanpa ini, kedua cacat di
     (`isConfirmed` dihapus)     atas bisa lolos sementara cincin Saturnus
                                 tetap tergambar pada kandidat yang belum
                                 pasti: lencana ada, tapi cirinya sudah
                                 telanjur tampil.

  4. syarat bola dihapus total   Kontrol negatif untuk sisi `drawSphere`.
                                 Gerbang yang kehilangan subjeknya harus
                                 **merah**, bukan hijau tanpa mengukur apa pun.

**Keadaan 1–3 tidak bisa saling menggantikan.** 1 menguji kehadiran bersyarat,
2 menguji bahwa syaratnya memang `!isConfirmed` (bukan sekadar ada `if`), 3
menguji bahwa ciri pengenal ikut dijaga. Kalau salah satunya dilewat, gerbang
bisa dibalik tanpa berbunyi di sisi itu.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang akan tetap
hijau walau aturan aslinya dilonggarkan. Yang diukur harus aturan yang CI
jalankan.
"""

from __future__ import annotations

import os
import re
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")

#: Tanda yang dicetak Aturan 32. Dibaca dari keluaran lint, bukan ditulis
#: ulang, supaya perubahan pesannya tidak membuat harness ini berbohong.
RULE_HEADER = "== Aturan 32:"
CLEAN_MARK = "Bersih: lencana ragu digambar tepat saat engine belum pasti."

#: Jangkar di view. Baris **utuh** supaya mutasinya tidak bergantung pada
#: spasi; kemunculannya diperiksa eksplisit karena jangkar yang muncul dua
#: kali mengubah lebih banyak daripada yang dilaporkan.
BADGE_LINE = ("            if !isConfirmed "
              "{ drawCandidateMarker(context: context, size: size) }")
SPHERE_LINE = "        if !(isConfirmed && palette.feature == .rings) {"

STATES = [
    ("[baseline]", None, False),
    ("1. lencana ragu dihapus",
     [(VIEW, BADGE_LINE, "            // MUTASI: lencana ragu dihapus")],
     True),
    ("2. lencana tanpa syarat `!isConfirmed`",
     [(VIEW, BADGE_LINE,
       "            if true { drawCandidateMarker(context: context, size: size) }")],
     True),
    ("3. cincin bocor ke kandidat (`isConfirmed` dihapus)",
     [(VIEW, SPHERE_LINE, "        if !(palette.feature == .rings) {")],
     True),
    ("4. syarat `drawSphere` dihapus total (kontrol negatif)",
     [(VIEW, SPHERE_LINE, "        if true {")],
     True),
]

_originals = {}
_sources = (VIEW,)


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(path, "w")`: belasan harness di
    `Tools/` memutasi berkas produksi yang sama, jadi penulisan biasa membuat
    pembaca bisa melihat berkas setengah jadi. Pemulihannya **diverifikasi** —
    kegagalan pemulihan bersifat diam dan lalu menyalahkan kode yang benar.
    """
    for path, content in _originals.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)


def extract_rule32():
    """Ambil program Aturan 32 dari `swift-ui-lint.sh`.

    Kenapa diekstrak, bukan disalin: harness yang menyalin aturannya akan
    tetap hijau walau aturan aslinya dilonggarkan — persis kelas cacat yang
    ditutup `check-harness-terdaftar.py` (gerbang yang tidak pernah
    dieksekusi selalu hijau).
    """
    text = open(LINT, encoding="utf-8").read()
    start = text.find("# ── Aturan 32")
    if start < 0:
        return None
    end = text.find('if [ "$status" -eq 0 ]; then', start)
    if end < 0:
        return None
    return text[start:end]


def probe(program):
    """Jalankan Aturan 32 sendiri → (merah?, detail)."""
    proc = subprocess.run(["bash", "-c", program], cwd=ROOT,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    clean = CLEAN_MARK in out
    return (not clean), out.strip()


def main():
    mutasi_sumber.require_clean_sources(list(_sources))

    program = extract_rule32()
    if program is None:
        print("GERBANG: program Aturan 32 tidak ditemukan di "
              "swift-ui-lint.sh — harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)
    if RULE_HEADER not in program:
        print("GERBANG: Aturan 32 tidak mencetak judulnya sendiri; harness "
              "tidak bisa membedakan aturan ini dari yang lain.",
              file=sys.stderr)
        sys.exit(2)

    for path in _sources:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()
    for path, anchor, label in (
            (VIEW, BADGE_LINE, "baris lencana ragu"),
            (VIEW, SPHERE_LINE, "baris syarat drawSphere")):
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x "
                  "— harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutations, must_fire in STATES:
            for path in _sources:
                mutasi_sumber.write_source(path, _originals[path])
            if mutations is not None:
                pending = {path: _originals[path] for path in _sources}
                anchor_missing = False
                for path, old, new in mutations:
                    content = pending[path].replace(old, new, 1)
                    if content == pending[path]:
                        print(f"{label:52s} ANCHOR TIDAK DITEMUKAN: {old!r}")
                        anchor_missing = True
                        continue
                    pending[path] = content
                if anchor_missing:
                    unexpected += 1
                    continue
                for path, content in pending.items():
                    if content != _originals[path]:
                        mutasi_sumber.write_source(path, content)

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:52s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            # Yang dituntut bukan «merah» melainkan **merah karena alasan
            # yang benar**: aturan ini harus menyebut baris/klaim yang
            # dilanggar. Pesan yang kosong berarti ia berbunyi tanpa mengukur.
            ok = (fired == must_fire)
            if fired and not detail.strip():
                ok = False
            if not ok:
                unexpected += 1
            state = "MERAH" if fired else "hijau"
            print(f"{'OK  ' if ok else 'SALAH'} {label:52s} {state}")
            if fired:
                for line in detail.splitlines():
                    if line.strip() and not line.startswith(RULE_HEADER.split("==")[1].strip()):
                        print(f"       {line.strip()[:150]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
