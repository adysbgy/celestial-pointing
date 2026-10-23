#!/usr/bin/env python3
"""Bukti bahwa gerbang "konstanta view benar-benar dipakai" **berbunyi** — lalu dipulihkan.

**Cacat yang dibuktikan di sini, dan kenapa ia lolos sampai sekarang.**
`Tools/render-visuals.py` menandai konstanta dengan `# VIEW: ...` untuk
menjanjikan bahwa angka itu berasal dari `CelestialVisualView`. Satu-satunya
pemeriksa janji itu adalah `check_port_matches_swift_constants`, yang
menanyakan apakah **teks** angkanya masih tertulis di berkas view. Konstanta
yang dideklarasikan lalu tidak pernah dibaca tetap memuat teks itu, jadi ia
hijau — dan tidak ada yang tahu bahwa ciri gambarnya sudah hilang.

Diukur di proses baru pada pohon yang seharusnya hijau, dua mutasi:

    .opacity(Self.glowOpacities[...])        -> .opacity(0.5)
    starRadius * Self.clusterCoreHaloScale   -> starRadius * 1.0

Keduanya: `swift-ui-lint.sh` exit 0 dengan 102 aturan, dan kedua gerbang
paritas 235 pemeriksaan 0 gagal. Nol merah untuk dua ciri gambar yang hilang.

**Kenapa dua keadaan "harus hijau" di sini justru yang terpenting.** Draf
pertama gerbang ini menuntut "angka port harus tertulis di badan fungsi yang
ditandai", dan ia **merah pada kode yang benar** pada lima konstanta:

  - `MARIA_EDGE_SOFTNESS` — view menyimpannya sebagai
    `private static let mariaEdgeSoftness = 0.35` lalu membacanya di
    `drawMoonSurfaceShading`. Pemfaktoran yang benar, bukan cacat.
  - `SPIKE_OPACITY` — view membacanya dari model (`geometry.spikeOpacity`),
    jadi angkanya memang tidak boleh muncul lagi di view.

Gerbang yang merah pada kode benar akan dimatikan orang, dan bentuk kegagalan
itu paling sulit terlihat karena tampak seperti ketaatan. Karena itu dua
keadaan terakhir di berkas ini mengunci kedua bentuk benar tersebut.

**Kenapa memakai `Sumber.replace` yang melempar.** Sama seperti
`bukti-mutasi-aksen.py`: `str.replace` dengan jangkar yang sudah tidak ada
mengembalikan sumber apa adanya tanpa galat, sehingga keadaan yang
mengharapkan hijau akan hijau karena **tidak menguji apa pun**. Di sini itu
lebih berbahaya daripada biasanya, karena tiga keadaan mengharapkan hijau.

Pakai:
    python3 Tools/bukti-mutasi-konstanta-view.py        # 0 = semua sesuai harapan
"""
import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW = os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")
PORT = os.path.join(ROOT, "Tools/render-visuals.py")

spec = importlib.util.spec_from_file_location(
    "check_visuals", os.path.join(ROOT, "Tools/check-visuals.py"))
CV = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CV)

# Nama pemeriksaan, dipakai apa adanya: kalau namanya berubah di gerbang,
# berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
C = "konstanta view yang diklaim port benar-benar dipakai"


class JangkarHilang(Exception):
    """Jangkar mutasi tidak ada di sumber — mutasinya tidak jadi apa-apa."""


class Sumber(str):
    """`str` yang **menolak** `replace()` dengan jangkar yang tidak ada."""

    def replace(self, old, new, count=-1):  # type: ignore[override]
        if old not in self:
            raise JangkarHilang(
                f"jangkar tidak ditemukan, mutasi tidak jadi: {old[:80]!r}")
        return super().replace(old, new, count)


BASE_VIEW = Sumber(open(VIEW, encoding="utf-8").read())
BASE_PORT = Sumber(open(PORT, encoding="utf-8").read())

# Jangkar pemakaian yang sebenarnya, bukan deklarasinya.
GLOW_USE = ".opacity(Self.glowOpacities["
HALO_USE = "starRadius * Self.clusterCoreHaloScale"

CASES = []


def case(name, expect):
    """`expect` = himpunan nama pemeriksaan yang **harus** berbunyi."""
    def wrap(fn):
        CASES.append((name, fn, expect))
        return fn
    return wrap


def measure(view=None, port=None):
    results = []
    CV.check_view_literals_are_used_where_the_port_says(
        results, view_source=view, port_source=port)
    return {r.name for r in results if not r.ok}


# ── Keadaan yang HARUS merah ────────────────────────────────────────────────

@case("view: glowOpacities dideklarasikan tetapi tidak dipakai (cacat aslinya)", {C})
def _():
    # Mutasi yang terukur hijau di seluruh gerbang sebelum pemeriksaan ini ada.
    import re
    return Sumber(re.sub(r"\.opacity\(Self\.glowOpacities\[[^\]]*\]\)",
                         ".opacity(0.5)", BASE_VIEW)), None


@case("view: clusterCoreHaloScale dideklarasikan tetapi tidak dipakai", {C})
def _():
    return BASE_VIEW.replace(HALO_USE, "starRadius * 1.0"), None


@case("view: kedua konstanta mati sekaligus", {C})
def _():
    import re
    return Sumber(re.sub(r"\.opacity\(Self\.glowOpacities\[[^\]]*\]\)", ".opacity(0.5)",
                         BASE_VIEW.replace(HALO_USE, "starRadius * 1.0"))), None


@case("port: penanda VIEW dihapus seluruhnya (kehilangan subjek = MERAH)", {C})
def _():
    # Aturan yang berhenti mengukur tanpa berbunyi lebih berbahaya daripada
    # tidak ada aturan: kalau penandanya hilang, pemeriksaan ini harus bilang.
    import re
    stripped = Sumber(re.sub(r"\s*#\s*VIEW:\s*`?[A-Za-z_][A-Za-z0-9_.]*`?", "",
                             BASE_PORT))
    if stripped == BASE_PORT:
        raise JangkarHilang("tidak ada penanda VIEW: untuk dihapus di port")
    return None, stripped


@case("view: nama konstanta diubah (deklarasi tidak lagi cocok = hilang subjek)", {C})
def _():
    # Kalau konstanta diganti nama di view tetapi penandanya tetap menunjuk nama
    # lama, ia berhenti menjadi "konstanta bernama" dan diam-diam keluar dari
    # himpunan yang diperiksa. Untuk satu-satunya dua anggota, itu harus merah.
    return (BASE_VIEW.replace("private static let glowOpacities",
                              "private static let glowOpacitiesLama")
            .replace("private static let clusterCoreHaloScale",
                     "private static let clusterCoreHaloScaleLama")), None


# ── Keadaan yang HARUS hijau ────────────────────────────────────────────────

@case("kode sekarang (tanpa mutasi)", set())
def _():
    return None, None


@case("kode benar: angka difaktorkan ke konstanta lain (dulu MERAH, harus HIJAU)", set())
def _():
    # Bentuk yang menjatuhkan draf pertama gerbang ini. `0.35` tetap dipakai
    # untuk menggambar, hanya lewat nama — bukan cacat, dan tidak boleh merah.
    return BASE_VIEW.replace(
        "let inner = edge * (1 - mariaEdgeSoftness)",
        "let inner = edge * (1 - Self.mariaEdgeSoftness)"), None


@case("kode benar: angka dibaca dari model (dulu MERAH, harus HIJAU)", set())
def _():
    # `SPIKE_OPACITY` sengaja tidak muncul sebagai angka di view: nilainya
    # datang dari `PhaseGeometry`. Menuntut angkanya tertulis akan menuntut
    # salinan kedua rumus — persis yang dihindari repo ini.
    return BASE_VIEW, None


@case("kode benar: konstanta dibaca lewat `Self.` di fungsi lain", set())
def _():
    return BASE_VIEW.replace(GLOW_USE, ".opacity(Self . glowOpacities["), None


def main():
    problems = 0
    for name, mutate, expect in CASES:
        try:
            view, port = mutate()
            got = measure(view, port)
        except JangkarHilang as error:
            problems += 1
            print(f"[SALAH] {name}")
            print(f"      {error}")
            continue
        ok = got == expect
        if not ok:
            problems += 1
        print(f"[{'OK ' if ok else 'SALAH'}] {name}")
        if not ok:
            print(f"      harap   {sorted(expect) or 'nol merah'}")
            print(f"      terukur {sorted(got) or 'nol merah'}")
            for extra in sorted(got - expect):
                print(f"      LEBIH:  {extra}")
            for missing in sorted(expect - got):
                print(f"      KURANG: {missing}")
    print(f"\n{len(CASES)} keadaan, {problems} tidak sesuai harapan")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
