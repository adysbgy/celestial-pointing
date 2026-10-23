#!/bin/bash
# Jalankan unit test di Linux via Docker Swift — tanpa Mac.
#
# Dua paket:
#   Packages/CelestialEngine  — mesin inti (astronomi, resolusi, keselamatan slew)
#   Packages/PointingKit      — logika lapisan app (alur, kalibrasi, haptic, harness)
#
# Keduanya sengaja bebas API Apple, jadi seluruh keputusan produk bisa
# dibuktikan di sini. Yang tersisa untuk Mac hanya pembungkus sensor/UI.
#
# Kenapa skrip ini punya dua jalur, dan kenapa jalur kedua **diukur**
# ===================================================================
#
# Sampai siklus ini skrip ini hanya punya satu jalur: `sudo docker run`.
# Itu benar di mesin pengembang, dan **mustahil** di CI. Job `Engine Tests
# (Linux)` berjalan *di dalam* kontainer `swift:6.0` (`container: image:`),
# dan kontainer itu tidak punya `sudo` maupun `docker`:
#
#     $ ./swift-test.sh
#     ./swift-test.sh: line 19: sudo: command not found
#     EXIT=127
#
# Akibatnya bukan "tiga harness gagal". Akibatnya lebih buruk: harness yang
# memanggil skrip ini menerima exit 127, membacanya sebagai "suite merah",
# lalu melaporkan **"suite tidak hijau pada kode benar"** — gejala yang
# menunjuk ke kode produksi padahal kodenya benar. Tiga harness terdaftar
# (`getaran`, `elongasi-ragu`, `sebaran-gugus`) jatuh begitu, jadi `main`
# merah sejak 17–18 Okt 2026 dengan sebab yang tidak satu pun pesannya sebut.
#
# Perbaikannya **bukan** menghapus keadaannya, dan bukan melonggarkan
# harnessnya. Jalur kedua ditambahkan, dan ia hanya dipakai bila toolchain-nya
# **diukur** sama: `swift --version` harus melaporkan `Swift version 6.0`,
# versi yang sama dengan yang dipin jalur Docker. Kalau tidak cocok, skrip
# ini berhenti keras dengan pesan yang menyebut apa yang ditemukannya —
# bukan diam-diam menjalankan compiler lain, karena gerbang yang mengukur
# toolchain lain bukan gerbang.
#
# Yang TIDAK diklaim: jalur kedua tidak membuktikan citranya `swift:6.0`
# persis (tidak ada `docker` untuk membuktikannya dari dalam); yang diukur
# adalah versi Swift-nya. Perbedaan paket sistem di image lain tidak
# tertangkap di sini — itu harga yang dibayar supaya harness bisa berjalan
# di CI sama sekali.
set -eu
cd "$(dirname "$0")"

# Versi Swift yang dipin kedua jalur. Satu tempat, supaya jalur Docker dan
# jalur langsung tidak bisa menyimpang tanpa ada yang melihatnya.
SWIFT_MAYOR="6.0"
IMAGE="swift:6.0"

jalankan_langsung() {
    # Sama seperti jalur Docker: argumen tambahan selalu untuk CelestialEngine.
    # Repo ini tidak punya `Package.swift` di akarnya, jadi `swift test` dari
    # sana akan gagal dengan pesan yang tidak ada hubungannya dengan uji.
    if [ "$#" -gt 0 ]; then
        cd Packages/CelestialEngine
        exec swift test "$@"
    fi
    for package in CelestialEngine PointingKit; do
        echo "=== $package ==="
        ( cd "Packages/$package" && swift test )
    done
}

jalankan_docker() {
    if [ "$#" -gt 0 ]; then
        exec sudo -n docker run --rm -v "$PWD":/src -w /src/Packages/CelestialEngine \
            "$IMAGE" swift test "$@"
    fi
    for package in CelestialEngine PointingKit; do
        echo "=== $package ==="
        sudo -n docker run --rm -v "$PWD":/src -w "/src/Packages/$package" "$IMAGE" swift test
    done
}

# Jalur Docker hanya kalau keduanya benar-benar bisa dipakai. `command -v
# docker` saja tidak cukup: di banyak mesin `docker` ada tetapi daemonnya
# hanya bisa dijangkau lewat sudo, dan `sudo -n` yang gagal keluar dengan
# kode yang sama dengan "ada uji yang gagal". Jadi keberhasilannya diukur,
# bukan diasumsikan.
if command -v docker >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    jalankan_docker "$@"
fi

# Sampai di sini berarti tidak ada Docker. Satu-satunya jalur yang sah
# adalah menjalankan toolchain yang sama secara langsung — dan itu harus
# dibuktikan, bukan diandaikan.
versi="$(swift --version 2>/dev/null | head -1 || true)"
case "$versi" in
    *"Swift version $SWIFT_MAYOR"*)
        echo "catatan: Docker tidak tersedia; menjalankan toolchain langsung ($versi)."
        jalankan_langsung "$@"
        ;;
    "")
        echo "GAGAL: tidak ada Docker dan tidak ada \`swift\` di PATH." >&2
        echo "        Skrip ini butuh salah satunya; ia tidak akan melaporkan" >&2
        echo "        \"hijau\" atas toolchain yang tidak pernah dijalankan." >&2
        exit 127
        ;;
    *)
        echo "GAGAL: tidak ada Docker, dan \`swift\` yang ada bukan versi $SWIFT_MAYOR:" >&2
        echo "        $versi" >&2
        echo "        Jalur langsung hanya sah untuk toolchain yang sama dengan" >&2
        echo "        citra $IMAGE. Pasang Docker, atau jalankan di dalam citra itu." >&2
        exit 127
        ;;
esac
