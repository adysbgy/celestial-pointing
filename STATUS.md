# STATUS — Celestial Pointing Engine

## Progres terakhir (3 Okt 2026)

### Siklus ini: efemeris disambungkan ke resolver + penyaringan visibilitas
- ✅ `Visibility.swift` — `VisibilityPolicy`, `SkyContext`, `VisibilityFilter`.
  Alasan penolakan eksplisit: di bawah horizon, terlalu redup, siang,
  terlalu dekat Matahari. Semua ambang bisa dikalibrasi tanpa mengubah engine.
- ✅ `PointingResolver` dirombak: `diagnose()` mengembalikan `Resolution`
  berisi jawaban + jejak audit (kandidat yang ditolak & alasannya, kegagalan
  efemeris, jumlah benda yang dipertimbangkan).
- ✅ Bulan & planet kini ikut jadi kandidat, memakai koordinat of-date dari
  efemeris (tanpa presesi ganda).
- ✅ **Pengaman Matahari**: `EphemerisBody.pointableBodies` tidak memuat
  Matahari. Menunjuk teleskop ke Matahari merusak alat & mata, jadi Matahari
  tidak pernah masuk proses kandidat sama sekali — hanya dipakai sebagai
  konteks. Ada uji khusus untuk ini.
- ✅ Kebijakan `permissive` yang konsisten (sebelumnya bisa bertentangan
  dengan `context.isDark`; sekarang gelap/terang selalu dihitung dari
  `policy` + ketinggian Matahari).
- ✅ `swift test`: **42 test, 0 gagal** (Swift 6.0, Docker, Linux aarch64).

### Siklus sebelumnya
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

## Langkah berikutnya
1. Uji anti-false-lock: kandidat ambigu TIDAK boleh HIGH.
2. Instrumentasi/logging untuk Experiment 1.
