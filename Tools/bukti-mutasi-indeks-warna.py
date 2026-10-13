#!/usr/bin/env python3
"""Buktikan gerbang **indeks warna bintang** berbunyi — 25 entri B−V yang
hidup di dua bahasa, dan **tanda**-nya yang jadi identitas.

Kenapa harness ini ada.

`check_star_colour_index_matches_the_model` menjaga 25 indeks warna yang
ditulis dua kali: `CelestialVisual.starColorIndex` di Swift dan
`STAR_COLOR_INDEX` di port Python. Tidak ada pemeriksaan lain yang
membandingkan keduanya — setiap pemeriksaan warna bintang yang ada mengukur
**gambar port**, jadi mengubah satu nilai di Swift membiarkan semuanya hijau
sambil mengukur warna yang tidak pernah ada.

Gerbangnya hijau pada hari ditulis, dan itu bukan bukti apa pun: kedua tabel
memang identik hari ini. Yang membedakan gerbang yang menjaga dari gerbang
yang hanya *terlihat* menjaga adalah apakah ia bisa dibuat merah, dan merah
pada keadaan yang memang salah.

### Yang paling penting diukur harness ini: dua arah yang **tidak** simetris

Keadaan 5 dan 6 adalah cermin satu sama lain — bintang yang sama (`rigel`)
hilang, sekali dari model dan sekali dari port — dan keduanya memerahkan
pemeriksaan yang **berbeda**:

    model kehilangan rigel  →  "tidak ada bintang sisa di port"   (port berlebih)
    port kehilangan rigel   →  "setiap bintang model ada di port" (model tidak terjangkau)

Itu bukan kerapian. Kalau salah satu arah tidak diperiksa, bintang yang
hilang dari sisi itu lewat tanpa suara: sisi yang tersisa masih memuat nama
yang sama, jadi pemeriksaan "per bintang" tidak punya apa pun untuk
dibandingkan dan hanya jumlahnya yang berubah. Harness ini menuntut **nama**
pemeriksaan yang merah, bukan sekadar "ada yang merah", supaya kedua arah itu
tidak bisa saling menggantikan.

### Tanda adalah identitas

Keadaan 3 dan 4 mengubah bintang yang sama sebanyak satu angka:

    4. model betelgeuse  1.85 → -1.85   MERAH 2 (nilai + tanda)
    3. model betelgeuse  1.85 →  1.90   MERAH 1 (nilai saja)

Yang membedakan keduanya hanya tanda, dan itulah intinya: Betelgeuse +1.85
harus merah, Rigel −0.03 biru. Tanda yang terbalik tidak akan pernah
dilaporkan pengguna — bintang tetap tampak sebagai titik bercahaya — jadi
kalau pemeriksaan tanda tidak ada, warna yang salah itu bertahan. Keadaan 4
membuktikan pemeriksaan itu berbunyi; keadaan 3 membuktikan ia **tidak**
berbunyi pada perubahan yang bukan soal tanda, sehingga keduanya tidak
saling menggantikan.

### Keadaan

  keadaan                                          harapan
  [baseline]                                       hijau 28/28
  1. port: betelgeuse 1.85 → -1.85 (tanda)         MERAH 2
  2. port: betelgeuse 1.85 → 1.90 (nilai)          MERAH 1
  3. model: betelgeuse 1.85 → 1.90                 MERAH 1
  4. model: betelgeuse 1.85 → -1.85                MERAH 2
  5. model kehilangan rigel                        MERAH 1 (arah "sisa")
  6. port kehilangan rigel                         MERAH 1 (arah "tidak terjangkau")
  7. **keduanya diubah bersama, nilai sama**       **hijau 28/28**
  8. jangkar tabel model dirapikan                 MERAH 1, gerbang **berhenti
                                                   lebih awal**

Keadaan 7 adalah yang paling mudah hilang dari sebuah harness, dan ia yang
menjaga gerbangnya tetap jujur: mengubah **kedua** sisi menjadi nilai yang
sama **bukan cacat** — model dan port masih sepakat, dan itu satu-satunya
keadaan yang sah untuk menyunting angka B−V. Harness yang merah di sana akan
mengajarkan bahwa gerbangnya menolak pekerjaan yang benar, dan gerbang yang
dilonggarkan untuk itu berhenti menjaga apa pun.

Keadaan 8 mengukur jalur gagal-bersih: jangkar tabelnya hilang, dan
gerbangnya melaporkan **satu** hasil merah yang menyebut jangkarnya, bukan
traceback. Himpunan hasilnya dituntut persis supaya "berhenti lebih awal"
terlihat sebagai berhenti lebih awal.

### Yang TIDAK diklaim

- Yang diukur **teks**, bukan piksel app Apple. Yang dibuktikan: ketujuh
  kawat gerbang ini merah pada keadaan yang memang salah, hijau pada
  penyuntingan yang sah, dan merah dengan pesan bersih saat modelnya
  dirapikan.
- Harness ini **tidak** membuktikan bahwa 25 angka B−V itu benar secara
  astronomi. Yang dijaga gerbangnya adalah kesepakatan dua bahasa dan tanda
  hangat/dingin — bukan ketepatan nilainya. Angka yang salah di **kedua**
  bahasa akan tetap hijau, dan itu dinyatakan di sini alih-alih disangka
  tertutup.
- Menyentuh dua berkas (model, port) dan memulihkan keduanya persis; md5
  dibandingkan di akhir.
- Tidak ada berkas di `Apps/` yang disentuh, dan tidak ada uji Swift yang
  berubah.

Pakai:
    python3 Tools/bukti-mutasi-indeks-warna.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                           "CelestialVisual.swift")
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
FILES = [MODEL, RENDER]

HIJAU = "hijau"
MERAH = "merah"

# ── Nama hasil gerbang (dibaca dari sumber, bukan disalin mata) ──────────
ADA = "indeks warna bintang: setiap bintang model ada di port"
SISA = "indeks warna bintang: tidak ada bintang sisa di port"
TANDA = "indeks warna bintang: tanda hangat/dingin sama di kedua bahasa"
TERBACA = "indeks warna bintang: terbaca dari model"
#: Hasil per bintang: nama dibentuk dari nama bintangnya, jadi keadaan yang
#: menyentuh bintang lain akan memerahkan nama yang berbeda.
BETELGEUSE = "indeks warna betelgeuse"

#: Seluruh 25 bintang + 4 pemeriksaan tabel. Ditulis penuh karena himpunan
#: hasilnya dituntut **persis**: bintang yang hilang dari himpunan hasil
#: berarti gerbangnya berhenti melaporkannya, bukan lulus.
STARS = ["achernar", "acrux", "aldebaran", "alioth", "alnitak", "altair",
         "antares", "arcturus", "bellatrix", "betelgeuse", "canopus",
         "capella", "castor", "deneb", "dubhe", "fomalhaut", "hadar",
         "polaris", "pollux", "procyon", "regulus", "rigel", "sirius",
         "spica", "vega"]
FULL = [ADA, SISA] + [f"indeks warna {n}" for n in sorted(STARS)] + [TANDA]
assert len(FULL) == 28, f"28 pemeriksaan, terukur {len(FULL)}"

# ── Jangkar mutasi ───────────────────────────────────────────────────────
#: Tabel di **model** memakai perataan kolom, jadi angkanya tidak menempel di
#: titik dua. Jangkar di bawah menyertakan spasinya apa adanya — jangkar yang
#: "dirapikan" akan muncul nol kali dan harness-nya berhenti sebagai KELEMAHAN
#: BUKTI, bukan lulus diam-diam.
MODEL_BETELGEUSE_OLD = '"betelgeuse":  1.85,'
MODEL_BETELGEUSE_NEW = '"betelgeuse":  1.90,'
MODEL_BETELGEUSE_NEG = '"betelgeuse": -1.85,'
MODEL_RIGEL_OLD = '"rigel":      -0.03,'

#: Tabel di **port** ditulis padat, satu spasi.
PORT_BETELGEUSE_OLD = '"betelgeuse": 1.85,'
PORT_BETELGEUSE_NEW = '"betelgeuse": 1.90,'
PORT_BETELGEUSE_NEG = '"betelgeuse": -1.85,'
PORT_RIGEL_OLD = '"rigel": -0.03,'

#: Jangkar tabel model: menggantinya membuat pembacanya melempar, dan
#: gerbangnya harus melaporkan itu sebagai satu hasil merah.
MODEL_ANCHOR_OLD = "static let starColorIndex: [String: Double] = ["
MODEL_ANCHOR_NEW = "static let starColourIndex: [String: Double] = ["

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "cv_probe", os.path.join(sys.argv[1], "Tools", "check-visuals.py"))
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)

results = []
try:
    C.check_star_colour_index_matches_the_model(results)
except Exception as exc:
    print("RAISED " + type(exc).__name__ + ": " + str(exc)[:300])
    raise SystemExit(0)

for r in results:
    print("GATE|" + r.name + "|" + ("OK" if r.ok else "GAGAL"))
"""


def _full(*red):
    """Himpunan hasil lengkap; nama yang disebut di `red` memerah."""
    return {name: (MERAH if name in red else HIJAU) for name in FULL}


# ── Keadaan ──────────────────────────────────────────────────────────────
# (nama, [(berkas, cari, ganti), ...] atau None, {nama hasil: harapan})
STATES = [
    ("[baseline] sumber bersih", None, _full()),

    # ── Port menyimpang: tanda ───────────────────────────────────────────
    # Dua kawat, dan yang kedua itu intinya: nilai yang salah **dan** tanda
    # yang terbalik. Hanya pemeriksaan tanda yang bisa melihat yang kedua.
    ("1. port: betelgeuse 1.85 -> -1.85 (tanda)",
     [(RENDER, PORT_BETELGEUSE_OLD, PORT_BETELGEUSE_NEG)],
     _full(BETELGEUSE, TANDA)),

    # ── Port menyimpang: nilai saja ──────────────────────────────────────
    # Pemeriksaan tanda **tidak** berbunyi di sini — kedua sisi masih sama-
    # sama positif. Itu yang membuktikan kedua kawat tidak saling menggantikan.
    ("2. port: betelgeuse 1.85 -> 1.90 (nilai)",
     [(RENDER, PORT_BETELGEUSE_OLD, PORT_BETELGEUSE_NEW)],
     _full(BETELGEUSE)),

    # ── Model menyimpang: nilai saja ─────────────────────────────────────
    ("3. model: betelgeuse 1.85 -> 1.90",
     [(MODEL, MODEL_BETELGEUSE_OLD, MODEL_BETELGEUSE_NEW)],
     _full(BETELGEUSE)),

    # ── Model menyimpang: tanda ──────────────────────────────────────────
    # Pasangan keadaan 1 dari sisi seberang. Gerbangnya mengukur **dua arah**:
    # model yang menyimpang sama merahnya dengan port yang menyimpang, karena
    # port-lah yang akan mengikuti model saat keduanya tidak sepakat.
    ("4. model: betelgeuse 1.85 -> -1.85",
     [(MODEL, MODEL_BETELGEUSE_OLD, MODEL_BETELGEUSE_NEG)],
     _full(BETELGEUSE, TANDA)),

    # ── Bintang hilang: dua arah yang tidak simetris ─────────────────────
    # Keduanya memerahkan pemeriksaan yang **berbeda**. Kalau salah satu arah
    # tidak diperiksa, bintang yang hilang dari sisi itu lewat tanpa suara:
    # sisi yang tersisa masih memuat nama yang sama, jadi pemeriksaan
    # per-bintang tidak punya apa pun untuk dibandingkan.
    ("5. model kehilangan rigel",
     [(MODEL, MODEL_RIGEL_OLD, "")],
     {n: (MERAH if n == SISA else HIJAU) for n in FULL if n != "indeks warna rigel"}),

    ("6. port kehilangan rigel",
     [(RENDER, PORT_RIGEL_OLD, "")],
     {n: (MERAH if n == ADA else HIJAU) for n in FULL if n != "indeks warna rigel"}),

    # ── Penyuntingan yang SAH: wajib hijau ───────────────────────────────
    # Mengubah kedua sisi menjadi nilai yang sama bukan cacat — model dan
    # port masih sepakat. Ini satu-satunya cara yang benar untuk menyunting
    # angka B−V, dan harness yang merah di sini mengajarkan bahwa gerbangnya
    # menolak pekerjaan, bukan menuntut kesepakatan.
    ("7. KEDUANYA diubah bersama, nilai sama (wajib hijau)",
     [(MODEL, MODEL_BETELGEUSE_OLD, MODEL_BETELGEUSE_NEW),
      (RENDER, PORT_BETELGEUSE_OLD, PORT_BETELGEUSE_NEW)],
     _full()),

    # ── Jangkar tabel dirapikan: berhenti lebih awal, tanpa traceback ────
    ("8. jangkar tabel model dirapikan",
     [(MODEL, MODEL_ANCHOR_OLD, MODEL_ANCHOR_NEW)],
     {TERBACA: MERAH}),
]


def run_probe():
    """Jalankan gerbang di proses baru. → (hasil, galat)."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if line.startswith("RAISED "):
            return None, line
        if not line:
            continue
        parts = line.split("|")
        if len(parts) != 3:
            continue
        _, name, state = parts
        verdicts[name] = HIJAU if state == "OK" else MERAH
    return verdicts, None


def mutate(path, old, new):
    """Suntikkan `old` -> `new`; jangkar harus muncul **tepat sekali**.

    Tanpa penuntutan itu, jangkar yang muncul di beberapa tempat akan
    menyasar yang pertama — yang belum tentu yang sedang diuji — dan
    harness-nya lalu mengukur berkas yang salah sambil terlihat benar.
    """
    text = open(path, encoding="utf-8").read()
    count = text.count(old)
    if count != 1:
        return (f"KELEMAHAN BUKTI: {os.path.basename(path)}: jangkar muncul "
                f"{count}x, butuh 1")
    text = text.replace(old, new)
    if new and new not in text:
        return "KELEMAHAN BUKTI: hasil suntikan tidak ditemukan"
    mutasi_sumber.write_source(path, text)
    return None


def main():
    mutasi_sumber.require_clean_sources(FILES)
    originals = {path: open(path, "rb").read() for path in FILES}
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
        for name, edits, expected in STATES:
            restore()
            problems = []
            if edits is not None:
                for path, find, replace in edits:
                    problem = mutate(path, find, replace)
                    if problem:
                        problems.append(problem)
                        break
            if not problems:
                verdicts, error = run_probe()
                if verdicts is None:
                    problems.append(f"probe gagal: {error}")
                else:
                    # Himpunan hasilnya dibandingkan **persis**: hasil yang
                    # hilang (gerbang berhenti lebih awal), hasil tak
                    # terduga (cakupannya berubah), dan verdict yang salah.
                    missing = sorted(set(expected) - set(verdicts))
                    extra = sorted(set(verdicts) - set(expected))
                    if missing:
                        problems.append(f"hasil hilang: {missing}")
                    if extra:
                        problems.append(f"hasil tak terduga: {extra}")
                    wrong = [f"{n} diharapkan {w} terukur {verdicts[n]}"
                             for n, w in expected.items()
                             if n in verdicts and verdicts[n] != w]
                    if wrong:
                        problems.append("verdict salah: " + "; ".join(wrong))

            if problems:
                failures.append(f"{name}: " + " | ".join(problems))
                print(f"{name}: TIDAK SESUAI HARAPAN")
                for item in problems:
                    print(f"    {item}")
            else:
                merah = sum(1 for v in expected.values() if v == MERAH)
                print(f"{name}: sesuai harapan ({merah} merah dari "
                      f"{len(expected)} pemeriksaan)")
    finally:
        restore()

    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        rel = os.path.relpath(path, ROOT)
        print(f"md5 {rel}: {digest} -> {after} "
              f"({'pulih persis' if after == digest else 'TIDAK PULIH'})")
        if after != digest:
            failures.append(f"sumber produksi tidak pulih persis: {path}")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
