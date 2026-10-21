#!/usr/bin/env python3
"""Buktikan Aturan 86 (cabang `.stateRequest` menjawab, bukan diam) **berbunyi**.

Kenapa harness ini ada.

Aturan 86 lahir dari pengukuran, bukan dari bacaan. Sebelum ia ada, mutasi
berikut dijalankan pada salinan pohon utuh di proses baru:

    Apps/PointAndKnowiOS/Sources/PhoneLinkService.swift:120
        case .stateRequest:
            if let lastState { send(lastState) }
      -> (seluruh cabang dihapus)

Hasil: `swift-ui-lint.sh` **exit 0**, "SEMUA GERBANG UI LULUS", 85 aturan
hijau. Artinya jam bisa meminta keadaan dan tidak pernah menerima jawaban
apa pun, tanpa satu gerbang pun berbunyi.

Berkas itu satu dari tiga berkas `Apps/` yang tidak dirujuk gerbang mana pun
(`JSONArchiveDocument.swift`, `ComplicationLocalization.swift`). Sisi jam
sudah benar sejak awal — ia menulis `stateRequestTooEarly` — jadi yang hilang
bukan kalimatnya, melainkan **paritas kedua sisi**. Itu yang diuji di sini.

Keadaan yang diuji, dan apa yang masing-masing buktikan.

  [baseline]  pohon apa adanya -> diam. Tanpa ini, harness yang selalu
              berbunyi akan lulus seluruh keadaan di bawah.

  1  cabang `.stateRequest` dihapus **seluruhnya** -> BERBUNYI. Ini cacat
     aslinya, bentuk yang persis lolos 85 aturan di `main`.

  2  cabang dikembalikan ke `if let lastState { send(lastState) }` -> BERBUNYI.
     Bentuk asli sebelum siklus ini: memakai keputusan tulisan tangan, bukan
     yang diuji di Linux.

  3  `.resendLastState` mengirim di dalam `if false` -> BERBUNYI. Ini yang
     membedakan "ada kata `send(`" dari "benar-benar mengirim"; versi pertama
     aturan ini lolos pada mutasi ini.

  4  `.reportUnanswerable` menulis `nil` ke catatan status -> BERBUNYI.
     Penugasan yang hasilnya tetap diam — cacatnya sendiri, dalam bentuk
     yang paling mudah lolos ("ada baris `lastNote =`").

  5  penugasan `.reportUnanswerable` dihapus -> BERBUNYI. Bentuk yang paling
     mungkin muncul saat seseorang merapikan kode: cabangnya tinggal kosong.

  6  cabang `.reportUnanswerable` dihapus -> BERBUNYI.

  7  sisi JAM dikembalikan ke `if let` tulisan tangan -> BERBUNYI. Kalau
     hanya sisi iPhone yang dijaga, aturan ini akan hijau sementara jamnya
     menyimpang lagi.

  8  sisi JAM menulis `nil` -> BERBUNYI.

  9  KONTROL: kalimat yang dipakai tetap `stateRequestUnanswerable` meski
     ditulis lewat variabel perantara -> tetap diam. Aturan memeriksa bentuk
     keputusan, bukan nilai kalimatnya; nilai kalimatnya diuji di
     `StateRequestReplyTests` (Linux, `swift-test.sh`).

 10  fail-closed: `Apps/` kosong -> BERBUNYI dengan FAIL, bukan "Bersih".
     Indeks kosong yang dilaporkan bersih adalah bentuk gerbang hijau paling
     berbahaya.

Harness menjalankan **program Python milik Aturan 86 apa adanya**, diambil dari
`Tools/check-aturan86-jawaban-state-request.py`, di dalam sandbox yang hanya
berisi `Apps/` hasil mutasi. Aturan itu tidak membaca berkas lain, jadi tidak
ada pra-syarat lain yang perlu dibawa — dan kegagalan pra-syarat tidak akan
terbaca palsu sebagai "gerbang berbunyi". `returncode` di luar (0, 1) berarti
**galat harness**, bukan keberhasilan.
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATURAN = os.path.join(ROOT, "Tools", "check-aturan86-jawaban-state-request.py")

IOS = "Apps/PointAndKnowiOS/Sources/PhoneLinkService.swift"
JAM = "Apps/PointAndKnowWatch/Sources/WatchLinkService.swift"


def jalankan(mutasi=None, kosongkan_apps=False):
    """Jalankan aturan di sandbox; kembalikan (returncode, stdout, stderr)."""
    d = tempfile.mkdtemp(prefix="rule86-")
    try:
        tujuan_apps = os.path.join(d, "Apps")
        if kosongkan_apps:
            os.makedirs(tujuan_apps)
        else:
            shutil.copytree(os.path.join(ROOT, "Apps"), tujuan_apps,
                            ignore=shutil.ignore_patterns("*.xcodeproj",
                                                          "*.xcworkspace"))
        os.makedirs(os.path.join(d, "Tools"), exist_ok=True)
        shutil.copy2(ATURAN, os.path.join(d, "Tools", "check.py"))
        if mutasi:
            daftar = mutasi if isinstance(mutasi, list) else [mutasi]
            for m in daftar:
                # Mutasi boleh berupa fungsi atas direktori sandbox: sebagian
                # cacat (mis. "seluruh cabang dihapus") tidak bisa dinyatakan
                # sebagai satu pasangan jangkar→ganti.
                if callable(m):
                    m(d)
                    continue
                rel, anchor, ganti = m
                path = os.path.join(d, rel)
                teks = open(path, encoding="utf-8").read()
                assert anchor in teks, "anchor tidak ditemukan di %s: %r" % (
                    rel, anchor[:70])
                teks = teks.replace(anchor, ganti, 1)
                open(path, "w", encoding="utf-8").write(teks)
        p = subprocess.run([sys.executable, os.path.join("Tools", "check.py")],
                           cwd=d, capture_output=True, text=True)
        if p.returncode not in (0, 1):
            print("Aturan 86 gagal dijalankan (returncode %d), bukan berbunyi:"
                  % p.returncode)
            print((p.stderr or p.stdout)[-2000:])
            sys.exit(1)
        return p.returncode, p.stdout, p.stderr
    finally:
        shutil.rmtree(d)


# Jangkar = baris produksi apa adanya. Kalau baris ini berubah, harness harus
# ikut — `assert` di `jalankan` membuat perubahan itu berbunyi karena sebab
# yang jelas, bukan diam-diam melewati keadaan.
SEND_IOS = "                if let lastState { send(lastState) }"
TULIS_IOS = ("                lastNote = LinkStatusText.stateRequestUnanswerable")
TULIS_JAM = ("                lastMessageNote = "
             "LinkStatusText.stateRequestUnanswerable")


def ganti_cabang(teks, baru, penutup):
    """Ganti **seluruh** cabang `.stateRequest` dengan `baru`.

    Jangkar baris-per-baris tidak cukup di sini: cabang ini panjang (komentar
    penjelas + `switch` bersarang), dan mengganti hanya baris pertamanya
    meninggalkan `switch LinkStatusText.stateRequestReply(...)` di tempatnya —
    sehingga mutasinya **bukan** cacat yang dimaksud, dan aturan yang benar
    akan terlihat "diam" pada keadaan yang seharusnya berbunyi. Terukur:
    versi pertama harness ini memakai jangkar dua baris dan melaporkan tiga
    keadaan GAGAL padahal aturannya bekerja.
    """
    awal = teks.find("        case .stateRequest:")
    if awal < 0:
        return teks
    akhir = teks.find(penutup, awal)
    return teks[:awal] + baru + teks[akhir:]


def mutasi_cabang_ios(baru):
    def ubah(d):
        path = os.path.join(d, IOS)
        teks = open(path, encoding="utf-8").read()
        hasil = ganti_cabang(teks, baru, "        case .acknowledgement:")
        assert hasil != teks, "cabang .stateRequest tidak ditemukan di %s" % IOS
        open(path, "w", encoding="utf-8").write(hasil)
    return ubah


def mutasi_cabang_jam(baru):
    def ubah(d):
        path = os.path.join(d, JAM)
        teks = open(path, encoding="utf-8").read()
        hasil = ganti_cabang(teks, baru, "        default:")
        assert hasil != teks, "cabang .stateRequest tidak ditemukan di %s" % JAM
        open(path, "w", encoding="utf-8").write(hasil)
    return ubah


def main():
    if not os.path.exists(ATURAN):
        print("FAIL %s tidak ada: Aturan 86 tidak mengukur apa pun."
              % os.path.relpath(ATURAN, ROOT))
        return 1

    gagal = []

    def periksa(label, seharusnya_berbunyi, mutasi=None, kosongkan_apps=False):
        code, out, _ = jalankan(mutasi, kosongkan_apps)
        berbunyi = code != 0
        if berbunyi == seharusnya_berbunyi:
            print("OK    %-56s %s" % (label,
                                      "berbunyi" if berbunyi else "diam"))
        else:
            print("GAGAL %-56s seharusnya %s, ternyata %s"
                  % (label, "berbunyi" if seharusnya_berbunyi else "diam",
                     "berbunyi" if berbunyi else "diam"))
            if not berbunyi and seharusnya_berbunyi:
                print("      -> aturan ini tidak menangkap bentuk yang ada di "
                      "main sebelum ia ditulis.")
            if berbunyi:
                print("      -> " + (out.strip().splitlines() or ["?"])[0][:200])
            gagal.append(label)

    periksa("baseline: pohon apa adanya", False)
    periksa("1 cabang .stateRequest dihapus seluruhnya", True,
            mutasi_cabang_ios(""))
    periksa("2 kembali ke if let tulisan tangan (iPhone)", True,
            mutasi_cabang_ios(
                "        case .stateRequest:\n"
                "            if let lastState { send(lastState) }\n"))
    periksa("3 resendLastState mengirim di dalam `if false`", True,
            (IOS, SEND_IOS, "                if false { send(lastState) }"))
    periksa("4 reportUnanswerable menulis nil", True,
            (IOS, TULIS_IOS,
             "                lastNote = nil"))
    periksa("5 penugasan reportUnanswerable dihapus", True,
            (IOS, TULIS_IOS, ""))
    periksa("6 cabang reportUnanswerable dihapus", True,
            (IOS, "            case .reportUnanswerable:\n" + TULIS_IOS + "\n",
             ""))
    periksa("7 kembali ke if let tulisan tangan (jam)", True,
            mutasi_cabang_jam(
                "        case .stateRequest:\n"
                "            if let currentSnapshot { send(state: "
                "currentSnapshot()) }\n"
                "            else { lastMessageNote = LinkStatusText"
                ".stateRequestTooEarly }\n"))
    periksa("8 jam menulis nil", True,
            (JAM, TULIS_JAM,
             "                lastMessageNote = nil"))
    periksa("9 KONTROL: kalimat lewat variabel perantara", False,
            (IOS, TULIS_IOS,
             "                let kalimat = LinkStatusText"
             ".stateRequestUnanswerable\n"
             "                lastNote = kalimat"))
    periksa("10 fail-closed: Apps/ kosong", True, None, kosongkan_apps=True)

    if gagal:
        print("\nAturan 86 TIDAK terbukti: %d keadaan tidak sesuai."
              % len(gagal))
        return 1
    print("\nAturan 86 terbukti berbunyi pada 8 bentuk cacat, diam pada 1 "
          "kontrol,\ndan fail-closed saat Apps/ kosong.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
