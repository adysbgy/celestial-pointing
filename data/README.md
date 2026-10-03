# data/
- `bright_stars.json` — katalog bintang terang (menyusul; sumber: engine Catalogue.swift)
- Dataset pointing (Experiment 1) akan disimpan di sini oleh motion logger.

## Golden reference efemeris
`horizons_reference.json` sengaja TIDAK ditaruh di sini melainkan di
`Packages/CelestialEngine/Tests/CelestialEngineTests/Fixtures/`, karena
SwiftPM hanya bisa memaketkan resource di dalam direktori paket.
Segarkan dengan `python3 Tools/fetch_horizons_reference.py`.
