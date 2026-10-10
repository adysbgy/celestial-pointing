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
            XCTAssertGreaterThan(target.direction.altitudeDeg,
                                 controller().resolver.policy.minAltitudeDeg,
                                 "\(target.id) di bawah ambang engine")
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

    // MARK: - Cacat: daftar acuan bisa basi karena **waktu**, bukan cuma tempat

    /// Daftar acuan dihitung untuk langit pada suatu detik, lalu dibiarkan.
    /// Bintang bergerak ~15°/jam, jadi sepuluh menit kemudian daftar itu
    /// sudah meleset hingga ~2,5° (terbukti lewat pengukuran drift) — tapi
    /// `isReferenceListStale` lama hanya membandingkan **lokasi**, sehingga
    /// tetap `false`. Pengguna lalu memilih bintang yang sebenarnya sudah
    /// terbenam, dan `capture` memakai arah bintang itu sebagai kebenaran.
    ///
    /// Test ini mengunci bahwa waktu ikut dihitung: daftar yang berumur lebih
    /// dari batasnya harus dianggap basi meskipun lokasinya sama.
    func testReferenceListBecomesStaleAfterMaxAge() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        // Hitung daftar "pada detik ini".
        session.refreshReferenceTargets(date: date)
        XCTAssertFalse(session.isReferenceListStale(asOf: date),
                       "baru dihitung: belum basi")

        // Maju melewati batas usia daftar.
        let later = date.addingTimeInterval(session.referenceMaxAge + 1)
        XCTAssertTrue(session.isReferenceListStale(asOf: later),
                      "daftar berumur lebih dari batas harus basi")

        // Hitung ulang pada waktu itu → segar lagi.
        session.refreshReferenceTargets(date: later)
        XCTAssertFalse(session.isReferenceListStale(asOf: later),
                       "sudah dihitung ulang: segar")
    }

    /// Bintang yang sudah terbenam tidak boleh dipakai sebagai acuan —
    /// arahnya di bawah cakrawala, jadi memakainya sebagai kebenaran hanya
    /// menghasilkan sampel hantu yang membalik offset kalibrasi tanpa
    /// terlihat.
    ///
    /// Reproduksi cacat: ambil bintang yang masih di atas horizon saat
    /// daftar dihitung, lalu tunjuk ke arah itu beberapa jam kemudian saat
    /// bintang sudah terbenam. `capture` lama tetap menambah sampel
    /// (terbukti: sampel fiktif 13,2° muncul), padahal kebenarannya sudah
    /// di bawah horizon.
    func testCaptureRejectsObjectBelowHorizon() throws {
        let c = controller()
        let session = CalibrationSession(controller: c)

        // Cari bintang acuan yang sedang di atas horizon, dan waktu saat ia
        // sudah terbenam.
        let refs = visibleReferences()
        try XCTSkipIf(refs.isEmpty, "tidak ada acuan di atas horizon saat uji")
        let id = refs[0]
        let truthNow = c.resolver.horizontal(ofObjectID: id,
                                            observer: observer,
                                            date: date)!
        XCTAssertGreaterThan(truthNow.altitudeDeg, 0, "prasyarat: acuan di atas horizon sekarang")

        // Cari waktu nanti saat bintang itu di bawah horizon.
        var setTime: Date?
        for minutes in stride(from: 5.0, through: 600.0, by: 5.0) {
            let d = date.addingTimeInterval(minutes * 60)
            if (c.resolver.horizontal(ofObjectID: id, observer: observer, date: d)?
                .altitudeDeg ?? 90) <= 0 {
                setTime = d
                break
            }
        }
        try XCTSkipIf(setTime == nil, "bintang tidak terbenam dalam jendela uji")

        // Pengguna menunjuk ke arah lama (di atas horizon saat daftar dihitung).
        let phantom = HorizontalCoord(altitudeDeg: truthNow.altitudeDeg,
                                     azimuthDeg: truthNow.azimuthDeg)
        let step = session.capture(objectID: id, measured: phantom, date: setTime!)
        XCTAssertTrue(session.flow.samples.isEmpty,
                      "sampel bintang yang sudah terbenam tidak boleh tercatat")
        XCTAssertEqual(step.selectedTarget, nil)
        XCTAssertTrue(step.message.contains("terbenam"),
                      "pengguna harus diberi tahu bintang sudah terbenam, bukan diam")
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

    /// Kalibrasi tidak boleh memakai arah tunjuk yang tersisa saat sensor mati.
    ///
    /// Saat sensor hilang, `rawPointing` yang ada di cuplikan adalah nilai
    /// **terakhir sebelum sensor hilang** — tetap terisi, jadi tanpa penjagaan
    /// ia lolos sebagai pengukuran. Yang terjadi kalau lolos: kalibrasi dipasang
    /// dari arah yang sudah tidak berlaku, seluruh pointing sesudahnya bergeser,
    /// dan kesalahannya tersembunyi di balik sebaran yang terlihat bagus.
    func testCaptureIsRefusedWhenSensorIsUnavailable() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        guard references.count >= 2 else { return }

        // Bawa sensor ke keadaan hidup dengan arah tunjuk nyata, lalu matikan.
        let truth = c.resolver.horizontal(ofObjectID: references[0], observer: observer, date: date)!
        let q = quaternion(viewPointingAt: truth)
        c.feed(quaternion: q, timestamp: date)
        XCTAssertTrue(c.snapshot.hasSensor)
        XCTAssertNotNil(c.snapshot.rawPointing, "arah tunjuk tersisa tetap terisi")

        c.setSensorAvailable(false)
        XCTAssertFalse(c.snapshot.hasSensor)
        XCTAssertNotNil(c.snapshot.rawPointing,
                        "inilah jebakannya: nilainya masih ada saat sensor mati")

        let step = session.capture(objectID: references[0])
        XCTAssertTrue(session.flow.samples.isEmpty,
                      "arah tunjuk sisa tidak boleh tercatat sebagai pengukuran")
        XCTAssertFalse(step.applied)
        XCTAssertNil(step.selectedTarget)
        XCTAssertTrue(step.message.contains("Sensor gerak tidak aktif"), step.message)

        let nearest = session.captureNearest()
        XCTAssertTrue(session.flow.samples.isEmpty)
        XCTAssertTrue(nearest.message.contains("Sensor gerak tidak aktif"), nearest.message)

        XCTAssertNil(session.applyIfReady(), "tidak ada sampel -> tidak ada yang dipasang")
        XCTAssertEqual(c.calibration, .none)
    }

    /// Arah tunjuk yang sama tetap boleh dicatat saat sensor hidup.
    func testCaptureWorksWhenSensorIsAvailable() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        guard !references.isEmpty else { return }

        let truth = c.resolver.horizontal(ofObjectID: references[0], observer: observer, date: date)!
        c.feed(quaternion: quaternion(viewPointingAt: truth), timestamp: date)

        let step = session.capture(objectID: references[0])
        XCTAssertEqual(session.flow.samples.count, 1)
        XCTAssertEqual(step.selectedTarget?.id, references[0])
    }

    /// Setiap sampel yang dicatat dari sensor membawa attitude mentahnya, dan
    /// dari situ sumbu yang benar-benar dipakai menunjuk bisa dikenali —
    /// termasuk bila itu bukan sumbu yang sedang dipakai controller.
    func testAxisEvaluationFindsTheAxisActuallyUsed() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        XCTAssertGreaterThanOrEqual(references.count, 2, "prasyarat: dua acuan terlihat")
        guard references.count >= 2 else { return }

        // Pengguna menunjuk dengan −X (mis. jam dipakai terbalik), padahal
        // controller memakai +X.
        for (i, id) in references.prefix(2).enumerated() {
            let t = date.addingTimeInterval(Double(i))
            let truth = c.resolver.horizontal(ofObjectID: id, observer: observer, date: t)!
            let q = DeviceAttitude.synthetic(aim: .screenLeft, pointingAt: truth).quaternion
            c.feed(quaternion: q, timestamp: t)
            session.capture(objectID: id, date: t)
        }
        XCTAssertEqual(session.rawAttitudes.count, 2)
        XCTAssertEqual(session.axisEvaluation.first?.aim, .screenLeft)
        XCTAssertLessThan(session.axisEvaluation.first!.rmsErrorDeg, 0.01)

        session.removeLast()
        XCTAssertEqual(session.rawAttitudes.count, session.flow.samples.count)
        session.reset()
        XCTAssertTrue(session.rawAttitudes.isEmpty)
        XCTAssertTrue(session.axisEvaluation.isEmpty)
    }

    /// Sampel yang dimasukkan sebagai arah jadi tidak punya attitude, dan
    /// tidak boleh ikut menilai sumbu.
    func testManualSamplesCarryNoAttitude() {
        let c = controller()
        let session = CalibrationSession(controller: c)
        guard let id = visibleReferences().first else { return }
        session.capture(objectID: id, measured: measured(id, yawError: 3, date: date), date: date)
        XCTAssertEqual(session.rawAttitudes.count, 1)
        XCTAssertNil(session.rawAttitudes[0] ?? nil)
        XCTAssertTrue(session.axisEvaluation.isEmpty)
    }

    /// Sama seperti di `PointingControllerTests`: quaternion yang menunjuk ke
    /// arah horizontal tertentu (roll = 0).
    private func quaternion(viewPointingAt target: HorizontalCoord) -> Quaternion {
        // Sumbu bawaan controller (lengan bawah), konvensi CoreMotion — ADR-002.
        DeviceAttitude.synthetic(aim: PointingControllerConfig().aim, pointingAt: target).quaternion
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

    /// Membuang kalibrasi harus terbaca dari cuplikan controller.
    ///
    /// UI membaca **cuplikan**, bukan `controller.calibration`. Kalau `reset()`
    /// membuang kalibrasinya tetapi cuplikan masih membawa `isCalibrated` lama,
    /// layar jam terus menampilkan "Kalibrasi: Sudah" dan ikon scope padahal
    /// offsetnya sudah hilang — pengguna mempercayai arah tunjuk yang sebenarnya
    /// belum terkalibrasi. Itu klaim tanpa dasar, dan tidak ada bagian layar
    /// yang terlihat keliru. Test ini mengunci janji bahwa pembersihan benar
    /// benar terlihat di satu-satunya sumber yang dibaca UI.
    func testResetClearsCalibrationFromPublishedSnapshot() throws {
        let c = controller()
        let session = CalibrationSession(controller: c)
        let references = visibleReferences()
        try XCTSkipIf(references.count < 2, "butuh minimal dua bintang acuan")

        for id in references.prefix(3) {
            session.capture(objectID: id, measured: measured(id, yawError: 4, date: date), date: date)
        }
        try XCTUnwrap(session.applyIfReady())
        XCTAssertTrue(c.snapshot.isCalibrated, "kalibrasi yang dipasang harus terbaca di cuplikan")

        session.reset()

        XCTAssertFalse(c.snapshot.isCalibrated,
                       "kalibrasi yang dibuang tidak boleh tetap diklaim terpasang di cuplikan")
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
