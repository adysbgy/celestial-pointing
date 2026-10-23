#!/usr/bin/env python3
"""Buktikan gerbang **kutipan yang terbelah melewati baris** berbunyi.

Kenapa harness ini ada.

`check_citations_are_not_split_across_lines` lahir dari merah CI yang nyata:
`CelestialVisual.swift:2822` memecah nama uji di dalam backtick melewati batas
baris, dan `check_cited_test_names_exist` membacanya sebagai
`testSunCoronaOpacityReadsAsLightWithout`. Merahnya benar — tetapi **kebetulan
benar**. Gerbang itu berbunyi karena potongan pertama kebetulan bukan nama uji
yang sah. Kalau potongan pertamanya kebetulan **adalah** nama uji yang sah,
gerbang yang sama akan hijau sementara rujukannya tetap menunjuk nama yang
salah.

### Keadaan 4 dan 5 adalah inti berkas ini

Keadaan 4 dan 5 **tidak** memakai nama karangan. Keduanya memakai dua nama uji
yang benar-benar ada di pohon ini, yang satu adalah awalan yang lain:

    testPermissivePolicyRejectsNothing
    testPermissivePolicyRejectsNothingForEveryKind

Kutipan yang dipotong di tengahnya membaca `testPermissivePolicyRejectsNothing`
— nama yang **terdefinisi** — jadi `check_cited_test_names_exist` hijau. Itu
dibuktikan di sini, bukan diklaim: keadaan 4 menuntut gerbang **lama** hijau
dan gerbang **baru** merah pada mutasi yang sama. Kalau kelak gerbang lama
kebetulan ikut merah (mis. karena nama itu dihapus dari suite), keadaan 4
gagal dan pesannya menyuruh memperbarui pasangan namanya — bukan dilonggarkan.

### Keadaan

    [baseline]                                    hijau
    1. kutipan terbelah memotong nama uji nyata   MERAH   (baru) / hijau (lama)
    2. kutipan terbelah memotong nama gerbang     MERAH
    3. kutipan terbelah memotong jalur berkas     MERAH
    4. potongan pertama = nama uji NYATA          MERAH   (baru) / hijau (lama)
    5. prosa dibungkus (`Apple` + `Build`)        HIJAU   (kontrol negatif)
    6. fail-closed: nol backtick terbaca          MERAH

Keadaan 5 adalah kontrol negatif yang wajib: versi pertama aturan ini
melaporkan **62** temuan di pohon ini, hampir semuanya prosa yang wajar
dibungkus. Aturan yang menuduh kalimat biasa akan dimatikan orang, dan itu
lebih buruk daripada tidak ada aturan. Keadaan 5 mengunci sifat itu.

### Yang TIDAK diklaim

- Yang dijaga adalah **bentuk kutipan**, bukan kebenaran isinya. Kutipan yang
  terbelah pada nama yang **tidak** ada di pohon tidak ditangkap di sini —
  itu wilayah `check_cited_test_names_exist` (untuk nama uji) dan tidak ada
  gerbang untuk nama lain.
- Gerbangnya membaca keberadaan nama di **pohon ini**, jadi ia tidak bisa
  membedakan "prosa yang kebetulan menyambung menjadi nama nyata" dari
  "kutipan yang benar-benar dipotong". Diukur: nol kasus seperti itu di pohon
  ini, dan kalau muncul ia akan berbunyi sebagai temuan palsu — arah
  kelalaian yang dipilih, karena temuan palsu terlihat dan bisa diperbaiki,
  sedangkan kutipan terbelah yang lolos tidak terlihat.

Pakai:
    python3 Tools/bukti-mutasi-kutipan-terbelah.py    # 0 = sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import re
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

CHECKS = os.path.join(ROOT, "Tools", "check-visuals.py")
#: Berkas yang dimutasi untuk keadaan 1–4. Sumber produksi, tempat cacat
#: aslinya terjadi.
TARGET = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit",
                              "CelestialVisual.swift")

HIJAU = "hijau"
MERAH = "merah"

BARU = "kutipan tidak terbelah melewati baris"
LAMA = "uji yang dikutip produksi ada"

# ── Jangkar ──────────────────────────────────────────────────────────────
# Semuanya unik di berkasnya (diperiksa sebelum memutasi).

#: Nama uji nyata yang **satu adalah awalan yang lain**. Dipakai keadaan 4.
AWALAN = "testPermissivePolicyRejectsNothing"
PANJANG = "testPermissivePolicyRejectsNothingForEveryKind"

#: Jangkar komentar di `CelestialVisual.swift`, di dalam docstring
#: `sunCoronaOpacity` — tempat cacat aslinya. Satu baris utuh yang tidak
#: memuat backtick, jadi penggantinya bisa menambahkan kutipan tanpa
#: menggeser backtick lain.
JANGKAR = ("    /// **Yang TIDAK diklaim.** Ini bukan nilai astronomi; "
           "corona nyata tidak\n")

#: Nama gerbang nyata di `Tools/check-visuals.py`, dipotong dua.
GERBANG_NAMA = "check_modeled_port_constants_match_the_model"

PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "cv_probe", os.path.join(sys.argv[1], "Tools", "check-visuals.py"))
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)

results = []
for fn in ("check_citations_are_not_split_across_lines",
           "check_cited_test_names_exist"):
    try:
        getattr(C, fn)(results)
    except Exception as exc:
        print("ERR " + fn + " " + type(exc).__name__ + ": " + str(exc)[:200])
        continue

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""


def _split(name):
    """Potong `name` di tengah, hasilkan teks dua baris yang menyambung lagi.

    Bentuknya **dua** backtick: satu membuka di akhir baris pertama, satu
    menutup di baris kedua. Versi pertama fungsi ini menaruh backtick
    penutup juga di baris pertama, sehingga baris itu berisi dua backtick —
    jumlahnya genap, dan gerbangnya melewatinya. Harness lalu melaporkan
    keadaan 2–4 hijau dan menyalahkan gerbang, padahal yang cacat adalah
    teks mutasinya.
    """
    half = len(name) // 2
    return "`" + name[:half] + "\n    /// " + name[half:] + "`"


#: Jangkar di berkas ini **dirakit saat jalan**: nama uji, nama gerbang, dan
#: jalur berkas dipotong oleh `_split` di tengahnya, jadi pasangan
#: (jangkar, pengganti) tidak pernah ada sebagai teks tetap yang bisa dibaca
#: statis. Potongannya sendiri yang menjadi subjek uji, jadi menuliskannya
#: sebagai literal akan menghapus hal yang sedang dibuktikan.
JANGKAR_KECUALI = (
    "jangkar dirakit saat jalan oleh _split: nama utuh dipotong di tengahnya "
    "supaya keadaan uji benar-benar membentuk kutipan terbelah, jadi pasangan "
    "(jangkar, pengganti) tidak ada sebagai teks tetap di berkas ini")

#: Teks potongan dibangun oleh `_split`, supaya nama aslinya tetap utuh di
#: satu tempat dan tidak ada salinan yang bisa menyimpang.
GERBANG_POTONG = _split(GERBANG_NAMA)

#: Jalur berkas nyata, dipotong dua.
JALUR_NAMA = "Apps/Shared/CelestialVisualView.swift"
JALUR_POTONG = _split(JALUR_NAMA)


def _states():
    """Bangun daftar keadaan; `_split` dipakai supaya nama asli utuh."""
    return [
        ("[baseline] berkas bersih", None,
         {BARU: HIJAU}),

        # 1. Cacat aslinya: nama uji nyata, dipotong. Gerbang baru merah.
        ("1. kutipan terbelah memotong nama uji nyata",
         [(TARGET, JANGKAR,
           JANGKAR + "    /// Lihat `testSunCoronaOpacityReadsAsLightWithout\n"
                     "    /// CoveringTheDisk`.\n")],
         {BARU: MERAH}),

        # 2. Nama gerbang nyata, dipotong. Cakupan gerbang baru lebih luas
        #    dari sekadar nama uji — ini yang membuktikannya.
        ("2. kutipan terbelah memotong nama gerbang",
         [(TARGET, JANGKAR, JANGKAR + "    /// " + GERBANG_POTONG + ".\n")],
         {BARU: MERAH}),

        # 3. Jalur berkas nyata, dipotong.
        ("3. kutipan terbelah memotong jalur berkas",
         [(TARGET, JANGKAR, JANGKAR + "    /// " + JALUR_POTONG + ".\n")],
         {BARU: MERAH}),

        # 4. **Keadaan yang membuktikan gerbang lama buta.** Potongan
        #    pertamanya adalah nama uji yang benar-benar terdefinisi, jadi
        #    `check_cited_test_names_exist` hijau — sementara rujukannya
        #    menunjuk nama yang salah. Dua harapan sekaligus, dan keduanya
        #    harus dipenuhi.
        ("4. potongan pertama adalah nama uji NYATA (gerbang lama buta)",
         [(TARGET, JANGKAR,
           JANGKAR + "    /// Lihat `" + AWALAN + "\n"
                     "    /// ForEveryKind`.\n")],
         {BARU: MERAH, LAMA: HIJAU}),

        # 5. Kontrol negatif: prosa yang wajar dibungkus. Harus hijau di
        #    gerbang baru, kalau tidak aturannya menuduh kalimat biasa.
        ("5. prosa dibungkus (kontrol negatif)",
         [(TARGET, JANGKAR,
           JANGKAR + "    /// Dijalankan di `Apple\n"
                     "    /// Build` setiap push.\n")],
         {BARU: HIJAU}),

        # 6. Fail-closed: pola pembaca backtick dibuat tidak cocok sama
        #    sekali. Nol bacaan harus **merah**, bukan hijau karena tidak ada
        #    yang diperiksa.
        ("6. fail-closed: nol backtick terbaca",
         [(CHECKS, "        total_ticks += source.count(\"`\")",
           "        total_ticks += 0 * source.count(\"`\")")],
         {BARU: MERAH}),
    ]


def run_probe():
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    return out.stdout, None


def classify(stdout):
    verdicts = {}
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        state, _, name = stripped.partition(" ")
        name = name.strip()
        if state in ("OK", "GAGAL"):
            verdict = "hijau" if state == "OK" else "merah"
            verdicts[name] = verdict
            verdicts.setdefault(name.split(":")[0].strip(), verdict)
    return verdicts


def main():
    files = [CHECKS, TARGET]
    mutasi_sumber.require_clean_sources(files)
    originals = {path: open(path, "rb").read() for path in files}
    baseline_md5 = {path: hashlib.md5(data).hexdigest()
                    for path, data in originals.items()}
    failures = []

    def restore():
        for path, data in originals.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected in _states():
            restore()
            if edits is not None:
                pending = {}
                for path, find, replace in edits:
                    content = pending.get(path, originals[path].decode())
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}× di "
                            f"{os.path.relpath(path, ROOT)}, harus 1")
                        break
                    pending[path] = content.replace(find, replace, 1)
                else:
                    for path, content in pending.items():
                        mutasi_sumber.write_source(path, content)

            stdout, error = run_probe()
            if stdout is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"GAGAL {name} — probe gagal")
                continue

            verdicts = classify(stdout)
            wrong = []
            for check_name, want in expected.items():
                got = verdicts.get(check_name)
                if got is None:
                    wrong.append(f"{check_name}: tidak muncul di keluaran")
                elif got != want:
                    wrong.append(f"{check_name}: harap {want}, dapat {got}")
            if wrong:
                failures.append(f"{name}: " + "; ".join(wrong))
                print(f"GAGAL {name}")
                for item in wrong:
                    print(f"        {item}")
            else:
                detail = ", ".join(f"{k.split(':')[0]}={v}"
                                   for k, v in sorted(expected.items()))
                print(f"OK    {name}  ({detail})")
    finally:
        restore()

    for path, digest in baseline_md5.items():
        now = hashlib.md5(open(path, "rb").read()).hexdigest()
        if now != digest:
            failures.append(
                f"{os.path.relpath(path, ROOT)} tidak pulih byte-per-byte")

    if failures:
        print(f"\n{len(failures)} keadaan tidak sesuai harapan:")
        for item in failures:
            print(f"  - {item}")
        return 1

    print(f"\n{len(_states())} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
