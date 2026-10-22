#!/usr/bin/env python3
"""Buktikan Aturan 99 berbunyi, bukan hijau saja.

Gerbang yang hijau selamanya tidak membuktikan apa pun. Yang membuktikan
adalah gerbang yang **memerah ketika cacatnya dikembalikan**.

Cacat aslinya terukur, bukan disangka: `ComplicationProvider.getTimeline`
memakai `Timeline(entries: [entry], policy: .never)`, sehingga seluruh lapisan
basi di `ComplicationDigest` — yang diuji rapi di Linux — tidak pernah
berkesempatan dievaluasi pada waktu selain detik penulisannya. `./swift-ui-lint.sh`
hijau (98 aturan, 0 merah), `check-visuals.py` hijau, dan 1095 uji PointingKit
hijau. Tidak satu pun bisa melihatnya: WidgetKit tidak ada di Linux, dan tidak
ada uji yang bisa memanggil `getTimeline`.

Lima keadaan, karena lima jalan berbeda menuju "complication membeku":

  1. **Kembali ke `.never`** — bentuk aslinya, yang lolos seluruh gerbang.
  2. **`.after` dengan angka tetap** (`Date().addingTimeInterval(60)`) —
     menyegar, jadi sapuan "apakah ada `.after`" akan hijau, tetapi waktunya
     tidak berhubungan dengan umur cuplikan: penyegaran pertama mendarat saat
     digest masih segar, menggambar centang hijau sekali lagi, lalu berhenti.
     Bentuk paling sunyi dari kelas ini.
  3. **Cabang `nil` dibuang** — `policy: .after(refresh ?? .distantFuture)`.
     Kompilasinya sah, `.after` ada, aksesornya dipanggil; tetapi digest yang
     sudah basi dijadwalkan menyegar di masa depan tak terhingga.
  4. **Hanya disebut di komentar** — nama `nextRefreshDate` ada di berkas,
     tidak di kode. Sapuan teks yang tidak membuang komentar akan hijau.
  5. **Kontrol negatif** — pohon apa adanya. Harus hijau.

Keadaan 2 dan 4 adalah alasan gerbang ini tidak cukup ditulis sebagai
"apakah `.after(` muncul di berkas". Keadaan 3 adalah alasan ia juga tidak
cukup sebagai "apakah `nextRefreshDate` disebut".

Setiap keadaan menyunting berkas **sungguhan** lalu mengembalikannya, dan
pemulihannya diverifikasi byte-per-byte. Harness menolak berjalan di atas
sumber yang sudah kotor: kalau tidak, ia akan mengadopsi penyimpangan itu
sebagai «aslinya» dan melaporkan «pulih persis» atas dirinya sendiri.
"""

from __future__ import annotations

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True

import mutasi_sumber as M  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GERBANG = "Tools/check-aturan99-complication-menyegar.py"
WIDGET = "Apps/PointAndKnowWatch/Complications/ComplicationWidget.swift"

#: Jangkar mutasi: cabang yang menjadwalkan penyegaran dari umur cuplikan.
JADWAL = """        if let refresh = digest?.nextRefreshDate(after: now) {
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        } else {
            completion(Timeline(entries: [entry], policy: .never))
        }"""


def jalankan() -> tuple[int, str]:
    hasil = subprocess.run([sys.executable, GERBANG], cwd=ROOT,
                           capture_output=True, text=True)
    return hasil.returncode, (hasil.stdout + hasil.stderr).strip()


def main() -> int:
    M.require_clean_sources([WIDGET])

    path = os.path.join(ROOT, WIDGET)
    asli = open(path, encoding="utf-8").read()

    if JADWAL not in asli:
        print("FAIL jangkar jadwal penyegaran tidak ditemukan di widget —")
        print("     harness ini tidak mengukur apa pun. Perbaiki jangkarnya;")
        print("     jangan dihapus.")
        return 1

    # (label, isi widget baru, harapan kode keluar)
    keadaan = [
        ("[baseline] pohon apa adanya", asli, 0),
        ("1. kembali ke `policy: .never` (bentuk aslinya)",
         asli.replace(JADWAL,
                      "        completion(Timeline(entries: [entry], policy: .never))", 1),
         1),
        ("2. `.after` dengan angka tetap, bukan umur cuplikan",
         asli.replace(JADWAL,
                      "        completion(Timeline(entries: [entry],\n"
                      "                               policy: .after(Date().addingTimeInterval(60))))", 1),
         1),
        ("3. cabang `nil` dibuang (`?? .distantFuture`)",
         asli.replace(JADWAL,
                      "        let refresh = digest?.nextRefreshDate(after: now) ?? .distantFuture\n"
                      "        completion(Timeline(entries: [entry], policy: .after(refresh)))", 1),
         1),
        ("4. aksesor hanya disebut di komentar",
         asli.replace(JADWAL,
                      "        // digest?.nextRefreshDate(after: now)\n"
                      "        completion(Timeline(entries: [entry],\n"
                      "                           policy: .after(now.addingTimeInterval(60))))", 1),
         1),
        ("5. kontrol negatif: kode jujur", asli, 0),
    ]

    gagal = 0
    for label, baru, harap in keadaan:
        if label.startswith("[baseline]"):
            kode, keluaran = jalankan()
        else:
            if baru == asli:
                print(f"{label:56s} LEWAT  mutasinya tidak mengubah apa pun — "
                      f"jangkar basi?")
                gagal += 1
                continue
            M.write_source(path, baru)
            try:
                kode, keluaran = jalankan()
            finally:
                M.write_source(path, asli)
                M.restore_verified(path, asli)

        sesuai = (kode == harap)
        tanda = "OK   " if sesuai else "SALAH"
        ringkas = keluaran.splitlines()[0] if keluaran else "(tanpa keluaran)"
        print(f"{tanda} {label:56s} exit={kode} (harap {harap})")
        if not sesuai:
            gagal += 1
            for baris in keluaran.splitlines()[:6]:
                print(f"        {baris}")

    print()
    if gagal:
        print(f"GAGAL: {gagal} keadaan tidak sesuai.")
        return 1
    print(f"LULUS: {len(keadaan)} keadaan, 0 tidak sesuai.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
