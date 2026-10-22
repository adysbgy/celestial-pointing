#!/usr/bin/env python3
"""Bukti bahwa gerbang ikon app **bisa gagal** — bukan hanya bisa hijau.

Kenapa berkas ini ada.

`check_app_icon_has_a_focal_mark` di `Tools/check-visuals.py` mengukur ikon
yang benar-benar dikirim ke App Store. Gerbang yang hanya pernah dilihat hijau
belum membuktikan apa pun: ia bisa hijau karena ikonnya bagus, atau karena
ambangnya terlalu longgar, atau karena ia membaca berkas yang salah. Berkas ini
membedakan ketiganya dengan **mengganti isi berkas ikon**, lalu menjalankan
gerbang yang sama di **proses baru**.

Kenapa arah kedua memakai ikon lama yang asli, bukan ikon yang dibuat-buat.

Ikon pra-perbaikan diambil dari `git show HEAD~:<path>` (lewat
`mutasi_sumber.git_show`) hanya bila HEAD~ memang memuat starfield lama. Bila
tidak, arah kedua dilewati dengan **alasan tertulis** — bukan dilaporkan hijau.
Alasannya: ikon sintetis yang kebetulan lolos ambang akan membuat harness ini
melaporkan "gerbangnya bekerja" atas bahan yang tidak pernah dikirim, dan itu
kelas kebohongan yang sama dengan gerbang yang mengukur gambar yang tidak
pernah tampil.

Kenapa setiap keadaan menulis ulang berkas lalu memulihkannya.

Gerbang membaca **dari disk**, jadi satu-satunya cara menguji reaksinya adalah
mengubah disk. `mutasi_sumber.write_source` menulis atomik dan
`restore_verified` membaca ulang byte demi byte; md5 dibandingkan di akhir
supaya berkas produksi terbukti pulih persis, bukan "seharusnya pulih".

Batas yang dinyatakan.

Yang dibuktikan: gerbang **membedakan** ikon bersubjek dari ikon bising, dan
ambangnya tidak sekadar lolos untuk apa pun. Yang **tidak** dibuktikan:
keindahan ikon, kesesuaiannya dengan merek, atau bahwa gerbang ini akan
menangkap setiap cacat ikon di masa depan.
"""

from __future__ import annotations

import hashlib
import os
import subprocess
import sys

sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

import mutasi_sumber  # noqa: E402

CHECK = os.path.join(ROOT, "Tools/check-visuals.py")
ICON_REL = ("Apps/PointAndKnowiOS/Resources/Assets.xcassets/"
            "AppIcon.appiconset/AppIcon-1024.png")
ICON = os.path.join(ROOT, ICON_REL)
GATE = "check_app_icon_has_a_focal_mark"

#: Dijalankan di proses baru: impor ulang `check-visuals` dari disk.
PROBE = r"""
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cv_probe", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
results = []
m.check_app_icon_has_a_focal_mark(results)
if not results:
    print("TIDAK ADA")
for r in results:
    print(("OK   " if r.ok else "GAGAL") + " " + r.name + "  " + r.detail)
"""


def run_probe():
    """Jalankan gerbang atas ikon yang ada di disk → (verdict, baris)."""
    proc = subprocess.run([sys.executable, "-c", PROBE, CHECK],
                          capture_output=True, text=True, cwd=ROOT)
    if proc.returncode != 0:
        return None, [proc.stderr.strip().splitlines()[-1] if proc.stderr.strip()
                      else f"exit {proc.returncode}"]
    lines = [ln.strip() for ln in proc.stdout.splitlines() if ln.strip()]
    if not lines or lines[0] == "TIDAK ADA":
        return None, lines or ["(tanpa hasil)"]
    verdicts = {ln.split(" ", 1)[0] for ln in lines}
    # Gerbang ini melaporkan dua pemeriksaan; keduanya harus sepakat.
    if "GAGAL" in verdicts:
        return "merah", lines
    return ("hijau" if verdicts == {"OK"} else None), lines


def previous_icon_from_history(current):
    """Byte ikon pada versi **sebelum** ikon yang sekarang, atau None.

    **Kenapa "berbeda dari sekarang", bukan "commit ke-N".** Versi pertama
    fungsi ini mengambil PNG pertama yang ditemukan menelusuri `HEAD~1`,
    `HEAD~2`, …; setelah perbaikan ikon di-commit, `HEAD~1` **adalah** ikon
    baru, jadi keadaan 1 mengukur ikon yang sama dengan baseline dan harness
    melaporkan "diharapkan merah, terukur hijau". Gejalanya menyesatkan: ia
    tampak seperti gerbangnya yang terlalu longgar, padahal yang salah adalah
    bahan ujinya.

    **Kenapa bukan "cari yang massa terangnya rendah".** Itu memilih bahan
    uji memakai **metrik yang sedang diuji**, jadi keadaannya lolos secara
    lingkar: gerbang selalu menemukan contoh yang pasti merah. Yang dipakai
    di sini adalah definisi yang tidak bergantung pada metrik — versi
    sebelumnya yang isinya berbeda.

    `subprocess` langsung, bukan `mutasi_sumber._git`: helper itu memakai
    `text=True`, dan PNG lewat jalur teks rusak atau melempar.
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for depth in range(1, 12):
        ref = f"HEAD~{depth}"
        proc = subprocess.run(
            ["git", "-c", f"safe.directory={root}", "show", f"{ref}:{ICON_REL}"],
            capture_output=True, cwd=ROOT)
        if proc.returncode != 0 or len(proc.stdout) < 100:
            continue
        if not proc.stdout.startswith(b"\x89PNG"):
            continue
        if proc.stdout == current:
            continue          # commit yang tidak mengubah ikon
        return ref, proc.stdout
    return None


def write_bytes(path, data):
    mutasi_sumber.write_source(path, data)


def decode_icon(data):
    """(lebar, tinggi, baris RGBA) dari byte PNG — lewat dekoder repo sendiri.

    Dipakai untuk membuat bahan uji keadaan 2 tanpa Pillow. `decode_png` di
    `check-visuals.py` bekerja atas **jalur berkas** dan hanya menerima RGBA8;
    itu justru yang diinginkan di sini, karena bahan uji jadi pasti berbentuk
    sama dengan yang dibaca gerbang.
    """
    import importlib.util
    import tempfile
    spec = importlib.util.spec_from_file_location("cv_icon", CHECK)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"tidak bisa memuat {CHECK} sebagai modul")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as handle:
        handle.write(data)
        path = handle.name
    try:
        return module.decode_png(path)
    finally:
        os.unlink(path)


def main():
    mutasi_sumber.require_clean_sources([CHECK])
    if not os.path.exists(ICON):
        print(f"GERBANG: ikon tidak ada di {ICON_REL} — harness ini tidak "
              "mengukur apa pun.", file=sys.stderr)
        return 2

    original_icon = open(ICON, "rb").read()
    baseline_md5 = hashlib.md5(original_icon).hexdigest()

    def restore():
        mutasi_sumber.restore_verified(ICON, original_icon)

    import signal

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] ikon produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    failures = []
    states: list[tuple[str, bytes, str, str | None]] = [
        ("[baseline] ikon yang dikirim", original_icon, "hijau", None)]

    found = previous_icon_from_history(original_icon)
    if found is None:
        print("CATATAN: ikon versi sebelumnya tidak ditemukan di 11 commit "
              "terakhir — arah kedua DILEWATI dengan alasan, bukan "
              "dilaporkan hijau.")
    else:
        ref, old = found
        states.append((f"1. ikon starfield lama ({ref})", old, "merah",
                       "subjek terpusat"))

    # Keadaan: ikon yang subjeknya digeser keluar frame. Dibuat dari ikon yang
    # benar dengan memindahkan isinya ke tepi — meniru cacat "subjek di pojok"
    # yang lolos bila gerbang hanya memeriksa "ada piksel terang".
    #
    # **Kenapa tidak memakai PIL.** CI `engine-tests.yml` hanya memasang
    # `python3`; Pillow tidak ada di sana, jadi keadaan ini akan **dilewati**
    # di CI — yaitu tepat di tempat bukti itu dibutuhkan. Pergeseran piksel
    # cukup ditulis dengan `bytes` dan pembungkus PNG yang sudah ada di
    # `make_app_icons.py`, dan hasilnya deterministik.
    try:
        import make_app_icons  # noqa: PLC0415
        width, height, rows = decode_icon(original_icon)
        dx, dy = int(width * 0.62), int(height * 0.62)
        blank = bytes((10, 10, 15, 255)) * width
        shifted_rows = []
        for y in range(height):
            src = y - dy
            if src < 0:
                shifted_rows.append(blank)
                continue
            row = rows[src]
            shifted_rows.append(bytes(dx * 4) + row[: (width - dx) * 4])
        shifted_png = make_app_icons._png(width, height, b"".join(shifted_rows))
        states.append(("2. subjek digeser ke pojok kanan-bawah",
                       shifted_png, "merah", "subjek terpusat"))
    except Exception as exc:  # noqa: BLE001
        print(f"CATATAN: keadaan 2 DILEWATI ({type(exc).__name__}: {exc}).")

    try:
        for label, content, want, must_name in states:
            restore()
            write_bytes(ICON, content)
            verdict, lines = run_probe()
            detail = " | ".join(lines)
            ok = verdict == want
            if ok and must_name is not None:
                ok = must_name in detail
            print(f"{'OK  ' if ok else 'SALAH'} {label}: diharapkan {want}, "
                  f"terukur {verdict}")
            print(f"       {detail[:200]}")
            if not ok:
                failures.append(f"{label}: diharapkan {want}, terukur {verdict}")
    finally:
        restore()

    after = hashlib.md5(open(ICON, "rb").read()).hexdigest()
    print(f"\nmd5 {ICON_REL}: {baseline_md5} -> {after} "
          f"({'pulih persis' if after == baseline_md5 else 'TIDAK PULIH'})")
    if after != baseline_md5:
        failures.append("ikon produksi tidak pulih persis")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(states)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
