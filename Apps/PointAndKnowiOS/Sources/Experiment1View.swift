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
    @ObservedObject var link: PhoneLinkService

    @StateObject private var recorder: ExperimentRecorder

    init(engine: PointingEngine, link: PhoneLinkService) {
        self.engine = engine
        self.link = link
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
            // Sembunyikan latar `List` bawaan supaya gradien aplikasi
            // terlihat di balik kartu, bukan chrome sistem.
            .scrollContentBackground(.hidden)
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
                // Kebenaran (ground truth) dihitung untuk lokasi yang berlaku
                // sekarang. Lokasi sungguhan tiba setelah app dijalankan, jadi
                // `onChange` di bawah yang menyusulkannya — di sini hanya
                // mengejar keadaan yang sudah ada.
                recorder.updateLocation(engine.location)
            }
            // Kebenaran harus mengikuti lokasi yang sedang dipakai engine.
            // Lokasi sungguhan tiba beberapa detik setelah `bind`, jadi tanpa
            // ini daftar target tetap dihitung untuk lokasi bawaan.
            .onChange(of: engine.location) { _, newLocation in
                recorder.updateLocation(newLocation)
            }
            // Sensor & lokasi dimiliki `RootView`, bukan tab ini: keduanya
            // dibagi dengan tab Diagnostik, dan `TabView` menahan kedua tab
            // tetap hidup.
        }
        .appBackground()
        .forceDarkScheme()
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
            // Kalau lokasinya masih yang bawaan, seluruh daftar ini dihitung
            // untuk tempat lain — dan tinggi objeknya salah. Itu harus terlihat,
            // bukan tersembunyi di balik daftar yang tampak normal.
            Text(recorder.currentLocation.isFallback
                 ? "Lokasi belum didapat — tinggi di bawah dihitung untuk \(recorder.currentLocation.label), bukan tempat Anda."
                 : "Dihitung untuk \(recorder.currentLocation.label).")
                .foregroundStyle(recorder.currentLocation.isFallback
                                 ? PointingTone.warning.color
                                 : Color.nightAwareSecondary)
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
                        .foregroundStyle(Color.nightAwareSecondary)
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
            // Sensor mati juga mematikan tombolnya: tanpa ini penguji bisa
            // menekan Rekam dan mengira percobaannya tercatat, padahal
            // `ExperimentRecorder` menolaknya (arah tunjuk yang tersisa bukan
            // pengukuran sekarang). Keadaan alurnya sudah tampil di baris atas.
            .disabled(recorder.selectedTargetID == nil || !engine.snapshot.hasSensor)

            Button("Buang percobaan terakhir", role: .destructive) {
                recorder.removeLast()
            }
            .disabled(recorder.harness.trials.isEmpty)

            Text(recorder.statusMessage)
                .font(.footnote)
                .foregroundStyle(Color.nightAwareSecondary)
        }
    }

    private var resultSection: some View {
        Section("Hasil") {
            let summary = recorder.summary
            if summary.trialCount == 0 {
                Text("Belum ada percobaan yang bisa dianalisis.")
                    .foregroundStyle(Color.nightAwareSecondary)
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
                        .foregroundStyle(Color.nightAwareSecondary)
                }
            }
        }
    }

    private var trialsSection: some View {
        Section("Percobaan") {
            let trials = recorder.harness.trials
            if trials.isEmpty {
                Text("Belum ada percobaan.").foregroundStyle(Color.nightAwareSecondary)
            } else {
                ForEach(Array(trials.enumerated().reversed()), id: \.offset) { _, trial in
                    trialRow(trial)
                }
            }

            ShareLink(item: exportDocument(recorder),
                      preview: SharePreview("Dataset Experiment 1")) {
                Label("Ekspor dataset (JSON)", systemImage: "square.and.arrow.up")
            }
            .disabled(trials.isEmpty)
        }
    }

    private func trialRow(_ trial: AnalyzedTrial) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(trialTitle(trial))
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
                        .foregroundStyle(Color.nightAwareSecondary)
                }
            }
            Text(detailLine(trial))
                .font(.caption)
                .foregroundStyle(Color.nightAwareSecondary)
        }
    }

    /// Headline baris percobaan: **nama** objek yang ditunjuk, bukan slug-nya.
    ///
    /// Baris ini adalah laporan alat ukur, jadi yang ditulis di depan adalah
    /// jawaban yang dicari pengguna. `groundTruthObjectID` menyimpan slug
    /// (`sirius`) karena itulah bentuk yang dipakai mesin; menampilkannya apa
    /// adanya membuat laporan berbunyi seperti file log, bukan seperti hasil.
    ///
    /// `resolver.catalogue` dipakai — bukan `brightStars` — karena resolver dan
    /// tombol-tombol layar ini berjalan dengan katalog yang sama. Kalau
    /// katalognya berbeda, nama akan hilang persis di baris yang paling butuh
    /// kejelasan.
    private func trialTitle(_ trial: AnalyzedTrial) -> String {
        guard let id = trial.trial.groundTruthObjectID else { return "—" }
        return DisplayLabel.objectNameOrIdentifier(
            forObjectID: id,
            catalogue: engine.controller.resolver.catalogue)
    }

    private func detailLine(_ trial: AnalyzedTrial) -> String {
        var parts: [String] = []
        if let error = trial.analysis?.rawPointingErrorDeg {
            parts.append(String(format: "galat %.1f°", error))
        }
        parts.append("jawab \(trial.trial.intent.best?.name ?? "—")")
        parts.append("keyakinan \(trial.trial.intent.level.displayName)")
        parts.append("keadaan \(trial.stateAtCapture.shortLabel)")
        if let rate = trial.angularRateAtCaptureDegPerSec {
            parts.append(String(format: "%.0f°/dtk", rate))
        }
        return parts.joined(separator: " · ")
    }

    /// Ekspor sebagai berkas JSON bernama, lewat lembar berbagi.
    ///
    /// Kalau encoding gagal, yang dibagikan adalah pesan kesalahan di dalam
    /// berkas — bukan berkas kosong yang tampak seperti dataset valid. Nama
    /// berkasnya memakai stempel waktu UTC dari `DatasetArchive` supaya dua
    /// ekspor tidak saling menimpa.
    private func exportDocument(_ recorder: ExperimentRecorder) -> JSONArchiveDocument {
        let filename = DatasetArchive.suggestedFilename()
        do {
            let data = try DatasetArchive.encode(recorder.dataset())
            return JSONArchiveDocument(filename: filename, data: data)
        } catch {
            let message = "{\"error\": \"gagal meng-encode dataset: \(error.localizedDescription)\"}"
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
