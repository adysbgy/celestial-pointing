#!/usr/bin/env python3
"""Buktikan Aturan 71 berbunyi: baris yang diucapkan wajib juga digambar.

Cacat yang ditutup, **terukur** pada salinan utuh repo ini dengan Aturan 70
sudah ada (proses baru, sebelum Aturan 71): di
`Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift`, `detailRow` menggambar

    Text(title) ... Spacer ... Text(value)

lalu mengumumkannya lewat `RowSpeech.label(title:value:)`. Mengganti
`Text(value)` menjadi `Text(title)` membuat baris itu menggambar **judul dua
kali** sementara VoiceOver mengucapkan "judul, nilai". Seluruh 70 aturan UI
lulus (exit 0) atas pohon itu.

Kenapa itu bukan sekadar salah ketik: `RowSpeech.label(title:value:)` ada
supaya judul dan nilai diumumkan sebagai satu kalimat. Kesepakatannya adalah
**dua saluran membaca dua nilai yang sama**. Begitu satu saluran membaca nilai
lain, yang rusak bukan tampilannya saja — yang rusak kesepakatan itu, dan
tidak ada compiler yang melihatnya karena kedua sisi tetap bertipe `String`.
Pengguna melihat baris tanpa nilai; pembaca layar membacakan nilai yang tidak
ada di layar.

Bentuk aturan ini sengaja **sempit**, dan itu keputusan yang diukur: prototipe
pertama membandingkan nama yang diucapkan dengan seluruh badan `struct` dan
melaporkan 15 temuan pada pohon yang benar — semuanya karena nilai digambar
lewat pembantu (`spokenDegrees(row.raDeg)`), bukan `Text(...)` langsung.
Gerbang yang salah merah akan dimatikan orang, dan setelah dimatikan ia tidak
menjaga apa pun. Jadi yang diputuskan hanya pengenal sederhana terhadap
`Text(...)` di fungsi yang sama; ekspresi dilewati dan **dihitung**, supaya
hijau tidak bisa berarti "tidak ada yang diperiksa".

Tiga keadaan:

  1. pohon utuh                       -> wajib HIJAU
  2. `Text(value)` -> `Text(title)`   -> wajib MERAH, menyebut `value`
  3. aturan pra-perbaikan pada mutasi yang sama -> wajib HIJAU
     (bukti non-vakuitas: kalau aturan lama juga merah di sini, cacat ini
     sudah terjaga dan Aturan 71 tidak menambah apa pun)

Pakai:
    python3 Tools/bukti-mutasi-aturan71-baris-digambar.py   # 0 = sesuai
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")
TARGET = os.path.join("Apps", "PointAndKnowiOS", "Sources", "DiagnosticsView.swift")

#: Jangkar harus muncul tepat sekali. `Text(value)` muncul juga di `row`, jadi
#: yang dipakai adalah bentuk tiga baris yang hanya ada di `detailRow`.
ANCHOR = """            Text(value)
                .monospacedDigit()
                .foregroundStyle(SurfacePalette.active.textSecondaryColor)
        }
        .font(.footnote)"""
REPLACEMENT = ANCHOR.replace("Text(value)", "Text(title)")

RULE_MARK = "Aturan 71: baris yang DIUCAPKAN wajib juga DIGAMBAR"


def jalankan_lint(cwd, skrip="swift-ui-lint.sh"):
    proc = subprocess.run(["bash", skrip], capture_output=True, text=True,
                          cwd=cwd, env=dict(os.environ, PYTHONWARNINGS="ignore"))
    return proc.returncode, proc.stdout + proc.stderr


def salin_pohon(tujuan):
    """Salin berkas yang dibaca gerbang; `.build`/`out` dilewati."""
    for nama in ("Apps", "Packages", "Tools", ".github"):
        asal = os.path.join(ROOT, nama)
        if os.path.isdir(asal):
            shutil.copytree(asal, os.path.join(tujuan, nama),
                            ignore=shutil.ignore_patterns(".build", "out"))
    for nama in ("swift-ui-lint.sh", "README.md", "project.yml", "STATUS.md"):
        asal = os.path.join(ROOT, nama)
        if os.path.isfile(asal):
            shutil.copy2(asal, os.path.join(tujuan, nama))


def main():
    print("Aturan 71: baris yang diucapkan juga digambar\n")

    if RULE_MARK not in open(LINT, encoding="utf-8").read():
        print("GAGAL: penanda Aturan 71 tidak ada di swift-ui-lint.sh -- "
              "aturan belum diterapkan, harness ini tidak boleh hijau.")
        return 2

    isi = open(os.path.join(ROOT, TARGET), encoding="utf-8").read()
    jumlah = isi.count(ANCHOR)
    if jumlah != 1:
        print(f"GAGAL: jangkar muncul {jumlah}x di {TARGET} (harus 1). "
              "Berkasnya berubah; harness ini tidak lagi mengukur cacat yang "
              "diklaimnya.")
        return 2

    kerja = tempfile.mkdtemp(prefix="aturan71-")
    hasil = []
    try:
        salin_pohon(kerja)

        keluar, out = jalankan_lint(kerja)
        ok = keluar == 0
        print(f"{'OK  ' if ok else 'SALAH'} pohon utuh          -> "
              f"{'hijau' if ok else 'MERAH'} (harap hijau)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        sasaran = os.path.join(kerja, TARGET)
        with open(sasaran, "w", encoding="utf-8") as handle:
            handle.write(isi.replace(ANCHOR, REPLACEMENT))
        keluar, out = jalankan_lint(kerja)
        menyebut = "`value`" in out
        ok = keluar != 0 and menyebut
        print(f"{'OK  ' if ok else 'SALAH'} nilai tak digambar  -> "
              f"{'MERAH' if keluar else 'hijau'}"
              f"{', menyebut value' if menyebut else ', TIDAK menyebut value'}"
              " (harap MERAH + menyebut)")
        if not ok:
            for baris in out.strip().splitlines()[-8:]:
                print(f"       {baris}")
        hasil.append(ok)

        lama = os.path.join(kerja, "lint-lama.sh")
        proc = subprocess.run(["git", "show", "HEAD:swift-ui-lint.sh"],
                              capture_output=True, text=True, cwd=ROOT)
        if proc.returncode != 0 or not proc.stdout.strip():
            print("SALAH aturan pra-perbaikan tidak terbaca dari git -- "
                  "non-vakuitas tidak bisa dibuktikan.")
            hasil.append(False)
        else:
            with open(lama, "w", encoding="utf-8") as handle:
                handle.write(proc.stdout)
            keluar, out = jalankan_lint(kerja, "lint-lama.sh")
            ok = keluar == 0
            print(f"{'OK  ' if ok else 'SALAH'} aturan pra-perbaikan -> "
                  f"{'hijau' if ok else 'MERAH'} pada mutasi yang sama "
                  "(harap hijau = dulu buta)")
            if not ok:
                for baris in out.strip().splitlines()[-8:]:
                    print(f"       {baris}")
            hasil.append(ok)
    finally:
        shutil.rmtree(kerja, ignore_errors=True)

    print()
    if not all(hasil):
        print(f"{hasil.count(False)} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(hasil)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
