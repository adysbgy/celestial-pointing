import Foundation

/// Teks yang tampil & diucapkan untuk alur kalibrasi — satu sumber, teruji di
/// Linux.
///
/// **Kenapa ini ada.** `CalibrationFlow.message`, `CalibrationSession` (tiga
/// pesan kegagalan), dan `CalibrationSpeech` (label yang diucapkan) semuanya
/// **menghasilkan** kalimat Bahasa Indonesia di dalam paket. Tidak satu pun
/// kalimat itu ada di `Localizable.xcstrings`, dan tidak satu pun bisa
/// dijangkau gerbang mana pun:
///
/// - Aturan 4 menyapu literal `Apps/`, sedangkan kalimat ini lahir di
///   `Packages/PointingKit`.
/// - Aturan 6 memeriksa paritas `LocalizedText.allKeys` dengan katalog — dan
///   kalimat ini tidak pernah melewati `LocalizedText`, jadi ia tidak punya
///   kunci untuk dibandingkan.
///
/// Akibatnya seluruh alur kalibrasi tampil dan terdengar dalam Bahasa
/// Indonesia di semua bahasa, dengan setiap gerbang hijau. Ini kelas cacat
/// yang sama dengan `TextLocalization` (dibuat untuk menutupnya), tetapi
/// berkas-berkas ini tertinggal di belakang: kuncinya dulu hanya ditambahkan
/// untuk keadaan engine, tingkat keyakinan, jenis benda, fase Bulan, bentuk
/// objek langit dalam, putusan GoTo, pengumuman, dan status sensor.
///
/// **Batasnya.** Yang disediakan hanya kalimatnya; urutan dan kapan ia
/// ditampilkan tetap milik pemanggil. Angka masuk lewat `String(format:)`
/// supaya bahasa lain bisa menempatkannya di urutan berbeda.
public enum CalibrationText {

    // MARK: - Pesan tahap alur (`CalibrationFlow.message`)

    /// Belum ada acuan.
    public static var idleMessage: String {
        TextLocalization.text(.calibrationMessageIdle)
    }

    /// Sudah ada acuan, tapi belum cukup banyak.
    ///
    /// `%lld` untuk jumlah bulat: `%d` di Linux Swift membaca 32-bit dan
    /// memotong nilai `Int` 64-bit — perbedaan yang tidak terlihat sampai
    /// angkanya besar.
    public static func needMoreMessage(minimum: Int, recorded: Int) -> String {
        TextLocalization.text(.calibrationMessageNeedMore,
               Int64(minimum), Int64(recorded))
    }

    /// Sebaran sisa masih terlalu lebar.
    public static func spreadTooWideMessage(spreadDeg: Double, maxDeg: Double) -> String {
        TextLocalization.text(.calibrationMessageSpreadTooWide,
               spreadDeg, maxDeg)
    }

    /// Kalibrasi sudah layak dipakai.
    public static func readyMessage(spreadDeg: Double, sampleCount: Int) -> String {
        TextLocalization.text(.calibrationMessageReady,
               spreadDeg, Int64(sampleCount))
    }

    /// Kalibrasi sudah dipasang ke controller.
    public static var appliedMessage: String {
        TextLocalization.text(.calibrationMessageApplied)
    }

    // MARK: - Pesan kegagalan langkah (`CalibrationSession`)

    /// Sensor gerak mati: arah tunjuk yang tersisa bukan pengukuran sekarang.
    public static var sensorUnavailableMessage: String {
        TextLocalization.text(.calibrationMessageSensorUnavailable)
    }

    /// Sensor belum memberi arah tunjuk sama sekali.
    public static var noPointingMessage: String {
        TextLocalization.text(.calibrationMessageNoPointing)
    }

    /// Arah objek yang dipilih tidak bisa dihitung.
    public static func directionUncomputableMessage(objectID: String) -> String {
        TextLocalization.text(.calibrationMessageDirectionUncomputable,
               objectID)
    }

    /// Objek acuan sudah di bawah cakrawala — mencatatnya hanya menghasilkan
    /// sampel hantu yang membalik offset kalibrasi.
    public static func belowHorizonMessage(objectID: String) -> String {
        TextLocalization.text(.calibrationMessageBelowHorizon, objectID)
    }

    /// Tidak ada bintang acuan yang jelas di arah tunjuk.
    public static var noNearbyStarMessage: String {
        TextLocalization.text(.calibrationMessageNoNearbyStar)
    }

    // MARK: - Teks yang diucapkan (`CalibrationSpeech`)

    /// "Tahap: Siap dipakai."
    public static func spokenPhasePrefix(_ phase: String) -> String {
        TextLocalization.text(.calibrationSpeechPhasePrefix, phase)
    }

    /// "3 acuan tercatat."
    public static func spokenSamplesRecorded(_ count: Int) -> String {
        TextLocalization.text(.calibrationSpeechSamplesRecorded,
               Int64(count))
    }

    /// "Offset 4.2 derajat."
    public static func spokenOffset(degrees: Double) -> String {
        TextLocalization.text(.calibrationSpeechOffset, degrees)
    }

    /// "Sebaran 2.4 derajat, batas 3.0 derajat."
    public static func spokenSpread(spreadDeg: Double, maxDeg: Double) -> String {
        TextLocalization.text(.calibrationSpeechSpread,
               spreadDeg, maxDeg)
    }

    /// Label tombol "Pakai" saat kalibrasi siap.
    public static var spokenApplyReady: String {
        TextLocalization.text(.calibrationSpeechApplyReady)
    }

    /// Label tombol "Pakai" saat belum bisa dipakai — menyebut keadaannya.
    public static var spokenApplyNotReady: String {
        TextLocalization.text(.calibrationSpeechApplyNotReady)
    }

    /// "Catat Vega sebagai acuan, 40 derajat tinggi."
    public static func spokenCaptureLabel(name: String, altitudeDeg: Double) -> String {
        TextLocalization.text(.calibrationSpeechCaptureLabel,
               name, altitudeDeg)
    }

    // MARK: - Pesan status di layar kalibrasi

    /// Pesan status awal sebelum pengguna mencatat apa pun.
    public static var initialStatus: String {
        TextLocalization.text(.calibrationStatusInitial)
    }

    /// Kalibrasi dari sesi sebelumnya sudah terpasang.
    public static func alreadyInstalled(offsetDeg: Double) -> String {
        TextLocalization.text(.calibrationStatusAlreadyInstalled,
               offsetDeg)
    }

    /// Tombol "Pakai" ditekan, tapi sebarannya belum cukup sempit.
    public static var notReadyStatus: String {
        TextLocalization.text(.calibrationStatusNotReady)
    }

    /// Kalibrasi baru saja dipasang.
    public static func installed(offsetDeg: Double, spreadDeg: Double) -> String {
        TextLocalization.text(.calibrationStatusInstalled,
               offsetDeg, spreadDeg)
    }

    /// Kalibrasi dibuang.
    public static var resetStatus: String {
        TextLocalization.text(.calibrationStatusReset)
    }

    // MARK: - Angka ringkas di kartu kalibrasi (layar, bukan suara)

    /// "Offset 4.2°" — bentuk ringkas untuk kartu.
    public static func offsetDisplay(degrees: Double) -> String {
        TextLocalization.text(.calibrationDisplayOffset, degrees)
    }

    /// "Sebaran 2.4° (maks 3.0°)" — bentuk ringkas untuk kartu.
    public static func spreadDisplay(spreadDeg: Double, maxDeg: Double) -> String {
        TextLocalization.text(.calibrationDisplaySpread,
               spreadDeg, maxDeg)
    }

    /// "40° tinggi" — keterangan tinggi acuan di baris daftar acuan.
    ///
    /// **Kenapa ini ada.** Kalimatnya dulu lahir sebagai literal di dalam
    /// `String(format: "%.0f° tinggi", …)` di `CalibrationView` — bentuk yang
    /// tidak dilihat Aturan 4 (bukan argumen `Text(...)`) maupun Aturan 6
    /// (tanpa kunci). Kata "tinggi" adalah teks yang harus diterjemahkan;
    /// `°` dan angkanya tidak.
    public static func captureAltitudeDisplay(altitudeDeg: Double) -> String {
        TextLocalization.text(.calibrationDisplayCaptureAltitude,
               altitudeDeg)
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    static let calibrationMessageIdle = LocalizedText(
        key: "calibration.message.idle",
        id: "Tunjuk bintang acuan, lalu tekan untuk mencatat.")
    static let calibrationMessageNeedMore = LocalizedText(
        key: "calibration.message.needMore",
        id: "Butuh minimal %lld acuan (%lld tercatat).")
    static let calibrationMessageSpreadTooWide = LocalizedText(
        key: "calibration.message.spreadTooWide",
        id: "Sebaran %.1f° masih terlalu lebar (maks %.1f°). Tambah acuan.")
    static let calibrationMessageReady = LocalizedText(
        key: "calibration.message.ready",
        id: "Siap — sebaran %.1f° dari %lld acuan.")
    static let calibrationMessageApplied = LocalizedText(
        key: "calibration.message.applied",
        id: "Kalibrasi dipakai.")
    static let calibrationMessageSensorUnavailable = LocalizedText(
        key: "calibration.message.sensorUnavailable",
        id: "Sensor gerak tidak aktif — arah tunjuk yang tersisa bukan pengukuran sekarang. Tidak dicatat.")
    static let calibrationMessageNoPointing = LocalizedText(
        key: "calibration.message.noPointing",
        id: "Belum ada arah tunjuk dari sensor.")
    static let calibrationMessageDirectionUncomputable = LocalizedText(
        key: "calibration.message.directionUncomputable",
        id: "Arah objek %@ tidak bisa dihitung — tidak dicatat.")
    static let calibrationMessageBelowHorizon = LocalizedText(
        key: "calibration.message.belowHorizon",
        id: "%@ sudah terbenam — tidak dicatat sebagai acuan.")
    static let calibrationMessageNoNearbyStar = LocalizedText(
        key: "calibration.message.noNearbyStar",
        id: "Tidak ada bintang acuan yang jelas di arah itu — dekatkan tunjuk ke bintang terang.")

    static let calibrationSpeechPhasePrefix = LocalizedText(
        key: "calibration.speech.phasePrefix", id: "Tahap: %@.")
    static let calibrationSpeechSamplesRecorded = LocalizedText(
        key: "calibration.speech.samplesRecorded", id: "%lld acuan tercatat.")
    static let calibrationSpeechOffset = LocalizedText(
        key: "calibration.speech.offset", id: "Offset %.1f derajat.")
    static let calibrationSpeechSpread = LocalizedText(
        key: "calibration.speech.spread",
        id: "Sebaran %.1f derajat, batas %.1f derajat.")
    static let calibrationSpeechApplyReady = LocalizedText(
        key: "calibration.speech.applyReady", id: "Pakai kalibrasi ini")
    static let calibrationSpeechApplyNotReady = LocalizedText(
        key: "calibration.speech.applyNotReady",
        id: "Pakai kalibrasi, belum bisa dipakai")
    static let calibrationSpeechCaptureLabel = LocalizedText(
        key: "calibration.speech.captureLabel",
        id: "Catat %@ sebagai acuan, %.0f derajat tinggi.")

    static let calibrationStatusInitial = LocalizedText(
        key: "calibration.status.initial",
        id: "Tunjuk bintang acuan, lalu tekan Catat.")
    static let calibrationStatusAlreadyInstalled = LocalizedText(
        key: "calibration.status.alreadyInstalled",
        id: "Kalibrasi sudah terpasang: offset %.1f°.")
    static let calibrationStatusNotReady = LocalizedText(
        key: "calibration.status.notReady",
        id: "Belum siap dipakai: sebarannya masih terlalu lebar.")
    static let calibrationStatusInstalled = LocalizedText(
        key: "calibration.status.installed",
        id: "Terpasang. Offset %.1f°, sebaran %.1f°.")
    static let calibrationStatusReset = LocalizedText(
        key: "calibration.status.reset",
        id: "Kalibrasi dihapus. Mulai dari awal.")

    /// Keterangan ambang keyakinan yang **diusulkan** engine, di bawah daftar
    /// acuan.
    ///
    /// Bentuk "%@: σ %.1f°" — kata pengantar, lalu lambang sigma di dalam slot
    /// `%@`, lalu sudut. Sigma bukan "kata" yang bisa diucapkan, jadi ia
    /// dibiarkan sebagai lambang; yang boleh berubah lewat terjemahan adalah
    /// kata pengantar dan satuan, bukan lambangnya.
    static let calibrationDisplaySuggestedSigma = LocalizedText(
        key: "calibration.display.suggestedSigma",
        id: "Ambang keyakinan usulan: σ %.1f°")

    static let calibrationDisplayOffset = LocalizedText(
        key: "calibration.display.offset", id: "Offset %.1f°")
    static let calibrationDisplaySpread = LocalizedText(
        key: "calibration.display.spread", id: "Sebaran %.1f° (maks %.1f°)")

    /// Keterangan tinggi acuan di baris daftar acuan (`CalibrationView`).
    /// Dulu literal `String(format: "%.0f° tinggi", …)` — kata "tinggi"
    /// tampil dalam Bahasa Indonesia di semua bahasa tanpa ada yang melihat.
    static let calibrationDisplayCaptureAltitude = LocalizedText(
        key: "calibration.display.captureAltitude", id: "%.0f° tinggi")

    // Nama tahap. Dipakai untuk layar (`phaseLabel` di view) **dan** suara
    // (`spokenName`); keduanya dulu literal di tempat berbeda, jadi satu
    // perubahan bisa membuat layar dan suara menyebut tahap yang berbeda.
    static let calibrationPhaseIdleLabel = LocalizedText(
        key: "calibration.phase.idle.label", id: "Belum ada acuan")
    static let calibrationPhaseCollectingLabel = LocalizedText(
        key: "calibration.phase.collecting.label", id: "Mengumpulkan acuan")
    static let calibrationPhaseReadyLabel = LocalizedText(
        key: "calibration.phase.ready.label", id: "Siap dipakai")
    static let calibrationPhaseAppliedLabel = LocalizedText(
        key: "calibration.phase.applied.label", id: "Sudah dipakai")
}
