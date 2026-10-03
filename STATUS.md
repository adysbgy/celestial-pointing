# STATUS — Celestial Pointing Engine

## Progres terakhir (3 Okt 2026)

### Siklus ini: anti-false-lock + instrumentasi Experiment 1 → FASE 1 SELESAI
- ✅ `Confidence.swift` dirombak. Ambang keyakinan kini dinyatakan sebagai
  kelipatan **sigma pointing**, bukan turunan dari `coneDeg`. Sebelumnya
  ambang "pasti" ikut mengecil bila pengguna mempersempit kerucut pencarian —
  itu keliru: ketidakpastian tunjuk tidak berubah hanya karena kita mencari
  lebih sempit. `coneDeg` tetap menentukan siapa yang masuk pertimbangan.
- ✅ Ambiguitas diukur dari **jarak antar-kandidat** (`nearestNeighbourDeg`),
  bukan dari jarak masing-masing ke arah tunjuk. Dua benda bisa sama-sama
  dekat ke arah tunjuk tapi berjauhan satu sama lain; yang menentukan ragu
  atau tidak adalah yang kedua.
- ✅ Ambang ambiguitas inklusif (tepat di batas = masih ragu). Arah aman.
- ✅ `ConfidenceTests` (10 uji) — termasuk kasus ambigu wajib tidak HIGH.
- ✅ **Ditemukan lewat uji nyata**: Jupiter 2026-01-01 hanya ~6.8° dari Pollux,
  jadi engine dengan benar menolak HIGH saat ditunjuk ke Jupiter. Ini
  anti-false-lock bekerja pada geometri langit sungguhan, bukan hanya di
  unit test sintetis. (Diverifikasi dengan probe AstronomyKit.)
- ✅ `ObservationLog.swift` — instrumentasi Experiment 1: `PointingTrial`
  (arah tunjuk mentah + terkalibrasi, jawaban engine, label kebenaran),
  `TrialAnalysis` (galat tunjuk terukur, `isFalseLock`), `ExperimentSummary`
  (akurasi, median, p90, kriteria keselamatan), `TrialArchive` (JSON).
  Model di `Models.swift` kini `Codable`/`Sendable` agar bisa diekspor dari
  Watch/iPhone ke mesin analisis.
- ✅ `swift test`: **65 test, 0 gagal** (Swift 6.0, Docker, Linux aarch64).

### Siklus sebelumnya
- ✅ Penyaringan visibilitas + efemeris tersambung ke resolver (`Visibility`,
  `diagnose()` dengan jejak audit, pengaman Matahari). 42 test hijau.
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

## Langkah berikutnya (FASE 2 — app watchOS)
Fase 1 (engine) selesai: 65 test hijau, anti-false-lock teruji.
1. Motion logger: `CMDeviceMotion` → rekam attitude + timestamp.
2. Alur kalibrasi (uji beberapa metode).
3. UI: idle → pointing → searching → lock → uncertain → detail.
4. Haptic sukses + state uncertain.
5. Watch ↔ iPhone (WatchConnectivity).

Catatan: unit test engine tetap jalan di Linux, tapi Fase 2 butuh Mac untuk
build/run watchOS. Engine TIDAK boleh bergantung pada API Apple (sudah bersih).
