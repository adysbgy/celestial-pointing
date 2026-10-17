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
        ///
        /// **Nilainya dinaikkan kontrasnya setelah diukur, dan itu bukan
        /// selera.** Bintik digambar sebagai elips warna rata di atas pita
        /// yang warnanya nyaris sama, dan warnanya dulu `(0.85, 0.35, 0.25)`:
        ///
        ///   - **Di mode malam bintiknya lebih TERANG dari pitanya.** Mode
        ///     malam membuang hue dan hanya menyisakan kanal merah, jadi
        ///     `0.85 → 0.9025` duduk di atas pita paling gelap `0.72 → 0.818`.
        ///     Di layar yang justru paling dipakai untuk mengamati, satu-satunya
        ///     pembeda bintik berbalik arah.
        ///   - **Di mode siang selisih luminansnya 12.8/255 (1.09:1).** Piksel
        ///     bintik di atas pita di bawahnya — jauh di bawah 3:1, jadi di
        ///     mode siang bintiknya hanya bisa ditemukan lewat **ronanya**,
        ///     bukan lewat terangnya.
        ///
        /// Dan tidak satu pun gerbang lama melihatnya: semuanya mengukur
        /// **keberadaan** ciri (`check_planet_features_present` menuntut ≥ 20
        /// piksel kemerahan), **lengkung** gradiennya
        /// (`check_jupiter_spot_keeps_its_curvature`), atau **letaknya**
        /// (`testJupiterSpotIsCenteredNotCornered`) — bukan
        /// keterbacaannya.
        ///
        /// **Kenapa menggelapkan, bukan mencerahkan.** Diukur terhadap pita
        /// yang sama: menggelapkan mencapai selisih 26/255, mencerahkan hanya
        /// 14/255 — plafonnya ada karena bintik harus tetap terbaca sebagai
        /// badai merah, bukan sebagai bayangan. Bintik yang lebih terang dari
        /// pitanya juga terbaca sebagai **pita kedua**, bukan badai.
        ///
        /// **Kenapa 0.52, bukan 0.55.** Yang mengikat bukan keterbacaan siang
        /// melainkan mode malam: `NightVisual.surface` menaikkan kanal merah
        /// ke 0.35…1.0, jadi selisih siang 0.03 menyusut jadi 0.02 di malam.
        /// Ambang uji `testJupiterSpotIsDarkerThanItsOwnBelt` (bintik ≤ 85%
        /// pita, di kedua mode) menuntut kanal merah **≤ 0.53**; 0.52 adalah
        /// langkah cadangan di bawahnya, dan masih ≥ 20/255 lebih gelap dari
        /// pita di bawahnya di render.
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
        /// Sabuk samar Uranus.
        ///
        /// Uranus dikenali justru karena piringannya **nyaris polos**, jadi
        /// sabuk ini harus lebih terang dari permukaannya tetapi **tidak
        /// banyak** — bedanya kecil dengan sengaja. Nilai yang terlalu tinggi
        /// membuat Uranus terbaca sebagai planet berpita seperti Jupiter, yaitu
        /// tingkat rincian yang tidak pernah tampak pada ukuran yang digambar
        /// aplikasi ini.
        public var uranusBand: RGBComponents
        /// Bintik gelap Neptunus (Great Dark Spot).
        ///
        /// Warnanya versi **lebih gelap** dari piringan Neptunus, bukan warna
        /// baru: bintik itu adalah cekungan di permukaan yang sama, dan warna
        /// baru akan membuatnya terbaca sebagai objek yang menempel di atas
        /// bola. Nilainya dijaga `testNeptuneSpotIsDarkerThanItsDisc` supaya
        /// tidak bisa diam-diam berbalik menjadi bercak terang.
        public var neptuneSpot: RGBComponents
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
        /// **Kelegapannya dinaikkan dari 0.15 ke 0.30 setelah diukur, dan itu
        /// bukan selera.** Pada f = 0 kekuatan earthshine `1 - f` = 1.0, jadi
        /// piringan bulan baru **adalah** warna token ini apa adanya. Pada
        /// 0.15 piringan itu terukur **1.32:1** terhadap latar kartu di ukuran
        /// jam (38 px) — di bawah ambang keterbacaan mana pun, dan setara
        /// "kotak kosong": kartu jam yang tidak menyampaikan apa pun. Sapuan
        /// 0.15…0.36 (`Tools/sapu-earthshine.py`, kontras piringan `moon-new`
        /// 38 px terhadap latar #0A0A0F, plus margin kanal merah ke
        /// `moonPhaseUnknown` yang diukur gerbangnya sendiri di 200 px):
        ///
        ///     earthshine   kontras jam   gerbang   margin ke unknown
        ///     0.15           1.32:1      6/6 OK        94/255
        ///     0.24           1.85:1      6/6 OK        71/255
        ///     0.30           2.39:1      6/6 OK        55/255
        ///     0.34           2.80:1      6/6 OK        45/255
        ///     0.36           3.03:1      6/6 OK        40/255
        ///
        /// Seluruh gerbang tetap hijau sampai 0.36, jadi yang mengikat bukan
        /// gerbang melainkan **rasio malam terhadap siang**, yang punya plafon
        /// mutlak 45% dan tembus di **0.37** (terukur 45.32%). Margin kejujuran
        /// ke `moonPhaseUnknown` (jarak kanal merah harus > 25) baru menggigit
        /// di **0.44** — jadi plafon sebenarnya 0.36, ditentukan gerbang malam.
        /// 0.30 dipilih dengan satu langkah cadangan di bawahnya: 2.39:1.
        ///
        /// Sisi fisisnya: cahaya Bumi **paling kuat saat bulan baru** (Bumi
        /// nyaris purnama dilihat dari Bulan), dan "bulan tua dalam pelukan
        /// bulan muda" adalah pengamatan earthshine paling terkenal dengan
        /// mata telanjang. Nilai 0.15 dipilih sebagai "redup" umum, bukan
        /// diukur terhadap kasus bulan baru — yang justru kasus paling terang.
        ///
        /// Yang tetap berlaku: tidak pernah terbaca sebagai pita yang menyala
        /// — earthshine adalah *sisi gelap yang sedikit bercahaya*, bukan fase
        /// kedua (ia masih ≈ 1/3 `moonLit`, jauh di bawahnya). Dan tidak
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
        ///
        /// **Batas bawahnya bergerak, dan itu disengaja.** Yang dijaga bukan
        /// `moonUnlit < moonPhaseUnknown` (perbandingan penuh) melainkan
        /// **jarak** kanal merah ke `moonUnlit` — dulu karena `moonPhaseUnknown`
        /// bisa menempel `moonUnlit` tanpa suara, sekarang karena
        /// `moonEarthshine` yang naik (0.15 → 0.30) memakan ruang di antaranya.
        /// Pada 0.30 jaraknya 55/255 (kanal merah, diukur gerbangnya sendiri);
        /// gerbang `check_unknown_phase_is_not_a_new_moon` (ambang 25) baru
        /// menggigit di earthshine **0.44**. Jadi yang lebih dulu menyerah
        /// bukan jarak ini melainkan plafon malam 45% di 0.37 — dua batas yang
        /// jauh berbeda, dan dua-duanya diukur, bukan ditulis.
        public var moonPhaseUnknown: RGBComponents

        // MARK: Matahari
        /// Inti fotosfer.
        public var sunCore: RGBComponents
        /// Tepi fotosfer.
        public var sunPhotosphere: RGBComponents

        // MARK: Objek langit dalam & penanda
        /// Kabut **netral** — dipakai saat morfologinya tidak boleh diklaim.
        ///
        /// Bukan warna "nebula": ini warna untuk keadaan *tidak tahu*. Ia
        /// dipakai ketika `drawableMorphology` mengembalikan `nil`, yaitu id
        /// yang tidak ada di katalog **atau** engine yang belum pasti. Warna
        /// per morfologi ada di token di bawah; yang ini sengaja tetap ada
        /// supaya keadaan ragu punya warnanya sendiri dan tidak meminjam
        /// warna salah satu jenis objek.
        public var deepSky: RGBComponents
        /// Isi lencana tanda tanya (kandidat).
        public var candidateFill: RGBComponents
        /// Garis lencana & tanda tanyanya.
        ///
        /// Lencana adalah satu benda: isi, garis, dan glif. Isinya dulu diatur
        /// di satu tempat (tanpa cabang mode malam), garisnya di tempat lain
        /// (`PointingTone.warning.color`, di luar palet yang diukur pemeriksa
        /// gambar), jadi bentuknya tidak pernah bisa diuji sebagai satu
        /// kesatuan. Sekarang keduanya aksen, dan keduanya diuji bersama:
        /// garis harus lebih terang dari isinya, isinya lebih gelap dari
        /// cincin yang ditutupinya.
        public var candidateStroke: RGBComponents

        // MARK: Warna kabut per morfologi objek langit dalam
        //
        // **Cacat yang ditutup token-token ini.** Sampai siklus ini seluruh
        // objek langit dalam memakai **satu** warna (`deepSky`, abu-biru
        // 0.72/0.78/0.95). Diukur pada render 200 px: keempat morfologi
        // menghasilkan hue 0.636–0.642 — praktis satu angka. Bentuknya sudah
        // berbeda sejak siklus lalu, tetapi warnanya menyatakan bahwa nebula
        // emisi, nebula planetari, galaksi, dan gugus bola adalah benda yang
        // sama. Dua tinjauan visual independen menyebut hasilnya "kabut yang
        // bisa jadi apa saja" — persis akibat satu warna untuk enam benda.
        //
        // Warnanya **fisis, bukan hiasan**, dan itu yang membuatnya layak
        // jadi token: nebula emisi bersinar dari Hα (merah muda), nebula
        // planetari dari O III (hijau-biru), inti galaksi dan gugus bola
        // didominasi bintang tua (kuning-oranye), sedangkan lengan spiral dan
        // gugus terbuka didominasi bintang muda (biru-putih). Yang digambar
        // karena itu bukan "warna yang bagus", melainkan warna yang dimiliki
        // benda itu karena umur dan komposisi bintangnya.
        //
        // **Aturan keyakinannya sama dengan bentuk.** Warna ini adalah klaim
        // jenis yang sama kuatnya dengan bentuknya: nebula merah muda di
        // sebelah badge "Ragu" menyatakan "ini nebula emisi" sama kerasnya
        // dengan menggambar cangkang berongga. Karena itu warnanya dipilih
        // lewat fungsi yang sama dengan bentuknya (`deepSkyColour(for:)`),
        // yang menerima `nil` saat engine ragu.
        /// Nebula emisi/pantulan (M42, M8, M17) — Hα merah muda.
        public var deepSkyNebula: RGBComponents
        /// Nebula planetari (M27, M57) — O III hijau-biru.
        public var deepSkyPlanetaryNebula: RGBComponents
        /// Galaksi tampak miring (M31, M33) — cahaya bintang tua, krem.
        public var deepSkyGalaxy: RGBComponents
        /// Galaksi berlengan (M51, M101) — bintang muda di lengan, biru.
        public var deepSkySpiralGalaxy: RGBComponents
        /// Gugus terbuka (Pleiades) — bintang muda panas, putih-biru.
        public var deepSkyOpenCluster: RGBComponents
        /// Gugus bola (M13) — bintang tua, kuning-oranye.
        public var deepSkyGlobularCluster: RGBComponents

        public init(jupiterBandCream: RGBComponents,
                    jupiterBandRust: RGBComponents,
                    jupiterBandTan: RGBComponents,
                    jupiterSpot: RGBComponents,
                    saturnRing: RGBComponents,
                    marsPolarCap: RGBComponents,
                    venusHaze: RGBComponents,
                    uranusBand: RGBComponents = .init(red: 0.74, green: 0.90, blue: 0.92),
                    neptuneSpot: RGBComponents = .init(red: 0.16, green: 0.26, blue: 0.62),
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
                    deepSkyNebula: RGBComponents,
                    deepSkyPlanetaryNebula: RGBComponents,
                    deepSkyGalaxy: RGBComponents,
                    deepSkySpiralGalaxy: RGBComponents,
                    deepSkyOpenCluster: RGBComponents,
                    deepSkyGlobularCluster: RGBComponents,
                    candidateFill: RGBComponents,
                    // **Wajib, sengaja.** Sebelumnya parameter ini punya
                    // nilai bawaan amber siang, dan `static let accents`
                    // tidak mengisinya: mode malam diam-diam menggambar garis
                    // amber (0.96/0.70/0.29) — kanal hijau & biru bukan nol —
                    // tanpa satu pun gerbang berbunyi. Nilai bawaan di sini
                    // berarti setiap anggota `Accents` baru bisa lupa diisi
                    // dan tetap kompilasi. Uji
                    // `testNightStrokeComesFromThePaletteToken` menangkapnya.
                    candidateStroke: RGBComponents) {
            self.jupiterBandCream = jupiterBandCream
            self.jupiterBandRust = jupiterBandRust
            self.jupiterBandTan = jupiterBandTan
            self.jupiterSpot = jupiterSpot
            self.saturnRing = saturnRing
            self.marsPolarCap = marsPolarCap
            self.venusHaze = venusHaze
            self.uranusBand = uranusBand
            self.neptuneSpot = neptuneSpot
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
            self.deepSkyNebula = deepSkyNebula
            self.deepSkyPlanetaryNebula = deepSkyPlanetaryNebula
            self.deepSkyGalaxy = deepSkyGalaxy
            self.deepSkySpiralGalaxy = deepSkySpiralGalaxy
            self.deepSkyOpenCluster = deepSkyOpenCluster
            self.deepSkyGlobularCluster = deepSkyGlobularCluster
            self.candidateFill = candidateFill
            self.candidateStroke = candidateStroke
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
        jupiterSpot: .init(red: 0.52, green: 0.14, blue: 0.10),
        saturnRing: .init(red: 0.86, green: 0.78, blue: 0.60),
        marsPolarCap: .init(red: 0.97, green: 0.95, blue: 0.93),
        venusHaze: .init(red: 0.99, green: 0.96, blue: 0.82),
        // Sabuk samar Uranus. Sedikit lebih terang dari permukaan Uranus
        // (0.68/0.85/0.88) supaya sabuknya tampak, tapi bedanya kecil —
        // Uranus dikenali justru karena piringannya nyaris polos.
        uranusBand: .init(red: 0.74, green: 0.90, blue: 0.92),
        // Bintik gelap Neptunus: versi lebih gelap dari piringan Neptunus
        // (0.28/0.42/0.92), bukan warna baru — supaya ia terbaca sebagai
        // cekungan di permukaan, bukan objek yang menempel di atas bola.
        //
        // **Nilai lama (0.16/0.26/0.62) melanggar kalimat itu, dan tidak ada
        // yang memeriksanya sampai uji `testNeptuneSpotIsDarkerThanItsDisc`
        // ada.** Terukur: sisi gelap piringan Neptunus berjumlah 0.66
        // (0.08+0.16+0.42), sedangkan bintiknya 1.04 — **58% lebih terang**
        // daripada permukaan yang dianggap dicukilnya. Yang sampai ke layar
        // karena itu bukan bintik gelap, melainkan bercak terang berwarna
        // lebih muda di tengah piringan, yaitu kebalikan dari ciri pengenal
        // yang membuat Neptunus bisa dibedakan dari Uranus yang sama-sama biru.
        //
        // **Kenapa 0.02, bukan 0.052 (nilai pertama yang lolos uji).** Uji
        // yang sama menguji **mode malam** juga, dan di sana seluruh rentang
        // siang dipetakan ke pita merah sempit `0.35 + 0.65 x` (`floorBrightness`
        // + `rangeBrightness`). Pemetaan itu memampatkan selisih kecil sampai
        // hampir hilang: pada 0.052, bintiknya hanya **4.5% lebih gelap** dari
        // sisi gelap piringan di malam (0.384 lawan 0.402) — praktis tak
        // terlihat di mode yang justru alasan produk ini ada. Pada 0.02
        // selisihnya menjadi ~10% terhadap sisi gelap dan ~32% terhadap sisi
        // **terang** piringan, tempat bintiknya benar-benar digambar.
        //
        // **Batas yang diakui.** Sisi gelap piringan Neptunus sendiri hanya
        // 0.08, dan di malam ia naik ke 0.402 oleh lantai 0.35 — jadi bintik
        // **tidak mungkin** lebih dari ~13% lebih gelap dari piksel tergelap
        // piringan itu (terukur, bintik=0 pun hanya mencapai nisbah 0.871).
        // Angka itu bukan pilihan rasa, melainkan konsekuensi palet malam
        // yang memaksa satu kanal; karena itu uji malamnya memakai sisi
        // **terang** piringan sebagai pembanding (0.658 pada 0.02), bukan
        // mengklaim margin yang tidak bisa ada.
        neptuneSpot: .init(red: 0.02, green: 0.04, blue: 0.105),
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
        // Earthshine: sisi gelap Bulan yang disinar Bumi. **Ini token yang
        // menentukan apakah bulan baru terlihat sama sekali** — pada f = 0
        // kekuatannya 1.0, jadi piringan bulan baru adalah warna ini apa
        // adanya. Nilainya dinaikkan dari 0.15 ke 0.30 setelah diukur: pada
        // 0.15 piringan bulan baru terukur **1.32:1** terhadap latar kartu
        // (38 px) — kotak kosong, bukan bulan. Pada 0.30 ia 2.39:1 dan
        // bentuknya terbaca. Lihat `moonEarthshine` di `Accents` untuk
        // sapuan lengkapnya dan kenapa plafonnya 0.36.
        moonEarthshine: .init(red: 0.30, green: 0.30, blue: 0.37),
        // Abu-abu tengah, dan sengaja **bukan** warna bulan yang menyala
        // maupun yang gelap: piringan ini tidak boleh terbaca sebagai salah
        // satu fase. Dijaga `testPhaseUnknownDiscIsNeitherLitNorUnlit`.
        moonPhaseUnknown: .init(red: 0.52, green: 0.52, blue: 0.55),
        sunCore: .init(red: 1.00, green: 0.93, blue: 0.62),
        sunPhotosphere: .init(red: 1.00, green: 0.72, blue: 0.24),
        deepSky: .init(red: 0.72, green: 0.78, blue: 0.95),
        // Warna kabut per morfologi. Kanan = kanal merah (yang menentukan
        // kecerahan mode malam, lihat `nightModeBrightness`), dan urutan
        // kecerahannya sengaja mengikuti objeknya.
        //
        // **Urutan di bawah diukur, bukan dikira-kira.** Komentar ini sampai
        // siklus ini berbunyi "gugus bola paling terang ... lalu galaksi dan
        // gugus terbuka" — dan separuhnya salah: terukur lewat
        // `NightVisual.surface`, gugus terbuka justru yang **paling terang**
        // (0.967), bukan salah satu dari dua yang paling redup. Ini kelas
        // cacat yang sudah berulang di repo ini (komentar mengutip angka yang
        // tidak pernah ia ukur), jadi sekarang urutannya dijaga uji
        // `testDeepSkyNightBrightnessMatchesTheDocumentedOrdering`.
        //
        // Terukur (kanal merah mode malam, terang -> redup):
        //   gugus terbuka 0.967 > gugus bola 0.955 > nebula emisi 0.922
        //     > galaksi miring 0.883 > kabut netral 0.818
        //     > galaksi spiral 0.662 > nebula planetari 0.623
        //
        // Kenapa urutan ini penting: mode malam membuang seluruh hue, jadi
        // kecerahan adalah satu-satunya kanal tersisa untuk membedakan keenam
        // jenis benda di layar.
        //
        // Hijau & biru tidak boleh nol di sini — warna siang yang netral
        // (merah = hijau = biru) adalah definisi "tidak berwarna", dan
        // seluruh siklus ini ada untuk berhenti memakai satu warna untuk
        // enam benda. Yang menjaga mode malam tetap merah murni bukan angka
        // di sini, melainkan `NightVisual.surface`, yang membuang kedua
        // kanal itu.
        //
        // Satu makna per benda, dan **setiap** warna harus terpisah jelas dari
        // kabut netral di atas — kalau tidak, "gugus terbuka" akan tampil
        // sebagai "tidak tahu" dan cacatnya kembali dalam bentuk lain.
        // Karena itu jaraknya bukan rasa: dijaga `check_deep_sky_colours`
        // (port) dan `testDeepSkyColoursAreDistinct` (model).
        //   nebula emisi      Hα   -> merah muda (merah jauh di atas hijau)
        //   nebula planetari  O III-> cyan (biru & hijau di atas merah)
        //   galaksi miring    tua  -> krem netral-hangat (biru paling rendah)
        //   galaksi spiral    muda -> biru (biru jauh di atas merah)
        //   gugus terbuka     muda -> putih-biru, paling terang
        //   gugus bola        tua  -> kuning-oranye (biru paling rendah)
        deepSkyNebula: .init(red: 0.88, green: 0.44, blue: 0.50),
        deepSkyPlanetaryNebula: .init(red: 0.42, green: 0.78, blue: 0.86),
        deepSkyGalaxy: .init(red: 0.82, green: 0.78, blue: 0.70),
        deepSkySpiralGalaxy: .init(red: 0.48, green: 0.58, blue: 0.96),
        deepSkyOpenCluster: .init(red: 0.95, green: 0.97, blue: 1.00),
        deepSkyGlobularCluster: .init(red: 0.93, green: 0.74, blue: 0.42),
        // **Nilai sengaja netral-merah, bukan `Color.black`.** Lencana ini
        // menandai "engine belum pasti" dan digambar di atas objek yang bisa
        // saja lagi berwarna. `Color.black.opacity(...)` (bentuk lama di view)
        // tidak bisa dipetakan `NightVisual` sama sekali — ia bukan angka —
        // sehingga di mode merah lencananya tetap satu-satunya piksel bukan-
        // merah di layar. Yang sampai ke layar sekarang membaca token ini lewat
        // `CandidateMarker.badgeFill(isNight:)`, yang dijaga
        // `CandidateMarkerTests`.
        candidateFill: .init(red: 0.34, green: 0, blue: 0),
        // Garis & glif lencana ragu. Merah penuh: 0.28 di atas isinya (0.72)
        // supaya cincinnya terbaca sebagai garis di layar jam, bukan menyatu,
        // dan tetap di atas nada malam (`TonePalette.night.warning` 0.982).
        // Pemiliknya di sini, bukan di `CandidateMarker`: gerbang jangkauan
        // aksen hanya menelusuri fungsi di berkas palet ini.
        candidateStroke: .init(red: 1.0, green: 0, blue: 0)
    )

    /// Isi lencana "engine ragu", per mode, dibaca dari token palet.
    ///
    /// **Kenapa di sini, bukan di `CandidateMarker`.** `accents.candidateFill`
    /// adalah warna mentah yang dibaca port Python (`ACCENTS["candidateFill"]`)
    /// dan gerbang paritas malam. Sebelum siklus ini ia **tidak pernah
    /// menggambar**: isi lencana diambil dari konstanta `dayRed`/`nightRed` di
    /// `CandidateMarker`, jadi gerbang jangkauan melaporkannya sebagai warna
    /// mati (25 dari 26) dan CI Linux merah. Gerbang itu menelusuri penutupan
    /// dari **file ini** — nama aksen di view, ditambah aksen di tubuh `func`
    /// yang tinggal di sini — jadi warnanya tinggal di sini pula, satu baris
    /// dari `deepSkyColour(for:)`.
    ///
    /// **Kenapa parameternya `isNight`.** Kedua mode menghasilkan merah murni
    /// (hijau & biru nol persis: mode merah membuang hue, rod ~498-530nm),
    /// tetapi kanal merahnya **berbeda**: latar malam hampir hitam, jadi merah
    /// siang tenggelam di sana (`testNightMarkIsBrighterThanDayMark`). Token
    /// palet adalah nilai siangnya; cabang malam mengembalikan
    /// `CandidateMarker.nightRed` supaya tetap satu pemilik angka.
    static func candidateFill(isNight: Bool) -> CelestialVisual.RGBComponents {
        let day = accents.candidateFill
        if !isNight { return day }
        return .init(red: CandidateMarker.nightRed, green: 0, blue: 0)
    }

    /// Garis & glif lencana ragu, per mode — dibaca view, berdampingan dengan
    /// `candidateFill(isNight:)`.
    ///
    /// **Kenapa accessor-nya di sini, bukan cukup di `CandidateMarker`.** Isi
    /// dan garis lencana adalah satu benda. Kalau garisnya lewat fungsi di
    /// berkas lain, gerbang jangkauan aksen (`check_night_accents_reach_the_view`)
    /// hanya bisa melihat token ini lewat fungsi yang **berkasnya** sama dengan
    /// `Accents`; fungsi di `CandidateMarker.swift` membuat tokennya dilaporkan
    /// mati (diukur: 26 dari 27, `candidateStroke`) walau view memakainya.
    ///
    /// **Kenapa mode siang tetap `TonePalette.day.warning`.** Token di
    /// `ACCENTS` port Python memegang nilai **malam** (merah murni), sedangkan
    /// mode siang memang memakai amber yang sudah dijaga gerbang kontras nada
    /// terhadap `surface2`. Port-nya membaca amber itu dari
    /// `ACCENTS["candidateStroke"]` lewat `_warning_color(False)`; yang dijaga
    /// gerbang paritas adalah **nilai malam**, karena hanya nilai malam yang
    /// bisa salah tanpa terlihat di mode siang.
    static func candidateStroke(isNight: Bool) -> CelestialVisual.RGBComponents {
        let day = accents.candidateStroke
        return isNight ? day : .init(red: TonePalette.day.warning.red,
                                     green: TonePalette.day.warning.green,
                                     blue: TonePalette.day.warning.blue)
    }

    /// Warna kabut untuk sebuah morfologi, atau warna **netral** saat
    /// morfologinya tidak boleh diklaim.
    ///
    /// **Kenapa ini fungsi, bukan `switch` di view.** Warna adalah klaim
    /// jenis yang sama dengan bentuknya — nebula merah muda menyatakan
    /// "nebula emisi" sama kerasnya dengan menggambar cangkang berongga.
    /// Karena itu ia harus menerima `nil` yang sama dengan
    /// `DeepSkyCatalogue.drawableMorphology`, dan lewat gerbang yang sama:
    /// satu tempat, diuji di Linux.
    ///
    /// Versi yang menaruh pemetaan ini di view akan lolos setiap uji model
    /// dan tetap bisa menampilkan warna morfologi di sebelah badge "Ragu" —
    /// gambar yang lebih yakin daripada teksnya, persis yang dilarang PRD.
    static func deepSkyColour(for morphology: DeepSkyCatalogue.Morphology?)
        -> CelestialVisual.RGBComponents {
        let accents = CelestialVisual.accents
        switch morphology {
        case .nebula: return accents.deepSkyNebula
        case .planetaryNebula: return accents.deepSkyPlanetaryNebula
        case .galaxy: return accents.deepSkyGalaxy
        case .spiralGalaxy: return accents.deepSkySpiralGalaxy
        case .openCluster: return accents.deepSkyOpenCluster
        case .globularCluster: return accents.deepSkyGlobularCluster
        case nil: return accents.deepSky
        }
    }
}