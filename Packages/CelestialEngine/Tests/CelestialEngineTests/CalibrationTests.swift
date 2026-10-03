import XCTest
@testable import CelestialEngine

/// Kalibrasi: penyelesaian offset yaw dan estimasi sigma pointing.
final class CalibrationTests: XCTestCase {

    // MARK: - Rata-rata sirkular

    func testCircularMeanDoesNotWrapAroundAtZero() {
        // 359° dan 1° seharusnya rata-rata 0°, bukan 180°.
        let mean = CalibrationSolver.circularMeanDeg([359, 1])!
        XCTAssertTrue(mean < 1e-9 || mean > 360 - 1e-9, "didapat \(mean)")
    }

    func testCircularMeanOfIdenticalAngles() {
        XCTAssertEqual(CalibrationSolver.circularMeanDeg([45, 45, 45])!, 45, accuracy: 1e-9)
    }

    func testCircularMeanEmptyIsNil() {
        XCTAssertNil(CalibrationSolver.circularMeanDeg([]))
    }

    func testRootMeanSquare() {
        XCTAssertEqual(CalibrationSolver.rootMeanSquare([3, 4])!, sqrt(12.5), accuracy: 1e-12)
        XCTAssertNil(CalibrationSolver.rootMeanSquare([]))
    }

    // MARK: - Penyelesaian kalibrasi

    func testSolveRecoversConstantYawOffset() {
        let truth = [HorizontalCoord(altitudeDeg: 20, azimuthDeg: 10),
                     HorizontalCoord(altitudeDeg: 40, azimuthDeg: 100),
                     HorizontalCoord(altitudeDeg: 15, azimuthDeg: 250)]
        // Pengukuran selalu meleset 30° ke arah barat.
        let measured = truth.map {
            HorizontalCoord(altitudeDeg: $0.altitudeDeg,
                            azimuthDeg: SkyMath.normalizeDeg($0.azimuthDeg - 30))
        }

        let cal = CalibrationSolver.solve(measured: measured, truth: truth)!
        XCTAssertEqual(cal.yawOffsetDeg, 30, accuracy: 1e-9)
        XCTAssertEqual(cal.sampleCount, 3)
        // Toleransi 1e-4° (0.36″) karena jarak sudut dihitung lewat acos, yang
        // kehilangan presisi di dekat pemisahan nol. Sisa galat sesungguhnya
        // di sini ~1e-6°, jadi ini benar-benar nol secara praktis.
        XCTAssertEqual(cal.residualSpreadDeg!, 0, accuracy: 1e-4)

        // Setelah diterapkan, arah tunjuk harus tepat.
        for (m, t) in zip(measured, truth) {
            let corrected = cal.apply(to: m)
            XCTAssertEqual(corrected.azimuthDeg, t.azimuthDeg, accuracy: 1e-9)
            XCTAssertEqual(corrected.altitudeDeg, t.altitudeDeg, accuracy: 1e-9)
        }
    }

    func testApplyLeavesAltitudeUntouched() {
        let cal = PointingCalibration(yawOffsetDeg: 45, residualSpreadDeg: nil, sampleCount: 1)
        let corrected = cal.apply(to: HorizontalCoord(altitudeDeg: 33, azimuthDeg: 10))
        XCTAssertEqual(corrected.altitudeDeg, 33, accuracy: 1e-12)
        XCTAssertEqual(corrected.azimuthDeg, 55, accuracy: 1e-12)
    }

    func testApplyNormalizesAzimuth() {
        let cal = PointingCalibration(yawOffsetDeg: 350, residualSpreadDeg: nil, sampleCount: 1)
        let corrected = cal.apply(to: HorizontalCoord(altitudeDeg: 0, azimuthDeg: 20))
        XCTAssertEqual(corrected.azimuthDeg, 10, accuracy: 1e-12)
    }

    func testSolveRejectsMismatchedLengths() {
        let measured = [HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0)]
        let truth = [HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0),
                     HorizontalCoord(altitudeDeg: 0, azimuthDeg: 90)]
        XCTAssertNil(CalibrationSolver.solve(measured: measured, truth: truth))
    }

    func testSolveRejectsEmpty() {
        XCTAssertNil(CalibrationSolver.solve(measured: [], truth: []))
    }

    func testSolveRejectsNonFinite() {
        let measured = [HorizontalCoord(altitudeDeg: .nan, azimuthDeg: 0)]
        let truth = [HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0)]
        XCTAssertNil(CalibrationSolver.solve(measured: measured, truth: truth))
    }

    /// Satu titik acuan cukup untuk yaw, tapi tidak boleh mengklaim sigma.
    func testSingleSampleGivesYawButNoSpread() {
        let measured = [HorizontalCoord(altitudeDeg: 10, azimuthDeg: 350)]
        let truth = [HorizontalCoord(altitudeDeg: 10, azimuthDeg: 5)]
        let cal = CalibrationSolver.solve(measured: measured, truth: truth)!
        XCTAssertEqual(cal.yawOffsetDeg, 15, accuracy: 1e-9)
        XCTAssertNil(cal.residualSpreadDeg, "satu titik tidak bisa mengukur konsistensi")
    }

    /// Yaw menyerap kesalahan sistematis, tapi sisa galat acak harus muncul
    /// sebagai sigma — bukan disembunyikan.
    func testResidualSpreadReflectsRandomError() {
        let truth = [HorizontalCoord(altitudeDeg: 30, azimuthDeg: 0),
                     HorizontalCoord(altitudeDeg: 30, azimuthDeg: 90),
                     HorizontalCoord(altitudeDeg: 30, azimuthDeg: 180),
                     HorizontalCoord(altitudeDeg: 30, azimuthDeg: 270)]
        // Offset konstan 10°, plus galat altitude acak ±5°.
        let altitudeNoise = [5.0, -5.0, 5.0, -5.0]
        let measured = zip(truth, altitudeNoise).map { t, noise in
            HorizontalCoord(altitudeDeg: t.altitudeDeg + noise,
                            azimuthDeg: SkyMath.normalizeDeg(t.azimuthDeg - 10))
        }

        let cal = CalibrationSolver.solve(measured: measured, truth: truth)!
        XCTAssertEqual(cal.yawOffsetDeg, 10, accuracy: 1e-9)
        // Sisa galat = 5° RMS (hanya dari altitude; yaw sudah sempurna).
        XCTAssertEqual(cal.residualSpreadDeg!, 5.0, accuracy: 1e-6)
    }

    // MARK: - Jembatan ke model keyakinan

    func testMeasuredSigmaDrivesConfidencePolicy() {
        let cal = PointingCalibration(yawOffsetDeg: 0, residualSpreadDeg: 4.0, sampleCount: 10)
        let policy = cal.confidencePolicy()!
        XCTAssertEqual(policy.pointingSigmaDeg, 4.0, accuracy: 1e-12)
        // Ambang turunan ikut mengecil bersama sigma yang terukur.
        XCTAssertEqual(policy.maxSeparationDeg, 4.0, accuracy: 1e-12)
        XCTAssertEqual(policy.ambiguityDeg, 8.0, accuracy: 1e-12)
    }

    func testNoSpreadMeansNoPolicy() {
        XCTAssertNil(PointingCalibration.none.confidencePolicy())
        XCTAssertNil(PointingCalibration.none.suggestedPointingSigmaDeg)
    }

    /// Sigma yang lebih kecil membuat engine lebih berani memberi HIGH pada
    /// geometri yang sama — konsekuensi yang diinginkan dari kalibrasi.
    func testSmallerSigmaAllowsHighWhereLooseSigmaDidNot() {
        let candidates = [
            Candidate(object: CelestialObject(id: "a", name: "A", kind: .star,
                                              raDeg: 0, decDeg: 0, magnitude: 1),
                      separationDeg: 2.0),
            Candidate(object: CelestialObject(id: "b", name: "B", kind: .star,
                                              raDeg: 0, decDeg: 0, magnitude: 2),
                      separationDeg: 12.0)
        ]
        let loose = ConfidenceModel.evaluate(candidates: candidates, coneDeg: 20,
                                             nearestNeighbourDeg: 10,
                                             policy: ConfidencePolicy(pointingSigmaDeg: 10))
        XCTAssertEqual(loose.level, .medium, "dengan sigma 10°, 2° terlalu jauh untuk HIGH")

        let calibrated = ConfidenceModel.evaluate(candidates: candidates, coneDeg: 20,
                                                  nearestNeighbourDeg: 10,
                                                  policy: ConfidencePolicy(pointingSigmaDeg: 3))
        XCTAssertEqual(calibrated.level, .high, "dengan sigma 3°, 2° cukup dekat dan 10° cukup jauh")
    }
}
