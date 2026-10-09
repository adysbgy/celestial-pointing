import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Petunjuk arah, ramalan gelap, dan pilihan kerangka (ADR-011,
/// Docs/WATCH_NOT_SURE_ANALYSIS.md).
final class SkyGuideTests: XCTestCase {

    private let jakarta = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    /// 9 Okt 2026 13:44 WIB — saat Ady melaporkan "not sure yet terus".
    private let afternoon = ISO8601DateFormatter().date(from: "2026-10-09T06:44:00Z")!
    /// 9 Okt 2026 20:00 WIB.
    private let evening = ISO8601DateFormatter().date(from: "2026-10-09T13:00:00Z")!

    private func target(_ id: String, alt: Double, az: Double) -> PointingTarget {
        PointingTarget(id: id, name: id, kind: .star, magnitude: 0,
                       direction: HorizontalCoord(altitudeDeg: alt, azimuthDeg: az), isMoving: false)
    }

    // MARK: Panah

    func testArrowPointsRightUpLeftDown() {
        let p = HorizontalCoord(altitudeDeg: 30, azimuthDeg: 0)
        XCTAssertEqual(SkyGuide.arrowDeg(from: p, to: HorizontalCoord(altitudeDeg: 50, azimuthDeg: 0)), 0, accuracy: 0.5)
        XCTAssertEqual(SkyGuide.arrowDeg(from: p, to: HorizontalCoord(altitudeDeg: 30, azimuthDeg: 20)), 90, accuracy: 6)
        XCTAssertEqual(SkyGuide.arrowDeg(from: p, to: HorizontalCoord(altitudeDeg: 10, azimuthDeg: 0)), 180, accuracy: 0.5)
        XCTAssertEqual(SkyGuide.arrowDeg(from: p, to: HorizontalCoord(altitudeDeg: 30, azimuthDeg: 340)), 270, accuracy: 6)
    }

    /// Melewati Utara (359° → 1°) tetap "ke kanan", bukan memutar 358° ke kiri.
    func testArrowAcrossNorthWraps() {
        let p = HorizontalCoord(altitudeDeg: 20, azimuthDeg: 355)
        XCTAssertEqual(SkyGuide.arrowDeg(from: p, to: HorizontalCoord(altitudeDeg: 20, azimuthDeg: 10)), 90, accuracy: 6)
    }

    func testHintPicksNearest() throws {
        let p = HorizontalCoord(altitudeDeg: 40, azimuthDeg: 90)
        let hint = try XCTUnwrap(SkyGuide.hint(from: p, to: [
            target("far", alt: 40, az: 200),
            target("near", alt: 55, az: 95),
        ]))
        XCTAssertEqual(hint.objectID, "near")
        XCTAssertEqual(hint.separationDeg, 15.4, accuracy: 0.5)
        XCTAssertNil(SkyGuide.hint(from: p, to: []))
    }

    // MARK: Bukti siang (laporan lapangan 9 Okt 2026)

    /// Inilah akar masalah pertama: siang hari tidak ada satu pun benda yang
    /// boleh dikenali, jadi setiap arah berakhir "Belum yakin".
    func testAfternoonOfTheReportHasNothingVisible() {
        let resolver = EngineFactory.makeResolver()
        XCTAssertFalse(resolver.skyContext(observer: jakarta, date: afternoon).isDark)
        XCTAssertTrue(resolver.visibleTargets(observer: jakarta, date: afternoon).isEmpty)
    }

    func testEveningHasVisibleTargetsAndAGuide() throws {
        let resolver = EngineFactory.makeResolver()
        let visible = resolver.visibleTargets(observer: jakarta, date: evening)
        XCTAssertGreaterThan(visible.count, 5)
        // Selalu ada langkah berikutnya: arah mana pun di atas horizon.
        for az in stride(from: 0.0, to: 360, by: 45) {
            XCTAssertNotNil(SkyGuide.hint(from: HorizontalCoord(altitudeDeg: 30, azimuthDeg: az), to: visible))
        }
    }

    // MARK: Ramalan gelap

    func testNextDarkIsEarlyEveningInJakarta() throws {
        let resolver = EngineFactory.makeResolver()
        let dark = try XCTUnwrap(DarknessForecast.nextDark(after: afternoon, observer: jakarta, resolver: resolver))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        let c = cal.dateComponents([.hour, .minute], from: dark)
        // Matahari terbenam ~17:50 WIB; senja sipil (−6°) ~18:10 WIB.
        XCTAssertEqual(c.hour, 18)
        XCTAssertLessThan(c.minute ?? 99, 30)
        XCTAssertFalse(resolver.skyContext(observer: jakarta, date: dark.addingTimeInterval(-120)).isDark)
        XCTAssertTrue(resolver.skyContext(observer: jakarta, date: dark).isDark)
    }

    func testNextDarkWhenAlreadyDarkIsNow() {
        let resolver = EngineFactory.makeResolver()
        XCTAssertEqual(DarknessForecast.nextDark(after: evening, observer: jakarta, resolver: resolver), evening)
    }

    func testTonightListsBrightObjects() {
        let resolver = EngineFactory.makeResolver()
        let tonight = DarknessForecast.tonight(after: afternoon, observer: jakarta, resolver: resolver)
        XCTAssertEqual(tonight.count, 3)
        XCTAssertEqual(tonight.map(\.magnitude), tonight.map(\.magnitude).sorted())
    }

    func testNoEphemerisMeansNoForecast() {
        let resolver = EngineFactory.makeResolver(includeSolarSystem: false)
        XCTAssertNil(DarknessForecast.nextDark(after: afternoon, observer: jakarta, resolver: resolver))
    }

    // MARK: Kerangka

    func testFramePreferenceOrder() {
        XCTAssertEqual(AttitudeReferenceFrame.preferred(from: AttitudeReferenceFrame.allCases), .xTrueNorthZVertical)
        XCTAssertEqual(AttitudeReferenceFrame.preferred(from: [.xArbitraryZVertical, .xMagneticNorthZVertical]),
                       .xMagneticNorthZVertical)
        XCTAssertEqual(AttitudeReferenceFrame.preferred(from: []), .xArbitraryZVertical)
    }

    func testFrameFallbackChain() {
        let all = AttitudeReferenceFrame.allCases
        XCTAssertEqual(AttitudeReferenceFrame.xTrueNorthZVertical.fallback(within: all), .xMagneticNorthZVertical)
        XCTAssertEqual(AttitudeReferenceFrame.xMagneticNorthZVertical.fallback(within: [.xArbitraryZVertical]),
                       .xArbitraryZVertical)
        XCTAssertNil(AttitudeReferenceFrame.xArbitraryZVertical.fallback(within: all))
    }

    // MARK: Teks

    func testIndonesianTexts() {
        XCTAssertEqual(WatchHomeText.guideTitle("Jupiter"), "Geser ke Jupiter")
        XCTAssertEqual(WatchHomeText.guideDistance(24.6), "25° lagi")
        XCTAssertEqual(WatchHomeText.darkAt(evening, timeZone: TimeZone(identifier: "Asia/Jakarta")!).hasPrefix("Bintang muncul sekitar 20"), true)
    }

    // MARK: Laporan pengembang

    func testWhyNotSureReportNamesTheArbitraryFrame() {
        let rows = WhyNotSureReport.rows(snapshot: PointingSnapshot(state: .searching, searchHint: .daylight),
                                         frame: .xArbitraryZVertical, locationIsFallback: true,
                                         sunAltitudeDeg: 59.2, visibleCount: 0, nearest: nil)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.value) })
        XCTAssertEqual(byID["hint"], "daylight")
        XCTAssertEqual(byID["heading"], "arbitrary")
        XCTAssertEqual(byID["sun alt"], "59°")
        XCTAssertEqual(byID["visible"], "0")
        XCTAssertEqual(byID["nearest"], "–")
    }

    // MARK: iPhone (ADR-013)

    func testObjectForIDCoversCatalogueAndPlanets() throws {
        let resolver = EngineFactory.makeResolver()
        XCTAssertEqual(resolver.object(forID: "vega", observer: jakarta, date: evening)?.name, "Vega")
        let saturn = try XCTUnwrap(resolver.object(forID: "saturn", observer: jakarta, date: evening))
        XCTAssertEqual(saturn.kind, .planet)
        XCTAssertNil(resolver.object(forID: "sun", observer: jakarta, date: evening))
        XCTAssertNil(resolver.object(forID: "nope", observer: jakarta, date: evening))
    }

    func testWhereToLookLine() {
        XCTAssertEqual(SkyRowText.whereToLook(HorizontalCoord(altitudeDeg: 44.6, azimuthDeg: 95)),
                       "Arah timur · 45° di atas cakrawala")
    }
}

