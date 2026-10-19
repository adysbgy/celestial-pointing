#!/usr/bin/env python3
"""Buktikan Aturan 68 (satu App Group di Swift + semua entitlements) **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia bisa merah, merah pada keadaan yang memang salah, dan merah karena
bentuk yang dilanggar -- bukan sekadar keluar != 0.

Kelas cacat yang ditutupnya, dan **diukur** sebelum aturan ini ada.

App Group adalah satu nilai yang ditulis di tiga berkas yang tidak saling
tahu:

    Apps/Shared/Complication/ComplicationStore.swift   (Swift)
    Apps/PointAndKnowWatch/PointAndKnowWatch.entitlements
    Apps/PointAndKnowWatch/Complications/…entitlements

Complication watchOS berjalan di proses terpisah; satu-satunya cara ia tahu
objek terakhir yang terkunci adalah berkas yang dibagi lewat group ini.
Terukur pada salinan utuh, proses baru, sebelum Aturan 68 ada:

    group complication -> ".typo"     lint exit 0, swift-test exit 0
    group app          -> ".typo"     lint exit 0, swift-test exit 0
    appGroupID di Swift -> ".lain"    lint exit 0, swift-test exit 0

Ketiganya membuat complication gagal **diam**: `containerURL:` mengembalikan
nil, store jatuh ke cache yang berbeda, dan complication memeriksa cache-nya
sendiri selamanya. Tidak crash, tidak ada galat, tidak ada log. Di CI (tanpa
tanda tangan) kedua jalur memang selalu memakai fallback cache, jadi build
paling hijau justru saat keduanya berbeda.

Keadaan yang diuji:

  1. entitlements complication -> group lain   MERAH
  2. entitlements app jam      -> group lain   MERAH
  3. appGroupID di Swift       -> group lain   MERAH
  4. kontrol negatif: pohon apa adanya         hijau
  5. fail-closed: blok array dikosongkan       MERAH
     (sumber tampak, tetapi tidak menyebut nilai apa pun)

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap hijau
walau aturan aslinya dilonggarkan.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
SWIFT = os.path.join(ROOT, "Apps", "Shared", "Complication",
                     "ComplicationStore.swift")
ENT_APP = os.path.join(ROOT, "Apps", "PointAndKnowWatch",
                       "PointAndKnowWatch.entitlements")
ENT_COMP = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Complications",
                        "PointAndKnowWatchComplication.entitlements")

RULE_HEADER = "# \u2500\u2500 Aturan 68:"
#: Bentuk yang dicari di keluaran aturan ketika ia berbunyi karena group.
PANEL_MARK = "App Group"
GROUP = "group.dev.celestial.pointandknow"

STATES = [
    ("[baseline]", None, False),
    ("1 entitlements complication -> lain",
     [(ENT_COMP, "<string>group.dev.celestial.pointandknow</string>",
       "<string>group.dev.celestial.pointandknow.lain</string>", 1)], True),
    ("2 entitlements app jam -> lain",
     [(ENT_APP, "<string>group.dev.celestial.pointandknow</string>",
       "<string>group.dev.celestial.zlain</string>", 1)], True),
    ("3 appGroupID Swift -> lain",
     [(SWIFT, 'static let appGroupID = "group.dev.celestial.pointandknow"',
       'static let appGroupID = "group.dev.celestial.lain"', 1)], True),
    ("4 kontrol negatif: pohon apa adanya", None, False),
    ("5 fail-closed: blok array dikosongkan",
     [(ENT_COMP, "        <string>group.dev.celestial.pointandknow</string>\n",
       "", 1)], True),
]

#: Keadaan yang diuji terhadap lint PRA-perbaikan. Kalau lint lama sudah merah
#: atas mutasi yang sama, keadaan 1-3 tidak membuktikan adanya lubang.
#:
#: Jangkar ditulis **literal**, bukan f-string yang merujuk `GROUP`: pembaca
#: `Tools/check-jangkar-harness.py` menyelesaikan konstanta bernama dan string
#: telanjang, tetapi tidak mengevaluasi f-string. Bentuk yang tidak bisa dibaca
#: statis membuat harness ini "menanam mutasi tanpa satu jangkar pun" — gerbang
#: itu justru benar, dan cara menutupnya adalah membuat jangkarnya bisa dibaca,
#: bukan mengecualikannya (`JANGKAR_KECUALI`).
ARAH_KEDUA = [
    ("lint lama: entitlements complication -> lain",
     [(ENT_COMP, "<string>group.dev.celestial.pointandknow</string>",
       "<string>group.dev.celestial.pointandknow.lain</string>", 1)]),
    ("lint lama: appGroupID Swift -> lain",
     [(SWIFT, 'static let appGroupID = "group.dev.celestial.pointandknow"',
       'static let appGroupID = "group.dev.celestial.lain"', 1)]),
]

#: Arah kedua tidak memakai commit pra-perbaikan: blok Aturan 68 **dicabut**
#: dari lint di disk dan dikirim lewat stdin. Alasannya, tanpa commit pra,
#: urutan commit unit ini sendiri bisa membuat `HEAD` memuat aturan yang
#: sedang diuji -- sehingga arah kedua mengukur salinan dirinya sendiri.


def _bounds(text):
    """Rentang seluruh blok Aturan 68, termasuk pembungkus bash-nya.

    Dipisahkan dari potongan heredoc (`PY` … `)`) karena blok aturan ini juga
    memuat status-harness di belakangnya (`app_group_status=$?` … `fi`).
    Memotong di `PY\\n)` saja akan meninggalkan potongan bash menggantung di
    berkas pra-lint -- yang bukan "aturan dicabut" melainkan berkas rusak.
    """
    start = text.find(RULE_HEADER)
    if start < 0:
        return None, None
    akhir = text.find("\nPY\n)", start)
    if akhir < 0:
        return None, None
    akhir = akhir + len("\nPY\n)")
    # Sertakan pembungkus statusnya sampai baris `fi` penutup, sehingga yang
    # dihapus adalah blok aturan yang utuh, bukan separuhnya.
    penutup = text.find("\nfi\n", akhir)
    if penutup < 0:
        return None, None
    return start, penutup + len("\nfi\n")


def extract_rule68(text=None):
    if text is None:
        text = open(LINT, encoding="utf-8").read()
    start, end = _bounds(text)
    if start is None:
        return None
    body = text[start:end]
    if "app_group=" not in body:
        return None
    return body


def probe(program, cwd=ROOT):
    """Jalankan potongan aturan; True = berbunyi, False = bersih, None = gagal.

    Potongan aturan dari `swift-ui-lint.sh` tidak meng-`exit` sendiri — ia
    menetapkan `status=1` dan kila aturan berjalan. Di berkas asli keputusan
    barulah jadi kode keluar di akhir berkas (`exit "$status"`), dan itu **di
    luar** potongan yang diekstrak. Karena itu satu baris penutup ditambahkan
    di sini: `exit "$status"` apa adanya dari berkas induk, bukan angka yang
    ditulis ulang. Tanpa itu setiap keadaan akan terbaca hijau — probe yang
    tidak bisa merah bukan bukti apa pun.
    """
    sumber = "status=0\n" + program + '\n\nexit "$status"\n'
    proc = subprocess.run(["bash", "-s"], cwd=cwd, input=sumber,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    if "PERINGATAN" in out or "Traceback" in out:
        return True, out.strip()
    return (proc.returncode != 0), out.strip()


_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def pra_lint_dengan_aturan68():
    """Lint pra-perbaikan: dari disk, tetapi Aturan 68 dicabut.

    Kenapa tidak `git show <commit>`: akibat urutan commit, versi yang benar-
    benar bebas Aturan 68 adalah commit sesudah ini. Yang menentukan arah kedua
    adalah **tidak adanya aturan itu**, bukan nomor commit -- dan itu bisa
    dibuktikan dengan mencabut bloknya, bukan dengan menebak ref.
    """
    text = open(LINT, encoding="utf-8").read()
    start, end = _bounds(text)
    if start is None:
        raise SystemExit("GAGAL: blok Aturan 68 tidak ditemukan -- arah kedua "
                         "tidak bisa dijalankan tanpa itu.")
    return text[:start] + text[end:]


def main():
    targets = [SWIFT, ENT_APP, ENT_COMP]
    mutasi_sumber.require_clean_sources(targets)

    program = extract_rule68()
    if program is None:
        print("GERBANG: program Aturan 68 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        return 2

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    # Setiap jangkar harus unik di berkasnya.
    anchors = [(ENT_COMP, GROUP), (ENT_APP, GROUP),
               (SWIFT, f'static let appGroupID = "{GROUP}"')]
    for path, anchor in anchors:
        count = _originals[path].count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {anchor!r} muncul {count}x di "
                  f"{os.path.relpath(path)}, harus 1 -- harness tidak boleh "
                  "jalan.", file=sys.stderr)
            return 2

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, mutations, must_fire in STATES:
            for path, content in _originals.items():
                mutasi_sumber.write_source(path, content)
            if mutations is not None:
                bad = False
                for target, old, new, jumlah in mutations:
                    base = _originals[target]
                    content = base.replace(old, new, jumlah)
                    if content == base:
                        print(f"{label:48s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(target, content)
                if bad:
                    unexpected += 1
                    continue
            fired, detail = probe(program)
            if fired is None:
                print(f"{label:48s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue
            ok = (fired == must_fire)
            if fired and must_fire:
                ok = PANEL_MARK in detail
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:48s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if not ok:
                print(f"       {detail[:300]}")

        # Arah kedua: lint tanpa Aturan 68 wajib HIJAU atas cacat yang sama.
        pra = pra_lint_dengan_aturan68()
        if "Aturan 68" in pra:
            print("SALAH arah kedua: lint pra masih memuat Aturan 68")
            unexpected += 1
        else:
            for label, mutations in ARAH_KEDUA:
                for path, content in _originals.items():
                    mutasi_sumber.write_source(path, content)
                bad = False
                for target, old, new, jumlah in mutations:
                    base = _originals[target]
                    content = base.replace(old, new, jumlah)
                    if content == base:
                        print(f"SEBELUM {label:44s} JANGKAR TIDAK DITEMUKAN")
                        bad = True
                        continue
                    mutasi_sumber.write_source(target, content)
                if bad:
                    unexpected += 1
                    continue
                # Jalankan lint pra dari stdin: berkasnya tidak disentuh.
                proc = subprocess.run(["bash", "-s"], cwd=ROOT, input=pra,
                                      capture_output=True, text=True)
                fired = proc.returncode != 0
                ok = (not fired)
                if not ok:
                    unexpected += 1
                print(f"{'OK  ' if ok else 'SALAH'} {label:48s} "
                      f"{'MERAH' if fired else 'hijau'}")
    finally:
        for path, content in _originals.items():
            mutasi_sumber.write_source(path, content)
        restore()

    print(f"\n{len(STATES) + len(ARAH_KEDUA)} keadaan, "
          f"{unexpected} tidak sesuai harapan")
    return 0 if unexpected == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
