#!/usr/bin/env python3
"""Buktikan Aturan 91 (sumber terjemahan dipasang di `init()`) **berbunyi**.

Kenapa harness ini ada.

Sebelum Aturan 91, `LocalizationBridge.swift` adalah satu-satunya berkas di
`Apps/` yang tidak dirujuk **satu pun** gerbang. Yang menjaganya hanya kalimat
di docstring. Diukur dengan mencabut panggilan itu dari kedua entry point:
`swift-ui-lint.sh` (90 aturan), `swift-typecheck.sh`, dan 1301 uji tetap
hijau. Artinya bridge bisa lepas dan tidak ada yang berbunyi.

Harness ini mencabutnya lima cara, karena tiap cara gagal di tempat berbeda:

  1. panggilan dihapus dari entry point app jam   — bridge tidak terpasang
  2. panggilan dipindah ke `body`                 — terpasang, tapi terlambat
  3. panggilan dihapus dari entry point iPhone    — target kedua ikut lepas
  4. panggilan dihapus dari complication          — target terpisah ikut lepas
  5. kontrol: pohon apa adanya                    — harus **diam**

Keadaan 2 yang paling penting. "Ada panggilan di berkasnya" adalah bentuk
pemeriksaan yang lolos untuk keadaan 2, dan hasilnya di perangkat sama
buruknya dengan tidak memasang sama sekali: label pertama sudah terbaca
sebelum `body` berjalan, dan tidak ada yang menggambar ulang.

Keadaan 4 menguji hal yang berbeda lagi: complication adalah target terpisah
dengan bridge-nya sendiri. Aturan yang hanya menerima satu nama simbol akan
berbunyi untuk sambungan yang benar — dan aturan yang berbunyi untuk hal
benar akan dimatikan orang.

Cara pakai: python3 Tools/bukti-mutasi-aturan91-bridge-lokalisasi.py
Keluar 0 kalau semua keadaan sesuai harapan, 1 kalau ada yang tidak.
"""
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIN = ["Apps", "Tools"]

JAM = os.path.join("Apps", "PointAndKnowWatch", "Sources",
                   "PointAndKnowWatchWatchApp.swift")
IPHONE = os.path.join("Apps", "PointAndKnowiOS", "Sources", "DiagnosticsView.swift")
COMPLICATION = os.path.join("Apps", "PointAndKnowWatch", "Complications",
                            "ComplicationWidget.swift")

PASANG_JAM = "    init() { LocalizationBridge.install() }"
PASANG_IPHONE = "    init() { LocalizationBridge.install() }"
PASANG_COMPLICATION = "        ComplicationLocalization.install()\n"

# (berkas, teks asli, pengganti, harap_bunyi, keterangan)
KEADAAN = [
    (JAM, PASANG_JAM,
     "    init() { }",
     True,
     "app jam berhenti memasang bridge — label jatuh ke Bahasa Indonesia"),

    # Keadaan yang lolos pemeriksaan naif "berkasnya memuat panggilan".
    (JAM, PASANG_JAM,
     "    init() { }\n\n    private func pasang() { LocalizationBridge.install() }",
     True,
     "bridge dipasang di luar init() — ada, tapi terlambat"),

    (IPHONE, PASANG_IPHONE,
     "    init() { }",
     True,
     "app iPhone berhenti memasang bridge"),

    (COMPLICATION, PASANG_COMPLICATION,
     "",
     True,
     "complication berhenti memasang bridge-nya sendiri (target terpisah)"),

    (None, None, None,
     False,
     "kontrol: pohon apa adanya"),
]


def jalankan(berkas, asli, ganti):
    tmp = tempfile.mkdtemp(prefix="aturan91-")
    try:
        for item in SALIN:
            src = os.path.join(REPO, item)
            dst = os.path.join(tmp, item)
            if os.path.isdir(src):
                shutil.copytree(
                    src, dst,
                    ignore=shutil.ignore_patterns(".build", "*.o", "*.swiftmodule"))
            else:
                shutil.copy2(src, dst)

        if berkas is not None:
            path = os.path.join(tmp, berkas)
            teks = open(path, encoding="utf-8").read()
            if asli not in teks:
                return None, f"jangkar tidak ditemukan di {berkas}"
            open(path, "w", encoding="utf-8").write(teks.replace(asli, ganti, 1))

        r = subprocess.run(
            [sys.executable,
             os.path.join(tmp, "Tools", "check-aturan91-bridge-lokalisasi.py")],
            cwd=tmp, capture_output=True, text=True, timeout=300)
        return r.returncode, r.stdout + r.stderr
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    gagal = 0
    for berkas, asli, ganti, harap_bunyi, ket in KEADAAN:
        kode, keluaran = jalankan(berkas, asli, ganti)
        if kode is None:
            print(f"JANGKAR  {ket}\n         {keluaran}")
            gagal += 1
            continue
        bunyi = kode != 0
        tanda = "bunyi" if bunyi else "diam "
        harap = "harap bunyi" if harap_bunyi else "harap diam "
        if bunyi == harap_bunyi:
            print(f"OK    {tanda} ({harap})  {ket}")
        else:
            print(f"SALAH {tanda} ({harap})  {ket}")
            gagal += 1
            if harap_bunyi and not bunyi:
                print(f"         keluaran: {keluaran.strip()[:400]}")

    print()
    if gagal == 0:
        print("Aturan 91 berbunyi pada keempat cara memutus sumber terjemahan, "
              "dan diam pada pohon apa adanya.")
        return 0
    print(f"{gagal} keadaan tidak sesuai harapan.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
