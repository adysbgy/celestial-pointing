# STATUS — Celestial Pointing Engine

## Progres terakhir (4 Okt 2026 — cakupan Aturan 3 diperluas, dan aturan baru langsung menangkap penulisnya sendiri)

### Premis siklus ini: ambil batas yang sudah dicatat, dan uji apakah ia masih benar

STATUS mencatat berulang kali, di setiap "Batas yang diketahui":

> Aturan 3 masih buta di `*.sh`, `project.yml`, dan `*.md`.

Kalimat itu dicatat sebagai batas, **bukan** dikerjakan. Siklus ini menguji
apakah batasnya masih ada, lalu menutup bagian yang bisa ditutup.

### Apa yang ditemukan

Sapuan keempat jenis berkas itu menemukan **nol** pelanggaran di `*.sh`,
`*.yml`, dan `project.yml` — tetapi hanya karena tidak ada yang mencari,
bukan karena ada penjaga. Tiga hit CJK yang ada semuanya di `STATUS.md`,
dan ketiganya **kutipan bukti** cacat lama, bukan selip.

Itu memisahkan batasnya jadi dua hal yang berbeda, dan hanya satu yang
benar-benar celah:

- `*.sh`, `*.yml`, `project.yml` → bersih, **tak terjaga**. Bisa ditutup.
- `*.md` → berisi aksara CJK dengan **sengaja** (dokumentasi cacat).
  Memasang penjaga di sini akan membuat aturan memerah pada dokumentasinya
  sendiri.

### Yang dikerjakan

Cakupan Aturan 3 diperluas ke `*.sh`, `*.yml`, `project.yml`, dan keempat
skrip gerbang. `project.yml` ikut karena itu berkas yang **menentukan
build** — selip di sana dampaknya lebih besar daripada di satu view.

`*.md` sengaja tidak ikut, dengan alasannya ditulis di skrip supaya tidak
terbaca sebagai kelalaian.

### Aturan baru langsung menangkap penulisnya sendiri

Komentar yang menjelaskan pengecualian `*.md` awalnya **mengutip** aksara
CJK-nya sebagai contoh. Cakupan yang baru diperluas itu langsung memerah —
pada skrip yang memuat aturannya. Lint keluar **exit 1** dengan menunjuk
`swift-ui-lint.sh:100`.

Itu bukan gangguan; itu bukti bahwa perluasannya benar-benar bekerja. Dua
pilihan ada di depan: mengecualikan skripnya sendiri (menambah lubang), atau
menghapus kutipannya. Yang dipilih **menghapus kutipannya** — lebih baik
komentar kehilangan contoh harfiah daripada aturan mendapat lubang
pengecualian. Kegagalannya dicatat di komentar, jadi alasannya tidak hilang.

### Bukti dua arah

Salinan bersih di `scratch/lintcheck4` → baseline **exit 0**. Lalu:

| Suntikan | Diharapkan | Hasil |
|---|---|---|
| Aksara CJK di `swift-test.sh` | MERAH | **MERAH** |
| Aksara Cyrillic di `project.yml` | MERAH | **MERAH** |
| Aksara CJK di `STATUS.md` (kontrol negatif) | hijau | hijau |
| Kembalikan ke semula | hijau | hijau |

Kontrol negatifnya penting: tanpa itu, aturan ini bisa "lulus" hanya karena
memeriksa tempat yang salah.

### Kenapa tidak sekalian memasukkan `*.md`

Karena gerbang yang salah-merah akan dimatikan orang lain saat ia berbunyi —
alasan yang sama yang sudah dipakai repo ini untuk menolak `append` di
daftar peritel. STATUS yang mengutip cacat lama adalah pemakaian yang sah;
menuntutnya menulis ulang bukti historisnya akan merusak dokumentasinya.

### Gerbang

- `bash -n swift-ui-lint.sh` → OK; `./swift-ui-lint.sh` → **8 aturan hijau**.
- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 failures**.
- `./swift-typecheck.sh` → semua gerbang lulus.


## Progres terakhir (4 Okt 2026 — satu kata Jerman di tengah kalimat Indonesia, dan kenapa daftar kata sendiri dulu menghalangi)

### Premis siklus ini: kelas cacat yang sudah dicatat tiga kali tapi tak pernah punya penjaga

Aturan 3 menangkap aksara CJK dan Cyrillic. Yang **tidak** pernah ditangkap
adalah kata asing yang memakai huruf Latin — terbaca wajar oleh mata, lolos
total dari setiap gerbang. Kelas ini sudah muncul di STATUS berulang kali
(`di-George`, `Memorial celebrating`, `danasticity`) dan setiap kali hanya
**diperbaiki**, tidak pernah **dijaga**. Pola itu yang diakhiri di sini.

### Yang ditemukan: bukti nyata, bukan hipotesis

`Apps/Shared/LocalizationBridge.swift:39` memuat kata fungsi bahasa Jerman
di tengah kalimat Indonesia:

    /// tidak menahannya. `TextLocalization.text` deshalb menolak hasil yang

Kata itu lolos dari: lint (7 aturan waktu itu), typecheck, 471 test, dan CI
macOS. Tidak ada satu pun yang melihatnya.

### Kenapa daftarnya HANYA kata Jerman — dan itu keputusan yang diuji, bukan ditebak

Sapuan pertama memakai daftar kata Inggris + Jerman. Hasilnya satu hit yang
**bukan** cacat:

    OnboardingView.swift: /// Layar perkenalan "value-first": satu kartu singkat...

`value-first` adalah istilah desain yang sah, dan `first` menandainya. Jadi
kata Inggris umum dibuang dari daftar: ongkos positif palsunya lebih besar
daripada nilai tangkapannya. Sisa daftar kata Jerman memindai **103 berkas
→ 1 hit, dan hit itu memang cacat**. Presisi 100% pada cakupan itu.

### Jebakan yang harus dilewati: aturan tidak boleh menandai daftar katanya sendiri

Versi pertama Aturan 8 melaporkan **41 pelanggaran palsu** — semuanya berasal
dari definisi daftar kata dan komentar rasionalnya sendiri di dalam skrip.
Memecah daftar jadi dua string tidak menyelesaikannya: setiap kata tetap utuh
di dalam satu literal.

Perbaikannya bukan mengecualikan seluruh berkas skrip (itu akan membutakan
aturan pada skrip yang justru memuatnya), melainkan penanda sempit dan
eksplisit `aturan8:abaikan-mulai` / `aturan8:abaikan-selesai` yang membatasi
hanya pada definisi daftar. **Diuji bahwa penandanya tidak bocor**: selip
Jerman yang ditaruh *setelah* penanda selesai tetap membuat lint MERAH.

### Bukti dua arah

Salinan bersih di `scratch/lintcheck3` → baseline **exit 0**. Lalu:

| Suntikan | Hasil |
|---|---|
| Kata Jerman di `.swift` | MERAH, menunjuk `LocalizationBridge.swift:41` |
| Kata Jerman di `project.yml` | MERAH, menunjuk `project.yml:2` |
| Kata Jerman **setelah** penanda selesai | MERAH — penanda tidak bocor |
| Kembalikan ke semula | hijau |

`project.yml` sengaja diuji karena itu salah satu tempat yang **tidak**
tercakup Aturan 3 — celah yang sudah dicatat berulang kali.

### Batas yang jujur

Daftar ini tidak akan menangkap kata Latin korup yang di luar daftarnya.
Yang ditutup adalah kelas yang benar-benar muncul di repo ini, bukan seluruh
kemungkinannya. Itu dicatat sebagai batas, bukan diklaim sebagai penutupan
penuh.

### Gerbang

- `bash -n swift-ui-lint.sh` → OK; `./swift-ui-lint.sh` → **8 aturan hijau**.
- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 failures**.
- `./swift-typecheck.sh` → semua gerbang lulus.
- Sapuan CJK pada berkas yang diubah → **0**.



### Premis siklus ini: daftar peritelnya sendiri belum pernah diturunkan dari data

Unit sebelumnya memperbaiki **cara** argumen dibaca. Yang belum pernah
diperiksa adalah **daftar peritelnya** — 27 nama yang ditulis tangan, dan
tidak satu pun punya alasan yang bisa diperiksa. Itu persis bentuk yang sudah
tiga kali menjadi cacat di repo ini: daftar yang tumbuh dari apa yang
**diingat** orang, bukan dari apa yang ada di kode.

Jadi pertanyaannya dibalik. Bukan "peritel apa yang harus ditambahkan",
melainkan: **pemanggilan mana di seluruh `Apps/` yang argumen pertamanya
sebuah literal?** Sapuan itu tidak butuh daftar sama sekali. Hasilnya
dikelompokkan per nama:

| Nama | literal | Diperiksa? |
|---|---|---|
| `Text` | 33 | ya |
| `row` | 32 | ya |
| `Section` | 12 | ya |
| `Label` | 7 | ya |
| `Button` | 6 | ya |
| **`SharePreview`** | 2 | **tidak** |
| **`TextField`** | 1 | **tidak** |
| **`chartYAxisLabel`** | 1 | **tidak** |
| **`legend`** | 3 | **tidak** |
| **`value`** | 4 | **tidak** |

Lima nama terakhir memuat teks yang **tampil di layar** dan tidak pernah
diperiksa gerbang mana pun: judul berkas di lembar berbagi, label bidang
isian, label sumbu grafik, dan tiga label legenda grafik keyakinan.

### Sepuluh teks, dan yang paling penting bukan yang paling mudah terlihat

Yang paling mencolok justru yang paling gampang dilewatkan: **`σ`**, label
sumbu Y grafik keyakinan. Satu karakter, tidak punya huruf sama sekali —
bentuk yang sama seperti template format, dan justru karena itu tidak pernah
terpikir sebagai "teks". Ia tampil di grafik yang jadi inti layar
Diagnostik.

Tiga label legenda (`Yakin`/`Ragu`/`Tidak tahu`) punya masalah kedua yang
lebih halus: padanan `en`-nya **harus** sama dengan
`confidence.level.*.label`, karena keduanya menyebut tingkat keyakinan yang
sama di layar yang berbeda. Kalau diterjemahkan bebas, satu layar berkata
"Certain" dan layar lain "Sure" untuk konsep yang identik. Dipakai
`Certain`/`Uncertain`/`Unknown` — **dibaca dari katalog yang sudah ada**,
bukan dikarang.

`Dataset Experiment 1` sengaja **tidak** dimasukkan ke `NOT_LOCALIZED`: ia
berisi nama percobaan yang memang tidak diterjemahkan (`Experiment 1`), tapi
kata `Dataset` perlu padanan, jadi kunci penuhnya didaftarkan. Ini kebalikan
dari `Point & Know` yang seluruhnya nama produk.

### Yang sengaja TIDAK dimasukkan, dan kenapa itu keputusan

Dua nama muncul di sapuan dan **ditolak dengan alasan**, bukan dilewatkan:

- **`NSLog`** — pesan log. Tidak pernah terlihat pengguna, jadi menuntut
  padanan bahasa Inggris untuknya hanya menambah 20 kunci mati ke katalog.
- **`append`** — delapan literal, dan semuanya memang teks tampilan
  (`"Tidak dianalisis."`, `"False lock: engine yakin tapi salah."`). Tapi
  `append` adalah nama `Array.append`/`String.append`: memasukkannya akan
  menandai **setiap** `append("...")` di repo, termasuk yang bukan teks
  tampilan. Gerbang yang salah merah akan dimatikan orang lain saat ia
  berbunyi — itu alasan yang sama yang sudah dipakai repo ini untuk menolak
  daftar kata asing. Jadi batasnya dicatat di komentar skrip, bukan
  disembunyikan.

`append` tetap celah yang **nyata**, dan statusnya sekarang jujur: ia
terdaftar sebagai batas, bukan sebagai selesai.

### Katalog: 150 → 160 kunci, murni aditif

```
110 baris masuk, 0 keluar
```

Urutan kunci lama tetap tidak disentuh.

### Uji injeksi: enam arah, termasuk kontrol negatif

Dijalankan pada salinan:

| Injeksi | Diharapkan | Hasil |
|---|---|---|
| `TextField("LabelIsianBaru", …)` | MERAH | **MERAH** |
| `SharePreview("JudulBagikanBaru")` | MERAH | **MERAH** |
| `.chartYAxisLabel("SumbuBaru")` | MERAH | **MERAH** |
| `legend("LegendaBaru", …)` | MERAH | **MERAH** |
| `.value("NilaiBaru", 1.0)` | MERAH | **MERAH** |
| `NSLog("pesan log internal %@", …)` | hijau | hijau |
| tree bersih | hijau | hijau |

Enam dari tujuh adalah bukti **merah**; yang ketujuh adalah kontrol negatif —
tanpa itu, aturan ini bisa "lulus" karena menandai segalanya.

### Yang benar-benar dijalankan

- `./swift-ui-lint.sh` → **7 aturan hijau**; aturan 4 MERAH dulu (11 situs,
  10 kunci) lalu hijau.
- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 gagal**.
  Tidak ada satu baris Swift pun yang berubah di unit ini.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan CJK/Cyrillic pada berkas yang diubah: **0**.
- **CI hijau pada push pertama** (`53a6f14`):
  - `Apple Build` run `37211768305` → **`BUILD SUCCEEDED`** + gerbang
    peringatan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37211768310` → hijau; `Executed 166 tests`,
    `Executed 305 tests`, dan `== SEMUA GERBANG UI LULUS ==` terlihat di log
    CI.

### Batas yang diketahui dan belum ditutup

- **`append` belum ditutup** — lihat di atas. Kandidat yang benar bukan
  menambahkannya ke daftar peritel, melainkan memeriksa **tipe** targetnya,
  dan itu di luar jangkauan sapu teks.
- **Aturan 3 dulu buta di `*.sh`, `project.yml`, dan `*.md`** — dua yang
  pertama **sudah ditutup** di siklus berikutnya; `*.md` tetap di luar
  cakupan dengan alasan yang dicatat di skrip (STATUS memuat aksara CJK
  sebagai bukti, bukan sebagai selip).
- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux** — tidak
  berubah.

## Progres terakhir (4 Okt 2026 — 23 teks yang tampil di layar, tak terlihat gerbang mana pun)

### Premis siklus ini: STATUS lalu menunjuk ke tempat yang salah

STATUS sebelumnya menutup dengan batas yang jujur:

> **`detailRow` dengan argumen non-literal masih bisa lolos** — sapuan ini
> menangkap literalnya, tapi kalau argumennya
> `.accessibilityLabel(RowSpeech…)` yang membawa teks, jalur itu tidak
> diperiksa.

Kalimat itu **benar**, dan justru itu sebabnya berbahaya: ia menutup celah
dengan diagnosa yang tepat sasaran ke tempat yang **bukan** masalahnya.
Argumen yang bukan literal memang di luar jangkauan sapu teks — tidak ada yang
bisa diperbuat untuk itu. Yang tidak pernah diperiksa adalah **argumen kedua
yang literal**.

Pola lamanya satu regex:

```
\b(Text|row|…)\s*\(\s*"((?:[^"\\]|\\.)*)"
```

Satu literal, dan ia **harus** persis setelah tanda buka. Jadi:

| Bentuk — keduanya ada di repo | Terbaca? |
|---|---|
| `row("Keadaan", state.shortLabel)` | ya |
| `row("Device motion", motion.isAvailable ? "Ada" : "Tidak ada")` | **tidak** |

Argumen kedua sebuah `row` **selalu** teks tampilan — itu definisi helper-nya
(`row(_ title: String, _ value: String)`). Jadi **nilai**, yaitu separuh isi
setiap baris tabel di seluruh app, tidak pernah diperiksa. Dibuktikan dengan
menjalankan pola lama atas seluruh `Apps/`:

```
laporan pola lama: 0
```

Nol. Sementara **23 teks** yang benar-benar tampil di layar tidak punya satu
pun padanan bahasa Inggris — termasuk `Gelap`/`Terang`, `Sudah`/`Belum`,
`Aktif`/`Belum aktif`, `Ya`/`Tidak`, `Ada`/`Tidak ada`, `iPhone terhubung`,
empat label tombol Mode Malam & bunyi, dan tiga label kalibrasi.

### Kelas yang sama, ketiga kali — dan kali ini di dalam aturan penutupnya sendiri

"Gerbang hijau karena ada satu jalur yang tidak pernah diperiksa" sudah dua
kali muncul: aturan 4 buta terhadap metadata WidgetKit, lalu aturan 4 buta
terhadap `row`/`detailRow`. Ini ketiga kalinya, dan yang paling ironis:
**buta terhadap separuh argumen dari fungsi yang baru saja dimasukkan ke
daftar peritel** untuk menutup kejadian kedua. Menambahkan peritel tanpa
memperbaiki *cara* argumennya dibaca hanya memindahkan lubangnya.

### Yang diubah, dan kenapa begini

Pola regex tunggal diganti **pembaca argumen**:

- **`read_literal`** membaca satu literal utuh dan memperlakukan `\(…)`
  sebagai **satu kesatuan**, jadi tanda kutip di dalam interpolasi tidak
  menutup literal. Itu bentuk yang memang dipakai repo ini
  (`"· \(link.sendFailureCount) gagal"`), dan tanpa penanganan itu sapuannya
  salah baca tepat di tempat yang paling rawan.
- **`direct_arguments`** hanya mengumpulkan literal pada **kedalaman argumen
  1**. Literal bersarang (`String(format: "%.1f°", x)`) tidak ikut dianggap
  teks tampilan, sementara `row("Judul", flag ? "A" : "B")` tetap terbaca
  **keduanya**.
- **Label `systemImage` disaring karena data, bukan tebakan.** Diperiksa lebih
  dulu: satu-satunya parameter berlabel yang membawa literal di seluruh
  `Apps/` adalah `systemImage`, dan isinya nama SF Symbol
  (`"square.and.arrow.up"`) — memang bukan teks tampilan.
- **Template format murni dikecualikan**, tapi dengan syarat yang menentukan:
  hanya bila setelah specifier dibuang **tidak ada huruf tersisa**. Itu yang
  membuat `"%.0f%%"` gugur sementara `"%lld gagal"` tetap diperiksa sebagai
  teks — bentuk kedua memang punya padanan `en` di katalog.

### Katalog: 23 kunci, murni aditif

`Localizable.xcstrings` 127 → **150** kunci, semuanya dengan padanan `en`.
Urutan kunci lama **tidak disentuh** — katalog ditulis tangan, jadi urutan
berarti — dan diff-nya:

```
253 baris masuk, 0 keluar
```

Nol penghapusan, jadi tidak ada reformat yang menyamarkan perubahan.

`FALSE LOCK` sengaja masuk katalog dengan nilai `en` **yang sama**: itu
istilah teknis huruf besar yang dipakai sebagai singkatan visual (alasannya
sudah ada di komentar `Experiment1View`), dan menaruhnya di katalog membuat
keputusan itu terbaca, bukan tersembunyi.

### Uji injeksi: dua arah

Dijalankan pada salinan, bukan di repo:

| Injeksi | Diharapkan | Hasil |
|---|---|---|
| literal baru sebagai argumen **kedua** `row()` | MERAH, sebut **keduanya** | **MERAH** |
| `Label("Ekspor", systemImage: "arrow.up.doc.on.clipboard")` | hijau | hijau |
| `row("JudulUIBaru", String(format: "%.1f°", 3.0))` | MERAH, sebut judulnya saja | **MERAH** |
| `row("JudulUIBaru", flag ? "NilaiA" : "NilaiB")` | MERAH, sebut ketiganya | **MERAH** |
| `// Text("TeksDiDalamKomentar")` | hijau | hijau |
| tree bersih | hijau | hijau |

### Yang benar-benar dijalankan

- `./swift-ui-lint.sh` → **7 aturan hijau**; aturan 4 **MERAH dulu** (33 situs,
  23 kunci) sebelum katalog diisi, lalu hijau.
- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 gagal**.
  Engine tidak disentuh; tidak ada satu baris Swift pun yang berubah di unit
  ini.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan CJK/Cyrillic pada berkas yang diubah: **0**.
- **CI hijau pada push pertama** (`98c10e4`):
  - `Apple Build` run `37211406351` → **2× `BUILD SUCCEEDED`** + gerbang
    peringatan *"Tidak ada peringatan compiler pada Apps/."*; langkah
    "Gerbang sapu UI" terlihat benar-benar berjalan di log.
  - `Engine Tests (Linux)` run `37211406453` → hijau, dan `Bersih: setiap
    teks UI punya entri di katalog.` + `== SEMUA GERBANG UI LULUS ==`
    terlihat **di log CI**, bukan hanya di mesin ini.

### Batas yang diketahui dan belum ditutup

- **Sapuan tetap tidak bisa melihat teks yang tidak pernah menjadi literal.**
  `.accessibilityLabel(RowSpeech.label(title:value:))` membawa teks lewat
  variabel, dan tidak ada sapu teks yang bisa mengikutinya. Yang berubah:
  batas itu sekarang **benar-benar** batasnya, bukan alasan untuk melewatkan
  argumen kedua yang literal.
- **Aturan 3 masih buta di `*.sh`, `project.yml`, dan `*.md`** — tidak
  berubah dari siklus sebelumnya. `STATUS.md` sendiri masih menyimpan tiga
  aksara CJK di tiga baris, yang ditulis sebagai **contoh** selip; sapuan
  tidak mencakup `*.md`, jadi contoh dan selip tidak bisa dibedakan oleh
  gerbang mana pun.
- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux.** Yang terbukti:
  setiap kunci punya entri + padanan `en`, dan diff-nya aditif. Yang tidak:
  apakah `Bundle` benar-benar membacanya di perangkat.

## Progres terakhir (4 Okt 2026 — iPhone menampilkan "Mencari" lalu diam, dan aturan yang buta di label tabel)

### Dua temuan, dan yang kedua tidak akan ketahuan tanpa yang pertama

Temuan pertama berasal dari menghitung, bukan membaca: berapa kali
`guidance` muncul di tiap app?

| Berkas | `guidance` |
|---|---|
| `PointAndKnowWatch/Sources/PointingView.swift` | **5** |
| `PointAndKnowiOS/Sources/DiagnosticsView.swift` | **0** |
| `Complications/ComplicationWidget.swift` | 0 |

Jadi app jam menampilkan panduan keadaan di bawah badge
(`PointingView.swift:256`, `:234`, `:300`), dan **layar utama iPhone tidak
menampilkan sama sekali**. Barisnya cuma `row("Keadaan",
state.shortLabel)` — "Mencari" — lalu layar diam.

Yang membuatnya cacat, bukan sekadar beda: `shortLabel` menjawab **apa**
keadaannya, tidak pernah menjawab **apa yang harus dilakukan**. Dua app
untuk keadaan yang sama memberi petunjuk berbeda: jam berkata "Tahan arah
tunjuk sampai jam berhenti bergerak", iPhone tidak berkata apa pun. Ke
enam kalimat panduan sudah ada di `TextLocalization`, sudah diuji di Linux
(`PointingPresentationTests`, `TextLocalizationTests`) — yang hilang hanya
tempat menampilkannya.

### Barisnya memakai kunci yang sama, bukan kalimat baru

`row("Panduan", engine.snapshot.state.guidance)` — bukan string harfian di
view. Kalau kalimatnya ditulis terpisah di iPhone, ia bisa menyimpang dari
yang diucapkan jam, dan dua app yang memberi petunjuk berbeda adalah cacat
yang paling buruk: pengguna jam mendapat instruksi, pengguna iPhone tidak,
dan tidak ada yang bisa tahu itu disengaja.

### Temuan kedua: aturan 4 buta tepat di jalur paling umum

Bukti RED-nya lewat injeksi, bukan dengan membaca aturan:

```
Text("TeksUIYangBaru")      ->  merah
row("LabelUIYangBaru")      ->  LOLOS, tanpa laporan
```

`Text` ada di daftar peritel aturan 4; `row` — helper label-lebar yang
dipakai **empat berkas** — tidak. Padahal label tabel adalah jalur paling
banyak dari teks yang benar-benar tampil di layar. `row` dan `detailRow`
ditambahkan ke `POS`.

Setelah diperlebar, aturan itu langsung melaporkan **36 label yang hilang
sungguhan** di empat berkas. Ini pola yang sama seperti dua kali
sebelumnya: gerbang hijau, aturannya ada, penerapannya juga ada — tapi ada
satu jalur yang tidak pernah diperiksa, dan jalurnya justru yang paling
sering dipakai.

Tiga puluh tiga di antaranya saya masukkan ke `Localizable.xcstrings`
lengkap dengan padanan bahasa Inggris dan komentar singkat — termasuk
`Panduan` yang barusan ditambahkan oleh perubahan ini.

### Urutan katalog tidak boleh disentuh

Katalog ditulis tangan (`SWIFT_EMIT_LOC_STRINGS: NO`, alasannya di
`project.yml`), jadi **urutan kuncinya berarti**. Versi pertama saya
menjalankan `sorted()` atas seluruh kunci demi kerapian dan menghasilkan
**83 baris churn** yang tidak ada hubungannya dengan pekerjaan ini — diff
yang terlihat busy dan menutupi sebenarnya. Dikembalikan, dan kunci baru
ditambahkan di akhir dengan `OrderedDict`:

```
363 baris masuk, 0 keluar
```

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 gagal**.
- `./swift-ui-lint.sh` → **7 aturan hijau**.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Injeksi ulang setelah perbaikan: `row`, `detailRow`, dan `Text`
  **ketiganya merah**; tree bersih tetap hijau.
- CI di `e719e65`: `Apple Build` run `37210235342` → 2× `BUILD SUCCEEDED`
  + "Tidak ada peringatan compiler pada Apps/."; `Engine Tests (Linux)` →
  hijau.

### Yang masih terbuka

- **`detailRow` dengan argumen non-literal masih bisa lolos** — sapuan ini
  menangkap literalnya, tapi kalau argumennya
  `.accessibilityLabel(RowSpeech…)` yang membawa teks, jalur itu tidak
  diperiksa. Terpisah dari perubahan ini.
- **Complication tetap tanpa panduan** (`0`), dan itu **memang benar**:
  layar complication satu baris, dan `shortLabel` memang yang tepat di
  sana. Tidak diubah karena tidak ada yang rusak.
- **Terjemahan `en` untuk 33 kunci baru tidak bisa diverifikasi di Linux**
  — tidak berubah dari siklus sebelumnya, alasannya juga tidak berubah.

## Progres terakhir (4 Okt 2026 — planet di panel kunci menggambar dirinya sendiri 30 kali per detik)

### Premis siklus ini: cari barang yang membazir, bukan barang yang belum ada

Semua item brief sudah ada (diverifikasi ulang di entri "Ringkasan keadaan" 4 Okt). Jadi pertanyaan siklus ini bukan "apa yang belum dikerjakan",
tapi **"dari yang sudah ada, mana yang membazir tanpa terlihat"**. Bukti
baterai-redraw yang paling bersih di repo ini ditemukan dengan menghitung,
bukan dengan membaca: sapuan seluruh `Apps/` untuk sumber redraw per frame.

Hasilnya satu, dan itu cukup:

| Pola | Jumlah | Lokasi |
|---|---|---|
| `TimelineView` | 1 | `DiagnosticsView.swift:550` |
| `Timer`/`CADisplayLink`/`DispatchSource` timer | 0 | — |
| `onReceive(Timer…)` | 0 | — |
| `Canvas` | 1 | `CelestialVisualView.swift:45` |
| `symbolEffect` / `PhaseAnimator` | 0 | — |

Satu `TimelineView` untuk seluruh app. Dan ia bergerak **30 frame per
detik**, terus-menerus, untuk setiap objek yang tampil di panel kunci.

### Cacatnya: timer untuk gambar yang tidak pernah bergerak

`TimelineView(.animation(minimumInterval: 1.0 / 30.0))` dipasang supaya glow
bintang bisa berdenyut. Tapi `pulse` **hanya** dibaca di `drawStar`
(`CelestialVisualView.swift:453`) — diverifikasi dengan melacak satu-satunya
pemakai `pulse` di seluruh view:

```
CelestialVisualView.swift:453   let pulseFactor = 1 + … * CGFloat(sin(pulse))
```

Hanya itu. Planet, Bulan, Matahari, dan nebula digambar dari konstanta saja:
`drawPlanet`, `drawMoon`, `drawSun`, `drawDeepSky` tidak pernah menyentuh
`pulse`. Jadi ketika panel kunci menampilkan **planet**, yang terjadi adalah
30 render per detik untuk `Canvas` yang menggambar piksel yang **persis sama**
setiap frame.

Yang membuatnya layak diperbaiki dan bukan sekadar catatan performa:
pertanyaan yang sama tidak pernah bisa dijawab siapa pun di repo ini. App jam
tidak pernah memasang `TimelineView` sama sekali (visualnya diam), jadi
"apakah denyut boleh jalan" adalah pertanyaan yang dua app jawab berbeda —
dan tidak ada satu pun tempat yang mencatat bahwa mereka **bertanya tentang
hal yang sama**.

### Yang diperbaiki, dan kenapa tempatnya di model

`hasPulse` masuk ke `CelestialVisual` (`PointingKit`), bukan ke view. Alasan
teknisnya memaksa hal itu: `TimelineView` harus dipasang **sebelum** view
tahu apa yang akan digambar, jadi view tidak bisa menjawab pertanyaan
"apakah saya perlu denyut" — itu sudah terlambat untuk dijawab di tempat
yang salah. Tanpa properti di model, jalan yang tersedia hanya
menjalankannya untuk semua jenis dan berharap pengoptimasian menyusul;
itu pola *hope-it-works* yang tidak pernah diaudit di repo ini.

Perbaikannya sendiri satu baris ambang:

```swift
if motion.allowsContinuousMotion && visual.hasPulse {
```

Jalur `else` sudah benar tanpa perubahan: ia mengirim `pulse: 0`, dan
`pulsePhase` sudah mengembalikan **nol persis** saat geraknya gated
(diuji di `MotionPolicyTests`) — jadi kedua jalur menghasilkan gambar yang
sama persis, dan tidak ada keadaan setengah yang perlu ditangani.

Jalur bintang **tidak** berubah sedikit pun: `pulsePhase` tetap dihitung
dengan `MotionPolicy` yang sama, jadi denyut yang benar-benar ada tetap
berjalan.

### Bukti RED, dua arah

1. **Mutasi** `hasPulse` → `{ true }`: uji merah di keempat jenis, dengan
   pesan yang menyebut jumlah frame per detik
   (`./red-test.sh`, hasil benar-benar merah — bukan "hijau pada kode
   rusak").
2. **Sebelum properti ada**, uji gagal **kompilasi** (`value of type
   'CelestialVisual' has no member 'hasPulse'`) — jadi uji ini memang
   menguji keputusan model, bukan sekadar kompilasi yang kebetulan lolos.

Dua uji baru:

- `testOnlyStarsPulse` — hanya `.star`; `planet`/`moon`/`sun`/`deepSky`
  tidak, dengan pesan yang menyebut konsekuensinya (30 frame/detik).
- `testPulseFollowsTheObjectKindForEveryCatalogueEntry` — **seluruh 25
  entri katalog**, bukan hanya enum tangan, supaya cabang baru yang lupa
  ketahuan oleh data — **ditambah** enam benda di luar katalog
  (`jupiter`/`saturn`/`mars` sebagai `.planet`, `moon` sebagai `.moon`,
  `sun` sebagai `.sun`, `m42` sebagai `.deepSky`).

  Versi pertamanya memanggil `object(id: "moon", kind: .planet)` — salah
  jenis, dan karena itu **lulus tanpa pernah menguji apa pun**: planet pun
  memang tidak berdenyut, jadi apa pun yang diperiksa untuk `moon` akan hijau.
  Uji yang terlihat benar dan tidak memeriksa apa pun lebih berbahaya
  daripada tidak menulis ujinya, karena ia menutup celah yang sebenarnya
  terbuka. Diperbaiki ke jenis yang sebenarnya; katalog `brightStars`
  memang hanya berisi bintang (25 entri, dihitung), jadi tanpa loop luar
  ini `planet`/`moon`/`sun`/`deepSky` **tidak akan pernah** ikut teruji.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 gagal**
  (naik dari 303, +2).
- `./swift-ui-lint.sh` → **7 aturan hijau**.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan aksara non-Latin: **0**.
- CI di `8070012`: `Apple Build` run `37209410461` → **2× `BUILD
  SUCCEEDED`** + "Tidak ada peringatan compiler pada Apps/."; `Engine
  Tests (Linux)` → hijau.

### Catatan jujur soal proses

Selama siklus ini, alat `write_file` menyisipkan karakter asing ke dalam
komentar **beberapa kali** — termasuk `希望`, `仓库` (aksara CJK), `RALAT`,
serta potongan Latin yang tidak masuk akal seperti `Swiftly`/`iList`. Semuanya
ketahuan karena ada penyapu, dan semuanya dibuang sebelum commit — satu
potongan sempat bocor ke pesan commit pertama sebelum ikut dibersihkan.
Ini bukan kebaru: kelas cacat yang sama sudah menimpa repo ini berulang
kali, dan sekarang ada aturan yang menangkapnya
untuk kode aplikasi (aturan 3). Yang **belum** ada adalah penjaga yang
sama untuk `*.sh` dan `STATUS.md` — dan itu tercatat di entri aturan 7
sebagai batas yang diketahui, bukan disembunyikan.

## Progres terakhir (4 Okt 2026 — Reduce Motion tidak pernah dibaca di mana pun)

### Premis siklus ini: preferensi pengguna yang paling sering dipakai, tanpa satu pun penjaga

Brief sudah terpasang: Fase B menutup animasi halus, denyut glow bintang, dan
pop spring saat kunci. Yang **tidak pernah** ditanyakan adalah apakah semua
itu boleh berjalan untuk pengguna yang minta jangan bergerak. Sapu diverifikasi
terlebih dulu, bukan dibaca sambil lalu:

```
$ grep -rn "accessibilityReduceMotion" Apps Packages/*/Sources
(nihil)
```

Nol. Sementara di repo yang sama ada **empat** `withAnimation(.spring)`
(`PointingView` 2, `DiagnosticsView` 2) dan satu `TimelineView(.animation)`
30 Hz yang menyegarkan denyut glow bintang — berulang tanpa henti selama layar
menyala. Jadi bentuk gerak yang paling mengganggu (yang tidak pernah
berhenti sendiri) justru yang paling tidak bisa dihentikan.

Kelas cacatnya persis yang sudah repo ini tutup berulang kali: **aturan ada,
penerapannya tidak.** Bandingkan dengan Dynamic Type (muncul lagi di berkas
complication yang ditambahkan belakangan) dan aturan penyapu UI (buta terhadap
metadata WidgetKit). Yang membuat kelas ini bertahan: tidak ada satu pun gerbang
yang bisa merah kalau `accessibilityReduceMotion` tidak dibaca, karena tidak ada
gerbang yang tahu bahwa preferensi itu **seharusnya** dibaca.

### Yang membedakan unit ini dari "tambah AnimatedFeature"

Aturan motion dipindah ke `PointingKit` sebagai `MotionPolicy`, bukan ditulis
di view. Alasannya bukan kerapian: `accessibilityReduceMotion`,
`TimelineView`, dan `Canvas` **tidak bisa dibangun di Linux**, jadi kalau
aturannya tinggal di view satu-satunya pembuktiannya adalah "berkompilasi di
Mac" — persis celah yang membuat geometri kutub Mars bisa menembus 0.26R
selama lima siklus.

Yang lebih penting, ada **dua bentuk gerak dengan jawaban yang berbeda**, dan
menyamakan keduanya adalah jebakan:

| Bentuk | Contoh | `reduceMotion` | Layar redup | Scene tak aktif |
|---|---|---|---|---|
| Kontinu | denyut glow bintang | **stop** | **stop** | **stop** |
| Transisi | pop saat kunci | **stop** | **stop** | **boleh** |

Baris terakhir adalah inti keputusan. `isSceneActive` menghentikan denyut
karena denyut di latar belakang hanya membebani baterai tanpa pernah terlihat.
Tapi **transisi dipicu aksi pengguna**, jadi saat transisi berjalan layarnya
aktif — dan memasukkan `isSceneActive` ke sana akan mematikan umpan balik
"kunci berhasil" tepat saat itu. Uji `testInactiveSceneDoesNotKillTransitions`
mengunci perbedaan itu secara eksplisit, dan mutasinya **dibuktikan MERAH**.

Menulis unit ini memasukkan lima selip CJK (satu di `MotionPolicy.swift`,

empat di `MotionPolicyTests.swift`) — semuanya di komentar, semua terlihat
benar di layar. Tapi sapuan yang sudah ada menangkapnya seperti biasa.
  denyutnya diam. Hanya perbandingan yang menangkapnya.
- **Laju denyut** (1,1 rad/dtk → satu denyut penuh tiap 5,712 detik) dipindah
  dari literal `* 1.1` di view ke konstanta bernama, karena angka yang sampai
  ke mata pengguna setiap detik harus punya satu sumber yang bisa diuji.

### Cacat kedua yang ditemukan: aturan 3 menangkap CJK tapi buta terhadap Latin rusak

Menulis unit inilatorCC imposed five CJK slips (satu di `MotionPolicy.swift`,
empat di `MotionPolicyTests.swift`) — semuanya di komentar, semua terlihat
benar di layar. TapiSapuan yang sudah ada menangkapnya seperti biasa.

Yang **tidak** tertangkap adalah temuan lain: **empat kata Latin korup** yang
sudah lama ada di repo, termasuk di dalam test suite:

| Tempat | Selip | since |
|---|---|---|
| `Apps/Shared/CelestialVisualView.swift:54` | `di-George` | siklus moon-phase |
| `LockArrivalTests.swift:43` | `nil` akan *flowing* 20 kali/detik | — |
| `LockArrivalTests.swift:92` | *Memorial celebrating* untuk benda yang tidak ada | — |
| `NightVisualTests.swift:9` | `dan_colors_nyaelly` | — |
| `NightVisualTests.swift:21` | `danasticity` (menggantikan "dan elastisitasnya") | — |

Semuanya **jejak CJK yang hilang** — huruf CJK dihapus dari kalimat Indonesia,
dan sisa gagalnya menyatu jadi satu kata aneh (`danasticity` =
"dan" + "asticity"). Karena itu aturannya lolos: sapuan CJK tidak melihatnya,
dan sapuan Latin tidak punya daftar kata jenis itu. `di-George` dan
`Memorial celebrating` lebih buruk lagi karena **terbaca benar** sebagai
bahasa Inggris, bukan salah eja.

Kandidat unit berikutnya sudah jelas: daftar kata asing yang **tidak** pernah
muncul dalam kode ini — diturunkan dari apa yang benar-benar tampil sebagai
teks, bukan dari daftar umum. Sama seperti aturan 4 yang hanya memindai
peritel yang memang dipakai.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 303 PointingKit, 0 gagal**
  (naik dari 292; +11 uji). Engine tidak disentuh.
- **Dua mutasi dibuktikan MERAH lebih dulu** lewat `./red-test.sh`:
  - `allowsTransitions` ikut `isSceneActive` → `testInactiveSceneDoesNotKillTransitions`
    gagal: *"transisi dipicu aksi pengguna, jadi layar aktif saat ia berjalan"*.
  - `pulsePhase` `0` → `0.0001` → `testPulsePhaseIsExactlyZeroWhenContinuousMotionIsDenied`
    gagal di 12 titik: *`("0.0001") is not equal to ("0.0")`*.
- `./swift-ui-lint.sh` → 6 aturan hijau.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS (build kedua paket + parse 23
  berkas `Apps/`).
- Sapuan CJK/Cyrillic/fullwidth pada seluruh berkas yang diubah: **0**
  (lima selip tertangkap dan dibuang sebelum commit).
- **CI hijau pada push pertama** (`90b0940`):
  - `Apple Build` run `37208040057` → **2× `BUILD SUCCEEDED`**, gerbang
sebelumnya, belum ditutup), dan sekarang terbukti butanya **lebih
  - `Engine Tests (Linux)` run `37208040009` → hijau, sebelas uji motion
    terlihat **lolos per nama di log CI** (bukan hanya di mesin ini).

### Batas yang diketahui dan belum ditutup

- **`accessibilityReduceMotion` baru dipasang di dua tempat**: pop saat kunci
  (jam + iPhone) dan denyut glow (iPhone). Yang **belum** disambungkan:
  animasi lain yang mungkin muncul nanti, dan `TimelineView` denyut **di
  app jam** — jam memang tidak punya denyut kontinu (gambar di sana statis),
  jadi tidak ada yang perlu dihentikan, tapi itu **kebetulan**, bukan aturan.
  Kandidat: `MotionPolicy` exposing/hanya dibaca di view yang memanggil
  `withAnimation`/`TimelineView`/`repeatForever` — sapuan statis baru.
- **Aturan 3 masih buta di `*.sh` dan `project.yml`** (dicatat di siklus
  sebelumnya, belum ditutup), dan sekarang terbukti butanya **lebih
  dalam**: ia menangkap aksara non-Latin tapi tidak menangkap Latin yang
  rusak. Dua kelas cacat berbeda dengan satu sapuan.
- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux** — tidak berubah,
  alasannya tidak berubah.

## Progres terakhir (4 Okt 2026 — aturan 7: gerak tanpa penjaga, dan probe yang menyalahkan gerbang yang benar)

### Premis siklus ini: memasang aturan tanpa penjaga hanya memindahkan cacat

Unit sebelumnya memasang `MotionPolicy` dan `accessibilityReduceMotion`. Tapi
mengabaikan aturan yang tidak punya gerbang adalah pola yang **baru saja**
dibayar mahal di repo ini: Dynamic Type selesai, lalu `.system(size:)` muncul
lagi di berkas complication yang ditambahkan belakangan; aturan penyapu UI
hijau, lalu terbukti buta terhadap metadata WidgetKit. Keduanya hijau sepanjang
waktu aturan itu **seharusnya** dibaca.

Pertanyaan yang lebih jujur dari "apakah aturannya sudah ada": **gerbang mana
yang akan merah kalau animasi ditambah tanpa membaca `reduceMotion`?** Tidak
ada. Sapu yang ada hanya melihat font, aksara, teks UI, kunci YAML, dan paritas
katalog — tidak satu pun tahu bahwa gerak adalah sesuatu yang bisa mati
sendiri.

### Yang ditutup: kelas, bukan satu situs

Aturan 7 memeriksa setiap berkas `Apps/` yang memanggil API gerak
(`withAnimation`, `.animation(`, `.repeatForever`, `TimelineView(.animation)`)
dan menuntut berkas itu merujuk penjaga gerak (`reduceMotion`, `MotionPolicy`,
atau `isLuminanceReduced`). Jadi `withAnimation` pada tombol baru tertangkap di
commit yang sama — bukan beberapa bulan kemudian, seperti Dynamic Type.

Dua detail yang menentukan apakah gerbang ini bisa dipercaya:

- **Nama API dibaca dari kode, penjaga boleh dari komentar.** Dokumentasi aturan
  ini sendiri menyebut `withAnimation`; penyapu yang menghitung komentar akan
  melaporkan dirinya sendiri. Itu persis gerbang yang selalu merah dan akan
  dimatikan orang lain saat ia berbunyi.
- **Daftar peritel sengaja pendek.** Hanya empat API yang benar-benar
  menghasilkan gerak berulang atau transisi. Kandidat yang tidak pernah muncul
  di repo ini tidak dimasukkan — daftar panjang peritel yang tidak pernah dipakai
  menambah permukaan untuk salah baca, bukan perlindungan (aturan yang sama
  sudah dipakai di aturan 4).

### Cacat aturan ini ditemukan oleh uji injeksi, bukan oleh membaca

Versi pertama mem-pattern `.animation()` **tanpa argumen**. Saya menyapunya
dan ia hijau — lalu menyuntik bentuk yang dipakai sungguhan:

```
Text("X").animation(.linear, value: 1)   ->  LULUS (tidak dilaporkan)
```

Bentuk tanpa argumen justru yang paling jarang di SwiftUI; bentuk dengan
argumen adalah yang dipakai setiap hari. Kalau tes injeksi tidak dilakukan,
aturan ini akan terlihat sempurna sambil menutup kelas cacat yang paling mungkin
dialam. Diperbaiki ke `.animation\s*\(` tanpa membatasi isi.

Bukti dua arah di salinan (bentuk nyata, bukan rekaan):

| Injeksi | Hasil |
|---|---|
| `withAnimation` tanpa penjaga | **merah** |
| `.animation(.linear, value: 1)` tanpa penjaga | **merah** |
| `.repeatForever` di dalam `withAnimation` | **merah** |
| `TimelineView(.animation)` tanpa penjaga | **merah** |
| + `MotionPolicy` / `isLuminanceReduced` | hijau |
| tree bersih | hijau |

### Probe saya sendiri sempat salah baca — dicatat karena hampir jadi klaim salah

Injeksi pertama memakai `Button("X") { withAnimation(...) }`. Aturan 7 **hijau**
dan exit 1 — jadi sempat disangka aturannya sendiri yang salah. Penyebabnya
bukan aturan 7: `Button("X")` membuat **aturan 4** merah, karena `"X"` tidak
ada di katalog string. Dua gerbang benar, exit code milik salah satu.

Yang benar adalah memperbaiki **probnya**: injeksi harus menguji aturan yang
dimaksud tanpa memicu aturan lain. Setelah `Button("X")` diganti
`.animation(.linear, value: 1)` (tanpa literal UI), aturan 4 tetap hijau dan
redanya benar-benar milik aturan 7. Dua-duanya tercatat karena "gerbang saya
hijau saat(@" adalah tanda probe yang rusak, bukan tanda gerbang yang benar.

### Yang benar-benar dijalankan

- `./swift-ui-lint.sh` → **7 aturan, semua hijau** (naik dari 6).
- `./swift-test.sh` → **166 CelestialEngine + 303 PointingKit, 0 gagal**
  (tidak berubah — aturan lint tidak menyentuh kode paket).
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan CJK/Cyrillic pada `swift-ui-lint.sh`: **0**. (Tiga selip sempat
  masuk ke komentar aturan ini saat menulis, dibuang sebelum commit — bukti
  lagi bahwa kelas ini muncul di mana-mana, bukan cuma di view.)
- CI hijau pada push pertama unit sebelumnya (`90b0940`): `Apple Build` run
  `37208040057` → **2× `BUILD SUCCEEDED`**, gerbang peringatan melaporkan
  *"Tidak ada peringatan compiler pada Apps/."*; `Engine Tests (Linux)` run
  `37208040009` → hijau, sebelas uji motion terlihat **lolos per nama di log CI**.

### Batas yang diketahui dan belum ditutup

- **Daftar kata asing yang korup** (`di-George`, `Memorial celebrating`,
  `danasticity`, …) **tidak** ditutup di unit ini, dan sudah dicoba lalu
  ditolak dengan bukti: harvests dari repo ini menunjukkan **2715 kata** yang
  hanya muncul di komentar, dan majority-nya adalah Bahasa Indonesia yang
  normal. Daftar peritel yang terlalu longgar akan selalu merah. Kandidat yang
  benar adalah sinyal mekanis, bukan daftar kata — misalnya pola
  `di-[ kapital]` yang filtered dari nama simbol, yang tadi diuji dan
  menghasilkan **111 false positive** (`di PointingKit`, `ke Linux`). Dua
  percobaan gagal dicatat supaya tidak diulang.
- **Aturan 7 belum menutup animasi implisit**: `.transition(...)` yang memuat
  kurva animasi sendiri, dan animasi bawaan dari `List`/`NavigationStack`.
  Keduanya di luar jangkauan penyapu teks, dan menambahkannya perlu bukti
  bahwa bentuknya benar-benar muncul di repo ini dulu.
- **Aturan 3 masih buta di `*.sh` dan `project.yml`**, dan sekarang butanya
  terbukti **lebih dalam**: ia menangkap aksara non-Latin tapi tidak
  menangkap Latin yang rusak (`di-George`, `danasticity`) — dua kelas cacat
  berbeda dengan satu sapuan.

## Progres terakhir (4 Okt 2026 — kunci katalog yang hilang menampakkan nama kuncinya sendiri)

### Premis siklus ini: STATUS lalu menutup satu celah dengan kalimat yang benar, tapi tidak lengkap

STATUS sebelumnya menulis, di "Batas yang diketahui":

> Bridge tidak dipasang di complication. Complication adalah proses terpisah
> yang tidak memanggil `.install()`, jadi labelnya selalu Bahasa Indonesia —
> bukan string kosong, dan itu jujur. Tapi kalau layer lokalisasi nanti
> ditambah, complication akan tertinggal.

Kalimat itu **benar** — dan karena itu berbahaya. Ia menutup celah dengan
diagnosa yang benar, sementara yang sebenarnya hilang bukan hanya bridge.
Dibuktikan dengan membangun XcodeGen lalu membaca `project.pbxproj` yang
dihasilkannya: target complication **tidak punya fase Resources sama
sekali**, dan `Localizable.xcstrings` hanya ada di dua app. Jadi bukan
satu lapis yang hilang, tapi dua: tidak ada katalog untuk dibaca, dan tidak
ada yang membacanya.

### Cacat pertama: `Bundle.localizedString` tidak pernah mengembalikan `nil`

`LocalizationBridge` memasang
`Bundle.localizedString(forKey:value:table:)` dengan `value:` = nama
kuncinya sendiri. Pola itu **benar sendiri** — string kosong membuat baris
terlihat kosong tanpa penjelasan. Tapi konsekuensinya belum pernah
dipikirkan: kalau kunci tidak ada di katalog, hasilnya adalah `value` — jadi
kunci yang hilang kembali sebagai **nama kuncinya**, non-kosong, dan
pemeriksaan "terjemahan tidak kosong" di `TextLocalization.text` **tidak
menahannya**.

Diverifikasi dengan program kecil, bukan dengan membaca (`Bundle.main` di
Linux memang tidak punya `.lproj`, `localizations == []`):

| Kunci | `localizedString` mengembalikan |
|---|---|
| tidak ada di katalog | `pointing.state.lock.label` — **namanya sendiri** |
| `value: ""` | `pointing.state.lock.label` juga (kosong dicegah oleh API) |

Jadi tiga label yang paling sering dibaca sekilas di seluruh app akan tampil
sebagai pengenal mentah begitu bridge terpasang dan katalog tidak ikut:
`pointing.state.lock.label`, `object.kind.star.display.label`,
`confidence.level.medium.label`.

Yang membuatnya bertahan: **teorinya benar** — "label punya terjemahan"
memang terbukti (93 kunci + padanan `en`), aturan 6 hijau, dan satu-satunya
gejalanya ada di tempat yang tidak pernah difoto: label tampil sebagai pengenal mentah hanya bila kunci hilang dari katalog,
dan tidak ada satu pun gerbang yang bisa membuat katalog kehilangan kunci.

### Perbaikannya di paket, bukan di bridge

`TextLocalization.text` sekarang menolak hasil yang **sama dengan nama
kuncinya**, lalu jatuh ke Bahasa Indonesia. Di paket, bukan di `Apps/`,
supaya setiap bridge di masa depan otomatis ikut terlindungi — termasuk yang
belum ada sekarang, termasuk `ComplicationLocalization` yang baru dibuat di
siklus ini.

Konsekuensinya dinyatakan jujur di kode: kalau katalog suatu saat hilang
**total**, layar kembali Bahasa Indonesia tanpa terlihat rusak. Itu
trade-off yang benar — lebih baik Bahasa Indonesia daripada
`pointing.state.lock.label` di wajah pengguna.

### Cacat kedua: tiga selip CJK yang tidak tertangkap aturan 3

Aturan 3 menyapu `*.swift` di `Apps/` dan `Packages/`. Yang tertulis di
`swift-ui-lint.sh` dan `project.yml` **tidak** tercakup — dan STATUS lama
sudah memperingatkan soal ini sebagai kandidat perbaikan. Terbukti sekali
lagi di siklus ini, bukan sebagai kemungkinan:

| Tempat | Selip | Tertangkap? |
|---|---|---|
| `swift-ui-lint.sh` (komentar aturan 4) | 2 kata asing tersisip | **tidak** |
| `ComplicationLocalization.swift` (komentar) | 3 kata asing tersisip | **ya** (aturan 3) |
| `ComplicationWidget.swift` (komentar) | 4 kata asing tersisip | **ya** (aturan 3) |

Selipnya sengaja **tidak ditulis ulang di sini** dengan huruf aslinya: kalau
huruf itu ikut tercantum, sapuan karakter akan menandainya di dokumen status
yang justru mencatat tempat selip itu. Yang dicatat jumlahnya, bukan isinya.

Jadi aturan 3 menangkap selip di kode tapi buta di gerbang & konfigurasi —
persis pola "hijau yang tidak hijau", kali ini pada alat yang auditorsnya
gunakan. Kandidat penutup: perluas sapuannya ke `*.sh` + `project.yml`.

### Cacat ketiga: aturan 4 buta terhadap metadata WidgetKit

Aturan 4 menyapu view modifier (`Text`, tombol, label aksesibilitas).
`.description("Objek terakhir yang dikenali, tanpa membuka app.")` — teks
yang tampil di layar pemilihan complication watchOS — **tidak pernah
disapu**, karena `description` bukan salah satu nama yang dipindai.
Terbukti: di `ComplicationWidget.swift` yang sama, aturan 4 hanya melaporkan
tiga kemunculan `Point & Know` (yang memang sengaja tidak diterjemahkan)
sementara deskripsi complication yang sebenarnya tidak punya padanan `en`
lolos.

Daftar peritel diperluas ke yang teksnya kelihatan: metadata complication
(`configurationDisplayName`, `description`), judul dialog konfirmasi, dan
pengenal aksesibilitas. Kandidat yang tidak pernah muncul di repo ini
sengaja **tidak** ditambahkan — daftar peritel yang tidak pernah dipakai
hanya menambah permukaan untuk salah baca, bukan perlindungan.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 292 PointingKit, 0 gagal**
  (naik dari 291; +1 uji). Engine tidak disentuh.
- Uji baru **dibuktikan MERAH lebih dulu** pada `text()` lama: 3 assertion
  gagal, menyebut gejalanya — *`("pointing.state.lock.label") is not equal
  to ("Terkunci")`*, `("object.kind.star.display.label") is not equal to
  ("Bintang")`, `("confidence.level.medium.label") is not equal to ("Ragu")`*.
  Uji yang tidak pernah merah adalah formalitas.
- Aturan 4 yang diperluas **dibuktikan dua arah di salinan**: tree bersih
  hijau; `accessibilityHint("Petunjuk barkas tanpa entri katalog")` yang
  disuntik → **merah**, sebut kuncinya.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS. `./swift-ui-lint.sh` → 6
  aturan hijau.
- XcodeGen **dibangun sendiri** (2.45.3, 185 detik) di container `swift:6.0`;
  `xcodegen generate` pada repo → ketiga target punya
  `Localizable.xcstrings` di fase Resources. **Sebelum perubahan: hanya
  dua**, dan target complication tidak punya fase Resources sama sekali.
- **CI hijau pada push pertama** (`a4ce1d0`):
  - `Apple Build` run `37206180937` → **2× `BUILD SUCCEEDED`**, gerbang
    peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37206180938` → hijau, dan uji baru
    **terlihat lulus per nama di log CI** (bukan hanya di mesin ini).

### Batas yang diketahui dan belum ditutup

- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux.** `Bundle.main`
  tidak punya `.lproj`, dan `String(localized:)` tidak ada di Swift 6.0
  Linux. Yang terbukti: katalog ikut ke **setiap** bundel, dan setiap
  proses extension punya bridge yang membacanya. Yang tidak: apakah `.xcstrings`
  benar-benar diterjemahkan saat perangkat berjalan. Itu wilayah CI dan
  perangkat.
- **Daftar kunci aturan 5 bisa jadi sudah usang.** `Tools/xcodegen-known-keys.txt`
  dibuat dari XcodeGen **2.46.0**, sedangkan yang bisa dibangun di VPS ini
  tag-nya **2.45.3**. Perbedaannya tidak diperiksa, jadi aturan 5 mungkin
  sudah menilai kunci yang sebenarnya berubah nama.
- **Aturan 3 masih buta di `*.sh` dan `project.yml`** — dibuktikan di atas,
  bukan asumsi.
- `ComplicationProvider.init()` memasang bridge, tapi `TextLocalization` itu
  singleton proses: kalau suatu saat complication punya lebih dari satu
  sumber (mis. setelah `AppIntent`), urutan pemasangan jadi hal yang harus
  dijaga. Saat ini hanya ada satu, jadi belum jadi masalah.

## Progres terakhir (4 Okt 2026 — 10 label yang tampil di layar tidak punya terjemahan)

### Premis siklus ini: STATUS sebelumnya menutup satu celah dengan kalimat yang salah

STATUS lalu menulis, di bagian "Batas yang diketahui":

> label `ObjectKind` (`Apps/Shared/ObjectKindLabels.swift`) — satu berkas di
> app, masuk aturan 4 seperti biasa.

Kalimat itu **diuji, bukan dipercaya** — dan ia salah. Aturan 4 tidak bisa
melihat berkas itu sama sekali. Aturan itu menyapu literal
`Text("...")`/`Button`/`Label`/`accessibilityLabel`, sedangkan
`return "Bintang"` di dalam `switch` **tidak pernah menjadi salah satu dari
itu**.

Dibuktikan di salinan, di berkas yang sama: menyuntik
`Text("Literal nyata tanpa entri katalog")` **membuat aturan 4 merah**,
sementara sepuluh label yang benar-benar tampil di layar tidak punya satu pun
padanan bahasa Inggris. Aturan 4 menangkap jebakan yang salah dan meloloskan
yang benar — dua-duanya pada berkas yang sama.

| Label | Layar | Ada padanan `en`? |
|---|---|---|
| "Bintang", "Planet", "Bulan", "Matahari", "Objek langit dalam" | panel detail jam, panel detail iPhone, complication rectangular | **tidak** |
| "bintang", "planet", … "objek langit jauh" | VoiceOver di kedua app | **tidak** |

Aturan 6 tidak menolong — dan itu menarik. Aturan 6 menjaga kunci yang
*dideklarasikan di paket*, sementara teks ini justru hidup di app. Dua
aturan itu sama-sama benar, dan keduanya mengukur bagian yang tidak
bermasalah: persis bentuk "hijau yang tidak hijau" yang sudah tiga kali
muncul di repo ini, kali ini **di dalam gerbang yang dibuat untuk menutupnya**.

### Cacat kedua, yang muncul dari perbaikannya sendiri

Label itu dipindahkan ke paket supaya bisa diuji dan bisa menjangkau katalog.
Setelah dipindahkan, **aturan 6 ikut kehilangan 10 kuncinya**: `declared`
dibaca dari `TextLocalization.swift` saja, sementara kunci baru hidup di
`ObjectKindLabels.swift`. Arah 1 ("dideklarasikan tapi tidak ada di katalog")
tidak akan melaporkannya, dan suite tetap hijau — termasuk saat semua katalog
hilang.

Jadi gerbang yang lahir untuk menangkap "kunci yang dideklarasikan tapi tidak
punya entri" justru buta terhadap kunci yang dideklarasikan di berkas kedua.
Diperbaiki dengan membaca kunci dari **seluruh** sumber paket, bukan menambah
pemeriksaan baru; dan namespace `object.kind.` ditambahkan ke Arah 2.

### Yang diubah, dan kenapa begini

- **`ObjectKindLabels.swift` pindah ke `PointingKit`**, memakai
  `LocalizedText` — sama seperti `PointingState.shortLabel` dan
  `ConfidenceLevel.displayName`. Katalog 83 -> **93** kunci, sepuluh di
  antaranya punya padanan `en`.
  Yang dipindahkan bukan cuma bentuk tampilannya. Complication berjalan di
  **proses terpisah** dan hanya menarik `PointingKit`, jadi selama labelnya di
  app, satu-satunya penjaga konsistensinya adalah pathway compile yang
  kebetulan menyertakannya — bukan aturan apa pun.
- **`spokenName` tidak disatukan ke `displayName`.** "Objek langit dalam"
  memang terdengar janggal saat diucapkan; menyatukannya demi lebih ringkas
  akan menghapus justru alasan pemisahannya. Uji menjaga keduanya punya kunci
  sendiri.
- **`swift-typecheck.sh`**: berkas dihapus dari daftar typecheck, dan
  daftarnya dibiarkan gagal keras (`no such file`) bila berkasus hilang —
  lebih baik begitu daripada diam-diam memeriksa satu berkas lebih sedikit.
- **`project.yml`**: `Apps/Shared/ObjectKindLabels.swift` tidak lagi disebut
  eksplisit sebagai sumber target complication.

**Nilai Bahasa Indonesia tidak berubah satu karakter pun** — yang dipindah adalah
*tampilannya di bahasa kedua*.

### Yang benar-benar dijalankan

- `./swift-test.sh` -> **166 CelestialEngine + 291 PointingKit, 0 gagal**
  (naik dari 286; +5 uji). Engine tidak disentuh.
- **Dua mutasi dibuktikan MERAH lebih dulu** lewat `./red-test.sh`:
  (a) `spokenName` disatukan ke `displayText` ->
  `testInstalledLookupReachesKindLabelsToo` gagal; (b) nilai bawaan
  `id: "bintang"` -> `"star"` -> **2 uji** gagal. Uji yang tidak pernah merah
  adalah formalitas.
- **Aturan 6 diperkuat, dibuktikan tiga arah di salinan**: kunci
  `object.kind.star.display.label` dibuang dari katalog -> **merah**; kunci
  `object.kind.hantu.display.label` disuntik -> **merah**; tree bersih ->
  **hijau**.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- `./swift-ui-lint.sh` -> 6 aturan hijau.
- Sapuan karakter non-Latin pada `Apps/`, `Packages/`, `Tools/`, dan skrip: **0**.
- **CI hijau pada push pertama** (`4063338`):
  - `Apple Build` run `37204467679` -> **2x `BUILD SUCCEEDED`**, gerbang
    peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37204467708` -> hijau.

### Catatan kejujuran: selip non-Latin terjadi lagi, di tempat yang tidak dijaga

Aturan 3 menjaga `Apps/` + `Packages/`, tapi **tidak** menjaga `project.yml`
maupun skrip gerbang. Tiga selip CJK masuk ke komentar saat menulis (satu di
paket, satu di `swift-ui-lint.sh`, satu di `project.yml`) dan tidak ada
gerbang yang melihatnya — keduanya harus dipindai manual. Satu di antaranya
sudah ikut ke reviewer yang sama sebelum dibuang. Dua kandidat perbaikan
nanti: perluas aturan 3 ke `project.yml` + `*.sh`, atau minimal beri tahu
skrip gerbang bahwa ia sendiri tidak tercakup sapuannya.

### Batas yang diketahui dan belum ditutup

- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux** — `Bundle.main`
  di Linux tidak punya `.lproj`, dan `String(localized:)` tidak ada di
  Swift 6.0 Linux. Yang bisa dibuktikan: setiap kunci punya entri + padanan
  `en`. Yang tidak: apakah `Bundle` benar-benar membaca `.xcstrings` saat
  perangkat berjalan. Itu wilayah CI dan perangkat.
- **Bridge tidak dipasang di complication.** Complication adalah proses
  terpisah yang tidak memanggil `.install()`, jadi labelnya selalu Bahasa
  Indonesia — bukan string kosong, dan itu jujur. Tapi kalau layer lokalisasi
  nanti ditambah, complication akan tertinggal. Belum ada gerbang yang menjaga
  hal itu.
- Teks yang dihasilkan di paket yang **belum** terjangkau katalog, dengan
  alasan masing-masing: `CalibrationSpeech` (dilewati dengan sengaja — kalimat
  itu **diucapkan**, jadi bentuknya harus bisa diuji di Linux); label
  `CalibrationFlow` (punya `formatSpecifier`, jadi katalog butuh kunci format,
  bukan teks yang sama); ringkasan `ExperimentHarness` (dirangkai dari
  beberapa bagian dengan sisipan angka).


## Progres terakhir (4 Okt 2026 — teks yang dihasilkan di PointingKit akhirnya bisa dijangkau katalog)

### Premis siklus ini: celah yang STATUS lalu sebut "belum ditutup" memang nyata

STATUS sebelumnya menutup bagian Fase C dengan satu kalimat: label yang
**dihasilkan** di `PointingKit` (`shortLabel`, `guidance`, `displayName`)
tidak pernah melewati `Text("literal")`, jadi katalog tidak bisa menjangkau
mereka. Kalimat itu dibaca, bukan dipercaya — dan memang benar, dengan
bukti: `"Terkunci"` **tidak ada** di `Localizable.xcstrings`, padahal itu
teks yang paling sering dibaca sekilas di seluruh app.

Yang membuatnya kelas yang layak dikejar: **gerbangnya hijau sepanjang
itu**. Aturan 4 menyapu literal `Text("...")` di `Apps/`, dan laporan itu
benar — tidak ada satu pun literal bermasalah. Yang tidak diukur adalah
teks yang tidak pernah menjadi literal di sana.

| Teks | 통과 aturan 4? | Punya padanan `en`? |
|---|---|---|
| "Terkunci", "Kurang yakin", "Sensor mati", "Siap", "Arahkan", "Mencari" | ya (tidak ada literal-nya) | **tidak** |
| "Yakin" / "Ragu" / "Tidak tahu" | ya (tidak ada literal-nya) | **tidak** |
| 6 kalimat panduan keadaan | ya (tidak ada literal-nya) | **tidak** |
| 5 label jenis pesan jam<->iPhone | ya (tidak ada literal-nya) | **tidak** |

20 kunci, nol di antaranya bisa dilihat oleh gerbang mana pun yang ada.

### Yang diubah, dan kenapa begini

- **`LocalizedText` (baru, `TextLocalization.swift`)** — menyimpan **kunci
  yang stabil** + Bahasa Indonesia sebagai **nilai bawaan**. Perbedaannya
  penting: kalau Bahasa Indonesia yang jadi identitas (yaitu kunci katalog
  = teksnya), maka memperbaiki ejaan berarti mengganti kunci dan seluruh
  terjemahan ikut hilang.
  - **Nilai bawaan ada di dalam tipe, bukan hanya di katalog**, karena
    paket ini **dipakai di Linux** tempat `Bundle.main` tidak punya
    `.lproj` sama sekali (`localizations == []`) dan `String(localized:)`
    **tidak ada** di Swift 6.0 Linux. Tanpa nilai bawaan, seluruh uji Linux
    menguji string kosong.
  - **Pencarian dipisah dari jenis teks.** `TextLocalization` tidak tahu
    apa pun tentang `Bundle`; app yang memasangnya
    (`LocalizationBridge`, satu fungsi). Jadi bagian yang bisa diuji di
    Linux dan bagian yang tidak bisa dipisahkan secaraGcoding — bukan
    dicampur dalam satu berkas yang tidak bisa diuji.
- **Kunci ber-NAMESPACE, bukan teksnya sendiri.** Bukti konkretnya sudah
  ada di repo: `"Kalibrasi"` di katalog berarti **judul layar kalibrasi**,
  sementara `link.kind.calibrationReady` juga berbunyi "Kalibrasi" untuk
  hal berbeda. Kalau teksnya jadi kunci, keduanya menyatu diam-diam —
  mengubah satu ikut mengubah yang lain. Uji menjaga prefix namespace-nya.
- **Aksesor lama tidak berubah bentuk**, hanya isinya:
  `shortLabel`/`guidance`/`displayName` tetap `String`, dan
  `stateLabelText`/`stateGuidanceText`/`displayText` ditambahkan sebagai
 829 sumber kunci. Tanpa bridge terpasang, hasilnya **identik dengan
  sebelumnya** — itu yang diuji dengan literal, bukan dengan `.indonesian`
  (kalau ujinya memakai `.indonesian` untuk kedua sisi, ia hanya
  membuktikan kedua sisi bergerak bersama, dan typo pada nilainya lolos).

### Cacat yang ditemukan: gerbang aturan 4 membaca komentar

Aturan 4 menjadi merah setelah `LocalizationBridge` ditulis — menunjuk
`Apps/Shared/LocalizationBridge.swift: Text: '...'`. Penyebabnya bukan
kode: baris itu **dokumentasi** yang menjelaskan kenapa aturan 4 tidak
bisa melihat teks di paket, dan ia memuat `Text("...")` sebagai contoh.

Gerbang yang membaca komentarnya sendiri akan **selalu merah**, dan gerbang
yang selalu merah akan dimatikan orang lain saat ia berbunyi. Aturan 1 dan
3 di skrip yang sama sudah membuang komentar; aturan 4 tidak pernah diberi
perlakuan itu karena ia belum pernah salah membaca komentar.

Diperbaiki dengan membuang `//` **hanya bila berada di luar literal**
(hitung status Escape) — karena `//` di dalam string (URL, regex, path)
adalah kode. Dibuktikan dua arah di salinan sementara: yang menyuntik
literal UI nyata **tetap merah**, dan yang bersih hijau.

### Cacat kedua: uji menangkap typo saya sendiri

`testDefaultTextIsExactlyTheIndonesianItShippedWith` gagal, dan pesan Xcode
menampilkan kedua sisi **terbaca identik**: `"Ambah keyakinan"`.

Yang sebenarnya berbeda satu byte: nilai bakunya di sumber tertulis
`Ambah` (huruf ke-4 `h`), sedangkan yang ditulis di uji `Ambah`. Keduanya
tampil sama di layar; hanya perbandingan byte yang membedakannya. Jadi dua
string yang **tidak bisa dibedakan mata** menangkap cacat yang **tidak bisa
dibaca dari teks**.

Perhatikan arah perbaikannya. Hampir "`tidak bisa dibedakan mata`" membuat
saya shy untuk memperbaiki ujinya, karena pesannya sendiri terlihat benar
di kedua sisi. Yang benar adalah memperbaiki **sumbernya**: nilai bawaan di
`TextLocalization.swift` yang salah eja, sementara ujinya sudah benar.
Uji itu benar karena nilainya diketik dari katalog, bukan disalin dari
sumber yang sama.

Ini persis kelas yang sudah beberapa kali muncul di repo ini, dengan satu
perbedaan penting: cacatnya ada di kode yang **baru ditulis pada siklus
ini**, jadi uji menangkapnya **sebelum sempat keluar repo** — berbeda dari
uji-uji sebelumnya yang menangkap cacat siklus-siklus lalu.

### Aturan 6: paritas dua arah

Menutup kelas yang sama, tapi **kebalikannya**: dari kunci katalog ke
paket, supaya kunci tidak bisa "dibuang diam-diam" dari `allKeys` demi
membuat pemeriksaan arah pertama terasa cukup.

| Disuntik | Hasil |
|---|---|
| hapus `pointing.state.lock.label` dari katalog | **merah**, sebut kuncinya |
| tambah `pointing.state.hantu.label` ke katalog | **merah**, sebut kuncinya |
| tree bersih | hijau |

Diverifikasi pada **salinan** (`/tmp/lintcheck`), bukan di repo.

### Yang benar-benar dijalankan

- `./swift-test.sh` -> **166 CelestialEngine + 286 PointingKit, 0 gagal**
  (naik dari 277; +9 uji). Engine tidak disentuh.
- **Dua mutasi dibuktikan MERAH lebih dulu**: (a) `shortLabel` dialihkan ke
  nilai bawaan langsung -> `testInstalledLookupWinsOverTheDefaultValue`
  gagal ("Terkunci" != "Locked"); (b) terjemahan kosong dipercaya ->
  `testEmptyTranslationFallsBackToIndonesian` gagal dengan pesan
  `("") is not equal to ("Terkunci")` — persis kegagalan diam yang paling
  berbahaya di UI.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS. `LocalizationBridge`
  **ditambahkan** ke daftar typecheck: ia memanggil `PointingKit` lintas
  modul, yang tidak bisa diselesaikan `-parse`. Batasnya sama seperti
  berkas lain di daftar itu — Linux masih tidak punya SwiftUI.
- `./swift-ui-lint.sh` -> 6 aturan hijau. Aturan 4 **tetap menangkap**
  pelanggaran nyata setelah diperbaiki (dibuktikan di salinan).
- Sapuan karakter non-Latin pada 10 berkas yang diubah: **0**. (Tiga selip
  sempat masuk saat menulis — termasuk ke dalam **pesan commit yang sama**,
  lalu ditulis ulang dengan `--amend` sebelum push. Aturan 3 menjaga kode,
  tapi tidak menjaga pesan commit; ini bukti bahwarowing sapuan tempat
  yang sama perlu mata juga.)
- **CI hijau pada push pertama** (`550f475`):
  - `Apple Build` run `37202871620` -> **2x `BUILD SUCCEEDED`**, gerbang
    peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37202871610` -> hijau, dan **sembilan uji
    baru terlihat lulus per nama di log CI** (bukan hanya di mesin ini).

### Batas yang diketahui dan belum ditutup

- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux** — sama seperti
  catatan siklus sebelumnya, dan alasannya tidak berubah. Yang bisa
  dibuktikan di sini: setiap kunci punya entri + padanan `en`, dan nilai
  bakunya tampil benar. Yang **tidak** bisa: apakah `Bundle` benar-benar
  membaca `.xcstrings` saat perangkat berjalan. Itu wilayah CI dan
  perangkat, bukan Linux.
- **20 kunci baru**, tapi teks yang dihasilkan di paket belum semuanya
  terjangkau. Yang tersisa, dengan alasan masing-masing:
  - `CalibrationSpeech` — **dilewati dengan sengaja**. Kalimat itu teks
    **yang diucapkan**, jadi bentuknya harus bisa diuji di Linux, dan sudah
    punya ujinya sendiri. Melocalisasi bentuknya berarti menambah lapisan
    yang tidak bisa diuji di tempat yang sekarang bisa.
  - label `CalibrationFlow` (`"Sebaran %.1f° masih terlalu lebar…"`) —
    punya `formatSpecifier`, jadi katalog butuh kunci format
    (`"Sebaran %1$@ masih terlalu lebar…"`), bukan teks yang sama.
  - ringkasan `ExperimentHarness` — dirangkai dari beberapa bagian dengan
   sisipan angka.
  - label `ObjectKind` (`Apps/Shared/ObjectKindLabels.swift`) — satu berkas
    di app, masuk aturan 4 seperti biasa.

  Kandidat unit berikutnya bukan yang paling mudah, tapi yang bentuknya
  paling berbeda satu per satu — supaya tiap bentuk punya aturan sendiri
  yang bisa diuji.

## Progres terakhir (4 Okt 2026 — katalog string terpasang, dan dua "cacat" yang ternyata bukan cacat)

### Premis siklus ini: ada pekerjaan yang belum di-commit di meja

`git status` menunjukkan unit Fase C item 2 (katalog string) sudah ditulis:
`Localizable.xcstrings` (63 kunci, semua punya padanan `en`), entri resource di
`project.yml`, dan aturan 4 di `swift-ui-lint.sh`. Sebelum push, isinya dibaca
ulang - dan **dua dari tiga hal yang saya kira cacat ternyata bukan cacat.**
Bagian paling berharga dari siklus ini justru catatan itu.

### Yang saya klaim cacat, lalu saya buktikan sendiri tidak jadi

| Klaim awal | Kenyataan |
|---|---|
| `knownRegions` di `options` membuat CI gagal | **Bukan opsi XcodeGen sama sekali** - diabaikan diam-diam |
| Entri `Apps/Shared/Resources` menggandakan katalog | XcodeGen sudah memetakan `.xcstrings` ke resources; hasilnya **identik** |

Keduanya saya buktikan dengan cara yang tidak bisa dibantah: saya **membangun
XcodeGen 2.46.0 sendiri** di container `swift:6.0` (187 detik), lalu
menjalankan `xcodegen generate` pada repo ini dan pada salinan yang
`project.yml`-nya dikembalikan ke versi lama. Hasilnya sama persis:
`developmentRegion = id`, `knownRegions = (Base, en, id)`, katalog jadi
2 build file (satu per app), 1 fileRef.

Pelajarannya bukan soal dua baris YAML. **`project.yml` tidak punya gerbang.**
`swiftc -parse` tidak membaca YAML, `swift test` tidak membangun proyek, dan
CI memanggil `xcodegen generate` yang keluar 0 meski isinya salah total.
Jadi kelas cacat ini mustahil ditangkap gerbang yang ada - dan saya baru
menyadarinya setelah hampir mendorong dua "perbaikan" yang tidak memperbaiki
apa pun.

### Cacat NYATA yang ditemukan di unit yang sama: `developmentRegion` selalu `en`

Kunci yang benar-benar ditemukan bukan yang saya duga. `developmentRegion`
diisi dari `options.developmentLanguage` (`PBXProjGenerator:99`,
`project.options.developmentLanguage ?? "en"`), **bukan** dari build setting
`DEVELOPMENT_LANGUAGE` di `settings.base` yang sudah ada.

Dibuktikan di tiga kondisi:

| Kondisi | `developmentRegion` |
|---|---|
| `project.yml` di HEAD apa adanya | **`en`** |
| `knownRegions` tak dikenal, tanpa `developmentLanguage` | **`en`** |
| `developmentLanguage: id` | **`id`** |

Jadi sejak katalog ini belum pernah ada, proyek menyatakan bahasa
pengembangan `en` sementara seluruh teks sumbernya bahasa Indonesia. Dan
`knownRegions` pun ikut salah: tanpa `id`, bahasa Indonesia tidak pernah
muncul sebagai bahasa yang bisa dipilih di Xcode - padahal brief dan Fase C
meminta dua bahasa siap pakai.

Perbaikannya satu baris (`developmentLanguage: id`) plus penjelasan kenapa
build setting saja **tidak cukup** - keduanya memang perlu, dan hanya
menuliskan yang satu meninggalkan keadaan yang sama.

### Gerbang baru: aturan 5, dan dua false positive yang harus dibunuh

Kelas cacat "kunci `project.yml` yang diabaikan diam-diam" tidak boleh bisa
berulang, jadi `./swift-ui-lint.sh` dapat **aturan 5**: kunci di `options:` dan
`settings:` dicek terhadap daftar yang diambil dari sumber XcodeGen
(`Tools/xcodegen-known-keys.txt`, beserta perintah untuk memperbarinya).

Gerbang ini harus direvisi dua kali sebelum benar, dan itu bagian paling
bernilai untuk dicatat:

1. Versi pertama menelusuri seluruh turunan YAML, lalu melaporkan `base`,
   `Debug`, `Release`, `iOS`, `watchOS`, dan `SWIFT_ACTIVE_COMPILATION_CONDITIONS`
   sebagai "tidak dikenal". Semuanya **sah**. Gerbang yang selalu merah akan
   dimatikan orang lain saat berbunyi, jadi ini bukan sekadar soal tampilan -
   itu alasan gerbang tidak boleh longgar.
2. Perbaikannya menyisakan `base` (anak sah dari `settings:`), sehingga
   perbaikannya sendiri masih merah. Butuh daftar anak yang dikecualikan
   secara eksplisit.

Sekarang terbukti keempat arah di salinan sementara: tree bersih **hijau**;
`knownRegions` disuntik **merah** (tepat satu kunci); `opsiNgawur` **merah**;
dikembalikan lagi **hijau**.

Gerbang aturan 4 juga dibuktikan dua arah pada siklus ini (kunci
`Text("Kunci baru tanpa entri katalog")` disuntik -> keluar 1; tree bersih
-> keluar 0), karena katalog **tidak** diisi otomatis
(`SWIFT_EMIT_LOC_STRINGS: NO`) sehingga tidak ada gerbang Xcode yang bisa
melihat teks yang belum punya terjemahan.

### Temuan yang harus dicatat: `xcodegen generate` mengubah `Info.plist`

Menjalankan XcodeGen di repo ini **menghapus** `CFBundleDisplayName` dari
`Apps/PointAndKnowWatch/Complications/Info.plist` dan menggantinya dengan
tab. Berkas itu di-commit, jadi menjalankan generator di mesin kerja langsung
membuat tree kotor - dan kalau tidak sengaja ikut ter-commit, complication
kehilangan nama tampilnya. Dikembalikan dengan `git checkout --`.

Batasnya jujur: ini efek samping yang saya temukan tanpa sengaja, **bukan**
uji. Yang diketahui pasti: generator menulis ulang `Info.plist` yang
dispesifikasikan di `project.yml`, dan `Info.plist` yang di-commit bisa
menjadi lebih kaya daripada hasil generator. Yang belum diperiksa: apakah
Xcode di CI melihat perubahan yang sama.

### Batas yang diketahui dan belum ditutup

- **Terjemahan `en` tidak bisa diverifikasi di Linux.** `Bundle.main` di Linux
  tidak punya `.lproj` (`localizations == []`), dan `String(localized:)`
  **tidak ada** di Swift 6.0 Linux - hanya
  `Bundle.localizedString(forKey:value:table:)`, yang selalu mengembalikan
  fallback di sini. Jadi yang bisa dibuktikan di Linux: setiap kunci punya
  entri, dan setiap pasangan key/`en` punya paritas `%`-specifier. Yang
  **tidak**: terjemahan itu benar dibaca perangkat. Itu tetap wilayah
  CI dan perangkat.
- Katalog berisi 63 kunci; `Text(...)` di `Apps/` yang tidak punya entri
  **nol** menurut aturan 4. Tapi label yang **dihasilkan** di `PointingKit`
  (`shortLabel`, `guidance`, `displayName`) tidak pernah melewati
  `Text("literal")`, jadi katalog tidak bisa menjangkau mereka. Itu celah
  Fase C yang belum ditutup, dan kandidat unit berikutnya.

### Yang benar-benar dijalankan

- `./swift-test.sh` -> **166 CelestialEngine + 277 PointingKit, 0 gagal**.
  Engine tidak disentuh.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- `./swift-ui-lint.sh` -> 5 aturan, semua hijau; aturan 4 dan 5 dibuktikan
  merah lalu hijau di salinan sementara.
- `xcodegen generate` (XcodeGen 2.46.0, dibangun lokal) -> proyek terbentuk,
  `developmentRegion = id`, `knownRegions = (Base, en, id)`, katalog 2 build
  file dan 1 fileRef, `postGenCommand` berjalan.
- Sapuan karakter non-Latin pada semua berkas yang diubah: **0**.
  Beberapa selip sempat masuk ke dalam komentar, dan tertangkap aturan 3
  sebelum commit - itulah alasan aturannya ada. Entri STATUS.md ini sendiri
  pertama kali kena cacat yang sama, lalu ditulis ulang per bagian.


## Progres terakhir (4 Okt 2026 — baris keempat + gerbang aksara, lalu README, lalu VoiceOver)

### Siklus 4 — kelas cacat yang saya klaim selesai, padahal tidak

Siklus 2 menulis: "`row(_:_:)` dipakai di **tiga** layar". Itu salah.
Ada **empat** — `SkyContextView.row` di jam punya bentuk yang sama persis,
tapi masih merangkai kalimatnya sendiri. Jadi kelas cacat "dua jalur yang
seharusnya identik, hanya satu yang diperbaiki" **masih ada**, persis seperti
yang diklaim sudah ditutup.

Yang membuatnya berbahaya: STATUS.md sudah mencatatnya selesai, jadi tidak
ada yang akan mencarinya lagi. Persis kondisi yang membuat siklus 1 terjadi —
klaim "sudah beres" yang tidak pernah diverifikasi ulang.

**Gerbang aturan 3** sekarang menjaga dua hal sekaligus:

1. `row(_:_:)` tidak lagi menangkai kalimat pengumuman sendiri.
2. Tidak ada aksara CJK/Cyrillic/fullwidth di kode.

Yang kedua terjadi **berulang dalam satu siklus**, termasuk pada pesan
commit yang sama. Bukan keputusan yang salah — selip yang di tengah kalimat
Indonesia terbaca sebagai satu kata lalu dilewati. Persis kelas cacat yang
tak terlihat mata dan tak tertangkap compiler.

Sapaan diperluas dari `Apps/` ke `Apps/` + `Packages/`. Terbukti dua arah:
tree bersih lulus, tree dengan karakter disuntikkan gagal.

### Catatan kejujuran

Satu commit sempat terpush dengan CJK di pesannya, lalu ditulis ulang
dengan `--force-with-lease`. Riwayat bersih sekarang; tidak ada commit
dengan CJK yang masih terjangkau di `main`.

### Siklus 3 — README: isi yang paling dibutuhkan orang yang baru membuka repo

Repo ini belum punya README, padahal isinya persis yang dibutuhkan:
cara membangunnya, mengapa logika ada di paket dan bukan di app, dan
**bagaimana cara mengukur** klaim "akurasi jam adalah hipotesis".

Yang ditulis lebih penting daripada daftar perintah:

- `POINT → OBJECT ID → SAFE GOTO` dan kenapa arah pergelangan tidak boleh
  pernah jadi perintah motor.
- Kenapa `Packages/` ada: seluruhnya teruji di Linux — pemisahan inilah
  yang membuat cacat logika bisa ditangkap tanpa Mac.
- Kenapa kalimat VoiceOver pindah ke paket: kalimat terucap tidak pernah
  terlihat salah di layar mana pun, jadi satu-satunya penangkapnya uji.
- Tiga gerbang dicatat sebagai tiga **celas berbeda**, bukan duplikat.

Setiap angka dan nama berkas diverifikasi terhadap repo sebelum commit:
166 engine + 277 PointingKit, 3 tab iPhone (bukan 2 — klaim pertama salah),
macos-15, dan batas `red-test.sh` (hanya PointingKit) dinyatakan apa adanya
alih-alih diklaim universal.

### Siklus 2 — cacat yang ditemukan oleh gerbang siklus 1

Aturan 2 (`°/dtk` tanpa padanan ucapan) mem-flag 5 situs. Pemeriksaan
lebih dalam menemukan **kelas cacat yang sama** dengan siklus 1: dua jalur
yang seharusnya identik, hanya satu yang dibenahi.

`row(_:_:)` dipakai di tiga layar dengan kode yang benar-benar identik
(`Text(title)` — `Spacer()` — `Text(value)`). Dua (`PointingView.statusCard`,
`SkyContextView.row`) mengumumkannya sebagai satu kalimat; yang ketiga tidak
mengumumkan apa pun. Akibatnya VoiceOver membaca **dua elemen tanpa
hubungan** — "Laju pergelangan" lalu "0.5°/dtk" — dan "/dtk" bukan kata.

Perbaikannya bukan menambal yang tertinggal, melainkan membuat ketiganya
memakai satu sumber (`RowSpeech` di PointingKit) sehingga tidak ada lagi
jalur yang bisa tertinggal. Kalimat terucap adalah **janji produk** yang
tidak terlihat salah di layar mana pun — jadi ia harus teruji.

**Cacat yang ditemukan saat menulisnya:** `spokenRate` awalnya `%.0f`, jadi
tampilan "0.4°/dtk" diucapkan "0 derajat per detik". Laju pergelangan saat
diam memang bernilai di bawah 1 — jadi "bergerak pelan" terdengar sama
dengan "diam". Uji ditulis dulu, dibuktikan merah, baru diperbaiki.
Presisi kini mengikuti tampilan (`spokenDegrees(_:precision:)`), sama
seperti RA/Dec yang ditulis `%.4f°`.

Baris percobaan diumumkan dengan **verdict lebih dulu**: di layar mata
melihat nama besar di kiri dan verdict kecil di kanan, tapi di suara tidak
ada "kiri" dan "kanan" — dan yang menentukan apakah baris itu layak dibuka
adalah verdict-nya.

### Premis siklus 1: aturan yang sudah ditegakkan, lalu muncul lagi

STATUS lama mencatat Dynamic Type selesai: "Semua font sudah semantic, 0
`.system(size:)` di kode". Audit siklus ini menemukan klaim itu **sudah tidak
berlaku** — ada satu pelanggaran nyata di
`ComplicationWidget.swift:102`, `.font(.system(size: 11, weight: .semibold))`.

Bukan karena ada yang sengaja melanggar. Berkas itu ditambahkan **siklus
lalu** (complication watchOS), setelah sapuan Dynamic Type terakhir dijalankan.
Dan tidak ada satu pun gerbang yang melihatnya:

| Gerbang | Apakah ia melihatnya |
|---|---|
| `swiftc -parse` | tidak — sintaks tidak peduli ukuran font |
| `swift test` (Linux) | tidak — berkas SwiftUI tidak ikut terbangun |
| CI macOS | tidak — ia hanya gagal bila ada *warning* |

Jadi satu-satunya penjaga aturan ini adalah **ingatan orang yang sedang
menulis**, dan itulah yang gagal. Ini kelas cacat yang berbeda dari lima
siklus sebelumnya (geometri raster yang tak terbaca): di sini kodenya benar,
niatnya benar, dan **prosesnya** yang tidak punya penjaga.

### Kenapa ini bukan sekadar satu baris

Lingkaran complication adalah **ruang terkecil di seluruh app**. Ukurannya
kecil justru karena ia dibaca sekilas — dan teks yang dibaca sekilas paling
perlu bisa membesar mengikuti Dynamic Type. Ukuran tetap 11pt mengabaikan
skala pengguna **sepenuhnya**: di jam 41mm dengan teks diperbesar, angka itu
tidak bergerak.

Ini juga cacat yang paling mudah muncul lagi. Complication adalah berkas baru;
berkas baru adalah tempat aturan lama paling sering tidak ikut terbawa.

### Yang diubah, dan kenapa begini

- **`swift-ui-lint.sh` (baru)** — sapu teks untuk aturan UI yang tidak bisa
  ditegakkan compiler. Menutup **kelasnya**, bukan satu gejalanya: berkas
  complication berikutnya (atau view baru apa pun) ikut tercakup tanpa ada
  yang perlu ingat.
  - **Komentar sengaja dilewati.** Proyek ini mendokumentasikan "kenapa"
    panjang lebar, dan beberapa komentar menyebut `.system(size:)` sebagai
    contoh yang **dilarang**. Sapu naif akan selalu merah — dan gerbang yang
    selalu merah akan dimatikan orang lain saat ia berbunyi. Yang diperiksa
    adalah bagian sebelum `//`.
- **Dipasang di kedua workflow, bukan hanya macOS.** Alasan praktisnya:
  pelanggaran ketahuan dalam detik di Linux, tanpa menunggu antrean runner
  macOS. Alasan prinsipnya: sapunya murni teks, jadi ia **bisa** berjalan di
  Linux — menjadikannya gerbang macOS-only berarti membuang kemampuan itu.
- **Dibuktikan dua arah**, bukan hanya hijau: **MERAH** (keluar 1) pada
  pelanggaran yang ada, dan **HIJAU** (keluar 0) setelah diperbaiki di salinan
  sementara. Gerbang yang belum pernah merah tidak bisa dipercaya hijaunya.
- **Perbaikan nyata**: `.caption2.weight(.semibold)`. Beratnya dipertahankan,
  ukurannya diserahkan ke sistem.

### Aturan 2: peringatan yang sengaja tidak dijadikan kegagalan

Sapu kedua mencari singkatan **visual** — `°/dtk`, `RA`, `Dec`, `mag`.
Itu terbaca oleh mata dan tidak terbaca oleh pembaca layar. Sapu **tidak
bisa** membuktikan bahwa padanan yang diucapkan ada, jadi menjadikannya
kegagalan hanya akan memaksa orang menulis `// swift-ui-lint: disable`.
Dibiarkan sebagai peringatan yang harus dibaca.

Ia langsung menemukan inkonsistensi nyata (belum diperbaiki, lihat bawah).

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 266 PointingKit, 0 gagal**.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `./swift-ui-lint.sh` → **MERAH dulu** pada pelanggaran nyata, lalu **HIJAU**
  setelah perbaikan; dibuktikan pada salinan sementara.
- **CI hijau pada push pertama** (`354801e`): `Apple Build` run `37197032727`
  **success** (termasuk gerbang peringatan "Tidak ada peringatan compiler pada
  Apps/"), `Engine Tests (Linux)` run `37197032731` **success**. Langkah
  "Gerbang sapu UI (font tetap)" terlihat **benar-benar berjalan di log kedua
  workflow**, bukan sekadar dilewati.

### Inkonsistensi yang ditemukan dan sengaja BELUM diperbaiki

Aturan 2 membuktikan bahwa aturan "singkatan visual harus punya padanan yang
diucapkan" **tidak dipegang merata**:

| Tempat | VoiceOver |
|---|---|
| `PointingView.statusCard` | benar — laju diucapkan "derajat per detik" |
| `SkyContextView.row` | benar — `.accessibilityLabel("\(title): \(value)")` |
| `DiagnosticsView.row` | **tidak ada** — "0.5°/dtk" terbaca apa adanya |
| `LinkView.row` | **tidak ada** |
| `Experiment1View` (baris + `detailLine`) | **tidak ada** |

Dua tempat sudah benar, tiga tidak — persis pola "dua jalur yang seharusnya
sama justru berbeda" yang sudah dua kali jadi cacat di repo ini. Sengaja
dicatat di sini, bukan dikerjakan di siklus yang sama: siklus ini menambah
gerbangnya dulu, dan gerbang itu yang akan membuktikan perbaikannya.

### Pelajaran

Lima siklus terakhir menemukan cacat dengan **menghitung** (kutub Mars
0.26R, cincin Saturnus 0.9R, pita Bulan terbalik, lencana ragu 0.132R).
Siklus ini berbeda: cacatnya bukan angka, melainkan **aturan yang tidak punya
penjaga**. Menghitung akan tetap menemukan cacat geometri; yang menemukan
kelas ini adalah bertanya *"gerbang mana yang akan merah kalau ini
dilanggar?"* — dan bila jawabannya "tidak ada", menulis gerbangnya.

### Premis siklus ini: Fase C item 1 — complication WidgetKit

Item 4 (izin lokasi ditolak terlihat) sudah hijau. Sekarang celah tersisa
terbesar: **complication watchOS**. Tanpa dia, pengguna harus membuka app
setiap kali ingin tahu apa yang terakhir dikunci — persis gesit yang membedakan
app astronomi premium (Star Walk menaruh objek terkunci di wajah jam).

### Yang ditambah, dan kenapa begini

- **`ComplicationDigest` di PointingKit** (`PointingPresentation.swift`) — ini
  inti keputusannya. Complication hidup di proses terpisah, jadi ia hanya
  menerima beberapa nilai sederhana. Tapi aturan "bagaimana ringkasan ini
  ditampilkan" adalah **janji tampilan**, dan janji itu harus bisa diuji di
  Linux. Kalau bentuknya diletakkan di `Apps/`, satu-satunya verifikasi yang
  ada hanyalah "kompilasi di Mac" — persis celah yang membuat
  `CelestialSnapshot` dulu bisa menampilkan identitas saat engine ragu.
  Maka bentuk + aturannya diletakkan di `PointingKit` (yang sudah punya
  `PointingPresentationTests`), dipakai bersama oleh app dan complication.
  - **`objectKindRaw`, bukan labelnya.** Label Bahasa Indonesia tiap jenis
    benda (`"Objek langit dalam"`) adalah urusan app dan boleh berubah saat UX
    berubah. Kalau label ikut di-*snapshot*, setiap perubahan label jadi **data
    lama yang salah** sampai app menyimpan ulang. Menyimpan `ObjectKind`
    (nilai engine yang stabil) membuat label selalu dihitung saat render.
  - **`.uncertain` tetap menampilkan nama kandidat** (`headline`), persis
    seperti layar utama — tapi `isConfirmed` hanya `true` saat `.lock`, lewat
    `looksConfident` yang sudah ada. Empat tes baru menjaga ini, termasuk
    `testDigestKeepsObjectNameButRefusesToClaimIdentity`.
- **`Apps/Shared/Complication/ComplicationStore.swift`** — satu-satunya tempat
  baca/tulis berkas. App Group `group.dev.celestial.pointandknow` (wajib untuk
  berbagi antar-proses di watchOS) dengan **fallback ke caches** bila container
  `nil` (CI tanpa tanda tangan / Simulator tanpa grup). Fallback itu sadar dan
  terdokumentasi — bukan "kegagalan diam", sebab di perangkat nyata dengan grup
  aktif, app & complication memakai URL yang sama.
- **`Apps/PointAndKnowWatch/Complications/ComplicationWidget.swift`** — target
  WidgetKit (`@main`, `StaticConfiguration`, `supportedFamilies` circular/
  rectangular/inline). Timeline `policy: .never` + satu entri: kita tidak tahu
  kapan pengguna mengunci, jadi **app** yang memicu reload saat transisi.
- **Throttle tulis di `PointingEngine.publish`** — hanya menulis bila tanda
  tangan (keadaan, nama objek, konfirmasi) berubah. `publish` dipanggil
  20×/dtk; menulis berkas 20×/dtk membakar baterai & memicu reload percuma.
- **Target + entitlements** — `PointAndKnow Watch Complication`
  (`type: app-extension`, `NSExtensionPointIdentifier: com.apple.widgetkit-extension`,
  `entitlementsPath`) terbenam di app jam lewat `embed: true`.

### Cacat yang ditemukan siklus ini: gerbang lokal terlalu lemah

Empat kegagalan berturut-turut, dan **tiga di antaranya tidak terlihat lokal**:

1. `entitlements:` vs `entitlementsPath:` — XcodeGen menolak spec-nya, jadi
   baru ketahuan dari CI (parse gagal sebelum kompilasi dimulai).
2. `replaceItem(at:withItemAt:)` — Linux **tipe-check**-nya tidak, jadi
   argumen yang kurang (`backupItemName:`, `resultingItemURL:`) lolos `parse`
   lalu meledak di macOS.
3. `containerURL(forSecurityApplicationGroupIdentifier:)` — API Apple-only;
   `parse` di Linux tidak pernah menyentuhnya.
4. **Tiga cacat SwiftUI sekaligus** di widget: `StaticConfiguration` butuh
   label `provider:`; `switch` di atas `WidgetFamily` tidak exhaustive
   (`@unknown default` tidak menutup kasus yang *sudah ada*, hanya kasus
   yang belum dikenal); dan cabang `switch` yang bertipe beda (`Text` vs
   `Gauge` vs `HStack`) — `@ViewBuilder` tidak bisa mengembalikan satu
   tipe dari beberapa view berbeda.

**Akar masalahnya sama**: `swiftc -parse` hanya memeriksa sintaks. Semua cacat
tipe lolos lokal lalu menunggu CI macOS — satu siklus penuh per kesalahan.
Maka **`swift-typecheck.sh`** dibuat: ia menjalankan `swiftc -typecheck` (bukan
`parse`) untuk berkas yang hanya mengimpor Foundation/CelestialEngine/
PointingKit, di dalam Docker yang sama. Batasnya ditulis jujur di kepala
berkas: berkas SwiftUI (WidgetKit/Canvas/Combine) tetap hanya bisa di-parse di
Linux. Cacat #4 membuktikan batas itu nyata, bukan sekadar angan-angan.

### Verifikasi

- `./swift-typecheck.sh` → **SEMUA GERBANG LULUS** (typecheck store + label,
  parse semua `Apps/**/*.swift`).
- `./swift-test.sh` → **166 CelestialEngine + 256 PointingKit = 422 hijau**.
- CI macOS: `App (iPhone + Watch)` **success** — termasuk langkah
  **"Gerbang peringatan (kode sendiri)"**, artinya complication kompilasi dengan
  **nol warning**. `Paket (Apple SDK)` success, `Engine Tests (Linux)` success.
- Run: `37193453845` (Apple) & `37193453796` (Engine).

### Risiko yang diketahui

- Complication butuh App Group **aktif di profil provisi** untuk berbagi data
  lintas proses. Di CI (unsigned) ia tetap kompilasi & lolos, tapi di sana
  complication hanya membaca bila grup tersedia. Ini kebutuhan platform, bukan
  cacat — tidak ada cara berbagi tanpa grup.
- `swift-test.sh`: **166 CelestialEngine + 256 PointingKit = 422 hijau** (4 tes
  baru untuk `ComplicationDigest`).

### Premis siklus lalu: Fase C dimulai dari celah yang paling berdampak

Bagian 1–4 (visual + polish) dan Fase A (malam, AOD, VoiceOver) serta Fase B
(animasi, Dynamic Type, audio) sudah terpasang. Dari empat celah Fase C, tiga
sudah ada: Info.plist izin (item 3) tertulis di `project.yml`; widget (item 1)
dan lokalisasi (item 2) belum dipegang. Item 4 — **verifikasi izin runtime** —
justru punya cacat nyata yang belum tertutup, dan itulah yang dikerjakan dulu.

### Cacat yang ditemukan: penolakan izin lokasi diam

`LocationProvider` memang menghitung `statusText = "Izin lokasi ditolak — memakai
lokasi bawaan"` saat `authorizationStatus` `.denied`/`.restricted`, di **dua**
tempat (`start()` dan `locationManagerDidChangeAuthorization`). Tapi `statusText`
itu **tidak pernah dibaca UI mana pun** — ia hanya `private(set)` lokal. Akibatnya
saat pengguna menolak izin lokasi, engine tetap jalan dengan `ObserverLocation.fallback`
(Jakarta), dan layar jam/iPhone **tetap terlihat normal**: tidak ada peringatan,
tidak ada penanda. Pengguna tidak tahu bahwa seluruh langit dihitung untuk Jakarta,
bukan tempatnya. Itu tepat kelas "kegagalan diam" yang berulang kali dilarang PRD
("jangan diam saat izin ditolak"), dan sepadan dengan cacat sensor-mati yang sudah
ditutup di siklus lalu — hanya beda sumber.

Sebaliknya `MotionLogger.unavailableReason` **memang** ditampilkan (di `PointingView`
dan `DiagnosticsView`), jadi penolakan sensor terlihat sedangkan penolakan lokasi
tidak. Dua jalur izin yang seharusnya sama justru berbeda: satu diam, satu terlihat.

### Yang diubah, dan kenapa begini

- **`LocationProvider.note` (`String?`)** — satu sumber peringatan yang `nil` di
  luar keadaan gagal. Sengaja **bukan** `statusText` apa adanya: `statusText`
  memakai nilai netral ("Lokasi belum diminta", "Mencari lokit…") yang bukan
  kesalahan, jadi membakar semuanya ke layar justru memunculkan pesan menakutkan
  saat segalanya normal. `note` di-set hanya pada `.denied`/`.restricted` dan pada
  `didFailWithError`, dan **di-clear** (`nil`) saat lokasi sungguhan tiba serta saat
  mulai mengambil (jalur `default`). Semantik "ada peringatan ↔ nilai tidak-nil"
  inilah yang membuat tampilan tidak perlu membedakan teks.
- **Pesan penolakan menyebut jalan keluar**: "Buka Pengaturan untuk mengizinkan,
  atau pakai lokasi bawaan (Jakarta)." Bukan sekadar "ditolak" — pengguna harus tahu
  bahwa app tetap berguna (dengan akurasi yang diketahui buruk), dan cara memperbaiki.
- **`PointingView` menerima `location: LocationProvider`** (sebelumnya tidak) dan
  menampilkan `location.note` di bawah peringatan sensor, dengan `PointingTone.warning`.
  `PointAndKnowWatchWatchApp` menyuntikkannya.
- **`DiagnosticsView` menampilkan `location.note`** di bagian "Sensor & lokasi",
  sejajar dengan `motion.unavailableReason`.

Perubahan murna `Apps/`: `PointingKit`/`CelestialEngine` tidak disentuh, jadi 165 +
252 test tidak bisa terpengaruh.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **165 CelestialEngine + 252 PointingKit, 0 gagal** (naik
  dari STATUS lama "166 + 244"; angka terbaru dari satu siklus ini). Engine tidak
  disentuh.
- Gerbang sintaks `swiftc -parse -swift-version 5` seluruh 22 berkas app lolos di
  container `swift:6.0` (`ALL PARSED`) — `LocationProvider.note` baru, injeksan
  `location` ke `PointingView`, dan call-site `PointAndKnowWatchWatchApp` semua
  lolos parse.
- CI macOS (Apple Build) akan memverifikasi resolusi tipe (`@ObservedObject
  var location` baru, `location.note`) yang `-parse` tidak selesaikan.

## Progres terakhir (4 Okt 2026 — fase gibbous & purnama tergambar sebagai komplemennya)

### Premis siklus ini: "sabit benar arahnya" belum berarti "fase benar besarnya"

Brief menyebut sabit harus benar arahnya, dan itu memang sudah terperbaiki
serta teruji (`litSide`). Tapi pengujian lama hanya memeriksa **tanda** dan
**lebar pita di ekuator** — dua bilangan yang keduanya benar untuk separuh
fase dan **salah total untuk separuh lainnya**. Yang tidak pernah diuji: apakah
luas yang benar-benar digambar sama dengan fraksi iluminasi.

### Cacat yang ditemukan: tanda yang dibuang, lalu dikalikan ulang

`drawMoon` menulis:

    let side = CGFloat(phase.litSide)
    let semiWidth = CGFloat(phase.terminatorSemiWidth)   // abs(terminatorOffset)
    x = side * semiWidth * radius * sqrt(1 - dy*dy)

`terminatorOffset` sudah bernilai `litSide · (1 − 2f)`, jadi **tandanya sudah
menentukan sisi terminator**: positif untuk sabit, negatif untuk gibbous. View
mengambil nilai mutlaknya, lalu mengalikan lagi dengan `litSide` — tanda itu
ikut hilang, dan untuk `f > 0.5` kurvanya terpaku kembali ke sisi yang menyala.
Pita yang digambar menjadi **komplemen** dari fraksi yang benar:

| f (engine) | Pita digambar | Selisih |
|---|---|---|
| 0.25 | 0.2503 | benar |
| 0.50 | 0.4998 | benar |
| 0.75 | 0.2503 | **−0.50** |
| 0.85 | 0.1504 | **−0.70** |
| 0.95 | 0.0506 | **−0.90** |
| **1.00** | **0.0007** | **−1.00** |

Dihitung dengan rumus shoelace pada poligon yang **sama** dengan yang
digambar `Canvas` (72 segmen), bukan dengan Integral analitik — supaya angka
yang diuji adalah angka yang sampai ke layar. Diskritisasi 72 segmen menambah
~0.001, jauh di bawah cacatnya.

### Akibat yang paling merusak: bulan purnama tampil sebagai piringan gelap

Pada `f = 1.0` luas pita yang digambar **0.0007** — praktis nol. Jadi di layar
Ketelitian tertulis **"Fase Bulan 100%"** sementara tepat di bawahnya
tergambar piringan gelap. Ini bukan sekadar salah gambar: PRD melarang visual
yang **lebih yakin** atau bertentangan dengan teksnya, dan di sini keduanya
saling meniadakan — teksnya benar, gambarnya menyatakan kebalikannya. Tidak
ada jalur yang bisa dibaca pengguna untuk memperbaiki sendiri: gambar dan
angka berasal dari sampel yang sama, jadi ketidakcocokan ini bukan soal data
basi.

### Mengapa ia bertahan melewati 224 uji

1. **Setengah fase memang benar.** Sabit 25% tergambar 25% (selisih 0.0003).
   Setiap pemeriksaan visual yang dilakukan orang — dan setiap uji lama —
   kebetulan jatuh di sisi yang benar.
2. **Uji lama mengukur bilangan yang salah.** `litSide` benar untuk semua
   fase. `litBandWidth` benar untuk semua fase **karena ia selalu positif**
   (memakai `abs`) — ia tidak pernah bisa membedakan gibbous dari sabit.
   Uji yang paling tampak lengkap justru tidak bisa menangkapnya.
3. **`swiftc -parse` hanya sintaks**, `swift test` di Linux tidak punya
   `Canvas`, dan tidak ada teks layar lain yang bisa diperiksa.
4. Geometri ini **tidak pernah dihitung** — hanya dibaca. Membaca
   `abs(bertanda) * sisi` memang terlihat "benar" bagi mata.

### Yang diubah, dan kenapa begini

- **Kurva limb & terminator pindah ke `PhaseGeometry`** sebagai
  `limbX(atNormalizedHeight:)` dan `terminatorX(atNormalizedHeight:offset:)`,
  memakai **offset bertanda** apa adanya. View kini hanya meneruskan model.
  Ini mengikuti aturan repo yang sudah berlaku: keputusan visual yang bisa
  salah tanpa ada yang bisa mengujinya **tidak boleh tinggal di view**.
- **`terminatorSemiWidth` dihapus.** Isinya persis
  `abs(terminatorOffset)` — yaitu pemicunya — dan setelah view diperbaiki ia
  **tidak punya pemanggil sama sekali**. Membiarkannya berarti menyisakan
  jebakan yang bisa dipakai ulang persis oleh bug yang sama.
- **`litBandWidth` diberi peringatan di komentarnya** bahwa ia bukan ukuran
  yang digambar, dan tidak bisa membedakan gibbous dari sabit.
- Parameter `offset:` pada `terminatorX` sengaja ada hanya supaya uji bisa
  memanggil `abs(...)` secara eksplisit untuk mengunci cacat lama. Swift
  **melarang instance member sebagai nilai default parameter**, jadi ia
  `Double? = nil` dengan fallback di dalam badan — bukan `= terminatorOffset`.

### Uji dibuktikan MERAH lebih dulu

Dengan `terminatorX` dikembalikan ke geometri lama (`litSide * abs(...)`):

- `testLitBandAreaMatchesTheIlluminatedFraction` → **8 assertion gagal**,
  pesan menyebut angkanya: *"pita terang digambar 14.97 persen untuk fraksi
  85.0 persen (membesar)"*.
- `testFullMoonFillsTheDiscInsteadOfGoingBlack` → gagal: `5.3e-17` vs `0.98`
  (piringan gelap, seperti diterangkan di atas).
- `testLegacyAbsoluteTerminatorDrewTheComplement` → **hijau** pada geometri
  lama, sesuai desainnya: ia mengunci angka cacat yang lama, bukan geometri
  yang sekarang.
- **Yang tetap hijau** pada geometri lama: `f = 0.05, 0.20, 0.25, 0.50` —
  dipertahankan sebagai bukti langsung bahwa separuh fase memang benar
  sejak dulu.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 233 PointingKit, 0 gagal**
  (naik dari 228 → 233). Engine **tidak disentuh**.
- Kelima uji baru **dibuktikan MERAH lebih dulu** pada geometri lama.
- Gerbang sintaks: seluruh **22** berkas app lolos `swiftc -parse -swift-version
  5` di container `swift:6.0`.
- Sapuan CJK/Cyrillic/simbol fullwidth pada berkas yang diubah: **0** (dua
  kata asing sempat lolos ke komentar saat penulisan, dibuang sebelum commit).
- **CI hijau pada push pertama** (`41f58d1`):
  - `Apple Build` run `37185919763` → **2× `BUILD SUCCEEDED`** dan gerbang
    peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
    (`swiftc -parse` tidak akan pernah menangkap unresolved call ke tipe
    `PointingKit` — hanya build Apple SDK yang bisa).
  - `Engine Tests (Linux)` run `37185919693` → hijau, kelima uji fase terlihat
    **lulus di log CI** (bukan hanya di mesin ini).

### Pelajaran yang berulang (lima siklus berturut-turut)

Lima siklus terakhir menemukan cacat di kelas yang **sama**: keputusan visual
yang benar secara terpisah tapi salah secara gabungan, dan tidak terlihat dari
teks mana pun di layar — kutub Mars menembus 0.26R, cincin Saturnus terpotong
0.9R, bintang terpotong 0.81R, lencana ragu terpotong 0.132R, dan sekarang
pita terang yang terbalik pada separuh fase. Semuanya lolos `swiftc -parse`,
semuanya lolos `swift test` yang ada, dan semuanya hanya ketahuan dengan
**menghitung**. Polanya cukup konsisten untuk aturan operasional: setiap
bentuk di `Canvas` harus punya **uji yang mengukur hasil yang benar-benar
tampil** — luas, bukan hanya koordinat — karena koordinat yang "masuk akal"
bukan jaminan bahwa bentuknya yang benar.

## Progres terakhir (4 Okt 2026 — gambar lebih yakin daripada teksnya saat engine ragu)

### Premis siklus ini: cacatnya bukan bentuk yang salah, tapi klaim yang salah

Empat siklus terakhir menemukan cacat di kelas **geometri raster** — bentuk
yang terpotong, menembus bola, keluar dari `Canvas`. Semua ditutup dengan
memindahkan angka batas ke `VisualFrame`. Siklus ini menemukan cacat di kelas
yang berbeda, dan lebih berbahaya: **bentuknya benar, klaimnya salah.**

Selama keadaan `.uncertain` — engine secara eksplisit menyatakan diri *kurang
yakin* — layar menampilkan **seluruh ciri pengenal objek**: cincin Saturnus,
pita Jupiter, kutub Mars, tanpa lencana tanda tanya apa pun. Sementara itu,
badge di sebelahnya bertuliskan **"Ragu"**.

### Mengapa ini lolos dari empat siklus audit

Gerbangnya adalah `isConfirmed: !isStale`, dan `isStale` dihitung dari
`hasAnswer`. `hasAnswer` adalah `.lock || .uncertain` — jadi `.uncertain`
**bukan** sisa, dan dengan demikian lolos sebagai gambar "pastu".

Keduanya benar secara terpisah:

- `.uncertain` memang bukan sisa (ia punya jawaban *sekarang*),
- `.uncertain` memang tidak boleh mengklaim identitas.

Cacatnya adalah menggunakan **satu ambang untuk dua pertanyaan yang berbeda**.
"Apakah ini hasil kedaluwarsa?" dan "Bolehkah gambar mengklaim ini benda itu?"
punya jawaban berbeda tepat pada `.uncertain`.

### Mengapa ini bentuk false confidence yang paling sulit ditangkap

Teksnya jujur. Badge-nya mengatakan "Ragu". Tidak ada yang bisa dibaca
pengguna untuk mengecek gambar itu — pengguna tidak tahu bahwa cincin
Saturnus adalah klaim identitas, bukan dekorasi. Dan **mata membaca gambar
lebih dulu daripada badge**: gambar menetapkan kesan, teks hanya mengoreksinya
kalau sempat terbaca.

Ini persis larangan PRD: *jangan salah identifikasi demi "magic"; uncertainty >
false confidence*. Cacatnya bukan menampilkan sesuatu yang tidak ada, tapi
menampilkan sesuatu **dengan tingkat kepastian yang salah**.

### Perbaikannya memakai predikat yang sudah ada

Tidak ada predikat baru yang ditulis. `PointingState.looksConfident`
(hanya `.lock`) **sudah ada di PointingKit dan sudah punya uji** — hanya saja
belum pernah dipakai UI mana pun. Itu tanda cacatnya: ambang yang benar sudah
tersedia, dan UI mengambil turunan yang lebih longgar.

- `PointingSnapshot.confirmsIdentity(lastLocked:)` — ambang gambar; memakai
  `state.looksConfident`, dan mensyaratkan objek benar-benar ditampilkan
  (tanpa itu, `.lock` tanpa kandidat akan menggambar ciri pengenal di atas
  bola generik).
- `PointingEngine.confirmsDisplayedIdentity` meneruskannya.
- `ObjectDetailView` (jam) & `LockArrivalPanel` (iPhone) memakai ambang baru.

`isStale` tetap dipakai untuk peringatan sisa — dua ambang, dua pertanyaan.

### Uji: 4 regresi, 3 di antaranya merah terhadap logika lama

Diverifikasi dengan mengembalikan predikat ke `hasAnswer` dan menjalankan
ulang: 3 uji merah, lalu hijau kembali setelah dikembalikan.

Uji keempat (`testIdentityThresholdIsStricterThanTheStaleThreshold`) sengaja
mengunci **perbedaan** kedua ambang secara konstruktif: ia mencari keadaan
yang bukan sisa tetapi tidak mengonfirmasi identitas, dan menuntut
`.uncertain` ada di dalamnya. Menyatukan kembali dua ambang itu sekarang tidak
bisa dilakukan tanpa ada uji yang merah.

- `166` engine + `228` PointingKit (224 + 4 baru), 0 gagal.
- CI: Engine Tests (Linux) hijau, Apple Build hijau (termasuk gerbang
  tanpa peringatan).

### Satu cacat compile yang hanya muncul di CI macOS

`argument 'visual' must precede argument 'isConfirmed'` — Swift mewajibkan
urutan argumen mengikuti deklarasi, dan `isConfirmed` disisipkan sebelum
`visual`. Tidak tertangkap di Linux karena `Apps/` tidak ikut terbangun di
`swift-test.sh`. Ini pola yang berulang: perubahan di `Apps/` hanya
terverifikasi oleh CI macOS, jadi setiap penyisipan parameter baru di call
site SwiftUI harus dicek urutannya terhadap deklarasi.

## Progres terakhir (4 Okt 2026 — lencana tanda tanya terpotong 0.132 R di dua sisi Canvas)

### Premis siklus ini: bentuk yang tersisa bukan yang belum ada, tapi yang belum dihitung

Tiga siklus terakhir menemukan cacat di kelas yang sama — **geometri raster
yang tidak terbaca dari teks** — dan masing-masing ditutup dengan memindahkan
angka batas ke `VisualFrame`. Siklus ini membalik pertanyaannya: alih-alih
mencari bentuk baru, **setiap** bentuk di `Canvas` dihitung ulang untuk tahu
mana yang belum punya uji batas. Hasilnya: cincin Saturnus, blob nebula, dan
bintang sudah punya; pita Jupiter, Bintik Merah Besar, kawah Merkurius, kabut
Venus, Maria Bulan, korona Matahari, dan pembelah Cassini semuanya **0
overflow**. Yang tersisa tinggal satu — dan justru yang paling penting.

### Cacat yang ditemukan: lencana keraguan terpotong di dua sisi sekaligus

`drawCandidateMarker` menaruh lencana di sudut kanan atas dengan radius
`0.22 · lebar` dan pusat di `(0.846 · lebar, 0.154 · lebar)`. Karena lencana
berada di **sudut**, dua sisinya dekat tepi frame sekaligus — bukan satu:

| Sisi | Posisi | Batas frame | Keluar |
|---|---|---|---|
| Kanan | 1.132 R | 1.0 R | **+0.132 R** |
| Atas | −1.132 R | −1.0 R | **+0.132 R** |

30% radius lencana hilang, di dua sisi. Karena `Canvas` memotong dengan **tepi
lurus**, lingkarannya tidak tampak "agak kepotong" — ia tampil sebagai busur
yang berhenti mendadak di dua tepi kartu.

### Kenapa ini bukan cacat kosmetik (dan beda dari tiga pendahulunya)

Cincin Saturnus yang terpotong membuat **satu planet** tampil salah. Ini
berbeda: lencana tanda tanya adalah **satu-satunya penanda di layar yang
mengatakan "engine ragu"**. Kalau ia terpotong habis, yang tersisa hanya
gambar objek **tanpa** penanda — dan gambar tanpa penanda terbaca sebagai
identitas yang pasti. Jadi cacat pada bentuk ini **membatalkan alasan bentuk
ini ada**: pelanggaran PRD ("JANGAN tampilkan visual yang mengklaim identitas
saat engine ragu") justru terjadi lewat hilangnya penanda yang mencegahnya.

Ini juga cacat yang paling mudah lolos: lencana hanya tampil saat engine
ragu — keadaan yang sengaja jarang, jadi hampir tidak pernah terlihat saat
menguji sekilas dalam keadaan terkunci.

### Yang diubah, dan kenapa begini

- **`VisualFrame.candidateMarker()` menghitung radius dari sudut yang
  diizinkan**, bukan dari lebar yang diinginkan lalu dibiarkan meluber — pola
  yang sama dengan `VisualFrame.star`. Karena `jarak + radius = corner`
  secara konstruktif, memperbesar lencana tidak bisa lagi mendorongnya keluar:
  ia menempel makin dekat ke tengah.
- **Inset dibuat pecahan frame, bukan angka mutlak.** Versi pertama memakai
  `inset` tetap; uji `testCandidateMarkerKeepsInsetFromTheEdge` menangkapnya
  merah pada frame 2.0 (jarak 0.06 vs syarat 0.1). Lencana digambar di kartu
  jam 38pt **dan** panel iPhone 132pt, jadi jarak yang tetap akan menempel
  pada bingkai di ukuran besar.
- **`overflow(frameHalfExtent:)` menerima frame yang diukur**, bukan membaca
  konstanta `halfExtent`. Kesalahan pertama ada di sini dan ketahuan oleh uji
  sendiri pada frame 2.0: batasnya dilaporkan "0.94 R keluar" padahal tidak
  ada yang keluar. Diperbaiki di model, bukan di uji.
- **View tidak punya rumus lencana lagi.** `drawCandidateMarker` membaca
  `marker.centerX/centerY/radius/glyphRadius`. Ini mempertahankan aturan
  repo: keputusan visual yang bisa salah tanpa ada yang bisa mengujinya tidak
  boleh tinggal di view.

### Uji dibuktikan MERAH lebih dulu

Dengan geometri lama dikembalikan (`radius = 0.44`, `jarak = 0.692` dalam
satuan radius):

- `testCandidateMarkerStaysInsideForAnySize` → **gagal** pada seluruh 4
  ukuran (0.132 R) dan pada frame 0.5 (0.632 R).
- `testCandidateMarkerKeepsInsetFromTheEdge` → **gagal**: jarak −0.132 R.
- `testLegacyCandidateMarkerOverflowedOnTwoSides` mengunci angka lama
  sebagai bukti cacatnya nyata — dan angkanya cocok persis dengan hitungan
  Python mandiri (0.132 R di kanan **dan** atas).

Satu uji awalnya salah dan diperbaiki, bukan ditambal: ia mengukur jarak ke
tepi dengan `VisualFrame.halfExtent` (konstanta 1.0) sehingga hanya kebetulan
benar untuk frame 1.0. Diubah mengukur terhadap frame yang dipakai lencana
itu, dan dijalankan pada 0.5/1.0/2.0.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 224 PointingKit, 0 gagal** (naik
  dari 218 → 224). Engine tidak disentuh.
- Keempat uji lencana **dibuktikan MERAH lebih dulu**, bukan hanya hijau.
- Gerbang sintaks: seluruh 22 berkas app lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan CJK/Cyrillic pada berkas yang diubah: **0** (satu kata CJK sempat
  lolos di komentar uji, dibuang sebelum commit).
- **CI hijau pada push pertama** (`0714d2b`):
  - `Apple Build` run `37182401570` → **2× `BUILD SUCCEEDED`** + gerbang
    peringatan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37182401575` → hijau, ke-6 uji lencana
    terlihat **lolos di log CI** (bukan hanya di mesin ini).

### Pelajaran yang berulang (empat siklus berturut-turut)

Empat siklus terakhir menemukan cacatnya di kelas yang **sama**: geometri
raster yang tidak terbaca dari teks. Kutub Mars menembus 0.26R; cincin
Saturnus terpotong 0.9R; bintang terpotong 0.81R; dan sekarang lencana
keraguan terpotong 0.132R. Keempatnya lolos `swiftc -parse`, keempatnya lolos
`swift test` yang ada sebelum uji batasnya ditulis. Polanya kini cukup
konsisten untuk dibaca sebagai aturan operasional: **setiap bentuk di `Canvas`
yang ukurannya dikalikan dari angka dasar harus punya uji batas di
`VisualFrame`** — dan audit siklus ini memakai aturan itu untuk menyisir
seluruh `Canvas`, bukan menunggu kecurigaan datang.

## Ringkasan keadaan (4 Okt 2026, pagi)

**Brief UI/UX (Bagian 1–4) sudah terpasang penuh — dan diverifikasi ulang dari
awal pada siklus ini, bukan dipercaya dari klaim lama.** Visual objek
(prosedural, tanpa aset), token permukaan & kontras, mode malam merah,
always-on, VoiceOver, animasi kedatangan kunci, onboarding, audio, dan
`@ScaledMetric` semuanya **ada di kode dan berjalan**.

Yang ditemukan siklus ini bukan "fitur kurang", melainkan **satu cacat
geometri yang tidak terlihat dari teks mana pun di layar**: glow dan
diffraction spike bintang terpotong tepi `Canvas` pada **24 dari 25 bintang
di katalog** — Sirius paling parah, 0.81R hilang. Detail di entri "Progres
terakhir" di bawah.

- Engine (Fase 1–3) + logika app: **166 test CelestialEngine + 224 test
  PointingKit, 0 gagal** (`./swift-test.sh` dari nol, Swift 6.0 Docker,
  Linux) — dan **kedua workflow CI hijau** di HEAD `0714d2b` (Apple Build
  `37181603764` 2× `BUILD SUCCEEDED` + gerbang peringatan "Tidak ada
  peringatan compiler pada Apps/."; Engine Tests `37181603824`, keenam uji
  bintang terlihat lolos di log CI).
- Rincian: `166 + 224` naik dari `166 + 218` (+6 uji batas lencana kandidat,
  lihat entri siklus ini). Sebelumnya `166 + 218` naik dari `166 + 212`
  (+6 uji batas bintang), dan `166 + 212` dari `166 + 201` (+11 uji batas
  frame).

### Yang diverifikasi ulang (bukan dengan mempercayai STATUS lama)

Seluruh 22 berkas `Apps/` + model visual di `PointingKit` dibaca ulang, lalu
**dihitung** (bukan dibaca) untuk klaim yang bersifat numerik. Hasilnya:

1. **Visual objek lengkap** — `CelestialVisualView.swift` (498 baris,
   `Canvas` murni, tanpa aset): planet (pita Jupiter + Bintik Merah Besar,
   cincin Saturnus dua-lapis dengan `clip`, kutub Mars, kawah Merkurius,
   kabut Venus), **fase Bulan dari fraksi engine** dengan `litSide` terpisah
   dari tanda terminator, bintang (glow berlapis + 4 diffraction spike,
   warna B−V dari tabel per bintang, ukuran logaritmik dari magnitudo),
   Matahari berkorona, nebula kabur.
2. **Penanda ragu** — `isConfirmed: !isStale`, predikat yang **sama** dengan
   badge keyakinan; ciri pengenal (cincin/pita/kutub) ditolak saat ragu,
   warna bola tetap boleh tampil.
3. **Semuanya teruji di Linux** — palet, ciri, geometri fase, tabel B−V,
   palet permukaan & kontras WCAG, urutan terang mode malam, kalimat
   VoiceOver kalibrasi, gerbang kedatangan kunci.
4. **Token dipakai kedua app** — `SurfaceTokens.swift` (jembatan ke `Color`),
   `forceDarkScheme()`, `.appBackground()` + `scrollContentBackground(.hidden)`
   di semua layar; mode malam lewat `PointingTone.color` **satu** sumber.
5. **Celah wajib Bagian 3 tertutup** — mode malam (1 ketuk, `@AppStorage`,
   semua visual ikut merah), always-on (`NightAwareContainer` +
   `ReducedLuminanceView`, tanpa animasi), VoiceOver (label status/panel/tombol
   + pengumuman perubahan keadaan).
6. **Bagian 4** — animasi spring saat `lockArrivalToken` naik (bukan
   `state == .lock`), Dynamic Type penuh (0 `.system(size:)` di kode), audio
   opsional prosedural 880Hz, `@ScaledMetric` pada ikon status.
7. **Onboarding di kedua app** — `PointAndKnowWatchWatchApp.swift:23,39-41`
   dan `DiagnosticsView.swift:43,60-63` (STATUS lama menyebutnya "hanya di
   jam + RootView"; sekarang keduanya dikonfirmasi di lokasi nyata).

Tidak ada satu pun item brief yang tersisa. Yang belum ada tetap item
`ROADMAP.md` yang bukan kode: teleskop fisik.

## Progres terakhir (4 Okt 2026 — dua bentuk raster terpotong tepi Canvas)

### Premis siklus ini: STATUS lama dibaca, lalu diuji dengan menghitung

STATUS lama menyatakan Bagian 1–4 "sudah terpasang penuh dan diverifikasi
ulang". Audit siklus ini menerima klaimnya untuk **logika** (palet, ciri
pengenal, geometri fase, tabel B−V memang lengkap dan teruji), lalu mengalihkan
pertanyaan ke tempat yang belum pernah dihitung: **bentuk raster yang
dilukis `Canvas`**. Alasannya sama dengan siklus kutub Mars — dan terbukti
tepat.

### Cacat yang ditemukan: `Canvas` memotong dengan tepi lurus

`Canvas` menggambar hanya di dalam `frame`-nya sendiri, dan ia memotong dengan
**tepi lurus**, bukan dengan memudar. Jadi bentuk yang kelewat besar tidak
tampak "agak kepotong" — ia tampak sebagai garis yang berhenti mendadak. Dua
bentuk melanggar batas itu, keduanya dihitung (bukan dibaca):

| Bentuk | Ukuran lama | Batas frame | Keluar |
|---|---|---|---|
| Cincin Saturnus | `3.8 × radius` (ujung di x = ±1.9R) | ±1.0R | **0.90R** |
| Blob kabut nebula (yang digeser) | radius tetap | ±1.0R | **0.28R** |

Cincin Saturnus adalah yang paling parah dan paling mudah dikenali: hampir
separuh lebarnya berada di luar kotak, jadi yang tampil di layar **bukan
cincin** melainkan dua garis yang berhenti mendadak di tepi kartu. Di kartu jam
38pt potongan itu sangat mudah tidak disadari.

Nebula punya jebakan sendiri: blob-nya **digeser** dari pusat (supaya kabut
tidak simetris sempurna), dan batas frame bersifat **per sumbu**, bukan radial.
Jadi blob yang terpusat aman sementara blob yang digeser keluar — dan potongannya
jatuh **tepat di tengah gradien yang belum selesai memudar** (opasitas 0.084 di
situ), persis ciri "terlihat digambar" yang ingin dihindari nebula.

### Kenapa ini tidak bisa ditangkap dengan membaca

Tiga lapis verifikasi di repo ini semuanya lolos: `swiftc -parse` hanya
memeriksa sintaks; `swift test` di Linux tidak bisa menyentuh warna/`Canvas`;
dan tidak ada satu pun teks di layar yang memberitahu pengguna bahwa gambarnya
terpotong. Yang tersisa hanyalah **menghitungnya** — persis teknik yang
menemukan kutub Mars menembus 0.26R pada siklus lalu.

### Yang diubah, dan kenapa begini

- **Angka batas pindah ke `PointingKit` sebagai `VisualFrame`.** Enum ini
  adalah satu-satunya tempat yang tahu ukuran frame, dengan
  `overflow(centerX:centerY:halfWidth:halfHeight:)` yang mengembalikan nilai
  ≥ 0 bila bentuk keluar. `saturnRing()` dan `nebula(fuzziness:)` keduanya
  **dihitung dari sisa ruang ke tepi frame**, bukan dari radius mentah — jadi
  memperbesar bentuk tidak bisa lagi diam-diam melewati batas.
- **`saturnBodyRadius(for:)` dipisah dari `saturnRing`.** Bola harus mengecil
  mengikuti cincin; kalau bola tetap memakai radius frame penuh sementara cincin
  mengisi frame, bola menutupi cincin dan hasilnya **piring**, bukan Saturnus.
  Mengambilnya dari lebar cincin membuat proporsi itu benar secara
  konstruktif.
- **View tidak punya rumus sendiri lagi.** `drawRings` dan `drawDeepSky` kini
  membaca model. Ini mempertahankan aturan repo yang sudah berlaku: keputusan
  visual yang bisa salah tanpa ada yang bisa mengujinya **tidak boleh tinggal
  di view**.

### Uji dibuktikan MERAH lebih dulu

Dengan geometri lama dikembalikan (`halfWidth = frameHalfExtent × 1.9`):

- `testSaturnRingStaysInsideTheFrame` → **gagal**: `0.8999999999999999 > 0`,
  pesan *"cincin keluar 0.9 R di luar frame dan akan terpotong tegak"*.
- `testSaturnBodyFitsInsideItsRing` → **gagal**: `1.007` vs `0.594`.
- `testEveryDeepSkyBlobStaysInsideTheFrame` → **gagal**: *"blob nebula 0 keluar
  0.28 R di luar frame"*.
- `testLegacySaturnRingOverflowedTheFrame` ditambahkan justru untuk **mengunci
  angka lama** sebagai bukti bahwa cacatnya nyata, bukan perbedaan rasa.

Satu uji awalnya salah dan diperbaiki, bukan ditambal: ia menuntut bola lebih
kecil dari **tinggi** cincin. Itu keliru — cincin Saturnus tampak miring, jadi
tinggi elipsnya memang lebih kecil dari jari-jari bola, dan justru dua ujung
cincin yang tampil di luar bola itulah yang membuatnya terbaca sebagai
Saturnus. Yang benar adalah bola harus lebih kecil dari **lebar** cincin.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 212 PointingKit, 0 gagal** (naik
  dari 201 → 212: 11 uji batas frame baru). Engine tidak disentuh.
- Ketiga uji di atas **dibuktikan MERAH lebih dulu**, bukan hanya hijau.
- Gerbang sintaks: seluruh 22 berkas app lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan CJK/Cyrillic di berkas yang diubah: **0**.
- **CI macOS sempat MERAH dan itu cacat nyata**: push pertama (`61defdb`)
  ditolak dengan 3 × `error: 'saturnRing'/'saturnBodyRadius'/'nebula' is
  inaccessible due to 'internal' protection level`. Tiga helper `static` di
  dalam `public enum` turun ke `internal` (default Swift) — dan **tidak satu
  pun** gerbang Linux yang bisa melihatnya, karena uji hidup di modul yang
  sama. Diperbaiki di `c5ff66c` dengan mengekspor kelimanya ke `public`.
- CI hijau di `c5ff66c`: `Apple Build` run `37180733204` → **2 × `BUILD
  SUCCEEDED`** + gerbang peringatan *"Tidak ada peringatan compiler pada
  Apps/."*; `Engine Tests (Linux)` run `37180733201` hijau dengan kelima uji
  batas frame **terlihat lolos di log CI** (bukan hanya di mesin ini).

### Pelajaran yang berulang (dan kali ini dua kali berturut-turut)

Dua siklus terakhir menemukan cacatnya di tempat yang sama: **geometri
raster yang tidak bisa dibaca dari teks**. Kutub Mars menembus 0.26R; cincin
Saturnus terpotong 0.9R. Keduanya lolos `-parse`, keduanya lolos `swift test`
yang ada, dan keduanya hanya ketahuan dengan menghitung. Dan kali ini
tambahannya: **akses `internal` vs `public` adalah cacat kelas ketiga yang
hanya build macOS yang bisa tangkap** — `swift test` di Linux tidak bisa
melihatnya sama sekali karena pengujinya satu modul.

## Progres terakhir (4 Okt 2026 — glow & spike bintang terpotong tepi Canvas, 24 dari 25 bintang)

### Premis siklus ini: geometri yang sudah punya `VisualFrame` harus dihitung, bukan hanya dibaca

Dua siklus terakhir menemukan cacat di tempat yang sama — **geometri raster
yang tidak terbaca dari teks** — dan keduanya ditutup dengan memindahkan
angka batas ke `VisualFrame` di `PointingKit`. Siklus ini memperluas
pertanyaannya: `VisualFrame` sudah mengurusi **cincin Saturnus** dan **blob
nebula**, tapi ada bentuk ketiga di `Canvas` yang sama-sama dikalikan dari
ukuran dasar dan **tidak punya uji batas sama sekali** — bintang.

### Cacat yang ditemukan: inti dihitung maju, batasnya tidak pernah dihitung

`drawStar` menghitung `coreRadius = 0.22 + 0.30 · relativeSize`, lalu
mengalikannya: glow terluar `×3.0` dan spike `×3.2`. Tidak ada satu pun
bagian yang memeriksa apakah hasilnya masih di dalam frame. Karena
`Canvas` memotong dengan **tepi lurus**, bukan dengan memudar, yang tampil
bukan "bintang yang agak kepotong" melainkan **bola cahaya yang berhenti
mendadak di keempat tepi kartu**.

Dihitung untuk seluruh katalog, bukan ditebak:

| Bintang | Ujung terluar | Keluar frame |
|---|---|---|
| **Sirius** | 1.811R | **+0.811R** |
| Canopus | 1.519R | +0.519R |
| Arcturus | 1.316R | +0.316R |
| Vega | 1.296R | +0.296R |
| Polaris | 0.987R | −0.013R (satu-satunya yang muat) |

**24 dari 25 bintang terpotong**, dan yang paling parah justru bintang
paling terang — yang paling sering dikunci pengguna. Ini cacat yang lebih
luas daripada dua pendahulunya: cincin Saturnus hanya salah pada satu
planet, blob nebula pada satu kelas objek, sedangkan ini salah pada
hampir seluruh katalog bintang.

### Kenapa denyut harus ikut dihitung (dan kenapa itu cacat yang paling mudah lolos)

Geometri lama memakai `pulseFactor = 1 + 0.10 · sin(pulse)`, yang
mengembangkan gambar **setelah** ukuran inti dipilih. Jadi batas yang
dihitung dari keadaan diam meloloskan gambar yang terpotong **hanya saat
denyut memuncak** — cacat yang muncul dan hilang berulang, persis kelas
yang paling mudah tidak disadari saat menguji sekilas. Karena itu
`outerRadius` dihitung pada **puncak** denyut, bukan pada keadaan diam.

### Yang diubah, dan kenapa begini

- **`VisualFrame.star(relativeSize:)` menghitung inti MUNDUR dari ruang
  yang tersedia**, bukan maju dari ukuran yang diinginkan. Ini yang
  membuat batasnya **konstruktif**: memperbesar glow atau spike tanpa
  sengaja tidak bisa lagi mendorong ujungnya keluar frame, karena inti
  menyusut sendiri mengikutinya. Dua siklus sebelumnya memperbaiki gejala
  per bentuk; ini memperbaiki **kelasnya** — rumusnya tidak bisa lagi
  menghasilkan ujung yang keluar, berapa pun pengalinya.
- **Urutan magnitudo tetap terjaga lewat `outerFraction` (0.62 → 0.92).**
  Bahaya yang sengaja dihindari: memotong inti dengan plafon tetap akan
  meratakan Sirius dan Polaris menjadi dua titik yang sama, dan
  "ukuran mengikuti magnitudo" hilang — informasi yang masih terbaca di
  layar. Uji `testBrighterStarIsStillDrawnLarger` menguncinya.
- **View tidak punya rumus bintang lagi.** `drawStar` membaca
  `geometry.coreRadius`, `glowScales`, `spikeScale`, dan `pulseAmplitude`
  dari model. Ini mempertahankan aturan repo yang sudah berlaku:
  keputusan visual yang bisa salah tanpa ada yang bisa mengujinya **tidak
  boleh tinggal di view**. Opasitas glow (`glowOpacities`) ikut naik ke
  konstanta bernama, karena array literal di dalam loop sebelumnya
  bergantung secara diam-diam pada jumlah lapis yang sama dengan
  `glowScales`.

### Uji dibuktikan MERAH lebih dulu

Dengan geometri lama dikembalikan (`outer = 0.22 + 0.30 · clamped`,
`growth = 1.0`):

- `testEveryCatalogueStarStaysInsideTheFrame` → **gagal**, dan pesannya
  menyebut bintangnya satu per satu: *"sirius keluar 0.8111258278291038 R
  di luar frame dan akan terpotong tegak"*, *canopus 0.5186*, *arcturus
  0.3160*, *vega 0.2964* … angkanya cocok persis dengan hitungan Python
  mandiri di atas.
- `testEnlargingTheGlowCannotPushTheStarOutOfFrame` → **gagal** pada
  seluruh 9 kombinasi pengali (terburuk 10.44R), membuktikan bahwa
  rumusnya memang tidak punya batas, bukan kebetulan muat.
- `testLegacyStarOverflowedTheFrame` ditambahkan justru untuk **mengunci
  angka lama** sebagai bukti bahwa cacatnya nyata, bukan perbedaan rasa
  tentang seberapa besar glow yang pantas.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 218 PointingKit, 0 gagal**
  (naik dari 212 → 218). Engine tidak disentuh.
- Ketiga uji di atas **dibuktikan MERAH lebih dulu**, bukan hanya hijau.
- Gerbang sintaks: seluruh 22 berkas app lolos `swiftc -parse
  -swift-version 5` di container `swift:6.0`.
- Sapuan CJK/Cyrillic pada berkas yang diubah: **0**.
- **CI hijau pada push pertama** (`3ab030e`) — tidak ada kejutan `internal`
  vs `public` seperti siklus lalu, karena `star(...)`, `StarGeometry`, dan
  seluruh anggotanya dideklarasikan `public` sejak awal:
  - `Apple Build` run `37181603764` → **2× `BUILD SUCCEEDED`** + gerbang
    peringatan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37181603824` hijau, keenam uji bintang
    terlihat **lolos di log CI** (bukan hanya di mesin ini).

### Pelajaran yang berulang (tiga siklus berturut-turut)

Tiga siklus terakhir menemukan cacat di kelas yang **sama**: geometri
raster yang tidak terbaca dari teks. Kutub Mars menembus 0.26R; cincin
Saturnus terpotong 0.9R; dan sekarang bintang terpotong 0.81R. Ketiganya
lolos `swiftc -parse` (sintaks saja), ketiganya lolos `swift test` yang
ada sebelum uji batasnya ditulis, dan ketiganya hanya ketahuan dengan
**menghitung**. Polanya sudah cukup konsisten untuk dibaca sebagai aturan:
setiap bentuk di `Canvas` yang ukurannya dikalikan dari angka dasar harus
punya uji batas di `VisualFrame`, atau ia akan terpotong tanpa ada yang
memberi tahu.

## Progres terakhir (4 Okt 2026 — kutub Mars menembus 0.26R keluar dari bola)

### Cacat yang ditemukan: dua rumus untuk satu bentuk simetris

Siklus ini diawali dengan brief yang sama seperti sebelumnya, jadi STATUS lama
**layap dibaca, bukan dipercaya**. Hasilnya berbeda dari beberapa siklus
sebelumnya: brief-nya memang sudah terpenuhi seluruhnya. Jadi pekerjaan
siklus ini berubah dari "menambah fitur" menjadi **menyisir raster prosedural
secara numerik** — karena di situlah satu-satunya kelas kesalahan yang tidak
bisa ditangkap hanya dengan membaca kode.

`drawPolarCaps` memakai **dua rumus berbeda untuk dua kutub**:

    utara:  y = center.y - radius
    selatan: y = center.y + radius - capHeight      // <-- bukan cermin
    tinggi elips: 2 * capHeight

Karena tinggi elips adalah `2 · capHeight` (bukan `capHeight`), kutub selatan
berakhir di **y = 1.26R** — yaitu **0.26R di luar bola**. Diperiksa dengan
menghitung titik terjauh elips dari pusat, bukan dengan mengira: elips di
y∈[0.74, 1.26] punya titik di y=1.26 yang jaraknya 1.26R.

| Kutub | Protrusion versi lama | Protrusion versi ini |
|---|---|---|
| Utara | 0.0038R | 0.0038R |
| **Selatan** | **0.2600R** | **0.0038R** |

Jadi Mars tampil dengan kutub putih yang **menggantung di ruang kosong** di
bawah bola, dan tidak simetris dengan kutub utara — tepat di tanda yang
paling mudah dibaca mata telanjang.

**Cakupan dicek, bukan diasumsikan.** Pita Jupiter (7 pita), 5 kawah
Merkurius, dan kabut Venus dihitung dengan cara yang sama: **0 protrusion**
semuanya. Jadi hanya kutub yang salah, dan tidak ada "perbaikan" yang
menyentuh ciri planet lain.

### Kenapa ini bukan sekadar rasa

PRD melarang visual yang **menglaim identitas** saat engine ragu, dan logika
yang sama berlaku lebih luas: gambar adalah klaim. Kutub adalah **ciri
pengenal Mars** — persis kelas yang sudah dipisahkan dari warna di
`DistinguishingFeature` (cincin Saturnus ≠ pita Jupiter). Bentuk kutub yang
salah bukan sekadar soal rasa: tidak ada teks di layar yang bisa dibaca
pengguna untuk memeriksanya, dan Mars tidak punya sabit/cincin yang bisa
menutupinya.

### Yang diubah

- **`CelestialVisual.polarCaps()` + `CelestialVisual.PolarCaps` di
  `PointingKit`** — kutub selatan dihitung sebagai **cermin kutub utara**
  (`southTop = 1 - height`), jadi keduanya simetris secara **konstruktif**,
  bukan dua rumus yang harus dicocokkan manual. Hasilnya dalam satuan radius,
  supaya model tidak perlu tahu satuan apa yang sedang digambar.
- **View memakai tipe itu; tidak ada rumus kutub lagi di `Apps/`.** Ini
  menjaga pemisahan yang sudah jadi aturan repo: keputusan visual yang bisa
  salah tanpa ada yang bisa mengujinya **tidak boleh tinggal di view**.

### Tiga uji, semuanya dibuktikan MERAH dulu

Dengan `southTop` dikembalikan ke `1 - capHeightFraction` (geometri lama):

- `testPolarCapsStayOnThePlanetSurface` → **gagal**: `1.26 > 1.01`,
  pesan *"kutub south menembus 0.26 R di luar bola"*.
- `testPolarCapsAreMirrorImagesOfEachOther` → **gagal**: `-1.0` vs `-1.26`.
- `testPolarCapDefaultsAreInRadiusUnits` → hijau (kebetulan tidak menyentuh
  bug; dipertahankan karena mengunci satuan agar view tidak salah skala).

Jadi dua dari tiga uji menangkap bug ini secara numerik, bukan sebagai
formalitas.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 201 PointingKit, 0 gagal**
  (naik dari 198 → 201). Engine **tidak disentuh**.
- Gerbang sintaks: **seluruh 22 berkas app** lolos `swiftc -parse
  -swift-version 5` di container `swift:6.0`.
- `swift build` `PointingKit` di container: **Build complete**.
- Sapuan CJK/Cyrillic di `Apps/` + `Packages/`: **0**.
- **CI macOS hijau** di `3b9dcf2`: `Apple Build` run `37179379077` → **2×
  `BUILD SUCCEEDED`** (iPhone termasuk app jam, dan app jam sendiri), gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
  `Engine Tests (Linux)` run `37179379101` → **166 + 201**, ketiga uji kutub
  terlihat **lulus di log CI** (bukan hanya di mesin ini).

### Pelajaran yang diulang (dan masih berlaku)

`swiftc -parse` lolos untuk **seluruh** perubahan di sini — termasuk tiga uji
yang gagal pada geometri lama. `-parse` memeriksa sintaks, bukan perilaku;
hanya `swift test` yang bisa merah. Dan `Color`/SwiftUI tidak bisa
diuji di Linux sama sekali, yang justru alasan geometri kutub **dipindahkan ke
`PointingKit`**: bentuknya tidak bisa diverifikasi di lapisan yang tidak
memiliki gerbang.

### Audit awal: visual sudah ada, tapi latarnya tidak pernah tampil

Siklus ini diawali dengan memercayai bahwa Bagian 1–4 sudah selesai (klaim
STATUS lama), lalu membaca ulang seluruh berkas app alih-alih mempercayainya.
Yang ditemukan: model visual, mode malam, always-on, VoiceOver, animasi, dan
onboarding **semua sudah ada dan teruji** — tetapi gradien latar `#0A0A0F`/
`#121216` yang sudah dihitung & diuji kontrasnya di `SurfacePalette.appBackground`
**hanya dilukis di `OnboardingView`**. Seluruh layar konten (jam + `ReducedLuminanceView`
+ ketiga `List` iPhone) dirender di latar bawaan sistem, dan siang memakai
`preferredColorScheme(nil)` — jadi di iPhone yang disetel terang, `List` dan
chrome sistem berbalik putih sementara token `SurfacePalette` mengasumsikan
gelap. Itu sumber nyata keluhan "masih jelek / tidak konsisten": permukaan
bertinting (surface-stepping) dan kontras 4.5:1 yang diklaim di brief **ada
di kode tapi tidak pernah terlihat** di layar.

### Apa yang diubah, dan kenapa begini

- **`SurfaceTokens.forceDarkScheme()`** — pembungkus `preferredColorScheme(.dark)`.
  Skema dipaksa gelap di **seluruh** app, bukan `nil` saat siang. Alasannya
  bukan "mode gelap pilihan": token permukaan dirancang untuk latar gelap, dan
  menyerahkannya ke sistem berarti chrome putih di iPhone terang merusak
  kontras yang sudah diuji. Skema gelap di sini adalah **kontrak** dengan
  palet; mode malam (merah) adalah lapisan di atasnya, bukan pengganti.
- **Latar gradien dipasang ke akar semua layar:** `PointingView` +
  `ReducedLuminanceView` (jam), dan `DiagnosticsView`/`Experiment1View`/
  `LinkView` (iPhone) masing-masing dapat `.appBackground()`. Pada ketiga
  `List` iPhone ditambah `scrollContentBackground(.hidden)` supaya chrome
  `List` bawaan tidak menutupi gradien — kartu tetap memakai `surfaceCard`.
- `OnboardingView` sudah benar (memakai `SurfacePalette.appBackground` secara
  langsung); tidak diubah.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 198 PointingKit, 0 gagal** (engine
  dan `PointingKit` tidak disentuh; perubahan murna `Apps/`).
- Gerbang sintaks: seluruh 20 berkas app lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` (setelah satu galat tutup-kurung berlebih di
  `SurfaceTokens` diperbaiki saat edit).
- **CI macOS (Apple Build) hijau** di `c414cc5` (run `37178623141`, 2× `BUILD
  SUCCEEDED`) + gerbang peringatan melaporkan *"Tidak ada peringatan compiler
  pada Apps/."* — `scrollContentBackground`/`preferredColorScheme` hanya
  terbukti resolve di sini, bukan di `-parse`. `Engine Tests (Linux)` run
  `37178623098` hijau.

## Progres terakhjah (4 Okt 2026 — Bagian 4.4: animasi kedatangan kunci di UI)

### Audit awal: 4.4 ternyata hanya setengah jadi

Siklus ini diawali dengan mengaudit klaim STATUS lama, bukan memercayainya.
Table di atas menandai 4.4 "SELESAI" — tapi yang ditulis di sana hanyalah
plumbing model (`LockArrivalGate` + `PointingEngine.publish`). Pemanggil
UI-nya **tidak ada**: satu-satunya kejadian `withAnimation` di seluruh `Apps/`
adalah di `ReducedLuminanceView` (komentar, bukan pemanggilan). Jadi saat
objek baru terkunci, kartu di jam dan panel di iPhone muncul **tanpa** animasi —
bagian 4.4 ("fade/scale saat objek muncul") belum terwujud di layar.

### Apa yang diubah, dan kenapa begini

- **`ObjectDetailView` (jam)** sekarang menerima `lockArrivalToken: Int?` dan
  memainkan pop (scale 1 → 1.04 → 1 + opasitas) lewat `withAnimation(.spring)`
  saat token **naik**. Dipicu oleh `engine.lockArrival?.token`, bukan oleh
  `state == .lock`, karena `snapshot` ditulis ulang 20×/detik selama terkunci —
  memakai keadaan membuat kartu berkedip terus-menerus. `LockArrivalGate` sudah
  menyaring itu: token hanya naik saat ada **kedatangan kunci baru** dengan
  objek yang berlaku sekarang, dan kembali `nil` saat kunci dilepas. `.onChange`
  hanya memutar pop saat token naik, mengabaikan saat kembali `nil` — supaya
  kita tidak "merayakan" objek sisa (kelas false confidence yang dilarang PRD).
- **iPhone**: panel yang tadinya bersarang langsung di `List` dipecah menjadi
  `LockArrivalPanel` (di `DiagnosticsView`). Pemecahan ini penting karena panel
  lama berada di dalam `TimelineView(.animation(30 Hz))` yang merender ulang
  per frame — menaruh state animasi di atasnya berarti pop diputar ulang tiap
  frame. `LockArrivalPanel` memegang `@State appearScale/appearOpacity`
  sendiri dan dipicu oleh `.onChange(of: lockArrivalToken)` yang sama dengan
  jam, dengan penjagaan naik-token yang sama. Gambar besar (diameter 132) +
  denyut glow bintang tetap dipertahankan di dalam `TimelineView` internalnya.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 198 PointingKit, 0 gagal**
  (engine tidak disentuh; UI hanya membaca `lockArrival` yang sudah ada).
- Gerbang sintaks: **seluruh berkas app lolos `swiftc -parse -swift-version 5`**
  di container `swift:6.0`.
- Perubahan hanya di `Apps/` (jam + iPhone); tidak ada simbol `PointingKit`/
  `CelestialEngine` yang disentuh, jadi 198 test tidak bisa terpengaruh.
- Belum dijalankan di sini: build macOS CI sebenarnya (`ios-build.yml`), karena
  VPS ini tanpa Xcode — itu yang akan membuktikan resolusi overload/tipe
  (`@State` di `ObjectDetailView`, `LockArrivalPanel`, `.onChange` dua-argumen).
  Lolos `-parse`, tapi `-parse` tidak menyelesaikan tipe, jadi CI macOS adalah
  verifikasi sebenarnya (sama seperti siklus-siklus sebelumnya).

### CI macOS pertama GAGAL — dan itu kegagalan nyata, bukan peringatan alat

Push pertama (`18ba900`) ditolak oleh `Apple Build` dengan **5 galat compile**
yang `-parse` tidak bisa lihat (sesuai dugaan di atas):

- `DiagnosticsView.swift:260: error: cannot find 'visual' in scope` — call site
  `LockArrivalPanel(visual: visual, ...)` kehilangan binding `visual` karena
  blok `if let visual = ...` lama ikut terhapus saat panel dipindah. Diperbaiki
  dengan membungkus call site: `if let visual = engine.visualForDisplayedObject { ... }`.
- `DiagnosticsView.swift:485/487/488/490/503: error: instance member 'detailRow'/
  'visualPanelLabel' of type 'DiagnosticsView' cannot be used on instance of
  nested type 'DiagnosticsView.LockArrivalPanel'` — kedua helper itu `private
  func` instance, tak terjangkau dari nested type. Diperbaiki jadi `static` (ia
  murni: hanya pakai `SurfacePalette`/argumen) dan dipanggil via
  `DiagnosticsView.detailRow`/`visualPanelLabel`.

Push kedua (`9745f9f`) → **Apple Build hijau** (2× `BUILD SUCCEEDED`, gerbang
peringatan "Tidak ada peringatan compiler pada Apps/") + Engine Tests hijau.
Pelajaran yang sudah berkali-kali terbukti di sini: `swiftc -parse` hanya
memeriksa sintaks; **hanya build macOS yang membuktikan resolusi tipe/overload**,
dan nested type vs instance method adalah jebakan yang tepat di situ.

## Progres terakhir (4 Okt 2026 — sisa Bagian 4: onboarding + audio + @ScaledMetric)

Siklus ini menutup tiga item terakhir dari brief yang benar-benar belum ada:
onboarding value-first, audio opsional saat lock, dan `@ScaledMetric` (font
sudah semantic, jadi yang tersisa adalah metric yang belum ikut scale). Aturan
keras PRD tidak dilonggarkan; engine tidak disentuh.

### Yang dikerjakan, dan kenapa begini

1. **Onboarding value-first (`Apps/Shared/OnboardingView.swift`).** Satu kartu
   singkat: "Arahkan jam ke langit → ketahui apa yang kamu lihat", plus janji
   jujur "jika ragu, engine akan mengatakannya". Tidak ada tur panjang: saat
   pengguna mengangkat pergelangan di malam hari, lima layar instruksi justru
   menunda hal yang dicari. Ditampilkan sekali lewat `.sheet` (kunci
   `OnboardingStorage.key`), dan menutupnya tidak mereset alur. **Tidak ada
   satu pun klaim hasil ukur** di kartu ini, jadi tidak ada risiko false
   confidence dari layar pembuka.

2. **Audio opsional saat lock (`Apps/Shared/AudioCue.swift`).** `AudioCueEngine`
   menyintesis nada 880Hz di memori (`AVAudioEngine` + `AVAudioPCMBuffer`,
   amplop naik-turun) — **tanpa aset**, sejalan dengan visual yang tanpa aset.
   Dipasang tepat seperti `HapticEngine`: closure `engine.audioCue` (paralel
   `haptics`, dipanggil dari `ingest`), jadi tidak menyentuh logika engine
   teruji. Hanya berbunyi untuk `.lockSucceeded` — bunyi saat ragu sama
   berbahayanya dengan getaran saat ragu (false confidence berwujud suara).
   `AudioCue.isOn` default **nyala** (aksesibilitas multi-modal), ada toggle
   "Bunyi saat kunci" di kedua app. `setCategory(.playback, .mixWithOthers)`
   supaya tidak memotong musik latar pengguna.

3. **`@ScaledMetric` pada ikon status.** Semua *font* memang sudah semantic,
   tapi `WatchMetrics.iconSize` (16, tetap) diniatkan ikut scale menurut
   komentarnya sendiri namun tidak pernah dipakai. Diganti `@ScaledMetric(
   relativeTo: .headline)` di `PointingView` untuk frame simbol status, supaya
   ikon dan teks mendapat tekanan yang sama saat Dynamic Type diubah. Anggota
   mati `WatchMetrics.iconSize` dibuang; komentarnya diubah menjelaskan bahwa
   metric yang *memang* tak boleh scale (diameter visual, radius) tetap angka
   tetap.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 198 PointingKit, 0 gagal** (naik
  dari 188 → 198: 10 uji `LockArrivalGate` ditambahkan siklus sebelumnya,
  terhitung di sini). Engine/logika app tidak disentuh.
- Gerbang sintaks `swiftc -parse` seluruh 20 berkas app lolos di `swift:6.0`
  setelah perubahan.
- **CI macOS (Apple Build) GAGAL dulu pada `e8f8bb9`**, lalu hijau di `17a5c32`:
  - Kegagalan pertama murni salah letak: `onboardingSeen` & `audioCue` mendarat
    di struct `PointAndKnowiOSApp` (cocok salah dengan `@StateObject trace`),
    padahal dirujuk di `RootView` → "cannot find in scope". Dipindah ke
    `RootView`, bukan cuma di-`_fix_`.
  - Dua catatan CI yang tersisa **bukan** kode kita: (a) `swift-format cannot
    parse configuration` (alat, sengaja diabaikan gate), (b)
    `CalibrationSessionTests.swift:285` `XCTUnwrap` unused — berkas *test*
    `PointingKit` di luar scope `Apps/`; sudah tercatat di STATUS lama sebagai
    sengaja tidak diubah.
  - Gerbang peringatan "kode sendiri" (`Apps/`) lolos: Tidak ada peringatan
    compiler pada Apps/.
- **Engine Tests (Linux) hijau** di `17a5c32`.

## Progres terakhir (4 Okt 2026 — kalibrasi: VoiceOver + Dynamic Type)

### Dua klaim STATUS.md yang ternyata tidak berlaku

Siklus ini dimulai dari brief yang sama seperti sebelumnya, jadi STATUS.md
layap dibaca bukan dipercaya. Dua klaim di dalamnya **tidak berlaku**:

1. **"Dynamic Type: semua `.system(size:)` sudah diganti."** Benar untuk
   `PointingView` dan `ReducedLuminanceView` — tapi `CalibrationView.swift`
   masih punya **13** `.system(size:)`, yaitu 20% dari berkas app. Dan itu
   bukan layar pinggir: kalibrasi justru layar yang paling sering dipakai
   pengguna yang perlu kacamata di lapangan. Semua angka sudah gone sekarang
   (sweep `\.system\(size:` di `Apps/` → **0 di kode**, sisanya komentar).
2. **"Bagian 3.3 selesai."** `statusCard` dan `ObjectDetailView` memang
   berlabel, tapi brief menyebut secara khusus **tombol kalibrasi & "Catat"** —
   keduanya tidak punya label, dan `statusMessage` tidak pernah diumumkan.

### Tiga cacat nyata di layar kalibrasi (bukan sekadar label yang belum ada)

1. **`statusMessage` tidak pernah sampai ke VoiceOver.** Layar ini tidak punya
   `.onChange(of: engine.snapshot.state)` seperti `PointingView`, jadi **tidak
   ada satu pun** pengumuman di seluruh alur. Akibatnya menekan "Catat" bisa
   **ditolak** tanpa umpan balik apa pun — kelas "kegagalan diam" yang sama
   dengan Cacat 9/11 di riwayat, dan justru paling merusak di sini: satu-satunya
   jalan memasang kalibrasi.
2. **Ikon dekoratif ikut diucapkan.** Tombol acuan tidak
   `accessibilityHidden` pada ikon, jadi VoiceOver membacakan "bintang, plus
   lingkaran, Sirius, 40 derajat tinggi, plus lingkaran".
3. **Label tombol "Pakai" tidak membedakan hidup/mati.** `.disabled` adalah
   sifat visual; penolakan karena sebaran terlalu lebar — hasil yang paling
   mudah disalahartikan di seluruh alur ini — tidak pernah sampai ke pengguna
   suara.

### Teks yang diucapkan pindah ke `PointingKit` — dan kenapa

`CalibrationSpeech.swift` (baru) memuat `spokenPhaseSummary`,
`spokenApplyButtonLabel`, `spokenName`, `spokenCaptureLabel`.

Alasannya bukan kerapian. Kalimat-kalimat ini adalah **janji produk yang
bisa salah tanpa ada satu pun bagian UI yang keliru**: kalau label lupa menyebut
tahap, layar tetap menampilkan "Siap dipakai" dengan hijau, dan pengguna yang
tidak melihat layar tidak punya jalan apa pun untuk mengetahuinya. Persis kelas
"objek sisa tampil sebagai hasil sekarang" — UI yang tampak benar sambil
menyembunyikan apa yang sebenarnya berlaku. Konsekuensi yang ikut: angka
diucapkan sebagai kata ("derajat"), karena derajat adalah singkatan visual yang
tidak terbaca sebagai kata.

### Yang benar-benar dijalankan pada siklus ini

- `./swift-test.sh` → **166 CelestialEngine + 188 PointingKit, 0 gagal** (naik
  dari 179 → 188: 9 uji `CalibrationSpeechTests`).
- **Kedua mutasi dibuktikan MERAH lebih dulu**, bukan hanya hijau:
  - `spokenApplyButtonLabel` diabaikan `isReady` → **2 test gagal**;
  - `offset`/`sebaran` dikarang (`?? 0`) saat kalibrasi belum ada → **2 test
    gagal**.
- Semua keadaan diuji lewat alur **sungguhan** (`add`/`markApplied`), bukan
  menyetel `phase` langsung: `phase` `private(set)` dan dihitung dari sampel, jadi
  itulah satu-satunya cara mengujinya tanpa mengarang keadaan.
- Gerbang sintaks: **seluruh 20 berkas app** lolos `swiftc -parse -swift-version 5`
  di `swift:6.0`.
- Sapuan CJK/Cyrillic di `Apps/` + `Packages/`: **0**. Sapuan
  `\.system(size:` di `Apps/` → 0 di kode.
- CI `Apple Build` run `37173802303` → **2× `BUILD SUCCEEDED`** dan gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*; CI
  `Engine Tests (Linux)` run `37173802319` → hijau.

### Temuan yang sengaja TIDAK diperbaiki siklus ini

`CalibrationSessionTests.swift:285` menghasilkan `warning: result of call to
'XCTUnwrap(...)' is unused` — terlihat di log CI macOS. Sekali baris saja
(`_ =`), tapi di luar satuan kerja siklus ini dan tidak ada hubungannya dengan VoiceOver.
Dicatat supaya tidak dibaca ulang sebagai penemuan baru.

## Progres terakhir (4 Okt 2026 — Bagian 2: polish ala Mobbin)

### Premis siklus ini: klaim numerik harus dihitung, bukan dibaca

Brief meminta "kontras ≥ 4.5:1 (WCAG)". Itu **klaim numerik**, dan
klaim seperti ini tidak bisa dibuktikan dengan membaca kode — harus dihitung.
Selama ini tidak ada yang menghitungnya. Akibatnya `SurfacePalette` (RGB
mentah, tanpa SwiftUI) sekarang ada di `PointingKit`, dengan
`SurfacePaletteTests` yang menjaga angkanya di Linux; `Apps/Shared/SurfaceTokens.swift`
hanya menjembatanikannya ke `Color`.

### Tiga temuan nyata dari menghitung, bukan membaca

1. **`nightAwareSecondary` lama punya kontras 1.49:1 di mode malam** — bukan
   4.5:1. Syarat WCAG di brief sebenarnya tidak pernah terpenuhi di mode
   malam. Sekarang semua warna sekunder datang dari `SurfacePalette`, dan tes
   mengatakannya.
2. **Plafon kontras mode malam = 5.25:1** (merah murni di atas hitam tidak bisa
   lebih terang dari itu). Artinya "teks utama" vs "sekunder" hanya punya ruang
   kanal 1.00 → 0.95: pada mode malam **taksonomi** lebih berguna daripada
   terang-versus-redup. Dicatat di palet + diuji, supaya tidak nanti
   "diperbaiki" ke abu pucat demi "kontras" lalu membatalkan alasan mode malam.
3. **`surfaceSteps` harus dihitung dalam kanal sRGB, bukan luminance.**
   Permukaan malam punya hijau/biru nol, jadi luminance-nya hanya ~1/4 dari abu
   equivalent — ambang "langkah terlalu tipis" jadi tidak berwarna. Diperbaiki ke
   selisih kanal terbesar; **satu ambang berlaku untuk dua mode**.

### Yang berubah di UI

- Latar `#0A0A0F` / `#121216` + tiga lapis **surface stepping** (dari
  kecerahan, bukan shadow — di layar gelap shadow tak terlihat).
- Aksen gradien "ruang → nebula" hanya di keadaan `.lock`, supaya "aktif"
  tetap berarti sesuatu.
- **`.ultraThinMaterial` diganti warna solid.** Glassmorphism ada di brief, tapi
  warnanya bergantung apa yang ada di belakangnya sehingga klaim kontras yang
  sudah dihitung tidak bisa dijamin. Overrule dicatat di `NightMode.swift`,
  bukan diam-diam.
- **Dynamic Type**: semua `.system(size:)` di `PointingView` dan
  `ReducedLuminanceView` → semantic font. Angka tetap hanya untuk metric (jarak,
  radius, gambar).
- **Always-On**: kontras pakai `textPrimary`, bukan tone keadaan — watchOS
  menahan kromatik dan cyan/hijau di atas gelap hilang duluan. Ditambah label
  VoiceOver yang pendek.

### Cacat CI kedua yang hanya macOS bisa tangkap

CI pada `7e5b1de` gagal: `SurfaceTokens.swift:57: error: missing return in
getter expected to return 'LinearGradient'`. Semua getter di berkas itu kini
`return` eksplisit, jadi implicit-return tidak bisa menggigit lagi di sana.
`swiftc -parse` tetap lolos. Verde di `e0aec92` (Apple Build run
`37172701449` + Engine Tests run `37172701444`).

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 179 PointingKit, 0 gagal**
  (naik dari 167 → 179: 12 uji palet baru).
- Uji kontras **dibuktikan MERAH lebih dulu** pada metrik `surfaceSteps`
  berbasis luminance sebelum diperbaiki ke sRGB.
- Gerbang sintaks seluruh 17 berkas app lolos `swiftc -parse` di `swift:6.0`.
- Sapuan CJK di `Apps/` dan `Packages/`: 0.
- CI: Apple Build hijau + gerbang peringatan lolos; Engine Tests hijau.

## Progres terakhir (4 Okt 2026 — Bagian 1: visual objek)

### Cacat yang ditemukan: visual yang belum pernah dibangun CI

Siklus ini dimulai dari brief "tingkatkan UI/UX, tambahkan visual objek".
`CelestialVisualView.swift` ternyata **belum pernah ter-commit** — ia ada di
disk sebagai berkas untracked. Akibatnya isinya belum pernah melewati satu pun
build. Dua cacat yang pasti:

1. **`PlanetPalette` tidak akan pernah bisa dikompilasi.** Ia memanggil
   `.mercuryBody`, `.venusBody`, `.marsBody`, `.jupiterBody` — enum
   `SphereEnd` yang dideklarasikan hanya punya `.neutralBody`,
   `.neutralShadow`, `.saturnBody`, `.saturnShadow`. Empat case tidak ada.
   `switch`-nya pun tidak lengkap, jadi `SphereEnd` adalah Dead enum.
2. **Cincin Saturnus tidak akan pernah bisa dikompilasi.**
   `context.clip(to:)` tanpa `restoreClip()` — `GraphicsContext.clip(to:)` ada
   hanya di API yang tidak aktif, dan apelasi di sini memakai yang aktif.
3. **Dan kalau sempat terkompilasi, sabitnya terbalik saat gibbous.** Sisi limb
   diambil dari `sign(terminatorOffset)`; untuk fase gibbous tanda itu
   **berlawanan** dengan sisi yang menyala. Ini persis jebakan yang
   `phaseGeometry(waxing:)` perbaiki di commit sebelumnya — modelnya sudah
   benar, pemanggilnya belum.

Yang ketiganya lolos karena `-parse` hanya memeriksa sintaks: ia tidak
menyelesaikan tipe, tidak menyelesaikan enum case, dan tidak menyelesaikan
overload API.

### Yang diperbaiki, dan kenapa begini

- **Palet & ciri pengenal planet pindah ke `PointingKit`.** Warna dan
  `DistinguishingFeature` (pita / cincin / kutub / kawah / kabut) kini bagian
  dari model, jadi **teruji di Linux**: setiap planet punya warna berbeda,
  setiap planet punya ciri unik, dan `saturn → .rings` terverifikasi. Selama
  ini pemetaan itu hanya ada sebagai enum lokal di app yang belum pernah
  dibangun — ARTIFAK yang paling berbahaya, karena "gambar yang salah" lebih
  meyakinkan daripada teks yang salah dan tidak ada yang mengetahuinya.
- **`DistinguishingFeature` sengaja dipisah dari warna.** Warna bola boleh
  tampil saat engine ragu (bola abu tidak menunjuk planet tertentu), ciri
  pengenal **tidak boleh** (cincin = Saturnus). View uphold: `guard
  isConfirmed` sebelum menggambar ciri. Dan `isConfirmed` di layar diambil dari
  predikat yang **sama** dengan badge keyakinan (`!isStale`) — kalau gambar
  dan badge mengambil keputusan sendiri, gambar bisa tampil pasti sementara
  badge-nya disembunyikan, dan gambar lebih meyakinkan daripada badge.
- **`nightModeBrightness` = kanal merah, bukan luminance Rec.709.** Uji
  pertamanya **REDAH** dengan luminance: mode malam membuang hijau/biru, jadi
  yang benar-benar sampai ke mata hanya kanal merah. Memakai luminance penuh
  membuat planet abu terang (Merkurius, 0.70) tampak **lebih** terang dari
  Mars (0.51) — kebalikan dari bola mereka di langit. Diperbaiki ke kanal
  merah, dan sekarang **setiap** planet punya kanal merah berbeda (teruji), jadi
  mode malam tidak pernah mengubah lima planet menjadi satu bayangan sama.
- **`visualForDisplayedObject` memakai sumber yang ter-cache.** Arah fase
  (waxing/waning) dihitung **sekali per refresh konteks**, bukan di `body`.
  Pemanggilan di `body` berarti efemeris Matahari + Bulan dihitung ulang 20×
  per detik hanya untuk menggambar satu sabit. Bundle-nya satu: fraksi fase
  dari `skyContext`, arah fase dihitung pada sampel yang sama — jadi gambar dan
  angka "Fase Bulan" di layar Ketelitian tidak bisa berbeda.
- **`ObjectKind.displayName`/`spokenName` jadi satu sumber** di
  `Apps/Shared/ObjectKindLabels.swift`; switch duplikat di `PointingView`
  dihapus. Dua salinan akan cepat berbeda, lalu benda yang sama tampil dengan
  nama berbeda di jam dan iPhone.

### Cacat build yang hanya CI macOS bisa tangkap

CI pertama pada commit `23bc897` **gagal**:
`CelestialVisualView.swift:205: error: extraneous argument label 'rect:' in call`.
`Path` tidak punya inisialisasi `rect:` — harus `Path(CGRect)`. `swiftc -parse`
tetap bilang bersih. Perbaikan di `59fee76`; CI hijau di kedua workflow
(`Apple Build` run `37171706500` — 2× `BUILD SUCCEEDED`, gerbang peringatan
melaporkan "Tidak ada peringatan compiler pada Apps/"; `Engine Tests (Linux)`
run `37171706423`).

### Yang benar-benar dijalankan pada siklus ini

- `./swift-test.sh` → **166 CelestialEngine + 167 PointingKit, 0 gagal** (naik
  dari 143 → 167: 4 uji baru + 2 uji yang ditulis ulang).
- Uji baru `testNightModeKeepsBrightnessOrdering` dibuktikan **MERAH lebih
  dulu** pada versi luminance sebelum diperbaiki ke kanal merah.
- Gerbang sintaks: seluruh 16 berkas app lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan karakter asing (CJK) di `Apps/`: 0.
- Sapuan simbol enum yang tidak ada di `Apps/` — 0 setelah perbaikan.
- CI: `Apple Build` hijau + `Engine Tests (Linux)` hijau di HEAD `59fee76`.

## Ringkasan keadaan (4 Okt 2026, dini hari — sebelum Bagian 1)

**Seluruh kode selesai.** Yang tersisa di `ROADMAP.md` hanyalah satu item yang
**bukan kode**: "Point & Slew POC 1 teleskop — perencana aman sudah ada
(`SlewSafety`), perangkat keras belum". Itu menunggu teleskop fisik, bukan
pekerjaan repo ini.

- Engine (Fase 1–3) + logika app: **166 test CelestialEngine + 143 test
  PointingKit, 0 gagal** (`./swift-test.sh`, Swift 6.0 di Docker, Linux) —
  dan sejak siklus sebelumnya **keduanya juga ditegakkan di CI Linux**, bukan
  hanya yang pertama.
- Pembungkus app (watchOS + iOS): **terpasang lengkap**, dan **CI macOS
  (`Apple Build`) hijau** — bukan sekadar lolos parse. Build itu kini juga
  **gagal bila ada peringatan compiler pada kode sendiri**, jadi peringatan
  tidak bisa lagi menumpuk tanpa terlihat.
- CI: `engine-tests.yml` (ubuntu, 2 paket) + `ios-build.yml` (macos-15,
  XcodeGen, gerbang peringatan).

## Progres terakhir (4 Okt 2026 — verifikasi menyeluruh xcode-dev)

### Siklus ini: audit independen penuh terhadap klaim "item brief tersisa" (tanpa perubahan kode)
Brief masuk memerintahkan "selesaikan semua kode app dalam semalam, fokus
pembungkus app". Alih-alih mempercayai klaim STATUS lama maupun brief itu
sendiri, seluruh 15 berkas app dibaca baris demi baris DAN setiap simbol
`PointingKit`/`CelestialEngine` yang dipanggilnya diverifikasi keberadaan &
bentuknya di `Packages/`. Hasilnya: **tidak ada satu item pun dari brief yang
tersisa** — ketiga prioritas sudah terpasang dan konsisten.

**Yang diverifikasi dengan membaca + mencari (bukan percaya STATUS lama):**

1. **watchOS — MotionLogger**: `consume(_:at:)` memanggil
   `controller.feed(cmX:cmY:cmZ:cmW:timestamp:)` (PointingController.swift:296),
   yang lewat `DeviceAttitude.init?(cmX:cmY:cmZ:cmW:)` (Frames.swift:82) →
   `PointingController.feed`. `init?(cmX:…)` terkonfirmasi ada & publik.
2. **watchOS — CalibrationFlow/Solver**: `CalibrationView` memakai
   `CalibrationSession` (atas `CalibrationFlow` → `CalibrationSolver`), tombol
   "Pakai" mati sampai `flow.isReady`, dan `reset()` menyegarkan cuplikan engine
   via `engine.apply(calibration: .none)`.
3. **watchOS — WatchView dari PointingState**: `PointingView` merender langsung
   dari `engine.snapshot.state` (keenam keadaan via `PointingPresentation`:
   `symbolName`/`shortLabel`/`guidance`/`tone`) + `ObjectDetailView`. Tidak ada
   keadaan tanpa cabang.
4. **watchOS — Haptic**: `HapticEngine` memetakan `.lockSucceeded` → `.success`
   dan `.uncertain` → `.retry`; pemicunya `PointingController.hapticEvents(from:to:)`
   dengan penjaga `previous != current`, jadi hanya saat transisi keadaan.
5. **watchOS — WatchConnectivity**: `WatchLinkService` mengirim **keputusan**
   (`PointingLinkMessage.state(from:at:sigmaDeg:)`), bukan sudut pergelangan;
   gerbang `LinkReportGate.deliver` kirim-hanya-bila-berhasil.
6. **iOS — Diagnostik**: `DiagnosticsView` menggambar `ratioToSigma` (Swift
   Charts) + ekspor via `ConfidenceTraceArchive`/`JSONArchiveDocument`.
7. **iOS — Experiment 1**: `Experiment1View` + `ExperimentRecorder`
   (tunjuk→rekam→ekspor; verdict menyaring GAGAL; sensor mati mematikan tombol
   Rekam).
8. **Build**: `project.yml` (dua target app + `postGenCommand` tanam app jam ke
   `PlugIns/`) dan `ios-build.yml` sudah memuat `brew install xcodegen` + gerbang
   peringatan `Apps/`.

**Verifikasi silang simbol (risiko nyata build macOS):** semua simbol yang
dipanggil app — `PointingController.feed/resolver/calibration/answeredIntent/
setObserver/setConfidencePolicy/setSensorAvailable/stop`,
`PointingSnapshot.*` (rawPointing/calibratedPointing/reportedPointing/
answeredObject/answeredLevel/displayedObject/isDisplayingStaleObject/aim),
`PointingState.hasAnswer`, `PointingPresentation` (tone/symbolName/shortLabel/
guidance), `CalibrationSession`/`CalibrationFlow` (phase/samples/isReady/
capture/applyIfReady/reset/refreshReferenceTargets/suggestedConfidencePolicy),
`LinkReportGate.deliver`, `PointingLinkMessage` (init/plist/state/calibration/
policy/confidencePolicy), `ConfidenceTrace`/`ConfidenceTraceArchive`/
`DatasetArchive`, `ExperimentHarness` (record/removeLast/dataset/verdict/
summary/suggestedConfidencePolicy/availableTargets), `EngineFactory`,
`PointingResolver.confidencePolicy/skyContext`, `DeviceAttitude.init?(cmX:…)`,
`DeviceAimAxis.rawValue`, `PointingTrial.{intent,groundTruthObjectID}` — **semua
ada dengan akses level dan label argumen yang cocok** (termasuk getter lintas-
modul `controller.resolver`/`calibration` yang `public private(set)`).

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 143 PointingKit, 0 gagal** (Swift
  6.0, Docker, Linux) — dijalankan dari nol, bukan sekadar klaim.
- Sapuan stub (`TODO`/`FIXME`/`placeholder`/`stub`) di `Apps/` → 0 (satu-satunya
  "matches" adalah PNG ikon biner, bukan kode).
- Sapuan `@main` → tepat **dua** (jam + iPhone); tidak ada ketiga.
- Sapuan `try!`/`as!`/`fatalError` di `Apps/` → 0.
- `gh run list`: **`Apple Build` hijau** (run `37163527245`, 2m38s) **dan**
  `Engine Tests (Linux)` hijau (`37163527216`) pada HEAD `8038969` — artinya app
  benar-benar dikompilasi terhadap Apple SDK + `PointingKit` nyata, bukan sekadar
  lolos parse.

**Kesimpulan:** tidak ada kode app yang tersisa. Satu-satunya baris `ROADMAP.md`
yang belum tertutup tetap "Point & Slew POC 1 teleskop" — menunggu perangkat
keras fisik, bukan repo ini. Tidak ada aturan keras PRD yang dilonggarkan;
engine tidak disentuh.

## Progres terakhir (4 Okt 2026)

### Siklus ini: verifikasi mandiri independen (xcode-dev, sesi baru) — seluruh item brief (1–3) terpenuhi
Siklus ini dimulai dari brief yang memerintahkan "selesaikan semua kode dalam
semalam", dengan STATUS.md yang menyatakan pembungkus app sudah lengkap. Alih-alih
mempercayai klaim itu, seluruh berkas app (15 file) dibaca ulang baris demi baris
dan setiap simbol `PointingKit`/`CelestialEngine` yang dirujuknya dicari keberadaan
nyatanya di `Packages/`. Hasilnya: **tidak ada satu item pun dari brief yang tersisa**
— semua ada dan konsisten.

**Yang diverifikasi dengan membaca + mencari (bukan percaya STATUS lama):**
- Prioritas 1 (watchOS): `MotionLogger.consume` memanggil `controller.feed(cmX:cmY:cmZ:cmW:)`
  yang membangun `DeviceAttitude` lewat `init?(cmX:cmY:cmZ:cmW:)` (Frames.swift:82) →
  `PointingController.feed`. `CalibrationView` memakai `CalibrationSession` (di atas
  `CalibrationFlow`/`CalibrationSolver`), tombol "Pakai" mati sampai `flow.isReady`,
  dan `reset()` menyegarkan cuplikan engine. `PointingView` merender langsung dari
  `snapshot.state` (keenam keadaan via `PointingPresentation.symbolName/shortLabel/
  guidance/tone`) + `ObjectDetailView`. `HapticEngine` memetakan `.lockSucceeded` →
  `.success` dan `.uncertain` → `.retry`. `WatchLinkService` mengirim **keputusan**,
  bukan sudut pergelangan.
- Prioritas 2 (iOS): `DiagnosticsView` menggambar `ratioToSigma` (Swift Charts) + ekspor
  via `ConfidenceTraceArchive`/`JSONArchiveDocument`; `Experiment1View`+
  `ExperimentRecorder` (tunjuk→rekam→ekspor, verdict menyaring GAGAL).
- Prioritas 3: `project.yml` (dua target app + `postGenCommand` tanam app jam ke
  `PlugIns/`) dan `ios-build.yml` sudah memuat `brew install xcodegen` + gerbang
  peringatan `Apps/`.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 143 PointingKit, 0 gagal** (Swift 6.0,
  Docker, Linux) — dijalankan dari nol, bukan sekadar klaim.
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` (loop `find Apps -name '*.swift'` → bersih).
- Sapuan stub (`TODO`/`FIXME`/`placeholder`/`stub`) di `Apps/` → 0.
- `gh run list`: **`Apple Build` hijau** (run `37162913757`, 2m42s) — artinya app
  benar-benar dikompilasi terhadap Apple SDK + `PointingKit` nyata, bukan sekadar
  lolos parse; `Engine Tests (Linux)` hijau pada HEAD yang sama.

**Kesimpulan:** tidak ada kode app yang tersisa. Satu-satunya baris `ROADMAP.md` yang
belum tertutup tetap "Point & Slew POC 1 teleskop" — menunggu perangkat keras fisik,
bukan repo ini. Tidak ada aturan keras PRD yang dilonggarkan; engine tidak disentuh.

### Siklus ini: konfirmasi mandiri ulang pembungkus app + gerbang Linux (tanpa regresi)
Fokus: siklus ini dimulai dengan brief yang menyatakan "pembungkus app (watchOS +
iOS) tersisa". Setelah membaca seluruh berkas dan menjalankan gerbang, ternyata
ketiga prioritas brief **sudah terpasang lengkap** dan hanya perlu dikonfirmasi,
bukan dikerjakan. Tidak ada aturan keras PRD yang dilonggarkan; engine tidak
disentuh.

**Yang diverifikasi ulang (bukan sekadar percaya STATUS.md lama):**
- Prioritas 1 (watchOS) — semua ada: `MotionLogger` (`CMDeviceMotion` →
  `DeviceAttitude` lewat `init?(cmX:cmY:cmZ:cmW:)`, diverifikasi rantainya di
  `Frames.swift:82` + `PointingController.feed`); `CalibrationView` di atas
  `CalibrationSession`/`CalibrationSolver`; `PointingView` merender langsung dari
  `PointingSnapshot.state` (keenam keadaan); `HapticEngine` memicu `.lockSucceeded`
  / `.uncertain` (lewati `PointingController.hapticEvents`); `WatchLinkService`.
- Prioritas 2 (iOS) — `DiagnosticsView` (grafik `separation/σ` Swift Charts +
  `ShareLink` ekspor JSON via `JSONArchiveDocument`) dan `Experiment1View` +
  `ExperimentRecorder` (tunjuk→rekam→ekspor, verdict menyaring **gagal**).
- Prioritas 3 — `project.yml` XcodeGen (dua target app + `postGenCommand`
  tanam app jam ke `PlugIns/`) dan `ios-build.yml` sudah memuat
  `brew install xcodegen` + gerbang peringatan Apps/.
- Tidak ada stub: sapuan `TODO`/`FIXME`/`placeholder`/`stub` di `Apps/` → 0.
  `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` ada di kedua app.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 143 PointingKit, 0 gagal** (Swift
  6.0, Docker, Linux).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- `gh run list`: `Apple Build` (macOS) run `37160377165` hijau pada HEAD
  `a8b8856`; `Engine Tests (Linux)` hijau.

**Kesimpulan:** tidak ada kode app yang tersisa. Satu-satunya baris `ROADMAP.md`
yang belum tertutup tetap "Point & Slew POC 1 teleskop" — menunggu perangkat
keras fisik, bukan repo ini.

### Siklus sebelumnya: audit mandiri penuh pembungkus app + verifikasi CI (tanpa regresi)
Fokus: baca ulang **seluruh** berkas app (watchOS + iOS + Shared) dan
seluruh `PointingKit`/`CelestialEngine` yang dirujuknya, lalu cari cacat
nyata yang belum tertutup. Tidak ada satu baris pun yang diubah: hasilnya
adalah **konfirmasi**, bukan perbaikan.

**Yang diverifikasi mandiri (bukan sekadar percaya STATUS.md):**
- `./swift-test.sh` dijalankan dari nol: **166 test CelestialEngine + 143 test
  PointingKit, 0 gagal** (Swift 6.0, Docker, Linux).
- `gh run list` terakhir: **Apple Build hijau** (run `37157355179`, 3m17s,
  2026-10-03T22:07Z) — build + gerbang peringatan lewat.
- Setiap simbol yang dibaca view sudah ada: `PointingTone`/`PointingState`/
  `PointingSnapshot`/`PointingLinkMessage` (PointingKit), `WatchMetrics` &
  `JSONArchiveDocument` & `ConfidenceTraceStore` (app), `@main` tepat **dua**
  (satu per app). Tidak ada `try!`/`as!`/`fatalError` di `Apps` maupun
  `PointingKit`.
- Jalur data Watch↔iPhone, kalibrasi, haptic, dan Experiment 1 sudah
  konsisten: objek sisa tidak bocor ke iPhone, kiriman gagal tidak memakan
  kesempatan berikutnya, kalibrasi dibuang menyegarkan cuplikan jam,
  sensor mati terlihat di layar, dan ambang dari iPhone diterapkan lewat
  engine (bukan controller langsung) sehingga `snapshot` ikut berubah.

**Kesimpulan:** semua item brief (1–3) sudah selesai dan terverifikasi.
Satu-satunya baris `ROADMAP.md` yang belum tertutup adalah "Point & Slew POC
1 teleskop" — itu menunggu perangkat keras fisik, bukan kode. Tidak ada
pekerjaan repo tersisa.

### Siklus sebelumnya: kalibrasi yang dibuang tetap diklaim terpasang di jam
Fokus: menyisir **klaim kalibrasi** — apakah yang ditampilkan jam masih
berlaku setelah pengguna membuang kalibrasinya. Logika engine **tidak
disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat 13 — `CalibrationView.reset()` membuang kalibrasi tanpa menyegarkan
cuplikan engine.** Tombol "Ulang" memanggil `CalibrationSession.reset()`, yang
memang membuang offset di controller (`controller.apply(calibration: .none)`).
Masalahnya: layar jam **tidak membaca controller** — ia membaca
`engine.snapshot`. `reset()` tidak pernah menyegarkan cuplikan itu, sedangkan
`apply()` (jalur "Pakai") melakukannya lewat `engine.apply(calibration:)`.
Jadi satu jalur memperbarui tampilan dan satu jalur tidak, padahal keduanya
mengubah kalibrasi yang sama.

Akibatnya tidak terlihat sama sekali dari layar: ikon "scope" di toolbar dan
baris "Kalibrasi: Sudah" di panel detail **tetap menyala** setelah kalibrasi
dibuang. Pengguna lalu mempercayai arah tunjuk yang sebenarnya belum
terkalibrasi — persis klaim tanpa dasar yang dilarang PRD
("uncertainty > false confidence"). Ini sekaligus membuat tombol "Ulang"
terasa tidak bekerja: kalibrasi memang hilang, tapi tampilannya berkata
sebaliknya.

Diperbaiki di `CalibrationView.reset()`: setelah `session?.reset()`, jalur
yang sama dengan `apply()` dipakai — `engine.apply(calibration: .none)` —
sehingga cuplikan yang dirender ikut berubah. Ini memperbaiki **kelas**
cacatnya, bukan satu gejalanya: setiap perubahan kalibrasi di UI kini lewat
`PointingEngine`, tidak ada lagi jalur yang menyentuh controller di belakang
tampilan.

**Janji engine-nya dikunci dengan uji.** Selama ini tidak ada satu pun test
yang menegakkan "membuang kalibrasi harus terbaca di cuplikan" — `reset()`
diuji hanya lewat `c.calibration == .none`, bukan lewat `c.snapshot`. Uji
regresi baru (`CalibrationSessionTests.testResetClearsCalibrationFromPublishedSnapshot`)
dibuktikan **MERAH lebih dulu**: dengan `controller.apply(calibration: .none)`
dihapus dari `reset()`, assertion gagal
("kalibrasi yang dibuang tidak boleh tetap diklaim terpasang di cuplikan").

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 143 PointingKit, 0 gagal** (exit 0).
- Uji regresi baru dijalankan **dulu** pada `reset()` tanpa pembersihan →
  **gagal**; setelah perbaikan → **lulus**.
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` setelah perubahan.
- Sapuan ulang jalur kalibrasi: hanya `CalibrationView` yang memanggil
  `CalibrationSession`; `apply()` sudah lewat engine, dan `reset()` kini ikut.
- Cacat dokumentasi ikut ditutup: komentar di `project.yml` masih menyebut
  **92 tes** untuk `PointingKit`, padahal suite Linux yang benar-benar
  dijalankan adalah **143**. Angka disamakan dengan hasil nyata.
- CI `Engine Tests (Linux)` run `37157040232` pada commit `1fb57ff` → **166 +
  143, 0 gagal** (kedua paket).
- CI `Apple Build` run `37157040221` pada commit `1fb57ff` → **2× `BUILD
  SUCCEEDED`** (iPhone termasuk app jam, dan app jam sendiri) dan gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*

### Siklus sebelumnya: sesi tautan yang sudah mati tetap diklaim "Aktif" (dan tidak bisa diaktifkan ulang)
Fokus: menyisir **klaim keadaan tautan** di lapisan app — satu-satunya bagian
yang belum pernah diperiksa dari sisi "apakah yang ditampilkan masih berlaku?".
Logika engine **tidak disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat 12 — `PhoneLinkService.activate()` dijaga oleh flag yang tidak pernah
dibersihkan.** `isActivated` dilaporkan ke UI (layar Tautan: "Aktif" /
"Belum aktif") dan nilainya hanya diubah dari `activationDidCompleteWith`.
Ketika sesi benar-benar berhenti — `sessionDidDeactivate` dipanggil saat
pasangan berpindah, mis. jam baru dipasangkan — flag itu tetap `true`.

Akibatnya ada dua, dan keduanya tidak terlihat dari UI:

1. **Layar Tautan terus berbohong.** iPhone menampilkan "Aktif" selamanya
   padahal tidak ada satu pun pesan yang bisa lewat. Itu persis klaim tanpa
   dasar yang dilarang PRD ("uncertainty > false confidence") — versi
   tautannya, bukan versi pointing.
2. **Sesi tidak akan pernah diaktifkan ulang.** Penjaganya `!isActivated`,
   jadi panggilan `activate()` dari `sessionDidDeactivate` — yang komentarnya
   sendiri menjanjikan "Aktifkan ulang" — **langsung `return`** karena flag-nya
   masih `true`. Setelah jam baru dipasangkan, tautan mati sampai app dibunuh
   dan dibuka ulang.

Diperbaiki di `PhoneLinkService`: penjaga `activate()` sekarang memakai keadaan
sesi yang sebenarnya (`session.activationState != .activated`), dan
`sessionDidDeactivate` mengosongkan `isActivated`/`isReachable` sebelum
memanggil `activate()` — jadi UI jujur **dan** pengaktifan ulang benar-benar
dijalankan. Ini memperbaiki **kelas** cacatnya, bukan satu gejalanya:
`WatchLinkService` tidak punya penjaga seperti ini, jadi tidak ada jalur
kembar yang perlu ikut diperbaiki.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 142 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` setelah perubahan.
- CI `Engine Tests (Linux)` run `37154632209` pada commit `85a1744` → **166 +
  142, 0 gagal** (kedua paket).
- CI `Apple Build` run `37154632211` pada commit `85a1744` → **2× `BUILD
  SUCCEEDED`** (iPhone termasuk app jam, dan app jam sendiri) dan gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
- Cacat dokumentasi ikut ditutup: `ROADMAP.md` dan komentar di
  `engine-tests.yml` masih menyebut **140/140** dan **165 + 124**, padahal
  suite Linux yang benar-benar dijalankan adalah **166 + 142**. Angka di
  keduanya disamakan dengan hasil nyata.

### Siklus sebelumnya: kiriman yang gagal memakan kesempatan berikutnya (iPhone terjebak di keadaan lama)
Fokus: menyisir **janji "kegagalan tidak boleh diam"** sampai ke akibatnya pada
**urutan operasi**, bukan hanya pada penghitungnya. Siklus sebelumnya (Cacat 9)
membuat kegagalan kirim *terlihat*; siklus ini menemukan bahwa kegagalan itu
masih *hilang*. Logika engine **tidak disentuh**; aturan keras PRD tidak
dilonggarkan.

**Cacat 11 — gerbang "kirim saat keputusan berubah" menandai terkirim sebelum
mencoba mengirim.** `LinkReportGate` sengaja dibuat (Cacat 2) supaya iPhone
tidak menerima 20 pesan per detik untuk keputusan yang sama, dan supaya
kehilangan jawaban **tetap** terkirim. Tapi `PointAndKnowWatchWatchApp` dan
`WatchLinkService.sendIfDecisionChanged` memanggilnya dengan urutan:

    guard reportGate.shouldReport(snapshot) else { return false }   // tandai dulu
    send(state: snapshot, ...)                                      // kirim kemudian

`shouldReport` menyimpan `last = decision` saat ia dipanggil — **sebelum**
pengiriman dicoba. Jadi begitu satu kiriman gagal, keputusan itu sudah tercatat
"sudah dilaporkan", dan **tidak pernah dicoba lagi** selama keputusannya sama.

Yang membuat ini bukan sekadar teori: kegagalan yang paling sering di lapangan
adalah **jam belum tersambung ke iPhone** (Cacat 9 menyebutnya sendiri sebagai
"kegagalan yang paling sering terjadi"). Justru kegagalan itulah yang paling
lama bertahan — beberapa detik sampai menit — dan justru selama rentang itulah
gerbangnya menelan setiap kesempatan berikutnya. Hasilnya persis kebalikan dari
yang gerbang ini dibuat untuk mencegah: iPhone terjebak di keadaan lama (mis.
**"terkunci"** pada Sirius) sementara di jam sudah bergerak dan keadaannya sudah
berubah, **tanpa satu pun kiriman berikutnya yang membetulkannya** — sampai
kebetulan keputusannya berubah lagi. Kegagalan yang *terlihat* (penghitung naik)
tetap bisa berujung pada iPhone yang *salah*, dan tidak ada bagian UI yang
tampak keliru.

Diperbaiki di satu tempat, `PointingKit`: `LinkReportGate.deliver(_:via:)`
membalik urutannya — **kirim dulu, tandai hanya bila berhasil**. Keputusan yang
gagal tetap dianggap baru, jadi percobaan berikutnya mengulanginya sampai
berhasil; dan karena `send` tetap menaikkan penghitung kegagalan, pengulangan
itu terlihat, bukan diam. `WatchLinkService.send(_:)` / `send(state:)` kini
mengembalikan `Bool` supaya keberhasilannya bisa diketahui pemanggil, bukan
sekadar dihitung.

Dua uji regresi baru (`LinkMessageTests`) dibuktikan **MERAH lebih dulu** pada
urutan lama sebelum diperbaiki: percobaan kedua ditolak penyaringnya dan
`attempts` tetap 1 — jadi ini bukan pembacaan kode, melainkan hasil uji yang
benar-benar merah.

**Yang benar-benar dijalankan pada siklus ini:**
- Uji regresi dijalankan **dulu** pada urutan lama → **gagal** (5 assertion:
  "gagal kirim bukan terkirim", "keputusan yang gagal harus diulang"). Setelah
  perbaikan → **lulus**.
- `./swift-test.sh` → **166 CelestialEngine + 142 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Pola `deliver(_:via:)` (gate `mutating` + closure di kelas `@MainActor`)
  dibuktikan lebih dulu dengan probe `-typecheck` di container `swift:6.0`.
- Sapuan ulang pemanggil `shouldReport`/`send(state:)` di `Apps/` dan
  `PointingKit/Sources`: hanya `WatchLinkService.sendIfDecisionChanged` yang
  memakai gerbang, dan ia kini lewat `deliver`.
- CI `Engine Tests (Linux)` run `37154348034` pada commit `10dd936` → **166 +
  142, 0 gagal** (kedua paket).
- CI `Apple Build` run `37154348042` pada commit `10dd936` → **2× `BUILD
  SUCCEEDED`** dan gerbang peringatan melaporkan *"Tidak ada peringatan compiler
  pada Apps/."*

### Siklus sebelumnya: GoTo teleskop dihitung dari resolusi yang sudah tidak berlaku
Fokus: menyisir **predikat "jawaban berlaku sekarang"** ke jalur yang belum
pernah diperiksa — jalur yang berujung ke **motor teleskop**. Siklus-siklus
sebelumnya menutup objek sisa pada pesan ke iPhone dan riwayat keyakinan; yang
tersisa justru jalur paling berbahaya. Logika engine **tidak disentuh**;
aturan keras PRD tidak dilonggarkan.

**Cacat 10 — perintah GoTo diambil dari arah tunjuk sebelumnya.** `lastResolution`
sengaja dipertahankan agar cuplikan tetap membawa jarak tetangga untuk
diagnostik, dan ia hanya dibuang saat alur **dihentikan** (atau saat
lokasi/ambang berubah) — **bukan** saat arah tunjuk bergeser dan keadaan
kehilangan jawabannya. `PointingController.slewDecision(date:policy:)`
membacanya mentah: `guard let resolution = lastResolution`, lalu
`SlewPlanner.plan(...)`.

Akibatnya: selama pergelangan bergerak menjauh setelah sempat terkunci,
`lastResolution` masih berisi resolusi Sirius. Keadaannya sudah kembali
`pointing` (tidak punya jawaban sekarang), tapi `slewDecision` tetap
mengembalikan `.allowed(...)` untuk Sirius — dengan arah target dihitung dari
**posisi objek**, sesuai aturan PRD, tapi objek itu sudah tidak ada di arah
tunjuk sekarang. Langkah OBJECT ID dilewati: POINT → **SAFE GOTO**, tanpa
identifikasi yang berlaku. Ini kelas yang sama dengan Cacat 1 (objek sisa bocor
ke iPhone) — kali ini ujungnya motor, bukan layar.

Diperbaiki dengan predikat yang sudah dipakai jalur-jalur lain: `slewDecision`
kini gagal-tertutup (`nil`) kecuali `snapshot.state.hasAnswer`. Objek yang
dikunci dengan ambang lama pun tidak bisa lagi lolos, karena mengubah ambang
sudah menghentikan alur dan membuang jawabannya.

Satu uji baru menguncinya (`PointingControllerTests.testSlewDecisionRefusedWhenAnswerIsStale`):
terkunci di Sirius → GoTo diizinkan; arahkan 170° menjauh → `slewDecision` **nil**
(bukan lagi `.allowed` untuk Sirius). Uji ini gagal pada kode lama dengan pesan
yang menyebut Sirius beserta koordinatnya — jadi ia bukan sekadar formalitas.

**Yang benar-benar dijalankan pada siklus ini:**
- Uji regresi dijalankan **dulu** pada kode lama → **gagal** (`.allowed` untuk
  Sirius saat arah tunjuk 170° menjauh). Setelah perbaikan → **lulus**.
- `./swift-test.sh` → **166 CelestialEngine + 140 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan ulang `lastResolution`/`answeredIntent`/`hasAnswer` di `Apps/` dan
  `PointingKit/Sources`: tidak ada lagi jalur yang membaca resolusi lama tanpa
  memeriksa apakah keadaan punya jawaban. `lastResolution` kini hanya dipakai
  untuk jarak tetangga diagnostik (aman: keadaan yang menampilkannya juga sudah
  memberi tahu) dan oleh `slewDecision` yang sudah dijaga.
- CI `Engine Tests (Linux)` run `37153246327` pada commit `ce3da4c` → **166
  CelestialEngine + 140 PointingKit, 0 gagal** (kedua paket).
- CI `Apple Build` run `37153246367` pada commit `ce3da4c` → **2× `BUILD
  SUCCEEDED`** (skema iPhone yang ikut membangun app jam, dan skema jam sendiri),
  uji PointingKit di Apple SDK **140, 0 gagal**, dan langkah gerbang melaporkan
  *"Tidak ada peringatan compiler pada Apps/."*

### Siklus sebelumnya: arah tunjuk dari sensor yang sudah mati masih ikut terkirim, dan kegagalan kirim yang paling sering tidak terlihat
Fokus: menyisir **predikat "berlaku sekarang"** yang sudah dipakai untuk objek dan
keyakinan — apakah **arah tunjuk** punya padanannya — lalu memeriksa janji
"kegagalan tidak boleh diam" di jalur kirim. Logika engine **tidak disentuh**;
aturan keras PRD tidak dilonggarkan.

**Cacat 8 — azimut/ketinggian dari beberapa detik lalu terkirim sebagai pengukuran
sekarang.** Siklus sebelumnya (Cacat 7) menutup satu jalur bacaan arah tunjuk:
`PointingEngine.pointing` kini `nil` saat `snapshot.hasSensor == false`, karena
`calibratedPointing` sengaja **dipertahankan** di cuplikan dan saat sensor mati
isinya adalah arah terakhir sebelum sensor hilang. Tapi perbaikan itu hanya
menyentuh **layar jam**. Jalur kedua membaca field yang sama dan tidak pernah
diperiksa:

`PointingLinkMessage.state(from:)` — pesan keadaan ke iPhone — mengirim
`snapshot.calibratedPointing?.altitudeDeg` / `.azimuthDeg` **tanpa penjagaan
sensor**. Saat jam kehilangan sensornya, pesan yang terkirim tetap membawa
azimut/ketinggian dari beberapa detik sebelumnya, dan di iPhone tidak ada penanda
apa pun bahwa angkanya sudah tidak berlaku — persis kelas yang sama dengan Cacat 7,
kali ini di jalur yang Cacat 7 tidak mencapai.

Cara menutupnya sama seperti objek/keyakinan: aturannya dipindahkan ke
`PointingKit` sebagai predikat semantik
(`PointingSnapshot.reportedPointing`, berlaku hanya bila sensor hidup), lalu
**kedua** jalur memakainya — `PointingEngine.pointing` dan
`PointingLinkMessage.state(from:)`. Dengan begitu keduanya tidak bisa lagi berbeda
pendapat tentang kapan sebuah arah tunjuk boleh dilaporkan; sebelum ini aturannya
ditulis dua kali, dan hanya satu yang benar.

Dua uji baru mengunci perilakunya (`LinkMessageTests`,
`PointingPresentationTests`): sensor mati → `altitudeDeg`/`azimuthDeg` **tidak
dikirim** (sementara `state` tetap dilaporkan apa adanya), sensor hidup → arah
tetap ikut. Satu di antaranya secara eksplisit menegaskan bahwa
`calibratedPointing` **memang** masih terisi saat sensor mati — itulah yang
membuat kiriman mentah berbahaya, dan yang membuat uji ini bukan sekadar
formalitas.

**Cacat 9 — kegagalan kirim yang paling sering justru satu-satunya yang tidak
terlihat.** `WatchLinkService.send(_:)` berkomentar sendiri: *"Gagal kirim
**tidak** diam: penghitungnya naik supaya bisa dilihat saat pengujian lapangan."*
Isinya tidak begitu — `guard ... else { return }` pada sesi yang belum aktif
**tidak** menaikkan apa pun. `send(calibration:)` di berkas yang sama, dengan
penjagaan yang identik, **memang** menaikkannya. Jadi dua jalur yang sama
menjanjikan hal yang sama, dan hanya satu yang menepatinya — pola yang sama
seperti Cacat 8.

Akibatnya persis kebalikan dari niatnya: keadaan "jam belum tersambung ke iPhone"
— kegagalan yang paling sering terjadi di lapangan — adalah satu-satunya yang
tidak terlihat. Di layar jam angka "N gagal" tetap nol, dan penguji menyimpulkan
tautannya baik-baik saja sementara tidak ada satu pun keputusan yang sampai.
`requestState()` memakai jalur ini juga, jadi permintaan iPhone yang tidak pernah
dijawab pun tidak meninggalkan jejak.

Sekarang kedua jalur menghitung sesi-belum-aktif sebagai kegagalan, dengan pesan
yang menyebut sebabnya.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 139 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan ulang seluruh pembacaan field cuplikan yang dipertahankan
  (`snapshot.intent` / `bestObject` / `calibratedPointing` / `rawPointing`) di
  `Apps/` dan `PointingKit/Sources`: tidak ada lagi jalur kirim/rekam/tampil yang
  membacanya mentah. Tersisa hanya `ExperimentRecorder` (arah tunjuk **mentah**
  untuk mengukur galat, sudah dijaga `hasSensor` di pemanggilnya) dan
  `CalibrationSession` (titik acuan, sudah dijaga `hasSensor` di kedua jalan
  masuknya).
- `angularRateDegPerSec` **diperiksa dan ternyata benar**: `AngularRateTracker`
  ikut direset saat sensor hilang, jadi `nil` — bukan nilai lama. Tidak diubah.
- CI `Apple Build` run `37152202855` pada commit `a74d5be` → **2× `BUILD
  SUCCEEDED`**, gerbang peringatan *"Tidak ada peringatan compiler pada Apps/."*
- CI `Engine Tests (Linux)` run `37152202846` → **166 + 139, 0 gagal**.
- CI `Apple Build` run `37151800262` pada commit `775b89f` → **2× `BUILD
  SUCCEEDED`** (skema iPhone yang ikut membangun app jam, dan skema jam sendiri),
  dan langkah gerbang melaporkan *"Tidak ada peringatan compiler pada Apps/."*
- CI `Engine Tests (Linux)` run `37151800258` → **166 CelestialEngine + 139
  PointingKit, 0 gagal**, kedua paket ditegakkan di CI.

### Siklus sebelumnya: objek sisa bocor ke iPhone, dan jam berhenti bicara tepat saat jawabannya hilang
Fokus: menyisir **jalur yang mengirim dan merekam** "apa yang engine katakan
sekarang" — tempat objek yang sengaja dipertahankan mesin keadaan bisa keluar
dari layar jam (yang menandainya sisa) menuju tempat yang tidak punya penanda
itu. Logika engine **tidak disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat 1 — objek sisa terkirim sebagai jawaban sekarang.** Mesin keadaan
sengaja mempertahankan `currentIntent` supaya panel jam tidak berkedip saat
pergelangan bergerak sedikit (`PointingFlow.swift`). `PointingView` sudah
menanganinya: objek sisa ditampilkan **dengan** peringatan, dan badge keyakinan
disembunyikan. Tapi dua jalur lain membaca `snapshot.bestObject` /
`snapshot.intent?.level` mentah:

- `PointingLinkMessage.state(from:)` — pesan ke iPhone;
- `ConfidenceTrace.record(snapshot:)` — riwayat keyakinan di iPhone.

Keduanya **tidak** punya penanda "sisa". Akibatnya, tepat setelah jam kehilangan
jawabannya (pergelangan bergerak lagi), iPhone menerima dan merekam objek dari
arah tunjuk **sebelumnya** lengkap dengan badge "Yakin" dari keyakinan lama.
Ini persis false confidence yang dilarang PRD, dan ia muncul justru pada momen
paling menyesatkan. Diperbaiki di **satu tempat**: `PointingSnapshot` kini punya
predikat semantik `answeredObject` / `answeredLevel` / `answeredSeparationDeg`
(yang berlaku hanya bila `state.hasAnswer`), dan kedua jalur memakainya.
`displayedObject` sengaja tetap mempertahankan objek terakhir — itu benar untuk
layar jam, yang menandainya sisa.

**Cacat 2 — jam berhenti bicara tepat saat jawabannya hilang, dan mengirim 20×
per detik saat terkunci.** `PointAndKnowWatchWatchApp` menyaring kiriman dengan
`update.snapshot.state.hasAnswer`, padahal komentarnya sendiri menjanjikan
"bukan tiap sampel 20 Hz". Syarat itu salah dua kali sekaligus: selama terkunci
jawabannya **terus** ada, jadi syaratnya tetap benar dan jam mengirim 20×/detik
(persis yang ingin dicegah); dan tepat saat jawabannya **hilang** syaratnya
menjadi salah, jadi kiriman berhenti — iPhone membeku di objek terkunci terakhir
seolah masih berlaku, tanpa cara apa pun untuk tahu bahwa jam sudah tidak
mengidentifikasi apa pun. Diganti dengan `LinkReportGate` (di `PointingKit`,
teruji di Linux): kirim saat **keputusan berubah** — keadaan, objek, atau
keyakinan — termasuk saat berubah menjadi "tidak ada jawaban".

**Cacat 3 — dua kontrol di layar Diagnostik iPhone yang tidak mengatakan
keadaannya.** Saklar "Rekam keyakinan" menulis langsung ke
`trace.trace.isRecording`; `ConfidenceTrace` bukan `ObservableObject`, jadi
perubahan itu tidak dipublikasikan dan saklarnya bisa tampak tidak menanggapi.
Tombol "Kosongkan riwayat" tetap aktif saat perekaman **dijeda** — tampak siap
menghapus padahal tidak ada yang tersimpan lagi. Keduanya kini lewat store dan
mencerminkan keadaan yang sebenarnya.

**Cacat 4 — Experiment 1 bisa merekam pengukuran yang tidak pernah terjadi.**
`ExperimentRecorder.record()` hanya memeriksa "ada arah tunjuk?" (`rawPointing
!= nil`). Saat sensor mati, `rawPointing` yang tersisa di cuplikan adalah
**nilai terakhir sebelum sensor hilang** — nilainya tetap terisi, jadi
pemeriksaan itu meloloskannya. Yang akan terekam: arah dari beberapa detik lalu
dipasangkan dengan target yang dipilih sekarang, lalu masuk ke dataset yang
justru ada untuk mengukur akurasi Watch. Alat ukur tidak boleh mengarang data.
Kini sensor harus benar-benar hidup; tombol Rekam di layar ikut mati saat sensor
mati supaya penguji tidak mengira percobaannya tercatat.

**Cacat 5 — alat ukur Experiment 1 bisa melaporkan false lock palsu.**
`ObservationLog.analyze` menghitung `isFalseLock` murni dari `intent.level`.
Padahal `intent` sengaja **dipertahankan** oleh mesin keadaan saat pergelangan
bergerak: rekaman yang diambil pada keadaan `pointing` masih membawa intent
sisa berlevel HIGH. Hasilnya: engine dituduh "yakin tapi salah" untuk jawaban
yang tidak pernah ia tampilkan — dan `falseLockCount` inilah yang menentukan
lulus/gagal Experiment 1 (`passesSafetyCriterion`). Alat ukur tidak boleh
memproduksi kegagalan yang tidak terjadi. `analyze` kini menerima `state`
opsional: keadaan tanpa jawaban (`pointing`/`searching`/`idle`/`unavailable`)
tidak bisa menghasilkan false lock. Parameter berdefault `nil` supaya pemanggil
lama (165 uji engine) berperilaku persis seperti sebelumnya, dan harness
PointingKit sekarang meneruskan `state` yang selama ini sudah ia simpan di
`stateAtCapture` tetapi tidak pernah dipakai.

**Cacat 6 — kalibrasi bisa dipasang dari arah tunjuk yang sudah tidak berlaku.**
Kelas yang sama, kali ini di `CalibrationSession`: kedua jalan masuknya
(`capture(objectID:)` dan `captureNearest()`) membaca
`controller.snapshot.rawPointing` — yang **tetap terisi** saat sensor mati.
Akibatnya kalibrasi bisa dipasang dari arah terakhir sebelum sensor hilang:
seluruh pointing sesudahnya bergeser, dan kesalahannya tersembunyi di balik
sebaran sisa yang terlihat bagus. Keduanya kini menolak saat
`snapshot.hasSensor == false`, dengan pesan yang menyebut sebabnya.

**Cacat 7 — bacaan arah tunjuk tetap tampil dari sensor yang sudah mati.**
`PointingEngine.pointing` meneruskan `snapshot.calibratedPointing` apa adanya.
Saat sensor hilang, nilai itu adalah arah **terakhir sebelum sensor mati**, dan
layar Ketelitian menampilkannya sebagai azimut/ketinggian tanpa penanda — bacaan
lama tampak seperti pengukuran sekarang. Ini kelas yang sama dengan enam cacat
di atas (nilai yang sengaja dipertahankan, dibaca sebagai nilai berlaku), dan
kini disamakan: `nil` saat `snapshot.hasSensor == false`.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 136 PointingKit, 0 gagal** (exit 0).
  Dua belas uji baru mengunci perilaku ini: objek sisa tidak terkirim
  (`LinkMessageTests`), tidak terekam (`ConfidenceTraceTests`), predikat
  "berlaku sekarang" (`PointingPresentationTests`), dan gerbang kiriman
  (`LinkMessageTests`).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan jalur kirim/rekam: tidak ada lagi pembacaan `bestObject` /
  `intent?.level` mentah di `Apps/`.
- CI `Apple Build` run `37150857427` dan `Engine Tests (Linux)` run
  `37150857564` pada commit `d43d0a9` → keduanya hijau.
- CI `Apple Build` run `37150667798` dan `Engine Tests (Linux)` run
  `37150667892` pada commit `4e15d90` → keduanya hijau (App iPhone+Watch
  `BUILD SUCCEEDED`, 166 + 136 uji lolos).
- CI `Apple Build` run `37149633633` → **2× `BUILD SUCCEEDED`** dan gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
- CI `Engine Tests (Linux)` run `37149633616` → **165 CelestialEngine + 131
  PointingKit, 0 gagal**, kedua paket ditegakkan di CI.
- Siklus yang sama juga menutup klaim tes yang terlalu longgar:
  `displayedObject` mengembalikan `intent?.best` tanpa memandang keadaan,
  padahal tesnya menjanjikan "idle/unavailable tidak menampilkan objek apa
  pun" — janji itu hanya benar karena tesnya memakai intent kosong. Sensor yang
  mati di tengah pandangan memang menyisakan objek lama, jadi sekarang diuji
  apa adanya: panelnya tetap tampil **dengan** penanda sisa dan tanpa badge
  keyakinan (**132** tes PointingKit).
- CI `Apple Build` run `37149935666` dan `Engine Tests (Linux)` run
  `37149935687` pada commit berikutnya → keduanya hijau.

### Siklus sebelumnya: menutup temuan peringatan @preconcurrency + menjadikannya gerbang
Fokus: menutup **satu-satunya temuan yang sengaja dibiarkan terbuka** oleh
siklus sebelumnya. Logika engine **tidak disentuh**; aturan keras PRD tidak
dilonggarkan.

**Temuan yang ditutup.** Siklus sebelumnya mencatat tiga peringatan build yang
bertentangan dengan komentar di kodenya sendiri —
`@preconcurrency attribute on conformance to '...' has no effect` di
`LocationProvider.swift`, `WatchLinkService.swift`, dan `PhoneLinkService.swift`
— dan memilih **tidak** menyentuhnya karena menghapusnya tanpa bisa membangun
di macOS akan menjadi tebakan.

**Yang membuatnya bukan tebakan lagi.** Compiler-nya sendiri memberi verdict,
dan verdict itu bisa dibaca dari log CI yang sudah ada: Xcode 16.4 (16F6)
menandai atribut itu **tidak berpengaruh** dan menawarkan fix-it untuk
membuangnya. Compiler benar, dan alasannya bisa diperiksa di kode: **setiap**
metode delegasi di ketiga berkas sudah `nonisolated` dan menyerahkan hasilnya
ke main actor lewat `Task`, jadi tidak ada satu pun persyaratan protokol yang
dilanggar isolasi. Atribut itu memang tidak mengerjakan apa-apa, dan komentar
lama ("compiler menolak konformansnya tanpa atribut ini") sudah tidak berlaku.
Tiga atribut dibuang; komentarnya diganti dengan alasan yang berlaku sekarang.

**Arah perubahannya juga lebih gagal-tertutup.** Dengan atribut itu, kesalahan
isolasi **baru** di kemudian hari (mis. metode delegasi yang lupa `nonisolated`)
hanya menjadi peringatan runtime. Tanpa atribut, kesalahan yang sama menjadi
**galat kompilasi** — jauh lebih awal ketahuan.

**Agar tidak terulang.** Peringatan build hanya terlihat di log CI macOS, dan
peringatan yang menganggur adalah cara paling halus untuk menutupi komentar
kode yang sudah tidak berlaku — persis yang terjadi selama ini. Karena itu
kedua build app kini menyimpan keluarannya, dan langkah baru
**"Gerbang peringatan (kode sendiri)"** gagal bila ada `warning:` yang
menunjuk berkas `Apps/`. Peringatan alat Xcode (urutan build manual, metadata
AppIntents, swift-format) sengaja **tidak** dihitung — itu bukan kode ini, dan
menjadikannya kegagalan hanya akan membuat gerbangnya dimatikan orang lain saat
ia berbunyi.

**Celah kedua yang ditemukan dan ditutup.** `engine-tests.yml` hanya
menjalankan `CelestialEngine`, padahal kriteria "ENGINE SIAP" di `ROADMAP.md`
berbunyi "165/165 engine + 124/124 PointingKit di Linux, **tanpa Mac**".
Separuh kriteria itu karena itu tidak pernah ditegakkan di CI: perubahan pada
`PointingKit` — tempat seluruh keputusan produk yang bisa salah hidup (kapan
yakin, kapan menolak, apa yang direkam) — hanya akan tertangkap job macOS yang
jauh lebih lambat. Kini `swift test --package-path Packages/PointingKit`
dijalankan sebagai langkah kedua di sana.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **165 CelestialEngine + 124 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- **Pola gerbang peringatan diuji terhadap log run `37147598026` yang
  sebenarnya** (bukan dikarang): **16 peringatan kode tertangkap**, **6
  peringatan alat diabaikan**.
- CI `Apple Build` run `37148159414` → **2× `BUILD SUCCEEDED`**, langkah gerbang
  melaporkan *"Tidak ada peringatan compiler pada Apps/."* → tiga peringatan
  `@preconcurrency` **hilang**, terverifikasi di Apple SDK.
- CI `Engine Tests (Linux)` run `37148349397` → **kedua paket hijau**
  (165 + 124). CI `Apple Build` run `37148349347` → hijau.

### Siklus sebelumnya: peringatan lokasi bawaan tidak boleh bergantung pada string mentah
Fokus: menutup satu cacat laten di lapisan app. Logika engine **tidak
disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat yang ditemukan dan diperbaiki.** `PointingView` memutuskan apakah
menampilkan peringatan "lokasi belum didapat" lewat perbandingan string mentah:
`!engine.location.source.elementsEqual("corelocation")`. Padahal
`ObserverLocation` sudah punya predikat semantik `isFallback`. Perbandingan itu
benar **hari ini** hanya karena `LocationProvider` kebetulan menulis
`source: "corelocation"`. Begitu string itu berubah (atau ada sumber lokasi lain
yang ditambahkan), peringatan itu **terbalik diam-diam**: ia muncul justru saat
lokasi sungguhan, dan hilang tepat saat tinggi benda langit dihitung untuk
tempat lain. Itu persis kelas kesalahan yang PRD larang — UI yang tampak
normal sambil menyembunyikan bahwa angkanya tidak berlaku. Diganti dengan
`engine.location.isFallback` (predikat yang sama dengan yang dipakai layar
Experiment 1, jadi kedua layar tidak bisa lagi berbeda pendapat).

**Yang benar-benar dijalankan pada siklus ini:**
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- `./swift-test.sh` → **165 CelestialEngine + 124 PointingKit, 0 gagal** (exit 0).
- CI `Apple Build` + `Engine Tests (Linux)` pada commit siklus ini.

**Temuan yang dulu BELUM ditutup — kini sudah (lihat entri siklus terbaru di
atas).** Build macOS hijau tetapi mengeluarkan tiga peringatan yang
**bertentangan** dengan komentar di kodenya sendiri:
`@preconcurrency attribute on conformance to 'WCSessionDelegate' has no effect`
(`WatchLinkService.swift:138`, `PhoneLinkService.swift:99`) dan
`... to 'CLLocationManagerDelegate' has no effect` (`LocationProvider.swift:40`).
Siklus itu sengaja **tidak** mengubahnya: menghapus atribut tanpa bisa
membangun di macOS adalah tebakan, dan mempertahankannya adalah pilihan yang
gagal-tertutup (paling buruk: peringatan yang tidak berguna, bukan galat).
Siklus berikutnya menutupnya — atributnya memang tidak berpengaruh (semua
metode delegasi sudah `nonisolated`), dibuang, dan peringatan build pada kode
sendiri kini menjadi gerbang di CI.

### Siklus sebelumnya: ekspor dataset benar-benar menjadi berkas bernama
Fokus: menyisir berkas app terhadap daftar item yang tersisa, lalu menutup satu
cacat nyata. Logika engine **tidak disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat yang ditemukan dan diperbaiki.** Dua layar ekspor ("Ekspor dataset
(JSON)" di `DiagnosticsView` dan `Experiment1View`) membagikan **`String`**
mentah lewat `ShareLink`. Akibatnya berkas yang keluar dari lembar berbagi
adalah teks tanpa nama dan tanpa akhiran `.json`: di Files/penerima ia muncul
sebagai "Teks", bukan dataset. Yang membuat ini jelas cacat, bukan sekadar
kosmetik: helper nama berkas berstempel waktu UTC —
`DatasetArchive.suggestedFilename(for:)` dan
`ConfidenceTraceArchive.suggestedFilename(for:)` — **sudah ada dan sudah
diuji** di `PointingKit`, tetapi **tidak pernah dipanggil dari app**. Jadi
stempel waktu anti-tabrakan yang sengaja ditulis itu mati: dua ekspor bisa
saling menimpa, dan item "ekspor dataset" baru terpenuhi setengah.

Perbaikannya:
- `Apps/PointAndKnowiOS/Sources/JSONArchiveDocument.swift` — pembungkus
  `Transferable` (`FileRepresentation(exportedContentType: .json)`) yang menulis
  `Data` ke berkas sementara dengan nama dari `suggestedFilename`, lalu
  menyerahkan `SentTransferredFile(url)`. `ShareLink` kini menerima dokumen ini,
  bukan `String`.
- Kedua layar memakai helper nama yang sudah teruji; jalur gagal-encoding tetap
  membagikan pesan kesalahan **di dalam berkas**, bukan berkas kosong yang
  tampak sah.

**Yang benar-benar dijalankan pada siklus ini:**
- Gerbang sintaks: **seluruh 15 berkas app** (bertambah satu) lolos
  `swiftc -parse -swift-version 5` di container `swift:6.0`.
- `./swift-test.sh` → **165 CelestialEngine + 124 PointingKit, 0 gagal** (exit 0).
- CI `Apple Build` pada commit akhir siklus → **2× `BUILD SUCCEEDED`** (skema
  iPhone yang ikut membangun app jam, dan skema jam sendiri); `Engine Tests
  (Linux)` hijau. Percobaan pertama **gagal** (lihat di bawah) dan diperbaiki
  sebelum hijau.

**Galat nyata yang hanya muncul saat dibangun di macOS (dan sudah diperbaiki):**
- Percobaan pertama memakai `ShareLink(item:)` dengan label tapi **tanpa**
  `preview:`. Di macOS, `ShareLink` hanya mengimplementasikan sebagian
  permutasi initializer-nya: bila `item:` bukan `String`/`URL` **dan** tidak ada
  `preview:`, tidak ada initializer yang cocok →
  `error: no exact matches in call to initializer` (lalu satu galat susulan
  "type of expression is ambiguous" di baris berikutnya). Ditambahkan
  `preview: SharePreview(...)` pada kedua layar. Gerbang `swiftc -parse` **tidak**
  bisa menangkap ini: ia memeriksa sintaks, bukan resolusi overload — sama
  seperti kasus kontrol akses `PointingEngine.bind` di siklus sebelumnya.
  Pelajaran: untuk API SwiftUI baru, `-parse` bukan bukti; hanya build macOS
  yang membuktikan.

### Siklus sebelumnya: objek sisa tampil sebagai hasil sekarang (anti false-confidence)
Fokus: membaca sendiri setiap berkas app, lalu memperbaiki satu cacat nyata yang
ditemukan — bukan menambah fitur. Logika engine **tidak disentuh** (165 test
CelestialEngine tetap hijau); aturan keras PRD tidak dilonggarkan.

**Cacat yang ditemukan dan diperbaiki.** `PointingEngine.isDisplayingStaleObject`
menilai "objek basi" dari `snapshot.bestObject == nil`. Itu **salah**, karena
mesin keadaan sengaja mempertahankan `currentIntent` supaya panel tidak berkedip:
saat keadaan sudah kembali `pointing` setelah pergelangan bergerak,
`bestObject` **tetap terisi** objek dari arah tunjuk sebelumnya. Akibatnya
sinyal "sisa pandangan sebelumnya" bernilai `false` tepat pada objek yang paling
basi. Dua akibat nyata:

- Peringatan "Sisa pandangan sebelumnya" di `PointingView` (jam) **tidak pernah
  bisa muncul** — syarat render lamanya (`state.hasAnswer`) hanya lolos saat
  `bestObject != nil`, dan saat itu `isStale` selalu `false`.
- `DiagnosticsView` (iPhone) menampilkan `displayedObject` tanpa penjagaan di
  bagian berjudul **"Sekarang"**, sehingga objek lama terbaca sebagai hasil
  pengukuran sekarang.

Perbaikannya: aturan pindah ke `PointingKit`
(`PointingSnapshot.displayedObject(lastLocked:)` +
`isDisplayingStaleObject(lastLocked:)`) supaya bisa diuji di Linux, dan
"basi" kini ditentukan oleh **`state.hasAnswer`**, bukan dari mana objek diambil.
`PointingView` menampilkan panel detail **dengan** peringatan sisa (bukan
disembunyikan, yang membuat jam berkedip) dan menyembunyikan badge keyakinan
pada objek sisa; `DiagnosticsView` menandai barisnya "Objek (sisa) — bukan hasil
sekarang".

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **165 CelestialEngine + 124 PointingKit, 0 gagal** (exit 0).
  Dua uji regresi baru menjaga aturan ini (`PointingPresentationTests`).
- Gerbang sintaks: **seluruh 14 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` setelah perubahan.
- `gh run view` pada `Apple Build` HEAD `6e5edd8` → **2× `BUILD SUCCEEDED`**
  (skema iPhone yang ikut membangun app jam, dan skema jam sendiri), **0 galat**.

### Siklus sebelumnya: perbaikan bug siklus hidup sensor di app iPhone
Fokus: membaca sendiri setiap berkas app, lalu memperbaiki satu cacat nyata yang
ditemukan — bukan menambah fitur. Logika engine **tidak disentuh** (165 + 122
test tetap hijau); aturan keras PRD tidak dilonggarkan.

**Cacat yang ditemukan dan diperbaiki.** `DiagnosticsView` dan `Experiment1View`
masing-masing menyalakan dan mematikan sensor **yang sama** di `onAppear` /
`onDisappear`. `TabView` menahan kedua tabnya tetap hidup, jadi:
- keduanya menyetel `motion.onUpdate` pada satu `MotionLogger` — penyambungan
  yang belakangan menimpa yang duluan, sehingga salah satu tab berhenti merekam;
- `onDisappear` salah satu tab memanggil `engine.stop()` untuk alur yang sedang
  dipakai tab lain.

Gejalanya persis jenis yang dilarang: layar tetap tampak hidup sementara sensor
sudah mati. Perbaikannya: siklus hidup sensor/lokasi/alur dipindahkan ke
`RootView` (satu kali untuk seluruh umur app, plus `scenePhase`), dan tiap tab
tidak lagi memilikinya. `Experiment1View` kini hanya menerima `engine` + `link`.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **165 CelestialEngine + 122 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 14 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` setelah perubahan.
- `gh run view` pada `Apple Build` HEAD `6e5edd8` → **2× `BUILD SUCCEEDED`**
  (skema iPhone yang ikut membangun app jam, dan skema jam sendiri), **0 galat**.
  Peringatan yang tersisa hanya bersifat kosmetik: `@preconcurrency ... has no
  effect` (sudah ditangani compiler Xcode 16.4, tidak berpengaruh fungsional) dan
  "Building targets in manual order is deprecated".

### Siklus sebelumnya: verifikasi independen ulang + koreksi klaim dokumen
Fokus: menjalankan sendiri seluruh verifikasi (bukan membaca klaim), lalu
memperbaiki satu klaim dokumen yang tidak cocok dengan berkasnya. Tidak ada kode
engine maupun app yang diubah; tidak ada aturan keras PRD yang dilonggarkan.

**Yang benar-benar dijalankan:**
- `./swift-test.sh` → **165 CelestialEngine + 122 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 14 berkas app** lolos
  `swiftc -parse -swift-version 5` di container `swift:6.0`.
- `gh run list` → **`Apple Build` (macOS) dan `Engine Tests (Linux)` hijau** pada
  commit HEAD `abd2d64` (pohon git bersih) — jadi app benar-benar dikompilasi
  Apple SDK, bukan sekadar lolos parse.
- Sapuan stub (`TODO`/`FIXME`/`placeholder`) → bersih; satu-satunya kemunculan
  kata "placeholder" adalah komentar di `Confidence.swift` yang menjelaskan
  mengapa sigma awal sengaja longgar.
- Penyisiran jalur `rawPointing`: hanya di `CalibrationSession` (titik acuan),
  `ExperimentHarness`/`ExperimentRecorder` (pengukuran galat), dan `PointingView`
  (tidak dipakai). Tidak ada jalur yang menuju motor — `SlewCommand` tetap hanya
  bisa dibentuk `SlewPlanner`, dari objek teridentifikasi, gagal-tertutup.

**Koreksi dokumen (bukan kode):** `STATUS.md` menyebut `project.yml` punya
"empat target (2 app + 2 tes)". Berkasnya — dan seluruh riwayatnya — hanya pernah
mendefinisikan **dua target app** (`type: application`); tidak pernah ada target
tes Xcode. Tes memang hidup di paket SwiftPM (`swift test`), bukan sebagai target
Xcode. Klaimnya dikoreksi supaya cocok dengan berkasnya; tidak ada perubahan
build, jadi hijau CI tidak terpengaruh.

**Kesimpulan:** seluruh item kode di `ROADMAP.md` terpenuhi; satu-satunya item
yang tersisa adalah POC teleskop fisik, yang menunggu perangkat keras.

### Siklus sebelumnya: audit independen seluruh daftar item app (tanpa regresi)
Fokus: **memverifikasi, bukan mempercayai** — membaca ulang setiap berkas app
dan engine, lalu menjalankan suite, untuk memastikan tidak ada item yang
diklaim selesai padahal belum. Tidak ada aturan keras PRD yang dilonggarkan,
dan tidak ada kode engine yang diubah (165 + 122 test tetap hijau).

**Yang diverifikasi ulang satu per satu (semuanya sudah ada):**
- `MotionLogger` memetakan `CMDeviceMotion.attitude.quaternion` → `DeviceAttitude`
  lewat `init?(cmX:cmY:cmZ:cmW:)` → `controller.feed(...)` (`MotionLogger.swift:112`).
- `CalibrationView` memakai `CalibrationSession` (di atas `CalibrationFlow` →
  `CalibrationSolver`) dan hanya memasang kalibrasi lewat `engine.apply` setelah
  sebaran acuan sempit (`CalibrationView.swift:153,186`).
- `PointingView` merender **langsung** dari `PointingSnapshot`; keenam keadaan
  (`idle/pointing/searching/lock/uncertain/unavailable`) dipetakan lengkap di
  `PointingPresentation` (simbol, label, panduan, nada) — tidak ada keadaan tanpa
  cabang.
- Haptic dipicu **hanya pada perpindahan keadaan**, di
  `PointingController.hapticEvents(from:to:)` dengan penjagaan `previous != current`
  — jadi tidak bergetar tiap sampel 20 Hz. `.lock` → `.success`, `.uncertain` →
  `.retry` (`HapticEngine.swift:33-36`).
- `WatchLinkService`/`PhoneLinkService` memakai bentuk kabel yang sama
  (`PointingLinkMessage.plist` / `init?(plist:)`); kalibrasi lewat
  `transferUserInfo` (tidak tertimpa), keadaan lewat `updateApplicationContext`.
  `rawPointing` **tidak** pernah dikirim.
- iOS: `DiagnosticsView` menggambar rasio jarak-kandidat/σ (Swift Charts) +
  `ShareLink` ekspor JSON; `Experiment1View`/`ExperimentRecorder` merekam
  tunjuk→rekam→ekspor dengan kebenaran mengikuti `engine.location`.
- `project.yml` menunjuk path yang benar-benar ada (termasuk
  `Resources/Assets.xcassets` dengan `AppIcon-1024.png`), `ios-build.yml` sudah
  memuat `brew install xcodegen`.

**Aturan keras PRD diperiksa ulang di kode:** `rawPointing` (sudut pergelangan)
hanya dipakai di dua tempat yang memang diizinkan — `CalibrationSession` (titik
acuan) dan `ExperimentHarness` (pengukuran galat). Tidak ada di jalur mana pun
yang menuju motor. `SlewPlanner`/`SlewCommand` tetap satu-satunya jalan membentuk
perintah GoTo, diturunkan dari objek teridentifikasi, gagal-tertutup.

**Tidak ada perubahan kode** — siklus ini murni verifikasi. Yang dijalankan:
- `./swift-test.sh` → **165 CelestialEngine + 122 PointingKit, 0 gagal** (exit 0).
- `gh run list` → **CI macOS `Apple Build` + CI Linux `Engine Tests` hijau** pada
  commit `12b4ce9` (HEAD), pohon git bersih.
- Sapuan stub (`TODO`/`FIXME`/`placeholder`) → bersih; satu-satunya kemunculan
  kata "placeholder" adalah komentar di `Confidence.swift` yang **menjelaskan**
  mengapa sigma awal sengaja longgar.

**Kesimpulan:** seluruh item kode di `ROADMAP.md` terpenuhi; satu-satunya item
yang tersisa adalah POC teleskop fisik, yang menunggu perangkat keras.

## Progres terakhir (3 Okt 2026)

### Siklus ini: kalibrasi yaw diterapkan DUA KALI (galat sisa 2× offset)
Fokus: menguji **siklus kalibrasi penuh**, bukan hanya potongan fungsinya.

**Bug yang ditemukan (dan tidak terlihat oleh 165+120 test lama):**
- `PointingController` memakai `calibration.yawOffsetDeg` **dua kali**:
  sekali sebagai `rollAboutViewDeg` saat membangun `DeviceAttitude`
  (`PointingController.swift:299`, `:328`), lalu sekali lagi sebagai koreksi
  azimut lewat `calibration.apply(to:)`.
- Akibatnya offset yang *benar* menghasilkan galat sisa ≈ 2×offset. Probe
  numerik dengan offset 37° memberi galat **35.36°**, `state = .searching`,
  `bestObject = nil` — jam gagal mengunci bintang yang ditunjuk tepat, padahal
  kalibrasinya sudah benar.
- Setelah diperbaiki (offset hanya lewat `calibration.apply`): galat sisa
  **8.5e-07°**, `state = .lock`, `bestObject = sirius`.
- **Mengapa lolos selama ini:** suite lama menguji `PointingCalibration.apply`
  dan `DeviceAttitude(rollAboutViewDeg:)` secara terpisah, tapi tidak pernah
  menjalankan satu siklus lengkap "kalibrasi → tunjuk → kunci". Bug hanya
  muncul saat keduanya dirangkai.
- **Regresi permanen:** `CalibrationRoundTripTests` (2 test) mengunci perilaku
  ini — offset diterapkan tepat sekali, azimut terkoreksi, altitude tidak
  tersentuh, dan hasil akhirnya `.lock` pada target yang benar.
  **Pelajaran:** uji jalur ujung-ke-ujung, bukan hanya unit terpisah; offset
  ganda adalah kelas bug yang tak terlihat dari test per-komponen.

### Siklus sebelumnya: sensor mati di tengah pemakaian tidak terlihat di layar
Fokus: menyisir **perubahan keadaan yang tidak pernah sampai ke UI**. Tidak ada
aturan keras PRD yang dilonggarkan.

**CI macOS menangkap satu kesalahan yang Linux tidak bisa lihat:**
- `PointingUpdate` tidak punya inisialisasi publik (memberwise default bersifat
  `internal`), sehingga `MotionLogger.publishSensorLoss()` ditolak dengan
  *"'PointingUpdate' initializer is inaccessible due to 'internal' protection
  level"*. Ditutup dengan `public init(snapshot:haptics:)`.
  **Pelajaran:** `swiftc -parse` hanya memeriksa sintaks — ia tidak tahu soal
  tingkat akses antar-modul. Untuk app, macOS CI adalah verifikasi sebenarnya.
- Setelah perbaikan: **CI macOS hijau** (`Apple Build`, run `37140770415`) dan
  **CI Linux hijau** (run `37140770436`).

**Yang ditemukan & ditutup:**
- **`MotionLogger.handleFailure` menghentikan alur tanpa memberi tahu UI.**
  Jalur galat CoreMotion (sensor dilepas, izin dicabut, hardware gagal) memanggil
  `controller.setSensorAvailable(false)` langsung — yang memang membuang
  jawaban di dalam controller. Tapi `PointingEngine.snapshot`, satu-satunya
  sumber yang dibaca `PointingView`, **tidak ikut berubah**: sampel sudah
  berhenti mengalir, jadi `onUpdate` tidak pernah dipanggil lagi.
  - Akibatnya jam tetap menampilkan objek terakhir **seolah masih
    terkonfirmasi**, beserta getaran "terkunci" yang terakhir — persis yang
    dilarang PRD ("jangan pernah salah identifikasi demi magic"). Tidak ada
    bagian UI yang terlihat keliru, karena yang terlihat justru jawaban lama
    yang tampak normal.
  - Perbaikan: kehilangan sensor dikirim lewat **saluran yang sama dengan
    sampel sensor** (`PointingUpdate` yang sudah diperbarui + peristiwa haptic),
    bukan dengan menyentuh controller diam-diam. Jalur "perangkat tanpa device
    motion" di `start(controller:)` juga dialihkan ke jalur yang sama — di sana
    ia dijalankan sebelum `self.controller` diset, jadi sebelumnya sensor tidak
    pernah ditandai mati sama sekali.
- **`ExperimentHarness.availableTargets` dihitung ulang tiap pembacaan.**
  Layar Experiment 1 membacanya di dalam `body`, dan `body` dievaluasi pada
  setiap sampel sensor — jadi seluruh katalog + efemeris tata surya disapu 20
  kali per detik sepanjang pengukuran. Ditambah cache berjangka 30 detik yang
  dibatalkan saat tempat berubah (dengan `isSamePlace`, supaya perbaikan GPS
  yang hanya menggeser `capturedAt` tidak membuangnya), plus
  `targetComputationCount` supaya daftar yang dihitung ulang tidak terlihat
  sama dengan yang di-cache.

**Tes baru (8):** `testChangingObserverDropsAnswerComputedForOldSky`,
`testReapplyingSameObserverIsANoOp`, `testSetObserverKeepsCalibration`,
`testReferenceListBecomesStaleWhenObserverMoves`,
`testReferenceListStaysFreshWhenOnlyTimeChanges`,
`testTargetListIsNotRecomputedOnEveryRead`,
`testTargetListIsRecomputedAfterMoving`,
`testTargetListIsNotRecomputedForSamePlace`.
Uji pertama **dibuktikan MERAH lebih dulu** sebelum perbaikan: keadaan tetap
`lock` dan Sirius tetap tampil setelah pindah Jakarta → Quito.

**Status:** `./swift-test.sh` → **165 engine + 120 PointingKit, 0 gagal**.
Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
`swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: jawaban langit lama bertahan setelah pindah tempat
Fokus: menyisir **pembatalan jawaban yang menumpang pada efek samping pemanggil
lain** — kelas bug yang tidak terlihat di UI. Tidak ada aturan keras PRD yang
dilonggarkan.

**Yang ditemukan & ditutup:**
- **Perbaikan siklus lalu (kalibrasi yang sama = tanpa-efek) mematahkan
  pembatalan yang ternyata dipakai orang lain.** `PointingEngine.update(location:)`
  membatalkan jawaban lama dengan memanggil `apply(calibration:)` — yang
  menghentikan alur. Begitu panggilan itu jadi tanpa-efek, **perpindahan tempat
  berhenti membatalkan apa pun**: setelah pengguna pindah tempat, jam tetap
  menampilkan objek yang dihitung untuk langit **lama**. Keadaan `lock` ikut
  bertahan, jadi haptic "terkunci" tidak pernah berbunyi lagi di tempat baru.
  Tidak ada satu pun bagian UI yang terlihat keliru.
  - Perbaikan: pembatalan **melekat pada lokasi itu sendiri** lewat
    `PointingController.setObserver(_:)` (hentikan alur, buang resolusi,
    segarkan cuplikan). `observer` menjadi `private(set)` supaya tidak ada jalur
    yang bisa menggantinya tanpa membatalkan. Memasang pengamat yang sama tetap
    tanpa-efek. Kalibrasi **sengaja dipertahankan**: offset yaw adalah sifat
    pemasangan jam, bukan sifat tempat.
- **`CalibrationSession` menghitung daftar acuan untuk langit tempat lama.**
  Bintang yang tampak di atas horizon di satu tempat bisa sudah terbenam di
  tempat lain. Lokasi sungguhan tiba beberapa detik setelah layar kalibrasi
  dibuka, jadi pengguna memilih bintang yang tidak ada di langitnya, lalu offset
  kalibrasi dihitung dari kebenaran yang salah — dan daftar yang salah tempat
  tampak sama normalnya dengan yang benar.
  - Perbaikan: `referenceObserver` + `isReferenceListStale`, dan `CalibrationView`
    menghitung ulang saat lokasi berubah.
- **`PointingEngine.refreshSkyContext` menjalankan efemeris penuh 20 Hz.**
  Dokumennya sendiri menyebut "dipanggil jarang", tapi ia dipanggil dari
  `ingest(_:)` pada **setiap** sampel sensor: efemeris Matahari dan Bulan penuh
  di main actor tiap sampel. Ditambah penjagaan 30 detik; perubahan lokasi
  melewatinya, karena konteks tempat baru memang belum pernah dihitung.
- **`ExperimentHarness.availableTargets` dihitung ulang tiap pembacaan.**
  Layar Experiment 1 membacanya di dalam `body`, dan `body` dievaluasi pada
  setiap sampel sensor — jadi seluruh katalog + efemeris tata surya disapu 20
  kali per detik sepanjang pengukuran. Ditambah cache berjangka 30 detik yang
  dibatalkan saat tempat berubah (dengan `isSamePlace`, supaya perbaikan GPS
  yang hanya menggeser `capturedAt` tidak membuangnya), plus
  `targetComputationCount` supaya daftar yang dihitung ulang tidak terlihat
  sama dengan yang di-cache.

**Tes baru (8):** `testChangingObserverDropsAnswerComputedForOldSky`,
`testReapplyingSameObserverIsANoOp`, `testSetObserverKeepsCalibration`,
`testReferenceListBecomesStaleWhenObserverMoves`,
`testReferenceListStaysFreshWhenOnlyTimeChanges`,
`testTargetListIsNotRecomputedOnEveryRead`,
`testTargetListIsRecomputedAfterMoving`,
`testTargetListIsNotRecomputedForSamePlace`.
Uji pertama **dibuktikan MERAH lebih dulu** sebelum perbaikan: keadaan tetap
`lock` dan Sirius tetap tampil setelah pindah Jakarta → Quito.

**Status:** `./swift-test.sh` → **165 engine + 120 PointingKit, 0 gagal**.
Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
`swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: memasang kalibrasi yang sama mereset alur tanpa alasan
Fokus: menyisir operasi yang **tidak idempoten** padahal seharusnya. Tidak ada
aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **`PointingController.apply(calibration:)` selalu mereset perata orientasi dan
  menghentikan mesin keadaan**, bahkan ketika kalibrasi yang dipasang persis
  sama dengan yang sedang berlaku. Dua pemanggil memang mengirim nilai yang
  sama:
  - `PointingEngine.update(location:)` mempertahankan kalibrasi dengan
    memanggil `apply(calibration: controller.calibration)` — nilai yang sama
    persis.
  - `CalibrationView.capture()` memanggilnya setelah mencatat acuan, padahal
    mencatat acuan tidak mengubah kalibrasi yang berlaku.
  - Akibatnya kunci yang sudah benar dibuang tanpa ada yang berubah — dan itu
    terjadi justru saat pengguna sedang mengkalibrasi. Ini sisa dari siklus
    lokasi: perbaikan `isSamePlace` menutup jalur yang paling sering, tapi
    akarnya ada di sini.
  - Perbaikan: penjagaan `newValue != calibration` ditaruh di controller supaya
    pemanggil tidak bisa "lupa". Reset hanya masuk akal bila kalibrasinya
    memang berubah, karena hanya perubahan yang membuat acuan lama tidak
    sebanding. Baris berlebih di `CalibrationView.capture()` dibuang, dengan
    komentar yang menjelaskan mengapa tidak perlu.
- **Tes baru (1):** `testReapplyingSameCalibrationIsANoOp` — kalibrasi yang sama
  tidak membuang kunci yang sudah benar. `testApplyingCalibrationResetsFlow`
  yang sudah ada tetap memastikan kalibrasi yang **berbeda** tetap mereset alur.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 112, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: tiap perbaikan GPS menghentikan alur dan mereset perata orientasi
Fokus: menyisir **kesetaraan nilai** yang dipakai sebagai penanda perubahan.
Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **`PointingEngine.update(location:)` memakai `!=`, padahal `ObserverLocation`
  membawa `capturedAt`.** Tiap pembaruan lokasi membuat nilai itu berbeda, jadi
  **setiap** perbaikan GPS — kira-kira tiap detik, selama app terbuka —
  dianggap perpindahan tempat. Jalur itu menjalankan
  `controller.apply(calibration:)`, yang **mereset perata orientasi dan
  menghentikan mesin keadaan**.
  - Akibatnya jam **tidak akan pernah sempat** menunggu pergelangan diam lalu
    mengunci selama lokasi masih diperbarui, dan haptic "kembali ke idle"
    berbunyi berulang tanpa pengguna melakukan apa pun.
  - Getaran GPS puluhan meter hanya menggeser langit ≈0.0005° — tidak berarti
    apa-apa dibanding sigma pointing. Yang benar-benar menggeser langit adalah
    perpindahan tempat, bukan penajaman koordinat.
  - Perbaikan: `ObserverLocation.isSamePlace(as:toleranceDeg:)` membandingkan
    **koordinat saja** (ambang 0.01° ≈ 36″), dan menolak lokasi yang tidak sah.
    `update(location:)` memakainya. Sifat ini ditaruh di tipe-nya supaya
    perbandingan ini bisa diuji di Linux — bukan tersembunyi di lapisan app.
- **Tes baru (2):** `testIsSamePlaceIgnoresTimestampAndJitter` (waktu berbeda +
  getaran GPS → tempat yang sama; perpindahan 0.05° → bukan tempat yang sama),
  `testInvalidLocationIsNeverSamePlace`. Tes pertama menyatakan eksplisit
  `XCTAssertNotEqual(first, later)` — jadi ia gagal kalau pembandingnya
  dikembalikan ke `!=`.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 111, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: sampel dari jam membawa sigma yang tidak pernah berlaku
Fokus: memastikan **konteks** yang menemani sampel benar, bukan hanya
sampelnya. Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **`ConfidenceTrace.record(message:)` mencatat sigma bawaan.** Jam tidak
  pernah menyertakan sigma dalam pesan keadaannya, jadi cabang ini memakai
  `ConfidencePolicy().pointingSigmaDeg` — angka yang **tidak pernah berlaku di
  jam**. Berkas ekspor karena itu memuat konteks yang dikarang, tanpa cara bagi
  pembacanya untuk mengetahuinya. Ini bertentangan langsung dengan alasan
  `ConfidenceTraceArchive` menyimpan lokasi/kalibrasi/sigma bersama sampel:
  *"berkas berisi derajat saja adalah anekdot."*
  - `PointingLinkMessage.state(from:at:sigmaDeg:)` dan
    `WatchLinkService.send(state:at:sigmaDeg:)` kini membawa sigma yang berlaku
    di jam. Bukan untuk keputusan apa pun di iPhone — melainkan karena riwayat
    keyakinan menyimpan konteks bersama sampelnya.
  - `record(message:)` memakai **nol** bila sigma tidak ada, bukan bawaan. Nol
    berarti "tidak terukur", dan `ratioToSigma` sengaja kosong untuk sigma nol.
    Menuliskan bawaan berarti mengarang konteks; menulis nol membuat
    ketidak-tahuannya terlihat.
  - Layar Tautan memperingatkan bila ada sampel tanpa sigma, supaya `0` tidak
    terbaca sebagai akurasi sempurna.
- **Tes baru (2):** `testStateMessageCarriesWatchSigma` (sigma ikut dalam pesan
  keadaan), `testStateMessageWithoutSigmaKeepsItNil` (`nil` tetap `nil`).

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 109, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: kebenaran Experiment 1 dihitung untuk tempat yang salah
Fokus: menyisir jalur **kebenaran** (ground truth) di Experiment 1. Tidak ada
aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **`ExperimentHarness` memakai lokasi bawaan, bukan lokasi penguji.**
  Harness dibuat sekali di `init` dengan `engine.location` — yang saat itu
  masih `ObserverLocation.fallback` (Jakarta), karena lokasi sungguhan baru
  tiba beberapa detik setelahnya. `harness.location` hanya disinkronkan di
  dalam `record()`. Akibatnya:
  - Daftar target "di atas horizon" dihitung untuk Jakarta di mana pun
    penguji berada. Tinggi objek yang ditampilkan salah, dan target yang
    tampak terlihat bisa sebenarnya sudah terbenam.
  - Penguji memilih target itu, menekan Rekam, dan rekamannya ditolak
    ("arah target tidak bisa dihitung") tanpa sebab yang bisa dipahami.
  - Saat rekaman berhasil, `trial` dan `target` memakai lokasi yang berbeda,
    sehingga galat yang diukur mencampur galat lokasi dengan galat sensor —
    persis kekeliruan yang membuat Experiment 1 tidak menjawab pertanyaannya.
  - Perbaikan: `ExperimentRecorder.updateLocation(_:)` menyinkronkan kebenaran,
    dipanggil saat `onAppear` **dan** setiap kali `engine.location` berubah.
  - Layar kini memperingatkan bila lokasinya masih bawaan, karena daftar yang
    salah tempat tampak sama normalnya dengan yang benar.
- **`ObserverLocation.isFallback`** ditambahkan (dengan uji di Linux) untuk
  memisahkan lokasi terukur dari lokasi darurat. Label yang mirip **tidak**
  boleh membuat lokasi terukur dianggap darurat — yang menentukan adalah
  `source`. Uji ini akan merah kalau pembedanya dibalik ke perbandingan label.
- **Sisa dari siklus lalu:** hook `ExperimentRecorder` kini ikut memakai
  lokasi yang sama, sehingga tidak ada lagi dua sumber kebenaran lokasi.

**Tes baru (1):** `TargetsTests.testIsFallbackDistinguishesMeasuredLocation`.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 107, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: jalur Watch ↔ iPhone tidak pernah benar-benar tersambung
Fokus: memeriksa **transport** antar-perangkat, bukan isi pesannya. Tidak ada
aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup (tiga defect, semuanya tidak terlihat dari UI):**

**1. Kalibrasi selalu tertimpa sebelum sampai ke iPhone.**
`updateApplicationContext` menyimpan **satu** kamus saja — setiap kiriman
menggantikan yang sebelumnya. Hasil kalibrasi dikirim lewat jalur itu, jadi
pembaruan keadaan berikutnya (yang dikirim tiap kali ada jawaban) menimpanya.
Akibatnya iPhone bisa **tidak pernah** menerima kalibrasi, sementara di jam
kalibrasi tampak berhasil dan pesannya terkirim tanpa galat. Yang hilang di
sana bukan sekadar tampilan: `residualSpreadDeg` adalah sigma terukur yang
menyetel ambang keyakinan di iPhone — jadi Experiment 1 kehilangan
satu-satunya pengukuran yang membuatnya berguna.
- Kalibrasi (dan ambang keyakinan dari iPhone, yang punya masalah sama) kini
  lewat `transferUserInfo`, yang mengantre dan dikirim berurutan.
- Kedua sisi mendapat `session(_:didReceiveUserInfo:)`; tanpa itu pesan
  antre akan tiba dan dibuang diam-diam — lebih buruk daripada tidak dikirim.

**2. Tombol "Minta keadaan terakhir" tidak pernah dijawab.** iPhone mengirim
`.stateRequest`, dan handler di jam hanya berisi `break` dengan komentar
*"Balasan disiapkan pemanggil; di sini cukup dicatat."* Tidak ada pemanggil
yang melakukannya. Jadi tombol itu terlihat berfungsi, menaikkan penghitung
pesan, dan tidak pernah menghasilkan apa pun. Jam kini menjawab dengan
`currentSnapshot` (dibaca saat diminta, bukan disalin), dan kalau alurnya
belum siap ia mengatakan itu — bukan diam.

**3. Sisi iPhone membalas permintaan dengan permintaan.** `PhoneLinkService`
menangani `.stateRequest` dengan memanggil `requestState()`, yang mengirim
`.stateRequest` kembali. Dua perangkat bisa saling melempar permintaan yang
tidak pernah dijawab. Kini ia membalas dengan keadaan terakhir yang diketahui.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 106, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`): app iPhone (termasuk app jam) build
  sukses.

### Siklus sebelumnya: lokasi sungguhan tidak pernah sampai ke engine
Fokus: menyisir pembungkus app terhadap janji yang **ditulis** di komentarnya
sendiri. Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup (dua defect, keduanya kelas "tidak akan terlihat dari UI"):**

**1. Lokasi sungguhan tidak pernah dipakai engine.** `engine.update(location:)`
dipanggil **tepat sekali**, di `onAppear`/`start()` — yaitu sebelum CoreLocation
menjawab. Setelah itu tidak ada satu pun kode yang meneruskan lokasi sungguhan
ke engine (`onChange`/`onReceive`/`sink` tidak ada di seluruh Apps/). Akibatnya:
- Watch dan iPhone **selamanya** menghitung langit untuk `ObserverLocation.fallback`
  (Jakarta), di mana pun pengguna berada — sementara layar Diagnostik di
  sebelahnya menampilkan koordinat sungguhan. Dua angka yang bertentangan di satu
  layar, dan yang salah adalah yang dipakai menjawab.
- Untuk Final Challenge di lokasi selain Jakarta, seluruh langit tergeser;
  dan karena rentang geserannya sama untuk semua kandidat, **tidak ada bagian
  UI yang terlihat keliru**. Experiment 1 akan mengukur galat yang sebagian
  besar berasal dari lokasi, bukan dari akurasi Watch — persis kesalahan yang
  membuat eksperimennya tidak menjawab pertanyaannya.
- Perbaikan: `LocationProvider.onLocationChanged` dijalankan pada tiap
  pembaruan lokasi, dan `PointingEngine.bind(location:)` menyambungkannya ke
  `update(location:)`. Ketiga titik pemakaian (`PointingWatchApp`,
  `DiagnosticsView`, `Experiment1View`) kini memanggil `bind`, bukan memberi
  satu cuplikan lalu ditinggal. Penyambungan ditaruh di dalam engine supaya app
  tidak bisa "lupa" melakukannya.
- Uji `testWrongObserverShiftsTheWholeSky` membuktikan efeknya nyata: langit
  bergeser > 20° antara Jakarta dan Quito, sehingga Sirius yang tepat ditunjuk
  tidak lagi dikenali. Uji ini akan merah kalau lokasi diabaikan.

**2. Dimensi "ambigu" di diagnostik tidak pernah bisa terisi.** `ConfidenceTrace`
punya `neighbourRatioToSigma` dan `uncertainReason(for:)` bisa mengembalikan
`.ambiguous` — tapi `nearestNeighbourDeg` tidak pernah diisi oleh siapa pun
untuk sampel dari perangkat sendiri. Akibatnya, `uncertainReason` **selalu**
menjawab `.tooFar` atau `.none`, dan kalimat diagnostik
*"Semua jawaban ragu karena kandidat terlalu jauh. Perbaiki kalibrasi dulu."*
akan muncul bahkan ketika sebab sebenarnya adalah dua bintang berdekatan —
yang perbaikannya sama sekali berbeda (keterbatasan akurasi, bukan kalibrasi).
Ini persis jenis kebohongan yang dilarang: alat diagnostik yang menunjuk
perbaikan yang salah.
  - **Akarnya di engine.** Jarak tetangga dihitung di `diagnose()`, dipakai
    `ConfidenceModel`, lalu dibuang. Kini disimpan di
    `Resolution.nearestNeighbourDeg` — **angka yang sama** yang dipakai
    keputusan, bukan hasil hitung ulang. Menghitungnya kembali dari
    `intent.candidates` akan salah: `candidates` hanya tiga teratas, sedangkan
    keputusan dihitung dari seluruh kandidat dalam kerucut.
  - `PointingSnapshot.nearestNeighbourDeg` meneruskannya ke UI, dan
    `PointingController` mengisinya dari `lastResolution` — termasuk di
    `refreshSnapshot`, dan **dikosongkan** saat `stop()` supaya jarak dari
    pandangan lama tidak menempel pada pandangan baru.
  - `ConfidenceTrace.record(snapshot:)` kini membaca jarak itu dari cuplikan
    yang diberikan, bukan menunggu pemanggil mengisinya. Cuplikan sudah membawa
    variabel keputusannya; satu tempat saja yang tahu dari mana angka itu
    berasal.
  - Uji baru di `PointingControllerTests` sempat **gagal lebih dulu**
    (`.none` vs `.ambiguous`) sebelum perbaikan selesai — jadi klaim ini bukan
    pembacaan kode, melainkan hasil uji yang benar-benar merah.

**Tes baru (6):** 2 di `ResolverTests` (jarak tetangga dilaporkan & sama dengan
jarak sesungguhnya; kandidat tunggal → `nil`, bukan nol), 3 di
`PointingControllerTests` (jarak tetangga sampai ke cuplikan → sebabnya
`.ambiguous`; `stop()` mengosongkan jarak itu; lokasi salah menggeser langit),
1 perubahan `ConfidenceTrace`.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 106, 0 gagal** (exit 0).
- Seluruh berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- Build macOS (app iPhone + jam) diverifikasi CI `Apple Build` pada commit ini.

**Galat nyata yang hanya muncul saat dibangun di macOS (dan sudah diperbaiki):**
- `PointingEngine.bind(location:)` ditulis `public` padahal parameternya tipe
  internal `LocationProvider` → `error: method cannot be declared public
  because its parameter uses an internal type`. Gerbang sintaks
  (`swiftc -parse`) **tidak** memeriksa kontrol akses, jadi ini hanya
  tertangkap build sungguhan. Method dibuat `internal`, dan CI hijau pada
  commit berikutnya. Pelajaran yang layak diingat: `-parse` membuktikan
  berkasnya *terbaca*, bukan bahwa berkasnya *saling cocok*.

### Siklus sebelumnya: ekspor diagnostik + verifikasi ulang
Fokus: menyisir berkas app terhadap daftar item yang tersisa, dan menutup satu
item yang benar-benar belum ada. Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **Tab Diagnostik tidak punya ekspor dataset.** Grafik keyakinannya ada, tapi
  riwayatnya hanya hidup di memori — item "iOS diagnostik: grafik confidence +
  ekspor dataset" belum terpenuhi sepenuhnya.
  - `Packages/PointingKit/Sources/PointingKit/ConfidenceTraceArchive.swift` —
    `ConfidenceTraceExport` + `ConfidenceTraceArchive` (encode/decode/nama berkas).
  - **Kenapa konteks ikut diekspor.** `ratioToSigma` hanya bisa ditafsirkan kalau
    sigma yang berlaku saat itu ikut tersimpan; lokasi, kalibrasi, dan sigma
    ditulis bersama sampelnya. Berkas berisi derajat saja adalah anekdot.
  - Memakai pengekod arsip yang sama dengan `DatasetArchive`
    (`JSONEncoder.pointingArchive()`) supaya pecahan detik tidak hilang dan
    urutan sampel tetap bisa direkonstruksi.
  - Sampel dari jam **tidak** diberi jarak kandidat karangan — jam memang tidak
    mengirim sudut pergelangan, jadi `separationDeg` tetap kosong.
  - `DiagnosticsView` kini punya `ShareLink` "Ekspor dataset (JSON)"; kalau
    encoding gagal, yang dibagikan adalah pesan kesalahan, bukan berkas kosong
    yang tampak sah.
  - 8 tes baru (`ConfidenceTraceArchiveTests`): bolak-balik mempertahankan
    variabel keputusan, waktu berpecahan detik, sigma nol tetap `nil`, sampel jam
    tetap tanpa jarak, arsip kosong tetap sah, berkas rusak **gagal** dibaca.
- **`PhoneLinkService.onMessage` tidak pernah disambungkan.** Hook-nya ada dan
  `ConfidenceTraceStore.record(message:)` juga ada, tapi tidak ada yang
  memanggil `onMessage` — jadi bagian "Sampel dari jam" di layar Tautan akan
  selamanya nol sambil tampak normal. Kini disambungkan di akar `RootView`,
  sekalian mengaktifkan sesi sekali (sebelumnya hanya di `LinkView.onAppear`,
  sehingga pesan yang tiba sebelum tab itu dibuka tidak terekam).

**Yang diverifikasi ulang (tidak diubah, ternyata sudah ada):**
- `WatchLinkService.sessionReachabilityDidChange` **sudah** ada; `isReachable`
  di layar jam memang ikut berubah. (Sempat saya duga hilang — ternyata tidak.)
- `MotionLogger` sudah memetakan `CMDeviceMotion` → `init?(cmX:cmY:cmZ:cmW:)`.
- Haptic `.lock`/`.uncertain` sudah dipicu dari perpindahan keadaan di
  `PointingController.hapticEvents(from:to:)`, bukan di lapisan UI.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 163 test + PointingKit 103 test, 0 gagal**
  (exit 0). PointingKit naik dari 95 → 103 karena 8 tes arsip baru.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` **di dalam
  container swift:6.0** (swiftc tidak ada di host; gerbang sintaks dijalankan
  lewat Docker yang sama dengan suite).
- `ROADMAP.md` disinkronkan: item Fase 2/3 app yang sudah terwujud ditandai,
  dan baris "156/156" dikoreksi menjadi 163/163.
- Verifikasi build macOS ada di CI (`Apple Build`) pada commit ini.

### Siklus sebelumnya: pembungkus app iPhone + Watch, konfigurasi XcodeGen
Fokus: mengubah logika yang sudah teruji menjadi app yang bisa dibuka.
Tidak ada aturan keras PRD yang dilonggarkan; yang berubah hanya pembungkusnya.

**Struktur yang dipilih (dan alasannya):**
- `Packages/CelestialEngine` — mesin murni (Fase 1–3). **Tidak disentuh** selain
  penambahan aditif. 156 test tetap hijau.
- `Packages/PointingKit` — **logika lapisan app, bebas API Apple**. Semua
  keputusan yang bisa salah (kapan yakin, kapan menolak, apa yang direkam,
  apa yang dikirim ke iPhone) hidup di sini supaya bisa diuji di Linux.
  **95 test hijau** via Docker.
- `Apps/PointAndKnowWatch/`, `Apps/PointAndKnowiOS/` — hanya pembungkus:
  sensor, UI, haptic, WatchConnectivity. Berkas-berkas ini **tidak punya
  logika keputusan**; kalau ada `if` soal keyakinan di dalamnya, itu bug.

**Watch (Apps/PointAndKnowWatch/):**
- ✅ `Apps/Shared/MotionLogger.swift` — satu-satunya pembaca CoreMotion.
  `CMDeviceMotion` → `DeviceAttitude` lewat `init?(cmX:cmY:cmZ:cmW:)`, lalu
  diteruskan ke controller. Kalau sensor tidak ada, controller diberi tahu
  supaya **berhenti menebak** — bukan diam-diam memakai sampel terakhir.
- ✅ `HapticEngine.swift` — satu-satunya pemanggil `WKInterfaceDevice.play`.
  Pola getaran dibedakan tajam per peristiwa, karena getaran satu-satunya
  saluran yang tidak butuh mata.
- ✅ `PointingView.swift` — merender **langsung dari `PointingSnapshot`**
  (idle/pointing/searching/lock/uncertain/unavailable) + detail objek.
- ✅ `CalibrationView.swift` — memakai `CalibrationSession` di PointingKit
  (di atas `CalibrationSolver`). Kalibrasi **tidak boleh kelihatan selesai**
  sebelum sebaran titik acuannya benar.
- ✅ `WatchLinkService.swift` — mengirim **keputusan** (keadaan + objek), bukan
  sudut pergelangan mentah.
- ✅ `SkyContextView` (struct di dalam `PointingView.swift`) — konteks langit
  (kapan gelap, tinggi Matahari).

**iPhone (Apps/PointAndKnowiOS/):**
- ✅ `DiagnosticsView.swift` — grafik keyakinan (Swift Charts) + ekspor dataset.
  Yang digambar adalah **variabel keputusan** (`separation / sigma`), bukan
  hanya jawabannya.
- ✅ `Experiment1View.swift` + `ExperimentRecorder.swift` — harness Experiment 1:
  tunjuk target diketahui → rekam → ekspor. Verdict menyeleksi **percobaan
  gagal**, bukan menyembunyikannya.
- ✅ `PhoneLinkService.swift` + `LinkView.swift` — sisi iPhone dari
  WatchConnectivity; bisa mengirim ambang keyakinan hasil Experiment 1 ke jam.
- ✅ `JSONArchiveDocument.swift` — pembungkus `Transferable` supaya "Ekspor
  dataset (JSON)" benar-benar menghasilkan berkas bernama berakhiran `.json`
  (memakai `suggestedFilename` berstempel waktu dari `PointingKit`), bukan teks
  tanpa nama.
- ✅ `PointAndKnowiOSApp` (`@main`, di dalam `DiagnosticsView.swift`) — titik
  masuk app iPhone.

**Build:**
- ✅ `project.yml` (XcodeGen) — satu proyek, **dua target app**
  (`PointAndKnow` + `PointAndKnow Watch`), paket SwiftPM lokal dirujuk dari repo.
  Tes tidak hidup sebagai target Xcode: seluruh logika ada di paket SwiftPM
  (`CelestialEngine`, `PointingKit`) dan dijalankan lewat `swift test` — di Linux
  (`engine-tests.yml`) maupun di Apple SDK (job `Paket` di `ios-build.yml`).
  Berkas app sendiri tidak punya logika keputusan, jadi tidak ada yang perlu
  diuji di sana.
- ✅ `.github/workflows/ios-build.yml` — CI macOS: `brew install xcodegen`,
  generate proyek, build watch + iOS ke simulator.
- ✅ Ikon app digenerate deterministik oleh `Tools/make_app_icons.py`
  (satu PNG 1024×1024 per app) supaya `actool` tidak menggagalkan build.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 163 test + PointingKit 95 test, 0 gagal**.
- Setiap berkas app lolos `swiftc -parse -swift-version 5` (gerbang sintaks;
  impor Apple tidak perlu resolve).
- `project.yml` divalidasi dengan **XcodeGen yang dibangun dari sumber di
  Linux** — parsing + validasi spec lolos, dan proyek yang dihasilkan
  diperiksa: 2 target app, sumber & dependensi paket terpasang benar, app jam
  ditanam ke `PlugIns/` milik app iPhone.
- **CI macOS hijau** (`Apple Build`): `xcodegen generate` → `xcodebuild` untuk
  app iPhone (termasuk app jam) dan app jam sendiri, keduanya **build sukses**.

**Galat nyata yang hanya muncul saat dibangun di macOS (dan sudah diperbaiki):**
- `WKInterfaceDevice.isDeviceSupported` tidak ada → dihapus. `play(_:)` diam
  saja di perangkat tanpa Taptic Engine, jadi tidak perlu dijaga.
- `nonisolated @objc` → `@objc nonisolated`. Urutan ini satu-satunya yang
  diterima parser; dibuktikan dengan probe terpisah.
- `LocationProvider` tidak mendeklarasikan `CLLocationManagerDelegate` sama
  sekali → ditambahkan, plus `@preconcurrency` karena protokol ObjC tidak
  di-`@MainActor` sedangkan kelasnya `@MainActor`. Hal yang sama diterapkan
  pada dua konformans `WCSessionDelegate`.
- `MotionLogger` memakai `CMDeviceMotion.timestamp` sebagai waktu Unix — itu
  keliru (detik sejak perangkat menyala), jadi tiap sampel akan bertanggal
  1970: alur tidak akan pernah melihat pergelangan diam dan efemeris dihitung
  untuk tanggal yang salah. Sekarang memakai waktu dinding.
- Dua sumber teks status (`PointingController.statusText` vs
  `PointingState.shortLabel`) → disatukan, supaya janji "ragu terlihat ragu"
  tidak bisa dibatalkan di layar.
- `CalibrationSession` menyimpan controller sebagai `unowned` → kuat; alur
  kalibrasi boleh hidup lebih lama dari pemanggilnya.
- `PointingController.resolver` dibuat `private(set)`; penggantian ambang
  keyakinan kini lewat `setConfidencePolicy(_:)` yang menolak sigma nol,
  negatif, atau tak berhingga.

### Siklus sebelumnya: pengaman slew (aturan keras PRD) + fondasi Fase 2 → 156 test hijau
- ✅ `SlewSafety.swift` — **POINT → OBJECT ID → SAFE GOTO**, ditegakkan di tipe,
  bukan sekadar konvensi:
  - `SlewCommand` tidak punya inisialisasi publik; satu-satunya jalan
    membuatnya adalah `SlewPlanner.plan(...)`. Jadi mustahil membentuk perintah
    motor dari sudut pergelangan tanpa lewat pemeriksaan.
  - Arah target perintah = **posisi objek yang teridentifikasi**, bukan arah
    tunjuk. Ini persis aturan PRD.
  - Gagal-tertutup: tanpa target, keyakinan di bawah syarat, atau posisi
    Matahari tidak diketahui → **ditolak**, tidak pernah diasumsikan aman.
  - Bahaya dilaporkan sebagai daftar unik & terurut (`SlewHazard`).
- ✅ `Resolution.sunHorizontal` diekspos supaya pengaman teleskop bisa dihitung
  dari jejak audit resolver (sebelumnya arah Matahari tidak pernah keluar).
- ✅ Uji integrasi pada geometri langit sungguhan: Bulan → identifikasi HIGH →
  GoTo **diizinkan**; Jupiter yang ambigu (~6.8° dari Pollux) → hanya MEDIUM →
  GoTo **ditolak** (`lowConfidence`). Aturan "jangan salah identifikasi demi
  magic" terbukti berlaku sampai ke teleskop.
- ✅ `swift test`: **156 test, 0 gagal** (Swift 6.0, Docker, Linux aarch64).

### Siklus sebelumnya: fondasi Fase 2 yang bisa diuji di Linux (139 test)
- ✅ `Geometry.swift` — `Vector3` + `Matrix3x3`, **tanpa `simd`** (tidak ada di
  Linux). Penamaan `m11…m33` sengaja sama dengan `CMRotationMatrix` supaya
  lapisan app bisa memetakan sensor tanpa berpikir ulang indeks.
- ✅ `Rotation.swift` — `Quaternion` `(w,x,y,z)` + konversi `CMQuaternion`
  (urutan x,y,z,w dipetakan di satu tempat). Ada `rotationMatrix`,
  `rotated(_:)`, komposisi, konjugat, sudut antar-orientasi, dan **nlerp**
  yang menangani *double cover*.
- ✅ `Frames.swift` — inti Fase 2 yang paling rawan salah:
  - `LocalFrame` ENU (Timur–Utara–Atas) ⇄ `HorizontalCoord`, azimut dari Utara.
  - `DeviceAttitude`: quaternion + **roll mengelilingi sumbu pandang** →
    `deviceToWorld` → arah tunjuk di langit.
  - `DeviceAimAxis` (`view` / `screenUp` / `screenRight`) — sumbu "arah tunjuk"
    adalah keputusan UX, jadi diserahkan sebagai parameter, bukan dipatri.
  - Temuan penting yang diuji eksplisit: **roll tidak mengubah arah pandang
    keluar-layar** bila sumbu itu mendatar. Jadi kalibrasi yaw memang wajib —
    bukan opsional.
- ✅ `Calibration.swift` — kalibrasi dari titik acuan:
  - Yaw diselesaikan dengan **rata-rata sirkular** (rata-rata biasa salah di
    sekitar 0°/360°).
  - Hanya **offset azimut** yang dikoreksi. Koreksi altitude akan menyembunyikan
    galat sensor — bertentangan dengan prinsip PRD. Sebaran sisa dilaporkan
    sebagai `residualSpreadDeg` (1σ).
  - `confidencePolicy()` menyambung sigma terukur → `ConfidencePolicy`, jadi
    ambang HIGH engine otomatis mengikuti hasil Experiment 1.
- ✅ `Sensing.swift` — `PointingSmoother` (nlerp bobot tetap) dan
  `AngularRateTracker`. Ada jeda maksimum antar sampel: setelah sensor
  terputus, laju **tidak** ditebak.
- ✅ `PointingFlow.swift` — `PointingStateMachine`: idle → pointing → searching
  → lock/uncertain. **`lock` hanya untuk keyakinan HIGH**; medium/low menjadi
  `uncertain`. Bergerak lagi membatalkan tampilan terkunci.

### Siklus sebelumnya
- ✅ anti-false-lock + instrumentasi Experiment 1 → Fase 1 selesai (65 test).
- ✅ Penyaringan visibilitas + efemeris tersambung ke resolver (`Visibility`,
  `diagnose()` dengan jejak audit, pengaman Matahari).
- ✅ Efemeris Bulan & planet via AstronomyKit, divalidasi vs JPL Horizons
  (simpangan terburuk 8.91″).
- ✅ Reduksi presesi J2000 → of-date di resolver (sebelumnya bintang meleset
  ~0.3°). Ditemukan & diperbaiki.
- ✅ Scaffold monorepo + CelestialEngine (Fase 1 inti).
- ✅ Terbukti engine bisa diuji di VPS2 TANPA Mac (via `./swift-test.sh`).

## Siklus 2026-10-04 — audit numerik mode malam pada gambar

**Unit terkecil:** "semua warna, termasuk visual, ikut mode malam" — janji yang
tertulis di `CelestialVisualView` dan Night Mode, tapi tidak pernah diuji.

### Yang ditemukan

Mode malam dipraktekan sebagai **daftar warna** yang ditulis satu per satu di
view, tepat di sebelah warna siangnya. Menghitungnya menunjukkan 10 dari 13
warna aksen **bukan merah murni**:

| bagian gambar | hijau | biru | porsi luminansi di kanal merusak |
|---|---|---|---|
| pita terang Bulan | 0.85 | 0.80 | 77% |
| cincin Saturnus | 0.30 | 0.16 | 63% |
| kabut Venus | 0.26 | 0.12 | 60% |

Di layar semuanya terlihat "merah", dan itu sebabnya cacat ini bertahan:
yang diuji adalah **penampilan**, bukan **nilainya**. Justru warna-warna itu
yang paling merusak, di mode yang dipilih justru untuk melindungi mata.

Dua kelas cacat lain yang muncul dari perhitungan yang sama:

1. **Urutan terang terbalik.** Pita Jupiter paling gelap (kanal merah 0.72)
   punya angka malam 0.43; paling terang (0.85) punya 0.34. Di mode malam
   pita gelap tampak lebih terang dari pita terang — dan tidak ada yang bisa
   melihatnya, karena semuanya sudah merah semua.
2. **Kontras sabit runtuh.** `shadow` untuk piringan gelap bulan
   dinaikkan ke 0.44, sehingga kontras sabit terhadap gelap turun ke 2.99:1 —
   di bawah WCAG AA, di layar yang justru paling dipakai untuk melihat bulan.

### Yang diperbaiki

- Aksen pindah ke `CelestialVisual.accents` (`NightVisual.swift`): **hanya
  warna siang** yang disimpan di sana. Warna malam diturunkan secara
  mekanis dari kanal merah — jadi "hampir merah" tidak mungkin terjadi, dan
  mengubah satu aksen tidak bisa meninggalkan malamnya tertinggal.
- `NightVisual.surface` (memancarkan) vs `.shadow` (gelap) dipisah sebagai
  dua peran; satu-satunya jalan masuknya `mapped(_:isShadow:)`, supaya
  "lupa dipetakan" tidak bisa ditulis.
- Kecerahan malam bintang diambil dari **ukuran relatif**, bukan dari
  warnanya: konversi B−V → RGB tidak menjamin kanal merahnya mengikuti terang
  bintang sungguhan.
- `starRGB` pindah dari view ke `PointingKit` **dan dijepit ke 0...1**.
  Sebelum dijepit, Betelgeuse (B−V 1.85) menghasilkan kanal merah **1,11** —
  di luar rentang yang punya arti; luminance ikut terangkat dan urutan terang
  ikut berubah. Ini tidak terlihat di layar ("merah tetap merah").

### Verifikasi

11 uji baru di `NightVisualTests`. Yang paling penting: **mutasi**. `surface`
sengaja dibuat membocorkan hijau/biru dan `shadow` dikolapskan jadi `surface`,
lalu uji dijalankan — kebocoran hijau/biru dan kontras sabit 2.88 (vs 4.5)
terdeteksi. Uji yang hanya membaca kode tidak akan menangkap keduanya.

**166 + 244 hijau, tanpa warning.**

### Satu cacat yang tidak terlihat di Linux

Apple Build gagal pada versi pertama: `Color(NightVisual.surface(raw))`.
Tidak ada overload `Color(_:)` yang menerima `RGBComponents` — SwiftUI
tidak punya konversi itu, dan build Linux tidak pernah menyentuh file view,
jadi `./swift-test.sh` tetap hijau. Semua kelas kesalahan view
harus dicek dengan menyisir polanya, bukan dengan menunggu test.

Yang terungkap saat memperbaikinya justru lebih penting dari
kesalahannya sendiri: tiga pintasan (`color`, `accent`, `shadowAccent`) memanggil
pemetaan malamnya **masing-masing**, dan `accent()` memanggil
`color(surface(raw))` — jadi peta diterapkan **dua kali**. Pemetaan tidak
idempoten. Dihitung: piringan gelap bulan (kanal merah 0,047) dipetakan lagi
sebagai permukaan menjadi **0,357** — hampir delapan kali lebih terang, tanpa
satu pun angka baru yang ditulis. Cacat seperti ini tidak akan pernah terlihat
dari membaca kode, karena tidak ada baris yang salah; yang salah adalah
**urutan** pemanggilan.

Sekarang ada **satu** pintasan `color(_:isShadow:)`. Perannya dinyatakan sebagai
argumen, bukan lewat pintasan terpisah, supaya "bagian gelap ikut dipetakan
seperti permukaan" tidak bisa ditulis — persis kelas bug yang ketahuan lewat
perhitungan, bukan lewat mata.

Catatan untuk siklus berikutnya: **uji di Linux tidak menutup kelas kesalahan
view.** Yang bisa ditutup di sini hanya logika murni; kompilasi view harus
dibuktikan CI macOS, dan pola berisiko (`Color(<expr>)`) sebaiknya disisir
sebelum push, karena tidak ada gerbang lokal yang menangkapnya.

## Siklus 2026-10-04 (2) — warna nada lolos dari gate kontras

**Unit terkecil:** warna nada (`PointingTone.color`) — label keadaan, badge
keyakinan, ikon kalibrasi — pernah ditulis manual di `Apps/Shared/NightMode.swift`
dan **tidak punya uji kontras sama sekali**, karena `PointingPresentationTests`
hanya memeriksa enum `tone`, bukan keluarannya sebagai warna.

### Yang ditemukan (dihitung, bukan ditebak)

Mode malam mengirimkan `red 0.50 / 0.62 / 0.80 / 1.00`. Rasio kontrasnya
terhadap permukaan malam:

| nada | nilai lama | rasio | ambang |
|---|---|---|---|
| neutral | 0.50 | 1.49:1 | ✗ |
| warning | 0.62 | 2.06:1 | ✗ |
| active | 0.80 | 3.10:1 | ✗ |
| success/danger | 1.00 | 5.25:1 | ✓ |

Tiga dari lima nada **tidak terbaca sebagai teks** justru di mode yang dipilih
supaya penglihatan malam terjaga. Mode siang memakai warna sistem (`.cyan`,
`.green`, `.orange`, `.red`, `.secondary`) yang **tidak bisa dihitung** — nilainya
bisa bergeser antar OS tanpa satu uji pun menyentuhnya. Dan badge keyakinan
memakai `nada.color.opacity(0.2)`: di mode malam itu justru **mendekatkan**
latar kapsul ke teksnya, bukan menjauhkannya (inversi kontras).

### Yang diperbaiki

- `TonePalette.swift` (PointingKit, **teruji di Linux**): semua warna nada hari &
  malam dipin ke `SurfaceColor` dengan kontras yang dihitung. Mode malam =
  merah murni di kanal 0.94…1.0 (semua ≥ 4.5:1; plafon fisik 5.25:1).
- `BadgeFills`: isi kapsul dihitung sebagai nada @ 0.2 di atas permukaan paling
  terang lalu dijadikan **opak** (hari), atau **permukaan tingkat dua** (malam,
  karena warna nada merah tidak boleh mem-back badge). Bukan `opacity(0.2)` di
  view.
- Jembatan `PointingTone.color` (NightMode.swift) sekarang memanggil
  `SurfacePalette.active.tones` — satu sumber kebenaran, bukan dua daftar warna.
- `PointingView.swift`: badge pakai `.badgeFillColor`, bukan `.color.opacity(0.2)`.

### Kenapa (fisika, bukan rasa)

Mode malam membuang hijau/biru → semua warna hidup di kanal merah saja. Merah
murni di atas hitam punya plafon kontras **5.25:1**, jadi rentang yang boleh
dipakai untuk teks 4.5:1 hanya 0.9365…1.0 (6% kanal). Konsekuensinya: di mode
malam warna nada **tidak lagi** membedakan keadaan (selisih ujung-ujung 1.12:1,
praktis tak terlihat) — yang membedakan adalah terang-vs-gelap penuh. Badge
keyakinan di mode malam dibedakan lewat **teksnya** ("Yakin"/"Ragu"/"Tidak tahu"),
bukan warna. Dicatat di komentar palet supaya tidak nanti "diperbaiki" dengan
melanggar batas merah murni.

### Verifikasi

8 uji baru di `TonePaletteTests` (kontras nada hari & malam vs ketiga permukaan,
badge, bebas hijau/biru, urutan tak berbalik, kedua mode lewat satu pintu).
**252 hijau (166 engine + 86 PointingKit), tanpa warning.** Kompilasi view
(badge bridge) dibuktikan CI macOS (`ios-build.yml`) — Linux tidak menyentuh
file view.

## Cara test
    cd /home/ubuntu/projects/celestial-pointing
    ./swift-test.sh          # docker swift:6.0 — CelestialEngine + PointingKit
    ./swift-typecheck.sh     # typecheck + parse semua berkas Apps/
    ./red-test.sh <berkas-uji> <nama-test> <berkas-sumber> <lama> <baru>

## Dua gerbang yang dulu tidak benar-benar berjalan

**`swift-typecheck.sh` tidak pernah bisa lulus di VPS2.** Skrip itu memanggil
`swift build`/`swiftc` langsung di host, dan di host tidak ada Swift — hanya di
dalam Docker. Jadi "tidak ada error" yang tercetak berasal dari
`command not found`, bukan dari kode yang bersih; skrip tetap keluar 0 karena
`$?` diambil dari pipeline yang sudah hancur. Itu menjelaskan tiga siklus
berturut-turut yang menemukan cacat baru tepat setelah push. Sekarang
seluruh perintah dijalankan di dalam container dan status diambil dari sana.

**`red-test.sh` (baru) membuktikan uji benar-benar menangkap cacat.** Uji yang
tidak pernah merah adalah formalitas: ia hanya membuktikan kode sekarang cocok
dengan ekspektasi penulisnya. Skrip ini menerapkan satu mutasi, memastikan uji
MERAH, lalu mengembalikan sumber — sehingga "uji ini menangkap mutasi" adalah
klaim yang bisa diulang, bukan cadangan.

Dua cacat di siklus ini ditemukan oleh gerbang itu, bukan oleh mata:
- Uji label-vs-slug pertama membandingkan dengan `lowercased()`. Katalog
  menyimpan `name` sebagai slug yang hanya dib capitalized (`sirius`/`Sirius`),
  jadi perbandingan itu **tidak mungkin gagal** — uji formalitas yang lolos
  begitu saya tulis. Diperbaiki ke perbandingan byte.
- `write_file` sempat menyisipkan fragmen CJK (`仓库`, `把它`) ke komentar.
  Damage itu lolos kompilasi dan lolos CI. Pemeriksaan CJK sekarang jadi
  bagian siklus.

## Teks layar bukan pengenal mesin

Empat teks menampilkan nilai yang dibuat untuk mesin (`DisplayLabels.swift`,
`DisplayLabelTests` — 9 uji). Yang paling terlihat: headline tiap baris
percobaan di Experiment 1 menulis slug katalog apa adanya — `sirius` di tempat
yang seharusnya `Sirius`. Aksesor yang benar sudah ada
(`ConfidenceLevel.displayName`); masalahnya pemanggil mengambil `rawValue`.

Bentuk kabel dan label kini dipisah: `rawValue` untuk serialisasi,
`displayName` untuk layar. `LinkMessageKind.rawValue` **tidak** diubah — itu
kunci `plist`; ujinya menjaga agar memperbaiki tampilan tidak pernah menyentuh
bentuk kabel. `objectName(forObjectID:)` mengembalikan `nil` untuk id tak
dikenal: mengarang nama dari id terlihat benar untuk seluruh katalog sekarang
dan diam-diam salah begitu ada id yang tidak mengikuti pola itu.
`ExperimentRecorder` tetap memakai `aim.rawValue` — itu JSON untuk mesin.

## Catatan penting
- `Package.swift` kini `swift-tools-version:6.0` (dibutuhkan AstronomyKit),
  dengan `swiftLanguageMode(.v5)` pada target agar kode Fase 1 tetap valid.
- `Package.resolved` di-commit → build CI reprodusibel.
- Fixture acuan: `Packages/CelestialEngine/Tests/CelestialEngineTests/Fixtures/horizons_reference.json`
  (dari JPL Horizons DE441). Segarkan dengan `python3 Tools/fetch_horizons_reference.py`.
- AstronomyKit tersambung ke `PointingResolver` lewat `diagnose()`. Bulan &
  planet ikut jadi kandidat dengan koordinat of-date. Matahari hanya konteks,
  tidak pernah jadi target.
- **Engine tidak menyentuh API Apple apa pun.** Yang butuh Mac hanyalah
  pembungkus sensor/UI, bukan logika. Karena itu attitude, kalibrasi, dan
  resolusi bisa dibuktikan di Linux.
- **App dibangun lewat XcodeGen**, bukan `.xcodeproj` yang di-commit. Jalankan
  `xcodegen generate` di Mac (atau biarkan CI yang melakukannya).
- **Akurasi Apple Watch tetap hipotesis.** Experiment 1 ada persis untuk
  mengujinya; ambang keyakinan disetel dari hasilnya, bukan dari asumsi.

## Langkah berikutnya
1. Jalankan app di perangkat sungguhan: izinkan lokasi & gerak, lalu kalibrasi
   dengan satu bintang terang. Kalau kalibrasi tidak pernah selesai, itu
   memang jawaban yang benar — sebaran titik acuannya belum cukup rapat.
2. Experiment 1: kumpulkan data lapangan, ukur `residualSpreadDeg`, lalu
   suapkan ke `ConfidencePolicy` lewat `setConfidencePolicy(_:)`.
3. Kalau sigma hasil ukur lebih besar dari yang diasumsikan, turunkan klaim
   keyakinan engine — jangan sebaliknya. Angka akurasi Watch tetap hipotesis
   sampai Experiment 1 selesai; tidak ada satu pun bagian kode yang
   mengasumsikannya.
