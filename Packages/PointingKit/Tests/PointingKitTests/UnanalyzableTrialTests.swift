import XCTest
import CelestialEngine
@testable import PointingKit

/// Percobaan yang tidak bisa dianalisis harus **tampak**, bukan hilang.
///
/// **Premis.** `ExperimentHarness.record(...)` menolak menyimpan rekaman yang
/// arah kebenarannya tak bisa dihitung. Tapi `AnalyzedTrial.analysis` tetap
/// bertipe opsional, dan `ObservationLog.analyze` mengembalikan `nil` bila
/// `groundTruthObjectID` kosong — jadi rekaman tanpa analisis bisa masuk lewat
/// jalur lain, dan yang terjadi sama saja bagi pengguna: **percobaan yang
/// tercatat tapi tidak masuk hitungan**.
///
/// Yang rusak bukan cuma tampilannya. `summary` dibangun dari
/// `trials.compactMap(\.analysis)`, jadi `trialCount` — angka yang menentukan
/// `hasEnoughEvidenceForSafetyClaim`, dan dengan itu menentukan boleh-tidaknya
/// kalimat "lulus" diucapkan — menyusut sendiri tanpa jejak. Akibatnya lebih
/// buruk dari kosmetik: percobaan yang tak terbaca membuat penguji mengira
/// sampelnya bertambah, sehingga ambang 20 percobaan bisa terpenuhi dengan data
/// yang separuhnya tidak bisa dinilai.
///
/// Ini kelas "dihitung tapi tidak pernah tampil" yang sama seperti
/// `uncertainReasonCounts`: field ada, terisi, teruji — lalu tidak pernah
/// sampai ke layar.
final class UnanalyzableTrialTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let location = ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                                            label: "Bandung", source: "test",
                                            capturedAt: Date(timeIntervalSince1970: 1_700_000_000))
    private let truth = HorizontalCoord(altitudeDeg: 20, azimuthDeg: 10)

    // MARK: - Bangun rekaman

    /// Percobaan dengan analisis — jalur normal.
    private func analyzable(isCorrect: Bool, falseLock: Bool) -> AnalyzedTrial {
        AnalyzedTrial(
            trial: trial(groundTruth: "sirius"),
            analysis: TrialAnalysis(rawPointingErrorDeg: 4,
                                    calibratedPointingErrorDeg: nil,
                                    isCorrect: isCorrect,
                                    reportedLevel: falseLock ? .high : .medium,
                                    isFalseLock: falseLock),
            truthDirection: truth,
            stateAtCapture: .lock,
            angularRateAtCaptureDegPerSec: 1)
    }

    /// Percobaan yang tercatat tapi `analysis`-nya `nil` — label kebenaran
    /// belum terisi, jadi `ObservationLog.analyze` menolak menganalisisnya.
    private func unanalyzable() -> AnalyzedTrial {
        AnalyzedTrial(
            trial: trial(groundTruth: nil),
            analysis: nil,
            truthDirection: truth,
            stateAtCapture: .lock,
            angularRateAtCaptureDegPerSec: 1)
    }

    private func trial(groundTruth: String?) -> PointingTrial {
        PointingTrial(timestamp: date,
                      observer: observer,
                      rawPointing: HorizontalCoord(altitudeDeg: 18, azimuthDeg: 12),
                      calibratedPointing: nil,
                      intent: CelestialIntent(level: .medium, best: nil, candidates: []),
                      groundTruthObjectID: groundTruth)
    }

    private func dataset(_ trials: [AnalyzedTrial]) -> ExperimentDataset {
        ExperimentDataset(createdAt: date,
                          location: location,
                          calibration: PointingCalibration(yawOffsetDeg: 0, residualSpreadDeg: nil, sampleCount: 0),
                          confidenceSigmaDeg: 3,
                          aim: "sirius",
                          trials: trials)
    }

    // MARK: - Angka yang hilang

    /// Jumlah percobaan tak-teranalisis harus benar-benar dihitung, bukan
    /// selalu nol. `unanalyzableCount` sudah ada di dataset — ini mengunci
    /// bahwa ia menghitung dan bukan cuma field yang kebetulan selalu 0.
    func testUnanalyzableCountCountsTrialsWithoutAnalysis() {
        XCTAssertEqual(dataset([analyzable(isCorrect: true, falseLock: false)]).unanalyzableCount, 0)
        XCTAssertEqual(dataset([unanalyzable()]).unanalyzableCount, 1)
        XCTAssertEqual(dataset([analyzable(isCorrect: true, falseLock: false),
                                unanalyzable(),
                                unanalyzable()]).unanalyzableCount, 2)
    }

    /// Dataset juga harus tahu **berapa** yang teranalisis, supaya layar bisa
    /// menampilkan kedua angka tanpa menghitung ulang di view.
    func testDatasetReportsHowManyWereAnalyzedToo() {
        let d = dataset([analyzable(isCorrect: true, falseLock: false),
                         unanalyzable()])
        XCTAssertEqual(d.analyzedCount, 1)
        XCTAssertEqual(d.unanalyzableCount, 1)
    }

    /// Jumlah rekaman yang benar-benar ada — termasuk yang tak teranalisis.
    ///
    /// Tanpa ini, layar hanya bisa menampilkan `trialCount`, dan yang hilang
    /// justru informasi terpenting: ada rekaman yang tidak bisa dinilai.
    func testRecordedCountIncludesUnanalyzableTrials() {
        XCTAssertEqual(dataset([analyzable(isCorrect: true, falseLock: false),
                                unanalyzable()]).recordedCount, 2)
    }

    // MARK: - Penyusutan yang tidak jujur

    /// **Regresi inti.** `summary.trialCount` hanya menghitung yang teranalisis,
    /// sehingga "Percobaan" di layar lebih kecil dari jumlah rekaman yang ada.
    ///
    /// Bedanya bukan angka bulat — bedanya menentukan berapa bukti yang
    /// terkumpul dan seberapa jauh klaim "lulus" masih boleh diucapkan.
    func testSummaryTrialCountIsSmallerThanRecordedTrials() {
        let s = dataset([analyzable(isCorrect: true, falseLock: false),
                         unanalyzable()]).summary
        XCTAssertEqual(s.trialCount, 1, "summary hanya melihat yang teranalisis")
    }

    /// **Regresi yang paling mudah rusak.** Ambang "boleh lulus" ada di 20
    /// percobaan. Dengan 19 percobaan teranalisis ditambah beberapa yang
    /// tercatat tapi tak teranalisis, vonis **harus tetap belum cukup
    /// bukti**.
    ///
    /// Bentuk sebelumnya hanya membandingkan dua vonis satu sama lain, jadi
    /// ia hampir tidak bisa dibatalkan: mutasi apa pun yang membuat keduanya
    /// berubah bersama tetap hijau. Yang menguji sebenarnya di sini adalah
    /// nilai mutlak, dan itu yang bisa patah.
    ///
    /// Pelaku yang menyesatkan adalah "bikin `trialCount` menghitung
    /// semuanya supaya ambang 20 lebih cepat tercapai" — persis dustur yang
    /// dilarang PRD: menaikkan keyakinan tanpa bukti baru masuk.
    func testUnanalyzableTrialsDoNotPushTheSampleOverTheThreshold() {
        // 19 = satu di bawah ambang. Tiga tak teranalisis tidak boleh mendorongnya.
        let nineteen = (0..<19).map { _ in analyzable(isCorrect: true, falseLock: false) }
        let honest = dataset(nineteen).summary
        XCTAssertEqual(honest.trialCount, 19)
        XCTAssertEqual(honest.safetyVerdict, .insufficientEvidence,
                       "19 percobaan belum cukup bukti")

        let inflated = dataset(nineteen + [unanalyzable(), unanalyzable(),
                                           unanalyzable()]).summary
        XCTAssertEqual(inflated.trialCount, 19,
                       "percobaan tak teranalisis tidak boleh masuk hitungan")
        XCTAssertEqual(inflated.safetyVerdict, .insufficientEvidence,
                       "22 rekaman tapi hanya 19 teranalisis — klaim lulus belum boleh diucapkan")
    }

    /// Keberadaan percobaan tak-teranalisis harus **dinyatakan**, supaya layar
    /// bisa memperingatkan. Tanpa penanda, verdict "belum cukup bukti" muncul
    /// tanpa penjelasan dan pengguna akan mengira dia belum menekan tombol
    /// cukup kali — padahal ada rekaman yang masuk tapi tidak bisa dinilai.
    func testUnanalyzableTrialsAreFlagged() {
        XCTAssertFalse(dataset([analyzable(isCorrect: true, falseLock: false)]).hasUnanalyzableTrials)
        XCTAssertTrue(dataset([analyzable(isCorrect: true, falseLock: false),
                               unanalyzable()]).hasUnanalyzableTrials)
    }
}
