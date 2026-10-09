import XCTest
@testable import PointingKit

/// Menguji **klaim** yang dibuat brief UX: kontras teks ≥ 4.5:1 (WCAG AA).
///
/// Uji kontras yang tidak pernah merah bukan bukti apa pun — ia hanya
/// membuktikan bahwa angka yang sudah benar tetap benar. Karena itu satu uji di
/// sini sengaja dipatok **melebihi** ambang WCAG dengan alasan yang tercatat:
/// secondary yang pas di 4.5:1 tepat di batas akan terlihat redup di layar jam
/// yang sangat redup, dan batas itu tidak memperhitungkan keterbacaan di bawah
/// kondisi penglihatan yang justru jadi use case utama produk ini.
final class SurfacePaletteTests: XCTestCase {

    // MARK: - Kebenaran perhitungan

    func testContrastRatioIsSymmetricAndBounded() {
        let a = SurfaceColor(red: 0.1, green: 0.1, blue: 0.1)
        let b = SurfaceColor(red: 0.9, green: 0.9, blue: 0.9)
        XCTAssertEqual(a.contrastRatio(against: b),
                       b.contrastRatio(against: a), accuracy: 1e-12)
        // Putih di atas hitam = 21:1, nilai tertinggi WCAG.
        XCTAssertEqual(SurfaceColor(red: 1, green: 1, blue: 1)
                        .contrastRatio(against: SurfaceColor(red: 0, green: 0, blue: 0)),
                       21, accuracy: 1e-9)
        // Warna yang sama dengan dirinya sendiri = 1:1, tidak boleh nol atau
        // negatif (kelekuan float bisa membuat pembagiannya tidak stabil).
        XCTAssertEqual(a.contrastRatio(against: a), 1, accuracy: 1e-12)
    }

    /// Menahan regresi ke "luminance rata-rata".
    ///
    /// Abu tengah 0.5 sRGB punya kecerahan relatif ~0.214, bukan ~0.5. Kalau
    /// transfer non-linier dihilangkan, luminance-nya jadi 0.5 dan rasio
    /// kontras terhadap hitam terhitung 10.4:1 — padahal benar-benar hanya
    /// 4.6:1. Kesalahan 2.2× itu cukup untuk membuat teks 8pt lolos ambang
    /// WCAG padahal di layar ia nyaris tak terbaca. Ini persis kesalahan yang
    /// paling mungkin dibuat, jadi ia dipatok di sini.
    func testLuminanceAppliesNonLinearTransferNotAverage() {
        let midGrey = SurfaceColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(midGrey.relativeLuminance, 0.2140, accuracy: 0.001)
        XCTAssertLessThan(midGrey.relativeLuminance, 0.5)
    }

    // MARK: - Klaim yang dibuat brief

    func testDayPaletteMeetsWCAGAAOnEverySurfaceItSitsOn() {
        XCTAssertGreaterThanOrEqual(
            SurfacePalette.day.weakestTextContrast,
            SurfacePalette.minimumTextContrast,
            "Teks harian harus terbaca di latar, kartu, dan kartu tingkat dua")
    }

    func testNightPaletteMeetsWCAGAAOnEverySurfaceItSitsOn() {
        XCTAssertGreaterThanOrEqual(
            SurfacePalette.night.weakestTextContrast,
            SurfacePalette.minimumTextContrast,
            "Teks mode malam harus terbaca di latar, kartu, dan kartu tingkat dua")
    }

    /// Mode malam **tidak boleh** hanya "cukup kontras" — ia juga tidak boleh
    /// menyiarkan hijau/biru sedikit pun, karena itu justru bagian yang
    /// membatalkan alasan mode malam ada.
    func testNightPaletteContainsNoGreenOrBlueAtAll() {
        let night = SurfacePalette.night
        let all: [SurfaceColor] = [
            night.background, night.surface1, night.surface2,
            night.textPrimary, night.textSecondary,
            night.accentStart, night.accentEnd,
        ]
        for color in all {
            XCTAssertEqual(color.green, 0, " hijau harus nol, bukan diredupkan")
            XCTAssertEqual(color.blue, 0, " biru harus nol, bukan diredupkan")
        }
    }

    // MARK: - Surface stepping

    func testSurfaceSteppingGoesDeeperToNearer() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let steps = palette.surfaceSteps
            XCTAssertGreaterThan(steps.backgroundTo1, 0,
                "\(name): kartu harus lebih terang dari latar")
            XCTAssertGreaterThan(steps.surface1To2, 0,
                "\(name): lapisan ketiga harus lebih terang dari kartu")
        }
    }

    /// Di kanvas gelap, bayangan tidak terlihat — kedalaman hanya bisa datang
    /// dari perbedaan kecerahan. Kalau langkah-langkahnya sekecil itu, kartu dan
    /// latar praktis satu bidang.
    func testSurfaceSteppingIsBigEnoughToSeeInTheDark() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let steps = palette.surfaceSteps
            XCTAssertGreaterThan(steps.backgroundTo1, SurfacePalette.minimumVisibleSurfaceStep,
                "\(name): selisih kecerahan kartu-latar terlalu tipis untuk terlihat")
            XCTAssertGreaterThan(steps.surface1To2, SurfacePalette.minimumVisibleSurfaceStep,
                "\(name): selisih kecerahan lapisan ketiga-kartu terlalu tipis")
        }
    }

    /// **Komposisi alpha benar-benar dihitung, bukan dikira-kira.**
    ///
    /// Operasi ini punya satu bentuk yang paling mudah salah: menganggap
    /// `alpha` di atas latar **terang** sama dengan `alpha` di atas latar
    /// **gelap**. Yang benar adalah campuran linier, dan karena kontras
    /// bergantung pada latar, dua hasilnya bisa berbeda jauh.
    ///
    /// Uji ini menahan bentuk salah itu di sumbernya, karena `composited` akan
    /// dipakai untuk membuktikan cacat nyata di bawah — kalau operasinya
    /// sendiri salah, bukti itu tidak berarti apa-apa.
    func testCompositingIsLinearAndDependsOnTheBackdrop() {
        let tone = SurfaceColor(red: 0.94, green: 0.47, blue: 0.27)
        let dark = SurfaceColor(red: 0.039, green: 0.039, blue: 0.059)
        let light = SurfaceColor(red: 0.9, green: 0.9, blue: 0.9)

        let overDark = tone.composited(over: dark, alpha: 0.12)
        XCTAssertEqual(overDark.red, 0.12 * 0.94 + 0.88 * 0.039, accuracy: 1e-12)
        XCTAssertEqual(overDark.green, 0.12 * 0.47 + 0.88 * 0.039, accuracy: 1e-12)

        // Latar mengubah hasilnya — inilah kenapa warna ini tidak boleh
        // "dikira" tanpa menghitung latarnya.
        let overLight = tone.composited(over: light, alpha: 0.12)
        XCTAssertGreaterThan(overLight.red, overDark.red)
        XCTAssertNotEqual(overLight, overDark)

        // Alpha penuh = warnanya sendiri; alpha nol = latarnya sendiri.
        XCTAssertEqual(tone.composited(over: dark, alpha: 1), tone)
        XCTAssertEqual(tone.composited(over: dark, alpha: 0), dark)
    }

    /// **Regresi: kartu yang membangun latarnya sendiri dari warna nada.**
    ///
    /// Kartu tahap kalibrasi pernah menggambar dirinya dengan
    /// `tone.color.opacity(0.12)` di atas latar, bukan dari token permukaan.
    /// Di mode malam, nada paling redup yang benar-benar dipakai tahap
    /// (`.neutral`, merah 0.94) di atas latar malam menghasilkan merah ~0.152 —
    /// **di atas plafon kontras** mode malam (`surface2 * 1.12` ≈ 0.101), jadi
    /// teksnya yang berwarna nada yang sama jatuh ke **4.32:1**, di bawah
    /// ambang 4.5 yang brief nyatakan.
    ///
    /// Yang diuji di sini bukan angka satu warna, melainkan bahwa **konvensi
    /// itu sendiri keluar dari token**: nada apa pun, di atas latar mode malam,
    /// menghasilkan warna yang tidak ada di palet — sehingga kontrasnya tidak
    /// pernah dijamin. Itu sebabnya perbaikannya mengarah ke `surfaceCard`,
    /// bukan ke nilai alpha yang lebih kecil (yang hanya akan menyembunyikan
    /// cacat yang sama sampai nada berikutnya ditambahkan).
    func testAToneTintedCardBackgroundCannotBeTrustedForContrast() {
        let night = SurfacePalette.night
        let tone = TonePalette.night.neutral
        let tinted = tone.composited(over: night.background, alpha: 0.12)

        // Warnanya bukan permukaan mana pun yang kontrasnya sudah diuji.
        XCTAssertNotEqual(tinted, night.surface1)
        XCTAssertNotEqual(tinted, night.surface2)
        // Dan ia lebih terang dari lapisan terdalam, jadi hierarki permukaan
        // terbalik: kartu paling tidak penting justru paling menyala.
        XCTAssertGreaterThan(tinted.red, night.surface2.red,
            "kartu bernada lebih terang dari lapisan terdalam — hierarki permukaan terbalik")

        // Akibat yang sebenarnya: teks nada itu di atas latarnya sendiri.
        let ratio = tone.contrastRatio(against: tinted)
        XCTAssertLessThan(ratio, SurfacePalette.minimumTextContrast,
            "kalau ini tidak lagi merah, cacatnya sudah tertutup — dan uji ini "
            + "harus diganti, bukan dihapus")
    }

    /// Dan konvensi yang **benar** — `surfaceCard` — memang menahan kontras
    /// untuk seluruh nada, di kedua mode. Ini pasangan positif dari uji di
    /// atas: bukan cuma "yang salah itu salah", tapi "yang benar itu benar".
    func testTheSurfaceTokenPathHoldsContrastForEveryTone() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            for tone in PointingTone.allCases {
                let card = palette.surface1
                let ratio = palette.tones.color(for: tone).contrastRatio(against: card)
                XCTAssertGreaterThanOrEqual(ratio, SurfacePalette.minimumTextContrast,
                    "\(name) \(tone): \(ratio):1 di atas kartu surface1 < 4.5")
            }
        }
    }

    /// Latar **bukan** pure black, dan hari selalu **sejuk** (biru > merah).
    ///
    /// Di OLED, hitam pekat = piksel mati, dan tidak ada gradasi yang bisa
    /// menggambar kedalaman di atasnya. `#0A0A0F` yang disengaja membiarkan
    /// permukaan di atasnya punya sesuatu untuk naik dari. Catatan: mode
    /// malam tidak punya sifat dingin — ia merah murni, jadi tes dingin
    /// ini hanya berlaku di mode siang.
    func testBackgroundIsNotPureBlackAndDayBackgroundIsCool() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            XCTAssertGreaterThan(palette.background.red, 0.01,
                "\(name): latar hitam pekat mematikan gradien dan kedalaman")
        }
        let day = SurfacePalette.day
        XCTAssertGreaterThan(day.background.blue, day.background.red,
            "siang: latar harus sedikit ke ungu — warna langit malam, bukan abu netral")
        // Mode malam tetap punya pemisah merah, walau tidak "dingin".
        XCTAssertGreaterThan(SurfacePalette.night.background.red,
                             SurfacePalette.night.background.green,
                             "malam: pemisah merah tidak boleh hilang total")
    }

    // MARK: - Pengetasan yang disengaja, dengan alasannya

    /// Secondary **pada ambang** 4.5:1 akan lolos WCAG, tapi di layar jam yang
    /// sangat redup teks sekunder praktis hilang — dan metadata (RA/Dec/mag)
    /// justru lapisan yang paling sering dikorbankan saat UI dirapatkan. Karena
    /// itu ambang lokal lebih ketat dari WCAG, dan alasannya dicatat supaya
    /// tidak nanti "diperbaiki" balik ke 4.5.
    ///
    /// **Catatan fisika yang menjaga ambang ini tetap bermakna:** mode malam
    /// dibatasi 5.25:1 — merah murni di atas hitam *tidak bisa* lebih terang
    /// dari itu, berapa pun layar itu dinaikkan. Jadi "secondary redup" di mode
    /// malam hanya punya ruang kanal merah 1.00 → ~0.93, dan pengetasan di sini
    /// memakai ruang yang benar-benar tersedia, bukan ruang borongan.
    func testSecondaryTextIsMoreThanBarelyLegible() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            XCTAssertGreaterThan(
                palette.textSecondary.contrastRatio(against: palette.surface2),
                SurfacePalette.minimumTextContrast + 0.1,
                "\(name): secondary yang pas di batas WCAG hilang di layar redup")
        }
    }

    /// Menjaga pengetasan di atas tetap punya isi: kalau primary dan secondary
    /// kembar, "secondary" tidak berarti apa-apa dan lapisan petunjuk hilang.
    ///
    /// Yang diuji adalah **perbedaan nyata**, bukan "harus berbeda" yang longgar.
    /// Dan untuk mode malam, perbedaannya diuji dalam kanal yang benar: warna
    /// merah murni dengan hijau/biru nol tidak bisa dibandingkan lewat
    /// luminance penuh tanpa membuat setiap pasangan tampak hampir identik.
    func testSecondaryIsActuallyDistinguishableFromPrimary() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let drop = palette.textPrimary.red - palette.textSecondary.red
            XCTAssertGreaterThan(drop, 0.04,
                "\(name): secondary tidak bisa dibedakan dari primary")
        }
    }

    /// Kontras mode malam memang dibatasi 5.25:1. Ini bukan cacat — itu
    /// konsekuensi fisik dari "merah murni", dan mencatatnya sebagai batas
    /// hampir penting: tanpa itu, orang yang menyukainya akan menaikkan
    /// primary dan menurunkan secondary ke abu pucat demi "kontras", lalu
    /// membatalkan seluruh alasan mode malam ada.
    func testNightModeContrastCeilingIsKnownAndBounded() {
        let ceiling = SurfaceColor(red: 1, green: 0, blue: 0)
            .contrastRatio(against: SurfaceColor(red: 0, green: 0, blue: 0))
        XCTAssertEqual(ceiling, 5.252, accuracy: 0.01,
                       "plafon kontras merah murni di atas hitam harus tetap dalam yang tercatat")
        XCTAssertGreaterThan(SurfacePalette.night.weakestTextContrast, 4.5)
    }

    // MARK: - Latar yang benar-benar digambar

    /// **Regresi: kontras diuji terhadap warna yang tidak pernah muncul di
    /// layar.**
    ///
    /// Latar app bukan `background` datar. Ia gradien dari `surface2` yang
    /// diredupkan di atas `background` — dan gradien itu digambar di balik
    /// **segalanya**, termasuk di belakang kartu. Karena itu satu-satunya
    /// latar yang kartu pernah bertemu bukan `background`, melainkan campuran
    /// di puncak gradien itu.
    ///
    /// Seluruh klaim WCAG di berkas ini dihitung terhadap `background`,
    /// `surface1`, dan `surface2` — tiga warna token. Campuran gradiennya
    /// tidak pernah masuk ke himpunan itu, jadi langkah kartu-latar bisa
    /// menyusut di bawah ambang "terlihat di gelap" tanpa satu pun uji yang
    /// merah. Diukur pada alpha 0.55 (nilai lama): siang **0.0137**, malam
    /// **0.0018**, terhadap ambang 0.02 — malam praktis satu bidang, dan itu
    /// tepat mode yang dipakai di gelap, tempat ambang ini ada untuk bekerja.
    ///
    /// Uji ini menahan alpha atmosfer dari **model**, bukan dari view: view
    /// tidak bisa dijalankan di Linux, jadi angka yang tidak punya nama di
    /// model adalah angka yang tidak bisa dijaga siapa pun.
    func testThePaintedBackdropStillLeavesTheCardAVisibleStep() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let backdrop = palette.backdrop(
                atmosphereAlpha: SurfacePalette.backdropAtmosphereAlpha)
            let step = SurfacePalette.largestChannelGap(from: backdrop, to: palette.surface1)
            XCTAssertGreaterThan(step, SurfacePalette.minimumCardLadderMargin,
                "\(name): kartu tenggelam ke latar gradien (\(step) ≤ "
                + "\(SurfacePalette.minimumCardLadderMargin)) — kedalaman hilang tepat di "
                + "mode yang dipakai di gelap")
        }
    }

    /// Arah kedua dari uji di atas: gradien latar **tidak boleh mati**.
    ///
    /// Menurunkan alpha sampai nol akan membuat uji sebelumnya hijau tanpa
    /// memperbaiki apa pun — kartunya memang lebih terang dari latar datar,
    /// tapi atmosfernya hilang dan rasa premium yang dibeli brief ikut hilang.
    /// Jadi lantainya diuji juga, bukan hanya langit-langitnya.
    ///
    /// Lantainya **satu langkah kuantisasi sRGB**, bukan ambang "langkah
    /// permukaan" yang lebih besar: gradien latar tidak dimaksudkan untuk
    /// dibaca sebagai lapisan, hanya untuk terasa. Yang bisa diklaim tanpa
    /// mengarang ambang baru adalah bahwa puncaknya jatuh di kuantisasi yang
    /// berbeda dari latar — di bawah itu, ia secara literal warna latar.
    func testTheBackdropStillHasAtmosphere() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let backdrop = palette.backdrop(
                atmosphereAlpha: SurfacePalette.backdropAtmosphereAlpha)
            let atmosphere = SurfacePalette.largestChannelGap(
                from: palette.background, to: backdrop)
            XCTAssertGreaterThanOrEqual(atmosphere, SurfacePalette.minimumBackdropAtmosphere,
                "\(name): gradien latar jatuh di bawah satu langkah kuantisasi "
                + "(\(atmosphere) < \(SurfacePalette.minimumBackdropAtmosphere)) — menghapusnya "
                + "adalah cara termudah membuat uji langkah kartu hijau")
        }
    }

    /// Gradien latar bukan permukaan kartu: kalau puncaknya **lebih terang**
    /// dari kartu, hierarki terbalik — latar paling belakang justru paling
    /// menyala, dan "makin dekat ke pengguna makin terang" berhenti benar.
    func testTheBackdropNeverOutshinesTheCards() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let backdrop = palette.backdrop(
                atmosphereAlpha: SurfacePalette.backdropAtmosphereAlpha)
            XCTAssertLessThan(backdrop.red, palette.surface1.red,
                "\(name): puncak latar lebih terang dari kartu — hierarki permukaan terbalik")
        }
    }

    /// Aksen boleh lebih vibrant dari teks, tapi harus tetap bisa
    /// dibedakan dari permukaannya — kalau aksen kontrasnya sama dengan
    /// permukaan, elemen "aktif" jadi tidak terlihat aktif.
    func testAccentStandsOutFromTheBackground() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            XCTAssertGreaterThan(
                palette.accentEnd.contrastRatio(against: palette.background),
                2.0,
                "\(name): aksen tidak terlihat di atas latar")
            XCTAssertGreaterThan(
                palette.accentEnd.contrastRatio(against: palette.surface2),
                2.0,
                "\(name): aksen tidak terlihat di atas kartu")
        }
    }
}