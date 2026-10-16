import XCTest
import CelestialEngine
@testable import PointingKit

/// Objek langit dalam adalah **satu-satunya kelas katalog yang namanya frasa
/// Bahasa Indonesia**, dan nama itu melewati `DisplayLabel.objectName` apa
/// adanya.
///
/// **Cacat yang ditutup berkas ini.** Selama beberapa siklus,
/// `DisplayLabel.objectName(forObjectID:catalogue:)` mengembalikan
/// `match.name` mentah untuk cabang katalog. Itu benar untuk bintang —
/// `Sirius` memang sama di dua bahasa — dan **salah untuk tujuh belas dari
/// delapan belas** nama di `DeepSkyCatalogue`: `Nebula Orion`,
/// `Galaksi Kincir Angin`, `Gugus Sarang Lebah`, `Gugus Kupu-kupu`. Di
/// perangkat berbahasa Inggris pengguna melihat Bahasa Indonesia, dan
/// `DisplayLabelTests` yang ada tidak menangkapnya karena setiap ujinya
/// memakai id bintang, yang namanya kebetulan sama di kedua bahasa.
///
/// **Kenapa lewat `objectName` dan bukan `ObjectDisplayName`.**
/// `ObjectDisplayNameTests` menjaga **accessor**-nya. Berkas ini menjaga
/// **pemanggil**-nya — permukaan yang benar-benar dipakai aplikasi lewat
/// `PointingEngine.displayedObjectName`, dan jalur itu punya langkah kedua
/// (cabang `EphemerisBody`) yang tidak bisa dilihat dari accessor.
final class DeepSkyObjectNameTests: XCTestCase {

    override func tearDown() {
        TextLocalization.reset()
        NumberFormat.reset()
        super.tearDown()
    }

    /// Setiap nama frasa di katalog harus **berganti** saat terjemahan English
    /// terpasang — dan berganti menjadi nilai yang bukan dirinya sendiri.
    ///
    /// Uji ini membaca katalog yang di-commit, jadi ia merah begitu ada nama
    /// baru yang belum punya baris `object.name.*`. Itu memang tujuannya:
    /// objek baru tanpa terjemahan tidak terlihat di mesin pengembang.
    func testEveryDeepSkyPhraseNameIsTranslatedThroughObjectName() throws {
        let catalog = try XCTUnwrap(Self.catalogStrings(),
                                    "Localizable.xcstrings tidak terbaca")
        let objects = DeepSkyCatalogue.objects
        XCTAssertGreaterThan(objects.count, 10,
                             "katalog objek langit dalam mengecil — cakupan uji ini bohong")

        for object in objects {
            let key = ObjectDisplayName.catalogKey(forName: object.name)
            let entry = try XCTUnwrap(catalog[key],
                                      "\(key) tidak ada untuk \(object.name)")
            let localizations = entry["localizations"] as? [String: [String: Any]]
            let english = (localizations?["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            let translated = try XCTUnwrap(english, "\(key) tanpa terjemahan en")

            TextLocalization.reset()
            TextLocalization.install { key in
                key == ObjectDisplayName.catalogKey(forName: object.name) ? translated : nil
            }
            let shown = DisplayLabel.objectName(forObjectID: object.id,
                                                catalogue: DeepSkyCatalogue.objects)
            XCTAssertEqual(shown, translated,
                           "\(object.id) tampil \(shown ?? "nil") — bukan \(translated)")
        }
    }

    /// Tanpa terjemahan terpasang, nama harus **tidak bergeser satu karakter
    /// pun**. Ini yang membuat perubahan ini aman untuk perangkat berbahasa
    /// Indonesia, yang merupakan mayoritas pengguna app ini.
    func testWithoutLookupTheDeepSkyNameIsUnchanged() {
        for object in DeepSkyCatalogue.objects {
            XCTAssertEqual(DisplayLabel.objectName(forObjectID: object.id,
                                                   catalogue: DeepSkyCatalogue.objects),
                           object.name)
        }
    }

    /// Id yang tidak ada di katalog tetap menghasilkan `nil`, bukan nama
    /// karangan — aturan lama yang tidak boleh dilonggarkan oleh perubahan ini.
    func testUnknownIdentifierStillReturnsNil() {
        XCTAssertNil(DisplayLabel.objectName(forObjectID: "bukan-objek",
                                             catalogue: DeepSkyCatalogue.objects))
    }

    /// Cabang `EphemerisBody` **tidak boleh** ikut berubah perilaku.
    ///
    /// `DisplayLabel.objectName` mencoba katalog lebih dulu, lalu benda tata
    /// surya. Karena id benda tata surya (`"jupiter"`) tidak ada di katalog
    /// langit dalam, cabang kedua yang melayani. Kalau perubahan ini tanpa
    /// sengaja membuat cabang pertama cocok untuk id benda, nama planet akan
    /// kembali ke bentuk katalog — dan uji ini yang menangkapnya.
    func testSolarSystemBranchStillGoesThroughBodyName() {
        TextLocalization.install { key in
            key == "object.body.saturn.label" ? "Saturn" : nil
        }
        XCTAssertEqual(DisplayLabel.objectName(forObjectID: "saturn",
                                               catalogue: DeepSkyCatalogue.objects),
                       "Saturn")
    }

    private static func catalogStrings() -> [String: [String: Any]]? {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            dir.deleteLastPathComponent()
            let candidate = dir
                .appendingPathComponent("Apps/Shared/Resources/Localizable.xcstrings")
            if FileManager.default.fileExists(atPath: candidate.path),
               let data = try? Data(contentsOf: candidate),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let strings = root["strings"] as? [String: [String: Any]] {
                return strings
            }
        }
        return nil
    }
}
