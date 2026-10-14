#!/usr/bin/env python3
"""Buktikan Aturan 16 (kalimat aksesibilitas harus datang dari katalog) **berbunyi**.

Kenapa harness ini ada.

Aturan 16 menyapu satu kelas cacat yang **tidak terlihat oleh siapa pun**:
kalimat yang diucapkan VoiceOver ditulis langsung di `Apps/`, sementara teks
yang tampil di baris yang sama sudah lewat katalog. Komponennya karena itu
**terlihat benar** — pengguna yang mengganti bahasa perangkat membaca Bahasa
Inggris di layar dan mendengar Bahasa Indonesia di telinga, di komponen yang
sama. Tidak ada galat kompilasi, tidak ada *warning*, dan `swift test` di Linux
tidak bisa menolong: ia hanya membangun `Packages/`, sedangkan berkas ini hidup
di `Apps/`.

Cacatnya sudah pernah dibayar di repo ini. `linkAccessibilityLabel` dulu
merakit sendiri:

    var text = link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau"
    text += LinkStatusText.sendFailures(link.sendFailureCount)

dan baris yang **ditampilkan** tepat di atasnya sudah memakai
`TextLocalization.text(.pointingLinkConnected)` — kunci katalog, ada Bahasa
Inggrisnya. Jadi layarnya benar dan hanya kalimat yang didengar yang salah.

Yang membuat harness ini wajib: sampai siklus ini Aturan 16 **tidak punya satu
pun rekam jejak bahwa ia bisa keluar merah**. Gerbang yang belum pernah diukur
merah persis sama dengan gerbang yang tidak mengukur apa pun, dan yang
dipertaruhkan di sini bukan kerapian teks melainkan janji VoiceOver yang brief
nyatakan sebagai syarat ("umumkan saat state berubah").

Kenapa programnya **diekstrak** dari `swift-ui-lint.sh`, bukan disalin.

Harness yang menyalin aturannya mengukur **salinan**: ia tetap hijau walau
aturan aslinya dilonggarkan sampai tidak menggigit apa pun — kelas cacat yang
sama dengan gerbang yang tidak pernah dieksekusi. Yang diukur harus potongan
yang CI jalankan. Batas potongannya dinyatakan di bawah dan diperiksa, bukan
disangka: ia harus memuat judul `== Aturan 16:`, penanda bersihnya, dan
`status=1` — kalau salah satu hilang, harness **berhenti** (exit 2) alih-alih
melaporkan hijau atas potongan yang tidak mengukur apa-apa.

Keadaan yang diuji, dan apa yang masing-masing buktikan.

  [baseline]                     kode benar -> gerbang hijau
                                 (tanpa ini, harness yang selalu merah lulus
                                 seluruh keadaan di bawah)

  1. cacat asli                  `linkAccessibilityLabel` dirakit dari literal
                                 lagi, persis bentuk yang pernah ada di `main`.
                                 Ini keadaan yang **menentukan** apakah aturan
                                 benar-benar menutup cacatnya.

  2. kelas yang sama, var lain    `statusAccessibilityLabel` — membuktikan
                                 aturan memindai **setiap** variabel yang
                                 diumumkan, bukan hanya satu yang kebetulan
                                 punya bentuk itu.

  3. kelas yang sama, var ketiga  `detailAccessibilityLabel`. Bersama keadaan 2
                                 ini yang membuktikan cakupannya bukan
                                 kebetulan satu nama.

  4. literal di var **yang tidak    `kindLine` memuat kalimat, tetapi hasilnya
     diumumkan**                 tidak pernah diumumkan. Gerbang harus **diam**:
                                 yang diukur adalah "apakah yang didengar
                                 melewati katalog", bukan "apakah ada literal
                                 di repo". Kontrol negatif ini yang membuat
                                 keadaan 2 dan 3 berarti.

  5. literal **pengenal**, bukan    `"pointing.state.lock"` di dalam variabel
     kalimat                     yang diumumkan. Gerbang harus **diam**:
                                 pengenal dan nama aset bukan teks tampilan, dan
                                 gerbang yang memerah pada keduanya akan
                                 dimatikan orang saat ia berbunyi.

Keadaan 4 dan 5 bukan hiasan. Tanpa keduanya, aturan yang berbunyi pada
**setiap** literal akan lulus keadaan 1-3 dengan sempurna — dan itu gerbang
yang tidak bisa dipakai.

Yang TIDAK diklaim harness ini.

- Ia mengukur **teks** `Apps/`, bukan pengucapan VoiceOver di perangkat. Yang
  dibuktikan: aturan berbunyi pada kalimat literal di variabel yang diumumkan,
  dan diam pada literal yang bukan teks tampilan.
- Ia tidak membuktikan kalimat yang sudah berkunci **terjemahannya benar** —
  itu wilayah uji paritas katalog (Aturan 6/11).
- Keadaan 4 dan 5 adalah kontrol negatif yang tersedia di sini; keduanya
  mengukur **cakupan** aturan (apa yang tidak boleh dianggap temuan), bukan
  ketajaman pendeteksinya.

**Non-vakuositasnya diukur, bukan diklaim.** Dengan pendeteksi Aturan 16
dilumpuhkan di worktree terpisah — `A11Y_USE` diubah jadi pola yang tidak akan
pernah cocok, sehingga aturan tidak bisa lagi menemukan satu pun variabel yang
diumumkan — harness ini merah **persis pada keadaan 1, 2, dan 3**, dan tetap
hijau pada keadaan 4 dan 5. Itu tanda tangan yang benar: yang diukur memang
pendeteksi aturannya, dan kedua kontrol negatifnya tidak ikut bergantung pada
pendeteksi itu.
- Ia memutasi berkas produksi, jadi ia tunduk pada `require_clean_sources`:
  ia **menolak jalan** di atas pohon yang sudah kotor (dan itulah yang terjadi
  di pohon kerja yang memuat WIP siklus lain — penolakan itu benar, bukan
  kerusakan).
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

#: Batas potongan program Aturan 16 di dalam `swift-ui-lint.sh`.
BEGIN = "# ── Aturan 16:"
END = "# ── Aturan 17:"

#: Tanda yang harus ada di dalam potongan. Kalau salah satu hilang, yang
#: diekstrak bukan aturan yang CI jalankan dan harness berhenti.
REQUIRED = ("== Aturan 16:",
            "Bersih: kalimat aksesibilitas berasal dari katalog.",
            "status=1")

#: Jangkar di view. Semuanya harus muncul **tepat sekali**: jangkar yang muncul
#: dua kali menyunting lebih banyak daripada yang dilaporkan, dan harness yang
#: menyunting lebih banyak daripada yang dilaporkan adalah harness yang
#: mengukur keadaan yang tidak ia sebut.
ANCHORS = {
    "badan `statusAccessibilityLabel`":
        "        var parts = [RowSpeech.stateLine(state), engine.snapshot.guidanceText]",
    "badan `linkAccessibilityLabel`":
        "        LinkStatusText.linkSpeech(isReachable: link.isReachable,\n"
        "                                  sendFailureCount: link.sendFailureCount)",
    "badan `detailAccessibilityLabel`":
        "        var parts = [objectDisplayName]",
    "badan `kindLine`":
        "        var parts = [kindLabel]",
}

A_STATUS = ANCHORS["badan `statusAccessibilityLabel`"]
A_LINK = ANCHORS["badan `linkAccessibilityLabel`"]
A_DETAIL = ANCHORS["badan `detailAccessibilityLabel`"]
A_KINDLINE = ANCHORS["badan `kindLine`"]

#: Cacat asli, dikembalikan apa adanya — termasuk `text +=`, yang memaku urutan
#: kalimat di kode sehingga bahasa yang ingin meletakkan jumlah sebelum kata
#: "gagal" tidak bisa mengatakannya.
LINK_DEFECT = (
    '        var text = link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau"\n'
    "        text += LinkStatusText.sendFailures(link.sendFailureCount)\n"
    "        return text"
)

#: Bentuk yang sama, diringkas: satu literal di dalam variabel yang diumumkan.
STATUS_DEFECT = '        let note = "Menunggu arah yang stabil"\n' + A_STATUS
DETAIL_DEFECT = '        let note = "Objek belum terkunci"\n' + A_DETAIL

#: Kontrol negatif. Kalimat di variabel yang **tidak** diumumkan.
KINDLINE_NEGATIVE = '        let note = "Objek langit dalam"\n' + A_KINDLINE
#: Kontrol negatif. Pengenal, bukan kalimat, di variabel yang diumumkan.
IDENTIFIER_NEGATIVE = '        let key = "pointing.state.lock"\n' + A_STATUS

#: (label, suntikan, harus_merah). `None` = tanpa suntikan.
STATES = [
    ("[baseline] kode benar", None, False),
    ("1. cacat asli: `linkAccessibilityLabel` dirakit dari literal",
     [(A_LINK, LINK_DEFECT)], True),
    ("2. kelas yang sama di `statusAccessibilityLabel`",
     [(A_STATUS, STATUS_DEFECT)], True),
    ("3. kelas yang sama di `detailAccessibilityLabel`",
     [(A_DETAIL, DETAIL_DEFECT)], True),
    ("4. literal di `kindLine` (tidak diumumkan) — kontrol negatif",
     [(A_KINDLINE, KINDLINE_NEGATIVE)], False),
    ("5. pengenal di var yang diumumkan — kontrol negatif",
     [(A_STATUS, IDENTIFIER_NEGATIVE)], False),
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


def extract_rule16():
    """Ambil potongan program Aturan 16 dari `swift-ui-lint.sh`, atau `None`."""
    text = open(LINT, encoding="utf-8").read()
    start = text.find(BEGIN)
    end = text.find(END)
    if start < 0 or end <= start:
        return None
    return text[start:end]


def probe(program):
    """Jalankan Aturan 16 sendiri -> (merah?, detail)."""
    proc = subprocess.run(["bash", "-c", program], cwd=ROOT,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    return ("Bersih: kalimat aksesibilitas berasal dari katalog." not in out), out.strip()


def main():
    mutasi_sumber.require_clean_sources([VIEW])

    program = extract_rule16()
    if program is None:
        print("GERBANG: potongan Aturan 16 tidak ditemukan di swift-ui-lint.sh "
              f"(antara {BEGIN!r} dan {END!r}) — harness tidak boleh jalan.",
              file=sys.stderr)
        return 2
    missing = [mark for mark in REQUIRED if mark not in program]
    if missing:
        print("GERBANG: potongan Aturan 16 tidak memuat "
              + ", ".join(repr(m) for m in missing)
              + " — yang diekstrak bukan aturan yang CI jalankan, jadi "
                "harness ini tidak mengukur apa pun.", file=sys.stderr)
        return 2

    global _original
    _original = open(VIEW, encoding="utf-8").read()

    # Jangkar: kemunculannya diperiksa, bukan disangka. Jangkar yang hilang
    # berarti view sudah berubah dan harness ini akan melaporkan hijau atas
    # suntikan yang tidak pernah terjadi.
    for label, anchor in ANCHORS.items():
        count = _original.count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar {label} muncul {count}x, harus tepat 1x — "
                  "harness tidak boleh jalan.", file=sys.stderr)
            return 2

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, injection, must_fire in STATES:
            mutasi_sumber.write_source(VIEW, _original)
            if injection is not None:
                content = _original
                for old, new in injection:
                    content = content.replace(old, new, 1)
                mutasi_sumber.write_source(VIEW, content)

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:58s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            # Yang dituntut bukan sekadar «merah»: aturan harus **menyebut
            # berkas yang disuntik**. Pesan yang menunjuk berkas lain berarti
            # ada aturan/harness lain yang berbunyi, dan keadaan ini tidak
            # membuktikan apa pun tentang Aturan 16.
            named_view = os.path.relpath(VIEW) in detail
            ok = (fired == must_fire)
            if fired and not named_view:
                ok = False
            if not ok:
                unexpected += 1
            state = "MERAH" if fired else "hijau"
            print(f"{'OK  ' if ok else 'SALAH'} {label:58s} {state}")
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
