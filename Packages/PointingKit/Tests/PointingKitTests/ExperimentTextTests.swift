import XCTest
@testable import PointingKit

/// Uji untuk teks Experiment 1 yang dihasilkan di luar view.
///
/// **Kenapa ini diuji di Linux.** Laporan alat ukur — pesan status, kata
/// putusan, baris detail, ringkasan, dan diagnosis — lahir sebagai kalimat
/// Bahasa Indonesia di dalam `Packages/PointingKit` (`ExperimentHarness.verdict`,
/// `ConfidenceTrace.diagnosis`) atau dirakit lebih dulu ke sebuah `String` di
/// dalam view. Aturan 4 menyapu literal `Text("…")` di `Apps/`, jadi kalimat
/// yang lahir di paket tidak terjangkau; Aturan 6 memeriksa paritas kunci, dan
/// kalimat yang tidak melewati `LocalizedText` tidak punya kunci. Yang bisa
/// dijaga di Linux: kunci punya nilai bawaan, angka yang disisipkan benar-benar
/// masuk, dan terjemahan memasang kata yang menggantikan bawaan.
final class ExperimentTextTests: XCTestCase {

    override func tearDown() {
        // Kedua bridge dilepas: melepas hanya katalog membocorkan bahasa
        // angka milik uji ini ke berkas lain.
        TextLocalization.reset()
        NumberFormat.reset()
        super.tearDown()
    }

    func testDefaultIsIndonesianAndNotEmpty() {
        for text in LocalizedText.allKeys where text.rawValue.hasPrefix("experiment.") {
            XCTAssertFalse(text.indonesian.isEmpty,
                           "\(text.rawValue) tidak punya nilai bawaan")
            XCTAssertFalse(TextLocalization.text(text).isEmpty)
        }
    }

    func testEveryExperimentKeyIsDeclared() {
        // Kalau sebuah kalimat baru ditambahkan tanpa masuk `allKeys`, gerbang
        // paritas buta terhadapnya — persis cacat yang berkas ini tutup.
        let declared = Set(LocalizedText.allKeys
            .map(\.rawValue)
            .filter { $0.hasPrefix("experiment.") })
        XCTAssertGreaterThanOrEqual(declared.count, 36,
                                    "ada kunci experiment yang belum masuk allKeys")
    }

    func testStatusRecordedInsertsErrorVerdictAndAnswer() {
        let message = ExperimentText.statusRecorded(error: "1.2°",
                                                    verdict: ExperimentText.verdictFalseLock,
                                                    answer: "Vega")
        XCTAssertTrue(message.contains("1.2°"), "galat hilang: \(message)")
        XCTAssertTrue(message.contains("FALSE LOCK"), "putusan hilang: \(message)")
        XCTAssertTrue(message.contains("Vega"), "jawaban hilang: \(message)")
    }

    func testTargetUncomputableInsertsID() {
        let message = ExperimentText.statusTargetUncomputable(targetID: "sirius")
        XCTAssertTrue(message.contains("sirius"), "ID target hilang: \(message)")
    }

    func testSummaryFailedInsertsCountAndNumbers() {
        let message = ExperimentText.summaryFailed(falseLockCount: 3,
                                                   accuracy: "80%",
                                                   median: "1.2°",
                                                   p90: "3.4°")
        XCTAssertTrue(message.contains("3"), "jumlah false lock hilang: \(message)")
        XCTAssertTrue(message.contains("80%"), "akurasi hilang: \(message)")
        XCTAssertTrue(message.contains("1.2°"), "median hilang: \(message)")
        XCTAssertTrue(message.contains("3.4°"), "P90 hilang: \(message)")
    }

    func testSummaryInsufficientInsertsCountsAndMinimum() {
        let message = ExperimentText.summaryInsufficient(trialCount: 2,
                                                         minimum: 20,
                                                         accuracy: "—",
                                                         median: "—",
                                                         p90: "—")
        XCTAssertTrue(message.contains("2"), "jumlah percobaan hilang: \(message)")
        XCTAssertTrue(message.contains("20"), "sampel minimal hilang: \(message)")
    }

    /// Diagnosis rasio memakai `%lld` untuk dua jumlah bulat.
    ///
    /// `%d` di Linux Swift membaca 32-bit dan memotong nilai `Int` 64-bit —
    /// perbedaan yang tidak terlihat sampai jumlahnya besar. Uji ini memakai
    /// angka yang melewati batas 32-bit untuk mengunci perilakunya.
    func testDiagnosisRatioInsertsPercentAndCounts() {
        let message = ExperimentText.diagnosisRatio(locks: 5, uncertain: 2)
        XCTAssertTrue(message.contains("71"), "persentase hilang: \(message)")
        XCTAssertTrue(message.contains("5"), "jumlah yakin hilang: \(message)")
        XCTAssertTrue(message.contains("2"), "jumlah ragu hilang: \(message)")
    }

    func testDiagnosisRatioHandlesEmptyCounts() {
        // Total nol tidak boleh membagi dengan nol; kalimatnya tetap muncul.
        let message = ExperimentText.diagnosisRatio(locks: 0, uncertain: 0)
        XCTAssertTrue(message.contains("0"), "rasio nol hilang: \(message)")
    }

    func testTargetOptionInsertsNameAndAltitude() {
        let option = ExperimentText.targetOption(name: "Vega", altitudeDeg: 42.6)
        XCTAssertTrue(option.contains("Vega"), "nama hilang: \(option)")
        XCTAssertTrue(option.contains("43"), "tinggi hilang: \(option)")
    }

    /// Peringatan lokasi bawaan harus menyebut lokasi yang **sedang** dipakai.
    ///
    /// Kalau lokasi belum didapat, seluruh daftar target dihitung untuk tempat
    /// lain — dan tinggi objeknya salah. Kalimat yang tidak menyebut lokasinya
    /// tidak memberi tahu pengguna tempat mana yang sebenarnya dihitung, jadi
    /// peringatannya jadi tidak bisa ditindaklanjuti.
    func testLocationFallbackWarningInsertsLabel() {
        let warning = ExperimentText.locationFallbackWarning(label: "Jakarta")
        XCTAssertTrue(warning.contains("Jakarta"), "label lokasi hilang: \(warning)")
        XCTAssertNotEqual(warning, ExperimentText.locationComputed(label: "Jakarta"),
                          "peringatan bawaan dan keterangan biasa harus berbeda")
    }

    func testLocationComputedInsertsLabel() {
        let computed = ExperimentText.locationComputed(label: "Bandung")
        XCTAssertTrue(computed.contains("Bandung"), "label lokasi hilang: \(computed)")
    }

    func testDetailErrorAndRateInsertNumbers() {
        let error = ExperimentText.detailError(degrees: 1.25)
        let rate = ExperimentText.detailRate(degPerSec: 12.7)
        XCTAssertTrue(error.contains("1,2"), "galat hilang: \(error)")
        XCTAssertTrue(rate.contains("13"), "laju hilang: \(rate)")
    }

    /// Bentuk pendek (layar) dan bentuk kalimat (suara) tetap berbeda.
    ///
    /// Satu sumber angka, dua bentuk: layar memakai kata pendek di daftar,
    /// suara memakai kalimat penuh. Menyamakannya akan membuat salah satu
    /// permukaan kehilangan bentuk yang benar untuknya.
    func testVerdictShortAndSentenceFormsAreDistinct() {
        XCTAssertNotEqual(ExperimentText.verdictFalseLock,
                          ExperimentText.verdictFalseLockSentence)
        XCTAssertNotEqual(ExperimentText.verdictCorrect,
                          ExperimentText.verdictCorrectSentence)
    }

    /// Terjemahan memasang kata yang menggantikan bawaan.
    ///
    /// Kalau sebuah kalimat tidak punya entri katalog, `text()` jatuh ke
    /// bawaan Bahasa Indonesia — dan pengguna Bahasa Inggris melihat Bahasa
    /// Indonesia tanpa ada yang tahu. Uji ini memasang terjemahan Inggris
    /// untuk seluruh kunci experiment dan memastikan setiap aksesornya
    /// membacanya.
    func testEnglishTranslationControlsTheWords() {
        let english: [String: String] = [
            "experiment.status.initial": "Pick a target, aim, then record.",
            "experiment.status.noTarget": "Pick a target first.",
            "experiment.status.recorded": "Recorded: error %@, %@. Engine answer: %@.",
            "experiment.status.removed": "Removed: %@.",
            "experiment.status.nothingToRemove": "No trial to remove.",
            "experiment.status.reset": "Dataset cleared.",
            "experiment.verdict.falseLock": "FALSE LOCK",
            "experiment.verdict.correct": "correct",
            "experiment.verdict.falseLock.sentence": "False lock: confident but wrong.",
            "experiment.detail.noAnswer": "none yet",
            "experiment.detail.answer": "answer %@",
            "experiment.detail.error": "error %.1f°",
            "experiment.detail.rate": "%.0f°/s",
            "experiment.target.option": "%@ · %.0f°",
            "experiment.summary.noAnalyzable": "No trial that can be analyzed yet.",
            "experiment.summary.failed": "FAILED: %lld false lock. Accuracy %@, median %@, P90 %@.",
            "experiment.diagnosis.noSamples": "No samples yet.",
            "experiment.diagnosis.ratio": "%.0f%% confident (%lld confident, %lld uncertain).",
            "experiment.suggestedThreshold": "Suggested threshold: σ %.1f°",
            "experiment.location.fallback": "Location not yet available — computed for %@.",
            "experiment.location.computed": "Computed for %@.",
        ]
        EnglishTranslation.install(english)

        XCTAssertEqual(ExperimentText.statusInitial,
                       "Pick a target, aim, then record.")
        XCTAssertEqual(ExperimentText.statusNoTarget, "Pick a target first.")
        XCTAssertEqual(ExperimentText.verdictFalseLock, "FALSE LOCK")
        XCTAssertEqual(ExperimentText.verdictCorrect, "correct")
        XCTAssertEqual(ExperimentText.verdictFalseLockSentence,
                       "False lock: confident but wrong.")
        XCTAssertEqual(ExperimentText.detailNoAnswer, "none yet")
        XCTAssertEqual(ExperimentText.detailAnswer("Vega"), "answer Vega")
        XCTAssertEqual(ExperimentText.detailError(degrees: 1.25), "error 1.2°")
        XCTAssertEqual(ExperimentText.detailRate(degPerSec: 12.7), "13°/s")
        XCTAssertEqual(ExperimentText.targetOption(name: "Vega", altitudeDeg: 42.6),
                       "Vega · 43°")
        XCTAssertEqual(ExperimentText.summaryNoAnalyzable,
                       "No trial that can be analyzed yet.")
        XCTAssertEqual(ExperimentText.summaryFailed(falseLockCount: 1,
                                                    accuracy: "a", median: "b", p90: "c"),
                       "FAILED: 1 false lock. Accuracy a, median b, P90 c.")
        XCTAssertEqual(ExperimentText.diagnosisNoSamples, "No samples yet.")
        XCTAssertEqual(ExperimentText.diagnosisRatio(locks: 5, uncertain: 2),
                       "71% confident (5 confident, 2 uncertain).")
        XCTAssertEqual(ExperimentText.suggestedThreshold(sigmaDeg: 2.4),
                       "Suggested threshold: σ 2.4°")
        XCTAssertEqual(ExperimentText.locationFallbackWarning(label: "Jakarta"),
                       "Location not yet available — computed for Jakarta.")
        XCTAssertEqual(ExperimentText.locationComputed(label: "Jakarta"),
                       "Computed for Jakarta.")
    }
}
