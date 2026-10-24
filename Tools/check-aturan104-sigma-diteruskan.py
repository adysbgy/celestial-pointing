#!/usr/bin/env python3
"""Aturan 104: sigma yang dicatat/dikirim harus datang dari sigma yang berlaku.

Kenapa aturan ini ada — cacat yang **diukur buta** terhadap seluruh
`swift-ui-lint.sh` yang ada, pada **dua** jalur berbeda:

  Apps/PointAndKnowWatch/Sources/PointAndKnowWatchWatchApp.swift
    link.sendIfDecisionChanged(
        state: update.snapshot,
        sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)

  Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift
    trace.record(snapshot: update.snapshot,
                 sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)

Mengganti `sigmaDeg: ...pointingSigmaDeg` menjadi `sigmaDeg: 0.0` pada
**salah satu** jalur membuat seluruh aturan UI hijau (exit 0, "SEMUA GERBANG UI
LULUS"), sementara riwayat keyakinan merekam σ = 0 untuk keadaan itu — seolah
perangkat selalu tahu arahnya dengan pasti, padahal PRD v0.4 menegaskan akurasi
Watch adalah *hipotesis*, bukan kepastian.

Bentuk cacatnya halus dan itu alasannya butuh gerbang: kedua pemanggilan
menerima `sigmaDeg: Double`, jadi `0.0` masuk tanpa cast dan tanpa mengubah
satu baris pun yang lain. Tidak ada teks di layar yang membantahnya, karena
σ = 0 *memang* nilai yang sah di jalur yang sama (lihat
`ConfidenceTrace.record(message:)` yang melakukan `pointingSigmaDeg ?? 0`).
Persis bentuk yang dikejar repo ini: setiap gerbang hijau, dan yang diukur
bukan bagian yang bermasalah.

Kenapa Aturan 86 tidak menutupnya. Aturan 86 menjaga *balasan* permintaan
state (`send(state:)` tanpa sigma dilarang). Di sini bukan balasan: satu jalur
adalah **pembaruan berkala** di jam, satu lagi adalah **pencatatan sampel**
di iPhone. Keduanya menyalurkan sigma, tapi ke jalur berbeda dan dengan
ejaan yang berbeda, jadi jangkar 86 tidak menyentuh baris ini.

Jangkar yang dicari persis:

    sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)

Titik koma di ujung menyatukan dua kalimat berbeda — jangkar ini tidak akan
cocok dengan `sigmaMissing` maupun balasan `.stateRequestReply` (yang memang
tidak membawa sigma, sesuai Aturan 86).

Yang diperiksa adalah **makna**: argumen sigma harus dibaca dari
`confidencePolicy.pointingSigmaDeg`, bukan dari literal mana pun. Karena itu
baik `0.0`, `0`, maupun `Double.zero` ketiganya gagal — bukan karena bentuk
spesifik satu literal, tapi karena tidak lagi membaca sigma yang berlaku.
"""

from __future__ import annotations

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: Jalur yang wajib meneruskan sigma yang berlaku — jam dan iPhone.
SASARAN = (
    ("Apps/PointAndKnowWatch/Sources/PointAndKnowWatchWatchApp.swift",
     "pembaruan berkala di jam"),
    ("Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift",
     "pencatatan sampel di iPhone"),
)

# Akhiran titik koma supaya tidak menyamai baris lain.
JANGKAR = (
    "sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)")

# Bentuk yang **bukan** membaca sigma yang berlaku. Dipakai untuk membedakan
# "argumen ada tapi literal" dari "argumen membaca kebijakan": satu-satunya
# hal yang membuat mutasi buta lolos adalah literal yang sah-sah saja.
LITERAL = ("sigmaDeg: 0.0)", "sigmaDeg: 0)", "sigmaDeg: Double.zero)")


def main() -> int:
    masalah: list[str] = []
    situs_total = 0

    for path, peran in SASARAN:
        if not os.path.exists(path):
            masalah.append(f"{path}: berkas tidak ada — daftar SASARAN di "
                           f"aturan ini menyebutnya ({peran}), jadi ia "
                           f"dipindah atau dihapus tanpa memperbarui aturan.")
            continue

        teks = open(path, encoding="utf-8").read()
        hit = teks.count(JANGKAR)
        if hit == 0:
            masalah.append(
                f"{path}: tidak ada jangkar sigmaDeg yang berlaku ({peran}). "
                f"Gerbang ini bekerja pada teks; jangkar yang basi berarti ia "
                f"tidak menyunting apa pun dan akan hijau tanpa menguji apa pun.")
            continue

        for buruk in LITERAL:
            if buruk in teks:
                masalah.append(
                    f"{path}: `{buruk}` ditemukan. Argumen sigma harus dibaca "
                    f"dari confidencePolicy.pointingSigmaDeg, bukan dari "
                    f"literal: riwayat keyakinan akan merekamnya sebagai "
                    f"kepastian yang tidak pernah diukur.")

        situs_total += hit
        print(f"OK {path} — {peran} meneruskan sigma yang berlaku (site={hit}).")

    if masalah:
        print()
        for baris in masalah:
            print(baris)
        print(f"-> {len(masalah)} masalah.")
        return 1

    print(f"\nAturan 104: {situs_total} situs di {len(SASARAN)} jalur meneruskan "
          f"sigma yang berlaku — telemetri tidak bisa merekam jam sebagai selalu "
          f"yakin arahnya.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
