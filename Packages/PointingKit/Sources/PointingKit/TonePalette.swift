import Foundation

/// Warna per **nada** untuk satu mode tampilan — dengan kontras yang sudah
/// **dihitung**, bukan diwarisi dari warna sistem.
///
/// **Cacat yang ditutup oleh file ini.** Warna nada pernah hidup di
/// `Apps/Shared/NightMode.swift` sebagai daftar warna yang ditulis manual:
/// mode siang memakai warna sistem (`.cyan`, `.green`, `.orange`, `.red`,
/// `.secondary`) yang **tidak bisa dihitung**, dan mode malam memakai
/// `red 0.50 / 0.62 / 0.80 / 1.00` yang **salah kontras** untuk teks.
///
/// Jam dan iPhone memakai warna nada untuk hal yang paling terlihat di layar:
/// label keadaan di kartu status, badge keyakinan di panel objek, ikon
/// kalibrasi, dan penanda "Ragu". Kalau kontrasnya tidak dihitung, kegagalan
/// itu tidak punya teks lain yang bisa membongkar: `shortLabel` sudah benar,
/// `guidance` sudah benar, dan yang redup hanya warnanya.
public struct TonePalette: Equatable, Sendable {

    public var neutral: SurfaceColor
    public var active: SurfaceColor
    public var success: SurfaceColor
    public var warning: SurfaceColor
    public var danger: SurfaceColor

    public init(neutral: SurfaceColor, active: SurfaceColor, success: SurfaceColor,
                warning: SurfaceColor, danger: SurfaceColor) {
        self.neutral = neutral
        self.active = active
        self.success = success
        self.warning = warning
        self.danger = danger
    }

    /// Warna untuk nada tertentu.
    public func color(for tone: PointingTone) -> SurfaceColor { tone.fill(from: self) }
}

// MARK: - Pencocokan nada

public extension PointingTone {

    /// Warna nada ini pada palet tertentu.
    ///
    /// Satu fungsi, bukan lima `switch` di dua tempat: warna nada dipakai
    /// untuk teks, ikon, dan latar kapsul badge, dan ketiganya harus dapat
    /// warna yang sama. Kalau tiap peran punya pencarian sendiri, nada yang
    /// baru ditambah bisa mendapat warna di satu peran dan tidak di peran
    /// lain — persis kelas cacat "satu ambang untuk dua pertanyaan" yang
    /// sudah pernah menutupi bug di repo ini.
    func fill(from palette: TonePalette) -> SurfaceColor {
        switch self {
        case .neutral: return palette.neutral
        case .active: return palette.active
        case .success: return palette.success
        case .warning: return palette.warning
        case .danger: return palette.danger
        }
    }

    /// Semua nada, dalam urutan enum — supaya pengujian bisa menyisir
    /// **seluruh** warna tanpa ada satu pun yang luput karena tidak disebut.
    static let allCases: [PointingTone] = [.neutral, .active, .success, .warning, .danger]
}

// MARK: - Isi kapsul badge

/// Latar kapsul badge keyakinan untuk kelima nada.
///
/// **Kenapa ini milik model, bukan `opacity(0.2)` di view.** Badge memakai
/// warna nada yang sama untuk teks dan latar kapsul, jadi kontrasnya
/// bergantung pada **campuran** keduanya, bukan hanya pada warna nadanya.
/// Campuran `nada @ 0.2` di atas permukaan menghasilkan warna latar yang
/// lebih dekat ke teksnya — dan di mode malam itu justru salah arah, karena
/// latar kapsul menjadi **lebih terang** dari nada, sehingga jarak antara
/// teks dan latarnya menyusut.
public struct BadgeFills: Equatable, Sendable {

    public var neutral: SurfaceColor
    public var active: SurfaceColor
    public var success: SurfaceColor
    public var warning: SurfaceColor
    public var danger: SurfaceColor

    public init(neutral: SurfaceColor, active: SurfaceColor, success: SurfaceColor,
                warning: SurfaceColor, danger: SurfaceColor) {
        self.neutral = neutral
        self.active = active
        self.success = success
        self.warning = warning
        self.danger = danger
    }

    public func fill(for tone: PointingTone) -> SurfaceColor { tone.badgeFill(from: self) }
}

public extension PointingTone {
    func badgeFill(from fills: BadgeFills) -> SurfaceColor {
        switch self {
        case .neutral: return fills.neutral
        case .active: return fills.active
        case .success: return fills.success
        case .warning: return fills.warning
        case .danger: return fills.danger
        }
    }
}

// MARK: - Palet mode siang

public extension TonePalette {

    /// Palet nada mode siang.
    ///
    /// **Kenapa warna sistem `.cyan` / `.green` / ... tidak lagi dipakai.**
    /// Warna sistem bergerak mengikuti OS. Nilainya bisa bergeser di iOS atau
    /// watchOS berikutnya **tanpa ada satu pun uji yang menyentuhnya**, jadi
    /// gerbang kontras yang kita hitung tidak akan berlaku lagi. Nilai di sini
    /// dipin ke warna semantik yang sama dengan yang sebelumnya, dipin ke
    /// angka yang bisa diuji, lalu **dijaga kontrasnya** setiap kali palet
    /// permukaan berubah.
    ///
    /// Semua nilainya di atas 4.5:1 terhadap **permukaan paling terang**
    /// (`surface2`) — kasus terburuk, bukan kasus yang paling sering terlihat.
    static let day = TonePalette(
        neutral: SurfaceColor(red: 0.784, green: 0.800, blue: 0.835),
        active: SurfaceColor(red: 0.310, green: 0.780, blue: 0.900),
        success: SurfaceColor(red: 0.290, green: 0.830, blue: 0.470),
        warning: SurfaceColor(red: 0.960, green: 0.700, blue: 0.290),
        danger: SurfaceColor(red: 1.000, green: 0.420, blue: 0.420))

    /// Isi kapsul badge mode siang.
    ///
    /// Dihitung sebagai warna nada pada 20% di atas **permukaan paling
    /// terang**, lalu dijadikan **opak**. Opak penting: kalau view memakai
    /// `opacity` di atas permukaan yang berbeda dari yang dipakai saat
    /// menghitung, hasilnya bergeser dan kontras yang sudah diuji kembali
    /// tidak berlaku. Angka ini dijaga lewat
    /// `testBadgeFillsStayLegibleOnEverySurfaceTheyCanLandOn`.
    static let dayBadge = BadgeFills(
        neutral: SurfaceColor(red: 0.2416, green: 0.2448, blue: 0.2734),
        active: SurfaceColor(red: 0.1468, green: 0.2408, blue: 0.2864),
        success: SurfaceColor(red: 0.1428, green: 0.2508, blue: 0.2004),
        warning: SurfaceColor(red: 0.2768, green: 0.2248, blue: 0.1644),
        danger: SurfaceColor(red: 0.2848, green: 0.1688, blue: 0.1904))
}

// MARK: - Palet mode malam

public extension TonePalette {

    /// Palet nada mode malam — **merah murni**, dan semua nadanya **terbaca
    /// sebagai teks**.
    ///
    /// **Ramp yang sangat sempit ini bukan pilihan rasa, itu fisika.** Mode
    /// malam membuang hijau dan biru sepenuhnya, jadi semua warna hidup di
    /// kanal merah saja, dan merah murni di atas hitam punya kontras
    /// maksimum 5.25:1 (lihat `SurfacePaletteTests`). Karena itu rentang
    /// warna yang boleh dipakai untuk teks 4.5:1 terhadap permukaan
    /// malam hanya 0.9365 sampai 1.0 — hanya 6% lebar kanal. Versi lama
    /// mengambil nilai di luar rentang itu (0.50 / 0.62 / 0.80), jadi tiga
    /// dari lima nada **tidak terbaca sebagai teks** justru di mode yang
    /// dipilih supaya penglihatan malam terjaga.
    ///
    /// **Konsekuensi yang harus diterima, bukan disembunyikan.** Rentang
    /// 0.94 sampai 1.0 hanya berbeda 1.12:1 antar ujungnya — praktis tidak
    /// terlihat. Jadi pada mode malam, warna nada **tidak lagi** membedakan
    /// keadaan; yang membedakan adalah terang-versus-gelap **penuh** antara
    /// nada (1.0) dan teks permukaan. Warna nada tetap dipakai sebagai
    /// identitas, bukan sebagai pembawa informasi. Ini dicatat di sini
    /// supaya tidak nanti "diperbaiki" dengan melanggar batas merah murni.
    ///
    /// Urutan terang **dipertahankan** dari versi lama
    /// (neutral < warning < active < success = danger) supaya tidak ada
    /// informasi yang berubah tanpa disengaja.
    static let night = TonePalette(
        neutral: SurfaceColor(red: 0.940, green: 0.000, blue: 0.000),
        active: SurfaceColor(red: 0.955, green: 0.000, blue: 0.000),
        success: SurfaceColor(red: 0.968, green: 0.000, blue: 0.000),
        warning: SurfaceColor(red: 0.982, green: 0.000, blue: 0.000),
        danger: SurfaceColor(red: 1.000, green: 0.000, blue: 0.000))

    /// Isi kapsul badge mode malam — **permukaan tingkat dua**, bukan warna
    /// nada.
    ///
    /// Di mode malam warna nada tidak boleh dipakai sebagai latar kapsul:
    /// laturnya akan berada di kanal merah yang sama dengan teksnya, dan
    /// jarak keduanya hanya sepersekian kanal yang tersedia. Memakai
    /// permukaan tingkat dua membuat badge tetap berupa **permukaan**
    /// (surface stepping) sementara teksnya tetap jelas.
    ///
    /// **Tapi ini menimbulkan janji yang harus dijaga:** pada mode malam
    /// kapsul **tidak membawa warna nada**, jadi kelimanya tidak lagi
    /// berbeda satu sama lain. Konsekuensinya, badge keyakinan di mode
    /// malam dibedakan lewat **teksnya** ("Yakin" / "Ragu" / "Tidak tahu"),
    /// yang memang sudah ada dan selalu terbaca. Dicatat di sini karena
    /// inilah harga yang dibayar atas Mode Malam.
    static let nightBadge = BadgeFills(
        neutral: SurfaceColor(red: 0.090, green: 0.000, blue: 0.000),
        active: SurfaceColor(red: 0.090, green: 0.000, blue: 0.000),
        success: SurfaceColor(red: 0.090, green: 0.000, blue: 0.000),
        warning: SurfaceColor(red: 0.090, green: 0.000, blue: 0.000),
        danger: SurfaceColor(red: 0.090, green: 0.000, blue: 0.000))
}

// MARK: - Rujukan silang

public extension SurfacePalette {

    /// Permukaan mana pun yang teksnya paling terang, yaitu kasus terburuk
    /// untuk kontras.
    var lightestSurface: SurfaceColor {
        // `surface2` selalu paling terang dalam kedua mode; diuji di
        // `SurfacePaletteTests`, jadi di sini cukup menyebutnya.
        surface2
    }

    /// Palet nada yang menyertainya.
    var tones: TonePalette {
        isNight ? .night : .day
    }

    /// Isi kapsul badge yang menyertainya.
    var badgeFills: BadgeFills {
        isNight ? TonePalette.nightBadge : TonePalette.dayBadge
    }

    /// Mode malam? Ditentukan oleh isi palet, bukan oleh keputusan yang
    /// terpisah: hijau dan biru nol adalah **syarat** mode malam, jadi
    /// pertanyaan "ini mode malam?" punya satu jawaban yang bisa diuji.
    var isNight: Bool {
        background.green == 0 && background.blue == 0
    }
}
