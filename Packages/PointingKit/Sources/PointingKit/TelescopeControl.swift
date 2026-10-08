import Foundation
import CelestialEngine

// MARK: - Kontrol teleskop dari jam (ADR-009)
//
// Jam tidak pernah menggerakkan motor sendiri. Ia hanya:
// 1. menampilkan keadaan teleskop yang dilaporkan iPhone (lewat
//    `updateApplicationContext`, keadaan terakhir + cap waktu);
// 2. meminta GoTo **untuk objek yang sudah dikonfirmasi**, hanya saat iPhone
//    terjangkau dan teleskop dilaporkan siap dengan laporan yang segar;
// 3. meminta Stop, yang selalu tersedia saat teleskop (mungkin) bergerak.
//
// Semua aturan itu ada di `TelescopeControlModel` (murni, teruji di Linux).

/// Keadaan teleskop yang dilaporkan iPhone.
public enum TelescopeStatusState: String, Codable, Equatable, Sendable {
    /// Fitur teleskop mati di iPhone.
    case disabled
    case disconnected
    case ready
    case slewing
    case error
}

/// Laporan keadaan teleskop iPhone → jam. Kunci kamus terpisah dari
/// `PointingLinkMessage`, jadi iPhone harus **menggabungkan** keduanya dalam
/// satu `applicationContext` (konteks baru menimpa seluruh kamus).
public struct TelescopeStatus: Equatable, Codable, Sendable {
    public static let plistKey = "telescope.status.v1"

    public var state: TelescopeStatusState
    public var at: Date
    public var detail: String?

    public init(state: TelescopeStatusState, at: Date, detail: String? = nil) {
        self.state = state
        self.at = at
        self.detail = detail
    }

    public init(readiness: TelescopeReadiness, at: Date, detail: String? = nil) {
        switch readiness {
        case .ready: self.init(state: .ready, at: at, detail: detail)
        case .slewing: self.init(state: .slewing, at: at, detail: detail)
        case .notReady: self.init(state: .error, at: at, detail: detail)
        case .disconnected: self.init(state: .disconnected, at: at, detail: detail)
        }
    }

    public var plist: [String: Any] {
        [Self.plistKey: (try? LiveCoding.encoder.encode(self)) ?? Data()]
    }

    public init?(plist: [String: Any]) {
        guard let data = plist[Self.plistKey] as? Data,
              let s = try? LiveCoding.decoder.decode(TelescopeStatus.self, from: data) else { return nil }
        self = s
    }
}

/// Keadaan teleskop yang **berlaku** di jam: laporan yang lebih tua dari
/// `TelescopeControlModel.staleAfter` menjadi `unknown`.
public enum TelescopeEffectiveState: Equatable, Sendable {
    case disabled, disconnected, ready, slewing, error, unknown
}

/// Aturan tombol GoTo/Stop di jam.
public struct TelescopeControlModel: Equatable, Sendable {
    /// Laporan lebih tua dari ini dianggap tidak diketahui.
    public static let staleAfter: TimeInterval = 10

    /// GoTo yang diterima dianggap selesai bila laporan segar menunjukkan
    /// bergerak → siap, atau "siap" terus selama ini sesudah diterima (slew
    /// pendek yang selesai di antara dua laporan).
    public static let assumeDoneAfterReady: TimeInterval = 20

    public enum Action: Equatable, Sendable {
        case none
        case sendingGoTo
        case goToAccepted
        case goToCompleted
        case goToFailed(LiveRejection?)
        case sendingStop
        case stopAccepted
        case stopFailed(LiveRejection?)
    }

    /// Laporan terbaru. Laporan yang lebih tua dari yang sudah ada diabaikan
    /// (konteks antrean bisa tiba setelah jawaban kanal langsung yang lebih
    /// baru).
    public var status: TelescopeStatus? {
        didSet {
            if let old = oldValue, let new = status, new.at < old.at { status = old; return }
            observeProgress()
        }
    }
    public var isReachable: Bool
    private var sawSlewingSinceGoTo = false
    private var goToAcceptedAt: Date?
    public private(set) var confirmedObjectID: String?
    /// GoTo sudah diminta untuk konfirmasi ini (teleskop mungkin bergerak).
    public private(set) var goToIssued = false
    public private(set) var lastAction: Action = .none

    public init(status: TelescopeStatus? = nil, isReachable: Bool = false) {
        self.status = status
        self.isReachable = isReachable
    }

    public func effectiveState(now: Date) -> TelescopeEffectiveState {
        guard let status else { return .unknown }
        let age = now.timeIntervalSince(status.at)
        // Cap waktu dari masa depan (jam berbeda) juga tidak dipercaya.
        guard age <= Self.staleAfter, age >= -Self.staleAfter else { return .unknown }
        switch status.state {
        case .disabled: return .disabled
        case .disconnected: return .disconnected
        case .ready: return .ready
        case .slewing: return .slewing
        case .error: return .error
        }
    }

    /// Tombol GoTo hanya muncul setelah konfirmasi, iPhone terjangkau, dan
    /// teleskop **siap** menurut laporan yang segar.
    public func canGoTo(now: Date) -> Bool {
        confirmedObjectID != nil && isReachable && effectiveState(now: now) == .ready
            && !showsStop(now: now)
    }

    /// Stop terlihat setiap kali teleskop sedang atau **mungkin** bergerak:
    /// dilaporkan slewing, atau GoTo sudah diminta dan keadaannya kini tidak
    /// diketahui / galat, atau GoTo sedang dikirim / baru diterima.
    public func showsStop(now: Date) -> Bool {
        if effectiveState(now: now) == .slewing { return true }
        // GoTo diminta dan belum terbukti selesai atau dihentikan: mungkin
        // bergerak, apa pun laporan terakhirnya (termasuk "siap" yang belum
        // menyusul, atau tidak ada jawaban sama sekali).
        if goToIssued { return true }
        switch lastAction {
        case .sendingStop, .stopFailed: return true
        default: return false
        }
    }

    private mutating func observeProgress() {
        guard goToIssued, lastAction == .goToAccepted, let status else { return }
        switch status.state {
        case .slewing:
            sawSlewingSinceGoTo = true
        case .ready:
            let longReady = goToAcceptedAt.map {
                status.at.timeIntervalSince($0) >= Self.assumeDoneAfterReady
            } ?? false
            if sawSlewingSinceGoTo || longReady {
                goToIssued = false
                sawSlewingSinceGoTo = false
                lastAction = .goToCompleted
            }
        default:
            break
        }
    }

    /// Ada objek terkonfirmasi tetapi iPhone tidak terjangkau: tampilkan
    /// "iPhone tidak terjangkau", bukan tombol GoTo, dan tidak mencoba ulang.
    public func showsPhoneUnreachable(now: Date) -> Bool {
        confirmedObjectID != nil && !isReachable
    }

    public mutating func confirm(objectID: String) {
        confirmedObjectID = objectID
        goToIssued = false
        sawSlewingSinceGoTo = false
        lastAction = .none
    }

    /// "Tunjuk lagi": objek dilepas (tidak ada GoTo baru), tetapi bila GoTo
    /// sudah diminta, Stop tetap tersedia sampai teleskop terbukti diam atau
    /// Stop diterima.
    public mutating func clearConfirmation() {
        confirmedObjectID = nil
        if !goToIssued { lastAction = .none }
    }

    /// - Returns: `false` bila GoTo tidak diizinkan saat ini (tidak ada yang
    ///   dikirim).
    public mutating func beginGoTo(now: Date) -> Bool {
        guard canGoTo(now: now) else { return false }
        goToIssued = true
        lastAction = .sendingGoTo
        return true
    }

    public mutating func finishGoTo(_ result: LiveSendResult, now: Date = Date()) {
        switch result {
        case .replied(let r) where r.accepted:
            lastAction = .goToAccepted
            goToAcceptedAt = now
            sawSlewingSinceGoTo = false
        case .replied(let r): lastAction = .goToFailed(r.rejection)
        case .recordedOnly: lastAction = .goToFailed(nil)          // tidak terjadi untuk GoTo
        case .failed(let reason): lastAction = .goToFailed(reason)
        }
        // Ditolak tegas oleh iPhone = tidak bergerak. Tanpa jawaban = mungkin
        // bergerak, jadi Stop tetap terlihat (goToIssued tetap true).
        if case .replied(let r) = result, !r.accepted { goToIssued = false }
    }

    public mutating func beginStop() {
        lastAction = .sendingStop
    }

    public mutating func finishStop(_ result: LiveSendResult) {
        if case .replied(let r) = result, r.accepted {
            lastAction = .stopAccepted
            goToIssued = false
            sawSlewingSinceGoTo = false
        } else if case .failed(let reason) = result {
            lastAction = .stopFailed(reason)
        } else if case .replied(let r) = result {
            lastAction = .stopFailed(r.rejection)
        } else {
            lastAction = .stopFailed(nil)
        }
    }
}

// MARK: - Teks

public enum TelescopeControlText {
    public static func state(_ s: TelescopeEffectiveState) -> String {
        switch s {
        case .disabled: return TextLocalization.text(.telescopeCtlDisabled)
        case .disconnected: return TextLocalization.text(.telescopeCtlDisconnected)
        case .ready: return TextLocalization.text(.telescopeCtlReady)
        case .slewing: return TextLocalization.text(.telescopeCtlSlewing)
        case .error: return TextLocalization.text(.telescopeCtlError)
        case .unknown: return TextLocalization.text(.telescopeCtlUnknown)
        }
    }

    /// SF Symbol per keadaan: ikon + teks, tidak pernah warna saja.
    public static func symbol(_ s: TelescopeEffectiveState) -> String {
        switch s {
        case .disabled: return "scope"
        case .disconnected: return "wifi.slash"
        case .ready: return "checkmark.circle"
        case .slewing: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle"
        case .unknown: return "questionmark.circle"
        }
    }

    public static func goTo(_ name: String) -> String { TextLocalization.text(.telescopeCtlGoTo, name) }
    public static var stop: String { TextLocalization.text(.telescopeCtlStop) }
    public static var phoneUnreachable: String { TextLocalization.text(.telescopeCtlPhoneUnreachable) }

    public static func action(_ a: TelescopeControlModel.Action) -> String? {
        switch a {
        case .none: return nil
        case .sendingGoTo: return TextLocalization.text(.telescopeCtlSendingGoTo)
        case .goToAccepted: return TextLocalization.text(.telescopeCtlGoToAccepted)
        case .goToCompleted: return TextLocalization.text(.telescopeCtlGoToCompleted)
        case .goToFailed(let r): return TextLocalization.text(.telescopeCtlGoToFailed, reason(r))
        case .sendingStop: return TextLocalization.text(.telescopeCtlSendingStop)
        case .stopAccepted: return TextLocalization.text(.telescopeCtlStopAccepted)
        case .stopFailed(let r): return TextLocalization.text(.telescopeCtlStopFailed, reason(r))
        }
    }

    public static func reason(_ r: LiveRejection?) -> String {
        switch r {
        case .unreachable?: return TextLocalization.text(.telescopeCtlPhoneUnreachable)
        case .noReply?: return TextLocalization.text(.telescopeCtlReasonNoReply)
        case .stale?: return TextLocalization.text(.telescopeCtlReasonStale)
        case .notConfirmed?: return TextLocalization.text(.telescopeCtlReasonNotConfirmed)
        case .telescopeUnavailable?: return TextLocalization.text(.telescopeCtlReasonUnavailable)
        case .unsafe?: return TextLocalization.text(.telescopeCtlReasonUnsafe)
        default: return TextLocalization.text(.telescopeCtlReasonOther)
        }
    }
}

public extension LocalizedText {
    static let telescopeCtlDisabled = LocalizedText(key: "telescopeCtl.state.disabled", id: "Teleskop mati")
    static let telescopeCtlDisconnected = LocalizedText(key: "telescopeCtl.state.disconnected", id: "Teleskop terputus")
    static let telescopeCtlReady = LocalizedText(key: "telescopeCtl.state.ready", id: "Teleskop siap")
    static let telescopeCtlSlewing = LocalizedText(key: "telescopeCtl.state.slewing", id: "Teleskop bergerak")
    static let telescopeCtlError = LocalizedText(key: "telescopeCtl.state.error", id: "Teleskop galat")
    static let telescopeCtlUnknown = LocalizedText(key: "telescopeCtl.state.unknown", id: "Keadaan teleskop tidak diketahui")
    static let telescopeCtlGoTo = LocalizedText(key: "telescopeCtl.goTo", id: "Arahkan teleskop ke %@")
    static let telescopeCtlStop = LocalizedText(key: "telescopeCtl.stop", id: "Stop")
    static let telescopeCtlPhoneUnreachable = LocalizedText(key: "telescopeCtl.phoneUnreachable",
                                                            id: "iPhone tidak terjangkau")
    static let telescopeCtlSendingGoTo = LocalizedText(key: "telescopeCtl.sendingGoTo", id: "Mengirim GoTo…")
    static let telescopeCtlGoToAccepted = LocalizedText(key: "telescopeCtl.goToAccepted", id: "GoTo diterima")
    static let telescopeCtlGoToFailed = LocalizedText(key: "telescopeCtl.goToFailed", id: "GoTo gagal: %@")
    static let telescopeCtlGoToCompleted = LocalizedText(key: "telescopeCtl.goToCompleted",
                                                         id: "Teleskop sampai di target")
    static let telescopeCtlSendingStop = LocalizedText(key: "telescopeCtl.sendingStop", id: "Mengirim Stop…")
    static let telescopeCtlStopAccepted = LocalizedText(key: "telescopeCtl.stopAccepted", id: "Teleskop dihentikan")
    static let telescopeCtlStopFailed = LocalizedText(key: "telescopeCtl.stopFailed",
                                                      id: "Stop gagal: %@ — hentikan di iPhone")
    static let telescopeCtlReasonNoReply = LocalizedText(key: "telescopeCtl.reason.noReply",
                                                         id: "tidak ada jawaban, periksa iPhone")
    static let telescopeCtlReasonStale = LocalizedText(key: "telescopeCtl.reason.stale", id: "perintah kedaluwarsa")
    static let telescopeCtlReasonNotConfirmed = LocalizedText(key: "telescopeCtl.reason.notConfirmed",
                                                              id: "objek belum dikonfirmasi di iPhone")
    static let telescopeCtlReasonUnavailable = LocalizedText(key: "telescopeCtl.reason.unavailable",
                                                             id: "teleskop tidak siap")
    static let telescopeCtlReasonUnsafe = LocalizedText(key: "telescopeCtl.reason.unsafe",
                                                        id: "ditolak pengaman (Matahari/ketinggian)")
    static let telescopeCtlReasonOther = LocalizedText(key: "telescopeCtl.reason.other", id: "galat")

    static let telescopeControlKeys: [LocalizedText] = [
        .telescopeCtlDisabled, .telescopeCtlDisconnected, .telescopeCtlReady, .telescopeCtlSlewing,
        .telescopeCtlError, .telescopeCtlUnknown, .telescopeCtlGoTo, .telescopeCtlStop,
        .telescopeCtlPhoneUnreachable, .telescopeCtlSendingGoTo, .telescopeCtlGoToAccepted,
        .telescopeCtlGoToFailed, .telescopeCtlGoToCompleted, .telescopeCtlSendingStop, .telescopeCtlStopAccepted, .telescopeCtlStopFailed,
        .telescopeCtlReasonNoReply, .telescopeCtlReasonStale, .telescopeCtlReasonNotConfirmed,
        .telescopeCtlReasonUnavailable, .telescopeCtlReasonUnsafe, .telescopeCtlReasonOther,
    ]
}
