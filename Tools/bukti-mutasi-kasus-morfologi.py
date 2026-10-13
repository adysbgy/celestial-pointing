#!/usr/bin/env python3
"""Buktikan gerbang **kasus render morfologi** berbunyi — dan bahwa bentuk baru
yang terpasang lengkap memang hijau.

Kenapa harness ini ada.

`check_every_morphology_in_the_model_has_render_cases` menjaga aturan yang
berlaku untuk **bentuk yang belum ada**: setiap morfologi di enum
`DeepSkyCatalogue.Morphology` harus terbaca pembaca gerbang, punya kasus
render, punya layout di port, dan tidak ada bentuk sisa di port. Keenam
morfologi hari ini sudah memenuhi keempatnya, jadi gerbangnya hijau apa pun
yang terjadi pada bentuk **berikutnya**.

Gerbang tetangganya — `check_deep_sky_layouts_match_the_model` — tampak
menjaga hal yang sama, dan tidak. Ia membandingkan model dengan port **per
nama yang ia temukan di kedua sisi**, dan daftar namanya ditulis tangan. Jadi
ia benar, dan ia tidak bisa melihat bentuk yang tidak ada di kedua daftar
sekaligus. Keadaan 3 di bawah mengukurnya: komet ditambahkan ke enum, ke
`switch` gambar, dan ke kasus render — tetangganya **hijau penuh, 8 dari 8
pemeriksaan**, sementara gerbang ini merah dua kali. Yang pertama adalah
keadaan sunyinya, dan ia terukur, bukan diklaim.

### Cacat yang ditemukan harness ini (bukan sekadar dibuktikan)

Keadaan 5 menemukan bahwa gerbangnya **mati dengan traceback**. Pembacanya
menyebut nama morfologi sebagai jangkar teks (`case .<nama>:`), jadi
merapikan satu cabang `switch` membuatnya melempar `ValueError` yang tidak
ditangkap siapa pun: `check-visuals.py` berhenti dengan traceback, bukan
melaporkan satu hasil merah. Gerbang tetangganya sudah membungkus pembaca
yang sama dengan `try/except ValueError` sejak awal.

Itu kelas cacat yang repo ini sendiri sudah nyatakan berbahaya: gerbang yang
mati dengan traceback saat modelnya dirapikan **akan dihapus orang**, bukan
diperbaiki. Perbaikannya ada di `check_every_morphology_in_the_model_has_render_cases`
(bungkus `ValueError` → satu `Result` merah yang menyebut jangkarnya), dan
keadaan 5 adalah regresinya: sebelum perbaikan ia melaporkan
`GATE RAISED ValueError`, sesudahnya satu pemeriksaan merah bernama
`kasus render morfologi: pembaca gerbang terbaca dari model`.

### Keadaan

  keadaan                                          harapan
  [baseline]                                       hijau 4/4
  1. enum + switch gambar (.comet), tanpa sisanya  MERAH 3 dari 4
  2. port saja (.comet di DEEP_SKY_LAYOUT)         MERAH 1 dari 4
  3. enum + switch + kasus render, TANPA port      MERAH 2 dari 4
     — dan tetangganya hijau **8/8** di keadaan yang sama
  4. pembaca gerbang kehilangan 'globularCluster'  MERAH 1 dari 4
  5. model: switch kehilangan 'case .globularCluster:'
                                                   MERAH 1, dan gerbangnya
                                                   **berhenti lebih awal**
  5b. enum Morphology dirusak namanya              MERAH 1, berhenti lebih awal
  6. **comet terpasang LENGKAP**                   **hijau 4/4**

Keadaan 1, 2, 3, 4 memerahkan kawat yang berbeda dan tidak saling
menggantikan. Yang paling penting justru 3: ia satu-satunya keadaan yang
menunjukkan gerbang tetangga **tidak bisa** melihat cacatnya, dan itu satu-
satunya alasan gerbang ini ada. Kalau 3 hijau, gerbang ini tidak menambah
apa pun.

Keadaan 5 dan 5b **berhenti lebih awal** — gerbangnya melaporkan satu hasil
lalu `return`. Himpunan hasilnya karena itu dituntut **persis**: gerbang yang
berhenti lebih awal harus terlihat berhenti lebih awal, bukan diam-diam
dianggap lulus karena satu hasilnya merah. Itu alasan kedua pemeriksaan ini
memakai perbandingan himpunan, bukan sekadar "ada yang merah".

Keadaan 6 adalah alasan gerbang ini ada, dinyatakan sebagai keadaan yang bisa
diukur: bentuk yang terpasang **lengkap** tidak memerahkan apa pun, dan
tetangganya ikut hijau. Tanpa keadaan ini, harness yang merah pada setiap
suntingan bentuk mengajarkan bahwa gerbangnya menolak pekerjaan, bukan
menuntut kelengkapannya — dan gerbang yang dilonggarkan tidak menjaga apa pun.

### Yang TIDAK diklaim

- Yang diukur **teks**, bukan piksel app Apple. Yang dibuktikan: keempat
  kawat gerbang ini merah pada keadaan yang memang salah, dan hijau pada
  bentuk yang terpasang lengkap.
- Keadaan 1–3 dan 6 **tidak dikompilasi Swift**: `.comet` tidak ada di enum
  aslinya di pohon nyata, dan harness ini menyunting salinan di pohon kerja.
  Yang diukur adalah pembaca teks `check-visuals.py`, persis seperti yang
  dijalankan CI. Tidak ada klaim bahwa app Apple menggambar komet.
- Bentuk kelima yang benar-benar ditambahkan ke app **belum ada**; harness ini
  tidak menambahkannya, hanya membuktikan bahwa gerbangnya akan menuntut
  kelengkapannya kalau ditambahkan.
- Harness ini menyentuh empat berkas (model, katalog, port, gerbang) dan
  memulihkan keempatnya persis; md5 dibandingkan di akhir.

Pakai:
    python3 Tools/bukti-mutasi-kasus-morfologi.py    # 0 = semua sesuai harapan
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
CATALOGUE = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                               "DeepSkyCatalogue.swift")
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")
CHECK = os.path.join(ROOT, "Tools", "check-visuals.py")
FILES = [MODEL, CATALOGUE, RENDER, CHECK]

HIJAU = "hijau"
MERAH = "merah"

# ── Nama hasil gerbang (dibaca dari sumber, bukan disalin mata) ──────────
FULL = [
    "kasus render morfologi: setiap kasus enum terbaca pembaca gerbang",
    "kasus render morfologi: setiap kasus enum punya kasus render",
    "kasus render morfologi: setiap kasus enum punya layout di port",
    "kasus render morfologi: tidak ada bentuk sisa di port",
]
#: Hasil yang muncul saat gerbangnya **berhenti lebih awal** (jangkar hilang).
AWAL_ENUM = "kasus render morfologi: enum terbaca dari model"
AWAL_PEMBACA = "kasus render morfologi: pembaca gerbang terbaca dari model"

TERBACA, KASUS, PORT, SISA = FULL

# ── Nama hasil tetangga: tiga pemeriksaan strukturalnya ─────────────────
N_TERBACA = "tata letak objek langit dalam: terbaca dari model"
N_ADA = "tata letak objek langit dalam: setiap bentuk model ada di port"
N_SISA = "tata letak objek langit dalam: tidak ada bentuk sisa di port"
NEIGHBOUR_STRUCT = [N_TERBACA, N_ADA, N_SISA]

# ── Jangkar mutasi ───────────────────────────────────────────────────────
#: Kasus enum baru. Dipakai di tiga keadaan, dengan kelengkapan berbeda.
ENUM_TAIL_OLD = "        case globularCluster\n    }"
ENUM_TAIL_COMET = "        case globularCluster\n        case comet\n    }"
ENUM_ANCHOR_OLD = ("public enum Morphology: String, Equatable, Sendable, "
                   "CaseIterable {")
ENUM_ANCHOR_NEW = ("public enum MorphologyX: String, Equatable, Sendable, "
                   "CaseIterable {")

#: Cabang gambar di model. Keadaan 5 mengganti namanya — jangkar teks yang
#: dicari pembaca hilang, dan itulah yang membuktikan gerbangnya **tidak**
#: mati dengan traceback.
SWITCH_GLOB_OLD = "        case .globularCluster:\n"
SWITCH_GLOB_NEW = "        case .globularClusterRenamed:\n"
COMET_SWITCH = ("        case .comet:\n"
                "            let layout: [(Double, Double, Double, Double, "
                "Double, Double)] = [\n"
                "                ( 0.000000,  0.000000, 0.34, 1.0, 0.0, 0.55),\n"
                "                ( 0.520000, -0.340000, 0.33, 1.0, 0.0, 0.45)\n"
                "            ]\n"
                "            return buildDeepSky(layout: layout, "
                "fuzziness: fuzziness,\n"
                "                                frameHalfExtent: "
                "frameHalfExtent)\n\n"
                "        case .globularCluster:\n")

#: Daftar nama **tangan** di dalam pembaca gerbang. Inilah tempat nama yang
#: ditambahkan belakangan tertinggal — dan alasan pemeriksaan 1 ada.
READER_OLD = ('    for name in ("planetaryNebula", "galaxy", "spiralGalaxy", '
              '"openCluster",\n                 "globularCluster"):')
READER_COMET = ('    for name in ("planetaryNebula", "galaxy", "spiralGalaxy", '
                '"openCluster",\n                 "globularCluster", "comet"):')
#: Kehilangan satu nama yang **sudah** ada: pembaca berhenti menjangkau
#: `globularCluster`, jadi bentuk itu dilaporkan tidak terbaca walaupun ia
#: ada di model dan di port.
READER_DROP_OLD = ('                 "globularCluster"):')
READER_DROP_NEW = ('                 ):')

#: Kasus render bentuk baru (port gambar).
RENDER_TAIL_OLD = '("globularCluster", "gugus bola (M13)")):'
RENDER_TAIL_COMET = ('("globularCluster", "gugus bola (M13)"),\n'
                     '                        ("comet", "komet")):')
#: Layout bentuk baru di port.
PORT_OPEN = "DEEP_SKY_LAYOUT = {\n"
PORT_COMET = ('DEEP_SKY_LAYOUT = {\n'
              '    "comet": [( 0.000000,  0.000000, 0.34, 1.0, 0.0, 0.55),\n'
              '              ( 0.520000, -0.340000, 0.33, 1.0, 0.0, 0.45)],\n')

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

def emit(tag, results):
    for r in results:
        print(tag + "|" + r.name + "|" + ("OK" if r.ok else "GAGAL"))

gate = []
try:
    C.check_every_morphology_in_the_model_has_render_cases(gate)
except Exception as exc:
    print("RAISED_GATE " + type(exc).__name__ + ": " + str(exc)[:200])
emit("GATE", gate)

neighbour = []
try:
    C.check_deep_sky_layouts_match_the_model(neighbour)
except Exception as exc:
    print("RAISED_TETANGGA " + type(exc).__name__ + ": " + str(exc)[:200])
emit("TETANGGA", neighbour)
"""


def _full(*red):
    """Himpunan hasil lengkap; nama yang disebut di `red` memerah."""
    return {name: (MERAH if name in red else HIJAU) for name in FULL}


# ── Keadaan ──────────────────────────────────────────────────────────────
# (nama, [(berkas, cari, ganti), ...] atau None, {nama hasil: harapan},
#  {nama hasil tetangga: harapan} atau None)
STATES = [
    ("[baseline] sumber bersih", None, _full(), None),

    # ── Bentuk baru di enum + switch, sisanya belum ──────────────────────
    # Tiga kawat, dan ketiganya berbeda: bentuk yang tidak terbaca pembaca,
    # bentuk yang tidak punya kasus render, dan bentuk yang tidak punya
    # layout di port. Yang keempat (bentuk sisa) memang **tidak** berbunyi —
    # port belum disentuh, jadi tidak ada yang berlebih di sana.
    ("1. enum + switch gambar (.comet), tanpa sisanya",
     [(CATALOGUE, ENUM_TAIL_OLD, ENUM_TAIL_COMET),
      (MODEL, SWITCH_GLOB_OLD, COMET_SWITCH)],
     _full(TERBACA, KASUS, PORT), None),

    # ── Bentuk hanya ditambahkan ke port ─────────────────────────────────
    # Kode mati yang tampak seperti pekerjaan selesai: ada, tidak salah, dan
    # tidak bisa dipilih objek mana pun.
    ("2. port saja (.comet di DEEP_SKY_LAYOUT)",
     [(RENDER, PORT_OPEN, PORT_COMET)],
     _full(SISA), None),

    # ── Keadaan sunyi: tetangganya hijau penuh ───────────────────────────
    # Bentuk ditambahkan ke enum, ke switch, dan ke kasus render — tetapi
    # tidak ke layout port. Gerbang tetangganya **8 dari 8 hijau**, karena
    # yang dibacanya adalah daftar nama tangan yang tidak memuat `comet`.
    # Inilah satu-satunya alasan gerbang ini ada.
    ("3. enum + switch + kasus render, TANPA port",
     [(CATALOGUE, ENUM_TAIL_OLD, ENUM_TAIL_COMET),
      (MODEL, SWITCH_GLOB_OLD, COMET_SWITCH),
      (RENDER, RENDER_TAIL_OLD, RENDER_TAIL_COMET)],
     _full(TERBACA, PORT), "semua hijau"),

    # ── Pembaca gerbang kehilangan satu nama yang sudah ada ──────────────
    # Bentuknya ada di model dan di port; yang hilang hanya jangkauan
    # pembacanya. Akibatnya bentuk itu dilaporkan tidak terbaca.
    ("4. pembaca gerbang kehilangan 'globularCluster'",
     [(CHECK, READER_DROP_OLD, READER_DROP_NEW)],
     _full(TERBACA), None),

    # ── Jangkar hilang: gerbangnya berhenti lebih awal ───────────────────
    # Sebelum perbaikan di gerbangnya, keadaan ini melaporkan
    # `RAISED_GATE ValueError` — traceback, bukan hasil. Himpunan hasil
    # dituntut **persis** supaya "berhenti lebih awal" terlihat sebagai
    # berhenti lebih awal.
    ("5. model: switch kehilangan 'case .globularCluster:'",
     [(MODEL, SWITCH_GLOB_OLD, SWITCH_GLOB_NEW)],
     {AWAL_PEMBACA: MERAH}, None),

    ("5b. enum Morphology dirusak namanya",
     [(CATALOGUE, ENUM_ANCHOR_OLD, ENUM_ANCHOR_NEW)],
     {AWAL_ENUM: MERAH}, None),

    # ── Bentuk terpasang lengkap: wajib hijau ────────────────────────────
    # Empat tempat: enum, switch gambar, daftar pembaca, kasus render, dan
    # layout port. Kelimanya harus sepakat sebelum gerbangnya hijau.
    ("6. comet TERPASANG LENGKAP (wajib hijau)",
     [(CATALOGUE, ENUM_TAIL_OLD, ENUM_TAIL_COMET),
      (MODEL, SWITCH_GLOB_OLD, COMET_SWITCH),
      (CHECK, READER_OLD, READER_COMET),
      (RENDER, RENDER_TAIL_OLD, RENDER_TAIL_COMET),
      (RENDER, PORT_OPEN, PORT_COMET)],
     _full(), "semua hijau"),
]


def run_probe():
    """Jalankan gerbang di proses baru. → (hasil, tetangga, galat)."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        return None, None, out.stderr.strip()[-1500:]
    gate, neighbour, raised = {}, {}, []
    for line in out.stdout.splitlines():
        line = line.strip()
        if line.startswith("RAISED_"):
            raised.append(line)
            continue
        if not line:
            continue
        parts = line.split("|")
        if len(parts) != 3:
            continue
        tag, name, state = parts
        verdict = HIJAU if state == "OK" else MERAH
        if tag == "GATE":
            gate[name] = verdict
        elif tag == "TETANGGA":
            neighbour[name] = verdict
    if raised:
        return None, None, " | ".join(raised)
    return gate, neighbour, None


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
    if new not in text:
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
        for name, edits, expected, neighbour_rule in STATES:
            restore()
            problems = []
            if edits is not None:
                for path, find, replace in edits:
                    problem = mutate(path, find, replace)
                    if problem:
                        problems.append(problem)
                        break
            if not problems:
                gate, neighbour, error = run_probe()
                if gate is None:
                    problems.append(f"probe gagal: {error}")
                else:
                    # Himpunan hasilnya dibandingkan **persis**: hasil yang
                    # hilang (gerbang berhenti lebih awal), hasil tak
                    # terduga (cakupannya berubah), dan verdict yang salah.
                    missing = sorted(set(expected) - set(gate))
                    extra = sorted(set(gate) - set(expected))
                    if missing:
                        problems.append(f"hasil hilang: {missing}")
                    if extra:
                        problems.append(f"hasil tak terduga: {extra}")
                    wrong = [f"{n} diharapkan {w} terukur {gate[n]}"
                             for n, w in expected.items()
                             if n in gate and gate[n] != w]
                    if wrong:
                        problems.append("verdict salah: " + "; ".join(wrong))

                    if neighbour_rule == "semua hijau":
                        merah = sorted(n for n, v in neighbour.items()
                                       if v == MERAH)
                        if merah:
                            problems.append(
                                "tetangga seharusnya hijau penuh di keadaan "
                                f"ini, terukur merah: {merah}")
                        elif not neighbour:
                            problems.append(
                                "tetangga melaporkan nol hasil — ia tidak "
                                "mengukur apa pun, jadi 'hijau penuh' di sini "
                                "tidak membuktikan apa-apa")

            if problems:
                failures.append(f"{name}: " + " | ".join(problems))
                print(f"{name}: TIDAK SESUAI HARAPAN")
                for item in problems:
                    print(f"    {item}")
            else:
                if neighbour_rule == "semua hijau":
                    print(f"{name}: sesuai harapan "
                          f"({len(neighbour)} pemeriksaan tetangga, "
                          f"semuanya hijau)")
                else:
                    print(f"{name}: sesuai harapan "
                          f"({len(expected)} pemeriksaan, "
                          f"{sum(1 for v in expected.values() if v == MERAH)} "
                          f"merah)")
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
