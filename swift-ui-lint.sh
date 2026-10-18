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

# ── Pra-syarat: `python3` harus ada ─────────────────────────────────────────
# Sebelas aturan di bawah dijalankan lewat `python3 - <<'PY'`. Kalau
# interpreter itu tidak ada, shell mencetak "command not found" ke stderr dan
# `$(...)` mengembalikan **string kosong** — maka setiap aturan itu jatuh ke
# cabang `else`-nya dan mencetak "Bersih". Gerbang keluar 0 dan seluruh CI
# hijau, sementara tidak ada satu pun yang diperiksa.
#
# Itu bukan kekhawatiran teoretis: image CI (`swift:6.0`, Ubuntu 24.04)
# **tidak memuat Python sama sekali**, jadi selama ini kesebelas aturan itu
# no-op di Linux — persis "hijau yang tidak hijau" yang seluruh berkas ini
# dibuat untuk menutup, terjadi pada gerbangnya sendiri.
#
# Karena itu kegagalan ini dianggap GAGAL, bukan peringatan: pemeriksaan yang
# tidak bisa dijalankan tidak boleh dilaporkan sebagai lulus.
if ! command -v python3 >/dev/null 2>&1; then
  echo "== GERBANG UI GAGAL: python3 tidak ditemukan =="
  echo "Sebelas aturan di berkas ini memakai python3; tanpanya masing-masing"
  echo "mengembalikan string kosong lalu dilaporkan 'Bersih' tanpa memeriksa"
  echo "apa pun. Pasang python3, atau jalankan gerbang ini di image yang"
  echo "memuatnya (CI menjalankannya di dalam container swift:6.0)."
  exit 1
fi

# ── Aturan 1: tidak ada ukuran font tetap ──────────────────────────────────
# Sapu `.system(size:` dan `Font.system(size:` pada **kode**, bukan komentar.
#
# Versi pertama memakai `awk` dengan `index(line, "//")` untuk membuang
# komentar sebaris. Bentuk itu punya cacat yang sama dengan yang baru
# ditemukan di Aturan 7: ia memotong di `//` pertama pada baris, termasuk
# `//` yang ada **di dalam literal string**. Disuntik dan diukur:
#
#     Text("https://example.com/x").font(.system(size: 11))
#
# → "Bersih: tidak ada .system(size:) pada kode di Apps/." Pelanggaran
# Dynamic Type yang paling mungkin dialam (baris dengan URL atau path di
# dalamnya) justru satu-satunya yang tidak terlihat. Ia juga tidak mengenal
# komentar blok `/* */` sama sekali, jadi komentar multi-baris tetap dibaca
# sebagai kode.
#
# Karena itu pemotong komentar di sini sama dengan Aturan 7: sadar literal,
# sadar escape, dan sadar komentar blok.
echo "== Aturan 1: tidak ada ukuran font tetap di Apps/ =="
hits=$(python3 - <<'PY'
import os, re

FONT_API = re.compile(r"\.system\(size:|Font\.system\(size")


def strip_comments(src):
    """Buang `//` dan `/* */` yang berada di **luar** literal string."""
    out, i, n = [], 0, len(src)
    in_str, esc = False, False
    while i < n:
        ch = src[i]
        if in_str:
            out.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                # Baris baru di dalam komentar blok **dipertahankan**, supaya
                # nomor baris temuan tetap cocok dengan berkas aslinya.
                if src[i] == "\n":
                    out.append("\n")
                i += 1
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


hits = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        raw = open(path, encoding="utf-8").read()
        src = strip_comments(raw)
        raw_lines = raw.split("\n")
        for m in FONT_API.finditer(src):
            line = src[:m.start()].count("\n") + 1
            # Teks yang dilaporkan diambil dari baris **asli** supaya komentar
            # di ujungnya tetap terbaca orang; nomor barisnya dari sumber
            # bersih, yang jumlah barisnya sama karena baris baru dijaga.
            shown = raw_lines[line - 1].strip() if line - 1 < len(raw_lines) else ""
            hits.append(f"{path}:{line}: {shown}")
print("\n".join(hits) if hits else "")
PY
)

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
abbrev=$(python3 - <<'PY' 2>&1
import glob, json, os, re

# Prosa berbahasa Indonesia yang **menjelaskan** pola ini hampir selalu memuat
# salah satu kata ini, dan sebuah argumen yang memuatnya bukan satuan yang
# dipakai menampilkan nilai:
#   "atau"  -> "…: 0.5°/dtk atau galat %.1f°"
#   "hanya" -> "Pakai satuan \"°/dtk\" hanya setelah ada padanan terucap."
#   "bukan" -> "…bentuk LAYAR ringkas (\"mag\"), bukan bentuk suara…"
# Kata penanda itu sendiri sengaja **tidak** ditebak di sini: daftarnya
# diekstrak dari prosa yang benar-benar ditolak versi baru ini (lihat
# `Tools/bukti-mutasi-singkatan-visual.py`, keadaan 3), jadi ia menyempit
# kalau prosa repo ini berubah — bukan daftar yang ditebak sekali lalu
# dipercaya selamanya.
PROSA = re.compile(r"\b(atau|hanya|bukan|mis\.|misalnya|dulu|dahulu)\b", re.I)

SATUAN = [("°/dtk", "derajat per detik"),
          ("RA ", "RA derajat"),
          ("Dec ", "deklinasi derajat")]
MAG = re.compile(r"^mag [0-9]")


def swift_strings(path):
    """Ambil setiap literal string di `path` beserta nomor barisnya.

    Komentar dibuang lebih dulu supaya `// "°/dtk" yang tak bermakna…` tidak
    pernah sampai ke sini. Kegagalan lexing diperlakukan sebagai temuan
    bentuk, bukan dilewati: gerbang yang berhenti mengukur secara diam
    dilaporkan sebagai galat, kelas cacat yang sudah dibayar repo ini.
    """
    src = open(path, encoding="utf-8").read()
    out, i, n, line, start = [], 0, len(src), 1, 1
    while i < n:
        if src.startswith("//", i):
            j = src.find("\n", i)
            if j < 0:
                break
            line += src.count("\n", i, j) + 1
            i = j + 1
        elif src.startswith("/*", i):
            j = src.find("*/", i)
            j = n if j < 0 else j + 2
            line += src.count("\n", i, j)
            i = j
        elif src[i] == '"':
            start, j, buf = line, i + 1, []
            while j < n and src[j] != '"':
                if src[j] == "\\":
                    buf.append(src[j:j + 2])
                    j += 2
                    continue
                if src[j] == "\n":
                    line += 1
                buf.append(src[j])
                j += 1
            out.append((start, "".join(buf)))
            i = j + 1
        else:
            if src[i] == "\n":
                line += 1
            i += 1
    return out


def penuh(path):
    """Kata penuh dari katalog untuk `mag`, `°/dtk`, dan `RA`/`Dec`.

    Dibaca dari `stringUnit` bahasa Inggris yang memuat `%` — nilai formulat,
    jadi bentuk yang benar-benar diucapkan/ditampilkan, bukan judul baris.
    """
    if not os.path.exists(path):
        return []
    words = set()
    for entry in json.load(open(path, encoding="utf-8"))["strings"].values():
        unit = entry.get("localizations", {}).get("en", {}).get("stringUnit", {})
        value = unit.get("value", "")
        if "%" not in value:
            continue
        for token in re.findall(r"[a-zA-Z]{4,}", value):
            words.add(token.lower())
    return sorted(words)


CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"
KATA_PENUH = penuh(CATALOG)

hits = []
for path in sorted(glob.glob("Apps/**/*.swift", recursive=True)):
    for line, value in swift_strings(path):
        if PROSA.search(value):
            continue
        teks = value.lower()
        if any(w in teks for w in KATA_PENUH):
            continue
        cocok = [v for token, v in SATUAN if token in value]
        if MAG.match(value):
            cocok.append("magnitudo")
        if cocok:
            hits.append(f"{path}:{line}: \"{value[:70]}\" "
                        f"({', '.join(cocok)})")

# Katalog memuat teks yang benar-benar tampil dan **tidak dipindai aturan mana
# pun** — bukan Aturan 4 (ia menyapu kode yang memakainya), bukan Aturan 6
# (paritas kunci). Terukur: `object.display.coordinates` = `'RA %.1f° Dec
# %+.1f°'` dan `diagnostics.row.rightAscension` = `'RA'` adalah dua nilai
# LAYAR, sementara pasangan suaranya (`object.speech.coordinates` = `'RA %.1f
# degrees, declination %+.1f degrees'`) justru memakai kata penuh. Jadi
# katalognya sendiri menyatakan perbedaan yang aturan ini jaga, dan jalan
# masuknya harus ikut diperiksa.
if os.path.exists(CATALOG):
    for key, entry in sorted(json.load(open(CATALOG, encoding="utf-8"))["strings"].items()):
        value = entry.get("localizations", {}).get("en", {}) \
                     .get("stringUnit", {}).get("value", "")
        if not value or PROSA.search(value):
            continue
        teks = value.lower()
        if any(w in teks for w in KATA_PENUH):
            continue
        cocok = [v for token, v in SATUAN if token in value]
        if cocok:
            hits.append(f"{CATALOG}: kunci `{key}` = \"{value[:50]}\" "
                        f"({', '.join(cocok)})")

if hits:
    print("\n".join(hits))
PY
)
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
echo "== Aturan 3: tidak ada huruf non-Latin (selain Yunani) di kode =="
# Cakup **seluruh** kode, bukan hanya `Apps/`: selip yang sama bisa muncul
# di `Packages/`, yang tidak akan pernah terjangkau sapuan `Apps/` saja.
# Satu sapuan untuk satu aturan.
#
# Cakupan diperluas ke `*.sh`, `*.yml`, dan `project.yml`. Tiga tempat itu
# sebelumnya **tidak terjangkau aturan mana pun** — STATUS sudah mencatatnya
# sebagai batas berulang kali — padahal selip yang sama bisa mendarat di
# sana, dan `project.yml` justru berkas yang menentukan build. Sapuan
# menunjukkan ketiganya bersih, jadi memperluas cakupannya tidak menambah
# pelanggaran apa pun; yang berubah hanya ada-tidaknya penjaga.
#
# `*.md` sengaja **tidak** ikut, dan itu keputusan, bukan kelalaian:
# STATUS.md memuat aksara CJK **sebagai bukti** cacat yang pernah terjadi —
# mengutipnya apa adanya, lengkap dengan aksaranya. Memasukkan `.md` akan
# membuat aturan memerah pada dokumentasinya sendiri, persis kegagalan yang
# membuat gerbang salah-merah lalu dimatikan orang. Batas ini dicatat di
# sini supaya tidak terbaca sebagai kelalaian.
#
# Catatan yang sama berlaku untuk komentar ini sendiri: awalnya kalimat di
# atas mengutip aksara CJK-nya, dan aturan yang baru diperluas ini langsung
# memerah pada skrip yang memuatnya. Kutipannya dihapus, bukan dikecualikan —
# lebih baik komentarnya kehilangan contoh harfiah daripada aturannya
# mendapat lubang pengecualian.
#
# **Cakupan karakternya sendiri ternyata lubang, dan itu terbukti.** Versi
# sebelumnya memakai daftar rentang **tangan** (CJK, Hiragana/Katakana,
# Hangul, fullwidth, Cyrillic). Daftar tangan selalu ketinggalan abjad yang
# tidak disebut: satu huruf Arab (U+0627, ALEF) pernah benar-benar masuk ke
# berkas ini — menyelinap di dalam komentar Aturan 7 — dan aturan ini
# melaporkan **"Bersih"**. Ia lolos bukan karena kebetulan yang langka:
# daftar itu tidak pernah punya rentang Arabic sama sekali.
#
# Pemeriksaannya kini diturunkan dari **sifat** karakternya, bukan dari daftar
# abjad yang harus diingat: setiap karakter berkategori huruf (Unicode `L*`)
# yang bukan ASCII, bukan Latin, dan bukan Yunani. Arab, Ibrani, Devanagari,
# Thai, Armenia, dan abjad apa pun yang belum ditemukan semuanya tertangkap
# tanpa perlu ditambahkan satu per satu.
#
# **Kenapa Yunani dikecualikan, dan kenapa itu diukur bukan dikira-kira.**
# Sapuan yang menandai **semua** huruf non-Latin langsung menemukan 99 temuan
# di repo ini — semuanya sah: `σ`, `α`, `θ`, `φ`, `Δ` dipakai sebagai simbol
# matematis di uji dan komentar (`σ` = simpangan baku, `Δ` = selisih). Gerbang
# yang merah pada 99 baris kode yang benar adalah gerbang yang dimatikan
# orang, jadi Yunani dikecualikan **secara eksplisit** — dulu ia lolos hanya
# karena kebetulan tidak ada di daftar, dan kebetulan bukan pengecualian.
#
# Diukur dua arah setelah perluasan: **0 temuan** atas seluruh repo yang
# bersih (jadi tidak ada satu pun kode benar yang jadi merah), sementara
# huruf Arab **tertangkap** dan huruf Yunani tidak.
#
# Batas yang dinyatakan: yang diperiksa adalah **huruf** (`L*`). Simbol dan
# tanda baca non-ASCII tidak ditandai, karena komentar repo ini memang
# memakai `─ ▸ ° × ≥ •` sebagai tata letak. Dan `.build/` dilewati: ia hasil
# build (termasuk salinan pustaka pihak ketiga), bukan sumber repo ini.
#
# **Cakupan berkasnya sendiri adalah lubang kedua, dan ia lebih besar dari
# yang pertama.** Versi sebelumnya memindai `*.swift`, `*.sh`, `*.yml`, dan
# `*.yaml` di bawah `Apps/`, `Packages/`, dan `Tools/` — terukur: 168 berkas.
# Yang **tidak pernah dipindai satu kali pun**: 74 berkas `.py` di `Tools/`
# dan 2 berkas `.yml` di `.github/workflows/`. Padahal di sanalah prosa
# Indonesia repo ini paling padat — setiap harness `bukti-mutasi-*.py`
# menulis penjelasan panjang tentang apa yang ia buktikan — dan huruf Arab
# yang dulu benar-benar menyelinap masuk ke berkas ini lewat **komentar**,
# yaitu bentuk yang persis sama.
#
# Jadi `Tools/*.py` dan `.github/` kini ikut; terukur, keduanya bersih
# (cakupan 168 -> 245 berkas dipindai, 0 temuan di keduanya), sehingga
# perluasannya tidak menambah satu pun pelanggaran — yang berubah hanya
# ada-tidaknya penjaga. Selisihnya 77 berkas: 75 `.py` di `Tools/` (74 yang
# sudah ada + harness `bukti-mutasi-aturan3-aksara.py` yang menutup celah ini)
# dan 2 `.yml` di `.github/workflows/`.
#
# Dua pengecualian di bawah keduanya punya alasan yang bisa diperiksa, bukan
# kemudahan: `.md` mengutip aksara CJK dan Cyrillic **sebagai bukti** cacat
# yang pernah terjadi (STATUS.md memuatnya apa adanya), dan `out/` adalah
# direktori keluaran `render-visuals.py` yang sudah di-`.gitignore`, bukan
# sumber yang ditulis orang.
#
# **Batas `out/` yang dinyatakan, bukan diklaim tertutup.** Di checkout bersih
# direktori itu tidak ada, jadi pengecualiannya belum menutup apa pun — ia ada
# supaya berkas keluaran tidak masuk cakupan **saat** seseorang menjalankan
# `render-visuals.py` lebih dulu. Menutupnya secara menyeluruh menuntut
# melacak berkas yang ditulis proses lain, dan itu di luar jangkauan sapu teks
# ini. Dicatat di sini supaya tidak terbaca sebagai sudah tertutup.
cjk=$(python3 - <<'PY'
import os
import unicodedata

DIRS = ["Apps", "Packages", "Tools", ".github"]
FILES = ["project.yml", "swift-ui-lint.sh", "swift-test.sh",
         "swift-typecheck.sh", "red-test.sh", "red-lint.sh"]
EXTS = (".swift", ".sh", ".yml", ".yaml", ".py")

# Di luar cakupan meski ekstensinya cocok: `Tools/out/` adalah **keluaran**
# `render-visuals.py`, bukan sumber yang ditulis orang. Alasannya sama dengan
# `.build/` — gerbang yang memerah pada berkas hasil alat repo sendiri adalah
# gerbang yang akan dimatikan orang. Ditulis sebagai awalan path, bukan nama
# direktori `"out"`, supaya direktori `out` di tempat lain tidak ikut lolos
# tanpa disadari.
SKIP_PREFIXES = ("Tools/out/",)

# Diizinkan **secara eksplisit**: huruf Yunani dipakai sebagai simbol
# matematis di repo ini (σ simpangan baku, Δ selisih, α/θ/φ di uji gambar).
YUNANI = (0x0370, 0x03FF)


def nama(ch):
    try:
        return unicodedata.name(ch)
    except ValueError:
        return "<tanpa nama>"


def mencurigakan(ch):
    """Huruf non-ASCII yang bukan Latin dan bukan Yunani."""
    if ord(ch) < 0x80:
        return False
    if not unicodedata.category(ch).startswith("L"):
        return False
    if "LATIN" in nama(ch):
        return False
    if YUNANI[0] <= ord(ch) <= YUNANI[1]:
        return False
    return True


def berkas():
    for d in DIRS:
        if not os.path.isdir(d):
            continue
        for root, dirs, files in os.walk(d):
            dirs[:] = [x for x in dirs if x != ".build"]
            for f in sorted(files):
                if f.endswith(EXTS):
                    p = os.path.join(root, f)
                    if any(p.startswith(pref) for pref in SKIP_PREFIXES):
                        continue
                    yield p
    for f in FILES:
        if os.path.exists(f):
            yield f


temuan = []
for path in berkas():
    try:
        src = open(path, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        continue
    for i, line in enumerate(src.split("\n"), 1):
        for ch in line:
            if mencurigakan(ch):
                temuan.append(f"{path}:{i}: {line.strip()} [{nama(ch)}]")
                break
print("\n".join(temuan))
PY
)
if [ -n "$cjk" ]; then
  echo "Aksara non-Latin ditemukan — repo ini ditulis bahasa Indonesia:"
  echo "$cjk"
  echo "-> Hapus karakter tersebut; kemungkinan besar selip, bukan pilihan."
  echo "   (Yunani dikecualikan: dipakai sebagai simbol matematis.)"
  status=1
else
  echo "Bersih: tidak ada huruf non-Latin selain Yunani."
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
    r'row|detailRow|'
    # Daftar ini **diturunkan dari data**, bukan dari ingatan. Sapuan
    # dijalankan atas seluruh `Apps/` untuk mencari setiap pemanggilan yang
    # argumen pertamanya sebuah literal, lalu hasilnya dikelompokkan per nama.
    # Yang muncul dan teksnya benar-benar tampil masuk ke daftar ini; yang
    # tidak, tidak. Lima nama di bawah ditemukan begitu — masing-masing
    # memuat literal yang **tampil di layar** dan sebelumnya tidak diperiksa
    # gerbang mana pun:
    #
    #   SharePreview  judul berkas di lembar berbagi (2 situs)
    #   TextField     label bidang isian ("Catatan (opsional)")
    #   chartYAxisLabel  label sumbu grafik
    #   value         label nilai Swift Charts — nama pendek, tapi API-nya
    #                 memang selalu dipanggil `.value(...)` dan argumennya
    #                 selalu label sumbu
    #   legend        helper legenda lokal di `DiagnosticsView`, argumennya
    #                 teks yang tampil
    #
    # Yang **sengaja tidak** dimasukkan, dengan alasannya masing-masing:
    #   NSLog         pesan log, tidak pernah terlihat pengguna
    #   append        nama terlalu umum (`Array.append`/`String.append`):
    #                 memasukkannya akan menandai setiap `append("...")` di
    #                 repo, termasuk yang bukan teks tampilan. Gerbang yang
    #                 salah merah akan dimatikan orang lain saat ia berbunyi.
    #                 Batas ini dicatat, bukan disembunyikan.
    r'SharePreview|TextField|chartYAxisLabel|value|legend'
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
    """Literal pada **semua kedalaman** argumen, beserta label parameternya.

    Kenapa semua kedalaman, bukan hanya 1 — dan ini cacat yang sama dengan
    tiga siklus sebelumnya, kini pada gerbangnya sendiri.

    Bentuk lama memeriksa `if depth == 1`. Konsekuensinya terukur:
    `Text("benar")` terbaca, sementara

        Text(analysis.isFalseLock ? "FALSE LOCK"
             : (analysis.isCorrect ? "benar" : "salah"))

    **tidak terbaca sama sekali** — kedua literal itu berada di kedalaman 2
    dan 3, di dalam tanda kurung ternary. Padahal keduanya teks yang tampil
    di layar, keduanya tanpa padanan Inggris, dan keduanya nyata ada di
    `Experiment1View.swift` selama berbulan-bulan sementara gerbang ini
    hijau. `FALSE LOCK` kebetulan lolos karena kebetulan ada di katalog;
    `benar` dan `salah` tidak, dan tidak pernah dilaporkan.

    Batas kedalaman bukan cara membedakan teks tampilan dari bukan-teks —
    peritelnya (`Text`, `row`, ...) yang menentukan itu, dan pemanggilnya
    sudah disaring oleh `POS`. Jadi syaratnya dilonggarkan menjadi
    `depth >= 1`, yang berarti "di dalam tanda kurung peritel ini".
    """
    depth, i, found = 0, open_index, []
    while i < len(src):
        ch = src[i]
        if ch == '"':
            end, text, interpolated = read_literal(src, i)
            if depth >= 1:
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
                    # Interpolasi **tidak** otomatis berarti "bukan teks
                    # tampilan" — dan itulah yang dulu diasumsikan di sini
                    # (`continue` tanpa syarat). Buktinya cacat yang
                    # ditemukan pada siklus ini: `DiagnosticsView`
                    # menulis `"\(object.name) — bukan hasil sekarang"`
                    # sebagai penanda objek basi. Kata-katanya
                    # ("bukan hasil sekarang") adalah kalimat yang tampil
                    # di layar dan tidak punya padanan bahasa Inggris,
                    # sementara Aturan 4 melintasinya tanpa laporan apa pun.
                    #
                    # Yang **benar** tidak bisa diuji adalah bentuk
                    # katalognya: `"%@ — bukan hasil sekarang"` memang
                    # punya bentuk, tapi tidak bisa ditulis sebagai kunci
                    # katalog — ia harus melewati `FORMATS` di atas supaya
                    # pemetaannya tercatat. Jadi aturannya dibuat gagal
                    # bawaan (fail-closed): literal interpolasi yang masih
                    # punya kata dilaporkan, dan yang **tidak** punya kata
                    # sama sekali (mis. `"54.2° / 121.0°"`, yang kata-katanya
                    # hanyalah pengenal Swift di dalam kurung) tetap lolos
                    # karena memang bukan teks tampilan.
                    #
                    # Tanda kurung dihitung berimbang, bukan dengan
                    # `[^()]` — tanpa itu `\(NumberFormat.degrees(x))`
                    # berhenti di kurung buka `degrees(` dan pengenalnya
                    # ("NumberFormat") terbaca sebagai kata tampilan.
                    words, depth, i = [], 0, 0
                    while i < len(text):
                        if text.startswith("\\(", i):
                            j, depth = i, 0
                            while j < len(text):
                                if text[j] == "(":
                                    depth += 1
                                elif text[j] == ")":
                                    depth -= 1
                                    if depth == 0:
                                        break
                                j += 1
                            i = j + 1
                            continue
                        words.append(text[i])
                        i += 1
                    if not re.search(r"[A-Za-z]", "".join(words)):
                        continue
                    found.append(
                        f"  {path}:{line}: {text!r} "
                        f"(interpolasi: butuh kunci lewat FORMATS)")
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
    r"^(pointing\.state|confidence\.level|link\.kind|object\.kind|diagnostics)\.")
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
# **Cakupan versi pertama terlalu lebar, dan itu terbukti dengan menyuntik.**
# Ia menanyakan penjaganya ke **seluruh berkas** (`whole = "\n".join(lines)`)
# dan berhenti setelah satu laporan per berkas (`break`). Terukur pada
# `PointingView.swift`: satu `motion.allowsTransitions` di baris 546 membuat
# ketiga API gerak di berkas itu lolos — termasuk `TimelineView(.animation)`
# di `PulsingCelestialVisual`, yang penjaganya (`motion.allowsContinuousMotion`)
# hidup di `if` pada baris berikutnya, bukan di pohon yang sama.
#
# Dua akibatnya, dan yang kedua jauh lebih mahal:
#   1. `break` membuat API gerak **kedua** di satu berkas tidak pernah
#      diperiksa sama sekali. Berkas yang sudah punya satu penjaga adalah
#      berkas yang paling aman menurut gerbang ini — persis kebalikannya.
#   2. `withAnimation` baru di fungsi baru di berkas yang sudah menyebut
#      `motion` **hijau**, walau tidak ada penjaga di dekatnya. Disuntik dan
#      diukur: `withAnimation(.linear(duration: 0.3))` di fungsi baru
#      `PointingView.swift` → gerbang ini melaporkan "Bersih".
#
# Yang ditutup karena itu adalah **kelas**-nya dengan cakupan yang benar:
# setiap API gerak harus berada di dalam blok `{...}` yang memuat rujukan
# penjaga — blok itu sendiri, atau salah satu blok yang membungkusnya.
#
# **Kenapa blok, bukan "rentang fungsi".** Fungsi bukan satu-satunya pemilik
# badan di berkas SwiftUI. `var body: some View` adalah **properti**; rentang
# berbasis `func` membuat `body` tidak punya pemilik sama sekali dan
# melaporkan seluruh 6 API gerak yang ada sebagai pelanggaran — gerbang yang
# merah pada kode yang benar, dan gerbang seperti itu dimatikan orang.
# Kurung kurawal menutup `func`, `var`, `if`, dan `else` sekaligus, tanpa
# perlu tahu mana yang sedang dibaca. Terukur: 6/6 API gerak yang ada hijau,
# dan suntikan di atas merah — satu-satunya selisihnya.
#
# Yang diperiksa adalah nama API **di kode**, sementara penjaga boleh disebut
# di mana saja di dalam bloknya -- **tetapi hanya di kode**. Versi pertama
# hanya membuang komentar, jadi penjaga yang muncul **di dalam literal
# string** ikut dihitung. Terukur dengan menyuntik di `PointingView.swift`:
#
#     var zzzMotionProbe: some View {
#         _ = "MotionPolicy(reduceMotion: false)"
#         withAnimation(.linear(duration: 0.3)) { }
#         return EmptyView()
#     }
#     -> "Bersih: setiap API gerak berada di blok berpenjaga reduce-motion."
#
# Satu baris `_ = "…"` yang menyebut nama penjaganya di dalam string membuat
# gerak tanpa penjaga lolos. Kalimat yang menyebut penjaga bukan penjaga —
# dan itu justru bentuk yang paling mungkin muncul di repo ini, yang menulis
# `motion.allowsTransitions` di dalam teks yang **dijelaskan** ke pengguna.
# Karena itu isi literal string dikosongkan sebelum penjaganya dicari.
#
# Kalimat di atas pernah berbunyi "(kode atau komentar)", dan itu **salah**:
# komentarnya sudah dibuang `strip_comments` sebelum bloknya diuji, jadi
# penjaga di dalam komentar tidak pernah dihitung (dan memang tidak boleh --
# dokumentasi aturan ini sendiri menyebut `withAnimation`, jadi penyapu yang
# ikut menghitung komentar akan melaporkan dirinya sendiri, persis gerbang
# yang selalu merah dan akan dimatikan orang lain saat ia berbunyi).
#
# Batas yang dinyatakan: blok yang diuji adalah blok **terdekat yang memuat**,
# bukan blok yang sebenarnya mengeksekusi API itu. Penjaga di `if` bersaudara
# masih hijau. Batas itu dibiarkan karena versi yang lebih ketat menuntut
# pelacakan alur yang tidak bisa dibuktikan benar oleh sapu teks — dan
# `red-lint.sh` di CI menyuntik kasusnya sendiri untuk memastikan gerbang ini
# tetap berbunyi, bukan hanya tetap tenang.
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
# ini ada; berkas yang hanya mengurus Always-On itu tidak otomatis salah.
GUARD = re.compile(
    r"\breduceMotion\b|\bMotionPolicy\b|\bisLuminanceReduced\b")


def strip_comments(src):
    """Buang `//` dan `/* */` yang berada di **luar** literal string.

    Kenapa bukan `raw[:raw.find("//")]` seperti versi pertama: bentuk itu
    memotong di `//` pertama pada baris, termasuk `//` yang ada **di dalam**
    literal (URL, path, regex). Selain itu ia tidak mengenal komentar blok,
    jadi komentar multi-baris yang menjelaskan aturan ini tetap terbaca
    sebagai kode.
    """
    out, i, n = [], 0, len(src)
    in_str, esc = False, False
    while i < n:
        ch = src[i]
        if in_str:
            out.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def brace_blocks(src):
    """Semua pasangan `{...}` yang berimbang, sebagai (buka, tutup)."""
    stack, out = [], []
    for i, ch in enumerate(src):
        if ch == "{":
            stack.append(i)
        elif ch == "}" and stack:
            out.append((stack.pop(), i))
    return out


def blank_strings(src):
    """Kosongkan isi literal string; tanda kutipnya dipertahankan.

    Penjaga yang hanya **disebut** di dalam string bukan penjaga. Tanpa ini,
    satu baris `_ = "MotionPolicy(reduceMotion: false)"` di dalam blok
    membuat setiap API gerak di blok itu lolos -- terukur, bukan dugaan.
    """
    out, i, n = [], 0, len(src)
    while i < n:
        if src[i] == '"':
            out.append('""')
            i += 1
            while i < n:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def is_guarded(src, pos, blocks):
    """Apakah `pos` berada di blok yang memuat rujukan penjaga.

    Blok yang diuji adalah blok terdekat yang memuat `pos`, lalu blok yang
    membungkusnya, dan seterusnya ke luar. Penjaga di **saudara** blok tidak
    dihitung — itu yang membedakan gerbang ini dari versi berkas-lebar.

    Isi literal string dikosongkan lebih dulu (`blank_strings`): yang dicari
    adalah penjaga **di kode**, bukan kalimat yang menyebut namanya.
    """
    for (open_at, close_at) in blocks:
        if open_at < pos < close_at and GUARD.search(
                blank_strings(src[open_at:close_at + 1])):
            return True
    return False


bad = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        src = strip_comments(open(path, encoding="utf-8").read())
        blocks = brace_blocks(src)
        # **Tanpa `break`.** Versi pertama berhenti setelah laporan pertama
        # per berkas, jadi API gerak kedua di berkas yang sama tidak pernah
        # diperiksa. Setiap kemunculan diperiksa sendiri.
        for m in MOTION_API.finditer(src):
            if is_guarded(src, m.start(), blocks):
                continue
            line = src[:m.start()].count("\n") + 1
            bad.append(f"  {path}:{line}: {m.group(0)}")
print("\n".join(bad) if bad else "")
PY
)
if [ -n "$motion" ]; then
  echo "Gerak dipanggil di luar blok berpenjaga reduce-motion:"
  echo "$motion"
  echo "-> Baca MotionPolicy.allowsContinuousMotion / allowsTransitions"
  echo "   dari PointingKit, di blok yang sama dengan pemanggilan geraknya."
  echo "   Penjaga di fungsi/berkas lain tidak menutupi baris ini."
  status=1
else
  echo "Bersih: setiap API gerak berada di blok berpenjaga reduce-motion."
fi

# ── Aturan 8: kata asing yang terselip di komentar/kode ───────────────────
# Kelas ini sudah lama tercatat sebagai batas yang belum ditutup, dan
# sekarang tertutup sebagian dengan cakupan yang bisa diperiksa.
#
# Buktinya nyata, bukan dugaan: `Apps/Shared/LocalizationBridge.swift`
# memuat satu kata fungsi bahasa Jerman di tengah kalimat Indonesia, dan
# tidak ada gerbang yang melihatnya. Aturan 3 menangkap aksara CJK serta
# Cyrillic, tapi kata Latin yang terbaca wajar oleh mata lolos total.
#
# Daftar kata sengaja memuat kata fungsi bahasa Jerman saja. Alasannya
# ditemukan dengan menguji, bukan menebak:
#
#   - Kata Inggris umum menghasilkan positif palsu pada istilah yang
#     memang dipakai repo ini. Terbukti: sapuan kata Inggris menandai
#     istilah desain berbahasa Inggris di `OnboardingView` yang sah.
#   - Kata Jerman yang dipakai bersih: 103 berkas dipindai, satu hit,
#     dan hit itu memang cacat.
#
# Batas yang jujur: daftar ini tidak akan menangkap kata Latin korup yang
# di luar daftarnya. Yang ditutup adalah kelas yang benar-benar muncul,
# bukan seluruh kemungkinannya.
echo
echo "== Aturan 8: kata asing yang terselip di komentar/kode =="
foreign=$(python3 - <<'PY'
import os, re

# Kata fungsi Jerman: tidak mungkin muncul sah dalam kalimat Bahasa Indonesia
# maupun sebagai istilah produk berbahasa Inggris di repo ini.
FOREIGN = set((
    # aturan8:abaikan-mulai — definisi daftar ini sendiri tidak dipindai,
    # karena sebuah aturan tidak boleh menandai daftar katanya sendiri.
    "deshalb trotzdem obwohl waehrend während natuerlich natürlich "
    "zunaechst zunächst jedoch bereits ebenfalls allerdings somit sodass "
    "werden wurde "
    "nicht auch sind kann muss dass wenn aber nur noch schon mehr sehr "
    "ganz durch ueber über unter zwischen damit dabei dazu dafür dafuer"
    # aturan8:abaikan-selesai
).split())

TARGETS = []
for base in ("Apps", "Packages/PointingKit/Sources", "Packages/PointingKit/Tests",
             "Packages/CelestialEngine/Sources", "Packages/CelestialEngine/Tests",
             "Tools"):
    for root, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d != ".build"]
        for name in sorted(files):
            if name.endswith((".swift", ".sh", ".yml")):
                TARGETS.append(os.path.join(root, name))
# `project.yml` dan skrip gerbang ikut dipindai: dua tempat yang justru
# **tidak** tercakup aturan 3, dan itu celah yang sudah dicatat berulang kali.
for name in ("project.yml", "swift-ui-lint.sh", "swift-test.sh",
             "swift-typecheck.sh", "red-test.sh"):
    if os.path.exists(name):
        TARGETS.append(name)

# Pindai baris mentah, bukan hanya komentar: satu kata asing di dalam kode
# sama salahnya, dan bentuk ini terbukti sama tepatnya (1 hit, dan hit itu
# memang cacat) tanpa perlu mengurai komentar.
#
# Definisi daftar kata di atas dibatasi penanda `aturan8:abaikan-*`, karena
# sebuah aturan tidak boleh menandai daftar katanya sendiri. Penanda itu
# sengaja eksplisit dan sempit — bukan pengecualian untuk seluruh berkas —
# supaya cakupan aturan tetap bisa diperiksa.
WORD = re.compile(r"[A-Za-zÄÖÜäöüß]+")
SKIP_BEGIN = "aturan8:abaikan-mulai"
SKIP_END = "aturan8:abaikan-selesai"

for path in TARGETS:
    ignoring = False
    for number, raw in enumerate(
            open(path, encoding="utf-8").read().split("\n"), 1):
        if SKIP_BEGIN in raw:
            ignoring = True
            continue
        if SKIP_END in raw:
            ignoring = False
            continue
        if ignoring:
            continue
        for match in WORD.finditer(raw):
            if match.group(0).lower() in FOREIGN:
                print(f"  {path}:{number}: {match.group(0)!r}  {raw.strip()[:80]}")
PY
)
if [ -n "$foreign" ]; then
  echo "Kata asing ditemukan — repo ini ditulis bahasa Indonesia:"
  echo "$foreign"
  echo "-> Ganti dengan kata Indonesia yang dimaksud. Kalau kata itu memang"
  echo "   disengaja, tambahkan ke daftar FOREIGN dengan alasannya."
  status=1
else
  echo "Bersih: tidak ada kata asing yang terselip."
fi

# ── Aturan 9: WidgetKit tanpa pemanggil reload tidak pernah menyegar ───────
# Complication (WidgetKit) berjalan di proses terpisah dan memakai
# `Timeline(entries:policy:.never)` — satu entri yang berlaku sampai ada yang
# meminta watchOS menghitung ulang. Menulis berkas snapshot **tidak** membuat
# watchOS menggambar ulang apa pun. Tanpa `WidgetCenter.shared.reload...`,
# complication membaca ringkasan sekali lalu membeku di objek pertama selamanya:
# berkasnya selalu benar, layarnya yang tidak pernah berubah.
#
# Bentuk cacat ini tidak bisa dilihat di layar (complication hanya ada di
# perangkat), tidak bisa diuji di Linux (WidgetKit hanya ada di Apple), dan
# tidak membuat `swiftc -parse` mengeluh. Karena itu penjaganya harus sapu
# teks, bukan ingatan orang yang menulis.
#
# Yang diperiksa bukan gaya: kalau ada deklarasi `struct ...: Widget` di
# `Apps/`, maka harus ada pemanggilan `WidgetCenter.shared.reload...` di kode.
# Komentar dilewati, sama seperti aturan 1 — proyek ini menyebut API itu di
# dokumentasi, dan yang dihitung hanya kode.
echo
echo "== Aturan 9: WidgetKit yang ada harus punya pemanggil reload =="
reload=$(python3 - <<'PY'
import os, re

widget_decl = re.compile(r"struct\s+\w+\s*:\s*Widget\b")
reload_call = re.compile(r"WidgetCenter\.shared\.reload\w*")

widgets, reloads = [], []
for root, dirs, files in os.walk("Apps"):
    dirs[:] = [d for d in dirs if d != ".build"]
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        for number, raw in enumerate(
                open(path, encoding="utf-8").read().split("\n"), 1):
            line = raw.split("//", 1)[0]  # buang komentar sebaris
            if widget_decl.search(line):
                widgets.append(f"{path}:{number}")
            if reload_call.search(line):
                reloads.append(f"{path}:{number}")

if widgets and not reloads:
    print("WidgetKit ada, tetapi tidak ada pemanggil reload:")
    for w in widgets:
        print(f"  {w}")
    print("-> Tambahkan WidgetCenter.shared.reloadAllTimelines() (atau")
    print("   reloadTimelines(ofKind:)) saat snapshot berubah. Timeline")
    print("   `policy: .never` tidak pernah dihitung ulang tanpa ini.")
PY
)
if [ -n "$reload" ]; then
  echo "$reload"
  status=1
else
  echo "Bersih: setiap WidgetKit punya pemanggil reload."
fi

# ── Aturan 10: hitungan uji di README harus cocok dengan uji yang ada ──────
# README menyebut "CelestialEngine 166, PointingKit N". Angka itu adalah janji
# ke pembaca tentang seberapa tebal jaring pengamannya, dan ia **tidak bisa
# dijaga compiler**: menambah uji tidak menyentuh README, jadi angka itu
# membusuk perlahan tanpa satu pun gerbang merah. Pernah terjadi: README
# tertinggal di 277 sementara suite sudah 367 — selisih 90 uji yang tidak
# terlihat siapa pun karena tidak ada yang membandingkannya.
#
# Hitungannya statis (`func test` per berkas), dan itu cukup di sini: yang
# dijaga adalah **kelas** drift (angka vs kenyataan), bukan angka tepatnya.
# Kalau suatu saat uji dihasilkan dinamis sehingga hitungan statis tidak lagi
# sama dengan yang dijalankan, aturan ini yang pertama akan memberi tahu.
#
# Klaim **jumlah aturan** di README juga diperiksa di sini, karena ia kelas
# drift yang sama persis: "berkasnya tumbuh jadi **21 aturan**" juga janji ke
# pembaca, juga tidak bisa dijaga compiler, dan juga membusuk tanpa gerbang
# merah. Terbukti: aturan ke-22 dan ke-23 ditambahkan tanpa ada yang menyentuh
# kalimat itu, dan README tetap bilang 21 sampai aturan ini diperluas.
#
# Sumber angkanya adalah **aturan yang benar-benar mencetak**, bukan nomor
# tertinggi: kalau `Aturan 12` pernah dihapus, menghitung nomor maksimum akan
# tetap bilang 23. Yang dijaga nomor terkecil yang hilang, supaya celah
# penomoran pun ketahuan.
echo
echo "== Aturan 10: hitungan uji di README cocok dengan berkas uji =="
readme=$(python3 - <<'PY'
import glob, os, re

def count(glob_pat):
    total = 0
    for path in glob.glob(glob_pat, recursive=True):
        total += len(re.findall(r"\bfunc\s+test",
                               open(path, encoding="utf-8").read()))
    return total

engine = count("Packages/CelestialEngine/Tests/**/*.swift")
kit = count("Packages/PointingKit/Tests/**/*.swift")

lint = open("swift-ui-lint.sh", encoding="utf-8").read()
numbers = [int(n) for n in re.findall(r'^echo "== Aturan (\d+)', lint, re.M)]
rule_count = len(numbers)

if not os.path.exists("README.md"):
    print("PERINGATAN: README.md tidak ada.")
    print("Aturan 10 DILEWATI, bukan lulus.")
    raise SystemExit

text = open("README.md", encoding="utf-8").read()
problems = []

# Cari klaim "CelestialEngine <angka>" dan "PointingKit <angka>".
for label, actual in (("CelestialEngine", engine), ("PointingKit", kit)):
    found = re.findall(rf"{label}\s*\*{{0,2}}(\d+)", text)
    if not found:
        problems.append(f"README tidak menyebut hitungan uji {label} sama sekali.")
        continue
    for number in found:
        if int(number) != actual:
            problems.append(
                f"README bilang {label} {number}, berkas uji berisi {actual}.")

# Klaim jumlah aturan lint.
found_rules = re.findall(r"(\d+)\s+aturan", text)
if not found_rules:
    problems.append("README tidak menyebut jumlah aturan lint sama sekali.")
for number in found_rules:
    if int(number) != rule_count:
        problems.append(
            f"README bilang {number} aturan, swift-ui-lint.sh punya {rule_count}.")

if problems:
    for p in problems:
        print(p)
    print("-> Perbarui angka di README.md, atau perbaiki kalau uji/aturan "
          "terhapus.")
else:
    # Sengaja tidak mencetak apa pun saat bersih: blok ini memakai konvensi
    # yang sama dengan aturan lain di berkas ini — python hanya bicara saat
    # ada masalah, dan shell yang menulis "Bersih". Mencetak baris sukses di
    # sini akan terbaca sebagai keluaran tidak kosong, lalu dihitung sebagai
    # kegagalan oleh `if [ -n "$readme" ]` di bawah.
    pass
PY
)
if [ -n "$readme" ]; then
  echo "$readme"
  case "$readme" in
    *"DILEWATI"*) : ;;   # peringatan saja, bukan kegagalan
    *) status=1 ;;
  esac
else
  echo "Bersih: hitungan uji di README cocok."
fi

# ── Aturan 11: specifier katalog harus cocok tipe dengan template kode ─────
# Katalog adalah berkas terjemahan. Bentuk yang paling wajar ditulis
# penerjemah — menukar posisi specifier supaya angkanya di depan — bisa
# **menjatuhkan app**, bukan sekadar salah kata.
#
# Buktinya nyata di repo ini, dan baru muncul di CI macOS: `spokenError`
# mengirim `(String, Double, String)` dengan template `"%@ %.1f %@"`. Uji
# urutan menulis template pengganti `"%.1f %@ %@"`; `%.1f` menerima sebuah
# `String`. **Di CoreFoundation itu crash**; glibc memaafkannya, jadi
# `swift-test.sh` hijau 450 uji dan hanya CI macOS yang merah.
#
# Jebakan yang sama sudah tercatat sekali (specifier posisional `%1$@`
# berperilaku beda di CoreFoundation vs Swift Foundation). Dua-duanya bentuk
# yang tak bisa ditangkap di Linux — jadi penjaganya harus perbandingan
# **teks**, bukan uji runtime.
#
# Yang dibandingkan: urutan tipe specifier pada template bawaan kode
# (`id:`) vs setiap nilai terjemahan untuk kunci yang sama. Tipe harus sama
# persis. Posisi boleh berbeda (itu memang alasan katalog ada) — tapi
# `%.1f` tidak boleh bertemu tempat yang diisi `String`.
echo
echo "== Aturan 11: specifier katalog cocok tipe dengan template kode =="
specifier=$(python3 - <<'PY'
import glob, json, os, re

CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"
SRC_DIR = "Packages/PointingKit/Sources/PointingKit"

# Satu konversi printf, dengan huruf tipenya ditangkap. `%%` bukan konversi
# (tanda persen harfiah), jadi ia dibuang lebih dulu oleh pemanggil.
CONV = re.compile(
    r"%(?:[0-9]+\$)?[-+ #0]*(?:[0-9]+|\*)?(?:\.(?:[0-9]+|\*))?"
    r"(?:hh|h|ll|l|q|L|z|t|j)?([diouxXeEfgGaAcspn@])")

def types(template):
    """Urutan tipe specifier, mengabaikan `%%`."""
    return CONV.findall(template.replace("%%", ""))

defaults = {}
for path in sorted(glob.glob(os.path.join(SRC_DIR, "*.swift"))):
    src = open(path, encoding="utf-8").read()
    for key, value in re.findall(
            r'key:\s*"([^"]+)",\s*\n?\s*id:\s*"([^"]*)"', src):
        defaults[key] = value

if not os.path.exists(CATALOG):
    raise SystemExit

strings = json.load(open(CATALOG, encoding="utf-8"))["strings"]

problems = []
for key, unit in sorted(strings.items()):
    if key not in defaults:
        continue
    expected = types(defaults[key])
    for lang, entry in sorted(unit.get("localizations", {}).items()):
        value = entry.get("stringUnit", {}).get("value", "")
        got = types(value)
        if got != expected:
            problems.append(
                f"  {key!r} [{lang}]: kode {expected} vs katalog {got}"
                f"  ({value!r})")

print("\n".join(problems) if problems else "")
PY
)
if [ -n "$specifier" ]; then
  echo "Tipe specifier katalog tidak cocok dengan template kode:"
  echo "$specifier"
  echo "-> Urutan **dan** tipe specifier katalog harus sama dengan template"
  echo "   kode. Menukar posisi dua specifier berbeda tipe = crash di"
  echo "   CoreFoundation. Bahasa yang menuntut urutan lain harus diubah"
  echo "   lewat kode, bukan lewat berkas terjemahan."
  status=1
else
  echo "Bersih: tipe specifier katalog cocok dengan template kode."
fi

# ── Aturan 12: kalimat tampilan tidak boleh lahir sebagai literal ───────────
# Aturan 4 menyapu literal yang **langsung** ada di dalam argumen `Text(...)`.
# Aturan 6 memeriksa paritas kunci yang **dideklarasikan**. Di antara keduanya
# ada celah: service menyimpan kalimat ke properti tampilan
# (`lastNote`, `lastMessageNote`, ...), lalu view merendernya lewat
# `Text(note)`. Literalnya tak pernah menyentuh `Text(...)` dan tak pernah
# punya kunci — dua gerbang tetap hijau, pengguna Bahasa Inggris membaca
# kalimat Indonesia. Aturan ini menutup celah itu.
echo
echo "== Aturan 12: kalimat tampilan tidak lahir sebagai literal =="
literal_note=$(python3 - <<'PY'
import os, re

# Properti yang jelas-jelas berakhir di layar / diucapkan.
NAME = re.compile(r'\b(\w*(?:Note|Message|Label|Title|Subtitle|Hint|Reason|Warning|Error|Body|Caption|Detail|Speech|Spoken)\w*)\s*=\s*([^\n]*)')
LIT  = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')
# Kunci katalog: titik-pemisah, huruf kecil, tanpa spasi.
KEY  = re.compile(r'^[a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9_]+)+$')

def is_sentence(s):
    if KEY.match(s):          # kunci katalog, bukan kalimat
        return False
    if len(s) < 3 or " " not in s:
        return False          # satu kata = nama, bukan kalimat
    if not re.search(r'[A-Za-z]', s):
        return False
    return True

hits = []
for root, dirs, files in os.walk("Apps"):
    dirs[:] = [d for d in dirs if d not in (".build", "build")]
    for f in files:
        if not f.endswith(".swift"):
            continue
        p = os.path.join(root, f)
        with open(p, encoding="utf-8") as fh:
            for i, line in enumerate(fh, 1):
                if line.lstrip().startswith("//"):
                    continue
                m = NAME.search(line)
                if not m:
                    continue
                for lit in LIT.findall(m.group(2)):
                    if is_sentence(lit):
                        hits.append(f"{p}:{i}  {m.group(1)} = \"{lit[:70]}\"")

print("\n".join(hits))
PY
)
if [ -n "$literal_note" ]; then
  echo "Kalimat tampilan ditulis sebagai literal di kode:"
  echo "$literal_note"
  echo "-> Pindahkan kalimatnya ke PointingKit lewat kunci katalog"
  echo "   (pola: RowSpeech / LinkStatusText), supaya Aturan 6 dan"
  echo "   Aturan 11 bisa melihatnya. Service hanya menyimpan *keadaan*;"
  echo "   kalimat jadi lahir dari katalog."
  status=1
else
  echo "Bersih: tak ada kalimat tampilan yang lahir sebagai literal."
fi

# ── Aturan 13: kalimat yang lahir di dalam String(format:) pun harus berkunci ─
# Aturan 4 menyapu literal di dalam `Text(...)`. Aturan 12 menyapu literal yang
# **ditugaskan** ke variabel berakhiran Note/Label/Speech lalu dirender.
# Yang tersisa adalah kelas yang keduanya tidak lihat: kalimat yang dirakit
# **sebagai argumen**, di dalam `String(format: …)`, `parts.append(…)`, atau
# `text += …`.
#
# Kenapa kelas ini lolos dari semua gerbang lain, dan kenapa ia berbahaya:
#   1. Bentuknya bukan argumen `Text`, jadi Aturan 4 tidak menyapunya.
#   2. Tidak pernah jadi nilai variabel berakhiran Note/Label, jadi Aturan 12
#      juga tidak.
#   3. Yang paling penting: **tidak terlihat salah**. "mag %.2f" dan
#      "%.0f° tinggi" berisi angka dan derajat yang identik di semua bahasa,
#      jadi diff dan tangkapan layar tidak menunjukkan apa pun. Yang berbeda —
#      kata pengantar dan **urutannya** — baru terasa oleh pengguna yang
#      membaca bahasa lain.
# Bukti nyata di repo ini: delapan kalimat seperti bentuk, antara lain
# "Laju pergelangan %.0f derajat per detik." yang memaksa Bahasa Inggris
# mengucapkan "derajat", dan "Keadaan: %@." yang memaksa awalan
# Bahasa Indonesia dibaca lebih dulu.
echo
echo "== Aturan 13: kalimat di dalam String(format:)/append harus berkunci =="
assembled_note=$(python3 - <<'PY'
import json, os, re

CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"

# Kata yang TIDAK diterjemahkan: nama produk & istilah yang watchOS sendiri
# gunakan apa adanya. Ini daftar **kata**, bukan daftar kalimat yang boleh
# lolos — jadi ia tak perlu bertambah tiap kalimat baru, dan tak bisa dipakai
# untuk men-justifikasi kalimat yang sebenarnya perlu diterjemahkan.
PROPER = {"iPhone", "iPad", "watchOS", "iOS", "GoTo", "Swift", "Wi-Fi",
          "Bluetooth", "Experiment", "Point", "Know", "False", "lock"}

# Satu konversi printf dengan huruf tipenya. `%%` bukan konversi, jadi ia
# dibuang lebih dulu (dipakai juga oleh Aturan 11).
CONV = re.compile(r"%(?:[0-9]+\$)?[-+ #0]*(?:[0-9]+|\*)?(?:\.(?:[0-9]+|\*))?"
                  r"(?:hh|h|ll|l|q|L|z|t|j)?[diouxXeEfgGaAcspn@]")
# Kata yang "dinyatakan": minimal 3 huruf, supaya "%@" dan "°" tidak dihitung.
WORD = re.compile(r"[A-Za-z][A-Za-z]{2,}")

# Konteks: tempat kalimat bisa lahir. `var x = [` / `let x = [`
#   menangkap kumpulan bagian kalimat yang dirakit pelan-pelan.
CTX = re.compile(r"(String\(format:|\.append\(|\.insert\(|\+=|"
                 r"\bvar\s+\w+\s*(?::[^=]*)?=\s*\[|\blet\s+\w+\s*=\s*\[)")


def strip_line_comments(text):
    """Hapus `// …`, tapi hanya di luar literal string."""
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
    """Baca satu literal mulai tanda kutip di `start`.

    Mengembalikan (akhir, teks_tanpa_interpolasi, teks_penuh, ada_interpolasi).
    Teks tanpa interpolasi dipakai untuk menilai **kata** yang ada; teks penuh
    dipakai untuk melaporkannya ke pemakai gerbang.
    """
    i = start + 1
    escaped = False
    buf, plain, interp = [], [], False
    while i < len(src):
        ch = src[i]
        if escaped:
            escaped = False
            if ch == "(":
                interp = True
                # Lewati seluruh ekspresi interpolasi, termasuk literal
                # string di dalamnya — `\(x ? "a" : "b")`.
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
            plain.append(ch)
        elif ch == "\\":
            escaped = True
            buf.append(ch)
        elif ch == '"':
            return i + 1, "".join(plain), "".join(buf), interp
        else:
            buf.append(ch)
            plain.append(ch)
        i += 1
    return i, "".join(plain), "".join(buf), interp


keys = set(json.load(open(CATALOG, encoding="utf-8"))["strings"])

hits = []
for root, dirs, files in os.walk("Apps"):
    dirs[:] = [d for d in dirs if d not in (".build", "build")]
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        source = strip_line_comments(open(path, encoding="utf-8").read())
        for lineno, line in enumerate(source.split("\n"), 1):
            if "NSLog(" in line or not CTX.search(line):
                continue
            i = 0
            while i < len(line):
                if line[i] != '"':
                    i += 1
                    continue
                end, plain, raw, interp = read_literal(line, i)
                i = end
                # `"…"` tanpa spasi = satu kata, bukan kalimat; `"{…}"`
                # adalah string multi-baris yang isinya ditangani per baris.
                if raw.startswith("{") or " " not in raw:
                    continue
                # Sudah punya kunci: literal ini adalah nilai bawaan katalog
                # yang ikut dimuat di view, bukan kalimat yang belum bernama.
                if raw in keys:
                    continue
                words = [w for w in WORD.findall(CONV.sub("", plain))
                         if w not in PROPER]
                if not words:
                    continue
                hits.append((path, lineno, raw, interp))

if hits:
    for path, lineno, raw, interp in hits:
        suffix = " (interpolasi)" if interp else ""
        print(f"  {path}:{lineno}: {raw[:96]!r}{suffix}")
PY
)
if [ -n "$assembled_note" ]; then
  echo "Kalimat dirakit sebagai argumen, tanpa kunci katalog:"
  echo "$assembled_note"
  echo "-> Bentuk kalimatnya milik PointingKit, bukan view. Ambil dari"
  echo "   TextLocalization.text(.kunci, …) — atau pakai helper yang"
  echo "   sudah ada (RowSpeech.stateLine, RowSpeech.spokenWristRate,"
  echo "   RowSpeech.spokenError, LinkStatusText.sendFailures,"
  echo "   CalibrationText.spreadDisplay)."
  echo "   Alasannya bukan cuma terjemahan: urutan kata ikut terpaku di"
  echo "   kode, dan bentuk seperti ini tidak terlihat salah karena"
  echo "   angka & derajat sama di semua bahasa."
  status=1
else
  echo "Bersih: tak ada kalimat yang dirakit sebagai argumen."
fi

# ── Aturan 14: setiap izin sistem harus punya InfoPlist.strings ────────────
# Teks izin (`NS*UsageDescription`) tidak tampil lewat `Text(...)`, dan tidak
# dihasilkan di `PointingKit` — ia dibaca **sistem operasi** dari bundel, di
# luar jangkauan `Localizable.xcstrings`. Karena itu Aturan 4 (literal di
# `Apps/`) dan Aturan 6 (paritas kunci paket) berdua tidak punya apa pun
# untuk dilihat: teksnya hidup di `project.yml` sebagai `INFOPLIST_KEY_*`,
# dan seluruh gerbang hijau sementara dialog izin berbahasa Indonesia untuk
# semua pengguna.
#
# Ini persis kelas cacat yang sama dengan Aturan 4: yang diukur bukan bagian
# yang bermasalah. Bedanya di sini lebih buruk, karena teks ini tidak bisa
# diperbaiki lewat katalog — satu-satunya jalurnya adalah `InfoPlist.strings`
# per bahasa, dan tidak ada gerbang Xcode yang memperingatkan bila berkas itu
# tidak ada.
#
# Yang diperiksa: setiap `INFOPLIST_KEY_NS*UsageDescription` di `project.yml`
# harus punya kunci yang sama di `Apps/Shared/Resources/<bahasa>.lproj/
# InfoPlist.strings`, untuk setiap bahasa yang katalog string dukung.
# Keduanya diambil dari berkas, bukan ditulis mati — supaya izin baru dan
# bahasa baru keduanya merah bila tidak dilengkapi.
echo
echo "== Aturan 14: izin sistem punya terjemahan InfoPlist.strings =="
# `status_crash` ditangkap terpisah: kalau pemeriksanya sendiri error,
# `$(...)` mengembalikan string kosong dan aturan ini akan melaporkan
# **bersih** — padahal tidak ada yang diperiksa. Itu persis "hijau yang
# tidak hijau" yang seluruh berkas ini dibuat untuk menutup, jadi
# kegagalan internal diperlakukan sebagai kegagalan gerbang.
permission=$(python3 - <<'PY' 2>&1
import glob, json, os, re

SPEC = "project.yml"
RES = "Apps/Shared/Resources"

if not os.path.exists(SPEC):
    print("PERINGATAN: project.yml tidak ada.")
    raise SystemExit

spec = open(SPEC, encoding="utf-8").read()
# Hanya kunci **izin** — `CFBundleDisplayName` memang tidak diterjemahkan
# ("Point & Know" adalah nama produk di semua bahasa).
perms = sorted(set(re.findall(r'INFOPLIST_KEY_(NS\w*UsageDescription)\s*:', spec)))

catalog = os.path.join(RES, "Localizable.xcstrings")
if not os.path.exists(catalog):
    print("PERINGATAN: katalog tidak ada, bahasa tidak bisa diturunkan.")
    raise SystemExit

# Bahasa yang didukung = bahasa katalog + bahasa sumbernya sendiri.
# `sourceLanguage: id` tidak punya entri `localizations`, jadi tanpa
# menyebutnya secara eksplisit berkas `id.lproj` akan dianggap tidak ada.
catalog_data = json.load(open(catalog, encoding="utf-8"))
strings = catalog_data["strings"]
# `sourceLanguage: id` tidak punya entri `localizations` sendiri, jadi tanpa
# menyebutnya secara eksplisit berkas `id.lproj` akan dianggap tidak ada.
langs = {catalog_data.get("sourceLanguage", "id")}
for unit in strings.values():
    langs.update(unit.get("localizations", {}).keys())
langs.discard(None)

problems = []
if not perms:
    print("PERINGATAN: tidak ada kunci izin yang ditemukan di project.yml.")

for lang in sorted(langs):
    path = os.path.join(RES, f"{lang}.lproj", "InfoPlist.strings")
    if not os.path.exists(path):
        problems.append(
            f"  {path} tidak ada — {len(perms)} izin belum diterjemahkan "
            f"untuk '{lang}'")
        continue
    text = open(path, encoding="utf-8").read()
    for perm in perms:
        # Kunci harus ada **dan** punya nilai, bukan hanya disebut.
        if not re.search(rf'^\s*{re.escape(perm)}\s*=\s*"[^"]+"\s*;',
                         text, re.M):
            problems.append(f"  {path}: tidak memuat {perm}")

print("\n".join(problems) if problems else "")
PY
)
if printf '%s' "$permission" | grep -q "Traceback\\|Error\\|error:"; then
  echo "Pemeriksaan Aturan 14 gagal dijalankan:"
  echo "$permission"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$permission" ]; then
  echo "Izin sistem berikut belum punya terjemahan:"
  echo "$permission"
  echo "-> Tambahkan Apps/Shared/Resources/<bahasa>.lproj/InfoPlist.strings."
  echo "   Teks izin dibaca sistem dari bundel, bukan lewat Localizable."
  echo "   xcstrings, jadi Aturan 4 & 6 tidak bisa melihatnya."
  status=1
else
  echo "Bersih: setiap izin punya terjemahan di setiap bahasa."
fi

# ── Aturan 15: warna prosedural harus lewat penjaga mode malam ─────────────
# PRD: "Semua warna (termasuk visual) ikut mode ini." Alasannya fisiologis,
# bukan selera: sel batang paling sensitif di ~498-530nm, cahaya >620nm tidak
# memicu rhodopsin. Jadi `Color(red:...)` yang **tidak** membaca
# `NightMode.isOn` bukan pelanggaran gaya -- ia memancarkan cahaya yang
# mematikan adaptasi gelap 20-40 menit, di layar yang justru dipakai untuk
# melihat bintang redup.
#
# Kenapa perlu aturan sendiri: cacatnya **pernah terjadi di berkas ini**,
# pada 10 dari 13 warna gambar. Masing-masing ditulis tangan sebagai
# "merah-ish" pilihan sendiri dan semuanya terlihat "cukup merah" di mata.
# Setelah luminansinya dihitung -- satu-satunya cara mengetahuinya -- dua
# pertiga cahaya pita terang Bulan berada di kanal hijau/biru. Perbaikannya
# kini satu aturan (`NightVisual`) dengan uji di Linux, tapi tidak ada yang
# mencegah warna baru ditulis sendiri besok: `Color(red:)` adalah API biasa
# dan compiler tidak peduli.
#
# Yang diperiksa: setiap `Color(red:`/`Color(hue:` di `Apps/` harus berada di
# bawah `guard NightMode.isOn else` / `if NightMode.isOn` dalam rentang
# fungsi yang sama. Pemeriksanya **menghitung**, bukan menebak dari nama.
echo
echo "== Aturan 15: warna prosedural wajib lewat penjaga mode malam =="
color_guard=$(python3 - <<'PY' 2>&1
import os, re

# Konstruksi warna yang memancarkan cahaya. `Color(white:)` netral dan
# `Color(gray:)`/`Color(black:)` tidak memancarkan apa pun ke arah
# rhodopsin, jadi keduanya tidak masuk.
MAKING = re.compile(r'\bColor\s*\(\s*(?:red|hue|green|blue|orange|purple|pink|cyan|teal|mint|indigo|brown|yellow)\s*:')
GUARD = re.compile(r'\b(?:guard\s+NightMode\.isOn\s+else|if\s+NightMode\.isOn|NightMode\.isOn\s*\?|guard\s+!NightMode\.isOn)')
# Deklarasi fungsi, **dengan** kata kunci akses di depannya (`private static
# func`). Tanpa awalan itu, `rfind("\nfunc")` tidak pernah cocok dan rentang
# fungsi jatuh ke seluruh berkas.
#
# **Versi pertama masih buta pada atribut dan `override`.** Daftarnya
# menutup pengubah akses dan `static`, tapi `@ViewBuilder func` dan
# `override func` tidak dikenali sebagai deklarasi sama sekali — sehingga
# cacat di dalamnya jatuh ke rentang **fungsi sebelumnya**, dan penjaga
# `NightMode.isOn` milik fungsi itu membelanya. Terukur (mengganti `func` di
# atas cacat yang sama):
#
#   private func warnaUji() -> Color     -> 1 temuan
#   @ViewBuilder private func warnaUji() -> 0 temuan (LOLOS)
#   override func warnaUji() -> Color    -> 0 temuan (LOLOS)
#
# Bentuknya persis kelas yang sama dengan Aturan 18: gerbang hijau karena ia
# tidak mengenali bentuk yang sedang dibacanya. `@ViewBuilder` adalah bentuk
# yang **paling mungkin** dialam di berkas SwiftUI, jadi lubangnya tepat di
# tempat yang paling sering ditulis. `nonisolated`/`async` ikut dimasukkan
# supaya daftar pengubahnya tidak perlu diperluas lagi.
DECL = re.compile(
    r'^\s*'
    r'(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s+)*'      # @ViewBuilder, @MainActor
    r'(?:(?:public|private|internal|fileprivate|open|static|final|mutating|'
    r'nonisolated|override|class|dynamic|lazy|weak|unowned)\s+)*'
    r'func\s', re.M)

problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        src = open(path, encoding="utf-8").read()
        # Komentar dibuang: berkas ini mendokumentasikan "kenapa" panjang
        # lebar dan beberapa menyebut `Color(red:` sebagai contoh cacat.
        code = []
        in_str = False
        for raw in src.split("\n"):
            out, esc, i = [], False, 0
            while i < len(raw):
                ch = raw[i]
                if in_str:
                    if esc:
                        esc = False
                    elif ch == "\\":
                        esc = True
                    elif ch == '"':
                        in_str = False
                else:
                    if ch == '"':
                        in_str = True
                    elif ch == "/" and i + 1 < len(raw) and raw[i + 1] == "/":
                        break
                out.append(ch)
                i += 1
            code.append("".join(out))
        src = "\n".join(code)

        # Batas fungsi: deklarasi `func` terdekat **sebelum** konstruksi
        # warna, sampai deklarasi `func` berikutnya.
        #
        # Kenapa bukan `rfind("\\nfunc")`: bentuk itu tidak pernah cocok
        # dengan `private static func warnaUji()` -- ada kata kunci akses di
        # depannya. `rfind` mengembalikan -1, rentangnya jatuh ke seluruh
        # berkas, dan penjaga `NightMode.isOn` di fungsi *lain* membuat
        # warna tanpa penjaga dilaporkan bersih. Gerbang ini pernah hijau
        # pada cacat yang disuntik persis seperti yang pernah nyata -- jadi
        # cacat pada gerbangnya ditemukan dengan menyuntik, bukan dibayangkan.
        decls = [d.start() for d in DECL.finditer(src)]
        for m in MAKING.finditer(src):
            before = [s for s in decls if s <= m.start()]
            start = before[-1] if before else 0
            after = [s for s in decls if s > m.start()]
            end = after[0] if after else len(src)
            body = src[start:end]
            if not GUARD.search(body):
                line = src[:m.start()].count("\n") + 1
                problems.append(
                    f"  {path}:{line}: {m.group(0)!r} tanpa penjaga "
                    f"NightMode.isOn di fungsi yang sama")

if problems:
    print("\n".join(problems))
    print("-> Pakai NightVisual.mapped(...) supaya warna malam dihitung,")
    print("   bukan ditulis tangan (rincian di NightVisual.swift).")
PY
)
if [ -n "$color_guard" ]; then
  echo "$color_guard"
  echo "   Sebab: sel batang ~498-530nm; merah >620nm aman. Warna yang"
  echo "   melewati penjaga memancarkan hijau/biru di mode malam."
  status=1
else
  echo "Bersih: setiap warna prosedural melewati penjaga mode malam."
fi

# ── Aturan 16: kalimat aksesibilitas harus datang dari katalog ─────────────
# Aturan 4 menyapu literal di dalam `accessibilityLabel(...)` — dan ia tetap
# hijau pada cacat yang nyata ada di repo ini:
#
# ```swift
# private var linkAccessibilityLabel: String {
#     var text = link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau"
#     ...
# }
# ```
#
# Dua sebab, dan keduanya sudah dipakai bentuk lain di berkas ini:
#
# 1. **Bentuknya**, bukan teksnya. Keduanya literal di dalam `var ... =` —
#    Aturan 12 menyapu penugasan ke properti berakhiran Note/Label/Title/…,
#    tapi `var text` berakhiran `text`, bukan salah satu dari itu.
# 2. **Nilainya bukan argumen peritel mana pun.** Ia dilalui ke
#    `.accessibilityLabel(linkAccessibilityLabel)`, jadi yang sampai ke
#    peritel hanyalah nama variabelnya.
#
# Yang membuatnya bertahan lama lebih halus: **baris yang sama sudah benar.**
# `linkRow` dua baris di atas menampilkannya lewat
# `TextLocalization.text(.pointingLinkConnected)` — jadi terlihat, pakai Bahasa
# Inggris, dan punya kunci katalog. Yang salah cuma kalimat untuk VoiceOver,
# tepat di sebelah yang benar. Kalau view dirender, tidak ada yang terlihat
# keliru.
#
# Tapi yang didengar adalah yang berbeda: pengguna VoiceOver mendengar Bahasa
# Indonesia sementara matanya membaca Bahasa Inggris, di komponen yang sama.
echo
echo "== Aturan 16: kalimat aksesibilitas tidak lahir sebagai literal =="
a11y_literal=$(python3 - <<'PY'
import os, re

# Satu-satunya peritelist: nama produk, yang memang tidak diterjemahkan.
#
# **Kenapa nilai katalog TIDAK diperbolehkan.** Itu sempat jadi "")
# whitelist di versi pertama - dengan alasan "kalimat ini sudah punya terjemahan". Dan whitelist itu persis yang membuat aturan ini hijau pada
# cacat yang diklaimnya menangkap: kunci katalog di repo ini **sama dengan
# teks Bahasa Indonesia-nya** (`pointing.link.connected` punya kunci
# `"iPhone terhubung"`), jadi setiap literal bermasalah cocok dengan nama
# kunci dan lolos.
#
# Yang ditanyakan aturan ini bukan "apakah kalimat ini punya padanan bahasa
# lain", melainkan "apakah layar membacanya lewat katalog". Kalimat literal
# tidak pernah melewati katalog, sekecil apa pun perbedaannya — dan itulah
# yang membuat pengucapan dan tampilan bisa berbeda bahasa di komponen yang
# sama.
NOT_LOCALIZED = {"Point & Know", "Experiment 1"}

# Yang dicari: variabel `String` yang (a) bodinya memuat literal bertanda
# kata, dan (b) hasilnya **benar-benar diumumkan** lewat modifier aksesibilitas.
#
# Kenapa dua syarat itu harus bersama:
#   - Tanpa (a), setiap `var label = "…"` di repo dilaporkan, termasuk yang
#     bukan teks UI (nama aset, pengenal internal) — gerbang yang terlalu
#     berisik akan dimatikan orang lain saat ia berbunyi.
#   - Tanpa (b), pemeriksaan tidak tahu mana yang **tampil ke pengguna**.
#     Kalimat yang tidak diucapkan tidak perlu diterjemahkan.
A11Y_USE = re.compile(
    r'accessibility(?:Label|Value|Hint)\(\s*([A-Za-z_][A-Za-z0-9_]*)')


def strip_line_comments(text):
    lines, out = [], []
    in_str = False
    for raw in text.split("\n"):
        line, esc, i = [], False, 0
        while i < len(raw):
            ch = raw[i]
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
            else:
                if ch == '"':
                    in_str = True
                elif ch == "/" and i + 1 < len(raw) and raw[i + 1] == "/":
                    break
            line.append(ch)
            i += 1
        out.append("".join(line))
    return "\n".join(out)


def is_sentence(value):
    """Apakah ini kalimat Bahasa Indonesia, bukan data atau format."""
    # Format printf / template koordinat: bukan teks tampilan.
    stripped = re.sub(r"%(?:%|(?:[-+ #0]*)(?:\d+|\*)?(?:\.\d+|\.\*)?[a-zA-Z@])",
                      "", value)
    stripped = re.sub(r"\\\(.*?\)", "", stripped)
    words = re.findall(r"[A-Za-z]{2,}", stripped)
    if not words:
        return False            # "54.2°" — angka & satuan, bukan kalimat
    if " " not in stripped.strip():
        return False            # satu kata = nama, bukan kalimat
    if re.fullmatch(r"[\w./:+-]+", stripped.strip()):
        return False            # pengenal: "pointing.state.lock"
    return True


problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        code = strip_line_comments(open(path, encoding="utf-8").read())

        # Hanya variabel yang hasilnya benar-benar diumumkan. Tanpa ini,
        # aturan ini akan meledak pada setiap `var label = "…"` di repo —
        # termasuk yang memang bukan teks UI (nama aset, label internal).
        announced = {m.group(1) for m in A11Y_USE.finditer(code)}
        if not announced:
            continue

        for m in re.finditer(
                r'\b(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*String\b',
                code):
            name = m.group(1)
            if name not in announced:
                continue
            # Badan variabel: dari deklarasi sampai penutup badan pada indentasi
            # yang sama.
            #
            # Kenapa kurung kurangnya dihitung, bukan `tail.find("\n    }")`:
            # accessor privat di `PointingView` closes dengan `\n    }`, tapi
            # accessor bersarang atau `body` punya indentasi berbeda — batas
            # yang dipatok akan menelan seluruh sisa berkas, dan literal di
            # view lain ikut dilaporkan sebagai punya variabel ini.
            tail = code[m.end():]
            body, depth = [], 0
            started = False
            for ch in tail:
                body.append(ch)
                if ch == "{":
                    depth += 1
                    started = True
                elif ch == "}":
                    depth -= 1
                    if started and depth == 0:
                        break
            body = "".join(body)
            for lit in re.findall(r'"([^"\\]{3,})"', body):
                if lit in NOT_LOCALIZED:
                    continue
                if not is_sentence(lit):
                    continue
                line = code[:m.start()].count("\n") + 1
                problems.append(
                    f"  {path}:{line}: {name} memuat literal {lit!r} "
                    f"dan dipakai accessibility*")
                break

if problems:
    print("\n".join(problems))
    print("-> Ambil dari katalog (TextLocalization.text) lewat kunci yang ada,")
    print("   atau taruh kalimatnya di PointingKit seperti kelas teks lain.")
PY
)
if [ -n "$a11y_literal" ]; then
  echo "$a11y_literal"
  echo "   Sebab: yang dilihat dan yang didengar harus bahasa yang sama."
  echo "   Kalimat literal hanya punya Bahasa Indonesia selamanya."
  status=1
else
  echo "Bersih: kalimat aksesibilitas berasal dari katalog."
fi

# ── Aturan 17: view harus memakai aksesor, bukan meniru kuncinya ────────────
# Aksesor di `PointingKit` yang bentuknya **murni wraps** satu kunci katalog
# dibuat dengan satu alasan: supaya teks yang tampil/diucapkan itu bisa
# **diuji di Linux**. Selama view masih memanggil
# `TextLocalization.text(.objectDisplayCoordinates, …)` secara langsung,
# alasan itu batal — teksnya tetap tidak bisa diuji, dan yang tersisa cuma
# salinan.
#
# Bentuk cacatnya unik di repo ini: tidak ada layar yang salah dan tidak ada
# gerbang yang merah. Isi kuncinya sama persis, jadi Aturan 4 (kunci ada di
# katalog) dan Aturan 6 (paritas) tetap hijau. Aksesornya yang mati
# terdokumentasi seolah dipakai — jadi orang berikutnya yang mengubah
# katalog akan mengubah aksesor yang layar tidak pernah baca.
echo
echo "== Aturan 17: view memakai pembungkus kunci dari PointingKit =="
wrapped=$(python3 - <<'PY'
import os, re

PKG = "Packages/PointingKit/Sources/PointingKit"
CALL = "TextLocalization.text("
KEYHEAD = re.compile(r'TextLocalization\.text\(\s*\.([A-Za-z_][A-Za-z0-9_]*)')


def strip_calls(body, fname):
    """Hapus `fname(...)` beserta argumennya, kurung seimbang.

    Kenapa argumen harus ikut dibuang: kalau hanya nama fungsinya yang
    dihapus, sisa `(.objectDisplayCoordinates, 101.287, -16.716)` masih
    tersisa dan setiap aksesor akan ternilai "tidak murni" — gerbang
    yang selalu hijau kembali.
    """
    out, i, n = [], 0, len(body)
    while i < n:
        if body.startswith(fname, i) and (i == 0 or not body[i - 1].isalnum()):
            j = body.find("(", i)
            if j < 0:
                out.append(body[i])
                i += 1
                continue
            depth, k = 0, j
            while k < n:
                if body[k] == "(":
                    depth += 1
                elif body[k] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                k += 1
            i = k + 1
            continue
        out.append(body[i])
        i += 1
    return "".join(out)


def bodies(src):
    for m in re.finditer(r'public static (?:var|func) ([A-Za-z_][A-Za-z0-9_]*)',
                         src):
        i = src.find("{", m.end())
        if i < 0:
            continue
        depth, j = 0, i
        while j < len(src):
            if src[j] == "{":
                depth += 1
            elif src[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        yield m.group(1), src[i + 1:j]


# Kunci -> aksesor yang **membungkusnya tanpa logika lain**.
#
# Syarat "murni" itu yang menjaga gerbang ini dari positif palsu: `spokenRate`
# menghitung satuan lebih dulu lalu meneruskan ke kunci, jadi ia bukan
# pembungkus murni dan pemanggilan kuncinya di dalam paket tidak dihitung.
# Yang dinilai hanya pemanggilan **di `Apps/`** — satu-satunya lapisan yang
# tidak bisa diuji di Linux.
owned = {}
for name in sorted(os.listdir(PKG)):
    if not name.endswith(".swift"):
        continue
    src = open(os.path.join(PKG, name), encoding="utf-8").read()
    for accessor, body in bodies(src):
        keys = KEYHEAD.findall(body)
        if not keys:
            continue
        residue = strip_calls(body, CALL)
        # Komentar dulu, lalu whitespace. Kenapa urutan itu penting: kalau
        # whitespace lebih dulu dihapus, `// x` dan `/* */` menyatu jadi
        # `/.../` dan sisa "//"-nya ikut hilang dengan sendirinya --
        # satu baris komentar masih akan lolos sebagai "murni".
        residue = re.sub(r'//[^\n]*', '', residue)
        residue = re.sub(r'/\*.*?\*/', '', residue, flags=re.S)
        residue = "".join(residue.split())
        for junk in ("return", "{", "}", ";"):
            residue = residue.replace(junk, "")
        if residue:
            continue          # bukan pembungkus murni: di luar cakupan
        for k in keys:
            owned.setdefault(k, []).append(f"{name}:{accessor}")

hits = []
for root, _, files in os.walk("Apps"):
    for fname in sorted(files):
        if not fname.endswith(".swift"):
            continue
        path = os.path.join(root, fname)
        src = open(path, encoding="utf-8").read()
        for i, line in enumerate(src.split("\n"), 1):
            if line.lstrip().startswith("//"):
                continue
            for k in KEYHEAD.findall(line):
                if k in owned:
                    hits.append(f"  {path}:{i}: .{k} -> {owned[k]}")

print("\n".join(hits))
PY
)
if [ -n "$wrapped" ]; then
  echo "$wrapped"
  echo "-> Panggil aksesornya (mis. ObjectSpeech.magnitudeDisplay(...)),"
  echo "   jangan tulis ulang pemanggilan kuncinya. Aksesor itulah yang"
  echo "   membuat baris ini bisa diuji di Linux."
  status=1
else
  echo "Bersih: view memakai pembungkus kuncinya."
fi

# ── Aturan 18: klaim identitas tidak boleh berbaku `true` ──────────────────
# PRD: "JANGAN pernah menampilkan visual yang mengklaim identitas saat engine
# RAGU" dan "uncertainty > false confidence". Keduanya menetapkan **arah** dari
# kegagalan yang bisa diterima: terlalu hati-hati boleh, terlalu yakin tidak.
#
# Kenapa perlu aturan sendiri. Nilai bawaan parameter adalah satu-satunya
# nilai di Swift yang **tidak pernah muncul di pemanggil**. Pemanggil yang
# meneruskan `isConfirmed: engine.confirmsDisplayedIdentity` menulis
# keyakinannya di layar dan bisa dibaca; pemanggil yang lupa tidak menulis
# apa-apa, dan yang berjalan adalah nilai bawaan — persis kelas "dihitung lalu
# dibuang" yang berulang di repo ini, dalam bentuk yang tidak punya baris
# untuk diperiksa.
#
# Tiga tempat di `Apps/` membawa baku `= true` untuk nama ini (gambar jam,
# gambar iPhone, dan label suara panel iPhone). Semuanya sudah diperbaiki ke
# `false`, dan semuanya memang dipanggil dengan argumen eksplisit hari ini —
# jadi perbaikannya **tidak mengubah satu piksel pun**. Yang diubah adalah
# jawaban untuk layar yang ditulis besok.
#
# Yang diperiksa: deklarasi `Bool = true` yang namanya menyatakan klaim
# identitas (`isConfirmed` dan turunannya). Pemeriksanya membaca **kode**,
# bukan komentar, karena berkas-berkas ini mendokumentasikan cacatnya dengan
# menyebut `isConfirmed: Bool = true` sebagai contoh.
echo
echo "== Aturan 18: klaim identitas tidak boleh berbaku true =="
claim_default=$(python3 - <<'PY' 2>&1
import os, re

# Nama yang menyatakan "bolehkah gambar/suara mengklaim identitas ini".
# `isStale` sengaja tidak masuk: ia menyatakan umur, dan `true` di sana
# berarti "tampilkan peringatan" -- arah yang justru lebih aman.
#
# **Versi pertama regex ini buta pada bentuk yang paling sering ditulis.**
# Ia menuntut `var`/`let` sebagai token **pertama** di baris. Terukur dengan
# menyuntikkan satu per satu ke `Apps/`:
#
#   `    private var isConfirmed: Bool = true`   -> HIJAU (lolos)
#   `    static var isConfirmed: Bool = true`    -> HIJAU
#   `    @State private var isConfirmed: Bool = true` -> HIJAU
#   `    private let claimIdentity: Bool = true` -> HIJAU
#   `    private(set) var isConfirmed: Bool = true` -> HIJAU
#   `    var isConfirmed: Bool = true`           -> merah (satu-satunya)
#
# Artinya seluruh kode `Apps/` yang asli **tidak satu pun** diperiksa oleh
# versi ini: `private`/`static`/`@State`/`private(set)` adalah bentuk normal
# deklarasi properti di app SwiftUI. Aturan ini karena itu hijau bukan karena
# nilainya sudah `false`, melainkan karena ia tidak pernah membaca baris yang
# memuat nilai itu -- persis kelas "hijau karena tidak mengukur apa pun" yang
# aturan ini ada untuk menutup, kali ini pada dirinya sendiri.
#
# Yang dijaga sekarang **bentuk deklarasinya**, bukan token pertamanya:
# pengubah akses, `static`, atribut properti (`@State`, `@AppStorage("k")`,
# dengan atau tanpa argumen), dan `private(set)`. Yang dicari adalah
# `var`/`let` + nama + `: Bool = true` di mana pun setelah awalan itu.
#
# **Anotasi `: Bool` tetap wajib**, dan itu keputusan sadar: `var isConfirmed
# = true` tanpa anotasi tipe juga lolos hari ini, tapi menutupnya menuntut
# aturan mengenali tipe hasil inferensi. Anotasinya yang membuat baris ini
# bisa dibaca tanpa menebak -- dan `Bool = true` adalah bentuk yang ditulis
# orang yang sedang **mendeklarasikan nilai bawaan**, bukan kebetulan.
#
# **`static` sengaja TIDAK dikecualikan, walaupun satu anggota statis di
# `Apps/` memakai baku `true` secara sah** (`LockArrivalPanel` tidak, tapi
# `includeTechnicalDetails` di `DiagnosticsView.swift:977` memakai
# `Bool = true` sebagai baku parameter *fungsi* -- bentuk yang berbeda dan
# tidak ditangkap pola ini). Aturan yang mengecualikan `static` akan kembali
# buta pada `static var isConfirmed` -- bentuk yang justru dipakai
# `CelestialVisualView.isConfirmed` kalau kelak dipromosikan. Nilai bawaan
# `true` untuk nama yang menyatakan klaim identitas salah di kedua konteks,
# jadi tidak ada pengecualian yang bisa dibenarkan di sini.
CLAIM = re.compile(
    r'^\s*'
    r'(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s+)*'   # @State, @AppStorage("k")
    r'(?:(?:public|internal|fileprivate|private|open|final|static|'
    r'mutating|nonisolated|lazy|weak|unowned)(?:\(set\))?\s+)*'  # + private(set)
    r'(?:var|let)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)\s*:\s*Bool\s*=\s*true\s*$')
NAMES = re.compile(r'(?i)(isconfirmed|confirmsidentity|confirmsdisplayed'
                   r'|identityconfirmed|claim)')

problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        for i, line in enumerate(open(path, encoding="utf-8"), 1):
            # Komentar dibuang: berkas ini menyebut bentuk cacatnya sebagai
            # contoh, dan `//` bisa muncul setelah kode pada baris yang sama --
            # jadi yang diperiksa hanya bagian sebelum `//`.
            code = line.split("//", 1)[0]
            m = CLAIM.match(code)
            if m and NAMES.search(m.group(1)):
                problems.append(
                    f"  {path}:{i}: {m.group(1)}: Bool = true "
                    f"-> nilai bawaan harus false")

if problems:
    print("\n".join(problems))
    print("-> Nilai bawaan adalah jawaban untuk pemanggil yang LUPA")
    print("   meneruskan keyakinan; ia harus memihak ke 'terlalu hati-hati'.")
PY
)
if [ -n "$claim_default" ]; then
  echo "$claim_default"
  echo "   Sebab: PRD melarang visual yang mengklaim identitas saat ragu."
  echo "   Baku true menggambar cincin Saturnus di bawah badge \"Ragu\"."
  status=1
else
  echo "Bersih: klaim identitas tidak ada yang berbaku true."
fi

# ── Aturan 19: kunci katalog yang tak terpakai (kunci yatim) ───────────────
# Aturan 6 menjaga paritas dua arah, tapi hanya untuk kunci **ber-namespace**
# (`pointing.state.`, `confidence.level.`, `link.kind.`, `object.kind.`). Kunci
# di luar namespace itu tidak pernah dicek arah baliknya: katalog boleh
# memuat entri yang tidak dirujuk oleh satu baris kode pun, dan suite tetap
# hijau.
#
# Ini bukan sekadar kerapian. Katalog adalah **satu-satunya** sumber teks
# untuk bahasa selain Bahasa Indonesia, dan entri yatim mengaku sebagai
# terjemahan yang belum diverifikasi siapa pun. Lebih buruk: entri yatim
# berpotensi menutupi kebalikannya. Kalau kode memanggil kunci yang **hanya**
# ada di katalog sebagai entri yatim (bukan lewat `TextLocalization`), maka
# `TextLocalization.text()` jatuh ke nilai bawaan Bahasa Indonesia tanpa
# pernah memberi tahu -- persis kelas "hijau yang tidak hijau" yang menjadi
# alasan Aturan 6 ditulis.
#
# Yang ditemukan saat aturan ini ditulis: `Status: %@.` -- satu entri berkunci
# literal (bukan `calibration.statusPrefix`), tanpa satu rujukan pun di
# `Apps/` maupun `Packages/`, lengkap dengan terjemahan `en`. Satu-satunya
# kunci yatim di katalog. Ia dihapus, dan aturan ini mencegahnya kembali.
#
# Pemeriksaannya sengaja **menyilang seluruh berkas .swift**: kunci bisa
# dirujuk lewat `key:`, lewat enum ber-kasus, atau lewat `LocalizedText`.
# Yang dihitung adalah ketiadaan kunci di seluruh kode sumber.
#
# **Batas yang sebelumnya salah, dan dua kunci yang ia sembunyikan.** Sampai
# siklus ini pencariannya adalah `k in source` — kunci yang **muncul di mana
# saja** dihitung sebagai dirujuk. Dua bentuk kematian kunci lolos dari itu,
# dan keduanya terukur di katalog ini:
#
#   - `'%lld gagal'`. Bentuknya adalah **teks bawaan** (`id:`) milik kunci
#     lain: `pointing.link.failures` berbunyi `id: "· %lld gagal"`, dan itu
#     memuat `'%lld gagal'` sebagai potongan. Kuncinya sendiri tidak dipanggil
#     siapa pun -- yang ada hanyalah salinan teksnya di dalam berkas lain.
#     Bentuk ini tidak bisa ditutup oleh paritas (`Aturan 6` hanya melihat
#     kunci ber-namespace; `'%lld gagal'` tidak punya namespace) maupun oleh
#     uji kelengkapan `en` (entrinya memang punya `en`, jadi ia lulus).
#   - `'GoTo'`. Bentuknya adalah **komentar yang mendokumentasikan
#     penghapusannya sendiri**. Ia dulu judul baris `row("GoTo", verdict)`;
#     baris itu diganti `SlewVerdictBanner` karena bobot visualnya salah, dan
#     komentar yang menjelaskan penggantian itu menulis `"GoTo"` dengan tanda
#     kutip. Jadi satu-satunya rujukan ke kunci itu adalah catatan bahwa ia
#     tidak lagi dipakai.
#
# Karena itu yang dicari adalah **literal berkutip** (`"kunci"`), di dalam
# sumber yang komentarnya sudah dikosongkan. Isi string **tidak** dikosongkan:
# kunci memang hidup di dalam string. Hanya `.swift` yang dipindai -- `.md`,
# `.yml`, dan JSON katalognya sendiri bisa memuat nama kunci apa pun, dan
# memindai mereka berarti katalog merujuk dirinya sendiri.
#
# **Berkas uji tidak ikut dipindai**, dan itu keputusan cakupan yang disengaja.
# Kunci katalog ada untuk **UI yang dikirim ke pengguna**; berkas uji bukan
# pemakainya. Bentuk ketiga kematian kunci adalah justru ini, dan ia terukur:
# `'sisa'` -- label layar redup satu kata. Satu-satunya rujukan berkutip ke
# `"sisa"` di seluruh repo ada di `ObjectSpeechTests.swift`, pada
# `XCTAssertTrue(note.lowercased().contains("sisa"))`. Uji itu tidak memakai
# kunci `'sisa'`; ia menegaskan teks **bawaan** kunci lain (`object.speech.
# stale.short`) memuat kata "sisa" -- dan justru untuk menyatakan bahwa bentuk
# satu kata itu **sengaja tidak dipakai**. Jadi uji itu menjaga keputusan yang
# membuat kunci `'sisa'` mati, sambil menjadi satu-satunya alasan kunci itu
# terlihat hidup. Mengeluarkan berkas uji dari cakupan adalah yang membuat
# lingkaran itu putus; dan ia tidak menambah yatim lain di pohon ini
# (terukur: `'sisa'` satu-satunya).
echo
echo "== Aturan 19: kunci katalog yang tidak dipakai kode mana pun =="
orphan_keys=$(python3 - <<'PY' 2>&1
import json, os

CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"
if not os.path.exists(CATALOG):
    print("BELUM-ADA-KATALOG")
    raise SystemExit(0)

strings = json.load(open(CATALOG, encoding="utf-8"))["strings"]


def strip_comments(text):
    """Kosongkan komentar, pertahankan isi string apa adanya.

    Isi string **tidak** dikosongkan: kunci katalog hidup di dalam string.
    Yang dibuang hanya komentar, karena komentar yang **menyebut** sebuah kunci
    bukan pemakaian -- dan justru komentar seperti itu yang menjaga kunci mati
    tetap terlihat hidup.
    """
    out, i, n = [], 0, len(text)
    in_string = escaped = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


# Seluruh kode sumber, sekali, menjadi satu teks. Kunci bisa dirujuk dari
# Apps/ (pemanggil) maupun Packages/ (deklarasi kunci), jadi kedua pohon
# harus ikut -- memeriksa hanya satu pohon akan melaporkan kunci yang sah
# sebagai yatim, dan itulah "merah yang tidak merah".
blob = []
for root in ("Apps", "Packages"):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".build"]
        # Berkas uji bukan pemakai katalog: kunci katalog ada untuk UI yang
        # dikirim. Lihat alasan lengkapnya di komentar Aturan 19.
        if "/Tests/" in dirpath.replace(os.sep, "/"):
            continue
        for name in sorted(filenames):
            if name.endswith(".swift"):
                path = os.path.join(dirpath, name)
                try:
                    blob.append(strip_comments(
                        open(path, encoding="utf-8", errors="ignore").read()))
                except OSError:
                    continue
source = "\n".join(blob)

orphans = sorted(k for k in strings if f'"{k}"' not in source)
print("\n".join(f"  {k!r}" for k in orphans))
PY
)
if [ "$orphan_keys" = "BELUM-ADA-KATALOG" ]; then
  echo "Katalog belum ada: aturan 19 belum berlaku, bukan kegagalan."
elif [ -n "$orphan_keys" ]; then
  echo "Katalog memuat kunci yang tidak dirujuk kode mana pun:"
  printf '%s\n' "$orphan_keys"
  echo "-> Hapus entri itu, atau rujuk ia dari kode. Entri yatim adalah"
  echo "   terjemahan yang tidak diverifikasi siapa pun."
  status=1
else
  echo "Bersih: setiap kunci katalog dirujuk oleh kode."
fi

# ── Aturan 20: permukaan kartu harus dari token, bukan campuran warna ====
# Aturan 15 menjaga **warna prosedural** (planet, bintang, bulan) supaya
# tidak memancarkan hijau/biru di mode malam. Ia tidak melihat permukaan.
#
# Yang dilihatnya: kartu yang membangun latarnya sendiri dengan
# `warna.opacity(alpha)` di atas apa pun yang ada di belakangnya. Operasi itu
# menghasilkan warna yang **tidak pernah dihitung siapa pun**, jadi kontras
# teks di atasnya tidak dijamin.
#
# Cacat nyatanya, dan kenapa hanya mode malam yang menunjukkannya: kartu tahap
# kalibrasi memakai `phaseTone.color.opacity(0.12)`. Di mode malam nada paling
# redup yang benar-benar dipakai (`.neutral`, merah 0.94) di atas latar malam
# menghasilkan merah ~0.154, sementara teksnya berwarna nada yang sama -> 4.32:1,
# di bawah ambang 4.5 yang brief nyatakan sebagai syarat. Di mode siang cacat
# yang sama ada tapi tidak terlihat sebagai kesalahan: kartunya hanya jadi ~2x
# lebih terang dari kartu tetangganya, dan tidak ada teks yang gagal.
#
# Kenapa gerbang lama hijau: kontras bergantung pada **campuran**, dan tidak
# ada satu pun uji yang menghitung campuran itu — `TonePaletteTests` menguji
# teks di atas permukaan token, bukan di atas latar yang dirakit view.
#
# Perbaikannya bukan "alpha lebih kecil": itu menyembunyikan cacat yang sama
# sampai nada berikutnya ditambahkan. Permukaan kartu harus datang dari
# `SurfacePalette` (`surfaceCard`), yang kontrasnya sudah diuji terhadap semua
# nada. Yang diperiksa karena itu: `.background(`/`.fill(` yang argumennya
# berakhir `.color.opacity(`, di berkas `Apps/`.
echo
echo "== Aturan 20: permukaan kartu tidak dirakit dari warna yang tidak diuji =="
ad_hoc_surface=$(python3 - <<'PY' 2>&1
import os, re

# Bentuk yang dilarang: sebuah warna bertoken (`.color`) diredupkan dengan
# `.opacity(...)` dan dipakai sebagai latar/isi. `.color` sengaja disyaratkan
# supaya `Color.black.opacity(...)` (bayangan di dalam gambar prosedural) dan
# `palette.surface2.color.opacity(...)` (bagian dari definisi token itu
# sendiri) tidak ikut tertangkap.
#
# **Kenapa argumennya diekstrak berimbang, bukan dicocokkan baris demi baris.**
# Versi sebelumnya mencocokkan pola ini atas **satu baris** pada satu waktu, dan
# itu bukan detail gaya: `.background(` dan `.color.opacity(` yang terpisah
# baris tidak pernah cocok. Terukur (8 keadaan,
# `Tools/bukti-mutasi-permukaan.py`): memformat cacat asli yang **sama** menjadi
#
#     Text("x").background(
#         tone.color.opacity(0.12))
#
# membiarkan aturan ini **hijau**, padahal bentuk satu-barisnya merah. Yang
# menentukan apakah aturan ini menggigit jadi **gaya pemformatan**, bukan ada
# tidaknya cacat — dan repo ini menulis rantai modifier multi-baris di banyak
# tempat. Jalan kedua ke cacat yang sama (`tone.color\n    .opacity(0.12)`)
# juga lolos.
#
# Pola lamanya pun memakai `[^)]*`, yang **tidak bisa melewati satu `)` pun**;
# argumen yang memuat pemanggilan bersarang (`pilih(tone.color.opacity(0.12))`)
# hanya kebetulan tertangkap karena `.color.opacity(` kebetulan mendahului `)`
# pertama.
#
# Karena itu sekarang: komentar dibuang (hormat pada literal string — sama
# seperti Aturan 29; tanpa itu docstring yang **menjelaskan** pola ini akan
# dihitung sebagai temuan), isi literal string dikosongkan, lalu setiap
# `.(background|fill)(` diambil **argumennya secara berimbang** dan polanya
# diuji di dalam teks argumen itu — bukan di satu baris.
#
# Batas yang dinyatakan, bukan disangka tertutup: `background`/`fill` saja,
# sesuai docstring aturan ini. `.overlay(warna)` yang mencampur token dengan
# `.opacity(` tidak diperiksa — belum ada situsnya di `Apps/`, dan melebarkan
# cakupan tanpa situs nyata hanya menambah risiko positif palsu tanpa menambah
# satu pun cacat yang tertangkap. Nilai campuran yang dipindahkan ke variabel
# perantara (`let bg = tone.color.opacity(0.12)`) juga di luar jangkauan:
# melacaknya menuntut pelacakan aliran, dan gerbang yang salah merah pada kode
# benar akan dimatikan orang.
def _swift_code(text):
    """Buang komentar `//` dan `/* */` yang berada di luar literal string."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            out.append(c)
            i += 1
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    out.append(text[i:i + 2])
                    i += 2
                    continue
                out.append(text[i])
                if text[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i)
            i = n if j < 0 else j + 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _blank_strings(text):
    """Kosongkan isi literal string supaya kalimat tidak dicocokkan sebagai kode."""
    out, i, n = [], 0, len(text)
    while i < n:
        if text[i] == '"':
            out.append('"')
            i += 1
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    i += 2
                    continue
                if text[i] == '"':
                    out.append('"')
                    i += 1
                    break
                out.append(" ")
                i += 1
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


AD_HOC = re.compile(r'\.color\s*\.\s*opacity\s*\(')
CALL = re.compile(r'\.(?:background|fill)\s*\(')

problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        code = _swift_code(open(path, encoding="utf-8").read())
        for m in CALL.finditer(code):
            depth, i, n = 1, m.end(), len(code)
            while i < n and depth:
                if code[i] in "([{":
                    depth += 1
                elif code[i] in ")]}":
                    depth -= 1
                i += 1
            arg = _blank_strings(code[m.end():i - 1])
            if AD_HOC.search(arg):
                line = code[:m.start()].count("\n") + 1
                problems.append(f"  {path}:{line}: {arg.strip()[:70]!r}")

if problems:
    print("\n".join(problems))
    print("-> Pakai `.surfaceCard(level:)` / `SurfacePalette` supaya kontrasnya")
    print("   dihitung, bukan dirakit di view (rincian di SurfacePalette.swift).")
PY
)
if [ -n "$ad_hoc_surface" ]; then
  echo "$ad_hoc_surface"
  echo "   Sebab: warna hasil campuran tidak ada di palet, jadi kontras teks"
  echo "   di atasnya tidak pernah diuji — dan di mode malam itulah yang gagal."
  status=1
else
  echo "Bersih: setiap permukaan kartu datang dari token yang diuji."
fi

# ── Aturan 21: denyut harus digerbangi `hasPulse` ──────────────────────────
# Aturan 7 memastikan API gerak **punya penjaga** di berkasnya. Ia tidak bisa
# melihat apakah denyut benar-benar sampai ke gambar, dan tidak bisa melihat
# apakah ia sampai ke gambar yang **tidak seharusnya** berdenyut.
#
# Dua cacat nyata, dua arah:
# 1. Kartu jam tidak pernah meneruskan `pulse` sama sekali. Bintang yang di
#    iPhone berdenyut halus diam total di jam — permukaan utamanya — padahal
#    komentar `CelestialVisualView` sendiri menulis denyut diberi dari luar
#    "supaya jam bisa menghentikannya saat layar redup".
# 2. `Canvas` digambar ulang setiap kali nilai yang ditangkapnya berubah.
#    `pulse` yang bergerak 20x/detik karena itu memaksa planet, Bulan, dan
#    Matahari digambar ulang 20x/detik untuk piksel yang identik — denyut
#    hanya dibaca `drawStar`. Di jam, view memang sudah dirender 20 Hz oleh
#    sampel sensor, jadi ini ongkos yang nyata: baterai, di layar yang paling
#    peduli baterai.
#
# **Kenapa "menyebut `hasPulse`" bukan gerbang — diukur, bukan ditebak.**
#
# Versi pertama aturan ini mencari `re.search(r"\bhasPulse\b", args)` atas
# seluruh daftar argumen. Terukur (Tools/ukur-cakupan-aturan21.py, commit
# `a229176`): **1 dari 5** keadaan cacat berbunyi. Empat sisanya lolos,
# masing-masing **menyebut** `hasPulse` dan masing-masing tampak digerbangi
# pada tinjauan kode:
#
#   pulse: !visual.hasPulse ? pulsePhase : 0   denyut mengalir ke planet,
#                                              mati pada bintang — kebalikan
#                                              maksud aturan ini
#   pulse: visual.hasPulse ? 0 : pulsePhase    cabang benarnya nol, bintang
#                                              tidak pernah berdenyut
#   visual: v.hasPulse ? v : v, pulse: 0.8     hasPulse di argumen `visual:`
#   hasPulse: true, pulse: 0.7                 sebuah **label argumen**
#
# Yang membedakan gerbang sungguhan bukan keberadaan nama itu, melainkan
# **posisinya**: di dalam ekspresi yang menghasilkan nilai denyutnya, pada
# cabang yang benar, tanpa dinegasikan.
#
# Yang diperiksa sekarang, untuk setiap `pulse:` bernilai bukan-nol:
#   1. ekspresi nilai denyutnya memuat `hasPulse`;
#   2. `hasPulse` tidak dinegasikan (`!hasPulse`, `== false`, `!= true`);
#   3. cabang **benar** dari `? :` bukan nol, dan cabang **salah** yang
#      bukan-nol → denyut terbalik.
#
# Nama itu properti teruji di Linux (`CelestialVisual.hasPulse`), jadi
# aturannya tidak bergantung pada daftar jenis lokal yang bisa basi.
#
# **Batas yang dinyatakan, bukan disangka tertutup.** Gerbang yang sah
# ditulis di variabel perantara (`let p = visual.hasPulse ? fase : 0` lalu
# `pulse: p`) tetap hijau — melacaknya menuntut pelacakan aliran, dan
# gerbang yang menebak akan merah pada kode benar.
echo
echo "== Aturan 21: denyut gambar digerbangi hasPulse =="
ungated_pulse=$(python3 - <<'PY' 2>&1
import os, re

CALL = "CelestialVisualView("
# Nilai yang dianggap "denyut mati": pemanggil tidak menggerakkan apa pun.
MATI = ("0", "0.0", ".zero",
        # Konstanta model untuk gambar statis (`MotionPolicy`), diuji sama
        # dengan nol di Linux. Ditambahkan bersamaan dengan Aturan 21 awal,
        # bukan sebagai kelonggaran: tanpa ia, pemanggil yang **sengaja**
        # memilih diam — ilustrasi onboarding, layar redup — dilaporkan sama
        # dengan pemanggil yang lupa, dan dua keadaan yang berbeda artinya
        # dilaporkan sebagai satu. Tiga jalur "denyut mati" dulu menulis `0`
        # masing-masing; sekarang satu nama dengan satu nilai yang diuji.
        "MotionPolicy.staticPulsePhase",
        "staticPulsePhase")


def ekspresi_nilai(args):
    """Teks argumen `pulse:`-nya saja — bukan seluruh daftar argumen.

    Inilah inti perbaikannya. Mencari `hasPulse` di **seluruh** daftar
    argumen membuat `visual: v.hasPulse ? v : v, pulse: 0.8` lolos, dan
    sebuah label argumen bernama `hasPulse` lolos. Yang menentukan
    gerbangnya adalah ekspresi yang menghasilkan **nilai denyutnya**.
    """
    for arg in re.split(r",(?![^()\[\]]*[)\]])", args):
        m = re.match(r"\s*pulse\s*:\s*(.*)$", arg, re.S)
        if m:
            return m.group(1).strip()
    # `pulse:` bisa hidup di dalam argumen yang memuat koma bersarang;
    # jatuh kembali ke pencarian lama agar bentuk itu tidak **hilang**.
    m = re.search(r"\bpulse\s*:\s*(.*)", args, re.S)
    return m.group(1).strip() if m else None


def terbalik(nilai):
    """`hasPulse` yang dinegasikan: denyut jalan tepat saat gambar diam."""
    return bool(re.search(r"!\s*\w*\.?\s*hasPulse|"
                          r"hasPulse\s*(?:==\s*false|!=\s*true)", nilai))


def cabang_salah(nilai):
    """Cabang `? :` yang **benar** nol, atau yang **salah** bukan nol.

    `visual.hasPulse ? 0 : pulsePhase` menyebut gerbang yang benar pada
    posisi yang benar, tetapi denyutnya mati. Tanpa pemeriksaan ini,
    "menyebut hasPulse" sudah cukup untuk lolos walau bintang diam.
    """
    if "?" not in nilai or ":" not in nilai:
        return False
    # Ambil cabang benar & salah pada `?` tingkat teratas.
    i = nilai.index("?")
    j = nilai.rindex(":")
    if j < i:
        return False
    benar, salah = nilai[i + 1:j].strip(), nilai[j + 1:].strip()
    return benar in MATI or salah not in MATI


problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = open(path, encoding="utf-8").read()
        # Komentar dibuang sebelum mencari argumen: dokumentasi aturan ini
        # sendiri menyebut `pulse:` dan akan melaporkan dirinya sendiri.
        lines = text.split("\n")
        code_lines = [l.split("//", 1)[0] for l in lines]
        code = "\n".join(code_lines)
        start = 0
        while True:
            i = code.find(CALL, start)
            if i < 0:
                break
            # Telusuri sampai tanda kurung seimbang -> seluruh daftar argumen.
            j = i + len(CALL)
            depth = 1
            while j < len(code) and depth:
                if code[j] == "(":
                    depth += 1
                elif code[j] == ")":
                    depth -= 1
                j += 1
            args = code[i + len(CALL):j - 1]
            start = j
            value = ekspresi_nilai(args)
            if value is None or value in MATI:
                continue
            line_no = code[:i].count("\n") + 1
            if not re.search(r"\bhasPulse\b", value):
                problems.append(
                    f"  {path}:{line_no}: pulse: {value[:40]} tanpa hasPulse "
                    "di ekspresi nilainya")
            elif terbalik(value):
                problems.append(
                    f"  {path}:{line_no}: pulse: {value[:40]} — hasPulse "
                    "dinegasikan, denyut jalan tepat saat gambar diam")
            elif cabang_salah(value):
                problems.append(
                    f"  {path}:{line_no}: pulse: {value[:40]} — cabang "
                    "hasPulse=true nol (atau cabang salahnya bukan nol)")

if problems:
    print("\n".join(problems))
    print("-> Gerbangi dengan `visual.hasPulse`: `pulse: visual.hasPulse ? fase : 0`.")
    print("   Tanpa gerbang, planet digambar ulang 20x/detik untuk piksel yang sama.")
PY
)
if [ -n "$ungated_pulse" ]; then
  echo "$ungated_pulse"
  echo "   Sebab: Canvas digambar ulang tiap nilai tangkapan berubah; denyut"
  echo "   hanya dibaca drawStar, jadi denyut pada planet cuma membuang baterai."
  echo "   `hasPulse` yang hanya **disebut** (di argumen lain, dinegasikan,"
  echo "   atau cabangnya terbalik) bukan gerbang."
  status=1
else
  echo "Bersih: setiap denyut gambar digerbangi hasPulse pada cabang yang benar."
fi

# ── Aturan 22: judul & nilai satu baris tidak boleh kunci yang sama ─────────
# Aturan 4 menuntut teks tampilan punya **kunci**; Aturan 6 menuntut kunci itu
# **ada di katalog**. Keduanya hijau untuk baris yang judulnya memakai kunci
# *nilainya* — dan baris seperti itu tidak pernah menyebut apa yang diukur.
#
# Cacat nyata yang menutup siklus ini: `SkyContextView` menulis
#
#     row(TextLocalization.text(.skyContextDark),      // judul → "Gelap"
#         context.isDark ? ... .skyContextDark         // nilai → "Gelap"
#                        : ... .skyContextLight)       // nilai → "Terang"
#
# sehingga barisnya tampil **"Gelap: Gelap"** (atau "Gelap: Terang"). Katalog
# bahkan sudah menyebut peran yang benar di komentarnya sendiri ("Nilai baris
# kegelapan langit"), tapi view memakai kunci yang salah, dan tidak ada gerbang
# yang bisa melihatnya: yang salah bukan keberadaan kunci, bukan paritas, dan
# bukan kosakata — melainkan **peran**. Judul harus menamai barisnya, nilai
# harus mengisi barisnya; keduanya tidak boleh benda yang sama.
#
# Yang diperiksa: pada setiap `row`/`detailRow`, himpunan kunci katalog di
# argumen **judul** dan di argumen **nilai** tidak boleh beririsan. `detailRow`
# ikut karena ia peritel label-lebar yang sama (lihat POS_NAMES).
echo
echo "== Aturan 22: judul baris tidak memakai kunci nilainya =="
row_key_reuse=$(python3 - <<'PY' 2>&1
import os, re

CALLS = ("row(", "detailRow(")
# Kunci katalog **yang benar-benar dipakai lewat `TextLocalization.text`**.
# Sengaja sempit: `\.([a-z]\w*)` polos akan menangkap `text`, `isDark`, dan
# setengah repo, dan gerbang yang selalu merah akan dimatikan orang lain saat
# ia berbunyi.
KEY = re.compile(r"TextLocalization\s*\.\s*text\s*\(\s*\.([A-Za-z][A-Za-z0-9]*)")

def split_args(src, open_index):
    """Argumen tingkat atas sebuah panggilan, menghormati kurung & string."""
    args, depth, i, start, in_str, esc = [], 0, open_index, open_index + 1, False, False
    while i < len(src):
        ch = src[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                args.append(src[start:i])
                return args
        elif ch == "," and depth == 1:
            args.append(src[start:i])
            start = i + 1
        i += 1
    args.append(src[start:])
    return args

problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = open(path, encoding="utf-8").read()
        code = "\n".join(l.split("//", 1)[0] for l in text.split("\n"))
        for call in CALLS:
            start = 0
            while True:
                i = code.find(call, start)
                if i < 0:
                    break
                start = i + len(call)
                # `detailRow(` sudah tercakup oleh `row(`; jangan dihitung dua.
                if call == "row(" and code[max(0, i - 6):i].endswith("detail"):
                    continue
                if i > 0 and (code[i - 1].isalnum() or code[i - 1] in "._"):
                    continue
                args = split_args(code, i + len(call) - 1)
                if len(args) < 2:
                    continue
                title_keys = set(KEY.findall(args[0]))
                value_keys = set(KEY.findall(args[1]))
                shared = title_keys & value_keys
                if shared:
                    line_no = code[:i].count("\n") + 1
                    problems.append(
                        f"  {path}:{line_no}: judul & nilai memakai kunci "
                        f"yang sama: {', '.join(sorted(shared))}")

if problems:
    print("\n".join(problems))
    print("-> Judul harus menamai barisnya (mis. `skyContext.skyLabel` = "
          "\"Langit\"), bukan mengulang nilainya.")
    print("   Tanpa itu barisnya terbaca \"Gelap: Gelap\" dan tidak pernah "
          "menyebut apa yang diukur.")
PY
)
if [ -n "$row_key_reuse" ]; then
  echo "$row_key_reuse"
  status=1
else
  echo "Bersih: tidak ada judul baris yang memakai kunci nilainya."
fi

# ── Aturan 23: complication inline wajib menandai keraguan lewat ikon ───────
# Complication punya dua kanal: satu ikon dan satu baris teks. Model sudah
# menyediakan keduanya (`presentedSymbolName(at:)`, `sublineContent(at:)`), dan
# dokumentasi `presentedSymbolName` sendiri menulis alasannya: "satu kata
# tambahan sudah memenuhi ruang di `.accessoryInline` — jadi ikon yang jadi
# kanal penanda".
#
# Tiga keluarga lain memakai ikon itu. `.accessoryInline` tidak: ia
# mengembalikan `Text(digest.headline)` saja. Akibatnya keluarga yang paling
# sempit — dan karena itu paling bergantung pada ikon — justru satu-satunya
# yang menampilkan nama kandidat `.uncertain` persis seperti nama yang sudah
# terkunci. Di pergelangan, tanpa membuka app, tidak ada cara membedakannya.
#
# Yang diperiksa: di dalam **satu cabang keluarga** complication, kalau
# `digest.headline` dirender, `presentedSymbolName` harus ikut dirender di
# cabang yang sama. Diperiksa per cabang, bukan per ekspresi: keluarga
# lingkaran dan persegi panjang merender ikon sebagai view **sebelah** teksnya,
# jadi menuntut ikon di `Text` yang sama akan melaporkan dua tempat yang
# sebenarnya benar. Dua nama itu teruji di Linux
# (`PointingPresentationTests`), jadi aturannya tidak bergantung pada daftar
# keluarga lokal yang bisa basi.
#
# **Batas cabangnya adalah `switch`-nya, bukan akhir berkas.** Dulu cabang
# terakhir dibatasi `len(code)`, sehingga ia memuat sisa berkas — termasuk
# `switch family` kedua di `fallback`, yang tidak memuat `digest.headline`
# sama sekali. Akibatnya sebuah pelanggaran di cabang `default` dilaporkan
# sebagai pelanggaran `case .accessoryRectangular`: cabang yang disalahkan
# bukan cabang yang salah. Itu kelas cacat yang paling merusak kepercayaan
# pada gerbang — ia berbunyi, tapi menunjuk ke tempat yang tidak bersalah —
# dan hanya ketahuan setelah harness menuntut **nama cabang yang dimutasi**
# (`Tools/bukti-mutasi-penanda-complication.py`, keadaan 2).
#
# Penanda berhentinya: kurung kurawal penutup pada indentasi **lebih rendah**
# daripada label cabangnya, atau akhir berkas bila tidak ketemu.
echo
echo "== Aturan 23: setiap cabang complication memakai kanal ikon =="
inline_claim=$(python3 - <<'PY' 2>&1
import os, re

BRANCH = re.compile(r"^(\s*)(case\s+\.accessory\w+|default)\s*:", re.M)

def branch_end(code, start, indent):
    """Berhenti di `}` yang menutup `switch`, bukan di akhir berkas."""
    close = re.compile(r"^" + indent + r"\}", re.M)
    m = close.search(code, start)
    return m.start() if m else len(code)

problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = open(path, encoding="utf-8").read()
        # Komentar dibuang: dokumentasi aturan ini menyebut kedua nama itu.
        code = "\n".join(l.split("//", 1)[0] for l in text.split("\n"))
        if "digest.headline" not in code:
            continue
        marks = list(BRANCH.finditer(code))
        for idx, m in enumerate(marks):
            end = branch_end(code, m.end(), m.group(1))
            nxt = marks[idx + 1].start() if idx + 1 < len(marks) else end + 1
            # Ambil yang lebih dulu: label cabang berikutnya, atau penutup
            # `switch`. Mana pun yang lebih dekat, cabangnya berhenti di situ.
            end = min(end, nxt if idx + 1 < len(marks) else end)
            branch = code[m.end():end]
            if "digest.headline" not in branch:
                continue
            if "presentedSymbolName" in branch:
                continue
            line_no = code[:m.start()].count("\n") + 1
            problems.append(
                f"  {path}:{line_no}: cabang `{m.group(2)}` menampilkan "
                f"`digest.headline` tanpa `presentedSymbolName` — "
                f"keraguan tidak terlihat")

if problems:
    print("\n".join(problems))
    print("-> Nama kandidat akan terbaca persis seperti nama yang terkunci. "
          "Render ikon keadaan di cabang keluarga yang sama.")
PY
)
if [ -n "$inline_claim" ]; then
  echo "$inline_claim"
  status=1
else
  echo "Bersih: nama objek di complication selalu tampil bersama ikon keadaan."
fi

# ── Aturan 24: indeks warna bintang tidak boleh dipakai mentah ──────────────
# Warna spektral adalah ciri pengenal, jadi satu-satunya jalan yang sah dari
# `colorIndexBV` ke gambar adalah lewat `drawableStarColorIndex(_:isConfirmed:)`
# — fungsi yang mengembalikan warna "tidak mengklaim" saat engine ragu.
#
# **Kenapa aturan ini perlu, padahal cacatnya sudah pernah diperbaiki dan
# diuji.** Uji Swift menguji **model**-nya (`drawableStarColorIndex`), bukan
# pemakaiannya di view. Gerbang gambar (`Tools/check-visuals.py`) menguji
# **port Python**-nya, bukan view Swift-nya. Keduanya bisa hijau sementara view
# Swift kembali memakai `visual.colorIndexBV` mentah: port tetap benar, model
# tetap benar, dan satu-satunya berkas yang salah justru yang tidak diperiksa
# siapa pun. Itu persis bentuk cacat yang baru saja diperbaiki, jadi ia layak
# dijaga di tempat yang melihat berkas Swift-nya.
echo
echo "== Aturan 24: indeks warna bintang hanya lewat drawableStarColorIndex =="
raw_star_colour=$(python3 - <<'PY' 2>&1
import os, re

problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = open(path, encoding="utf-8").read()
        code = "\n".join(l.split("//", 1)[0] for l in text.split("\n"))
        if "colorIndexBV" not in code:
            continue
        lines = code.split("\n")
        for i, line in enumerate(lines):
            if "colorIndexBV" not in line:
                continue
            # Pernyataan bisa membungkus baris, jadi gabungkan dengan baris
            # sebelumnya lalu cari **daftar argumen** pemanggilannya.
            combined = (lines[i - 1] + "\n" if i > 0 else "") + line
            call = re.search(
                r"drawableStarColorIndex\s*\(([^)]*)\)", combined, re.S)
            # Aman hanya kalau `colorIndexBV` benar-benar jadi argumen
            # `drawableStarColorIndex`, **dan** argumen penjaganya ikut
            # dikirim. Memakai nama fungsi yang benar tanpa `isConfirmed:`
            # tetap mengklaim warna saat ragu — bentuk cacat yang nyaris
            # lolos dari versi pertama aturan ini.
            if call and "colorIndexBV" in call.group(1) \
                    and "isConfirmed" in call.group(1):
                continue
            problems.append(
                f"  {path}:{i + 1}: `colorIndexBV` tidak lewat "
                f"`drawableStarColorIndex(_:isConfirmed:)` — warna diklaim "
                f"saat ragu")

if problems:
    print("\n".join(problems))
    print("-> Salurkan lewat `CelestialVisual.drawableStarColorIndex(_:isConfirmed:)` "
          "supaya warna netral saat engine ragu.")
PY
)
if [ -n "$raw_star_colour" ]; then
  echo "$raw_star_colour"
  status=1
else
  echo "Bersih: indeks warna bintang selalu lewat drawableStarColorIndex."
fi

# ── Aturan 25: `CelestialVisual.X` harus benar-benar anggota CelestialVisual ──
# Cacat yang melahirkan aturan ini sudah dua kali sampai ke `origin/main` dan
# baru ketahuan dari CI macOS, masing-masing satu siklus penuh (~2 menit) dan
# sebuah build merah:
#
#   CelestialVisualView.swift:784: error: type 'CelestialVisual' has no member 'VisualFrame'
#
# `VisualFrame` adalah tipe **top-level** (`public enum VisualFrame {`), bukan
# tipe bersarang di dalam `CelestialVisual` — jadi `CelestialVisual.VisualFrame`
# tidak ada. Dan tak satu pun gerbang Linux bisa melihatnya:
#
#   - `swift-test.sh` membangun **paket**, bukan `Apps/`;
#   - `swift-typecheck.sh` hanya **`-parse`** berkas `Apps/` (sintaks, bukan
#     tipe) — batas yang sudah ditulis jujur di berkasnya sendiri;
#   - CI macOS memang menangkapnya, tapi satu siklus penuh terlambat.
#
# Yang bisa dilihat di Linux adalah **keanggotaannya**: daftar anggota
# `CelestialVisual` bisa dibaca dari sumber paketnya, dan nama yang dipakai
# view bisa dibaca dari `Apps/`. Itulah yang diperiksa di sini.
#
# Batas yang jujur: aturan ini tahu anggota yang **langsung** dimiliki
# `CelestialVisual` (dibaca sampai kedalaman satu), bukan seluruh pohon
# tipe bersarangnya. Ia menangkap "anggota yang tidak ada sama sekali" —
# bentuk cacat yang benar-benar terjadi — dan sengaja tidak menebak lebih
# jauh: gerbang yang menebak akan memerah pada kode yang sah.
echo
echo "== Aturan 25: CelestialVisual.X harus anggota CelestialVisual =="
unknown_member=$(python3 - <<'PY' 2>&1
import os, re

SRC = "Packages/PointingKit/Sources/PointingKit"
TYPE = "CelestialVisual"

# Tipe yang dideklarasikan **top-level** di paket. Ini bukan pengecualian:
# justru inilah cacatnya. `VisualFrame` ada, tapi bukan anggota
# `CelestialVisual` — jadi `CelestialVisual.VisualFrame` tetap salah, dan
# pesannya menyebutkan bahwa ia harus dipakai tanpa kualifikasi.
top_level = set()
for root, _, files in os.walk(SRC):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        text = open(os.path.join(root, name), encoding="utf-8").read()
        top_level |= set(re.findall(
            r"^(?:public |internal |final |open )*"
            r"(?:struct|enum|class|protocol|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)",
            text, re.M))

def body_of_extension(text, start):
    """Isi `{ ... }` yang dimulai di `start`, dengan pencocokan kurung."""
    depth = 0
    for j in range(start, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[start:j]
    return ""

def direct_members(body):
    """Deklarasi pada kedalaman satu saja — anggota **langsung** tipe ini.

    **Cacat yang diperbaiki.** Versi lama memanggil `re.match` **di setiap**
    posisi `{` dan `}`. Kurung penutup sebuah literal (`static let accents =
    Accents( ... )` diikuti `}`) ikut memicu pencocokan ulang, dan
    `re.match` yang dijalankan di posisi itu memakan teks sesudahnya — jadi
    anggota yang **tepat setelah** initializer besar tidak pernah masuk
    inventaris. Akibatnya `NightVisual.candidateFill`, anggota sah pada
    kedalaman satu, dilaporkan "bukan anggota NightVisual": gerbang merah di
    kode benar. Diukur: menggeser satu fungsi ke bawah `static let accents`
    cukup untuk memicu ini.

    Sekarang posisi setiap karakter dibaca **satu pass**, dan `re.match`
    hanya dipanggil pada awal baris yang masih pada kedalaman satu — bukan
    pada kedua jenis kurung.
    """
    found, depth = set(), 0
    i, n = 0, len(body)
    while i < n:
        ch = body[i]
        if depth == 1 and (i == 0 or body[i - 1] == "\n"):
            m = re.match(
                r"[ \t]*(?:public |internal |private |fileprivate )?"
                r"(?:static |indirect )?"
                r"(?:func|var|let|struct|enum|class|typealias|case)\s+"
                r"([A-Za-z_][A-Za-z0-9_]*)", body[i:])
            if m:
                found.add(m.group(1))
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        i += 1
    return found

members = set()
for root, _, files in os.walk(SRC):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        text = open(os.path.join(root, name), encoding="utf-8").read()
        # Anggota yang dideklarasikan di dalam badan tipe itu sendiri.
        for m in re.finditer(rf"^(?:public |internal |final |open )*struct {TYPE}[^\n]*\{{",
                             text, re.M):
            members |= direct_members(body_of_extension(text, m.end() - 1))
        # Anggota yang ditambahkan lewat extension.
        for m in re.finditer(rf"^(?:public )?extension {TYPE}\s*\{{", text, re.M):
            members |= direct_members(body_of_extension(text, m.end() - 1))

problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        lines = open(path, encoding="utf-8").read().split("\n")
        for i, raw in enumerate(lines):
            line = raw.split("//", 1)[0]
            for used in re.findall(rf"\b{TYPE}\.([A-Za-z_][A-Za-z0-9_]*)", line):
                if used in members:
                    continue
                if used in top_level:
                    problems.append(
                        f"  {path}:{i + 1}: `{TYPE}.{used}` — `{used}` adalah tipe "
                        f"top-level di PointingKit, bukan anggota `{TYPE}`; "
                        f"pakai `{used}` tanpa kualifikasi")
                    continue
                problems.append(
                    f"  {path}:{i + 1}: `{TYPE}.{used}` — `{used}` bukan anggota "
                    f"`{TYPE}` dan tidak ada di PointingKit")

if problems:
    print("\n".join(problems))
    print(f"-> Buang kualifikasi `{TYPE}.` kalau `X`-nya tipe top-level, "
          "atau tambahkan anggotanya ke paket.")
PY
)
if [ -n "$unknown_member" ]; then
  echo "$unknown_member"
  status=1
else
  echo "Bersih: setiap CelestialVisual.X ada di paket."
fi

# ── Aturan 26: `TipePaket.anggota` harus benar-benar ada ───────────────────
# Aturan 25 lahir setelah `CelestialVisual.VisualFrame` dua kali lolos sampai
# `origin/main` dan baru ketahuan dari CI macOS. Yang ditutupnya hanya **satu
# nama tipe**. STATUS.md menulis batasnya sendiri dengan jujur:
#
#   "Memperluasnya ke seluruh tipe PointingKit adalah unit berikutnya yang
#    jelas — dan lebih besar, jadi sengaja tidak digabung ke siklus ini."
#
# Ini unit itu. Bedanya bukan sekadar 1 → 406 tipe, melainkan dua hal yang
# membuatnya tidak cukup disalin dari Aturan 25:
#
#  1. **Tipe bersarang.** `CelestialVisual.Planet` dua tingkat; indeks
#     anggota-langsung saja akan memerah pada kode yang sah. Pindai pohon
#     tipe memakai nama berkualifikasi, dan tipe bersarang dicatat sebagai
#     anggota induknya.
#  2. **Anggota yang diwariskan.** `CelestialVisual.Planet.allCases` tidak
#     dideklarasi di badan `Planet` — ia datang dari `CaseIterable`. Tanpa
#     resolusi basis, gerbang memerah pada baris yang benar-benar dikompilasi.
#     Itu bukan cacat: gerbang yang memerah pada kode benar akan dimatikan.
#
# Batas yang jujur, dan harus tertulis karena ia yang menentukan kapan
# aturan ini boleh dipercaya:
#
#  - Indeksnya **teks**, bukan compiler. Ia tahu "anggota dengan nama ini
#    tidak ada di tipe ini"; ia tidak tahu tipe argumen, kelebihan beban,
#    atau nama yang disediakan sintesis compiler.
#  - Hanya akses **berkualifikasi** (`Tipe.anggota`). Pemanggilan fungsi
#    bebas, anggota lewat `self`, dan ekstensi yang dideklarasi di `Apps/`
#    tidak terlihat — sama seperti Aturan 25.
#  - Tipe yang dideklarasi **di `Apps/`** dilewati: aturan ini menjaga
#    pemakaian API paket dari view, bukan kode antar-view.
echo
echo "== Aturan 26: TipePaket.anggota harus benar-benar ada di paket =="
unknown_any=$(python3 - <<'PY' 2>&1
import os, re, collections

PKG, APPS = "Packages", "Apps"


def strip(text):
    """Buang komentar tanpa menyentuh string literal.

    Interpolasi string (`\\(fractionDigits)`) **wajib** menyimpan kurung
    pembuka dan penutupnya. Tanpa itu hitungan brace setelah string pertama
    berhenti, dan badan tipe terpotong di situ: `NumberFormat.swift` memuat
    `String(format: "\\%.\\(fractionDigits)f", ...)`, jadi badan
    `NumberFormat` habis tepat di string itu — metode `degrees`,
    `signedDegrees`, `degreesPerSecond`, dan `percent` lenyap dari indeks,
    dan pemanggilannya lewat tanpa diperiksa sama sekali.

    Kegagalan ini tidak muncul sebagai "hijau": gerbang kehilangan isi
    berkas, bukan menolak isi yang salah. Itu lebih berbahaya daripada gerbang
    yang tidak ada, karena ia tetap melaporkan apa yang terdengar benar.
    Aturan 26 memakai pembaca yang sama; ia hanya kebetulan tidak terpengaruh
    karena yang diindeksnya anggota bertipe, bukan badan.
    """
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            out.append(c); i += 1
            while i < n:
                out.append(text[i])
                if text[i] == "\\":
                    if i + 1 < n:
                        out.append(text[i + 1])
                    i += 2; continue
                if text[i] == '"':
                    i += 1; break
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(c); i += 1
    return "".join(out)


DECL = re.compile(
    r"(?:public |internal |private |fileprivate |package |final |open )*"
    r"(?:indirect )?"
    r"(struct|enum|class|protocol|typealias|extension|actor)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)")

MEM = re.compile(
    r"(?:public |internal |private |fileprivate |package )?"
    r"(?:static |class |final |override |mutating |nonmutating |indirect )*"
    r"(?:func|var|let|struct|enum|class|typealias|case|init|actor)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)")

# Akses berkualifikasi. Awalan negatif menolak `foo.Bar` di dalam string.
PAIR = re.compile(r"(?<![A-Za-z0-9_.\"'])"
                  r"(?P<t>[A-Z][A-Za-z0-9_]*)"
                  r"\.(?P<m>[A-Za-z_][A-Za-z0-9_]*)")

# Akses berkualifikasi **bertingkat**: `Tipe.Luar.Dalam.anggota`.
#
# Kenapa `PAIR` saja tidak cukup, dan kegagalannya berbentuk hijau. `PAIR`
# memakai awalan negatif `(?<![A-Za-z0-9_.])`, jadi dari
# `CelestialVisual.Planet.saturn` ia hanya membaca `CelestialVisual.Planet` —
# anggota yang **paling spesifik** (`saturn`) tidak pernah diperiksa.
#
# Terukur 15 Okt 2026: mengganti `CelestialVisual.Planet.saturn` menjadi
# `.salahAnggota` membiarkan aturan ini melaporkan "Bersih", padahal itu
# galat kompilasi yang **pasti**. Yang hilang bukan satu nama, melainkan satu
# tingkat kedalaman — dan tingkat terdalam adalah yang paling sering disunting.
#
# `DEEP` menangkap awalan berkualifikasi berapa pun tingkatnya, lalu anggotanya
# diperiksa pada tipe **terdalam**, bukan pada akar. Kualifikasi yang tidak
# seluruhnya ada di indeks paket dilewati: itu bukan "anggota hilang", dan
# menebaknya akan memerahkan kode yang benar.
DEEP = re.compile(r"(?<![A-Za-z0-9_.\"'])"
                  r"(?:(?P<q>[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*)\.)?"
                  r"(?P<t>[A-Z][A-Za-z0-9_]*)"
                  r"\.(?P<m>[A-Za-z_][A-Za-z0-9_]*)")


def index(root_dir):
    """Pindai pohon tipe: nama berkualifikasi -> anggota langsung + basis."""
    types = collections.defaultdict(set)
    bases = collections.defaultdict(set)
    for root, _, files in os.walk(root_dir):
        for name in sorted(files):
            if not name.endswith(".swift"):
                continue
            text = strip(open(os.path.join(root, name), encoding="utf-8").read())
            events = []
            for m in DECL.finditer(text):
                events.append((m.start(), "decl", m))
            for m in MEM.finditer(text):
                events.append((m.start(), "mem", m))
            for m in re.finditer(r"[{}]", text):
                events.append((m.start(), "brace", m.group(0)))
            events.sort(key=lambda e: (e[0], 0 if e[1] == "decl" else 1))

            depth, stack = 0, []
            for _pos, kind, payload in events:
                if kind == "brace":
                    if payload == "{":
                        depth += 1
                    else:
                        depth -= 1
                        while stack and depth < stack[-1][1]:
                            stack.pop()
                    continue
                if kind == "decl":
                    k, tname = payload.group(1), payload.group(2)
                    j = payload.end()
                    while j < len(text) and text[j] not in "{;=\n":
                        j += 1
                    rest = text[payload.end():j]
                    prefix = stack[-1][0] if stack else ""
                    qual = f"{prefix}.{tname}" if prefix else tname
                    if j < len(text) and text[j] == "{":
                        types[qual] |= set()
                        # Tipe bersarang adalah anggota induknya.
                        if prefix:
                            types[prefix].add(tname)
                        if k == "typealias":
                            bases[qual] |= set(re.findall(
                                r"[A-Za-z_][A-Za-z0-9_]*", rest.split("=")[0]))
                        else:
                            for b in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", rest):
                                if b not in ("where", "Self"):
                                    bases[qual].add(b)
                        stack.append((qual, depth + 1))
                    continue
                if stack and depth == stack[-1][1]:
                    types[stack[-1][0]].add(payload.group(1))
    return types, bases


pkg_types, bases = index(PKG)
apps_types = set(index(APPS)[0])

# Anggota yang diwariskan/dikonformasi (`CaseIterable.allCases`, dll).
resolved = {}
for t in pkg_types:
    seen, stack, acc = {t}, [t], set(pkg_types[t])
    while stack:
        cur = stack.pop()
        for b in bases.get(cur, ()):
            if b in seen or b not in pkg_types:
                continue
            seen.add(b); stack.append(b); acc |= pkg_types[b]
    resolved[t] = acc

problems = []
for root, _, files in os.walk(APPS):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        for i, raw in enumerate(open(path, encoding="utf-8").read().split("\n")):
            line = strip(raw)
            for m in DEEP.finditer(line):
                t, mem = m.group("t"), m.group("m")
                prefix = m.group("q")
                qual = f"{prefix}.{t}" if prefix else t
                # `root` sengaja **bukan** nama ini: `for root, _, files in
                # os.walk(APPS)` memakai nama itu, dan menugaskannya di sini
                # akan menimpa variabel perulangannya — baris berikutnya lalu
                # membuka `<tipe>/<Berkas>.swift` dan aturan ini mati dengan
                # `FileNotFoundError`, bukan dengan temuan.
                akar = prefix.split(".")[0] if prefix else t
                # Tipe yang dideklarasi di `Apps/` dilewati: aturan ini menjaga
                # pemakaian API **paket** dari view (lihat docstring Aturan 26).
                if akar not in pkg_types or akar in apps_types:
                    continue
                # Hanya periksa kualifikasi yang **seluruhnya** ada di indeks
                # paket. Kalau `Outer.Inner` tidak dikenali, itu bukan
                # "anggota hilang" — menebaknya akan memerahkan kode benar,
                # dan gerbang yang memerah pada kode benar akan dimatikan orang.
                if qual not in resolved:
                    continue
                # `Type.self` / `Type.Type` disediakan compiler.
                if mem in ("self", "Type") or mem in resolved[qual]:
                    continue
                # Anggota yang **disintesis compiler** tidak pernah tertulis di
                # sumber, jadi teks indeks tidak memuatnya. `CaseIterable`
                # menyediakan `allCases`; tanpa ini, `CelestialVisual.Planet
                # .allCases` — baris yang dikompilasi hari ini di
                # `PointingEngine.swift:251` — dilaporkan sebagai anggota yang
                # hilang. Gerbang yang memerah pada kode benar akan dimatikan
                # orang, jadi ini bukan pelonggaran: yang ditambahkan hanya
                # nama yang keberadaannya dijamin konformansinya, dan hanya
                # bila konformansi itu **tertulis** di deklarasi tipenya.
                if mem == "allCases" and "CaseIterable" in bases.get(qual, ()):
                    continue
                nested = f"{qual}.{mem}"
                hint = ""
                if nested in pkg_types:
                    hint = (f" — `{nested}` ada sebagai tipe bersarang; "
                            f"akses anggotanya lewat `{mem}.<anggota>`")
                problems.append(
                    f"  {path}:{i + 1}: `{qual}.{mem}` — bukan anggota `{qual}`"
                    f"{hint}")

if problems:
    print("\n".join(problems))
    print("-> Anggota yang hilang hanya ketahuan dari CI macOS hari ini; "
          "tambahkan ke paket, atau perbaiki pemanggilnya.")
PY
)
if [ -n "$unknown_any" ]; then
  echo "$unknown_any"
  status=1
else
  echo "Bersih: setiap TipePaket.anggota di Apps/ ada di paket."
fi

# ── Aturan 27: label argumen inisialisasi paket harus benar ─────────────────
# Aturan 26 menjaga **keanggotaan**: `Tipe.anggota` benar-benar ada di paket.
# Yang dijaganya nama anggota — dan inisialisasi tidak punya nama anggota sama
# sekali. `CelestialVisual.RGBComponents(red:green:blue:)` adalah pemanggilan
# yang benar apartemen: receiver-nya adalah *tipe*, dan tidak ada
# `Tipe.anggota` yang bisa dibaca darinya.
#
# Kenapa ini harus gerbang Linux, bukan CI macOS saja:
#
#   `swift-test.sh`       membangun paket, bukan `Apps/` — pemanggilan ini
#                         tidak pernah dilihatnya sama sekali.
#   `swift-typecheck.sh`  mengompilasi **dua** berkas Foundation; berkas
#                         SwiftUI (Canvas/WidgetKit) mustahil di Linux.
#   Aturan 26             melihat `Tipe.anggota`, jadi `Tipe(Label:)` tak
#                         pernah diindeks.
#
# Bentuk cacatnya persis bentuk yang sudah muncul berulang di berkas ini: kode
# yang **benar** dipanggil dengan nama yang hampir benar, dan yang salah hanya
# karena satu huruf. `ObserverLocation(latDeg:…)` adalah merah di CI macOS satu
# siklus penuh (~2 menit) terlambat, seperti `VisualFrame` yang lolos dua kali.
#
# Yang bisa dan tidak bisa dijamin — batasnya ditulis karena inilah yang
# menentukan kapan aturan ini boleh dipercaya:
#
#  - Label **eksternal** yang dibandingkan. Swift punya dua nama untuk satu
#    argumen: `func text(for state: …)` dipanggil `text(for: …)`, sedangkan
#    `func text(state: …)` dipanggil `text(state: …)`. Membaca label yang
#    salah membuat gerbang merah pada kode yang benar.
#  - Inisialisasi **bawaan** Swift (yang mengisi semua stored property)
#    menerima apa pun dalam urutan apa pun, jadi tidak dihitung. Kalau sebuah
#    tipe hanya punya inisialisasi bawaan, panggilannya dilewati.
#  - Panggilan **posisional** dilewati: tanpa label tidak ada yang bisa
#    dijamin tanpa menebak urutan, dan menebak urutan akan membuat gerbang
#    merah pada kode yang benar.
#  - Yang diperiksa: label yang ditulis harus sama dengan label deklarasi, dan
#    argumen wajib tidak boleh hilang. Tipe argumen, kelebihan beban, dan
#    `init?` tetap hanya ketahuan dari CI macOS.
echo
echo "== Aturan 27: label argumen TipePaket(Label:) di Apps/ harus benar =="
wrong_labels=$(python3 - <<'PY' 2>&1
import os, re, collections

PKG, APPS = "Packages", "Apps"


def strip(text):
    """Buang komentar tanpa menyentuh string literal.

    Interpolasi string (`\\(fractionDigits)`) **wajib** menyimpan kurung
    pembuka dan penutupnya. Tanpa itu hitungan brace setelah string pertama
    berhenti, dan badan tipe terpotong di situ: `NumberFormat.swift` memuat
    `String(format: "\\%.\\(fractionDigits)f", ...)`, jadi badan
    `NumberFormat` habis tepat di string itu — metode `degrees`,
    `signedDegrees`, `degreesPerSecond`, dan `percent` lenyap dari indeks,
    dan pemanggilannya lewat tanpa diperiksa sama sekali.

    Kegagalan ini tidak bisa dilihat sebagai "hijau": gerbang kehilangan isi
    berkas, bukan menolak isi yang salah. Itu lebih berbahaya daripada gerbang
    yang tidak ada, karena ia tetap melaporkan apa yang terdengar benar.
    """
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            out.append(c); i += 1
            while i < n:
                out.append(text[i])
                if text[i] == "\\":
                    if i + 1 < n:
                        out.append(text[i + 1])
                    i += 2; continue
                if text[i] == '"':
                    i += 1; break
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2; continue
        out.append(c); i += 1
    return "".join(out)


def balanced(text, i):
    """text[i] adalah '(' atau '[' atau '{'; kembalikan isinya."""
    depth = 0
    j = i
    while j < len(text):
        c = text[j]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
        j += 1
    return text[i + 1:]


def split_top(inside):
    parts, depth, cur = [], 0, ""
    for c in inside:
        if c in "([{<":
            depth += 1
        elif c in ")]}>":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur); cur = ""
        else:
            cur += c
    if cur.strip():
        parts.append(cur)
    return [p.strip() for p in parts if p.strip()]


def has_default(param):
    """True kalau `label: T = nilai` — bukan `==`, `<=`, `!=`, `>=`, `=~`."""
    depth, i, n = 0, 0, len(param)
    while i < n:
        c = param[i]
        if c in "([{<":
            depth += 1
        elif c in ")]}>":
            depth -= 1
        elif c == "=" and depth == 0:
            prev = param[i - 1] if i else ""
            nxt = param[i + 1] if i + 1 < n else ""
            if not (nxt == "=" or prev in ("!", "<", ">", "=") or nxt == "~"):
                return True
        i += 1
    return False


LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:(?!:)")


def call_params(inside):
    """[(label, ada nilai)] untuk sisi PEMANGGILAN."""
    out = []
    for p in split_top(inside):
        m = LABEL.match(p)
        out.append((m.group(1) if m else None, has_default(p)))
    return out


def decl_params(inside):
    """[(label EKSTERNAL, ada nilai)] untuk sisi DEKLARASI.

    Swift mengizinkan dua nama untuk satu argumen: `func text(for state:)`
    dipanggil `text(for:)`, sedangkan `func text(state:)` dipanggil
    `text(state:)`. Yang diperiksa adalah nama yang dipakai pemanggil.
    """
    out = []
    for p in split_top(inside):
        head = p.split(":", 1)[0].strip()
        tokens = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", head)
        out.append((tokens[0] if tokens else None, has_default(p)))
    return out


DECL = re.compile(r"\b(?:struct|enum|class|actor)\s+([A-Za-z_][A-Za-z0-9_]*)")
# `extension CelestialVisual.Planet { … }` — nama berkualifikasi, tanpa protokol.
EXT = re.compile(r"\bextension\s+([A-Za-z_][A-Za-z0-9_.]*)")
# `(?<![.\w])` menolak **inisialisasi anggota** `.init(red:…)` / `self.init(…)`.
# Bentuk itu adalah pemanggilan, bukan deklarasi: ia hidup di dalam badan tipe
# dan tidak menambah satu pun label yang sah. Tanpa penolakan ini, setiap
# `.init(light: .init(red:…))` di dalam `extension CelestialVisual.Planet`
# tercatat sebagai deklarasi milik `CelestialVisual.Planet`, sehingga tabelnya
# berisi tanda tangan palsu `(light:, dark:, feature:)` dan pesan galatnya
# menuduh label yang tidak pernah ditulis pemanggil — gerbang yang benar tapi
# menyesatkan tetap gerbang yang dimatikan orang.
INIT = re.compile(
    r"(?<![.\w])(?:convenience |required |override )*init\s*(\?|\!)?\s*\(")

inits = collections.defaultdict(list)
# ── Tipe BERSARANG: `CelestialVisual.RGBComponents(…)` ─────────────────────
#
# Kenapa indeks kedua ini ada.
#
# `DECL` di atas mencari nama tipe **sederhana** (`struct RGBComponents`), jadi
# kuncinya `RGBComponents` — dan pemanggilan yang dicocokkannya karena itu
# hanya yang **tidak berkualifikasi**. Bentuk yang repo ini benar-benar tulis
# adalah bentuk berkualifikasi, karena `CelestialVisual` adalah tipe bersarang
# di paket:
#
#     Apps/Shared/CelestialVisualView.swift:1238
#         CelestialVisual.RGBComponents(red: 1, green: 1, blue: 1)
#     Apps/Shared/PointingEngine.swift:585
#         CelestialVisual.Planet(objectID: object.id)
#
# Terukur (probe, 14 Okt 2026): mengganti `objectID:` menjadi `objectId:` di
# baris 585, dan **membuang `blue:`** di baris 1238, membiarkan seluruh 35
# aturan `swift-ui-lint.sh` hijau (exit 0). Keduanya hanya ketahuan dari CI
# macOS — dan `objectId:` bukan galat yang *mungkin* lolos, ia galat kompilasi
# yang **pasti**, persis yang aturan ini ada untuk menangkapnya satu siklus
# (~2 menit CI, ditambah satu push) lebih awal.
#
# Kenapa ini **tambahan**, bukan penggantian.
#
# Membuat `DECL` sadar-kurung dan menyimpan nama berkualifikasi saja akan
# **menghapus** kunci `Planet`, `Blob`, `Core`, `Decision`, dan `RecordRefusal`
# dari himpunan: kelimanya dideklarasikan di dalam tipe lain, dan pemanggilan
# tak-berkualifikasinya sekarang dijaga lewat kunci sederhana itu. Gerbang yang
# menyempit tanpa suara adalah gerbang yang selalu hijau, jadi kunci
# berkualifikasi ditambahkan **di samping** kunci sederhana, bukan menggantinya.
#
# Batas yang dinyatakan: `extension` **diikuti**, tetapi hanya namanya —
# `extension CelestialVisual.Planet { … }` menumpuk `CelestialVisual.Planet`,
# sehingga `init?(objectID:)` yang hidup di dalamnya teratribusi ke tipe yang
# benar. Tanpa itu, `inits["Planet"]` hanya memuat `init(kind:…)` dan
# `Planet(objectID:)` yang **sah** dilaporkan sebagai label yang salah — gerbang
# merah pada kode benar, yang membuatnya dimatikan orang. `extension Foo: Bar`
# aman: yang ditangkap namanya, bukan protokolnya.
for root, _, files in os.walk(PKG):
    if ".build" in root:
        continue
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = strip(open(path, encoding="utf-8").read())
        decls = [(m.start(), m.group(1)) for m in DECL.finditer(text)]
        for m in INIT.finditer(text):
            owner = None
            for pos, t in decls:
                if pos < m.start():
                    owner = t
                else:
                    break
            if owner:
                inits[owner].append(
                    (decl_params(balanced(text, m.end() - 1)), path))

        # Nama berkualifikasi untuk `init` yang sama: tumpukan tipe sadar-kurung.
        events = [(m.start(), "decl", m.group(1)) for m in DECL.finditer(text)]
        events += [(m.start(), "ext", m.group(1)) for m in EXT.finditer(text)]
        events += [(m.start(), "brace", m.group(0))
                   for m in re.finditer(r"[{}]", text)]
        events += [(m.start(), "init", m) for m in INIT.finditer(text)]
        events.sort(key=lambda e: (e[0], 0 if e[1] in ("decl", "ext") else 1))
        depth, stack = 0, []
        for pos, kind, payload in events:
            if kind == "brace":
                if payload == "{":
                    depth += 1
                else:
                    depth -= 1
                    while stack and depth < stack[-1][1]:
                        stack.pop()
                continue
            if kind in ("decl", "ext"):
                if kind == "ext":
                    # Sudah berkualifikasi sendiri (`CelestialVisual.Planet`).
                    qual = payload if "." in payload else (
                        f"{stack[-1][0]}.{payload}" if stack else payload)
                else:
                    prefix = stack[-1][0] if stack else ""
                    qual = f"{prefix}.{payload}" if prefix else payload
                j = pos + len(payload)
                while j < len(text) and text[j] not in "{;=\n":
                    j += 1
                if j < len(text) and text[j] == "{":
                    stack.append((qual, depth + 1))
                continue
            if stack and "." in stack[-1][0]:
                inits[stack[-1][0]].append(
                    (decl_params(balanced(text, payload.end() - 1)), path))


def matches(given, decl):
    if len(given) > len(decl):
        return False
    for (gl, _gd), (dl, ddef) in zip(given, decl):
        if not ddef and gl != dl:
            return False
    return all(ddef for _l, ddef in decl[len(given):])


CALL = re.compile(r"(?<![A-Za-z0-9_.])([A-Z][A-Za-z0-9_]*)\s*\(")
# Pemanggilan **berkualifikasi**: `CelestialVisual.RGBComponents(…)`.
# Awalan negatif hanya menolak `a.b.Call(` bertingkat-tiga; satu titik adalah
# bentuk yang dipakai repo ini, dan yang `CALL` di atas tidak pernah lihat.
QUALIFIED_CALL = re.compile(
    r"(?<![A-Za-z0-9_.])([A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)+)\s*\(")


def resolve_qualified(full, table):
    """Cari `full` di `table` lewat sufiks terpanjang yang cocok.

    `CelestialVisual.RGBComponents` dicoba apa adanya lebih dulu; kalau tidak
    ada, `RGBComponents` dicoba. Urutan itu penting: mencoba sufiks terpendek
    lebih dulu akan mencocokkan tipe bersarang yang **berbeda** dengan nama
    yang kebetulan sama.
    """
    parts = full.split(".")
    for k in range(len(parts)):
        cand = ".".join(parts[k:])
        if cand in table:
            return cand
    return None


problems = []
for root, _, files in os.walk(APPS):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = strip(open(path, encoding="utf-8").read())
        calls = [(m, m.group(1)) for m in CALL.finditer(text)]
        calls += [(m, resolve_qualified(m.group(1), inits))
                  for m in QUALIFIED_CALL.finditer(text)]
        for m, t in calls:
            if t is None or t not in inits:
                continue
            given = call_params(balanced(text, m.end() - 1))
            # Tanpa label tidak ada yang bisa dijamin tanpa menebak urutan —
            # TAPI nol argumen tetap harus merah kalau deklarasinya mewajibkan
            # argumen. Inisialisasi tanpa `Tipe()` padahal deklarasinya
            # `init(latitudeDeg:longitudeDeg:)` adalah pemanggilan yang lebih
            # salah, bukan lebih sedikit pemeriksaannya.
            if not given:
                required = [(d, p) for d, p in inits[t]
                            if any(not x for _l, x in d)]
                if required:
                    decl, dpath = required[0]
                    problems.append(
                        f"  {path}: {t}() tanpa argumen\n"
                        f"      deklarasi di {dpath} mewajibkan: "
                        + ", ".join(l + ":" for l, x in decl if not x))
                continue
            # Positional: urutan argumen tidak bisa dipastikan tanpa compiler.
            if any(l is None for l, _ in given):
                continue
            if not any(matches(given, decl) for decl, _ in inits[t]):
                problems.append(
                    f"  {path}: {t}("
                    + ", ".join(f"{l}:" for l, _ in given) + ")\n"
                    f"      deklarasi di {inits[t][0][1]} punya: "
                    + ", ".join(l + (" (bawaan)" if d else "")
                                for l, d in inits[t][0][0]))

if problems:
    print("GAGAL: " + f"{len(problems)} pemanggilan inisialisasi paket "
          "yang tidak cocok dengan deklarasinya.")
    print("\n".join(problems))
    print("-> Label yang salah hanya ketahuan dari CI macOS hari ini. "
          "Perbaiki pemanggilnya, atau kembalikan label di paket.")
PY
)
if [ -n "$wrong_labels" ]; then
  case "$wrong_labels" in
    GAGAL:*) status=1 ;;
  esac
  echo "$wrong_labels"
else
  echo "Bersih: setiap TipePaket(Label:) di Apps/ cocok dengan deklarasinya."
fi

# ── Aturan 28: label argumen TipePaket.metode(label:) di Apps/ harus benar ─
# ── Alasan: Aturan 26 membuktikan `TipePaket.metode` ADA. Aturan 27
# ── membuktikan label pada `TipePaket(Label:)`. Yang tersisa adalah jalur
# ── paling jenuh di repo ini: metode statis paket yang dipanggil
# ── berkualifikasi (`StateAnnouncement.text(for: state)`), di mana label
# ── argumen adalah contracts pemanggil dan derajat kompilasi, bukan sekadar
# ── nama. Sekitar 44 pemanggilan seperti itu di Apps/ kehilangan seluruh
# ── pemeriksaannya kalau hanya dua aturan sebelumnya yang bekerja.
# ── Batasnya disengaja: pemanggilan tanpa label ATAU posisional dilewati
# ── karena urutan argumen tidak bisa dipastikan tanpa compiler, dan
# ── menebaknya lebih berbahaya daripada tidak memeriksa.
# ──
# ── DUA batas yang dinyatakan, dan keduanya diukur oleh
# ── `Tools/bukti-mutasi-label-bawaan.py`:
# ──
# ──  1. Argumen berlabel boleh diberikan dalam **urutan apa pun** (aturan
# ──     Swift), jadi pencocokannya per **nama**, bukan per posisi. Tanpa itu
# ──     `makeController(location:config:)` — sah, ada di
# ──     `PointingEngine.swift:92` — memerah karena `config` berhadapan dengan
# ──     `calibration`.
# ──  2. Parameter bernilai bawaan boleh **dibuang**, tetapi kalau labelnya
# ──     ditulis, labelnya tetap dibandingkan. Versi lama membebaskan
# ──     perbandingan itu (`if not ddef and gl != dl`), sehingga 4 argumen
# ──     berlabel di `Apps/` lolos dengan label yang salah.
echo "== Aturan 28: label argumen TipePaket.metode(Label:) di Apps/ harus benar =="
wrong_method_labels=$(python3 - <<'PY' 2>&1
import os, re, collections

PKG, APPS = "Packages", "Apps"

TYPE = re.compile(r"\b(?:struct|enum|class|actor|extension|protocol)\s+"
                  r"([A-Za-z_][A-Za-z0-9_]*)")
METHOD = re.compile(r"\b(?:public |internal |private |fileprivate |package |"
                    r"static |class |final |override |mutating |nonmutating |"
                    r"required |convenience |discardableResult )*"
                    r"func\s+([A-Za-z_][A-Za-z0-9_]*)")


def strip(text):
    """Buang komentar tanpa menyentuh string literal.

    Interpolasi string (`\\(fractionDigits)`) **wajib** menyimpan kurung
    pembuka dan penutupnya. Tanpa itu hitungan brace setelah string pertama
    berhenti, dan badan tipe terpotong di situ: `NumberFormat.swift` memuat
    `String(format: "\\%.\\(fractionDigits)f", ...)`, jadi badan
    `NumberFormat` habis tepat di string itu — metode `degrees`,
    `signedDegrees`, `degreesPerSecond`, dan `percent` lenyap dari indeks.

    Kegagalan ini tidak muncul sebagai "hijau": gerbang kehilangan isi
    berkas, bukan menolak isi yang salah. Itu lebih berbahaya daripada gerbang
    yang tidak ada, karena ia tetap melaporkan apa yang terdengar benar.
    """
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            out.append(c); i += 1
            while i < n:
                out.append(text[i])
                if text[i] == "\\":
                    if i + 1 < n:
                        out.append(text[i + 1])
                    i += 2; continue
                if text[i] == '"':
                    i += 1; break
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2; continue
        out.append(c); i += 1
    return "".join(out)


def balanced(text, i):
    """text[i] adalah '(' atau '[' atau '{'; kembalikan isinya."""
    depth, j = 0, i
    while j < len(text):
        c = text[j]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
        j += 1
    return text[i + 1:]


def split_top(inside):
    parts, depth, cur = [], 0, ""
    for c in inside:
        if c in "([{<":
            depth += 1
        elif c in ")]}>":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur); cur = ""
        else:
            cur += c
    if cur.strip():
        parts.append(cur)
    return [p.strip() for p in parts if p.strip()]


def has_default(param):
    """True kalau `label: T = nilai` — bukan `==`, `<=`, `!=`, `>=`, `=~`."""
    depth, i, n = 0, 0, len(param)
    while i < n:
        c = param[i]
        if c in "([{<":
            depth += 1
        elif c in ")]}>":
            depth -= 1
        elif c == "=" and depth == 0:
            prev = param[i - 1] if i else ""
            nxt = param[i + 1] if i + 1 < n else ""
            if not (nxt == "=" or prev in ("!", "<", ">", "=") or nxt == "~"):
                return True
        i += 1
    return False


LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:(?!:)")


def call_params(inside):
    out = []
    for p in split_top(inside):
        m = LABEL.match(p)
        out.append((m.group(1) if m else None, has_default(p)))
    return out


def decl_params(inside):
    """[(label EKSTERNAL, ada nilai)] untuk sisi DEKLARASI."""
    out = []
    for p in split_top(inside):
        head = p.split(":", 1)[0].strip()
        tokens = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", head)
        out.append((tokens[0] if tokens else None, has_default(p)))
    return out


def matches(given, decl):
    # Label pemanggil dibandingkan **selalu**, termasuk pada parameter yang
    # punya nilai bawaan.
    #
    # Bentuk lamanya (`if not ddef and gl != dl`) membiarkan label yang salah
    # lolos persis di parameter yang **paling sering** disunting:
    # `deepSky(morphology:fuzziness:elongation:frameHalfExtent:)` — tiga dari
    # empat parameternya punya nilai bawaan, jadi
    # `CelestialVisual.deepSky(morphology:, fuzziness:, salah:)` tetap hijau
    # walau `salah:` bukan parameter yang ada. Terukur (probe, 15 Okt 2026):
    # 4 argumen berlabel di `Apps/` hari ini lolos dengan label salah, dan
    # 94 dari 1489 statika terindeks punya celah yang sama.
    #
    # Yang membuatnya bukan sekadar menghapus `not ddef`: Swift mengizinkan
    # argumen berlabel diberikan dalam **urutan apa pun**, jadi mencocokkan
    # per posisi akan memerahkan
    # `makeController(location: config:)` — pemanggilan yang sah dan ada di
    # `PointingEngine.swift:92` — karena `config` di posisi 1 berhadapan
    # dengan `calibration` di deklarasi. Terukur: mencocokkan per posisi
    # memerahkan kode benar itu; mencocokkan **per nama** tidak.
    #
    # Jadi: tiap label yang diberikan harus ada di deklarasi (bebas urutan),
    # dan parameter yang tidak diberikan harus punya nilai bawaan.
    if len(given) > len(decl):
        return False
    labels = [l for l, _ in given]
    if any(l is None for l in labels):
        return False  # posisional: urutan tak bisa dipastikan tanpa compiler
    decl_labels = [l for l, _ in decl]
    if len(set(labels)) != len(labels):
        return False  # label diulang
    for l in labels:
        if l not in decl_labels:
            return False
    given_set = set(labels)
    return all(ddef for l, ddef in decl if l not in given_set)


# Indeks metode per tipe. Badan dibaca per deklarasi tipe, jadi nama metode
# yang sama pada tipe berbeda tidak tertukar.
methods = collections.defaultdict(list)
for root, _, files in os.walk(PKG):
    if ".build" in root:
        continue
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = strip(open(path, encoding="utf-8").read())
        for tm in TYPE.finditer(text):
            open_brace = text.find("{", tm.end())
            if open_brace < 0:
                continue
            nxt = TYPE.search(text, tm.end())
            if nxt is not None and nxt.start() < open_brace:
                continue  # deklarasi tanpa badan
            body = balanced(text, open_brace)
            for mm in METHOD.finditer(body):
                k = mm.end()
                while k < len(body) and body[k] in " \t\n":
                    k += 1
                if k < len(body) and body[k] == "(":
                    methods[tm.group(1)].append(
                        (mm.group(1), decl_params(balanced(body, k)), path))

QF = re.compile(r"(?<![A-Za-z0-9_.])([A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")
stats = collections.Counter()
problems = []
for root, _, files in os.walk(APPS):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = strip(open(path, encoding="utf-8").read())
        for m in QF.finditer(text):
            t, fn = m.group(1), m.group(2)
            overloads = [(d, p) for f, d, p in methods.get(t, []) if f == fn]
            if not overloads:
                continue  # bukan metode paket: properti, enum case, alias tipe
            given = call_params(balanced(text, m.end() - 1))
            if not given:
                # Nol argumen BUKAN hal yang aman untuk dilewati: pemanggilan
                # tanpa argumen ke metode yang mewajibkan argumen adalah
                # pemanggilan yang lebih salah, bukan lebih sedikit
                # pemeriksaannya. Megetil `text()` padahal deklarasinya
                # `text(for snapshot:)` harus merah di sini.
                required = [(d, p) for d, p in overloads
                            if any(not x for _l, x in d)]
                if required:
                    stats["nol argumen tapi wajib punya argumen"] += 1
                    decl, dpath = required[0]
                    problems.append(
                        f"  {path}: {t}.{fn}() tanpa argumen\n"
                        f"      deklarasi di {dpath} mewajibkan: "
                        + ", ".join(l + ":" for l, x in decl if not x))
                else:
                    stats["tanpa argumen"] += 1
                continue
            if any(l is None for l, _ in given):
                stats["posisional (dilewati)"] += 1
                continue
            stats["berlabel diperiksa"] += 1
            if not any(matches(given, d) for d, _p in overloads):
                stats["MISMATCH"] += 1
                decl, dpath = overloads[0]
                problems.append(
                    f"  {path}: {t}.{fn}("
                    + ", ".join(f"{l}:" for l, _ in given) + ")\n"
                    f"      deklarasi di {dpath} punya: "
                    + ", ".join(l + (" (bawaan)" if x else "") for l, x in decl))

if problems:
    print("GAGAL: " + f"{stats['MISMATCH'] + stats['nol argumen tapi wajib punya argumen']} "
          "pemanggilan metode paket yang tidak cocok dengan deklarasinya.")
    print("\n".join(problems))
    print("-> Label yang salah hanya ketahuan dari CI macOS hari ini. "
          "Perbaiki pemanggilnya, atau kembalikan label di paket.")
elif stats["berlabel diperiksa"]:
    print(f"Bersih: {stats['berlabel diperiksa']} pemanggilan "
          f"TipePaket.metode(Label:) di Apps/ cocok dengan deklarasinya "
          f"({stats['posisional (dilewati)']} positional dilewati).")
else:
    print("Bersih: tidak ada pemanggilan metode paket berlabel di Apps/.")
PY
)
if [ -n "$wrong_method_labels" ]; then
  case "$wrong_method_labels" in
    GAGAL:*) status=1 ;;
  esac
  echo "$wrong_method_labels"
fi

# ── Aturan 29: terjemahan yang tidak akan pernah sampai ke layar ───────────
# Aturan 4 menyapu literal di dalam argumen peritel teks (`Text`, `Label`,
# `row`, `detailRow`, `legend`, …) dan menuntut setiap literal itu **ada** di
# katalog. Ia hijau, dan ia benar.
#
# Yang tidak dilihat siapa pun: `Text` punya **dua** inisialisator yang
# berperilaku berlawanan, dan yang mana yang terpakai ditentukan oleh **tipe
# parameter** tempat literal itu berdiri — bukan oleh isinya.
#
#   Text("Terkunci")        // LocalizedStringKey -> dicari di katalog
#   Text(someString)        // StringProtocol      -> DICETAK APA ADANYA
#
# Apple mendokumentasikan yang kedua sebagai *"without localization"*.
# Jadi `row("Keadaan", …)` — di mana `row(_ title: String, _ value: String)`
# — menerima kunci katalog di dalam parameter bertipe `String`, dan kata
# **"Keadaan"** yang tercetak ke layar, bukan terjemahannya.
#
# Kenapa kelas ini tidak pernah terlihat. Tiga gerbang menyentuh permukaan ini
# dan ketiganya hijau:
#
#   Aturan 4   literal itu memang **ada** di katalog -> hijau
#   Aturan 6   paritas kunci paket <-> katalog -> tidak melihat `Apps/`
#   Aturan 19  "kunci yatim" mencari teks kunci di **seluruh** sumber sebagai
#              substring mentah, jadi kemunculannya di dalam argumen `row("…")`
#              **menghitung sebagai rujukan** -> hijau
#
# Aturan 19 yang paling menentukan, karena ia satu-satunya gerbang yang
# niatnya memang "kunci ini dipakai atau tidak". Ia menjawab ya — dan
# jawabannya salah: kunci itu dipakai sebagai **teks Indonesia**, bukan
# sebagai kunci.
#
# Akibatnya 18 terjemahan Bahasa Inggris yang sudah ditulis (`Keadaan` →
# "State", `Laju pergelangan` → "Wrist rate", `Id katalog` → "Catalogue ID",
# …) tidak akan pernah muncul di perangkat mana pun, di bahasa mana pun,
# tanpa satu pun peringatan build. Persis "hijau yang tidak hijau" yang
# menjadi alasan berkas ini ada.
#
# Pemeriksaannya sengaja **diturunkan dari kode**, bukan dari daftar nama
# helper yang ditulis tangan: helper mana pun yang parameternya `: String`
# ikut diperiksa, jadi helper baru yang ditambahkan besok langsung dijangkau.
echo
echo "== Aturan 29: literal katalog yang berdiri di parameter bertipe String =="
nonlocalized=$(python3 - <<'PY'
import json, os, re, sys

CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"
if not os.path.exists(CATALOG):
    print("BELUM-ADA-KATALOG")
    raise SystemExit(0)

keys = set(json.load(open(CATALOG, encoding="utf-8"))["strings"])

# Kunci yang isinya **hanya tanda baca/simbol** tidak diperiksa.
#
# Alasannya diukur, bukan ditebak: katalog memuat `"—"` ("Penanda nilai kosong
# pada baris tabel"), dan terjemahan `en`-nya juga `"—"`. Sebagai argumen
# `row(_:_:)` ia memang berdiri di parameter `String`, tapi ia **placeholder**,
# bukan label — dan karena kedua bahasanya identik, tidak ada terjemahan yang
# hilang karenanya.
#
# Tanpa pengecualian ini gerbang melaporkan enam situs yang tidak bisa
# diperbaiki: menggantinya dengan `TextLocalization.text(…)` menuntut kunci
# ber-namespace untuk sebuah tanda pisah, dan itu menambah katalog tanpa
# menambah satu pun kata yang bisa diterjemahkan. Gerbang yang merah pada kode
# yang benar akan dimatikan orang lain saat ia berbunyi — jadi batasnya
# dinyatakan di sini, bukan disembunyikan.
keys = {k for k in keys if any(ch.isalnum() for ch in k)}


def strip_comments(src):
    """Buang komentar `//` dan `/* */` yang berada **di luar** literal string.

    Wajib, bukan kerapian: repo ini mendokumentasikan "kenapa" panjang lebar,
    dan komentarnya memuat contoh kode beserta nama kuncinya. Mengindeks
    komentar akan melaporkan situs yang tidak pernah dikompilasi — dan
    gerbang yang merah pada kode yang benar akan dimatikan orang.
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            out.append(c)
            i += 1
            while i < n:
                if src[i] == "\\" and i + 1 < n:
                    out.append(src[i:i + 2])
                    i += 2
                    continue
                out.append(src[i])
                if src[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i)
            i = n if j < 0 else j + 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def balanced(text, open_idx):
    """Isi kurung yang dibuka di `open_idx`, menghormati string dan nesting."""
    depth = 0
    i = open_idx
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    i += 2
                    continue
                if text[i] == '"':
                    break
                i += 1
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1:i]
        i += 1
    return ""


def split_args(inner):
    """Pisah argumen pada koma tingkat teratas."""
    args, depth, cur = [], 0, []
    i, n = 0, len(inner)
    while i < n:
        c = inner[i]
        if c == '"':
            cur.append(c)
            i += 1
            while i < n:
                cur.append(inner[i])
                if inner[i] == "\\" and i + 1 < n:
                    cur.append(inner[i + 1])
                    i += 2
                    continue
                if inner[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "," and depth == 0:
            args.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    if "".join(cur).strip():
        args.append("".join(cur))
    return args


problems = []
sites = 0
checked_helpers = 0

# Helper dibaca dari **kedua** pohon, bukan hanya `Apps/`.
#
# Versi pertama hanya membaca `Apps/`, dan itu meninggalkan separuh kelas cacat
# yang sama: helper-nya hidup di paket. `RowSpeech.spokenRow(title:value:)`
# misalnya bertipe `String` untuk keduanya, dan pemanggilnya di `Apps/`
# menyerahkan `"Laju pergelangan"` — literal kunci katalog yang sama persis,
# melewati katalog yang sama persis. Gerbang yang hanya melihat `Apps/` akan
# melaporkan bersih sambil baris itu tetap berbahasa Indonesia di semua bahasa.
#
# Situs pemanggilnya tetap hanya dari `Apps/`: teks yang sampai ke layar
# melewati helper dari sana, sedangkan panggilan di dalam paket mengirim
# kalimat yang sudah jadi atau pengenal, bukan label.
helper_signatures = {}
for tree in ("Apps", "Packages"):
    for dirpath, dirnames, filenames in os.walk(tree):
        dirnames[:] = [d for d in dirnames if d != ".build"]
        for name in sorted(filenames):
            if not name.endswith(".swift"):
                continue
            src = strip_comments(open(os.path.join(dirpath, name), encoding="utf-8").read())
            for m in re.finditer(r'\bfunc\s+(\w+)\s*\(', src):
                fname = m.group(1)
                inner = balanced(src, m.end() - 1)
                if not inner:
                    continue
                idxs = set()
                for pos, arg in enumerate(split_args(inner)):
                    if re.search(r':\s*String\b', arg):
                        idxs.add(pos)
                if idxs:
                    # Gabung, bukan timpa: dua tipe bisa punya `label(_:)`
                    # dengan bentuk berbeda, dan posisi String dari keduanya
                    # sama-sama perlu diperiksa.
                    helper_signatures.setdefault(fname, set()).update(idxs)
checked_helpers = len(helper_signatures)

for dirpath, dirnames, filenames in os.walk("Apps"):
    dirnames[:] = [d for d in dirnames if d != ".build"]
    for name in sorted(filenames):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(dirpath, name)
        src = strip_comments(open(path, encoding="utf-8").read())

        for fname, idxs in helper_signatures.items():
            # Dua bentuk panggilan: `row(` (fungsi lokal) dan `Tipe.row(`
            # (helper paket). Keduanya adalah situs yang sama.
            for pattern in (r'(?<![\w.])' + re.escape(fname) + r'\s*\(',
                            r'\.' + re.escape(fname) + r'\s*\('):
                for m in re.finditer(pattern, src):
                    inner = balanced(src, src.index("(", m.start()))
                    if not inner:
                        continue
                    for pos, arg in enumerate(split_args(inner)):
                        if pos not in idxs:
                            continue
                        for lit in re.findall(r'"((?:[^"\\]|\\.)*)"', arg):
                            if lit not in keys:
                                continue
                            sites += 1
                            line = src[:m.start()].count("\n") + 1
                            problems.append(
                                f"  {path}:{line}: {fname}(…) argumen {pos + 1} "
                                f"menerima kunci katalog {lit!r}\n"
                                f"      parameternya bertipe `String`, jadi "
                                f"`Text` mencetaknya apa adanya —\n"
                                f"      terjemahan katalog untuk kunci ini tidak "
                                f"akan pernah tampil.")

if problems:
    print(f"GAGAL: {len(problems)} literal katalog berdiri di parameter "
          f"bertipe `String`.")
    print("\n".join(problems))
    print("-> Parameter `String` melewati katalog. Lewatkan `TextLocalization"
          ".text(kunci)`\n   sebagai argumennya, atau ubah parameter helper "
          "itu menjadi `LocalizedStringKey`.")
else:
    print(f"Bersih: {checked_helpers} helper berparameter `String` di Apps/ "
          f"tidak menerima literal kunci katalog.")
PY
)
if [ -n "$nonlocalized" ]; then
  # Pola yang sama dengan Aturan 27/28: skrip Python mencetak pesannya sendiri
  # ("Bersih: …" atau "GAGAL: …"), dan yang menentukan status hanyalah
  # prefiksnya. Versi pertama memakai `-n` — dan itu membuat gerbang **selalu
  # merah**, karena pesan "Bersih" juga non-kosong. Gerbang yang selalu merah
  # akan dimatikan orang, jadi ia tidak menjaga apa pun.
  case "$nonlocalized" in
    GAGAL:*) status=1 ;;
  esac
  echo "$nonlocalized"
fi

# ── Aturan 30: kunci Info.plist yang dideklarasikan engine harus sampai ke proyek ──
# Aturan 14 hanya menguji **satu arah**: kunci yang sudah ada di `project.yml`
# harus punya terjemahan. Ia tidak bisa melihat arah sebaliknya — kunci yang
# dideklarasikan **engine** dan tidak pernah ditulis ke `project.yml` sama
# sekali. Untuk arah itu Aturan 14 persis "hijau karena tidak ada yang
# diuji": himpunan `perms`-nya diambil dari `project.yml`, jadi kunci yang
# absen tidak pernah masuk perbandingan.
#
# Itu bukan cacat hipotetis. `TelescopeNetworkRequirements.localNetworkUsageKey`
# (`NSLocalNetworkUsageDescription`) sudah dideklarasikan dan diuji di
# `CelestialEngine` sejak §19, tetapi tidak ada di `project.yml` maupun di
# kedua `InfoPlist.strings` — seluruh 29 aturan hijau sementara aplikasi
# diam-diam tidak akan pernah menemukan teleskop. Kegagalannya memang bukan
# galat yang terbaca: tanpa kunci ini iOS menolak akses jaringan lokal tanpa
# peringatan, dan layar hanya menunjukkan "teleskop tidak ditemukan".
#
# Yang diperiksa: setiap kunci `NS*UsageDescription` yang dideklarasikan di
# sumber `Packages/` harus muncul di `project.yml`. Keduanya dibaca dari
# berkas — gerbang yang menyalin daftar kuncinya sendiri akan tetap hijau
# saat engine menambah kunci baru.
#
# **Batas yang dinyatakan.** `NSBonjourServices` sengaja TIDAK dituntut: ia
# hanya wajib bila ada tipe layanan yang benar-benar di-browse
# (`needsBonjourDeclaration`), dan tidak satu pun transport produksi yang
# mendaftarkannya. Menuntutnya akan memaksa menulis kunci untuk layanan yang
# tidak dipakai.
echo
echo "== Aturan 30: kunci izin engine harus sampai ke project.yml =="
declared=$(python3 - <<'PY' 2>&1
import os, re

SPEC = "project.yml"
SRC  = "Packages"

# Kunci yang dideklarasikan engine: `public static let <nama> = "NS...UsageDescription"`.
# Hanya yang berakhiran `UsageDescription` — `NSBonjourServices` bukan teks
# izin dan hanya wajib bersyarat (lihat batas di atas).
keys = {}
pat_decl = re.compile(r'static\s+let\s+(\w+)\s*=\s*"(NS\w*UsageDescription)"')
for root, _dirs, files in os.walk(SRC):
    # `.build` berisi salinan artefak yang bisa ikut terhitung dua kali.
    if ".build" in root.split(os.sep):
        continue
    for name in files:
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        try:
            text = open(path, encoding="utf-8").read()
        except OSError:
            continue
        for m in pat_decl.finditer(text):
            keys.setdefault(m.group(2), path)

if not keys:
    # Himpunan kosong berarti gerbang ini kehilangan giginya. Dilaporkan
    # keras: aturan yang menemukan nol kunci akan selalu "Bersih", dan itu
    # persis hijau yang tidak hijau.
    print("PERINGATAN: tidak ada kunci izin yang dideklarasikan di Packages/.")
    raise SystemExit

if not os.path.exists(SPEC):
    print("PERINGATAN: project.yml tidak ada.")
    raise SystemExit

spec = open(SPEC, encoding="utf-8").read()
present = set(re.findall(r'INFOPLIST_KEY_(NS\w*UsageDescription)\s*:', spec))

missing = [f"  {k} (dideklarasikan {v}) tidak ada di {SPEC}"
           for k, v in sorted(keys.items()) if k not in present]
print("\n".join(missing) if missing else "")
PY
)
if printf '%s' "$declared" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 30 gagal dijalankan:"
  echo "$declared"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$declared" ]; then
  echo "Kunci izin yang dideklarasikan engine tapi absen di project.yml:"
  echo "$declared"
  echo "-> Tanpanya iOS menolak akses tanpa peringatan, dan Aturan 14 tidak"
  echo "   bisa melihatnya (himpunannya diambil dari project.yml sendiri)."
  status=1
else
  echo "Bersih: setiap kunci izin engine ada di project.yml."
fi

# ── Aturan 31: arah fase harus sampai ke gambar untuk SETIAP benda berfase ──
# `PointingEngine.visualForDisplayedObject` (Apps/Shared/PointingEngine.swift)
# adalah **satu-satunya** kawat yang menghubungkan arah fase (waxing/waning)
# ke gambar objek. Kawat ini hidup di `Apps/`, jadi ia **tidak terjangkau**
# `swift-test.sh` (Linux hanya membangun `Packages/`), dan sebelum aturan ini
# ia juga tidak punya gerbang mana pun — satu-satunya penjaganya adalah
# komentar.
#
# **Cacat yang ditutup aturan ini, dan kenapa komentar tidak cukup.** Kawat
# itu dulunya berbunyi:
#
#     let waxing = isMoon ? moonIsWaxing : nil
#
# `phaseGeometry(waxing:)` mengembalikan `nil` bila arahnya `nil`, jadi baris
# itu mematikan **seluruh** jalur fase planet dalam: `planetPhases` dan
# `planetBrightLimbAngles` dihitung tiap 30 detik, lalu tidak pernah dipakai
# gambar apa pun. Venus tampil sebagai bola penuh di setiap keadaan —
# termasuk saat engine baru saja menghitung iluminasinya 2 persen. Gambar itu
# menyatakan kebalikan dari apa yang dihitung engine, dan tidak ada satu teks
# pun di layar yang bisa dibaca pengguna untuk memeriksanya.
#
# Perbaikannya sudah mendarat di sumber, tapi **tidak ada uji yang
# menangkapnya** — karena uji menguji *rumus*-nya
# (`testInnerPlanetDrawsAPhaseFromItsOwnFraction`), bukan *pengawat*-nya. Tanpa
# gerbang, satu penyuntingan yang mengembalikan `nil` untuk planet akan hijau
# di semua 30 aturan lain dan merah hanya di langit.
#
# **Kenapa polanya "benda berfase", bukan "planet".** Keduanya berfase karena
# alasan yang sama (sisi terang menghadap Matahari) dan memakai kurva yang
# sama — jadi aturannya satu, bukan dua. Menulis ulang daftar planet di sini
# akan membuat salinan kedua yang bisa berbeda diam-diam dari model.
#
# Yang diperiksa: kawatnya tidak boleh lagi mengembalikan `nil` untuk benda
# bukan-Bulan, `isWaxing` harus benar-benar diteruskan ke `CelestialVisual`,
# dan **kedua** kawat geometri fase planet (`brightLimbAngleRadians` dan
# `planetIlluminationFraction`) harus benar-benar terisi untuk planet berfase.
#
# **Kedua kawat itu kelas cacat yang sama, dan versi pertama aturan ini
# melewatkannya sambil mengklaim sebaliknya.** Komentar di atas menyebut
# `planetBrightLimbAngles` sebagai "dihitung tiap 30 detik, lalu tidak pernah
# dipakai gambar apa pun" — tetapi yang diperiksa hanya kawat `waxing`.
# Diukur pada port dengan mematikan satu kawat per keadaan:
#
#     brightLimbAngleRadians      -> nil : 10.254/40.000 piksel (25,6%)
#     planetIlluminationFraction  -> nil : 31.604/40.000 piksel (79,0%)
#
# Keduanya membuat Aturan 31 tetap **hijau** dan seluruh 31 aturan UI lulus.
# Yang kedua paling parah: seluruh pita terang hilang dan Venus tergambar
# sebagai **bola penuh** di setiap keadaan, termasuk saat engine baru
# menghitung iluminasinya 0,22 — gambar yang menyatakan kebalikan dari yang
# dihitung engine. Ini kelas cacat yang paling sering berulang di repo ini:
# gerbang yang mengutip sebuah jalur di komentarnya tanpa mengukurnya.
echo
echo "== Aturan 31: arah fase harus sampai ke gambar untuk tiap benda berfase =="
waxing=$(python3 - <<'PY' 2>&1
import os, re

WIRE = "Apps/Shared/PointingEngine.swift"

if not os.path.exists(WIRE):
    print("PERINGATAN: %s tidak ada." % WIRE)
    raise SystemExit

text = open(WIRE, encoding="utf-8").read()

# Kode saja: komentar di berkas ini menceritakan cacat lamanya, dan pola
# `: nil` yang **dikomentari** tidak boleh terbaca sebagai kenyataan.
code = re.sub(r"//[^\n]*", "", text)
code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)

problems = []

# 1. Kawat `waxing` tidak boleh `nil` untuk benda berfase mana pun.
#    Dicari sebagai penugasan ke `waxing`, lalu ditolak bila **salah satu**
#    cabangnya berujung pada `nil`.
#
#    **Kenapa kedua cabang, bukan hanya `else`.** Versi pertama memeriksa
#    `:\s*nil\s*$` saja -- sisi bukan-Bulan. Diukur: mengubah sisi **Bulan**
#    menjadi nil (`isMoon ? nil : planet.flatMap { … }`) membuat seluruh 31
#    aturan UI tetap hijau, sementara 31.604 dari 40.000 piksel (79,0%) sabit
#    Bulan berubah -- Bulan kehilangan fasenya. Cacat yang sama bentuknya
#    dengan yang gerbang ini tutup: satu cabang diperiksa, cabang lain
#    dikutip. Bentuk itu mudah terjadi justru karena sisi planet yang panjang
#    menarik mata, dan `nil` di sisi Bulan terlihat seperti "belum ada data".
assigns = re.findall(r"\blet\s+waxing\s*=\s*([^\n]+)", code)
if not assigns:
    problems.append("  tidak ditemukan penugasan `let waxing =` di %s; gerbang ini "
                    "kehilangan gigi" % WIRE)
for expr in assigns:
    stripped = expr.strip()
    # Cabang Bulan (`isMoon ? X : …`) dan cabang planet (`… : Y`).
    ternary = re.match(r".*?isMoon\s*\?\s*(.*?)\s*:\s*(.*)$", stripped)
    if ternary:
        moon_side, planet_side = ternary.group(1).strip(), ternary.group(2).strip()
        if moon_side == "nil":
            problems.append(
                "  `let waxing = %s` mengembalikan nil untuk **Bulan**; Bulan "
                "kehilangan fasenya dan tampil sebagai bola penuh di setiap "
                "keadaan (terukur 79,0%% piksel berbeda)" % stripped)
        if planet_side == "nil":
            problems.append(
                "  `let waxing = %s` mengembalikan nil untuk **planet dalam**; "
                "arah fase planet mati total dan Venus tampil sebagai bola "
                "penuh di setiap keadaan" % stripped)
    elif re.search(r":\s*nil\s*$", stripped):
        problems.append("  `let waxing = %s` mengembalikan nil untuk benda bukan-Bulan; "
                        "arah fase planet dalam mati total dan Venus tampil sebagai "
                        "bola penuh di setiap keadaan" % stripped)

# 2. `isWaxing` harus benar-benar diteruskan **dan bernilai** ke `CelestialVisual`.
#
# Versi pertama hanya memeriksa `"isWaxing:" in code` -- keberadaan stringnya.
# Diukur: `isWaxing: nil` membuat pemeriksaan itu hijau, padahal arah fase
# mati di kedua cabang (Bulan dan planet), dan 31.604 dari 40.000 piksel
# (79,0%) berubah. Pemeriksaan yang mencari **nama** tidak pernah bisa
# menangkap nilai yang salah; karena itu kawat ini sekarang masuk
# `PHASE_WIRES` dan diperiksa sebagai nilai, bukan sebagai string.
if "isWaxing:" not in code:
    problems.append("  `isWaxing:` tidak diteruskan ke CelestialVisual; arah fase "
                    "yang dihitung tidak pernah sampai ke gambar")

# 3. Kawat **sudut** sisi terang (`brightLimbAngleRadians`) untuk planet berfase.
#
# Kawat kedua di fungsi yang sama, dan kelas cacatnya persis sama: `nil`
# berarti "jangan putar" (`terminatorRotationRadians` mengembalikan nil), jadi
# sabit Venus tergambar tegak -- sisi terang ke kanan -- sementara di langit
# ia menghadap Matahari. Terukur pada port: 10.254 dari 40.000 piksel (25,6%)
# berbeda pada Venus f=0,22 sudut -pi/2, dan 12.916 (32,3%) pada Merkurius
# f=0,30 sudut -pi/2. Tidak ada teks di layar yang bisa membantahnya: yang
# tampil tetap sabit.
#
# **Sudutnya wajib disebut, dan itu bukan kerapian penulisan.** `nil` memutar
# 0 rad, jadi cacat ini **tak terlihat** pada benda yang sudutnya memang 0 --
# **asalkan fasenya memakai pita dasar kiri** (`lit_side > 0`, yaitu waxing).
# Kasus katalog `planet-mercury-crescent` memakai sudut 0,0 dan terukur 0 dari
# 40.000 piksel berubah. Gerbang yang mengukur benda itu akan hijau selamanya
# pada kawat yang mati -- gerbang hampa, kelas cacat yang sudah berulang di
# repo ini. Angka Merkurius di atas karena itu diukur dengan sudut -pi/2, bukan
# pada sudut katalognya.
#
# **Dan "sudut 0" saja tidak cukup untuk menyimpulkan "tak terlihat".** Untuk
# fase yang dasarnya ada di kanan (`lit_side < 0`, waning),
# `terminatorRotationRadians` menambahkan pi -- jadi nil (0 rad) **tidak**
# sama dengan sudut 0. Terukur: `moon-waning-crescent` (sudut 0,0, waning)
# berubah 11.608 dari 40.000 piksel (29,0%) saat kawat sudutnya dimatikan,
# sementara `moon-crescent-jakarta` (sudut -pi/2, waxing) berubah 8.686
# (21,7%). Gerbang hampa hanya terjadi bila **sudut 0 dan waxing** bertemu;
# memilih benda contoh untuk gerbang piksel harus memeriksa keduanya, dan
# angka yang dikutip harus menyebut sudutnya.
#
# **Kenapa pemakaian dan penugasan harus dibaca bersama.** Memeriksa
# argumennya saja (`: planetLimbAngle`) tidak melihat bentuk cacat yang
# paling mungkin: nilainya di-`nil`-kan di baris **penugasan**, dan argumennya
# tetap menyebut nama yang sama. Diukur: `let planetLimbAngle: Double? = nil`
# dengan argumen utuh membuat Aturan 31 versi lama tetap hijau, sementara
# gambarnya sudah kehilangan orientasinya.
#
# **Kenapa yang ditelusuri hanya cabang yang berlaku.** Ekspresi argumennya
# berbentuk `isMoon ? limbAngle : planetLimbAngle`, dan `limbAngle` **memang**
# bernilai nil untuk planet (`isMoon ? moonBrightLimbAngle : nil`) -- itu
# benar, karena cabang itu tidak pernah dipakai planet. Menelusuri seluruh
# ekspresi akan menuduh kode yang benar. Yang ditelusuri karena itu hanya
# cabang yang berlaku untuk benda itu: sisi `else` untuk planet, sisi `then`
# untuk Bulan.
def _branch(expr, want_moon):
    """Bagian `expr` yang berlaku untuk Bulan (`want_moon`) atau planet."""
    ternary = re.match(r".*?isMoon\s*\?\s*(.*?)\s*:\s*(.*)$", expr)
    if not ternary:
        return expr.strip()
    return (ternary.group(1) if want_moon else ternary.group(2)).strip()


def _bound_value(name):
    """**Semua** ekspresi yang diikat ke `name` lewat `let`, sebagai daftar.

    **Kenapa semua ikatan, bukan yang pertama, dan kenapa itu tidak sepele.**
    Diukur pada `Apps/Shared/PointingEngine.swift`: berkas itu mengikat
    `fraction` **dua** kali (sekali di dalam `for` planet berfase, sekali
    untuk Bulan) dan `waxing` **dua** kali pula. `re.search` mengembalikan
    ikatan **pertama** -- milik planet -- jadi menelusuri kawat Bulan
    `moonIlluminationFraction: fraction` membaca ikatan **planet** dan
    melaporkan "bersih" berdasarkan baris yang tidak pernah dipakai Bulan.
    Gerbangnya tidak longgar: ia membaca baris yang salah.

    Terukur, proses baru, dengan mutasi yang tetap bisa dikompilasi
    (bukan `= nil` polos yang menolak dikompilasi karena `let` tanpa tipe
    tidak boleh diikat ke `nil`):

        let fraction: Double? = nil          -> HIJAU   (Bulan kehilangan fase)
        let planet: ...Planet? = nil         -> HIJAU   (planet kehilangan fase)
        let waxing: Bool? = nil              -> HIJAU   (keduanya kehilangan arah)

    Ketiganya mengubah **31.604 dari 40.000 piksel (79,0%)** pada port --
    Bulan/planet tergambar sebagai bola penuh di setiap keadaan, persis cacat
    yang gerbang ini ditulis untuk menangkap.

    Aturannya karena itu: sebuah kawat merah bila **salah satu** ikatan
    namanya nil untuk benda itu. Bukan "semua ikatan nil" -- itu akan
    mengembalikan kegagalan yang sama dengan menyembunyikannya di balik
    ikatan lain yang kebetulan sehat.
    """
    return [m.strip() for m in
            re.findall(r"\blet\s+%s\b[^=\n]*=\s*([^\n]+)" % re.escape(name), code)]


def _is_nil_for(expr, want_moon):
    """True bila `expr` jelas bernilai nil untuk benda itu (Bulan/planet).

    `want_moon=None` berarti "cabang mana pun": dipakai untuk kawat yang
    nil-nya mematikan fase **kedua** jenis benda, seperti `isWaxing`.
    """
    if expr is None:
        return False
    if want_moon is None:
        return _is_nil_for(expr, False) or _is_nil_for(expr, True)
    value = _branch(expr, want_moon)
    if value == "nil":
        return True
    # Bentuk bersarang: cabangnya sendiri bercabang lagi.
    return value != expr.strip() and _is_nil_for(value, want_moon)


#: Kawat-kawat fase yang wajib terisi, per **cabang benda**.
#:
#: Semuanya kelas cacat yang **sama** -- `nil` berarti "jangan gambar fase",
#: jadi gambar menyatakan kebalikan dari yang dihitung engine. Diukur pada
#: port dengan mematikan satu kawat per keadaan, lalu menjalankan seluruh 31
#: aturan UI (semuanya tetap **hijau**):
#:
#:   `planetIlluminationFraction` -> nil : 31.604/40.000 piksel Venus (79,0%)
#:   `moonIlluminationFraction`   -> nil : 31.604/40.000 piksel Bulan (79,0%)
#:   `brightLimbAngleRadians` (planet) -> nil : 10.254/40.000 Venus (25,6%)
#:   `brightLimbAngleRadians` (Bulan)  -> nil : 8.686/40.000 (21,7%) pada
#:                                              `moon-crescent-jakarta`
#:
#: Yang fraksi paling parah: seluruh pita terang hilang dan benda tergambar
#: sebagai **bola penuh** di setiap keadaan, termasuk saat engine baru
#: menghitung iluminasinya 0,22.
#:
#: **Cabang Bulan ditemukan belakangan, dan itu bukan kerapian.** Versi
#: sebelumnya hanya memeriksa cabang planet, jadi `moonIlluminationFraction:
#: nil` -- yang mematikan fase Bulan, benda yang justru paling sering
#: ditunjuk -- hijau di seluruh 31 aturan. Kesalahan yang sama bentuknya
#: dengan yang gerbang ini tutup: satu cabang diperiksa, cabang lain dikutip.
PHASE_WIRES = (
    ("isWaxing", None,
     "arah fase tidak pernah sampai ke gambar, jadi pita terang tergambar "
     "di sisi yang salah untuk kedua jenis benda berfase (terukur 79,0% "
     "piksel)"),
    ("brightLimbAngleRadians", False,
     "sudut sisi terang planet tidak pernah sampai ke gambar, jadi sabit "
     "Venus tergambar menghadap arah yang salah (terukur 25,6% piksel)"),
    ("planetIlluminationFraction", False,
     "fraksi iluminasi planet tidak pernah sampai ke gambar, jadi Venus "
     "tampil sebagai bola penuh di setiap keadaan -- termasuk saat engine "
     "baru menghitung iluminasinya 0,22 (terukur 79,0% piksel)"),
    ("brightLimbAngleRadians", True,
     "sudut sisi terang Bulan tidak pernah sampai ke gambar, jadi sabit "
     "Bulan tergambar menghadap arah yang salah (terukur 21,7% piksel)"),
    ("moonIlluminationFraction", True,
     "fraksi iluminasi Bulan tidak pernah sampai ke gambar, jadi Bulan "
     "tampil sebagai bola penuh di setiap keadaan -- termasuk saat engine "
     "baru menghitung iluminasinya 0,18 (terukur 79,0% piksel)"),
)


#: Argumen bernama di dalam daftar argumen: `label: value`.
#:
#: **Kenapa harus didahului `(` atau `,`.** Tanpa itu, titik dua **ternary**
#: ikut terbaca sebagai label argumen: `let fraction = isMoon ?
#: skyContext?.moonIlluminationFraction : nil` menghasilkan kecocokan
#: `moonIlluminationFraction : nil`, dan gerbangnya lalu menuduh kode yang
#: benar. Itu kelas cacat yang lebih berbahaya daripada gerbang yang hijau
#: pada kode salah — orang yang terburu-buru akan mengembalikan kodenya ke
#: bentuk yang salah supaya gerbangnya diam. Ditemukan saat cabang Bulan
#: ditambahkan; cabang planet tidak pernah kena karena `planetPhases` tidak
#: muncul di ternary mana pun.
_ARG = r"(?:[(,]\s*)%s\s*:\s*([^,\n]+)"


def _phase_wire_args(wire):
    """Ekspresi argumen untuk `wire` di `PointingEngine.swift`, sebagai daftar."""
    return re.findall(_ARG % re.escape(wire), code)


def _strip_unbalanced_close(expr):
    """Buang `)` penutup yang tidak berpasangan di ujung `expr`.

    Argumennya dipotong dari teks panggilan, jadi `)` penutup panggilan itu
    ikut terbaca sebagai bagian ekspresi: `planetIlluminationFraction:
    planetPhase)` menghasilkan `planetPhase)`. Tanpa dibuang, pemeriksaannya
    tidak mengenali `nil` telanjang dan gerbangnya hijau pada kawat yang mati
    -- diukur pada keadaan 3 harness `bukti-mutasi-aturan31-kawat.py`.

    Yang dibuang hanya `)` yang **tidak berpasangan**: `foo()` tetap utuh,
    karena kurungnya berpasangan.
    """
    value = expr.strip()
    while value.endswith(")"):
        if value.count("(") >= value.count(")"):
            break
        value = value[:-1].strip()
    return value


def _telusuri(name, want_moon, why, wire, depth, visited):
    """Telusuri `name` ke ikatannya; merah bila **rantaiannya** berujung nil.

    Dua tingkat pertama yang diukur buta, keduanya dengan mutasi yang tetap
    bisa dikompilasi:

        let fraction: Double? = nil       (kedalaman 0 -- langsung)
        let planet: ...Planet? = nil      (kedalaman 1 -- lewat `planetPhase`)

    Yang kedua tetap hijau pada penelusuran satu tingkat: `planetPhase`
    sendiri tidak pernah berubah, karena yang mati adalah `planet` di
    dalamnya, dan `flatMap` atas `nil` mengembalikan `nil`.
    """
    if depth > 4 or name in visited:
        return
    visited.add(name)
    for value in _bound_value(name):
        if _is_nil_for(value, want_moon):
            problems.append(
                "  `%s` memakai `%s`, yang diikat ke `%s` -- nil untuk "
                "benda berfase; %s" % (wire, name, value, why))
            continue
        for inner in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\b",
                                _branch(value, want_moon)):
            if inner in ("nil", "true", "false", "isMoon", "flatMap"):
                continue
            _telusuri(inner, want_moon, why, wire, depth + 1, visited)


_seen_wires = set()
for wire, want_moon, why in PHASE_WIRES:
    args = _phase_wire_args(wire)
    if not args:
        if wire not in _seen_wires:
            _seen_wires.add(wire)
            problems.append("  `%s:` tidak ditemukan di %s; gerbang ini "
                            "kehilangan gigi" % (wire, WIRE))
        continue
    for raw in args:
        expr = _strip_unbalanced_close(raw)
        side_expr = _branch(expr, want_moon)
        if _is_nil_for(expr, want_moon):
            problems.append("  `%s: %s` bernilai nil untuk benda berfase; %s"
                            % (wire, expr, why))
            continue
        # Telusuri nama yang dipakai **di cabang itu** ke nilai penugasan.
        #
        # **Kenapa penelusurannya transitif, dan kenapa kedalaman 2 bukan
        # berlebihan.** Diukur: `let planet: CelestialVisual.Planet? = nil`
        # tetap **hijau** setelah perbaikan ikatan-jamak di atas, karena
        # `planetPhase` sendiri tidak pernah berubah -- ia masih tertulis
        # `planet.flatMap { planetPhases[$0] }`. Kawatnya mati **satu
        # tingkat lebih jauh**: `flatMap` pada `nil` mengembalikan `nil`, jadi
        # seluruh fase planet lenyap sementara barisnya terbaca utuh.
        # Terukur pada port: 31.604/40.000 piksel (79,0%).
        #
        # Kedalaman dibatasi 4 dan memakai himpunan `visited` karena
        # penelusuran tanpa batas bisa berputar pada ikatan yang saling
        # menyebut; batasnya bukan soal hemat, melainkan supaya gerbang ini
        # tidak pernah menggantung.
        for name in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\b", side_expr):
            if name in ("nil", "true", "false", "isMoon"):
                continue
            _telusuri(name, want_moon, why, wire, 0, set())


#: Cacat kedua di kelas yang sama, dan **bukan** nullability: planet yang salah.
#:
#: Seluruh pemeriksaan di atas menuntut kawat fase berisi nilai yang bukan nil.
#: Terukur di atas salinan utuh (proses baru, `Apps/` dibawa): satu baris
#:
#:     let planet = CelestialVisual.Planet.venus
#:
#: membuat **setiap** planet berfase memakai fase Venus -- dan seluruh Aturan 31
#: (beserta 11 keadaan harnessnya) tetap hijau. Baris itu tidak mengubah satu
#: pun kawat: `planetPhases`, `planetWaxing`, dan `planetBrightLimbAngles`
#: masih dibaca dengan kunci yang sah, masih bukan nil; yang berubah hanya
#: **planet mana** yang dipakai kuncinya. Venus yang sedang sabit tipis
#: menularkan sabitnya ke Merkurius, dan sebaliknya. Gambarnya tetap "sabit",
#: jadi tidak ada teks di layar yang bisa dibantah pembaca.
#:
#: Satu-satunya sumber identitas di fungsi itu adalah `object`, jadi bentuk sah
#: untuk baris ini adalah yang **menyebut `object`**. Bentuk tetap seperti
#: `CelestialVisual.Planet(rawValue: object.id)` dan
#: `CelestialVisual.Planet(objectID: object.id)` lolos; bentuk yang tidak
#: menyebutnya -- `.venus`, `.jupiter`, `.allCases.first { … }` -- ditolak.
IDENTITY = re.compile(r"CelestialVisual\.Planet\s*(?:\(|\.)")

#: Baris yang dibaca: satu-satunya yang mengikat `planet` dari model visual.
IDENTITY_BINDING = re.compile(r"[ \t]*let\s+planet\s*=\s*CelestialVisual\.Planet\b",
                              re.M)


def _identity_expr():
    """Ekspresi setelah `=` pada baris pengikatan `planet`, atau None.

    Yang dikembalikan **termasuk** `CelestialVisual.Planet` sendiri, supaya
    `IDENTITY` menilai ekspresinya utuh, bukan hanya lanjutannya.
    """
    m = IDENTITY_BINDING.search(code)
    if m is None:
        return None
    return code[m.end():code.find("\n", m.end())]


def _identity_problem():
    """Satu masalah, atau None: apakah baris `let planet = …` memakai objeknya.

    Arah kedua yang lebih penting: bentuk yang **sah** tetap harus menyebut
    `object`. Tanpa itu, `CelestialVisual.Planet(objectID: "venus")` -- masih
    panggilan, tetapi planet tetap yang menyamar -- akan lolos, dan setiap
    planet berfase memakai fase Venus.
    """
    bars = IDENTITY_BINDING.findall(code)
    if len(bars) != 1:
        return ("  tidak ditemukan tepat satu `let planet = CelestialVisual.Planet…` "
                "di %s (%d ketemu); pemeriksa identitas kehilangan gigi, dan tanpa "
                "baris itu fase planet tidak dihitung dari objek yang tampil"
                % (WIRE, len(bars)))
    expr = _identity_expr()
    if expr is None:
        return None
    # Bentuk tetap yang tidak menyebut objeknya. Dua corak, keduanya sungguh
    # terjadi: kasus enum tanpa argumen (`Planet.venus`) dan terusan penerusnya
    # yang menyamar sebagai bentuk sah (`Planet(objectID: "venus")`,
    # `Planet(rawValue: other.id)`).
    #
    # Dibaca sebagai label argumen, bukan dicocokkan dengan satu regex besar:
    # uji-ulang menunjukkan pola berlapis itu mencocokkan `(objectID:` lalu
    # berhenti -- "ada argumen bernama objectID" terbaca sebagai "memakai
    # objek". Labelnya harus berisi kata `object` sendiri.
    arg = re.match(r"\s*\(\s*([A-Za-z_]\w*)\s*:\s*(.*)\)", expr, re.S)
    if re.match(r"\s*\.\w+", expr) or (
            arg and arg.group(1) in ("objectID", "rawValue")
            and not re.search(r"\bobject\b", arg.group(2))):
        return ("  `let planet = CelestialVisual.Planet%s` tidak mengambil "
                "identitas planet dari objek yang tampil; setiap planet berfase "
                "lalu memakai fase planet lain -- sah, bukan nil, dan tidak ada "
                "teks di layar yang bisa membantahnya" % expr.rstrip())
    return None


_masalah_identitas = _identity_problem()
if _masalah_identitas:
    problems.append(_masalah_identitas)


#: Cacat ketiga, dan **bukan** soal nullability maupun identitas: kuncinya.
#:
#: Pemeriksaan di atas menuntut (a) kawat berisi nilai bukan nil, dan (b)
#: `let planet` menyebut `object`. Terukur, keduanya hijau pada mutasi ini
#: (proses baru, program Aturan 31 dijalankan langsung atas salinan):
#:
#:     let planetPhase = planet.flatMap { planetPhases[$0] }
#:   -> let planetPhase = planet.flatMap { _ in planetPhases.values.first }
#:
#: `planet` masih benar, kamusnya masih dibaca, nilainya bukan nil — yang
#: hilang hanya **planet mana** yang jadi kuncinya, jadi setiap planet
#: berfase memakai fraksi planet pertama di kamus. Diukur pada port: pita
#: terang Venus berubah **75,6%** piksel (0,22 → 0,90), Merkurius **82,2%**
#: (0,50 → 0,09). Gambarnya tetap terbaca sebagai "planet berfase", jadi
#: tidak ada teks di layar yang bisa membantahnya — kelas cacat yang sama
#: dengan `let planet = .venus`, tetapi lewat kamusnya.
#:
#: **Kenapa yang diperiksa bentuk ikatannya, bukan hasil evaluasinya.**
#: Kamusnya diisi saat `refresh`, dan gerbang ini tidak mengeksekusi Swift.
#: Yang bisa dibuktikan dari teks adalah bahwa indeks kamusnya **planet itu
#: sendiri**: penutup fungsinya memakai `planet` — entah lewat `$0` (argumen
#: `flatMap` atas `planet`) atau lewat `planet` langsung.
#:
#: **Kenapa `$0` diterima utuh, bukan dicurigai.** `planet.flatMap { ... }`
#: dijalankan atas `Optional`, jadi `$0` **adalah** planet yang sedang
#: digambar. Yang ditolak adalah bentuk yang mengabaikannya: `{ _ in … }`,
#: `{ _ in values.first }`, `.first`, `.values.first`, `planetPhases.values`,
#: dan indeks konstanta seperti `planetPhases[.venus]`.
PHASE_MAPS = ("planetPhases", "planetWaxing", "planetBrightLimbAngles")

#: Satu baris `let <nama> = <indeks> <kamus> [ … ]`, dengan pengikat opsional.
#: Antara nama kamus dan `[` boleh ada `.values`/`.first`/`.allCases` —
#: bentuk yang justru jadi cacat (`planetPhases.values.first`) tetap harus
#: terbaca sebagai **pembacaan kamus itu**, supaya pesannya menunjuk sebab
#: yang benar alih-alih mengaku kamusnya tidak dibaca.
_KEY_BINDING = re.compile(
    r"[ \t]*let\s+(\w+)\s*=\s*(.*?)\b(%s)\b([^\n]*)" % "|".join(PHASE_MAPS), re.M)


def _key_problem():
    """Satu masalah, atau None: apakah tiap kawat kamus memakai planetnya."""
    found = {}
    for m in _KEY_BINDING.finditer(code):
        name, prefix, table, tail = m.groups()
        # `tail` = `[$0]` untuk bentuk sehat, atau `.values.first` dst.
        key = "—"
        if "[" in tail:
            rest = code[m.end() - len(tail) + tail.index("["):]
            close = rest.find("]")
            key = rest[1:close] if close >= 0 else rest[1:41]
        elif tail.strip():
            key = tail.strip()
        found.setdefault(table, []).append((name, prefix.strip(), key.strip(), tail))

    missing = [t for t in PHASE_MAPS if t not in found]
    # **Kenapa "kamus dibaca" hanya jadi syarat keras bila **ketiganya** hilang.**
    # Satu mutasi bisa mematikan dua hal sekaligus: `let planetPhase: Double? =
    # nil` menghapus pembacaan kamus **dan** mematikan kawatnya, dan kawatnya
    # sudah dilaporkan pemeriksaan nullability di atas. Melaporkan "kamus tidak
    # dibaca" di situ akan terbaca sebagai cacat **kedua** pada keadaan yang
    # sebenarnya hanya punya satu -- salah-diagnosis yang sudah dibayar mahal
    # di harness ini: pembaca lalu memperbaiki sebab yang salah dan gerbangnya
    # tetap merah (terlihat pada keadaan 2, 4, 8, dan 11 sebelum diperbaiki).
    #
    # Tetapi syarat itu **tidak boleh hilang sama sekali**, karena itulah satu-
    # satunya penjaga non-vakum: bila ketiga kamus lenyap (mis. fungsinya
    # ditulis ulang tanpa fase planet), tidak ada satu baris pun yang tersisa
    # untuk diperiksa kuncinya, dan gerbang ini akan hijau tanpa memeriksa apa
    # pun. Ketiganya sekaligus lenyap **tidak** mungkin akibat satu kawat mati,
    # jadi pesannya tidak pernah menjadi diagnosis palsu.
    if len(missing) == len(PHASE_MAPS):
        return ("  tidak satu pun kamus fase (%s) dibaca di %s; pemeriksa "
                "kunci kehilangan gigi, dan tanpa baris itu fase planet tidak "
                "dihitung dari objek yang tampil"
                % (", ".join("`%s`" % t for t in PHASE_MAPS), WIRE))
    return _check_keys(found)


def _check_keys(found):
    for table, binds in found.items():
        for name, prefix, key, tail in binds:
            # Bentuk sehat: `flatMap { <kamus>[$0] }` atau `[planet]`.
            uses_whole = key == "$0" and "flatMap" in prefix
            uses_planet = re.search(r"\bplanet\b", key) is not None
            if uses_whole or uses_planet:
                continue
            excerpt = (prefix + " " + table + tail).strip() if prefix else (table + tail).strip()
            return ("  `let %s = %s` tidak memakai planet yang sedang "
                    "digambar sebagai kunci; setiap planet berfase lalu "
                    "memakai fase planet lain -- sah, bukan nil, dan tidak "
                    "ada teks di layar yang bisa membantahnya"
                    % (name, excerpt))
    return None


_masalah_kunci = _key_problem()
if _masalah_kunci:
    problems.append(_masalah_kunci)

print("\n".join(problems) if problems else "")
PY
)
if printf '%s' "$waxing" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 31 gagal dijalankan:"
  echo "$waxing"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$waxing" ]; then
  echo "Kawat arah fase putus di Apps/Shared/PointingEngine.swift:"
  echo "$waxing"
  echo "-> Tanpa arah, phaseGeometry mengembalikan nil dan benda berfase"
  echo "   kehilangan fasenya; cacatnya tidak terlihat di layar mana pun."
  status=1
else
  echo "Bersih: arah fase diteruskan untuk setiap benda berfase."
fi

# ── Aturan 32: penanda "engine ragu" harus benar-benar digambar ────────────
#
# Dua baris di `Apps/Shared/CelestialVisualView.swift` adalah satu-satunya
# penanda di layar yang mengatakan "engine tidak yakin":
#
#   baris 63  `if !isConfirmed { drawCandidateMarker(...) }`
#   baris 308 `if !(isConfirmed && palette.feature == .rings)`
#
# Tanpa baris 63, kandidat yang belum terkunci digambar **tanpa** lencana
# tanda tanya, sehingga gambar terbaca sebagai identitas yang pasti di
# sebelah badge teks "Ragu" -- persis kebalikan dari PRD §2 (gambar tidak
# boleh lebih yakin daripada teksnya).
#
# **Kenapa gerbang ini harus ada: cacatnya terbukti tak terlihat.** Baris 63
# dihapus (mutasi), lalu seluruh 31 aturan UI **dan** `swift-typecheck.sh`
# dijalankan: keduanya tetap lulus, exit 0. `swift test` di Linux tidak bisa
# menolong karena ia hanya membangun `Packages/` -- berkas ini hidup di
# `Apps/`. Jadi sampai aturan ini ada, menghapus satu-satunya penanda
# keraguan di layar tidak menghasilkan satu pun kegagalan.
#
# Kenapa geometrinya tidak cukup: `VisualFrame.candidateMarker()` memang
# diuji di Linux (`testLegacyCandidateMarkerOverflowedOnTwoSides`), tetapi
# uji itu memeriksa **bentuknya**, bukan bahwa fungsinya **dipanggil**.
# Bentuk yang sempurna dan tidak pernah digambar tetap hijau selamanya --
# kelas cacat yang sama dengan setengah-lebar spike yang hilang hanya di
# sisi view.
#
# Yang diperiksa adalah **pemanggilan bersyarat**, bukan sekadar keberadaan
# nama fungsi: `drawCandidateMarker(...)` tanpa `!isConfirmed` akan
# menggambar lencana ragu pada objek yang **sudah** terkunci, yaitu
# kebohongan pada arah sebaliknya. Karena itu syaratnya diikat.
echo
echo "== Aturan 32: lencana 'engine ragu' digambar tepat saat belum pasti =="
ragu=$(python3 - <<'PY' 2>&1
import os, re

VIEW = "Apps/Shared/CelestialVisualView.swift"

if not os.path.exists(VIEW):
    print("PERINGATAN: %s tidak ada." % VIEW)
    raise SystemExit

text = open(VIEW, encoding="utf-8").read()
# Kode saja: komentar di berkas ini menceritakan cacat lamanya, dan pola
# `if !isConfirmed` yang **dikomentari** tidak boleh terbaca sebagai
# kenyataan.
code = re.sub(r"//[^\n]*", "", text)
code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)

problems = []

# 1. Lencana harus dipanggil, dan **bersyarat** pada ketidakpastian.
#
#    Dicari sebagai `if <syarat> { … drawCandidateMarker( … ) }`, dengan
#    tubuhnya digabung dulu supaya komentar di antaranya tidak memengaruhi
#    pencocokan. Syaratnya harus memuat `isConfirmed` dalam bentuk negatif
#    (`!isConfirmed`, `isConfirmed == false`), kalau tidak lencana akan
#    tampil pada objek yang sudah terkunci.
body = re.sub(r"\s+", " ", code)
calls = re.findall(
    r"if\s+([^{;]{0,120}?)\s*\{[^{}]*?drawCandidateMarker\s*\(", body)
if not calls:
    problems.append(
        "  `drawCandidateMarker` tidak dipanggil di bawah `if` mana pun di %s; "
        "kandidat yang belum terkunci digambar tanpa penanda keraguan" % VIEW)
for cond in calls:
    if not re.search(r"!\s*isConfirmed|isConfirmed\s*==\s*false", cond):
        problems.append(
            "  `drawCandidateMarker` dipanggil dengan syarat `%s`; lencana ragu "
            "harus bergantung pada `!isConfirmed`, kalau tidak ia tampil pada "
            "objek yang sudah terkunci" % cond.strip())

# 2. Cincin Saturnus tidak boleh digambar pada kandidat yang belum pasti.
#
#    Ini arah sebaliknya dari pemeriksaan 1, dan tanpa itu cacatnya bisa
#    diselesaikan dengan menggambar lencana ragu **di atas** cincin:
#    penanda ada, tetapi ciri pengenalnya sudah telanjur tampil. Syaratnya
#    harus memuat `isConfirmed` **dan** `feature == .rings` bersamaan --
#    hanya salah satu membuat bola Saturnus hilang (atau cincin bocor ke
#    kandidat) tanpa terdeteksi.
sphere = re.search(
    r"if\s+([^{;]{0,160}?)\s*\{\s*drawSphere\s*\(", body)
if sphere:
    cond = sphere.group(1)
    if "isConfirmed" not in cond or "feature" not in cond:
        problems.append(
            "  `drawSphere` digambar dengan syarat `%s`; cincin Saturnus harus "
            "dilewat saat `isConfirmed` salah **dan** cirinya `.rings`, kalau "
            "tidak cincin (ciri pengenal) bocor ke kandidat yang belum pasti"
            % cond.strip())
else:
    problems.append(
        "  `drawSphere` tidak ditemukan di bawah `if` di %s; gerbang ini "
        "kehilangan gigi pada sisi cincin" % VIEW)

print("\n".join(problems) if problems else "")
PY
)
if printf '%s' "$ragu" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 32 gagal dijalankan:"
  echo "$ragu"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$ragu" ]; then
  echo "Penanda keraguan tidak lagi digambar dengan benar:"
  echo "$ragu"
  echo "-> Tanpa lencana, gambar kandidat terbaca sebagai identitas pasti;"
  echo "   tanpa penjaga cincin, ciri pengenal bocor ke kandidat."
  status=1
else
  echo "Bersih: lencana ragu digambar tepat saat engine belum pasti."
fi

# ── Aturan 33: bobot putusan GoTo harus datang dari putusannya ─────────────
#
# `SlewVerdictBanner` punya dua baris yang menentukan apakah dua kelas bahaya
# **terlihat berbeda**:
#
#   `Image(systemName: decision.verdictSymbolName)`   ikon
#   `let tone = decision.verdictTone`                 warna
#
# Keduanya ada karena versi pertama banner ini menulis ikon dan warna
# **langsung di view**: `exclamationmark.triangle.fill` untuk semua penolakan,
# warna peringatan untuk semua penolakan. Akibatnya `sunProximity` (melindungi
# peralatan dan **mata** dari cahaya Matahari) dan `lowConfidence` (soal
# ketelitian) tergambar dengan bobot yang sama, dan pengguna yang membaca
# sekilas menyimpulkan keduanya sama mendesaknya. Docstring
# `SlewVerdict.verdictTone` menyebut versi itu sebagai cacatnya.
#
# **Kenapa gerbang ini harus ada: cacat itu terbukti tak terlihat.** Kedua
# baris dikembalikan ke bentuk lamanya (ikon tetap `exclamationmark.triangle
# .fill`, nada tetap `PointingTone.warning`), lalu dijalankan: seluruh 32
# aturan UI lulus, `./swift-typecheck.sh` lulus (exit 0), dan `./swift-test.sh`
# melaporkan **755 uji, 0 gagal**. Jadi sampai aturan ini ada, memundurkan
# pemisahan bobot itu ke bentuk yang docstring-nya sendiri sebut salah tidak
# menghasilkan satu pun kegagalan.
#
# Kenapa uji Linux tidak bisa menolong: `SlewVerdictTests` menguji **nilai**
# `verdictTone`/`verdictSymbolName` (dan `testDangerAndWarningUseDifferentSymbols`
# memang menuntut keduanya berbeda), tetapi tidak ada satu pun uji yang
# menuntut **view membacanya**. Rumus yang benar dan tidak pernah dipakai
# tetap hijau selamanya -- kelas yang sama dengan setengah-lebar spike yang
# hilang hanya di sisi view.
#
# **Batasnya, dinyatakan di sini supaya tidak salah tuduh.**
# `ReducedLuminanceView` juga menulis `exclamationmark.triangle.fill` sebagai
# literal, dan itu **bukan** cacat: layar redup hanya pernah menampilkan
# `safetyWarningText`, yang `nil` untuk seluruh kelas mutu, jadi di sana hanya
# ada satu kelas bahaya dan tidak ada yang perlu dibedakan. Aturan ini karena
# itu membaca **satu berkas**, bukan menyapu semua `Image(systemName:)` di
# `Apps/`.
echo
echo "== Aturan 33: bobot putusan GoTo datang dari putusannya =="
putusan_goto=$(python3 - <<'PY' 2>&1
import os, re

VIEW = "Apps/Shared/SlewVerdictBanner.swift"

if not os.path.exists(VIEW):
    print("PERINGATAN: %s tidak ada." % VIEW)
    raise SystemExit

text = open(VIEW, encoding="utf-8").read()
# Kode saja: docstring berkas ini menceritakan cacat lamanya, dan nama
# `verdictSymbolName` yang **dikutip di komentar** tidak boleh terbaca
# sebagai pemakaian.
code = re.sub(r"//[^\n]*", "", text)
code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)

problems = []

# 1. Ikon harus datang dari putusannya, bukan dari literal di view.
#
#    Diperiksa sebagai **argumen** `Image(systemName:)`, bukan sebagai
#    keberadaan nama: `verdictSymbolName` yang disebut di tempat lain (mis.
#    hanya dihitung lalu dibuang) tidak sampai ke layar.
icon = re.search(r"Image\s*\(\s*systemName\s*:\s*([^)]*)\)", code)
if not icon:
    problems.append(
        "  `Image(systemName:)` tidak ditemukan di %s; gerbang ini kehilangan "
        "subjeknya, jadi ia tidak mengukur apa pun" % VIEW)
else:
    arg = icon.group(1).strip()
    if not re.search(r"\bverdictSymbolName\b", arg):
        problems.append(
            "  ikon digambar dari `%s`, bukan `decision.verdictSymbolName`; "
            "ikon tetap membuat kelas keselamatan dan kelas mutu terlihat "
            "sama -- dan di Mode Malam ikon satu-satunya pembeda yang "
            "tersisa, karena seluruh palet nada menyempit jadi satu merah"
            % arg[:60])

# 2. Nada harus datang dari putusannya.
if not re.search(r"\bdecision\s*\.\s*verdictTone\b", code):
    problems.append(
        "  `decision.verdictTone` tidak dipakai di %s; warna peringatan yang "
        "tetap menyamakan \"terlalu dekat Matahari\" dengan \"terlalu redup\""
        % VIEW)

# 3. Dan nada itu harus benar-benar **dipakai** untuk menggambar.
#
#    Arah ketiga, dan tanpa itu cacat nomor 2 bisa \"diselesaikan\" dengan
#    menghitung nadanya lalu tetap menggambar warna tetap: nilainya ada,
#    layarnya tidak berubah.
paint = re.search(r"foregroundStyle\s*\(\s*([^)]*)\)", code)
if not paint:
    problems.append(
        "  `foregroundStyle(...)` tidak ditemukan di %s; tidak ada yang "
        "membuktikan nada putusan itu sampai ke warna yang digambar" % VIEW)
elif not re.search(r"\btone\b", paint.group(1)):
    problems.append(
        "  warna digambar dari `%s`, bukan dari nada putusan yang sudah "
        "dihitung; nadanya dihitung lalu dibuang"
        % paint.group(1).strip()[:60])

print("\n".join(problems) if problems else "")
PY
)
if printf '%s' "$putusan_goto" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 33 gagal dijalankan:"
  echo "$putusan_goto"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$putusan_goto" ]; then
  echo "Bobot putusan GoTo tidak lagi datang dari putusannya:"
  echo "$putusan_goto"
  echo "-> Ambil ikon dari decision.verdictSymbolName dan warna dari"
  echo "   decision.verdictTone; dua kelas bahaya harus terlihat berbeda,"
  echo "   terutama di Mode Malam tempat warna berhenti membedakan."
  status=1
else
  echo "Bersih: bobot putusan GoTo datang dari putusannya."
fi

# ── Aturan 34: penjaga identitas harus menerima keyakinan engine ─────────────
#
# Model `PointingKit` punya beberapa aksesor yang **sengaja** menerima
# `isConfirmed:` supaya bisa menolak mengklaim identitas saat engine ragu:
#
#     CelestialVisual.drawableStarColorIndex(_:isConfirmed:)   warna bintang
#     DeepSkyCatalogue.drawableMorphology(forObjectID:isConfirmed:)  bentuk kabut
#     Palette.drawable(isConfirmed:)                           palet planet
#     spokenStarColor(isConfirmed:)                            suara warna
#     spokenPhase(isConfirmed:)                                suara fase
#     spokenDeepSkyMorphology(isConfirmed:)                    suara morfologi
#
# Parameternya ada, rumusnya benar, dan **masing-masing punya uji Swift**.
# Yang tidak dijaga siapa pun adalah **nilai yang dikirim dari `Apps/`**:
# seluruh berkas di `Apps/` berada di luar jangkauan `swift-test.sh` (Linux
# hanya membangun `Packages/`), dan `Tools/check-visuals.py` merender **port
# Python**-nya, bukan view Swift-nya. Jadi satu-satunya berkas yang bisa
# salah adalah berkas yang tidak diperiksa kedua-duanya.
#
# **Cacat yang ditutup aturan ini, dan itu diukur bukan dikira-kira.**
# `isConfirmed: isConfirmed` di `CelestialVisualView.swift` diganti
# `isConfirmed: true` — satu kata, satu tempat, tepat di kawat yang memutuskan
# apakah bentuk/bentuk/warna objek langit dalam boleh diklaim:
#
#     isConfirmed: true   ->  swift-ui-lint.sh  LULUS (exit 0)
#                             swift-typecheck.sh LULUS (exit 0)
#                             755 uji PointingKit hijau
#
# Artinya memaksa **klaim identitas** pada jalur objek langit dalam tidak
# menghasilkan satu pun kegagalan, walaupun PRD menyebut larangan itu sebagai
# aturan paling keras ("JANGAN salah identifikasi demi magic", "uncertainty >
# false confidence"). Ini kelas cacat yang sama dengan Aturan 24 dan 31:
# rumus benar, pengawat salah, dan pengawatnya tidak diperiksa apa pun.
#
# **Kenapa daftar aksesornya dibaca dari model, bukan ditulis di sini.**
# Menyalin keenam nama ke dalam aturan ini membuat salinan kedua yang bisa
# berbeda diam-diam dari model: aksesor ketujuh yang lahir besok akan lolos
# hanya karena namanya tidak ada di daftar. Aturan ini mencari sendiri
# deklarasi yang punya parameter `isConfirmed:` di `Packages/PointingKit`,
# lalu menuntut setiap pemanggilannya di `Apps/` mengirim **sesuatu selain
# literal `true`/`false`**.
#
# **Kenapa literalnya dilarang, bukan "harus `isConfirmed:`".** Ada pemakaian
# literal yang sah dan tidak boleh memerah: `OnboardingView` memakai
# `isConfirmed: true` pada `CelestialVisualView` (struktur view, bukan
# aksesor model) untuk ilustrasi statis yang memang bukan hasil pengukuran,
# dan `#Preview` complication memakai literal untuk data contoh. Keduanya
# **bukan** pemanggilan aksesor model, jadi keduanya tidak masuk daftar.
# Yang dilarang sempit: mengirim literal ke aksesor yang parameternya ada
# justru supaya keyakinan bisa ditolak.
echo
echo "== Aturan 34: penjaga identitas menerima keyakinan engine, bukan literal =="
penjaga_identitas=$(python3 - <<'PY' 2>&1
import os, re

PK = os.path.join("Packages", "PointingKit", "Sources", "PointingKit")
if not os.path.isdir(PK):
    print("Tidak bisa membaca %s -- aturan ini tidak bisa memutuskan." % PK)
    raise SystemExit(0)

# 1. Aksesor model yang menerima `isConfirmed:`.
aksesor = set()
for root, _, files in os.walk(PK):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        text = open(os.path.join(root, name), encoding="utf-8").read()
        # Komentar dibuang dulu: beberapa berkas mendokumentasikan bentuk
        # `isConfirmed:` sebagai contoh, dan contoh tidak boleh terbaca
        # sebagai deklarasi.
        code = "\n".join(l.split("//", 1)[0] for l in text.split("\n"))
        datar = re.sub(r"\s+", " ", code)
        for m in re.finditer(
                r"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)", datar):
            if re.search(r"\bisConfirmed\s*:", m.group(2)):
                aksesor.add(m.group(1))

if not aksesor:
    print("Tidak ada aksesor model ber-`isConfirmed:` yang ditemukan; "
          "aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)


def kode_saja(teks):
    """Buang komentar dan isi string literal."""
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam_str, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam_str = False
            else:
                if ch == '"':
                    dalam_str = True
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
            buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


masalah = []
diperiksa = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = kode_saja(open(path, encoding="utf-8").read())
        for fn in sorted(aksesor):
            for m in re.finditer(re.escape(fn) + r"\s*\(", kode):
                # Ambil daftar argumen dengan kurung berimbang: panggilan bisa
                # membungkus beberapa baris, jadi mencari sampai `)` pertama
                # akan memotong argumennya.
                i, depth = m.end(), 1
                mulai = i
                while i < len(kode) and depth:
                    if kode[i] == "(":
                        depth += 1
                    elif kode[i] == ")":
                        depth -= 1
                    i += 1
                args = kode[mulai:i - 1]
                if not re.search(r"\bisConfirmed\s*:", args):
                    continue
                diperiksa += 1
                nilai = re.search(r"\bisConfirmed\s*:\s*([^,\)]+)", args)
                if nilai and re.match(r"^\s*(true|false)\s*$", nilai.group(1)):
                    baris = kode[:m.start()].count("\n") + 1
                    masalah.append(
                        "  %s:%d: `%s(isConfirmed: %s)` -- keyakinan engine "
                        "diganti literal, jadi identitas diklaim saat ragu"
                        % (path, baris, fn, nilai.group(1).strip()))

# 2. Arah fase: kelas yang sama, argumen yang berbeda.
#
#    `phaseGeometry(waxing:)` mengembalikan `nil` bila arahnya `nil`, dan
#    `nil` berarti \"jangan menggambar fase\". Mengirim `true`/`false` di
#    tempatnya berarti **memilih sisi** untuk benda yang arahnya tidak
#    diketahui engine -- persis larangan PRD yang sama, karena sisi terang
#    adalah ciri pengenal: sabit yang menghadap ke arah salah menyatakan
#    \"ini bulan sabit awal\" saat engine hanya tahu \"ada sabit\".
#    Modelnya sendiri menyebutnya: `waxing: Bool?` -- \"`nil` menghasilkan
#    `nil`: tanpa arah, gambar apa pun yang digambar akan memihak ke satu
#    sisi, dan itu pernyataan yang tidak dihitung engine\".
#
#    Diukur sebelum bagian ini ada: `waxing: visual.isWaxing` di
#    CelestialVisualView.swift diganti `waxing: true` (dua situs), lalu
#    lint LULUS (exit 0) dan typecheck LULUS (exit 0).
#
#    Kenapa tidak masuk bagian 1: daftar aksesornya dibaca dari deklarasi
#    ber-`isConfirmed:`, dan `phaseGeometry` tidak punya parameter itu --
#    aturan yang hanya mencari `isConfirmed:` akan melewatkannya sepenuhnya.
masalah_fase = []
diperiksa_fase = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = kode_saja(open(path, encoding="utf-8").read())
        for m in re.finditer(r"\bphaseGeometry\s*\(", kode):
            i, depth, mulai = m.end(), 1, m.end()
            while i < len(kode) and depth:
                if kode[i] == "(":
                    depth += 1
                elif kode[i] == ")":
                    depth -= 1
                i += 1
            args = kode[mulai:i - 1]
            nilai = re.search(r"\bwaxing\s*:\s*([^,\)]+)", args)
            if not nilai:
                continue
            diperiksa_fase += 1
            if re.match(r"^\s*(true|false)\s*$", nilai.group(1)):
                baris = kode[:m.start()].count("\n") + 1
                masalah_fase.append(
                    "  %s:%d: `phaseGeometry(waxing: %s)` -- arah fase "
                    "diganti literal, jadi sisi terang dipilih untuk benda "
                    "yang arahnya tidak diketahui engine"
                    % (path, baris, nilai.group(1).strip()))

if diperiksa == 0 and diperiksa_fase == 0:
    print("Tidak ada pemanggilan aksesor identitas di Apps/; aturan ini "
          "tidak mengukur apa pun.")
elif masalah or masalah_fase:
    print("\n".join(masalah + masalah_fase))
    if masalah:
        print("-> Salurkan `engine.confirmsDisplayedIdentity` (atau "
              "`isConfirmed` yang sudah diturunkan darinya), bukan literal: "
              "`true` membuat gambar lebih yakin daripada teksnya.")
    if masalah_fase:
        print("-> Salurkan `visual.isWaxing` (opsional) apa adanya, bukan "
              "literal: `nil` berarti \"jangan pilih sisi\", dan sisi terang "
              "adalah ciri pengenal.")
PY
)
if printf '%s' "$penjaga_identitas" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 34 gagal dijalankan:"
  echo "$penjaga_identitas"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$penjaga_identitas" ]; then
  echo "$penjaga_identitas"
  status=1
else
  echo "Bersih: penjaga identitas menerima keyakinan engine."
fi

# ── Aturan 35: fakta yang dibaca berkasnya tidak boleh ditulis sebagai literal ─
#
# Kelas cacat yang ditutupnya, dan ini **diukur**, bukan dikira-kira.
#
# `PointingView.swift` menampilkan status tautan ke iPhone di dua kanal
# sekaligus, dan keduanya membaca satu fakta yang sama:
#
#     `link.isReachable ? "iphone.gen3.radiowaves…" : "iphone.slash"`  ikon
#     `LinkStatusText.linkSpeech(isReachable: …)`                       suara
#
# Diukur: argumen `linkSpeech` diganti `link.isReachable` -> `true` (satu
# kata, satu tempat). Lalu seluruh berkas ini dijalankan **dengan** cacat itu
# di pohon: `swift-ui-lint.sh` LULUS (exit 0), `swift-typecheck.sh` LULUS
# (exit 0), `./swift-test.sh` 755 uji hijau. Jadi membuat ikon berkata
# "iPhone tidak terjangkau" sementara VoiceOver membacakan "iPhone terhubung"
# tidak menghasilkan satu pun kegagalan.
#
# Kenapa Aturan 34 tidak menangkapnya: daftar aksesornya dibaca dari
# deklarasi ber-parameter `isConfirmed:` — dan `linkSpeech` menerima
# `isReachable`. Cacatnya bukan pada keyakinan identitas, melainkan pada
# **satu berkas yang bertentangan dengan dirinya sendiri**: satu kanal
# menyatakan fakta, kanal lain menulisnya sebagai tetapan. Karena itu aturan
# ini tidak memakai daftar nama, melainkan prinsipnya:
#
#     berkas yang **membaca** `.p` dari sebuah penerima tidak boleh
#     mengirim literal `true`/`false` untuk parameter `p` di berkas itu.
#
# Aksesornya dicari dari model (setiap `func` PointingKit yang punya
# parameter Bool), bukan disalin ke sini — aksesor yang lahir besok ikut
# terjaga tanpa menyunting aturan ini.
#
# **Kenapa "kontradiksi di berkas yang sama", bukan "literal dilarang".**
# Ada literal yang sah dan tidak boleh memerah: `setSensorAvailable(false)`
# di `MotionLogger` adalah **perintah** ("hentikan sensor"), bukan klaim
# tentang keadaan, dan berkasnya tidak membaca `.available` sama sekali.
# `color(raw, isShadow: true)` meminta cakram bayangan — bukan aksesor model.
# Yang dilarang sempit: fakta yang **sudah dibaca** berkas itu lalu diganti
# tetapan di kanal lain, karena di situlah layar dan suara bisa berbeda.
#
# **Yang TIDAK diklaim aturan ini.** Ia sapu teks: ia tidak tahu tipe, tidak
# tahu apakah `p` benar-benar parameter aksesor yang dipanggil (nama
# parameter yang kebetulan sama sudah cukup untuk memerah), dan ia tidak
# melihat blok komentar `/* */` (hanya `//`). Batas itu sama dengan Aturan 34,
# dan disebut di sini supaya "hijau" tidak dibaca lebih luas daripada yang
# benar-benar diukur.
#
# ── Perluasan siklus ini: fakta yang **namanya berbeda** ────────────────────
#
# Kelas cacat kedua, dan diukur sebelum diperluas:
#
#     Apps/PointAndKnowWatch/Sources/ReducedLuminanceView.swift
#         isStale:       engine.isDisplayingStaleObject
#         safetyWarning: engine.slewVerdict?.safetyWarningText
#         sensorNote:    motionNote   (-> engine.sensorNote)
#
# Ketiganya diganti literal (`false`, `nil`, `nil`) -> `swift-ui-lint.sh`
# **LULUS (exit 0)**. Artinya keempat salinan fakta di layar Always-On bisa
# dijadikan tetapan, dan tidak satu pun gerbang berbunyi.
#
# Kenapa aturan versi lama melewatkannya: `dibaca` mencocokkan nama parameter
# **persis**. Di sini nama parameternya memang sengaja berbeda dari nama
# faktanya -- `isStale` adalah kata yang dipakai label, sedangkan
# `isDisplayingStaleObject` adalah fakta yang dimilikinya. Nama yang sama persis
# bukan syarat yang benar untuk kelas ini.
#
# Yang diperluas, dan batasnya yang diukur:
#   * Parameter model dikumpulkan dari tipe `Bool` **dan** `String?`; hanya
#     `Bool` membuat `safetyWarning:`/`sensorNote:` tidak pernah terdaftar.
#   * Sumber fakta dicari dengan **kata camelCase berurutan di awal nama**
#     (`safetyWarning` -> `safetyWarningText`, kata isi `stale` ->
#     `isDisplayingStaleObject`). Percobaan pertama memakai substring biasa,
#     dan itu **memerahkan kode benar**: `title`, `value`, `name`, `label`
#     tercatat punya sumber di hampir setiap berkas.
#   * Sumber yang **tidak diawali** tidak dihitung. Diukur: `objectName` ->
#     `reportedObjectName` membuat `record(objectName: nil)` -- nilai yang sah,
#     "tidak ada objek" -- ditandai sebagai fakta yang disembunyikan.
#   * Nama yang sama persis tetap dihitung sebagai sumber bila dibaca lewat
#     **properti perantara** (`var motionNote { engine.sensorNote }`), karena
#     itulah jalur yang dipakai layar redup.
#
# Arah sebaliknya tetap dijaga `bukti-mutasi-fakta-literal.py` keadaan 4, 5,
# dan 7: literal yang sah (ilustrasi statis, perintah sensor, parameter yang
# berkasnya tidak punya sumbernya) harus tetap hijau.
echo
echo "== Aturan 35: fakta Bool yang dibaca berkasnya tidak diganti literal =="
kontradiksi_literal=$(python3 - <<'PY' 2>&1
import os, re

PK = os.path.join("Packages", "PointingKit", "Sources", "PointingKit")
if not os.path.isdir(PK):
    print("Tidak bisa membaca %s -- aturan ini tidak bisa memutuskan." % PK)
    raise SystemExit(0)


def kode_saja(teks):
    """Buang komentar `//` dan isi string literal."""
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam_str, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam_str = False
            else:
                if ch == '"':
                    dalam_str = True
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
            buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


def argumen(kode, buka):
    """Daftar argumen dari kurung **berimbang** mulai di indeks `(`.

    Mencari sampai `)` pertama akan memotong argumen yang isinya kurung
    (mis. nilai bawaan atau pemanggilan bersarang).
    """
    i, depth = buka + 1, 1
    while i < len(kode) and depth:
        if kode[i] == "(":
            depth += 1
        elif kode[i] == ")":
            depth -= 1
        i += 1
    return kode[buka + 1:i - 1]


# 1. Deklarasi: setiap `func` PointingKit yang punya parameter Bool.
aksesor = {}
for root, _, files in os.walk(PK):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        kode = kode_saja(open(os.path.join(root, name), encoding="utf-8").read())
        datar = re.sub(r"\s+", " ", kode)
        for m in re.finditer(r"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", datar):
            params = argumen(datar, m.end() - 1)
            # `Bool` **dan** `String?`/`Bool?` opsional: fakta opsional adalah
            # fakta. Diukur pada keadaan 6b/6c `bukti-mutasi-fakta-literal.py`:
            # dengan hanya `Bool` didaftarkan, `safetyWarning:`
            # (`String?`) dan `sensorNote:` (`String?`) tidak pernah dibaca
            # sebagai parameter, sehingga `nil` yang menggantikannya tidak
            # diperiksa apa pun. `Bool?` sudah ikut lewat awalan `Bool`.
            bools = re.findall(
                r"\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?:Bool|String)\??\b", params)
            if bools:
                aksesor.setdefault(m.group(1), set()).update(bools)

if not aksesor:
    print("Tidak ada aksesor model ber-parameter Bool/String ditemukan; "
          "aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

# 2. Per berkas `Apps/`: fakta Bool yang **dibaca** dari sebuah penerima,
#    lalu pemanggilan aksesor yang mengirim literal untuk fakta itu.
#
#    Pembacaan diperiksa dalam **tiga** bentuk, dan yang ketiga bukan
#    kelengkapan: konvensi Swift membuang awalan `is`/`has` dari label
#    argumen, jadi `phaseGeometry(waxing:)` dipanggil dengan
#    `visual.isWaxing`. Terukur: tanpa perluasan ini, argumen `waxing:`
#    diganti literal **hijau** -- keadaan 2 `bukti-mutasi-fakta-literal.py`
#    merah pada aturannya sendiri, dan aturan yang melewatkan seluruh
#    keluarga aksesor `is`-berawalan akan menjaga jauh lebih sedikit daripada
#    yang tampak dari namanya. Bentuk `.is<Param>`/`.has<Param>` juga yang
#    menangkap `setSensorAvailable(available:)` lewat `motion.isAvailable`.
masalah = []
diperiksa = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = kode_saja(open(path, encoding="utf-8").read())

        dibaca = set()
        for prm in {p for ps in aksesor.values() for p in ps}:
            b = prm[0].upper() + prm[1:]
            for bentuk in (".%s" % prm, ".is%s" % b, ".has%s" % b):
                if re.search(re.escape(bentuk) + r"\b", kode):
                    dibaca.add(prm)
                    break

        # 2b. Fakta yang **dibaca berkas ini** tetapi namanya tidak sama
        #     dengan nama parameternya.
        #
        #     Inilah yang dijaga keadaan 6 `bukti-mutasi-fakta-literal.py`, dan
        #     diukur sebelum perluasan ini: layar redup mengirim
        #
        #         isStale:       engine.isDisplayingStaleObject
        #         safetyWarning: engine.slewVerdict?.safetyWarningText
        #         sensorNote:    motionNote  (properti -> engine.sensorNote)
        #
        #     Ketiganya diganti literal, dan `swift-ui-lint.sh` LULUS. Sebabnya
        #     `dibaca` di atas hanya mencocokkan nama parameter persis, sedang
        #     di sini nama parameternya memang sengaja berbeda: `isStale` adalah
        #     kata yang dipakai label, `isDisplayingStaleObject` adalah fakta
        #     yang dimilikinya.
        #
        #     Cara mencocokkannya tanpa daftar tangan: nama parameter dipotong
        #     jadi kata isi (buang awalan `is`/`has`), lalu setiap anggota di
        #     berkas yang memuat kata itu sebagai **kata utuh dalam camelCase**
        #     dianggap sumber faktanya. `isDisplayingStaleObject` memuat kata
        #     `Stale`; `safetyWarningText` memuat `safety` + `Warning`.
        #
        #     **Kenapa camelCase, bukan substring.** Diukur: pencocokan
        #     substring membuat `title`, `value`, `name`, dan `label` ikut
        #     tercatat punya "sumber" di hampir setiap berkas (karena `.label`,
        #     `.localizedName`, `.rowTitle` ada di mana-mana). Itu arah yang
        #     memerahkan kode benar, dan gerbang yang menuduh kode benar akan
        #     dilonggarkan orang. Dengan batas kata camelCase, `safetyWarning`
        #     hanya cocok dengan `.safetyWarningText`, bukan dengan `.title`.
        #
        #     **Kenapa kata isi, bukan awalan `is`/`has` saja.** `safetyWarning`
        #     dan `sensorNote` bukan aksesor `is`-berawalan; perluasan yang
        #     hanya menangani awalan itu akan hijau pada 6b/6c.
        #
        #     **Kenapa pencocokan boleh gagal tanpa memerah.** Bentuk ini
        #     menjaga arah sebaliknya (keadaan 7): `waxing: true` di berkas yang
        #     tidak membaca sumber apa pun tidak punya kata yang cocok, jadi
        #     tidak memerah.
        def kata_isi(prm):
            return re.sub(r"^(is|has)(?=[A-Z])", "", prm)

        def kata_dari(nama):
            """Pecah nama camelCase menjadi kata huruf kecil.

            `isDisplayingStaleObject` -> kata is: is, displaying, stale, object.

            Pencocokan per kata, bukan substring: `stale` cocok dengan
            `...Stale...` dan `safetyWarning` cocok dengan
            `safetyWarningText` (awalan dua kata), tetapi `title` tidak cocok
            dengan `.rowTitleNote` yang tidak ada hubungannya. Substring polos
            (percobaan pertama) membuat `title`, `value`, `name`, `label`
            tercatat punya sumber di hampir setiap berkas -- arah yang
            memerahkan kode benar.
            """
            hasil = []
            for bagian in re.split(r"[^A-Za-z0-9]+", nama):
                if not bagian:
                    continue
                hasil.extend(w.lower() for w in
                             re.findall(r"[A-Z]+(?![a-z])|[A-Z]?[a-z0-9]+",
                                        bagian))
            return hasil

        def memuat_kata(nama, kata):
            """`nama` **diawali** seluruh kata `kata`.

            Diawali, bukan sekadar memuat: `safetyWarning` -> `safetyWarningText`
            cocok (awalan), `isStale` -> `isDisplayingStaleObject` cocok lewat
            kata isi `stale`... tetapi `objectName` -> `reportedObjectName`
            **tidak** cocok, karena di sana `objectName` adalah kata *belakang*
            dari nama yang berbeda maknanya.

            Diukur: dengan pencocokan "memuat" biasa, keadaan 3
            `bukti-mutasi-fakta-literal.py` memunculkan pemeriksaan palsu
            `record(objectName: nil)` -- `nil` untuk `objectName` adalah nilai
            sah ("tidak ada objek"), bukan fakta yang disembunyikan, dan
            pemanggil sah itu memerahkan gerbangnya sendiri.
            """
            butuh = kata_dari(kata)
            punya = kata_dari(nama)
            return bool(butuh) and punya[:len(butuh)] == butuh

        anggota = {m.group(1)
                   for m in re.finditer(r"\.([A-Za-z_][A-Za-z0-9_]*)\b", kode)}
        # Anggota yang dibaca di dalam badan properti **lain** (bukan langsung
        # sebagai argumen). `sensorNote: motionNote` di mana
        # `var motionNote { engine.sensorNote }` termasuk di sini; `objectName:`
        # yang dibaca langsung di argumen tidak -- dan `nil` untuk `objectName`
        # adalah nilai sah, bukan fakta yang disembunyikan.
        dalam_properti = set()
        for m in re.finditer(
                r"\bvar\s+([a-z][A-Za-z0-9_]*)\b[^\n{]*\{([^}]*)\}", kode):
            for a in re.finditer(r"\.([A-Za-z_][A-Za-z0-9_]*)\b", m.group(2)):
                dalam_properti.add((m.group(1), a.group(1)))
        sumber = {}
        for prm in {p for ps in aksesor.values() for p in ps}:
            kata = kata_isi(prm)
            if len(kata) < 4:
                continue
            calon = {a for a in anggota
                     if memuat_kata(a, kata) and a != prm}
            # Buang dirinya sendiri: `.isStale` bukan bukti fakta berbeda.
            calon.discard("is" + kata[0].upper() + kata[1:])
            calon.discard("has" + kata[0].upper() + kata[1:])
            # Nama yang sama persis tetap sumber bila dibaca lewat properti
            # perantara: itulah jalur `sensorNote: motionNote`.
            if any(a == prm for _, a in dalam_properti):
                calon.add(prm)
            if calon:
                sumber[prm] = sorted(calon)

        if not dibaca and not sumber:
            continue

        for fn, params in sorted(aksesor.items()):
            for m in re.finditer(
                    r"(?<![A-Za-z0-9_])" + re.escape(fn) + r"\s*\(", kode):
                args = argumen(kode, m.end() - 1)
                for prm in sorted(params):
                    if prm not in dibaca and prm not in sumber:
                        continue
                    nilai = re.search(r"\b" + prm + r"\s*:\s*([^,)]+)", args)
                    if not nilai:
                        continue
                    diperiksa += 1
                    if re.match(r"^\s*(true|false)\s*$", nilai.group(1)):
                        baris = kode[:m.start()].count("\n") + 1
                        masalah.append(
                            "  %s:%d: `%s(%s: %s)` -- berkas ini juga membaca "
                            "`.%s`, jadi faktanya tersedia dan diganti literal"
                            % (path, baris, fn, prm,
                               nilai.group(1).strip(),
                               prm if prm in dibaca
                               else "/.".join(sumber[prm])))
                    # 2c. String? yang dibaca berkas itu, lalu diganti `nil`.
                    elif (prm in sumber
                          and re.match(r"^\s*nil\s*$", nilai.group(1))):
                        baris = kode[:m.start()].count("\n") + 1
                        masalah.append(
                            "  %s:%d: `%s(%s: nil)` -- berkas ini membaca "
                            "`.%s`, jadi faktanya tersedia dan diganti `nil`"
                            % (path, baris, fn, prm,
                               "/.".join(sumber[prm])))
                    # 2c-opsional. Fakta opsional yang dibaca berkas itu lewat
                    #      properti perantara, lalu diganti `nil`:
                    #      `sensorNote: nil` sementara `motionNote` membacakan
                    #      `engine.sensorNote`. Inilah bentuk yang paling sunyi
                    #      di layar redup: catatan "sensor tidak tersedia"
                    #      hilang, dan layar yang membeku terbaca sebagai
                    #      keberhasilan.
                    #
                    #      Sengaja **hanya** untuk `nil`: `nil` adalah nilai sah
                    #      untuk banyak parameter opsional (`objectName: nil`),
                    #      jadi cabang ini menuntut bukti bahwa faktanya memang
                    #      dibaca berkas ini lewat sebuah properti.
                    elif (re.match(r"^\s*nil\s*$", nilai.group(1))
                          and prm in sumber):
                        baris = kode[:m.start()].count("\n") + 1
                        masalah.append(
                            "  %s:%d: `%s(%s: nil)` -- berkas ini membaca "
                            "faktanya (`%s`), jadi faktanya tersedia dan "
                            "diganti `nil`"
                            % (path, baris, fn, prm,
                               ".".join(sumber[prm])))
                    # 2d. Fakta lewat **properti perantara**: argumennya nama
                    #     properti lokal (`sensorNote: motionNote`), dan badan
                    #     properti itu yang membaca faktanya
                    #     (`private var motionNote: String? { engine.sensorNote }`).
                    #     Tanpa jalur ini, keadaan 6c hijau: nama argumennya
                    #     tidak sama dengan nama apa pun di model.
                    elif prm in sumber:
                        lewat = re.match(r"^\s*([a-z][A-Za-z0-9_]*)\s*$",
                                         nilai.group(1))
                        if not lewat or lewat.group(1) == prm:
                            continue
                        badan = re.search(
                            r"\bvar\s+" + lewat.group(1)
                            + r"\b[^=\n]*=\s*\{?\s*([^\n}]*)",
                            kode)
                        if not badan:
                            continue
                        kata = re.sub(r"^(is|has)", "",
                                      prm if prm in dibaca else "")
                        if not kata:
                            continue
                        if not any(k.lower() in badan.group(1).lower()
                                   for k in [kata] + sumber.get(prm, [])):
                            continue
                        baris = kode[:m.start()].count("\n") + 1
                        masalah.append(
                            "  %s:%d: `%s(%s: %s)` -- `%s` membaca faktanya "
                            "(`%s`), jadi faktanya tersedia dan dialirkan "
                            "lewat nama lain"
                            % (path, baris, fn, prm, nilai.group(1).strip(),
                               lewat.group(1), badan.group(1).strip()[:60]))

if diperiksa == 0:
    print("Tidak ada pemanggilan aksesor Bool di Apps/; aturan ini tidak "
          "mengukur apa pun.")
elif masalah:
    print("\n".join(masalah))
    print("-> Salurkan fakta yang dibaca berkas itu (mis. `link.isReachable`), "
          "bukan literal: literal membuat satu kanal mengklaim hal yang "
          "dibantah kanal lain di layar yang sama.")
PY
)
if printf '%s' "$kontradiksi_literal" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 35 gagal dijalankan:"
  echo "$kontradiksi_literal"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$kontradiksi_literal" ]; then
  echo "$kontradiksi_literal"
  status=1
else
  echo "Bersih: fakta Bool yang dibaca berkasnya sampai apa adanya."
fi

# ── Aturan 36: penjaga identitas menerima faktornya, bukan kawan tunggal ──
#
# Kelas cacat yang ditutup, **diukur** bukan dikira-kira: Aturan 34 sudah
# melarang literal (`isConfirmed: true`), dan Aturan 24 sudah menuntut nama
# penjaga disebut. Terukur:
#
#     isConfirmed: !isConfirmed     ->  swift-ui-lint.sh  LULUS (exit 0)
#     isConfirmed: otherBool        ->  swift-ui-lint.sh  LULUS (exit 0)
#
# Keduanya **mengompilasi**, dan keduanya mematahkan larangan paling keras
# PRD — \"uncertainty > false confidence\" — dengan arah yang paling parah:
# bentuk inversi memaksa ciri pengenal tampil **tepat saat engine ragu**, dan
# nama lain memakainya dari fakta yang tidak ada hubungannya. Yang terbaca di
# layar tetap sama: bintang tetap berwarna Betelgeuse, galaksi tetap
# berpaluk, badge di sebelahnya tetap bertuliskan \"Ragu\". Gambar lebih yakin
# daripada teksnya, dan **kedua aturan yang ada untuk itu diam**.
#
# Kenapa Aturan 34 tidak menangkapnya: ia hanya menguji `nilai` **bukan**
# `true`/`false`. Semua ekspresi non-literal lolos, entah benar entah tidak.
#
# Kenapa Aturan 24 tidak menangkapnya: ia menguji **substring** — nama
# `drawableStarColorIndex` ada dan `isConfirmed` ada di dalam daftar
# argumen, jadi ia melaporkan \"Bersih\". Warnanya sendiri justru yang paling
# mahal: warna spektral adalah ciri pengenal, dan satu-satunya yang
# memutuskan boleh-tidak-nya tampil adalah argumen ini.
#
# **Batasnya dinyatakan, bukan disangka tertutup.** Yang boleh: nama penjaga
# yang diteruskan apa adanya (`isConfirmed` — bentuk yang dipakai seluruh
# sembilan situs panggilan hari ini), atau akses berkualifikasi yang
# **bertumpu** pada fakta yang sama (`engine.confirmsDisplayedIdentity`,
# `object.isConfirmed`, `snapshot.confirmsIdentity`). Yang HARUS merah:
# negasi (`!isConfirmed`, `!` di awal ekspresi) dan nama yang bukan fakta
# keyakinan (`showsCandidateMarker`, `isStale`, `link.isReachable`, …).
#
# Yang TIDAK diklaim: ini sapu teks, bukan pemeriksa tipe. Ia tidak tahu
# bahwa `otherBool` memang `Bool`, dan tidak tahu bahwa `otherBool` dan
# `isConfirmed` kebetulan punya nilai sama — keduanya tetap hijau.
echo
echo "== Aturan 36: penjaga identitas menerima faktornya, bukan kawan tunggal =="
penjaga_faktor=$(python3 - <<'PY' 2>&1
import os, re

PK = os.path.join("Packages", "PointingKit", "Sources", "PointingKit")
if not os.path.isdir(PK):
    print("Tidak bisa membaca %s -- aturan ini tidak bisa memutuskan." % PK)
    raise SystemExit(0)

aksesor = set()
for root, _, files in os.walk(PK):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        text = open(os.path.join(root, name), encoding="utf-8").read()
        code = "\n".join(l.split("//", 1)[0] for l in text.split("\n"))
        datar = re.sub(r"\s+", " ", code)
        for m in re.finditer(
                r"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)", datar):
            if re.search(r"\bisConfirmed\s*:", m.group(2)):
                aksesor.add(m.group(1))

if not aksesor:
    print("Tidak ada aksesor model ber-`isConfirmed:` yang ditemukan; "
          "aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)


def kode_saja(teks):
    """Buang komentar **dan isi** literal string.

    Kodinya dipakai aturan Aturan 7 dan 20 untuk kelas cacat yang sama, dan
    alasan mengosongkan -- bukan cuma menghapus tanda kutipnya -- diukur di
    sini: repo ini mendokumentasikan bentuk yang dilarang sebagai contoh di
    dalam `"..."` ("drawable(isConfirmed: !isConfirmed) itu dilarang"), dan
    isi yang dibiarkan hidup terbaca sebagai **pemanggilan**. Terukur: tanpa
    pengosongan, baris dokumentasi itu memerahkan aturan ini pada kode yang
    benar. Tanda kutipnya dipertahankan supaya pemotong komentar tidak mengubah
    makna baris yang tersisa.
    """
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam_str, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam_str:
                if esc:
                    esc = False
                    buf.append(" ")
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam_str = False
                    buf.append('"')
                else:
                    buf.append(" ")
            else:
                if ch == '"':
                    dalam_str = True
                    buf.append('"')
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


# Nama yang **boleh** berdiri di posisi penjaga. Akhiran yang sama dipakai
# modelnya sendiri (`confirmsDisplayedIdentity`, `confirmsIdentity`), jadi
# whitelist ini ikut arah model, bukan milik larangan ini.
NAMA_FAKTOR = re.compile(
    r"^(?:[A-Za-z_][A-Za-z0-9_]*\.)*(?:isConfirmed|confirmsIdentity|"
    r"confirmsDisplayedIdentity)$")

masalah = []
diperiksa = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = kode_saja(open(path, encoding="utf-8").read())
        for fn in sorted(aksesor):
            for m in re.finditer(re.escape(fn) + r"\s*\(", kode):
                i, depth, mulai = m.end(), 1, m.end()
                while i < len(kode) and depth:
                    if kode[i] == "(":
                        depth += 1
                    elif kode[i] == ")":
                        depth -= 1
                    i += 1
                args = kode[mulai:i - 1]
                nilai = re.search(r"\bisConfirmed\s*:\s*([^,\)]+)", args)
                if not nilai:
                    continue
                diperiksa += 1
                ekspresi = nilai.group(1).strip()
                # Negasi diperiksa lebih dulu: `!isConfirmed` memakai nama
                # yang **benar**, jadi daftar nama saja akan meloloskannya.
                if ekspresi.startswith("!"):
                    baris = kode[:m.start()].count("\n") + 1
                    masalah.append(
                        "  %s:%d: `%s(isConfirmed: %s)` -- penjaga "
                        "dibalik, jadi ciri pengenal dipaksa muncul saat "
                        "engine ragu" % (path, baris, fn, ekspresi))
                elif not NAMA_FAKTOR.match(ekspresi):
                    baris = kode[:m.start()].count("\n") + 1
                    masalah.append(
                        "  %s:%d: `%s(isConfirmed: %s)` -- penjaga bukan "
                        "fakta keyakinan engine, jadi identitas diklaim "
                        "atau dibungkam karena sebab yang lain"
                        % (path, baris, fn, ekspresi))

# ── Badan `confirmsDisplayedIdentity` sendiri harus meneruskan fakta ──────
#
# **Kenapa cabang ini ada, padahal pemanggilnya sudah diperiksa di atas.**
# Pemeriksaan di atas hanya melihat **argumen** yang dikirim pemanggil. Kalau
# badan properti ini menyimpang, seluruh pemanggil tetap mengirim nama yang
# benar — jadi aturan versi sebelumnya hijau sementara nilainya sudah bukan
# keyakinan.
#
# Terukur, bukan ditebak: mengganti badannya menjadi `!isDisplayingStaleObject`
# — persis kegagalan yang diperingatkan docstring properti ini — membiarkan
# **seluruh 37 aturan lulus** (exit 0). `.uncertain` ikut `hasAnswer`, jadi
# `!isStale` benar pada saat engine menyatakan diri ragu, dan cincin Saturnus
# tampil di sebelah badge "Ragu". Gambar jadi lebih yakin daripada teksnya.
#
# Properti ini hidup di `Apps/`, yang tidak pernah dibangun `swift-test.sh`,
# jadi tidak ada uji Linux yang bisa menahannya.
DEFINISI = "public var confirmsDisplayedIdentity: Bool {"
SUMBER_DEFINISI = os.path.join("Apps", "Shared", "PointingEngine.swift")
badan = None
if os.path.exists(SUMBER_DEFINISI):
    teks = kode_saja(open(SUMBER_DEFINISI, encoding="utf-8").read())
    if DEFINISI in teks:
        # Ambil sampai kurung kurawal tutup pada kedalaman yang sama.
        i = teks.index(DEFINISI) + len(DEFINISI)
        kedalaman, j = 1, i
        while j < len(teks) and kedalaman:
            if teks[j] == "{":
                kedalaman += 1
            elif teks[j] == "}":
                kedalaman -= 1
            j += 1
        badan = teks[i:j - 1].strip()

if badan is None:
    # Fail-closed: propertinya hilang atau berubah nama berarti aturan ini
    # tidak lagi mengukur saklar identitas yang paling penting.
    masalah.append(
        "  %s: deklarasi `confirmsDisplayedIdentity` tidak ditemukan -- "
        "aturan ini tidak bisa memutuskan apakah gambar boleh mengklaim "
        "identitas; jangan anggap bersih." % SUMBER_DEFINISI)
elif badan.startswith("!"):
    masalah.append(
        "  %s: `confirmsDisplayedIdentity` menegasikan (%s) -- kebalikan "
        "dari maksudnya, ciri pengenal muncul saat engine ragu."
        % (SUMBER_DEFINISI, badan))
elif not re.search(r"\b(?:confirmsIdentity|confirmsDisplayedIdentity)\b", badan):
    masalah.append(
        "  %s: `confirmsDisplayedIdentity` berbadan `%s` -- bukan fakta "
        "keyakinan engine, jadi identitas diklaim atau dibungkam karena "
        "sebab yang lain (mis. `!isStale` lolos pada `.uncertain`)."
        % (SUMBER_DEFINISI, badan))

if diperiksa == 0:
    print("Tidak ada pemanggilan aksesor identitas di Apps/; aturan ini "
          "tidak mengukur apa pun.")
elif masalah:
    print("\n".join(masalah))
    print("-> Kirim faktornya apa adanya (`isConfirmed`, "
          "`engine.confirmsDisplayedIdentity`), bukan `!` atau nama lain: "
          "penjaga yang bukan faktornya membuat gambar lebih yakin atau "
          "lebih ragu daripada teksnya.")
PY
)
if printf '%s' "$penjaga_faktor" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 36 gagal dijalankan:"
  echo "$penjaga_faktor"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$penjaga_faktor" ]; then
  echo "$penjaga_faktor"
  status=1
else
  echo "Bersih: penjaga identitas menerima faktornya, bukan kawan tunggal."
fi

# ── Aturan 37: `switch` di Apps/ wajib memuat SETIAP kasus enum model ───────
#
# Cacat yang ditutup aturan ini nyata dan sudah pernah mendarat di `main`:
# commit `27dd677` menambahkan `.paleDisk` dan `.blueDisk` ke
# `enum DistinguishingFeature` (PointingKit), dan memperbarui **satu** dari
# dua `switch` atas `palette.feature` di `CelestialVisualView.swift`. Yang
# belum diperbarui ada di jalur sabit (`showsPhase`).
#
# Seluruh gerbang Linux hijau pada commit itu: 216 + 799 uji, 36 aturan UI,
# dan `swift-typecheck.sh`. Yang merah hanya Apple Build (macos-15):
#
#     Apps/Shared/CelestialVisualView.swift:269:29:
#       error: switch must be exhaustive
#
# Kenapa Linux **tidak bisa** melihatnya, dan itu bukan kelalaian yang bisa
# ditambal di tempat lain: runner Linux hanya membangun `Packages/`, tidak
# pernah `Apps/`. `swift-typecheck.sh` hanya `-parse` — sintaks — dan
# kelengkapan `switch` adalah pemeriksaan **semantik** yang butuh seluruh tipe
# diketahui. Jadi tidak ada satu pun gerbang cepat yang bisa menangkap kelas
# ini, sementara gerbang yang bisa (macOS) adalah yang paling lambat dan
# paling akhir.
#
# **Kenapa aturan ini tidak boleh hanya memeriksa enum yang "baru".** Aturan
# yang membaca daftar bernama (`paleDisk`, `blueDisk`) akan hijau pada cacat
# yang sama persis begitu orang menambahkan kasus berikutnya — dan itu satu
# baris kerja. Karena itu aturannya **menurunkan** himpunan kasus dari sumber
# model di `Packages/`, lalu menuntut setiap `switch` di `Apps/` yang tidak
# punya `default:` memuat seluruh himpunan itu.
#
# **Kedua paket, dan kenapa itu diukur.** Cakupannya semula hanya
# `Packages/PointingKit/Sources/`. `MountAxis` hidup di **CelestialEngine** dan
# di-`switch` di `Apps/PointAndKnowiOS/Sources/TelescopeHandoffView.swift:81`,
# jadi `switch` itu tidak pernah diperiksa. Terukur: menghapus `case
# .altitudeAzimuth:` dari sana membiarkan seluruh 37 aturan hijau, sementara
# compiler menolaknya di macOS (`switch must be exhaustive`) — kelas cacat yang
# persis sama dengan yang mendarat di `main` pada `27dd677`, hanya satu paket
# lebih jauh. Terukur sesudah perluasan: 8 situs diperiksa → **9**.
#
# **Syarat kandidat ikut berubah, dan itu bukan pelonggaran.** Syarat lama
# menuntut labelnya subset dari **tepat satu** enum. Perluasan cakupan membuat
# `switch visual.kind` (`CelestialVisualView.swift:73`) cocok dengan **dua**
# enum berhimpunan kasus identik — `CelestialVisual.Kind` (PointingKit) dan
# `ObjectKind` (CelestialEngine), keduanya
# `{moon, planet, star, sun, deepSky}`. Dengan syarat lama situs itu justru
# **hilang dari pemeriksaan**: gerbang yang menyempit tanpa suara, terukur.
# Karena dua enum berhimpunan sama menuntut kelengkapan yang sama, syaratnya
# sekarang "semua kandidat punya himpunan kasus identik" — dan kalau ada dua
# kandidat dengan himpunan **berbeda**, kita memang tidak tahu enum mana yang
# dimaksud, jadi diam tetap jawaban yang jujur di sana.
#
# **Pembaca klausanya menghitung kedalaman kurung, bukan baris.** Versi
# semula memakai `^[ \t]*case` (`re.M`), yang tidak bisa membedakan `case`
# milik tipe terluar dari `case` yang hidup di dalam `switch` bersarang. Dua
# akibatnya terukur di pohon ini: `DeepSkyCatalogue` menyerap keenam kasus
# `Morphology` yang bersarang di dalamnya, dan `Planet` dibuang seluruhnya
# karena `switch self` di dalam propertinya terbaca sebagai kasus planet.
# Keduanya membuat himpunan kasus **salah**, bukan sekadar tidak lengkap.
# Sesudah perbaikan: 12 enum terindeks → **25**, dan tidak ada enum yang
# hilang. Untuk `switch` di `Apps/` perubahannya hari ini **0 situs**; ia
# tetap dipasang karena arah kegagalannya yang mahal — label asing dari
# `switch` bersarang membuat `switch` yang **kurang** satu kasus tampak
# lengkap.
#
# **Kasus bermuatan, dan kenapa itu wajib dibaca.** Versi pertama pembaca ini
# hanya mengenali `case nama` dan membuang **seluruh** enum yang salah satu
# kasusnya bermuatan (`case identifiable(CelestialVisual)`). Akibatnya terukur:
# `switch ReducedLuminanceVisual.plan(...)` (`ReducedLuminanceView.swift:57`)
# tidak pernah diperiksa, dan menambahkan `case candidate(CelestialVisual)`
# ke `Plan` membiarkan seluruh aturan hijau sementara `switch`-nya tidak
# lengkap — kelas cacat yang sama dengan `27dd677`, pada enum yang kebetulan
# punya muatan. Yang dibandingkan hanya **nama** kasusnya; muatan di sisi
# `switch` (`let visual`) justru wajib ada dan memang berbeda dari muatan di
# model, jadi menuntut muatan yang sama akan menuduh kode yang benar.
# Terukur: enum terindeks **25 → 27**, situs diperiksa **9 → 10**, **0 hilang**.
#
# **Batas yang diakui, dan kenapa ia tetap berguna.** Ini sapu **teks**, bukan
# pemeriksa tipe. Untuk menghindari menuduh kode yang benar, aturan hanya
# berbunyi bila memenuhi **ketiga** syarat:
#
#   1. setiap klausa `case`-nya murni daftar koma dari anggota berbentuk
#      `.nama` (tanpa `let`, tanpa `where`, tanpa literal) — jadi tidak ada
#      pengikatan nilai yang bisa membuat daftarnya tidak lengkap;
#   2. tidak ada `default:` di badannya (kalau ada, compiler memang tidak
#      menuntut kelengkapan);
#   3. labelnya subset dari enum yang **kasusnya sama**. Kalau ada dua
#      kandidat dengan himpunan berbeda, kita tidak tahu `switch`-nya atas
#      enum yang mana — dan gerbang yang menebak akan menuduh kode benar,
#      yang membuat orang melonggarkannya. Diam adalah jawaban yang jujur di
#      sana.
#
# Syarat 3 itu bukan kehati-hatian teoretis: ia **diukur**. Versi pertama
# tanpa syarat itu menandai `ReducedLuminanceView.swift:57`
# (`switch ReducedLuminanceVisual.plan(...) { case .none / .identifiable }`)
# sebagai kehilangan `Subline`, `UncertainReason`, `DistinguishingFeature`,
# dan dua enum lain yang kebetulan punya superset label yang sama — sebuah
# tuduhan pada kode yang benar. Ditemukan dengan menjalankan kandidat aturan
# atas pohon yang sudah diperbaiki (0 temuan) **dan** atas pohon pra-perbaikan
# (tepat 1 temuan, `CelestialVisualView.swift:269`, kehilangan
# `['blueDisk', 'paleDisk']`) — bukan dengan membayangkan kasusnya.
#
# **Yang TIDAK diklaim.** Ia tidak membuktikan `switch`-nya benar, hanya
# lengkap. Ia tidak melihat `switch` ber-`default:` (di sana kelengkapan
# memang tidak dituntut compiler). Ia tidak mengenali enum yang dideklarasikan
# di `Apps/` sendiri. Dan ia tidak tahu apakah cabang yang lengkap itu
# menggambar hal yang benar.
echo
echo "== Aturan 37: switch di Apps/ wajib memuat setiap kasus enum model =="
switch_lengkap=$(python3 - <<'PY' 2>&1
import os
import re

# Kedua paket, bukan hanya PointingKit.
#
# `MountAxis` hidup di CelestialEngine dan di-`switch` di
# `Apps/PointAndKnowiOS/Sources/TelescopeHandoffView.swift:81`. Selama
# himpunannya hanya dibaca dari PointingKit, `switch` itu **tidak pernah
# diperiksa** — dan cacatnya persis kelas yang aturan ini ada untuk menutup:
# menghapus `case .altitudeAzimuth:` membiarkan seluruh 37 aturan hijau
# (diukur), sementara compiler menolaknya di macOS.
PACKAGE_SOURCES = [os.path.join("Packages", "PointingKit", "Sources"),
                   os.path.join("Packages", "CelestialEngine", "Sources")]
APPS = "Apps"


def strip_comments(text):
    """Kode saja. Berkas di repo ini menceritakan cacat lamanya panjang lebar
    di komentar, dan `case .paleDisk:` yang **dikomentari** tidak boleh
    terbaca sebagai kenyataan."""
    text = re.sub(r"//[^\n]*", "", text)
    return re.sub(r"/\*.*?\*/", "", text, flags=re.S)


def brace_block(text, start):
    """Isi blok `{...}` yang mulai di/atau setelah `start`, atau (None, -1)."""
    i = text.find("{", start)
    if i < 0:
        return None, -1
    depth = 0
    j = i
    while j < len(text):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i + 1:j], j
        j += 1
    return None, -1


def at_line_start(body, i):
    """Apakah `i` karakter pertama yang bukan-spasi di barisnya.

    Dipakai menggantikan `^[ \\t]*` pada regex ber-`re.M`, yang **tidak bisa
    menghitung kedalaman kurung**. Perbedaan itu bukan kerapian: regex baris
    membaca `case` di dalam `switch` bersarang sebagai kasus milik tipe
    terluar — lihat `top_level_cases` dan `switch_label_sets`.
    """
    j = i - 1
    while j >= 0 and body[j] in " \t":
        j -= 1
    return j < 0 or body[j] == "\n"


def top_level_clauses(body, prefix):
    """Klausa ber-`prefix` pada **kedalaman kurung 0**, plus apakah semuanya
    sederhana (tidak ada pengikatan nilai / `where` / literal).

    Kedalaman itu yang membuat himpunan kasus benar. Regex baris mencampur
    kasus sebuah enum dengan kasus enum yang dideklarasikan **di dalamnya**:
    terukur pada pohon ini, `DeepSkyCatalogue` menyerap keenam kasus
    `Morphology` (yang bersarang di dalamnya) dan `Planet` dibuang seluruhnya
    karena `switch self` di dalam propertinya terbaca sebagai kasus planet.
    """
    out = []
    simple = True
    depth = 0
    i = 0
    n = len(body)
    while i < n:
        ch = body[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        elif depth == 0 and at_line_start(body, i) and body.startswith(prefix, i):
            rest = body.find("\n", i)
            if rest < 0:
                rest = n
            clause = body[i + len(prefix):rest].strip()
            colon = clause.find(":")
            if colon >= 0:
                clause = clause[:colon]
            out.append(clause)
            i = rest
            continue
        i += 1
    return out, simple


def split_top_commas(clause):
    """Pecah daftar `case` pada koma **kedalaman kurung 0**.

    `case a(Int, Int), b` adalah dua kasus, bukan tiga: koma di dalam
    tanda kurung milik muatan kasus pertama. `str.split(",")` membacanya
    sebagai tiga potongan dan potongan `Int` lalu tampak seperti kasus
    yang tidak terbaca — satu-satunya alasan `Plan` (yang punya
    `.identifiable(CelestialVisual)`) tidak pernah masuk ke himpunan enum
    dan `switch` atasnya tidak pernah diperiksa.
    """
    out = []
    depth = 0
    current = ""
    for ch in clause:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(current)
            current = ""
        else:
            current += ch
    out.append(current)
    return out


def enum_case_sets(text):
    """{nama enum: {kasus}} untuk enum yang semua kasusnya berbentuk nama.

    **Kasus berasosiasi-nilai ikut dibaca, namanya saja.** Ini bukan
    kelonggaran: yang dituntut Aturan 37 adalah *kelengkapan label*, dan
    `case .identifiable(let visual)` di `Apps/` adalah label `.identifiable`
    yang sama dengan `case identifiable(CelestialVisual)` di model. Muatannya
    boleh berbeda antar sisi tanpa membuat labelnya salah — `let` di sisi
    `switch` justru **wajib** ada supaya nilainya bisa dipakai, dan menuntut
    muatan yang sama persis akan menuduh kode yang benar.

    Terukur pada pohon ini: membaca kasus bermuatan menaikkan enum terindeks
    **25 → 27** dan situs diperiksa **9 → 10**, dengan **0 situs hilang**.
    Situs yang bertambah itu `ReducedLuminanceView.swift:57`
    (`switch ReducedLuminanceVisual.plan(...)` atas `Plan`) — dan di sana
    versi lama memang buta: menambahkan `case candidate(CelestialVisual)` ke
    `Plan` membiarkan seluruh aturan hijau sementara `switch`-nya tidak
    lengkap. Itu bentuk cacat yang sama dengan `27dd677`, pada enum yang
    kebetulan punya muatan.

    Yang tetap dibuang: enum yang **tidak punya satu pun kasus** (namespace
    berisi `static let` saja — 35 dari 62 enum di pohon ini) dan enum yang
    salah satu klausanya tidak berbentuk `nama` / `nama(muatan)`. Kasus
    pertama bukan enum, kasus kedua tidak bisa ditaksir dari teks.
    """
    found = {}
    for m in re.finditer(r"\benum\s+([A-Za-z_][A-Za-z0-9_]*)\s*[:{]", text):
        name = m.group(1)
        body, _ = brace_block(text, m.end() - 1)
        if body is None:
            continue
        clauses, _ = top_level_clauses(body, "case")
        cases = set()
        readable = True
        for clause in clauses:
            for part in split_top_commas(clause):
                part = part.strip()
                # `nama` atau `nama(muatan)` — muatannya tidak dibaca, hanya
                # keberadaannya yang menandakan ini kasus bermuatan.
                match = re.fullmatch(
                    r"([A-Za-z_][A-Za-z0-9_]*)\s*(?:\((?:[^()]|\([^()]*\))*\))?",
                    part, re.S)
                if match:
                    cases.add(match.group(1))
                else:
                    readable = False
        if cases and readable:
            found.setdefault(name, set()).update(cases)
        else:
            found.pop(name, None)
    return found


def switch_label_sets(text):
    """(baris, ekspresi, {label}) untuk tiap `switch` tanpa `default:`.

    Klausa yang tidak berbentuk daftar `.anggota` membatalkan `switch` itu —
    `case .identifiable(let visual) where x > 0:` tidak boleh dibaca sebagai
    himpunan label, karena labelnya memang tidak dimaksudkan lengkap.

    **`.anggota(let x)` diterima, dan `let` itu wajib di sisi ini.** Label
    yang dibandingkan adalah namanya saja; muatannya tidak pernah dipakai
    untuk memutuskan kelengkapan. Menolak bentuk ini akan membuang seluruh
    `switch` atas enum bermuatan — terukur: `switch ReducedLuminanceVisual.plan(...)`
    kehilangan satu-satunya kasusnya yang bermuatan dan tidak pernah diperiksa.
    Sebaliknya, bentuk yang memang bukan daftar label tetap membatalkan:
    `case let .identifiable(visual)` (pengikatan di depan), `where`, dan
    label berangka seperti `.case1` semuanya di luar jangkauan pembaca ini,
    dan `switch` yang memuatnya dilewati alih-alih dituduh.

    Klausanya diambil pada kedalaman 0 saja, dengan alasan yang sama seperti
    `top_level_clauses`: `switch` bersarang yang tidak ber-`default:`
    menyumbangkan labelnya ke himpunan milik induknya. Terukur pada pohon ini
    perubahannya **0 situs** — jadi ini penjaga untuk bentuk yang belum
    ditulis, bukan perbaikan cacat yang sedang ada. Ia tetap ada karena arah
    kegagalannya yang mahal: label asing membuat `switch` yang **kurang**
    satu kasus tampak lengkap.
    """
    for m in re.finditer(r"\bswitch\s+([^\{]+?)\s*\{", text):
        body, _ = brace_block(text, m.end() - 1)
        if body is None:
            continue
        if re.search(r"^[ \t]*default\s*:", body, re.M):
            continue
        clauses, _ = top_level_clauses(body, "case")
        labels = set()
        readable = True
        for clause in clauses:
            for part in split_top_commas(clause):
                part = part.strip()
                # `.nama` atau `.nama(muatan)`; muatannya boleh memuat `let`.
                match = re.fullmatch(
                    r"\.([A-Za-z_][A-Za-z0-9_]*)\s*(?:\(.*\))?", part, re.S)
                if match:
                    labels.add(match.group(1))
                else:
                    readable = False
        if not readable or not labels:
            continue
        yield text[:m.start()].count("\n") + 1, m.group(1).strip(), labels


cases = {}
for source_dir in PACKAGE_SOURCES:
    for dirpath, _, filenames in os.walk(source_dir):
        for filename in filenames:
            if not filename.endswith(".swift"):
                continue
            path = os.path.join(dirpath, filename)
            with open(path, encoding="utf-8") as handle:
                for name, values in enum_case_sets(
                        strip_comments(handle.read())).items():
                    cases.setdefault(name, set()).update(values)

problems = []
examined = 0
for dirpath, _, filenames in os.walk(APPS):
    for filename in sorted(filenames):
        if not filename.endswith(".swift"):
            continue
        path = os.path.join(dirpath, filename)
        with open(path, encoding="utf-8") as handle:
            text = strip_comments(handle.read())
        for line, expr, labels in switch_label_sets(text):
            # Hanya bila labelnya subset dari enum yang **kasusnya sama**.
            # Kalau ada dua kandidat dengan himpunan kasus **berbeda**, kita
            # tidak tahu enum mana yang dimaksud — dan gerbang yang menebak
            # akan menuduh kode benar, yang membuat orang melonggarkannya.
            # Diam adalah jawaban yang jujur di sana.
            #
            # Perhatikan `<=`, bukan `<`. `switch` yang **lengkap** punya
            # `labels == values`, jadi syarat `<` akan membuang justru
            # `switch` yang benar — dan `examined` lalu hanya menghitung
            # pelanggaran, sehingga pohon yang bersih tampak seperti "tidak
            # mengukur apa pun" dan gerbang ini merah pada kode yang benar.
            # Diukur pada pohon ini: `<` memberi 0 yang diperiksa, `<=`
            # memberi 9.
            #
            # Syarat "berbeda" itu bukan pelonggaran. Dua enum dengan kasus
            # yang sama menuntut **kelengkapan yang sama**, jadi memeriksa
            # salah satunya tidak menebak apa pun. Terukur: `CelestialVisual
            # .Kind` (PointingKit) dan `ObjectKind` (CelestialEngine)
            # keduanya {moon, planet, star, sun, deepSky}, dan `switch
            # visual.kind` di `CelestialVisualView.swift:73` cocok dengan
            # keduanya. Dengan syarat lama ("tepat satu kandidat") situs itu
            # **hilang dari pemeriksaan** begitu cakupan diperluas — gerbang
            # yang menyempit tanpa suara.
            candidates = [name for name, values in cases.items()
                          if labels <= values]
            full = {frozenset(cases[name]) for name in candidates}
            if len(full) != 1:
                continue
            examined += 1
            complete = next(iter(full))
            if labels >= complete:
                continue
            missing = sorted(complete - labels)
            problems.append(
                "  %s:%d: `switch %s` melewatkan %s dari `%s` -- compiler "
                "menolaknya di macOS (`switch must be exhaustive`), tetapi "
                "tidak ada gerbang Linux yang melihatnya"
                % (path, line, expr.replace("\n", " ").strip(),
                   missing, sorted(set(candidates))))

if not cases:
    print("Tidak ada enum sederhana yang terbaca dari %s; aturan ini tidak "
          "mengukur apa pun." % ", ".join(PACKAGE_SOURCES))
elif examined == 0 and not problems:
    print("Tidak ada `switch` di %s yang bisa dipastikan atas satu enum; "
          "aturan ini tidak mengukur apa pun." % APPS)
elif problems:
    print("\n".join(problems))
PY
)
if printf '%s' "$switch_lengkap" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 37 gagal dijalankan:"
  echo "$switch_lengkap"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$switch_lengkap" ]; then
  echo "$switch_lengkap"
  echo "-> Lengkapi case-nya, atau tambahkan default: bila switch itu memang"
  echo "   tidak dimaksudkan menutup seluruh enum."
  status=1
else
  echo "Bersih: setiap switch di Apps/ memuat seluruh kasus enum model."
fi

# ── Aturan 38: permukaan kejujuran di Apps/ wajib meneruskan faktanya ──────
#
# Cacat yang ditutup aturan ini **diukur**, bukan disangka, dan ia bersaudara
# dengan yang ditutup Aturan 36.
#
# `Apps/Shared/PointingEngine.swift` punya **tiga** permukaan kejujuran yang
# lahir dari satu keputusan yang sama (`PointingSnapshot`, teruji di Linux):
#
#     isDisplayingStaleObject   -> snapshot.isDisplayingStaleObject(lastLocked:)
#     confirmsDisplayedIdentity -> snapshot.confirmsIdentity(lastLocked:)
#     carriesUncertaintyMarker  -> snapshot.carriesUncertaintyMarker(lastLocked:)
#
# Aturan 36 mengawal **satu** di antaranya -- badan `confirmsDisplayedIdentity`
# -- karena pada siklus itu yang dimutasi hanya yang satu itu. Terukur hari ini
# (salinan utuh, proses baru, `Apps/` + `Packages/` dibawa):
#
#     isDisplayingStaleObject   -> !snapshot.isDisplayingStaleObject(...)
#     isDisplayingStaleObject   -> true
#     isDisplayingStaleObject   -> snapshot.isCalibrated
#     carriesUncertaintyMarker  -> !snapshot.carriesUncertaintyMarker(...)
#     carriesUncertaintyMarker  -> true
#     carriesUncertaintyMarker  -> snapshot.isCalibrated
#
# **semuanya `swift-ui-lint.sh` LULUS (exit 0)**, dan `swift-typecheck.sh`
# juga lulus karena tidak ada yang salah sintaks. Dua di antara enam itu
# bahkan lebih buruk daripada yang ditutup Aturan 36:
#
#   * `isDisplayingStaleObject -> true` membuat peringatan "sisa pandangan
#     sebelumnya" menyala **terus-menerus** pada jam: setiap hasil, betapapun
#     segar, dituduh basi. Lawannya (`false`) membungkamnya selamanya.
#   * `carriesUncertaintyMarker -> false` membuat **nama kandidat** tampil
#     sebagai temuan di layar redup -- persis keadaan yang menurut docstring
#     properti ini paling berbahaya, karena di sanalah nama kandidat menjadi
#     huruf terbesar di layar.
#
# Kenapa Aturan 36 tidak menangkapnya: ia menambat **satu nama**
# (`DEFINISI = "public var confirmsDisplayedIdentity: Bool {"`). Dua
# saudaranya tidak pernah dibaca. Kenapa Aturan 34/35 tidak menangkapnya:
# keduanya mengawasi **argumen pemanggil**, dan di sini pemanggilnya tidak
# berubah -- `engine.isDisplayingStaleObject` tetap dikirim apa adanya.
#
# **Kenapa aturan ini menurunkan permukaannya, bukan mendaftar namanya.**
# Daftar tiga nama akan hijau lagi besok pagi, begitu seseorang menambah
# permukaan keempat. Yang dipakai di sini adalah prinsipnya: sebuah
# `var <Nama>: Bool` di `Apps/` yang namanya **sama dengan** anggota `Bool`
# model di `Packages/` adalah penerusan, dan penerusan harus menyebut
# anggota itu di badannya. Fail-closed bila deklarasi hilang.
#
# **Kenapa syarat "namanya sama dengan anggota model".** Ini bukan hiasan:
# `NightMode.isOn`, `AudioCue.isOn`, `MotionLogger.isAvailable`,
# `LocationProvider.hasRealLocation`, `DiagnosticsView.isRecording` tidak
# punya padanan di model -- mereka preferensi dan keadaan sensor, bukan
# keputusan engine. Menuntut mereka menyebut anggota model akan menuduh kode
# yang benar, dan gerbang yang menuduh kode benar akan dilonggarkan orang.
# Yang diawasi persis yang punya sumber di model.
#
# **Kenapa `confirmsDisplayedIdentity` ikut tercakup walau namanya tidak ada
# di model.** Namanya memang berbeda dari `confirmsIdentity` (sengaja: ia
# menyebut **apa yang dilakukan**, bukan dari mana asalnya), sehingga
# pencocokan nama akan melewatkan permukaan yang paling penting. Aturan ini
# karena itu memakai **dua** jalan: nama yang sama dengan anggota model,
# *atau* nama yang berbagi kata dengan anggota model yang sudah dikenal
# Aturan 36 (`confirmsIdentity`). Fail-closed tetap: kalau badannya tidak
# menyebut anggota mana pun, ia merah.
#
# Yang TIDAK diklaim: ini sapu teks atas bentuk `var X: Bool { satu
# ekspresi }`. Ia tidak tahu tipe, dan tidak membaca `get {}` berbadan
# banyak-pernyataan selain lewat bentuk sederhana itu.
echo
echo "== Aturan 38: permukaan kejujuran di Apps/ meneruskan faktanya =="
permukaan_jujur=$(python3 - <<'PY' 2>&1
import os, re

PK = os.path.join("Packages", "PointingKit", "Sources", "PointingKit")
if not os.path.isdir(PK):
    print("Tidak bisa membaca %s -- aturan ini tidak bisa memutuskan." % PK)
    raise SystemExit(0)


def kode_saja(teks):
    """Buang komentar `//` dan isi literal string.

    Isi string dikosongkan -- bukan cuma tanda kutipnya dibuang -- karena
    repo ini mendokumentasikan bentuk yang dilarang sebagai contoh di dalam
    `"..."`; isi yang dibiarkan hidup terbaca sebagai deklarasi.
    """
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam_str, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam_str:
                if esc:
                    esc = False
                    buf.append(" ")
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam_str = False
                    buf.append('"')
                else:
                    buf.append(" ")
            else:
                if ch == '"':
                    dalam_str = True
                    buf.append('"')
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


# 1. Anggota `Bool` model: properti **dan** fungsi ber-`-> Bool`.
anggota = set()
for root, _, files in os.walk(PK):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        src = kode_saja(open(os.path.join(root, name), encoding="utf-8").read())
        for m in re.finditer(r"\bvar\s+([A-Za-z_]\w*)\s*:\s*Bool\b", src):
            anggota.add(m.group(1))
        for m in re.finditer(r"\bfunc\s+([A-Za-z_]\w*)\s*\(", src):
            i, d, j = m.end(), 1, m.end()
            while j < len(src) and d:
                if src[j] == "(":
                    d += 1
                elif src[j] == ")":
                    d -= 1
                j += 1
            if re.search(r"->\s*Bool", src[j:j + 30]):
                anggota.add(m.group(1))

if not anggota:
    print("Tidak ada anggota Bool model; aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

# Nama yang sudah dikenal Aturan 36 walau namanya tidak ada di model:
# `confirmsDisplayedIdentity` adalah penamaan sisi UI untuk
# `snapshot.confirmsIdentity`.
PASANGAN = {"confirmsDisplayedIdentity": "confirmsIdentity"}

DEKL = re.compile(r"\bvar\s+([A-Za-z_]\w*)\s*:\s*Bool\s*\{")
masalah = []
diperiksa = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = kode_saja(open(path, encoding="utf-8").read())
        for m in DEKL.finditer(kode):
            nama = m.group(1)
            if nama not in anggota and nama not in PASANGAN:
                continue  # preferensi/keadaan sensor: bukan keputusan engine
            i, d, j = m.end(), 1, m.end()
            while j < len(kode) and d:
                if kode[j] == "{":
                    d += 1
                elif kode[j] == "}":
                    d -= 1
                j += 1
            badan = " ".join(kode[i:j - 1].split())
            if not badan:
                continue
            diperiksa += 1
            baris = kode[:m.start()].count("\n") + 1
            if badan.startswith("!"):
                masalah.append(
                    "  %s:%d: `var %s: Bool` menegasikan (%s) -- kebalikan "
                    "dari maksudnya, penanda kejujuran menyala atau diam "
                    "pada keadaan yang salah" % (path, baris, nama, badan))
                continue
            if re.match(r"^\s*(true|false)\s*$", badan):
                masalah.append(
                    "  %s:%d: `var %s: Bool` berbadan literal `%s` -- "
                    "keputusan engine diganti tetapan, jadi penandanya tidak "
                    "lagi mengikuti keadaan" % (path, baris, nama, badan))
                continue
            # Penerusan: badannya harus menyebut **anggotanya sendiri**.
            sumber = PASANGAN.get(nama, nama)
            if not re.search(r"\b" + re.escape(sumber) + r"\b", badan):
                masalah.append(
                    "  %s:%d: `var %s: Bool` berbadan `%s` -- tidak "
                    "menyebut `%s`, jadi faktanya diambil dari keadaan yang "
                    "bukan sumbernya" % (path, baris, nama, badan, sumber))

if diperiksa == 0:
    print("Tidak ada permukaan kejujuran di Apps/; aturan ini tidak "
          "mengukur apa pun.")
elif masalah:
    print("\n".join(masalah))
    print("-> Teruskan faktanya apa adanya (`snapshot.<anggotanya>(...)`), "
          "bukan `!`, literal, atau nama lain: permukaan ini yang memberi "
          "tahu pengguna apa yang tidak diketahui engine.")
PY
)
if printf '%s' "$permukaan_jujur" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 38 gagal dijalankan:"
  echo "$permukaan_jujur"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$permukaan_jujur" ]; then
  echo "$permukaan_jujur"
  status=1
else
  echo "Bersih: setiap permukaan kejujuran di Apps/ meneruskan faktanya."
fi

# ── Aturan 39: anggota `static` tidak boleh dipanggil pada instance ─────────
#
# Cacat yang melahirkan aturan ini **sampai ke `origin/main` dan memerahkan
# CI macOS**, dengan pesan yang tidak bisa dilihat satu gerbang Linux pun:
#
#   Apps/PointAndKnowWatch/Sources/PointingView.swift:669:28: error:
#   static member 'spokenStarClassLine' cannot be used on instance of type
#   'CelestialVisual'
#
# Bentuk barisnya: `visual.spokenStarClassLine(spectralClass: …)`. Dua gerbang
# yang paling dekat **dua-duanya lulus**, dan masing-masing dengan alasan yang
# masuk akal:
#
#  - Aturan 26 (keanggotaan) benar: `spokenStarClassLine` memang anggota
#    `CelestialVisual`. Yang salah adalah bagaimana ia dipanggil.
#  - Aturan 27 (label argumen) benar: `spectralClass:` memang labelnya.
#  - Aturan 34 (meneruskan `isConfirmed`) juga — argumennya utuh.
#
# Jadi yang terlewat bukan nama, label, atau faktor, melainkan **bentuk
# pemanggilannya**: boleh dipanggil di tipe (`CelestialVisual.x`), tidak di
# nilai (`visual.x`). Itu satu kelas terpisah, dan penjaganya harus terpisah.
#
# **Kenapa instance-receiver-nya lokal pada berkas yang sama.** Menebak tipe
# sebuah nama dari berkas lain akan memerahkan kode yang benar (repo ini sudah
# menulis aturan itu untuk Aturan 26/27: gerbang yang merah pada kode benar
# akan dimatikan orang). Bentuk yang **pasti** salah dan bisa dibaca tanpa
# menebak: nama yang di-`let`/`var` **di dalam berkas itu sendiri** dengan
# anotasi tipe paket yang punya anggota `static` bernama sama — atau nama yang
# di deklarasikan sebagai parameter beranotasi serupa. Di `ObjectDetailView`
# itu `let visual: CelestialVisual?` (parameter ber-`@Binding`), jadi
# pemeriksaan parameter wajib ada; kalau tidak, aturan ini diam pada bentuk
# yang justru terjadi.
#
# Batasnya jujur: ia hanya memeriksa receiver yang **tipenya tertulis** di
# berkas yang sama. Receiver tanpa anotasi (`let v = …` lalu `v.x()`),
# anggota statis lewat protokol, dan tipe yang dideklarasi di `Apps/` tidak
# terlihat. Yang dijaga adalah bentuk yang benar-benar lolos ke `main`.
echo
echo "== Aturan 39: anggota static tidak dipanggil pada instance =="
statis_instance=$(python3 - <<'PY' 2>&1
import os, re

# ── Aturan 39: indeks anggota, dipisah dari pemindainya ─────────────────────
#
# **Kenapa berkas ini tidak "membaca blok dengan mencacah kurung kurawal".**
# Tiga percobaan pertama aturan ini memakai pencacah kurung yang berjalan per
# baris, dan ketiganya melapor "Bersih" sambil memegang indeks yang **kosong**
# (0 anggota `CelestialVisual`, padahal tipe itu punya belasan anggota statis).
# Yang membuatnya bertahan bukan kecerdikan pemindainya, melainkan bahwa
# "Bersih" adalah kata yang sama untuk "tidak ada pelanggaran" dan "tidak
# membaca apa pun". Karena itu:
#
#   1. kalau indeks kosong -> aturan ini GAGAL, bukan bersih (vacuous green);
#   2. kepemilikan anggota diturunkan dari **deklarator** `struct/enum/class/
#      actor/extension` yang terakhir terlihat di berkas itu, setelah komentar
#      dan isi string dibuang. Tidak ada neraca kurung yang harus benar.
#
# Batas yang dinyatakan: satu deklarator berlaku sampai deklarator berikutnya
# di berkas yang sama. Itu sesuai tata letak paket ini (satu tipe per bagian,
# extension diberi namanya sendiri, dan metode pada extension memakai `Self.`).
# Kalau kelak ada anggota tipe A yang ditulis setelah tipe B tanpa deklarator,
# aturan ini bisa salah membaca pemiliknya; ia akan lebih sering **berbunyi
# pada kode benar** daripada diam, dan itu arah yang bisa ditoleransi gerbang
# (dilihat orang), sedangkan diam pada kode salah tidak.
PKG = "Packages/PointingKit/Sources/PointingKit"
APPS = "Apps"


def kode_saja(teks):
    """Buang komentar dan isi string literal."""
    t = re.sub(r"//[^\n]*", "", teks)
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    return "\n".join(re.sub(r'"[^"\n]*"', '""', b) for b in t.split("\n"))


# Di-anchor ke AWAL baris (dipakai dengan `.match`): sebuah deklarator hanya
# yang **memulai** deklarasi. Pola tanpa anchor pernah menangkap
# `-> PhaseGeometry? {` sebagai deklarasi dan memindahkan kepemilikan anggota.
DEKL = re.compile(r"\s*(?:(?:public|internal|private|fileprivate|package|"
                  r"final|open)\s+)*(?:struct|enum|class|actor|extension)\s+"
                  r"([A-Za-z_][A-Za-z0-9_.]*)")
STATIS = re.compile(r"^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+|"
                    r"package\s+)*static\s+(?:func|var|let)\s+([A-Za-z_][A-Za-z0-9_]*)")
INSTANCE = re.compile(r"^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+|"
                      r"package\s+|mutating\s+|nonmutating\s+)*"
                      r"(?:func|var|let)\s+([A-Za-z_][A-Za-z0-9_]*)")

statis = {}
instance = {}
for root, _, files in os.walk(PKG):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        teks = kode_saja(open(os.path.join(root, name), encoding="utf-8").read())
        # ── Pemilik anggota: tumpukan deklarator ber-kedalaman ──────────────
        #
        # Dua pendekatan sebelumnya sama-sama gagal dan sama-sama melapor
        # "Bersih":
        #   * pencacah kurung yang berjalan sendiri -> neraca meleset, indeks
        #     kosong (0 anggota `CelestialVisual`, padahal belasan).
        #   * "deklarator terakhir berlaku sampai deklarator berikutnya" ->
        #     `CelestialVisual` (baris 23) lalu `PhaseGeometry` (331) membuat
        #     SEMUA metode `CelestialVisual` sesudah 331 tercatat milik
        #     `PhaseGeometry`; indeks terlihat berisi (55 tipe), jadi penjaga
        #     lantai pun lolos. Yang menangkapnya: uji harness menanyakan
        #     anggota yang persis dibutuhkan (`phaseGeometry` instance).
        #
        # Yang benar: kedalaman kurung kurawal, dengan deklarator hanya
        # dicatat pada baris yang MEMULAI deklarasi tipe. Tipe bersarang
        # dicatat ber-titik (`CelestialVisual.Planet`), dan `extension` tidak
        # menambah nama ke tumpukan (isinya milik tipe yang sama).
        EXT = "\0ext"
        ANON = "\0anon"
        ext_kini = None
        tumpukan = []      # nama per blok: str, EXT untuk extension
        for baris in teks.split("\n"):
            d = DEKL.match(baris) if re.match(r"\s*(?:(?:public|internal|private|"
                                              r"fileprivate|package|final|open)\s+)"
                                              r"*(?:struct|enum|class|actor|extension)\b",
                                              baris) else None

            # Tipe pemilik baris ini: nama terdalam yang bukan penanda extension.
            # Pemilik = entri terdalam yang bukan penanda; entri itu SUDAH
            # ber-titik utuh (`CelestialVisual.Kind`). Menyambung seluruh
            # tumpukan menghasilkan `CelestialVisual.CelestialVisual.Kind`.
            nama = [n for n in tumpukan if n not in (EXT, ANON)]
            pemilik = nama[-1] if nama else (ext_kini if EXT in tumpukan else None)

            if pemilik and not d:
                m = STATIS.match(baris)
                if m:
                    statis.setdefault(pemilik, set()).add(m.group(1))
                else:
                    mi = INSTANCE.match(baris)
                    if mi:
                        instance.setdefault(pemilik, set()).add(mi.group(1))

            penanda = None
            if d is not None:
                is_ext = re.match(r"\s*(?:(?:public|internal|private|fileprivate|package)\s+)*extension\b",
                                  baris) is not None
                if is_ext:
                    ext_kini = d.group(1)
                    penanda = EXT
                else:
                    # Entri tumpukan sudah ber-titik utuh, jadi induknya
                    # adalah entri terakhir apa adanya (`CelestialVisual`
                    # atau `CelestialVisual.Kind`). Versi sebelumnya menyambung
                    # seluruh tumpukan dan menghasilkan
                    # `CelestialVisual.CelestialVisual.Kind`.
                    induk = [n for n in tumpukan if n not in (EXT, ANON)]
                    penanda = (induk[-1] + "." + d.group(1)) if induk else d.group(1)

            # ── Neraca blok ──────────────────────────────────────────────
            # Setiap blok terbuka dicatat di `tumpukan`; `kedalaman` adalah
            # panjangnya. Aturannya sederhana dan itu sengaja:
            #
            #   * baris deklarasi tipe  -> buka blok (tumpukan +1)
            #   * baris `}`             -> tutup satu blok (tumpukan -1)
            #   * baris lain            -> buka/tutup blok anonim (`if`, dsb.)
            #
            # Yang membuat versi-versi sebelumnya salah: mereka mencoba
            # menurunkan kedalaman dari SELISIH kurung per baris, dan setiap
            # baris yang memuat `}` penutup ikut mem-pop tipe induknya. Di
            # `CelestialVisual.swift` enum bersarang pertama (`Kind`) menutup
            # `CelestialVisual`, jadi seluruh anggota induk sesudahnya tercatat
            # milik tipe lain -- dan gerbangnya tetap melapor "Bersih".
            selisih = baris.count("{") - baris.count("}")
            if d is not None:
                # Deklarasi membuka bloknya sendiri; kurung lain di baris yang
                # sama (deklarasi satu baris) diterapkan setelahnya.
                tumpukan.append(penanda)
                selisih -= 1
            if selisih > 0:
                tumpukan.extend([ANON] * selisih)
            elif selisih < 0:
                # Baris ini menutup blok. Yang ditutup adalah blok terdalam --
                # dan blok anonim di atasnya ikut tertutup. Versi sebelumnya
                # hanya menutup pada baris yang ISINYA persis `}`, sehingga
                # `            }` punya spasi jadi terlewat (spasi dibuang
                # `.strip()`, tapi baris seperti `        })` atau
                # `        } else {` tidak pernah cocok).
                for _ in range(-selisih):
                    if tumpukan:
                        tumpukan.pop()
            if not tumpukan:
                ext_kini = None

# **Penjaga kevakuman.** Angka di bawah bukan janji tentang masa depan; ia
# lantai yang terbukti hari ini. Kalau indeks menyusut di bawahnya, artinya
# pemindai berhenti bekerja -- bukan artinya kode jadi lebih bersih.
if len(statis) < 10 or len(instance) < 10:
    print("Indeks anggota terlalu kecil (%d tipe statis, %d tipe instance): "
          "pemindai tidak membaca paket; aturan ini tidak mengukur apa pun."
          % (len(statis), len(instance)))
    raise SystemExit(0)
if "CelestialVisual" not in statis:
    print("`CelestialVisual` tidak ada di indeks anggota statis; pemindai "
          "salah berkas atau salah pola. Aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

DEKLARASI = re.compile(r"\b(?:let|var)\s+([a-z_][A-Za-z0-9_]*)\s*:\s*([A-Z][A-Za-z0-9_.]*)")
PARAMETER = re.compile(r"(?:@\w+(?:\([^)]*\))?\s+)*(?:let\s+)?([a-z_][A-Za-z0-9_]*)\s*:\s*"
                       r"([A-Z][A-Za-z0-9_.]*)")

masalah = []
diperiksa = 0
for root, _, files in os.walk(APPS):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        teks = kode_saja(open(path, encoding="utf-8").read())
        repot = {}
        for m in DEKLARASI.finditer(teks):
            repot.setdefault(m.group(1), set()).add(m.group(2))
        for m in PARAMETER.finditer(teks):
            repot.setdefault(m.group(1), set()).add(m.group(2))
        for nomor, baris in enumerate(teks.split("\n"), start=1):
            for m in re.finditer(r"(?<![A-Za-z0-9_.])([a-z_][A-Za-z0-9_]*)\s*\??\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)",
                                 baris):
                nama, anggota = m.group(1), m.group(2)
                if nama in ("self", "Self"):
                    continue
                for tipe in repot.get(nama, ()):
                    akar = tipe.split(".")[0]
                    # Anggota instance bernama sama: `CelestialVisual.phaseGeometry`
                    # ada sebagai metode instance DAN statis; `visual.phaseGeometry(…)`
                    # adalah kode yang benar. Tanpa daftar instance, aturan ini
                    # menuduh dua baris sah di `CelestialVisualView.swift`.
                    if anggota in instance.get(akar, ()) or anggota in instance.get(tipe, ()):
                        continue
                    if anggota in statis.get(akar, ()) or anggota in statis.get(tipe, ()):
                        masalah.append(
                            "  %s:%d: `%s.%s` -- `%s` anggota **static** `%s`; "
                            "dipanggil pada instance ia galat kompilasi "
                            "(lihat CI macOS). Pakai `%s.%s(...)`."
                            % (path, nomor, nama, anggota, anggota, tipe, tipe, anggota))
                        break
                diperiksa += 1

if diperiksa == 0:
    print("Tidak ada akses anggota lewat receiver di Apps/; aturan ini tidak "
          "mengukur apa pun.")
elif masalah:
    print("\n".join(sorted(set(masalah))))
    print("-> Anggota `static` dipanggil di tipenya, bukan di nilai: "
          "`CelestialVisual.f(a:)`, bukan `visual.f(a:)`. Linux tidak bisa "
          "melihat galat ini (`swift-typecheck.sh` hanya `-parse`), jadi "
          "gerbang inilah satu-satunya yang berbunyi sebelum push.")
PY
)
if printf '%s' "$statis_instance" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 39 gagal dijalankan:"
  echo "$statis_instance"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$statis_instance" ]; then
  echo "$statis_instance"
  status=1
else
  echo "Bersih: tidak ada anggota static yang dipanggil pada instance."
fi

# ── Aturan 40: setiap gambar wajib MENGATAKAN fase yang dikirimnya ──────────
# Aturan 21 mengukur isi argumen `pulse:` — dinegasikah, terbalik, tanpa
# `hasPulse`. Ia melewati `pulse:` yang **tidak ada** (`value is None:
# continue`), dan di celah itulah cacat yang menutup siklus ini hidup:
#
#     CelestialVisualView(visual: CelestialVisual(kind: .star, ...),
#                         diameter: 64,
#                         isConfirmed: true)          <- tidak ada `pulse:`
#
# Ilustrasi onboarding adalah **bintang**, dan `CelestialVisual.hasPulse`
# menyatakan bintang satu-satunya jenis yang berdenyut. Nilai baku `0` berarti
# layar pertama yang dilihat pengguna adalah satu-satunya tempat glow bintang
# diam — dan tidak ada satu pun gerbang yang berbunyi, karena Aturan 21 hanya
# memeriksa argumen yang ditulis.
#
# Aturannya **bukan** "semua harus berdenyut": gambar statis sah, dan tiga
# pemanggil memang statis. Yang dituntut adalah **keputusan tertulis**. Diam
# yang ditulis sebagai `MotionPolicy.staticPulsePhase` adalah keputusan; diam
# yang terjadi karena labelnya lupa adalah kelalaian, dan keduanya sekarang
# terlihat berbeda — yang pertama hijau, yang kedua merah.
#
# Batas yang dinyatakan: ini membaca **teks** pemanggilan `CelestialVisualView(`
# yang hurufnya persis begitu. Pemanggil yang disimpan di variabel
# (`let gambar: () -> some View = { CelestialVisualView(...) }`) tidak
# berbeda — isinya tetap satu token dan dipindai. Yang TIDAK terbaca adalah
# view yang dibungkus fungsi pembangun di berkas lain; itu tidak ada hari ini
# dan tidak diklaim tertutup.
echo
echo "== Aturan 40: setiap CelestialVisualView menyebut fase denyutnya =="
fase_hilang=$(python3 - <<'PY' 2>&1
import os, re

CALL = "CelestialVisualView("

masalah = []
jumlah = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = open(path, encoding="utf-8").read()
        # Komentar dibuang: nama `CelestialVisualView` muncul di dokumentasi
        # cukup sering, dan docstring yang memuatnya bukan pemanggilan.
        code = "\n".join(l.split("//", 1)[0] for l in text.split("\n"))
        start = 0
        while True:
            i = code.find(CALL, start)
            if i < 0:
                break
            j = i + len(CALL)
            depth = 1
            while j < len(code) and depth:
                if code[j] == "(":
                    depth += 1
                elif code[j] == ")":
                    depth -= 1
                j += 1
            args = code[i + len(CALL):j - 1]
            start = j
            jumlah += 1
            # `pulse:` pada tingkat atas daftar argumen saja. `pulse:` di dalam
            # kurung bersarang milik pemanggil lain tidak berlaku untuk
            # pemanggilan ini.
            datar, kedalaman = [], 0
            for ch in args:
                if ch in "([":
                    kedalaman += 1
                elif ch in ")]":
                    kedalaman -= 1
                if ch == "," and kedalaman == 0:
                    datar.append("\n")
                else:
                    datar.append(ch)
            ada = any(re.match(r"\s*pulse\s*:", a) for a in "".join(datar).split("\n"))
            if not ada:
                line_no = code[:i].count("\n") + 1
                masalah.append(
                    f"  {path}:{line_no}: tidak menyebut `pulse:` — nilainya "
                    "baku 0, diterima tanpa keputusan")

if jumlah == 0:
    print("TIDAK ADA satu pun pemanggilan CelestialVisualView( terbaca — "
          "pembacanya perlu diselaraskan; nol pemanggilan bukan berarti bersih")
elif masalah:
    print("\n".join(masalah))
    print("-> Diam yang sah ditulis `pulse: MotionPolicy.staticPulsePhase`; "
          "yang berdenyut ditulis `pulse: visual.hasPulse ? fase : 0`.")
PY
)
if printf '%s' "$fase_hilang" | grep -q "Traceback\|^error:"; then
  echo "Pemeriksaan Aturan 40 gagal dijalankan:"
  echo "$fase_hilang"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$fase_hilang" ]; then
  echo "$fase_hilang"
  echo "   Sebab: nilai baku `pulse:` adalah 0, dan bintang yang diam di"
  echo "   layar pertama adalah cacat yang tidak bisa dilihat gerbang lain."
  status=1
else
  echo "Bersih: setiap pemanggilan menyebut fase yang dikirimnya."
fi

# ── Aturan 41: nama objek yang tampil wajib melewati pelokalan ─────────────
#
# Cacat yang ditutup aturan ini **tersembunyi oleh kode yang benar** di
# atasnya, dan karena itu tidak pernah terlihat walau seluruh suite hijau.
#
#   ObjectDetailView.objectDisplayName  ->  displayName ?? object.name
#
# `CelestialObject.name` adalah data engine yang memuat bentuk Bahasa
# Indonesia yang dibekukan (`Saturnus`, `Bulan`, `Merkurius`). Pemanggil di
# `PointingView` **selalu** meneruskan `engine.displayedObjectName(object)`,
# jadi cabang kiri yang benar menutupi cabang kanan yang salah: selama tidak
# ada yang memanggil tanpa `displayName`, cacatnya tidak pernah dieksekusi --
# dan tidak ada uji Linux yang bisa mengeksekusinya, karena `Apps/` tidak
# pernah dibangun `swift-test.sh`.
#
# Terukur hari ini di salinan utuh: mengganti `Text(objectDisplayName)` di
# judul kartu menjadi `Text(object.name)` -- persis bentuk yang dipakai
# cabang cadangan itu -- membuat **ke-40 aturan tetap hijau** (exit 0).
# Begitu pula `displayedObjectName -> object.name`, yang mengembalikan
# bentuk Indonesia ke **empat** permukaan sekaligus.
#
# Yang diawasi di sini bukan "apakah `object.name` dipakai" (ia sah untuk
# pengenal dan kunci), melainkan **satu bentuk**: `?? object.name`, yaitu
# jatuh kembali ke nama engine di tempat nama untuk layar diharapkan.
# Bentuknya sempit sengaja -- gerbang yang menuduh `object.name` di mana pun
# akan memerah pada kode yang benar, dan gerbang yang memerah pada kode
# benar akan dilonggarkan orang.
#
# **Kenapa fail-closed, dan kenapa lantainya bukan "harus ada temuan".**
# Bila tidak ada satu pun berkas `Apps/` yang terbaca, aturan ini
# menganggap itu GAGAL: nol pembacaan berarti pembacanya berhenti melihat,
# bukan berarti bersih. Sebaliknya, **nol temuan dengan berkas terbaca
# adalah keadaan yang benar** setelah keempat situs diperbaiki --
# menjadikannya kegagalan akan membuat gerbang mustahil dipuaskan, dan
# gerbang seperti itu akan dimatikan orang.
echo
echo "== Aturan 41: nama yang tampil tidak jatuh kembali ke nama engine =="
nama_mentah=$(python3 - <<'PY' 2>&1
import os, re

# Nama objek yang tampil lewat `.name` — dua bentuk, satu cacat.
#
#   1. `?? <pengenal>.name`   -> cabang cadangan ke `CelestialObject.name`
#   2. `?.name` pada objek    -> rantai opsional, tanpa `??` sama sekali
#
# Bentuk kedua **tidak** tertangkap versi pertama aturan ini, dan itu terukur:
# `Experiment1View` merakit `intent.best?.name` tiga kali (baris layar, baris
# terucap, dan pesan status di `ExperimentRecorder`), dan `intent.best` adalah
# `CelestialObject` yang namanya diisi `PointingResolver` dari
# `EphemerisBody.displayName` — Bahasa Indonesia yang dibekukan (`Bulan`,
# `Saturnus`). Pola lama menuntut pengenal **sebelum** titik, jadi `best?.name`
# lolos dan seluruh gerbang UI tetap hijau.
POLA_CADANGAN = re.compile(r"\?\?\s*[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\.name\b")
# `?.name` hanya ditandai bila barisnya menyebut sesuatu yang memang membawa
# `CelestialObject`/`PointingTarget`: receiver `best`, `object`, `target`,
# `displayedObject`, atau `intent`. Sengaja sempit — `preferredFrame?.name`
# atau `calibrationTarget?.name` bukan nama engine dan tidak dibekukan.
POLA_RANTAI = re.compile(
    r"\b(best|object|target|displayedObject|intent|candidate)"
    r"(?:\.[A-Za-z_]\w*)?\?\.name\b"
)
# Bentuk ketiga: akses **langsung**, tanpa `?` dan tanpa `??`.
#
#     Text(target.name)      <- daftar acuan kalibrasi
#
# Ini yang paling mudah lolos: tidak ada `??`, tidak ada `?.`, jadi kedua
# pola di atas diam. Yang menahannya bukan pola yang lebih pintar,
# melainkan daftar penerima yang sempit — hanya nama yang di repo ini
# memang membawa `CelestialObject`/`PointingTarget`. `preferredFrame.name`
# dan `MountFrame.name` sengaja di luar daftar karena keduanya label
# internal app yang tidak dibekukan engine.
POLA_LANGSUNG = re.compile(
    r"\b(best|object|target|displayedObject|intent|candidate)\.name\b"
)
# Bentuk keempat: medan nama **yang dibawa** antar-permukaan, bukan
# `CelestialObject.name` langsung.
#
#     state.objectName          <- layar Tautan (nama dari jam)
#     command.objectName        <- layar serah-terima teleskop
#     message.objectName        <- service tautan
#
# Ketiga medan itu diisi dari `snapshot.answeredObject?.name` /
# `object.name` / `slew.object.name` — semuanya bentuk Indonesia yang
# dibekukan engine. Ketiganya **juga** membawa `objectID`, jadi nama yang
# benar bisa diselesaikan di sisi pembaca; yang dilarang adalah mencetak
# medan mentahnya ke layar.
#
# Kenapa pola terpisah, bukan menambah `objectName` ke daftar penerima di
# atas: nama medannya beda, dan mencampurnya membuat pesan temuan menyebut
# `CelestialObject.name` untuk sesuatu yang bukan itu.
POLA_MEDAN = re.compile(
    r"\b(best|object|target|state|message|command|intent|candidate)\.objectName\b"
)

#: Baris tempat sebuah nama **sampai ke layar**.
#:
#: `POLA_MEDAN` saja akan memerah pada kode yang benar: bentuk perbaikannya
#: adalah menyerahkan medan itu ke penyelesai nama
#:
#:     DisplayLabel.telescopeTargetName(carriedName: command.objectName, ...)
#:
#: — di situ `command.objectName` memang dibaca, tapi sebagai **cadangan**
#: yang hanya dipakai kalau katalog tidak mengenal id-nya, bukan sebagai teks
#: yang dicetak. Gerbang yang menuduh baris itu akan memerah pada kode benar,
#: dan gerbang seperti itu akan dilonggarkan orang.
#:
#: Jadi yang diperiksa dua hal sekaligus: baris itu menggambar sesuatu
#: (`row(`/`Text(`/`accessibilityLabel`/`LinkStatusText.`), **dan** namanya
#: tidak sedang diserahkan ke penyelesai (`carriedName:`). Keduanya sempit
#: dengan sengaja.
KONTEKS_GAMBAR = re.compile(r"\b(row\(|Text\(|accessibilityLabel|LinkStatusText\.)")
PENYERAHAN = re.compile(r"\bcarriedName\s*:")

# ── Aturan 41: nama objek yang tampil wajib melewati pelokalan ─────────────

masalah = []
diperiksa = 0
berkas_dibaca = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        teks = open(path, encoding="utf-8").read()
        berkas_dibaca += 1
        # Cakupan sengaja **sempit**: hanya berkas yang benar-benar
        # menangani nama objek langit. `MountFrame.name` adalah label
        # internal app yang tidak dibekukan engine -- menuduhnya akan
        # membuat gerbang merah pada kode yang benar, dan gerbang seperti
        # itu akan dilonggarkan orang.
        #
        # **`PointingTarget` ikut, dan dulu tidak.** Versi sebelumnya
        # menyebut `CalibrationTarget.name` sebagai contoh sah -- tipe
        # yang **tidak ada** di repo ini. Daftar acuan kalibrasi justru
        # mengulang `[PointingTarget]`, dan `PointingTarget.name` diisi
        # engine dari `EphemerisBody.displayName` (`Bulan`, `Saturnus`),
        # jadi berkas itu lolos hanya karena gerbangnya menyebut tipe
        # yang salah. `localizedName` di struct yang sama sudah jadi
        # jalur benar yang dipakai pemilih target Experiment 1.
        #
        # **`PointingLinkMessage`/`TelescopeCommand` juga**, dan itu
        # menutup lubang yang sama sekali lain: kedua layar itu
        # (Tautan, serah-terima teleskop) **tidak menyebut**
        # `CelestialObject` sama sekali — mereka membaca medan
        # `.objectName` yang dibawa pesan. Jadi berkasnya lolos penyaring
        # bahkan setelah cakupannya dilebarkan, dan bentuknya lolos kedua
        # pola karena tidak ada `??` maupun `?.`. Terukur: mengembalikan
        # kedua baris ke `.objectName` mentah membuat Aturan 41 tetap
        # mencetak "Bersih".
        if ("CelestialObject" not in teks and "displayedObject" not in teks
                and "PointingTarget" not in teks
                and "PointingLinkMessage" not in teks
                and "TelescopeCommand" not in teks
                # `LinkView` membaca `link.lastState` tanpa pernah menamai
                # tipenya, jadi daftar tipe di atas tetap melewatkannya.
                # Medan `.objectName` sendiri yang jadi penandanya — dan
                # pola yang memakainya sudah sempit (`state.`/`message.`/
                # `command.`), jadi melebarkan penyaring ini tidak
                # menambahkan tuduhan baru pada kode yang benar.
                and ".objectName" not in teks):
            continue
        baris_teks = teks.split("\n")
        for nomor, baris in enumerate(baris_teks, start=1):
            # Komentar dibuang: repo ini mendokumentasikan `?? object.name`
            # sebagai bentuk yang dilarang, dan docstring yang menyebutnya
            # bukan pemakaian.
            kode = baris.split("//", 1)[0]
            m = (POLA_CADANGAN.search(kode) or POLA_RANTAI.search(kode)
                 or POLA_LANGSUNG.search(kode))
            # `POLA_MEDAN` hanya berbunyi bila baris itu **menggambar**
            # medannya. Baris yang menyerahkannya ke penyelesai nama
            # (`carriedName:`) sengaja diam — lihat `PENYERAHAN`.
            if (not m and POLA_MEDAN.search(kode)
                    and KONTEKS_GAMBAR.search(kode)
                    and not PENYERAHAN.search(kode)):
                m = POLA_MEDAN.search(kode)
            if not m:
                continue
            diperiksa += 1
            masalah.append(
                "  %s:%d: `%s` -- `CelestialObject.name` memuat bentuk "
                "Bahasa Indonesia yang dibekukan (`Saturnus`, `Bulan`), "
                "jadi nama ini tidak mengikuti bahasa perangkat. Pakai "
                "`ObjectDisplayName.text(of:)` atau "
                "`DisplayLabel.objectName(forObjectID:catalogue:)`."
                % (path, nomor, m.group(0).strip()))

# Lantai non-vakuositas: bukan "harus ada temuan" (nol temuan justru
# keadaan yang benar setelah diperbaiki), melainkan "pembacanya masih
# membaca". Bila tidak ada berkas `Apps/` yang terbaca sama sekali, aturan
# ini tidak mengukur apa pun dan tidak boleh diam.
if berkas_dibaca == 0:
    print("TIDAK ADA berkas Swift di Apps/ yang terbaca -- aturan ini tidak "
          "mengukur apa pun")
elif masalah:
    print("\n".join(masalah))
    print("-> Cabang cadangan nama ikut mewarisi bentuk engine; pemanggil "
          "yang meneruskan `displayName` menutupinya, sehingga cacatnya "
          "hanya muncul pada pemanggil yang tidak meneruskannya.")
PY
)
if printf '%s' "$nama_mentah" | grep -q "Traceback\|^error:\|Error:"; then
  echo "Pemeriksaan Aturan 41 gagal dijalankan:"
  echo "$nama_mentah"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$nama_mentah" ]; then
  echo "$nama_mentah"
  status=1
else
  echo "Bersih: tidak ada nama tampilan yang jatuh kembali ke nama engine."
fi

# ── Aturan 42: permukaan **bukan-Bool** di Apps/ juga meneruskan faktanya ──
#
# Cacat yang ditutup aturan ini **diukur, bukan disangka**. Aturan 38 mengawal
# badan permukaan kejujuran di `Apps/` — tetapi **hanya yang bertipe `Bool`**
# (`var x: Bool { ... }`). Saudaranya yang bertipe lain tidak pernah dibaca:
#
#     displayedObject           CelestialObject?  -> snapshot.displayedObject(lastLocked:)
#     pointing                  HorizontalCoord?  -> snapshot.reportedPointing
#     answeredIntent            CelestialIntent?  -> controller.answeredIntent
#
# Ketiganya meneruskan fakta model ke lapisan UI, dan ketiganya hidup di
# `Apps/`, yang **tidak pernah dibangun** `swift-test.sh` di Linux. Terukur
# pada salinan utuh (proses baru, `Apps/` + `Packages/` dibawa) dengan mutasi
# yang **mengompilasi**:
#
#     displayedObject -> lastLockedObject        swift-ui-lint.sh LULUS (exit 0)
#
# yaitu: setiap permukaan menampilkan objek yang terakhir terkunci sebagai
# jawaban **sekarang**. Jam, panel iPhone, layar redup, dan Diagnostics
# serentak menyatakan objek yang tidak sedang ditunjuk — dan tidak satu pun
# gerbang berbunyi, karena seluruh pemanggil tetap mengirim
# `engine.displayedObject` apa adanya (yang dijaga Aturan 34/35/38 hanya
# **argumen** dan **badan Bool**, bukan badan `CelestialObject?`).
#
# **Kenapa aturan ini menurunkan permukaannya, bukan mendaftar namanya.**
# Daftar nama tangan akan basi diam-diam — persis yang terjadi pada daftar
# gerbang dan daftar jangkar yang sudah dua kali menjatuhkan `main` di repo
# ini. Yang dipakai sebagai sumber kebenaran: setiap `var <nama>: T? { ... }`
# (dan `T` non-Bool) di `Apps/` yang namanya **ada sebagai anggota model** di
# `Packages/PointingKit`. Nama yang bukan anggota model (mis. `let name: String?`
# milik berkas view, `@AppStorage` sendiri) bukan keputusan engine dan tidak
# diawasi — gerbang yang menuduh kode benar akan dilonggarkan orang.
#
# **Batas yang dinyatakan, bukan disangka tertutup.** Aturan ini sapu teks,
# bukan pemeriksa tipe: ia tahu **bentuk** badannya (penerusan satu ekspresi),
# tidak tahu nilai yang dihasilkannya. Cabang yang menambahkan `.map { ... }`
# atau `?? ...` tetap lolos bila menyebut nama anggotanya. Yang ditutup adalah
# bentuk yang paling senyap: badan yang **sama sekali tidak** menyebut faktanya.
echo
echo "== Aturan 42: permukaan bukan-Bool di Apps/ juga meneruskan faktanya =="
permukaan_nilai=$(python3 - <<'PY' 2>&1
import os, re

PK = os.path.join("Packages", "PointingKit", "Sources", "PointingKit")
if not os.path.isdir(PK):
    print("Tidak bisa membaca %s -- aturan ini tidak bisa memutuskan." % PK)
    raise SystemExit(0)


def kode_saja(teks):
    """Buang komentar `//` dan isi literal string (sama seperti Aturan 38)."""
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam_str, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam_str:
                if esc:
                    esc = False
                    buf.append(" ")
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam_str = False
                    buf.append('"')
                else:
                    buf.append(" ")
            else:
                if ch == '"':
                    dalam_str = True
                    buf.append('"')
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


# 1. Anggota model: properti **dan** fungsi — semua tipe, bukan hanya Bool.
#    Aturan 38 menurunkan yang Bool; di sini yang penting adalah namanya ada,
#    supaya nama UI yang meneruskannya bisa dikenali.
anggota = set()
for root, _, files in os.walk(PK):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        src = kode_saja(open(os.path.join(root, name), encoding="utf-8").read())
        for m in re.finditer(r"\bvar\s+([A-Za-z_]\w*)\s*:", src):
            anggota.add(m.group(1))
        for m in re.finditer(r"\bfunc\s+([A-Za-z_]\w*)\s*\(", src):
            anggota.add(m.group(1))

if not anggota:
    print("Tidak ada anggota model; aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

# Nama sisi-UI untuk anggota model yang dinamai lain (lihat PASANGAN di
# Aturan 38): `pointing` meneruskan `reportedPointing`.
PASANGAN = {"pointing": "reportedPointing"}

# `var <nama>: <Tipe>? {` -- **non-Bool** saja; Bool milik Aturan 38.
DEKL = re.compile(r"\bvar\s+([A-Za-z_]\w*)\s*:\s*([A-Za-z_][\w.<>?, ]*?)\s*\?\s*\{")
masalah = []
diperiksa = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = kode_saja(open(path, encoding="utf-8").read())
        for m in DEKL.finditer(kode):
            nama, tipe = m.group(1), m.group(2).strip()
            # `[X: Y]?` dan tipe lain di luar cakupan sempit ini bukan
            # permukaan kejujuran; biarkan.
            if tipe in ("Bool",):
                continue
            if nama not in anggota and nama not in PASANGAN:
                continue  # bukan keputusan engine
            i, d, j = m.end(), 1, m.end()
            while j < len(kode) and d:
                if kode[j] == "{":
                    d += 1
                elif kode[j] == "}":
                    d -= 1
                j += 1
            badan = " ".join(kode[i:j - 1].split())
            if not badan:
                continue  # `{ get }` / protokol: tidak punya badan di sini
            diperiksa += 1
            baris = kode[:m.start()].count("\n") + 1
            sumber = PASANGAN.get(nama, nama)
            if re.match(r"^\s*(nil|\.none)\s*$", badan):
                masalah.append(
                    "  %s:%d: `var %s: %s?` berbadan literal `%s` -- "
                    "permukaan selalu kosong, jadi pengguna tidak pernah "
                    "melihat hasil pengukuran"
                    % (path, baris, nama, tipe, badan))
                continue
            if not re.search(r"\b" + re.escape(sumber) + r"\b", badan):
                masalah.append(
                    "  %s:%d: `var %s: %s?` berbadan `%s` -- tidak menyebut "
                    "`%s`, jadi nilainya diambil dari keadaan yang bukan "
                    "sumbernya" % (path, baris, nama, tipe, badan, sumber))

if diperiksa == 0:
    print("Tidak ada permukaan bukan-Bool di Apps/; aturan ini tidak "
          "mengukur apa pun.")
elif masalah:
    print("\n".join(masalah))
    print("-> Teruskan faktanya apa adanya (`snapshot.<anggotanya>(...)`): "
          "permukaan ini yang memberi tahu pengguna hasil pengukuran yang "
          "berlaku sekarang, bukan objek dari arah tunjuk sebelumnya.")
PY
)
if printf '%s' "$permukaan_nilai" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 42 gagal dijalankan:"
  echo "$permukaan_nilai"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$permukaan_nilai" ]; then
  echo "$permukaan_nilai"
  status=1
else
  echo "Bersih: setiap permukaan bukan-Bool di Apps/ meneruskan faktanya."
fi

# ── Aturan 43: teks yang dirakit di Apps/ harus hidup di PointingKit ──
#
# Cacat siklus ini, dan tidak satu pun dari 42 aturan di atas yang bisa
# melihatnya:
#
#   `ReducedLuminanceView.reducedAccessibilityLabel` merakit enam sumber di
#   `Apps/`, dan melewatkan catatan sensor yang justru tampil di layar.
#
# Ia **String yang dirakit**, ia `private` di `Apps/`, dan ia tidak pernah
# dieksekusi di Linux — jadi tidak ada uji yang bisa memerahkannya. Aturan
# 34/35/36/38/42 masing-masing mengurus *satu* fakta yang diteruskan; yang
# merakit beberapa sumber tidak masuk cakupan satupun.
#
# **Yang TIDAK ditangkap aturan ini, meski sempat tertulis di sini.** Versi
# pertama docstring ini menyebut `visualForDisplayedObject` sebagai cacat
# "bentuk yang sama". Itu **salah ukur**: mutasi
# `displayedObject -> lastLockedObject` pada properti itu diukur menjalankan
# **seluruh** lint (exit 0, "SEMUA GERBANG UI LULUS"), jadi aturan ini tidak
# menangkapnya — deteksinya menyapu `String`, sedangkan properti itu
# mengembalikan `CelestialVisual?`. Celah itu ditutup **Aturan 44**, yang
# menyapu hasil bertipe `CelestialVisual`. Dua aturan, dua kelas: String
# (43) dan identitas gambar (44). Menyatukannya dalam satu sapu akan
# menghasilkan deteksi longgar yang menuduh kode benar.
#
# Aturan ini menutup **kelasnya**, bukan satu barisnya: anggota `private` di
# `Apps/` yang merangkai dua fakta engine atau lebih menjadi satu String
# adalah calon cacat, dan harus dirakit di `PointingKit` (tempat ia bisa
# diuji). Bentuk yang tertinggal di `Apps/` dilaporkan.
#
# **Kenapa deteksinya menyempit pada `parts`/`joined`.** Pemeriksaan longgar
# ("setiap anggota private yang menyebut dua fakta") juga menangkap
# `fullView`, `start`, dan `exportDocument` — badan yang memang **harus**
# tinggal di view. Daftar yang panjang dan semuanya boleh dikecualikan
# adalah gerbang yang akan dimatikan orang pada hari pertama. Yang dicari
# di sini hanya pola **perangkaian teks**: `parts` + `joined`, bentuk yang
# dipakai kedua cacat itu persis.
#
# **Batas yang diukur, bukan diasumsikan: fakta dihitung per komponen
# pertama.** `engine.snapshot.state`, `engine.snapshot.guidanceText`, dan
# `engine.snapshot.angularRateDegPerSec` semuanya terbaca sebagai satu fakta
# bernama `snapshot`. Alasannya bukan kecerobohan: menghitung sampai komponen
# terakhir (`engine\.((?:\w+\.)*\w+)`) membuat `statusAccessibilityLabel`
# — yang merangkai tiga fakta tapi **hanya** mengambil keputusan "kapan
# parts.append", dan setiap teksnya sudah lahir di `RowSpeech` — dilaporkan
# sebagai cacat. Diukur: versi itu merah pada pohon bersih. Gerbang yang
# menuduh kode benar akan dilonggarkan orang, jadi yang dipilih adalah
# hitungan yang kasar tetapi tidak pernah menuduh. Konsekuensinya dinyatakan:
# mutasi yang mengganti **sumber panduan** di dalam anggota itu membuat aturan
# ini diam.
echo "== Aturan 43: teks yang dirakit di Apps/ harus hidup di PointingKit =="
rakitan=$(python3 - <<'PY' 2>&1
import os, re


def kode_saja(teks):
    """Buang komentar `//` — sama seperti Aturan 38."""
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam = False
            else:
                if ch == '"':
                    dalam = True
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


berkas = []
for root, _, files in os.walk("Apps"):
    for f in files:
        if f.endswith(".swift"):
            berkas.append(os.path.join(root, f))

if not berkas:
    print("PERINGATAN: tidak ada berkas Swift di Apps/ -- aturan ini tidak "
          "bisa memutuskan.")
    raise SystemExit(0)

masalah = []
for jalur in berkas:
    teks = kode_saja(open(jalur, encoding="utf-8").read())
    baris = teks.split("\n")
    for m in re.finditer(r"private (?:var|func)\s+(\w+)([^{]*)\{", teks):
        nama, sig = m.group(1), m.group(2)
        # Hanya perangkaian teks: yang mengembalikan String.
        if "String" not in sig:
            continue
        awal = teks[:m.start()].count("\n")
        dalam_kurung, akhir = 0, awal
        for j in range(awal, min(awal + 60, len(baris))):
            dalam_kurung += baris[j].count("{") - baris[j].count("}")
            if dalam_kurung == 0 and j > awal:
                akhir = j
                break
        else:
            akhir = min(awal + 60, len(baris) - 1)
        badan = "\n".join(baris[awal:akhir + 1])
        # Bentuk yang dicari: mengisi wadah lalu menggabungnya.
        if not re.search(r"\.joined\(|\bparts\b", badan):
            continue
        fakta = set(re.findall(r"engine\.(\w+)", badan))
        # Satu fakta tidak butuh perakitan; dua ke atas adalah cacat yang
        # sudah dua kali terjadi.
        if len(fakta) < 2:
            continue
        masalah.append(
            "  `%s` di %s merangkai %d fakta engine (%s) menjadi satu String "
            "di dalam Apps/. Berkas ini tidak pernah dibangun di Linux, jadi "
            "tidak ada uji yang bisa memerahkannya -- pindahkan perakitannya "
            "ke PointingKit, seperti `ReducedLuminanceLabel` dan `RowSpeech`."
            % (nama, jalur, len(fakta), ", ".join(sorted(fakta))))

print("\n".join(masalah))
PY
)
if printf '%s' "$rakitan" | grep -q "Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 43 gagal dijalankan:"
  echo "$rakitan"
  echo "-> Aturan ini tidak bisa memutuskan; anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$rakitan" ]; then
  echo "$rakitan"
  status=1
else
  echo "Bersih: tidak ada String yang dirangkai dari beberapa fakta di Apps/."
fi

# ── Aturan 44: objek yang digambar tidak boleh dipilih sendiri di Apps/ ──
#
# Saudaranya Aturan 43, dan lahir dari cacat yang **docstring Aturan 43 sendiri
# sebut** tapi tidak bisa ditangkapnya:
#
#   `PointingEngine.visualForDisplayedObject` mengembalikan `CelestialVisual?`
#   dan merakitnya dari `displayedObject` + fraksi fase + sudut sisi terang di
#   `Apps/`. Mengganti `displayedObject` jadi `lastLockedObject` membuat seluruh
#   43 aturan di atas tetap hijau (terukur: menjalankan seluruh `swift-ui-lint.sh`
#   di atas salinan yang dimutasi -> exit 0, "SEMUA GERBANG UI LULUS"), sementara
#   kartu menampilkan nama Jupiter dengan gambar cincin Saturnus.
#
# Yang membedakannya dari cacat String: di sini hasilnya adalah **identitas
# gambar**, bukan teks. `CelestialVisual` memang tinggal di `Packages/`, tapi
# *pemilihan objek* yang dirakit di `Apps/` tidak pernah dieksekusi di Linux.
# Perbaikannya dulu (siklus "gambar objek tak bisa lagi berasal dari benda
# selain yang tertulis di kartunya") memindahkan pemilihan itu ke
# `PointingSnapshot.displayedVisual(lastLocked:)`, yang meneruskan `object`
# dari `displayedObject` dan karenanya tidak bisa disodori benda lain. Tapi
# **gerbang** yang menutup pemindahan itu tidak pernah ditulis — jadi mutasi
# yang memutar balik pemindahan itu buta sampai hari ini.
#
# Aturan ini menutup **pemilihan bendanya**, bukan pembuatan gambarnya.
# `CelestialVisual(...)` boleh tetap dirakit di `Apps/` — faktanya (fraksi fase,
# arah, sudut sisi terang) sengaja dijaga Aturan 31 sebagai *nilai* di sini, dan
# memindahkannya ke Swift murni hanya ikut memindahkan pemeriksaannya. Yang
# **tidak** boleh: objeknya dipilih di `Apps/`.
#
# Terukur, bukan teoretis: `let object = displayedObject` -> `let object =
# lastLockedObject` di `visualForDisplayedObject` membuat seluruh lint lulus
# (exit 0, "SEMUA GERBANG UI LULUS"), sementara kartu menampilkan nama Jupiter
# dengan gambar cincin Saturnus. Kedua pengikatan itu **sama-sama sah** secara
# sintaks, sama-sama bukan `nil`, dan tidak ada teks di layar yang membedahnya.
#
# Karena itu yang dituntut bukan "jangan panggil ctor", melainkan **syarat
# ketat pada pengikatan**: `let object = <sumber>` di `Apps/` hanya boleh
# bersumber dari jalur yang namanya menyebut objek yang **sedang ditampilkan**
# (`displayedObject`, `displayedVisual(...)`). Menyebut `lastLockedObject`,
# `answeredObject`, `intent?.best`, atau `lastLocked` sebagai sumber langsung
# dilaporkan. Daftar sumber yang diterima sengaja **pendek dan tertulis**:
# daftar panjang berarti gerbang yang akan dilonggarkan pada hari pertama.
#
# Catatan jujur tentang cakupannya: ini **sapu teks**, bukan pemeriksa tipe.
# Ia membaca nama di sebelah kanan `=`, bukan nilai yang dihasilkannya.
# `displayedObject` yang disalurkan lewat variabel perantara tidak terlihat.
echo "== Aturan 44: objek yang digambar tidak dipilih sendiri di Apps/ =="
rakitan44=$(python3 - <<'PY' 2>&1
import os, re

#: Sumber yang **boleh** jadi kanan `let object = ...` di `Apps/`. Semuanya
#: jalur yang turun dari `displayedObject(lastLocked:)`, jadi tidak ada satupun
#: yang bisa berbeda dari objek yang namanya tertulis di kartu.
SUMBER_SAH = (
    "displayedObject",
    "displayedVisual",
)

#: Sumber yang **dilarang**. Daftar ini hanya memperjelas **pesan**-nya: yang
#: menentukan adalah `SUMBER_SAH` di atas (daftar putih). Sumber yang tidak
#: dikenal tetap dilaporkan -- cacat yang dulu lolos adalah bentuk yang belum
#: terpikirkan, jadi daftar hitam persis yang akan tertinggal.
SUMBER_TERLARANG = (
    "lastLockedObject",
    "lastLocked",
    "answeredObject",
    "bestObject",
    "intent?.best",
    "intent.best",
)


def kode_saja(teks):
    """Buang komentar `//` — sama seperti Aturan 38/43."""
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam = False
            else:
                if ch == '"':
                    dalam = True
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


#: Nama lokal yang menandai "objek yang sedang ditampilkan". Disengaja sempit:
#: `object` dipakai konsisten di keempat situs yang diukur.
IKATAN = re.compile(r"\blet\s+(object|displayed)\s*=\s*([A-Za-z_?][^\n]*?)\s*$")

berkas = []
for root, _, files in os.walk("Apps"):
    for f in files:
        if f.endswith(".swift"):
            berkas.append(os.path.join(root, f))

if not berkas:
    print("PERINGATAN: tidak ada berkas Swift di Apps/ -- aturan ini tidak "
          "bisa memutuskan.")
    raise SystemExit(0)

TERHITUNG = 0
masalah = []
for jalur in berkas:
    teks = kode_saja(open(jalur, encoding="utf-8").read())
    for nomor, baris in enumerate(teks.split("\n"), 1):
        m = IKATAN.search(baris)
        if not m:
            continue
        kanan = m.group(2)
        TERHITUNG += 1
        if any(s in kanan for s in SUMBER_SAH):
            continue
        # Bukan daftar hitam: sumber yang **tidak dikenal** tetap dilaporkan,
        # karena bentuk yang belum terpikirkan persis yang dulu lolos. Nama
        # terlarang hanya memperjelas pesannya.
        larang = [s for s in SUMBER_TERLARANG if s in kanan] or ["sumber yang tidak dikenal"]
        if True:
            masalah.append(
                "  %s:%d  `let %s = %s` -- objek yang digambar diambil dari "
                "%s, bukan dari objek yang sedang ditampilkan. Kartu bisa "
                "menampilkan nama satu benda dengan gambar benda lain, dan "
                "Apps/ tidak pernah dibangun di Linux sehingga tidak ada uji "
                "yang memerahkannya. Pakai `displayedObject` / "
                "`displayedVisual(lastLocked:)`." %
                (jalur, nomor, m.group(1), kanan, "/".join(larang)))

if TERHITUNG == 0:
    # Fail-closed: nol ikatan terbaca berarti pembacanya berhenti melihat,
    # bukan berarti tidak ada yang perlu dijaga.
    print("PERINGATAN: tidak satu pun pengikatan `let object = ...` terbaca di "
          "Apps/ -- aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

print("\n".join(masalah))
PY
)
if printf '%s' "$rakitan44" | grep -q "PERINGATAN\|Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 44 tidak bisa memutuskan:"
  echo "$rakitan44"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$rakitan44" ]; then
  echo "$rakitan44"
  status=1
else
  echo "Bersih: objek yang digambar selalu dari objek yang sedang ditampilkan."
fi

# ── Aturan 45: pemilih palet tidak boleh ditulis sendiri di Apps/ ──────────
#
# Cacat yang ditutup aturan ini **diukur**, bukan disangka.
# `Apps/Shared/SurfaceTokens.swift` punya satu properti yang memilih palet
# untuk **26 situs** di jam dan iPhone — latar aplikasi, alas kartu, teks
# utama & sekunder, gradien aksen, garis rambut, warna nada, isi badge, dan
# layar redup:
#
#     static var active: SurfacePalette { return NightMode.isOn ? .night : .day }
#
# Terukur pada salinan utuh (proses baru, `Apps/` + `Packages/` dibawa),
# dengan mutasi yang semuanya mengompilasi:
#
#     return .day                            swift-ui-lint.sh LULUS (exit 0)
#     return .night                          swift-ui-lint.sh LULUS (exit 0)
#     return NightMode.isOn ? .day : .night  swift-ui-lint.sh LULUS (exit 0)
#     return Bool.random() ? .night : .day   swift-ui-lint.sh LULUS (exit 0)
#
# Empat keadaan, **nol** yang berbunyi. Yang paling sunyi bukan yang acak,
# melainkan `return .day`: mode malam — satu-satunya mode yang rhodopsin
# izinkan (batang rod paling sensitif ~498-530nm, cahaya >620nm aman) — lalu
# memancarkan **biru dan hijau penuh** sementara tombol bulan di layar menyala
# seakan ia aktif. Pengamat yang sedang mengamati bintang lemah kehilangan
# adaptasi gelapnya 20-40 menit karena satu baris di berkas yang tidak punya
# gerbang. Tidak ada teks di layar yang membantahnya: labelnya bertuliskan
# "mode malam", warnanya berkata lain.
#
# Kenapa Aturan 38/42 tidak menangkapnya: keduanya menurunkan permukaan yang
# **namanya ada sebagai anggota model** dan menuntut badannya "menyebut
# faktanya". `active` memang anggota `SurfacePalette`, dan
# `NightMode.isOn ? .day : .night` **menyebut** `NightMode` — jadi kedua
# aturan itu lulus pada pemetaan yang terbalik sekalipun. Yang salah bukan
# apakah faktanya disebut, melainkan **bagaimana ia dipakai**: di sini ia
# menjadi syarat percabangan, bukan nilai yang diteruskan.
#
# Kenapa perbaikannya struktural, bukan menambah daftar: pemilihnya dipindah
# ke `NightPaletteSelector` (PointingKit) dan dijaga uji
# (`SurfacePaletteTests`), sedangkan `Apps/` cuma meneruskan keadaan saklarnya.
# Aturan ini menutup **sisi `Apps/`** dari kelas yang sama: badan
# `SurfacePalette.active` tidak boleh lagi menulis percabangan palet itu
# sendiri.
#
# Yang TIDAK diklaim: ini sapu teks atas bentuk `return ... ? .night : .day`
# (dan kebalikannya). Pemetaan yang disembunyikan di balik fungsi helper atau
# variabel perantara tetap tidak terlihat — itulah sebabnya uji di PointingKit
# ikut menahan nilai kembaliannya, bukan cuma bentuknya.
echo "== Aturan 45: pemilih palet tidak ditulis sendiri di Apps/ =="
rakitan45=$(python3 - <<'PY' 2>&1
import os, re

#: Bentuk percabangan palet yang **dilarang** ditulis di `Apps/`: keduanya
#: palet langsung, atau syarat yang memilih di antara keduanya.
POLA = (
    re.compile(r"[?]\s*\.night\s*:\s*\.day"),
    re.compile(r"[?]\s*\.day\s*:\s*\.night"),
    re.compile(r"return\s+\.day\s*$"),
    re.compile(r"return\s+\.night\s*$"),
    # Badan yang hanya berisi palet itu sendiri: `static var active { .day }`.
    # Bentuk ini tidak memakai `?` sama sekali, jadi tanpa pola ini ia lolos —
    # terukur: keadaan "selalu .day" tetap hijau sebelum pola ini ada.
    re.compile(r"^\s*\.day\s*$"),
    re.compile(r"^\s*\.night\s*$"),
)

masalah = []
diperiksa = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        # Buang komentar agar doc-comment yang mengutip bentuk lama tidak
        # memicu aturan ini (sama seperti Aturan 38/42).
        kode = open(path, encoding="utf-8").read()
        buf = []
        for baris in kode.split("\n"):
            if "//" in baris:
                baris = baris.split("//", 1)[0]
            buf.append(baris)
        kode = "\n".join(buf)
        for i, baris in enumerate(kode.split("\n"), 1):
            if not any(p.search(baris) for p in POLA):
                continue
            # Hanya baris kode: abaikan yang masih sisa string/dokumentasi.
            bersih = baris.strip()
            if bersih.startswith("///") or bersih.startswith("*") or '"' in bersih:
                continue
            diperiksa += 1
            masalah.append(
                "  %s:%d: `%s` -- pemilihan palet ditulis sendiri di Apps/. "
                "Pakai `NightPaletteSelector.palette(isNightModeEnabled:)` "
                "(PointingKit, teruji di Linux); berkas ini tidak pernah "
                "dibangun swift-test.sh." % (path, i, baris.strip()[:90]))

if diperiksa == 0 and not os.path.isdir("Apps"):
    print("PERINGATAN: Apps/ tidak terbaca -- aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

print("\n".join(masalah))
PY
)
if printf '%s' "$rakitan45" | grep -q "PERINGATAN\|Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 45 tidak bisa memutuskan:"
  echo "$rakitan45"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$rakitan45" ]; then
  echo "$rakitan45"
  status=1
else
  echo "Bersih: pemilihan palet selalu lewat NightPaletteSelector."
fi

# ── Aturan 46: peristiwa yang berbunyi tidak boleh dipilih sendiri di Apps/ ──
#
# Cacat yang ditutup aturan ini **diukur**, bukan disangka.
# `Apps/Shared/AudioCue.swift` punya satu baris yang memutuskan peristiwa mana
# yang boleh terdengar seperti berhasil:
#
#     guard AudioCue.isOn, events.contains(.lockSucceeded) else { return }
#
# Itu bukan rincian implementasi, melainkan **politik PRD**: hanya
# `lockSucceeded` yang boleh berbunyi. Bunyi saat engine ragu adalah false
# confidence yang berwujud suara — dan itu satu-satunya saluran bagi pengguna
# yang tidak melihat layar, jadi tidak ada teks yang bisa membantahnya.
#
# Terukur pada salinan utuh (proses baru, `Apps/` + `Packages/` dibawa),
# dengan mutasi yang semuanya mengompilasi:
#
#     guard ... events.contains(.lockSucceeded) ...    swift-ui-lint.sh LULUS
#     guard ... .lockSucceeded || .uncertain ...       swift-ui-lint.sh LULUS
#     guard AudioCue.isOn                              swift-ui-lint.sh LULUS
#     return                                           swift-ui-lint.sh LULUS
#
# Empat keadaan, **nol** yang berbunyi. Yang paling sunyi bukan yang terakhir
# (bunyi hilang, cukup terlihat) melainkan yang kedua: engine ragu berbunyi
# **persis** seperti engine yakin, dan tidak ada gerbang yang melihatnya.
#
# Kenapa Aturan 38/42 tidak menangkapnya: keduanya menurunkan permukaan yang
# **namanya ada sebagai anggota model** (properti `var X: Bool { ... }`).
# `play(_:)` adalah fungsi berbadan banyak-pernyataan yang menerima daftar
# peristiwa; tidak ada nama permukaan untuk ditambat, dan yang salah bukan
# "apakah `lockSucceeded` disebut" melainkan **aturan pemilihan**-nya.
#
# Kenapa perbaikannya struktural: pemilihnya dipindah ke `AudioEventPolicy`
# (PointingKit) dan dijaga uji (`AudioEventPolicyTests`), sedangkan `Apps/`
# hanya meneruskan daftar peristiwa + saklarnya. Aturan ini menutup **sisi
# `Apps/`** dari kelas yang sama: badan `play` tidak boleh lagi memilih
# peristiwa audible sendiri.
#
# Yang TIDAK diklaim: ini sapu teks atas pemilihan peristiwa yang **ditulis
# langsung** di `Apps/` (`contains(.lockSucceeded)`, `== .lockSucceeded`,
# `case .lockSucceeded` di dalam fungsi yang menerima `[HapticEvent]`).
# Pemilihan yang disembunyikan di balik fungsi helper tetap tidak terlihat —
# itulah sebabnya uji di PointingKit ikut menahan nilai kembaliannya.
echo "== Aturan 46: peristiwa berbunyi tidak dipilih sendiri di Apps/ =="
rakitan46=$(python3 - <<'PY' 2>&1
import os, re

#: Bentuk pemilihan peristiwa audible yang **dilarang** ditulis di `Apps/`.
#: Sengaja sempit ke nama peristiwa yang benar-benar menentukan bunyi, supaya
#: aturan ini tidak menuduh pemakaian sah `lockSucceeded` di tempat lain
#: (mis. label VoiceOver yang menyebut objek terkunci).
POLA = (
    re.compile(r"contains\s*\(\s*\.lockSucceeded\s*\)"),
    re.compile(r"\.lockSucceeded\s*=="),
    re.compile(r"==\s*\.lockSucceeded"),
    re.compile(r"contains\s*\(\s*\.uncertain\s*\)"),
)

#: Nama berkas/fungsi yang memang berisi keputusan bunyi. Hanya di sana pola di
#: atas berarti "memilih peristiwa audible"; di tempat lain (label, lencana)
#: ia bisa sah. Diukur: tanpa pembatas ini, aturan menuduh docstring Aturan 46
#: sendiri dan `CelestialVisual` yang menyebut `.lockSucceeded` untuk teks.
KONTEKS = re.compile(r"AudioCue|play\s*\(")

masalah = []
diperiksa = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = open(path, encoding="utf-8").read()
        # Buang komentar agar doc-comment yang mengutip bentuk lama tidak
        # memicu aturan ini (sama seperti Aturan 38/42/45).
        buf = []
        for baris in kode.split("\n"):
            if "//" in baris:
                baris = baris.split("//", 1)[0]
            buf.append(baris)
        kode = "\n".join(buf)
        for i, baris in enumerate(kode.split("\n"), 1):
            if not any(p.search(baris) for p in POLA):
                continue
            bersih = baris.strip()
            # Hanya baris kode: abaikan yang masih sisa string/dokumentasi.
            if bersih.startswith("///") or bersih.startswith("*") or '"' in bersih:
                continue
            # Di luar berkas pemegang keputusan bunyi, pola ini belum tentu
            # soal audio — jangan menuduh yang sah.
            if not KONTEKS.search(path) and not KONTEKS.search(bersih):
                continue
            diperiksa += 1
            masalah.append(
                "  %s:%d: `%s` -- pemilihan peristiwa berbunyi ditulis sendiri "
                "di Apps/. Pakai `AudioEventPolicy.shouldPlay(events:"
                "isAudioEnabled:)` (PointingKit, teruji di Linux); berkas ini "
                "tidak pernah dibangun swift-test.sh." % (path, i, bersih[:90]))

if diperiksa == 0 and not os.path.isdir("Apps"):
    print("PERINGATAN: Apps/ tidak terbaca -- aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

print("\n".join(masalah))
PY
)
if printf '%s' "$rakitan46" | grep -q "PERINGATAN\|Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 46 tidak bisa memutuskan:"
  echo "$rakitan46"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$rakitan46" ]; then
  echo "$rakitan46"
  status=1
else
  echo "Bersih: pemilihan peristiwa berbunyi selalu lewat AudioEventPolicy."
fi

# ── Aturan 47: getaran "ragu" tidak boleh dipilih sendiri di Apps/ ──
#
# Kembar dari Aturan 46, dan cacatnya **diukur** sebelum ditutup.
#
# Getaran adalah satu-satunya saluran yang tidak butuh mata saat jam diangkat
# — tepat situasi produk ini. Kalau `.uncertain` berbunyi pola yang sama
# dengan `.lockSucceeded`, pengguna yang mengandalkan getaran tidak punya cara
# apa pun membedakan "terkunci" dari "kurang yakin".
#
# Keputusan itu ditulis **dua kali** di `Apps/`:
#
#     Apps/PointAndKnowWatch/Sources/HapticEngine.swift
#         case .uncertain: device.play(.retry)
#     Apps/PointAndKnowiOS/Sources/PhoneHapticEngine.swift
#         case .uncertain: UIImpactFeedbackGenerator(style: .rigid)
#
# Terukur pada salinan utuh (proses baru, `Apps/` + `Packages/` dibawa), dengan
# mutasi yang semuanya mengompilasi:
#
#     case .uncertain: device.play(.success)      swift-ui-lint.sh LULUS
#     case .uncertain: <efek yang sama>           swift-ui-lint.sh LULUS
#
# Dua keadaan, **nol** yang berbunyi. Dan dua salinan berarti memperbaiki satu
# tidak memperbaiki yang lain.
#
# Kenapa Aturan 38/42 tidak menangkapnya: tidak ada properti bernama di model
# untuk ditambat. Yang salah adalah **isi `switch`** di dalam fungsi berbadan
# banyak-pernyataan.
#
# Perbaikannya struktural, sama seperti Aturan 46: pemetaannya dipindah ke
# `HapticPolicy` (PointingKit, diuji `HapticPolicyTests` di Linux), dan kedua
# `Apps/` hanya menerjemahkan pola ke API platform masing-masing.
#
# Yang TIDAK diklaim: ini sapu teks atas `case .<peristiwa>:` yang ditulis
# **langsung** di berkas yang memainkan getaran. Pemetaan yang disembunyikan di
# balik fungsi helper tidak terlihat — itulah sebabnya uji di PointingKit ikut
# menahan nilai kembaliannya, bukan cuma bentuk kodenya.
echo "== Aturan 47: getaran ragu tidak dipilih sendiri di Apps/ =="
rakitan47=$(python3 - <<'PY' 2>&1
import os, re

#: Berkas yang benar-benar memainkan getaran. Di luar ini, `case .uncertain:`
#: bisa sah (mis. lencana keraguan di complication), jadi jangan menuduh.
BERKAS = re.compile(r"Haptic")

#: Pola yang berarti "Apps/ memilih sendiri pola untuk sebuah peristiwa".
#: `case .x:` di dalam `switch` atas `HapticEvent` adalah bentuknya; begitu
#: juga pencocokan langsung `event == .x` yang memilih efek.
POLA = re.compile(
    r"case\s+\.(lockSucceeded|uncertain|sensorUnavailable|returnedToIdle)\s*:"
    r"|==\s*\.(lockSucceeded|uncertain|sensorUnavailable|returnedToIdle)\b"
)

#: Penanda bahwa keputusan sudah didelegasikan — badan yang memakai
#: `HapticPolicy` boleh (dan memang harus) menyebut peristiwa.
#:
#: **Tidak dipakai sebagai jalan keluar.** Versi pertama aturan ini melewati
#: seluruh berkas bila `HapticPolicy.pattern` muncul di mana pun di dalamnya.
#: Harness membuktikan itu salah: berkas yang mendelegasikan di satu tempat dan
#: memutuskan sendiri di tempat lain tetap hijau — persis kelas cacat yang
#: aturan ini klaim tutup. Karena itu tidak ada lagi jalan keluar per-berkas;
#: yang diperiksa adalah **barisnya**, dan `switch` atas pola memakai nama
#: `completed`/`unsettled`/`failed`/`tick`, yang tidak cocok dengan pola di
#: bawah. Tidak perlu pengecualian.

masalah = []
diperiksa = 0
berkas_dilihat = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift") or not BERKAS.search(name):
            continue
        berkas_dilihat += 1
        path = os.path.join(root, name)
        kode = open(path, encoding="utf-8").read()
        # Buang komentar: doc-comment yang mengutip bentuk lama (seperti di
        # `HapticEngine.swift`) tidak boleh memicu aturan ini.
        buf = []
        for baris in kode.split("\n"):
            if "//" in baris:
                baris = baris.split("//", 1)[0]
            buf.append(baris)
        kode = "\n".join(buf)
        for i, baris in enumerate(kode.split("\n"), 1):
            bersih = baris.strip()
            if bersih.startswith("///") or bersih.startswith("*") or '"' in bersih:
                continue
            if not POLA.search(bersih):
                continue
            diperiksa += 1
            masalah.append(
                "  %s:%d: `%s` -- pola getaran per peristiwa dipilih sendiri "
                "di Apps/. Pakai `HapticPolicy.pattern(for:)` (PointingKit, "
                "teruji di Linux); berkas ini tidak pernah dibangun "
                "swift-test.sh." % (path, i, bersih[:90]))

# Fail-closed: aturan yang tidak menemukan satu pun berkas getaran tidak
# mengukur apa pun. Lebih jujur memerah daripada melaporkan "Bersih" atas nol
# pembacaan — `Apps/` yang berubah nama cukup untuk membuat aturan ini tidur.
if berkas_dilihat == 0:
    print("PERINGATAN: tidak ada berkas getaran yang terbaca di Apps/ -- "
          "aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

print("\n".join(masalah))
PY
)
if printf '%s' "$rakitan47" | grep -q "PERINGATAN\|Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 47 tidak bisa memutuskan:"
  echo "$rakitan47"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$rakitan47" ]; then
  echo "$rakitan47"
  status=1
else
  echo "Bersih: pola getaran per peristiwa selalu lewat HapticPolicy."
fi

# ── Aturan 48: angka gerak tidak boleh ditulis sendiri di Apps/ ─────────────
#
# Kembar dari Aturan 45/46/47, tetapi cacatnya **terukur di dua saluran
# sekaligus** dan satu di antaranya saya sendiri yang menciptakannya.
#
# Saluran pertama: `TimelineView(.animation(minimumInterval: 1.0 / 30.0))`
# ditulis tangan di tiga layar. Angka itu bukan angka tampilan — `TimelineView`
# menyegarkan **seluruh** `Canvas`, jadi setiap frame menggambar ulang planet,
# pita, cincin, dan kabut yang pikselnya tidak berubah. Di jam tangan, itu
# baterai; di iPhone, CPU untuk satu titik cahaya. Terukur pada salinan utuh
# (proses baru), dengan mutasi yang mengompilasi:
#
#     1.0 / 30.0  ->  1.0 / 60.0   di DiagnosticsView.swift
#     swift-ui-lint.sh LULUS (exit 0)
#
# Saluran kedua: `withAnimation(.spring(response: 0.42, dampingFraction:
# 0.82))` — angka pop saat kunci. Ini **umpan balik bahwa identifikasi
# berhasil**, dan ia ditulis terpisah di jam dan iPhone. Siklus yang menulis
# aturan ini memindahkan angkanya ke `MotionPolicy.LockArrival`, lalu mengukur
# apakah pemindahan itu dijaga sesuatu:
#
#     .spring(response: 0.90, dampingFraction: 0.30) + appearScale = 1.60
#     di PointingView.swift            swift-ui-lint.sh LULUS (exit 0)
#
# Nol dari 47 aturan. Yang membuatnya layak ditutup: pemindahan angka ke
# `PointingKit` **tidak menutup apa pun** kalau `Apps/` masih boleh menulis
# angkanya sendiri. Uji di Linux menahan nilai di model; hanya gerbang yang
# bisa menahan bahwa view benar-benar membacanya.
#
# Yang TIDAK diklaim: ini sapu teks atas dua bentuk yang **ditulis langsung**.
# Angka yang lewat variabel perantara (`let r = 0.42; .spring(response: r)`)
# atau yang dirakit fungsi helper tidak terlihat. Itu sebabnya uji
# `LockArrivalMotionTests`/`PulseFrameRateTests` menahan **nilai** di model,
# sementara aturan ini menahan **dari mana** `Apps/` mengambilnya.
echo "== Aturan 48: angka gerak tidak ditulis sendiri di Apps/ =="
rakitan48=$(python3 - <<'PY' 2>&1
import os, re

#: Dua bentuk angka gerak yang dimiliki `MotionPolicy`:
#:   - interval penyegar `TimelineView` (ongkos baterai)
#:   - bentuk pegas `withAnimation` (umpan balik "kunci berhasil")
POLA = [
    (re.compile(r"minimumInterval\s*:\s*[0-9]"),
     "interval `TimelineView` ditulis sebagai angka",
     "`MotionPolicy.pulseFrameInterval`"),
    (re.compile(r"\.spring\s*\(\s*response\s*:\s*[0-9]"),
     "bentuk pegas `.spring(response:)` ditulis sebagai angka",
     "`MotionPolicy.LockArrival`"),
    (re.compile(r"dampingFraction\s*:\s*[0-9]"),
     "redaman `.spring(dampingFraction:)` ditulis sebagai angka",
     "`MotionPolicy.LockArrival`"),
]

masalah = []
berkas_dilihat = 0
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = open(path, encoding="utf-8").read()
        # Buang komentar: docstring yang mengutip bentuk lama tidak boleh
        # memicu aturan ini. (Siklus lalu: Aturan 45 sempat menuduh dirinya
        # sendiri karena membaca komentarnya sendiri.)
        buf = []
        for baris in kode.split("\n"):
            if "//" in baris:
                baris = baris.split("//", 1)[0]
            buf.append(baris)
        kode = "\n".join(buf)
        berkas_dilihat += 1
        for i, baris in enumerate(kode.split("\n"), 1):
            for pola, sebab, saran in POLA:
                if pola.search(baris):
                    masalah.append(
                        "  %s:%d: %s -- pakai %s (PointingKit, teruji di "
                        "Linux); berkas ini tidak pernah dibangun "
                        "swift-test.sh." % (path, i, sebab, saran))

# Fail-closed: nol berkas terbaca berarti aturan ini tidak mengukur apa pun.
# `Apps/` yang berubah nama cukup untuk membuatnya tidur.
if berkas_dilihat == 0:
    print("PERINGATAN: tidak ada berkas Apps/ yang terbaca -- aturan ini "
          "tidak mengukur apa pun.")
    raise SystemExit(0)

print("\n".join(masalah))
PY
)
if printf '%s' "$rakitan48" | grep -q "PERINGATAN\|Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 48 tidak bisa memutuskan:"
  echo "$rakitan48"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$rakitan48" ]; then
  echo "$rakitan48"
  status=1
else
  echo "Bersih: angka gerak selalu lewat MotionPolicy."
fi

# ── Aturan 49: layar penuh memakai latar aplikasi yang **sama** ─────────────
#
# Cacat yang ditutup: `OnboardingView` — layar **pertama** yang dilihat
# pengguna — adalah satu-satunya layar penuh yang menggambar
# `SurfacePalette.appBackground` mentah, bukan `appBackdrop()`. Akibatnya ia
# kehilangan langit berbintang yang dimiliki lima layar lain, dan justru di
# tempat yang paling menentukan kesan pertama: pengguna membuka app astronomi
# dan melihat satu gradien dua warna.
#
# Kenapa tidak ada gerbang yang berbunyi. `appBackdrop()` benar-benar dipakai
# di lima berkas, jadi sapuan "apakah ada layar memakai latar" hijau. Yang
# tidak terlihat adalah **ketiadaannya di berkas keenam** — kelas cacat yang
# sama dengan Aturan 40: gerbang yang memeriksa keberadaan tidak melihat
# ketiadaan. Diukur pada salinan utuh (proses baru, 48 aturan):
#
#     OnboardingView: appBackground mentah   -> SEMUA GERBANG UI LULUS
#
# Aturan ini menuntut: setiap berkas `Apps/**` yang mendeklarasikan sebuah
# `View` **dan** menyentuh latar aplikasi harus menyebut `appBackdrop`.
# Menyebut `SurfacePalette.appBackground` tanpa `appBackdrop` di berkas yang
# sama = merah.
#
# Kenapa `appBackground()` (helper lama di `SurfaceTokens`) tidak dipakai
# sebagai penanda sah. Ia **dead code**: nol pemanggil di seluruh repo, dan
# ia justru bentuk yang menghasilkan cacat ini — gradien polos tanpa langit.
# Membiarkannya sebagai jalan keluar yang sah berarti aturan ini bisa
# dipuaskan oleh latar yang salah.
#
# Batasnya jujur: ini sapu teks per berkas, bukan pelacakan aliran. Layar
# yang membangun latarnya di berkas lain (mis. lewat sebuah container) tidak
# terlihat; bentuk itu belum ada hari ini dan tidak diklaim tertutup.
echo "== Aturan 49: layar penuh memakai latar aplikasi yang sama =="
rakitan49=$(python3 - <<'PY' 2>&1
import os
import re

masalah = []
berkas_layar = 0
# Kode (komentar dibuang) tiap berkas yang mendeklarasikan View. Dipakai arah
# ketiga di bawah, yang harus melihat **satu berkas utuh** dan bukan satu
# `struct`, karena latar dipasang per berkas.
kode_per_berkas = []
wadah_terbaca = 0

for root, dirs, files in os.walk("Apps"):
    dirs[:] = [d for d in dirs if d not in (".build", "build")]
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        kode = open(path, encoding="utf-8").read()
        # Buang komentar: docstring di berkas ini banyak mengutip bentuk
        # lama, dan kutipan itu tidak boleh memicu aturan (kelas cacat yang
        # sudah dua kali terjadi di repo ini).
        baris_kode = []
        for baris in kode.split("\n"):
            if "//" in baris:
                baris = baris.split("//", 1)[0]
            baris_kode.append(baris)
        kode = "\n".join(baris_kode)

        # Hanya berkas yang benar-benar mendeklarasikan View.
        if not re.search(r"struct\s+\w+\s*:\s*View\b", kode):
            continue
        kode_per_berkas.append((path, kode))
        wadah_terbaca += len(re.findall(r"\b(?:List|Form|ScrollView)\b\s*(?:\{|\()",
                                        kode))
        # Berkas yang **memang** menyusun gradiennya sendiri. Ia satu-satunya
        # tempat `SurfacePalette.appBackground` sah: dialah yang membungkus
        # gradien itu bersama langit menjadi `AppBackdropView`, dan semua
        # layar lain memakai hasilnya. Kalau ia ikut dilarang, aturannya
        # melarang dirinya sendiri.
        if os.path.basename(path) == "SkyBackdropView.swift":
            berkas_layar += 1
            continue
        # **Satu-satunya hal yang diperiksa: gradien mentah di kode.**
        #
        # Versi pertama aturan ini menuntut "menyebut `appBackdrop`", dan itu
        # lebih lemah dalam dua arah sekaligus. Terukur di harness:
        #
        #   1. `AppBackdropView()` (bentuk yang BENAR) tidak cocok dengan
        #      penanda `appBackdrop` huruf kecil, jadi `OnboardingView` yang
        #      sudah diperbaiki **dilewati** — hijau karena tidak melihat
        #      apa-apa, persis kelas cacat yang aturan ini klaim tutup.
        #   2. Berkas yang memanggil `appBackdrop()` **dan** menggambar
        #      gradien mentah di cabang lain tetap hijau, padahal cabang itu
        #      tampil tanpa langit.
        #
        # Menegasikan bentuk yang salah menutup keduanya tanpa daftar
        # pengecualian: setiap pemakaian `appBackground` di luar berkas
        # pembungkusnya adalah cacat, terlepas dari apa lagi yang ada di
        # berkas itu.
        if "appBackground" not in kode:
            continue
        berkas_layar += 1
        masalah.append(
            "  %s: memakai `SurfacePalette.appBackground` mentah -- layar "
            "ini kehilangan langit berbintang yang dimiliki layar lain. "
            "Pakai `appBackdrop()` atau `AppBackdropView()`." % path)

# ── Arah ketiga: `appBackdrop()` yang **dipasang tapi tertutup** ──────────
#
# Dua pemeriksaan di atas menanyakan "apakah `appBackground` dipakai mentah".
# Keduanya menjawab **tidak** untuk layar yang sama sekali tidak menyentuh
# latar — dan bentuk itulah yang terukur luput di siklus ini.
#
#   `SkyContextView` (jam)  membungkus isinya dalam `List { … }` tanpa
#                           `.scrollContentBackground(.hidden)`.
#   `CalibrationView` (jam) membungkus isinya dalam `ScrollView { … }` tanpa
#                           `.appBackdrop()` sama sekali.
#
# Keduanya **exit 0** pada 50 aturan. Layar konteks langit lalu tampil dengan
# latar bawaan sistem — permukaan terang di mode malam yang paletnya sengaja
# dibuat tanpa cahaya biru/hijau, dan tanpa langit berbintang di mode siang.
# Ini kelas cacat yang sama dengan asal Aturan 49 (`OnboardingView`), hanya
# satu langkah lebih jauh: bukan latar yang salah, melainkan **tidak ada
# latar**.
#
# Yang diperiksa, dan **kenapa keduanya**, bukan salah satunya:
#
#   a. `List`/`Form` **wajib** menyembunyikan latar bawaannya. Tanpa
#      `.scrollContentBackground(.hidden)`, `appBackdrop()` boleh terpasang
#      dan tetap tak terlihat — hijau palsu, persis cacat yang harness
#      gerbang ini dibangun untuk menangkap.
#   b. `ScrollView` tanpa `.scrollContentBackground(.hidden)` juga **wajib**
#      memasang `appBackdrop()`. Kalau sudah menyembunyikan latar bawaannya,
#      `appBackdrop()` di berkas yang sama sudah cukup (atau ia sudah
#      menumpang latar induk yang benar — `ReducedLuminanceView` menyembunyikan
#      latar dan memasang `appBackdrop(starfield: false)` di level yang sama).
#
# Cakupannya **seluruh berkas**, bukan per `struct`: `PointingView.swift`
# memuat dua layar, dan latar dipasang per berkas — menuntut per `struct`
# akan membuat layar kedua menuduh layar pertama yang sudah benar.
for path, kode in kode_per_berkas:
    if os.path.basename(path) == "SkyBackdropView.swift":
        continue          # dialah yang membangun latarnya.
    bungkus = re.findall(r"\b(List|Form|ScrollView)\b\s*(?:\{|\()", kode)
    if not bungkus:
        continue
    tersembunyi = ".scrollContentBackground(.hidden)" in kode
    punya_latar = "appBackdrop(" in kode
    if ("List" in bungkus or "Form" in bungkus) and not tersembunyi:
        masalah.append(
            "  %s: memakai `List`/`Form` tanpa `.scrollContentBackground"
            "(.hidden)` -- latar bawaan sistem menutupi latar aplikasi, jadi"
            " `appBackdrop()` (kalau ada) tidak terlihat di mode malam" % path)
    elif "ScrollView" in bungkus and not tersembunyi and not punya_latar:
        masalah.append(
            "  %s: memakai `ScrollView` tanpa `.appBackdrop()` dan tanpa "
            "`.scrollContentBackground(.hidden)` -- layar ini tampil dengan "
            "permukaan bawaan sistem, bukan latar aplikasi" % path)

# Fail-closed: nol berkas layar terbaca berarti aturan ini tidak mengukur
# apa pun. `Apps/` yang berubah nama cukup untuk membuatnya tidur.
if berkas_layar == 0:
    print("PERINGATAN: tidak ada berkas layar yang menyentuh latar -- "
          "aturan ini tidak mengukur apa pun.")
    raise SystemExit(0)

# Fail-closed arah ketiga: tanpa satu pun wadah yang terbaca, pemeriksaan
# baru di atas diam dan gerbang ini hijau karena tidak melihat apa-apa.
if wadah_terbaca == 0:
    print("PERINGATAN: tidak ada List/Form/ScrollView yang terbaca di Apps/ "
          "-- arah ketiga Aturan 49 tidak mengukur apa pun.")
    raise SystemExit(0)

print("\n".join(masalah))
PY
)
if printf '%s' "$rakitan49" | grep -q "PERINGATAN\|Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 49 tidak bisa memutuskan:"
  echo "$rakitan49"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$rakitan49" ]; then
  echo "$rakitan49"
  status=1
else
  echo "Bersih: setiap layar memakai latar aplikasi yang sama."
fi

# ── Aturan 50: ciri pengenal planet berhenti saat engine ragu ──────────────
#
# Satu baris di `Apps/Shared/CelestialVisualView.swift` adalah satu-satunya
# yang menghentikan ketujuh ciri pengenal planet (pita Jupiter, cincin
# Saturnus, tudung es Mars, kawah Merkurius, kabut Venus, piringan Uranus,
# piringan Neptunus) tampil saat engine belum yakin:
#
#   baris 334  `guard isConfirmed else { return }`
#
# **Kenapa gerbang ini harus ada: cacatnya terukur tak terlihat.** Baris itu
# dihapus (mutasi), lalu seluruh 49 aturan UI dijalankan di proses baru:
# **exit 0, "SEMUA GERBANG UI LULUS"**. `swift test` tidak bisa menolong
# karena ia hanya membangun `Packages/` — berkas ini hidup di `Apps/`, yang
# tidak pernah dibangun di Linux. Jadi sampai aturan ini ada, menghapus
# penjaga yang menahan cincin Saturnus pada kandidat yang belum terkunci
# tidak menghasilkan satu pun kegagalan.
#
# **Kenapa Aturan 32 tidak menutupnya.** Aturan 32 memeriksa dua hal: bahwa
# lencana `drawCandidateMarker` digambar saat `!isConfirmed`, dan bahwa
# `drawSphere` dilewat saat `isConfirmed` salah **dan** cirinya `.rings`.
# Keduanya **tetap hijau** setelah mutasi di atas: lencananya masih digambar
# (baris 63), dan `drawSphere` masih dijaga (baris 324). Yang hilang justru
# baris yang menahan `drawBands`/`drawRings`/`drawPolarCaps`/… — yaitu
# **ciri pengenalnya sendiri**. Lencana tanda tanya di atas cincin Saturnus
# bukan kejujuran: cirinya sudah telanjur tampil, dan mata membaca cincin
# lebih dulu daripada lencana.
#
# **Kenapa `Palette.drawable(isConfirmed:)` tidak cukup, meski ia benar.**
# `drawable` sudah mengembalikan `feature: .none` saat ragu, jadi hari ini
# kedua penjaga itu **tumpang tindih** dan mutasinya diam. Itu justru
# alasan aturan ini diperlukan, bukan alasan untuk tidak menulisnya:
# penjaga ganda yang tidak dijaga adalah penjaga yang akan dihapus orang
# sebagai "duplikat", dan saat itu yang tersisa tinggal `drawable` —
# sebuah kebetulan yang tidak ada yang mengukurnya. Aturan ini mengunci
# **keduanya** ada dan sejalan.
#
# Yang diperiksa: `switch palette.feature` di dalam `drawPlanet` harus
# berada **setelah** sebuah `guard isConfirmed`-negatif pada jalur yang sama.
# Dicari sebagai teks, bukan sebagai pohon sintaks — `swiftc -parse` tidak
# dijalankan atas `Apps/`, dan bentuk yang dicari cukup sempit.
echo
echo "== Aturan 50: ciri pengenal planet berhenti saat engine ragu =="
ragu=$(python3 - <<'PY' 2>&1
import os
import re

VIEW = "Apps/Shared/CelestialVisualView.swift"

if not os.path.exists(VIEW):
    print("PERINGATAN: %s tidak ada." % VIEW)
    raise SystemExit

kode = open(VIEW, encoding="utf-8").read()
# Komentar dibuang: docstring berkas ini mengutip bentuk lama (termasuk
# `guard isConfirmed` itu sendiri) di beberapa tempat, dan kutipan itu
# tidak boleh terbaca sebagai kenyataan.
kode = re.sub(r"//[^\n]*", "", kode)
kode = re.sub(r"/\*.*?\*/", "", kode, flags=re.S)

masalah = []

# 1. Penjaga harus ada, dan harus menghentikan fungsi (bukan sekadar `if`).
#
#    Dua bentuk yang sah, dan keduanya **berhenti saat engine ragu**:
#
#      `guard isConfirmed else { return }`      afirmatif + `else`
#      `if isConfirmed == false { return }`     ekuivalen yang ditulis lain
#
#    Bentuk **terbalik** — `guard !isConfirmed else { return }` — adalah
#    cacat pada arah sebaliknya: ia berhenti saat engine **yakin**, jadi
#    ciri pengenal justru tampil hanya pada kandidat. Karena itu tanda `!`
#    diperiksa secara terpisah, bukan sekadar "ada `isConfirmed`".
penjaga = re.findall(
    r"guard\s+([^{;]{0,120}?)\s+else\s*\{\s*return\s*\}", kode)
penjaga += re.findall(
    r"if\s+([^{;]{0,120}?)\s*\{\s*return\s*\}", kode)
# Penjaga sah: menyebut `isConfirmed` **tanpa** dinegasikan.
penjaga_ragu = [k.strip() for k in penjaga
                if "isConfirmed" in k and "!isConfirmed" not in k]
# Penjaga terbalik: `isConfirmed` dinegasikan, sehingga yang dihentikan
# justru keadaan yakin.
penjaga_terbalik = [k.strip() for k in penjaga if "!isConfirmed" in k]
if penjaga_terbalik:
    masalah.append(
        "  penjaga `%s` menghentikan `drawPlanet` saat engine **yakin**; "
        "ciri pengenal akan tampil hanya pada kandidat yang belum terkunci "
        "-- kebalikan dari yang diminta PRD" % penjaga_terbalik[0])
if not penjaga_ragu:
    masalah.append(
        "  tidak ada `guard !isConfirmed … else { return }` di %s; ketujuh "
        "ciri pengenal planet (pita, cincin, tudung es, kawah, kabut, "
        "piringan) akan digambar pada kandidat yang belum terkunci" % VIEW)

# 2. Ciri pengenal harus **ditarik** dari `palette.feature`, bukan ditulis
#    sendiri, dan switch-nya harus ada — kalau tidak, penjaga nomor 1
#    menjadi penjaga atas sesuatu yang tidak pernah digambar (hijau palsu).
tubuh = re.sub(r"\s+", " ", kode)
if not re.search(r"switch\s+palette\.feature\s*\{", tubuh):
    masalah.append(
        "  `switch palette.feature` tidak ditemukan di %s; ciri pengenal "
        "tidak lagi dibaca dari palet yang teruji di Linux" % VIEW)

# 3. Penjaga harus mendahului switch ciri pengenal, **di dalam `drawPlanet`**.
#
#    Tanpa syarat urut ini, `guard` bisa diletakkan di fungsi lain dan
#    aturan tetap hijau sementara ciri pengenalnya bocor. Dicari di dalam
#    tubuh `drawPlanet` — `guard isConfirmed` juga muncul di fungsi lain
#    (`drawMoon`), jadi mencarinya di seluruh berkas membuat urutannya
#    tertukar dengan penjaga milik fungsi yang berbeda.
if penjaga_ragu and re.search(r"switch\s+palette\.feature\s*\{", tubuh):
    i_fn = kode.find("func drawPlanet(")
    if i_fn < 0:
        masalah.append(
            "  `drawPlanet` tidak ditemukan di %s; penjaga tidak bisa "
            "dipastikan menahan ciri pengenal planet" % VIEW)
    else:
        # Batas fungsi berikutnya: deklarasi `private func` / `func` pada
        # kolom pertama.
        lanjut = kode.find("\n    private func ", i_fn)
        if lanjut < 0:
            lanjut = kode.find("\n    func ", i_fn)
        tubuh_fn = kode[i_fn:(lanjut if lanjut > 0 else len(kode))]
        # Penjaga dicari dalam **dua** bentuk yang sah, sama seperti
        # pemeriksaan 1: `guard isConfirmed else` maupun
        # `if isConfirmed == false`. Mengunci hanya bentuk `guard` membuat
        # aturan ini merah pada penjaga yang ditulis ekuivalen -- gerbang
        # yang merah pada kode benar akan dimatikan orang.
        i_guard = tubuh_fn.find("guard isConfirmed")
        if i_guard < 0:
            i_guard = tubuh_fn.find("if isConfirmed == false")
        if i_guard < 0:
            i_guard = tubuh_fn.find("if !isConfirmed")
        # **`rfind`, bukan `find`.** `switch palette.feature` muncul **dua
        # kali** di `drawPlanet`: yang pertama di dalam klip pita terang
        # (`if isConfirmed, let phase = …`), yang kedua setelah penjaga.
        # Memakai kemunculan pertama membuat urutannya tertukar dengan
        # switch yang sudah benar-benar terlindungi, dan aturan ini merah
        # pada kode yang benar — gerbang yang merah pada kode benar akan
        # dimatikan orang. Yang dijaga penjaga adalah switch **terakhir**,
        # tempat ketujuh ciri pengenal digambar tanpa syarat apa pun lagi.
        i_switch = tubuh_fn.rfind("switch palette.feature")
        if i_guard < 0 or i_switch < 0 or i_guard > i_switch:
            masalah.append(
                "  penjaga `isConfirmed` tidak mendahului "
                "`switch palette.feature` di dalam `drawPlanet`; ciri "
                "pengenal digambar sebelum sempat dihentikan")

print("\n".join(masalah) if masalah else "")
PY
)
if printf '%s' "$ragu" | grep -q "PERINGATAN\|Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 50 tidak bisa memutuskan:"
  echo "$ragu"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$ragu" ]; then
  echo "Ciri pengenal planet tidak lagi berhenti saat engine ragu:"
  echo "$ragu"
  echo "-> Cincin Saturnus atau pita Jupiter pada kandidat yang belum"
  echo "   terkunci adalah identitas yang diklaim gambar, bukan engine."
  status=1
else
  echo "Bersih: ciri pengenal planet berhenti tepat saat engine ragu."
fi

# ── Aturan 51: saputangan yang mengklaim identitas wajib membaca keyakinan ──
#
# Aturan 50 menutup **satu** jalur: `switch palette.feature` di `drawPlanet`.
# Dua jalur yang **sama persis kelasnya** tidak dijaga satu pun gerbang, dan
# keduanya diukur di siklus ini lewat mutasi pada pohon yang benar:
#
#   1. `if isConfirmed, let phase = visual.phaseGeometry(...)` di `drawPlanet`
#      — **fase planet dalam** (sabit Venus & Merkurius). Sabit adalah bentuk,
#      sama seperti cincin Saturnus. Penjaga `isConfirmed` dihapus -> seluruh
#      50 aturan tetap **exit 0**. Dibalik (`if !isConfirmed`) juga exit 0.
#   2. `planet.palette.drawable(isConfirmed: isConfirmed)` — **warna** planet.
#      Argumennya dihapus (`drawable()`; di Swift itu berarti palet penuh)
#      -> exit 0. `planet.palette` tanpa `drawable(...)` sama sekali -> exit 0.
#      Aturan 34 hanya menangkap `drawable(isConfirmed: true)` — **literal** —
#      bukan argumen yang hilang sama sekali.
#
# Kenapa Aturan 26 tidak menutupnya, meski ia tampak melakukan hal serupa.
# Aturan 26 memeriksa bahwa `TipePaket.anggota` ada di paket. `planet.palette`
# **memang anggota** `Planet`, jadi ia hijau; tidak ada gerbang yang menuntut
# nilainya disalurkan lewat `drawable(isConfirmed:)`.
#
# **Kenapa cakupannya `drawPlanet`, bukan seluruh berkas.** Kedua polanya
# muncul di tempat lain dengan teks yang sama persis, dan keduanya sah tanpa
# `isConfirmed`: `phaseGeometry(waxing: visual.isWaxing)` di `drawMoon` — fase
# Bulan adalah fakta tanggal, bukan hasil pencarian id, dan
# `check_moon_phase_survives_uncertainty` menuntutnya **tetap tampil** saat
# ragu — serta `.palette` di `drawRings`, yang dipakai untuk `saturnRing`
# (warna dari `CelestialVisual.accents`, token, bukan palet planet) sementara
# cincinnya sendiri sudah ditahan Aturan 50 dan 32. Menuntut `isConfirmed`
# di kedua situs itu berarti merah pada kode yang benar, dan gerbang yang
# merah pada kode benar akan dimatikan orang.
#
# Ini sapu teks, bukan pelacakan aliran: ia membuktikan situsnya **menyebut**
# keyakinan engine, bukan bahwa pikselnya berhenti berubah di perangkat
# (`Apps/` tidak pernah dibangun `swift-test.sh`, dan tidak ada Xcode di sini).
echo
echo "== Aturan 51: saputangan identitas wajib membaca keyakinan engine =="
klaim_ragu=$(python3 - <<'PY' 2>&1
import os
import re

VIEW = "Apps/Shared/CelestialVisualView.swift"

if not os.path.exists(VIEW):
    print("PERINGATAN: %s tidak ada." % VIEW)
    raise SystemExit

teks = open(VIEW, encoding="utf-8").read()
# Komentar dibuang: docstring berkas ini mengutip bentuk lama dari kedua
# situs ini (termasuk `if isConfirmed, let phase`), dan kutipan itu tidak
# boleh terbaca sebagai kenyataan. Alasan yang sama dengan Aturan 50.
kode = re.sub(r"//[^\n]*", "", teks)
kode = re.sub(r"/\*.*?\*/", "", kode, flags=re.S)

masalah = []

# Tubuh `drawPlanet`, dibatasi deklarasi fungsi berikutnya pada kolom
# pertama — bukan "sisa berkas". Tanpa batas ini, `phaseGeometry` milik
# `drawMoon` ikut dituntut berpenjaga dan gerbang ini merah pada kode benar.
i_fn = kode.find("func drawPlanet(")
if i_fn < 0:
    masalah.append(
        "  `drawPlanet` tidak ditemukan di %s; sabit planet dalam dan warna "
        "planet tidak bisa dipastikan membaca keyakinan engine" % VIEW)
else:
    lanjut = kode.find("\n    private func ", i_fn)
    if lanjut < 0:
        lanjut = kode.find("\n    func ", i_fn)
    tubuh = kode[i_fn:(lanjut if lanjut > 0 else len(kode))]

    def nomor_baris(offset):
        """Nomor baris di berkas asli untuk offset di dalam `tubuh`."""
        return kode[:i_fn].count("\n") + tubuh[:offset].count("\n") + 1

    # ── Situs 1: fase planet dalam ─────────────────────────────────────────
    # Dituntut: `if`/`guard` yang memuat panggilan ini menyebut `isConfirmed`
    # **tanpa** dinegasikan. `if !isConfirmed` adalah kebalikan arah yang
    # sama cacatnya dengan `guard !isConfirmed` di Aturan 50.
    for m in re.finditer(r"\bphaseGeometry\s*\(", tubuh):
        awal = tubuh.rfind("\n", 0, m.start()) + 1
        pernyataan = tubuh[awal:m.start() + 160]
        if not re.search(r"\b(if|guard)\b[^;{]*\bisConfirmed\b", pernyataan) \
                or re.search(r"\b(if|guard)\b[^;{]*!isConfirmed", pernyataan):
            masalah.append(
                "  %s:%d: `phaseGeometry(waxing:)` di `drawPlanet` tanpa "
                "penjaga `isConfirmed` — sabit Venus/Merkurius adalah bentuk "
                "pengenal, jadi ia tidak boleh digambar saat engine ragu"
                % (VIEW, nomor_baris(m.start())))

    # ── Situs 2: palet warna planet ────────────────────────────────────────
    # Warna planet adalah ciri pengenal yang paling cepat dibaca mata — lebih
    # cepat daripada teks di bawahnya — jadi nilainya **wajib** lewat
    # `drawable(isConfirmed:)`.
    #
    # Kenapa bukan sekadar "ada kata `drawable(` di berkas": `drawable()` tanpa
    # argumen **juga** mengandung kata itu, dan di Swift `drawable()` berarti
    # palet penuh — persis cacatnya. Yang dituntut karena itu adalah
    # argumennya, yaitu `isConfirmed:` **di dalam** tanda kurungnya — sama
    # seperti Aturan 24 menuntut argumen, bukan keberadaan nama fungsinya.
    palet_dipakai = False
    for m in re.finditer(r"\.palette\b", tubuh):
        palet_dipakai = True
        ekor = tubuh[m.end():m.end() + 200]
        pemanggilan = re.match(r"\s*\.drawable\s*\(", ekor)
        if not pemanggilan:
            masalah.append(
                "  %s:%d: `.palette` dipakai tanpa `drawable(isConfirmed:)` — "
                "warna planet adalah ciri pengenal, jadi ia tampil walau "
                "engine ragu" % (VIEW, nomor_baris(m.start())))
            continue
        j, depth, mulai = pemanggilan.end(), 1, pemanggilan.end()
        while j < len(ekor) and depth:
            if ekor[j] == "(":
                depth += 1
            elif ekor[j] == ")":
                depth -= 1
            j += 1
        args = ekor[mulai:j - 1]
        if not re.search(r"\bisConfirmed\s*:", args):
            masalah.append(
                "  %s:%d: `drawable(%s)` tanpa argumen `isConfirmed:` — warna "
                "planet diklaim tanpa membaca keyakinan engine"
                % (VIEW, nomor_baris(m.start()), args.strip()))

    if not palet_dipakai:
        # Bukan "bersih": tanpa situsnya aturan ini lulus pada pohon apa pun.
        # Kegagalan terbuka lebih buruk daripada tidak ada gerbang.
        masalah.append(
            "  tidak ada pemakaian `.palette` di dalam `drawPlanet` (%s); "
            "aturan ini kehilangan gigi dan akan lulus selamanya" % VIEW)

print("\n".join(masalah) if masalah else "")
PY
)
if printf '%s' "$klaim_ragu" | grep -q "PERINGATAN\|Traceback\|Error\|error:"; then
  echo "Pemeriksaan Aturan 51 tidak bisa memutuskan:"
  echo "$klaim_ragu"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$klaim_ragu" ]; then
  echo "$klaim_ragu"
  echo "-> Sabit planet dalam dan warna planet adalah ciri pengenal: keduanya"
  echo "   wajib membaca keyakinan engine, bukan diasumsikan terkunci."
  status=1
else
  echo "Bersih: sabit & warna planet membaca keyakinan engine."
fi

# ── Aturan 52: klaim keyakinan pada gambar/panel tidak boleh lewat nama lain ──
#
# Ke-51 aturan sebelumnya menjaga **dari mana** keyakinan datang: Aturan 34
# menuntut argumennya ada, Aturan 18 melarang nilai bawaannya `true`, dan dua
# aturan lain menolak `!isStale` sebagai penggantinya. Yang tidak dijaga satu
# pun: argumen yang **membaca keyakinan** tetapi menyebutnya lewat nama lain.
#
# `SITUS` mencakup **setiap** pemanggil yang meneruskan keyakinan ke gambar
# atau ke pembaca identitas: `CelestialVisualView` (penggambar), dan dua
# panel yang meneruskan `isConfirmed` ke gambar *serta* keempat aksesor
# `spoken*` — `LockArrivalPanel` (DiagnosticsView.swift) dan `ObjectDetailView`
# (PointingView.swift). Cakupan ini terukur buta sebelum diperluas: literal
# `true` pada kedua panel itu **exit 0** padahal membuka ciri pengenal pada
# kandidat yang engine belum kunci (lihat Tools/bukti-mutasi-keyakinan-visual.py,
# keadaan "panel iPhone"/"panel jam").
#
# Diukur pada salinan utuh (proses baru, `Apps/` + `Packages/` dibawa), dengan
# mutasi yang semuanya **mengompilasi** — hanya satu bentuk yang memerah:
#
#   isConfirmed: true                                    -> MERAH (Aturan 34)
#   isConfirmed: engine.isDisplayingStaleObject ? false
#                : engine.confirmsDisplayedIdentity       -> MERAH (Aturan 34)
#   let keyakinan = engine.confirmsDisplayedIdentity
#   isConfirmed: keyakinan                               -> **exit 0, semua lulus**
#   isConfirmed: CelestialVisualView.defaultConfirmation -> **exit 0, semua lulus**
#
# Bentuk terakhir yang paling sunyi: `defaultConfirmation` **tidak ada** di
# `CelestialVisualView`, jadi baris itu tidak bisa dikompilasi — dan justru
# itu yang membuatnya layak dijaga. Siapa pun yang "merapikan" nama panjang
# itu cukup menambahkan satu `static let` di view dan seluruh ciri pengenal
# (cincin Saturnus, pita Jupiter, warna spektral Betelgeuse) tampil pada
# kandidat yang engine belum kunci, di samping badge "Ragu".
#
# **Kenapa gerbang ini wajib, bukan sekadar rapi.** `Apps/` tidak pernah
# dibangun `swift-test.sh` di Linux; satu-satunya tempat nama yang tidak ada
# terlihat adalah runner macOS setelah push. Dan keyakinan adalah satu-satunya
# fakta yang keberadaannya menentukan apakah gambar mengklaim identitas.
#
# Bentuk yang diterima, dan **hanya** itu — daftar putih, bukan daftar hitam:
#
#   isConfirmed: <ekspresi>            di mana `<ekspresi>` menyebut
#                                      `confirmsDisplayedIdentity` langsung,
#                                      atau `isConfirmed` (meneruskan parameter)
#
# Daftar hitam tidak dipakai karena bentuk cacat yang dulu lolos adalah bentuk
# yang belum terpikirkan penulisnya. Fail-closed: nol situs terbaca = gagal,
# karena kalau konstruktor berganti nama, aturan ini akan hijau selamanya.
echo
echo "== Aturan 52: klaim keyakinan visual tidak lewat nama lain =="
keyakinan_nama=$(python3 - <<'PY' 2>&1
import os
import re

DEKL = re.compile(r'\b(?:let|var)\s+(?:isConfirmed|confirmsDisplayedIdentity)\b')
# Situs: setiap pemanggilan yang meneruskan keyakinan engine ke **gambar atau
# ke pembaca identitas**. Awalnya hanya `CelestialVisualView(`, dan bentuk itu
# terukur buta pada satu kelas cacat yang sama (lihat catatan panjang di atas
# `echo "== Aturan 52"`).
#
# **Daftar ini sekarang DITURUNKAN, bukan ditulis tangan.** Tiga nama yang
# dulu ditulis tangan adalah daftar yang benar tentang hari ia ditulis, dan
# itulah bentuk cacatnya: `PulsingCelestialVisual` — pembungkus kartu jam yang
# meneruskan keyakinan ke **dua** pemanggilan `CelestialVisualView` — tidak
# pernah masuk daftar, jadi satu-satunya jalur keyakinan ke kartu jawaban jam
# tidak diperiksa siapa pun. Terukur pada pohon utuh, proses baru:
#
#   PointingView.swift  `isConfirmed: isConfirmed` (pada `PulsingCelestialVisual`)
#                    -> `isConfirmed: true`   exit 0, SEMUA GERBANG LULUS
#
# Akibatnya persis yang dilarang PRD: pada `.uncertain`, kartu jam menggambar
# cincin Saturnus dan pita Jupiter di samping badge "Ragu". Enam aturan lain
# (18, 32, 34, 50, 51) tetap hijau karena semuanya memeriksa **pemanggil yang
# mereka kenal**; pembungkus ini bukan salah satunya.
#
# Karena itu daftarnya dibaca dari sumber: setiap `struct`/`extension` yang
# memuat properti `isConfirmed` **dan** meneruskannya (`isConfirmed:
# isConfirmed`) adalah simpul rantai, dan simpul rantai wajib diperiksa.
# Tipe baru yang meneruskan keyakinan ikut terjaga tanpa ada yang ingat
# mendaftarkannya — dan itu satu-satunya cara lubang ini tidak kembali.
#
# `PENGGAMBAR` sengaja tetap ada sebagai jangkar: ia yang menggambar, jadi
# kalau ia hilang dari daftar turunan, artinya pemeriksaannya kehilangan
# sasaran dan aturan harus memerah, bukan diam.
PENGGAMBAR = "CelestialVisualView"


def tanpa_komentar_dan_string(swift):
    """Buang komentar dan isi literal string, jaga posisi baris.

    Kurung kurawal di dalam komentar dan string akan menggeser kedalaman blok,
    dan kedalaman yang bergeser membuat `struct` yang benar terbaca sebagai
    milik tipe lain.
    """
    hasil = []
    i = 0
    n = len(swift)
    while i < n:
        dua = swift[i:i + 2]
        if dua == "//":
            j = swift.find("\n", i)
            if j < 0:
                break
            hasil.append(" " * (j - i))
            i = j
        elif dua == "/*":
            j = swift.find("*/", i + 2)
            if j < 0:
                hasil.append(" " * (n - i))
                break
            potong = swift[i:j + 2]
            hasil.append("".join("\n" if c == "\n" else " " for c in potong))
            i = j + 2
        elif swift[i] == '"':
            j = i + 1
            while j < n:
                if swift[j] == "\\":
                    j += 2
                    continue
                if swift[j] == '"':
                    j += 1
                    break
                j += 1
            hasil.append(" " * (j - i))
            i = j
        else:
            hasil.append(swift[i])
            i += 1
    return "".join(hasil)


def _argumen(kode, buka):
    """Isi daftar argumen mulai dari `(` di indeks `buka`."""
    depth = 0
    j = buka
    while j < len(kode):
        if kode[j] in "([{":
            depth += 1
        elif kode[j] in ")]}":
            depth -= 1
            if depth == 0:
                return kode[buka + 1:j]
        j += 1
    return ""


def turunkan_situs(berkas):
    """Tipe **View** yang dipanggil dengan argumen `isConfirmed:`.

    **Kenapa dari pemanggilan, bukan dari deklarasi.** Versi pertama aturan ini
    memakai daftar nama tertulis tangan, dan daftar itu selalu ketinggalan
    satu pembungkus: `PulsingCelestialVisual` — pembungkus kartu jam yang
    meneruskan keyakinan ke dua pemanggilan `CelestialVisualView` — tidak
    pernah masuk daftar, jadi satu-satunya jalur keyakinan ke kartu jawaban
    jam tidak diperiksa siapa pun. Terukur: `isConfirmed: true` di sana,
    exit 0, seluruh gerbang lulus.

    Definisi yang dipakai karena itu diturunkan dari **bentuk panggilan**:
    siapa pun yang dipanggil dengan `isConfirmed:` adalah simpul rantai,
    karena ia yang memutuskan keyakinan apa yang sampai ke lapisan gambar.
    Dibatasi ke tipe yang dideklarasikan `: View` — `ComplicationEntry` dan
    `ComplicationDigest` juga menerima `isConfirmed:` di `#Preview`, tetapi
    keduanya bukan view yang menggambar identitas objek; menuntut mereka
    membaca `confirmsDisplayedIdentity` akan menuduh kode yang benar.
    """
    view = set()
    dipanggil = set()
    for path, kode in berkas:
        for m in re.finditer(r"\bstruct\s+(\w+)\s*:\s*[^{]*\bView\b", kode):
            view.add(m.group(1))
        for m in re.finditer(r"\b([A-Z]\w*)\s*\(", kode):
            if re.search(r"(?:struct|class|enum|func)\s+$",
                         kode[max(0, m.start() - 12):m.start()]):
                continue
            if re.search(r"\bisConfirmed\s*:", _argumen(kode, m.end() - 1)):
                dipanggil.add(m.group(1))
    return dipanggil & view


# Baca seluruh `Apps/` sekali: daftar situs diturunkan dari sumber, bukan
# ditulis tangan. Berkas yang tidak bisa dibaca dilewati — `terbaca` di bawah
# yang memutuskan apakah aturan ini mengukur apa pun.
_sumber = []
for _root, _dirs, _files in os.walk("Apps"):
    _dirs[:] = [d for d in _dirs if d not in (".build", "build")]
    for _nama in sorted(_files):
        if not _nama.endswith(".swift"):
            continue
        _path = os.path.join(_root, _nama)
        try:
            _sumber.append((_path, tanpa_komentar_dan_string(
                open(_path, encoding="utf-8").read())))
        except OSError:
            continue

SITUS_NAMA = sorted(turunkan_situs(_sumber))
SITUS = re.compile(r"(?:\b" + r"|\b".join(re.escape(n) for n in SITUS_NAMA) + r")\s*\(")
#: Bentuk yang diterima, dan **hanya** itu — daftar putih receiver, bukan
#: pola bebas. Tiga versi sebelumnya buta, dan masing-masing terukur di
#: harness sebelum ditulis:
#:
#:   `\b(isConfirmed|confirmsDisplayedIdentity)\b`   `visual.isConfirmed` lolos
#:   `^(?:[\w.]*)?isConfirmed$`                     rantai bertitik apa pun lolos,
#:                                                  termasuk `visual.isConfirmed`
#:   `\bisConfirmed\b(?!\s*\.)`                     `engine.confirms…` ditolak
#:
#: Yang salah bukan arah rantainya, melainkan **receiver-nya**. `visual` adalah
#: gambar itu sendiri; `visual.isConfirmed` menjawab "apakah saya terkunci"
#: dengan bertanya pada dirinya sendiri. Receiver yang boleh hanya sumber
#: keyakinan: `engine` dan `snapshot` (dan turunannya).
LANGSUNG = re.compile(
    r'(?:isConfirmed|(?:[A-Za-z_][A-Za-z0-9_]*\.)*(?:engine|snapshot)\.'
    r'confirmsDisplayedIdentity)')
#: Receiver yang **tidak** boleh menjawab keyakinan, namun bentuknya lolos
#: kalau hanya dicek "nama kata terakhir". Diperiksa terpisah supaya
#: pesannya menyebut sebabnya, bukan sekadar "tidak cocok pola".
RECEIVER_TERLARANG = re.compile(
    r'^(?:[A-Za-z_][A-Za-z0-9_]*\.)*(?:visual|object|planet|illustration|'
    r'preview)\.isConfirmed$')
ILUSTRASI = {"OnboardingView.swift"}

masalah = []
terbaca = 0

# Fail-closed pada **derivasi**, bukan hanya pada hasilnya.
#
# Kalau pembaca `struct` berhenti bekerja (mis. sintaks Swift berubah, atau
# kurung kurawal tidak lagi seimbang karena satu berkas dipotong), daftar
# turunan menjadi kosong dan aturan ini diam-diam kembali ke tiga nama
# tertulis tangan — persis keadaan yang membuat lubang ini ada. Karena itu
# penggambar wajib muncul di daftar, dan jumlah simpul rantai wajib > 0.
if PENGGAMBAR not in SITUS_NAMA:
    masalah.append(
        "  daftar situs turunan tidak memuat `%s` -- pembaca panggilan "
        "berhenti bekerja, dan aturan ini kembali jadi daftar tertulis tangan"
        % PENGGAMBAR)
if len(SITUS_NAMA) < 3:
    masalah.append(
        "  hanya %d simpul rantai yang terbaca di Apps/ -- derivasi terlalu "
        "sempit, jadi pembungkus baru tidak akan pernah diperiksa"
        % len(SITUS_NAMA))

for root, dirs, files in os.walk("Apps"):
    dirs[:] = [d for d in dirs if d not in (".build", "build")]
    for nama in sorted(files):
        if not nama.endswith(".swift"):
            continue
        path = os.path.join(root, nama)
        teks = open(path, encoding="utf-8").read()
        # Komentar dibuang lebih dulu: docstring di `Apps/` mengutip bentuk
        # cacatnya, dan gerbang yang menuduh docstring akan dilonggarkan orang.
        kode = re.sub(r"//[^\n]*", "", teks)
        kode = re.sub(r"/\*.*?\*/", "", kode, flags=re.S)
        for m in SITUS.finditer(kode):
            # Tutup kurung yang sepadan untuk seluruh daftar argumen.
            i = kode.find("(", m.end() - 1)
            depth = 0
            dot = 0
            akhir = -1
            for j in range(i, len(kode)):
                ch = kode[j]
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        akhir = j
                        break
                elif ch == '"':
                    # Lewati literal string supaya tanda kurung di dalamnya
                    # tidak menggulung kedalaman.
                    k = j + 1
                    while k < len(kode) and kode[k] != '"':
                        if kode[k] == "\\":
                            k += 1
                        k += 1
                    continue
            daftar = kode[i + 1:akhir] if akhir > 0 else ""
            terbaca += 1
            dipanggil = kode[m.start():m.end()].rstrip("( \t\n").strip()
            situs = re.search(r'\bisConfirmed\s*:\s*([^,\n]+)', daftar)
            if not situs:
                masalah.append(
                    "  %s: `%s(...)` tanpa argumen `isConfirmed:` "
                    "-- nilai bawaan `false` berlaku, yang aman, tetapi baris ini "
                    "tidak bisa dibedakan dari lupa" % (path, dipanggil))
                continue
            nilai = situs.group(1).strip()
            if nilai == "true" and nama in ILUSTRASI:
                continue
            if RECEIVER_TERLARANG.fullmatch(nilai):
                masalah.append(
                    "  %s: `isConfirmed: %s` -- keyakinan dibaca dari gambar "
                    "itu sendiri, bukan dari engine" % (path, nilai))
                continue
            if not LANGSUNG.fullmatch(nilai):
                masalah.append(
                    "  %s: `isConfirmed: %s` -- keyakinan engine tidak dibaca "
                    "langsung; nama lain bisa berarti apa saja" % (path, nilai))

if terbaca == 0:
    print("PERINGATAN: tidak ada pemanggilan `CelestialVisualView(` yang terbaca "
          "di Apps/ -- aturan ini tidak mengukur apa pun.")
else:
    print("\n".join(masalah))
PY
)
if printf '%s' "$keyakinan_nama" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 52 tidak bisa memutuskan:"
  echo "$keyakinan_nama"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$keyakinan_nama" ]; then
  echo "$keyakinan_nama"
  echo "-> Teruskan keyakinan engine dari confirmsDisplayedIdentity, atau"
  echo "   parameter isConfirmed, apa adanya. Nama perantara bisa menunjuk"
  echo "   nilai yakin tanpa satu pun baris yang membacanya."
  status=1
else
  echo "Bersih: setiap gambar membaca keyakinan engine secara langsung."
fi

# ── Aturan 53: kejujuran sensor di MotionLogger tidak boleh dibalik ──────
#
# `MotionLogger.swift` adalah satu-satunya berkas yang membaca sensor gerak
# (jam maupun iPhone). Ia punya **tiga** titik jujur yang, kalau dibalik,
# membuat jam terus menampilkan objek terakhir sebagai "terkonfirmasi"
# padahal sensornya mati — persis yang dilarang PRD (false confidence).
#
# Diukur pada salinan utuh (proses baru, `Apps/` dibawa), mutasi yang
# semuanya **mengompilasi** — sebelum aturan ini ada, **semua lolos** (exit 0):
#
#   let events = controller.setSensorAvailable(false)   -> (true)
#       lint LULUS  swift-typecheck LULUS  ./swift-test.sh 0 gagal
#   unavailableReason = SensorStatusText.motionMissing  -> nil
#       lint LULUS  (alasan ketiadaan sensor dihapus, layar diam)
#   isRunning = manager.isDeviceMotionActive            -> true
#       lint LULUS  (klaim sensor selalu hidup)
#
# Yang paling berbahaya yang pertama: `setSensorAvailable(false)` memanggil
# `PointingController.setSensorAvailable(false)`, yang (lihat
# `PointingController.swift:243-260`) menghentikan alur dan membuang jawaban.
# Tapi `PointingEngine.snapshot` — satu-satunya sumber yang dibaca UI — tidak
# ikut berubah kalau `onUpdate` tidak dipanggil; `publishSensorLoss()` yang
# memanggilnya justru lewat saluran itu. Membaliknya ke `true` berarti "sensor
# hilang tapi laporkan tersedia": jam tetap menampilkan objek terakhir seolah
# masih terkonfirmasi.
#
# **Kenapa ini di lint, bukan di PointingKit.** Ketiga bentuk itu adalah
# **perintah** yang dipanggil di `Apps/`, bukan nilai yang diturunkan — tidak
# ada tipe murni yang bisa menampung "jangan membalik perintah ini" tanpa
# mengubah `MotionLogger` jadi tidak melakukan pekerjaannya. Aturan 52 sudah
# membuktikan pola ini: perintah sensor lolos semua gerbang karena ia bukan
# "klaim identitas", hanya "perintah".
#
# **Fail-closed, bukan daftar-hitam.** Dua penjaga memaksa aturan ini merah
# kalau ia berhenti mengukur: (a) `MotionLogger.swift` harus ada, dan (b) ke-
# tiga bentuk jujur harus muncul **tepat sekali**. Kalau seseorang
# memindahkan/menggabung berkas ini, atau menghapus salah satu titik jujur,
# aturan memerah — bukan diam. Kalau semua bentuk jujur hilang sekaligus, itu
# adalah "gerbang buta selamanya" yang kita larang.
echo
echo "== Aturan 53: kejujuran sensor MotionLogger tidak dibalik =="
sensor_nama=$(python3 - <<'PY' 2>&1
import os
import re

MOTION = "Apps/Shared/MotionLogger.swift"

# Bentuk **jujur** yang wajib ada tepat sekali (fail-closed: hilang = gagal).
# Setiap bentuk ini adalah **satu-satunya** tempat di berkas yang melakukan
# kejujuran itu -- membaliknya (false->true, alasan->nil, isRunning->true)
# menghapus bentuk jujur ini, sehingga hitungannya menjadi 0 dan aturan
# memerah. Daftar-hitam per-kata ("jangan tulis `isRunning = true`") tidak
# dipakai: `unavailableReason = nil` **sah** ada di tempat lain (mengosongkan
# alasan saat sensor berhasil menyala), jadi melarang kata itu akan memerah
# pada kode benar. Fail-closed lewat hitungan bentuk jujur menangkap mutasi
# tanpa menuduh kode yang sah.
SENSOR_LOSS = "let events = controller.setSensorAvailable(false)"
REASON      = "unavailableReason = SensorStatusText.motionMissing"
RUNNING     = "isRunning = manager.isDeviceMotionActive"

masalah = []

if not os.path.exists(MOTION):
    print("PERINGATAN: %s tidak ditemukan -- Aturan 53 tidak mengukur apa pun."
          % MOTION)
else:
    kode = open(MOTION, encoding="utf-8").read()
    # Komentar dibuang: docstring di Apps/ mengutip bentuk cacat.
    kode = re.sub(r"//[^\n]*", "", kode)
    kode = re.sub(r"/\*.*?\*/", "", kode, flags=re.S)

    # Fail-closed: ketiga bentuk jujur harus ada tepat sekali. Mutasi yang
    # membalik salah satunya menghapus bentuk itu dari berkas, sehingga
    # hitungannya bukan 1 -- aturan memerah, bukan diam.
    for bentuk in (SENSOR_LOSS, REASON, RUNNING):
        n = kode.count(bentuk)
        if n != 1:
            masalah.append(
                "  %s: bentuk jujur `%s` muncul %d kali (harus tepat 1) -- "
                "kejujuran sensor dibalik atau aturan berhenti mengukur."
                % (MOTION, bentuk, n))

if masalah:
    print("\n".join(masalah))
PY
)
if printf '%s' "$sensor_nama" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 53 tidak bisa memutuskan:"
  echo "$sensor_nama"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$sensor_nama" ]; then
  echo "$sensor_nama"
  echo "-> MotionLogger harus jujur saat sensor tidak ada: jangan balik"
  echo "   perintah sensor-hilang, jangan hapus alasannya, jangan klaim"
  echo "   sensor selalu hidup."
  status=1
else
  echo "Bersih: MotionLogger tetap jujur saat sensor tidak ada."
fi

# ── Aturan 54: kejujuran izin lokasi di LocationProvider tidak boleh dibalik ──
#
# `LocationProvider.swift` adalah satu-satunya berkas yang membaca izin lokasi
# (jam maupun iPhone). Ia cermin persis `MotionLogger` (Aturan 53): punya
# **empat** titik jujur yang, kalau dibalik, membuat penolakan izin tampil
# senyap — persis yang dilarang PRD ("jangan diam saat izin ditolak").
#
# Diukur pada salinan utuh (proses baru, `Apps/` + `Packages/` dibawa),
# mutasi yang semuanya **mengompilasi di macOS** — sebelum aturan ini ada,
# **seluruh 53 aturan UI lolos (exit 0)**:
#
#   denied     -> note = nil           (alasan ditolak dibuang, layar diam)
#   restricted -> note = nil           (alasan dibatasi dibuang, layar diam)
#   failed     -> self.note = nil      (kegagalan lokasi diam)
#   guard horizontalAccuracy >= 0       -> guard let last = … else return
#       (lokasi dengan akurasi invalid diterima sebagai lokasi sah;
#        `last` bisa `CLLocation` yang `horizontalAccuracy == -1`)
#
# Yang paling berbahaya bukan sekadar "diam": PRD menuntut penolakan izin
# **terlihat dan jelas** (Aturan 14 & `SensorStatusText`), dan `LocationProvider`
# adalah satu-satunya yang mengisinya. `note` yang lenyap berarti penolakan
# izin tidak ditampilkan — lokasi darurat (Jakarta) dipakai tanpa satu kata
# pun yang memberi tahu pengguna bahwa langit dihitung untuk tempat lain.
#
# **Kenapa ini di lint, bukan di PointingKit.** Keempat bentuk itu adalah
# **perintah penulisan** ke properti `@Published` (keadaan sensor/lokasi),
# bukan nilai turunan yang bisa ditampung tipe murni — sama seperti ketiga
# bentuk jujur di Aturan 53. Aturan 38 menyapu `var X: Bool` yang namanya
# sama dengan anggota model; keempat bentuk di sini bukan `Bool` dan bukan
# penerusan `snapshot.*`, jadi lepas dari jangkauannya. Aturan 36/37/38 tidak
# menangkapnya karena mereka mengawasi kawan `MotionLogger` (sensor gerak),
# bukan kawan lokasi.
#
# **Fail-closed, bukan daftar-hitam per-kata.** Empat bentuk jujur dihitung
# **berpasangan dengan jumlah kemunculannya yang sah**, bukan dilarang kata
# per kata:
#   - `note = SensorStatusText.locationDeniedNote`    harus **tepat 2** (start
#     + delegasi — dua jalur keadaan ditolak yang sama-sama wajib menampilkan
#     alasannya).
#   - `note = SensorStatusText.locationRestrictedNote` harus **tepat 2** (sama).
#   - `self.note = SensorStatusText.locationFailedNote(message)` harus **tepat
#     1** (hanya di delegasi kegagalan).
#   - `locations.last, last.horizontalAccuracy >= 0`   harus **tepat 1**
#     (satu gerbang akurasi di `didUpdateLocations`).
# Daftar-hitam per-kata (`note = nil` dilarang) salah: `self.note = nil` **sah**
# ada persis 2 kali (mengosongkan catatan saat lokasi sah tiba), jadi
# melarangnya memerah pada kode benar. Fail-closed lewat hitungan bentuk jujur
# menangkap mutasi tanpa menuduh kode yang sah.
#
# **Kenapa hitungannya berpasangan, bukan "ada".** `denied`/`restricted` masing-
# masing muncul 2 kali *by design* (dua jalur keadaan). Memaksa "ada ≥ 1"
# akan lulus bila salah satu dari dua jalur dibalik (sisanya tetap ada), sehingga
# mutasi `denied start -> nil` tetap hijau — cacat lolos. Menuntut tepat 2
# membuat hilangnya satu dari dua jalur memerah.
echo
echo "== Aturan 54: kejujuran izin lokasi LocationProvider tidak dibalik =="
izin_nama=$(python3 - <<'PY' 2>&1
import os
import re

LOCATION = "Apps/Shared/LocationProvider.swift"

# Bentuk **jujur** yang wajib ada pada hitungan tertentu (fail-closed).
# (label, teks, jumlah wajib) -- jumlah mewakili berapa jalur keadaan yang
# memanggilnya; mutasi yang menghapus salah satu jalur membuat hitungannya
# bukan nilai wajib, sehingga aturan memerah, bukan diam.
BENTUK = (
    ("denied.note",     "note = SensorStatusText.locationDeniedNote",     2),
    ("restricted.note", "note = SensorStatusText.locationRestrictedNote", 2),
    ("failed.note",     "self.note = SensorStatusText.locationFailedNote(message)", 1),
    ("akurasi.guard",   "locations.last, last.horizontalAccuracy >= 0",    1),
)

masalah = []

if not os.path.exists(LOCATION):
    print("PERINGATAN: %s tidak ditemukan -- Aturan 54 tidak mengukur apa pun."
          % LOCATION)
else:
    kode = open(LOCATION, encoding="utf-8").read()
    # Komentar dibuang: docstring di Apps/ mengutip bentuk cacat.
    kode = re.sub(r"//[^\n]*", "", kode)
    kode = re.sub(r"/\*.*?\*/", "", kode, flags=re.S)

    for label, bentuk, wajib in BENTUK:
        n = kode.count(bentuk)
        if n != wajib:
            masalah.append(
                "  %s: bentuk jujur `%s` muncul %d kali (harus tepat %d) -- "
                "penolakan izin lokasi dibalik atau aturan berhenti mengukur."
                % (LOCATION, bentuk, n, wajib))

if masalah:
    print("\n".join(masalah))
PY
)
if printf '%s' "$izin_nama" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 54 tidak bisa memutuskan:"
  echo "$izin_nama"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$izin_nama" ]; then
  echo "$izin_nama"
  echo "-> LocationProvider harus jujur saat izin lokasi ditolak/dibatasi/gagal:"
  echo "   jangan buang catatannya, jangan terima lokasi akurasi invalid."
  status=1
else
  echo "Bersih: LocationProvider tetap jujur saat izin lokasi ditolak/dibatasi/gagal."
fi

# ── Aturan 55: teks status yang ditulis wajib dibaca satu layar ─────────────
#
# Kelas cacatnya: sebuah properti `@Published` berakhiran Note/Reason/Message/
# Label/Speech ditulis berkali-kali — tiap jalur kegagalan, tiap penolakan
# izin — lalu **tidak pernah dibaca satu view pun**. Layar tidak tampak salah:
# tidak ada yang hilang dari tata letak, tidak ada teks yang salah kata, dan
# seluruh 54 aturan lain hijau. Yang hilang justru kabarnya.
#
# Terukur di `main` sebelum aturan ini ada: `WatchLinkService.lastMessageNote`
# ditulis **7 kali** (kalibrasi tidak terkirim, pesan tidak terkirim, kirim
# gagal, ambang tidak sah, permintaan keadaan terlalu dini, aktivasi sesi
# gagal, dan catatan pesan masuk) dan dibaca **0 kali**. Kembarannya di iPhone,
# `PhoneLinkService.lastNote`, dibaca `LinkView` — jadi tidak ada yang
# mencurigakan saat membandingkan kedua service: keduanya "punya properti
# catatan", dan hanya satu yang tersambung ke layar.
#
# Yang membuat ini bukan sekadar kerapian: `link.send(calibration:)` adalah
# satu-satunya jalan hasil kalibrasi sampai ke iPhone (sigma-nya menyetel
# ambang keyakinan di sana). Saat sesi belum aktif, ia menulis
# `calibrationNotSent` — dan pengguna di jam tidak melihat apa pun, karena
# `CalibrationView` hanya menampilkan `statusMessage` miliknya sendiri yang
# berbunyi "Kalibrasi terpasang". Dua kalimat itu bertentangan, dan yang
# salah adalah yang terlihat. PRD menuntut kegagalan terlihat; di sini
# kegagalan paling penting (hasil ukur hilang di jalan) justru senyap.
#
# **Kenapa ini bukan urusan Aturan 12/16.** Aturan 12 menyapu penugasan
# berakhiran Note yang berisi **literal**; di sini nilainya accessor katalog
# (`LinkStatusText.calibrationNotSent`), jadi bentuknya justru yang benar.
# Aturan 16 menyapu literal peritel aksesibilitas. Keduanya mengawasi **isi**
# kalimat; tidak ada yang mengawasi apakah kalimat itu sampai ke layar.
#
# **Kenapa fail-closed, bukan daftar-hitam.** Aturan ini tidak menyebut nama
# properti apa pun. Ia menurunkan daftarnya dari sumbernya: setiap properti
# `@Published` di `Apps/` yang namanya berakhiran Note/Reason/Message/Label/
# Speech adalah "teks status", dan masing-masing wajib punya **minimal satu
# pembacaan di luar deklarasinya**. Properti baru otomatis ikut terjaga tanpa
# ada yang ingat mendaftarkannya — dan properti yang dibaca tetap hijau tanpa
# pengecualian khusus.
#
# **Kenapa pembacaan di berkas sendiri TIDAK dihitung.** Kalau dihitung,
# `lastMessageNote` akan lolos lewat `handle(_:)` yang membacanya untuk
# menyusun nilai berikutnya — menulis dan membaca di tempat yang sama,
# sementara layar tetap tidak pernah menerimanya. Itu persis bentuk yang
# lolos hari ini. Yang dihitung hanya pembacaan dari **berkas lain**.
#
# **Kenapa pembacaan di dalam `.onChange(of: ...)` juga TIDAK dihitung.**
# Ini lubang yang ditemukan justru setelah aturan ini ditulis. Perbaikan
# pertama menambahkan dua pembaca: satu baris `Text(note)` di layar, dan satu
# `.onChange(of: link.lastMessageNote)` yang mengumumkannya ke VoiceOver.
# Menghapus baris `Text`-nya menyisakan pengumuman — dan aturan tetap hijau,
# padahal teksnya tidak lagi tampil di layar mana pun. Cacat aslinya kembali
# utuh, hanya bergeser satu tingkat: dari "tidak dibaca" menjadi "dibaca
# tetapi hanya untuk diucapkan". Pengumuman adalah saluran **tambahan**, bukan
# pengganti tampilan — teks yang hanya diucapkan tidak bisa dibaca ulang
# dengan mengusap layar, dan tidak ada di tangkapan layar mana pun.
# Jadi pembacaan yang berada di dalam blok `.onChange(of: <properti>)` untuk
# properti itu dianggap pengumuman, bukan tampilan, dan tidak dihitung.
#
# **Kenapa zero-item = GAGAL.** Kalau `Apps/` tidak ditemukan atau tidak ada
# satu pun properti teks status yang terdeteksi, aturan ini tidak mengukur
# apa pun. Hijau dalam keadaan itu adalah hijau yang kosong.
echo
echo "== Aturan 55: teks status yang ditulis wajib dibaca satu layar =="
teks_mati=$(python3 - <<'PY' 2>&1
import os
import re

AKAR = "Apps"

def buang_komentar(s):
    s = re.sub(r"//[^\n]*", "", s)
    return re.sub(r"/\*.*?\*/", "", s, flags=re.S)

def rentang_onchange(isi, nama):
    """Rentang blok `.onChange(of: <nama>) { ... }` untuk satu properti.

    Dipakai untuk memisahkan **pengumuman** dari **tampilan**. Kurung kurawal
    diseimbangkan dari `{` pertama sesudah `.onChange(of: nama)`; tidak ada
    parser Swift di sini dan tidak perlu — satu tingkat kedalaman sudah cukup
    untuk membedakan blok pengumuman dari baris tampilan di luarnya.
    """
    rentang = []
    pola = re.compile(r"\.onChange\(of:\s*[^)]*\b%s\b" % re.escape(nama))
    for m in pola.finditer(isi):
        buka = isi.find("{", m.end())
        if buka < 0:
            continue
        dalam = 0
        for i in range(buka, len(isi)):
            if isi[i] == "{":
                dalam += 1
            elif isi[i] == "}":
                dalam -= 1
                if dalam == 0:
                    # Rentang mulai dari **awal `.onChange`**, bukan dari `{`.
                    # Nama properti muncul dua kali di blok ini: sekali di
                    # klausa `of:` dan sekali (mungkin) di badannya. Kalau
                    # rentangnya mulai dari `{`, kemunculan di `of:` dihitung
                    # sebagai tampilan — dan aturan tetap hijau walau baris
                    # `Text`-nya sudah dibuang. Itu persis yang terjadi pada
                    # percobaan pertama aturan ini.
                    rentang.append((m.start(), i + 1))
                    break
    return rentang

berkas = []
for dasar, _, nama_berkas in os.walk(AKAR):
    for n in nama_berkas:
        if n.endswith(".swift"):
            berkas.append(os.path.join(dasar, n))

if not berkas:
    print("PERINGATAN: tidak ada berkas Swift di %s -- Aturan 55 tidak "
          "mengukur apa pun." % AKAR)
    raise SystemExit(0)

sumber = {}
for b in berkas:
    try:
        sumber[b] = buang_komentar(open(b, encoding="utf-8").read())
    except OSError as e:
        print("PERINGATAN: %s tidak terbaca (%s)." % (b, e))
        raise SystemExit(0)

# Teks status = properti @Published yang namanya berakhiran salah satu ini.
# Daftar akhiran ini **bukan** daftar properti: ia aturan penamaan yang sudah
# dipakai repo (`lastNote`, `lastMessageNote`, `sensorNote`,
# `unavailableReason`), jadi properti baru ikut terjaga dengan sendirinya.
AKHIRAN = ("Note", "Reason", "Message", "Label", "Speech")
DEKLARASI = re.compile(r"@Published[^\n]*\bvar\s+(\w+)\s*:")

teks_status = []          # (berkas, nama)
for b, isi in sumber.items():
    for m in DEKLARASI.finditer(isi):
        nama = m.group(1)
        if nama.endswith(AKHIRAN):
            teks_status.append((b, nama))

if not teks_status:
    print("PERINGATAN: tidak ada properti teks status di %s -- Aturan 55 "
          "tidak mengukur apa pun." % AKAR)
    raise SystemExit(0)

masalah = []
for b, nama in sorted(teks_status):
    tampil_di = set()
    for lain, isi in sumber.items():
        if lain == b:
            # Pembacaan di berkas sendiri sengaja dilewati: itu bisa berarti
            # menulis-lalu-membaca di tempat yang sama, bukan sampai ke layar.
            continue
        abaikan = rentang_onchange(isi, nama)
        for m in re.finditer(r"\b%s\b" % re.escape(nama), isi):
            sebelum = isi[max(0, m.start() - 8):m.start()]
            if re.search(r"\b(var|let)\s+$", sebelum):
                continue
            sesudah = isi[m.end():m.end() + 4].lstrip()
            if sesudah.startswith("=") and not sesudah.startswith("=="):
                continue
            if any(a <= m.start() < z for a, z in abaikan):
                # Pengumuman VoiceOver, bukan tampilan.
                continue
            tampil_di.add(lain)
    if not tampil_di:
        masalah.append(
            "  %s: `%s` ditulis tetapi tidak ditampilkan berkas lain mana pun "
            "-- kalimatnya tidak pernah sampai ke layar." % (b, nama))

if masalah:
    print("\n".join(masalah))
PY
)
if printf '%s' "$teks_mati" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 55 tidak bisa memutuskan:"
  echo "$teks_mati"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$teks_mati" ]; then
  echo "$teks_mati"
  echo "-> Teks status yang ditulis harus dibaca minimal satu view:"
  echo "   kegagalan yang tidak pernah tampil sama saja dengan diam."
  status=1
else
  echo "Bersih: setiap teks status dibaca minimal satu layar."
fi

# ── Aturan 56: layar redup menerima versi hemat, bukan layar penuh ──────────
#
# Kelas cacatnya: `NightAwareContainer` memilih **isi** mana yang tampil saat
# watchOS meredupkan layar. Pemilihan itu dulu berbunyi `if isLuminanceReduced`
# di `Apps/PointAndKnowWatch/Sources/ReducedLuminanceView.swift` — berkas yang
# tidak pernah dibangun `swift-test.sh` di Linux dan tidak dibaca badan satu pun
# dari 55 aturan di atas.
#
# Terukur pada salinan utuh, proses baru, sebelum aturan ini ada. Ketiga mutasi
# di bawah ini mengompilasi dan **seluruh 55 aturan lulus (exit 0)**:
#
#     reduced: { fullView }                            -> exit 0
#     reduced: { ReducedLuminanceView(engine: PointingEngine()) } -> exit 0
#     reduced: { EmptyView() }                          -> exit 0
#     if isLuminanceReduced  ->  if false               -> exit 0
#
# Yang pertama mengembalikan seluruh layar interaktif ke Always-On: animasi,
# tombol, dan gestur yang justru diabaikan watchOS saat redup. Yang kedua
# menampilkan nama objek dari mesin yang tidak pernah menerima satu sampel pun
# — layar redup yang selalu berbunyi "Mencari" di sebelah jam yang sedang
# terkunci. Yang ketiga mengosongkan layar yang dibuat untuk dibaca sekilas.
# Tidak satu pun bisa terlihat dari layar lain, karena layar ini hanya tampil
# saat pergelangan diturunkan.
#
# **Kenapa keputusannya dipindah, bukan hanya dijaga.** Pemilihan isi sekarang
# hidup di `AlwaysOnContent.choose(isLuminanceReduced:)` (PointingKit) dan
# diuji di Linux (`AlwaysOnContentTests`). Aturan ini menjaga sisi yang tidak
# bisa dieksekusi di sini: **pemanggilnya**. Dua lapis, dua kelas cacat —
# nilai yang salah dijaga uji, isi yang salah dijaga sapuan teks.
#
# **Kenapa fail-closed.** Nol pemanggil `NightAwareContainer` berarti aturan
# ini tidak mengukur apa pun. Hijau dalam keadaan itu adalah hijau yang kosong,
# dan justru itulah bentuk kegagalan yang paling mungkin: berkasnya diganti
# nama, atau layarnya berhenti memakai pembungkus itu sama sekali.
echo
echo "== Aturan 56: layar redup menerima versi hemat, bukan layar penuh =="
redup_salah=$(python3 - <<'PY' 2>&1
import os
import re

AKAR = "Apps"

def buang_komentar(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    return re.sub(r"//[^\n]*", "", s)

def blok_dari(isi, buka):
    """Isi antara `{` di posisi buka dan pasangannya, atau None."""
    dalam = 0
    for i in range(buka, len(isi)):
        if isi[i] == "{":
            dalam += 1
        elif isi[i] == "}":
            dalam -= 1
            if dalam == 0:
                return isi[buka + 1:i], i
    return None, -1

berkas = []
for dasar, _, nama in os.walk(AKAR):
    for n in sorted(nama):
        if n.endswith(".swift"):
            berkas.append(os.path.join(dasar, n))

if not berkas:
    print("PERINGATAN: tidak ada berkas Swift di %s -- Aturan 56 tidak "
          "mengukur apa pun." % AKAR)
    raise SystemExit(0)

masalah = []
pemanggil = 0
wadah_terbaca = 0

for path in berkas:
    try:
        isi = buang_komentar(open(path, encoding="utf-8").read())
    except OSError as e:
        print("PERINGATAN: %s tidak terbaca (%s)." % (path, e))
        raise SystemExit(0)

    # ── Arah 1: setiap pemanggil wajib mengisi `reduced:` dengan versi hemat.
    for m in re.finditer(r"\bNightAwareContainer\s*\{", isi):
        buka = isi.find("{", m.start())
        isi_utama, tutup = blok_dari(isi, buka)
        if isi_utama is None:
            masalah.append("  %s: `NightAwareContainer` tanpa kurung kurawal "
                           "seimbang -- aturan tidak bisa memutuskan." % path)
            continue
        sisa = isi[tutup + 1:]
        label = re.match(r"\s*reduced\s*:\s*\{", sisa)
        if not label:
            masalah.append(
                "  %s: `NightAwareContainer` tanpa cabang `reduced:` -- layar "
                "redup tidak punya isi hemat." % path)
            continue
        buka_redup = tutup + 1 + label.end() - 1
        isi_redup, _ = blok_dari(isi, buka_redup)
        if isi_redup is None:
            masalah.append("  %s: cabang `reduced:` tanpa kurung kurawal "
                           "seimbang." % path)
            continue
        pemanggil += 1
        # Bentuk yang sah: `ReducedLuminanceView(engine: <pengenal>)`.
        # Penerima yang mengandung tanda kurung berarti mesin baru
        # (`PointingEngine()`), bukan mesin yang sedang diamati layar.
        sah = re.search(r"\bReducedLuminanceView\s*\(\s*engine\s*:\s*"
                        r"([A-Za-z_]\w*)\s*[,)]", isi_redup)
        if not sah:
            masalah.append(
                "  %s: cabang `reduced:` tidak meneruskan "
                "`ReducedLuminanceView(engine: <mesin yang sama>)` -- isi "
                "layar redup bukan versi hemat." % path)

    # ── Arah 2: pembungkusnya sendiri wajib memakai keputusan model.
    for m in re.finditer(r"\bstruct\s+NightAwareContainer\b", isi):
        buka = isi.find("{", m.start())
        badan, _ = blok_dari(isi, buka)
        if badan is None:
            continue
        wadah_terbaca += 1
        if "AlwaysOnContent.choose(isLuminanceReduced: isLuminanceReduced)" \
                not in badan:
            masalah.append(
                "  %s: `NightAwareContainer` tidak memakai "
                "`AlwaysOnContent.choose(isLuminanceReduced: "
                "isLuminanceReduced)` -- pemilihan isi harus meneruskan "
                "keadaan layar yang sebenarnya, bukan literal." % path)
        if re.search(r"\bif\s+isLuminanceReduced\b", badan):
            masalah.append(
                "  %s: `NightAwareContainer` masih bercabang langsung pada "
                "`isLuminanceReduced` -- keputusan isi harus lewat model "
                "yang diuji." % path)

if wadah_terbaca == 0:
    print("PERINGATAN: `NightAwareContainer` tidak ditemukan di %s -- "
          "Aturan 56 tidak mengukur apa pun." % AKAR)
    raise SystemExit(0)
if pemanggil == 0:
    print("PERINGATAN: tidak ada pemanggil `NightAwareContainer` di %s -- "
          "Aturan 56 tidak mengukur satu layar pun." % AKAR)
    raise SystemExit(0)

if masalah:
    print("\n".join(masalah))
PY
)
if printf '%s' "$redup_salah" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 56 tidak bisa memutuskan:"
  echo "$redup_salah"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$redup_salah" ]; then
  echo "$redup_salah"
  echo "-> Saat layar redup, yang tampil harus versi sederhana & kontras"
  echo "   tinggi dari mesin yang sama -- bukan layar penuh, bukan mesin baru,"
  echo "   bukan layar kosong."
  status=1
else
  echo "Bersih: setiap layar redup memakai versi hemat dari mesinnya sendiri."
fi

# ── Aturan 57: kunci preferensi wajib lewat token, bukan literal ────────────
#
# Kelas cacatnya: `@AppStorage("nightModeEnabled")` di satu layar dan
# `@AppStorage("nightMode")` di layar lain. Keduanya mengompilasi, keduanya
# berjalan, dan **keduanya menyimpan ke tempat berbeda**. Pengguna menyalakan
# Mode Malam di jam, membuka iPhone, dan mendapati Mode Malam mati — sementara
# tidak satu pun layar salah, dan tidak ada yang bisa dibaca untuk menyadarinya.
# Pada mode malam ini bukan cacat kosmetik: palet merah adalah satu-satunya
# yang menjaga rhodopsin, dan pengguna yang mengira sudah menyalakannya
# mendapat layar putih di gelap.
#
# Terukur pada salinan utuh, proses baru, sebelum aturan ini ada. Ketiga mutasi
# di bawah mengompilasi dan **seluruh 56 aturan lulus (exit 0)**:
#
#     Watch  : NightModeStorage.key  ->  "nightMode"        -> exit 0
#     iPhone : AudioCueStorage.key   ->  "soundOn"          -> exit 0
#     Watch  : AudioCueStorage.key   ->  "audio"            -> exit 0
#
# Dua yang terakhir paling sunyi: bunyi kunci adalah aksesibilitas
# multi-modal, jadi mematikan saklar di jam dan mendapatinya masih menyala di
# iPhone (atau sebaliknya) hanya terasa seperti "kadang berbunyi, kadang
# tidak".
#
# **Kenapa token, bukan sekadar "string yang sama".** Memeriksa kesamaan
# literal antar-berkas akan hijau pada dua layar yang sama-sama menulis
# `"nightMode"` — padahal itu tetap dua tempat yang bisa menyimpang nanti.
# Yang dijaga di sini adalah **satu sumber**: kuncinya hidup di enum
# penyimpanan, dan pemakainya menyebut enum itu.
#
# **Kenapa fail-closed.** Nol `@AppStorage` berarti aturan ini tidak mengukur
# apa pun — dan itu justru bentuk kegagalan yang paling mungkin: seluruh
# preferensi dipindah ke `@SceneStorage` atau ke lapisan pengaturan baru, dan
# aturan ini diam-diam berhenti menjaga apa pun.
echo
echo "== Aturan 57: kunci preferensi lewat token, bukan literal =="
kunci_pref=$(python3 - <<'PY' 2>&1
import os
import re

AKAR = "Apps"

def buang_komentar(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    return re.sub(r"//[^\n]*", "", s)

berkas = []
for dasar, _, nama in os.walk(AKAR):
    for n in sorted(nama):
        if n.endswith(".swift"):
            berkas.append(os.path.join(dasar, n))

if not berkas:
    print("PERINGATAN: tidak ada berkas Swift di %s -- Aturan 57 tidak "
          "mengukur apa pun." % AKAR)
    raise SystemExit(0)

masalah = []
pemakai = 0
#: kunci literal -> daftar (berkas, nilai token yang seharusnya)
literal = {}

for path in berkas:
    try:
        isi = buang_komentar(open(path, encoding="utf-8").read())
    except OSError as e:
        print("PERINGATAN: %s tidak terbaca (%s)." % (path, e))
        raise SystemExit(0)

    for m in re.finditer(r"@AppStorage\s*\(\s*([^)]*)\)", isi):
        argumen = m.group(1).strip()
        pemakai += 1
        # Bentuk yang sah: `@AppStorage(SomeStorage.key)`.
        if re.fullmatch(r"[A-Za-z_]\w*\.key", argumen):
            continue
        if argumen.startswith('"'):
            nilai = re.match(r'"([^"]*)"', argumen)
            if nilai:
                literal.setdefault(nilai.group(1), []).append(path)
                masalah.append(
                    "  %s: `@AppStorage(%s)` memakai literal -- kuncinya "
                    "harus datang dari enum penyimpanan, supaya jam & iPhone "
                    "tidak bisa menyimpang." % (path, argumen.split(",")[0]))
                continue
        masalah.append(
            "  %s: `@AppStorage(%s)` bukan `SomeStorage.key` -- aturan tidak "
            "bisa memastikan kuncinya satu sumber." % (path, argumen[:60]))

if pemakai == 0:
    print("PERINGATAN: tidak ada `@AppStorage` di %s -- Aturan 57 tidak "
          "mengukur satu preferensi pun." % AKAR)
    raise SystemExit(0)

#: Kunci yang dipakai lebih dari satu berkas tetapi ditulis sebagai literal di
#: salah satunya sudah dilaporkan di atas. Di sini hanya penjaga tambahan:
#: satu nilai literal tidak boleh dipakai dua berkas, karena itu berarti dua
#: layar menyimpan sendiri-sendiri tanpa token.
for nilai, paths in sorted(literal.items()):
    if len(set(paths)) > 1:
        masalah.append(
            '  kunci "%s" ditulis sebagai literal di %d berkas -- satu '
            "preferensi, dua sumber." % (nilai, len(set(paths))))

if masalah:
    print("\n".join(masalah))
PY
)
if printf '%s' "$kunci_pref" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 57 tidak bisa memutuskan:"
  echo "$kunci_pref"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$kunci_pref" ]; then
  echo "$kunci_pref"
  echo "-> Preferensi yang disimpan dengan literal bisa menyimpang antar"
  echo "   layar tanpa satu pun layar terlihat salah."
  status=1
else
  echo "Bersih: setiap preferensi memakai token penyimpanan yang sama."
fi

# ── Aturan 58: penjaga gerak tidak boleh dibalik atau diganti literal ───────
#
# Aturan 7 menuntut **adanya** penjaga reduce-motion di blok yang sama. Ia
# tidak pernah menanyakan **arah** penjaganya, dan itu bukan kelalaian kecil:
# blok yang sama juga menyebut `MotionPolicy.LockArrival.responseSeconds` di
# argumen `withAnimation`, dan `MotionPolicy` cocok dengan penjaga Aturan 7.
# Jadi begitu penjaganya diganti literal, Aturan 7 tetap hijau karena nama
# modelnya masih ada di baris berikutnya.
#
# Terukur pada salinan utuh, proses baru, sebelum aturan ini ada — ketiganya
# mengompilasi dan **seluruh 57 aturan lulus (exit 0)**:
#
#     guard motion.allowsTransitions else { return }   -> guard true else
#     guard motion.allowsTransitions else { return }   -> guard !motion.allowsTransitions else
#     if motion.allowsContinuousMotion && visual.hasPulse -> if true && visual.hasPulse
#
# Yang **kedua** paling berbahaya, dan bukan karena geraknya hilang: `!` di
# depan penjaga membuat animasi berjalan **hanya** untuk pengguna yang meminta
# reduksi gerak, dan berhenti untuk semua orang lain. Preferensi accessibility
# yang dibalik adalah cacat yang tidak bisa dilihat oleh orang yang tidak
# memakai preferensi itu — termasuk semua orang yang mengembangkan app ini.
#
# **Kenapa arahnya bisa diperiksa.** Keempat penjaga di repo ini berbentuk
# nilai turunan yang sudah diuji di Linux (`MotionPolicy.allowsTransitions`,
# `allowsContinuousMotion`) atau preferensi mentah yang wajib dinegasikan
# (`!reduceMotion`, `!isLuminanceReduced`). Jadi pertanyaannya bukan "apakah
# kondisinya masuk akal" — itu butuh pelacakan alur yang tidak bisa dibuktikan
# sapuan teks — melainkan "apakah polaritasnya salah satu dari dua bentuk
# yang benar". Itu bisa dijawab.
#
# **Yang TIDAK diklaim.** Aturan ini membaca **kondisi penjaga terdekat**,
# bukan alur eksekusi. Penjaga di `if` bersaudara, atau penjaga yang benar
# tetapi dinegasikan lagi di dalam badan blok, tidak terlihat. Batas itu sama
# dengan Aturan 7, dan dinyatakan supaya tidak dikira lebih kuat dari
# kenyataannya.
#
# Fail-closed: nol API gerak = PERINGATAN, bukan hijau kosong.
echo
echo "== Aturan 58: penjaga gerak tidak dibalik atau diganti literal =="
arah_gerak=$(python3 - <<'PY' 2>&1
import os
import re

AKAR = "Apps"

API = re.compile(r"\bwithAnimation\b"
                 r"|\.repeatForever\b"
                 r"|TimelineView\(\s*\.animation"
                 r"|\.animation\s*\(")

#: Penjaga yang **wajib positif** (nilainya sudah berarti "boleh").
POSITIF = ("allowsTransitions", "allowsContinuousMotion")
#: Penjaga yang **wajib dinegasikan** (preferensi mentah: "dilarang").
NEGATIF = ("reduceMotion", "isLuminanceReduced")


def buang_komentar(src):
    """Buang `//` dan `/* */` di luar literal string."""
    out, i, n = [], 0, len(src)
    dalam, esc = False, False
    while i < n:
        ch = src[i]
        if dalam:
            out.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                dalam = False
            i += 1
            continue
        if ch == '"':
            dalam = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def blok(src):
    """Semua pasangan `{...}` berimbang sebagai (buka, tutup)."""
    tumpuk, hasil = [], []
    for i, ch in enumerate(src):
        if ch == "{":
            tumpuk.append(i)
        elif ch == "}" and tumpuk:
            hasil.append((tumpuk.pop(), i))
    return hasil


def _dinegasikan(kondisi, mulai, akhir):
    """Apakah **suku** yang memuat `[mulai, akhir)` dinegasikan.

    Negasi tidak menempel pada nama penjaganya: pada `!motion.allowsTransitions`
    tanda `!` mendahului **penerima** (`motion`), bukan propertinya. Karena itu
    yang diperiksa adalah awal suku (`&&`/`||` sebagai pemisah), bukan karakter
    tepat sebelum nama.

    Versi pertama aturan ini mencari `!` tepat sebelum nama, sehingga bentuk
    `!motion.allowsTransitions` -- justru yang paling berbahaya -- terbaca
    sebagai penjaga positif.

    Versi kedua memeriksa awal **seluruh operand**, dan itu memerah pada
    `!reduceMotion && illustration.hasPulse` untuk suku kedua: awal operand-nya
    `!`, padahal `!` itu milik suku pertama. Jadi `!` hanya dihitung kalau ia
    menempel pada suku ini -- yaitu tidak ada `&&`/`||` di antaranya.
    """
    # Awal suku: tepat **setelah** pemisah terakhir. `+2` hanya berlaku kalau
    # pemisahnya memang ada -- `rfind` mengembalikan -1 saat tidak ada, dan
    # `-1 + 2 = 1` memotong karakter pertama (`!`), sehingga
    # `!reduceMotion && ...` terbaca sebagai penjaga positif.
    kiri = max(kondisi.rfind("&&", 0, mulai),
               kondisi.rfind("||", 0, mulai))
    kiri = 0 if kiri < 0 else kiri + 2
    # Batas kanan harus **akhir suku**, bukan akhir nama. Kalau dipotong di
    # `akhir`, `!reduceMotion && illustration.hasPulse` untuk suku kedua
    # menghasilkan `!reduceMotion && illustration.hasPulse` (karena `&&` jatuh
    # di luar potongan) dan `!` milik suku pertama terbaca sebagai milik suku
    # ini -- gerbang memerah pada kode yang benar.
    kanan_kandidat = [x for x in (kondisi.find("&&", akhir),
                                  kondisi.find("||", akhir)) if x != -1]
    kanan = min(kanan_kandidat) if kanan_kandidat else len(kondisi)
    suku = kondisi[kiri:kanan].strip()
    return suku.lstrip("(").lstrip().startswith("!")


def masalah_polaritas(kondisi):
    """Salah arah? Kembalikan penjelasan, atau None kalau bentuknya sah."""
    if re.search(r"\bMotionPolicy\s*\(", kondisi):
        # Model yang memutuskan; arahnya diuji di Linux, bukan di sini.
        return None
    ketemu = False
    for nama in POSITIF + NEGATIF:
        for m in re.finditer(r"\b" + nama + r"\b", kondisi):
            ketemu = True
            dinegasikan = _dinegasikan(kondisi, m.start(), m.end())
            if nama in POSITIF and dinegasikan:
                return ("`!%s` membalik penjaga: gerak hanya berjalan saat "
                        "gerak justru dilarang" % nama)
            if nama in NEGATIF and not dinegasikan:
                return ("`%s` dipakai tanpa `!`: gerak berjalan saat "
                        "pengguna meminta reduksi gerak" % nama)
    if not ketemu:
        return ("penjaga tidak membaca kebijakan gerak sama sekali "
                "(literal `true` atau kondisi lain)")
    return None


berkas = []
for dasar, _, nama in os.walk(AKAR):
    for n in sorted(nama):
        if n.endswith(".swift"):
            berkas.append(os.path.join(dasar, n))

if not berkas:
    print("PERINGATAN: tidak ada berkas Swift di %s -- Aturan 58 tidak "
          "mengukur apa pun." % AKAR)
    raise SystemExit(0)

masalah = []
jumlah_api = 0
jumlah_penjaga = 0

for path in berkas:
    try:
        asli = open(path, encoding="utf-8").read()
    except OSError as e:
        print("PERINGATAN: %s tidak terbaca (%s)." % (path, e))
        raise SystemExit(0)
    src = buang_komentar(asli)
    semua_blok = blok(src)

    for m in API.finditer(src):
        pos = m.start()
        jumlah_api += 1
        # Blok yang memuat API ini, dari yang terdekat ke luar.
        memuat = [(o, c) for (o, c) in semua_blok if o < pos < c]
        memuat.sort(key=lambda oc: oc[1] - oc[0])

        kandidat = []   # (posisi, kondisi, jenis)
        for (o, c) in memuat:
            # (a) Blok yang dibuka oleh `if <kondisi> {`.
            awal_baris = src.rfind("\n", 0, o) + 1
            sebelum = src[awal_baris:o]
            mi = re.search(r"\bif\s+(.+?)\s*$", sebelum)
            if mi:
                kandidat.append((o, mi.group(1), "if"))
            # (b) `guard <kondisi> else` di dalam blok ini, sebelum API.
            for g in re.finditer(r"\bguard\s+([^\n{]+?)\s+else\b", src[o + 1:pos]):
                kandidat.append((o + 1 + g.start(), g.group(1), "guard"))

        if not kandidat:
            # Tidak ada penjaga: itu wilayah Aturan 7, bukan aturan ini.
            continue
        kandidat.sort()
        _, kondisi, jenis = kandidat[-1]
        jumlah_penjaga += 1
        salah = masalah_polaritas(kondisi)
        if salah:
            baris = src.count("\n", 0, pos) + 1
            masalah.append("  %s:%d: %s (%s `%s`)"
                           % (path, baris, salah, jenis, kondisi.strip()[:70]))

if jumlah_api == 0:
    print("PERINGATAN: tidak ada API gerak di %s -- Aturan 58 tidak "
          "mengukur satu penjaga pun." % AKAR)
    raise SystemExit(0)

if masalah:
    print("\n".join(masalah))
PY
)
if printf '%s' "$arah_gerak" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 58 tidak bisa memutuskan:"
  echo "$arah_gerak"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$arah_gerak" ]; then
  echo "$arah_gerak"
  echo "-> Penjaga yang dibalik membuat gerak berjalan hanya untuk pengguna"
  echo "   yang memintanya berhenti; penjaga literal membuatnya berjalan"
  echo "   untuk semua orang."
  status=1
else
  echo "Bersih: setiap penjaga gerak menghadap arah yang benar."
fi

# ── Aturan 59: kartu perkenalan harus bisa ditutup dan tidak kembali ────────
#
# Kelas cacatnya: `sheet(isPresented:)` dengan pengikat yang **tidak bisa
# berpindah ke `false`**. Perkenalan adalah satu-satunya layar yang menghalangi
# seluruh app, jadi cacat di sini bukan cacat kosmetik — ia adalah app yang
# tidak bisa dipakai sama sekali, atau kartu yang muncul setiap kali dibuka.
#
# Terukur pada salinan utuh, proses baru, sebelum aturan ini ada — keduanya
# mengompilasi dan **seluruh 58 aturan lulus (exit 0)**:
#
#     Watch  : get: { !onboardingSeen }  ->  get: { false }   -> exit 0
#     iPhone : get: { !onboardingSeen }  ->  get: { true }    -> exit 0
#
# `false` berarti perkenalan tidak pernah tampil: pengguna tidak pernah membaca
# satu-satunya kalimat yang menjelaskan bahwa app ini **boleh** menjawab "tidak
# tahu", lalu menafsirkan keraguan sebagai kerusakan. `true` lebih buruk:
# `set:` tetap menulis `onboardingSeen = true`, tetapi `get:` tidak pernah
# membacanya, jadi sheet tidak pernah bisa ditutup dan app jam tidak bisa
# dipakai.
#
# **Kenapa kedua arah diperiksa, bukan hanya "jangan literal".** Penjaga yang
# hanya melarang literal akan hijau pada `get: { onboardingSeen }` — bentuk
# yang memakai token, mengompilasi, dan membalik artinya: perkenalan muncul
# **hanya setelah** pengguna menutupnya. Yang benar adalah satu ekspresi
# tertentu, jadi yang diperiksa adalah ekspresi itu.
#
# Fail-closed: nol pemanggil `OnboardingView` di `sheet` = PERINGATAN. Itu
# bentuk kegagalan yang paling mungkin: perkenalan dipindah ke `fullScreenCover`
# atau ke alur onboarding baru, dan aturan ini diam-diam berhenti menjaga.
echo
echo "== Aturan 59: kartu perkenalan bisa ditutup dan tidak kembali =="
kartu_perkenalan=$(python3 - <<'PY' 2>&1
import os
import re

AKAR = "Apps"

def buang_komentar(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    return re.sub(r"//[^\n]*", "", s)

def blok_dari(isi, buka):
    dalam = 0
    for i in range(buka, len(isi)):
        if isi[i] == "{":
            dalam += 1
        elif isi[i] == "}":
            dalam -= 1
            if dalam == 0:
                return isi[buka + 1:i], i
    return None, -1

berkas = []
for dasar, _, nama in os.walk(AKAR):
    for n in sorted(nama):
        if n.endswith(".swift"):
            berkas.append(os.path.join(dasar, n))

if not berkas:
    print("PERINGATAN: tidak ada berkas Swift di %s -- Aturan 59 tidak "
          "mengukur apa pun." % AKAR)
    raise SystemExit(0)

masalah = []
jumlah = 0

for path in berkas:
    try:
        isi = buang_komentar(open(path, encoding="utf-8").read())
    except OSError as e:
        print("PERINGATAN: %s tidak terbaca (%s)." % (path, e))
        raise SystemExit(0)

    for m in re.finditer(r"\.sheet\s*\(\s*isPresented\s*:", isi):
        # Isi panggilan `.sheet(...)` sampai kurung penutupnya.
        buka = isi.find("(", m.start())
        dalam, akhir = 0, -1
        for i in range(buka, len(isi)):
            if isi[i] == "(":
                dalam += 1
            elif isi[i] == ")":
                dalam -= 1
                if dalam == 0:
                    akhir = i
                    break
        if akhir < 0:
            masalah.append("  %s: `.sheet(isPresented:)` tanpa kurung "
                           "seimbang -- aturan tidak bisa memutuskan." % path)
            continue
        panggilan = isi[buka:akhir + 1]
        # Isi sheet ada di **trailing closure**, di luar kurung penutup
        # `isPresented:`: `.sheet(isPresented: .init(...)) { OnboardingView() }`.
        # Tanpa menyertakannya, aturan ini tidak pernah melihat view-nya dan
        # melaporkan "tidak mengukur satu layar pun" pada kode yang benar.
        sesudah = akhir + 1
        while sesudah < len(isi) and isi[sesudah] in " \t\n":
            sesudah += 1
        if sesudah < len(isi) and isi[sesudah] == "{":
            badan_sheet, tutup = blok_dari(isi, sesudah)
            if badan_sheet is not None:
                panggilan += badan_sheet
        if "OnboardingView" not in panggilan:
            # Sheet lain (mis. detail objek) bukan wilayah aturan ini.
            continue
        jumlah += 1

        # `get:` harus `!<kunci>`; `set:` harus menulis kunci yang sama.
        mi = re.search(r"get\s*:\s*\{\s*([^}]*?)\s*\}", panggilan)
        if not mi:
            masalah.append(
                "  %s: sheet perkenalan tanpa `get:` -- aturan tidak bisa "
                "memastikan kapan kartunya tampil." % path)
            continue
        get = mi.group(1).strip()
        if not re.fullmatch(r"!\s*[A-Za-z_]\w*", get):
            masalah.append(
                "  %s: `get: { %s }` -- perkenalan harus tampil **tepat saat "
                "belum pernah dilihat** (`!<kunci>`). Bentuk lain membuatnya "
                "tidak pernah tampil, atau tidak pernah bisa ditutup."
                % (path, get))

        # `set: { seen in onboardingSeen = seen }` -- yang harus sama dengan
        # `get:` adalah **kunci yang ditulis**, bukan parameter masuknya.
        ms = re.search(r"set\s*:\s*\{([^{}]*)\}", panggilan)
        if not ms:
            masalah.append(
                "  %s: sheet perkenalan tanpa `set:` -- `onDone` tidak "
                "menyimpan apa pun, jadi kartunya muncul lagi tiap buka."
                % path)
            continue
        badan_set = ms.group(1) if ms.groups() else ""
        mt = re.search(r"([A-Za-z_]\w*)\s*=\s*[^=]", badan_set)
        if not mt:
            masalah.append(
                "  %s: `set:` tidak menulis kunci apa pun -- menutup kartu "
                "tidak menyimpan apa-apa." % path)
            continue
        set_val = mt.group(1)
        kunci_get = get.lstrip("! ").strip()
        if set_val != kunci_get:
            masalah.append(
                "  %s: `set:` menulis `%s` tetapi `get:` membaca `%s` -- "
                "menutup kartu tidak mengubah yang dibacanya." %
                (path, set_val, kunci_get))

        # `onDone` harus menutup kartu, bukan sekadar ada.
        mo = re.search(r"OnboardingView\s*\(\s*onDone\s*:\s*\{([^}]*)\}", panggilan)
        if not mo:
            masalah.append(
                "  %s: `OnboardingView` tanpa `onDone:` -- tombol tutup tidak "
                "melakukan apa pun." % path)
        else:
            badan = mo.group(1).strip()
            if "= true" not in badan and "=true" not in badan:
                masalah.append(
                    "  %s: `onDone: { %s }` tidak menandai perkenalan sudah "
                    "dilihat -- kartunya muncul lagi setiap kali app dibuka."
                    % (path, badan))

if jumlah == 0:
    print("PERINGATAN: tidak ada sheet perkenalan di %s -- Aturan 59 tidak "
          "mengukur satu layar pun." % AKAR)
    raise SystemExit(0)

if masalah:
    print("\n".join(masalah))
PY
)
if printf '%s' "$kartu_perkenalan" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 59 tidak bisa memutuskan:"
  echo "$kartu_perkenalan"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$kartu_perkenalan" ]; then
  echo "$kartu_perkenalan"
  echo "-> Perkenalan adalah layar yang menghalangi seluruh app: salah di"
  echo "   sini berarti app yang tidak bisa dipakai, atau kartu yang tak"
  echo "   pernah berhenti muncul."
  status=1
else
  echo "Bersih: perkenalan tampil sekali, bisa ditutup, dan tidak kembali."
fi

# ── Aturan 60: penanda kejujuran yang DIGAMBAR wajib dijaga predikatnya ────
#
# Kelas cacat yang ditutup aturan ini **diukur**, bukan disangka. Sampai siklus
# ini, 59 aturan menjaga **dari mana** fakta kejujuran datang (Aturan 34/35/38/
# 42/52 menelusuri argumen dan badan penerus), tetapi tidak satu pun membaca
# **tempat penandanya digambar**. Terukur pada salinan utuh (proses baru,
# `Apps/` + `Packages/` dibawa), dengan mutasi yang semuanya **mengompilasi**:
#
#   PointingView:        `if isStale {` -> `if false {`         exit 0
#   PointingView:        `if let level, !isStale {` -> tanpa !  exit 0
#   PointingView:        label a11y `if isStale {` -> `if false` exit 0
#   ReducedLuminanceView:`if engine.isDisplayingStaleObject {` -> `if false` exit 0
#   ReducedLuminanceView:`if engine.carriesUncertaintyMarker {` -> `if false` exit 0
#   DiagnosticsView:     `if let level, !isStale {` -> tanpa !   exit 0
#   DiagnosticsView:     `stale: isStale,` -> `stale: false,`    exit 0
#
# Tujuh cacat, satu kelas: **penanda yang menyatakan "ini basi" atau "ini
# ragu" bisa dihapus dari empat permukaan layar tanpa satu gerbang berbunyi.**
# Itu bukan cacat kosmetik. PRD menaruh "uncertainty > false confidence" sebagai
# aturan pertama, dan yang dihapus di sini justru satu-satunya hal di layar
# yang memberi tahu pengguna bahwa engine **tidak** yakin:
#
#   * `if false` pada `isStale` membuat objek sisa pandangan sebelumnya tampil
#     persis seperti hasil pengukuran sekarang — di layar redup, di mana nama
#     itu huruf terbesar di layar.
#   * `if let level` tanpa `!isStale` menempelkan badge "Yakin" pada objek
#     basi — klaim keyakinan atas pengukuran yang tidak sedang berlangsung.
#   * `if false` pada `carriesUncertaintyMarker` membuat **nama kandidat**
#     tampil sebagai temuan, bukan sebagai kandidat.
#
# Kenapa Aturan 34/35/38/42/52 tidak menangkapnya: kelimanya mengawasi
# **argumen pemanggil** dan **badan penerus**. Di ketujuh mutasi di atas,
# pemanggilnya tidak berubah sama sekali — `engine.isDisplayingStaleObject`
# tetap dikirim apa adanya ke `isStale:`. Yang berubah adalah **cabang yang
# menggambar** penandanya, dan cabang itu tidak pernah dibaca siapa pun.
# `Apps/` juga tidak pernah dibangun `swift-test.sh` di Linux, jadi tidak ada
# jalur kedua yang bisa menangkapnya.
#
# **Kenapa aturan ini menurunkan prinsipnya, bukan mendaftar situsnya.**
# Daftar situs akan basi diam-diam — persis yang sudah dua kali menjatuhkan
# `main` di repo ini (daftar gerbang, daftar jangkar). Yang dipakai:
#
#     setiap tempat yang MENGGAMBAR penanda kejujuran wajib berada di dalam
#     `if`/`guard` yang membaca predikat fakta itu — atau di dalam `case`
#     sebuah `switch` atas keputusan model yang sudah diuji di Linux.
#
# Penandanya dikenali dari **bentuk yang digambar**, bukan dari nama variabel
# view: `Text(level.displayName)` (badge keyakinan), kunci katalog
# `.objectDetailStaleNoteDisplay` / `.confidenceUncertainMarker`, dan
# `ObjectSpeech.staleShortNote` / `.staleNote`. Menambah permukaan baru yang
# memakai salah satu bentuk itu otomatis ikut terjaga.
#
# **Kenapa `switch` diterima sebagai bentuk sah.** `ComplicationWidget.subline`
# memutuskan prioritas baris kedua di `ComplicationDigest.sublineContent(at:)`
# — model yang teruji di Linux (`ComplicationDigestStalenessTests`). Menuntut
# `if` di sana akan menuduh kode yang benar, dan gerbang yang menuduh kode
# benar akan dilonggarkan orang. Yang disyaratkan: `switch`-nya atas
# keputusan model (`digest.`/`engine.`/`snapshot.`), bukan atas nilai lokal.
#
# **Arah kedua: literal di pemanggil.** Satu cacat di daftar di atas berbeda
# arah — `stale: isStale` -> `stale: false` di panel iPhone. Badannya benar
# (ia memakai `stale` sebagai syarat penanda), yang berbohong adalah
# pemanggilnya. Karena itu aturan ini juga menelusuri fungsi yang **badannya**
# memakai parameter sebagai syarat penanda, lalu menolak literal untuk
# parameter itu di setiap pemanggilan. Yang **tidak** ikut: parameter tampilan
# seperti `includeTechnicalDetails: false` — ia mengatur berapa banyak yang
# ditampilkan, bukan apa yang benar.
#
# Yang TIDAK diklaim aturan ini. Ia sapu teks, bukan pemeriksa tipe: ia tidak
# tahu apakah `isStale` benar-benar Bool yang dimaksud, tidak membaca blok
# komentar `/* */`, dan tidak menilai apakah `if`-nya **cukup** (mis. `if
# isStale || true` lolos). Yang ditutup adalah bentuk yang paling senyap dan
# paling mudah terjadi saat merapikan tampilan: penanda yang **dicabut** dari
# syaratnya, atau syaratnya diganti literal.
echo
echo "== Aturan 60: penanda kejujuran yang digambar dijaga predikatnya =="
penanda_jujur=$(python3 - <<'PY' 2>&1
import os
import re


def kode_saja(teks):
    """Buang komentar `//` dan isi literal string (sama seperti Aturan 38)."""
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam:
                if esc:
                    esc = False
                    buf.append(" ")
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam = False
                    buf.append('"')
                else:
                    buf.append(" ")
            else:
                if ch == '"':
                    dalam = True
                    buf.append('"')
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


def blok(kode, kata_kunci):
    """Rentang `kata_kunci <kondisi> { ... }` beserta teks kondisinya."""
    hasil = []
    for m in re.finditer(kata_kunci, kode):
        i = m.end()
        kedalaman, j = 0, i
        while j < len(kode):
            ch = kode[j]
            if ch in "([":
                kedalaman += 1
            elif ch in ")]":
                kedalaman -= 1
            elif ch == "{" and kedalaman == 0:
                break
            j += 1
        if j >= len(kode):
            continue
        kondisi = " ".join(kode[i:j].split())
        d, k = 0, j
        while k < len(kode):
            if kode[k] == "{":
                d += 1
            elif kode[k] == "}":
                d -= 1
                if d == 0:
                    break
            k += 1
        hasil.append((m.start(), kondisi, j, k))
    return hasil


def kasus_switch(kode):
    """Rentang badan setiap `case` di dalam setiap `switch`, beserta judulnya.

    `case` Swift tidak memakai kurung kurawal: badannya berakhir di `case`/
    `default` berikutnya pada kedalaman yang sama. Karena itu `blok()` tidak
    bisa dipakai untuknya.
    """
    hasil = []
    for m in re.finditer(r"(?<![\w.])switch\b", kode):
        i = kode.find("{", m.end())
        if i < 0:
            continue
        d, j = 0, i
        while j < len(kode):
            if kode[j] == "{":
                d += 1
            elif kode[j] == "}":
                d -= 1
                if d == 0:
                    break
            j += 1
        judul = " ".join(kode[m.end():i].split())
        tanda = []
        d = 0
        k = i
        while k < j:
            ch = kode[k]
            if ch == "{":
                d += 1
            elif ch == "}":
                d -= 1
            elif d == 1 and (kode.startswith("case ", k)
                             or kode.startswith("default", k)):
                batas = kode.find(":", k)
                if batas > 0:
                    tanda.append((k, batas, " ".join(kode[k:batas].split())))
                    k = batas
            k += 1
        for n, (awal, titikdua, teks) in enumerate(tanda):
            akhir = tanda[n + 1][0] if n + 1 < len(tanda) else j
            hasil.append((awal, teks, titikdua, akhir, judul))
    return hasil


#: (pola yang menggambar penanda, sebutan, ejaan predikat yang sah)
#: `(nama, positif)` -- `positif=False` berarti penandanya justru harus
#: disembunyikan saat fakta itu benar (`badge` hanya untuk yang berlaku).
PENANDA = [
    (r"Text\(\s*level\.displayName\s*\)", "badge keyakinan",
     [("isStale", False)]),
    (r"\.objectDetailStaleNoteDisplay\b", "catatan sisa (panel)",
     [("isStale", True)]),
    (r"\.confidenceUncertainMarker\b", "penanda ragu",
     [("carriesUncertaintyMarker", True)]),
    (r"ObjectSpeech\.staleShortNote\b", "penanda sisa (layar redup)",
     [("isDisplayingStaleObject", True)]),
    (r"ObjectSpeech\.staleNote\b", "penanda sisa (VoiceOver)",
     [("isStale", True), ("stale", True)]),
]

masalah = []
terbaca = 0
lewat_model = 0
berkas = []

for root, dirs, files in os.walk("Apps"):
    dirs[:] = [d for d in dirs if d not in (".build", "build")]
    for nama in sorted(files):
        if nama.endswith(".swift"):
            berkas.append(os.path.join(root, nama))

for path in berkas:
    kode = kode_saja(open(path, encoding="utf-8").read())
    ifs = blok(kode, r"(?<![\w.])if\b") + blok(kode, r"(?<![\w.])guard\b")
    kasus = kasus_switch(kode)
    for pola, sebutan, sah in PENANDA:
        for m in re.finditer(pola, kode):
            terbaca += 1
            baris = kode[:m.start()].count("\n") + 1
            dalam = [b for b in ifs if b[2] < m.start() < b[3]]
            if dalam:
                kondisi = max(dalam, key=lambda b: b[0])[1]
                ok = False
                for predikat, positif in sah:
                    if positif:
                        if re.search(r"(?<![!])\b" + re.escape(predikat)
                                     + r"\b", kondisi):
                            ok = True
                    else:
                        if re.search(r"!\s*" + re.escape(predikat)
                                     + r"\b", kondisi):
                            ok = True
                if ok:
                    continue
                masalah.append(
                    "  %s:%d: %s di dalam `if %s` -- predikat %s tidak dibaca, "
                    "jadi penandanya bisa hilang atau menyala pada keadaan "
                    "yang salah" % (path, baris, sebutan, kondisi,
                                    "/".join(p for p, _ in sah)))
                continue
            # Bentuk sah kedua: `case` pada switch atas keputusan model.
            dalam_case = [b for b in kasus if b[2] < m.start() < b[3]]
            if dalam_case:
                terdekat = max(dalam_case, key=lambda b: b[0])
                if re.search(r"\b(digest|engine|snapshot)\.", terdekat[4]):
                    lewat_model += 1
                    continue
            masalah.append(
                "  %s:%d: %s tampil TANPA syarat -- penanda kejujuran yang "
                "tidak dijaga predikatnya" % (path, baris, sebutan))


def fungsi_penanda(kode):
    """Fungsi yang badannya memakai parameter sebagai syarat penanda."""
    hasil = []
    for m in re.finditer(r"\bfunc\s+([A-Za-z_]\w*)\s*\(", kode):
        i = kode.find("(", m.end() - 1)
        d, j = 0, i
        while j < len(kode):
            if kode[j] == "(":
                d += 1
            elif kode[j] == ")":
                d -= 1
                if d == 0:
                    break
            j += 1
        kurung = kode[i + 1:j]
        k = kode.find("{", j)
        if k < 0:
            continue
        d, e = 0, k
        while e < len(kode):
            if kode[e] == "{":
                d += 1
            elif kode[e] == "}":
                d -= 1
                if d == 0:
                    break
            e += 1
        badan = kode[k:e]
        if not any(re.search(p, badan) for p, _, _ in PENANDA):
            continue
        # Hanya parameter yang menjadi syarat **blok berisi penanda**.
        # Parameter tampilan (mis. `includeTechnicalDetails`) sah dikirim
        # literal: ia mengatur berapa banyak yang ditampilkan, bukan apa
        # yang benar.
        syarat = []
        for b in blok(badan, r"(?<![\w.])if\b"):
            isi = badan[b[2]:b[3]]
            if any(re.search(p, isi) for p, _, _ in PENANDA):
                syarat.append(b[1])
        syarat = " ".join(syarat)
        parameter = []
        for pm in re.finditer(r"([A-Za-z_]\w*)\s*:\s*(?:Bool|String\??)\b", kurung):
            nama = pm.group(1)
            if re.search(r"\b" + re.escape(nama) + r"\b", syarat):
                parameter.append(nama)
        if parameter:
            hasil.append((m.group(1), parameter))
    return hasil


# Arah kedua: pemanggil fungsi penanda tidak boleh mengirim literal untuk
# parameter yang badannya pakai sebagai syarat.
for path in berkas:
    kode = kode_saja(open(path, encoding="utf-8").read())
    for fungsi, parameter in fungsi_penanda(kode):
        for pm in re.finditer(r"\b" + re.escape(fungsi) + r"\s*\(", kode):
            i = kode.find("(", pm.end() - 1)
            d, j = 0, i
            while j < len(kode):
                if kode[j] == "(":
                    d += 1
                elif kode[j] == ")":
                    d -= 1
                    if d == 0:
                        break
                j += 1
            daftar = kode[i + 1:j]
            for p in parameter:
                am = re.search(r"\b" + re.escape(p) + r"\s*:\s*"
                               r"(true|false|nil)\b", daftar)
                if not am:
                    continue
                terbaca += 1
                masalah.append(
                    "  %s:%d: `%s` menerima `%s: %s` -- literal, padahal "
                    "badannya memakai parameter itu untuk memutuskan penanda "
                    "kejujuran" % (path, kode[:pm.start()].count("\n") + 1,
                                   fungsi, p, am.group(1)))

# Keluaran bersih sengaja berbentuk ringkas yang **dikenali** di bawah: pesan
# "Bersih" biasa akan terbaca sebagai temuan oleh cabang `elif [ -n ... ]`,
# dan aturan yang hijau akan memerahkan gerbangnya sendiri.
if terbaca == 0:
    print("PERINGATAN: tidak ada penanda kejujuran yang terbaca di Apps/ -- "
          "aturan ini tidak mengukur apa pun.")
elif masalah:
    print("\n".join(masalah))
else:
    print("JUMLAH %d %d" % (terbaca, lewat_model))
PY
)
jumlah_penanda=$(printf '%s' "$penanda_jujur" | sed -n 's/^JUMLAH \([0-9]*\) \([0-9]*\)$/\1 \2/p')
if printf '%s' "$penanda_jujur" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 60 tidak bisa memutuskan:"
  echo "$penanda_jujur"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$penanda_jujur" ] && [ -z "$jumlah_penanda" ]; then
  echo "$penanda_jujur"
  echo "-> Penanda \"basi\"/\"ragu\" hanya boleh muncul di bawah predikat yang"
  echo "   menyatakan fakta itu. Tanpa syarat, layar mengklaim lebih daripada"
  echo "   yang diketahui engine -- persis yang dilarang PRD."
  status=1
else
  echo "Bersih: $(echo "$jumlah_penanda" | cut -d' ' -f1) penanda kejujuran" \
       "dijaga predikatnya ($(echo "$jumlah_penanda" | cut -d' ' -f2) lewat" \
       "keputusan model)."
fi

# ── Aturan 61: sinyal yang HANYA dibedakan warna wajib punya penanda kedua ──
#
# Kelas cacat yang ditutup aturan ini **diukur**, bukan disangka. Sapuan teks
# atas seluruh `Apps/` menemukan lima `foregroundStyle(<kondisi> ? … : …)`.
# Tiga di antaranya sudah membawa penanda kedua di teksnya sendiri:
#
#   PointingView:169      ikon berubah bentuk (`scope` vs `exclamationmark.circle`)
#   CalibrationView:203   teksnya memuat angka spread dan ambangnya
#   Experiment1View:282   teksnya memuat putusan ("Salah kunci"/"Benar"/"Salah")
#
# Dua sisanya tidak:
#
#   PointingView:279      laju sudut — angka yang sama, hanya warnanya berubah
#   Experiment1View:142   "lokasi darurat" — teksnya bergantung pada nilai yang
#                         SAMA, tapi tidak satu katanya menyebut bahwa itu
#                         perkiraan
#
# Keduanya lolos seluruh 60 aturan, dan keduanya adalah WCAG 1.4.1 (Use of
# Color): informasi yang disampaikan **hanya** lewat warna. Bagi pengguna
# buta warna — deuteranopia adalah ~6% pria — jam yang bergetar terlalu cepat
# dan jam yang diam terbaca sama persis. Untuk cacat di `PointingView:279` itu
# bukan cacat kosmetik: seluruh gunanya layar ini adalah memberi tahu bahwa
# pergelangan masih bergerak, dan itulah satu-satunya alasan engine menahan
# kunci.
#
# **Kenapa aturan ini menurunkan prinsipnya, bukan mendaftar dua situsnya.**
# Daftar situs akan basi diam-diam. Yang dipakai:
#
#     `foregroundStyle(<kondisi> ? A : B)` boleh, asalkan di cabang yang SAMA
#     ada teks yang juga bergantung pada `<kondisi>` itu — bukan pada nilai
#     lain yang kebetulan searah.
#
# Bentuk terakhir itu yang paling mudah salah dan yang paling sulit dilihat:
# `Experiment1View:142` punya teks yang **memang** bercabang pada
# `isFallback` — jadi pemeriksaan naif ("ada `isFallback` di blok itu?") akan
# hijau. Yang diperiksa karena itu bukan keberadaan kondisinya, melainkan
# apakah teksnya **menyatakan** hal yang dibedakan warnanya.
#
# **Batas yang dinyatakan, bukan disangka tertutup.** Aturan ini sapu teks: ia
# tidak tahu apakah teks yang bergantung pada kondisi itu benar-benar terbaca
# (bisa jadi `lineLimit(0)`), dan ia tidak memeriksa kontras. Ia menutup satu
# bentuk yang paling senyap — warna sebagai satu-satunya pembeda — bukan
# seluruh WCAG 1.4.1.
echo
echo "== Aturan 61: sinyal yang hanya dibedakan warna punya penanda kedua =="
sinyal_warna=$(python3 - <<'PY' 2>&1
import os
import re


def kode_saja(teks):
    """Buang komentar `//` dan isi literal string (sama seperti Aturan 38)."""
    hasil = []
    for baris in teks.split("\n"):
        buf, i, dalam, esc = [], 0, False, False
        while i < len(baris):
            ch = baris[i]
            if dalam:
                if esc:
                    esc = False
                    buf.append(" ")
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    dalam = False
                    buf.append('"')
                else:
                    buf.append(" ")
            else:
                if ch == '"':
                    dalam = True
                    buf.append('"')
                elif ch == "/" and i + 1 < len(baris) and baris[i + 1] == "/":
                    break
                else:
                    buf.append(ch)
            i += 1
        hasil.append("".join(buf))
    return "\n".join(hasil)


def imbang(kode, mulai, buka="(", tutup=")"):
    """Indeks penutup yang sepadan untuk kurung yang mulai di `mulai`."""
    d, j = 0, mulai
    while j < len(kode):
        if kode[j] == buka:
            d += 1
        elif kode[j] == tutup:
            d -= 1
            if d == 0:
                return j
        j += 1
    return -1


def kondisi_dari(expr):
    """Ambil `<kondisi>` dari `<kondisi> ? A : B` (ternary tingkat atas)."""
    d = 0
    for i, ch in enumerate(expr):
        if ch in "([":
            d += 1
        elif ch in ")]":
            d -= 1
        elif ch == "?" and d == 0:
            return expr[:i].strip()
    return None


def blok_terdekat(kode, pos):
    """Teks blok `{...}` terdalam yang memuat `pos`, atau None."""
    terbaik = None
    for m in re.finditer(r"\{", kode):
        if m.start() >= pos:
            continue
        akhir = imbang(kode, m.start(), "{", "}")
        if akhir > pos:
            if terbaik is None or m.start() > terbaik[0]:
                terbaik = (m.start(), akhir)
    if terbaik is None:
        return None
    return kode[terbaik[0] + 1:terbaik[1]]


#: Penanda kedua yang diterima: perubahan **bentuk** ikon (SF Symbol yang
#: dipilih oleh kondisi yang sama) dan teks yang bercabang pada kondisi itu.
masalah = []
terbaca = 0
punya_penanda = 0

for root, dirs, files in os.walk("Apps"):
    dirs[:] = [d for d in dirs if d not in (".build", "build")]
    for nama in sorted(files):
        if not nama.endswith(".swift"):
            continue
        path = os.path.join(root, nama)
        kode = kode_saja(open(path, encoding="utf-8").read())
        for m in re.finditer(r"\.foregroundStyle\s*\(", kode):
            buka = m.end() - 1
            tutup = imbang(kode, buka)
            if tutup < 0:
                continue
            expr = " ".join(kode[buka + 1:tutup].split())
            kondisi = kondisi_dari(expr)
            if kondisi is None:
                continue  # warna tetap: bukan sinyal, tidak ada yang dibedakan
            terbaca += 1
            baris = kode[:m.start()].count("\n") + 1
            blok = blok_terdekat(kode, m.start())
            if blok is None:
                masalah.append(
                    "  %s:%d: `foregroundStyle(%s)` -- warna bergantung "
                    "kondisi di luar blok mana pun, jadi tidak ada teks yang "
                    "bisa menyatakan hal yang sama" % (path, baris, expr))
                continue
            # Penanda kedua yang diterima, dan **hanya** ini:
            #
            #   (a) `if <kondisi>` di blok yang sama -- kata yang menyatakan
            #       keadaannya, mis. `if tooFast { Text("Cepat") }`.
            #   (b) `Image(systemName: <kondisi> ? … : …)` -- bentuk berubah,
            #       bukan warna.
            #   (c) `Text(...)` yang memuat kondisi itu sendiri.
            #   (d) `Text(...)` yang memuat **semua** nilai yang dibandingkan
            #       kondisi itu, sehingga pembacanya bisa membandingkan sendiri
            #       tanpa warna.
            #
            # (d) ada karena versi pertama aturan ini menuduh kode yang benar:
            # baris sebaran kalibrasi menampilkan "Sebaran 1.2° (maks 3.0°)"
            # dan mewarnainya hijau/kuning. Warnanya memang satu-satunya
            # pembeda **warna**, tetapi bukan satu-satunya pembeda informasi:
            # kedua angka yang dibandingkan ada di layar, jadi pengguna buta
            # warna tetap bisa menyimpulkan sendiri. Gerbang yang menuduh kode
            # benar akan dilonggarkan orang, jadi bentuk ini diterima.
            #
            # Yang **tidak** diterima (d): menampilkan hanya satu dari dua
            # nilai. Baris laju sudut menampilkan angkanya ("12°/s") tetapi
            # tidak pernah menyebut ambangnya, jadi "terlalu cepat" tidak bisa
            # disimpulkan tanpa warna -- dan itulah cacat yang ditutup.
            ada_teks = re.search(r"(?<![\w.])if\b[^{]*"
                                 + re.escape(kondisi) + r"\b", blok)
            ada_bentuk = re.search(r"systemName\s*:\s*[^,\n]*"
                                   + re.escape(kondisi) + r"\b", blok)
            ada_teks_langsung = re.search(r"Text\s*\([^()]*"
                                          + re.escape(kondisi) + r"\b", blok)
            ada_nilai_lengkap = False
            if not (ada_teks or ada_bentuk or ada_teks_langsung):
                # Semua pengenal yang dibandingkan kondisi (buang kata kunci
                # dan angka), lalu tuntut masing-masing muncul di sebuah
                # `Text(...)` pada blok yang sama.
                operan = [w for w in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", kondisi)
                          if w not in {"true", "false", "nil"}]
                if len(operan) >= 2:
                    teks_blok = " ".join(
                        " ".join(kode2.split())
                        for kode2 in re.findall(r"Text\s*\(([^;]*?)\)\s*\n",
                                                blok, flags=re.S))
                    ada_nilai_lengkap = all(
                        re.search(r"\b" + re.escape(o) + r"\b", teks_blok)
                        for o in operan)
            if ada_teks or ada_bentuk or ada_teks_langsung or ada_nilai_lengkap:
                punya_penanda += 1
                continue
            masalah.append(
                "  %s:%d: `foregroundStyle(... ? ... : ...)` atas `%s` -- "
                "hanya warna yang membedakan; pengguna buta warna membaca dua "
                "keadaan itu sama persis" % (path, baris, kondisi))

if terbaca == 0:
    print("PERINGATAN: tidak ada `foregroundStyle` berkondisi di Apps/ -- "
          "aturan ini tidak mengukur apa pun.")
elif masalah:
    print("\n".join(masalah))
else:
    print("JUMLAH %d %d" % (terbaca, punya_penanda))
PY
)
jumlah_warna=$(printf '%s' "$sinyal_warna" | sed -n 's/^JUMLAH \([0-9]*\) \([0-9]*\)$/\1 \2/p')
if printf '%s' "$sinyal_warna" | grep -q "PERINGATAN\|Traceback"; then
  echo "Pemeriksaan Aturan 61 tidak bisa memutuskan:"
  echo "$sinyal_warna"
  echo "-> Anggap GAGAL, bukan bersih."
  status=1
elif [ -n "$sinyal_warna" ] && [ -z "$jumlah_warna" ]; then
  echo "$sinyal_warna"
  echo "-> Sinyal yang hanya dibedakan warna tidak terbaca oleh pengguna buta"
  echo "   warna. Tambahkan penanda kedua yang dibaca mata DAN VoiceOver:"
  echo "   bentuk ikon yang berubah, atau kata di teksnya."
  status=1
else
  echo "Bersih: $(echo "$jumlah_warna" | cut -d' ' -f1) sinyal berwarna," \
       "semuanya punya penanda kedua."
fi

# ── Aturan 62: layar yang mengenali objek wajib menggambar visualnya ────────
#
# Kelas cacat yang ditutup aturan ini **diukur**, bukan disangka.
#
# Seluruh misi produk ini adalah "arahkan jam ke langit, ketahui apa yang kamu
# lihat". Ketika engine mengenali objek, hal yang membuat pengguna percaya
# adalah **bentuknya** — pita Jupiter, cincin Saturnus, sabit Bulan. Teks saja
# sudah ada sebelum misi poles dimulai.
#
# Dua mutasi berikut mengompilasi dan membuat seluruh **61** aturan tetap
# hijau, dan keduanya menghapus persis hal itu:
#
#     PointingView.swift      `if let visual {`  -> `if false {`      exit 0
#     DiagnosticsView.swift   `CelestialVisualView(...)` -> `EmptyView()`  exit 0
#
# Yang pertama adalah kartu jawaban di jam — satu-satunya tempat pengguna
# melihat objek saat `.lock`. Yang kedua adalah panel detail iPhone. Setelah
# mutasi itu aplikasi tetap berjalan, tetap mengunci objek dengan benar, tetap
# menulis namanya, dan tetap lulus setiap gerbang: hanya gambarnya yang hilang.
#
# Kenapa tidak ada gerbang yang menangkapnya: `check-visuals.py` membaca
# `CelestialVisualView.swift` (penggambarnya) dan port Python-nya, jadi ia bisa
# membuktikan pita Jupiter digambar dengan benar **tanpa pernah bertanya apakah
# penggambar itu dipanggil di layar**. Aturan 34 menjaga argumen
# `isConfirmed:` pada pemanggilan itu, bukan keberadaan pemanggilannya.
#
# Yang diperiksa karena itu bukan "apakah `CelestialVisualView` ada di berkas",
# melainkan: setiap permukaan yang **menyatakan identitas objek** harus
# memuat pemanggilan penggambar visual di dalam badan yang sama, dan
# pemanggilan itu tidak boleh berada di bawah kondisi yang selalu salah.
echo
echo "== Aturan 62: layar yang mengenali objek wajib menggambar visualnya =="
visual_objek=$(python3 - <<'PY' 2>&1
import os
import re
import sys

MASALAH = []
TERBACA = 0


def tanpa_komentar(swift):
    """Buang komentar `//` dan `/* */`, jaga isi string.

    **Kenapa wajib.** Percobaan pertama aturan ini melaporkan "Bersih" untuk
    pemanggilan yang sudah diganti `EmptyView() // CelestialVisualView(...)`:
    nama itu masih ADA di berkas, di dalam komentar. Gerbang yang bisa
    dipuaskan dengan mengomentari kode akan dipuaskan dengan mengomentari kode.
    """
    hasil = []
    i = 0
    n = len(swift)
    while i < n:
        dua = swift[i:i + 2]
        if dua == "//":
            j = swift.find("\n", i)
            if j < 0:
                break
            hasil.append(" " * (j - i))
            i = j
        elif dua == "/*":
            j = swift.find("*/", i + 2)
            if j < 0:
                hasil.append(" " * (n - i))
                break
            potong = swift[i:j + 2]
            hasil.append("".join("\n" if c == "\n" else " " for c in potong))
            i = j + 2
        elif swift[i] == '"':
            j = i + 1
            while j < n:
                if swift[j] == "\\":
                    j += 2
                    continue
                if swift[j] == '"':
                    j += 1
                    break
                j += 1
            hasil.append(swift[i:j])
            i = j
        else:
            hasil.append(swift[i])
            i += 1
    return "".join(hasil)


# Permukaan yang menyatakan identitas objek, beserta penanda bahwa ia memang
# permukaan jawaban. Yang dituntut: pemanggilan penggambar di badan yang sama.
PERMUKAAN = [
    ("Apps/PointAndKnowWatch/Sources/PointingView.swift",
     "kartu jawaban jam"),
    ("Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift",
     "panel detail iPhone"),
]

PENGGAMBAR = "CelestialVisualView("

# Kondisi yang selalu salah: pemanggilan di bawahnya tidak pernah tampil.
SELALU_SALAH = re.compile(r"(?<![\w.])if\s+false\b|\bguard\s+false\b")

for path, sebutan in PERMUKAAN:
    if not os.path.exists(path):
        MASALAH.append("  %s: berkas %s tidak ada -- permukaan %s hilang, "
                       "dan aturan ini tidak bisa memeriksanya"
                       % (path, path, sebutan))
        continue
    with open(path, encoding="utf-8") as handle:
        sumber = tanpa_komentar(handle.read())
    TERBACA += 1
    jumlah = sumber.count(PENGGAMBAR)
    if jumlah == 0:
        MASALAH.append(
            "  %s: %s tidak memanggil %s sama sekali -- pengguna melihat nama "
            "objek tanpa bentuknya, dan tidak ada gerbang lain yang membaca ini"
            % (path, sebutan, PENGGAMBAR.rstrip("(")))
        continue
    # Setiap pemanggilan harus berada di luar kondisi yang selalu salah.
    for m in re.finditer(re.escape(PENGGAMBAR), sumber):
        baris = sumber.count("\n", 0, m.start()) + 1
        # Cari `if false`/`guard false` terdekat di atasnya yang membuka blok
        # dan belum ditutup pada baris ini. Pendekatan sederhana dan cukup:
        # hitung kedalaman kurawal sejak awal berkas.
        kedalaman = 0
        salah_pada = None
        for i, ch in enumerate(sumber[:m.start()]):
            if ch == "{":
                kedalaman += 1
            elif ch == "}":
                kedalaman -= 1
        # Kumpulkan `if false` yang bloknya masih terbuka di titik ini.
        for s in SELALU_SALAH.finditer(sumber[:m.start()]):
            buka = sumber.find("{", s.end())
            if buka < 0 or buka > m.start():
                continue
            dalam = 0
            for ch in sumber[buka:m.start()]:
                if ch == "{":
                    dalam += 1
                elif ch == "}":
                    dalam -= 1
            if dalam > 0:
                salah_pada = sumber.count("\n", 0, s.start()) + 1
                break
        if salah_pada is not None:
            MASALAH.append(
                "  %s:%d: pemanggilan %s berada di bawah kondisi yang selalu "
                "salah (baris %d) -- gambarnya tidak pernah tampil"
                % (path, baris, PENGGAMBAR.rstrip("("), salah_pada))

if TERBACA == 0:
    print("PERINGATAN: tidak ada permukaan yang terbaca -- aturan ini tidak "
          "mengukur apa pun. Hijau di sini berarti 'tidak diperiksa', bukan "
          "'benar'.")
    sys.exit(1)

if MASALAH:
    print("\n".join(MASALAH))
    sys.exit(1)

print("Bersih: %d permukaan mengenali objek dan menggambar visualnya."
      % TERBACA)
PY
)
# Kode keluar harus diambil dari **python-nya**, bukan dari perintah sebelumnya.
# Percobaan pertama menulis `status=$?` tepat setelah `echo`, jadi statusnya
# selalu 0: aturan mencetak pelanggaran lalu tetap melaporkan lulus.
visual_status=$?
echo "$visual_objek"
[ "$visual_status" -ne 0 ] && status=1


if [ "$status" -eq 0 ]; then
  echo
echo "== SEMUA GERBANG UI LULUS =="
else
  echo
  echo "== GERBANG UI GAGAL =="
fi
exit "$status"
