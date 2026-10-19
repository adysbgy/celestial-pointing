#!/usr/bin/env python3
"""Buktikan gerbang jangkar menolak sasaran mutasi yang bukan sumber perangkat lunak.

Aturan 69 menutup celah yang **terukur**, bukan diklaim.

Gerbang jangkar (`Tools/check-jangkar-harness.py`) menjaga mutasi tertinggal:
suatu harness memutasi berkas dengan pasangan (jangkar, pengganti), dan bila
jangkarnya sudah hilang sementara penggantinya ada di pohon, itu mutasi bocor
yang ikut ter-commit -- kelas cacat yang dua kali menjatuhkan `main`.

Yang belum pernah ditanya gerbang itu: **berkas apa yang dimutasi**. Terukur,
sebuah harness uji coba dengan pasangan

    (README.md,        "68 aturan")
    (swift-ui-lint.sh, "Aturan 68:")

diterima sebagai dua jangkar yang sah. Gerbang melaporkan "+2 jangkar, 0
kebocoran, exit 0" atas mutasi yang tidak menyentuh satu baris kode pun --
yang diubah adalah prosa laporan dan naskah gerbangnya sendiri. Harness yang
"menjaga kode" karena mengedit dokumen lolos tanpa menjaga apa pun.

Apa yang tidak dilakukan pemeriksaan ini: ia tidak memutuskan `.md` atau `.sh`
**selalu** salah. `swift-ui-lint.sh` memang dimutasi sebagian besar harness
repo ini, dan mutasinya bermakna -- ia membuktikan aturan UI-nya berbunyi.
Yang diminta adalah berkas sasaran eksplisit ber-ekstensi **sumber**
(`.swift`, `.py`, `.plist`, `.xcstrings`, `.entitlements`, `.json`, `.yml`,
`.yaml`, `.strings`); berkas luar daftar itu dilaporkan sebagai penyimpangan,
bukan dilewatkan diam-diam.

Dua keadaan diuji:

  1. harness uji dengan sasaran `.md` dan `.txt` -> gerbang wajib MERAH.
  2. kontrol negatif: harness uji dengan sasaran `.swift` -> gerbang wajib
     HIJAU. Tanpa keadaan ini pemeriksaan bisa merah karena alasan lain
     (mis. membenci setiap berkas baru), dan merah atas apa pun membuktikan
     nol tentang sasaran.

Berkas uji coba ditulis ke `Tools/` karena gerbang memindai direktori itu,
lalu dihapus di `finally` bersama pemulihan apa pun yang terjamah.

Pakai:
    python3 Tools/bukti-mutasi-aturan69-sasaran-sumber.py   # 0 = sesuai
"""
from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "Tools")
GATE = os.path.join(TOOLS, "check-jangkar-harness.py")

#: Unit yang diuji di gerbang: penanda fungsi penentu ekstensi sumber.
RULE_MARK = "def _ekstensi_sumber"
#: Nama konstanta yang menahan daftar ekstensi itu.
EXTENSION_CONST = "_EXT_SUMBER"

PREFIX = "bukti-mutasi-zz-probe-aturan69"
README = os.path.join(ROOT, "README.md")
CATATAN = os.path.join(ROOT, "CATATAN-UJI-69.txt")
SWIFT = os.path.join(ROOT, "Apps", "Shared", "OnboardingView.swift")

_written = []


def jalankan_gerbang():
    proc = subprocess.run([sys.executable, GATE], capture_output=True,
                          text=True, cwd=ROOT,
                          env=dict(os.environ, PYTHONWARNINGS="ignore"))
    return proc.returncode, proc.stdout + proc.stderr


def tulis(path, isi):
    _written.append(path)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(isi)


def bersihkan():
    for path in _written:
        if os.path.exists(path):
            os.remove(path)
    _written.clear()


def probe_sasaran(mutations, nama):
    """Tulis harness uji coba; kembalikan (keluar, keluaran) gerbang.

    Bentuk `STATES` yang dipakai: `(label, [(jalur, jangkar, pengganti), …])`.
    Bentuk empat-elemen `(label, jalur, jangkar, pengganti)` **tidak terbaca**
    oleh gerbang (terukur: `_collect_edits` mengembalikan daftar kosong),
    sehingga probe berbentuk itu akan "lulus" karena tidak diperiksa sama
    sekali -- hijau tanpa makna. Probe yang tidak bisa merah bukan bukti.
    """
    baris = ["STATES = [", f"    ('uji {nama}', ["]
    for target, anchor, replacement in mutations:
        baris.append(f"        ({target!r}, {anchor!r}, {replacement!r}),")
    baris.append("    ]),")
    baris.append("]")
    path = os.path.join(TOOLS, f"{PREFIX}-{nama}.py")
    tulis(path, "\n".join(baris) + "\n")
    try:
        return jalankan_gerbang()
    finally:
        # Dibuang sebelum keadaan berikutnya diukur: probe keadaan 1 tetap
        # terbaca sebagai jangkar non-sumber pada pemeriksaan keadaan 2, dan
        # kontrol negatif lalu merah karena sisa keadaan sebelumnya --
        # bukan karena apa pun tentang sasaran `.swift`.
        if os.path.exists(path):
            os.remove(path)


def main():
    print("Aturan 69: gerbang jangkar menolak sasaran non-sumber\n")

    teks = open(GATE, encoding="utf-8").read()
    if RULE_MARK not in teks or EXTENSION_CONST not in teks:
        print(f"GAGAL: '{RULE_MARK}'/'{EXTENSION_CONST}' tidak ada di "
              f"{os.path.basename(GATE)} -- aturan belum diterapkan, "
              "harness ini tidak boleh melaporkan hijau.")
        return 2

    tulis(CATATAN, "baris isi uji\n")
    hasil = []

    try:
        # 1. Sasaran dokumen -> wajib MERAH.
        keluar, out = probe_sasaran(
            [(README, "68 aturan", "999 aturan"),
             (CATATAN, "baris", "baris-x")],
            "nonsumber")
        merah = "GAGAL" in out
        ok = keluar != 0 and merah
        print(f"{'OK  ' if ok else 'SALAH'} "
              f"sasaran .md/.txt  -> gerbang {'MERAH' if keluar else 'hijau'}")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        # 2. Kontrol negatif: sasaran sumber -> wajib HIJAU.
        keluar, out = probe_sasaran(
            [(SWIFT, "import", "import")],
            "sumber")
        ok = keluar == 0 and "OK:" in out
        print(f"{'OK  ' if ok else 'SALAH'} "
              f"sasaran .swift     -> gerbang {'hijau' if keluar == 0 else 'MERAH'}")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)
    finally:
        bersihkan()

    print()
    if not all(hasil):
        print(f"{hasil.count(False)} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(hasil)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
