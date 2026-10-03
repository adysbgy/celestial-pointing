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
    @Published public private(set) var statusMessage = "Pilih target, arahkan, lalu rekam."

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
            statusMessage = "Pilih target dulu — tanpa kebenaran, rekaman tidak bisa dianalisis."
            return nil
        }
        guard let raw = engine.snapshot.rawPointing else {
            statusMessage = "Belum ada arah tunjuk dari sensor — tidak ada yang direkam."
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
            statusMessage = "Arah target \(targetID) tidak bisa dihitung — percobaan tidak disimpan."
            return nil
        }

        let error = trial.analysis.map { String(format: "%.1f°", $0.rawPointingErrorDeg) } ?? "—"
        let verdict = trial.analysis?.isFalseLock == true ? "FALSE LOCK" :
            (trial.analysis?.isCorrect == true ? "benar" : "salah")
        statusMessage = "Tercatat: galat \(error), \(verdict). "
            + "Jawaban engine: \(intent.best?.name ?? "belum ada")."
        return trial
    }

    /// Buang percobaan terakhir (mis. salah pilih target).
    public func removeLast() {
        guard let removed = harness.removeLast() else {
            statusMessage = "Tidak ada percobaan untuk dibuang."
            return
        }
        statusMessage = "Dibuang: \(removed.trial.groundTruthObjectID ?? "—")."
    }

    public func reset() {
        harness.reset()
        statusMessage = "Dataset dikosongkan."
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

    /// Usulan ambang keyakinan dari hasil yang sudah terkumpul.
    ///
    /// `nil` berarti belum cukup data — engine tetap memakai ambang bawaannya,
    /// bukan angka karangan.
    public func suggestedPolicy() -> ConfidencePolicy? {
        harness.suggestedConfidencePolicy(calibration: engine.controller.calibration)
    }
}
