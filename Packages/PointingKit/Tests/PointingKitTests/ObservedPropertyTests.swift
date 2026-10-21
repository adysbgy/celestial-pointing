import XCTest
@testable import PointingKit

/// Gerbang: setiap properti `@Published` di `Apps/` punya **peran yang
/// diputuskan**, dan yang tidak boleh `@Published` benar-benar tidak.
///
/// **Kenapa uji ini tinggal di sini, dan kenapa ia membaca sumber `Apps/`.**
/// Satu-satunya `ObservableObject` yang punya gerbang peran semacam ini
/// adalah `PointingEngine` (`ObservedState`, `ObservedStateTests`). Empat objek
/// lain — `MotionLogger`, `LocationProvider`, `WatchLinkService`,
/// `PhoneLinkService`, `ConfidenceTraceStore`, `ExperimentRecorder` — dan
/// semuanya berisi properti `@Published` yang ditulis tiap sampel sensor.
///
/// Terukur, dengan menyapu teks **semua** berkas di `Apps/` dan memutasi satu
/// per satu:
///
///   * `MotionLogger.isRunning` — ditulis di tiga jalur (`start`, `stop`,
///     `handleFailure`), **nol** pembacaan. Menghapusnya seluruhnya, atau
///     membalik `isRunning = false` di `handleFailure` menjadi `true`, membuat
///     sensor mati dilaporkan hidup — seluruh 76 aturan UI,
///     `swift-typecheck.sh`, dan 983 uji paket tetap hijau.
///   * `WatchLinkService.lastPolicyFromPhone` — ditulis saat ambang keyakinan
///     dari iPhone masuk, lalu diteruskan ke `onPolicyReceived`. Nilainya tidak
///     pernah dibaca.
///
/// Keduanya hijau karena kenyataan bahwa tiap keputusan hidup di berkasnya
/// sendiri: tidak ada satu tempat pun yang menuntut setiap `@Published` punya
/// peran. Omong kosongnya bukan soal aturan yang lemah — memang tidak ada
/// aturan untuk kelas ini.
///
/// Polanya sama seperti `PreferenceDefaultsTests`: yang tidak bisa dibangun di
/// Linux harus **dibaca**, bukan dilewati.
final class ObservedPropertyTests: XCTestCase {

    // MARK: - Aturan murni

    func testEventCarrierIsNotRenderInput() {
        // Bukan pernyataan tautologis: keduanya arah yang berbeda dari
        // "properti ini sampai ke layar", dan membedakannya adalah gunanya.
        XCTAssertNotEqual(ObservedProperty.Role.eventCarrier,
                          ObservedProperty.Role.renderInput)
        XCTAssertNotEqual(ObservedProperty.Role.eventCarrier,
                          ObservedProperty.Role.bookkeeping)
    }

    /// Pemilik yang disebut harus punya properti, bukan entri kosong.
    ///
    /// Daftar pemilik kosong akan membuat `role(for:in:)` menjawab `nil`
    /// untuk semua properti owner itu — dan itu tidak bisa dibedakan dari
    /// "peran belum diputuskan" oleh uji mana pun di bawah.
    func testEveryOwnerHasAtLeastOneProperty() {
        for (path, props) in ObservedProperty.roles {
            XCTAssertFalse(props.isEmpty,
                           "\(path) terdaftar sebagai pemilik @Published tapi tidak punya properti")
        }
    }

    /// `bookkeeping` diturunkan dari `roles`, bukan daftar kedua.
    func testBookkeepingIsDerivedFromRoles() {
        let harapan = ObservedProperty.roles
            .flatMap { (path, props) -> [(path: String, name: String)] in
                props.compactMap { (name, role) -> (path: String, name: String)? in
                    role == .bookkeeping ? (path: path, name: name) : nil
                }
            }
            .sorted { (a, b) in a.path == b.path ? a.name < b.name : a.path < b.path }
        XCTAssertEqual(ObservedProperty.bookkeeping.map { "\($0.path):\($0.name)" },
                       harapan.map { "\($0.path):\($0.name)" })
    }

    /// Nama yang tidak dikenal harus **merah**, bukan judul aman.
    func testUnknownPropertyHasNoRole() {
        XCTAssertNil(ObservedProperty.role(for: "belumAda", in: "Apps/Shared/PointingEngine.swift"))
        XCTAssertNil(ObservedProperty.role(for: "snapshot", in: "Apps/Shared/TidakAda.swift"))
    }

    // MARK: - Gerbang terhadap sumber `Apps/`

    /// Setiap properti `@Published` yang benar-benar ada di `Apps/` wajib
    /// punya peran.
    ///
    /// Tanpa ini, properti baru bisa lahir tanpa ada yang memutuskan
    /// perannya — dan objek yang diobservasi layar membayar perubahannya.
    func testEveryPublishedPropertyInAppsHasARole() throws {
        let published = try publishedPropertiesInApps()

        XCTAssertFalse(published.isEmpty,
                       "sapuan tidak menemukan properti @Published di Apps/ — path salah, gate vakum")
        XCTAssertGreaterThanOrEqual(published.count, 25,
                                    "hanya \(published.count) properti @Published terbaca — pola pembacaannya berhenti bekerja")

        for (path, name) in published {
            XCTAssertNotNil(ObservedProperty.role(for: name, in: path),
                            "\(path): `@Published \(name)` belum punya peran di ObservedProperty.roles "
                            + "— properti yang ditulis tiap sampel tanpa peran adalah tepat cuaian yang dijaga di sini")
        }
    }

    /// Peran hanya boleh menyebut properti yang benar-benar ada, **dan** peran
    /// yang menjanjikan saluran render harus benar-benar `@Published`.
    ///
    /// Dua arah, karena satu arah saja hijau pada daftar yang salah:
    ///
    ///   * `renderInput`/`eventCarrier` menjanjikan properti itu **memicu**
    ///     render saat berubah. Kalau ia bukan `@Published`, janji itu bohong:
    ///     layar tidak akan pernah ikut berubah, dan tidak ada galat.
    ///   * `bookkeeping` menjanjikan yang **sebaliknya** — properti itu ada,
    ///     tetapi tidak boleh membayar render. Karena itu ia diperiksa terhadap
    ///     deklarasi `var` biasa, bukan terhadap `@Published`. Memeriksanya
    ///     terhadap `@Published` (versi pertama uji ini) membuat perbaikan yang
    ///     benar — mencabut `@Published` dari `isRunning` — justru **merah**,
    ///     karena peran yang menyebutnya dianggap menggantung.
    ///
    /// Arah kedua tetap ditegakkan `testBookkeepingPropertiesAreNotPublished`;
    /// keduanya bersama berarti "peran bookkeeping = ada, dan tidak
    /// `@Published`", bukan "salah satu".
    func testRenderInputRolesArePublished() throws {
        let published = Set(try propertyNamesInApps(prefix: "@Published")
            .map { "\($0.path)|\($0.name)" })
        let semuaVar = Set(try allVarDeclarationsInApps())
        for (path, props) in ObservedProperty.roles {
            for (name, role) in props {
                let kunci = "\(path)|\(name)"
                switch role {
                case .renderInput, .eventCarrier:
                    XCTAssertTrue(published.contains(kunci),
                                  "\(path): peran `\(role)` untuk `\(name)` menjanjikan saluran render, "
                                  + "tapi properti itu bukan @Published — layar tidak akan ikut berubah, tanpa galat")
                case .bookkeeping:
                    XCTAssertTrue(semuaVar.contains(kunci),
                                  "\(path): ObservedProperty.roles menyebut `\(name)` sebagai pembukuan, "
                                  + "tapi berkas itu tidak punya properti bernama itu")
                    XCTAssertFalse(published.contains(kunci),
                                  "\(path): `\(name)` terdaftar pembukuan tetapi masih @Published — "
                                  + "itulah yang dilarang perannya")
                }
            }
        }
    }

    /// Properti pembukuan **tidak boleh** `@Published`.
    ///
    /// Inilah cacat yang diukur: `MotionLogger.isRunning` ditulis di tiga
    /// jalur dan tidak dibaca satu layar pun, jadi setiap perubahan memicu
    /// `objectWillChange` — untuk objek yang diobservasi `PointingView`,
    /// `CalibrationView`, `ReducedLuminanceView`, dan dokumen aplikasi. Biaya
    /// itu dibayar untuk nilai yang tidak pernah tampil.
    ///
    /// Bedanya dengan `.renderInput` yang salah: cacat ini **terlihat** dari
    /// Linux sebagai sifat properti (`@Published` ada atau tidak), tidak
    /// menuntut layar sungguhan.
    func testBookkeepingPropertiesAreNotPublished() throws {
        let published = Set(try publishedPropertiesInApps().map { "\($0.path)|\($0.name)" })
        XCTAssertFalse(ObservedProperty.bookkeeping.isEmpty,
                       "tidak ada properti pembukuan yang terdaftar — gate ini tidak mengukur apa pun")
        for entry in ObservedProperty.bookkeeping {
            XCTAssertFalse(published.contains("\(entry.path)|\(entry.name)"),
                           "\(entry.path): `@Published \(entry.name)` pembukuan: tiap perubahan memicu render layar untuk nilai yang tidak tampil")
        }
    }

    // MARK: - Sapuan sumber

    /// Semua berkas `.swift` di `Apps/`, rekursif, sebagai (path_repo, teks).
    private func appsSources() -> [(path: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PointingKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // PointingKit
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // <repo>
        let apps = root.appendingPathComponent("Apps")
        var hasil: [(path: String, text: String)] = []
        var alamat: [URL] = [apps]
        while let url = alamat.popLast() {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                // Direktori `.git`-alike tidak ada di `Apps/`, tapi keluarkan
                // yang tersembunyi supaya sapuan tidak masuk cache berkas.
                let isi = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil)) ?? []
                alamat.append(contentsOf: isi.filter { !$0.lastPathComponent.hasPrefix(".") })
            } else if url.pathExtension == "swift" {
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    hasil.append((path: repoRelative(url, root: root), text: text))
                }
            }
        }
        return hasil.sorted { (a, b) in a.path < b.path }
    }

    private func repoRelative(_ url: URL, root: URL) -> String {
        url.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    /// Nama properti `@Published` di semua berkas `Apps/`, sebagai
    /// (path_repo, nama). Mengabaikan komentar supaya docstring yang menyebut
    /// `@Published var x` tidak terbaca sebagai deklarasi.
    private func publishedPropertiesInApps() throws -> [(path: String, name: String)] {
        try propertyNamesInApps(prefix: "@Published")
    }

    /// Semua deklarasi `var` milik properti di `Apps/`, sebagai "path|nama" —
    /// **tanpa** melihat awalan modifier apa pun.
    ///
    /// Dipakai untuk peran `.bookkeeping`: properti itu wajib **ada** (kalau
    /// hilang, perannya menggantung) tetapi wajib tidak `@Published`. Karena itu
    /// yang dituntut bukan nama deklarasinya, melainkan namanya.
    ///
    /// Sengaja hanya menerima `var` di tingkat atas kelas/nilai — biasa
    /// digunakan bersama modifier akses, jadi bentuknya cukup ketat untuk tidak
    /// menerima variabel lokal.
    private func allVarDeclarationsInApps() throws -> Set<String> {
        let pattern = try NSRegularExpression(
            pattern: #"^\s*(?:(?:public|private|internal|fileprivate|package)(?:\((?:set|get)\))?\s+)*var (\w+)\s*(?::|=)"#,
            options: [.anchorsMatchLines])
        var hasil = Set<String>()
        for (path, text) in appsSources() {
            let kode = Self.stripComments(text)
            let range = NSRange(kode.startIndex..<kode.endIndex, in: kode)
            for match in pattern.matches(in: kode, range: range) {
                guard let captured = Range(match.range(at: 1), in: kode) else { continue }
                hasil.insert("\(path)|\(String(kode[captured]))")
            }
        }
        return hasil
    }

    private func propertyNamesInApps(prefix: String) throws -> [(path: String, name: String)] {
        let escaped = NSRegularExpression.escapedPattern(for: prefix)
        // Modifier akses boleh membawa pembatas akses **menempel** pada katanya:
        // `private(set) var`, bukan `private (set) var`. Versi pertama pola ini
        // hanya mengenal `private ` (dengan spasi), jadi setiap deklarasi
        // berbentuk `public private(set) var` — yaitu **26 dari 28** properti
        // `@Published` di `Apps/` — terlewat, dan yang terbaca hanya dua
        // (`public var note`, `public var selectedTargetID`). Gerbangnya lalu
        // hijau karena hampir tidak ada yang diperiksa.
        //
        // Itu bukan kemungkinan: terukur pada siklus ini, gerbang melaporkan
        // "hanya 2 properti @Published terbaca". Ambang `>= 25` di uji
        // pemanggil yang menangkapnya — bukan pemeriksaan peran, yang tidak
        // punya apa pun untuk diperiksa saat daftarnya kosong.
        let pattern = try NSRegularExpression(
            pattern: #"^\s*"# + escaped
                + #"\s+(?:(?:public|private|internal|fileprivate|package)(?:\((?:set|get)\))?\s+)*var (\w+)\s*(?::|=)"#,
            options: [.anchorsMatchLines])
        var hasil: [(path: String, name: String)] = []
        for (path, text) in appsSources() {
            let kode = Self.stripComments(text)
            let range = NSRange(kode.startIndex..<kode.endIndex, in: kode)
            for match in pattern.matches(in: kode, range: range) {
                guard let captured = Range(match.range(at: 1), in: kode) else { continue }
                hasil.append((path: path, name: String(kode[captured])))
            }
        }
        return hasil
    }

    /// Buang komentar, sama seperti `buang_komentar` di `swift-ui-lint.sh`.
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
}
