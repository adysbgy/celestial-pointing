import XCTest
import CelestialEngine
@testable import PointingKit

/// Gladi bersih uji malam pertama Ady, 9 Okt 2026, Jakarta (ADR-012).
///
/// Dengan langit kota, setiap benda yang terlihat harus terkunci pada dirinya
/// sendiri saat ditunjuk — juga dengan galat pergelangan 7° — dan tidak ada
/// gugus/nebula tak terlihat yang membuat bintang terang menjadi ragu.
final class TonightRehearsalTests: XCTestCase {

    private let jakarta = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    /// 18:45, 19:30, 21:00 WIB.
    private let times = ["2026-10-09T11:45:00Z", "2026-10-09T12:30:00Z", "2026-10-09T14:00:00Z"]
        .map { ISO8601DateFormatter().date(from: $0)! }

    private func outcome(pointingAt direction: HorizontalCoord, resolver: PointingResolver,
                         date: Date) -> IdentificationOutcome {
        let controller = PointingController(resolver: resolver, observer: jakarta,
                                            config: PointingControllerConfig(frame: .xTrueNorthZVertical))
        let q = DeviceAttitude.synthetic(aim: controller.config.aim, pointingAt: direction,
                                         frame: .xTrueNorthZVertical).quaternion
        for step in 0..<20 { controller.feed(quaternion: q, timestamp: date.addingTimeInterval(Double(step) * 0.1)) }
        return IdentificationOutcome.from(controller.snapshot)
    }

    func testCitySkyLocksEveryVisibleObjectTonight() {
        let resolver = EngineFactory.makeResolver(policy: SkyQuality.city.visibilityPolicy)
        for date in times {
            let visible = resolver.visibleTargets(observer: jakarta, date: date)
            XCTAssertGreaterThanOrEqual(visible.count, 7, "\(date)")
            XCTAssertTrue(visible.contains { $0.id == "saturn" }, "Saturnus harus terlihat \(date)")
            for target in visible {
                guard case .single(let object) = outcome(pointingAt: target.direction,
                                                         resolver: resolver, date: date) else {
                    XCTFail("\(target.name) tidak terkunci \(date)")
                    continue
                }
                XCTAssertEqual(object.id, target.id, "\(date)")
            }
        }
    }

    /// Galat 7° (di bawah sigma cadangan 10°) tetap mengunci benda yang sama.
    func testCitySkyToleratesWristError() {
        let resolver = EngineFactory.makeResolver(policy: SkyQuality.city.visibilityPolicy)
        let date = times[1]
        for id in ["saturn", "vega", "antares", "fomalhaut"] {
            let truth = resolver.visibleTargets(observer: jakarta, date: date).first { $0.id == id }!
            let off = HorizontalCoord(altitudeDeg: truth.direction.altitudeDeg + 7,
                                      azimuthDeg: truth.direction.azimuthDeg)
            guard case .single(let object) = outcome(pointingAt: off, resolver: resolver, date: date) else {
                return XCTFail("\(id) tidak terkunci dengan galat 7°")
            }
            XCTAssertEqual(object.id, id)
        }
    }

    /// Bukti masalahnya: dengan batas langit gelap 6.0, Antares menjadi ragu
    /// karena gugus yang tidak terlihat dari kota.
    func testDarkSkyPolicyMakesAntaresAmbiguousInTheCity() {
        let resolver = EngineFactory.makeResolver(policy: SkyQuality.dark.visibilityPolicy)
        let date = times[0]
        let antares = resolver.visibleTargets(observer: jakarta, date: date).first { $0.id == "antares" }!
        guard case .possibleMatches = outcome(pointingAt: antares.direction, resolver: resolver, date: date) else {
            return XCTFail("diharapkan ragu dengan batas 6.0")
        }
    }

    func testSkyQualityPolicies() {
        XCTAssertEqual(SkyQuality.default, .city)
        XCTAssertEqual(SkyQuality.city.visibilityPolicy.limitingMagnitude, 3.0)
        XCTAssertEqual(SkyQuality.dark.visibilityPolicy, VisibilityPolicy())
        XCTAssertEqual(SkyQualityStorage.quality(darkSky: false), .city)
    }

    func testSetVisibilityPolicyInvalidatesOnlyOnChange() {
        let controller = PointingController(resolver: EngineFactory.makeResolver(), observer: jakarta)
        XCTAssertFalse(controller.setVisibilityPolicy(VisibilityPolicy()))
        XCTAssertTrue(controller.setVisibilityPolicy(SkyQuality.city.visibilityPolicy))
        XCTAssertEqual(controller.resolver.policy.limitingMagnitude, 3.0)
        XCTAssertNil(controller.lastResolution)
    }
}
