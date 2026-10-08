#if DEBUG
import Foundation
import CelestialEngine
import PointingKit

/// Pose sintetis untuk simulator (DEBUG saja, ADR-007).
///
/// Simulator tidak punya device motion, jadi alur Identify → Confirm tidak
/// bisa dilihat di sana. Injector ini memberi controller quaternion yang
/// dibangun dengan konvensi yang sama dengan sensor (ADR-002), 20 Hz, dengan
/// getaran kecil — **bukan** validasi pointing, hanya penggerak UI.
///
/// Diaktifkan lewat argumen peluncuran:
///
///     xcrun simctl launch <sim> <bundle> -debugPose object:sirius
///     … -debugPose ambiguous    (titik tengah dua objek yang berdekatan)
///     … -debugPose empty        (arah tanpa objek di kerucut)
///     … -debugPose moving       (pergelangan terus bergerak)
///
/// Tambahkan `-onboardingSeen YES` untuk melewati kartu perkenalan.
@MainActor
final class DebugPoseInjector {
    static let shared = DebugPoseInjector()

    private var timer: Timer?
    private var tick = 0

    var requestedMode: String? {
        UserDefaults.standard.string(forKey: "debugPose")
    }

    func startIfRequested(engine: PointingEngine) {
        guard let mode = requestedMode else { return }
        start(mode: mode, engine: engine)
    }

    func start(mode: String, engine: PointingEngine) {
        stop()
        let controller = engine.controller
        let aim = controller.config.aim
        let frame = controller.config.frame
        let base = Self.direction(for: mode, controller: controller) ?? HorizontalCoord(altitudeDeg: 45, azimuthDeg: 0)
        let moving = mode == "moving"
        // Satu attitude dasar, lalu hanya putaran kecil mengelilingi vertikal.
        // Membangun ulang busur terpendek tiap sampel membuat roll di sekitar
        // sumbu tunjuk melompat, dan laju sudut terbaca puluhan °/dtk padahal
        // arah tunjuknya diam.
        let q0 = DeviceAttitude.synthetic(aim: aim, pointingAt: base, frame: frame).quaternion
        engine.setSensorAvailable(true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self, weak engine] _ in
            MainActor.assumeIsolated {
                guard let self, let engine else { return }
                self.tick += 1
                let t = Double(self.tick)
                let yawDeg = moving ? t * 3.0 : sin(t * 0.9) * 0.05
                let yaw = Quaternion.axisAngle(axis: .unitZ, radians: SkyMath.deg2rad(yawDeg)) ?? .identity
                engine.ingest(engine.controller.feed(quaternion: yaw.multiplied(by: q0), timestamp: Date()))
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Arah untuk mode yang diminta, dari langit yang **sedang** dihitung
    /// resolver (lokasi & waktu sungguhan simulator).
    static func direction(for mode: String, controller: PointingController) -> HorizontalCoord? {
        let resolver = controller.resolver
        let observer = controller.observer
        let now = Date()
        let targets = resolver.availableTargets(observer: observer, date: now)

        if mode.hasPrefix("object:") {
            return resolver.horizontal(ofObjectID: String(mode.dropFirst("object:".count)),
                                       observer: observer, date: now)
        }
        switch mode {
        case "ambiguous":
            // Pasangan terdekat (tapi tidak menumpuk) → titik tengahnya.
            var best: (Double, HorizontalCoord)?
            for (i, a) in targets.enumerated() {
                for b in targets[(i + 1)...] {
                    let sep = SkyMath.angularSeparationHorizontalDeg(a.direction, b.direction)
                    guard sep > 2, sep < 15 else { continue }
                    if best == nil || sep < best!.0 {
                        let mid = (LocalFrame.enuFromHorizontal(a.direction)
                                   + LocalFrame.enuFromHorizontal(b.direction))
                        if let h = LocalFrame.horizontalFromENU(mid) { best = (sep, h) }
                    }
                }
            }
            return best?.1
        case "empty":
            // Titik langit yang paling jauh dari semua objek.
            var best: (Double, HorizontalCoord)?
            for alt in stride(from: 20.0, through: 80.0, by: 10) {
                for az in stride(from: 0.0, to: 360.0, by: 10) {
                    let h = HorizontalCoord(altitudeDeg: alt, azimuthDeg: az)
                    let d = targets.map { SkyMath.angularSeparationHorizontalDeg(h, $0.direction) }.min() ?? 180
                    if best == nil || d > best!.0 { best = (d, h) }
                }
            }
            return best?.1
        default:
            return targets.first?.direction
        }
    }
}
#endif
