import Foundation

/// Satu percobaan pointing yang direkam — bahan mentah Experiment 1.
///
/// PRD v0.4: akurasi Watch adalah **hipotesis yang harus diuji**, bukan
/// asumsi. Karena itu setiap percobaan menyimpan apa yang benar-benar
/// terjadi: apa yang ditunjuk, apa yang dijawab engine, dan apa yang
/// sebenarnya ada di langit. Dari sini kita bisa menghitung galat tunjuk
/// yang sesungguhnya, bukan menebaknya.
public struct PointingTrial: Codable, Equatable, Sendable {
    /// Waktu tunjuk (UTC). Dipakai untuk menghitung posisi benda langit.
    public var timestamp: Date
    /// Lokasi pengamat saat tunjuk.
    public var observer: Observer
    /// Arah tunjuk mentah yang dikirim Watch, SEBELUM koreksi apa pun.
    public var rawPointing: HorizontalCoord
    /// Arah tunjuk setelah kalibrasi (kalau ada). `nil` = belum dikalibrasi.
    public var calibratedPointing: HorizontalCoord?
    /// Yang dijawab engine.
    public var intent: CelestialIntent
    /// Objek yang sebenarnya dituju manusia (diisi saat analisis).
    /// `nil` = belum dilabeli.
    public var groundTruthObjectID: String?
    /// Catatan bebas: kondisi langit, apa yang dipakai penguji, dsb.
    public var note: String?

    public init(timestamp: Date, observer: Observer, rawPointing: HorizontalCoord,
                calibratedPointing: HorizontalCoord?, intent: CelestialIntent,
                groundTruthObjectID: String? = nil, note: String? = nil) {
        self.timestamp = timestamp
        self.observer = observer
        self.rawPointing = rawPointing
        self.calibratedPointing = calibratedPointing
        self.intent = intent
        self.groundTruthObjectID = groundTruthObjectID
        self.note = note
    }
}

/// Hasil analisis satu percobaan.
///
/// Angka-angka ini yang menjawab pertanyaan riset: seberapa akurat pointing
/// Watch, dan berapa sering engine salah?
public struct TrialAnalysis: Codable, Equatable, Sendable {
    /// Galat sudut antara arah tunjuk mentah dan arah sebenarnya objek.
    /// Inilah "akurasi Watch" yang selama ini diasumsikan — sekarang diukur.
    public var rawPointingErrorDeg: Double
    /// Sama, tapi setelah kalibrasi (kalau ada).
    public var calibratedPointingErrorDeg: Double?
    /// Apakah engine menebak objek yang benar.
    public var isCorrect: Bool
    /// Tingkat keyakinan yang dilaporkan engine untuk tebakannya.
    public var reportedLevel: ConfidenceLevel
    /// `true` bila engine yakin tinggi TAPI tebakannya salah.
    ///
    /// Ini mode kegagalan paling berbahaya — "false lock". Engine yang
    /// jujur ragu masih berguna; engine yang yakin tapi salah merusak
    /// kepercayaan. Target: angka ini nol.
    public var isFalseLock: Bool

    public init(rawPointingErrorDeg: Double, calibratedPointingErrorDeg: Double?,
                isCorrect: Bool, reportedLevel: ConfidenceLevel, isFalseLock: Bool) {
        self.rawPointingErrorDeg = rawPointingErrorDeg
        self.calibratedPointingErrorDeg = calibratedPointingErrorDeg
        self.isCorrect = isCorrect
        self.reportedLevel = reportedLevel
        self.isFalseLock = isFalseLock
    }
}

/// Rekaman percobaan Experiment 1, plus analisisnya.
public enum ObservationLog {

    /// Analisis satu percobaan terhadap kebenaran yang diketahui.
    ///
    /// - Parameter truthDirection: arah horizontal objek yang sebenarnya
    ///   dituju. Kalau `groundTruthObjectID` tidak ada, panggil dengan `nil`.
    public static func analyze(
        _ trial: PointingTrial,
        truthDirection: HorizontalCoord?
    ) -> TrialAnalysis? {
        guard let truth = truthDirection,
              let truthID = trial.groundTruthObjectID else { return nil }

        let rawError = SkyMath.angularSeparationHorizontalDeg(trial.rawPointing, truth)
        let calError = trial.calibratedPointing.map {
            SkyMath.angularSeparationHorizontalDeg($0, truth)
        }

        let isCorrect = trial.intent.best?.id == truthID
        // False lock = yakin tinggi tapi salah. Sengaja TIDAK menghitung
        // MEDIUM sebagai false lock: engine yang ragu bukanlah kebohongan.
        let isFalseLock = (trial.intent.level == .high) && !isCorrect

        return TrialAnalysis(
            rawPointingErrorDeg: rawError,
            calibratedPointingErrorDeg: calError,
            isCorrect: isCorrect,
            reportedLevel: trial.intent.level,
            isFalseLock: isFalseLock
        )
    }

    /// Ringkasan sekumpulan percobaan — inti jawaban Experiment 1.
    public static func summarize(_ analyses: [TrialAnalysis]) -> ExperimentSummary {
        ExperimentSummary(analyses: analyses)
    }
}

/// Ringkasan statistik Experiment 1.
public struct ExperimentSummary: Codable, Equatable, Sendable {
    public var trialCount: Int
    public var correctCount: Int
    public var falseLockCount: Int
    /// Median galat tunjuk mentah (lebih tahan outlier daripada mean).
    public var medianRawPointingErrorDeg: Double?
    /// Persentil ke-90 galat tunjuk — "seberapa buruk di kasus terburuk".
    public var p90RawPointingErrorDeg: Double?

    public init(analyses: [TrialAnalysis]) {
        self.trialCount = analyses.count
        self.correctCount = analyses.filter(\.isCorrect).count
        self.falseLockCount = analyses.filter(\.isFalseLock).count

        let errors = analyses.map(\.rawPointingErrorDeg).sorted()
        self.medianRawPointingErrorDeg = Self.percentile(errors, 0.5)
        self.p90RawPointingErrorDeg = Self.percentile(errors, 0.9)
    }

    /// Persentil dengan interpolasi linear. Mengembalikan `nil` bila kosong.
    static func percentile(_ sorted: [Double], _ q: Double) -> Double? {
        guard !sorted.isEmpty else { return nil }
        guard sorted.count > 1 else { return sorted[0] }
        let pos = q * Double(sorted.count - 1)
        let lower = Int(pos.rounded(.down))
        let upper = Int(pos.rounded(.up))
        if lower == upper { return sorted[lower] }
        let frac = pos - Double(lower)
        return sorted[lower] + frac * (sorted[upper] - sorted[lower])
    }

    /// Akurasi sebagai pecahan 0...1. `nil` bila belum ada percobaan.
    public var accuracy: Double? {
        guard trialCount > 0 else { return nil }
        return Double(correctCount) / Double(trialCount)
    }

    /// Kriteria lulus Experiment 1: tidak ada false lock sama sekali.
    /// Ini ambang mutlak dari PRD, bukan target yang bisa ditawar.
    public var passesSafetyCriterion: Bool { falseLockCount == 0 }
}

/// Ekspor/impor dataset percobaan sebagai JSON.
///
/// Dipakai untuk memindahkan rekaman dari Watch/iPhone ke mesin analisis.
public enum TrialArchive {
    public static func encode(_ trials: [PointingTrial]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(trials)
    }

    public static func decode(_ data: Data) throws -> [PointingTrial] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PointingTrial].self, from: data)
    }
}
