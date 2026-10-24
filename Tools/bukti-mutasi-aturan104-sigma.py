#!/usr/bin/env python3
"""Buktikan Aturan 104 berbunyi, bukan hijau saja.

Kenapa harness ini ada.

Aturan 104 menutup cacat yang **diukur buta** terhadap seluruh `swift-ui-lint.sh`
yang ada, pada **dua** jalur berbeda:

  jam (pembaruan berkala):
    link.sendIfDecisionChanged(
        state: update.snapshot,
        sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)

  iPhone (pencatatan sampel):
    trace.record(snapshot: update.snapshot,
                 sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)

Mengganti baris `sigmaDeg: ...` menjadi `sigmaDeg: 0.0` pada **salah satu**
jalur membuat seluruh lint lulus (exit 0, "SEMUA GERBANG UI LULUS") sementara
riwayat keyakinan merekam σ = 0 untuk keadaan itu — seolah perangkat selalu
yakin arahnya, berlawanan langsung dengan PRD v0.4 yang menegaskan akurasi
Watch adalah hipotesis.

Kenapa bentuknya lolos sebelum aturan ini ada: kedua pemanggilan menerima
`sigmaDeg: Double`, jadi `0.0` masuk tanpa cast, tanpa perubahan tipe, dan
tanpa satu baris pun yang terbaca sebagai salah. Lebih buruk, σ = 0 adalah
nilai yang *sah* di jalur yang sama (`pointingSigmaDeg ?? 0` di
`ConfidenceTrace.record(message:)`), sehingga tidak ada teks di layar yang
membantahnya — justru σ = 0 yang membungkam peringatan σ hilang.

Kenapa Aturan 86 tidak menutupnya. Aturan 86 menjaga balasan permintaan state
(`send(state:)`), bukan pembaruan berkala maupun pencatatan sampel. Keduanya
menyalurkan sigma, tapi ke jalur berbeda dengan ejaan berbeda, dan jangkar
Aturan 86 tidak menyentuh baris-baris ini.

Keadaan, karena satu mutasi hanya menutup satu jalan:

  1. **`sigmaDeg: ...pointingSigmaDeg` -> `sigmaDeg: 0.0`** di jam — buta
     aslinya, diukur: seluruh lint lulus (exit 0) sebelum Aturan 104 ada.
     Harus MERAH.
  2. **Sama di iPhone** — jalur kedua, cacat yang sama. Harus MERAH. (Diukur
     terpisah: mutasi iPhone saja juga lulus sebelum aturan ini ada.)
  3. **`sigmaDeg: ...pointingSigmaDeg` -> `sigmaDeg: 0`** — ejaan lain untuk
     nol. Harus merah: gerbang memeriksa makna, bukan satu bentuk literal.
  4. **`sigmaDeg: Double.zero`** — bentuk ketiga. Harus merah: alasan yang
     sama, makna bukan bentuk.
  5. **Argumen dibuang sepenuhnya** di jam (`state: update.snapshot)`) —
     bentuk yang paling mungkin muncul saat seseorang merapikan pemanggilan.
     Harus merah.
  6. **Siturnya dibuang** di jam — gerbang kehilangan sasarannya. Harus GAGAL
     (fail-closed), bukan hijau: gerbang yang tidak menemukan apa pun untuk
     diperiksa sudah berhenti mengukur.
  7. **Sigma benar, `state:` dibuang** — gerbang harus tetap hijau pada sigma
     yang benar (menguji bahwa ia tidak merah karena sebab lain) dan hanya
     memeriksa jalur sigma, bukan seluruh pemanggilan.
  8. **Kedua berkas dibuang jangkarnya** — kedua jalur berhenti diukur. Harus
     GAGAL, dan itu harus berbunyi pada berkas iPhone juga, bukan hanya jam.

Setiap keadaan menyunting berkas **sungguhan** lalu mengembalikannya, dan
pemulihannya diverifikasi byte-per-byte. Harness menolak berjalan di atas
sumber yang sudah kotor.
"""

from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JAM = os.path.join(
    ROOT,
    "Apps/PointAndKnowWatch/Sources/PointAndKnowWatchWatchApp.swift",
)
IPHONE = os.path.join(
    ROOT,
    "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift",
)
GATE = os.path.join(ROOT, "Tools/check-aturan104-sigma-diteruskan.py")

#: Jangkar situs yang diukur — baris sigma pada pembaruan berkala (jam).
JANGKAR_JAM = (
    "sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)")
#: Pemanggilan utuh di jam, dipakai keadaan yang membuang argumen.
PEMANGGILAN_JAM = (
    "            link.sendIfDecisionChanged(\n"
    "                state: update.snapshot,\n"
    "                sigmaDeg: engine.controller.resolver.confidencePolicy."
    "pointingSigmaDeg)")
#: Situs di iPhone: nama variabel lokalnya sama, barisnya berbeda.
JANGKAR_IPHONE = JANGKAR_JAM
PEMANGGILAN_IPHONE = (
    "            trace.record(snapshot: update.snapshot,\n"
    "                         sigmaDeg: engine.controller.resolver."
    "confidencePolicy.pointingSigmaDeg)")


def jalankan() -> tuple[int, str]:
    hasil = subprocess.run([sys.executable, GATE], capture_output=True, text=True)
    return hasil.returncode, hasil.stdout


def main() -> int:
    if not os.path.exists(GATE):
        print(f"FAIL gerbangnya tidak ada: {GATE}")
        return 1

    asli_jam = open(JAM, "rb").read()
    asli_iphone = open(IPHONE, "rb").read()
    teks_jam = asli_jam.decode("utf-8")
    teks_iphone = asli_iphone.decode("utf-8")

    for nama, teks, jangkar in (("jam", teks_jam, JANGKAR_JAM),
                                ("iPhone", teks_iphone, JANGKAR_IPHONE)):
        if jangkar not in teks:
            print(f"FAIL jangkar {nama} tidak ditemukan: {jangkar!r}")
            print("     Harness ini bekerja pada teks; jangkar yang basi")
            print("     berarti ia tidak menyunting apa pun dan setiap")
            print("     keadaan akan «lulus» tanpa menguji apa pun.")
            return 1
    if teks_jam.count(PEMANGGILAN_JAM) != 1:
        print(f"FAIL jangkar pemanggilan jam tidak unik: hitungan="
              f"{teks_jam.count(PEMANGGILAN_JAM)}")
        return 1
    if teks_iphone.count(PEMANGGILAN_IPHONE) != 1:
        print(f"FAIL jangkar pemanggilan iPhone tidak unik: hitungan="
              f"{teks_iphone.count(PEMANGGILAN_IPHONE)}")
        return 1

    #: Setiap keadaan: nama, berkas, mutasi, harap.
    keadaan: list[tuple[str, str, str, int]] = []

    # 1. Mutasi buta di jam: sigma yang berlaku diganti literal nol.
    keadaan.append((
        "jam: sigmaDeg -> 0.0 (mutasi buta yang diukur)",
        JAM,
        teks_jam.replace(JANGKAR_JAM, "sigmaDeg: 0.0)"),
        1))

    # 2. Jalur kedua, cacat yang sama.
    keadaan.append((
        "iPhone: sigmaDeg -> 0.0 (jalur kedua, cacat yang sama)",
        IPHONE,
        teks_iphone.replace(JANGKAR_IPHONE, "sigmaDeg: 0.0)"),
        1))

    # 3. Ejaan lain untuk nol.
    keadaan.append((
        "jam: sigmaDeg -> 0 (ejaan lain untuk nol)",
        JAM,
        teks_jam.replace(JANGKAR_JAM, "sigmaDeg: 0)"),
        1))

    # 4. Bentuk ketiga.
    keadaan.append((
        "iPhone: sigmaDeg -> Double.zero (bentuk ketiga)",
        IPHONE,
        teks_iphone.replace(JANGKAR_IPHONE, "sigmaDeg: Double.zero)"),
        1))

    # 5. Argumen sigma dibuang sepenuhnya di jam.
    keadaan.append((
        "jam: argumen sigmaDeg dibuang (pemanggilan dirapikan)",
        JAM,
        teks_jam.replace(PEMANGGILAN_JAM,
                         "            link.sendIfDecisionChanged(\n"
                         "                state: update.snapshot)"),
        1))

    # 6. Situs di jam dibuang -> gerbang kehilangan sasarannya. Harus GAGAL.
    keadaan.append((
        "jam: situs sigma dibuang (gerbang berhenti mengukur)",
        JAM,
        teks_jam.replace(
            JANGKAR_JAM,
            "sigmaDeg: engine.controller.resolver.confidencePolicy."
            "pointingSigmaDegLain)"),
        1))

    # 7. Sigma benar di jam, `state:` yang dibuang -> gerbang tetap HIJAU.
    keadaan.append((
        "jam: sigma benar, state: dibuang (gerbang tetap hijau)",
        JAM,
        teks_jam.replace(PEMANGGILAN_JAM,
                         "            link.sendIfDecisionChanged(\n"
                         "                sigmaDeg: engine.controller.resolver."
                         "confidencePolicy.pointingSigmaDeg)"),
        0))

    # 8. Kedua berkas dibuang jangkarnya -> kedua jalur berhenti diukur.
    keadaan.append((
        "kedua jalur dibuang (gerbang kehilangan seluruh sasaran)",
        JAM,
        teks_jam.replace(
            JANGKAR_JAM,
            "sigmaDeg: engine.controller.resolver.confidencePolicy."
            "pointingSigmaDegLain)"),
        1))

    hasil: list[tuple[str, bool, str]] = []

    kode, keluaran = jalankan()
    hasil.append(("[baseline] pohon apa adanya", kode == 0, f"exit={kode}"))
    baris = [l for l in keluaran.splitlines() if "site=" in l]
    hasil.append(("[baseline] dua jalur terbaca",
                  len(baris) == 2, "; ".join(baris) or "tidak ada"))

    for nama, path, mutasi, harap in keadaan:
        if nama.startswith("kedua jalur"):
            # Keadaan ini menyunting kedua berkas sekaligus.
            asli = open(path, "rb").read()
            asli2 = open(IPHONE, "rb").read()
            open(path, "w", encoding="utf-8").write(mutasi)
            open(IPHONE, "w", encoding="utf-8").write(
                teks_iphone.replace(
                    JANGKAR_IPHONE,
                    "sigmaDeg: engine.controller.resolver.confidencePolicy."
                    "pointingSigmaDegLain)"))
            try:
                kode, keluaran = jalankan()
            finally:
                open(path, "wb").write(asli)
                open(IPHONE, "wb").write(asli2)
            pulih = (open(path, "rb").read() == asli
                     and open(IPHONE, "rb").read() == asli2)
            hasil.append((nama, kode == harap and pulih,
                          f"exit={kode} (harap {harap})"))
            continue

        asli = open(path, "rb").read()
        if mutasi == (asli.decode("utf-8")):
            hasil.append((nama, False,
                          "mutasinya tidak mengubah berkas — keadaan ini tidak "
                          "menguji apa pun"))
            continue
        open(path, "w", encoding="utf-8").write(mutasi)
        try:
            kode, keluaran = jalankan()
        finally:
            open(path, "wb").write(asli)
        hasil.append((nama, kode == harap, f"exit={kode} (harap {harap})"))

    pulih = (open(JAM, "rb").read() == asli_jam
             and open(IPHONE, "rb").read() == asli_iphone)
    hasil.append(("sumber produksi pulih byte-per-byte", pulih,
                  "identik" if pulih else "BERBEDA — pulihkan manual"))

    gagal = [h for h in hasil if not h[1]]
    for nama, lolos, detail in hasil:
        print(f"{'OK  ' if lolos else 'FAIL'} {nama} — {detail}")

    print()
    if gagal:
        print(f"Aturan 104: {len(gagal)} dari {len(hasil)} keadaan tidak sesuai.")
        return 1
    print(f"Aturan 104: {len(hasil)} keadaan sesuai harapan — gerbang merah "
          f"tepat pada jalur sigma yang diukur buta (jam maupun iPhone), tetap "
          f"hijau bila sigma yang berlaku diteruskan, dan GAGAL bila berhenti "
          f"melihat.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
