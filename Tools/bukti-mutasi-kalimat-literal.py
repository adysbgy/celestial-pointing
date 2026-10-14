#!/usr/bin/env python3
"""Buktikan Aturan 12 (kalimat tampilan tidak lahir sebagai literal) **berbunyi**.

Kenapa berkas ini ada.

Aturan 12 menyapu kelas cacat lokalisasi yang tidak terlihat oleh compiler dan
tidak terlihat oleh mata: kalimat Bahasa Indonesia yang ditulis **langsung** di
dalam `Apps/`, ditugaskan ke properti berakhiran Note/Message/Label/Title/
Speech, lalu dirender apa adanya.

Yang membuatnya berbahaya justru bahwa ia tampak benar. Kalimatnya terbaca
lancar di layar, lulus tinjauan, dan tidak pernah muncul di diff sebagai
kesalahan — sampai seseorang mengganti bahasa perangkat. Saat itu kalimatnya
tetap Bahasa Indonesia, sendiri, di tengah antarmuka yang sudah berbahasa lain.
`swiftc` tidak peduli, `swift test` di Linux tidak bisa membangun `Apps/`
sama sekali, dan CI macOS hanya gagal bila ada *warning*.

Aturan 12 adalah satu-satunya penjaga kelas ini, dan sebelum harness ini ia
tidak punya rekam jejak bahwa ia bisa keluar merah.

Kenapa pembuktiannya perlu bentuk khusus.

Aturan 12 menyapu berdasarkan **nama properti** (akhiran Note/Label/Title/…)
dan bentuk literalnya (harus mengandung spasi, harus ada huruf, bukan kunci
katalog bertitik). Dua penyaring itu bisa gagal dengan cara yang berbeda, dan
kedua kegagalannya menghasilkan keluaran yang sama persis: "Bersih".

  - penyaring nama terlalu sempit  -> kalimat di properti biasa lolos
  - penyaring literal terlalu longgar -> kalimat sah dilaporkan (positif palsu)

Karena itu harness menguji **empat** keadaan, bukan dua: kalimat literal harus
berbunyi, kunci katalog harus **diam** (kalau tidak, aturan memerah pada setiap
penugasan wajar dan akan dimatikan orang), satu kata harus diam, dan kode benar
harus diam.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  1. kode benar                        -> diam
     (aturan tidak memerah pada kepatuhan yang sah)
  2. `statusMessage = ExperimentText.statusNoTarget`
        menjadi `statusMessage = "Belum ada target yang dipilih untuk direkam"`
                                       -> berbunyi, menyebut berkas dan baris
     (aturan mengukur kelas cacatnya, bukan sekadar hidup)
  3. penugasan kunci katalog bertitik  -> diam
     (aturan tidak memerah pada bentuk yang sah — tanpa ini, keadaan 2 lulus
      juga untuk aturan yang memerah pada segala sesuatu)
  4. literal satu kata                 -> diam
     (aturan membedakan kalimat dari nama; tanpa ini ia akan memaksa setiap
      pengenal dilokalkan)

Yang TIDAK diklaim harness ini: ia tidak membuktikan seluruh kalimat di
`Apps/` sudah terlokalkan, dan tidak membuktikan terjemahan Bahasa Inggrisnya
benar. Yang dibuktikan: aturan ini berbunyi pada kalimat literal yang lahir di
`Apps/`, dan diam pada tiga bentuk yang tidak seharusnya berbunyi.

Berkas ini tidak memutasi sumber produksi: ia menyuntik di atas salinan bersih
per keadaan.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penjaga sumber bersih, sama dengan harness lain)

WATCHED = [LINT, os.path.join(ROOT, "Apps")]

# Berkas yang bukan milik WIP siklus lain, supaya commit harness ini tidak
# bertabrakan dengan pohon kerja mereka.
TARGET = "Apps/PointAndKnowiOS/Sources/ExperimentRecorder.swift"
ANCHOR = "statusMessage = ExperimentText.statusNoTarget"

failures: list[str] = []


def copy_repo() -> str:
    """Salin seluruh pohon yang dibaca aturan, kecuali `.git`/`.build`.

    Kenapa utuh: salinan parsial membuat aturan lain berbunyi di salinan tak
    lengkap dan menenggelamkan tanda yang dicari — cacat yang sama persis
    dengan versi pertama `bukti-mutasi-aturan-ui.py`.
    """
    workdir = tempfile.mkdtemp(prefix="gerbang-kalimat-literal-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build -cf - . '
         '| (cd "$2" && tar -xf -)', "copy", ROOT, workdir],
        check=True)
    return workdir


def run_lint(workdir: str) -> tuple[int, str]:
    """Jalankan **salinan** `swift-ui-lint.sh` di dalam `workdir`.

    Skripnya `cd "$(dirname "$0")"`, jadi menjalankan yang di repo dengan
    `cwd=workdir` akan tetap memeriksa repo sungguhan.
    """
    lint = os.path.join(workdir, "swift-ui-lint.sh")
    os.chmod(lint, 0o755)
    p = subprocess.run(["bash", lint], cwd=workdir,
                       capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def finding(out: str, rule: str) -> str | None:
    """Ambil badan temuan Aturan `rule`, atau None kalau ia bersih."""
    m = re.search(rf"^== Aturan {rule}:.*?$(.*?)(?=^== Aturan \d+:|\Z)",
                  out, re.M | re.S)
    if not m:
        return None
    body = m.group(1).strip()
    if body.startswith("Bersih"):
        return None
    return body


def expect(nama: str, kondisi: bool, diharapkan: bool) -> None:
    if kondisi == diharapkan:
        print(f"  OK   {nama}")
        return
    kata = "merah" if diharapkan else "hijau"
    nyata = "merah" if kondisi else "hijau"
    failures.append(f"  Aturan 12 / {nama}: {nyata} padahal diharapkan {kata}")


def sunting(workdir: str, baru: str) -> bool:
    """Ganti baris ber-ANCHOR di salinan. False bila jangkar tidak ada."""
    p = os.path.join(workdir, TARGET)
    src = open(p, encoding="utf-8").read()
    if ANCHOR not in src:
        return False
    open(p, "w", encoding="utf-8").write(src.replace(ANCHOR, baru, 1))
    return True


def keadaan(nama: str, pengganti: str, diharapkan_merah: bool,
            harus_sebut: str | None = None) -> None:
    """Suntik satu keadaan lalu nilai Aturan 12 di atasnya."""
    wd = copy_repo()
    try:
        if not sunting(wd, pengganti):
            failures.append(f"  Aturan 12 / {nama}: jangkar tidak ditemukan "
                            f"di {TARGET} — harness perlu disesuaikan")
            return
        _, out = run_lint(wd)
        body = finding(out, "12")
        assert body is None or isinstance(body, str)
        merah = body is not None
        if merah and harus_sebut and harus_sebut not in body:
            merah = False
            failures.append(f"  Aturan 12 / {nama}: berbunyi tapi tidak "
                            f"menyebut '{harus_sebut}' — kemungkinan aturan "
                            f"lain yang merah")
            return
        expect(nama, merah, diharapkan_merah)
    finally:
        shutil.rmtree(wd, ignore_errors=True)


def main() -> int:
    mutasi_sumber.require_clean_sources(WATCHED)

    # Pra-syarat jangkar. Kalau ini tidak ada, seluruh keadaan di bawah
    # mengukur keadaan yang tidak pernah tersuntik — dan akan melaporkan
    # hijau atas ketiadaan.
    src = open(os.path.join(ROOT, TARGET), encoding="utf-8").read()
    if ANCHOR not in src:
        print(f"LEWAT: '{ANCHOR}' tidak ada di {TARGET} — "
              "harness perlu disesuaikan")
        return 1

    print("== Buktikan Aturan 12 berbunyi pada kalimat literal di Apps/ ==")
    print(f"  jangkar: {TARGET}")

    # 1. kode benar -> diam
    wd = copy_repo()
    try:
        _, out = run_lint(wd)
        expect("kode benar (harus diam)", finding(out, "12") is not None, False)
    finally:
        shutil.rmtree(wd, ignore_errors=True)

    # 2. kalimat literal -> berbunyi, menyebut berkasnya
    keadaan("kalimat literal Bahasa Indonesia (harus merah, sebut berkas)",
            'statusMessage = "Belum ada target yang dipilih untuk direkam"',
            True, harus_sebut="ExperimentRecorder.swift")

    # 3. kunci katalog bertitik -> diam (bukan kalimat)
    keadaan("kunci katalog bertitik (harus diam)",
            "statusMessage = ExperimentText.statusNoTargetX",
            False)

    # 4. literal satu kata -> diam (nama, bukan kalimat)
    keadaan("literal satu kata (harus diam)",
            'statusMessage = "Menunggu"',
            False)

    if failures:
        print("\nGERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        for f in failures:
            print(f)
        return 1
    print("\nBersih: Aturan 12 berbunyi pada kalimat literal yang lahir di "
          "Apps/, dan diam pada kunci katalog, satu kata, dan kode benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
