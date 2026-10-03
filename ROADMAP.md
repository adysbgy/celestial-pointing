# ROADMAP — Celestial Pointing Engine (Final Challenge)

Sumber kebenaran: PRD v0.4 (3 Okt 2026). Prinsip: POINT → UNDERSTAND → ACT.
Aturan: jangan asumsikan Watch akurat; uncertainty > false confidence;
jangan pernah wrist-angle → motor.

## FASE 1 — Engine (testable di Linux) 🔑
- [x] SkyMath: Julian date, GMST/LST, ekua→horizontal, jarak sudut (+test)
- [x] Katalog 20+ bintang terang (J2000)
- [x] PointingResolver: pointing+konteks → kandidat
- [x] ConfidenceModel: HIGH/MEDIUM/LOW (anti false-lock)
- [x] Tambah Bulan & planet terang (via AstronomyKit ephemeris) — divalidasi vs JPL Horizons, simpangan terburuk 8.91″
- [x] Visibility/context filtering (di bawah horizon, magnitude, siang/malam, pengaman Matahari)
- [x] Instrumentasi/logging untuk Experiment 1 (`ObservationLog`: `PointingTrial`, `TrialAnalysis`, `ExperimentSummary`, arsip JSON)
- [x] Uji: kandidat ambigu → tidak boleh HIGH (`ConfidenceTests`)

## FASE 2 — App watchOS
- [x] Matematika attitude bebas-Apple: `Vector3`/`Matrix3x3`/`Quaternion` (tanpa `simd`, teruji di Linux)
- [x] Attitude → pointing: kerangka ENU, pemetaan device→langit, roll sumbu pandang (`Frames.swift`)
- [x] Kalibrasi yaw + sigma pointing terukur dari titik acuan (`Calibration.swift`) — menyambung Experiment 1 ke `ConfidencePolicy`
- [x] Perata orientasi (nlerp) + pelacak kecepatan sudut (`Sensing.swift`) — syarat "pergelangan diam" sebelum mengunci
- [x] Mesin keadaan alur: idle → pointing → searching → lock/uncertain (`PointingFlow.swift`, sumber resolusi disuntik)
- [ ] Motion logger: CMDeviceMotion → rekam attitude + timestamp (butuh Mac)
- [ ] Calibration flow (uji beberapa metode) — UI/app, butuh Mac
- [ ] Rendering UI dari keadaan alur + detail (butuh Mac)
- [ ] Pemicu haptic dari state lock/uncertain (butuh Mac)
- [ ] Watch ↔ iPhone (WatchConnectivity) (butuh Mac)

## FASE 3 — iOS companion + POC
- [x] Pengaman slew (`SlewSafety.swift`): POINT → OBJECT ID → SAFE GOTO. Aturan "wrist angle TIDAK PERNAH → motor" ditegakkan di tipe: `SlewCommand` hanya bisa dibuat oleh `SlewPlanner`, dan perintah diturunkan dari objek teridentifikasi (arah target = posisi objek, bukan arah tunjuk). Gagal-tertutup: tanpa target/keyakinan cukup/Matahari tak diketahui → tolak.
- [ ] iOS diagnostik (grafik confidence, ekspor dataset)
- [ ] Experiment 1 harness: tunjuk target diketahui → rekam → ekspor
- [ ] Point & Slew POC 1 teleskop (setelah engine terbukti)

## Kriteria "ENGINE SIAP"
- [x] swift test hijau (156/156 di Linux, tanpa Mac)
- [x] Resolver mengembalikan objek benar untuk target diketahui
- [x] Tidak pernah HIGH saat kandidat ambigu (diuji eksplisit)
- [x] Apple build hijau (macOS) — diverifikasi di CI
- [x] Rantai attitude→resolver utuh & teruji tanpa sensor (attitude sintetis → bintang benar)
- [x] Slew hanya diizinkan dari objek teridentifikasi berkeyakinan tinggi; gagal-tertutup teruji
