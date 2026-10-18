import XCTest
@testable import PointingKit

/// Gerbang: layar redup (Always-On) wajib memilih **isi hemat**, bukan layar
/// penuh — dan pemilihan itu harus dinyatakan sebagai nilai, bukan `if` di view.
///
/// **Kenapa uji ini ada.** `NightAwareContainer` dulu memilih isinya dengan
/// `if isLuminanceReduced` di berkas `Apps/`, yang tidak pernah dibangun di
/// Linux. Diukur pada salinan utuh sebelum `AlwaysOnContent` ada: mengganti
/// cabang redup dengan layar penuh, dengan `PointingEngine()` baru, atau dengan
/// `EmptyView()` membuat **seluruh 55 aturan UI lulus (exit 0)**. Artinya
/// FASE A #2 (\"saat redup tampilkan versi sederhana + kontras tinggi, hentikan
/// animasi\") tidak dijaga satu pun gerbang — dan pelanggarannya tidak mungkin
/// terlihat dari layar mana pun, karena layar itu hanya tampil saat
/// pergelangan diturunkan.
final class AlwaysOnContentTests: XCTestCase {

    func testReducedLuminanceSelectsTheReducedContent() {
        XCTAssertEqual(AlwaysOnContent.choose(isLuminanceReduced: true), .reduced,
                       "layar redup memilih layar penuh: animasi dan gestur yang "
                       + "tidak bisa diandalkan kembali ke Always-On")
    }

    func testNormalLuminanceSelectsTheFullContent() {
        XCTAssertEqual(AlwaysOnContent.choose(isLuminanceReduced: false), .full)
    }

    /// Arah sebaliknya, sebagai satu uji: kedua keadaan harus **berbeda**.
    /// Kalau `choose` mengembalikan satu nilai untuk keduanya, dua uji di atas
    /// hanya bisa hijau bersama bila nilai itu benar — uji ini menangkap
    /// pembalikannya.
    func testTheTwoStatesNeverSelectTheSameContent() {
        XCTAssertNotEqual(AlwaysOnContent.choose(isLuminanceReduced: true),
                          AlwaysOnContent.choose(isLuminanceReduced: false))
    }

    /// Isi redup tidak boleh beranimasi. Ini alasan baterai **dan** alasan
    /// kesetiaan pada `MotionPolicy`: watchOS menyegarkan layar redup sekali
    /// per detik, jadi denyut 30 fps di sana tidak pernah terlihat mulus.
    func testReducedContentNeverAllowsMotion() {
        XCTAssertFalse(AlwaysOnContent.reduced.allowsMotion,
                       "isi layar redup mengizinkan animasi: baterai habis untuk "
                       + "frame yang tidak pernah terlihat")
    }

    func testFullContentAllowsMotion() {
        XCTAssertTrue(AlwaysOnContent.full.allowsMotion,
                      "layar penuh tanpa animasi berarti denyut bintang mati "
                      + "di layar yang justru selalu terlihat")
    }
}
