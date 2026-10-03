import XCTest
import CelestialEngine
@testable import PointingKit

/// Pemilihan target dan arah benda di lapisan app.
final class TargetsTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private let sirius = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                         raDeg: 101.28715533, decDeg: -16.71611586,
                                         magnitude: -1.46)

    /// Katalog satu bintang: membuat uji pemilihan target deterministik
    /// (tidak bergantung bintang mana yang kebetulan sedang di atas horizon).
    private func resolver(ephemeris: Bool = false) -> PointingResolver {
        PointingResolver(catalogue: [sirius],
                         policy: .permissive,
                         ephemeris: ephemeris ? AstronomyKitEphemeris() : nil)
    }

    // MARK: - Daftar target

    func testTargetsAboveHorizonOnlyByDefault() {
        let r = PointingResolver(catalogue: Catalogue.brightStars, policy: .permissive)
        let targets = r.availableTargets(observer: observer, date: date)
        XCTAssertFalse(targets.isEmpty)
        XCTAssertTrue(targets.allSatisfy { $0.direction.altitudeDeg > 0 })
        XCTAssertTrue(targets.allSatisfy { !$0.isMoving }, "tanpa efemeris semua target adalah bintang")
    }

    /// Benda bergerak (Bulan/planet) harus ikut muncul saat efemeris tersedia,
    /// dan ditandai `isMoving` supaya UI tahu arahnya berubah.
    func testSolarSystemTargetsAppearWhenEphemerisAvailable() {
        let r = PointingResolver(catalogue: Catalogue.brightStars,
                                 policy: .permissive,
                                 ephemeris: AstronomyKitEphemeris())
        let targets = r.availableTargets(observer: observer, date: date)
        XCTAssertTrue(targets.contains { $0.isMoving })
        XCTAssertTrue(targets.allSatisfy { $0.id != "sun" }, "Matahari tidak pernah jadi target")
    }

    func testTargetsAreSortedBrightestFirst() {
        let r = PointingResolver(catalogue: Catalogue.brightStars, policy: .permissive)
        let magnitudes = r.availableTargets(observer: observer, date: date).map(\.magnitude)
        XCTAssertEqual(magnitudes, magnitudes.sorted())
    }

    func testTargetSeparationMatchesEngineMath() {
        let r = resolver()
        let target = r.availableTargets(observer: observer, date: date,
                                        aboveHorizonOnly: false).first!
        let other = HorizontalCoord(altitudeDeg: target.direction.altitudeDeg + 3,
                                    azimuthDeg: target.direction.azimuthDeg)
        XCTAssertEqual(target.separation(from: other),
                       SkyMath.angularSeparationHorizontalDeg(other, target.direction),
                       accuracy: 1e-12)
    }

    // MARK: - Target terdekat

    func testNearestTargetFindsExactDirection() {
        let r = resolver()
        let truth = r.horizontal(ofObjectID: "sirius", observer: observer, date: date)!
        let found = r.nearestTarget(to: truth, observer: observer, date: date,
                                    aboveHorizonOnly: false)
        XCTAssertEqual(found?.id, "sirius")
    }

    /// Dua kandidat yang nyaris sama dekatnya **tidak** boleh dipilih diam-diam:
    /// memilih yang salah membuat kalibrasi mengoreksi ke arah yang keliru.
    func testAmbiguousNearestTargetIsRefused() {
        let twin = CelestialObject(id: "sirius-twin", name: "Sirius Twin", kind: .star,
                                   raDeg: sirius.raDeg + 0.05, decDeg: sirius.decDeg,
                                   magnitude: 1.0)
        let r = PointingResolver(catalogue: [sirius, twin], policy: .permissive)
        let truth = r.horizontal(ofObjectID: "sirius", observer: observer, date: date)!

        XCTAssertNil(r.nearestTarget(to: truth, observer: observer, date: date,
                                     aboveHorizonOnly: false),
                     "kandidat berimpit harus ditolak, bukan dipilih yang terdekat")
    }

    func testNearestTargetRespectsSearchRadius() {
        let r = resolver()
        let truth = r.horizontal(ofObjectID: "sirius", observer: observer, date: date)!
        let far = HorizontalCoord(altitudeDeg: truth.altitudeDeg + 80,
                                  azimuthDeg: SkyMath.normalizeDeg(truth.azimuthDeg + 180))
        XCTAssertNil(r.nearestTarget(to: far, observer: observer, date: date, withinDeg: 5,
                                     aboveHorizonOnly: false))
    }

    func testNearestTargetSkipsBelowHorizon() {
        let r = resolver()
        // Arah di bawah horizon: tidak ada target yang boleh dipilih di sana.
        let below = HorizontalCoord(altitudeDeg: -40, azimuthDeg: 180)
        XCTAssertNil(r.nearestTarget(to: below, observer: observer, date: date))
    }

    // MARK: - Lokasi

    func testLocationValidity() {
        XCTAssertTrue(ObserverLocation.fallback.isValid)
        XCTAssertFalse(ObserverLocation(latitudeDeg: 120, longitudeDeg: 0,
                                        label: "x", source: "test").isValid)
        XCTAssertFalse(ObserverLocation(latitudeDeg: 0, longitudeDeg: 400,
                                        label: "x", source: "test").isValid)
    }

    func testLocationConvertsToObserver() {
        let location = ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                                        label: "Bandung", source: "test")
        XCTAssertEqual(location.observer, observer)
    }

    /// Lokasi darurat harus jelas menandai dirinya supaya tidak salah dianggap
    /// lokasi pengukuran.
    func testFallbackIsLabelled() {
        XCTAssertEqual(ObserverLocation.fallback.source, "fallback")
        XCTAssertTrue(ObserverLocation.fallback.label.contains("bawaan"))
    }
}
