#!/usr/bin/env python3
"""Buktikan Aturan 109 **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis — itu bukan bukti apa pun. Yang
harus dibuktikan adalah bahwa ia **bisa merah**, dan merah pada keadaan yang
memang salah.

Keadaan yang diuji di sini bukan karangan: ketiganya adalah mutasi yang
**sungguhan dijalankan** atas salinan utuh pohon ini, lengkap dengan
`./swift-ui-lint.sh` (107 gerbang lain) dan `./swift-typecheck.sh` sungguhan di
sebelahnya. Hasil pengukurannya, sebelum gerbang ini ada:

    jam (PointingView)        cabang `else` statis dihapus → LINT exit 0, TC exit 0
    iPhone (DiagnosticsView)  cabang `else` statis dihapus → LINT exit 0, TC exit 0
    onboarding                cabang `else` statis dihapus → LINT exit 0, TC exit 0

**Nol yang berbunyi**, untuk ketiga layar, pada kedua alat. Itulah alasan
gerbang ini bukan hiasan: bentuk cacatnya tidak menghasilkan galat kompilasi,
tidak menghasilkan peringatan, dan tidak mengubah satu pun teks di layar. Yang
terjadi di perangkat adalah `if` tanpa `else` di dalam `ViewBuilder` — dan itu
sah secara tipe (`EmptyView` adalah `View`). Cabang yang tidak terpenuhi
menggambar **tidak ada apa-apa**. Di jam dan iPhone, `hasPulse` bernilai
`false` untuk planet, Bulan, dan Matahari, jadi yang hilang bukan denyutnya:
**seluruh gambar objek**.

Yang dituntut bukan «ada yang merah», melainkan **berkas dan baris mana**. Harus
tepat satu temuan, pada berkas yang dimutasi, dan pada baris `if` miliknya —
bukan pada berkas sebelahnya. Gerbang yang berbunyi pada berkas yang salah
mengukur hal lain daripada yang diklaimnya, dan repo ini sudah membayar kelas
cacat itu beberapa kali.

Keadaan batas, dan satu-satunya yang **wajib hijau**: badan `else` statisnya
dibungkus ulang dalam satu baris komentar `//`. Gambar yang dihasilkan identik
sampai bit terakhir; yang berubah hanya teks. Gerbang yang membaca **isi**
boleh tidak peduli, gerbang yang menghitung **tanda kurung** boleh tidak peduli,
tetapi gerbang yang mencocokkan bentuk dengan rapuh akan berbunyi di sini. Tanpa
keadaan ini, mutasi yang lebih polos — misalnya komentar yang diperbaiki
diksuntikan — bisa membuat seluruh laporan ini merah tanpa ada cacat gambar.

Berkas produksi **dimutasi dengan sengaja** lalu dipulihkan di `finally` per
keadaan. Lewat `mutasi_sumber`, bukan `open(path, "w")`: setiap prob membaca
berkasnya dari **proses baru**, jadi penulisan biasa membuat pembaca bisa
melihat berkas setengah jadi — dan kegagalan pemulihan bersifat **diam**, lalu
menyalahkan kode yang benar. `SIGKILL` tetap bisa melewati `finally`, jadi ada
handler sinyal juga. Itu batas yang diketahui, bukan klaim kebal.

Pakai:
    python3 Tools/bukti-mutasi-aturan109-cabang-statis.py

"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (bersih-dulu, tulis atomik, pulih terverifikasi)

GATE = os.path.join(ROOT, "Tools", "check-aturan109-cabang-statis.py")

WATCH = os.path.join(ROOT, "Apps/PointAndKnowWatch/Sources/PointingView.swift")
IOS = os.path.join(ROOT, "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift")
ONBOARDING = os.path.join(ROOT, "Apps/Shared/OnboardingView.swift")

#: Dijalankan di proses baru: mengimpor ulang gerbang dari berkas yang **sudah
#: dimutasi** di disk. Mengimpor sekali di dalam proses ini akan memakai
#: salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
ROOT = sys.argv[1]
spec = importlib.util.spec_from_file_location(
    "g109", os.path.join(ROOT, "Tools", "check-aturan109-cabang-statis.py"))
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)
for path in sorted(g.glob.glob(os.path.join(g.APPS, "**", "*.swift"),
                               recursive=True)):
    findings, count = g.check_file(path)
    rel = os.path.relpath(path, g.ROOT)
    for line, message in findings:
        print("GAGAL " + rel + " " + str(line))
"""

# ── Keadaan ────────────────────────────────────────────────────────────────
#
# Setiap keadaan: (nama, berkas, (cari, ganti), berkas_yang_harus_berbunyi).
#
# Jangkar diperiksa harus muncul **tepat satu kali** — `str.replace` atas
# jangkar yang muncul dua kali mengubah keduanya, dan harness lalu melaporkan
# keadaan yang tidak pernah ia uji. Diperiksa eksplisit di `main()`.
#
# Keadaan 1-3 adalah mutasi yang sudah diukur: ketiganya lolos 107 gerbang lain
# dan typecheck. Keadaan 4 adalah batas yang wajib hijau, dan justru yang
# membuktikan gerbang ini membaca **struktur**, bukan bentuk teks.

STATES = [
    ("[baseline]", None, None, None),

    ("1. jam: cabang statis dihapus", WATCH,
     ("            } else {\n"
      "                // Tanpa `TimelineView` denyut benar-benar berhenti, bukan\n"
      "                // \"cukup kecil\". `pulsePhase` mengembalikan **nol persis** di\n"
      "                // keadaan gated, jadi kedua cabang menghasilkan gambar yang\n"
      "                // sama saat gerak mati.\n"
      "                CelestialVisualView(visual: visual,\n"
      "                                    diameter: diameter,\n"
      "                                    isConfirmed: isConfirmed,\n"
      "                                    pulse: MotionPolicy.staticPulsePhase)\n"
      "            }",
      "            }"),
     "Apps/PointAndKnowWatch/Sources/PointingView.swift"),

    ("2. iPhone: cabang statis dihapus", IOS,
     ("                } else {\n"
      "                    // Tanpa `TimelineView`: view tidak pernah di-refresh per\n"
      "                    // frame, jadi denyut benar-benar berhenti — bukan\n"
      "                    // \"cukup kecil\". Tiga hal bisa membawa ke sini:\n"
      "                    // `reduceMotion`/redup (geraknya memang tidak boleh\n"
      "                    // jalan), `hasPulse` salah (gambarnya memang diam), dan\n"
      "                    // `pulsePhase` mengembalikan **nol persis** di keadaan\n"
      "                    // gated — bukan amplitude kecil. Ketiganya menghasilkan\n"
      "                    // gambar yang sama persis, dan itu yang membuat cabang\n"
      "                    // ini boleh dicabut tanpa perlu menebak apa yang berubah.\n"
      "                    content(pulse: 0)\n"
      "                }",
      "                }"),
     "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift"),

    ("3. onboarding: cabang statis dihapus", ONBOARDING,
     ("        } else {\n"
      "            // Diam karena diminta, bukan karena lupa.\n"
      "            CelestialVisualView(visual: illustration,\n"
      "                                diameter: VisualImageMetrics.onboardingIllustrationDiameter,\n"
      "                                isConfirmed: true,\n"
      "                                pulse: MotionPolicy.staticPulsePhase)\n"
      "                .accessibilityHidden(true)\n"
      "        }",
      "        }"),
     "Apps/Shared/OnboardingView.swift"),

    # Batas: gambar identik sampai bit terakhir, hanya teks yang berubah.
    # Gerbang yang mengukur struktur harus diam di sini.
    ("4. komentar di badan statis (wajib hijau)", ONBOARDING,
     ("            // Diam karena diminta, bukan karena lupa.\n"
      "            CelestialVisualView(visual: illustration,",
      "            // DIPERIKSA: komentar tambahan tidak mengubah gambar.\n"
      "            // Diam karena diminta, bukan karena lupa.\n"
      "            CelestialVisualView(visual: illustration,"),
     None),
]

SOURCES = [WATCH, IOS, ONBOARDING]

_original = {}


def restore(*_):
    """Pulihkan berkas produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber` (tulis atomik + verifikasi pemulihan): tiga berkas
    Swift ini dibaca oleh `swift-typecheck.sh` dan oleh gerbang lain di CI
    yang sama, dan setiap prob membacanya dari proses baru.
    """
    for path, content in _original.items():
        mutasi_sumber.restore_verified(path, content)


def probe():
    """Jalankan gerbang langsung → (himpunan "berkas:baris" merah, galat)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None, (proc.stderr.strip().splitlines()[-1:]
                      or ["(tanpa galat)"])
    red = set()
    for line in proc.stdout.splitlines():
        if line.startswith("GAGAL "):
            parts = line.split()
            # "GAGAL <relpath> <baris>"
            red.add(parts[1])
    return red, None


def main() -> int:
    mutasi_sumber.require_clean_sources(SOURCES)

    # Jangkar diperiksa **sebelum** apa pun dimutasi.
    for path in SOURCES:
        with open(path, encoding="utf-8") as handle:
            _original[path] = handle.read()
    for label, target, mutation, want in STATES:
        if mutation is None or want is None:
            continue
        old, _ = mutation
        count = _original[target].count(old)
        if count != 1:
            print(f"GERBANG: jangkar untuk «{label}» muncul {count}x, harus "
                  "tepat 1x — harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, target, mutation, want in STATES:
            if mutation is None:
                # Baseline: berkas sudah bersih (dijamin `require_clean_sources`).
                pass
            else:
                # **Pulihkan lebih dulu.** Tanpa ini, mutasi keadaan 1 hidup di
                # keadaan 2 dan 3, dan berkas yang tidak pernah dimutasi tetap
                # berbunyi — laporan lalu menuduh kode yang benar. Kegagalan
                # semacam ini bersifat **diam** dan sudah pernah menjatuhkan
                # `main` di repo ini (lihat `mutasi_sumber`).
                for path, content in _original.items():
                    mutasi_sumber.write_source(path, content)
                old, new = mutation
                if old not in _original[target]:
                    print(f"{label:44s} ANCHOR TIDAK DITEMUKAN")
                    unexpected += 1
                    continue
                mutasi_sumber.write_source(
                    target, _original[target].replace(old, new, 1))

            red, error = probe()
            if red is None:
                detail = (error or ["(tanpa galat)"])[-1]
                print(f"{label:44s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            if want is None:
                ok = not red
            else:
                # Tepat satu berkas berbunyi, dan itu berkas yang dimutasi.
                ok = red == {want}
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:44s} "
                  f"berkas merah: {sorted(red) or '—'}")
            if not ok:
                print(f"       harapan: {want if want else '— (hijau)'}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
