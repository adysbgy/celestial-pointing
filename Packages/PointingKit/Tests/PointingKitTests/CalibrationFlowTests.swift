import XCTest
import CelestialEngine
@testable import PointingKit

/// Alur kalibrasi: mengumpulkan acuan, mengukur sebaran, menolak yang belum matang.
final class CalibrationFlowTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let resolver = PointingResolver(catalogue: Catalogue.brightStars,
                                            policy: .permissive)

    private func truth(_ id: String) -> HorizontalCoord {
        resolver.horizontal(ofObjectID: id, observer: observer, date: date)!
    }

    /// Arah tunjuk yang meleset dari kebenaran dengan offset yaw tertentu.
    private func measured(_ id: String, yawError: Double, altitudeBias: Double = 0) -> HorizontalCoord {
        let t = truth(id)
        return HorizontalCoord(altitudeDeg: t.altitudeDeg + altitudeBias,
                               azimuthDeg: SkyMath.normalizeDeg(t.azimuthDeg - yawError))
    }

    // MARK: - Dasar

    func testStartsEmptyAndNotReady() {
        let flow = CalibrationFlow()
        XCTAssertEqual(flow.phase, .idle)
        XCTAssertTrue(flow.samples.isEmpty)
        XCTAssertFalse(flow.isReady)
        XCTAssertNil(flow.applicableCalibration)
    }

    func testUnknownObjectIsNotStored() {
        var flow = CalibrationFlow()
        let result = flow.add(objectID: "tidak-ada",
                              measured: HorizontalCoord(altitudeDeg: 30, azimuthDeg: 90),
                              resolver: resolver, observer: observer, date: date)
        XCTAssertNil(result)
        XCTAssertTrue(flow.samples.isEmpty, "sampel yang tidak bisa diverifikasi tidak boleh disimpan")
    }

    /// Satu acuan belum cukup: tidak ada cara mengukur konsistensi.
    func testSingleSampleIsNotReady() {
        var flow = CalibrationFlow()
        let update = flow.add(objectID: "sirius",
                              measured: measured("sirius", yawError: 5),
                              resolver: resolver, observer: observer, date: date)
        XCTAssertEqual(update?.phase, .collecting)
        XCTAssertEqual(flow.samples.count, 1)
        XCTAssertFalse(flow.isReady)
        XCTAssertNil(flow.applicableCalibration,
                     "satu acuan tidak boleh dipasang — sebarannya belum terukur")
    }

    // MARK: - Kalibrasi yang baik

    func testConsistentSamplesBecomeReadyAndRecoverYaw() {
        var flow = CalibrationFlow()
        let yawError = 12.0
        for id in ["sirius", "vega", "arcturus"] {
            flow.add(objectID: id,
                     measured: measured(id, yawError: yawError),
                     resolver: resolver, observer: observer, date: date)
        }

        XCTAssertTrue(flow.isReady)
        let calibration = try! XCTUnwrap(flow.applicableCalibration)
        // Tanda: arah tunjuk meleset -yawError, jadi offset harus +yawError.
        XCTAssertEqual(calibration.yawOffsetDeg, yawError, accuracy: 0.5)
        XCTAssertLessThanOrEqual(calibration.residualSpreadDeg ?? 99, 3.0)
        XCTAssertEqual(calibration.sampleCount, 3)
    }

    /// Sebaran lebar harus **menahan** kalibrasi. Ini yang mencegah offset
    /// asal-asalan membalik jawaban engine tanpa terlihat.
    func testWideSpreadBlocksCalibration() {
        var flow = CalibrationFlow()
        flow.add(objectID: "sirius",
                 measured: measured("sirius", yawError: -30),
                 resolver: resolver, observer: observer, date: date)
        flow.add(objectID: "vega",
                 measured: measured("vega", yawError: 30),
                 resolver: resolver, observer: observer, date: date)

        XCTAssertEqual(flow.phase, .collecting)
        XCTAssertFalse(flow.isReady)
        XCTAssertNil(flow.applicableCalibration)
        XCTAssertTrue(flow.currentUpdate.message.contains("terlalu lebar"))
    }

    /// Bias altitude tidak boleh diserap kalibrasi — ia hanya mengoreksi yaw.
    func testAltitudeBiasIsReportedNotHidden() {
        var flow = CalibrationFlow()
        // Yaw konsisten, tapi semua titik meleset 20° ke atas: itu galat sensor
        // yang harus tetap terlihat di sebaran sisa.
        for id in ["sirius", "vega", "arcturus"] {
            flow.add(objectID: id,
                     measured: measured(id, yawError: 0, altitudeBias: 20),
                     resolver: resolver, observer: observer, date: date)
        }
        XCTAssertFalse(flow.isReady, "galat altitude 20° harus membuat sebaran besar")
        let spread = try! XCTUnwrap(flow.calibration?.residualSpreadDeg)
        XCTAssertGreaterThan(spread, 10)
    }

    // MARK: - Siklus hidup

    func testRemoveLastDropsSampleAndRecomputes() {
        var flow = CalibrationFlow()
        flow.add(objectID: "sirius", measured: measured("sirius", yawError: 8),
                 resolver: resolver, observer: observer, date: date)
        flow.add(objectID: "vega", measured: measured("vega", yawError: 8),
                 resolver: resolver, observer: observer, date: date)
        XCTAssertTrue(flow.isReady)

        flow.removeLast()
        XCTAssertEqual(flow.samples.count, 1)
        XCTAssertFalse(flow.isReady)
    }

    func testResetClearsEverything() {
        var flow = CalibrationFlow()
        flow.add(objectID: "sirius", measured: measured("sirius", yawError: 8),
                 resolver: resolver, observer: observer, date: date)
        flow.add(objectID: "vega", measured: measured("vega", yawError: 8),
                 resolver: resolver, observer: observer, date: date)
        flow.reset()
        XCTAssertEqual(flow.phase, .idle)
        XCTAssertTrue(flow.samples.isEmpty)
        XCTAssertNil(flow.calibration)
    }

    func testMarkAppliedOnlyWhenReady() {
        var flow = CalibrationFlow()
        flow.markApplied()
        XCTAssertEqual(flow.phase, .idle, "belum siap, tidak boleh ditandai dipakai")

        for id in ["sirius", "vega"] {
            flow.add(objectID: id, measured: measured(id, yawError: 6),
                     resolver: resolver, observer: observer, date: date)
        }
        flow.markApplied()
        XCTAssertEqual(flow.phase, .applied)
        XCTAssertTrue(flow.isReady)
    }

    // MARK: - Kebijakan keyakinan dari sebaran

    /// Sigma terukur harus mengalir ke `ConfidencePolicy` — ini jembatan antara
    /// Experiment 1 dan ambang engine.
    func testMeasuredSpreadDrivesConfidencePolicy() {
        var flow = CalibrationFlow()
        for id in ["sirius", "vega", "arcturus"] {
            flow.add(objectID: id, measured: measured(id, yawError: 4),
                     resolver: resolver, observer: observer, date: date)
        }
        let calibration = try! XCTUnwrap(flow.applicableCalibration)
        let policy = try! XCTUnwrap(calibration.confidencePolicy())
        XCTAssertEqual(policy.pointingSigmaDeg, try! XCTUnwrap(calibration.residualSpreadDeg),
                       accuracy: 1e-12)
        XCTAssertLessThan(policy.pointingSigmaDeg, 10.0,
                          "kalibrasi bagus harus membuat engine lebih berani dari bawaan konservatif")
        XCTAssertTrue(policy.isMeasured,
                      "sigma dari kalibrasi nyata adalah hasil ukur, bukan cadangan")
    }

    /// Kalibrasi tanpa sebaran terukur tidak boleh mengarang kebijakan.
    func testCalibrationWithoutSpreadYieldsNoPolicy() {
        let onePoint = PointingCalibration(yawOffsetDeg: 5, residualSpreadDeg: nil, sampleCount: 1)
        XCTAssertNil(onePoint.confidencePolicy())
    }

    // MARK: - Acuan bawaan

    /// Acuan bawaan harus ada di katalog dan tersebar, bukan menumpuk di satu
    /// bagian langit (dua acuan berdekatan memberi yaw yang sama-sama rapuh).
    func testDefaultReferencesAreSpreadAcrossSky() {
        let references = CalibrationFlow.defaultReferences
        XCTAssertGreaterThanOrEqual(references.count, 4)

        let directions = references.compactMap {
            resolver.horizontal(of: $0, observer: observer, date: date)
        }
        XCTAssertEqual(directions.count, references.count)

        var minimumSeparation = Double.greatestFiniteMagnitude
        for i in 0..<directions.count {
            for j in (i + 1)..<directions.count {
                minimumSeparation = min(minimumSeparation,
                                        SkyMath.angularSeparationHorizontalDeg(directions[i], directions[j]))
            }
        }
        XCTAssertGreaterThan(minimumSeparation, 20.0,
                             "acuan bawaan terlalu berdekatan untuk memberi yaw yang tahan galat")
    }
}
