#!/usr/bin/env python3
"""Aturan 103: `lastLocked:` tidak boleh diisi `nil` — objek yang dipertahankan
tidak boleh dibuang diam-diam di `Apps/`.

Kenapa aturan ini ada, dan kenapa ia bukan tebakan.

`PointingSnapshot.displayedObject(lastLocked:)` punya tiga cabang:

    if let best = intent?.best { return best }
    return state == .searching ? lastLocked : nil

Cabang ketiga itulah satu-satunya tempat `lastLocked` menentukan hasil: saat
keadaan `.searching`, engine **sengaja** menyimpan objek dari pandangan
sebelumnya supaya panel detail tidak berkedip saat pergelangan bergerak
sedikit. `PointingEngine` menyalurkannya lewat empat properti yang dibaca
seluruh layar:

    displayedObject                 kartu, panel detail, layar redup
    isDisplayingStaleObject         peringatan "sisa pandangan sebelumnya"
    confirmsDisplayedIdentity       boleh-tidaknya gambar mengklaim identitas
    carriesUncertaintyMarker        penanda ragu yang menempel pada nama

Diukur, bukan disangka (`Tools/bukti-mutasi-aturan103-lastlocked.py`, salinan
utuh, proses baru, `./swift-ui-lint.sh` sungguhan dijalankan ulang):

    `lastLocked: lastLockedObject` -> `lastLocked: nil`        BUTA (exit 0)
    `displayedObject` -> `nil`                                 tertangkap
    `isDisplayingStaleObject` -> `false`                       tertangkap
    `confirmsDisplayedIdentity` -> `true` / `false`            tertangkap
    `carriesUncertaintyMarker` -> `true` / `false`             tertangkap

Enam dari tujuh mutasi berbunyi; **yang paling halus justru yang paling
sunyi**. Mutasi itu tidak menghapus satu baris pun, tidak mengubah tipe, dan
tetap mengompilasi: `lastLocked:` menerima `CelestialObject?`, jadi `nil`
masuk tanpa cast. Yang terjadi di layar bukan crash melainkan **panel yang
kosong** saat `.searching` — tidak ada teks yang membantahnya, karena tidak
ada teks yang tampil. Bentuknya persis yang dikejar repo ini: setiap gerbang
hijau, dan yang diukur bukan bagian yang bermasalah.

Kenapa Aturan 44 tidak menangkapnya. Aturan 44 menjaga **sumber objek yang
digambar** (`let object = <sumber>`) supaya gambar tidak berasal dari benda
selain yang tertulis di kartu. Ia membaca nama di kanan `=`. Di sini yang
salah bukan sumbernya, melainkan **argumen** yang diteruskan ke sana — dan
`nil` bukan sumber yang bisa dibandingkan dengan daftar putih.

Bentuk yang diperiksa.

Setiap pemanggilan yang menyebut label `lastLocked:` di `Apps/` wajib
meneruskan sesuatu yang **bukan** `nil`/`nil` literal dan bukan
`Optional.none`. Yang dibaca adalah teks di antara `lastLocked:` dan
pemisah argumen berikutnya (`)` atau `,`).

Kenapa daftar pemanggilnya **tidak** ditulis tangan: aturan ini menemukan
**lima** situs di `PointingEngine.swift`. Daftar tangan akan basi pada situs
keenam, dan situs keenam itu justru yang paling mungkin lupa — alasan yang
sama dengan Aturan 98/101/102. Jumlah situs juga diukur: nol situs terbaca
berarti pembacanya berhenti melihat, dan itu GAGAL, bukan lolos.

Yang TIDAK diklaim.

Ini sapuan **teks**, bukan pemeriksa tipe. Ia tidak membuktikan bahwa nilai
yang diteruskan benar-benar berisi objek yang tepat — `lastLocked:
beberapaObjekLain` lolos. Ia juga tidak menjangkau pemanggil yang menyalurkan
argumennya lewat variabel perantara (`lastLocked: retained`), dan tidak
memeriksa `PointingKit` sebagai pohon yang dikompilasi. Yang dijaga sempit
dan konkret: **jalur `nil` yang sudah terukur buta tidak bisa kembali** tanpa
gerbang merah.
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS = os.path.join(ROOT, "Apps")

#: Label yang dijaga. Semua fungsi yang menerimanya memperlakukan `nil`
#: sebagai "tidak ada objek yang dipertahankan".
LABEL = "lastLocked"

#: Nilai yang berarti "tidak ada objek" — dan karenanya membuang cabang
#: `.searching` dari `displayedObject`.
NILAI_KOSONG = ("nil", "Optional.none", ".none")

#: Argumen `lastLocked: …` sampai pemisah argumen berikutnya. `[^,)]` cukup:
#: tiap situs memakai satu ekspresi sederhana, dan bentuk bertingkat akan
#: terbaca sebagai argumen yang tidak kosong — arah yang aman (tidak menuduh).
ARG = re.compile(r"\b%s\s*:\s*([^,)\n]*)" % re.escape(LABEL))


def tanpa_komentar(source: str) -> str:
    """Buang komentar `//` dan isi string supaya prosa tidak terbaca kode.

    Wajib, bukan kerapian: docstring `PointingEngine.swift` dan berkas ini
    sendiri menyebut `lastLocked:` beberapa kali dalam kalimat penjelasan.
    Tanpa penyaringan, gerbangnya menuduh dokumentasi yang benar.
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


def main() -> int:
    berkas = berkas_swift()
    if not berkas:
        print("FAIL tidak ada berkas Swift di Apps/ — aturan ini tidak "
              "mengukur apa pun, jadi ini GAGAL, bukan lolos")
        return 1

    situs = 0
    masalah: list[str] = []

    for jalur in berkas:
        relatif = os.path.relpath(jalur, ROOT)
        try:
            mentah = open(jalur, encoding="utf-8").read()
        except OSError as exc:
            print(f"FAIL berkas tidak terbaca: {relatif}: {exc}")
            return 1
        kode = tanpa_komentar(mentah)
        for nomor, baris in enumerate(kode.split("\n"), 1):
            for m in ARG.finditer(baris):
                situs += 1
                nilai = m.group(1).strip()
                if nilai in NILAI_KOSONG:
                    masalah.append(
                        f"  {relatif}:{nomor}  `{LABEL}: {nilai}` — objek yang "
                        f"dipertahankan dibuang. Saat keadaan `.searching`, "
                        f"`displayedObject(lastLocked:)` mengembalikan objek "
                        f"ini; dengan `nil` panel detail dan layar redup "
                        f"menjadi kosong tanpa satu pun teks yang membantahnya. "
                        f"Teruskan `lastLockedObject`.")

    if situs == 0:
        print(f"FAIL tidak satu pun `{LABEL}:` terbaca di Apps/ — aturan ini "
              f"berhenti melihat, jadi ini GAGAL, bukan lolos")
        return 1

    if masalah:
        print("\n".join(masalah))
        print()
        print(f"Aturan 103: {len(masalah)} dari {situs} situs `{LABEL}:` "
              f"membuang objek yang dipertahankan.")
        print("Teruskan `lastLockedObject`, jangan `nil`: cabang `.searching` "
              "di `displayedObject` hanya hidup dari argumen itu.")
        return 1

    print(f"ok   {situs} situs `{LABEL}:` di Apps/ meneruskan objek yang "
          f"dipertahankan")
    print()
    print(f"Aturan 103: {situs} situs diperiksa — tidak ada yang membuang "
          f"objek yang dipertahankan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
