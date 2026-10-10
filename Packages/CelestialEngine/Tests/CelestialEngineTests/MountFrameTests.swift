import XCTest
@testable import CelestialEngine

/// Koordinat yang dikirim ke dudukan harus dalam kerangka yang dinyatakan
/// dudukan (`EquatorialSystem` Alpaca, ADR-008). Uji ini membuktikan bahwa
/// "J2000" dan "of-date" di 2026 memang berbeda sebesar presesi yang
/// diharapkan — jadi salah memilih kerangka akan membelokkan GoTo ~0,3°,
/// lebih dari seperempat medan pandang Seestar S50 (~1,3° × 0,7°).
final class MountFrameTests: XCTestCase {

    private let siriusJ2000 = EquatorialCoord(raDeg: 101.28715533, decDeg: -16.71611586)

    /// Presesi tahunan baku (Meeus, Astronomical Algorithms §21, pendekatan
    /// rumus rendah): Δα = m + n·sin α·tan δ, Δδ = n·cos α, dengan
    /// m = 3,075 dtk-waktu/thn dan n = 1,336 dtk-waktu/thn = 20,04″/thn.
    /// Proper motion Sirius sengaja tidak dihitung (uji ini presesi saja).
    func testSiriusJ2000VersusOfDate2026MatchesExpectedPrecession() {
        let date = ISO8601DateFormatter().date(from: "2026-04-01T00:00:00Z")!
        let jd = SkyMath.julianDate(from: date)
        let years = (jd - 2451545.0) / 365.25
        let ofDate = SkyMath.precessJ2000ToDate(siriusJ2000, jd: jd)

        let a = SkyMath.deg2rad(siriusJ2000.raDeg), d = SkyMath.deg2rad(siriusJ2000.decDeg)
        let raSecondsPerYear = 3.075 + 1.336 * sin(a) * tan(d)          // dtk-waktu
        let decArcsecPerYear = 20.04 * cos(a)                             // ″
        let expectedDeltaRADeg = raSecondsPerYear * years * 15 / 3600
        let expectedDeltaDecDeg = decArcsecPerYear * years / 3600

        let deltaRA = ofDate.raDeg - siriusJ2000.raDeg
        let deltaDec = ofDate.decDeg - siriusJ2000.decDeg
        XCTAssertEqual(deltaRA, expectedDeltaRADeg, accuracy: 0.005)       // ≤ 18″
        XCTAssertEqual(deltaDec, expectedDeltaDecDeg, accuracy: 0.002)     // ≤ 7″
        // Dan besarnya memang tidak bisa diabaikan untuk GoTo.
        XCTAssertGreaterThan(abs(deltaRA), 0.25)
        XCTAssertEqual(expectedDeltaRADeg, 0.293, accuracy: 0.01)
    }

    /// Bolak-balik J2000 → of-date → J2000 harus kembali (bridge memakai
    /// keduanya untuk dudukan J2000).
    func testRoundTripIsLossless() {
        let jd = SkyMath.julianDate(from: ISO8601DateFormatter().date(from: "2026-10-08T12:00:00Z")!)
        let back = SkyMath.precessDateToJ2000(SkyMath.precessJ2000ToDate(siriusJ2000, jd: jd), jd: jd)
        XCTAssertEqual(back.raDeg, siriusJ2000.raDeg, accuracy: 1e-6)
        XCTAssertEqual(back.decDeg, siriusJ2000.decDeg, accuracy: 1e-6)
    }
}
