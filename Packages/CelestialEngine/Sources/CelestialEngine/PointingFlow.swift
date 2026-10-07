import Foundation

/// Keadaan alur pointing yang ditampilkan ke pengguna.
///
/// Urutannya sengaja memisahkan "sedang menunjuk" dari "sudah stabil" dan
/// "sudah ada jawaban". Engine tidak boleh melompat langsung ke `lock` hanya
/// karena ada kandidat — ia harus menunggu pergelangan benar-benar diam.
public enum PointingState: String, Equatable, Codable, Sendable {
    /// Belum ada data sensor.
    case idle
    /// Sensor ada, tetapi pergelangan masih bergerak.
    case pointing
    /// Sudah cukup stabil, hasil sedang dicari / belum ada kandidat.
    case searching
    /// Ada kandidat dan engine yakin tinggi.
    case lock
    /// Ada kandidat tetapi engine tidak cukup yakin — tampilkan sebagai ragu.
    case uncertain
    /// Sensor tidak tersedia; engine menolak menebak.
    case unavailable

    /// Apakah ada jawaban yang ditampilkan (yakin atau ragu).
    public var hasAnswer: Bool { self == .lock || self == .uncertain }
}

/// Ambang alur pointing. Bisa dikalibrasi lewat Experiment 1.
public struct PointingPolicy: Equatable, Sendable {
    /// Di atas laju ini (derajat/detik) pergelangan dianggap masih bergerak.
    public var maxAngularRateDegPerSec: Double
    /// Lama pergelangan harus diam sebelum hasil boleh dicari (detik).
    public var maxHoldSeconds: Double
    /// Jeda minimum antar resolusi (detik). Mencegah resolusi tiap frame.
    public var searchIntervalSeconds: Double

    public init(maxAngularRateDegPerSec: Double = 8.0,
                maxHoldSeconds: Double = 0.4,
                searchIntervalSeconds: Double = 0.25) {
        self.maxAngularRateDegPerSec = maxAngularRateDegPerSec
        self.maxHoldSeconds = maxHoldSeconds
        self.searchIntervalSeconds = searchIntervalSeconds
    }
}

/// Mesin keadaan alur pointing: idle → pointing → searching → lock/uncertain.
///
/// Prinsip yang dipegang (PRD): engine hanya menjawab setelah arah tunjuk
/// stabil, dan **selalu** membedakan "yakin" dari "ragu". Karena itu `lock`
/// hanya diberikan untuk `ConfidenceLevel.high`; keyakinan medium/low menjadi
/// `uncertain`, bukan dipaksa menjadi jawaban pasti.
///
/// Mesin ini murni logika — tidak menyentuh CoreMotion, tidak menyentuh UI.
/// Sumber resolusi disuntikkan sebagai closure supaya bisa diuji di Linux.
public struct PointingStateMachine: Sendable {
    public var policy: PointingPolicy
    /// Apakah sensor tersedia. Bila `false`, engine menolak menebak.
    public var isSensorAvailable: Bool

    public private(set) var state: PointingState = .idle
    public private(set) var currentIntent: CelestialIntent?
    /// Kecepatan sudut terakhir (derajat/detik), `nil` bila belum terukur.
    public var angularRateDegPerSec: Double? { rateTracker.angularRateDegPerSec }

    /// Orientasi perangkat **mentah** dari sampel terakhir, sebelum perataan.
    ///
    /// Disimpan supaya Experiment 1 bisa mengarsipkan attitude mentah tiap
    /// percobaan (bidang Lampiran A). Tanpa ini, `rawPointing` yang sudah
    /// diolah tidak bisa dibalik: satu-satunya cara menganalisis ulang rekaman
    /// dengan kalibrasi/konvensi sumbu berbeda adalah dari quaternion aslinya.
    /// Direset saat alur berhenti, karena itu orientasi dari alur yang sudah
    /// tidak berlaku lagi.
    public private(set) var lastRawQuaternion: Quaternion?

    private var rateTracker = AngularRateTracker()
    private var stableSince: Date?
    private var lastResolution: Date?

    public init(policy: PointingPolicy = PointingPolicy(),
                isSensorAvailable: Bool = true) {
        self.policy = policy
        self.isSensorAvailable = isSensorAvailable
    }

    /// Masukkan satu sampel sensor.
    ///
    /// - Parameters:
    ///   - quaternion: orientasi perangkat mentah (belum teredam).
    ///   - pointing: arah tunjuk horizontal yang sudah dikalibrasi.
    ///   - timestamp: waktu sampel.
    ///   - resolve: cara mendapatkan `CelestialIntent` untuk satu arah tunjuk.
    ///     Dipanggil paling sering setiap `policy.searchIntervalSeconds`.
    /// - Returns: keadaan terbaru.
    @discardableResult
    public mutating func update(quaternion: Quaternion,
                                pointing: HorizontalCoord,
                                timestamp: Date,
                                resolve: (HorizontalCoord) -> CelestialIntent) -> PointingState {
        guard isSensorAvailable else {
            stableSince = nil
            state = .unavailable
            return state
        }

        let rate = rateTracker.update(quaternion, at: timestamp)
        // Simpan attitude mentah untuk arsip Experiment 1 (Lampiran A). Ditaruh
        // sebelum penyaring apa pun supaya yang tersimpan benar-benar nilai
        // sensor, bukan hasil olahan.
        lastRawQuaternion = quaternion
        // Laju `nil` (sampel pertama atau ada jeda) diperlakukan sebagai
        // "masih bergerak" — arah aman: jangan mengunci tanpa bukti diam.
        let moving = rate.map { $0 > policy.maxAngularRateDegPerSec } ?? true

        if moving {
            stableSince = nil
            state = .pointing
            return state
        }

        if stableSince == nil { stableSince = timestamp }
        guard let since = stableSince,
              timestamp.timeIntervalSince(since) >= policy.maxHoldSeconds else {
            state = .pointing
            return state
        }

        if lastResolution == nil
            || timestamp.timeIntervalSince(lastResolution!) >= policy.searchIntervalSeconds {
            currentIntent = resolve(pointing)
            lastResolution = timestamp
        }

        guard let intent = currentIntent, intent.best != nil else {
            state = .searching
            return state
        }
        state = intent.level == .high ? .lock : .uncertain
        return state
    }

    /// Hentikan alur (mis. layar pergi). Kembali ke `idle`, lupakan riwayat.
    public mutating func stop() {
        rateTracker.reset()
        stableSince = nil
        lastResolution = nil
        currentIntent = nil
        lastRawQuaternion = nil
        state = .idle
    }
}
