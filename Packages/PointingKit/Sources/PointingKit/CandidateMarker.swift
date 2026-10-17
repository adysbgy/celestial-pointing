import Foundation

// MARK: - Penanda "engine ragu" pada gambar

/// Warna & bentuk lencana yang menandai **kandidat**, bukan identitas.
///
/// **Kenapa token ini ada di model, bukan di view.** Lencana ini satu-satunya
/// penanda bahwa gambar di sebelahnya **tidak** mengklaim identitas
/// (`CelestialVisualView.isConfirmed == false`). Ia dikerjakan dua hal
/// sekaligus, dan keduanya bisa salah tanpa ada teks di layar yang bisa
/// membantah:
///
/// 1. **Warnanya.** View lama memakai `Color.black.opacity(0.55)` — hitam
///    pekat **tanpa mode malam**. Di mode merah (satu-satunya mode yang
///    rhodopsin izinkan: rod ~498-530nm, cahaya >620nm aman), tanda keraguan
///    jadi satu-satunya piksel yang **tidak** merah di seluruh layar.
///    Gerbang warna (Aturan 15) tidak bisa melihatnya: ia menghitung warna
///    **prosedural** (angka), sedangkan `Color.black` adalah nama.
/// 2. **Bentuknya.** Warna saja tidak cukup. Mode malam membuang hue, jadi
///    lencana yang hanya dibedakan warnanya menghilang bersama hue-nya. Yang
///    tersisa harus **bentuk** — tanda tanya (`glyph`), dengan ukuran yang
///    tidak menutupi piringan objeknya (`diameterFactor`).
///
/// Karena itu warnanya dinyatakan di sini sebagai kanal merah saja, dan
/// kedua mode menghasilkan merah murni: hijau & biru **nol**, bukan "kecil".
public enum CandidateMarker {

    /// Isi lencana, dalam warna **merah murni** di kedua mode.
    ///
    /// - Parameter isNight: mode malam (merah) aktif.
    ///
    /// Siang tetap merah karena (a) merah bukan warna objek mana pun di
    /// palet — Mars paling dekat, tetapi lencana ini digambar **di atas**
    /// objeknya dan bukan pada permukaannya, dan (b) kalau siang memakai
    /// abu-abu, lencana yang sama menjadi dua benda berbeda di dua mode, dan
    /// yang pertama kali lupa diperbarui adalah yang jarang dilihat.
    public static func badgeFill(isNight: Bool) -> CelestialVisual.RGBComponents {
        .init(red: isNight ? nightRed : dayRed, green: 0, blue: 0)
    }

    /// Kanal merah siang.
    ///
    /// Lebih gelap dari `accents.saturnRing` (0.86) dengan margin jauh lebih
    /// besar dari selisih piksel mini, supaya lencana terbaca sebagai penanda
    /// di atas cincin — bukan sebagai bagian dari cincin itu.
    static let dayRed: Double = 0.38

    /// Kanal merah malam. Lebih terang dari kanal merah `SurfacePalette.night`
    /// background supaya lencananya tidak tenggelam ke latar saat mode malam.
    static let nightRed: Double = 0.72

    /// Simbol di dalam lencana.
    ///
    /// Tanda tanya, bukan warna: satu-satunya saluran yang **tidak** dibuang
    /// mode malam.
    public static let glyph = "?"

    /// Diameter lencana, sebagai pecahan dari diameter objek.
    ///
    /// Batas atasnya bukan selera: lencana yang lebih besar dari ~separuh
    /// piringan menutupi ciri yang justru sedang **disamarkan** dan bisa
    /// terbaca sebagai objek lain. Batas bawahnya: lebih kecil dari ini, tanda
    /// tanya tidak terbaca di kartu jam 38pt.
    public static let diameterFactor: Double = 0.28
}
