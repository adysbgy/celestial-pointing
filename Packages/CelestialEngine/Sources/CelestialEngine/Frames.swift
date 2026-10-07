import Foundation

/// Kerangka lokal pengamat: East–North–Up (ENU), tangan kanan.
///
/// - `+X` = Timur (East)
/// - `+Y` = Utara (North)
/// - `+Z` = Atas (Up / zenith)
///
/// Ini adalah kerangka "dunia" yang dipakai untuk mengubah attitude perangkat
/// menjadi arah di langit. Pemetaan ini dipisahkan dari `HorizontalCoord` agar
/// konversinya bisa diuji sendirian, tanpa sensor apa pun.
public enum LocalFrame {

    /// Horizontal (alt-az) -> vektor satuan ENU.
    ///
    /// Azimut diukur dari Utara ke arah Timur (0° = Utara, 90° = Timur),
    /// sesuai konvensi `SkyMath.equatorialToHorizontal`.
    public static func enuFromHorizontal(_ h: HorizontalCoord) -> Vector3 {
        let alt = SkyMath.deg2rad(h.altitudeDeg)
        let az = SkyMath.deg2rad(h.azimuthDeg)
        let cosAlt = cos(alt)
        return Vector3(
            x: cosAlt * sin(az),   // East
            y: cosAlt * cos(az),   // North
            z: sin(alt)            // Up
        )
    }

    /// Vektor ENU -> horizontal (alt-az). `nil` bila vektornya nol/tidak sah.
    public static func horizontalFromENU(_ v: Vector3) -> HorizontalCoord? {
        guard let n = v.normalized else { return nil }
        let altitude = SkyMath.rad2deg(asin(max(-1.0, min(1.0, n.z))))
        let azimuth = SkyMath.normalizeDeg(SkyMath.rad2deg(atan2(n.x, n.y)))
        return HorizontalCoord(altitudeDeg: altitude, azimuthDeg: azimuth)
    }
}

/// Sumbu badan perangkat yang bisa dijadikan "arah tunjuk".
///
/// Perangkat (Apple Watch / iPhone dalam orientasi potret) memakai kerangka:
/// `+X` ke kanan layar, `+Y` ke atas layar, `+Z` keluar dari layar.
/// Sumbu mana yang dianggap "arah tunjuk" adalah keputusan UX — karena itu
/// diserahkan sebagai parameter, bukan dipatri di dalam matematika.
///
/// `Codable` sejak bidang Lampiran A: `PointingTrial` menyimpan sumbu yang
/// berlaku saat rekam, sebab arti `rawPointing` bergantung padanya — rekaman
/// yang tidak menyebut sumbunya tidak bisa ditafsirkan ulang dengan benar.
public enum DeviceAimAxis: String, CaseIterable, Codable, Equatable, Sendable {
    /// Keluar dari layar (normal permukaan jam).
    case view
    /// Ke atas layar (menuju punggung tangan saat lengan dijulurkan).
    case screenUp
    /// Ke kanan layar (menuju tangan).
    case screenRight

    /// Vektor arah dalam kerangka perangkat.
    public var vector: Vector3 {
        switch self {
        case .view: return Vector3(x: 0, y: 0, z: 1)
        case .screenUp: return Vector3(x: 0, y: 1, z: 0)
        case .screenRight: return Vector3(x: 1, y: 0, z: 0)
        }
    }
}

/// Attitude perangkat beserta koreksi roll, siap diubah menjadi arah langit.
///
/// `quaternion` adalah orientasi perangkat terhadap kerangka acuan CoreMotion
/// (mis. `xArbitraryZVertical`). `rollAboutViewDeg` adalah sudut roll yang
/// diselesaikan lewat kalibrasi: putaran mengelilingi sumbu pandang yang
/// menyelaraskan arah tunjuk horizontal dengan Utara sebenarnya.
///
/// Kenapa quaternion disimpan, bukan langsung matriks: konversi ke matriks
/// kehilangan presisi dan sulit dibalik saat kalibrasi. Quaternion bisa
/// dinormalkan dan dikomposisi berulang tanpa akumulasi galat.
public struct DeviceAttitude: Equatable, Codable, Sendable {
    public var quaternion: Quaternion
    public var rollAboutViewDeg: Double

    public init(quaternion: Quaternion, rollAboutViewDeg: Double = 0) {
        self.quaternion = quaternion
        self.rollAboutViewDeg = rollAboutViewDeg
    }

    /// Dari komponen `CMQuaternion` (urutan x, y, z, w).
    public init?(cmX: Double, cmY: Double, cmZ: Double, cmW: Double,
                rollAboutViewDeg: Double = 0) {
        let q = Quaternion(cmX: cmX, cmY: cmY, cmZ: cmZ, cmW: cmW).normalized
        guard let q else { return nil }
        self.init(quaternion: q, rollAboutViewDeg: rollAboutViewDeg)
    }

    /// Attitude identitas (perangkat sejajar kerangka acuan).
    public static let identity = DeviceAttitude(quaternion: .identity)

    /// Matriks rotasi perangkat -> ENU.
    ///
    /// Kerangka perangkat dipetakan dengan `rollAboutViewDeg = 0` sebagai:
    /// - `+Z` (keluar layar) -> Timur
    /// - `+Y` (atas layar)   -> Zenith
    /// - `+X` (kanan layar)  -> Utara
    ///
    /// `rollAboutViewDeg` lalu memutar mengelilingi sumbu pandang. Roll positif
    /// memutar "atas layar" menjauhi Utara (ke arah Selatan). Perhatikan bahwa
    /// roll **tidak** mengubah arah pandang keluar-layar selama sumbu pandang
    /// mendatar — itulah sebabnya kalibrasi yaw tetap diperlukan.
    public var deviceToWorld: Matrix3x3? {
        guard let q = quaternion.normalized else { return nil }
        let roll = SkyMath.deg2rad(rollAboutViewDeg)
        let c = cos(roll), s = sin(roll)
        // Kolom = citra sumbu perangkat (x, y, z) di ENU.
        let rollMatrix = Matrix3x3(
            m11: 0, m12: 0, m13: 1,
            m21: c, m22: -s, m23: 0,
            m31: s, m32: c, m33: 0
        )
        return rollMatrix.multiplied(by: q.rotationMatrix)
    }

    /// Arah tunjuk dalam ENU untuk sumbu badan tertentu.
    ///
    /// `nil` bila quaternion tidak sah.
    public func pointingVector(aim: DeviceAimAxis) -> Vector3? {
        pointingVector(deviceAim: aim.vector)
    }

    /// Arah tunjuk untuk vektor badan sembarang (mis. hasil rata-rata sensor).
    public func pointingVector(deviceAim: Vector3) -> Vector3? {
        guard let r = deviceToWorld else { return nil }
        return r.multiplied(by: deviceAim).normalized
    }

    /// Arah tunjuk sebagai horizontal (alt-az). `nil` bila tidak terdefinisi.
    public func horizontalPointing(aim: DeviceAimAxis) -> HorizontalCoord? {
        guard let v = pointingVector(aim: aim) else { return nil }
        return LocalFrame.horizontalFromENU(v)
    }
}
