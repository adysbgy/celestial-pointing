import XCTest
@testable import PointingKit

/// Gerbang: properti `@Published` milik `PointingEngine` harus punya peran yang
/// diputuskan, dan yang tidak dibaca layar tidak boleh memicu render.
///
/// **Kenapa uji ini tinggal di sini, dan kenapa ia membaca sumber `Apps/`.**
/// `PointingEngine` hidup di `Apps/Shared/`, yang **tidak pernah dibangun**
/// `swift-test.sh` dan tidak pernah disentuh satu pun dari 52 aturan UI.
/// Terukur sebelum uji ini: `@Published var sampleCount` — ditulis 20×/detik,
/// dibaca nol layar — bisa dihapus seluruhnya dengan `swift-ui-lint.sh` tetap
/// exit 0. Satu-satunya cara menahannya dari Linux adalah membaca **teks**
/// sumbernya, persis pola `testAllKeysListsEveryDeclaredKey` yang menahan
/// `allKeys` terhadap kenyataan.
final class ObservedStateTests: XCTestCase {

    // MARK: - Aturan murni

    func testBookkeepingPropertiesCannotTriggerRender() {
        for name in ObservedState.mustNotBePublished {
            XCTAssertFalse(ObservedState.canTriggerRender(name),
                           "\(name) adalah pembukuan tapi boleh memicu render")
        }
    }

    func testRenderInputsDoTriggerRender() {
        XCTAssertTrue(ObservedState.canTriggerRender("snapshot"),
                      "snapshot dibaca semua layar; perubahannya wajib memicu render")
        XCTAssertTrue(ObservedState.canTriggerRender("lockArrival"))
    }

    /// Nama tak dikenal harus **diam**, bukan berisik.
    ///
    /// Kalau jawabannya `true`, setiap properti baru otomatis memicu sembilan
    /// redraw per sampel sampai ada yang sadar. Kalau `false`, akibatnya cuma
    /// satu render yang hilang — dan itu **terlihat** saat layarnya diuji
    /// tangan, sementara redraw berlebih tidak terlihat siapa pun.
    func testUnknownPropertyDoesNotTriggerRender() {
        XCTAssertFalse(ObservedState.canTriggerRender("belumAda"))
        XCTAssertFalse(ObservedState.canTriggerRender(""))
    }

    /// `mustNotBePublished` diturunkan dari `roles`, bukan daftar kedua.
    func testMustNotBePublishedIsDerivedFromRoles() {
        let expected = ObservedState.roles
            .filter { $0.value == .bookkeeping }
            .keys
            .sorted()
        XCTAssertEqual(ObservedState.mustNotBePublished, expected)
    }

    // MARK: - Gerbang terhadap sumber `PointingEngine`

    /// Setiap properti `@Published` di `PointingEngine` wajib punya peran.
    ///
    /// Tanpa ini, properti `@Published` baru bisa lahir tanpa ada yang
    /// memutuskan apakah ia boleh memicu render — dan sembilan layar
    /// membayarnya per sampel.
    func testEveryPublishedPropertyHasARole() throws {
        let published = try publishedPropertyNames()
        XCTAssertFalse(published.isEmpty,
                       "sapuan tidak menemukan properti @Published sama sekali — path salah, gerbang vacuum")
        for name in published {
            XCTAssertNotNil(ObservedState.roles[name],
                            "@Published \(name) belum punya peran di ObservedState.roles")
        }
    }

    /// Properti pembukuan **tidak boleh** `@Published`.
    ///
    /// Ini cacat yang diukur: `sampleCount` dinaikkan 20×/detik dan tidak
    /// dibaca layar mana pun, sehingga setiap sampel memicu `objectWillChange`
    /// dua kali untuk seluruh layar teramati — termasuk layar Always-On, yang
    /// justru diminta hemat baterai.
    func testBookkeepingPropertiesAreNotPublished() throws {
        let published = Set(try publishedPropertyNames())
        for name in ObservedState.mustNotBePublished {
            XCTAssertFalse(published.contains(name),
                           "@Published \(name) adalah pembukuan: perubahannya memicu render sembilan layar untuk nilai yang tidak tampil")
        }
    }

    /// Peran yang disebut harus benar-benar ada di sumber.
    ///
    /// Kebalikan dari uji di atas, dan alasannya sama dengan
    /// `allKeys`: daftar yang menyebut properti yang sudah tidak ada akan
    /// terus "hijau" untuk properti yang sudah dihapus, sambil tidak menjagai
    /// apa pun.
    func testRolesMentionOnlyRealProperties() throws {
        let declared = Set(try publishedPropertyNames())
        // `sampleCount` boleh tidak `@Published` (justru itu yang dituntut di
        // atas), jadi yang diperiksa adalah keberadaan **deklarasi**, bukan
        // keberadaannya di antara `@Published`.
        let all = declared.union(try plainPropertyNames())
        for name in ObservedState.roles.keys {
            XCTAssertTrue(all.contains(name),
                          "ObservedState.roles menyebut \(name), tapi PointingEngine tidak punya properti itu")
        }
    }

    // MARK: - Sapuan sumber

    private func engineSource() throws -> String {
        let directory = try XCTUnwrap(sourceDirectory(),
                                      "direktori sumber PointingKit tidak ditemukan")
        // `Packages/PointingKit/Sources/PointingKit` -> `Apps/Shared/PointingEngine.swift`
        let repo = directory
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // PointingKit
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // repo root
        let path = repo.appendingPathComponent("Apps/Shared/PointingEngine.swift")
        return try String(contentsOf: path, encoding: .utf8)
    }

    /// Nama properti yang dideklarasikan dengan `@Published`.
    private func publishedPropertyNames() throws -> [String] {
        try propertyNames(in: engineSource(), prefix: "@Published")
    }

    /// Nama properti `var` yang **tidak** `@Published` — untuk uji keberadaan.
    private func plainPropertyNames() throws -> Set<String> {
        let source = try engineSource()
        let pattern = try NSRegularExpression(
            pattern: #"^\s*(?:public |private |internal |fileprivate )*(?:private\(set\) )?var (\w+)"#,
            options: [.anchorsMatchLines])
        let range = NSRange(source.startIndex..., in: source)
        var names: Set<String> = []
        for match in pattern.matches(in: source, range: range) {
            guard let captured = Range(match.range(at: 1), in: source) else { continue }
            names.insert(String(source[captured]))
        }
        return names
    }

    private func propertyNames(in source: String, prefix: String) throws -> [String] {
        let escaped = NSRegularExpression.escapedPattern(for: prefix)
        let pattern = try NSRegularExpression(
            pattern: #"^\s*"# + escaped + #"\s+(?:public |private |internal |fileprivate )*(?:private\(set\) )?var (\w+)"#,
            options: [.anchorsMatchLines])
        let range = NSRange(source.startIndex..., in: source)
        return pattern.matches(in: source, range: range).compactMap { match in
            guard let captured = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[captured])
        }
    }

    /// Direktori sumber `PointingKit` — pola yang sama dengan
    /// `TextLocalizationTests.sourceDirectory()`.
    private func sourceDirectory() -> URL? {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = url.appendingPathComponent("Sources/PointingKit")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            url = url.deletingLastPathComponent()
        }
        return nil
    }
}
