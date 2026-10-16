#!/usr/bin/env python3
"""Buktikan gerbang **keterbacaan ciri planet di ukuran jam** berbunyi.

Kenapa harness ini ada.

Tujuh ciri planet punya bukti geometris pada 38 pt
(`check_features_survive_the_watch_size`), tetapi syaratnya `diff > 0` — satu
piksel berbeda pun lolos. Dua ciri (bintik Jupiter, celah Saturnus) punya
gerbang kekuatan sendiri. Untuk **kutub Mars** dan **kawah Merkurius** tidak
ada satu pun yang mengukur seberapa kuat cirinya pada ukuran yang
benar-benar tampil: terukur, ciri yang tinggal sepersepuluh kekuatannya
tetap hijau di seluruh berkas pemeriksa.

`check_unreadable_features_never_pass_the_watch_size` menutup celah itu, dan
harness ini membuktikan gerbang tersebut **bisa merah** — tanpa itu, ia tidak
bisa dibedakan dari gerbang yang tidak mengukur apa pun.

### Yang diukur harness ini, bukan dikutip dari docstring

    [baseline]                                     hijau, 0 merah / 2
    1. kutub Mars tidak digambar                   MERAH 1 (kutub Mars), Merkurius hijau
    2. kabut Venus tidak digambar                  hijau penuh  ← Venus tidak diklaim
    3. kawah Merkurius tidak digambar              MERAH 1 (Merkurius), Mars hijau
    4. kutub Mars digambar terlalu pudar (0,02x)   MERAH 1 (kutub Mars)
    5. kontrol negatif: prosa lain diubah          hijau penuh

**Skala 0,12x pada keadaan 4 pernah salah dan menutupi cacatnya sendiri.**
Terukur, deviasi kutub Mars adalah 107,54% di produksi; 0,12x hanya
menurunkannya ke 12,91% — masih di atas ambang 3,0, jadi keadaan itu hijau
padahal harapannya MERAH, dan `Engine Tests (Linux)` merah satu siklus penuh.
0,02x (2,15%) adalah skala terkecil yang **diukur** masih membedakan "pudar"
dari "hilang" sambil benar-benar melewati ambang. Angka lengkapnya ada di
komentar keadaan 4.

Keadaan 1 dan 3 tidak saling menggantikan: keduanya mematikan **ciri yang
berbeda**, dan harness menuntut himpunan hasilnya **persis** — mencabut satu
ciri harus memerahkan **satu** hasil saja. Gerbang yang memakai metrik
"selisih seluruh piringan" akan memerahkan keduanya sekaligus di sini, dan
itu terlihat sebagai himpunan yang tidak sesuai harapan.

Keadaan 4 adalah arah yang paling penting, dan yang paling tidak bisa
digantikan keadaan 1: cirinya **tetap digambar, tetap utuh secara geometris**,
hanya kontrasnya jatuh ke 0,12x. Gerbang yang hanya memeriksa "ada bedanya
atau tidak" hijau di sini; gerbang yang mengukur **kekuatan** memerah. Itulah
seluruh alasan gerbang ini ada.

Keadaan 2 dinyatakan sebagai hijau dengan sengaja. Kabut Venus **tidak**
diklaim gerbangnya, karena dengan pembanding `-no-feature` pun menghapusnya
tidak menggerakkan skornya (geometri `venusHaze()` menutupi hampir seluruh
piringan, jadi angkanya milik gradien bola). Kalau kelak seseorang memasukkan
Venus kembali ke daftar kasus tanpa memperbaiki metriknya, keadaan 2 mulai
tidak sesuai harapan — dan itu memang yang harus terjadi.

Negatif kontrol (5) bukan hiasan: kalau harness merah di sana, ia merah karena
**berkasnya berubah**, bukan karena cirinya hilang, dan ia tidak mengukur apa
pun.

### Kenapa mutasinya di `render-visuals.py`

Gerbang membaca gambar dari port render. Yang dibuktikan karena itu adalah
**gambar yang dipakai gerbang memang berubah saat cirinya hilang** — bukan
bahwa view Swift menggambarnya. View Swift dijaga gerbang lint dan gerbang
geometris yang lain; batas itu dinyatakan di docstring gerbangnya sendiri.

Berkas produksi dimutasi lalu dipulihkan di `finally`, plus handler
`SIGINT`/`SIGTERM`. `require_clean_sources` menolak jalan bila berkas
produksi sudah menyimpang dari HEAD.

### Yang TIDAK diklaim

- Harness ini tidak membaca piksel app Apple, dan tidak membuktikan bahwa
  76 px adalah ukuran yang dipakai perangkat — itu klaim
  `WatchMetrics.visualDiameter`, dijaga gerbang lain.
- **Mode malam tidak diukur.** Kontras kutub Mars di sana turun 3,4x karena
  `NightVisual` memetakan semua warna ke kanal merah, dan itu keputusan yang
  sengaja dipilih repo ini. Gerbang yang memerah pada perilaku yang sengaja
  dipilih akan dilonggarkan orang, jadi ia tidak dipasang.
- Ia tidak mengukur Jupiter/Saturnus (punya gerbang sendiri) maupun
  Uranus/Neptunus (tidak punya ciri pengenal di palet).

Pakai:
    python3 Tools/bukti-mutasi-ciri-terbaca.py   # 0 = sesuai harapan
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

RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

HIJAU = "hijau"
MERAH = "merah"

#: Nama hasil di dalam gerbang, dituntut **persis** supaya perubahan nama
#: tidak terbaca sebagai "gerbangnya masih ada".
MARS = "kutub Mars terbaca pada 76 px (ukuran jam)"
MERKURIUS = "kawah Merkurius terbaca pada 76 px (ukuran jam)"

# ── Jangkar: potongan yang benar-benar ada di `render-visuals.py` ──────────
# Jumlah kemunculannya diperiksa sebelum memutasi; jangkar yang meleset
# dilaporkan sebagai kelemahan bukti, bukan dipakai diam-diam.
MARS_CALL = "        _draw_polar_caps(canvas, cx, cy, radius, night_mode)\n"
VENUS_CALL = ("            canvas.ellipse(cx, cy + radius * center_y, "
              "radius * half_w, radius * half_h, haze_clipped)\n")
MERKURIUS_CALL = "        _draw_craters(canvas, cx, cy, radius, night_mode)\n"
PROSA = "# **Bola dulu, dengan radius penuh"

# Dijalankan di proses baru: mengimpor ulang `check-visuals` dari berkas yang
# **sudah dimutasi** di disk. Mengimpor sekali di dalam proses ini akan
# memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))

path = os.path.join(sys.argv[1], "Tools", "check-visuals.py")
spec = importlib.util.spec_from_file_location("cv_probe", path)
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)

results = []
try:
    C.check_unreadable_features_never_pass_the_watch_size(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:200])
    raise SystemExit(0)

for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
    print("     " + r.detail)
"""

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama hasil: harapan})
STATES = [
    ("[baseline] berkas bersih", None,
     {MARS: HIJAU, MERKURIUS: HIJAU}),

    # ── 1. Kutub Mars hilang sama sekali ─────────────────────────────────
    # Keadaan yang gerbangnya ada untuk menangkap. Kalau hijau di sini,
    # gerbangnya tidak menjaga apa pun.
    ("1. kutub Mars tidak digambar",
     [(RENDER, MARS_CALL, "        pass  # MUT: kutub Mars hilang\n")],
     {MARS: MERAH, MERKURIUS: HIJAU}),

    # ── 2. Kabut Venus hilang — dan itu harus tetap hijau ────────────────
    # Venus sengaja **tidak** diklaim gerbangnya (metriknya tidak bergerak;
    # lihat docstring gerbang). Keadaan ini mengunci keputusan itu: kalau
    # Venus dimasukkan kembali tanpa memperbaiki metrik, ia memerah di sini.
    ("2. kabut Venus tidak digambar (tidak diklaim)",
     [(RENDER, VENUS_CALL, "            pass  # MUT: kabut Venus hilang\n")],
     {MARS: HIJAU, MERKURIUS: HIJAU}),

    # ── 3. Kawah Merkurius hilang sama sekali ────────────────────────────
    # Ciri yang berbeda, jadi hasil yang memerah pun harus berbeda. Gerbang
    # bermetrik "seluruh piringan" akan memerahkan Mars juga di sini.
    ("3. kawah Merkurius tidak digambar",
     [(RENDER, MERKURIUS_CALL, "        pass  # MUT: kawah Merkurius hilang\n")],
     {MARS: HIJAU, MERKURIUS: MERAH}),

    # ── 4. Ciri digambar, tetapi terlalu pudar ───────────────────────────
    # Arah ini yang tidak bisa digantikan keadaan 1: geometrinya utuh, hanya
    # kontrasnya jatuh. Gerbang "ada bedanya?" hijau di sini — dan justru
    # itulah celah yang ditutup gerbang ini. Opasitasnya diambil dari
    # `polar_cap_fade(...)`, jadi mutasinya menskalakan keduanya.
    #
    # **Skalanya 0,02x, dan angka itu diukur, bukan dipilih.** Versi pertama
    # memakai 0,12x dengan alasan "sepersepuluh kekuatan" — dan itu **salah**:
    # terukur di gerbangnya sendiri, deviasi kutub Mars pada 76 px adalah
    # 107,54% di produksi, dan 0,12x hanya menurunkannya ke **12,91%** —
    # masih 4,3x di atas ambang 3,0, jadi keadaan itu **hijau** padahal
    # harapannya MERAH. Harness-nya merah pada sumber bersih, dan itulah
    # sebab `Engine Tests (Linux)` merah satu siklus penuh.
    #
    # Diukur ulang untuk mencari skala yang benar-benar melewati ambang:
    #     1,00x -> 107,54%   hijau
    #     0,12x ->  12,91%   hijau   <- harapan lama, salah
    #     0,03x ->   3,21%   hijau   (masih di atas ambang)
    #     0,02x ->   2,15%   MERAH   <- dipakai di sini
    #     0,01x ->   1,09%   MERAH
    # 0,02x dipilih karena ia **di bawah** ambang dengan margin yang cukup
    # untuk tidak bergantung pada pembulatan satu piksel, tetapi masih jauh
    # dari nol — jadi ia tetap membedakan "pudar" dari "hilang" (keadaan 1).
    ("4. kutub Mars digambar terlalu pudar (0,02x)",
     [(RENDER, '        fade = polar_cap_fade(caps, center)\n',
       '        _f = polar_cap_fade(caps, center)  # MUT: pudarkan kutub\n'
       '        fade = {"inner_edge_y": _f["inner_edge_y"],\n'
       '                "full_y": _f["full_y"],\n'
       '                "edge_opacity": _f.get("edge_opacity", 0.0) * 0.02,\n'
       '                "full_opacity": _f.get("full_opacity", 0.0) * 0.02}\n')],
     {MARS: MERAH, MERKURIUS: HIJAU}),

    # ── 5. Kontrol negatif: prosa yang tidak dibaca gerbang ──────────────
    # Harus hijau penuh: kalau merah, harness merah karena berkasnya berubah,
    # bukan karena cirinya hilang.
    ("5. kontrol negatif: prosa lain diubah",
     [(RENDER, PROSA, "# **Bola dulu, dengan radius penuh!**")],
     {MARS: HIJAU, MERKURIUS: HIJAU}),
]


def run_probe():
    """Jalankan gerbang di proses baru. -> (stdout atau None, galat)."""
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    return out.stdout, None


def classify(stdout):
    """Petakan keluaran prob -> {nama hasil: hijau|merah}."""
    verdicts = {}
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("ERR"):
            continue
        state, _, name = stripped.partition(" ")
        name = name.strip()
        if state in ("OK", "GAGAL") and name:
            verdicts[name] = HIJAU if state == "OK" else MERAH
    return verdicts


def main():
    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        mutasi_sumber.restore_verified(RENDER, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, want in STATES:
            restore()
            if edits is not None:
                pending = {}
                broken = False
                for path, find, replace in edits:
                    content = pending.get(path, original.decode())
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: "
                            f"{find[:70]!r}")
                        broken = True
                        break
                    pending[path] = content.replace(find, replace)
                if broken:
                    continue
                for path, content in pending.items():
                    mutasi_sumber.write_source(path, content)

            stdout, error = run_probe()
            if stdout is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            verdicts = classify(stdout)

            # Himpunan hasilnya dituntut **persis**: hasil yang hilang dan
            # hasil yang muncul tiba-tiba keduanya bagian dari bukti.
            missing = sorted(set(want) - set(verdicts))
            if missing:
                failures.append(
                    f"{name}: hasil tidak dihasilkan gerbang: {missing}")

            wrong = {k: (verdicts.get(k, "TIDAK ADA"), v)
                     for k, v in want.items()
                     if verdicts.get(k, "TIDAK ADA") != v}
            if wrong:
                failures.append(f"{name}: tidak sesuai harapan: {wrong}")

            ok = not missing and not wrong
            detail = ""
            for line in stdout.splitlines():
                if line.startswith("     "):
                    detail = line.strip()
            print(f"{name}: "
                  + ("sesuai harapan" if ok else "TIDAK SESUAI HARAPAN")
                  + (f" ({detail})" if detail else ""))
    finally:
        restore()

    after = hashlib.md5(open(RENDER, "rb").read()).hexdigest()
    print(f"\nmd5 Tools/render-visuals.py: {baseline_md5} -> {after} "
          f"({'pulih persis' if after == baseline_md5 else 'TIDAK PULIH'})")
    if after != baseline_md5:
        failures.append("sumber produksi tidak pulih persis: "
                        "Tools/render-visuals.py")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
