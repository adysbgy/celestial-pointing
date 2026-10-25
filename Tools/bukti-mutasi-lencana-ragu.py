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

  5. ciri `.paleDisk` hilang      **Keadaan yang membedakan aturan baru dari
     dari jalur gambar            yang lama, diukur lewat penyuntikan
                                 terpisah — bukan lewat harness ini.**
                                 Seluruh baris `case .paleDisk:
                                 drawPaleDisk(…)` dihapus, sehingga Uranus
                                 kehilangan sabuk samarnya dan tampil seperti
                                 planet tak dikenal — padahal `enum
                                 DistinguishingFeature` masih menyebut
                                 `.paleDisk` dan view masih punya jalur untuk
                                 semua ciri lain. Terukur:

                                     aturan lama (pola `drawSphere`)  hijau
                                     aturan baru (himpunan ciri)      MERAH

                                 **Kenapa tidak bisa jadi keadaan di sini.**
                                 Harness ini menolak jalan di atas sumber yang
                                 tidak sama dengan HEAD (itu yang membuat
                                 «pulih persis»-nya bermakna), sedangkan
                                 `.paleDisk` **hanya ada** di pekerjaan yang
                                 belum di-commit: di HEAD ia tidak ada sama
                                 sekali, sehingga jangkarnya nol kali dan
                                 harness berhenti — persis yang terjadi. Jadi
                                 pengukuran di atas dilakukan dengan menyuntik
                                 view salinan di luar harness, dan **angka itu
                                 yang diklaim**, bukan angka dari keadaan di
                                 bawah. Begitu penambahannya di-commit,
                                 keadaan ini harus masuk kembali ke sini:
                                 pada HEAD ia akan punya jangkar yang sah.

  6. `.paleDisk` utuh             Kontrol negatif, dengan alasan yang sama
                                 belum bisa berdiri di sini. Gerbang yang
                                 memerah pada ciri yang **memang terjaga**
                                 akan dilonggarkan orang, jadi keadaan yang
                                 setara wajib hijau. Yang terukur di sisinya
                                 adalah **batas** yang dinyatakan di atas:
                                 mengganti fungsi gambarnya (`drawPaleDisk` →
                                 `drawNeutralBody`, simbol `.paleDisk` tetap
                                 ada) juga hijau — gerbang ini menjaga bahwa
                                 cirinya **dipakai di bawah penjaga**, bukan
                                 bahwa gambarnya benar.

**Keadaan 1–3 saling tidak bisa menggantikan.** 1 menguji kehadiran bersyarat,
2 menguji bahwa syaratnya memang `!isConfirmed` (bukan sekadar ada `if`), 3
menguji ciri `.rings`. Kelas cacat yang ditangkap keadaan 1–3 adalah **cacat
pada satu situs** yang sudah hidup di HEAD; kelas cacat keadaan 5 adalah
**cacat pada ciri mana pun** yang belum ada di HEAD. Karena harness ini hanya
boleh berjalan di atas HEAD, keadaan 1–3 adalah yang bisa ditegakkan di sini,
dan keadaan 5 tetap harus diukur di luar lalu disebutkan kejujurannya.

**Yang TIDAK diklaim keadaan ini.** Ia menuntut simbol cirinya **ada** di bawah
sebuah `if` yang memuat `isConfirmed`. Ia tidak membuktikan bahwa `if` itu
**dievaluasi** (`if true` dengan `isConfirmed` di dalam ekspresi yang tidak
dipakai akan hijau), tidak mengenali penjaga `guard isConfirmed else { return }`
yang berdiri sebelum `switch`, dan tidak tahu apakah cabangnya menggambar
gambar yang benar. Ketiga batas itu diukur, bukan diduga — lihat catatan di
`swift-ui-lint.sh`.

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
#:
#: **Kenapa jangkarnya pindah ke `overlay`.** Sampai siklus "lencana selamat
#: dari samaran", lencana digambar **di dalam** `Canvas` objek, dan `.blur` di
#: atas kanvas itu mengolesinya bersama gambarnya: tepi glif terukur 0.04,
#: bukan ≈1.0. Penanda "engine ragu" berhenti terbaca tepat pada penanda yang
#: menjaga pengguna dari false confidence. Lencana sekarang dipasang sebagai
#: `overlay` **sesudah** `.blur`, jadi jangkar mutasinya juga di situ — kalau
#: harness tetap memutasi baris lama, ia mengukur baris yang tidak lagi
#: menentukan apa pun.
BADGE_LINE = "            if !isConfirmed { candidateMarkerOverlay }"
BADGE_BODY = "            drawCandidateMarker(context: context, size: size)"
SPHERE_LINE = "        if !(isConfirmed && palette.feature == .rings) {"

STATES = [
    ("[baseline]", None, False),
    ("1. lencana ragu dihapus",
     [(VIEW, BADGE_LINE, "            // MUTASI: lencana ragu dihapus")],
     True),
    ("2. lencana tanpa syarat `!isConfirmed`",
     [(VIEW, BADGE_LINE,
       "            if true { candidateMarkerOverlay }")],
     True),
    # Arah yang baru bisa dilihat sesudah lencana pindah ke `overlay`: badan
    # overlay yang dikosongkan. Sebelumnya pemeriksaan "dipanggil" ikut
    # mencocokkan **definisi** `private func drawCandidateMarker(`, jadi
    # keadaan ini tetap hijau — diukur, dan itulah kenapa keadaan ini ada.
    ("2b. badan overlay dikosongkan",
     [(VIEW, BADGE_BODY, "            // MUTASI: glif dihapus")],
     True),
    # Cacat yang persis ditutup siklus ini: lencana dipasang **sebelum**
    # `.blur`, sehingga samaran mengolesi penanda keraguan itu sendiri.
    # Syaratnya benar, badannya utuh — yang salah hanya urutannya. Karena itu
    # ia dua suntingan: blok `overlay` dicabut dari tempatnya, lalu dipasang
    # di atas `.drawingGroup` (yaitu sebelum `.blur`).
    ("2c. overlay dipasang sebelum `.blur`",
     [(VIEW, BADGE_LINE + "\n        }\n", ""),
      (VIEW, "        .drawingGroup(opaque: false, colorMode: .linear)\n",
       "        .overlay {\n" + BADGE_LINE + "\n        }\n"
       "        .drawingGroup(opaque: false, colorMode: .linear)\n")],
     True),
    ("3. cincin bocor ke kandidat (`isConfirmed` dihapus)",
     [(VIEW, SPHERE_LINE, "        if !(palette.feature == .rings) {")],
     True),
    ("4. syarat `drawSphere` dihapus total (kontrol negatif)",
     [(VIEW, SPHERE_LINE, "        if true {")],
     True),
    # Keadaan 5 & 6 sengaja TIDAK ada di sini: keduanya menyentuh `.paleDisk`,
    # yang belum hidup di HEAD — jangkarnya nol kali dan harness berhenti
    # (benar, karena harness hanya mengukur apa yang di-commit). Keduanya
    # diukur lewat penyuntikan terpisah; hasilnya dicatat di kepala berkas.
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

    **Batasnya blok Aturan 32, bukan sampai ekor lint.** Versi lama memotong
    dari judul Aturan 32 sampai `if [ "$status" -eq 0 ]; then` — baris
    penutup **global**. Selama Aturan 32 yang terakhir itu benar; sejak
    aturan 33…106 menyusul, potongannya menjadi 450.583 byte, dan
    `probe()` menyerahkannya ke `bash -c` sebagai satu argumen. Linux
    menolak argumen di atas 128 KiB (`MAX_ARG_STRLEN`), jadi keadaan
    [baseline] pun gagal jalan dan `main` merah:

        OSError: [Errno 7] Argument list too long: 'bash'

    Yang penting: potongan 450 KB itu **bukan** Aturan 32. Ia menjalankan 32
    aturan, mencetak 52 judul, dan `CLEAN_MARK` Aturan 32 bisa datang dari
    aturan mana pun di antaranya — bukti yang hijau untuk alasan yang salah,
    sebelum ia sempat gagal.
    """
    return mutasi_sumber.batas_aturan(
        open(LINT, encoding="utf-8").read(), 32)


def probe(program):
    """Jalankan Aturan 32 sendiri → (merah?, detail).

    Lewat `mutasi_sumber.jalankan_program` (berkas, bukan `bash -c`), supaya
    panjang program tidak bisa lagi membuat harness merah karena batas
    argumen Linux alih-alih karena gerbangnya.
    """
    code, out, err = mutasi_sumber.jalankan_program(program, ROOT)
    if code not in (0, 1):
        return None, (err.strip().splitlines() or ["(tanpa galat)"])[-1]
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
