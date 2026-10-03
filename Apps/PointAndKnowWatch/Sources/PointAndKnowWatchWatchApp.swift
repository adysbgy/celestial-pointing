import SwiftUI
import PointingKit

/// Titik masuk app jam.
///
/// Yang penting di sini adalah **siklus hidup sensor**. Saat pergelangan
/// diturunkan, watchOS menidurkan app; kalau sensor dibiarkan hidup, jam
/// menghabiskan baterai untuk sampel yang tidak dilihat siapa pun. Dan kalau
/// alur tidak dihentikan saat app pergi, objek terakhir bisa tersisa di layar
/// seolah masih terkonfirmasi. Karena itu `scenePhase` langsung memetakan ke
/// start/stop.
@main
struct PointAndKnowWatchApp: App {

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var engine = PointingEngine()
    @StateObject private var motion = MotionLogger()
    @StateObject private var link = WatchLinkService()
    @StateObject private var location = LocationProvider()

    /// Pemutar getaran. Satu instance untuk seluruh umur app: membuatnya ulang
    /// tiap render tidak berbahaya, tapi menyimpannya membuat pemetaan
    /// peristiwa → pola getaran tidak pernah berubah di tengah jalan.
    private let haptics = HapticEngine()

    var body: some Scene {
        WindowGroup {
            PointingView(engine: engine, motion: motion, link: link)
                .onAppear(perform: start)
                .onDisappear { stop() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                start()
            case .inactive, .background:
                stop()
            @unknown default:
                stop()
            }
        }
    }

    private func start() {
        let player = haptics
        engine.haptics = { events in player.play(events) }

        location.start()
        engine.update(location: location.effectiveLocation)
        engine.refreshSkyContext()

        motion.onUpdate = { update in
            engine.ingest(update)
            // Laporkan hanya saat ada jawaban atau sensor berubah — bukan tiap
            // sampel 20 Hz. Jam dan telepon sering tidak terhubung, dan yang
            // berguna di sana adalah keputusan terakhir, bukan banjir sampel.
            if update.snapshot.state.hasAnswer || update.haptics.contains(.sensorUnavailable) {
                link.send(state: update.snapshot)
            }
        }
        motion.start(controller: engine.controller)
        engine.setSensorAvailable(motion.isAvailable)

        // Ambang keyakinan dari iPhone (hasil Experiment 1) diterapkan ke
        // resolver jam, sehingga kedua perangkat memakai ambang yang sama.
        link.onPolicyReceived = { policy in
            engine.controller.resolver.confidencePolicy = policy
        }

        link.activate()
    }

    private func stop() {
        motion.stop()
        engine.stop()
        location.stop()
    }
}
