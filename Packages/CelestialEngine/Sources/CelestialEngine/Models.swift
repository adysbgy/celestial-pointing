import Foundation

/// Pengamat di Bumi.
public struct Observer: Equatable, Codable, Sendable {
    public var latitudeDeg: Double
    public var longitudeDeg: Double
    public init(latitudeDeg: Double, longitudeDeg: Double) {
        self.latitudeDeg = latitudeDeg
        self.longitudeDeg = longitudeDeg
    }
}

/// Koordinat ekuatorial (J2000).
public struct EquatorialCoord: Equatable, Codable, Sendable {
    public var raDeg: Double
    public var decDeg: Double
    public init(raDeg: Double, decDeg: Double) {
        self.raDeg = raDeg
        self.decDeg = decDeg
    }
}

/// Koordinat horizontal (alt-az).
public struct HorizontalCoord: Equatable, Codable, Sendable {
    public var altitudeDeg: Double
    public var azimuthDeg: Double
    public init(altitudeDeg: Double, azimuthDeg: Double) {
        self.altitudeDeg = altitudeDeg
        self.azimuthDeg = azimuthDeg
    }
}

public enum ObjectKind: String, Equatable, Codable, Sendable {
    case moon, planet, star, deepSky
    /// Matahari hanya dipakai sebagai konteks, tidak pernah sebagai target.
    case sun
}

/// Benda langit di katalog.
public struct CelestialObject: Equatable, Codable, Sendable {
    public var id: String
    public var name: String
    public var kind: ObjectKind
    public var raDeg: Double
    public var decDeg: Double
    public var magnitude: Double
    public init(id: String, name: String, kind: ObjectKind,
                raDeg: Double, decDeg: Double, magnitude: Double) {
        self.id = id; self.name = name; self.kind = kind
        self.raDeg = raDeg; self.decDeg = decDeg; self.magnitude = magnitude
    }
}

public enum ConfidenceLevel: String, Equatable, Codable, Sendable {
    case high, medium, low
}

public struct Candidate: Equatable, Codable, Sendable {
    public var object: CelestialObject
    public var separationDeg: Double
    public init(object: CelestialObject, separationDeg: Double) {
        self.object = object; self.separationDeg = separationDeg
    }
}

/// Hasil resolusi niat: objek terbaik + tingkat keyakinan.
public struct CelestialIntent: Equatable, Codable, Sendable {
    public var level: ConfidenceLevel
    public var best: CelestialObject?
    public var candidates: [Candidate]
    public init(level: ConfidenceLevel, best: CelestialObject?, candidates: [Candidate]) {
        self.level = level; self.best = best; self.candidates = candidates
    }
}

/// Nama tampilan objek dalam bahasa aktif (ADR-007).
///
/// Nama di engine ditulis dalam Bahasa Indonesia ("Saturnus", "Galaksi
/// Andromeda"). Engine tidak tahu katalog string app, jadi app memasang
/// `lookup` (lewat `TextLocalization.install`) dan nama dibentuk saat objek
/// dibuat. Kunci: `object.name.<id>`. Tanpa `lookup`, atau bila katalog tidak
/// punya terjemahan, nama Indonesia dipakai — tidak pernah kunci mentah.
public enum ObjectNameLocalization {
    public typealias Lookup = @Sendable (String) -> String?

    private static let lock = NSLock()
    nonisolated(unsafe) private static var installed: Lookup?

    public static func install(_ lookup: Lookup?) {
        lock.lock(); defer { lock.unlock() }
        installed = lookup
    }

    public static func key(forObjectID id: String) -> String { "object.name.\(id)" }

    public static func name(forObjectID id: String, indonesian: String) -> String {
        lock.lock()
        let lookup = installed
        lock.unlock()
        let key = key(forObjectID: id)
        if let found = lookup?(key), !found.isEmpty, found != key { return found }
        return indonesian
    }
}
