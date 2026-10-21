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
    ///
    /// **Keputusan ini tidak lagi ditulis di sini.** Pemetaan saklar → palet
    /// hidup di `NightPaletteSelector` (PointingKit, teruji di Linux), karena
    /// badan `return NightMode.isOn ? .night : .day` yang dulu tinggal di sini
    /// memilih palet untuk 26 situs (jam + iPhone), hidup di `Apps/` yang tidak
    /// pernah dibangun `swift-test.sh`, dan seluruh mutasinya lolos ke-44
    /// aturan UI — termasuk `return .day`, yang membuat mode malam memancarkan
    /// biru & hijau penuh sementara tombol bulan menyala. Di sini hanya
    /// meneruskan keadaan saklarnya.
    static var active: SurfacePalette {
        NightPaletteSelector.palette(isNightModeEnabled: NightMode.isOn)
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
///
/// **Kepekatan kilau sudah pindah ke model.** `glassSheenOpacity` pernah hidup
/// di sini sebagai `0.10` telanjang, dan angka itu membocorkan kanal hijau/biru
/// ke mode malam (0.000 → 0.042) sekaligus menjatuhkan kontras teks malam ke
/// 4.19:1. Sekarang kepekatannya datang dari
/// `SurfacePalette.glassSheenAlpha(for:)` — teruji di Linux, nol di mode malam.
/// Yang tersisa di berkas ini hanya hal yang memang tidak bisa dihitung.
enum SurfaceTokens {

    /// **Kenapa enum ini sekarang kosong.** Ia dipertahankan sebagai tempat
    /// untuk token lapis app yang benar-benar tidak bisa diuji, bukan sebagai
    /// wadah yang harus diisi. Angka pertama yang pernah tinggal di sini
    /// (`glassSheenOpacity`) ternyata **bisa** diuji — dan setelah diuji, ia
    /// salah. Sebelum menambah token di sini, tanyakan dulu apakah ia bisa
    /// pindah ke `PointingKit`; jawabannya biasanya bisa.
    ///
    /// Enum tanpa case dipakai justru karena itu: ia tidak bisa dipakai
    /// sebagai nilai, jadi satu-satunya isinya adalah konstanta `static`.
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
        SurfacePalette.active.textSecondary.color.opacity(
            SurfacePalette.hairlineOpacity(for: SurfacePalette.active))
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
    // **`appBackground()` sudah dihapus, dan penghapusannya bagian dari
    // perbaikan.** Helper itu tidak pernah dipanggil siapa pun sejak
    // `appBackdrop()` lahir, dan justru dialah bentuk yang menghasilkan cacat
    // Aturan 49: satu baris yang "terlihat benar" (gradien aplikasi), tapi
    // diam-diam tanpa langit berbintang. Selama ia ada, setiap penulis baru
    // punya dua jalan yang sama wajarnya, dan yang salah tidak berbunyi di
    // gerbang mana pun. Yang tersisa hanya satu jalan: `appBackdrop()`.

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
    /// **Urutan lapisnya bagian dari perbaikan, bukan selera.** Versi lama
    /// menaruh kilau sebagai `.overlay` — yaitu **di atas** isi kartu — lalu
    /// dokumentasinya menyatakan material itu "tidak pernah duduk di bawah
    /// teks". Itu kebalikan dari yang dikerjakan kodenya: `.overlay` menggambar
    /// sesudah isi, jadi kilau menyapu teks, dan seluruh klaim kontras yang
    /// dihitung terhadap alas buram tidak lagi berlaku untuk piksel yang
    /// dilihat pengguna. Diukur dengan material = putih penuh pada kepekatan
    /// lama 0.10: teks utama mode malam 5.13 → **4.19**, sekunder 4.67 →
    /// **3.82**, keduanya di bawah ambang 4.5.
    ///
    /// Sekarang kilau duduk **di antara alas dan isi** (`.background` bertingkat):
    /// alas token buram, kilau di atasnya, lalu isi kartu. Teks kembali berada
    /// di atas alas yang kontrasnya sudah diuji, dan yang mendapat kilau adalah
    /// permukaan kosong kartu — persis seperti yang dokumentasi lama klaimkan.
    ///
    /// **Kepekatannya dari model, dan nol di mode malam.** Diatur
    /// `SurfacePalette.glassSheenAlpha(for:)`: 0.10 di siang, **0.0** di malam.
    /// Nol bukan pengecilan angka, melainkan satu-satunya nilai yang sah —
    /// setiap kepekatan > 0 membocorkan kanal 498–530nm ke kartu mode malam
    /// (0.000 → 0.042 pada 0.10), dan merah murni hanya punya plafon kontras
    /// 5.25:1 sehingga tidak ada anggaran untuk membayar hiasan apa pun.
    func surfaceCard(level: SurfaceLevel = .card, radius: CGFloat = 16) -> some View {
        let palette = SurfacePalette.active
        let sheen = SurfacePalette.glassSheenAlpha(for: palette)
        return self
            .background {
                // Dua lapis: alas buram (kontras teruji), lalu kilau di atasnya.
                // Kilau **di sini**, bukan sebagai `.overlay`, supaya ia tidak
                // pernah menyentuh isi kartu.
                level.fill(in: palette)
                    .overlay {
                        if sheen > 0 {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(.ultraThinMaterial.opacity(sheen))
                        }
                    }
            }
            .clipShape(.rect(cornerRadius: radius))
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
        case .overlay: return palette.surface2.color.opacity(SurfacePalette.overlaySurfaceOpacity)
        }
    }
}