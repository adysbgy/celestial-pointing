import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Nama objek mengikuti katalog string app (ADR-007): "Saturn" di UI
/// Inggris, "Saturnus" tetap di UI Indonesia, dan tidak pernah kunci mentah.
final class ObjectNameLocalizationTests: XCTestCase {

    override func tearDown() {
        TextLocalization.reset()
        super.tearDown()
    }

    func testBodiesUseTheInstalledCatalog() {
        TextLocalization.install { $0 == "object.name.saturn" ? "Saturn" : nil }
        XCTAssertEqual(EphemerisBody.saturn.displayName, "Saturn")
        XCTAssertEqual(EphemerisBody.moon.displayName, "Bulan", "tanpa terjemahan: Indonesia")
    }

    func testWithoutCatalogNamesStayIndonesian() {
        XCTAssertEqual(EphemerisBody.saturn.displayName, "Saturnus")
        XCTAssertEqual(EphemerisBody.saturn.indonesianName, "Saturnus")
    }

    /// `Bundle.localizedString` mengembalikan kuncinya sendiri bila hilang.
    func testKeyEchoIsNeverShown() {
        TextLocalization.install { $0 }
        XCTAssertEqual(EphemerisBody.jupiter.displayName, "Jupiter")
        XCTAssertEqual(ObjectNameLocalization.name(forObjectID: "m31", indonesian: "Galaksi Andromeda"),
                       "Galaksi Andromeda")
    }

    func testResetRestoresIndonesian() {
        TextLocalization.install { _ in "X" }
        TextLocalization.reset()
        XCTAssertEqual(EphemerisBody.venus.displayName, "Venus")
        XCTAssertEqual(ObjectNameLocalization.name(forObjectID: "m42", indonesian: "Nebula Orion"), "Nebula Orion")
    }

    /// Setiap benda dan objek langit dalam punya kunci di katalog app.
    func testEveryLocalizableObjectHasACatalogEntry() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Apps/Shared/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as! [String: Any]
        let strings = json["strings"] as! [String: Any]
        let ids = EphemerisBody.allCases.map(\.rawValue) + DeepSkyCatalogue.objects.map(\.id)
        for id in ids {
            let entry = try XCTUnwrap(strings[ObjectNameLocalization.key(forObjectID: id)] as? [String: Any], id)
            let loc = try XCTUnwrap(entry["localizations"] as? [String: Any], id)
            XCTAssertNotNil(loc["en"], "\(id) tanpa terjemahan Inggris")
        }
    }
}
