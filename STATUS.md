# STATUS — Celestial Pointing Engine

## Ringkasan keadaan (4 Okt 2026, dini hari)

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

## Cara test
    cd /home/ubuntu/projects/celestial-pointing
    ./swift-test.sh          # docker swift:6.0 — CelestialEngine + PointingKit

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
