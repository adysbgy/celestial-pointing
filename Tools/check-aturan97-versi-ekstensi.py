#!/usr/bin/env python3
"""Aturan 97: setiap target yang Info.plist-nya memakai variabel build wajib
mendefinisikan variabel itu di scope target tersebut.

Kenapa aturan ini ada.

Cacat aslinya bukan tebakan: ia tertulis di log Apple Build setiap kali
alur kerja itu berjalan.

    warning: The CFBundleVersion of an app extension (null) must match that
    of its containing parent app ('1').

Penyebabnya di `project.yml`: target `PointAndKnow Watch Complication`
menulis

    info:
      properties:
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)

tapi `settings.base`-nya hanya berisi bundle id, nama produk, dan
`SKIP_INSTALL`. `CURRENT_PROJECT_VERSION` memang didefinisikan — di target
**app jam** dan **app iPhone** — dan XcodeGen tidak mewariskan `settings`
dari app ke extension yang di-embed. Jadi di scope extension kedua variabel
itu kosong, dan Info.plist yang dihasilkan berisi string literal `null`.

Kenapa tidak ada yang menangkapnya:

  * Bukan warning compiler kode sendiri, jadi gerbang "gagal bila ada
    compiler warning" di `ios-build.yml` tidak berbunyi — ia memeriksa
    keluaran `swiftc`, bukan `actool`/validasi bundel.
  * Bukan teks di layar, jadi 96 aturan UI tidak melihatnya.
  * `Tools/check-aturan*` lain membaca `Apps/`, bukan `project.yml`.
  * Build tetap **hijau**: Info.plist berisi `null` masih bisa dibangun dan
    dijalankan di simulator. Yang menolaknya adalah App Store, jauh
    belakangan — dan itu bentuk kegagalan yang paling mahal.

Yang diperiksa di sini adalah hal yang sebenarnya penting: setiap
`$(VARIABLE)` di `info.properties` sebuah target harus terdefinisi di
`settings` target itu sendiri, di salah satu config-nya, atau di `base`.
Mewarisi dari target lain **tidak** dihitung, karena itulah persis bug
yang terjadi.

Kenapa diparse dengan PyYAML, bukan regex: `project.yml` berisi komentar
panjang dan blok multi-baris; regex akan membaca komentar sebagai kode dan
melaporkan target yang tidak ada. PyYAML tersedia di runner CI (dipakai
XcodeGen sendiri) dan di mesin pengembang.

Yang TIDAK diklaim: aturan ini tidak memeriksa apakah nilainya **benar**
(hanya bahwa variabelnya terdefinisi), tidak memeriksa `entitlements`, dan
tidak menggantikan validasi App Store.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

AKAR = Path(__file__).resolve().parent.parent
PROYEK = AKAR / "project.yml"

#: Variabel yang selalu disediakan Xcode/XcodeGen sendiri — tidak perlu
#: didefinisikan di `settings` target.
BAWAAN_XCODE = {
    "PRODUCT_NAME",
    "PRODUCT_BUNDLE_IDENTIFIER",
    "TARGET_NAME",
    "SRCROOT",
    "PROJECT_DIR",
    "CONFIGURATION",
    "DEVELOPMENT_LANGUAGE",
    "EXECUTABLE_NAME",
    "PLATFORM_NAME",
}

VAR = re.compile(r"\$\(([A-Za-z_][A-Za-z0-9_]*)\)")


def ambil_variabel(nilai) -> set[str]:
    """Semua `$(VAR)` di dalam sebuah nilai Info.plist, rekursif."""
    hasil: set[str] = set()
    if isinstance(nilai, str):
        hasil.update(VAR.findall(nilai))
    elif isinstance(nilai, dict):
        for v in nilai.values():
            hasil |= ambil_variabel(v)
    elif isinstance(nilai, list):
        for v in nilai:
            hasil |= ambil_variabel(v)
    return hasil


def variabel_target(target: dict) -> set[str]:
    """Variabel yang didefinisikan `settings` target itu sendiri."""
    definisi: set[str] = set()
    settings = target.get("settings") or {}
    definisi.update((settings.get("base") or {}).keys())
    for cfg in (settings.get("configs") or {}).values():
        definisi.update((cfg or {}).keys())
    return definisi


def main() -> int:
    if not PROYEK.exists():
        print(f"FAIL {PROYEK} tidak ada: Aturan 97 tidak mengukur apa pun.")
        return 1

    data = yaml.safe_load(PROYEK.read_text(encoding="utf-8"))
    targets = data.get("targets") or {}
    if not targets:
        print("FAIL project.yml tidak punya `targets`: Aturan 97 tidak mengukur apa pun.")
        return 1

    masalah: list[str] = []
    diperiksa = 0

    for nama, target in targets.items():
        if not isinstance(target, dict):
            continue
        info = target.get("info") or {}
        properti = info.get("properties") or {}
        dipakai = ambil_variabel(properti)
        if not dipakai:
            continue
        diperiksa += 1
        tersedia = variabel_target(target) | BAWAAN_XCODE
        for var in sorted(dipakai - tersedia):
            masalah.append(
                f"target '{nama}': Info.plist memakai $({var}) tapi variabel itu "
                f"tidak didefinisikan di settings target ini — nilainya akan "
                f"menjadi literal 'null' di bundel."
            )

    if diperiksa == 0:
        # Nol target yang diperiksa berarti aturan ini tidak mengukur apa pun;
        # hijau di sini akan menyesatkan.
        print("FAIL tidak ada target dengan `info.properties` bervariabel: "
              "Aturan 97 tidak mengukur apa pun.")
        return 1

    if masalah:
        print(f"FAIL {len(masalah)} variabel build tidak terdefinisi:")
        for m in masalah:
            print(f"  - {m}")
        print("-> Definisikan variabelnya di `settings.base` target itu, atau")
        print("   hapus rujukan $(...) dari info.properties. Jangan longgarkan")
        print("   aturannya.")
        return 1

    print(f"OK {diperiksa} target: setiap variabel di info.properties "
          f"terdefinisi di settings target itu sendiri.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
