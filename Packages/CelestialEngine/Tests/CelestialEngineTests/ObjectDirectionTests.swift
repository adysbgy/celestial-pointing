import XCTest
@testable import CelestialEngine

/// `PointingResolver.horizontal(of:)` — arah benda yang sebenarnya saat ini.
///
/// Tiga pemakai lapisan app bergantung pada ini (kalibrasi, label Experiment 1,
/// target GoTo), dan ketiganya akan salah secara diam-diam kalau fungsi ini
/// mengembalikan arah tunjuk alih-alih arah objek. Karena itu fungsi ini diuji
/// dengan putaran balik lewat resolver: arahkan tunjuk **ke** arah yang
/// dilaporkan, dan resolver harus mengembalikan benda yang sama.
final class ObjectDirectionTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func resolver(withEphemeris: Bool = true) -> PointingResolver {
        PointingResolver(
            catalogue: Catalogue.brightStars,
            policy: .permissive,
            ephemeris: withEphemeris ? AstronomyKitEphemeris() : nil
        )
    }

    // MARK: - Bintang

    func testStarDirectionResolvesBackToThatStar() throws {
        let resolver = resolver()
        for star in Catalogue.brightStars {
            let direction = try XCTUnwrap(
                resolver.horizontal(of: star, observer: observer, date: date),
                "\(star.id): arah tidak terhitung"
            )
            XCTAssertTrue(direction.altitudeDeg.isFinite)
            XCTAssertTrue((0..<360).contains(direction.azimuthDeg))

            let intent = resolver.resolve(pointing: direction, observer: observer,
                                          date: date, coneDeg: 5)
            XCTAssertEqual(intent.best?.id, star.id,
                           "menunjuk tepat ke arah \(star.id) harus mengembalikan \(star.id), bukan \(String(describing: intent.best?.id))")
        }
    }

    /// Bintang J2000 harus dipresesi ke of-date. Kalau tidak, arahnya meleset
    /// ~0.3° dan uji putaran balik di atas akan gagal di sekitar ambang.
    func testStarDirectionIsPresecedToDate() {
        let resolver = resolver()
        let star = Catalogue.brightStars[0]  // Sirius
        let direction = resolver.horizontal(of: star, observer: observer, date: date)!

        let jd = SkyMath.julianDate(from: date)
        let expected = SkyMath.equatorialToHorizontal(
            SkyMath.precessJ2000ToDate(
                EquatorialCoord(raDeg: star.raDeg, decDeg: star.decDeg), jd: jd
            ),
            observer: observer, jd: jd
        )
        XCTAssertEqual(direction.altitudeDeg, expected.altitudeDeg, accuracy: 1e-12)
        XCTAssertEqual(direction.azimuthDeg, expected.azimuthDeg, accuracy: 1e-12)
    }

    // MARK: - Matahari tidak pernah jadi target

    /// Aturan keras PRD: tidak ada apa pun yang boleh diarahkan ke Matahari.
    /// Matahari ada di katalog efemeris, jadi permintaan arahnya harus ditolak.
    func testSunDirectionIsRefused() {
        let resolver = resolver()
        let sun = CelestialObject(id: "sun", name: "Matahari", kind: .sun,
                                  raDeg: 0, decDeg: 0, magnitude: -26.7)
        XCTAssertNil(resolver.horizontal(of: sun, observer: observer, date: date),
                     "arah Matahari tidak boleh pernah diberikan")
        XCTAssertNil(resolver.horizontal(ofBody: .sun, observer: observer, date: date))
    }

    // MARK: - Benda tata surya

    func testSolarSystemDirectionNeedsEphemeris() {
        let resolver = resolver(withEphemeris: false)
        XCTAssertNil(resolver.horizontal(ofBody: .moon, observer: observer, date: date),
                     "tanpa efemeris arah Bulan tidak diketahui — jangan menebak")
    }

    func testMoonDirectionResolvesBackToMoon() throws {
        let resolver = resolver()
        let direction = try XCTUnwrap(
            resolver.horizontal(ofBody: .moon, observer: observer, date: date)
        )
        let intent = resolver.resolve(pointing: direction, observer: observer,
                                      date: date, coneDeg: 5)
        XCTAssertEqual(intent.best?.id, "moon")
    }

    /// Arah benda tata surya dari `horizontal(of:)` harus sama dengan yang
    /// dipakai `diagnose()` saat menyaring kandidat. Kalau keduanya berbeda,
    /// pengaman slew akan memakai target yang tidak konsisten dengan resolusi.
    func testSolarSystemDirectionMatchesDiagnoseGeometry() throws {
        let resolver = resolver()
        let direction = try XCTUnwrap(resolver.horizontal(ofBody: .jupiter, observer: observer, date: date))

        let ephemeris = try XCTUnwrap(resolver.ephemeris)
        let sample = try ephemeris.apparent(.jupiter, at: date, from: observer)
        let expected = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
            observer: observer, jd: SkyMath.julianDate(from: date)
        )
        XCTAssertEqual(direction.altitudeDeg, expected.altitudeDeg, accuracy: 1e-12)
        XCTAssertEqual(direction.azimuthDeg, expected.azimuthDeg, accuracy: 1e-12)
    }

    /// Target GoTo harus bisa dihitung dari objek hasil identifikasi, tanpa
    /// pernah menyentuh arah tunjuk. Ini yang menjaga aturan PRD di lapisan app.
    func testIdentifiedObjectGivesSlewTargetIndependentOfPointing() throws {
        let resolver = resolver()
        let truth = try XCTUnwrap(resolver.horizontal(ofBody: .jupiter, observer: observer, date: date))

        // Arah tunjuk sengaja meleset 8° dari objek: masih teridentifikasi,
        // tapi perintah GoTo harus menunjuk posisi Jupiter, bukan arah tunjuk.
        let offPointing = HorizontalCoord(
            altitudeDeg: truth.altitudeDeg - 8,
            azimuthDeg: truth.azimuthDeg
        )
        let resolution = resolver.diagnose(pointing: offPointing, observer: observer,
                                           date: date, coneDeg: 15)
        XCTAssertEqual(resolution.intent.best?.id, "jupiter")

        let object = try XCTUnwrap(resolution.intent.best)
        let target = try XCTUnwrap(resolver.horizontal(of: object, observer: observer, date: date))
        XCTAssertEqual(target.altitudeDeg, truth.altitudeDeg, accuracy: 1e-9)
        XCTAssertNotEqual(target.altitudeDeg, offPointing.altitudeDeg, accuracy: 1.0,
                          "target GoTo tidak boleh sama dengan arah tunjuk")
    }
}
