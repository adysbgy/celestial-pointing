#!/usr/bin/env python3
"""Buktikan gerbang luruhan kutub Mars berbunyi — dan ukur cakupannya.

Kenapa harness ini ada.

`check_mars_caps_fade_into_the_surface` lahir bersama siklus ini, dan gerbang
baru yang hijau pada hari ia ditulis **tidak membuktikan apa pun**. Yang harus
dibuktikan: ia bisa merah atas cacat yang ia tulis untuk menangkap, hijau atas
gambar yang benar, dan tidak berbunyi atas pekerjaan yang benar.

### Kenapa gerbangnya perlu ada — diukur, bukan dibaca

Sampai siklus ini kutub Mars diisi **satu warna rata** di kedua penggambar
(`capColor.opacity(0.85)` di view, `accent_fn(…, POLAR_CAP_OPACITY)` di port),
jadi tepi **dalamnya** — batas elips yang menghadap ekuator — adalah langkah
yang sempurna. Diukur pada kolom tengah render 400 px
(`planet-mars-confirmed`, ss=2):

    tepi dalam kutub utara   111.5 luminans dalam satu piksel
    tepi dalam kutub selatan 139.7 luminans dalam satu piksel
    bola Mars di baris yang sama            0.9 luminans per piksel

Seluruh **210 pemeriksaan** di `check-visuals.py` hijau atas gambar itu —
termasuk `check_mars_caps_touch_the_limb`, yang mengukur tepi **luar** kutub.
Bukan gerbang yang tidak menyentuh kasusnya: tidak ada satu pun yang melihat
kolom tengah di sekitar tepi dalam.

### Arah luruhan: nilai sah, gambar salah

Perbaikannya adalah gradien — opasitas penuh di pusat kutub, meluruh ke nol di
tepi dalamnya. Yang **tidak bisa** dijaga uji Linux adalah **arahnya**: luruhan
yang terbalik menaruh tepi kaburnya di ujung kutub dan tepi tajamnya di
ekuator, dan setiap nilai opasitasnya tetap sah satu per satu. Terukur pada
mutasi itu: langkah tepi dalam kembali **111.5 / 139.7** — persis cacat lama —
sementara seluruh pemeriksaan lain tetap hijau. Karena itu yang diukur harness
ini bukan "apakah ada gradien", melainkan **arah yang terukur di piksel**.

### Yang diukur, bukan dikira-kira

Harness menjalankan gerbangnya di proses baru (mengimpor ulang
`check-visuals.py` dari berkas yang sudah dimutasi) dan membandingkan
**himpunan nama hasil yang dituntut**, bukan sekadar "ada yang merah".

  keadaan                                            hasil
  [baseline]                                         hijau
  1. port: warna kutub kembali rata                  MERAH 2 (kedua kutub)
       "kutub Mars utara/selatan luruh ke tepi dalamnya"
  2. port: arah luruhan DIBALIK                      MERAH 4
       kedua hasil "luruh ke tepi dalamnya" **dan** kedua hasil
       "lebih pekat ke arah kutubnya"
  3. model: jangkauan luruhan 0.45 -> 0.05           hijau (lihat di bawah)
  4. view: berhenti memakai gradien                  hijau (batas cakupan)
  5. kontrol negatif: komentar ditambahkan           hijau penuh

Keadaan 3 dan 4 adalah **batas cakupan yang dinyatakan**, bukan keluhan.
Keadaan 3 mengubah gambar di jam (luruhan jadi sempit) dan tetap hijau di sini:
gerbang ini menjaga **tepi dalam luruh dan arahnya**, bukan **panjang**
luruhannya. Keadaan 4 mengganti gradien view dengan warna rata — cacat yang
sama persis, di bahasa yang lain — dan tetap hijau, karena seluruh gerbang di
berkas ini mengukur **port Python**. Yang menjaga view adalah
`check_port_matches_swift_constants`; harness ini tidak mengklaim lebih.

### Batas lain yang tidak diklaim

  - Yang diukur gambar port. Tidak ada klaim bahwa perangkat Apple menggambar
    tepi dalam kutub dengan angka yang sama; yang dibuktikan adalah **port**
    menggambarnya berluruhan dan **ke arah yang benar**.
  - Ambang 25 luminans dipilih di antara dua keadaan yang diukur (luruh: 2.65
    / 3.57; rata dan terbalik: 111.5 / 139.7). Nilai di antaranya tidak
    diklaim — luruhan yang sangat pendek akan terbaca seperti tepi tajam dan
    itu memang tujuannya.
  - Tiga arah luruhan yang diklaim docstring model (0.45 / 0.55 / 0.60)
    **tidak** diuji di sini. Yang mengujinya uji Linux di `CelestialVisualTests`.

Berkas produksi dimutasi lalu dipulihkan di `finally` per keadaan, plus handler
`SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally` dan meninggalkan mutasi hidup.
`require_clean_sources` menolak jalan bila berkasnya sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-luruh-kutub.py    # 0 = sesuai harapan
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

VIEW = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")
MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

HIJAU = "hijau"
MERAH = "merah"

GATE = "check_mars_caps_fade_into_the_surface"

#: Empat hasil yang dituntut gerbangnya, dua per kutub.
LURUH = ["kutub Mars utara luruh ke tepi dalamnya",
         "kutub Mars selatan luruh ke tepi dalamnya"]
PEKAT = ["kutub Mars utara lebih pekat ke arah kutubnya",
         "kutub Mars selatan lebih pekat ke arah kutubnya"]

#: ── Jangkar sumber ──────────────────────────────────────────────────────
#: Arah luruhan di port: satu-satunya tempat `toward_pole` diberi tanda.
PORT_TOWARD_POLE = "    toward_pole = -1.0 if center < 0 else 1.0"
#: Blok penggantian warna rata di port, dari `alpha_fn` sampai `canvas.fill`.
PORT_SHADED = (
    '        alpha_fn = linear_gradient([(ACCENTS["marsPolarCap"], '
    'fade["edge_opacity"]),\n'
    '                                    (ACCENTS["marsPolarCap"], '
    'fade["full_opacity"])],\n'
    "                                   (cx, y0), (cx, y1))\n"
    "        # `color_fn` mengabaikan koordinatnya, jadi satu panggilan cukup "
    "untuk\n"
    "        # mengambil warna yang sudah dipetakan — tanpa menyalin "
    "pemetaannya.\n"
    '        cap_rgb, _ = accent_fn(ACCENTS["marsPolarCap"], night_mode, 1.0)'
    "(cx, cy)\n"
    "\n"
    "        def shaded(x, y, alpha_fn=alpha_fn, cap_rgb=cap_rgb):\n"
    '            _, alpha = alpha_fn(x, y)\n'
    "            return cap_rgb, alpha\n")
#: Bentuk warna rata yang menggantikannya — sama seperti sebelum siklus ini.
#:
#: **`cap(x, y)`, bukan `cap`.** `accent_fn` mengembalikan **fungsi**
#: (`color_fn`), dan di HEAD fungsi itulah yang dikirim ke `canvas.fill` sebagai
#: `color_at`. Versi pertama blok ini mengembalikan fungsinya utuh, dan
#: keadaannya mati dengan `TypeError: cannot unpack non-iterable function
#: object` di dalam `fill` — bukan merah yang mengukur gambar, melainkan probe
#: yang tidak pernah sampai ke gambar. Ditemukan pada jalannya yang **pertama**:
#: satu-satunya keadaan di harness ini yang gagal karena mutasinya sendiri, dan
#: ia terlihat justru karena harness ini menuntut hasil per nama, bukan sekadar
#: "ada yang merah".
PORT_FLAT = (
    '        cap = accent_fn(ACCENTS["marsPolarCap"], night_mode, '
    "POLAR_CAP_OPACITY)\n"
    "\n"
    "        def shaded(x, y, cap=cap):\n"
    "            return cap(x, y)\n")
#: Jangkauan luruhan di model: 0.45 -> 0.05 (luruhan hampir hilang).
MODEL_FADE_START = "    static let polarCapFadeStart: Double = 0.45"
#: Gradien di view: baris `stops` pertama. Menggantinya dengan warna rata
#: mengembalikan cacat lama **di view**, yang tidak dilihat gerbang mana pun
#: di berkas ini — lihat keadaan 4.
VIEW_GRADIENT = ("            inner.fill(Path(ellipseIn: rect),\n"
                 "                       with: .linearGradient(Gradient(stops: "
                 "stops),")

STATES = [
    ("[baseline] sumber bersih", None,
     {GATE: HIJAU, **{n: HIJAU for n in LURUH + PEKAT}}),

    # ── 1. Port kembali menggambar warna rata ────────────────────────────
    # Arah yang paling mungkin terjadi: seseorang menyunting penggambar port
    # dan mengembalikan opasitas konstan. Cacatnya kembali utuh — 111.5 dan
    # 139.7 luminans dalam satu piksel.
    #
    # Hanya kedua hasil "luruh ke tepi dalamnya" yang **dituntut** merah:
    # pemeriksaan pita ("lebih pekat ke arah kutubnya") juga merah, tapi
    # menuntutnya di sini akan mencampur dua besaran yang mengukur hal yang
    # berbeda. Keduanya wajib hijau di baseline, dan keadaan 2 yang
    # membuktikan keduanya bisa berbunyi bersama.
    ("1. port: warna kutub kembali rata", [
        (RENDER, PORT_SHADED, PORT_FLAT),
    ], {GATE: MERAH, **{n: MERAH for n in LURUH}}),

    # ── 2. Arah luruhan dibalik ──────────────────────────────────────────
    # Mutasi yang **paling penting** di harness ini: satu tanda. Semua nilai
    # opasitas tetap sah, seluruh uji Linux tetap hijau, dan seluruh 210
    # pemeriksaan lain di `check-visuals.py` tetap hijau — terukur. Yang
    # berubah hanya ujung mana yang kabur.
    #
    # Kedua besaran wajib merah, dan itu yang membuat keadaan ini berbeda dari
    # keadaan 1: di sini tepi dalamnya kembali tajam (111.5 / 139.7) **dan**
    # pita dalamnya justru lebih terang dari pita penuh.
    ("2. port: arah luruhan dibalik (satu tanda)", [
        (RENDER, PORT_TOWARD_POLE,
         "    toward_pole = 1.0 if center < 0 else -1.0"),
    ], {GATE: MERAH, **{n: MERAH for n in LURUH + PEKAT}}),

    # ── 3. Batas cakupan: panjang luruhan tidak dijaga ───────────────────
    # Jangkauan luruhan 0.45 -> 0.05: luruhannya jadi sangat pendek, dan
    # gambarnya **berubah** di jam. Gerbang ini tetap hijau, karena yang
    # dijaganya tepi dalam luruh dan arahnya — bukan panjangnya. Ditulis
    # sebagai keadaan **wajib hijau** supaya cakupan itu terbaca sebagai
    # pernyataan, bukan sebagai "gerbangnya ketinggalan".
    ("3. batas: jangkauan luruhan 0.45 -> 0.05 (tidak dijaga)", [
        (MODEL, MODEL_FADE_START, "    static let polarCapFadeStart: Double = 0.05"),
    ], {GATE: HIJAU, **{n: HIJAU for n in LURUH + PEKAT}}),

    # ── 4. Batas cakupan: view tidak diukur gerbang ini ──────────────────
    # Gradien di view diganti warna rata — cacat yang sama persis, di bahasa
    # yang lain. Seluruh gerbang di `check-visuals.py` mengukur port Python,
    # jadi keadaan ini hijau. Yang menjaga view adalah
    # `check_port_matches_swift_constants` (`let fade =
    # CelestialVisual.polarCapFade(cap: cap)`).
    ("4. batas: gradien view diganti warna rata (tidak dijaga)", [
        (VIEW, VIEW_GRADIENT,
         "            inner.fill(Path(ellipseIn: rect),\n"
         "                       with: .color(capColor.opacity(0.85)))"),
    ], {GATE: HIJAU, **{n: HIJAU for n in LURUH + PEKAT}}),

    # ── 5. Kontrol negatif: mekanisme pengukurannya sendiri ─────────────
    # Komentar yang menyebut angka ditambahkan di ujung baris jangkar. Kalau
    # keadaan ini memerah, yang rusak bukan kode produksi — dan seluruh
    # himpunan harapan di atas tidak berarti.
    ("5. kontrol negatif: komentar di ujung baris jangkar", [
        (RENDER, PORT_TOWARD_POLE,
         PORT_TOWARD_POLE + "  # arah: -1 ke kutub utara"),
    ], {GATE: HIJAU, **{n: HIJAU for n in LURUH + PEKAT}}),
]

PROBE = r"""
import importlib.util, os, sys

root = sys.argv[1]
names = [n for n in sys.argv[2].split(",") if n]

sys.path.insert(0, os.path.join(root, "Tools"))
sys.dont_write_bytecode = True


def load(mod, filename):
    path = os.path.join(root, "Tools", filename)
    spec = importlib.util.spec_from_file_location(mod, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[mod] = module
    spec.loader.exec_module(module)
    return module


try:
    C = load("cv_probe", "check-visuals.py")
except BaseException as exc:
    print("ERR <import>: " + type(exc).__name__ + ": " + str(exc)[:400])
    raise SystemExit(0)

for name in names:
    fn = getattr(C, name, None)
    if fn is None:
        print("ERR " + name + ": gerbang tidak ada")
        continue
    results = []
    try:
        fn(results)
    except BaseException as exc:
        print("ERR " + name + ": " + type(exc).__name__ + ": " + str(exc)[:300])
        continue
    if not results:
        # Bukan hijau: gerbang yang tidak mengembalikan hasil tidak mengukur
        # apa pun, dan himpunan kosong harus terlihat.
        print("KOSONG " + name)
        continue
    ok = all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + "  " + str(r.name) + "  | " +
              str(r.detail))
"""


def run_probe(gate_names):
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT,
                          ",".join(gate_names)],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, (out.stderr or out.stdout).strip()[-1200:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("ERR "):
            return None, line
        if line.startswith("KOSONG "):
            verdicts[line.split(" ", 1)[1]] = "kosong"
            continue
        state, rest = line.split(" ", 1)
        name = rest.split("  | ")[0].strip()
        verdicts[name] = HIJAU if state == "OK" else MERAH
    return verdicts, None


def verify_anchors(edits, label):
    """Setiap jangkar harus muncul **persis sekali** di berkasnya."""
    problems = []
    for path, find, _replace in edits:
        text = open(path, encoding="utf-8").read()
        hits = text.count(find)
        if hits != 1:
            problems.append(f"{label}: jangkar muncul {hits}x (butuh 1) di "
                            f"{os.path.basename(path)}: {find[:70]!r}")
    return problems


def main():
    mutasi_sumber.require_clean_sources([VIEW, MODEL, RENDER])
    originals = {path: open(path, "rb").read() for path in (VIEW, MODEL, RENDER)}
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
        for label, edits, expected in STATES:
            restore()
            if edits:
                problems = verify_anchors(edits, label)
                if problems:
                    failures.extend(problems)
                    print(f"{label}: JANGKAR TIDAK TERBACA")
                    for item in problems:
                        print(f"    {item}")
                    continue
                for path, find, replace in edits:
                    text = open(path, encoding="utf-8").read()
                    mutasi_sumber.write_source(path, text.replace(find, replace))

            verdicts, error = run_probe([n for n in expected
                                         if n.startswith("check_")])
            if verdicts is None:
                failures.append(f"{label}: probe gagal: {error}")
                print(f"{label}: PROBE GAGAL\n{error}")
                continue

            # **Subset, bukan kesamaan persis.** Harapan tiap keadaan menyebut
            # hasil yang **menangkap** arah mutasinya, bukan seluruh isi
            # gerbang. Yang tetap tidak bisa lolos: nama yang diharapkan
            # hilang, verdict yang salah, dan gerbang yang mengembalikan nol
            # hasil (dilaporkan `KOSONG` dan menjadi hasil hilang di sini).
            problems = []
            missing = sorted(set(expected) - set(verdicts))
            if missing:
                problems.append(f"hasil hilang: {missing}")
            wrong = [(n, expected[n], verdicts[n]) for n in sorted(expected)
                     if n in verdicts and verdicts[n] != expected[n]]
            if wrong:
                problems.append("verdict salah: " + "; ".join(
                    f"{n} diharapkan {w}, terukur {g}" for n, w, g in wrong))

            if problems:
                failures.append(f"{label}: " + " | ".join(problems))
                print(f"{label}: TIDAK SESUAI HARAPAN")
                for item in problems:
                    print(f"    {item}")
            else:
                red = sum(1 for v in verdicts.values() if v == MERAH)
                merah = [n for n, v in sorted(verdicts.items())
                         if v == MERAH and n.startswith("check_")]
                print(f"{label}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} hasil)" +
                      (f" — merah: {', '.join(merah)}" if merah else ""))
    finally:
        restore()

    print()
    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        state = "pulih persis" if after == digest else "TIDAK PULIH"
        print(f"md5 {os.path.relpath(path, ROOT)}: {digest} -> {after} ({state})")
        if after != digest:
            failures.append(f"berkas tidak pulih: {path}")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
