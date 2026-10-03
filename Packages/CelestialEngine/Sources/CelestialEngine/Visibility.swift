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

    public init(minAltitudeDeg: Double = 5.0,
                limitingMagnitude: Double = 6.0,
                sunAltitudeForDarknessDeg: Double = -6.0,
                minSunSeparationDeg: Double = 30.0) {
        self.minAltitudeDeg = minAltitudeDeg
        self.limitingMagnitude = limitingMagnitude
        self.sunAltitudeForDarknessDeg = sunAltitudeForDarknessDeg
        self.minSunSeparationDeg = minSunSeparationDeg
    }

    /// Kebijakan santai untuk pengujian: tidak membuang apa pun.
    ///
    /// `sunAltitudeForDarknessDeg: 91` membuat langit selalu dianggap gelap
    /// (Matahari tidak pernah setinggi itu), `minAltitudeDeg: -90` meloloskan
    /// benda di bawah horizon, dan `minSunSeparationDeg: 0` mematikan
    /// penyaring Matahari.
    public static let permissive = VisibilityPolicy(
        minAltitudeDeg: -90,
        limitingMagnitude: 30,
        sunAltitudeForDarknessDeg: 91,
        minSunSeparationDeg: 0
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
                                policy: VisibilityPolicy) -> Visibility {
        if altitudeDeg < policy.minAltitudeDeg { return .belowHorizon }
        if magnitude > policy.limitingMagnitude { return .tooFaint }
        if let separation = separationFromSunDeg, separation < policy.minSunSeparationDeg {
            return .tooCloseToSun
        }
        if !isDark(sunAltitudeDeg: context.sunAltitudeDeg, policy: policy) { return .daylight }
        return .visible
    }

    /// Apakah langit dianggap gelap untuk konteks ini.
    public static func isDark(sunAltitudeDeg: Double, policy: VisibilityPolicy) -> Bool {
        sunAltitudeDeg < policy.sunAltitudeForDarknessDeg
    }
}
