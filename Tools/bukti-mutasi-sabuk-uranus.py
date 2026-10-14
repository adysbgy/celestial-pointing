#!/usr/bin/env python3
"""Buktikan gerbang **konstanta port yang mengaku dari model** berbunyi — dan
berbunyi pada keadaan yang memang salah, di **kedua** arah.

Kenapa harness ini ada.

Uranus dan Neptunus masuk bersama **sembilan** konstanta geometri di port
Python, masing-masing dengan komentar `# MODEL: CelestialVisual.<nama>` yang
menjanjikan angkanya sama dengan sumber Swift-nya. Tidak ada pemeriksaan mana
pun yang membandingkan kesembilan pasangan itu. Diukur pada sumber saat
gerbangnya ditulis: mengganti `URANUS_BAND_HALF_HEIGHT 0.30 -> 0.55` **dan**
`NEPTUNE_SPOT_OPACITY 0.55 -> 0.20` membiarkan seluruh gerbang gambar repo ini
pada jumlah merah yang **sama persis** seperti sebelumnya. Kelas cacatnya sama
dengan yang sudah dibayar repo ini untuk kabut Venus dan indeks warna B−V:
**komentar yang menjanjikan kesamaan bukan gerbang** — dan di sini ia lebih
menipu, karena namanya memuat kata "MODEL" di sebelahnya.

Gerbangnya hijau pada hari ditulis, dan itu bukan bukti apa pun: kedua sisi
memang sama hari ini. Yang membedakan gerbang yang menjaga dari gerbang yang
hanya *terlihat* menjaga adalah apakah ia bisa dibuat merah, dan merah pada
keadaan yang memang salah.

### Dua arah yang **tidak** simetris

Model dan port memuat angka yang sama, tetapi yang menggambar adalah
**port**: seluruh gerbang piksel repo ini menyampel PNG dari
`render-visuals.py`, bukan dari app Apple. Jadi port yang menyimpang adalah
yang bisa membuat PNG mengukur sabuk setinggi 0.55 R sementara jam menggambar
0.30 R — dan itu tidak pernah terlihat di layar mana pun.

Harness ini menuntut **nama** pemeriksaan yang merah, bukan sekadar "ada yang
merah", dan itu yang membuat keadaan 1 dan 4 tidak bisa saling menggantikan:
keduanya menyentuh angka yang sama, sekali dari port dan sekali dari model.

### Nama token itu sendiri yang memilih parameternya

Sebagian konstanta port bernilai **skalar** sementara komentarnya menunjuk
sebuah **fungsi**:

    URANUS_BAND_CENTER_Y = 0.0      # MODEL: `uranusBand`

Gerbangnya membaca `uranusBand` di model, mengambil parameter yang namanya
disebut token itu sendiri (`CENTER_Y` → `centerY:`), lalu membandingkan satu
angka. Keadaan 2 dan 3 memakai pasangan token ini, jadi jalur pembacaan
"token bersufiks nama parameter" ikut dibuktikan berbunyi — bukan hanya jalur
`static let … : Double` yang sudah dipakai keadaan 1 dan 4.

### Keadaan

  keadaan                                              harapan
  [baseline] sumber bersih                             hijau 21/21
  1. port:   URANUS_BAND_HALF_HEIGHT 0.30 -> 0.55      MERAH 1 (token itu)
  2. port:   URANUS_BAND_CENTER_Y 0.0 -> 0.25          MERAH 1 (token itu)
  3. model:  uranusBand(centerY:) 0.0 -> 0.25          MERAH 1 (token itu)
  4. model:  uranusBandOpacity 0.18 -> 0.66            MERAH 1 (token itu)
  5. port kehilangan komentar `# MODEL:`               hasilnya **menyusut**:
                                                       himpunan dituntut persis
  6. **keduanya diubah bersama, nilai sama**           **hijau 21/21**
  7. jangkar gerbang dirapikan (fungsi diganti nama)   MERAH, berhenti di
                                                       pemeriksaan batas

Keadaan 6 adalah yang paling mudah hilang dari sebuah harness, dan ia yang
menjaga gerbangnya tetap jujur: mengubah **kedua** sisi menjadi nilai yang
sama **bukan cacat** — model dan port masih sepakat. Harness yang merah di
sana akan mengajarkan bahwa gerbangnya menolak pekerjaan yang benar, dan
gerbang yang dilonggarkan untuk itu berhenti menjaga apa pun.

Keadaan 7 mengukur satu-satunya jalan keluar yang jujur ketika bentuk model
berubah: pembacanya melaporkan **satu** hasil merah yang menyebut
pengakuannya, bukan traceback dan bukan hijau.

### Yang TIDAK diklaim

- Yang diukur **teks**, bukan piksel app Apple. Yang dibuktikan: gerbangnya
  merah pada kedua arah penyimpangan, hijau pada penyuntingan yang sah, dan
  berhenti dengan pesan bersih saat bentuk modelnya berubah.
- Harness ini **tidak** membuktikan bahwa sembilan angka geometri itu benar
  sebagai astronomi — itu keputusan tampilan (seberapa samar sabuk Uranus
  boleh terlihat), bukan hasil pengukuran. Angka yang sama-sama salah di
  **kedua** sisi akan tetap hijau, dan itu dinyatakan di sini alih-alih
  disangka tertutup.
- **Lima token sengaja di luar cakupan**, dan jumlahnya dituntut di sini
  supaya batas itu tidak bisa melebar tanpa terlihat: `CRATER_RIM_STRENGTH`,
  `CRATER_FLOOR_DEPTH`, `SPHERE_LIGHT_OFFSET`, `SPOT_CENTER`, `SPOT_SIZE`.
  Pengakuan mereka menunjuk fungsi yang memakainya sebagai parameter
  **keberapa-tidak-tentu** (`craterRelief` menerima `strength:` sebagai
  parameter ketiga dari empat) atau sebagai **tupel dua** parameter
  (`SPOT_CENTER`). Memetakannya menuntut menebak, dan gerbang yang menebak
  akan merah pada kode yang benar — gerbang yang merah pada kode benar akan
  dimatikan orang. Batasnya **dinyatakan**, bukan disangka tertutup.
- Menyentuh dua berkas (model, port) dan memulihkan keduanya persis; md5
  dibandingkan di akhir.
- Tidak ada berkas di `Apps/` yang disentuh, dan tidak ada uji Swift yang
  berubah.

Pakai:
    python3 Tools/bukti-mutasi-sabuk-uranus.py    # 0 = semua sesuai harapan
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
#: Hasil per token: nama dibentuk dari nama tokennya, jadi keadaan yang
#: menyentuh token lain akan memerahkan nama yang berbeda.
URANUS_HALF_HEIGHT = "model→port: URANUS_BAND_HALF_HEIGHT[0] == model"
URANUS_CENTER_Y = "model→port: URANUS_BAND_CENTER_Y[0] == model"
URANUS_OPACITY = "model→port: URANUS_BAND_OPACITY[0] == model"
NEPTUNE_CENTER_X = "model→port: NEPTUNE_SPOT_CENTER_X[0] == model"
NEPTUNE_CENTER_Y = "model→port: NEPTUNE_SPOT_CENTER_Y[0] == model"
NEPTUNE_HALF_WIDTH = "model→port: NEPTUNE_SPOT_HALF_WIDTH[0] == model"
NEPTUNE_HALF_HEIGHT = "model→port: NEPTUNE_SPOT_HALF_HEIGHT[0] == model"
NEPTUNE_OPACITY = "model→port: NEPTUNE_SPOT_OPACITY[0] == model"
#: Batas yang dinyatakan: hasilnya **selalu hijau** (ia ada supaya daftarnya
#: bisa dibaca), tetapi kehadirannya dituntut persis supaya cakupan gerbang
#: tidak bisa menyusut tanpa terlihat.
BATAS = "model→port: batas (pengakuan ke fungsi tak terpetakan)"

#: Seluruh 21 pemeriksaan gerbang. Ditulis penuh karena himpunan hasilnya
#: dituntut **persis**: token yang hilang dari himpunan hasil berarti
#: gerbangnya berhenti melaporkannya, bukan lulus.
FULL = [
    # Ciri pengenal planet: kata yang sama di kedua sisi.
    "model→port: ciri jupiter sama",
    "model→port: ciri mars sama",
    "model→port: ciri mercury sama",
    "model→port: ciri saturn sama",
    "model→port: ciri venus sama",
    # Bentuk `static let … : Double` di model.
    URANUS_OPACITY,
    NEPTUNE_CENTER_X, NEPTUNE_OPACITY,
    "model→port: MOON_LIMB_SHADING_STRENGTH[0] == model",
    "model→port: MOON_SPHERE_GRADIENT_END_RADIUS[0] == model",
    "model→port: POLAR_CAP_OPACITY[0] == model",
    # Bentuk `static func … -> HazeGeometry`, seluruh parameternya.
    URANUS_CENTER_Y, URANUS_HALF_HEIGHT,
    "model→port: URANUS_BAND_HALF_WIDTH[0] == model",
    NEPTUNE_CENTER_Y, NEPTUNE_HALF_WIDTH, NEPTUNE_HALF_HEIGHT,
    # Bentuk skalar yang mengaku ke fungsi: parameter dipilih oleh sufiks
    # nama tokennya.
    "model→port: VENUS_HAZE_CENTER_Y[0] == model",
    "model→port: VENUS_HAZE_HALF_WIDTH[0] == model",
    "model→port: VENUS_HAZE_HALF_HEIGHT[0] == model",
    # Batas yang dinyatakan.
    BATAS,
]
FULL = sorted(set(FULL))
assert len(FULL) == 21, f"21 pemeriksaan, terukur {len(FULL)}"

#: Nama hasil untuk pengakuan yang namanya hilang dari model. Dibentuk dari
#: nama tokennya, jadi keadaan 7 memerahkan ketiga token sabuk Uranus —
#: bukan satu yang kebetulan tersisa.
def _punya_sumber(token):
    return f"model→port: pengakuan {token} punya sumber"

# ── Jangkar mutasi ───────────────────────────────────────────────────────
#: Sabuk Uranus di **port** ditulis dengan perataan kolom.
PORT_UH_OLD = "URANUS_BAND_HALF_HEIGHT = 0.30"
PORT_UH_NEW = "URANUS_BAND_HALF_HEIGHT = 0.55"
PORT_UC_OLD = "URANUS_BAND_CENTER_Y = 0.0"
PORT_UC_NEW = "URANUS_BAND_CENTER_Y = 0.25"

#: Sabuk Uranus di **model**: `halfHeight:` berdiri sendiri di barisnya.
MODEL_UH_OLD = "halfHeight: Double = 0.30) -> HazeGeometry"
MODEL_UH_NEW = "halfHeight: Double = 0.55) -> HazeGeometry"
MODEL_UC_OLD = "static func uranusBand(centerY: Double = 0.0,"
MODEL_UC_NEW = "static func uranusBand(centerY: Double = 0.25,"

#: Opasitas: `static let … : Double` di kedua sisi — bentuk pembacaan kedua,
#: yang dipakai keadaan 4 dari sisi model.
MODEL_OP_OLD = "static let uranusBandOpacity: Double = 0.18"
MODEL_OP_NEW = "static let uranusBandOpacity: Double = 0.66"

#: Menghapus komentar pengakuan membuat token itu **hilang dari pemeriksaan**.
PORT_COMMENT_OLD = ("URANUS_BAND_HALF_HEIGHT = 0.30               "
                    "# MODEL: `CelestialVisual.uranusBand`")
PORT_COMMENT_NEW = "URANUS_BAND_HALF_HEIGHT = 0.30"

#: Jangkar gerbang: fungsi model diganti nama, jadi ketiga pengakuan
#: `URANUS_BAND_*` menggantung. Sebelum penjaga ini ada, keadaan ini
#: **hijau** — token-token itu menyusut dari himpunan hasil tanpa suara.
MODEL_ANCHOR_OLD = "static func uranusBand(centerY: Double"
MODEL_ANCHOR_NEW = "static func uranusStripe(centerY: Double"

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
    C.check_modeled_port_constants_match_the_model(results)
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

    # ── Port menyimpang: bentuk `static let` ─────────────────────────────
    ("1. port: URANUS_BAND_HALF_HEIGHT 0.30 -> 0.55",
     [(RENDER, PORT_UH_OLD, PORT_UH_NEW)],
     _full(URANUS_HALF_HEIGHT)),

    # ── Port menyimpang: bentuk fungsi bersufiks parameter ───────────────
    # Membuktikan jalur pembacaan "token bersufiks nama parameter" berbunyi,
    # bukan hanya jalur `static let`. CenterY di sini **bukan** nol, jadi
    # gerbang yang hanya membandingkan panjang atau lupa mengambil angkanya
    # akan lolos pada keadaan 1 tetapi tidak di sini.
    ("2. port: URANUS_BAND_CENTER_Y 0.0 -> 0.25",
     [(RENDER, PORT_UC_OLD, PORT_UC_NEW)],
     _full(URANUS_CENTER_Y)),

    # ── Model menyimpang: bentuk fungsi bersufiks parameter ──────────────
    ("3. model: uranusBand(centerY:) 0.0 -> 0.25",
     [(MODEL, MODEL_UC_OLD, MODEL_UC_NEW)],
     _full(URANUS_CENTER_Y)),

    # ── Model menyimpang: bentuk `static let` ────────────────────────────
    # Pasangan keadaan 1 dari sisi seberang. Gerbangnya mengukur **dua arah**:
    # model yang menyimpang sama merahnya dengan port yang menyimpang.
    ("4. model: uranusBandOpacity 0.18 -> 0.66",
     [(MODEL, MODEL_OP_OLD, MODEL_OP_NEW)],
     _full(URANUS_OPACITY)),

    # ── Pengakuan dicabut: cakupannya menyusut ───────────────────────────
    # Tanpa komentar `# MODEL:`, token itu tidak lagi diperiksa. Hasilnya
    # **hilang** dari himpunan, dan himpunan dituntut persis — jadi gerbang
    # yang diam-diam berhenti mengukur satu token terlihat sebagai hilang,
    # bukan lulus.
    ("5. port mencabut komentar `# MODEL:` dari satu token",
     [(RENDER, PORT_COMMENT_OLD, PORT_COMMENT_NEW)],
     {n: HIJAU for n in FULL if n != URANUS_HALF_HEIGHT}),

    # ── Penyuntingan yang SAH: wajib hijau ───────────────────────────────
    # Mengubah kedua sisi menjadi nilai yang sama bukan cacat — model dan port
    # masih sepakat. Ini satu-satunya cara yang benar untuk menyunting angka
    # geometri, dan harness yang merah di sini mengajarkan bahwa gerbangnya
    # menolak pekerjaan, bukan menuntut kesepakatan.
    ("6. KEDUANYA diubah bersama, nilai sama (wajib hijau)",
     [(MODEL, MODEL_UH_OLD, MODEL_UH_NEW),
      (RENDER, PORT_UH_OLD, PORT_UH_NEW)],
     _full()),

    # ── Pengakuan menggantung: berhenti mengukur tanpa suara ─────────────
    # Ini cacat yang **paling berbahaya** dari ketiganya, dan yang paling
    # mudah lolos: mengganti nama fungsi di model membuat ketiga token
    # `URANUS_BAND_*` kehilangan sumbernya. Sebelum penjaga ini ada,
    # ketiganya menyusut dari himpunan hasil dan gerbangnya tetap **hijau**
    # sambil berhenti membandingkan tiga angka — tepat ketika modelnya
    # berubah, yaitu saat gerbang itu paling dibutuhkan.
    ("7. model: uranusBand diganti nama menjadi uranusStripe",
     [(MODEL, MODEL_ANCHOR_OLD, MODEL_ANCHOR_NEW)],
     {**{n: HIJAU for n in FULL
         if n not in (URANUS_CENTER_Y, URANUS_HALF_HEIGHT,
                      "model→port: URANUS_BAND_HALF_WIDTH[0] == model")},
      _punya_sumber("URANUS_BAND_CENTER_Y"): MERAH,
      _punya_sumber("URANUS_BAND_HALF_HEIGHT"): MERAH,
      _punya_sumber("URANUS_BAND_HALF_WIDTH"): MERAH}),
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
