import Foundation

/// Engine inti: arah pointing + waktu + lokasi + katalog -> niat benda langit.
public struct PointingResolver {
    public var catalogue: [CelestialObject]

    public init(catalogue: [CelestialObject]) {
        self.catalogue = catalogue
    }

    public func resolve(pointing: HorizontalCoord,
                        observer: Observer,
                        date: Date,
                        coneDeg: Double = 20.0,
                        minAltitudeDeg: Double = 0.0) -> CelestialIntent {
        let jd = SkyMath.julianDate(from: date)
        var candidates: [Candidate] = []

        for obj in catalogue {
            // Katalog bintang disimpan dalam J2000; ekuator/ekuinoks bergeser
            // karena presesi. Tanpa reduksi ini bintang meleset ~0.3° (2026).
            let j2000 = EquatorialCoord(raDeg: obj.raDeg, decDeg: obj.decDeg)
            let eq = SkyMath.precessJ2000ToDate(j2000, jd: jd)
            let hor = SkyMath.equatorialToHorizontal(eq, observer: observer, jd: jd)
            if hor.altitudeDeg < minAltitudeDeg { continue }
            let sep = SkyMath.angularSeparationHorizontalDeg(pointing, hor)
            if sep <= coneDeg {
                candidates.append(Candidate(object: obj, separationDeg: sep))
            }
        }

        candidates.sort { $0.separationDeg < $1.separationDeg }
        return ConfidenceModel.evaluate(candidates: candidates, coneDeg: coneDeg)
    }
}
