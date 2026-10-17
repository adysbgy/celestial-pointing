#!/usr/bin/env python3
"""Buktikan Aturan 40 berbunyi pada gambar yang **tidak menyebut** fasenya.

Kenapa harness ini ada, padahal sudah ada `bukti-mutasi-gerbang-denyut.py`.

Harness itu membuktikan Aturan 21 berbunyi pada denyut yang **isi** argumennya
salah: dinegasikan, cabangnya terbalik, `hasPulse` di argumen lain. Ia tidak
dan tidak bisa membuktikan apa pun tentang pemanggil yang **tidak menulis**
`pulse:` — justru di situlah cacat yang menutup siklus #273 hidup:

    CelestialVisualView(visual: CelestialVisual(kind: .star, …),
                        diameter: 64,
                        isConfirmed: true)      <- nilai baku 0, diam

Ilustrasi onboarding adalah bintang, dan `CelestialVisual.hasPulse` menyatakan
bintang satu-satunya jenis yang berdenyut. Hasilnya: layar pertama yang dilihat
pengguna adalah satu-satunya tempat glow bintang diam, dan **nol** gerbang
berbunyi — Aturan 21 melewati `pulse:` yang tidak ada.

Yang dibuktikan harness ini, dan arahnya:

  [baseline]   pohon apa adanya                                  hijau
  1. sunting   `pulse: MotionPolicy.staticPulsePhase)` dihapus    MERAH
               (bentuk cacat yang persis terjadi di onboarding)
  2. sunting   `pulse: 0)` dihapus dari kartu jam                 MERAH
               (kelalaian yang sama di berkas lain — kelasnya,
               bukan satu situs)
  3. injeksi   view baru tanpa `pulse:` di berkas baru            MERAH
               (baris yang ditulis **besok**)
  4. injeksi   kontrol negatif: gambar statis yang **menyebut**   hijau
               `pulse: MotionPolicy.staticPulsePhase`
  5. injeksi   kontrol negatif: bintang dengan gerbang penuh      hijau
  6. injeksi   `pulse:` di dalam kurung bersarang pemanggilan     MERAH
               lain tidak boleh dihitung sebagai miliknya
  7. non-vak.  badan Aturan 40 dilumpuhkan — **wajib** hijau di
               keadaan 1, kalau tidak yang berbunyi adalah aturan lain

Keadaan 7 adalah yang membuat sisa berkas ini berarti. Tanpa itu, "merah"
bisa berarti "merah karena aturan lain di salinan tak lengkap", dan harness
yang lulus akan melaporkan keberhasilan yang tidak pernah diukur.

Yang TIDAK diklaim.

  - Yang dibaca Aturan 40 adalah **teks** pemanggilan `CelestialVisualView(`.
    Gambar yang dihasilkan fungsi pembangun di berkas lain (mis.
    `gambarBintang()` di berkas ketiga) tidak terbaca, karena tidak
    mengandung token itu. Bentuk itu tidak ada hari ini.
  - Ia tidak tahu apakah `pulse:`-nya bermakna. Nilai bukan-nol yang salah
    tetap Aturan 21 yang punya urusan.
  - Tampilan di perangkat tetap tidak diperiksa: tidak ada Xcode di VPS.

Berkas ini tidak memutasi sumber produksi: setiap keadaan disuntik ke salinan
pohon bersih sendiri (`.git` dan `.build` dikecualikan), lalu `swift-ui-lint.sh`
**di dalam salinan itu** dijalankan. Skrip aslinya `cd "$(dirname "$0")"`, jadi
menjalankan yang di repo dengan `cwd=workdir` tetap akan memeriksa repo.

Pakai:
    python3 Tools/bukti-mutasi-fase-gambar.py        # 0 = semua sesuai harapan
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

sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penjaga sumber bersih, sama dengan harness lain)

WATCHED = [LINT, os.path.join(ROOT, "Apps")]

RULE = "40"

# Situs yang **hari ini** menyebut fasenya diam-diam. Jangkar dibaca dari berkas
# saat jalan; kegagalannya dicetak sebagai LEWAT, bukan dilaporkan lulus —
# `check-jangkar-harness.py` menutup kelas "mutasi tertinggal di jangkar".
ONBOARDING = "Apps/Shared/OnboardingView.swift"
ONBOARDING_ANCHOR = "                                pulse: MotionPolicy.staticPulsePhase)"
WATCH_CARD = "Apps/PointAndKnowWatch/Sources/PointingView.swift"
WATCH_CARD_ANCHOR = "                                    pulse: MotionPolicy.staticPulsePhase)"

INJECT_INTO = "Apps/Shared/OnboardingView.swift"

failures: list[str] = []


def copy_repo() -> str:
    """Salin seluruh pohon yang dibaca gerbang sapu, kecuali `.git`/`.build`.

    Kenapa utuh, bukan hanya `Apps/`: aturan lain membaca `Packages/`,
    `project.yml`, dan `Tools/`; salinan parsial membuat semuanya berbunyi dan
    menenggelamkan tanda yang dicari.
    """
    workdir = tempfile.mkdtemp(prefix="fase-gambar-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build '
         '--exclude="*/cangkang-tmp" -cf - . | (cd "$2" && tar -xf -)',
         "copy", ROOT, workdir],
        check=True)
    return workdir


def run_lint(workdir: str) -> tuple[int, str]:
    lint = os.path.join(workdir, "swift-ui-lint.sh")
    os.chmod(lint, 0o755)
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run(["bash", lint], cwd=workdir,
                       capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def finding(out: str, rule: str) -> str | None:
    """Ambil badan temuan Aturan `rule`, atau None kalau ia bersih.

    Setiap aturan selalu mencetak `== Aturan N: …` entah ia menemukan sesuatu
    atau tidak, jadi mencocokkan judulnya membuat setiap keadaan tampak
    "berbunyi". Yang diambil adalah badan **sesudah** judul, sampai judul
    berikutnya.
    """
    marks = list(re.finditer(r"^== Aturan \d+:.*$", out, re.M))
    header = re.compile(rf"^== Aturan {rule}:.*$", re.M)
    for i, m in enumerate(marks):
        if not header.match(m.group(0)):
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(out)
        body = out[m.end():end].strip()
        if not body or body.startswith("Bersih"):
            return None
        return body
    return None


def expect(nama: str, fired: bool, diharapkan: bool) -> None:
    if fired == diharapkan:
        print(f"  OK   {nama}")
        return
    kata = "merah" if diharapkan else "hijau"
    nyata = "merah" if fired else "hijau"
    failures.append(f"  Aturan {RULE} / {nama}: {nyata} padahal diharapkan {kata}")


def keadaan_hapus(nama: str, target: str, jangkar: str, diharapkan: bool) -> None:
    """Hapus satu baris `pulse:` dari salinan bersih, lalu jalankan aturannya."""
    wd = copy_repo()
    try:
        path = os.path.join(wd, target)
        src = open(path, encoding="utf-8").read()
        if src.count(jangkar) != 1:
            failures.append(f"  Aturan {RULE} / {nama}: jangkar muncul "
                            f"{src.count(jangkar)}× di {target}, harus tepat 1 "
                            "— harness perlu disesuaikan, bukan aturannya")
            return
        open(path, "w", encoding="utf-8").write(src.replace(jangkar, "", 1))
        _, out = run_lint(wd)
        expect(nama, finding(out, RULE) is not None, diharapkan)
    finally:
        shutil.rmtree(wd, ignore_errors=True)


def keadaan_injeksi(nama: str, argumen: str, diharapkan: bool) -> None:
    """Suntik satu pemanggilan baru ke `INJECT_INTO`, lalu jalankan aturannya.

    Kenapa injeksi, bukan hanya suntingan: keadaan 1–2 membuktikan aturan
    berbunyi pada situs yang **hari ini** ada. Yang tidak dibuktikannya adalah
    baris yang ditulis besok di berkas lain — dan kelas cacat "aturan UI
    kembali muncul di berkas yang ditambahkan belakangan" sudah beberapa kali
    menutup siklus di repo ini.
    """
    wd = copy_repo()
    try:
        path = os.path.join(wd, INJECT_INTO)
        src = open(path, encoding="utf-8").read()
        view = ("\nstruct ZzzProbeFaseGambar: View {\n"
                "    var body: some View {\n        "
                f"CelestialVisualView({argumen})\n"
                "    }\n}\n")
        open(path, "w", encoding="utf-8").write(
            src.replace("import SwiftUI", "import SwiftUI" + view, 1))
        _, out = run_lint(wd)
        expect(nama, finding(out, RULE) is not None, diharapkan)
    finally:
        shutil.rmtree(wd, ignore_errors=True)


def keadaan_nonvakuositas() -> None:
    """Lumpuhkan badan Aturan 40; keadaan 1 wajib berbalik hijau.

    Yang dipangkas adalah cabang `elif [ -n "$fase_hilang" ]` milik Aturan 40
    saja — dicari lewat teksnya yang unik, bukan lewat nomor baris, dan
    kegagalan menemukannya adalah LEWAT, bukan lulus.
    """
    wd = copy_repo()
    try:
        path = os.path.join(wd, TARGET_ANCHOR_FILE)
        src = open(path, encoding="utf-8").read()
        if src.count(ONBOARDING_ANCHOR) != 1:
            failures.append("  non-vakuositas: jangkar onboarding hilang")
            return
        src = src.replace(ONBOARDING_ANCHOR, "", 1)
        cabang = 'elif [ -n "$fase_hilang" ]; then'
        if src.count(cabang) != 1:
            failures.append(f"  non-vakuositas: cabang {cabang!r} muncul "
                            f"{src.count(cabang)}×, harus tepat 1")
            return
        # Cabang dilumpuhkan dengan syarat yang tidak pernah benar. Badan
        # programnya tetap utuh, jadi yang hilang hanyalah *pelaporannya*.
        src = src.replace(cabang, 'elif false; then', 1)
        open(path, "w", encoding="utf-8").write(src)
        _, out = run_lint(wd)
        # Aturan lain boleh berbunyi; yang harus hilang adalah Aturan 40.
        expect("non-vakuositas: badan dilumpuhkan (harus hijau)",
               finding(out, RULE) is not None, False)
    finally:
        shutil.rmtree(wd, ignore_errors=True)


TARGET_ANCHOR_FILE = "swift-ui-lint.sh"


def cek() -> None:
    # Pra-syarat jangkar. Kalau ini tidak ada, seluruh harness di bawah
    # mengukur keadaan yang tidak pernah disuntik — dan melaporkan hijau atas
    # ketiadaan.
    for target, jangkar in ((ONBOARDING, ONBOARDING_ANCHOR),
                            (WATCH_CARD, WATCH_CARD_ANCHOR)):
        src = open(os.path.join(ROOT, target), encoding="utf-8").read()
        if src.count(jangkar) != 1:
            print(f"LEWAT: jangkar {jangkar!r} muncul {src.count(jangkar)}× "
                  f"di {target}, harus tepat 1 — harness perlu disesuaikan")
            sys.exit(1)
    print(f"  jangkar: onboarding & kartu jam, masing-masing tepat 1")

    # ── Keadaan 0: pohon apa adanya -> diam ─────────────────────────────
    # Paling penting: aturan yang merah pada kode benar akan dimatikan orang,
    # dan aturan yang dimatikan tidak menjaga apa pun.
    wd = copy_repo()
    try:
        rc, out = run_lint(wd)
        expect("kode benar (harus diam)", finding(out, RULE) is not None, False)
    finally:
        shutil.rmtree(wd, ignore_errors=True)

    # ── Keadaan 1: bentuk cacat aslinya — `pulse:` hilang dari onboarding ──
    keadaan_hapus("onboarding tanpa `pulse:` (harus merah)",
                  ONBOARDING, ONBOARDING_ANCHOR, True)

    # ── Keadaan 2: kelalaian yang sama di berkas lain ───────────────────
    # Kalau hanya keadaan 1 yang diuji, aturan ini bisa jadi aturan yang
    # menambat satu berkas — kelas cacat yang sudah beberapa kali lolos.
    keadaan_hapus("kartu jam tanpa `pulse:` (harus merah)",
                  WATCH_CARD, WATCH_CARD_ANCHOR, True)

    # ── Keadaan 3: baris yang ditulis besok ─────────────────────────────
    keadaan_injeksi("view baru tanpa `pulse:` (harus merah)",
                    "visual: CelestialVisual(kind: .star), diameter: 40",
                    True)

    # ── Keadaan 4: kontrol negatif — gambar statis yang menyebut fasenya ──
    keadaan_injeksi("gambar statis yang menyebut fase (harus diam)",
                    "visual: CelestialVisual(kind: .moon), diameter: 40, "
                    "pulse: MotionPolicy.staticPulsePhase", False)

    # ── Keadaan 5: kontrol negatif — bintang dengan gerbang penuh ───────
    keadaan_injeksi("bintang bergerbang hasPulse (harus diam)",
                    "visual: CelestialVisual(kind: .star), diameter: 40, "
                    "pulse: CelestialVisual(kind: .star).hasPulse ? 1.2 : 0",
                    False)

    # ── Keadaan 6: `pulse:` milik pemanggilan BERSARANG ─────────────────
    # `CelestialVisualView(visual: f(pulse: 1))` tidak menyebut fasenya
    # sendiri. Pemisah argumen tingkat atas yang menangkap ini; pencarian
    # `re.search(r"pulse:")` atas seluruh daftar argumen tidak.
    keadaan_injeksi("`pulse:` hanya di kurung bersarang (harus merah)",
                    "visual: CelestialVisual(kind: .star), diameter: 40, "
                    "isConfirmed: true).id(Foo(pulse: 1))",
                    True)

    # ── Keadaan 7: pengukuran non-vakuositas ────────────────────────────
    keadaan_nonvakuositas()


def main() -> int:
    mutasi_sumber.require_clean_sources(WATCHED)
    print("== Buktikan Aturan 40 berbunyi pada gambar tanpa fase ==")
    cek()
    if failures:
        print("\nGERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        for f in failures:
            print(f)
        return 1
    print("\nBersih: Aturan 40 berbunyi pada tiga bentuk kelalaian, diam pada "
          "dua bentuk yang sah, membedakan `pulse:` bersarang, dan lumpuh "
          "saat badannya dilumpuhkan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
