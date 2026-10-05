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

if problems:
    for p in problems:
        print(p)
    print("-> Perbarui angka di README.md, atau perbaiki kalau uji terhapus.")
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

if [ "$status" -eq 0 ]; then
  echo
  echo "== SEMUA GERBANG UI LULUS =="
else
  echo
  echo "== GERBANG UI GAGAL =="
fi
exit "$status"
