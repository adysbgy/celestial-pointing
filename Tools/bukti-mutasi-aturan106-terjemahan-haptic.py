#!/usr/bin/env python3
"""Buktikan Aturan 106 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 106 menjaga satu langkah dalam rantai haptic yang **tidak bisa dilihat
oleh compiler maupun oleh mata**: terjemahan `HapticPattern` → efek platform di
`Apps/`. Politik peristiwa→pola sudah dikunci `HapticPolicy` dan diuji di
Linux; yang tersisa di `Apps/` adalah dua `switch` tanpa keputusan — dan
ternyata di situ getaran "ragu" bisa kembali terasa persis seperti "berhasil"
hanya dengan satu baris.

Diukur pada salinan utuh pohon ini (proses baru, seluruh aturan UI lain
dijalankan atas `Apps/`) sebelum Aturan 106 ada:

    iPhone: .unsettled .rigid -> .medium      swift-ui-lint.sh LULUS (buta)
    jam:   .unsettled .retry  -> .success     swift-ui-lint.sh LULUS (buta)

Dua keadaan, nol yang berbunyi. Keduanya mengompilasi bersih, keduanya tidak
mengubah satu baris teks di layar — yang berubah hanya rasa getaran di tangan,
yaitu satu-satunya saluran yang tidak butuh mata saat jam diangkat.

Keadaan, karena satu mutasi hanya menutup satu jalan:

  1. **iPhone: `.unsettled` → `.medium`** — cacat intinya. Ragu jadi terasa
     identik dengan berhasil. Harus MERAH.
  2. **jam: `.unsettled` → `.success`** — cacat yang sama di platform lain.
     Harus MERAH (membuktikan gate membaca kedua berkas).
  3. **iPhone: `.tick` dibuang** — kelengkapan, bukan injektivitas: pola itu
     berhenti bergetar sama sekali. Harus MERAH.
  4. **iPhone: efek salah ketik `.sccess`** — efek yang tidak nyata harus
     ditolak, bukan diabaikan diam-diam. Harus MERAH.
  5. **jam: `.completed` → `.retry`** — arah sebaliknya dari keadaan 2:
     kali ini yang menabrak `.unsettled`. Harus MERAH.
  6. **iPhone: `switch pattern` dihapus** — terjemahannya hilang seluruhnya.
     Harus MERAH (fail-closed, bukan hijau atas berkas tanpa switch).
  7. **`HapticEngine.swift` dibuang** — subjek gerbang di jam hilang.
     Harus MERAH, bukan hijau atas berkas kosong.
  8. **Komentar menyebut kedua efek** — kontrol positif: dokumentasi yang
     benar harus tetap **HIJAU**. Gerbang yang merah atas komentar akan
     dimatikan orang.

Setiap keadaan menyunting berkas **sungguhan** lalu mengembalikannya, dan
pemulihannya diverifikasi byte-per-byte. Harness menolak berjalan di atas
sumber yang sudah kotor.
"""
from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WATCH = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "HapticEngine.swift")
PHONE = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                     "PhoneHapticEngine.swift")
GATE = os.path.join(ROOT, "Tools", "check-aturan106-terjemahan-haptic.py")

#: Baris terjemahan yang dimutasi.
IPHONE_UNSETTLED = (
    "            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()")
IPHONE_COMPLETED = (
    "            UIImpactFeedbackGenerator(style: .medium).impactOccurred()")
IPHONE_TICK = (
    "        case .tick:\n"
    "            UIImpactFeedbackGenerator(style: .light).impactOccurred()")
IPHONE_NOTIF = (
    "            UINotificationFeedbackGenerator()."
    "notificationOccurred(.warning)")
IPHONE_SWITCH = "    private func play(_ pattern: HapticPattern) {\n        switch pattern {"
WATCH_UNSETTLED = "        case .unsettled: return .retry"
WATCH_COMPLETED = "        case .completed: return .success"
IPHONE_KOMENTAR = (
    "    /// Terjemahan pola → efek UIKit. Tanpa keputusan: satu pola, satu efek.")


def jalankan() -> tuple[int, str]:
    hasil = subprocess.run([sys.executable, GATE], capture_output=True, text=True)
    return hasil.returncode, hasil.stdout + hasil.stderr


def baca(path: str) -> tuple[bytes, str]:
    mentah = open(path, "rb").read()
    return mentah, mentah.decode("utf-8")


def main() -> int:
    if not os.path.exists(GATE):
        print(f"FAIL gerbangnya tidak ada: {GATE}")
        return 1

    asli_watch, teks_watch = baca(WATCH)
    asli_phone, teks_phone = baca(PHONE)

    # Jangkar wajib unik dan hadir — jangkar basi berarti setiap keadaan
    # "lulus" tanpa menyunting apa pun.
    for nama, teks, jangkar in (
            ("iPhone .unsettled", teks_phone, IPHONE_UNSETTLED),
            ("iPhone .tick", teks_phone, IPHONE_TICK),
            ("jam .unsettled", teks_watch, WATCH_UNSETTLED),
            ("jam .completed", teks_watch, WATCH_COMPLETED)):
        if teks.count(jangkar) != 1:
            print(f"FAIL jangkar {nama} tidak unik/hilang ({teks.count(jangkar)} "
                  f"kecocokan)")
            print("     Harness ini bekerja pada teks; jangkar yang basi")
            print("     berarti ia tidak menyunting apa pun dan setiap")
            print("     keadaan akan «lulus» tanpa menguji apa pun.")
            return 1

    #: (nama, [(path, teks_mutasi)], harap)
    keadaan: list[tuple[str, list[tuple[str, str]], int]] = []

    # 1. Cacat intinya, di iPhone: ragu jadi terasa seperti berhasil.
    keadaan.append((
        "iPhone: .unsettled .rigid -> .medium (ragu = berhasil)",
        [(PHONE, teks_phone.replace(
            IPHONE_UNSETTLED,
            "            UIImpactFeedbackGenerator(style: .medium)"
            ".impactOccurred()"))],
        1))

    # 2. Cacat yang sama di jam — membuktikan gate membaca kedua berkas.
    keadaan.append((
        "jam: .unsettled .retry -> .success (ragu = berhasil)",
        [(WATCH, teks_watch.replace(
            WATCH_UNSETTLED, "        case .unsettled: return .success"))],
        1))

    # 3. Kelengkapan: pola yang berhenti bergetar.
    keadaan.append((
        "iPhone: case .tick dibuang (pola tidak bergetar)",
        [(PHONE, teks_phone.replace(IPHONE_TICK, ""))],
        1))

    # 4. Efek yang tidak nyata harus ditolak, bukan diabaikan.
    keadaan.append((
        "iPhone: gaya .sccess (efek tidak dikenal)",
        [(PHONE, teks_phone.replace(
            IPHONE_UNSETTLED,
            "            UIImpactFeedbackGenerator(style: .sccess)"
            ".impactOccurred()"))],
        1))

    # 5. Arah sebaliknya: yang menabrak kini .unsettled, bukan .completed.
    keadaan.append((
        "jam: .completed .success -> .retry (nabrak .unsettled)",
        [(WATCH, teks_watch.replace(
            WATCH_COMPLETED, "        case .completed: return .retry"))],
        1))

    # 6. Terjemahan hilang seluruhnya — fail-closed.
    keadaan.append((
        "iPhone: switch pattern dibuang (fail-closed)",
        [(PHONE, teks_phone.replace(
            IPHONE_SWITCH,
            "    private func play(_ pattern: HapticPattern) {\n"
            "        if pattern == .completed { }"))],
        1))

    # 7. Subjek gerbang di jam dibuang.
    keadaan.append((
        "jam: HapticEngine.swift dikosongkan (fail-closed)",
        [(WATCH, "")],
        1))

    # 8. Kontrol positif: komentar yang menyebut kedua efek tetap hijau.
    keadaan.append((
        "iPhone: kedua efek disebut di komentar (harus HIJAU)",
        [(PHONE, teks_phone.replace(
            IPHONE_KOMENTAR,
            IPHONE_KOMENTAR + "\n    ///\n    /// Catatan dokumentasi: `.completed` memakai"
            "\n    /// `.medium` dan `.unsettled` memakai `.rigid`."))],
        0))

    hasil: list[tuple[str, bool, str]] = []

    kode, keluaran = jalankan()
    if kode != 0:
        print("FAIL baseline sudah merah — harness ini menolak berjalan di atas")
        print("     sumber yang kotor. Perbaiki dulu, lalu jalankan ulang.")
        print()
        print(keluaran)
        return 1
    hasil.append(("[baseline] pohon apa adanya", True, f"exit={kode}"))

    for nama, suntingan, harap in keadaan:
        mentah = {path: open(path, "rb").read() for path, _ in suntingan}
        bersih = True
        for path, teks_baru in suntingan:
            if teks_baru == mentah[path].decode("utf-8"):
                hasil.append((nama, False, "mutasinya tidak mengubah berkas — "
                                           "keadaan ini tidak menguji apa pun"))
                bersih = False
                break
        if not bersih:
            continue
        try:
            for path, teks_baru in suntingan:
                open(path, "w", encoding="utf-8").write(teks_baru)
            kode, keluaran = jalankan()
        finally:
            for path, isi in mentah.items():
                open(path, "wb").write(isi)
        pulih = all(open(path, "rb").read() == mentah[path] for path, _ in suntingan)
        if not pulih:
            hasil.append((nama, False, "sumber produksi TIDAK pulih — periksa "
                                       "secara manual sebelum lanjut"))
            continue
        sebab = ""
        if kode != harap:
            sebab = " | " + " ; ".join(
                l.strip() for l in keluaran.splitlines()
                if l.startswith("FAIL"))[:300]
        hasil.append((nama, kode == harap, f"exit={kode} (harap {harap}){sebab}"))

    pulih = (open(WATCH, "rb").read() == asli_watch
             and open(PHONE, "rb").read() == asli_phone)
    hasil.append(("sumber produksi pulih byte-per-byte", pulih,
                  "identik" if pulih else "BERBEDA — pulihkan manual"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'OK  ' if lolos else 'FAIL'} {nama} — {detail}")

    print()
    if gagal:
        print(f"Aturan 106: {len(gagal)} dari {len(hasil)} keadaan tidak sesuai.")
        return 1
    print(f"Aturan 106: {len(hasil)} keadaan sesuai harapan — terjemahan "
          f"pola→efek tidak bisa menyatukan dua pola jadi satu rasa di Apps/ "
          f"tanpa gerbang merah, sementara efek yang disebut di komentar tetap "
          f"hijau.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
