import Foundation
import CelestialEngine

// MARK: - Pointing Lab: model data percobaan (ADR-004)
//
// Pointing Lab adalah alat riset, bukan fitur produk. Ia menjawab satu
// pertanyaan sebelum yang lain: seberapa jauh arah yang dihitung dari attitude
// jam dari arah yang **dimaksud** pengguna? Semua yang dibutuhkan untuk
// menjawabnya ulang nanti — dengan sumbu lain, model kalibrasi lain, atau
// kerangka lain — ikut direkam mentah, jadi analisis tidak terkunci pada
// keputusan yang berlaku saat rekam.
//
// Berkas ini murni (tanpa CoreMotion/WatchKit) supaya format dan ringkasannya
// teruji di Linux. Perekam sensornya ada di app jam.

/// Target satu percobaan: arah yang diketahui pengguna.
public struct LabTarget: Equatable, Hashable, Codable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        /// Penanda darat dengan bearing (dari Utara sebenarnya) dan elevasi
        /// yang diukur sendiri, mis. dari peta atau klinometer.
        case manual
        /// Objek katalog; arahnya dihitung saat percobaan direkam.
        case catalogObject
    }

    public var id: String
    public var name: String
    public var kind: Kind
    public var bearingDeg: Double?
    public var elevationDeg: Double?
    public var objectID: String?

    public init(id: String, name: String, kind: Kind,
                bearingDeg: Double? = nil, elevationDeg: Double? = nil,
                objectID: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.bearingDeg = bearingDeg
        self.elevationDeg = elevationDeg
        self.objectID = objectID
    }

    public static func manual(name: String, bearingDeg: Double, elevationDeg: Double) -> LabTarget {
        LabTarget(id: "manual:\(name):\(bearingDeg):\(elevationDeg)", name: name, kind: .manual,
                  bearingDeg: SkyMath.normalizeDeg(bearingDeg),
                  elevationDeg: max(-90, min(90, elevationDeg)))
    }

    public static func catalog(objectID: String, name: String) -> LabTarget {
        LabTarget(id: "object:\(objectID)", name: name, kind: .catalogObject, objectID: objectID)
    }

    /// Arah sebenarnya untuk target manual. Target katalog butuh resolver.
    public var manualTruth: HorizontalCoord? {
        guard kind == .manual, let b = bearingDeg, let e = elevationDeg else { return nil }
        return HorizontalCoord(altitudeDeg: e, azimuthDeg: b)
    }
}

/// Satu sampel `CMDeviceMotion`, apa adanya.
public struct LabMotionSample: Equatable, Codable, Sendable {
    /// `CMDeviceMotion.timestamp` (detik sejak boot).
    public var t: Double
    /// Quaternion attitude (w, x, y, z).
    public var q: [Double]
    public var gravity: Vector3
    public var rotationRate: Vector3
    public var userAcceleration: Vector3
    /// `CMCalibratedMagneticField.field` (µT), `nil` bila tidak tersedia.
    public var magneticField: Vector3?
    /// `CMMagneticFieldCalibrationAccuracy.rawValue` (−1 = tidak terkalibrasi).
    public var magneticAccuracy: Int?
    /// Arah gerak (heading) dari CoreMotion bila kerangkanya berutara.
    public var heading: Double?

    public init(t: Double, quaternion: Quaternion, gravity: Vector3, rotationRate: Vector3,
                userAcceleration: Vector3, magneticField: Vector3? = nil,
                magneticAccuracy: Int? = nil, heading: Double? = nil) {
        self.t = t
        self.q = [quaternion.w, quaternion.x, quaternion.y, quaternion.z]
        self.gravity = gravity
        self.rotationRate = rotationRate
        self.userAcceleration = userAcceleration
        self.magneticField = magneticField
        self.magneticAccuracy = magneticAccuracy
        self.heading = heading
    }

    public var quaternion: Quaternion? {
        guard q.count == 4 else { return nil }
        return Quaternion(w: q[0], x: q[1], y: q[2], z: q[3]).normalized
    }
}

/// Ringkasan satu jendela sampel di satu kerangka.
public struct LabFrameSummary: Equatable, Codable, Sendable {
    public var sampleCount: Int
    /// Laju yang benar-benar diterima, dari cap waktu (bukan yang diminta).
    public var observedHz: Double?
    /// Rata-rata quaternion (dinormalkan, tanda diselaraskan).
    public var meanQuaternion: [Double]?
    /// Arah tunjuk rata-rata per sumbu kandidat (`DeviceAimAxis.rawValue`).
    public var pointing: [String: HorizontalCoord]
    /// Sebaran sumbu terpilih di sekitar rata-ratanya (derajat, maks) —
    /// seberapa diam pergelangan selama jendela.
    public var aimSpreadDeg: Double?
    /// Median selisih gravitasi terukur vs ramalan konvensi (ADR-002).
    public var gravityMismatchMedianDeg: Double?
    /// Galat sudut per sumbu terhadap arah sebenarnya. Hanya untuk kerangka
    /// berutara; kerangka sembarang butuh kalibrasi yaw dulu (analisis).
    public var errorVsTruthDeg: [String: Double]?
}

/// Aliran CoreMotion yang dijalankan Lab. Apple menyarankan satu
/// `CMMotionManager` per app; mode tunggal ada supaya biaya mode ganda
/// (laju yang turun, aliran yang macet) bisa diukur, bukan diasumsikan.
public enum LabStreamMode: String, CaseIterable, Codable, Equatable, Sendable {
    case dual
    case singleNorth
    case singleArbitrary

    /// Urutan pilihan di layar. (Ditulis eksplisit: aturan 26
    /// `swift-ui-lint.sh` tidak mengenal `allCases` hasil sintesis.)
    public static let pickerOrder: [LabStreamMode] = [.dual, .singleNorth, .singleArbitrary]

    /// Kerangka yang diminta, urut: aliran pertama menggerakkan tampilan.
    public func frames(available: [AttitudeReferenceFrame]) -> [AttitudeReferenceFrame] {
        let north = [AttitudeReferenceFrame.xTrueNorthZVertical, .xMagneticNorthZVertical]
            .first(where: available.contains)
        let arbitrary = [AttitudeReferenceFrame.xArbitraryCorrectedZVertical, .xArbitraryZVertical]
            .first(where: available.contains)
        switch self {
        case .dual: return [north, arbitrary].compactMap { $0 }
        case .singleNorth: return [north ?? arbitrary].compactMap { $0 }
        case .singleArbitrary: return [arbitrary].compactMap { $0 }
        }
    }
}

/// Rekaman satu kerangka: sampel mentah + ringkasannya.
public struct LabFrameRecord: Equatable, Codable, Sendable {
    public var frame: AttitudeReferenceFrame
    public var requestedIntervalS: Double
    public var samples: [LabMotionSample]
    public var summary: LabFrameSummary
    /// Apakah aliran ini benar-benar mengirim sampel di dalam jendela.
    /// Opsional supaya berkas skema 1 tetap terbaca.
    public var deliveredInWindow: Bool?
    /// Laju yang diterima aliran ini dalam ~1 dtk terakhir sebelum penanda
    /// (lebih stabil daripada laju di dalam jendela 1 dtk itu sendiri).
    public var deliveredHzBeforeMark: Double?

    public init(frame: AttitudeReferenceFrame, requestedIntervalS: Double,
                samples: [LabMotionSample], summary: LabFrameSummary,
                deliveredHzBeforeMark: Double? = nil) {
        self.frame = frame
        self.requestedIntervalS = requestedIntervalS
        self.samples = samples
        self.summary = summary
        self.deliveredInWindow = !samples.isEmpty
        self.deliveredHzBeforeMark = deliveredHzBeforeMark
    }
}

/// Satu percobaan Pointing Lab. Satu baris JSONL.
public struct LabTrial: Equatable, Codable, Sendable, Identifiable {
    /// 2: `streamMode`, `deliveredInWindow`, `deliveredHzBeforeMark`
    /// (semuanya opsional; skema 1 tetap terbaca).
    public static let schemaVersion = 2

    public var schema: Int = LabTrial.schemaVersion
    public var id: UUID
    public var sessionID: UUID
    public var participant: String
    /// Waktu tombol Tandai ditekan (jam dinding, untuk astronomi).
    public var markedAt: Date
    /// `CMDeviceMotion.timestamp` pada saat yang sama (untuk menyelaraskan).
    public var markedAtUptime: Double
    public var watchOS: String
    public var deviceModel: String
    public var wear: WearConfiguration
    /// Sumbu yang dipakai engine saat rekam. Sumbu lain ada di ringkasan.
    public var aim: DeviceAimAxis
    public var target: LabTarget
    public var truth: HorizontalCoord?
    /// Lokasi dibulatkan ke 0,01° (~1 km): cukup untuk astronomi, tidak
    /// cukup untuk menunjuk rumah seseorang. Log mentah tetap tidak boleh
    /// masuk git (lihat `.gitignore`, `ResearchLogs/`).
    public var observerLatDeg: Double?
    public var observerLonDeg: Double?
    public var locationIsFallback: Bool
    public var frames: [LabFrameRecord]
    public var streamMode: LabStreamMode?
    public var extendedRuntime: String
    public var luminanceReduced: Bool?
    public var environment: String
    public var note: String

    public init(sessionID: UUID, participant: String, markedAt: Date,
                markedAtUptime: Double, watchOS: String, deviceModel: String,
                wear: WearConfiguration, aim: DeviceAimAxis, target: LabTarget,
                truth: HorizontalCoord?, observer: Observer?, locationIsFallback: Bool,
                frames: [LabFrameRecord], extendedRuntime: String, luminanceReduced: Bool?,
                environment: String, note: String, streamMode: LabStreamMode? = nil,
                id: UUID = UUID()) {
        self.streamMode = streamMode
        self.id = id
        self.sessionID = sessionID
        self.participant = participant
        self.markedAt = markedAt
        self.markedAtUptime = markedAtUptime
        self.watchOS = watchOS
        self.deviceModel = deviceModel
        self.wear = wear
        self.aim = aim
        self.target = target
        self.truth = truth
        self.observerLatDeg = observer.map { Self.round2($0.latitudeDeg) }
        self.observerLonDeg = observer.map { Self.round2($0.longitudeDeg) }
        self.locationIsFallback = locationIsFallback
        self.frames = frames
        self.extendedRuntime = extendedRuntime
        self.luminanceReduced = luminanceReduced
        self.environment = environment
        self.note = note
    }

    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
}

public enum PointingLab {

    /// Jendela di sekitar penanda: setengah lebar (detik).
    public static let windowHalfWidthS: Double = 0.5

    /// Sampel dalam jendela `[mark − w, mark + w]`.
    public static func window(_ samples: [LabMotionSample], aroundUptime mark: Double,
                              halfWidth: Double = windowHalfWidthS) -> [LabMotionSample] {
        samples.filter { abs($0.t - mark) <= halfWidth }.sorted { $0.t < $1.t }
    }

    /// Rata-rata quaternion: jumlah dengan tanda diselaraskan ke sampel
    /// pertama, lalu dinormalkan. Cukup akurat untuk sebaran beberapa derajat.
    public static func meanQuaternion(_ qs: [Quaternion]) -> Quaternion? {
        guard let first = qs.first else { return nil }
        var w = 0.0, x = 0.0, y = 0.0, z = 0.0
        for q in qs {
            let s: Double = q.dot(first) < 0 ? -1 : 1
            w += s * q.w; x += s * q.x; y += s * q.y; z += s * q.z
        }
        return Quaternion(w: w, x: x, y: y, z: z).normalized
    }

    /// Laju sampel yang diterima, dari cap waktu. `nil` bila < 2 sampel.
    public static func observedHz(_ samples: [LabMotionSample]) -> Double? {
        guard samples.count >= 2,
              let first = samples.map(\.t).min(), let last = samples.map(\.t).max(),
              last > first else { return nil }
        return Double(samples.count - 1) / (last - first)
    }

    public static func summarize(_ samples: [LabMotionSample],
                                 frame: AttitudeReferenceFrame,
                                 aim: DeviceAimAxis,
                                 truth: HorizontalCoord?) -> LabFrameSummary {
        let attitudes = samples.compactMap { $0.quaternion }
            .map { DeviceAttitude(quaternion: $0, frame: frame) }
        let mean = meanQuaternion(attitudes.map(\.quaternion))
            .map { DeviceAttitude(quaternion: $0, frame: frame) }

        var pointing: [String: HorizontalCoord] = [:]
        var errors: [String: Double] = [:]
        for axis in DeviceAimAxis.allCases {
            guard let h = mean?.horizontalPointing(aim: axis) else { continue }
            pointing[axis.rawValue] = h
            if frame.hasAbsoluteHeading, let truth {
                errors[axis.rawValue] = SkyMath.angularSeparationHorizontalDeg(h, truth)
            }
        }

        var spread: Double?
        if let meanVector = mean?.pointingVector(aim: aim) {
            spread = attitudes.compactMap { $0.pointingVector(aim: aim)?.angleDegrees(to: meanVector) }.max()
        }

        let mismatches = zip(samples, attitudes).compactMap { sample, attitude in
            attitude.gravityMismatchDeg(measured: sample.gravity)
        }.sorted()
        let median = mismatches.isEmpty ? nil : mismatches[mismatches.count / 2]

        return LabFrameSummary(sampleCount: samples.count,
                               observedHz: observedHz(samples),
                               meanQuaternion: mean.map { [$0.quaternion.w, $0.quaternion.x,
                                                           $0.quaternion.y, $0.quaternion.z] },
                               pointing: pointing,
                               aimSpreadDeg: spread,
                               gravityMismatchMedianDeg: median,
                               errorVsTruthDeg: errors.isEmpty ? nil : errors)
    }

    // MARK: JSONL

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Satu baris JSONL (diakhiri `\n`).
    public static func jsonLine(_ trial: LabTrial) throws -> Data {
        var data = try encoder().encode(trial)
        data.append(0x0A)
        return data
    }

    /// Baca semua percobaan dari berkas JSONL. Baris rusak dilewati dan
    /// dihitung, bukan menggagalkan seluruh berkas.
    public static func decodeLines(_ data: Data) -> (trials: [LabTrial], badLines: Int) {
        var trials: [LabTrial] = []
        var bad = 0
        let d = decoder()
        for line in data.split(separator: 0x0A) where !line.isEmpty {
            if let t = try? d.decode(LabTrial.self, from: Data(line)) { trials.append(t) } else { bad += 1 }
        }
        return (trials, bad)
    }

    /// Ringkasan beberapa angka galat: median, P90, P95 (metode nearest-rank).
    public static func percentiles(_ values: [Double]) -> (median: Double, p90: Double, p95: Double)? {
        let v = values.filter(\.isFinite).sorted()
        guard !v.isEmpty else { return nil }
        func rank(_ p: Double) -> Double { v[max(0, min(v.count - 1, Int((p * Double(v.count)).rounded(.up)) - 1))] }
        return (rank(0.5), rank(0.9), rank(0.95))
    }
}

// MARK: - Pesan Lab lewat WatchConnectivity

/// Kunci kamus WatchConnectivity untuk Pointing Lab. Terpisah dari
/// `PointingLinkMessage` supaya alat riset tidak mengubah protokol produk.
public enum LabLinkKeys {
    /// `transferUserInfo` iPhone -> jam: daftar target manual (JSON).
    public static let targets = "pointingLab.targets"
    /// Metadata `transferFile` jam -> iPhone.
    public static let fileMarker = "pointingLab.file"
    public static let sessionID = "pointingLab.sessionID"
    public static let trialCount = "pointingLab.trialCount"

    public static func encodeTargets(_ targets: [LabTarget]) -> [String: Any] {
        let data = (try? JSONEncoder().encode(targets)) ?? Data("[]".utf8)
        return [Self.targets: data]
    }

    public static func decodeTargets(_ dict: [String: Any]) -> [LabTarget]? {
        guard let data = dict[Self.targets] as? Data else { return nil }
        return try? JSONDecoder().decode([LabTarget].self, from: data)
    }
}

// MARK: - Baris teknis layar Lab

/// Baris angka untuk layar Lab. Sengaja **tidak** dilokalkan: isinya satuan
/// dan nama kerangka CoreMotion yang dibaca peneliti dan dicocokkan dengan
/// berkas JSONL, jadi harus sama persis di kedua bahasa.
public enum PointingLabText {
    public static func live(_ h: HorizontalCoord?) -> String {
        guard let h else { return "alt –  az –" }
        return String(format: "alt %.1f°  az %.1f°", h.altitudeDeg, h.azimuthDeg)
    }

    public static func frameAndAxis(_ frame: AttitudeReferenceFrame?, _ aim: DeviceAimAxis) -> String {
        "\(frame?.rawValue ?? "-") · \(aim.rawValue)"
    }

    public static func trialHeader(index: Int, summary s: LabFrameSummary) -> String {
        "#\(index)  n=\(s.sampleCount)  " + String(format: "%.0f Hz", s.observedHz ?? 0)
    }

    public static func error(_ deg: Double) -> String { String(format: "err %.1f°", deg) }

    public static func spread(_ s: LabFrameSummary) -> String {
        String(format: "spread %.1f°  g %.1f°", s.aimSpreadDeg ?? .nan, s.gravityMismatchMedianDeg ?? .nan)
    }

    public static func rate(_ frame: AttitudeReferenceFrame, _ hz: Double?) -> String {
        "\(frame.rawValue): " + String(format: "%.0f Hz", hz ?? 0)
    }

    public static func available(_ frames: [AttitudeReferenceFrame]) -> String {
        "avail: " + frames.map(\.rawValue).joined(separator: ", ")
    }

    public static func wear(_ w: WearConfiguration) -> String {
        "wrist \(w.wrist.rawValue) · crown \(w.crown.rawValue)"
    }

    public static func runtime(_ state: String) -> String { "runtime: \(state)" }

    public static func location(isFallback: Bool) -> String { "loc: " + (isFallback ? "fallback" : "gps") }

    public static func inFlight(_ n: Int) -> String { "↑ \(n)" }

    public static func targetRow(_ t: LabTarget) -> String {
        String(format: "%@  %.1f° / %.1f°", t.name, t.bearingDeg ?? 0, t.elevationDeg ?? 0)
    }

    /// Ringkasan satu berkas JSONL: jumlah percobaan dan galat sumbu yang
    /// dipakai di kerangka berutara (median / P90 / P95).
    public static func fileSummary(_ data: Data) -> String {
        let decoded = PointingLab.decodeLines(data)
        let errors = decoded.trials.compactMap { trial -> Double? in
            trial.frames.first { $0.frame.hasAbsoluteHeading }?
                .summary.errorVsTruthDeg?[trial.aim.rawValue]
        }
        var text = "n=\(decoded.trials.count)"
        if decoded.badLines > 0 { text += " bad=\(decoded.badLines)" }
        if let p = PointingLab.percentiles(errors) {
            text += String(format: "  med %.1f° p90 %.1f° p95 %.1f°", p.median, p.p90, p.p95)
        }
        return text
    }
}
