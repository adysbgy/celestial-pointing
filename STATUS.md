# STATUS — Celestial Pointing Engine

## Progres terakhir (3 Okt 2026)

### Siklus ini: fondasi Fase 2 yang bisa diuji di Linux → 139 test hijau
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
    ambang HIGH engine otomatis mengikuti hasil Experiment 1. Uji
    `testSmallerSigmaAllowsHighWhereLooseSigmaDidNot` membuktikan efeknya.
- ✅ `Sensing.swift` — `PointingSmoother` (nlerp bobot tetap) untuk meredam
  gemetar tangan, dan `AngularRateTracker` untuk mengukur kecepatan sudut.
  Ada jeda maksimum antar sampel: setelah sensor terputus, laju **tidak**
  ditebak (membagi jeda panjang menghasilkan laju palsu yang kecil).
- ✅ `PointingFlow.swift` — `PointingStateMachine`: idle → pointing → searching
  → lock/uncertain. Sumber resolusi disuntikkan sebagai closure, jadi seluruh
  alur bisa diuji di Linux. Aturan yang dipegang: **`lock` hanya untuk keyakinan
  HIGH**; medium/low menjadi `uncertain`. Bergerak lagi membatalkan tampilan
  terkunci. Sampel pertama & jeda dianggap "masih bergerak" (arah aman).
- ✅ Uji rantai penuh tanpa sensor: `FramesTests` membangun attitude sintetis
  yang mengarah ke Sirius, lalu resolver harus mengembalikan "sirius". Ini
  memvalidasi seluruh konversi ENU ↔ kerangka perangkat dua arah.
- ✅ `swift test`: **139 test, 0 gagal** (Swift 6.0, Docker, Linux aarch64).

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
    ./swift-test.sh          # docker swift:6.0 (image sudah ter-cache)

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
  pembungkus sensor/UI (Fase 2 app), bukan logika. Karena itu attitude,
  kalibrasi, dan resolusi bisa dibuktikan di Linux.

## Langkah berikutnya (sisa FASE 2 — app watchOS, butuh Mac)
Logika inti sudah ada & teruji; yang tersisa adalah pembungkus platform:
1. Motion logger: `CMDeviceMotion` → `DeviceAttitude` (lewat `init?(cmX:cmY:cmZ:cmW:)`)
   → `PointingSmoother` → `PointingStateMachine.update(...)` dengan
   `resolve:` = `PointingResolver.resolve` + `PointingCalibration.apply`.
2. Alur kalibrasi memakai `CalibrationSolver` (kumpulkan titik acuan → `apply`),
   lalu suapkan `residualSpreadDeg` ke `ConfidencePolicy` resolver.
3. Rendering UI langsung dari `PointingState` (idle/pointing/searching/lock/
   uncertain/unavailable) + detail objek dari `currentIntent`.
4. Haptic dipicu saat `state` berpindah ke `.lock` (sukses) dan `.uncertain`.
5. Watch ↔ iPhone (WatchConnectivity).

Catatan: unit test engine tetap jalan di Linux, tapi Fase 2 app butuh Mac untuk
build/run watchOS. Engine TIDAK boleh bergantung pada API Apple (sudah bersih).
