import XCTest
@testable import PointingKit

/// Kalimat status tautan tidak boleh lahir sebagai literal di dalam service.
///
/// **Cacat yang dijaga.** `PhoneLinkService` dan `WatchLinkService` menyimpan
/// kalimat status ke properti (`lastNote`, `lastMessageNote`), lalu view
/// merendernya lewat `Text(note)`. Selama kalimatnya literal di dalam service,
/// Aturan 4 (yang menyapu argumen `Text(...)`) dan Aturan 6 (yang memeriksa
/// paritas kunci) sama-sama buta. Uji di berkas ini menahan kalimatnya di
/// tempat yang bisa dilihat kedua gerbang.
final class LinkStatusTextTests: XCTestCase {

    /// Setiap kalimat berasal dari katalog, bukan literal di kode.
    ///
    /// Kalau seseorang mengembalikan `LinkStatusText` menjadi literal
    /// Indonesia langsung, uji ini gagal karena teksnya tidak lagi sama
    /// dengan nilai katalog.
    func testEverySentenceComesFromTheCatalog() {
        let fromCatalog = String(format: TextLocalization.text(.linkStatusWatchSaw), "Mars")
        XCTAssertEqual(LinkStatusText.watchSaw("Mars"), fromCatalog)

        XCTAssertEqual(LinkStatusText.stateFromWatch,
                       TextLocalization.text(.linkStatusStateFromWatch))
        XCTAssertEqual(LinkStatusText.calibrationFromWatch,
                       TextLocalization.text(.linkStatusCalibrationFromWatch))
        XCTAssertEqual(LinkStatusText.policyFromWatch,
                       TextLocalization.text(.linkStatusPolicyFromWatch))
        XCTAssertEqual(LinkStatusText.acknowledgement,
                       TextLocalization.text(.linkStatusAcknowledgement))
        XCTAssertEqual(LinkStatusText.calibrationNotSent,
                       TextLocalization.text(.linkStatusCalibrationNotSent))
        XCTAssertEqual(LinkStatusText.messageNotSent,
                       TextLocalization.text(.linkStatusMessageNotSent))
        XCTAssertEqual(LinkStatusText.invalidPolicyIgnored,
                       TextLocalization.text(.linkStatusInvalidPolicy))
        XCTAssertEqual(LinkStatusText.stateRequestTooEarly,
                       TextLocalization.text(.linkStatusStateRequestTooEarly))
        XCTAssertEqual(LinkStatusText.watchUnreachablePolicy,
                       TextLocalization.text(.linkStatusWatchUnreachablePolicy))
        XCTAssertEqual(LinkStatusText.watchUnreachableMessage,
                       TextLocalization.text(.linkStatusWatchUnreachableMessage))
    }

    /// Tidak ada satu pun kalimat yang membocorkan placeholder ke layar.
    ///
    /// `%@` yang tidak terisi akan terbaca pengguna sebagai tanda baca aneh.
    /// Format argumen yang salah jenis jauh lebih buruk lagi: ia menjatuhkan
    /// app di CoreFoundation (lihat Aturan 11).
    func testNoSentenceLeaksAPlaceholder() {
        let sentences = [
            LinkStatusText.calibrationNotSent,
            LinkStatusText.messageNotSent,
            LinkStatusText.sendFailed("sesi ditolak"),
            LinkStatusText.sent("keadaan"),
            LinkStatusText.watchSaw("Jupiter"),
            LinkStatusText.stateFromWatch,
            LinkStatusText.calibrationFromWatch,
            LinkStatusText.policyFromWatch,
            LinkStatusText.acknowledgement,
            LinkStatusText.invalidPolicyIgnored,
            LinkStatusText.stateRequestTooEarly,
            LinkStatusText.watchUnreachablePolicy,
            LinkStatusText.watchUnreachableMessage,
        ]
        for sentence in sentences {
            XCTAssertFalse(sentence.contains("%@"),
                           "placeholder bocor ke layar: \(sentence)")
            XCTAssertFalse(sentence.isEmpty, "kalimat kosong")
        }
    }

    /// Nama objek dan nama jenis pesan benar-benar disisipkan.
    func testNamesAreInterpolated() {
        XCTAssertTrue(LinkStatusText.watchSaw("Saturnus").contains("Saturnus"))
        XCTAssertTrue(LinkStatusText.sent("kalibrasi").contains("kalibrasi"))
        XCTAssertTrue(LinkStatusText.sendFailed("sesi ditolak").contains("sesi ditolak"))
    }

    /// Alasan galat sistem tidak diterjemahkan ulang.
    ///
    /// `localizedDescription` sudah datang dalam bahasa perangkat. Kalau kita
    /// membungkusnya dengan katalog lagi, pengguna berbahasa Inggris akan
    /// melihat alasan berbahasa Indonesia yang salah.
    func testSystemReasonIsPassedThroughVerbatim() {
        let reason = "The operation could not be completed."
        XCTAssertTrue(LinkStatusText.sendFailed(reason).contains(reason),
                      "alasan sistem dirusak oleh terjemahan")
    }
}
