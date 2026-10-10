import XCTest
@testable import PointingKit
@testable import CelestialEngine

final class WatchHomeTextTests: XCTestCase {
    func testCompassEightPoints() {
        XCTAssertEqual(WatchHomeText.compassKey(azimuthDeg: 0), .compassN)
        XCTAssertEqual(WatchHomeText.compassKey(azimuthDeg: 22.4), .compassN)
        XCTAssertEqual(WatchHomeText.compassKey(azimuthDeg: 22.5), .compassNE)
        XCTAssertEqual(WatchHomeText.compassKey(azimuthDeg: 90), .compassE)
        XCTAssertEqual(WatchHomeText.compassKey(azimuthDeg: 180), .compassS)
        XCTAssertEqual(WatchHomeText.compassKey(azimuthDeg: 270), .compassW)
        XCTAssertEqual(WatchHomeText.compassKey(azimuthDeg: 337.5), .compassN)
        XCTAssertEqual(WatchHomeText.compassKey(azimuthDeg: -45), .compassNW)
        XCTAssertNil(WatchHomeText.compassKey(azimuthDeg: .nan))
    }

    func testBrightnessWords() {
        XCTAssertEqual(WatchHomeText.brightnessKey(magnitude: -1.46), .brightnessVeryBright)
        XCTAssertEqual(WatchHomeText.brightnessKey(magnitude: 0.5), .brightnessBright)
        XCTAssertEqual(WatchHomeText.brightnessKey(magnitude: 2.0), .brightnessModerate)
        XCTAssertEqual(WatchHomeText.brightnessKey(magnitude: 4.0), .brightnessFaint)
    }

    /// Tanpa katalog terpasang: Bahasa Indonesia sehari-hari, tanpa angka teknis.
    func testIndonesianDefaults() {
        XCTAssertEqual(WatchHomeText.direction(azimuthDeg: 95), "Arah timur")
        XCTAssertEqual(WatchHomeText.altitude(44.6), "45° di atas cakrawala")
        XCTAssertEqual(WatchHomeText.altitude(-3), "0° di atas cakrawala")
        let saturn = CelestialObject(id: "saturn", name: "Saturnus", kind: .planet, raDeg: 0, decDeg: 0, magnitude: 0.6)
        XCTAssertEqual(WatchHomeText.subtitle(saturn), "Planet · Terang")
    }
}
