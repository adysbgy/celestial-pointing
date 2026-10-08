import XCTest
@testable import CelestialEngine

/// Pemilihan sumbu tunjuk dari data dan solver Wahba (ADR-002, ADR-003).
final class AxisCalibrationTests: XCTestCase {

    private let targets = [
        HorizontalCoord(altitudeDeg: 12, azimuthDeg: 40),
        HorizontalCoord(altitudeDeg: 55, azimuthDeg: 130),
        HorizontalCoord(altitudeDeg: 30, azimuthDeg: 250),
        HorizontalCoord(altitudeDeg: 75, azimuthDeg: 330),
    ]

    /// Sampel dari "jam" yang sebenarnya menunjuk dengan `trueAim`, di
    /// kerangka sembarang yang sumbu-X-nya menghadap `headingDeg` dari Utara.
    private func samples(trueAim: DeviceAimAxis, headingDeg: Double) -> [AxisSample] {
        // Kerangka sembarang = kerangka berutara yang diputar mengelilingi
        // vertikal; attitude terhadap kerangka itu = R_z(heading) · q_north.
        let toArbitrary = Quaternion.axisAngle(axis: .unitZ, radians: SkyMath.deg2rad(headingDeg))!
        return targets.map { t in
            let north = DeviceAttitude.synthetic(aim: trueAim, pointingAt: t, frame: .xTrueNorthZVertical)
            let q = toArbitrary.multiplied(by: north.quaternion)
            return AxisSample(attitude: DeviceAttitude(quaternion: q, frame: .xArbitraryZVertical),
                              truth: t)
        }
    }

    func testPicksTheTrueAxisInArbitraryFrame() {
        for aim in [DeviceAimAxis.screenLeft, .screenRight, .screenUp] {
            let scores = AxisSelection.evaluate(samples(trueAim: aim, headingDeg: 117))
            XCTAssertEqual(scores.first?.aim, aim)
            XCTAssertLessThan(scores.first!.rmsErrorDeg, 1e-6)
            XCTAssertGreaterThan(scores[1].rmsErrorDeg, 5, "kandidat lain harus jelas lebih buruk")
            XCTAssertEqual(scores.count, DeviceAimAxis.selectionCandidates.count,
                           "semua kandidat harus dinilai dan dicatat")
        }
    }

    /// Putaran +117° mengelilingi vertikal (berlawanan jarum jam dilihat dari
    /// atas) membuat azimut terukur 117° lebih kecil dari sebenarnya, jadi
    /// offset yang harus ditambahkan adalah +117°.
    func testYawOffsetRecoversArbitraryHeading() {
        let best = AxisSelection.evaluate(samples(trueAim: .screenRight, headingDeg: 117)).first!
        let yaw = try! XCTUnwrap(best.yawOffsetDeg)
        XCTAssertEqual(SkyMath.normalizeDeg(yaw - 117 + 180) - 180, 0, accuracy: 1e-6)
    }

    func testNorthFrameNeedsNoYawAndFitsDeviceAxis() {
        // Sumbu sebenarnya miring 10° dari +X ke arah +Z (jam sedikit
        // menengadah di pergelangan).
        let tilted = Vector3(x: cos(SkyMath.deg2rad(10)), y: 0, z: sin(SkyMath.deg2rad(10)))
        let samples = targets.map { t -> AxisSample in
            let ref = AttitudeReferenceFrame.referenceToENU.transpose
                .multiplied(by: LocalFrame.enuFromHorizontal(t))
            let q = Quaternion.shortestArc(from: tilted, to: ref)
            return AxisSample(attitude: DeviceAttitude(quaternion: q, frame: .xTrueNorthZVertical),
                              truth: t)
        }
        let best = AxisSelection.evaluate(samples).first!
        XCTAssertNil(best.yawOffsetDeg)
        XCTAssertEqual(best.aim, .screenRight)
        let fitted = try! XCTUnwrap(AxisSelection.fittedDeviceAxis(samples))
        XCTAssertLessThan(fitted.angleDegrees(to: tilted)!, 1e-6)
    }

    func testFittedAxisRefusesArbitraryFrame() {
        XCTAssertNil(AxisSelection.fittedDeviceAxis(samples(trueAim: .screenRight, headingDeg: 0)))
    }

    // MARK: - Wahba

    func testWahbaRecoversKnownRotation() {
        let r = Quaternion.axisAngle(axis: Vector3(x: 0.3, y: -0.5, z: 0.8), radians: 0.4)!
        let measured = targets.map(LocalFrame.enuFromHorizontal)
        let truth = measured.map(r.rotated)
        let s = try! XCTUnwrap(WahbaSolver.solve(measured: measured, truth: truth))
        XCTAssertLessThan(s.residualRMSDeg, 1e-6)
        XCTAssertLessThan(s.rotation.angleDegrees(to: r)!, 1e-6)
    }

    /// Dua acuan tak segaris sudah cukup menentukan rotasi.
    func testWahbaWorksWithTwoReferences() {
        let r = Quaternion.axisAngle(axis: .unitZ, radians: SkyMath.deg2rad(25))!
        let measured = Array(targets.prefix(2).map(LocalFrame.enuFromHorizontal))
        let s = try! XCTUnwrap(WahbaSolver.solve(measured: measured, truth: measured.map(r.rotated)))
        XCTAssertLessThan(s.rotation.angleDegrees(to: r)!, 1e-6)
    }

    func testWahbaRejectsUnobservableInput() {
        let v = LocalFrame.enuFromHorizontal(targets[0])
        XCTAssertNil(WahbaSolver.solve(measured: [v], truth: [v]))
        XCTAssertNil(WahbaSolver.solve(measured: [v, v], truth: [v, v]))
    }

    /// Dengan noise, residu Wahba tidak boleh lebih buruk dari model
    /// yaw-saja (Wahba memuat yaw-saja sebagai kasus khusus).
    func testWahbaResidualNotWorseThanYawOnly() {
        let measuredH = targets.enumerated().map { i, t in
            HorizontalCoord(altitudeDeg: t.altitudeDeg + [1.5, -2.0, 0.7, 2.5][i],
                            azimuthDeg: t.azimuthDeg + 20 + [0.8, -1.2, 2.0, -0.5][i])
        }
        let yawOnly = CalibrationSolver.solve(measured: measuredH, truth: targets)!
        let wahba = WahbaSolver.solve(measured: measuredH.map(LocalFrame.enuFromHorizontal),
                                      truth: targets.map(LocalFrame.enuFromHorizontal))!
        XCTAssertLessThanOrEqual(wahba.residualRMSDeg, yawOnly.residualSpreadDeg! + 1e-9)
    }
}
