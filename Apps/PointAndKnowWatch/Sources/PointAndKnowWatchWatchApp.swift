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

    /// Apakah layar perkenalan sudah pernah dilihat (per-device, sekali).
    @AppStorage(OnboardingStorage.key) private var onboardingSeen = false

    /// Pemutar getaran. Satu instance untuk seluruh umur app: membuatnya ulang
    /// tiap render tidak berbahaya, tapi menyimpannya membuat pemetaan
    /// peristiwa → pola getaran tidak pernah berubah di tengah jalan.
    private let haptics = HapticEngine()
    /// Pemutar bunyi opsional saat kunci — saluran multi-modal bagi pengguna
    /// yang tidak melihat layar. Satu instance untuk seluruh umur app.
    private let audioCue = AudioCueEngine()

    var body: some Scene {
        WindowGroup {
            PointingView(engine: engine, motion: motion, link: link, location: location)
                .onAppear(perform: start)
                .onDisappear { stop() }
                .sheet(isPresented: .init(
                    get: { !onboardingSeen },
                    set: { seen in onboardingSeen = seen })) {
                    OnboardingView(onDone: { onboardingSeen = true })
                }
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

        let cue = audioCue
        engine.audioCue = { events in cue.play(events) }

        location.start()
        // Lokasi sungguhan datang setelah `start()`, jadi engine disambungkan
        // ke sumbernya — bukan diberi satu cuplikan lalu ditinggal.
        engine.bind(location: location)
        engine.refreshSkyContext()

        motion.onUpdate = { update in
            engine.ingest(update)
            // Kirim **saat keputusan berubah** — bukan tiap sampel 20 Hz, dan
            // bukan hanya saat ada jawaban. Menyaring dengan "ada jawaban"
            // membuat jam mengirim 20×/detik selama terkunci (jawabannya terus
            // ada) sekaligus berhenti bicara tepat saat jawabannya hilang,
            // sehingga iPhone membeku di objek terakhir seolah masih berlaku.
            // Aturan perpindahannya ada di `LinkReportGate` (teruji di Linux).
            link.sendIfDecisionChanged(
                state: update.snapshot,
                sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)
        }
        // Sumber keadaan untuk menjawab permintaan iPhone. Dibaca saat diminta,
        // bukan disalin — supaya yang dikirim selalu keadaan yang berlaku.
        link.currentSnapshot = { [weak engine] in
            engine?.snapshot ?? PointingSnapshot(state: .idle)
        }
        motion.start(controller: engine.controller)
        engine.setSensorAvailable(motion.isAvailable)

        // Ambang keyakinan dari iPhone (hasil Experiment 1) diterapkan ke
        // resolver jam, sehingga kedua perangkat memakai ambang yang sama.
        // Lewat engine, bukan controller langsung: mengubah ambang membatalkan
        // jawaban yang dihitung dengan ambang lama, dan pembatalan itu harus
        // sampai ke `snapshot` yang dirender layar.
        link.onPolicyReceived = { policy in
            engine.setConfidencePolicy(policy)
        }

        link.activate()
    }

    private func stop() {
        motion.stop()
        engine.stop()
        location.stop()
    }
}
