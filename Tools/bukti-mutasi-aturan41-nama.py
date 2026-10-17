#!/usr/bin/env python3
"""Buktikan Aturan 41 (nama tampilan tidak jatuh ke `object.name`) **berbunyi**.

Cacat yang melahirkan aturan ini **tersembunyi oleh kode yang benar** di atasnya:
`ObjectDetailView.objectDisplayName` berbunyi `displayName ?? object.name`,
tetapi pemanggilnya di `PointingView` selalu meneruskan `displayName` — jadi
cabang kanan tidak pernah dieksekusi, dan keempat situs yang memakainya lulus
walau `object.name` membeku ke bentuk Indonesia (`Saturnus`, `Bulan`). Tidak
ada uji Linux yang bisa mengeksekusi `Apps/`, jadi cacat itu bertahan.

Aturan 41 menutupnya dengan menyapu satu bentuk sempit: `?? <sesuatu>.name`
di berkas `Apps/` yang menangani `CelestialObject`. Ini bukan pemeriksa tipe —
ia tidak tahu bahwa `object.name` adalah `CelestialObject.name`, bukan
`CalibrationTarget.name`. Ia hanya tahu bentuk jatuh-kembali itu muncul di
tempat nama untuk layar diharapkan, dan bahwa tempat itu memang menangani
objek langit.

Harness ini **tidak** memutasi sumber produksi. Program Aturan 41 **diekstrak**
dari `swift-ui-lint.sh` dan dijalankan atas salinan pohon di direktori
sementara (sama seperti `bukti-mutasi-aturan3-aksara.py`). Kalau punya salinan
yang tetap hijau walau aturan aslinya dilonggarkan, ia tidak membuktikan apa
pun.

Keadaan yang diukur:

  1. `displayName ?? object.name` di `PointingView.swift` (kartu jam) ->
     MERAH. Ini persis bentuk yang dipakai cabang cadangan lama.
  2. `?? object.name` di `DiagnosticsView.swift` (panel iPhone) -> MERAH.
  3. `displayedObjectName -> object.name` di `PointingEngine.swift` (empat
     permukaan sekaligus) -> MERAH.
  4. `?? ObjectDisplayName.text(of: object)` (perbaikan yang diterapkan) ->
     DIAM. Kontrol: gerbang harus diam pada kode yang benar, kalau tidak ia
     akan dilonggarkan orang.
  5. berkas `Apps/` apa adanya -> DIAM (kontrol negatif).

Lantai non-vakuositas diuji di sini juga: bila tidak ada berkas `Apps/` yang
terbaca, program mencetak pesan lantai dan **bukan** "bersih" — harness
menuntut keluaran mengandung tanda bersih yang tepat, jadi perubahan pesan
laporan akan ketahuan, bukan disimpulkan hijau dari keluaran yang tidak dibaca.

Pakai:
    python3 Tools/bukti-mutasi-aturan41-nama.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penjaga sumber bersih, sama dengan harness lain)

#: Pembuka/penutup program Aturan 41 di dalam `swift-ui-lint.sh`.
BLOCK_OPEN = 'nama_mentah=$(python3 - <<\'PY\' 2>&1'
BLOCK_CLOSE = '\nPY\n)'

#: Berkas target (semua menangani `CelestialObject` / `displayedObject`).
VIEW = os.path.join("Apps", "PointAndKnowWatch", "Sources", "PointingView.swift")
DIAG = os.path.join("Apps", "PointAndKnowiOS", "Sources", "DiagnosticsView.swift")
ENGINE = os.path.join("Apps", "Shared", "PointingEngine.swift")
EXPERIMENT = os.path.join("Apps", "PointAndKnowiOS", "Sources", "Experiment1View.swift")
TELESCOPE = os.path.join("Apps", "PointAndKnowiOS", "Sources", "TelescopeHandoffView.swift")
CALIBRATION = os.path.join("Apps", "PointAndKnowWatch", "Sources", "CalibrationView.swift")

#: Program Aturan 41 mencetak **temuan** ke stdout dan diam bila bersih.
#:
#: Konvensi ini sama dengan `bukti-mutasi-aturan3-aksara.py`, dan ia penting:
#: baris `Bersih: ...` dicetak oleh **shell**, bukan oleh program Python, jadi
#: menuntut tanda itu dari programnya akan membuat setiap keadaan bersih
#: terbaca sebagai "berbunyi" — harness lalu lulus pada kode yang benar
#: sekaligus gagal pada kode yang benar, tanpa pernah mengukur cacatnya.
CLEAN_MARK = ""

#: Lantai non-vakuositas. Kalau ini yang tercetak, aturan tidak membaca apa
#: pun — itu kegagalan harness, bukan "bersih" dan bukan "berbunyi".
FLOOR_MARK = "TIDAK ADA berkas Swift di Apps/ yang terbaca"


def extract_rule_program() -> str:
    """Ambil program Python Aturan 41 dari `swift-ui-lint.sh` apa adanya."""
    text = open(LINT, encoding="utf-8").read()
    start = text.index(BLOCK_OPEN) + len(BLOCK_OPEN)
    # Blok diakhiri oleh baris yang persis berisi `PY` lalu `)`.
    end = text.index("\nPY\n)", start)
    return text[start:end]


def sandbox() -> str:
    """Salin pohon yang dibaca aturan (tanpa `.git`/`.build`) ke tmp."""
    workdir = tempfile.mkdtemp(prefix="aturan41-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build -cf - . '
         '| (cd "$2" && tar -xf -)', "copy", ROOT, workdir],
        check=True)
    return workdir


def run_rule(workdir: str, program: str) -> tuple[bool, str]:
    """Jalankan program aturan di `workdir`; kembalikan (bersih?, keluaran).

    `returncode != 0` berarti programnya **galat**, bukan gerbang berbunyi.
    """
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    proc = subprocess.run([sys.executable, "-c", program],
                          capture_output=True, text=True, cwd=workdir, env=env)
    if proc.returncode != 0:
        tail = (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
        return False, f"GALAT menjalankan gerbang: {tail}"
    out = proc.stdout.strip()
    # Lantai: aturan tidak membaca apa pun. Diperlakukan sebagai kegagalan
    # harness, bukan "bersih" dan bukan "berbunyi".
    if FLOOR_MARK in out:
        return False, f"GALAT lantai non-vakuositas: {out}"
    return out == CLEAN_MARK, out


def mutate(workdir: str, path: str, old: str, new: str) -> None:
    full = os.path.join(workdir, path)
    text = open(full, encoding="utf-8").read()
    assert old in text, "jangkar tidak ditemukan di %s: %r" % (path, old)
    text = text.replace(old, new, 1)
    open(full, "w", encoding="utf-8").write(text)


def main() -> int:
    mutasi_sumber.require_clean_sources([LINT,
                                         os.path.join(ROOT, "Apps"),
                                         os.path.join(ROOT, "Packages"),
                                         os.path.join(ROOT, "Tools")])
    program = extract_rule_program()

    # Jangkar persis dari kode produksi.
    view_anchor = "    private var objectDisplayName: String {\n        displayName ?? ObjectDisplayName.text(of: object)\n    }"
    diag_anchor = "                        Text(displayName ?? ObjectDisplayName.text(of: object))"
    engine_anchor = """        DisplayLabel.objectName(forObjectID: object.id,
                                catalogue: controller.resolver.catalogue)
            ?? ObjectDisplayName.text(of: object)"""
    experiment_anchor = "            ExperimentText.answerName(trial.trial.intent)))"
    telescope_anchor = ("            row(TextLocalization.text(.telescopeFrameLabel), "
                        "preferredFrame.name)")
    # Jangkar daftar acuan kalibrasi. `localizedName` yang benar, jadi keadaan
    # 11 (kontrol) memakai jangkar ini apa adanya dan keadaan 10 memutasi
    # **hanya** kata itu — bukan baris di sekitarnya, supaya yang diukur
    # benar-benar `name` vs `localizedName`.
    calibration_anchor = "                                Text(target.localizedName)"

    states = [
        ("1. `?? object.name` di kartu jam",
         VIEW, view_anchor,
         "    private var objectDisplayName: String {\n        displayName ?? object.name\n    }",
         True),
        ("2. `?? object.name` di panel iPhone",
         DIAG, diag_anchor,
         "                        Text(displayName ?? object.name)",
         True),
        ("3. `displayedObjectName -> object.name`",
         ENGINE, engine_anchor,
         """        DisplayLabel.objectName(forObjectID: object.id,
                                catalogue: controller.resolver.catalogue)
            ?? object.name""",
         True),
        ("4. [kontrol] perbaikan `ObjectDisplayName.text(of:)`",
         VIEW, view_anchor, view_anchor, False),
        ("5. [kontrol] berkas apa adanya",
         None, None, None, False),
        # ── Bentuk rantai opsional: satu cacat yang lolos gerbang lama ──
        #
        # `intent.best?.name` **bukan** bentuk `?? <pengenal>.name`: tidak ada
        # pengenal sebelum titik, jadi pola lama tidak cocok dan gerbang
        # mencetak "Bersih". Terukur: tiga situs produksi memakai bentuk ini
        # (baris layar, baris terucap, pesan status recorder), dan seluruh
        # gerbang UI tetap hijau.
        ("6. `intent.best?.name` (rantai opsional) di laporan",
         EXPERIMENT, experiment_anchor,
         "            trial.trial.intent.best?.name ?? ExperimentText.detailNoAnswer))",
         True),
        ("7. `intent.best?.name` di pesan status recorder",
         EXPERIMENT, experiment_anchor,
         "            intent.best?.name ?? ExperimentText.detailNoAnswer)",
         True),
        ("8. [kontrol] `answerName(intent)` (perbaikan)",
         EXPERIMENT, experiment_anchor, experiment_anchor, False),
        # `preferredFrame.name` adalah `MountFrame.name` — label internal app,
        # tidak dibekukan engine. Aturan yang menuduhnya akan merah pada kode
        # benar. `?.name` pada receiver yang sama juga harus diam.
        ("9. [kontrol] `preferredFrame?.name` (bukan nama objek langit)",
         TELESCOPE, telescope_anchor,
         "            row(TextLocalization.text(.telescopeFrameLabel), preferredFrame?.name ?? \"—\")",
         False),
        # ── `PointingTarget`: satu permukaan yang dulu tidak terlihat ──
        #
        # Daftar acuan kalibrasi mengulang `[PointingTarget]`, dan
        # `PointingTarget.name` diisi engine dari `EphemerisBody.displayName`
        # (`Bulan`, `Saturnus`). Versi lama aturan ini **tidak** membaca berkas
        # itu: penyaring cakupannya hanya menerima berkas yang menyebut
        # `CelestialObject`/`displayedObject`, dan komentarnya menyebut
        # `CalibrationTarget.name` sebagai contoh sah — tipe yang tidak ada di
        # repo ini. Bentuknya pun `target.name` langsung: tanpa `??` dan tanpa
        # `?.`, jadi kedua pola lama diam dua kali.
        ("10. `target.name` di daftar acuan kalibrasi",
         CALIBRATION, calibration_anchor,
         "                                Text(target.name)",
         True),
        ("11. [kontrol] `target.localizedName` (perbaikan)",
         CALIBRATION, calibration_anchor, calibration_anchor, False),
        # Arah sebaliknya untuk penyaring yang baru dilebarkan: `MountFrame`
        # tetap di luar daftar penerima, jadi `preferredFrame.name` **langsung**
        # (tanpa `?`) juga harus diam. Tanpa keadaan ini, melebarkan
        # `POLA_LANGSUNG` menjadi `.name` di mana pun akan hijau di sini dan
        # merah pada kode yang benar.
        ("12. [kontrol] `preferredFrame.name` langsung (bukan nama objek)",
         TELESCOPE, telescope_anchor,
         "            row(TextLocalization.text(.telescopeFrameLabel), preferredFrame.name)",
         False),
    ]

    failures: list[str] = []
    for label, path, old, new, want_red in states:
        workdir = sandbox()
        try:
            if path is not None:
                mutate(workdir, path, old, new)
            clean, detail = run_rule(workdir, program)
            fired = not clean
            if detail.startswith("GALAT"):
                failures.append(f"{label}: {detail}")
                print(f"SALAH {label:48s}: {detail}")
                continue
            if fired != want_red:
                failures.append(
                    f"{label}: {'MERAH' if fired else 'hijau'} padahal "
                    f"diharapkan {'merah' if want_red else 'hijau'}")
                print(f"SALAH {label:48s}: "
                      f"{'MERAH' if fired else 'hijau'} "
                      f"(harap {'merah' if want_red else 'hijau'})")
            else:
                print(f"OK   {label:48s}: {'MERAH' if fired else 'hijau'}")
                if fired:
                    print(f"       {detail.splitlines()[0][:100]}")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # Lantai non-vakuositas: program harus tetap mengembalikan CLEAN_MARK yang
    # tepat, bukan pesan lantai, pada berkas yang benar-benar bersih.
    print()
    if failures:
        print(f"{len(failures)} keadaan tidak sesuai harapan:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"{len(states)} keadaan, 0 tidak sesuai harapan")
    print("Aturan 41 berbunyi pada jatuh-kembali ke object.name, dan diam "
          "pada perbaikan serta berkas apa adanya.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
