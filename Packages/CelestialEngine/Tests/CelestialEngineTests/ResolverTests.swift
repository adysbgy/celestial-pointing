import XCTest
@testable import CelestialEngine

final class ResolverTests: XCTestCase {

    // MARK: - Confidence model (tanpa katalog)

    func testConfidenceLowWhenNoCandidates() {
        let intent = ConfidenceModel.evaluate(candidates: [], coneDeg: 20)
        XCTAssertEqual(intent.level, .low)
        XCTAssertNil(intent.best)
    }

    // MARK: - Katalog bintang

    func testCatalogueNotEmpty() {
        XCTAssertGreaterThanOrEqual(Catalogue.brightStars.count, 20)
    }

    func testResolverFindsSiriusWhenPointedAtIt() {
        let obs = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8) // Jakarta
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let jd = SkyMath.julianDate(from: date)

        let sirius = EquatorialCoord(raDeg: 101.28715533, decDeg: -16.71611586)
        let ofDate = SkyMath.precessJ2000ToDate(sirius, jd: jd)
        let hor = SkyMath.equatorialToHorizontal(ofDate, observer: obs, jd: jd)

        let resolver = PointingResolver(catalogue: Catalogue.brightStars, policy: .permissive)
        let intent = resolver.resolve(pointing: hor, observer: obs, date: date, coneDeg: 20)
        XCTAssertEqual(intent.best?.id, "sirius")
        XCTAssertEqual(intent.level, .high)
    }

    /// Tanpa efemeris, resolver hanya boleh mengembalikan bintang.
    func testResolverWithoutEphemerisOnlyReturnsStars() {
        let obs = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let jd = SkyMath.julianDate(from: date)
        let sirius = EquatorialCoord(raDeg: 101.28715533, decDeg: -16.71611586)
        let hor = SkyMath.equatorialToHorizontal(
            SkyMath.precessJ2000ToDate(sirius, jd: jd), observer: obs, jd: jd
        )

        let resolver = PointingResolver(catalogue: Catalogue.brightStars, policy: .permissive)
        XCTAssertFalse(resolver.considersSolarSystem)

        let resolution = resolver.diagnose(pointing: hor, observer: obs, date: date, coneDeg: 20)
        XCTAssertEqual(resolution.intent.best?.kind, .star)
        XCTAssertTrue(resolution.ephemerisFailures.isEmpty)
    }

    /// Benda di bawah horizon tidak boleh jadi kandidat, walau tepat ditunjuk.
    ///
    /// Bintangnya dipilih dari katalog supaya benar-benar berada di bawah
    /// horizon pada saat itu — bukan diasumsikan.
    func testObjectBelowHorizonIsNeverACandidate() throws {
        let obs = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let jd = SkyMath.julianDate(from: date)
        let resolver = PointingResolver(catalogue: Catalogue.brightStars) // kebijakan default

        func horizontal(_ object: CelestialObject) -> HorizontalCoord {
            SkyMath.equatorialToHorizontal(
                SkyMath.precessJ2000ToDate(
                    EquatorialCoord(raDeg: object.raDeg, decDeg: object.decDeg), jd: jd
                ),
                observer: obs, jd: jd
            )
        }

        let underground = try XCTUnwrap(
            Catalogue.brightStars.first { horizontal($0).altitudeDeg < -20 },
            "butuh minimal satu bintang jauh di bawah horizon untuk uji ini"
        )
        let hidden = horizontal(underground)

        let resolution = resolver.diagnose(pointing: hidden, observer: obs,
                                           date: date, coneDeg: 10)
        XCTAssertNotEqual(resolution.intent.best?.id, underground.id)
        XCTAssertFalse(resolution.intent.candidates.contains { $0.object.id == underground.id },
                       "\(underground.name) di bawah horizon tapi jadi kandidat")
        XCTAssertTrue(resolution.rejected.contains {
            $0.object.id == underground.id && $0.visibility == .belowHorizon
        }, "\(underground.name) seharusnya dilaporkan sebagai di bawah horizon")
    }

    /// Semua kandidat yang dikembalikan harus benar-benar di atas horizon.
    func testEveryReturnedCandidateIsAboveHorizon() {
        let obs = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let jd = SkyMath.julianDate(from: date)

        let resolver = PointingResolver(catalogue: Catalogue.brightStars)
        // Sapu seluruh langit dan pastikan tidak ada kandidat di bawah horizon.
        for altitude in stride(from: -90.0, through: 90.0, by: 30.0) {
            for azimuth in stride(from: 0.0, to: 360.0, by: 30.0) {
                let resolution = resolver.diagnose(
                    pointing: HorizontalCoord(altitudeDeg: altitude, azimuthDeg: azimuth),
                    observer: obs, date: date, coneDeg: 30
                )
                for candidate in resolution.intent.candidates {
                    let hor = SkyMath.equatorialToHorizontal(
                        SkyMath.precessJ2000ToDate(
                            EquatorialCoord(raDeg: candidate.object.raDeg,
                                            decDeg: candidate.object.decDeg),
                            jd: jd
                        ),
                        observer: obs, jd: jd
                    )
                    XCTAssertGreaterThanOrEqual(
                        hor.altitudeDeg, resolver.policy.minAltitudeDeg,
                        "\(candidate.object.name) di bawah horizon tapi jadi kandidat"
                    )
                }
            }
        }
    }
}

#if canImport(AstronomyKit)

/// Uji integrasi resolver + efemeris sungguhan.
///
/// Skenario tetap: Jakarta, 2026-01-01T15:00Z. Pada saat itu Bulan ~55°,
/// Jupiter ~42°, dan Matahari ~-49° (malam penuh). Nilai-nilai ini berasal
/// dari efemeris yang sudah divalidasi terhadap Horizons.
final class ResolverEphemerisTests: XCTestCase {

    private let jakarta = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = ISO8601DateFormatter().date(from: "2026-01-01T15:00:00Z")!

    private func resolver(policy: VisibilityPolicy = .permissive) -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: policy,
                         ephemeris: AstronomyKitEphemeris())
    }

    /// Arahkan tepat ke posisi Bulan -> harus dapat Bulan.
    func testPointingAtMoonResolvesToMoon() throws {
        let ephemeris = AstronomyKitEphemeris()
        let sample = try ephemeris.apparent(.moon, at: date, from: jakarta)
        let jd = SkyMath.julianDate(from: date)
        let hor = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
            observer: jakarta, jd: jd
        )

        let intent = resolver().resolve(pointing: hor, observer: jakarta, date: date, coneDeg: 10)
        XCTAssertEqual(intent.best?.id, "moon")
        XCTAssertEqual(intent.best?.kind, .moon)
        XCTAssertEqual(intent.level, .high)
    }

    /// Arahkan tepat ke Jupiter -> harus dapat Jupiter.
    ///
    /// Tapi Jupiter tidak boleh berkeyakinan HIGH di sini: pada 2026-01-01
    /// ia hanya ~6.8° dari Pollux, jadi keduanya berada dalam ketidakpastian
    /// pointing kita. Ini justru contoh anti-false-lock yang bekerja pada
    /// geometri langit sungguhan.
    func testPointingAtJupiterResolvesToJupiterButNotHigh() throws {
        let ephemeris = AstronomyKitEphemeris()
        let sample = try ephemeris.apparent(.jupiter, at: date, from: jakarta)
        let jd = SkyMath.julianDate(from: date)
        let hor = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
            observer: jakarta, jd: jd
        )

        let intent = resolver().resolve(pointing: hor, observer: jakarta, date: date, coneDeg: 10)
        XCTAssertEqual(intent.best?.id, "jupiter", "Jupiter tetap tebakan terbaik")
        XCTAssertEqual(intent.level, .medium,
                       "Jupiter ~6.8° dari Pollux, jadi tidak boleh diklaim pasti")
        XCTAssertTrue(intent.candidates.contains { $0.object.id == "pollux" },
                      "Pollux harus ikut dilaporkan sebagai alternatif")
    }

    /// Sebaliknya: arahkan ke bintang yang jauh dari benda terang lain ->
    /// boleh HIGH. Kalau ini gagal, engine terlalu pelit dan tidak berguna.
    func testPointingAtIsolatedStarCanBeHigh() throws {
        let jd = SkyMath.julianDate(from: date)
        let sirius = EquatorialCoord(raDeg: 101.28715533, decDeg: -16.71611586)
        let hor = SkyMath.equatorialToHorizontal(
            SkyMath.precessJ2000ToDate(sirius, jd: jd), observer: jakarta, jd: jd
        )

        let resolution = resolver(policy: VisibilityPolicy()).diagnose(
            pointing: hor, observer: jakarta, date: date, coneDeg: 10
        )
        XCTAssertEqual(resolution.intent.best?.id, "sirius")
        XCTAssertEqual(resolution.intent.level, .high,
                       "Sirius ~40° dari Jupiter dan ~45° dari Betelgeuse; harus boleh HIGH")
    }

    /// Matahari TIDAK PERNAH boleh muncul sebagai kandidat, dalam kondisi apa pun.
    func testSunIsNeverACandidate() {
        let ephemeris = AstronomyKitEphemeris()
        let jd = SkyMath.julianDate(from: date)
        let sun = try! ephemeris.apparent(.sun, at: date, from: jakarta)
        let sunHor = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sun.raDeg, decDeg: sun.decDeg), observer: jakarta, jd: jd
        )

        // Tunjuk langsung ke Matahari, dengan kebijakan paling permisif.
        let resolution = resolver().diagnose(pointing: sunHor, observer: jakarta,
                                             date: date, coneDeg: 90)
        XCTAssertNotEqual(resolution.intent.best?.id, "sun")
        XCTAssertFalse(resolution.intent.candidates.contains { $0.object.id == "sun" })
        XCTAssertFalse(resolution.rejected.contains { $0.object.id == "sun" },
                       "Matahari seharusnya tidak pernah masuk proses sama sekali")
    }

    /// Konteks langit harus realistis: malam di Jakarta pada tanggal ini.
    func testSkyContextIsNightInJakarta() {
        let context = resolver().skyContext(observer: jakarta, date: date)
        XCTAssertLessThan(context.sunAltitudeDeg, -40, "Matahari seharusnya jauh di bawah horizon")
        XCTAssertTrue(context.isDark)
        XCTAssertNotNil(context.moonAltitudeDeg)
        XCTAssertGreaterThan(context.moonAltitudeDeg ?? -90, 40, "Bulan seharusnya tinggi")
    }

    /// Pada siang hari resolver tidak boleh mengklaim bintang dengan yakin.
    func testDaylightProducesNoHighConfidenceStar() throws {
        // Jakarta, tengah hari.
        let noon = ISO8601DateFormatter().date(from: "2026-01-01T05:00:00Z")!
        let resolution = resolver(policy: VisibilityPolicy()).diagnose(
            pointing: HorizontalCoord(altitudeDeg: 60, azimuthDeg: 180),
            observer: jakarta, date: noon, coneDeg: 40
        )
        XCTAssertFalse(resolution.context.isDark, "seharusnya siang")
        XCTAssertNotEqual(resolution.intent.level, .high)
    }

    /// Benda di bawah horizon harus dilaporkan dengan alasan yang benar.
    /// Memakai kebijakan default (ketat), bukan yang permisif.
    func testBelowHorizonBodiesAreReportedAsSuch() {
        let strict = resolver(policy: VisibilityPolicy())
        let resolution = strict.diagnose(
            pointing: HorizontalCoord(altitudeDeg: -80, azimuthDeg: 90),
            observer: jakarta, date: date, coneDeg: 5
        )
        XCTAssertNil(resolution.intent.best)
        XCTAssertGreaterThan(resolution.rejected.count, 0)
        XCTAssertTrue(resolution.rejected.allSatisfy { $0.visibility == .belowHorizon },
                      "malam hari, jadi alasan satu-satunya adalah di bawah horizon")
    }

    /// Jejak audit harus konsisten dengan jumlah yang dipertimbangkan.
    func testAuditTrailIsConsistent() {
        let resolution = resolver().diagnose(
            pointing: HorizontalCoord(altitudeDeg: 55, azimuthDeg: 90),
            observer: jakarta, date: date, coneDeg: 10
        )
        XCTAssertEqual(resolution.consideredCount,
                       Catalogue.brightStars.count + EphemerisBody.pointableBodies.count)
        XCTAssertTrue(resolution.ephemerisFailures.isEmpty,
                      "tidak seharusnya ada kegagalan efemeris: \(resolution.ephemerisFailures)")
    }
}

#endif
