#!/usr/bin/env python3
"""Buktikan Aturan 66 (fakta mode malam) **berbunyi**, dan tahu batasnya.

Kelas cacat yang ditutup aturan ini
===================================

Fakta `isNight`/`isNightModeEnabled` lahir di model justru supaya pemanggil
**tidak bisa** mengarang nilai mode malam. Pemanggil yang mengarangnya
menghasilkan satu piksel di layar merah yang bukan merah -- dan pada produk
ini itu bukan kosmetik: seluruh mode malam ada untuk menjaga rhodopsin, yang
butuh 20-40 menit untuk pulih setelah cahaya putih/biru.

Terukur pada pohon utuh, proses baru, seluruh **65** aturan hijau, dengan
mutasi yang semuanya mengompilasi dan semuanya hanya mengganti **satu**
argumen atau **satu** angka:

    CelestialVisualView  candidateStroke(isNight: NightMode.isOn) -> false
    CelestialVisualView  candidateFill(isNight:   NightMode.isOn) -> true
    SurfaceTokens        palette(isNightModeEnabled: NightMode.isOn) -> false
    SurfaceTokens        Hairline  ? 0.35 : 0.18                 -> ? 0.18 : 0.18
    SurfaceTokens        backdrop  backdropAtmosphereAlpha       -> 0.55

Lima keadaan, nol yang berbunyi. `palette(isNightModeEnabled: false)` di
`SurfacePalette.active` adalah yang paling sunyi: satu baris yang mengubah
**seluruh 26 situs** (jam dan iPhone) menjadi palet siang sementara tombol
bulan di layar menyala.

Kenapa Aturan 34/35/45 tidak menutupnya
=======================================

* **Aturan 34** menurunkan aksesornya dari parameter `isConfirmed:` -- keluarga
  `isNight:` tidak pernah masuk daftarnya.
* **Aturan 35** memerah bila parameter Bool yang **dibaca berkas itu** diganti
  literal. Ketiga berkas di atas membaca saklarnya lewat `NightMode.isOn`, yang
  tidak bernama `isNight`, jadi persyaratan "dibaca" tidak pernah terpenuhi.
* **Aturan 45** menjaga cabang `? .night : .day` (bentuk). Literal `false`
  bukan cabang -- ia jawaban.

Keadaan yang diuji, dan apa yang masing-masing buktikan
=======================================================

  1. lencana kandidat: stroke jadi `false`                MERAH
  2. lencana kandidat: fill jadi `true`                   MERAH
  3. palet aktif dikunci ke siang (`false`)               MERAH
  4. garis rambut: malam disamakan dengan siang           MERAH
  5. latar atmosfer: token jadi angka `0.55`              MERAH

  6. palet aktif dikunci ke **malam** (`true`)             hijau (batas)
  7. lencana kandidat: nilai lewat nama lain (`isPreview`) hijau (batas)
  8. fail-closed: seluruh pemanggilan hilang               MERAH
  9. kontrol negatif: pohon apa adanya                     hijau

Keadaan 6 dan 7 bukan kelonggaran yang tidak sengaja. Keduanya adalah **batas
yang dinyatakan**, dan mengujinya mencegah dua kesalahan yang berlawanan:

  * `true` tidak ditolak oleh aturan ini. Menolak keduanya akan memaksa satu
    bentuk pemanggilan yang "benar" hanya karena angkanya bukan `false` -- dan
    aturan yang memerah pada kode benar akan dilonggarkan orang. Yang
    menutup `true` adalah **uji PointingKit** (`NightPaletteSelector`), yang
    mengukur palet yang dihasilkan, bukan bentuk pemanggilannya.
  * Nilai yang bukan literal tidak dinilai, karena tanpa tipe aturan tidak
    bisa membuktikan apakah `isPreview` benar-benar berasal dari saklar mode
    malam atau dikarang di dekatnya. Itu wilayah Aturan 41/52.

Arah kedua
==========

Kelima keadaan cacat dijalankan lagi atas lint **pra-perbaikan**
(`git show <PRA>:swift-ui-lint.sh`, bukan dikarang) dan wajib **HIJAU** di
sana. Tanpa itu, keadaan merah hanya membuktikan aturan modern berbunyi,
bukan bahwa lubangnya nyata.

Dua hal ikut dikembalikan selama lint lama berjalan, dan keduanya ditemukan
dengan menjalankan arah kedua lalu membaca keluarnya:

  * `README.md` -- Aturan 10 membandingkan jumlah aturan yang mencetak dengan
    angka di README; lint lama punya 65 dan README baru 66.
  * `Packages/.../SurfacePaletteTests.swift` dan
    `apps/Shared/SurfaceTokens.swift` **tidak** dikembalikan. Uji PointingKit
    baru tidak dibaca lint lama (Aturan 10 hanya menghitung `func test`), dan
    `SurfaceTokens.swift` justru **subjek** mutasinya. Mengembalikannya akan
    menghapus mutasi yang sedang diuji.

Yang TIDAK dibuktikan
=====================

Sapu teks. Aturan ini tidak tahu tipe argumen, dan ia **tidak** menuntut
angka dibaca dari token bila barisnya tidak menyebut penerima palet sama
sekali. Yang dibuktikan: bentuk pemanggilan yang **ada** membawa sumbernya,
bukan bahwa palet yang dihasilkan benar -- itu wilayah uji PointingKit.
"""

from __future__ import annotations

import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
README = os.path.join(ROOT, "README.md")
SURFACE = os.path.join(ROOT, "Apps", "Shared", "SurfaceTokens.swift")
VISUAL = os.path.join(ROOT, "Apps", "Shared", "CelestialVisualView.swift")

RULE_HEADER = "== Aturan 66:"

#: Revisi **pra-perbaikan**: `Aturan 65: ...`, komit terakhir yang belum punya
#: blok Aturan 66. Bukan `HEAD` -- `HEAD` bergerak setiap kali aturannya
#: di-commit, dan arah kedua lalu menuntut HIJAU dari gerbang yang justru
#: sedang menguji cacat.
PRA = "02b0dc4"

JUMLAH_ATURAN_KINI = 66
JUMLAH_ATURAN_LAMA = 65

#: Jangkar: masing-masing **unik** di berkasnya, dan diperiksa di `main()`.
#:
#: Kenapa jangkar `palette(isNightModeEnabled: …)` ditulis dengan konteks
#: `static var active {` di depannya. Baris telanjangnya ada **dua** di
#: `SurfaceTokens.swift` kalau kelak ada pembaca kedua; dan lebih penting,
#: tanpa konteks itu jangkar dapat mencocokkan pemanggilan di berkas lain
#: setelah `grep`. Terukur pada pohon bersih: `palette(isNightModeEnabled:
#: NightMode.isOn)` muncul **1x** di `Apps/` hari ini -- tapi keadaan 8
#: mengganti seluruh pemanggilan, jadi keunikan per berkas memang satu-satunya
#: yang bisa dijamin.
AKTIF = "NightPaletteSelector.palette(isNightModeEnabled: NightMode.isOn)"
STROKE = "CelestialVisual.candidateStroke(isNight: NightMode.isOn)"
FILL = "CelestialVisual.candidateFill(isNight: NightMode.isOn)"
HAIRLINE_FN = "SurfacePalette.hairlineOpacity(for: SurfacePalette.active))"
BACKDROP = "palette.surface2.color.opacity(SurfacePalette.backdropAtmosphereAlpha)"

#: Tabel keadaan di **tingkat modul** dan bernama `STATES`, karena
#: `Tools/check-jangkar-harness.py` membacanya dari situ untuk tahu pasangan
#: (jangkar, pengganti) yang bisa tertinggal di sumber produksi bila harness
#: ini dihentikan di tengah. Tabel di dalam fungsi terbaca sebagai "nol
#: jangkar", dan gerbangnya menuduh harness ini buta -- merah pada pohon bersih.
#:
#: Bentuk `(label, [(berkas, cari, ganti), ...], harus_merah)`.
STATES = [
    ("1 lencana: stroke jadi false",
     [(VISUAL, STROKE,
       "CelestialVisual.candidateStroke(isNight: false)")], True),
    ("2 lencana: fill jadi true",
     [(VISUAL, FILL,
       "CelestialVisual.candidateFill(isNight: true)")], True),
    ("3 palet aktif dikunci siang",
     [(SURFACE, AKTIF,
       "NightPaletteSelector.palette(isNightModeEnabled: false)")], True),
    # 4: garis rambut. Jangkar yang ditulis adalah **pemanggilan tokennya**,
    # diganti bentuk lama yang mengarang keduanya sebagai angka -- persis
    # bentuk yang dulu hidup di berkas ini.
    ("4 garis rambut: malam = siang",
     [(SURFACE, HAIRLINE_FN,
       "NightPaletteSelector.isNight(SurfacePalette.active) ? 0.18 : 0.18)")],
     True),
    ("5 latar atmosfer jadi angka",
     [(SURFACE, BACKDROP,
       "palette.surface2.color.opacity(0.55)")], True),
    # 6: **batas yang dinyatakan.** `true` bukan cacat yang ditutup aturan ini.
    ("6 batas: palet dikunci malam", [(SURFACE, AKTIF,
                                        "NightPaletteSelector.palette(isNightModeEnabled: true)")],
     False),
    # 7: **batas yang dinyatakan.** Nama yang tidak menyebut asalnya juga
    # tidak dinilai -- tanpa tipe, aturan tidak bisa membedakan `isPreview`
    # yang berasal dari saklar dengan yang dikarang.
    ("7 batas: nilai lewat nama lain",
     [(VISUAL, STROKE, "CelestialVisual.candidateStroke(isNight: isPreview)")],
     False),
    ("8 fail-closed: semua pemanggilan hilang", "SEMUA", True),
    ("9 kontrol: pohon apa adanya", [], False),
]

BERKAS = (SURFACE, VISUAL)


def _baca_lint(rev):
    hasil = mutasi_sumber._git(["show", f"{rev}:swift-ui-lint.sh"])
    return hasil.stdout if hasil.returncode == 0 and hasil.stdout else None


def _program(teks):
    """Potong blok Aturan 66 dari `swift-ui-lint.sh`.

    Dipotong, bukan disalin: menyalin berarti harness mengukur salinannya,
    yang tetap hijau walau aturan aslinya dilonggarkan.
    """
    awal = teks.find("# ── Aturan 66")
    if awal < 0:
        return None
    sisa = teks[awal + 10:]
    akhir = -1
    for penanda in ("# ── Aturan ", 'if [ "$status" -eq 0 ]; then'):
        pos = sisa.find(penanda)
        if pos >= 0 and (akhir < 0 or pos < akhir):
            akhir = pos
    if akhir < 0:
        return None
    return teks[awal:awal + 10 + akhir]


def _jalankan(program):
    """Jalankan **blok aturannya saja** terhadap pohon kerja saat ini.

    `bash -s` dari stdin, bukan `bash -c`: program ini mendekati batas ukuran
    satu argumen Linux, dan kegagalannya akan terbaca sebagai "probe gagal",
    bukan sebagai temuan. Pola yang sama dipakai `bukti-mutasi-aturan65-*.py`.
    """
    skrip = "status=0\n" + program + "\nprintf 'STATUS:%s\\n' \"$status\"\n"
    hasil = subprocess.run(["bash", "-s"], cwd=ROOT, input=skrip,
                           capture_output=True, text=True, timeout=600)
    if hasil.returncode != 0:
        return None, (hasil.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    return "STATUS:1" in hasil.stdout, hasil.stdout.strip()


def _jalankan_lint_lama(teks_lint):
    """Jalankan lint pra-perbaikan **utuh** dan wajib HIJAU.

    `swift-ui-lint.sh` ditulis ulang dengan teks lama karena Aturan 10 membaca
    berkas itu dari cakram, bukan yang sedang berjalan. `README.md` dikembalikan
    ke hitungan lamanya karena Aturan 10 membandingkan angka yang mencetak
    dengan README -- lint lama punya 65, dan README baru bilang 66.
    """
    asli_readme = io.open(README, encoding="utf-8").read()
    asli_lint = io.open(LINT, encoding="utf-8").read()
    try:
        mutasi_sumber.write_source(LINT, teks_lint)
        io.open(README, "w", encoding="utf-8").write(asli_readme.replace(
            f"**{JUMLAH_ATURAN_KINI} aturan**",
            f"**{JUMLAH_ATURAN_LAMA} aturan**"))
        hasil = subprocess.run(["bash", LINT], cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        return hasil.returncode != 0, hasil.stdout.strip()
    finally:
        mutasi_sumber.write_source(LINT, asli_lint)
        io.open(README, "w", encoding="utf-8").write(asli_readme)


def main():
    mutasi_sumber.require_clean_sources(list(BERKAS))
    asli = {jalur: io.open(jalur, encoding="utf-8").read() for jalur in BERKAS}

    for nama, jalur, jangkar in (("AKTIF", SURFACE, AKTIF),
                                 ("STROKE", VISUAL, STROKE),
                                 ("FILL", VISUAL, FILL),
                                 ("HAIRLINE_FN", SURFACE, HAIRLINE_FN),
                                 ("BACKDROP", SURFACE, BACKDROP)):
        jumlah = asli[jalur].count(jangkar)
        if jumlah != 1:
            print(f"GERBANG: jangkar {nama} muncul {jumlah}x, harus 1 -- "
                  "harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    program = _program(io.open(LINT, encoding="utf-8").read())
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 66 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    lint_lama = _baca_lint(PRA)
    if lint_lama is None or RULE_HEADER in lint_lama:
        print(f"GERBANG: lint pra-perbaikan ({PRA}) tidak terbaca atau sudah "
              "memuat Aturan 66 -- arah kedua tidak bisa dijalankan.",
              file=sys.stderr)
        sys.exit(2)

    def terapkan(mutasi):
        if mutasi == "SEMUA":
            # Buang **pemanggilan**, bukan deklarasinya: nama lama tetap
            # muncul di deklarasi model, dan aturan memerah karena aksesornya
            # tidak ditemukan -- persis keadaan fail-closed yang dimaksud.
            isi = {}
            for j in BERKAS:
                teks = asli[j]
                teks = re.sub(r"\bNightPaletteSelector\s*\.\s*palette\s*\(",
                              "PaletteHilang(", teks)
                teks = re.sub(r"\bCelestialVisual\s*\.\s*candidate(?:Stroke|Fill)\s*\(",
                              "KandidatHilang(", teks)
                teks = re.sub(r"SurfacePalette\s*\.\s*hairlineOpacity\s*\(",
                              "GarisHilang(", teks)
                isi[j] = teks
        else:
            isi = dict(asli)
            for jalur, cari, ganti in mutasi:
                n = isi[jalur].count(cari)
                if n != 1:
                    return None
                isi[jalur] = isi[jalur].replace(cari, ganti, 1)
        for jalur in BERKAS:
            mutasi_sumber.write_source(jalur, isi[jalur])
        return isi

    salah = 0
    try:
        print("── Aturan 66 sekarang ──")
        for label, mutasi, harap in STATES:
            if terapkan(mutasi) is None:
                print(f"JANGKAR TIDAK DITEMUKAN: {label}")
                salah += 1
                continue
            menyala, detail = _jalankan(program)
            if menyala is None:
                print(f"PROBE GAGAL: {label}: {detail}")
                salah += 1
                continue
            ok = menyala == harap
            salah += 0 if ok else 1
            print(f"{'OK   ' if ok else 'SALAH'} {label:38s} "
                  f"{'MERAH' if menyala else 'hijau'}")
            if not ok:
                print(f"       {detail[:500]}")

        print("\n── arah kedua: lint pra-perbaikan (wajib HIJAU) ──")
        for label, mutasi, harap in STATES:
            if not harap:
                continue
            if terapkan(mutasi) is None:
                continue
            menyala, detail = _jalankan_lint_lama(lint_lama)
            if menyala is None:
                print(f"PROBE GAGAL: {label}: {detail}")
                salah += 1
                continue
            ok = not menyala
            salah += 0 if ok else 1
            print(f"{'OK   ' if ok else 'SALAH'} pra: {label:32s} "
                  f"{'MERAH' if menyala else 'hijau'}")
    finally:
        for jalur in BERKAS:
            mutasi_sumber.restore_verified(jalur, asli[jalur])

    print()
    if salah:
        print(f"{salah} keadaan tidak sesuai harapan")
        sys.exit(1)
    print("0 keadaan tidak sesuai harapan")


if __name__ == "__main__":
    main()
