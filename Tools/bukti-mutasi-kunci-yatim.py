#!/usr/bin/env python3
"""Buktikan Aturan 19 (kunci katalog yatim) **berbunyi** — pada tiga bentuknya.

Kenapa harness ini ada.

Aturan 19 adalah satu-satunya gerbang yang menjaga **kebersihan katalog**, dan
sampai siklus ini ia tidak punya satu pun rekam jejak bahwa ia bisa merah. Ia
hijau setiap hari, dan hijau pada gerbang yang belum pernah diukur merah sama
dengan gerbang yang tidak mengukur apa pun. Yang lebih buruk: ia hijau **karena
cara ia mencari**, dan cara itu menyembunyikan tiga kunci mati yang sudah ada di
katalog ini.

Tiga bentuk kematian kunci, dan kenapa masing-masing tidak terlihat.

Versi lama mencari `kunci in source` — nama kunci yang muncul **di mana saja**,
tanpa tanda kutip, di seluruh `.swift`. Tiga kunci mati lolos dari tiga cara
yang berbeda:

  1. **`'%lld gagal'` — hidup dari teks bawaan kunci lain.** Ia tidak dipanggil
     siapa pun; yang ada hanyalah salinan teksnya di dalam `id:` milik
     `pointing.link.failures` (`id: "· %lld gagal"`). Pencarian substring
     menemukannya di situ dan mengira kunci itu dipakai. Bentuk ini juga tidak
     bisa ditutup paritas (`Aturan 6` hanya melihat kunci ber-namespace, dan
     `'%lld gagal'` tidak punya namespace) maupun uji kelengkapan `en`
     (entrinya memang punya `en`).

  2. **`'GoTo'` — hidup dari komentar yang mendokumentasikan penghapusannya
     sendiri.** Ia dulu judul baris `row("GoTo", verdict)`; baris itu diganti
     `SlewVerdictBanner` karena bobot visualnya salah. Komentar yang menjelaskan
     penggantian itu menulis `"GoTo"` **dengan tanda kutip**, jadi satu-satunya
     rujukan ke kunci itu adalah catatan bahwa ia tidak lagi dipakai.

  3. **`'sisa'` — hidup dari berkas uji yang justru menjaga keputusan untuk
     tidak memakainya.** Satu-satunya rujukan berkutip ke `"sisa"` ada di
     `ObjectSpeechTests.swift` pada `contains("sisa")` — sebuah penegasan atas
     teks **bawaan** kunci lain (`object.speech.staleShort`, `id: "sisa
     pandangan sebelumnya"`), dan tepat untuk menyatakan bahwa bentuk satu kata
     itu **sengaja tidak dipakai**. Uji itu karena itu menjaga keputusan yang
     membuat kunci `'sisa'` mati, sekaligus menjadi satu-satunya alasan kunci itu
     terlihat hidup.

Jadi aturannya diperketat pada dua sumbu, dan harness ini membuktikan
**keduanya** bergerigi: yang dicari adalah **literal berkutip** di dalam sumber
yang **komentarnya sudah dikosongkan** dan **berkas ujinya sudah dikeluarkan**.
Satu sumbu saja tidak cukup — keadaan 1, 2, dan 3 masing-masing hanya jatuh oleh
satu sumbu, dan itu sebabnya ketiganya ada.

Yang juga diperiksa: pengetatannya **tidak** membuat gerbang memerah pada kode
yang benar. Keadaan 5-7 adalah kontrol negatif yang paling penting; tanpa
mereka, aturan yang memerah pada setiap kunci yang dirujuk lewat `id:` akan
lulus keadaan 1-4 dengan sempurna, dan setiap `id:` yang sah akan dilaporkan
sebagai kunci yatim.

Kenapa programnya **diekstrak** dari `swift-ui-lint.sh`, bukan disalin.

Harness yang menyalin aturannya mengukur **salinan**: ia tetap hijau walau aturan
aslinya dilonggarkan sampai tidak menggigit apa pun. Batas potongannya
dinyatakan dan diperiksa; kalau penanda yang dibutuhkan hilang, harness
**berhenti** (exit 2) alih-alih melaporkan hijau atas potongan yang tidak
mengukur apa-apa.

Keadaan yang diuji, dan apa yang masing-masing buktikan.

  [baseline]                     katalog bersih -> gerbang hijau. Tanpa ini,
                                 harness yang selalu merah lulus semuanya.

  1. kunci yatim ditambahkan     bentuk paling dasar: satu kunci tanpa rujukan.
                                 Membuktikan gerbangnya berbunyi sama sekali.

  2. kunci yang hanya hidup      `"pointing.link.failures"` ditambahkan sebagai
     sebagai teks bawaan          kunci, dengan `id:` yang memuat nama kunci
     kunci lain                   yatim nomor 1. Inilah bentuk `'%lld gagal'`:
                                 rujukan tunggalnya adalah salinan teks di
                                 dalam `id:` milik kunci lain. Gerbang harus
                                 tetap merah -- dan **pada kunci yang benar**,
                                 bukan pada `pointing.link.failures` yang sah.

  3. kunci yang hanya disebut    kunci yatim nomor 1 disebut di dalam komentar
     di komentar                  berkas produksi. Ini bentuk `'GoTo'`. Kalau
                                 komentar tidak dikosongkan, gerbang menjadi
                                 **hijau** dan kunci mati itu lolos.

  4. kunci yang hanya dirujuk     kunci yatim nomor 1 dirujuk dari berkas **uji**
     dari berkas uji              (`Packages/PointingKit/Tests/`). Ini bentuk
                                 `'sisa'`. Kalau berkas uji ikut dipindai,
                                 gerbang menjadi hijau.

  5. kunci yang dirujuk lewat     kontrol negatif: kunci yatim nomor 1 diberi
     `id:`                        `id: "…"` di sebuah `LocalizedText` yang
                                 sah. Gerbang harus **diam** -- `id:` adalah
                                 rujukan berkutip yang sah, dan aturan yang
                                 memerah di sini akan melarang pola yang
                                 seluruh repo ini pakai.

  6. kunci yang dirujuk lewat     kontrol negatif kedua: dirujuk lewat `key:`
     `key:`                       pada deklarasi `LocalizedText` yang sah.

  7. kunci yang dirujuk lewat     kontrol negatif ketiga: dirujuk sebagai
     `Text("…")` di view         literal di dalam `Text(...)`. Ini jalur
                                 rujukan yang paling umum di `Apps/`.

Yang TIDAK diklaim harness ini.

- Ia mengukur **teks** katalog dan sumber Swift, bukan perilaku app Apple.
  Yang dibuktikan: gerbang berbunyi pada tiga bentuk kunci mati yang dinamai,
  dan diam pada tiga bentuk rujukan yang sah.
- **Keadaan 4 adalah keputusan cakupan, bukan kebenaran mutlak.** Ia menyatakan
  bahwa berkas uji **bukan** pemakai katalog. Kalau kelak ada kunci yang memang
  hanya boleh dipakai uji, aturan ini akan menuduhnya -- dan itu keputusan yang
  harus ditinjau ulang, bukan cacat yang harus ditambal dengan mengembalikan
  berkas uji ke cakupan (yang akan menghidupkan kembali bentuk `'sisa'`).
- Ia **tidak** membuktikan bahwa `TextLocalization` benar-benar membaca katalog
  saat perangkat berjalan. Itu wilayah `LocalizationBridge` dan uji paket.
- Ia memutasi berkas produksi (katalog + satu view + satu berkas uji), jadi ia
  tunduk pada `require_clean_sources`: ia **menolak jalan** di atas pohon yang
  sudah kotor. Penolakan itu benar, bukan kerusakan.

**Non-vakuositasnya diukur, bukan diklaim.** Dengan pengetatan dikembalikan ke
bentuk lama (`k in source`, komentar utuh, berkas uji ikut dipindai) di
`git worktree` terpisah, harness ini merah **persis pada keadaan 2, 3, dan 4**
dan tetap hijau pada keadaan 1, 5, 6, 7 — jadi tiap sumbu pengetatan memang
yang menutup satu bentuk, bukan efek samping keadaan lain.

Pakai:
    python3 Tools/bukti-mutasi-kunci-yatim.py    # 0 = semua sesuai harapan
"""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (bersih-dulu, tulis atomik, pulih terverifikasi)

LINT = os.path.join(ROOT, "swift-ui-lint.sh")
CATALOG = os.path.join(ROOT, "Apps", "Shared", "Resources", "Localizable.xcstrings")
VIEW = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources", "PointingView.swift")
TESTS = os.path.join(ROOT, "Packages", "PointingKit", "Tests", "PointingKitTests",
                     "ObjectSpeechTests.swift")
DECLS = os.path.join(ROOT, "Packages", "PointingKit", "Sources", "PointingKit",
                     "ObjectSpeech.swift")

BEGIN = "# ── Aturan 19:"
END = "# ── Aturan 20:"

#: Tanda yang harus ada di dalam potongan. Kalau salah satu hilang, yang
#: diekstrak bukan aturan yang CI jalankan dan harness berhenti.
REQUIRED = ("== Aturan 19:",
            "Bersih: setiap kunci katalog dirujuk oleh kode.",
            "status=1")

#: Kunci yang disuntik sebagai yatim. Sengaja **tidak** ber-namespace dan tidak
#: muncul di mana pun, supaya yang diuji benar-benar ketiadaan rujukan.
ORPHAN = "KunciYatimUjiSiklus"

#: Jangkar di katalog: kunci sah yang sudah ada, tempat yatim disisipkan.
A_LINK_FAILURES = '    "pointing.link.failures": {'

#: Jangkar di view & berkas uji.
A_VIEW_COMMENT = "                    // Putusan GoTo: mengapa teleskop boleh / tidak boleh"
A_TEST_ASSERT = '        XCTAssertTrue(note.lowercased().contains("sisa")' 

#: Jangkar di TextLocalization.swift: deklarasi sah tempat rujukan `key:`/`id:`
#: disisipkan.
A_DECL = '    static let objectSpeechStaleShort = LocalizedText('

HIJAU = "hijau"
MERAH = "merah"

#: Entri katalog yatim yang disisipkan. Bentuknya sama dengan entri asli
#: katalog ini (termasuk terjemahan `en`), supaya yang diuji benar-benar
#: ketiadaan **rujukan**, bukan entri yang ditolak karena bentuknya.
def orphan_entry(name=ORPHAN):
    return ('    "%s": {\n'
            '      "comment": "entri uji",\n'
            '      "localizations": {\n'
            '        "en": { "stringUnit": { "state": "translated",'
            ' "value": "x" } }\n'
            '      }\n'
            '    },\n' % name)


def inserted(anchor, name=ORPHAN):
    """Sisipkan entri yatim **sebelum** `anchor`, tanpa menyentuh `anchor`.

    Versi pertama mengganti `anchor` dengan entri yatim -- jadi yang dihapus
    adalah kunci sahnya sendiri, dan katalognya rusak dengan cara yang tidak
    ada hubungannya dengan yang mau diuji.
    """
    return orphan_entry(name) + anchor


# (label, {path: [(cari, ganti), ...]} atau None, harus_merah)
STATES = [
    ("[baseline] katalog bersih", None, False),

    # ── 1. Bentuk paling dasar: kunci tanpa rujukan sama sekali ───────────
    ("1. kunci yatim tanpa rujukan", {
        CATALOG: [(A_LINK_FAILURES, inserted(A_LINK_FAILURES))],
    }, True),

    # ── 2. Bentuk '%lld gagal': rujukan tunggalnya adalah `id:` kunci lain ─
    ("2. yatim hidup dari teks bawaan kunci lain", {
        CATALOG: [(A_LINK_FAILURES, inserted(A_LINK_FAILURES))],
        # `id:` memuat nama kunci yatim **sebagai potongan**, bukan sebagai
        # literal utuh. Ini persis bentuk `pointing.link.failures` /
        # `'%lld gagal'`: yang menemukan kunci yatim adalah pencarian
        # substring, sedangkan rujukan berkutip `"KunciYatimUjiSiklus"` tidak
        # ada di mana pun. Kalau `id:`-nya diisi literal utuh, keadaan ini
        # tidak bisa merah dan kehilangan seluruh maknanya.
        DECLS: [(A_DECL,
                 '    static let ujiPembawaYatim = LocalizedText(\n'
                 '        key: "uji.pembawa.yatim", id: "\u00b7 %s gagal")\n' % ORPHAN
                 + A_DECL)],
    }, True),

    # ── 3. Bentuk 'GoTo': hanya disebut di komentar berkas produksi ────────
    ("3. yatim hanya disebut di komentar", {
        CATALOG: [(A_LINK_FAILURES, inserted(A_LINK_FAILURES))],
        VIEW: [(A_VIEW_COMMENT,
                A_VIEW_COMMENT + ' [%s]' % ORPHAN)],
    }, True),

    # ── 4. Bentuk 'sisa': hanya dirujuk dari berkas uji ───────────────────
    ("4. yatim hanya dirujuk berkas uji", {
        CATALOG: [(A_LINK_FAILURES, inserted(A_LINK_FAILURES))],
        TESTS: [(A_TEST_ASSERT,
                 '        _ = "%s"\n' % ORPHAN + A_TEST_ASSERT)],
    }, True),

    # ── Kontrol negatif: tiga jalur rujukan yang sah ──────────────────────
    ("5. kontrol: dirujuk lewat `id:`", {
        CATALOG: [(A_LINK_FAILURES, inserted(A_LINK_FAILURES))],
        DECLS: [(A_DECL,
                 '    static let ujiRujukan = LocalizedText(\n'
                 '        key: "uji.rujukan", id: "%s")\n' % ORPHAN + A_DECL)],
    }, False),

    ("6. kontrol: dirujuk lewat `key:`", {
        CATALOG: [(A_LINK_FAILURES, inserted(A_LINK_FAILURES))],
        DECLS: [(A_DECL,
                 '    static let ujiRujukan2 = LocalizedText(\n'
                 '        key: "%s", id: "uji")\n' % ORPHAN + A_DECL)],
    }, False),

    ("7. kontrol: dirujuk lewat Text(\"\u2026\") di view", {
        CATALOG: [(A_LINK_FAILURES, inserted(A_LINK_FAILURES))],
        VIEW: [(A_VIEW_COMMENT,
                A_VIEW_COMMENT + '\n                    _ = Text("%s")' % ORPHAN)],
    }, False),
]

#: Semua berkas yang dimutasi harness ini — diperiksa bersih sebelum jalan.
TOUCHED = [CATALOG, VIEW, TESTS, DECLS]


def extract_rule19():
    """Ambil potongan program Aturan 19 dari `swift-ui-lint.sh`, atau `None`."""
    text = open(LINT, encoding="utf-8").read()
    start = text.find(BEGIN)
    end = text.find(END)
    if start < 0 or end <= start:
        return None
    return text[start:end]


def probe(program):
    """Jalankan Aturan 19 sendiri -> (merah?, detail).

    Potongan yang diekstrak berhenti **sebelum** `exit` akhir `swift-ui-lint.sh`,
    jadi kode keluarnya 0 bahkan saat aturannya menemukan kunci yatim. Yang
    menentukan adalah penanda bersihnya, bukan kode keluar -- dan kode keluar
    selain 0/1 tetap dilaporkan sebagai probe yang gagal jalan.
    """
    proc = subprocess.run(["bash", "-c", program], cwd=ROOT,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    clean = "Bersih: setiap kunci katalog dirujuk oleh kode." in out
    return (not clean), out.strip()


def main():
    mutasi_sumber.require_clean_sources(TOUCHED)

    program = extract_rule19()
    if program is None:
        print("GERBANG: potongan Aturan 19 tidak ditemukan di swift-ui-lint.sh "
              f"(antara {BEGIN!r} dan {END!r}) — harness tidak boleh jalan.",
              file=sys.stderr)
        return 2
    missing = [mark for mark in REQUIRED if mark not in program]
    if missing:
        print("GERBANG: potongan Aturan 19 tidak memuat "
              + ", ".join(repr(m) for m in missing)
              + " — yang diekstrak bukan aturan yang CI jalankan, jadi harness "
                "ini tidak mengukur apa pun.", file=sys.stderr)
        return 2

    originals = {path: open(path, encoding="utf-8").read() for path in TOUCHED}

    # Setiap jangkar harus muncul **tepat sekali**: jangkar yang muncul dua kali
    # menyunting lebih banyak daripada yang dilaporkan.
    anchors = {
        CATALOG: [A_LINK_FAILURES],
        VIEW: [A_VIEW_COMMENT],
        TESTS: [A_TEST_ASSERT],
        DECLS: [A_DECL],
    }
    for path, items in anchors.items():
        for anchor in items:
            count = originals[path].count(anchor)
            if count != 1:
                print(f"GERBANG: jangkar di {os.path.relpath(path)} muncul "
                      f"{count}x, harus tepat 1x — harness tidak boleh jalan.",
                      file=sys.stderr)
                return 2

    def restore_all():
        for path, original in originals.items():
            mutasi_sumber.restore_verified(path, original)

    signal.signal(signal.SIGINT, lambda *a: (restore_all(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore_all(), sys.exit(143)))

    unexpected = 0
    try:
        for label, edits, must_fire in STATES:
            restore_all()
            if edits is not None:
                for path, replacements in edits.items():
                    content = originals[path]
                    for find, replace in replacements:
                        hits = content.count(find)
                        if hits != 1:
                            print(f"{label:52s} JANGKAR TIDAK UNIK ({hits}x)")
                            unexpected += 1
                            break
                        content = content.replace(find, replace, 1)
                    else:
                        mutasi_sumber.write_source(path, content)
                        continue
                    break

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:52s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            # Yang dituntut bukan sekadar «merah»: kalau yang berbunyi adalah
            # kunci **lain** (mis. `pointing.link.failures` yang sah), maka yang
            # ditangkap bukan cacat yang disuntik.
            ok = (fired == must_fire)
            if fired and ORPHAN not in detail:
                ok = False
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:52s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if fired:
                for line in detail.splitlines():
                    if ORPHAN in line or "kunci yang tidak dirujuk" in line:
                        print(f"       {line.strip()[:120]}")
    finally:
        restore_all()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(STATES)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
