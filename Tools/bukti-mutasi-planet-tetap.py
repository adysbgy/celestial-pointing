#!/usr/bin/env python3
"""Buktikan Aturan 31 menutup kalselnya: **planet yang salah**, bukan hanya `nil`.

Kenapa berkas ini ada, dan kenapa ia bukan tambahan `bukti-mutasi-aturan31-kawat.py`.

Aturan 31 sudah dua siklus ditegakkan, dan seluruh 12 keadaannya memeriksa satu
bentuk cacat: kawat fase berujung `nil`. Bentuk itu **satu dari dua**. Yang
tidak pernah diukur adalah bentuk kedua, yang sama-sama bisa dikompilasi dan
sama-sama mematikan fase planet dalam:

    let planet = CelestialVisual.Planet.venus     // bidang objek diabaikan

Setiap planet berfase lalu mengambil **fase Venus**. Venus yang sedang sabit
tipis menularkan sabitnya ke Merkurius; sebaliknya Merkurius yang purnama
memberi Venus cakram penuh. Gambarnya tetap "sabit" — jadi tidak ada
satu pun teks di layar yang bisa dibantah pembaca, dan tidak ada piksel yang
terlihat "kosong". Terukur di sini, sebelum gerbangnya diperbaiki:

    planet -> CelestialVisual.Planet.venus    Aturan 31 (lama) HIJAU

Jangkar `let planet = CelestialVisual.Planet(objectID: object.id)` adalah satu
baris yang menyambungkan **identitas objek** ke semua kawat fase dan ciri
permukaan. Kalau baris itu menunjuk planet tetap, kabelnya masih utuh ke
`planetPhases`, `planetWaxing`, `planetBrightLimbAngles` — semuanya sah — dan
yang berubah hanya **kunci** yang dipakai.

Mengapa bentuk ini tidak tertangkap gerbang mana pun yang sudah ada:

  - Aturan 31 membaca *nullability* (apakah nil untuk benda ini), bukan
    *identitas* (planet mana yang dipakai).
  - Aturan 24 menjaga indeks warna bintang, 32 menjaga lencana keraguan,
    36/38/42 menjaga permukaan `PointingEngine` — tidak satu pun membaca
    baris ini.
  - Uji Linux tidak bisa: `Apps/` tidak dibangun `swift-test.sh`.

Keadaan yang diuji:

  [baseline]                            diam (kalau tidak, harness salah)
  1. planet tetap Venus                 berbunyi
  2. planet tetap Jupiter               berbunyi
  3. planet dari planetWaxing           berbunyi (bukan identitas, melainkan
                                        buku fase yang selalu ada — Venus
                                        selalu ada di sana; Merkurius tidak)
  4. bentuk sah: idernya diganti
     `CelestialVisual.Planet(objectID: object.id)!`
                                        diam (identitas tetap dari objek)
  5. bentuk sah: `Planet(rawValue:)`
                                        diam

**Non-vakuositas diukur, bukan diklaim.** Keadaan 1–3 dijalankan sekali lagi
dengan pemeriksa bentuk kedua **dimatikan** (regex jangkar diganti pola yang
tidak pernah cocok). Kalau di sana mereka berbalik diam, maka yang berbunyi
memang pemeriksa baru itu — bukan Aturan 31 yang sudah ada.

Harness ini tidak memutasi sumber produksi: program Aturan 31 diekstrak dari
`swift-ui-lint.sh` dan dijalankan atas salinan `PointingEngine.swift` di
direktori sementara.

Pakai:
    python3 Tools/bukti-mutasi-planet-tetap.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")
WIRE = os.path.join("Apps", "Shared", "PointingEngine.swift")

#: Baris yang menyambungkan identitas objek ke seluruh kawat fase.
#:
#: Jangkar **tanpa** pengisian (tidak memuat `.venus` atau `.nil`): harness
#: yang jangkarnya memuat penggantinya membuat pemeriksa jangkar buta
#: selamanya, dan keadaan "sah" di bawah akan dituduh mutasi tertinggal.
ANCHOR = "let planet = CelestialVisual.Planet(objectID: object.id)"

BENAR = "let planet = CelestialVisual.Planet(objectID: object.id)"

STATES = [
    ("[baseline]", None, False),
    ("1. planet tetap Venus",
     "let planet = CelestialVisual.Planet.venus", True),
    ("2. planet tetap Jupiter",
     "let planet = CelestialVisual.Planet.jupiter", True),
    ("3. planet dari daftar planet berfase",
     "let planet = CelestialVisual.Planet.allCases.first { $0.showsPhase }",
     True),
    ("4. sah: bentuk objek dipertahankan (sama dengan kode)", None, False),
    ("5. sah: Planet(rawValue:) lewat jalan lain",
     "let planet = CelestialVisual.Planet(rawValue: object.id)", False),
]

BLOCK_OPEN = "waxing=$(python3 - <<'PY' 2>&1"


def extract_rule_program() -> str:
    """Ambil program Python Aturan 31 dari `swift-ui-lint.sh` (seperti harness 31)."""
    lines = open(LINT, encoding="utf-8").read().splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() == BLOCK_OPEN:
            start = i + 1
            break
    if start is None:
        raise SystemExit("GERBANG: pembuka program Aturan 31 tidak ditemukan "
                         f"di {LINT} — harness tidak boleh jalan.")
    for j in range(start, len(lines)):
        if lines[j].rstrip() == "PY":
            return "\n".join(lines[start:j])
    raise SystemExit("GERBANG: penutup program Aturan 31 (`PY`) tidak ditemukan.")


def identity_marker(program: str) -> str | None:
    """Temukan baris definisi pemeriksa identitas di program Aturan 31.

    `None` berarti gerbang itu **belum** punya pemeriksa identitas — keadaan
    yang sah saat harness ini ditulis (dan yang harus dilaporkan sebagai
    "tidak mengukur", bukan sebagai traceback).
    """
    for pattern in (r"^IDENTITY = re\.compile\(.*\)$",
                    r"^IDENTITY = re\.compile\("):
        m = re.search(pattern, program, re.M)
        if m:
            return m.group(0)
    return None


def disable_identity_check(program: str) -> str | None:
    """Matikan **hanya** pemeriksa identitas, sisakan seluruh Aturan 31 lama.

    Diganti pola yang tidak pernah cocok — atributnya tetap ada, jadi programnya
    tidak mati dengan `AttributeError` (pelajaran dari
    `bukti-mutasi-permukaan-nilai.py`: traceback pernah terbaca sebagai
    "berbunyi"). `None` bila Aturan 31 belum punya pemeriksanya sama sekali.
    """
    line = identity_marker(program)
    if line is None:
        return None
    permulaan = line[:line.index("re.compile(")] + "re.compile(r'(?!x)x')"
    # `replace` menuliskan ulang escape-nya: mengandalkan string di berkas lain
    # untuk dicocokkan kembali = harness yang rapuh terhadap satu tab. Satu baris
    # = satu penggantian, baris demi baris.
    baris = program.split("\n")
    baris = [permulaan if b == line else b for b in baris]
    mati = "\n".join(baris)
    mati = mati.replace(
        "bars = IDENTITY_BINDING.findall(code)", "bars = [None] * len("
        "[b for b in code.split(chr(10)) if 'let planet = CelestialVisual.Planet' in b])", 1)
    mati = mati.replace(
        "m = IDENTITY_BINDING.search(code)", "m = None", 1)
    # Mematikan pola saja TIDAK cukup: cabang "tidak ada tepat satu pengikatan"
    # ikut memakai pola yang sama, jadi ia tetap berbunyi dan keadaan "planet
    # tetap Venus" lolos sebagai "sudah terbukti" -- persis vakuositas yang
    # hendak ditutup. Penjaga pengikatan ikut dimatikan supaya yang tersisa
    # benar-benar hanya pemeriksa identitasnya.
    baris = mati.split("\n")
    hasil = []
    buang_lanjutan = False
    for b in baris:
        if buang_lanjutan:              # `re.M)` milik pola yang dimatikan
            buang_lanjutan = False
            continue
        if b.startswith("IDENTITY_BINDING = re.compile("):
            hasil.append(permulaan)
            buang_lanjutan = not b.endswith(")")
            continue
        hasil.append(b)
    return "\n".join(hasil)


def run_rule(sandbox: str, program: str) -> tuple[int, str]:
    proc = subprocess.run([sys.executable, "-c", program],
                          capture_output=True, text=True, cwd=sandbox,
                          env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
    gabung = proc.stdout + proc.stderr
    if "Traceback (most recent call last)" in gabung:
        sys.exit("GERBANG: program Aturan 31 mati dengan traceback — harness "
                 "ini tidak bisa mengukur apa pun.\n" + gabung)
    return proc.returncode, gabung


def _tunjuk_ke_identitas(out: str) -> bool:
    """Temuan berbunyi datang dari pemeriksa identitas planet, bukan dari sebab lain.

    Ini **harus** membaca kalimat pemeriksanya, bukan nama berkasnya: berkas
    yang sama juga dirujuk kawat `nil` yang sudah ada, jadi "menyebut
    PointingEngine.swift" tidak membedakan pemeriksa yang baru dari yang lama
    (pelajaran dari `bukti-mutasi-aturan31-kawat.py`: merah karena sebab lain
    terbaca sebagai "gerbang berbunyi").
    """
    return "mengambil identitas planet" in out or \
        "pemeriksa identitas kehilangan gigi" in out


def main() -> int:
    program = extract_rule_program()
    legacy = disable_identity_check(program)
    original = open(os.path.join(ROOT, WIRE), encoding="utf-8").read()
    count = original.count(ANCHOR)
    if count != 1:
        sys.exit(f"GERBANG: jangkar `{ANCHOR}` muncul {count}x, harus tepat 1x "
                 "— jangkar ini sudah basi, perbarui sebelum harness dijalankan.")

    failures: list[str] = []
    ran = 0

    # ── a. Semua keadaan di bawah aturan yang sekarang. ────────────────────
    for label, replacement, must_fire in STATES:
        sandbox = tempfile.mkdtemp(prefix="planet-tetap-")
        try:
            target = os.path.join(sandbox, WIRE)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            content = original if replacement is None else \
                original.replace(ANCHOR, replacement, 1)
            if content == original and replacement is not None:
                failures.append(f"{label}: penggantinya identik dengan jangkar")
                continue
            with open(target, "w", encoding="utf-8") as handle:
                handle.write(content)
            _, out = run_rule(sandbox, program)
            fired = bool(out.strip())
            ran += 1
            if fired != must_fire:
                failures.append(
                    f"  {label}: {'berbunyi' if fired else 'diam'} padahal "
                    f"seharusnya {'berbunyi' if must_fire else 'diam'}")
            elif fired and not _tunjuk_ke_identitas(out):
                failures.append(f"  {label}: berbunyi tetapi temuannya bukan "
                                f"pemeriksa identitas:\n    " + out.strip())
        finally:
            shutil.rmtree(sandbox, ignore_errors=True)

    # ── b. Non-vakuositas: tanpa pemeriksa identitas, cacat berbalik diam. ─
    if legacy is None:
        failures.append("  Aturan 31 belum punya pemeriksa identitas (`IDENTITY`) "
                        "— keadaan 1–3 hanya membuktikan bahwa planet tetap "
                        "ditolak, bukan oleh pemeriksa yang mana")
    else:
        for label, replacement, must_fire in STATES:
            if not must_fire:
                continue
            sandbox = tempfile.mkdtemp(prefix="planet-legacy-")
            try:
                target = os.path.join(sandbox, WIRE)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                with open(target, "w", encoding="utf-8") as handle:
                    handle.write(original.replace(ANCHOR, replacement, 1))
                _, out = run_rule(sandbox, legacy)
                ran += 1
                if out.strip():
                    failures.append(
                        f"  non-vakuositas / {label}: versi tanpa pemeriksa "
                        f"identitas juga berbunyi — keadaan ini tidak membuktikan "
                        f"pemeriksa itu mengukur apa pun")
            finally:
                shutil.rmtree(sandbox, ignore_errors=True)

    if ran < 4:
        sys.exit("GERBANG: kurang dari empat keadaan benar-benar dijalankan; "
                 "'sesuai harapan' atas hampir nol pembuktian bukan bukti.")

    konteks = "Aturan 31: kawat fase — identitas planet, bukan hanya nil"
    if failures:
        print(f"{konteks} — {len(failures)} keadaan TIDAK sesuai harapan "
              f"(dari {ran}):")
        print("\n".join(failures))
        return 1
    print(f"{konteks} — {ran} keadaan, semuanya sesuai harapan "
          f"({len(STATES)} keadaan, 3 di antaranya diulang tanpa pemeriksa "
          f"identitas).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
