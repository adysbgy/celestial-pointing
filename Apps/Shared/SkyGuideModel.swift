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

    private var lastRefresh: Date?
    private var lastObserver: Observer?

    func refresh(engine: PointingEngine, now: Date = Date(), force: Bool = false) {
        let observer = engine.controller.observer
        if !force, let last = lastRefresh, now.timeIntervalSince(last) < 60, lastObserver == observer { return }
        lastRefresh = now
        lastObserver = observer
        let resolver = engine.controller.resolver
        let context = resolver.skyContext(observer: observer, date: now)
        sunAltitudeDeg = context.sunAltitudeDeg
        isDark = context.isDark
        visible = resolver.visibleTargets(observer: observer, date: now)
        if context.isDark {
            darkAt = nil
            tonight = []
        } else {
            darkAt = DarknessForecast.nextDark(after: now, observer: observer, resolver: resolver)
            tonight = DarknessForecast.tonight(after: now, observer: observer, resolver: resolver)
        }
    }

    /// Petunjuk ke benda terlihat terdekat dari arah tunjuk sekarang.
    func hint(for pointing: HorizontalCoord?) -> GuideHint? {
        guard let pointing else { return nil }
        return SkyGuide.hint(from: pointing, to: visible)
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
