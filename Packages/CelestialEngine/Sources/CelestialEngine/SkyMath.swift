import Foundation

/// Matematika langit dasar: waktu sidereal, konversi koordinat, jarak sudut.
public enum SkyMath {

    public static func julianDate(from date: Date) -> Double {
        return date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    /// Greenwich Mean Sidereal Time (derajat).
    public static func gmstDegrees(jd: Double) -> Double {
        let t = (jd - 2451545.0) / 36525.0
        var g = 280.46061837
            + 360.98564736629 * (jd - 2451545.0)
            + 0.000387933 * t * t
            - (t * t * t) / 38710000.0
        g = g.truncatingRemainder(dividingBy: 360.0)
        if g < 0 { g += 360.0 }
        return g
    }

    /// Local Sidereal Time (derajat).
    public static func lstDegrees(jd: Double, longitudeDeg: Double) -> Double {
        var l = gmstDegrees(jd: jd) + longitudeDeg
        l = l.truncatingRemainder(dividingBy: 360.0)
        if l < 0 { l += 360.0 }
        return l
    }

    /// Ekuatorial -> horizontal (alt-az).
    public static func equatorialToHorizontal(_ eq: EquatorialCoord,
                                              observer: Observer,
                                              jd: Double) -> HorizontalCoord {
        let lst = lstDegrees(jd: jd, longitudeDeg: observer.longitudeDeg)
        let h = deg2rad(normalizeDeg(lst - eq.raDeg))          // hour angle
        let dec = deg2rad(eq.decDeg)
        let lat = deg2rad(observer.latitudeDeg)
        let sinAlt = sin(dec) * sin(lat) + cos(dec) * cos(lat) * cos(h)
        let alt = asin(max(-1.0, min(1.0, sinAlt)))
        let azFromSouth = atan2(sin(h), cos(h) * sin(lat) - tan(dec) * cos(lat))
        let az = normalizeDeg(rad2deg(azFromSouth) + 180.0)
        return HorizontalCoord(altitudeDeg: rad2deg(alt), azimuthDeg: az)
    }

    /// Jarak sudut antara dua koordinat ekuatorial (derajat).
    public static func angularSeparationDeg(_ a: EquatorialCoord, _ b: EquatorialCoord) -> Double {
        let a1 = deg2rad(a.decDeg), a2 = deg2rad(b.decDeg)
        let d = deg2rad(b.raDeg - a.raDeg)
        let cosd = sin(a1) * sin(a2) + cos(a1) * cos(a2) * cos(d)
        return rad2deg(acos(max(-1.0, min(1.0, cosd))))
    }

    /// Jarak sudut antara dua arah horizontal (derajat).
    public static func angularSeparationHorizontalDeg(_ a: HorizontalCoord, _ b: HorizontalCoord) -> Double {
        let alt1 = deg2rad(a.altitudeDeg), alt2 = deg2rad(b.altitudeDeg)
        let az1 = deg2rad(a.azimuthDeg), az2 = deg2rad(b.azimuthDeg)
        let x1 = cos(alt1) * cos(az1), y1 = cos(alt1) * sin(az1), z1 = sin(alt1)
        let x2 = cos(alt2) * cos(az2), y2 = cos(alt2) * sin(az2), z2 = sin(alt2)
        let dot = x1 * x2 + y1 * y2 + z1 * z2
        return rad2deg(acos(max(-1.0, min(1.0, dot))))
    }

    public static func deg2rad(_ d: Double) -> Double { d * .pi / 180.0 }
    public static func rad2deg(_ r: Double) -> Double { r * 180.0 / .pi }

    public static func normalizeDeg(_ d: Double) -> Double {
        var x = d.truncatingRemainder(dividingBy: 360.0)
        if x < 0 { x += 360.0 }
        return x
    }
}
