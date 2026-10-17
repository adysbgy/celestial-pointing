import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji token visual untuk keadaan **ragu**.
///
/// **Cacat yang ditutup uji-uji ini.** Lencana "engine belum pasti" digambar
/// oleh `drawCandidateMarker` di `Apps/Shared/CelestialVisualView.swift`.
/// Sebelum token ini pindah ke model, bentuk ikut view dan warnanya
/// `Color.black.opacity(0.55)` — pekat **tanpa** cabang mode malam. Di mode
/// merah (satu-satunya mode yang rhodopsin izinkan: rod ~498-530nm, cahaya
/// >620nm aman) lencana itu jadi satu-satunya piksel di layar yang **tidak**
/// merah. Gerbang warna (Aturan 15) buta terhadapnya: ia menghitung warna
/// prosedural berupa angka, sedangkan `Color.black` adalah nama.
///
/// Uji-uji di bawah mengunci konsekuensi yang bisa diukur: keraguan tidak
/// membawa kanal hijau/biru sama sekali, tetap terbaca di atas objek dan di
/// atas latar malam, dan dibedakan oleh **bentuk**, bukan hue.
final class CandidateMarkerTests: XCTestCase {

    private func brightness(_ c: CelestialVisual.RGBComponents) -> Double {
        c.red * 0.2126 + c.green * 0.7152 + c.blue * 0.0722
    }

    // MARK: - Keraguan tidak boleh diwarnai, apalagi diwarnai biru

    func testUncertainMarkIsPureRedInDayMode() {
        let mark = CandidateMarker.badgeFill(isNight: false)
        XCTAssertEqual(mark.green, 0, accuracy: 1e-12,
                       "keraguan tidak boleh membawa warna kedua")
        XCTAssertEqual(mark.blue, 0, accuracy: 1e-12,
                       "keraguan tidak boleh membawa warna kedua")
    }

    func testNightMarkIsPureRed() {
        let mark = CandidateMarker.badgeFill(isNight: true)
        XCTAssertGreaterThan(mark.red, 0)
        XCTAssertEqual(mark.green, 0, accuracy: 1e-12,
                       "hijau nol persis, bukan 'kecil'")
        XCTAssertEqual(mark.blue, 0, accuracy: 1e-12,
                       "biru nol persis, bukan 'kecil'")
    }

    /// Tanda ragu harus **lebih gelap** dari cincin planet di kedua mode.
    ///
    /// Ia digambar di atas piringan yang bisa saja cincin Saturnus. Tanda
    /// yang lebih terang dari cincinnya terbaca sebagai bagian dari objek —
    /// dan yang paling mungkin dibaca begitu justru tanda yang menyatakan
    /// "benda ini belum pasti".
    func testMarkIsDarkerThanTheRingItCovers() {
        let dayRing = CelestialVisual.accents.saturnRing
        let nightRing = NightVisual.surface(dayRing)
        for (isNight, ring) in [(false, dayRing), (true, nightRing)] {
            let mark = CandidateMarker.badgeFill(isNight: isNight)
            XCTAssertLessThan(brightness(mark), brightness(ring) * 0.8,
                              "tanda ragu (\(isNight ? "malam" : "siang")) "
                              + "tidak cukup gelap untuk terbaca sebagai "
                              + "penanda di atas objeknya")
        }
    }

    /// Tanda ragu harus terlihat sebagai **bentuk** di atas latar malam.
    ///
    /// Sisi gelap yang hampir hitam akan hilang ke latar, dan lencana yang
    /// hilang berarti layar ragu tanpa penanda — persis false confidence.
    func testMarkStaysVisibleOnTheNightBackground() {
        let mark = CandidateMarker.badgeFill(isNight: true)
        let background = SurfacePalette.night.background
        XCTAssertGreaterThan(mark.red, background.red + 0.15,
                             "tanda ragu malam tenggelam ke latar")
    }

    /// Tanda malam harus **lebih terang** dari tanda siang, dengan alasan
    /// yang sama seperti palet lain: latar malam `SurfacePalette.night`
    /// hampir hitam, dan kanal merah lencana siang tenggelam di sana.
    ///
    /// Uji ini ada karena harness `Tools/bukti-mutasi-token-lencana.py`
    /// menemukan celahnya: dengan cabang malam dipaksa mengembalikan merah
    /// siang, ketiga uji lain tetap hijau. Warna lencana memang harus gelap
    /// di kedua mode (supaya terbaca di atas objek), jadi selisihnya harus
    /// dinyatakan di sini — bukan disimpulkan dari "ada cabang `isNight`".
    func testNightMarkIsBrighterThanDayMark() {
        let day = CandidateMarker.badgeFill(isNight: false)
        let night = CandidateMarker.badgeFill(isNight: true)
        XCTAssertGreaterThan(night.red, day.red,
                             "tanda malam harus lebih terang dari tanda "
                             + "siang agar tidak tenggelam ke latar malam")
        // Bukan sekadar selisih kecil: harus terbaca sebagai peningkatan.
        XCTAssertGreaterThan(night.red - day.red, 0.2,
                             "selisih malam/siang terlalu kecil untuk "
                             + "berfungsi sebagai kompensasi latar")
    }

    // MARK: - Tanda tanya: simbol keraguan

    /// Simbol lencana sengaja **tidak** berupa warna. Kalau ia hanya beda
    /// warna, mode malam yang membuang hue akan menghapus satu-satunya
    /// penanda keraguan di gambar.
    func testMarkIsShapedNotJustColoured() {
        XCTAssertEqual(CandidateMarker.glyph, "?")
        XCTAssertGreaterThan(CandidateMarker.diameterFactor, 0.1)
        XCTAssertLessThan(CandidateMarker.diameterFactor, 0.5,
                          "lencana tidak boleh menutupi piringan objek")
    }

    /// Kecerahan tanda tidak bergantung pada objeknya: ia menandai
    /// **keraguan**, bukan ukuran atau terang objek. Dua objek berbeda
    /// dengan keyakinan sama harus menampilkan penanda yang sama.
    func testMarkDoesNotDependOnTheObject() {
        let a = CandidateMarker.badgeFill(isNight: false)
        let b = CandidateMarker.badgeFill(isNight: false)
        XCTAssertEqual(a, b)
    }
}
