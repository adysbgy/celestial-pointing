import XCTest
@testable import PointingKit

/// Uji untuk status sensor & izin yang dihasilkan di luar view.
///
/// **Kenapa ini diuji di Linux.** Kalimat ini adalah satu-satunya jalur sampai
/// pesan "izin ditolak" dan "sensor tidak tersedia" ke layar, dan PRD menuntut
/// penolakan izin **terlihat**. Versi lamanya hidup sebagai literal di dalam
/// `LocationProvider`/`MotionLogger`/`PointingEngine` — ditugaskan ke properti,
/// bukan diteruskan ke `Text("…")` — jadi aturan 4 tidak pernah melihatnya dan
/// tidak satu pun ada di katalog. Yang bisa dijaga di Linux: bentuk kunci,
/// nilai bawaan Bahasa Indonesia yang tidak kosong, dan bahwa nilai yang
/// disisipkan benar-benar masuk ke kalimatnya.
final class SensorStatusTextTests: XCTestCase {

    override func tearDown() {
        TextLocalization.reset()
        super.tearDown()
    }

    func testDefaultIsIndonesianAndNotEmpty() {
        for text in LocalizedText.allKeys where text.rawValue.hasPrefix("sensor.") {
            XCTAssertFalse(text.indonesian.isEmpty,
                           "\(text.rawValue) tidak punya nilai bawaan")
            XCTAssertFalse(TextLocalization.text(text).isEmpty)
        }
    }

    func testMotionMessagesAreDistinct() {
        // Dua keadaan berbeda (perangkat tidak menyediakan sensor vs sensor
        // hilang saat berjalan) harus terbaca berbeda — menyamakannya
        // menghapus perbedaan yang justru penting bagi pengguna.
        XCTAssertNotEqual(SensorStatusText.motionMissing,
                          SensorStatusText.motionUnavailable)
    }

    func testAccuracyInsertsMeters() {
        let spoken = SensorStatusText.locationAccuracy(meters: 12)
        XCTAssertTrue(spoken.contains("12"),
                      "angka meter tidak masuk ke kalimat: \(spoken)")
    }

    func testFailureMessagesInsertSystemMessage() {
        let status = SensorStatusText.locationFailedStatus("timeout")
        let note = SensorStatusText.locationFailedNote("timeout")
        XCTAssertTrue(status.contains("timeout"), "pesan sistem hilang: \(status)")
        XCTAssertTrue(note.contains("timeout"), "pesan sistem hilang: \(note)")
    }

    /// Kalimat yang disisipkan tetap dikendalikan katalog.
    ///
    /// Kalau salah satu kalimat ini tidak punya entri katalog, `text()` jatuh
    /// ke nilai bawaan Bahasa Indonesia — dan pengguna Bahasa Inggris melihat
    /// "Izin lokasi ditolak" tanpa ada yang tahu. Uji ini memasang terjemahan
    /// Inggris untuk seluruh kunci sensor dan memastikan setiap aksesornya
    /// benar-benar membacanya.
    func testEnglishTranslationControlsTheWords() {
        let english: [String: String] = [
            "sensor.motion.missing": "No motion sensor.",
            "sensor.motion.unavailable": "Motion off.",
            "sensor.location.denied.status": "Location denied.",
            "sensor.location.denied.note": "Denied. Open Settings.",
            "sensor.location.accuracy": "Accuracy %.0f m",
            "sensor.location.failed.status": "Failed: %@",
            "sensor.location.failed.note": "Failed: %@. Using default.",
        ]
        TextLocalization.install { english[$0] }

        XCTAssertEqual(SensorStatusText.motionMissing, "No motion sensor.")
        XCTAssertEqual(SensorStatusText.motionUnavailable, "Motion off.")
        XCTAssertEqual(SensorStatusText.locationDeniedStatus, "Location denied.")
        XCTAssertEqual(SensorStatusText.locationDeniedNote, "Denied. Open Settings.")
        XCTAssertEqual(SensorStatusText.locationAccuracy(meters: 3), "Accuracy 3 m")
        XCTAssertEqual(SensorStatusText.locationFailedStatus("x"), "Failed: x")
        XCTAssertEqual(SensorStatusText.locationFailedNote("x"),
                       "Failed: x. Using default.")
    }
}
