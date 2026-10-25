#!/usr/bin/env python3
"""Buktikan gerbang **Aturan 15** (penjaga mode malam untuk warna prosedural)
benar-benar berbunyi pada bentuk yang selama ini lolos.

Kenapa harness ini ada.

Aturan 15 menjaga bahwa setiap `Color(red:...)`/`Color(hue:...)` di `Apps/`
berada di bawah penjaga `NightMode.isOn` di fungsi yang sama. Alasannya
fisiologis, bukan gaya: sel batang paling sensitif di ~498-530nm, dan cahaya
hijau/biru mematikan adaptasi gelap 20-40 menit.

Gate-nya sendiri sudah pernah dibuktikan bisa merah — dan versi awalnya punya
lubang yang tercatat di docstring-nya: daftar pengubah deklarasi tidak
mengenali `@ViewBuilder func` dan `override func`, sehingga cacat di dalamnya
jatuh ke rentang fungsi **sebelumnya** dan penjaga milik fungsi itu
membelanya. Lubang itu sudah ditutup. Yang tidak ditutup adalah lubang dari
kelas yang sama persis, di **sisi batas blok-nya**:

    DECL hanya mengenali `func`. Jadi deklarasi apa pun yang bukan `func`
    tidak menjadi batas blok, dan `Color(red:)` di dalamnya diukur dengan
    rentang deklarasi `func` **sebelumnya**. Kalau deklarasi sebelumnya
    kebetulan punya penjaga, warna tanpa penjaga lolos — bukan karena ia
    benar, tapi karena ia meminjam penjaga tetangga.

Di `Apps/`, bentuk non-`func` yang bisa memuat warna adalah **computed
property**:

    func warnaAman() -> Color {
        guard NightMode.isOn else { return ... }   // penjaga
        return Color(red: 1, green: 0, blue: 0)
    }

    var warnaBocor: Color {                        // BUKAN batas blok
        Color(red: 0.2, green: 0.9, blue: 0.4)     // hijau/biru, tanpa penjaga
    }

Ketiga baris itu dibaca sebagai **satu** blok oleh DECL saat ini, dan
`GUARD` menemukan penjaga milik `warnaAman`. Hasilnya: nol temuan, exit 0 —
sementara layar memancarkan hijau/biru penuh di mode malam, yaitu persis
yang Aturan 15 ditulis untuk mencegah.

Keadaan yang diuji:

  [baseline]  pohon produksi apa adanya              -> HIJAU (wajib; kalau
                                                       tidak, harness-nya salah)
  1. computed var berisi `Color(red:)` hijau/biru
     sesudah func berpenjaga                        -> MERAH (wajib)
  2. computed var berpenjaga sendiri                -> HIJAU (wajib; jangan
                                                       menuduh yang benar)
  3. func berpenjga + computed var netral
     (`Color(white:)`/`gray:`)                      -> HIJAU (wajib; netral
                                                       tidak memancarkan)
  4. computed var berpenjga sendiri diletakkan
     SEBELUM func berpenjaga                        -> HIJAU (wajib; urutan
                                                       tidak boleh menentukan)

Berkas yang diperiksa adalah **kode Aturan 15 yang asli**, diekstrak dari
`swift-ui-lint.sh` saat dijalankan — bukan salinan yang bisa basi. Yang
dimutasi adalah pohon `Apps/` di direktori sementara, dan pohon produksi
tidak pernah disentuh.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

# Penanda awal & akhir blok Python Aturan 15 di dalam `swift-ui-lint.sh`.
# Dicari dari teksnya, bukan dari nomor baris: nomor baris berubah setiap
# kali berkas disunting, dan harness yang mengunci nomor baris akan merah
# karena sebab yang salah.
START_MARK = "== Aturan 15: warna prosedural wajib lewat penjaga mode malam =="
ASSIGN = "color_guard=$(python3 - <<'PY' 2>&1"
END_MARK = "\nPY\n"

#: Defek yang disuntikkan: penjaga milik func, warna bocor di computed var.
LEAKY_VAR = """import SwiftUI

struct ZzProbeBatas15 {

    /// Punya penjaga. Sengaja ditulis lebih dulu supaya penjaganya menjadi
    /// blok terdekat sebelum `warnaBocor` dibaca oleh DECL.
    func warnaAman() -> Color {
        guard NightMode.isOn else { return Color(white: 0.4) }
        return Color(red: 1, green: 0, blue: 0)
    }

    /// Bukan batas blok bagi DECL: hanya `func` yang diakui.
    var warnaBocor: Color {
        Color(red: 0.2, green: 0.9, blue: 0.4)
    }
}
"""

#: Kendali: computed var yang penjaganya sendiri. Wajib HIJAU — gerbang yang
#: menuduh bentuk yang benar akan dimatikan orang lain saat ia berbunyi.
GUARDED_VAR = """import SwiftUI

struct ZzProbeBatas15 {

    func warnaAman() -> Color {
        guard NightMode.isOn else { return Color(white: 0.4) }
        return Color(red: 1, green: 0, blue: 0)
    }

    /// Penjaganya ada di deklarasi yang sama.
    var warnaTerjaga: Color {
        if NightMode.isOn {
            return Color(red: 1, green: 0, blue: 0)
        }
        return Color(white: 0.4)
    }
}
"""

#: Kendali kedua: warna **netral**, yang memang tidak memancarkan ke arah
#: rhodopsin. Aturan 15 sendiri sudah menyatakan netral tidak diperiksa.
NEUTRAL_VAR = """import SwiftUI

struct ZzProbeBatas15 {

    func warnaAman() -> Color {
        guard NightMode.isOn else { return Color(white: 0.4) }
        return Color(red: 1, green: 0, blue: 0)
    }

    /// Netral, jadi bukan emisi.
    var warnaNetral: Color {
        Color(white: 0.5)
    }
}
"""

#: Kendali ketiga: computed var berpenjga diletakkan SEBELUM func. Kalau
#: urutan menentukan hasil, gerbangnya membaca posisi, bukan penjaga.
REVERSED_VAR = """import SwiftUI

struct ZzProbeBatas15 {

    var warnaTerjaga: Color {
        if NightMode.isOn {
            return Color(red: 1, green: 0, blue: 0)
        }
        return Color(white: 0.4)
    }

    func warnaAman() -> Color {
        guard NightMode.isOn else { return Color(white: 0.4) }
        return Color(red: 1, green: 0, blue: 0)
    }
}
"""


def extract_rule():
    """Kode Python Aturan 15 yang sebenarnya, diambil dari `swift-ui-lint.sh`.

    Sengaja bukan salinan: salinan akan hijau selamanya pada gate yang
    berubah di sisinya.
    """
    with open(LINT, encoding="utf-8") as handle:
        text = handle.read()
    if START_MARK not in text:
        raise SystemExit(
            f"tanda awal Aturan 15 tidak ditemukan di {LINT} — nama judul "
            "berubah, dan harness ini harus ikut, bukan diam-diam nol ukuran")
    start = text.index(ASSIGN)
    if start < 0 or START_MARK not in text[:start]:
        raise SystemExit(
            "penugasan `color_guard=$(python3 - <<'PY'` tidak mengikuti judul "
            "Aturan 15 — bentuk pemanggilannya berubah")
    start = start + len(ASSIGN)
    end = text.index(END_MARK, start)
    return text[start:end]


def run_rule(tree):
    """Jalankan kode Aturan 15 di dalam `tree`; kembalikan (exit, keluaran)."""
    script = extract_rule()
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False,
                                     encoding="utf-8") as handle:
        handle.write(script)
        path = handle.name
    try:
        proc = subprocess.run([sys.executable, path], cwd=tree,
                              capture_output=True, text=True)
        return proc.returncode, (proc.stdout or "") + (proc.stderr or "")
    finally:
        os.unlink(path)


def make_tree(extra=""):
    """Salin pohon `Apps/` produksi lalu suntikkan `extra` di Shared/."""
    tree = tempfile.mkdtemp(prefix="batas15-")
    proc = subprocess.run(["cp", "-r", os.path.join(ROOT, "Apps"),
                          os.path.join(tree, "Apps")],
                         capture_output=True, text=True)
    if proc.returncode != 0:
        raise SystemExit(f"gagal menyalin Apps/: {proc.stderr}")
    if extra:
        with open(os.path.join(tree, "Apps", "Shared",
                               "ZzProbeBatas15.swift"), "w",
                  encoding="utf-8") as handle:
            handle.write(extra)
    return tree


def detect(code):
    """Keluaran ini berarti gate berbunyi (ada temuan)."""
    return ("tanpa penjaga" in code) or ("di fungsi yang sama" in code)


def main():
    failures = []

    # ── baseline: pohon produksi apa adanya ────────────────────────────────
    base_tree = make_tree("")
    try:
        code, out = run_rule(base_tree)
    finally:
        subprocess.run(["rm", "-rf", base_tree])
    if code == 0 and not detect(out):
        print("OK   baseline: pohon produksi hijau")
    else:
        failures.append("baseline: pohon produksi merah — harness salah, "
                        "bukan kodenya")
        print("GAGAL baseline: pohon produksi merah")
        print(out)

    # ── keadaan yang disuntikkan ───────────────────────────────────────────
    cases = [
        ("computed var hijau/biru tanpa penjaga", LEAKY_VAR, True),
        ("computed var dengan penjaga sendiri", GUARDED_VAR, False),
        ("computed var warna netral", NEUTRAL_VAR, False),
        ("computed var berpenjga sebelum func", REVERSED_VAR, False),
    ]

    for label, source, want_red in cases:
        tree = make_tree(source)
        try:
            code, out = run_rule(tree)
        finally:
            subprocess.run(["rm", "-rf", tree])
        got_red = code != 0 or detect(out)
        if got_red == want_red:
            print(f"OK   {label:42s} {'MERAH' if want_red else 'HIJAU'}")
        else:
            failures.append(
                f"{label}: {'merah' if got_red else 'hijau'}, "
                f"seharusnya {'merah' if want_red else 'hijau'}")
            print(f"GAGAL {label:42s} "
                  f"{'merah' if got_red else 'hijau'}, "
                  f"seharusnya {'merah' if want_red else 'hijau'}")
            if out.strip():
                print("      keluaran: " + out.strip().splitlines()[0])

    print()
    if failures:
        print(f"{len(failures)} masalah:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("batas deklarasi Aturan 15 mengukur computed property, bukan hanya func")
    return 0


if __name__ == "__main__":
    sys.exit(main())
