import Foundation
import CelestialEngine

/// Teks layar utama jam versi baru (ADR-010, Docs/WATCH_UX_SPEC.md).
///
/// Prinsipnya: kata sehari-hari, satu gagasan per baris, tanpa angka teknis
/// (σ, °/dtk, nama kerangka) di alur utama. Angka teknis tetap ada di
/// Pengaturan → Detail teknis.
public enum WatchHomeText {
    public static var aimTitle: String { TextLocalization.text(.homeAimTitle) }
    public static var aimHint: String { TextLocalization.text(.homeAimHint) }
    public static var holdStill: String { TextLocalization.text(.homeHoldStill) }
    public static var possibleTitle: String { TextLocalization.text(.homePossibleTitle) }
    public static var notSureTitle: String { TextLocalization.text(.homeNotSureTitle) }
    public static var notSureHint: String { TextLocalization.text(.homeNotSureHint) }
    public static var unavailable: String { TextLocalization.text(.homeUnavailable) }
    public static var approxLocation: String { TextLocalization.text(.homeApproxLocation) }
    public static var settings: String { TextLocalization.text(.homeSettings) }
    public static var technicalDetails: String { TextLocalization.text(.homeTechnicalDetails) }
    public static var developerSection: String { TextLocalization.text(.homeDeveloperSection) }
    public static var nightMode: String { TextLocalization.text(.homeNightMode) }
    public static var soundOnLock: String { TextLocalization.text(.homeSoundOnLock) }
    public static var skyAndLocation: String { TextLocalization.text(.homeSkyAndLocation) }
    public static var phoneLink: String { TextLocalization.text(.homePhoneLink) }
    public static var confirmShort: String { TextLocalization.text(.homeConfirmShort) }
    public static var whatIsIt: String { TextLocalization.text(.homeWhatIsIt) }
    public static var dayTitle: String { TextLocalization.text(.homeDayTitle) }
    public static var dayNoDark: String { TextLocalization.text(.homeDayNoDark) }
    public static var tonight: String { TextLocalization.text(.homeTonight) }
    public static var calibrateFirst: String { TextLocalization.text(.homeCalibrateFirst) }
    public static var whyNotSure: String { TextLocalization.text(.homeWhyNotSure) }
    public static var nothingHere: String { TextLocalization.text(.homeNothingHere) }

    /// "Bintang muncul sekitar 18.12" — jam dalam format lokal perangkat.
    public static func darkAt(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: NumberFormat.activeLocaleId)
        f.timeZone = timeZone
        f.setLocalizedDateFormatFromTemplate("Hm")
        return TextLocalization.text(.homeDayDarkAt, f.string(from: date))
    }

    /// "Geser ke Jupiter".
    public static func guideTitle(_ name: String) -> String {
        TextLocalization.text(.homeGuideTitle, name)
    }

    /// "25° lagi".
    public static func guideDistance(_ deg: Double) -> String {
        TextLocalization.text(.homeGuideDistance, degrees(deg))
    }

    /// Sudut bulat tanpa tanda negatif: "25°".
    public static func degrees(_ deg: Double) -> String {
        NumberFormat.decimal(max(0, deg), fractionDigits: 0) + "°"
    }

    public static func altitude(_ deg: Double) -> String {
        TextLocalization.text(.homeAltitude, NumberFormat.decimal(max(0, deg), fractionDigits: 0) + "°")
    }

    public static func direction(azimuthDeg: Double) -> String {
        TextLocalization.text(.homeDirection, compass(azimuthDeg: azimuthDeg))
    }

    /// Arah mata angin 8 titik.
    public static func compass(azimuthDeg: Double) -> String {
        compassKey(azimuthDeg: azimuthDeg).map(TextLocalization.text) ?? "–"
    }

    static func compassKey(azimuthDeg: Double) -> LocalizedText? {
        guard azimuthDeg.isFinite else { return nil }
        let keys: [LocalizedText] = [.compassN, .compassNE, .compassE, .compassSE,
                                     .compassS, .compassSW, .compassW, .compassNW]
        let a = SkyMath.normalizeDeg(azimuthDeg)
        return keys[Int(((a + 22.5) / 45).rounded(.down)) % 8]
    }

    /// Kecerlangan dalam kata, dari magnitudo.
    public static func brightness(magnitude: Double) -> String {
        TextLocalization.text(brightnessKey(magnitude: magnitude))
    }

    static func brightnessKey(magnitude: Double) -> LocalizedText {
        switch magnitude {
        case ..<0: return .brightnessVeryBright
        case ..<1.5: return .brightnessBright
        case ..<3: return .brightnessModerate
        default: return .brightnessFaint
        }
    }

    /// Baris ringkas di bawah nama: "Planet · Sangat terang".
    public static func subtitle(_ object: CelestialObject) -> String {
        object.kind.displayName + " · " + brightness(magnitude: object.magnitude)
    }
}

public extension LocalizedText {
    static let homeAimTitle = LocalizedText(key: "home.aim.title", id: "Tunjuk ke langit")
    static let homeAimHint = LocalizedText(key: "home.aim.hint", id: "Angkat lengan ke arah yang Anda lihat")
    static let homeHoldStill = LocalizedText(key: "home.holdStill", id: "Tahan diam…")
    static let homePossibleTitle = LocalizedText(key: "home.possible.title", id: "Mungkin salah satu ini")
    static let homeNotSureTitle = LocalizedText(key: "home.notSure.title", id: "Belum yakin")
    static let homeNotSureHint = LocalizedText(key: "home.notSure.hint", id: "Tunjuk lebih tepat, lalu tahan diam")
    static let homeUnavailable = LocalizedText(key: "home.unavailable", id: "Sensor gerak tidak tersedia")
    static let homeApproxLocation = LocalizedText(key: "home.approxLocation", id: "Lokasi perkiraan")
    static let homeSettings = LocalizedText(key: "home.settings", id: "Pengaturan")
    static let homeTechnicalDetails = LocalizedText(key: "home.technicalDetails", id: "Detail teknis")
    static let homeDeveloperSection = LocalizedText(key: "home.developerSection", id: "Pengembang")
    static let homeNightMode = LocalizedText(key: "home.nightMode", id: "Mode malam (merah)")
    static let homeSoundOnLock = LocalizedText(key: "home.soundOnLock", id: "Bunyi saat ketemu")
    static let homeSkyAndLocation = LocalizedText(key: "home.skyAndLocation", id: "Langit & lokasi")
    static let homePhoneLink = LocalizedText(key: "home.phoneLink", id: "Koneksi iPhone")
    static let homeConfirmShort = LocalizedText(key: "home.confirmShort", id: "Ya, itu dia")
    static let homeWhatIsIt = LocalizedText(key: "home.whatIsIt", id: "Itu adalah")
    static let homeAltitude = LocalizedText(key: "home.altitude", id: "%@ di atas cakrawala")
    static let homeDirection = LocalizedText(key: "home.direction", id: "Arah %@")
    static let homeDayTitle = LocalizedText(key: "home.day.title", id: "Masih siang")
    static let homeDayDarkAt = LocalizedText(key: "home.day.darkAt", id: "Bintang muncul sekitar %@")
    static let homeDayNoDark = LocalizedText(key: "home.day.noDark", id: "Langit tidak gelap dalam 24 jam")
    static let homeTonight = LocalizedText(key: "home.tonight", id: "Malam ini")
    static let homeGuideTitle = LocalizedText(key: "home.guide.title", id: "Geser ke %@")
    static let homeGuideDistance = LocalizedText(key: "home.guide.distance", id: "%@ lagi")
    static let homeCalibrateFirst = LocalizedText(key: "home.calibrateFirst", id: "Arah kompas belum ada. Kalibrasi dulu.")
    static let homeWhyNotSure = LocalizedText(key: "home.whyNotSure", id: "Kenapa belum yakin?")
    static let homeNothingHere = LocalizedText(key: "home.nothingHere", id: "Tidak ada benda terang di sini")
    static let compassN = LocalizedText(key: "compass.n", id: "utara")
    static let compassNE = LocalizedText(key: "compass.ne", id: "timur laut")
    static let compassE = LocalizedText(key: "compass.e", id: "timur")
    static let compassSE = LocalizedText(key: "compass.se", id: "tenggara")
    static let compassS = LocalizedText(key: "compass.s", id: "selatan")
    static let compassSW = LocalizedText(key: "compass.sw", id: "barat daya")
    static let compassW = LocalizedText(key: "compass.w", id: "barat")
    static let compassNW = LocalizedText(key: "compass.nw", id: "barat laut")
    static let brightnessVeryBright = LocalizedText(key: "brightness.veryBright", id: "Sangat terang")
    static let brightnessBright = LocalizedText(key: "brightness.bright", id: "Terang")
    static let brightnessModerate = LocalizedText(key: "brightness.moderate", id: "Cukup terang")
    static let brightnessFaint = LocalizedText(key: "brightness.faint", id: "Redup")

    static let watchHomeKeys: [LocalizedText] = [
        .homeAimTitle, .homeAimHint, .homeHoldStill, .homePossibleTitle, .homeNotSureTitle,
        .homeNotSureHint, .homeUnavailable, .homeApproxLocation, .homeSettings, .homeTechnicalDetails,
        .homeDeveloperSection, .homeNightMode, .homeSoundOnLock, .homeSkyAndLocation, .homePhoneLink,
        .homeConfirmShort, .homeWhatIsIt, .homeAltitude, .homeDirection,
        .compassN, .compassNE, .compassE, .compassSE, .compassS, .compassSW, .compassW, .compassNW,
        .brightnessVeryBright, .brightnessBright, .brightnessModerate, .brightnessFaint,
        .homeDayTitle, .homeDayDarkAt, .homeDayNoDark, .homeTonight, .homeGuideTitle,
        .homeGuideDistance, .homeCalibrateFirst, .homeWhyNotSure, .homeNothingHere,
    ]
}
