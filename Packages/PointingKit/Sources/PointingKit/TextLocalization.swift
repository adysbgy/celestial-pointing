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

    /// Bentuk berformat dari kunci katalog.
    ///
    /// **Kenapa butuh overload terpisah, bukan `String(format: text(key), …)`
    /// di tiap pemanggil.** Setelah katalog diterjemahkan, terjemahan boleh
    /// memuat `%lld` di tempat berbeda dari aslinya — bahasa Carthaginian
    /// (gramatikal nomor dua) punya bentuk berbeda untuk "3 messages failed"
    /// dan "1 message failed", dan bentuk itu harus datang dari katalog. Yang
    /// memanggil overload ini hanya menyerahkan kunci dan nilai; **urutan
    /// argumennya milik terjemahan**, bukan milik pemanggil.
    ///
    /// Kalau katalog tidak punya terjemahan, format dijalankan terhadap nilai
    /// Indonesia — bukan terhadap kunci, yang akan membuat `%` dicetak apa
    /// adanya dan menutupi slot.
    ///
    /// **Kenapa `locale:` wajib di sini, dan bukan opsional.** Tanpa
    /// `locale:`, `String(format:)` memakai locale proses, dan pemisah
    /// desimal ikut ikut: pembaca Bahasa Indonesia melihat `Offset 4.2°`
    /// untuk nilai yang ia baca sebagai `4,2°` — sepuluh kali lebih besar.
    /// Angka tidak boleh jadi satu-satunya bagian layar yang berbicara
    /// bahasa berbeda dari teksnya, jadi pemisah desimalnya ikut bahasa yang
    /// membaca katalog, sama seperti katanya.
    ///
    /// Bahasanya datang dari `NumberFormat`, bukan `Locale.current`, supaya
    /// teks dan angka tidak bisa berbeda pendapat: bridge yang memasang
    /// katalog juga yang memasang pemisah angka.
    public static func text(_ key: LocalizedText, _ arguments: CVarArg...) -> String {
        String(format: text(key),
               locale: Locale(identifier: NumberFormat.activeLocaleId),
               arguments: arguments)
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

    /// Penanda ragu untuk complication — **satu kata**, bukan kalimat.
    ///
    /// **Kenapa kata khusus, bukan `levelMedium`.** `confidence.level.medium.label`
    /// ("Ragu") sudah dipakai sebagai badge di app jam dan iPhone, jadi memakainya
    /// lagi di complication terdengar benar: satu istilah untuk satu konsep.
    ///
    /// Tapi di complication konteksnya hilang — tidak ada teks "tingkat keyakinan"
    /// di sampingnya yang memberi tahu **tentang apa** kata itu. "Ragu" sendirian
    /// pernah berarti "ragu apakah sedang mengukur" (itulah makna aslinya di
    /// layar utama saat `state == .searching`). Kunci terpisah supaya
    /// penerjemah punya konteks, dan nilainya sedikit lebih eksplisit.
    ///
    /// **Batasnya yang jujur: ruangnya satu baris.** Di `.accessoryInline` dan
    /// `.accessoryCircular` kata ini **tidak muncul** — di sana penanda ragu
    /// dibawa ikon keadaan (`questionmark.circle`). Menambahkannya di sana akan
    /// memotong nama objek, dan nama objek adalah informasinya.
    static let confidenceUncertainMarker = LocalizedText(
        key: "confidence.uncertain.marker",
        id: "Belum pasti")

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

    // MARK: Layar perkenalan (onboarding value-first)

    /// Judul kartu perkenalan: ajakan menunjuk ke langit.
    static let onboardingTitle = LocalizedText(key: "onboarding.title",
                                               id: "Arahkan jam ke langit")
    /// Subjudul: apa yang didapat setelah menunjuk.
    static let onboardingSubtitle = LocalizedText(
        key: "onboarding.subtitle",
        id: "Tunjuk sebuah benda, dan ketahui apa yang sedang kamu lihat — bersama seberapa yakin engine mengenalinya.")
    /// Janji produk: ketidak-pastian ditampilkan apa adanya, bukan disembunyi.
    static let onboardingHonesty = LocalizedText(
        key: "onboarding.honesty",
        id: "Jika ragu, engine akan mengatakannya. Tidak ada yang diklaim sebagai pasti bila belum.")
    /// Label tombol penutup kartu.
    static let onboardingStart = LocalizedText(key: "onboarding.start.label",
                                               id: "Mulai")
    /// Label VoiceOver kartu utuh: merangkum ketiga baris teks.
    static let onboardingLabel = LocalizedText(
        key: "onboarding.label",
        id: "Perkenalan. Arahkan jam ke langit untuk mengetahui benda yang kamu lihat. Jika ragu, engine akan mengatakannya.")

    // MARK: Layar kalibrasi (label layar & tombol)

    static let calibrationTitle = LocalizedText(key: "calibration.title",
                                                 id: "Kalibrasi")
    static let calibrationSamplesRecorded = LocalizedText(
        key: "calibration.samplesRecorded", id: "%lld acuan tercatat")
    static let calibrationNotStarted = LocalizedText(
        key: "calibration.notStarted", id: "Kalibrasi belum dimulai.")
    static let calibrationReferenceHeading = LocalizedText(
        key: "calibration.referenceHeading", id: "Acuan di atas horizon")
    static let calibrationNoVisibleReference = LocalizedText(
        key: "calibration.noVisibleReference",
        id: "Tidak ada acuan yang terlihat sekarang. Acuan bawaan adalah bintang terang; tunggu sampai salah satunya terbit.")
    static let calibrationCaptureNearestLabel = LocalizedText(
        key: "calibration.captureNearest.label", id: "Catat yang ditunjuk")
    static let calibrationCaptureNearestHint = LocalizedText(
        key: "calibration.captureNearest.hint",
        id: "Catat yang sedang ditunjuk sebagai acuan")
    static let calibrationApplyLabel = LocalizedText(key: "calibration.apply.label",
                                                      id: "Pakai")
    static let calibrationApplyNotReadyHint = LocalizedText(
        key: "calibration.apply.notReadyHint",
        id: "Pakai kalibrasi, belum bisa dipakai")
    static let calibrationResetLabel = LocalizedText(key: "calibration.reset.label",
                                                      id: "Ulang")
    static let calibrationResetHint = LocalizedText(
        key: "calibration.reset.hint", id: "Ulangi kalibrasi dari awal")
    static let calibrationStatusPrefix = LocalizedText(
        key: "calibration.statusPrefix", id: "Status: %@")
    static let calibrationStatusAppliedShort = LocalizedText(
        key: "calibration.status.appliedShort", id: "Sudah")
    static let calibrationStatusNotAppliedShort = LocalizedText(
        key: "calibration.status.notAppliedShort", id: "Belum")

    // MARK: Layar tautan iOS↔jam (`LinkView`)

    static let linkSectionTitle = LocalizedText(
        key: "link.sectionTitle", id: "Tautan")
    static let linkRowStatus = LocalizedText(key: "link.row.status", id: "Status")
    static let linkValueActive = LocalizedText(key: "link.value.active", id: "Aktif")
    static let linkValueInactive = LocalizedText(
        key: "link.value.inactive", id: "Belum aktif")
    static let linkRowReachable = LocalizedText(key: "link.row.reachable", id: "Terjangkau")
    static let linkValueYes = LocalizedText(key: "link.value.yes", id: "Ya")
    static let linkValueNo = LocalizedText(key: "link.value.no", id: "Tidak")
    static let linkRowMessagesReceived = LocalizedText(
        key: "link.row.messagesReceived", id: "Pesan diterima")
    static let linkRequestState = LocalizedText(
        key: "link.requestState", id: "Minta keadaan terakhir")
    static let linkSectionLastState = LocalizedText(
        key: "link.section.lastState", id: "Keadaan terakhir dari jam")
    static let linkRowState = LocalizedText(key: "link.row.state", id: "Keadaan")
    static let linkRowObject = LocalizedText(key: "link.row.object", id: "Objek")
    static let linkRowConfidence = LocalizedText(
        key: "link.row.confidence", id: "Keyakinan")
    static let linkRowRate = LocalizedText(key: "link.row.rate", id: "Laju")
    static let linkRowTime = LocalizedText(key: "link.row.time", id: "Waktu")
    static let linkNoStateYet = LocalizedText(
        key: "link.empty.noState", id: "Belum ada keadaan dari jam.")
    static let linkSectionLastCalibration = LocalizedText(
        key: "link.section.lastCalibration", id: "Kalibrasi terakhir dari jam")
    static let linkRowYawOffset = LocalizedText(key: "link.row.yawOffset", id: "Offset yaw")
    static let linkRowSpread = LocalizedText(key: "link.row.spread", id: "Sebaran")
    static let linkRowReferenceCount = LocalizedText(
        key: "link.row.referenceCount", id: "Jumlah acuan")
    static let linkNoCalibrationYet = LocalizedText(
        key: "link.empty.noCalibration", id: "Jam belum melaporkan kalibrasi.")
    static let linkSectionSamples = LocalizedText(
        key: "link.section.samples", id: "Sampel dari jam")
    static let linkRowRecorded = LocalizedText(key: "link.row.recorded", id: "Terekam")
    static let linkSamplesNote = LocalizedText(
        key: "link.note.samples",
        id: "Sampel dari jam tidak membawa jarak kandidat, jadi rasionya terhadap σ kosong. Yang bisa dilihat dari sini adalah keadaan dan keyakinan yang dilaporkan jam.")
    static let linkSigmaMissingNote = LocalizedText(
        key: "link.note.sigmaMissing",
        id: "Sebagian sampel tidak menyertakan σ. Sigma yang tidak terukur ditulis 0, bukan angka bawaan — jangan dibaca sebagai akurasi sempurna.")

    // MARK: Layar utama (PointingView) & konteks langit

    static let pointingTitle = LocalizedText(key: "pointing.title",
                                             id: "Point & Know")
    static let pointingSkyContextLabel = LocalizedText(
        key: "pointing.skyContext.label", id: "Konteks langit dan ketelitian")
    static let pointingCalibrationInstalled = LocalizedText(
        key: "pointing.calibration.installed", id: "Kalibrasi, sudah terpasang")
    static let pointingCalibrationNotInstalled = LocalizedText(
        key: "pointing.calibration.notInstalled", id: "Kalibrasi, belum terpasang")
    static let pointingNightModeOn = LocalizedText(
        key: "pointing.nightMode.on", id: "Nonaktifkan Mode Malam")
    static let pointingNightModeOff = LocalizedText(
        key: "pointing.nightMode.off", id: "Aktifkan Mode Malam")
    static let pointingAudioCueOn = LocalizedText(
        key: "pointing.audioCue.on", id: "Nonaktifkan bunyi saat kunci")
    static let pointingAudioCueOff = LocalizedText(
        key: "pointing.audioCue.off", id: "Aktifkan bunyi saat kunci")
    static let pointingLinkConnected = LocalizedText(
        key: "pointing.link.connected", id: "iPhone terhubung")
    static let pointingLinkDisconnected = LocalizedText(
        key: "pointing.link.disconnected", id: "iPhone tidak terjangkau")
    static let pointingLinkFailures = LocalizedText(
        key: "pointing.link.failures", id: "· %lld gagal")
    static let objectDetailStaleNoteDisplay = LocalizedText(
        key: "objectDetail.staleNote.display",
        id: "Sisa pandangan sebelumnya — bukan hasil sekarang")
    static let pointingLocationFallbackPrefix = LocalizedText(
        key: "pointing.locationFallback", id: "Lokasi: %@")
    static let skyContextDark = LocalizedText(key: "skyContext.dark", id: "Gelap")
    static let skyContextLight = LocalizedText(key: "skyContext.light", id: "Terang")
    /// Judul baris **kegelapan langit** — nama barisnya, bukan nilainya.
    ///
    /// **Kenapa ini ada.** Judul baris ini dulu memakai `skyContextDark`
    /// ("Gelap") — yang jelas adalah *nilai*-nya, bukan namanya. Baris itu
    /// karena itu terbaca **"Gelap: Gelap"** (atau "Gelap: Terang"), dan tidak
    /// pernah menyebut apa yang sedang diukur. Ironisnya katalognya sudah
    /// menyebut peran yang benar di komentar kunci itu sendiri ("Nilai baris
    /// kegelapan langit"), tapi view memakai kunci yang salah — dan tidak ada
    /// gerbang yang bisa melihatnya: Aturan 4 hanya menuntut **adanya** kunci,
    /// Aturan 6 hanya menuntut **paritas**, keduanya hijau. Yang menutup kelas
    /// ini adalah Aturan 22: judul dan nilai satu baris `row` tidak boleh
    /// berasal dari kunci yang sama.
    static let skyContextSkyLabel = LocalizedText(
        key: "skyContext.skyLabel", id: "Langit")
    static let skyContextSun = LocalizedText(key: "skyContext.sun", id: "Matahari")
    static let skyContextMoon = LocalizedText(key: "skyContext.moon", id: "Bulan")
    static let skyContextMoonPhase = LocalizedText(
        key: "skyContext.moonPhase", id: "Fase Bulan")
    static let skyContextSection = LocalizedText(
        key: "skyContext.section", id: "Ketelitian")
    static let skyContextCalibration = LocalizedText(
        key: "skyContext.calibration", id: "Kalibrasi")
    static let skyContextAzimuth = LocalizedText(
        key: "skyContext.azimuth", id: "Azimut")
    static let skyContextAltitude = LocalizedText(
        key: "skyContext.altitude", id: "Ketinggian")
    static let skyContextLocation = LocalizedText(
        key: "skyContext.location", id: "Lokasi")
    static let skyContextLocationSource = LocalizedText(
        key: "skyContext.locationSource", id: "Asal lokasi")
    // Label asal lokasi. Masuk daftar karena baris "Asal lokasi" menampilkan
    // `ObserverLocation.source` **apa adanya** — pengenal mesin
    // (`corelocation`, `fallback`) di baris yang ditulis untuk menjawab
    // "langit ini dihitung untuk mana?". Kelas cacat yang sama dengan `sirius`
    // di headline Experiment 1: nilai untuk mesin tersaji sebagai teks untuk
    // orang, dan Aturan 4 tidak melihatnya karena ia bukan argumen `Text`.
    // Lihat `ObserverLocation.sourceDisplayName`.
    static let locationSourceCoreLocation = LocalizedText(
        key: "location.source.corelocation", id: "GPS perangkat")
    static let locationSourceFallback = LocalizedText(
        key: "location.source.fallback", id: "Bawaan (bukan lokasimu)")
    static let locationSourceManual = LocalizedText(
        key: "location.source.manual", id: "Dimasukkan sendiri")
    static let locationSourceSimulator = LocalizedText(
        key: "location.source.simulator", id: "Simulator")
    static let locationSourceUnknown = LocalizedText(
        key: "location.source.unknown", id: "Tidak diketahui (%@)")
    static let skyContextNotComputed = LocalizedText(
        key: "skyContext.notComputed", id: "Konteks langit belum dihitung.")

    // MARK: Ringkasan verbal grafik keyakinan (VoiceOver)

    /// "%lld sampel terukur." — jumlah yang punya jarak kandidat.
    static let chartSpeechMeasuredCount = LocalizedText(
        key: "chart.speech.measured", id: "%lld sampel terukur.")
    /// "%lld yakin" — di bawah atau tepat pada batas yakin.
    static let chartSpeechBandConfident = LocalizedText(
        key: "chart.speech.band.confident", id: "%lld yakin,")
    /// "%lld di antara dua batas" — melewati batas yakin, belum melewati batas jauh.
    static let chartSpeechBandMiddle = LocalizedText(
        key: "chart.speech.band.middle", id: "%lld di antara dua batas,")
    /// "%lld terlalu jauh" — melewati batas jauh.
    static let chartSpeechBandTooFar = LocalizedText(
        key: "chart.speech.band.tooFar", id: "%lld terlalu jauh.")
    /// "%lld tanpa jarak terukur" — hanya diucapkan kalau jumlahnya bukan nol.
    static let chartSpeechUnmeasuredCount = LocalizedText(
        key: "chart.speech.unmeasured", id: "%lld tanpa jarak terukur.")

    /// Tidak ada yang bisa dikatakan dari grafik.
    ///
    /// **Bukan string kosong, dan itu penting.** `.accessibilityLabel(_:)` hanya
    /// menerima `String` non-opsional, jadi ketiadaan harus diterjemahkan
    /// menjadi sesuatu. Memakai `""` berarti pembaca layar menemukan satu
    /// elemen yang sudah "terbaca" tapi tidak bermakna — lebih buruk daripada
    /// tidak ada pengumuman, karena keduanya berbeda rasa. Kalimat ini
    /// sekaligus mengulang pesan yang sudah terlihat di layar pada cabang
    /// "sampel ada, tapi belum ada jarak terukur", jadi suara dan mata
    /// menyebut hal yang sama.
    static let chartSpeechNothingMeasured = LocalizedText(
        key: "chart.speech.nothingMeasured",
        id: "Belum ada jarak kandidat yang terukur.")

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
        // Penanda ragu untuk complication. Masuk daftar karena ia tampil di layar
        // — dan karena Aturan 6 memeriksa dua arah, kunci yang ada di katalog
        // tapi tidak dideklarasikan akan ketahuan juga.
        .confidenceUncertainMarker,
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
        .deepSkyMorphologyNebula, .deepSkyMorphologyPlanetaryNebula,
        .deepSkyMorphologyGalaxy,
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
        // Bentuk **layar** dari tiga hal yang sama dengan bentuk suaranya.
        // Semuanya lahir sebagai literal `String(format:)` / `parts.append(…)`
        // di dalam view — bentuk yang tidak dilihat Aturan 4 (bukan argumen
        // `Text`) maupun Aturan 6 (tanpa kunci), dan yang tidak terlihat salah
        // karena angka dan derajat sama di semua bahasa.
        .objectDisplayCoordinates, .objectDisplayMagnitude,
        // Penanda sisa **di layar** yang mengandung nama objek. Masuk daftar
        // karena ia adalah bentuk yang paling mudah lolos dari semua gerbang:
        // literal berinterpolasi di dalam argumen `row(…)`, yang dilewati
        // Aturan 4 tanpa laporan (siklus ini memperbaiki celah itu juga).
        // Tanpa kunci, penanda "bukan hasil sekarang" — kalimat yang paling
        // tidak boleh salah tempat — tidak punya padanan bahasa Inggris.
        .objectDisplayStaleName,
        .objectSpeechStaleShort,
        // Status sensor & izin. Masuk daftar karena inilah satu-satunya jalur
        // pesan "izin ditolak" dan "sensor tidak tersedia" sampai ke layar —
        // dan karena versi lamanya hidup sebagai literal yang ditugaskan ke
        // properti (`note = "…"`) di tiga berkas `Apps/Shared/`, tempat katalog
        // tidak bisa menjangkaunya. Lihat `SensorStatusText.swift`.
        .sensorMotionMissing, .sensorMotionUnavailable,
        // Kegagalan sensor gerak di tengah pemakaian: `MotionLogger` dulu
        // menampilkan `error.localizedDescription` apa adanya. Lihat
        // `SensorStatusText.motionFailed`.
        .sensorMotionFailed,
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
        .calibrationMessageBelowHorizon, .calibrationMessageNoNearbyStar,
        .calibrationMessageRepeatedReference,
        .calibrationMessageRepeatedReferenceHint,
        .calibrationSpeechPhasePrefix, .calibrationSpeechSamplesRecorded,
        .calibrationSpeechRepeatedReference,
        .calibrationSpeechOffset, .calibrationSpeechSpread,
        .calibrationSpeechApplyReady, .calibrationSpeechApplyNotReady,
        .calibrationSpeechCaptureLabel,
        .calibrationStatusInitial, .calibrationStatusAlreadyInstalled,
        .calibrationStatusNotReady, .calibrationStatusInstalled,
        .calibrationStatusReset,
        .calibrationStatusStaleBanner, .calibrationStatusStaleBannerHint,
        .calibrationDisplayOffset, .calibrationDisplaySpread,
        .calibrationDisplayCaptureAltitude, .calibrationDisplaySuggestedSigma,
        // Label layar & tombol kalibrasi yang masih literal di `CalibrationView`.
        // Sama seperti `captureAltitude` di atas: literal Bahasa Indonesia di
        // dalam view lolos dari Aturan 4 (bukan argumen `Text` berbentuk kunci)
        // dan Aturan 6 (tanpa kunci), jadi English speaker membaca Indonesia.
        // Lihat siklus lokalisasi Fase C #2.
        .calibrationTitle, .calibrationSamplesRecorded,
        .calibrationNotStarted, .calibrationReferenceHeading,
        .calibrationNoVisibleReference, .calibrationCaptureNearestLabel,
        .calibrationCaptureNearestHint, .calibrationApplyLabel,
        .calibrationApplyNotReadyHint, .calibrationResetLabel,
        .calibrationResetHint, .calibrationStatusPrefix,
        .calibrationStatusAppliedShort, .calibrationStatusNotAppliedShort,
        // Layar tautan (`LinkView`) — lihat blok "// MARK: Layar tautan" di atas.
        .linkSectionTitle, .linkRowStatus, .linkValueActive, .linkValueInactive,
        .linkRowReachable, .linkValueYes, .linkValueNo, .linkRowMessagesReceived,
        .linkRequestState, .linkSectionLastState, .linkRowState, .linkRowObject,
        .linkRowConfidence, .linkRowRate, .linkRowTime, .linkNoStateYet,
        .linkSectionLastCalibration, .linkRowYawOffset, .linkRowSpread,
        .linkRowReferenceCount, .linkNoCalibrationYet, .linkSectionSamples,
        .linkRowRecorded, .linkSamplesNote, .linkSigmaMissingNote,
        .pointingTitle, .pointingSkyContextLabel,
        .pointingCalibrationInstalled, .pointingCalibrationNotInstalled,
        .pointingNightModeOn, .pointingNightModeOff,
        .pointingAudioCueOn, .pointingAudioCueOff,
        .pointingLinkConnected, .pointingLinkDisconnected, .pointingLinkFailures,
        .objectDetailStaleNoteDisplay, .pointingLocationFallbackPrefix,
        .skyContextDark, .skyContextLight, .skyContextSkyLabel,
        .skyContextSun, .skyContextMoon,
        .skyContextMoonPhase, .skyContextSection, .skyContextCalibration,
        .skyContextAzimuth, .skyContextAltitude, .skyContextLocation,
        .skyContextLocationSource, .skyContextNotComputed,
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
        .experimentDiagnosisMixed, .experimentDiagnosisMixedSeparator,
        .experimentSuggestedThreshold,
        .experimentLocationFallback, .experimentLocationComputed,
        // Label layar Experiment 1 (`Experiment1View`) — lihat blok
        // "// Label layar Experiment 1" di `ExperimentText.swift`.
        .experimentTitle, .experimentNoTargets, .experimentTargetPicker,
        .experimentNoneSelected, .experimentTargetHeader,
        .experimentGroundTruthFooter, .experimentCaptureSection,
        .experimentNotePlaceholder, .experimentRecordLabel,
        .experimentRemoveLastLabel, .experimentResultSection,
        .experimentNoAnalyzable, .experimentTrialsCountLabel,
        .experimentCorrectLabel, .experimentFalseLockLabel,
        .experimentMedianErrorLabel, .experimentP90ErrorLabel,
        .experimentMedianCalibratedErrorLabel,
        .experimentSendThresholdLabel, .experimentInsufficientForThreshold,
        .experimentTrialsSection, .experimentNoTrials,
        .experimentDatasetSharePreview, .experimentExportLabel,
        .experimentResetLabel,
        // Frasa yang diucapkan untuk baris "judul … nilai" dan nilai bertanda
        // satuan. Masuk daftar karena seluruh `RowSpeech` mengembalikan frasa
        // Bahasa Indonesia tanpa melewati `LocalizedText` — Aturan 6 tidak
        // melihatnya dan Aturan 4 tidak menyapu `Packages/`. Lihat
        // `RowSpeech.swift`.
        .rowSpeechLabel, .rowSpeechDegrees, .rowSpeechDegreesPerSecond,
        .rowSpeechErrorWord, .rowSpeechError, .rowSpeechWristRate,
        .rowSpeechWristRateWord, .rowSpeechStateLine,
        // Warna spektral bintang. Masuk daftar karena inilah satu-satunya
        // jalur warna sampai ke pengguna VoiceOver: gambar prosedural mewarnai
        // titik bintang dari indeks B−V katalog, dan tanpa kunci ini "Rigel"
        // dan "Betelgeuse" terdengar sama persis padahal di layar keduanya
        // digambar biru vs merah. Lihat `StarColorSpeech.swift`.
        .starColorBlue, .starColorWhiteBlue, .starColorYellow,
        .starColorOrange, .starColorRed,
        // Kalimat keadaan kalibrasi yang tampil di layar Tautan. Disimpan di
        // paket sebagai keadaan + accessor (bukan kalimat jadi di pesan) supaya
        // punya kunci katalog — lihat `PointingLinkMessage.calibrationNoteText`.
        .linkNoteCalibrated, .linkNoteNotCalibrated,
        // Kalimat status tautan yang tampil di layar Tautan. Dulu literal di
        // dalam `PhoneLinkService`/`WatchLinkService` — lihat `LinkStatusText`.
        .linkStatusCalibrationNotSent, .linkStatusMessageNotSent,
        .linkStatusSendFailed, .linkStatusSent, .linkStatusWatchSaw,
        // Aktivasi sesi tautan gagal: dua `LinkService` dulu menyimpan
        // `error.localizedDescription` apa adanya ke `lastNote`.
        .linkStatusActivationFailed,
        .linkStatusStateFromWatch, .linkStatusCalibrationFromWatch,
        .linkStatusPolicyFromWatch, .linkStatusAcknowledgement,
        .linkStatusInvalidPolicy, .linkStatusStateRequestTooEarly,
        .linkStatusWatchUnreachablePolicy, .linkStatusWatchUnreachableMessage,
        .linkStatusSendFailures, .linkStatusSendFailuresWord,
        .linkStatusSendFailuresClause,
        .linkSpeechReachable, .linkSpeechUnreachable,
        // Label lokasi darurat yang tampil di layar utama jam & rincian.
        // Dulu literal di `ObserverLocation.fallback` — lihat berkas itu.
        .locationFallbackLabel,
        // Label asal lokasi. Baris "Asal lokasi" dulu menampilkan
        // `ObserverLocation.source` apa adanya (`corelocation`).
        .locationSourceCoreLocation, .locationSourceFallback,
        .locationSourceManual, .locationSourceSimulator,
        .locationSourceUnknown,
        // Rincian sebab keraguan + bentuk hitungan "n dari total".
        // Masuk daftar karena `uncertainReasonCounts` sudah dihitung dan
        // sudah diuji, tapi **nol konsumen di `Apps/`**: satu-satunya yang
        // tampil adalah `diagnosis(...)`, yang sengaja meringkas ke satu
        // kalimat dan karena itu membuang hitungan per sebab serta setiap
        // sebab yang kalah dari dominasi. Kunci ini yang membuat rinciannya
        // bisa tampil. Lihat `UncertainReasonBreakdown.swift`.
        .uncertainReasonTooFar, .uncertainReasonAmbiguous,
        .uncertainReasonNone, .rowCountOf,
        // Percobaan Experiment 1 yang tercatat tapi tidak bisa dinilai.
        // `unanalyzableCount` sudah ada dan sudah teruji, tapi **nol
        // konsumen di `Apps/`**: layar hasil menampilkan `trialCount`,
        // yang hanya menghitung yang teranalisis — sehingga rekaman yang
        // hilang tidak pernah terlihat. Lihat `ExperimentHarness.swift`.
        .experimentRowCountNotAnalyzed, .experimentUnanalyzableWarning,
        // Penanda "hasil jam lalu" untuk complication. complication ditulis
        // hanya saat tanda tangannya berubah, jadi tanpa penanda ini nama
        // objek bisa membeku di pergelangan dan tetap tampil seolah hasil
        // pengukuran yang sedang berjalan. Lihat `ComplicationDigest.isStale`.
        .complicationStaleMarker,
        .onboardingTitle, .onboardingSubtitle, .onboardingHonesty,
        .onboardingStart, .onboardingLabel,
        // Ringkasan verbal grafik keyakinan untuk VoiceOver. Kunci ini
        // dirakit di `ConfidenceChartSpeech`, dan grafiknya sendiri tidak
        // pernah punya pengumuman sebelum unit ini.
        .chartSpeechMeasuredCount, .chartSpeechBandConfident,
        .chartSpeechBandMiddle, .chartSpeechBandTooFar,
        .chartSpeechUnmeasuredCount, .chartSpeechNothingMeasured,
        // Label, legenda, dan nilai layar Diagnostik. Masuk daftar karena
        // inilah satu-satunya jalur teks itu sampai ke pengguna — dan karena
        // versi sebelumnya berdiri sebagai literal kunci katalog di dalam
        // parameter bertipe `String`, tempat `Text` mencetaknya apa adanya.
        // Aturan 4 hijau (literal itu memang ada di katalog), Aturan 19 hijau
        // (substring-nya terlihat sebagai rujukan), dan tidak satu pun kata
        // Inggris pernah sampai ke layar. Lihat `DiagnosticsText.swift`.
        .diagnosticsRowState, .diagnosticsRowGuidance,
        .diagnosticsRowCalibration, .diagnosticsRowWristRate,
        .diagnosticsRowObject, .diagnosticsRowObjectStale,
        .diagnosticsRowDirection, .diagnosticsRowSigmaInUse,
        .diagnosticsRowDeviceMotion, .diagnosticsRowSample,
        .diagnosticsRowLocation, .diagnosticsRowLocationSource,
        .diagnosticsRowMagnitude, .diagnosticsRowRightAscension,
        .diagnosticsRowDeclination, .diagnosticsRowCatalogueId,
        .diagnosticsLegendConfident, .diagnosticsLegendUncertain,
        .diagnosticsLegendUnknown,
        .diagnosticsValueCalibrated, .diagnosticsValueNotCalibrated,
        .diagnosticsValueMotionAvailable, .diagnosticsValueMotionUnavailable,
    ]
}