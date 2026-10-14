#!/usr/bin/env python3
"""Buktikan Aturan 11 (specifier katalog cocok tipe dengan template kode) **berbunyi**.

Kenapa harness ini ada.

Aturan 11 menjaga satu-satunya cacat di repo ini yang **menjatuhkan app**, bukan
sekadar salah kata. Bentuk yang paling wajar ditulis penerjemah — menukar posisi
dua specifier supaya angkanya di depan — bisa membuat `%.1f` menerima sebuah
`String`. Di CoreFoundation itu **crash**; glibc memaafkannya, jadi `swift-test.sh`
hijau ratusan uji dan hanya CI macOS yang merah. Bentuk itu sudah pernah ada di
repo ini: `spokenError` mengirim `(String, Double, String)` dengan template
`"%@ %.1f %@"`, dan uji urutan menulis template pengganti `"%.1f %@ %@"`.

Kenapa ia tidak bisa ditangkap uji runtime di Linux, dan kenapa penjaganya
harus perbandingan **teks**: perbedaan perilaku `String(format:)` antara glibc
dan CoreFoundation adalah persis alasan uji biasa buta di sini. Yang dibandingkan
adalah urutan **tipe** specifier pada template bawaan kode (`id:`) versus setiap
nilai terjemahan untuk kunci yang sama. Posisi boleh berbeda — itu memang alasan
katalog ada — tetapi tipenya tidak.

Sampai siklus ini Aturan 11 tidak punya satu pun rekam jejak bahwa ia bisa keluar
merah, dan gerbang yang belum pernah diukur merah sama dengan gerbang yang tidak
mengukur apa pun.

Kenapa programnya **diekstrak** dari `swift-ui-lint.sh`, bukan disalin.

Harness yang menyalin aturannya mengukur **salinan**: ia tetap hijau walau aturan
aslinya dilonggarkan sampai tidak menggigit apa pun. Batas potongannya dinyatakan
dan diperiksa; kalau penanda yang dibutuhkan hilang, harness **berhenti** (exit 2)
alih-alih melaporkan hijau atas potongan yang tidak mengukur apa-apa.

Keadaan yang diuji, dan apa yang masing-masing buktikan.

  [baseline]                  katalog benar -> gerbang hijau. Tanpa ini, harness
                              yang selalu merah lulus seluruh keadaan di bawah.

  1. specifier **ditukar**     `"Ready — spread %.1f° from %lld references."`
     posisinya                menjadi `"… %lld° from %.1f …"`. Ini bentuk asli
                              yang Aturan 11 dibuat untuk menangkap, dan yang di
                              CoreFoundation berarti `%.1f` menerima `Int64`.

  2. **tipe** diganti          `"Spread %.1f° (max %.1f°)"` -> `%lld` di slot
                              pertama. Posisinya benar, tipenya salah — jadi
                              keadaan ini memisahkan "aturan membandingkan
                              **urutan tipe**" dari "aturan membandingkan teks
                              mentah". Aturan yang hanya membandingkan teks
                              mentah juga akan merah di sini, tetapi aturan yang
                              membandingkan urutan tipe dengan benar tetap harus
                              merah — dan itu yang diperiksa.

  3. specifier **hilang**      `"Need at least %lld references (%lld recorded)."`
                              menjadi tanpa specifier sama sekali. Terjemahan
                              yang menjatuhkan argumen berarti format string
                              menerima argumen yang tidak dipakainya.

  4. urutan **specifier sejenis** `"Offset %.1f°"` -> `"%.1f° Offset"`. Hanya
     dipindah, tipenya sama — gerbang harus **diam**. Ini kontrol negatif yang
     paling penting: ia membuktikan aturan tidak memerah hanya karena teks
     terjemahan **berbeda dari** template kode. Tanpa keadaan ini, aturan yang
     membandingkan string mentah akan lulus keadaan 1-3 dengan sempurna, dan
     setiap terjemahan yang sah akan dilaporkan sebagai cacat.

Yang TIDAK diklaim harness ini.

- Ia mengukur **teks** katalog dan sumber `PointingKit`, bukan `String(format:)`
  yang berjalan di CoreFoundation. Yang dibuktikan: aturan berbunyi pada specifier
  yang tipenya tidak cocok, dan diam pada urutan yang cuma berpindah.
- **Penyempitan yang aturan sendiri nyatakan, dan batasnya di sini:** perbandingan
  hanya berlaku untuk kunci yang punya template bawaan di `PointingKit` (`key:` +
  `id:`). Kunci yang specifier-nya hanya hidup di katalog — terukur, mis.
  `'%lld acuan tercatat'` dan `'Lokasi: %@'` — **tidak** diperiksa, karena tidak
  ada template kode untuk dibandingkan. Itu batas cakupan yang sengaja, bukan
  kelalaian; ia dinyatakan supaya tidak disangka tertutup.
- Ia memutasi berkas produksi, jadi ia tunduk pada `require_clean_sources`: ia
  **menolak jalan** di atas pohon yang sudah kotor. Penolakan itu benar, bukan
  kerusakan.

**Non-vakuositasnya diukur, bukan diklaim.** Dengan pendeteksi Aturan 11
dilumpuhkan di worktree terpisah — perbandingan `got != expected` diubah supaya
selalu cocok — harness ini merah **persis pada keadaan 1, 2, dan 3**, dan tetap
hijau pada keadaan 4.
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
CATALOG = os.path.join(ROOT, "Apps", "Shared", "Resources", "Localizable.xcstrings")

BEGIN = "# ── Aturan 11:"
END = "# ── Aturan 12:"

#: Tanda yang harus ada di dalam potongan. Kalau salah satu hilang, yang diekstrak
#: bukan aturan yang CI jalankan dan harness berhenti.
REQUIRED = ("== Aturan 11:",
            "Bersih: tipe specifier katalog cocok dengan template kode.",
            "status=1")

#: Jangkar di katalog. Masing-masing harus muncul **tepat sekali** — jangkar yang
#: muncul dua kali menyunting lebih banyak daripada yang dilaporkan.
A_READY = '"Ready — spread %.1f° from %lld references."'
A_SPREAD = '"Spread %.1f° (max %.1f°)"'
A_NEEDMORE = '"Need at least %lld references (%lld recorded)."'
A_OFFSET = '"Offset %.1f°"'

#: (label, jangkar, pengganti, harus_merah). `None` = tanpa suntikan.
STATES = [
    ("[baseline] katalog benar", None, None, False),

    # ── Cacat: tiga cara specifier bisa tidak cocok ───────────────────────
    ("1. specifier ditukar posisinya (%.1f <-> %lld)",
     A_READY,
     '"Ready — spread %lld° from %.1f references."',
     True),
    ("2. tipe specifier diganti (%.1f -> %lld)",
     A_SPREAD,
     '"Spread %lld° (max %.1f°)"',
     True),
    ("3. specifier hilang dari terjemahan",
     A_NEEDMORE,
     '"At least some references."',
     True),

    # ── Kontrol negatif: urutan berpindah, tipe sama ──────────────────────
    ("4. specifier sejenis cuma dipindah — kontrol negatif",
     A_OFFSET,
     '"%.1f° Offset"',
     False),
]

_original: str | None = None


def restore(*_):
    """Pulihkan katalog — juga saat dihentikan sinyal.

    Lewat `mutasi_sumber`, bukan `open(path, "w")`: kegagalan pemulihan bersifat
    diam, dan katalog yang tertinggal termutasi membuat setiap gerbang
    lokalisasi berikutnya berbohong.
    """
    if _original is not None:
        mutasi_sumber.restore_verified(CATALOG, _original)


def extract_rule11():
    """Ambil potongan program Aturan 11 dari `swift-ui-lint.sh`, atau `None`."""
    text = open(LINT, encoding="utf-8").read()
    start = text.find(BEGIN)
    end = text.find(END)
    if start < 0 or end <= start:
        return None
    return text[start:end]


def probe(program):
    """Jalankan Aturan 11 sendiri -> (merah?, detail)."""
    proc = subprocess.run(["bash", "-c", program], cwd=ROOT,
                          capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return None, (proc.stderr.strip().splitlines() or ["(tanpa galat)"])[-1]
    out = proc.stdout
    clean = "Bersih: tipe specifier katalog cocok dengan template kode." in out
    return (not clean), out.strip()


def main():
    mutasi_sumber.require_clean_sources([CATALOG])

    program = extract_rule11()
    if program is None:
        print("GERBANG: potongan Aturan 11 tidak ditemukan di swift-ui-lint.sh "
              f"(antara {BEGIN!r} dan {END!r}) — harness tidak boleh jalan.",
              file=sys.stderr)
        return 2
    missing = [mark for mark in REQUIRED if mark not in program]
    if missing:
        print("GERBANG: potongan Aturan 11 tidak memuat "
              + ", ".join(repr(m) for m in missing)
              + " — yang diekstrak bukan aturan yang CI jalankan, jadi harness "
                "ini tidak mengukur apa pun.", file=sys.stderr)
        return 2

    global _original
    _original = open(CATALOG, encoding="utf-8").read()

    for anchor in (A_READY, A_SPREAD, A_NEEDMORE, A_OFFSET):
        count = _original.count(anchor)
        if count != 1:
            print(f"GERBANG: jangkar katalog {anchor!r} muncul {count}x, harus "
                  "tepat 1x — harness tidak boleh jalan.", file=sys.stderr)
            return 2

    signal.signal(signal.SIGINT, lambda *a: (restore(), sys.exit(130)))
    signal.signal(signal.SIGTERM, lambda *a: (restore(), sys.exit(143)))

    unexpected = 0
    try:
        for label, anchor, replacement, must_fire in STATES:
            mutasi_sumber.write_source(CATALOG, _original)
            if anchor is not None:
                content = _original.replace(anchor, replacement, 1)
                if content == _original:
                    print(f"{label:56s} ANCHOR TIDAK DITEMUKAN")
                    unexpected += 1
                    continue
                mutasi_sumber.write_source(CATALOG, content)

            fired, detail = probe(program)
            if fired is None:
                print(f"{label:56s} PROBE GAGAL JALAN: {detail}")
                unexpected += 1
                continue

            # Yang dituntut bukan sekadar «merah»: aturan harus **menyebut kunci
            # yang disuntik**. Pesan yang menunjuk kunci lain berarti yang
            # berbunyi bukan cacat yang saya suntik, dan keadaan ini tidak
            # membuktikan apa pun tentangnya.
            ok = (fired == must_fire)
            if fired and "calibration." not in detail:
                ok = False
            if not ok:
                unexpected += 1
            print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
                  f"{'MERAH' if fired else 'hijau'}")
            if fired:
                for line in detail.splitlines():
                    if line.strip() and "kode [" in line:
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
