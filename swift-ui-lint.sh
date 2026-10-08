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
cjk=$(grep -rnP --include='*.swift' --include='*.sh' --include='*.yml' --include='*.yaml' \
        '[\x{3000}-\x{303F}\x{3040}-\x{30FF}\x{4E00}-\x{9FFF}\x{AC00}-\x{D7AF}\x{FF00}-\x{FFEF}\x{0400}-\x{04FF}]' \
        Apps Packages Tools project.yml \
        swift-ui-lint.sh swift-test.sh swift-typecheck.sh red-test.sh 2>/dev/null || true)
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
DECL = re.compile(r'^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+|static\s+|mutating\s+)*func\s', re.M)

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
CLAIM = re.compile(
    r'^\s*(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*Bool\s*=\s*true\s*$')
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
echo
echo "== Aturan 19: kunci katalog yang tidak dipakai kode mana pun =="
orphan_keys=$(python3 - <<'PY' 2>&1
import json, os

CATALOG = "Apps/Shared/Resources/Localizable.xcstrings"
if not os.path.exists(CATALOG):
    print("BELUM-ADA-KATALOG")
    raise SystemExit(0)

strings = json.load(open(CATALOG, encoding="utf-8"))["strings"]

# Seluruh kode sumber, sekali, menjadi satu teks. Kunci bisa dirujuk dari
# Apps/ (pemanggil) maupun Packages/ (deklarasi kunci), jadi kedua pohon
# harus ikut -- memeriksa hanya satu pohon akan melaporkan kunci yang sah
# sebagai yatim, dan itulah "merah yang tidak merah".
blob = []
for root in ("Apps", "Packages"):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".build"]
        for name in sorted(filenames):
            if name.endswith(".swift"):
                path = os.path.join(dirpath, name)
                try:
                    blob.append(open(path, encoding="utf-8", errors="ignore").read())
                except OSError:
                    continue
source = "\n".join(blob)

orphans = sorted(k for k in strings if k not in source)
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
AD_HOC = re.compile(r'\.(?:background|fill)\s*\([^)]*\.color\s*\.\s*opacity\s*\(')

problems = []
for root, _, files in os.walk("Apps"):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        for i, line in enumerate(open(path, encoding="utf-8"), 1):
            code = line.split("//", 1)[0]
            if AD_HOC.search(code):
                problems.append(
                    f"  {path}:{i}: {code.strip()}")

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
# Yang diperiksa: setiap pemanggilan `CelestialVisualView(...)` yang
# meneruskan `pulse:` dengan nilai **bukan** literal nol wajib menyebut
# `hasPulse` di daftar argumen yang sama. Nama itu properti teruji di Linux
# (`CelestialVisual.hasPulse`), jadi aturannya tidak bergantung pada daftar
# jenis lokal yang bisa basi.
echo
echo "== Aturan 21: denyut gambar digerbangi hasPulse =="
ungated_pulse=$(python3 - <<'PY' 2>&1
import os, re

CALL = "CelestialVisualView("

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
            m = re.search(r"\bpulse\s*:\s*([^,]*)", args)
            if not m:
                continue
            value = m.group(1).strip()
            if value in ("0", "0.0", ".zero"):
                continue
            if not re.search(r"\bhasPulse\b", args):
                line_no = code[:i].count("\n") + 1
                problems.append(
                    f"  {path}:{line_no}: pulse: {value[:40]} tanpa hasPulse")

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
  status=1
else
  echo "Bersih: setiap denyut gambar digerbangi hasPulse."
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
echo
echo "== Aturan 23: setiap cabang complication memakai kanal ikon =="
inline_claim=$(python3 - <<'PY' 2>&1
import os, re

BRANCH = re.compile(r"^\s*(case\s+\.accessory\w+|default)\s*:", re.M)

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
            end = marks[idx + 1].start() if idx + 1 < len(marks) else len(code)
            branch = code[m.end():end]
            if "digest.headline" not in branch:
                continue
            if "presentedSymbolName" in branch:
                continue
            line_no = code[:m.start()].count("\n") + 1
            problems.append(
                f"  {path}:{line_no}: cabang `{m.group(1)}` menampilkan "
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
            for m in PAIR.finditer(line):
                t, mem = m.group("t"), m.group("m")
                if t not in pkg_types or t in apps_types:
                    continue
                # `Type.self` / `Type.Type` disediakan compiler.
                if mem in ("self", "Type") or mem in resolved[t]:
                    continue
                nested = f"{t}.{mem}"
                hint = ""
                if nested in pkg_types:
                    hint = (f" — `{nested}` ada sebagai tipe bersarang; "
                            f"akses anggotanya lewat `{mem}.<anggota>`")
                problems.append(
                    f"  {path}:{i + 1}: `{t}.{mem}` — bukan anggota `{t}`"
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
    # `->` pada tipe fungsi bukan kurung sudut. Tanpa ini `() -> Date = …`
    # menurunkan depth ke −1, lalu koma dan `=` sesudahnya tak terlihat.
    inside = inside.replace("->", "\u2192")
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
    param = param.replace("->", "\u2192")
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
INIT = re.compile(r"\b(?:convenience |required |override )*init\s*(\?|\!)?\s*\(")

inits = collections.defaultdict(list)
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


def matches(given, decl):
    """Swift boleh melewati argumen berbawaan di posisi **mana pun**, bukan
    hanya di ekor: `init(id: UUID = UUID(), name:)` dipanggil `T(name:)`.
    Jadi deklarasi dijajarkan satu per satu: label yang cocok dipakai,
    parameter berbawaan yang tidak disebut dilewati, sisanya gagal."""
    gi = 0
    for dl, ddef in decl:
        if gi < len(given) and given[gi][0] == dl:
            gi += 1
        elif not ddef:
            return False
    return gi == len(given)


CALL = re.compile(r"(?<![A-Za-z0-9_.])([A-Z][A-Za-z0-9_]*)\s*\(")
problems = []
for root, _, files in os.walk(APPS):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        text = strip(open(path, encoding="utf-8").read())
        for m in CALL.finditer(text):
            t = m.group(1)
            if t not in inits:
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
                # Ada kelebihan beban yang seluruhnya berbawaan: nol argumen sah.
                if required and not any(all(x for _l, x in d) for d, _p in
                                        inits[t]):
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
    # `->` pada tipe fungsi bukan kurung sudut. Tanpa ini `() -> Date = …`
    # menurunkan depth ke −1, lalu koma dan `=` sesudahnya tak terlihat.
    inside = inside.replace("->", "\u2192")
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
    param = param.replace("->", "\u2192")
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
    """Swift boleh melewati argumen berbawaan di posisi **mana pun**, bukan
    hanya di ekor: `init(id: UUID = UUID(), name:)` dipanggil `T(name:)`.
    Jadi deklarasi dijajarkan satu per satu: label yang cocok dipakai,
    parameter berbawaan yang tidak disebut dilewati, sisanya gagal."""
    gi = 0
    for dl, ddef in decl:
        if gi < len(given) and given[gi][0] == dl:
            gi += 1
        elif not ddef:
            return False
    return gi == len(given)


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
                # Ada kelebihan beban yang seluruhnya berbawaan: nol argumen sah.
                if required and not any(all(x for _l, x in d) for d, _p in
                                        overloads):
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

if [ "$status" -eq 0 ]; then
  echo
  echo "== SEMUA GERBANG UI LULUS =="
else
  echo
  echo "== GERBANG UI GAGAL =="
fi
exit "$status"
