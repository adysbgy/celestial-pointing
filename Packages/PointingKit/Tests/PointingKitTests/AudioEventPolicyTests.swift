import XCTest
@testable import PointingKit

/// Menguji politik bunyi: **peristiwa mana yang boleh terdengar seperti
/// berhasil**.
///
/// Kenapa berkas ini ada, dan kenapa ia berbunyi di tiga tingkat.
///
/// Sebelum `AudioEventPolicy` dipindah ke paket, keputusan ini hidup di satu
/// baris `Apps/Shared/AudioCue.swift`:
///
///     guard AudioCue.isOn, events.contains(.lockSucceeded) else { return }
///
/// `Apps/` tidak pernah dibangun `./swift-test.sh` di Linux. Diukur: empat
/// mutasi badan itu (termasuk membuat `.uncertain` berbunyi) **semuanya**
/// lolos ke-45 aturan UI. Jadi tidak ada satu pun gerbang yang menahan engine
/// ragu agar terdengar seperti engine yakin — padahal itu persis yang dilarang
/// PRD, dan bunyi adalah satu-satunya saluran bagi pengguna yang tidak
/// melihat layar.
///
/// Ketiga uji di bawah sengaja dibagi supaya tidak ada satu pun yang bisa
/// dipuaskan oleh politik yang salah:
///
///   1. yang audible hanya `lockSucceeded`, **dan** yang lain diam — kedua
///      arah, supaya "tidak pernah berbunyi" tidak lulus;
///   2. `.uncertain` tidak berbunyi **bersama** keadaan yakin, supaya uji
///      tidak lulus hanya karena semuanya menolak;
///   3. saklar pengguna benar-benar digerbangi di kedua posisinya.
final class AudioEventPolicyTests: XCTestCase {

    // MARK: - Peristiwa yang boleh berbunyi

    /// Dari empat peristiwa, hanya `lockSucceeded` yang audible.
    ///
    /// Ditulis sebagai kesamaan himpunan, bukan satu `contains`, supaya
    /// menambahkan peristiwa baru ke daftar audible **memerahkan uji ini**.
    /// Itu disengaja: setiap penambahan adalah keputusan PRD ("bolehkah ini
    /// terdengar seperti berhasil?"), bukan rincian implementasi.
    func testOnlyLockSucceededIsAudible() {
        XCTAssertEqual(AudioEventPolicy.audibleEvents, [.lockSucceeded])
        XCTAssertTrue(AudioEventPolicy.isAudible(.lockSucceeded))
        XCTAssertFalse(AudioEventPolicy.isAudible(.uncertain))
        XCTAssertFalse(AudioEventPolicy.isAudible(.sensorUnavailable))
        XCTAssertFalse(AudioEventPolicy.isAudible(.returnedToIdle))
    }

    /// **Inti cacatnya.** Engine yang ragu tidak boleh berbunyi berhasil.
    ///
    /// Keadaan ini adalah yang dulu lolos ke-45 aturan: `|| .uncertain`
    /// pada badan lama membuat bunyi berbunyi sama persis untuk "terkunci"
    /// dan "kurang yakin". Pengguna yang mengandalkan telinga tidak punya
    /// cara apa pun mengetahui bedanya.
    func testUncertainDoesNotSoundLikeSuccess() {
        XCTAssertFalse(
            AudioEventPolicy.shouldPlay(events: [.uncertain], isAudioEnabled: true),
            "engine ragu berbunyi seperti engine yakin — false confidence yang dilarang PRD")
    }

    /// Kegagalan sensor dan kembali ke idle juga diam.
    ///
    /// Keduanya adalah keadaan yang **bukan** hasil identifikasi; bunyi untuk
    /// keduanya akan mengajarkan pengguna bahwa bunyi ini berarti "ada
    /// sesuatu", lalu bunyi yang sama untuk lock berhenti bermakna.
    func testNonSuccessEventsAreSilent() {
        for event in [HapticEvent.sensorUnavailable, .returnedToIdle, .uncertain] {
            XCTAssertFalse(
                AudioEventPolicy.shouldPlay(events: [event], isAudioEnabled: true),
                "\(event) berbunyi sendiri")
        }
    }

    // MARK: - Keadaan positif, supaya "selalu diam" tidak lulus

    /// Lock yang sukses **harus** berbunyi. Ini pasangan positif dari
    /// `testUncertainDoesNotSoundLikeSuccess`: tanpa ini, kebijakan yang
    /// mengembalikan `false` untuk segalanya akan lulus semua uji di atas.
    func testLockSucceededIsAudible() {
        XCTAssertTrue(
            AudioEventPolicy.shouldPlay(events: [.lockSucceeded], isAudioEnabled: true))
    }

    /// Daftar kosong bukan bunyi. Engine memang mengirim daftar kosong saat
    /// tidak ada perpindahan keadaan.
    func testEmptyEventListIsSilent() {
        XCTAssertFalse(AudioEventPolicy.shouldPlay(events: [], isAudioEnabled: true))
    }

    /// Saat lock sukses dan ragu datang **bersamaan**, bunyinya tetap
    /// dibunyikan — yang dinilai adalah apakah ada alasan untuk berbunyi.
    ///
    /// Ini mengunci bentuk perilaku yang lebih halus: uji yang hanya memakai
    /// daftar satu-peristiwa tidak akan menangkap implementasi yang menolak
    /// seluruh daftar bila di dalamnya ada `.uncertain` — dan bentuk itu
    /// membuat lock sungguhan diam. Uji ini menyatakan pilihan yang dibuat,
    /// bukan kebetulan urutannya.
    func testSuccessAlongsideUncertainStillRings() {
        XCTAssertTrue(
            AudioEventPolicy.shouldPlay(
                events: [.uncertain, .lockSucceeded], isAudioEnabled: true))
    }

    // MARK: - Saklar pengguna

    /// Saklar mati **selalu** diam, walau peristiwanya audible. Kedua arah
    /// diuji supaya uji tidak lulus cuma karena satu posisi saklar.
    func testTheUserSwitchGatesBothWays() {
        XCTAssertTrue(
            AudioEventPolicy.shouldPlay(events: [.lockSucceeded], isAudioEnabled: true),
            "saklar nyala + lock sukses harus berbunyi")
        XCTAssertFalse(
            AudioEventPolicy.shouldPlay(events: [.lockSucceeded], isAudioEnabled: false),
            "saklar mati + lock sukses tidak boleh berbunyi")
    }

    /// Saklar pengguna **tidak** dapat menghidupkan peristiwa yang tidak
    /// audible. Ini arah yang berbahaya bila tertukar: saklar yang bisa
    /// memaksa `.uncertain` berbunyi sama saja dengan menghapus politiknya.
    func testTheUserSwitchCannotMakeAnInaudibleEventAudible() {
        XCTAssertFalse(
            AudioEventPolicy.shouldPlay(events: [.uncertain], isAudioEnabled: true))
        XCTAssertFalse(
            AudioEventPolicy.shouldPlay(events: [.uncertain], isAudioEnabled: false))
    }

    /// Himpunan audible dan jalur `shouldPlay` harus sepakat.
    ///
    /// Dua-duanya publik, jadi bisa menyimpang: satu daftar yang berisi
    /// `.lockSucceeded` sementara `shouldPlay` memeriksa nama lain akan
    /// membuat daftar itu berbohong tanpa satu pun uji di atas menangkapnya
    /// untuk peristiwa yang sama.
    func testTheAudibleSetAndTheSingleEventCheckAgree() {
        for event in HapticEvent.allTestCases {
            XCTAssertEqual(
                AudioEventPolicy.isAudible(event),
                AudioEventPolicy.shouldPlay(events: [event], isAudioEnabled: true),
                "\(event): himpunan audible dan shouldPlay tidak sepakat")
        }
    }
}

extension HapticEvent {
    /// Semua kasus, ditulis tangan karena `HapticEvent` bukan `CaseIterable`.
    ///
    /// Ditulis lengkap dengan sengaja: kalau suatu hari sebuah kasus
    /// ditambahkan dan lupa dimasukkan ke sini, uji kesepakatan di atas
    /// **tidak** memeriksanya — jadi daftar ini sendiri diuji di bawah.
    static let allTestCases: [HapticEvent] = [
        .lockSucceeded, .uncertain, .sensorUnavailable, .returnedToIdle,
    ]
}
