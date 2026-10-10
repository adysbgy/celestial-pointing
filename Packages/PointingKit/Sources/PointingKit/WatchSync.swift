import Foundation

/// Keadaan sambungan jam ↔ iPhone yang **dilihat pengguna** (ADR-020).
///
/// Diturunkan dari empat fakta WatchConnectivity: dipasangkan, app jam
/// terpasang, terjangkau (app jam sedang terbuka), dan kapan data terakhir
/// diterima. Satu sumber untuk pil status di iPhone, lembar detail, dan
/// langkah onboarding — supaya ketiganya tidak pernah berbeda pendapat.
public enum WatchConnectionState: Equatable, Sendable {
    /// Tidak ada Apple Watch dipasangkan dengan iPhone ini.
    case notPaired
    /// Jam dipasangkan, tetapi app Point & Know belum terpasang di jam.
    case appNotInstalled
    /// Terpasang, tetapi app jam tidak sedang terbuka. Konfirmasi tetap
    /// tersimpan di jam dan dikirim nanti (antre).
    case standby(lastContact: Date?)
    /// App jam terbuka dan terjangkau: data mengalir langsung.
    case live

    public init(isPaired: Bool, isAppInstalled: Bool, isReachable: Bool, lastContact: Date?) {
        if !isPaired { self = .notPaired }
        else if !isAppInstalled { self = .appNotInstalled }
        else if isReachable { self = .live }
        else { self = .standby(lastContact: lastContact) }
    }

    /// Hijau = langsung; kuning = tersambung tapi tidak langsung; abu = belum siap.
    public var isLive: Bool { self == .live }
    public var isReady: Bool { if case .notPaired = self { return false }; if case .appNotInstalled = self { return false }; return true }

    public var title: String {
        switch self {
        case .live: return TextLocalization.text(.connLive)
        case .standby: return TextLocalization.text(.connStandby)
        case .appNotInstalled: return TextLocalization.text(.connNotInstalled)
        case .notPaired: return TextLocalization.text(.connNotPaired)
        }
    }

    public func detail(now: Date = Date()) -> String {
        switch self {
        case .live: return TextLocalization.text(.connLiveDetail)
        case .standby(let last):
            let base = TextLocalization.text(.connStandbyDetail)
            guard let last else { return base }
            return TextLocalization.text(.connLastContact, Self.relative(last, now: now)) + " " + base
        case .appNotInstalled: return TextLocalization.text(.connNotInstalledDetail)
        case .notPaired: return TextLocalization.text(.connNotPairedDetail)
        }
    }

    /// "5 menit lalu" dalam bahasa aktif.
    public static func relative(_ date: Date, now: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: NumberFormat.activeLocaleId)
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: now)
    }
}

/// Pengaturan yang dipakai **kedua** perangkat, disinkronkan dua arah
/// (ADR-020). Yang terbaru menang (`updatedAt`), jadi mengubah di iPhone
/// atau di jam sama-sama berlaku di keduanya.
public struct SyncedSettings: Codable, Equatable, Sendable {
    public static let plistKey = "settings.v1"

    public var darkSky: Bool
    public var hotCold: Bool
    public var updatedAt: Date

    public init(darkSky: Bool, hotCold: Bool, updatedAt: Date = Date()) {
        self.darkSky = darkSky
        self.hotCold = hotCold
        self.updatedAt = updatedAt
    }

    public var plist: [String: Any] {
        [Self.plistKey: ["darkSky": darkSky, "hotCold": hotCold, "t": updatedAt.timeIntervalSince1970]]
    }

    public init?(plist: [String: Any]) {
        guard let d = plist[Self.plistKey] as? [String: Any],
              let dark = d["darkSky"] as? Bool, let hot = d["hotCold"] as? Bool,
              let t = d["t"] as? Double else { return nil }
        self.init(darkSky: dark, hotCold: hot, updatedAt: Date(timeIntervalSince1970: t))
    }

    /// Terapkan `incoming` hanya bila lebih baru — perubahan lokal yang lebih
    /// baru tidak boleh ditimpa pesan lama yang datang terlambat.
    public func merged(with incoming: SyncedSettings) -> SyncedSettings {
        incoming.updatedAt > updatedAt ? incoming : self
    }
}

/// Teks sambungan & sinkron (ADR-020).
public enum ConnectionText {
    public static var title: String { TextLocalization.text(.connTitle) }
    public static var stepPaired: String { TextLocalization.text(.connStepPaired) }
    public static var stepInstalled: String { TextLocalization.text(.connStepInstalled) }
    public static var stepOpen: String { TextLocalization.text(.connStepOpen) }
    public static var stepData: String { TextLocalization.text(.connStepData) }
    public static var whatSyncs: String { TextLocalization.text(.connWhatSyncs) }
    public static var syncConfirmations: String { TextLocalization.text(.connSyncConfirmations) }
    public static var syncSettings: String { TextLocalization.text(.connSyncSettings) }
    public static var syncPointing: String { TextLocalization.text(.connSyncPointing) }
    public static var fromWatch: String { TextLocalization.text(.connFromWatch) }
    public static var howTo: String { TextLocalization.text(.connHowTo) }
    public static var howToSteps: String { TextLocalization.text(.connHowToSteps) }
    public static var openWatchApp: String { TextLocalization.text(.connOpenWatchApp) }
    public static var phoneLive: String { TextLocalization.text(.connPhoneLive) }
    public static var phoneAway: String { TextLocalization.text(.connPhoneAway) }
    public static func neverYet() -> String { TextLocalization.text(.connNever) }
}

public extension LocalizedText {
    static let connTitle = LocalizedText(key: "conn.title", id: "Sambungan Apple Watch")
    static let connLive = LocalizedText(key: "conn.live", id: "Terhubung langsung")
    static let connLiveDetail = LocalizedText(key: "conn.liveDetail", id: "Jam dan iPhone sedang bertukar data.")
    static let connStandby = LocalizedText(key: "conn.standby", id: "Tersambung")
    static let connStandbyDetail = LocalizedText(key: "conn.standbyDetail", id: "Buka Point & Know di jam untuk data langsung. Konfirmasi tetap tersimpan dan dikirim nanti.")
    static let connLastContact = LocalizedText(key: "conn.lastContact", id: "Data terakhir %@.")
    static let connNotInstalled = LocalizedText(key: "conn.notInstalled", id: "App jam belum terpasang")
    static let connNotInstalledDetail = LocalizedText(key: "conn.notInstalledDetail", id: "Buka app Watch di iPhone → Point & Know → Pasang.")
    static let connNotPaired = LocalizedText(key: "conn.notPaired", id: "Belum ada Apple Watch")
    static let connNotPairedDetail = LocalizedText(key: "conn.notPairedDetail", id: "Pasangkan Apple Watch lewat app Watch di iPhone.")
    static let connStepPaired = LocalizedText(key: "conn.stepPaired", id: "Jam dipasangkan")
    static let connStepInstalled = LocalizedText(key: "conn.stepInstalled", id: "App terpasang di jam")
    static let connStepOpen = LocalizedText(key: "conn.stepOpen", id: "App terbuka di jam")
    static let connStepData = LocalizedText(key: "conn.stepData", id: "Data terakhir diterima")
    static let connWhatSyncs = LocalizedText(key: "conn.whatSyncs", id: "Yang tersinkron")
    static let connSyncConfirmations = LocalizedText(key: "conn.syncConfirmations", id: "Setiap \"Ya, itu dia\" masuk ke Jurnal iPhone, juga saat iPhone jauh")
    static let connSyncSettings = LocalizedText(key: "conn.syncSettings", id: "Langit gelap dan getaran panas–dingin sama di kedua perangkat")
    static let connSyncPointing = LocalizedText(key: "conn.syncPointing", id: "Arah tunjuk langsung ke iPhone dan Stellarium saat app jam terbuka")
    static let connFromWatch = LocalizedText(key: "conn.fromWatch", id: "Dari Apple Watch")
    static let connHowTo = LocalizedText(key: "conn.howTo", id: "Cara menyambungkan")
    static let connHowToSteps = LocalizedText(key: "conn.howToSteps", id: "1. Pakai jam dan buka kuncinya.\n2. Buka Point & Know di jam.\n3. Biarkan iPhone di dekatmu dengan Bluetooth menyala.")
    static let connOpenWatchApp = LocalizedText(key: "conn.openWatchApp", id: "Buka Point & Know di jam")
    static let connPhoneLive = LocalizedText(key: "conn.phoneLive", id: "iPhone tersambung")
    static let connPhoneAway = LocalizedText(key: "conn.phoneAway", id: "iPhone jauh: data dikirim nanti")
    static let connNever = LocalizedText(key: "conn.never", id: "belum pernah")

    static let connectionKeys: [LocalizedText] = [
        .connTitle, .connLive, .connLiveDetail, .connStandby, .connStandbyDetail, .connLastContact,
        .connNotInstalled, .connNotInstalledDetail, .connNotPaired, .connNotPairedDetail, .connStepPaired,
        .connStepInstalled, .connStepOpen, .connStepData, .connWhatSyncs, .connSyncConfirmations,
        .connSyncSettings, .connSyncPointing, .connFromWatch, .connHowTo, .connHowToSteps,
        .connOpenWatchApp, .connPhoneLive, .connPhoneAway, .connNever,
    ]
}
