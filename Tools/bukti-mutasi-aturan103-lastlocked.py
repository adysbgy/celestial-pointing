#!/usr/bin/env python3
"""Buktikan Aturan 103 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 103 menutup cacat yang **diukur buta** terhadap seluruh `swift-ui-lint.sh`
yang ada: `PointingEngine.displayedObject` menyalurkan `lastLockedObject` ke
`PointingSnapshot.displayedObject(lastLocked:)`, dan mengganti argumen itu
menjadi `nil` membuat seluruh lint lulus (exit 0, "SEMUA GERBANG UI LULUS")
sementara panel detail dan layar redup menjadi **kosong** saat keadaan
`.searching` — karena cabang `.searching` di `displayedObject` hanya hidup
dari argumen itu.

Bentuk cacatnya halus dan itu alasannya butuh gerbang: `lastLocked:` menerima
`CelestialObject?`, jadi `nil` masuk tanpa cast dan tanpa mengubah satu baris
pun yang lain. Tidak ada teks di layar yang membantahnya, karena tidak ada
teks yang tampil.

Kenapa Aturan 42 tidak menutupnya. Aturan 42 menjaga **badan** permukaan
bukan-Bool (`displayedObject -> lastLockedObject`), yaitu saat seluruh badan
diganti. Yang salah di sini bukan badannya, melainkan **argumen** yang
diteruskan ke badan itu — dan `nil` bukan badan yang bisa dibandingkan dengan
jalur sah mana pun.

Keadaan, karena satu mutasi hanya menutup satu jalan:

  1. **`lastLocked: lastLockedObject` -> `lastLocked: nil`** — buta aslinya.
     Ini harus merah. Diukur: seluruh `swift-ui-lint.sh` lulus (exit 0) pada
     mutasi ini sebelum Aturan 103 ada.
  2. **`Optional.none`** alih-alih `nil` — bentuk yang sama dengan ejaan
     berbeda. Harus merah: gerbang memeriksa **makna** "tidak ada objek",
     bukan satu kata kunci.
  3. **Tanpa spasi** (`lastLocked:nil`) — bentuk yang paling mungkin muncul
     saat seseorang merapikan argumen. Harus merah.
  4. **Kelima situs dibuang sekaligus** — gerbang kehilangan seluruh sasaran
     ukurnya. Harus GAGAL (fail-closed), bukan hijau: gerbang yang tidak
     menemukan apa pun untuk diperiksa sudah berhenti mengukur.
  5. **Satu situs dibuang, empat tetap** — gerbang harus **tetap hijau** pada
     empat yang tersisa (ini menguji bahwa ia tidak merah karena sebab lain),
     dan jumlah situsnya turun menjadi empat.

Setiap keadaan menyunting berkas **sungguhan** lalu mengembalikannya, dan
pemulihannya diverifikasi byte-per-byte. Harness menolak berjalan di atas
sumber yang sudah kotor.
"""

from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ROOT, "Apps/Shared/PointingEngine.swift")
GATE = os.path.join(ROOT, "Tools/check-aturan103-lastlocked-tidak-dibuang.py")

#: Jangkar situs yang diukur — satu per properti yang menyalurkannya.
SITUS = (
    "        snapshot.displayedObject(lastLocked: lastLockedObject)",
    "        snapshot.isDisplayingStaleObject(lastLocked: lastLockedObject)",
    "        snapshot.confirmsIdentity(lastLocked: lastLockedObject)",
    "        snapshot.carriesUncertaintyMarker(lastLocked: lastLockedObject)",
)
#: Situs kelima: digest komplikasi, satu baris dengan argumen lain di kanan.
SITUS_DIGEST = ("        let digest = ComplicationDigest(snapshot: snapshot, "
                "lastLocked: lastLockedObject)")


def jalankan() -> tuple[int, str]:
    hasil = subprocess.run([sys.executable, GATE], capture_output=True, text=True)
    return hasil.returncode, hasil.stdout


def main() -> int:
    if not os.path.exists(GATE):
        print(f"FAIL gerbangnya tidak ada: {GATE}")
        return 1

    asli = open(ENGINE, "rb").read()
    teks = asli.decode("utf-8")

    for jangkar in SITUS + (SITUS_DIGEST,):
        if jangkar not in teks:
            print(f"FAIL jangkar tidak ditemukan: {jangkar!r}")
            print("     Harness ini bekerja pada teks; jangkar yang basi")
            print("     berarti ia tidak menyunting apa pun dan setiap")
            print("     keadaan akan «lulus» tanpa menguji apa pun.")
            return 1

    keadaan: list[tuple[str, str, int]] = []

    # 1. Mutasi buta: argumen dibuang. Harus MERAH.
    keadaan.append((
        "lastLocked: lastLockedObject -> nil (mutasi buta yang diukur)",
        teks.replace(SITUS[0],
                     "        snapshot.displayedObject(lastLocked: nil)"),
        1))

    # 2. Ejaan lain untuk "tidak ada objek".
    keadaan.append((
        "lastLocked: lastLockedObject -> Optional.none",
        teks.replace(SITUS[0],
                     "        snapshot.displayedObject(lastLocked: Optional.none)"),
        1))

    # 3. Tanpa spasi sesudah titik dua.
    keadaan.append((
        "lastLocked:nil tanpa spasi",
        teks.replace(SITUS[0],
                     "        snapshot.displayedObject(lastLocked:nil)"),
        1))

    # 4. Kelima situs dibuang sekaligus -> gerbang kehilangan sasarannya.
    #    Harus GAGAL (fail-closed), bukan hijau.
    teks_kosong = teks
    for i, jangkar in enumerate(SITUS):
        teks_kosong = teks_kosong.replace(
            jangkar, jangkar.replace("lastLocked: lastLockedObject", "arg: 0"))
    teks_kosong = teks_kosong.replace(
        SITUS_DIGEST,
        "        let digest = ComplicationDigest(snapshot: snapshot, arg: 0)")
    keadaan.append((
        "kelima situs dibuang (gerbang berhenti mengukur)",
        teks_kosong,
        1))

    # 5. Satu situs dibuang, empat tetap -> tetap hijau, situs turun ke empat.
    keadaan.append((
        "satu situs dibuang, empat tetap (gerbang tetap hijau)",
        teks.replace(SITUS_DIGEST,
                     "        let digest = ComplicationDigest(snapshot: snapshot, arg: 0)"),
        0))

    hasil: list[tuple[str, bool, str]] = []

    kode, keluaran = jalankan()
    hasil.append(("[baseline] pohon apa adanya", kode == 0, f"exit={kode}"))
    hasil.append(("[baseline] lima situs terbaca",
                  "5 situs" in keluaran, keluaran.strip().splitlines()[0]
                  if keluaran.strip() else "tidak ada keluaran"))

    for nama, mutasi, harap in keadaan:
        if mutasi == teks:
            hasil.append((nama, False,
                          "mutasinya tidak mengubah berkas — keadaan ini tidak "
                          "menguji apa pun"))
            continue
        open(ENGINE, "w", encoding="utf-8").write(mutasi)
        try:
            kode, keluaran = jalankan()
        finally:
            open(ENGINE, "wb").write(asli)
        hasil.append((nama, kode == harap, f"exit={kode} (harap {harap})"))

    pulih = open(ENGINE, "rb").read() == asli
    hasil.append(("sumber produksi pulih byte-per-byte", pulih,
                  "identik" if pulih else "BERBEDA — pulihkan manual"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'OK  ' if lolos else 'FAIL'} {nama} — {detail}")

    print()
    if gagal:
        print(f"Aturan 103: {len(gagal)} dari {len(hasil)} keadaan tidak sesuai.")
        return 1
    print(f"Aturan 103: {len(hasil)} keadaan sesuai harapan — gerbang merah "
          f"tepat pada jalur `nil` yang diukur buta, tetap hijau bila argumen "
          f"objek dipertahankan, dan GAGAL bila berhenti melihat.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
