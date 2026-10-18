#!/usr/bin/env python3
"""Buktikan Aturan 59 (kartu perkenalan bisa ditutup & tidak kembali) berbunyi.

Kenapa berkas ini ada.

Perkenalan adalah satu-satunya layar yang menghalangi seluruh app. Aturan 59
menjaga tiga hal yang semuanya **terukur lolos** dari 58 aturan sebelumnya
(salinan utuh, proses baru, exit 0):

  1. `get: { !onboardingSeen }` -> `get: { true }`
     Sheet tidak pernah bisa ditutup: `set:` menulis `onboardingSeen = true`,
     tetapi `get:` tidak pernah membacanya. App jam tidak bisa dipakai.

  2. `get: { !onboardingSeen }` -> `get: { false }`
     Perkenalan tidak pernah tampil. Pengguna tidak pernah membaca bahwa app
     ini **boleh** menjawab "tidak tahu".

  3. `get: { !onboardingSeen }` -> `get: { onboardingSeen }`
     Tokennya benar, arahnya salah: kartu muncul hanya **setelah** ditutup.

Keadaan **kontrol** wajib HIJAU, dan ini bagian yang membuat harness ini
berarti: `swift-ui-lint.sh` melaporkan setiap baris `Apps/`. Kalau kontrol
tidak hijau, aturan yang menuduh semua hal akan lulus semua keadaan cacat.

Jalankan:  python3 Tools/bukti-mutasi-aturan59-kartu-perkenalan.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

WATCH = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "PointAndKnowWatchWatchApp.swift")
IOS = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                   "DiagnosticsView.swift")

GET_WATCH = "get: { !onboardingSeen }"
GET_IOS = "get: { !onboardingSeen }"

CONTROL = "kontrol: sheet lain tetap hijau"


def siapkan(tujuan):
    """Salinan utuh repo -- lint membaca Packages/, README.md, dan STATUS.md."""
    if os.path.exists(tujuan):
        shutil.rmtree(tujuan)
    os.makedirs(tujuan)
    for nama in ("Apps", "Packages", "Tools"):
        shutil.copytree(os.path.join(ROOT, nama), os.path.join(tujuan, nama),
                        ignore=shutil.ignore_patterns(".build", "__pycache__"))
    for nama in ("swift-ui-lint.sh", "project.yml", "README.md", "STATUS.md"):
        shutil.copy2(os.path.join(ROOT, nama), os.path.join(tujuan, nama))


def jalankan(kerja):
    p = subprocess.run(["bash", "swift-ui-lint.sh"], cwd=kerja,
                       capture_output=True, text=True, timeout=600)
    return p.returncode, p.stdout + p.stderr


def merah_di(keluaran, nomor):
    """Apakah aturan `nomor` yang merah -- bukan aturan lain kebetulan.

    Header aturan (`== Aturan N: ...`) membuka blok; **header apa pun**
    menutupnya, termasuk `== SEMUA GERBANG UI LULUS ==`. Tanpa itu, baseline
    yang hijau terbaca merah hanya karena baris penutupnya tidak berawalan
    "Bersih".
    """
    aktif = None
    for baris in keluaran.splitlines():
        m = re.match(r"== Aturan (\d+)", baris)
        if m:
            aktif = int(m.group(1))
            continue
        if baris.startswith("=="):
            aktif = None
            continue
        if aktif == nomor and baris.strip() and not baris.startswith("Bersih"):
            return True
    return False


def tulis(path, isi):
    with open(path, "w", encoding="utf-8") as f:
        f.write(isi)


def baca(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def ganti(path, lama, baru, semua=False):
    isi = baca(path)
    if lama not in isi:
        raise SystemExit("Jangkar tidak ditemukan di %s: %r" % (path, lama))
    if not semua and isi.count(lama) != 1:
        raise SystemExit("Jangkar muncul %d kali di %s: %r"
                         % (isi.count(lama), path, lama))
    tulis(path, isi.replace(lama, baru))


# Keadaan: (nama, fungsi mutasi pada salinan, harus_merah)
def s1(kerja):
    ganti(os.path.join(kerja, os.path.relpath(WATCH, ROOT)),
          GET_WATCH, "get: { true }")


def s2(kerja):
    ganti(os.path.join(kerja, os.path.relpath(IOS, ROOT)),
          GET_IOS, "get: { false }")


def s3(kerja):
    ganti(os.path.join(kerja, os.path.relpath(WATCH, ROOT)),
          GET_WATCH, "get: { onboardingSeen }")


def s4(kerja):
    ganti(os.path.join(kerja, os.path.relpath(IOS, ROOT)),
          "OnboardingView(onDone: { onboardingSeen = true })",
          "OnboardingView(onDone: { })")


def s5(kerja):
    # Fail-closed: sheet perkenalan diganti nama view-nya, sehingga aturan
    # berhenti mengukur satu layar pun.
    for path in (WATCH, IOS):
        ganti(os.path.join(kerja, os.path.relpath(path, ROOT)),
              "OnboardingView(onDone: { onboardingSeen = true })",
              "PerkenalanBaru(onDone: { onboardingSeen = true })")


def kontrol(kerja):
    # Sheet lain yang bukan perkenalan tidak boleh tersentuh aturan ini.
    path = os.path.join(kerja, os.path.relpath(IOS, ROOT))
    isi = baca(path)
    if ".sheet(isPresented:" in isi:
        return
    raise SystemExit("Kontrol butuh sheet perkenalan sebagai basis")


STATES = [
    ("[baseline] kode apa adanya", None, False),
    ("1. Watch: get: { true }", s1, True),
    ("2. iPhone: get: { false }", s2, True),
    ("3. Watch: arah dibalik", s3, True),
    ("4. iPhone: onDone kosong", s4, True),
    ("5. fail-closed: view diganti nama", s5, True),
]


def main():
    gagal = 0
    dasar = tempfile.mkdtemp(prefix="bukti59-")

    for i, (nama, mutasi, harus_merah) in enumerate(STATES, 1):
        kerja = os.path.join(dasar, "s%d" % i)
        siapkan(kerja)
        if mutasi is not None:
            mutasi(kerja)

        kode, keluaran = jalankan(kerja)
        merah = merah_di(keluaran, 59)

        cocok = (merah == harus_merah) and ((kode != 0) == harus_merah)
        print("%-38s exit=%-3s aturan59=%-7s %s"
              % (nama, kode, "MERAH" if merah else "hijau",
                 "OK" if cocok else "TIDAK SESUAI"))
        if not cocok:
            gagal += 1
            print(keluaran[-2000:])

    shutil.rmtree(dasar, ignore_errors=True)

    print()
    if gagal:
        print("%d keadaan tidak sesuai harapan" % gagal)
        return 1
    print("%d keadaan, 0 tidak sesuai harapan" % len(STATES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
