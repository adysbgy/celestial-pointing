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
}
