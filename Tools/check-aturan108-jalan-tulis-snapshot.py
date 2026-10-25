#!/usr/bin/env python3
"""Aturan 108: `publish(_:)` wajib tetap satu-satunya jalan tulis snapshot.

**Kenapa aturan ini ada, dan kenapa ia bukan tebakan.**

`Apps/Shared/PointingEngine.swift` mendokumentasikan satu choke point:

    // Karena itu semua penulisan snapshot **wajib** lewat sini. Kalau
    // `snapshot = ...` muncul lagi di berkas ini, itu bug.
    private func publish(_ value: PointingSnapshot) {
        snapshot = value
        lockArrival = arrivalGate.update(with: value)
        recordComplicationIfChanged()
        refreshSlewVerdict(at: Date())
    }

Empat penulisan berdampingan di satu fungsi, masing-masing menjawab layar yang
berbeda:

    snapshot = value                     kartu, panel detail, layar redup
    lockArrival = arrivalGate.update(...) tanda "baru mengunci" (animasi + ucapan)
    recordComplicationIfChanged()         complication di wajah jam
    refreshSlewVerdict(at:)               putusan keamanan GoTo

Tidak satu pun gerbang yang ada menjaga bentuk itu. Diukur pada salinan utuh
pohon ini (proses baru, `./swift-ui-lint.sh` sungguhan dijalankan atas `Apps/`),
masing-masing dibuang satu per satu:

    `lockArrival = ...` dihapus               → 107 gerbang LULUS
    `recordComplicationIfChanged()` dihapus    → 107 gerbang LULUS
    `refreshSlewVerdict(at: ...)` dihapus      → 107 gerbang LULUS
    `snapshot = value` dihapus                → 107 gerbang LULUS

Empat mutasi, nol yang berbunyi — dan keempatnya mengompilasi bersih. Yang
terjadi di layar bukan crash melainkan **keheningan**: layar tetap menampilkan
keadaan yang benar, hanya tanpa satu dari empat hal yang tidak punya teks.

Akibatnya bisa diukur di tangan pengguna:

  * `lockArrival` hilang → animasi `withAnimation` spring dan pengumuman
    VoiceOver "terkunci" tidak pernah menyala. Aturan 62/63 menjaga *apa* yang
    diucapkan dan *di mana* visualnya, bukan bahwa peristiwanya benar-benar
    sampai ke pemanggil.
  * `recordComplicationIfChanged()` hilang → complication terus menampilkan
    objek dari pandangan **sebelumnya** sampai ambang basi tiba. Berkasnya
    selalu benar; wajah jam yang tidak menyegar. Aturan 68 menjaga App Group,
    Aturan 52 menjaga kartu — keduanya diam atas pemicunya.
  * `refreshSlewVerdict(at:)` hilang → peringatan "jangan mengarahkan ke
    Matahari" membeku di nilai pertama. Komentar di atasnya menjelaskan kenapa
    ini bukan keterlambatan melainkan **peringatan yang salah**: layar berkata
    "aman" atas langit yang sudah bergerak.
  * `snapshot = value` hilang → tidak ada satu pun teks yang berubah, karena
    yang hilang adalah pembaruannya, bukan isinya.

Kenapa aturan ini tidak bisa dirangkum menjadi "jangan hapus baris". Yang dijaga
bukan keberadaan baris, melainkan bahwa **keempat** penulisan itu tetap berada di
**dalam tubuh `publish`**. Memindahkan salah satunya ke pemanggil memecah
choke point-nya secara senyap — enam jalur pemanggil menjadi enam kesempatan
untuk lupa, dan tidak ada teks di layar yang membantahnya. Itu alasan yang sama
yang tertulis di komentar `setConfidencePolicy`: pemanggil yang menyentuh
controller langsung membuat snapshot tidak ikut berubah.

**Bentuk yang diperiksa.**

Teks `publish(_ value: PointingSnapshot) { … }` di `Apps/` harus memuat
keempat penulisan itu, dan hanya itu yang dituntut. Penulisannya longgar
(`lockArrival =`, `refreshSlewVerdict(`, `recordComplicationIfChanged()`)
supaya ia tidak mematahkan pemformatan ulang yang tidak mengubah arti — gerbang
yang merah atas `clang-format` akan dimatikan orang.

Yang TIDAK diklaim.

Ini sapuan **teks**, bukan pemeriksa tipe: ia tidak membuktikan bahwa
`value` yang disimpan memang snapshot terbaru, dan `snapshot = nilaiLain`
lolos. Ia juga tidak memeriksa `PointingKit` sebagai pohon yang dikompilasi,
dan tidak menjaga urutan panggilan. Yang dijaga sempit dan konkret: **empat
penulisan yang sudah terukur buta tidak bisa dibuang lagi tanpa gerbang merah.**
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS = os.path.join(ROOT, "Apps")

#: Empat penulisan yang harus hidup di dalam tubuh `publish`.
#:
#: Dipisahkan menjadi **tanda tangan** (yang harus muncul) dan **teks larangan**
#: (yang mustahil muncul bersamaan dengan choke point yang utuh), karena
#: keduanya menjaga arah yang berbeda:
#:
#:   - tanda tangan: penulisan yang hilang harus MERAH.
#:   - larangan: pemecahan choke point ke pemanggil harus MERAH.
TANDATANGAN = (
    ("snapshot = value", "cuplikan tidak lagi ditulis di jalan tunggal — "
                         "semua layar membeku di nilai lama"),
    ("lockArrival = arrivalGate.update(with: value)",
     "tanda kedatangan kunci tidak lagi dicatat — animasi spring dan "
     "pengumuman VoiceOver 'terkunci' tidak pernah menyala"),
    ("recordComplicationIfChanged()",
     "complication tidak lagi disegarkan saat snapshot berubah — wajah jam "
     "tetap menampilkan objek dari pandangan sebelumnya"),
    ("refreshSlewVerdict(at: Date())",
     "putusan GoTo tidak lagi diperbarui bersama snapshot — peringatan "
     "keselamatan membeku di nilai pertama dan berkata 'aman' atas langit "
     "yang sudah bergerak"),
)

#: Bentuk yang berarti choke point-nya pecah: snapshot ditulis langsung, bukan
#: lewat `publish`. Komentar di `PointingEngine.swift` sendiri menyebut ini bug.
TULISAN_LANGSUNG = re.compile(r"^\s*snapshot\s*=\s*(?!value\b)")

#: Cari tubuh `publish(_ value: PointingSnapshot) {`.
#:
#: Tanda tangan dicocokkan longgar (`_ value:` saja, bukan tipe penuh) supaya
#: penulisan ulang yang tidak mengubah arti tidak memecahkan pembacaan — dan
#: supaya gerbang ini tetap mengukur kalau parameternya kelak diganti nama.
MULAI = re.compile(r"func\s+publish\s*\(\s*_\s*value\s*:\s*PointingSnapshot\s*\)\s*\{")


def tanpa_komentar(source: str) -> str:
    """Buang komentar `//` dan isi string supaya prosa tidak terbaca kode.

    Wajib, bukan kerapian: docstring berkas ini sendiri menyebut
    `snapshot = value` dan `refreshSlewVerdict(at: Date())` beberapa kali dalam
    kalimat penjelasan. Tanpa penyaringan, gerbangnya menuduh dokumentasi yang
    benar.
    """
    hasil = []
    for baris in source.split("\n"):
        buf, i, dalam, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam = False
            else:
                if ch == '"':
                    dalam = True
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


def berkas_swift() -> list[str]:
    jalur = []
    for root, _, files in os.walk(APPS):
        for f in files:
            if f.endswith(".swift"):
                jalur.append(os.path.join(root, f))
    return sorted(jalur)


def tubuh_publish(kode: str) -> tuple[int, int] | None:
    """Baris pertama & terakhir (1-based, inklusif) tubuh `publish`."""
    baris = kode.split("\n")
    for i, ln in enumerate(baris):
        if MULAI.search(ln):
            # Kurung kurawal diseimbangkan, mengabaikan yang di dalam string.
            kedalaman = 0
            for j in range(i, len(baris)):
                teks = re.sub(r'"(?:[^"\\]|\\.)*"', '""', baris[j])
                for ch in teks:
                    if ch == "{":
                        kedalaman += 1
                    elif ch == "}":
                        kedalaman -= 1
                        if kedalaman == 0:
                            return i + 1, j + 1
            return None
    return None


def main() -> int:
    berkas = berkas_swift()
    if not berkas:
        print("FAIL tidak ada berkas Swift di Apps/ — aturan ini tidak "
              "mengukur apa pun, jadi ini GAGAL, bukan lolos")
        return 1

    masalah: list[str] = []
    badan_terbaca: list[str] = []
    jumlah_panggil = 0

    for jalur in berkas:
        relatif = os.path.relpath(jalur, ROOT)
        try:
            mentah = open(jalur, encoding="utf-8").read()
        except OSError as exc:
            print(f"FAIL berkas tidak terbaca: {relatif}: {exc}")
            return 1
        kode = tanpa_komentar(mentah)
        baris = kode.split("\n")

        # 1. Jalur tulis langsung: `snapshot = …` di luar tubuh `publish`.
        rentang = tubuh_publish(kode)
        for n, ln in enumerate(baris, 1):
            if rentang and rentang[0] <= n <= rentang[1]:
                continue
            if TULISAN_LANGSUNG.match(ln):
                masalah.append(
                    f"  {relatif}:{n}  `{ln.strip()}` — snapshot ditulis "
                    f"langsung, bukan lewat `publish(_:)`. Komentar berkas itu "
                    f"sendiri menyebutnya bug: `lockArrival`, complication, dan "
                    f"putusan GoTo tidak ikut berubah, dan tidak ada satu pun "
                    f"teks di layar yang membantahnya.")

        # 2. Bentuk tubuh `publish` — hanya dari berkas yang memang punya.
        if rentang is None:
            continue

        awal, akhir = rentang
        badan = "\n".join(baris[awal - 1:akhir])
        badan_terbaca.append(relatif)

        for tanda, akibat in TANDATANGAN:
            if tanda not in badan:
                # Sebutkan baris tanda tangan supaya yang membaca tahu di mana
                # ia mencari, bukan hanya apa yang hilang.
                masalah.append(
                    f"  {relatif}:{awal}  tubuh `publish(_:)` tidak memuat "
                    f"`{tanda}` — {akibat}. Empat penulisan itu wajib berada di "
                    f"satu tempat: memindahkannya ke pemanggil membuat enam "
                    f"jalur pemanggil menjadi enam kesempatan untuk lupa.")

        # 3. Pemanggil wajib tetap memakai `publish(`, bukan menulis snapshot.
        #    Dihitung, bukan didaftar tangan: daftar tangan basi pada pemanggil
        #    ketujuh, dan pemanggil ketujuh justru yang paling mungkin lupa.
        for n, ln in enumerate(baris, 1):
            if rentang[0] <= n <= rentang[1]:
                continue
            if re.search(r"\bpublish\s*\(", ln):
                jumlah_panggil += 1

    if not badan_terbaca:
        print("FAIL tidak satu pun tubuh `publish(_:)` terbaca di Apps/ — "
              "aturan ini berhenti melihat, jadi ini GAGAL, bukan lolos")
        return 1

    if jumlah_panggil == 0:
        print("FAIL tidak satu pun pemanggil `publish(` terbaca di Apps/ — "
              "aturan ini berhenti melihat, jadi ini GAGAL, bukan lolos")
        return 1

    if masalah:
        print("\n".join(masalah))
        print()
        print(f"Aturan 108: {len(masalah)} pelanggaran pada jalan tulis "
              f"snapshot ({', '.join(badan_terbaca)}).")
        print("Kembalikan keempat penulisan ke dalam `publish(_:)` — choke "
              "point yang utuh adalah satu-satunya alasan layar, wajah jam, "
              "dan peringatan GoTo tidak bisa berbeda pendapat.")
        return 1

    print(f"ok   tubuh `publish(_:)` di {', '.join(badan_terbaca)} memuat "
          f"keempat penulisan, dan {jumlah_panggil} pemanggil memakainya")
    print()
    print(f"Aturan 108: {jumlah_panggil} pemanggil diperiksa — jalan tulis "
          f"snapshot tetap satu, dan keempat efek sampingnya tidak bisa "
          f"dibuang tanpa gerbang merah.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
