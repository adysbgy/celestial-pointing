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
MATI = ("0", "0.0", ".zero")


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
    """Deklarasi pada kedalaman satu saja — anggota **langsung** tipe ini."""
    found, depth = set(), 0
    for k, ch in enumerate(body):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        elif depth == 1:
            m = re.match(
                r"(?:public |internal |private |fileprivate )?"
                r"(?:static |indirect )?"
                r"(?:func|var|let|struct|enum|class|typealias|case)\s+"
                r"([A-Za-z_][A-Za-z0-9_]*)", body[k:])
            if m:
                found.add(m.group(1))
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
            bools = re.findall(
                r"\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*Bool\??\b", params)
            if bools:
                aksesor.setdefault(m.group(1), set()).update(bools)

if not aksesor:
    print("Tidak ada aksesor model ber-parameter Bool yang ditemukan; "
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
        if not dibaca:
            continue

        for fn, params in sorted(aksesor.items()):
            for m in re.finditer(
                    r"(?<![A-Za-z0-9_])" + re.escape(fn) + r"\s*\(", kode):
                args = argumen(kode, m.end() - 1)
                for prm in sorted(params):
                    if prm not in dibaca:
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
                               nilai.group(1).strip(), prm))

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

if [ "$status" -eq 0 ]; then
  echo
  echo "== SEMUA GERBANG UI LULUS =="
else
  echo
  echo "== GERBANG UI GAGAL =="
fi
exit "$status"
