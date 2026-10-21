import XCTest
import CelestialEngine
@testable import PointingKit

/// Kalimat yang tampil untuk `.allBelowHorizon` harus menyebut **cakupan yang
/// benar**: benda di dalam kerucut arah tunjuk, bukan seluruh katalog.
///
/// **Cacat yang ditutup di sini.** `SearchHintConeScopeTests` sudah menjaga
/// *keputusan* `searchHint` — ia tidak lagi membaca benda dari sisi langit yang
/// lain. Tapi yang dibaca pengguna bukan enum-nya, melainkan
/// `SearchHint.message`. Kalimatnya masih berbunyi:
///
///     "Semua objek di katalog sedang di bawah horizon."
///
/// dan itu klaim yang **salah** untuk keadaan yang justru memicunya: hint ini
/// hanya muncul bila ada benda **di dalam kerucut** yang ditolak karena di
/// bawah horizon (`SearchHint.swift`, `inCone`). Di luar kerucut, langit bisa
/// penuh bintang yang sedang di atas horizon. Jadi logikanya sudah sempit,
/// kalimatnya masih luas — dan yang dibaca pengguna adalah kalimatnya.
///
/// Ini bentuk cacat yang berulang di repo ini: satu bagian diperbaiki,
/// bagian yang menyampaikan hasilnya ke pengguna tidak ikut, dan tidak ada
/// gerbang yang menghubungkan keduanya. `SearchHintConeScopeTests` menguji
/// enum; tidak ada satu pun tes yang menguji kata "katalog".
///
/// **Kenapa tesnya memeriksa kata, bukan angka.** Cakupan yang salah bentuk
/// hanya bisa dinyatakan dengan kata; tidak ada angka yang bisa dibandingkan.
/// Yang bisa dijaga secara mekanis: kalimat itu tidak boleh mengklaim
/// keseluruhan (`katalog`, `semua objek`, `seluruh langit`). Tes ini sengaja
/// **tidak** mengunci kalimat lengkapnya — kalimat boleh diperbaiki redaksinya
/// kapan saja; yang dikunci adalah tidak kembalinya klaim keseluruhan.
final class SearchHintScopeWordingTests: XCTestCase {

    /// Kata yang menyatakan cakupan **seluruh langit/katalog**.
    ///
    /// Dicocokkan tanpa peduli huruf besar/kecil. Daftar ini sengaja pendek dan
    /// konkret: hanya kata yang benar-benar mengubah arti cakupan.
    ///
    /// **"semua objek" tidak ada di daftar ini** dengan sengaja. "Semua objek
    /// di arah tunjuk sedang di bawah horizon" adalah kalimat yang **benar** —
    /// kuantor "semua" sah selama cakupannya disebut. Yang membuat kalimat lama
    /// salah bukan "semua", melainkan **"di katalog"**: cakupan yang tidak
    /// pernah diperiksa oleh kode yang memutuskan hint ini.
    private let wholeSkyWords = ["katalog", "seluruh langit",
                                 "whole sky", "entire catalogue",
                                 "entire catalog", "the catalogue"]

    /// Kalimat Indonesia bawaan (yang dipakai di Linux, tempat katalog tidak
    /// bisa dibaca — lihat `LocalizedText.indonesian`).
    private func indonesian(_ hint: SearchHint) -> String {
        hint.text.indonesian
    }

    // MARK: - Prasyarat: fixture-nya memang menyentuh hint ini

    /// Kalau `.allBelowHorizon` tidak pernah muncul, seluruh tes di bawah hijau
    /// tanpa menguji apa pun — kelas "hijau yang tidak hijau".
    func testHintUnderTestIsActuallyReachable() throws {
        let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let epoch = Date(timeIntervalSince1970: 1_768_453_200)
        let resolver = PointingResolver(catalogue: Catalogue.brightStars,
                                        policy: VisibilityPolicy(),
                                        ephemeris: AstronomyKitEphemeris())
        var seen: Set<SearchHint> = []
        for hour in stride(from: 0.0, through: 23.0, by: 2.0) {
            let when = epoch.addingTimeInterval(hour * 3600)
            guard resolver.skyContext(observer: observer, date: when).isDark else { continue }
            for alt in stride(from: 0.0, through: 85.0, by: 5.0) {
                for az in stride(from: 0.0, through: 355.0, by: 15.0) {
                    let r = resolver.diagnose(
                        pointing: HorizontalCoord(altitudeDeg: alt, azimuthDeg: az),
                        observer: observer, date: when, coneDeg: 20)
                    if let h = r.searchHint { seen.insert(h) }
                }
            }
        }
        XCTAssertTrue(seen.contains(.allBelowHorizon),
                      "fixture harus benar-benar menghasilkan .allBelowHorizon; "
                      + "yang terlihat: \(seen.map(\.rawValue).sorted())")
    }

    // MARK: - Yang dijaga

    /// **Penjaga utama.** Kalimat `.allBelowHorizon` tidak boleh mengklaim
    /// cakupan seluruh katalog.
    ///
    /// Ini penjaga yang benar-benar bisa menggigit: ia merah pada kalimat lama
    /// ("Semua objek di katalog sedang di bawah horizon.") dan hijau setelah
    /// kalimatnya dibatasi ke kerucut arah tunjuk.
    func testBelowHorizonMessageDoesNotClaimTheWholeCatalogue() {
        let sentence = indonesian(.allBelowHorizon).lowercased()
        let offending = wholeSkyWords.filter { sentence.contains($0) }
        XCTAssertTrue(offending.isEmpty,
                      "kalimat .allBelowHorizon mengklaim cakupan seluruh katalog "
                      + "(\(offending)) padahal hint ini hanya tentang benda di "
                      + "dalam kerucut arah tunjuk: \"\(indonesian(.allBelowHorizon))\"")
    }

    /// Penjaga anti-vacuous: kalimatnya harus benar-benar menyebut **sesuatu**
    /// tentang arah tunjuk. Tanpa ini, menghapus kalimatnya jadi string kosong
    /// akan lolos tes di atas (tidak ada kata terlarang di string kosong).
    func testBelowHorizonMessageStillSaysWhereToLook() {
        let sentence = indonesian(.allBelowHorizon).lowercased()
        let scoped = ["arah", "tunjuk", "kerucut", "sekeliling", "di situ", "sana"]
        XCTAssertTrue(scoped.contains { sentence.contains($0) },
                      "kalimat harus menyebut cakupan sempitnya (arah tunjuk), "
                      + "bukan hanya menghapus kata 'katalog': \"\(indonesian(.allBelowHorizon))\"")
        XCTAssertGreaterThan(indonesian(.allBelowHorizon).count, 15,
                             "kalimat tidak boleh kosong/terlalu pendek")
    }

    /// Kalimat hint lain tidak boleh ikut mengklaim seluruh katalog.
    ///
    /// `.allTooFaint` dan `.allTooCloseToSun` sudah memakai "di arah itu", jadi
    /// tes ini bukan formalitas — ia mengunci bentuk yang benar itu supaya
    /// tidak mundur saat redaksi diubah.
    func testNoSearchHintClaimsTheWholeCatalogue() {
        let all: [SearchHint] = [.daylight, .allBelowHorizon, .allTooFaint,
                                 .allTooCloseToSun, .noCandidates]
        for hint in all {
            let sentence = indonesian(hint).lowercased()
            let offending = wholeSkyWords.filter { sentence.contains($0) }
            XCTAssertTrue(offending.isEmpty,
                          "\(hint.rawValue) mengklaim cakupan seluruh katalog "
                          + "(\(offending)): \"\(indonesian(hint))\"")
        }
    }
}
