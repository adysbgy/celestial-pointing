#!/usr/bin/env bash
# Buktikan sebuah gerbang sapu UI **berbunyi** pada cacat yang diklaimnya
# ditangkap, lalu kembalikan berkasnya.
#
# **Kenapa berkas ini ada.** `swift-ui-lint.sh` adalah gerbang teks: ia tidak
# dikompilasi, tidak punya uji, dan hasilnya hanya "Bersih" atau daftar
# temuan. Itu membuatnya rentan pada cacat yang **paling berbahaya** dari
# semua: hijau karena ia tidak melihat apa pun.
#
# Ini bukan kekhawatiran teoretis. Aturan 15 (warna mode malam) pertama
# kali ditulis dan langsung hijau — lalu ketika cacat yang persis seperti
# yang pernah nyata disuntikkan (`Color(red: 0.62, green: 0.30, blue: 0.16)`
# tanpa penjaga), ia **tetap** hijau. Sebabnya: batas fungsinya memakai
# `rfind("\nfunc")`, yang tidak pernah cocok dengan `private static func`,
# sehingga rentangnya jatuh ke seluruh berkas dan penjaga di fungsi lain
# membuatnya lolos. Jadi gerbang itu lulus pada kode benar *dan* pada kode
# salah — sama saja dengan tidak ada.
#
# `red-test.sh` melakukan hal ini untuk `swift test`. Berkas ini
# melakukannya untuk gerbang sapu: suntik, wajibkan MERAH, pulihkan.
#
# Pakai:
#   ./red-lint.sh <berkas> <teks-yang-disuntik> <penanda-di-output>
#
# Contoh:
#   ./red-lint.sh Apps/Shared/CelestialVisualView.swift \
#     '    private static func warnaUji() -> Color {
#         Color(red: 0.62, green: 0.30, blue: 0.16)
#     }
# ' 'Aturan 15'
set -uo pipefail
cd "$(dirname "$0")"

SRC="${1:?berkas yang disuntik}"
SNIPPET="${2:?teks cacat yang disuntik}"
NEEDLE="${3:?penanda yang wajib muncul di output gerbang (mis. \"Aturan 15\")}"

backup=$(mktemp)
cp "$SRC" "$backup"
restore() { cp "$backup" "$SRC"; rm -f "$backup"; }
trap restore EXIT

# Suntik **setelah** baris `import` terakhir: awal berkas pasti bagian kode,
# bukan komentar atau di dalam tipe, jadi sintaksnya tetap valid.
python3 - "$SRC" "$SNIPPET" <<'PY'
import sys
path, snippet = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
last = max(i for i, l in enumerate(lines) if l.startswith("import "))
out = lines[:last + 1] + [""] + snippet.split("\n") + lines[last + 1:]
open(path, "w", encoding="utf-8").write("\n".join(out))
PY

echo "== Suntik cacat ke $SRC =="
out=$(./swift-ui-lint.sh 2>&1)
code=$?

# Dua syarat, bukan satu — dan urutannya penting.
#
# Coba pertama memeriksa `grep -qF "$NEEDLE"` saja. Itu **selalu** benar:
# `swift-ui-lint.sh` mencetak judul setiap aturan ("== Aturan 15: ...")
# entah ia menemukan sesuatu atau tidak. Jadi pembuktinya sendiri hijau
# pada cacat yang tidak ia buktikan apa pun — hijau palsu pada penjaga
# hijau palsu.
#
# Yang membedakan gerbang berbunyi dari gerbang yang hanya mencetak judul
# adalah **exit code**-nya (`GERBANG UI GAGAL`). Itu yang disyaratkan
# pertama.
if [ "$code" -eq 0 ]; then
  echo "== HIJAU PALSU: gerbang keluar 0 pada kode yang salah =="
  echo "   Gerbang yang lulus pada kode salah sama saja dengan tidak ada."
  exit 1
fi
if ! echo "$out" | grep -qF -- "$NEEDLE"; then
  echo "== SALAH SASARAN: gerbang gagal, tapi bukan karena '$NEEDLE' =="
  echo "$out" | grep -v "^== Aturan" | grep -v "^Bersih" | head -10
  exit 1
fi
echo "== MERAH: gerbang gagal (exit $code) pada '$NEEDLE' =="
echo "$out" | grep -v "^Bersih" | grep -F -A3 -- "$NEEDLE" | head -8
echo "== Berkas dipulihkan =="
exit 0
