import Foundation

/// Perata orientasi untuk meredam gemetar tangan.
///
/// Sensor Watch memberi sampel attitude mentah yang bergetar; arah tunjuk yang
/// ditampilkan harus lebih tenang daripada sensornya, tapi **tidak** boleh
/// terasa lambat mengikuti gerakan. Karena itu ini interpolasi (nlerp) dengan
/// bobot tetap, bukan filter yang bergantung waktu.
///
/// `blendFactor` = bobot sampel baru: kecil = lebih halus tapi lebih lambat,
/// besar = lebih responsif tapi lebih bergetar.
public struct PointingSmoother: Equatable, Sendable {
    public var blendFactor: Double
    public private(set) var current: Quaternion?

    public init(blendFactor: Double = 0.3) {
        self.blendFactor = max(0.0, min(1.0, blendFactor))
    }

    /// Masukkan sampel baru, kembalikan orientasi teredam.
    ///
    /// Sampel pertama langsung menjadi acuan (tanpa itu, tidak ada dasar untuk
    /// menginterpolasi). Sampel tidak sah diabaikan, bukan merusak keadaan.
    @discardableResult
    public mutating func update(_ q: Quaternion) -> Quaternion? {
        guard let n = q.normalized else { return current }
        guard let c = current else {
            current = n
            return n
        }
        guard let blended = c.interpolated(to: n, t: blendFactor) else { return current }
        current = blended
        return blended
    }

    /// Lupakan acuan (mis. setelah kalibrasi ulang).
    public mutating func reset() { current = nil }
}

/// Pelacak kecepatan sudut dari rangkaian orientasi bertimestamp.
///
/// Dipakai untuk menjawab "apakah pergelangan sedang diam?" — syarat sebelum
/// engine boleh mengunci objek. Tanpa ini, engine bisa mengklaim objek saat
/// lengan masih menyapu langit, yang justru menghasilkan false lock.
public struct AngularRateTracker: Equatable, Sendable {
    public private(set) var lastQuaternion: Quaternion?
    public private(set) var lastTimestamp: Date?
    /// Kecepatan sudut terakhir (derajat/detik), `nil` bila belum bisa dihitung.
    public private(set) var angularRateDegPerSec: Double?

    /// Jarak waktu maksimum antar sampel (detik). Di atas ini, sampel dianggap
    /// terputus (mis. sensor sempat berhenti) dan laju **tidak** dihitung —
    /// membagi dengan jeda panjang akan menghasilkan laju palsu yang kecil.
    public var maxGapSeconds: Double

    public init(maxGapSeconds: Double = 1.0) {
        self.maxGapSeconds = maxGapSeconds
    }

    /// Masukkan sampel baru; kembalikan laju terbaru bila bisa dihitung.
    @discardableResult
    public mutating func update(_ q: Quaternion, at timestamp: Date) -> Double? {
        defer {
            lastQuaternion = q
            lastTimestamp = timestamp
        }
        guard let prev = lastQuaternion, let prevTime = lastTimestamp,
              let prevUnit = prev.normalized, let currUnit = q.normalized else {
            angularRateDegPerSec = nil
            return nil
        }
        let dt = timestamp.timeIntervalSince(prevTime)
        guard dt > 0, dt <= maxGapSeconds else {
            angularRateDegPerSec = nil
            return nil
        }
        guard let angle = prevUnit.angleDegrees(to: currUnit) else {
            angularRateDegPerSec = nil
            return nil
        }
        let rate = angle / dt
        angularRateDegPerSec = rate
        return rate
    }

    public mutating func reset() {
        lastQuaternion = nil
        lastTimestamp = nil
        angularRateDegPerSec = nil
    }
}
