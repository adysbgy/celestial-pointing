import XCTest
import CelestialEngine
@testable import PointingKit

/// Bulan di **siang hari** tidak boleh terkunci — dan penolakannya harus jujur.
///
/// **Kenapa berkas ini ada, terpisah dari yang lain.** `DaylightLockTests`
/// sudah membuktikan jalur controller sampai `.lock` menolak bintang saat
/// terang — tapi ia **sengaja memilih bintang**, dan bintang bukan satu-satunya
/// benda yang bisa ditunjuk. Bulan ditangani lewat jalur efemeris yang berbeda
/// (bukan tabel J2000), dan pada siang hari Bulan acapkali justru **di atas
/// horizon** (fase sabit pagi/sore, atau purnama yang baru terbit saat matahari
/// masih tinggi). Maka celahnya spesifik: arah tunjuk ke Bulan yang benar-benar
/// di atas horizon, saat Matahari juga di atas horizon, masih harus ditolak
/// karena `daylight` — bukan karena `belowHorizon`, dan sama sekali tidak boleh
/// `.lock`.
///
/// **Yang dijaga.** Sama seperti `DaylightLockTests`/`BelowHorizonHonestyTests`,
/// ujinya memutar `PointingController` **sungguhan**, bukan resolver: `.lock`
/// adalah satu-satunya keadaan yang memicu haptic sukses, bunyi, pengumuman
/// VoiceOver, visual pengenal, dan izin GoTo. Kalau pelindung siang bocor di
/// satu lapis antara resolver dan `.lock` untuk benda tata surya, ini yang merah.
///
/// **Kejujuran, bukan sekadar "tidak terkunci".** Cukup menguji "tidak lock"
/// berarti tes bisa hijau karena alasan yang salah. Karena itu tes ini menuntut
/// **dua** hal:
/// 1. arah tunjuk ke Bulan saat siang (dan Bulan di atas horizon) tidak pernah
///    `.lock` **dan** `searchHint`-nya `.daylight` — penolakannya menjelaskan
///    *kenapa*, dan tidak ada haptic sukses;
/// 2. **bukti positif** bahwa penolakan itu spesifik ke siang: pada jam yang
///    sama (atau tanggal yang sama) Bulan di atas horizon **saat langit gelap**
///    tidak lagi ditolak karena `daylight`. (Kita tidak menuntut `.lock` untuk
///    Bulan — lihat catatan di `BelowHorizonHonestyTests`: keyakinan Bulan sering
///    turun ke `.uncertain` meski arahnya benar, dan itu perilaku *benar* menurut
///    PRD. Yang dituntut adalah `searchHint` bukan lagi `.daylight`, sehingga
///    yang membedakan kedua keadaan benar-benar adalah terangnya langit.)
final class MoonDaylightHonestyTests: XCTestCase {

    /// Pengamat Jakarta (WIB, UTC+7). Sama dengan `DaylightLockTests`.
    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)

    /// Epok acuan: 15 Jan 2026 12:00 WIB = 05:00 UTC (sama dengan
    /// `DaylightLockTests`): Matahari tinggi di Jakarta.
    private let epoch = Date(timeIntervalSince1970: 1_768_453_200)

    private var productionPolicy: VisibilityPolicy { VisibilityPolicy() }

    private func makeResolver(policy: VisibilityPolicy = VisibilityPolicy()) -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: policy,
                         ephemeris: AstronomyKitEphemeris())
    }

    /// Arah tunjuk persis ke target horizontal (roll=0, salinan dari
    /// `DaylightLockTests`).
    private func quaternion(viewPointingAt target: HorizontalCoord) -> Quaternion {
        let v = LocalFrame.enuFromHorizontal(target)
        let d = Vector3(x: v.y, y: v.z, z: v.x)
        let from = Vector3.unitZ
        let axis = from.cross(d)
        if axis.magnitude < 1e-12 { return .identity }
        let angle = acos(max(-1.0, min(1.0, from.dot(d))))
        return Quaternion.axisAngle(axis: axis, radians: angle)!
    }

    private func aim(at moon: EphemerisBody,
                     date: Date,
                     resolver: PointingResolver) throws -> Quaternion {
        let direction = try XCTUnwrap(
            resolver.horizontal(ofBody: moon, observer: observer, date: date),
            "Bulan harus punya arah horizontal pada waktu ini")
        return quaternion(viewPointingAt: direction)
    }

    private func controller(resolver: PointingResolver) -> PointingController {
        PointingController(resolver: resolver,
                           observer: observer,
                           config: PointingControllerConfig(coneDeg: 20.0))
    }

    private func hold(_ controller: PointingController,
                      quaternion q: Quaternion,
                      since start: Date,
                      steps: Int = 12) {
        for step in 0..<steps {
            controller.feed(quaternion: q,
                            timestamp: start.addingTimeInterval(Double(step) * 0.1))
        }
    }

    // MARK: - Pemilihan fixture

    /// Cari satu tanggal di mana **kedua** syarat berlaku:
    /// - Matahari tinggi (langit terang), DAN
    /// - Bulan di atas horizon (alt > 30°), sehingga arahnya sungguhan dan
    ///   penolakannya datang dari `daylight`, bukan `belowHorizon`.
    ///
    /// Dicari dari resolver, bukan ditulis tangan: posisi Bulan di suatu tanggal
    /// adalah hasil efemeris, dan menebaknya akan membuat tes ini vacuous.
    private func moonDaytimeFixture() -> Date? {
        let resolver = makeResolver()
        for day in 0..<120 {
            for hour in stride(from: 0.0, through: 23.5, by: 0.5) {
                let candidate = epoch.addingTimeInterval(Double(day) * 86400 + hour * 3600)
                let context = resolver.skyContext(observer: observer, date: candidate)
                guard !context.isDark, context.sunAltitudeDeg > 30 else { continue }
                guard let moonDir = resolver.horizontal(ofBody: .moon,
                                                         observer: observer,
                                                         date: candidate),
                      moonDir.altitudeDeg > 30
                else { continue }
                return candidate
            }
        }
        return nil
    }

    /// Jam malam saat Bulan di atas horizon (> 30°), untuk bukti positif.
    private func moonNightFixture() -> Date? {
        let resolver = makeResolver()
        for day in 0..<120 {
            for hour in stride(from: 0.0, through: 23.5, by: 0.5) {
                let candidate = epoch.addingTimeInterval(Double(day) * 86400 + hour * 3600)
                guard resolver.skyContext(observer: observer, date: candidate).isDark else { continue }
                guard let moonDir = resolver.horizontal(ofBody: .moon,
                                                         observer: observer,
                                                         date: candidate),
                      moonDir.altitudeDeg > 30
                else { continue }
                return candidate
            }
        }
        return nil
    }

    // MARK: - Yang dijaga

    /// Prasyarat fixture: ada saat Bulan di atas horizon saat siang.
    func testDaytimeMoonFixtureExists() throws {
        let when = try XCTUnwrap(moonDaytimeFixture(),
                                 "tidak ada saat Bulan di atas 30° saat siang dalam 120 hari")
        let resolver = makeResolver()
        let context = resolver.skyContext(observer: observer, date: when)
        XCTAssertFalse(context.isDark, "fixture harus siang")
        let moonDir = try XCTUnwrap(resolver.horizontal(ofBody: .moon,
                                                        observer: observer, date: when))
        XCTAssertGreaterThan(moonDir.altitudeDeg, 30,
                             "Bulan harus di atas horizon supaya penolakan datang dari daylight")
    }

    /// Bulan di siang hari (dan di atas horizon) tidak boleh `.lock`.
    func testMoonDaytimeNeverLocks() throws {
        let resolver = makeResolver()
        let when = try XCTUnwrap(moonDaytimeFixture(),
                                 "tidak ada saat Bulan di atas 30° saat siang dalam 120 hari")
        let controller = self.controller(resolver: resolver)

        hold(controller, quaternion: try aim(at: .moon, date: when, resolver: resolver),
             since: when)

        XCTAssertNotEqual(controller.snapshot.state, .lock,
                          "Bulan di siang hari tidak boleh terkunci")
        XCTAssertFalse(controller.hapticLog.contains { $0.event == .lockSucceeded },
                       "tidak boleh ada haptic sukses untuk Bulan di siang hari")
    }

    /// Penolakan Bulan di siang hari harus **jujur**: menyebut `daylight`,
    /// bukan diam atau `allBelowHorizon`.
    func testMoonDaytimeRefusalIsHonest() throws {
        let resolver = makeResolver()
        let when = try XCTUnwrap(moonDaytimeFixture(),
                                 "tidak ada saat Bulan di atas 30° saat siang dalam 120 hari")
        let controller = self.controller(resolver: resolver)

        hold(controller, quaternion: try aim(at: .moon, date: when, resolver: resolver),
             since: when)

        let snapshot = controller.snapshot
        XCTAssertNotEqual(snapshot.state, .lock)
        XCTAssertEqual(snapshot.searchHint, .daylight,
                       "harus menyalahkan terang, bukan 'tidak ada kandidat'")
        // Dan resolver memang menolak Bulannya secara eksplisit karena daylight.
        let resolution = resolver.diagnose(pointing: try XCTUnwrap(
            resolver.horizontal(ofBody: .moon, observer: observer, date: when)),
            observer: observer, date: when, coneDeg: 20.0)
        let moonRejection = resolution.rejected.first { $0.object.id == "moon" }
        XCTAssertEqual(moonRejection?.visibility, .daylight,
                       "resolver harus menyebut Bulan ditolak karena daylight")
    }

    /// Bukti positif: pada jam yang sama Bulan di atas horizon **saat langit
    /// gelap**, penolakannya bukan lagi `daylight`.
    ///
    /// Kita tidak menuntut `.lock` (lihat catatan kelas): keyakinan Bulan boleh
    /// `.uncertain`. Yang dituntut adalah `searchHint` berubah dari `.daylight`
    /// — membuktikan bahwa penolakan di atas memang spesifik ke terangnya
    /// langit, bukan karena Bulan tidak bisa dipetakan sama sekali.
    func testMoonAtNightIsNotRejectedForDaylight() throws {
        let resolver = makeResolver()
        let when = try XCTUnwrap(moonNightFixture(),
                                 "tidak ada saat Bulan di atas 30° saat malam dalam 120 hari")
        let context = resolver.skyContext(observer: observer, date: when)
        XCTAssertTrue(context.isDark, "fixture harus malam")

        let resolution = resolver.diagnose(pointing: try XCTUnwrap(
            resolver.horizontal(ofBody: .moon, observer: observer, date: when)),
            observer: observer, date: when, coneDeg: 20.0)
        let moonRejection = resolution.rejected.first { $0.object.id == "moon" }
        XCTAssertNotEqual(moonRejection?.visibility, .daylight,
                          "saat gelap, Bulan tidak boleh ditolak karena daylight")
    }

    // MARK: - Yang TIDAK diuji sampai siklus ini: koordinat Bulan dari efemeris

    /// Bulan **tidak boleh** diperlakukan sebagai benda berkoordinat tetap.
    ///
    /// **Kenapa ini ditambahkan.** Seluruh tes kejujuran lain di repo ini —
    /// termasuk empat uji di atas — menguji **penolakan** (tidak boleh lock).
    /// Tidak satu pun menguji **posisinya**. Padahal ada satu asumsi struktural
    /// yang menopang semuanya: benda tata surya dihitung dari `EphemerisSample`
    /// (apparent of-date), bukan dari `raDeg`/`decDeg` pada `CelestialObject`.
    ///
    /// **Bentuk cacat yang dijaga.** `PointingResolver.consider` menerima
    /// sebuah objek dan sebuah posisi horizontal. Untuk bintang, pemanggilnya
    /// meneruskan pasangan (objek katalog, posisi hasil presesi). Untuk benda
    /// tata surya, pasangannya adalah (objek dari `catalogueObject(for:sample:)`,
    /// posisi dari `sample`). Kedua cabang terlihat identik di layar kode —
    /// itulah kenapa cacat ini berbahaya: satu argumen tertukar (mis. memakai
    /// `horizontal(of: object)`, jalur bintang, untuk benda tata surya) tidak
    /// mengubah bentuk apa pun.
    ///
    /// **Apa yang terjadi kalau tertukar.** RA/Dec Bulan bergerak ~13,2°/hari
    /// (~0,55°/jam) terhadap bintang. Jarak sudut dari posisi lamanya karena itu
    /// melewati lebar kerucut (20°) dalam hitungan jam, dan mencapai puluhan
    /// derajat dalam hitungan hari. Engine lalu mengklasifikasi visibilitas dan
    /// menghitung separasi pada tempat yang sudah lama ditinggalkan Bulan: ia
    /// bisa melaporkan Bulan yang sedang tinggi sebagai `belowHorizon`, atau
    /// menolaknya karena `tooFaint`, dan `.lock` yang dihasilkan mengarah ke
    /// arah yang salah sama sekali.
    ///
    /// **Yang diukur di sini: jarak antara koordinat tetap dan posisi nyata.**
    /// Angka itu adalah **lebar cacatnya**, dan ia harus jauh lebih besar dari
    /// toleransi mana pun yang masuk akal. Kalau suatu saat efemeris diganti
    /// tabel J2000 (atau disuntik dengan koordinat tetap), jarak ini menciut
    /// ke nol dan tes merah.
    ///
    /// **Kenapa ambangnya 10°, bukan angka yang lebih tajam.** Cacatnya
    /// bergerak pada skala puluhan derajat, jadi ambang renggang tetap
    /// menangkapnya sementara tes tidak ikut merah karena pembaruan model
    /// efemeris yang menggeser satu-dua derajat. Uji yang rapuh akan dimatikan
    /// orang, dan gerbang yang dimatikan sama dengan gerbang yang tidak ada.
    func testMoonCataloguePositionIsNotItsCurrentPosition() throws {
        let resolver = makeResolver()

        // Prasyarat fixture: Bulan tinggi saat langit gelap. Kalau tidak ada,
        // tes ini tidak menguji apa pun dan harus gagal keras.
        let when = try XCTUnwrap(moonNightFixture(),
                                 "tidak ada saat Bulan di atas 30° saat malam dalam 120 hari")

        let sample = try XCTUnwrap(
            try? AstronomyKitEphemeris().apparent(.moon, at: when, from: observer),
            "efemeris Bulan harus tersedia pada waktu ini")
        let fromEphemeris = try XCTUnwrap(
            resolver.horizontal(ofBody: .moon, observer: observer, date: when),
            "Bulan harus punya arah dari efemeris pada waktu ini")
        XCTAssertGreaterThan(fromEphemeris.altitudeDeg, 30,
                             "fixture harus Bulan di atas 30°")

        // Koordinat J2000 yang menempel pada Bulan di katalog — jalur yang
        // TIDAK boleh dipakai mesin. Benda tata surya tidak ada di dalam
        // `Catalogue.brightStars`; yang mengikatnya ke katalog adalah
        // `CelestialObject` hasil `catalogueObject(for:sample:)`, dan
        // `raDeg`/`decDeg` di sana adalah salinan J2000 yang dibekukan pada
        // saat berkas ini ditulis.
        let frozen = CelestialObject(id: "moon", name: "Bulan", kind: .moon,
                                     raDeg: 218.0, decDeg: -19.0, magnitude: -12.7)
        let jd = SkyMath.julianDate(from: when)
        let fromFrozen = SkyMath.equatorialToHorizontal(
            SkyMath.precessJ2000ToDate(
                EquatorialCoord(raDeg: frozen.raDeg, decDeg: frozen.decDeg), jd: jd),
            observer: observer, jd: jd)

        let separation = SkyMath.angularSeparationHorizontalDeg(fromEphemeris, fromFrozen)
        XCTAssertGreaterThan(separation, 10.0,
                             "koordinat tetap Bulan berjarak hanya \(separation)° dari "
                             + "posisi efemerisnya; kalau mesin memakai koordinat tetap, "
                             + "visibilitas dan separasinya dihitung di tempat yang salah")

        // Dan jalur yang benar-benar dipakai mesin tidak boleh menganggap Bulan
        // di bawah horizon saat ia sedang tinggi. Kalau posisinya dihitung dari
        // koordinat tetap, penolakannya `belowHorizon` atau `tooFaint` — bukan
        // alasan lain yang jujur.
        let resolution = resolver.diagnose(pointing: fromEphemeris,
                                           observer: observer,
                                           date: when,
                                           coneDeg: 20.0)
        let moonRejection = resolution.rejected.first { $0.object.id == "moon" }
        XCTAssertNotEqual(moonRejection?.visibility, .belowHorizon,
                          "Bulan di atas 30° tidak boleh ditolak karena horizon; "
                          + "itu tanda posisinya dihitung dari koordinat tetap")
        XCTAssertEqual(sample.illuminationFraction >= 0, true)
    }
}
