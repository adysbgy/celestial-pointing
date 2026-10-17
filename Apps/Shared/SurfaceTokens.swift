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
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

extension SurfacePalette {

    /// Palet aktif saat ini — mengikuti mode malam, dibaca ulang tiap
    /// akses supaya `body` SwiftUI yang dievaluasi ulang otomatis ikut berubah.
    static var active: SurfacePalette {
        return NightMode.isOn ? .night : .day
    }

    var backgroundColor: Color { return background.color }
    var surface1Color: Color { return surface1.color }
    var surface2Color: Color { return surface2.color }
    var textPrimaryColor: Color { return textPrimary.color }
    var textSecondaryColor: Color { return textSecondary.color }

    /// Gradien aksen "ruang" → "nebula".
    ///
    /// Hanya untuk elemen **aktif**. Aksen yang dipakai di semua tempat
    /// kehilangan makna "aktif" — dan di produk ini keaktifan justru
    /// informasi yang paling berharga (engine sedang mengukur, atau terkunci).
    var accentGradient: LinearGradient {
        return LinearGradient(
            colors: [accentStart.color, accentEnd.color],
            startPoint: .leading, endPoint: .trailing)
    }

    /// Latar yang benar-benar digambar di balik segalanya.
    ///
    /// `Color` polos, bukan `Material`: material di atas latar yang diketahui
    /// warnanya bisa menggeser kontras ke arah yang tidak diuji, dan
    /// kontras-lah yang sudah kita nyatakan.
    ///
    /// **Kepekatannya dibaca dari model, bukan ditulis di sini.** Angka ini
    /// pernah hidup sebagai literal `0.55` di berkas ini — lapisan yang tidak
    /// bisa dijalankan uji di Linux — sehingga langkah kartu-latar diukur
    /// terhadap token yang bukan latar sebenarnya, dan kartu jam tenggelam ke
    /// atmosfernya sendiri (malam 0.0018 terhadap ambang 0.02) tanpa satu pun
    /// uji merah. Sekarang nilainya di `SurfacePalette.backdropAtmosphereAlpha`
    /// dan dijaga `testThePaintedBackdropStillLeavesTheCardAVisibleStep`.
    static var appBackground: LinearGradient {
        let palette = active
        // Gradien sangat tipis pada latar: cukup untuk terasa seperti
        // atmosfer, tidak cukup untuk mengganggu pembacaan teks.
        return LinearGradient(
            colors: [palette.surface2.color.opacity(SurfacePalette.backdropAtmosphereAlpha),
                     palette.background.color],
            startPoint: .top, endPoint: .bottom)
    }
}

/// Token lapis "kaca" — nilai yang tidak bisa diuji di Linux, jadi dikumpulkan
/// di sini supaya alasannya bisa dibaca di satu tempat, bukan tersebar di view.
enum SurfaceTokens {
    /// Opasitas kilau kaca (`.ultraThinMaterial`) pada kartu.
    ///
    /// **Kenapa rendah, bukan penuh.** Kontras teks 4.5:1 dihitung terhadap
    /// warna token **buram** di bawahnya (teruji di `SurfacePaletteTests`).
    /// Material di opasitas penuh membuat warnanya bergantung latar belakang,
    /// sehingga menggeser luminans efektif di bawah teks melewati ambang —
    /// itulah sebabnya `surfaceCard` aslinya menolak material sama sekali.
    /// Di sini material diletakkan **di atas** alas buram pada opasitas ini,
    /// jadi ia hanya menyapu permukaan kosong kartu sebagai kilau, dan teks
    /// tetap duduk di atas alas buram yang kontrasnya sudah dijamin.
    ///
    /// **Batas yang diakui.** Tidak ada gerbang yang mengukur kontras hasil
    /// render kartu di `Apps/` (hanya model `SurfacePalette` yang diuji), jadi
    /// angka ini adalah pilihan desain, bukan hasil pengukuran perangkat.
    /// Ia sengaja dibuat rendah supaya tidak mengubah klaim kontras yang sudah
    /// lulus; kalau kelak ada gerbang kontras lapisan app, angka ini harus
    /// diukur ulang, bukan diwarisi.
    static let glassSheenOpacity: CGFloat = 0.10
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

/// Ukuran gambar benda langit yang **tidak** mengikuti Dynamic Type.
///
/// **Kenapa di `Apps/Shared/`, bukan di `WatchMetrics`.** `WatchMetrics`
/// tinggal di target jam, jadi iPhone tidak bisa membacanya — dan ukuran
/// ilustrasi onboarding duduk di `OnboardingView` yang dipakai **kedua**
/// platform. Sebelum ini angkanya ditulis dua kali sebagai `64` telanjang di
/// dua cabang `onboardingVisual`, sehingga mengubah satu dan lupa yang lain
/// menghasilkan dua ukuran untuk gambar yang sama tanpa satu pun gerbang
/// berbunyi.
///
/// **Kenapa tidak ikut Dynamic Type.** Ini citra, bukan teks: memperbesarnya
/// bersama `accessibilityLarge` mendorong judul dan tombol keluar layar jam
/// 41mm sebelum kartunya bisa dibaca. Ukuran **teks** di layar ini tetap
/// semantik dan tetap membesar; yang tetap hanyalah gambarnya. Keputusan yang
/// sama sudah tertulis di `WatchMetrics.visualDiameter`.
enum VisualImageMetrics {
    /// Ilustrasi bintang di layar perkenalan. Cukup besar untuk glow dan
    /// spike terbaca sebagai bintang, cukup kecil untuk tidak menyaingi
    /// judul di layar jam terkecil yang didukung.
    static let onboardingIllustrationDiameter: CGFloat = 64
}

// MARK: - Pemakaian

extension View {
    /// Latar aplikasi, dipakai di akar kedua app.
    func appBackground() -> some View {
        background(SurfacePalette.appBackground.ignoresSafeArea())
    }

    /// Paksa skema gelap di seluruh app.
    ///
    /// **Kenapa bukan `nil` saat siang.** Token permukaan (`SurfacePalette`)
    /// sengaja dirancang untuk latar gelap bertingkat (`#0A0A0F`/`#121216`):

    /// teks terang, kartu abu bertingkat, dan kontras 4.5:1 dihitung melawan
    /// latar itu. Meninggalkan skema ke sistem berarti di iPhone yang disetel
    /// terang, `List` dan chrome sistemnya berbalik menjadi putih sementara
    /// token kita mengasumsikan gelap — hasilnya justru kontras yang
    /// berantakan dan rasa yang tidak konsisten. Skema gelap di sini bukan
    /// "mode gelap pilihan", melainkan **kontrak** dengan palet yang sudah
    /// diuji; mode malam (merah) adalah lapisan di atasnya, bukan pengganti.
    func forceDarkScheme() -> some View {
        preferredColorScheme(.dark)
    }

    /// Permukaan kartu: warna yang sudah **diuji**, plus kilau kaca tipis, plus
    /// garis rambut.
    ///
    /// **Lapis, bukan ganti.** Alas kartu tetap warna token **buram** yang
    /// kontrasnya sudah lulus `SurfacePaletteTests` — itu jaminan 4.5:1 untuk
    /// teks. Di atasnya diletakkan `.ultraThinMaterial` pada opasitas rendah
    /// (`SurfaceTokens.glassSheenOpacity`) sebagai kilau "kaca" ala Mobbin/app
    /// premium, lalu garis rambut di lapis paling depan. Material tidak pernah
    /// duduk **di bawah** teks, jadi ia tidak menggeser kontras yang sudah
    /// dihitung — ia hanya memberi rasa frosted pada permukaan kosong kartu.
    ///
    /// Penolakan material di versi lama benar soal kontras; lapisan ini adalah
    /// cara mendapatkan rasa yang sama tanpa membatalkan jaminan itu.
    func surfaceCard(level: SurfaceLevel = .card, radius: CGFloat = 16) -> some View {
        let palette = SurfacePalette.active
        return self
            .background(level.fill(in: palette),
                        in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .fill(.ultraThinMaterial.opacity(SurfaceTokens.glassSheenOpacity))
            )
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