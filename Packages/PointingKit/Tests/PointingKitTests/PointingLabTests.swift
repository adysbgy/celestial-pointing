import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Format dan ringkasan Pointing Lab (ADR-004). Yang dijaga: data mentah
/// selamat bolak-balik, dan ringkasan mengukur yang dijanjikannya.
final class PointingLabTests: XCTestCase {

    private let truth = HorizontalCoord(altitudeDeg: 40, azimuthDeg: 120)

    /// Jendela 1 dtk di 50 Hz dengan getaran kecil di sekitar `truth`.
    private func samples(frame: AttitudeReferenceFrame = .xTrueNorthZVertical,
                         aim: DeviceAimAxis = .screenRight,
                         jitterDeg: Double = 0.5, start: Double = 100) -> [LabMotionSample] {
        (0..<51).map { i in
            let wobble = sin(Double(i) * 0.7) * jitterDeg
            let target = HorizontalCoord(altitudeDeg: truth.altitudeDeg + wobble,
                                         azimuthDeg: truth.azimuthDeg - wobble)
            let a = DeviceAttitude.synthetic(aim: aim, pointingAt: target, frame: frame)
            return LabMotionSample(t: start + Double(i) * 0.02, quaternion: a.quaternion,
                                   gravity: a.predictedGravity!, rotationRate: .zero,
                                   userAcceleration: .zero,
                                   magneticField: Vector3(x: 20, y: 0, z: -40), magneticAccuracy: 2)
        }
    }

    private func trial(_ frames: [LabFrameRecord]) -> LabTrial {
        LabTrial(sessionID: UUID(), participant: "P01", markedAt: Date(timeIntervalSince1970: 1_700_000_000),
                 markedAtUptime: 100.5, watchOS: "26.5", deviceModel: "Watch", wear: .default,
                 aim: .screenRight, target: .manual(name: "Menara", bearingDeg: 120, elevationDeg: 40),
                 truth: truth, observer: Observer(latitudeDeg: -6.123456, longitudeDeg: 106.876543),
                 locationIsFallback: false, frames: frames, extendedRuntime: "running",
                 luminanceReduced: false, environment: "open-field", note: "")
    }

    func testSummaryMeasuresRateSpreadErrorAndConvention() {
        let s = PointingLab.summarize(samples(), frame: .xTrueNorthZVertical,
                                      aim: .screenRight, truth: truth)
        XCTAssertEqual(s.sampleCount, 51)
        XCTAssertEqual(s.observedHz!, 50, accuracy: 0.01)
        XCTAssertLessThan(s.errorVsTruthDeg!["screenRight"]!, 0.5)
        XCTAssertGreaterThan(s.errorVsTruthDeg!["screenLeft"]!, 90, "sumbu lain harus tercatat dan jelas salah")
        XCTAssertGreaterThan(s.aimSpreadDeg!, 0.3)
        XCTAssertLessThan(s.aimSpreadDeg!, 1.5)
        XCTAssertEqual(s.gravityMismatchMedianDeg!, 0, accuracy: 1e-6)
        XCTAssertEqual(s.pointing.count, DeviceAimAxis.allCases.count)
    }

    /// Kerangka sembarang tidak boleh mengklaim galat terhadap arah
    /// sebenarnya: azimutnya belum bermakna tanpa kalibrasi.
    func testArbitraryFrameReportsNoErrorVsTruth() {
        let s = PointingLab.summarize(samples(frame: .xArbitraryCorrectedZVertical),
                                      frame: .xArbitraryCorrectedZVertical,
                                      aim: .screenRight, truth: truth)
        XCTAssertNil(s.errorVsTruthDeg)
        XCTAssertEqual(s.pointing["screenRight"]!.altitudeDeg, truth.altitudeDeg, accuracy: 0.5)
    }

    func testWindowSelectsAroundMark() {
        let w = PointingLab.window(samples(), aroundUptime: 100.5, halfWidth: 0.1)
        XCTAssertEqual(w.count, 11)
        XCTAssertTrue(w.allSatisfy { abs($0.t - 100.5) <= 0.1 + 1e-9 })
    }

    func testMeanQuaternionHandlesDoubleCover() {
        let q = Quaternion.axisAngle(axis: .unitZ, radians: 0.3)!
        let negated = Quaternion(w: -q.w, x: -q.x, y: -q.y, z: -q.z)
        let mean = PointingLab.meanQuaternion([q, negated, q])!
        XCTAssertLessThan(mean.angleDegrees(to: q)!, 1e-9)
    }

    func testJSONLRoundTripAndBadLines() throws {
        let frames = [LabFrameRecord(frame: .xTrueNorthZVertical, requestedIntervalS: 0.02,
                                     samples: samples(),
                                     summary: PointingLab.summarize(samples(), frame: .xTrueNorthZVertical,
                                                                    aim: .screenRight, truth: truth))]
        let t = trial(frames)
        var data = try PointingLab.jsonLine(t)
        data.append(Data("not json\n".utf8))
        data.append(try PointingLab.jsonLine(t))
        let decoded = PointingLab.decodeLines(data)
        XCTAssertEqual(decoded.trials.count, 2)
        XCTAssertEqual(decoded.badLines, 1)
        XCTAssertEqual(decoded.trials[0], t)
        XCTAssertEqual(decoded.trials[0].schema, LabTrial.schemaVersion)
        XCTAssertEqual(data.split(separator: 0x0A).count, 3, "satu percobaan = satu baris")
    }

    func testLocationIsRoundedForPrivacy() {
        let t = trial([])
        XCTAssertEqual(t.observerLatDeg, -6.12)
        XCTAssertEqual(t.observerLonDeg, 106.88)
    }

    func testManualTargetTruthAndClamping() {
        let t = LabTarget.manual(name: "Tiang", bearingDeg: -10, elevationDeg: 120)
        XCTAssertEqual(t.manualTruth!.azimuthDeg, 350, accuracy: 1e-9)
        XCTAssertEqual(t.manualTruth!.altitudeDeg, 90)
        XCTAssertNil(LabTarget.catalog(objectID: "sirius", name: "Sirius").manualTruth)
    }

    func testTargetsSurviveLinkEncoding() {
        let targets = [LabTarget.manual(name: "A", bearingDeg: 10, elevationDeg: 5),
                       LabTarget.catalog(objectID: "moon", name: "Bulan")]
        XCTAssertEqual(LabLinkKeys.decodeTargets(LabLinkKeys.encodeTargets(targets)), targets)
        XCTAssertNil(LabLinkKeys.decodeTargets(["other": 1]))
    }

    func testStreamModesPickFrames() {
        let all = AttitudeReferenceFrame.allCases
        XCTAssertEqual(LabStreamMode.dual.frames(available: all),
                       [.xTrueNorthZVertical, .xArbitraryCorrectedZVertical])
        XCTAssertEqual(LabStreamMode.singleNorth.frames(available: all), [.xTrueNorthZVertical])
        XCTAssertEqual(LabStreamMode.singleArbitrary.frames(available: all),
                       [.xArbitraryCorrectedZVertical])
        // Tanpa magnetometer/lokasi: "utara" jatuh ke sembarang, dan mode
        // ganda tidak menggandakan aliran yang sama.
        let noNorth: [AttitudeReferenceFrame] = [.xArbitraryZVertical]
        XCTAssertEqual(LabStreamMode.dual.frames(available: noNorth), [.xArbitraryZVertical])
        XCTAssertEqual(LabStreamMode.singleNorth.frames(available: noNorth), [.xArbitraryZVertical])
        XCTAssertEqual(LabStreamMode.dual.frames(available: [.xMagneticNorthZVertical]),
                       [.xMagneticNorthZVertical])
    }

    func testFrameRecordFlagsAStreamThatDeliveredNothing() {
        let empty = LabFrameRecord(frame: .xTrueNorthZVertical, requestedIntervalS: 0.02, samples: [],
                                   summary: PointingLab.summarize([], frame: .xTrueNorthZVertical,
                                                                  aim: .screenRight, truth: truth),
                                   deliveredHzBeforeMark: 0)
        XCTAssertEqual(empty.deliveredInWindow, false)
        XCTAssertNil(empty.summary.observedHz)
    }

    /// Baris skema 1 (tanpa field baru) harus tetap terbaca.
    func testSchema1LineStillDecodes() throws {
        var t = trial([])
        t.schema = 1
        var json = try JSONSerialization.jsonObject(with: PointingLab.encoder().encode(t)) as! [String: Any]
        json.removeValue(forKey: "streamMode")
        let line = try JSONSerialization.data(withJSONObject: json) + Data([0x0A])
        let decoded = PointingLab.decodeLines(line)
        XCTAssertEqual(decoded.trials.count, 1)
        XCTAssertNil(decoded.trials[0].streamMode)
    }

    func testPercentilesNearestRank() {
        let p = PointingLab.percentiles((1...20).map(Double.init))!
        XCTAssertEqual(p.median, 10)
        XCTAssertEqual(p.p90, 18)
        XCTAssertEqual(p.p95, 19)
        XCTAssertNil(PointingLab.percentiles([]))
    }
}
