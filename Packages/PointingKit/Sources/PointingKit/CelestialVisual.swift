import Foundation
import CelestialEngine

/// Model visual prosedural untuk sebuah benda langit.
///
/// **Kenapa modelnya ada di `PointingKit`, bukan di `Apps/`.** Dua hal di sini
/// bisa salah dengan cara yang tidak terlihat dari layar, dan keduanya harus
/// bisa diuji di Linux:
///
/// 1. **Identitas.** Memilih "Jupiter" dari sebuah `CelestialObject` terdengar
///    sepele, tapi kalau pemilihannya salah, UI akan menggambar pita Jupiter
///    pada Saturnus — tampak meyakinkan, sepenuhnya salah. PRD melarang
///    tampilan yang mengklaim identitas yang tidak dimiliki engine, dan
///    "gambar yang salah" adalah bentuk klaim yang paling halus: tidak ada
///    teks yang bisa dibaca pengguna untuk mengeceknya.
/// 2. **Geometri fase Bulan.** Sabit harus menghadap ke arah yang benar.
///    Geometri itu murni angka, jadi ia bisa diuji — dan kalau ia salah,
///    pengguna melihat Bulan sabit yang terbalik tanpa ada peringatan apa pun.
///
/// Yang **tidak** ada di sini: warna, gradien, `Canvas`, apa pun dari SwiftUI.
/// itu semua ada di `Apps/Shared/CelestialVisual.swift`. Pemisahannya sengaja:
/// model ini diuji di Linux, sedangkan warnanya tidak bisa.
public struct CelestialVisual: Equatable, Sendable {

    /// Jenis gambar yang harus digambar lapisan UI.
    public enum Kind: String, Equatable, Sendable {
        case planet
        case moon
        case star
        case sun
        case deepSky
    }

    /// Planet yang dikenali secara spesifik.
    ///
    /// Sengaja **bukan** nama tampilan: nama bisa berubah, id tidak. Pemetaan
    /// dilakukan dari `CelestialObject.id`, yang diisi resolver dari
    /// `EphemerisBody.rawValue` (lihat
    /// `PointingResolver.catalogueObject(for:sample:)`) — jadi keduanya tidak
    /// bisa berbeda pendapat tentang apa itu "jupiter".
    public enum Planet: String, Equatable, Sendable, CaseIterable {
        case mercury
        case venus
        case mars
        case jupiter
        case saturn
    }

    public var kind: Kind
    /// Planet spesifik, bila `kind == .planet` dan id-nya dikenali.
    public var planet: Planet?

    // MARK: - Bulan

    /// Fraksi piringan yang menyala, 0…1 (dari engine, bukan tebakan).
    ///
    /// Untuk selain Bulan nilainya `nil`, karena UI tidak boleh menggambar
    /// fase pada benda yang fasenya tidak dihitung.
    public var illuminationFraction: Double?
    /// Apakah sabit membesar (waxing) — menentukan sisi mana yang menyala.
    ///
    /// `nil` bila arah fasenya tidak diketahui. Saat `nil`, UI menggambar
    /// fase **simetris** (tidak memilih sisi), bukan menebak: sabit yang
    /// menghadap ke arah yang salah jauh lebih buruk daripada sabit yang
    /// tidak memihak, karena yang pertama terbaca sebagai fakta.
    public var isWaxing: Bool?

    // MARK: - Bintang

    /// Indeks warna B−V (magnitudo). Positif = merah, negatif = biru.
    ///
    /// Diisi dari **tabel warna nyata per bintang**, bukan dari magnitudo:
    /// magnitudo mengatakan seberapa terang, bukan warna apa. Merah dan biru
    /// yang tertukar akan terlihat "cukup masuk akal" bagi kebanyakan
    /// pengguna, jadi kesalahannya tidak akan pernah dilaporkan — persis
    /// jenis klaim tanpa dasar yang harus diuji, bukan diasumsikan.
    public var colorIndexBV: Double
    /// Radius sudut relatif untuk digambar, 0…1 (1 = bintang paling terang
    /// yang ada di katalog).
    public var relativeSize: Double

    // MARK: - Objek langit dalam

    /// Seberapa "menyebar" objeknya (0 = titik, 1 = kabut lebar).
    ///
    /// Nebula dan galaksi tidak punya tepi, jadi ukurannya tidak bisa
    /// diturunkan dari magnitudo seperti bintang. Angka ini yang membedakan
    /// "titik kabur" dari "kabut lebar".
    public var fuzziness: Double

    public init(kind: Kind,
                planet: Planet? = nil,
                illuminationFraction: Double? = nil,
                isWaxing: Bool? = nil,
                colorIndexBV: Double = 0,
                relativeSize: Double = 0.5,
                fuzziness: Double = 0) {
        self.kind = kind
        self.planet = planet
        self.illuminationFraction = illuminationFraction
        self.isWaxing = isWaxing
        self.colorIndexBV = colorIndexBV
        self.relativeSize = relativeSize
        self.fuzziness = fuzziness
    }

    // MARK: - Pembuatan dari objek engine

    /// Bangun model visual untuk sebuah objek hasil resolusi.
    ///
    /// - Parameters:
    ///   - object: objek yang dijawab engine.
    ///   - moonIlluminationFraction: fraksi fase Bulan dari `SkyContext`.
    ///     Hanya dipakai bila objeknya benar-benar Bulan — meneruskannya ke
    ///     benda lain akan menggambar fase pada Venus.
    ///   - isWaxing: arah fase Bulan, bila diketahui.
    public init(object: CelestialObject,
                moonIlluminationFraction: Double? = nil,
                isWaxing: Bool? = nil) {
        switch object.kind {
        case .moon:
            self.init(kind: .moon,
                      illuminationFraction: moonIlluminationFraction,
                      isWaxing: isWaxing,
                      relativeSize: 1.0)
        case .planet:
            self.init(kind: .planet,
                      planet: Planet(objectID: object.id),
                      relativeSize: Self.sizeFromMagnitude(object.magnitude))
        case .star:
            self.init(kind: .star,
                      colorIndexBV: Self.colorIndex(forStarID: object.id),
                      relativeSize: Self.sizeFromMagnitude(object.magnitude))
        case .sun:
            self.init(kind: .sun, relativeSize: 1.0)
        case .deepSky:
            // Objek langit dalam tidak punya magnitudo yang sebanding dengan
            // bintang (magnitudonya terintegrasi, bukan titik), jadi ukurannya
            // tidak diturunkan dari angka itu.
            self.init(kind: .deepSky, relativeSize: 0.7, fuzziness: 0.8)
        }
    }

    // MARK: - Geometri fase Bulan

    /// Geometri terminator Bulan, siap digambar oleh `Canvas`.
    ///
    /// **Kenapa ini dihitung di sini, bukan di view.** Sabit Bulan adalah
    /// selisih dua kurva: piringan Bulan dikurangi separuh elips terminator
    /// yang membentang dari kutub atas ke kutub bawah. Elips itu bernilai
    /// `x = terminatorOffset · R · √(1 − (y/R)²)`, dan daerah yang menyala
    /// adalah pita **antara** kurva itu dengan limb di sisi yang terang.
    /// Kalau tanda `terminatorOffset` terbalik, sabitnya menghadap ke
    /// belakang — dan tidak ada teks di layar yang memberitahu pengguna
    /// bahwa gambarnya terbalik. Karena itu **tanda**-nya diuji
    /// (`CelestialVisualTests`), bukan hanya besarnya.
    public struct PhaseGeometry: Equatable, Sendable {
        /// Posisi x terminator di ekuator, dalam satuan radius piringan (−1…1).
        ///
        /// Tanda = sisi yang **menyala**: positif berarti terminator berada di
        /// kanan sehingga pita terangnya menempel pada limb kanan (waxing);
        /// negatif berarti sebaliknya. Besar = setengah sumbu mendatar elips
        /// terminator: `1` → tidak ada yang menyala, `0` → terminator lurus
        /// (setengah piringan), `−1` → purnama.
        public var terminatorOffset: Double

        /// Apakah fase-nya gibbous (lebih dari setengah).
        ///
        /// Sabat dan gibbous memakai **sisi piringan yang berlawanan** sebagai
        /// acuan terminator, jadi UI harus tahu yang mana. Salah memilih
        /// membuat Bulan tampak cekung — separuh terangnya melengkung ke arah
        /// yang salah.
        public var isGibbous: Bool

        /// Separuh sumbu mendatar elips terminator (selalu ≥ 0).
        public var terminatorSemiWidth: Double { abs(terminatorOffset) }
    }

    /// Hitung geometri fase dari fraksi iluminasi.
    ///
    /// Fraksi piringan yang menyala berbanding lurus dengan lebar pita
    /// terangnya, yaitu `(1 − terminatorOffset) / 2`, sehingga
    /// `terminatorOffset = 1 − 2f`. Untuk f = 0 → +1 (tidak ada yang
    /// menyala), f = 0.5 → 0 (setengah), f = 1 → −1 (purnama — terminator
    /// sudah keluar dari piringan).
    ///
    /// - Parameter waxing: arah fase. `nil` saat tidak diketahui.
    /// - Returns: `nil` bila tidak ada fase yang bisa digambar (bukan Bulan,
    ///   atau fraksinya tidak tersedia).
    public func phaseGeometry(waxing: Bool?) -> PhaseGeometry? {
        guard kind == .moon, let f = illuminationFraction else { return nil }
        let clamped = min(1, max(0, f))
        let offset = 1 - 2 * clamped
        // Arah menentukan **tanda**, bukan besar. `nil` → 0: terminator
        // lurus di tengah. Itu bukan "fase setengah palsu" melainkan
        // pengakuan bahwa arahnya tidak diketahui — elipsnya simetris, jadi
        // gambar tidak memihak ke kiri maupun kanan.
        let sign: Double
        if let waxing {
            sign = waxing ? 1 : -1
        } else {
            sign = 0
        }
        return PhaseGeometry(terminatorOffset: offset * sign,
                             isGibbous: clamped > 0.5)
    }

    // MARK: - Warna bintang

    /// Indeks warna B−V untuk bintang yang ada di katalog.
    ///
    /// Nilainya dari katalog warna bintang terang yang sudah mapan. Yang
    /// penting di sini bukan presisi dua desimal, melainkan **tanda**-nya:
    /// Betelgeuse (M1, B−V ≈ +1.85) harus merah, Rigel (B8, B−V ≈ −0.03)
    /// biru, Sirius (A1, B−V ≈ 0.00) putih-biru. Tanda yang terbalik tidak
    /// akan pernah dilaporkan pengguna — karena itu ia diuji.
    ///
    /// Bintang yang tidak ada di tabel mengembalikan `0` (putih), bukan
    /// warna karangan: putih netral tidak mengklaim apa-apa.
    public static func colorIndex(forStarID id: String) -> Double {
        Self.starColorIndex[id] ?? 0
    }

    /// Tabel B−V per id bintang di `Catalogue.brightStars`.
    ///
    /// Sengaja `internal` (bukan `private`) supaya uji bisa menegakkan bahwa
    /// **setiap** bintang di katalog punya entri warna. Tanpa uji itu,
    /// menambah bintang ke katalog akan menghasilkan bintang putih yang
    /// tampak sah padahal warnanya tidak diketahui.
    static let starColorIndex: [String: Double] = [
        "sirius":      0.00,   // A1 — putih kebiruan
        "canopus":     0.15,   // F0 — putih
        "arcturus":    1.23,   // K0 — jingga
        "vega":        0.00,   // A0 — putih kebiruan
        "capella":     0.80,   // G8 — kuning
        "rigel":      -0.03,   // B8 — biru
        "procyon":     0.42,   // F5 — putih kekuningan
        "achernar":   -0.16,   // B6 — biru
        "betelgeuse":  1.85,   // M1 — merah
        "hadar":      -0.23,   // B1 — biru
        "altair":      0.22,   // A7 — putih
        "acrux":      -0.24,   // B0 — biru
        "aldebaran":   1.54,   // K5 — jingga kemerahan
        "spica":      -0.23,   // B1 — biru
        "antares":     1.83,   // M1 — merah
        "pollux":      1.00,   // K0 — jingga
        "fomalhaut":   0.09,   // A3 — putih
        "deneb":       0.09,   // A2 — putih
        "regulus":    -0.11,   // B8 — biru keputihan
        "castor":      0.03,   // A1 — putih
        "bellatrix":  -0.22,   // B2 — biru
        "alioth":     -0.02,   // A1 — putih
        "alnitak":    -0.21,   // O9 — biru
        "dubhe":       1.07,   // K0 — jingga
        "polaris":     0.60    // F7 — putih kekuningan
    ]

    // MARK: - Ukuran dari magnitudo

    /// Radius gambar relatif dari magnitudo tampak, 0…1.
    ///
    /// Skala magnitudo **logaritmik dan terbalik**: makin kecil angkanya,
    /// makin terang. Karena itu ukurannya diturunkan dari
    /// `10^(−0.2·(m − mTerang))`, bukan dari selisih linear — memakai skala
    /// linear membuat Sirius dan Deneb nyaris sama besar padahal selisihnya
    /// 2.7 magnitudo (≈ 12× terang).
    ///
    /// Dijepit ke 0.15…1: benda paling redup masih harus terlihat sebagai
    /// titik, bukan menghilang.
    public static func sizeFromMagnitude(_ magnitude: Double) -> Double {
        let brightest: Double = -1.5
        let raw = pow(10.0, -0.2 * (magnitude - brightest))
        return min(1, max(0.15, raw))
    }
}

public extension CelestialVisual.Planet {

    /// Kenali planet dari `CelestialObject.id`.
    ///
    /// `nil` untuk id yang tidak dikenal — UI lalu menggambar bola generik,
    /// **bukan** memilih planet secara acak. Bola generik tidak mengklaim
    /// planet mana pun; pita Jupiter pada planet yang bukan Jupiter
    /// mengklaim sesuatu yang tidak diketahui engine.
    init?(objectID: String) {
        guard let planet = Self(rawValue: objectID) else { return nil }
        self = planet
    }
}

// MARK: - Arah fase Bulan

public extension PointingResolver {

    /// Arah fase Bulan saat ini: apakah sabitnya membesar (waxing).
    ///
    /// **Kenapa ini dihitung, bukan diasumsikan.** `SkyContext` hanya membawa
    /// `moonIlluminationFraction` — besar fase, tanpa arah. Padahal sabit
    /// yang mengarah ke kiri dan ke kanan adalah dua gambar yang berbeda,
    /// dan keduanya tampak sama meyakinkannya bagi pengguna. Menggambar yang
    /// salah berarti UI menyatakan sesuatu yang tidak dihitung engine —
    /// persis yang dilarang PRD.
    ///
    /// Caranya: Bulan membesar selama **elongasinya** (selisih bujur
    /// ekliptika terhadap Matahari) berada di 0°–180°. Selisih RA dipakai
    /// sebagai proksi bujur: keduanya naik ke arah yang sama, dan yang
    /// dibutuhkan di sini hanya **tanda**-nya (waxing vs waning), bukan
    /// nilai tepatnya. Proksi ini hanya bisa salah dalam rentang sangat
    /// sempit di sekitar bulan baru/purnama, tempat fraksinya mendekati 0
    /// atau 1 dan sabitnya nyaris tidak terlihat.
    ///
    /// - Returns: `nil` bila efemeris tidak tersedia atau perhitungannya
    ///   gagal. UI lalu menggambar fase **simetris**, bukan menebak sisi.
    func isMoonWaxing(at date: Date = Date()) -> Bool? {
        guard let ephemeris else { return nil }
        guard let moon = try? ephemeris.apparent(.moon, at: date),
              let sun = try? ephemeris.apparent(.sun, at: date) else { return nil }
        let difference = Self.normalizedDegrees(moon.raDeg - sun.raDeg)
        return difference < 180
    }

    /// Fraksi piringan Bulan yang menyala, dari efemeris yang sama.
    ///
    /// Diambil di sini — bukan dari `SkyContext` — supaya fraksi dan arahnya
    /// berasal dari **satu** sampel efemeris.Kalau fraksi diambil dari
    /// konteks berjangka 30 detik sedangkan arahnya dihitung sekarang,
    /// keduanya bisa berasal dari menit yang berbeda.
    func moonIlluminationFraction(at date: Date = Date()) -> Double? {
        guard let ephemeris else { return nil }
        guard let moon = try? ephemeris.apparent(.moon, at: date) else { return nil }
        return min(1, max(0, moon.illuminationFraction))
    }

    /// Bungkus sudut ke rentang 0…360.
    static func normalizedDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
