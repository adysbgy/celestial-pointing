import Foundation

/// Teks yang tampil & diucapkan untuk Experiment 1 — satu sumber, teruji di
/// Linux.
///
/// **Kenapa ini ada.** Experiment 1 adalah alat ukur repo ini sendiri: ia
/// merekam percobaan, menghitung galat, dan memutuskan apakah ambang keyakinan
/// cukup ketat. Nyaris seluruh kalimat yang dilaporkannya lahir sebagai literal
/// Bahasa Indonesia di dalam `Packages/PointingKit` (`ExperimentHarness.verdict`,
/// `ConfidenceTrace.diagnosis`) atau dirakit lebih dulu di dalam view
/// (`statusMessage = "…\(…)…"`, `parts.append("jawab \(…)")`).
///
/// Tidak satu pun bisa dijangkau gerbang:
///
/// - Aturan 4 menyapu literal `Text("…")` di `Apps/` — sedangkan kalimat ini
///   lahir di paket, atau dirakit ke sebuah `String` sebelum ditampilkan, jadi
///   tidak ada argumen langsung untuk dilihat.
/// - Aturan 6 memeriksa paritas `LocalizedText.allKeys` dengan katalog — dan
///   kalimat ini tidak pernah melewati `LocalizedText`.
///
/// Akibatnya laporan alat ukur — termasuk putusan "GAGAL" dan "belum bisa
/// disimpulkan" yang justru paling penting dibaca jujur — tampil dalam Bahasa
/// Indonesia di semua bahasa, dengan setiap gerbang hijau. Ini kelas cacat yang
/// sama dengan `SensorStatusText`, `ObjectSpeech`, dan `CalibrationText`.
///
/// **Batasnya.** Yang disediakan hanya kalimatnya; urutan dan kapan ia
/// ditampilkan tetap milik pemanggil. Angka masuk lewat `String(format:)`
/// supaya bahasa lain bisa menempatkannya di urutan berbeda.
public enum ExperimentText {

    // MARK: - Pesan status recorder

    /// Pesan awal sebelum penguji memilih target.
    public static var statusInitial: String {
        TextLocalization.text(.experimentStatusInitial)
    }

    /// Rekam ditekan tanpa memilih target.
    public static var statusNoTarget: String {
        TextLocalization.text(.experimentStatusNoTarget)
    }

    /// Sensor gerak mati: arah tunjuk yang tersisa bukan pengukuran sekarang.
    ///
    /// Alat ukur tidak boleh mengarang data — ini sebabnya rekaman ditolak,
    /// bukan sekadar peringatan.
    public static var statusSensorOff: String {
        TextLocalization.text(.experimentStatusSensorOff)
    }

    /// Sensor belum memberi arah tunjuk sama sekali.
    public static var statusNoPointing: String {
        TextLocalization.text(.experimentStatusNoPointing)
    }

    /// Arah target yang dipilih tidak bisa dihitung.
    public static func statusTargetUncomputable(targetID: String) -> String {
        String(format: TextLocalization.text(.experimentStatusTargetUncomputable),
               targetID)
    }

    /// Satu percobaan tersimpan.
    ///
    /// - Parameter error: galat dalam bentuk tampilan (mis. `"1.2°"`, atau
    ///   `"—"` bila tidak ada analisis).
    /// - Parameter verdict: kata putusan (`FALSE LOCK`/`benar`/`salah`).
    /// - Parameter answer: nama objek jawaban engine, atau `statusNoAnswer`.
    public static func statusRecorded(error: String,
                                      verdict: String,
                                      answer: String) -> String {
        String(format: TextLocalization.text(.experimentStatusRecorded),
               error, verdict, answer)
    }

    /// Percobaan terakhir dibuang.
    public static func statusRemoved(objectID: String) -> String {
        String(format: TextLocalization.text(.experimentStatusRemoved), objectID)
    }

    /// Tidak ada percobaan yang bisa dibuang.
    public static var statusNothingToRemove: String {
        TextLocalization.text(.experimentStatusNothingToRemove)
    }

    /// Seluruh dataset dikosongkan.
    public static var statusReset: String {
        TextLocalization.text(.experimentStatusReset)
    }

    // MARK: - Kata putusan (dipakai layar **dan** suara)

    /// `FALSE LOCK` — sengaja huruf besar: inilah satu-satunya hasil di layar
    /// ini yang wajib terdengar berbeda dari sekadar "salah".
    public static var verdictFalseLock: String {
        TextLocalization.text(.experimentVerdictFalseLock)
    }

    public static var verdictCorrect: String {
        TextLocalization.text(.experimentVerdictCorrect)
    }

    public static var verdictWrong: String {
        TextLocalization.text(.experimentVerdictWrong)
    }

    /// `tak dianalisis` — bentuk pendek di baris daftar.
    public static var verdictNotAnalyzed: String {
        TextLocalization.text(.experimentVerdictNotAnalyzed)
    }

    // Bentuk kalimat untuk diucapkan. Dipisah dari bentuk pendek di atas
    // karena satu sumber angka harus bisa tampil dan terdengar berbeda tanpa
    // dua tempat menyimpan teksnya.

    public static var verdictFalseLockSentence: String {
        TextLocalization.text(.experimentVerdictFalseLockSentence)
    }

    public static var verdictCorrectSentence: String {
        TextLocalization.text(.experimentVerdictCorrectSentence)
    }

    public static var verdictWrongSentence: String {
        TextLocalization.text(.experimentVerdictWrongSentence)
    }

    public static var verdictNotAnalyzedSentence: String {
        TextLocalization.text(.experimentVerdictNotAnalyzedSentence)
    }

    // MARK: - Baris detail percobaan

    /// Kata pengganti nama objek saat engine belum menjawab.
    public static var detailNoAnswer: String {
        TextLocalization.text(.experimentDetailNoAnswer)
    }

    /// Kata pengganti galat saat tidak ada analisis.
    public static var detailNoError: String {
        TextLocalization.text(.experimentDetailNoError)
    }

    public static func detailAnswer(_ name: String) -> String {
        String(format: TextLocalization.text(.experimentDetailAnswer), name)
    }

    public static func detailConfidence(_ level: String) -> String {
        String(format: TextLocalization.text(.experimentDetailConfidence), level)
    }

    public static func detailState(_ state: String) -> String {
        String(format: TextLocalization.text(.experimentDetailState), state)
    }

    /// Galat dalam bentuk tampilan, dengan presisi yang mengikuti tampilan.
    public static func detailError(degrees: Double) -> String {
        String(format: TextLocalization.text(.experimentDetailError), degrees)
    }

    /// Laju pergelangan dalam bentuk tampilan (simbol `/dtk`).
    public static func detailRate(degPerSec: Double) -> String {
        String(format: TextLocalization.text(.experimentDetailRate), degPerSec)
    }

    /// Opsi di pemilih target: `"Vega · 42°"`.
    public static func targetOption(name: String, altitudeDeg: Double) -> String {
        String(format: TextLocalization.text(.experimentTargetOption),
               name, altitudeDeg)
    }

    // MARK: - Ringkasan (`ExperimentHarness.verdict`)

    /// Belum ada percobaan yang bisa dianalisis.
    public static var summaryNoAnalyzable: String {
        TextLocalization.text(.experimentSummaryNoAnalyzable)
    }

    /// Ada false lock — engine yakin tapi salah. Ambang harus diperketat.
    public static func summaryFailed(falseLockCount: Int,
                                     accuracy: String,
                                     median: String,
                                     p90: String) -> String {
        String(format: TextLocalization.text(.experimentSummaryFailed),
               Int64(falseLockCount), accuracy, median, p90)
    }

    /// Nol false lock, tapi sampel belum cukup untuk menyebut "lulus".
    ///
    /// Jangan ucapkan "lulus": yang diketahui cuma "belum ketemu".
    public static func summaryInsufficient(trialCount: Int,
                                           minimum: Int,
                                           accuracy: String,
                                           median: String,
                                           p90: String) -> String {
        String(format: TextLocalization.text(.experimentSummaryInsufficient),
               Int64(trialCount), Int64(minimum), accuracy, median, p90)
    }

    /// Sampel cukup dan tidak ada false lock.
    public static func summaryPassed(trialCount: Int,
                                     accuracy: String,
                                     median: String,
                                     p90: String) -> String {
        String(format: TextLocalization.text(.experimentSummaryPassed),
               Int64(trialCount), accuracy, median, p90)
    }

    // MARK: - Diagnosis (`ConfidenceTrace.diagnosis`)

    public static var diagnosisNoSamples: String {
        TextLocalization.text(.experimentDiagnosisNoSamples)
    }

    public static var diagnosisNoAnswers: String {
        TextLocalization.text(.experimentDiagnosisNoAnswers)
    }

    public static var diagnosisTooFar: String {
        TextLocalization.text(.experimentDiagnosisTooFar)
    }

    public static var diagnosisAmbiguous: String {
        TextLocalization.text(.experimentDiagnosisAmbiguous)
    }

    public static var diagnosisNoMeasurableCause: String {
        TextLocalization.text(.experimentDiagnosisNoMeasurableCause)
    }

    /// Rasio jawaban yakin.
    ///
    /// `%lld` untuk dua jumlah bulat: `%d` di Linux Swift membaca 32-bit dan
    /// memotong nilai `Int` 64-bit.
    public static func diagnosisRatio(locks: Int, uncertain: Int) -> String {
        let total = locks + uncertain
        let ratio = total > 0 ? Double(locks) / Double(total) : 0
        return String(format: TextLocalization.text(.experimentDiagnosisRatio),
                      ratio * 100, Int64(locks), Int64(uncertain))
    }

    // MARK: - Layar

    /// Usulan ambang keyakinan dari sigma terukur.
    public static func suggestedThreshold(sigmaDeg: Double) -> String {
        String(format: TextLocalization.text(.experimentSuggestedThreshold),
               sigmaDeg)
    }

    /// Peringatan bahwa lokasi masih bawaan.
    ///
    /// Kalau lokasi belum didapat, seluruh daftar target dihitung untuk tempat
    /// lain — tinggi objeknya salah. Itu harus terlihat, bukan tersembunyi di
    /// balik daftar yang tampak normal.
    public static func locationFallbackWarning(label: String) -> String {
        String(format: TextLocalization.text(.experimentLocationFallback),
               label)
    }

    /// Keterangan lokasi tempat tinggi objek dihitung.
    public static func locationComputed(label: String) -> String {
        String(format: TextLocalization.text(.experimentLocationComputed), label)
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    static let experimentStatusInitial = LocalizedText(
        key: "experiment.status.initial",
        id: "Pilih target, arahkan, lalu rekam.")
    static let experimentStatusNoTarget = LocalizedText(
        key: "experiment.status.noTarget",
        id: "Pilih target dulu — tanpa kebenaran, rekaman tidak bisa dianalisis.")
    static let experimentStatusSensorOff = LocalizedText(
        key: "experiment.status.sensorOff",
        id: "Sensor gerak tidak aktif — arah tunjuk yang tersisa bukan pengukuran sekarang. Tidak ada yang direkam.")
    static let experimentStatusNoPointing = LocalizedText(
        key: "experiment.status.noPointing",
        id: "Belum ada arah tunjuk dari sensor — tidak ada yang direkam.")
    static let experimentStatusTargetUncomputable = LocalizedText(
        key: "experiment.status.targetUncomputable",
        id: "Arah target %@ tidak bisa dihitung — percobaan tidak disimpan.")
    static let experimentStatusRecorded = LocalizedText(
        key: "experiment.status.recorded",
        id: "Tercatat: galat %@, %@. Jawaban engine: %@.")
    static let experimentStatusRemoved = LocalizedText(
        key: "experiment.status.removed",
        id: "Dibuang: %@.")
    static let experimentStatusNothingToRemove = LocalizedText(
        key: "experiment.status.nothingToRemove",
        id: "Tidak ada percobaan untuk dibuang.")
    static let experimentStatusReset = LocalizedText(
        key: "experiment.status.reset",
        id: "Dataset dikosongkan.")

    static let experimentVerdictFalseLock = LocalizedText(
        key: "experiment.verdict.falseLock", id: "FALSE LOCK")
    static let experimentVerdictCorrect = LocalizedText(
        key: "experiment.verdict.correct", id: "benar")
    static let experimentVerdictWrong = LocalizedText(
        key: "experiment.verdict.wrong", id: "salah")
    static let experimentVerdictNotAnalyzed = LocalizedText(
        key: "experiment.verdict.notAnalyzed", id: "tak dianalisis")
    static let experimentVerdictFalseLockSentence = LocalizedText(
        key: "experiment.verdict.falseLock.sentence",
        id: "False lock: engine yakin tapi salah.")
    static let experimentVerdictCorrectSentence = LocalizedText(
        key: "experiment.verdict.correct.sentence", id: "Benar.")
    static let experimentVerdictWrongSentence = LocalizedText(
        key: "experiment.verdict.wrong.sentence", id: "Salah.")
    static let experimentVerdictNotAnalyzedSentence = LocalizedText(
        key: "experiment.verdict.notAnalyzed.sentence", id: "Tidak dianalisis.")

    static let experimentDetailNoAnswer = LocalizedText(
        key: "experiment.detail.noAnswer", id: "belum ada")
    static let experimentDetailNoError = LocalizedText(
        key: "experiment.detail.noError", id: "—")
    static let experimentDetailAnswer = LocalizedText(
        key: "experiment.detail.answer", id: "jawab %@")
    static let experimentDetailConfidence = LocalizedText(
        key: "experiment.detail.confidence", id: "keyakinan %@")
    static let experimentDetailState = LocalizedText(
        key: "experiment.detail.state", id: "keadaan %@")
    static let experimentDetailError = LocalizedText(
        key: "experiment.detail.error", id: "galat %.1f°")
    static let experimentDetailRate = LocalizedText(
        key: "experiment.detail.rate", id: "%.0f°/dtk")
    static let experimentTargetOption = LocalizedText(
        key: "experiment.target.option", id: "%@ · %.0f°")

    static let experimentSummaryNoAnalyzable = LocalizedText(
        key: "experiment.summary.noAnalyzable",
        id: "Belum ada percobaan yang bisa dianalisis.")
    static let experimentSummaryFailed = LocalizedText(
        key: "experiment.summary.failed",
        id: "GAGAL: %lld false lock — engine yakin tapi salah. Ambang keyakinan harus diperketat. Akurasi %@, galat median %@, P90 %@.")
    static let experimentSummaryInsufficient = LocalizedText(
        key: "experiment.summary.insufficient",
        id: "Belum bisa disimpulkan: 0 false lock dari %lld percobaan — sampel belum cukup (butuh minimal %lld). Akurasi %@, galat tunjuk median %@, P90 %@. Ini bukan bukti aman, hanya belum ada bukti sebaliknya.")
    static let experimentSummaryPassed = LocalizedText(
        key: "experiment.summary.passed",
        id: "Lulus syarat keselamatan (0 false lock dari %lld percobaan). Akurasi %@, galat tunjuk median %@, P90 %@.")

    static let experimentDiagnosisNoSamples = LocalizedText(
        key: "experiment.diagnosis.noSamples", id: "Belum ada sampel.")
    static let experimentDiagnosisNoAnswers = LocalizedText(
        key: "experiment.diagnosis.noAnswers",
        id: "Belum ada jawaban sama sekali. Arahkan ke langit dan tahan sampai pergelangan diam.")
    static let experimentDiagnosisTooFar = LocalizedText(
        key: "experiment.diagnosis.tooFar",
        id: "Semua jawaban ragu karena kandidat terlalu jauh dari arah tunjuk. Perbaiki kalibrasi dulu.")
    static let experimentDiagnosisAmbiguous = LocalizedText(
        key: "experiment.diagnosis.ambiguous",
        id: "Semua jawaban ragu karena ada dua kandidat berdekatan. Ini keterbatasan akurasi, bukan kesalahan kalibrasi.")
    static let experimentDiagnosisNoMeasurableCause = LocalizedText(
        key: "experiment.diagnosis.noMeasurableCause",
        id: "Jawaban ragu tanpa sebab terukur — periksa apakah arah tunjuk masuk akal.")
    static let experimentDiagnosisRatio = LocalizedText(
        key: "experiment.diagnosis.ratio",
        id: "%.0f%% jawaban yakin (%lld yakin, %lld ragu).")

    static let experimentSuggestedThreshold = LocalizedText(
        key: "experiment.suggestedThreshold",
        id: "Usulan ambang keyakinan: σ %.1f°")

    // Kalau lokasinya masih bawaan, seluruh daftar target dihitung untuk
    // tempat lain — tinggi objeknya salah. Kalimat itu harus terlihat, jadi ia
    // harus punya kunci; kalau tidak, pengguna Bahasa Inggris membaca Bahasa
    // Indonesia tanpa satu pun gerbang merah.
    static let experimentLocationFallback = LocalizedText(
        key: "experiment.location.fallback",
        id: "Lokasi belum didapat — tinggi di bawah dihitung untuk %@, bukan tempat Anda.")
    static let experimentLocationComputed = LocalizedText(
        key: "experiment.location.computed",
        id: "Dihitung untuk %@.")
}
