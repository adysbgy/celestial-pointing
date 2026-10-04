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