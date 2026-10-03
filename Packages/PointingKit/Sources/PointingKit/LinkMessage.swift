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
    ///
    /// **Objek dan keyakinan hanya ikut bila keadaan punya jawaban sekarang.**
    /// `snapshot.bestObject` sengaja mempertahankan objek terakhir supaya panel
    /// jam tidak berkedip — itu benar untuk layar jam, yang menandai objek sisa
    /// sebagai sisa. Di sini tidak ada penanda seperti itu: mengirim objek sisa
    /// akan membuat iPhone menampilkannya sebagai keadaan jam sekarang, lengkap
    /// dengan badge "Yakin" dari keyakinan lama. Itu persis false confidence
    /// yang dilarang PRD, dan ia terjadi justru pada momen yang paling
    /// menyesatkan — tepat saat jam kehilangan jawabannya. Saat tidak ada
    /// jawaban, `state` tetap dikirim (itu faktanya); objek dan keyakinannya
    /// kosong.
    ///
    /// `sigmaDeg` **ikut** dikirim. Bukan untuk keputusan apa pun di iPhone —
    /// melainkan karena riwayat keyakinan di sana menyimpan konteks bersama
    /// sampelnya, dan sigma adalah bagian dari konteks itu. Tanpa ini, sampel
    /// dari jam akan tercatat dengan sigma bawaan, sehingga berkas ekspor
    /// menyatakan sesuatu yang tidak pernah berlaku di jam.
    public static func state(from snapshot: PointingSnapshot,
                             at date: Date = Date(),
                             sigmaDeg: Double? = nil) -> PointingLinkMessage {
        PointingLinkMessage(
            kind: .pointingState,
            sentAt: date,
            state: snapshot.state,
            objectID: snapshot.answeredObject?.id,
            objectName: snapshot.answeredObject?.name,
            level: snapshot.answeredLevel,
            altitudeDeg: snapshot.calibratedPointing?.altitudeDeg,
            azimuthDeg: snapshot.calibratedPointing?.azimuthDeg,
            angularRateDegPerSec: snapshot.angularRateDegPerSec,
            pointingSigmaDeg: sigmaDeg,
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

/// Penyaring kiriman keadaan Watch → iPhone.
///
/// `updateApplicationContext` hanya menyimpan **satu** kamus, jadi mengirim pada
/// tiap sampel sensor (20 Hz) tidak menambah informasi apa pun — hanya memakai
/// radio dan baterai jam — sementara yang berguna di iPhone adalah **keputusan
/// terakhir**, bukan banjir sampel.
///
/// Menyaringnya dengan "apakah ada jawaban?" (`state.hasAnswer`) salah dua kali
/// sekaligus:
/// - selama terkunci, jawabannya **terus** ada, jadi syarat itu tetap benar dan
///   jam mengirim 20 kali per detik — persis yang ingin dicegah;
/// - tepat saat jam **kehilangan** jawabannya (pergelangan bergerak lagi),
///   syarat itu menjadi salah dan kiriman berhenti — iPhone tetap menampilkan
///   objek terkunci terakhir seolah masih berlaku, padahal jam sudah tidak
///   mengidentifikasi apa pun.
///
/// Yang benar adalah mengirim saat **keputusannya berubah** — keadaan, objek,
/// atau keyakinan — termasuk saat berubah menjadi "tidak ada jawaban". Itu
/// membuat kiriman jarang (hanya pada perpindahan) sekaligus tidak pernah
/// menyembunyikan hilangnya jawaban.
///
/// Ditaruh di paket ini, bukan di app, supaya aturannya bisa diuji di Linux:
/// perilaku "kapan jam bicara" menentukan apa yang dilihat pengguna di iPhone.
public struct LinkReportGate: Sendable {

    /// Isi pesan yang menentukan apakah ada sesuatu yang baru.
    private struct Decision: Equatable, Sendable {
        var state: PointingState
        var objectID: String?
        var level: ConfidenceLevel?
    }

    private var last: Decision?

    public init() {}

    /// Apakah cuplikan ini membawa keputusan baru — jadi harus dikirim.
    ///
    /// Cuplikan pertama selalu dikirim: iPhone belum tahu apa-apa.
    ///
    /// Angka yang terus berubah (arah tunjuk, laju pergelangan) sengaja **tidak**
    /// ikut menentukan: kalau ikut, tiap sampel akan dianggap baru dan
    /// penyaringnya tidak menyaring apa pun. Pesan yang dikirim tetap membawa
    /// angka terbaru saat itu — yang disaring hanyalah **kapan** ia dikirim.
    public mutating func shouldReport(_ snapshot: PointingSnapshot) -> Bool {
        let decision = Decision(state: snapshot.state,
                                objectID: snapshot.answeredObject?.id,
                                level: snapshot.answeredLevel)
        guard decision != last else { return false }
        last = decision
        return true
    }
}
