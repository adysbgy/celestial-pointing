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

    /// Warna ini pada sebagian kepekatan (`alpha`) di atas sebuah latar —
    /// **operasi yang sama** dengan `.opacity(alpha)` SwiftUI, tapi bisa
    /// dihitung dan diuji di Linux.
    ///
    /// **Kenapa ini perlu ada di model, bukan cukup ditulis di view.** Inilah
    /// operasi yang menghasilkan cacat nyata: `tone.color.opacity(0.12)` di
    /// atas latar gelap menghasilkan warna yang **tidak pernah dihitung
    /// siapa pun**. Kontras teks di atasnya jadi tidak diketahui — dan karena
    /// teksnya berwarna nada yang sama dengan latarnya, jarak keduanya
    /// menyusut sampai di bawah ambang, tanpa satu pun gerbang yang menyala.
    ///
    /// Komposisi `alpha` di atas latar **bukan** warna yang sama dengan
    /// `alpha` di atas latar lain. Selama operasi ini tidak punya nama di
    /// model, setiap view yang memakainya mengarang aturan kontrasnya sendiri
    /// di berkas yang tidak diuji. Di sini ia jadi satu fungsi yang bisa
    /// ditahan `TonePaletteTests`.
    public func composited(over backdrop: SurfaceColor, alpha: Double) -> SurfaceColor {
        SurfaceColor(red: alpha * red + (1 - alpha) * backdrop.red,
                     green: alpha * green + (1 - alpha) * backdrop.green,
                     blue: alpha * blue + (1 - alpha) * backdrop.blue)
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
    /// **Latar 0.032, bukan 0.045.** Ia dulu 0.045 supaya kartu (0.068) jelas
    /// di atasnya, tetapi angka itu diukur terhadap latar **datar** — padahal
    /// latar yang digambar adalah gradien `surface2` di atasnya
    /// (`backdropAtmosphereAlpha`). Diukur: tangga 0.045 → 0.068 (0.023) tidak
    /// cukup untuk menampung atmosfer **dan** menyisakan langkah kartu di atas
    /// ambang — disapu dari 0.00 sampai 0.30, **tidak ada** alpha yang lolos
    /// keduanya (pada alpha 0.05 atmosfernya sudah di bawah satu langkah
    /// kuantisasi, sementara langkah kartunya baru 0.0202). Latar 0.032
    /// memperlebar tangga jadi 0.036, dan di situ keduanya muat: atmosfer
    /// 1.63/255, langkah kartu 0.0296.
    ///
    /// Ini juga lebih gelap, dan itu arah yang benar untuk mode malam: lebih
    /// sedikit cahaya merah yang dipancarkan, dengan hierarki yang tetap utuh.
    public static let night = SurfacePalette(
        background: SurfaceColor(red: 0.032, green: 0.000, blue: 0.000),
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

    /// Jarak minimum kartu ke **latar yang benar-benar digambar**.
    ///
    /// Sedikit di atas `minimumVisibleSurfaceStep`, dan sengaja: latar itu
    /// gradien, jadi kartu di puncaknya punya jarak paling tipis, sementara
    /// ambang yang dipakai bergantung pada warna yang tidak pernah berubah —
    /// kalau jarak puncaknya duduk **tepat** di ambang, satu pembulatan sRGB
    /// membuatnya jatuh di bawah tanpa ada yang sengaja mengubah apa pun.
    ///
    /// Mode malam yang mengikat nilainya: tangganya paling pendek
    /// (0.045 → 0.068), jadi ia yang lebih dulu kehabisan ruang saat atmosfer
    /// latar dinaikkan. Diukur: 0.55 → 0.0018 (cacat), 0.10 → 0.0185,
    /// 0.06 → 0.0203. Margin yang dipakai (0.022) memberi 0.0016 di atas
    /// ambang lantai, bukan nol.
    public static let minimumCardLadderMargin = 0.022

    /// Lantai "atmosfer latar terlihat": satu langkah kuantisasi sRGB.
    ///
    /// Sengaja **1/255**, bukan angka yang lebih ambisius. Gradien latar
    /// dibeli untuk rasa, bukan untuk dibaca: yang bisa diklaim tanpa
    /// mengarang ambang baru adalah bahwa puncaknya benar-benar jatuh di
    /// kuantisasi yang berbeda dari latar. Kalau ia lebih kecil dari satu
    /// langkah 8-bit, puncak itu secara literal adalah warna latar.
    ///
    /// Diukur di ambang ini: 0.55 → 0.0407/0.0248 (lolos dengan lebar),
    /// 0.11 → 0.0081/0.0064 (≈2/255 dan 1,6/255, lolos dengan tipis), dan
    /// turun ke ~0.05 akan membuat mode malam gagal — jadi lantai ini memang
    /// mengikat, bukan hiasan.
    public static let minimumBackdropAtmosphere = 1.0 / 255.0

    /// Kepekatan atmosfer latar: `surface2` di atas `background`.
    ///
    /// **Kenapa angka ini pindah ke sini.** Sebelumnya `0.55` hidup di dalam
    /// `appBackground` di `Apps/Shared/SurfaceTokens.swift` — lapisan yang
    /// **tidak bisa dijalankan uji di Linux**. Akibatnya setiap klaim kontras
    /// dan setiap ambang "langkah permukaan" diukur terhadap tiga warna token,
    /// sementara latar yang sungguh-sungguh digambar adalah **campuran** yang
    /// tidak ada di himpunan itu. Kartu jam yang seharusnya "jelas lebih terang
    /// dari latar" tenggelam ke atmosfernya sendiri tanpa satu pun uji merah.
    ///
    /// 0.55 tidak pernah dipilih dengan mengukur langkah kartu-latar; ia
    /// dipilih supaya gradiennya terasa. Diukur: pada 0.55 langkah kartu-latar
    /// tinggal **0.0137** (siang) / **0.0018** (malam) terhadap ambang 0.02,
    /// dan di **kedua** mode puncak gradiennya malah lebih terang dari kartu —
    /// latar paling belakang jadi elemen paling menyala.
    ///
    /// 0.11 dipilih dengan menyapu rentangnya terhadap tiga syarat sekaligus:
    /// langkah kartu > `minimumCardLadderMargin`, atmosfer ≥ 1/255 (satu
    /// langkah kuantisasi, satu-satunya "terlihat" yang bisa diklaim), dan
    /// kartu tetap lebih terang dari puncak latar. Terukur pada 0.11:
    /// langkah 0.0246 (siang) / 0.0296 (malam), atmosfer 2.08/255 dan
    /// 1.63/255, kartu lebih terang di keduanya.
    public static let backdropAtmosphereAlpha = 0.11

    /// Selisih kanal sRGB terbesar antara dua warna.
    ///
    /// Dipakai `surfaceSteps` **dan** pemeriksaan latar: satu definisi
    /// "seberapa banyak lebih terang", supaya ambang yang sama benar-benar
    /// berarti sama di kedua tempat.
    public static func largestChannelGap(from a: SurfaceColor, to b: SurfaceColor) -> Double {
        Swift.max(Swift.abs(b.red - a.red),
                  Swift.max(Swift.abs(b.green - a.green), Swift.abs(b.blue - a.blue)))
    }

    /// Warna di puncak gradien latar — satu-satunya latar yang kartu pernah
    /// bertemu, karena gradien itu digambar di balik segalanya.
    ///
    /// Ada di model, bukan di view, karena view tidak bisa dijalankan di Linux:
    /// warna yang hanya dirakit di view adalah warna yang tidak bisa ditahan
    /// uji apa pun, dan itulah bagaimana `0.55` lolos selama ini.
    public func backdrop(atmosphereAlpha alpha: Double) -> SurfaceColor {
        surface2.composited(over: background, alpha: alpha)
    }

    private func largestChannelGap(from a: SurfaceColor, to b: SurfaceColor) -> Double {
        SurfacePalette.largestChannelGap(from: a, to: b)
    }
}