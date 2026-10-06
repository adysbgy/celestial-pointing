import XCTest
import CelestialEngine
@testable import PointingKit

/// Benda di **bawah horizon** tidak boleh terkunci — dan penolakannya harus
/// jujur, bukan diam.
///
/// **Kenapa tes ini ada, dan kenapa terpisah dari `DaylightLockTests`.**
/// `DaylightLockTests` memang menguji jalur controller sampai `.lock`, tapi ia
/// **sengaja** memilih bintang yang berada *di atas* horizon (altitude > 30°)
/// pada siang hari — supaya penolakannya datang dari `daylight`, bukan dari
/// `belowHorizon`. Jadi celah "arah tunjuk ke benda di bawah horizon tetap
/// menghasilkan `.lock`" tidak tersentuh oleh berkas itu. Ini kelas cacat yang
/// sama dengan yang ditutup `DaylightLockTests`: bagian-bagiannya benar secara
/// terpisah (`VisibilityFilter` menolak `belowHorizon` di level engine), tapi
/// jalur `controller -> .lock -> haptic -> GoTo` belum pernah disambungkan
/// untuk horizon.
///
/// **Yang dijaga.** Sama seperti `DaylightLockTests`, ujinya memutar controller
/// **sungguhan**, bukan resolver: `.lock` adalah satu-satunya keadaan yang
/// memicu haptic sukses, bunyi, pengumuman VoiceOver, visual pengenal, dan izin
/// GoTo. Kalau pelindung horizon bocor di satu lapis antara resolver dan
/// `.lock`, ini yang akan merah — bukan `DaylightLockTests`.
///
/// **Kejujuran, bukan sekadar "tidak terkunci".** Cukup menguji "tidak lock"
/// berarti tes bisa hijau karena alasan yang salah (mis. bintangnya memang
/// tidak bisa dikunci sama sekali). Karena itu tes ini menuntut **dua** hal:
/// (1) arah tunjuk ke benda di bawah horizon tidak pernah `.lock` **dan**
///     `searchHint`-nya `.allBelowHorizon` — penolakannya menjelaskan *kenapa*,
/// (2) arah tunjuk ke **bintang yang sama** saat ia sudah di atas horizon
///     **harus** `.lock` — bukti positif bahwa penolakan tadi spesifik ke
///     horizon, bukan karena bintangnya tidak bisa dikunci.
final class BelowHorizonHonestyTests: XCTestCase {

    /// Pengamat Jakarta (WIB, UTC+7). Sama dengan `DaylightLockTests`.
    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)

    /// Epok acuan: 15 Jan 2026 12:00 WIB = 05:00 UTC. Sama dengan
    /// `DaylightLockTests` supaya pemilihan bintang konsisten dan dapat
    /// diprediksi.
    private let epoch = Date(timeIntervalSince1970: 1_768_453_200)

    private var productionPolicy: VisibilityPolicy { VisibilityPolicy() }

    private func makeResolver(policy: VisibilityPolicy = VisibilityPolicy()) -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: policy,
                         ephemeris: AstronomyKitEphemeris())
    }

    /// Arah tunjuk persis ke target horizontal — salinan dari `DaylightLockTests`
    /// (pemetaan roll=0 sama persis).
    private func quaternion(viewPointingAt target: HorizontalCoord) -> Quaternion {
        let v = LocalFrame.enuFromHorizontal(target)
        let d = Vector3(x: v.y, y: v.z, z: v.x)
        let from = Vector3.unitZ
        let axis = from.cross(d)
        if axis.magnitude < 1e-12 { return .identity }
        let angle = acos(max(-1.0, min(1.0, from.dot(d))))
        return Quaternion.axisAngle(axis: axis, radians: angle)!
    }

    /// Arah tunjuk tepat ke `object` pada waktu `date`, seperti aplikasi.
    private func aim(at object: CelestialObject,
                     date: Date,
                     resolver: PointingResolver) throws -> Quaternion {
        let direction = try XCTUnwrap(
            resolver.horizontal(of: object, observer: observer, date: date),
            "objek \(object.id) harus punya arah horizontal pada waktu ini")
        return quaternion(viewPointingAt: direction)
    }

    private func controller(resolver: PointingResolver) -> PointingController {
        PointingController(resolver: resolver,
                           observer: observer,
                           config: PointingControllerConfig(coneDeg: 20.0))
    }

    /// Tahan arah tunjuk yang sama berulang kali, seperti pergelangan diam.
    private func hold(_ controller: PointingController,
                      quaternion q: Quaternion,
                      since start: Date,
                      steps: Int = 12) {
        for step in 0..<steps {
            controller.feed(quaternion: q,
                            timestamp: start.addingTimeInterval(Double(step) * 0.1))
        }
    }

    // MARK: - Pemilihan sasaran

    /// Cari satu bintang + dua waktu (malam) yang memenuhi keempat syarat.
    ///
    /// 1. **Di bawah horizon** pada `downTime`: altitude ≤ −30° supaya seluruh
    ///    kerucut 20° ikut di bawah ambang (5°), sehingga penolakannya bersih
    ///    `.belowHorizon`, bukan campuran yang jatuh ke `.noCandidates`.
    /// 2. **Langit gelap** pada `downTime` — kalau tidak, penolakannya datang
    ///    dari `daylight`, bukan horizon (persis jebakan `DaylightLockTests`).
    /// 3. **Di atas horizon** pada `upTime` (altitude > 30°) **dan** langit
    ///    gelap — bukti positif bahwa bintang ini *bisa* dikunci.
    /// 4. Keduanya pada tanggal yang sama (pindai ±18 jam dari epok).
    ///
    /// Dipilih dari resolver, bukan ditulis tangan: cap waktu "terlihat benar"
    /// sudah terbukti menyesatkan di `DaylightLockTests`. Kalau tidak ada yang
    /// cocok, berkas ini gagal keras menyebutkan berapa bintang yang diperiksa.
    private func pickTarget() throws -> (star: CelestialObject, downTime: Date, upTime: Date) {
        let resolver = makeResolver()

        var examined = 0
        for object in Catalogue.brightStars {
            var downTime: Date?, upTime: Date?
            for hour in stride(from: -18.0, through: 18.0, by: 1.0) {
                let candidate = epoch.addingTimeInterval(hour * 3600)
                guard resolver.skyContext(observer: observer, date: candidate).isDark,
                      let direction = resolver.horizontal(of: object,
                                                         observer: observer,
                                                         date: candidate)
                else { continue }
                if direction.altitudeDeg <= -30 {
                    downTime = downTime ?? candidate
                } else if direction.altitudeDeg > 30 {
                    upTime = upTime ?? candidate
                }
                if downTime != nil, upTime != nil { break }
            }
            guard downTime != nil, upTime != nil else { continue }
            examined += 1

            // Prasyarat 2 diulang, bukan dipercaya: downTime benar-benar gelap
            // DAN bintangnya benar-benar di bawah horizon.
            let down = try XCTUnwrap(downTime)
            let downDir = try XCTUnwrap(
                resolver.horizontal(of: object, observer: observer, date: down))
            XCTAssertFalse(resolver.skyContext(observer: observer, date: down).isDark == false,
                           "downTime harus gelap")
            XCTAssertLessThan(downDir.altitudeDeg, -25,
                              "\(object.name) harus jauh di bawah horizon pada downTime")
            return (object, down, try XCTUnwrap(upTime))
        }

        XCTFail("tidak ada bintang yang memenuhi syarat horizon pada epok \(epoch); "
                + "diperiksa \(examined) bintang. Fixture berubah dan berkas ini "
                + "tidak lagi menguji apa pun")
        throw XCTSkip("fixture tidak punya sasaran di bawah horizon")
    }

    // MARK: - Yang dijaga

    /// Arah tunjuk ke bintang yang sedang **di bawah horizon** (malam, langit
    /// gelap) tidak boleh menghasilkan `.lock`.
    func testAimAtBelowHorizonStarNeverLocks() throws {
        let picked = try pickTarget()
        let resolver = makeResolver()
        let controller = self.controller(resolver: resolver)

        hold(controller,
             quaternion: try aim(at: picked.star, date: picked.downTime, resolver: resolver),
             since: picked.downTime)

        XCTAssertNotEqual(controller.snapshot.state, .lock,
                          "bintang di bawah horizon tidak boleh terkunci")
    }

    /// Penolakannya harus jujur: `searchHint` menyebut *semua di bawah
    /// horizon*, bukan sekadar "tidak ada kandidat".
    func testBelowHorizonAimExplainsItself() throws {
        let picked = try pickTarget()
        let resolver = makeResolver()
        let controller = self.controller(resolver: resolver)

        hold(controller,
             quaternion: try aim(at: picked.star, date: picked.downTime, resolver: resolver),
             since: picked.downTime)

        let snapshot = controller.snapshot
        XCTAssertNotEqual(snapshot.state, .lock)
        XCTAssertEqual(snapshot.searchHint, .allBelowHorizon,
                       "harus menyalahkan horizon, bukan 'tidak ada kandidat'")
        XCTAssertFalse(controller.hapticLog.contains { $0.event == .lockSucceeded },
                       "tidak boleh ada haptic sukses untuk benda di bawah horizon")
    }

    /// Bukti positif: arah tunjuk ke **bintang yang sama** saat ia sudah di atas
    /// horizon **harus** terkunci. Tanpa ini, "tidak terkunci" bisa berarti
    /// bintangnya memang tidak bisa dikunci, bukan karena horizon.
    func testSameStarLocksWhenAboveHorizon() throws {
        let picked = try pickTarget()
        let resolver = makeResolver()

        // Prasyarat yang diulang: upTime gelap DAN bintangnya tinggi.
        XCTAssertTrue(resolver.skyContext(observer: observer, date: picked.upTime).isDark)
        let upDir = try XCTUnwrap(
            resolver.horizontal(of: picked.star, observer: observer, date: picked.upTime))
        XCTAssertGreaterThan(upDir.altitudeDeg, 30)

        let controller = self.controller(resolver: resolver)
        hold(controller,
             quaternion: try aim(at: picked.star, date: picked.upTime, resolver: resolver),
             since: picked.upTime)

        XCTAssertEqual(controller.snapshot.state, .lock,
                       "bintang di atas horizon harus terkunci; kalau tidak, "
                       + "penolakan bawah-horizon tadi karena alasan lain")
        XCTAssertTrue(controller.hapticLog.contains { $0.event == .lockSucceeded })
    }
}
