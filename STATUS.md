# STATUS — Celestial Pointing Engine

## Progres terakhir (3 Okt 2026)
- ✅ Scaffold monorepo + CelestialEngine (Fase 1 inti) selesai & TERUJI.
- ✅ `swift test` HIJAU: 8 test, 0 gagal (Swift 6.0, Docker, Linux aarch64).
- ✅ Terbukti engine bisa diuji di VPS2 TANPA Mac (via `./swift-test.sh`).

## Cara test
    cd /home/ubuntu/projects/celestial-pointing
    ./swift-test.sh          # docker swift:6.0 (image sudah ter-cache)

## Langkah berikutnya
1. Tambah Bulan & planet terang via AstronomyKit (ephemeris).
2. Visibility/context filtering (magnitude, di bawah horizon).
3. Uji anti-false-lock: kandidat ambigu TIDAK boleh HIGH.
4. Instrumentasi/logging untuk Experiment 1.
