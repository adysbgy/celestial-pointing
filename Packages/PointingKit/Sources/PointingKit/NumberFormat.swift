import Foundation

/// Format angka untuk tampilan.
///
/// **Kenapa berkas ini ada.** Semua baris angka di kedua app — ketinggian,
/// azimut, galat, fraksi Bulan, laju pergelangan — dulu diformat dengan
/// `String(format: "%.1f")` **tanpa `locale:`**. Tanpa `locale:`,
/// `String(format:)` memakai locale proses, dan pemisah desimal ikut ikut:
/// di perangkat berbahasa Indonesia hasilnya `42.5` diikuti derajat, bukan
/// `42,5`.
///
/// Ini bukan soal kerapian. Pemisah desimal adalah bagian dari cara membaca
/// angka, dan di locale yang memakai koma `42.5` dibaca sebagai
///empat ratus dua puluh lima. Jadi baris yang terlihat rapi justru bisa
/// menyatakan besaran yang sepuluh kali lebih besar — tanpa satu pun gerbang
/// di repo ini yang bisa melihatnya, karena gerbang tidak memeriksa isi layar.
public enum NumberFormat {

    /// Bahasa yang dipakai saat bridge belum terpasang.
    ///
    /// Indonesia adalah bahasa UI app ini, jadi nilai bawaan harus memakai
    /// pemisah koma. Bridge yang belum terpasang bukan alasan untuk menampilkan
    /// angka dalam bahasa yang salah untuk pembaca app ini.
    public static let defaultLocaleId = "id_ID"

    /// Sumber bahasa aktif, dipasang sekali oleh app.
    ///
    /// `nonisolated(unsafe)` dan pola pasang/lepas mengikuti `TextLocalization`
    /// persis: bridge dipasang sekali saat app dirancang, dan pola yang sama
    /// membuat uji bisa mengembalikannya ke keadaan semula.
    nonisolated(unsafe) private static var installedLocaleId: String?

    /// Pasang identifier bahasa yang dipakai untuk format angka.
    public static func install(localeId: String) {
        installedLocaleId = localeId
    }

    /// Lepas bridge — untuk uji.
    public static func reset() {
        installedLocaleId = nil
    }

    /// Bahasa yang sedang aktif.
    public static var activeLocaleId: String {
        installedLocaleId ?? defaultLocaleId
    }

    /// Angka desimal, tanpa satuan.
    ///
    /// `localeId` punya nilai bawaan supaya uji bisa menyebutkannya secara
    /// eksplisit, sementara pemanggil app cukup memakai bawaan itu.
    public static func decimal(_ value: Double,
                               fractionDigits: Int,
                               localeId: String = activeLocaleId) -> String {
        String(format: "%.\(fractionDigits)f", locale: Locale(identifier: localeId), value)
    }

    /// Angka desimal dengan satuan derajat.
    public static func degrees(_ value: Double,
                                fractionDigits: Int = 1,
                                localeId: String = activeLocaleId) -> String {
        decimal(value, fractionDigits: fractionDigits, localeId: localeId) + "\u{00B0}"
    }

    /// Derajat **bertanda**, untuk lintang dan declinasi.
    ///
    /// Tanda dicetak di sini, bukan oleh pemanggil: `String(format:)` dengan
    /// `%+` menghasilkan baris yang isinya bukan kalimat, dan di layar yang
    /// pemisah desimalnya harus tetap ikut bahasa.
    public static func signedDegrees(_ value: Double,
                                     fractionDigits: Int = 4,
                                     localeId: String = activeLocaleId) -> String {
        String(format: "%+.\(fractionDigits)f",
               locale: Locale(identifier: localeId), value) + "\u{00B0}"
    }

    /// Derajat per detik, untuk baris laju pergelangan.
    public static func degreesPerSecond(_ value: Double,
                                        fractionDigits: Int = 1,
                                        localeId: String = activeLocaleId) -> String {
        degrees(value, fractionDigits: fractionDigits, localeId: localeId) + "/dtk"
    }

    /// Persentase dari fraksi 0…1.
    ///
    /// Nilainya dikalikan 100 di sini, bukan di setiap pemanggil — kalau tidak,
    /// satu pemanggil lupa dan purnama tampil sebagai `1%`.
    public static func percent(_ fraction: Double,
                               fractionDigits: Int = 0,
                               localeId: String = activeLocaleId) -> String {
        decimal(fraction * 100, fractionDigits: fractionDigits, localeId: localeId) + "%"
    }
}
