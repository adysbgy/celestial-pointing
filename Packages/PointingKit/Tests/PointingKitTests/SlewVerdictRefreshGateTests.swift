import XCTest
@testable import PointingKit

/// Gerbang penyegaran putusan GoTo — kapan putusan lama masih boleh dipakai.
///
/// **Kenapa diuji.** `PointingEngine` menyimpan `SlewDecision` supaya efemeris
/// tidak jalan 20×/detik. Versi pertama membatasi dengan tanda tangan
/// (keadaan, objek) saja, dan itu **membekukan** putusan selama pengguna
/// menahan tunjukan: geometri Matahari & objek terus bergerak, tapi tanda
/// tangannya tidak. Uji di sini menjaga dua jalur yang membuat putusan segar —
/// subjek berubah, **dan** umur habis — karena menghilangkan yang kedua tidak
/// membuat apa pun terlihat salah di layar sampai sebuah penolakan keselamatan
/// diam-diam berubah menjadi izin.
final class SlewVerdictRefreshGateTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// Putusan pertama selalu dihitung: tidak ada yang bisa dipakai lagi.
    func testFirstVerdictAlwaysComputes() {
        let gate = SlewVerdictRefreshGate(maximumAge: 30)
        XCTAssertTrue(gate.needsRecompute(signature: "lock|sirius", at: t0))
    }

    /// Subjek yang sama, masih muda -> tidak dihitung ulang. Inilah yang
    /// menjaga efemeris tetap murah di jalur 20 Hz.
    func testSameSubjectWithinAgeIsReused() {
        var gate = SlewVerdictRefreshGate(maximumAge: 30)
        gate.record(signature: "lock|sirius", at: t0)
        XCTAssertFalse(gate.needsRecompute(signature: "lock|sirius",
                                           at: t0.addingTimeInterval(5)))
        XCTAssertFalse(gate.needsRecompute(signature: "lock|sirius",
                                           at: t0.addingTimeInterval(29.9)))
    }

    /// **Uji inti.** Subjek yang sama, tapi umur habis -> dihitung ulang.
    ///
    /// Inilah cacat yang diperbaiki: tanpa cabang umur, putusan atas geometri
    /// lama dipakai selamanya selama pengguna menahan tunjukan.
    func testSameSubjectIsRecomputedOnceAgeExpires() {
        var gate = SlewVerdictRefreshGate(maximumAge: 30)
        gate.record(signature: "lock|sirius", at: t0)
        XCTAssertTrue(gate.needsRecompute(signature: "lock|sirius",
                                          at: t0.addingTimeInterval(30)))
        XCTAssertTrue(gate.needsRecompute(signature: "lock|sirius",
                                          at: t0.addingTimeInterval(120)))
    }

    /// Subjek berbeda -> langsung dihitung ulang, tanpa menunggu umur.
    func testDifferentSubjectRecomputesImmediately() {
        var gate = SlewVerdictRefreshGate(maximumAge: 30)
        gate.record(signature: "lock|sirius", at: t0)
        XCTAssertTrue(gate.needsRecompute(signature: "lock|vega",
                                          at: t0.addingTimeInterval(0.1)))
        XCTAssertTrue(gate.needsRecompute(signature: "uncertain|sirius",
                                          at: t0.addingTimeInterval(0.1)))
    }

    /// `record` memulai ulang umurnya: putusan yang baru dihitung tidak
    /// langsung dianggap tua.
    func testRecordRestartsTheAge() {
        var gate = SlewVerdictRefreshGate(maximumAge: 30)
        gate.record(signature: "lock|sirius", at: t0)
        // Tepat di ambang: putusan lama sudah tua, jadi harus dihitung ulang.
        let atThreshold = t0.addingTimeInterval(30)
        XCTAssertTrue(gate.needsRecompute(signature: "lock|sirius", at: atThreshold))
        // Setelah putusan baru dicatat, umurnya mulai dari nol lagi.
        gate.record(signature: "lock|sirius", at: atThreshold)
        XCTAssertFalse(gate.needsRecompute(signature: "lock|sirius",
                                           at: atThreshold.addingTimeInterval(1)))
        // Dan kembali tua 30 detik setelah **pencatatan**, bukan setelah
        // putusan pertama.
        XCTAssertTrue(gate.needsRecompute(signature: "lock|sirius",
                                          at: atThreshold.addingTimeInterval(30)))
    }

    /// `reset` membuang putusan tersimpan, jadi yang berikutnya dihitung ulang
    /// apa pun tanda tangannya.
    func testResetForcesRecompute() {
        var gate = SlewVerdictRefreshGate(maximumAge: 30)
        gate.record(signature: "lock|sirius", at: t0)
        gate.reset()
        XCTAssertTrue(gate.needsRecompute(signature: "lock|sirius",
                                          at: t0.addingTimeInterval(1)))
    }

    /// Umur tak-positif berarti "selalu hitung ulang" — gagal-tertutup, dan
    /// bukan cara yang membekukan putusan.
    func testNonPositiveAgeAlwaysRecomputes() {
        var gate = SlewVerdictRefreshGate(maximumAge: 0)
        gate.record(signature: "lock|sirius", at: t0)
        XCTAssertTrue(gate.needsRecompute(signature: "lock|sirius", at: t0))
    }
}
