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
final class SensorStatusTextTests: BridgedTextTestCase {

    func testDefaultIsIndonesianAndNotEmpty() {
        for text in LocalizedText.allKeys where text.rawValue.hasPrefix("sensor.") {
            XCTAssertFalse(text.indonesian.isEmpty,
                           "\(text.rawValue) tidak punya nilai bawaan")
            XCTAssertFalse(TextLocalization.text(text).isEmpty)
        }
    }

    /// Pesan sistem **tidak boleh** sampai ke layar apa adanya.
    ///
    /// **Kenapa uji ini ada, padahal `locationFailed*` sudah diuji di bawah.**
    /// Keduanya beda kelas, dan bedanya yang membuat cacat ini lolos.
    /// Kegagalan lokasi disusun di `LocationProvider`, yang sudah memanggil
    /// accessor katalog sejak siklus `SensorStatusText` — jadi jalurnya
    /// terlihat dari berkas `Apps/`. Kegagalan **gerak** disusun di
    /// `MotionLogger.handleFailure`, yang menyimpan
    /// `error.localizedDescription` **langsung** ke `unavailableReason`;
    /// properti itu dirender `Text(reason)` di dua layar.
    ///
    /// Yang membuatnya tak terlihat oleh semua gerbang, sekaligus:
    ///   - Aturan 4 menyapu literal di dalam argumen `Text(...)` — ini
    ///     argumen **fungsi**, bukan literal.
    ///   - Aturan 12 menyapu penugasan ke properti berakhiran Note — ini
    ///     `unavailableReason`, dan nilainya datang dari ekspresi.
    ///   - Aturan 13 menyapu literal di dalam `String(format:)`/`append` —
    ///     tidak ada satupun di sini.
    ///
    /// Akibatnya nyata: teks `localizedDescription` mengikuti bahasa
    /// **perangkat**, bukan bahasa katalog, jadi barisnya adalah satu-satunya
    /// yang tidak bisa diterjemahkan — dan tidak ada yang memberitahu.
    func testMotionFailureWrapsTheSystemMessage() {
        let wrapped = SensorStatusText.motionFailed("timeout")
        XCTAssertNotEqual(wrapped, "timeout",
                          "pesan sistem tampil apa adanya, tanpa kalimat katalog")
        XCTAssertTrue(wrapped.contains("timeout"),
                      "pesan sistem hilang — dua kegagalan berbeda akan terbaca sama")
    }

    /// Terjemahan mengendalikan katanya, dan specifier-nya satu.
    func testMotionFailureFollowsTheCatalog() {
        EnglishTranslation.install(["sensor.motion.failed": "Motion stopped: %@"])
        XCTAssertEqual(SensorStatusText.motionFailed("timeout"), "Motion stopped: timeout")
    }

    /// Bentuk kabel: pesan sistemnya harus **tetap ada** di dalam kalimatnya.
    ///
    /// Ini penjaga arah sebaliknya dari uji di atas: "merapikan" kalimatnya
    /// dengan membuang `%@` akan membuat dua kegagalan berbeda tampak identik
    /// pada baris yang dipakai untuk memutuskan apakah jam masih bisa dipakai.
    func testMotionFailureKeepsTheSystemMessageUnderTranslation() {
        EnglishTranslation.install(["sensor.motion.failed": "Motion stopped"])
        XCTAssertEqual(SensorStatusText.motionFailed("timeout"), "Motion stopped")
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

    /// **Ditolak** dan **dibatasi perangkat** tidak boleh berbunyi sama.
    ///
    /// **Cacat yang ditangkap uji ini.** `CLAuthorizationStatus` memisahkan
    /// `.denied` dari `.restricted`, dan `LocationProvider` memetakan keduanya
    /// ke satu kalimat: "Buka Pengaturan untuk mengizinkan". Pemisahan itu ada
    /// bukan tanpa alasan — `.denied` berarti pengguna menolak dan **bisa**
    /// mengubahnya di Pengaturan, sedangkan `.restricted` berarti perangkatnya
    /// tidak mengizinkan (Pembatasan Orang Tua atau profil MDM) dan **tidak
    /// ada satu pun layar Pengaturan** yang bisa mengubahnya.
    ///
    /// Jadi untuk pengguna `.restricted`, kalimat itu petunjuk yang **tidak
    /// bisa berhasil**: ia mencari layar yang tidak ada, gagal, lalu
    /// menyimpulkan aplikasinya rusak. Itu kebohongan yang bentuknya sama
    /// dengan visual yang mengklaim identitas saat engine ragu — menuntun ke
    /// kepastian yang tidak dimiliki aplikasi.
    ///
    /// Uji ini mengunci tiga hal sekaligus: kalimatnya **berbeda**, kalimat
    /// `.restricted` **tidak** menyuruh membuka Pengaturan, dan kalimat
    /// `.denied` **tetap** menyuruhnya (kalau keduanya berhenti menyebut
    /// Pengaturan, pengguna `.denied` kehilangan satu-satunya jalan keluar).
    func testRestrictedPermissionIsNotToldToOpenSettings() {
        let denied = SensorStatusText.locationDeniedNote
        let restricted = SensorStatusText.locationRestrictedNote

        XCTAssertNotEqual(denied, restricted,
                          "ditolak dan dibatasi perangkat berbunyi sama — "
                          + "hanya satu dari keduanya yang bisa diperbaiki di Pengaturan")
        XCTAssertNotEqual(SensorStatusText.locationDeniedStatus,
                          SensorStatusText.locationRestrictedStatus,
                          "status singkat keduanya sama")

        XCTAssertFalse(restricted.lowercased().contains("buka pengaturan"),
                       "izin yang dibatasi perangkat disuruh membuka Pengaturan, "
                       + "padahal tidak ada layar di sana yang bisa mengubahnya: \(restricted)")
        XCTAssertTrue(denied.lowercased().contains("buka pengaturan"),
                      "izin yang ditolak pengguna kehilangan jalan keluarnya "
                      + "(Pengaturan): \(denied)")

        // Menyebut "Pengaturan" saja tidak cukup untuk gagal: kalimat
        // `.restricted` justru **harus** menyebutnya untuk menjelaskan bahwa
        // tidak ada pengaturan yang bisa menolong. Yang dilarang adalah
        // **menyuruh** ke sana, dan itu dibedakan oleh "buka".
        //
        // Sebaliknya, kalimat itu harus menyatakan dengan jelas bahwa aplikasi
        // ini bukan yang memblokir — kalau tidak, pengguna tetap akan mencari
        // kesalahan di dalam aplikasi.
        XCTAssertTrue(restricted.lowercased().contains("bukan aplikasi"),
                      "tidak menjelaskan bahwa bukan aplikasi ini yang memblokir: \(restricted)")

        // Keduanya harus menyebut lokasi bawaan: app tetap jalan, dan
        // pengguna berhak tahu angka apa yang sedang dipakai.
        for text in [denied, restricted] {
            XCTAssertTrue(text.lowercased().contains("bawaan"),
                          "tidak menyebut lokasi bawaan yang sedang dipakai: \(text)")
        }
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
            "sensor.location.restricted.status": "Restricted by device.",
            "sensor.location.restricted.note": "Restricted by device. Using default.",
            "sensor.location.accuracy": "Accuracy %.0f m",
            "sensor.location.failed.status": "Failed: %@",
            "sensor.location.failed.note": "Failed: %@. Using default.",
        ]
        TextLocalization.install { english[$0] }

        XCTAssertEqual(SensorStatusText.motionMissing, "No motion sensor.")
        XCTAssertEqual(SensorStatusText.motionUnavailable, "Motion off.")
        XCTAssertEqual(SensorStatusText.locationDeniedStatus, "Location denied.")
        XCTAssertEqual(SensorStatusText.locationDeniedNote, "Denied. Open Settings.")
        XCTAssertEqual(SensorStatusText.locationRestrictedStatus, "Restricted by device.")
        XCTAssertEqual(SensorStatusText.locationRestrictedNote,
                       "Restricted by device. Using default.")
        XCTAssertEqual(SensorStatusText.locationAccuracy(meters: 3), "Accuracy 3 m")
        XCTAssertEqual(SensorStatusText.locationFailedStatus("x"), "Failed: x")
        XCTAssertEqual(SensorStatusText.locationFailedNote("x"),
                       "Failed: x. Using default.")
    }
}
