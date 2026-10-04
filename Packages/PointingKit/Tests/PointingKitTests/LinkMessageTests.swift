import XCTest
import CelestialEngine
@testable import PointingKit

/// Format pesan Watch ↔ iPhone.
///
/// Diuji di Linux karena `WCSession` hanya menerima tipe property list:
/// pesan yang salah bentuk antara dua perangkat adalah bug yang mahal
/// ditemukan (harus ada dua perangkat, dan gagalnya senyap).
final class LinkMessageTests: XCTestCase {

    // MARK: - Bolak-balik

    func testStateMessageSurvivesPlistRoundTrip() {
        let snapshot = PointingSnapshot(
            state: .lock,
            intent: CelestialIntent(level: .high,
                                    best: CelestialObject(id: "sirius", name: "Sirius",
                                                          kind: .star, raDeg: 101.287,
                                                          decDeg: -16.716, magnitude: -1.46),
                                    candidates: []),
            calibratedPointing: HorizontalCoord(altitudeDeg: 42.5, azimuthDeg: 133.25),
            angularRateDegPerSec: 0.35,
            aim: .view,
            hasSensor: true,
            isCalibrated: true
        )
        let message = PointingLinkMessage.state(from: snapshot,
                                               at: Date(timeIntervalSince1970: 1_700_000_000))
        let decoded = try! XCTUnwrap(PointingLinkMessage(plist: message.plist))

        XCTAssertEqual(decoded.kind, .pointingState)
        XCTAssertEqual(decoded.state, .lock)
        XCTAssertEqual(decoded.objectID, "sirius")
        XCTAssertEqual(decoded.objectName, "Sirius")
        XCTAssertEqual(decoded.level, .high)
        XCTAssertEqual(decoded.altitudeDeg!, 42.5, accuracy: 1e-12)
        XCTAssertEqual(decoded.azimuthDeg!, 133.25, accuracy: 1e-12)
        XCTAssertEqual(decoded.sentAt, message.sentAt)
    }

    /// Bentuk kabel harus benar-benar bisa disimpan sebagai property list —
    /// kalau tidak, `updateApplicationContext` akan gagal saat runtime.
    func testPlistIsPropertyListSerializable() {
        let snapshot = PointingSnapshot(state: .uncertain,
                                        intent: CelestialIntent(level: .medium,
                                                                best: CelestialObject(id: "moon", name: "Bulan",
                                                                                      kind: .moon, raDeg: 10,
                                                                                      decDeg: 5, magnitude: -12),
                                                                candidates: []),
                                        calibratedPointing: HorizontalCoord(altitudeDeg: 20, azimuthDeg: 200),
                                        isCalibrated: true)
        let plist = PointingLinkMessage.state(from: snapshot).plist
        XCTAssertTrue(PropertyListSerialization.propertyList(plist, isValidFor: .binary),
                      "pesan tidak bisa disimpan sebagai property list")
    }

    /// Arah tunjuk mentah sengaja **tidak** ikut dikirim: yang perlu diketahui
    /// iPhone adalah jawaban engine, bukan sudut pergelangan.
    func testStateMessageDoesNotCarryRawWristAngle() {
        let snapshot = PointingSnapshot(state: .lock,
                                        rawPointing: HorizontalCoord(altitudeDeg: 1, azimuthDeg: 2),
                                        calibratedPointing: HorizontalCoord(altitudeDeg: 42, azimuthDeg: 133))
        let message = PointingLinkMessage.state(from: snapshot)
        XCTAssertEqual(message.altitudeDeg!, 42, accuracy: 1e-12)
        XCTAssertNotEqual(message.altitudeDeg!, 1)
    }

    func testCalibrationMessageCarriesMeasuredSigma() {
        let calibration = PointingCalibration(yawOffsetDeg: 7.5, residualSpreadDeg: 2.25, sampleCount: 4)
        let message = PointingLinkMessage.calibration(calibration)
        let decoded = try! XCTUnwrap(PointingLinkMessage(plist: message.plist))

        XCTAssertEqual(decoded.kind, .calibrationReady)
        XCTAssertEqual(decoded.yawOffsetDeg!, 7.5, accuracy: 1e-12)
        XCTAssertEqual(decoded.residualSpreadDeg!, 2.25, accuracy: 1e-12)
        XCTAssertEqual(decoded.sampleCount, 4)
        XCTAssertEqual(try! XCTUnwrap(decoded.calibration).residualSpreadDeg!, 2.25, accuracy: 1e-12)
    }

    func testPolicyMessageCarriesThreshold() {
        let message = PointingLinkMessage.policy(ConfidencePolicy(pointingSigmaDeg: 3.5))
        let decoded = try! XCTUnwrap(PointingLinkMessage(plist: message.plist))
        XCTAssertEqual(decoded.kind, .policyUpdate)
        XCTAssertEqual(try! XCTUnwrap(decoded.confidencePolicy).pointingSigmaDeg, 3.5, accuracy: 1e-12)
    }

    /// Sigma yang berlaku di jam harus ikut dalam pesan keadaan. Riwayat
    /// keyakinan di iPhone menyimpan konteks bersama sampelnya; tanpa sigma,
    /// sampel dari jam tercatat dengan angka yang tidak pernah berlaku di jam.
    func testStateMessageCarriesWatchSigma() {
        let snapshot = PointingSnapshot(state: .lock)
        let message = PointingLinkMessage.state(from: snapshot,
                                               at: Date(timeIntervalSince1970: 1_700_000_000),
                                               sigmaDeg: 4.25)
        let decoded = try! XCTUnwrap(PointingLinkMessage(plist: message.plist))
        XCTAssertEqual(decoded.pointingSigmaDeg!, 4.25, accuracy: 1e-12)
        XCTAssertEqual(decoded.kind, .pointingState)
    }

    /// Tanpa sigma, `nil` tetap `nil` — bukan 0 yang terbaca seperti "sempurna".
    func testStateMessageWithoutSigmaKeepsItNil() {
        let message = PointingLinkMessage.state(from: PointingSnapshot(state: .lock))
        XCTAssertNil(message.pointingSigmaDeg)
    }

    // MARK: - Pesan rusak

    func testUnknownKindIsRejected() {
        XCTAssertNil(PointingLinkMessage(plist: ["kind": "sesuatu", "sentAt": 0.0]))
    }

    func testMissingFieldsAreRejected() {
        XCTAssertNil(PointingLinkMessage(plist: [:]))
        XCTAssertNil(PointingLinkMessage(plist: ["kind": "pointingState"]))
    }

    /// Ambang keyakinan yang tidak masuk akal tidak boleh diterapkan:
    /// sigma 0 atau NaN akan membuat engine selalu yakin.
    func testNonsensePolicyIsRefused() {
        let zero = PointingLinkMessage(kind: .policyUpdate, pointingSigmaDeg: 0)
        XCTAssertNil(zero.confidencePolicy)
        let negative = PointingLinkMessage(kind: .policyUpdate, pointingSigmaDeg: -5)
        XCTAssertNil(negative.confidencePolicy)
        let nan = PointingLinkMessage(kind: .policyUpdate, pointingSigmaDeg: .nan)
        XCTAssertNil(nan.confidencePolicy)
        let missing = PointingLinkMessage(kind: .policyUpdate)
        XCTAssertNil(missing.confidencePolicy)
    }

    func testCalibrationMessageWithoutYawIsRefused() {
        XCTAssertNil(PointingLinkMessage(kind: .calibrationReady).calibration)
    }

    /// Kalibrasi tanpa sebaran terukur tetap sah (mis. satu titik acuan),
    /// tapi sigmanya harus tetap `nil` — bukan 0 yang terlihat seperti sempurna.
    func testCalibrationWithoutSpreadKeepsSigmaNil() {
        let message = PointingLinkMessage(kind: .calibrationReady,
                                          yawOffsetDeg: 5,
                                          sampleCount: 1)
        let calibration = try! XCTUnwrap(message.calibration)
        XCTAssertEqual(calibration.yawOffsetDeg, 5, accuracy: 1e-12)
        XCTAssertNil(calibration.residualSpreadDeg)
        XCTAssertNil(calibration.confidencePolicy())
    }

    // MARK: - Objek sisa tidak boleh ikut terkirim

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279, decDeg: 38, magnitude: 0.03)

    /// Objek dan keyakinan hanya ikut bila keadaan **punya jawaban sekarang**.
    ///
    /// Mesin keadaan sengaja mempertahankan objek terakhir supaya panel jam
    /// tidak berkedip. Di jam itu benar — layar menandai objek sisa sebagai
    /// sisa. Di pesan ini tidak ada penanda seperti itu: mengirim objek sisa
    /// membuat iPhone menampilkannya sebagai keadaan jam sekarang, lengkap
    /// dengan badge "Yakin" dari keyakinan lama. Itu false confidence yang
    /// dilarang PRD, dan ia muncul tepat saat jam kehilangan jawabannya.
    func testStaleObjectIsNotSentAsCurrentAnswer() {
        let stale = PointingSnapshot(state: .pointing,
                                     intent: CelestialIntent(level: .high, best: vega, candidates: []))
        let message = PointingLinkMessage.state(from: stale)

        XCTAssertEqual(message.state, .pointing, "keadaannya tetap dilaporkan apa adanya")
        XCTAssertNil(message.objectID, "objek dari arah tunjuk sebelumnya bukan jawaban sekarang")
        XCTAssertNil(message.objectName)
        XCTAssertNil(message.level, "keyakinan lama tidak boleh menempel pada keadaan tanpa jawaban")
    }

    /// Keadaan yang benar-benar punya jawaban tetap mengirim objek + keyakinan.
    func testLiveAnswerIsSentWithObjectAndLevel() {
        for state in [PointingState.lock, .uncertain] {
            let live = PointingSnapshot(state: state,
                                        intent: CelestialIntent(level: .high, best: vega, candidates: []))
            let message = PointingLinkMessage.state(from: live)
            XCTAssertEqual(message.objectID, "vega", "\(state) adalah jawaban sekarang")
            XCTAssertEqual(message.objectName, "Vega")
            XCTAssertEqual(message.level, .high)
        }
    }

    // MARK: - Arah tunjuk dari sensor yang sudah mati

    /// Saat sensor mati, `calibratedPointing` yang tersisa di cuplikan adalah
    /// arah **terakhir sebelum sensor hilang** — dan pesan ini tidak punya
    /// penanda apa pun bahwa angkanya sudah tidak berlaku. Mengirimkannya
    /// membuat iPhone menampilkan azimut/ketinggian lama sebagai pengukuran
    /// sekarang, persis false confidence yang dilarang PRD.
    ///
    /// (Di layar jam sendiri nilai yang sama masih boleh dibaca, karena keadaan
    /// `unavailable` ditampilkan tepat di sebelah angkanya. Di pesan ini tidak
    /// ada penanda seperti itu.)
    func testPointingAnglesAreNotSentWhenSensorIsDead() {
        let dead = PointingSnapshot(state: .unavailable,
                                    calibratedPointing: HorizontalCoord(altitudeDeg: 42.5,
                                                                        azimuthDeg: 133.25),
                                    hasSensor: false)
        XCTAssertEqual(dead.calibratedPointing?.altitudeDeg, 42.5,
                       "cuplikan memang mempertahankannya — itu yang membuat kiriman mentah berbahaya")

        let message = PointingLinkMessage.state(from: dead)
        XCTAssertEqual(message.state, .unavailable, "keadaannya tetap dilaporkan apa adanya")
        XCTAssertNil(message.altitudeDeg, "arah dari beberapa detik lalu bukan pengukuran sekarang")
        XCTAssertNil(message.azimuthDeg)
    }

    /// Sensor hidup → arah tunjuk tetap ikut, apa adanya.
    func testPointingAnglesAreSentWhileSensorIsAlive() {
        let live = PointingSnapshot(state: .lock,
                                    calibratedPointing: HorizontalCoord(altitudeDeg: 42.5,
                                                                        azimuthDeg: 133.25),
                                    hasSensor: true)
        let message = PointingLinkMessage.state(from: live)
        XCTAssertEqual(message.altitudeDeg!, 42.5, accuracy: 1e-12)
        XCTAssertEqual(message.azimuthDeg!, 133.25, accuracy: 1e-12)
    }

    // MARK: - Kapan jam bicara

    /// Kirim saat **keputusan berubah**, bukan tiap sampel.
    ///
    /// Menyaring dengan "apakah ada jawaban?" salah dua kali: selama terkunci
    /// syaratnya selalu benar (jadi tetap 20 Hz), dan tepat saat jawabannya
    /// hilang syaratnya salah — iPhone membeku di objek terakhir seolah masih
    /// berlaku.
    func testGateReportsOnDecisionChangeOnly() {
        var gate = LinkReportGate()
        let locked = PointingSnapshot(state: .lock,
                                      intent: CelestialIntent(level: .high, best: vega, candidates: []))

        XCTAssertTrue(gate.shouldReport(locked), "cuplikan pertama selalu dikirim")

        // Sampel berikutnya dengan keputusan yang sama tidak dikirim, walau
        // angka yang berubah-ubah (laju pergelangan) terus datang.
        var stillLocked = locked
        stillLocked.angularRateDegPerSec = 1.25
        XCTAssertFalse(gate.shouldReport(stillLocked),
                       "20 sampel per detik dengan keputusan sama bukan informasi baru")

        // Jawaban **hilang** — inilah yang dulu tidak pernah sampai ke iPhone.
        let lost = PointingSnapshot(state: .pointing,
                                    intent: CelestialIntent(level: .high, best: vega, candidates: []))
        XCTAssertTrue(gate.shouldReport(lost), "hilangnya jawaban harus dikirim, bukan disembunyikan")

        // Kembali terkunci pada objek yang sama: keadaan berubah lagi.
        XCTAssertTrue(gate.shouldReport(locked))
        XCTAssertFalse(gate.shouldReport(locked))
    }

    /// Keyakinan yang berubah pada objek yang sama adalah keputusan baru.
    func testGateReportsLevelChange() {
        var gate = LinkReportGate()
        let high = PointingSnapshot(state: .lock,
                                    intent: CelestialIntent(level: .high, best: vega, candidates: []))
        let medium = PointingSnapshot(state: .uncertain,
                                      intent: CelestialIntent(level: .medium, best: vega, candidates: []))
        XCTAssertTrue(gate.shouldReport(high))
        XCTAssertTrue(gate.shouldReport(medium), "yakin → ragu adalah kabar yang harus dikirim")
    }

    /// **Kiriman yang gagal tidak boleh memakan kesempatan berikutnya.**
    ///
    /// `shouldReport` menandai keputusan sebagai "sudah dilaporkan" saat
    /// dipanggil — sebelum pengiriman dicoba. Kalau urutannya begitu, kiriman
    /// yang gagal (jam belum tersambung ke iPhone — kegagalan yang paling
    /// sering di lapangan) membuat keputusan itu tercatat terkirim, sehingga
    /// **tidak pernah dicoba lagi** selama keputusannya sama. iPhone terjebak
    /// di keadaan lama sementara di jam sudah berubah, dan tidak ada kiriman
    /// berikutnya yang membetulkannya.
    ///
    /// Uji ini akan merah kalau `deliver` dikembalikan ke urutan lama
    /// (tandai dulu, kirim kemudian): percobaan kedua akan langsung ditolak
    /// penyaringnya dan `attempts` tetap 1.
    func testFailedSendIsRetriedInsteadOfSwallowed() {
        var gate = LinkReportGate()
        let locked = PointingSnapshot(state: .lock,
                                      intent: CelestialIntent(level: .high, best: vega, candidates: []))
        var attempts = 0

        // Percobaan pertama gagal: sesi belum aktif.
        let first = gate.deliver(locked) { _ in attempts += 1; return false }
        XCTAssertFalse(first, "gagal kirim bukan terkirim")

        // Keputusan yang sama, percobaan berikutnya: harus dicoba lagi.
        let second = gate.deliver(locked) { _ in attempts += 1; return true }
        XCTAssertTrue(second, "kiriman yang gagal tidak boleh dianggap sudah tersampaikan")
        XCTAssertEqual(attempts, 2, "keputusan yang gagal harus diulang")

        // Setelah benar-benar terkirim, keputusan yang sama tidak dikirim lagi.
        XCTAssertFalse(gate.deliver(locked) { _ in attempts += 1; return true })
        XCTAssertEqual(attempts, 2, "20 sampel dengan keputusan sama bukan informasi baru")
    }

    /// Kehilangan jawaban tetap terkirim walau ada kiriman yang gagal
    /// sebelumnya — inilah kabar yang dulu tidak pernah sampai ke iPhone.
    func testLostAnswerIsStillDeliveredAfterAFailedSend() {
        var gate = LinkReportGate()
        let locked = PointingSnapshot(state: .lock,
                                      intent: CelestialIntent(level: .high, best: vega, candidates: []))
        let lost = PointingSnapshot(state: .pointing,
                                    intent: CelestialIntent(level: .high, best: vega, candidates: []))

        XCTAssertFalse(gate.deliver(locked) { _ in false }, "kiriman pertama gagal")
        XCTAssertTrue(gate.deliver(lost) { _ in true },
                      "kehilangan jawaban harus tetap bisa dikirim setelah kegagalan")
    }

    // MARK: - Kalimat keadaan, bukan kalimat jadi di dalam pesan

    /// Keadaan kalibrasi disimpan sebagai **keadaan**, bukan kalimat.
    ///
    /// Dulu `note` diisi `"terkalibrasi"` di dalam paket, lalu iPhone
    /// merendernya lewat `LinkView`. Literal itu tidak punya kunci katalog —
    /// Aturan 6 memeriksa kunci yang **dideklarasikan**, dan kalimat itu tidak
    /// punya kunci — jadi ia tampil Bahasa Indonesia di semua bahasa dengan
    /// setiap gerbang hijau. Uji ini menuntut yang dikirim adalah nilai
    /// boolean, bukan kata.
    func testStateCarriesCalibrationAsAFlagNotASentence() {
        let calibrated = PointingLinkMessage.state(
            from: PointingSnapshot(state: .lock, isCalibrated: true))
        XCTAssertEqual(calibrated.isCalibrated, true)
        XCTAssertNil(calibrated.note, "kalimat jadi tidak boleh lahir di dalam paket")

        let notCalibrated = PointingLinkMessage.state(
            from: PointingSnapshot(state: .pointing, isCalibrated: false))
        XCTAssertEqual(notCalibrated.isCalibrated, false)
        XCTAssertNil(notCalibrated.note)
    }

    /// Bendera kalibrasi selamat melewati bentuk kabel.
    ///
    /// Kalau ia tidak ikut diserialisasi, iPhone menerima pesan tanpa keadaan
    /// kalibrasi dan menampilkan jam sebagai "belum terkalibrasi" walau sudah
    /// dikalibrasi — salah, dan tidak terlihat dari sisi jam.
    func testCalibrationFlagSurvivesTheWire() {
        let message = PointingLinkMessage.state(
            from: PointingSnapshot(state: .lock, isCalibrated: true))
        let decoded = try! XCTUnwrap(PointingLinkMessage(plist: message.plist))
        XCTAssertEqual(decoded.isCalibrated, true)
    }

    /// Kalimatnya datang dari katalog, dan `nil` saat tidak ada keadaan.
    func testCalibrationNoteTextComesFromTheCatalog() {
        let calibrated = PointingLinkMessage(kind: .pointingState, isCalibrated: true)
        XCTAssertEqual(calibrated.calibrationNoteText, "terkalibrasi")

        let notCalibrated = PointingLinkMessage(kind: .pointingState, isCalibrated: false)
        XCTAssertEqual(notCalibrated.calibrationNoteText, "belum terkalibrasi")

        // Tanpa keadaan: tidak ada baris, bukan baris kosong.
        let silent = PointingLinkMessage(kind: .acknowledgement)
        XCTAssertNil(silent.calibrationNoteText)
    }

    /// Terjemahan memasang kata yang menggantikan bawaan.
    func testCalibrationNoteTextIsTranslatable() {
        TextLocalization.install { key in
            [
                "link.note.calibrated": "calibrated",
                "link.note.notCalibrated": "not calibrated",
            ][key]
        }
        defer { TextLocalization.reset() }

        XCTAssertEqual(
            PointingLinkMessage(kind: .pointingState, isCalibrated: true)
                .calibrationNoteText,
            "calibrated")
        XCTAssertEqual(
            PointingLinkMessage(kind: .pointingState, isCalibrated: false)
                .calibrationNoteText,
            "not calibrated")
    }
}
