import CelestialEngine

/// Putusan keselamatan Experiment 1, dipisah dari ringkasan statistiknya.
///
/// **Kenapa ini bukan sekadar `passesSafetyCriterion`.**
/// `ExperimentSummary.passesSafetyCriterion` hanya bertanya "ada false lock?"
/// dan menjawab `falseLockCount == 0`. Jawaban itu **benar**, tapi sebagai
/// *kalimat* ia bohong: nol false lock dari satu percobaan sama saja dengan
/// nol false lock dari nol percobaan — tidak ada bukti apa pun di baliknya.
///
/// Gagal dan lulus **tidak simetris**, dan menyamakannya adalah bentuk lain
/// dari "yakin padahal belum tahu":
/// - Untuk **menggagalkan** klaim "engine tidak pernah yakin-salah", satu
///   contoh tandingan saja sudah cukup. Satu false lock = gagal, titik. Ukuran
///   sampel tidak relevan di sini; yang dibutuhkan cuma satu saksi.
/// - Untuk **menyatakan lulus**, tidak ada contoh tandingan yang bisa
///   ditunjukkan — yang ada hanya "belum ketemu". Ketidakhadiran bukti bukan
///   bukti ketidakhadiran. Butuh sampel yang cukup besar sebelum "belum
///   pernah" boleh dibaca sebagai "aman".
///
/// PRD v0.4: *uncertainty > false confidence*. Karena itu ambang di bawah ini
/// punya dasar yang bisa dipertanggungjawabkan, bukan angka bulat yang dipilih
/// supaya enak dilihat (lihat `minimumTrialsForSafetyClaim`).
public extension ExperimentSummary {

    /// Jumlah percobaan minimum sebelum "lulus" boleh diucapkan.
    ///
    /// **Dari mana angka 20.** Bila 0 false lock teramati dari N percobaan,
    /// batas atas satu-sisi 95% untuk laju false lock adalah ≈ 3/N — inilah
    /// *rule of three*. Untuk boleh mengklaim laju false lock di bawah ~15%
    /// (batas keselamatan yang masih layak dipercaya untuk alat bantu tunjuk),
    /// dibutuhkan 3/0,15 = 20 percobaan. Di bawah itu, "0 false lock" masih
    /// cocok dengan laju kegagalan yang jauh lebih tinggi daripada yang ingin
    /// diklaim alat ini.
    ///
    /// Angka ini **bukan** target yang harus dikejar penguji; ia hanya
    /// ambang bicara. Mengumpulkan lebih sedikit data tetap sah — yang tidak
    /// sah adalah menyebutnya "lulus".
    static let minimumTrialsForSafetyClaim = 20

    /// Apakah sampel sudah cukup besar untuk menopang klaim lulus.
    var hasEnoughEvidenceForSafetyClaim: Bool {
        trialCount >= Self.minimumTrialsForSafetyClaim
    }

    /// Tiga keadaan, bukan dua.
    enum SafetyVerdict: Equatable, Sendable {
        /// Ada false lock: satu contoh tandingan sudah cukup untuk gagal.
        case failed
        /// Nol false lock, tapi sampelnya terlalu kecil untuk menyimpulkan
        /// apa pun. Inilah keadaan yang paling mudah disalahartikan sebagai
        /// "lulus" — dan justru karena itu ia diberi nama sendiri.
        case insufficientEvidence
        /// Nol false lock dari sampel yang cukup besar.
        case passed

        /// Apakah ini klaim "lulus" yang benar-benar boleh diucapkan.
        public var isPassedClaim: Bool { self == .passed }

        /// Nada visual putusan ini.
        ///
        /// Dipisahkan dari `passesSafetyCriterion` supaya layar tidak bisa
        /// mewarnai "belum cukup bukti" dengan hijau sukses. Sebelumnya
        /// `Experiment1View` mewarnai kalimat putusan dari
        /// `passesSafetyCriterion` — yang bernilai `true` bahkan untuk satu
        /// percobaan bersih, sehingga keraguan tampil sebagai keyakinan.
        public var tone: PointingTone {
            switch self {
            case .failed: return .danger
            case .insufficientEvidence: return .warning
            case .passed: return .success
            }
        }
    }

    var safetyVerdict: SafetyVerdict {
        // Urutan penting: gagal diperiksa lebih dulu. Satu false lock
        // menggagalkan klaim meskipun sampelnya masih kecil.
        if falseLockCount > 0 { return .failed }
        return hasEnoughEvidenceForSafetyClaim ? .passed : .insufficientEvidence
    }
}
