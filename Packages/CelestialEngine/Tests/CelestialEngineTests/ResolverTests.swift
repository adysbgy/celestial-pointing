import XCTest
@testable import CelestialEngine

final class ResolverTests: XCTestCase {

    func testConfidenceLowWhenNoCandidates() {
        let intent = ConfidenceModel.evaluate(candidates: [], coneDeg: 20)
        XCTAssertEqual(intent.level, .low)
        XCTAssertNil(intent.best)
    }

    func testResolverFindsSiriusWhenPointedAtIt() {
        let obs = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8) // Jakarta
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let jd = SkyMath.julianDate(from: date)

        let sirius = EquatorialCoord(raDeg: 101.28715533, decDeg: -16.71611586)
        let hor = SkyMath.equatorialToHorizontal(sirius, observer: obs, jd: jd)

        let resolver = PointingResolver(catalogue: Catalogue.brightStars)
        let intent = resolver.resolve(pointing: hor, observer: obs, date: date,
                                      coneDeg: 20, minAltitudeDeg: -90)
        XCTAssertEqual(intent.best?.id, "sirius")
        XCTAssertEqual(intent.level, .high)
    }

    func testCatalogueNotEmpty() {
        XCTAssertGreaterThanOrEqual(Catalogue.brightStars.count, 20)
    }
}
