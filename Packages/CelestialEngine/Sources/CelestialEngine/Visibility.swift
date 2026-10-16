import Foundation

/// Klasifikasi visibilitas: mengapa sebuah benda layak atau tidak layak
/// dijadikan kandidat saat ini.
///
/// Ini yang mencegah engine menjawab "Bulan!" saat pengguna menunjuk ke bawah
/// meja, atau "Venus!" saat Matahari masih di langit. Tanpa penyaringan ini
/// resolver akan mengembalikan kandidat yang secara fisik mustahil dilihat.
public enum Visibility: String, Equatable {
    /// Bisa dilihat sekarang.
    case visible
    /// Di bawah horizon pengamat.
    case belowHorizon
    /// Terlalu redup untuk dilihat dengan mata telanjang pada konteks ini.
    case tooFaint
    /// Langit terlalu terang (Matahari masih di atas cakrawala sipil).
    case daylight
    /// Terlalu dekat dengan Matahari untuk ditunjuk dengan aman (teleskop).
    case tooCloseToSun

    /// Apakah benda ini boleh menjadi kandidat.
    public var isCandidate: Bool { self == .visible }
}

/// Parameter penyaringan. Semua ambang bisa diubah dari luar supaya bisa
/// dikalibrasi lewat Experiment 1 tanpa mengubah engine.
public struct VisibilityPolicy: Equatable {
    /// Ketinggian minimum benda di atas horizon (derajat).
    public var minAltitudeDeg: Double
    /// Batas magnitudo — benda yang lebih redup dari ini dibuang.
    public var limitingMagnitude: Double
    /// Ketinggian minimum Matahari (derajat) agar langit dianggap gelap.
    /// -6° adalah batas senja sipil: di bawah ini bintang terang mulai terlihat.
    public var sunAltitudeForDarknessDeg: Double
    /// Sudut minimum dari Matahari (derajat) agar aman ditunjuk. Ini pengaman
    /// teleskop: membarui GoTo ke arah Matahari bisa merusak alat dan mata.
    public var minSunSeparationDeg: Double
    /// Seberapa jauh ambang magnitudo boleh mengetat karena cahaya Bulan,
    /// dalam satuan magnitudo, pada fraksi iluminasi penuh.
    ///
    /// Default 1.6: purnama menurunkan batas penglihatan mata telanjang dari
    /// sekitar 6.5 ke sekitar 4.9 — angka kasar yang lazim dipakai peminat
    /// pengamatan, bukan hasil pengukuran di instrument. Yang dijaga uji adalah
    /// **arahnya** (lihat `testMoonlightTightensTheLimitingMagnitude`), karena
    /// angka yang tepat bergantung pada pengamat, latitude, dan kebersihan
    /// langit.
    ///
    /// `0` untuk policy permisif: policy pengujian harus tetap tidak membuang
    /// apa pun.
    public var moonBrighteningMagnitudes: Double

    /// Ambang magnitudo **khusus objek langit dalam** (nebula, galaksi, gugus).
    ///
    /// **Kenapa batasnya terpisah dari `limitingMagnitude`.** Katalog produksi
    /// memuat objek langit dalam sampai mag 8.8 (M57), dan seluruh jalur
    /// visualnya — `CelestialVisual.Kind.deepSky`, `VisualFrame`, label,
    /// pengucapan, dan bentuk per-morfologi — sudah ada dan teruji. Tapi
    /// `classify` hanya memakai `limitingMagnitude` (6.0), jadi keenam objek
    /// yang melebihi 6.0 (M27, M57, M51, M101, M2, M11) — termasuk seluruh
    /// wakil `.planetaryNebula` dan `.spiralGalaxy` — diklasifikasi
    /// `.tooFaint` dan resolver tidak pernah menghasilkannya. Hasilnya kode
    /// gambar yang mahal untuk dua kelas objek tidak pernah berjalan di app.
    /// Ini kelas cacat yang sama persis dengan yang sudah ditutup
    /// `DeepSkyCatalogueTests`: setiap bagian benar sendiri, yang hilang
    /// adalah ambang yang membedakan bintang dari objek langit dalam.
    ///
    /// Bintang dan objek langit dalam memang punya ambang beda: batas mata
    /// telanjang (~6) adalah untuk bintang titik; objek langit dalam adalah
    /// target binokuler/tele yang sengaja lebih redup. Memakai satu angka
    /// untuk keduanya berarti atau binokuler DSO tidak pernah dikenali, atau
    /// bintang redup palsu diklaim terlihat. Ambang terpisah menyelesaikannya
    /// tanpa mengubah batas bintang (6.0) — sehingga tidak ada uji bintang
    /// yang berubah.
    ///
    /// Nilai 9.0 berada di atas mag terredup katalog (M57 = 8.80) agar semua
    /// anggota katalog benar-benar bisa jadi kandidat saat langit gelap.
    /// Cahaya Bulan tetap mengketatkannya lewat `moonBrighteningMagnitudes`
    /// (lihat `effectiveLimitingMagnitude`), jadi M57 tetap ditolak saat
    /// purnama tinggi — itu jujur: nebula mag 8.8 memang tidak terlihat di
    /// langit terang Bulan.
    public var deepSkyLimitingMagnitude: Double

    /// Ambang magnitudo **khusus planet** di luar orbit Saturnus.
    ///
    /// **Kenapa planet tidak cukup memakai `limitingMagnitude` (6.0).**
    /// Batas mata telanjang 6.0 benar untuk bintang titik, dan memang
    /// menolak Uranus (5.9 — di bawah batas, jadi aman) **dan Neptunus
    /// (7.8 — di atas batas)**. Tanpa ambang sendiri, Neptunus tidak pernah
    /// bisa menjadi kandidat: `classify` mengembalikannya `.tooFaint`
    /// sebelum ketinggiannya bahkan diperiksa, sehingga "tunjuk ke arah
    /// Neptunus" selalu berakhir "tidak ada". Itu bukan kejujuran — itu
    /// engine yang diam-diam membuang sebuah benda yang memang ada di sana.
    ///
    /// Nilainya **8.30**, bukan 7.8, dan angkanya punya alasan yang bisa
    /// diperiksa.
    ///
    /// **Cacat yang ditutupnya.** Versi pertama ambang ini 7.8 — persis
    /// magnitudo Neptunus di sekitar oposisi. Terukur di fixture Horizons repo
    /// ini sendiri (`horizons_reference.json`, sampel 2000-01-01): Neptunus
    /// **7.853**. Pada tanggal itu `classify` mengembalikannya `.tooFaint`
    /// sebelum ketinggiannya diperiksa — jadi "tunjuk ke arah Neptunus"
    /// berakhir "tidak ada", yaitu kegagalan yang sama yang docstring ini
    /// klaim sudah ditutup, hanya bergeser ke sembilan belas tahun yang lain.
    /// Neptunus yang kadang muncul dan kadang tidak, tanpa penjelasan di layar,
    /// lebih buruk daripada tidak ada sama sekali: pengguna tidak bisa
    /// membedakan cacat ini dari langit yang memang kosong.
    ///
    /// **Kenapa 8.30, bukan 7.86 (sekadar di atas fixture).** Magnitudo
    /// Neptunus berubah terhadap Bumi selama orbit 165 tahunnya; ia paling
    /// redup di sekitar konjungsi, bukan oposisi. Ambang yang dirapatkan ke
    /// satu sampel hanya memindahkan cacatnya ke sampel berikutnya. Rentang
    /// yang dipakai di sini adalah **terang 7.65 … redup 8.05** dengan margin
    /// 0.25 di ujung redup — jadi seluruh rentang orbitnya tertutup, tanpa
    /// mengklaim benda yang lebih redup dari Neptunus sebagai terlihat.
    ///
    /// **Batas yang diakui.** Ambang ini satu angka untuk seluruh planet,
    /// bukan per-planet. Uranus (5.7–5.9) dan planet dalam jauh di bawahnya,
    /// jadi angkanya praktis hanya pernah relevan untuk Neptunus — tetapi
    /// planet kesembilan yang lebih redup dari 8.30 akan tertolak tanpa cara
    /// menyatakannya. Itu di luar katalog saat ini dan disebutkan di sini
    /// alih-alih disangka tertutup.
    ///
    /// Sementara cahaya Bulan tetap mengketatkannya lewat
    /// `moonBrighteningMagnitudes`: Neptunus di langit berbulan terang memang
    /// **tidak** bisa dilihat mata telanjang, dan ambang yang ikut turun
    /// mengatakan justru itu.
    ///
    /// Batas bintang 6.0 **tidak** disentuh: merapatkannya ke 8 akan mengklaim
    /// bintang redup palsu sebagai terlihat, dan itu persis yang dilakukan
    /// engine saat menolak `tooFaint` untuk bintang.
    public var planetLimitingMagnitude: Double

    public init(minAltitudeDeg: Double = 5.0,
                limitingMagnitude: Double = 6.0,
                sunAltitudeForDarknessDeg: Double = -6.0,
                minSunSeparationDeg: Double = 30.0,
                moonBrighteningMagnitudes: Double = 1.6,
                deepSkyLimitingMagnitude: Double = 9.0,
                planetLimitingMagnitude: Double = 8.30) {
        self.minAltitudeDeg = minAltitudeDeg
        self.limitingMagnitude = limitingMagnitude
        self.sunAltitudeForDarknessDeg = sunAltitudeForDarknessDeg
        self.minSunSeparationDeg = minSunSeparationDeg
        self.moonBrighteningMagnitudes = moonBrighteningMagnitudes
        self.deepSkyLimitingMagnitude = deepSkyLimitingMagnitude
        self.planetLimitingMagnitude = planetLimitingMagnitude
    }

    /// Kebijakan santai untuk pengujian: tidak membuang apa pun.
    ///
    /// `sunAltitudeForDarknessDeg: 91` membuat langit selalu dianggap gelap
    /// (Matahari tidak pernah setinggi itu), `minAltitudeDeg: -90` meloloskan
    /// benda di bawah horizon, `minSunSeparationDeg: 0` mematikan
    /// penyaring Matahari, dan `moonBrighteningMagnitudes: 0` mematikan
    /// penyaringan cahaya Bulan — tanpa itu policy permisif akan tetap membuang
    /// bintang redup saat ada purnama, dan "tidak membuang apa pun" jadi
    /// setengah benar.
    ///
    /// **Ketiga ambang magnitudo harus ikut dinaikkan, bukan hanya dua.**
    /// `limitingMagnitude` dan `deepSkyLimitingMagnitude` sudah dinaikkan ke
    /// 30 sejak awal; `planetLimitingMagnitude` tertinggal di nilai bawaan
    /// produksi (8.30), sehingga `permissive` — yang docstring-nya berbunyi
    /// "tidak membuang apa pun" — diam-diam membuang setiap planet redup.
    /// Cacat itu bertahan lama karena uji "permissive tidak menolak apa pun"
    /// memanggil `classify` tanpa `kind:`, jadi ia selalu memakai `.star` dan
    /// tidak pernah menyentuh ambang planet. Bentuk yang sama persis dengan
    /// celah cahaya Bulan di atas, satu `kind` lebih jauh.
    ///
    /// Karena itu `planetLimitingMagnitude` disetel sama dengan
    /// `limitingMagnitude`, bukan angka lain: yang diklaim policy ini adalah
    /// **tidak ada ambang magnitudo yang tersisa**, dan menulis angka lain akan
    /// membuat klaim itu tidak lagi bisa diperiksa dari satu perbandingan.
    public static let permissive = VisibilityPolicy(
        minAltitudeDeg: -90,
        limitingMagnitude: 30,
        sunAltitudeForDarknessDeg: 91,
        minSunSeparationDeg: 0,
        moonBrighteningMagnitudes: 0,
        deepSkyLimitingMagnitude: 30,
        planetLimitingMagnitude: 30
    )
}

/// Konteks langit saat ini, dihitung sekali per resolusi.
///
/// Dipisahkan dari resolver supaya efemeris tidak dihitung berulang untuk
/// setiap benda dan supaya logika penyaringan bisa diuji tanpa efemeris.
public struct SkyContext: Equatable {
    /// Ketinggian Matahari (derajat).
    public var sunAltitudeDeg: Double
    /// Ketinggian Bulan (derajat), bila tersedia.
    public var moonAltitudeDeg: Double?
    /// Fraksi piringan Bulan yang menyala, 0…1.
    public var moonIlluminationFraction: Double?
    /// Apakah langit cukup gelap untuk melihat bintang.
    public var isDark: Bool

    public init(sunAltitudeDeg: Double,
                moonAltitudeDeg: Double? = nil,
                moonIlluminationFraction: Double? = nil,
                isDark: Bool = true) {
        self.sunAltitudeDeg = sunAltitudeDeg
        self.moonAltitudeDeg = moonAltitudeDeg
        self.moonIlluminationFraction = moonIlluminationFraction
        self.isDark = isDark
    }
}

/// Penyaring visibilitas. Fungsi murni — sengaja tanpa dependensi efemeris
/// agar bisa diuji di Linux dengan nilai yang ditulis tangan.
public enum VisibilityFilter {

    /// Klasifikasi satu benda.
    ///
    /// Gelap/terang **selalu** dihitung dari `policy` dan ketinggian Matahari,
    /// bukan dari `context.isDark`. Kalau tidak, kebijakan dan konteks bisa
    /// saling bertentangan dan tidak jelas mana yang menang.
    /// (`SkyContext.isDark` tetap ada untuk ditampilkan ke pengguna.)
    ///
    /// - Parameters:
    ///   - altitudeDeg: ketinggian benda saat ini.
    ///   - magnitude: magnitudo tampak benda.
    ///   - separationFromSunDeg: jarak sudut dari Matahari (`nil` untuk Matahari sendiri).
    ///   - context: konteks langit.
    ///   - policy: ambang yang dipakai.
    public static func classify(altitudeDeg: Double,
                                magnitude: Double,
                                separationFromSunDeg: Double?,
                                context: SkyContext,
                                policy: VisibilityPolicy,
                                kind: ObjectKind = .star) -> Visibility {
        if altitudeDeg < policy.minAltitudeDeg { return .belowHorizon }
        if magnitude > effectiveLimitingMagnitude(context: context, policy: policy, kind: kind) {
            return .tooFaint
        }
        if let separation = separationFromSunDeg, separation < policy.minSunSeparationDeg {
            return .tooCloseToSun
        }
        if !isDark(sunAltitudeDeg: context.sunAltitudeDeg, policy: policy) { return .daylight }
        return .visible
    }

    /// Batas magnitudo **efektif** untuk konteks langit ini.
    ///
    /// Cahaya Bulan menutupi bintang redup, jadi ambang magnitudo ikut
    /// bergerak: makin terang langit, makin ketat ambangnya.
    ///
    /// **Kenapa hanya fraksi, bukan juga ketinggian dan sudut.** Karena fraksi
    /// saja yang punya sumber sudah teruji di engine
    /// (`EphemerisBody.illuminationFraction`); menambahkan dua faktor lain
    /// butuh plumbing efemeris baru untuk pengaruh orde dua. Aturan repo:
    /// jangan menambah presisi yang belum ada sumbernya.
    ///
    /// **Cahaya hanya dihitung kalau Bulan benar-benar masih di atas horizon.**
    /// `SkyContext.moonAltitudeDeg` memegang ketinggiannya; saat Bulan sudah
    /// terbenam nilainya negatif, sedangkan `moonIlluminationFraction` tetap
    /// tidak `nil` — jadi menyaring hanya dari fraksi akan menghukum bintang
    /// redup untuk Bulan yang pengguna sama sekali tidak bisa lihat. Itu
    /// penolakan palsu, persis yang dilarang PRD v0.4. Altitude `nil` (Bulan
    /// tak diketahui letaknya) diperlakukan sama: "tidak tahu" berarti **jangan
    /// menebak lebih buruk**, bukan "asumsikan paling terang".
    ///
    /// Mengembalikan batas dasar saat fraksi `nil` (Bulan tidak diketahui),
    /// saat Bulan di bawah horizon, atau saat altitudenya tak diketahui: asumsi
    /// terbaik tanpa bukti adalah batas paling longgar, dan itu juga yang paling
    /// tidak berbohong tentang apa yang bisa dilihat.
    ///
    /// **Kenapa `kind` ikut.** Bintang titik dan objek langit dalam punya ambang
    /// beda (`limitingMagnitude` lawan `deepSkyLimitingMagnitude`); tanpa
    /// `kind` di sini, ambang tunggal akan membuang keenam DSO terredup
    /// (M27/M57/M51/M101/M2/M11) — termasuk seluruh wakil `.planetaryNebula`
    /// dan `.spiralGalaxy` — padahal kode gambarnya sudah ada. `kind` dibawa
    /// sebagai parameter, bukan dibaca dari katalog, supaya fungsi ini tetap
    /// murni dan bisa diuji di Linux dengan benda buatan tangan.
    public static func effectiveLimitingMagnitude(context: SkyContext,
                                                  policy: VisibilityPolicy,
                                                  kind: ObjectKind = .star) -> Double {
        let base: Double
        switch kind {
        case .deepSky: base = policy.deepSkyLimitingMagnitude
        case .planet: base = policy.planetLimitingMagnitude
        case .moon, .star, .sun: base = policy.limitingMagnitude
        }
        // Cahaya Bulan hanya relevan kalau Bulan memang masih di atas horizon.
        let moonIsUp = (context.moonAltitudeDeg ?? -90) > 0
        let fraction = moonIsUp ? (context.moonIlluminationFraction ?? 0) : 0
        guard fraction > 0 else { return base }
        return base - policy.moonBrighteningMagnitudes * fraction
    }

    /// Apakah langit dianggap gelap untuk konteks ini.
    public static func isDark(sunAltitudeDeg: Double, policy: VisibilityPolicy) -> Bool {
        sunAltitudeDeg < policy.sunAltitudeForDarknessDeg
    }
}
