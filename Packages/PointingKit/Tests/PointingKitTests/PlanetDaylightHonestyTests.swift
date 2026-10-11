import XCTest
import CelestialEngine
@testable import PointingKit

/// Planet di **siang hari** tidak boleh terkunci — dan penolakannya harus jujur.
///
/// **Kenapa berkas ini ada, walau sudah ada dua berkas siang.**
/// Dua penjaga siang yang ada **sengaja** tidak mencakup planet:
///
///   - `DaylightLockTests` memilih arah tunjuknya dari `Catalogue.brightStars`,
///     jadi yang dijaganya hanya **bintang**.
///   - `MoonDaylightHonestyTests` menguji `.moon` saja, lewat jalur efemerisnya
///     sendiri.
///
/// Planet (Merkurius, Venus, Mars, Jupiter, Saturnus) jatuh di celah
/// keduanya: mereka bukan bintang katalog, dan bukan Bulan. Mereka ditambahkan
/// ke kandidat oleh cabang `EphemerisBody.pointableBodies` di dalam
/// `resolve`/`diagnose`, dengan magnitudo **sampel efemeris** (`sample.magnitude`)
/// — bukan magnitudo katalog seperti bintang.
///
/// Itu celah yang layak dijaga, karena magnitudo planet jauh lebih terang
/// daripada ambang `limitingMagnitude`: Jupiter dan Saturnus **lulus** gerbang
/// magnitudo dan gerjang jarak-Matahari, sehingga `daylight` adalah
/// **satu-satunya** alasan mereka tidak jadi kandidat. Terukur (probe,
/// pengamat Jakarta): Saturnus di alt 43,3° dengan Matahari 69,5° memberi
/// level `low`/`best=nil` pada policy produksi, tetapi `high`/`best=saturn`
/// ketika **hanya** `sunAltitudeForDarknessDeg` dilonggarkan.
///
/// **Yang dijaga.** Sama seperti dua berkas di atasnya, ujinya memutar
/// `PointingController` **sungguhan**, bukan resolver: `.lock` adalah satu-
/// satunya keadaan yang memicu haptic sukses, bunyi, pengumuman VoiceOver,
/// visual pengenal (pita Jupiter, cincin Saturnus), dan izin GoTo. Penjagaan
/// siang yang bocor di salah satu langkah antara resolver dan `.lock` adalah
/// persis kelas false confidence yang dilarang PRD.
///
/// **Kenapa bukti positifnya wajib.** "Tidak terkunci" saja bisa hijau karena
/// alasan yang salah — misalnya planetnya sedang di bawah horizon. Karena itu
/// tiap planet yang diuji harus lolos tiga syarat: tinggi (> 30°), ditolak
/// **karena `daylight`**, dan **menjadi kandidat** bila hanya gerbang kegelapan
/// yang dilonggarkan.
final class PlanetDaylightHonestyTests: XCTestCase {

    /// Pengamat Jakarta (WIB, UTC+7) — sama dengan `DaylightLockTests` dan
    /// `MoonDaylightHonestyTests`, supaya ketiga berkas siang bercerita tentang
    /// langit yang sama.
    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)

    /// Epok acuan: 15 Jan 2026 12:00 WIB = 05:00 UTC (sama dengan kedua berkas
    /// siang lainnya).
    private let epoch = Date(timeIntervalSince1970: 1_768_453_200)

    /// Policy produksi, bukan `.permissive`.
    ///
    /// Alasan yang sama dengan `DaylightLockTests`: `.permissive` menyetel
    /// `sunAltitudeForDarknessDeg: 91`, jadi memakainya berarti mematikan
    /// gerbang yang sedang diuji.
    private var productionPolicy: VisibilityPolicy { VisibilityPolicy() }

    /// Policy yang hanya melonggarkan **gerbang kegelapan**, untuk bukti positif.
    ///
    /// Longgarannya sengaja sesempit mungkin: `minAltitudeDeg`,
    /// `limitingMagnitude`, dan `minSunSeparationDeg` tetap produksi, jadi
    /// satu-satunya yang berubah adalah "apakah langit cukup gelap".
    private var darknessRelaxedPolicy: VisibilityPolicy {
        var policy = productionPolicy
        policy.sunAltitudeForDarknessDeg = 91
        return policy
    }

    private func makeResolver(policy: VisibilityPolicy = VisibilityPolicy()) -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: policy,
                         ephemeris: AstronomyKitEphemeris())
    }

    /// Arah tunjuk persis ke target horizontal (roll=0; salinan dari
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

    private func controller(resolver: PointingResolver) -> PointingController {
        PointingController(resolver: resolver,
                           observer: observer,
                           config: PointingControllerConfig(coneDeg: 20.0))
    }

    /// Tahan arah tunjuk yang sama, seperti pengguna yang menjaga jam tetap
    /// diam sampai pergelangan dianggap tenang.
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

    /// Satu planet beserta jam siangnya, yang memenuhi **tiga** syarat:
    ///
    ///   1. **Tinggi** (> 30°) saat langit terang, sehingga penolakan tidak
    ///      datang dari `belowHorizon` — jebakan yang membuat versi pertama
    ///      `DaylightLockTests` vacuous.
    ///   2. **Ditolak karena `daylight`, dan bukan karena alasan lain.**
    ///      `VisibilityFilter.classify` diuji ulang dengan magnitudo dan jarak
    ///      Matahari yang **benar**, karena memberi nilai karangan akan
    ///      membangkitkan `tooFaint`/`tooCloseToSun` lebih dulu.
    ///   3. **Menjadi kandidat bila hanya gerbang kegelapan dilonggarkan.**
    ///      Inilah bukti positifnya: tanpa dia, "tidak terkunci" bisa berarti
    ///      planetnya memang tidak bisa dipetakan.
    ///
    /// Dicari dari efemeris, bukan ditulis tangan: posisi planet di suatu tanggal
    /// adalah hasil perhitungan, dan menebaknya akan membuat berkas ini vacuous.
    private func planetDaytimeFixture() throws -> (body: EphemerisBody, when: Date) {
        let resolver = makeResolver()
        let relaxedResolver = makeResolver(policy: darknessRelaxedPolicy)

        for body in EphemerisBody.pointableBodies where body != .moon {
            for day in 0..<200 {
                for hour in stride(from: 0.0, through: 23.0, by: 1.0) {
                    let when = epoch.addingTimeInterval(Double(day) * 86400 + hour * 3600)
                    let context = resolver.skyContext(observer: observer, date: when)
                    guard !context.isDark, context.sunAltitudeDeg > 30 else { continue }
                    guard let direction = resolver.horizontal(ofBody: body,
                                                              observer: observer,
                                                              date: when),
                          direction.altitudeDeg > 30
                    else { continue }

                    // Syarat 2: satu-satunya alasan penolakan yang boleh berlaku.
                    let resolution = resolver.diagnose(pointing: direction,
                                                       observer: observer,
                                                       date: when,
                                                       coneDeg: 20.0)
                    guard let rejection = resolution.rejected.first(where: { $0.object.id == body.rawValue }),
                          rejection.visibility == .daylight
                    else { continue }

                    // Syarat 3: bukti positif — hanya gerbang kegelapan yang
                    // dilonggarkan, dan planetnya harus muncul sebagai kandidat.
                    let relaxed = relaxedResolver.resolve(pointing: direction,
                                                          observer: observer,
                                                          date: when,
                                                          coneDeg: 20.0)
                    guard relaxed.best?.id == body.rawValue else { continue }

                    return (body, when)
                }
            }
        }
        throw XCTSkip("tidak ada planet yang tinggi, tertahan hanya oleh terang, "
                      + "dan kembali jadi kandidat saat gerbang gelap dilonggarkan")
    }

    private func aim(at body: EphemerisBody,
                     date: Date,
                     resolver: PointingResolver) throws -> Quaternion {
        let direction = try XCTUnwrap(
            resolver.horizontal(ofBody: body, observer: observer, date: date),
            "\(body.rawValue) harus punya arah horizontal pada waktu ini")
        return quaternion(viewPointingAt: direction)
    }

    // MARK: - Yang dijaga

    /// Prasyarat fixture: langitnya benar-benar terang dan planetnya tinggi,
    /// sehingga penolakan tidak mungkin datang dari bawah horizon.
    ///
    /// Berdiri sendiri, bukan pengulangan: kalau pencarian fixture bergerak ke
    /// planet yang lebih rendah atau jam yang lebih redup, tiga tes di bawah
    /// tetap hijau sambil berhenti menguji gerbang siang.
    func testDaytimePlanetFixtureIsHighUnderABrightSky() throws {
        let picked = try planetDaytimeFixture()
        let resolver = makeResolver()
        let context = resolver.skyContext(observer: observer, date: picked.when)
        XCTAssertFalse(context.isDark, "fixture harus siang")
        XCTAssertGreaterThan(context.sunAltitudeDeg, 30, "Matahari harus tinggi")

        let direction = try XCTUnwrap(
            resolver.horizontal(ofBody: picked.body, observer: observer, date: picked.when))
        XCTAssertGreaterThan(direction.altitudeDeg, 30,
                             "\(picked.body.rawValue) harus tinggi; kalau tidak ia "
                             + "ditolak karena bawah horizon, bukan karena terang")
    }

    /// Planet di siang hari **tidak boleh** menghasilkan `.lock`, dan tidak
    /// boleh memicu haptic sukses.
    func testDaytimePlanetNeverLocks() throws {
        let picked = try planetDaytimeFixture()
        let resolver = makeResolver()
        let controller = self.controller(resolver: resolver)

        hold(controller,
             quaternion: try aim(at: picked.body, date: picked.when, resolver: resolver),
             since: picked.when)

        XCTAssertNotEqual(controller.snapshot.state, .lock,
                          "\(picked.body.rawValue) di siang hari tidak boleh terkunci")
        XCTAssertFalse(controller.hapticLog.contains { $0.event == .lockSucceeded },
                       "tidak boleh ada haptic sukses untuk planet di siang hari")
    }

    /// Penolakannya harus **jujur**: menyebut terang, bukan diam atau
    /// menyalahkan "tidak ada kandidat".
    ///
    /// Langit terang juga bukan ambiguitas, jadi `.uncertain` pun salah — alasan
    /// yang sama dengan `DaylightLockTests`.
    func testDaytimePlanetRefusalIsHonest() throws {
        let picked = try planetDaytimeFixture()
        let resolver = makeResolver()
        let controller = self.controller(resolver: resolver)

        hold(controller,
             quaternion: try aim(at: picked.body, date: picked.when, resolver: resolver),
             since: picked.when)

        let snapshot = controller.snapshot
        XCTAssertNotEqual(snapshot.state, .lock)
        XCTAssertNotEqual(snapshot.state, .uncertain,
                          "langit terang bukan ambiguitas; jangan samakan")
        XCTAssertEqual(snapshot.searchHint, .daylight,
                       "harus menyalahkan terang, bukan 'tidak ada kandidat'")
    }

    /// Bukti positif: **hanya** gerbang kegelapan yang dilonggarkan membuat
    /// planet yang sama kembali jadi kandidat.
    ///
    /// Tanpa ini, "tidak terkunci" bisa berarti planetnya sedang tidak bisa
    /// dipetakan, dan seluruh berkas ini hijau tanpa menguji apa pun. Longgaran
    /// lewat **policy**, bukan lewat `SkyContext(isDark: true)`: `classify`
    /// membaca `context.sunAltitudeDeg`, jadi konteks yang dipalsukan akan
    /// terlihat benar sambil tidak menguji apa pun.
    func testRelaxingOnlyDarknessBringsThePlanetBack() throws {
        let picked = try planetDaytimeFixture()
        let relaxedResolver = makeResolver(policy: darknessRelaxedPolicy)
        let direction = try XCTUnwrap(
            relaxedResolver.horizontal(ofBody: picked.body, observer: observer, date: picked.when))

        let relaxed = relaxedResolver.resolve(pointing: direction,
                                              observer: observer,
                                              date: picked.when,
                                              coneDeg: 20.0)
        XCTAssertEqual(relaxed.best?.id, picked.body.rawValue,
                       "melonggarkan hanya gerbang kegelapan harus mengembalikan "
                       + "\(picked.body.rawValue) sebagai kandidat — kalau tidak, "
                       + "penolakan siang tadi bukan karena terang")
        XCTAssertNotEqual(relaxed.level, .low,
                          "dan keyakinannya harus naik dari `low`")
    }
}
