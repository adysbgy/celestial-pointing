#!/usr/bin/env python3
"""Buktikan penjaga «sumber produksi bersih» benar-benar berbunyi.

Kenapa harness ini ada.

`mutasi_sumber.require_clean_sources` adalah gerbang baru, dan gerbang baru
selalu hijau pada hari ia ditulis — itu bukan bukti apa pun. Lebih dari itu,
gerbang ini punya bentuk kegagalan yang **persis** yang paling sulit
terlihat: bila ia diam-diam lulus-terbuka (failing open), setiap harness
mutasi kembali ke perilaku lamanya — mengadopsi berkas produksi yang sudah
termutasi sebagai «aslinya», lalu melaporkan «pulih persis» untuk
perbandingan **dengan dirinya sendiri**.

Itu bukan kemungkinan teoretis. Ia sudah terjadi: sebuah harness yang
di-`timeout` pada pukul 17:15 meninggalkan satu baris mutasi hidup di
`Tools/render-visuals.py`, dan `bukti-mutasi-langit-dalam.py` berikutnya
melaporkan 15 kelemahan bukti sekaligus `md5 … -> … (pulih persis)` untuk
berkas yang tidak pernah pulih. Yang berbunyi adalah kelemahan lain, bukan
akarnya; dan bila mutasi yang tertinggal kebetulan tidak mengubah hasil
probe, harness itu akan melaporkan hijau penuh.

Keadaan yang diuji:

  [baseline]                 sumber bersih → penjaga **lulus**, dan itu harus
                             begitu: penjaga yang menyalak pada sumber bersih
                             akan dimatikan orang, dan itu bentuk kegagalan
                             yang tampak seperti ketaatan
  1. satu sumber kotor       penjaga keluar **2** dan **menyebut berkasnya**
  2. yang bersih tidak ikut  pesan penjaga tidak menyalahkan berkas bersih —
                             pesan yang menyalahkan berkas bersih membuat
                             orang memulihkan yang salah
  3. `git diff` gagal        penjaga **tidak** lulus-terbuka; kegagalan git
                             diperlakukan sebagai berhenti, bukan lulus
  4. HEAD tak terbaca        penjaga berhenti **tanpa menuduh berkas bersih**:
                             `git diff --quiet` memakai exit 1 untuk «berkas
                             menyimpang» **dan** untuk «HEAD tidak terbaca»,
                             dan yang kedua pernah menjatuhkan `main`

Berkas yang dimutasi: **dua berkas terlacak yang bersih**, satu di antaranya
disunting sementara lalu dipulihkan di `finally` plus handler
`SIGINT`/`SIGTERM` (pola yang sama dengan `red-lint.sh`). Berkasnya sengaja
**bukan** sumber produksi: harness ini mengukur penjaganya, jadi ia tidak
perlu — dan tidak boleh — menyentuh produksi.
"""

from __future__ import annotations

import os
import shutil
import signal
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

#: Berkas terlacak yang bersih dan tidak dibaca gerbang mana pun. Dipilih dari
#: `Tools/` supaya tidak ada harness lain yang menjalankannya bersamaan, dan
#: bukan `render-visuals.py`/`CelestialVisual*.swift` supaya harness ini tidak
#: pernah bisa merusak sumber produksi kalau ia sendiri dihentikan paksa.
CLEAN = os.path.join(ROOT, "Tools", "sapu-earthshine.py")
DIRTY = os.path.join(ROOT, "Tools", "montage.py")

#: Dijalankan di proses baru. **Tanpa** `try/except SystemExit`: kode keluar
#: penjaganya harus merambat keluar, karena itulah yang diukur. Versi pertama
#: menangkapnya dan selalu keluar 0, jadi seluruh keadaan terbaca "hijau
#: palsu" — dan justru itu kelas cacat yang harness ini ada untuk mencegah.
PROBE = r"""
import sys
sys.path.insert(0, %(tools)r)
import mutasi_sumber
mutasi_sumber.require_clean_sources(%(paths)r)
print("LULUS")
"""

_original = None


def restore(*_):
    if _original is not None:
        with open(DIRTY, "wb") as handle:
            handle.write(_original)
        print(f"\n[sinyal/pemulihan] {os.path.relpath(DIRTY)} dipulihkan.")


def run_probe(paths, env=None, cwd=None):
    """Panggil penjaganya di proses baru → (stdout, stderr, exit).

    `env` dan `cwd` bisa ditimpa supaya harness ini dapat menirukan lingkungan
    yang rusak (mis. `GIT_DIR` yang tidak memuat HEAD) tanpa perlu mengubah
    berkas atau pemiliknya.
    """
    code = PROBE % {"tools": os.path.join(ROOT, "Tools"), "paths": paths}
    proc = subprocess.run([sys.executable, "-c", code],
                          capture_output=True, text=True,
                          cwd=cwd or ROOT, env=env)
    return proc.stdout.strip(), proc.stderr.strip(), proc.returncode


def main():
    global _original
    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    with open(DIRTY, "rb") as handle:
        _original = handle.read()

    failures = []
    try:
        # --- baseline: keduanya bersih → lulus ---
        out, err, code = run_probe([CLEAN, DIRTY])
        if out != "LULUS" or code != 0:
            failures.append(f"[baseline] penjaga menyalak pada sumber bersih "
                            f"(out={out!r}, err={err!r}, exit={code})")
        print(f"{'OK  ' if not failures else 'SALAH'} [baseline] sumber bersih "
              f"→ {out or 'DIAM'} (exit {code})")

        # --- 1 + 2. satu berkas kotor → keluar 2, menyebut hanya yang kotor ---
        with open(DIRTY, "ab") as handle:
            handle.write(b"\n# KOTOR: baris ini membuat berkas menyimpang "
                         b"dari HEAD\n")
        out, err, code = run_probe([CLEAN, DIRTY])
        named_dirty = os.path.relpath(DIRTY) in err
        named_clean = os.path.relpath(CLEAN) in err
        ok1 = code == 2 and named_dirty
        ok2 = not named_clean
        if not ok1:
            failures.append(
                f"1. sumber kotor: exit={code} (butuh 2), menyebut berkas "
                f"kotor={named_dirty}")
        if not ok2:
            failures.append("2. sumber bersih ikut disalahkan oleh pesan "
                            "penjaga")
        print(f"{'OK  ' if ok1 else 'SALAH'} 1. sumber kotor → keluar {code}, "
              f"menyebut berkas kotor: {named_dirty}")
        print(f"{'OK  ' if ok2 else 'SALAH'} 2. sumber bersih tidak ikut "
              f"disalahkan: {not named_clean}")

        restore()
        out, err, code = run_probe([CLEAN, DIRTY])
        if out != "LULUS":
            failures.append(f"pemulihan tidak mengembalikan keadaan bersih "
                            f"(out={out!r}, exit={code})")

        # --- 3. `git diff` gagal → tidak lulus-terbuka ---
        # Dijalankan dari luar repo: `git diff HEAD` keluar 128, bukan 1.
        code_out = PROBE % {"tools": os.path.join(ROOT, "Tools"),
                            "paths": [CLEAN, DIRTY]}
        proc = subprocess.run([sys.executable, "-c", code_out],
                              capture_output=True, text=True, cwd="/")
        ok3 = proc.returncode == 2 and "LULUS" not in proc.stdout
        if not ok3:
            failures.append(f"3. git gagal: exit={proc.returncode} "
                            f"(butuh 2, bukan lulus-terbuka), "
                            f"out={proc.stdout.strip()!r}")
        print(f"{'OK  ' if ok3 else 'SALAH'} 3. `git diff` gagal → berhenti, "
              f"tidak lulus-terbuka (exit {proc.returncode})")

        # --- 4. HEAD tidak terbaca tapi jalurnya sah → JANGAN menyalahkan berkas ---
        #
        # Ini cacat yang menjatuhkan `main` dua kali (9 Okt), dan bentuknya
        # tidak terlihat dari luar: `git diff --quiet HEAD -- <berkas>` memakai
        # **exit 1 untuk dua hal yang berbeda** —
        #
        #     berkas memang menyimpang  → exit 1, stderr kosong
        #     HEAD tidak terbaca        → exit 1, stderr "Could not access 'HEAD'"
        #
        # Penjaga versi pertama hanya membaca exit code-nya, jadi yang kedua
        # terbaca sebagai «berkas kotor». Itu terjadi sungguhan di job Linux:
        # `actions/checkout` menulis `safe.directory` ke HOME **sementara**
        # yang tidak bertahan ke langkah-langkah berikutnya, sehingga `git`
        # menolak repo (dubious ownership) — dan setiap harness mutasi mati
        # dengan pesan yang menuduh `Tools/render-visuals.py` menyimpang,
        # padahal berkasnya byte-identik dengan HEAD. Pesan itu mengirim orang
        # memulihkan berkas yang **sudah** benar.
        #
        # `GIT_DIR` ke direktori kosong menirukan keadaan itu tanpa menyentuh
        # berkas atau pemiliknya: jalurnya tetap sah dan relatif, jadi `rel`
        # benar, tetapi HEAD tidak bisa dibaca.
        bogus = tempfile.mkdtemp(prefix="gIT_DIR-kosong-uji-")
        try:
            env = dict(os.environ, GIT_DIR=bogus)
            out, err, code = run_probe([CLEAN, DIRTY], env=env)
        finally:
            shutil.rmtree(bogus, ignore_errors=True)
        accused = os.path.relpath(DIRTY) in err or os.path.relpath(CLEAN) in err
        ok4 = code == 2 and not accused and "LULUS" not in out
        if not ok4:
            failures.append(
                f"4. HEAD tak terbaca: exit={code} (butuh 2), "
                f"menuduh berkas bersih={accused}, out={out!r}")
        print(f"{'OK  ' if ok4 else 'SALAH'} 4. HEAD tak terbaca → berhenti "
              f"tanpa menuduh berkas bersih (exit {code})")
    finally:
        restore()
        _original = None

    print()
    if failures:
        print(f"{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("4 keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
