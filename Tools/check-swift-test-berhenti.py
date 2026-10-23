#!/usr/bin/env python3
"""`swift-test.sh` wajib berhenti setelah jalur Docker-nya, bukan jatuh tembus.

Kenapa gerbang ini ada.

`swift-test.sh` punya dua jalur: `sudo docker run` (mesin pengembang) dan
`swift` langsung (kontainer CI, yang tidak punya Docker). Jalur kedua
ditambahkan pada `9e583eb` justru karena jalur pertama mustahil di CI.

Yang tidak diperhatikan saat itu: `jalankan_docker` **kembali** alih-alih
keluar. Setelah ia selesai, kendali jatuh ke cabang "tidak ada Docker" di
bawahnya, sehingga mesin yang **punya** Docker mencetak:

    1098 tests, with 0 failures
    GAGAL: tidak ada Docker dan tidak ada `swift` di PATH.
    EXIT=127

Dua akibatnya, dan yang kedua yang berbahaya:

  * Mesin pengembang melihat "GAGAL" setelah suite hijau — membingungkan,
    tetapi setidaknya terlihat.
  * Setiap pemanggil yang membaca exit code — termasuk harness mutasi yang
    memanggil skrip ini — menerima **127**, membacanya sebagai "suite
    merah", lalu melaporkan "suite tidak hijau pada kode benar". Gejala itu
    menunjuk ke kode produksi padahal kode produksinya benar. Itu persis
    bentuk kegagalan yang docstring `swift-test.sh` sendiri sebut sebagai
    yang paling berbahaya.

Kenapa CI tidak menangkapnya: CI berjalan **di dalam** kontainer `swift:6.0`
tanpa Docker, jadi cabang `jalankan_docker` tidak pernah diambil di sana.
Bug ini hanya hidup di mesin yang punya Docker — yaitu mesin setiap
pengembang, dan bukan mesin yang memutuskan hijau/merah.

Yang diukur di sini adalah **alur kendali**, bukan hasil uji. Karena itu
`docker` dan `sudo` diganti tiruan: tiruan `docker` mencetak satu baris
"suite hijau" dan keluar 0, sehingga skrip asli berjalan sampai titik yang
menarik. Kalau skrip berhenti di jalur Docker, exit-nya 0 dan tidak ada
keluhan "tidak ada Docker". Kalau ia jatuh tembus, exit-nya 127 dan keluhan
itu muncul — dan itulah yang ditangkap.

Yang TIDAK diklaim: gerbang ini tidak menjalankan Swift sama sekali, jadi ia
tidak membuktikan suite-nya hijau. Itu tugas `swift-test.sh` sendiri dan
langkah CI. Yang dijaga di sini satu hal sempit: setelah jalur Docker
selesai, skrip **berhenti**.

`prove_itself` di bawah membuktikan gerbangnya bisa merah: skrip yang sama
dijalankan dengan `exit 0` dibuang, dan hasilnya harus 127. Gerbang yang
hijau pada hari ia ditulis tidak membuktikan apa pun.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKRIP = os.path.join(ROOT, "swift-test.sh")

#: Tiruan `docker`: cukup mencetak satu baris yang menyerupai ringkasan suite
#: lalu keluar 0. Isinya sengaja tidak meniru keluaran Swift sungguhan —
#: gerbang ini tidak mengukur keluaran Swift, hanya alur kendali skrip.
DOCKER_TIRUAN = """#!/bin/sh
echo "Executed 1 tests, with 0 failures (0 unexpected)"
exit 0
"""

#: Tiruan `sudo -n true` (dipakai skrip untuk mengukur keterjangkauan daemon)
#: dan `sudo -n docker …`. Keduanya harus berhasil supaya cabang Docker diambil.
SUDO_TIRUAN = """#!/bin/sh
# Buang `-n` bila ada; sisa argumen dijalankan apa adanya.
[ "$1" = "-n" ] && shift
exec "$@"
"""


def jalankan(skrip_isi, label):
    """Jalankan `skrip_isi` dengan `docker`/`sudo` tiruan di PATH-nya."""
    with tempfile.TemporaryDirectory() as tmp:
        bin_dir = os.path.join(tmp, "bin")
        os.makedirs(bin_dir)
        for nama, isi in (("docker", DOCKER_TIRUAN), ("sudo", SUDO_TIRUAN)):
            path = os.path.join(bin_dir, nama)
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(isi)
            os.chmod(path, 0o755)
        target = os.path.join(tmp, "swift-test.sh")
        with open(target, "w", encoding="utf-8") as handle:
            handle.write(skrip_isi)
        os.chmod(target, 0o755)
        env = dict(os.environ)
        env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "")
        hasil = subprocess.run(["/bin/bash", target], cwd=tmp,
                               capture_output=True, text=True, env=env)
        return hasil


def baca_skrip():
    with open(SKRIP, encoding="utf-8") as handle:
        return handle.read()


def audit(isi):
    """Kembalikan (ok, pesan) untuk isi skrip yang diberikan."""
    hasil = jalankan(isi, "audit")
    keluaran = hasil.stdout + hasil.stderr
    if hasil.returncode == 0:
        return True, "exit 0 setelah jalur Docker"
    if hasil.returncode == 127 and "tidak ada Docker" in keluaran:
        return False, ("exit 127 — skrip jatuh tembus ke cabang \"tidak ada "
                       "Docker\" setelah jalur Docker selesai")
    return False, f"exit {hasil.returncode} (bukan 0): {keluaran.strip()[:200]}"


def _mutasi_buang_exit(isi):
    """Bentuk cacat aslinya: `exit 0` setelah `jalankan_docker` dibuang."""
    baris = isi.splitlines(keepends=True)
    keluaran = []
    for i, b in enumerate(baris):
        if b.strip() == "exit 0" and i > 0:
            # Hanya yang berdiri tepat setelah pemanggilan jalur Docker.
            sebelumnya = [x for x in baris[:i] if x.strip()
                          and not x.strip().startswith("#")]
            if sebelumnya and sebelumnya[-1].strip().startswith('jalankan_docker'):
                continue
        keluaran.append(b)
    return "".join(keluaran)


def prove_itself(isi):
    """Gerbang ini harus **bisa** merah. Buktikan, jangan andaikan."""
    rusak = _mutasi_buang_exit(isi)
    if rusak == isi:
        print("SALAH bukti-diri: mutasi tidak mengubah apa pun — "
              "`exit 0` setelah jalankan_docker tidak ditemukan")
        return ["mutasi tidak berlaku: gerbang ini tidak mengukur yang diklaimnya"]
    ok, pesan = audit(rusak)
    if ok:
        print("SALAH bukti-diri: skrip tanpa `exit 0` masih lolos — "
              "gerbang ini tidak menangkap cacatnya")
        return ["gerbang hijau pada bentuk cacat aslinya"]
    print(f"OK    bukti-diri: tanpa `exit 0` -> merah ({pesan})")
    return []


def main():
    if not os.path.exists(SKRIP):
        print(f"GAGAL: {SKRIP} tidak ada")
        return 1

    isi = baca_skrip()
    ok, pesan = audit(isi)
    print(f"{'OK   ' if ok else 'GAGAL'} pohon utuh            -> {pesan}")

    gagal = [] if ok else [pesan]
    gagal += prove_itself(isi)

    print()
    if gagal:
        print(f"{len(gagal)} masalah:")
        for g in gagal:
            print(f"  - {g}")
        return 1
    print("Alur kendali swift-test.sh sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
