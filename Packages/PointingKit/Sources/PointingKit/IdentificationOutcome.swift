import Foundation
import CelestialEngine

/// Hasil Point → Identify yang ditampilkan jam, dalam tiga bentuk produk:
/// satu jawaban, beberapa kemungkinan, atau tidak yakin (ADR-007).
///
/// Diturunkan dari keadaan alur dan `CelestialIntent` yang sudah ada; tidak
/// ada ambang baru di sini. Ambangnya tetap milik `ConfidencePolicy`, dan
/// selama sigma-nya belum terukur ia **PROVISIONAL** — `isProvisional`
/// membawa fakta itu sampai ke layar.
public enum IdentificationOutcome: Equatable, Sendable {
    /// Sensor tidak ada; engine menolak menebak.
    case unavailable
    /// Pergelangan masih bergerak / belum ada data: "Tahan stabil".
    case holdSteady
    /// Satu objek, yakin tinggi.
    case single(CelestialObject)
    /// Beberapa kandidat masuk akal (1–3), engine tidak cukup yakin memilih.
    case possibleMatches([CelestialObject])
    /// Stabil, tapi tidak ada objek yang didukung di arah itu.
    case notSure

    public static func from(_ snapshot: PointingSnapshot) -> IdentificationOutcome {
        switch snapshot.state {
        case .unavailable:
            return .unavailable
        case .idle, .pointing:
            return .holdSteady
        case .searching:
            return .notSure
        case .lock:
            guard let best = snapshot.intent?.best else { return .notSure }
            return .single(best)
        case .uncertain:
            var objects = (snapshot.intent?.candidates ?? []).map(\.object)
            if let best = snapshot.intent?.best, !objects.contains(best) {
                objects.insert(best, at: 0)
            }
            let top = Array(objects.prefix(3))
            return top.isEmpty ? .notSure : .possibleMatches(top)
        }
    }

    /// Objek yang boleh dikonfirmasi dari hasil ini.
    public var confirmable: [CelestialObject] {
        switch self {
        case .single(let o): return [o]
        case .possibleMatches(let list): return list
        default: return []
        }
    }
}

public extension ConfidencePolicy {
    /// Benar selama sigma pointing belum berasal dari pengukuran perangkat.
    /// Ambang lock/ambigu yang diturunkan darinya ikut PROVISIONAL.
    var isProvisional: Bool { !isMeasured }
}

// MARK: - Teks layar Identify → Confirm (ADR-007)

/// Teks layar identifikasi. Dirakit di paket supaya teruji dan berpadanan
/// katalog, bukan sebagai literal di view.
public enum IdentificationText {
    public static var holdSteady: String { TextLocalization.text(.identifyHoldSteady) }
    public static var possibleMatches: String { TextLocalization.text(.identifyPossibleMatches) }
    public static var notSure: String { TextLocalization.text(.identifyNotSure) }
    public static func confirm(_ name: String) -> String { TextLocalization.text(.identifyConfirm, name) }
    public static func confirmed(_ name: String) -> String { TextLocalization.text(.identifyConfirmed, name) }
    public static var sending: String { TextLocalization.text(.identifySending) }
    public static var deliveredLive: String { TextLocalization.text(.identifyDeliveredLive) }
    public static var deliveredRecorded: String { TextLocalization.text(.identifyDeliveredRecorded) }
    public static var deliveryFailed: String { TextLocalization.text(.identifyDeliveryFailed) }
    public static var pointAgain: String { TextLocalization.text(.identifyPointAgain) }
    public static var phoneConfirmedTitle: String { TextLocalization.text(.identifyPhoneConfirmedTitle) }
    public static var phoneNothingConfirmed: String { TextLocalization.text(.identifyPhoneNothingConfirmed) }

    /// Waktu konfirmasi di iPhone, ditambah catatan bila ia hanya tiba lewat
    /// antrean (riwayat, tidak membuka GoTo).
    public static func phoneConfirmedTime(_ date: Date, live: Bool) -> String {
        let time = date.formatted(date: .omitted, time: .standard)
        return live ? time : time + " · " + deliveredRecorded
    }

    /// Baris teknis, sengaja **tidak** dilokalkan dan selalu menyebut
    /// PROVISIONAL selama sigma belum terukur — supaya tangkapan layar dan
    /// demo tidak pernah menyiratkan ambang yang sudah divalidasi.
    public static func sigmaLine(_ policy: ConfidencePolicy) -> String {
        String(format: "σ %.1f°", policy.pointingSigmaDeg) + (policy.isProvisional ? " PROVISIONAL" : " measured")
    }
}

public extension LocalizedText {
    static let identifyHoldSteady = LocalizedText(key: "identify.holdSteady", id: "Tahan stabil")
    static let identifyPossibleMatches = LocalizedText(key: "identify.possibleMatches",
                                                       id: "Mungkin salah satu ini")
    static let identifyNotSure = LocalizedText(key: "identify.notSure", id: "Belum yakin — arahkan lagi")
    static let identifyConfirm = LocalizedText(key: "identify.confirm", id: "Konfirmasi %@")
    static let identifyConfirmed = LocalizedText(key: "identify.confirmed", id: "%@ dikonfirmasi")
    static let identifySending = LocalizedText(key: "identify.sending", id: "Mengirim ke iPhone…")
    static let identifyDeliveredLive = LocalizedText(key: "identify.delivered.live", id: "Terkirim ke iPhone")
    static let identifyDeliveredRecorded = LocalizedText(key: "identify.delivered.recorded",
                                                         id: "Disimpan — iPhone tidak terjangkau")
    static let identifyDeliveryFailed = LocalizedText(key: "identify.delivered.failed", id: "Gagal dikirim")
    static let identifyPointAgain = LocalizedText(key: "identify.pointAgain", id: "Tunjuk lagi")
    static let identifyPhoneConfirmedTitle = LocalizedText(key: "identify.phone.confirmedTitle",
                                                           id: "Dikonfirmasi di jam")
    static let identifyPhoneNothingConfirmed = LocalizedText(key: "identify.phone.nothingConfirmed",
                                                             id: "Belum ada objek yang dikonfirmasi")

    static let identifyKeys: [LocalizedText] = [
        .identifyHoldSteady, .identifyPossibleMatches, .identifyNotSure, .identifyConfirm,
        .identifyConfirmed, .identifySending, .identifyDeliveredLive, .identifyDeliveredRecorded,
        .identifyDeliveryFailed, .identifyPointAgain, .identifyPhoneConfirmedTitle,
        .identifyPhoneNothingConfirmed,
    ]
}
