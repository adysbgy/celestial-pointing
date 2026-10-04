import SwiftUI
import PointingKit

/// Jembatan dari token warna yang **teruji di Linux** (`PointingKit`) ke
/// SwiftUI di kedua app.
///
/// **Kenapa jembatan ini ada, dan kenapa di `Apps/`.** Nilai warna, urutan
/// surface, dan klaim kontras WCAG semuanya tinggal di `PointingKit` supaya
/// bisa diuji di Linux (`SurfacePaletteTests`). Yang tidak bisa diuji di Linux
/// adalah `Color`, jadi konversinya harus berada di lapisan app. Konsekuensnya
/// ada dua file token, bukan satu: model (teruji) dan jembatan (tidak bisa
/// diuji). Jawaban yang benar bukan menyatukan dua-duanya di satu tempat,
/// tapi memastikan tidak ada warna yang ditulis langsung di view — kalau ada,
/// warna itu lolos dari gate.
extension SurfaceColor {
    /// Konversi ke `Color`. RGB murni, tanpa color space eksotis: semua nilai
    /// di model sudah sRGB 0…1, jadi tidak ada konversi yang bisa menggeser
    /// hasilnya di luar yang sudah diuji.
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

extension SurfacePalette {

    /// Palet aktif saat ini — mengikuti mode malam, dibaca ulang tiap
    /// akses supaya `body` SwiftUI yang dievaluasi ulang otomatis ikut berubah.
    static var active: SurfacePalette {
        NightMode.isOn ? .night : .day
    }

    var backgroundColor: Color { background.color }
    var surface1Color: Color { surface1.color }
    var surface2Color: Color { surface2.color }
    var textPrimaryColor: Color { textPrimary.color }
    var textSecondaryColor: Color { textSecondary.color }

    /// Gradien aksen "ruang" → "nebula".
    ///
    /// Hanya untuk elemen **aktif**. Aksen yang dipakai di semua tempat
    /// kehilangan makna "aktif" — dan di produk ini keaktifan justru
    /// informasi yang paling berharga (engine sedang mengukur, atau terkunci).
    var accentGradient: LinearGradient {
        LinearGradient(colors: [accentStart.color, accentEnd.color],
                       startPoint: .leading, endPoint: .trailing)
    }

    /// Latar yang benar-benar di gambar di balik segalanya.
    ///
    /// `Color` polos, bukan `Material`: material di atas latar yang diketahui
    /// warnanya bisa menggeser kontras ke arah yang tidak diuji, dan
    /// dan kontras-lah yang sudah kita nyatakan.
    static var appBackground: LinearGradient {
        let palette = active
        // Gradien sangat tipis pada latar: cukup untuk terasa seperti
        // atmosfer, tidak cukup untuk mengganggu pembacaan teks.
        LinearGradient(colors: [palette.surface2.color.opacity(0.55), palette.background.color],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Ketebalan garis tipis pemisah kartu.
///
/// Satu token, bukan satu angka per file: jarak garis 1px vs 0.5px
/// terlihat sangat berbeda di layar 1pt Apple Watch dan di iPhone, dan
/// perbedaan itu tidak butuh dua angka yang berbeda — cukup satu angka yang
/// konsisten.
enum Hairline {
    static let width: CGFloat = 0.5
    /// Warna garis: selalu lebih redup dari teks sekunder, jadi garis tidak
    /// pernah terbaca sebagai elemen. Di mode malam garis ikut merah.
    static var color: Color {
        SurfacePalette.active.textSecondary.color.opacity(NightMode.isOn ? 0.35 : 0.18)
    }
}

// MARK: - Pemakaian

extension View {
    /// Latar aplikasi, dipakai di akar kedua app.
    func appBackground() -> some View {
        background(SurfacePalette.appBackground.ignoresSafeArea())
    }

    /// Permukaan kartu: warna yang sudah **diuji**, plus garis rambut.
    ///
    /// Kenapa memakai warna solid dan bukan `.ultraThinMaterial`: material
    /// membuat warnanya bergantung apa yang ada di belakangnya, sehingga
    /// kontras yang kita klaim 4.5:1 tidak lagi bisa dipastikan. Glassmorphism itu
    /// enak dilihat saat warnanya acak; di palet yang sudah kita hitung, ia hanya
    /// mengurangi ketajaman hierarki.
    func surfaceCard(level: SurfaceLevel = .card, radius: CGFloat = 16) -> some View {
        let palette = SurfacePalette.active
        return self
            .background(level.fill(in: palette),
                        in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Hairline.color, lineWidth: Hairline.width)
            )
    }
}

/// Tingkat kedalaman permukaan — tiga lapis, tidak ada lagi.
///
/// Lapisan ekstra yang tidak punya peran hierarki adalah dekorasi, dan
/// dekorasi yang tidak menjelaskan apa pun membuat hierarki jadi lebih sulit
/// dibaca, bukan lebih mudah.
enum SurfaceLevel {
    /// Permukaan paling dalam: kartu utama.
    case card
    /// Satu tingkat di atas: baris terpilih, lapisan progressive disclosure.
    case raised
    /// Di atas `card` — untuk konten yang benar-benar muncul di atas kartu
    /// (chip, tombol segmentasi).
    case overlay

    func fill(in palette: SurfacePalette) -> Color {
        switch self {
        case .card:    return palette.surface1.color
        case .raised:  return palette.surface2.color
        case .overlay: return palette.surface2.color.opacity(0.92)
        }
    }
}