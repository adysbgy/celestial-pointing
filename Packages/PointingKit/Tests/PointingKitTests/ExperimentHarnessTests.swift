import XCTest
import CelestialEngine
@testable import PointingKit

/// Harness Experiment 1: merekam percobaan tanpa menyaring yang gagal,
/// menghitung galat, dan mengusulkan ambang keyakinan dari hasilnya.
final class ExperimentHarnessTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let resolver = PointingResolver(catalogue: Catalogue.brightStars,
                                            policy: .permissive)
    private let location = ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                                            label: "Bandung", source: "test",
                                            capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

    private func truth(_ id: String) -> HorizontalCoord {
        resolver.horizontal(ofObjectID: id, observer: observer, date: date)!
    }

    private func intent(level: ConfidenceLevel, object: CelestialObject) -> CelestialIntent {
        CelestialIntent(level: level, best: object, candidates: [])
    }

    private func star(_ id: String) -> CelestialObject {
        Catalogue.brightStars.first { $0.id == id }!
    }

    private func harness() -> ExperimentHarness {
        ExperimentHarness(resolver: resolver, location: location)
    }

    // MARK: - Perekaman

    /// Rekaman benar: galat tunjuk mentah harus terukur, bukan ditebak.
    func testRecordsMeasuredPointingError() {
        let h = harness()
        let target = star("sirius")
        let t = truth("sirius")
        // Meleset 6° ke bawah dari Sirius.
        let pointed = HorizontalCoord(altitudeDeg: t.altitudeDeg - 6, azimuthDeg: t.azimuthDeg)

        let recorded = try! XCTUnwrap(h.record(targetObjectID: "sirius",
                                               rawPointing: pointed,
                                               calibratedPointing: nil,
                                               intent: intent(level: .high, object: target),
                                               state: .lock,
                                               angularRateDegPerSec: 0.2,
                                               calibration: .none,
                                               timestamp: date))
        let analysis = try! XCTUnwrap(recorded.analysis)
        XCTAssertEqual(analysis.rawPointingErrorDeg, 6, accuracy: 0.05)
        XCTAssertTrue(analysis.isCorrect)
        XCTAssertFalse(analysis.isFalseLock)
        XCTAssertEqual(h.trials.count, 1)
    }

    /// Mode kegagalan paling berbahaya: yakin tinggi tapi salah.
    func testConfidentButWrongIsFlaggedAsFalseLock() {
        let h = harness()
        let t = truth("vega")
        h.record(targetObjectID: "vega",
                 rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg, azimuthDeg: t.azimuthDeg),
                 calibratedPointing: nil,
                 intent: intent(level: .high, object: star("sirius")),  // jawaban salah
                 state: .lock,
                 angularRateDegPerSec: 0.1,
                 calibration: .none,
                 timestamp: date)

        XCTAssertEqual(h.summary.falseLockCount, 1)
        XCTAssertFalse(h.summary.passesSafetyCriterion)
        XCTAssertTrue(h.verdict.contains("GAGAL"))
        XCTAssertEqual(h.dataset(calibration: .none, confidenceSigmaDeg: 10, aim: "view").falseLocks.count, 1)
    }

    /// Ragu bukan kebohongan: MEDIUM + salah bukan false lock.
    func testUncertainAndWrongIsNotAFalseLock() {
        let h = harness()
        let t = truth("vega")
        h.record(targetObjectID: "vega",
                 rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg, azimuthDeg: t.azimuthDeg),
                 calibratedPointing: nil,
                 intent: intent(level: .medium, object: star("sirius")),
                 state: .uncertain,
                 angularRateDegPerSec: 0.1,
                 calibration: .none,
                 timestamp: date)

        XCTAssertEqual(h.summary.falseLockCount, 0)
        XCTAssertTrue(h.summary.passesSafetyCriterion)
        XCTAssertFalse(h.verdict.contains("GAGAL"))
    }

    /// Target tak dikenal tidak menghasilkan rekaman — dataset tidak boleh
    /// diisi percobaan yang tak bisa diverifikasi.
    func testUnknownTargetIsNotRecorded() {
        let h = harness()
        let result = h.record(targetObjectID: "nebula-tidak-ada",
                              rawPointing: HorizontalCoord(altitudeDeg: 30, azimuthDeg: 90),
                              calibratedPointing: nil,
                              intent: intent(level: .high, object: star("sirius")),
                              state: .lock,
                              angularRateDegPerSec: nil,
                              calibration: .none,
                              timestamp: date)
        XCTAssertNil(result)
        XCTAssertTrue(h.trials.isEmpty)
    }

    /// Percobaan yang salah tetap disimpan. Membuangnya justru menghapus
    /// informasi paling berharga: seberapa sering engine gagal.
    func testWrongTrialsAreKeptNotFiltered() {
        let h = harness()
        let t = truth("vega")
        for _ in 0..<5 {
            h.record(targetObjectID: "vega",
                     rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg + 40,
                                                  azimuthDeg: t.azimuthDeg),
                     calibratedPointing: nil,
                     intent: intent(level: .low, object: star("sirius")),
                     state: .uncertain,
                     angularRateDegPerSec: 1.0,
                     calibration: .none,
                     timestamp: date)
        }
        XCTAssertEqual(h.trials.count, 5)
        XCTAssertEqual(h.summary.trialCount, 5)
        XCTAssertEqual(h.summary.correctCount, 0)
    }

    // MARK: - Statistik

    func testSummaryStatisticsAreCorrect() {
        let h = harness()
        // Galat: 1°, 2°, 3°, 4° (median 2.5, P90 3.7)
        for (index, error) in [1.0, 2.0, 3.0, 4.0].enumerated() {
            let id = ["sirius", "vega", "arcturus", "capella"][index]
            let t = truth(id)
            h.record(targetObjectID: id,
                     rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg - error,
                                                  azimuthDeg: t.azimuthDeg),
                     calibratedPointing: nil,
                     intent: intent(level: .high, object: star(id)),
                     state: .lock,
                     angularRateDegPerSec: 0.1,
                     calibration: .none,
                     timestamp: date)
        }
        let summary = h.summary
        XCTAssertEqual(summary.trialCount, 4)
        XCTAssertEqual(summary.correctCount, 4)
        XCTAssertEqual(summary.accuracy!, 1.0, accuracy: 1e-12)
        XCTAssertEqual(summary.medianRawPointingErrorDeg!, 2.5, accuracy: 0.05)
        XCTAssertEqual(summary.p90RawPointingErrorDeg!, 3.7, accuracy: 0.05)
    }

    /// Rekaman pada keadaan tanpa jawaban tidak boleh dicatat sebagai false
    /// lock, walau `intent` sisa masih berlevel HIGH.
    ///
    /// Ini yang membuat `stateAtCapture` berguna: tanpa memakainya, harness
    /// bisa melaporkan false lock untuk rekaman yang engine-nya tidak pernah
    /// menampilkan jawaban — dan angka itu yang menentukan lulus/gagal
    /// Experiment 1.
    func testRecordWithoutDisplayedAnswerIsNotAFalseLock() {
        let h = harness()
        let t = truth("vega")
        let recorded = h.record(targetObjectID: "vega",
                                rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg,
                                                             azimuthDeg: t.azimuthDeg),
                                calibratedPointing: nil,
                                // Intent sisa dari arah sebelumnya.
                                intent: intent(level: .high, object: star("sirius")),
                                state: .pointing,
                                angularRateDegPerSec: 12.0,
                                calibration: .none,
                                timestamp: date)
        let analysis = try! XCTUnwrap(recorded?.analysis)
        XCTAssertFalse(analysis.isCorrect)
        XCTAssertFalse(analysis.isFalseLock,
                       "engine tidak menampilkan jawaban -> tidak ada klaim yang bisa salah")
        XCTAssertEqual(h.summary.falseLockCount, 0)
        XCTAssertTrue(h.summary.passesSafetyCriterion)
        // Percobaannya tetap disimpan — yang dihindari adalah tuduhan palsu,
        // bukan menghapus rekaman.
        XCTAssertEqual(h.trials.count, 1)
        XCTAssertEqual(recorded?.stateAtCapture, .pointing)
    }

    /// Rekaman saat benar-benar terkunci tetap dihitung apa adanya.
    func testRecordWithDisplayedAnswerStillFlagsFalseLock() {
        let h = harness()
        let t = truth("vega")
        h.record(targetObjectID: "vega",
                 rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg, azimuthDeg: t.azimuthDeg),
                 calibratedPointing: nil,
                 intent: intent(level: .high, object: star("sirius")),
                 state: .lock,
                 angularRateDegPerSec: 0.1,
                 calibration: .none,
                 timestamp: date)
        XCTAssertEqual(h.summary.falseLockCount, 1)
    }

    // MARK: - Kebijakan keyakinan dari hasil

    /// Tanpa false lock, sigma terukur dari kalibrasi yang dipakai.
    func testPolicyUsesMeasuredSigmaWhenSafe() {
        let h = harness()
        let t = truth("sirius")
        h.record(targetObjectID: "sirius",
                 rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg, azimuthDeg: t.azimuthDeg),
                 calibratedPointing: nil,
                 intent: intent(level: .high, object: star("sirius")),
                 state: .lock,
                 angularRateDegPerSec: 0.1,
                 calibration: .none,
                 timestamp: date)

        let calibration = PointingCalibration(yawOffsetDeg: 3, residualSpreadDeg: 2.5, sampleCount: 4)
        let policy = try! XCTUnwrap(h.suggestedConfidencePolicy(calibration: calibration))
        XCTAssertEqual(policy.pointingSigmaDeg, 2.5, accuracy: 1e-12)
    }

    /// Ada false lock → ambang **diperketat**, bukan dilonggarkan. Ini arah yang
    /// benar menurut PRD: uncertainty > false confidence.
    func testFalseLockTightensPolicy() {
        let h = harness()
        let t = truth("vega")
        h.record(targetObjectID: "vega",
                 rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg, azimuthDeg: t.azimuthDeg),
                 calibratedPointing: nil,
                 intent: intent(level: .high, object: star("sirius")),
                 state: .lock,
                 angularRateDegPerSec: 0.1,
                 calibration: .none,
                 timestamp: date)

        // Kalibrasi bagus (sigma 2°) — tapi ada false lock, jadi jangan percaya.
        let calibration = PointingCalibration(yawOffsetDeg: 3, residualSpreadDeg: 2.0, sampleCount: 4)
        let policy = try! XCTUnwrap(h.suggestedConfidencePolicy(calibration: calibration))
        XCTAssertLessThan(policy.pointingSigmaDeg, 2.0,
                          "false lock harus memperketat ambang, bukan memakai sigma terukur apa adanya")
    }

    /// Belum ada percobaan → jangan mengarang kebijakan.
    func testNoTrialsYieldsNoPolicy() {
        let h = harness()
        XCTAssertNil(h.suggestedConfidencePolicy(calibration: .none))
    }

    func testRemoveLastAndReset() {
        let h = harness()
        let t = truth("sirius")
        h.record(targetObjectID: "sirius",
                 rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg, azimuthDeg: t.azimuthDeg),
                 calibratedPointing: nil,
                 intent: intent(level: .high, object: star("sirius")),
                 state: .lock, angularRateDegPerSec: 0.1, calibration: .none, timestamp: date)
        XCTAssertEqual(h.trials.count, 1)
        XCTAssertNotNil(h.removeLast())
        XCTAssertTrue(h.trials.isEmpty)

        h.record(targetObjectID: "sirius",
                 rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg, azimuthDeg: t.azimuthDeg),
                 calibratedPointing: nil,
                 intent: intent(level: .high, object: star("sirius")),
                 state: .lock, angularRateDegPerSec: 0.1, calibration: .none, timestamp: date)
        h.reset()
        XCTAssertTrue(h.trials.isEmpty)
    }

    // MARK: - Arsip

    func testDatasetRoundTripsThroughJSON() throws {
        let h = harness()
        let t = truth("sirius")
        h.record(targetObjectID: "sirius",
                 rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg - 3, azimuthDeg: t.azimuthDeg),
                 calibratedPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg - 1, azimuthDeg: t.azimuthDeg),
                 intent: intent(level: .high, object: star("sirius")),
                 state: .lock,
                 angularRateDegPerSec: 0.15,
                 calibration: PointingCalibration(yawOffsetDeg: 2, residualSpreadDeg: 1.5, sampleCount: 3),
                 timestamp: date,
                 note: "langit cerah")

        let dataset = h.dataset(calibration: PointingCalibration(yawOffsetDeg: 2, residualSpreadDeg: 1.5, sampleCount: 3),
                                confidenceSigmaDeg: 1.5,
                                aim: "view",
                                createdAt: date)
        let data = try DatasetArchive.encode(dataset)
        let decoded = try DatasetArchive.decode(data)

        XCTAssertEqual(decoded, dataset)
        XCTAssertEqual(decoded.trials.count, 1)
        XCTAssertEqual(decoded.trials[0].trial.note, "langit cerah")
        XCTAssertEqual(decoded.location.label, "Bandung")
        XCTAssertEqual(decoded.summary.trialCount, 1)
        XCTAssertEqual(decoded.trials[0].angularRateAtCaptureDegPerSec, 0.15)
    }

    /// Arsip harus menyimpan pecahan detik. Kalau tidak, dua percobaan dalam
    /// detik yang sama bertukar urutan dan waktu yang hilang tidak terlihat.
    func testArchiveKeepsSubSecondTimestamps() throws {
        let precise = Date(timeIntervalSince1970: 1_700_000_000.4567)
        let dataset = ExperimentDataset(createdAt: precise,
                                        location: location,
                                        calibration: .none,
                                        confidenceSigmaDeg: 10,
                                        aim: "view",
                                        trials: [])
        let decoded = try DatasetArchive.decode(try DatasetArchive.encode(dataset))
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970,
                       precise.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    func testSuggestedFilenameIsStableAndSortable() {
        let name = DatasetArchive.suggestedFilename(for: date)
        XCTAssertTrue(name.hasPrefix("experiment1-"))
        XCTAssertTrue(name.hasSuffix("Z.json"))
    }

    // MARK: - Target yang tersedia

    /// Target tanpa arah yang bisa dihitung tidak boleh ditawarkan: percobaan
    /// seperti itu tidak bisa dianalisis.
    func testAvailableTargetsAreAllComputableAndAboveHorizon() {
        let h = harness()
        let targets = h.availableTargets
        XCTAssertFalse(targets.isEmpty)
        for target in targets {
            XCTAssertGreaterThan(target.direction.altitudeDeg, 0, "\(target.id) di bawah horizon")
            XCTAssertNotEqual(target.id, "sun")
        }
    }

    // MARK: - Biaya daftar target

    /// Daftar target **tidak boleh dihitung ulang setiap kali dibaca**.
    ///
    /// Layar Experiment 1 membaca `availableTargets` di dalam `body`, dan
    /// `body` dievaluasi pada setiap sampel sensor — 20 kali per detik.
    /// Perhitungan ini menyapu seluruh katalog dan efemeris tata surya, jadi
    /// tanpa cache ia berjalan 20 kali per detik sepanjang pengukuran
    /// berlangsung: baterai habis dan layar tersendat, sementara daftar yang
    /// dihitung ulang terlihat persis sama dengan yang di-cache.
    func testTargetListIsNotRecomputedOnEveryRead() {
        let h = harness()
        let before = h.targetComputationCount
        for _ in 0..<50 { _ = h.availableTargets }
        XCTAssertEqual(h.targetComputationCount, before + 1,
                       "50 pembacaan berturut-turut harus memakai satu perhitungan")
    }

    /// Berpindah tempat **wajib** membatalkan cache: daftar tempat lama tidak
    /// berlaku di langit tempat baru.
    func testTargetListIsRecomputedAfterMoving() {
        let h = harness()
        _ = h.availableTargets
        let before = h.targetComputationCount

        h.location = ObserverLocation(latitudeDeg: -0.18, longitudeDeg: -78.47,
                                      label: "Quito", source: "test",
                                      capturedAt: date)

        _ = h.availableTargets
        XCTAssertEqual(h.targetComputationCount, before + 1,
                       "langit tempat baru belum pernah dihitung")
    }

    /// Memasang lokasi yang sama bukan perpindahan: cache tetap berlaku.
    func testTargetListIsNotRecomputedForSamePlace() {
        let h = harness()
        _ = h.availableTargets
        let before = h.targetComputationCount

        h.location = ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                                      label: "Bandung lagi", source: "test",
                                      capturedAt: Date(timeIntervalSince1970: 1_700_000_999))

        _ = h.availableTargets
        XCTAssertEqual(h.targetComputationCount, before, "tempatnya sama")
    }
}
