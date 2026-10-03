# STATUS — Celestial Pointing Engine

## Progres terakhir (3 Okt 2026)

### Siklus ini: memasang kalibrasi yang sama mereset alur tanpa alasan
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
- ✅ `SkyContextView.swift` — konteks langit (kapan gelap, tinggi Matahari).

**iPhone (Apps/PointAndKnowiOS/):**
- ✅ `DiagnosticsView.swift` — grafik keyakinan (Swift Charts) + ekspor dataset.
  Yang digambar adalah **variabel keputusan** (`separation / sigma`), bukan
  hanya jawabannya.
- ✅ `Experiment1View.swift` + `ExperimentRecorder.swift` — harness Experiment 1:
  tunjuk target diketahui → rekam → ekspor. Verdict menyeleksi **percobaan
  gagal**, bukan menyembunyikannya.
- ✅ `PhoneLinkService.swift` + `LinkView.swift` — sisi iPhone dari
  WatchConnectivity; bisa mengirim ambang keyakinan hasil Experiment 1 ke jam.
- ✅ `PointAndKnowApp.swift` — titik masuk app iPhone.

**Build:**
- ✅ `project.yml` (XcodeGen) — satu proyek, empat target (2 app + 2 tes),
  paket SwiftPM lokal dirujuk dari repo.
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
