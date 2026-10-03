import XCTest
@testable import CelestialEngine

/// Mesin keadaan alur pointing: kapan engine boleh menjawab, dan kapan harus ragu.
///
/// Catatan waktu: `Date` menyimpan `Double`, jadi selisih seperti 0.5 − 0.1
/// tidak persis 0.4. Uji ini sengaja memakai jarak yang jauh dari ambang supaya
/// tidak rapuh terhadap pembulatan — mesinnya sendiri tidak boleh bergantung
/// pada sampel yang tepat di batas.
final class PointingFlowTests: XCTestCase {

    private let target = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                         raDeg: 101.287, decDeg: -16.716, magnitude: -1.46)
    private let aim = HorizontalCoord(altitudeDeg: 30, azimuthDeg: 90)
    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    private func intent(_ level: ConfidenceLevel) -> CelestialIntent {
        CelestialIntent(level: level, best: target, candidates: [])
    }

    private func rotZ(_ deg: Double) -> Quaternion {
        Quaternion.axisAngle(axis: Vector3.unitZ, radians: SkyMath.deg2rad(deg))!
    }

    // MARK: - Keadaan sensor

    func testUnavailableSensorNeverGuesses() {
        var m = PointingStateMachine(isSensorAvailable: false)
        m.update(quaternion: .identity, pointing: aim, timestamp: t0) { _ in self.intent(.high) }
        XCTAssertEqual(m.state, .unavailable)
        XCTAssertNil(m.currentIntent)
    }

    /// Sampel pertama belum punya pembanding, jadi dianggap masih bergerak.
    func testFirstSampleIsPointingNotLock() {
        var m = PointingStateMachine()
        m.update(quaternion: .identity, pointing: aim, timestamp: t0) { _ in self.intent(.high) }
        XCTAssertEqual(m.state, .pointing)
    }

    func testFastMovementStaysPointingAndNeverResolves() {
        var m = PointingStateMachine()
        var resolved = false
        // 90° tiap 0.1 dtk = 900°/dtk, jauh di atas ambang.
        for i in 0..<10 {
            m.update(quaternion: rotZ(Double(i) * 90),
                     pointing: aim,
                     timestamp: at(Double(i) * 0.1)) { _ in
                resolved = true
                return self.intent(.high)
            }
        }
        XCTAssertEqual(m.state, .pointing)
        XCTAssertFalse(resolved, "tidak boleh resolusi saat lengan masih menyapu")
        XCTAssertNil(m.currentIntent)
    }

    // MARK: - Kunci setelah stabil

    func testLocksOnlyAfterHoldingStill() {
        var m = PointingStateMachine()
        let r: (HorizontalCoord) -> CelestialIntent = { _ in self.intent(.high) }

        m.update(quaternion: .identity, pointing: aim, timestamp: at(0), resolve: r)
        XCTAssertEqual(m.state, .pointing)

        // Mulai diam, tapi belum cukup lama.
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0.1), resolve: r)
        XCTAssertEqual(m.state, .pointing, "belum melewati maxHoldSeconds")

        m.update(quaternion: .identity, pointing: aim, timestamp: at(0.3), resolve: r)
        XCTAssertEqual(m.state, .pointing, "0.2 dtk masih di bawah ambang 0.4")

        // Sudah diam ~0.9 dtk.
        m.update(quaternion: .identity, pointing: aim, timestamp: at(1.0), resolve: r)
        XCTAssertEqual(m.state, .lock)
        XCTAssertEqual(m.currentIntent?.best?.id, "sirius")
    }

    /// Keyakinan medium menjadi `uncertain`, bukan dipaksa menjadi jawaban pasti.
    func testMediumConfidenceBecomesUncertainNotLock() {
        var m = PointingStateMachine()
        let r: (HorizontalCoord) -> CelestialIntent = { _ in self.intent(.medium) }
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0), resolve: r)
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0.1), resolve: r)
        m.update(quaternion: .identity, pointing: aim, timestamp: at(1.0), resolve: r)
        XCTAssertEqual(m.state, .uncertain)
        XCTAssertEqual(m.currentIntent?.best?.id, "sirius")
    }

    func testNoCandidateBecomesSearching() {
        var m = PointingStateMachine()
        let empty = CelestialIntent(level: .low, best: nil, candidates: [])
        let r: (HorizontalCoord) -> CelestialIntent = { _ in empty }
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0), resolve: r)
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0.1), resolve: r)
        m.update(quaternion: .identity, pointing: aim, timestamp: at(1.0), resolve: r)
        XCTAssertEqual(m.state, .searching)
    }

    /// Bergerak lagi setelah terkunci harus membatalkan tampilan terkunci.
    func testMovementAfterLockReturnsToPointing() {
        var m = PointingStateMachine()
        let r: (HorizontalCoord) -> CelestialIntent = { _ in self.intent(.high) }
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0), resolve: r)
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0.1), resolve: r)
        m.update(quaternion: .identity, pointing: aim, timestamp: at(1.0), resolve: r)
        XCTAssertEqual(m.state, .lock)

        // Sapuan cepat: 120° dalam 0.1 dtk.
        m.update(quaternion: rotZ(120), pointing: aim, timestamp: at(1.1), resolve: r)
        XCTAssertEqual(m.state, .pointing)
    }

    // MARK: - Laju resolusi

    func testResolutionRespectsSearchInterval() {
        var m = PointingStateMachine()
        var calls = 0
        let r: (HorizontalCoord) -> CelestialIntent = { _ in
            calls += 1
            return self.intent(.high)
        }
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0), resolve: r)   // diam mulai
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0.1), resolve: r) // stabil sejak 0.1
        m.update(quaternion: .identity, pointing: aim, timestamp: at(1.0), resolve: r) // resolusi #1
        XCTAssertEqual(calls, 1)

        m.update(quaternion: .identity, pointing: aim, timestamp: at(1.1), resolve: r) // 0.1 < interval
        XCTAssertEqual(calls, 1, "belum waktunya resolusi ulang")

        m.update(quaternion: .identity, pointing: aim, timestamp: at(1.4), resolve: r) // 0.4 ≥ interval
        XCTAssertEqual(calls, 2)
    }

    func testStopResetsEverything() {
        var m = PointingStateMachine()
        let r: (HorizontalCoord) -> CelestialIntent = { _ in self.intent(.high) }
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0), resolve: r)
        m.update(quaternion: .identity, pointing: aim, timestamp: at(0.1), resolve: r)
        m.update(quaternion: .identity, pointing: aim, timestamp: at(1.0), resolve: r)
        XCTAssertEqual(m.state, .lock)

        m.stop()
        XCTAssertEqual(m.state, .idle)
        XCTAssertNil(m.currentIntent)
        XCTAssertNil(m.angularRateDegPerSec)
    }

    func testHasAnswerOnlyForLockAndUncertain() {
        XCTAssertTrue(PointingState.lock.hasAnswer)
        XCTAssertTrue(PointingState.uncertain.hasAnswer)
        XCTAssertFalse(PointingState.pointing.hasAnswer)
        XCTAssertFalse(PointingState.searching.hasAnswer)
        XCTAssertFalse(PointingState.idle.hasAnswer)
        XCTAssertFalse(PointingState.unavailable.hasAnswer)
    }
}
