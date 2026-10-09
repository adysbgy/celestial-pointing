import Foundation
import CelestialEngine
import PointingKit

/// Langit "sekarang" untuk layar utama: benda yang terlihat, terang/gelap,
/// kapan gelap, dan apa yang terlihat malam ini (ADR-011).
///
/// Dihitung paling sering sekali per menit (langit bergeser ~0.25°/menit,
/// jauh di bawah kerucut 20°), bukan per sampel sensor 50 Hz. Arah panah ke
/// benda terdekat dihitung tiap render dari daftar ini — murah, ~20 benda.
@MainActor
final class SkyGuideModel: ObservableObject {
    @Published private(set) var visible: [PointingTarget] = []
    @Published private(set) var isDark = true
    @Published private(set) var darkAt: Date?
    @Published private(set) var tonight: [PointingTarget] = []
    @Published private(set) var sunAltitudeDeg: Double?
    /// Kalender fenomena (ADR-015), dihitung ulang paling sering tiap 30 menit.
    @Published private(set) var phenomena: [Phenomenon] = []
    /// Fenomena yang sedang dipandu (panas–dingin ke sasarannya), bila ada.
    @Published private(set) var pinned: Phenomenon?
    /// Arah sasaran yang dipandu sekarang; `nil` bila di bawah cakrawala.
    @Published private(set) var pinnedDirection: HorizontalCoord?
    @Published private(set) var pinnedTargetName: String?
    @Published private(set) var pinnedTargetID: String?

    private static let moonID = "moon"
    private var lastRefresh: Date?
    private var lastPhenomenaRefresh: Date?
    private weak var engine: PointingEngine?
    private var lastObserver: Observer?

    func refresh(engine: PointingEngine, now: Date = Date(), force: Bool = false) {
        self.engine = engine
        let observer = engine.controller.observer
        updatePinnedDirection(now: now)
        if !force, let last = lastRefresh, now.timeIntervalSince(last) < 60, lastObserver == observer { return }
        lastRefresh = now
        lastObserver = observer
        let resolver = engine.controller.resolver
        let context = resolver.skyContext(observer: observer, date: now)
        sunAltitudeDeg = context.sunAltitudeDeg
        isDark = context.isDark
        visible = resolver.visibleTargets(observer: observer, date: now)
        if force || lastPhenomenaRefresh.map({ now.timeIntervalSince($0) > 1800 }) ?? true {
            lastPhenomenaRefresh = now
            phenomena = PhenomenaCalendar.upcoming(after: now.addingTimeInterval(-6 * 3600),
                                                   observer: observer, resolver: resolver,
                                                   events: EngineFactory.defaultEventSearch)
                .filter { $0.date > now.addingTimeInterval(-3 * 3600) }
        }
        if context.isDark {
            darkAt = nil
            tonight = []
        } else {
            darkAt = DarknessForecast.nextDark(after: now, observer: observer, resolver: resolver)
            tonight = DarknessForecast.tonight(after: now, observer: observer, resolver: resolver)
        }
    }

    /// Petunjuk dari arah tunjuk sekarang: ke sasaran fenomena yang dipandu
    /// bila ada (dan sudah di atas cakrawala), selain itu ke benda terlihat
    /// terdekat.
    func hint(for pointing: HorizontalCoord?) -> GuideHint? {
        guard let pointing else { return nil }
        if let pinned {
            guard let target = pinnedDirection else { return nil }
            let name = pinnedTargetName ?? PhenomenonText.targetName(pinned)
            let id = pinnedTargetID ?? pinned.id
            return GuideHint(objectID: id,
                             name: name,
                             kind: pinned.radiant != nil ? .deepSky : (id == Self.moonID ? .moon : .planet),
                             separationDeg: SkyMath.angularSeparationHorizontalDeg(pointing, target),
                             arrowDeg: SkyGuide.arrowDeg(from: pointing, to: target))
        }
        return SkyGuide.hint(from: pointing, to: visible)
    }

    /// Mulai memandu ke fenomena ini (bukan gerhana Matahari — ADR-015).
    func pin(_ phenomenon: Phenomenon?) {
        pinned = phenomenon?.isGuidable == true ? phenomenon : nil
        updatePinnedDirection(now: Date())
    }

    /// Sasaran yang bisa dipandu sekarang: radian, atau benda pertama yang
    /// sudah di atas cakrawala (konjungsi: kalau Bulan belum terbit tapi
    /// planetnya sudah, pandu ke planetnya).
    func guideTarget(of phenomenon: Phenomenon, now: Date = Date()) -> (id: String, name: String, direction: HorizontalCoord)? {
        guard let engine else { return nil }
        let observer = engine.controller.observer
        if let radiant = phenomenon.radiant {
            let h = PhenomenaCalendar.radiantDirection(radiant, observer: observer, date: now)
            return h.altitudeDeg > 0 ? (phenomenon.id, PhenomenonText.targetName(phenomenon), h) : nil
        }
        for (i, id) in phenomenon.targetIDs.enumerated() {
            if let h = engine.controller.resolver.horizontal(ofObjectID: id, observer: observer, date: now),
               h.altitudeDeg > 0 {
                return (id, phenomenon.names.indices.contains(i) ? phenomenon.names[i] : id, h)
            }
        }
        return nil
    }

    func direction(of phenomenon: Phenomenon, now: Date = Date()) -> HorizontalCoord? {
        guideTarget(of: phenomenon, now: now)?.direction
    }

    private func updatePinnedDirection(now: Date) {
        let target = pinned.flatMap { guideTarget(of: $0, now: now) }
        pinnedDirection = target?.direction
        pinnedTargetName = target?.name
        pinnedTargetID = target?.id
    }
}

extension ObjectKind {
    /// Simbol kecil per jenis benda untuk daftar dan petunjuk.
    var guideSymbol: String {
        switch self {
        case .moon: return "moon.fill"
        case .planet: return "circle.circle.fill"
        case .star: return "sparkle"
        case .deepSky: return "hurricane"
        case .sun: return "sun.max.fill"
        }
    }
}

extension Phenomenon {
    /// Simbol keterlihatan untuk baris kalender.
    var visibilitySymbol: String { visibleHere ? "eye" : "eye.slash" }
}
