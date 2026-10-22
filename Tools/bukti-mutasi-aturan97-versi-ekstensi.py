#!/usr/bin/env python3
"""Bukti mutasi Aturan 97: variabel Info.plist yang tidak terdefinisi.

Kenapa harness ini ada.

Gerbang yang hijau pada hari ia ditulis belum membuktikan apa pun. Yang
dibuktikan di sini: Aturan 97 benar-benar **berbunyi** saat cacat aslinya
dikembalikan, dan **diam** saat pohonnya bersih.

Cacat aslinya diukur dari log Apple Build, bukan dikarang:

    warning: The CFBundleVersion of an app extension (null) must match that
    of its containing parent app ('1').

Tiga bentuk pemutusan diuji, karena ketiganya lolos dari gerbang lain:

  1. `CURRENT_PROJECT_VERSION` dihapus dari target complication — persis
     cacat aslinya. Build tetap hijau; App Store yang menolak.
  2. Hanya `MARKETING_VERSION` yang dihapus. Ini memisahkan "satu variabel
     hilang" dari "seluruh blok settings hilang", supaya aturan tidak bisa
     lulus hanya karena menemukan salah satu dari keduanya.
  3. `$(BUILD_NUMBER)` ditambahkan ke Info.plist tanpa definisi di mana pun.
     Bentuk ini menangkap aturan yang hanya memeriksa dua nama variabel yang
     dikenal (`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`) alih-alih
     memeriksa apa pun yang benar-benar dirujuk.

Bentuk yang paling menipu — variabelnya ada di berkas tapi hanya di target
**lain** — sudah tercakup mutasi 1: `CURRENT_PROJECT_VERSION` memang
didefinisikan di target app jam dan app iPhone, jadi `grep` menemukannya dan
pembacaan sekilas terlihat benar. XcodeGen tidak mewariskan `settings` dari
app ke extension yang di-embed, dan itulah sebabnya cacat ini bertahan.

Harness menyunting berkas sungguhan lalu mengembalikannya (try/finally), dan
memeriksa bahwa pohon kembali bersih — gerbang yang meninggalkan mutasi di
disk lebih berbahaya daripada tidak ada gerbang.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

AKAR = Path(__file__).resolve().parent.parent
PROYEK = AKAR / "project.yml"
GERBANG = AKAR / "Tools" / "check-aturan97-versi-ekstensi.py"

#: Definisi versi di target complication, persis seperti di project.yml.
DEFINISI = (
    '        MARKETING_VERSION: "1.0"\n'
    '        CURRENT_PROJECT_VERSION: "1"\n'
)

#: Batas blok `settings.base` milik target complication. Ketiga target
#: (iPhone, app jam, complication) sama-sama punya `MARKETING_VERSION` dan
#: `CURRENT_PROJECT_VERSION` dengan indentasi identik, jadi mengganti
#: kemunculan pertama akan menyunting target yang salah dan harness akan
#: melaporkan "gerbang tetap hijau" padahal tidak ada yang dimutasi.
AWAL_BLOK = "PRODUCT_NAME: PointAndKnowWatchComplication"
AKHIR_BLOK = "CODE_SIGNING_ALLOWED: NO"


def sunting_blok(teks: str, ubah) -> str:
    """Terapkan `ubah` hanya pada blok settings target complication."""
    i = teks.find(AWAL_BLOK)
    if i < 0:
        return teks
    j = teks.find(AKHIR_BLOK, i)
    if j < 0:
        return teks
    j += len(AKHIR_BLOK)
    return teks[:i] + ubah(teks[i:j]) + teks[j:]


def hapus_semua(teks: str) -> str:
    return sunting_blok(teks, lambda blok: blok.replace(DEFINISI, "", 1))


def hapus_marketing(teks: str) -> str:
    return sunting_blok(
        teks,
        lambda blok: blok.replace(
            DEFINISI,
            '        CURRENT_PROJECT_VERSION: "1"\n',
            1,
        ),
    )


def tambah_build_number(teks: str) -> str:
    """Rujuk variabel baru yang tidak didefinisikan di target mana pun."""
    return teks.replace(
        "        CFBundleVersion: $(CURRENT_PROJECT_VERSION)\n",
        "        CFBundleVersion: $(CURRENT_PROJECT_VERSION)\n"
        "        CFBundleBuildNumber: $(BUILD_NUMBER)\n",
        1,
    )


#: (nama, fungsi penyunting, penanda bahwa suntingan benar-benar terjadi)
MUTASI = (
    ("CURRENT_PROJECT_VERSION dihapus dari target complication", hapus_semua,
     lambda asli, hasil: hasil.count("CURRENT_PROJECT_VERSION") < asli.count("CURRENT_PROJECT_VERSION")),
    ("MARKETING_VERSION dihapus dari target complication", hapus_marketing,
     lambda asli, hasil: hasil.count("MARKETING_VERSION") < asli.count("MARKETING_VERSION")),
    ("variabel baru dirujuk tanpa definisi", tambah_build_number,
     lambda asli, hasil: "BUILD_NUMBER" in hasil and "BUILD_NUMBER" not in asli),
)


def jalankan_gerbang() -> tuple[int, str]:
    r = subprocess.run(
        [sys.executable, str(GERBANG)],
        capture_output=True,
        text=True,
        cwd=AKAR,
    )
    return r.returncode, (r.stdout + r.stderr).strip()


def main() -> int:
    if not PROYEK.exists():
        print(f"FAIL {PROYEK} tidak ada.")
        return 1

    asli = PROYEK.read_text(encoding="utf-8")
    if DEFINISI not in asli:
        print("FAIL definisi versi di target complication tidak ditemukan;")
        print("     harness ini tidak menunjuk cacat yang dimaksud.")
        return 1

    kode, keluaran = jalankan_gerbang()
    if kode != 0:
        print("FAIL gerbang merah pada pohon bersih — tidak ada yang dibuktikan.")
        print(keluaran)
        return 1
    print("OK   pohon bersih: gerbang diam.")

    gagal = 0
    try:
        for nama, sunting, berubah in MUTASI:
            hasil = sunting(asli)
            if not berubah(asli, hasil):
                print(f"FAIL mutasi '{nama}': suntingan tidak mengubah apa pun.")
                print("     Harness yang tidak menemukan sasarannya akan hijau")
                print("     tanpa membuktikan apa pun.")
                gagal += 1
                continue
            PROYEK.write_text(hasil, encoding="utf-8")
            kode, keluaran = jalankan_gerbang()
            if kode == 0:
                print(f"FAIL mutasi '{nama}': gerbang tetap hijau.")
                gagal += 1
            elif "Aturan 97" not in keluaran and "variabel" not in keluaran:
                print(f"FAIL mutasi '{nama}': merah, tapi bukan karena Aturan 97.")
                print(keluaran)
                gagal += 1
            else:
                print(f"OK   mutasi '{nama}': gerbang berbunyi.")
            PROYEK.write_text(asli, encoding="utf-8")
    finally:
        PROYEK.write_text(asli, encoding="utf-8")

    if PROYEK.read_text(encoding="utf-8") != asli:
        print("FAIL project.yml tidak kembali ke isi aslinya.")
        return 1

    if gagal:
        print(f"FAIL {gagal} mutasi tidak terbukti.")
        return 1

    print(f"OK   {len(MUTASI)} mutasi terbukti; project.yml utuh.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
