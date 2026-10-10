import SwiftUI
import os
import RealityKit
import CoreGraphics
import CelestialEngine
import PointingKit

/// Tampilan 3D di iPhone (ADR-017). Semua geometri dari `Scene3D`
/// (PointingKit, teruji): arah cahaya Matahari, fase, kemiringan cincin, dan
/// jarak konjungsi. Cahaya dipanggang ke tekstur dan materialnya unlit, jadi
/// sisi malam benar-benar gelap — tidak bergantung pada pencahayaan
/// lingkungan RealityKit.
struct Sky3DView: View {
    enum Content {
        case object(Object3DSpec)
        /// Dua benda konjungsi dengan letak dan jari-jari sudutnya (derajat).
        case pair(Object3DSpec, Object3DSpec, offsets: [(x: Double, y: Double)], radiiDeg: [Double], separationDeg: Double)
    }

    let content: Content
    let title: String

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                RealityView { scene in
                    scene.add(await Self.root(for: content))
                }
                .realityViewCameraControls(.orbit)
                .ignoresSafeArea()
                caption
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.55))
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .fontDesign(.rounded)
        }
        .forceDarkScheme()
    }

    @ViewBuilder
    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch content {
            case .object(let spec):
                if let lit = spec.illuminationPercent { Text(Scene3DText.lit(lit)) }
                if let ring = spec.ringOpeningDeg { Text(Scene3DText.ringTilt(ring)) }
            case .pair(let a, let b, _, _, let separation):
                Text(verbatim: Scene3DText.pairLine(a.name, b.name, separationDeg: separation))
                Text(Scene3DText.planetsEnlarged)
            }
            Text(Scene3DText.dragHint).foregroundStyle(Color.nightAwareSecondary)
        }
        .font(.footnote)
    }

    // MARK: Adegan

    @MainActor
    static func root(for content: Content) async -> Entity {
        let root = Entity()
        switch content {
        case .object(let spec):
            root.addChild(await entity(for: spec, radius: 0.5))
        case .pair(let a, let b, let offsets, let radii, _):
            // Skala: 1 satuan = 1° di langit, dipas supaya muat di layar.
            let span = max(1.0, hypot(offsets[0].x - offsets[1].x, offsets[0].y - offsets[1].y))
            let unitPerDeg = Float(1.6 / span)
            for (i, spec) in [a, b].enumerated() {
                let trueRadius = Float(radii[i]) * unitPerDeg
                // Planet terlalu kecil untuk terlihat pada skala sebenarnya: diperbesar.
                let radius = max(trueRadius, spec.kind == .moon ? trueRadius : 0.06)
                let e = await entity(for: spec, radius: max(radius, 0.02))
                e.position = [Float(offsets[i].x) * unitPerDeg, Float(offsets[i].y) * unitPerDeg, 0]
                root.addChild(e)
            }
        }
        return root
    }

    @MainActor
    static func entity(for spec: Object3DSpec, radius: Float) async -> Entity {
        switch spec.body {
        case .star(let c):
            let core = ModelEntity(mesh: .generateSphere(radius: radius * 0.35),
                                   materials: [UnlitMaterial(color: uiColor(c))])
            var haloMaterial = UnlitMaterial(color: uiColor(c))
            haloMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.18))
            let halo = ModelEntity(mesh: .generateSphere(radius: radius * 0.8), materials: [haloMaterial])
            core.addChild(halo)
            return core
        case .sphere(let texture, let ring, let ringNormal):
            let planet = ModelEntity(mesh: .generateSphere(radius: radius),
                                     materials: [await material(texture, transparent: false)])
            if let ring, let n = ringNormal {
                let width = radius * 2 * 2.27
                let disc = ModelEntity(mesh: .generatePlane(width: width, depth: width),
                                       materials: [await material(ring, transparent: true)])
                disc.orientation = simd_quatf(from: [0, 1, 0],
                                              to: simd_normalize(SIMD3<Float>(Float(n.x), Float(n.y), Float(n.z))))
                planet.addChild(disc)
            }
            return planet
        }
    }

    @MainActor
    static func material(_ image: Scene3D.RGBAImage, transparent: Bool) async -> RealityKit.Material {
        var m = UnlitMaterial()
        if let cg = cgImage(image),
           let tex = try? await TextureResource(image: cg, options: .init(semantic: .color)) {
            m.color = .init(tint: .white, texture: .init(tex))
        }
        if transparent {
            m.blending = .transparent(opacity: .init(floatLiteral: 1))
            m.faceCulling = .none
        }
        return m
    }

    /// RGBA lurus → CGImage premultiplied.
    static func cgImage(_ image: Scene3D.RGBAImage) -> CGImage? {
        var px = image.pixels
        for i in stride(from: 0, to: px.count, by: 4) {
            let a = UInt16(px[i + 3])
            px[i] = UInt8(UInt16(px[i]) * a / 255)
            px[i + 1] = UInt8(UInt16(px[i + 1]) * a / 255)
            px[i + 2] = UInt8(UInt16(px[i + 2]) * a / 255)
        }
        guard let provider = CGDataProvider(data: Data(px) as CFData) else { return nil }
        return CGImage(width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    static func uiColor(_ c: CelestialVisual.RGBComponents) -> UIColor {
        UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
    }
}

/// Membangun isi 3D dari keadaan app (ADR-017).
enum Sky3DFactory {
    @MainActor
    static func object(_ id: String, engine: PointingEngine, date: Date = Date(), umbraTint: Double = 0) -> Sky3DView.Content? {
        let resolver = engine.controller.resolver
        let spec = Scene3D.spec(forObjectID: id, observer: engine.controller.observer, date: date,
                                resolver: resolver, umbraTint: umbraTint)
        if spec == nil {
            log.error("3D: no spec for \(id, privacy: .public) (ephemeris \(resolver.ephemeris != nil), object \(resolver.object(forID: id, observer: engine.controller.observer, date: date) != nil))")
        }
        return spec.map { .object($0) }
    }
    private static let log = Logger(subsystem: "dev.celestial.pointandknow", category: "scene3d")

    #if DEBUG
    /// Tekstur kalibrasi UV: empat warna per seperempat u, atas terang/bawah redup.
    static func uvTest() -> Sky3DView.Content {
        var img = Scene3D.RGBAImage(width: 64, height: 32)
        let colors: [CelestialVisual.RGBComponents] = [.init(red: 1, green: 0, blue: 0), .init(red: 0, green: 1, blue: 0),
                                                     .init(red: 0, green: 0, blue: 1), .init(red: 1, green: 1, blue: 0)]
        for y in 0..<32 { for x in 0..<64 {
            let c = colors[x / 16]; let k = y < 16 ? 1.0 : 0.35
            let i = (y * 64 + x) * 4
            img.pixels[i] = UInt8(c.red * k * 255); img.pixels[i + 1] = UInt8(c.green * k * 255)
            img.pixels[i + 2] = UInt8(c.blue * k * 255); img.pixels[i + 3] = 255
        } }
        return .object(Object3DSpec(objectID: "uvtest", name: "uvtest", kind: .planet,
                                    body: .sphere(texture: img, ring: nil, ringNormal: nil),
                                    lightDirection: nil, illuminationPercent: nil, ringOpeningDeg: nil))
    }
    #endif

    @MainActor
    static func content(for p: Phenomenon, engine: PointingEngine) -> Sky3DView.Content? {
        let resolver = engine.controller.resolver
        let observer = engine.controller.observer
        switch p.kind {
        case .conjunction:
            guard p.targetIDs.count == 2, let ephemeris = resolver.ephemeris,
                  let a = Scene3D.spec(forObjectID: p.targetIDs[0], observer: observer, date: p.date, resolver: resolver),
                  let b = Scene3D.spec(forObjectID: p.targetIDs[1], observer: observer, date: p.date, resolver: resolver),
                  let ba = EphemerisBody(rawValue: p.targetIDs[0]), let bb = EphemerisBody(rawValue: p.targetIDs[1]),
                  let sa = try? ephemeris.apparent(ba, at: p.date, from: observer),
                  let sb = try? ephemeris.apparent(bb, at: p.date, from: observer) else { return nil }
            let ea = EquatorialCoord(raDeg: sa.raDeg, decDeg: sa.decDeg)
            let eb = EquatorialCoord(raDeg: sb.raDeg, decDeg: sb.decDeg)
            let layout = Scene3D.conjunctionLayout(ea, eb)
            return .pair(a, b, offsets: [layout.a, layout.b], radiiDeg: [sa.angularRadiusDeg, sb.angularRadiusDeg],
                         separationDeg: SkyMath.angularSeparationDeg(ea, eb))
        case .lunarEclipse:
            let tint: Double = p.eclipseKind == "total" ? 1 : (p.eclipseKind == "partial" ? 0.6 : 0.15)
            return object("moon", engine: engine, date: p.date, umbraTint: tint)
        case .fullMoon, .elongation:
            return p.targetIDs.first.flatMap { object($0, engine: engine, date: p.date) }
        case .solarEclipse, .meteorShower:
            return nil
        }
    }
}

/// Kanvas 3D tanpa navigasi, untuk disisipkan di kartu dan halaman Penemuan
/// (ADR-019). `interactive` = kamera orbit dengan jari.
struct Sky3DCanvas: View {
    let content: Sky3DView.Content
    var interactive = true

    var body: some View {
        let view = RealityView { scene in
            scene.add(await Sky3DView.root(for: content))
        }
        if interactive {
            view.realityViewCameraControls(.orbit)
        } else {
            view.allowsHitTesting(false)
        }
    }
}
