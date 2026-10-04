import XCTest
import CelestialEngine
@testable import PointingKit

/// Putusan keselamatan Experiment 1: gagal dan lulus tidak simetris.
///
/// Gagal butuh satu contoh tandingan; lulus butuh sampel yang cukup besar.
/// Uji-uji ini mengunci perbedaan itu supaya "belum ada bukti sebaliknya"
/// tidak pernah lagi dicetak sebagai "lulus".
final class ExperimentSafetyVerdictTests: XCTestCase {

    private func summary(trials: Int, falseLocks: Int) -> ExperimentSummary {
        // Susun analisis langsung: yang diuji di sini adalah **putusan atas
        // ringkasan**, bukan jalur rekaman (itu sudah diuji terpisah).
        let analyses = (0..<trials).map { index in
            TrialAnalysis(rawPointingErrorDeg: 5,
                          calibratedPointingErrorDeg: nil,
                          isCorrect: index >= falseLocks,
                          reportedLevel: .high,
                          isFalseLock: index < falseLocks)
        }
        return ObservationLog.summarize(analyses)
    }

    // MARK: - Gagal: satu saksi sudah cukup

    /// Satu false lock menggagalkan klaim, sekecil apa pun sampelnya.
    func testSingleFalseLockFailsEvenWithTinySample() {
        let s = summary(trials: 1, falseLocks: 1)
        XCTAssertEqual(s.safetyVerdict, .failed)
        XCTAssertFalse(s.passesSafetyCriterion)
    }

    /// Satu false lock tetap menggagalkan meski sampel sudah besar.
    func testFalseLockFailsEvenWithLargeSample() {
        let s = summary(trials: 200, falseLocks: 1)
        XCTAssertEqual(s.safetyVerdict, .failed)
    }

    // MARK: - Belum bisa disimpulkan: sampel terlalu kecil

    /// Inti perbaikan: nol false lock dari **satu** percobaan bukan "lulus".
    func testZeroFalseLocksFromOneTrialIsNotAPass() {
        let s = summary(trials: 1, falseLocks: 0)
        // `passesSafetyCriterion` tetap `true` — ia hanya menjawab "ada false
        // lock?", dan itu jawaban yang benar. Yang berubah: `safetyVerdict`
        // menolak membacanya sebagai klaim lulus.
        XCTAssertTrue(s.passesSafetyCriterion)
        XCTAssertEqual(s.safetyVerdict, .insufficientEvidence)
        XCTAssertFalse(s.safetyVerdict.isPassedClaim)
    }

    /// Satu di bawah ambang masih belum cukup; tepat di ambang sudah.
    func testThresholdIsExact() {
        let below = summary(trials: ExperimentSummary.minimumTrialsForSafetyClaim - 1,
                            falseLocks: 0)
        let at = summary(trials: ExperimentSummary.minimumTrialsForSafetyClaim,
                         falseLocks: 0)
        XCTAssertEqual(below.safetyVerdict, .insufficientEvidence)
        XCTAssertEqual(at.safetyVerdict, .passed)
    }

    // MARK: - Nada visual

    /// Keraguan tidak boleh tampil sebagai sukses.
    func testTonesDistinguishRevertFromEvidence() {
        XCTAssertEqual(ExperimentSummary.SafetyVerdict.failed.tone, .danger)
        XCTAssertEqual(ExperimentSummary.SafetyVerdict.insufficientEvidence.tone, .warning)
        XCTAssertEqual(ExperimentSummary.SafetyVerdict.passed.tone, .success)
    }

    /// `tone` tidak boleh sekadar menyalin `passesSafetyCriterion`: kalau ia
    /// menyalinnya, keadaan "belum cukup bukti" akan ikut hijau — persis cacat
    /// yang diperbaiki.
    func testInsufficientEvidenceIsNotGreen() {
        let s = summary(trials: 3, falseLocks: 0)
        XCTAssertTrue(s.passesSafetyCriterion)
        XCTAssertNotEqual(s.safetyVerdict.tone, .success)
        XCTAssertEqual(s.safetyVerdict.tone, .warning)
    }

    // MARK: - Kalimat

    /// Kalimat untuk sampel kecil tidak boleh memuat kata "Lulus".
    func testVerdictTextAvoidsTheWordPassedWhenEvidenceIsThin() {
        let h = ExperimentHarness(resolver: PointingResolver(catalogue: Catalogue.brightStars,
                                                             policy: .permissive),
                                  location: ObserverLocation(latitudeDeg: -6.2,
                                                             longitudeDeg: 106.8,
                                                             label: "Bandung",
                                                             source: "test",
                                                             capturedAt: Date(timeIntervalSince1970: 1_700_000_000)))
        let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let truth = h.resolver.horizontal(ofObjectID: "sirius",
                                          observer: observer, date: date)!

        h.record(targetObjectID: "sirius",
                 rawPointing: truth,
                 calibratedPointing: nil,
                 intent: CelestialIntent(level: .high,
                                         best: Catalogue.brightStars.first { $0.id == "sirius" }!,
                                         candidates: []),
                 state: .lock,
                 angularRateDegPerSec: nil,
                 calibration: .none,
                 timestamp: date)

        XCTAssertEqual(h.trials.count, 1)
        XCTAssertFalse(h.verdict.contains("Lulus"),
                       "satu percobaan bersih tidak boleh dicetak sebagai lulus")
        XCTAssertTrue(h.verdict.contains("Belum bisa disimpulkan"))
    }
}
