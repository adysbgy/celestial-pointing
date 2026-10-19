#!/usr/bin/env python3
"""Buktikan Aturan 8 dan Aturan 17 di `swift-ui-lint.sh` **benar-benar berbunyi**.

Kelas cacat yang ditutup: **aturan yang tidak pernah dibuktikan bisa merah.**

Repo ini sudah berkali-kali mencatat bahwa gerbang yang hijau pada pohon bersih
belum membuktikan apa pun — gerbang *baru* selalu hijau, dan yang membedakan
gerbang yang menjaga dari gerbang yang hanya *terlihat* menjaga adalah apakah
ia bisa dibuat merah **pada keadaan yang memang salah**. Audit gerbang meta
(`Tools/bukti-mutasi-gerbang-nirsaksi.py`) menutup kelas ini untuk enam gerbang
piksel di `Tools/check-visuals.py`. Sisi `swift-ui-lint.sh` belum pernah diaudit
dengan cara yang sama.

Terukur pada commit ini, dengan menyilangkan nomor aturan terhadap langkah
`name:`/`run:` di `.github/workflows/engine-tests.yml` **dan** terhadap seluruh
`Tools/bukti-mutasi-*.py`: **35 dari 37 aturan** punya keadaan cacat yang
dieksekusi dan menuntut merah. Dua sisanya — **8** dan **17** — hanya muncul
sebagai **pembatas blok** di dalam docstring harness lain:

    Tools/bukti-mutasi-gerbang-gerak.py:112   END = "# ── Aturan 8:"
    Tools/bukti-mutasi-kalimat-a11y.py:118    END = "# ── Aturan 17:"
    Tools/bukti-mutasi-singkatan-visual.py:35 Aturan 17 sudah menempuh jalur ini…

Ketiganya adalah **prosa**: dua yang pertama memotong keluaran lint pada judul
aturan itu (supaya harness lain hanya membaca seksinya), yang ketiga menyebut
Aturan 17 di kalimat penjelasan. Tidak satu pun menanam cacat lalu menuntut
Aturan 8/17 menyala. Persis bentuk yang docstring `bukti-mutasi-gerbang-nirsaksi.py`
sebut sebagai alasan harness itu ada — hanya satu lapis lebih jauh: di sana yang
diaudit adalah **fungsi gerbang**, di sini **aturan lint**.

Bukan berarti aturannya rusak: keduanya **berbunyi** saat diuji manual (lihat
tabel di bawah). Yang belum ada adalah **bukti yang dieksekusi CI**, dan itulah
yang ditutup berkas ini.

Yang diukur tiap keadaan adalah **keluaran aturannya sendiri**, bukan
keberhasilan program lain. Program aturan **diekstrak** dari `swift-ui-lint.sh`
lalu dijalankan di sandbox (`tempfile`), sama seperti
`Tools/bukti-mutasi-aturan31-kawat.py` — bukan menjalankan seluruh lint.
Alasannya sudah tercatat di repo ini: lint penuh punya pra-syarat lain
(`project.yml`, aturan 1..7) yang tidak berhubungan, dan **crash karena
pra-syarat** pernah terbaca palsu sebagai "gerbang berbunyi". Di sini
`returncode != 0` diperlakukan sebagai **galat**, bukan sebagai temuan.

Yang diuji, dan kenapa bentuk itu:

  Aturan 8 — kata asing (Jerman) yang terselip di repo berbahasa Indonesia.
    Keadaan cacat ditanam dalam **empat bentuk** yang berbeda, karena yang
    paling mudah lolos adalah yang paling tidak terlihat: baris komentar,
    kode nyata, isi **literal string**, dan nama berkas yang dipindai lewat
    daftar berkas tingkat-atas (`project.yml`) alih-alih lewat `os.walk`.
    Keadaan **hijau** menahan bahwa aturan tidak memerah pada prosa yang sah
    (kata Indonesia yang memuat potongan kata asing) — dan pada penanda
    `aturan8:abaikan-*` yang memang ada supaya aturan tidak menandai daftar
    katanya sendiri.

  Aturan 17 — kunci katalog ditulis ulang langsung di `Apps/` alih-alih lewat
    aksesor bertipe di `PointingKit`. Aksesornya yang membuat teks bisa diuji
    di Linux; menulis `.kunci` mentah di `Apps/` melewati seluruh uji itu.
    Keadaan cacat ditanam pada **dua bentuk**: `.kunci` telanjang (bentuk yang
    gerbangnya cari) dan `LocalizedText(key:id:)` yang dirakit langsung
    (bentuk yang **tidak** dicari — lihat batas di bawah). Keadaan **hijau**
    menahan bahwa pemanggilan aksesornya sendiri tetap bersih, dan bahwa
    pemanggilan kunci **di dalam paket** tidak dihitung: itu justru isi
    aksesornya, dan memerah di sana akan memerahkan kode yang benar.

Batas yang dinyatakan, bukan disangka tertutup:

  - Keadaan 17b (`LocalizedText(key:id:)`) **terukur hijau** di gerbang hari
    ini. Ia bukan cacat yang ditutup, melainkan cacat yang **diakui**: gerbang
    ini sapu teks yang mencari `.namaKunci` di daftar argumen, bukan pelacak
    aliran `LocalizedText` yang dirakit. Berkas ini menjalankannya sebagai
    keadaan berharap-hijau supaya kalau kelak cakupannya meluas, keadaan itu
    berhenti sesuai harapan — dan itu tanda kabar baik, bukan harness rusak.
    Sama seperti batas yang dijalankan (bukan diceritakan) di
    `Tools/bukti-mutasi-literal-string-param.py`.
  - Aturan 8 memindai `Apps/`, `Packages/*/Sources|Tests`, `Tools/`, dan lima
    berkas tingkat-atas. Yang dibuktikan di sini adalah aturan berbunyi pada
    kelima jalur **penemuan** itu; ia tidak membuktikan daftar `FOREIGN`
    lengkap — kata asing yang tidak ada di daftar tidak bisa ditangkap siapa
    pun, dan itu sifat daftar, bukan cacat gerbang.

Tidak ada sumber produksi yang dimutasi: seluruh mutasi hidup di salinan
sementara di dalam `tempfile`, jadi tidak ada pemulihan yang bisa gagal dan
tidak ada `mutasi_sumber.require_clean_sources` yang perlu dilanggar.

Pakai:
    python3 Tools/bukti-mutasi-aturan8-17.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

#: Pohon yang harus ada di sandbox untuk aturan-aturan ini.
#: Aturan 8 memindai seluruh pohon ini; Aturan 17 membaca `Apps/` **dan**
#: `Packages/PointingKit/` (aksesornya hidup di paket). Menyalin salah satu
#: saja membuat gerbangnya menyempit dan melaporkan "Bersih" — kelas cacat
#: yang sudah pernah terjadi di repo ini pada harness Aturan 29.
TREES = [
    "Apps",
    "Packages/PointingKit/Sources",
    os.path.join("Packages", "CelestialEngine", "Sources"),
    "Tools",
]
#: Berkas tingkat-atas yang ikut dipindai Aturan 8 lewat daftar terpisah
#: (bukan lewat `os.walk`). Salah satunya wajib ada di sandbox supaya jalur
#: penemuan itu benar-benar dieksekusi, bukan dilewati.
TOP_FILES = ["project.yml"]

#: Pembuka blok program tiap aturan di dalam `swift-ui-lint.sh`.
BLOCK_RULE8 = "foreign=$(python3 - <<'PY'"
BLOCK_RULE17 = "wrapped=$(python3 - <<'PY'"

#: Jangkar yang harus muncul **tepat sekali** supaya mutasi tidak mengena
#: berkas yang salah. Jangkar yang meleset membuat harness melaporkan keadaan
#: cacatnya hijau — bukan karena aturannya buta, melainkan karena berkasnya
#: tidak pernah berubah.
#:
#: **Penggantinya sengaja tidak memuat jangkarnya.** Versi pertama berkas ini
#: memakai bentuk "tempelkan kata asing di belakang jangkar", dan itu membuat
#: `Tools/check-jangkar-harness.py` **buta** pada keenam jangkar ini: gerbang
#: itu menyimpulkan "mutasi tertinggal" dari `jangkar hilang && pengganti ada`,
#: dan selama pengganti *memuat* jangkarnya sebagai substring, syarat pertama
#: tidak pernah terpenuhi. Substitusi nilai (bukan penempelan) juga yang
#: sebenarnya terjadi di repo ini: `2.4 -> 40.0`, `0.25 -> 0.0`. Jadi
#: bentuknya diperbaiki agar cacat kelas itu memang bisa tertangkap.
ANCHOR_8_COMMENT = "jadi garis tidak"
ANCHOR_8_CODE = "static let width: CGFloat = 0.5"
#: **Kenapa jangkar ini tidak menyebut `NightMode.isOn ?`.** Versi lamanya
#: `".textSecondary.color.opacity(NightMode.isOn ? 0.35 : 0.18)"` -- potongan
#: tiga literal yang dulu hidup di `Apps/`, dan langsung basi ketika opasitas
#: garis pindah ke model (`SurfacePalette.hairlineOpacity(for:)`). Terukur:
#: jangkar itu muncul **0 kali**, sementara `Tools/check-jangkar-harness.py`
#: mencetaknya sebagai "jangkar hilang tanpa pengganti" dan tetap keluar 0 --
#: dua keadaan di berkas ini (8c dan 17a) yang jangkar mutasinya tidak pernah
#: lagi mengena apa pun, dilaporkan sebagai pembuktian.
#:
#: Jangkar baru diambil dari baris yang **akan tetap ada**: pemanggilan aturan
#: model di berkas yang sama. Ia harus unik dan tidak boleh memuat teks
#: penggantinya (lihat catatan di atas).
ANCHOR_8_STRING = "SurfacePalette.hairlineOpacity(for: SurfacePalette.active)"
ANCHOR_8_TOP = "name: PointAndKnow"

#: Berkas sasaran tiap jangkar, relatif terhadap ROOT.
FILE_8 = os.path.join("Apps", "Shared", "SurfaceTokens.swift")

#: Keadaan: (nama, [(berkas, cari, ganti)], harus_berbunyi).
#:
#: Bentuk ini sengaja **bukan** yang paling nyaman: ia yang dibaca
#: `Tools/check-jangkar-harness.py` lewat AST (elemen kedua harus daftar
#: `(sasaran, jangkar, pengganti)`). Versi pertama berkas ini memakai bentuk
#: `(nama, berkas, (cari, ganti), harap)` — lebih pendek, dan **tak terlihat
#: sama sekali** oleh gerbang itu: 73 berkas harness terbaca, 196 jangkar,
#: dan tidak satu pun milik berkas ini. Gerbang yang melewatkan satu berkas
#: dengan suara adalah kelas yang sama dengan yang berkas ini ada untuk
#: menutup, satu lapis di atasnya.
STATES = [
    # ── Aturan 8: kata asing yang terselip ────────────────────────────────
    ("[baseline] aturan 8", [], False),
    ("8a. kata asing di komentar",
     [(FILE_8, ANCHOR_8_COMMENT,
       "deshalb garis tidak")], True),
    ("8b. kata asing di kode",
     [(FILE_8, ANCHOR_8_CODE,
       "width: CGFloat = 0.75  // trotzdem")], True),
    ("8c. kata asing di literal string",
     [(FILE_8, ANCHOR_8_STRING,
       '.textSecondary.color.opacity(0.18)  // "deshalb"')], True),
    ("8d. kata asing di berkas tingkat-atas (project.yml)",
     [("project.yml", ANCHOR_8_TOP, "name: deshalb-PointAndKnow")], True),
    # Catatan pengukuran, dan ia yang membuat keadaan ini ada dalam dua bentuk.
    # `Tools/check-jangkar-harness.py` menyimpulkan mutasi bocor dari
    # `jangkar hilang && pengganti ada`. Bentuk pertama yang dicoba di sini —
    # `name: deshalbPointAndKnow` — **tidak mengandung jangkarnya**, jadi
    # gerbangnya bisa melihatnya; tetapi Aturan 8 sendiri **tetap hijau**,
    # karena `WORD` adalah `[A-Za-z…]+` sehingga seluruh pengenal itu satu
    # token yang memang tidak ada di daftar `FOREIGN`. Bentuk kedua
    # (`deshalb-PointAndKnow`) menyelesaikan keduanya: `-` memisahkan katanya
    # untuk Aturan 8, dan penggantinya tidak memuat jangkarnya untuk gerbang
    # jangkar. Dua arah itu memang milik dua gerbang yang berbeda, dan
    # keduanya harus benar bersamaan. Batasnya tetap: kata asing yang
    # **menempel** pada pengenal tidak terbaca sebagai kata.
    # Keadaan hijau: aturan tidak boleh memerah pada prosa yang sah.
    ("8e. prosa Indonesia sah tanpa kata asing (harus hijau)",
     [(FILE_8, ANCHOR_8_COMMENT, "jadi garis tidak")], False),

    # ── Aturan 17: kunci katalog ditulis ulang di Apps/ ───────────────────
    ("[baseline] aturan 17", [], False),
    ("17a. kunci milik aksesor ditulis langsung di Apps/",
     [(FILE_8, ANCHOR_8_STRING,
       '.textSecondary.color.opacity(0.18)\n'
       '    static let raw = TextLocalization.text(.calibrationMessageReady)')], True),
]


def extract_rule_program(block_open: str, label: str) -> str:
    """Ambil program Python satu aturan dari `swift-ui-lint.sh`.

    Diambil sebagai **teks** dan dijalankan langsung, bukan dengan menjalankan
    seluruh lint: pra-syarat lint yang tidak berhubungan (`project.yml`, aturan
    lain) pernah terbaca palsu sebagai "gerbang berbunyi" di repo ini.
    """
    lines = open(LINT, encoding="utf-8").read().splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() == block_open:
            start = i + 1
            break
    if start is None:
        raise SystemExit(f"GERBANG: pembuka program {label} tidak ditemukan "
                         f"di {LINT} — harness tidak boleh jalan.")
    for j in range(start, len(lines)):
        if lines[j].rstrip() == "PY":
            return "\n".join(lines[start:j])
    raise SystemExit(f"GERBANG: penutup program {label} (`PY`) tidak "
                     "ditemukan — harness tidak boleh jalan.")


def run_rule(sandbox: str, program: str) -> tuple[bool, str]:
    """Jalankan program aturan di sandbox; kembalikan (bersih?, keluaran).

    `returncode != 0` berarti programnya **galat**, bukan gerbang berbunyi:
    keduanya dibedakan supaya kegagalan menjalankan gerbang tidak pernah
    terbaca sebagai gerbang yang menangkap cacat.
    """
    proc = subprocess.run([sys.executable, "-c", program],
                          capture_output=True, text=True, cwd=sandbox)
    if proc.returncode != 0:
        tail = (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
        return False, f"GALAT menjalankan gerbang: {tail}"
    return proc.stdout.strip() == "", proc.stdout.strip()


def build_sandbox() -> str:
    """Salin pohon yang dibutuhkan aturan ke direktori sementara."""
    sandbox = tempfile.mkdtemp(prefix="aturan8-17-")
    for tree in TREES:
        src = os.path.join(ROOT, tree)
        dst = os.path.join(sandbox, tree)
        shutil.copytree(src, dst,
                        ignore=shutil.ignore_patterns(".build", "*.pyc"))
    for name in TOP_FILES:
        shutil.copy2(os.path.join(ROOT, name), os.path.join(sandbox, name))
    return sandbox


def main() -> int:
    program8 = extract_rule_program(BLOCK_RULE8, "Aturan 8")
    program17 = extract_rule_program(BLOCK_RULE17, "Aturan 17")

    # Jangkar wajib unik — jangkar yang meleset membuat keadaan cacat
    # dilaporkan hijau karena berkasnya tidak pernah berubah. Diturunkan dari
    # `STATES`, bukan dari daftar tangan: daftar tangan akan basi begitu satu
    # keadaan ditambahkan, dan keadaan yang jangkarnya tidak lagi diperiksa
    # adalah keadaan yang mengukur berkas tak berubah.
    seen_anchors = {}
    for _label, edits, _must in STATES:
        for rel, anchor, _new in edits:
            seen_anchors.setdefault((rel, anchor), 0)
            seen_anchors[(rel, anchor)] += 1
    for (rel, anchor), _ in seen_anchors.items():
        text = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        count = text.count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {anchor[:50]!r} ({rel}) muncul {count}x, "
                  "harus tepat 1x — harness tidak boleh jalan.", file=sys.stderr)
            return 2

    failures = []
    sandbox = build_sandbox()
    try:
        for label, edits, must_fire in STATES:
            program = program8 if label.startswith("8") or "aturan 8" in label \
                else program17
            originals = {}
            def restore():
                for rel, text in originals.items():
                    with open(os.path.join(sandbox, rel), "w",
                              encoding="utf-8") as handle:
                        handle.write(text)
            pristine = {}
            for rel, old, new in edits:
                target = os.path.join(sandbox, rel)
                if rel not in pristine:
                    pristine[rel] = open(target, encoding="utf-8").read()
                    originals[rel] = pristine[rel]
                if old not in pristine[rel]:
                    failures.append(f"{label}: ANCHOR TIDAK DITEMUKAN: {old!r}")
                    print(f"SALAH {label}: jangkar tidak ditemukan")
                    break
                pristine[rel] = pristine[rel].replace(old, new, 1)
                with open(target, "w", encoding="utf-8") as handle:
                    handle.write(pristine[rel])
            try:
                clean, detail = run_rule(sandbox, program)
            finally:
                restore()

            if detail.startswith("GALAT"):
                failures.append(f"{label}: {detail}")
                print(f"SALAH {label}: {detail}")
            elif must_fire:
                if clean:
                    failures.append(f"{label}: gerbang TIDAK berbunyi")
                    print(f"SALAH {label}: gerbang tetap hijau padahal "
                          "cacatnya sudah ditanam")
                else:
                    print(f"OK   {label:56s} berbunyi")
                    for line in detail.splitlines()[:3]:
                        print(f"       {line}")
            else:
                if clean:
                    print(f"OK   {label:56s} hijau (sesuai harapan)")
                else:
                    failures.append(f"{label}: gerbang MERAH pada keadaan sah")
                    print(f"SALAH {label}: gerbang merah pada keadaan sah:\n{detail}")
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)

    print()
    if failures:
        print(f"{len(failures)} keadaan tidak sesuai harapan:")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
