import XCTest
@testable import CelestialEngine

/// Uji penyaring visibilitas. Semua nilai ditulis tangan — tidak menyentuh
/// efemeris — supaya aturannya bisa diuji terpisah dari akurasi posisi.
final class VisibilityTests: XCTestCase {

    private let night = SkyContext(sunAltitudeDeg: -40, isDark: true)
    private let day = SkyContext(sunAltitudeDeg: 20, isDark: false)
    private let policy = VisibilityPolicy()

    // MARK: - Aturan dasar

    func testVisibleObjectIsCandidate() {
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 1.0, separationFromSunDeg: 120,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .visible)
        XCTAssertTrue(result.isCandidate)
    }

    func testBelowHorizonIsRejected() {
        let result = VisibilityFilter.classify(
            altitudeDeg: -3, magnitude: 1.0, separationFromSunDeg: 120,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .belowHorizon)
        XCTAssertFalse(result.isCandidate)
    }

    /// Ambang ketinggian bersifat inklusif: benda tepat di `minAltitudeDeg`
    /// masih lolos, yang di bawahnya dibuang.
    func testMinimumAltitudeBoundaryIsInclusive() {
        let atLimit = VisibilityFilter.classify(
            altitudeDeg: policy.minAltitudeDeg, magnitude: 1.0,
            separationFromSunDeg: 120, context: night, policy: policy
        )
        XCTAssertEqual(atLimit, .visible, "tepat di ambang masih terlihat")

        let below = VisibilityFilter.classify(
            altitudeDeg: policy.minAltitudeDeg - 0.1, magnitude: 1.0,
            separationFromSunDeg: 120, context: night, policy: policy
        )
        XCTAssertEqual(below, .belowHorizon)
    }

    func testTooFaintIsRejected() {
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 8.5, separationFromSunDeg: 120,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .tooFaint)
    }

    func testDaylightRejectsEverything() {
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: -1.0, separationFromSunDeg: 120,
            context: day, policy: policy
        )
        XCTAssertEqual(result, .daylight)
    }

    // MARK: - Pengaman Matahari

    /// Ini pengaman keras: benda yang terlalu dekat Matahari tidak boleh jadi
    /// target, karena GoTo ke arah Matahari merusak teleskop dan mata.
    func testTooCloseToSunIsRejectedEvenAtNight() {
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: -4.0, separationFromSunDeg: 12,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .tooCloseToSun)
        XCTAssertFalse(result.isCandidate)
    }

    func testSunItselfIsNeverRejectedForBeingCloseToItself() {
        // separationFromSunDeg == nil berarti "ini Matahari"; tidak boleh
        // ditolak oleh aturan jarak-Matahari (ia tetap ditolak sebagai target
        // lewat `pointableBodies`, bukan lewat aturan ini).
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: -26.7, separationFromSunDeg: nil,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .visible)
    }

    // MARK: - Urutan prioritas

    /// Benda di bawah horizon DAN redup harus dilaporkan sebagai di bawah
    /// horizon — alasannya lebih mendasar dan itu yang berguna untuk UI.
    func testBelowHorizonTakesPrecedenceOverFaintness() {
        let result = VisibilityFilter.classify(
            altitudeDeg: -20, magnitude: 12.0, separationFromSunDeg: 90,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .belowHorizon)
    }

    // MARK: - Batas senja

    func testDarknessBoundary() {
        XCTAssertTrue(VisibilityFilter.isDark(sunAltitudeDeg: -18, policy: policy))
        XCTAssertFalse(VisibilityFilter.isDark(sunAltitudeDeg: 0, policy: policy))
        XCTAssertFalse(VisibilityFilter.isDark(sunAltitudeDeg: -6, policy: policy),
                       "batas senja sipil: tepat di -6° belum dianggap gelap")
        XCTAssertTrue(VisibilityFilter.isDark(sunAltitudeDeg: -6.1, policy: policy))
    }

    func testPermissivePolicyRejectsNothing() {
        for altitude in [-90.0, -1.0, 0.0, 45.0] {
            for magnitude in [-26.0, 6.0, 20.0] {
                let result = VisibilityFilter.classify(
                    altitudeDeg: altitude, magnitude: magnitude,
                    separationFromSunDeg: 0, context: day,
                    policy: .permissive
                )
                XCTAssertEqual(result, .visible,
                               "kebijakan permissive tidak boleh menolak apa pun")
            }
        }
    }
}

// MARK: - Benda tata surya

final class EphemerisBodyTests: XCTestCase {

    /// Matahari tidak boleh pernah menjadi target pointing.
    func testSunIsNotPointable() {
        XCTAssertFalse(EphemerisBody.sun.isPointable)
        XCTAssertFalse(EphemerisBody.pointableBodies.contains(.sun))
        XCTAssertEqual(EphemerisBody.pointableBodies.count, EphemerisBody.allCases.count - 1)
    }

    func testPointableBodiesAreAllPointable() {
        for body in EphemerisBody.pointableBodies {
            XCTAssertTrue(body.isPointable, "\(body) seharusnya bisa ditunjuk")
        }
    }
}
