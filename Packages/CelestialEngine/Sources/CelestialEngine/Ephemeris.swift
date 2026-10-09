import Foundation

#if canImport(AstronomyKit)
import AstronomyKit
#endif

/// Benda tata surya yang didukung efemeris dinamis.
///
/// Matahari ada di sini **hanya sebagai konteks** (menentukan siang/malam dan
/// sudut aman teleskop). Matahari tidak pernah boleh menjadi kandidat target:
/// menunjuk teleskop ke Matahari merusak peralatan dan mata. Lihat
/// `EphemerisBody.pointableBodies`.
public enum EphemerisBody: String, CaseIterable, Equatable, Sendable {
    case sun, moon, mercury, venus, mars, jupiter, saturn

    /// Benda yang boleh menjadi target pointing. Matahari TIDAK termasuk.
    public static let pointableBodies: [EphemerisBody] = [
        .moon, .mercury, .venus, .mars, .jupiter, .saturn
    ]

    /// Apakah benda ini aman dijadikan target pointing.
    public var isPointable: Bool { self != .sun }

    /// Nama tampilan untuk UI, dalam bahasa aktif (`ObjectNameLocalization`).
    public var displayName: String {
        ObjectNameLocalization.name(forObjectID: rawValue, indonesian: indonesianName)
    }

    /// Nama Bahasa Indonesia (bahasa sumber).
    public var indonesianName: String {
        switch self {
        case .sun: return "Matahari"
        case .moon: return "Bulan"
        case .mercury: return "Merkurius"
        case .venus: return "Venus"
        case .mars: return "Mars"
        case .jupiter: return "Jupiter"
        case .saturn: return "Saturnus"
        }
    }

    /// Magnitudo khas saat paling terang — dipakai hanya sebagai prior,
    /// bukan pengganti perhitungan efemeris.
    public var typicalBrightestMagnitude: Double {
        switch self {
        case .sun: return -26.7
        case .moon: return -12.7
        case .mercury: return -1.9
        case .venus: return -4.9
        case .mars: return -2.9
        case .jupiter: return -2.9
        case .saturn: return -0.5
        }
    }
}

/// Satu sampel posisi benda tata surya.
///
/// `raDeg`/`decDeg` adalah koordinat **apparent of-date** (equator & equinox
/// tanggal pengamatan), bukan J2000. Ini penting: Bulan bergerak ~0.5°/jam,
/// dan menggunakan koordinat J2000 untuk Bulan akan salah ~0.4°.
public struct EphemerisSample: Equatable {
    /// Right ascension, derajat, apparent of-date.
    public var raDeg: Double
    /// Declination, derajat, apparent of-date.
    public var decDeg: Double
    /// Magnitudo tampak (visual) pada saat itu.
    public var magnitude: Double
    /// Radius sudut semu (derajat). Bulan ~0.26°, planet < 0.02°.
    public var angularRadiusDeg: Double
    /// Fraksi piringan yang menyala (0…1). Untuk bintang/planet jauh nilainya 1.
    public var illuminationFraction: Double

    public init(raDeg: Double, decDeg: Double, magnitude: Double,
                angularRadiusDeg: Double = 0, illuminationFraction: Double = 1) {
        self.raDeg = raDeg
        self.decDeg = decDeg
        self.magnitude = magnitude
        self.angularRadiusDeg = angularRadiusDeg
        self.illuminationFraction = illuminationFraction
    }
}

public enum EphemerisError: Error, Equatable {
    /// Backend efemeris tidak tersedia di platform/target ini.
    case backendUnavailable
    /// Benda tidak dikenal oleh backend.
    case unsupportedBody(String)
    /// Perhitungan gagal (mis. waktu di luar rentang yang didukung).
    case computationFailed(String)
}

/// Sumber posisi benda tata surya.
///
/// Kontrak: implementasi WAJIB mengembalikan koordinat apparent of-date.
/// Engine tidak boleh "menebak" posisi Bulan/planet; kalau efemeris tidak
/// tersedia, lebih baik gagal terang-terangan daripada memberi posisi salah
/// (PRD: uncertainty > false confidence).
public protocol SolarSystemEphemeris {
    /// Posisi tampak sebuah benda.
    /// - Parameters:
    ///   - body: benda yang diminta.
    ///   - date: waktu UTC pengamatan.
    ///   - observer: lokasi pengamat. `nil` = geosentris (pusat Bumi).
    ///     Untuk Bulan, perbedaan geosentris vs toposentris mencapai ~1°,
    ///     jadi pemanggil disarankan mengisi lokasi bila tersedia.
    func apparent(_ body: EphemerisBody, at date: Date, from observer: Observer?) throws -> EphemerisSample
}

public extension SolarSystemEphemeris {
    func apparent(_ body: EphemerisBody, at date: Date) throws -> EphemerisSample {
        try apparent(body, at: date, from: nil)
    }
}

#if canImport(AstronomyKit)

/// Backend produksi: AstronomyKit (Swift) di atas Astronomy Engine (C).
///
/// Akurasi divalidasi terhadap JPL Horizons di `EphemerisTests` — simpangan
/// < 10″ untuk Bulan & planet terang pada rentang 2000–2026, jauh di bawah
/// resolusi pointing manusia (derajat).
public struct AstronomyKitEphemeris: SolarSystemEphemeris {

    /// Jari-jari Bulan (km), untuk menghitung radius sudut semu.
    private static let moonRadiusKm = 1737.4
    /// 1 AU dalam km.
    private static let auKm = 149_597_870.7
    /// Jari-jari Bumi (meter). Astronomy Engine menempatkan observer geosentris
    /// di `height = -6378137` **meter**; salah satuan di sini menggeser Bulan
    /// ~0.8° karena parallax. Sudah pernah kejadian — lihat EphemerisTests.
    private static let geocentricHeightMeters = -6_378_137.0

    public init() {}

    public func apparent(_ body: EphemerisBody, at date: Date, from observer: Observer?) throws -> EphemerisSample {
        let time = AstroTime(date)
        let akObserver: AstronomyKit.Observer
        if let observer {
            akObserver = AstronomyKit.Observer(
                latitude: observer.latitudeDeg,
                longitude: observer.longitudeDeg,
                height: 0
            )
        } else {
            akObserver = AstronomyKit.Observer(
                latitude: 0,
                longitude: 0,
                height: Self.geocentricHeightMeters
            )
        }

        let celestial: CelestialBody
        switch body {
        case .sun: celestial = .sun
        case .moon: celestial = .moon
        case .mercury: celestial = .mercury
        case .venus: celestial = .venus
        case .mars: celestial = .mars
        case .jupiter: celestial = .jupiter
        case .saturn: celestial = .saturn
        }

        let eq: Equatorial
        let illum: Illumination
        do {
            eq = try celestial.equatorial(
                at: time,
                from: akObserver,
                equatorDate: .ofDate,
                aberration: .corrected
            )
            illum = try celestial.illumination(at: time)
        } catch {
            throw EphemerisError.computationFailed(String(describing: error))
        }

        var angularRadiusDeg = 0.0
        if body == .moon, eq.distance > 0 {
            let distanceKm = eq.distance * Self.auKm
            angularRadiusDeg = SkyMath.rad2deg(asin(min(1.0, Self.moonRadiusKm / distanceKm)))
        }

        return EphemerisSample(
            raDeg: eq.rightAscension * 15.0,
            decDeg: eq.declination,
            magnitude: illum.magnitude,
            angularRadiusDeg: angularRadiusDeg,
            illuminationFraction: illum.phaseFraction
        )
    }
}

#endif
