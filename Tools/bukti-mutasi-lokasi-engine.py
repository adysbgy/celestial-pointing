#!/usr/bin/env python3
"""Buktikan Aturan 77 **berbunyi**, bukan sekadar hijau.

Kenapa harness ini ada.

Aturan 77 lahir dari sapuan buta (`Tools/sapu-buta-apps.py`), bukan dari
membaca kode. Sapuan itu mengganti satu baris di `Apps/` —

    var effectiveLocation: ObserverLocation { location ?? .fallback }
 -> var effectiveLocation: ObserverLocation { .fallback }

— dan **seluruh 76 aturan UI saat itu lolos**. Gerbang baru yang hijau pada
hari ia ditulis bukan bukti apa pun; yang harus dibuktikan adalah bahwa ia
**bisa merah**, dan merah pada keadaan yang memang salah.

Kenapa cacat itu serius, bukan soal gaya.

`effectiveLocation` adalah satu-satunya ekspresi yang memutuskan langit mana
yang dihitung. `PointingEngine.bind(location:)` membacanya saat pemasangan,
dan `DiagnosticsView` menampilkan `effectiveLocation.label` sebagai "lokasi
sekarang". Kalau lokasi bawaan yang menang, engine menghitung seluruh langit
untuk tempat lain sementara layar menampilkan koordinat sungguhan — dan tidak
ada satu pun bagian UI yang terlihat salah. Itu definisi "yakin pada langit
yang salah", kelas cacat yang paling dilarang PRD (uncertainty > false
confidence). Tidak ada crash, tidak ada pesan galat, tidak ada yang bisa
dilihat pengguna.

Kenapa Aturan 54 tidak menangkapnya: aturan itu menjaga jalur **penolakan
izin** (`note` saat denied/restricted/failed, dan guard akurasi). Ketiga jalur
itu tetap utuh saat nilai yang dipakai engine sudah dibuang.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]                     gerbang hijau pada pohon apa adanya.
                                 Kalau tidak, harness menuduh kode yang benar.

  1. lokasi bawaan menang        cacat aslinya: `{ location ?? .fallback }`
                                 -> `{ .fallback }`. Gerbang wajib merah.

  2. penyambungan ke engine      `update(location: provider.effectiveLocation)`
     dihapus                     diganti lokasi bawaan. Properti benar, tetapi
                                 nilainya tidak pernah sampai — cacat yang
                                 **tidak terlihat** dari LocationProvider
                                 sendiri. Membuktikan aturan memeriksa kedua
                                 sisi, bukan cuma sisi yang mudah.

  3. label bawaan dihapus        `ObserverLocation.fallbackSource` dicabut,
                                 sehingga lokasi darurat tidak bisa lagi
                                 dibedakan dari lokasi sungguhan. Ini menjaga
                                 klaim "bawaan tetap terlihat sebagai bawaan":
                                 tanpa penanda, memakai lokasi bawaan bukan
                                 lagi jujur, karena pengguna tidak bisa tahu.

  4. kontrol negatif: berkas     `LocationProvider.swift` dihapus. Gerbang
     hilang                      wajib merah karena **tidak menemukan
                                 subjeknya**, bukan hijau tanpa mengukur apa
                                 pun. Gerbang yang kehilangan subjeknya dan
                                 tetap hijau adalah gerbang vakum.

Semua mutasi berjalan pada **salinan pohon** di direktori sementara, bukan
di tempat: `swift-ui-lint.sh` membaca banyak berkas sekaligus, dan mutasi
yang tertinggal akan mencemari repo. Pohon asli diperiksa ulang di akhir.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402
LOCATION = "Apps/Shared/LocationProvider.swift"
ENGINE = "Apps/Shared/PointingEngine.swift"
OBSERVER = "Packages/PointingKit/Sources/PointingKit/ObserverLocation.swift"

BENTUK = "var effectiveLocation: ObserverLocation { location ?? .fallback }"
SAMBUNG = "update(location: provider.effectiveLocation)"


def copy_tree(tree: str) -> None:
    """Salin pohon kerja secukupnya untuk `swift-ui-lint.sh`.

    **Kenapa tidak menyalin `Packages/*/.build`.** Direktori itu dibuat oleh
    root di dalam wadah Docker (ratusan MB) dan tidak dibaca aturan teks mana
    pun; menyalinnya membuat pembersihan gagal dengan `PermissionError` yang
    tidak ada hubungannya dengan mutasi yang diuji.

    **Kenapa selengkap ini.** Percobaan pertama hanya menyalin `Apps/` +
    `Packages/PointingKit/Sources`, dan baseline-nya **merah** — bukan karena
    ada yang salah pada pohon, tetapi karena aturan lain (katalog teks vs
    kunci yang dihasilkan `PointingKit`, hitungan uji di README) membaca
    berkas yang tidak ikut tersalin. Baseline yang merah membuat setiap
    "merah (aman)" di bawah tidak bisa dipercaya: sebabnya bisa jadi salinan
    yang kurang, bukan mutasinya. Karena itu daftar ini disamakan dengan
    `Tools/sapu-buta-apps.py`, yang baseline-nya sudah terbukti hijau.
    """
    os.makedirs(tree, exist_ok=True)
    for name in ("Apps", "Tools", "Tests", "README.md", "project.yml",
                 "swift-ui-lint.sh", "swift-typecheck.sh", "swift-test.sh"):
        src = os.path.join(ROOT, name)
        if not os.path.exists(src):
            continue
        dst = os.path.join(tree, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst, symlinks=True,
                            ignore=shutil.ignore_patterns("*.pyc", "__pycache__"))
        else:
            shutil.copy2(src, dst)
    packages_dst = os.path.join(tree, "Packages")
    os.makedirs(packages_dst, exist_ok=True)
    for pkg in sorted(os.listdir(os.path.join(ROOT, "Packages"))):
        pkg_src = os.path.join(ROOT, "Packages", pkg)
        if not os.path.isdir(pkg_src):
            continue
        for sub in ("Sources", "Tests"):
            sub_src = os.path.join(pkg_src, sub)
            if os.path.isdir(sub_src):
                shutil.copytree(sub_src, os.path.join(packages_dst, pkg, sub),
                                symlinks=True)
        manifest = os.path.join(pkg_src, "Package.swift")
        if os.path.exists(manifest):
            shutil.copy2(manifest, os.path.join(packages_dst, pkg, "Package.swift"))


def run_lint(tree: str) -> tuple[int, str]:
    proc = subprocess.run(["bash", os.path.join(tree, "swift-ui-lint.sh")],
                          cwd=tree, capture_output=True, text=True, timeout=900)
    return proc.returncode, proc.stdout + proc.stderr


def patch(tree: str, relpath: str, old: str, new: str) -> None:
    path = os.path.join(tree, relpath)
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if text.count(old) != 1:
        raise SystemExit(
            f"jangkar tidak unik di {relpath} ({text.count(old)}x): {old!r}\n"
            "Sumber berubah; perbarui harness ini, jangan longgarkan aturannya.")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text.replace(old, new))


# (nama, [(berkas, lama, baru), ...], harus_merah, penanda di keluaran)
STATES = [
    ("baseline (tanpa mutasi)", [], False, None),
    ("1. lokasi bawaan menang atas lokasi sungguhan",
     [(LOCATION, BENTUK, "var effectiveLocation: ObserverLocation { .fallback }")],
     True, "effectiveLocation"),
    ("2. penyambungan ke engine dihapus",
     [(ENGINE, SAMBUNG, "update(location: .fallback)")],
     True, "bind(location:)"),
    # Keadaan 3 dan 3b menggantikan keadaan lama "penanda lokasi bawaan
    # dicabut", yang **tidak mengompilasi** (memakai `fallbackSourceLama`) dan
    # karena itu tidak membuktikan apa pun tentang pohon yang bisa dibangun.
    # Keduanya cacat yang mengompilasi, dan keduanya **lolos Aturan 77 versi
    # pertama** (terukur, proses baru, sebelum aturannya diperbaiki).
    ("3. pembaruan lokasi dibuang ke bawaan",
     [(ENGINE, "self?.update(location: newValue)",
       "self?.update(location: .fallback)")],
     True, "onLocationChanged"),
    # 3b harus **mengompilasi**, kalau tidak ia tidak membuktikan apa pun
    # tentang pohon yang bisa dibangun. Mengganti nama parameternya menjadi `_`
    # tidak mengompilasi (lalu `newValue` tak terdefinisi), dan aturan yang
    # berbasis teks memang tidak bisa melihatnya. Yang dipakai: badan closure
    # tetap sah secara tipe tetapi **tidak meneruskan apa pun**.
    ("3b. closure lokasi berhenti meneruskan (tetap mengompilasi)",
     [(ENGINE, "self?.update(location: newValue)", "_ = newValue")],
     True, "onLocationChanged"),
    ("4. kontrol negatif: berkas LocationProvider hilang",
     [(LOCATION, None, None)],
     True, "tidak ditemukan"),
    # Kontrol negatif kedua, dan ini yang paling penting: refaktor yang **sah**
    # tidak boleh memerahkan aturan. Seluruh pemakaian `fallbackSource` diganti
    # literal `"fallback"` (perilaku identik) dan konstantanya dihapus. Aturan
    # versi pertama **MERAH** di sini — gerbang yang menuduh kode benar, kelas
    # yang membuat gerbang dilonggarkan orang sampai tidak menjaga apa pun.
    ("5. kontrol negatif: refaktor sah tanpa konstanta penanda",
     [(OBSERVER, "source == ObserverLocation.fallbackSource",
       'source == "fallback"'),
      (OBSERVER, "case ObserverLocation.fallbackSource: return .locationSourceFallback",
       'case "fallback": return .locationSourceFallback'),
      (OBSERVER, "public static let fallbackSource = \"fallback\"\n", ""),
      (OBSERVER, "source: fallbackSource", 'source: "fallback"')],
     False, None),
]


def main() -> int:
    asli = {}
    for rel in (LOCATION, ENGINE, OBSERVER):
        with open(os.path.join(ROOT, rel), "rb") as fh:
            asli[rel] = fh.read()

    tmp = tempfile.mkdtemp(prefix="bukti-lokasi-")
    tree = os.path.join(tmp, "repo")
    gagal = []
    try:
        copy_tree(tree)
        for nama, edits, harus_merah, penanda in STATES:
            # Salinan segar per keadaan: mutasi keadaan lalu tidak boleh
            # menumpuk dan membuat keadaan berikutnya berbunyi karena sebab
            # yang salah.
            bersih = os.path.join(tmp, "bersih")
            if os.path.exists(bersih):
                shutil.rmtree(bersih)
            shutil.copytree(tree, bersih, symlinks=True)
            try:
                for rel, old, new in edits:
                    path = os.path.join(bersih, rel)
                    if old is None:
                        os.remove(path)
                    else:
                        patch(bersih, rel, old, new)
                code, out = run_lint(bersih)
            finally:
                shutil.rmtree(bersih, ignore_errors=True)

            merah = code != 0
            ok = merah == harus_merah
            if merah and penanda and penanda not in out:
                # Merah karena sebab lain bukan bukti: aturan bisa memerah
                # karena berkas lain hilang di salinan, dan itu akan terlihat
                # sama hijau-nya dengan bukti yang benar.
                ok = False
            detail = f"exit {code}"
            if merah:
                # Hanya keluaran Aturan 77 sendiri. Baris pertama seluruh
                # keluaran bisa milik aturan lain (mis. peringatan singkatan
                # visual Aturan 2), dan mencetaknya membuat bukti terlihat
                # benar padahal yang berbunyi aturan yang salah.
                potong = out.split("== Aturan 77:", 1)
                milik = potong[1] if len(potong) == 2 else out
                baris = [l.strip() for l in milik.splitlines()
                         if l.strip() and not l.strip().startswith("==")]
                if baris:
                    detail += " | " + baris[0][:110]
            print(f"  {'OK  ' if ok else 'SALAH'} {nama}  | {detail}")
            if not ok:
                gagal.append(nama)

        # ── Arah kedua: lubangnya nyata ────────────────────────────────────
        # Gerbang baru yang hijau pada hari ia ditulis bukan bukti apa pun.
        # Yang membuktikan Aturan 77 **menambah** sesuatu adalah cacat-cacatnya
        # lolos seluruh aturan **sebelum** ia ada. Pohon pra-perbaikan diambil
        # dari `git show HEAD:swift-ui-lint.sh` **dan** `HEAD:README.md` —
        # keduanya, karena Aturan 10 membandingkan hitungan aturan di README
        # dengan jumlah aturan di lint; memakai README pohon kerja dengan lint
        # lama membuat baseline merah karena selisih angka, dan baseline merah
        # membuat setiap "merah" di bawah tidak bisa dipercaya.
        print("\n  arah kedua (lint pra-perbaikan, wajib HIJAU):")
        lama = os.path.join(tmp, "lama")
        shutil.copytree(tree, lama, symlinks=True)
        try:
            for rel in ("swift-ui-lint.sh", "README.md"):
                isi = mutasi_sumber._git(["show", "HEAD:" + rel])
                if isi.returncode != 0:
                    raise SystemExit(f"git show HEAD:{rel} gagal: {isi.stderr}")
                with open(os.path.join(lama, rel), "w", encoding="utf-8") as fh:
                    fh.write(isi.stdout)
            code, out = run_lint(lama)
            if code != 0:
                print("  SALAH baseline pra-perbaikan sudah merah -> arah kedua "
                      "tidak membuktikan apa pun")
                gagal.append("arah kedua: baseline pra-perbaikan merah")
            for nama, edits, harus_merah, _ in STATES:
                if not harus_merah:
                    continue
                d = os.path.join(tmp, "lama-mutasi")
                if os.path.exists(d):
                    shutil.rmtree(d)
                shutil.copytree(lama, d, symlinks=True)
                try:
                    for rel, old, new in edits:
                        path = os.path.join(d, rel)
                        if old is None:
                            os.remove(path)
                        else:
                            patch(d, rel, old, new)
                    c2, _ = run_lint(d)
                finally:
                    shutil.rmtree(d, ignore_errors=True)
                # Kontrol negatif keadaan 4 (berkas hilang) memang merah di
                # lint lama juga — aturan lain membaca berkas itu. Yang
                # dibuktikan di sini hanya cacat yang **khusus** Aturan 77.
                if nama.startswith("4."):
                    continue
                ok = c2 == 0
                print(f"  {'OK  ' if ok else 'SALAH'} {nama}: exit {c2}")
                if not ok:
                    gagal.append(f"arah kedua: {nama}")
        finally:
            shutil.rmtree(lama, ignore_errors=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        if os.path.isdir(tmp):
            subprocess.run(["sudo", "-n", "rm", "-rf", tmp], capture_output=True)

    # Pohon asli wajib utuh: harness yang meninggalkan mutasi di repo adalah
    # cacat yang lebih mahal daripada cacat yang ia kejar.
    for rel, isi in asli.items():
        with open(os.path.join(ROOT, rel), "rb") as fh:
            if fh.read() != isi:
                gagal.append(f"{rel}: pohon asli berubah!")

    if gagal:
        print("\n== ATURAN 77 TIDAK TERBUKTI ==")
        for g in gagal:
            print(f"  - {g}")
        return 1
    print("\n== semua keadaan sesuai harapan: Aturan 77 berbunyi pada cacatnya ==")
    return 0


if __name__ == "__main__":
    sys.exit(main())
