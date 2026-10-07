import Foundation

// MARK: - Mode malam untuk gambar prosedural

/// Mode malam untuk setiap bagian gambar -- **satu aturan**, bukan warna per
/// elemen.
///
/// **Kenapa ini ada di `PointingKit`, bukan di view.** Yang diselesaikan mode
/// malam adalah *rhodopsin*, bukan selera: batang (sel rod) paling sensitif
/// di ~498-530nm, sedangkan cahaya >620nm tidak memicu rhodopsin. Layar
/// putih/biru mematikan adaptasi gelap selama 20-40 menit. Jadi "merah
/// murni" bukan istilah yang bisa ditafsirkan longgar -- itu syaratnya, dan
/// syaratnya hanya bisa dijaga di tempat yang bisa diuji.
///
/// **Cacat yang ditutup oleh ini.** `CelestialVisualView` sudah
/// menjanjikan "mode malam benar-benar merah murni -- termasuk pada gambar,
/// bukan hanya pada teks", tapi **10 dari 13** warna gambar yang hidup di
/// mode malam **bukan** merah murni. Semuanya ditulis sebagai "merah-ish"
/// pilihan sendiri:
///
///     cincin Saturnus    (0.62, 0.30, 0.16)
///     pita terang Bulan (0.95, 0.85, 0.80)
///     kabut Venus        (0.72, 0.30, 0.16)
///
/// Di layar mana pun itu akan terlihat "cukup merah". Setelah luminansi
/// dihitung -- satu-satunya cara mengetahuinya -- **dua pertiga** cahaya yang
/// dipancarkan pita terang Bulan berada di kanal yang justru paling merusak
/// penglihatan malam. Dan tidak ada satu pun teks di layar yang memberitahu
/// pengguna.
///
/// Dua aturan yang harus dijaga supaya kelas cacat ini tidak bisa muncul
/// lagi:
///
/// 1. **Murni.** Hijau & biru **nol**, bukan "kecil". "Kecil" hanya terasa
///    benar bagi mata; tidak ada yang menghitungnya.
/// 2. **Urutan terang ikut yang di langit.** Mode malam mengorbankan
///    *hue*, dan itu trade-off yang disengaja. Yang tidak boleh hilang
///    adalah terang-gelap: planet yang paling terang tetap paling terang.
///    Warna "merah-ish" yang dipilih satu per satu melanggar aturan ini
///    diam-diam -- di pita Jupiter, pita paling gelap (kanal merah 0.72)
///    menjadi **lebih terang** dari pita paling terang (0.85), karena
///    angka malamnya ditulis 0.43 vs 0.34. Persis hal yang
///    `testNightModeKeepsBrightnessOrdering` lindungi untuk bola planet,
///    tapi tidak satu pun uji menyentuh aksen.
///
/// Karena itu kecerahan malam **diturunkan dari kanal merah warna siang**,
/// persis seperti bola planet: aturan yang sama, satu definisi "terang".
/// Warna malamnya bukan daftar kedua yang bisa tertinggal -- ia dihitung,
/// jadi tidak mungkin berbeda dari warna siang tanpa ada yang menambah
/// warna kedua.
public enum NightVisual {

    /// Kecerahan terendah untuk permukaan yang harus tetap terlihat.
    ///
    /// Bukan nol: pada latar merah tua, permukaan dengan kanal merah ~0
    /// menghilang ke latar dan objeknya tidak terbaca. Nilainya sama dengan
    /// yang dipakai bola planet, supaya "terang" punya satu arti di seluruh
    /// gambar.
    public static let floorBrightness: Double = 0.35
    /// Bentang kanal merah ke rentang yang terlihat, di atas batas bawah.
    public static let rangeBrightness: Double = 0.65

    /// Satu-satunya jalan dari warna siang ke warna malam.
    ///
    /// Ada sebagai satu fungsi, bukan dua pemanggilan terpisah, karena
    /// kegagalan yang nyata sebelumnya adalah **pemanggil yang salah
    /// memilih**: `shadow(...)` di satu tempat dan `surface(...)` di tempat
    /// lain, tanpa apa pun yang bisa tahu pemanggilnya keliru. Dengan
    /// niat dinyatakan sebagai argumen, "lupa dipetakan" tidak bisa ditulis.
    public static func mapped(_ day: CelestialVisual.RGBComponents,
                              isShadow: Bool) -> CelestialVisual.RGBComponents {
        isShadow ? shadow(day) : surface(day)
    }

    /// Mode malam untuk **permukaan**: memetakan kanal merah ke merah
    /// murni.
    ///
    /// - Parameter day: warna siang. **Hanya kanal merahnya yang dipakai.**
    ///   Hijau dan biru dibuang total -- itulah seluruh isi aturan mode
    ///   malam.
    public static func surface(_ day: CelestialVisual.RGBComponents) -> CelestialVisual.RGBComponents {
        let brightness = floorBrightness
            + rangeBrightness * min(1, max(0, day.nightModeBrightness))
        return .init(red: brightness, green: 0, blue: 0)
    }

    /// Mode malam untuk bagian **gelap** -- piringan bulan yang tidak
    /// menyala, isi lencana ragu.
    ///
    /// **Kenapa bukan `surface`.** Elemen ini bukan permukaan yang perlu
    /// terlihat, melainkan hal yang **tidak memancarkan cahaya**. Memetakan
    /// lewat `surface` akan menaikkan piringan gelap ke kanal merah
    /// 0.44 -- jauh lebih terang dari aslinya, dan kontras sabit versus
    /// gelap runtuh di layar yang justru paling dipakai untuk melihat
    /// bulan (naik ke 0.44 membuat kontrasnya 2.99:1, di bawah 4.5:1).
    /// Yang perlu dijaga justru gelapnya, jadi aturannya terpisah.
    ///
    /// - Parameter day: warna siang; sekali lagi hanya kanal merahnya.
    /// - Returns: merah murni dengan kanal merah setengah dari kanal merah
    ///   siang, supaya tetap terlihat sebagai "gelap" dan bukan lubang hitam
    ///   di atas latar.
    public static func shadow(_ day: CelestialVisual.RGBComponents) -> CelestialVisual.RGBComponents {
        .init(red: min(1, max(0, day.nightModeBrightness)) * shadowFraction,
              green: 0,
              blue: 0)
    }

    /// Pecahan kanal merah siang yang dipertahankan untuk bagian gelap.
    ///
    /// Dijaga lewat kontrasnya terhadap pita yang menyala
    /// (`testNightShadowKeepsTheMoonPhaseReadable`), bukan lewat angka ini
    /// sendiri -- supaya nilainya boleh diubah selama fase bulan masih
    /// terbaca.
    public static let shadowFraction: Double = 0.5
}

// MARK: - Aksen gambar

public extension CelestialVisual {

    /// Warna **siang** untuk setiap detail gambar, sebagai RGB mentah.
    ///
    /// **Kenapa warna aksen ikut pindah ke sini.** Semuanya berada di view,
    /// dan warna malamnya ditulis satu per satu di sebelahnya. Itu dua
    /// kesalahan sekaligus: warnanya bisa tidak murni merah tanpa ada yang
    /// mengetahuinya, dan mengedit aksen siang berarti mengedit *dua* warna
    /// sekaligus -- jadi malamnya bisa tertinggal. Keduanya benar-benar
    /// terjadi: satu warna sudah "merah-ish" bukan merah, dan urutan terang
    /// pita Jupiter terbalik antara siang dan malam.
    ///
    /// Di sini **hanya warna siang yang ada**. Warna malamnya diturunkan
    /// `NightVisual` dari kanal merah yang sama, jadi tidak bisa gagal
    /// bergeser antara siang dan malam tanpa ada yang menambahkan warna kedua.
    struct Accents: Equatable, Sendable {

        // MARK: Jupiter -- pita & Bintik Merah Besar
        /// Pita paling terang (abu-krem).
        public var jupiterBandCream: RGBComponents
        /// Pita paling gelap secara kanal merah.
        public var jupiterBandRust: RGBComponents
        /// Pita tengah (krem gelap).
        public var jupiterBandTan: RGBComponents
        /// Bintik Merah Besar.
        public var jupiterSpot: RGBComponents

        // MARK: Ciri planet lain
        /// Cincin Saturnus.
        public var saturnRing: RGBComponents
        /// Kutub es Mars.
        public var marsPolarCap: RGBComponents
        /// Kabut Venus.
        public var venusHaze: RGBComponents
        /// Dinding kawah Merkurius yang **membelakangi cahaya**.
        ///
        /// **Kenapa ini token, bukan hitam.** Versi pertama menggambar kawah
        /// sebagai satu cakram `Color.black.opacity(0.18)` yang rata. Di
        /// ukuran sebenarnya di jam (38 pt, 76 px @2x) hasilnya terbaca
        /// sebagai **stiker abu-abu yang ditempel** di bola, bukan sebagai
        /// permukaan berkawah — dan Merkurius satu-satunya planet yang ciri
        /// pengenalnya justru kawah.
        ///
        /// Yang membuat sebuah cekungan terbaca sebagai cekungan adalah
        /// **dua sisi yang berlawanan terang-gelap**, bukan gelapnya sendiri.
        /// Sisi yang menghadap cahaya diterangkan `craterRim`, sisi yang
        /// membelakanginya dinaungi token ini. Warnanya sengaja tidak hitam
        /// murni: bayangan di permukaan berdebu tetap memantulkan sedikit
        /// cahaya sekeliling, dan hitam murni di atas abu-abu terbaca sebagai
        /// **lubang**, bukan bayangan.
        public var craterFloor: RGBComponents
        /// Dinding kawah Merkurius yang **menghadap cahaya**.
        ///
        /// Pasangan `craterFloor`. Keduanya bersama-sama yang membuat kawah
        /// terbaca sebagai cekungan; satu saja di antaranya menghasilkan
        /// bercak gelap yang rata. Nilainya dijaga
        /// `testCraterRimIsBrighterThanItsFloor` supaya tidak bisa diam-diam
        /// bertukar atau menempel.
        public var craterRim: RGBComponents
        /// Piringan planet yang **tidak** menyala.
        ///
        /// Terpisah dari `moonUnlit` dengan alasan fisis: sisi gelap Bulan
        /// masih diterangi **earthshine** (cahaya yang dipantulkan Bumi), dan
        /// karena itu cukup terang untuk digambar. Sisi gelap Venus atau
        /// Merkurius tidak punya sumber seperti itu — yang terlihat di
        /// teleskop praktis hitam. Memakai satu nilai untuk keduanya berarti
        /// salah menggambarkan salah satunya, dan tidak ada teks di layar yang
        /// bisa membedakannya.
        public var planetUnlit: RGBComponents

        // MARK: Bulan
        /// Pita yang menyala.
        public var moonLit: RGBComponents
        /// Piringan yang **tidak** menyala -- bagian gelap.
        public var moonUnlit: RGBComponents
        /// Earthshine: cahaya samar di sisi gelap Bulan yang dipantulkan Bumi.
        ///
        /// **Kenapa token sendiri, bukan sekadar `moonUnlit` yang dinaikkan.**
        /// Di teleskop mata telanjang, sisi gelap Bulan saat sabit/celah
        /// terlihat redup tapi **tidak hitam** — Bumi memantulkan sinar
        /// Matahari ke sana. Sisi gelap Venus dan Merkurius (lihat
        /// `planetUnlit`) tidak punya sumber seperti itu dan praktis hitam.
        /// Menggambar bulan tanpa earthshine berarti sisi gelapnya hitam rata,
        /// yang justru terbaca sebagai "lubang" dan bukan sebagai bulan yang
        /// sedang sabit.
        ///
        /// Kelegapannya sengaja jauh di bawah `moonLit` (≈ 1/6) supaya tidak
        /// pernah terbaca sebagai pita yang menyala — earthshine adalah
        /// *sisi gelap yang sedikit bercahaya*, bukan fase kedua. Dan tidak
        /// boleh muncul saat `moonUnlit` penuh (f = 1, tidak ada sisi gelap)
        /// maupun saat fase tak diketahui (kartu ragu tidak menyatakan bulan
        /// sabit). Aturan kehadirannya diuji di Linux
        /// (`testEarthshineOnlyOnPartiallyLitMoon`).
        public var moonEarthshine: RGBComponents
        /// Piringan saat **fase tidak diketahui** (efemeris gagal / arah tak
        /// dihitung) — bukan piringan gelap.
        ///
        /// **Kenapa ini token sendiri, bukan `moonUnlit`.** Sampai siklus ini
        /// fase yang tidak diketahui digambar dengan warna *tidak menyala*,
        /// dan hasilnya **identik piksel demi piksel** dengan bulan baru:
        /// diukur, 0 dari 40.000 piksel berbeda. Bulan baru adalah fakta
        /// tentang langit (f = 0); "tidak tahu" bukan fakta tentang apa pun.
        /// Menggambar yang kedua sebagai yang pertama berarti gambar itu
        /// **menyatakan** bulan baru setiap kali efemeris gagal — dan tidak
        /// ada teks di layar yang membedakannya, karena jam hanya menampilkan
        /// gambar ini di kartu.
        ///
        /// Nilainya harus berada **tegas di antara** `moonUnlit` dan
        /// `moonLit`: cukup terang untuk tidak terbaca sebagai "gelap", cukup
        /// redup untuk tidak terbaca sebagai "menyala". Dijaga
        /// `testPhaseUnknownDiscIsNeitherLitNorUnlit`, jadi ia tidak bisa
        /// diam-diam menempel ke salah satu ujung.
        public var moonPhaseUnknown: RGBComponents

        // MARK: Matahari
        /// Inti fotosfer.
        public var sunCore: RGBComponents
        /// Tepi fotosfer.
        public var sunPhotosphere: RGBComponents

        // MARK: Objek langit dalam & penanda
        /// Kabut nebula/galaksi.
        public var deepSky: RGBComponents
        /// Isi lencana tanda tanya (kandidat).
        public var candidateFill: RGBComponents

        public init(jupiterBandCream: RGBComponents,
                    jupiterBandRust: RGBComponents,
                    jupiterBandTan: RGBComponents,
                    jupiterSpot: RGBComponents,
                    saturnRing: RGBComponents,
                    marsPolarCap: RGBComponents,
                    venusHaze: RGBComponents,
                    craterFloor: RGBComponents,
                    craterRim: RGBComponents,
                    planetUnlit: RGBComponents,
                    moonLit: RGBComponents,
                    moonUnlit: RGBComponents,
                    moonEarthshine: RGBComponents,
                    moonPhaseUnknown: RGBComponents,
                    sunCore: RGBComponents,
                    sunPhotosphere: RGBComponents,
                    deepSky: RGBComponents,
                    candidateFill: RGBComponents) {
            self.jupiterBandCream = jupiterBandCream
            self.jupiterBandRust = jupiterBandRust
            self.jupiterBandTan = jupiterBandTan
            self.jupiterSpot = jupiterSpot
            self.saturnRing = saturnRing
            self.marsPolarCap = marsPolarCap
            self.venusHaze = venusHaze
            self.craterFloor = craterFloor
            self.craterRim = craterRim
            self.planetUnlit = planetUnlit
            self.moonLit = moonLit
            self.moonUnlit = moonUnlit
            self.moonEarthshine = moonEarthshine
            self.moonPhaseUnknown = moonPhaseUnknown
            self.sunCore = sunCore
            self.sunPhotosphere = sunPhotosphere
            self.deepSky = deepSky
            self.candidateFill = candidateFill
        }
    }

    /// Aksen gambar pada mode terang.
    ///
    /// Satu konstanta, bukan konstanta per pemanggil: kalau ada dua salinan,
    /// satu bisa tertinggal saat palet diubah dan tidak ada yang mengetahuinya
    /// -- persis jebakan yang sudah menutupi satu bug warna di siklus lalu.
    static let accents = Accents(
        jupiterBandCream: .init(red: 0.90, green: 0.83, blue: 0.72),
        jupiterBandRust: .init(red: 0.72, green: 0.52, blue: 0.38),
        jupiterBandTan: .init(red: 0.85, green: 0.76, blue: 0.62),
        jupiterSpot: .init(red: 0.85, green: 0.35, blue: 0.25),
        saturnRing: .init(red: 0.86, green: 0.78, blue: 0.60),
        marsPolarCap: .init(red: 0.97, green: 0.95, blue: 0.93),
        venusHaze: .init(red: 0.99, green: 0.96, blue: 0.82),
        // Pasangan cekungan kawah Merkurius. Terangnya sengaja **tidak**
        // memakai `planetUnlit` (0.06) walaupun keduanya sama-sama bayangan:
        // dasar kawah bukan piringan yang tidak menyala, melainkan permukaan
        // berdebu yang tetap memantulkan cahaya sekeliling. Terlalu gelap di
        // sini membuat kawah terbaca sebagai lubang tembus, bukan cekungan.
        craterFloor: .init(red: 0.16, green: 0.155, blue: 0.15),
        // Lebih terang dari `light` Merkurius (0.72/0.70/0.68) supaya dinding
        // yang menghadap cahaya benar-benar menonjol dari bola sekitarnya.
        craterRim: .init(red: 0.86, green: 0.84, blue: 0.81),
        planetUnlit: .init(red: 0.06, green: 0.06, blue: 0.08),
        moonLit: .init(red: 0.97, green: 0.95, blue: 0.90),
        moonUnlit: .init(red: 0.13, green: 0.13, blue: 0.16),
        // Earthshine: sisi gelap Bulan yang disinar Bumi. Jauh di bawah
        // `moonLit` (~1/7) supaya tidak pernah terbaca sebagai pita yang
        // menyala — sisi gelap yang sedikit bercahaya, bukan fase kedua.
        moonEarthshine: .init(red: 0.15, green: 0.15, blue: 0.19),
        // Abu-abu tengah, dan sengaja **bukan** warna bulan yang menyala
        // maupun yang gelap: piringan ini tidak boleh terbaca sebagai salah
        // satu fase. Dijaga `testPhaseUnknownDiscIsNeitherLitNorUnlit`.
        moonPhaseUnknown: .init(red: 0.52, green: 0.52, blue: 0.55),
        sunCore: .init(red: 1.00, green: 0.93, blue: 0.62),
        sunPhotosphere: .init(red: 1.00, green: 0.72, blue: 0.24),
        deepSky: .init(red: 0.72, green: 0.78, blue: 0.95),
        candidateFill: .init(red: 0.10, green: 0.10, blue: 0.13)
    )
}