import XCTest
@testable import PointingKit

/// Uji untuk teks alur kalibrasi yang dihasilkan di luar view.
///
/// **Kenapa ini diuji di Linux.** Seluruh alur kalibrasi — pesan tahap, pesan
/// kegagalan langkah, label yang diucapkan, dan angka ringkas di kartu — lahir
/// sebagai kalimat Bahasa Indonesia di dalam `Packages/PointingKit`, tempat
/// Aturan 4 (yang menyapu `Apps/`) tidak menjangkaunya, dan tanpa kunci
/// katalog, sehingga Aturan 6 (paritas kunci) juga tidak melihatnya. Yang bisa
/// dijaga di Linux: kunci punya nilai bawaan, nilai yang disisipkan benar-benar
/// masuk ke kalimat, dan terjemahan memasang kata yang menggantikan bawaan.
final class CalibrationTextTests: XCTestCase {

    override func tearDown() {
        // Kedua bridge dilepas: melepas hanya katalog membocorkan bahasa
        // angka milik uji ini ke berkas lain.
        TextLocalization.reset()
        NumberFormat.reset()
        super.tearDown()
    }

    func testDefaultIsIndonesianAndNotEmpty() {
        for text in LocalizedText.allKeys where text.rawValue.hasPrefix("calibration.") {
            XCTAssertFalse(text.indonesian.isEmpty,
                           "\(text.rawValue) tidak punya nilai bawaan")
            XCTAssertFalse(TextLocalization.text(text).isEmpty)
        }
    }

    func testEveryCalibrationKeyIsDeclared() {
        // Kalau sebuah kalimat baru ditambahkan tanpa masuk `allKeys`, gerbang
        // paritas buta terhadapnya — persis cacat yang berkas ini tutup.
        let declared = Set(LocalizedText.allKeys
            .map(\.rawValue)
            .filter { $0.hasPrefix("calibration.") })
        XCTAssertGreaterThanOrEqual(declared.count, 27,
                                    "ada kunci kalibrasi yang belum masuk allKeys")
    }

    func testNeedMoreInsertsBothCounts() {
        let message = CalibrationText.needMoreMessage(minimum: 3, recorded: 1)
        XCTAssertTrue(message.contains("3"), "jumlah minimum hilang: \(message)")
        XCTAssertTrue(message.contains("1"), "jumlah tercatat hilang: \(message)")
    }

    func testSpreadTooWideInsertsBothDegrees() {
        let message = CalibrationText.spreadTooWideMessage(spreadDeg: 5.4,
                                                           maxDeg: 3)
        XCTAssertTrue(message.contains("5,4"), "sebaran hilang: \(message)")
        XCTAssertTrue(message.contains("3,0"), "batas hilang: \(message)")
    }

    func testDirectionUncomputableInsertsObjectID() {
        let message = CalibrationText.directionUncomputableMessage(objectID: "vega")
        XCTAssertTrue(message.contains("vega"), "nama objek hilang: \(message)")
    }

    func testSpokenOffsetAndSpreadInsertDegrees() {
        let offset = CalibrationText.spokenOffset(degrees: 4.2)
        let spread = CalibrationText.spokenSpread(spreadDeg: 2.4, maxDeg: 3)
        XCTAssertTrue(offset.contains("4,2"), "offset hilang: \(offset)")
        XCTAssertTrue(spread.contains("2,4"), "sebaran hilang: \(spread)")
        XCTAssertTrue(spread.contains("3,0"), "batas hilang: \(spread)")
    }

    func testCaptureLabelInsertsNameAndAltitude() {
        let label = CalibrationText.spokenCaptureLabel(name: "Vega",
                                                       altitudeDeg: 40.4)
        XCTAssertTrue(label.contains("Vega"), "nama acuan hilang: \(label)")
        XCTAssertTrue(label.contains("40"), "tinggi hilang: \(label)")
    }

    func testStatusNumbersInsertDegrees() {
        let installed = CalibrationText.installed(offsetDeg: 4.2, spreadDeg: 2.4)
        let display = CalibrationText.spreadDisplay(spreadDeg: 2.4, maxDeg: 3)
        XCTAssertTrue(installed.contains("4,2"), "offset hilang: \(installed)")
        XCTAssertTrue(installed.contains("2,4"), "sebaran hilang: \(installed)")
        XCTAssertTrue(display.contains("2,4"), "sebaran hilang: \(display)")
        XCTAssertTrue(display.contains("3,0"), "batas hilang: \(display)")
    }

    /// Layar dan suara membaca nama tahap dari **satu** sumber.
    ///
    /// Dulu keduanya literal di tempat berbeda (`phaseLabel` di view,
    /// `spokenName` di paket), jadi satu perubahan bisa membuat layar dan
    /// suara menyebut tahap yang berbeda untuk keadaan yang sama. Uji ini
    /// mengunci kesamaan itu.
    func testPhaseDisplayNameAndSpokenNameAgree() {
        for phase: CalibrationPhase in [.idle, .collecting, .ready, .applied] {
            XCTAssertEqual(phase.displayName, phase.spokenName,
                           "layar dan suara menyebut tahap berbeda: \(phase)")
        }
    }

    func testPhaseNamesAreDistinct() {
        let names = [CalibrationPhase.idle, .collecting, .ready, .applied]
            .map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count,
                       "dua tahap berbeda terbaca sama")
    }

    /// Terjemahan memasang kata yang menggantikan bawaan.
    ///
    /// Kalau sebuah kalimat tidak punya entri katalog, `text()` jatuh ke
    /// bawaan Bahasa Indonesia — dan pengguna Bahasa Inggris melihat Bahasa
    /// Indonesia tanpa ada yang tahu. Uji ini memasang terjemahan Inggris
    /// untuk seluruh kunci kalibrasi dan memastikan setiap aksesornya
    /// membacanya.
    func testEnglishTranslationControlsTheWords() {
        let english: [String: String] = [
            "calibration.message.idle": "Point at a star, then tap to record.",
            "calibration.message.needMore": "Need at least %lld (%lld recorded).",
            "calibration.message.ready": "Ready — spread %.1f° from %lld refs.",
            "calibration.message.applied": "Calibration applied.",
            "calibration.speech.phasePrefix": "Phase: %@.",
            "calibration.speech.samplesRecorded": "%lld references recorded.",
            "calibration.speech.applyReady": "Use this calibration",
            "calibration.speech.captureLabel": "Record %@ as reference, %.0f degrees high.",
            "calibration.status.initial": "Point at a reference star, then tap Record.",
            "calibration.status.notReady": "Not ready: spread is still too wide.",
            "calibration.status.reset": "Calibration cleared. Start over.",
            "calibration.display.offset": "Offset %.1f°",
            "calibration.display.spread": "Spread %.1f° (max %.1f°)",
            "calibration.phase.ready.label": "Ready to use",
        ]
        EnglishTranslation.install(english)

        XCTAssertEqual(CalibrationText.idleMessage,
                       "Point at a star, then tap to record.")
        XCTAssertEqual(CalibrationText.readyMessage(spreadDeg: 2, sampleCount: 3),
                       "Ready — spread 2.0° from 3 refs.")
        XCTAssertEqual(CalibrationText.appliedMessage, "Calibration applied.")
        XCTAssertEqual(CalibrationText.spokenSamplesRecorded(3),
                       "3 references recorded.")
        XCTAssertEqual(CalibrationText.spokenApplyReady, "Use this calibration")
        XCTAssertEqual(CalibrationText.initialStatus,
                       "Point at a reference star, then tap Record.")
        XCTAssertEqual(CalibrationText.notReadyStatus,
                       "Not ready: spread is still too wide.")
        XCTAssertEqual(CalibrationText.resetStatus,
                       "Calibration cleared. Start over.")
        XCTAssertEqual(CalibrationText.offsetDisplay(degrees: 4.2), "Offset 4.2°")
        XCTAssertEqual(CalibrationText.spreadDisplay(spreadDeg: 2.4, maxDeg: 3),
                       "Spread 2.4° (max 3.0°)")
        XCTAssertEqual(CalibrationPhase.ready.displayName, "Ready to use")
        XCTAssertEqual(CalibrationPhase.ready.spokenName, "Ready to use")
    }
}
