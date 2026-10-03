import Foundation

/// Pengamat di Bumi.
public struct Observer: Equatable {
    public var latitudeDeg: Double
    public var longitudeDeg: Double
    public init(latitudeDeg: Double, longitudeDeg: Double) {
        self.latitudeDeg = latitudeDeg
        self.longitudeDeg = longitudeDeg
    }
}

/// Koordinat ekuatorial (J2000).
public struct EquatorialCoord: Equatable {
    public var raDeg: Double
    public var decDeg: Double
    public init(raDeg: Double, decDeg: Double) {
        self.raDeg = raDeg
        self.decDeg = decDeg
    }
}

/// Koordinat horizontal (alt-az).
public struct HorizontalCoord: Equatable {
    public var altitudeDeg: Double
    public var azimuthDeg: Double
    public init(altitudeDeg: Double, azimuthDeg: Double) {
        self.altitudeDeg = altitudeDeg
        self.azimuthDeg = azimuthDeg
    }
}

public enum ObjectKind: String, Equatable {
    case moon, planet, star, deepSky
}

/// Benda langit di katalog.
public struct CelestialObject: Equatable {
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

public enum ConfidenceLevel: String, Equatable {
    case high, medium, low
}

public struct Candidate: Equatable {
    public var object: CelestialObject
    public var separationDeg: Double
    public init(object: CelestialObject, separationDeg: Double) {
        self.object = object; self.separationDeg = separationDeg
    }
}

/// Hasil resolusi niat: objek terbaik + tingkat keyakinan.
public struct CelestialIntent: Equatable {
    public var level: ConfidenceLevel
    public var best: CelestialObject?
    public var candidates: [Candidate]
    public init(level: ConfidenceLevel, best: CelestialObject?, candidates: [Candidate]) {
        self.level = level; self.best = best; self.candidates = candidates
    }
}
