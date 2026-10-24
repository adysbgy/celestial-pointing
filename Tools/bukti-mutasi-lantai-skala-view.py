#!/usr/bin/env python3
"""Buktikan gerbang "lantai skala di view memakai token model" **berbunyi**.

Kenapa berkas ini ada.

Gerbang baru selalu hijau pada hari ia ditulis. Yang harus dibuktikan adalah
bahwa ia bisa merah, dan merah pada keadaan yang memang salah -- bukan sekadar
keluar != 0.

Kelas cacat yang ditutupnya, dan **diukur** sebelum gerbang ini ada.

Lantai skala `.minimumScaleFactor` ada di **dua** tempat, dan hanya satu yang
dijaga. Sisi model (`ObjectCardLayout.nameScaleFloor`) dijaga keras: ubah
0.6 -> 0.45 memerahkan lima tes di `NameOverflowTests`. Sisi view -- literal
`.minimumScaleFactor(0.6)` di `PointingView.swift` -- tidak dijaga siapa pun.
Terukur pada salinan pohon, proses baru:

    mutasi view   0.6 -> 0.45   swift-ui-lint.sh exit 0
                                  swift-typecheck.sh exit 0
                                  swift-test.sh 1101 tes, 0 gagal

Jadi hari itu lantai kartu jam bisa jadi 0.45 dan seluruh gerbang tetap hijau,
sementara model yang memutuskan kapan kartu menyusun ulang tetap berhitung
dengan 0.6. Kedua paruh satu perhitungan berbeda pendapat tentang nama yang
sama, tanpa satu pun gerbang yang tahu.

**Kenapa keadaan di bawah kini bermutasi dari token, bukan dari 0.6.** Lubang
itu sudah ditutup di sumbernya: setiap situs `Apps/` kini memanggil
`ObjectCardLayout.nameScaleFloor`. Yang diuji di sini karena itu bukan lagi
"apakah angka literal tertangkap" -- itu sudah diuji `NameOverflowTests`
(`testEveryMinimumScaleFactorSiteNamesTheModelToken`) -- melainkan bahwa
perjanjian itu **tetap berbunyi** setelah perbaikannya masuk: lantai yang
kembali ditulis sebagai angka, lantai yang jadi 1.0, lantai baris meta yang
menyimpang dari nama di atasnya, dan lantai complication yang menyimpang dari
kartu jam.

Yang membuatnya layak gerbang tersendiri: Aturan 76 **memeriksa lantai itu
berulang kali** dan tetap diam. Ia menuntut kebijakan luapan *ada* di setiap
nama katalog -- dan `.minimumScaleFactor(0.45)` memenuhinya. Aturan yang
membaca tepat baris yang salah, lalu melaporkan "Bersih", lebih berbahaya
daripada aturan yang tidak ada: ia terlihat seperti penjaga.

Kenapa arah kedua diuji. Kalau lint sudah merah atas mutasi yang sama, keadaan
1-4 tidak membuktikan adanya lubang -- mereka hanya membuktikan lint bisa
merah. Karena itu keadaan terakhir menjalankan lint dengan **blok Aturan 76
dicabut** dan menuntutnya hijau atas mutasi yang sama, persis pola
`bukti-mutasi-aturan67-bawaan-preferensi.py`.

Yang TIDAK diklaim. Gerbangnya membaca teks, jadi ia mengukur perjanjian
**antar-teks**, bukan piksel di perangkat. Yang bisa diklaim: kedua sisi satu
perhitungan tidak bisa lagi berubah sendiri-sendiri tanpa ada yang berbunyi.

Pakai:
    python3 Tools/bukti-mutasi-lantai-skala-view.py     # 0 = sesuai harapan
"""
from __future__ import annotations

import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

VIEW = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                    "PointingView.swift")
WIDGET = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Complications",
                      "ComplicationWidget.swift")

#: Alat yang dipakai memerahkan: `swift-test.sh` menjalankan uji PointingKit di
#: Docker Swift 6.0. Yang lain (`swift-ui-lint.sh`, `swift-typecheck.sh`) juga
#: dijalankan, karena justru itu yang terukur **diam** atas mutasi ini.
TESTS = "swift-test.sh"
LINT = "swift-ui-lint.sh"
TYPECHECK = "swift-typecheck.sh"

#: Token yang harus dipakai setiap situs view.
TOKEN = "ObjectCardLayout.nameScaleFloor"

#: Pesan yang menandakan gerbang berbunyi karena **sebab yang benar**: ia
#: melihat lantai sebagai angka, bukan token. Bukan sekadar exit != 0.
MARK = "lantai skala ditulis sebagai angka di view"

#: Situs yang dimutasi. Dipilih supaya ketiga permukaan tercakup: kartu jam,
#: baris meta di kartu yang sama, dan complication (target lain, berkas lain).
#: Setiap jangkar wajib unik di berkasnya -- diperiksa di bawah, bukan
#: diandaikan, karena jangkar yang cocok dua tempat membuat mutasi menulis ke
#: situs yang tidak dimaksud dan keadaan "harus merah" hijau karena sebab yang
#: salah.
STATES = [
    # 1. Lantai kartu jam jadi angka: kebijakannya masih ada (Aturan 76
    #    tetap "Bersih"), tetapi yang menentukan penyusutan bukan lagi
    #    angka yang sama dengan model.
    ("1 kartu jam: lantai token -> angka 0.45",
     [(VIEW, "                .minimumScaleFactor(ObjectCardLayout.nameScaleFloor)",
       "                .minimumScaleFactor(0.45)", 1)]),
    # 2. Lantai kartu jam menjadi 1.0: huruf tak pernah menyusut, jadi
    #    `.lineLimit` yang memotong -- dan pemotongannya terjadi pada
    #    ukuran yang model tidak perhitungkan.
    ("2 kartu jam: lantai token -> 1.0 (huruf tak pernah menyusut)",
     [(VIEW, "                .minimumScaleFactor(ObjectCardLayout.nameScaleFloor)",
       "                .minimumScaleFactor(1.0)", 1)]),
    # 3. Baris meta di kartu jam memakai lantai yang berbeda dari nama di
    #    atasnya: satu kartu, dua angka, keduanya "kebijakan luapan".
    ("3 baris meta kartu jam: lantai berbeda dari nama",
     [(VIEW, "                    .minimumScaleFactor(ObjectCardLayout.nameScaleFloor)",
       "                    .minimumScaleFactor(0.45)", 1)]),
    # 4. Complication -- berkas lain, permukaan lain, nama yang sama.
    ("4 complication: lantai token -> angka 0.45",
     [(WIDGET, "                    .minimumScaleFactor(ObjectCardLayout.nameScaleFloor)",
       "                    .minimumScaleFactor(0.45)", 1)]),
]

#: Keadaan yang HARUS hijau. Tanpa ini, harness hanya membuktikan ia bisa
#: merah -- termasuk merah pada kode yang benar.
HIJAU = [
    ("kontrol: pohon apa adanya", None),
    ("kontrol: pemanggilan token di berkas lain",
     [(VIEW, "                .font(.title3.bold())",
       "                .font(.title3.bold()) // token " + TOKEN, 1)]),
]

_originals = {}


def restore(*_):
    for path, content in _originals.items():
        mutasi_sumber.restore_verified(path, content)


def jalankan(perintah: list[str], timeout: int = 2400):
    """Jalankan satu perintah; kembalikan (exit, gabungan keluaran)."""
    try:
        proc = subprocess.run(perintah, cwd=ROOT, capture_output=True,
                              text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None, "TIMEOUT setelah %d detik" % timeout
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def uji_berbunyi(label: str, mutations) -> bool:
    """Terapkan mutasi, jalankan tes, pulihkan. True = berbunyi karena benar."""
    for path, content in _originals.items():
        mutasi_sumber.write_source(path, content)
    if mutations:
        for target, old, new, jumlah in mutations:
            base = _originals[target]
            content = base.replace(old, new, jumlah)
            if content == base:
                print("SALAH %-46s JANGKAR TIDAK DITEMUKAN: %r"
                      % (label, old[:60]))
                return False
            mutasi_sumber.write_source(target, content)

    code, out = jalankan(["bash", os.path.join(ROOT, TESTS)])
    if code is None:
        print("SALAH %-46s %s" % (label, out))
        return False
    if code == 0:
        print("SALAH %-46s HIJAU -- gerbang tidak melihat mutasi ini" % label)
        return False
    if MARK not in out:
        print("SALAH %-46s merah karena sebab lain, bukan lantai skala" % label)
        print("       " + out.strip().splitlines()[0][:300])
        return False
    # Pulihkan segera: keadaan berikutnya wajib membaca berkas yang benar.
    for path, content in _originals.items():
        mutasi_sumber.write_source(path, content)
    print("OK   %-46s MERAH (%s)" % (label, MARK[:28] + "…"))
    return True


def uji_hijau(label: str, mutations) -> bool:
    """Mutasi yang sah -- gerbang tidak boleh menuduhnya."""
    for path, content in _originals.items():
        mutasi_sumber.write_source(path, content)
    if mutations:
        for target, old, new, jumlah in mutations:
            base = _originals[target]
            content = base.replace(old, new, jumlah)
            if content == base:
                print("SALAH %-46s JANGKAR TIDAK DITEMUKAN: %r"
                      % (label, old[:60]))
                return False
            mutasi_sumber.write_source(target, content)

    code, out = jalankan(["bash", os.path.join(ROOT, TESTS)])
    for path, content in _originals.items():
        mutasi_sumber.write_source(path, content)
    if code is None:
        print("SALAH %-46s %s" % (label, out))
        return False
    ok = code == 0
    print("%s %-46s %s" % ("OK   " if ok else "SALAH", label,
                           "hijau" if ok else "MERAH"))
    if not ok:
        print("       " + out.strip().splitlines()[0][:300])
    return ok


def arah_kedua() -> bool:
    """Lint **tanpa** Aturan 76 wajib HIJAU atas mutasi yang sama.

    Kenapa dicabut dari berkas di disk, bukan `git show HEAD^:`: satu commit
    sudah lepas, `HEAD^` tetap memuat Aturan 76, jadi arah keduanya jadi
    tautologi -- merah pada pohon yang benar, dan keadaan 1-3 tidak lagi
    membuktikan lubang apa pun.
    """
    text = open(LINT, encoding="utf-8").read()
    header = "# \u2500\u2500 Aturan 76:"
    start = text.find(header)
    if start < 0:
        print("SALAH arah kedua: blok Aturan 76 tidak ditemukan di lint")
        return False
    end = text.find("\nPY\n)", start)
    if end < 0:
        print("SALAH arah kedua: akhir blok Aturan 76 tidak ditemukan")
        return False
    end += len("\nPY\n)")
    stripped = text[:start] + text[end:]

    sandbox = tempfile.mkdtemp(prefix="lantai-arah2-")
    try:
        for name in ("Apps", "Packages"):
            shutil.copytree(os.path.join(ROOT, name),
                            os.path.join(sandbox, name),
                            ignore=shutil.ignore_patterns("*.xcodeproj",
                                                          "*.xcworkspace"))
        target = os.path.join(sandbox, "Apps", "PointAndKnowWatch", "Sources",
                              "PointingView.swift")
        base = open(target, encoding="utf-8").read()
        mutasi = base.replace("                .minimumScaleFactor(ObjectCardLayout.nameScaleFloor)",
                              "                .minimumScaleFactor(0.45)", 1)
        if mutasi == base:
            print("SALAH arah kedua: jangkar mutasi tidak ada di salinan")
            return False
        open(target, "w", encoding="utf-8").write(mutasi)
        open(os.path.join(sandbox, "swift-ui-lint.sh"), "w",
             encoding="utf-8").write(stripped)

        code, out = jalankan(["bash", os.path.join(sandbox, "swift-ui-lint.sh")],
                             timeout=1800)
        if code is None:
            print("SALAH arah kedua: %s" % out)
            return False
        # Lint tanpa Aturan 76: mutasi token -> 0.45 harus LOLOS. Kalau ia tetap
        # merah, keadaan 1 tidak membuktikan bahwa Aturan 76-lah yang menangkap
        # mutasi ini -- aturan lain yang sudah menahannya, dan lubang yang
        # diukur tidak pernah ada.
        ok = code == 0
        print("%s %-46s %s" % ("OK   " if ok else "SALAH",
                               "arah kedua: lint tanpa Aturan 76",
                               "hijau atas mutasi 0.45" if ok else "MASIH MERAH"))
        if not ok:
            print("       " + out.strip().splitlines()[0][:300])
        return ok
    finally:
        shutil.rmtree(sandbox)


def main() -> int:
    targets = [VIEW, WIDGET]
    mutasi_sumber.require_clean_sources(targets)

    for path in targets:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    # Jangkar wajib unik. Diperiksa, bukan diandaikan.
    for label, mutations in STATES + HIJAU:
        if not mutations:
            continue
        for target, old, _, _ in mutations:
            if target not in _originals:
                print("GERBANG: %s memutasi berkas di luar daftar target"
                      % label, file=sys.stderr)
                return 2
            if _originals[target].count(old) != 1:
                print("GERBANG: jangkar %r muncul %dx di %s -- harness tidak "
                      "boleh jalan." % (old[:50],
                                        _originals[target].count(old),
                                        os.path.basename(target)),
                      file=sys.stderr)
                return 2

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    gagal = 0
    try:
        for label, mutations in STATES:
            if not uji_berbunyi(label, mutations):
                gagal += 1
        for label, mutations in HIJAU:
            if not uji_hijau(label, mutations):
                gagal += 1
        if not arah_kedua():
            gagal += 1
    finally:
        restore()

    total = len(STATES) + len(HIJAU) + 1
    print("\n%d keadaan, %d tidak sesuai harapan" % (total, gagal))
    return 1 if gagal else 0


if __name__ == "__main__":
    sys.exit(main())
