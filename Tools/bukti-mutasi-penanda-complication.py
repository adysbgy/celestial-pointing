#!/usr/bin/env python3
"""Buktikan Aturan 23 (penanda keraguan di complication) **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Sapuan yang menutup 84/84 gerbang `check-visuals.py` (3 -> 0 nirsaksi) belum
pernah diajukan ke gerbang satunya lagi, `swift-ui-lint.sh`. Terukur di awal
siklus dengan menyilangkan 35 aturan terhadap harness yang menjalankannya:

    bersaksi : 1, 3, 7, 15, 18, 24, 31, 32, 33, 34, 35
    nirsaksi : 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 20, 21, 22,
               23, 25, 26, 27, 28, 29, 30

Dua puluh empat aturan belum pernah dijalankan dalam keadaan rusak. Aturan 23
dipilih lebih dulu karena ia menjaga **aturan paling keras PRD** ("JANGAN
pernah menampilkan visual yang mengklaim identitas saat engine RAGU") pada
permukaan terkecil di seluruh perangkat: complication, yang tidak punya baris
kedua.

Kenapa permukaan terkecil justru yang paling perlu dibuktikan.

Di layar app, penanda keraguan punya banyak kanal: badge teks "Ragu", lencana
tanda tanya (Aturan 32), warna yang hilang (Aturan 24). Di complication
`accessoryInline` **tidak ada satu pun dari itu** — slotnya satu baris teks di
sebelah jam, dan satu-satunya kanal yang tersisa adalah ikon
`presentedSymbolName`. Komentar di cabang itu menyatakannya sendiri:

    "Dulu cabang ini mengembalikan `Text(digest.headline)` saja, dan itu
     membuat satu-satunya keluarga yang tidak punya baris kedua juga jadi
     satu-satunya yang tidak punya penanda: nama kandidat `.uncertain`
     tampil persis seperti nama yang sudah terkunci."

Kalimat itu **klaim**. Terukur sebelum harness ini ada: barisnya dikembalikan
ke `AnyView(Text(digest.headline))` dan Aturan 23 memang merah — jadi
aturannya hidup. Yang belum pernah ada adalah **bukti tertulis yang
dieksekusi**: tidak satu pun keadaan di repo ini yang mewajibkannya merah,
dan `swift test` di Linux tidak bisa menolong karena ia hanya membangun
`Packages/`, sedangkan berkas ini hidup di `Apps/`.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                    gerbang hijau (kalau tidak, harness salah)

  1. ikon dibuang, inline        Cacat aslinya. Nama kandidat `.uncertain`
                                 tampil persis seperti nama yang terkunci,
                                 tanpa satu kanal pun yang tersisa.

  2. ikon dibuang, default       **Cabang yang berbeda**, dan itu disengaja.
                                 `default` menampung keluarga yang belum
                                 didesain (container, dan keluarga yang lahir
                                 di watchOS berikutnya) — persis cabang yang
                                 tidak pernah dirender oleh pengujian hari
                                 ini, dan karena itu paling mungkin rusak
                                 tanpa ada yang melihat.

  3. ikon diganti nama lain      Bentuk "ada ikon" yang **salah**: sebuah
                                 `Image(systemName:)` yang bukan
                                 `presentedSymbolName` tidak mengikuti
                                 keadaan engine, jadi ia ikon tetap —
                                 ragu dan terkunci tampil sama. Pemeriksaan
                                 yang hanya mencari kehadiran `Image` akan
                                 hijau di sini.

  4. `digest.headline` dihapus   Kontrol negatif untuk sisi **subjek**.
     dari cabang inline          Aturan ini hanya berlaku pada cabang yang
                                 menampilkan nama objek; cabang yang tidak
                                 menampilkannya bukan pelanggaran. Gerbang
                                 yang memerah di sini akan memaksa orang
                                 melonggarkannya, dan gerbang yang dilonggarkan
                                 tidak menjaga apa pun.

**Keadaan 1 dan 2 tidak bisa saling menggantikan.** Keduanya memakai baris
yang **byte-identik**, dan justru itu yang membuatnya layak dua keadaan
terpisah: mutasi yang memakai `replace` penuh akan mengubah keduanya sekaligus
dan tidak pernah membuktikan bahwa cabang `default` sendiri terbaca. Karena
itu jangkarnya **mencakup label cabangnya** (`case .accessoryInline:` /
`default:`) — bukan sekadar baris `AnyView(...)` yang muncul dua kali.

Kenapa `default` layak dijaga terpisah, bukan dianggap sama dengan inline.
`switch family` di Swift bersifat **tak lengkap**: keluarga widget yang
ditambahkan Apple di watchOS berikutnya jatuh ke `default`. Cabang itu karena
ini satu-satunya yang cakupannya **bertambah sendiri** seiring waktu tanpa
ada yang menyunting berkasnya.

Kenapa programnya diekstrak dari `swift-ui-lint.sh`, bukan ditulis ulang di
sini: menyalin aturannya membuat harness mengukur **salinan**, yang tetap
hijau walau aturan aslinya dilonggarkan. Yang diukur harus aturan yang CI
jalankan.

Yang TIDAK diklaim.
- Yang diukur **teks sumber Swift**, bukan piksel perangkat. Bahwa
  `presentedSymbolName(at:)` mengembalikan ikon yang benar untuk setiap
  keadaan dijaga uji Swift-nya (`ComplicationDigestTests`), bukan harness ini.
- Empat keadaan di sini menutup **satu** aturan dari 24 yang nirsaksi.
  Sisanya belum dikerjakan.
"""

from __future__ import annotations

import os
import re
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
WIDGET = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Complications",
                      "ComplicationWidget.swift")

RULE_HEADER = "== Aturan 23:"
CLEAN_MARK = "Bersih: nama objek di complication selalu tampil bersama ikon keadaan."

#: Baris ikon, **byte-identik** di kedua cabang. Ia tidak dipakai sendiri
#: sebagai jangkar karena kemunculannya 2x; yang dipakai adalah
#: `CASE_ANCHORS` di bawah, yang menyertakan label cabangnya.
ICON_LINE = ('AnyView(Text("\\(Image(systemName: digest.presentedSymbolName(at: Date()))) '
             '\\(digest.headline)"))')

#: Jangkar **bercabang**: label `case`-nya ikut, sehingga setiap mutasi
#: menyunting tepat satu cabang. Ini syarat, bukan gaya — jangkar yang muncul
#: dua kali berarti satu `replace` mengubah dua cabang sekaligus, dan keadaan
#: 1 akan "membuktikan" keadaan 2 tanpa pernah menyentuhnya.
#:
#: Labelnya **muncul dua kali di berkas** (133 dan 274), karena `fallback`
#: punya `switch family` sendiri yang tidak memuat `digest.headline`. Karena
#: itu pemotongannya dibatasi ke tubuh `content(for:)` — batas yang sama
#: dengan yang dipakai gerbang-gerbang lain di repo ini (`_function_body`) —
#: bukan sekadar `text.find` atas seluruh berkas.
CASE_ANCHORS = {
    "inline": ("        case .accessoryInline:\n",
               "    private func content(for digest: ComplicationDigest) -> AnyView {"),
    "default": ("        default:\n",
                "    private func content(for digest: ComplicationDigest) -> AnyView {"),
}

#: Baris tanpa ikon, dipakai sebagai pengganti pada mutasi penghapusan.
BARE_LINE = "AnyView(Text(digest.headline))"

#: Ikon yang **ada** tetapi bukan `presentedSymbolName`: ia tidak mengikuti
#: keadaan engine, jadi ragu dan terkunci tampil sama.
FIXED_ICON_LINE = ('AnyView(Text("\\(Image(systemName: \"moon.stars\")) '
                   '\\(digest.headline)"))')

SOURCES = (WIDGET,)

_originals = {}


def restore(*_):
    """Pulihkan sumber produksi — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(path, \"w\")`: belasan harness di
    `Tools/` memutasi berkas produksi yang sama, jadi penulisan biasa membuat
    pembaca bisa melihat berkas setengah jadi. Pemulihannya **diverifikasi** —
    kegagalan pemulihan bersifat diam dan lalu menyalahkan kode yang benar.
    """
    for path, content in _originals.items():
        if content is not None:
            mutasi_sumber.restore_verified(path, content)


def function_body(text: str) -> str | None:
    """Ambil tubuh `content(for:)` — satu-satunya `switch family` yang memuat
    `digest.headline`.

    Kenapa dibatasi ke fungsi: berkas ini punya **dua** `switch family`, dan
    yang kedua (`fallback`) menampilkan teks statis tanpa `digest.headline`
    — Aturan 23 memang benar mengabaikannya. Tanpa pembatas ini, mutasi bisa
    mendarat di `fallback`, yang tidak pernah menyalahi aturan ini, dan
    keadaannya akan melaporkan "MERAH" untuk suntingan yang tidak ada
    hubungannya.
    """
    head = CASE_ANCHORS["inline"][1]
    start = text.find(head)
    if start < 0:
        return None
    tail = text[start + len(head):]
    # Batas akhirnya deklarasi berikutnya pada indentasi **lebih rendah atau
    # sama** — penutup `}` fungsi. Tanpanya potongannya menjalar sampai EOF
    # dan ikut memuat `fallback` (switch kedua), sehingga penghitungan jangkar
    # di bawah melihat dua cabang dan menolak jalan atas kode yang benar.
    nxt = re.search(r"^    (?:private |public |internal |static |@)?"
                    r"(?:func|var|struct|enum|class|extension|init)\b",
                    tail, re.M)
    end = start + len(head) + (nxt.start() if nxt else len(tail))
    return text[start:end]


def scoped_replace(text: str, case_key: str, old: str, new: str) -> str | None:
    """Ganti `old` -> `new` **hanya di dalam tubuh cabang** `case_key`.

    Kenapa bukan `text.replace` biasa: baris ikon muncul dua kali dengan isi
    yang sama persis. Penggantian global akan menyunting kedua cabang, dan
    keadaan yang mengklaim menguji cabang `default` akan lolos karena
    kebetulan cabang inline ikut berubah.

    Batas tubuh cabangnya adalah label `case`/`default` berikutnya pada
    tingkat indentasi yang sama — sama dengan cara pembaca `red-lint.sh`
    memotong bagian, supaya keduanya membaca berkas dengan cara yang sama.
    """
    anchor, _head = CASE_ANCHORS[case_key]
    body = function_body(text)
    if body is None:
        return None
    # `offset` harus **indeks awal** badan fungsi, bukan `len(text)-len(body)`.
    # Rumus yang kedua hanya benar kalau badannya adalah ekor berkas; sejak
    # `function_body` dibatasi ke deklarasi berikutnya ia bukan ekor lagi,
    # dan selisih 8250 itu membuat hasil suntingan ditulis menimpa `fallback`
    # — mutasi mendarat di cabang yang salah sementara laporannya menyebut
    # nomor baris cabang yang benar.
    offset = text.find(CASE_ANCHORS["inline"][1])
    if offset < 0 or text[offset:offset + len(body)] != body:
        return None
    start = body.find(anchor)
    if start < 0:
        return None
    tail = body[start + len(anchor):]
    # Cari label **berikutnya** di `switch` yang sama, mulai persis setelah
    # `start`. Tanpa `start+` ini, `find("\n        default:")` bisa mendarat
    # di `default:` milik `switch` lain yang muncul **sebelum** cabang yang
    # dimutasi, menghasilkan irisan terbalik (end < start) dan mutasi mendarat
    # di tempat lain.
    rest = tail.find("\n        case ")
    if rest < 0:
        rest = tail.find("\n        default:")
    end = start + len(anchor) + (rest if rest >= 0 else len(tail))
    if end <= start + len(anchor):
        return None
    branch = body[start:end]
    if old not in branch:
        return None
    return text[:offset + start] + branch.replace(old, new, 1) + text[offset + end:]


def drop_headline(text: str, case_key: str) -> str | None:
    """Buang `digest.headline` dari tubuh cabang `case_key` (kontrol negatif)."""
    return scoped_replace(text, case_key, ICON_LINE,
                          'AnyView(Text("\\(Image(systemName: '
                          'digest.presentedSymbolName(at: Date())))"))')


STATES = [
    ("[baseline]", None, False, None),
    ("1. ikon keadaan dibuang dari cabang `accessoryInline`",
     ("inline", "drop"), True, "case .accessoryInline"),
    ("2. ikon keadaan dibuang dari cabang `default`",
     ("default", "drop"), True, "default"),
    ("3. ikon ada tapi bukan `presentedSymbolName` (inline)",
     ("inline", "fixed"), True, "case .accessoryInline"),
    ("4. kontrol negatif: cabang tidak menampilkan `headline`",
     ("inline", "noheadline"), False, None),
]


def apply_state(kind) -> bool:
    """Terapkan satu keadaan. False = jangkar tidak ditemukan."""
    case_key, what = kind
    base = _originals[WIDGET]
    if what == "drop":
        out = scoped_replace(base, case_key, ICON_LINE, BARE_LINE)
    elif what == "fixed":
        out = scoped_replace(base, case_key, ICON_LINE, FIXED_ICON_LINE)
    elif what == "noheadline":
        out = drop_headline(base, case_key)
    else:
        return False
    if out is None or out == base:
        return False
    mutasi_sumber.write_source(WIDGET, out)
    return True


def extract_rule23():
    """Ambil program Aturan 23 dari `swift-ui-lint.sh`.

    Kenapa diekstrak, bukan disalin: harness yang menyalin aturannya akan
    tetap hijau walau aturan aslinya dilonggarkan — persis kelas cacat yang
    ditutup `check-harness-terdaftar.py` (gerbang yang tidak pernah
    dieksekusi selalu hijau).

    **Kenapa dipotong pada heredoc-nya, bukan pada `if [ "$status" ...]`.**
    Pembatas yang dipakai harness Aturan 32/34 ada di bagian aturan itu
    sendiri; Aturan 23 menulis pemeriksanya dengan bentuk `if [ -n ... ]`
    yang lain, sehingga `find`-nya meleset dan yang diambil adalah aturan
    23 **sampai akhir berkas** (99 KB, 13 aturan). Probe lalu menjalankan
    aturan-aturan berikutnya dan melaporkan temuan mereka sebagai temuan
    Aturan 23.

    Bentuk yang diukur di sini persis yang dijalankan CI: blok `echo` judul
    + `python3 - <<'PY' … PY`. Keduanya dituntut ada, kalau tidak harness
    berhenti (exit 2) — bukan lapor hijau.
    """
    text = open(LINT, encoding="utf-8").read()
    header = 'echo "== Aturan 23:'
    start = text.find(header)
    if start < 0:
        return None
    end = text.find('echo "== Aturan 24:', start)
    if end < 0:
        return None
    return text[start:end]


def probe(program):
    """Jalankan Aturan 23 sendiri -> (merah?, detail).

    Yang diekstrak adalah **blok shell-nya utuh** (`python3 - <<'PY' … PY`),
    bukan hanya isi Python-nya, dan dijalankan lewat `bash -c`: baris
    `echo "Bersih: …"` ikut dieksekusi, jadi `CLEAN_MARK` yang dibaca probe
    ini lahir dari aturannya sendiri. Memotong hanya isi Python-nya
    menghilangkan baris itu dan membuat **baseline** ikut merah.
    """
    proc = subprocess.run(["bash", "-c", program], cwd=ROOT,
                          capture_output=True, text=True,
                          env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    return (CLEAN_MARK not in out), out.strip()


def main():
    mutasi_sumber.require_clean_sources(list(SOURCES))

    program = extract_rule23()
    if program is None or RULE_HEADER not in program:
        print("GERBANG: program Aturan 23 tidak ditemukan di swift-ui-lint.sh "
              "— harness tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)

    for path in SOURCES:
        with open(path, encoding="utf-8") as handle:
            _originals[path] = handle.read()

    # Jangkar wajib **unik di dalam tubuh fungsinya**: berkas ini punya dua
    # `switch family`, jadi penghitungan harus dilakukan setelah dipotong ke
    # `content(for:)` — bukan atas seluruh berkas. Kalau labelnya muncul dua
    # kali di situ, pemotongan tubuh cabangnya tidak bisa dipercaya dan
    # seluruh laporan di bawah mengukur cabang yang salah tanpa ada yang
    # memberitahu.
    body = function_body(_originals[WIDGET])
    if body is None:
        print("GERBANG: tubuh `content(for:)` tidak ditemukan — harness "
              "tidak boleh jalan.", file=sys.stderr)
        sys.exit(2)
    for key, (anchor, _head) in CASE_ANCHORS.items():
        count = body.count(anchor)
        if count != 1:
            print(f"GERBANG: label cabang '{key}' muncul {count}x di dalam "
                  "content(for:), harus tepat 1x — harness tidak boleh "
                  "jalan.", file=sys.stderr)
            sys.exit(2)
    # Baris ikon wajib ada **dua** kali di tubuh fungsi: itulah sebab
    # jangkarnya harus bercabang. Kalau kelak salah satu cabang diubah
    # sehingga barisnya tidak lagi identik, asumsi ini gugur dan harness
    # harus mengatakannya.
    icon_count = body.count(ICON_LINE)
    if icon_count != 2:
        print(f"GERBANG: baris ikon identik muncul {icon_count}x di dalam "
              "content(for:), harness ini mengasumsikan 2x — periksa ulang "
              "pemotongan cabangnya.", file=sys.stderr)
        sys.exit(2)

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, kind, must_fire, branch_name in STATES:
            # Mulai dari keadaan **bersih** tiap keadaan: menumpuk mutasi
            # membuat keadaan berikutnya mengukur campuran, dan kegagalan
            # pemulihan bersifat diam lalu menyalahkan kode yang benar.
            for path, content in _originals.items():
                mutasi_sumber.write_source(path, content)

            if kind is not None and not apply_state(kind):
                print(f"{label:56s} JANGKAR TIDAK DITEMUKAN")
                unexpected += 1
                continue

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:56s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            # Yang dituntut bukan sekadar «merah»: gerbang ini harus menyebut
            # **cabang yang dimutasi**. Tanpa tuntutan ini, keadaan 2 lolos
            # dengan laporan yang menunjuk `accessoryRectangular` — cabang
            # yang tidak disunting — persis kelas cacat yang dicari repo ini:
            # sebuah gerbang yang berbunyi karena sebab lain.
            ok = (fired == must_fire)
            if fired and branch_name is not None and branch_name not in detail:
                ok = False
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if fired:
                for line in detail.splitlines():
                    if line.strip().startswith("Apps/"):
                        print(f"       {line.strip()[:150]}")
            if fired and not must_fire:
                print(f"       (tidak diharapkan memerah) {detail[:160]}")
            if fired and branch_name is not None and branch_name not in detail:
                print(f"       (laporan tidak menyebut `{branch_name}`)")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
