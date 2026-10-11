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

# **Syarat kedua ternyata masih bisa dipenuhi judulnya sendiri.**
#
# Versi sebelumnya: `echo "$out" | grep -qF -- "$NEEDLE"`. Judul yang dicetak
# gerbang memuat teks yang sama persis dengan `$NEEDLE` — jadi pencarian itu
# selalu menemukan dirinya sendiri. Terukur, dan bukan hipotesis:
#
#   ./red-lint.sh WatchTheme.swift '<defect font>' 'Aturan 31'
#   -> "== MERAH: gerbang gagal (exit 1) pada 'Aturan 31'"   (exit 0)
#
# yang disuntik adalah cacat **font** (Aturan 1), sementara yang "terbukti"
# adalah Aturan 31 soal arah fase — dua aturan yang tidak berhubungan sama
# sekali. Artinya keempat langkah `red-lint.sh` di CI membuktikan hal yang
# sama: bahwa `swift-ui-lint.sh` keluar bukan-nol. Tidak satu pun
# membuktikan bahwa **aturan yang dinamainya** yang berbunyi.
#
# Yang benar-benar membuktikan: cari **baris temuan** di dalam **bagian
# aturan itu**, bukan judulnya di seluruh keluaran. Temuan dicetak sebagai
# `  <berkas>:<baris>: <pesan>`, dan bagiannya dibatasi header aturan
# berikutnya — jadi temuan Aturan 1 tidak bisa memuaskan permintaan
# Aturan 31 walau keduanya berbunyi bersamaan.
if ! LINT_OUT="$out" LINT_NEEDLE="$NEEDLE" python3 - <<'PY'
import os, re, sys

out = os.environ["LINT_OUT"]
needle = os.environ["LINT_NEEDLE"]
rule = re.search(r"\d+", needle)
if not rule:
    sys.exit(2)                      # penanda tanpa nomor aturan: salah pakai
number = rule.group(0)

# Bagian aturan itu: dari headernya sampai header aturan berikutnya.
header = re.compile(r"^==\s*Aturan\s+(\d+)\b.*$", re.M)
marks = list(header.finditer(out))
section = None
for i, m in enumerate(marks):
    if m.group(1) != number:
        continue
    end = marks[i + 1].start() if i + 1 < len(marks) else len(out)
    section = out[m.end():end]
    break
if section is None:
    sys.exit(3)                      # aturannya tidak mencetak apa pun

# Baris temuan: `path:baris: pesan`, dengan **atau tanpa** indentasi.
#
# Versi pertama menuntut indentasi (`^\s+\S`), dan itu memerah pada kode
# yang benar: Aturan 1 mencetak temuan **tanpa** spasi depan
# (`Apps/…/ReducedLuminanceView.swift:6: Text(…)`) sementara aturan lain
# memakai dua spasi. Bentuk temuan berbeda antar aturan, jadi yang boleh
# diandalkan hanya polanya — bukan tata letaknya.
#
# Yang membedakannya dari prosa penjelas gerbang: prosa memakai awalan
# `-> `, `   Sebab:`, `   Tanpa`, `Bersih:`, atau `Singkatan visual
# ditemukan` — tak satu pun memuat `:<angka>:`. Pemeriksaan ini karena itu
# tidak bisa dipuaskan kalimat penjelas, yang justru lubang versi pertama
# `red-lint.sh` (judul aturan memuaskan dirinya sendiri).
finding = re.compile(r"^\s*\S.*:\d+:", re.M)
sys.exit(0 if finding.search(section) else 4)
PY
then
  echo "== SALAH SASARAN: gerbang gagal, tapi tidak ada temuan di bagian '$NEEDLE' =="
  echo "   Gerbang keluar bukan-nol bisa karena aturan lain; itu tidak"
  echo "   membuktikan aturan '$NEEDLE' berbunyi."
  echo "$out" | grep -v "^Bersih" | grep -v "^== Aturan" | head -10
  exit 1
fi
echo "== MERAH: '$NEEDLE' melaporkan temuan (exit $code) =="
echo "$out" | grep -F -A3 -- "$NEEDLE" | grep -v "^Bersih" | head -8
echo "== Berkas dipulihkan =="
exit 0
