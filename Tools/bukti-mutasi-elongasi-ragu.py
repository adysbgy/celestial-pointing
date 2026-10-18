#!/usr/bin/env python3
"""Bukti bahwa gerbang keyakinan pada elongasi **benar-benar dijaga uji**.

Kenapa berkas ini ada.

Dua bukti yang sudah ada tidak menjangkau cacat ini, dan masing-masing
gagal dengan cara yang berbeda:

  - `bukti-mutasi-dumbel.py` membaca **port Python** geometri
    (`render-visuals.py`). Port itu tidak punya dimensi keyakinan sama
    sekali: fungsinya `deep_sky_blobs(morphology, fuzziness, ...)` —
    tidak ada `isConfirmed`. Jadi mutasi apa pun pada cabang "engine ragu"
    di Swift **tidak terlihat** di sana; ia hijau bukan karena cacatnya
    tidak ada, melainkan karena dimensinya tidak diukur.
  - `swift-ui-lint.sh` sengaja tidak memeriksa isi badan view. Gerbang
    lint membaca *bentuk kode* (52 aturan), bukan *perilaku*, dan
    menyilang argumen `elongation:` berarti menambah aturan yang rapuh.

Yang tersisa adalah uji Swift di PointingKit — satu-satunya pembaca yang
benar-benar menjalankan `drawableElongation`. Berkas ini membuktikan uji
itu bukan cakupan palsu: setiap cacat di bawah ditanam ke **berkas
sumber Swift yang sesungguhnya**, lalu suite dijalankan ulang dari proses
baru, dan yang dituntut merah adalah uji **bernama itu** — bukan sekadar
"ada yang gagal". Harness yang hanya menuntut "suite merah" akan hijau
bila uji lain yang kebetulan rusak.

Sisi sebaliknya juga diuji: pohon yang bersih harus **hijau**. Tanpa
itu, sebuah uji yang selalu merah juga akan lolos semua keadaan di atas.

Yang TIDAK diklaim berkas ini:
  - Tidak membuktikan cepat/lambat suite (yang diukur hanya hasilnya).
  - Tidak membuktikan view memanggil fungsi yang benar. Itu dijaga
    `swift-ui-lint.sh` lewat pembacaan nama, dan uji perilaku untuk
    perilaku view tidak mungkin ada di Linux tanpa membangun `Apps/`.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))

from mutasi_sumber import require_clean_sources, restore_verified, write_source  # noqa: E402

MODEL = "Packages/PointingKit/Sources/PointingKit/DeepSkyCatalogue.swift"
TEST_FILE = "Packages/PointingKit/Tests/PointingKitTests/CelestialVisualTests.swift"

# Uji yang **wajib** berbunyi. Ditulis namanya, bukan hanya "ada kegagalan",
# supaya cacat baru di uji lain tidak bisa dipinjam sebagai bukti.
NUTUP_UJI = "testElongationIsGatedByCertaintyLikeEveryOtherIdentityCue"

ASLI = """        guard isConfirmed else { return 1.0 }
        return elongation(forObjectID: id)"""

# 1. Gerbang dicabut — persis cacat yang ditutup siklus ini: elongasi
#    kembali dibaca langsung dari id tanpa melihat keyakinan.
TANPA_GERBANG = """        return elongation(forObjectID: id)"""

# 2. Gerbang ada tetapi **terbalik** — bentuk hanya dipakai saat engine
#    ragu. Ini bukan cacat yang pernah terjadi; ia ada untuk membuktikan uji
#    membaca **arah** gerbang, bukan sekadar keberadaan kata `isConfirmed`.
TERBALIK = """        guard !isConfirmed else { return 1.0 }
        return elongation(forObjectID: id)"""

# 3. Gerbang benar, tetapi objek lonjong dibuang seluruhnya: siluet selalu
#    netral. Hijau di setiap pemeriksaan "tidak ada klaim saat ragu", jadi
#    hanya sisi kedua uji yang menangkapnya. Inilah cakupan palsu yang
#    paling mungkin: "jangan pernah mengklaim" selalu mudah dipenuhi.
SELALU_NETRAL = """        return 1.0"""

# 4. Gerbang benar dan elongasi dipakai, tetapi **id diabaikan**: semua
#    objek langit dalam dipipihkan dengan satu angka. Klaim jenis tetap
#    ada, bentuknya jadi karangan.
SATU_ANGKA = """        guard isConfirmed else { return 1.0 }
        return 0.60"""


def baca(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
        return handle.read()


def jalankan_suite():
    """Jalankan uji PointingKit, kembalikan (lulus, teks keluaran).

    `swift-test.sh` menjalankan **kedua** paket; itu disengaja. Memanggil
    `swift test` langsung akan memakai image Docker yang berbeda dari yang
    dipakai CI, dan gerbang yang mengukur toolchain lain bukan gerbang.
    """
    out = subprocess.run(["./swift-test.sh"], cwd=ROOT, capture_output=True,
                         text=True, timeout=3000)
    return out.returncode == 0, out.stdout + out.stderr


def gagal_dengan_uji(output, nama_uji):
    """Apakah keluaran memuat **kegagalan** pada uji bernama ini.

    Dicocokkan lewat `Test Case '<nama>' failed`, bukan lewat substring
    namanya saja: keluarannya juga memuat `'<nama>' started` untuk uji yang
    lulus, jadi pencarian polos akan selalu cocok dan setiap keadaan
    "merah" akan lolos tanpa ada yang merah.
    """
    # Nama di keluaran **berkualifikasi suite**: `CelestialVisualTests.<uji>`.
    # Menuntut kutip persis sebelum nama akan tidak pernah cocok, dan
    # kegagalan yang tidak cocok terbaca sebagai "bukan uji yang menjaganya"
    # -- bukan sebagai bug matcher. Itu sudah terjadi di sini: keempat
    # keadaan merah di suite tetapi harness melaporkan "bukan di uji yang
    # menjaganya" untuk semuanya.
    return re.search(rf"\b(?:[A-Za-z_][A-Za-z0-9_]*\.)*{re.escape(nama_uji)}\b"
                     r"[^\n]*?\bfailed\b", output) is not None


def main():
    paths = [MODEL]
    require_clean_sources(paths)

    asli = baca(MODEL)
    if asli.count(ASLI) != 1:
        print("GAGAL: jangkar gerbang tidak ditemukan tepat satu kali di "
              f"{MODEL}.")
        print("Harness ini menguji perilaku; kalau gerbangnya ditulis ulang, "
              "perbarui jangkar -- jangan hapus keadaannya.")
        return 1

    # Uji harus benar-benar ada. Kalau namanya berubah, seluruh keadaan
    # merah di bawah akan "lulus" karena tidak ada yang perlu gagal.
    if NUTUP_UJI not in baca(TEST_FILE):
        print(f"GAGAL: uji {NUTUP_UJI} tidak ada di {TEST_FILE}.")
        return 1

    cacat = [
        ("1. gerbang dicabut (elongasi dari id langsung)", TANPA_GERBANG),
        ("2. gerbang terbalik (bentuk hanya saat ragu)", TERBALIK),
        ("3. siluet selalu netral (bentuk dibuang)", SELALU_NETRAL),
        ("4. semua objek dipipihkan satu angka", SATU_ANGKA),
    ]

    hasil = []
    try:
        # Baseline: pohon bersih harus hijau. Tanpa ini, uji yang selalu
        # merah akan lolos setiap keadaan cacat di bawah.
        bersih, keluaran = jalankan_suite()
        hasil.append(("[baseline: pohon bersih]", bersih,
                      "" if bersih else "suite tidak hijau pada kode benar"))

        for nama, mutasi in cacat:
            write_source(os.path.join(ROOT, MODEL), asli.replace(ASLI, mutasi))
            lulus, keluaran = jalankan_suite()
            if lulus:
                hasil.append((nama, False, "suite tetap hijau -- cacat lolos"))
            elif not gagal_dengan_uji(keluaran, NUTUP_UJI):
                hasil.append((nama, False,
                              "suite merah, tetapi bukan di uji yang menjaganya"))
            else:
                baris = next((l.strip() for l in keluaran.splitlines()
                              if NUTUP_UJI in l and ("error:" in l or "failed" in l)),
                             "")
                hasil.append((nama, True, baris[:148]))
    finally:
        restore_verified(os.path.join(ROOT, MODEL), asli)

    print()
    for nama, lulus, catatan in hasil:
        print(f"{'LULUS' if lulus else 'GAGAL'}  {nama}")
        if catatan:
            print(f"        {catatan}")

    gagal = [nama for nama, lulus, _ in hasil if not lulus]
    print()
    if gagal:
        print(f"HARNESS GAGAL: {len(gagal)} keadaan tidak terbukti: "
              + ", ".join(gagal))
        return 1
    print(f"SEMUA {len(hasil)} KEADAAN TERBUKTI: gerbang elongasi dijaga "
          f"uji {NUTUP_UJI}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
