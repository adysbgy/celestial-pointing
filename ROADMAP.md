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
- [ ] Instrumentasi/logging untuk Experiment 1
- [ ] Uji: kandidat ambigu → tidak boleh HIGH

## FASE 2 — App watchOS
- [ ] Motion logger: CMDeviceMotion → rekam attitude + timestamp
- [ ] Calibration flow (uji beberapa metode)
- [ ] UI: idle → pointing → searching → lock → uncertain → detail
- [ ] Haptic sukses + state uncertain
- [ ] Watch ↔ iPhone (WatchConnectivity)

## FASE 3 — iOS companion + POC
- [ ] iOS diagnostik (grafik confidence, ekspor dataset)
- [ ] Experiment 1 harness: tunjuk target diketahui → rekam → ekspor
- [ ] Point & Slew POC 1 teleskop (setelah engine terbukti)

## Kriteria "ENGINE SIAP"
- [ ] swift test hijau (semua)
- [ ] Resolver mengembalikan objek benar untuk target diketahui
- [ ] Tidak pernah HIGH saat kandidat ambigu
- [ ] Apple build hijau (macOS)
