import SwiftUI
import WidgetKit
import PointingKit
import CelestialEngine

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

    /// Dijalankan sekali, sebelum scene apa pun dibangun. Label keadaan
    /// ("Terkunci", "Kurang yakin", …) bisa dibaca kapan saja, termasuk dari
    /// complication dan pengumuman VoiceOver; bridge yang belum terpasang akan
    /// membuat semuanya diam-diam memakai Bahasa Indonesia.
    init() { LocalizationBridge.install() }

    @Environment(\.scenePhase) private var scenePhase

    // Sumbu tunjuk = lengan bawah, dari cara jam dipakai (ADR-002).
    @StateObject private var engine = PointingEngine(
        config: PointingControllerConfig(aim: WearConfiguration.current.forearmAim)
    )
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
                    // Penulis `isPresented` menerima "masih tampil?", bukan
                    // "sudah dilihat?". Dulu nilainya disimpan apa adanya, jadi
                    // menutup sheet menulis `onboardingSeen = false` dan sheet
                    // langsung muncul lagi — kartu ini tidak pernah bisa ditutup.
                    set: { presented in onboardingSeen = !presented })) {
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

        // Complication membaca ringkasan dari berkas yang dibagi, tapi
        // timeline-nya `.never`: menulis berkas tidak membuat watchOS menggambar
        // ulang apa pun. Tanpa panggilan ini complication menampilkan objek
        // pertama yang pernah terkunci lalu membeku di situ — berkasnya selalu
        // benar, layarnya yang tidak pernah menyegar. `reloadAllTimelines` aman
        // dipanggil saat app aktif; ia hanya menandai timeline perlu dihitung
        // ulang, bukan menggambar langsung.
        engine.complicationReload = { WidgetCenter.shared.reloadAllTimelines() }

        location.start()
        // Lokasi sungguhan datang setelah `start()`, jadi engine disambungkan
        // ke sumbernya — bukan diberi satu cuplikan lalu ditinggal.
        engine.bind(location: location)
        engine.refreshSkyContext()

        motion.onUpdate = { update in engine.ingest(update) }
        engine.onIngest = { snapshot in
            // Kirim **saat keputusan berubah** — bukan tiap sampel 20 Hz, dan
            // bukan hanya saat ada jawaban. Menyaring dengan "ada jawaban"
            // membuat jam mengirim 20×/detik selama terkunci (jawabannya terus
            // ada) sekaligus berhenti bicara tepat saat jawabannya hilang,
            // sehingga iPhone membeku di objek terakhir seolah masih berlaku.
            // Aturan perpindahannya ada di `LinkReportGate` (teruji di Linux).
            link.sendIfDecisionChanged(
                state: snapshot,
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

        #if DEBUG
        // Simulator: pose sintetis dari argumen peluncuran `-debugPose …`.
        DebugPoseInjector.shared.startIfRequested(engine: engine)
        #endif
    }

    private func stop() {
        #if DEBUG
        DebugPoseInjector.shared.stop()
        #endif
        motion.stop()
        engine.stop()
        location.stop()
    }
}
