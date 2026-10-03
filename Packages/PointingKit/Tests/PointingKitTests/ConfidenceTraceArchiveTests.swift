import XCTest
import CelestialEngine
@testable import PointingKit

/// Arsip riwayat keyakinan: yang diuji adalah apakah berkas hasil ekspor
/// **masih bisa ditafsirkan** tanpa kehilangan variabel keputusannya.
///
/// Ekspor yang membuang konteks (sigma, lokasi, kalibrasi) menghasilkan berkas
/// yang tampak sah tapi tidak bisa dianalisis — dan itu lebih buruk daripada
/// gagal ekspor, karena tidak ada yang tahu datanya sudah tidak berguna.
final class ConfidenceTraceArchiveTests: XCTestCase {

    private let location = ObserverLocation(latitudeDeg: -6.2,
                                            longitudeDeg: 106.8,
                                            label: "Jakarta (uji)",
                                            source: "manual")

    private func makeTrace() -> ConfidenceTrace {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "sirius", objectName: "Sirius",
                     separationDeg: 4, sigmaDeg: 10, nearestNeighbourDeg: 60, at: Date())
        trace.record(state: .uncertain, level: .medium, objectID: "vega", objectName: "Vega",
                     separationDeg: 25, sigmaDeg: 10, nearestNeighbourDeg: 80, at: Date())
        trace.record(state: .pointing, level: nil, objectID: nil, objectName: nil,
                     separationDeg: nil, sigmaDeg: 10, at: Date())
        return trace
    }

    private var calibration: PointingCalibration {
        PointingCalibration(yawOffsetDeg: 12.5, residualSpreadDeg: 2.4, sampleCount: 3)
    }

    // MARK: - Bolak-balik

    func testRoundTripPreservesDecisionVariables() throws {
        let export = ConfidenceTraceArchive.export(from: makeTrace(),
                                                   location: location,
                                                   calibration: calibration,
                                                   confidenceSigmaDeg: 10)
        let data = try ConfidenceTraceArchive.encode(export)
        let decoded = try ConfidenceTraceArchive.decode(data)

        XCTAssertEqual(decoded.samples.count, 3)
        // Variabel keputusan sesungguhnya harus selamat.
        XCTAssertEqual(decoded.samples[0].ratioToSigma, 0.4)
        XCTAssertEqual(decoded.samples[1].ratioToSigma, 2.5)
        XCTAssertEqual(decoded.samples[0].neighbourRatioToSigma, 6.0)
        // Konteks yang membuat angka itu bisa dibaca.
        XCTAssertEqual(decoded.confidenceSigmaDeg, 10)
        XCTAssertEqual(decoded.calibration.yawOffsetDeg, 12.5)
        XCTAssertEqual(decoded.calibration.residualSpreadDeg, 2.4)
        XCTAssertEqual(decoded.location?.label, "Jakarta (uji)")
        XCTAssertEqual(decoded.location?.source, "manual")
    }

    /// Waktu harus disimpan apa adanya — urutan sampel tidak boleh bertukar.
    func testRoundTripKeepsSubSecondTimestamps() throws {
        let trace = ConfidenceTrace()
        let early = Date(timeIntervalSince1970: 1_700_000_000.25)
        let late = Date(timeIntervalSince1970: 1_700_000_000.75)
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 1, sigmaDeg: 1, at: early)
        trace.record(state: .lock, level: .high, objectID: "b", objectName: "B",
                     separationDeg: 1, sigmaDeg: 1, at: late)

        let decoded = try ConfidenceTraceArchive.decode(
            ConfidenceTraceArchive.encode(
                ConfidenceTraceArchive.export(from: trace, location: location,
                                              calibration: .none, confidenceSigmaDeg: 1)))
        XCTAssertEqual(decoded.samples[0].timestamp, early)
        XCTAssertEqual(decoded.samples[1].timestamp, late)
    }

    /// Sigma nol tidak boleh menjadi rasio tak berhingga saat dibaca kembali.
    func testZeroSigmaStaysNilAcrossRoundTrip() throws {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 5, sigmaDeg: 0, at: Date())
        let decoded = try ConfidenceTraceArchive.decode(
            ConfidenceTraceArchive.encode(
                ConfidenceTraceArchive.export(from: trace, location: nil,
                                              calibration: .none, confidenceSigmaDeg: 0)))
        XCTAssertNil(decoded.samples[0].ratioToSigma)
    }

    // MARK: - Sampel dari jam

    /// Sampel dari jam tidak membawa jarak kandidat. Ekspor tidak boleh
    /// mengarangnya — yang tidak diukur tetap tidak diukur.
    func testWatchSamplesKeepTheirMissingSeparation() throws {
        let trace = ConfidenceTrace()
        trace.record(message: PointingLinkMessage(kind: .pointingState,
                                                  sentAt: Date(),
                                                  state: .lock,
                                                  objectID: "sirius",
                                                  objectName: "Sirius",
                                                  level: .high))
        let export = ConfidenceTraceArchive.export(from: trace, location: location,
                                                   calibration: calibration,
                                                   confidenceSigmaDeg: 10)
        let decoded = try ConfidenceTraceArchive.decode(ConfidenceTraceArchive.encode(export))

        XCTAssertEqual(decoded.watchSampleCount, 1)
        XCTAssertTrue(decoded.samples[0].fromWatch)
        XCTAssertNil(decoded.samples[0].separationDeg)
        XCTAssertNil(decoded.samples[0].ratioToSigma)
    }

    // MARK: - Ringkasan & nama berkas

    func testCountsDescribeTheTrace() {
        let export = ConfidenceTraceArchive.export(from: makeTrace(), location: location,
                                                   calibration: calibration,
                                                   confidenceSigmaDeg: 10)
        XCTAssertEqual(export.lockCount, 1)
        XCTAssertEqual(export.uncertainCount, 1)
        XCTAssertEqual(export.answeredCount, 2)
        XCTAssertEqual(export.watchSampleCount, 0)
    }

    /// Riwayat kosong tetap sah diekspor (berkas kosong yang jujur), bukan galat.
    func testEmptyTraceExportsValidArchive() throws {
        let export = ConfidenceTraceArchive.export(from: ConfidenceTrace(), location: nil,
                                                   calibration: .none, confidenceSigmaDeg: 10)
        let decoded = try ConfidenceTraceArchive.decode(ConfidenceTraceArchive.encode(export))
        XCTAssertTrue(decoded.samples.isEmpty)
        XCTAssertEqual(decoded.answeredCount, 0)
    }

    func testFilenameIsUTCStampedAndStable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
        let name = ConfidenceTraceArchive.suggestedFilename(for: date)
        XCTAssertEqual(name, "confidence-trace-20231114-221320Z.json")
        XCTAssertTrue(name.hasSuffix(".json"))
    }

    /// Berkas rusak harus gagal dibaca, bukan menghasilkan riwayat kosong yang
    /// tampak seperti hasil rekaman.
    func testCorruptArchiveThrows() {
        let garbage = Data("{\"samples\": \"bukan larik\"}".utf8)
        XCTAssertThrowsError(try ConfidenceTraceArchive.decode(garbage))
    }
}
