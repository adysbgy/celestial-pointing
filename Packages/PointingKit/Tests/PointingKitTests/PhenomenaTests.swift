import XCTest
import CelestialEngine
@testable import PointingKit

/// Kalender fenomena luring untuk Jakarta (ADR-015). Nilainya dari efemeris
/// dan pencarian peristiwa yang sama dengan engine.
final class PhenomenaTests: XCTestCase {

    private let jakarta = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let start = ISO8601DateFormatter().date(from: "2026-10-10T00:00:00Z")!
    private lazy var list = PhenomenaCalendar.upcoming(
        after: start, observer: jakarta,
        resolver: EngineFactory.makeResolver(policy: SkyQuality.city.visibilityPolicy),
        events: EngineFactory.defaultEventSearch)

    private func wib(_ date: Date) -> DateComponents {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return c.dateComponents([.year, .month, .day, .hour], from: date)
    }

    func testSortedByDate() {
        XCTAssertEqual(list.map(\.date), list.map(\.date).sorted())
    }

    /// Bulan sangat dekat Jupiter sebelum fajar 3 Nov 2026, terlihat dari Jakarta.
    func testMoonJupiterBeforeDawnNov3() throws {
        let p = try XCTUnwrap(list.first { $0.kind == .conjunction && $0.targetIDs == ["moon", "jupiter"] })
        XCTAssertTrue(p.visibleHere)
        XCTAssertLessThan(try XCTUnwrap(p.value), 1.0)
        let c = wib(p.date)
        XCTAssertEqual(c.month, 11); XCTAssertEqual(c.day, 3)
        XCTAssertTrue(p.isGuidable)
        XCTAssertEqual(PhenomenonText.title(p), "Bulan dekat Jupiter")
    }

    func testOrionidsArePreDawnAndGuidable() throws {
        let p = try XCTUnwrap(list.first { $0.id.hasPrefix("meteor-orionids") })
        XCTAssertTrue(p.visibleHere)
        let hour = try XCTUnwrap(wib(p.date).hour)
        XCTAssertTrue((1...5).contains(hour), "radian tertinggi sebelum fajar, terhitung \(hour)")
        XCTAssertNotNil(p.radiant)
        XCTAssertTrue(p.isGuidable)
        XCTAssertEqual(PhenomenonText.targetName(p), "Radian Orionid")
    }

    func testEclipsesAreHonestAboutVisibility() throws {
        let july2027 = try XCTUnwrap(list.first { $0.kind == .lunarEclipse && wib($0.date).year == 2027 && wib($0.date).month == 7 })
        XCTAssertTrue(july2027.visibleHere)
        XCTAssertEqual(PhenomenonText.title(july2027), "Gerhana Bulan penumbra")
        let feb2027 = try XCTUnwrap(list.first { $0.kind == .lunarEclipse && wib($0.date).month == 2 })
        XCTAssertFalse(feb2027.visibleHere)
    }

    /// Gerhana Matahari: terlihat, tapi **tidak pernah** dipandu (keputusan Ady).
    func testSolarEclipseIsNeverGuided() throws {
        let p = try XCTUnwrap(list.first { $0.kind == .solarEclipse && $0.visibleHere })
        XCTAssertEqual(wib(p.date).year, 2028)
        XCTAssertEqual(try XCTUnwrap(p.value), 0.89, accuracy: 0.02)
        XCTAssertTrue(p.requiresSolarFilter)
        XCTAssertFalse(p.isGuidable)
        XCTAssertEqual(PhenomenonText.detail(p), "89% tertutup")
    }

    func testWithoutEventSearchStillListsConjunctionsAndMeteors() {
        let lite = PhenomenaCalendar.upcoming(after: start, observer: jakarta,
                                              resolver: EngineFactory.makeResolver(), events: nil)
        XCTAssertTrue(lite.contains { $0.kind == .conjunction })
        XCTAssertTrue(lite.contains { $0.kind == .meteorShower })
        XCTAssertFalse(lite.contains { $0.kind == .lunarEclipse })
    }

    func testRadiantDirectionMovesWithTime() {
        let geminid = MeteorShower.annual.first { $0.id == "geminids" }!.radiant
        let a = PhenomenaCalendar.radiantDirection(geminid, observer: jakarta, date: start)
        let b = PhenomenaCalendar.radiantDirection(geminid, observer: jakarta, date: start.addingTimeInterval(3 * 3600))
        XCTAssertGreaterThan(SkyMath.angularSeparationHorizontalDeg(a, b), 20)
    }
}
