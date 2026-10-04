import XCTest
import CelestialEngine
@testable import PointingKit

/// Janji "teks layar bukan pengenal mesin" — diuji di Linux.
///
/// Setiap accessor di sini mengerjakan satu hal: mengubah nilai yang
/// **dibuat untuk mesin** (`rawValue`, slug katalog) menjadi teks yang
/// **untuk orang**. Yang dijaga bukan hanya label yang persis, tapi
/// dua sifat yang lebih sulit dijaga dan lebih mudah hilang diam-diam:
///
/// 1. Label tidak pernah **sama dengan** `rawValue`-nya. Kesamaan itu adalah
///    tanda accessor-nya hilang dan pemanggil kembali ke `rawValue` — dan
///    kesamaan itu lolos kompilasi, lolos uji yang hanya mengecek "label ada".
/// 2. Id tak dikenal tidak pernah menghasilkan nama karangan. PRD: jangan
///    tampilkan yang tidak dihitung engine.
final class DisplayLabelTests: XCTestCase {

    private let catalogue = Catalogue.brightStars

    // MARK: - Nama objek

    /// Slug katalog tidak boleh tampil sebagai label utama.
    ///
    /// Ini cacat yang ditemukan siklus ini: baris percobaan di Experiment 1
    /// menampilkan `groundTruthObjectID` apa adanya, jadi headline tiap baris
    /// berbunyi `sirius` di tempat yang seharusnya `Sirius`. Nama bintang
    /// adalah **jawaban yang dicari pengguna** — mengubahnya menjadi slug katalog
    /// menghapus jawaban itu tepat di layar yang seharusnya melaporkannya.
    func testCatalogueIDBecomesTheRealName() {
        XCTAssertEqual(DisplayLabel.objectName(forObjectID: "sirius", catalogue: catalogue),
                       "Sirius")
        XCTAssertEqual(DisplayLabel.objectName(forObjectID: "betelgeuse", catalogue: catalogue),
                       "Betelgeuse")
        XCTAssertEqual(DisplayLabel.objectName(forObjectID: "polaris", catalogue: catalogue),
                       "Polaris")
    }

    /// Setiap slug di katalog punya nama — tidak ada yang jatuh ke jalur
    /// tak dikenal. Ini yang membuat `forEveryCatalogueObject` di bawah
    /// bermakna: kalau katalog bertambah dan satu nama hilang, test ini merah
    /// lebih dulu.
    func testEveryCatalogueIDResolves() {
        for object in catalogue {
            let resolved = DisplayLabel.objectName(forObjectID: object.id, catalogue: catalogue)
            XCTAssertEqual(resolved, object.name,
                           "id katalog \(object.id) tidak punya label nama")
        }
    }

    /// Id tak dikenal **tidak** boleh ditebak menjadi nama.
    ///
    /// Mengarang nama dari id (`"sirius"` → capitalize → `"Sirius"`) akan
    /// terlihat benar untuk seluruh katalog sekarang, dan diam-diam salah
    /// begitu ada id yang tidak mengikuti pola itu. Yang dilarang di sini
    /// adalah persis tebakan itu, jadi id asal harus kembali apa adanya.
    func testUnknownIDReturnsNilRatherThanAGuessedName() {
        XCTAssertNil(DisplayLabel.objectName(forObjectID: "bukan-bintang", catalogue: catalogue))
        XCTAssertNil(DisplayLabel.objectName(forObjectID: "", catalogue: catalogue))
        // Varian yang paling menggoda untuk ditebak: id huruf besar.
        XCTAssertNil(DisplayLabel.objectName(forObjectID: "SIRIUS", catalogue: catalogue))
    }

    /// Benda tata surya: id-nya `EphemerisBody.rawValue`, dan nama
    /// BahasaIndonesianya sudah ada di engine — tidak perlu karangan.
    func testSolarSystemBodyIDUsesTheEngineName() {
        XCTAssertEqual(DisplayLabel.objectName(forObjectID: "jupiter", catalogue: catalogue),
                       "Jupiter")
        XCTAssertEqual(DisplayLabel.objectName(forObjectID: "saturn", catalogue: catalogue),
                       "Saturnus")
        XCTAssertEqual(DisplayLabel.objectName(forObjectID: "moon", catalogue: catalogue),
                       "Bulan")
    }

    /// Nama yang dikembalikan tidak boleh pernah **identik** dengan slug-nya.
    ///
    /// Perhatikan: katalog sengaja menyimpan `name` sebagai slug yang hanya
    /// dib capitalized — `id: "sirius"` dengan `name: "Sirius"`. Jadi
    /// perbandingan **tidak** boleh memakai `lowercased()`: `Sirius` dan
    /// `sirius` akan selalu dianggap sama, dan ujinya jadi tidak mungkin
    /// gagal — persis kelas uji formalitas yang harus dihindari.
    ///
    /// Yang diuji di sini bentuk byte-nya, dan itu memang yang tampil di
    /// layar: label `sirius` berarti accessor hilang dan pemanggil kembali
    /// ke `rawValue`.
    func testNoCatalogueIDIsEverReturnedVerbatimAsItsLabel() {
        for object in catalogue {
            let label = DisplayLabel.objectNameOrIdentifier(forObjectID: object.id,
                                                            catalogue: catalogue)
            XCTAssertNotEqual(label, object.id,
                              "label \(object.id) kembali ke slug-nya sendiri")
            XCTAssertFalse(label.contains("-"),
                           "label \(object.id) masih menyerupai slug: \(label)")
        }
    }

    /// Id tak dikenal tetap tampil sebagai id — sebagai **pengenal teknik**,
    /// bukan sebagai nama. Menampilkan apa adanya jujur; menampilkan string
    /// kosong membuat baris terlihat kosong tanpa penjelasan; nama karangan
    /// adalah kebohongan.
    func testUnknownIDFallsBackToTheIdentifierItself() {
        XCTAssertEqual(
            DisplayLabel.objectNameOrIdentifier(forObjectID: "entitas-asing",
                                                catalogue: catalogue),
            "entitas-asing")
    }

    /// Katalog yang diberikan harus dipakai, bukan katalog bawaan.
    ///
    /// Kalau `catalogue` diabaikan dan selalu dipakai `Catalogue.brightStars`,
    /// label bisa tetap terlihat benar padahal app menjalankan resolver dengan
    /// katalog yang lebih sempit — dan itu tidak akan terlihat dari layar.
    func testOnlyTheGivenCatalogueResolvesIDs() {
        let narrowed = Array(catalogue.prefix(2))
        XCTAssertNil(DisplayLabel.objectName(forObjectID: "polaris", catalogue: narrowed),
                     "id dari katalog yang tidak dipakai tidak boleh punya label")
        XCTAssertEqual(DisplayLabel.objectName(forObjectID: "sirius", catalogue: narrowed),
                       "Sirius")
    }

    // MARK: - Jenis pesan

    /// Tidak satu pun label jenis pesan boleh sama dengan `rawValue`-nya.
    func testNoMessageKindLabelEqualsItsRawValue() {
        for kind in [LinkMessageKind.pointingState, .calibrationReady,
                     .policyUpdate, .stateRequest, .acknowledgement] {
            XCTAssertNotEqual(kind.displayName, kind.rawValue,
                              "\(kind.rawValue) tampil apa adanya sebagai label")
        }
    }

    /// Semua jenis pesan punya label — tidak ada yang jatuh ke string kosong.
    func testEveryMessageKindHasALabel() {
        for kind in [LinkMessageKind.pointingState, .calibrationReady,
                     .policyUpdate, .stateRequest, .acknowledgement] {
            XCTAssertFalse(kind.displayName.isEmpty, "\(kind) tanpa label")
        }
    }

    /// `rawValue` **tidak boleh** berubah: itu kunci serialisasi `plist`.
    ///
    /// Mengganti `rawValue` untuk membuat label lebih enak dibaca adalah cara
    /// termurah untuk "memperbaiki" tampilan, dan cara paling cepat untuk
    /// membuat kedua perangkat tidak bisa bicara. Uji ini menjaga bahwa
    /// perbaikan tampilan tidak pernah menyentuh bentuk kabel.
    func testMessageKindWireValuesAreUnchanged() {
        XCTAssertEqual(LinkMessageKind.pointingState.rawValue, "pointingState")
        XCTAssertEqual(LinkMessageKind.calibrationReady.rawValue, "calibrationReady")
        XCTAssertEqual(LinkMessageKind.policyUpdate.rawValue, "policyUpdate")
        XCTAssertEqual(LinkMessageKind.stateRequest.rawValue, "stateRequest")
        XCTAssertEqual(LinkMessageKind.acknowledgement.rawValue, "acknowledgement")
    }
}
