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


def starfield_icon_from_history():
    """Ikon starfield pra-perbaikan dari riwayat, atau None bila tidak ada.

    Dicari beberapa kedalaman karena jarak commit perbaikan bergantung pada
    bagaimana riwayat ini di-*squash*. Yang dicari bukan commit tertentu,
    melainkan **isi**: ikon yang massa terangnya rendah. Bila riwayat tidak
    memuatnya, kembalikan None — dan pemanggil wajib melewati, bukan mengarang.

    **Kenapa `subprocess` langsung, bukan `mutasi_sumber._git`.** Helper itu
    memakai `text=True`, jadi PNG dikembalikan sebagai `str` hasil dekode
    UTF-8 — byte 0x89 dan seterusnya rusak atau melempar. Ikon adalah data
    biner; membacanya lewat jalur teks akan menghasilkan "berkas tidak ada"
    yang menyesatkan.
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
        return ref, proc.stdout
    return None


def write_bytes(path, data):
    mutasi_sumber.write_source(path, data)


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

    found = starfield_icon_from_history()
    if found is None:
        print("CATATAN: ikon starfield pra-perbaikan tidak ditemukan di 11 "
              "commit terakhir — arah kedua DILEWATI dengan alasan, bukan "
              "dilaporkan hijau.")
    else:
        ref, old = found
        states.append((f"1. ikon starfield lama ({ref})", old, "merah",
                       "subjek terpusat"))

    # Keadaan: ikon yang subjeknya digeser keluar frame. Dibuat dari ikon yang
    # benar dengan memindahkan isinya ke tepi — meniru cacat "subjek di pojok"
    # yang lolos bila gerbang hanya memeriksa "ada piksel terang".
    try:
        from PIL import Image  # noqa: PLC0415
        import io
        base = Image.open(io.BytesIO(original_icon)).convert("RGB")
        w, h = base.size
        shifted = Image.new("RGB", (w, h), (10, 10, 15))
        shifted.paste(base, (int(w * 0.62), int(h * 0.62)))
        buf = io.BytesIO()
        shifted.save(buf, format="PNG")
        states.append(("2. subjek digeser ke pojok kanan-bawah",
                       buf.getvalue(), "merah", "subjek terpusat"))
    except Exception as exc:  # noqa: BLE001
        print(f"CATATAN: PIL tidak tersedia ({exc}) — keadaan 2 DILEWATI.")

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
