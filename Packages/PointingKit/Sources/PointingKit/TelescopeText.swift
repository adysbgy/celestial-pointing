import Foundation
import CelestialEngine

/// Teks pengaturan teleskop di iPhone (ADR-008).
public enum TelescopeText {
    public static var section: String { TextLocalization.text(.telescopeSection) }
    public static var enableAlpaca: String { TextLocalization.text(.telescopeEnableAlpaca) }
    public static var address: String { TextLocalization.text(.telescopeAddress) }
    public static var connect: String { TextLocalization.text(.telescopeConnect) }
    public static var stateMock: String { TextLocalization.text(.telescopeStateMock) }
    public static var stateConnecting: String { TextLocalization.text(.telescopeStateConnecting) }
    public static func stateConnected(_ system: AlpacaEquatorialSystem) -> String {
        TextLocalization.text(.telescopeStateConnected, frameName(system))
    }
    public static var stateUnsupported: String { TextLocalization.text(.telescopeStateUnsupported) }
    public static var stateFailed: String { TextLocalization.text(.telescopeStateFailed) }

    /// Nama kerangka sebagaimana dinyatakan dudukan (istilah teknis, tidak
    /// diterjemahkan).
    public static func frameName(_ system: AlpacaEquatorialSystem) -> String {
        switch system {
        case .topocentric: return "JNow"
        case .j2000: return "J2000"
        case .j2050: return "J2050"
        case .b1950: return "B1950"
        case .other: return "other"
        }
    }
}

public extension LocalizedText {
    static let telescopeSection = LocalizedText(key: "telescope.section", id: "Teleskop (eksperimental)")
    static let telescopeEnableAlpaca = LocalizedText(key: "telescope.enableAlpaca", id: "Pakai teleskop Alpaca")
    static let telescopeAddress = LocalizedText(key: "telescope.address", id: "Alamat (host:port)")
    static let telescopeConnect = LocalizedText(key: "telescope.connect", id: "Sambungkan")
    static let telescopeStateMock = LocalizedText(key: "telescope.state.mock",
                                                  id: "Tiruan — tidak ada motor yang bergerak")
    static let telescopeStateConnecting = LocalizedText(key: "telescope.state.connecting", id: "Menyambung…")
    static let telescopeStateConnected = LocalizedText(key: "telescope.state.connected", id: "Tersambung (%@)")
    static let telescopeStateUnsupported = LocalizedText(key: "telescope.state.unsupported",
                                                         id: "Dudukan tidak mendukung GoTo app ini")
    static let telescopeStateFailed = LocalizedText(key: "telescope.state.failed", id: "Gagal tersambung")

    static let telescopeKeys: [LocalizedText] = [
        .telescopeSection, .telescopeEnableAlpaca, .telescopeAddress, .telescopeConnect,
        .telescopeStateMock, .telescopeStateConnecting, .telescopeStateConnected,
        .telescopeStateUnsupported, .telescopeStateFailed,
    ]
}
