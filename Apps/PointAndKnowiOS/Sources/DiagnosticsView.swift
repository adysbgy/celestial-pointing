import SwiftUI
import Charts
import CelestialEngine
import PointingKit

/// Palet warna per nada. Sama seperti di jam, dan sengaja sama: warna "yakin"
/// tidak boleh berbeda antara dua perangkat.
extension PointingTone {
    var color: Color {
        switch self {
        case .neutral: return .secondary
        case .active: return .cyan
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }
}

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

    var body: some View {
        TabView {
            DiagnosticsView(engine: engine, motion: motion, location: location, link: link, trace: trace)
                .tabItem { Label("Diagnostik", systemImage: "chart.xyaxis.line") }
            Experiment1View(engine: engine, motion: motion, location: location, link: link, trace: trace)
                .tabItem { Label("Experiment 1", systemImage: "target") }
            LinkView(link: link, trace: trace)
                .tabItem { Label("Tautan", systemImage: "iphone.gen3.radiowaves.left.and.right") }
        }
        .onAppear {
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
        }
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
                        row("Objek", object.name)
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
                            .foregroundStyle(.secondary)
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
                    Toggle("Rekam keyakinan", isOn: Binding(
                        get: { trace.trace.isRecording },
                        set: { trace.trace.isRecording = $0 }))
                    Button("Kosongkan riwayat") { trace.reset() }
                        .disabled(trace.samples.isEmpty)
                }

                Section {
                    ShareLink(item: exportText) {
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
            .onAppear {
                engine.haptics = nil
                motion.onUpdate = { update in
                    engine.ingest(update)
                    trace.record(snapshot: update.snapshot,
                                 sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)
                }
                motion.start(controller: engine.controller)
                engine.setSensorAvailable(motion.isAvailable)
                location.start()
                engine.update(location: location.effectiveLocation)
            }
            .onDisappear {
                motion.stop()
                engine.stop()
                location.stop()
            }
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
                    .foregroundStyle(.secondary)
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
    /// merekam**. Kalau encoding gagal, yang dibagikan adalah pesan kesalahan —
    /// bukan berkas kosong yang tampak seperti dataset valid.
    private var exportText: String {
        let export = ConfidenceTraceArchive.export(
            from: trace.trace,
            location: engine.location,
            calibration: engine.controller.calibration,
            confidenceSigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)
        do {
            let data = try ConfidenceTraceArchive.encode(export)
            return String(decoding: data, as: UTF8.self)
        } catch {
            return "{\"error\": \"gagal meng-encode riwayat keyakinan: \(error.localizedDescription)\"}"
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
