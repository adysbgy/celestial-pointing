#!/usr/bin/env python3
"""Buktikan `check_deep_sky_catalogue_values_reach_the_picture` benar-benar berbunyi.

Kenapa harness ini ada.

Audit `check-visuals.py` menemukan **tiga** gerbang tanpa satu pun bukti
mutasi (tidak dirujuk satu pun harness `bukti-mutasi-*.py`). Yang ditutup
di sini adalah `check_deep_sky_catalogue_values_reach_the_picture` — yang
paling bernilai dari ketiganya, karena ia menjaga **ragam visual** objek
langit dalam (nebula, galaksi, gugus): setiap entri katalog digambar dengan
angkanya sendiri, dan perbedaannya terlihat di ukuran jam.

Gerbang itu hijau pada hari ditulis; itu bukan bukti apa pun. Yang membedakan
gerbang yang menjaga dari gerbang yang hanya *terlihat* menjaga adalah apakah
ia bisa dibuat merah, dan merah pada keadaan yang memang salah.

Dua arah yang **berbeda** diuji, karena keduanya adalah hazard nyata di repo
dua bahasa ini:

  1. **Model diubah, port tertinggal** — rumus `growth` di `CelestialVisual
     .swift` menyimpang dari port. Ini satu-satunya gerbang yang membandingkan
     rumus growth model ke port, jadi ia harus berbunyi di sini.
  2. **Satu entri katalog kehilangan keunikan fuzziness-nya** (M31 disamakan
     ke netral 0.6). Rumus growth tak disentuh, jadi "rumus sama" tetap hijau;
     yang berbunyi adalah penjaga per-morfologi ("angka katalog punya efek").

Yang diukur tiap keadaan adalah **pemeriksaan bernama**, bukan sekadar "ada
yang merah": pemeriksaan mana yang menangkap cacatnya adalah temuannya.

Berkas `CelestialVisual.swift` (rumus growth) dan `DeepSkyCatalogue.swift`
(entri fuzziness) dimutasi lalu dipulihkan di `finally` per keadaan, plus
handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally` dan meninggalkan
mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-katalog-langit-dalam.py    # 0 = semua sesuai
"""

from __future__ import annotations

import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

MODEL = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")
CATALOGUE = os.path.join(ROOT, "Packages", "PointingKit", "Sources",
                        "PointingKit", "DeepSkyCatalogue.swift")

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
results = []
getattr(C, "check_deep_sky_catalogue_values_reach_the_picture")(results)
ok = bool(results) and all(r.ok for r in results)
print(("OK   " if ok else "GAGAL") + " check_deep_sky_catalogue_values_reach_the_picture")
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

# ── Jangkar rumus growth di model ───────────────────────────────────────────
# `private static func buildDeepSky(` memotong wilayah pembaca, lalu
# `let growth = 0.62 + 0.38 * clamped` di dalamnya. Satu-satunya kemunculan
# di CelestialVisual.swift (terukur: grep = 1x).
GROWTH_MODEL = "    let growth = 0.62 + 0.38 * clamped"
GROWTH_SQUASHED = "    let growth = 0.62 + 0.10 * clamped"

# ── Jangkar entri katalog di DeepSkyCatalogue.swift ─────────────────────────
# M31 fuzziness 1.00 (galaksi paling lebar) disamakan ke netral 0.6.
FZ_M31 = '"m31": 1.00'
FZ_M31_NEUTRAL = '"m31": 0.60'

HIJAU = "hijau"
MERAH = "merah"

CHECK = "check_deep_sky_catalogue_values_reach_the_picture"

# Setiap edit: (berkas, cari, ganti). Kedua berkas dipulihkan tiap keadaan.
STATES = [
    ("[baseline]", None,
     {CHECK: HIJAU,
      "katalog langit dalam: rumus growth sama di kedua bahasa": HIJAU,
      "katalog langit dalam: fuzziness benar-benar memperlebar kabut": HIJAU,
      "katalog langit dalam: angka katalog punya efek pada gambar jam": HIJAU,
      "katalog langit dalam: nilai berbeda terlihat berbeda di ukuran jam": HIJAU}),

    # ── 1. Model diubah, port tertinggal: rentang growth dikempeskan ──────
    #
    # Arah paling mungkin di repo ini. Yang dimutasi hanya `CelestialVisual
    # .swift`; render-visuals.py tetap 0.62 + 0.38. Yang berbunyi adalah
    # "rumus growth sama di kedua bahasa" (model 0.10 ≠ port 0.38).
    #
    # Yang tetap HIJAU (diukur, bukan ditebak):
    #   - "fuzziness memperlebar kabut" — span 0.10 ≠ 0, jadi masih naik.
    #   - "angka katalog punya efek pada gambar jam" — pemeriksaan ini hanya
    #     membandingkan tiap objek ke gambar netral 0.6; span tak nol berarti
    #     objek tetap berbeda dari netral, jadi tetap hijau. Benar: menyusutkan
    #     rentang bukan berarti "tidak ada efek", hanya efek yang lebih kecil.
    #   - "nilai berbeda terlihat berbeda" — antar-objek masih terbedakan.
    ("1. model: rentang growth 0.38 -> 0.10 (port tertinggal)",
     [(MODEL, GROWTH_MODEL, GROWTH_SQUASHED)],
     {CHECK: MERAH,
      "katalog langit dalam: rumus growth sama di kedua bahasa": MERAH,
      "katalog langit dalam: fuzziness benar-benar memperlebar kabut": HIJAU,
      "katalog langit dalam: angka katalog punya efek pada gambar jam": HIJAU,
      "katalog langit dalam: nilai berbeda terlihat berbeda di ukuran jam": HIJAU}),

    # ── 2. Satu entri katalog kehilangan keunikan (M31 -> netral 0.6) ─────
    #
    # Rumus growth tak disentuh, jadi "rumus growth sama" harus tetap HIJAU —
    # ini yang memisahkan penjaga rumus dari penjaga nilai. Yang berbunyi:
    # "angka katalog punya efek pada gambar jam" — M31 kini sama dengan gambar
    # netral morfologi galaksinya, jadi jatuh ke daftar `ineffective`.
    # "nilai berbeda terlihat berbeda" tetap HIJAU: tak ada galaksi lain di 0.6,
    # jadi tak ada tabrakan gambar dalam satu morfologi (diukur, bukan asumsi).
    ("2. entri m31 disamakan ke netral 0.6 (rumus tetap hijau)",
     [(CATALOGUE, FZ_M31, FZ_M31_NEUTRAL)],
     {CHECK: MERAH,
      "katalog langit dalam: rumus growth sama di kedua bahasa": HIJAU,
      "katalog langit dalam: fuzziness benar-benar memperlebar kabut": HIJAU,
      "katalog langit dalam: angka katalog punya efek pada gambar jam": MERAH,
      "katalog langit dalam: nilai berbeda terlihat berbeda di ukuran jam": HIJAU}),
]


def run_probe():
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
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


def main():
    mutasi_sumber.require_clean_sources([MODEL, CATALOGUE])
    original = {MODEL: open(MODEL, "rb").read(),
                CATALOGUE: open(CATALOGUE, "rb").read()}
    baseline_md5 = {path: hashlib.md5(data).hexdigest()
                    for path, data in original.items()}
    failures = []

    def restore():
        for path, data in original.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected in STATES:
            # Pulihkan **kedua** berkas dulu di setiap keadaan, bukan hanya
            # berkas yang dimutasi keadaan ini. Keadaan 2 hanya menyunting
            # katalog, jadi tanpa pemulihan di sini ia diam-diam berjalan di
            # atas `CelestialVisual.swift` yang masih membawa mutasi keadaan 1
            # — dan melaporkan "rumus growth sama" merah untuk suntingan yang
            # tidak menyentuh rumusnya. Mutasi nyasar itu kelas cacat yang
            # persis dicari repo ini, hanya kali ini hidup di dalam harness.
            restore()
            if edits is not None:
                contents = {path: data.decode() for path, data in original.items()}
                for path, find, replace in edits:
                    hits = contents[path].count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x di {os.path.basename(path)}, "
                            f"butuh 1: {find[:70]!r}")
                        break
                    contents[path] = contents[path].replace(find, replace)
                else:
                    for path, _, _ in edits:
                        mutasi_sumber.write_source(path, contents[path])

            verdicts, error = run_probe()
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            wrong = [(res, want, verdicts.get(res, "TIDAK ADA"))
                     for res, want in expected.items()
                     if verdicts.get(res, "TIDAK ADA") != want]
            if wrong:
                for res, want, got in wrong:
                    failures.append(f"{name}: {res!r} diharapkan {want}, "
                                    f"terukur {got}")
                print(f"{name}: {len(wrong)} TIDAK SESUAI HARAPAN")
                for res, want, got in wrong:
                    print(f"    {res}\n      diharapkan {want}, terukur {got}")
            else:
                red = sum(1 for v in verdicts.values() if v == "merah")
                print(f"{name}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} pemeriksaan)")
    finally:
        restore()

    for path, data in original.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        print(f"\nmd5 {os.path.basename(path)}: {baseline_md5[path]} -> {after} "
              f"({'pulih persis' if after == baseline_md5[path] else 'TIDAK PULIH'})")
        if after != baseline_md5[path]:
            failures.append(f"{os.path.basename(path)} tidak pulih persis")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("\nSemua keadaan sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
