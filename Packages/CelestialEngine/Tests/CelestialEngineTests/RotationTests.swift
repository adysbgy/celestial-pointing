import XCTest
@testable import CelestialEngine

/// Quaternion: komposisi, konversi matriks, dan rotasi vektor.
final class RotationTests: XCTestCase {

    private let quarterTurn = try! XCTUnwrap(
        Quaternion.axisAngle(axis: Vector3.unitZ, radians: .pi / 2)
    )

    func testIdentityLeavesVectorUnchanged() {
        let v = Vector3(x: 1, y: 2, z: 3)
        let r = Quaternion.identity.rotated(v)
        XCTAssertEqual(r.x, v.x, accuracy: 1e-12)
        XCTAssertEqual(r.y, v.y, accuracy: 1e-12)
        XCTAssertEqual(r.z, v.z, accuracy: 1e-12)
    }

    func testQuarterTurnAboutZMapsXToY() {
        let r = quarterTurn.rotated(.unitX)
        XCTAssertEqual(r.x, 0, accuracy: 1e-12)
        XCTAssertEqual(r.y, 1, accuracy: 1e-12)
        XCTAssertEqual(r.z, 0, accuracy: 1e-12)
    }

    func testQuarterTurnAboutZMapsYToMinusX() {
        let r = quarterTurn.rotated(.unitY)
        XCTAssertEqual(r.x, -1, accuracy: 1e-12)
        XCTAssertEqual(r.y, 0, accuracy: 1e-12)
    }

    func testRotationMatrixMatchesRotatedVector() {
        let v = Vector3(x: 0.3, y: -0.7, z: 0.2)
        let viaMatrix = quarterTurn.rotationMatrix.multiplied(by: v)
        let viaQuat = quarterTurn.rotated(v)
        XCTAssertEqual(viaMatrix.x, viaQuat.x, accuracy: 1e-12)
        XCTAssertEqual(viaMatrix.y, viaQuat.y, accuracy: 1e-12)
        XCTAssertEqual(viaMatrix.z, viaQuat.z, accuracy: 1e-12)
    }

    func testRotationMatrixIsOrthonormal() {
        XCTAssertTrue(quarterTurn.rotationMatrix.isRotation())
    }

    func testConjugateUndoesRotation() {
        let v = Vector3(x: 0.4, y: 0.1, z: -0.9)
        let roundTrip = quarterTurn.conjugate.rotated(quarterTurn.rotated(v))
        XCTAssertEqual(roundTrip.x, v.x, accuracy: 1e-12)
        XCTAssertEqual(roundTrip.y, v.y, accuracy: 1e-12)
        XCTAssertEqual(roundTrip.z, v.z, accuracy: 1e-12)
    }

    func testCompositionOrderIsRotationThenApply() {
        // q = a * b berarti: terapkan b dulu, lalu a.
        let a = try! XCTUnwrap(Quaternion.axisAngle(axis: Vector3.unitZ, radians: .pi / 2))
        let b = try! XCTUnwrap(Quaternion.axisAngle(axis: Vector3.unitX, radians: .pi / 2))
        let composed = a.multiplied(by: b)

        let stepwise = a.rotated(b.rotated(.unitY))
        let direct = composed.rotated(.unitY)
        XCTAssertEqual(stepwise.x, direct.x, accuracy: 1e-12)
        XCTAssertEqual(stepwise.y, direct.y, accuracy: 1e-12)
        XCTAssertEqual(stepwise.z, direct.z, accuracy: 1e-12)
    }

    func testAxisAngleRejectsZeroAxis() {
        XCTAssertNil(Quaternion.axisAngle(axis: .zero, radians: 1.0))
    }

    func testNormalizeFixesNonUnitQuaternion() {
        let q = Quaternion(w: 2, x: 0, y: 0, z: 0).normalized
        XCTAssertEqual(q!.magnitude, 1.0, accuracy: 1e-12)
        XCTAssertEqual(q!.w, 1.0, accuracy: 1e-12)
    }

    func testCMComponentOrderIsMappedCorrectly() {
        // CMQuaternion menyimpan (x, y, z, w). Pastikan tidak tertukar.
        let q = Quaternion(cmX: 0, cmY: 0, cmZ: 1, cmW: 0)
        XCTAssertEqual(q.w, 0)
        XCTAssertEqual(q.z, 1)
    }

    func testHalfTurnAboutXFlipsYAndZ() {
        let half = try! XCTUnwrap(Quaternion.axisAngle(axis: Vector3.unitX, radians: .pi))
        let r = half.rotated(Vector3(x: 0, y: 1, z: 1))
        XCTAssertEqual(r.x, 0, accuracy: 1e-12)
        XCTAssertEqual(r.y, -1, accuracy: 1e-12)
        XCTAssertEqual(r.z, -1, accuracy: 1e-12)
    }
}
