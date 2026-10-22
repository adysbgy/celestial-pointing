#!/usr/bin/env python3
"""Sapu buta badan Apps/: mutasi kecil yang mengompilasi, cari yang LOLOS seluruh gerbang.

Siklus repo ini pakai metode yang sama berulang kali: mutasi satu ekspresi di
`Apps/`, jalankan gerbang lokal pada proses baru, lalu periksa mana yang tetap
exit 0. Yang exit 0 padahal salah = titik yang belum dijaga.

**Ketiga gerbang, bukan dua (22 Okt 2026).** Sampai siklus ini berkas ini hanya
menjalankan `swift-ui-lint.sh` + `swift-typecheck.sh` dan mencetak
**"LOLOS SELURUH GERBANG"**. Kalimat itu salah: repo ini punya gerbang lokal
ketiga, `swift test`, dan uji-uji di `PointingKit` **membaca teks `Apps/`**
(`PreferenceDefaultsTests`, `ObservedPropertyTests`, `AlwaysOnContentTests`, …).
Terukur, dan itulah yang membuka siklus ini: mutasi `Apps/Shared/AudioCue.swift`
yang menghapus cabang bawaan preferensi dicetak **"LOLOS SELURUH GERBANG"** oleh
versi lama berkas ini, padahal `swift test` memerahkannya dengan dua kegagalan.
Kesimpulan "titik ini belum dijaga" lalu ditulis ke docstring produksi — dan
salah. Alat yang mengukur sebagian gerbang tapi mengucapkan "seluruh" bukan alat
yang kurang teliti; ia alat yang **menghasilkan cacat baru** berupa gerbang teks
yang ditulis untuk cacat yang sudah dijaga.

Karena itu sekarang tiga gerbang dijalankan, dan verdict-nya menyebut **gerbang
mana** yang berbunyi. `CelestialEngine` sengaja tidak dijalankan: tidak satu pun
ujinya membaca `Apps/` (`grep -rln "Apps/" Packages/CelestialEngine/Tests/`
kosong), jadi ia tidak bisa berbunyi untuk mutasi di pohon ini.

Sebelum menyapu, ada **kontrol positif**: satu mutasi yang sudah terukur harus
ditemukan `swift test` — dan harus **hanya** `swift test` yang menemukannya,
supaya yang terbukti berbunyi adalah gerbang ketiga itu, bukan gerbang teks yang
sudah lama bekerja. Kalau kontrolnya hijau, sapuan berhenti: gerbang ketiga tidak
mengukur apa pun, dan setiap "LOLOS" di bawahnya tidak berarti.

Yang membuat sapuan ini berbeda dari yang sudah ada: mutasi dipilih dari
**kategori** yang belum pernah disapu — bukan argumen pemanggil yang sudah dijaga
Aturan 34/52, tapi:
  - `guard`/`if let` yang jadi literal (fakta hilang dari alur)
  - perbandingan yang dibalik (`<` -> `>`)
  - enum case yang ditukar
  - `??` default yang jadi literal
  - konstanta numerik dalam badan logika Apps/

Tiap mutasi dijalankan pada salinan pohon kerja penuh (bukan in-place), jadi
mutasi yang tertinggal tidak mungkin mencemari repo. Jalankan sebagian dulu
(`--only N`) supaya hasil masuk bertahap.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS = os.path.join(ROOT, "Apps")

#: Gerbang lokal yang bisa berbunyi untuk mutasi di `Apps/`, dalam urutan
#: termurah lebih dulu. `swift test` sengaja terakhir: ia satu-satunya yang
#: butuh kompilasi + ~10 detik uji, dan gerbang teks yang lebih murah sudah
#: cukup untuk sebagian besar kandidat.
#:
#: `CelestialEngine` **tidak** ada di daftar ini, dan itu keputusan terukur:
#: `grep -rln "Apps/" Packages/CelestialEngine/Tests/` kosong, jadi tidak ada
#: uji di sana yang bisa membaca mutasi pohon ini.
GATES = ("swift-ui-lint.sh", "swift-typecheck.sh", "swift-test.sh")


def run_gates(tree: str, gates=GATES) -> tuple[bool, str, str]:
    """Jalankan gerbang pada salinan pohon.

    Kembalikan `(semua_lulus, ringkas, gerbang_yang_berbunyi)`. Nama gerbang
    pemanggil ikut dikembalikan karena verdict "LOLOS" hanya jujur kalau
    pembaca tahu **apa** yang lolos — kekurangan versi lama berkas ini.
    """
    out = []
    for script in gates:
        try:
            proc = subprocess.run(
                ["bash", os.path.join(tree, script)],
                cwd=tree, capture_output=True, text=True, timeout=2400,
            )
        except subprocess.TimeoutExpired:
            raise
        out.append(f"{script}: exit {proc.returncode}")
        if proc.returncode != 0:
            combined = proc.stdout + proc.stderr
            # `swift test` mencetak ratusan baris progres build; baris yang
            # menjawab "kenapa merah" adalah baris `error:`. Tanpa penyaringan
            # ini, laporan sapuan memuat nama berkas objek, bukan sebabnya —
            # dan sebabnya itulah yang dibaca orang untuk memutuskan apakah
            # gerbangnya benar atau kebetulan.
            sebab = [ln.strip() for ln in combined.splitlines() if "error:" in ln]
            if not sebab:
                sebab = [ln.strip() for ln in combined.splitlines() if ln.strip()][-6:]
            return False, " | ".join(out) + " || " + " ; ".join(s[:240] for s in sebab[:3]), script
    return True, " | ".join(out), ""


def buat_salinan() -> tuple[str, str]:
    """Buat direktori sementara + salinan pohon. Kembalikan (tmp, tree).

    **Kenapa bukan `TemporaryDirectory`.** `swift-typecheck.sh` menjalankan
    `swift build` lewat Docker **di dalam salinan**, jadi `Packages/*/.build`
    dibuat oleh **root** selama gerbang berjalan. `TemporaryDirectory` lalu
    gagal membersihkannya dengan `PermissionError` — kegagalan yang tidak ada
    hubungannya dengan mutasi yang diuji, tapi menghentikan sapuan sebelum
    satu pun hasil tercetak. Pembersihan karena itu dilakukan sendiri, dengan
    `sudo -n rm -rf` sebagai jalan terakhir.
    """
    tmp = tempfile.mkdtemp(prefix="sapu-")
    tree = os.path.join(tmp, "repo")
    copy_tree(tree)
    return tmp, tree


def bersihkan(tmp: str) -> None:
    try:
        shutil.rmtree(tmp)
        return
    except (PermissionError, OSError):
        pass
    # `.build` dibuat root di dalam wadah. `sudo -n` dipakai gerbang ini juga.
    subprocess.run(["sudo", "-n", "rm", "-rf", tmp],
                   capture_output=True, text=True)


def copy_tree(tree: str) -> None:
    """Salin pohon kerja secukupnya untuk kedua gerbang teks.

    **Kenapa bukan `copytree(ROOT)`.** `Packages/*/.build` berukuran 281M + 321M
    dan dimiliki **root** (dibuat di dalam wadah Docker), jadi menyalinnya
    membuat `TemporaryDirectory` gagal dibersihkan dengan `PermissionError` —
    kegagalan yang tidak ada hubungannya dengan mutasi yang sedang diuji.
    Direktori itu juga tidak dibaca gerbang teks mana pun: `swift-ui-lint.sh`
    hanya membaca berkas sumber, `swift-typecheck.sh` hanya `-parse`.
    """
    os.makedirs(tree, exist_ok=True)
    for name in ("Apps", "Tools", "Tests", "README.md", "project.yml",
                 "swift-ui-lint.sh", "swift-typecheck.sh", "swift-test.sh"):
        src = os.path.join(ROOT, name)
        if not os.path.exists(src):
            continue
        dst = os.path.join(tree, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst, symlinks=True,
                            ignore=shutil.ignore_patterns("*.pyc", "__pycache__"))
        else:
            shutil.copy2(src, dst)
    packages_dst = os.path.join(tree, "Packages")
    os.makedirs(packages_dst, exist_ok=True)
    for pkg in sorted(os.listdir(os.path.join(ROOT, "Packages"))):
        pkg_src = os.path.join(ROOT, "Packages", pkg)
        if not os.path.isdir(pkg_src):
            continue
        for sub in ("Sources", "Tests"):
            sub_src = os.path.join(pkg_src, sub)
            if os.path.isdir(sub_src):
                shutil.copytree(sub_src, os.path.join(packages_dst, pkg, sub),
                                symlinks=True)
        manifest = os.path.join(pkg_src, "Package.swift")
        if os.path.exists(manifest):
            shutil.copy2(manifest, os.path.join(packages_dst, pkg, "Package.swift"))


def mutate(tree: str, relpath: str, old: str, new: str) -> bool:
    path = os.path.join(tree, relpath)
    if not os.path.exists(path):
        return False
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if old not in text:
        return False
    if text.count(old) != 1:
        return False
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text.replace(old, new, 1))
    return True


# ── Kontrol positif: gerbang ketiga wajib terbukti berbunyi ────────────────
#
# Mutasinya bukan karangan: ia persis cacat yang dijaga
# `PreferenceDefaultsTests.testUnsetKeyAccessorsAgreeWithTheDeclaredDefault` —
# `bool(forKey:)` membaca kunci kosong sebagai `false`, jadi "belum diset"
# runtuh menjadi "dimatikan" dan bawaan nyala hilang tanpa ada yang meminta.
# Ia **mengompilasi** (`Bool` masuk ke parameter `Bool?` tanpa cast), tidak
# meninggalkan satu pun tanda di kedua gerbang teks, dan hanya `swift test`
# yang membacanya.
#
# Kenapa bentuk ini, bukan yang lebih dramatis: kontrol harus **bertahan pada
# pohon yang benar**. Versi pertama kontrol ini menghapus cabang `object(forKey:)`
# yang sudah tidak ada lagi setelah siklus ini, jadi ia akan "gagal dipasang"
# dan menghentikan sapuan — alat yang mati karena pekerjaannya sendiri selesai.
CONTROL = (
    "kontrol: `as? Bool` diganti `bool(forKey:)` (wajib ditangkap swift test)",
    "Apps/Shared/AudioCue.swift",
    "stored: UserDefaults.standard.object(forKey: AudioCueStorage.key) as? Bool",
    "stored: UserDefaults.standard.bool(forKey: AudioCueStorage.key)",
    "gerbang ketiga tidak berbunyi untuk kelas cacat yang sudah terukur",
)

CANDIDATES: list[tuple[str, str, str, str, str]] = []


def add(name: str, relpath: str, old: str, new: str, why: str) -> None:
    CANDIDATES.append((name, relpath, old, new, why))


def jalankan_kontrol(tree: str) -> bool:
    """Pastikan `swift test` benar-benar berbunyi, dan hanya dia yang berbunyi.

    Tanpa kontrol ini, "LOLOS" dan "merah (aman)" sama-sama tidak berarti:
    sapuan yang gerbang ketiganya tidak pernah jalan akan mencetak "LOLOS"
    untuk **setiap** kandidat, dan itu terbaca seperti repo yang sangat buta.
    """
    name, relpath, old, new, _ = CONTROL
    if not mutate(tree, relpath, old, new):
        print(f"KONTROL GAGAL DIPASANG (jangkar tidak unik/hilang): {name}")
        return False
    ok, detail, berbunyi = run_gates(tree)
    print(f"  {name}")
    print(f"    {detail}")
    if ok:
        print("  KONTROL HIJAU — `swift test` tidak berbunyi untuk cacat yang "
              "sudah terukur.\n  Sapuan dihentikan: tanpa gerbang ketiga, "
              "\"LOLOS\" di bawah berarti \"tidak ada gerbang yang jalan\", "
              "bukan \"tidak ada gerbang yang menjaga\".")
        return False
    if berbunyi != "swift-test.sh":
        print(f"  KONTROL SALAH GERBANG — yang berbunyi `{berbunyi}`, bukan "
              "`swift-test.sh`.\n  Kontrol ini dirancang untuk membuktikan "
              "gerbang KETIGA bekerja; gerbang teks yang berbunyi tidak "
              "membuktikan itu.")
        return False
    print("  KONTROL BENAR — hanya `swift test` yang berbunyi.\n")
    return True


# ── MotionLogger: kehilangan sensor ────────────────────────────────────────
#
# CATATAN (22 Okt 2026): kandidat "isRunning tetap true saat sensor hilang"
# DIHAPUS dari sapuan ini, bukan karena cacatnya diperbaiki, melainkan karena
# premisnya tidak benar dan tidak pernah benar.
#
# Alasannya terukur: `grep -rn '\.isRunning' Apps/` mengembalikan **nol**
# pembacaan. Properti itu memang ditulis di tiga jalur, tapi tidak satu pun
# layar membacanya; yang sampai ke pengguna adalah `PointingEngine.sensorNote`
# (diisi di `PointingEngine.swift:342` dan dibaca `PointingView` serta
# `ReducedLuminanceView`). Jadi membalik `isRunning` tidak membuat layar
# "bilang sensor hidup" — layar tidak pernah bertanya.
#
# Yang menjaganya tetap jujur adalah Aturan 53 (fail-closed: bentuk
# `isRunning = manager.isDeviceMotionActive` wajib muncul tepat sekali), dan
# yang menjaganya tetap **tanpa pembaca** adalah peran `.bookkeeping` di
# `ObservedProperty` beserta ujinya. Kandidat yang lolos tanpa bisa
# dibuktikan salah adalah kandidat yang membuat sapuan ini terdengar lebih
# teliti daripada isinya — dan itu justru yang harus dihindari.
add("motion: alur tak diberi tahu sensor mati",
    "Apps/Shared/MotionLogger.swift",
    "        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }\n        publishSensorLoss()\n    }",
    "        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }\n    }",
    "snapshot UI tertinggal di objek 'terkonfirmasi' padahal sensor sudah mati")

# ── LocationProvider: izin ditolak ─────────────────────────────────────────
add("lokasi: note dibuang saat ditolak (UI diam soal penolakan)",
    "Apps/Shared/LocationProvider.swift",
    "            statusText = SensorStatusText.locationDeniedStatus\n            note = SensorStatusText.locationDeniedNote",
    "            statusText = SensorStatusText.locationDeniedStatus\n            note = nil",
    "PRD: jangan diam saat izin ditolak — statusText sendiri tak pernah dibaca UI")

add("lokasi: efektif selalu lokasi bawaan",
    "Apps/Shared/LocationProvider.swift",
    "    var effectiveLocation: ObserverLocation { location ?? .fallback }",
    "    var effectiveLocation: ObserverLocation { .fallback }",
    "lokasi sungguhan ada tapi tak pernah dipakai")

# ── AudioCue: preferensi ───────────────────────────────────────────────────
add("suara: preferensi dibaca terus (tak bisa dimatikan)",
    "Apps/Shared/AudioCue.swift",
    "            AudioPreference.isEnabled(\n                stored: UserDefaults.standard.object(forKey: AudioCueStorage.key) as? Bool)",
    "            true",
    "pengguna matikan bunyi di toolbar, tetap berbunyi")

# ── Sensor tidak tersedia ──────────────────────────────────────────────────
add("sensor: alasan tak tersedia tak pernah diset",
    "Apps/Shared/MotionLogger.swift",
    "            unavailableReason = SensorStatusText.motionMissing",
    "            unavailableReason = nil",
    "layar tidak pernah menyatakan sensor mati")


def main() -> int:
    only = [int(a) for a in sys.argv[1:] if a.isdigit()]
    picked = [(i, c) for i, c in enumerate(CANDIDATES) if not only or i in only]
    print(f"Sapu {len(picked)} mutasi dari {len(CANDIDATES)} kandidat")
    print(f"Gerbang: {', '.join(GATES)}\n")

    # Kontrol dasar dulu: salinan TANPA mutasi wajib hijau. Kalau tidak,
    # setiap "merah (aman)" di bawah bisa berarti salinanku kurang berkas —
    # dan sapuan yang tadinya salah jadi terlihat benar.
    tmp, tree = buat_salinan()
    try:
        try:
            ok, detail, _ = run_gates(tree)
        except subprocess.TimeoutExpired:
            print("BASELINE TIMEOUT — perbaiki perkakas, bukan lanjut")
            return 2
        if not ok:
            print(f"BASELINE MERAH — salinan tanpa mutasi gagal, "
                  f"jadi sapuan ini tidak boleh dipercaya:\n  {detail}")
            return 2
        print(f"BASELINE HIJAU (salinan tanpa mutasi): {detail}\n")
    finally:
        bersihkan(tmp)

    # Kontrol positif: buktikan gerbang ketiga berbunyi sebelum verdict apa pun
    # di bawahnya dipakai. Tanpa ini, "LOLOS" tidak bisa dibedakan dari
    # "gerbangnya tidak pernah jalan".
    print("KONTROL POSITIF (gerbang ketiga wajib berbunyi):")
    tmp, tree = buat_salinan()
    try:
        if not jalankan_kontrol(tree):
            return 2
    finally:
        bersihkan(tmp)

    lolos = []
    for idx, (name, relpath, old, new, why) in picked:
        tmp, tree = buat_salinan()
        try:
            if not mutate(tree, relpath, old, new):
                print(f"[{idx}] LEWAT (jangkar tidak unik/hilang): {name}")
                continue
            try:
                ok, detail, berbunyi = run_gates(tree)
            except subprocess.TimeoutExpired:
                print(f"[{idx}] TIMEOUT: {name}")
                continue
            if ok:
                lolos.append((idx, name, why))
                print(f"[{idx}] LOLOS KETIGA GERBANG  {name}")
                print(f"       kenapa: {why}")
            else:
                print(f"[{idx}] merah (aman) lewat {berbunyi:<20} {name}")
        finally:
            bersihkan(tmp)
    print(f"\n=== {len(lolos)} dari {len(picked)} mutasi LOLOS ketiga gerbang ===")
    for idx, name, why in lolos:
        print(f"  [{idx}] {name}\n       {why}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
