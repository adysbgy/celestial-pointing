import SwiftUI
import CelestialEngine
import PointingKit

/// Experiment 1: tunjuk target yang diketahui → rekam → ekspor.
///
/// Layar ini sengaja tidak menyembunyikan hasil buruk. Verdict-nya menyebut
/// "GAGAL" secara eksplisit saat ada false lock, dan setiap percobaan yang
/// gagal tetap ada di daftar. Alat ukur yang menyaring keburukan bukan alat
/// ukur.
struct Experiment1View: View {

    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var location: LocationProvider
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var trace: ConfidenceTraceStore

    @StateObject private var recorder: ExperimentRecorder

    init(engine: PointingEngine, motion: MotionLogger, location: LocationProvider,
         link: PhoneLinkService, trace: ConfidenceTraceStore) {
        self.engine = engine
        self.motion = motion
        self.location = location
        self.link = link
        self.trace = trace
        // Recorder dibuat sekali dari engine yang sama. Kalau ia membuat
        // controller sendiri, rekaman akan memakai jalur pemrosesan yang
        // berbeda dari yang dilihat penguji di layar — dan hasilnya tidak lagi
        // menggambarkan apa pun.
        _recorder = StateObject(wrappedValue: ExperimentRecorder(engine: engine))
    }

    var body: some View {
        NavigationStack {
            List {
                targetSection
                captureSection
                resultSection
                trialsSection
            }
            .navigationTitle("Experiment 1")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        recorder.reset()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(recorder.harness.trials.isEmpty)
                }
            }
            .onAppear {
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

    // MARK: - Bagian

    private var targetSection: some View {
        Section {
            let targets = recorder.availableTargets
            if targets.isEmpty {
                Text("Tidak ada target di atas horizon sekarang.")
                    .foregroundStyle(PointingTone.warning.color)
            } else {
                Picker("Target (kebenaran)", selection: Binding(
                    get: { recorder.selectedTargetID },
                    set: { recorder.selectedTargetID = $0 })) {
                    Text("Belum dipilih").tag(String?.none)
                    ForEach(targets) { target in
                        Text(String(format: "%@ · %.0f°", target.name, target.direction.altitudeDeg))
                            .tag(String?.some(target.id))
                    }
                }
            }
        } header: {
            Text("Target")
        } footer: {
            Text("Kebenaran diambil dari katalog, bukan dari jawaban engine. Kalau engine salah mengenali, kita tetap tahu objek yang sebenarnya dituju.")
        }
    }

    private var captureSection: some View {
        Section("Rekam") {
            HStack {
                Image(systemName: engine.snapshot.state.symbolName)
                    .foregroundStyle(engine.snapshot.state.tone.color)
                Text(engine.snapshot.state.shortLabel)
                Spacer()
                if let rate = engine.snapshot.angularRateDegPerSec {
                    Text(String(format: "%.0f°/dtk", rate))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            TextField("Catatan (opsional)", text: Binding(
                get: { recorder.note },
                set: { recorder.note = $0 }))

            Button {
                recorder.record()
            } label: {
                Label("Rekam percobaan", systemImage: "record.circle")
            }
            .disabled(recorder.selectedTargetID == nil)

            Button("Buang percobaan terakhir", role: .destructive) {
                recorder.removeLast()
            }
            .disabled(recorder.harness.trials.isEmpty)

            Text(recorder.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var resultSection: some View {
        Section("Hasil") {
            let summary = recorder.summary
            if summary.trialCount == 0 {
                Text("Belum ada percobaan yang bisa dianalisis.")
                    .foregroundStyle(.secondary)
            } else {
                row("Percobaan", "\(summary.trialCount)")
                row("Benar", "\(summary.correctCount)")
                row("False lock", "\(summary.falseLockCount)")
                if let median = summary.medianRawPointingErrorDeg {
                    row("Galat median", String(format: "%.1f°", median))
                }
                if let p90 = summary.p90RawPointingErrorDeg {
                    row("Galat P90", String(format: "%.1f°", p90))
                }
                Text(recorder.verdict)
                    .font(.footnote)
                    .foregroundStyle(summary.passesSafetyCriterion
                                     ? PointingTone.success.color
                                     : PointingTone.danger.color)

                if let policy = recorder.suggestedPolicy() {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usulan ambang keyakinan: σ \(String(format: "%.1f°", policy.pointingSigmaDeg))")
                            .font(.footnote)
                        Button("Kirim ambang ke jam") {
                            link.send(policy: policy)
                        }
                        .font(.footnote)
                    }
                } else {
                    Text("Belum cukup data untuk mengusulkan ambang baru — engine tetap memakai ambang konservatif bawaannya.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var trialsSection: some View {
        Section("Percobaan") {
            let trials = recorder.harness.trials
            if trials.isEmpty {
                Text("Belum ada percobaan.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(trials.enumerated().reversed()), id: \.offset) { _, trial in
                    trialRow(trial)
                }
            }

            ShareLink(item: exportText(recorder)) {
                Label("Ekspor dataset (JSON)", systemImage: "square.and.arrow.up")
            }
            .disabled(trials.isEmpty)
        }
    }

    private func trialRow(_ trial: AnalyzedTrial) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(trial.trial.groundTruthObjectID ?? "—")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let analysis = trial.analysis {
                    Text(analysis.isFalseLock ? "FALSE LOCK"
                         : (analysis.isCorrect ? "benar" : "salah"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(analysis.isFalseLock ? PointingTone.danger.color
                                         : (analysis.isCorrect ? PointingTone.success.color
                                            : PointingTone.warning.color))
                } else {
                    Text("tak dianalisis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(detailLine(trial))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func detailLine(_ trial: AnalyzedTrial) -> String {
        var parts: [String] = []
        if let error = trial.analysis?.rawPointingErrorDeg {
            parts.append(String(format: "galat %.1f°", error))
        }
        parts.append("jawab \(trial.trial.intent.best?.name ?? "—")")
        parts.append("keyakinan \(trial.trial.intent.level.rawValue)")
        parts.append("keadaan \(trial.stateAtCapture.shortLabel)")
        if let rate = trial.angularRateAtCaptureDegPerSec {
            parts.append(String(format: "%.0f°/dtk", rate))
        }
        return parts.joined(separator: " · ")
    }

    /// Ekspor sebagai JSON lewat lembar berbagi.
    ///
    /// Kalau encoding gagal, yang dibagikan adalah pesan kesalahan — bukan
    /// berkas kosong yang tampak seperti dataset valid.
    private func exportText(_ recorder: ExperimentRecorder) -> String {
        do {
            let data = try DatasetArchive.encode(recorder.dataset())
            return String(decoding: data, as: UTF8.self)
        } catch {
            return "{\"error\": \"gagal meng-encode dataset: \(error.localizedDescription)\"}"
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
