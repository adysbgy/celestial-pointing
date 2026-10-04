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
        // Waxing → menyala di kanan, waning → di kiri.
        let waxing = CelestialVisual(kind: .moon, illuminationFraction: 0.2)
        let waning = CelestialVisual(kind: .moon, illuminationFraction: 0.2)
        XCTAssertEqual(waxing.phaseGeometry(waxing: true)?.litSide ?? 0, 1,
                       accuracy: 1e-9, "sabit membesar harus menyala di kanan")
        XCTAssertEqual(waning.phaseGeometry(waxing: false)?.litSide ?? 0, -1,
                       accuracy: 1e-9, "sabit mengecil harus menyala di kiri")
    }

    func testCrescentMagnitudeTracksIlluminationFraction() {
        // Lebar pita terang di ekuator = 2·f (dalam satuan radius). Ini yang
        // membuat gambar sabit mengikuti fase yang dihitung engine, bukan
        // fase yang "terlihat bagus".
        XCTAssertEqual(CelestialVisual(kind: .moon, illuminationFraction: 0.25)
                        .phaseGeometry(waxing: true)?.litBandWidth ?? -1, 0.5,
                       accuracy: 1e-9)
        XCTAssertEqual(CelestialVisual(kind: .moon, illuminationFraction: 0.5)
                        .phaseGeometry(waxing: true)?.litBandWidth ?? -1, 1.0,
                       accuracy: 1e-9)
        XCTAssertEqual(CelestialVisual(kind: .moon, illuminationFraction: 1.0)
                        .phaseGeometry(waxing: true)?.litBandWidth ?? -1, 2.0,
                       accuracy: 1e-9)
    }

    func testNewMoonDrawsNoLitBand() {
        // Bulan baru: lebar pita terangnya nol. Kalau ini tidak nol, layar
        // menampilkan sabit pada saat Bulan sama sekali tidak menyala.
        let newMoon = CelestialVisual(kind: .moon, illuminationFraction: 0.0)
        XCTAssertEqual(newMoon.phaseGeometry(waxing: true)?.litBandWidth ?? -1, 0,
                       accuracy: 1e-9)
        XCTAssertFalse(newMoon.phaseGeometry(waxing: true)?.isGibbous ?? true)
    }

    func testGibbousKeepsTerminatorOppositeToLitSide() {
        // Fase gibbous adalah jebakan: sisi yang menyala tetap kanan, tapi
        // terminatornya sudah bergeser ke kiri melewati pusat. Mengambil sisi
        // dari tanda terminator akan membalikkan arah sabit tepat pada fase
        // yang paling sering dikenali pengguna (hampir purnama).
        let gibbous = CelestialVisual(kind: .moon, illuminationFraction: 0.85)
            .phaseGeometry(waxing: true)
        XCTAssertEqual(gibbous?.litSide ?? 0, 1, accuracy: 1e-9)
        XCTAssertLessThan(gibbous?.terminatorOffset ?? 1, 0,
                          "terminator gibbous harus berada di sisi gelap")
        XCTAssertTrue(gibbous?.isGibbous ?? false)
    }

    func testUnknownWaxingDirectionDrawsNoPhase() {
        // Arah yang tidak diketahui harus menghasilkan **tanpa fase**, bukan
        // fase yang memilih satu sisi. Menggambar sabit miring berarti
        // menyatakan arah yang tidak dihitung engine — dan layar tidak punya
        // cara memberitahu pengguna bahwa arahnya tebakan.
        let unknown = CelestialVisual(kind: .moon, illuminationFraction: 0.25, isWaxing: nil)
        XCTAssertNil(unknown.phaseGeometry(waxing: nil),
                     "arah fase yang tidak diketahui tidak boleh menggambar sabit miring")
        // Fraksi yang tidak ada pun sama: UI menggambar piringan polos.
        XCTAssertNil(CelestialVisual(kind: .moon, illuminationFraction: nil)
                        .phaseGeometry(waxing: true))
    }

    func testGibbousSwitchesAtHalfPhase() {
        XCTAssertFalse(CelestialVisual(kind: .moon, illuminationFraction: 0.4)
                        .phaseGeometry(waxing: true)?.isGibbous ?? true)
        XCTAssertTrue(CelestialVisual(kind: .moon, illuminationFraction: 0.75)
                        .phaseGeometry(waxing: true)?.isGibbous ?? false)
    }

    func testIlluminationFractionIsClampedToPhysicalRange() {
        // Efemeris yang memberi 1.4 atau −0.2 tidak boleh membuat pita terang
        // melebar melebihi piringan (sabit "meledak" keluar dari Bulan).
        let over = CelestialVisual(kind: .moon, illuminationFraction: 1.4)
        XCTAssertEqual(over.phaseGeometry(waxing: true)?.litBandWidth ?? -1, 2.0,
                       accuracy: 1e-9)
        let under = CelestialVisual(kind: .moon, illuminationFraction: -0.2)
        XCTAssertEqual(under.phaseGeometry(waxing: true)?.litBandWidth ?? -1, 0.0,
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

    func testEveryPlanetHasADistinctPalette() {
        // Palet planet dipakai **sebelum** identitas dikonfirmasi (warna bola
        // boleh tampil, ciri pengenal belum). Kalau satu case tidak punya
        // palet, switch-nya tidak akan lengkap; yang diuji di sini adalah
        // bahwa warnanya benar-benar **berbeda per planet** — palet yang sama
        // untuk semua planet berarti warna tidak membawa informasi, padahal
        // warna adalah satu-satunya hal yang masih jujur tampil saat ragu.
        var palettes: Set<String> = []
        for planet in CelestialVisual.Planet.allCases {
            let palette = planet.palette
            palettes.insert("\(palette.light.red),\(palette.light.green),\(palette.light.blue)")
        }
        XCTAssertEqual(palettes.count, CelestialVisual.Planet.allCases.count,
                       "tiap planet harus punya warna sendiri, bukan warna bersama")
    }

    func testDistinguishingFeatureMatchesTheActualPlanet() {
        // Ciri pengenal adalah **klaim identitas**: cincin berkata "Saturnus",
        // pita + bintik merah berkata "Jupiter". Salah memetakan akan
        // menghasilkan gambar yang tampak sama meyakinkannya dengan yang
        // benar, tanpa satu pun teks di layar yang bisa mengeceknya.
        XCTAssertEqual(CelestialVisual.Planet.saturn.palette.feature, .rings)
        XCTAssertEqual(CelestialVisual.Planet.jupiter.palette.feature, .bands)
        XCTAssertEqual(CelestialVisual.Planet.mars.palette.feature, .polarCaps)
        XCTAssertEqual(CelestialVisual.Planet.mercury.palette.feature, .craters)
        XCTAssertEqual(CelestialVisual.Planet.venus.palette.feature, .haze)
    }

    func testEveryPlanetHasAUniqueFeature() {
        // Kalau dua planet berbagi ciri, ciri itu berhenti menjadi penanda
        // identitas — dan UI lalu menggambar ciri yang salah tanpa bisa
        // dibedakan dari yang benar.
        let features = Set(CelestialVisual.Planet.allCases.map { $0.palette.feature })
        XCTAssertEqual(features.count, CelestialVisual.Planet.allCases.count,
                       "ciri pengenal harus unik per planet")
        XCTAssertFalse(features.contains(.none),
                       "planet yang dikenali tidak boleh digambar sebagai bola generik")
    }

    func testNightModeKeepsBrightnessOrdering() {
        // Mode malam membuang hue (paksa merah), tapi **urutan terang** harus
        // tetap mengikuti apa yang terjadi pada bola di langit — dan yang
        // terlihat di malam hanyalah kanal merah. Urutan diuji per pasangan
        // planet yang benar-benar berbeda saat siang, bukan lewat angka
        // luminance penuh: metrik yang dipakai mode malam adalah kanal merah,
        // jadi itu yang harus diuji.
        func red(_ planet: CelestialVisual.Planet) -> Double {
            planet.palette.light.nightModeBrightness
        }
        XCTAssertGreaterThan(red(.venus), red(.mars),
                             "Venus harus lebih terang dari Mars di mode malam")
        XCTAssertGreaterThan(red(.saturn), red(.mars),
                             "Saturnus harus lebih terang dari Mars di mode malam")
        XCTAssertGreaterThan(red(.jupiter), red(.mars),
                             "Jupiter harus lebih terang dari Mars di mode malam")
        // Setiap planet harus punya kanal merah berbeda: kalau dua planet
        // berbagi nilai, mode malam mengubah semuanya menjadi satu bayangan
        // yang sama.
        let reds = Set(CelestialVisual.Planet.allCases.map {
            String(format: "%.3f", red($0))
        })
        XCTAssertEqual(reds.count, CelestialVisual.Planet.allCases.count)
    }

    func testEveryCatalogueStarHasAKnownColorIndex() {
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
