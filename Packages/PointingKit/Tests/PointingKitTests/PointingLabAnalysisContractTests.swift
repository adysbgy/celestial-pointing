import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Kontrak antara format JSONL Swift dan `Tools/analyze_pointing.py`.
///
/// Uji ini **menulis** berkas percobaan sintetis dengan bias yang diketahui
/// lewat jalur yang sama dengan app, lalu menjalankan skrip analisis atasnya.
/// Kalau skema atau konvensi kerangka (ADR-002) di salah satu sisi berubah
/// tanpa sisi lain, uji ini merah — bukan analisis lapangan yang diam-diam
/// salah. Dilewati bila `python3` tidak ada.
///
/// `CP_WRITE_LAB_FIXTURE=<path>` menyimpan salinan berkas sintetisnya.
final class PointingLabAnalysisContractTests: XCTestCase {

    static let altBiasDeg = 2.0
    static let azBiasDeg = 3.0
    static let arbitraryHeadingDeg = 117.0

    static let targets: [LabTarget] = [
        .manual(name: "T1", bearingDeg: 20, elevationDeg: 5),
        .manual(name: "T2", bearingDeg: 110, elevationDeg: 25),
        .manual(name: "T3", bearingDeg: 200, elevationDeg: 12),
        .manual(name: "T4", bearingDeg: 290, elevationDeg: 40),
    ]

    /// Dua lengan: kiri (mahkota kanan, +X) dan kanan (mahkota kanan, −X).
    static let arms: [WearConfiguration] = [
        WearConfiguration(wrist: .left, crown: .right),
        WearConfiguration(wrist: .right, crown: .right),
    ]

    /// Berkas sintetis: 4 target × 2 lengan × 5 ulangan, dua kerangka.
    static func syntheticJSONL() throws -> Data {
        var data = Data()
        let session = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let toArbitrary = Quaternion.axisAngle(axis: .unitZ,
                                               radians: SkyMath.deg2rad(arbitraryHeadingDeg))!
        var trialIndex = 0
        for wear in arms {
            let aim = wear.forearmAim
            for target in targets {
                let truth = target.manualTruth!
                for rep in 0..<5 {
                    trialIndex += 1
                    // Noise deterministik ±0,5° supaya ulangan tidak identik.
                    let n1 = sin(Double(trialIndex) * 1.7) * 0.5
                    let n2 = cos(Double(trialIndex) * 2.3) * 0.5
                    let intended = HorizontalCoord(altitudeDeg: truth.altitudeDeg + altBiasDeg + n1,
                                                   azimuthDeg: truth.azimuthDeg + azBiasDeg + n2)
                    let north = DeviceAttitude.synthetic(aim: aim, pointingAt: intended,
                                                         frame: .xTrueNorthZVertical)
                    let arbitraryQ = toArbitrary.multiplied(by: north.quaternion)

                    func samples(_ q: Quaternion) -> [LabMotionSample] {
                        let a = DeviceAttitude(quaternion: q)
                        return (0..<51).map { i in
                            LabMotionSample(t: 1000 + Double(trialIndex) * 10 + Double(i) * 0.02,
                                            quaternion: q, gravity: a.predictedGravity!,
                                            rotationRate: .zero, userAcceleration: .zero)
                        }
                    }
                    let mark = 1000 + Double(trialIndex) * 10 + 0.5
                    let frames = [(AttitudeReferenceFrame.xTrueNorthZVertical, north.quaternion),
                                  (.xArbitraryCorrectedZVertical, arbitraryQ)].map { frame, q in
                        let window = PointingLab.window(samples(q), aroundUptime: mark)
                        return LabFrameRecord(frame: frame, requestedIntervalS: 0.02, samples: window,
                                              summary: PointingLab.summarize(window, frame: frame,
                                                                             aim: aim, truth: truth),
                                              deliveredHzBeforeMark: 50)
                    }
                    let trial = LabTrial(sessionID: session, participant: "P01",
                                         markedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(trialIndex)),
                                         markedAtUptime: mark, watchOS: "synthetic", deviceModel: "synthetic",
                                         wear: wear, aim: aim, target: target, truth: truth,
                                         observer: Observer(latitudeDeg: -6.2, longitudeDeg: 106.8),
                                         locationIsFallback: false, frames: frames,
                                         extendedRuntime: "running", luminanceReduced: false,
                                         environment: "synthetic", note: "rep \(rep)",
                                         streamMode: .dual)
                    data.append(try PointingLab.jsonLine(trial))
                }
            }
        }
        return data
    }

    private static var scriptURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PointingKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // PointingKit
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // repo
            .appendingPathComponent("Tools/analyze_pointing.py")
    }

    private func runAnalysis(on file: URL) throws -> [String: Any] {
        let python = ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let python else { throw XCTSkip("python3 tidak tersedia") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [Self.scriptURL.path, "--json", file.path]
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let output = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, stderr)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: output) as? [String: Any])
    }

    func testAnalysisScriptReadsSwiftFixtureAndRecoversKnownBias() throws {
        let data = try Self.syntheticJSONL()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lab-contract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("synthetic.jsonl")
        try data.write(to: file)
        if let keep = ProcessInfo.processInfo.environment["CP_WRITE_LAB_FIXTURE"] {
            try data.write(to: URL(fileURLWithPath: keep))
        }

        let report = try runAnalysis(on: file)
        XCTAssertEqual(report["trials"] as? Int, 40)
        XCTAssertEqual(report["badLines"] as? Int, 0)

        // Konvensi: skrip menghitung ulang arah dari quaternion dan harus
        // sama dengan ringkasan Swift.
        XCTAssertLessThan(try XCTUnwrap(report["conventionCrossCheckMaxDeg"] as? Double), 1e-6)
        let gravity = try XCTUnwrap(report["gravityMismatchDeg"] as? [String: Any])
        XCTAssertLessThan(try XCTUnwrap(gravity["max"] as? Double), 1e-6)
        let hz = try XCTUnwrap(report["deliveredHz"] as? [[String: Any]])
        XCTAssertEqual(hz.count, 2)
        for h in hz {
            XCTAssertEqual(h["median"] as? Double ?? 0, 50, accuracy: 1e-9)
            XCTAssertEqual(h["deliveredWindows"] as? Int, h["windows"] as? Int)
        }

        // Galat di kerangka berutara, sumbu lengan masing-masing.
        let rows = try XCTUnwrap(report["rows"] as? [[String: Any]])
        for wear in Self.arms {
            let mine = rows.filter {
                $0["frame"] as? String == "xTrueNorthZVertical"
                    && $0["axis"] as? String == wear.forearmAim.rawValue
                    && $0["arm"] as? String == wear.wrist.rawValue
            }
            XCTAssertEqual(mine.count, Self.targets.count)
            for row in mine {
                let error = try XCTUnwrap(row["error"] as? [String: Any])
                XCTAssertEqual(error["n"] as? Int, 5)
                let median = try XCTUnwrap(error["median"] as? Double)
                XCTAssertGreaterThan(median, 1.5)
                XCTAssertLessThan(median, 4.5)
                let bias = try XCTUnwrap(row["bias"] as? [String: Any])
                XCTAssertEqual(try XCTUnwrap(bias["dAlt"] as? Double), Self.altBiasDeg, accuracy: 0.5)
                XCTAssertEqual(try XCTUnwrap(bias["dAzCosAlt"] as? Double), Self.azBiasDeg, accuracy: 0.8)
            }
        }

        // Kalibrasi: yaw dari target lain menghapus bias azimut (sisanya
        // bias altitude ~2°), di kedua kerangka — termasuk kerangka sembarang
        // yang mentahnya tidak bermakna.
        let calib = try XCTUnwrap(report["calibration"] as? [[String: Any]])
        for frame in ["xTrueNorthZVertical", "xArbitraryCorrectedZVertical"] {
            let c = try XCTUnwrap(calib.first {
                $0["frame"] as? String == frame && $0["axis"] as? String == "screenRight"
                    && $0["arm"] as? String == "left"
            })
            let yaw = try XCTUnwrap(c["yawAllLOO"] as? [String: Any])
            XCTAssertLessThan(try XCTUnwrap(yaw["median"] as? Double), 2.8, frame)
            let wahba = try XCTUnwrap(c["wahbaLOO"] as? [String: Any])
            XCTAssertEqual(wahba["n"] as? Int, 20, frame)
            if frame == "xArbitraryCorrectedZVertical" {
                XCTAssertTrue(c["raw"] is NSNull, "kerangka sembarang tidak boleh punya galat mentah")
            }
        }
    }
}
