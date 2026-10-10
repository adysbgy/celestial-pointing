import Foundation
import CelestialEngine

/// Geometri tampilan 3D di iPhone (ADR-017, Docs/PRODUCT_V2_IDEA.md §5).
///
/// **Prinsip: gambarnya tidak boleh berbohong.** Arah cahaya, fase, kemiringan
/// cincin, dan jarak antar-benda pada konjungsi semuanya dihitung dari
/// efemeris yang sama dengan engine — bukan dipilih supaya "bagus".
///
/// Kerangka kamera mengikuti RealityKit: kamera di +z memandang ke −z (ke
/// benda di titik asal), kanan = +x, atas = +y. "Atas" adalah arah Utara
/// langit yang diproyeksikan, jadi Timur tampak di **kiri** — persis seperti
/// memandang langit (dan seperti di teleskop tanpa diagonal).
public enum Scene3D {

    /// Vektor satuan ekuatorial dari RA/Dec (derajat).
    public static func unit(_ eq: EquatorialCoord) -> Vector3 {
        let a = eq.raDeg * .pi / 180, d = eq.decDeg * .pi / 180
        return Vector3(x: cos(d) * cos(a), y: cos(d) * sin(a), z: sin(d))
    }

    /// Basis kamera untuk memandang arah `forward` (satuan, ekuatorial).
    public struct Basis: Equatable, Sendable {
        public let right: Vector3
        public let up: Vector3
        public let forward: Vector3

        /// Vektor ekuatorial → ruang kamera RealityKit.
        public func toCamera(_ v: Vector3) -> Vector3 {
            Vector3(x: v.dot(right), y: v.dot(up), z: -v.dot(forward))
        }
    }

    public static func basis(lookingAt forward: Vector3) -> Basis {
        let f = forward.normalized ?? .unitX
        let north = Vector3.unitZ
        // Di dekat kutub langit, Utara terproyeksi tidak terdefinisi: pakai RA 0.
        let up = (north - f * north.dot(f)).normalized ?? (Vector3.unitX - f * Vector3.unitX.dot(f)).normalized ?? .unitY
        return Basis(right: f.cross(up), up: up, forward: f)
    }

    /// Sudut fase (derajat, 0 = purnama) dari fraksi iluminasi k:
    /// k = (1 + cos i) / 2.
    public static func phaseAngleDeg(illumination k: Double) -> Double {
        acos(min(1, max(-1, 2 * k - 1))) * 180 / .pi
    }

    /// Arah **dari benda ke Matahari**, di ruang kamera.
    ///
    /// Komponen menuju kamera = cos(i); sisanya mengarah ke Matahari pada
    /// bidang langit (proyeksi arah Matahari tegak lurus garis pandang). Jadi
    /// fase **dan** orientasi terminator benar.
    public static func lightDirection(object: EquatorialCoord, sun: EquatorialCoord,
                                      illumination k: Double) -> Vector3 {
        let o = unit(object), s = unit(sun)
        let b = basis(lookingAt: o)
        let i = phaseAngleDeg(illumination: k) * .pi / 180
        let p = (s - o * s.dot(o)).normalized.map { b.toCamera($0) } ?? .unitX
        return Vector3(x: sin(i) * p.x, y: sin(i) * p.y, z: cos(i))
    }

    /// Kutub utara Saturnus (IAU, J2000).
    public static let saturnPole = EquatorialCoord(raDeg: 40.589, decDeg: 83.537)

    /// Kutub sebuah planet di ruang kamera saat memandangnya.
    public static func poleInCamera(pole: EquatorialCoord, object: EquatorialCoord) -> Vector3 {
        basis(lookingAt: unit(object)).toCamera(unit(pole))
    }

    /// Kemiringan cincin terhadap garis pandang (lintang sub-Bumi B, derajat).
    /// 0 = cincin tegak/tipis (dilihat dari tepi), ±27° = paling terbuka.
    public static func ringOpeningDeg(saturn: EquatorialCoord) -> Double {
        let sinB = -unit(saturnPole).dot(unit(saturn))
        return asin(min(1, max(-1, sinB))) * 180 / .pi
    }

    /// Letak dua benda konjungsi pada bidang singgung di titik tengahnya
    /// (proyeksi gnomonik), dalam derajat: x ke kanan (Barat), y ke atas
    /// (Utara). Jaraknya sama dengan jarak sudut sebenarnya (untuk sudut kecil).
    public static func conjunctionLayout(_ a: EquatorialCoord, _ b: EquatorialCoord)
        -> (a: (x: Double, y: Double), b: (x: Double, y: Double)) {
        let va = unit(a), vb = unit(b)
        let mid = (va + vb).normalized ?? va
        let basis = basis(lookingAt: mid)
        func project(_ v: Vector3) -> (x: Double, y: Double) {
            let d = max(1e-9, v.dot(mid))
            return (atan(v.dot(basis.right) / d) * 180 / .pi, atan(v.dot(basis.up) / d) * 180 / .pi)
        }
        return (project(va), project(vb))
    }

    // MARK: Tekstur terpanggang

    /// Gambar RGBA 8-bit (tanpa CoreGraphics, supaya teruji di Linux).
    public struct RGBAImage: Equatable, Sendable {
        public let width: Int
        public let height: Int
        public var pixels: [UInt8]

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
            pixels = [UInt8](repeating: 0, count: width * height * 4)
        }

        public func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            let i = (y * width + x) * 4
            return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
        }

        mutating func set(_ x: Int, _ y: Int, _ c: CelestialVisual.RGBComponents, alpha: Double = 1) {
            let i = (y * width + x) * 4
            pixels[i] = UInt8(max(0, min(255, (c.red * 255).rounded())))
            pixels[i + 1] = UInt8(max(0, min(255, (c.green * 255).rounded())))
            pixels[i + 2] = UInt8(max(0, min(255, (c.blue * 255).rounded())))
            pixels[i + 3] = UInt8(max(0, min(255, (alpha * 255).rounded())))
        }
    }

    /// Normal permukaan bola untuk koordinat tekstur (u, v) di ruang model.
    ///
    /// Mengikuti pemetaan UV `MeshResource.generateSphere` RealityKit:
    /// v = 0 di kutub +y, u berputar mengelilingi sumbu y. Konvensi u
    /// (titik awal dan arah putar) diverifikasi dari tangkapan layar uji
    /// (ADR-017), jadi disimpan sebagai konstanta di satu tempat.
    public static func sphereNormal(u: Double, v: Double) -> Vector3 {
        let lat = (0.5 - v) * .pi
        let lon = u * 2 * .pi + uvLongitudeOffset
        return Vector3(x: cos(lat) * sin(lon) * uvLongitudeSign, y: sin(lat), z: cos(lat) * cos(lon))
    }

    /// Konvensi u RealityKit (lihat `sphereNormal`).
    ///
    /// **Diukur, bukan ditebak** (simulator iPhone 17, iOS 26.5, 10 Okt 2026)
    /// dengan tekstur kalibrasi empat warna per seperempat u: yang menghadap
    /// kamera (+z) adalah u = 0.75, tepi kanan (+x) u = 0 (= 1), dan v = 0 di
    /// atas (+y). Jadi n = (cos θ, ·, −sin θ) dengan θ = 2πu — rumus di atas
    /// dengan pergeseran bujur +90° dan tanda +1. Tebakan awal (tanpa
    /// pergeseran) menggambar sabit Venus 7% di sisi yang salah.
    public static let uvLongitudeOffset: Double = .pi / 2
    public static let uvLongitudeSign: Double = 1

    /// Tekstur bola dengan **cahaya terpanggang**: albedo × max(0, n·L) +
    /// cahaya sekitar kecil. Karena kamera yang mengorbit (bendanya diam),
    /// cahaya terpanggang tetap benar di ruang dunia.
    public static func bakedSphere(width: Int = 512, height: Int = 256,
                                   light: Vector3, ambient: Double = 0.035,
                                   albedo: (Vector3) -> CelestialVisual.RGBComponents) -> RGBAImage {
        var image = RGBAImage(width: width, height: height)
        let l = light.normalized ?? .unitZ
        for y in 0..<height {
            for x in 0..<width {
                let n = sphereNormal(u: (Double(x) + 0.5) / Double(width), v: (Double(y) + 0.5) / Double(height))
                // Pangkat 0.6: sabit tipis tetap terlihat di layar, tanpa
                // menggeser terminator (tetap di n·L = 0).
                let shade = ambient + (1 - ambient) * pow(max(0, n.dot(l)), 0.6)
                let a = albedo(n)
                image.set(x, y, .init(red: a.red * shade, green: a.green * shade, blue: a.blue * shade))
            }
        }
        return image
    }

    /// Albedo pita Jupiter / Saturnus: pita sejajar ekuator planet (bukan
    /// ekuator layar), memakai lintang terhadap kutub planet.
    public static func bandedAlbedo(pole: Vector3, bands: [CelestialVisual.RGBComponents])
        -> (Vector3) -> CelestialVisual.RGBComponents {
        let p = pole.normalized ?? .unitY
        return { n in
            guard !bands.isEmpty else { return .init(red: 0.5, green: 0.5, blue: 0.5) }
            let lat = asin(min(1, max(-1, n.dot(p))))      // −π/2…π/2
            let t = (lat / .pi + 0.5) * Double(bands.count * 2)
            return bands[Int(t) % bands.count]
        }
    }

    /// Tekstur cincin Saturnus untuk bidang persegi: transparan di luar
    /// cincin dan di celah tengah (planet), pita gelap-terang di antaranya.
    /// Jari-jari dalam/luar relatif terhadap tepi bidang (luar = 1).
    public static func ringTexture(size: Int = 256, color: CelestialVisual.RGBComponents,
                                   brightness: Double, inner: Double = 1.24 / 2.27) -> RGBAImage {
        var image = RGBAImage(width: size, height: size)
        for y in 0..<size {
            for x in 0..<size {
                let dx = (Double(x) + 0.5) / Double(size) * 2 - 1
                let dy = (Double(y) + 0.5) / Double(size) * 2 - 1
                let r = (dx * dx + dy * dy).squareRoot()
                guard r >= inner, r <= 1 else { continue }
                let t = (r - inner) / (1 - inner)
                // Celah Cassini kira-kira di 0.62 lebar cincin.
                let gap = abs(t - 0.62) < 0.035 ? 0.15 : 1.0
                let band = 0.75 + 0.25 * sin(t * 38)
                let k = brightness * band * gap
                image.set(x, y, .init(red: color.red * k, green: color.green * k, blue: color.blue * k),
                          alpha: 0.85 * gap)
            }
        }
        return image
    }
}

// MARK: - Spesifikasi adegan

/// Satu benda yang siap digambar 3D (ADR-017).
public struct Object3DSpec: Sendable {
    public enum Body: Sendable {
        /// Bola bertekstur dengan cahaya terpanggang; cincin opsional.
        case sphere(texture: Scene3D.RGBAImage, ring: Scene3D.RGBAImage?, ringNormal: Vector3?)
        /// Bintang: titik bercahaya berwarna sesuai indeks warnanya.
        case star(color: CelestialVisual.RGBComponents)
    }

    public let objectID: String
    public let name: String
    public let kind: ObjectKind
    public let body: Body
    /// Arah dari benda ke Matahari di ruang kamera (`nil` untuk bintang).
    public let lightDirection: Vector3?
    /// Persen piringan yang tersinari (`nil` untuk bintang).
    public let illuminationPercent: Int?
    /// Kemiringan cincin (Saturnus), derajat.
    public let ringOpeningDeg: Double?

    public init(objectID: String, name: String, kind: ObjectKind, body: Body, lightDirection: Vector3?,
                illuminationPercent: Int?, ringOpeningDeg: Double?) {
        self.objectID = objectID
        self.name = name
        self.kind = kind
        self.body = body
        self.lightDirection = lightDirection
        self.illuminationPercent = illuminationPercent
        self.ringOpeningDeg = ringOpeningDeg
    }
}

public extension Scene3D {

    /// Kutub utara planet (IAU, J2000). Lainnya: kutub langit (cukup untuk bola polos).
    static func pole(forObjectID id: String) -> EquatorialCoord {
        switch id {
        case "jupiter": return EquatorialCoord(raDeg: 268.057, decDeg: 64.495)
        case "saturn": return saturnPole
        default: return EquatorialCoord(raDeg: 0, decDeg: 90)
        }
    }

    /// Spesifikasi 3D untuk sebuah id katalog pada waktu tertentu.
    ///
    /// - Parameter umbraTint: 0…1 — Bulan saat gerhana diwarnai tembaga
    ///   sesuai seberapa dalam ia masuk bayangan Bumi.
    static func spec(forObjectID id: String, observer: Observer, date: Date,
                     resolver: PointingResolver, umbraTint: Double = 0) -> Object3DSpec? {
        guard let object = resolver.object(forID: id, observer: observer, date: date) else { return nil }
        switch object.kind {
        case .star:
            let color = CelestialVisual.starRGB(forColorIndex: CelestialVisual.colorIndex(forStarID: id))
            return Object3DSpec(objectID: id, name: object.name, kind: .star, body: .star(color: color),
                                lightDirection: nil, illuminationPercent: nil, ringOpeningDeg: nil)
        case .moon, .planet:
            guard let ephemeris = resolver.ephemeris, let body = EphemerisBody(rawValue: id),
                  let sample = try? ephemeris.apparent(body, at: date, from: observer),
                  let sun = try? ephemeris.apparent(.sun, at: date, from: observer) else { return nil }
            let here = EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg)
            let sunEq = EquatorialCoord(raDeg: sun.raDeg, decDeg: sun.decDeg)
            let light = lightDirection(object: here, sun: sunEq, illumination: sample.illuminationFraction)
            let pole = poleInCamera(pole: pole(forObjectID: id), object: here)
            let texture = bakedSphere(light: light, albedo: albedo(forObjectID: id, pole: pole, umbraTint: umbraTint))
            var ring: RGBAImage?
            var ringOpening: Double?
            if id == "saturn" {
                ringOpening = ringOpeningDeg(saturn: here)
                // Cincin memantulkan lebih banyak saat Matahari menyinarinya dari atas bidangnya.
                let brightness = 0.35 + 0.65 * abs(light.dot(pole.normalized ?? .unitY))
                ring = ringTexture(color: CelestialVisual.accents.saturnRing, brightness: brightness)
            }
            return Object3DSpec(objectID: id, name: object.name, kind: object.kind,
                                body: .sphere(texture: texture, ring: ring, ringNormal: ring == nil ? nil : pole),
                                lightDirection: light,
                                illuminationPercent: Int((sample.illuminationFraction * 100).rounded()),
                                ringOpeningDeg: ringOpening)
        case .deepSky, .sun:
            return nil
        }
    }

    /// Warna permukaan tiap benda, dari palet yang sama dengan ikon 2D.
    static func albedo(forObjectID id: String, pole: Vector3, umbraTint: Double)
        -> (Vector3) -> CelestialVisual.RGBComponents {
        let a = CelestialVisual.accents
        switch id {
        case "jupiter":
            return bandedAlbedo(pole: pole, bands: [a.jupiterBandCream, a.jupiterBandRust,
                                                    a.jupiterBandTan, a.jupiterBandCream])
        case "saturn":
            let base = CelestialVisual.Planet.saturn.palette.light
            let darker = CelestialVisual.RGBComponents(red: base.red * 0.88, green: base.green * 0.86, blue: base.blue * 0.82)
            return bandedAlbedo(pole: pole, bands: [base, darker, base])
        case "moon":
            let lit = a.moonLit
            let copper = CelestialVisual.RGBComponents(red: 0.55, green: 0.22, blue: 0.12)
            let t = min(1, max(0, umbraTint))
            // Maria sisi dekat (Utara di atas, seperti dilihat dari Bumi):
            // (arah pusat di ruang kamera, cos jari-jari sudut).
            let maria: [(Vector3, Double)] = [
                (Vector3(x: -0.35, y: 0.55, z: 0.76), 0.95),  // Imbrium
                (Vector3(x: 0.25, y: 0.45, z: 0.86), 0.975),  // Serenitatis
                (Vector3(x: 0.42, y: 0.12, z: 0.90), 0.965),  // Tranquillitatis
                (Vector3(x: 0.76, y: 0.30, z: 0.58), 0.985),  // Crisium
                (Vector3(x: -0.68, y: 0.18, z: 0.71), 0.90),  // Procellarum
                (Vector3(x: -0.18, y: -0.36, z: 0.91), 0.975), // Nubium
                (Vector3(x: 0.62, y: -0.12, z: 0.78), 0.975),  // Fecunditatis
            ].map { ($0.0.normalized ?? $0.0, $0.1) }
            return { n in
                // Tepi lembut: transisi di sekitar batas, bukan lingkaran tajam.
                var dark = 0.0
                for (c, edge) in maria {
                    let d = n.dot(c)
                    let t = min(1, max(0, (d - (edge - 0.03)) / 0.03))
                    dark = max(dark, t * t * (3 - 2 * t))
                }
                let k = 1 - 0.3 * dark
                return .init(red: (lit.red * (1 - t) + copper.red * t) * k,
                             green: (lit.green * (1 - t) + copper.green * t) * k,
                             blue: (lit.blue * (1 - t) + copper.blue * t) * k)
            }
        default:
            let base = CelestialVisual.Planet(objectID: id)?.palette.light ?? .init(red: 0.7, green: 0.7, blue: 0.7)
            return { _ in base }
        }
    }
}

/// Handoff jam → iPhone: "Lihat 3D di iPhone" (ADR-017).
public enum ViewObjectActivity {
    public static let type = "dev.celestial.pointandknow.view-object"
    public static let objectIDKey = "objectID"
}

/// Teks tampilan 3D.
public enum Scene3DText {
    public static var view3D: String { TextLocalization.text(.scene3DView) }
    public static var openOnPhone: String { TextLocalization.text(.scene3DOpenOnPhone) }
    public static var dragHint: String { TextLocalization.text(.scene3DDragHint) }
    public static var planetsEnlarged: String { TextLocalization.text(.scene3DEnlarged) }
    public static func lit(_ percent: Int) -> String {
        TextLocalization.text(.scene3DLit, String(percent) + "%")
    }
    /// "Bulan · Jupiter · 0.2°" — dua nama dan jarak sudutnya (satu desimal
    /// di bawah 10°, supaya konjungsi rapat tidak terbaca "0°").
    public static func pairLine(_ a: String, _ b: String, separationDeg: Double) -> String {
        let deg = NumberFormat.decimal(separationDeg, fractionDigits: separationDeg < 10 ? 1 : 0) + "°"
        return [a, b, deg].joined(separator: " · ")
    }
    public static func ringTilt(_ deg: Double) -> String {
        TextLocalization.text(.scene3DRingTilt, NumberFormat.decimal(abs(deg), fractionDigits: 0) + "°")
    }
}

public extension LocalizedText {
    static let scene3DView = LocalizedText(key: "scene3d.view", id: "Lihat 3D")
    static let scene3DOpenOnPhone = LocalizedText(key: "scene3d.openOnPhone", id: "Lihat 3D di iPhone")
    static let scene3DDragHint = LocalizedText(key: "scene3d.dragHint", id: "Geser untuk memutar, cubit untuk memperbesar")
    static let scene3DEnlarged = LocalizedText(key: "scene3d.enlarged", id: "Planet diperbesar; jarak dan Bulan sesuai skala")
    static let scene3DLit = LocalizedText(key: "scene3d.lit", id: "%@ piringan tersinari")
    static let scene3DRingTilt = LocalizedText(key: "scene3d.ringTilt", id: "Cincin miring %@ dari arah pandang")

    static let scene3DKeys: [LocalizedText] = [
        .scene3DView, .scene3DOpenOnPhone, .scene3DDragHint, .scene3DEnlarged, .scene3DLit, .scene3DRingTilt,
    ]
}
