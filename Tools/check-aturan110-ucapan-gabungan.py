#!/usr/bin/env python3
"""Aturan 110: setiap elemen `.accessibilityElement(children: .combine)`
wajib punya `.accessibilityLabel` sesudahnya.

**Kenapa aturan ini ada, dan bukannya sebuah tebakan.**

Diukur pada salinan utuh pohon ini, proses baru, dengan `./swift-ui-lint.sh`
sungguhan dijalankan. Tiga dari empat label yang FASE A tuntut dihapus satu
satu:

    statusCard label        → LINT exit 0
    ObjectDetail label      → LINT exit 1   (sudah terpaku)
    tombol kalibrasi        → LINT exit 0
    tombol Catat            → LINT exit 0

Nol yang berbunyi untuk tiga di antaranya. Menghapus `.accessibilityLabel`
dari sebuah `Text` yang sudah punya teks terlihat tetap sah secara tipe —
compiler hanya melihat sebuah `.accessibilityLabel(String)` yang hilang.
Dan yang paling penting: `.accessibilityElement(children: .combine)` bukan
hiasan. Ia **mengganti seluruh subtree** dengan satu elemen yang diumumkan
murni dari labelnya. Tanpa label, elemen yang semestinya berbicara menjadi
SENYAP — bukan sekadar kurang baik, tapi hilang sama sekali bagi pembaca
layar, untuk kartu keadaan dan tombol yang persis FASE A tuntut.

Inilah yang membuat aturan ini berbeda dari larangan umum "taruh a11y":
bentuk `.combine` menciptakan kelas cacat sendiri, yaitu gabungan yang
membisukan diri.

**Bentuk yang diperiksa.** Cari setiap `.accessibilityElement(children:
.combine)`; dalam blok yang sama (sampai penutup `body`/`var` berikutnya)
harus ada `.accessibilityLabel`. Pengecualian harus eksplisit dan
terlihat: elemen yang menggabungkan **hanya** teks terlihat boleh
`.accessibilityLabel` ganda-ganda — tapi itu persis kesalahan yang
menyebabkan kabar nama; yang dituntut di sini adalah label nyata.

Batas: aturan ini memeriksa **bentuk**, bukan isi ucapan. Apakah ucapan itu
benar tetap urusan uji dan mata manusia.

Yang TIDAK diklaim: aturan ini tidak memeriksa tombol yang tidak memakai
`.combine` (mereka masih bisa kehilangan label tanpa berbunyi), dan tidak
memeriksa `accessibilityHint`/`accessibilityValue`.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Direktori aplikasi SwiftUI — tempat aturan ini berlaku.
APPS_DIRS = [
    ROOT / "Apps",
]

# Simbol pembuka elemen gabungan.
COMBINE_RE = re.compile(
    r"\.accessibilityElement\(\s*children\s*:\s*\.combine\s*\)"
)
# Label ucapan — yang wajib menyusul.
LABEL_RE = re.compile(r"\.accessibilityLabel\s*\(")

# Pembersih komentar: docstring Swift memuat kata-kata aturan ini (tiga
# berkas menjelaskan keputusannya dengan menyebut `.combine` dan label),
# dan satu komentar saja akan membuat hitungan meleset.
COMMENT_RE = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)


def _clean(source: str) -> str:
    """Buang komentar, tapi pertahankan nomor baris.

    Komentar diganti spanyereya baris, sehingga posisi baris asli tetap
    berlaku untuk pesan yang dilaporkan ke pengembang.
    """
    def repl(m: re.Match) -> str:
        return re.sub(r"[^\n]", " ", m.group(0))

    return COMMENT_RE.sub(repl, source)


def _blk_end(clean: str, start: int) -> int:
    """Sampai penutup blok berikutnya setelah posisi `start`.

    Dipakai untuk memotong blok yang memuat `.combine` ke badan deklarasi
    yang memuatnya — bukan seluruh berkas, supaya sebuah label milik
    deklarasi lain tidak terhitung sebagai label elemen ini.

    **Kenapa pencarian kata kunci tidak cukup.** Aturan ini menutup cacat
    "label dihapus", dan harness bukti mutasinya (lima keadaan) mengukurnya.
    Yang pertama kali terukur: harness melaporkan HIJAU untuk penghapusan
    label statusCard, padahal wajib MERAH. Karena itu batas blok dicari
    dengan kata kunci:

        for kw in ("var body", "private var", "var ", "struct ", "func "):

    kata kunci **berikutnya** itu ada di baris 559 — yaitu deklarasi
    berikutnya, jauh sesudah `body` yang memuat `.combine` di baris 320. Blok
    jadi 239 baris dan menelan `.accessibilityLabel` milik tiga deklarasi
    sesudahnya. Label sesungguhnya dari elemen di baris 320 terhapus, dan
    gerbangnya tetap hijau karena ada label lain yang masuk hitungan.

    Jadi batasnya kini dari **kedalaman kurung**, bukan teks: mulai dari
    posisi `.combine`, hitung `{`/`}` dan berhenti pada kedalaman yang lebih
    dalam dari kedalaman awal. Deklarasi berikutnya ada di kedalaman yang
    sama atau lebih dangkal, jadi tidak bisa lagi terbaca sebagai blok ini.
    """
    depth = 0
    i = start
    n = len(clean)
    while i < n:
        ch = clean[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            if depth == 0:
                # Penutup pemilik `.combine` tanpa ada blok baru yang
                # dibuka di antaranya.
                return i + 1
            depth -= 1
            if depth == 0:
                # Blok terdekat yang memuat `.combine` ditutup di sini.
                return i + 1
        i += 1
    return n


def scan(path: Path) -> list[tuple[int, str]]:
    """Kembalikan [(baris, uraian)] untuk setiap `.combine` tanpa label."""
    source = path.read_text(encoding="utf-8")
    clean = _clean(source)
    findings: list[tuple[int, str]] = []

    for match in COMBINE_RE.finditer(clean):
        start = match.start()
        end = _blk_end(clean, start)
        block = clean[start:end]
        if not LABEL_RE.search(block):
            line = clean.count("\n", 0, start) + 1
            findings.append((line, "elemen gabungan tanpa .accessibilityLabel"))
    return findings


def main() -> int:
    checked = 0
    problems: list[str] = []

    for apps_dir in APPS_DIRS:
        if not apps_dir.exists():
            continue
        for path in sorted(apps_dir.rglob("*.swift")):
            checked += 1
            for line, note in scan(path):
                rel = path.relative_to(ROOT)
                problems.append(f"{rel}:{line}: {note}")

    if not checked:
        print(
            "Aturan 110: GAGAL — nol berkas Swift diperiksa. "
            "Hijau atas nol subjek bukan hijau."
        )
        return 1

    if problems:
        print(f"Aturan 110: {len(problems)} elemen gabungan tanpa ucapan.")
        for item in problems:
            print(f"  {item}")
        print(
            "\n-> Tambahkan .accessibilityLabel setelah .accessibilityElement"
            "(children: .combine)."
            "\n   Yang digabungkan itu SATU elemen yang diumumkan murni dari"
            "\n   labelnya — tanpa label, kartu keadaan dan tombolnya SENYAP"
            "\n   bagi pembaca layar."
        )
        return 1

    print(
        f"Aturan 110: setiap elemen `.accessibilityElement(children: "
        f".combine)` di {checked} berkas punya ucapan"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
