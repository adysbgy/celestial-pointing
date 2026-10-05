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
                        Text(ExperimentText.targetOption(name: target.name,
                                                         altitudeDeg: target.direction.altitudeDeg))
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
            // Kalimatnya dibaca dari paket, bukan dirakit di sini: yang dirakit
            // lebih dulu ke sebuah `String` tidak punya kunci katalog, jadi ia
            // tidak bisa diterjemahkan dan tidak terlihat gerbang mana pun.
            Text(recorder.currentLocation.isFallback
                 ? ExperimentText.locationFallbackWarning(
                     label: recorder.currentLocation.label)
                 : ExperimentText.locationComputed(
                     label: recorder.currentLocation.label))
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
                    Text(NumberFormat.degreesPerSecond(rate, fractionDigits: 0))
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
            if recorder.recordedCount == 0 {
                Text("Belum ada percobaan yang bisa dianalisis.")
                    .foregroundStyle(Color.nightAwareSecondary)
            } else {
                // Angka "Percobaan" sengaja memakai `recordedCount`, bukan
                // `summary.trialCount`. Yang terakhir hanya menghitung yang
                // teranalisis, jadi memakainya membuat layar melaporkan lebih
                // sedikit percobaan dari yang benar-benar ditekan pengguna —
                // dan selisihnya tidak pernah dijelaskan. Baris berikutnya
                // yang menyebut jumlah yang tidak teranalisis.
                row("Percobaan", "\(recorder.recordedCount)")
                if recorder.unanalyzableCount > 0 {
                    row(ExperimentText.rowCountNotAnalyzed,
                        "\(recorder.unanalyzableCount)")
                }
                row("Benar", "\(summary.correctCount)")
                row("False lock", "\(summary.falseLockCount)")
                if recorder.hasUnanalyzableTrials {
                    // Disebutkan eksplisit karena akibatnya tidak terlihat dari
                    // angka: percobaan ini tidak menambah bukti, jadi ambang
                    // "lulus" tidak makin dekat. Tanpa kalimat ini, pengguna
                    // akan mengira tinggal menambah percobaan saja.
                    Text(ExperimentText.countNotAnalyzedWarning(recorder.unanalyzableCount))
                        .font(.footnote)
                        .foregroundStyle(PointingTone.warning.color)
                }
                if let median = summary.medianRawPointingErrorDeg {
                    row("Galat median", NumberFormat.degrees(median))
                }
                if let p90 = summary.p90RawPointingErrorDeg {
                    row("Galat P90", NumberFormat.degrees(p90))
                }
                Text(recorder.verdict)
                    .font(.footnote)
                    // Nada dari putusan itu sendiri, bukan dari
                    // `passesSafetyCriterion`: yang terakhir bernilai `true`
                    // bahkan untuk satu percobaan bersih, sehingga "belum
                    // cukup bukti" akan tampil hijau sukses.
                    .foregroundStyle(summary.safetyVerdict.tone.color)

                if let policy = recorder.suggestedPolicy() {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ExperimentText.suggestedThreshold(sigmaDeg: policy.pointingSigmaDeg))
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
                    Text(analysis.isFalseLock ? ExperimentText.verdictFalseLock
                         : (analysis.isCorrect ? ExperimentText.verdictCorrect
                                               : ExperimentText.verdictWrong))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(analysis.isFalseLock ? PointingTone.danger.color
                                         : (analysis.isCorrect ? PointingTone.success.color
                                            : PointingTone.warning.color))
                } else {
                    Text(ExperimentText.verdictNotAnalyzed)
                        .font(.caption)
                        .foregroundStyle(Color.nightAwareSecondary)
                }
            }
            Text(detailLine(trial))
                .font(.caption)
                .foregroundStyle(Color.nightAwareSecondary)
        }
        // Baris percobaan diumumkan sebagai **satu** kalimat, dengan dua
        // penyesuaian yang tidak bisa dilakukan oleh gabungan mentah:
        //
        // 1. "FALSE LOCK" adalah singkatan visual. Diucapkan apa adanya ia
        //    terdengar seperti dua kata bahasa Inggris, bukan kegagalan
        //    keselamatan — padahal inilah satu-satunya hasil di layar ini
        //    yang **wajib** terdengar berbeda.
        // 2. `detailLine` berisi "°.1f°/dtk" dan "galat %.1f°"; bentuk
        //    katanya disusul lewat `spokenDetailLine`.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(trialAccessibilityLabel(trial))
    }

    /// Kalimat terucap untuk satu baris percobaan.
    ///
    /// Urutannya sengaja **kebalik** dari tampilan: verdict lebih dulu, lalu
    /// nama, baru detail. Di layar mata melihat nama besar di kiri dan
    /// verdict kecil di kanan; di suara tidak ada "kiri" dan "kanan", dan
    /// yang menentukan apakah baris ini layak dibuka adalah verdict-nya.
    private func trialAccessibilityLabel(_ trial: AnalyzedTrial) -> String {
        var parts: [String] = []
        if let analysis = trial.analysis {
            if analysis.isFalseLock {
                parts.append(ExperimentText.verdictFalseLockSentence)
            } else {
                parts.append(analysis.isCorrect ? ExperimentText.verdictCorrectSentence
                                                : ExperimentText.verdictWrongSentence)
            }
        } else {
            parts.append(ExperimentText.verdictNotAnalyzedSentence)
        }
        parts.append(trialTitle(trial) + ".")
        parts.append(spokenDetailLine(trial))
        return parts.joined(separator: " ")
    }

    /// Padanan terucap dari `detailLine` — satuan jadi kata.
    ///
    /// Sengaja **bukan** mengubah `detailLine`: baris itu dipakai juga
    /// sebagai teks tampilan, dan mengubahnya akan mengubah tampilan. Dua
    /// bentuk, satu sumber angka.
    private func spokenDetailLine(_ trial: AnalyzedTrial) -> String {
        var parts: [String] = []
        if let error = trial.analysis?.rawPointingErrorDeg {
            parts.append(RowSpeech.spokenError(error))
        }
        parts.append(ExperimentText.detailAnswer(
            trial.trial.intent.best?.name ?? ExperimentText.detailNoAnswer))
        parts.append(ExperimentText.detailConfidence(trial.trial.intent.level.displayName))
        parts.append(ExperimentText.detailState(trial.stateAtCapture.shortLabel))
        if let rate = trial.angularRateAtCaptureDegPerSec {
            parts.append(RowSpeech.spokenRate(rate))
        }
        return parts.joined(separator: ", ")
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
            parts.append(ExperimentText.detailError(degrees: error))
        }
        parts.append(ExperimentText.detailAnswer(
            trial.trial.intent.best?.name ?? ExperimentText.detailNoAnswer))
        parts.append(ExperimentText.detailConfidence(trial.trial.intent.level.displayName))
        parts.append(ExperimentText.detailState(trial.stateAtCapture.shortLabel))
        if let rate = trial.angularRateAtCaptureDegPerSec {
            parts.append(ExperimentText.detailRate(degPerSec: rate))
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
        // Satu pengumuman, sumber yang sama dengan `DiagnosticsView` &
        // `LinkView` (`RowSpeech`). Baris di layar ini isinya angka hasil
        // ukur — "Percobaan" lalu "12" tanpa hubungan tidak memberitahu apa
        // yang dihitung.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(RowSpeech.label(title: title, value: value))
    }
}
