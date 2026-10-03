import Foundation
import CelestialEngine

/// Objek yang bisa dijadikan target pointing, beserta arahnya saat ini.
///
/// Dibuat sebagai tipe tersendiri karena target di lapisan app datang dari dua
/// tempat yang berbeda: bintang dari katalog (J2000, perlu presesi) dan benda
/// tata surya dari efemeris (sudah of-date). Menyatukan keduanya di satu tipe
/// mencegah UI dan harness harus tahu perbedaan itu.
public struct PointingTarget: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var kind: ObjectKind
    public var magnitude: Double
    /// Arah objek saat ini.
    public var direction: HorizontalCoord
    /// Apakah arah ini dihitung dari efemeris (benda bergerak) atau katalog.
    public var isMoving: Bool

    public init(id: String, name: String, kind: ObjectKind,
                magnitude: Double, direction: HorizontalCoord, isMoving: Bool) {
        self.id = id
        self.name = name
        self.kind = kind
        self.magnitude = magnitude
        self.direction = direction
        self.isMoving = isMoving
    }

    /// Apakah objek ini sedang cukup tinggi untuk ditunjuk.
    public var isAboveHorizon: Bool { direction.altitudeDeg > 0 }

    /// Jarak sudut dari sebuah arah tunjuk (derajat).
    public func separation(from pointing: HorizontalCoord) -> Double {
        SkyMath.angularSeparationHorizontalDeg(pointing, direction)
    }

    public var kindLabel: String {
        switch kind {
        case .star: return "Bintang"
        case .moon: return "Bulan"
        case .planet: return "Planet"
        case .deepSky: return "Objek langit dalam"
        case .sun: return "Matahari"
        }
    }
}

public extension PointingResolver {

    /// Semua target yang arahnya bisa dihitung sekarang.
    ///
    /// Bintang selalu bisa (katalog). Bulan/planet hanya bila efemeris
    /// tersedia dan perhitungannya berhasil. Matahari tidak pernah muncul:
    /// `horizontal(ofBody:)` menolaknya.
    ///
    /// - Parameter aboveHorizonOnly: buang objek di bawah cakrawala. Untuk
    ///   kalibrasi dan Experiment 1 ini penting — menunjuk objek yang tidak
    ///   ada di langit hanya menghasilkan rekaman yang menyesatkan.
    func availableTargets(observer: Observer,
                          date: Date,
                          aboveHorizonOnly: Bool = true) -> [PointingTarget] {
        var targets: [PointingTarget] = []

        for object in catalogue where object.kind == .star || object.kind == .deepSky {
            guard let direction = horizontal(of: object, observer: observer, date: date) else { continue }
            if aboveHorizonOnly && direction.altitudeDeg <= 0 { continue }
            targets.append(PointingTarget(id: object.id,
                                          name: object.name,
                                          kind: object.kind,
                                          magnitude: object.magnitude,
                                          direction: direction,
                                          isMoving: false))
        }

        if considersSolarSystem {
            for body in EphemerisBody.pointableBodies {
                guard let direction = horizontal(ofBody: body, observer: observer, date: date) else { continue }
                if aboveHorizonOnly && direction.altitudeDeg <= 0 { continue }
                targets.append(PointingTarget(id: body.rawValue,
                                              name: body.displayName,
                                              kind: body == .moon ? .moon : .planet,
                                              magnitude: body.typicalBrightestMagnitude,
                                              direction: direction,
                                              isMoving: true))
            }
        }

        // Terang dulu — itu yang paling mudah ditunjuk.
        return targets.sorted { $0.magnitude < $1.magnitude }
    }

    /// Target terdekat dari sebuah arah tunjuk, dalam batas sudut tertentu.
    ///
    /// Dipakai kalibrasi: kalau pengguna menunjuk Sirius, kita perlu tahu itu
    /// Sirius — bukan bintang lain yang kebetulan terdekat di katalog.
    func nearestTarget(to pointing: HorizontalCoord,
                       observer: Observer,
                       date: Date,
                       withinDeg: Double = 25.0,
                       aboveHorizonOnly: Bool = true) -> PointingTarget? {
        let candidates = availableTargets(observer: observer,
                                          date: date,
                                          aboveHorizonOnly: aboveHorizonOnly)
            .map { (target: $0, separation: $0.separation(from: pointing)) }
            .filter { $0.separation <= withinDeg }
            .sorted { $0.separation < $1.separation }

        guard let best = candidates.first else { return nil }

        // Dua kandidat yang nyaris sama dekatnya tidak boleh dipilih diam-diam:
        // memilih yang salah membuat kalibrasi mengoreksi ke arah yang keliru.
        // Jarak 5° dipakai sebagai ambang "tidak bisa dibedakan dengan mata".
        if candidates.count >= 2 {
            let runnerUp = candidates[1].separation
            if runnerUp - best.separation < 5.0 { return nil }
        }
        return best.target
    }
}
