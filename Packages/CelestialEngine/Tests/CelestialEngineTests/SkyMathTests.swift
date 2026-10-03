import XCTest
@testable import CelestialEngine

final class SkyMathTests: XCTestCase {

    func testJulianDateEpoch() {
        let d = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(SkyMath.julianDate(from: d), 2440587.5, accuracy: 1e-6)
    }

    func testAngularSeparationSamePoint() {
        let a = EquatorialCoord(raDeg: 10, decDeg: 20)
        XCTAssertEqual(SkyMath.angularSeparationDeg(a, a), 0, accuracy: 1e-9)
    }

    func testAngularSeparationKnown90() {
        let a = EquatorialCoord(raDeg: 0, decDeg: 0)
        let b = EquatorialCoord(raDeg: 90, decDeg: 0)
        XCTAssertEqual(SkyMath.angularSeparationDeg(a, b), 90, accuracy: 1e-6)
    }

    func testPolarisAltitudeApproxLatitude() {
        let obs = Observer(latitudeDeg: 45, longitudeDeg: 0)
        let eq = EquatorialCoord(raDeg: 37.95456067, decDeg: 89.26410897)
        let hor = SkyMath.equatorialToHorizontal(eq, observer: obs, jd: 2460000.5)
        XCTAssertEqual(hor.altitudeDeg, 45, accuracy: 1.5)
    }

    func testHorizontalSeparationSame() {
        let a = HorizontalCoord(altitudeDeg: 30, azimuthDeg: 100)
        XCTAssertEqual(SkyMath.angularSeparationHorizontalDeg(a, a), 0, accuracy: 1e-9)
    }
}
