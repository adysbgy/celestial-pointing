import XCTest
import CelestialEngine
@testable import PointingKit

/// Nama objek yang **sudah dirakit engine** harus tetap melewati katalog.
///
/// **Premis, dan apa yang membedakannya dari `LocalizedObjectNameTests`.**
/// Berkas itu membuktikan `DisplayLabel` dan `BodyName` — dua jalur yang
/// **dihitung saat render** dari id mentah. Yang belum pernah diuji adalah
/// jalur yang lebih tua dan lebih langsung: `CelestialObject.name`, field yang
/// diisi **resolver** saat ia mengenali objek, lalu dipakai apa adanya oleh
/// setiap layar (`object.name` di `PointingView`, `ObjectDetailView`,
/// `ReducedLuminanceView`, `DiagnosticsView`, `ComplicationDigest`).
///
/// Dua jalur itu punya **bentuk kegagalan yang berbeda**, dan itulah kenapa
/// berkas ini ada alih-alih menambah satu uji lagi ke berkas itu:
///
/// - kalau `DisplayLabel` lupa melokalkan, hasilnya salah **di semua bahasa
///   sekaligus** (nama Indonesia di layar Inggris), dan `objectName(forObjectID:)`
///   adalah titik tunggal yang bisa dijaga;
/// - kalau `CelestialObject.name` yang tidak dilokalkan, hasilnya salah
///   **hanya di bahasa non-sumber**, dan pemanggilnya lima. Tidak ada satu
///   titik yang bisa menjaganya — kecuali accessor ini, yang dipakai kelima
///   pemanggil itu.
///
/// Jadi uji di bawah bukan duplikat: ia menjaga permukaan yang berbeda.
/// Yang diuji di sini **nilainya** (nama yang benar muncul), bukan sekadar
/// "ada sesuatu yang non-kosong".
final class ObjectDisplayNameTests: XCTestCase {

    private func object(id: String, name: String, kind: ObjectKind) -> CelestialObject {
        CelestialObject(id: id, name: name, kind: kind,
                        raDeg: 101.287, decDeg: -16.716, magnitude: -1.46)
    }

    override func tearDown() {
        // Sumber terjemahan adalah singleton proses: satu uji yang memasang
        // `Lookup` bocor ke semua uji berikutnya, dan kebocoran itu muncul
        // sebagai teks yang "kebetulan benar", bukan sebagai kegagalan.
        TextLocalization.reset()
        NumberFormat.reset()
        super.tearDown()
    }

    // MARK: - Tanpa katalog: persis seperti sebelumnya

    /// Tanpa bridge terpasang, nama harus **sama persis** dengan yang dipasang
    /// resolver. Ini yang membuat perubahan ini aman: di Linux, dan di app
    /// berbahasa Indonesia, tidak ada satu karakter pun yang bergeser.
    func testWithoutInstalledLookupTheNameIsUntouched() {
        let jupiter = object(id: "jupiter", name: "Jupiter", kind: .planet)
        let saturn = object(id: "saturn", name: "Saturnus", kind: .planet)
        let sirius = object(id: "sirius", name: "Sirius", kind: .star)

        XCTAssertEqual(jupiter.localizedName, "Jupiter")
        XCTAssertEqual(saturn.localizedName, "Saturnus")
        XCTAssertEqual(sirius.localizedName, "Sirius")
    }

    /// Objek yang tidak punya baris di katalog harus tetap menampilkan
    /// namanya sendiri — bukan kunci mentah, bukan string kosong.
    func testNameWithNoCatalogEntryFallsBackToTheEngineName() {
        TextLocalization.install { key in
            // Meniru `Bundle.localizedString(forKey:value:)`: kunci yang tidak
            // ada **bukan** `nil`, melainkan nilai `value` yang diberikan.
            key == "object.body.saturn.label" ? "Saturn" : key
        }
        let saturn = object(id: "saturn", name: "Saturnus", kind: .planet)
        XCTAssertEqual(saturn.localizedName, "Saturn")
    }

    // MARK: - Bentuk cacat yang nyata: kata yang terbelah

    /// **Inilah cacatnya.** Resolver mengisi `name` dari katalog engine
    /// (`Catalogue.brightStars`), jadi namanya adalah **kalimat yang sudah
    /// jadi**: `"Bulan Purnama"`, `"Gugus Ptolemy"`, `"Nebula Orion"`. Kalau
    /// pemanggil hanya melokalkan kata **pertama**, sisa kalimatnya tinggal
    /// dalam Bahasa Indonesia di layar Inggris:
    ///
    ///     Moon Purnama
    ///
    /// Itu lebih buruk daripada tidak diterjemahkan sama sekali, karena
    /// separuh baris tampak benar dan tidak ada yang mencarinya.
    func testMultiWordNameDoesNotBecomeHalfTranslated() {
        TextLocalization.install { key in
            key == "object.name.bulan" ? "Moon" : nil
        }
        let fullMoon = object(id: "moon", name: "Bulan Purnama", kind: .moon)
        XCTAssertEqual(fullMoon.localizedName, "Bulan Purnama",
                       "separuh nama diterjemahkan — 'Moon Purnama' di layar")
    }

    // MARK: - Sumber terjemahan yang salah harus ditolak

    /// Bridge yang mengembalikan **kunci itu sendiri** (kontrak
    /// `Bundle.localizedString(forKey:value:)` untuk kunci yang tak dikenal)
    /// tidak boleh membuat pengenal mentah muncul sebagai nama objek.
    func testLookupReturningTheKeyItselfIsRejected() {
        TextLocalization.install { key in key }
        for name in ["Sirius", "Saturnus", "Bulan Purnama", "Gugus Ptolemy"] {
            let body = object(id: "x", name: name, kind: .star)
            XCTAssertEqual(body.localizedName, name,
                           "\(name) tampil sebagai pengenal mentah")
        }
    }

    /// Terjemahan kosong juga ditolak: baris kosong membuat layar tampak
    /// rusak tanpa penjelasan, dan itu lebih buruk daripada kata yang salah.
    func testEmptyTranslationIsRejected() {
        TextLocalization.install { _ in "" }
        let vega = object(id: "vega", name: "Vega", kind: .star)
        XCTAssertEqual(vega.localizedName, "Vega")
    }

    // MARK: - Kunci katalog yang benar-benar ada

    /// Accessor ini hanya berguna kalau kuncinya **ada di katalog**. Uji ini
    /// membaca katalog yang di-commit, jadi ia merah begitu accessor ini
    /// memakai namespace yang belum diterjemahkan.
    ///
    /// **Kenapa `en` wajib dan `id` tidak.** `sourceLanguage` katalog adalah
    /// `id`, jadi bentuk Indonesia untuk kunci `object.body.*` **tidak**
    /// diduplikasi sebagai `localizations.id` — ia hidup satu kali, di
    /// `LocalizedText.id` di dalam paket (`BodyName.declaration`). Menuntut
    /// keduanya di sini akan menuntut setiap nama benda ditulis dua kali, dan
    /// salinan kedua itulah yang akan melenceng. Yang tidak boleh hilang
    /// adalah terjemahan **`en`**: kalau barisnya tidak ada, pembaca Inggris
    /// melihat `Saturnus` — dan itu bentuk cacat yang berkas ini jaga.
    ///
    /// Batas yang dinyatakan: uji ini tidak memeriksa **isi** terjemahannya,
    /// hanya keberadaan dan ketidak-kosongannya. Isi yang salah tapi tidak
    /// kosong adalah kelas yang tidak bisa dilihat dari sini.
    func testEveryBodyKeyUsedByTheAccessorExistsInTheCatalog() throws {
        let catalog = try XCTUnwrap(Self.catalogStrings(),
                                    "Localizable.xcstrings tidak terbaca")
        XCTAssertGreaterThan(catalog.count, 400,
                             "katalog terbaca tetapi hampir kosong — cakupan uji ini bohong")
        for body in EphemerisBody.allCases {
            let key = ObjectDisplayName.catalogKey(forName: body.displayName)
            let entry = try XCTUnwrap(catalog[key],
                                      "\(key) tidak ada di katalog — nama benda "
                                      + "ini akan tampil Bahasa Indonesia di semua bahasa")
            let localizations = entry["localizations"] as? [String: [String: Any]]
            let unit = localizations?["en"]?["stringUnit"] as? [String: Any]
            let value = unit?["value"] as? String
            XCTAssertNotNil(value, "\(key) tanpa terjemahan en")
            XCTAssertFalse(value?.isEmpty ?? true, "\(key) kosong di en")
        }
    }

    /// Nama yang dirakit engine dari **kalimat** juga harus punya barisnya.
    ///
    /// Sembilan kunci `object.body.*` menutup bendera tata surya, tapi
    /// `"Nebula Orion"` dan `"Gugus Ptolemy"` bukan bendera — keduanya frasa
    /// yang dipasang katalog engine, dan **tujuh belas dari delapan belas**
    /// nama objek langit dalam adalah frasa. Kalau kunci `object.name.*` tidak
    /// ada, semuanya tampil Bahasa Indonesia di layar Inggris.
    ///
    /// Uji ini membaca daftar frasa dari **sumber katalog**, bukan daftar
    /// tangan: kalau sebuah objek berganti nama, kunci yang tertinggal jadi
    /// merah di sini alih-alih diam-diam tak terpakai.
    func testPhraseNamesAssembledByTheEngineAlsoHaveRows() throws {
        let catalog = try XCTUnwrap(Self.catalogStrings(),
                                    "Localizable.xcstrings tidak terbaca")
        let phrases = Self.enginePhraseNames()
        XCTAssertGreaterThan(phrases.count, 10,
                             "hanya \(phrases.count) frasa terbaca dari katalog engine "
                             + "— pembacanya rusak, dan uji ini jadi hijau tanpa arti")
        for phrase in phrases {
            let key = ObjectDisplayName.catalogKey(forName: phrase)
            let entry = try XCTUnwrap(catalog[key],
                                      "\(key) tidak ada — \(phrase) tampil Bahasa "
                                      + "Indonesia di layar Inggris")
            let localizations = entry["localizations"] as? [String: [String: Any]]
            let value = (localizations?["en"]?["stringUnit"] as? [String: Any])?["value"] as? String
            XCTAssertNotNil(value, "\(key) tanpa terjemahan en")
            XCTAssertFalse(value?.isEmpty ?? true, "\(key) kosong di en")
        }
    }

    /// Nama multi-kata yang **benar-benar** dirakit engine, dibaca dari kedua
    /// katalog — bukan daftar tangan.
    ///
    /// Sengaja kedua berkas: bintang dan benda tata surya ada di
    /// `CelestialEngine/Catalogue.swift`, objek langit dalam di
    /// `PointingKit/DeepSkyCatalogue.swift`. Membaca hanya satu di antaranya
    /// akan membuat uji ini hijau sambil melewatkan seluruh kelas objek yang
    /// paling banyak memakai nama frasa.
    private static func enginePhraseNames() -> [String] {
        engineNames().filter { $0.contains(" ") }
    }

    /// **Semua** nama yang dirakit engine dari ketiga sumbernya: katalog
    /// bintang, katalog langit dalam, dan `EphemerisBody`.
    ///
    /// Katalog dibaca dengan memangsa literal `name: "..."` dari berkas
    /// sumber. Itu pembacaan yang kasar, jadi keabsahannya dijaga oleh
    /// `XCTAssertGreaterThan` di tiap pemanggil: kalau bentuk berkasnya
    /// berubah dan pembacanya mengembalikan terlalu sedikit, ujinya merah
    /// alih-alih hijau tanpa arti.
    private static func engineNames() -> [String] {
        let sources = [
            "Packages/CelestialEngine/Sources/CelestialEngine/Catalogue.swift",
            "Packages/PointingKit/Sources/PointingKit/DeepSkyCatalogue.swift"
        ]
        var names: [String] = []
        for source in sources {
            var dir = URL(fileURLWithPath: #filePath)
            for _ in 0..<6 {
                dir.deleteLastPathComponent()
                let candidate = dir.appendingPathComponent(source)
                guard let text = try? String(contentsOf: candidate, encoding: .utf8) else {
                    continue
                }
                names += text.components(separatedBy: "name: \"")
                    .dropFirst()
                    .compactMap { $0.components(separatedBy: "\"").first }
                break
            }
        }
        return names + EphemerisBody.allCases.map { $0.displayName }
    }

    /// **`ObjectDisplayName.catalogueKeys` harus persis sama dengan kunci
    /// untuk nama yang perlu diterjemahkan.**
    ///
    /// Daftar itu ada karena gerbang Aturan 19 menuntut setiap kunci katalog
    /// dirujuk oleh literal di kode yang dikirim — kunci yang disusun saat
    /// jalan tidak terlihat oleh gerbang, jadi daftar itu adalah harga yang
    /// dibayar untuk baris katalog yang tidak dianggap yatim. Uji ini yang
    /// membayar sisanya: daftar tangan selalu bisa basi, dan bentuk basi yang
    /// berbahaya adalah **kunci yang hilang** — baris katalog yang sudah
    /// ditulis lalu dilaporkan yatim, sehingga seseorang menghapusnya, dan
    /// namanya kembali Bahasa Indonesia.
    ///
    /// Yang diharapkan adalah nama **non-bintang**: nama bintang adalah nama
    /// baku yang sama di dua bahasa, jadi ia sengaja tidak punya baris katalog.
    /// Kata "non-bintang" di sini bukan tebakan: yang menentukan adalah
    /// `Catalogue.brightStars`, katalog yang sama yang dipakai resolver.
    ///
    /// Jadi ujinya dua arah:
    ///
    /// - setiap nama yang perlu diterjemahkan **punya** kuncinya di daftar;
    /// - tidak ada satu pun kunci di daftar yang **tidak** berasal dari katalog.
    ///
    /// Arah kedua menangkap kunci yang tertinggal setelah sebuah objek
    /// berganti nama — kunci yang akan tetap "dirujuk" oleh daftar, jadi
    /// Aturan 19 tidak akan pernah melihatnya.
    func testDeclaredKeyListMatchesTheEngineCataloguesExactly() {
        let starNames = Set(Catalogue.brightStars.map(\.name))
        let translatable = Self.engineNames().filter { !starNames.contains($0) }
        let expected = Set(translatable.map { ObjectDisplayName.catalogKey(forName: $0) })
        let declared = Set(ObjectDisplayName.catalogueKeys)

        XCTAssertGreaterThan(declared.count, 20,
                             "daftar kunci menyusut — cakupan uji ini bohong")
        XCTAssertGreaterThan(starNames.count, 20,
                             "katalog bintang tidak terbaca — penyaringnya bohong, "
                             + "dan uji ini akan menuntut kunci untuk nama baku")

        let missing = expected.subtracting(declared).sorted()
        XCTAssertTrue(missing.isEmpty,
                      "kunci ini dihitung dari katalog tapi tidak ada di "
                      + "`catalogueKeys`, jadi barisnya dilaporkan yatim oleh "
                      + "Aturan 19: \(missing)")

        let extra = declared.subtracting(expected).sorted()
        XCTAssertTrue(extra.isEmpty,
                      "kunci ini ada di `catalogueKeys` tapi tidak ada objeknya "
                      + "lagi di katalog engine: \(extra)")
    }

    /// Ketujuh kunci itu harus **berbeda** satu sama lain.
    ///
    /// Cacat yang ditutup: accessor yang membangun kunci dari nama katalog dan
    /// lupa menormalkannya akan menghasilkan kunci yang sama untuk dua benda —
    /// dan keduanya lalu menampilkan nama yang sama, tanpa satu pun baris kode
    /// yang terlihat salah.
    func testKeysAreDistinctPerBody() {
        let keys = EphemerisBody.allCases.map {
            ObjectDisplayName.catalogKey(forName: $0.displayName)
        }
        XCTAssertEqual(Set(keys).count, keys.count,
                       "dua benda memakai kunci katalog yang sama: \\(keys)")
    }

    // MARK: - Bentuk kunci

    /// Namespace tanpa spasi, sama seperti seluruh kunci lain di katalog.
    /// Teks sebagai kunci adalah cacat yang sudah pernah dibayar repo ini
    /// (`LocalizedText.rawValue`): `"Saturnus"` menyatu diam-diam dengan
    /// kalimat lain yang kebetulan sama.
    func testKeyIsNamespacedAndHasNoSpaces() {
        for body in EphemerisBody.allCases {
            let key = ObjectDisplayName.catalogKey(forName: body.displayName)
            XCTAssertTrue(key.hasPrefix("object.name."), "\\(key) di luar namespace")
            XCTAssertFalse(key.contains(" "), "\\(key) memuat spasi — itu teks, bukan kunci")
        }
    }

    /// **Cacat yang sebenarnya dicegah berkas ini: kata majemuk kehilangan
    /// spasi di pengenal.** `"Bulan Purnama"` harus menjadi satu kata
    /// (`bulanPurnama`), kalau tidak kuncinya berisi spasi tepat di kasus yang
    /// paling sering muncul di langit — dan pemeriksaan `contains(" ")`
    /// di atas akan hijau pada tujuh benda lalu merah di perangkat.
    func testCompoundNameIsNormalisedToASpacelessIdentifier() {
        XCTAssertEqual(ObjectDisplayName.identifier(forName: "Nebula Orion"),
                       "nebulaOrion")
        XCTAssertEqual(ObjectDisplayName.identifier(forName: "Gugus Ptolemy"),
                       "gugusPtolemy")
        XCTAssertEqual(ObjectDisplayName.identifier(forName: "Sirius"), "sirius")
        // Tanda hubung dan tanda baca lain **memisahkan** kata, bukan hilang
        // begitu saja: `"Kupu-kupu"` adalah dua kata, jadi pengenalunya
        // `kupuKupu`, sama seperti kalau spasi yang dipakai.
        XCTAssertEqual(ObjectDisplayName.identifier(forName: "Gugus Kupu-kupu"),
                       "gugusKupuKupu")
        // Apostrof juga memisahkan — `"Barnard's"` menjadi dua kata. Yang
        // penting bukan bentuk persisnya, melainkan bahwa menambah apostrof
        // tidak menghasilkan kunci yang **berbeda** untuk benda yang sama
        // dengan yang tertulis tanpa apostrof.
        XCTAssertEqual(ObjectDisplayName.identifier(forName: "Barnards Star"),
                       ObjectDisplayName.identifier(forName: "Barnard's Star"),
                       "apostrof mengubah pengenal — katalog menuntut baris kedua "
                       + "untuk benda yang sama")
        // Nama yang dimulai angka: kata tanpa huruf dibuang, supaya tidak ada
        // kunci ber-titik yang terlihat seperti versi lain dari kunci yang
        // sama (`object.name.51` vs `object.name.51.pegasi`).
        XCTAssertEqual(ObjectDisplayName.identifier(forName: "51 Pegasi b"), "pegasiB")
        XCTAssertEqual(ObjectDisplayName.identifier(forName: "Gugus M35"), "gugusM35")
    }

    /// Nama yang **tidak** memuat satu huruf pun tidak boleh menghasilkan kunci
    /// kosong atau `object.name.` dengan ekor hampa — itu kunci yang cocok
    /// dengan apa saja yang jatuh ke fallback yang sama.
    func testNameWithoutLettersFallsBackToAStablePlaceholder() {
        for name in ["42", "  ", "---", "1234"] {
            let identifier = ObjectDisplayName.identifier(forName: name)
            XCTAssertFalse(identifier.isEmpty, "\(name) menghasilkan pengenal kosong")
            XCTAssertFalse(identifier.hasPrefix("."), "\(name) memulai pengenal dengan titik")
        }
        XCTAssertEqual(ObjectDisplayName.identifier(forName: "42"), "unknown")
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
