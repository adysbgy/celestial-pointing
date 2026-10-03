import XCTest
import CelestialEngine
@testable import PointingKit

/// Alur kalibrasi yang menyentuh controller sungguhan.
final class CalibrationSessionTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    /// Katalog empat bintang yang selalu terang dan tersebar.
    private func resolver() -> PointingResolver {
        let wanted = ["sirius", "vega", "arcturus", "capella"]
        return PointingResolver(catalogue: Catalogue.brightStars.filter { wanted.contains($0.id) },
                                policy: .permissive)
    }

    private func controller() -> PointingController {
        PointingController(resolver: resolver(),
                           observer: observer,
                           config: PointingControllerConfig(coneDeg: 5))
    }

    /// Arah tunjuk yang meleset dari kebenaran dengan offset yaw tertentu.
    private func measured(_ id: String, yawError: Double, date: Date) -> HorizontalCoord {
        let truth = controller().resolver.horizontal(ofObjectID: id, observer: observer, date: date)!
        return HorizontalCoord(altitudeDeg: truth.altitudeDeg,
                               azimuthDeg: SkyMath.normalizeDeg(truth.azimuthDeg - yawError))
    }

    /// Bintang acuan yang sedang di atas horizon pada waktu uji ini.
    private func visibleReferences() -> [String] {
        let r = resolver()
        return ["sirius", "vega", "arcturus", "capella"].filter {
            r.horizontal(ofObjectID: $0, observer: observer, date: date)!.altitudeDeg > 0
        }
    }

    // MARK: - Daftar acuan

    func testReferenceTargetsComeFromFlowNotWholeCatalogue() {
        let session = CalibrationSession(controller: controller())
        XCTAssertFalse(session.referenceTargets.isEmpty)
        let allowed = Set(CalibrationFlow.defaultReferences.map(\.id))
        for target in session.referenceTargets {
            XCTAssertTrue(allowed.contains(target.id), "\(target.id) bukan acuan bawaan")
            XCTAssertGreaterThan(target.direction.altitudeDeg, 0)
        }
    }

    /// Daftar acuan harus dihitung untuk **tempat sekarang**, bukan tempat lama.
    ///
    /// Bintang yang tampak di atas horizon di satu tempat bisa sudah terbenam di
    /// tempat lain. Lokasi sungguhan tiba beberapa detik setelah layar kalibrasi
    /// dibuka, jadi tanpa sinyal basi ini daftar tetap berisi bintang tempat
    /// lama — pengguna memilihnya, lalu offset kalibrasi dihitung dari kebenaran
    /// yang tidak ada di langitnya, dan kesalahannya tidak terlihat.
    func testReferenceListBecomesStaleWhenObserverMoves() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        XCTAssertFalse(session.isReferenceListStale, "baru dihitung: belum basi")

        c.setObserver(Observer(latitudeDeg: -0.18, longitudeDeg: -78.47))

        XCTAssertTrue(session.isReferenceListStale,
                      "daftar masih dihitung untuk langit tempat lama")

        session.refreshReferenceTargets()
        XCTAssertFalse(session.isReferenceListStale, "sudah dihitung ulang")
        XCTAssertEqual(session.referenceObserver, c.observer)
    }

    /// Perhitungan ulang yang tidak mengubah apa pun tidak boleh dianggap basi
    /// hanya karena waktunya berbeda — yang menentukan adalah **tempatnya**.
    func testReferenceListStaysFreshWhenOnlyTimeChanges() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        session.refreshReferenceTargets()
        XCTAssertFalse(session.isReferenceListStale)
    }

    // MARK: - Pencatatan

    func testCaptureWithoutPointingRecordsNothing() {
        let session = CalibrationSession(controller: controller())
        let step = session.capture(objectID: "sirius", measured: nil)
        XCTAssertTrue(session.flow.samples.isEmpty)
        XCTAssertTrue(step.message.contains("Belum ada arah tunjuk"))
    }

    func testCaptureUnknownObjectRecordsNothing() {
        let session = CalibrationSession(controller: controller())
        let step = session.capture(objectID: "tidak-ada",
                                   measured: HorizontalCoord(altitudeDeg: 30, azimuthDeg: 90))
        XCTAssertTrue(session.flow.samples.isEmpty)
        XCTAssertTrue(step.message.contains("tidak bisa dihitung"))
    }

    /// Kalibrasi yang konsisten harus siap, dan memasangnya harus benar-benar
    /// mengubah controller.
    func testConsistentCaptureBecomesReadyAndAppliesToController() throws {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        try XCTSkipIf(references.count < 2, "butuh minimal dua bintang acuan di atas horizon")

        let yawError = 9.0
        for id in references.prefix(3) {
            session.capture(objectID: id, measured: measured(id, yawError: yawError, date: date), date: date)
        }

        XCTAssertTrue(session.flow.isReady, "sebaran harus cukup sempit: \(session.flow.currentUpdate.message)")
        let applied = try XCTUnwrap(session.applyIfReady())
        XCTAssertEqual(applied.yawOffsetDeg, yawError, accuracy: 0.5)
        XCTAssertEqual(c.calibration.yawOffsetDeg, applied.yawOffsetDeg, accuracy: 1e-12)
        XCTAssertEqual(session.flow.phase, .applied)
        XCTAssertTrue(c.snapshot.isCalibrated)
    }

    func testApplyIsRefusedWhileNotReady() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        XCTAssertNil(session.applyIfReady(), "satu acuan tidak boleh dipasang")
        XCTAssertEqual(c.calibration, .none)
    }

    /// Acuan yang tidak konsisten harus menahan pemasangan — bukan dipasang
    /// dengan offset asal-asalan.
    func testInconsistentCaptureIsNotApplicable() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        guard references.count >= 2 else { return }

        session.capture(objectID: references[0],
                        measured: measured(references[0], yawError: -40, date: date), date: date)
        session.capture(objectID: references[1],
                        measured: measured(references[1], yawError: 40, date: date), date: date)

        XCTAssertFalse(session.flow.isReady)
        XCTAssertNil(session.applyIfReady())
        XCTAssertEqual(c.calibration, .none)
    }

    // MARK: - Pencocokan ke target terdekat

    /// Menunjuk tepat ke sebuah bintang harus mengenali bintang itu.
    func testCaptureNearestIdentifiesThePointedStar() throws {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        try XCTSkipIf(references.isEmpty, "tidak ada acuan di atas horizon")

        let id = references[0]
        let truth = c.resolver.horizontal(ofObjectID: id, observer: observer, date: date)!
        let step = session.captureNearest(measured: truth, date: date)
        XCTAssertEqual(step.selectedTarget?.id, id)
        XCTAssertEqual(session.flow.samples.count, 1)
    }

    /// Arah yang tidak dekat dengan bintang mana pun harus **ditolak**, bukan
    /// dipaksa cocok. Memaksa cocok berarti kalibrasi mengoreksi ke arah yang
    /// salah dan kesalahannya tersembunyi.
    func testCaptureNearestRefusesWhenNothingIsClose() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let empty = HorizontalCoord(altitudeDeg: 85, azimuthDeg: 200)
        // Pastikan arah itu memang jauh dari semua acuan.
        let nearest = c.resolver.nearestTarget(to: empty, observer: observer, date: date)
        try? XCTSkipIf(nearest != nil, "kebetulan ada acuan di dekat zenith")

        let step = session.captureNearest(measured: empty, date: date)
        XCTAssertNil(step.selectedTarget)
        XCTAssertTrue(session.flow.samples.isEmpty)
        XCTAssertTrue(step.message.contains("Tidak ada bintang acuan"))
    }

    // MARK: - Siklus hidup

    func testRemoveLastAndReset() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        guard references.count >= 2 else { return }

        session.capture(objectID: references[0],
                        measured: measured(references[0], yawError: 5, date: date), date: date)
        session.capture(objectID: references[1],
                        measured: measured(references[1], yawError: 5, date: date), date: date)
        XCTAssertTrue(session.flow.isReady)

        session.removeLast()
        XCTAssertEqual(session.flow.samples.count, 1)

        session.reset()
        XCTAssertTrue(session.flow.samples.isEmpty)
        XCTAssertEqual(c.calibration, .none)
    }

    /// Sigma terukur harus mengalir sampai ke usulan ambang keyakinan.
    func testSuggestedPolicyFollowsMeasuredSpread() throws {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        try XCTSkipIf(references.count < 2, "butuh minimal dua bintang acuan")

        for id in references.prefix(3) {
            session.capture(objectID: id, measured: measured(id, yawError: 4, date: date), date: date)
        }
        let policy = try XCTUnwrap(session.suggestedConfidencePolicy)
        XCTAssertEqual(policy.pointingSigmaDeg,
                       try XCTUnwrap(session.flow.calibration?.residualSpreadDeg),
                       accuracy: 1e-12)
        XCTAssertLessThan(policy.pointingSigmaDeg, 10.0)
    }
}
