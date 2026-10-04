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

    // MARK: - Geometri kutub planet

    /// Titik terjauh elips kutub dari pusat bola, dalam satuan radius.
    ///
    /// Elips kutub adalah gambaran di dalam `CGRect` view; agar bisa diuji
    /// di Linux (tanpa SwiftUI), bentuknya dihitung ulang di sini dari
    /// `topY/height/halfWidth` yang sama persis dengan yang dipakai view.
    private func maxDistanceFromCenter(topY: Double,
                                        height: Double,
                                        halfWidth: Double) -> Double {
        let steps = 2000
        var worst = 0.0
        for i in 0...steps {
            let t = 2 * Double.pi * Double(i) / Double(steps)
            let x = halfWidth * cos(t)
            let y = topY + height / 2 + (height / 2) * sin(t)
            worst = max(worst, hypot(x, y))
        }
        return worst
    }

    func testPolarCapsStayOnThePlanetSurface() {
        // **Regresi untuk kutub selatan yang menembus 0.26R keluar dari bola.**
        //
        // Versi lama memakai `y - radius` untuk kutub utara tapi
        // `y + radius - capHeight` untuk kutub selatan, dengan tinggi elips
        // `2 · capHeight` — jadi kutub selatan berakhir di y = 1.26, jauh di
        // luar bola: kutub putih menggantung di ruang kosong, bukan
        // menempel di permukaan. Uji ini gagal pada geometri lama.
        let caps = CelestialVisual.polarCaps()
        for (name, cap) in [("north", caps.north), ("south", caps.south)] {
            let farthest = maxDistanceFromCenter(topY: cap.topY,
                                                  height: cap.height,
                                                  halfWidth: cap.halfWidth)
            // Toleransi kecil hanya untuk pembulatan titik sampel; kutub
            // memang sedikit menyentuh tepi bola di kutub utara.
            XCTAssertLessThanOrEqual(farthest, 1.01,
                                     "kutub \(name) menembus \(farthest - 1) R di luar bola")
        }
    }

    func testPolarCapsAreMirrorImagesOfEachOther() {
        // Kutub Mars harus simetris terhadap ekuator. Versi lama tidak
        // (utara hanya meleset 0.004R, selatan 0.26R), dan simetri itulah
        // yang membuat keduanya melekat pada bola.
        let caps = CelestialVisual.polarCaps()
        XCTAssertEqual(caps.north.topY, -caps.south.topY - caps.south.height,
                       accuracy: 1e-12,
                       "kedua kutub harus cermin terhadap ekuator")
        XCTAssertEqual(caps.north.height, caps.south.height)
        XCTAssertEqual(caps.north.halfWidth, caps.south.halfWidth)
    }

    func testPolarCapDefaultsAreInRadiusUnits() {
        // Model tidak boleh bocor satuan: hasilnya proporsional radius
        // (satuan 1), supaya view cukup mengalikan sendiri.
        let caps = CelestialVisual.polarCaps()
        XCTAssertEqual(caps.north.topY, -1.0, accuracy: 1e-12)
        XCTAssertEqual(caps.north.height, 0.52, accuracy: 1e-12)
        XCTAssertEqual(caps.north.halfWidth, 0.55, accuracy: 1e-12)
    }

    // MARK: - Batas frame: tidak ada bentuk yang boleh keluar dari Canvas
    //
    // `Canvas` memotong apa pun di luar `frame`-nya dengan **tepi lurus**.
    // Bentuk yang keluar tidak terlihat "sedikit kebaca" seperti pada bug
    // lain -- ia terlihat **tidak sengaja terpotong**, dan tidak ada teks di
    // layar yang bisa memberi tahu. Karena itu setiap bentuk yang punya
    // bagian keluar frame harus punya batas yang diuji di sini.

    /// Cincin versi lama, dipakai sebagai **bukti merah** (lihat
    /// `testSaturnRingStaysInsideTheFrame`).
    private static let legacySaturnRing = VisualFrame.RingGeometry(
        halfWidth: 1.9,
        halfHeight: 0.62)

    func testSaturnRingStaysInsideTheFrame() {
        // **Regresi untuk cincin Saturnus yang terpotong tegak.**
        //
        // Versi lama menggambar cincin selebar `3.8 x radius` di dalam
        // `Canvas` selebar `2 x radius`: ujung elips berada di x = +/-1.9,
        // yaitu 0.9R **di luar** frame, jadi `Canvas` memotongnya dengan tepi
        // lurus. Hasilnya bukan cincin, melainkan dua garis yang berhenti
        // mendadak. Uji ini gagal pada geometri lama dengan pesan yang
        // menyebut berapa jauh keluar frame.
        let ring = VisualFrame.saturnRing()
        let spill = VisualFrame.overflow(centerX: 0,
                                         centerY: 0,
                                         halfWidth: ring.halfWidth,
                                         halfHeight: ring.halfHeight)
        XCTAssertLessThanOrEqual(spill, 0,
                                 "cincin keluar \(spill) R di luar frame dan akan terpotong tegak")
    }

    func testLegacySaturnRingOverflowedTheFrame() {
        // Bukti bahwa geometri lama benar-benar salah, bukan sekadar
        //beda rasa: dihitung, bukan diklaim. Tanpa ini, "diperbaiki" bisa
        // berarti angka yang sama ditulis ulang dengan nama lain.
        let spill = VisualFrame.overflow(centerX: 0,
                                         centerY: 0,
                                         halfWidth: Self.legacySaturnRing.halfWidth,
                                         halfHeight: Self.legacySaturnRing.halfHeight)
        XCTAssertGreaterThan(spill, 0.8,
                             "cincin lama hampir seluruhnya di luar frame -- inilah cacatnya")
    }

    func testSaturnRingTipsRemainVisibleBeyondTheBody() {
        // Bola harus **lebih kecil dari lebar cincin**, bukan dari
        // tingginya. Cincin Saturnus tampak miring, jadi tinggi elipsnya
        // memang lebih kecil dari jari-jari bola -- dan itu benar: bola
        // menutupi bagian tengah cincin, sementara dua ujung cincin harus
        // tetap tampil keluar di kiri dan kanan. Yang membuatnya terbaca
        // sebagai Saturnus justru dua ujung itu.
        //
        // Yang salah adalah memakai jari-jari bola sebesar frame
        // (`bodyFraction = 1`): cincin tertutup seluruhnya dan hasilnya
        // piring. Itu sebabnya `saturnBodyRadius` dihitung dari lebar
        // cincin, bukan ditulis sendiri di view.
        let ring = VisualFrame.saturnRing()
        let body = VisualFrame.saturnBodyRadius(for: ring)
        XCTAssertLessThan(body, ring.halfWidth,
                          "bola menutupi seluruh cincin -- hasilnya piring, bukan Saturnus")
        // Ujung cincin harus benar-benar terlihat, bukan cuma selisih nol.
        let exposed = ring.halfWidth - body
        XCTAssertGreaterThan(exposed, 0.2 * VisualFrame.halfExtent,
                             "ujung cincin harus tampil di luar bola, bukan menempel")
    }

    func testSaturnBodyStaysInsideTheFrame() {
        // Bola tidak boleh melebihi frame hanya karena cincinnya pas.
        let ring = VisualFrame.saturnRing()
        let body = VisualFrame.saturnBodyRadius(for: ring)
        let spill = VisualFrame.overflow(centerX: 0, centerY: 0,
                                         halfWidth: body, halfHeight: body)
        XCTAssertLessThanOrEqual(spill, 0,
                                 "bola Saturnus keluar \(spill) R di luar frame")
    }

    func testSaturnBodyScalesWithTheRing() {
        // Kalau lebar cincin diubah, bola **harus** ikut. inilah alasan
        // `saturnBodyRadius` ada: proporsi bola terhadap cincinnya tidak
        // boleh bergantung pada angka yang ditulis manual di view.
        let wide = VisualFrame.saturnRing(frameHalfExtent: 1.0)
        let wideBody = VisualFrame.saturnBodyRadius(for: wide)
        let narrow = VisualFrame.saturnRing(frameHalfExtent: 0.5)
        let narrowBody = VisualFrame.saturnBodyRadius(for: narrow)
        XCTAssertEqual(wideBody / narrowBody, 2.0, accuracy: 1e-12,
                       "bola harus ikut cincin, persis linear")
    }

    func testSaturnRingIsNotAFullDisc() {
        // Cincin harus **pipih**. Elips penuh (axialRatio 1.0) terbaca sebagai
        // piring, bukan cincin -- dan itulah bentuk yang tampil kalau rasio
        // lebar/tinggi cincin hilang.
        let ring = VisualFrame.saturnRing()
        XCTAssertLessThan(ring.fullHeight / ring.fullWidth, 0.5,
                          "cincin harus pipih; elips penuh terbaca sebagai piring")
        XCTAssertGreaterThan(ring.fullHeight, 0,
                             "cincin tidak boleh nol tinggi")
    }

    func testOverflowReportsNothingForCentredSmallShapes() {
        // Fungsi batas harus benar untuk bentuk yang memang muat: nilai
        // negatif berarti "tidak ada yang keluar", bukan "kurang"/"lebih".
        let spill = VisualFrame.overflow(centerX: 0, centerY: 0,
                                         halfWidth: 0.5, halfHeight: 0.5)
        XCTAssertEqual(spill, -0.5, accuracy: 1e-12)
        // Bentuk yang tepat di tepi: nol, bukan positif.
        let edge = VisualFrame.overflow(centerX: 0, centerY: 0,
                                        halfWidth: 1.0, halfHeight: 1.0)
        XCTAssertEqual(edge, 0, accuracy: 1e-12)
    }

    func testOverflowAccountsForOffsetCentres() {
        // Bentuk yang **digeser** (blob nebula) keluar frame lebih cepat
        // daripada yang terpusat, dan bedanya nyata: yang terpusat cukup
        // dicek secara radial, yang digeser harus dicek per sumbu. Uji ini
        // menjaga `overflow` menghitung **per sumbu**, bukan radial.
        let centred = VisualFrame.overflow(centerX: 0, centerY: 0,
                                           halfWidth: 0.9, halfHeight: 0.9)
        let offset = VisualFrame.overflow(centerX: 0.5, centerY: 0,
                                          halfWidth: 0.9, halfHeight: 0.9)
        XCTAssertEqual(centred, -0.1, accuracy: 1e-12)
        XCTAssertEqual(offset, 0.4, accuracy: 1e-12)
    }

    func testEveryDeepSkyBlobStaysInsideTheFrame() {
        // Kabut nebula memakai gradien yang sudah memudar ke transparan di
        // tepi blob, jadi keluar sedikit tidak merusak. Tapi keluar **cukup
        // jauh** memotong gradien di opasitas yang masih terlihat, dan tepi
        // rata-rata itu persis yang membuat nebula terlihat "digambar".
        // Uji ini memakai geometri model yang sama dengan view, bukan angka
        // yang disalin ulang -- kalau disalin, view bisa menyimpang tanpa
        // ada yang memberi tahu.
        for fuzziness in [0.0, 0.4, 0.8, 1.0] {
            let nebula = VisualFrame.nebula(fuzziness: fuzziness)
            for (index, blob) in nebula.blobs.enumerated() {
                let spill = VisualFrame.overflow(centerX: abs(blob.offsetX),
                                                 centerY: abs(blob.offsetY),
                                                 halfWidth: blob.radius,
                                                 halfHeight: blob.radius)
                XCTAssertLessThanOrEqual(spill, 1e-12,
                                         "blob nebula \(index) keluar \(spill) R di luar frame pada fuzziness \(fuzziness)")
            }
        }
    }

    func testNebulaGrowsWithFuzziness() {
        // Kabut yang lebih menyebar harus lebih besar -- itulah satu-satunya
        // hal yang membedakan "titik kabur" dari "kabut lebar", dan kalau
        // `fuzziness` diabaikan semua objek langit dalam tampil sama.
        let tight = VisualFrame.nebula(fuzziness: 0.0)
        let wide = VisualFrame.nebula(fuzziness: 1.0)
        XCTAssertGreaterThan(wide.blobs[0].radius, tight.blobs[0].radius,
                             "fuzziness harus memperlebar kabut")
    }

    func testNebulaIsAsymmetric() {
        // Kabut yang simetris sempurna tampak seperti lingkaran yang
        // digambar. Geserannya harus nyata, bukan nol.
        let nebula = VisualFrame.nebula(fuzziness: 0.8)
        let offsets = nebula.blobs.map { hypot($0.offsetX, $0.offsetY) }
        XCTAssertGreaterThan(offsets.max() ?? 0, 0.1,
                             "blob harus digeser dari pusat supaya tidak tampak digambar")
    }

    // MARK: - Geometri bintang: glow & spike tidak boleh terpotong tegak

    /// Ujung terluar bintang pada geometri **lama** (inti dihitung maju dari
    /// ukuran yang diinginkan: `0.22 + 0.30 · relativeSize`).
    ///
    /// Angka ini persis yang dipakai view sebelum siklus ini, jadi uji
    /// `testLegacyStarOverflowedTheFrame` bisa membuktikan cacatnya nyata —
    /// bukan perbedaan rasa tentang seberapa besar glow yang pantas.
    private func legacyStarOuterRadius(relativeSize: Double) -> (glow: Double, spike: Double) {
        let core = 0.22 + 0.30 * relativeSize
        return (core * 3.0, core * 3.2 * 1.10)
    }

    func testLegacyStarOverflowedTheFrame() {
        // **Pengunci cacat lama.** Inti dihitung maju dari `relativeSize`,
        // lalu glow dikalikan 3× dan spike 3.2× — tanpa pernah memeriksa
        // apakah hasilnya masih di dalam frame. Di seluruh katalog bintang
        // terang, hampir semuanya keluar.
        var overflowing = 0
        for star in Catalogue.brightStars {
            let legacy = legacyStarOuterRadius(
                relativeSize: CelestialVisual.sizeFromMagnitude(star.magnitude))
            if max(legacy.glow, legacy.spike) > VisualFrame.halfExtent {
                overflowing += 1
            }
        }
        XCTAssertGreaterThan(overflowing, 20,
                             "geometri lama harus terbukti memotong hampir seluruh katalog")
        // Sirius (bintang paling terang) adalah yang paling parah: ujungnya
        // 0.81R di luar frame, jadi lebih dari separuh lebarnya hilang.
        let siriusLegacy = legacyStarOuterRadius(
            relativeSize: CelestialVisual.sizeFromMagnitude(-1.46))
        XCTAssertGreaterThan(siriusLegacy.spike - VisualFrame.halfExtent, 0.5,
                             "Sirius harus terbukti keluar >0.5 R pada geometri lama")
    }

    func testEveryCatalogueStarStaysInsideTheFrame() {
        // Inti bintang kecil, tapi glow dan spike-nya dikalikan beberapa
        // kali dari inti itu — jadi batasnya harus dihitung dari **ujung
        // terluar**, bukan dari inti. `Canvas` memotong dengan tepi lurus,
        // jadi yang kelewat besar tidak tampak "agak kepotong": ia tampak
        // sebagai bola cahaya yang berhenti mendadak di keempat tepi kartu.
        for star in Catalogue.brightStars {
            let geometry = VisualFrame.star(
                relativeSize: CelestialVisual.sizeFromMagnitude(star.magnitude))
            let spill = VisualFrame.overflow(centerX: 0, centerY: 0,
                                             halfWidth: geometry.outerRadius,
                                             halfHeight: geometry.outerRadius)
            XCTAssertLessThanOrEqual(spill, 1e-12,
                                     "\(star.id) keluar \(spill) R di luar frame dan akan terpotong tegak")
        }
    }

    func testStarPulsePeakStaysInsideTheFrame() {
        // **Denyut harus ikut dihitung.** Ukurannya dipilih saat diam,
        // sedangkan denyut mengembangkannya **setelahnya** — jadi bintang
        // yang muat saat diam bisa terpotong setiap kali denyut memuncak.
        // Cacat yang muncul dan hilang seperti ini yang paling mudah lolos.
        let geometry = VisualFrame.star(relativeSize: 1.0)
        let peak = geometry.coreRadius * geometry.outermostScale * (1 + geometry.pulseAmplitude)
        XCTAssertEqual(geometry.outerRadius, peak, accuracy: 1e-12,
                       "outerRadius harus sudah termasuk denyut puncak")
        let spill = VisualFrame.overflow(centerX: 0, centerY: 0,
                                         halfWidth: peak, halfHeight: peak)
        XCTAssertLessThanOrEqual(spill, 1e-12,
                                 "denyut puncak mengeluarkan bintang \(spill) R dari frame")
    }

    func testBrighterStarIsStillDrawnLarger() {
        // Memperkecil inti demi muat tidak boleh meratakan seluruh bintang
        // menjadi satu ukuran: "ukuran mengikuti magnitudo" adalah informasi
        // yang masih terbaca di layar, dan memotongnya dengan plafon tetap
        // akan membuat Sirius dan Polaris tampak sama.
        let sirius = VisualFrame.star(
            relativeSize: CelestialVisual.sizeFromMagnitude(-1.46))
        let polaris = VisualFrame.star(
            relativeSize: CelestialVisual.sizeFromMagnitude(1.98))
        XCTAssertGreaterThan(sirius.coreRadius, polaris.coreRadius,
                             "bintang terang harus tetap lebih besar")
        XCTAssertGreaterThan(sirius.outerRadius, polaris.outerRadius,
                             "ujung terluar bintang terang harus tetap lebih jauh")
    }

    func testEnlargingTheGlowCannotPushTheStarOutOfFrame() {
        // Yang membuat batas ini konstruktif: inti dihitung **mundur** dari
        // ruang yang tersedia. Jadi memperbesar glow/spike tidak bisa
        // mendorong ujungnya keluar — inti menyusut sendiri mengikutinya.
        for spikeScale in [3.2, 5.0, 12.0] {
            for glowScales in [[3.0, 1.9, 1.0], [6.0, 4.0, 2.0], [20.0]] {
                let geometry = VisualFrame.star(relativeSize: 1.0,
                                                glowScales: glowScales,
                                                spikeScale: spikeScale)
                let spill = VisualFrame.overflow(centerX: 0, centerY: 0,
                                                 halfWidth: geometry.outerRadius,
                                                 halfHeight: geometry.outerRadius)
                XCTAssertLessThanOrEqual(spill, 1e-12,
                                         "glow \(glowScales)/spike \(spikeScale) mengeluarkan bintang \(spill) R")
            }
        }
    }

    func testStarCoreStaysVisible() {
        // Batasnya tidak boleh bekerja dengan mengecilkan inti sampai nol:
        // bintang paling redup pun harus tetap punya inti yang terlihat,
        // bukan hanya glow kosong.
        let faint = VisualFrame.star(relativeSize: 0.0)
        XCTAssertGreaterThan(faint.coreRadius, 0.05,
                             "inti bintang paling redup tidak boleh menghilang")
    }
}
