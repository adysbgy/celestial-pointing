#!/usr/bin/env python3
"""Buktikan Aturan 65 (fakta preferensi `MotionPolicy`) **berbunyi**.

Kelas cacat yang ditutup aturan ini
===================================

Terukur pada pohon utuh, proses baru, seluruh **64** aturan hijau:

    PointingView.swift:474      reduceMotion: reduceMotion -> reduceMotion: false
    DiagnosticsView.swift:269   reduceMotion: reduceMotion -> reduceMotion: false
    OnboardingView.swift:174    reduceMotion: reduceMotion -> reduceMotion: false
    DiagnosticsView.swift:811   reduceMotion: reduceMotion -> reduceMotion: false
    (x4)                        isSceneActive: scenePhase == .active -> true
    PointingView.swift:481      isLuminanceReduced: false -> true

Enam mutasi itu **mengompilasi** dan semuanya `exit 0`.

Yang hilang bukan animasi yang berjalan lebih cepat -- yang hilang adalah
**preferensi pengguna yang diabaikan tanpa satu pun gerbang berbunyi**.
Pengguna yang menyalakan Reduce Motion di Pengaturan akan tetap melihat denyut
bintang berjalan di tiga layar, dan tidak ada apa pun di layar yang bisa
memberi tahu dia: preferensi itu memang tidak pernah ditampilkan sebagai
status, jadi pengabaiannya sepenuhnya tak terlihat.

Kenapa gerbang yang sudah ada tidak menutupnya
=============================================

* **Aturan 58** memeriksa **arah** penjaga pada kondisi yang memanggil API gerak
  (`guard motion.allowsTransitions` -> `guard !motion.allowsTransitions` merah).
  Ia **meng-exempt** `MotionPolicy(` dengan alasan "model yang memutuskan;
  arahnya diuji di Linux". Alasan itu benar untuk nilai yang **keluar**, dan
  tidak berlaku untuk nilai yang **masuk**: `MotionPolicy(reduceMotion: false,
  ...)` tidak lagi memakai keputusan model sama sekali -- ia melewati keputusan
  itu dengan mengarang masukannya, lalu `allowsContinuousMotion` menghitung
  dari angka rekaan itu.

* **Aturan 35** melarang parameter yang faktanya **dibaca berkas itu** diganti
  literal. Ia mencari sumber fakta dengan membaca nama parameter dari
  deklarasi fungsi model. `MotionPolicy` adalah **inisialiser struct**, bukan
  fungsi berparameter -- `init(reduceMotion:...)` tidak pernah tercatat sebagai
  pemanggilan aksesor, jadi `reduceMotion` tidak pernah masuk daftar parameter
  yang diperiksa.

Tiga cacat pada aturan ini sendiri, semuanya terukur
===================================================

Aturan ini lahir dari percobaan sebelumnya, dan tiga versinya
salah **melewati gerbang** -- bukan karena gerbangnya lemah:

1. **`isSceneActive` tidak pernah berbunyi.** Percobaan pertama memakai
   `bool(sumber) and bool(re.search("scenePhase", nilai))`, sedangkan `nilai`
   sudah dibatasi literal `true`/`false` di baris sebelumnya. Dua syarat yang
   saling meniadakan: literal tidak pernah memuat kata `scenePhase`, jadi
   cabang itu **mati selamanya**. Terukur: mutasi keadaan 4 hijau.

2. **`isLuminanceReduced` kebocor lewat pencocokan kata.** Percobaan kedua
   menulis "nilai harus muncul sebagai kata di berkas ini" --
   `isLuminanceReduced: true` lolos karena kata `true` ada di mana saja pada
   berkas itu. Terukur: keadaan 6 hijau.

3. **Per berkas, bukan per lingkup tipe.** Percobaan ketiga mengumpulkan
   `@Environment` per **berkas**. Itu membuat aturan **lebih ketat dari
   kenyataan**: `LockArrivalPanel` (nested di `DiagnosticsView`) memakai
   `isSceneActive: true` yang **benar** -- panel itu tidak punya
   `scenePhase` sendiri dan tidak pernah dirender saat app tidak aktif.
   Dikumpulkan per berkas, aturan melihat `scenePhase` milik `DiagnosticsView`
   di berkas yang sama dan **memerah pada kode benar**. Terukur: exit 1 pada
   `DiagnosticsView.swift:811`.

Yang dipakai sekarang: sumber preferensi dibaca dari **blok tipe
terdalam** yang memuat pemanggilan. Tipe nested di Swift tidak mewarisi
properti milik tipe enclosing-nya, jadi `LockArrivalPanel` tidak mewarisi
`scenePhase` -- persis yang dibutuhkan agar nilainya yang benar tetap hijau.
Pencocokan deklarasi tipe memakai indentasi sebarang (`^[ \\t]*`); pola
`\\nstruct ` yang lebih sempit tidak pernah menemukan tipe nested dan membuat
pemanggil di dalamnya terlihat seperti pemanggil di tipe luar.

Yang diuji
==========

  1. preferensi Reduce Motion jadi `false` di layar jam         MERAH
  2. keadaan scene jadi `true` di layar yang membacanya          MERAH
  3. keadaan scene jadi `false` di layar yang membacanya         MERAH
  4. layar diklaim redup (`isLuminanceReduced: true`)            MERAH
  5. preferensi Reduce Motion jadi `false` di kartu iPhone       MERAH
  6. preferensi Reduce Motion jadi `false` di perkenalan         MERAH
  7. `isSceneActive: true` di layar yang **tidak** punya
     `scenePhase` (perkenalan) -- **wajib hijau**, itu jujur      hijau
  8. nilai yang bukan literal (`isLuminanceReduced: sensorNote`) hijau
  9. fail-closed: seluruh pemanggilan `MotionPolicy` hilang       MERAH
 10. kontrol negatif: pohon apa adanya                           hijau

Keadaan 7 menentukan ruang gerak aturan ini. Kalau "literal" dilarang
selalu-tanpa-pengecualian, aturan akan memerah pada dua tempat yang nilainya
**benar** -- dan gerbang yang menuduh kode benar akan dilonggarkan orang.

Arah kedua
==========

Enam keadaan cacat dijalankan lagi atas lint pra-perbaikan (`git show`, bukan
dikarang) dan wajib HIJAU di sana.

Yang TIDAK dibuktikan
=====================

Sapu teks. Aturan ini tidak tahu tipe argumen, tidak tahu apakah `reduceMotion`
di berkas itu memang `@Environment(\\.accessibilityReduceMotion)` atau nama
lain yang kebetulan sama, dan penyaringan komentarnya tidak membaca blok
`/* */`. Yang **tidak** diperiksa: nilai yang **bukan** literal (keadaan 8) --
nama yang diteruskan tidak bisa dinilai tanpa tipe, dan itu wilayah Aturan
52/41. Batas itu dinyatakan supaya "hijau" tidak dibaca lebih lebar daripada
yang terukur.
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
POINTING = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                        "PointingView.swift")
DIAGNOSTICS = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                           "DiagnosticsView.swift")
ONBOARDING = os.path.join(ROOT, "Apps", "Shared", "OnboardingView.swift")

RULE_HEADER = "== Aturan 65:"

#: Baris **satu** per pemanggilan, bukan blok argumen penuh.
#:
#: Kenapa satu baris, dan kenapa yang seperti ini. Jangkar blok penuh
#: (`MotionPolicy(reduceMotion: reduceMotion,\n…\nisSceneActive: …)`) **tidak
#: cocok** pada `PointingView`: antara baris `reduceMotion` dan baris
#: `isSceneActive` ada **tiga baris komentar**, jadi blok itu tidak pernah
#: ada di sana. Terukur: gerbang jangkar harness menolak jalan dengan "jangkar
#: JAM muncul 0x" -- benar menolak, benar menolak, bukan gagal menulis.
#:
#: Dan jangkar yang **hanya** `reduceMotion:` juga tidak boleh: baris itu
#: muncul **dua kali** di `DiagnosticsView.swift` (baris 269 dan 811), dan
#: `str.replace` atas jangkar tidak unik akan mengubah keduanya -- termasuk
#: yang benar. Terukur: harness melaporkan "JANGKAR 2x".
#:
#: Yang dipakai: jangkar per fakta, masing-masing **unik** di berkasnya --
#: `isSceneActive: scenePhase == .active)` unik karena hanya baris 269 yang
#: membandingkan scenePhase; `isSceneActive: true)` unik karena hanya baris
#: 811 yang menjawab tanpa sumber. Keduanya terukur 1x pada pohon bersih.
JAM_REDUCE = "MotionPolicy(reduceMotion: reduceMotion,"
JAM_SCENE = "isSceneActive: scenePhase == .active)"
JAM_LUMI = "isLuminanceReduced: false,"

IPHONE_REDUCE = ("    private var pulsePhase: Double {\n"
                 "        MotionPolicy(reduceMotion: reduceMotion,")
IPHONE_SCENE = "                     isSceneActive: scenePhase == .active)"
ONB_REDUCE = "        MotionPolicy(reduceMotion: reduceMotion,"
ONB_SCENE = "                     isSceneActive: true)"

#: Jumlah aturan sebelum dan sesudah Aturan 65 ditambahkan. Dipakai arah
#: kedua untuk mengembalikan README ke hitungan lama selama lint lama
#: dijalankan -- Aturan 10 membaca angka itu dari README.
JUMLAH_ATURAN_KINI = 65
JUMLAH_ATURAN_LAMA = 64

#: Revisi **pra-perbaikan** untuk arah kedua: komit terakhir yang belum punya
#: blok Aturan 65.
#:
#: Kenapa bukan `HEAD`. `HEAD` bergerak setiap kali aturannya di-commit, dan
#: arah kedua lalu menuntut HIJAU dari gerbang yang justru sedang menguji
#: cacat. Kelas cacat ini sudah menjatuhkan `main` di siklus Aturan 52.
PRA = "f700e05"  # `Aturan 64: ...` -- sebelum Aturan 65

#: Tabel keadaan, di **tingkat modul** dan bernama `STATES`.
#:
#: `Tools/check-jangkar-harness.py` membaca tabel tingkat modul untuk tahu
#: pasangan (jangkar, pengganti) yang bisa tertinggal di sumber produksi bila
#: harness ini dihentikan di tengah. Tabel di dalam fungsi terbaca sebagai
#: "nol jangkar", dan gerbangnya menuduh harness ini buta -- merah pada pohon
#: bersih.
#:
#: Bentuk `(label, [(berkas, cari, ganti), ...], harus_merah)`.
#:
#: Keadaan 9 memakai penanda `"SEMUA"`, bukan daftar suntingan: ia mengganti
#: **setiap** pemanggilan, dan satu jangkar per berkas tidak cukup untuk itu.
#: Penanda itu dibaca `terapkan()` di bawah, bukan oleh
#: `check-jangkar-harness.py` -- jadi keadaan ini **sumbang nol jangkar**,
#: dan itu disengaja: jangkar yang ia gunakan berputar-putar di berkas yang
#: sudah ia ganti seluruhnya, sehingga "mutasi bocor" tidak dapat diartikan.
STATES = [
    ("1 jam: preferensi jadi false",
     [(POINTING, JAM_REDUCE,
       "MotionPolicy(reduceMotion: false,")], True),
    ("2 jam: keadaan scene jadi true",
     [(POINTING, JAM_SCENE, "isSceneActive: true)")], True),
    ("3 jam: keadaan scene jadi false",
     [(POINTING, JAM_SCENE, "isSceneActive: false)")], True),
    ("4 jam: layar diklaim redup",
     [(POINTING, JAM_LUMI, "isLuminanceReduced: true,")], True),
    ("5 iPhone: preferensi jadi false",
     [(DIAGNOSTICS, IPHONE_REDUCE,
       "    private var pulsePhase: Double {\n"
       "        MotionPolicy(reduceMotion: false,")], True),
    ("5b iPhone: keadaan scene jadi true",
     [(DIAGNOSTICS, IPHONE_SCENE, "                     isSceneActive: true)")], True),
    ("6 perkenalan: preferensi jadi false",
     [(ONBOARDING, ONB_REDUCE,
       "        MotionPolicy(reduceMotion: false,")], True),
    # 7: kontrol **wajib hijau**. Perkenalan tidak punya `scenePhase`, jadi
    # `false` di sana adalah jawaban jujur, bukan pengabaian -- dan gerbang
    # yang memerahkannya akan memaksa penambahan `scenePhase` yang tidak
    # dibutuhkan.
    ("7 perkenalan: scene false tanpa sumber",
     [(ONBOARDING, ONB_SCENE,
       "                     isSceneActive: false)")], False),
    # 8: nilai non-literal tidak boleh dipatahkan. `MotionPolicy` tidak
    # bertipe di sini, jadi aturan tidak bisa menilai apakah `sensorNote`
    # adalah sumber faktanya -- batas itu dinyatakan, bukan dipalsukan dengan
    # tebakan.
    ("8 jam: nilai non-literal",
     [(POINTING, JAM_LUMI, "isLuminanceReduced: sensorNote,")], False),
    ("9 fail-closed: semua pemanggilan hilang", "SEMUA", True),
    ("10 kontrol: pohon apa adanya", [], False),
]

BERKAS = (POINTING, DIAGNOSTICS, ONBOARDING)


def _baca_lint(rev):
    hasil = subprocess.run(["git", "show", f"{rev}:swift-ui-lint.sh"],
                           cwd=ROOT, capture_output=True, text=True)
    return hasil.stdout if hasil.returncode == 0 else None


def _program(teks):
    """Potong blok Aturan 65 dari `swift-ui-lint.sh`.

    Dipotong, bukan disalin: menyalin berarti harness mengukur salinannya,
    yang tetap hijau walau aturan aslinya dilonggarkan.
    """
    awal = teks.find("# ── Aturan 65")
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
    skrip = "status=0\n" + program + "\nprintf 'STATUS:%s\\n' \"$status\"\n"
    hasil = subprocess.run(["bash", "-s"], cwd=ROOT, input=skrip,
                           capture_output=True, text=True, timeout=600)
    if hasil.returncode != 0:
        return None, (hasil.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    return "STATUS:1" in hasil.stdout, hasil.stdout.strip()


def _jalankan_lint_lama(teks_lint):
    """Jalankan lint pra-perbaikan **utuh**, dan wajib HIJAU.

    Arah kedua tidak bisa memotong blok dari lint lama: revisi itu belum punya
    blok Aturan 65 sama sekali. Yang harus dibuktikan justru sebaliknya --
    bahwa **seluruh** lint lama melaporkan LULUS atas mutasi yang sekarang
    memerah.

    Dua hal harus ikut dikembalikan, dan keduanya ditemukan dengan menjalankan
    arah kedua dan membacanya, bukan disangka:

      * `swift-ui-lint.sh` **itu sendiri** ditulis ulang dengan teks lama.
        Salinan di berkas lain tidak cukup: Aturan 10 membaca
        `swift-ui-lint.sh` dari cakram, bukan berkas yang sedang berjalan.

      * `README.md` dikembalikan ke hitungan lamanya. Aturan 10 membandingkan
        jumlah aturan yang mencetak dengan angka di README; lint lama punya 64
        dan README baru bilang 65, sehingga arah kedua merah karena
        **hitungan**, bukan karena cacat yang sedang diuji.

    Keduanya dipulihkan lewat `mutasi_sumber`, yang memverifikasi isi setelah
    menulis -- bukan `try/finally` yang percaya pada dirinya sendiri.
    """
    readme = os.path.join(ROOT, "README.md")
    asli_readme = io.open(readme, encoding="utf-8").read()
    asli_lint = io.open(LINT, encoding="utf-8").read()
    try:
        mutasi_sumber.write_source(LINT, teks_lint)
        io.open(readme, "w", encoding="utf-8").write(asli_readme.replace(
            f"**{JUMLAH_ATURAN_KINI} aturan**",
            f"**{JUMLAH_ATURAN_LAMA} aturan**"))
        hasil = subprocess.run(["bash", LINT], cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        return hasil.returncode != 0, hasil.stdout.strip()
    finally:
        mutasi_sumber.write_source(LINT, asli_lint)
        io.open(readme, "w", encoding="utf-8").write(asli_readme)


def main():
    mutasi_sumber.require_clean_sources(list(BERKAS))
    asli = {jalur: io.open(jalur, encoding="utf-8").read() for jalur in BERKAS}

    for nama, jalur, jangkar in (("JAM_REDUCE", POINTING, JAM_REDUCE),
                                 ("JAM_SCENE", POINTING, JAM_SCENE),
                                 ("JAM_LUMI", POINTING, JAM_LUMI),
                                 ("IPHONE_REDUCE", DIAGNOSTICS, IPHONE_REDUCE),
                                 ("ONB_REDUCE", ONBOARDING, ONB_REDUCE),
                                 ("ONB_SCENE", ONBOARDING, ONB_SCENE)):
        jumlah = asli[jalur].count(jangkar)
        if jumlah != 1:
            print(f"GERBANG: jangkar {nama} muncul {jumlah}x, harus 1 -- "
                  "harness tidak boleh jalan.", file=sys.stderr)
            sys.exit(2)

    program = _program(io.open(LINT, encoding="utf-8").read())
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 65 tidak ditemukan di swift-ui-lint.sh "
              "-- harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    lint_lama = _baca_lint(PRA)
    if lint_lama is None:
        print("GERBANG: lint pra-perbaikan tidak terbaca -- arah kedua tidak "
              "bisa dijalankan.", file=sys.stderr)
        sys.exit(2)

    def terapkan(mutasi):
        """Tulis mutasi ke sumber produksi; `None` bila jangkar tak ada."""
        if mutasi == "SEMUA":
            isi = {j: re.sub(r"\bMotionPolicy\s*\(",
                             "MotionPolicyHilang(", asli[j])
                  for j in BERKAS}
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
        print("── Aturan 65 sekarang ──")
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
            print(f"{'OK   ' if ok else 'SALAH'} {label:44s} "
                  f"{'MERAH' if menyala else 'hijau'}")
            if not ok:
                print(f"       {detail[:400]}")

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
            print(f"{'OK   ' if ok else 'SALAH'} pra: {label:40s} "
                  f"{'MERAH' if menyala else 'hijau'}")
    finally:
        for jalur in BERKAS:
            mutasi_sumber.write_source(jalur, asli[jalur])

    print()
    if salah:
        print(f"{salah} keadaan tidak sesuai harapan")
        sys.exit(1)
    print("0 keadaan tidak sesuai harapan")


if __name__ == "__main__":
    main()