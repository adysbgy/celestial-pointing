import SwiftUI
import Charts
import CelestialEngine
import PointingKit

/// Akar app iPhone.
///
/// iPhone tidak menunjuk; ia **mengukur dan menjelaskan**. Karena itu dua tab:
/// diagnostik (apa yang terjadi, dan mengapa engine ragu) dan Experiment 1
/// (mengumpulkan data yang menjawab apakah akurasi Watch cukup).
@main
struct PointAndKnowiOSApp: App {

    @StateObject private var engine = PointingEngine()
    @StateObject private var motion = MotionLogger()
    @StateObject private var location = LocationProvider()
    @StateObject private var link = PhoneLinkService()
    @StateObject private var trace = ConfidenceTraceStore()

    var body: some Scene {
        WindowGroup {
            RootView(engine: engine, motion: motion, location: location, link: link, trace: trace)
        }
    }
}

struct RootView: View {

    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var location: LocationProvider
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var trace: ConfidenceTraceStore

    @Environment(\.scenePhase) private var scenePhase

    /// Preferensi mode malam — **satu untuk seluruh app**, bukan per-tab.
    /// `TabView` menahan semua tab tetap hidup, jadi menaruhnya di akar
    /// berarti paletnya berubah serentak di Diagnostik, Experiment 1, dan
    /// Tautan. Kuncinya sama dengan app jam (lihat `NightModeStorage.key`).
    @AppStorage(NightModeStorage.key) private var nightMode = false

    var body: some View {
        TabView {
            DiagnosticsView(engine: engine, motion: motion, location: location, link: link, trace: trace)
                .tabItem { Label("Diagnostik", systemImage: "chart.xyaxis.line") }
            Experiment1View(engine: engine, link: link)
                .tabItem { Label("Experiment 1", systemImage: "target") }
            LinkView(link: link, trace: trace)
                .tabItem { Label("Tautan", systemImage: "iphone.gen3.radiowaves.left.and.right") }
        }
        // Palet merah murni saat malam, berlaku untuk **seluruh** tab.
        .preferredColorScheme(nightMode ? .dark : nil)
        .onAppear { start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: start()
            case .inactive, .background: stop()
            @unknown default: stop()
            }
        }
    }

    /// Sensor, lokasi, dan alur adalah milik **app**, bukan milik satu tab.
    ///
    /// **Kenapa tidak di `onAppear` tiap tab.** `TabView` menahan semua tabnya
    /// tetap hidup: membuka tab lain tidak mematikan tab sebelumnya. Kalau tiap
    /// tab menyalakan sensornya sendiri, keduanya menyetel `motion.onUpdate` pada
    /// `MotionLogger` yang **sama** — yang terakhir menang — dan `onDisappear`
    /// salah satu tab akan memanggil `engine.stop()` untuk alur yang dipakai tab
    /// lain. Gejalanya halus dan menyesatkan: layar tetap tampak hidup sementara
    /// sensor sudah mati, atau riwayat keyakinan diam-diam berhenti terisi.
    /// Menaruh siklus hidupnya di akar membuat ia berjalan tepat sekali untuk
    /// seluruh umur app.
    private func start() {
        // Keputusan yang dikirim jam direkam ke riwayat keyakinan yang sama
        // dengan sampel iPhone; `fromWatch` membedakan asal-usulnya.
        //
        // Tanpa penyambungan ini, `onMessage` tidak pernah dipanggil dan
        // bagian "Sampel dari jam" di layar Tautan akan selalu nol — layar
        // yang tampak baik-baik saja sambil menyembunyikan bahwa datanya
        // tidak pernah masuk. Jam tidak mengirim jarak kandidat, jadi
        // `ratioToSigma` sampel ini memang kosong; itu ditampilkan apa
        // adanya, bukan diisi angka karangan.
        link.onMessage = { message in trace.record(message: message) }
        link.activate()

        // Setiap sampel masuk ke engine **dan** ke riwayat keyakinan.
        // Penyambungannya ada di sini, bukan di tiap tab, karena hanya ada
        // satu `MotionLogger` yang dibagi kedua tab.
        motion.onUpdate = { update in
            engine.ingest(update)
            trace.record(snapshot: update.snapshot,
                         sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)
        }
        // iPhone tidak punya Taptic Engine.
        engine.haptics = nil
        motion.start(controller: engine.controller)
        engine.setSensorAvailable(motion.isAvailable)
        location.start()
        engine.bind(location: location)
    }

    private func stop() {
        motion.stop()
        engine.stop()
        location.stop()
    }
}

/// Pembungkus `ObservableObject` untuk `ConfidenceTrace`, supaya perubahan
/// (sampel baru) memicu render grafik.
@MainActor
final class ConfidenceTraceStore: ObservableObject {
    @Published private(set) var trace = ConfidenceTrace()
    /// Jumlah sampel — dipublikasikan terpisah supaya `objectWillChange`
    /// benar-benar terpicu (kelas `ConfidenceTrace` bukan ObservableObject).
    @Published private(set) var count = 0

    func record(snapshot: PointingSnapshot, sigmaDeg: Double, nearestNeighbourDeg: Double? = nil) {
        // `nearestNeighbourDeg` tidak diisi dari sini: cuplikan sudah membawa
        // angka yang dipakai engine untuk memutuskan ambiguitas, dan
        // `ConfidenceTrace` membacanya dari sana. Satu tempat saja yang tahu
        // dari mana angka itu berasal.
        trace.record(snapshot: snapshot,
                     sigmaDeg: sigmaDeg,
                     nearestNeighbourDeg: nearestNeighbourDeg)
        count = trace.samples.count
    }

    func record(message: PointingLinkMessage) {
        trace.record(message: message)
        count = trace.samples.count
    }

    func reset() {
        trace.reset()
        count = 0
    }

    /// Nyalakan/jeda perekaman.
    ///
    /// **Lewat store, bukan binding langsung ke `trace.trace.isRecording`.**
    /// `ConfidenceTrace` bukan `ObservableObject`, jadi menulis propertinya dari
    /// binding tidak memicu render: saklarnya bisa tampak tidak menanggapi
    /// ketukan. Melewati `@Published` di sini membuat setiap perubahan
    /// dipublikasikan.
    func setRecording(_ isRecording: Bool) {
        trace.isRecording = isRecording
        count = trace.samples.count
    }

    /// Apakah sampel yang datang sedang disimpan.
    var isRecording: Bool { trace.isRecording }

    var samples: [ConfidenceSample] { trace.samples }
}

// MARK: - Diagnostik

/// Grafik keyakinan + penjelasan mengapa engine ragu.
///
/// Yang digambar sengaja **rasio terhadap sigma**, bukan derajat. Ambang
/// keyakinan dinyatakan dalam kelipatan sigma pointing, jadi derajat mentah
/// tidak bisa dibaca: 5° berarti "sangat dekat" pada sigma 10° dan "jauh" pada
/// sigma 1°. Menggambar derajat akan membuat pengguna menyimpulkan hal yang
/// salah tentang ambangnya.
struct DiagnosticsView: View {

    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var location: LocationProvider
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var trace: ConfidenceTraceStore

    /// Preferensi mode malam. Menulis ke kunci yang **sama** dengan `RootView`
    /// (`NightModeStorage.key`), jadi saklar ini dan palet seluruh app tidak
    /// bisa berbeda pendapat — keduanya membaca `UserDefaults` yang sama.
    @AppStorage(NightModeStorage.key) private var nightMode = false

    var body: some View {
        NavigationStack {
            List {
                Section("Sekarang") {
                    row("Keadaan", engine.snapshot.state.shortLabel)
                    row("Kalibrasi", engine.snapshot.isCalibrated ? "Sudah" : "Belum")
                    if let rate = engine.snapshot.angularRateDegPerSec {
                        row("Laju pergelangan", String(format: "%.1f°/dtk", rate))
                    }
                    if let object = engine.displayedObject {
                        // Sama seperti di jam: objek sisa harus terlihat sebagai
                        // sisa. Baris ini berada di bagian "Sekarang", jadi
                        // tanpa penanda ia terbaca sebagai hasil pengukuran
                        // sekarang.
                        row(engine.isDisplayingStaleObject ? "Objek (sisa)" : "Objek",
                            engine.isDisplayingStaleObject
                                ? "\(object.name) — bukan hasil sekarang"
                                : object.name)
                    }
                    if let pointing = engine.pointing {
                        row("Arah", String(format: "%.1f° / %.1f°",
                                           pointing.altitudeDeg, pointing.azimuthDeg))
                    }
                    row("Sigma dipakai", String(format: "%.1f°",
                                                engine.controller.resolver.confidencePolicy.pointingSigmaDeg))
                }

                Section("Keyakinan") {
                    if trace.samples.isEmpty {
                        Text("Belum ada sampel. Angkat iPhone dan arahkan ke langit.")
                            .foregroundStyle(Color.nightAwareSecondary)
                    } else {
                        confidenceChart
                        Text(trace.trace.diagnosis(
                            policy: engine.controller.resolver.confidencePolicy))
                            .font(.footnote)
                    }
                }

                Section("Sensor & lokasi") {
                    row("Device motion", motion.isAvailable ? "Ada" : "Tidak ada")
                    row("Sampel", "\(motion.sampleCount)")
                    row("Lokasi", location.effectiveLocation.label)
                    row("Asal lokasi", location.effectiveLocation.source)
                    if let reason = motion.unavailableReason {
                        Text(reason).foregroundStyle(PointingTone.danger.color)
                    }
                }

                Section("Kontrol") {
                    Toggle("Mode Malam (merah)", isOn: $nightMode)
                    Toggle("Rekam keyakinan", isOn: Binding(
                        get: { trace.isRecording },
                        set: { trace.setRecording($0) }))
                    Button("Kosongkan riwayat") { trace.reset() }
                        // Riwayat kosong **atau** perekaman dijeda: tombol yang
                        // tampak siap menghapus padahal tidak ada yang disimpan
                        // lagi hanya membuat pengguna mengira riwayatnya masih
                        // terkumpul. Keadaannya ditampilkan apa adanya.
                        .disabled(trace.samples.isEmpty || !trace.isRecording)
                }

                Section {
                    ShareLink(item: exportDocument,
                              preview: SharePreview("Riwayat keyakinan")) {
                        Label("Ekspor dataset (JSON)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(trace.samples.isEmpty)
                } header: {
                    Text("Ekspor")
                } footer: {
                    Text("Berkas ini memuat lokasi, kalibrasi, dan sigma yang berlaku saat merekam — tanpa itu, jarak kandidat dalam derajat tidak bisa ditafsirkan kembali.")
                }
            }
            .navigationTitle("Diagnostik")
            // Siklus hidup sensor, lokasi, dan alur **tidak** ada di sini:
            // ketiganya dibagi dengan tab Experiment 1, dan `TabView` menahan
            // kedua tab tetap hidup. Siklus hidupnya ada di `RootView`, tempat
            // ia berjalan tepat sekali untuk seluruh app.
        }
    }

    /// Rasio terhadap sigma. Garis ambang digambar dari kebijakan yang **sedang
    /// dipakai**, bukan angka tetap, supaya grafiknya tetap benar setelah
    /// ambangnya diperketat.
    private var confidenceChart: some View {
        let policy = engine.controller.resolver.confidencePolicy
        let points = trace.samples.enumerated().compactMap { index, sample -> (Int, Double)? in
            sample.ratioToSigma.map { (index, $0) }
        }

        return VStack(alignment: .leading, spacing: 4) {
            if points.isEmpty {
                Text("Sampel ada, tapi belum ada jarak kandidat yang terukur.")
                    .font(.footnote)
                    .foregroundStyle(Color.nightAwareSecondary)
            } else {
                Chart {
                    ForEach(points, id: \.0) { index, ratio in
                        LineMark(x: .value("Sampel", index), y: .value("σ", ratio))
                            .foregroundStyle(PointingTone.active.color)
                    }
                    RuleMark(y: .value("Ambang yakin", policy.maxSeparationSigma))
                        .lineStyle(StrokeStyle(dash: [4, 3]))
                        .foregroundStyle(PointingTone.success.color)
                        .annotation(position: .top, alignment: .leading) {
                            Text("batas yakin").font(.caption2)
                        }
                    RuleMark(y: .value("Ambang ambigu", policy.ambiguitySigma))
                        .lineStyle(StrokeStyle(dash: [2, 4]))
                        .foregroundStyle(PointingTone.warning.color)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("batas ambigu").font(.caption2)
                        }
                }
                .chartYAxisLabel("jarak kandidat / σ")
                .frame(height: 180)
            }

            HStack(spacing: 12) {
                legend("Yakin", .success)
                legend("Ragu", .warning)
                legend("Tidak tahu", .danger)
            }
            .font(.caption2)
        }
    }

    private func legend(_ label: String, _ tone: PointingTone) -> some View {
        HStack(spacing: 3) {
            Circle().fill(tone.color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    /// Isi berkas ekspor: riwayat keyakinan **beserta konteks yang berlaku saat
    /// merekam**. Kalau encoding gagal, yang dibagikan adalah pesan kesalahan di
    /// dalam berkas — bukan berkas kosong yang tampak seperti dataset valid.
    /// Nama berkasnya memakai stempel waktu UTC dari `ConfidenceTraceArchive`.
    private var exportDocument: JSONArchiveDocument {
        let filename = ConfidenceTraceArchive.suggestedFilename()
        let export = ConfidenceTraceArchive.export(
            from: trace.trace,
            location: engine.location,
            calibration: engine.controller.calibration,
            confidenceSigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)
        do {
            let data = try ConfidenceTraceArchive.encode(export)
            return JSONArchiveDocument(filename: filename, data: data)
        } catch {
            let message = "{\"error\": \"gagal meng-encode riwayat keyakinan: \(error.localizedDescription)\"}"
            return JSONArchiveDocument(filename: filename, data: Data(message.utf8))
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(Color.nightAwareSecondary)
        }
    }
}
