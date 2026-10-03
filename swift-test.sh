#!/bin/bash
# Jalankan unit test di Linux via Docker Swift — tanpa Mac.
#
# Dua paket:
#   Packages/CelestialEngine  — mesin inti (astronomi, resolusi, keselamatan slew)
#   Packages/PointingKit      — logika lapisan app (alur, kalibrasi, haptic, harness)
#
# Keduanya sengaja bebas API Apple, jadi seluruh keputusan produk bisa
# dibuktikan di sini. Yang tersisa untuk Mac hanya pembungkus sensor/UI.
set -eu
cd "$(dirname "$0")"

if [ "$#" -gt 0 ]; then
    exec sudo -n docker run --rm -v "$PWD":/src -w /src/Packages/CelestialEngine swift:6.0 swift test "$@"
fi

for package in CelestialEngine PointingKit; do
    echo "=== $package ==="
    sudo -n docker run --rm -v "$PWD":/src -w "/src/Packages/$package" swift:6.0 swift test
done
