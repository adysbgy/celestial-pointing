import XCTest
@testable import CelestialEngine

/// Perata orientasi dan pelacak kecepatan sudut.
final class SensingTests: XCTestCase {

    private func rotZ(_ deg: Double) -> Quaternion {
        Quaternion.axisAngle(axis: Vector3.unitZ, radians: SkyMath.deg2rad(deg))!
    }

    // MARK: - PointingSmoother

    func testFirstSampleBecomesReference() {
        var s = PointingSmoother(blendFactor: 0.3)
        let q = rotZ(40)
        let out = s.update(q)!
        XCTAssertEqual(out.angleDegrees(to: q)!, 0, accuracy: 1e-9)
    }

    func testFullBlendFollowsNewSampleExactly() {
        var s = PointingSmoother(blendFactor: 1.0)
        s.update(.identity)
        let target = rotZ(50)
        let out = s.update(target)!
        XCTAssertEqual(out.angleDegrees(to: target)!, 0, accuracy: 1e-9)
    }

    func testPartialBlendLandsBetweenOldAndNew() {
        var s = PointingSmoother(blendFactor: 0.5)
        s.update(.identity)
        let target = rotZ(60)
        let out = s.update(target)!
        // nlerp t=0.5 dari 0° ke 60° mendarat tepat di 30°.
        XCTAssertEqual(out.angleDegrees(to: .identity)!, 30, accuracy: 1e-6)
        XCTAssertEqual(out.angleDegrees(to: target)!, 30, accuracy: 1e-6)
    }

    func testInvalidSampleDoesNotCorruptState() {
        var s = PointingSmoother(blendFactor: 0.3)
        s.update(rotZ(10))
        let before = s.current
        // Sampel nol tidak sah: keadaan tetap, dan yang dikembalikan = keadaan lama.
        XCTAssertEqual(s.update(Quaternion(w: 0, x: 0, y: 0, z: 0)), before)
        XCTAssertEqual(s.current, before)
    }

    func testResetForgetsReference() {
        var s = PointingSmoother(blendFactor: 0.3)
        s.update(rotZ(10))
        s.reset()
        XCTAssertNil(s.current)
    }

    /// Interpolasi harus menempuh busur terpendek walau quaternion tujuan
    /// adalah negatifnya (double cover).
    func testBlendTakesShortArcAcrossDoubleCover() {
        var s = PointingSmoother(blendFactor: 1.0)
        s.update(.identity)
        let negated = Quaternion(w: -1, x: 0, y: 0, z: 0)
        let out = s.update(negated)!
        // -identity adalah orientasi yang sama; hasil harus identity, bukan putaran 360°.
        XCTAssertEqual(out.angleDegrees(to: .identity)!, 0, accuracy: 1e-9)
    }

    // MARK: - AngularRateTracker

    func testFirstSampleHasNoRate() {
        var t = AngularRateTracker()
        XCTAssertNil(t.update(.identity, at: Date(timeIntervalSince1970: 0)))
    }

    func testRateIsAngleOverTime() {
        var t = AngularRateTracker()
        let t0 = Date(timeIntervalSince1970: 100)
        t.update(.identity, at: t0)
        // 90° dalam 1 detik = 90 derajat/detik.
        let rate = t.update(rotZ(90), at: t0.addingTimeInterval(1.0))!
        XCTAssertEqual(rate, 90, accuracy: 1e-6)
    }

    func testStationaryDeviceHasZeroRate() {
        var t = AngularRateTracker()
        let t0 = Date(timeIntervalSince1970: 100)
        t.update(.identity, at: t0)
        XCTAssertEqual(t.update(.identity, at: t0.addingTimeInterval(0.5))!, 0, accuracy: 1e-9)
    }

    func testDoubleCoverGivesZeroRate() {
        var t = AngularRateTracker()
        let t0 = Date(timeIntervalSince1970: 100)
        t.update(.identity, at: t0)
        // Negatif identity = orientasi sama; laju harus nol, bukan 360°/dt.
        let rate = t.update(Quaternion(w: -1, x: 0, y: 0, z: 0),
                            at: t0.addingTimeInterval(0.1))!
        XCTAssertEqual(rate, 0, accuracy: 1e-9)
    }

    func testGapSuppressesRate() {
        var t = AngularRateTracker(maxGapSeconds: 1.0)
        let t0 = Date(timeIntervalSince1970: 100)
        t.update(.identity, at: t0)
        // Jeda 5 detik: laju tidak dihitung, bukan ditebak.
        XCTAssertNil(t.update(rotZ(90), at: t0.addingTimeInterval(5.0)))
    }

    func testNonAdvancingTimestampSuppressesRate() {
        var t = AngularRateTracker()
        let t0 = Date(timeIntervalSince1970: 100)
        t.update(.identity, at: t0)
        XCTAssertNil(t.update(rotZ(90), at: t0))
    }

    func testResetClearsRate() {
        var t = AngularRateTracker()
        let t0 = Date(timeIntervalSince1970: 100)
        t.update(.identity, at: t0)
        t.update(rotZ(90), at: t0.addingTimeInterval(1.0))
        XCTAssertNotNil(t.angularRateDegPerSec)
        t.reset()
        XCTAssertNil(t.angularRateDegPerSec)
    }
}
