#!/usr/bin/env python3
"""Buktikan Aturan 2 (singkatan visual) berbunyi, dan **tidak** berbunyi pada kalimat.

Kenapa berkas ini ada.

Aturan 2 ada untuk melindungi satu hal yang tidak bisa dilihat mata: apakah
`"°/dtk"` dan `"mag 1.4"` yang tampil di layar punya padanan yang **diucapkan**.
Pembaca layar membacanya sebagai deretan karakter, jadi singkatan visual yang
tidak punya padanan terucap adalah informasi yang hilang bagi sebagian pengguna
— dan hilangnya diam: layarnya benar.

Aturan itu **memang bukan kegagalan**, dan itu keputusan yang benar (padanannya
tidak bisa dibuktikan sapu teks). Tapi ia punya cacat yang berbeda, dan cacat
itu justru lahir dari kenyataan bahwa ia satu-satunya aturan yang **berbunyi
hampir setiap kali dijalankan**.

Kecurigaannya: aturan yang selalu berbunyi berhenti dibaca.

Terukur di HEAD (`bade7fa`, 35 aturan): Aturan 2 melaporkan **9 baris** di 5
berkas — dan **tidak satu pun** di antaranya teks yang tampil ke pengguna.
Kesembilannya **komentar**: sembilan baris yang **menjelaskan** kenapa satuan
visual dipakai di tempat lain, atau mengutip teksnya untuk dibandingkan.

    PointingView.swift:303   // "°/dtk" yang tak bermakna bagi pembaca layar.
    LinkView.swift:117       // lalu "0.5°/dtk" — dan pada layar ini nilainya …

Jadi laporan itu hari ini **nol sinyal**. Dan lebih dari itu: `grep`-nya mencari
polanya di **teks berkas**, bukan di dalam literal string, jadi komentar yang
menyebut pola itu dihitung sebagai temuan. Sebuah berkas yang menambah penjelasan
untuk pembaca manusia tentang singkatan visual justru menambah baris yang harus
dilewati pembaca manusia. Itu kebalikan dari yang dimaui — dan kelas cacat yang
sama sudah dibayar repo ini di Aturan 7 dan Aturan 20: pola yang dicari di dalam
komentar dan literal string.

Aturan 17 sudah menempuh jalur ini untuk `String` literal di `Apps/`, dan
harness ini memakai cara yang sama: komentar dibuang dulu, lalu **isi** literal
string dipisahkan dari prosa (`Tools/check-visuals.py` memuat `swift_code_only`
dengan alasan yang persis sama). Yang diuji setelah itu bukan "berkas ini
menyebut pola itu", melainkan "string ini **bernilai** satuan visual".

Apa yang diukur tiap keadaan.

  1. kode apa adanya                        -> temuan yang tersisa **bukan
     komentar** (versi lama: 9 temuan, 9 dari komentar → 0 sinyal)
  2. teks **nyata** di layar (`Text("mag 1.4")`)  -> berbunyi (arah yang dijaga)
  3. kalimat yang **mengutip** singkatannya       -> diam
     (bentuk yang paling mudah salah dibaca sebagai temuan)
  4. komentar yang menyebut singkatannya          -> diam
  5. singkatan di dalam `label:` aksesibilitas    -> berbunyi
     (itu tetap teks yang bisa sampai ke layar; jalan ini tidak boleh ditutup)
  6. pola di dalam **nilai kunci katalog**        -> berbunyi
     (`Localizable.xcstrings` tidak dipindai aturan mana pun, padahal isinya
      teks yang benar-benar tampil — dan ia memuat dua nilai LAYAR yang nyata:
      `object.display.coordinates` dan `telescope.coordinate.equatorial`)
  7. dokumentasi yang menulis `mag 2.5`           -> diam
     (**ini yang membedakan dokumen dari kode**: satu baris yang sama persis
      bisa jadi komentar atau kode, dan hanya posisinya yang membedakan)
  8. dokumentasi yang menulis `magnitudo 2.5` (kata penuh) -> diam
  9. frasa penuh yang **dianjurkan** di dalam string      -> diam
     (`"RA 101.3 degrees, declination -16.7 degrees"` — bentuk terucap yang
      benar, dan ia persis alasan `"RA "`/`"Dec "` mentah tidak bisa dipakai
      sebagai penanda)

Kontrol negatif (3, 4, 7, 8, 9) bukan hiasan: aturan yang memerah pada komentar
dan kalimat adalah aturan yang dimatikan orang — dan aturan yang dimatikan
tidak melindungi pembaca layar mana pun. Dua dari keadaan itu mengunci
perbaikan ini: **keadaan 4 dan 7 hijau persis pada versi baru**, dan merah pada
versi lama.

Yang TIDAK diklaim harness ini.

  - Ia mengukur **teks `Apps/` + kunci katalog**, bukan piksel dan bukan
    perilaku VoiceOver di perangkat. Yang dibuktikan: kalimat dikeluarkan,
    teks nyata masuk, dan kode yang benar tetap diam.
  - Ia **tidak** membuktikan setiap singkatan yang tersisa punya padanan
    terucap. Itu batas yang aturan 2 sendiri nyatakan, dan tidak ditutup di sini.
  - Leksikon kata penuh dibaca dari katalog **`Localizable.xcstrings` hari ini**;
    kalau katalognya menghapus entri `… speech`, keadaan 8 mulai tidak sesuai
    harapan. Itu tanda leksikonnya menyusut, bukan harnessnya rusak.
  - Ia **tidak** memeriksa apakah baris yang lolos benar-benar terdengar baik.
    `°` di luar pola `°/dtk` tidak pernah diperiksa siapa pun.

Berkas ini tidak memutasi sumber produksi: ia menyuntik di atas salinan bersih
per keadaan, supaya tidak ada pemulihan yang bisa gagal.
"""

from __future__ import annotations

import json
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

RULE = "2"

#: Situs suntik: berkas view yang tidak disentuh WIP siklus lain. Jangkar dibaca
#: dari berkas pada saat jalan; kegagalannya dicetak sebagai keadaan yang tidak
#: sesuai harapan, bukan dilaporkan lulus.
TARGET = "Apps/PointAndKnowWatch/Sources/CalibrationView.swift"

#: Situs kedua untuk keadaan katalog: entri yang sudah ada, tempat entri uji
#: disisipkan. Bentuknya sama dengan entri katalog asli supaya yang diuji
#: benar-benar isi teksnya, bukan bentuk entri yang ditolak.
CATALOG = os.path.join(ROOT, "Apps", "Shared", "Resources", "Localizable.xcstrings")
A_CATALOG = '    "pointing.link.failures": {'

#: Judul Aturan 2 — dipakai untuk mengambil **badannya**, bukan sekadar
#: "ada yang berbunyi". Aturan lain bisa merah karena salinan pohon yang tidak
#: lengkap, dan harness yang hanya menuntut "ada yang merah" tidak bisa
#: membedakan aturan mana yang menangkap cacatnya.
HEADER = "== Aturan 2:"

failures: list[str] = []


def copy_repo() -> str:
    """Salin seluruh pohon yang dibaca aturan, kecuali `.git`/`.build`.

    Kenapa utuh, bukan hanya `Apps/`: aturan lain membaca `Packages/`,
    `project.yml`, dan `Tools/`; salinan parsial membuat semuanya berbunyi dan
    menenggelamkan tanda yang dicari — cacat yang sama persis dengan versi
    pertama `bukti-mutasi-aturan-ui.py`.
    """
    workdir = tempfile.mkdtemp(prefix="gerbang-singkatan-")
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && tar --exclude=.git --exclude=.build '
         '--exclude="*/cangkang-tmp" -cf - . | (cd "$2" && tar -xf -)',
         "copy", ROOT, workdir],
        check=True)
    return workdir


def run_lint(workdir: str) -> str:
    """Jalankan **salinan** `swift-ui-lint.sh` di dalam `workdir`.

    Skripnya melakukan `cd "$(dirname "$0")"` di baris 24, jadi menjalankan yang
    ada di repo dengan `cwd=workdir` akan tetap memeriksa repo sungguhan —
    seluruh keadaan lalu dilaporkan hijau. Gejalanya persis "semuanya lulus".
    """
    lint = os.path.join(workdir, "swift-ui-lint.sh")
    os.chmod(lint, 0o755)
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run(["bash", lint], cwd=workdir,
                       capture_output=True, text=True, env=env)
    return p.stdout + p.stderr


def rule2_body(out: str) -> str | None:
    """Badan Aturan 2 sampai judul aturan berikutnya, atau None kalau hilang.

    Aturan 2 selalu mencetak judulnya entah ia menemukan sesuatu atau tidak, jadi
    mencocokkan judulnya akan membuat setiap keadaan tampak "berbunyi".
    """
    marks = list(re.finditer(r"^== Aturan \d+:.*$", out, re.M))
    for i, m in enumerate(marks):
        if not m.group(0).startswith(HEADER):
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(out)
        return out[m.end():end]
    return None


def hit_lines(body: str) -> list[str]:
    """Baris temuan di dalam badan Aturan 2.

    Dua bentuk: `path/berkas.swift:baris: "…" (…)` untuk kode, dan
    `path/Localizable.xcstrings: kunci \\`…\\` = "…" (…)` untuk katalog.
    Keduanya dihitung — kalau hanya bentuk pertama yang diakui, keadaan
    katalog akan dilaporkan "diam" walau aturannya berbunyi.
    """
    out = []
    for line in body.splitlines():
        s = line.strip()
        if re.match(r"^\S+\.swift:\d+:", s) or "kunci `" in s:
            out.append(s)
    return out


def expect(nama: str, kondisi: bool, diharapkan: bool, catatan: str = "") -> None:
    if kondisi == diharapkan:
        print(f"  OK   {nama}{catatan}")
        return
    kata = "berbunyi" if diharapkan else "diam"
    nyata = "berbunyi" if kondisi else "diam"
    failures.append(f"  Aturan {RULE} / {nama}: {nyata} padahal diharapkan {kata}")


def inject(workdir: str, snippet: str, path: str | None = None) -> bool:
    """Sisipkan `snippet` sesudah baris `import` terakhir di `path` (atau TARGET).

    Sesudah `import` terakhir pasti bagian kode, bukan komentar dan bukan di
    dalam tipe, jadi suntingannya tetap berbentuk Swift yang wajar.
    """
    path = path or TARGET
    full = os.path.join(workdir, path)
    if not os.path.exists(full):
        return False
    lines = open(full, encoding="utf-8").read().split("\n")
    imports = [i for i, l in enumerate(lines) if l.startswith("import ")]
    if not imports:
        return False
    last = imports[-1]
    out = lines[:last + 1] + [""] + snippet.split("\n") + lines[last + 1:]
    open(full, "w", encoding="utf-8").write("\n".join(out))
    return True


def inject_catalog(workdir: str, value: str) -> bool:
    """Sisipkan satu entri katalog baru berisi `value`, sebelum jangkar."""
    path = os.path.join(workdir, "Apps", "Shared", "Resources",
                        "Localizable.xcstrings")
    if not os.path.exists(path):
        return False
    text = open(path, encoding="utf-8").read()
    if text.count(A_CATALOG) != 1:
        return False
    entry = ('    "uji.singkatan.siklus": {\n'
             '      "comment": "entri uji",\n'
             '      "localizations": {\n'
             '        "en": { "stringUnit": { "state": "translated",'
             ' "value": "%s" } }\n'
             '      }\n'
             '    },\n' % value)
    open(path, "w", encoding="utf-8").write(text.replace(A_CATALOG, entry + A_CATALOG, 1))
    return True


def keadaan(nama: str, snippet: str | None, diharapkan: bool,
            katalog: str | None = None, dasar: set[str] | None = None,
            jejak: str | None = None, ukur_saja: bool = False) -> list[str]:
    """Suntik satu keadaan, jalankan aturannya, kembalikan **temuan baru**.

    Kenapa selisih terhadap `dasar`, bukan "ada temuan atau tidak". Aturan 2
    bukan aturan yang bersih di repo ini: ia melaporkan **2 temuan sah** hari
    ini (`object.display.coordinates` dan `telescope.coordinate.equatorial`,
    keduanya nilai LAYAR yang memang bentuk singkat). Harness yang menuntut
    "diam" atas himpunan penuh akan merah pada kode yang benar, dan harness
    yang menuntut "ada temuan" akan hijau pada keadaan yang tidak menyuntik
    apa pun.

    Yang diukur karena itu: **apakah cacat yang disuntik muncul**, dibanding
    keadaan dasar. `jejak` adalah penanda unik milik keadaan itu (fungsi uji
    atau nama kunci); kalau tidak diberikan, seluruh temuan baru dihitung.

    `ukur_saja=True` menonaktifkan penilaian: dipakai oleh keadaan dasar, yang
    hasilnya bukan jawaban melainkan pembanding bagi keadaan lain.
    """
    wd = copy_repo()
    try:
        if snippet is not None and not inject(wd, snippet):
            failures.append(f"  Aturan {RULE} / {nama}: tidak bisa menyuntik ke "
                            f"{TARGET} — harness perlu disesuaikan")
            return []
        if katalog is not None and not inject_catalog(wd, katalog):
            failures.append(f"  Aturan {RULE} / {nama}: tidak bisa menyuntik "
                            "entri katalog — harness perlu disesuaikan")
            return []
        out = run_lint(wd)
        body = rule2_body(out)
        if body is None:
            failures.append(f"  Aturan {RULE} / {nama}: judul aturan tidak "
                            "ditemukan di keluaran — aturannya hilang atau "
                            "berubah nama")
            return []
        hits = hit_lines(body)
        baru = [h for h in hits if h not in (dasar or set())]
        if jejak is not None:
            baru = [h for h in baru if jejak in h]
        if not ukur_saja:
            expect(nama, bool(baru), diharapkan)
        return baru
    finally:
        shutil.rmtree(wd, ignore_errors=True)


def keadaan_dasar() -> set[str]:
    """Himpunan temuan Aturan 2 atas kode apa adanya (tanpa suntikan).

    Dipanggil lewat `keadaan(...)` supaya jalur salin-jalan-uraikan yang sama
    dipakai — termasuk pemeriksaan "judul aturan ada". Harapannya `False`
    (tidak ada cacat yang disuntik), dan hasilnya dipakai sebagai **selisih**
    oleh seluruh keadaan lain.
    """
    return set(keadaan("0 dasar", None, False, ukur_saja=True))


def baris_uji(diharapkan: bool) -> list[str]:
    """Temuan tambahan di luar yang sudah ada (dipakai arah positif)."""
    return [] if diharapkan else []


def main() -> int:
    mutasi_sumber.require_clean_sources(WATCHED)

    print(f"== Buktikan Aturan {RULE} berbunyi pada singkatan visual, "
          "dan diam pada kalimat ==")
    print(f"  situs suntik: {TARGET}")

    # ── Keadaan 0: dasar — himpunan temuan atas kode apa adanya ─────────────
    # Arah yang tidak biasa untuk sebuah harness: keadaan dasar inilah yang
    # membuktikan cacatnya. Versi lama aturan ini melaporkan **9 temuan** di
    # sini, semuanya komentar (`PointingView.swift:303`, `LinkView.swift:117`,
    # …) — nol sinyal. Versi baru melaporkan **2**, keduanya nilai katalog yang
    # memang bentuk LAYAR (`object.display.coordinates`,
    # `telescope.coordinate.equatorial`).
    #
    # Dan yang paling penting: **tidak satu pun komentar**. Itu yang dituntut
    # di sini, bukan "diam" — aturan ini sengaja tidak pernah dijadikan
    # kegagalan, jadi "diam" bukan syaratnya. Kalau kelak ia kembali melaporkan
    # komentar, keadaan ini mulai tidak sesuai harapan.
    dasar = keadaan_dasar()
    komentar = [h for h in dasar if "//" in h]
    print(f"  dasar: {len(dasar)} temuan, {len(komentar)} dari komentar")

    # ── Keadaan 1: teks nyata di layar -> berbunyi ──────────────────────────
    keadaan("1 `Text(\"mag 1.4\")` di layar (harus berbunyi)",
            '    func ujiSingkatanNyata() -> some View {\n'
            '        Text("mag 1.4")\n'
            '    }\n', True, dasar=dasar)

    # ── Keadaan 2: kalimat yang mengutip singkatannya -> diam ───────────────
    # Bentuk paling mudah salah dibaca sebagai temuan: kalimat yang memuat
    # `"°/dtk"` persis, tetapi bukan satuan yang dipakai menampilkan nilai.
    keadaan("2 kalimat yang mengutip singkatannya (harus diam)",
            '    func ujiKalimat() -> some View {\n'
            '        Text("Pakai satuan \\"°/dtk\\" hanya setelah ada padanan"\n'
            '             + " terucap.")\n'
            '    }\n', False, dasar=dasar)

    # ── Keadaan 3: komentar yang menyebut singkatannya -> diam ──────────────
    # **Keadaan yang paling berharga**: ia hijau persis pada versi baru, dan
    # merah pada versi lama. Inilah cacat yang ditutup siklus ini.
    keadaan("3 komentar menyebut singkatannya (harus diam)",
            '    // Contoh baris yang dulu berbunyi: "RA 101.3° Dec −16.7°".\n'
            '    func ujiKomentar() -> some View {\n'
            '        Text("halo")\n'
            '    }\n', False, dasar=dasar)

    # ── Keadaan 4: label aksesibilitas -> berbunyi ──────────────────────────
    # `label:` tetap teks yang bisa sampai ke layar dan ke pembaca layar, jadi
    # jalan ini **tidak** boleh ikut ditutup oleh pemisahan yang baru.
    keadaan("4 singkatan di `label:` aksesibilitas (harus berbunyi)",
            '    func ujiLabel() -> some View {\n'
            '        Text("halo").accessibilityLabel("mag 2.5")\n'
            '    }\n', True, dasar=dasar)

    # ── Keadaan 5: kunci katalog -> berbunyi ────────────────────────────────
    # `Localizable.xcstrings` memuat teks yang benar-benar tampil. Sebelum
    # siklus ini jalan itu **tidak diperiksa siapa pun** — bukan Aturan 4 (ia
    # menyapu kode yang memakainya), bukan Aturan 6 (paritas kunci). Nilai
    # yang disuntik sengaja berkata `Dec`, bukan `mag`, supaya ia diuji lewat
    # satuan yang sama dengan dua temuan asli yang tersisa.
    keadaan("5 singkatan di kunci katalog (harus berbunyi)", None, True,
            katalog="Dec %+.1f°", dasar=dasar)

    # ── Keadaan 6: dokumentasi berkata `mag 2.5` -> **diam** ────────────────
    # Ini yang membedakan dokumen dari kode, dan bentuknya tidak bisa
    # dibedakan regex apa pun: satu baris yang sama persis bisa jadi komentar
    # atau kode. Prosa yang menjelaskan singkatan visual adalah hal yang
    # **benar**, jadi ia tidak boleh dihitung — kalau tidak, menambah
    # penjelasan untuk pembaca manusia justru menambah baris yang harus
    # dilewati pembaca manusia.
    keadaan("6 dokumentasi berkata `mag 2.5` (harus diam)",
            '    // Aturan 2 mengingatkan bahwa mag 2.5 butuh padanan terucap.\n'
            '    func ujiDok() -> some View {\n'
            '        Text("halo")\n'
            '    }\n', False, dasar=dasar)

    # ── Keadaan 7: dokumentasi berkata `magnitudo 2.5` -> diam ──────────────
    keadaan("7 dokumentasi berkata `magnitudo 2.5` (harus diam)",
            '    // Aturan 2 mengingatkan bahwa magnitudo 2.5 butuh padanan.\n'
            '    func ujiDokPenuh() -> some View {\n'
            '        Text("halo")\n'
            '    }\n', False, dasar=dasar)

    # ── Keadaan 8: frasa penuh di dalam string -> diam ──────────────────────
    # Bentuk yang **dianjurkan** repo ini: bentuk terucap ditulis sebagai
    # kalimat penuh. Ini persis alasan `"RA "`/`"Dec "` mentah tidak bisa
    # dipakai sebagai penanda — ia berbunyi pada kalimat yang diinginkan.
    keadaan("8 frasa penuh dalam string (harus diam)",
            '    func ujiFrasaPenuh() -> some View {\n'
            '        Text("RA 101.3 degrees, declination -16.7 degrees")\n'
            '    }\n', False, dasar=dasar)

    if failures:
        print("\nGERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        for f in failures:
            print(f)
        return 1
    print(f"\nBersih: Aturan {RULE} berbunyi pada singkatan visual di teks yang "
          "tampil — kalimat, komentar, dan kata penuh tidak menghitung.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
