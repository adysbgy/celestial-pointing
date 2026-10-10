import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Tunjuk satu, tahu satu + panas–dingin (ADR-014).
final class OneAtATimeTests: XCTestCase {

    private let pollux = CelestialObject(id: "pollux", name: "Pollux", kind: .star,
                                         raDeg: 116.32895875, decDeg: 28.02619889, magnitude: 1.14)
    private let castor = CelestialObject(id: "castor", name: "Castor", kind: .star,
                                         raDeg: 113.64947225, decDeg: 31.88827547, magnitude: 1.58)
    private let procyon = CelestialObject(id: "procyon", name: "Procyon", kind: .star,
                                          raDeg: 114.82549276, decDeg: 5.22499310, magnitude: 0.34)

    /// Sama dekatnya: yang lebih terang (yang terlihat di kota) di depan.
    func testBrighterWinsWhenEquallyClose() {
        let list = OneAtATime(candidates: [Candidate(object: castor, separationDeg: 3.0),
                                           Candidate(object: pollux, separationDeg: 3.0)])
        XCTAssertEqual(list.entry(at: 0)?.object.id, "pollux")
    }

    /// Arah tunjuk tetap yang utama: benda yang jauh lebih dekat ke tangan
    /// menang walau lebih redup.
    func testPointingStillDominates() {
        let list = OneAtATime(candidates: [Candidate(object: pollux, separationDeg: 9.0),
                                           Candidate(object: castor, separationDeg: 1.0)])
        XCTAssertEqual(list.entry(at: 0)?.object.id, "castor")
    }

    func testCrownWrapsBothWays() {
        let list = OneAtATime(candidates: [Candidate(object: pollux, separationDeg: 1),
                                           Candidate(object: castor, separationDeg: 2),
                                           Candidate(object: procyon, separationDeg: 15)])
        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(list.entry(at: 3)?.object.id, list.entry(at: 0)?.object.id)
        XCTAssertEqual(list.entry(at: -1)?.object.id, list.entry(at: 2)?.object.id)
        XCTAssertNil(OneAtATime(candidates: []).entry(at: 0))
    }

    /// Castor–Pollux 4,5° di langit: disebut sebagai tetangga dekat;
    /// Procyon (23° jauhnya) tidak.
    func testCloseNeighbourIsNamedWithSkyDistance() throws {
        let list = OneAtATime(candidates: [Candidate(object: pollux, separationDeg: 1),
                                           Candidate(object: castor, separationDeg: 3),
                                           Candidate(object: procyon, separationDeg: 18)])
        let n = try XCTUnwrap(list.closeNeighbour(of: 0, withinDeg: 10))
        XCTAssertEqual(n.object.id, "castor")
        XCTAssertEqual(n.distanceDeg, 4.5, accuracy: 0.1)
        XCTAssertNil(OneAtATime(candidates: [Candidate(object: pollux, separationDeg: 1),
                                             Candidate(object: procyon, separationDeg: 18)])
            .closeNeighbour(of: 0, withinDeg: 10))
    }

    // MARK: Panas–dingin

    func testTickCadenceGetsFasterWhenCloser() throws {
        XCTAssertNil(HotCold.tickInterval(separationDeg: 60))
        XCTAssertNil(HotCold.tickInterval(separationDeg: .nan))
        let far = try XCTUnwrap(HotCold.tickInterval(separationDeg: 45))
        let mid = try XCTUnwrap(HotCold.tickInterval(separationDeg: 15))
        let near = try XCTUnwrap(HotCold.tickInterval(separationDeg: 2))
        XCTAssertGreaterThan(far, mid)
        XCTAssertGreaterThan(mid, near)
        XCTAssertEqual(near, 0.2, accuracy: 1e-9)
    }

    func testHeat() {
        XCTAssertEqual(HotCold.heat(separationDeg: 0), 1)
        XCTAssertEqual(HotCold.heat(separationDeg: 30), 0.5, accuracy: 1e-9)
        XCTAssertEqual(HotCold.heat(separationDeg: 90), 0)
    }

    func testTexts() {
        XCTAssertEqual(WatchHomeText.alsoClose("Castor", distanceDeg: 4.6), "Castor juga dekat (5°). Putar crown.")
        XCTAssertEqual(WatchHomeText.position(0, of: 3), "1 dari 3")
    }
}
