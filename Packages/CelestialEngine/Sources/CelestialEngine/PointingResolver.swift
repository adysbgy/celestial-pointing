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
            let eq = EquatorialCoord(raDeg: obj.raDeg, decDeg: obj.decDeg)
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
