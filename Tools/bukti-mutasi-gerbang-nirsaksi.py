#!/usr/bin/env python3
"""Buktikan enam gerbang piksel tanpa-bukti benar-benar berbunyi.

Kenapa harness ini ada.

Audit `check-visuals.py` menemukan **enam** gerbang piksel yang tidak punya
bukti mutasi sama sekali — tidak dirujuk satu pun dari dua puluh satu harness
`bukti-mutasi-*.py` di disk. Enam itu bukan gerbang pinggiran: masing-masing
menjaga salah satu janji paling keras di app ini.

  - `check_night_mode_purity`          mode malam: hijau & biru **nol**
  - `check_night_mode_never_exceeds_day` malam tidak pernah lebih terang
  - `check_jupiter_bands_reach_the_limb` pita Jupiter menjangkau tepi bola
  - `check_mars_caps_touch_the_limb`   kutub Mars menempel tepi, bukan mengambang
  - `check_unknown_phase_is_not_a_new_moon` fase tak dihitung bukan bulan baru
  - (`check_bands_follow_the_limb_arc` ikut karena satu kelas dengan pita)

Keenamnya hijau pada hari ditulis, dan itu bukan bukti apa pun — gerbang
gambar baru selalu hijau. Yang membedakan gerbang yang menjaga dari gerbang
yang hanya *terlihat* menjaga adalah apakah ia bisa dibuat merah, dan merah
pada keadaan yang memang salah.

Yang diukur tiap keadaan adalah **pemeriksaan bernama**, bukan sekadar "ada
yang merah". Alasannya bukan kerapian: keadaan 5 (fase tak diketahui kembali
jadi piringan gelap rata) memang membuat satu pemeriksaan merah sementara
pemeriksaan **pertama** di fungsi yang sama tetap hijau. Kalau harness ini
hanya menuntut "ada yang merah", ia tidak akan pernah bisa membedakan
pemeriksaan mana yang menangkap cacatnya — dan justru perbedaan itulah
temuannya (lihat keadaan 5 di bawah).

Berkas sumber produksi (`Tools/render-visuals.py`) dimutasi dengan sengaja
lalu dipulihkan di `finally` per keadaan, plus handler `SIGINT`/`SIGTERM`:
`SIGKILL` melewati `finally` dan meninggalkan mutasi hidup.

Pakai:
    python3 Tools/bukti-mutasi-gerbang-nirsaksi.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

RENDER = os.path.join(ROOT, "Tools", "render-visuals.py")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk.
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

# **Dua tingkat verdict, dan itu bukan kerapian.**
#
# `STATES` menuntut dua jenis nama sekaligus: nama **pemeriksaan** (fungsi
# `check_*`) dan nama **hasil** di dalamnya. Versi pertama hanya mencetak
# nama hasil, sehingga setiap kunci berbentuk fungsi tidak pernah muncul dan
# seluruh tujuh keadaan melaporkan "TIDAK ADA" -- harness yang tidak akan
# pernah bisa hijau, di langkah CI yang tidak pernah dijalankan (alur
# kerjanya masih di working tree).
#
# Tingkat fungsi **dibutuhkan** oleh temuan keadaan 6: `check_unknown_...`
# harus merah (ada hasil yang gagal di dalamnya) sementara hasil pertama
# fungsi itu tetap hijau. Tanpa baris tingkat fungsi, pembeda "warna salah"
# dari "warna hilang" itu tidak bisa dinyatakan.
#
# Hijau tingkat fungsi = pemeriksaannya **ada** DAN semuanya lolos. Himpunan
# kosong sengaja **bukan** hijau: gerbang yang hijau karena tidak mengukur
# apa pun adalah kelas cacat yang seluruh repo ini kejar, dan di sini ia
# akan tampak sebagai pemeriksaan yang lulus tanpa satu pun hasil.
for name in sys.argv[2].split(","):
    results = []
    getattr(C, name)(results)
    ok = bool(results) and all(r.ok for r in results)
    print(("OK   " if ok else "GAGAL") + " " + name)
    for r in results:
        print(("OK   " if r.ok else "GAGAL") + " " + r.name)
"""

# ── Jangkar di dalam port ────────────────────────────────────────────────
# Mode malam: dua fungsi yang menjanjikan pemurnian kanal.
NIGHT_SURFACE_PURE = "    return (b, 0.0, 0.0)"
NIGHT_SURFACE_TINTED = "    return (b, 0.0, 0.2)"
NIGHT_SHADOW_PURE = ("    return (min(1, max(0, day[0])) * NIGHT_SHADOW_FRACTION,"
                     " 0.0, 0.0)")
NIGHT_SHADOW_TINTED = ("    return (min(1, max(0, day[0])) * NIGHT_SHADOW_FRACTION,"
                       " 0.2, 0.0)")
NIGHT_FLOOR = "NIGHT_FLOOR_BRIGHTNESS = 0.35"
NIGHT_FLOOR_TOO_BRIGHT = "NIGHT_FLOOR_BRIGHTNESS = 1.6"

# Pita Jupiter: cacat aslinya adalah kosinus, bukan keliling bola.
# `band_half_width(height)` dipanggil dengan ketinggian pita, jadi bentuk
# lamanya (`cos((t - 0.5) · pi · 0.92)` dengan `t = (y + 1) / 2`) setara
# dengan `cos((y / 2) · pi · 0.92)`. Ditulis begitu supaya yang dikembalikan
# adalah cacat yang **dinamai** docstring gerbangnya, bukan bentuk lain yang
# kebetulan juga salah.
BAND_ARC_HEAD = ('def band_half_width(height):\n'
                 '    """Port `CelestialVisual.bandHalfWidthAt(height:)`'
                 ' — tepi bola di ketinggian.')
BAND_ARC_COSINE = ('def band_half_width(height):\n'
                   '    return math.cos((height / 2.0) * math.pi * 0.92)\n'
                   '    """Port `CelestialVisual.bandHalfWidthAt(height:)`'
                   ' — tepi bola di ketinggian.')

# Kutub Mars: cacat aslinya lebar tetap 0.55 R, mengambang di dalam piringan.
CAPS_FROM_LIMB = "    half_width = math.sqrt(max(0.0, 1 - pinch_y * pinch_y))"
CAPS_FIXED = "    half_width = 0.55"

# Fase tak diketahui: cacat aslinya piringan gelap rata — identik dengan
# bulan baru sejauh mata pengguna.
UNKNOWN_SPHERE = ("        _fill_moon_sphere(canvas, cx, cy, radius, unknown,"
                  " night_mode)")
UNKNOWN_FLAT = "        canvas.disc(cx, cy, radius, shadow_fn(unlit, night_mode))"

PURITY = "check_night_mode_purity"
NEVER_BRIGHTER = "check_night_mode_never_exceeds_day"
BAND_REACH = "check_jupiter_bands_reach_the_limb"
BAND_ARC = "check_bands_follow_the_limb_arc"
CAPS = "check_mars_caps_touch_the_limb"
UNKNOWN = "check_unknown_phase_is_not_a_new_moon"

HIJAU = "hijau"
MERAH = "merah"

ALL = ",".join((PURITY, NEVER_BRIGHTER, BAND_REACH, BAND_ARC, CAPS, UNKNOWN))

# (nama keadaan, [(cari, ganti), ...] atau None, {nama pemeriksaan: harapan})
STATES = [
    ("[baseline]", None,
     {PURITY: HIJAU, NEVER_BRIGHTER: HIJAU, BAND_REACH: HIJAU,
      BAND_ARC: HIJAU, CAPS: HIJAU, UNKNOWN: HIJAU}),

    # ── 1. Mode malam tidak memurnikan: kanal biru dibiarkan 0.2 ─────────
    #
    # Janji produknya adalah "hijau & biru **nol**", bukan "kecil". Satu
    # kanal biru yang bocor membatalkan alasannya (rhodopsin) tanpa
    # mengubah apa pun yang terlihat di layar.
    #
    # **Kedua pemeriksaan memerah, dan versi pertama harness ini salah
    # mengira tidak.** Harapannya dulu `NEVER_BRIGHTER: HIJAU` dengan alasan
    # "yang berubah hanya kanal biru, dan pemeriksaan itu membaca kanal
    # merah". Alasan itu tidak benar tentang kodenya:
    # `check_night_mode_never_exceeds_day` membandingkan
    # `luminance_field`, yaitu Rec. 709 — `0.2126 R + 0.7152 G + 0.0722 B`.
    # Kanal biru berbobot, jadi kebocoran 0.2 menaikkan luminans sebesar
    # `0.0722 x 0.2 x 255 = 3.7`, dan terukur persis itu: 12 kasus "ragu"
    # memerah dengan puncak +3.7. Kasus ragu yang memerah dan yang terkunci
    # tidak, karena pada kasus ragu malam dan siang nyaris sama terang
    # (bola netral + samaran), sehingga 3.7 cukup untuk melewatinya.
    #
    # Jadi kedua gerbang memang menyala bersama di sini — dan itu benar:
    # satu kebocoran biru melanggar **dua** janji sekaligus (kanal harus nol,
    # malam tidak boleh lebih terang). Pemisahan keduanya dibuktikan keadaan
    # 3, arah sebaliknya: lantai dinaikkan membuat `NEVER_BRIGHTER` merah
    # sementara kemurnian tetap hijau. Menuntut satu keadaan membuktikan
    # keduanya sekaligus adalah yang membuat harapan lama salah.
    ("1. mode malam tidak memurnikan (kanal biru 0.2)",
     [(NIGHT_SURFACE_PURE, NIGHT_SURFACE_TINTED)],
     {PURITY: MERAH, NEVER_BRIGHTER: MERAH,
      "malam murni: planet-mercury-confirmed": MERAH,
      "malam murni: moon-full": MERAH,
      "malam murni: sun": MERAH,
      "malam <= siang: planet-jupiter-uncertain": MERAH}),

    # ── 2. Jalur **bayangan** juga berwarna ──────────────────────────────
    #
    # Yang membedakannya dari keadaan 1: hanya benda yang menggambar aksen
    # bayangan (`moonUnlit`, planet netral, kabut langit dalam) yang boleh
    # memerah. Bola planet yang **terkunci** tidak menggambar bayangan
    # sama sekali, jadi ia harus tetap hijau — dan itu membuktikan mutasinya
    # memang menyentuh jalur bayangan, bukan seluruh gambar.
    #
    # **`planet-jupiter-bare` dulu diharapkan merah di sini, dan itu salah.**
    # Kasus itu bukan keadaan produksi: ia bola berpalet tanpa ciri, dipakai
    # sebagai pengurang bentuk. Ia tidak pernah memanggil jalur bayangan —
    # diukur dengan menghitung pemanggilan `night_shadow` per kasus:
    #
    #     planet-jupiter-bare          0
    #     planet-jupiter-confirmed     0
    #     planet-saturn-confirmed      1   (bayangan cincin)
    #     moon-full                    1
    #
    # Nol pemanggilan berarti tidak ada yang bisa dibocorkan, jadi hijau di
    # sini adalah hasil yang **benar** dan harapan merahnya yang keliru.
    # Penggantinya `planet-saturn-confirmed`: satu-satunya planet terkunci
    # yang benar-benar menggambar bayangan (cincin), sehingga ia membuktikan
    # hal yang sama tanpa meminta kasus pembanding berperilaku seperti
    # keadaan produksi.
    ("2. jalur bayangan mode malam berwarna (hijau 0.2)",
     [(NIGHT_SHADOW_PURE, NIGHT_SHADOW_TINTED)],
     {PURITY: MERAH,
      "malam murni: planet-jupiter-bare": HIJAU,
      "malam murni: moon-full": MERAH,
      "malam murni: planet-saturn-confirmed": MERAH,
      "malam murni: planet-jupiter-confirmed": HIJAU}),

    # ── 3. Lantai kecerahan malam dinaikkan melewati siang ───────────────
    #
    # Arah sebaliknya dari keadaan 1 & 2: di sini kanal merah yang berubah,
    # jadi "malam tidak lebih terang dari siang" yang harus berbunyi, dan
    # kemurnian kanal tetap hijau (warnanya masih merah murni).
    ("3. lantai malam melewati siang (0.35 -> 1.6)",
     [(NIGHT_FLOOR, NIGHT_FLOOR_TOO_BRIGHT)],
     {NEVER_BRIGHTER: MERAH, PURITY: HIJAU,
      "malam <= siang: planet-mercury-confirmed": MERAH,
      "malam <= siang: moon-full": MERAH}),

    # ── 4. Pita Jupiter kembali ke kosinus (cacat 0.19 R) ────────────────
    #
    # Dua gerbang sekaligus, karena keduanya menamai cacat yang sama dari
    # sisi berbeda: "menjangkau tepi" mengukur jarak, "mengikuti busur limb"
    # mengukur bentuknya. Yang pertama bisa lolos kalau pitanya kebetulan
    # lebar di ketinggian sampelnya; yang kedua tidak bisa.
    #
    # **Pita 0 dulu diharapkan hijau di sini, dan itu keliru.** Dugaan yang
    # mendasarinya masuk akal — pita kutub paling sempit, jadi mungkin ia
    # sudah menyentuh tepi karena sempitnya — tetapi terukur sebaliknya.
    # Dengan bentuk kosinus, pita 0 berhenti di 0.325 R sementara bola di
    # baris yang diukur 0.519 R: **19.4% R di dalam tepi**, hampir dua kali
    # lipat ambangnya (2% R). Justru pita 3 (khatulistiwa) satu-satunya yang
    # hijau, karena di sana kosinus dan `sqrt(1-y^2)` bertemu di 1.0 —
    # 0.5% R, hanya anti-aliasing.
    #
    # Jadi ketujuh pita memerah bersama; yang membuktikan kedua gerbang
    # mengukur hal berbeda bukan "sebagian hijau", melainkan angka yang
    # dilaporkan: pita 3 hijau di **kedua** gerbang, dan galatnya naik dari
    # pusat ke kutub (0.5% → 19.4%) hanya di gerbang jangkauan.
    ("4. tepi pita Jupiter kembali ke kosinus",
     [(BAND_ARC_HEAD, BAND_ARC_COSINE)],
     {BAND_REACH: MERAH, BAND_ARC: MERAH,
      "pita Jupiter 2 menjangkau tepi bola": MERAH,
      "pita Jupiter 2 mengikuti busur limb (tali busur, bukan elips)": MERAH,
      "pita Jupiter 0 menjangkau tepi bola": MERAH,
      "pita Jupiter 3 menjangkau tepi bola": HIJAU,
      "pita Jupiter 3 mengikuti busur limb (tali busur, bukan elips)": HIJAU}),

    # ── 5. Kutub Mars kembali lebar tetap 0.55 R ─────────────────────────
    ("5. kutub Mars kembali lebar tetap 0.55 R",
     [(CAPS_FROM_LIMB, CAPS_FIXED)],
     {CAPS: MERAH,
      "kutub Mars menyentuh tepi bola di baris pusatnya": MERAH}),

    # ── 6. Fase tak diketahui kembali jadi piringan gelap rata ───────────
    #
    # Keadaan ini yang paling banyak mengajarkan. Pemeriksaan **pertama**
    # ("bukan bulan baru") tetap **hijau** di sini — karena piringan gelap
    # yang digambar masih membawa earthshine, sehingga ia tetap berbeda dari
    # `moon-new`. Jadi pemeriksaan itu, sendirian, tidak menangkap cacat yang
    # dinamai judulnya sendiri. Yang menangkapnya adalah pemeriksaan ketiga:
    # piringan tak-diketahui harus berada **di antara** gelap dan terang, dan
    # piringan gelap rata berada di bawahnya.
    #
    # Kedua harapan itu ditulis apa adanya, bukan hanya "ada yang merah":
    # tanpa baris HIJAU ini, harness akan melaporkan bahwa "bukan bulan
    # baru" menangkap cacatnya, dan itu salah.
    ("6. fase tak diketahui kembali jadi piringan gelap rata",
     [(UNKNOWN_SPHERE, UNKNOWN_FLAT)],
     {UNKNOWN: MERAH,
      "fase tak diketahui bukan bulan baru": HIJAU,
      "piringan tak-diketahui di antara gelap & terang": MERAH}),
]


def run_probe(checks):
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT, checks],
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
    mutasi_sumber.require_clean_sources([RENDER])
    original = open(RENDER, "rb").read()
    baseline_md5 = hashlib.md5(original).hexdigest()
    failures = []

    def restore():
        mutasi_sumber.restore_verified(RENDER, original)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected in STATES:
            if edits is None:
                restore()
            else:
                content = original.decode()
                for find, replace in edits:
                    hits = content.count(find)
                    if hits != 1:
                        failures.append(
                            f"{name}: jangkar muncul {hits}x, butuh 1: {find[:70]!r}")
                        break
                    content = content.replace(find, replace)
                else:
                    mutasi_sumber.write_source(RENDER, content)

            verdicts, error = run_probe(ALL)
            if verdicts is None:
                failures.append(f"{name}: probe gagal: {error}")
                print(f"{name}: PROBE GAGAL\n{error}")
                continue

            wrong = [(check, want, verdicts.get(check, "TIDAK ADA"))
                     for check, want in expected.items()
                     if verdicts.get(check, "TIDAK ADA") != want]
            if wrong:
                for check, want, got in wrong:
                    failures.append(f"{name}: {check!r} diharapkan {want}, "
                                    f"terukur {got}")
                print(f"{name}: {len(wrong)} TIDAK SESUAI HARAPAN")
                for check, want, got in wrong:
                    print(f"    {check}\n      diharapkan {want}, terukur {got}")
            else:
                red = sum(1 for v in verdicts.values() if v == "merah")
                print(f"{name}: sesuai harapan ({red} merah dari "
                      f"{len(verdicts)} pemeriksaan)")
    finally:
        restore()

    after = hashlib.md5(open(RENDER, "rb").read()).hexdigest()
    print(f"\nmd5 render-visuals.py: {baseline_md5} -> {after} "
          f"({'pulih persis' if after == baseline_md5 else 'TIDAK PULIH'})")
    if after != baseline_md5:
        failures.append("sumber produksi tidak pulih persis")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("\nSemua keadaan sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
