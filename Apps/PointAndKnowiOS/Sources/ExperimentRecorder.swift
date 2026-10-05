import Foundation
import Combine
import CelestialEngine
import PointingKit

/// Perekam Experiment 1 di iPhone.
///
/// **Kenapa Experiment 1 ada.** PRD v0.4 menyatakan akurasi Apple Watch adalah
/// hipotesis, bukan asumsi. Alat ini yang mengujinya: penguji memilih target
/// yang **sudah diketahui** (kebenaran dari katalog, bukan dari jawaban
/// engine), mengarahkan jam ke sana, lalu menekan tombol. Yang disimpan adalah
/// arah tunjuk mentah, jawaban engine saat itu, dan arah objek yang sebenarnya.
///
/// Dua hal yang sengaja tidak dilakukan:
/// 1. **Tidak menyaring percobaan gagal.** Membuang yang gagal menghapus
///    informasi paling berharga — seberapa sering engine salah.
/// 2. **Tidak merekam jawaban yang sudah basi.** Kalau pergelangan sudah
///    bergerak, `snapshot.intent` masih berisi jawaban dari arah sebelumnya.
///    Merekamnya sebagai jawaban untuk arah baru akan mencatat false lock yang
///    tidak pernah terjadi. Karena itu yang direkam adalah
///    `controller.answeredIntent`.
@MainActor
public final class ExperimentRecorder: ObservableObject {

    public let harness: ExperimentHarness
    public private(set) var engine: PointingEngine

    /// Lokasi yang sedang dipakai harness — sama dengan lokasi engine.
    ///
    /// Ditampilkan di layar supaya penguji bisa melihat bahwa kebenaran
    /// dihitung untuk tempat yang benar. Kalau ini masih lokasi bawaan,
    /// seluruh daftar target sedang salah dan itu harus terlihat.
    @Published public private(set) var currentLocation: ObserverLocation

    /// Target yang dipilih penguji sebagai kebenaran.
    @Published public var selectedTargetID: String?
    /// Catatan bebas untuk percobaan berikutnya (kondisi langit, dll).
    @Published public var note: String = ""
    /// Pesan terakhir untuk penguji.
    @Published public private(set) var statusMessage = ExperimentText.statusInitial

    public init(engine: PointingEngine) {
        self.engine = engine
        self.harness = ExperimentHarness(resolver: engine.controller.resolver,
                                         location: engine.location)
        self.currentLocation = engine.location
        self.harness.location = engine.location
    }

    /// Sinkronkan kebenaran dengan lokasi engine yang berlaku sekarang.
    ///
    /// Kebenaran (ground truth) **wajib** memakai lokasi yang sama dengan yang
    /// dipakai engine. Kalau tidak, daftar target di layar dihitung untuk
    /// lokasi bawaan: tinggi objeknya salah, dan target yang tampak "di atas
    /// horizon" bisa sebenarnya sudah terbenam — penguji memilih target yang
    /// tidak bisa direkam, lalu rekamannya ditolak tanpa sebab yang jelas.
    ///
    /// Dipanggil pemanggil saat lokasi engine berubah (lokasi sungguhan tiba
    /// beberapa detik setelah app dibuka), bukan disalin sekali di `init`.
    public func updateLocation(_ location: ObserverLocation) {
        guard location != currentLocation else { return }
        currentLocation = location
        harness.location = location
    }

    /// Target yang boleh dipakai sebagai kebenaran (di atas horizon, arahnya
    /// bisa dihitung).
    public var availableTargets: [PointingTarget] { harness.availableTargets }

    /// Rekam satu percobaan untuk target yang dipilih.
    ///
    /// - Returns: `nil` bila tidak ada yang bisa direkam — pemanggil
    ///   menampilkan `statusMessage` apa adanya, bukan pesan sukses.
    @discardableResult
    public func record(at date: Date = Date()) -> AnalyzedTrial? {
        guard let targetID = selectedTargetID else {
            statusMessage = ExperimentText.statusNoTarget
            return nil
        }
        // Sensor harus benar-benar hidup. Saat sensor mati, `rawPointing` yang
        // ada di cuplikan adalah **nilai terakhir sebelum sensor hilang** —
        // nilainya tetap terisi, jadi pemeriksaan "ada arah tunjuk?" saja akan
        // meloloskannya. Yang terekam saat itu adalah arah dari beberapa detik
        // lalu yang dipasangkan dengan target yang dipilih sekarang: sebuah
        // pengukuran yang tidak pernah terjadi, di dalam dataset yang justru
        // ada untuk menguji akurasi. Alat ukur tidak boleh mengarang data.
        guard engine.snapshot.hasSensor else {
            statusMessage = ExperimentText.statusSensorOff
            return nil
        }
        guard let raw = engine.snapshot.rawPointing else {
            statusMessage = ExperimentText.statusNoPointing
            return nil
        }

        // Jawaban yang berlaku untuk arah sekarang. `nil` berarti engine belum
        // menjawab: itu tetap direkam, sebagai percobaan yang belum ada
        // jawabannya — bukan dibuang.
        let intent = engine.answeredIntent
            ?? CelestialIntent(level: .low, best: nil, candidates: [])

        harness.location = engine.location
        guard let trial = harness.record(targetObjectID: targetID,
                                         rawPointing: raw,
                                         calibratedPointing: engine.snapshot.calibratedPointing,
                                         intent: intent,
                                         state: engine.snapshot.state,
                                         angularRateDegPerSec: engine.snapshot.angularRateDegPerSec,
                                         calibration: engine.controller.calibration,
                                         timestamp: date,
                                         note: note.isEmpty ? nil : note) else {
            statusMessage = ExperimentText.statusTargetUncomputable(targetID: targetID)
            return nil
        }

        let error = trial.analysis.map { ExperimentText.detailError(degrees: $0.rawPointingErrorDeg) }
            ?? ExperimentText.detailNoError
        let verdict = trial.analysis?.isFalseLock == true ? ExperimentText.verdictFalseLock
            : (trial.analysis?.isCorrect == true ? ExperimentText.verdictCorrect
                                                 : ExperimentText.verdictWrong)
        statusMessage = ExperimentText.statusRecorded(
            error: error,
            verdict: verdict,
            answer: intent.best?.name ?? ExperimentText.detailNoAnswer)
        return trial
    }

    /// Buang percobaan terakhir (mis. salah pilih target).
    public func removeLast() {
        guard let removed = harness.removeLast() else {
            statusMessage = ExperimentText.statusNothingToRemove
            return
        }
        statusMessage = ExperimentText.statusRemoved(
            objectID: removed.trial.groundTruthObjectID ?? ExperimentText.detailNoError)
    }

    public func reset() {
        harness.reset()
        statusMessage = ExperimentText.statusReset
    }

    /// Dataset lengkap dengan konteks rekaman.
    public func dataset() -> ExperimentDataset {
        harness.dataset(calibration: engine.controller.calibration,
                        confidenceSigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg,
                        aim: engine.snapshot.aim.rawValue)
    }

    /// Kalimat penilaian Experiment 1.
    public var verdict: String { harness.verdict }

    /// Ringkasan angka.
    public var summary: ExperimentSummary { harness.summary }

    /// Rekaman apa adanya, tanpa konteks ekspor.
    ///
    /// Dipakai sebagai sumber angka tampilan. Yang dihitung dari sini adalah
    /// `trials` — bukan ringkasan analisis — supaya "Percobaan" sama dengan
    /// jumlah baris yang benar-benar ada di daftar di bawahnya.
    private var recordedTrials: ExperimentDataset {
        harness.dataset(calibration: engine.controller.calibration,
                        confidenceSigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg,
                        aim: engine.snapshot.aim.rawValue)
    }

    /// Jumlah rekaman yang benar-benar tercatat, termasuk yang tak teranalisis.
    ///
    /// **Kenapa view butuh ini, bukan cuma `summary`.** `summary.trialCount`
    /// hanya menghitung percobaan yang teranalisis, sedangkan daftar di layar
    /// menampilkan semua rekaman. Kalau view hanya punya `summary`, "Percobaan"
    /// akan terlihat lebih sedikit dari baris yang benar-benar ada — dan
    /// selisihnya tidak akan pernah dijelaskan.
    public var recordedCount: Int { recordedTrials.recordedCount }

    /// Percobaan yang tercatat tapi tidak bisa dinilai.
    ///
    /// Ketentuannya sengaja **dibaca** dari paket, bukan dihitung ulang di sini:
    /// `ExperimentDataset` sudah menghitungnya, dan dua definisi "tak
    /// teranalisis" yang berbeda diam-diam akan membuat layar dan vonis
    /// memakai dua definisi yang berbeda.
    public var unanalyzableCount: Int { recordedTrials.unanalyzableCount }

    /// Apakah ada rekaman yang tercatat tapi tidak bisa dinilai.
    public var hasUnanalyzableTrials: Bool { recordedTrials.hasUnanalyzableTrials }

    /// Usulan ambang keyakinan dari hasil yang sudah terkumpul.
    ///
    /// `nil` berarti belum cukup data — engine tetap memakai ambang bawaannya,
    /// bukan angka karangan.
    public func suggestedPolicy() -> ConfidencePolicy? {
        harness.suggestedConfidencePolicy(calibration: engine.controller.calibration)
    }
}
