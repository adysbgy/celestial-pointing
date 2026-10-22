import XCTest
import CelestialEngine
@testable import PointingKit

/// Complication yang **tidak pernah** menyegar, sehingga penanda basinya
/// mustahil muncul.
///
/// **Cacat yang diukur, bukan disangka.** Siklus-siklus sebelumnya membangun
/// lapisan basi yang panjang dan benar di `ComplicationDigest`:
/// `isStale(at:)`, `confirmsIdentityNow(at:)`, `sublineContent(at:)`, dan
/// `presentedSymbolName(at:)`. Semuanya diuji di Linux, semuanya memakai
/// `now` sebagai parameter — dan **tidak satu pun pernah berkesempatan
/// berjalan pada waktu yang berbeda dari waktu penulisan**.
///
/// Sebabnya ada di `ComplicationProvider.getTimeline`:
///
///     completion(Timeline(entries: [entry], policy: .never))
///
/// `policy: .never` berarti watchOS tidak pernah meminta entri baru kecuali
/// app memanggil `reloadAllTimelines()`. App hanya memanggilnya saat tanda
/// tangan snapshot **berubah** (`PointingEngine.recordComplicationIfChanged`).
/// Jadi begitu pergelangan berhenti bergerak — tepat kasus yang membuat
/// complication basi — tidak ada tulisan baru, tidak ada reload, dan
/// **tidak ada render baru**. `Date()` di dalam view dievaluasi sekali, pada
/// detik digest itu ditulis, ketika umurnya nol.
///
/// Akibatnya di pergelangan: cuplikan berumur 90 menit tetap menampilkan
/// `checkmark.circle.fill` dan nama objek, karena penanda basi tidak pernah
/// diminta. Seluruh lapisan basi itu adalah jalur mati yang lulus semua uji —
/// persis kelas cacat yang dikejar repo ini: bukan salah hitung, tapi
/// **tidak pernah dipanggil**.
///
/// **Kenapa perbaikannya bukan `.after(Date().addingTimeInterval(60))`.**
/// Menyegarkan tiap menit akan membuat complication bangun 60×/jam untuk
/// jawaban yang umurnya baru berubah sekali, di menit ke-15. Yang dibutuhkan
/// bukan penyegaran berkala, melainkan **satu** penyegaran tepat setelah
/// cuplikan melewati ambang klaimnya. Itu keputusan murni atas dua waktu, jadi
/// ia bisa diuji di Linux — dan itulah yang diuji di sini.
final class ComplicationRefreshScheduleTests: XCTestCase {

    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private func digest(ageSeconds: TimeInterval,
                        isConfirmed: Bool = true,
                        state: PointingState = .lock,
                        name: String? = "Sirius") -> ComplicationDigest {
        ComplicationDigest(stateRaw: state.rawValue,
                           objectName: name,
                           objectKindRaw: ObjectKind.star.rawValue,
                           isConfirmed: isConfirmed,
                           updatedAt: fixedNow.addingTimeInterval(-ageSeconds))
    }

    // MARK: - Inti kontraknya

    /// **Ini uji yang sebenarnya.** Tanggal yang dikembalikan harus jatuh di
    /// sisi **basi** dari ambang, bukan di sisi segar.
    ///
    /// Kalau `nextRefreshDate` mengembalikan `updatedAt + maximumClaimedAge`
    /// persis, `isStale` masih `false` di detik itu (`>` bersifat ketat), jadi
    /// watchOS akan menggambar ulang complication dan **tetap** menampilkan
    /// centang hijau — lalu tidak pernah diminta lagi. Penyegaran yang
    /// mendarat satu detik terlalu awal sama saja dengan tidak ada
    /// penyegaran. Karena itu yang diuji bukan "ada tanggal", melainkan
    /// "tanggal itu benar-benar membuat penandanya muncul".
    func testRefreshDateLandsOnTheStaleSideOfTheThreshold() throws {
        let fresh = digest(ageSeconds: 0)
        let refresh = try XCTUnwrap(fresh.nextRefreshDate(after: fixedNow),
                                    "digest segar yang punya jawaban wajib punya jadwal penyegaran")
        XCTAssertTrue(fresh.isStale(at: refresh),
                      "penyegaran mendarat di detik ketika digest masih dianggap segar; penanda basi tidak akan muncul")
    }

    /// Sisi sebaliknya: penyegaran **tidak boleh** lebih lambat dari yang
    /// perlu. Selisih satu detik sebelum tanggal itu harus masih segar, kalau
    /// tidak kita membuang waktu bangun untuk jawaban yang masih sah.
    func testRefreshDateIsNotLaterThanNecessary() throws {
        let fresh = digest(ageSeconds: 0)
        let refresh = try XCTUnwrap(fresh.nextRefreshDate(after: fixedNow))
        XCTAssertFalse(fresh.isStale(at: refresh.addingTimeInterval(-1)),
                       "penyegaran dijadwalkan lebih lambat dari ambang; complication menampilkan centang hijau melewati batas klaimnya")
    }

    /// Jarak dari `updatedAt` harus **persis** ambang + kelonggaran, bukan
    /// angka lain yang kebetulan lolos dua uji di atas (mis. ambang + 10
    /// menit juga lolos keduanya).
    func testRefreshIsOneGraceAfterTheClaimLimit() throws {
        let fresh = digest(ageSeconds: 0)
        let refresh = try XCTUnwrap(fresh.nextRefreshDate(after: fixedNow))
        XCTAssertEqual(refresh.timeIntervalSince(fresh.updatedAt),
                       ComplicationDigest.maximumClaimedAge + ComplicationDigest.staleRefreshGrace,
                       accuracy: 1e-9)
    }

    /// Kelonggarannya harus eksplisit dan kecil. Angka besar berarti
    /// complication tetap mengklaim lock lama jauh melewati batasnya; angka
    /// nol berarti penyegaran mendarat tepat di ambang dan tidak berguna
    /// (lihat uji pertama). Satu detik adalah resolusi jam, bukan pilihan rasa.
    func testStaleRefreshGraceIsOneSecond() {
        XCTAssertEqual(ComplicationDigest.staleRefreshGrace, 1)
    }

    // MARK: - Kapan TIDAK perlu menyegar

    /// Sudah basi → penanda basi sudah tergambar. Menjadwalkan penyegaran
    /// lagi hanya membangunkan widget untuk menggambar hal yang sama.
    func testAlreadyStaleDigestNeedsNoRefresh() {
        XCTAssertNil(digest(ageSeconds: 90 * 60).nextRefreshDate(after: fixedNow))
    }

    /// Tanpa jawaban (`searching`) tidak ada nama yang bisa basi. Tidak ada
    /// yang perlu dijadwalkan, dan menjadwalkan berarti membangunkan widget
    /// untuk kalimat yang tidak berubah.
    func testDigestWithoutAnAnswerNeedsNoRefresh() {
        XCTAssertNil(digest(ageSeconds: 0, state: .searching, name: nil)
            .nextRefreshDate(after: fixedNow))
        XCTAssertNil(digest(ageSeconds: 0, state: .pointing, name: nil)
            .nextRefreshDate(after: fixedNow))
    }

    /// `.uncertain` **punya** jawaban (kandidat), jadi ia bisa basi dan wajib
    /// dijadwalkan. Kalau syaratnya ditulis `state == .lock`, kandidat akan
    /// membeku di pergelangan sebagai nama tanpa batas umur.
    func testUncertainDigestIsScheduledToo() throws {
        let uncertain = digest(ageSeconds: 0, isConfirmed: false, state: .uncertain)
        // `XCTUnwrap` sendiri sudah gagal bila `nil`; membungkusnya dengan
        // `XCTAssertNotNil` hanya menambah pernyataan yang selalu benar dan
        // menyamarkan bahwa yang diuji adalah "tidak nil".
        _ = try XCTUnwrap(uncertain.nextRefreshDate(after: fixedNow),
                          "kandidat `.uncertain` yang punya nama wajib dijadwalkan penyegaran")
    }

    /// Jam device yang salah (stempel di masa depan) sudah dibaca `isStale`
    /// sebagai basi, jadi tidak ada yang perlu dijadwalkan — dan menjadwalkan
    /// tanggal di masa lalu akan membuat WidgetKit menyegar berulang-ulang.
    func testFutureTimestampNeedsNoRefresh() {
        let future = ComplicationDigest(stateRaw: PointingState.lock.rawValue,
                                        objectName: "Sirius",
                                        objectKindRaw: ObjectKind.star.rawValue,
                                        isConfirmed: true,
                                        updatedAt: fixedNow.addingTimeInterval(3600))
        XCTAssertNil(future.nextRefreshDate(after: fixedNow))
    }

    /// **Jadwal tidak boleh di masa lalu.** Digest yang **hampir** basi
    /// (setengah detik sebelum ambang) adalah kasus terketat: penyegarannya
    /// hanya beberapa detik di depan. Kalau rumusnya memakai `updatedAt`
    /// tanpa ambang, tanggalnya akan jatuh di masa lalu dan WidgetKit akan
    /// meminta entri berulang-ulang tanpa henti.
    func testRefreshIsNeverInThePast() throws {
        let nearlyStale = digest(ageSeconds: ComplicationDigest.maximumClaimedAge - 0.5)
        XCTAssertFalse(nearlyStale.isStale(at: fixedNow), "prasyarat: masih segar")
        let refresh = try XCTUnwrap(nearlyStale.nextRefreshDate(after: fixedNow))
        XCTAssertGreaterThan(refresh, fixedNow)
    }

    // MARK: - Kesetiaan pada ambang yang sudah ada

    /// Ambang yang dipakai jadwal ini harus ambang **yang sama** dengan yang
    /// dipakai penanda basi. Kalau `nextRefreshDate` menyalin angka 900
    /// sebagai literal, mengubah `maximumClaimedAge` akan membuat jadwal dan
    /// penanda berbeda pendapat — complication disegarkan pada saat ia masih
    /// menganggap dirinya segar.
    func testScheduleFollowsTheSharedThreshold() throws {
        let fresh = digest(ageSeconds: 0)
        let refresh = try XCTUnwrap(fresh.nextRefreshDate(after: fixedNow))
        // Titik ketika penanda basi menyala, dihitung dari ambang bersama.
        let threshold = fresh.updatedAt
            .addingTimeInterval(ComplicationDigest.maximumClaimedAge)
        XCTAssertGreaterThan(refresh, threshold,
                             "jadwal harus melewati ambang bersama, bukan menyentuhnya")
    }
}
