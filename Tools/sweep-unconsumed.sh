#!/usr/bin/env bash
# Sapuan "dihitung tapi tidak pernah dikonsumsi", versi ketat.
#
# Untuk setiap anggota `public` di PointingKit, hitung berapa kali namanya
# muncul di `Apps/` (sasarannya: masuk ke layar), di `Tests/` (apakah
# diuji), dan di `Sources/` selain baris deklarasinya sendiri (apakah
# dipakai logika lain di dalam paket).
#
# Yang dilaporkan: `app=0`. Kombinasi itu tidak otomatis cacat -- API
# public yang hanya dipakai di dalam paketnya sendiri masih hidup -- tapi
# justru di situ kelas "dihitung lalu dibuang" bersembunyi. Jadi daftar ini
# kandidat untuk diperiksa satu per satu, bukan daftar kesalahan.
set -uo pipefail

cd "$(dirname "$0")/.."

grep -rnoE '^\s*public (static )?(var|let|func) [A-Za-z_][A-Za-z0-9_]*' \
  Packages/PointingKit/Sources/PointingKit --include='*.swift' \
  | while IFS=: read -r file line rest; do
      name=$(printf '%s\n' "$rest" | grep -oE '[A-Za-z_][A-Za-z0-9_]*$')
      apps=$(grep -rhoE "\b$name\b" Apps --include='*.swift' 2>/dev/null | wc -l)
      tests=$(grep -rhoE "\b$name\b" Packages/CelestialEngine/Tests \
              Packages/PointingKit/Tests --include='*.swift' 2>/dev/null | wc -l)
      pkg=$(grep -rhoE "\b$name\b" Packages/PointingKit/Sources/PointingKit \
            --include='*.swift' 2>/dev/null | wc -l)
      # 1 = hanya baris deklarasi; >=2 = dipakai di dalam paket juga.
      if [ "$apps" -eq 0 ]; then
        where=$([ "$pkg" -le 1 ] && echo "MATI" || echo "paket saja")
        printf '  %-34s app=%-3s test=%-3s paket=%-3s %-10s %s:%s\n' \
          "$name" "$apps" "$tests" "$pkg" "$where" "$file" "$line"
      fi
    done | sort -k4