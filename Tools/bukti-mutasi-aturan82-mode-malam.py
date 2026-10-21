#!/usr/bin/env python3
"""Buktikan Aturan 82 (Mode Malam bisa dimatikan) **berbunyi**.

Kenapa harness ini ada.

`NightMode.isOn` dibaca 7 tempat di `Apps/` tiap render — `SurfacePalette
.active`, `SkyBackdropView`, dan seluruh kanvas visual. Menggantinya dengan
tetapan membuat saklar Mode Malam menjadi tombol mati, dan itu terukur lolos
seluruh 81 aturan UI sebelum Aturan 82 ada.

Harness ini mencabut jalurnya empat cara berbeda, karena keempatnya lolos
gerbang yang berbeda:

  1. getter jadi `true`        — saklar menyala selamanya
  2. getter jadi `false`       — saklar tidak pernah menyala
  3. getter membaca kunci lain — menyala/mati, tetapi kunci yang salah, jadi
                                 saklar di layar tidak mengubah palet
  4. getter membaca kunci benar lalu membuang nilainya (`&& false`) — bentuk
                                 yang paling menipu: nama kuncinya benar

Keadaan ketiga yang paling penting: ia mengompilasi, ia punya getter, ia
membaca `UserDefaults`, dan ia tetap salah. Aturan yang hanya memeriksa
"ada `UserDefaults`" akan meloloskannya.

Keadaan keempat lolos **versi pertama** Aturan 82, yang menuntut adanya
`bool(forKey: NightModeStorage.key)` tanpa menuntut nilainya dipakai. Ia
ditemukan saat menulis aturannya, bukan sesudah CI merah.

Keadaan kelima adalah kontrol: pohon apa adanya harus **diam**.

Cara pakai: python3 Tools/bukti-mutasi-aturan82-mode-malam.py
Keluar 0 kalau semua keadaan sesuai harapan, 1 kalau ada yang tidak.
"""
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIN = ["Apps", "Tools", "Packages", "README.md", "swift-ui-lint.sh", "project.yml"]
BERKAS = os.path.join("Apps", "Shared", "NightMode.swift")
ASLI = "get { UserDefaults.standard.bool(forKey: NightModeStorage.key) }"

# (teks pengganti, harap_bunyi, keterangan)
KEADAAN = [
    ("get { true }", True,
     "getter jadi tetapan true (merah selamanya)"),
    ("get { false }", True,
     "getter jadi tetapan false (mode malam mati total)"),
    ("get { UserDefaults.standard.bool(forKey: \"nightMode\") }", True,
     "getter membaca kunci lain (saklar tak berpengaruh)"),
    # Keadaan keempat ditemukan oleh aturannya sendiri, bukan oleh harness:
    # versi pertama Aturan 82 hanya menuntut **adanya** bacaan `bool(forKey:)`
    # terhadap kunci yang benar. Bentuk di bawah membaca kunci yang benar,
    # menyebut nama yang benar, dan tetap memaku palet merah. Ia lolos versi
    # pertama itu (exit 0) — jadi ia masuk ke sini sebagai keadaan yang wajib
    # berbunyi, dan aturannya yang diperbaiki.
    ("get { UserDefaults.standard.bool(forKey: NightModeStorage.key) && false }", True,
     "getter membaca kunci benar tetapi membuang nilainya"),
    (None, False,
     "kontrol: pohon apa adanya"),
]


def jalankan(pengganti):
    tmp = tempfile.mkdtemp(prefix="aturan82-")
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

        path = os.path.join(tmp, BERKAS)
        if pengganti is not None:
            teks = open(path, encoding="utf-8").read()
            if ASLI not in teks:
                return None, f"jangkar tidak ditemukan di {BERKAS}"
            open(path, "w", encoding="utf-8").write(teks.replace(ASLI, pengganti, 1))

        r = subprocess.run(
            ["bash", "swift-ui-lint.sh"], cwd=tmp,
            capture_output=True, text=True, timeout=600)
        return r.returncode, r.stdout
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    gagal = 0
    for pengganti, harap_bunyi, ket in KEADAAN:
        kode, keluaran = jalankan(pengganti)
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
                # Tunjukkan aturan mana yang seharusnya berbunyi.
                baris = [l for l in keluaran.split("\n") if "Aturan 82" in l]
                if baris:
                    print("         " + baris[0].strip())

    print()
    if gagal == 0:
        print("Aturan 82 berbunyi pada keempat cara memutus saklar Mode Malam, "
              "dan diam pada pohon apa adanya.")
        return 0
    print(f"{gagal} keadaan tidak sesuai harapan.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
