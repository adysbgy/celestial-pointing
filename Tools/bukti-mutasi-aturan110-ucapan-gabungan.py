#!/usr/bin/env python3
"""Buktikan Aturan 110 **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis — itu bukan bukti apa pun.
Yang harus dibuktikannya adalah sebaliknya: **kelas cacat yang membuatnya
ditulis harus berubah putusan** kalau dikenakan lagi. Aturan 110 lahir dari
pengukuran bahwa tiga dari empat label VoiceOver yang FASE A tuntut bisa
dihapus satu per satu dengan `swift-ui-lint.sh` **exit 0** — jadi buktinya
harus menghapus label itu kembali, dan menuntut gerbangnya memerah.

Yang membuat kelas cacat ini tak terlihat: `.accessibilityElement(children:
.combine)` bukan hiasan. Ia mengganti seluruh subtree dengan SATU elemen yang
diumumkan murni dari labelnya. Menghapus `.accessibilityLabel` dari sana sah
secara tipe — compiler hanya melihat sebuah modifier yang hilang — tapi kartu
keadaan dan tombol yang persis FASE A tuntut jadi **senyap** bagi pembaca
layar. Bukan kurang baik: hilang.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  1. bersih (acuan)              Wajib hijau. Kalau tidak, harness salah.
  2. label statusCard dihapus    Cacat aslinya: kartu keadaan — tepat yang
                                 FASE A tuntut — kembali senyap.
  3. label banner GoTo dihapus   Situs terpisah, dan inilah yang menemukan
                                 bahwa 15 elemen punya label sementara satu
                                 tidak. Sebelum perbaikan siklus ini,
                                 keadaan ini **hijau**; sekarang wajib merah.
  4. hanya komentar ditambahkan Kontrol negatif, dan tanpa itu aturan yang
                                 memerah atas *teks* juga akan lulus sebagai
                                 "berbunyi". Gambarnya tidak berubah sampai
                                 bit, jadi wajib HIJAU.
  5. semua label dibuang         Kontrol negatif sisi lain: gerbang yang
                                 kehilangan subjeknya harus merah, bukan
                                 hijau tanpa mengukur apa pun.

Yang TIDAK diklaim: harness ini tidak menguji apakah **isi** ucapan itu benar
— itu urutan tes PointingKit (`SlewVerdictTests`). Ia hanya membuktikan
bentuknya terpaku. Ia juga tidak menguji tombol yang tidak memakai `.combine`:
mereka masih bisa kehilangan label tanpa berbunyi, dan itu batas yang dicatat
di `check-aturan110-ucapan-gabungan.py`.

Cacat yang ditemukan di siklus ini, pada harness ini sendiri. Harness pertamanya
memutuskan merah/hijau dari tanda `CLEAN_MARK = "punya ucapan"` yang dicari
di keluarannya. Aturan ini mencetak judulnya **sebelum** mengukur —

    == Aturan 110: elemen gabungan wajib punya ucapan ==

— dan "punya ucapan" adalah substring dari judul itu. Jadi tanda itu hadir di
**setiap** keluaran, termasuk ketika aturan merah, dan `clean` selalu benar:
lima keadaan terukur HIJAU. Harnessnya hijau atas gerbang yang tak pernah
berbunyi, dan ia lolos ke CI. Siklus ini juga menemukan batas blok
checker-nya (`_blk_end`) mencari kata kunci berikutnya, bukan kurung, sehingga
blok 239 baris menelan label deklarasi sesudahnya. Keduanya tertangkap karena
harness ini dijalankan **lokal sampai selesai**, bukan dianggap hijau karena
sudah terdaftar di CI.
"""
from __future__ import annotations

import os
import re
import signal
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
VIEW = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                    "PointingView.swift")
BANNER = os.path.join(ROOT, "Apps", "Shared", "SlewVerdictBanner.swift")

#: Tanda yang dicetak Aturan 110 saat bersih. Dibaca dari keluaran lint,
#: bukan ditulis ulang, supaya perubahan pesannya tidak membuat harness ini
#: berbohong.
#:
#: **Kenapa bukan "punya ucapan".** Aturan ini mencetak judulnya sendiri
#: **sebelum** mengukur:
#:
#:     == Aturan 110: elemen gabungan wajib punya ucapan ==
#:
#: dan "punya ucapan" adalah substring dari judul itu. Dipakai sebagai tanda
#: bersih, ia hadir di **setiap** keluaran — termasuk saat aturan merah —
#: jadi `clean` selalu benar dan kelima keadaan terukur HIJAU. Harness hijau
#: atas gerbang yang tak pernah berbunyi: cacat yang sama persis dengan yang
#: ditutup Aturan 107, kali ini di sisi pembaca keluarannya.
#:
#: Yang dicari sekarang adalah kalimat hasil yang **hanya** muncul saat
#: bersih: "di {n} berkas punya ucapan". Bagian "di ... berkas" membuatnya
#: tak mungkin muncul di judul, dan `{n}` dicek > 0 supaya hijau atas nol
#: subjek tidak terbaca sebagai bersih.
CLEAN_RE = re.compile(r"di (\d+) berkas punya ucapan")


def bersih(keluaran: str) -> bool:
    """Aturan 110 hijau? — dari kalimat hasilnya, bukan dari judulnya."""
    m = CLEAN_RE.search(keluaran)
    return m is not None and int(m.group(1)) > 0

#: Jangkar di view: kartu keadaan, tepat yang FASE A tuntut.
VIEW_LABEL = "        .accessibilityLabel(statusAccessibilityLabel)\n"
#: Jangkar di banner: ucapan putusan GoTo.
BANNER_LABEL = "            .accessibilityLabel(decision.spokenVerdict ?? text)\n"

STATES = [
    ("1. bersih (acuan)", None, False),
    ("2. label statusCard dihapus",
     [(VIEW, VIEW_LABEL, "")],
     True),
    ("3. label banner GoTo dihapus",
     [(BANNER, BANNER_LABEL, "")],
     True),
    # Hanya komentar: jangkar dipisahkan dari `.combine` oleh baris komentar
    # baru. Gambarnya tidak berubah sampai bit, jadi wajib HIJAU.
    ("4. hanya komentar ditambahkan",
     [(VIEW, VIEW_LABEL,
       "        // Digabung jadi SATU elemen: tanpa `.combine`, VoiceOver\n"
       "        // membaca simbol, label, panduan, dan laju sebagai empat\n"
       "        // item terpisah yang harus diusap satu per satu.\n" + VIEW_LABEL)],
     False),
    # Semua label sesudah `.combine` di kedua berkas dibuang.
    ("5. semua label sesudah .combine dibuang",
     [(VIEW, VIEW_LABEL, ""),
      (BANNER, BANNER_LABEL, "")],
     True),
]

_SOURCES = (VIEW, BANNER)
_originals = {}


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal."""
    for path, content in _originals.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)


def extract_rule110():
    """Ambil program Aturan 110 dari `swift-ui-lint.sh`.

    Kenapa diekstrak, bukan disalin: harness yang menyalin aturannya akan
    tetap hijau walau aturan aslinya dilonggarkan — persis kelas cacat yang
    ditutup `check-harness-terdaftar.py` (gerbang yang tidak pernah
    dieksekusi selalu hijau). Yang diukur harus aturan yang CI jalankan.
    """
    return mutasi_sumber.batas_aturan(
        open(LINT, encoding="utf-8").read(), 110)


def probe(program):
    """Jalankan Aturan 110 sendiri → (merah?, detail).

    Lewat `mutasi_sumber.jalankan_program` (berkas, bukan `bash -c`), supaya
    panjang program tidak bisa lagi membuat harness merah karena batas
    argumen Linux alih-alih karena gerbangnya.
    """
    code, out, err = mutasi_sumber.jalankan_program(program, ROOT)
    if code not in (0, 1):
        return None, (err.strip().splitlines() or ["(tanpa galat)"])[-1]
    return (not bersih(out)), out.strip()


def main():
    mutasi_sumber.require_clean_sources(list(_SOURCES))

    program = extract_rule110()
    if program is None:
        print("GERBANG: program Aturan 110 tidak ditemukan di "
              "swift-ui-lint.sh — harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)
    if "elemen gabungan wajib punya ucapan" not in program:
        print("GERBANG: Aturan 110 tidak mencetak judulnya sendiri; harness "
              "tidak bisa membedakan aturan ini dari yang lain.",
              file=sys.stderr)
        sys.exit(2)

    for path in _SOURCES:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()
    for path, anchor, label in ((VIEW, VIEW_LABEL, "label statusCard"),
                                (BANNER, BANNER_LABEL, "label banner")):
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
            for path in _SOURCES:
                mutasi_sumber.write_source(path, _originals[path])
            if mutations is not None:
                pending = {path: _originals[path] for path in _SOURCES}
                anchor_missing = False
                for path, old, new in mutations:
                    content = pending[path].replace(old, new, 1)
                    if content == pending[path]:
                        print(f"{label:44s} ANCHOR TIDAK DITEMUKAN: {old!r}")
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
                print(f"{label:44s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue
            if fired != must_fire:
                print(f"{label:44s} TIDAK SESUAI "
                      f"(diharapkan {'MERAH' if must_fire else 'HIJAU'}, "
                      f"didapat {'MERAH' if fired else 'HIJAU'})")
                print("    " + detail.splitlines()[0])
                unexpected += 1
            else:
                print(f"{label:44s} {'MERAH' if fired else 'HIJAU'}")
    finally:
        restore()

    ok, _ = probe(program)
    if ok is None or ok:
        print("\nPohon tidak pulih bersih — periksa `git status`.")
        unexpected += 1

    if unexpected:
        print(f"\n{unexpected} keadaan tidak sesuai harapan.")
        return 1
    print("\nSemua keadaan sesuai harapan: Aturan 110 berbunyi atas label "
          "yang hilang, dan tetap hijau atas sekadar komentar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
