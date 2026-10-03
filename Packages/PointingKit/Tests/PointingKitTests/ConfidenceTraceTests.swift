import XCTest
import CelestialEngine
@testable import PointingKit

/// Riwayat keyakinan: yang diuji adalah apakah grafiknya **jujur**.
///
/// Kalau riwayat ini salah menyimpan variabel keputusan, grafik diagnostik akan
/// menunjuk perbaikan yang salah — dan seluruh gunanya hilang.
final class ConfidenceTraceTests: XCTestCase {

    // MARK: - Variabel keputusan

    /// Rasio terhadap sigma harus ikut disimpan: 5° berarti berbeda pada sigma
    /// 10° dan sigma 1°.
    func testRatioToSigmaIsTheDecisionVariable() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "sirius", objectName: "Sirius",
                     separationDeg: 5, sigmaDeg: 10, at: Date())
        trace.record(state: .uncertain, level: .medium, objectID: "vega", objectName: "Vega",
                     separationDeg: 5, sigmaDeg: 1, at: Date())

        XCTAssertEqual(trace.samples[0].ratioToSigma, 0.5)
        XCTAssertEqual(trace.samples[1].ratioToSigma, 5.0)
        // Jarak mentahnya sama, tapi keputusannya harus berbeda.
        XCTAssertNotEqual(trace.samples[0].ratioToSigma, trace.samples[1].ratioToSigma)
    }

    /// Sigma nol tidak boleh menghasilkan pembagian tak berhingga yang tampak
    /// seperti "sangat dekat".
    func testZeroSigmaDoesNotProduceFakeRatio() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "sirius", objectName: "Sirius",
                     separationDeg: 5, sigmaDeg: 0, at: Date())
        XCTAssertNil(trace.samples[0].ratioToSigma)
    }

    // MARK: - Kapasitas

    func testCapacityKeepsTheMostRecentSamples() {
        let trace = ConfidenceTrace(capacity: 3)
        for index in 0..<5 {
            trace.record(state: .lock, level: .high, objectID: "obj\(index)",
                         objectName: "Obj\(index)", separationDeg: 1, sigmaDeg: 1, at: Date())
        }
        XCTAssertEqual(trace.samples.count, 3)
        XCTAssertEqual(trace.samples.map(\.objectID), ["obj2", "obj3", "obj4"])
    }

    func testRecordingCanBePaused() {
        let trace = ConfidenceTrace()
        trace.isRecording = false
        trace.record(state: .lock, level: .high, objectID: "sirius", objectName: "Sirius",
                     separationDeg: 1, sigmaDeg: 1, at: Date())
        XCTAssertTrue(trace.samples.isEmpty)
    }

    // MARK: - Sebab keraguan

    /// Dua sebab keraguan punya perbaikan yang berbeda dan **tidak boleh**
    /// dicampur: "terlalu jauh" berarti perbaiki kalibrasi, "ambigu" berarti
    /// batas akurasi.
    func testUncertainReasonsAreDistinguished() {
        let trace = ConfidenceTrace()
        let policy = ConfidencePolicy(pointingSigmaDeg: 10) // maxSeparation 10°, ambiguity 20°

        // Jauh: 25° = 2.5σ.
        trace.record(state: .uncertain, level: .medium, objectID: "a", objectName: "A",
                     separationDeg: 25, sigmaDeg: 10, nearestNeighbourDeg: 60, at: Date())
        // Ambigu: dekat (5° = 0.5σ), tapi tetangga 10° = 1σ ≤ 2σ.
        trace.record(state: .uncertain, level: .medium, objectID: "b", objectName: "B",
                     separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 10, at: Date())

        XCTAssertEqual(trace.uncertainReason(for: trace.samples[0], policy: policy), .tooFar)
        XCTAssertEqual(trace.uncertainReason(for: trace.samples[1], policy: policy), .ambiguous)

        let counts = trace.uncertainReasonCounts(policy: policy)
        XCTAssertEqual(counts[.tooFar], 1)
        XCTAssertEqual(counts[.ambiguous], 1)
    }

    func testDiagnosisPointsAtCalibrationWhenEverythingIsTooFar() {
        let trace = ConfidenceTrace()
        trace.record(state: .uncertain, level: .medium, objectID: "a", objectName: "A",
                     separationDeg: 30, sigmaDeg: 10, nearestNeighbourDeg: 90, at: Date())
        XCTAssertTrue(trace.diagnosis(policy: ConfidencePolicy(pointingSigmaDeg: 10))
            .contains("kalibrasi"))
    }

    func testDiagnosisSaysNothingRecordedWhenEmpty() {
        XCTAssertTrue(ConfidenceTrace().diagnosis().contains("Belum ada sampel"))
    }

    // MARK: - Pesan dari jam

    /// Sampel dari jam tidak membawa jarak kandidat; itu harus tetap kosong,
    /// bukan diisi angka karangan.
    func testWatchMessageRecordsWithoutInventingSeparation() {
        let trace = ConfidenceTrace()
        let message = PointingLinkMessage(kind: .pointingState,
                                          sentAt: Date(),
                                          state: .lock,
                                          objectID: "sirius",
                                          objectName: "Sirius",
                                          level: .high)
        trace.record(message: message)

        XCTAssertEqual(trace.samples.count, 1)
        XCTAssertTrue(trace.samples[0].fromWatch)
        XCTAssertEqual(trace.samples[0].objectID, "sirius")
        XCTAssertNil(trace.samples[0].separationDeg)
        XCTAssertNil(trace.samples[0].ratioToSigma)
    }

    /// Pesan yang bukan keadaan pointing (mis. tanda terima) tidak boleh
    /// menghasilkan sampel.
    func testNonStateMessagesAreIgnored() {
        let trace = ConfidenceTrace()
        trace.record(message: PointingLinkMessage(kind: .acknowledgement))
        XCTAssertTrue(trace.samples.isEmpty)
    }

    func testCountsByStateAndLevel() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 1, sigmaDeg: 10, at: Date())
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 1, sigmaDeg: 10, at: Date())
        trace.record(state: .pointing, level: nil, objectID: nil, objectName: nil,
                     separationDeg: nil, sigmaDeg: 10, at: Date())

        XCTAssertEqual(trace.stateCounts[.lock], 2)
        XCTAssertEqual(trace.stateCounts[.pointing], 1)
        XCTAssertEqual(trace.levelCounts[.high], 2)
        XCTAssertEqual(trace.answered.count, 2)
    }

    func testResetClearsEverything() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 1, sigmaDeg: 10, at: Date())
        trace.reset()
        XCTAssertTrue(trace.samples.isEmpty)
    }
}
