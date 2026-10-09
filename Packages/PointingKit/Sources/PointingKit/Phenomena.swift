import Foundation
import CelestialEngine

/// Satu fenomena langit di kalender (ADR-015, Docs/PRODUCT_V2_IDEA.md §4).
public struct Phenomenon: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case conjunction, lunarEclipse, solarEclipse, meteorShower, fullMoon, elongation
    }

    public var id: String
    public var kind: Kind
    /// Saat puncak, atau saat terbaik untuk melihatnya dari sini.
    public var date: Date
    /// Bisa dilihat dari lokasi ini: di atas cakrawala saat langit gelap
    /// (atau, untuk gerhana Matahari, saat Matahari di atas cakrawala).
    public var visibleHere: Bool
    /// Benda yang ditunjuk untuk fenomena ini (Bulan/planet), urut terpenting.
    public var targetIDs: [String]
    /// Radian hujan meteor (J2000), bila ini hujan meteor.
    public var radiant: EquatorialCoord?
    /// Nama tampilan benda/hujan meteor yang terlibat (dalam bahasa aktif).
    public var names: [String]
    /// Jarak sudut antar-benda (konjungsi) atau tutupan (gerhana Matahari),
    /// atau ZHR (hujan meteor).
    public var value: Double?
    /// Gerhana Matahari: **wajib filter**, dan app tidak pernah memandu ke
    /// Matahari (keputusan Ady, PRODUCT_V2_IDEA §8b).
    public var requiresSolarFilter: Bool { kind == .solarEclipse }
    /// Jenis gerhana ("total", "partial", …) bila gerhana.
    public var eclipseKind: String?

    /// Bisakah app memandu (panas–dingin) ke fenomena ini?
    public var isGuidable: Bool { !requiresSolarFilter && (radiant != nil || !targetIDs.isEmpty) }
}

/// Hujan meteor tahunan. Nilai pendekatan dari kalender IMO (puncak,
/// radian J2000, ZHR). Bergeser ±1 hari dari tahun ke tahun.
public struct MeteorShower: Equatable, Sendable {
    public var id: String
    public var name: String
    public var peakMonth: Int
    public var peakDay: Int
    public var radiant: EquatorialCoord
    public var zhr: Double

    public static let annual: [MeteorShower] = [
        MeteorShower(id: "quadrantids", name: "Quadrantid", peakMonth: 1, peakDay: 4,
                     radiant: EquatorialCoord(raDeg: 230, decDeg: 49), zhr: 110),
        MeteorShower(id: "lyrids", name: "Lyrid", peakMonth: 4, peakDay: 22,
                     radiant: EquatorialCoord(raDeg: 271, decDeg: 34), zhr: 18),
        MeteorShower(id: "eta-aquariids", name: "Eta Aquariid", peakMonth: 5, peakDay: 6,
                     radiant: EquatorialCoord(raDeg: 338, decDeg: -1), zhr: 50),
        MeteorShower(id: "southern-delta-aquariids", name: "Delta Aquariid Selatan", peakMonth: 7, peakDay: 30,
                     radiant: EquatorialCoord(raDeg: 340, decDeg: -16), zhr: 25),
        MeteorShower(id: "perseids", name: "Perseid", peakMonth: 8, peakDay: 12,
                     radiant: EquatorialCoord(raDeg: 48, decDeg: 58), zhr: 100),
        MeteorShower(id: "orionids", name: "Orionid", peakMonth: 10, peakDay: 21,
                     radiant: EquatorialCoord(raDeg: 95, decDeg: 16), zhr: 20),
        MeteorShower(id: "leonids", name: "Leonid", peakMonth: 11, peakDay: 17,
                     radiant: EquatorialCoord(raDeg: 152, decDeg: 22), zhr: 15),
        MeteorShower(id: "geminids", name: "Geminid", peakMonth: 12, peakDay: 14,
                     radiant: EquatorialCoord(raDeg: 112, decDeg: 33), zhr: 150),
    ]
}

/// Kalender fenomena luring untuk satu lokasi (ADR-015).
///
/// Semua dihitung dari efemeris dan pencarian peristiwa yang sama dengan
/// engine — tidak ada data internet. "Terlihat dari sini" memakai aturan yang
/// sama dengan penyaring visibilitas: di atas cakrawala saat langit gelap.
public enum PhenomenaCalendar {

    /// Batas jarak konjungsi (derajat).
    public static let moonPlanetMaxDeg = 6.0
    public static let planetPairMaxDeg = 3.0
    /// Ketinggian minimum agar dianggap terlihat (derajat).
    public static let minAltitudeDeg = 10.0

    /// Fenomena dari `date` ke depan, urut waktu.
    ///
    /// - Parameters:
    ///   - days: jendela konjungsi, purnama, elongasi, dan hujan meteor.
    ///   - eclipseYears: jendela gerhana (jarang, jadi lebih panjang).
    public static func upcoming(after date: Date,
                                observer: Observer,
                                resolver: PointingResolver,
                                events: SkyEventSearch?,
                                days: Int = 45,
                                eclipseYears: Double = 2) -> [Phenomenon] {
        let end = date.addingTimeInterval(Double(days) * 86400)
        var out: [Phenomenon] = []
        out += conjunctions(from: date, to: end, observer: observer, resolver: resolver)
        out += meteorShowers(from: date, to: end, observer: observer, resolver: resolver)
        if let events {
            let eclipseEnd = date.addingTimeInterval(eclipseYears * 365.25 * 86400)
            out += lunarEclipses(from: date, to: eclipseEnd, observer: observer, resolver: resolver, events: events)
            out += solarEclipses(from: date, to: eclipseEnd, observer: observer, events: events)
            out += fullMoons(from: date, to: end, observer: observer, resolver: resolver, events: events)
            out += elongations(from: date, to: end.addingTimeInterval(75 * 86400), observer: observer,
                               resolver: resolver, events: events)
        }
        return out.sorted { $0.date < $1.date }
    }

    // MARK: Konjungsi

    static func conjunctions(from start: Date, to end: Date, observer: Observer,
                             resolver: PointingResolver) -> [Phenomenon] {
        guard let ephemeris = resolver.ephemeris else { return [] }
        let bodies: [EphemerisBody] = [.moon, .mercury, .venus, .mars, .jupiter, .saturn]
        let step: TimeInterval = 2 * 3600
        var times: [Date] = []
        // Mulai di jam bulat supaya waktu yang tampil rapi (22.00, bukan 22.23).
        var t = Date(timeIntervalSince1970: (start.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        while t <= end { times.append(t); t = t.addingTimeInterval(step) }

        // Posisi tiap benda pada tiap waktu (topocentric).
        var positions: [EphemerisBody: [EquatorialCoord]] = [:]
        for body in bodies {
            positions[body] = times.map { time in
                (try? ephemeris.apparent(body, at: time, from: observer))
                    .map { EquatorialCoord(raDeg: $0.raDeg, decDeg: $0.decDeg) }
                    ?? EquatorialCoord(raDeg: .nan, decDeg: .nan)
            }
        }

        var out: [Phenomenon] = []
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let a = bodies[i], b = bodies[j]
                let limit = (a == .moon || b == .moon) ? moonPlanetMaxDeg : planetPairMaxDeg
                guard let pa = positions[a], let pb = positions[b] else { continue }
                let seps = zip(pa, pb).map { SkyMath.angularSeparationDeg($0, $1) }
                guard seps.count >= 3 else { continue }
                for k in 1..<(seps.count - 1)
                where seps[k].isFinite && seps[k] <= limit && seps[k] <= seps[k - 1] && seps[k] < seps[k + 1] {
                    let when = times[k]
                    let best = bestVisibleTime(near: when, ids: [a.rawValue, b.rawValue],
                                               observer: observer, resolver: resolver)
                    // Bulan dulu (paling mudah), lalu yang lebih terang.
                    let ordered = [a, b].sorted { lhs, rhs in
                        if lhs == .moon { return true }
                        if rhs == .moon { return false }
                        return lhs.typicalBrightestMagnitude < rhs.typicalBrightestMagnitude
                    }
                    out.append(Phenomenon(id: "conj-\(a.rawValue)-\(b.rawValue)-\(Int(when.timeIntervalSince1970))",
                                          kind: .conjunction,
                                          date: best ?? when,
                                          visibleHere: best != nil,
                                          targetIDs: ordered.map(\.rawValue),
                                          radiant: nil,
                                          names: ordered.map(\.displayName),
                                          value: seps[k],
                                          eclipseKind: nil))
                }
            }
        }
        return out
    }

    /// Waktu terbaik dalam ±10 jam di sekitar `date` ketika langit gelap dan
    /// **semua** benda di atas `minAltitudeDeg`, dipilih saat ketinggian
    /// terendah di antara mereka paling besar. `nil` bila tidak pernah.
    static func bestVisibleTime(near date: Date, ids: [String], observer: Observer,
                                resolver: PointingResolver) -> Date? {
        var best: (Date, Double)?
        for k in -20...20 {
            let t = date.addingTimeInterval(Double(k) * 1800)
            guard resolver.skyContext(observer: observer, date: t).isDark else { continue }
            let alts = ids.compactMap { resolver.horizontal(ofObjectID: $0, observer: observer, date: t)?.altitudeDeg }
            guard alts.count == ids.count, let low = alts.min(), low >= minAltitudeDeg else { continue }
            if best == nil || low > best!.1 { best = (t, low) }
        }
        return best?.0
    }

    // MARK: Hujan meteor

    static func meteorShowers(from start: Date, to end: Date, observer: Observer,
                              resolver: PointingResolver) -> [Phenomenon] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let years = Set([calendar.component(.year, from: start), calendar.component(.year, from: end)])
        var out: [Phenomenon] = []
        for year in years.sorted() {
            for shower in MeteorShower.annual {
                guard let peak = calendar.date(from: DateComponents(year: year, month: shower.peakMonth,
                                                                    day: shower.peakDay, hour: 12)),
                      peak >= start.addingTimeInterval(-86400), peak <= end else { continue }
                let best = bestRadiantTime(around: peak, radiant: shower.radiant, observer: observer,
                                           resolver: resolver)
                out.append(Phenomenon(id: "meteor-\(shower.id)-\(year)", kind: .meteorShower,
                                      date: best?.0 ?? peak, visibleHere: best != nil,
                                      targetIDs: [], radiant: shower.radiant, names: [shower.name],
                                      value: shower.zhr, eclipseKind: nil))
            }
        }
        return out
    }

    /// Jam gelap dalam ±18 jam dari puncak saat radian paling tinggi (≥ 20°).
    static func bestRadiantTime(around peak: Date, radiant: EquatorialCoord, observer: Observer,
                                resolver: PointingResolver) -> (Date, Double)? {
        var best: (Date, Double)?
        for k in -36...36 {
            let t = peak.addingTimeInterval(Double(k) * 1800)
            guard resolver.skyContext(observer: observer, date: t).isDark else { continue }
            let alt = radiantDirection(radiant, observer: observer, date: t).altitudeDeg
            guard alt >= 20 else { continue }
            if best == nil || alt > best!.1 { best = (t, alt) }
        }
        return best
    }

    /// Arah radian sekarang (radian disimpan J2000; presesi ikut dihitung).
    public static func radiantDirection(_ radiant: EquatorialCoord, observer: Observer, date: Date) -> HorizontalCoord {
        let jd = SkyMath.julianDate(from: date)
        return SkyMath.equatorialToHorizontal(SkyMath.precessJ2000ToDate(radiant, jd: jd), observer: observer, jd: jd)
    }

    // MARK: Gerhana, purnama, elongasi

    static func lunarEclipses(from start: Date, to end: Date, observer: Observer,
                              resolver: PointingResolver, events: SkyEventSearch) -> [Phenomenon] {
        let list = (try? events.lunarEclipses(after: start, count: 6)) ?? []
        return list.filter { $0.peak <= end }.map { e in
            let alt = resolver.horizontal(ofBody: .moon, observer: observer, date: e.peak)?.altitudeDeg ?? -90
            return Phenomenon(id: "lunar-\(Int(e.peak.timeIntervalSince1970))", kind: .lunarEclipse,
                              date: e.peak, visibleHere: alt >= minAltitudeDeg, targetIDs: ["moon"],
                              radiant: nil, names: [EphemerisBody.moon.displayName], value: nil,
                              eclipseKind: e.kind.rawValue)
        }
    }

    static func solarEclipses(from start: Date, to end: Date, observer: Observer,
                              events: SkyEventSearch) -> [Phenomenon] {
        let list = (try? events.localSolarEclipses(after: start, observer: observer, count: 3)) ?? []
        return list.filter { $0.peak <= end }.map { e in
            Phenomenon(id: "solar-\(Int(e.peak.timeIntervalSince1970))", kind: .solarEclipse,
                       date: e.peak, visibleHere: e.sunAltitudeDeg > 0, targetIDs: [],
                       radiant: nil, names: [], value: e.obscuration, eclipseKind: e.kind.rawValue)
        }
    }

    static func fullMoons(from start: Date, to end: Date, observer: Observer,
                          resolver: PointingResolver, events: SkyEventSearch) -> [Phenomenon] {
        let quarters = (try? events.moonQuarters(after: start, until: end)) ?? []
        return quarters.filter { $0.phase == .full }.map { q in
            let best = bestVisibleTime(near: q.time, ids: ["moon"], observer: observer, resolver: resolver)
            return Phenomenon(id: "fullmoon-\(Int(q.time.timeIntervalSince1970))", kind: .fullMoon,
                              date: best ?? q.time, visibleHere: best != nil, targetIDs: ["moon"],
                              radiant: nil, names: [EphemerisBody.moon.displayName], value: nil,
                              eclipseKind: nil)
        }
    }

    static func elongations(from start: Date, to end: Date, observer: Observer,
                            resolver: PointingResolver, events: SkyEventSearch) -> [Phenomenon] {
        [EphemerisBody.venus, .mercury].compactMap { body in
            guard let e = try? events.maxElongation(of: body, after: start), e.time <= end else { return nil }
            let best = bestVisibleTime(near: e.time, ids: [body.rawValue], observer: observer, resolver: resolver)
            return Phenomenon(id: "elong-\(body.rawValue)-\(Int(e.time.timeIntervalSince1970))",
                              kind: .elongation, date: best ?? e.time, visibleHere: best != nil,
                              targetIDs: [body.rawValue], radiant: nil, names: [body.displayName],
                              value: e.angleDeg, eclipseKind: e.isMorning ? "morning" : "evening")
        }
    }
}

public extension EngineFactory {
    /// Pencarian peristiwa bawaan bila AstronomyKit tersedia (ADR-015).
    static var defaultEventSearch: SkyEventSearch? {
        #if canImport(AstronomyKit)
        return AstronomyKitEvents()
        #else
        return nil
        #endif
    }
}

// MARK: - Teks

/// Teks kalender fenomena (ADR-015).
public enum PhenomenonText {
    public static var sectionTitle: String { TextLocalization.text(.phenTitle) }
    public static var guideThere: String { TextLocalization.text(.phenGuide) }
    public static var stopGuiding: String { TextLocalization.text(.phenStopGuide) }
    public static var solarFilter: String { TextLocalization.text(.phenSolarFilter) }

    public static func title(_ p: Phenomenon) -> String {
        switch p.kind {
        case .conjunction:
            return TextLocalization.text(.phenConjunction, p.names.first ?? "–", p.names.dropFirst().first ?? "–")
        case .lunarEclipse:
            switch p.eclipseKind {
            case "total": return TextLocalization.text(.phenLunarTotal)
            case "partial": return TextLocalization.text(.phenLunarPartial)
            default: return TextLocalization.text(.phenLunarPenumbral)
            }
        case .solarEclipse:
            switch p.eclipseKind {
            case "total": return TextLocalization.text(.phenSolarTotal)
            case "annular": return TextLocalization.text(.phenSolarAnnular)
            default: return TextLocalization.text(.phenSolarPartial)
            }
        case .meteorShower:
            return TextLocalization.text(.phenMeteor, p.names.first ?? "–")
        case .fullMoon:
            return TextLocalization.text(.phenFullMoon)
        case .elongation:
            return TextLocalization.text(p.eclipseKind == "morning" ? .phenElongationMorning : .phenElongationEvening,
                                         p.names.first ?? "–")
        }
    }

    /// Satu baris rincian: jarak, tutupan, atau ZHR.
    public static func detail(_ p: Phenomenon) -> String? {
        guard let v = p.value else { return nil }
        switch p.kind {
        case .conjunction:
            return TextLocalization.text(.phenDetailApart, NumberFormat.decimal(v, fractionDigits: 1) + "°")
        case .solarEclipse:
            return TextLocalization.text(.phenDetailCovered, NumberFormat.decimal(v * 100, fractionDigits: 0) + "%")
        case .meteorShower:
            return TextLocalization.text(.phenDetailZhr, NumberFormat.decimal(v, fractionDigits: 0))
        default:
            return nil
        }
    }

    public static func visibility(_ p: Phenomenon) -> String {
        TextLocalization.text(p.visibleHere ? .phenVisibleHere : .phenNotVisibleHere)
    }

    /// "Sab 24 Okt, 22.00" dalam bahasa dan zona waktu perangkat.
    public static func when(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: NumberFormat.activeLocaleId)
        f.timeZone = timeZone
        f.setLocalizedDateFormatFromTemplate("EEEdMMMHm")
        return f.string(from: date)
    }

    public static func guiding(_ name: String) -> String { TextLocalization.text(.phenGuiding, name) }
    public static func notUpYet(_ name: String) -> String { TextLocalization.text(.phenNotUpYet, name) }

    /// Nama sasaran pemandu untuk fenomena ini (benda pertama, atau radian).
    public static func targetName(_ p: Phenomenon) -> String {
        if p.kind == .meteorShower { return TextLocalization.text(.phenRadiant, p.names.first ?? "–") }
        return p.names.first ?? "–"
    }
}

public extension LocalizedText {
    static let phenTitle = LocalizedText(key: "phen.title", id: "Fenomena")
    static let phenGuide = LocalizedText(key: "phen.guide", id: "Pandu ke sana")
    static let phenStopGuide = LocalizedText(key: "phen.stopGuide", id: "Berhenti memandu")
    static let phenSolarFilter = LocalizedText(key: "phen.solarFilter", id: "Wajib filter Matahari. App tidak memandu ke Matahari.")
    static let phenConjunction = LocalizedText(key: "phen.conjunction", id: "%@ dekat %@")
    static let phenLunarTotal = LocalizedText(key: "phen.lunar.total", id: "Gerhana Bulan total")
    static let phenLunarPartial = LocalizedText(key: "phen.lunar.partial", id: "Gerhana Bulan sebagian")
    static let phenLunarPenumbral = LocalizedText(key: "phen.lunar.penumbral", id: "Gerhana Bulan penumbra")
    static let phenSolarTotal = LocalizedText(key: "phen.solar.total", id: "Gerhana Matahari total")
    static let phenSolarAnnular = LocalizedText(key: "phen.solar.annular", id: "Gerhana Matahari cincin")
    static let phenSolarPartial = LocalizedText(key: "phen.solar.partial", id: "Gerhana Matahari sebagian")
    static let phenMeteor = LocalizedText(key: "phen.meteor", id: "Hujan meteor %@")
    static let phenFullMoon = LocalizedText(key: "phen.fullMoon", id: "Bulan purnama")
    static let phenElongationEvening = LocalizedText(key: "phen.elongation.evening", id: "%@ tampak petang")
    static let phenElongationMorning = LocalizedText(key: "phen.elongation.morning", id: "%@ tampak pagi")
    static let phenDetailApart = LocalizedText(key: "phen.detail.apart", id: "Berjarak %@")
    static let phenDetailCovered = LocalizedText(key: "phen.detail.covered", id: "%@ tertutup")
    static let phenDetailZhr = LocalizedText(key: "phen.detail.zhr", id: "Hingga ~%@ meteor/jam di langit gelap")
    static let phenVisibleHere = LocalizedText(key: "phen.visibleHere", id: "Terlihat dari sini")
    static let phenNotVisibleHere = LocalizedText(key: "phen.notVisibleHere", id: "Tidak terlihat dari sini")
    static let phenGuiding = LocalizedText(key: "phen.guiding", id: "Memandu ke %@")
    static let phenNotUpYet = LocalizedText(key: "phen.notUpYet", id: "%@ belum terlihat dari sini")
    static let phenRadiant = LocalizedText(key: "phen.radiant", id: "Radian %@")

    static let phenomenaKeys: [LocalizedText] = [
        .phenTitle, .phenGuide, .phenStopGuide, .phenSolarFilter, .phenConjunction, .phenLunarTotal,
        .phenLunarPartial, .phenLunarPenumbral, .phenSolarTotal, .phenSolarAnnular, .phenSolarPartial,
        .phenMeteor, .phenFullMoon, .phenElongationEvening, .phenElongationMorning, .phenDetailApart,
        .phenDetailCovered, .phenDetailZhr, .phenVisibleHere, .phenNotVisibleHere, .phenGuiding,
        .phenNotUpYet, .phenRadiant,
    ]
}
