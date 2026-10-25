#!/usr/bin/env python3
"""Berkas produksi yang dimutasi harness: bersih dulu, tulis atomik, pulih terverifikasi.

Kenapa berkas ini ada.

Tujuh harness di `Tools/` memutasi berkas produksi yang **sama**
(`render-visuals.py`, `CelestialVisual.swift`, `CelestialVisualView.swift`)
dan setiap prob membacanya dari **proses baru**. Penulisan biasa
(`open(path, "w")`) bukan operasi atomik: pembaca bisa melihat berkas
setengah jadi, dan bila tulisan terputus di tengah, berkas produksi tetap
termutasi tanpa ada yang tahu.

Bentuk gejalanya yang paling berbahaya bukan kerusakannya, melainkan **siapa
yang disalahkan**. Kegagalan pemulihan itu **diam**: keadaan berikutnya lalu
merah dengan pemeriksaan milik keadaan sebelumnya, seolah gerbangnya yang
salah cakupannya — padahal yang diukur adalah berkas yang masih membawa
mutasi keadaan sebelumnya. Itu sudah sekali menjatuhkan `main`:
`bukti-mutasi-radius-akhir.py` keadaan 4 merah dengan lima pemeriksaan
planet yang **sama persis** dengan keadaan 1.

Tiga penjaga, dan yang **pertama** yang paling penting.

  1. `require_clean_sources` — harness **menolak jalan** kalau berkas
     produksi yang akan ia mutasi sudah menyimpang dari `git HEAD`. Ini
     bukan hiasan: mutasi yang tertinggal dari proses yang di-`SIGKILL`
     (atau `timeout`) pernah membuat `bukti-mutasi-langit-dalam.py`
     mengambil berkas **yang sudah termutasi** sebagai "aslinya", lalu
     melaporkan "pulih persis" untuk perbandingan **dengan dirinya
     sendiri**. Seluruh laporan harness itu hijau, dan tidak satu pun
     angkanya berarti. Tanpa penjaga ini, harness yang gagal pulih akan
     mengadopsi kerusakannya sendiri sebagai kebenaran — kelas cacat yang
     sama dengan gerbang yang mengukur gambar yang tidak pernah tampil.
  2. `write_source` — tulis atomik (`os.replace`), jadi prob hanya pernah
     melihat versi lama atau versi baru.
  3. `restore_verified` — pemulihan dibaca kembali dan dibandingkan byte
     demi byte; ketidakcocokan **dilempar**, bukan diabaikan.

Kenapa satu modul, bukan salinan di tiap harness. Sampai siklus ini hanya
satu harness yang punya `os.replace`; enam saudaranya — yang memutasi berkas
produksi yang sama di CI yang sama — masih menulis biasa. Perbaikan yang
disalin enam kali adalah perbaikan yang akan hilang di salinan ketujuh.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys

# Jangan pernah menulis bytecode `.pyc` — dan ini berlaku juga untuk proses
# prob yang di-spawn harness ini, karena variabelnya diwariskan lewat
# lingkungan. CPython memvalidasi cache bytecode lewat (ukuran, mtime),
# **bukan isi**: dua keadaan harness yang berbeda bisa menghasilkan berkas
# produksi sepanjang sama, dan bila keduanya jatuh pada detik yang sama,
# probe membaca **kode keadaan sebelumnya**. Lihat `_purge_stale_bytecode` di
# `check-visuals.py` untuk cacat aslinya.
sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"


def _git(args):
    """Jalankan `git` atas repo ini, dengan pemilik repo diakui aman.

    `-c safe.directory=<akar repo>` bukan kelonggaran: tanpa itu `git`
    menolak repo yang pemiliknya berbeda dari pengguna yang menjalankannya,
    dan itu **persis** keadaan job CI (berkas di-checkout sebagai uid lain,
    sementara langkah-langkahnya berjalan sebagai root). Penolakan itu
    dilaporkan sebagai exit 1 — kode yang sama dengan «berkas menyimpang» —
    sehingga penjaga menuduh berkas yang byte-identik dengan HEAD.

    Cakupannya sengaja hanya akar repo ini, bukan `*`.

    **`cwd=root`, dan itu bukan hiasan.** Versi pertama helper ini tidak
    memasang `cwd`, sedangkan setiap pemanggil yang ia gantikan memakai
    `cwd=ROOT`. Terukur: `cd /tmp && python3 Tools/bukti-mutasi-aturan63-samaran.py`
    berhenti dengan «bukan repo git», sementara perintah yang sama dari akar
    repo berjalan. Perbedaannya tidak terlihat di CI (yang selalu berjalan
    dari akar) dan justru itu yang membuatnya bertahan: harness yang hanya
    benar dari satu direktori adalah harness yang akan dibaca orang dari
    direktori lain, lalu dilaporkan sebagai gerbang yang rusak.
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return subprocess.run(["git", "-c", f"safe.directory={root}", *args],
                          capture_output=True, text=True, cwd=root)


def _git_bytes(args):
    """`_git` untuk berkas biner: stdout sebagai byte, tanpa dekode.

    `safe.directory` tetap dipasang dengan alasan yang sama seperti `_git`:
    tanpa itu git menolak repo CI, dan penolakan itu terbaca sebagai
    "berkasnya tidak ada" — hijau palsu tepat pada job yang seharusnya
    membuktikan cacatnya. `cwd` juga sama, dengan alasan yang sama.
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return subprocess.run(["git", "-c", f"safe.directory={root}", *args],
                          capture_output=True, cwd=root)


def git_show(ref, path, min_bytes=1000):
    """Isi `path` pada `ref`, atau **berhenti keras** kalau tidak terbaca.

    Dipakai harness yang butuh "versi sebelum perbaikan" untuk arah kedua
    (membuktikan cacatnya dulu lolos). Kenapa tidak boleh mengembalikan
    string kosong: skrip kosong yang dijalankan sebagai "versi lama"
    menemukan **nol** temuan, yaitu hijau — jadi kegagalan membaca akan lulus
    **persis** pada keadaan-keadaan yang seharusnya membuktikan cacatnya, dan
    harness melaporkan "SEMUA SESUAI" atas nol pembuktian. Gerbang yang
    gagal-terbuka lebih buruk daripada tidak ada gerbang.

    Kenapa lewat `_git` dan bukan `subprocess` langsung: tanpa
    `-c safe.directory` git **menolak** repo yang pemiliknya berbeda dari
    pengguna yang menjalankannya — persis keadaan job CI (checkout sebagai
    uid lain, langkah berjalan sebagai root). Penolakan itu keluar non-nol,
    dan pemanggil yang hanya membaca `p.stdout` menerima string kosong tanpa
    tahu ada yang salah. Terukur: `bukti-mutasi-label-bawaan.py` gagal di CI
    dengan gejala yang **berbeda** dari kegagalannya di mesin pengembang,
    justru karena perbedaan ini.

    `min_bytes` memisahkan "ref-nya salah menunjuk" dari "isi sah": berkas
    yang ditambat di sini berukuran ratusan ribu karakter, jadi pembacaan di
    bawah ambang berarti ref-nya tidak memuat berkas itu — dan itu juga
    berhenti, bukan diam.

    Catatan lingkungan: `git show <sha>` hanya bekerja bila riwayatnya ada.
    `actions/checkout` bawaan mengambil **satu** commit, dan pada kedalaman
    itu penambat commit gagal terbaca; alur kerja karena itu memakai
    `fetch-depth: 0`.
    """
    proc = _git(["show", f"{ref}:{path}"])
    text = proc.stdout
    if proc.returncode != 0 or len(text) < min_bytes:
        raise SystemExit(
            f"GAGAL: tidak bisa membaca `{ref}:{path}` "
            f"(exit {proc.returncode}, {len(text)} karakter, "
            f"butuh >= {min_bytes}). {proc.stderr.strip()}\n"
            "        Harness yang butuh versi pra-perbaikan tidak boleh "
            "jalan tanpa itu: skrip kosong akan dilaporkan hijau, dan "
            "arah kedua berhenti membuktikan apa pun.")
    return text


def git_show_bytes(ref, path, min_bytes=100):
    """Seperti `git_show`, tetapi mengembalikan **byte** — untuk berkas biner.

    Kenapa terpisah: `_git` memakai `text=True`, dan `git show` atas PNG
    mengembalikan 0x89 di posisi 0 yang bukan UTF-8 — dekode gagal sebelum
    isinya bisa dibandingkan. Berkas ikon justru **harus** dibaca sebagai
    byte: yang diuji adalah ketiadaan piksel opak, bukan teksnya.

    Kontraknya sama dengan `git_show`: tidak terbaca berarti berhenti keras.
    Harness yang menerima byte kosong akan melaporkan "tidak ada ikon
    sebelumnya" — hijau tanpa memeriksa apa pun.
    """
    proc = _git_bytes(["show", f"{ref}:{path}"])
    data = proc.stdout
    if proc.returncode != 0 or len(data) < min_bytes:
        raise SystemExit(
            f"GAGAL: tidak bisa membaca `{ref}:{path}` sebagai byte "
            f"(exit {proc.returncode}, {len(data)} byte, "
            f"butuh >= {min_bytes}).\n"
            "        Harness ikon tidak boleh jalan tanpa gambar sebelumnya: "
            "byte kosong berarti 'tidak ada ikon lama', dan arah kedua "
            "berhenti membuktikan apa pun.")
    return data


def require_clean_sources(paths):
    """Hentikan harness kalau berkas produksi yang akan dimutasi sudah kotor.

    Pembandingnya `git HEAD`, bukan salinan di memori: salinan di memori
    **adalah** berkas yang kotor, jadi membandingkan dengannya selalu cocok
    dan tidak menjaga apa pun. Itu tepat cacat yang membuat
    `bukti-mutasi-langit-dalam.py` melaporkan "pulih persis" atas berkas
    yang tidak pernah pulih.

    Yang diminta adalah `git diff --quiet HEAD -- <path>` untuk setiap
    berkas: nol perbedaan berarti bersih. Kegagalan `git` sendiri (bukan
    repo, `git` tidak ada) diperlakukan sebagai **berhenti**, bukan lulus —
    penjaga yang gagal-terbuka lebih buruk daripada tidak ada penjaga.

    **Kenapa ada preflight `rev-parse`.** `git diff --quiet HEAD` memakai
    exit 1 untuk **dua** hal yang berbeda: berkas memang menyimpang, dan HEAD
    tidak terbaca. Versi pertama hanya membaca exit code-nya, jadi yang kedua
    terbaca sebagai «berkas kotor» dan pesannya menyalahkan berkas yang
    sebenarnya bersih — itu menjatuhkan `main` dua kali pada 9 Okt, dengan
    tuduhan atas `Tools/render-visuals.py` yang byte-identik dengan HEAD.
    Preflight memisahkan keduanya: HEAD yang tidak terbaca berhenti **tanpa**
    menyebut berkas apa pun, karena yang rusak adalah lingkungannya, bukan
    sumbernya.
    """
    head = _git(["rev-parse", "--verify", "--quiet", "HEAD"])
    if head.returncode != 0:
        print("GERBANG: `git` tidak bisa membaca HEAD di repo ini "
              f"(exit {head.returncode}): "
              f"{head.stderr.strip() or head.stdout.strip()}\n"
              "        Ini masalah lingkungan, bukan berkas sumber — jadi "
              "tidak ada berkas yang disalahkan.\n"
              "        Periksa kepemilikan repo (`git config --global --add "
              "safe.directory <akar repo>`).", file=sys.stderr)
        sys.exit(2)

    dirty = []
    for path in paths:
        rel = os.path.relpath(path)
        proc = _git(["diff", "--quiet", "HEAD", "--", rel])
        if proc.returncode == 1 and not proc.stderr.strip():
            dirty.append(rel)
        elif proc.returncode != 0:
            # Termasuk exit 1 ber-stderr: HEAD ada tapi tidak terbaca.
            print(f"GERBANG: `git diff` gagal atas {rel} "
                  f"(exit {proc.returncode}): {proc.stderr.strip() or '(tanpa stderr)'}",
                  file=sys.stderr)
            sys.exit(2)
    if dirty:
        print("GERBANG: berkas produksi menyimpang dari HEAD — harness "
              "mutasi tidak boleh jalan di atas sumber yang sudah kotor,\n"
              "        karena ia akan mengadopsi penyimpangan itu sebagai "
              "«aslinya» dan melaporkan «pulih persis» atas dirinya sendiri:\n"
              + "\n".join(f"          {name}" for name in dirty)
              + "\n        Pulihkan dulu (`git checkout -- <berkas>`) atau "
                "commit perubahannya.", file=sys.stderr)
        sys.exit(2)


def write_source(path, content):
    """Tulis `path` secara atomik, di filesystem yang sama.

    `content` boleh `str` atau `bytes`. `os.replace` dalam satu direktori itu
    atomik, jadi pembaca (proses baru yang menjalankan prob) hanya pernah
    melihat versi lama atau versi baru — tidak pernah yang di antaranya.

    **Mode berkas dipertahankan.** `open(tmp, "wb")` membuat berkas baru dengan
    mode 0644, jadi memutasi `swift-ui-lint.sh` (0755) lewat sini akan
    menghapus bit eksekusinya dan harness berikutnya gagal dengan
    `PermissionError` — bukan dengan temuan, yang jauh lebih menyesatkan.
    Ditemukan oleh `bukti-mutasi-gerak-angka.py`, satu-satunya harness yang
    memutasi skrip shell, bukan `.swift`.
    """
    data = content.encode("utf-8") if isinstance(content, str) else content
    try:
        mode = os.stat(path).st_mode
    except OSError:
        mode = None
    tmp = path + ".tmp-mutasi"
    with open(tmp, "wb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    if mode is not None:
        os.chmod(tmp, mode)
    os.replace(tmp, path)


def restore_verified(path, original):
    """Pulihkan `path` ke `original`, lalu **buktikan** ia pulih.

    `original` boleh `str` atau `bytes`, asal jenisnya sama dengan yang
    dibaca harness-nya. Isi di disk dibandingkan **byte demi byte** dengan
    yang seharusnya; ketidakcocokan dilempar, bukan diabaikan.

    Dipakai juga sebagai `restore()` di handler `SIGINT`/`SIGTERM`, jadi
    galatnya sengaja tidak ditelan: harness yang dihentikan di tengah dan
    gagal memulihkan harus berisik.
    """
    data = original.encode("utf-8") if isinstance(original, str) else original
    write_source(path, data)
    with open(path, "rb") as handle:
        on_disk = handle.read()
    if on_disk != data:
        raise RuntimeError(
            f"pemulihan {os.path.basename(path)} tidak cocok dengan isi "
            f"aslinya ({len(on_disk)} vs {len(data)} byte) — berkas produksi "
            "masih termutasi; perbaiki sebelum mempercayai hasil harness ini")


# ── Arah kedua: gerbang lama harus **buta**, bukan harus **hijau** ──────────
#
# Tujuh harness di `Tools/` membuktikan cacatnya nyata dengan menjalankan
# `swift-ui-lint.sh` versi **pra-perbaikan** atas mutasi yang sekarang
# memerah, lalu menuntut versi lama itu **HIJAU**. Idenya benar: kalau
# gerbang lama sudah merah pada cacat yang sama, keadaan itu tidak
# membuktikan lubang apa pun.
#
# Bentuk yang dipakai untuk menegakkannya salah, dan salahnya **tumbuh
# sendiri**. Yang dituntut adalah `exit 0` dari *seluruh* lint lama — padahal
# lint lama memeriksa **seluruh** `Apps/`, dan `Apps/` terus berubah sesudah
# lint itu di-commit. Setiap aturan baru yang lebih ketat membuat lint lama
# memerah pada pohon yang **benar**, sehingga arah kedua gagal bukan karena
# cacat yang diuji, melainkan karena repo maju. Terukur pada 23 Okt 2026,
# enam harness merah bersamaan dan tidak satu pun menyebut sebabnya:
#
#     Aturan 63  pra: 1 radius samaran Swift = 0        MERAH  (harap hijau)
#     Aturan 64  pra: 1 pemanggil menulis literal       MERAH  (harap hijau)
#     Aturan 65  pra: 1 jam: preferensi jadi false      MERAH  (harap hijau)
#     Aturan 66  pra: 1 lencana: stroke jadi false      MERAH  (harap hijau)
#     Aturan 77  arah kedua: 1. lokasi bawaan menang    exit 1 (harap 0)
#     Aturan 35  lint lama: kartu jam isStale -> false  MERAH  (harap hijau)
#
# Penyebabnya terbaca begitu diukur: lint `4302081` (pra-Aturan 63) atas
# `Apps/` hari ini keluar **1 pada pohon bersih**, karena Aturan 32 versi lama
# menuntut `drawCandidateMarker` dipanggil di bawah `if`, sementara lencana
# itu sejak `cfb911f` digambar di `.overlay { if !isConfirmed { … } }`.
# Lint yang sama atas pohonnya sendiri (`git worktree` di `4302081`) keluar
# **0**. Jadi yang diukur bukan "gerbang lama buta pada cacat ini", melainkan
# "gerbang lama ketinggalan zaman" — dan itu selalu benar, lalu selalu merah.
#
# **Yang benar: bandingkan putusannya, bukan angka keluarnya.** Pertanyaan
# yang sebenarnya ingin dijawab adalah *apakah mutasi ini mengubah apa yang
# dilihat gerbang lama*. Jadi jalankan lint lama dua kali — atas pohon bersih
# dan atas pohon termutasi — lalu tuntut **himpunan aturan yang memerah
# sama**. Kalau sama, gerbang lama memang buta pada mutasi itu, dan itu
# berlaku tanpa peduli berapa aturan lain yang sudah usang.
#
# Diukur pada keenam harness: himpunan itu **identik** ({32} untuk Aturan 63,
# dan seterusnya) sebelum dan sesudah mutasi. Jadi klaim aslinya — "gerbang
# lama tidak melihat cacat ini" — tetap benar dan tetap dibuktikan; yang
# dibuang hanyalah syarat bahwa repo tidak boleh maju.
#
# **Yang TIDAK diklaim.** Pembandingan ini tidak membuktikan gerbang lama
# *hijau*; ia membuktikan gerbang lama **tidak berubah pikiran** karena
# mutasinya. Untuk cacat yang kebetulan sudah tertangkap aturan lain yang
# kebetulan juga merah hari ini, keadaan ini akan lulus — dan itu memang
# benar: yang diuji adalah apakah aturan **yang sedang diperbaiki** buta,
# bukan apakah seluruh repo bersih pada revisi lama.

#: Baris pembuka tiap aturan di `swift-ui-lint.sh`.
_ATURAN = re.compile(r"(?m)^== Aturan (\d+):")

#: Penanda bahwa blok sebuah aturan **memerah**. Dua bentuk dipakai lint ini:
#: arahan `-> …` sesudah pesan kegagalan, dan kalimat "Anggap GAGAL, bukan
#: bersih." pada cabang fail-closed. Keduanya hanya dicetak pada kegagalan.
_GAGAL = re.compile(r"(?m)^-> |Anggap GAGAL, bukan bersih\.")


def aturan_yang_merah(keluaran):
    """Himpunan nomor aturan yang **memerah** dalam keluaran `swift-ui-lint.sh`.

    Kenapa nomor, bukan exit code: exit code menjawab "ada yang merah", dan
    yang dibutuhkan arah kedua adalah "**yang mana**". Dua keluaran bisa
    sama-sama tidak nol karena aturan yang sama sekali berbeda, dan justru
    itulah yang harus dibedakan.

    Kenapa tidak memakai `GERBANG UI GAGAL`: baris itu hanya dicetak sekali
    di ekor, jadi ia tidak bisa memisahkan satu aturan dari yang lain.

    Aturan yang memerah karena **tidak bisa memutuskan** (berkas hilang,
    `python3` tidak ada) ikut terhitung, dan itu disengaja: keadaan itu juga
    kegagalan gerbang, dan memperlakukannya sebagai "bersih" akan membuat
    perbandingan dua kegagalan lingkungan tampak seperti bukti.
    """
    blok = _ATURAN.split(keluaran)
    merah = set()
    # `re.split` dengan satu grup: [pra, nomor, isi, nomor, isi, …]
    for i in range(1, len(blok) - 1, 2):
        if _GAGAL.search(blok[i + 1]):
            merah.add(int(blok[i]))
    return merah


def jalankan_lint(teks_lint, akar):
    """Jalankan `swift-ui-lint.sh` **dari teks**, kembalikan (exit, stdout).

    Ditulis ke berkas sungguhan di `akar`, bukan ke `bash -s`: beberapa aturan
    membaca `swift-ui-lint.sh` **dari cakram** (Aturan 10 membandingkan
    hitungan aturan dengan README), jadi versi yang dijalankan harus juga
    versi yang ada di cakram. Nama berkasnya berawalan titik supaya tidak
    pernah terbaca sebagai sumber produksi, dan ia dihapus di `finally`.
    """
    jalur = os.path.join(akar, ".swift-ui-lint-pra.sh")
    try:
        with open(jalur, "w", encoding="utf-8") as berkas:
            berkas.write(teks_lint)
        os.chmod(jalur, 0o755)
        hasil = subprocess.run(["bash", jalur], cwd=akar,
                               capture_output=True, text=True, timeout=1800)
        return hasil.returncode, hasil.stdout
    finally:
        if os.path.exists(jalur):
            os.remove(jalur)


def batas_aturan(teks_lint, nomor):
    """Potong **satu** blok `# ── Aturan N` dari `swift-ui-lint.sh`.

    Kenapa tidak `text[start:end]` dengan `end = find('if [ "$status" -eq 0 ]
    ; then', start)`. Bentuk itu mengira baris penutup global ada **tepat
    sesudah** aturan yang dicari. Ia benar selama aturannya yang terakhir.
    Begitu aturan lain ditambahkan sesudahnya, potongannya berisi **semua**
    aturan berikutnya sampai ekor global — dan itu bukan cacat kosmetik:

        Tools/bukti-mutasi-lencana-ragu.py   Aturan 32
          potongan 450.583 byte  (32 aturan, 52 judul, s/d Aturan 106)
          `subprocess.run(["bash", "-c", program])`
          -> OSError [Errno 7] Argument list too long
          -> main MERAH, seluruh job "Engine Tests (Linux)" merah

    Batas 128 KiB itu `MAX_ARG_STRLEN` di Linux: satu argumen tidak boleh
    melebihi 128 KiB, dan `bash -c` menerima programnya sebagai **satu**
    argumen. Di macOS tidak ada batas itu, jadi cacatnya hanya muncul di CI
    Linux — tepat di tempat yang menjalankan seluruh harness.

    **Batasnya judul aturan berikutnya yang bernomor lain, bukan `nomor + 1`.**
    `Aturan 69` tidak tinggal di berkas ini (ia di `Tools/`), jadi mencari
    `Aturan 69` mengembalikan -1 dan blok Aturan 68 jatuh kembali ke ekor
    global: terukur 130.765 byte, masih di atas batas. Sama untuk 72, 77, 85.
    Nomor berikutnya yang **ada** yang dipakai — dicari sebagai judul, bukan
    sebagai angka, karena jarak nomornya memang berlubang.

    Nol blok = `None`, supaya pemanggil berhenti dengan alasan yang benar
    alih-alih menjalankan potongan kosong yang selalu hijau.
    """
    awal = teks_lint.find(f"# ── Aturan {nomor}")
    if awal < 0:
        return None
    # Judul bernomor **lain** sesudah blok ini; judul bernomor sama bisa
    # muncul dua kali (Aturan 39 dan 41 punya dua bagian) dan bukan batas.
    for judul in re.finditer(r"# ── Aturan (\d+)", teks_lint[awal + 1:]):
        if int(judul.group(1)) != nomor:
            blok = teks_lint[awal:awal + 1 + judul.start()]
            return blok or None
    ekor = teks_lint.find('if [ "$status" -eq 0 ]; then', awal)
    blok = teks_lint[awal:ekor] if ekor > awal else teks_lint[awal:]
    return blok or None


def jalankan_program(program, cwd, timeout=1800):
    """Jalankan potongan `swift-ui-lint.sh` → `(exit, stdout, stderr)`.

    **Bukan `bash -c program`.** Program yang diekstrak dari lint bisa
    melebihi 128 KiB (`MAX_ARG_STRLEN` di Linux) dan `bash -c` menerimanya
    sebagai satu argumen, jadi ia gagal `OSError [Errno 7] Argument list too
    long` sebelum satu aturan pun berjalan — harness lalu merah karena
    infrastrukturnya, bukan karena gerbangnya. Ditulis ke berkas sementara
    berawalan titik di `cwd` (dihapus di `finally`), dengan alasan yang sama
    seperti `jalankan_lint`: aturan yang membaca lint **dari cakram** harus
    melihat berkas yang benar-benar ada.

    `$0` dan `BASH_SOURCE` tidak dipakai satu pun aturan, jadi memindahkan
    program ke berkas tidak mengubah apa yang diukur.
    """
    jalur = os.path.join(cwd, ".potongan-aturan.sh")
    try:
        with open(jalur, "w", encoding="utf-8") as berkas:
            berkas.write(program)
        os.chmod(jalur, 0o755)
        hasil = subprocess.run(["bash", jalur], cwd=cwd,
                               capture_output=True, text=True, timeout=timeout)
        return hasil.returncode, hasil.stdout, hasil.stderr
    finally:
        if os.path.exists(jalur):
            os.remove(jalur)


def arah_kedua_buta(teks_lint, akar, pulihkan, mutasi):
    """Buktikan gerbang lama **tidak berubah pikiran** karena `mutasi`.

    `pulihkan` dipanggil untuk mengembalikan seluruh berkas produksi ke isi
    aslinya; `mutasi` adalah callable tanpa argumen yang menerapkannya lagi.
    Urutannya: bersih → ukur → termutasi → ukur → bersih. Pengukuran pertama
    adalah **acuan**, dan itu yang membuat hasilnya kebal terhadap repo yang
    maju: aturan usang yang sudah merah sebelum mutasi ada di kedua himpunan,
    jadi ia tidak bisa menyamar sebagai "gerbang lama menangkap cacat ini".

    **`mutasi` wajib mengembalikan `False` bila jangkarnya tidak ditemukan.**
    Tanpa itu, mutasi yang tidak pernah diterapkan membuat kedua pengukuran
    identik — dan hasilnya "gerbang lama buta", yaitu **hijau yang paling
    kosong**: pohon yang tidak berubah tentu tidak mengubah putusan apa pun.
    Keadaan itu dikembalikan sebagai `(None, …)`, bukan `(True, …)`, supaya
    pemanggil tidak bisa salah membacanya sebagai bukti.

    Kembalian `(buta, sebelum, sesudah)`. `buta is None` berarti mutasinya
    tidak terpasang. `buta is False` berarti gerbang lama **memang** berubah
    pikiran — entah ia menangkap cacatnya (dan keadaan harness itu tidak
    membuktikan lubang), atau mutasinya menyentuh aturan lain (dan keadaannya
    harus dipersempit). Keduanya wajib merah, dan pemanggil yang mencetak
    `sebelum`/`sesudah` membuat sebabnya terbaca tanpa menjalankan ulang.
    """
    pulihkan()
    _, bersih = jalankan_lint(teks_lint, akar)
    sebelum = aturan_yang_merah(bersih)
    if mutasi() is False:
        pulihkan()
        return None, sebelum, sebelum
    _, termutasi = jalankan_lint(teks_lint, akar)
    sesudah = aturan_yang_merah(termutasi)
    pulihkan()
    return sebelum == sesudah, sebelum, sesudah


def arah_kedua_buta_di_pohon_salinan(jalankan, teks_lint, terapkan, pulihkan):
    """`arah_kedua_buta` untuk harness yang menguji **salinan** pohon.

    Beberapa harness (Aturan 70-75) menyalin `Apps/` ke direktori sementara
    lalu menjalankan lint di sana, bukan memutasi pohon asli. Alasan salinan
    itu tetap sah — mereka menguji berkas yang tidak boleh disentuh langsung
    oleh beberapa keadaan berturut-turut — tetapi bentuk **pembandingnya**
    harus sama dengan yang di pohon asli, kalau tidak cacat yang sama
    (lint lama dituntut `exit 0` padahal ia memeriksa `Apps/` hari ini)
    kembali muncul di sini.

    Bedanya hanya pada siapa yang menjalankan lint: pemanggil menyerahkan
    `jalankan(teks_lint) -> (exit, keluaran)`, yang sudah tahu direktori
    kerjanya. Sisanya identik dengan `arah_kedua_buta`, termasuk kontrak
    `terapkan()` yang wajib mengembalikan `False` bila jangkarnya hilang.

    Kembalian `(buta, sebelum, sesudah)` dengan arti yang sama.
    """
    pulihkan()
    _, bersih = jalankan(teks_lint)
    sebelum = aturan_yang_merah(bersih)
    if terapkan() is False:
        pulihkan()
        return None, sebelum, sebelum
    _, termutasi = jalankan(teks_lint)
    sesudah = aturan_yang_merah(termutasi)
    pulihkan()
    return sebelum == sesudah, sebelum, sesudah
