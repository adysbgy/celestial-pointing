#!/usr/bin/env python3
"""Bukti bahwa gambar yang **ragu** menyamar lewat penyamaran (blur), dan
bahwa penyamaran itu **terbalikkan** — tanpa menghapus objeknya.

Ini bukan uji model (yang ada di `UncertainBlurTests`, Linux). Ini menanam
cacat ke **port gambar** (`Tools/render-visuals.py`) lalu menjalankan
pemeriksa piksel, supaya cacat yang **hanya tampak di layar** — gambar
ragu yang tetap tajam, atau penyamaran yang mematikan seluruh gambar —
terukur di sini.

Empat keadaan, masing-masing menuduh **nama pemeriksaan tertentu** di
`check-visuals.py`, bukan \"ada yang gagal\":

1. **Penyamaran dimatikan** (blur tidak dipanggil saat ragu) →
   `uncertain_object_is_blurred` MENGHARAP merah. Jika tidak, gambar ragu
   tetap tajam — kelas cacat yang persis dengan \"visual mengklaim identitas
   saat engine ragu\", hanya lewat ketajaman, bukan lewat ciri.
2. **Penyamaran diterapkan ke semua jenis** (termasuk Bulan/bintang) →
   `uncertain_blur_excludes_moon` MENGHARAP merah (Bulan kehilangan fakta
   tanggalnya, `check_moon_phase_survives_uncertainty` jadi palsu), DAN
   `uncertain_blur_is_reversible` MENGHARAP merah (bintang dijam menjadi
   titik yang hilang).
3. **Penyamaran tidak terbalikkan** (hilang objek, bukan samar) →
   `uncertain_blur_is_reversible` MENGHARAP merah.
4. **Radius nol** (samar yang tidak menyamar) → `uncertain_object_is_blurred`
   MENGHARAP merah.

Kontrol negatif: pohon utuh hijau pada keempat pemeriksaan.

Batas yang diakui: `blur` SwiftUI memakai Gaussian ala CoreImage; port ini
memakai kotak sejajar-sumbu. Yang diukur adalah **jarak antara dua kanvas
milik model yang sama**, bukan kesamaan dengan Apple.

Batas eksekusi: pemeriksa piksel (`check-visuals.py` tanpa `--only`) tetap
menjalankan **seluruh** katalog, jadi satu jalannya butuh puluhan menit. Bila
proses dihentikan di tengah (timeout CI, SIGINT), `finally` tidak kejangkau —
sumber produksi tertinggal ter-mutasi, dan jalankan berikutnya gagal dengan
"ANCHOR TIDAK DITEMUKAN" yang menyesatkan. Itulah kelas yang dijaga
`require_clean_sources` di CI; di sini sumbernya dipulihkan juga lewat
handler `SIGINT`/`SIGTERM` (SIGKILL tetap bisa melewati keduanya — batas
yang diketahui, bukan klaim kebal).
"""
import os
import signal
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PORT = os.path.join(ROOT, "Tools", "render-visuals.py")
CHECK = os.path.join(ROOT, "Tools", "check-visuals.py")

# Penanda yang dipakai pemeriksa piksel untuk menuduh — dijaga sinkron dengan
# `check-visuals.py` (lihat `check_uncertain_blur_*`).
EXPECTED_FAILING = {
    "uncertain_object_is_blurred",
    "uncertain_blur_excludes_moon",
    "uncertain_blur_is_reversible",
}


def _edit(port_source, find, replace):
    if find not in port_source:
        raise SystemExit(f"ANCHOR TIDAK DITEMUKAN: {find[:60]!r}")
    return port_source.replace(find, replace, 1)


def _run_check(state_label):
    # Jalankan pemeriksaan yang relevan lewat `--only` agar cepat dan tidak
    # menarik dependensi render yang jauh. `check-visuals.py` mencetak
    # "GAGAL <nama>  <detail>" untuk tiap yang gagal.
    env = dict(os.environ)
    proc = subprocess.run(
        [sys.executable, CHECK, "--check", "--only",
         "uncertain_object_is_blurred uncertain_blur_excludes_moon "
         "uncertain_blur_is_reversible"],
        capture_output=True, text=True, cwd=ROOT, env=env)
    out = proc.stdout + proc.stderr
    failing = set(re.findall(r"GAGAL\s+([a-z_]+)", out))
    return failing, out


def _restore(path, original):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(original)


def main():
    with open(PORT, encoding="utf-8") as handle:
        original = handle.read()

    states = []

    # Pulihkan sumber bila dihentikan di tengah jalan (timeout CI, SIGINT).
    # `finally` di bawah tidak kejangkau oleh SIGTERM/SIGINT, jadi tanpa ini
    # mutant tertinggal hidup — kelas yang dijaga `require_clean_sources`.
    def _restore_now(*_):
        _restore(PORT, original)
        sys.exit(143 if _[0] == signal.SIGTERM else 130)
    signal.signal(signal.SIGINT, _restore_now)
    signal.signal(signal.SIGTERM, _restore_now)

    # Keadaan 1: penyamaran dimatikan sepenuhnya.
    off = _edit(original,
                "    if kw.get(\"is_confirmed\") is False and uncertain_blur_allows(kind):\n",
                "    if False and kw.get(\"is_confirmed\") is False and uncertain_blur_allows(kind):\n")
    states.append(("penyamaran dimatikan", off, {"uncertain_object_is_blurred"}))

    # Keadaan 2: penyamaran diterapkan ke SEMUA jenis.
    allk = _edit(original,
                "    if kw.get(\"is_confirmed\") is False and uncertain_blur_allows(kind):\n",
                "    if kw.get(\"is_confirmed\") is False:\n")
    states.append(("penyamaran semua jenis", allk,
                   {"uncertain_blur_excludes_moon", "uncertain_blur_is_reversible"}))

    # Keadaan 3: penyamaran mengganti objek dengan latar (tidak terbalikkan).
    kill = _edit(original,
                 "        canvas.box_blur(uncertain_blur_radius_points(size))",
                 "        canvas.buf = [[0.0,0.0,0.0] for _ in canvas.buf]")
    states.append(("penyamaran menghapus objek", kill,
                   {"uncertain_blur_is_reversible"}))

    # Keadaan 4: radius nol.
    zero = _edit(original,
                 "    return size * VIEW_UNCERTAIN_BLUR_FRACTION / 2.0",
                 "    return 0.0")
    states.append(("radius nol", zero, {"uncertain_object_is_blurred"}))

    results = []
    try:
        for label, src, expect in states:
            with open(PORT, "w", encoding="utf-8") as handle:
                handle.write(src)
            failing, out = _run_check(label)
            unexpected = failing - expect
            # Yang diharapkan gagal memang gagal?
            matched = expect & failing
            ok = (matched == expect) and not unexpected
            results.append((label, ok, matched, unexpected, failing, expect))
    finally:
        _restore(PORT, original)

    # Kontrol negatif: pohon utuh.
    failing, out = _run_check("pohon utuh")
    baseline_ok = not (failing & EXPECTED_FAILING)

    print("=== bukti-mutasi-objek-samar ===")
    all_ok = True
    for label, ok, matched, unexpected, failing, expect in results:
        status = "OK" if ok else "GAGAL"
        all_ok = all_ok and ok
        print(f"  [{status}] {label}: diharap {sorted(expect)} "
          f"terpenuhi {sorted(matched)} tak-diharap {sorted(unexpected)} "
          f"(gagal={sorted(failing)})")
    print(f"  [{'OK' if baseline_ok else 'GAGAL'}] pohon utuh: "
          f"pemeriksaan tidak gagal tanpa sebab ({sorted(failing & EXPECTED_FAILING)})")
    if not (all_ok and baseline_ok):
        raise SystemExit(1)
    print("  SEMUA Keadaan sesuai harapan.")


if __name__ == "__main__":
    main()
