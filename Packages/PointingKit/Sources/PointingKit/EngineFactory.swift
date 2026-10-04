import Foundation
import CelestialEngine

/// Perakitan engine untuk aplikasi.
///
/// Ada di sini (bukan di dalam app) supaya konfigurasi produksi — katalog apa,
/// ambang visibilitas apa, efemeris hidup atau tidak — bisa diuji di Linux dan
/// tidak berbeda diam-diam antara app Watch dan app iPhone. Kalau kedua app
/// merakit resolver sendiri-sendiri, cepat atau lambat keduanya akan memakai
/// ambang yang berbeda dan hasil eksperimennya jadi tidak bisa dibandingkan.
public enum EngineFactory {

    /// Katalog produksi: bintang terang + objek langit dalam.
    ///
    /// **Kenapa bukan `Catalogue.brightStars` langsung.** Sampai berkas ini
    /// diperbaiki, resolver produksi hanya pernah melihat bintang — padahal
    /// resolver, visual, label, dan pengucapan untuk objek langit dalam
    /// semuanya sudah ada dan teruji. Yang hilang hanya satu: tidak ada
    /// katalog yang memuat objek ber-`kind: .deepSky`, jadi jalur itu tidak
    /// pernah berjalan di aplikasi. Menggabungkannya di sini (satu tempat,
    /// teruji di Linux) menutupnya untuk **kedua** app sekaligus, bukan hanya
    /// yang kebetulan merakit resolver dengan katalog yang lebih luas.
    ///
    /// `Catalogue.brightStars` sendiri sengaja tidak disentuh: ia dikunci
    /// oleh uji engine (`testCatalogueNotEmpty`, `testAuditTrailIsConsistent`)
    /// dan oleh uji warna bintang yang menuntut **setiap** anggotanya
    /// ber-`kind: .star`. Menambah objek langit dalam ke sana akan memecahkan
    /// keduanya — dan keduanya benar: katalog itu memang katalog **bintang**.
    public static let productionCatalogue: [CelestialObject] =
        Catalogue.brightStars + DeepSkyCatalogue.objects

    /// Resolver produksi.
    ///
    /// - Parameters:
    ///   - catalogue: katalog bintang. Bawaan: katalog produksi (bintang
    ///     terang + objek langit dalam).
    ///   - policy: ambang visibilitas.
    ///   - confidencePolicy: ambang keyakinan. Ganti dengan hasil
    ///     `CalibrationFlow` begitu sigma pointing terukur.
    ///   - includeSolarSystem: sertakan Bulan & planet via efemeris.
    public static func makeResolver(
        catalogue: [CelestialObject] = productionCatalogue,
        policy: VisibilityPolicy = VisibilityPolicy(),
        confidencePolicy: ConfidencePolicy = ConfidencePolicy(),
        includeSolarSystem: Bool = true
    ) -> PointingResolver {
        PointingResolver(
            catalogue: catalogue,
            policy: policy,
            confidencePolicy: confidencePolicy,
            ephemeris: includeSolarSystem ? Self.defaultEphemeris : nil
        )
    }

    /// Efemeris bawaan bila modulnya tersedia di platform ini.
    ///
    /// Tanpa AstronomyKit, resolver tetap bekerja — hanya dengan bintang
    /// katalog. Yang **tidak** boleh terjadi adalah mengarang posisi Bulan.
    private static var defaultEphemeris: SolarSystemEphemeris? {
        #if canImport(AstronomyKit)
        return AstronomyKitEphemeris()
        #else
        return nil
        #endif
    }

    /// Resolver dengan ambang keyakinan yang berasal dari kalibrasi terukur.
    ///
    /// `nil` dari `confidencePolicy()` berarti sigma belum terukur — dalam hal
    /// itu ambang konservatif bawaan **tetap** dipakai, bukan diganti angka
    /// karangan. Ini aturan PRD: uncertainty > false confidence.
    public static func makeResolver(calibration: PointingCalibration,
                                    catalogue: [CelestialObject] = productionCatalogue,
                                    policy: VisibilityPolicy = VisibilityPolicy(),
                                    includeSolarSystem: Bool = true) -> PointingResolver {
        makeResolver(catalogue: catalogue,
                     policy: policy,
                     confidencePolicy: calibration.confidencePolicy() ?? ConfidencePolicy(),
                     includeSolarSystem: includeSolarSystem)
    }

    /// Controller produksi: resolver + lokasi + pengaturan alur.
    public static func makeController(location: ObserverLocation,
                                      calibration: PointingCalibration = .none,
                                      config: PointingControllerConfig = PointingControllerConfig(),
                                      includeSolarSystem: Bool = true) -> PointingController {
        PointingController(
            resolver: makeResolver(calibration: calibration, includeSolarSystem: includeSolarSystem),
            observer: location.observer,
            config: config,
            calibration: calibration
        )
    }
}
