#!/usr/bin/env python3
"""Bukti bahwa gerbang pemakaian token aksen **berbunyi** — lalu dipulihkan.

**Kenapa berkas ini ada, dan kenapa ia tidak boleh tinggal di `out/`.**
`red-lint.sh` sudah melakukan hal ini untuk `swift-ui-lint.sh`, dan `red-test.sh`
untuk `swift test`. Yang belum punya pembuktian adalah gerbang **gambar**
(`Tools/check-visuals.py`) — dan justru di sana buktinya paling dibutuhkan,
karena gerbang itu bekerja dengan membaca **teks** sumber lalu menyimpulkan
sesuatu tentang gambar. Gerbang teks yang salah membaca sumber akan hijau
selamanya dan tidak ada yang tahu.

**Kenapa `out/` tidak cukup.** Sampai siklus ini seluruh pembuktian mutasi
repo ini hidup di `out/` — dan `out/` di-gitignore. Dua puluh harness pernah
ditulis di sana dan **tidak satu pun** yang masih ada bagi siapa pun yang
membaca repo ini. Pembuktian yang hilang sama dengan tidak ada: yang tersisa
hanya gerbangnya, tanpa alasan untuk mempercayainya.

**Cara ia bekerja, dan kenapa bukan `--check` penuh.** Gerbang penuh merender
seluruh katalog dan butuh ~6 menit; tiga belas keadaan akan memakan lebih dari
satu jam, dan gerbang yang terlalu lambat untuk dijalankan adalah gerbang yang
dilewati. Berkas ini memanggil **fungsi pemeriksaan yang sama** lewat parameter
`view_source`/`night_source` — nilai bawaannya membaca berkas yang sama, jadi
bukan jalur kedua yang bisa berbeda. Bedanya hanya: tidak merender. Jalan
<1 detik.

Yang dibuktikan bukan "gerbangnya hijau", melainkan bahwa ia **berbunyi pada
keadaan yang salah**, **diam pada keadaan yang benar**, dan **berbunyi karena
alasan yang benar**. Tiga keadaan terakhir sengaja diharapkan hijau: gerbang
yang merah pada kode benar akan dimatikan orang, dan itu bentuk kegagalan yang
paling sulit terlihat karena tampak seperti ketaatan.

Pakai:
    python3 Tools/bukti-mutasi-aksen.py        # 0 = semua sesuai harapan
"""
import importlib.util
import os
import sys
from typing import SupportsIndex

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEW = os.path.join(ROOT, "Apps/Shared/CelestialVisualView.swift")
NIGHT = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/NightVisual.swift")

spec = importlib.util.spec_from_file_location(
    "check_visuals", os.path.join(ROOT, "Tools/check-visuals.py"))
CV = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CV)

# Jangkar: baris yang benar-benar menggambar piringan fase tak diketahui.
SPHERE_CALL = (
    "            Self.fillSphere(context: context, disc: disc, center: center, radius: radius,\n"
    "                            base: CelestialVisual.accents.moonPhaseUnknown)")


class JangkarHilang(Exception):
    """Jangkar mutasi tidak ada di sumber — mutasinya tidak jadi apa-apa."""


class Sumber(str):
    """`str` yang **menolak** `replace()` dengan jangkar yang tidak ada.

    **Kenapa ini ada.** Seluruh keadaan di berkas ini bekerja dengan
    `BASE_VIEW.replace(jangkar, pengganti)`. Kalau `jangkar` sudah tidak ada
    lagi di sumber — karena kode produksinya direfaktor, yang di repo ini
    terjadi terus — `str.replace` mengembalikan sumber **apa adanya**, tanpa
    galat apa pun. Harness lalu mengukur sumber yang tidak termutasi.

    Akibatnya berbeda menurut arah harapannya, dan yang **hijau** yang
    berbahaya:

      - Keadaan yang mengharapkan **merah**: pengukuran mengembalikan nol
        merah, `got != expect`, jadi tercetak `[SALAH]`. Berisik, aman.
      - Keadaan yang mengharapkan **hijau**: nol merah memang yang
        diharapkan, jadi tercetak `[OK ]`. Keadaan itu **tidak lagi menguji
        apa pun**, dan tidak ada satu pun tanda di keluarannya.

    Empat keadaan di berkas ini mengharapkan hijau — termasuk tiga yang
    menjaga kode benar dari gerbang yang terlalu ketat, dan satu yang
    menjaga keadaan `main` sekarang. Keempatnya bisa berhenti berarti
    tanpa suara.

    Karena itu `replace()` di sini melempar bila jangkarnya tidak ada.
    Dipasang di kelas `str`-nya, bukan di sebelas tempat pemanggilan: satu
    tempat yang benar, dan pemanggilan baru tidak bisa lupa memakainya.
    """

    def replace(self, old: str, new: str,
                count: SupportsIndex = -1) -> str:  # type: ignore[override]
        if old not in self:
            raise JangkarHilang(
                f"jangkar tidak ditemukan, mutasi tidak jadi: {old[:80]!r}")
        return super().replace(old, new, count)


BASE_VIEW = Sumber(open(VIEW, encoding="utf-8").read())
BASE_NIGHT = Sumber(open(NIGHT, encoding="utf-8").read())

# Nama pemeriksaan, dipakai apa adanya supaya perubahan nama di gerbang membuat
# berkas ini merah — bukan diam-diam mencocokkan himpunan kosong.
C_DIPAKAI = "piringan fase tak diketahui: dipakai di kode view"
C_WARNA = "piringan fase tak diketahui: view tidak menulis warnanya sendiri"
C_SAMPAI = "aksen gambar: setiap warna model sampai ke view"
C_LUAR = "aksen gambar: view tidak memakai nama di luar model"
C_BLOK = "aksen gambar: blok `accents` terbaca dari model"

CASES = []


def case(name, expect):
    """`expect` = himpunan nama pemeriksaan yang **harus** berbunyi.

    Bukan jumlahnya. Menghitung "berapa merah" menyembunyikan keadaan yang
    berbunyi karena **alasan yang salah** — pernah terjadi di repo ini, dan
    bentuknya menyesatkan karena gerbangnya memang merah, jadi tampak bekerja.
    Diukur di sini juga: `view: memakai nama aksen yang tidak ada di model`
    merah oleh **tiga** pemeriksaan, bukan oleh satu.
    """
    def wrap(fn):
        CASES.append((name, fn, expect))
        return fn
    return wrap


def measure(view=None, night=None):
    """Jalankan kedua pemeriksaan atas sumber yang diberikan → himpunan gagal."""
    results = []
    CV.check_night_accents_reach_the_view(results, view_source=view, night_source=night)
    CV.check_unknown_moon_disc_uses_the_token(results, view_source=view)
    return {r.name for r in results if not r.ok}


# ── Keadaan yang HARUS merah ────────────────────────────────────────────────

@case("baseline (tanpa mutasi)", set())
def _():
    return None, None


@case("view: token diganti warna tetap (bentuk cacat aslinya)",
      {C_DIPAKAI, C_WARNA, C_SAMPAI})
def _():
    # Cacat yang gerbang ini ada untuk menangkap: token model hilang dari kode
    # yang menggambar, dan warnanya ditulis langsung.
    return BASE_VIEW.replace(
        SPHERE_CALL,
        "            context.fill(disc, with: .color(Color(red: 0.52, green: 0.52, blue: 0.55)))"), None


@case("view: token hanya hidup di komentar", {C_DIPAKAI, C_SAMPAI})
def _():
    # Bentuk paling sunyi, dan yang paling wajar ditulis orang. Dengan pembaca
    # mentah (`"nama" in view`) keadaan ini **hijau** — itulah sebabnya
    # `swift_code_only` ada.
    #
    # `C_WARNA` **tidak** berbunyi di sini, dan itu benar: penggantinya memakai
    # token lain (`moonUnlit`), jadi `drawMoon` memang tidak menulis warnanya
    # sendiri. Harapan yang menuntut ia merah akan menuntut gerbang berbunyi
    # karena alasan yang salah.
    return BASE_VIEW.replace(
        SPHERE_CALL,
        "            Self.fillSphere(context: context, disc: disc, center: center, radius: radius,\n"
        "                            base: CelestialVisual.accents.moonUnlit)\n"
        "            // TODO kembalikan CelestialVisual.accents.moonPhaseUnknown"), None


@case("view: token hanya hidup di dalam string", {C_DIPAKAI, C_WARNA, C_SAMPAI})
def _():
    # Lubang yang sama satu lapis lebih dalam: nama token ditulis di pesan
    # galat. Tidak menggambar apa pun.
    return BASE_VIEW.replace(
        SPHERE_CALL,
        '            print("CelestialVisual.accents.moonPhaseUnknown")\n'
        "            context.fill(disc, with: .color(Color(red: 0.52, green: 0.52, blue: 0.55)))"), None


@case("view: warna tetap di dalam drawMoon, token dipakai di tempat lain", {C_WARNA})
def _():
    # Di sini `C_DIPAKAI` hijau — tokennya memang muncul di kode view — jadi
    # satu-satunya yang bisa berbunyi adalah pemeriksaan kedua. Inilah sebabnya
    # ada dua, bukan satu.
    return BASE_VIEW.replace(
        SPHERE_CALL,
        "            context.fill(disc, with: .color(Color(red: 0.52, green: 0.52, blue: 0.55)))\n"
        "            _ = CelestialVisual.accents.moonPhaseUnknown"), None


@case("model: aksen baru tidak pernah dipakai view", {C_SAMPAI})
def _():
    # Kelas paling sunyi: setiap gerbang **nilai** tetap hijau (model dan port
    # sama-sama punya warnanya), dan warnanya tidak pernah menggambar apa pun.
    return None, BASE_NIGHT.replace(
        "        candidateFill: .init(red: 0.10, green: 0.10, blue: 0.13)",
        "        candidateFill: .init(red: 0.10, green: 0.10, blue: 0.13),\n"
        "        aksenBaruYangTidakDipakai: .init(red: 0.11, green: 0.22, blue: 0.33)")


@case("view: memakai nama aksen yang tidak ada di model", {C_LUAR, C_DIPAKAI, C_SAMPAI})
def _():
    # Arah sebaliknya: view membaca nama yang tidak pernah didefinisikan, jadi
    # warnanya jatuh ke nilai bawaan tanpa ada yang tahu.
    return BASE_VIEW.replace(
        "CelestialVisual.accents.moonPhaseUnknown",
        "CelestialVisual.accents.moonPhaseTidakDiketahui"), None


@case("model: blok `accents` tidak terbaca lagi", {C_BLOK})
def _():
    return None, BASE_NIGHT.replace(
        "static let accents = Accents(", "static let paletAksen = Accents(")


@case("view: drawMoon diubah namanya (jangkar hilang → merah, bukan lulus)", {C_WARNA})
def _():
    # Jangkar yang hilang harus **merah**, bukan diam-diam lulus. Gerbang yang
    # kehilangan tempat yang diukurnya adalah gerbang yang berhenti mengukur.
    return BASE_VIEW.replace("private func drawMoon(", "private func gambarBulan("), None


# ── Keadaan yang HARUS hijau ────────────────────────────────────────────────

@case("kode benar, ejaan berbeda (keadaan yang dulu merah — harus HIJAU)", set())
def _():
    # Keadaan yang menjatuhkan `main` selama dua commit: pemakaiannya sah,
    # hanya tidak berbentuk `Self.accent(...)`. Menggantinya dengan jalan lain
    # yang setara harus tetap hijau, karena yang dijaga adalah faktanya, bukan
    # ejaannya.
    return BASE_VIEW.replace(
        SPHERE_CALL,
        "            let dasarFase = CelestialVisual.accents.moonPhaseUnknown\n"
        "            context.fill(disc, with: .color(Self.accent(dasarFase)))"), None


@case("kode benar, nama lewat variabel lokal (harus HIJAU)", set())
def _():
    # Menemukan cacat nyata di gerbang ini: pola `accents\\.(\\w+)` saja tidak
    # melihat alias, jadi kode yang benar merah. Diperbaiki di
    # `accent_names_in_view_code`.
    return BASE_VIEW.replace(
        SPHERE_CALL,
        "            let aksen = CelestialVisual.accents\n"
        "            Self.fillSphere(context: context, disc: disc, center: center, radius: radius,\n"
        "                            base: aksen.moonPhaseUnknown)"), None


@case("kode benar, komentar menyebut token yang tidak dipakai (harus HIJAU)", set())
def _():
    # Komentar yang menyebut aksen **lain** tidak boleh dihitung sebagai
    # pemakaian — sama seperti komentar yang menyebut token yang sama.
    return BASE_VIEW.replace(
        "    // MARK: - Bulan",
        "    // Catatan: CelestialVisual.accents.venusHaze tidak dipakai di sini.\n"
        "    // MARK: - Bulan"), None


@case("kode benar, piringan digambar sebagai bola (keadaan `main` sekarang)", set())
def _():
    # Keadaan `main` sekarang. Dijaga di sini supaya regresi ke ejaan lama
    # tidak bisa kembali tanpa ada yang tahu.
    return BASE_VIEW, None


def main():
    problems = 0
    for name, mutate, expect in CASES:
        view, night = mutate()
        got = measure(view, night)
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
