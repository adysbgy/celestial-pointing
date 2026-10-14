#!/usr/bin/env python3
"""Buktikan Aturan 13 (kalimat yang dirakit sebagai argumen harus berkunci) **berbunyi**.

Kenapa harness ini ada.

Aturan 13 menyapu kelas cacat lokalisasi yang **dua gerbang lain tidak lihat**:
kalimat yang lahir sebagai argumen — di dalam `String(format: …)`,
`parts.append(…)`, `parts += […]`. Aturan 4 menyapu literal di dalam `Text(…)`,
Aturan 12 menyapu literal yang ditugaskan ke variabel berakhiran Note/Label.
Kalimat seperti ini tidak pernah menyentuh keduanya.

Yang membuatnya berbahaya bukan kerapian, melainkan bahwa ia **tidak terlihat
salah**. "Laju pergelangan %.0f derajat per detik." berisi angka dan derajat
yang identik di semua bahasa, jadi diff dan tangkapan layar tidak menunjukkan
apa pun. Yang berbeda — kata pengantar dan **urutannya** — hanya terasa oleh
pengguna yang membaca bahasa lain. Di repo ini bentuk itu pernah ada delapan
kali, antara lain "Laju pergelangan %.0f derajat per detik." yang memaksa
Bahasa Inggris mengucapkan "derajat", dan "Keadaan: %@." yang memaksa awalan
Bahasa Indonesia dibaca lebih dulu.

`swiftc` tidak peduli, `swift test` di Linux tidak bisa menolong (ia hanya
membangun `Packages/`, sedangkan berkasnya hidup di `Apps/`), dan CI macOS
hanya gagal bila ada *warning*. Sampai siklus ini Aturan 13 tidak punya satu
pun rekam jejak bahwa ia bisa keluar merah — dan gerbang yang belum pernah
diukur merah sama dengan gerbang yang tidak mengukur apa pun.

Kenapa programnya **diekstrak** dari `swift-ui-lint.sh`, bukan disalin.

Harness yang menyalin aturannya mengukur **salinan**: ia tetap hijau walau
aturan aslinya dilonggarkan sampai tidak menggigit apa pun. Batas potongannya
dinyatakan dan diperiksa; kalau penanda yang dibutuhkan hilang, harness
**berhenti** (exit 2) alih-alih melaporkan hijau atas potongan yang tidak
mengukur apa-apa.

Keadaan yang diuji, dan apa yang masing-masing buktikan.

  [baseline]                    kode benar -> gerbang hijau. Tanpa ini, harness
                                yang selalu merah lulus seluruh keadaan di bawah.

  1. `String(format:)` dengan   Bentuk yang docstring aturan sendiri namai.
     kalimat literal            Membuktikan cabang `String(format:` hidup.

  2. `parts += ["Keadaan: %@."]` Cabang yang **berbeda**: `+=` dengan larik
                                literal. Tanpa keadaan ini, aturan yang hanya
                                menyapu `String(format:` akan lulus keadaan 1
                                dengan sempurna.

  3. helper katalog tanpa       `parts.append(TextLocalization.text(.kunci))` —
     literal                    tidak ada literal kalimat, jadi gerbang harus
                                **diam**. Ini bentuk yang benar, dan gerbang yang
                                memerah padanya akan dimatikan orang.

  4. interpolasi murni angka    `String(format: "%.0f", rate)`. Tanpa kata, ini
                                bukan kalimat yang perlu diterjemahkan — gerbang
                                harus **diam**, kalau tidak setiap angka yang
                                diformat di view akan dilaporkan.

  5. satu kata, tanpa spasi     `String(format: "Lock")`. Satu kata = nama, bukan
                                kalimat (aturan menyaringnya lewat `" " not in
                                raw`). Gerbang harus **diam**.

Keadaan 3, 4, dan 5 bukan hiasan: tanpa ketiganya, aturan yang memerah pada
**setiap** literal di dalam `append` akan lulus keadaan 1 dan 2 dengan
sempurna — dan itu gerbang yang tidak bisa dipakai.

Yang TIDAK diklaim harness ini.

- Ia mengukur **teks** `Apps/`, bukan tampilan atau pengucapan di perangkat.
  Yang dibuktikan: aturan berbunyi pada kalimat yang dirakit sebagai argumen,
  dan diam pada bentuk yang sah.
- Ia **tidak** menyentuh penyempitan yang aturan sendiri nyatakan: literal yang
  **sama persis dengan nama kunci katalog** sengaja dilewati (`raw in keys`),
  karena bentuk itu adalah nilai bawaan katalog yang ikut dimuat di view.
  Keadaan yang memakainya sebagai "cacat" akan mengukur harapan yang salah, jadi
  tidak ada di sini.
- Ia tidak membuktikan terjemahan kalimat yang sudah berkunci itu benar.
- Ia memutasi berkas produksi, jadi ia tunduk pada `require_clean_sources`: ia
  **menolak jalan** di atas pohon yang sudah kotor. Penolakan itu benar, bukan
  kerusakan — pohon kerja yang memuat WIP siklus lain memang tidak boleh diukur.

**Non-vakuositasnya diukur, bukan diklaim.** Dengan pendeteksi Aturan 13
(`CTX`) dilumpuhkan di worktree terpisah — polanya diubah supaya tidak akan
pernah cocok, sehingga tidak ada satu pun tempat kalimat bisa lahir — harness
ini merah **persis pada keadaan 1 dan 2**, dan tetap hijau pada keadaan 3, 4,
dan 5.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (bersih-dulu, tulis atomik, pulih terverifikasi)

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
VIEW = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources", "PointingView.swift")

BEGIN = "# ── Aturan 13:"
END = "# ── Aturan 14:"

#: Tanda yang harus ada di dalam potongan. Kalau salah satu hilang, yang
#: diekstrak bukan aturan yang CI jalankan dan harness berhenti.
REQUIRED = ("== Aturan 13:",
            "Bersih: tak ada kalimat yang dirakit sebagai argumen.",
            "status=1")

#: Jangkar di view. Masing-masing harus muncul **tepat sekali**: jangkar yang
#: muncul dua kali menyunting lebih banyak daripada yang dilaporkan, dan
#: harness yang menyunting lebih banyak daripada yang dilaporkan adalah harness
#: yang mengukur keadaan yang tidak ia sebut.
A_WRIST = "            parts.append(RowSpeech.spokenWristRate(rate))"
A_MAGNITUDE = "        parts.append(ObjectSpeech.magnitude(object.magnitude))"

#: (label, jangkar, pengganti, harus_merah). `None` = tanpa suntikan.
STATES = [
    ("[baseline] kode benar", None, None, False),

    # ── Cacat: dua cabang perakitan yang berbeda ──────────────────────────
    ("1. `String(format:)` dengan kalimat literal",
     A_WRIST,
     '            parts.append(String(format: "Laju pergelangan %.0f derajat per detik.", rate))',
     True),
    ("2. `parts += [\"Keadaan: %@.\"]` (cabang `+=`)",
     A_MAGNITUDE,
     '        parts += ["Keadaan: %@."]',
     True),

    # ── Kontrol negatif: bentuk yang sah harus tetap hijau ────────────────
    ("3. helper katalog tanpa literal — kontrol negatif",
     A_WRIST,
     "            parts.append(TextLocalization.text(.pointingSkyContextLabel))",
     False),
    ("4. interpolasi murni angka — kontrol negatif",
     A_WRIST,
     '            parts.append(String(format: "%.0f", rate))',
     False),
    ("5. satu kata tanpa spasi — kontrol negatif",
     A_WRIST,
     '            parts.append(String(format: "Lock"))',
     False),
]

_original: str | None = None


def restore(*_):
    """Pulihkan `PointingView.swift` — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(path, "w")`: berkas ini juga dimutasi
    harness lain, dan kegagalan pemulihan bersifat diam — keadaan berikutnya
    lalu menyalahkan kode yang sebenarnya benar.
    """
    if _original is not None:
        mutasi_sumber.restore_verified(VIEW, _original)


def extract_rule13():
    """Ambil potongan program Aturan 13 dari `swift-ui-lint.sh`, atau `None`."""
    text = open(LINT, encoding="utf-8").read()
    start = text.find(BEGIN)
    end = text.find(END)
    if start < 0 or end <= start:
        return None
    return text[start:end]


def probe(program):
    """Jalankan Aturan 13 sendiri -> (merah?, detail)."""
    proc = subprocess.run(["bash", "-c", program], cwd=ROOT,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    clean = "Bersih: tak ada kalimat yang dirakit sebagai argumen." in out
    return (not clean), out.strip()


def main():
    mutasi_sumber.require_clean_sources([VIEW])

    program = extract_rule13()
    if program is None:
        print("GERBANG: potongan Aturan 13 tidak ditemukan di swift-ui-lint.sh "
              f"(antara {BEGIN!r} dan {END!r}) — harness tidak boleh jalan.",
              file=sys.stderr)
        return 2
    missing = [mark for mark in REQUIRED if mark not in program]
    if missing:
        print("GERBANG: potongan Aturan 13 tidak memuat "
              + ", ".join(repr(m) for m in missing)
              + " — yang diekstrak bukan aturan yang CI jalankan, jadi "
                "harness ini tidak mengukur apa pun.", file=sys.stderr)
        return 2

    global _original
    _original = open(VIEW, encoding="utf-8").read()

    for label, anchor in (("`parts.append(RowSpeech.spokenWristRate(rate))`", A_WRIST),
                          ("`parts.append(ObjectSpeech.magnitude(…))`", A_MAGNITUDE)):
        count = _original.count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x — "
                  "harness tidak boleh jalan.", file=sys.stderr)
            return 2

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, anchor, replacement, must_fire in STATES:
            mutasi_sumber.write_source(VIEW, _original)
            if anchor is not None:
                content = _original.replace(anchor, replacement, 1)
                if content == _original:
                    print(f"{label:52s} ANCHOR TIDAK DITEMUKAN")
                    unexpected += 1
                    continue
                mutasi_sumber.write_source(VIEW, content)

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:52s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            # Yang dituntut bukan sekadar «merah»: aturan harus **menyebut
            # berkas yang disuntik**. Pesan yang menunjuk berkas lain berarti
            # yang berbunyi bukan aturan ini, dan keadaan ini tidak membuktikan
            # apa pun tentangnya.
            named_view = os.path.relpath(VIEW) in detail
            ok = (fired == must_fire)
            if fired and not named_view:
                ok = False
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:52s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if fired and not named_view:
                print("       (merah, tetapi tidak menyebut berkas yang disuntik)")
            if fired:
                for line in detail.splitlines():
                    if line.strip():
                        print(f"       {line.strip()[:150]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
