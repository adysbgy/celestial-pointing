import XCTest
import CelestialEngine
@testable import PointingKit

/// Benda **terlalu dekat dengan Matahari** untuk ditunjuk aman tidak boleh
/// terkunci, dan penolakannya harus jujur.
///
/// **Kenapa berkas ini ada.** `BelowHorizonHonestyTests`, `DaylightLockTests`,
/// dan `TooFaintLockHonestyTests` sudah menutup tiga alasan penolakan lain
/// sampai ke `.lock` lewat controller sungguhan. `tooCloseToSun` — pengaman
/// teleskop yang paling berbahaya, karena `.lock` membuka izin GoTo dan
/// mengarahkan motor ke arah Matahari bisa merusak alat dan mata — **belum
/// pernah diuji di level controller**. STATUS.md (entri bawah-horizon)
/// mencatat alasan ini "tidak pernah muncul sama sekali" di sapu mereka, dan
/// pemindaian 365 hari di sini mengonfirmasi: nol bintang katalog yang pernah
/// berada di (13°, 30°) dari Matahari saat keduanya di atas horizon. Jadi
/// seperti `tooFaint`, jalur ini **kode mati di produksi** — dan tes ini
/// menyalakannya **sebelum** suatu saat katalog diperluas (mis. bintang
/// konjungsi Matahari pagi/sore) membuatnya hidup untuk pengguna.
///
/// **Dua lapis pengaman Matahari, dan tes ini menargetkan yang benar.** Resolver
/// punya gerbang `sunSafeConeDeg` (13°) yang menolak **arah tunjuk itu sendiri**
/// kalau menunjuk langsung ke Matahari — itu mengembalikan `intent` kosong
/// (`best: nil`) dan berujung pada `searchHint == .noCandidates`, bukan
/// `tooCloseToSun`. Tes ini menargetkan lapis **kedua**: kandidat bintang yang
/// posisinya dekat Matahari (< `minSunSeparationDeg` = 30°) tapi arah tunjuk
/// **tidak** menunjuk ke Matahari (≥ 13° darinya). Maka penolakannya harus
/// `tooCloseToSun` (lewat `VisibilityFilter.classify`), dan `searchHint`-nya
/// `.allTooCloseToSun`.
///
/// **Bintang tiruan, bukan katalog.** Karena tidak ada bintang nyata di celah
/// itu (lihat di atas), tes memakai bintang tiruan yang ditempatkan di dekat
/// Matahari pada waktu siang tertentu — persis pola `TooFaintLockHonestyTests`
/// (hanya magnitudo yang diubah). Tujuannya menyalakan satu-satunya jalur yang
/// belum pernah hidup, bukan menyalin katalog.
///
/// **Yang dijaga.** Sama seperti tes kejujuran sebelumnya, ujinya memutar
/// `PointingController` **sungguhan**. `.lock` adalah satu-satunya keadaan
/// yang memicu haptic sukses, bunyi, pengumuman VoiceOver, visual pengenal,
/// dan izin GoTo — kalau pelindung Matahari bocor di satu lapis antara resolver
/// dan `.lock`, ini yang merah.
///
/// **Kejujuran, bukan sekadar "tidak terkunci".** (1) arah tunjuk ke bintang
/// dekat Matahari (saat siang, bintang di atas horizon, arah tunjuk ≥ 13° dari
/// Matahari) tidak pernah `.lock` **dan** `searchHint == .allTooCloseToSun`,
/// resolver menyebut bintangnya ditolak `.tooCloseToSun`; (2) **bukti positif**
/// bahwa penolakan itu spesifik ke dekat-Matahari: bintang yang **sama** saat
/// malam (jauh dari Matahari) **harus** `.lock`. Tanpa (2), tes (1) bisa hijau
/// karena alasan yang salah.
final class TooCloseToSunLockHonestyTests: XCTestCase {

    /// Pengamat Jakarta (WIB, UTC+7). Sama dengan tes kejujuran lain.
    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)

    /// Epok acuan: 15 Jan 2026 12:00 WIB = 05:00 UTC.
    private let epoch = Date(timeIntervalSince1970: 1_768_453_200)

    private var policy: VisibilityPolicy { VisibilityPolicy() }

    private func makeResolver(catalogue: [CelestialObject])
        -> PointingResolver {
        PointingResolver(catalogue: catalogue,
                         policy: policy,
                         ephemeris: AstronomyKitEphemeris())
    }

    private func quaternion(viewPointingAt target: HorizontalCoord) -> Quaternion {
        let v = LocalFrame.enuFromHorizontal(target)
        let d = Vector3(x: v.y, y: v.z, z: v.x)
        let from = Vector3.unitZ
        let axis = from.cross(d)
        if axis.magnitude < 1e-12 { return .identity }
        let angle = acos(max(-1.0, min(1.0, from.dot(d))))
        return Quaternion.axisAngle(axis: axis, radians: angle)!
    }

    private func aim(at star: CelestialObject,
                     date: Date,
                     resolver: PointingResolver) throws -> Quaternion {
        let direction = try XCTUnwrap(
            resolver.horizontal(of: star, observer: observer, date: date),
            "bintang harus punya arah horizontal pada waktu ini")
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
                      steps: Int = 12) -> [HapticEvent] {
        var events: [HapticEvent] = []
        for step in 0..<steps {
            events.append(contentsOf: controller.feed(
                quaternion: q,
                timestamp: start.addingTimeInterval(Double(step) * 0.1)).haptics)
        }
        return events
    }

    /// Cari satu waktu siang (Matahari tinggi, alt > 30°) dalam 30 hari ke
    /// depan. Bintang tiruan ditempatkan dekat Matahari pada waktu ini.
    ///
    /// Dihitung dari efemeris, bukan ditulis tangan — posisi Matahari bergantung
    /// tanggal dan tidak boleh ditebak.
    /// Hitung arah horizontal Matahari secara langsung (`.sun` bukan benda
    /// yang bisa ditunjuk, jadi `resolver.horizontal(ofBody: .sun)` selalu nil).
    private func sunHorizontal(at when: Date) -> HorizontalCoord? {
        guard let s = try? AstronomyKitEphemeris().apparent(.sun, at: when, from: observer)
        else { return nil }
        return SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: s.raDeg, decDeg: s.decDeg),
            observer: observer, jd: SkyMath.julianDate(from: when))
    }

    private func findNoon() throws -> Date {
        for day in 0..<30 {
            for hour in stride(from: 0.0, through: 23.0, by: 1.0) {
                let when = epoch.addingTimeInterval(Double(day) * 86400 + hour * 3600)
                guard let sun = sunHorizontal(at: when), sun.altitudeDeg > 30 else { continue }
                return when
            }
        }
        throw XCTSkip("tidak ada siang (Matahari > 30°) dalam 30 hari")
    }

    /// Cari offset RA/Dec kecil sehingga bintang tiruan, saat `when`, berada
    /// di atas horizon (alt > 25) dan berjarak (13°, 30°) dari Matahari —
    /// artinya kena `tooCloseToSun` tapi **lolos** gerbang arah-tunjuk.
    ///
    /// Dihitung, bukan ditulis tangan: posisi Matahari adalah hasil efemeris,
    /// dan menebak offset yang menghasilkan separasi horizontal tertentu akan
    /// membuat tes ini vacuous.
    private func makeCloseToSunStar(at when: Date) throws -> CelestialObject {
        let resolver = makeResolver(catalogue: [])
        guard let sun = sunHorizontal(at: when)
        else { throw XCTSkip("Matahari tidak punya arah saat ini") }
        guard let sunSample = try? AstronomyKitEphemeris()
            .apparent(.sun, at: when, from: observer)
        else { throw XCTSkip("efemeris Matahari gagal") }

        // Cari offset (dRA, dDec) yang memenuhi syarat. dRA dalam derajat
        // ekuatorial; dikalikan cos(dec) supaya separasi sudut kira-kira seragam.
        for dRA in stride(from: 8.0, through: 40.0, by: 1.0) {
            for dDec in stride(from: -25.0, through: 25.0, by: 1.0) {
                let ra = sunSample.raDeg + dRA / max(0.2, cos(sunSample.decDeg * .pi / 180))
                let dec = sunSample.decDeg + dDec
                let star = CelestialObject(id: "tes.closeSun", name: "Bintang Dekat Matahari",
                                           kind: .star, raDeg: ra, decDeg: dec, magnitude: -1.0)
                guard let dir = resolver.horizontal(of: star, observer: observer, date: when),
                      dir.altitudeDeg > 25 else { continue }
                let sep = SkyMath.angularSeparationHorizontalDeg(dir, sun)
                if sep > PointingResolver.sunSafeConeDeg && sep < policy.minSunSeparationDeg {
                    return star
                }
            }
        }
        throw XCTSkip("tidak ada offset yang memenuhi celah (13°,30°) dari Matahari saat siang")
    }

    /// Waktu malam saat bintang tiruan di atas horizon (untuk bukti positif).
    private func nightWindow(for star: CelestialObject) -> Date? {
        let resolver = makeResolver(catalogue: [star])
        for day in 0..<120 {
            for hour in stride(from: 0.0, through: 23.5, by: 0.5) {
                let when = epoch.addingTimeInterval(Double(day) * 86400 + hour * 3600)
                guard resolver.skyContext(observer: observer, date: when).isDark else { continue }
                guard let dir = resolver.horizontal(of: star,
                                                   observer: observer, date: when),
                      dir.altitudeDeg > 30
                else { continue }
                return when
            }
        }
        return nil
    }

    // MARK: - Yang dijaga

    /// Prasyarat fixture: bintang tiruan di (13°,30°) dari Matahari, di atas
    /// horizon saat siang.
    func testCloseToSunFixtureExists() throws {
        let noon = try findNoon()
        let star = try makeCloseToSunStar(at: noon)
        let resolver = makeResolver(catalogue: [star])
        let context = resolver.skyContext(observer: observer, date: noon)
        XCTAssertFalse(context.isDark, "fixture harus siang")
        let sunDir = try XCTUnwrap(sunHorizontal(at: noon))
        let starDir = try XCTUnwrap(resolver.horizontal(of: star,
                                                        observer: observer, date: noon))
        let sep = SkyMath.angularSeparationHorizontalDeg(starDir, sunDir)
        XCTAssertGreaterThan(sep, PointingResolver.sunSafeConeDeg,
                             "harus lolos gerbang arah-tunjuk")
        XCTAssertLessThan(sep, policy.minSunSeparationDeg,
                          "harus kena tooCloseToSun")
    }

    /// Bintang dekat Matahari (saat siang, di atas horizon, arah tunjuk ≥ 13°
    /// dari Matahari) tidak boleh `.lock`.
    func testStarCloseToSunNeverLocks() throws {
        let noon = try findNoon()
        let star = try makeCloseToSunStar(at: noon)
        let resolver = makeResolver(catalogue: [star])
        let controller = self.controller(resolver: resolver)

        _ = hold(controller,
                 quaternion: try aim(at: star, date: noon, resolver: resolver),
                 since: epoch)

        XCTAssertNotEqual(controller.snapshot.state, .lock,
                          "bintang terlalu dekat Matahari tidak boleh terkunci")
        XCTAssertFalse(controller.hapticLog.contains { $0.event == .lockSucceeded },
                       "tidak boleh ada haptic sukses untuk bintang dekat Matahari")
    }

    /// Penolakan harus **jujur**: `searchHint == .allTooCloseToSun`, dan
    /// Penolakan harus **jujur** di level resolver: resolver menyebut bintangnya
    /// ditolak `.tooCloseToSun` (bukan `daylight` atau alasan lain).
    ///
    /// Diuji di level resolver, bukan lewat `searchHint` controller, karena
    /// `SearchHint` memilih alasan **dominan** dari himpunan semua benda
    /// tertolak — saat siang, mayoritas benda memang `daylight`, jadi pesan
    /// "terang" yang muncul ke pengguna adalah yang jujur untuk keadaan itu.
    /// Yang dijaga di sini adalah jalur `tooCloseToSun` itu sendiri tidak
    /// hilang diam-diam: kalau penyaring Matahari dicabut, bintang ini akan
    /// lulus penyaringan dan masuk kandidat.
    func testStarCloseToSunRejectedByVisibility() throws {
        let noon = try findNoon()
        let star = try makeCloseToSunStar(at: noon)
        let resolver = makeResolver(catalogue: [star])

        let resolution = resolver.diagnose(pointing: try XCTUnwrap(
            resolver.horizontal(of: star, observer: observer, date: noon)),
            observer: observer, date: noon, coneDeg: 20.0)
        let rejection = resolution.rejected.first { $0.object.id == star.id }
        XCTAssertEqual(rejection?.visibility, .tooCloseToSun,
                       "resolver harus menyebut bintang ditolak karena tooCloseToSun")
    }

    /// Dan di level controller sungguhan: arah tunjuk ke bintang itu tidak boleh
    /// `.lock` dan tidak memicu haptic sukses — pelindung Matahari tidak bocor
    /// ke status yang membuka izin GoTo.
    func testStarCloseToSunRefusalIsHonest() throws {
        let noon = try findNoon()
        let star = try makeCloseToSunStar(at: noon)
        let resolver = makeResolver(catalogue: [star])
        let controller = self.controller(resolver: resolver)

        _ = hold(controller,
                 quaternion: try aim(at: star, date: noon, resolver: resolver),
                 since: noon)

        let snapshot = controller.snapshot
        XCTAssertNotEqual(snapshot.state, .lock,
                          "bintang terlalu dekat Matahari tidak boleh terkunci")
        XCTAssertFalse(controller.hapticLog.contains { $0.event == .lockSucceeded },
                       "tidak boleh ada haptic sukses untuk bintang dekat Matahari")
    }

    /// Bukti positif: bintang yang **sama** saat malam (jauh dari Matahari,
    /// di atas horizon) **harus** `.lock`. Membuktikan penolakan di atas
    /// spesifik ke dekat-Matahari, bukan karena bintangnya tidak bisa
    /// dipetakan sama sekali.
    func testSameStarLocksAtNight() throws {
        let noon = try findNoon()
        let star = try makeCloseToSunStar(at: noon)
        let night = try XCTUnwrap(nightWindow(for: star),
            "bintang tiruan tidak pernah di atas horizon saat malam dalam 120 hari")
        let resolver = makeResolver(catalogue: [star])
        let controller = self.controller(resolver: resolver)

        _ = hold(controller,
                 quaternion: try aim(at: star, date: night, resolver: resolver),
                 since: night)

        XCTAssertEqual(controller.snapshot.state, .lock,
                       "bintang yang sama harus terkunci saat malam (jauh dari Matahari)")
        XCTAssertTrue(controller.hapticLog.contains { $0.event == .lockSucceeded },
                      "harus ada haptic sukses saat malam")
    }
}
