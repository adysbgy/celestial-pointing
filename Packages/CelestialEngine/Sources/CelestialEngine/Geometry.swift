import Foundation

/// Vektor 3D dalam ruang Euclid.
///
/// Sengaja tidak memakai `simd`: modul itu tidak tersedia di Linux dan akan
/// memaksa engine bergantung pada API Apple. Prinsip proyek ini adalah engine
/// harus bisa dibangun **dan diuji** tanpa Mac, jadi matematika vektor/rotasi
/// ditulis sendiri di sini.
public struct Vector3: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(x: 0, y: 0, z: 0)
    public static let unitX = Vector3(x: 1, y: 0, z: 0)
    public static let unitY = Vector3(x: 0, y: 1, z: 0)
    public static let unitZ = Vector3(x: 0, y: 0, z: 1)

    public var magnitudeSquared: Double { x * x + y * y + z * z }
    public var magnitude: Double { magnitudeSquared.squareRoot() }

    /// Apakah semua komponennya bilangan berhingga.
    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }

    /// Vektor satuan dengan arah yang sama. `nil` bila panjangnya nol atau
    /// tidak berhingga — arah tidak terdefinisi, dan menebak akan menyesatkan.
    public var normalized: Vector3? {
        let m = magnitude
        guard m.isFinite, m > 0 else { return nil }
        return Vector3(x: x / m, y: y / m, z: z / m)
    }

    public func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    public func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    public static func + (a: Vector3, b: Vector3) -> Vector3 {
        Vector3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)
    }

    public static func - (a: Vector3, b: Vector3) -> Vector3 {
        Vector3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)
    }

    public static func * (v: Vector3, s: Double) -> Vector3 {
        Vector3(x: v.x * s, y: v.y * s, z: v.z * s)
    }

    public static func * (s: Double, v: Vector3) -> Vector3 { v * s }

    public static prefix func - (v: Vector3) -> Vector3 {
        Vector3(x: -v.x, y: -v.y, z: -v.z)
    }

    /// Jarak sudut antara dua vektor (derajat). `nil` bila salah satunya nol.
    public func angleDegrees(to other: Vector3) -> Double? {
        guard let a = normalized, let b = other.normalized else { return nil }
        let c = max(-1.0, min(1.0, a.dot(b)))
        return SkyMath.rad2deg(acos(c))
    }
}

/// Matriks rotasi 3×3, tersimpan baris-demi-baris (row-major).
///
/// Penamaan `m11…m33` sengaja dibuat sama dengan `CMRotationMatrix` di
/// CoreMotion supaya lapisan app bisa memetakan hasil sensor tanpa berpikir
/// ulang soal indeks. Konvensi: `mRC` = baris R, kolom C.
public struct Matrix3x3: Equatable, Codable, Sendable {
    public var m11: Double, m12: Double, m13: Double
    public var m21: Double, m22: Double, m23: Double
    public var m31: Double, m32: Double, m33: Double

    public init(m11: Double, m12: Double, m13: Double,
                m21: Double, m22: Double, m23: Double,
                m31: Double, m32: Double, m33: Double) {
        self.m11 = m11; self.m12 = m12; self.m13 = m13
        self.m21 = m21; self.m22 = m22; self.m23 = m23
        self.m31 = m31; self.m32 = m32; self.m33 = m33
    }

    public static let identity = Matrix3x3(
        m11: 1, m12: 0, m13: 0,
        m21: 0, m22: 1, m23: 0,
        m31: 0, m32: 0, m33: 1
    )

    public var transpose: Matrix3x3 {
        Matrix3x3(m11: m11, m12: m21, m13: m31,
                  m21: m12, m22: m22, m23: m32,
                  m31: m13, m32: m23, m33: m33)
    }

    public var determinant: Double {
        m11 * (m22 * m33 - m23 * m32)
            - m12 * (m21 * m33 - m23 * m31)
            + m13 * (m21 * m32 - m22 * m31)
    }

    /// Perkalian matriks–matriks: `self * other` (rotasi `other` dulu, lalu `self`).
    public func multiplied(by other: Matrix3x3) -> Matrix3x3 {
        Matrix3x3(
            m11: m11 * other.m11 + m12 * other.m21 + m13 * other.m31,
            m12: m11 * other.m12 + m12 * other.m22 + m13 * other.m32,
            m13: m11 * other.m13 + m12 * other.m23 + m13 * other.m33,
            m21: m21 * other.m11 + m22 * other.m21 + m23 * other.m31,
            m22: m21 * other.m12 + m22 * other.m22 + m23 * other.m32,
            m23: m21 * other.m13 + m22 * other.m23 + m23 * other.m33,
            m31: m31 * other.m11 + m32 * other.m21 + m33 * other.m31,
            m32: m31 * other.m12 + m32 * other.m22 + m33 * other.m32,
            m33: m31 * other.m13 + m32 * other.m23 + m33 * other.m33
        )
    }

    public func multiplied(by v: Vector3) -> Vector3 {
        Vector3(
            x: m11 * v.x + m12 * v.y + m13 * v.z,
            y: m21 * v.x + m22 * v.y + m23 * v.z,
            z: m31 * v.x + m32 * v.y + m33 * v.z
        )
    }

    /// Apakah matriks ini rotasi murni (ortonormal, determinan +1) dalam
    /// toleransi tertentu. Dipakai untuk memvalidasi hasil konversi dari
    /// quaternion atau dari sensor.
    public func isRotation(tolerance: Double = 1e-9) -> Bool {
        let r = multiplied(by: transpose)
        let close = { (a: Double, b: Double) in abs(a - b) <= tolerance }
        return close(r.m11, 1) && close(r.m22, 1) && close(r.m33, 1)
            && close(r.m12, 0) && close(r.m13, 0)
            && close(r.m21, 0) && close(r.m23, 0)
            && close(r.m31, 0) && close(r.m32, 0)
            && close(determinant, 1)
    }
}
