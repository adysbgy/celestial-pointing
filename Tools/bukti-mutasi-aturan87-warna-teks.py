#!/usr/bin/env python3
"""Buktikan Aturan 87 (warna teks dari palet) **berbunyi**.

Kenapa harness ini ada.

Mode malam menjanjikan palet merah murni. `Text` tanpa warna jatuh ke
`.primary` = putih di skema gelap, dan itu tepat kanal hijau/biru yang
seluruh mode malam ada untuk menekan ke nol. Sebelum Aturan 87, dua teks
paling penting di app — nama benda di kartu jam dan di panel detail iPhone —
tidak berwarna, dan **nol dari 86 aturan** berbunyi.

Harness ini mencabut jalurnya empat cara, karena keempatnya lolos gerbang
yang berbeda:

  1. akar palet berhenti memasang warna   — satu baris, seluruh pohon putih
  2. akar palet diganti warna tetap       — "ada warna", tetapi bukan palet
  3. satu `Text` kehilangan warnanya di berkas yang **punya** akar
  4. berkas yang tidak punya akar memuat `Text` tanpa warna

Keadaan ketiga adalah yang paling penting: ia lolos versi pertama aturan ini,
yang hanya memeriksa "berkasnya memanggil `forceDarkScheme()`". Satu teks
yang lupa menulis warnanya di berkas yang akarnya benar tetap putih di mode
malam — dan versi pertama itu diam.

Keadaan kelima adalah kontrol: pohon apa adanya harus **diam**.

Cara pakai: python3 Tools/bukti-mutasi-aturan87-warna-teks.py
Keluar 0 kalau semua keadaan sesuai harapan, 1 kalau ada yang tidak.
"""
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIN = ["Apps", "Tools", "Packages", "README.md", "swift-ui-lint.sh", "project.yml"]

TOKENS = os.path.join("Apps", "Shared", "SurfaceTokens.swift")
AKAR_ASLI = "            .foregroundStyle(SurfacePalette.active.textPrimaryColor)\n    }"
CARD = os.path.join("Apps", "PointAndKnowWatch", "Sources", "PointingView.swift")
# Baris akar di layar jam. Menghapusnya membuat **seluruh** teks kartu yang
# tidak menulis warnanya sendiri kembali ke `.primary` — bentuk cacat yang
# paling mungkin terjadi saat seseorang merapikan rantai modifier.
CARD_AKAR = "        .forceDarkScheme()\n"
# Berkas yang warnanya datang dari **pembungkus**, bukan dari akar.
TANPA_AKAR = os.path.join("Apps", "Shared", "SlewVerdictBanner.swift")
TANPA_AKAR_ASLI = "            .foregroundStyle(tone.color)\n"
TANPA_AKAR_GANTI = ""

# (berkas, teks asli, pengganti, harap_bunyi, keterangan)
KEADAAN = [
    (TOKENS, AKAR_ASLI,
     "    }",
     True,
     "akar palet berhenti memasang warna teks (seluruh pohon kembali putih)"),
    (TOKENS, AKAR_ASLI,
     "            .foregroundStyle(Color.white)\n    }",
     True,
     "akar palet diganti warna tetap, bukan palet"),
    (CARD, CARD_AKAR,
     "",
     True,
     "layar jam berhenti memakai akar palet — teksnya kembali putih"),
    (TANPA_AKAR, TANPA_AKAR_ASLI,
     TANPA_AKAR_GANTI,
     True,
     "pembungkus berhenti mewarnai teksnya, dan berkasnya tanpa akar"),
    (None, None, None,
     False,
     "kontrol: pohon apa adanya"),
]


def jalankan(berkas, asli, ganti):
    tmp = tempfile.mkdtemp(prefix="aturan87-")
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
            open(path, "w", encoding="utf-8").write(
                teks.replace(asli, ganti, 1))

        r = subprocess.run(
            [sys.executable, os.path.join(tmp, "Tools", "check-aturan87-warna-teks.py")],
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
        if bunyi == harap_bunyi:
            tanda = "bunyi" if bunyi else "diam "
            harap = "harap bunyi" if harap_bunyi else "harap diam "
            print(f"OK    {tanda} ({harap})  {ket}")
        else:
            tanda = "bunyi" if bunyi else "diam "
            harap = "harap bunyi" if harap_bunyi else "harap diam "
            print(f"SALAH {tanda} ({harap})  {ket}")
            gagal += 1
            if harap_bunyi and not bunyi:
                print(f"         keluaran: {keluaran.strip()[:400]}")

    print()
    if gagal == 0:
        print("Aturan 87 berbunyi pada keempat cara memutus warna teks, "
              "dan diam pada pohon apa adanya.")
        return 0
    print(f"{gagal} keadaan tidak sesuai harapan.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
