import XCTest
@testable import CelestialEngine

/// Jembatan teleskop: putusan slew → perintah motor yang bentuknya benar.
///
/// Yang dijaga berkas ini bukan "apakah perintahnya jalan" (itu urusan
/// perangkat keras), melainkan **apa yang tidak boleh pernah lolos**:
/// perintah tanpa izin, koordinat dengan kerangka yang salah, dan perintah
/// dari mount yang tidak bisa dihentikan.
final class TelescopeBridgeTests: XCTestCase {

    // MARK: - Fixture

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279.23473479, decDeg: 38.78368896,
                                       magnitude: 0.03)

    /// Pengamat di Bandung — lokasi yang sama dengan fixture eksperimen lain.
    private let observer = Observer(latitudeDeg: -6.9, longitudeDeg: 107.6)

    /// 15 Jan 2026, 15:00 UTC.
    private let date = Date(timeIntervalSince1970: 1_768_489_200)

    private func allowed(_ object: CelestialObject) -> SlewDecision {
        .allowed(SlewCommand(object: object,
                             target: HorizontalCoord(altitudeDeg: 45, azimuthDeg: 90),
                             confidence: .high))
    }

    private func bridge(axes: MountAxis = .equatorial,
                        frames: Set<CoordinateFrame> = [.j2000, .ofDate],
                        canAbort: Bool = true,
                        preferredFrame: CoordinateFrame = .j2000) -> TelescopeBridge {
        TelescopeBridge(
            resolver: PointingResolver(catalogue: [vega]),
            capability: TelescopeCapability(axes: axes,
                                            supportedFrames: frames,
                                            firmwareVersion: "test-1.0",
                                            canAbort: canAbort),
            preferredFrame: preferredFrame
        )
    }

    // MARK: - Gerbang: penolakan tidak pernah menjadi izin

    func testRejectedDecisionNeverProducesACommand() {
        let decision = SlewDecision.rejected(hazards: [.sunProximity])
        let result = bridge().command(for: decision, observer: observer, date: date)

        guard case .failure(.notAllowed(let hazards)) = result else {
            return XCTFail("penolakan tidak boleh menghasilkan perintah")
        }
        XCTAssertEqual(hazards, [.sunProximity],
                       "bahaya harus diteruskan apa adanya, bukan diringkas")
    }

    func testLowConfidenceRejectionCarriesItsHazard() {
        let decision = SlewDecision.rejected(hazards: [.lowConfidence, .tooFaint])
        let result = bridge().command(for: decision, observer: observer, date: date)

        guard case .failure(.notAllowed(let hazards)) = result else {
            return XCTFail("harus ditolak")
        }
        XCTAssertEqual(Set(hazards), Set([.lowConfidence, .tooFaint]))
    }

    // MARK: - Matahari tidak pernah jadi target

    func testSunIsNeverAValidTarget() {
        // Matahari tidak bisa dibuat lewat SlewPlanner (selalu ditolak), jadi
        // yang diuji di sini adalah pertahanan lapis kedua: kalaupun sebuah
        // SlewCommand memuatnya, jembatan tetap menolak.
        let sun = CelestialObject(id: "sun", name: "Matahari", kind: .sun,
                                  raDeg: 280, decDeg: -20, magnitude: -26.7)
        let result = bridge().command(for: allowed(sun), observer: observer, date: date)

        guard case .failure(.targetHasNoPosition(let id)) = result else {
            return XCTFail("Matahari tidak boleh punya posisi yang bisa dikirim ke motor")
        }
        XCTAssertEqual(id, "sun")
    }

    // MARK: - Bentuk target mengikuti sumbu mount

    func testEquatorialMountGetsEquatorialTargetInTheRequestedFrame() {
        let result = bridge(preferredFrame: .j2000)
            .command(for: allowed(vega), observer: observer, date: date)

        guard case .success(let command) = result,
              case .equatorial(let coord, let frame) = command.target else {
            return XCTFail("mount ekuatorial harus menerima koordinat ekuatorial")
        }
        XCTAssertEqual(frame, .j2000)
        XCTAssertEqual(coord.raDeg, vega.raDeg, accuracy: 0.01,
                       "J2000 diminta → koordinat katalog harus dikembalikan apa adanya")
        XCTAssertEqual(coord.decDeg, vega.decDeg, accuracy: 0.01)
    }

    func testAltAzMountGetsHorizontalTargetNotEquatorial() {
        let resolver = PointingResolver(catalogue: [vega])
        let result = TelescopeBridge(
            resolver: resolver,
            capability: TelescopeCapability(axes: .altitudeAzimuth,
                                            supportedFrames: [],
                                            firmwareVersion: "test-1.0",
                                            canAbort: true)
        ).command(for: allowed(vega), observer: observer, date: date)

        guard case .success(let command) = result,
              case .horizontal(let horizontal) = command.target else {
            return XCTFail("mount alt-az harus menerima arah horizontal")
        }

        // Dibandingkan dengan jalur engine sendiri (`horizontal(ofObjectID:)`),
        // yang mempresesi J2000 → of-date lalu mengubah ke horizontal. Kalau
        // jembatan menyerahkan koordinat J2000 mentah ke `equatorialToHorizontal`,
        // angkanya meleset ~0,3° dan pemeriksaan ini merah.
        let expected = resolver.horizontal(ofObjectID: "vega", observer: observer, date: date)
        let want = try! XCTUnwrap(expected)
        XCTAssertEqual(horizontal.altitudeDeg, want.altitudeDeg, accuracy: 1e-9)
        XCTAssertEqual(horizontal.azimuthDeg, want.azimuthDeg, accuracy: 1e-9)
    }

    /// **Bukti bahwa presesi benar-benar terjadi di jalur alt-az.** Tanpa
    /// presesi, bintang meleset ~0,3° pada 2026 — di bawah ambang yang bisa
    /// dilihat mata di layar mana pun, tapi cukup untuk memilih bintang salah.
    func testAltAzPathAppliesPrecessionRatherThanUsingRawJ2000() {
        let result = bridge(axes: .altitudeAzimuth)
            .command(for: allowed(vega), observer: observer, date: date)

        guard case .success(let command) = result,
              case .horizontal(let actual) = command.target else {
            return XCTFail("harus horizontal")
        }

        let jd = SkyMath.julianDate(from: date)
        let noPrecession = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: vega.raDeg, decDeg: vega.decDeg),
            observer: observer, jd: jd
        )
        let separation = SkyMath.angularSeparationHorizontalDeg(actual, noPrecession)
        XCTAssertGreaterThan(separation, 0.1,
                             "kalau sama, koordinat J2000 mentah dipakai tanpa presesi")
        XCTAssertLessThan(separation, 1.0, "presesi 26 tahun tidak sebesar ini")
    }

    /// **Inti kebenaran kerangka.** Mengirim koordinat J2000 ke mount yang
    /// minta of-date berarti meleset ~0,3° pada 2026 — dan tidak ada layar
    /// mana pun yang bisa memperlihatkannya.
    func testOfDateFrameDiffersFromJ2000ByPrecession() {
        let b = bridge(preferredFrame: .ofDate)
        let result = b.command(for: allowed(vega), observer: observer, date: date)

        guard case .success(let command) = result,
              case .equatorial(let coord, let frame) = command.target else {
            return XCTFail("harus menghasilkan koordinat ekuatorial of-date")
        }
        XCTAssertEqual(frame, .ofDate)

        let separation = SkyMath.angularSeparationDeg(
            EquatorialCoord(raDeg: vega.raDeg, decDeg: vega.decDeg), coord
        )
        // Presesi 2000 → 2026 sekitar 0,36°. Ambang bawah 0,1° cukup untuk
        // membuktikan konversinya benar-benar terjadi, ambang atas 1,0°
        // membuktikan ia bukan presesi yang dikarang.
        XCTAssertGreaterThan(separation, 0.1,
                             "of-date harus berbeda dari J2000 — kalau sama, presesinya tidak jalan")
        XCTAssertLessThan(separation, 1.0, "presesi 26 tahun tidak mungkin sebesar ini")
    }

    func testEquatorialMountThatCannotAcceptTheFrameIsRejected() {
        let result = bridge(frames: [.ofDate], preferredFrame: .j2000)
            .command(for: allowed(vega), observer: observer, date: date)

        guard case .failure(.unsupportedFrame(let frame)) = result else {
            return XCTFail("kerangka yang tidak didukung harus ditolak, bukan dikonversi diam-diam")
        }
        XCTAssertEqual(frame, .j2000)
    }

    // MARK: - Benda tata surya: posisi diambil ulang, bukan dipakai ulang

    func testPlanetPositionIsRecomputedFromTheEphemerisNotReused() throws {
        // Dua waktu berbeda; posisi Bulan harus ikut bergerak. Kalau jembatan
        // memakai ulang koordinat dari resolusi, keduanya akan identik.
        let ephemeris = StubEphemeris()
        let resolver = PointingResolver(catalogue: [], ephemeris: ephemeris)
        let b = TelescopeBridge(
            resolver: resolver,
            capability: TelescopeCapability(axes: .equatorial,
                                            supportedFrames: [.ofDate],
                                            firmwareVersion: "test-1.0",
                                            canAbort: true),
            preferredFrame: .ofDate
        )

        let moon = CelestialObject(id: "moon", name: "Bulan", kind: .moon,
                                   raDeg: 0, decDeg: 0, magnitude: -12)
        let first = try XCTUnwrap(b.command(for: allowed(moon), observer: observer, date: date).get())
        let later = try XCTUnwrap(
            b.command(for: allowed(moon),
                      observer: observer,
                      date: date.addingTimeInterval(3 * 3600)).get()
        )

        guard case .equatorial(let a, _) = first.target,
              case .equatorial(let c, _) = later.target else {
            return XCTFail("harus ekuatorial")
        }
        XCTAssertNotEqual(a.raDeg, c.raDeg,
                          "Bulan bergerak ~0,5°/jam — koordinat lama tidak boleh dipakai ulang")
        XCTAssertGreaterThan(abs(a.raDeg - c.raDeg), 0.5)
    }

    func testPlanetWithoutEphemerisIsRejectedNotGuessed() {
        // Resolver tanpa efemeris: koordinat planet tidak bisa dihitung.
        let resolver = PointingResolver(catalogue: [])
        let b = TelescopeBridge(
            resolver: resolver,
            capability: TelescopeCapability(axes: .equatorial,
                                            supportedFrames: [.ofDate],
                                            firmwareVersion: "test-1.0",
                                            canAbort: true),
            preferredFrame: .ofDate
        )
        let jupiter = CelestialObject(id: "jupiter", name: "Jupiter", kind: .planet,
                                      raDeg: 10, decDeg: 10, magnitude: -2)
        let result = b.command(for: allowed(jupiter), observer: observer, date: date)

        guard case .failure(.targetHasNoPosition(let id)) = result else {
            return XCTFail("tanpa efemeris, posisi planet tidak boleh ditebak")
        }
        XCTAssertEqual(id, "jupiter")
    }

    // MARK: - Sesi: penolakan tidak menyentuh perangkat keras

    func testRefusedDecisionNeverTouchesTheTransport() {
        let transport = SpyTransport()
        let session = TelescopeSession(bridge: bridge(),
                                       transport: transport,
                                       commandPath: "test-path")
        let attempt = session.execute(.rejected(hazards: [.sunProximity]),
                                      observer: observer,
                                      date: date)

        XCTAssertEqual(attempt.outcome, .refused)
        XCTAssertEqual(transport.goToCount, 0,
                       "gerbang yang menolak tidak boleh memanggil perangkat sama sekali")
        XCTAssertEqual(transport.abortCount, 0)
    }

    func testAllowedDecisionReachesTheTransportExactlyOnce() {
        let transport = SpyTransport()
        let session = TelescopeSession(bridge: bridge(),
                                       transport: transport,
                                       commandPath: "seestar-community-v2")
        let attempt = session.execute(allowed(vega), observer: observer, date: date)

        XCTAssertEqual(attempt.outcome, .issued)
        XCTAssertEqual(transport.goToCount, 1)
        XCTAssertEqual(attempt.objectID, "vega")
        XCTAssertEqual(attempt.commandPath, "seestar-community-v2")
        XCTAssertEqual(attempt.firmwareVersion, transport.firmwareVersion,
                       "§18: versi firmware ikut tercatat di setiap percobaan")
    }

    func testTransportFailureIsRecordedAsFailedNotIssued() {
        let transport = SpyTransport()
        transport.goToError = StubError.timeout
        let session = TelescopeSession(bridge: bridge(),
                                       transport: transport,
                                       commandPath: "test-path")
        let attempt = session.execute(allowed(vega), observer: observer, date: date)

        XCTAssertEqual(attempt.outcome, .failed)
        XCTAssertNotNil(attempt.errorDescription)
        XCTAssertTrue(attempt.errorDescription?.contains("timeout") ?? false)
    }

    /// **§20.** Mount tanpa Abort tidak boleh menerima perintah sama sekali
    /// sampai risikonya diterima — bukan setelah perintah pertama terkirim.
    func testMountWithoutAbortIsRefusedBeforeAnyCommandIsBuilt() {
        let transport = SpyTransport()
        let session = TelescopeSession(bridge: bridge(canAbort: false),
                                       transport: transport,
                                       commandPath: "test-path")
        let attempt = session.execute(allowed(vega), observer: observer, date: date)

        XCTAssertEqual(attempt.outcome, .refused)
        XCTAssertEqual(transport.goToCount, 0)
        XCTAssertTrue(attempt.errorDescription?.contains("mountCannotAbort") ?? false)
    }

    func testMountWithoutAbortIsAllowedOnceTheRiskIsAccepted() {
        let transport = SpyTransport()
        let session = TelescopeSession(bridge: bridge(canAbort: false),
                                       transport: transport,
                                       commandPath: "test-path",
                                       acceptsNoAbort: true)
        let attempt = session.execute(allowed(vega), observer: observer, date: date)

        XCTAssertEqual(attempt.outcome, .issued)
        XCTAssertEqual(transport.goToCount, 1)
    }

    /// **§20.** Abort tidak boleh bergantung pada keadaan apa pun.
    func testAbortAlwaysReachesTheTransport() {
        let transport = SpyTransport()
        let session = TelescopeSession(bridge: bridge(),
                                       transport: transport,
                                       commandPath: "test-path")

        let attempt = session.abort(now: date)

        XCTAssertEqual(attempt.outcome, .aborted)
        XCTAssertEqual(transport.abortCount, 1,
                       "tombol darurat tidak boleh bisa mati sendiri")
    }

    func testAbortFailureIsReportedNotSwallowed() {
        let transport = SpyTransport()
        transport.abortError = StubError.disconnected
        let session = TelescopeSession(bridge: bridge(),
                                       transport: transport,
                                       commandPath: "test-path")

        let attempt = session.abort(now: date)

        XCTAssertEqual(attempt.outcome, .failed)
        XCTAssertTrue(attempt.errorDescription?.contains("disconnected") ?? false)
    }

    // MARK: - Log percobaan bisa diekspor (§18)

    func testAttemptArchiveRoundTripsThroughJSON() throws {
        let transport = SpyTransport()
        let session = TelescopeSession(bridge: bridge(),
                                       transport: transport,
                                       commandPath: "seestar-community-v2")
        let attempt = session.execute(allowed(vega), observer: observer, date: date)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([attempt])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([TelescopeAttempt].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].objectID, "vega")
        XCTAssertEqual(decoded[0].outcome, .issued)
        XCTAssertEqual(decoded[0].commandPath, "seestar-community-v2")
        guard case .equatorial(_, let frame) = decoded[0].target else {
            return XCTFail("kerangka harus ikut tersimpan — log yang kehilangan kerangka tidak bisa diaudit")
        }
        XCTAssertEqual(frame, .j2000)
    }

    // MARK: - Kebutuhan jaringan lokal (§19)

    func testBonjourDeclarationIsOnlyNeededWhenServiceTypesExist() {
        let withoutBonjour = TelescopeNetworkRequirements(usageDescription: "Untuk terhubung ke teleskop.")
        XCTAssertFalse(withoutBonjour.needsBonjourDeclaration)

        let withBonjour = TelescopeNetworkRequirements(usageDescription: "Untuk terhubung ke teleskop.",
                                                       bonjourServiceTypes: ["_seestar._tcp"])
        XCTAssertTrue(withBonjour.needsBonjourDeclaration)
        XCTAssertEqual(TelescopeNetworkRequirements.localNetworkUsageKey,
                       "NSLocalNetworkUsageDescription")
        XCTAssertEqual(TelescopeNetworkRequirements.bonjourServicesKey, "NSBonjourServices")
    }
}

// MARK: - Ganda uji

/// Efemeris palsu: Bulan bergerak 0,5°/jam ke arah RA naik.
private struct StubEphemeris: SolarSystemEphemeris {
    func apparent(_ body: EphemerisBody, at date: Date, from observer: Observer?) throws -> EphemerisSample {
        let hours = date.timeIntervalSince1970 / 3600.0
        return EphemerisSample(raDeg: (hours * 0.5).truncatingRemainder(dividingBy: 360),
                               decDeg: 10,
                               magnitude: -12)
    }
}

private enum StubError: Error, Equatable {
    case timeout
    case disconnected
}

/// Transport palsu yang mencatat setiap panggilan.
private final class SpyTransport: TelescopeTransport {
    var firmwareVersion: String = "seestar-4.12"
    var goToCount = 0
    var abortCount = 0
    var goToError: Error?
    var abortError: Error?

    func readState() throws -> TelescopeReadiness { .ready }

    func goTo(_ command: TelescopeCommand) throws {
        goToCount += 1
        if let goToError { throw goToError }
    }

    func abort() throws {
        abortCount += 1
        if let abortError { throw abortError }
    }
}
