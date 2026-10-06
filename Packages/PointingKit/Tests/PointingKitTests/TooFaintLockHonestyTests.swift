import XCTest
import CelestialEngine
@testable import PointingKit

/// Benda yang **terlalu redup untuk dilihat mata** tidak boleh terkunci, dan
/// penolakannya harus jujur.
///
/// **Kenapa tes ini ada.** `BelowHorizonHonestyTests` menutup celah horizon dan
/// `DaylightLockTests` menutup celah siang; keduanya memilih benda dari
/// `Catalogue.brightStars`. Penyaring `tooFaint` punya sifat yang berbeda dan
/// justru karena itu ia lolos dari keduanya: ia tidak pernah muncul di katalog
/// produksi. Bintang paling redup di katalog itu 1.98, sedangkan batas
/// magnitudo paling sempit yang bisaSUNyikan langit (bulan purnama di
/// Zenit) hanya turun ke 4.40 — jadi `mag > limit` mustahil terjadi untuk
/// benda mana pun yang benar-benar ada di `Catalogue.brightStars`.
///
/// Itu **bukan** berarti penyaringnya salah; ia benar dan ia bekerja. Tapi
/// konsekuensinya tidak boleh disembunyikan: karena tidak ada benda produksi
/// yang bisa dipsentuh,\ kode `.tooFaint` di jalur ini belum pernah dieksekusi
/// data nyata. Kalau suatu saat katalog diperluas dengan bintang samar
/// (mis. batas 6.0), jalur itu akan langsung dipakai pengguna — dan bisa jadi
/// berubah karena alasan yang keliru.
///
/// Jadi tes ini memakai **bintang tiruan** pada posisi Sirius dengan
/// magnitudo 6.5: hanya mengubah magnitudo, geometri dan cuplikan cuaca
/// heavens tetap sama, sehingga satu-satunya variabel yang diuji memang
/// penyaring magnitudo. Tujuannya bukan menyalin katalog, melainkan
/// menyalakan satu-satunya jalur yang belum pernah hidup.
///
/// **Yang dijaga.** (1) Arah tunjuk ke bintang redup **tidak pernah** `.lock`
/// dan `searchHint`-nya `.allTooFaint` — menjelaskan kenapa. (2) Bintang
/// tiruan yang sama pada magnitudo terang **harus** `.lock` — bukti positif
/// bahwa penolakan tadi karena kecerahan, bukan karena posisinya atau karena
/// jalurnya memang tidak bisa lock.
final class TooFaintLockHonestyTests: XCTestCase {

    /// Pengamat Jakarta (WIB, UTC+7). Sama dengan dua berkas kejujuran
    /// sebelumnya supaya pola pemilihan waktu bisa dibandingkan.
    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)

    /// Epok acuan: 15 Jan 2026 12:00 WIB = 05:00 UTC.
    private let epoch = Date(timeIntervalSince1970: 1_768_453_200)

    /// Posisi Sirius, magnitudo yang memaksa penyaring `tooFaint`.
    private let faintStar = CelestialObject(id: "tes.faint", name: "Bintang Redup",
                                           kind: .star,
                                           raDeg: 101.28715533, decDeg: -16.71611586,
                                           magnitude: 6.5)

    /// Objek yang sama persis, tapi terang seperti Sirius aslinya.
    private let brightStar = CelestialObject(id: "tes.faint", name: "Bintang Terang",
                                             kind: .star,
                                             raDeg: 101.28715533, decDeg: -16.71611586,
                                             magnitude: -1.46)

    private func quaternion(viewPointingAt target: HorizontalCoord) -> Quaternion {
        let v = LocalFrame.enuFromHorizontal(target)
        let d = Vector3(x: v.y, y: v.z, z: v.x)
        let from = Vector3.unitZ
        let axis = from.cross(d)
        if axis.magnitude < 1e-12 { return .identity }
        let angle = acos(max(-1.0, min(1.0, from.dot(d))))
        return Quaternion.axisAngle(axis: axis, radians: angle)!
    }

    private func controller(for star: CelestialObject) -> PointingController {
        PointingController(
            resolver: PointingResolver(catalogue: [star],
                                      policy: VisibilityPolicy(),
                                      ephemeris: AstronomyKitEphemeris()),
            observer: observer,
            config: PointingControllerConfig(coneDeg: 20.0))
    }

    /// Tahan arah tunjuk yang sama berulang kali, seperti pergelangan diam.
    @discardableResult
    private func hold(_ controller: PointingController,
                      at star: CelestialObject,
                      since start: Date,
                      steps: Int = 12) -> [HapticEvent] {
        var events: [HapticEvent] = []
        for step in 0..<steps {
            events.append(contentsOf: controller.feed(
                quaternion: quaternion(viewPointingAt: aim(at: star, since: start,
                                                          controller: controller)),
                timestamp: start.addingTimeInterval(Double(step) * 0.1)).haptics)
        }
        return events
    }

    private func aim(at star: CelestialObject,
                     since start: Date,
                     controller: PointingController) -> HorizontalCoord {
        // Arah dihitung ulang untuk setiap cuplikan supaya waktu yang dipakai
        //sama dengan cap waktu sampel — persis seperti aplikasi yang
        // mengikuti bintang yang bergerak.
        controller.resolver.horizontal(of: star, observer: observer,
                                       date: start)!
    }

    /// Satu waktu malam yang benar-benar benar-benar `tooFaint`: langit gelap,
    /// bulan di atas cakrawala (menyukut batas magnitudo), bintang tinggi.
    ///
    /// Dicari, **diasumsikan**: kalau tidak ketemu, tes gagal dengan pesan
    /// yang menjelaskan — bukan diam-diam lewat.
    private func findFaintWindow() throws -> Date {
        let resolver = PointingResolver(catalogue: [faintStar],
                                       policy: VisibilityPolicy(),
                                       ephemeris: AstronomyKitEphemeris())
        for day in stride(from: 0.0, through: 59.0, by: 1.0) {
            for hour in stride(from: 0.0, through: 23.0, by: 1.0) {
                let when = epoch.addingTimeInterval(day * 86400 + hour * 3600)
                guard let d = resolver.horizontal(of: faintStar, observer: observer,
                                                  date: when),
                      d.altitudeDeg > 30 else { continue }
                let ctx = resolver.skyContext(observer: observer, date: when)
                guard ctx.isDark,
                      (ctx.moonAltitudeDeg ?? -99) > 0,
                      ctx.moonIlluminationFraction ?? 0 > 0.5 else { continue }
                return when
            }
        }
        XCTFail("tidak ada jendela malam dengan bulan terang di atas cakrawala")
        throw XCTSkip("tidak ada jendela")
    }

    // MARK: - Gerbang

    /// Bintang di bawah batas magnitudo tidak boleh terkunci, dan aplikasi
    /// harus bisa menjelaskan kenapa.
    func testFaintStarNeverLocksAndExplainsItself() throws {
        let when = try findFaintWindow()
        let controller = controller(for: faintStar)
        let events = hold(controller, at: faintStar, since: when)

        let state = controller.snapshot.state
        XCTAssertNotEqual(state, .lock,
                          "bintang di bawah batas magnitudo tidak boleh terkunci")
        XCTAssertEqual(controller.lastResolution?.searchHint, .allTooFaint,
                       "penolakan harus menjelaskan soal kecerahan")
        XCTAssertFalse(events.contains(.lockSucceeded),
                       "tidak boleh ada haptic sukses untuk bintang redup")
    }

    /// Bukti positif: benda yang sama persis, kalau cuma magnitudo yang
    /// diubah, **harus** terkunci. Tanpa ini, tes di atas bisa hijau karena
    /// alasan yang salah.
    func testSamePositionLocksWhenBrightEnough() throws {
        let when = try findFaintWindow()
        let controller = controller(for: brightStar)
        let events = hold(controller, at: brightStar, since: when)

        XCTAssertEqual(controller.snapshot.state, .lock,
                       "bintang terang pada posisi yang sama harus terkunci")
        XCTAssertTrue(events.contains(.lockSucceeded),
                      "harus ada haptic sukses untuk bintang terang")
        XCTAssertNil(controller.lastResolution?.searchHint,
                     "benda yang terkunci tidak boleh punya alasan penolakan")
    }

    /// Katalog produksi **tidak punya** benda yang bisa memicu `tooFaint`.
    ///
    /// Ini bukan cacat: magnitudo paling redup 1.98 masih jauh di atas batas
    /// paling sempit 4.40. Tapi itu sebabnya jalur `tooFaint` tidak pernah
    /// hidup di produksi, dan tes ini menjaga Angka itu tetap_true — kalau
    /// katalog nanti diperluas dengan bintang samar, angka ini yang berubah
    /// lebih dulu dan perlu ditinjau ulang.
    func testProductionCatalogueCannotTriggerTooFaint() {
        let resolver = PointingResolver(catalogue: Catalogue.brightStars,
                                       policy: VisibilityPolicy(),
                                       ephemeris: AstronomyKitEphemeris())
        var faintest = -Double.infinity
        var triggers = 0
        for day in stride(from: 0.0, through: 59.0, by: 1.0) {
            for hour in stride(from: 0.0, through: 23.0, by: 1.0) {
                let when = epoch.addingTimeInterval(day * 86400 + hour * 3600)
                let ctx = resolver.skyContext(observer: observer, date: when)
                let limit = VisibilityFilter.effectiveLimitingMagnitude(context: ctx,
                                                                        policy: VisibilityPolicy())
                for star in Catalogue.brightStars {
                    faintest = max(faintest, star.magnitude)
                    guard let d = resolver.horizontal(of: star, observer: observer,
                                                      date: when),
                          d.altitudeDeg > -5 else { continue }
                    if star.magnitude > limit { triggers += 1 }
                }
            }
        }
        XCTAssertEqual(triggers, 0,
                       "katalog produksi punya \(faintest) sebagai magnitudo paling redup; "
                       + "batas paling sempit yang terukur lebih terang dari itu")
    }
}