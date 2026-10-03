import XCTest
@testable import CelestialEngine

/// Uji instrumentasi Experiment 1.
///
/// Yang diuji di sini bukan astronomi, melainkan **kejujuran pengukuran**:
/// false lock harus terdeteksi, keraguan tidak boleh dihitung sebagai
/// kesalahan, dan statistiknya benar.
final class ObservationLogTests: XCTestCase {

    let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    let date = Date(timeIntervalSince1970: 1_767_286_800) // 2026-01-01T15:00Z

    // MARK: - Helper

    func object(id: String) -> CelestialObject {
        CelestialObject(id: id, name: id.capitalized, kind: .star,
                        raDeg: 100, decDeg: -16, magnitude: 1.0)
    }

    func trial(pointingAlt: Double, pointingAz: Double,
               bestID: String?, level: ConfidenceLevel,
               truthID: String?,
               calibrated: HorizontalCoord? = nil,
               note: String? = nil) -> PointingTrial {
        let intent = CelestialIntent(
            level: level,
            best: bestID.map { object(id: $0) },
            candidates: []
        )
        return PointingTrial(
            timestamp: date,
            observer: observer,
            rawPointing: HorizontalCoord(altitudeDeg: pointingAlt, azimuthDeg: pointingAz),
            calibratedPointing: calibrated,
            intent: intent,
            groundTruthObjectID: truthID,
            note: note
        )
    }

    // MARK: - Analisis dasar

    func testCorrectGuessIsNotAFalseLock() throws {
        let t = trial(pointingAlt: 40, pointingAz: 180, bestID: "sirius",
                      level: .high, truthID: "sirius")
        let analysis = try XCTUnwrap(
            ObservationLog.analyze(t, truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180))
        )
        XCTAssertTrue(analysis.isCorrect)
        XCTAssertFalse(analysis.isFalseLock)
        // ~1e-6° adalah derau pembulatan acos di sekitar pemisahan nol.
        XCTAssertEqual(analysis.rawPointingErrorDeg, 0, accuracy: 1e-5)
    }

    /// Inti PRD: yakin tinggi tapi salah HARUS ditandai false lock.
    func testConfidentButWrongIsFlaggedAsFalseLock() throws {
        let t = trial(pointingAlt: 40, pointingAz: 180, bestID: "vega",
                      level: .high, truthID: "sirius")
        let analysis = try XCTUnwrap(
            ObservationLog.analyze(t, truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180))
        )
        XCTAssertFalse(analysis.isCorrect)
        XCTAssertTrue(analysis.isFalseLock, "HIGH + salah = false lock")
    }

    /// Ragu tapi salah BUKAN false lock — kejujuran tidak dihukum.
    func testUncertainWrongGuessIsNotAFalseLock() throws {
        let t = trial(pointingAlt: 40, pointingAz: 180, bestID: "vega",
                      level: .medium, truthID: "sirius")
        let analysis = try XCTUnwrap(
            ObservationLog.analyze(t, truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180))
        )
        XCTAssertFalse(analysis.isCorrect)
        XCTAssertFalse(analysis.isFalseLock,
                       "MEDIUM yang salah bukan kebohongan; engine sudah jujur ragu")
    }

    /// Galat tunjuk diukur dari arah MENTAH, bukan dari hasil engine.
    func testPointingErrorIsMeasuredFromRawDirection() throws {
        let t = trial(pointingAlt: 50, pointingAz: 180, bestID: "sirius",
                      level: .high, truthID: "sirius")
        // Kebenaran 10° di bawah arah tunjuk, azimuth sama.
        let analysis = try XCTUnwrap(
            ObservationLog.analyze(t, truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180))
        )
        XCTAssertEqual(analysis.rawPointingErrorDeg, 10.0, accuracy: 1e-6)
    }

    func testCalibratedErrorIsReportedWhenPresent() throws {
        let t = trial(pointingAlt: 50, pointingAz: 180, bestID: "sirius",
                      level: .high, truthID: "sirius",
                      calibrated: HorizontalCoord(altitudeDeg: 41, azimuthDeg: 180))
        let analysis = try XCTUnwrap(
            ObservationLog.analyze(t, truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180))
        )
        XCTAssertEqual(try XCTUnwrap(analysis.calibratedPointingErrorDeg), 1.0, accuracy: 1e-6)
    }

    /// Tanpa label kebenaran, analisis tidak boleh menebak.
    func testUnlabelledTrialYieldsNoAnalysis() {
        let t = trial(pointingAlt: 40, pointingAz: 180, bestID: "sirius",
                      level: .high, truthID: nil)
        XCTAssertNil(ObservationLog.analyze(t, truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180)))
        XCTAssertNil(ObservationLog.analyze(t, truthDirection: nil))
    }

    // MARK: - Statistik

    func testPercentileInterpolatesLinearly() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        XCTAssertEqual(ExperimentSummary.percentile(values, 0.5)!, 3.0, accuracy: 1e-9)
        XCTAssertEqual(ExperimentSummary.percentile(values, 0.0)!, 1.0, accuracy: 1e-9)
        XCTAssertEqual(ExperimentSummary.percentile(values, 1.0)!, 5.0, accuracy: 1e-9)
        // 0.9 pada 5 nilai -> posisi 3.6 -> antara 4.0 dan 5.0 -> 4.6
        XCTAssertEqual(ExperimentSummary.percentile(values, 0.9)!, 4.6, accuracy: 1e-9)
    }

    func testPercentileOfEmptyIsNil() {
        XCTAssertNil(ExperimentSummary.percentile([], 0.5))
    }

    func testSummaryCountsAccuracyAndFalseLocks() throws {
        let trials: [(Double, ConfidenceLevel, String?)] = [
            (40, .high, "sirius"),   // benar
            (40, .high, "sirius"),   // benar
            (40, .high, "vega"),     // salah + HIGH -> false lock
            (40, .medium, "vega"),   // salah tapi ragu -> aman
        ]
        let analyses = trials.compactMap { alt, level, truth in
            ObservationLog.analyze(
                trial(pointingAlt: alt, pointingAz: 180, bestID: "sirius", level: level, truthID: truth),
                truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180)
            )
        }
        XCTAssertEqual(analyses.count, 4)

        let summary = ObservationLog.summarize(analyses)
        XCTAssertEqual(summary.trialCount, 4)
        XCTAssertEqual(summary.correctCount, 2)
        XCTAssertEqual(summary.falseLockCount, 1)
        XCTAssertEqual(try XCTUnwrap(summary.accuracy), 0.5, accuracy: 1e-9)
        XCTAssertFalse(summary.passesSafetyCriterion,
                       "ada false lock -> Experiment 1 belum lulus")
    }

    func testSummaryOfCleanRunPassesSafetyCriterion() throws {
        let analyses = [
            ObservationLog.analyze(
                trial(pointingAlt: 40, pointingAz: 180, bestID: "sirius", level: .high, truthID: "sirius"),
                truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180)
            )!,
            ObservationLog.analyze(
                trial(pointingAlt: 40, pointingAz: 180, bestID: "vega", level: .medium, truthID: "sirius"),
                truthDirection: HorizontalCoord(altitudeDeg: 40, azimuthDeg: 180)
            )!,
        ]
        let summary = ObservationLog.summarize(analyses)
        XCTAssertEqual(summary.falseLockCount, 0)
        XCTAssertTrue(summary.passesSafetyCriterion)
    }

    func testEmptySummaryHasNoAccuracy() {
        let summary = ObservationLog.summarize([])
        XCTAssertEqual(summary.trialCount, 0)
        XCTAssertNil(summary.accuracy)
        XCTAssertNil(summary.medianRawPointingErrorDeg)
    }

    // MARK: - Arsip JSON

    func testArchiveRoundTripsThroughJSON() throws {
        let original = [
            trial(pointingAlt: 42.5, pointingAz: 181.25, bestID: "sirius",
                  level: .high, truthID: "sirius", note: "langit bersih"),
            trial(pointingAlt: 10, pointingAz: 90, bestID: "vega",
                  level: .low, truthID: "vega"),
        ]
        let data = try TrialArchive.encode(original)
        let restored = try TrialArchive.decode(data)
        XCTAssertEqual(restored, original)
    }
}
