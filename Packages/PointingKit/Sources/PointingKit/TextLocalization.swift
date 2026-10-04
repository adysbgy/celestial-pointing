import Foundation

/// Satu teks yang destined ke layar, bersama **kunci katalognya**.
///
/// **Kenapa berkas ini ada.** Label yang paling sering dibaca sekilas di app ini
/// justru **yang paling sulit dilokalisasi**: "Siap", "Arahkan", "Terkunci", dan
/// kalimat panduannya tidak pernah melewati `Text("literal")` — semuanya
/// **dihasilkan** di `PointingKit`. Akibatnya `Localizable.xcstrings` tidak
/// bisa menjangkau mereka, dan aturan 4 di `./swift-ui-lint.sh` (yang menyapu
/// literal di `Apps/`) melaporkan **hijau** sementara separuh teks yang
/// benar-benar tampil di layar belum punya padanan bahasa Inggris.
///
/// Itu persis bentuk "hijau yang tidak hijau" yang sudah dua kali muncul di
/// repo ini: gerbang berjalan, gerbang itu benar, dan yang diukur bukan
/// bagian yang bermasalah.
///
/// Yang diperbaiki bukan "tambah kunci", tapi **cara teks sampai ke katalog**:
/// teks tidak lagi memakai string Bahasa Indonesia sebagai identitasnya.
/// Identitasnya adalah kunci yang stabil, dan Bahasa Indonesia menjadi
/// **nilai bawaan** — bukan nama kunci.
/// Sengaja **tidak** conforms ke `RawRepresentable`, meskipun nama
///anggotanya `rawValue`. Konformansi itu menuntut `init?(rawValue:)` yang
/// harus mengembalikan `nil` untuk kunci yang tak dikenal — dan initsiator itu
/// tidak ada pemanggilnya di seluruh repo. Deklarasikannya sempat ada karena
/// "kunci = data mentah"; konformansinya gagal karena Swift tidak mengarang
/// initsiator untuk struct dengan penyimpanan tambahan, dan pesannya hanya
/// menyebut `LocalizedText` tanpa menyebut baris yang salah. Jadi konformansi
/// dibuang, bukan diberi supaya dipoles.
public struct LocalizedText: Hashable, Sendable {

    /// Kunci katalog, mis. `"pointing.state.lock.label"`.
    ///
    /// Sengaja memakai **namespace**, bukan teks Bahasa Indonesia. Alasannya
    /// konkrit: `"Kalibrasi"` sudah ada di katalog sebagai **judul layar
    /// kalibrasi**, sementara `LinkMessageKind.calibrationReady` juga
    /// menghasilkan kalimat "Kalibrasi" untuk hal yang berbeda. Kalau teksnya
    /// sendiri yang jadi kunci, keduanya menyatu diam-diam — mengubah satu
    /// ikut mengubah yang lain, dan tidak ada yang memberi tahu.
    public let rawValue: String

    /// Teks Bahasa Indonesia — nilai bawaan saat katalog tidak punya
    /// terjemahan.
    ///
    /// Ini bukan gaya: `sourceLanguage` proyek adalah `id`, dan paket ini
    /// **dipakai di Linux**, tempat `Bundle.main` tidak punya `.lproj` sama
    /// sekali (`localizations == []`). Tanpa nilai bawaan di dalam tipe,
    /// seluruh uji Linux akan menguji string kosong.
    public let indonesian: String

    public init(key: String, id: String) {
        self.rawValue = key
        self.indonesian = id
    }
}

/// Sumber terjemahan untuk `LocalizedText`.
///
/// **Kenapa tidak memakai `String(localized:)` langsung.** API itu tidak ada
/// di Swift 6.0 Linux — hanya `Bundle.localizedString(forKey:value:table:)`,
/// yang di sini selalu mengembalikan nilai bawaan. Paket ini harus tetap bisa
/// diuji di Linux, jadi **pencarian dipisah dari tempat jenis teksnya
/// ditentukan**: enum ini tidak tahu apa pun tentang `Bundle`, dan pemasangannya
/// dilakukan oleh app.
public enum TextLocalization {

    /// Fungsi pencarian: menerima kunci katalog, mengembalikan teks pada
    /// bahasa aktif, atau `nil` bila tidak ada terjemahannya.
    public typealias Lookup = @Sendable (String) -> String?

    private static let lock = NSLock()
    nonisolated(unsafe) private static var installed: Lookup?

    /// Daftarkan sumber terjemahan (dari app: `Bundle.localizedString`).
    ///
    /// Aman dipanggil lebih dari sekali; pemanggilan terakhir menang. Sengaja
    /// **tidak** ada yang dipasang di dalam paket: tanpa app, Bahasa
    /// Indonesia tetap benar — dan itulah yang diuji di Linux.
    public static func install(_ lookup: @escaping Lookup) {
        lock.lock()
        defer { lock.unlock() }
        installed = lookup
    }

    /// Melepas sumber terjemahan.
    ///
    /// Bukan untuk pemakaian app — untuk uji, supaya satu pengujian yang
    /// memasang `Lookup` tidak bocor ke pengujian berikutnya. Bocornya
    /// akan terlihat sebagai "katalog terpasang sendiri", bukan sebagai
    /// kegagalan — persis kelas kesalahpahaman yang gerbang ini hunts.
    public static func reset() {
        lock.lock()
        defer { lock.unlock() }
        installed = nil
    }

    private static var lookup: Lookup? {
        lock.lock()
        defer { lock.unlock() }
        return installed
    }

    /// Teks untuk ditampilkan, dalam bahasa aktif.
    ///
    /// **Kontrak: tidak pernah kosong, dan tidak pernah nama kunci.**
    /// Tiga kemungkinan diperiksa berurutan:
    ///
    /// 1. Terjemahan ditemukan, tidak kosong, **dan bukan nama kuncinya
    ///    sendiri** -> dipakai.
    /// 2. Selain itu -> nilai bawaan Bahasa Indonesia; dan kalau **tetap**
    ///    kosong (kunci hastily dideklarasikan tanpa teks), teks kuncinya
    ///    sendiri yang dikembalikan. String kosong membuat baris terlihat
    ///    kosong tanpa penjelasan, sedangkan kunci mentah setidaknya jujur
    ///    menyatakan "ini pengenal, bukan teks".
    ///
    /// **Kenapa syarat "bukan nama kuncinya sendiri" itu ada.** Sumber
    /// terjemahan dari app adalah `Bundle.localizedString(forKey:value:)`,
    /// dan fungsi itu **tidak pernah mengembalikan `nil` maupun string
    /// kosong**: kalau kuncinya tidak ada di katalog, hasilnya persis
    /// `value` yang diberikan. Karena bridge itu memberikan `value: key`
    /// (pola yang benar sendiri — string kosong akan membuat baris terlihat
    /// kosong tanpa penjelasan), kunci yang hilang sampai ke sini sebagai
    /// **teks yang salah**, bukan sebagai ketiadaan. Dipakai apa adanya, ia
    /// menampakkan pengenal mentah di layar: bukannya "Terkunci" yang
    /// tampil, melainkan `pointing.state.lock.label`.
    ///
    /// Kalau ini tidak dijaga, teorinya "label yang paling sering dibaca
    /// sekilas punya terjemahan" tetap benar sementara **layar**nya salah —
    /// dan tidak ada satu pun gerbang yang bisa melihatnya: aturan 4 menyapu
    /// literal `Apps/`, sedangkan teks ini di-*switch* di dalam paket.
    ///
    /// Syaratnya aman karena kunci dijaga ber-namespace tanpa spasi (bukti:
    /// `testDeclaredKeysAreUniqueNonEmptyAndComplete`), jadi tidak mungkin
    /// sama dengan kalimat terjemahan yang sah.
    public static func text(_ key: LocalizedText) -> String {
        if let found = lookup?(key.rawValue),
           !found.isEmpty,
           found != key.rawValue {
            return found
        }
        return key.indonesian.isEmpty ? key.rawValue : key.indonesian
    }
}

// MARK: - Katalog kunci

/// Kunci + nilai bawaan untuk setiap teks yang **dihasilkan** di paket.
///
/// Daftar ini adalah satu-satunya tempat yang tahu bentuk katalognya, sehingga
/// aturan 6 di `./swift-ui-lint.sh` bisa memverifikasi **paritas** dengan
/// `Localizable.xcstrings` — kesenjangan yang tidak bisa ditutup dengan menyapu
/// `Apps/` saja.
public extension LocalizedText {

    // MARK: Keadaan engine (label jam + kalimat panduan)

    static let stateIdleLabel = LocalizedText(key: "pointing.state.idle.label",
                                              id: "Siap")
    static let statePointingLabel = LocalizedText(key: "pointing.state.pointing.label",
                                                  id: "Arahkan")
    static let stateSearchingLabel = LocalizedText(key: "pointing.state.searching.label",
                                                   id: "Mencari")
    static let stateLockLabel = LocalizedText(key: "pointing.state.lock.label",
                                              id: "Terkunci")
    static let stateUncertainLabel = LocalizedText(key: "pointing.state.uncertain.label",
                                                   id: "Kurang yakin")
    static let stateUnavailableLabel = LocalizedText(key: "pointing.state.unavailable.label",
                                                     id: "Sensor mati")

    static let stateIdleGuidance = LocalizedText(
        key: "pointing.state.idle.guidance",
        id: "Angkat jam dan arahkan ke langit.")
    static let statePointingGuidance = LocalizedText(
        key: "pointing.state.pointing.guidance",
        id: "Tahan arah tunjuk sampai jam berhenti bergerak.")
    static let stateSearchingGuidance = LocalizedText(
        key: "pointing.state.searching.guidance",
        id: "Belum ada objek di arah itu.")
    static let stateLockGuidance = LocalizedText(
        key: "pointing.state.lock.guidance",
        id: "Objek dikenali dengan keyakinan tinggi.")
    static let stateUncertainGuidance = LocalizedText(
        key: "pointing.state.uncertain.guidance",
        id: "Ada kandidat, tapi belum cukup yakin untuk memastikan.")
    static let stateUnavailableGuidance = LocalizedText(
        key: "pointing.state.unavailable.guidance",
        id: "Jam tidak memberi data gerak. Coba lagi.")

    // MARK: Tingkat keyakinan

    static let levelHigh = LocalizedText(key: "confidence.level.high.label", id: "Yakin")
    static let levelMedium = LocalizedText(key: "confidence.level.medium.label", id: "Ragu")
    static let levelLow = LocalizedText(key: "confidence.level.low.label",
                                        id: "Tidak tahu")

    // MARK: Jenis pesan (jam <-> iPhone)

    static let linkKindPointingState = LocalizedText(key: "link.kind.pointingState.label",
                                                      id: "Keadaan")
    static let linkKindCalibrationReady = LocalizedText(
        key: "link.kind.calibrationReady.label", id: "Kalibrasi")
    static let linkKindPolicyUpdate = LocalizedText(key: "link.kind.policyUpdate.label",
                                                    id: "Ambang keyakinan")
    static let linkKindStateRequest = LocalizedText(key: "link.kind.stateRequest.label",
                                                    id: "Permintaan keadaan")
    static let linkKindAcknowledgement = LocalizedText(
        key: "link.kind.acknowledgement.label", id: "Tanda terima")

    /// Setiap kunci yang dideklarasikan di sini.
    ///
    /// Satu sumber untuk gerbang paritas dan untuk uji — supaya "kunci yang
    /// dideklarasikan tapi tidak punya entri katalog" tidak bisa lolos tanpa
    /// ada yang melihatnya.
    static let allKeys: [LocalizedText] = [
        .stateIdleLabel, .statePointingLabel, .stateSearchingLabel,
        .stateLockLabel, .stateUncertainLabel, .stateUnavailableLabel,
        .stateIdleGuidance, .statePointingGuidance, .stateSearchingGuidance,
        .stateLockGuidance, .stateUncertainGuidance, .stateUnavailableGuidance,
        .levelHigh, .levelMedium, .levelLow,
        .linkKindPointingState, .linkKindCalibrationReady, .linkKindPolicyUpdate,
        .linkKindStateRequest, .linkKindAcknowledgement,
        // Label jenis benda: nama tampilan maupun pengucapan. Keduanya
        // masuk daftar karena keduanya tampil di layar, dan keduanya dulu
        // hidup di `Apps/Shared/ObjectKindLabels.swift` — berkas yang tidak
        // bisa dijangkau satu pun gerbang (lihat komentar berkas itu).
        .kindStarLabel, .kindPlanetLabel, .kindMoonLabel,
        .kindSunLabel, .kindDeepSkyLabel,
        .kindStarSpoken, .kindPlanetSpoken, .kindMoonSpoken,
        .kindSunSpoken, .kindDeepSkySpoken,
        // Nama fase Bulan. Masuk daftar karena inilah **satu-satunya** jalur
        // fase sampai ke pengguna VoiceOver: gambar prosedural menampilkan
        // bentuknya, dan tanpa kunci ini yang terdengar hanya "Bulan" — sama
        // untuk purnama maupun sabit tipis. Lihat `MoonPhaseSpeech.swift`.
        .moonPhaseNew, .moonPhaseFull, .moonPhaseCrescent,
        .moonPhaseWaxingCrescent, .moonPhaseWaningCrescent,
        .moonPhaseGibbous, .moonPhaseWaxingGibbous, .moonPhaseWaningGibbous,
        .moonPhaseQuarter, .moonPhaseFirstQuarter, .moonPhaseLastQuarter,
        // Alasan "mengapa tidak ada objek". Masuk daftar karena inilah
        // satu-satunya jalur alasan penolakan engine sampai ke layar:
        // `Resolution.rejected` sudah lama dihitung dan tidak pernah dibaca.
        // Lihat `SearchHint.swift`.
        .searchHintDaylight, .searchHintBelowHorizon, .searchHintTooFaint,
        .searchHintTooCloseToSun, .searchHintNoCandidates,
        // Bentuk objek langit dalam. Masuk daftar karena inilah satu-satunya
        // jalur bentuk sampai ke pengguna VoiceOver: gambar prosedural
        // menampilkan cakram galaksi vs inti padat gugus bola, dan tanpa kunci
        // ini "Gugus Ptolemy" dan "Gugus Hercules" terdengar sama persis.
        // Lihat `DeepSkySpeech.swift`.
        .deepSkyMorphologyNebula, .deepSkyMorphologyGalaxy,
        .deepSkyMorphologyOpenCluster, .deepSkyMorphologyGlobularCluster,
        // Putusan GoTo. Masuk daftar karena inilah satu-satunya jalur putusan
        // keselamatan sampai ke layar: `SlewPlanner` sudah menghitungnya sejak
        // FASE 3, tetapi `slewDecision` nol konsumen di `Apps/`. Tanpa kunci
        // ini, penolakan karena Matahari (melindungi alat & mata) tidak bisa
        // dibedakan dari penolakan karena keyakinan rendah. Lihat
        // `SlewVerdict.swift`.
        .slewVerdictRejectedPrefix,
        .slewHazardSunProximity, .slewHazardBelowAltitudeLimit,
        .slewHazardBelowHorizon, .slewHazardTooFaint, .slewHazardNoTarget,
        .slewHazardLowConfidence, .slewHazardSunPositionUnknown,
        // Kalimat pengumuman VoiceOver saat keadaan berubah. Masuk daftar
        // karena inilah satu-satunya jalur perubahan keadaan sampai ke
        // pengguna yang tidak melihat layar — dan karena versi lamanya hidup
        // sebagai literal di dalam `PointingView`, tempat katalog tidak bisa
        // menjangkaunya. Lihat `StateAnnouncement.swift`.
        .announceLockedOn, .announceLocked, .announceUncertain,
        .announceUnavailable, .announceState,
        // Frasa pengumuman panel objek. Masuk daftar karena inilah satu-satunya
        // jalur magnitudo, tingkat keyakinan, koordinat, dan penanda "sisa"
        // sampai ke pengguna VoiceOver — dan karena versi lamanya hidup
        // sebagai literal yang disusun lewat `String(format:)` di dalam dua
        // view, tempat katalog tidak bisa menjangkaunya. Lihat
        // `ObjectSpeech.swift`.
        .objectSpeechMagnitude, .objectSpeechStale,
        .objectSpeechConfidence, .objectSpeechCoordinates,
        // Status sensor & izin. Masuk daftar karena inilah satu-satunya jalur
        // pesan "izin ditolak" dan "sensor tidak tersedia" sampai ke layar —
        // dan karena versi lamanya hidup sebagai literal yang ditugaskan ke
        // properti (`note = "…"`) di tiga berkas `Apps/Shared/`, tempat katalog
        // tidak bisa menjangkaunya. Lihat `SensorStatusText.swift`.
        .sensorMotionMissing, .sensorMotionUnavailable,
        .sensorLocationNotRequested, .sensorLocationSearching,
        .sensorLocationWaiting, .sensorLocationDeniedStatus,
        .sensorLocationUnknownStatus, .sensorLocationDeniedNote,
        .sensorLocationAccuracy, .sensorLocationFailedStatus,
        .sensorLocationFailedNote,
        // Alur kalibrasi. Masuk daftar karena inilah satu-satunya jalur
        // pesan tahap, pesan kegagalan, label yang diucapkan, dan angka kartu
        // kalibrasi sampai ke pengguna — dan karena versi lamanya hidup
        // sebagai literal di dalam `Packages/PointingKit` (`CalibrationFlow`,
        // `CalibrationSession`, `CalibrationSpeech`) serta sebagai literal
        // yang ditugaskan ke `statusMessage` di dalam view. Aturan 4 tidak
        // menjangkau paket, dan Aturan 6 tidak melihat literal tanpa kunci,
        // jadi seluruh alur kalibrasi tampil dalam Bahasa Indonesia di semua
        // bahasa dengan setiap gerbang hijau. Lihat `CalibrationText.swift`.
        .calibrationMessageIdle, .calibrationMessageNeedMore,
        .calibrationMessageSpreadTooWide, .calibrationMessageReady,
        .calibrationMessageApplied, .calibrationMessageSensorUnavailable,
        .calibrationMessageNoPointing, .calibrationMessageDirectionUncomputable,
        .calibrationMessageNoNearbyStar,
        .calibrationSpeechPhasePrefix, .calibrationSpeechSamplesRecorded,
        .calibrationSpeechOffset, .calibrationSpeechSpread,
        .calibrationSpeechApplyReady, .calibrationSpeechApplyNotReady,
        .calibrationSpeechCaptureLabel,
        .calibrationStatusInitial, .calibrationStatusAlreadyInstalled,
        .calibrationStatusNotReady, .calibrationStatusInstalled,
        .calibrationStatusReset,
        .calibrationDisplayOffset, .calibrationDisplaySpread,
        .calibrationPhaseIdleLabel, .calibrationPhaseCollectingLabel,
        .calibrationPhaseReadyLabel, .calibrationPhaseAppliedLabel,
        // Experiment 1. Masuk daftar karena inilah satu-satunya jalur pesan
        // status recorder, kata putusan, baris detail, ringkasan alat ukur,
        // dan diagnosis sampai ke pengguna — dan karena versi lamanya lahir
        // sebagai literal di dalam `Packages/PointingKit`
        // (`ExperimentHarness.verdict`, `ConfidenceTrace.diagnosis`) atau
        // dirakit lebih dulu ke sebuah `String` di dalam view
        // (`statusMessage = "…\(…)…"`), tempat tidak ada argumen langsung
        // untuk disapu Aturan 4 dan tidak ada kunci untuk diperiksa Aturan 6.
        // Lihat `ExperimentText.swift`.
        .experimentStatusInitial, .experimentStatusNoTarget,
        .experimentStatusSensorOff, .experimentStatusNoPointing,
        .experimentStatusTargetUncomputable, .experimentStatusRecorded,
        .experimentStatusRemoved, .experimentStatusNothingToRemove,
        .experimentStatusReset,
        .experimentVerdictFalseLock, .experimentVerdictCorrect,
        .experimentVerdictWrong, .experimentVerdictNotAnalyzed,
        .experimentVerdictFalseLockSentence, .experimentVerdictCorrectSentence,
        .experimentVerdictWrongSentence, .experimentVerdictNotAnalyzedSentence,
        .experimentDetailNoAnswer, .experimentDetailNoError,
        .experimentDetailAnswer, .experimentDetailConfidence,
        .experimentDetailState, .experimentDetailError, .experimentDetailRate,
        .experimentTargetOption,
        .experimentSummaryNoAnalyzable, .experimentSummaryFailed,
        .experimentSummaryInsufficient, .experimentSummaryPassed,
        .experimentDiagnosisNoSamples, .experimentDiagnosisNoAnswers,
        .experimentDiagnosisTooFar, .experimentDiagnosisAmbiguous,
        .experimentDiagnosisNoMeasurableCause, .experimentDiagnosisRatio,
        .experimentSuggestedThreshold,
        .experimentLocationFallback, .experimentLocationComputed,
    ]
}