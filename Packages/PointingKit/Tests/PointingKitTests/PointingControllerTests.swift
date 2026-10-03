import XCTest
import CelestialEngine
@testable import PointingKit

/// Alur lapisan app: sensor → arah tunjuk → keadaan → haptic → rencana GoTo.
///
/// Semua uji di sini berjalan di Linux karena controller sengaja tidak
/// menyentuh CoreMotion. Yang diuji adalah keputusan, bukan pembacaan sensor.
final class PointingControllerTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private let sirius = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                         raDeg: 101.28715533, decDeg: -16.71611586,
                                         magnitude: -1.46)

    /// Resolver dengan satu bintang saja → keyakinan HIGH deterministik.
    private func singleStarResolver() -> PointingResolver {
        PointingResolver(catalogue: [sirius], policy: .permissive)
    }

    /// Resolver dengan dua bintang berimpit → selalu ambigu → MEDIUM.
    private func ambiguousResolver() -> PointingResolver {
        let twin = CelestialObject(id: "twin", name: "Twin", kind: .star,
                                   raDeg: sirius.raDeg + 0.02, decDeg: sirius.decDeg,
                                   magnitude: 1.0)
        return PointingResolver(catalogue: [sirius, twin], policy: .permissive)
    }

    private func resolverWithEphemeris() -> PointingResolver {
        PointingResolver(catalogue: [sirius], policy: .permissive,
                         ephemeris: AstronomyKitEphemeris())
    }

    private func siriusDirection(_ resolver: PointingResolver) -> HorizontalCoord {
        resolver.horizontal(of: sirius, observer: observer, date: date)!
    }

    private func at(_ seconds: Double) -> Date { date.addingTimeInterval(seconds) }

    /// Bangun quaternion yang sumbu pandangnya mengarah ke `target`.
    /// Dipakai sebagai "sensor sempurna".
    private func quaternion(viewPointingAt target: HorizontalCoord) -> Quaternion {
        let v = LocalFrame.enuFromHorizontal(target)
        let d = Vector3(x: v.y, y: v.z, z: v.x)   // balik pemetaan roll=0
        let from = Vector3.unitZ
        let axis = from.cross(d)
        if axis.magnitude < 1e-12 { return .identity }
        let angle = acos(max(-1.0, min(1.0, from.dot(d))))
        return Quaternion.axisAngle(axis: axis, radians: angle)!
    }

    private func controller(_ resolver: PointingResolver,
                            calibration: PointingCalibration = .none) -> PointingController {
        PointingController(resolver: resolver,
                           observer: observer,
                           config: PointingControllerConfig(coneDeg: 5.0),
                           calibration: calibration)
    }

    // MARK: - Keadaan awal & sensor

    func testStartsIdleWhenSensorAvailable() {
        let c = controller(singleStarResolver())
        XCTAssertEqual(c.snapshot.state, .idle)
        XCTAssertTrue(c.snapshot.hasSensor)
        XCTAssertFalse(c.snapshot.isCalibrated)
        XCTAssertNil(c.snapshot.intent)
    }

    func testMissingSensorNeverGuesses() {
        let c = PointingController(resolver: singleStarResolver(),
                                   observer: observer,
                                   isSensorAvailable: false)
        XCTAssertEqual(c.snapshot.state, .unavailable)

        // Sampel tidak sah tidak boleh menghasilkan jawaban apa pun.
        let update = c.feed(cmX: 0, cmY: 0, cmZ: 0, cmW: 0, timestamp: at(0))
        XCTAssertEqual(update.snapshot.state, .unavailable)
        XCTAssertNil(update.snapshot.intent)
        XCTAssertTrue(update.haptics.isEmpty)
    }

    /// Sensor yang sempat hilang boleh pulih — tapi hanya setelah ada sampel
    /// yang benar-benar sah, bukan karena waktu berlalu.
    func testSensorRecoversOnlyOnValidSample() {
        let resolver = singleStarResolver()
        let c = PointingController(resolver: resolver, observer: observer,
                                   isSensorAvailable: false)
        XCTAssertEqual(c.snapshot.state, .unavailable)

        let q = quaternion(viewPointingAt: siriusDirection(resolver))
        // Jalur sensor platform: CMDeviceMotion → controller.
        let recovered = c.feed(cmX: q.x, cmY: q.y, cmZ: q.z, cmW: q.w, timestamp: at(0))
        XCTAssertTrue(recovered.snapshot.hasSensor)
        XCTAssertEqual(recovered.snapshot.state, .pointing)
    }

    /// Sensor hilang saat sudah terkunci harus **langsung** membatalkan
    /// tampilan terkunci. Membiarkannya berarti objek terakhir tetap terlihat
    /// terkonfirmasi padahal tidak ada data.
    func testSensorLossDropsLockAndFiresHaptic() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        let q = quaternion(viewPointingAt: siriusDirection(resolver))
        lockController(c, quaternion: q)
        XCTAssertEqual(c.snapshot.state, .lock)

        let events = c.setSensorAvailable(false)
        XCTAssertEqual(c.snapshot.state, .unavailable)
        XCTAssertEqual(events, [.sensorUnavailable])
        XCTAssertNil(c.snapshot.intent)
    }

    /// Quaternion nol dari sensor tidak boleh menghasilkan arah karangan.
    func testInvalidQuaternionDoesNotProduceDirection() {
        let c = controller(singleStarResolver())
        let update = c.feed(cmX: 0, cmY: 0, cmZ: 0, cmW: 0, timestamp: at(0))
        XCTAssertEqual(update.snapshot.state, .unavailable)
        XCTAssertNil(update.snapshot.rawPointing)
        XCTAssertNil(update.snapshot.intent)
    }

    // MARK: - Alur menuju lock

    /// Sampel pertama belum punya pembanding → dianggap masih bergerak.
    func testFirstSampleIsPointing() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        let update = c.feed(quaternion: quaternion(viewPointingAt: siriusDirection(resolver)),
                            timestamp: at(0))
        XCTAssertEqual(update.snapshot.state, .pointing)
        XCTAssertTrue(update.haptics.isEmpty)
    }

    func testHoldsStillThenLocksAndFiresHapticExactlyOnce() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        let q = quaternion(viewPointingAt: siriusDirection(resolver))

        var allEvents: [HapticEvent] = []
        var lockedAt: Double?
        for step in 0..<12 {
            let t = at(Double(step) * 0.1)
            let update = c.feed(quaternion: q, timestamp: t)
            allEvents.append(contentsOf: update.haptics)
            if update.snapshot.state == .lock && lockedAt == nil { lockedAt = Double(step) * 0.1 }
        }

        XCTAssertEqual(c.snapshot.state, .lock)
        XCTAssertEqual(c.snapshot.bestObject?.id, "sirius")
        XCTAssertNotNil(lockedAt)
        XCTAssertGreaterThanOrEqual(lockedAt!, 0.4, "harus menunggu pergelangan diam")
        XCTAssertEqual(allEvents, [.lockSucceeded],
                       "getaran sukses harus berbunyi sekali, bukan tiap sampel")
    }

    /// Keyakinan MEDIUM tidak boleh terasa seperti sukses.
    func testAmbiguousCandidatesGiveUncertainHapticNotSuccess() {
        let resolver = ambiguousResolver()
        let c = controller(resolver)
        let q = quaternion(viewPointingAt: siriusDirection(resolver))

        var events: [HapticEvent] = []
        for step in 0..<12 {
            events.append(contentsOf: c.feed(quaternion: q, timestamp: at(Double(step) * 0.1)).haptics)
        }

        XCTAssertEqual(c.snapshot.state, .uncertain)
        XCTAssertNotNil(c.snapshot.bestObject, "kandidat tetap ditampilkan, tapi sebagai ragu")
        XCTAssertEqual(events, [.uncertain])
        XCTAssertFalse(events.contains(.lockSucceeded), "ragu tidak boleh terasa seperti sukses")
    }

    /// Tidak ada kandidat → searching, tanpa getaran jawaban.
    func testNoCandidateStaysSearchingSilently() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        // Arahkan jauh dari satu-satunya bintang di katalog.
        let away = HorizontalCoord(altitudeDeg: 60, azimuthDeg: 270)
        var events: [HapticEvent] = []
        for step in 0..<12 {
            events.append(contentsOf: c.feed(quaternion: quaternion(viewPointingAt: away),
                                             timestamp: at(Double(step) * 0.1)).haptics)
        }
        XCTAssertEqual(c.snapshot.state, .searching)
        XCTAssertNil(c.snapshot.bestObject)
        XCTAssertTrue(events.isEmpty)
    }

    /// Bergerak lagi setelah terkunci harus membatalkan kunci.
    func testMovingAfterLockUnlocks() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        let q = quaternion(viewPointingAt: siriusDirection(resolver))
        lockController(c, quaternion: q)
        XCTAssertEqual(c.snapshot.state, .lock)

        // Sapuan cepat: 120° dalam 0.1 dtk.
        let swept = Quaternion.axisAngle(axis: Vector3.unitZ, radians: SkyMath.deg2rad(120))!
        let update = c.feed(quaternion: swept, timestamp: at(2.0))
        XCTAssertEqual(update.snapshot.state, .pointing)
    }

    func testStopReturnsToIdleAndFiresHaptic() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))
        let events = c.stop()
        XCTAssertEqual(c.snapshot.state, .idle)
        XCTAssertEqual(events, [.returnedToIdle])
        XCTAssertNil(c.snapshot.intent)
    }

    // MARK: - Kalibrasi

    /// Kalibrasi hanya boleh menggeser azimut, tidak pernah altitude.
    func testCalibrationShiftsAzimuthOnly() {
        let resolver = singleStarResolver()
        let raw = siriusDirection(resolver)
        let c = controller(resolver, calibration: PointingCalibration(yawOffsetDeg: 25,
                                                                      residualSpreadDeg: 2,
                                                                      sampleCount: 3))
        let update = c.feed(quaternion: quaternion(viewPointingAt: raw), timestamp: at(0))

        let rawPointing = try! XCTUnwrap(update.snapshot.rawPointing)
        let calibrated = try! XCTUnwrap(update.snapshot.calibratedPointing)
        XCTAssertEqual(rawPointing.altitudeDeg, calibrated.altitudeDeg, accuracy: 1e-9)
        XCTAssertEqual(SkyMath.normalizeDeg(rawPointing.azimuthDeg + 25),
                       calibrated.azimuthDeg, accuracy: 1e-9)
        XCTAssertTrue(update.snapshot.isCalibrated)
    }

    /// Offset kalibrasi yang salah harus **membuat engine meleset** — inilah
    /// kenapa kalibrasi tidak boleh dipasang sebelum sebarannya terukur.
    func testWrongCalibrationMakesEngineMiss() {
        let resolver = singleStarResolver()
        let raw = siriusDirection(resolver)
        let wrong = PointingCalibration(yawOffsetDeg: 40, residualSpreadDeg: 1, sampleCount: 2)
        let c = controller(resolver, calibration: wrong)
        for step in 0..<12 {
            c.feed(quaternion: quaternion(viewPointingAt: raw), timestamp: at(Double(step) * 0.1))
        }
        XCTAssertNotEqual(c.snapshot.state, .lock, "offset 40° harus merusak jawaban, bukan menyembunyikannya")
    }

    func testApplyingCalibrationResetsFlow() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))
        XCTAssertEqual(c.snapshot.state, .lock)

        c.apply(calibration: PointingCalibration(yawOffsetDeg: 3, residualSpreadDeg: 1, sampleCount: 2))
        XCTAssertEqual(c.snapshot.state, .idle)
        XCTAssertNil(c.snapshot.intent)
        XCTAssertTrue(c.snapshot.isCalibrated)
    }

    // MARK: - Rencana GoTo (aturan keras PRD)

    /// Tanpa posisi Matahari yang diketahui, GoTo **ditolak**. Gagal-tertutup.
    func testSlewRefusedWhenSunPositionUnknown() {
        let resolver = singleStarResolver()   // tanpa efemeris
        let c = controller(resolver)
        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))

        let decision = try! XCTUnwrap(c.slewDecision(date: at(2.0)))
        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.hazards.contains(.sunPositionUnknown))
    }

    /// Target GoTo harus posisi objek, bukan arah tunjuk pergelangan.
    func testSlewTargetComesFromObjectNotWristAngle() {
        let resolver = resolverWithEphemeris()
        let truth = siriusDirection(resolver)
        let c = controller(resolver)

        // Tunjuk meleset 4° dari Sirius: masih teridentifikasi, tapi arah tunjuk
        // ≠ arah objek.
        let off = HorizontalCoord(altitudeDeg: truth.altitudeDeg - 4,
                                  azimuthDeg: truth.azimuthDeg)
        lockController(c, quaternion: quaternion(viewPointingAt: off))
        XCTAssertEqual(c.snapshot.state, .lock)
        XCTAssertEqual(c.snapshot.bestObject?.id, "sirius")

        let policy = SlewSafetyPolicy(minSunSeparationDeg: 0,
                                      minAltitudeDeg: -90,
                                      maxAltitudeDeg: 90,
                                      limitingMagnitude: 30,
                                      requiredConfidence: .high)
        // Keputusan dihitung pada waktu yang sama dengan arah kebenarannya —
        // Sirius bergerak ~0.008°/2 dtk, dan toleransi di sini 1e-9.
        let decisionDate = at(2.0)
        let truthAtDecision = resolver.horizontal(ofObjectID: "sirius",
                                                  observer: observer,
                                                  date: decisionDate)!
        let decision = try! XCTUnwrap(c.slewDecision(date: decisionDate, policy: policy))
        guard case .allowed(let command) = decision else {
            return XCTFail("GoTo seharusnya diizinkan, dapat \(decision)")
        }
        XCTAssertEqual(command.object.id, "sirius")
        // Inilah inti aturan PRD.
        XCTAssertEqual(command.target.altitudeDeg, truthAtDecision.altitudeDeg, accuracy: 1e-9)
        XCTAssertNotEqual(command.target.altitudeDeg, off.altitudeDeg, accuracy: 1.0)
    }

    /// Ragu (MEDIUM) tidak boleh memicu GoTo.
    func testSlewRefusedWhenUncertain() {
        let resolver = ambiguousResolver()
        let c = controller(resolver)
        let q = quaternion(viewPointingAt: siriusDirection(resolver))
        for step in 0..<12 {
            c.feed(quaternion: q, timestamp: at(Double(step) * 0.1))
        }
        XCTAssertEqual(c.snapshot.state, .uncertain)

        let decision = try! XCTUnwrap(c.slewDecision(date: at(2.0)))
        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.hazards.contains(.lowConfidence))
    }

    func testSlewDecisionNilBeforeAnyResolution() {
        let c = controller(singleStarResolver())
        XCTAssertNil(c.slewDecision(date: at(0)))
    }

    // MARK: - Bantu

    /// Beri sampel sampai controller terkunci (atau gagal, yang akan membuat
    /// uji gagal di tempat lain).
    private func lockController(_ c: PointingController, quaternion q: Quaternion) {
        for step in 0..<12 {
            c.feed(quaternion: q, timestamp: at(Double(step) * 0.1))
        }
    }
}
