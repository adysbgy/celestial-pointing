#!/usr/bin/env python3
"""Bukti bahwa `Tools/check-jangkar-harness.py` **berbunyi**, bukan sekadar mencetak "OK".

Gerbang tanpa saksi adalah gerbang yang tidak diketahui bisa merah. Di repo ini
"hijau sejak hari ditulis" berkali-kali berarti "tidak mengukur apa pun", dan
gerbang jangkar punya bentuk kebutaan yang khas: ia membandingkan **teks**, jadi
ia bisa hijau karena berkasnya tidak berubah, bukan karena tidak ada mutasi
tertinggal.

Yang diukur di sini, dan kenapa ketiganya perlu:

  1. **Mutasi bocor yang nyata** — nilai model diganti persis dengan `replace`
     milik sebuah keadaan harness (`clusterCoreBrighten: Double = 0.25` ->
     `0.0`). Ini bentuk yang sudah dua kali mendarat di `main`. Gerbang wajib
     keluar 1 dan **menyebut harness-nya**; "ada yang merah" tidak cukup,
     karena keluaran gerbang ini juga memuat baris "jangkar hilang", dan baris
     itu **bukan** temuan.

  2. **Kode yang benar harus diam.** Menyunting sumber secara sah (mis. nilai
     yang berbeda dari kedua sisi mutasi) tidak boleh merah. Gerbang yang
     merah pada pohon bersih adalah gerbang yang akan dimatikan orang, dan
     setelah dimatikan ia tidak menjaga apa pun.

  3. **Non-vakuositas.** Gerbang ini membaca `STATES` dari AST. Kalau
     pembacanya rusak sehingga tidak menemukan satu pun pasangan, ia akan
     mencetak "0 jangkar" dan keluar 0 — hijau dengan alasan yang salah.
     Keadaan 3 memutasi **pembacanya**, bukan sumbernya, dan menuntut gerbang
     menghentikan dirinya alih-alih melaporkan sukses kosong.

Menjalankan gerbang ini atas salinan pohon di direktori sementara, di proses
baru: gerbang yang dijalankan di dalam proses yang sama dengan pemutasi bisa
membaca modul yang sudah di-cache, dan itu jenis pengukuran yang salah modul
yang sudah pernah menipu sesi ini.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GERBANG = os.path.join("Tools", "check-jangkar-harness.py")
MODEL = os.path.join("Packages", "PointingKit", "Sources", "PointingKit",
                     "CelestialVisual.swift")

MODEL_ANCHOR = "clusterCoreBrighten: Double = 0.25"
MODEL_LEAKED = "clusterCoreBrighten: Double = 0.0"

#: Berkas sumber yang **tidak** ada di `KNOWN_TARGETS` milik gerbang, dipakai
#: keadaan 6 untuk membuktikan gerbang buta terhadap mutasi di luar daftar itu.
#: Jangkar di bawah adalah milik `Tools/bukti-mutasi-getaran.py` — jadi keadaan
#: ini memakai pasangan yang sudah ada di repo, bukan yang dikarang untuk lolos.
HAPTIC = os.path.join("Packages", "PointingKit", "Sources", "PointingKit",
                      "HapticPolicy.swift")
#: Jangkar **dan** penggantinya, diambil dari keadaan kedua
#: `Tools/bukti-mutasi-getaran.py` ("semua peristiwa mendapat pola yang sama").
#:
#: Kenapa bukan `pattern(for:)` + `return nil`: jangkar itu adalah **awalan**
#: dari penggantinya sendiri, jadi setelah mutasi ia masih "ada" dan gerbang
#: melaporkan hijau karena alasan yang benar tetapi bukan yang diuji. Bentuk
#: di bawah menghapus jangkarnya, sehingga hanya pengganti yang tersisa —
#: persis bentuk "mutasi tertinggal" yang harus ditangkap.
HAPTIC_ANCHOR = ("        case .sensorUnavailable:\n            return .failed\n"
                 "        case .returnedToIdle:\n            return .tick")
HAPTIC_LEAKED = ("        case .sensorUnavailable:\n            return .completed\n"
                 "        case .returnedToIdle:\n            return .completed")

#: Keadaan 7: suntingan **sisipan murni** — penggantinya memuat jangkarnya,
#: sehingga `anchor in text` tetap benar setelah mutasi mendarat.
#:
#: Pasangan ini diambil apa adanya dari keadaan `bukti-mutasi-aturan52-kartu-jam.py`
#: (pembungkus `isConfirmed: true` yang ditempel di atas
#: `PulsingCelestialVisual`). Memakai suntingan yang sudah ada berarti keadaan
#: ini mengukur gerbang, bukan jangkar karangan yang dibuat agar lolos.
SISIPAN = os.path.join("Apps", "PointAndKnowWatch", "Sources", "PointingView.swift")
SISIPAN_ANCHOR = "struct PulsingCelestialVisual: View {"
SISIPAN_LEAKED = (
    "struct PembungkusLuar: View {\n"
    "    var body: some View {\n"
    "        PembungkusBaru(isConfirmed: true)\n"
    "    }\n"
    "}\n"
    "\n"
    "struct PembungkusBaru: View {\n"
    "    let isConfirmed: Bool\n"
    "    var body: some View {\n"
    "        CelestialVisualView(visual: CelestialVisual(kind: .star),\n"
    "                            diameter: 10,\n"
    "                            isConfirmed: isConfirmed)\n"
    "    }\n"
    "}\n"
    "\n"
    "struct PulsingCelestialVisual: View {")

#: Berkas yang ikut disalin: cukup untuk gerbang (AST `STATES` + sumber sasaran).
#: Salinan parsial membuat gerbang melaporkan "TAK TERBACA" untuk berkas yang
#: tidak disalin; itu bukan temuan, dan menuntutnya merah akan mengukur
#: kelengkapan salinan, bukan gerbangnya.
COPY = (
    "Tools",
    "Packages/PointingKit/Sources/PointingKit",
    "Apps/Shared",
    "Apps/PointAndKnowWatch/Sources",
    # Ditambahkan bersama keadaan 6: berkas yang tidak ada di `KNOWN_TARGETS`
    # milik gerbang hanya bisa diuji kalau ia ikut disalin. Tanpa `Apps/
    # PointAndKnowiOS` dan `project.yml`, gerbang melaporkan "TAK TERBACA" --
    # yang bukan temuan, dan menuntutnya merah akan mengukur kelengkapan
    # salinan, bukan gerbangnya.
    "Apps/PointAndKnowiOS/Sources",
    "Apps/PointAndKnowWatch/Complications",
    "Packages/CelestialEngine/Sources",
    "project.yml",
)


def run_gerbang(cwd):
    proc = subprocess.run([sys.executable, GERBANG], cwd=cwd,
                          capture_output=True, text=True, timeout=600)
    return proc.returncode, proc.stdout + proc.stderr


def salin_pohon(dest):
    for rel in COPY:
        src = os.path.join(ROOT, rel)
        dst = os.path.join(dest, rel)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        elif os.path.isfile(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)


def main():
    failures = []

    # --- Keadaan 1 & 2: pohon utuh, lalu mutasi bocor nyata ditanamkan. ---
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        model = os.path.join(tmp, MODEL)

        code, out = run_gerbang(tmp)
        print("=== Keadaan 1: pohon utuh (harus hijau) ===")
        print(out.strip())
        if code != 0:
            failures.append(
                f"Keadaan 1: gerbang merah pada pohon utuh (exit {code}). "
                "Gerbang yang merah pada kode benar akan dimatikan orang.")

        text = open(model, encoding="utf-8").read()
        if MODEL_ANCHOR not in text:
            print(f"FATAL: jangkar {MODEL_ANCHOR!r} tidak ada di {MODEL} — "
                  "harness ini mengukur nilai yang sudah bergeser.")
            return 2
        open(model, "w", encoding="utf-8").write(
            text.replace(MODEL_ANCHOR, MODEL_LEAKED, 1))

        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 2: mutasi bocor ditanamkan (harus merah) ===")
        print(out.strip())
        if code == 0:
            failures.append(
                "Keadaan 2: gerbang hijau padahal nilai model sama persis "
                "dengan `replace` sebuah keadaan harness. Ini bentuk cacat "
                "yang sudah dua kali mendarat di `main`.")
        else:
            if "MUTASI BOCOR" not in out:
                failures.append(
                    "Keadaan 2: gerbang merah, tetapi tidak menyebut "
                    "'MUTASI BOCOR' — merah karena sebab lain, bukan karena "
                    "mutasi tertinggal.")
            if MODEL_LEAKED not in out:
                failures.append(
                    "Keadaan 2: gerbang tidak menyebut nilai yang bocor, jadi "
                    "orang yang membacanya tidak tahu apa yang harus "
                    "dipulihkan.")

    # --- Keadaan 3: pembaca jangkar dilumpuhkan (non-vakuositas). ---
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        g = os.path.join(tmp, GERBANG)
        src = open(g, encoding="utf-8").read()
        # Lumpuhkan pengumpulan pasangan: gerbang lalu memeriksa nol jangkar.
        # Bentuk ini yang paling berbahaya — ia tetap mencetak "OK".
        lumpuh = re.sub(r"(def _collect_edits\(tree, consts\):\n)",
                        r"\1    return []\n", src, count=1)
        if lumpuh == src:
            print("FATAL: tidak bisa melumpuhkan `_collect_edits` — harness "
                  "ini mengukur bentuk yang sudah berubah.")
            return 2
        open(g, "w", encoding="utf-8").write(lumpuh)

        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 3: pembaca jangkar dilumpuhkan (wajib NON-vakuos) ===")
        print(out.strip())
        if code == 0 and "0 jangkar" in out:
            failures.append(
                "Keadaan 3: gerbang melaporkan sukses dengan nol jangkar "
                "diperiksa. Ia hijau karena tidak mengukur apa pun.")
        if "0 jangkar" not in out and code == 0:
            # Bukan kegagalan keras, tapi harus terlihat: artinya pelumpuhan
            # tidak sampai ke jalur yang diukur.
            print("CATATAN: pelumpuhan tidak terlihat di keluaran — cakupan "
                  "keadaan ini perlu diperiksa.")

    # --- Keadaan 4: harness baru tanpa jangkar terbaca (wajib MERAH). ---
    #
    # Kelas yang dijaga di sini: harness **baru** yang menulis sumber produksi
    # di tempat sementara `STATES`-nya berbentuk yang belum dikenali pembaca.
    # Tanpa keadaan ini, pengecualian yang ditambahkan supaya pohon bersih
    # kembali hijau bisa melebar tanpa batas: apa pun yang buta akan lolos.
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        baru = os.path.join(tmp, "Tools", "bukti-mutasi-harness-baru.py")
        with open(baru, "w", encoding="utf-8") as handle:
            handle.write(
                "import os\n"
                "import mutasi_sumber\n"
                "ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))\n"
                "STATES = [(nomor, rakit()) for nomor in range(3)]\n"
                "def main():\n"
                "    mutasi_sumber.write_source(os.path.join(ROOT, 'x'), 'y')\n")
        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 4: harness baru tanpa jangkar terbaca (wajib MERAH) ===")
        print(out.strip()[-600:])
        if code == 0:
            failures.append(
                "Keadaan 4: gerbang hijau untuk harness baru yang memutasi "
                "sumber produksi tanpa satu jangkar terbaca. Pengecualian "
                "harus dinyatakan eksplisit, bukan diberikan diam-diam.")
        elif "bukti-mutasi-harness-baru.py" not in out:
            failures.append(
                "Keadaan 4: gerbang merah tetapi tidak menyebut harness yang "
                "buta — pembaca tidak tahu berkas mana yang harus diperbaiki.")

    # --- Keadaan 5: pengecualian yang dinyatakan (wajib HIJAU, tapi terlihat). ---
    #
    # Deklarasi `JANGKAR_KECUALI` harus **bekerja** — kalau tidak, satu-satunya
    # cara membuat gerbang hijau adalah menghapus pemeriksaannya. Dan harus
    # **tercetak**: pengecualian yang senyap sama saja dengan kebohongan.
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        baru = os.path.join(tmp, "Tools", "bukti-mutasi-harness-baru.py")
        with open(baru, "w", encoding="utf-8") as handle:
            handle.write(
                "import os\n"
                "import mutasi_sumber\n"
                "ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))\n"
                "JANGKAR_KECUALI = (\n"
                "    'muatan dirakit saat jalan dari AST berkas sasaran, jadi '\n"
                "    'tidak ada pasangan jangkar tetap untuk dibaca gerbang')\n"
                "STATES = [(nomor, rakit()) for nomor in range(3)]\n"
                "def main():\n"
                "    mutasi_sumber.write_source(os.path.join(ROOT, 'x'), 'y')\n")
        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 5: pengecualian dinyatakan (wajib HIJAU + tercetak) ===")
        print(out.strip()[-700:])
        if code != 0:
            failures.append(
                "Keadaan 5: gerbang tetap merah padahal harness-nya menyatakan "
                "alasan pengecualiannya. Satu-satunya jalan keluar yang tersisa "
                "adalah menghapus pemeriksaannya — dan itu yang akan dilakukan "
                "orang berikutnya.")
        if "bukti-mutasi-harness-baru.py" not in out:
            failures.append(
                "Keadaan 5: pengecualian diterima tetapi tidak dicetak. "
                "Pengecualian yang tidak terlihat tidak bisa ditinjau siapa pun.")

    # --- Keadaan 6: mutasi tertinggal di berkas yang TIDAK ada di daftar tangan. ---
    #
    # Kelas yang dijaga di sini, dan ia nyata: `KNOWN_TARGETS` adalah daftar
    # 12 berkas yang ditulis tangan, sedangkan `Apps/` + `Packages/` memuat
    # ratusan berkas sumber. Jangkar tanpa sasaran eksplisit hanya diuji
    # terhadap 12 berkas itu. Mutasi tertinggal di luar daftar karena itu
    # dilaporkan sebagai "jangkar hilang (pengganti tidak ada)" -- yang
    # komentarnya sendiri menyebutnya "bukan kebocoran" -- lalu keluar 0.
    #
    # Terukur pada `HEAD` sebelum keadaan ini ada: `return nil` disisipkan ke
    # `HapticPolicy.pattern(for:)` (memadamkan seluruh getaran) -> gerbang
    # mencetak "OK: 496 jangkar; tidak ada mutasi tertinggal" dan keluar 0.
    # Bentuk persisnya pernah mendarat di pohon kerja sesi ini.
    #
    # Kenapa `HapticPolicy.swift` yang dipakai: ia berkas sumber produksi yang
    # **tidak** ada di `KNOWN_TARGETS`, dan jangkarnya milik
    # `bukti-mutasi-getaran.py` -- jadi keadaan ini mengukur gerbang, bukan
    # berkas baru yang dikarang untuk lolos.
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        haptic = os.path.join(tmp, HAPTIC)
        if not os.path.isfile(haptic):
            print(f"FATAL: {HAPTIC} tidak tersalin — keadaan 6 tidak bisa diuji.")
            return 2
        text = open(haptic, encoding="utf-8").read()
        if text.count(HAPTIC_ANCHOR) != 1:
            print(f"FATAL: jangkar {HAPTIC_ANCHOR!r} tidak ada tepat satu kali "
                  f"di {HAPTIC} — keadaan 6 mengukur teks yang sudah bergeser.")
            return 2
        open(haptic, "w", encoding="utf-8").write(
            text.replace(HAPTIC_ANCHOR, HAPTIC_LEAKED, 1))

        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 6: mutasi tertinggal di luar daftar tangan "
              "(wajib MERAH) ===")
        print(out.strip()[-700:])
        if code == 0:
            failures.append(
                "Keadaan 6: gerbang hijau padahal `return nil` tertinggal di "
                "`HapticPolicy.pattern(for:)` — berkas sumber yang tidak ada "
                "di `KNOWN_TARGETS`. Jangkar tanpa sasaran yang tidak "
                "ditemukan hanya dicatat, jadi mutasi di luar 12 berkas itu "
                "tidak pernah bisa memerahkan gerbang.")
        else:
            if "MUTASI BOCOR" not in out:
                failures.append(
                    "Keadaan 6: gerbang merah, tetapi tidak menyebut "
                    "'MUTASI BOCOR' — merah karena sebab lain.")
            if "HapticPolicy" not in out:
                failures.append(
                    "Keadaan 6: gerbang tidak menyebut berkas yang termutasi, "
                    "jadi pembaca tidak tahu apa yang harus dipulihkan.")

    # --- Keadaan 7: mutasi SISIPAN murni (jangkar tetap ada). ---
    #
    # Keadaan 6 menutup satu bentuk kebocoran, tetapi gerbang masih memakai
    # `anchor in text` sebagai satu-satunya tanda. Itu cukup untuk mutasi yang
    # **menghapus** jangkarnya, dan tidak cukup untuk mutasi yang
    # **menyisipkan** teks baru tanpa membuang jangkar — bentuk yang justru
    # paling umum di harness repo ini: 22 dari 496 suntingan punya pengganti
    # yang **memuat** jangkarnya sendiri (mis. `bukti-mutasi-aturan52-kartu-jam.py`
    # menempel `PembungkusLuar`/`PembungkusBaru` **di atas**
    # `struct PulsingCelestialVisual`, sehingga jangkarnya tetap utuh).
    #
    # Terukur pada `HEAD` sebelum keadaan ini ada: `PembungkusLuar` disisipkan
    # ke `PointingView.swift` lalu dibiarkan -> gerbang mencetak
    # "OK: 496 jangkar; tidak ada mutasi tertinggal" dan keluar 0. Kode mati
    # yang mengklaim `isConfirmed: true` pada visual bintang ikut tertinggal
    # di pohon produksi tanpa satu pun gerbang berbunyi.
    #
    # Kenapa keadaan ini memakai suntingan yang **sudah ada** di harness lain
    # (`bukti-mutasi-aturan52-kartu-jam.py`), bukan teks karangan: supaya yang
    # diukur adalah gerbang, bukan jangkar baru yang dibuat agar lolos.
    with tempfile.TemporaryDirectory() as tmp:
        salin_pohon(tmp)
        view = os.path.join(tmp, SISIPAN)
        if not os.path.isfile(view):
            print(f"FATAL: {SISIPAN} tidak tersalin — keadaan 7 tidak bisa diuji.")
            return 2
        text = open(view, encoding="utf-8").read()
        if text.count(SISIPAN_ANCHOR) != 1:
            print(f"FATAL: jangkar {SISIPAN_ANCHOR!r} tidak ada tepat satu kali "
                  f"di {SISIPAN} — keadaan 7 mengukur teks yang sudah bergeser.")
            return 2
        if SISIPAN_ANCHOR not in SISIPAN_LEAKED:
            print("FATAL: pengganti keadaan 7 tidak memuat jangkarnya, jadi "
                  "keadaan ini tidak menguji bentuk sisipan murni.")
            return 2
        open(view, "w", encoding="utf-8").write(
            text.replace(SISIPAN_ANCHOR, SISIPAN_LEAKED, 1))

        code, out = run_gerbang(tmp)
        print("\n=== Keadaan 7: mutasi SISIPAN murni, jangkar tetap ada "
              "(wajib MERAH) ===")
        print(out.strip()[-700:])
        if code == 0:
            failures.append(
                "Keadaan 7: gerbang hijau padahal suntingan sisipan tertinggal "
                "di `PointingView.swift` dan jangkarnya masih utuh. Gerbang "
                "hanya bertanya 'apakah jangkar masih ada', sehingga bentuk "
                "yang menambah teks tanpa membuang jangkar tidak pernah "
                "terbaca sebagai mutasi tertinggal.")
        else:
            if "MUTASI BOCOR" not in out:
                failures.append(
                    "Keadaan 7: gerbang merah, tetapi tidak menyebut "
                    "'MUTASI BOCOR' — merah karena sebab lain.")
            if "PointingView" not in out:
                failures.append(
                    "Keadaan 7: gerbang tidak menyebut berkas yang termutasi, "
                    "jadi pembaca tidak tahu apa yang harus dipulihkan.")

    print()
    if failures:
        print(f"GAGAL: {len(failures)} keadaan tidak sesuai harapan.")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("OK: gerbang jangkar berbunyi pada mutasi bocor, dan diam pada "
          "pohon yang benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
