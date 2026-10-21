#!/usr/bin/env python3
"""Buktikan Aturan 80 (samaran ragu TERPASANG) **berbunyi**.

Kenapa harness ini ada.

Aturan 63 sudah menjaga **angka** samaran: `diameter * 0.06` di Swift sama
dengan `VIEW_UNCERTAIN_BLUR_FRACTION` di port Python, dan opasitasnya 0.75.
Yang tidak dijaga siapa pun adalah apakah angka itu **dipasang**. Terukur pada
pohon utuh, proses baru, seluruh 79 aturan hijau:

    CelestialVisualView.swift  .opacity(isConfirmed || ... ? 1 : 0.75)
                               -> .opacity(1)                        exit 0
    CelestialVisualView.swift  .blur(radius: ... 0 : radius)
                               -> .blur(radius: 0)                   exit 0
    CelestialVisualView.swift  drawSun radius: radius / sunCoronaReach
                               -> radius: radius                     exit 0
    CelestialVisualView.swift  let reach = sunCoronaReach * radius
                               -> let reach = radius                 exit 0

Akibatnya kandidat yang engine **belum kunci** digambar tajam dan penuh —
cincin Saturnus, pita Jupiter, warna spektral bintang — tepat di samping
lencana "Ragu". Seluruh aturan tetap hijau, karena semuanya memeriksa
**cabang** yang memutuskan menyamar (Aturan 50/51/60) atau **angka**nya
(Aturan 63), bukan pemasangannya. Itu persis kelas "gerbang mengukur salinan,
bukan yang dipakai" yang sudah berulang di repo ini.

Keadaan yang diuji.

  1  `.opacity` samaran diganti 1            -> MERAH (keyakinan palsu)
  2  `.blur` samaran diganti 0               -> MERAH (keyakinan palsu)
  3  piringan Matahari selebar frame         -> MERAH (corona terpotong)
  4  `let reach` tidak dari `sunCoronaReach` -> MERAH (halo hilang)
  5  KONTROL: pohon apa adanya               -> diam
  6  KONTROL: `.opacity` di dalam kanvas (gradien) tidak dituduh -> diam
  7  fail-closed: rantai samaran dihapus     -> MERAH, bukan "Bersih"

Keadaan 6 penting: berkas ini punya puluhan `.opacity(` di dalam gradient
planet dan bintang. Aturan yang menyapu seluruh berkas akan menuduh baris sah,
dan aturan yang menuduh baris sah akan dimatikan orang.

Keadaan 7 adalah bentuk gerbang hijau paling berbahaya: rantai yang tidak
terbaca (modifier berganti nama, berkas dipindah) berarti sapuannya berhenti
bekerja, bukan berarti kodenya benar.

Harness menjalankan **program Python milik Aturan 80 apa adanya**, diambil
dari `swift-ui-lint.sh`, di dalam sandbox yang hanya berisi `Apps/` hasil
mutasi. Lint utuh tidak dipanggil: ia punya pra-syarat lain (`project.yml`,
README, Packages/) dan kegagalan pra-syarat akan terbaca palsu sebagai
"gerbang berbunyi". `returncode` di luar (0, 1) berarti **galat harness**.

Yang TIDAK dibuktikan
=====================

Aturan ini menjaga **pemasangan** samaran dan **penyusutan** corona. Ia tidak
membuktikan bahwa 6% diameter adalah kekuatan samaran yang tepat (itu wilayah
Aturan 63), dan tidak membuktikan bahwa corona 0.40 cukup terang di layar
(`check_sun_corona_reaches_beyond_the_disk` mengukur itu di piksel). Yang
dijaga di sini hanya bahwa keduanya tidak bisa dicabut tanpa ada yang tahu.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

VIEW = "Apps/Shared/CelestialVisualView.swift"

MULAI = 'samaran_terpasang=$(python3 - <<\'PY\' 2>&1\n'

# Jangkar produksi. Kalau bentuknya berubah, harness harus ikut pindah —
# dan `assert` di `jalankan` membuat perubahan itu merah karena sebab yang
# jelas, bukan diam-diam melewati keadaan.
OPACITY_ASLI = """.opacity(isConfirmed || UncertainBlur.allows(visual.kind)
                 ? 1
                 : Self.uncertainBlurOpacity)"""
OPACITY_SATU = """.opacity(1)"""

BLUR_ASLI = """.blur(radius: isConfirmed || UncertainBlur.allows(visual.kind)
              ? 0
              : Self.uncertainBlurRadius(diameter: diameter))"""
BLUR_NOL = """.blur(radius: 0)"""

SUN_ASLI = """            drawSun(context: context, center: center,
                    radius: radius / CGFloat(VisualFrame.sunCoronaReach))"""
SUN_PENUH = """            drawSun(context: context, center: center,
                    radius: radius)"""

REACH_ASLI = "        let reach = CGFloat(VisualFrame.sunCoronaReach) * radius"
REACH_PENUH = "        let reach = radius"

#: Keadaan 6: `.opacity` pertama di dalam kanvas (gradien planet), bukan di
#: rantai samaran. Aturan yang menyapu seluruh berkas akan menuduhnya.
#: Jangkar ini sengaja **di dalam** badan gambar, jauh dari rantai modifier.
KANVAS_ASLI = "                        .opacity(CelestialVisual.jupiterBandOpacity),"
KANVAS_NOL = "                        .opacity(1),"

#: Keadaan 7: rantai samaran dicabut seluruhnya. Aturan harus memerah karena
#: tidak bisa memeriksa apa pun — bukan diam dan lulus.
RANTAI_AWAL = "        .drawingGroup(opaque: false, colorMode: .linear)"
RANTAI_AKHIR = "        .accessibilityHidden(true)"


def program_aturan80():
    """Ambil program Python milik Aturan 80 dari lint, apa adanya."""
    teks = open(LINT, encoding="utf-8").read()
    i = teks.index(MULAI) + len(MULAI)
    j = teks.index("\nPY\n)", i)
    return teks[i:j]


def jalankan(program, mutasi=None):
    """Jalankan program aturan di sandbox; kembalikan (returncode, stdout)."""
    d = tempfile.mkdtemp(prefix="rule80-")
    try:
        tujuan = os.path.join(d, "Apps")
        shutil.copytree(os.path.join(ROOT, "Apps"), tujuan,
                        ignore=shutil.ignore_patterns("*.xcodeproj",
                                                      "*.xcworkspace"))
        if mutasi:
            daftar = mutasi if isinstance(mutasi, list) else [mutasi]
            for anchor, ganti in daftar:
                path = os.path.join(d, VIEW)
                teks = open(path, encoding="utf-8").read()
                jumlah = teks.count(anchor)
                assert jumlah == 1, (
                    "jangkar muncul %dx di %s, harus 1: %r"
                    % (jumlah, VIEW, anchor[:70]))
                teks = teks.replace(anchor, ganti, 1)
                open(path, "w", encoding="utf-8").write(teks)
        p = subprocess.run([sys.executable, "-c", program], cwd=d,
                           capture_output=True, text=True)
        if p.returncode not in (0, 1):
            print("Aturan 80 gagal dijalankan (returncode %d), bukan berbunyi:"
                  % p.returncode)
            print((p.stderr or p.stdout)[-2000:])
            sys.exit(1)
        # **Keputusan dari exit code, bukan dari keluaran kosong.** Program ini
        # tidak mencetak apa pun saat bersih, jadi `bool(stdout)` kebetulan
        # benar di sini — tetapi memakai exit code membuat aturan ini bisa
        # menambah baris "Bersih" nanti tanpa merusak harness.
        return p.returncode, p.stdout
    finally:
        shutil.rmtree(d)


def main():
    program = program_aturan80()
    gagal = []

    def periksa(label, harus_berbunyi, mutasi=None, wajib_sebut=None):
        code, out = jalankan(program, mutasi)
        berbunyi = code != 0
        ok = berbunyi == harus_berbunyi
        tanda = "OK   " if ok else "GAGAL"
        print("%s %-52s %s" % (tanda, label,
                               "berbunyi" if berbunyi else "diam"))
        if not ok:
            if harus_berbunyi and not berbunyi:
                print("     -> aturan ini tidak menangkap bentuk yang ada di "
                      "main sebelum ia ditulis.")
            elif berbunyi:
                print("     -> " + out.strip().splitlines()[0][:200])
            gagal.append(label)
        if ok and wajib_sebut and wajib_sebut not in out:
            print("GAGAL %s: keluaran tidak menyebut %r, jadi yang berbunyi "
                  "belum tentu pemeriksaan yang dimaksud."
                  % (label, wajib_sebut))
            gagal.append(label + " (pesan)")
        return out

    # 1-2. Samaran dicabut: kandidat digambar tajam dan penuh.
    periksa("1 opacity samaran diganti 1", True, (OPACITY_ASLI, OPACITY_SATU),
            wajib_sebut="opacity")
    periksa("2 blur samaran diganti 0", True, (BLUR_ASLI, BLUR_NOL),
            wajib_sebut="blur")

    # 3-4. Corona Matahari terpotong frame.
    periksa("3 piringan Matahari selebar frame", True, (SUN_ASLI, SUN_PENUH),
            wajib_sebut="sunCoronaReach")
    periksa("4 reach tidak dari sunCoronaReach", True,
            (REACH_ASLI, REACH_PENUH), wajib_sebut="sunCoronaReach")

    # 5. KONTROL: pohon apa adanya harus diam.
    periksa("5 kontrol: pohon apa adanya", False)

    # 6. KONTROL: `.opacity` di dalam kanvas bukan situs samaran.
    #    Ini yang menahan aturan agar tidak menyapu seluruh berkas.
    periksa("6 kontrol: opacity gradien planet tidak dituduh", False,
            (KANVAS_ASLI, KANVAS_NOL))

    # 7. Fail-closed: rantai samaran tidak terbaca -> MERAH, bukan "Bersih".
    #    Dua mutasi: tandai awal rantai dan akhirnya agar keduanya tak dikenali.
    out = periksa("7 rantai samaran tak terbaca -> memerah", True,
                  [(RANTAI_AWAL, "        .drawingGroupLama(opaque: false)"),
                   (RANTAI_AKHIR, "        .accessibilityTersembunyi(true)")],
                  wajib_sebut="tidak ditemukan")

    if gagal:
        print("\nHARNESS ATURAN 80 GAGAL: " + ", ".join(gagal))
        sys.exit(1)
    print("\nAturan 80 berbunyi pada keempat cara mencabutnya, dan diam pada "
          "gradien di dalam kanvas.")


if __name__ == "__main__":
    main()
