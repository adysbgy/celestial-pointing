#!/usr/bin/env bash
# Gerbang sapu untuk `Apps/`: aturan UI yang tidak bisa ditegakkan compiler.
#
# Kenapa file ini ada: Dynamic Type di brief ("ganti font .system(size:) fix →
# semantik") sudah dikerjakan, lalu **muncul lagi** di berkas yang ditambahkan
# belakangan (`ComplicationWidget.swift`). Tidak ada satupun gerbang yang
# melihatnya: `swiftc -parse` tidak peduli ukuran font, `swift test` di Linux
# tidak bisa membangun SwiftUI sama sekali, dan CI macOS hanya gagal bila ada
# *warning*. Jadi satu-satunya penjaga aturan ini adalah ingatan orang yang
# sedang menulis — dan itu persis yang gagal.
#
# Aturan yang ditegakkan di sini bukan preferensi gaya. Ukuran font tetap
# mengabaikan Dynamic Type: di layar jam 41mm dengan teks yang diperbesar,
# teks 11pt **tidak bisa membesar sama sekali**. Kartu complication justru
# dibaca sekilas, jadi ia paling butuh mengikuti skala pengguna.
#
# Batasnya jujur: ini sapu **teks**, bukan pemeriksaan tipe. Komentar
# sengaja dilewati (proyek ini mendokumentasikan "kenapa" panjang lebar, dan
# beberapa di antaranya menyebut `.system(size:)` sebagai contoh yang
# dilarang). Yang dihitung hanyalah kode.
#
# Pakai: ./swift-ui-lint.sh
set -uo pipefail
cd "$(dirname "$0")"

status=0

# ── Aturan 1: tidak ada ukuran font tetap ──────────────────────────────────
# Sapu `.system(size:` dan `Font.system(size:` pada **kode**, bukan komentar.
# `grep -v '^\s*//'` saja tidak cukup: komentar bisa muncul setelah kode pada
# baris yang sama, jadi potongan sebelum `//` yang diperiksa.
echo "== Aturan 1: tidak ada ukuran font tetap di Apps/ =="
hits=$(while IFS= read -r f; do
  awk -v file="$f" '
    {
      line = $0
      sub(/^/, "", line)
      # Buang komentar sebaris: hanya bagian sebelum "//" yang bisa berupa kode.
      # Awk tidak punya regex non-greedy portabel, jadi index() dipakai.
      idx = index(line, "//")
      if (idx > 0) line = substr(line, 1, idx - 1)
      if (line ~ /\.system\(size:/ || line ~ /Font\.system\(size/) {
        printf "%s:%d: %s\n", file, FNR, $0
      }
    }' "$f"
done < <(find Apps -name '*.swift' | sort))

if [ -n "$hits" ]; then
  echo "Ukuran font tetap ditemukan (abaikan Dynamic Type):"
  echo "$hits"
  echo "-> Pakai font semantik (.caption/.caption2/.footnote/.headline) atau"
  echo "   @ScaledMetric bila ukurannya memang metrik, bukan teks."
  status=1
else
  echo "Bersih: tidak ada .system(size:) pada kode di Apps/."
fi

# ── Aturan 2: teks UI tidak boleh berupa satuan yang tak terbaca ────────────
# "°/dtk" dan "mag" adalah singkatan **visual**: mata bisa membacanya, pembaca
# layar tidak. Keduanya boleh ada di layar, tapi hanya bila ada padanan yang
# diucapkan. Sapu ini tidak bisa membuktikan padanannya ada — ia hanya
# mengingatkan. Sengaja tidak dijadikan kegagalan.
echo
echo "== Aturan 2: singkatan visual di teks UI (peringatan, bukan kegagalan) =="
abbrev=$(grep -rn --include='*.swift' -E '"[^"]*(°/dtk|mag [0-9]|RA |Dec )' Apps/ 2>/dev/null || true)
if [ -n "$abbrev" ]; then
  echo "Singkatan visual ditemukan — pastikan masing-masing punya label"
  echo "VoiceOver yang mengucapkannya lengkap:"
  echo "$abbrev"
else
  echo "Bersih."
fi

# ── Aturan 3: tidak ada aksara non-Latin yang tidak disengaja ───────────────
# Repo ini ditulis dalam bahasa Indonesia dan seluruh teks UI berbahasa
# Indonesia, jadi **seluruh** kode dan komentar harus Latin. Karakter CJK/
# Cyrillic/fullwidth yang muncul hampir selalu **selip**: bukan keputusan
# bahasa, tapi tembolan yang ikut masuk lewat papan ketik atau tempelan.
#
# Kenapa jadi gerbang: selipnya nyaris tak terlihat — di tengah kalimat
# Indonesia ia terbaca sebagai satu kata aneh lalu dilewati — tapi merusak
# repo yang dinyatakan "semua teks Bahasa Indonesia", dan merusak diff
# review. Kasus ini sudah terjadi di repo ini, dan hanya terlihat karena
# sapuan karakter, bukan karena ada yang membaca ulang.
echo
echo "== Aturan 3: tidak ada aksara CJK/Cyrillic/fullwidth di kode =="
# Cakup **seluruh** kode, bukan hanya `Apps/`: selip yang sama bisa muncul
# di `Packages/`, yang tidak akan pernah terjangkau sapuan `Apps/` saja.
# Satu sapuan untuk satu aturan.
cjk=$(grep -rnP --include='*.swift' '[\x{3000}-\x{303F}\x{3040}-\x{30FF}\x{4E00}-\x{9FFF}\x{AC00}-\x{D7AF}\x{FF00}-\x{FFEF}\x{0400}-\x{04FF}]' \
        Apps Packages 2>/dev/null || true)
if [ -n "$cjk" ]; then
  echo "Aksara non-Latin ditemukan — repo ini ditulis bahasa Indonesia:"
  echo "$cjk"
  echo "-> Hapus karakter tersebut; kemungkinan besar selip, bukan pilihan."
  status=1
else
  echo "Bersih: tidak ada aksara non-Latin."
fi

# ── Aturan 4: setiap teks UI harus ada di katalog string ───────────────────
# Katalog `Localizable.xcstrings` sengaja **tidak** diisi otomatis
# (`SWIFT_EMIT_LOC_STRINGS: NO`, alasannya di `project.yml`). Konsekuensinya
# yang biasanya dianggap jelas: string baru yang dipakai di view tapi belum
# ada di katalog **tidak menghasilkan peringatan apa pun** — teksnya
# muncul apa adanya, hanya tidak punya padanan bahasa Inggris.
#
# Itu persis bentuk "hijau yang tidak hijau": build sukses, tidak ada
# warning, tapi lokalisasi sudah setengah jadi tanpa ada yang memberitahu.
# Karena tidak ada gerbang Xcode yang bisa melihatnya, sapuan ini yang
# menggantinya.
echo
echo "== Aturan 4: teks UI tanpa entri di katalog string =="
missing=$(python3 - <<'PY'
import json, os, re, sys

CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"
if not os.path.exists(CATALOG):
    sys.exit(0)  # belum ada katalog: aturan belum berlaku, bukan kegagalan

keys = set(json.load(open(CATALOG, encoding="utf-8"))["strings"])
# Nama produk dan nama percobaan sengaja tidak diterjemahkan.
NOT_LOCALIZED = {"Point & Know", "Experiment 1"}

# Interpolasi SwiftUI tidak bisa jadi kunci katalog; bentuknya dipetakan
# ke kunci format yang benar supaya sapuan ini tidak melaporkannya sebagai
# hilang (dan supaya bug formatSpecifier-nya tetap terlihat).
FORMATS = {
    r"Status: \(statusMessage)": "Status: %@.",
    r"\(flow.samples.count) acuan tercatat": "%lld acuan tercatat",
    r"Lokasi: \(engine.location.label)": "Lokasi: %@",
    r"· \(link.sendFailureCount) gagal": "%lld gagal",
}
# `String(format:)` di dalam interpolasi tidak bisa diekstrak; dilewati
# dengan jujur daripada dikarang menjadi kunci.
SKIP_PREFIX = ("Usulan ambang keyakinan",)

# Nama fungsi yang teksnya **tampil ke pengguna**, jadi teksnya wajib ada di
# katalog.
#
# Versi pertama hanya berisi view modifier. Itu menutup `Text`, tombol, dan
# label aksesibilitas — tapi **tidak** menutup metadata WidgetKit. Terbukti
# di berkas yang sama: `ComplicationWidget.swift` menyatu
# `.description("Objek terakhir yang dikenali, tanpa membuka app.")`, yaitu
# teks yang benar-benar tampil di layar pemilihan complication watchOS, dan
# sapuan ini **tidak melihatnya** — ia hanya melaporkan tiga kemunculan
# "Point & Know" yang memang tidak diterjemahkan.
#
# Jadi daftar ini diperluas ke peritel yang teksnya kelihatan: metadata
# complication, dan pengenal aksesibilitas. Semuanya ditambahkan karena
# masing-masing **memang menampilkan teks**, bukan karena "kira-kira juga".
# Kandidat yang tidak pernah muncul di repo ini sengaja tidak dimasukkan:
# daftar panjang peritel yang tidak pernah dipakai hanya menambah permukaan
# untuk salah baca, bukan perlindungan.
POS_NAMES = (
    r'Text|navigationTitle|navigationSubtitle|Button|Label|Toggle|Picker|'
    r'Section|NavigationLink|accessibilityLabel|accessibilityHint|'
    r'accessibilityValue|accessibilityActionName|confirmationDialog|alert|'
    r'confirmationTitle|cancelTitle|primaryActionTitle|destructiveTitle|'
    r'configurationDisplayName|description|help|footer|header|prompt|message|'
    # `row`/`detailRow` adalah helper label-lebar di repo ini: keduanya
    # **menampilkan teksnya ke layar**, jadi keduanya wajib berpadanan.
    r'row|detailRow'
)

# Sapuan mencari **setiap literal langsung di dalam argumen** sebuah peritel
# teks, bukan hanya yang pertama.
#
# Kenapa harus begitu — dan ini kelas cacat yang sama seperti dua siklus
# sebelumnya, kali ini di dalam aturan yang dibuat untuk menutupnya. Bentuk
# lama memakai pola `\b(Text|row|...)\s*\(\s*"(...)"`: satu literal, dan ia
# **harus** persis setelah tanda buka. Konsekuensinya terukur:
# `row("Keadaan", state.shortLabel)` terbaca, sementara
# `row("Device motion", motion.isAvailable ? "Ada" : "Tidak ada")` tidak
# terbaca sama sekali. Jadi nilai — separuh isi setiap baris tabel — tidak
# pernah diperiksa, dan gerbangnya hijau sepanjang waktu.
#
# Argumen kedua sebuah `row` **selalu** teks tampilan: itu definisi helper-nya
# (`row(_ title: String, _ value: String)`). Jadi yang membedakan teks
# tampilan dari bukan-teks bukan posisi argumen, melainkan peritelnya.
POS = re.compile(r'\b(' + POS_NAMES + r')\s*\(')

# `%`-specifier printf, dipakai hanya untuk mengenali **template format**
# (`"%.1f°"`, `"%lld gagal"`) yang memang bukan teks tampilan. Tanpa ini,
# setiap `String(format:)` di repo dilaporkan sebagai teks yang hilang — dan
# gerbang yang selalu merah akan dimatikan orang lain saat ia berbunyi.
# `%%` ikut dikenali supaya `"%.0f%%"` (tanda persen harfiah) juga gugur.
CONV = re.compile(r'%(?:%|(?:[-+ #0]*)[\d*]*(?:\.\d+|\.\*)?[a-zA-Z@])')


def strip_line_comments(text):
    """Buang komentar `//` yang berada di **luar** literal string.

    Baris sebaris hanya boleh dibuang kalau `//` ada di luar literal — yang
    pertama bisa jadi bagian dari literal itu sendiri (URL, regex, path).
    `Text("// ...")` adalah kode; `// Text("...")` adalah penjelasan.

    Kenapa ini penting: tanpa itu, komentar yang **menjelaskan** aturan ini
    akan dilaporkan sebagai pelanggaran oleh aturan ini sendiri — persis
    gerbang yang selalu merah dan akan dimatikan orang lain saat ia berbunyi.
    """
    lines = []
    for raw in text.split("\n"):
        out, in_string, escaped, i = [], False, False, 0
        while i < len(raw):
            ch = raw[i]
            if in_string:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == '"':
                    in_string = False
            else:
                if ch == '"':
                    in_string = True
                elif ch == "/" and i + 1 < len(raw) and raw[i + 1] == "/":
                    break
            out.append(ch)
            i += 1
        lines.append("".join(out))
    return "\n".join(lines)


def read_literal(src, start):
    """Baca satu literal string mulai dari tanda kutip di `start`.

    Mengembalikan `(indeks setelah kutip penutup, isi tanpa kutip, ada
    interpolasi)`. Interpolasi `\\(...)` dihitung sebagai **satu kesatuan**,
    jadi tanda kutip di dalamnya tidak menutup literal — itu bentuk yang
    memang dipakai repo ini (`"· \\(link.sendFailureCount) gagal"`).
    """
    i, escaped, buf, interpolated = start + 1, False, [], False
    while i < len(src):
        ch = src[i]
        if escaped:
            escaped = False
            if ch == "(":
                interpolated = True
                j, depth = i, 0
                while j < len(src):
                    inner = src[j]
                    if inner == '"':
                        j = read_literal(src, j)[0]
                        continue
                    if inner == "(":
                        depth += 1
                    elif inner == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                buf.append(src[i:j + 1])
                i = j + 1
                continue
            buf.append(ch)
        elif ch == "\\":
            escaped = True
            buf.append(ch)
        elif ch == '"':
            return i + 1, "".join(buf), interpolated
        else:
            buf.append(ch)
        i += 1
    return i, "".join(buf), interpolated


def direct_arguments(src, open_index):
    """Literal pada **kedalaman argumen 1**, beserta label parameternya.

    Kedalaman dipakai sebagai pengganti daftar nama parameter yang akan selalu
    usang. Hasilnya diperiksa terhadap repo: satu-satunya label yang pernah
    muncul di sana adalah `systemImage`, dan literal di bawahnya memang nama
    SF Symbol (`"square.and.arrow.up"`), bukan teks tampilan. Jadi label itu
    disaring **karena data**, bukan karena tebakan.
    """
    depth, i, found = 0, open_index, []
    while i < len(src):
        ch = src[i]
        if ch == '"':
            end, text, interpolated = read_literal(src, i)
            if depth == 1:
                before = src[max(0, i - 60):i]
                label = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*:\s*$', before)
                found.append((i, text, interpolated,
                              label.group(1) if label else None))
            i = end
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return found
        i += 1
    return found

found = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        source = strip_line_comments(
            open(path, encoding="utf-8").read())

        for m in POS.finditer(source):
            line = source[:m.start()].count("\n") + 1
            for offset, text, interpolated, label in direct_arguments(
                    source, m.end() - 1):
                # Nama SF Symbol: satu-satunya parameter berlabel yang
                # membawa literal di repo ini, dan isinya bukan teks tampilan.
                if label == "systemImage":
                    continue
                if any(text.startswith(p) for p in SKIP_PREFIX):
                    continue
                if text in FORMATS:
                    key = FORMATS[text]
                elif interpolated:
                    # Interpolasi murni tidak punya bentuk katalog; yang
                    # punya bentuk dipetakan lewat FORMATS di atas.
                    continue
                elif CONV.search(text) and not re.search(
                        r"[A-Za-z]", CONV.sub("", text)):
                    # Template format murni (`"%.1f°"`), bukan teks tampilan.
                    # Syarat "tanpa huruf" itu yang menjaga `"%lld gagal"`
                    # tetap diperiksa sebagai teks.
                    continue
                else:
                    key = text
                if key in NOT_LOCALIZED or key in keys:
                    continue
                found.append(f"  {path}:{line}: {key!r}")

print("\n".join(found) if found else "")
PY
)
if [ -n "$missing" ]; then
  echo "Teks UI berikut belum ada di katalog (tanpa padanan bahasa Inggris):"
  echo "$missing"
  echo "-> Tambahkan kunci + terjemahan 'en' ke Localizable.xcstrings."
  status=1
else
  echo "Bersih: setiap teks UI punya entri di katalog."
fi

# ── Aturan 5: kunci `project.yml` yang benar-benar dibaca XcodeGen ─────────
# `project.yml` tidak pernah dikompilasi. XcodeGen membaca YAML-nya dengan
# pemetaan LENIENT: kunci yang tidak dikenal diabaikan diam-diam, dan
# `xcodegen generate` tetap keluar 0.
#
# Yang nyata terjadi di repo ini: `knownRegions: [id, en]` ditulis dengan
# komentar yang terdengar benar ("tanpa ini Xcode tidak tahu `en` ada"),
# padahal `SpecOptions` tidak punya field itu. XcodeGen menurunkan
# `knownRegions` sendiri dari isi katalog string. Kuncinya tidak pernah
# menyebutkan apa pun ke hasil generate, dan tidak ada gerbang yang
# melihatnya: `swiftc -parse` tidak membaca YAML, `swift test` tidak
# membangun proyek, dan CI hanya memanggil `xcodegen generate` yang keluar 0.
#
# Batasnya dinyatakan jujur: daftar kunci diambil dari XcodeGen 2.46.0,
# jadi ia usang begitu XcodeGen menambah opsi. Karena itu daftar itu simpan
# sebagai berkas (`Tools/xcodegen-known-keys.txt`) beserta perintah untuk
# memperbarui, bukan dikubur di dalam skrip ini.
echo
echo "== Aturan 5: kunci options/settings di project.yml yang dikenal XcodeGen =="
KEYS_FILE="Tools/xcodegen-known-keys.txt"
if [ ! -s "$KEYS_FILE" ]; then
  echo "PERINGATAN: $KEYS_FILE tidak ada atau kosong."
  echo "Aturan 5 DILEWATI, bukan lulus."
else
  unknown=$(KEYS_FILE="$KEYS_FILE" python3 - <<'PY'
import os, re

known = set(open(os.environ["KEYS_FILE"], encoding="utf-8").read().split())
lines = open("project.yml", encoding="utf-8").read().split("\n")

# Yang diperiksa adalah kunci LANGSUNG di `options:` dan `settings:`, pada
# tingkat indentasi yang sama dengan header itu sendiri.
#
# Kenapa harus sebatas itu, dan kenapa anak-anak dikecualikan: YAML di bawah
# `settings:` punya anak yang **sah** (`base:`, `configs:`), dan kunci di
# bawah keduanya **bebas** -- nama konfigurasi (`Debug`) dan build setting
# apa pun (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`). Versi pertama menelusuri
# seluruh turunan dan melaporkan enam kunci yang sah sebagai "tidak dikenal":
# itu persis bentuk gerbang yang selalu merah, yang akan dimatikan orang lain
# saat ia berbunyi. Kunci target juga punya skema sendiri
# (`sources`, `dependencies`, ...) dan tidak terkait aturan ini.
STRUCTURAL = {"base", "configs"}
OPTIONS_SCHEMA = {
    "deploymentTarget",   # map platform -> versi
    "disabledValidations",
    "fileTypes",
    "groupOrdering",
}

def direct_keys(header, allowed_children):
    found, inside, parent_indent = [], False, 0
    for raw in lines:
        if re.match(header, raw):
            inside, parent_indent = True, len(raw) - len(raw.lstrip())
            continue
        if inside:
            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                continue
            indent = len(raw) - len(raw.lstrip())
            if indent <= parent_indent:
                break
            if indent != parent_indent + 2:
                continue  # sudah masuk anak, biarkan
            m = re.match(r"\s+([A-Za-z_][A-Za-z0-9_]*)\s*:", raw)
            if m and m.group(1) not in allowed_children:
                found.append(m.group(1))
    return found

bad = []
for key in (direct_keys(r"^options:\s*$", OPTIONS_SCHEMA)
           + direct_keys(r"^settings:\s*$", STRUCTURAL)):
    if key not in known:
        bad.append(key)

print("\n".join(sorted(set(bad))))
PY
)
  if [ -n "$unknown" ]; then
    echo "Kunci yang TIDAK dikenal XcodeGen (diabaikan diam-diam):"
    echo "$unknown" | sed 's/^/  - /'
    echo "-> Kalau memang opsi XcodeGen, tambahkan ke $KEYS_FILE."
    echo "   Kalau bukan, hapus dari project.yml."
    status=1
  else
    echo "Bersih: semua kunci options/settings dikenal XcodeGen."
  fi
fi

# ── Aturan 6: paritas kunci katalog untuk teks yang DIHASILKAN di paket ────
# Aturan 4 menyapu literal `Text("...")` di `Apps/`. Itu benar, dan ia tetap
# hijau — padahal teks yang paling sering dibaca sekilas ("Siap", "Arahkan",
# "Terkunci", "Kurang yakin", "Sensor mati", kalimat panduannya, "Yakin/Ragu/
# Tidak tahu") **tidak pernah melewati literal itu**. Semuanya di-*switch*
# di dalam `PointingKit`, jadi sapuan `Apps/` tidak punya apa pun untuk
# dilihat, dan `SWIFT_EMIT_LOC_STRINGS: NO` membuat Xcode juga tidak akan
# mengisinya sendiri.
#
# Akibatnya kunci katalog itu bisa dihapus satu per satu — atau belum pernah
# ditambahkan — dan **tidak ada satu pun gerbang yang merah**, sementara
# teksnya tetap tampil dalam Bahasa Indonesia di semua bahasa.
#
# Aturan ini menutup kelas itu dengan memeriksa **paritas dua arah** antara
# `LocalizedText.allKeys` (satu-satunya sumber kunci di paket) dan
# `Localizable.xcstrings`: kunci dideklarasikan tapi tidak ada di katalog, dan
# katalog punya kunci dari paket yang tidak dideklarasikan.
echo
echo "== Aturan 6: paritas kunci katalog teks yang dihasilkan di PointingKit =="
SRC="Packages/PointingKit/Sources/PointingKit/TextLocalization.swift"
if [ ! -f "$SRC" ]; then
  echo "PERINGATAN: $SRC tidak ada."
  echo "Aturan 6 DILEWATI, bukan lulus."
else
  parity=$(SRC_DIR="Packages/PointingKit/Sources/PointingKit" python3 - <<'PY'
import glob, json, os, re, sys

CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"

# Kunci dibaca dari SELURUH sumber paket, bukan hanya satu berkas.
#
# Versi pertama hanya membaca `TextLocalization.swift`. Itu cukup selama
# semua kunci dideklarasikan di sana — tapi begitu kunci label jenis benda
# hidup di berkas sendiri (`ObjectKindLabels.swift`), `declared` kehilangan
# seluruh 10 kunci itu: Arah 1 tidak akan melaporkan "dideklarasikan tapi
# tidak ada di katalog", dan suite tetap hijau. Persis "hijau yang tidak
# hijau" yang aturan ini dibuat untuk menutup — terjadi di dalam aturan
# itu sendiri.
#
# Arah 2 (kunci katalog yang tak dideklarasikan) tetap menangkap kunci
# `object.kind.*` hanya kalau namespace-nya ikut ditambahkan di bawah —
# itu yang diverifikasi dua arah di salinan.
declared = set()
for path in sorted(glob.glob(os.path.join(os.environ["SRC_DIR"], "*.swift"))):
    src = open(path, encoding="utf-8").read()
    declared.update(re.findall(r'key:\s*"([^"]+)"', src))
if not declared:
    print("PERINGATAN:tidak ada kunci yang bisa dibaca dari " + os.environ["SRC_DIR"])
    sys.exit(0)

if not os.path.exists(CATALOG):
    print("BELUM-ADA-KATALOG")
    sys.exit(0)

strings = json.load(open(CATALOG, encoding="utf-8"))["strings"]

problems = []

# Arah 1: dideklarasikan di paket, tidak ada di katalog.
for key in sorted(declared - set(strings)):
    problems.append(f"  kunci dideklarasikan tapi tidak ada di katalog: {key!r}")

# Arah 2: ada di katalog, tapi tidak dideklarasikan di paket. Ini yang
# membuat kunci tidak bisa "dibuang diam-diam" dari `allKeys` supaya
# pemeriksaan Arah 1 terasa cukup.
#
# Namespace `object.kind.` ikut dicantumkan karena label jenis benda juga
# dihasilkan di paket — lewat `LocalizedText`, sama seperti tiga kelompok
# lainnya. Tanpa ia, menghapus `kindStarLabel` dari `allKeys` tidak akan
# terlihat oleh gerbang ini.
namespace = re.compile(
    r"^(pointing\.state|confidence\.level|link\.kind|object\.kind)\.")
for key in sorted(set(strings) - declared):
    if namespace.match(key):
        problems.append(f"  kunci katalog tak dideklarasikan di paket: {key!r}")

# Arah 3: nilai bawaan Bahasa Indonesia pada paket harus **tidak kosong**
# dan tidak sama dengan kuncinya (kalau iya, `text()` tidak bisa
# membedakan dua kasus itu).
for path in sorted(glob.glob(os.path.join(os.environ["SRC_DIR"], "*.swift"))):
    src = open(path, encoding="utf-8").read()
    for key, value in re.findall(
            r'key:\s*"([^"]+)",\s*\n?\s*id:\s*"([^"]*)"', src):
        if not value:
            problems.append(f"  nilai bawaan kosong: {key!r}")
        elif value == key:
            problems.append(f"  nilai bawaan sama dengan kunci: {key!r}")

print("\n".join(problems) if problems else "")
PY
)
  if [ "$parity" = "PERINGATAN" ] || printf '%s' "$parity" | grep -q '^PERINGATAN'; then
    printf '%s\n' "$parity"
    echo "-> Perbaiki berkasnya, atau-build ulang daftar allKeys."
    status=1
  elif [ "$parity" = "BELUM-ADA-KATALOG" ]; then
    echo "Katalog belum ada: aturan 6 belum berlaku, bukan kegagalan."
  elif [ -n "$parity" ]; then
    echo "Katalog dan teks di paket tidak sebanding:"
    printf '%s\n' "$parity"
    echo "-> Setiap kunci di LocalizedText.allKeys wajib ada di"
    echo "   Localizable.xcstrings, dan sebaliknya untuk kunci ber-namespace."
    status=1
  else
    echo "Bersih: kunci katalog dan kunci di PointingKit sebanding."
  fi
fi

# ── Aturan 7: gerak tanpa penjaga reduce-motion ────────────────────────────
# `accessibilityReduceMotion` **tidak pernah** dibaca di repo ini sampai unit
# MotionPolicy, padahal ada empat `withAnimation(.spring)` dan satu
# `TimelineView(.animation)` 30 Hz. Persis kelas yang sudah beberapa kali
# menutup siklus sebelumnya: Dynamic Type kembali muncul di berkas yang
# ditambahkan belakangan, aturan 4 buta terhadap metadata WidgetKit. Semuanya
# "hijau yang tidak hijau" — tidak ada gerbang yang merah karena tidak ada
# gerbang yang tahu aturan itu **seharusnya** dibaca.
#
# Yang ditutup di sini adalah **kelas**-nya, bukan satu situs: berkas mana pun
# yang memanggil API gerak wajib merujuk penjaga gerak. `withAnimation` pada
# tombol baru akan tertangkap di commit yang sama, bukan bulan kemudian.
#
# Yang diperiksa adalah nama API **di kode**, sementara penjaga boleh disebut
# di mana saja di berkas (kode atau komentar). Alasannya: dokumentasi aturan
# ini sendiri menyebut `withAnimation`, jadi penyapu yang ikut menghitung
# komentar akan melaporkan dirinya sendiri -- persis gerbang yang selalu merah
# dan akan dimatikan orang lain saat ia berbunyi.
echo
echo "== Aturan 7: API gerak harus punya penjaga reduce-motion =="
motion=$(python3 - <<'PY'
import os, re

# API yang menghasilkan gerak berulang atau transisi.
# `\.animation(` sengaja **tidak** dibatasi isinya. Versi pertama hanya
# mem-pattern `.animation()` (tanpa argumen) -- dan uji injeksi pada
# `.animation(.linear, value: 1)` membuktikan ia lolos. Bentuk tanpa argumen
# justru yang paling jarang di SwiftUI; bentuk dengan argumen adalah yang
# dipakai sungguhan, jadi daftar peritel yang sempit akan menutup kelas cacat
# ini dengan lubang di tempat yang paling mungkin dialam.
MOTION_API = re.compile(
    r"\bwithAnimation\b"
    r"|\.repeatForever\b"
    r"|TimelineView\(\s*\.animation"
    r"|\.animation\s*\(")

# Penjaga yang membuat gerak boleh atau tidak berjalan. `isLuminanceReduced`
# ikut dihitung karena `NightAwareContainer` sudah memakainya sebelum aturan
# ini ada; berkas yang hanyavíا Always-On itu tidak otomatis salah.
GUARD = re.compile(
    r"\breduceMotion\b|\bMotionPolicy\b|\bisLuminanceReduced\b")

bad = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        lines = open(path, encoding="utf-8").read().split("\n")
        for n, raw in enumerate(lines, 1):
            # Komentar dibuang hanya dari sisi yang diperiksa (nama API):
            # dokumentasi aturan ini menyebut `withAnimation`, jadi termasuk
            # kalau tidak dibuang akan melaporkan dirinya sendiri.
            code = raw[:raw.find("//")] if "//" in raw else raw
            if MOTION_API.search(code):
                whole = "\n".join(lines)
                if not GUARD.search(whole):
                    bad.append(f"  {path}:{n}: {raw.strip()[:70]}")
                break  # satu laporan per berkas sudah cukup
print("\n".join(bad) if bad else "")
PY
)
if [ -n "$motion" ]; then
  echo "Gerak dipanggil tanpa penjaga reduce-motion di berkas ini:"
  echo "$motion"
  echo "-> Baca MotionPolicy.allowsContinuousMotion / allowsTransitions"
  echo "   dari PointingKit. Kalau memang boleh tanpa, itu satu kebetulan"
  echo "   yang belum ditulis di mana pun."
  status=1
else
  echo "Bersih: setiap API gerak punya penjaga reduce-motion."
fi

if [ "$status" -eq 0 ]; then
  echo
  echo "== SEMUA GERBANG UI LULUS =="
else
  echo
  echo "== GERBANG UI GAGAL =="
fi
exit "$status"
