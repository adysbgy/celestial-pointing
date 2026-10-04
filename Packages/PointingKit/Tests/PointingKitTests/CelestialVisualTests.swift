import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji model visual prosedural.
///
/// **Kenapa model visual perlu uji.** Gambar adalah klaim: pita Jupiter
/// berkata "ini Jupiter", sabit yang menghadap kanan berkata "fase
/// membesar". Tidak ada teks di layar yang bisa dibaca pengguna untuk
/// mengecek klaim-klaim itu, dan kesalahannya tampak sama meyakinkannya
/// dengan yang benar. PRD melarang UI mengklaim identitas yang tidak
/// dimiliki engine — karena itu dua hal paling rawan di sini (identitas
/// planet dan arah sabit) diuji **tanda**-nya, bukan hanya keberadaannya.
final class CelestialVisualTests: XCTestCase {

    private func object(id: String, kind: ObjectKind, magnitude: Double = 1.0) -> CelestialObject {
        CelestialObject(id: id, name: id.capitalized, kind: kind,
                        raDeg: 0, decDeg: 0, magnitude: magnitude)
    }

    // MARK: - Identitas planet

    func testPlanetRecognisedFromObjectID() {
        // Id diisi resolver dari `EphemerisBody.rawValue`, jadi pemetaan ini
        // harus cocok dengannya — kalau tidak, UI menggambar planet yang lain.
        XCTAssertEqual(CelestialVisual.Planet(objectID: "jupiter"), .jupiter)
        XCTAssertEqual(CelestialVisual.Planet(objectID: "saturn"), .saturn)
        XCTAssertEqual(CelestialVisual.Planet(objectID: "mars"), .mars)
        XCTAssertEqual(CelestialVisual.Planet(objectID: "venus"), .venus)
        XCTAssertEqual(CelestialVisual.Planet(objectID: "mercury"), .mercury)
    }

    func testUnknownPlanetIDIsNotGuessed() {
        // Planet yang tidak dikenal harus menghasilkan `nil` → UI menggambar
        // bola generik. Mengembalikan salah satu planet berarti menggambar
        // pita Jupiter pada benda yang tidak diketahui.
        XCTAssertNil(CelestialVisual.Planet(objectID: "pluto"))
        XCTAssertNil(CelestialVisual.Planet(objectID: "sirius"))
        XCTAssertNil(CelestialVisual.Planet(objectID: ""))
    }

    func testEveryEphemerisPlanetHasAKnownVisual() {
        // Semua benda tata surya yang bisa jadi target (kecuali Bulan) harus
        // punya padanan visual. Kalau ada yang belum, UI diam-diam menggambar
        // bola generik dan tidak ada yang akan melaporkannya.
        for body in EphemerisBody.pointableBodies where body != .moon {
            XCTAssertNotNil(CelestialVisual.Planet(objectID: body.rawValue),
                            "\(body.rawValue) belum punya visual planet")
        }
    }

    // MARK: - Pemilihan jenis gambar

    func testKindFollowsObjectKind() {
        XCTAssertEqual(CelestialVisual(object: object(id: "sirius", kind: .star)).kind, .star)
        XCTAssertEqual(CelestialVisual(object: object(id: "jupiter", kind: .planet)).kind, .planet)
        XCTAssertEqual(CelestialVisual(object: object(id: "moon", kind: .moon)).kind, .moon)
        XCTAssertEqual(CelestialVisual(object: object(id: "sun", kind: .sun)).kind, .sun)
        XCTAssertEqual(CelestialVisual(object: object(id: "m42", kind: .deepSky)).kind, .deepSky)
    }

    func testMoonIlluminationIsNotAppliedToOtherBodies() {
        // Meneruskan fraksi fase ke benda selain Bulan akan menggambar sabit
        // pada Venus — tampak masuk akal, sepenuhnya salah.
        let venus = CelestialVisual(object: object(id: "venus", kind: .planet),
                                    moonIlluminationFraction: 0.3)
        XCTAssertNil(venus.illuminationFraction,
                     "fase Bulan tidak boleh menempel pada planet")
        XCTAssertNil(venus.phaseGeometry(waxing: true))
    }

    // MARK: - Geometri fase Bulan

    func testCrescentSignFollowsWaxingDirection() {
        // Inilah inti Bagian 1: sabit harus benar **arahnya**.
        // Waxing → menyala di kanan (+), waning → di kiri (−).
        let waxing = CelestialVisual(kind: .moon, illuminationFraction: 0.2, isWaxing: true)
        let waning = CelestialVisual(kind: .moon, illuminationFraction: 0.2, isWaxing: false)
        XCTAssertGreaterThan(waxing.phaseGeometry(waxing: true)?.terminatorOffset ?? 0, 0)
        XCTAssertLessThan(waning.phaseGeometry(waxing: false)?.terminatorOffset ?? 0, 0)
    }

    func testCrescentMagnitudeTracksIlluminationFraction() {
        // Besar sabit mengikuti fraksi: f = 0.5 → terminator lurus (nol),
        // f = 1 → terminator keluar dari piringan (−1, purnama).
        XCTAssertEqual(CelestialVisual(kind: .moon, illuminationFraction: 0.5)
                        .phaseGeometry(waxing: true)?.terminatorOffset ?? 99, 0,
                       accuracy: 1e-9)
        XCTAssertEqual(CelestialVisual(kind: .moon, illuminationFraction: 1.0)
                        .phaseGeometry(waxing: true)?.terminatorOffset ?? 0, -1,
                       accuracy: 1e-9)
        XCTAssertEqual(CelestialVisual(kind: .moon, illuminationFraction: 0.0)
                        .phaseGeometry(waxing: true)?.terminatorOffset ?? 0, 1,
                       accuracy: 1e-9)
    }

    func testNewMoonDrawsNoLitBand() {
        // Bulan baru: lebar pita terangnya nol. Kalau ini tidak nol, layar
        // menampilkan sabit pada saat Bulan sama sekali tidak menyala.
        let newMoon = CelestialVisual(kind: .moon, illuminationFraction: 0.0)
        XCTAssertEqual(newMoon.phaseGeometry(waxing: true)?.terminatorSemiWidth ?? -1, 1,
                       accuracy: 1e-9)
        XCTAssertFalse(newMoon.phaseGeometry(waxing: true)?.isGibbous ?? true)
    }

    func testUnknownWaxingDirectionDrawsSymmetricPhase() {
        // Arah yang tidak diketahui harus menghasilkan gambar yang **tidak
        // memihak**, bukan gambar yang memilih satu sisi. Memilih sisi berarti
        // menyatakan arah yang tidak dihitung engine.
        let unknown = CelestialVisual(kind: .moon, illuminationFraction: 0.25, isWaxing: nil)
        XCTAssertEqual(unknown.phaseGeometry(waxing: nil)?.terminatorOffset ?? 99, 0,
                       accuracy: 1e-9,
                       "arah fase yang tidak diketahui tidak boleh menggambar sabit miring")
    }

    func testGibbousSwitchesAtHalfPhase() {
        XCTAssertFalse(CelestialVisual(kind: .moon, illuminationFraction: 0.4)
                        .phaseGeometry(waxing: true)?.isGibbous ?? true)
        XCTAssertTrue(CelestialVisual(kind: .moon, illuminationFraction: 0.75)
                        .phaseGeometry(waxing: true)?.isGibbous ?? false)
    }

    func testIlluminationFractionIsClampedToPhysicalRange() {
        // Efemeris yang memberi 1.4 atau −0.2 tidak boleh membuat elips
        // terminator keluar dari piringan (sabit "meledek" ke luar Bulan).
        let over = CelestialVisual(kind: .moon, illuminationFraction: 1.4)
        XCTAssertEqual(over.phaseGeometry(waxing: true)?.terminatorOffset ?? 0, -1,
                       accuracy: 1e-9)
        let under = CelestialVisual(kind: .moon, illuminationFraction: -0.2)
        XCTAssertEqual(under.phaseGeometry(waxing: true)?.terminatorOffset ?? 0, 1,
                       accuracy: 1e-9)
    }

    // MARK: - Warna bintang

    func testRedGiantsAreRedAndHotStarsAreBlue() {
        // Tanda B−V yang terbalik membuat Betelgeuse biru dan Rigel merah.
        // Tidak ada pengguna yang akan melaporkannya — karena itu diuji.
        XCTAssertGreaterThan(CelestialVisual.colorIndex(forStarID: "betelgeuse"), 1.0,
                             "Betelgeuse harus merah (B−V positif besar)")
        XCTAssertGreaterThan(CelestialVisual.colorIndex(forStarID: "antares"), 1.0)
        XCTAssertLessThan(CelestialVisual.colorIndex(forStarID: "rigel"), 0,
                          "Rigel harus biru (B−V negatif)")
        XCTAssertLessThan(CelestialVisual.colorIndex(forStarID: "alnitak"), 0)
    }

    func testSiriusIsBlueWhiteNotRed() {
        let index = CelestialVisual.colorIndex(forStarID: "sirius")
        XCTAssertEqual(index, 0, accuracy: 1e-9)
        XCTAssertLessThan(index, 0.5, "Sirius tidak boleh digambar kemerahan")
    }

    func testUnknownStarIsNeutralNotInvented() {
        // Bintang tanpa entri warna harus putih netral: warna karangan
        // mengklaim kelas spektral yang tidak diketahui.
        XCTAssertEqual(CelestialVisual.colorIndex(forStarID: "bintang_tak_dikenal"), 0,
                       accuracy: 1e-9)
    }

    func testEveryCatalogueBrightStarHasAColourEntry() {
        // Kalau katalog bertambah tanpa tabel warna ikut, bintang baru akan
        // digambar putih — tampak sah, padahal warnanya tidak diketahui.
        // Uji ini membuat penambahan katalog wajib menyentuh tabelnya.
        for star in Catalogue.brightStars {
            XCTAssertNotNil(CelestialVisual.starColorIndex[star.id],
                            "\(star.id) belum punya entri warna")
        }
    }

    // MARK: - Ukuran dari magnitudo

    func testBrighterStarIsDrawnLarger() {
        let sirius = CelestialVisual.sizeFromMagnitude(-1.46)
        let deneb = CelestialVisual.sizeFromMagnitude(1.25)
        XCTAssertGreaterThan(sirius, deneb)
    }

    func testSizeScaleIsLogarithmicNotLinear() {
        // Magnitudo adalah skala logaritmik. Kalau ukurannya linear, Sirius
        // (−1.46) dan Deneb (+1.25) nyaris sama besar padahal beda 12× terang.
        let sirius = CelestialVisual.sizeFromMagnitude(-1.46)
        let deneb = CelestialVisual.sizeFromMagnitude(1.25)
        XCTAssertGreaterThan(sirius / deneb, 2.0,
                             "skala ukuran harus logaritmik, bukan linear")
    }

    func testFaintObjectsStayVisible() {
        // Benda paling redup harus tetap berupa titik, bukan menghilang.
        XCTAssertGreaterThanOrEqual(CelestialVisual.sizeFromMagnitude(20), 0.15)
    }

    func testBrightestMagnitudeIsCappedAtOne() {
        XCTAssertLessThanOrEqual(CelestialVisual.sizeFromMagnitude(-30), 1.0)
    }
}
