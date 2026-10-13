#!/usr/bin/env python3
"""Buktikan gerbang "ciri planet bertahan di mode malam" **berbunyi**.

Kenapa harness ini ada.

Gerbang baru selalu hijau pada hari ia ditulis — itu bukan bukti apa pun.
Yang harus dibuktikan adalah bahwa ia **bisa merah**, merah pada keadaan yang
memang salah, dan bahwa ia menangkap kelas yang **tidak** ditangkap gerbang
yang sudah ada.

Kelas cacat yang ditutupnya.

`check_features_survive_the_watch_size` mengukur kelima ciri pengenal planet
pada ukuran yang benar-benar tampil (38 pt) — tetapi hanya di mode siang.
Terukur dari sumber: dari lima gerbang ciri planet, hanya
`check_jupiter_spot_reads_on_the_watch` yang pernah merender mode malam. Empat
sisanya — cincin Saturnus, kutub Mars, kawah Merkurius, kabut Venus — **nol
kali**.

Mode malam bukan mode pinggiran di produk ini: `NightVisual` memetakan setiap
warna ke kanal merah saja, jadi satu-satunya pembeda yang tersisa adalah
terang. Ciri yang berhenti digambar di sana hilang tanpa satu pun gerbang
berbunyi.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                      gerbang hijau (kalau tidak, harness salah)

  1. peta warna malam diratakan   Cacat aslinya: seluruh terang malam dijadikan
     (satu terang untuk semua)    satu angka, sehingga tidak ada beda terang
                                  yang tersisa untuk menggambar ciri apa pun.
                                  Terukur: kawah Merkurius dan kabut Venus
                                  menjadi **0 piksel** — cirinya tidak tergambar
                                  sama sekali, sementara bola planetnya tetap
                                  ada. Empat dari lima ciri merah.

  2. lantai malam dinaikkan       Kontrol **arah berlawanan**: mode malam yang
     (ciri tenggelam ke latar)   dinaikkan sampai ciri tenggelam ke latar
                                  sekitarnya juga harus merah. Tanpa ini,
                                  gerbangnya bisa lulus dengan membuat mode
                                  malam sangat terang — kebalikan dari tujuan
                                  produknya (rhodopsin). Terukur 5 merah.

  3. gerbang ukuran jam (siang)   **Bukti bahwa gerbang ini tidak mubazir.**
     dijalankan pada cacat yang  Pada keadaan yang sama, gerbang siang yang
     sama                        sudah ada tetap **0 merah**. Kalau keadaan ini
                                  hijau, gerbang baru hanya menambah entri hijau.

  4. hanya bayangan yang          **Buta yang dinyatakan, bukan disembunyikan.**
     diratakan                   Meratakan hanya bayangan tidak menggeser jejak
                                  ciri sama sekali (terukur 0 merah), karena yang
                                  dihitung adalah perbedaan terhadap bola
                                  berpalet yang sama. Keadaan ini mengunci
                                  batas itu: gerbang ini tidak mengklaim
                                  menangkap cacat tersebut.

Mutasi dijalankan **di dalam proses** (`render-visuals.py` dimuat sebagai
modul oleh `check-visuals.py`), bukan dengan menyunting berkas di disk:
harness ini tidak menulis apa pun ke pohon kerja, jadi ia tidak bisa
meninggalkan sumber yang termutasi bila dihentikan di tengah jalan.

Batasnya jujur: yang diukur adalah jumlah piksel jejak ciri, bukan kekuatan
kontrasnya. Mengubah warna ciri sampai sama dengan piringannya tidak
menggeser angka ini sama sekali (terukur `kutub Mars 126 -> 126`). Itu
dinyatakan juga di docstring gerbangnya.
"""

import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_check_visuals():
    spec = importlib.util.spec_from_file_location(
        "check_visuals", os.path.join(ROOT, "Tools", "check-visuals.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def red_names(check, *args):
    """Nama pemeriksaan yang **merah** pada keadaan sekarang."""
    results = []
    check(results, *args)
    return [r for r in results if not r.ok]


def main():
    C = load_check_visuals()
    R = C.R

    day_check = C.check_features_survive_the_watch_size
    night_check = C.check_features_survive_the_watch_size_in_night_mode

    # Nilai asli, dipulihkan di akhir — dan `finally` memastikan itu terjadi
    # walau ada pemeriksaan yang gagal.
    original = {
        "night_surface": R.night_surface,
        "night_shadow": R.night_shadow,
        "NIGHT_FLOOR_BRIGHTNESS": R.NIGHT_FLOOR_BRIGHTNESS,
    }

    def restore():
        R.night_surface = original["night_surface"]
        R.night_shadow = original["night_shadow"]
        R.NIGHT_FLOOR_BRIGHTNESS = original["NIGHT_FLOOR_BRIGHTNESS"]

    states = []

    def add(label, setup, expect_night, expect_day=0, note=""):
        states.append((label, setup, expect_night, expect_day, note))

    # ── Keadaan ──────────────────────────────────────────────────────────
    def baseline():
        pass

    def flat_surface():
        """Seluruh terang malam dijadikan satu angka."""
        R.night_surface = lambda day: (0.55, 0.0, 0.0)

    def flat_shadow():
        """Hanya bayangan yang diratakan — permukaan tetap benar."""
        R.night_shadow = lambda day: (0.15, 0.0, 0.0)

    def floor_raised():
        """Lantai malam dinaikkan sampai ciri tenggelam ke latar."""
        R.NIGHT_FLOOR_BRIGHTNESS = 0.70

    def both_flat():
        flat_surface()
        flat_shadow()

    # `expect_night=None` berarti "harus merah", tanpa mematok berapa banyak:
    # yang penting gerbangnya berbunyi, bukan jumlah persisnya.
    add("[baseline]", baseline, 0, 0)
    add("1. peta warna malam diratakan (semua terang sama)", flat_surface, 4, 0)
    add("2. lantai malam dinaikkan (ciri tenggelam ke latar)", floor_raised, None, 0)
    add("3. gerbang siang pada cacat yang SAMA (bukti tak mubazir)", both_flat, None, 0)
    # Buta yang dinyatakan, bukan disembunyikan. Meratakan **hanya** bayangan
    # tidak menggeser jejak ciri sama sekali (terukur 0 merah), karena yang
    # menghitung piksel adalah perbedaan terhadap bola berpalet yang sama —
    # dan bayangan tidak mengubah bentuk cirinya. Gerbang ini karena itu
    # **tidak** mengklaim menangkap cacat itu; yang menangkapnya adalah
    # pemeriksaan kontras malam di tempat lain.
    add("4. hanya bayangan malam yang diratakan (BUTA — dinyatakan)", flat_shadow, 0, 0)

    unexpected = 0
    try:
        for label, setup, expect_night, expect_day, note in states:
            restore()
            setup()

            night_red = red_names(night_check)
            day_red = red_names(day_check)

            ok = True
            if expect_night is None:
                if not night_red:
                    ok = False
            elif len(night_red) != expect_night:
                ok = False
            if len(day_red) != expect_day:
                ok = False
            # Pemeriksaan yang merah tanpa kalimat tidak mengukur apa pun.
            if any(not r.detail.strip() for r in night_red):
                ok = False
            if not ok:
                unexpected += 1

            print(f"{'OK  ' if ok else 'SALAH'} {label:56s} "
                  f"{len(night_red)} merah (malam) | gerbang siang {len(day_red)} merah")
            for r in night_red:
                print(f"       {r.name[:88]}")
                print(f"       {r.detail[:120]}")
    finally:
        restore()

    print()
    if unexpected:
        print(f"{unexpected} keadaan tidak sesuai harapan")
        sys.exit(1)
    print(f"{len(states)} keadaan, 0 tidak sesuai harapan")


if __name__ == "__main__":
    main()
