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

    /// Jarak tetangga harus sampai ke cuplikan yang dibaca UI.
    ///
    /// Ini rantai yang sebelumnya putus: engine tahu jaraknya (dipakai untuk
    /// memutuskan ambiguitas) tetapi angka itu tidak pernah keluar dari
    /// `Resolution`, sehingga riwayat diagnostik selalu kehilangan dimensi
    /// ambiguitas — ragu karena dua bintang berdekatan akan tercatat sama
    /// seperti ragu karena kandidat jauh. Keduanya butuh perbaikan berbeda.
    func testAmbiguousLockExposesNearestNeighbourToDiagnostics() {
        let resolver = ambiguousResolver()
        let c = controller(resolver)
        let q = quaternion(viewPointingAt: siriusDirection(resolver))

        for step in 0..<12 {
            c.feed(quaternion: q, timestamp: at(Double(step) * 0.1))
        }

        XCTAssertEqual(c.snapshot.state, .uncertain)
        guard let neighbour = c.snapshot.nearestNeighbourDeg else {
            return XCTFail("jarak tetangga tidak sampai ke cuplikan")
        }
        XCTAssertLessThanOrEqual(neighbour, resolver.confidencePolicy.ambiguityDeg,
                                 "dua bintang berimpit seharusnya di dalam ambang ambiguitas")

        // Dan dengan angka itu, riwayat bisa menyebut sebabnya dengan benar.
        let trace = ConfidenceTrace()
        trace.record(snapshot: c.snapshot,
                     sigmaDeg: resolver.confidencePolicy.pointingSigmaDeg)
        guard let sample = trace.samples.last else { return XCTFail("tidak ada sampel") }
        XCTAssertEqual(trace.uncertainReason(for: sample,
                                             policy: resolver.confidencePolicy), .ambiguous)
    }

    /// Resolusi lama tidak boleh menempel saat tidak ada jawaban lagi.
    ///
    /// Setelah alur dihentikan, `lastResolution` dibuang; kalau cuplikan masih
    /// membawa jarak tetangga dari resolusi lama, riwayat akan mencatat angka
    /// dari pandangan sebelumnya seolah milik pandangan sekarang.
    func testStoppedFlowDoesNotCarryStaleNeighbourDistance() {
        let resolver = ambiguousResolver()
        let c = controller(resolver)
        let q = quaternion(viewPointingAt: siriusDirection(resolver))
        for step in 0..<12 {
            c.feed(quaternion: q, timestamp: at(Double(step) * 0.1))
        }
        XCTAssertNotNil(c.snapshot.nearestNeighbourDeg)

        c.stop()
        XCTAssertNil(c.snapshot.nearestNeighbourDeg)
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

    // MARK: - Lokasi

    /// Lokasi yang salah menggeser seluruh langit.
    ///
    /// Ini alasan mengapa lokasi **wajib** disambungkan ulang saat koordinat
    /// sungguhan tiba: engine yang tetap memakai lokasi bawaan akan menjawab
    /// dengan bintang yang salah, dan tidak ada bagian UI yang terlihat keliru.
    /// Uji ini membuktikan efeknya nyata, bukan teoretis.
    func testWrongObserverShiftsTheWholeSky() {
        let resolver = singleStarResolver()
        // Jakarta (lokasi bawaan app) vs Quito — garis bujur berbeda ~28°.
        let jakarta = PointingController(resolver: resolver,
                                         observer: Observer(latitudeDeg: -6.2, longitudeDeg: 106.8),
                                         config: PointingControllerConfig(coneDeg: 5))
        let quito = PointingController(resolver: resolver,
                                       observer: Observer(latitudeDeg: -0.18, longitudeDeg: -78.47),
                                       config: PointingControllerConfig(coneDeg: 5))

        let siriusAtJakarta = resolver.horizontal(of: sirius,
                                                  observer: jakarta.observer, date: date)!
        let siriusAtQuito = resolver.horizontal(of: sirius,
                                                observer: quito.observer, date: date)!

        // Langitnya benar-benar bergeser — ini bukan perbedaan kecil.
        let shift = SkyMath.angularSeparationHorizontalDeg(siriusAtJakarta, siriusAtQuito)
        XCTAssertGreaterThan(shift, 20,
                             "bujur berbeda 185° seharusnya menggeser langit jauh lebih dari 20°")

        // Arahkan tepat ke Sirius menurut Jakarta, lalu tanya engine Quito.
        let update = quito.feed(quaternion: quaternion(viewPointingAt: siriusAtJakarta),
                                timestamp: at(0))
        for step in 1..<12 {
            quito.feed(quaternion: quaternion(viewPointingAt: siriusAtJakarta),
                       timestamp: at(Double(step) * 0.1))
        }

        XCTAssertNotEqual(quito.snapshot.bestObject?.id, "sirius",
                          "lokasi yang salah seharusnya membuat bintangnya meleset")
        XCTAssertNotNil(update.snapshot.rawPointing,
                        "arah tunjuk tetap ada — yang salah adalah langitnya")
    }

    /// Memindahkan pengamat harus **membatalkan** jawaban yang dihitung untuk
    /// langit lama.
    ///
    /// Ini regresi yang pernah lolos: pembatalan dulu menumpang pada
    /// `apply(calibration:)` yang kebetulan menghentikan alur. Begitu
    /// pemasangan kalibrasi yang sama dijadikan tanpa-efek, perpindahan tempat
    /// berhenti membatalkan apa pun — dan objek dari langit lama tetap tampil
    /// seolah masih berlaku, tanpa satu pun bagian UI yang terlihat keliru.
    func testChangingObserverDropsAnswerComputedForOldSky() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))
        XCTAssertEqual(c.snapshot.state, .lock)
        XCTAssertNotNil(c.lastResolution)

        // Pindah jauh (Quito) — langit bergeser > 20°, jadi jawaban lama
        // tidak lagi sah untuk arah tunjuk yang sama.
        c.setObserver(Observer(latitudeDeg: -0.18, longitudeDeg: -78.47))

        XCTAssertEqual(c.snapshot.state, .idle,
                       "jawaban langit lama tidak boleh tetap tampil setelah pindah")
        XCTAssertNil(c.snapshot.intent)
        XCTAssertNil(c.lastResolution,
                     "resolusi lama dihitung untuk langit lama")
    }

    /// Memasang pengamat yang **sama** bukan perubahan: langitnya tidak
    /// bergeser, jadi jawaban yang sudah benar tidak boleh dibuang. Ini yang
    /// membuat pembaruan lokasi berulang dari tempat yang sama tidak mematikan
    /// kunci yang baru saja didapat.
    func testReapplyingSameObserverIsANoOp() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))
        XCTAssertEqual(c.snapshot.state, .lock)

        c.setObserver(observer)

        XCTAssertEqual(c.snapshot.state, .lock)
        XCTAssertNotNil(c.snapshot.intent)
    }

    /// Pindah tempat tidak boleh membuang kalibrasi: offset yaw adalah sifat
    /// pemasangan jam, bukan sifat tempat.
    func testChangingObserverKeepsCalibration() {
        let resolver = singleStarResolver()
        let calibration = PointingCalibration(yawOffsetDeg: 7, residualSpreadDeg: 1, sampleCount: 3)
        let c = controller(resolver, calibration: calibration)

        c.setObserver(Observer(latitudeDeg: -0.18, longitudeDeg: -78.47))

        XCTAssertEqual(c.calibration, calibration)
        XCTAssertTrue(c.snapshot.isCalibrated)
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

    /// Memasang kalibrasi yang **sedang berlaku** bukan perubahan: tidak boleh
    /// mereset perata orientasi atau menghentikan alur.
    ///
    /// Tanpa ini, pemanggil yang mengulang kalibrasi yang sama — mis. UI yang
    /// menyegarkan tampilan setelah mencatat acuan, atau
    /// `PointingEngine.update(location:)` yang mempertahankan kalibrasi —
    /// membuang kunci yang sudah benar, persis saat pengguna sedang
    /// mengkalibrasi.
    func testReapplyingSameCalibrationIsANoOp() {
        let resolver = singleStarResolver()
        let calibration = PointingCalibration(yawOffsetDeg: 3, residualSpreadDeg: 1, sampleCount: 2)
        let c = controller(resolver, calibration: calibration)
        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))
        XCTAssertEqual(c.snapshot.state, .lock)

        c.apply(calibration: calibration)

        XCTAssertEqual(c.snapshot.state, .lock,
                       "kalibrasi yang sama tidak boleh membuang kunci yang sudah benar")
        XCTAssertNotNil(c.snapshot.intent)
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

    // MARK: - Ambang keyakinan yang bisa berubah

    /// Mengubah ambang harus benar-benar mengubah keputusan, dan jawaban lama
    /// yang dihitung dengan ambang sebelumnya tidak boleh tetap tampil.
    func testSettingConfidencePolicyChangesDecisionsAndStopsFlow() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))
        XCTAssertEqual(c.snapshot.state, .lock)

        // Sigma jauh lebih ketat: kandidat yang tadinya dianggap dekat kini
        // di luar ambang, jadi keyakinan harus turun.
        XCTAssertTrue(c.setConfidencePolicy(ConfidencePolicy(pointingSigmaDeg: 0.01)))
        XCTAssertEqual(c.snapshot.state, .idle, "alur harus dihentikan saat ambang berubah")
        XCTAssertNil(c.lastResolution, "resolusi lama dihitung dengan ambang lama")
    }

    /// Ambang yang tidak masuk akal ditolak, bukan diterapkan.
    func testInvalidConfidencePolicyIsRejected() {
        let c = controller(singleStarResolver())
        let original = c.resolver.confidencePolicy
        for bad in [0.0, -1.0, .infinity, .nan] {
            XCTAssertFalse(c.setConfidencePolicy(ConfidencePolicy(pointingSigmaDeg: bad)),
                           "sigma \(bad) tidak boleh diterima")
        }
        XCTAssertEqual(c.resolver.confidencePolicy, original)
    }

    /// Jawaban yang berlaku hanya ada saat keadaan memang punya jawaban.
    ///
    /// Ini yang membuat Experiment 1 tidak mencatat false lock karangan:
    /// jawaban dari arah tunjuk sebelumnya tidak boleh dianggap jawaban untuk
    /// arah sekarang.
    func testAnsweredIntentOnlyExistsWhenStateHasAnswer() {
        let resolver = singleStarResolver()
        let c = controller(resolver)
        XCTAssertNil(c.answeredIntent, "idle tidak punya jawaban")

        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))
        XCTAssertEqual(c.answeredIntent?.best?.id, "sirius")

        // Arahkan ke tempat lain: keadaan kembali menunjuk, jawaban lama
        // dipertahankan untuk tampilan tapi tidak lagi berlaku.
        let elsewhere = quaternion(viewPointingAt: HorizontalCoord(altitudeDeg: 60,
                                                                  azimuthDeg: 250))
        c.feed(quaternion: elsewhere, timestamp: at(5.0))
        XCTAssertEqual(c.snapshot.state, .pointing)
        XCTAssertNil(c.answeredIntent)
    }

    /// Rencana GoTo tidak boleh berasal dari resolusi yang sudah tidak berlaku.
    ///
    /// `lastResolution` sengaja dipertahankan agar cuplikan tetap membawa jarak
    /// tetangga untuk diagnostik, dan ia hanya dibuang saat alur **dihentikan**
    /// (atau saat lokasi/ambang berubah) — **bukan** saat arah tunjuk bergeser
    /// dan keadaan kehilangan jawabannya. Jadi selama pergelangan bergerak,
    /// `lastResolution` masih berisi resolusi dari arah tunjuk **sebelumnya**.
    /// Membacanya mentah berarti teleskop bisa diarahkan ke objek yang sudah
    /// tidak ada di arah tunjuk sekarang — persis aturan keras PRD
    /// "POINT → OBJECT ID → SAFE GOTO", dengan langkah OBJECT ID dilewati.
    /// Yang menentukan adalah apakah keadaan **punya jawaban sekarang**.
    func testSlewDecisionRefusedWhenAnswerIsStale() {
        let resolver = resolverWithEphemeris()
        let c = controller(resolver)
        let policy = SlewSafetyPolicy(minSunSeparationDeg: 0,
                                      minAltitudeDeg: -90,
                                      maxAltitudeDeg: 90,
                                      limitingMagnitude: 30,
                                      requiredConfidence: .high)

        lockController(c, quaternion: quaternion(viewPointingAt: siriusDirection(resolver)))
        XCTAssertEqual(c.snapshot.state, .lock)
        XCTAssertTrue(try! XCTUnwrap(c.slewDecision(date: at(1.2), policy: policy)).isAllowed)

        // Arahkan ke tempat lain: keadaan kembali `pointing` dan tidak punya
        // jawaban sekarang — tapi resolusi Sirius masih tersimpan.
        let elsewhere = quaternion(viewPointingAt: HorizontalCoord(altitudeDeg: 60,
                                                                  azimuthDeg: 250))
        c.feed(quaternion: elsewhere, timestamp: at(5.0))
        XCTAssertEqual(c.snapshot.state, .pointing)
        XCTAssertNil(c.answeredIntent, "keadaan tanpa jawaban")

        XCTAssertNil(c.slewDecision(date: at(5.0), policy: policy),
                     "GoTo tidak boleh dihitung dari resolusi arah tunjuk sebelumnya")
    }

    // MARK: - Matahari: jangan pernah terkunci

    /// Mengarahkan jam **langsung ke Matahari** tidak boleh menghasilkan
    /// `.lock`, haptic sukses, atau izin GoTo — lewat alur controller nyata,
    /// bukan cuma resolver.
    ///
    /// `testSunIsNeverACandidate` di paket engine membuktikan resolver menolak
    /// Matahari. Tapi antara resolver dan `.lock` ada perata, mesin keadaan,
    /// dan `hapticEvents` — satu-satunya lapisan yang memicu haptic **dan**
    /// membuka izin GoTo. Kalau salah satu lapisan itu bocor, pengguna
    /// mendapat getaran "berhasil" sambil menunjuk Matahari, dan status
    /// `.lock` membuka jalur ke rencana GoTo. Ini aturan keras PRD:
    /// POINT → OBJECT ID → SAFE GOTO, dan pergelangan **tidak pernah** boleh
    /// menjadi gerak motor.
    ///
    /// Resolver dibangun **dengan efemeris penuh** tapi tanpa katalog bintang,
    /// jadi satu-satunya benda tata surya yang dipertimbangkan adalah Bulan,
    /// planet, dan Matahari — dan Matahari sudah disingkirkan dari
    /// `pointableBodies`. Menunjuk Matahari jatuh ke `low`/`searching`, bukan
    /// ke `.lock`.
    func testAimingAtTheSunNeverLocksOrFiresSuccessHaptic() throws {
        let ephemeris = AstronomyKitEphemeris()
        let resolver = PointingResolver(catalogue: [],
                                       policy: .permissive,
                                       ephemeris: ephemeris)
        // Posisi Matahari diambil langsung dari efemeris (resolver sengaja
        // menolak menghitung arahnya — `isPointable` salah untuk `.sun`), lalu
        // diubah ke horizontal seperti yang dilakukan resolver untuk benda lain.
        //
        // Dipakai **tengah hari** Jakarta (Matahari tinggi) agar gerbang
        // pengaman benar-benar tersentuh: saat Matahari di bawah horizon, jarak
        // arah tunjuk ke Matahari tidak relevan dan uji jadi vacuous.
        let noon = Date(timeIntervalSince1970: 1_768_453_200)
        let sunSample = try ephemeris.apparent(.sun, at: noon, from: observer)
        let jd = SkyMath.julianDate(from: noon)
        let sunHor = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sunSample.raDeg, decDeg: sunSample.decDeg),
            observer: observer, jd: jd)
        let c = controller(resolver)


        // Tahan arah tunjuk ke Matahari cukup lama untuk melewati ambang
        // "pergelangan diam" dan memicu resolusi lengkap berulang kali.
        let q = quaternion(viewPointingAt: sunHor)
        for step in 0..<12 {
            c.feed(quaternion: q, timestamp: at(Double(step) * 0.1))
        }

        XCTAssertNotEqual(c.snapshot.state, .lock,
                         "menunjuk Matahari tidak boleh mengunci")
        XCTAssertFalse(c.hapticLog.contains { $0.event == .lockSucceeded },
                       "tidak boleh ada haptic sukses saat menunjuk Matahari")
        XCTAssertNil(c.slewDecision(date: at(1.5)),
                     "tidak boleh ada rencana GoTo untuk Matahari")
        // Dan Matahari benar-benar tidak pernah muncul sebagai jawaban.
        XCTAssertNotEqual(c.snapshot.bestObject?.id, "sun")
    }

    // MARK: - Objek langit dalam lewat controller penuh

    /// Objek langit dalam harus bisa mencapai `.lock` lewat **controller
    /// sungguhan**, bukan hanya lewat resolver.
    ///
    /// Katalog, resolver, visual, dan label untuk objek langit dalam sudah
    /// diuji masing-masing — tapi tidak satu pun uji yang menembaknya lewat
    /// `PointingController` sampai ke `.lock` dan rencana GoTo. Ini kelas
    /// cacat yang berulang di repo ini: bagian-bagiannya benar, jalur yang
    /// menghubungkannya tidak pernah disambungkan. Kalau suatu hari jalur
    /// controller membuang objek ber-`kind: .deepSky` (misal lewat filter
    /// jenis di tempat lain), seluruh rangkaian uji di atas tetap hijau
    /// sementara aplikasi tidak pernah mengunci satu nebula pun.
    func testDeepSkyObjectLocksThroughTheFullController() throws {
        // Nebula Orion: satu-satunya objek di kerucut, kebijakan permisif →
        // HIGH deterministik, tanpa ambiguitas bintang tetangga.
        let ephemeris = AstronomyKitEphemeris()
        let nebula = CelestialObject(id: "m42", name: "Nebula Orion", kind: .deepSky,
                                     raDeg: 83.82208333, decDeg: -5.39111111, magnitude: 4.0)
        // Resolver pakai efemeris supaya rencana GoTo bisa menghitung posisi
        // Matahari (aman), bukan menolak dengan `sunPositionUnknown`.
        let resolver = PointingResolver(catalogue: [nebula], policy: .permissive,
                                       ephemeris: ephemeris)
        let c = controller(resolver)

        // Cari waktu malam ketika nebulanya benar-benar di atas horizon, supaya
        // uji ini tidak vacuous: kalau tidak pernah naik, kegagalan "tidak
        // terkunci" bisa datang dari horizon, bukan dari jalur controller.
        // Malam dipilih agar gerbang pengaman Matahari tidak membatalkan arah
        // tunjuk, dan rencana GoTo tidak menghadapi hazard dekat-Matahari.
        var when: Date?
        for hour in 0..<48 {
            let candidate = date.addingTimeInterval(Double(hour) * 3600)
            let aboveHorizon = (resolver.horizontal(of: nebula, observer: observer,
                                                   date: candidate)?.altitudeDeg ?? -90) > 20
            // Malam dipilih dengan ambang tetap (Matahari jauh di bawah
            // horizon), bukan `policy.minAltitudeDeg`: kebijakan `.permissive`
            // memang memakai ambang −90, jadi memakainya akan membuat cek
            // "malam" tidak pernah benar. Ambang −10° cukup sebagai bukti malam
            // sungguhan; siang bukanlah keadaan yang ingin diuji di sini.
            let sunDown = (resolver.skyContext(observer: observer, date: candidate)
                .sunAltitudeDeg) < -10
            if aboveHorizon && sunDown {
                when = candidate
                break
            }
        }
        guard let targetDate = when else {
            return XCTFail("M42 tidak pernah di atas horizon pada malam hari dalam 48 jam — uji tidak bisa membuktikan apa pun")
        }
        let dir = resolver.horizontal(of: nebula, observer: observer, date: targetDate)!

        // Tahan arah tunjuk ke nebula cukup lama untuk melewati ambang
        // "pergelangan diam" dan memicu resolusi berulang.
        let q = quaternion(viewPointingAt: dir)
        for step in 0..<12 {
            c.feed(quaternion: q, timestamp: targetDate.addingTimeInterval(Double(step) * 0.1))
        }

        XCTAssertEqual(c.snapshot.state, .lock, "objek langit dalam harus bisa dikunci lewat controller")
        XCTAssertEqual(c.snapshot.bestObject?.id, "m42")
        XCTAssertEqual(c.snapshot.bestObject?.kind, .deepSky)
        XCTAssertTrue(c.hapticLog.contains { $0.event == .lockSucceeded },
                      "lock berhasil harus berbunyi haptic")

        // GoTo harus aman dan menarget posisi objek, bukan arah pergelangan.
        let policy = SlewSafetyPolicy(minSunSeparationDeg: 0,
                                      minAltitudeDeg: -90,
                                      maxAltitudeDeg: 90,
                                      limitingMagnitude: 30,
                                      requiredConfidence: .high)
        let decision = try XCTUnwrap(c.slewDecision(date: targetDate, policy: policy))
        guard case .allowed(let command) = decision else {
            return XCTFail("GoTo untuk objek langit dalam seharusnya diizinkan, dapat \(decision)")
        }
        XCTAssertEqual(command.object.id, "m42")
        let truth = resolver.horizontal(ofObjectID: "m42", observer: observer, date: targetDate)!
        XCTAssertEqual(command.target.altitudeDeg, truth.altitudeDeg, accuracy: 1e-9)
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
