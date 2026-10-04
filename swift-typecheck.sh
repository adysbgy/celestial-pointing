#!/usr/bin/env bash
# Gate kedua untuk perubahan Apps/: **typecheck**, bukan cuma `parse`.
#
# Kenapa file ini ada: `swiftc -parse` hanya memeriksa sintaks, bukan tipe.
# Semua yang keliru karena tipe — argumen hilang, API Apple-only, simbol yang
# tidak ada — lolos lokal lalu baru meledak di CI macOS, satu siklus penuh
# (~2 menit) per kesalahan. Dua cacat nyata ditemukan lewat gate ini:
# `replaceItem(at:withItemAt:)` yang menuntut argumen tambahan, dan
# `containerURL(forSecurityApplicationGroupIdentifier:)` yang hanya ada di
# Apple platform.
#
# Batasnya jujur dan disengaja, dan batasnya **tidak bisa dihapus** di Linux:
#
# 1. Hanya berkas yang mengimpor Foundation/CelestialEngine/PointingKit yang
#    bisa di-typecheck di sini. Berkas SwiftUI (WidgetKit/Canvas/Combine) tidak
#    bisa — SDK-nya tidak ada. Itu bukan kelalaian, itu batas platform.
# 2. Akibatnya cacat tipe di berkas SwiftUI (mis. `switch` yang cabangnya
#    bertipe beda, atau initializer WidgetKit yang salah) **tetap hanya ketahuan
#    dari CI macOS**. Gate ini menutup jalur Foundation/store, bukan jalur UI.
#    Batas kedua itu tidak akan pernah bisa ditutup di Linux.
#
# Jadi: jangan menganggap gate ini sebagai pengganti CI untuk berkas UI.
# Yang bisa diperiksa lokal, diperiksa lokal; yang tidak bisa, jujur tetap
# menunggu CI.
#
# Pakai: ./swift-typecheck.sh
set -uo pipefail
cd "$(dirname "$0")"

# Berkas yang tidak mengimpor SwiftUI/UIKit/AppKit/Combine — aman di Linux.
TYPECHECKABLE=(
  Apps/Shared/Complication/ComplicationStore.swift
  Apps/Shared/ObjectKindLabels.swift
)

echo "== Build paket (modul untuk typecheck) =="
docker_run() {
  sudo -n docker run --rm -v "$PWD":/src -w /src swift:6.0 "$@"
}

docker_run bash -lc 'swift build --package-path Packages/PointingKit   2>&1 | tail -1'
docker_run bash -lc 'swift build --package-path Packages/CelestialEngine 2>&1 | tail -1'

# swiftc di Linux tidak bisa menemukan .build di dalam package; path-nya
# ditentukan dari arsitektur host. Jadi semua typecheck juga di dalam Docker —
# flank: menjalankan swiftc di luar container menghasilkan "command not found"
# yang terlihat seperti "gate lulus".
ARCH=$(uname -m)
PK="/src/Packages/PointingKit/.build/${ARCH}-unknown-linux-gnu/debug"
CE="/src/Packages/CelestialEngine/.build/${ARCH}-unknown-linux-gnu/debug"
CA="/src/Packages/PointingKit/.build/checkouts/AstronomyKit/Sources/CLibAstronomy"

echo "== Typecheck: ${TYPECHECKABLE[*]} =="
docker_run bash -lc "swiftc -typecheck -swift-version 5 \
  -I '$PK/Modules' -I '$CE/Modules' -I '$CA' \
  -Xcc -fmodule-map-file='$CA/module.modulemap' \
  -L '$PK' -L '$CE' \
  ${TYPECHECKABLE[*]}"
status=$?

echo "== Parse semua berkas Apps/ (sintaks saja) =="
docker_run bash -lc '
while IFS= read -r f; do
  swiftc -parse -swift-version 5 "$f" || { echo "PARSE FAIL: $f"; exit 1; }
done < <(find Apps -name "*.swift")'
[ $? -ne 0 ] && status=1

if [ "$status" -eq 0 ]; then
  echo "== SEMUA GERBANG LULUS =="
else
  echo "== GERBANG GAGAL =="
fi
exit "$status"