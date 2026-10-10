import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Teks desain Figma (ADR-019): data jujur dan isi per benda.
final class DesignTextTests: XCTestCase {

    /// Di bawah cakrawala tidak boleh terbaca 0°.
    func testAltAzKeepsNegativeAltitude() {
        XCTAssertEqual(WatchHomeText.altAz(HorizontalCoord(altitudeDeg: -12.4, azimuthDeg: 287.2)), "AZ 287° · ALT −12°")
        XCTAssertEqual(WatchHomeText.altAz(HorizontalCoord(altitudeDeg: 34, azimuthDeg: -18)), "AZ 342° · ALT 34°")
    }

    func testGuideContentPerBodyAndKind() {
        let jupiter = CelestialObject(id: "jupiter", name: "Jupiter", kind: .planet, raDeg: 0, decDeg: 0, magnitude: -2.4)
        XCTAssertEqual(ObjectGuideContent.content(for: jupiter).binoculars, "Jupiter dan empat bulan Galileonya")
        let vega = CelestialObject(id: "vega", name: "Vega", kind: .star, raDeg: 0, decDeg: 0, magnitude: 0)
        XCTAssertEqual(ObjectGuideContent.content(for: vega).telescope, "Tetap sebuah titik, karena terlalu jauh")
        let m42 = CelestialObject(id: "m42", name: "Nebula Orion", kind: .deepSky, raDeg: 0, decDeg: 0, magnitude: 4)
        XCTAssertEqual(ObjectGuideContent.content(for: m42).nakedEye, "Bercak samar di langit gelap")
        XCTAssertEqual(DesignText.kindLine(.planet, DesignText.discVisibleNow), "Planet • Terlihat sekarang")
    }

    /// Tidak ada klaim akurasi yang belum terukur di teks desain.
    func testNoUnmeasuredPrecisionClaims() {
        for key in LocalizedText.designKeys {
            XCTAssertFalse(TextLocalization.text(key).contains("0.1°"))
            XCTAssertFalse(TextLocalization.text(key).lowercased().contains("presisi"))
        }
    }
}
