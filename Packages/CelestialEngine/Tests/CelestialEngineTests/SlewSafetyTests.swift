import XCTest
@testable import CelestialEngine

/// Pengaman slew: POINT → OBJECT ID → SAFE GOTO, dengan aturan gagal-tertutup.
final class SlewSafetyTests: XCTestCase {

    private let star = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279.23, decDeg: 38.78, magnitude: 0.03)
    // Matahari jauh di barat, target di timur.
    private let sun = HorizontalCoord(altitudeDeg: 30, azimuthDeg: 270)
    private let goodTarget = HorizontalCoord(altitudeDeg: 45, azimuthDeg: 90)

    private func resolution(level: ConfidenceLevel,
                            best: CelestialObject?,
                            sun: HorizontalCoord?) -> Resolution {
        Resolution(
            intent: CelestialIntent(level: level, best: best, candidates: []),
            context: SkyContext(sunAltitudeDeg: -20),
            sunHorizontal: sun
        )
    }

    // MARK: - Kasus aman

    func testHighConfidenceClearTargetIsAllowed() {
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: star, sun: sun),
            targetHorizontal: goodTarget
        )
        XCTAssertTrue(decision.isAllowed)
        guard case .allowed(let command) = decision else { return XCTFail() }
        XCTAssertEqual(command.object.id, "vega")
        XCTAssertEqual(command.target.altitudeDeg, 45)
        XCTAssertEqual(command.confidence, .high)
        XCTAssertTrue(decision.hazards.isEmpty)
    }

    // MARK: - Penolakan karena keyakinan / target

    func testNoTargetIsRejected() {
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: nil, sun: sun),
            targetHorizontal: goodTarget
        )
        XCTAssertEqual(decision.hazards, [.noTarget])
    }

    func testMediumConfidenceIsRejectedByDefault() {
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .medium, best: star, sun: sun),
            targetHorizontal: goodTarget
        )
        XCTAssertEqual(decision.hazards, [.lowConfidence])
    }

    func testMediumConfidenceAllowedWhenPolicyPermits() {
        let policy = SlewSafetyPolicy(requiredConfidence: .medium)
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .medium, best: star, sun: sun),
            targetHorizontal: goodTarget,
            policy: policy
        )
        XCTAssertTrue(decision.isAllowed)
    }

    func testMissingTargetDirectionIsRejected() {
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: star, sun: sun),
            targetHorizontal: nil
        )
        XCTAssertEqual(decision.hazards, [.noTarget])
    }

    // MARK: - Pengaman Matahari (batas keras)

    func testTargetTooCloseToSunIsRejected() {
        // Target hanya 10° dari Matahari, di bawah ambang 30°.
        let nearSun = HorizontalCoord(altitudeDeg: 30, azimuthDeg: 260)
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: star, sun: sun),
            targetHorizontal: nearSun
        )
        XCTAssertTrue(decision.hazards.contains(.sunProximity))
        XCTAssertFalse(decision.isAllowed)
    }

    /// Kalau posisi Matahari tidak diketahui, engine TIDAK boleh menganggap
    /// aman. Ini arah aman yang wajib.
    func testUnknownSunPositionIsRejectedNotAssumedSafe() {
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: star, sun: nil),
            targetHorizontal: goodTarget
        )
        XCTAssertEqual(decision.hazards, [.sunPositionUnknown])
        XCTAssertFalse(decision.isAllowed)
    }

    // MARK: - Batas ketinggian & kecerlangan

    func testBelowTelescopeLimitIsRejected() {
        let low = HorizontalCoord(altitudeDeg: 5, azimuthDeg: 90)
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: star, sun: sun),
            targetHorizontal: low
        )
        XCTAssertTrue(decision.hazards.contains(.belowAltitudeLimit))
        XCTAssertFalse(decision.hazards.contains(.belowHorizon), "5° masih di atas horizon")
    }

    func testBelowHorizonIsReportedAsSuch() {
        let under = HorizontalCoord(altitudeDeg: -10, azimuthDeg: 90)
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: star, sun: sun),
            targetHorizontal: under
        )
        XCTAssertTrue(decision.hazards.contains(.belowHorizon))
        XCTAssertTrue(decision.hazards.contains(.belowAltitudeLimit))
    }

    func testAboveMeridianLimitIsRejected() {
        let tooHigh = HorizontalCoord(altitudeDeg: 89.5, azimuthDeg: 90)
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: star, sun: sun),
            targetHorizontal: tooHigh
        )
        XCTAssertTrue(decision.hazards.contains(.belowAltitudeLimit))
    }

    func testTooFaintIsRejected() {
        let faint = CelestialObject(id: "faint", name: "Faint", kind: .star,
                                    raDeg: 0, decDeg: 0, magnitude: 12.0)
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: faint, sun: sun),
            targetHorizontal: goodTarget
        )
        XCTAssertTrue(decision.hazards.contains(.tooFaint))
    }

    // MARK: - Gagal-tertutup & sanitasi

    func testRejectedHazardsAreNeverEmpty() {
        let cases: [SlewDecision] = [
            SlewPlanner.plan(resolution: resolution(level: .high, best: nil, sun: sun),
                             targetHorizontal: goodTarget),
            SlewPlanner.plan(resolution: resolution(level: .low, best: star, sun: sun),
                             targetHorizontal: goodTarget),
            SlewPlanner.plan(resolution: resolution(level: .high, best: star, sun: nil),
                             targetHorizontal: goodTarget)
        ]
        for decision in cases {
            XCTAssertFalse(decision.isAllowed)
            XCTAssertFalse(decision.hazards.isEmpty)
        }
    }

    func testHazardsAreUniqueAndSorted() {
        // Di bawah horizon + terlalu redup sekaligus (jauh dari Matahari).
        let bad = CelestialObject(id: "bad", name: "Bad", kind: .star,
                                  raDeg: 0, decDeg: 0, magnitude: 15)
        let underHorizon = HorizontalCoord(altitudeDeg: -5, azimuthDeg: 90)
        let decision = SlewPlanner.plan(
            resolution: resolution(level: .high, best: bad, sun: sun),
            targetHorizontal: underHorizon
        )
        let hazards = decision.hazards
        XCTAssertEqual(Set(hazards).count, hazards.count, "tidak boleh ada duplikat")
        XCTAssertEqual(hazards, hazards.sorted { $0.rawValue < $1.rawValue }, "harus terurut")
        XCTAssertTrue(hazards.contains(.belowHorizon))
        XCTAssertTrue(hazards.contains(.belowAltitudeLimit))
        XCTAssertTrue(hazards.contains(.tooFaint))
    }

    func testConfidenceRanking() {
        let policy = SlewSafetyPolicy(requiredConfidence: .medium)
        XCTAssertTrue(SlewPlanner.confidenceIsSufficient(.high, policy: policy))
        XCTAssertTrue(SlewPlanner.confidenceIsSufficient(.medium, policy: policy))
        XCTAssertFalse(SlewPlanner.confidenceIsSufficient(.low, policy: policy))
    }
}

#if canImport(AstronomyKit)

/// Rantai penuh POINT → OBJECT ID → SAFE GOTO pada geometri langit sungguhan.
final class SlewIntegrationTests: XCTestCase {

    private let jakarta = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = ISO8601DateFormatter().date(from: "2026-01-01T15:00:00Z")!

    private func resolver() -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: .permissive,
                         ephemeris: AstronomyKitEphemeris())
    }

    private func horizontal(of body: EphemerisBody) throws -> HorizontalCoord {
        let sample = try AstronomyKitEphemeris().apparent(body, at: date, from: jakarta)
        let jd = SkyMath.julianDate(from: date)
        return SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
            observer: jakarta, jd: jd
        )
    }

    /// Tunjuk Bulan pada malam penuh → identifikasi HIGH → GoTo aman.
    func testPointingAtMoonYieldsSafeGoto() throws {
        let moonDir = try horizontal(of: .moon)
        let resolution = resolver().diagnose(pointing: moonDir, observer: jakarta,
                                             date: date, coneDeg: 10)
        XCTAssertEqual(resolution.intent.best?.id, "moon")

        let decision = SlewPlanner.plan(resolution: resolution, targetHorizontal: moonDir)
        XCTAssertTrue(decision.isAllowed, "hazards: \(decision.hazards)")
        guard case .allowed(let command) = decision else { return XCTFail() }
        XCTAssertEqual(command.object.id, "moon")
    }

    /// Jupiter berdekatan dengan Pollux pada tanggal ini → resolver hanya MEDIUM,
    /// sehingga GoTo default (butuh HIGH) harus DITOLAK. Inilah aturan
    /// "jangan pernah salah identifikasi demi magic" bekerja sampai ke teleskop.
    func testAmbiguousJupiterDoesNotAuthorizeGoto() throws {
        let jupiterDir = try horizontal(of: .jupiter)
        let resolution = resolver().diagnose(pointing: jupiterDir, observer: jakarta,
                                             date: date, coneDeg: 10)
        XCTAssertEqual(resolution.intent.level, .medium)

        let decision = SlewPlanner.plan(resolution: resolution, targetHorizontal: jupiterDir)
        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.hazards.contains(.lowConfidence))
    }

    /// Matahari di bawah horizon malam itu, tapi arahnya tetap diekspos sehingga
    /// pengaman bisa dijalankan — bukan ditolak karena "tidak diketahui".
    func testSunDirectionIsAvailableAtNight() throws {
        let resolution = resolver().diagnose(
            pointing: HorizontalCoord(altitudeDeg: 60, azimuthDeg: 90),
            observer: jakarta, date: date, coneDeg: 10
        )
        XCTAssertNotNil(resolution.sunHorizontal)
        XCTAssertLessThan(resolution.context.sunAltitudeDeg, -40)
    }
}

#endif
