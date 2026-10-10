import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Getaran tidak berulang untuk kunci yang goyah (ADR-022).
final class HapticDebouncerTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 0)

    func testWobblingLockOnSameStarBuzzesOnce() {
        var d = HapticDebouncer()
        XCTAssertEqual(d.filter([.lockSucceeded], state: .lock, objectID: "deneb", at: t0), [.lockSucceeded])
        // Lengan goyah: lock → pointing → lock dalam beberapa detik.
        XCTAssertEqual(d.filter([], state: .pointing, objectID: "deneb", at: t0.addingTimeInterval(1)), [])
        XCTAssertEqual(d.filter([.lockSucceeded], state: .lock, objectID: "deneb", at: t0.addingTimeInterval(1.6)), [])
        XCTAssertEqual(d.filter([.lockSucceeded], state: .lock, objectID: "deneb", at: t0.addingTimeInterval(4)), [])
    }

    func testNewStarBuzzesImmediately() {
        var d = HapticDebouncer()
        _ = d.filter([.lockSucceeded], state: .lock, objectID: "deneb", at: t0)
        XCTAssertEqual(d.filter([.lockSucceeded], state: .lock, objectID: "vega", at: t0.addingTimeInterval(2)),
                       [.lockSucceeded])
    }

    func testSameStarAfterLongLossBuzzesAgain() {
        var d = HapticDebouncer()
        _ = d.filter([.lockSucceeded], state: .lock, objectID: "deneb", at: t0)
        XCTAssertEqual(d.filter([.lockSucceeded], state: .lock, objectID: "deneb", at: t0.addingTimeInterval(12)),
                       [.lockSucceeded])
    }

    func testUncertainRightAfterLockIsSilentAndRateLimited() {
        var d = HapticDebouncer()
        _ = d.filter([.lockSucceeded], state: .lock, objectID: "deneb", at: t0)
        XCTAssertEqual(d.filter([.uncertain], state: .uncertain, objectID: "deneb", at: t0.addingTimeInterval(1)), [])
        var e = HapticDebouncer()
        XCTAssertEqual(e.filter([.uncertain], state: .uncertain, objectID: "a", at: t0), [.uncertain])
        XCTAssertEqual(e.filter([.uncertain], state: .uncertain, objectID: "a", at: t0.addingTimeInterval(2)), [])
        XCTAssertEqual(e.filter([.uncertain], state: .uncertain, objectID: "a", at: t0.addingTimeInterval(7)), [.uncertain])
    }

    func testOtherEventsPass() {
        var d = HapticDebouncer()
        XCTAssertEqual(d.filter([.sensorUnavailable], state: .unavailable, objectID: nil, at: t0), [.sensorUnavailable])
    }
}

/// Arah gerak dalam kata (ADR-022).
final class GuideDirectionsTests: XCTestCase {
    private func hint(_ arrow: Double, _ sep: Double) -> GuideHint {
        GuideHint(objectID: "x", name: "X", kind: .star, separationDeg: sep, arrowDeg: arrow)
    }

    func testWords() {
        XCTAssertEqual(GuideDirections.words(hint(0, 20)), "Naik")
        XCTAssertEqual(GuideDirections.words(hint(90, 20)), "Ke kanan")
        XCTAssertEqual(GuideDirections.words(hint(225, 20)), "Turun · Ke kiri")
        XCTAssertEqual(GuideDirections.words(hint(80, 10)), "Ke kanan", "komponen naik < 3° tidak disebut")
        XCTAssertEqual(GuideDirections.words(hint(45, 2)), "Hampir — tahan diam")
    }
}
