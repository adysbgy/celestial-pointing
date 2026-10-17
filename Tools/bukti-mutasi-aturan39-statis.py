#!/usr/bin/env python3
"""Buktikan gerbang Aturan 39 (anggota `static` dipanggil pada instance) **berbunyi**.

Cacat yang melahirkan aturan ini benar-benar sampai ke `origin/main` dan
memerahkan CI macOS:

    Apps/PointAndKnowWatch/Sources/PointingView.swift:669:28: error:
    static member 'spokenStarClassLine' cannot be used on instance of type
    'CelestialVisual'

Di Linux galat ini **tidak terlihat**: `./swift-typecheck.sh` hanya `-parse`,
dan `./swift-test.sh` tidak pernah membangun `Apps/`. Satu-satunya tempat ia
terlihat adalah runner macOS -- dan itu setelah push. Aturan 39 ada supaya
lokal yang berbunyi lebih dulu.

**Kenapa harness ini ada, padahal aturannya sudah ditulis.** Aturan 39 versi
pertamanya melaporkan "Bersih" sambil memegang indeks yang **kosong**: ia
membaca blok Swift dengan mencacah kurung kurawal per baris, dan di
`CelestialVisual.swift` pencacahnya meleset sehingga seluruh anggota tipe itu
terbaca milik tipe lain. Tiga penyuntingan berturut-turut tetap "Bersih".
Yang menghentikannya bukan pembacaan ulang kode, melainkan menyuntikkan galat
yang **persis** sama dengan CI ke sandbox dan melihat gerbangnya tetap diam.
Karena itu setiap keadaan di bawah disuntikkan, bukan dibayangkan.

Keadaan yang diuji:

    1. `visual.spokenStarClassLine(…)`   -> berbunyi   (bentuk yang gagal di CI)
    2. `v?.spectralClass(…)`, `v` beranotasi `CelestialVisual?`
                                         -> berbunyi   (optional chaining)
    3. `visual.phaseGeometry(…)`         -> DIAM       (kontrol: `phaseGeometry`
                                           punya kembaran instance, jadi ini
                                           kode yang sah -- gerbang yang menuduh
                                           kode benar akan dimatikan orang)
    4. berkas apa adanya                 -> DIAM       (baseline)

Cara mengukur, sama dengan pelajaran `bukti-mutasi-aturan31-kawat.py`: program
Aturan 39 **diekstrak dari `swift-ui-lint.sh`** dan dijalankan langsung di
sandbox yang hanya berisi `Packages/` + `Apps/`. Lint utuh tidak dipanggil,
karena ia punya pra-syarat lain (`project.yml`, README, ...) dan kegagalan
pra-syarat akan terbaca palsu sebagai "gerbang berbunyi". `returncode != 0`
di sini berarti **galat harness**, bukan keberhasilan.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")
SRC = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
VIEW = "Apps/Shared/CelestialVisualView.swift"

MULAI = 'statis_instance=$(python3 - <<\'PY\' 2>&1\n'


def program_aturan39():
    """Ambil program Python milik Aturan 39 dari lint, apa adanya."""
    teks = open(LINT, encoding="utf-8").read()
    i = teks.index(MULAI) + len(MULAI)
    j = teks.index("\nPY\n)", i)
    return teks[i:j]


def jalankan(program, mutasi=None):
    """Jalankan program aturan di sandbox; kembalikan (stdout, stderr).

    Sandbox hanya berisi `Packages/` dan `Apps/<berkas mutasi>`. Dua berkas app
    yang relevan disalin penuh supaya keadaan baseline benar-benar baseline.
    """
    d = tempfile.mkdtemp(prefix="rule39-")
    try:
        shutil.copytree(os.path.join(ROOT, "Packages"), os.path.join(d, "Packages"),
                        ignore=shutil.ignore_patterns(".build"))
        for rel in (SRC, VIEW):
            teks = open(os.path.join(ROOT, rel), encoding="utf-8").read()
            if mutasi and mutasi[0] == rel:
                assert mutasi[1] in teks, "anchor tidak ditemukan di %s: %r" % (
                    rel, mutasi[1][:60])
                teks = teks.replace(mutasi[1], mutasi[2], 1)
            tujuan = os.path.join(d, rel)
            os.makedirs(os.path.dirname(tujuan), exist_ok=True)
            open(tujuan, "w", encoding="utf-8").write(teks)
        p = subprocess.run([sys.executable, "-c", program], cwd=d,
                           capture_output=True, text=True)
        if p.returncode != 0:
            print("Aturan 39 gagal dijalankan (returncode %d), bukan berbunyi:"
                  % p.returncode)
            print((p.stderr or p.stdout)[-2000:])
            sys.exit(1)
        return p.stdout, p.stderr
    finally:
        shutil.rmtree(d)


def main():
    program = program_aturan39()
    gagal = []

    def periksa(label, seharusnya_berbunyi, mutasi=None):
        out, _ = jalankan(program, mutasi)
        berbunyi = bool(out.strip())
        tanda = "OK   " if berbunyi == seharusnya_berbunyi else "GAGAL"
        if berbunyi == seharusnya_berbunyi:
            print("%s %-46s %s" % (tanda, label,
                                   "berbunyi" if berbunyi else "diam"))
        else:
            print("%s %-46s seharusnya %s, ternyata %s"
                  % (tanda, label,
                     "berbunyi" if seharusnya_berbunyi else "diam",
                     "berbunyi" if berbunyi else "diam"))
            if not berbunyi and seharusnya_berbunyi:
                print("     -> aturan ini tidak menangkap bentuk yang pernah "
                      "gagal di CI macOS.")
            if berbunyi:
                print("     -> " + out.strip().splitlines()[0][:200])
            gagal.append(label)
        return out

    # 0. Penjaga kevakuman: program harus MELIHAT `CelestialVisual` sama sekali.
    #    Indeks kosong pernah dilaporkan sebagai "Bersih" -- keadaan itulah yang
    #    paling berbahaya, jadi ia diperiksa eksplisit.
    out, _ = jalankan(program + '\nprint("PROBE", '
                      '"spokenStarClassLine" in statis.get("CelestialVisual", set()),'
                      ' len(statis.get("CelestialVisual", set())),'
                      ' "phaseGeometry" in instance.get("CelestialVisual", set()))')
    probe = [b for b in out.splitlines() if b.startswith("PROBE")]
    bidang = probe[0].split()[1:] if probe else []
    if len(bidang) != 3 or bidang[0] != "True" or bidang[2] != "True":
        print("GAGAL indeks anggota tidak memuat anggota CelestialVisual")
        print("     -> " + (probe[0] if probe else "probe tidak tercetak"))
        gagal.append("indeks")
    else:
        print("%s %-46s %s anggota statis, phaseGeometry instance" % ("OK   ", "indeks anggota terbaca", bidang[1]))

    periksa("galat yang persis memerahkan CI", True,
            (SRC, "let starClass = CelestialVisual.spokenStarClassLine(",
             "let starClass = visual.spokenStarClassLine("))

    # Jangkar ini **bukan** baris produksi yang dijaga Aturan 39; ia hanya
    # titik sisip untuk membentuk receiver `CelestialVisual?` beranotasi.
    # Barisnya ikut berubah siklus ini ketika `objectDisplayName` dipecah
    # menjadi deklarasi multi-baris (perbaikan Aturan 41), dan harness
    # **harus** mengikuti -- kalau tidak, `assert` di bawah gagal dan CI
    # merah karena sebab yang bukan cacat yang dicari.
    anchor = "    private var objectDisplayName: String {"
    periksa("receiver beranotasi + optional chaining", True,
            (SRC, anchor,
             anchor + "\n    private func p() { let v: CelestialVisual? = visual;"
                      " _ = v?.spectralClass(forStarID: \"x\") }"))

    # KONTROL. `CelestialVisual` punya `phaseGeometry(waxing:)` sebagai metode
    # instance DAN `phaseGeometry(fraction:waxing:)` statis; `visual.` adalah
    # bentuk yang benar. Aturan yang menuduh baris ini akan dimatikan orang.
    kontrol = "if isConfirmed, let phase = visual.phaseGeometry(waxing: visual.isWaxing) {"
    periksa("kontrol sah: instance phaseGeometry", False,
            (VIEW, kontrol, kontrol + " /* probe */"))

    out = periksa("baseline berkas apa adanya", False)

    if gagal:
        print("\nHARNESS ATURAN 39 GAGAL: " + ", ".join(gagal))
        sys.exit(1)
    print("\nAturan 39 berbunyi pada bentuk yang gagal di CI, dan diam pada kode sah.")


if __name__ == "__main__":
    main()
