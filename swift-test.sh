#!/bin/bash
# Jalankan unit test engine di Linux via Docker Swift — tanpa Mac.
set -eu
cd "$(dirname "$0")"
exec sudo -n docker run --rm -v "$PWD":/src -w /src/Packages/CelestialEngine swift:6.0 swift test "$@"
