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

Kenapa ada parser YAML sendiri, bukan PyYAML: percobaan pertama memakai
`import yaml`, hijau di mesin pengembang, lalu **merah di macOS runner**
dengan `ModuleNotFoundError: No module named 'yaml'` — gerbang yang hanya
bisa berjalan di satu mesin bukan gerbang. `project.yml` di repo ini hanya
memakai subset YAML yang sempit (mapping bersarang + list skalar), jadi
parser indentasi di bawah cukup, dan tidak menambah dependensi yang harus
diinstal CI.

Yang TIDAK diklaim: aturan ini tidak memeriksa apakah nilainya **benar**
(hanya bahwa variabelnya terdefinisi), tidak memeriksa `entitlements`, dan
tidak menggantikan validasi App Store. Parser di bawah bukan YAML lengkap —
ia sengaja menolak berkas yang memakai flow mapping (`{a: b}`) atau anchor,
karena pada berkas seperti itu ia bisa diam-diam salah membaca.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

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


class YamlTidakDidukung(Exception):
    """Berkas memakai bentuk YAML yang tidak bisa dibaca parser ini."""


def buang_komentar(baris: str) -> str:
    """Buang komentar `#` yang tidak berada di dalam tanda kutip."""
    keluaran = []
    kutip = None
    for i, c in enumerate(baris):
        if kutip:
            if c == kutip:
                kutip = None
        elif c in "'\"":
            kutip = c
        elif c == "#" and (i == 0 or baris[i - 1] in " \t"):
            break
        keluaran.append(c)
    return "".join(keluaran).rstrip()


def skalar(teks: str) -> str:
    teks = teks.strip()
    if len(teks) >= 2 and teks[0] == teks[-1] and teks[0] in "'\"":
        return teks[1:-1]
    return teks


def muat_yaml(teks: str) -> dict:
    """Parser YAML subset: mapping bersarang + list skalar.

    Cukup untuk `project.yml` di repo ini. Bentuk yang tidak didukung
    dilempar sebagai `YamlTidakDidukung`, bukan diabaikan — supaya gerbang
    tidak pernah "hijau karena tidak membaca apa pun".
    """
    akar: dict = {}
    # Tumpukan (indentasi, mapping) — mapping teratas selalu tujuan penulisan.
    tumpukan: list[tuple[int, dict]] = [(-1, akar)]
    # Indentasi blok skalar (`|` / `>`) yang isinya dilewati apa adanya.
    lewati_sampai: int | None = None

    for nomor, mentah in enumerate(teks.splitlines(), start=1):
        if not mentah.strip():
            continue
        indent_mentah = len(mentah) - len(mentah.lstrip())
        if lewati_sampai is not None:
            # Isi blok skalar: bukan YAML, jangan diparse. Blok berakhir saat
            # ada baris berindentasi <= indentasi kuncinya.
            if indent_mentah > lewati_sampai:
                continue
            lewati_sampai = None
        if mentah.lstrip().startswith("#"):
            continue
        if "\t" in mentah[:indent_mentah]:
            raise YamlTidakDidukung(f"baris {nomor}: indentasi tab")
        baris = buang_komentar(mentah)
        if not baris.strip():
            continue

        indent = len(baris) - len(baris.lstrip())
        isi = baris.strip()

        if isi.startswith("- "):
            # Item list. Tidak ada yang dibaca dari list di aturan ini, jadi
            # isinya dilewati; yang penting parser tidak salah menautkan
            # kunci berikutnya ke item list.
            continue

        if ":" not in isi:
            raise YamlTidakDidukung(f"baris {nomor}: bukan mapping: {isi[:40]!r}")

        kunci, _, sisa = isi.partition(":")
        kunci = skalar(kunci)
        if not kunci:
            raise YamlTidakDidukung(f"baris {nomor}: kunci kosong")

        while tumpukan and indent <= tumpukan[-1][0]:
            tumpukan.pop()
        if not tumpukan:
            raise YamlTidakDidukung(f"baris {nomor}: indentasi tidak konsisten")

        induk = tumpukan[-1][1]

        nilai = sisa.strip()
        if nilai in ("|", ">", "|-", ">-", "|+", ">+"):
            # Blok skalar: isinya baris-baris berindentasi lebih dalam.
            # Isinya tidak relevan untuk aturan ini (yang diperiksa hanya
            # nilai Info.plist), tapi harus dilewati supaya baris di dalamnya
            # tidak dibaca sebagai kunci.
            induk[kunci] = ""
            lewati_sampai = indent
        elif nilai == "":
            anak: dict = {}
            induk[kunci] = anak
            tumpukan.append((indent, anak))
        else:
            if nilai.startswith("{") or nilai.startswith("["):
                raise YamlTidakDidukung(f"baris {nomor}: flow collection")
            induk[kunci] = skalar(nilai)

    return akar


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
    if not isinstance(settings, dict):
        return definisi
    base = settings.get("base") or {}
    if isinstance(base, dict):
        definisi.update(base.keys())
    configs = settings.get("configs") or {}
    if isinstance(configs, dict):
        for cfg in configs.values():
            if isinstance(cfg, dict):
                definisi.update(cfg.keys())
    return definisi


def main() -> int:
    if not PROYEK.exists():
        print(f"FAIL {PROYEK} tidak ada: Aturan 97 tidak mengukur apa pun.")
        return 1

    try:
        data = muat_yaml(PROYEK.read_text(encoding="utf-8"))
    except YamlTidakDidukung as e:
        print(f"FAIL project.yml memakai YAML yang tidak didukung: {e}")
        print("-> Perluas parser di Tools/check-aturan97-versi-ekstensi.py;")
        print("   jangan biarkan aturan ini hijau tanpa membaca berkasnya.")
        return 1

    targets = data.get("targets") or {}
    if not isinstance(targets, dict) or not targets:
        print("FAIL project.yml tidak punya `targets`: Aturan 97 tidak mengukur apa pun.")
        return 1

    masalah: list[str] = []
    diperiksa = 0

    for nama, target in targets.items():
        if not isinstance(target, dict):
            continue
        info = target.get("info") or {}
        if not isinstance(info, dict):
            continue
        properti = info.get("properties") or {}
        if not isinstance(properti, dict):
            continue
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
