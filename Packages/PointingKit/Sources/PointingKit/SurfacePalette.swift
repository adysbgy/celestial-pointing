import Foundation

/// Model warna **permukaan** — latar, kartu, teks, aksen.
///
/// **Kenapa ini ada di `PointingKit`, bukan di `Apps/`.** Brief UX menyebut
/// syarat "kontras ≥ 4.5:1 (WCAG)". Itu sebuah **klaim numerik**, dan klaim
/// seperti ini tidak bisa dibuktikan dengan membaca kode — harus dihitung. SwiftUI tidak punya WCAG di Linux, jadi kalau palet hanya tinggal di
/// `Apps/`, tukang warna akan bebas mengubah angka dan tidak ada yang memberitahu
/// bahwa teks jadi tidak terbaca. Di sini klaim itu jadi **pernyataan yang
/// diuji**, dan tesnya gagal kalau paletnya rusak.
///
/// Sama seperti palet planet: warnanya milik keputusan produk yang bisa salah
/// tanpa terlihat, jadi ia tidak boleh hanya ada di lapisan yang tidak pernah
/// dijalankan uji.
public struct SurfaceColor: Equatable, Sendable {

    /// Kanal merah, 0…1. Hijau & biru sengaja ada sebagai kanal terpisah
    /// (bukan hanya satu abu) karena mode malam harus bisa **membuang** keduanya
    /// ke nol, dan "abu" tidak bisa dumped ke merah.
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// True bila ketiga kanal identik — abu kelabu asli.
    public var isGrey: Bool {
        red == green && green == blue
    }

    /// Kecerahan relatif WCAG 2.1 — **bukan** luminance yang dikalikan
    /// langsung.
    ///
    /// WCAG tidak memakai rata-rata linier kanal; ia mensyaratkan kanal
    /// sRGB dilewatkan transfer non-linier dulu. Menghilangkan transfer itu membuat
    /// abu gelap tampak jauh lebih terang daripada yang sebenarnya, dan teks
    /// yang "terang" di kalkulasi bisa jadi hampir tidak terlihat di layar.
    public var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red)
             + 0.7152 * channel(green)
             + 0.0722 * channel(blue)
    }
}

extension SurfaceColor {
    /// Rasio kontras WCAG 2.1 antara dua warna, 1…21.
    ///
    /// Simetris dan tidak bisa negatif, jadi aman dipanggil dengan warna yang
    /// lebih terang lebih dulu maupun tidak.
    public func contrastRatio(against other: SurfaceColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        let lighter = Swift.max(a, b)
        let darker = Swift.min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// Satu set token permukaan untuk satu mode tampilan.
///
/// **"Surface stepping"** — kunci rasa premiumnya. Di layar gelap, bayangan
/// tidak terlihat: perbedaan kedalaman harus datang dari **latar yang lebih
/// terang**, bukan dari shadow. Maka tiga lapis: `background` (paling dalam) →
/// `surface1` (kartu) → `surface2` (kartu di atas kartu / baris terpilih). Makin
/// dekat ke pengguna, makin terang.
public struct SurfacePalette: Equatable, Sendable {

    public var background: SurfaceColor
    /// Permukaan kartu.
    public var surface1: SurfaceColor
    /// Permukaan satu tingkat di atas `surface1` — lapisan ketiga untuk
    /// progressive disclosure.
    public var surface2: SurfaceColor
    /// Teks utama. Harus ≥ 4.5:1 terhadap **semua** permukaan di atasnya,
    /// karena teks boleh muncul di kartu mana pun.
    public var textPrimary: SurfaceColor
    /// Teks sekunder (subtitle, satuan, label). Wajib tetap terbaca, jadi
    /// tetap ≥ 4.5:1 — bukan "abu dekoratif".
    public var textSecondary: SurfaceColor
    /// Ujung atas aksen "ruang" → biru ruang.
    public var accentStart: SurfaceColor
    /// Ujung bawah aksen "nebula" → ungu. Gradien hanya untuk elemen **aktif**;
    /// memakainya di mana-mana justru membuat aktif kehilangan artinya.
    public var accentEnd: SurfaceColor
}

extension SurfacePalette {

    /// Palet siang — "surface, bukan pure black".
    public static let day = SurfacePalette(
        background: SurfaceColor(red: 0.039, green: 0.039, blue: 0.059),
        surface1: SurfaceColor(red: 0.071, green: 0.071, blue: 0.086),
        surface2: SurfaceColor(red: 0.106, green: 0.106, blue: 0.133),
        textPrimary: SurfaceColor(red: 0.949, green: 0.957, blue: 0.973),
        textSecondary: SurfaceColor(red: 0.788, green: 0.808, blue: 0.847),
        accentStart: SurfaceColor(red: 0.298, green: 0.490, blue: 1.000),
        accentEnd: SurfaceColor(red: 0.608, green: 0.365, blue: 0.898))

    /// Palet mode malam — **merah murni**.
    ///
    /// Hijau & biru di sini benar-benar nol, bukan diredupkan: batang rod paling
    /// sensitif ~498–530nm, jadi warna di panjang gelombang itu harus hilang
    /// sepenuhnya, bukan tinggal redup.
    ///
    /// **Ramp ini dibatasi oleh fisika, bukan selera.** Merah murni di atas
    /// hitam punya kontras maksimum 5.25:1 (lihat
    /// `SurfaceColor.contrastRatio`). Artinya "teks utama" dan "teks sekunder"
    /// tidak bisa dibedakan jauh — secondary hanya punya ruang kanal merah
    /// 1.00 → 0.95. Konsekuensi yang harus diterima diam-diam: pada mode malam,
    /// **taksonomi** yang membedakan bagian lebih penting daripada terang
    /// versus redup. Kehilangan ini sekarang tercatat dan diuji, bukan
    /// dikomodkan diam-diam oleh pilihan warna.
    ///
    /// Permukaan dinaikkan (0.045 / 0.068 / 0.090) justru karena plafon itu:
    /// semakin gelap permukaannya, semakin dekat ke 5.25:1 teksnya, dan langkah
    /// antarpermukaan harus ≥ 5/255 agar kartu tidak menyatu dengan latar.
    public static let night = SurfacePalette(
        background: SurfaceColor(red: 0.045, green: 0.000, blue: 0.000),
        surface1: SurfaceColor(red: 0.068, green: 0.000, blue: 0.000),
        surface2: SurfaceColor(red: 0.090, green: 0.000, blue: 0.000),
        textPrimary: SurfaceColor(red: 1.000, green: 0.000, blue: 0.000),
        textSecondary: SurfaceColor(red: 0.950, green: 0.000, blue: 0.000),
        accentStart: SurfaceColor(red: 1.000, green: 0.000, blue: 0.000),
        accentEnd: SurfaceColor(red: 1.000, green: 0.000, blue: 0.000))
}

extension SurfacePalette {

    /// Ambang WCAG AA untuk teks normal: 4.5:1.
    public static let minimumTextContrast = 4.5

    /// Rasio kontras terkecil di antara setiap pasangan
    /// (teks, permukaan) yang memang boleh berdekatan.
    ///
    /// Yang **tidak** termasuk di sini: `accent` — aksen adalah warna
    /// identitas, bukan teks, dan rasio teks-ke-aksen tidak dijamin. Menguji
    /// semuanya sekaligus hanya menghasilkan angka yang tidak bermakna.
    public var weakestTextContrast: Double {
        let surfaces = [background, surface1, surface2]
        var worst = Double.infinity
        for text in [textPrimary, textSecondary] {
            for surface in surfaces {
                worst = Swift.min(worst, text.contrastRatio(against: surface))
            }
        }
        return worst
    }

    /// Selisih kecerahan antarpermukaan dalam **sRGB**, bukan dalam luminance.
    ///
    /// Kenapa bukan luminance: pada permukaan mode malam, hijau dan biru nol,
    /// jadi kecerahan relatifnya hanya sekitar seperempat dari abu pada
    /// kanal yang sama. Artinya ambang "langkah terlalu tipis" untuk warna mode
    /// malam harus berbeda dari ambang yang sama untuk abu — kalau tidak, ambang
    /// itu jadi tidak berwarna. Selisih kanal sRGB mengukur "seberapa banyak lebih
    /// terang lapis ini" dalam satuan yang sama dengan yang dilihat mata
    /// (8-bit), jadi satu ambang berlaku untuk semua mode.
    ///
    /// Yang diukur adalah **kanal terbesar**, karena itulah yang mata tangkap:
    /// lapisan yang hanya berbeda 0.005 di kanal yang sudah nol adalah lapisan
    /// yang sama.
    public var surfaceSteps: (backgroundTo1: Double, surface1To2: Double) {
        (largestChannelGap(from: background, to: surface1),
         largestChannelGap(from: surface1, to: surface2))
    }

    /// Ambang "terlihat di gelap" dalam sRGB, ≈5/255.
    ///
    /// Di bawah ~5/255 perbedaan itu hilang di layar OLED yang merender kehitaman
    /// hampir sempurna, dan kartu menyatu dengan latar.
    public static let minimumVisibleSurfaceStep = 0.02

    private func largestChannelGap(from a: SurfaceColor, to b: SurfaceColor) -> Double {
        Swift.max(Swift.abs(b.red - a.red),
                  Swift.max(Swift.abs(b.green - a.green), Swift.abs(b.blue - a.blue)))
    }
}