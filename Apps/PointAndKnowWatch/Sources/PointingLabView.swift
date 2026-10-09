import SwiftUI
import CelestialEngine
import PointingKit

/// Layar riset Pointing Lab (ADR-004). Bukan bagian alur produk: ia ada
/// untuk mengukur galat tunjuk di perangkat nyata sebelum ambang, kalibrasi,
/// dan katalog diputuskan. Protokol lapangan: Docs/VALIDATION.md.
struct PointingLabView: View {
    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var link: WatchLinkService
    @StateObject private var recorder = PointingLabRecorder()

    @AppStorage("pointingLab.participant") private var participant = "P01"
    @AppStorage("pointingLab.environment") private var environment = "open-field"
    @State private var selectedTargetID: String?
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private static let participants = (1...12).map { String(format: "P%02d", $0) }
    private static let environments = ["open-field", "urban", "near-telescope", "indoor"]

    private var catalogTargets: [LabTarget] {
        engine.controller.resolver
            .availableTargets(observer: engine.controller.observer, date: Date())
            .prefix(12)
            .map { LabTarget.catalog(objectID: $0.id, name: $0.name) }
    }

    private var allTargets: [LabTarget] { link.labTargets + catalogTargets }

    private var selectedTarget: LabTarget? {
        allTargets.first { $0.id == selectedTargetID } ?? allTargets.first
    }

    var body: some View {
        // List, bukan ScrollView: di jam nyata Picker di dalam ScrollView
        // runtuh menjadi roda setinggi ~10 pt dan teksnya terpotong. Gaya
        // `.navigationLink` memberi baris "Label  nilai" yang terbaca di
        // semua ukuran (40–49 mm) dan membuka daftar pilihan layar penuh.
        List {
            Section {
                liveReadout
                markButton
                if let result = recorder.lastResult { resultRow(result) }
            }
            Section {
                targetPicker
                sessionSettings
            }
            .pickerStyle(.navigationLink)
            Section {
                sendRow
            }
            Section {
                diagnostics
            }
        }
        .navigationTitle("Lab Pointing")
        .onAppear {
            // Satu-satunya aliran sensor selama Lab terbuka adalah milik Lab.
            motion.stop()
            recorder.start()
        }
        .onDisappear {
            recorder.stop()
            motion.start(controller: engine.controller)
        }
    }

    // MARK: Bagian

    private var liveReadout: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: PointingLabText.live(recorder.live))
                .font(.headline)
                .monospacedDigit()
            Text(verbatim: PointingLabText.frameAndAxis(recorder.liveFrame, recorder.aim))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var markButton: some View {
        Button {
            mark()
        } label: {
            Label(recorder.isMarking ? "Merekam" : "Tandai", systemImage: "scope")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!recorder.isRunning || recorder.isMarking || selectedTarget == nil)
        // Ketuk dua kali (Double Tap) menandai tanpa menyentuh layar, jadi
        // lengan yang menunjuk tidak perlu bergerak.
        .handGestureShortcut(.primaryAction)
    }

    private func resultRow(_ s: LabFrameSummary) -> some View {
        let error = s.errorVsTruthDeg?[recorder.aim.rawValue]
        return VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: PointingLabText.trialHeader(index: recorder.trialCount, summary: s))
            if let error {
                Text(verbatim: PointingLabText.error(error))
                    .font(.headline)
            }
            Text(verbatim: PointingLabText.spread(s))
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }

    private var targetPicker: some View {
        Picker("Target", selection: Binding(
            get: { selectedTarget?.id ?? String() },
            set: { selectedTargetID = $0 })) {
            ForEach(allTargets) { target in
                Text(verbatim: target.name).tag(target.id)
            }
        }
    }

    private var sessionSettings: some View {
        Group {
            Picker("Peserta", selection: $participant) {
                ForEach(Self.participants, id: \.self) { Text(verbatim: $0).tag($0) }
            }
            Picker("Lingkungan", selection: $environment) {
                ForEach(Self.environments, id: \.self) { Text(verbatim: $0).tag($0) }
            }
            Picker("Aliran sensor", selection: $recorder.streamMode) {
                ForEach(LabStreamMode.pickerOrder, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
            }
            .onChange(of: recorder.streamMode) { _, _ in recorder.restart() }
        }
    }

    private var sendRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                link.transferLabFile(recorder.fileURL, sessionID: recorder.sessionID,
                                     trialCount: recorder.trialCount)
            } label: {
                Label("Kirim ke iPhone", systemImage: "arrow.up.doc")
            }
            .disabled(!recorder.hasFile)
            if link.labTransfersInFlight > 0 {
                Text(verbatim: PointingLabText.inFlight(link.labTransfersInFlight))
                    .font(.caption2)
            }
            if let ok = link.labTransferSucceeded {
                Image(systemName: ok ? "checkmark.circle" : "xmark.circle")
                    .accessibilityLabel(ok ? "Terkirim" : "Gagal terkirim")
            }
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(recorder.activeFrames, id: \.self) { frame in
                Text(verbatim: PointingLabText.rate(frame, recorder.observedHz[frame]))
            }
            Text(verbatim: PointingLabText.available(recorder.availableFrames))
            Text(verbatim: PointingLabText.wear(recorder.wear))
            Text(verbatim: PointingLabText.runtime(recorder.runtimeState))
            Text(verbatim: PointingLabText.location(isFallback: engine.location.isFallback))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    // MARK: Aksi

    private func mark() {
        guard let target = selectedTarget else { return }
        let observer = engine.controller.observer
        let truth: HorizontalCoord?
        switch target.kind {
        case .manual:
            truth = target.manualTruth
        case .catalogObject:
            truth = target.objectID.flatMap {
                engine.controller.resolver.horizontal(ofObjectID: $0, observer: observer, date: Date())
            }
        }
        recorder.mark(target: target, truth: truth, observer: observer,
                      locationIsFallback: engine.location.isFallback,
                      environment: environment, participant: participant,
                      luminanceReduced: isLuminanceReduced)
    }
}
