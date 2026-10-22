#!/usr/bin/env python3
"""Aturan 87: setiap `Text` mendapat warna dari palet, bukan warisan `.primary`.

**Cacat yang dijaga.** Mode malam menjanjikan palet **merah murni**:
`SurfacePalette.night.textPrimary` = (1.000, 0.000, 0.000). Janji itu hanya
berlaku untuk teks yang **diberi** warna. `Text` tanpa `foregroundStyle`
mewarisi `.primary`, yang di skema gelap = putih (1, 1, 1) — kanal hijau dan
biru penuh, tepat yang dirusak mode malam terhadap rhodopsin (rod ~498–530 nm;
merah >620 nm tidak menyentuhnya).

Diukur di pohon utuh sebelum aturan ini ada (`./swift-ui-lint.sh`, 86 aturan,
exit 0):

    PointingView.swift:586     Text(objectDisplayName)   -> tanpa warna
    DiagnosticsView.swift:1019 Text(displayName ?? …)    -> tanpa warna

Keduanya adalah **informasi utama aplikasi** — nama benda yang sedang
ditunjuk, yang paling besar dan paling tebal di kartu jam dan di panel detail
iPhone. Di mode malam jawaban yang dicari pengguna tetap putih sementara
seluruh layar di sekitarnya merah. Nol dari 86 aturan berbunyi, karena aturan
warna yang ada memeriksa apakah warna yang **sudah ditulis** berasal dari
palet; tidak ada yang memeriksa apakah warna itu **ada**.

**Dua cacat, bukan satu.** Selain baris-baris di atas, akarnya juga bocor:
`forceDarkScheme()` hanya memasang `preferredColorScheme(.dark)`, tidak
pernah memasang warna teks. Jadi tidak ada satu pun titik di pohon yang
menurunkan warna palet. Aturan ini mengukur keduanya, karena memperbaiki
pemanggil satu per satu tanpa memperbaiki akarnya hanya memindahkan masalah
ke teks berikutnya.

**Kenapa bentuknya begini.** `foregroundStyle` adalah nilai lingkungan: satu
pemasangan di akar layar menurun ke seluruh keturunan, dan pemasangan
eksplisit di anak tetap menang. Jadi aturannya bukan "setiap `Text` wajib
menulis warna sendiri" — itu kerja yang sama berulang. Yang dituntut: setiap
`Text` berwarna, entah dari rantai modifiernya sendiri, dari rantai modifier
blok yang membungkusnya, atau dari akar palet berkasnya.

**Apa yang TIDAK diklaim.** Ini pembaca teks, bukan pemeriksa tipe. Ia
menebak pohon tampilan dari blok kurawal, jadi ia bisa salah pada kode yang
menyusun view di luar blok (mis. `.overlay { }` yang rantainya menempel ke
induk lain). Yang diukur adalah **keberadaan warna dari palet di jalur render
layar itu**, bukan hasil pikselnya. Rasio kontras juga tidak diukur di sini —
itu `SurfacePalette.weakestTextContrast`, diuji di Linux.
"""

import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "Apps"

AKAR = os.path.join("Apps", "Shared", "SurfaceTokens.swift")
AKAR_FUNGSI = "func forceDarkScheme()"
AKAR_WARNA = "foregroundStyle(SurfacePalette.active.textPrimaryColor)"

WARNA = re.compile(r"\.(foregroundStyle|foregroundColor)\s*\(")
TEKS = re.compile(r"(?<![\w.])Text\s*\(")
SPASI = " \t\r\n"

# Berkas yang sah tidak memakai palet app sama sekali.
#
# Setiap entri harus tetap benar. Daftar pengecualian yang tidak bisa basi
# adalah daftar yang cepat atau lambat berbohong — karena itu isinya satu
# berkas yang alasannya struktural, bukan "belum sempat".
PENGECUALIAN = {
    "Apps/PointAndKnowWatch/Complications/ComplicationWidget.swift":
        "complication dirender WatchKit di muka jam, di luar pohon app: "
        "warnanya milik sistem (widgetRenderingMode), bukan palet",
}


def buang_komentar_dan_string(src):
    """Ganti komentar dan isi string dengan spasi, panjang tetap.

    Panjang dipertahankan supaya nomor baris hasilnya sama dengan berkas asli.
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        dua = src[i:i + 2]
        if dua == "//":
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif dua == "/*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join("\n" if c == "\n" else " " for c in src[i:j]))
            i = j
        elif src[i] == '"':
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == '"':
                    j += 1
                    break
                j += 1
            out.append('"' + " " * max(0, j - i - 2) + '"')
            i = j
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def cocok(kode, buka):
    """Indeks penutup yang berpasangan dengan `buka`."""
    pasangan = {"(": ")", "{": "}", "[": "]"}
    tutup_ch = pasangan[kode[buka]]
    dalam = 0
    for j in range(buka, len(kode)):
        if kode[j] == kode[buka]:
            dalam += 1
        elif kode[j] == tutup_ch:
            dalam -= 1
            if dalam == 0:
                return j
    return len(kode) - 1


def rantai_modifier(kode, mulai):
    """Rantai `.nama(...)` yang menempel langsung sesudah `mulai`."""
    i, n = mulai, len(kode)
    while i < n:
        while i < n and kode[i] in SPASI:
            i += 1
        if i >= n or kode[i] != ".":
            break
        j = i + 1
        while j < n and (kode[j].isalnum() or kode[j] == "_"):
            j += 1
        while j < n and kode[j] in SPASI:
            j += 1
        if j < n and kode[j] == "(":
            j = cocok(kode, j) + 1
        i = j
    return kode[mulai:i]


def blok_pembungkus(kode, pos):
    """Indeks `{` pembuka setiap blok yang membungkus `pos`, terdalam dulu."""
    hasil = []
    kedalaman = 0
    i = pos - 1
    while i >= 0:
        c = kode[i]
        if c == "}":
            kedalaman += 1
        elif c == "{":
            if kedalaman == 0:
                hasil.append(i)
            else:
                kedalaman -= 1
        i -= 1
    return hasil


def berwarna(kode, pos):
    """(punya warna, sumbernya) untuk `Text` di `pos`."""
    buka = kode.find("(", pos)
    tutup = cocok(kode, buka)
    if WARNA.search(rantai_modifier(kode, tutup + 1)):
        return True, "sendiri"
    for b in blok_pembungkus(kode, pos):
        t = cocok(kode, b)
        if t < pos:
            continue
        if WARNA.search(rantai_modifier(kode, t + 1)):
            return True, "pembungkus"
    return False, None


def badan_fungsi(kode, tanda):
    """Isi kurung kurawal milik deklarasi yang memuat `tanda`, atau None."""
    pos = kode.find(tanda)
    if pos < 0:
        return None
    buka = kode.find("{", pos)
    if buka < 0:
        return None
    return kode[buka:cocok(kode, buka) + 1]


def main():
    gagal = []

    # 1. Akar palet wajib memasang warna teks.
    if not os.path.isfile(AKAR):
        print(f"FAIL {AKAR} tidak ada: Aturan 87 tidak bisa mengukur akar palet.")
        return 1
    kode_akar = buang_komentar_dan_string(open(AKAR, encoding="utf-8").read())
    badan = badan_fungsi(kode_akar, AKAR_FUNGSI)
    if badan is None:
        gagal.append(
            f"{AKAR}: `{AKAR_FUNGSI}` tidak ditemukan — tidak ada akar palet "
            f"untuk teks.")
    elif AKAR_WARNA not in badan:
        gagal.append(
            f"{AKAR}: `{AKAR_FUNGSI}` tidak memasang `{AKAR_WARNA}` — teks "
            f"tanpa warna eksplisit kembali ke `.primary` (putih) dan mode "
            f"malam berhenti menjadi merah.")

    # 2. Setiap `Text` berwarna.
    jumlah = {"sendiri": 0, "pembungkus": 0, "akar": 0}
    dipakai = set()
    for akar_dir, _, nama in os.walk(ROOT):
        for n in sorted(nama):
            if not n.endswith(".swift"):
                continue
            path = os.path.join(akar_dir, n).replace(os.sep, "/")
            mentah = open(path, encoding="utf-8").read()
            kode = buang_komentar_dan_string(mentah)
            teks = list(TEKS.finditer(kode))
            if not teks:
                continue
            punya_akar = "forceDarkScheme()" in kode
            if path in PENGECUALIAN:
                dipakai.add(path)
                continue
            for m in teks:
                ok, sumber = berwarna(kode, m.start())
                if ok:
                    assert sumber is not None
                    jumlah[sumber] += 1
                elif punya_akar:
                    jumlah["akar"] += 1
                else:
                    baris = kode.count("\n", 0, m.start()) + 1
                    isi = mentah.split("\n")[baris - 1].strip()
                    gagal.append(
                        f"{path}:{baris}: `{isi[:64]}` tidak punya warna dan "
                        f"berkasnya tidak memasang `forceDarkScheme()` — "
                        f"teksnya jatuh ke `.primary` (putih) di mode malam.")

    for path in sorted(set(PENGECUALIAN) - dipakai):
        gagal.append(
            f"{path}: terdaftar di PENGECUALIAN tetapi tidak lagi memuat "
            f"`Text(` — entri basi, hapus.")

    if gagal:
        print("Aturan 87 GAGAL:")
        for g in gagal:
            print(f"  - {g}")
        return 1

    print(f"Aturan 87: akar palet memasang warna teks; {jumlah['sendiri']} "
          f"`Text` berwarna sendiri, {jumlah['pembungkus']} dari pembungkus, "
          f"{jumlah['akar']} dari akar berkas, {len(PENGECUALIAN)} berkas "
          f"beralasan di luar pohon app.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
