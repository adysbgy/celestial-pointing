#!/usr/bin/env python3
"""Aturan 109: setiap cabang `TimelineView` wajib punya cabang statis.

**Kenapa aturan ini ada, dan cacatnya bukan tebakan.**

Tiga layar memutuskan denyut dengan bentuk yang sama:

    if <gerbang gerak> {
        TimelineView(.animation(minimumInterval: MotionPolicy.pulseFrameInterval)) { _ in
            CelestialVisualView(…, pulse: …)
        }
    } else {
        CelestialVisualView(…, pulse: MotionPolicy.staticPulsePhase)
    }

Gerbang geraknya berbeda di tiga tempat (`motion.allowsContinuousMotion &&
visual.hasPulse` di jam dan iPhone, `!reduceMotion && illustration.hasPulse` di
layar perkenalan), tetapi bentuknya satu: **cabang beranimasi** dan **cabang
statis**. `TimelineView` menyegarkan `Canvas` 30 kali per detik; cabang `else`
adalah satu-satunya jalan gambar itu muncul saat penyegaran per frame tidak
boleh atau tidak perlu jalan.

Diukur pada salinan utuh pohon ini (proses baru, `./swift-ui-lint.sh` dan
`./swift-typecheck.sh` sungguhan dijalankan), cabang `else` di **ketiga** layar
dihapus — dan keduanya LULUS:

    jam:    `} else { CelestialVisualView(…staticPulsePhase) }` dihapus → LINT exit 0
    iPhone: `} else { content(pulse: 0) }` dihapus                      → LINT exit 0
    onboarding: cabang statis bintang dihapus                           → LINT exit 0

    swift-typecheck.sh → exit 0 untuk ketiganya

Nol yang berbunyi. Yang terjadi di layar bukan crash melainkan **kekosongan**:
`if` tanpa `else` di dalam `ViewBuilder` berarti cabang yang tidak terpenuhi
menggambar **tidak ada apa-apa**. Di jam, `hasPulse` bernilai `false` untuk
planet, Bulan, dan Matahari — jadi yang hilang bukan satu animasi, melainkan
**seluruh gambar** untuk setiap objek yang bukan bintang. Dan karena
`CelestialVisualView` masih dipanggil di cabang `if` serta di layar lain,
setiap pemeriksaan "apakah view ini dipakai" tetap hijau.

**Kenapa tidak ada gerbang yang melihatnya.** `swift-ui-lint.sh` membaca teks,
tetapi tidak ada satu aturan pun yang mengenali "`if` tanpa `else` di dalam
`ViewBuilder`" sebagai cacat — dan bentuk itu **sah** di Swift, sah di
`@ViewBuilder`, dan sah secara tipe (`EmptyView` adalah `View`). Compiler diam.
Tidak ada teks di layar yang berubah; yang hilang adalah gambar.

**Yang diukur, sempit dan konkret.** Setiap `if … {` yang **cabang then-nya
memuat `TimelineView(`** wajib punya `else` sesudah penutupnya, dan badan
`else` itu wajib memuat setidaknya satu pemanggilan (`(`) — bukan kosong, bukan
komentar saja. Nol cabang `TimelineView` di seluruh `Apps/` = GAGAL: gerbang
yang berhenti menemukan subjeknya lebih mungkin berarti bentuk kodenya berubah
daripada aplikasinya berhenti berdenyut.

**Kenapa pemicunya `TimelineView`, bukan nama gerbang geraknya.** Tiga layar
memakai tiga predikat berbeda, dan predikat keempat yang ditulis besok akan
membuat daftar tangan basi tepat di situ. `TimelineView` adalah **bentuk** yang
menyebabkan cacatnya: penyegaran per frame. Setiap `if` yang memilih antara
penyegaran per frame dan tidak, butuh kedua jawabannya tertulis.

**Yang TIDAK diklaim.** Ini sapuan teks, bukan render: ia tidak membuktikan
cabang statisnya menggambar hal yang sama dengan cabang beranimasinya (itu
`MotionPolicy.staticPulsePhase` + uji `hasPulse` di Linux), dan tidak
membuktikan `TimelineView` benar-benar berdetak di perangkat. Ia juga tidak
membedakan `else if` — bentuk itu akan terbaca sebagai `else` dengan badan yang
memuat `(`; yang dijaga adalah "ada jawaban kedua", bukan "jawabannya tepat
satu". Yang dijaga sempit dan konkret: **cabang statis yang sudah terukur bisa
dihapus tanpa gerbang merah** tidak bisa terulang.
"""
from __future__ import annotations

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS = os.path.join(ROOT, "Apps")


def strip_comments(source: str) -> str:
    """Buang komentar `//` dan `/* */`, pertahankan isi string.

    Docstring di ketiga berkas itu **menyebut** `TimelineView` dan `else`
    berkali-kali untuk menjelaskan keputusannya. Tanpa penyaringan, gerbangnya
    akan menuduh dokumentasi yang benar — dan gerbang yang merah atas
    dokumentasi yang benar akan dimatikan orang.
    """
    out = []
    i = 0
    n = len(source)
    in_line = in_block = in_str = False
    while i < n:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < n else ""
        if in_line:
            if ch == "\n":
                in_line = False
                out.append(ch)
            i += 1
            continue
        if in_block:
            if ch == "*" and nxt == "/":
                in_block = False
                i += 2
                continue
            if ch == "\n":
                out.append(ch)
            i += 1
            continue
        if in_str:
            out.append(ch)
            if ch == "\\" and nxt:
                out.append(nxt)
                i += 2
                continue
            if ch == '"':
                in_str = False
            i += 1
            continue
        if ch == "/" and nxt == "/":
            in_line = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def matching_brace(code: str, open_index: int):
    """Indeks `}` yang menutup `{` di `open_index`, atau `None`."""
    depth = 0
    in_str = False
    i = open_index
    n = len(code)
    while i < n:
        ch = code[i]
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return None


#: `if <kondisi> {` di awal baris — bentuk yang dipakai ketiga layar.
IF_OPEN = re.compile(r"^[ \t]*if\b[^{]*\{[ \t]*$", re.MULTILINE)
#: `else` yang mengikuti penutup `}` (boleh sebaris `} else {`).
ELSE_AFTER = re.compile(r"\s*else\b")


def check_file(path: str):
    """Temuan untuk satu berkas, plus jumlah cabang `TimelineView` terbaca."""
    with open(path, encoding="utf-8") as handle:
        code = strip_comments(handle.read())

    findings = []
    timeline_branches = 0
    for match in IF_OPEN.finditer(code):
        open_brace = code.index("{", match.start())
        close_brace = matching_brace(code, open_brace)
        if close_brace is None:
            findings.append((match.start(),
                             "`if` tidak tertutup — gerbang berhenti mengukur"))
            continue
        then_body = code[open_brace + 1:close_brace]
        if "TimelineView(" not in then_body:
            continue
        timeline_branches += 1
        line = code[:match.start()].count("\n") + 1
        rest = code[close_brace + 1:]
        else_match = ELSE_AFTER.match(rest)
        if not else_match:
            findings.append((
                line,
                "cabang `TimelineView` tanpa `else`: saat penyegaran per frame "
                "tidak boleh jalan, cabang ini menggambar **tidak ada apa-apa** "
                "— gambar objeknya hilang, bukan denyutnya saja"))
            continue
        else_start = close_brace + 1 + else_match.end()
        # `else {` — badan statisnya wajib memanggil sesuatu.
        else_brace = code.find("{", else_start)
        if else_brace < 0 or code[else_start:else_brace].strip():
            findings.append((
                line,
                "`else` tanpa badan kurawal sesudah cabang `TimelineView` — "
                "bentuk ini tidak bisa dibaca, jadi tidak bisa dijamin "
                "menggambar apa pun"))
            continue
        else_close = matching_brace(code, else_brace)
        if else_close is None:
            findings.append((line, "badan `else` tidak tertutup"))
            continue
        else_body = code[else_brace + 1:else_close]
        if "(" not in else_body:
            findings.append((
                line,
                "badan `else` sesudah cabang `TimelineView` tidak memanggil "
                "apa pun — cabang statis yang kosong sama dengan tidak ada"))
    return findings, timeline_branches


def main() -> int:
    files = sorted(glob.glob(os.path.join(APPS, "**", "*.swift"), recursive=True))
    if not files:
        print("Aturan 109: GAGAL — nol berkas Swift di Apps/ terbaca. "
              "Gerbang yang hijau atas nol berkas tidak mengukur apa pun.")
        return 1
    problems = []
    branches = 0
    for path in files:
        findings, count = check_file(path)
        branches += count
        rel = os.path.relpath(path, ROOT)
        for line, message in findings:
            problems.append("{}:{}: {}".format(rel, line, message))

    if problems:
        print("Aturan 109: cabang `TimelineView` tanpa jawaban statis")
        for problem in problems:
            print("  " + problem)
        print("-> Tambahkan `else` yang memanggil gambar yang sama dengan "
              "`pulse: MotionPolicy.staticPulsePhase`. `if` tanpa `else` di "
              "dalam `ViewBuilder` menggambar kosong, dan `hasPulse` bernilai "
              "`false` untuk planet, Bulan, dan Matahari.")
        return 1
    if branches == 0:
        print("Aturan 109: GAGAL — {} berkas terbaca tetapi nol cabang "
              "`TimelineView`. Gerbang berhenti menemukan subjeknya: "
              "kemungkinan bentuk kodenya berubah, bukan aplikasinya berhenti "
              "berdenyut.".format(len(files)))
        return 1
    print("Aturan 109: {} cabang `TimelineView` di {} berkas — semuanya punya "
          "jawaban statis".format(branches, len(files)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
