import Foundation
import CelestialEngine

/// Petunjuk arah ke benda terlihat terdekat (Docs/WATCH_NOT_SURE_ANALYSIS.md).
///
/// **Kenapa ada.** Dengan katalog sekarang, ~43% arah langit malam tidak punya
/// satu pun benda dalam kerucut 20° — dengan kompas sempurna sekalipun. Tanpa
/// petunjuk, layar hanya bisa berkata "Belum yakin" dan pengguna tidak tahu
/// harus ke mana. Petunjuk ini memberi satu langkah berikutnya yang pasti:
/// "Jupiter, 25° ke kanan atas".
///
/// Petunjuk **bukan** identifikasi: ia tidak pernah mengunci, tidak memicu
/// haptic sukses, dan tidak membuka GoTo. Ia hanya menunjuk ke benda yang
/// memang lolos penyaring visibilitas yang sama dengan resolver.
public struct GuideHint: Equatable, Sendable {
    public var objectID: String
    public var name: String
    public var kind: ObjectKind
    /// Jarak sudut dari arah tunjuk sekarang (derajat).
    public var separationDeg: Double
    /// Arah panah di layar: 0° = naik, 90° = kanan, searah jarum jam.
    public var arrowDeg: Double

    public init(objectID: String, name: String, kind: ObjectKind,
                separationDeg: Double, arrowDeg: Double) {
        self.objectID = objectID
        self.name = name
        self.kind = kind
        self.separationDeg = separationDeg
        self.arrowDeg = arrowDeg
    }
}

public enum SkyGuide {

    /// Benda terlihat terdekat dari arah tunjuk, beserta arah panahnya.
    ///
    /// `nil` bila tidak ada target sama sekali (mis. siang hari).
    public static func hint(from pointing: HorizontalCoord,
                            to targets: [PointingTarget]) -> GuideHint? {
        let best = targets.min {
            SkyMath.angularSeparationHorizontalDeg(pointing, $0.direction)
                < SkyMath.angularSeparationHorizontalDeg(pointing, $1.direction)
        }
        guard let best else { return nil }
        return GuideHint(objectID: best.id,
                         name: best.name,
                         kind: best.kind,
                         separationDeg: SkyMath.angularSeparationHorizontalDeg(pointing, best.direction),
                         arrowDeg: arrowDeg(from: pointing, to: best.direction))
    }

    /// Arah panah dari `pointing` ke `target` pada bidang singgung langit di
    /// arah tunjuk, dilihat oleh pengamat yang menghadap `pointing`.
    ///
    /// Dihitung dengan vektor (bukan selisih azimut/altitude mentah) supaya
    /// tetap benar di dekat zenit, tempat selisih azimut kehilangan arti.
    /// Kanan = azimut bertambah (menghadap Utara, Timur ada di kanan).
    public static func arrowDeg(from pointing: HorizontalCoord, to target: HorizontalCoord) -> Double {
        let az = pointing.azimuthDeg * .pi / 180
        let alt = pointing.altitudeDeg * .pi / 180
        // ENU: (timur, utara, atas).
        let right = (x: cos(az), y: -sin(az), z: 0.0)
        let up = (x: -sin(az) * sin(alt), y: -cos(az) * sin(alt), z: cos(alt))
        let tAz = target.azimuthDeg * .pi / 180
        let tAlt = target.altitudeDeg * .pi / 180
        let t = (x: sin(tAz) * cos(tAlt), y: cos(tAz) * cos(tAlt), z: sin(tAlt))
        let dx = t.x * right.x + t.y * right.y + t.z * right.z
        let dy = t.x * up.x + t.y * up.y + t.z * up.z
        return SkyMath.normalizeDeg(atan2(dx, dy) * 180 / .pi)
    }
}

/// Kapan langit cukup gelap, dan apa yang akan terlihat.
public enum DarknessForecast {

    /// Saat pertama langit dianggap gelap (ambang yang sama dengan
    /// `VisibilityFilter.isDark`), dalam 24 jam setelah `date`.
    ///
    /// Mengembalikan `date` bila sudah gelap, dan `nil` bila tidak gelap sama
    /// sekali dalam 24 jam (lintang tinggi di musim panas) atau tanpa efemeris.
    public static func nextDark(after date: Date,
                                observer: Observer,
                                resolver: PointingResolver,
                                step: TimeInterval = 15 * 60) -> Date? {
        guard resolver.ephemeris != nil else { return nil }
        func dark(_ t: Date) -> Bool { resolver.skyContext(observer: observer, date: t).isDark }
        if dark(date) { return date }
        var lower = date
        while lower.timeIntervalSince(date) < 24 * 3600 {
            let upper = lower.addingTimeInterval(step)
            if dark(upper) {
                // Bisection ke ketelitian satu menit.
                var lo = lower, hi = upper
                while hi.timeIntervalSince(lo) > 60 {
                    let mid = lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2)
                    if dark(mid) { hi = mid } else { lo = mid }
                }
                return hi
            }
            lower = upper
        }
        return nil
    }

    /// Benda paling terang yang akan terlihat satu jam setelah gelap.
    public static func tonight(after date: Date,
                               observer: Observer,
                               resolver: PointingResolver,
                               limit: Int = 3) -> [PointingTarget] {
        guard let dark = nextDark(after: date, observer: observer, resolver: resolver) else { return [] }
        return Array(resolver.visibleTargets(observer: observer,
                                             date: dark.addingTimeInterval(3600)).prefix(limit))
    }
}

public extension PointingResolver {

    /// Target yang **benar-benar** bisa dilihat sekarang: lolos penyaring
    /// visibilitas yang sama dengan `diagnose` (horizon, magnitudo, terang
    /// langit, jarak dari Matahari). Urut dari yang paling terang.
    func visibleTargets(observer: Observer, date: Date) -> [PointingTarget] {
        let context = skyContext(observer: observer, date: date)
        let sun = sunDirection(observer: observer, date: date)
        return availableTargets(observer: observer, date: date).filter { target in
            let separation = sun.map { SkyMath.angularSeparationHorizontalDeg(target.direction, $0) }
            return VisibilityFilter.classify(altitudeDeg: target.direction.altitudeDeg,
                                             magnitude: target.magnitude,
                                             separationFromSunDeg: separation,
                                             context: context,
                                             policy: policy).isCandidate
        }
    }

    /// Arah Matahari, dari efemeris (Matahari sengaja bukan target).
    private func sunDirection(observer: Observer, date: Date) -> HorizontalCoord? {
        guard let ephemeris, let sample = try? ephemeris.apparent(.sun, at: date, from: observer) else {
            return nil
        }
        return SkyMath.equatorialToHorizontal(EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
                                              observer: observer,
                                              jd: SkyMath.julianDate(from: date))
    }
}
