#!/usr/bin/env python3
"""Buktikan Aturan 7 (penjaga reduce-motion) **berbunyi** — dan pada hal yang benar.

Kenapa harness ini ada.

Aturan 7 menjaga satu-satunya janji aksesibilitas yang **bergerak**: setiap API
gerak (`withAnimation`, `.repeatForever`, `TimelineView(.animation)`,
`.animation(`) harus berada di blok yang membaca penjaga gerak. Sampai siklus
ini aturan itu tidak punya satu pun rekam jejak bahwa ia bisa keluar merah --
`red-lint.sh` di CI menyuntik `Text("x").withAnimation(...)` dan menuntut
`swift-ui-lint.sh` keluar bukan-nol, tetapi itu membuktikan **satu** bentuk
cacat di **satu** berkas. Gerbang yang hanya pernah diukur merah pada satu
bentuk adalah gerbang yang cakupannya tidak diketahui.

Cacat yang ditemukan dengan mengukur, bukan membaca.

Versi aturan ini membuang komentar sebelum menguji bloknya (`strip_comments`),
tetapi **tidak** membuang isi literal string. Akibatnya penjaga yang hanya
**disebut** di dalam string dihitung sebagai penjaga. Terukur di
`PointingView.swift`:

    var zzzMotionProbe: some View {
        _ = "MotionPolicy(reduceMotion: false)"
        withAnimation(.linear(duration: 0.3)) { }
        return EmptyView()
    }
    -> "Bersih: setiap API gerak berada di blok berpenjaga reduce-motion."

Satu baris string membuat gerak tanpa penjaga lolos — dan itu bukan bentuk
karangan: repo ini menulis `motion.allowsTransitions` di dalam kalimat yang
**dijelaskan** ke pengguna, di berkas yang sama dengan geraknya.

Docstring aturan itu juga mengklaim penjaga boleh disebut "(kode atau
komentar)". Klaim itu **salah** dan diukur di sini (keadaan 7): komentar sudah
dibuang sebelum bloknya diuji, jadi penjaga di dalam komentar tidak pernah
dihitung. Kalimatnya sudah diperbaiki; keadaan 7 yang menahannya.

Keadaan yang diuji, dan apa yang masing-masing buktikan.

  [baseline]  kode apa adanya -> hijau. Tanpa ini, harness yang selalu merah
              akan lulus seluruh keadaan di bawah.

  1  API gerak di blok tanpa penjaga -> MERAH. Ini cacat aslinya, dan
     keadaan yang menentukan apakah aturannya benar-benar menggigit.

  2  penjaga hanya **di dalam literal string** -> MERAH. Keadaan ini **hijau
     pada versi lama**, dan ia satu-satunya alasan `blank_strings` ada.

  3  penjaga yang **selalu melarang** (`MotionPolicy(reduceMotion: false)`)
     -> hijau. Gerbangnya sapu teks, bukan penilai kebenaran nilai; keadaan
     ini menyatakan batas itu sebagai **harapan yang dieksekusi**, bukan
     sebagai catatan. (Gerbang yang mencoba memutuskan nilai ini akan merah
     pada kode yang benar.)

  4, 5  penjaga yang benar (membaca `reduceMotion`; `MotionPolicy` +
     `allowsTransitions`) -> hijau. Gerbang yang merah pada kode yang benar
     akan dilonggarkan orang, dan gerbang yang dilonggarkan tidak menjaga
     apa pun.

  6  penjaga di blok **pembungkus** -> hijau. Bentuk yang sah.

  7  penjaga hanya di **komentar** -> MERAH. Ini yang membuktikan kalimat
     "(kode atau komentar)" salah.

  8  penjaga di blok **saudara yang lebih dalam** -> hijau. **Batas yang
     dinyatakan**, bukan kelalaian: yang diuji adalah blok terdekat yang
     memuat API-nya, bukan blok yang mengeksekusinya. Penjaga di `if`
     bersaudara masih lolos, dan menutupnya menuntut pelacakan alur yang
     tidak bisa dibuktikan benar oleh sapu teks.

Non-vakuositasnya diukur, bukan diklaim.

Keadaan 2 harus hijau kalau `blank_strings` dilepas dari program aturannya.
Harness ini **melakukannya**: potongan aturan yang diekstrak dijalankan sekali
lagi dengan `blank_strings(src[…])` dikembalikan ke `src[…]`, dan keadaan 2
wajib berbalik jadi hijau. Kalau tidak, yang menutup keadaan 2 bukan
perbaikannya, dan seluruh keadaan di bawahnya mengukur hal lain. Kalau
penulisan itu tidak ditemukan di potongannya, harness **berhenti** (exit 2)
alih-alih melaporkan hijau atas pengukuran yang tidak terjadi.

Batas yang TIDAK diklaim.

- Yang diukur **teks** `Apps/`, bukan perilaku app Apple. Yang dibuktikan:
  aturan berbunyi pada API gerak yang tidak berpenjaga di kode, dan diam pada
  bentuk-bentuk sah yang dinyatakan di atas.
- Ia tidak membuktikan penjaganya benar secara **nilai** (keadaan 3) maupun
  bahwa `MotionPolicy` di Linux mengembalikan nilai yang benar untuk
  preferensi pengguna — itu wilayah `PointingKit` dan sudah diuji di sana.
- Keadaan 8 adalah batas yang **dinyatakan dan dieksekusi**: kalau kelak
  cakupannya diperketat sampai menjangkau saudaranya, keadaan itu mulai tidak
  sesuai harapan, dan itu tanda cakupannya meluas, bukan harnessnya rusak.
"""

from __future__ import annotations

import os
import shutil
import signal
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penjaga sumber bersih, sama dengan harness lain)

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
VIEW = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources", "PointingView.swift")

#: Batas potongan program Aturan 7 di dalam `swift-ui-lint.sh`.
BEGIN = "# ── Aturan 7:"
END = "# ── Aturan 8:"

#: Tanda yang harus ada di dalam potongan. Kalau salah satu hilang, yang
#: diekstrak bukan aturan yang CI jalankan dan harness berhenti.
REQUIRED = ("== Aturan 7:",
            "Bersih: setiap API gerak berada di blok berpenjaga reduce-motion.",
            "status=1",
            "blank_strings")

#: Jangkar tunggal di view. Dihitung, bukan disangka: jangkar yang muncul lebih
#: dari sekali menyunting lebih banyak daripada yang dilaporkan.
ANCHOR = ("    @ScaledMetric(relativeTo: .headline) private var statusIconSize:"
          " CGFloat = 16\n\n    var body: some View {")

PROBE_OPEN = ("    @ScaledMetric(relativeTo: .headline) private var statusIconSize:"
              " CGFloat = 16\n\n    var zzzMotionProbe: some View {\n")
PROBE_CLOSE = "    }\n\n    var body: some View {"

#: Nama berkas relatif, seperti yang dicetak aturan di baris temuannya.
REL_VIEW = os.path.relpath(VIEW, ROOT)

#: (label, isi badan blok probe, harus_merah). `None` = tanpa suntikan.
STATES = [
    ("[baseline] kode apa adanya", None, False),
    ("1. API gerak di blok tanpa penjaga",
     "        withAnimation(.linear(duration: 0.3)) { }\n"
     "        return EmptyView()\n", True),
    ("2. penjaga hanya di dalam literal string",
     '        _ = "MotionPolicy(reduceMotion: false)"\n'
     "        withAnimation(.linear(duration: 0.3)) { }\n"
     "        return EmptyView()\n", True),
    ("3. penjaga yang selalu melarang (batas dinyatakan)",
     "        _ = MotionPolicy(reduceMotion: false, isLuminanceReduced: false,"
     " lowPower: false)\n"
     "        withAnimation(.linear(duration: 0.3)) { }\n"
     "        return EmptyView()\n", False),
    ("4. penjaga benar: membaca `reduceMotion`",
     "        if reduceMotion { }\n"
     "        withAnimation(.linear(duration: 0.3)) { }\n"
     "        return EmptyView()\n", False),
    ("5. penjaga benar: `MotionPolicy` + `allowsTransitions`",
     "        _ = MotionPolicy(reduceMotion: reduceMotion,"
     " isLuminanceReduced: false, lowPower: false).allowsTransitions\n"
     "        withAnimation(.linear(duration: 0.3)) { }\n"
     "        return EmptyView()\n", False),
    ("6. penjaga di blok pembungkus",
     "        if reduceMotion {\n"
     "            withAnimation(.linear(duration: 0.3)) { }\n"
     "        }\n"
     "        return EmptyView()\n", False),
    ("7. penjaga hanya di komentar (klaim lama: \"kode atau komentar\")",
     "        // reduceMotion\n"
     "        withAnimation(.linear(duration: 0.3)) { }\n"
     "        return EmptyView()\n", True),
    ("8. penjaga di blok saudara yang lebih dalam (batas dinyatakan)",
     "        if true { _ = MotionPolicy.self }\n"
     "        withAnimation(.linear(duration: 0.3)) { }\n"
     "        return EmptyView()\n", False),
]

#: Penulisan yang harus dibalik untuk mengukur non-vakuositas. Kalau ini tidak
#: ditemukan, harness berhenti — bukan melaporkan hijau.
HARDENING = "blank_strings(src[open_at:close_at + 1])"
UNHARDENED = "src[open_at:close_at + 1]"


def extract_rule() -> str | None:
    """Ambil potongan program Aturan 7 dari `swift-ui-lint.sh`, atau `None`."""
    text = open(LINT, encoding="utf-8").read()
    start = text.find(BEGIN)
    end = text.find(END)
    if start < 0 or end <= start:
        return None
    return text[start:end]


def fresh_tree() -> str:
    """Salin pohon yang dibaca aturan, kecuali `.git`/`.build`/`out`.

    Kenapa salinan, bukan berkas produksi langsung: aturannya menyapu seluruh
    `Apps/`, jadi menyunting berkas produksi akan membuat setiap keadaan
    berjalan di atas sisa keadaan sebelumnya bila pemulihan gagal. Menyalin
    membuat pemulihan tidak bisa gagal — kelas cacat yang sudah pernah
    membayar repo ini di harness lain.
    """
    workdir = tempfile.mkdtemp(prefix="gerbang-gerak-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build --exclude=out -cf - . '
         '| (cd "$2" && tar -xf -)', "copy", ROOT, workdir],
        check=True)
    return workdir


def run_rule(program: str, workdir: str) -> tuple[int, str]:
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run(["bash", "-c", program], cwd=workdir,
                       capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def fired(out: str) -> bool:
    """Aturan berbunyi? Judulnya sendiri **bukan** bukti."""
    return ("Bersih: setiap API gerak berada di blok berpenjaga reduce-motion."
            not in out)


def main() -> int:
    # Berkas produksi yang dibaca harus byte-identik dengan HEAD — tetapi
    # **hanya view-nya**, bukan `swift-ui-lint.sh`.
    #
    # Kenapa view-nya: harness ini menyuntik ke **salinan**, jadi tidak ada
    # pemulihan yang bisa gagal; yang dijaga `require_clean_sources` di sini
    # adalah bahwa salinan itu diambil dari kode yang bukan milik commit ini.
    #
    # Kenapa **bukan** `swift-ui-lint.sh`: yang diukur harness ini justru
    # aturannya sendiri, apa adanya. Menuntut skripnya bersih akan membuat
    # harness ini tidak bisa dijalankan pada perubahan yang menambahnya —
    # dan, lebih buruk, akan mengukurnya dari salinan commit lama alih-alih
    # dari aturan yang CI jalankan. Yang menjaga potongan itu benar bukan
    # `git status`, melainkan `REQUIRED` dan hitungan `HARDENING` di bawah:
    # kalau potongan yang diekstrak bukan aturan yang dimaksud, harness
    # berhenti alih-alih melaporkan hijau.
    mutasi_sumber.require_clean_sources([VIEW])

    program = extract_rule()
    if program is None:
        print(f"GERBANG: potongan Aturan 7 tidak ditemukan di swift-ui-lint.sh "
              f"(antara {BEGIN!r} dan {END!r}) — harness tidak boleh jalan.",
              file=sys.stderr)
        return 2
    missing = [mark for mark in REQUIRED if mark not in program]
    if missing:
        print("GERBANG: potongan Aturan 7 tidak memuat "
              + ", ".join(repr(m) for m in missing)
              + " — yang diekstrak bukan aturan yang CI jalankan, jadi harness "
                "ini tidak mengukur apa pun.", file=sys.stderr)
        return 2
    if program.count(HARDENING) != 1:
        print(f"GERBANG: penulisan {HARDENING!r} muncul "
              f"{program.count(HARDENING)}x di potongan Aturan 7, harus 1x — "
              "pengukuran non-vakuositas tidak bisa dijalankan, jadi harness "
              "ini tidak boleh melaporkan hijau.", file=sys.stderr)
        return 2

    original = open(VIEW, encoding="utf-8").read()
    if original.count(ANCHOR) != 1:
        print(f"GERBANG: jangkar di PointingView.swift muncul "
              f"{original.count(ANCHOR)}x, harus 1x — harness tidak boleh jalan.",
              file=sys.stderr)
        return 2

    signal.signal(signal.SIGINT, lambda *a: sys.exit(130))
    signal.signal(signal.SIGTERM, lambda *a: sys.exit(143))

    unexpected = 0
    for label, body, must_fire in STATES:
        workdir = fresh_tree()
        try:
            if body is not None:
                target = os.path.join(workdir, REL_VIEW)
                open(target, "w", encoding="utf-8").write(
                    original.replace(ANCHOR, PROBE_OPEN + body + PROBE_CLOSE, 1))
            rc, out = run_rule(program, workdir)
            if rc not in (0, 1):
                print(f"{label:62s} PROBE GAGAL JALAN (exit {rc})")
                print(out.strip()[-400:])
                unexpected += 1
                continue
            got = fired(out)
            # Yang dituntut bukan sekadar «merah»: temuan harus **menyebut
            # berkas yang disuntik**. Salinan yang tidak lengkap membuat
            # aturan lain berbunyi, dan keadaan itu tidak membuktikan apa pun.
            names_view = REL_VIEW in out
            ok = (got == must_fire) and (not got or names_view)
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:62s} "
                  f"{'MERAH' if got else 'hijau'}")
            if got and not names_view:
                print("       (merah, tetapi tidak menyebut berkas yang disuntik)")
            if got and ok:
                for line in out.splitlines():
                    if REL_VIEW in line:
                        print(f"       {line.strip()[:140]}")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # ── Non-vakuositas: keadaan 2 harus berbalik hijau tanpa perbaikannya ──
    old_program = program.replace(HARDENING, UNHARDENED)
    label = "2. penjaga hanya di literal string — TANPA blank_strings"
    workdir = fresh_tree()
    try:
        body = STATES[2][1]
        target = os.path.join(workdir, REL_VIEW)
        open(target, "w", encoding="utf-8").write(
            original.replace(ANCHOR, PROBE_OPEN + body + PROBE_CLOSE, 1))
        rc, out = run_rule(old_program, workdir)
        if rc not in (0, 1):
            print(f"{label:62s} PROBE GAGAL JALAN (exit {rc})")
            unexpected += 1
        else:
            got = fired(out)
            ok = (got is False)          # versi lama WAJIB hijau di sini
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:62s} "
                  f"{'MERAH' if got else 'hijau'}")
            if ok:
                print("       -> versi tanpa blank_strings memang meloloskannya;")
                print("          jadi keadaan 2 diukur oleh perbaikannya, "
                      "bukan oleh hal lain.")
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(STATES)} keadaan + 1 pengukuran non-vakuositas, "
          "0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
