import XCTest
import CelestialEngine
@testable import PointingKit

/// Bulan **redup** (sabit tipis) di langit gelap: boleh terlihat, tidak boleh
/// digambar seolah purnama, dan tidak boleh ditolak karena alasan yang salah.
///
/// **Kenapa berkas ini ada.** FASE C.6 menyebut tiga tepi kasus kejujuran:
/// objek di bawah horizon, siang hari, dan **bulan redup**. Dua yang pertama
/// sudah punya berkas sendiri (`BelowHorizonHonestyTests`,
/// `MoonDaylightHonestyTests`). Yang ketiga belum — dan ia bukan tepi kasus
/// yang sama, karena arah penolakannya **berlawanan**:
///
/// - Siang hari menolak bulan yang **terang** (sabut siang);
/// - Bulan redup justru yang **paling mungkin lolos** penyaring kecerahan,
///   karena sabit tipis tetap jauh lebih terang dari ambang magnitudo
///   mata telanjang. Yang berbahaya bukan "ditolak", melainkan **diterima
///   lalu digambar salah**: sabit 8% yang dirender sebagai piringan penuh
///   adalah klaim identitas yang tidak dihitung engine — persis yang
///   dilarang PRD v0.4 ("uncertainty > false confidence").
///
/// **Angka yang diukur, bukan diandaikan.** Probe pada 400 hari x 24 jam
/// (Jakarta, 2026-01-15 ke depan) menemukan sabit tipis (fraksi 0,07–0,16)
/// di langit gelap selalu bermagnitudo sekitar −7 sampai −8, sedangkan
/// ambang mata telanjang pada konteks itu ~5,8. Jadi bulan redup **tidak
/// pernah** tersaring `tooFaint`, dan tes yang menuntut `.lock` untuknya
/// akan lulus karena alasan yang salah kalau ambangnya berubah. Karena itu
/// yang dituntut di sini adalah tiga hal yang spesifik:
///
/// 1. penyaring **tidak** menolaknya karena `tooFaint` (bukti positif bahwa
///    redup ≠ tak terlihat);
/// 2. geometri fase yang digambar **sempit** (sabit, bukan gibbous), dan
///    lebarnya **membesar** saat iluminasi naik — bukan angka tetap;
/// 3. earthshine **ada** pada sabit (ada sisi gelap untuk diterangi) tapi
///    **nol** pada purnama — supaya sisi gelap tidak pernah dilukis sebagai
///    "menyala penuh" di jam kecil.
///
/// **Yang TIDAK diklaim.** Tes ini tidak menuntut `.lock`. Keyakinan Bulan
/// sering turun ke `.uncertain` meski arahnya benar (lihat catatan di
/// `BelowHorizonHonestyTests`), dan itu perilaku **benar** menurut PRD.
/// Yang dijaga adalah: apa pun tingkat keyakinannya, **gambar** yang
/// diturunkan dari fase tidak boleh berbohong tentang bentuknya.
final class DimMoonHonestyTests: XCTestCase {

    /// Pengamat Jakarta (WIB, UTC+7) — sama dengan `MoonDaylightHonestyTests`.
    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)

    /// Epok acuan yang sama dengan `MoonDaylightHonestyTests`.
    private let epoch = Date(timeIntervalSince1970: 1_768_453_200)

    private func makeResolver() -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: VisibilityPolicy(),
                         ephemeris: AstronomyKitEphemeris())
    }

    // MARK: - Fixture

    /// Cari saat **langit gelap**, Bulan cukup tinggi untuk ditunjuk, dan
    /// iluminasinya di bawah `maxFraction`.
    ///
    /// Dicari dari resolver, bukan ditulis tangan: fase Bulan adalah hasil
    /// efemeris, dan menebak tanggalnya akan membuat tes vacuous.
    private func dimMoonNightFixture(maxFraction: Double) -> Date? {
        let resolver = makeResolver()
        for day in 0..<400 {
            for hour in stride(from: 0.0, through: 23.5, by: 0.5) {
                let candidate = epoch.addingTimeInterval(Double(day) * 86400 + hour * 3600)
                let context = resolver.skyContext(observer: observer, date: candidate)
                guard context.isDark,
                      let fraction = context.moonIlluminationFraction,
                      fraction > 0, fraction <= maxFraction,
                      let altitude = context.moonAltitudeDeg, altitude > 15
                else { continue }
                return candidate
            }
        }
        return nil
    }

    // MARK: - 1. Redup bukan berarti tak terlihat

    /// Sabit tipis di langit gelap **tidak** ditolak sebagai `tooFaint`.
    ///
    /// Kalau suatu hari penyaring kecerahan diperketat sehingga sabit 8%
    /// ikut tersaring, tes ini merah — dan itu memang yang diinginkan: artinya
    /// aplikasi berhenti bisa menamai Bulan pada malam-malam yang paling
    /// mudah dikenali orang (sabit muda di barat setelah maghrib).
    func testDimMoonIsNotRejectedAsTooFaint() throws {
        let resolver = makeResolver()
        let when = try XCTUnwrap(dimMoonNightFixture(maxFraction: 0.20),
                                 "tidak ada malam dengan Bulan redup di atas 15° dalam 400 hari")

        let context = resolver.skyContext(observer: observer, date: when)
        let fraction = try XCTUnwrap(context.moonIlluminationFraction)
        XCTAssertLessThanOrEqual(fraction, 0.20, "fixture harus benar-benar redup")

        let direction = try XCTUnwrap(resolver.horizontal(ofBody: .moon,
                                                          observer: observer, date: when),
                                      "Bulan harus punya arah pada waktu fixture")
        let resolution = resolver.diagnose(pointing: direction,
                                           observer: observer, date: when, coneDeg: 20.0)

        let rejection = resolution.rejected.first { $0.object.id == "moon" }
        XCTAssertNotEqual(rejection?.visibility, .tooFaint,
                          "sabit \(fraction) masih jauh di atas ambang mata telanjang; "
                          + "menolaknya sebagai tooFaint berarti kehilangan Bulan pada "
                          + "malam yang paling mudah dikenali")
        XCTAssertNotEqual(rejection?.visibility, .belowHorizon,
                          "Bulan berada di atas 15°, jadi bukan belowHorizon")
        XCTAssertNotEqual(rejection?.visibility, .daylight,
                          "langit gelap, jadi bukan daylight")
    }

    // MARK: - 2. Bentuk yang digambar mengikuti fase

    /// Sabit tipis digambar **sempit** dan **bukan** gibbous.
    ///
    /// `phaseGeometry` adalah fungsi murni yang dipakai kanvas; kalau ia
    /// membulatkan fraksi kecil ke piringan penuh (atau menandainya
    /// gibbous), jam akan menampilkan purnama pada malam sabit.
    func testThinCrescentIsDrawnAsCrescentNotFullDisc() throws {
        let resolver = makeResolver()
        let when = try XCTUnwrap(dimMoonNightFixture(maxFraction: 0.20))
        let context = resolver.skyContext(observer: observer, date: when)
        let fraction = try XCTUnwrap(context.moonIlluminationFraction)

        let visual = CelestialVisual(kind: .moon,
                                     illuminationFraction: fraction,
                                     isWaxing: true,
                                     brightLimbAngleRadians: nil,
                                     relativeSize: 1.0)
        let geometry = try XCTUnwrap(visual.phaseGeometry(waxing: true),
                                     "fase dengan fraksi \(fraction) harus bisa digambar")

        XCTAssertFalse(geometry.isGibbous,
                       "fraksi \(fraction) bukan gibbous; menandainya gibbous "
                       + "membalikkan sisi terang pada fase yang paling mudah dikenali")
        // Terminator pada sabit berada di sisi terang, menyisakan pita tipis.
        XCTAssertGreaterThan(geometry.terminatorOffset, 0,
                             "sabit: terminator harus di sisi terang (offset positif)")
        // Lebar pita di ekuator = 1 − offset (satuan radius). Sabit tipis
        // berarti pita jauh lebih sempit dari setengah piringan.
        let bandWidth = 1 - geometry.terminatorOffset
        XCTAssertGreaterThan(bandWidth, 0, "sabit harus punya pita menyala")
        XCTAssertLessThan(bandWidth, 0.5,
                          "pita sabit \(bandWidth) radius tidak boleh selebar piringan penuh")
    }

    /// Lebar sabit **membesar** saat iluminasi naik — bukan angka tetap.
    ///
    /// Tes non-vakum: kalau `phaseGeometry` mengabaikan fraksinya dan selalu
    /// mengembalikan lebar yang sama, kedua perbandingan ini gagal.
    func testCrescentBandWidensWithIllumination() {
        let thin = CelestialVisual.phaseGeometry(fraction: 0.10, waxing: true)
        let thick = CelestialVisual.phaseGeometry(fraction: 0.45, waxing: true)
        let thinBand = 1 - thin.terminatorOffset
        let thickBand = 1 - thick.terminatorOffset
        XCTAssertGreaterThan(thickBand, thinBand,
                             "sabit 45% harus lebih lebar dari sabit 10%")
        XCTAssertFalse(thick.isGibbous, "45% masih sabit, belum gibbous")
        XCTAssertTrue(CelestialVisual.phaseGeometry(fraction: 0.75, waxing: true).isGibbous,
                      "75% gibbous")
    }

    // MARK: - 3. Earthshine tidak pernah mengklaim purnama

    /// Earthshine ada pada sabit, nol pada purnama.
    ///
    /// Pada ukuran jam, sisi gelap yang dilukis terlalu terang akan terbaca
    /// sebagai "piringan menyala penuh". Jadi kekuatannya harus **turun**
    /// saat iluminasi naik, dan tepat nol di purnama.
    func testEarthshineFadesAsMoonApproachesFull() {
        XCTAssertEqual(CelestialVisual.earthshineStrength(illuminationFraction: 1.0), 0,
                       "purnama tidak punya sisi gelap — earthshine harus nol")
        XCTAssertEqual(CelestialVisual.earthshineStrength(illuminationFraction: 0.0), 1,
                       "bulan baru: sisi gelap terluas")
        let thin = CelestialVisual.earthshineStrength(illuminationFraction: 0.10)
        let thick = CelestialVisual.earthshineStrength(illuminationFraction: 0.45)
        XCTAssertGreaterThan(thin, thick,
                             "sisi gelap menyempit saat iluminasi naik, jadi "
                             + "earthshine harus meredup")
    }

    // MARK: - 4. Arah sabit tidak boleh dikarang saat arah tak diketahui

    /// Tanpa `waxing`, geometri fase **tidak** dibuat: `nil`.
    ///
    /// Ini aturan kejujuran inti untuk gambar. Tanpa arah, sisi mana pun
    /// yang dipilih adalah karangan — dan sabit yang menghadap arah salah
    /// lebih buruk daripada piringan tanpa fase, karena ia tampak yakin.
    func testPhaseGeometryIsNilWhenDirectionIsUnknown() {
        let visual = CelestialVisual(kind: .moon,
                                     illuminationFraction: 0.12,
                                     isWaxing: nil,
                                     brightLimbAngleRadians: nil,
                                     relativeSize: 1.0)
        XCTAssertNil(visual.phaseGeometry(waxing: nil),
                     "tanpa arah fase, UI harus menggambar piringan tanpa fase")
    }
}
