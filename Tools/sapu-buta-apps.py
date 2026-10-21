#!/usr/bin/env python3
"""Sapu buta badan Apps/: mutasi kecil yang mengompilasi, cari yang LOLOS seluruh gerbang.

Siklus repo ini pakai metode yang sama berulang kali: mutasi satu ekspresi di
`Apps/`, jalankan `./swift-ui-lint.sh` + `./swift-typecheck.sh` pada proses baru,
lalu periksa mana yang tetap exit 0. Yang exit 0 padahal salah = titik yang belum
dijaga.

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


def run_gates(tree: str) -> tuple[bool, str]:
    """Jalankan kedua gerbang teks pada salinan pohon. Kembalikan (lulus, ringkas)."""
    out = []
    for script in ("swift-ui-lint.sh", "swift-typecheck.sh"):
        proc = subprocess.run(
            ["bash", os.path.join(tree, script)],
            cwd=tree, capture_output=True, text=True, timeout=900,
        )
        out.append(f"{script}: exit {proc.returncode}")
        if proc.returncode != 0:
            tail = (proc.stdout + proc.stderr).strip().splitlines()
            return False, " | ".join(out) + " || " + " ; ".join(tail[-6:])
    return True, " | ".join(out)


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


# Kandidat mutasi: (nama, berkas relatif, potongan lama, potongan baru, kenapa relevan)
CANDIDATES: list[tuple[str, str, str, str, str]] = []


def add(name: str, relpath: str, old: str, new: str, why: str) -> None:
    CANDIDATES.append((name, relpath, old, new, why))


# ── MotionLogger: kehilangan sensor ────────────────────────────────────────
add("motion: isRunning tetap true saat sensor hilang",
    "Apps/Shared/MotionLogger.swift",
    "        isRunning = false\n        if manager.isDeviceMotionActive",
    "        isRunning = true\n        if manager.isDeviceMotionActive",
    "layar membaca isRunning untuk katakan sensor hidup; sensor sudah mati tapi layar bilang hidup")

add("motion: alur tak diberi tahu sensor mati",
    "Apps/Shared/MotionLogger.sh".replace(".sh", ".swift"),
    "        publishSensorLoss()\n        return\n    }\n    guard !manager.isDeviceMotionActive",
    "        return\n    }\n    guard !manager.isDeviceMotionActive",
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
    "            if UserDefaults.standard.object(forKey: AudioCueStorage.key) == nil { return true }\n            return UserDefaults.standard.bool(forKey: AudioCueStorage.key)",
    "            return true",
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
    print(f"Sapu {len(picked)} mutasi dari {len(CANDIDATES)} kandidat\n")

    # Kontrol dasar dulu: salinan TANPA mutasi wajib hijau. Kalau tidak,
    # setiap "merah (aman)" di bawah bisa berarti salinanku kurang berkas —
    # dan sapuan yang tadinya salah jadi terlihat benar.
    tmp, tree = buat_salinan()
    try:
        try:
            ok, detail = run_gates(tree)
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

    lolos = []
    for idx, (name, relpath, old, new, why) in picked:
        tmp, tree = buat_salinan()
        try:
            if not mutate(tree, relpath, old, new):
                print(f"[{idx}] LEWAT (jangkar tidak unik/hilang): {name}")
                continue
            try:
                ok, detail = run_gates(tree)
            except subprocess.TimeoutExpired:
                print(f"[{idx}] TIMEOUT: {name}")
                continue
            if ok:
                lolos.append((idx, name, why))
                print(f"[{idx}] LOLOS SELURUH GERBANG  {name}")
                print(f"       kenapa: {why}")
            else:
                print(f"[{idx}] merah (aman)          {name}")
        finally:
            bersihkan(tmp)
    print(f"\n=== {len(lolos)} dari {len(picked)} mutasi LOLOS seluruh gerbang ===")
    for idx, name, why in lolos:
        print(f"  [{idx}] {name}\n       {why}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
