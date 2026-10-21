#!/usr/bin/env python3
"""Buktikan lima gerbang latar langit **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

`SkyBackdropView` menggambar lapisan langit di **setiap** layar app: puluhan
titik yang tersebar di bidang penuh. Sampai unit ini, seluruh cakupan
render-nya nol — tidak satu pun dari 108 pemeriksaan di `Tools/check-visuals.py`
membaca pikselnya. Yang ada hanya 13 tes Linux untuk `SkyBackdrop`, dan tes
itu menguji **fungsi** warna: `nightColour(0.62).red == 0.62`, hijau dan biru
nol. Semuanya benar, dan semuanya hijau, sementara view bisa mengisi
`GraphicsContext` dengan apa pun.

Bentuk cacat yang sudah pernah dikirim ke `main` justru yang paling wajar:
view memakai `nightBrightness(...)` sebagai `context.opacity` di atas
`neutralStarBody` — yang **putih**. Terangnya benar, ronanya salah. Tidak ada
teks di layar yang menyebut warna titik-titik itu, gerbang kontras tidak
mengukurnya (tidak ada teks di atasnya), dan di mata "langit agak redup"
terlihat wajar. Yang dikorbankan seluruh alasan mode malam ada: cahaya biru
mematikan adaptasi gelap 20–40 menit, dan lapisan ini ada di setiap layar.

Kenapa cacat itu tidak tertangkap apa pun.

Tiga sebab, dan ketiganya harus ditutup bersamaan:

  1. **Modelnya benar.** `SkyBackdrop.nightColour` membuang hijau & biru
     total. Gerbang yang membaca fungsi akan hijau pada gambar yang putih.
  2. **Tidak ada yang menggambar.** Port Python untuk backdrop tidak ada;
     `render-visuals.py` punya port untuk planet, bulan, bintang, dan
     nebula, tetapi tidak untuk lapisan yang paling sering tampil.
  3. **Tidak ada paritas sumber.** Cincin Saturnus sudah pernah kena kelas
     yang sama: port benar, view memakai bentuk lama. Jawabannya di repo ini
     selalu sama — ukur keduanya, karena hanya satu yang punya PNG.

Yang dibuktikan harness ini, dua arah.

  Keadaan 1  putih diredupkan di mode malam  -> gerbang merah murni memerah
  Keadaan 2  "perbaikan" kebablasan: siang ikut merah -> gerbang netral memerah
  Keadaan 3  guard AOD dibuang (tetap menggambar saat redup) -> gerbang AOD memerah
  Keadaan 4  view kembali ke bentuk lama -> gerbang paritas sumber memerah
  Keadaan 5  KONTROL NEGATIF: komentar menyebut nama lama -> tetap hijau
  Keadaan 6  model berubah, port tidak (layerOpacity 0.5 -> 0.30) -> gerbang paritas angka memerah
  Keadaan 7  model berubah, port tidak (speckDensity 90 -> 45) -> gerbang paritas angka memerah
  Keadaan 8  KONTROL NEGATIF: komentar model menyebut angka lama -> tetap hijau

Keadaan 6 dan 7 adalah cacat yang **terukur** sebelum gerbangnya ada.

Empat gerbang piksel di atas mengukur `render-visuals.py`, dan port itu
menulis lima angkanya dengan tangan dari `SkyBackdrop.swift`. Tidak satu pun
dibaca dari model. Diukur pada salinan utuh di proses baru: mengubah
`layerOpacity` menjadi `0.30` **dan** `speckDensity` menjadi `45` di model
membiarkan keempat gerbang hijau dengan angka **sama persis** (0.722 / 3361
piksel / 0.571). Artinya unit ini mengukur langit yang tidak digambar app
begitu modelnya berubah — dan model berubah adalah hal yang wajar, bukan
sabotase.

Keadaan 8 ada karena gerbang paritas membaca **teks** model. Komentar yang
menyebut angka lama tidak menggambar apa pun, jadi ia tidak boleh memuaskan
gerbang; kalau bisa, gerbangnya merah pada kode yang benar dan akan dimatikan
orang.

Keadaan 5 ada karena gerbang paritas sumber memakai `swift_code_only`, dan
gerbang yang memerah pada komentar akan dimatikan orang. Diukur: tanpa
pembaca itu, `// dulu: opacity = SkyBackdrop.nightBrightness(0.5)` membuat
gerbang keadaan-4 merah pada kode yang benar.

Kenapa keadaan 3 tidak boleh ikut memerahkan gerbang keadaan 2.

Percobaan pertama memakai `is_visible=False` sebagai pembanding gerbang siang,
dan saat guard AOD dimutasi **dua** gerbang memerah. Gerbang yang mewarisi
cacat tetangga menyembunyikan cacat mana yang sebenarnya ada. Pembandingnya
karena itu mengosongkan **daftar titik**, bukan saklar AOD — satu gerbang,
satu cacat.

Jalankan: python3 Tools/bukti-mutasi-latar-langit.py
Keluar 0 hanya kalau keempat keadaan memerah tepat pada gerbangnya dan
kontrol negatif tetap hijau.
"""
import importlib.util
import os
import sys

sys.dont_write_bytecode = True

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW_PATH = os.path.join(ROOT, "Apps/Shared/SkyBackdropView.swift")
MODEL_PATH = os.path.join(
    ROOT, "Packages/PointingKit/Sources/PointingKit/SkyBackdrop.swift")


def load_checker():
    spec = importlib.util.spec_from_file_location(
        "check_visuals", os.path.join(ROOT, "Tools/check-visuals.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_gates(checker, view_source=None, model_source=None):
    results = []
    checker.check_backdrop_night_specks_are_red(results)
    checker.check_backdrop_day_specks_are_neutral(results)
    checker.check_backdrop_stops_drawing_when_reduced(results)
    checker.check_backdrop_view_reads_the_model_colours(results, view_source=view_source)
    checker.check_backdrop_radius_scales_with_width(results)
    checker.check_backdrop_port_matches_the_model(
        results, model_source=model_source, view_source=view_source)
    return results


def report(label, results, expected_red):
    red = [result for result in results if not result.ok]
    names = [result.name for result in red]
    hit = all(any(key in name for name in names) for key in expected_red)
    exact = len(red) == len(expected_red)
    print(("LULUS " if hit and exact else "GAGAL ") + label)
    for result in red:
        print("    merah:", result.name)
        print("           ", result.detail[:160])
    if hit and not exact:
        print("    gerbang yang memerah tidak sesuai harapan:", names)
    return hit and exact


def main():
    checker = load_checker()
    render = checker.R
    outcomes = []

    # Keadaan 1 — bentuk cacat yang pernah dikirim: putih diredupkan.
    original_night = render.backdrop_night_colour
    render.backdrop_night_colour = lambda day: (day, day, day)
    try:
        outcomes.append(report("keadaan 1 (putih redup di mode malam) memerah",
                               run_gates(checker), ["merah murni"]))
    finally:
        render.backdrop_night_colour = original_night

    # Keadaan 2 — "perbaikan" yang kebablasan: mode siang ikut merah.
    original_day = render.backdrop_day_colour
    render.backdrop_day_colour = lambda: render.backdrop_night_colour(0.62)
    try:
        outcomes.append(report("keadaan 2 (mode siang ikut merah) memerah",
                               run_gates(checker), ["tetap netral"]))
    finally:
        render.backdrop_day_colour = original_day

    # Keadaan 3 — guard AOD dibuang: tetap menggambar saat layar redup.
    original_render = render.render_backdrop

    def without_guard(width, height, night_mode=False, is_visible=True, ss=1):
        return original_render(width, height, night_mode=night_mode,
                               is_visible=True, ss=ss)

    render.render_backdrop = without_guard
    try:
        outcomes.append(report("keadaan 3 (guard AOD dibuang) memerah",
                               run_gates(checker), ["berhenti menggambar"]))
    finally:
        render.render_backdrop = original_render

    # Keadaan 4 — view kembali ke bentuk lama (jalur terang, bukan jalur warna).
    with open(VIEW_PATH) as handle:
        view = handle.read()
    broken = view.replace("SkyBackdrop.nightColour(", "neutralStarBody(", 1)
    if broken == view:
        print("GAGAL keadaan 4 tidak bisa disiapkan: `SkyBackdrop.nightColour(` "
              "tidak ditemukan di view — jangkar harness sudah basi")
        return 1
    outcomes.append(report("keadaan 4 (view memakai terang, bukan warna) memerah",
                           run_gates(checker, view_source=broken),
                           ["view memakai warna model"]))

    # Keadaan 5 — kontrol negatif: komentar yang menyebut bentuk lama.
    benign = view + "\n// dulu: opacity = SkyBackdrop.nightBrightness(0.5)\n"
    outcomes.append(report("keadaan 5 (komentar sah) tetap hijau",
                           run_gates(checker, view_source=benign), []))

    # Keadaan 6 dan 7 — cacat yang terukur sebelum gerbangnya ada: model
    # berubah, port tetap memakai angka lama. Yang memerah harus **tepat**
    # satu gerbang, karena gerbang yang mewarisi cacat tetangga menyembunyikan
    # cacat mana yang sebenarnya ada.
    with open(MODEL_PATH) as handle:
        model = handle.read()

    for label, old, new, gate in (
            ("keadaan 6 (model layerOpacity 0.5 -> 0.30)",
             "static let layerOpacity: Double = 0.5",
             "static let layerOpacity: Double = 0.30",
             "SPECK_LAYER_OPACITY"),
            ("keadaan 7 (model speckDensity 90 -> 45)",
             "static let speckDensity: Double = 90",
             "static let speckDensity: Double = 45",
             "SPECK_DENSITY")):
        if old not in model:
            print(f"GAGAL {label} tidak bisa disiapkan: `{old}` tidak ditemukan "
                  f"di model — jangkar harness sudah basi")
            return 1
        outcomes.append(report(label + " memerah",
                               run_gates(checker,
                                         model_source=model.replace(old, new, 1)),
                               [gate]))

    # Keadaan 8 — lantai radius di view berubah, port tidak.
    old_floor = "max(0.35, speck.radius * size.width)"
    if old_floor not in view:
        print("GAGAL keadaan 8 tidak bisa disiapkan: lantai radius tidak "
              "ditemukan di view — jangkar harness sudah basi")
        return 1
    outcomes.append(report("keadaan 8 (lantai radius view 0.35 -> 0.90) memerah",
                           run_gates(checker, view_source=view.replace(
                               old_floor, "max(0.90, speck.radius * size.width)", 1)),
                           ["SPECK_RADIUS_FLOOR"]))

    # Keadaan 9 — KONTROL NEGATIF: komentar model menyebut angka lama.
    # Gerbang paritas membaca **teks**; komentar tidak menggambar apa pun.
    commented = model.replace(
        "static let layerOpacity: Double = 0.5",
        "static let layerOpacity: Double = 0.5\n"
        "    // dulu: static let layerOpacity: Double = 0.30", 1)
    outcomes.append(report("keadaan 9 (komentar model menyebut angka lama) tetap hijau",
                           run_gates(checker, model_source=commented), []))

    # Keadaan 10 — port memakai sumbu yang salah: radius dikali **tinggi**.
    # Kelima gerbang latar yang lain tetap hijau pada mutasi ini (semuanya
    # memakai bidang persegi), jadi hanya gerbang sumbu yang bisa melihatnya.
    render_source_path = os.path.join(ROOT, "Tools/render-visuals.py")
    with open(render_source_path) as handle:
        render_source = handle.read()
    axis_anchor = 'speck["radius"] * width'
    if axis_anchor not in render_source:
        print("GAGAL keadaan 10 tidak bisa disiapkan: `speck[\"radius\"] * width` "
              "tidak ditemukan di port — jangkar harness sudah basi")
        return 1
    import types
    broken = types.ModuleType("render_visuals_axis")
    broken.__file__ = render_source_path
    exec(compile(render_source.replace(axis_anchor, 'speck["radius"] * height'),
                 render_source_path, "exec"), broken.__dict__)
    original_renderer = checker.R
    checker.R = broken
    try:
        outcomes.append(report("keadaan 10 (radius diskalakan tinggi) memerah",
                               run_gates(checker), ["diskalakan lebar"]))
    finally:
        checker.R = original_renderer

    print()
    if all(outcomes):
        print("HASIL: SEMUA LULUS — keenam gerbang berbunyi, kontrol negatif diam")
        return 0
    print("HASIL: ADA YANG GAGAL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
