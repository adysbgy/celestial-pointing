import Foundation
import CelestialEngine

/// Jenis pesan Watch ↔ iPhone.
public enum LinkMessageKind: String, Codable, Equatable, Sendable {
    /// Watch → iPhone: keadaan alur sekarang (objek, keyakinan, arah).
    case pointingState
    /// Watch → iPhone: kalibrasi selesai, beserta sigma pointing terukur.
    case calibrationReady
    /// iPhone → Watch: ambang keyakinan baru (hasil Experiment 1).
    case policyUpdate
    /// iPhone → Watch: permintaan mengirim keadaan terakhir.
    case stateRequest
    /// Saling: tanda terima.
    case acknowledgement
}

/// Isi pesan Watch ↔ iPhone.
///
/// Formatnya sengaja primitif (String/Double/Bool saja) karena
/// `WCSession.updateApplicationContext` hanya menerima tipe yang bisa
/// disimpan sebagai property list. Tipe ini didefinisikan di paket yang bebas
/// API Apple supaya **formatnya bisa diuji di Linux** — pesan yang salah
/// bentuk antara dua perangkat adalah bug yang mahal untuk ditemukan.
public struct PointingLinkMessage: Codable, Equatable, Sendable {
    public var kind: LinkMessageKind
    public var sentAt: Date
    /// Keadaan alur (untuk `pointingState`).
    public var state: PointingState?
    public var objectID: String?
    public var objectName: String?
    public var level: ConfidenceLevel?
    public var altitudeDeg: Double?
    public var azimuthDeg: Double?
    public var angularRateDegPerSec: Double?
    /// Kalibrasi (untuk `calibrationReady`).
    public var yawOffsetDeg: Double?
    public var residualSpreadDeg: Double?
    public var sampleCount: Int?
    /// Ambang keyakinan (untuk `policyUpdate`).
    public var pointingSigmaDeg: Double?
    public var note: String?

    public init(kind: LinkMessageKind,
                sentAt: Date = Date(),
                state: PointingState? = nil,
                objectID: String? = nil,
                objectName: String? = nil,
                level: ConfidenceLevel? = nil,
                altitudeDeg: Double? = nil,
                azimuthDeg: Double? = nil,
                angularRateDegPerSec: Double? = nil,
                yawOffsetDeg: Double? = nil,
                residualSpreadDeg: Double? = nil,
                sampleCount: Int? = nil,
                pointingSigmaDeg: Double? = nil,
                note: String? = nil) {
        self.kind = kind
        self.sentAt = sentAt
        self.state = state
        self.objectID = objectID
        self.objectName = objectName
        self.level = level
        self.altitudeDeg = altitudeDeg
        self.azimuthDeg = azimuthDeg
        self.angularRateDegPerSec = angularRateDegPerSec
        self.yawOffsetDeg = yawOffsetDeg
        self.residualSpreadDeg = residualSpreadDeg
        self.sampleCount = sampleCount
        self.pointingSigmaDeg = pointingSigmaDeg
        self.note = note
    }

    // MARK: - Bentuk kabel

    /// Bentuk yang bisa dikirim `WCSession` (property list).
    public var plist: [String: Any] {
        var out: [String: Any] = [
            "kind": kind.rawValue,
            "sentAt": sentAt.timeIntervalSince1970
        ]
        if let state { out["state"] = state.rawValue }
        if let objectID { out["objectID"] = objectID }
        if let objectName { out["objectName"] = objectName }
        if let level { out["level"] = level.rawValue }
        if let altitudeDeg { out["altitudeDeg"] = altitudeDeg }
        if let azimuthDeg { out["azimuthDeg"] = azimuthDeg }
        if let angularRateDegPerSec { out["angularRateDegPerSec"] = angularRateDegPerSec }
        if let yawOffsetDeg { out["yawOffsetDeg"] = yawOffsetDeg }
        if let residualSpreadDeg { out["residualSpreadDeg"] = residualSpreadDeg }
        if let sampleCount { out["sampleCount"] = sampleCount }
        if let pointingSigmaDeg { out["pointingSigmaDeg"] = pointingSigmaDeg }
        if let note { out["note"] = note }
        return out
    }

    /// Baca dari bentuk kabel. `nil` bila `kind`/`sentAt` tidak ada atau tidak
    /// dikenal — pesan rusak tidak boleh menghasilkan keadaan karangan.
    public init?(plist: [String: Any]) {
        guard let rawKind = plist["kind"] as? String,
              let kind = LinkMessageKind(rawValue: rawKind),
              let sentInterval = plist["sentAt"] as? Double
        else { return nil }

        self.kind = kind
        self.sentAt = Date(timeIntervalSince1970: sentInterval)
        self.state = (plist["state"] as? String).flatMap(PointingState.init(rawValue:))
        self.objectID = plist["objectID"] as? String
        self.objectName = plist["objectName"] as? String
        self.level = (plist["level"] as? String).flatMap(ConfidenceLevel.init(rawValue:))
        self.altitudeDeg = plist["altitudeDeg"] as? Double
        self.azimuthDeg = plist["azimuthDeg"] as? Double
        self.angularRateDegPerSec = plist["angularRateDegPerSec"] as? Double
        self.yawOffsetDeg = plist["yawOffsetDeg"] as? Double
        self.residualSpreadDeg = plist["residualSpreadDeg"] as? Double
        self.sampleCount = plist["sampleCount"] as? Int
        self.pointingSigmaDeg = plist["pointingSigmaDeg"] as? Double
        self.note = plist["note"] as? String
    }

    // MARK: - Pembuat

    /// Pesan keadaan dari cuplikan controller.
    ///
    /// `rawPointing` **tidak** dikirim: yang perlu diketahui iPhone adalah
    /// jawaban engine, bukan sudut pergelangan. Mengirim sudut mentah ke
    /// perangkat lain hanya menambah peluang ia dipakai untuk hal yang salah.
    public static func state(from snapshot: PointingSnapshot,
                             at date: Date = Date()) -> PointingLinkMessage {
        PointingLinkMessage(
            kind: .pointingState,
            sentAt: date,
            state: snapshot.state,
            objectID: snapshot.bestObject?.id,
            objectName: snapshot.bestObject?.name,
            level: snapshot.intent?.level,
            altitudeDeg: snapshot.calibratedPointing?.altitudeDeg,
            azimuthDeg: snapshot.calibratedPointing?.azimuthDeg,
            angularRateDegPerSec: snapshot.angularRateDegPerSec,
            note: snapshot.isCalibrated ? "terkalibrasi" : "belum terkalibrasi"
        )
    }

    /// Pesan kalibrasi selesai.
    public static func calibration(_ calibration: PointingCalibration,
                                   at date: Date = Date()) -> PointingLinkMessage {
        PointingLinkMessage(
            kind: .calibrationReady,
            sentAt: date,
            yawOffsetDeg: calibration.yawOffsetDeg,
            residualSpreadDeg: calibration.residualSpreadDeg,
            sampleCount: calibration.sampleCount,
            pointingSigmaDeg: calibration.suggestedPointingSigmaDeg
        )
    }

    /// Pesan ambang keyakinan baru (iPhone → Watch).
    public static func policy(_ policy: ConfidencePolicy,
                              at date: Date = Date()) -> PointingLinkMessage {
        PointingLinkMessage(kind: .policyUpdate,
                            sentAt: date,
                            pointingSigmaDeg: policy.pointingSigmaDeg)
    }

    /// Kebijakan dari pesan ini, bila memang membawa ambang keyakinan.
    ///
    /// Ambang `nil` atau tidak berhingga ditolak: menerapkannya akan membuat
    /// engine tidak pernah (atau selalu) yakin.
    public var confidencePolicy: ConfidencePolicy? {
        guard let sigma = pointingSigmaDeg, sigma.isFinite, sigma > 0 else { return nil }
        return ConfidencePolicy(pointingSigmaDeg: sigma)
    }

    /// Kalibrasi dari pesan ini, bila memang membawa hasil kalibrasi.
    public var calibration: PointingCalibration? {
        guard let yaw = yawOffsetDeg, yaw.isFinite else { return nil }
        let spread = residualSpreadDeg.flatMap { $0.isFinite ? $0 : nil }
        return PointingCalibration(yawOffsetDeg: yaw,
                                   residualSpreadDeg: spread,
                                   sampleCount: sampleCount ?? 0)
    }
}
