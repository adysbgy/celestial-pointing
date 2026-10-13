#!/usr/bin/env python3
"""Buktikan gerbang **kekuatan earthshine** berbunyi, bukan sekadar hijau.

Kenapa harness ini ada.

`Tools/render-visuals.py` menulis, di komentarnya sendiri, bahwa kekuatan
earthshine "mengikuti `1 - f` (sama seperti
`CelestialVisual.earthshineStrength` di Swift)". Kalimat itu **klaim**, dan
sampai siklus ini tidak ada satu pun gerbang yang menjaganya.

Diukur, bukan diwarisi dari STATUS.md (`Tools/ukur-earthshine.py`):

    [baseline]                                  0 dari 8 gerbang Bulan
    1. model `1 - f` -> `(1 - f) * 0.5`         0 dari 8 gerbang Bulan
    2. model `1 - f` -> `f`                     0 dari 8 gerbang Bulan

Nol. Sebabnya kelas yang sudah dibayar repo ini berkali-kali: setiap gerbang
Bulan mengukur **gambar port**, dan port-nya tidak ikut berubah. Yang
menyimpang adalah **view**, yang memanggil fungsinya — jadi yang diuji di
Linux dan yang tampil di jam perlahan-lahan menjadi dua Bulan berbeda,
sementara kedua sisi hijau.

Tiga arah, dan ketiganya diukur di sini karena masing-masing punya jalan
berbeda menuju kesalahan:

  * **model** berubah, port tidak ikut  (arah yang paling mungkin terjadi)
  * **port** berubah, model tidak ikut
  * **view** berhenti memakai namanya    (hanya gerbang teks bisa melihatnya)

Keadaan 3 adalah yang paling berharga, dan itu **diukur**: mengganti
pemanggilan di view dengan `1.0 - (visual.illuminationFraction ?? 0)`
menghasilkan **0 merah di seluruh 8 gerbang Bulan**. Gambarnya identik hari
ini; yang hilang hanya ikatannya. Tanpa keadaan ini, harness akan melaporkan
bahwa gerbangnya menutup kelas cacat yang sebenarnya masih terbuka.

Keadaan 5 adalah kontrol negatif, dan ia bukan hiasan: **kedua bahasa
diubah bersama** ke rumus yang sama. Di situ tidak ada penyimpangan, jadi
gerbang ini **wajib hijau** — kalau ia memerah, ia sedang memerah pada kode
yang benar, dan orang akan mematikannya.

Keadaan 5 juga membawa **klaim yang dikoreksi**. Versi pertama docstring
gerbangnya menyatakan `check_earthshine` yang menangkap "dua bahasa
sepakat sama-sama salah" (dengan angka "5 merah"). Diukur ulang: **salah** —
`check_earthshine` hijau seluruhnya pada keadaan itu, karena ambangnya
berbasis nisbah dan longgar. Yang benar-benar menangkapnya adalah uji Swift
`testEarthshineOnlyOnPartiallyLitMoon` (terukur: 3 assertion merah). Karena
itu keadaan 5 **menjalankan uji itu** dan menuntutnya gagal; kalau tidak,
harness ini hanya akan mencatat batas cakupan tanpa membuktikan bahwa ada
yang menutupnya.

Berkas sumber produksi dimutasi dengan sengaja lalu dipulihkan di `finally`
per keadaan, plus handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally`
dan meninggalkan mutasi hidup. Penulisan & pemulihannya lewat `mutasi_sumber`,
sama seperti harness lain — dan `require_clean_sources` menolak jalan kalau
berkas produksi sudah menyimpang dari HEAD.

Pakai:
    python3 Tools/bukti-mutasi-earthshine.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import shutil
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                           "CelestialVisual.swift")
VIEW = os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")
RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

#: Uji Swift yang menangkap rumus yang sama-sama salah di kedua bahasa.
#: Dijalankan sungguhan di keadaan 5 — lihat catatan di docstring modul.
SWIFT_TEST = "testEarthshineOnlyOnPartiallyLitMoon"

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

def load(name, filename):
    path = os.path.join(sys.argv[1], "Tools", filename)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

C = load("cv_probe", "check-visuals.py")

# Hijau tingkat fungsi = pemeriksaannya **ada** DAN semuanya lolos. Himpunan
# kosong sengaja **bukan** hijau: gerbang yang hijau karena tidak mengukur
# apa pun adalah kelas cacat yang seluruh repo ini kejar.
for name in sys.argv[2].split(","):
    results = []
    try:
        getattr(C, name)(results)
    except Exception as exc:
        print("ERR " + name + " " + type(exc).__name__ + ": " + str(exc)[:200])
        continue
    ok = bool(results) and all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

# ── Jangkar ──────────────────────────────────────────────────────────────
# Semuanya unik; harness memeriksa jumlah kemunculannya sebelum memutasi, jadi
# jangkar yang menjadi ambigu dilaporkan sebagai kelemahan bukti, bukan
# dipakai diam-diam.
#
# **`MODEL_CLAMP` sempat salah tempat, dan itu diukur.** Versi pertamanya
# memakai `let clamped = min(1, max(0, fraction))` — unik di berkas, tapi
# milik `terminatorRotationRadians` (baris 431), **bukan**
# `earthshineStrength` (baris 463) yang menulis `let f = min(1, max(0, …))`.
# Akibatnya keadaan 4 memutasi fungsi yang salah, gerbangnya tetap hijau, dan
# harness melaporkan "sesuai harapan" untuk alasan yang sama sekali lain.
# Jangkar yang benar diambil dari **badan fungsi yang diukur**, bukan dari
# bentuk yang kebetulan mirip di tempat lain.
MODEL_FORMULA = "        return 1 - f\n"
MODEL_CLAMP = "        let f = min(1, max(0, fraction))\n"
PORT_FORMULA = "    return 1 - f\n"
PORT_CLAMP = "    f = min(1, max(0, fraction))\n"
PORT_USE = "        strength = earthshine_strength(f)\n"
VIEW_CALL = ("        let earthshine = CelestialVisual.earthshineStrength(\n"
             "            illuminationFraction: visual.illuminationFraction ?? 0)")

GATE = "check_earthshine_strength_matches_the_model"
EARTHSHINE = "check_earthshine"

HIJAU = "hijau"
MERAH = "merah"

ALL = ",".join((GATE, EARTHSHINE))

# Nama pemeriksaan di dalam gerbang, supaya harness bisa menuntut **yang mana**
# berbunyi, bukan sekadar "ada yang merah". Dua arah yang berbeda yang
# menyalakan pemeriksaan yang sama berarti separuh gerbangnya mubazir.
#
# Nama-nama ini diambil dari gerbang **yang ada sekarang**, bukan dari versi
# pertamanya: gerbang itu ditulis ulang dari "membandingkan bentuk tulisan
# rumus" menjadi "membandingkan nilainya di titik uji", dan nama lama
# (`offset sama`, `clamp_high sama`) tidak lagi dihasilkan siapa pun — harness
# yang menuntutnya akan melaporkan "TIDAK ADA" dan menyalahkan gerbangnya.
SAMA = "earthshine: nilai sama di model dan port (seluruh titik uji)"
CLAMP_ATAS = "earthshine: penjepit batas atas sama di model dan port"
CLAMP_BAWAH = "earthshine: penjepit batas bawah sama di model dan port"
PORT_NAMED = "earthshine: port memakai fungsinya sendiri (bukan literal)"
VIEW_NAMED = "earthshine: view memakai fungsi model (bukan literal)"
VIEW_HAND = "earthshine: view tidak menghitung rumusnya sendiri"
RANGE = "earthshine: penjepit tetap 0…1"

# (nama keadaan, [(berkas, cari, ganti), ...] atau None, {nama: harapan})
STATES = [
    ("[baseline] berkas bersih", None,
     {GATE: HIJAU, EARTHSHINE: HIJAU}),

    # ── 1. Model berubah, port tidak ikut ────────────────────────────────
    #
    # Arah yang paling mungkin di dunia nyata: yang memperbaiki tampilan
    # Bulan menyunting **model** di Mac, bukan port Python di Linux. Sebelum
    # gerbang ini, keadaan ini menghasilkan nol merah di delapan gerbang
    # Bulan.
    #
    # `check_earthshine` sengaja diharapkan **hijau**: ia mengukur gambar
    # port, dan port-nya memang tidak berubah. Kalau ia ikut memerah, kedua
    # gerbang sedang mengukur hal yang sama — dan salah satunya tidak
    # menjaga apa pun.
    ("1. model `1 - f` -> `(1 - f) * 0.5`, port tidak ikut",
     [(MODEL, MODEL_FORMULA, "        return (1 - f) * 0.5\n")],
     {GATE: MERAH, SAMA: MERAH, EARTHSHINE: HIJAU}),

    # ── 2. Port berubah, model tidak ikut ────────────────────────────────
    #
    # Arah sebaliknya, dan di sini satu **batas cakupan** yang nyata
    # terukur: `check_earthshine` tetap **hijau**. Bukan cacat gerbangnya —
    # docstringnya sendiri menyatakan rasionya sengaja longgar — melainkan
    # batas yang perlu dinyatakan supaya tidak disangka tertutup.
    #
    # Terukur dengan `Tools/ukur-es-piksel.py` (luminans sisi gelap sabit
    # f=0.15, skala 0–255): earthshine **dihapus** → 33.6, sama dengan
    # `moonUnlit` (MERAH); **separuh** → 52.8 (HIJAU); **penuh** → 78.2
    # (MERAH pada arah "lebih kuat pada sabit tipis"). Jadi gerbang piksel
    # itu menangkap "tidak digambar" dan "menyala penuh", tetapi **tidak**
    # menangkap separuh kekuatan.
    ("2. port `1 - f` -> `0.5 * (1 - f)`, model tidak ikut",
     [(RENDER, PORT_FORMULA, "    return 0.5 * (1 - f)\n")],
     {GATE: MERAH, SAMA: MERAH, EARTHSHINE: HIJAU}),

    # ── 2b. Batas itu punya batas: gerbang pikselnya tidak mubazir ───────
    #
    # Tanpa keadaan ini, "check_earthshine hijau di keadaan 2" bisa dibaca
    # sebagai gerbang piksel yang tidak mengukur apa pun. Diukur: earthshine
    # yang **dihapus** memerahkannya di dua pemeriksaan sekaligus.
    ("2b. port: earthshine dihapus (`return 0.0`)",
     [(RENDER, PORT_FORMULA, "    return 0.0\n")],
     {GATE: MERAH, SAMA: MERAH, EARTHSHINE: MERAH}),

    # ── 3. View berhenti memakai namanya ─────────────────────────────────
    #
    # Bentuk yang **hanya** gerbang teks bisa lihat, dan alasan keadaan ini
    # ada. Diukur: mengganti pemanggilan dengan
    # `1.0 - (visual.illuminationFraction ?? 0)` menghasilkan 0 merah di
    # seluruh 8 gerbang Bulan. Gambarnya identik hari ini; yang hilang cuma
    # ikatannya — persis kelas cacat yang sudah dibayar `bukti-mutasi-jangkauan-corona.py`
    # keadaan 5 untuk `sunCoronaReach`.
    ("3. view menghitung sendiri `1.0 - …`, bukan memanggil",
     [(VIEW, VIEW_CALL,
       "        let earthshine = 1.0 - (visual.illuminationFraction ?? 0)")],
     {GATE: MERAH, VIEW_NAMED: MERAH, VIEW_HAND: MERAH,
      SAMA: HIJAU, EARTHSHINE: HIJAU}),

    # ── 4. Penjepit bergeser keluar 0…1 (di model) ───────────────────────
    #
    # Kedua bahasa tidak lagi sepakat, jadi pemeriksaan kesamaan nilai dan
    # batas atas **ikut** berbunyi — dan pemeriksaan rentang juga, karena
    # penjepit model-nya sendiri sudah keluar dari 0…1. Penjepit 0…2 membuat
    # kekuatan earthshine bisa melebihi 1 (memutihkan sisi gelap), dan tidak
    # ada gerbang piksel yang menuntut itu.
    ("4. model: penjepit 0…1 -> 0…2",
     [(MODEL, MODEL_CLAMP, "        let f = min(2, max(0, fraction))\n")],
     {GATE: MERAH, SAMA: MERAH, CLAMP_ATAS: MERAH, RANGE: MERAH,
      CLAMP_BAWAH: HIJAU, EARTHSHINE: HIJAU}),

    # ── 4b. Penjepit bergeser di **port**, model tidak ikut ──────────────
    #
    # Arah cermin dari keadaan 4, dan bukan pengulangan: di sini pemeriksaan
    # **rentang** justru hijau, karena rentang itu dibaca dari **model** —
    # yang memang masih benar. Yang berbunyi adalah kesamaan nilai dan batas
    # atas. Tanpa keadaan ini, "rentang" dan "kesamaan" tidak terbukti
    # mengukur dua hal yang berbeda; dengan dia, keduanya terpisah jelas:
    # 4 menyalakan keduanya, 4b hanya menyalakan kesamaannya.
    ("4b. port: penjepit 0…1 -> 0…2",
     [(RENDER, PORT_CLAMP, "    f = min(2, max(0, fraction))\n")],
     {GATE: MERAH, SAMA: MERAH, CLAMP_ATAS: MERAH, RANGE: HIJAU,
      CLAMP_BAWAH: HIJAU, EARTHSHINE: HIJAU}),

    # ── 5. Kontrol negatif: kedua bahasa sepakat, dan yang menangkap uji ─
    #
    # Model DAN port diubah bersama ke rumus yang sama. Tidak ada
    # penyimpangan, jadi gerbang ini **wajib hijau** — dan itu penting,
    # karena gerbang yang memerah pada kode yang benar akan dilonggarkan
    # orang, dan gerbang yang dilonggarkan tidak menjaga apa pun.
    #
    # Keadaan ini juga yang membuktikan gerbangnya mengukur **penyimpangan**,
    # bukan nilainya: rumusnya jelas berbeda dari `1 - f`, dan gerbangnya
    # diam.
    #
    # **Dan di sinilah klaim lama dikoreksi.** Docstring versi pertama
    # menyatakan `check_earthshine` yang menangkap keadaan ini. Diukur:
    # tidak — `check_earthshine` hijau seluruhnya di sini. Yang menangkapnya
    # uji Swift, jadi uji itu dijalankan sungguhan dan dituntut gagal
    # (`swift_check=True`). Kalau uji itu berhenti menjaga, keadaan ini
    # memerah dan ketahuan.
    ("5. kedua bahasa `1 - f` -> `1 - 0.5 * f` (sepakat, sama-sama salah)",
     [(MODEL, MODEL_FORMULA, "        return 1 - 0.5 * f\n"),
      (RENDER, PORT_FORMULA, "    return 1 - 0.5 * f\n")],
     {GATE: HIJAU, EARTHSHINE: HIJAU}, True),
]


def run_probe(checks):
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, checks],
                         capture_output=True, text=True, timeout=1800)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        state, name = line.split(" ", 1)
        verdicts[name.strip()] = "hijau" if state == "OK" else "merah"
    return verdicts, None


def swift_catches_it():
    """Jalankan uji Swift yang menangkap rumus itu. → (dijalankan, gagal, pesan).

    `swift` dipakai langsung bila ada di PATH (itulah yang terjadi di CI, yang
    berjalan di dalam citra `swift:6.0`). Di VPS ini tidak ada Swift, hanya
    Docker — jadi jalur keduanya memakai citra yang sama lewat `swift-test.sh`
    supaya yang diukur tetap toolchain yang sama.

    **Kenapa dijalankan, bukan dikutip.** Klaim "uji ini yang menangkapnya"
    adalah klaim tentang **perilaku**, dan klaim perilaku yang tidak dijalankan
    akan tetap tertulis di docstring walau ujinya kelak dilonggarkan. Yang
    dibuktikan di sini adalah arah yang mudah hilang: ujinya masih berbunyi
    saat rumusnya salah.
    """
    if shutil.which("swift"):
        cmd = ["swift", "test", "--package-path", "Packages/PointingKit",
               "--filter", SWIFT_TEST]
        how = "swift langsung"
    elif shutil.which("docker"):
        cmd = ["sudo", "-n", "docker", "run", "--rm", "-v", f"{ROOT}:/src",
               "-w", "/src/Packages/PointingKit", "swift:6.0",
               "swift", "test", "--filter", SWIFT_TEST]
        how = "docker swift:6.0"
    else:
        return False, False, "dilewati: tidak ada `swift` maupun `docker`"

    out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                         timeout=1800)
    text = (out.stdout or "") + (out.stderr or "")
    failed = out.returncode != 0 and SWIFT_TEST in text
    detail = (f"{how}: {'gagal seperti dituntut' if failed else 'LULUS'}"
              f" (exit {out.returncode})")
    if not failed:
        tail = [l for l in text.splitlines() if "error:" in l][:3]
        detail += "; " + (" | ".join(tail) if tail else text.strip()[-300:])
    return True, failed, detail


def main():
    files = [MODEL, VIEW, RENDER]
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
        for state in STATES:
            name, edits, expected = state[0], state[1], state[2]
            swift_check = len(state) > 3 and state[3]
            restore()
            if edits is not None:
                # Mutasi dikumpulkan per berkas supaya beberapa suntingan di
                # berkas yang sama tidak saling menimpa.
                pending = {}
                for path, find, replace in edits:
                    content = pending.get(path, originals[path].decode())
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: {find[:70]!r}")
                        break
                    pending[path] = content.replace(find, replace)
                else:
                    for path, content in pending.items():
                        mutasi_sumber.write_source(path, content)

            verdicts, error = run_probe(ALL)
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            wrong = [(check, want, verdicts.get(check, "TIDAK ADA"))
                     for check, want in expected.items()
                     if verdicts.get(check, "TIDAK ADA") != want]
            for check, want, got in wrong:
                failures.append(f"{name}: {check!r} diharapkan {want}, "
                                f"terukur {got}")

            # Uji Swift dijalankan **sebelum** pemulihan, atas model yang
            # masih termutasi.
            swift_note = ""
            swift_ok = True
            if swift_check:
                ran, caught, detail = swift_catches_it()
                swift_note = f" | uji Swift: {detail}"
                swift_ok = ran and caught
                if not ran:
                    failures.append(f"{name}: {detail}")
                elif not caught:
                    failures.append(
                        f"{name}: {SWIFT_TEST} tidak lagi menangkap rumusnya "
                        f"({detail})")

            if wrong or not swift_ok:
                print(f"{name}: TIDAK SESUAI HARAPAN")
                for check, want, got in wrong:
                    print(f"    {check}\n      diharapkan {want}, terukur {got}")
                if not swift_ok:
                    print(f"    uji Swift{swift_note}")
            else:
                red = sum(1 for v in verdicts.values() if v == "merah")
                print(f"{name}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} pemeriksaan){swift_note}")
    finally:
        restore()

    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        print(f"\nmd5 {os.path.relpath(path, ROOT)}: {digest} -> {after} "
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
