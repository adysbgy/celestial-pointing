#!/usr/bin/env python3
"""Jalankan **pemilihan** gerbang `check-visuals.py` — tanpa seluruh katalog.

Kenapa ada. Gerbang penuh `check-visuals.py --check` merender **seluruh**
katalog visual (~41 menit di VPS ini, ~6 menit di runner CI). Selama
menutup satu cacat berarti menunggu seperempat jam setiap kali satu angka
atau satu ambang perlu diukur ulang — dan tekanan waktu itu sendiri cacat:
ia mendorong orang menebak angka daripada mengukurnya.

Alat ini mengimpor berkas gerbang sebagai **modul** (bukan menjalankannya
sebagai program) lalu memanggil hanya gerbang yang namanya disebut,
sehingga satu pemeriksaan tertentu bisa diukur dalam hitungan detik.

    python3 Tools/run-visual-checks.py "<substr>" ["<substr>", ...]

Semua gerbang punya argumen bera default (`size=200, ss=2`, sama dengan
`--size`/`--ss` bawaan program), jadi pemanggilan `fn(results)` menyebut
angka yang identik dengan yang dipakai gerbang penuh.

**Batas yang dinyatakan.** Nama diperiksa sebagai substring, sama seperti
`--only` di gerbang. Bila sebuah nama cocok ke **nol** gerbang, alat ini
keluar != 0 — tanpa itu, satu nama yang salah tulis tidak akan menjalankan
apa pun dan melaporkan "0 pemeriksaan", yang terbaca persis seperti
"0 gagal": kelas cacat "hijau karena tidak ada" yang berkas gerbangnya
sendiri sudah sebut sebagai bahayanya.
"""

from __future__ import annotations

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CV_PATH = os.path.join(HERE, "check-visuals.py")


def _load_gate_module():
    """Muat `check-visuals.py` sebagai modul, **tanpa** menjalankan `main()`.

    Efek yang tetap perlu: `_load("render_visuals", "render-visuals.py")`
    di tingkat modul membacanya dari disk dan membuang `.pyc` basi — jadi
    probe selalu mengukur port yang ada sekarang, bukan salinan yang salah.
    """
    spec = importlib.util.spec_from_file_location("check_visuals", CV_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"tidak bisa memuat {CV_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    wanted = [w for w in argv[1].split() if w]

    try:
        gate = _load_gate_module()
    except Exception as exc:  # pragma: no cover - jalur alat rusak
        print(f"gagal memuat {CV_PATH}: {exc}")
        return 2

    names = sorted(n for n in dir(gate) if n.startswith("check_"))
    selected = [n for n in names if any(w in n for w in wanted)]
    if not selected:
        print(f"nama cocok ke NOL gerbang: {wanted}")
        return 2

    results = []
    for name in selected:
        getattr(gate, name)(results)

    width = max(len(r.name) for r in results)
    failures = [r for r in results if not r.ok]
    for r in results:
        mark = "OK  " if r.ok else "GAGAL"
        print(f"{mark} {r.name.ljust(width)}  {r.detail}")
    print(f"\n{len(results)} pemeriksaan, {len(failures)} gagal")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
