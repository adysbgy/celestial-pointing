# STATUS — Celestial Pointing Engine

## Progres terakhir (3 Okt 2026)

### Siklus ini: menutup rantai variabel keputusan yang putus di diagnostik
Fokus: menyisir pembungkus app terhadap janji yang **ditulis** di komentarnya
sendiri. Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup (satu rantai, bukan satu titik):**
- **Dimensi "ambigu" di diagnostik tidak pernah bisa terisi.** `ConfidenceTrace`
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
- **Verifikasi yang menangkapnya.** Uji baru di `PointingControllerTests`
  gagal lebih dulu (`.none` vs `.ambiguous`) sebelum perbaikan selesai — jadi
  klaim ini bukan pembacaan kode, melainkan hasil uji yang benar-benar merah.

**Tes baru (5):**
- `ResolverTests`: jarak tetangga dilaporkan **dan** sama dengan jarak
  sesungguhnya di langit (bukan sekadar "tidak nil"); kandidat tunggal → `nil`,
  bukan nol.
- `PointingControllerTests`: dua bintang berimpit → jarak tetangga sampai ke
  cuplikan, dan riwayat menyebut sebabnya `.ambiguous`; `stop()` mengosongkan
  jarak itu.
- 2 tes resolver + 2 tes controller + 1 perubahan `ConfidenceTrace` →
  **CelestialEngine 165, PointingKit 105, 0 gagal.**

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **165 + 105, 0 gagal** (exit 0).
- Seluruh berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- Build macOS (app iPhone + jam) diverifikasi CI `Apple Build` pada commit ini.

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
