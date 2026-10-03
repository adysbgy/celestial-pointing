import Foundation

/// Quaternion satuan untuk rotasi 3D. Konvensi `(w, x, y, z)`.
///
/// Dipakai karena `CMAttitude` menyediakan quaternion, dan quaternion adalah
/// representasi yang paling aman untuk integrasi gyroscope (tanpa gimbal lock).
/// Kita tidak memakai tipe apa pun dari CoreMotion di sini agar engine tetap
/// bisa diuji di Linux.
public struct Quaternion: Equatable, Codable, Sendable {
    /// Komponen skalar.
    public var w: Double
    /// Komponen vektor.
    public var x: Double
    public var y: Double
    public var z: Double

    public init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w; self.x = x; self.y = y; self.z = z
    }

    public static let identity = Quaternion(w: 1, x: 0, y: 0, z: 0)

    /// Quaternion dari `CMQuaternion` (urutan x, y, z, w) — dipetakan di sini
    /// supaya lapisan app tidak perlu mengingat perbedaan urutan komponen.
    public init(cmX: Double, cmY: Double, cmZ: Double, cmW: Double) {
        self.init(w: cmW, x: cmX, y: cmY, z: cmZ)
    }

    public var magnitudeSquared: Double { w * w + x * x + y * y + z * z }
    public var magnitude: Double { magnitudeSquared.squareRoot() }

    /// Quaternion satuan; `nil` bila panjangnya nol/tidak berhingga.
    public var normalized: Quaternion? {
        let m = magnitude
        guard m.isFinite, m > 0 else { return nil }
        return Quaternion(w: w / m, x: x / m, y: y / m, z: z / m)
    }

    /// Konjugat. Untuk quaternion satuan, ini sekaligus inversnya.
    public var conjugate: Quaternion {
        Quaternion(w: w, x: -x, y: -y, z: -z)
    }

    public func multiplied(by other: Quaternion) -> Quaternion {
        Quaternion(
            w: w * other.w - x * other.x - y * other.y - z * other.z,
            x: w * other.x + x * other.w + y * other.z - z * other.y,
            y: w * other.y - x * other.z + y * other.w + z * other.x,
            z: w * other.z + x * other.y - y * other.x + z * other.w
        )
    }

    public func dot(_ other: Quaternion) -> Double {
        w * other.w + x * other.x + y * other.y + z * other.z
    }

    /// Sudut rotasi terpendek antara dua orientasi (derajat).
    ///
    /// Dua quaternion `q` dan `-q` mewakili orientasi yang sama, jadi dipakai
    /// nilai absolut hasil dot. `nil` bila salah satunya tidak sah.
    public func angleDegrees(to other: Quaternion) -> Double? {
        guard let a = normalized, let b = other.normalized else { return nil }
        let d = abs(max(-1.0, min(1.0, a.dot(b))))
        return SkyMath.rad2deg(2 * acos(d))
    }

    /// Interpolasi linear ternormalisasi (nlerp) menuju `other`.
    ///
    /// `t` dijepit ke 0…1. Menangani *double cover*: kalau dot negatif, `other`
    /// dinegasikan dulu supaya interpolasi menempuh busur terpendek, bukan
    /// memutar hampir 360°. Cukup untuk smoothing sensor; presisi kecepatan
    /// sudut seragam (slerp) tidak dibutuhkan di sini.
    public func interpolated(to other: Quaternion, t: Double) -> Quaternion? {
        guard let a = normalized, other.normalized != nil else { return nil }
        let target = a.dot(other) < 0
            ? Quaternion(w: -other.w, x: -other.x, y: -other.y, z: -other.z)
            : other
        guard let b = target.normalized else { return nil }
        let tt = max(0.0, min(1.0, t))
        return Quaternion(
            w: a.w + (b.w - a.w) * tt,
            x: a.x + (b.x - a.x) * tt,
            y: a.y + (b.y - a.y) * tt,
            z: a.z + (b.z - a.z) * tt
        ).normalized
    }

    /// Quaternion dari sudut (radian) dan sumbu rotasi.
    public static func axisAngle(axis: Vector3, radians: Double) -> Quaternion? {
        guard let n = axis.normalized else { return nil }
        let half = radians / 2
        let s = sin(half)
        return Quaternion(w: cos(half), x: n.x * s, y: n.y * s, z: n.z * s)
    }

    /// Matriks rotasi aktif: `v_world = R * v_local`.
    ///
    /// Rumus standar untuk quaternion satuan. Diasumsikan sudah dinormalkan
    /// (mis. lewat `normalized`); bila belum, hasilnya bukan rotasi murni.
    public var rotationMatrix: Matrix3x3 {
        let xx = x * x, yy = y * y, zz = z * z
        let xy = x * y, xz = x * z, yz = y * z
        let wx = w * x, wy = w * y, wz = w * z
        return Matrix3x3(
            m11: 1 - 2 * (yy + zz), m12: 2 * (xy - wz),     m13: 2 * (xz + wy),
            m21: 2 * (xy + wz),     m22: 1 - 2 * (xx + zz), m23: 2 * (yz - wx),
            m31: 2 * (xz - wy),     m32: 2 * (yz + wx),     m33: 1 - 2 * (xx + yy)
        )
    }

    /// Rotasi vektor oleh quaternion ini (rotasi aktif).
    public func rotated(_ v: Vector3) -> Vector3 {
        // v' = v + 2w(q_v × v) + 2 q_v × (q_v × v)
        let qv = Vector3(x: x, y: y, z: z)
        let t = qv.cross(v) * 2.0
        return v + t * w + qv.cross(t)
    }
}
