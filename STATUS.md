# STATUS — Celestial Pointing Engine

## Progres terakhir (3 Okt 2026)

### Siklus ini: efemeris Bulan & planet, divalidasi terhadap JPL Horizons
- ✅ `Ephemeris.swift` — protokol `SolarSystemEphemeris` + backend
  `AstronomyKitEphemeris` (AstronomyKit 0.2.3 / Astronomy Engine 2.1.19, MIT).
- ✅ Benda didukung: Bulan, Merkurius, Venus, Mars, Jupiter, Saturnus.
  Koordinat **apparent of-date** (bukan J2000 — Bulan bergerak ~0.5°/jam).
- ✅ `EphemerisTests`: 6 test baru. **Simpangan terburuk vs Horizons 8.91″**
  (Saturnus), toleransi 30″. Uji ini memakai fixture Horizons yang di-commit,
  jadi deterministik dan tanpa jaringan.
- ✅ Bug ditemukan & diperbaiki: satuan `Observer.height` adalah **meter**,
  bukan km. Observer "geosentris" sebelumnya 6 km di bawah permukaan →
  Bulan meleset 0.8° karena parallax. Sekarang `-6378137` m.
- ✅ `swift test`: **14 test, 0 gagal** (Swift 6.0, Docker, Linux aarch64).

### Siklus sebelumnya
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
- AstronomyKit **belum tersambung ke `PointingResolver`**. Saat ini ia hanya
  penyedia posisi; katalog yang diresolusi masih bintang saja.

## Langkah berikutnya
1. Sambungkan efemeris ke `PointingResolver` (Bulan/planet jadi kandidat).
2. Visibility/context filtering (magnitudo, ambang ketinggian, cahaya siang).
3. Uji anti-false-lock: kandidat ambigu TIDAK boleh HIGH.
4. Instrumentasi/logging untuk Experiment 1.
