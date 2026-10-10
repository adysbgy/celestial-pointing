import XCTest
@testable import PointingKit

/// Dua bridge berdiri sendiri: `TextLocalization` memasang **kata**,
/// `NumberFormat` memasang **pemisah angka**. Keduanya milik bahasa yang sama,
/// tapi tidak ada yang mengikatnya — jadi uji boleh memasang kata Inggris
/// tanpa memasang bahasa Inggris, dan hasilnya teks campur:
/// "Ready — spread 2,0° from 3 refs."
///
/// Itu persis kelas cacat yang repo ini hunts — teks dan angka berbeda
/// pendapat — dan ia tidak terlihat dari mana pun: setiap baris hijau
/// sendiri-sendiri. Semua uji yang memasang terjemahan Inggris lewat
/// `installEnglish(_:)` supaya kedua bahasa ikut terpasang.
enum EnglishTranslation {

    /// Pasang terjemahan **dan** bahasa aktif sekaligus.
    ///
    /// Menyatukan dua pemasangan itu disengaja. Kalau hanya kata yang dipasang,
    /// pemisah desimal tetap Bahasa Indonesia dan kalimat yang diuji tidak
    /// pernah muncul — bukan karena katalog salah, tapi karena angka bicara
    /// bahasa lain.
    static func install(_ english: [String: String]) {
        TextLocalization.install { english[$0] }
        NumberFormat.install(localeId: "en_US")
    }
}

/// Basis untuk uji yang memasang bridge: `tearDown` melepas **keduanya**.
///
/// Melepas hanya `TextLocalization` membuat uji berikutnya diam-diam memakai
/// bahasa milik uji sebelumnya — dan kebocoran itu tidak muncul sebagai
/// kegagalan, melainkan sebagai angka yang tiba-tiba memakai pemisah yang
/// salah di berkas lain.
class BridgedTextTestCase: XCTestCase {

    override func setUp() {
        super.setUp()
        TextLocalization.reset()
        NumberFormat.reset()
    }

    override func tearDown() {
        TextLocalization.reset()
        NumberFormat.reset()
        super.tearDown()
    }
}