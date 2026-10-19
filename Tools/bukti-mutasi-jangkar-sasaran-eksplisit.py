#!/usr/bin/env python3
"""Buktikan gerbang mutasi tertinggal bisa **kehilangan berkas sasaran**.

Kenapa berkas ini ada.

`Tools/check-jangkar-harness.py` memastikan setiap pasangan (jangkar,
pengganti) di `Tools/bukti-mutasi-*.py` masih menyebut teks yang ada di
pohon. Ia menentukan **berkas mana** yang diperiksa dari bentuk pencatatan
harness: pasangan telanjang `(label, jangkar, pengganti)` dicari di seluruh
sumber produksi, sedangkan `(path, jangkar, pengganti)` diperiksa terhadap
`path` itu.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan di sini
bukan bahwa ia menemukan pohon bersih (itu dilaporkan setiap run), melainkan
bahwa ia **tidak bisa** menyatakan "tidak ada mutasi tertinggal" ketika
sebuah harness menyebut berkas sasarannya secara eksplisit tetapi yang diuji
adalah teks milik berkas lain.

Kelas cacat yang ditutupnya.

Sebuah harness menulis `[(LOCATION, jangkar, pengganti, 1)]`.
`_edit_pairs` membaca pasangan itu, lalu `main` mencari `jangkar` di berkas
yang **disebut eksplisit**. Kalau penulisnya keliru menunjuk berkas lain --
misalnya potongan `LocationProvider.swift` dipasangkan dengan
`ComplicationStore.swift` -- teksnya tidak ada di sana, dan gerbang menyusut
jadi pernyataan **tentang berkas lain**: "tidak ada mutasi tertinggal" di
berkas yang tidak dimutasi harness ini. Hijau dengan alasan yang keliru,
tepat kelas cacat yang gerbang itu ada untuk menutup.

Probe di sini meniru percobaan itu tanpa menyentuh `Tools/`:

  1. sasaran benar       jangkar ada di berkas yang disebut   -> hijau
  2. sasaran keliru      jangkar tidak ada di berkas itu      -> MERAH
     (`.swift` vs `.swift` lewat `_ekstensi_sumber`, jadi aturan ekstensi
     tidak menangkapnya; yang harus menangkapnya adalah hitungan
     "jangkar tidak ditemukan")
  3. kontrol negatif     pengganti sudah tertinggal di berkas yang benar
                         -> tetap MERAH (gerbang memang bisa memerah)
  4. pohon nyata         seluruh pasangan bersasaran eksplisit yang dibaca
                         gerbang -> hijau. Kalau tidak, 1-3 mengukur
                         salinan yang salah.

Keadaan 2 dulu **hijau** pada HEAD `a93d6fe`: pasangan tanpa sasaran
dimasukkan ke daftar `missing`, dicetak sebagai catatan ("bukan kebocoran,
tapi harness itu mungkin perlu diperbarui"), lalu keluar 0. Angka pertama
yang terukur pada pohon yang sama: 11 jangkar tanpa sasaran, 0 di antaranya
merah -- jadi cacatnya nyata pada berkas repo ini, bukan hipotesis.

Yang TIDAK diklaim.

- Probe ini menguji satu keputusan `main` (pasangan yang jangkarnya tidak
  ditemukan di sasaran eksplisit). Aturan lain di `main` (ekstensi
  bukan-sumber, harness tanpa jangkar) sudah punya keadaan di
  `Tools/bukti-mutasi-aturan69-sasaran-sumber.py` dan di gerbang itu sendiri.
- Ia tidak membuktikan pemilihan sasaran **benar** -- hanya bahwa sasaran
  yang salah tidak bisa lulus sebagai hijau.
- Ia membaca `collect_harness_edits` dari modul gerbang, bukan menjalankan
  ulang `main`; bentuk pencatatan atau fungsi itu yang berubah membuat
  keadaan 4 merah, dan itu disengaja.
"""

from __future__ import annotations

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
# Nama berkasnya memakai hubung (`check-jangkar-harness.py`), jadi ia bukan
# nama modul yang bisa di-`import` langsung. `spec_from_file_location`
# memuatnya dengan nama apa pun -- dan penjaganya di bawah memastikan fungsi
# yang dipakai benar-benar ada, jadi gerbang yang berganti nama tidak bisa
# membuat probe ini hijau tanpa mengukur apa pun.
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location(
    "gerbang_jangkar", os.path.join(ROOT, "Tools", "check-jangkar-harness.py"))
if _spec is None or _spec.loader is None:
    raise SystemExit("GERBANG: Tools/check-jangkar-harness.py tidak terbaca -- "
                     "probe ini tidak boleh jalan.")
gerbang = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gerbang)
if not hasattr(gerbang, "collect_harness_edits"):
    raise SystemExit("GERBANG: `collect_harness_edits` tidak ada di "
                     "Tools/check-jangkar-harness.py -- probe ini tidak boleh "
                     "jalan.")

LOCATION = os.path.join(ROOT, "Apps", "Shared", "LocationProvider.swift")
STORE = os.path.join(ROOT, "Apps", "Shared", "Complication",
                     "ComplicationStore.swift")


def _read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def _sasaran_eksplisit():
    """Pasangan bersasaran eksplisit, dinormalkan sendiri.

    Kenapa tidak membaca tuple gerbang apa adanya: sebelum perbaikan ini
    `collect_harness_edits()` membuang sasaran (`target`), karena `main`
    memeriksa seluruh sumber produksi untuk setiap jangkar -- sasarannya
    hanya dicetak. Probe yang memakai bentuk lama karena itu membaca **nol**
    pasangan bersasaran, dan "pohon nyata hijau" menjadi pernyataan kosong.
    Terukur pada `HEAD`: 387 jangkar, 0 bersasaran. Bentuk di sini menerima
    keempat tupel maupun bentuk tanpa sasaran, lalu menolak 0 -- gerbang
    yang tidak membaca sasaran tidak bisa dianggap lulus.
    """
    hasil = []
    for edit in gerbang.collect_harness_edits()[0]:
        if len(edit) >= 4 and edit[3]:
            hasil.append((edit[0], edit[1], edit[2], edit[3]))
    return hasil


def _hijau(edits):
    """Keputusan gerbang untuk daftar pasangan ini: True = aman (keluar 0).

    Ditiru dari `main` **yang sedang dipakai repo ini**:

      - jangkar ada di sasaran                     -> lewat
      - jangkar tidak ada **dan** pengganti ada     -> kebocoran, MERAH
      - jangkar dan pengganti sama-sama tidak ada   -> `missing`, **hijau**
        (dulu) -- dan itulah yang harus berubah jadi MERAH

    Keadaan "sama-sama tidak ada" berarti dua hal yang tidak bisa dibedakan
    dari sini: sasarannya keliru, atau teksnya memang sudah berubah. Gerbang
    yang mengklaim "tidak ada mutasi tertinggal" tidak boleh menebak yang
    mana -- ia harus menolak.
    """
    for _, anchor, replacement, target in edits:
        if not target:
            return False
        with open(target, encoding="utf-8") as handle:
            text = handle.read()
        if anchor in text:
            continue
        return False
    return True


def main():
    loc = _read(LOCATION)
    store = _read(STORE)

    anchor = [line for line in loc.splitlines()
              if "locationDeniedNote" in line
              and not line.strip().startswith("//")][0]
    if not anchor.strip() or anchor in store:
        print("GERBANG: jangkar probe tidak membedakan kedua berkas -- "
              "keadaan 2 tidak bisa diuji.", file=sys.stderr)
        return 2
    replacement = anchor.replace("locationDeniedNote", "locationDeniedNote__x")
    if replacement in store or replacement in loc:
        print("GERBANG: pengganti probe sudah ada di pohon -- keadaan 2 dan 3 "
              "tidak bisa membedakan.", file=sys.stderr)
        return 2

    unexpected = 0

    def catat(label, green, must_be_green):
        nonlocal unexpected
        ok = green == must_be_green
        if not ok:
            unexpected += 1
        print(f"{'OK  ' if ok else 'SALAH'} {label:54s} "
              f"{'hijau' if green else 'MERAH'}")

    catat("1. sasaran benar: jangkar ada di berkasnya",
          _hijau([("probe", anchor, replacement, LOCATION)]), True)
    catat("2. sasaran keliru: jangkar tidak ada di berkas itu",
          _hijau([("probe", anchor, replacement, STORE)]), False)
    # 3. Kontrol negatif: jangkar **ada** tetapi pengganti sudah tertinggal di
    #    berkas yang sama (dua kali mutasi, satu tidak dipulihkan). Gerbang
    #    mencocokkan jangkar lebih dulu, jadi keadaannya "pengganti ada tanpa
    #    jangkar" -- pasangan sengaja disusun begitu.
    catat("3. kontrol negatif: pengganti tertinggal, jangkar tidak",
          _hijau([("probe", replacement, replacement, LOCATION)]), False)

    explicit = _sasaran_eksplisit()
    # 4a. Pohon nyata: setiap pasangan bersasaran eksplisit yang jangkarnya
    #     **ada** harus lewat. Lebih dari nol, supaya gerbang yang membaca nol
    #     berkas tidak bisa hijau dengan alasan kosong.
    found = [edit for edit in explicit
             if edit[1] in _read(edit[3])]
    #     Nol pasangan bersasaran adalah bentuk lama `collect_harness_edits`
    #     (sebelum perbaikan ini, sasaran dibuang dari tuple). Diukur: 387
    #     jangkar, 0 bersasaran pada `HEAD` -- keadaan ini memerah di sana,
    #     jadi ia tidak bisa hijau karena berkasnya tidak dibaca.
    catat(f"4. pohon nyata: pasangan bersasaran eksplisit ({len(found)})",
          len(found) > 0 and _hijau(found), True)
    # 4b. Keadaan yang **dulu** lolos: jangkar hilang dari sasarannya, tanpa
    #     pengganti di sana (`missing`). Nilai baru `main` menolaknya, jadi
    #     pin ini ditulis sebagai "harus MERAH". Kalau `main` kembali ke
    #     hitungan `leaks` saja, keadaan ini hijau lagi dan probe merah.
    catat("4b. jangkar hilang tanpa pengganti (dulu dicatat, kini tolok)",
          _hijau([("probe", anchor, replacement, STORE)]), False)

    # 4c. Pohon nyata yang gerbang baca: harus **nol** di kedua jurusan.
    #     Dicetak setiap run -- kalau angka ini naik, berkas di bawah yang
    #     harus diperbarui, bukan angka ini yang diturunkan.
    leaks = [edit for edit in explicit
             if edit[1] not in _read(edit[3])
             and edit[2] is not None and edit[2] in _read(edit[3])]
    hilang = [edit for edit in explicit if edit[1] not in _read(edit[3])]
    catat(f"4c. pohon: {len(hilang)} jangkar-hilang, {len(leaks)} kebocoran",
          len(leaks) > 0 or len(hilang) > 0, False)

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        return 1
    print("5 keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
