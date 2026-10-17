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
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return subprocess.run(["git", "-c", f"safe.directory={root}", *args],
                          capture_output=True, text=True)


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
