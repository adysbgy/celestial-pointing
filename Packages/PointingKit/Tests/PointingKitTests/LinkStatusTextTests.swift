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
final class LinkStatusTextTests: BridgedTextTestCase {

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

    // MARK: - Aktivasi sesi

    /// Kegagalan **aktivasi** sesi tidak boleh sampai ke layar apa adanya.
    ///
    /// **Kenapa uji ini terpisah dari `sendFailed` di atas.** Keduanya beda
    /// jalur, dan bedanya persis yang membuat cacat ini lolos berbulan-bulan.
    /// `sendFailed` dipanggil dari kedua `LinkService` untuk kegagalan
    /// pengiriman, dan jalurnya **terlihat** dari berkas `Apps/`. Kegagalan
    /// aktivasi menyimpan `error.localizedDescription` **mentah** ke
    /// `lastNote` / `lastMessageNote` — dua properti yang dirender di layar
    /// Tautan — tanpa accessor apa pun.
    ///
    /// Yang membuatnya tak terlihat gerbang, sekaligus:
    ///   - bukan literal di argumen `Text(...)` (Aturan 4),
    ///   - bukan penugasan berakhiran Note dengan **literal** (Aturan 12) —
    ///     nilainya ekspresi `error.localizedDescription`,
    ///   - bukan argumen `String(format:)`/`append` (Aturan 13).
    ///
    /// Akibatnya: baris yang seharusnya berbunyi "Sesi gagal aktif: …" hanya
    /// berisi teks bahasa perangkat, di tengah layar berbahasa Indonesia.
    func testActivationFailureIsWrappedNotBare() {
        let reason = "The operation could not be completed."
        let shown = LinkStatusText.activationFailed(reason)
        XCTAssertNotEqual(shown, reason,
                          "pesan sistem tampil apa adanya, tanpa kalimat katalog")
        XCTAssertTrue(shown.contains(reason),
                      "pesan sistem hilang — dua kegagalan berbeda terbaca sama")
    }

    /// Katalog yang mengendalikan katanya, dan specifier-nya satu `%@`.
    func testActivationFailureFollowsTheCatalog() {
        EnglishTranslation.install(
            ["link.status.activationFailed": "Session failed: %@"])
        XCTAssertEqual(LinkStatusText.activationFailed("timeout"),
                       "Session failed: timeout")
    }

    // MARK: - Kalimat utuh baris tautan (dipakai `.accessibilityLabel`)

    /// **Cacat yang ditutup di sini.** `linkAccessibilityLabel` di
    /// `PointingView` merakit kalimatnya sendiri:
    ///
    /// ```swift
    /// var text = link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau"
    /// text += LinkStatusText.sendFailures(link.sendFailureCount)
    /// ```
    ///
    /// Bagian pertamanya **tidak pernah melewati katalog**. Dua gerbang yang
    /// biasa menangkap literal Bahasa Indonesia di `Apps/` buta di sini, dan
    /// ketiganya dibuktikan: Aturan 4 (bukan argumen `Text(...)`), Aturan 12
    /// (penugasan ke `var text`, bukan properti berakhiran Note/Label), dan
    /// Aturan 16 (bukan literal peritel aksesibilitas — yang diiwa adalah
    /// **nama variabelnya**).
    ///
    /// Yang membuatnya bertahan lama adalah bentuknya: baris yang
    /// **ditampilkan** di layar memakai kunci yang benar dengan teks yang sama
    /// persis, jadi komponennya terlihat benar, Bahasa Inggrinya ada, dan
    /// tidak ada layar yang tampak keliru.
    ///
    /// Uji ini mengunci nilai **mutlak**, bukan perbandingan dua bentuk —
    /// mutasi "kalimat literal" tetap hijau bila yang dibandingkan hanya
    /// "boleh memakai kunci apa pun yang menghasilkan teks yang sama".
    func testReachableSentenceIsNotAHardcodedIndonesianLiteral() {
        let spoken = LinkStatusText.linkSpeech(isReachable: true,
                                               sendFailureCount: 0)
        XCTAssertEqual(spoken, TextLocalization.text(.pointingLinkConnected) + ".",
                       "kalimat yang diucapkan harus dari katalog, bukan literal")
        XCTAssertNotEqual(spoken, "iPhone terhubung",
                          "literal Bahasa Indonesia bocor ke pengumuman")
    }

    /// Keadaan tidak terjangkau harus **terdengar berbeda** dari terjangkau.
    ///
    /// Nilai mutlak kedua, karena yang pertama sudah tertutup: accessor bisa
    /// mengembalikan satu kalimat benar untuk salah satu keadaan, lalu diam-diam
    /// memakai kalimat yang sama untuk yang lain. Dan "iPhone terhubung" saat
    /// iPhone justru tidak terjangkau lebih buruk daripada teks yang tidak
    /// diterjemahkan: ia **menyatakan sesuatu yang tidak benar**.
    func testUnreachableSentenceDiffersFromTheReachableOne() {
        let reachable = LinkStatusText.linkSpeech(isReachable: true,
                                                   sendFailureCount: 0)
        let unreachable = LinkStatusText.linkSpeech(isReachable: false,
                                                     sendFailureCount: 0)
        XCTAssertNotEqual(reachable, unreachable)
        XCTAssertEqual(unreachable, TextLocalization.text(.linkSpeechUnreachable))
        XCTAssertNotEqual(unreachable, TextLocalization.text(.linkSpeechReachable))
    }

    /// Bagian jumlah **ikut** kalimat, dan nol **tidak** ikut.
    ///
    /// Dua arah sengaja. Kalau nol ikut, kalimatnya berbunyi "iPhone
    /// terhubung. 0 kiriman gagal." — itu menyatakan ada masalah yang tidak
    /// terjadi, dan yang didengar pengguna seperti ada yang salah. Kalau jumlah
    /// tidak pernah ikut, kegagalan pengiriman kembali senyap di pengumuman.
    func testFailureCountIsAppendedOnlyWhenItIsPositive() {
        XCTAssertEqual(LinkStatusText.linkSpeech(isReachable: true,
                                                 sendFailureCount: 0),
                       "iPhone terhubung.")
        XCTAssertEqual(LinkStatusText.linkSpeech(isReachable: true,
                                                 sendFailureCount: 3),
                       "iPhone terhubung. 3 kiriman gagal.")
    }

    /// Kalimat utuh mengikuti katalog **semuanya**, bukan cuma bagian jumlah.
    ///
    /// Yang dijaga: versi Inggris, supaya apa pun yang diumumkan pengguna
    /// Bahasa Inggris benar-benar Bahasa Inggris — termasuk bagian pembuka
    /// yang salah sebelum siklus ini. Bagian itu literal, jadi memasang
    /// terjemahan pada bagian jumlah saja tidak mengubah apa pun.
    func testTheWholeSentenceFollowsTheCatalog() {
        EnglishTranslation.install([
            "link.speech.reachable": "The phone is connected.",
            "link.speech.unreachable": "The phone cannot be reached.",
            "link.status.sendFailuresClause": " %lld %@.",
            "link.status.sendFailuresWord": "messages failed",
        ])
        XCTAssertEqual(LinkStatusText.linkSpeech(isReachable: true,
                                                 sendFailureCount: 2),
                       "The phone is connected. 2 messages failed.")
        XCTAssertEqual(LinkStatusText.linkSpeech(isReachable: false,
                                                 sendFailureCount: 0),
                       "The phone cannot be reached.")
    }
}
