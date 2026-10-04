#!/usr/bin/env bash
# Buktikan sebuah mutasi membuat uji BENCIK (Merah), lalu kembalikan.
#
# **Kenapa berkas ini ada.** Repo ini punya sejarah panjang: test yang ditulis
# lalu langsung hijau karena tidak pernah diuji terhadap kode yang salah. Uji
# yang tidak pernah merah adalah formalitas — ia hanya membuktikan bahwa
# kode saat ini cocok dengan ekspektasi penulisnya, tanpa pernah membuktikan
# bahwa ekspektasinya itu menangkap cacat yang diklaimnya.
#
# Yang paling berbahaya: mutasi yang **tidak bisa gagal** — filter yang
# dibuang, ambang yang dibalik, accessor yang diganti `rawValue`-nya. Semuanya
# kompilasi, semuanya lolos gerbang, dan hasilnya adalah UI yang menampilkan
# `sirius` di tempat `Sirius` — benar secara terpisah, salah secara gabungan,
# dan tidak terlihat dari mana pun.
#
# Pakai:
#   ./red-test.sh <berkas-uji> <nama-test> <berkas-sumber> <lama> <baru>
#
# Contoh (mengganti accessor label dengan rawValue):
#   ./red-test.sh Packages/PointingKit/Tests/PointingKitTests/DisplayLabelTests.swift \
#     testNoMessageKindLabelEqualsItsRawValue \
#     Packages/PointingKit/Sources/PointingKit/DisplayLabels.swift \
#     'case .stateRequest:     return "Permintaan keadaan"' \
#     'case .stateRequest:     return "stateRequest"'
set -uo pipefail
cd "$(dirname "$0")"

TEST_FILE="${1:?berkas uji}"
TEST_NAME="${2:?nama test}"
SRC_FILE="${3:?berkas sumber}"
OLD="${4:?teks lama}"
NEW="${5:?teks baru}"

if ! grep -qF -- "$OLD" "$SRC_FILE"; then
  echo "MUTASI GAGAL: teks lama tidak ditemukan di $SRC_FILE"
  echo "  cari: $OLD"
  exit 2
fi

backup=$(mktemp)
cp "$SRC_FILE" "$backup"
restore() { cp "$backup" "$SRC_FILE"; rm -f "$backup"; }
trap restore EXIT

python3 - "$SRC_FILE" "$OLD" "$NEW" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path, encoding="utf-8").read()
if src.count(old) != 1:
    print(f"MUTASI GAGAL: pola muncul {src.count(old)} kali (harus tepat 1)")
    sys.exit(2)
open(path, "w", encoding="utf-8").write(src.replace(old, new))
PY
[ $? -ne 0 ] && { restore; trap - EXIT; exit 2; }

echo "== Mutasi diterapkan =="
# Paket uji diturunkan dari letak berkas uji, bukan ditulis mati di sini.
# Kalau dipatok ke PointingKit, filter untuk uji engine akan berjalan di paket
# yang tidak punya uji itu: swift test keluar 0 dengan "0 tests passed", dan
# Mutasi GAGAL akan dilaporkan sebagai "uji ini tidak menangkap mutasi" —
# hijau palsuk yang persis yang harusnya dicegah oleh skrip ini.
PKG_DIR=$(cd "$(dirname "$TEST_FILE")/../.." && pwd)
REL_PKG=${PKG_DIR#"$PWD"/}
sudo -n docker run --rm -v "$PWD":/src -w "/src/$REL_PKG" \
  swift:6.0 swift test --filter "$TEST_NAME" > /tmp/red-test.log 2>&1
status=$?

# "0 tests" adalah hijau yang menipu: filter tidak cocok dengan nama uji
# mana pun, jadi tidak ada yang diuji dan tidak ada yang gagal.
if ! grep -qE "Executed [1-9][0-9]* tests?" /tmp/red-test.log; then
  echo "== UJI TIDAK BERJALAN — hasil hijau diabaikan =="
  echo "   paket: $REL_PKG, filter: $TEST_NAME"
  grep -E "error:|warning:" /tmp/red-test.log | head -5
  restore
  trap - EXIT
  exit 3
fi

if [ "$status" -ne 0 ]; then
  echo "== UJI MERAH pada kode yang rusak (diharapkan) =="
  grep -E "XCTAssert|error:|failed" /tmp/red-test.log | head -12
  restore
  trap - EXIT
  echo "== Sumber dikembalikan =="
  exit 0
fi

echo "== UJI HIJAU pada kode yang rusak — uji ini tidak menangkap mutasi =="
restore
trap - EXIT
exit 1
