import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Geometri 3D yang jujur (ADR-017).
final class Scene3DTests: XCTestCase {

    private func eq(_ ra: Double, _ dec: Double) -> EquatorialCoord { EquatorialCoord(raDeg: ra, decDeg: dec) }

    /// Memandang langit dengan Utara di atas: Timur di kiri.
    func testBasisPutsNorthUpAndEastLeft() {
        let b = Scene3D.basis(lookingAt: Scene3D.unit(eq(0, 0)))
        XCTAssertEqual(b.up.z, 1, accuracy: 1e-12)
        let east = Scene3D.unit(eq(90, 0))
        XCTAssertLessThan(b.toCamera(east).x, -0.99, "Timur di kiri")
        XCTAssertEqual(b.toCamera(Scene3D.unit(eq(0, 0))).z, -1, accuracy: 1e-12, "benda di depan kamera (−z)")
    }

    func testPhaseAngle() {
        XCTAssertEqual(Scene3D.phaseAngleDeg(illumination: 1), 0, accuracy: 1e-9)
        XCTAssertEqual(Scene3D.phaseAngleDeg(illumination: 0.5), 90, accuracy: 1e-9)
        XCTAssertEqual(Scene3D.phaseAngleDeg(illumination: 0), 180, accuracy: 1e-9)
    }

    /// Bulan setengah dengan Matahari di Barat-nya (RA lebih kecil): sisi
    /// kanan (Barat) yang terang, dan cahaya tegak lurus garis pandang.
    func testHalfMoonIsLitTowardTheSun() {
        let l = Scene3D.lightDirection(object: eq(90, 0), sun: eq(0, 0), illumination: 0.5)
        XCTAssertEqual(l.z, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(l.x, 0.99, "Matahari di Barat → terang di kanan")
        let full = Scene3D.lightDirection(object: eq(180, 0), sun: eq(0, 0), illumination: 1)
        XCTAssertEqual(full.z, 1, accuracy: 1e-9, "purnama: cahaya dari arah kamera")
    }

    /// Cincin Saturnus 2026 masih dekat bidang tepi (Bumi melintasi bidang
    /// cincin Maret 2025), dan saat menghadap kutub cincin terbuka penuh.
    func testRingOpening() throws {
        let resolver = EngineFactory.makeResolver()
        let date = ISO8601DateFormatter().date(from: "2026-10-10T12:00:00Z")!
        let sample = try XCTUnwrap(try resolver.ephemeris?.apparent(.saturn, at: date))
        let b = Scene3D.ringOpeningDeg(saturn: eq(sample.raDeg, sample.decDeg))
        XCTAssertLessThan(abs(b), 12)
        XCTAssertGreaterThan(abs(b), 1)
        XCTAssertEqual(abs(Scene3D.ringOpeningDeg(saturn: eq(40.589 + 180, -83.537))), 90, accuracy: 1e-6)
    }

    /// Bulan–Jupiter 3 Nov 2026: jarak pada tata letak = jarak sudut.
    func testConjunctionLayoutKeepsSeparation() {
        let a = eq(100, 20), b = eq(101, 20.5)
        let layout = Scene3D.conjunctionLayout(a, b)
        let d = hypot(layout.a.x - layout.b.x, layout.a.y - layout.b.y)
        let truth = SkyMath.angularSeparationDeg(a, b)
        XCTAssertEqual(d, truth, accuracy: 0.001)
        XCTAssertGreaterThan(layout.b.y, layout.a.y, "b lebih ke Utara → lebih atas")
        XCTAssertLessThan(layout.b.x, layout.a.x, "b lebih ke Timur → lebih kiri")
    }

    func testBakedSphereIsLitOnTheSunSideOnly() {
        let white = CelestialVisual.RGBComponents(red: 1, green: 1, blue: 1)
        let img = Scene3D.bakedSphere(width: 64, height: 32, light: Vector3(x: 0, y: 1, z: 0)) { _ in white }
        XCTAssertGreaterThan(img.pixel(10, 1).r, 200, "dekat kutub +y: terang")
        XCTAssertLessThan(img.pixel(10, 30).r, 15, "dekat kutub −y: gelap (hanya cahaya sekitar)")
        XCTAssertEqual(img.pixel(10, 30).a, 255)
    }

    func testRingTextureIsTransparentInsideAndOutside() {
        let ring = Scene3D.ringTexture(size: 64, color: .init(red: 0.9, green: 0.8, blue: 0.6), brightness: 1)
        XCTAssertEqual(ring.pixel(32, 32).a, 0, "pusat (planet) transparan")
        XCTAssertEqual(ring.pixel(0, 0).a, 0, "sudut di luar cincin transparan")
        XCTAssertGreaterThan(ring.pixel(56, 32).a, 0, "di dalam cincin terlihat")
    }

    func testBandsFollowThePlanetEquator() {
        let bands: [CelestialVisual.RGBComponents] = [.init(red: 1, green: 0, blue: 0), .init(red: 0, green: 0, blue: 1)]
        let albedo = Scene3D.bandedAlbedo(pole: Vector3(x: 1, y: 0, z: 0), bands: bands)
        // Dua titik pada lintang planet yang sama (beda bujur) → pita sama.
        XCTAssertEqual(albedo(Vector3(x: 0.3, y: 0.95, z: 0)), albedo(Vector3(x: 0.3, y: 0, z: 0.95)))
    }

    /// Konvensi UV RealityKit yang diukur (ADR-017): u = 0.75 menghadap
    /// kamera (+z), u = 0 di kanan (+x), v = 0 di atas (+y).
    func testMeasuredRealityKitUVConvention() {
        let front = Scene3D.sphereNormal(u: 0.75, v: 0.5)
        XCTAssertEqual(front.z, 1, accuracy: 1e-9)
        let right = Scene3D.sphereNormal(u: 0, v: 0.5)
        XCTAssertEqual(right.x, 1, accuracy: 1e-9)
        let left = Scene3D.sphereNormal(u: 0.5, v: 0.5)
        XCTAssertEqual(left.x, -1, accuracy: 1e-9)
        XCTAssertEqual(Scene3D.sphereNormal(u: 0.3, v: 0).y, 1, accuracy: 1e-9)
    }

    func testPairLineKeepsTightConjunctionsReadable() {
        XCTAssertEqual(Scene3DText.pairLine("Bulan", "Jupiter", separationDeg: 0.15), "Bulan · Jupiter · 0,2°")
        XCTAssertEqual(Scene3DText.pairLine("Mars", "Jupiter", separationDeg: 12.4), "Mars · Jupiter · 12°")
    }
}
