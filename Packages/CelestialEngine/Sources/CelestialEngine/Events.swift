import Foundation

#if canImport(AstronomyKit)
import AstronomyKit
#endif

/// Peristiwa langit yang bisa dihitung luring (ADR-015).
///
/// Dipisahkan dari efemeris posisi (`SolarSystemEphemeris`) karena ini
/// **pencarian waktu** — "kapan gerhana berikutnya" — bukan "di mana benda X
/// sekarang". Protokolnya kecil supaya kalender fenomena di PointingKit bisa
/// diuji dengan nilai tulisan tangan bila perlu.
public protocol SkyEventSearch: Sendable {
    func lunarEclipses(after date: Date, count: Int) throws -> [LunarEclipseEvent]
    func localSolarEclipses(after date: Date, observer: Observer, count: Int) throws -> [SolarEclipseEvent]
    func moonQuarters(after date: Date, until end: Date) throws -> [MoonQuarterEvent]
    func maxElongation(of body: EphemerisBody, after date: Date) throws -> ElongationEvent?
}

public struct LunarEclipseEvent: Equatable, Sendable {
    public enum Kind: String, Sendable { case penumbral, partial, total }
    public var kind: Kind
    public var peak: Date
}

public struct SolarEclipseEvent: Equatable, Sendable {
    public enum Kind: String, Sendable { case partial, annular, total }
    public var kind: Kind
    public var peak: Date
    /// Ketinggian Matahari saat puncak, dari pengamat (derajat).
    public var sunAltitudeDeg: Double
    /// Fraksi piringan Matahari yang tertutup, 0…1.
    public var obscuration: Double
}

public struct MoonQuarterEvent: Equatable, Sendable {
    public enum Phase: String, Sendable { case new, firstQuarter, full, thirdQuarter }
    public var phase: Phase
    public var time: Date
}

public struct ElongationEvent: Equatable, Sendable {
    public var body: EphemerisBody
    public var time: Date
    /// Sudut dari Matahari (derajat).
    public var angleDeg: Double
    /// `true` = tampak pagi (sebelum Matahari terbit), `false` = petang.
    public var isMorning: Bool
}

#if canImport(AstronomyKit)
/// Pencarian peristiwa memakai Astronomy Engine (lewat AstronomyKit).
public struct AstronomyKitEvents: SkyEventSearch {
    public init() {}

    public func lunarEclipses(after date: Date, count: Int) throws -> [LunarEclipseEvent] {
        var out: [LunarEclipseEvent] = []
        guard count > 0 else { return out }
        var e = try Eclipse.searchLunar(after: AstroTime(date))
        for i in 0..<count {
            // Pembungkus memetakan penumbra ke `.none`; durasinya yang jujur.
            let kind: LunarEclipseEvent.Kind = e.totalDuration > 0 ? .total
                : (e.partialDuration > 0 ? .partial : .penumbral)
            out.append(LunarEclipseEvent(kind: kind, peak: e.peak.date))
            if i + 1 < count { e = try Eclipse.nextLunar(after: e) }
        }
        return out
    }

    public func localSolarEclipses(after date: Date, observer: Observer, count: Int) throws -> [SolarEclipseEvent] {
        var out: [SolarEclipseEvent] = []
        guard count > 0 else { return out }
        let site = AstronomyKit.Observer(latitude: observer.latitudeDeg, longitude: observer.longitudeDeg)
        var e = try Eclipse.searchLocalSolar(after: AstroTime(date), from: site)
        for i in 0..<count {
            let kind: SolarEclipseEvent.Kind
            switch e.kind {
            case .total: kind = .total
            case .annular: kind = .annular
            default: kind = .partial
            }
            out.append(SolarEclipseEvent(kind: kind, peak: e.peak.time.date,
                                         sunAltitudeDeg: e.peak.altitude, obscuration: e.obscuration))
            if i + 1 < count { e = try Eclipse.nextLocalSolar(after: e, from: site) }
        }
        return out
    }

    public func moonQuarters(after date: Date, until end: Date) throws -> [MoonQuarterEvent] {
        var out: [MoonQuarterEvent] = []
        var q = try Moon.searchQuarter(after: AstroTime(date))
        while q.time.date < end, out.count < 64 {
            let phase: MoonQuarterEvent.Phase
            switch q.phase {
            case .new: phase = .new
            case .firstQuarter: phase = .firstQuarter
            case .full: phase = .full
            case .thirdQuarter: phase = .thirdQuarter
            }
            out.append(MoonQuarterEvent(phase: phase, time: q.time.date))
            q = try Moon.nextQuarter(after: q)
        }
        return out
    }

    public func maxElongation(of body: EphemerisBody, after date: Date) throws -> ElongationEvent? {
        let target: CelestialBody
        switch body {
        case .mercury: target = .mercury
        case .venus: target = .venus
        default: return nil
        }
        let e = try target.searchMaxElongation(after: AstroTime(date))
        return ElongationEvent(body: body, time: e.time.date, angleDeg: e.angle,
                               isMorning: e.visibility == .morning)
    }
}
#endif
