import XCTest

@testable import PointingKit

/// Gerbang mode malam untuk gambar prosedural.
///
/// **Kelas cacat yang dijaga di sini.** `CelestialVisualView` menjanjikan
/// "mode malam benar-benar merah murni -- termasuk pada gambar, bukan hanya
/// pada teks", dan warnanya ditulis satu per satu di view. Sebagian
/// besar dari angka malam itu ternyata **bukan** merah murni: pita terang
/// Bulan menyimpan 77% luminansinya di hijau/biru, cincin Saturnus 63%,
/// kabut Venus 60%. Di layar semuanya terlihat "merah"; hanya menghitungnya
/// yang memperjukannya.
///
/// Dua hal yang tidak bisa diuji dengan membaca kode:
///
/// 1. **Kemurnian.** Hijau & biru harus **nol**. "Sedikit" tidak punya
///    batas yang bisa diuji, jadi hanya "nol" yang punya arti.
/// 2. **Urutan terang.** Mode malam mengorbankan hue secara sengaja,
///    jadi yang tersisa hanyalah terang. Warna malam yang dipilih satu per
///    satu bisa membalik urutan itu -- dan kelihatannya tidak terlihat di
///    layar malam karena semuanya sudah merah semua.
final class NightVisualTests: XCTestCase {

    // MARK: - Kemurnian

    /// Setiap warna gambar harus menjadi **merah murni** di mode malam.
    ///
    /// Dicek terhadap seluruh palet aksen, bukan satu-dua warna yang
    /// terlihat paling penting: kelas cacatnya justru "hampir semua warna
    /// benar", jadi uji yang hanya memeriksa satu warna akan lolos pada
    /// cacat yang nyata.
    func testEveryAccentColourBecomesPureRedAtNight() {
        let accents = CelestialVisual.accents
        // Semua aksen lewat **peta yang sama**. Daftar sengaja tidak
        // menyimpan warna malam di dalam dirinya: begitu satu entri lupa
        // dibungkus, ia diam-diam menguji warna siang dan ujinya tetap
        // hijau. `NightVisual.mapped(_:isShadow:)` adalah satu-satunya jalan.
        let daylit: [(String, CelestialVisual.RGBComponents)] = [
            ("pita Jupiter paling terang", accents.jupiterBandCream),
            ("pita Jupiter paling gelap", accents.jupiterBandRust),
            ("pita Jupiter tengah", accents.jupiterBandTan),
            ("Bintik Merah Besar", accents.jupiterSpot),
            ("cincin Saturnus", accents.saturnRing),
            ("kutub Mars", accents.marsPolarCap),
            ("kabut Venus", accents.venusHaze),
            ("pita terang Bulan", accents.moonLit),
            ("inti Matahari", accents.sunCore),
            ("fotosfer Matahari", accents.sunPhotosphere),
            ("kabut objek langit dalam", accents.deepSky),
        ]
        let shadowed: [(String, CelestialVisual.RGBComponents)] = [
            ("piringan gelap Bulan", accents.moonUnlit),
            ("isi lencana ragu", accents.candidateFill),
        ]
        let named = daylit.map { ($0.0, NightVisual.mapped($0.1, isShadow: false)) }
            + shadowed.map { ($0.0, NightVisual.mapped($0.1, isShadow: true)) }
        XCTAssertEqual(named.count, 13, "seluruh palet aksen harus ikut diuji")

        for (name, night) in named {
            XCTAssertEqual(night.green, 0,
                           "\(name) tidak boleh memancarkan hijau di mode malam "
                           + "-- batang paling sensitif di 498-530nm")
            XCTAssertEqual(night.blue, 0,
                           "\(name) tidak boleh memancarkan biru di mode malam")
            XCTAssertGreaterThan(night.red, 0,
                                 "\(name) harus tetap memancarkan cahaya merah")
        }
    }

    /// Bola planet juga harus tetap murni -- ini menjaga bahwa
    /// `NightVisual.surface` tidak merusak jalur yang sudah benar.
    func testPlanetSpheresStayPureRedAtNight() {
        for planet in CelestialVisual.Planet.allCases {
            for (role, raw) in [("terang", planet.palette.light),
                                ("gelap", planet.palette.dark)] {
                let night = NightVisual.surface(raw)
                XCTAssertEqual(night.green, 0, "\(planet) \(role): hijau harus nol")
                XCTAssertEqual(night.blue, 0, "\(planet) \(role): biru harus nol")
            }
        }
    }

    /// Pengunci cacat lama: warna "merah-ish" yang dipakai versi sebelumnya
    /// **memang** bukan merah murni, dan di layar ia tetap terlihat "merah".
    ///
    ///Uji ini dibuat **hijau** pada kode yang sudah
    /// benar -- ia mengunci angka yang salah supaya ada bukti cacat itu nyata,
    /// bukan sekadar perbedaan rasa.
    func testLegacyHandPickedNightColoursWereNotPureRed() {
        let legacySaturnRing = CelestialVisual.RGBComponents(red: 0.62, green: 0.30, blue: 0.16)
        let legacyMoonLit = CelestialVisual.RGBComponents(red: 0.95, green: 0.85, blue: 0.80)

        XCTAssertGreaterThan(legacySaturnRing.green, 0,
                             "cincin Saturnus lama jelas bukan merah murni")
        XCTAssertGreaterThan(legacyMoonLit.blue, 0,
                             "pita terang Bulan lama jelas bukan merah murni")
        // Porsi luminansi di kanal yang merusak rhodopsin -- inilah angkanya yang
        // membuat cacatnya tidak terlihat dari layar.
        func greenBlueShare(_ c: CelestialVisual.RGBComponents) -> Double {
            let luminance = 0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue
            return (0.7152 * c.green + 0.0722 * c.blue) / luminance
        }
        XCTAssertGreaterThan(greenBlueShare(legacyMoonLit), 0.7,
                             "dua pertiga cahaya pita Bulan lama ada di kanal merusak")
    }

    // MARK: - Urutan terang

    /// Urutan terang harus sama antara siang dan malam.
    ///
    /// Kelas ini sudah dilindungi untuk bola planet
    /// (`testNightModeKeepsBrightnessOrdering`), tapi tidak satu pun uji
    /// menyentuh **aksen** -- dan di situlah bug-nya: pita Jupiter paling
    /// gelap (kanal merah 0.72) punya angka malam 0.43, sementara pita
    /// paling terang (0.85) punya 0.34. Urutannya terbalik tepat di mode
    /// malam.
    func testNightAccentsKeepTheDaylightBrightnessOrdering() {
        let accents = CelestialVisual.accents
        let ordered: [(String, CelestialVisual.RGBComponents)] = [
            ("pita paling gelap", accents.jupiterBandRust),
            ("pita tengah", accents.jupiterBandTan),
            ("pita paling terang", accents.jupiterBandCream),
        ]

        for (lower, higher) in zip(ordered, ordered.dropFirst()) {
            XCTAssertLessThan(lower.1.nightModeBrightness, higher.1.nightModeBrightness,
                              "di siang \(lower.0) harus lebih gelap dari \(higher.0)")
            XCTAssertLessThan(NightVisual.surface(lower.1).red,
                              NightVisual.surface(higher.1).red,
                              "pita Jupiter membalik urutan terang di mode malam: "
                              + "\(lower.0) harus tetap lebih gelap dari \(higher.0)")
        }
    }

    /// Mode malam tidak boleh mengubah **kelas** terang: apa yang terang di
    /// langit tetap terang, hanya warnanya yang hilang.
    func testNightMappingIsMonotonicInDaylightBrightness() {
        // Seluruh rentang kanal merah yang mungkin dipakai palet.
        for step in 0...100 {
            let daylight = Double(step) / 100.0
            let night = NightVisual.surface(
                .init(red: daylight, green: daylight, blue: daylight)).red
            // Monotonik: kecerahan malam tidak boleh turun saat kecerahan
            // siang naik
            if step > 0 {
                let previous = NightVisual.surface(
                    .init(red: daylight - 0.01, green: 0, blue: 0)).red
                XCTAssertGreaterThanOrEqual(night, previous,
                                           "peta kecerahan malam harus monotonik")
            }
        }
    }

    /// Setiap warna aksen harus tetap **terlihat** di malam: kanal merahnya
    /// tidak boleh jatuh ke batas bawah palet malam.
    ///
    /// Alasannya: pada latar merah tua, permukaan dengan kanal merah mendekati
    /// nol menghilang ke latar, dan objeknya berhenti terbaca -- mode malam
    /// membuat bulan lebih sulit dilihat, bukan lebih aman.
    func testNightAccentsStayAboveTheNightBackground() {
        let background = SurfacePalette.night.background
        for (name, raw) in [
            ("cincin Saturnus", CelestialVisual.accents.saturnRing),
            ("pita terang Bulan", CelestialVisual.accents.moonLit),
            ("kutub Mars", CelestialVisual.accents.marsPolarCap),
            ("kabut Venus", CelestialVisual.accents.venusHaze),
        ] {
            let night = NightVisual.surface(raw)
            XCTAssertGreaterThan(night.red, background.red * 3,
                                 "\(name) nyaris hilang ke latar mode malam")
        }
    }

    // MARK: - Bagian gelap

    /// Piringan gelap bulan harus tetap **gelap** di mode malam.
    ///
    /// Ini yang memisahkan `shadow` dari `surface`. Kalau bagian gelap ikut
    /// dipetakan sebagai permukaan, kanal merahnya naik ke 0.44 dan
    /// kontras sabit terhadap gelap jatuh ke 2.99:1 -- di bawah 4.5:1, di
    /// layar yang justru paling dipakai untuk melihat bulan, dan tepat saat
    /// mode malam dipilih supaya penglihatan malam terjaga.
    func testNightShadowKeepsTheMoonPhaseReadable() {
        let accents = CelestialVisual.accents
        let lit = NightVisual.surface(accents.moonLit)
        let unlit = NightVisual.shadow(accents.moonUnlit)

        // Gelap harus tetap jauh lebih gelap dari pita yang menyala.
        XCTAssertLessThan(unlit.red, lit.red * 0.5,
                          "piringan gelap tidak boleh mendekati pita yang menyala")
        // Dan kontrasnya harus tetap memenuhi WCAG AA untuk teks besar/
    /// non-teks, dengan rumus yang sama seperti palet permukaan.
        XCTAssertGreaterThanOrEqual(contrast(lit, unlit), 4.5,
                                    "kontras sabit terhadap gelap runtuh di mode malam")
    }

    /// `shadow` harus **tidak** sama dengan `surface`, dan tidak boleh lebih
    /// terang darinya. Kalau suatu saat keduanya disamakan, pemisahan ini
    /// mati tanpa ada yang mengetahuinya.
    func testShadowIsDarkerThanSurfaceForTheSameColour() {
        let raw = CelestialVisual.accents.moonUnlit
        XCTAssertLessThan(NightVisual.shadow(raw).red, NightVisual.surface(raw).red,
                          "bagian gelap harus lebih redup dari permukaan yang sama")
    }

    // MARK: - Bintang

    /// Konversi B−V → RGB tidak boleh membalik **terang** bintang.
    ///
    /// Mode malam membuang hue, jadi yang tersisa hanyalah terang. Kalau
    /// konversi ini membuat Rigel lebih terang dari Aldebaran, di malam
    /// keduanya menjadi dua titik merah dengan ukuran sama -- dan informasi
    /// yang hilang bukan hanya warna, tapi terang. Urutan yang dijaga di sini
    /// adalah urutan **magnitudo** dari katalog, lewat tabel B−V.
    func testStarColourConversionKeepsCatalogueBrightnessOrdering() {
        // Katalog: paling terang lebih dulu.
        let sirius = CelestialVisual.colorIndex(forStarID: "sirius")
        let betelgeuse = CelestialVisual.colorIndex(forStarID: "betelgeuse")
        let polaris = CelestialVisual.colorIndex(forStarID: "polaris")

        // Sirius (A1, B−V 0.00) harus lebih terang dari Betelgeuse
        // (M1, +1.85) dan Polaris (F7, +0.60).
        let siriusRGB = CelestialVisual.starRGB(forColorIndex: sirius)
        XCTAssertGreaterThan(siriusRGB.luminance, CelestialVisual.starRGB(forColorIndex: betelgeuse).luminance,
                             "Sirius lebih terang dari Betelgeuse, dan harus warnanya lebih terang juga")
        XCTAssertGreaterThan(siriusRGB.luminance, CelestialVisual.starRGB(forColorIndex: polaris).luminance,
                             "Sirius lebih terang dari Polaris")
    }

    /// Tren warna harus benar: B−V naik = warmer, tidak boleh terbalik.
    /// Yang dijaga adalah **tanda**nya, karena warna yang terbalik "cukup
    /// meyakinkan" bagi mata dan tidak akan pernah dilaporkan.
    func testStarColourIsMonotonicInColorIndex() {
        // Monotonik **tidak menurun**, bukan naik ketat: penjepit kanal
        // membuat merah saturasi di 1.0 untuk B-V >= 4.12, jadi sesudah titik
        // itu batang mendatar secara wajar. Yang dijaga adalah arahnya --
        // tidak pernah turun -- supaya tidak ada B-V tinggi yang lebih dingin
        // dari B-V rendahnya.
        let saturation = 1.35
        for step in 0..<20 {
            let a = -0.4 + 0.1 * Double(step)
            let b = a + 0.1
            let low = CelestialVisual.starRGB(forColorIndex: a).red
            let high = CelestialVisual.starRGB(forColorIndex: b).red
            XCTAssertGreaterThanOrEqual(high, low,
                                        "B-V lebih tinggi tidak boleh lebih dingin")
            // Di bawah titik saturasi, kenaikan masih harus terasa.
            if b <= saturation {
                XCTAssertGreaterThan(high, low,
                                     "di bawah saturasi, B-V lebih tinggi harus lebih merah")
            }
        }
        // Kedua ujung tabel nyata harus benar arahnya. Rigel (B-V -0.24) harus
        // lebih BIRU dari Betelgeuse (B-V +1.85). Tanda di kanal biru yang
        // terbalik adalah kelas cacat yang lolos dari membaca kode: warnanya
        // tetap "warna yang benar", hanya tidak sesuai konsensus astronominya.
        XCTAssertGreaterThan(CelestialVisual.starRGB(forColorIndex: -0.24).blue,
                             CelestialVisual.starRGB(forColorIndex: 1.85).blue,
                             "bintang biru harus lebih biru dari bintang merah")
        XCTAssertGreaterThan(CelestialVisual.starRGB(forColorIndex: 1.85).red,
                             CelestialVisual.starRGB(forColorIndex: -0.24).red,
                             "bintang merah harus lebih merah dari bintang biru")
    }

    /// Kanal warna harus selalu berada di 0...1.
    ///
    /// Tanpa penjepit, B-V 1.85 (Betelgeuse) menghasilkan kanal merah
    /// **1,11**. `Color(red:green:blue:)` tidak punya nilai di luar 1, jadi
    /// hasilnya bergantung pada perilaku penjepitan diam-diam milik SwiftUI.
    /// Yang bisa dihitung justru akibatnya: kanal > 1 ikut terangkat pada
    /// luminance, sehingga urutan terang pun ikut berubah.
    func testStarColourStaysInsideChannelRange() {
        for step in 0...40 {
            let index = -0.5 + 0.0625 * Double(step)   // sampai 2.0, melewati batas
            let rgb = CelestialVisual.starRGB(forColorIndex: index)
            for (name, value) in [("merah", rgb.red), ("hijau", rgb.green),
                                  ("biru", rgb.blue)] {
                XCTAssertGreaterThanOrEqual(value, 0, "kanal \(name) < 0 pada B-V \(index)")
                XCTAssertLessThanOrEqual(value, 1, "kanal \(name) > 1 pada B-V \(index)")
            }
        }
    }
}

// MARK: - Utilitas

private extension CelestialVisual.RGBComponents {
    /// Luminansi relatif Rec.709.
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }
}

// MARK: - Warna kabut objek langit dalam

/// Gerbang warna kabut per morfologi objek langit dalam.
///
/// **Kelas cacat yang dijaga di sini.** Sampai siklus ini seluruh objek
/// langit dalam memakai satu warna (`accents.deepSky`), jadi nebula emisi,
/// nebula planetari, galaksi, dan gugus bola digambar dengan warna yang
/// **sama**. Bentuknya sudah berbeda sejak siklus sebelumnya, tetapi warnanya
/// tetap menyatakan bahwa keenam benda itu satu jenis. Diukur pada render
/// 200 px: hue keenamnya 0.636-0.642 -- praktis satu angka.
///
/// Yang tidak bisa dilihat dengan membaca kode: warna-warna ini bisa
/// **bertabrakan** tanpa ada yang menyadarinya. Versi pertama palet ini
/// membuat `openCluster` (putih-biru) berjarak 0.002 hue dari kabut netral
/// dan `spiralGalaxy` 0.018 dari kabut netral -- artinya "gugus terbuka"
/// dan "galaksi berlengan" tampil nyaris persis sebagai "tidak tahu",
/// sehingga cacatnya kembali dalam bentuk lain: satu warna untuk dua makna
/// yang berlawanan.
///
/// Karena itu jaraknya diukur, bukan dirasakan: setiap warna morfologi
/// harus terpisah jelas dari kabut netral **dan** dari setiap warna
/// morfologi lain. Ambangnya di kanal warna (bukan hue), karena hue tidak
/// terdefinisi untuk warna yang hampir netral -- dan justru di sekitar
/// netral itulah tabrakan yang nyata terjadi.
final class DeepSkyColourTests: XCTestCase {

    private var neutral: CelestialVisual.RGBComponents { CelestialVisual.accents.deepSky }

    /// Jarak terbesar antar kanal -- ukuran "seberapa beda warnanya".
    ///
    /// Sengaja bukan jarak Euclidean dan bukan selisih hue: yang menentukan
    /// apakah dua kabut terbaca berbeda di layar kecil adalah kanal yang
    /// paling berbeda, bukan rata-rata ketiganya.
    private func distance(_ a: CelestialVisual.RGBComponents,
                          _ b: CelestialVisual.RGBComponents) -> Double {
        max(abs(a.red - b.red), max(abs(a.green - b.green), abs(a.blue - b.blue)))
    }

    /// Setiap morfologi punya warnanya sendiri, dan semuanya ada di katalog.
    func testEveryMorphologyHasItsOwnColour() {
        var seen: [DeepSkyCatalogue.Morphology: CelestialVisual.RGBComponents] = [:]
        for morphology in DeepSkyCatalogue.Morphology.allCases {
            let colour = CelestialVisual.deepSkyColour(for: morphology)
            XCTAssertNotEqual(colour, neutral,
                              "\(morphology) memakai warna kabut netral — "
                              + "morfolologi tanpa warna sendiri kembali jadi 'tidak tahu'")
            for (other, otherColour) in seen {
                XCTAssertGreaterThanOrEqual(distance(colour, otherColour), 0.15,
                                            "\(morphology) dan \(other) terlalu mirip "
                                            + "(jarak \(distance(colour, otherColour)))")
            }
            seen[morphology] = colour
        }
        // Keenam kasus harus ikut teruji; kalau enum bertambah, uji ini
        // menangkapnya lewat `allCases` -- angka ini hanya pengunci bahwa
        // daftar yang diuji benar-benar seluruhnya.
        XCTAssertEqual(seen.count, DeepSkyCatalogue.Morphology.allCases.count)
    }

    /// Setiap warna morfologi harus terpisah dari kabut netral.
    ///
    /// Ini arah yang paling mudah hilang: morfologi yang warnanya kebetulan
    /// mirip netral akan tampil sebagai "tidak tahu" di layar, dan tidak ada
    /// teks yang bisa membedakannya -- kecuali nama objeknya, yang justru
    /// sedang tidak boleh diklaim.
    func testEveryMorphologyColourIsDistinctFromTheNeutralFog() {
        for morphology in DeepSkyCatalogue.Morphology.allCases {
            let colour = CelestialVisual.deepSkyColour(for: morphology)
            XCTAssertGreaterThanOrEqual(distance(colour, neutral), 0.15,
                                        "\(morphology) terlalu dekat dengan kabut netral "
                                        + "(jarak \(distance(colour, neutral)))")
        }
    }

    /// Morfologi yang **tidak boleh diklaim** harus jatuh ke kabut netral.
    ///
    /// Warna adalah klaim jenis yang sama dengan bentuk: nebula merah muda di
    /// sebelah badge "Ragu" menyatakan "ini nebula emisi" sama kerasnya
    /// dengan menggambar cangkang berongga. Karena itu `nil` -- yang berarti
    /// id tak dikenal **atau** engine belum pasti -- harus menghasilkan
    /// kabut netral, bukan warna salah satu jenis.
    func testUnknownMorphologyFallsBackToTheNeutralFog() {
        XCTAssertEqual(CelestialVisual.deepSkyColour(for: nil), neutral)
    }

    /// Warna kabut tetap merah murni di mode malam.
    ///
    /// Diuji di sini juga, bukan hanya di `testEveryAccentColourBecomesPureRedAtNight`:
    /// warna baru yang tidak masuk daftar uji itu akan lolos tanpa ada yang
    /// menghitungnya -- dan daftar tangan itulah yang membuat warna ke-14
    /// bisa sunyi.
    func testDeepSkyColoursStayPureRedAtNight() {
        var colours = DeepSkyCatalogue.Morphology.allCases.map {
            CelestialVisual.deepSkyColour(for: $0)
        }
        colours.append(CelestialVisual.deepSkyColour(for: nil))
        for (index, day) in colours.enumerated() {
            let night = NightVisual.surface(day)
            XCTAssertEqual(night.green, 0, "warna kabut #\(index): hijau harus nol")
            XCTAssertEqual(night.blue, 0, "warna kabut #\(index): biru harus nol")
            XCTAssertGreaterThan(night.red, 0, "warna kabut #\(index): harus tetap merah")
        }
    }
}

/// Rasio kontras WCAG antara dua warna.
private func contrast(_ a: CelestialVisual.RGBComponents,
                      _ b: CelestialVisual.RGBComponents) -> Double {
    func channel(_ v: Double) -> Double {
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    func relative(_ c: CelestialVisual.RGBComponents) -> Double {
        0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue)
    }
    let lighter = max(relative(a), relative(b))
    let darker = min(relative(a), relative(b))
    return (lighter + 0.05) / (darker + 0.05)
}