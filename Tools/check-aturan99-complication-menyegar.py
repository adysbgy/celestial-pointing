#!/usr/bin/env python3
"""Aturan 99: complication yang membaca digest basi wajib menjadwalkan penyegaran.

Kenapa gerbang ini ada.

Lapisan basi di `ComplicationDigest` dibangun selama beberapa siklus dan
seluruhnya diuji di Linux: `isStale(at:)`, `confirmsIdentityNow(at:)`,
`sublineContent(at:)`, `presentedSymbolName(at:)`. Semuanya menerima `now`
sebagai parameter, dan itulah yang membuatnya terlihat benar — seolah
complication memang dievaluasi ulang seiring waktu.

Ia tidak. `ComplicationProvider.getTimeline` memakai

    Timeline(entries: [entry], policy: .never)

dan `.never` berarti watchOS **tidak pernah** meminta entri baru kecuali app
memanggil `reloadAllTimelines()`. App hanya memanggilnya saat tanda tangan
snapshot berubah (`PointingEngine.recordComplicationIfChanged`). Jadi begitu
pergelangan berhenti bergerak — tepat kasus yang membuat cuplikan basi —
tidak ada tulisan baru, tidak ada reload, dan tidak ada render baru. `Date()`
di dalam view dievaluasi sekali, pada detik digest ditulis, ketika umurnya
nol.

Akibatnya seluruh lapisan basi itu jalur mati: 90 menit kemudian pergelangan
masih menampilkan centang hijau dan nama objek, sementara app di layar yang
sama sudah memberi tahu bahwa itu sisa pandangan lama. Satu-satunya perbedaan
adalah tidak ada yang pernah meminta complication menggambar ulang.

Yang dijaga gerbang ini adalah **bentuk yang membuatnya mati**: sebuah
timeline provider yang membaca `ComplicationDigest` tetapi memakai
`policy: .never` tanpa jalur `.after(...)`. Keduanya harus ada bersama;
`nextRefreshDate(after:)` sendirian tidak pernah dipanggil, dan `.never`
sendirian membekukan penandanya.

Kenapa bukan uji di PointingKit. WidgetKit tidak ada di Linux, jadi
`ComplicationProvider` tidak bisa dikompilasi — apalagi dipanggil — di sini.
Keputusan *kapan* menyegar sudah dipindah ke model dan diuji
(`ComplicationRefreshScheduleTests`). Yang tersisa adalah pertanyaan bentuk:
apakah view-nya benar-benar memakai keputusan itu. Itu hanya bisa dibaca dari
sumbernya.

Kenapa bukan Aturan 9. Aturan 9 menuntut **ada** pemanggil
`reloadAllTimelines` di suatu tempat di `Apps/`. Syarat itu terpenuhi, dan
justru itulah yang menutupi cacat ini: reload memang ada, tetapi hanya
dipicu perubahan tanda tangan — dan cuplikan yang menua tidak mengubah tanda
tangan apa pun. Aturan 9 hijau pada kode yang membeku.
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: Berkas yang boleh memuat `ComplicationDigest` dan timeline WidgetKit.
APPS = "Apps"

#: Fungsi penyedia timeline yang menyusun `Timeline(...)`.
TIMELINE_CALL = re.compile(r"\bTimeline\s*\(\s*entries\s*:")
#: Kebijakan yang membekukan complication sampai ada reload dari luar.
NEVER_POLICY = re.compile(r"policy\s*:\s*\.never\b")
#: Kebijakan yang menyegar sendiri, beserta **nama** argumennya.
AFTER_POLICY = re.compile(r"policy\s*:\s*\.after\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)")
#: Model yang punya lapisan basi — pemicu aturan ini.
STALENESS_MODEL = re.compile(r"\bComplicationDigest\b")
#: Aksesor jadwal yang wajib menjadi **sumber** argumen `.after(...)`.
SCHEDULE_ACCESSOR = r"\bnextRefreshDate\s*\(\s*after\s*:"


def bound_from_schedule(code: str, name: str) -> bool:
    """Apakah `name` diikat dari `nextRefreshDate(after:)`?

    **Kenapa bukan sekadar "apakah `.after(` ada".** `.after(now)`,
    `.after(Date().addingTimeInterval(60))`, dan `.after(refresh ?? .distantFuture)`
    semuanya memakai `.after` dan semuanya lolos sapuan yang hanya mencari
    nama API. Dua yang pertama menyegar pada waktu yang tidak berhubungan
    dengan umur cuplikan (yang satu bahkan menyegar terus-menerus — loop
    bangun yang menghabiskan baterai), dan yang ketiga mengikat jadwal ke
    cabang `nil` sehingga digest segar pun ikut dibekukan.

    Yang membuat jadwal itu benar adalah **asal nilainya**: tanggal yang
    dikembalikan model, yang diuji di Linux. Jadi yang diperiksa adalah
    ikatannya, bukan keberadaan pemanggilannya.
    """
    # `let refresh = ... nextRefreshDate(after: ...)` — boleh multi-baris.
    pattern = (r"\blet\s+" + re.escape(name) + r"\s*(?::[^=\n]+)?=\s*"
               r"[^\n]*?" + SCHEDULE_ACCESSOR)
    return re.search(pattern, code, re.S) is not None


def strip_comments(text: str) -> str:
    """Buang komentar `//` dan `/* */` supaya dokumen tidak dihitung kode.

    Proyek ini mendokumentasikan API-nya panjang lebar — termasuk
    `policy: .never` di docstring yang menjelaskan **kenapa** ia dulu dipakai.
    Sapuan yang tidak membuang komentar akan memerah pada dokumentasi yang
    benar, dan gerbang yang memerah pada kode benar akan dilonggarkan orang.
    """
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    out = []
    for line in text.split("\n"):
        # `//` di dalam string literal tidak mungkin memuat `policy:` di repo
        # ini; membuang dari kemunculan pertama sudah cukup dan tetap aman.
        out.append(line.split("//", 1)[0])
    return "\n".join(out)


def swift_files(root: str):
    for base, dirs, files in os.walk(os.path.join(root, APPS)):
        dirs[:] = [d for d in dirs if d not in (".build", ".swiftpm")]
        for name in sorted(files):
            if name.endswith(".swift"):
                yield os.path.join(base, name)


def main() -> int:
    if not os.path.isdir(os.path.join(ROOT, APPS)):
        print("PERINGATAN: direktori Apps/ tidak ada.")
        print("Aturan 99 DILEWATI, bukan lulus.")
        return 1

    diperiksa = 0
    pelanggaran = []
    tanpa_aksesor = []

    for path in swift_files(ROOT):
        rel = os.path.relpath(path, ROOT)
        code = strip_comments(open(path, encoding="utf-8").read())

        if not TIMELINE_CALL.search(code):
            continue
        # Hanya provider yang membaca model berlapis-basi yang terkena.
        if not STALENESS_MODEL.search(code):
            continue

        diperiksa += 1
        memakai_never = bool(NEVER_POLICY.search(code))
        memakai_jadwal = False
        memakai_after_tak_terikat = False
        for name in AFTER_POLICY.findall(code):
            if bound_from_schedule(code, name):
                memakai_jadwal = True
            else:
                memakai_after_tak_terikat = True

        if memakai_never and not memakai_jadwal:
            pelanggaran.append(rel)
        elif memakai_after_tak_terikat:
            # `.after(<nama>)` yang namanya **bukan** berasal dari
            # `nextRefreshDate(after:)` — jadwal yang tidak berhubungan
            # dengan umur cuplikan. Lihat `bound_from_schedule`.
            tanpa_aksesor.append(rel)

    if diperiksa == 0:
        print("FAIL tidak ada timeline WidgetKit yang membaca ComplicationDigest.")
        print("     Aturan ini tidak mengukur apa pun, dan complication yang")
        print("     membeku akan lolos tanpa satu pun gerbang berbunyi.")
        return 1

    if pelanggaran:
        print("Timeline complication memakai `policy: .never` tanpa jalur `.after(...)`:")
        for rel in pelanggaran:
            print(f"  {rel}")
        print("-> `policy: .never` berarti watchOS tidak pernah meminta entri baru")
        print("   kecuali app memanggil reloadAllTimelines(), dan app hanya")
        print("   memanggilnya saat tanda tangan snapshot berubah. Cuplikan yang")
        print("   menua tidak mengubah tanda tangan apa pun, jadi penanda basi")
        print("   tidak akan pernah muncul. Pakai")
        print("   `Timeline(entries:policy: .after(digest.nextRefreshDate(after: now)))`")
        print("   dan jatuh ke `.never` hanya bila jadwalnya `nil`.")
        return 1

    if tanpa_aksesor:
        print("Timeline complication menyegar, tetapi bukan dari umur cuplikan:")
        for rel in tanpa_aksesor:
            print(f"  {rel}")
        print("-> Jadwalnya harus berasal dari `nextRefreshDate(after:)` (model,")
        print("   teruji di Linux), bukan angka yang ditulis di view. Angka di")
        print("   view tidak bisa diuji dan akan berbeda pendapat dengan ambang")
        print("   `maximumClaimedAge` begitu salah satunya diubah.")
        return 1

    print(f"OK {diperiksa} timeline complication membaca digest basi, "
          f"semuanya menjadwalkan penyegaran dari umur cuplikan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
