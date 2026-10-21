#!/usr/bin/env python3
"""Aturan 86: cabang `.stateRequest` wajib memakai putusan yang diuji.

**Cacat yang dijaga.** `PhoneLinkService.handle(_:)` punya cabang
`.stateRequest` yang berbunyi:

    // Jam meminta keadaan — balas dengan yang terakhir kita punya.
    // (Peran ini jarang terpakai, tapi harus ada supaya permintaan
    // tidak berakhir tanpa jawaban.)
    if let lastState { send(lastState) }

Komentarnya menjanjikan bahwa permintaan **selalu** dijawab. Kodenya tidak:
saat `lastState` masih `nil`, cabang itu tidak melakukan apa pun, dan
`lastNote` tidak berubah. Diukur di `main` sebelum aturan ini ada, proses
baru, seluruh 85 aturan UI dijalankan:

    PhoneLinkService.swift   cabang .stateRequest DIHAPUS SELURUHNYA  ->  HIJAU
    PhoneLinkService.swift   `if let lastState` -> `if false`         ->  HIJAU
    PhoneLinkService.swift   `lastNote = …` -> `lastNote = nil`       ->  HIJAU

Nol dari tiga yang berbunyi, karena `PhoneLinkService` tidak dirujuk satu
gerbang pun (satu-satunya berkas `Apps/` bersama `JSONArchiveDocument.swift`
dan `ComplicationLocalization.swift` yang begitu).

**Kenapa ini bukan cacat kosmetik.** Yang berbahaya bukan diamnya, melainkan
bahwa diam itu **tak terlihat**: di layar Tautan, jam yang meminta lalu tidak
dijawab tampak persis sama dengan jam yang tidak pernah meminta — `lastNote`
tidak berubah, jadi tidak ada satu piksel pun yang berbeda. PRD melarang klaim
tanpa dasar, dan "tidak ada apa-apa di layar" adalah klaim bahwa tidak ada
yang perlu dilaporkan. Sisi jam sudah benar sejak awal (ia menulis
`stateRequestTooEarly`); hanya sisi iPhone yang diam, jadi yang dijaga di sini
adalah **paritas kedua sisi**, bukan satu berkas.

**Apa yang diukur, dan apa yang TIDAK.**

Diukur: setiap berkas `Apps/` yang punya `case .stateRequest` harus
memanggil `LinkStatusText.stateRequestReply` dan harus punya cabang
`reportUnanswerable` yang menulis ke catatan status (`lastNote` /
`lastMessageNote`). Yang diukur adalah **bentuk keputusan** yang dipakai,
bukan kalimat yang dihasilkannya — kalimatnya sudah diuji di
`StateRequestReplyTests` (Linux), termasuk bahwa ia berasal dari katalog.

TIDAK diklaim: bahwa permintaan benar-benar sampai ke perangkat lain. Itu
wilayah `WCSession` dan tidak bisa diuji di Linux; `send(_:)` yang gagal
tetap melaporkan dirinya lewat `sendFailed`.
"""

import os
import re
import sys

# Berkas yang memegang cabang `.stateRequest` di `Apps/`.
CABANG = re.compile(r'case\s+\.stateRequest\s*:')

# Putusan yang diuji, dan nama anggotanya.
PUTUSAN = "LinkStatusText.stateRequestReply"
ANGGOTA = "reportUnanswerable"

# Catatan status yang boleh menerima kalimat "tidak bisa dijawab".
CATATAN = ("lastNote", "lastMessageNote")

# Pemotong badan cabang memakai **indentasi**, bukan pola `\s*`.
#
# Bukan detail gaya. Badan cabang ini memuat `switch` bersarang (itu intinya —
# putusannya dari fungsi yang diuji), dan setiap `case .resendLastState:` di
# dalamnya berada lebih dalam. Pemotong yang hanya mencari `\n\s*case\s`
# berhenti di `case` **bersarang** itu, sehingga `.reportUnanswerable` — yang
# justru wajib ada — tidak pernah terbaca, dan aturan ini melaporkan kode yang
# sudah benar sebagai cacat.
#
# Versi pertama menulis pemotong itu sebagai `\n({{{indent}}})…` lalu
# `.format(indent=" "*n)`. Hasilnya `\n({        })` — bukan kuantor
# `{n}` yang sah (kuantor tidak boleh berisi spasi), jadi Python membacanya
# sebagai literal `{        }` dan pemotongnya **tidak pernah cocok**. Terukur:
# badan cabangnya terbaca sampai akhir berkas, `.reportUnanswerable` "ada"
# karena baris `lastNote = …` di tempat lain ikut terbaca, dan mutasi yang
# menghapus penugasannya lolos hijau. Karena itu di sini dipakai `[ ]{n}`,
# yang tidak bisa salah dibaca.
def awal_baris(teks, posisi):
    return teks.rfind("\n", 0, posisi) + 1


def indentasi_baris(teks, posisi):
    """Jumlah spasi di awal baris yang memuat `posisi`."""
    i = awal_baris(teks, posisi)
    kol = 0
    while i + kol < len(teks) and teks[i + kol] == " ":
        kol += 1
    return kol


def badan_cabang(source, mulai, indent):
    """Teks badan satu cabang, dari `mulai` sampai `case`/`default`/`}`
    berikutnya yang indentasinya **sama atau lebih dangkal**."""
    henti = re.compile(r'\n[ ]{0,%d}(?:case\s|default\s*:|\})' % indent)
    m = henti.search(source, mulai)
    return source[mulai:] if m is None else source[mulai:m.start()]


def buang_komentar(teks):
    """Buang komentar `//` yang berada di luar literal string.

    Tanpa ini, komentar yang **menjelaskan** cacatnya (dan karena itu memuat
    `lastNote` serta `reportUnanswerable` di dalam prosa) akan membuat
    pemeriksaan lulus sendiri. Itu persis bentuk "hijau yang tidak hijau"
    yang sudah berulang di repo ini.
    """
    keluaran, i, dalam = [], 0, False
    while i < len(teks):
        c = teks[i]
        if dalam:
            if c == "\\":
                keluaran.append(teks[i:i + 2])
                i += 2
                continue
            if c == '"':
                dalam = False
            keluaran.append(c)
            i += 1
            continue
        if c == '"':
            dalam = True
            keluaran.append(c)
            i += 1
            continue
        if teks.startswith("//", i):
            j = teks.find("\n", i)
            i = len(teks) if j < 0 else j
            continue
        keluaran.append(c)
        i += 1
    return "".join(keluaran)


# Berkas yang **wajib** memegang cabang `.stateRequest`. Bukan ditemukan
# otomatis, melainkan didaftar: penemuan otomatis membuat aturan ini lulus
# dengan lebih sedikit berkas daripada yang seharusnya. Terukur — menghapus
# cabangnya dari `PhoneLinkService` membuat versi sebelumnya melaporkan
# "Bersih: 1 cabang" (berkas jam saja) dan tetap exit 0, padahal berkas yang
# justru punya cacat aslinya sudah tidak diperiksa lagi.
WAJIB = (
    "Apps/PointAndKnowiOS/Sources/PhoneLinkService.swift",
    "Apps/PointAndKnowWatch/Sources/WatchLinkService.swift",
)

# Setiap anggota `StateRequestReply` harus punya cabangnya sendiri.
ANGGOTA = (
    ("resendLastState", "send("),
    ("reportUnanswerable", None),   # diperiksa khusus di bawah
)


def sub_badan(badan, anggota, indent):
    """Badan satu `case .<anggota>:` di dalam cabang `.stateRequest`.

    `None` bila cabangnya tidak ada. Pemotongnya memakai indentasi `case` itu
    sendiri — bukan kuantor spasi — karena alasan yang sama dengan
    `badan_cabang`.
    """
    pola = re.compile(r'\n([ ]*)case\s+\.%s\s*:' % anggota)
    m = pola.search(badan)
    if m is None:
        return None
    kol = len(m.group(1))
    henti = re.compile(r'\n[ ]{0,%d}(?:case\s|default\s*:|\})' % kol)
    h = henti.search(badan, m.end())
    return badan[m.end():] if h is None else badan[m.end():h.start()]


def periksa(path, source):
    """Kembalikan daftar masalah untuk satu berkas."""
    masalah = []
    cabang = list(CABANG.finditer(source))
    if not cabang:
        return [f"{path}: tidak ada `case .stateRequest:` — berkas ini wajib "
                f"menjawab permintaan keadaan dari perangkat lain."]

    for m in cabang:
        nomor = source[:m.start()].count("\n") + 1
        indent = indentasi_baris(source, m.start())
        badan = buang_komentar(badan_cabang(source, m.end(), indent))

        if PUTUSAN not in badan:
            masalah.append(
                f"{path}:{nomor}: cabang .stateRequest tidak memakai "
                f"{PUTUSAN}. Cabang yang ditulis tangan bisa (dan pernah) "
                f"memilih diam saat tidak ada keadaan — lihat docstring.")
            continue

        for anggota, wajib_ada in ANGGOTA:
            isi = sub_badan(badan, anggota, indent)
            if isi is None:
                masalah.append(
                    f"{path}:{nomor}: cabang .{anggota} tidak ada. "
                    f"Setiap putusan {PUTUSAN} harus punya tindakannya; "
                    f"yang hilang berarti permintaan itu berakhir tanpa "
                    f"jawaban.")
                continue
            isi = isi.strip()

            if anggota == "resendLastState":
                # Harus benar-benar mengirim. `if false { send(...) }` lolos
                # pemeriksaan "ada kata send(" — jadi yang diperiksa adalah
                # `send(` yang **tidak** berada di dalam `if false`.
                if "send(" not in isi:
                    masalah.append(
                        f"{path}:{nomor}: cabang .resendLastState tidak "
                        f"memanggil send(...): putusannya bilang ada keadaan "
                        f"untuk dikirim, tapi tidak ada yang dikirim.")
                elif re.search(r'if\s+false\s*\{', isi):
                    masalah.append(
                        f"{path}:{nomor}: cabang .resendLastState mengirim di "
                        f"dalam `if false` — tidak pernah berjalan.")
            else:
                # Harus menulis kalimat ke catatan status, dan kalimatnya
                # bukan `nil`. `lastNote = nil` secara sintaksis adalah
                # penugasan, tapi hasilnya tetap diam — persis cacatnya.
                tulis = re.search(
                    r'(%s)\s*=\s*([^;\n]+)' % "|".join(CATATAN), isi)
                if tulis is None:
                    masalah.append(
                        f"{path}:{nomor}: cabang .{anggota} tidak menulis ke "
                        f"catatan status ({' / '.join(CATATAN)}): pengguna "
                        f"tidak akan melihat apa pun, dan diam itu tak "
                        f"terlihat dari layar.")
                elif tulis.group(2).strip() in ("nil", "Optional.none"):
                    masalah.append(
                        f"{path}:{nomor}: cabang .{anggota} menulis `nil` ke "
                        f"{tulis.group(1)}: itu penugasan yang hasilnya tetap "
                        f"diam.")
    return masalah



def main():
    if not os.path.isdir("Apps"):
        print("FAIL tidak berjalan dari akar repo (folder Apps/ tidak ada)")
        return 1

    masalah = []
    for path in WAJIB:
        if not os.path.exists(path):
            masalah.append(f"{path}: berkas tidak ada — daftar WAJIB di aturan "
                           f"ini menyebutnya, jadi ia dipindah atau dihapus "
                           f"tanpa memperbarui aturan.")
            continue
        masalah.extend(periksa(path, open(path, encoding="utf-8").read()))

    # Berkas lain yang kebetulan punya cabangnya tetap diperiksa: aturan ini
    # tidak boleh buta terhadap salinan baru di luar daftar.
    lain = 0
    for root, _, files in os.walk("Apps"):
        for nama in sorted(files):
            if not nama.endswith(".swift"):
                continue
            path = os.path.join(root, nama)
            if path in WAJIB:
                continue
            source = open(path, encoding="utf-8").read()
            if CABANG.search(source):
                lain += 1
                masalah.extend(periksa(path, source))

    if masalah:
        for baris in masalah:
            print(baris)
        print(f"-> {len(masalah)} masalah.")
        return 1

    print(f"Bersih: {len(WAJIB)} berkas wajib + {lain} berkas lain menjawab "
          f"`.stateRequest` lewat {PUTUSAN}, dan menangani "
          f"{' + '.join('.' + a for a, _ in ANGGOTA)}.")
    return 0



if __name__ == "__main__":
    sys.exit(main())
