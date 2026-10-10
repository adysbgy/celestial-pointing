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

/// Kerangka acuan attitude CoreMotion (`CMAttitudeReferenceFrame`), ditulis
/// ulang di sini supaya engine bisa diuji di Linux tanpa CoreMotion.
///
/// Definisi Apple untuk keempatnya sama di dua hal: sumbu-Z **vertikal ke
/// atas** (sejajar melawan gravitasi), dan kerangkanya tangan kanan. Yang
/// berbeda hanya arti sumbu-X di bidang horizontal:
///
/// | kasus | sumbu-X |
/// |---|---|
/// | `xArbitraryZVertical` | horizontal sembarang (tetap selama sesi) |
/// | `xArbitraryCorrectedZVertical` | sama, tapi drift yaw dikoreksi magnetometer |
/// | `xMagneticNorthZVertical` | Utara magnetis |
/// | `xTrueNorthZVertical` | Utara sebenarnya (butuh lokasi) |
///
/// Karena X = Utara dan Z = Atas, tangan kanan memaksa Y = Z × X = **Barat**.
/// Lihat Docs/DECISIONS.md ADR-002.
public enum AttitudeReferenceFrame: String, CaseIterable, Codable, Equatable, Sendable {
    case xArbitraryZVertical
    case xArbitraryCorrectedZVertical
    case xMagneticNorthZVertical
    case xTrueNorthZVertical

    /// Apakah azimut dari kerangka ini bermakna tanpa kalibrasi yaw.
    public var hasAbsoluteHeading: Bool {
        switch self {
        case .xArbitraryZVertical, .xArbitraryCorrectedZVertical: return false
        case .xMagneticNorthZVertical, .xTrueNorthZVertical: return true
        }
    }

    /// Kerangka acuan -> ENU. Sama untuk keempat kasus: (E, N, U) = (−Y, X, Z).
    ///
    /// Untuk kerangka sembarang, "Utara" di sini berarti sumbu-X sembarang;
    /// kalibrasi yaw yang memberinya arti sebenarnya.
    public static let referenceToENU = Matrix3x3(
        m11: 0, m12: -1, m13: 0,
        m21: 1, m22: 0, m23: 0,
        m31: 0, m32: 0, m33: 1
    )
}

/// Sumbu badan perangkat yang bisa dijadikan "arah tunjuk".
///
/// Kerangka perangkat CoreMotion: `+X` ke kanan layar, `+Y` ke atas layar,
/// `+Z` keluar dari layar. Pada Apple Watch yang dipakai di pergelangan kiri
/// dengan Digital Crown di kanan (bawaan watchOS), `+X` mengarah ke mahkota,
/// yaitu ke arah tangan; sumbu lengan bawah (yang paling dekat dengan arah
/// telunjuk) adalah ±X. Tandanya **hipotesis**: belum diketahui apakah
/// watchOS membalik kerangka sensor saat pengaturan mahkota diubah, jadi
/// sumbu yang dipakai harus bisa dipilih dari data (`AxisSelection`).
///
/// `Codable`: `PointingTrial` menyimpan sumbu yang berlaku saat rekam, sebab
/// arti `rawPointing` bergantung padanya.
public enum DeviceAimAxis: String, CaseIterable, Codable, Equatable, Sendable {
    /// +Z, keluar dari layar (normal permukaan jam). Dipertahankan sebagai
    /// opsi eksperimen; bukan arah tunjuk alami.
    case view
    /// +Y, ke atas layar (arah jam 12).
    case screenUp
    /// +X, ke kanan layar (arah jam 3, mahkota pada pemakaian bawaan).
    case screenRight
    /// −X, ke kiri layar (arah jam 9).
    case screenLeft
    /// −Y, ke bawah layar (arah jam 6).
    case screenDown

    /// Vektor arah dalam kerangka perangkat.
    public var vector: Vector3 {
        switch self {
        case .view: return Vector3(x: 0, y: 0, z: 1)
        case .screenUp: return Vector3(x: 0, y: 1, z: 0)
        case .screenRight: return Vector3(x: 1, y: 0, z: 0)
        case .screenLeft: return Vector3(x: -1, y: 0, z: 0)
        case .screenDown: return Vector3(x: 0, y: -1, z: 0)
        }
    }

    /// Sumbu bawaan untuk menunjuk dengan jam: lengan bawah pada pemakaian
    /// bawaan watchOS (kiri, mahkota kanan).
    public static let defaultForearm: DeviceAimAxis = .screenRight

    /// Kandidat yang dibandingkan saat memilih sumbu dari data.
    public static let selectionCandidates: [DeviceAimAxis] =
        [.screenRight, .screenLeft, .screenUp, .screenDown, .view]
}

/// Cara jam dipakai, dari `WKInterfaceDevice.wristLocation` dan
/// `crownOrientation`. Engine tidak mengimpor WatchKit, jadi dicerminkan di
/// sini.
public struct WearConfiguration: Equatable, Codable, Sendable {
    public enum Side: String, Codable, Equatable, Sendable { case left, right }

    public var wrist: Side
    public var crown: Side

    public init(wrist: Side, crown: Side) {
        self.wrist = wrist
        self.crown = crown
    }

    /// Pemakaian bawaan watchOS.
    public static let `default` = WearConfiguration(wrist: .left, crown: .right)

    /// Sumbu lengan bawah **dugaan** di kerangka perangkat keras.
    ///
    /// Kiri+mahkota kanan dan kanan+mahkota kiri: mahkota menghadap tangan,
    /// jadi +X. Dua kombinasi lainnya membalik jam 180° di pergelangan, jadi −X.
    /// Ini mengasumsikan kerangka sensor ikut perangkat keras, bukan ikut
    /// orientasi layar — belum diverifikasi di perangkat.
    public var forearmAim: DeviceAimAxis {
        (wrist == .left) == (crown == .right) ? .screenRight : .screenLeft
    }
}

/// Attitude perangkat dalam satu kerangka acuan CoreMotion yang **eksplisit**.
///
/// Konvensi (ADR-002): `quaternion` adalah `CMAttitude.quaternion`, dan
/// matriks rotasi aktifnya membawa vektor perangkat ke kerangka acuan:
/// `v_ref = R(q) · v_device`. Bukti tidak langsung yang bisa diperiksa di
/// perangkat: gravitasi di kerangka perangkat harus sama dengan
/// `−R(q)ᵀ · ẑ` (`predictedGravity`), dan `PointingTrial` merekam keduanya.
public struct DeviceAttitude: Equatable, Codable, Sendable {
    public var quaternion: Quaternion
    public var frame: AttitudeReferenceFrame

    public init(quaternion: Quaternion,
                frame: AttitudeReferenceFrame = .xArbitraryZVertical) {
        self.quaternion = quaternion
        self.frame = frame
    }

    /// Dari komponen `CMQuaternion` (urutan x, y, z, w).
    public init?(cmX: Double, cmY: Double, cmZ: Double, cmW: Double,
                frame: AttitudeReferenceFrame = .xArbitraryZVertical) {
        guard let q = Quaternion(cmX: cmX, cmY: cmY, cmZ: cmZ, cmW: cmW).normalized
        else { return nil }
        self.init(quaternion: q, frame: frame)
    }

    /// Attitude identitas: perangkat sejajar kerangka acuan, yaitu **terbaring
    /// mendatar, layar menghadap ke atas**.
    public static let identity = DeviceAttitude(quaternion: .identity)

    /// Matriks rotasi perangkat -> ENU: `M(ref→ENU) · R(q)`.
    public var deviceToWorld: Matrix3x3? {
        guard let q = quaternion.normalized else { return nil }
        return AttitudeReferenceFrame.referenceToENU.multiplied(by: q.rotationMatrix)
    }

    /// Arah tunjuk dalam ENU untuk sumbu badan tertentu. `nil` bila quaternion
    /// tidak sah.
    public func pointingVector(aim: DeviceAimAxis) -> Vector3? {
        pointingVector(deviceAim: aim.vector)
    }

    /// Arah tunjuk untuk vektor badan sembarang.
    public func pointingVector(deviceAim: Vector3) -> Vector3? {
        guard let r = deviceToWorld else { return nil }
        return r.multiplied(by: deviceAim).normalized
    }

    /// Arah tunjuk sebagai horizontal (alt-az). `nil` bila tidak terdefinisi.
    ///
    /// Pada kerangka sembarang, azimutnya relatif terhadap sumbu-X sembarang
    /// dan baru bermakna setelah kalibrasi yaw; altitude-nya absolut.
    public func horizontalPointing(aim: DeviceAimAxis) -> HorizontalCoord? {
        guard let v = pointingVector(aim: aim) else { return nil }
        return LocalFrame.horizontalFromENU(v)
    }

    /// Gravitasi yang **diramalkan** di kerangka perangkat (satuan g):
    /// `−R(q)ᵀ · ẑ`. Dibandingkan dengan `CMDeviceMotion.gravity` untuk
    /// memeriksa konvensi di perangkat nyata.
    public var predictedGravity: Vector3? {
        guard let q = quaternion.normalized else { return nil }
        return -(q.rotationMatrix.transpose.multiplied(by: .unitZ))
    }

    /// Sudut antara gravitasi terukur dan ramalan konvensi ini (derajat).
    /// Mendekati 0° bila konvensinya benar; `nil` bila salah satu vektor nol.
    public func gravityMismatchDeg(measured: Vector3) -> Double? {
        guard let predicted = predictedGravity else { return nil }
        return predicted.angleDegrees(to: measured)
    }

    /// Attitude sintetis yang membuat sumbu `aim` menunjuk ke `target`.
    ///
    /// Untuk uji dan replay: memakai rotasi busur terpendek, jadi roll di
    /// sekitar sumbu tunjuk tidak ditentukan (dan memang tidak memengaruhi
    /// arah tunjuk).
    public static func synthetic(aim: DeviceAimAxis,
                                 pointingAt target: HorizontalCoord,
                                 frame: AttitudeReferenceFrame = .xArbitraryZVertical)
        -> DeviceAttitude {
        let enu = LocalFrame.enuFromHorizontal(target)
        let ref = AttitudeReferenceFrame.referenceToENU.transpose.multiplied(by: enu)
        return DeviceAttitude(quaternion: Quaternion.shortestArc(from: aim.vector, to: ref),
                              frame: frame)
    }
}

public extension Quaternion {
    /// Rotasi busur terpendek yang membawa `from` ke `to` (keduanya
    /// dinormalkan). Untuk vektor berlawanan, diputar 180° mengelilingi sumbu
    /// tegak lurus mana pun.
    static func shortestArc(from: Vector3, to: Vector3) -> Quaternion {
        guard let a = from.normalized, let b = to.normalized else { return .identity }
        let d = a.dot(b)
        if d > 1 - 1e-12 { return .identity }
        if d < -1 + 1e-12 {
            let helper = abs(a.x) < 0.9 ? Vector3.unitX : Vector3.unitY
            let axis = a.cross(helper)
            return Quaternion.axisAngle(axis: axis, radians: .pi) ?? .identity
        }
        let axis = a.cross(b)
        return Quaternion.axisAngle(axis: axis, radians: acos(max(-1, min(1, d)))) ?? .identity
    }
}
