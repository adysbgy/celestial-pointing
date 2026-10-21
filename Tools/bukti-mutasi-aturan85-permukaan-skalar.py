#!/usr/bin/env python3
"""Buktikan Aturan 85 (permukaan skalar meneruskan faktanya) **berbunyi**.

Kenapa harness ini ada.

Aturan 85 lahir dari pengukuran, bukan dari bacaan. Sebelum ia ada, mutasi
berikut dijalankan pada salinan pohon utuh di proses baru:

    Apps/PointAndKnowiOS/Sources/ExperimentRecorder.swift:181
        verdict: String { harness.verdict }
      -> verdict: String { ExperimentText.summaryPassed(trialCount: ..., accuracy: "100%", ...) }

Hasil: `swift-ui-lint.sh` **exit 0**, "SEMUA GERBANG UI LULUS", 84 aturan
hijau. Artinya layar Experiment 1 bisa mencetak "Lulus, akurasi 100%" tanpa
membaca satu pun percobaan — dan tidak satu gerbang pun berbunyi. Seluruh mesin
kejujuran di bawahnya tetap benar dan tetap teruji; yang hilang adalah kaitannya
ke layar.

Keadaan yang diuji, dan apa yang masing-masing buktikan.

  [baseline]  pohon apa adanya -> diam. Tanpa ini, harness yang selalu berbunyi
              akan lulus seluruh keadaan di bawah.

  1  `verdict` diganti kalimat "Lulus" yang dikarang -> BERBUNYI. Ini cacat
     aslinya, bentuk yang persis lolos 84 aturan di `main`.

  2  `recordedCount` diganti `summary.trialCount` -> BERBUNYI. Mutasi ini
     mengompilasi, masuk akal dibaca sekilas (keduanya "jumlah percobaan"),
     dan justru itulah cacat yang komentar di berkas itu jelaskan panjang
     lebar: layar melaporkan lebih sedikit percobaan daripada yang ditekan
     pengguna, dan selisihnya tidak pernah dijelaskan.

  3  `unanalyzableCount` diganti literal `0` -> BERBUNYI. Nol berarti "semua
     percobaan bisa dinilai", jadi peringatan "tidak menambah bukti" hilang
     dan pengguna mengira tinggal menambah percobaan saja.

  4  KONTROL: `pulsePhase` (Double) yang sah, masih menyebut
     `motion.pulsePhase(...)` meski hasilnya dikalikan `1.0` -> tetap diam.
     Ini **batas yang dinyatakan**, bukan kelalaian: aturan memeriksa bentuk
     badan (apakah sumbernya disebut), bukan nilainya. `* 1.0` adalah cacat
     yang tidak bisa dibedakan dari kode benar tanpa menjalankan Swift.

  5  KONTROL: `var fallback: AnyView { ... }` di complication, yang badannya
     tidak menyebut `fallback` -> tetap diam. Tipe non-skalar adalah hiasan
     atau pembungkus tampilan, bukan fakta pengukuran; menuntutnya akan
     menuduh kode yang benar.

  6  KONTROL: `Bool` yang badannya literal (`var x: Bool { false }`) -> tetap
     diam di sini, karena ia milik Aturan 38. Batas itu dinyatakan di
     docstring aturannya, dan kontrol ini yang menahannya agar tidak diam-diam
     melebar.

  7  fail-closed: `Apps/` kosong -> BERBUNYI dengan FAIL, bukan "Bersih".
     Indeks kosong yang dilaporkan bersih adalah bentuk gerbang hijau paling
     berbahaya.

Harness menjalankan **program Python milik Aturan 85 apa adanya**, diambil dari
`Tools/check-aturan85-permukaan-skalar.py`, di dalam sandbox yang hanya berisi
`Apps/` hasil mutasi + `Packages/PointingKit/Sources/PointingKit` (sumber nama
anggota model). Lint utuh tidak dipanggil: ia punya pra-syarat lain
(`project.yml`, README, Packages/) dan kegagalan pra-syarat akan terbaca palsu
sebagai "gerbang berbunyi". `returncode` di luar (0, 1) berarti **galat
harness**, bukan keberhasilan.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATURAN = os.path.join(ROOT, "Tools", "check-aturan85-permukaan-skalar.py")

IOS = "Apps/PointAndKnowiOS/Sources/ExperimentRecorder.swift"
WATCH = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
COMP = "Apps/PointAndKnowWatch/Complications/ComplicationWidget.swift"


def jalankan(mutasi=None, kosongkan_apps=False):
    """Jalankan aturan di sandbox; kembalikan (returncode, stdout, stderr)."""
    d = tempfile.mkdtemp(prefix="rule85-")
    try:
        tujuan_apps = os.path.join(d, "Apps")
        if kosongkan_apps:
            os.makedirs(tujuan_apps)
        else:
            shutil.copytree(os.path.join(ROOT, "Apps"), tujuan_apps,
                            ignore=shutil.ignore_patterns("*.xcodeproj",
                                                          "*.xcworkspace"))
        # Nama anggota model dibaca dari paket; bawa apa adanya.
        shutil.copytree(os.path.join(ROOT, "Packages", "PointingKit", "Sources",
                                     "PointingKit"),
                        os.path.join(d, "Packages", "PointingKit", "Sources",
                                     "PointingKit"))
        os.makedirs(os.path.join(d, "Tools"), exist_ok=True)
        shutil.copy2(ATURAN, os.path.join(d, "Tools", "check.py"))
        if mutasi:
            daftar = mutasi if isinstance(mutasi, list) else [mutasi]
            for rel, anchor, ganti in daftar:
                path = os.path.join(d, rel)
                teks = open(path, encoding="utf-8").read()
                assert anchor in teks, "anchor tidak ditemukan di %s: %r" % (
                    rel, anchor[:70])
                teks = teks.replace(anchor, ganti, 1)
                open(path, "w", encoding="utf-8").write(teks)
        p = subprocess.run([sys.executable, os.path.join("Tools", "check.py")],
                           cwd=d, capture_output=True, text=True)
        if p.returncode not in (0, 1):
            print("Aturan 85 gagal dijalankan (returncode %d), bukan berbunyi:"
                  % p.returncode)
            print((p.stderr or p.stdout)[-2000:])
            sys.exit(1)
        return p.returncode, p.stdout, p.stderr
    finally:
        shutil.rmtree(d)


# Jangkar = baris produksi apa adanya. Kalau baris ini berubah, harness harus
# ikut — `assert` di `jalankan` membuat perubahan itu berbunyi karena sebab yang
# jelas, bukan diam-diam melewati keadaan.
VERDICT = "    public var verdict: String { harness.verdict }"
RECORDED = "    public var recordedCount: Int { recordedTrials.recordedCount }"
UNANALYZABLE = "    public var unanalyzableCount: Int { recordedTrials.unanalyzableCount }"

VERDICT_KARANGAN = (
    '    public var verdict: String { ExperimentText.summaryPassed('
    'trialCount: harness.trials.count, accuracy: "100%", median: "0", p90: "0") }')
RECORDED_SALAH = "    public var recordedCount: Int { summary.trialCount }"
UNANALYZABLE_NOL = "    public var unanalyzableCount: Int { 0 }"

# Kontrol: `Bool` yang badannya literal. Milik Aturan 38, bukan aturan ini.
KONTROL_BOOL = ("    public var hasUnanalyzableTrials: Bool "
                "{ recordedTrials.hasUnanalyzableTrials }")
KONTROL_BOOL_LITERAL = "    public var hasUnanalyzableTrials: Bool { false }"


def main():
    if not os.path.exists(ATURAN):
        print("FAIL %s tidak ada: Aturan 85 tidak mengukur apa pun."
              % os.path.relpath(ATURAN, ROOT))
        return 1

    gagal = []

    def periksa(label, seharusnya_berbunyi, mutasi=None, kosongkan_apps=False):
        code, out, _ = jalankan(mutasi, kosongkan_apps)
        berbunyi = code != 0
        if berbunyi == seharusnya_berbunyi:
            print("OK    %-54s %s" % (label,
                                      "berbunyi" if berbunyi else "diam"))
        else:
            print("GAGAL %-54s seharusnya %s, ternyata %s"
                  % (label, "berbunyi" if seharusnya_berbunyi else "diam",
                     "berbunyi" if berbunyi else "diam"))
            if not berbunyi and seharusnya_berbunyi:
                print("      -> aturan ini tidak menangkap bentuk yang ada di "
                      "main sebelum ia ditulis.")
            if berbunyi:
                print("      -> " + (out.strip().splitlines() or ["?"])[0][:200])
            gagal.append(label)

    periksa("baseline: pohon apa adanya", False)
    periksa("1 verdict dikarang 'Lulus, akurasi 100%'", True,
            (IOS, VERDICT, VERDICT_KARANGAN))
    periksa("2 recordedCount -> summary.trialCount", True,
            (IOS, RECORDED, RECORDED_SALAH))
    periksa("3 unanalyzableCount -> literal 0", True,
            (IOS, UNANALYZABLE, UNANALYZABLE_NOL))
    periksa("4 KONTROL: pulsePhase sah (Double) * 1.0", False,
            (WATCH, "        motion.pulsePhase(elapsedSeconds: "
                    "Date().timeIntervalSince(pulseStart))",
             "        motion.pulsePhase(elapsedSeconds: "
             "Date().timeIntervalSince(pulseStart)) * 1.0"))
    periksa("5 KONTROL: AnyView tanpa menyebut namanya", False,
            (COMP, "    private var fallback: AnyView {\n        switch family {",
             "    private var fallback: AnyView {\n        let unused = 0\n"
             "        switch family {"))
    periksa("6 KONTROL: Bool literal milik Aturan 38", False,
            (IOS, KONTROL_BOOL, KONTROL_BOOL_LITERAL))
    periksa("7 fail-closed: Apps/ kosong", True, None, kosongkan_apps=True)

    if gagal:
        print("\nAturan 85 TIDAK terbukti: %d keadaan tidak sesuai." % len(gagal))
        return 1
    print("\nAturan 85 terbukti berbunyi pada 4 bentuk cacat, diam pada 3 "
          "kontrol,\ndan fail-closed saat Apps/ kosong.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
