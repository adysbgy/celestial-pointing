#!/usr/bin/env python3
"""Buktikan Aturan 44 menutup celahnya: **objek yang digambar dipilih sendiri di Apps/**.

Kenapa harness ini ada.

Siklus "gambar objek tak bisa lagi berasal dari benda selain yang tertulis di
kartunya" memindahkan **pemilihan objek** ke `PointingKit`
(`PointingSnapshot.displayedVisual(lastLocked:)`). Perpindahannya diuji
(`VisualAssemblyTests`), tetapi **gerbang yang menutupnya tidak pernah ditulis**.

Akibatnya terukur: menjalankan **seluruh** `swift-ui-lint.sh` di atas salinan
yang dimutasi

    PointingEngine.swift:588
    -   guard let object = displayedObject else { return nil }
    +   guard let object = lastLockedObject else { return nil }

menghasilkan exit **0** dan "== SEMUA GERBANG UI LULUS ==". Dua pengikatan itu
sama-sama sah secara sintaks, sama-sama bukan `nil`, dan tidak ada teks di
layar yang membedahnya: kartu menampilkan nama Jupiter dengan gambar cincin
Saturnus di sebelahnya. Itu persis cacat yang dilarang PRD — gambar
mengklaim identitas yang tidak dimiliki engine saat ini.

Kenapa 43 aturan lainnya buta, bukan lalai.

  - Aturan 42 menyapu **permukaan bertipe Optional** di `Apps/` yang namanya
    ada sebagai anggota `PointingKit`. `visualForDisplayedObject` bukan
    penerusan satu fakta: ia merakit tujuh sumber, jadi ia tidak masuk
    cakupannya (itu sudah dinyatakan di docstring Aturan 42).
  - Aturan 43 menyapu **String** yang dirangkai dari beberapa fakta engine.
    `visualForDisplayedObject` mengembalikan `CelestialVisual?`, bukan String.
    Versi pertama **docstring Aturan 43** mengklaim ia menutup cacat ini —
    klaim yang salah ukur, dan sekarang dikoreksi di sana.
  - Aturan 31 menelusuri kawat **fase** sebagai nilai. Objeknya sendiri
    diasumsikan benar.

Aturan 44 menutupnya dengan **daftar putih sumber**: `let object = …` di
`Apps/` harus turun dari `displayedObject` / `displayedVisual(...)`. Bukan
daftar hitam: bentuk cacat yang dulu lolos adalah bentuk yang belum
terpikirkan penulisnya, jadi daftar hitam persis yang akan tertinggal.

Keadaan yang diuji.

  [baseline]                        diam  (kalau tidak, harness salah)
  1. PointingEngine -> lastLockedObject            berbunyi
  2. PointingEngine -> answeredIntent?.best        berbunyi
  3. PointingEngine -> snapshot.intent?.best       berbunyi
  4. ReducedLuminanceView -> engine.lastLockedObject   berbunyi
  5. sah: `displayedVisual(lastLocked:)` sebagai sumber   diam
  6. sah: berkas apa adanya                        diam

Keadaan 5 dan 6 bukan hiasan. Tanpa keadaan 5, aturan yang melaporkan **setiap**
pengikatan `let object =` akan lulus 1–4 dengan sempurna — dan itu gerbang yang
akan dimatikan orang pada hari pertama. Tanpa keadaan 6, harness mengukur
salinan yang tidak pernah cocok dengan produksi.

Non-vakuositas diukur, bukan diklaim: keadaan 1–4 dijalankan ulang dengan
pembaca aturan **dimatikan** (pola `IKATAN` diganti pola yang tidak pernah
cocok, atributnya tetap ada supaya program tidak mati dengan `NameError`).
Kalau di sana mereka berbalik diam, maka yang berbunyi memang pembaca baru itu.

Yang TIDAK diklaim harness ini.

- Ia mengukur **teks** `Apps/`, bukan tampilan di perangkat.
- Pembacanya mengenal **nama** di sebelah kanan `=`, bukan tipe. Pengikatan
  lewat variabel perantara (`let o = lastLockedObject; let object = o`) tidak
  terlihat. Batas itu dinyatakan di docstring aturannya juga.
- Ia tidak membuktikan `displayedVisual(lastLocked:)` mengembalikan benda yang
  benar — itu kerja `VisualAssemblyTests` (Linux).

Pakai:
    python3 Tools/bukti-mutasi-objek-gambar.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

TARGET_ENGINE = os.path.join("Apps", "Shared", "PointingEngine.swift")
TARGET_REDUCED = os.path.join("Apps", "PointAndKnowWatch", "Sources",
                              "ReducedLuminanceView.swift")

#: Jangkar **tanpa pengisian**: jangkar yang memuat penggantinya membuat
#: pemeriksa jangkar buta selamanya (pelajaran `-planet-tetap.py`).
ANCHOR_ENGINE = "        guard let object = displayedObject else { return nil }"
ANCHOR_REDUCED = "        if let object = engine.displayedObject {"

#: (label, berkas, pengganti, harus_berbunyi). `None` = biarkan apa adanya.
STATES = [
    ("[baseline]", TARGET_ENGINE, None, False),
    ("1. PointingEngine: objek dari lastLockedObject",
     TARGET_ENGINE,
     "        guard let object = lastLockedObject else { return nil }", True),
    ("2. PointingEngine: objek dari answeredIntent?.best",
     TARGET_ENGINE,
     "        guard let object = controller.answeredIntent?.best "
     "else { return nil }", True),
    ("3. PointingEngine: objek dari snapshot.intent?.best",
     TARGET_ENGINE,
     "        guard let object = snapshot.intent?.best else { return nil }",
     True),
    ("4. ReducedLuminanceView: objek dari lastLockedObject",
     TARGET_REDUCED,
     "        if let object = engine.lastLockedObject {", True),
    ("5. sah: sumbernya displayedVisual(lastLocked:)",
     TARGET_ENGINE,
     "        guard let object = snapshot.displayedVisual(lastLocked: "
     "lastLockedObject)?.object else { return nil }", False),
    ("6. sah: berkas apa adanya", TARGET_REDUCED, None, False),
]

#: Penanda pembaca aturan. Diganti pola yang tidak pernah cocok untuk uji
#: non-vakuositas.
PENANDA = 'IKATAN = re.compile('


def ekstrak_aturan() -> str:
    """Ambil program Python Aturan 44 dari `swift-ui-lint.sh`.

    Dicari lewat penanda `echo "== Aturan 44:` lalu blok `python3 - <<'PY'`
    pertama sesudahnya — sama seperti `bukti-mutasi-permukaan-nilai.py`.
    Menyalin programnya ke sini berarti mengukur **salinan**.
    """
    src = open(LINT, encoding="utf-8").read()
    header = re.compile(r'^echo "== Aturan (\d+):', re.M)
    marks = list(header.finditer(src))
    for i, m in enumerate(marks):
        if m.group(1) != "44":
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(src)
        section = src[m.start():end]
        prog = re.search(r"python3 - <<'PY'[^\n]*\n(.*?)\nPY\n", section, re.S)
        if not prog:
            sys.exit("GERBANG: Aturan 44 tidak menjalankan python3 - <<'PY' "
                     "— pembaca ini perlu disesuaikan.")
        return prog.group(1)
    sys.exit("GERBANG: Aturan 44 tidak ditemukan di swift-ui-lint.sh.")


def matikan_pembaca(program: str) -> str:
    """Buat aturan berhenti melihat pengikatan apa pun — atributnya tetap ada."""
    if PENANDA not in program:
        sys.exit("GERBANG: program Aturan 44 tidak memuat penanda "
                 f"`{PENANDA}`; harness non-vakuositas ini perlu disesuaikan "
                 "sebelum ia bisa mengukur apa pun.")
    baris = program.split("\n")
    for i, b in enumerate(baris):
        if PENANDA in b:
            # `re.compile(r'(?!x)x')` tidak pernah cocok, tetapi atributnya
            # tetap ada — jadi programnya tidak mati dengan NameError.
            baris[i] = b[:b.index("re.compile(")] + "re.compile(r'(?!x)x')"
            break
    return "\n".join(baris)


def jalankan(program: str, sandbox: str) -> tuple[int, str]:
    proc = subprocess.run([sys.executable, "-c", program],
                          capture_output=True, text=True, cwd=sandbox,
                          env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
    gabung = proc.stdout + proc.stderr
    if "Traceback (most recent call last)" in gabung:
        sys.exit("GERBANG: program Aturan 44 mati dengan traceback — harness "
                 "ini tidak bisa mengukur apa pun.\n" + gabung)
    return proc.returncode, gabung


def berbunyi(out: str) -> bool:
    """Keluaran dihitung berbunyi hanya bila ia **temuan**, bukan keadaan bersih.

    Aturan yang mencetak "Bersih:" atau "PERINGATAN" tidak boleh terbaca
    sebagai berbunyi (pelajaran `bukti-mutasi-permukaan-nilai.py`: aturan yang
    dimatikan pernah terbaca sebagai temuan).
    """
    s = out.strip()
    if not s:
        return False
    if "Bersih:" in s or "PERINGATAN" in s:
        return False
    return True


def main() -> int:
    program = ekstrak_aturan()
    mati = matikan_pembaca(program)

    asli = {
        TARGET_ENGINE: open(os.path.join(ROOT, TARGET_ENGINE),
                            encoding="utf-8").read(),
        TARGET_REDUCED: open(os.path.join(ROOT, TARGET_REDUCED),
                             encoding="utf-8").read(),
    }
    jangkar = {TARGET_ENGINE: ANCHOR_ENGINE, TARGET_REDUCED: ANCHOR_REDUCED}
    for berkas, teks in asli.items():
        n = teks.count(jangkar[berkas])
        if n != 1:
            sys.exit(f"GERBANG: jangkar di {berkas} muncul {n}x, harus tepat "
                     "1x — jangkar ini basi, perbarui sebelum harness jalan.")

    gagal: list[str] = []
    cacat: list[tuple[str, str, str]] = []

    # ── a. Semua keadaan, atas aturan yang sekarang. ───────────────────────
    for label, berkas, pengganti, harus in STATES:
        sandbox = tempfile.mkdtemp(prefix="objek-gambar-")
        try:
            teks = asli[berkas]
            isi = teks if pengganti is None else teks.replace(
                jangkar[berkas], pengganti, 1)
            if pengganti is not None and isi == teks:
                gagal.append(f"  {label}: penggantinya identik dengan jangkar")
                continue
            target = os.path.join(sandbox, berkas)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8") as h:
                h.write(isi)
            _, out = jalankan(program, sandbox)
            fired = berbunyi(out)
            if fired != harus:
                gagal.append(f"  {label}: {'berbunyi' if fired else 'diam'} "
                             f"padahal seharusnya "
                             f"{'berbunyi' if harus else 'diam'}")
            if harus:
                cacat.append((label, berkas, pengganti))
        finally:
            shutil.rmtree(sandbox, ignore_errors=True)

    # ── b. Non-vakuositas: tanpa pembacanya, cacat berbalik diam. ──────────
    for label, berkas, pengganti in cacat:
        sandbox = tempfile.mkdtemp(prefix="objek-gambar-")
        try:
            target = os.path.join(sandbox, berkas)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8") as h:
                h.write(asli[berkas].replace(jangkar[berkas], pengganti, 1))
            _, out = jalankan(mati, sandbox)
            if berbunyi(out):
                gagal.append(f"  {label}: tetap berbunyi walau pembaca aturan "
                             "dimatikan — yang berbunyi bukan Aturan 44")
        finally:
            shutil.rmtree(sandbox, ignore_errors=True)

    print("bukti-mutasi-objek-gambar.py  "
          f"{len(STATES)} keadaan + {len(cacat)} non-vakuositas")
    if gagal:
        print("\n".join(gagal))
        print(f"\nGAGAL: {len(gagal)} keadaan tidak sesuai harapan.")
        return 1
    print("SESUAI HARAPAN: setiap keadaan cacat berbunyi, setiap keadaan sah "
          "diam, dan semuanya diam bila pembacanya dimatikan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
