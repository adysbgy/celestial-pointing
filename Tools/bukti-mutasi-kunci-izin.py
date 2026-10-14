#!/usr/bin/env python3
"""Buktikan Aturan 30 (kunci izin engine sampai ke project.yml) **berbunyi**.

Kenapa berkas ini ada.

Aturan 30 menjaga rantai yang seluruhnya tidak terlihat oleh compiler:

    Packages/ mendeklarasikan "NSLocalNetworkUsageDescription"
        -> project.yml harus memuat INFOPLIST_KEY_NSLocalNetworkUsageDescription
            -> iOS membaca Info.plist
                -> pengguna melihat dialog izin

Putus di tengah dan tidak ada yang merah: `swiftc` tidak peduli, `swift test`
di Linux hanya membangun `Packages/` (jadi ia melihat ujung yang mendeklarasi
bukan ujung yang memakai), dan CI macOS hanya gagal bila ada *warning*. Yang
terjadi adalah iOS **menolak akses tanpa peringatan** — fitur mati di perangkat
dan hijau di mana-mana.

Itu cacat yang paling mahal untuk dibiarkan tanpa saksi, karena gejalanya
muncul di tangan pengguna, jauh dari tempat keputusannya dibuat.

Kenapa Aturan 30 sendiri perlu dibuktikan, bukan dipercaya.

Himpunannya diambil dari dua tempat (`Packages/` dan `project.yml`). Kalau
pencariannya berubah atau salah, `keys` jadi kosong, dan skripnya sudah
mengantisipasi itu dengan mencetak PERINGATAN. Tetapi **cabang `-n "$declared"`**
menganggap string apa pun — termasuk peringatan — sebagai temuan dan
memerahkannya, jadi kegagalan *pencarian* dan kegagalan *kepatuhan* tidak bisa
dibedakan dari luar. Dua arah di bawah memisahkan keduanya secara terukur.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  1. kode benar                       -> Aturan 30 diam
     (buktikan aturan tidak memerah pada kepatuhan yang sah)
  2. kunci dihapus dari project.yml   -> Aturan 30 berbunyi, **menyebut kunci
     itu sendiri**
     (buktikan aturan mengukur kepatuhan, bukan sekadar hidup)
  3. deklarasi di Packages/ dihapus   -> Aturan 30 diam, dan himpunannya
     **tidak** dilaporkan sebagai temuan
     (buktikan arah sebaliknya: aturan tidak memerah pada ketiadaan deklarasi,
     dan peringatan himpunan-kosong tidak disamarkan sebagai temuan)

Kenapa keadaan 3 penting dan bukan sekadar formalitas. Sapuan yang memerah pada
setiap keadaan akan lulus keadaan 2, dan karena itu keadaan 2 sendirian **tidak
membuktikan apa-apa**. Keadaan 3 adalah kontrol negatifnya.

Yang TIDAK diklaim harness ini: ia tidak membuktikan Info.plist yang
dihasilkan XcodeGen benar-benar memuat kuncinya pada build nyata, dan tidak
membuktikan teks izinnya terbaca di perangkat. Yang dibuktikan: aturan ini
berbunyi pada kepatuhan yang hilang dan diam pada yang ada.

Berkas ini tidak memutasi sumber produksi: ia menyuntik di atas salinan bersih
per keadaan.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penjaga sumber bersih, sama dengan harness lain)

WATCHED = [LINT, os.path.join(ROOT, "project.yml"),
           os.path.join(ROOT, "Packages")]

SPEC = "project.yml"
# Kunci yang dideklarasikan engine dan harus sampai ke project.yml.
# Dibaca dari sumber pada saat jalan, bukan ditulis mati — angka/jumlah yang
# ditulis mati di harness adalah jangkar yang membusuk (lihat cacat R10 di
# `bukti-mutasi-aturan-ui.py`).
KEY = "NSLocalNetworkUsageDescription"
INFOPLIST_KEY = f"INFOPLIST_KEY_{KEY}"
DECL_RE = rf'static\s+let\s+\w+\s*=\s*"{KEY}"'

failures: list[str] = []


def copy_repo() -> str:
    """Salin seluruh pohon yang dibaca aturan, kecuali `.git`/`.build`.

    Kenapa utuh, bukan hanya `project.yml`. Aturan 30 membaca `Packages/`;
    salinan parsial membuat aturan lain berbunyi dan menenggelamkan tanda
    yang dicari — cacat yang sama persis dengan versi pertama
    `bukti-mutasi-aturan-ui.py`.
    """
    workdir = tempfile.mkdtemp(prefix="gerbang-kunci-izin-")
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
    import re
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
    failures.append(f"  Aturan 30 / {nama}: {nyata} padahal diharapkan {kata}")


def cek() -> None:
    # Pra-syarat jangkar. Kalau ini tidak ada, seluruh harness di bawah
    # mengukur keadaan yang tidak pernah disuntik — dan melaporkan hijau
    # atas ketiadaan.
    spec_src = open(os.path.join(ROOT, SPEC), encoding="utf-8").read()
    if INFOPLIST_KEY not in spec_src:
        print(f"LEWAT: {INFOPLIST_KEY} tidak ada di {SPEC} — harness perlu disesuaikan")
        sys.exit(1)
    decl_path = None
    import re
    for root, _dirs, files in os.walk(os.path.join(ROOT, "Packages")):
        if ".build" in root.split(os.sep):
            continue
        for name in files:
            if not name.endswith(".swift"):
                continue
            p = os.path.join(root, name)
            try:
                if re.search(DECL_RE, open(p, encoding="utf-8").read()):
                    decl_path = os.path.relpath(p, ROOT)
                    break
            except OSError:
                continue
        if decl_path:
            break
    if decl_path is None:
        print(f"LEWAT: deklarasi {KEY} tidak ditemukan di Packages/ — "
              "harness perlu disesuaikan")
        sys.exit(1)
    print(f"  jangkar: {KEY} dideklarasi di {decl_path}, ada di {SPEC}")

    # ── Keadaan 1: kode benar -> diam ───────────────────────────────────
    wd = copy_repo()
    try:
        _, out = run_lint(wd)
        expect("kode benar (harus diam)", finding(out, "30") is not None, False)
    finally:
        shutil.rmtree(wd, ignore_errors=True)

    # ── Keadaan 2: kunci dihapus dari project.yml -> berbunyi ────────────
    wd = copy_repo()
    try:
        p = os.path.join(wd, SPEC)
        src = open(p, encoding="utf-8").read()
        import re
        new = re.sub(rf"^\s*{INFOPLIST_KEY}\s*:.*$\n", "", src,
                     count=1, flags=re.M)
        if new == src:
            failures.append("  Aturan 30: penyuntingan project.yml tidak "
                            "mengubah apa pun — cacatnya tidak tersuntik")
        else:
            open(p, "w", encoding="utf-8").write(new)
            _, out = run_lint(wd)
            body = finding(out, "30")
            fired = body is not None and KEY in body
            expect("kunci dihapus dari project.yml (harus merah, sebut kunci)",
                   fired, True)
    finally:
        shutil.rmtree(wd, ignore_errors=True)

    # ── Keadaan 3: deklarasi dihapus -> diam (kontrol negatif) ───────────
    wd = copy_repo()
    try:
        p = os.path.join(wd, decl_path)
        src = open(p, encoding="utf-8").read()
        import re
        new = re.sub(rf'^\s*public static let \w+\s*=\s*"{KEY}"\s*$', "",
                     src, count=1, flags=re.M)
        if new == src:
            # Deklarasinya mungkin tidak `public`; coba tanpa pengubah.
            new = re.sub(rf'^\s*static let \w+\s*=\s*"{KEY}"\s*$', "",
                         src, count=1, flags=re.M)
        if new == src:
            failures.append("  Aturan 30: deklarasi tidak tersunting — "
                            "keadaan kontrol tidak tersuntik")
        else:
            open(p, "w", encoding="utf-8").write(new)
            _, out = run_lint(wd)
            body = finding(out, "30")
            # Himpunan kosong dilaporkan keras oleh skripnya sebagai
            # PERINGATAN. Menganggap itu "merah" akan membuat keadaan 2
            # lulus walau aturan tidak mengukur kepatuhan; karena itu
            # keadaan ini menuntut badannya BUKAN temuan kepatuhan.
            kepatuhan = body is not None and "tidak ada di project.yml" in body
            expect("deklarasi dihapus (harus diam, bukan temuan kepatuhan)",
                   kepatuhan, False)
    finally:
        shutil.rmtree(wd, ignore_errors=True)


def main() -> int:
    mutasi_sumber.require_clean_sources(WATCHED)
    print("== Buktikan Aturan 30 berbunyi pada kepatuhan yang hilang ==")
    cek()
    if failures:
        print("\nGERBANG GAGAL: ada keadaan yang tidak sesuai harapan.")
        for f in failures:
            print(f)
        return 1
    print("\nBersih: Aturan 30 berbunyi pada kunci izin yang hilang dari "
          "project.yml, dan diam pada kode yang benar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
