import XCTest
@testable import PointingKit

/// Gerbang: nilai bawaan preferensi punya **satu** sumber, dan sisi yang tidak
/// bisa dieksekusi di Linux (aksesor `Apps/`) sepakat dengannya.
///
/// Kenapa uji ini tinggal di sini, dan kenapa ia membaca sumber `Apps/`.
/// `AudioCue.isOn` dan `NightMode.isOn` hidup di `Apps/Shared/`, yang **tidak
/// pernah dibangun** `swift-test.sh` di Linux. Nilai bawaannya bisa berubah
/// tanpa satu pun uji di paket ini mengetahuinya — dan `swift-ui-lint.sh`,
/// sampai Aturan 67, hanya menjaga *kunci* preferensinya (`Aturan 57`), bukan
/// nilai bawaannya.
///
/// Terukur sebelum uji ini: `@AppStorage(NightModeStorage.key) ... = false`
/// diganti `= true` di kedua layar, seluruh 66 aturan UI tetap exit 0. App
/// lalu terbuka di palet merah tanpa pernah dipilih.
///
/// Karena itu uji ini membaca **teks** sumber `Apps/`, persis pola
/// `ObservedStateTests` yang menahan properti `@Published` terhadap kenyataan:
/// yang tidak bisa dibangun di sini harus dibaca, bukan dilewati.
final class PreferenceDefaultsTests: XCTestCase {

    private static var appsRoot: URL {
        // `Packages/PointingKit/Tests/PointingKitTests/` -> akar repo.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PointingKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // PointingKit
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // <repo>
            .appendingPathComponent("Apps")
    }

    /// Semua berkas Swift di `Apps/`, rekursif.
    private static func appsSources() -> [(path: String, text: String)] {
        var hasil: [(String, String)] = []
        let root = appsRoot
        guard let walker = FileManager.default.enumerator(at: root,
                                                          includingPropertiesForKeys: nil)
        else { return hasil }
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            hasil.append((url.path, text))
        }
        return hasil.sorted { $0.0 < $1.0 }
    }

    /// Buang komentar supaya docstring yang menyebut `= true` tidak terbaca
    /// sebagai kode. Sama seperti `buang_komentar` di `swift-ui-lint.sh`.
    private static func stripComments(_ text: String) -> String {
        var out = text
        while let start = out.range(of: "/*"),
              let end = out.range(of: "*/", range: start.upperBound..<out.endIndex) {
            out.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return out.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let idx = line.range(of: "//") else { return line }
                return line[line.startIndex..<idx.lowerBound]
            }
            .joined(separator: "\n")
    }

    // MARK: - Model

    func testEveryPreferenceHasADeclaredDefault() {
        // Tidak vacuous: daftar kosong akan membuat semua uji di bawah lulus
        // tanpa mengukur apa pun.
        XCTAssertEqual(PreferenceDefaults.Key.allCases.count, 3,
                       "daftar preferensi menyusut — periksa apakah ini disengaja")
        for key in PreferenceDefaults.Key.allCases {
            let token = PreferenceDefaults.storageToken(for: key)
            XCTAssertFalse(token.isEmpty, "\(key) tidak punya token penyimpanan")
            XCTAssertFalse(PreferenceDefaults.propertyName(for: key).isEmpty,
                           "\(key) tidak punya nama properti")
        }
    }

    func testStorageTokensAreDistinct() {
        let tokens = PreferenceDefaults.Key.allCases.map(PreferenceDefaults.storageToken(for:))
        XCTAssertEqual(Set(tokens).count, tokens.count,
                       "dua preferensi berbagi token penyimpanan")
    }

    /// Nilai bawaan yang **disengaja**, bukan kebetulan.
    ///
    /// Ketiganya ditulis sebagai harapan, bukan dibaca ulang dari model:
    /// uji yang membandingkan `value(for:)` dengan `value(for:)` selalu lulus.
    func testDefaultsAreTheOnesTheProductPromises() {
        XCTAssertFalse(PreferenceDefaults.nightMode,
                       "Mode Malam tidak boleh nyala saat pertama dibuka")
        XCTAssertTrue(PreferenceDefaults.audioCueEnabled,
                      "bunyi kunci adalah aksesibilitas multi-modal: default nyala")
        XCTAssertFalse(PreferenceDefaults.onboardingSeen,
                       "kartu perkenalan harus tampil untuk pengguna baru")
    }

    // MARK: - Sisi yang tidak bisa dieksekusi di Linux

    /// Setiap `@AppStorage` di `Apps/` wajib memakai **token** dan nilai
    /// bawaan yang disebut model — bukan literal.
    ///
    /// Aturan 57 sudah menuntut tokennnya; yang ditambah di sini adalah
    /// sisi nilainya, karena itulah yang terukur lolos.
    func testEveryAppStorageSiteReadsTheDefaultFromTheModel() throws {
        let sources = Self.appsSources()
        XCTAssertFalse(sources.isEmpty, "tidak ada berkas Apps/ terbaca — path salah")

        // `@AppStorage(Token.key) ... = <bawaan>`
        let pola = try NSRegularExpression(
            pattern: #"@AppStorage\s*\(\s*([A-Za-z_]\w*)\.key\s*\)[^=\n]*=\s*([^\n]+)"#)
        var situs = 0
        for (path, text) in sources {
            let kode = Self.stripComments(text)
            let range = NSRange(kode.startIndex..<kode.endIndex, in: kode)
            for match in pola.matches(in: kode, range: range) {
                guard let tokenRange = Range(match.range(at: 1), in: kode),
                      let valueRange = Range(match.range(at: 2), in: kode) else { continue }
                situs += 1
                let token = String(kode[tokenRange])
                let nilai = String(kode[valueRange]).trimmingCharacters(in: .whitespaces)
                let key = PreferenceDefaults.Key.allCases.first {
                    PreferenceDefaults.storageToken(for: $0) == "\(token).key"
                }
                guard let key else {
                    XCTFail("\(path): `\(token).key` tidak terdaftar di PreferenceDefaults")
                    continue
                }
                let diharapkan = "PreferenceDefaults.\(PreferenceDefaults.propertyName(for: key))"
                XCTAssertEqual(nilai, diharapkan,
                               "\(path): nilai bawaan `\(token)` ditulis `\(nilai)`; "
                               + "harus \(diharapkan) supaya satu sumber")
            }
        }
        XCTAssertGreaterThanOrEqual(situs, 5,
                                   "hanya \(situs) situs @AppStorage terbaca — "
                                   + "pola pembacaannya berhenti bekerja")
    }

    /// Aksesor model di `Apps/` harus mengembalikan nilai yang **sama** untuk
    /// kunci yang belum diset.
    ///
    /// Inilah cacat yang terukur: `AudioCue.isOn` membaca `object(forKey:)`
    /// dan mengembalikan `true` bila kunci tidak ada, sementara `@AppStorage`
    /// memakai literal sendiri. Kalau aksesor berubah menjadi `bool(forKey:)`
    /// (yang mengembalikan `false` untuk kunci kosong), toolbar akan menampilkan
    /// "bunyi nyala" sementara `AudioCue` diam — dua jawaban untuk satu fakta.
    func testUnsetKeyAccessorsAgreeWithTheDeclaredDefault() throws {
        let sources = Self.appsSources()
        var diperiksa = 0

        for (path, text) in sources where path.hasSuffix("AudioCue.swift") {
            XCTAssertTrue(Self.stripComments(text).contains("object(forKey: AudioCueStorage.key) == nil"),
                          "\(path): default nyala `AudioCue` bergantung pada cabang "
                          + "`object(forKey:) == nil`; tanpa itu kunci kosong terbaca "
                          + "sebagai false dan bertentangan dengan nilai bawaan model.")
            XCTAssertTrue(PreferenceDefaults.audioCueEnabled,
                          "AudioCue mengembalikan true untuk kunci kosong, "
                          + "jadi bawaan model harus true")
            diperiksa += 1
        }
        for (path, text) in sources where path.hasSuffix("NightMode.swift") {
            let kode = Self.stripComments(text)
            XCTAssertTrue(kode.contains("bool(forKey: NightModeStorage.key)"),
                          "\(path): Mode Malam membaca kunci kosong lewat `bool(forKey:)`")
            XCTAssertFalse(PreferenceDefaults.nightMode,
                           "`bool(forKey:)` mengembalikan false untuk kunci kosong, "
                           + "jadi bawaan model harus false")
            diperiksa += 1
        }

        XCTAssertEqual(diperiksa, 2,
                       "aksesor audio/malam tidak ditemukan — uji ini tidak mengukur apa pun")
    }

    /// Pengguna baru harus **bertemu** kartu perkenalan: bawaan `false` untuk
    /// "sudah dilihat", dan gerbang kartunya membaca `!onboardingSeen`.
    func testOnboardingDefaultMeansANewUserSeesTheCard() {
        XCTAssertFalse(PreferenceDefaults.onboardingSeen)
        // Kontrol: kalau bawaan dibalik, pengguna baru tidak pernah melihatnya.
        XCTAssertTrue(!PreferenceDefaults.onboardingSeen,
                      "gerbang kartu perkenalan membaca `!onboardingSeen`")
    }
}
