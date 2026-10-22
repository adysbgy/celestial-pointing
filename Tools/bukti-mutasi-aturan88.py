#!/usr/bin/env python3
"""Bukti bahwa Aturan 88 benar-benar berbunyi, bukan sekadar mencetak OK.

Aturan yang tidak pernah terbukti merah adalah aturan yang tidak mengukur
apa pun. Skrip ini memutasi `LinkView.swift` dengan tiga cara yang pernah
atau bisa terjadi, menjalankan pemeriksa Aturan 88 di proses baru, dan
menuntut **merah** untuk ketiganya. Setelah itu berkasnya dipulihkan dan
pemeriksa dijalankan sekali lagi — harus hijau, supaya kegagalan karena
berkas setengah pulih tidak lolos sebagai "bukti".

Kenapa tiga mutasi ini:

1. **Berhenti memanggil** `calibrationRows`. Ini bentuk regresi yang paling
   mungkin: seseorang mengubah bagian kalibrasi dan memakai daftar kosong.
   Yang menangkapnya hanya aturan yang memeriksa panggilan, bukan isinya.

2. **Memanggil tapi membuang hasilnya** (`let _ = ...`). Ini bentuk yang
   paling menipu: `grep calibrationRows` tetap menemukannya, uji PointingKit
   tetap hijau, dan tidak satu baris pun sampai ke layar.

3. **Menulis kolomnya sendiri** lagi (`row(TextLocalization.text(.linkRow…))`).
   Ini bentuk asli cacatnya, sebelum kolom itu dipindah ke `LinkReport`.

Jalankan dari akar repo: `python3 Tools/bukti-mutasi-aturan88.py`
"""
import pathlib
import subprocess
import sys

VIEW = pathlib.Path("Apps/PointAndKnowiOS/Sources/LinkView.swift")
PERIKSA = ["python3", "Tools/check-aturan88-sambungan-laporan.py"]
TARGET = "ForEach(Array(LinkReport.calibrationRows(calibration)"

MUTASI = [
    (
        "berhenti memanggil calibrationRows",
        "ForEach(Array([LinkReport.Row]())",
        "tidak memanggil",
    ),
    (
        "memanggil tapi membuang hasilnya",
        "let _ = LinkReport.calibrationRows(calibration)\n"
        "                        ForEach(Array([LinkReport.Row]())",
        "tidak berada di dalam ForEach",
    ),
    (
        "menulis kolom laporan sendiri",
        'row(TextLocalization.text(.linkRowYawOffset), "x")\n'
        "                        ForEach(Array([LinkReport.Row]())",
        "ditulis langsung",
    ),
]


def jalankan():
    hasil = subprocess.run(PERIKSA, capture_output=True, text=True)
    return hasil.returncode, hasil.stdout + hasil.stderr


def main():
    if not VIEW.exists():
        print(f"GAGAL {VIEW} tidak ada")
        return 1

    asli = VIEW.read_text(encoding="utf-8")
    if TARGET not in asli:
        print(f"GAGAL penanda tidak ditemukan di {VIEW}: {TARGET}")
        print("      (mutasi tidak bisa diterapkan; perbarui skrip ini)")
        return 1

    gagal = []
    try:
        for nama, pengganti, harus_memuat in MUTASI:
            VIEW.write_text(asli.replace(TARGET, pengganti), encoding="utf-8")
            kode, keluaran = jalankan()
            merah = kode != 0
            menyebut = harus_memuat in keluaran
            if merah and menyebut:
                print(f"OK    {nama} — merah, dan pesannya menyebut sebabnya")
            else:
                gagal.append(nama)
                alasan = []
                if not merah:
                    alasan.append("masih HIJAU")
                if not menyebut:
                    alasan.append(f"pesan tidak menyebut '{harus_memuat}'")
                print(f"SALAH {nama} — {', '.join(alasan)}")
    finally:
        VIEW.write_text(asli, encoding="utf-8")

    kode, keluaran = jalankan()
    if kode != 0:
        print(f"GAGAL berkas tidak pulih bersih: {keluaran.strip()}")
        return 1
    print("OK    pulih — pemeriksa hijau lagi setelah semua mutasi")

    if gagal:
        print(f"\n== ATURAN 88 TIDAK TERBUKTI: {', '.join(gagal)} ==")
        return 1
    print("\n== ATURAN 88 TERBUKTI BERBUNYI ==")
    return 0


if __name__ == "__main__":
    sys.exit(main())
