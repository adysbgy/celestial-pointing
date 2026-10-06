import XCTest
import CelestialEngine
@testable import PointingKit

/// Cakupan yang dijelaskan `SearchHint` harus **cuma** benda di dalam kerucut
/// arah tunjuk — bukan seluruh langit.
///
/// **Cacat yang ditutup di sini.** `Resolution.rejected` memang dihitung
/// dengan benar, tapi ia memuat benda yang ditolak penyaring dari **seluruh
/// langit**: `PointingResolver.diagnose` menjalankan `VisibilityFilter` pada
/// setiap benda sebelum memotong kerucut arah tunjuk, jadi daftar penolakan
/// selalu berisi benda dari sisi langit yang lain — yang tidak pernah
/// sengaja ditunjuk pengguna.
///
/// `searchHint` lama membaca **seluruh** daftar itu lalu menyimpulkan
/// `.allBelowHorizon` dari situ. Kalimatnya berbunyi "Semua objek di katalog
/// sedang di bawah horizon" — sebuah klaim yang bisa diperiksa, dan salah.
/// Pengukuran sapu 24 jam x seluruh arah dengan katalog produksi menemukan
/// **2469 dari 2469** resolutions tanpa jawaban menampilkan `.allBelowHorizon`,
/// dan **0** di antaranya benar: setiap saat ada sedikit saja satu bintang
/// katalog yang benar-benar di atas horizon, hanya tidak berada di dalam
/// kerucut arah tunjuk.
///
/// Ini kelas cacat yang berulang di repo ini: bagian-bagiannya benar
/// terpisah (`rejected` benar, kalimatnya benar, pemetaannya benar) dan yang
/// tidak pernah disambungkan adalah **cakupan** yang seharusnya dijaga.
/// Bentuknya misled: jam memberi tahu "semua bintang sedang di bawah
/// horizon" pada langit yang justru paling banyak isinya — lalu pengguna
/// menaikkan tangan, berpikir tidak ada yang bisa dilihat. Persis yang
/// dilarang PRD v0.4.
final class SearchHintConeScopeTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let epoch = Date(timeIntervalSince1970: 1_768_453_200)
    private let cone: Double = 20.0

    private func makeResolver() -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: VisibilityPolicy(),
                         ephemeris: AstronomyKitEphemeris())
    }

    /// Benda katalog yang sedang **terlihat** dan berada di dalam kerucut arah
    /// tunjuk `aim`.
    ///
    /// "Terlihat" di sini berarti melewati ambang yang sama dengan penyaring:
    /// di atas `minAltitudeDeg`. Memakai ambang sendiri berburu-buru akan
    /// membuat pengujian terlalu longgar, dan ambang yang lebih longgar
    /// akan membuat pengujian terlalu ketat — keduanya membuat tes berbohong
    /// tanpa merah.
    private func visibleInCone(resolver: PointingResolver,
                               aim: HorizontalCoord,
                               date: Date) -> [String] {
        let policy = VisibilityPolicy()
        var ids: [String] = []
        for star in Catalogue.brightStars {
            guard let d = resolver.horizontal(of: star, observer: observer, date: date),
                  d.altitudeDeg >= policy.minAltitudeDeg,
                  SkyMath.angularSeparationHorizontalDeg(aim, d) <= cone
            else { continue }
            ids.append(star.id)
        }
        // Pesannya menyebut "objek", bukan "bintang", jadi benda tata surya
        // juga wajib ikut dihitung.
        for body in EphemerisBody.pointableBodies {
            guard let d = try? resolver.horizontal(ofBody: body, observer: observer, date: date),
                  d.altitudeDeg >= policy.minAltitudeDeg,
                  SkyMath.angularSeparationHorizontalDeg(aim, d) <= cone
            else { continue }
            ids.append(body.rawValue)
        }
        return ids
    }

    /// Sapu seluruh langit pada malam hari, menghasilkan semua resolusi yang
    /// tidak punya jawaban.
    private func sweepSkies(resolver: PointingResolver) -> [(aim: HorizontalCoord,
                                                              date: Date,
                                                              resolution: Resolution)] {
        var samples: [(HorizontalCoord, Date, Resolution)] = []
        for hour in stride(from: 0.0, through: 23.0, by: 1.0) {
            let when = epoch.addingTimeInterval(hour * 3600)
            guard resolver.skyContext(observer: observer, date: when).isDark else { continue }
            for alt in stride(from: -10.0, through: 85.0, by: 5.0) {
                for az in stride(from: 0.0, through: 355.0, by: 15.0) {
                    let aim = HorizontalCoord(altitudeDeg: alt, azimuthDeg: az)
                    let r = resolver.diagnose(pointing: aim, observer: observer,
                                              date: when, coneDeg: cone)
                    guard r.intent.best == nil, !r.rejected.isEmpty else { continue }
                    samples.append((aim, when, r))
                }
            }
        }
        return samples
    }

    // MARK: - Prasyarat: fixture-nya memang bisa menghasilkan hint

    /// Fixture ini harus benar-benar menghasilkan `allBelowHorizon`. Kalau
    /// tidak, seluruh tes di bawah hijau karena tidak pernah menguji apa pun —
    /// kelas "hijau yang tidak hijau" yang sudah berulang di repo ini.
    func testFixtureStillProducesBelowHorizonHints() throws {
        let samples = sweepSkies(resolver: makeResolver())
        XCTAssertGreaterThan(samples.count, 1000, "sapu harus benar-benar berjalan")
        XCTAssertGreaterThan(samples.filter { $0.resolution.searchHint == .allBelowHorizon }.count,
                             0,
                             "fixture harus punya minimal satu arah yang isinya di bawah horizon")
    }

    // MARK: - Yang dijaga

    /// **Penjaga utama.** Setiap arah yang kerucutnya **tidak punya benda
    /// yang ditolak sama sekali** harus menampilkan `noCandidates`.
    ///
    /// Inilah penjaga yang benar-benar bisa menggigit, dan alasannya terukur:
    /// di arah seperti itu **tidak ada satu pun benda di dalam kerucut yang
    /// bisa diperiksa** — jadi tidak ada sebab tunggal yang jujur untuk
    /// disebut. Versi lama tetap menampilkan `.allBelowHorizon` karena
    /// membaca benda dari sisi langit yang lain, dan itu klaim yang salah
    /// bentuk. Sapu penuh menemukan **1987 dari 1987** arah seperti itu, dan
    /// **1987** di antaranya salah.
    ///
    /// Syarat di baris kedua adalah penjaga anti-vacuous: kalau penyaringan
    /// kerucut dihapus, `searchHint` kembali membaca seluruh daftar dan nilai
    /// `claimsSpecific` ikut kembali ke 1987 — jadi mutasi itu merah di sini,
    /// bukan hijau di atas kode yang sudah rusak.
    func testConeWithoutAnyRejectionNeverClaimsAReasonForTheWholeSky() throws {
        let resolver = makeResolver()
        var emptyCone = 0
        var claimsSpecific = 0
        var examples: [String] = []

        for (aim, _, r) in sweepSkies(resolver: resolver) {
            let inCone = r.rejected.filter { $0.separationDeg <= cone }
            guard inCone.isEmpty else { continue }
            emptyCone += 1

            // Yang ditampilkan produksi adalah "tidak ada yang cocok".
            if r.searchHint != .noCandidates {
                claimsSpecific += 1
                if examples.count < 5 {
                    examples.append("tampil=\(r.searchHint?.rawValue ?? "nil") "
                        + "alt=\(Int(aim.altitudeDeg))")
                }
            }
        }

        XCTAssertGreaterThan(emptyCone, 0,
                             "fixture harus punya arah tanpa benda di dalam kerucut")
        XCTAssertEqual(claimsSpecific, 0,
                       "arah tanpa benda di kerucut tidak boleh disebut sebab "
                       + "seluruh langit: \(examples)")
    }

    /// `.allBelowHorizon` tidak boleh tampil bersama benda yang **terlihat**
    /// di dalam kerucut arah tunjuk.
    ///
    /// Kejujuran kata "semua" diuji di sini: itu versi yang kalau bocor akan
    /// menampilkan kalimat paling menyesatkan — "semua objek di katalog sedang
    /// di bawah horizon" pada langit yang justru paling banyak isinya.
    ///
    /// Syarat `hints > 0` bukan formalitas. Tanpa itu perbandingan di atas
    /// kosong dan hijau tanpa menguji apa pun; dan nilainya **nol** pada kode
    /// yang benar justru karena penyaringan kerucut bekerja. Itu sebabnya ia
    /// diuji sebagai syarat bahwa hint benar-benar muncul, bukan sebagai
    ///-patokan bahwa kontradiksi harus ada.
    func testAllBelowHorizonNeverCoexistsWithSomethingVisibleInTheCone() throws {
        let resolver = makeResolver()
        var hints = 0
        var contradictions: [String] = []

        for (aim, date, r) in sweepSkies(resolver: resolver) {
            guard r.searchHint == .allBelowHorizon else { continue }
            hints += 1
            let visible = visibleInCone(resolver: resolver, aim: aim, date: date)
            if visible.isEmpty == false {
                contradictions.append("alt=\(Int(aim.altitudeDeg)) terlihat=\(visible)")
            }
        }

        XCTAssertGreaterThan(hints, 0,
                             "fixture harus punya minimal satu hint allBelowHorizon")
        XCTAssertEqual(contradictions.count, 0,
                       "semua di bawah horizon bertentangan dengan benda yang "
                       + "terlihat di kerucut: \(contradictions.prefix(5))")
    }

    /// Kerucut yang **tidak diketahui** tidak boleh dikarang jadi cakupan.
    ///
    /// Resolusi buatan (dibuat tangan di tes, atau hasil serialisasi yang belum
    /// menyimpan kerucut) tidak punya `pointingConeDeg`. Mengasumsikan kerucut
    /// besar akan mengembalikan cacat yang sama lewat pintu lain; satu-satunya
    /// jawaban jujur adalah "tidak ada yang bisa dikatakan".
    func testUnknownConeRefusesToInventAScope() {
        let r = Resolution(
            intent: CelestialIntent(level: .low, best: nil, candidates: []),
            context: SkyContext(sunAltitudeDeg: -40, isDark: true),
            rejected: [
                RejectedObject(
                    object: CelestialObject(id: "a", name: "A", kind: .star,
                                            raDeg: 0, decDeg: 0, magnitude: 5),
                    visibility: .belowHorizon, separationDeg: 3),
                RejectedObject(
                    object: CelestialObject(id: "b", name: "B", kind: .star,
                                            raDeg: 1, decDeg: 1, magnitude: 5),
                    visibility: .belowHorizon, separationDeg: 3)
            ])
        XCTAssertNil(r.pointingConeDeg)
        XCTAssertEqual(r.searchHint, .noCandidates,
                       "kerucut tak diketahui tidak boleh mengarang cakupan")
    }

    /// `diagnose` harus **menyimpan** kerucut yang dipakainya.
    ///
    /// Tanpa ini `searchHint` tidak punya apa pun untuk menyaring dan harus
    /// selalu jatuh ke `noCandidates` — seluruh informasi hilang, bukan
    /// kejujuran yang terjaga. Yang dijaga adalah kesamaan dengan kerucut yang
    /// benar-benar dipakai, bukan angka tetap yang kebetulan cocok.
    func testDiagnoseRecordsTheConeItActuallyUsed() throws {
        let resolver = makeResolver()
        let when = epoch.addingTimeInterval(5 * 3600)
        for coneDeg in [5.0, 20.0, 45.0] {
            let r = resolver.diagnose(pointing: HorizontalCoord(altitudeDeg: 40,
                                                                 azimuthDeg: 90),
                                      observer: observer, date: when, coneDeg: coneDeg)
            XCTAssertEqual(r.pointingConeDeg, coneDeg,
                           "kerucut yang disimpan harus persis yang dipakai")
        }
    }
}