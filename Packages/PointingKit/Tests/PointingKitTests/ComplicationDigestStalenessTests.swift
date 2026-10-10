import XCTest
import CelestialEngine
@testable import PointingKit

/// Complication yang menampilkan lock lama seolah masih hasil sekarang.
///
/// **Premis.** `PointingEngine.recordComplicationIfChanged()` menulis digest
/// **hanya saat tanda tangannya berubah** (PointingEngine.swift:352). Itu
/// benar dan perlu — timeline WidgetKit tidak boleh ditulis 20×/dtk. Tapi
/// konsekuensinya: kalau pergelangan berhenti bergerak, tidak ada tulisan
/// baru yang terjadi, dan complication **tetap** menampilkan nama objek
/// dengan `isConfirmed: true`.
///
/// Di app, staleness ditangani oleh keadaan: `isDisplayingStaleObject`
/// benar begitu keadaan kembali `pointing` karena keadaan tidak lagi punya
/// jawaban. Complication tidak punya keadaan itu — ia hanya punya cuplikan
/// terakhir yang ditulis. Jadi tepat ketika app akan memberi tahu "ini sisa
/// Incremental", complication diam-diam mengklaim masih ada jawaban
/// sekarang. Perlu tahu bahwa digest yang ada boleh dipakai sebagai klaim
/// yang berlaku sekarang.
/// `updatedAt` sudah ada, sudah masuk JSON, sudah diuji round-trip — dan
/// **tidak pernah dibaca**. Ini instance ketiga dari pola yang sama seperti
/// `uncertainReasonCounts` dan `unanalyzableCount`: field dihitung, disimpan,
/// lalu tidak pernah dipakai untuk keputusan apa pun.
final class ComplicationDigestStalenessTests: XCTestCase {

    private func digest(updatedMinutesAgo minutes: Double,
                        isConfirmed: Bool = true) -> ComplicationDigest {
        ComplicationDigest(stateRaw: PointingState.lock.rawValue,
                           objectName: "Sirius",
                           objectKindRaw: ObjectKind.star.rawValue,
                           isConfirmed: isConfirmed,
                           updatedAt: Date(timeIntervalSinceNow: -minutes * 60))
    }

    private func now() -> Date { Date() }

    // MARK: - Batas usia

    /// Digest yang baru saja ditulis **tidak** boleh dianggap basi.
    ///
    /// Tanpa ini, ambang bisa saja terlalu pendek sehingga complication
    /// menampilkan "basi" untuk hasil yang baru saja lock — dan penanda
    /// basi jadi tidak berarti apa-apa.
    func testFreshDigestIsNotStale() {
        XCTAssertFalse(digest(updatedMinutesAgo: 0, isConfirmed: false).isStale(at: now()))
        XCTAssertFalse(digest(updatedMinutesAgo: 1).isStale(at: now()))
    }

    /// Digest lama harus basi. Ini yang tidak terjadi hari ini.
    func testOldDigestIsStale() {
        XCTAssertTrue(digest(updatedMinutesAgo: 90).isStale(at: now()))
        XCTAssertTrue(digest(updatedMinutesAgo: 600).isStale(at: now()))
    }

    /// **Batasnya harus eksplisit dan bisa diuji.** Umur negatif (jam maju,
    /// atau jam device salah) tidak boleh membalikkan penilaian: digest dari
    /// "masa depan" bukan bukti bahwa jarinya baru saja bergerak.
    ///
    /// Tanpa penjaga ini, klausa "kecuali bila jam device salah" bisa
    /// ditambahkan belakangan dan tetap terlihat masuk akal.
    func testFutureTimestampIsTreatedAsStaleNotFresh() {
        let future = ComplicationDigest(stateRaw: PointingState.lock.rawValue,
                                        objectName: "Sirius",
                                        objectKindRaw: ObjectKind.star.rawValue,
                                        isConfirmed: true,
                                        updatedAt: Date(timeIntervalSinceNow: 3600))
        XCTAssertTrue(future.isStale(at: now()))
    }

    // MARK: - Yang diklaim

    /// Penanda basi harus **membatalkan klaim identitas**, bukan cuma
    /// menambah catatan.
    ///
    /// `isConfirmed` berarti "gambar boleh memakai ciri pengenal" (cincin
    /// Saturnus, pita Jupiter). Kalau digest basi masih `isConfirmed`, gambar
    /// menampilkan planet lengkap sementara yang sebenarnya adalah catatan
    /// jam lalu — dan gambar lebih yakin daripada teksnya, yang persis bentuk
    /// false confidence yang paling sulit ditangkap.
    func testStaleDigestWithdrawsTheIdentityClaim() {
        let stale = digest(updatedMinutesAgo: 90)
        XCTAssertTrue(stale.isConfirmed, "aslinya terkonfirmasi")
        XCTAssertFalse(stale.confirmsIdentityNow(at: now()),
                       "tetap terkonfirmasi walau sudah basi")
    }

    /// Digest segar harus **mempertahankan** klaimnya. Menjaga agar perbaikan
    /// tidak bergerak terlalu jauh — mematikan semua `isConfirmed`.
    func testFreshDigestKeepsTheIdentityClaim() {
        XCTAssertTrue(digest(updatedMinutesAgo: 2).confirmsIdentityNow(at: now()))
    }

    /// Yang sudah tidak terkonfirmasi tidak boleh menjadi terkonfirmasi karena
    /// basi atau karena segar — waktu tidak memperbaiki keyakinan.
    func testUnconfirmedDigestNeverConfirmsIdentity() {
        XCTAssertFalse(digest(updatedMinutesAgo: 0, isConfirmed: false)
            .confirmsIdentityNow(at: now()))
        XCTAssertFalse(digest(updatedMinutesAgo: 90, isConfirmed: false)
            .confirmsIdentityNow(at: now()))
    }

    // MARK: - Penanda yang tampil

    /// Digest basi harus punya isi baris kedua yang menyatakan basi —
    /// kalau tidak, penandanya tidak akan pernah muncul dan pengamat tidak
    /// pernah tahu.
    ///
    /// Yang diuji di sini adalah **keputusan**, bukan teks: WidgetKit tidak
    /// ada di Linux, jadi aturan yang hanya hidup di view-nya mustahil diuji.
    func testStaleDigestAsksForAStaleMarkerInTheSubline() {
        XCTAssertEqual(digest(updatedMinutesAgo: 90).sublineContent(at: now()),
                       .staleMarker)
        XCTAssertEqual(digest(updatedMinutesAgo: 2).sublineContent(at: now()),
                       .objectKind)
    }

    /// **Prioritasnya tetap sama.** Penanda ragu lebih penting daripada
    /// penanda basi: "Ragu" answering the question "apakah ini benar?",
    /// sedangkan "Basi" answering "kapan?". Kalau basi menutupi ragu, ragu
    /// hilang tepat pada keadaan di mana ia paling dibutuhkan.
    ///
    /// Ini pengaman terhadap perbaikan masa depan yang "menyederhanakan"
    /// dengan memeriksa basi lebih dulu.
    func testUncertaintyStillOutranksStaleness() {
        let uncertainAndOld = digest(updatedMinutesAgo: 90, isConfirmed: false)
        XCTAssertTrue(uncertainAndOld.carriesUncertaintyMarker(at: now()))
        XCTAssertEqual(uncertainAndOld.sublineContent(at: now()), .uncertaintyMarker)
    }

    // MARK: - Konstanta umur maksimum (threshold tak tergate langsung)

    /// `maximumClaimedAge` sendiri **harus** diikat, bukan cuma sifatnya.
    ///
    /// Seluruh uji basi di atas memakai helper `digest(updatedMinutesAgo:)`
    /// dengan nilai 0/1/2/90/600 menit — tidak satu pun yang menyebut
    /// `maximumClaimedAge`. Jadi kalau suatu hari angkanya diganti (mis.
    /// `15 * 60` menjadi `5 * 60`, atau `max` dilepas jadi `0`), complication
    /// akan membekukan nama objek jauh lebih cepat **tanpa satu uji pun yang
    /// merah**: lima nilai uji itu semua masih di atas ambang baru. Ini tepat
    /// kelas cacat yang dicari repo ini — ambang yang tidak diuji adalah
    /// ambang yang bisa diam-diam berubah. Docstring konstanta itu sendiri
    /// menulis \"klausa yang tidak bisa diuji adalah klausa yang tidak bisa
    /// dipercaya\"; uji ini yang mewujudkannya.
    func testMaximumClaimedAgeIsFifteenMinutes() {
        XCTAssertEqual(ComplicationDigest.maximumClaimedAge, 15 * 60)
    }

    /// **Batasnya harus diuji di kedua sisi**, bukan cuma \"lama jadi basi\".
    ///
    /// `isStale` membandingkan `now.timeIntervalSince(updatedAt) >
    /// maximumClaimedAge`. Satu detik di bawah ambang harus tetap segar, dan
    /// satu detik di atasnya harus basi. Tanpa arah sebaliknya, seseorang
    /// bisa menaikkan ambang ke tak-terhingga (complication tidak pernah basi)
    /// atau menurunkannya ke nol (selalu basi) sambil tetap lolos uji
    /// \"90 menit basi\". `now` dikunci supaya selisihnya persis `age` (dua
    /// operasi `addingTimeInterval` berlawanan arah pada basis yang sama
    /// menghasilkan selisih eksak, bebas galat pembulatan).
    func testDigestOneSecondUnderTheLimitIsFresh() {
        XCTAssertFalse(digestAged(ComplicationDigest.maximumClaimedAge - 1).isStale(at: fixedNow))
    }

    func testDigestOneSecondOverTheLimitIsStale() {
        XCTAssertTrue(digestAged(ComplicationDigest.maximumClaimedAge + 1).isStale(at: fixedNow))
    }

    /// Batas persis: pada `age == maximumClaimedAge`, `>` bernilai salah, jadi
    /// bukan basi. Ini yang menjaga arah \"tepat di ambang masih diklaim\".
    func testDigestExactlyAtTheLimitIsNotStale() {
        XCTAssertFalse(digestAged(ComplicationDigest.maximumClaimedAge).isStale(at: fixedNow))
    }

    private let fixedNow = Date()

    private func digestAged(_ age: TimeInterval) -> ComplicationDigest {
        ComplicationDigest(stateRaw: PointingState.lock.rawValue,
                           objectName: "Sirius",
                           objectKindRaw: ObjectKind.star.rawValue,
                           isConfirmed: true,
                           updatedAt: fixedNow.addingTimeInterval(-age))
    }
}
