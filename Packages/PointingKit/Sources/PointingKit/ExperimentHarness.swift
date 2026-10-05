import Foundation
import CelestialEngine

/// Satu percobaan Experiment 1 yang sudah dianalisis, siap diekspor.
public struct AnalyzedTrial: Codable, Equatable, Sendable {
    public var trial: PointingTrial
    /// `nil` bila arah kebenaran tidak bisa dihitung (mis. efemeris gagal).
    public var analysis: TrialAnalysis?
    /// Arah objek yang sebenarnya saat percobaan — dipakai untuk menghitung galat.
    public var truthDirection: HorizontalCoord?
    /// Keadaan alur saat tombol ditekan (lock/uncertain).
    public var stateAtCapture: PointingState
    /// Kecepatan sudut pergelangan saat tombol ditekan (derajat/detik).
    public var angularRateAtCaptureDegPerSec: Double?

    public init(trial: PointingTrial,
                analysis: TrialAnalysis?,
                truthDirection: HorizontalCoord?,
                stateAtCapture: PointingState,
                angularRateAtCaptureDegPerSec: Double?) {
        self.trial = trial
        self.analysis = analysis
        self.truthDirection = truthDirection
        self.stateAtCapture = stateAtCapture
        self.angularRateAtCaptureDegPerSec = angularRateAtCaptureDegPerSec
    }
}

/// Seluruh dataset Experiment 1: percobaan + konteks + ringkasan.
///
/// Konteks (lokasi, kalibrasi, kebijakan) ikut disimpan karena galat pointing
/// tidak bisa ditafsirkan tanpa tahu dari mana angkanya datang. Rekaman tanpa
/// metadata adalah anekdot, bukan data.
public struct ExperimentDataset: Codable, Equatable, Sendable {
    public var createdAt: Date
    public var location: ObserverLocation
    /// Kalibrasi yang dipakai saat perekaman.
    public var calibration: PointingCalibration
    /// Kebijakan keyakinan yang dipakai saat perekaman.
    public var confidenceSigmaDeg: Double
    /// Sumbu badan yang dianggap arah tunjuk.
    public var aim: String
    public var trials: [AnalyzedTrial]
    /// Hasil hitungan atas `trials`.
    ///
    /// **Kenapa ini computed, bukan property yang disimpan.** Sebelumnya
    /// `summary` diisi sekali di `init` lalu ikut disalin ke arsip JSON
    /// sebagai field biasa. Itu berarti arsip punya **dua** bentuk kebenaran
    /// yang tidak saling mengikat: `trials` (rekaman) dan `summary` (hasil
    /// hitungannya). `DatasetArchive.decode` menerima keduanya apa adanya,
    /// jadi berkas yang `summary`-nya sudah diubah akan menghasilkan
    /// `falseLockCount` yang tidak pernah dihitung — dan dari situ
    /// `safetyVerdict` bisa keluar "aman".
    ///
    /// Bentuk sekarang menjadikan `trials` satu-satunya sumber. `trials`
    /// tetap ikut di arsip supaya berkas ekspor tetap bisa dibaca sebagai
    /// bukti yang berdiri sendiri; yang hilang adalah **ukuran**
    /// ringkasannya, yang sebelumnya berarti data kedua yang harus dipercaya
    /// tanpa pernah diverifikasi.
    ///
    /// Batas yang jujur: ini menutup pemalsuan lewat arsip, bukan
    /// `trials` itu sendiri. Rekaman yang salah masih salah — tetapi sekarang
    /// ia salah **terlihat**, karena ringkasan selalu menyertainya.
    public var summary: ExperimentSummary {
        ObservationLog.summarize(trials.compactMap(\.analysis))
    }

    public init(createdAt: Date,
                location: ObserverLocation,
                calibration: PointingCalibration,
                confidenceSigmaDeg: Double,
                aim: String,
                trials: [AnalyzedTrial]) {
        self.createdAt = createdAt
        self.location = location
        self.calibration = calibration
        self.confidenceSigmaDeg = confidenceSigmaDeg
        self.aim = aim
        self.trials = trials
    }

    /// Percobaan yang belum bisa dianalisis (label atau arah kebenaran hilang).
    ///
    /// **Kenapa ini harus ada dan bukan cuma `summary`.** `summary` dibangun dari
    /// `trials.compactMap(\.analysis)`, jadi `trialCount` menghitung **hanya**
    /// yang teranalisis. Tanpa penghitung ini, rekaman yang tidak bisa dinilai
    /// hilang tanpa suara: layar menampilkan "Percobaan 12" padahal ada 14
    /// rekaman, dan selisihnya tidak pernah dijelaskan.
    ///
    /// Yang hilang bukan angka kosmetik. `trialCount` itu yang menentukan
    /// `hasEnoughEvidenceForSafetyClaim`, jadi percobaan yang tak teranalisis
    /// membuat penguji mengira sampelnya bertambah tanpa bukti baru masuk —
    /// persis "yakin padahal belum tahu" versi pengukuran.
    public var unanalyzableCount: Int { trials.filter { $0.analysis == nil }.count }

    /// Percobaan yang benar-benar ikut dihitung dalam vonis.
    ///
    /// Berbeda dari `summary.trialCount` hanya karena dihitung di sini, bukan
    /// diambil dari ringkasan — supaya layar bisa menampilkan kedua angka
    /// berdampingan tanpa menghitung ulang di view.
    public var analyzedCount: Int { trials.count - unanalyzableCount }

    /// Semua rekaman yang ada, termasuk yang tidak bisa dinilai.
    ///
    /// Inilah angka yang jujur untuk baris "Percobaan": yang dihitung engine
    /// adalah rekaman, dan pengguna menekan tombol sebanyak itu.
    public var recordedCount: Int { trials.count }

    /// Apakah ada rekaman yang tercatat tapi tidak bisa dinilai.
    ///
    /// Penanda ini perlu karena "belum cukup bukti" punya dua sebab yang
    /// butuh tindakan berbeda: sampel memang masih sedikit, atau sampelnya
    /// ada tapi separuhnya tidak bisa dinilai. Tanpa penanda, keduanya tampil
    /// sama dan pengguna akan mengira dia belum menekan tombol cukup kali.
    public var hasUnanalyzableTrials: Bool { unanalyzableCount > 0 }

    /// Percobaan yang engine-nya salah **tetapi** yakin tinggi.
    /// Nol adalah syarat lulus; apa pun di atas nol adalah kegagalan.
    public var falseLocks: [AnalyzedTrial] {
        trials.filter { $0.analysis?.isFalseLock == true }
    }
}

/// Harness Experiment 1: menunjuk target yang sudah diketahui → merekam → ekspor.
///
/// **Kenapa ini ada.** PRD v0.4 menyatakan akurasi Apple Watch adalah hipotesis
/// yang harus diuji, bukan asumsi. Harness ini adalah alat ujinya: pengguna
/// memilih objek target dari katalog (kebenaran diketahui), menunjuk ke arahnya
/// dengan jam, lalu menekan tombol. Yang direkam adalah arah tunjuk mentah,
/// jawaban engine, dan arah objek yang sebenarnya — sehingga galat bisa
/// dihitung, bukan ditebak.
///
/// Harness ini **tidak** menyaring percobaan yang "jelek". Membuang percobaan
/// yang gagal justru menghapus informasi paling berharga: seberapa sering
/// engine salah. Semua percobaan disimpan, termasuk yang salah.
public final class ExperimentHarness {

    public private(set) var trials: [AnalyzedTrial] = []
    /// Lokasi yang dipakai saat merekam.
    ///
    /// Mengubahnya membatalkan cache daftar target: langit di tempat baru
    /// belum pernah dihitung, jadi daftar tempat lama tidak berlaku di sana.
    ///
    /// Yang menentukan adalah **koordinatnya**, bukan keseluruhan nilai:
    /// `ObserverLocation` membawa `capturedAt` yang berubah di tiap pembaruan
    /// GPS, jadi tanpa `isSamePlace` cache akan dibuang tiap detik dan
    /// daftar target kembali dihitung 20 kali per detik.
    public var location: ObserverLocation {
        didSet {
            guard !location.isSamePlace(as: oldValue) else { return }
            targetCache = nil
        }
    }
    public let resolver: PointingResolver

    /// Selang waktu (detik) daftar target dianggap masih berlaku.
    public var targetListValidity: TimeInterval = 30

    /// Berapa kali daftar target benar-benar dihitung dari katalog.
    ///
    /// Diumumkan karena alasan yang sama seperti `sampleCount` di engine:
    /// perhitungan ini menyapu seluruh katalog dan efemeris tata surya, dan
    /// layar Experiment 1 membacanya di dalam `body`. Tanpa angka ini, daftar
    /// yang dihitung ulang 20 kali per detik terlihat persis sama dengan yang
    /// di-cache.
    public private(set) var targetComputationCount = 0

    /// Cache daftar target terakhir.
    private var targetCache: (observer: Observer, bucket: Int, targets: [PointingTarget])?

    public init(resolver: PointingResolver, location: ObserverLocation) {
        self.resolver = resolver
        self.location = location
    }

    /// Objek target yang boleh dipakai sebagai kebenaran.
    ///
    /// Bintang selalu ada (katalog). Bulan/planet hanya bila efemerisnya
    /// tersedia — target tanpa arah yang bisa dihitung akan menghasilkan
    /// percobaan yang tak bisa dianalisis, dan itu hanya membuang waktu.
    ///
    /// Hanya yang di atas horizon yang ditawarkan: menunjuk objek yang tidak
    /// ada di langit menghasilkan rekaman yang menyesatkan.
    public var availableTargets: [PointingTarget] {
        let now = Date()
        let observer = location.observer
        let bucket = Int(now.timeIntervalSince1970 / targetListValidity)
        if let cache = targetCache, cache.observer == observer, cache.bucket == bucket {
            return cache.targets
        }
        let targets = resolver.availableTargets(observer: observer, date: now)
        targetComputationCount += 1
        targetCache = (observer, bucket, targets)
        return targets
    }

    /// Paksa perhitungan ulang daftar target pada akses berikutnya.
    ///
    /// Dipakai saat penguji berpindah tempat: daftar lama dihitung untuk langit
    /// yang lain, dan daftar yang salah tempat tampak sama normalnya dengan
    /// yang benar.
    public func invalidateTargets() { targetCache = nil }

    /// Rekam satu percobaan.
    ///
    /// - Parameters:
    ///   - targetObjectID: objek yang **benar-benar** dituju manusia. Ini
    ///     kebenarannya; sengaja tidak diambil dari jawaban engine.
    ///   - rawPointing: arah tunjuk mentah dari sensor.
    ///   - calibratedPointing: arah tunjuk setelah kalibrasi (kalau ada).
    ///   - intent: jawaban engine saat itu.
    ///   - state: keadaan alur saat tombol ditekan. Ikut menentukan false lock:
    ///     keadaan tanpa jawaban (`pointing`/`searching`/`idle`/`unavailable`)
    ///     tidak bisa menghasilkan false lock, karena engine tidak sedang
    ///     menampilkan klaim apa pun.
    ///   - angularRateDegPerSec: laju pergelangan saat itu, untuk menafsirkan
    ///     apakah galat besar disebabkan gerakan yang belum tenang.
    ///   - timestamp: waktu percobaan.
    ///   - note: catatan bebas penguji.
    /// - Returns: percobaan yang tersimpan, atau `nil` bila target tidak
    ///   dikenal / arahnya tidak bisa dihitung (rekaman seperti itu tidak
    ///   berguna dan tidak boleh masuk dataset).
    @discardableResult
    public func record(targetObjectID: String,
                       rawPointing: HorizontalCoord,
                       calibratedPointing: HorizontalCoord?,
                       intent: CelestialIntent,
                       state: PointingState,
                       angularRateDegPerSec: Double?,
                       calibration: PointingCalibration,
                       timestamp: Date,
                       note: String? = nil) -> AnalyzedTrial? {
        guard let truth = resolver.horizontal(ofObjectID: targetObjectID,
                                              observer: location.observer,
                                              date: timestamp) else {
            return nil
        }

        let trial = PointingTrial(timestamp: timestamp,
                                  observer: location.observer,
                                  rawPointing: rawPointing,
                                  calibratedPointing: calibratedPointing,
                                  intent: intent,
                                  groundTruthObjectID: targetObjectID,
                                  note: note)
        let analysis = ObservationLog.analyze(trial, truthDirection: truth, state: state)

        let analyzed = AnalyzedTrial(trial: trial,
                                     analysis: analysis,
                                     truthDirection: truth,
                                     stateAtCapture: state,
                                     angularRateAtCaptureDegPerSec: angularRateDegPerSec)
        trials.append(analyzed)
        return analyzed
    }

    /// Buang percobaan terakhir (mis. salah pilih target).
    @discardableResult
    public func removeLast() -> AnalyzedTrial? {
        trials.popLast()
    }

    public func reset() { trials = [] }

    /// Dataset lengkap dengan konteks.
    public func dataset(calibration: PointingCalibration,
                        confidenceSigmaDeg: Double,
                        aim: String,
                        createdAt: Date = Date()) -> ExperimentDataset {
        ExperimentDataset(createdAt: createdAt,
                          location: location,
                          calibration: calibration,
                          confidenceSigmaDeg: confidenceSigmaDeg,
                          aim: aim,
                          trials: trials)
    }

    /// Ringkasan analisis semua percobaan yang bisa dianalisis.
    public var summary: ExperimentSummary {
        ObservationLog.summarize(trials.compactMap(\.analysis))
    }

    // MARK: - Kebijakan dari hasil pengukuran

    /// Usulkan `ConfidencePolicy` berdasarkan hasil Experiment 1.
    ///
    /// Aturan yang dipegang (PRD: uncertainty > false confidence):
    /// - **Ada false lock** → ambang harus **diperketat**, bukan dilonggarkan.
    ///   Engine yang yakin tapi salah adalah mode kegagalan terburuk; satu saja
    ///   sudah cukup untuk memaksa sigma turun, sehingga lebih sedikit kasus
    ///   yang boleh berlabel HIGH.
    /// - **Tanpa false lock** → pakai sigma hasil kalibrasi bila ada (itu
    ///   ketidakpastian yang benar-benar terukur). Kalau belum ada, kembali ke
    ///   sigma konservatif bawaan — jangan mengarang angka yang lebih baik.
    /// - **Tidak ada percobaan** → `nil`; engine tetap memakai bawaannya.
    public func suggestedConfidencePolicy(calibration: PointingCalibration,
                                          baseSigmaDeg: Double = 10.0) -> ConfidencePolicy? {
        let analyzable = trials.compactMap(\.analysis)
        guard !analyzable.isEmpty else { return nil }

        let summary = ObservationLog.summarize(analyzable)
        let measured = calibration.suggestedPointingSigmaDeg

        if summary.falseLockCount > 0 {
            // Perketat: pakai sigma terukur kalau ada, kalau tidak separuh bawaannya.
            let tightened = min(measured ?? baseSigmaDeg, baseSigmaDeg) / 2.0
            return ConfidencePolicy(pointingSigmaDeg: max(0.5, tightened))
        }
        guard let sigma = measured, sigma > 0 else { return nil }
        return ConfidencePolicy(pointingSigmaDeg: sigma)
    }

    /// Kalimat penilaian untuk ditampilkan ke pengguna.
    ///
    /// **Kenapa "nol false lock" saja tidak cukup untuk bilang "lulus".**
    /// Lihat `ExperimentSummary.safetyVerdict`: gagal butuh satu contoh
    /// tandingan, lulus butuh sampel yang cukup. Satu percobaan bersih
    /// sebelumnya dicetak sebagai "Lulus syarat keselamatan" — klaim
    /// keselamatan dari satu titik data. Kini keadaan itu punya kalimatnya
    /// sendiri yang jujur menyebut sampelnya belum cukup.
    public var verdict: String {
        let analyzable = trials.compactMap(\.analysis)
        guard !analyzable.isEmpty else { return ExperimentText.summaryNoAnalyzable }
        let summary = ObservationLog.summarize(analyzable)

        let accuracy = summary.accuracy.map { NumberFormat.percent($0) } ?? "—"
        let median = summary.medianRawPointingErrorDeg.map { NumberFormat.degrees($0) } ?? "—"
        let p90 = summary.p90RawPointingErrorDeg.map { NumberFormat.degrees($0) } ?? "—"

        switch summary.safetyVerdict {
        case .failed:
            return ExperimentText.summaryFailed(falseLockCount: summary.falseLockCount,
                                                accuracy: accuracy,
                                                median: median,
                                                p90: p90)
        case .insufficientEvidence:
            // Jangan ucapkan "lulus": yang diketahui cuma "belum ketemu".
            return ExperimentText.summaryInsufficient(
                trialCount: summary.trialCount,
                minimum: ExperimentSummary.minimumTrialsForSafetyClaim,
                accuracy: accuracy,
                median: median,
                p90: p90)
        case .passed:
            return ExperimentText.summaryPassed(trialCount: summary.trialCount,
                                                accuracy: accuracy,
                                                median: median,
                                                p90: p90)
        }
    }
}

/// Ekspor/impor dataset Experiment 1 sebagai JSON.
public enum DatasetArchive {
    public static func encode(_ dataset: ExperimentDataset) throws -> Data {
        try JSONEncoder.pointingArchive().encode(dataset)
    }

    public static func decode(_ data: Data) throws -> ExperimentDataset {
        try JSONDecoder.pointingArchive().decode(ExperimentDataset.self, from: data)
    }

    /// Nama berkas dengan stempel waktu, supaya ekspor tidak saling menimpa.
    public static func suggestedFilename(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "experiment1-\(formatter.string(from: date))Z.json"
    }
}
