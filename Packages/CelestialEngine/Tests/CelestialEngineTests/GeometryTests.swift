import XCTest
@testable import CelestialEngine

/// Matematika vektor & matriks dasar — fondasi seluruh rantai pointing.
/// Diuji dengan nilai yang bisa dihitung tangan, bukan sekadar sifat umum.
final class GeometryTests: XCTestCase {

    // MARK: - Vector3

    func testNormalizeProducesUnitLength() {
        let v = Vector3(x: 3, y: 0, z: 4)
        let n = try! XCTUnwrap(v.normalized)
        XCTAssertEqual(n.magnitude, 1.0, accuracy: 1e-12)
        XCTAssertEqual(n.x, 0.6, accuracy: 1e-12)
        XCTAssertEqual(n.z, 0.8, accuracy: 1e-12)
    }

    func testZeroVectorHasNoDirection() {
        XCTAssertNil(Vector3.zero.normalized)
    }

    func testNonFiniteVectorHasNoDirection() {
        XCTAssertNil(Vector3(x: .nan, y: 0, z: 0).normalized)
        XCTAssertNil(Vector3(x: .infinity, y: 0, z: 0).normalized)
    }

    func testDotAndCrossOfBasisVectors() {
        XCTAssertEqual(Vector3.unitX.dot(Vector3.unitY), 0, accuracy: 1e-15)
        XCTAssertEqual(Vector3.unitX.dot(Vector3.unitX), 1, accuracy: 1e-15)

        let z = Vector3.unitX.cross(Vector3.unitY)
        XCTAssertEqual(z.x, 0, accuracy: 1e-15)
        XCTAssertEqual(z.y, 0, accuracy: 1e-15)
        XCTAssertEqual(z.z, 1, accuracy: 1e-15)
    }

    func testAngleBetweenBasisVectorsIsRightAngle() {
        XCTAssertEqual(Vector3.unitX.angleDegrees(to: Vector3.unitY)!, 90, accuracy: 1e-9)
        XCTAssertEqual(Vector3.unitX.angleDegrees(to: Vector3.unitX)!, 0, accuracy: 1e-9)
        XCTAssertEqual(Vector3.unitX.angleDegrees(to: -Vector3.unitX)!, 180, accuracy: 1e-9)
    }

    func testAngleIsIndependentOfLength() {
        let a = Vector3(x: 5, y: 0, z: 0)
        let b = Vector3(x: 0, y: 0.001, z: 0)
        XCTAssertEqual(a.angleDegrees(to: b)!, 90, accuracy: 1e-6)
    }

    // MARK: - Matrix3x3

    func testIdentityIsNeutral() {
        let m = Matrix3x3(m11: 1, m12: 2, m13: 3,
                          m21: 4, m22: 5, m23: 6,
                          m31: 7, m32: 8, m33: 10)
        XCTAssertEqual(m.multiplied(by: .identity), m)
        XCTAssertEqual(Matrix3x3.identity.multiplied(by: m), m)
    }

    func testTransposeTimesSelfIsIdentityForRotation() {
        // Rotasi 90° mengelilingi Z.
        let r = Matrix3x3(m11: 0, m12: -1, m13: 0,
                          m21: 1, m22: 0, m23: 0,
                          m31: 0, m32: 0, m33: 1)
        XCTAssertTrue(r.isRotation())
        XCTAssertEqual(r.multiplied(by: r.transpose), .identity)
        XCTAssertEqual(r.determinant, 1, accuracy: 1e-12)
    }

    func testRotationMapsXToY() {
        let r = Matrix3x3(m11: 0, m12: -1, m13: 0,
                          m21: 1, m22: 0, m23: 0,
                          m31: 0, m32: 0, m33: 1)
        let mapped = r.multiplied(by: .unitX)
        XCTAssertEqual(mapped.x, 0, accuracy: 1e-12)
        XCTAssertEqual(mapped.y, 1, accuracy: 1e-12)
        XCTAssertEqual(mapped.z, 0, accuracy: 1e-12)
    }

    func testNonOrthonormalMatrixIsNotARotation() {
        let scale = Matrix3x3(m11: 2, m12: 0, m13: 0,
                              m21: 0, m22: 1, m23: 0,
                              m31: 0, m32: 0, m33: 1)
        XCTAssertFalse(scale.isRotation())
        XCTAssertEqual(scale.determinant, 2, accuracy: 1e-12)
    }

    func testReflectionIsNotARotation() {
        // Pencerminan (determinan -1) bukan rotasi.
        let mirror = Matrix3x3(m11: -1, m12: 0, m13: 0,
                               m21: 0, m22: 1, m23: 0,
                               m31: 0, m32: 0, m33: 1)
        XCTAssertFalse(mirror.isRotation())
        XCTAssertEqual(mirror.determinant, -1, accuracy: 1e-12)
    }
}
