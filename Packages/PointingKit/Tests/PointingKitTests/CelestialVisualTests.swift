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

    // MARK: - Fase planet dalam

    /// Hanya planet **dalam** yang menampakkan fase dari Bumi.
    ///
    /// Mars sampai Saturnus tidak pernah tampak berfase. Kalau salah satunya
    /// dinyatakan berfase, ia akan digambar sebagai sabit — gambar yang
    /// menyatakan pemandangan yang tidak pernah ada di langit, dan tidak ada
    /// teks di layar yang bisa membantahnya.
    func testOnlyInnerPlanetsShowPhase() {
        XCTAssertTrue(CelestialVisual.Planet.mercury.showsPhase)
        XCTAssertTrue(CelestialVisual.Planet.venus.showsPhase)
        XCTAssertFalse(CelestialVisual.Planet.mars.showsPhase)
        XCTAssertFalse(CelestialVisual.Planet.jupiter.showsPhase)
        XCTAssertFalse(CelestialVisual.Planet.saturn.showsPhase)
    }

    /// Venus menerima fraksi fasenya sendiri, dan menggambarnya seperti Bulan.
    func testInnerPlanetDrawsAPhaseFromItsOwnFraction() {
        let venus = CelestialVisual(object: object(id: "venus", kind: .planet),
                                    isWaxing: true,
                                    planetIlluminationFraction: 0.25)
        XCTAssertNil(venus.illuminationFraction, "fase Bulan tidak boleh dipakai Venus")
        XCTAssertEqual(venus.fractionForPhase ?? -1, 0.25, accuracy: 1e-9)
        let phase = venus.phaseGeometry(waxing: true)
        XCTAssertNotNil(phase, "Venus berfase harus menghasilkan geometri")
        XCTAssertEqual(phase?.litBandWidth ?? -1, 0.5, accuracy: 1e-9,
                       "sabit Venus 25 persen harus selebar 0,5 radius")
    }

    /// Planet luar **menolak** fraksi fase walau angkanya diberikan.
    ///
    /// Ini penjaga cacat yang paling mudah terjadi: satu baris `?` yang
    /// keliru meneruskan `planetIlluminationFraction` ke semua planet akan
    /// menggambar sabit Mars. Tidak ada pengguna yang akan melaporkannya,
    /// karena sabitnya tampak wajar.
    func testOuterPlanetsRefuseAPhaseFractionEvenWhenGiven() {
        for planet in ["mars", "jupiter", "saturn"] {
            let visual = CelestialVisual(object: object(id: planet, kind: .planet),
                                         isWaxing: true,
                                         planetIlluminationFraction: 0.3)
            XCTAssertNil(visual.planetPhaseFraction,
                         "\(planet) tidak boleh menyimpan fraksi fase")
            XCTAssertNil(visual.phaseGeometry(waxing: true),
                         "\(planet) tidak boleh digambar berfase")
        }
    }

    /// Tanpa arah (`isWaxing` nil), planet berfase **tidak** digambar berfase.
    ///
    /// Sama dengan aturan Bulan: fase tanpa arah berarti sabit yang memihak ke
    /// satu sisi — pernyataan yang tidak dihitung engine.
    func testInnerPlanetWithoutDirectionDrawsNoPhase() {
        let venus = CelestialVisual(object: object(id: "venus", kind: .planet),
                                    isWaxing: nil,
                                    planetIlluminationFraction: 0.4)
        XCTAssertNil(venus.phaseGeometry(waxing: nil))
    }

    /// Geometri fase planet sama persis dengan geometri Bulan untuk fraksi dan
    /// arah yang sama.
    ///
    /// **Kenapa ini diuji.** Venus dan Bulan digambar oleh kurva yang sama;
    /// kalau rumusnya bercabang per jenis benda, cepat atau lambat keduanya
    /// berbeda — dan yang salah tetap tampak seperti sabit yang meyakinkan.
    /// Uji ini mengunci "satu rumus", bukan "dua rumus yang kebetulan cocok".
    func testPlanetAndMoonPhasesShareTheSameGeometry() {
        for fraction in [0.1, 0.25, 0.5, 0.75, 0.9] {
            for waxing in [true, false] {
                let moon = CelestialVisual(kind: .moon, illuminationFraction: fraction)
                    .phaseGeometry(waxing: waxing)
                let venus = CelestialVisual(kind: .planet, planet: .venus,
                                            planetPhaseFraction: fraction)
                    .phaseGeometry(waxing: waxing)
                XCTAssertEqual(moon?.terminatorOffset, venus?.terminatorOffset,
                               "fase \(fraction) (\(waxing ? "membesar" : "mengecil")) "
                               + "harus memakai geometri yang sama")
                XCTAssertEqual(moon?.litSide, venus?.litSide)
                XCTAssertEqual(moon?.isGibbous, venus?.isGibbous)
            }
        }
    }

    // MARK: - Orientasi terminator

    /// Sisi yang menyala harus menghadap **Matahari** setelah diputar.
    ///
    /// Ini penjaga cacat orientasi yang tidak bisa dilihat di layar: sabit
    /// yang terbalik tetap berbentuk sabit. Untuk setiap fraksi, titik tengah
    /// pita terang setelah putaran harus berada di sisi yang sama dengan arah
    /// Matahari.
    func testTerminatorRotationPutsLitSideTowardTheSun() {
        // Sudut Matahari = 0 (Matahari tepat di kanan benda).
        for fraction in [0.15, 0.4, 0.6, 0.85] {
            for waxing in [true, false] {
                let visual = CelestialVisual(kind: .moon,
                                             illuminationFraction: fraction,
                                             isWaxing: waxing,
                                             brightLimbAngleRadians: 0)
                guard let rotation = visual.terminatorRotationRadians,
                      let phase = visual.phaseGeometry(waxing: waxing) else {
                    return XCTFail("fase \(fraction) harus punya sudut & geometri")
                }
                // Titik tengah pita terang di ekuator pada gambar dasar.
                let mid = (phase.limbX(atNormalizedHeight: 0)
                           + phase.terminatorX(atNormalizedHeight: 0)) / 2
                // Diputar sebesar `rotation`: x' = mid·cos(rotation).
                let rotatedX = mid * cos(rotation)
                XCTAssertGreaterThan(rotatedX, 0,
                                     "fase \(fraction) (\(waxing ? "membesar" : "mengecil")): "
                                     + "sisi terang harus menghadap Matahari (kanan), "
                                     + "bukan ke arah sebaliknya")
            }
        }
    }

    /// Sudut putaran adalah sudut Matahari, dibalik hanya saat pita dasar ada
    /// di kiri (gibbous waning).
    func testTerminatorRotationFlipsOnlyForLeftSidedBands() {
        let crescentWaxing = CelestialVisual(kind: .moon, illuminationFraction: 0.2,
                                             isWaxing: true, brightLimbAngleRadians: 0.5)
        XCTAssertEqual(crescentWaxing.terminatorRotationRadians ?? .nan, 0.5, accuracy: 1e-12,
                       "sabit membesar: pita dasar di kanan, tidak dibalik")

        let gibbousWaning = CelestialVisual(kind: .moon, illuminationFraction: 0.8,
                                            isWaxing: false, brightLimbAngleRadians: 0.5)
        XCTAssertEqual(gibbousWaning.terminatorRotationRadians ?? .nan, 0.5 + .pi,
                       accuracy: 1e-12,
                       "cembung mengecil: pita dasar di kiri, harus dibalik dulu")
    }

    /// Tanpa sudut sisi terang, **tidak ada** putaran — bukan putaran nol yang
    /// diam-diam dipakai.
    func testTerminatorRotationIsNilWithoutALimbAngle() {
        let visual = CelestialVisual(kind: .moon, illuminationFraction: 0.3, isWaxing: true)
        XCTAssertNil(visual.terminatorRotationRadians)
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

    /// Piringan "fase tidak diketahui" harus **terbaca berbeda** dari kedua
    /// keadaan yang menyatakan sesuatu: bulan baru (gelap) dan bulan purnama
    /// (menyala).
    ///
    /// **Cacat yang dijaga di sini.** Sampai siklus ini `drawMoon` menggambar
    /// piringan *tidak menyala* saat fasenya tidak diketahui, lalu berhenti.
    /// Hasilnya **identik piksel demi piksel** dengan bulan baru — diukur di
    /// `check-visuals.py`: 0 dari 40.000 piksel berbeda. Bulan baru adalah
    /// fakta tentang langit (f = 0); "fase tidak dihitung" bukan fakta tentang
    /// apa pun. Menggambar yang kedua sebagai yang pertama berarti gambar itu
    /// **menyatakan** bulan baru setiap kali efemeris gagal atau arahnya tidak
    /// tersedia — dan tidak ada teks di kartu jam yang bisa membantahnya.
    ///
    /// Nilainya harus berada **tegas di antara** `moonUnlit` dan `moonLit`:
    /// cukup terang untuk tidak terbaca sebagai "gelap", cukup redup untuk
    /// tidak terbaca sebagai "menyala". Uji ini mengunci posisi itu, jadi
    /// tokennya tidak bisa diam-diam menempel ke salah satu ujung.
    func testPhaseUnknownDiscIsNeitherLitNorUnlit() {
        let accents = CelestialVisual.accents
        let unknown = accents.moonPhaseUnknown
        let unlit = accents.moonUnlit
        let lit = accents.moonLit

        XCTAssertGreaterThan(unknown.nightModeBrightness, unlit.nightModeBrightness,
                             "piringan 'tidak diketahui' tidak boleh segelap bulan baru")
        XCTAssertLessThan(unknown.nightModeBrightness, lit.nightModeBrightness,
                          "piringan 'tidak diketahui' tidak boleh seterang bulan purnama")
        // Jarak yang berarti, bukan sekadar tanda yang benar: selisih 0.01
        // secara teknis lolos kedua pertidaksamaan di atas sambil tetap
        // tampak identik di layar.
        XCTAssertGreaterThan(unknown.nightModeBrightness - unlit.nightModeBrightness, 0.1,
                             "harus terbaca jelas berbeda dari bulan baru")
        XCTAssertGreaterThan(lit.nightModeBrightness - unknown.nightModeBrightness, 0.1,
                             "harus terbaca jelas berbeda dari bulan purnama")
    }

    /// Dan token itu benar-benar dipakai: fase yang tidak diketahui harus
    /// menghasilkan piringan **tanpa pita terang**, apa pun fraksinya.
    func testPhaseUnknownDrawsNoLitBandEvenWithAFraction() {
        // Fraksi ada, tapi arahnya tidak: tanpa arah, sabitnya akan memihak
        // satu sisi — jadi tidak digambar sama sekali.
        let unknown = CelestialVisual(kind: .moon, illuminationFraction: 0.25, isWaxing: nil)
        XCTAssertNil(unknown.phaseGeometry(waxing: unknown.isWaxing))
    }

    // MARK: - Luas pita terang: kurva yang benar-benar digambar

    /// Luas pita terang sebagai pecahan piringan, dihitung dengan rumus
    /// shoelace pada kurva yang **sama** dengan yang dipakai view.
    ///
    /// Diulang di sini justru karena view tidak bisa diuji di Linux: tanpa
    /// pengulangan ini, "kurva yang benar" hanya sebuah klaim. Jumlah segmen
    /// = 72, sama seperti `drawMoon`, sehingga angka yang diuji adalah angka
    /// yang benar-benar digambar -- bukan versi ideal yang tidak pernah
    /// sampai ke layar.
    private func litAreaFraction(phase: CelestialVisual.PhaseGeometry,
                                 steps: Int = 72,
                                 useAbsoluteOffset: Bool = false) -> Double {
        var points: [(x: Double, y: Double)] = []
        // Limb: kutub bawah ke kutub atas.
        for step in 0...steps {
            let h = -1 + 2 * Double(step) / Double(steps)
            points.append((phase.limbX(atNormalizedHeight: h), h))
        }
        // Terminator: kutub atas ke kutub bawah.
        let offset = useAbsoluteOffset ? abs(phase.terminatorOffset)
                                       : phase.terminatorOffset
        for step in stride(from: steps, through: 0, by: -1) {
            let h = -1 + 2 * Double(step) / Double(steps)
            points.append((phase.terminatorX(atNormalizedHeight: h, offset: offset), h))
        }
        var twiceArea = 0.0
        for index in 0..<(points.count - 1) {
            twiceArea += points[index].x * points[index + 1].y
                - points[index + 1].x * points[index].y
        }
        return abs(twiceArea) / 2 / Double.pi
    }

    func testLitBandAreaMatchesTheIlluminatedFraction() {
        // **Pita terang harus sebesar fraksi iluminasi, bukan komplemennya.**
        //
        // Ini pengunci cacat yang menutup seluruh uji sebelumnya.
        // `terminatorOffset` sudah membawa tanda sisi terminator
        // (`litSide * (1 - 2f)`), tetapi view mengambil nilai mutlaknya lalu
        // mengalikan lagi dengan sisi. Tanda itu hilang, sehingga untuk
        // f > 0.5 terminator terpaku kembali ke sisi yang menyala dan pita
        // yang digambar menjadi komplemen dari yang benar: 85% menampilkan
        // 15%, dan bulan purnama (f = 1) menampilkan piringan gelap --
        // sementara angka "Fase Bulan 100%" tampil persis di atasnya.
        //
        // Geometri seperti ini lolos semua gerbang yang ada: `swiftc -parse`
        // hanya memeriksa sintaks, `swift test` di Linux tidak punya `Canvas`,
        // dan tidak ada teks di layar yang bisa dibaca pengguna untuk
        // mengeceknya. Yang menutupnya hanya menghitung luas kurvanya.
        for fraction in [0.05, 0.20, 0.25, 0.50, 0.75, 0.80, 0.85, 0.95] {
            for waxing in [true, false] {
                let phase = CelestialVisual(kind: .moon,
                                            illuminationFraction: fraction)
                    .phaseGeometry(waxing: waxing)
                XCTAssertNotNil(phase)
                guard let phase else { continue }
                let drawn = litAreaFraction(phase: phase)
                XCTAssertEqual(drawn, fraction, accuracy: 0.01,
                               "pita terang digambar \(drawn * 100) persen untuk fraksi "
                               + "\(fraction * 100) persen (\(waxing ? "membesar" : "mengecil"))")
            }
        }
    }

    func testFullMoonFillsTheDiscInsteadOfGoingBlack() {
        // Kasus batas yang paling merusak, dipisah supaya pesannya menyebut
        // gejalanya: purnama harus penuh, bukan kosong. Pada geometri lama
        // pita purnama ternyata 0 persen -- piringan gelap, kontradiksi
        // langsung dengan angka "Fase Bulan 100%" di layar Ketelitian.
        let full = CelestialVisual(kind: .moon, illuminationFraction: 1.0)
            .phaseGeometry(waxing: true)
        XCTAssertNotNil(full)
        guard let full else { return }
        XCTAssertGreaterThan(litAreaFraction(phase: full), 0.98,
                             "bulan purnama harus menampilkan piringan penuh, bukan gelap")
    }

    func testLegacyAbsoluteTerminatorDrewTheComplement() {
        // Pengunci cacat lama, supaya "diperbaiki" tidak berarti angka yang
        // sama ditulis ulang dengan nama lain: nilai mutlak dari
        // `terminatorOffset` dikalikan lagi dengan sisi -- persis yang
        // dilakukan view sebelum siklus ini.
        let gibbous = CelestialVisual(kind: .moon, illuminationFraction: 0.85)
            .phaseGeometry(waxing: true)
        XCTAssertNotNil(gibbous)
        guard let gibbous else { return }
        let legacy = litAreaFraction(phase: gibbous, useAbsoluteOffset: true)
        XCTAssertLessThan(legacy, 0.25,
                          "geometri lama harus terbukti menampilkan komplemennya")
        // Untuk bulan baru hasilnya justru benar -- itulah sebabnya cacat ini
        // bertahan lama: separuh fase (sabit) tergambar akurat, jadi siapa
        // pun yang memeriksa sabit tidak akan menemukan apa pun.
        let crescent = CelestialVisual(kind: .moon, illuminationFraction: 0.25)
            .phaseGeometry(waxing: true)
        XCTAssertNotNil(crescent)
        guard let crescent else { return }
        XCTAssertEqual(litAreaFraction(phase: crescent, useAbsoluteOffset: true),
                       0.25, accuracy: 0.01,
                       "sabit benar pada geometri lama -- itu yang menutupi cacatnya")
    }

    func testBothCurvesStayOnTheDisc() {
        // Kedua kurva harus berada di dalam piringan pada semua ketinggian:
        // limb menyentuh tepi, dan terminator tidak boleh keluar karena yang
        // keluar tidak terlihat (serta `Canvas` memotongnya tegak).
        let geometry = CelestialVisual(kind: .moon, illuminationFraction: 0.85)
            .phaseGeometry(waxing: true)
        XCTAssertNotNil(geometry)
        guard let geometry else { return }
        for step in 0...40 {
            let h = -1 + 2 * Double(step) / 40
            XCTAssertLessThanOrEqual(abs(geometry.limbX(atNormalizedHeight: h)), 1.0 + 1e-12,
                                     "limb keluar dari piringan pada h=\(h)")
            XCTAssertLessThanOrEqual(abs(geometry.terminatorX(atNormalizedHeight: h)), 1.0 + 1e-12,
                                     "terminator keluar dari piringan pada h=\(h)")
        }
    }

    func testBothCurvesMeetAtThePoles() {
        // Di kedua kutub kedua kurva harus bertemu; kalau tidak, pita terang
        // tidak tertutup dan ada celah gelap di basis piringan.
        let geometry = CelestialVisual(kind: .moon, illuminationFraction: 0.3)
            .phaseGeometry(waxing: false)
        XCTAssertNotNil(geometry)
        guard let geometry else { return }
        for h in [-1.0, 1.0] {
            XCTAssertEqual(geometry.limbX(atNormalizedHeight: h),
                           geometry.terminatorX(atNormalizedHeight: h),
                           accuracy: 1e-12,
                           "kedua kurva harus bertemu di kutub h=\(h)")
        }
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

    // MARK: - Sudut sisi terang Bulan

    /// Sabit muda dari Jakarta: sisi terang menghadap **bawah**, bukan kanan.
    ///
    /// Angka alt/az di sini adalah geometri langit Jakarta (lintang -6.2
    /// derajat) sesaat setelah Matahari terbenam: Bulan rendah di barat,
    /// hampir tepat di atas Matahari yang baru tenggelam — elongasi kecil,
    /// seperti sabit muda sungguhan.
    ///
    ///   Bulan  : tinggi 20 derajat, azimut 283 derajat (barat)
    ///   Matahari: tinggi -2 derajat, azimut 285 derajat (barat)
    ///
    /// Inilah **kasus yang membuat cacat lama terlihat**. Perilaku lama
    /// (sisi = `waxing ? kanan : kiri`) menghasilkan 0 derajat di sini,
    /// padahal geometrinya menuntut sekitar -85 derajat: **galat 85
    /// derajat**. Di lintang tinggi kedua jawaban itu kebetulan berdekatan,
    /// jadi cacatnya tidak pernah terlihat di sana — persis alasan mengapa
    /// lintangnya harus dipakai, bukan diasumsikan.
    func testCrescentInJakartaFacesDownNotRight() {
        let angle = CelestialVisual.brightLimbAngle(
            body: HorizontalCoord(altitudeDeg: 20, azimuthDeg: 283),
            sun: HorizontalCoord(altitudeDeg: -2, azimuthDeg: 285))
        guard let value = angle else { return XCTFail("sudut harus terdefinisi") }
        XCTAssertEqual(value, -.pi / 2, accuracy: SkyMath.deg2rad(10),
                       "sisi terang harus menghadap bawah; dapat \(SkyMath.rad2deg(value)) derajat")
        XCTAssertLessThan(value, 0,
                          "sisi terang harus di bawah (sudut negatif), bukan di kanan")
        // Jarak dari jawaban lama membuktikan ini bukan perbedaan kosmetik.
        XCTAssertGreaterThan(abs(value), SkyMath.deg2rad(45),
                             "jawaban lama (0 derajat) harus jauh dari yang benar")
    }

    /// Sabit yang lebih tua, di lintang utara menengah: sisi terang condong
    /// **kanan-bawah**, bukan tegak ke kanan.
    ///
    ///   Bulan  : tinggi 30 derajat, azimut 250 derajat
    ///   Matahari: tinggi -1 derajat, azimut 285 derajat
    ///
    /// Ujinya sengaja menyatakan **rentang**, bukan satu angka: yang bisa
    /// diklaim dengan yakin adalah sisi terang berada di kuadran
    /// kanan-bawah. Menulis angka persis akan mengunci presisi yang tidak
    /// dimiliki masukan yang ditulis tangan ini.
    func testMidLatitudeCrescentFacesRightAndDown() {
        let angle = CelestialVisual.brightLimbAngle(
            body: HorizontalCoord(altitudeDeg: 30, azimuthDeg: 250),
            sun: HorizontalCoord(altitudeDeg: -1, azimuthDeg: 285))
        guard let value = angle else { return XCTFail("sudut harus terdefinisi") }
        XCTAssertLessThan(value, 0, "harus condong ke bawah")
        XCTAssertGreaterThan(value, -.pi / 2, "harus condong ke kanan, bukan tegak ke bawah")
    }

    /// Kutub: sisi terang menghadap **atas** saat Matahari lebih tinggi pada
    /// azimut yang sama. Ini yang tidak bisa dijawab `isWaxing` sama sekali.
    func testPolarCrescentFacesUpWhenSunIsHigher() {
        let angle = CelestialVisual.brightLimbAngle(
            body: HorizontalCoord(altitudeDeg: 10, azimuthDeg: 90),
            sun: HorizontalCoord(altitudeDeg: 25, azimuthDeg: 90))
        guard let value = angle else { return XCTFail("sudut harus terdefinisi") }
        XCTAssertEqual(value, .pi / 2, accuracy: SkyMath.deg2rad(1),
                       "Matahari lebih tinggi di azimut yang sama -> sisi terang ke atas")
    }

    /// Kontrol negatif: `isWaxing` **tidak** bisa menghasilkan sudut ini.
    ///
    /// Uji ini mengunci alasan keberadaan `brightLimbAngle`: dua keadaan
    /// dengan arah waxing yang sama tetapi lintang berbeda harus memberi
    /// sudut yang berbeda jauh. Kalau kelak ada yang "menyederhanakan" sudut
    /// ini kembali menjadi boolean kanan/kiri, uji ini akan gagal.
    func testWaxingAloneCannotExpressTheLimbAngle() {
        let jakarta = CelestialVisual.brightLimbAngle(
            body: HorizontalCoord(altitudeDeg: 20, azimuthDeg: 283),
            sun: HorizontalCoord(altitudeDeg: -2, azimuthDeg: 285))
        let midLatitude = CelestialVisual.brightLimbAngle(
            body: HorizontalCoord(altitudeDeg: 30, azimuthDeg: 250),
            sun: HorizontalCoord(altitudeDeg: -1, azimuthDeg: 285))
        guard let a = jakarta, let b = midLatitude else {
            return XCTFail("kedua sudut harus terdefinisi")
        }
        XCTAssertGreaterThan(abs(a - b), SkyMath.deg2rad(30),
                             "dua lintang dengan waxing sama harus beda sudut jauh")
    }

    /// Sudut tidak diketahui: `nil`, bukan angka karangan.
    func testUnknownGeometryYieldsNoAngle() {
        // Bulan dan Matahari berimpit: tidak ada arah yang bisa ditentukan.
        let same = HorizontalCoord(altitudeDeg: 10, azimuthDeg: 100)
        XCTAssertNil(CelestialVisual.brightLimbAngle(body: same, sun: same))
    }

    // MARK: - Konversi sudut untuk `rotate(by:)`

    /// Tanda sudut **dibalik** saat diteruskan ke `GraphicsContext.rotate`.
    ///
    /// Model memakai konvensi matematis (positif = sisi terang ke atas);
    /// `GraphicsContext` SwiftUI berkoordinat layar (y ke bawah), tempat
    /// sudut positif berputar searah jarum jam. Kalau tanda itu tidak
    /// dibalik, sabit tercermin **vertikal** — sisi terang menghadap ke
    /// arah yang berlawanan — dan cacat itu tidak bisa ditangkap uji model
    /// mana pun, karena modelnya benar.
    func testDrawRotationMirrorsTheModelConvention() {
        let up = CelestialVisual.drawRotationRadians(brightLimbAngleRadians: .pi / 2)
        // Sisi terang menghadap ATAS di model → di layar (y ke bawah) itu
        // berarti putaran searah jarum jam seperempat, yaitu +90°, bukan
        // -90°. Diteruskan apa adanya (-90°) akan menghadap BAWAH.
        XCTAssertEqual(up, -.pi / 2, accuracy: 1e-12)
    }

    /// Kasus Jakarta dari `testCrescentInJakartaFacesDownNotRight`, dilihat
    /// dari sisi argumen `rotate`.
    ///
    /// Sisi terang menghadap **bawah** (model −90°). Di koordinat layar
    /// (y ke bawah), "bawah" adalah +90° — jadi argumennya harus **positif**.
    /// Kalau tandanya tidak dibalik, sabit Jakarta menghadap ke atas, dan
    /// itu persis kebalikan dari yang dihitung.
    func testJakartaCrescentIsRotatedDownwardNotUpward() {
        let model = CelestialVisual.brightLimbAngle(
            body: HorizontalCoord(altitudeDeg: 20, azimuthDeg: 283),
            sun: HorizontalCoord(altitudeDeg: -2, azimuthDeg: 285))
        guard let angle = model else { return XCTFail("sudut harus terdefinisi") }
        let draw = CelestialVisual.drawRotationRadians(brightLimbAngleRadians: angle)
        XCTAssertGreaterThan(draw, 0,
                             "sisi terang di bawah (model negatif) harus jadi putaran positif di layar")
    }

    /// Konversinya pembalikan murni: dua sudut yang berlawanan menghasilkan
    /// argumen yang berlawanan pula, dan nol tetap nol (sisi terang ke
    /// kanan tidak butuh putaran).
    func testDrawRotationIsAPureSignFlip() {
        XCTAssertEqual(CelestialVisual.drawRotationRadians(brightLimbAngleRadians: 0), 0)
        for angle in stride(from: -3.0, through: 3.0, by: 0.25) {
            XCTAssertEqual(
                CelestialVisual.drawRotationRadians(brightLimbAngleRadians: angle),
                -angle, accuracy: 1e-12)
        }
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

    /// Titik terjauh **irisan elips kutub dengan piringan** dari pusat bola,
    /// dalam satuan radius.
    ///
    /// Irisannya dihitung di sini karena itulah yang benar-benar tergambar:
    /// `drawPolarCaps` mengklip elips ke piringan, jadi bentuk di layar bukan
    /// elipsnya, melainkan bagian elips yang ada di dalam bola. Mengukur
    /// elipsnya saja akan mengukur bentuk yang tidak pernah muncul — persis
    /// kelas "gerbang mengukur gambar yang sudah tidak ada lagi".
    ///
    /// Titik di luar piringan dibuang, bukan dihitung: yang menjulur keluar
    /// memang dipotong, jadi menjulur bukan cacat — **kecuali** kalau tidak
    /// ada satu pun titik yang mencapai tepi, karena di situlah kutubnya
    /// berubah dari "menempel" menjadi "mengambang di dalam".
    private func farthestPointOfCap(_ cap: CelestialVisual.PolarCaps.Cap) -> Double {
        let steps = 4000
        var worst = 0.0
        for i in 0...steps {
            let t = 2 * Double.pi * Double(i) / Double(steps)
            let x = cap.halfWidth * cos(t)
            let y = cap.centerY + cap.halfHeight * sin(t)
            // Di luar piringan → dipotong klip, jadi bukan bagian gambarnya.
            guard x * x + y * y <= 1.0 else { continue }
            worst = max(worst, hypot(x, y))
        }
        return worst
    }

    func testPolarCapsTouchTheLimb() {
        // **Regresi untuk kutub yang mengambang di dalam piringan.**
        //
        // Versi lama memakai lebar tetap 0.55 R untuk kedua kutub. Diukur pada
        // render 400 px: pada baris terlebar kutub, tepi bola 0.675 R
        // sementara tepi kutub 0.550 R — rim merah 0.125 R (25 px) di atas
        // dan di sisi kiri-kanan kutubnya. Yang tergambar bukan kap es di
        // permukaan bola, melainkan elips yang ditempel agak ke dalam.
        //
        // Satu-satunya lebar yang membuat kutub benar-benar menyentuh tepi di
        // baris pusatnya adalah setengah-lebar bola pada ketinggian itu,
        // `sqrt(1 - y^2)`. Uji ini memeriksa **titik terjauh irisan** mencapai
        // tepi (1.0), jadi lebar tetap mana pun yang lebih sempit akan gagal
        // — bukan hanya angka 0.55 yang kebetulan dipakai sekarang.
        let caps = CelestialVisual.polarCaps()
        for (name, cap) in [("north", caps.north), ("south", caps.south)] {
            let farthest = farthestPointOfCap(cap)
            XCTAssertEqual(farthest, 1.0, accuracy: 1e-6,
                           "kutub \(name) tidak menyentuh tepi bola: terjauh \(farthest) R")
        }
    }

    func testPolarCapWidthIsDerivedFromTheLimb() {
        // Lebarnya **diturunkan**, bukan ditulis. Uji ini gagal untuk nilai
        // konstanta mana pun yang bukan `sqrt(1 - y^2)` di `centerY` — jadi
        // "kembalikan 0.55" tidak bisa lolos hanya karena angkanya terlihat
        // masuk akal.
        let caps = CelestialVisual.polarCaps()
        let expected = (1 - caps.north.centerY * caps.north.centerY).squareRoot()
        XCTAssertEqual(caps.north.halfWidth, expected, accuracy: 1e-12)
        XCTAssertNotEqual(caps.north.halfWidth, 0.55,
                          "lebar tetap 0.55 R adalah cacat yang uji ini tutup")
    }

    func testPolarCapsNeverLeaveThePlanetSurface() {
        // **Regresi untuk kutub selatan yang menembus 0.26 R keluar bola.**
        //
        // Versi lama memakai `y - radius` untuk kutub utara tapi
        // `y + radius - capHeight` untuk kutub selatan, dengan tinggi elips
        // `2 · capHeight` — jadi kutub selatan berakhir di y = 1.26, jauh di
        // luar bola: kutub putih menggantung di ruang kosong, bukan menempel
        // di permukaan.
        //
        // Sekarang lebarnya sengaja **lebih lebar** dari bola di dekat kutub
        // (itu yang membuatnya menempel di baris pusatnya), jadi yang menjaga
        // tidak ada luberan bukan angkanya melainkan **klip piringan** di
        // view. Uji ini memastikan irisannya tetap di dalam: setiap titik yang
        // terhitung memang lolos syarat `x² + y² ≤ 1`, dan tidak ada titik
        // yang terlewat di luar.
        let caps = CelestialVisual.polarCaps()
        for (name, cap) in [("north", caps.north), ("south", caps.south)] {
            let steps = 4000
            for i in 0...steps {
                let t = 2 * Double.pi * Double(i) / Double(steps)
                let x = cap.halfWidth * cos(t)
                let y = cap.centerY + cap.halfHeight * sin(t)
                guard x * x + y * y <= 1.0 else { continue }
                XCTAssertLessThanOrEqual(hypot(x, y), 1.0 + 1e-12,
                                         "kutub \(name) keluar bola")
            }
        }
    }

    func testPolarCapsAreMirrorImagesOfEachOther() {
        // Kutub Mars harus simetris terhadap ekuator. Versi lama tidak
        // (utara hanya meleset 0.004R, selatan 0.26R), dan simetri itulah
        // yang membuat keduanya melekat pada bola.
        let caps = CelestialVisual.polarCaps()
        XCTAssertEqual(caps.north.centerY, -caps.south.centerY, accuracy: 1e-12,
                       "kedua kutub harus cermin terhadap ekuator")
        XCTAssertEqual(caps.north.halfHeight, caps.south.halfHeight)
        XCTAssertEqual(caps.north.halfWidth, caps.south.halfWidth)
    }

    func testPolarCapDefaultsAreInRadiusUnits() {
        // Model tidak boleh bocor satuan: hasilnya proporsional radius
        // (satuan 1), supaya view cukup mengalikan sendiri.
        let caps = CelestialVisual.polarCaps()
        XCTAssertEqual(caps.north.centerY, -0.74, accuracy: 1e-12)
        XCTAssertEqual(caps.north.halfHeight, 0.26, accuracy: 1e-12)
        XCTAssertEqual(caps.north.halfWidth, (1.0 - 0.74 * 0.74).squareRoot(),
                       accuracy: 1e-12)
        // Kutub menjangkau ke arah ekuator tanpa menyentuhnya.
        XCTAssertLessThan(caps.north.centerY + caps.north.halfHeight, 0.0,
                          "kutub utara tidak boleh melewati ekuator")
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

    /// Setengah-bentang sumbu-x sebuah blob setelah rotasi.
    ///
    /// Elips yang diputar tidak lagi sejajar sumbu: bentang x-nya bertambah
    /// `hh·|sin θ|`. Mengabaikan suku ini akan membuat uji "tidak keluar
    /// frame" melaporkan aman untuk cakram galaksi yang sebenarnya keluar di
    /// sudutnya -- persis blob yang paling terlihat.
    private func rotatedHalfExtents(_ blob: VisualFrame.NebulaGeometry.Blob) -> (x: Double, y: Double) {
        let theta = blob.angleDegrees * .pi / 180
        let c = abs(cos(theta)), s = abs(sin(theta))
        return (blob.halfWidth * c + blob.halfHeight * s,
                blob.halfWidth * s + blob.halfHeight * c)
    }

    func testEveryDeepSkyBlobStaysInsideTheFrame() {
        // Kabut nebula memakai gradien yang sudah memudar ke transparan di
        // tepi blob, jadi keluar sedikit tidak merusak. Tapi keluar **cukup
        // jauh** memotong gradien di opasitas yang masih terlihat, dan tepi
        // rata-rata itu persis yang membuat nebula terlihat "digambar".
        // Uji ini memakai geometri model yang sama dengan view, bukan angka
        // yang disalin ulang -- kalau disalin, view bisa menyimpang tanpa
        // ada yang memberi tahu.
        //
        // **Semua morfologi ikut diuji**, termasuk `nil`. Bentuk yang
        // ditambahkan belakangan adalah yang paling mudah lupa diperiksa,
        // jadi daftarnya diambil dari `Morphology.allCases` -- bukan ditulis
        // tangan di sini, yang bisa tertinggal saat jenis baru muncul.
        var shapes: [DeepSkyCatalogue.Morphology?] = DeepSkyCatalogue.Morphology.allCases.map { $0 }
        shapes.append(nil)
        for morphology in shapes {
            for fuzziness in [0.0, 0.4, 0.8, 1.0] {
                let geometry = VisualFrame.deepSky(morphology: morphology,
                                                   fuzziness: fuzziness)
                XCTAssertFalse(geometry.blobs.isEmpty,
                               "\(String(describing: morphology)) harus punya blob")
                for (index, blob) in geometry.blobs.enumerated() {
                    let extents = rotatedHalfExtents(blob)
                    let spill = VisualFrame.overflow(centerX: abs(blob.offsetX),
                                                     centerY: abs(blob.offsetY),
                                                     halfWidth: extents.x,
                                                     halfHeight: extents.y)
                    XCTAssertLessThanOrEqual(
                        spill, 1e-9,
                        "blob \(index) \(String(describing: morphology)) keluar \(spill) R di luar frame pada fuzziness \(fuzziness)")
                }
            }
        }
    }

    func testNebulaGrowsWithFuzziness() {
        // Kabut yang lebih menyebar harus lebih besar -- itulah satu-satunya
        // hal yang membedakan "titik kabur" dari "kabut lebar", dan kalau
        // `fuzziness` diabaikan semua objek langit dalam tampil sama.
        let tight = VisualFrame.nebula(fuzziness: 0.0)
        let wide = VisualFrame.nebula(fuzziness: 1.0)
        XCTAssertGreaterThan(wide.blobs[0].halfWidth, tight.blobs[0].halfWidth,
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

    // MARK: - Morfologi: bentuk yang benar-benar berbeda di layar

    /// **Pengunci cacat lama.** Sebelum siklus ini, satu-satunya geometri
    /// objek langit dalam adalah `nebula(fuzziness:)` — tiga blob yang sama
    /// untuk setiap objek. Akibatnya galaksi Andromeda, gugus terbuka
    /// Pleiades, dan gugus bola Hercules tampil **identik**. Uji ini
    /// membuktikan cacatnya nyata dengan membandingkan geometri lama (satu
    /// bentuk untuk semua) terhadap geometri sekarang.
    func testLegacyDeepSkyGeometryWasIdenticalForEveryObject() {
        // Geometri lama tidak menerima morfologi sama sekali, jadi objek
        // berkategori berbeda menghasilkan blob dengan **bentuk yang sama**;
        // yang berbeda hanya skalanya. Itu justru masalahnya: galaksi vs
        // gugus bola tidak boleh dibedakan hanya oleh lebar.
        let galaxy = VisualFrame.nebula(fuzziness: 1.0)    // Andromeda
        let globular = VisualFrame.nebula(fuzziness: 0.35) // Hercules
        for geometry in [galaxy, globular] {
            let aspects = geometry.blobs.map { $0.halfHeight / $0.halfWidth }
            XCTAssertTrue(aspects.allSatisfy { abs($0 - 1.0) < 1e-12 },
                          "geometri lama selalu bulat — galaksi tidak mungkin berbentuk cakram")
        }
    }

    /// Nebula planetari harus **berongga**: tidak ada blob di pusat.
    ///
    /// Ini kebalikan dari nebula emisi, yang blobnya paling besar dan paling
    /// terang di tengah. Sampai siklus ini M27 (Dumbel) dan M57 (Cincin)
    /// dipetakan ke `.nebula`, jadi layar menyatakan "gas mengumpul di sini"
    /// pada dua objek yang gasnya justru sudah ditiup keluar. Yang membuat
    /// cacat itu tak terlihat: kedua bentuk tetap "kabut", dan tidak ada satu
    /// teks di layar yang menyebut bedanya.
    ///
    /// **Kenapa diuji pada `fuzziness` sebenarnya, bukan hanya 1.0.**
    /// `buildDeepSky` memperbesar setiap blob sebesar `0.62 + 0.38 · fuzziness`,
    /// dan cangkang ini lebarnya hanya 0.30 — delapan blob yang masing-masing
    /// membesar ke arah pusat bisa saja menutup lubang yang menjadi alasan
    /// bentuk ini ada. M27 memakai 0.68 dan M57 0.40, dan kedua angka itulah
    /// yang sungguhan sampai ke layar.
    ///
    /// **Kenapa yang diukur tepi dalamnya, bukan pusat blobnya.** Versi
    /// pertama uji ini mengukur jarak pusat blob, dan pusatnya tidak pernah
    /// bergerak — 0.42 untuk semua fuzziness — jadi uji itu akan tetap hijau
    /// berapa pun lebarnya blob membesar. Yang menentukan apakah lubangnya
    /// terlihat adalah **tepi dalam**: `radius − halfWidth`, yang menyusut
    /// dari 0.312 ke 0.246 pada rentang fuzziness ini. Uji pada pusat blob
    /// mengukur tempat yang tidak berubah, bukan lubang yang bisa menutup.
    func testPlanetaryNebulaIsHollowAtTheCentre() {
        for fuzziness in [0.0, 0.40, 0.68, 1.0] {
            let geometry = VisualFrame.deepSky(morphology: .planetaryNebula,
                                               fuzziness: fuzziness)
            XCTAssertFalse(geometry.blobs.isEmpty, "nebula planetari harus punya cangkang")
            let innerEdge = geometry.blobs.map { blob in
                hypot(blob.offsetX, blob.offsetY) - max(blob.halfWidth, blob.halfHeight)
            }.min() ?? -1
            XCTAssertGreaterThan(innerEdge, 0.2,
                                 "lubang cangkang menutup pada fuzziness \(fuzziness) (tepi dalam \(innerEdge)) — itu ciri nebula emisi")
        }
    }

    /// Cangkangnya harus duduk pada **satu radius**.
    ///
    /// Ini yang membedakannya dari `openCluster`, yang juga tanpa inti tapi
    /// tersebar pada radius yang berbeda-beda: nebula planetari adalah sebuah
    /// kulit bola, jadi semua bagian cangkangnya sejauh dari pusat. Tanpa uji
    /// ini, `.planetaryNebula` yang menyebar tak beraturan akan lolos semua
    /// pemeriksaan "tidak punya inti" sambil tampil sebagai gugus terbuka.
    func testPlanetaryNebulaShellSitsOnOneRadius() {
        let geometry = VisualFrame.deepSky(morphology: .planetaryNebula, fuzziness: 1.0)
        let radii = geometry.blobs.map { hypot($0.offsetX, $0.offsetY) }
        guard let smallest = radii.min(), let largest = radii.max() else {
            return XCTFail("nebula planetari harus punya cangkang")
        }
        XCTAssertLessThan(largest - smallest, 1e-9,
                          "cangkang harus satu radius (terkecil \(smallest) vs terbesar \(largest)) — kalau menyebar, ia tampil sebagai gugus terbuka")
    }

    /// Nebula planetari harus **berbeda** dari nebula emisi dan dari gugus
    /// terbuka — dua bentuk yang paling mirip dengannya di layar.
    ///
    /// Arah ketiga yang tak kalah penting ada di
    /// `testEveryMorphologyHasItsOwnSpokenWord`: gambar berbeda tapi kata
    /// sama berarti cacatnya cuma pindah ke telinga.
    func testPlanetaryNebulaDiffersFromItsNearestNeighbours() {
        let planetary = VisualFrame.deepSky(morphology: .planetaryNebula, fuzziness: 0.8)
        for other in [DeepSkyCatalogue.Morphology.nebula, .openCluster] {
            let geometry = VisualFrame.deepSky(morphology: other, fuzziness: 0.8)
            XCTAssertNotEqual(planetary.blobs, geometry.blobs,
                              "nebula planetari identik dengan \(other) — keduanya akan tampil sama")
        }
    }

    /// Galaksi harus benar-benar **elips**, bukan lingkaran.
    ///
    /// Kalau semua rasio sumbu mendekati 1, "galaksi" hanya nama untuk kabut
    /// bulat yang sama dengan nebula — pengguna tidak bisa membedakannya.
    func testGalaxyIsAnEllipticalDiscNotACircle() {
        let geometry = VisualFrame.deepSky(morphology: .galaxy, fuzziness: 1.0)
        let aspects = geometry.blobs.map { $0.halfHeight / $0.halfWidth }
        XCTAssertLessThan(aspects.max() ?? 1, 0.5,
                          "cakram galaksi harus jelas lebih lebar daripada tingginya")
        XCTAssertGreaterThan(aspects.min() ?? 0, 0,
                             "rasio sumbu harus positif")
    }

    /// Galaksi harus **miring**, bukan mendatar sempurna.
    ///
    /// Cakram mendatar pada ikon persegi terbaca sebagai garis, bukan galaksi.
    func testGalaxyDiscIsTilted() {
        let geometry = VisualFrame.deepSky(morphology: .galaxy, fuzziness: 1.0)
        XCTAssertTrue(geometry.blobs.contains { abs($0.angleDegrees) > 1 },
                      "cakram galaksi harus miring supaya terbaca sebagai galaksi")
    }

    /// Galaksi harus punya **tonjolan inti** yang lebih bulat daripada cakram.
    ///
    /// Ini yang membedakannya dari nebula lonjong: lapisan paling dalam makin
    /// mendekati bulat. Kalau semua lapisan punya rasio sama, hasilnya elips
    /// datar tanpa pusat.
    func testGalaxyHasARounderCoreThanItsDisc() {
        let geometry = VisualFrame.deepSky(morphology: .galaxy, fuzziness: 1.0)
        let aspects = geometry.blobs.map { $0.halfHeight / $0.halfWidth }
        guard let widest = aspects.first, let roundest = aspects.max() else {
            return XCTFail("galaksi harus punya blob")
        }
        XCTAssertGreaterThan(roundest, widest,
                             "lapisan inti harus lebih bulat daripada cakram terluar")
    }

    /// Tonjolan inti galaksi harus **terlihat**: inti bukan sekadar selembut
    /// kabut di atas cakram, ia harus punya **ukuran** yang jelas lebih kecil dan
    /// **kecerahan** yang jelas lebih tinggi.
    ///
    /// **Kenapa uji ini ada, dan bukan mengukur `aspectRatio`.** Ketiga uji
    /// galaksi yang lama mengukur angka yang **tidak pernah bergerak**:
    /// `buildDeepSky` menghitung `halfHeight = halfWidth · aspect`, jadi
    /// `halfHeight / halfWidth` kembali persis `aspect` — berapapun lebar,
    /// skala, atau ruang yang dihitung. `aspect` juga ditulis sebagai konstanta
    /// di layout. Maka "lapisan inti lebih bulat" (`aspect` 0.42 > 0.34) adalah
    /// **pembacaan ulang konstanta layout**, bukan pengukuran bentuk: ia hijau
    /// meski intinya diperkecil 130× sehingga tidak terlihat sebagai tonjolan,
    /// dan hijau meski urutannya dibalik sehingga yang bulat justru cakramnya.
    ///
    /// Yang benar-benar menentukan apakah tonjolan itu terlihat adalah ukuran
    /// dan opasitas, dan keduanya **bergerak** bersama lebar:
    /// `halfWidth = room · growth · widthScale`. Angka di bawah diukur pada
    /// beberapa `fuzziness` supaya tidak bergantung pada satu titik.
    ///
    /// **Mutasi yang dulu lolos** (dibuktikan, bukan diklaim): `widthScale`
    /// inti `0.26 -> 0.002` — inti menyusut jadi 0.2% dari cakram — tetap
    /// **hijau di 633/633 uji**, karena rasio aspect-nya tidak berubah sama
    /// sekali. Versi ini melihatnya merah.
    func testGalaxyCoreBulgeIsVisibleNotJustRounder() {
        for fuzziness in [0.0, 0.6, 1.0] {
            let blobs = VisualFrame.deepSky(morphology: .galaxy,
                                            fuzziness: fuzziness).blobs
            // Cakram terluar = blob paling lebar; inti = blob paling kecil.
            guard let widest = blobs.max(by: { $0.halfWidth < $1.halfWidth }),
                  let core = blobs.min(by: { $0.halfWidth < $1.halfWidth }) else {
                return XCTFail("galaksi harus punya blob")
            }
            let sizeRatio = core.halfWidth / widest.halfWidth
            XCTAssertGreaterThan(sizeRatio, 0.10,
                                 "inti galaksi jadi butiran pada fuzziness \(fuzziness) "
                                 + "(rasio lebar \(sizeRatio)) — tonjolan inti tidak terlihat")
            // Dan intinya harus **lebih terang**, bukan hanya lebih kecil:
            // pada opasitas sama, blob kecil di atas cakram besar hilang.
            XCTAssertGreaterThan(core.opacity, widest.opacity,
                                 "inti galaksi harus lebih terang daripada cakramnya "
                                 + "pada fuzziness \(fuzziness)")
        }
    }

    /// Gugus bola harus **memusat**: ada inti di tengah yang lebih besar
    /// daripada bintang di sekelilingnya.
    func testGlobularClusterHasADenseCentre() {
        let geometry = VisualFrame.deepSky(morphology: .globularCluster, fuzziness: 1.0)
        guard let core = geometry.blobs.first else {
            return XCTFail("gugus bola harus punya blob")
        }
        XCTAssertEqual(hypot(core.offsetX, core.offsetY), 0, accuracy: 1e-12,
                       "inti gugus bola harus di tengah")
        let maxHalfWidth = geometry.blobs.map(\.halfWidth).max() ?? 0
        XCTAssertEqual(core.halfWidth, maxHalfWidth, accuracy: 1e-12,
                       "inti gugus bola harus blob terbesar — kalau tidak, bentuknya tidak memusat")
    }

    /// Gugus bola harus **redup ke luar**, seperti yang ditulis di layout.
    ///
    /// Layout-nya menyebut inti "paling terang" dan dua cincin "makin redup
    /// ke luar". Tapi **tidak ada satu pun uji yang menjaga itu**, dan
    /// `testGlobularClusterHasADenseCentre` memang tidak bisa menjaganya:
    /// ia hanya membandingkan inti dengan blob **terbesar**, bukan yang paling
    /// terang — jadi soal warna sama sekali tidak tersentuh.
    ///
    /// **Mutasi yang dulu lolos** (dibuktikan, bukan diklaim): opasitas inti
    /// `0.55 -> 0.22` membuat inti sama redupnya dengan cincin **terluar** —
    /// gradien kecerahannya jadi rata — dan **634/634 uji tetap hijau**.
    ///
    /// **Kenapa dibandingkan per pita radius, bukan per blob.** Versi pertama
    /// uji ini mengambil `byRadius[1]` dan `byRadius[count-1]`, yaitu **satu**
    /// anggota tiap cincin. Karena `sorted` tidak menentukan urutan anggota
    /// yang radiusnya sama, mutasi **satu** blob cincin luar lolos tanpa
    /// terlihat: indeks terakhir bisa jatuh ke blob lain yang belum dirusak.
    /// Yang benar dijaga ada dua, dan keduanya di sini:
    ///
    ///  1. **Seragam dalam satu pita** — semua anggota cincin sama redupnya.
    ///     Tanpa ini, satu blob yang lebih terangeredup di dalam cincin yang
    ///     sama lolos begitu saja.
    ///  2. **Menurun antar pita** — inti > cincin dalam > cincin luar.
    ///
    /// Mutasi yang dibuktikan merah pada versi ini: inti `0.55 -> 0.22`
    /// (gradien rata), **dan** satu anggota cincin luar `0.22 -> 0.38`
    /// (pita jadi tidak seragam).
    func testGlobularClusterDimsWithRadius() {
        for fuzziness in [0.0, 0.6, 1.0] {
            let blobs = VisualFrame.deepSky(morphology: .globularCluster,
                                            fuzziness: fuzziness).blobs
            // Kelompokkan ke pita radius: inti di 0, lalu dua cincin. Kunci
            // dibulatkan ke 2 desimal karena radius layout (0.30, 0.46) dan
            // `room`-nya tidak pernah persis bulat.
            var bands: [Double: [Double]] = [:]
            for blob in blobs {
                let radius = (hypot(blob.offsetX, blob.offsetY) * 100).rounded() / 100
                bands[radius, default: []].append(blob.opacity)
            }
            let ordered = bands.keys.sorted()
            guard ordered.count >= 3 else {
                return XCTFail("gugus bola harus punya inti + beberapa cincin "
                               + "(hanya \(ordered.count) pita pada fuzziness \(fuzziness))")
            }
            let core = bands[ordered[0]] ?? []
            let innerRing = bands[ordered[1]] ?? []
            let outerRing = bands[ordered[ordered.count - 1]] ?? []

            // 1. Seragam dalam tiap pita — semua anggota satu cincin sama redup.
            for (name, band) in [("inti", core), ("cincin dalam", innerRing),
                                 ("cincin luar", outerRing)] {
                guard let lo = band.min(), let hi = band.max() else {
                    return XCTFail("pita \(name) kosong pada fuzziness \(fuzziness)")
                }
                XCTAssertEqual(lo, hi, accuracy: 1e-9,
                               "\(name) gugus bola harus sama redupnya semua anggota "
                               + "(terang \(hi) vs redup \(lo)) pada fuzziness \(fuzziness)")
            }
            // 2. Menurun ke luar — bandingkan **paling redup** di pita dalam
            //    dengan **paling terang** di pita luar, supaya selisih
            //    terkecil pun tidak bisa lolos.
            let (coreLo, coreHi) = (core.min() ?? 0, core.max() ?? 0)
            let (innerLo, innerHi) = (innerRing.min() ?? 0, innerRing.max() ?? 0)
            let (outerLo, outerHi) = (outerRing.min() ?? 0, outerRing.max() ?? 0)
            XCTAssertGreaterThan(coreLo, innerHi,
                                 "inti gugus bola harus lebih terang daripada cincin dalam "
                                 + "pada fuzziness \(fuzziness)")
            XCTAssertGreaterThan(innerLo, outerHi,
                                 "cincin dalam harus lebih terang daripada cincin luar "
                                 + "pada fuzziness \(fuzziness)")
        }
    }

    /// Gugus terbuka harus **tersebar**: tidak ada inti di pusat.
    ///
    /// Ketiadaan pusat inilah yang membedakannya dari gugus bola, bukan
    /// ukurannya. Dua hal diperiksa, dan keduanya mengukur "ketiadaan inti":
    /// tidak ada blob yang duduk di tengah, dan rata-rata jaraknya jauh dari
    /// pusat. Kalau bintangnya mengerumun di tengah, bentuknya jadi gugus bola.
    ///
    /// **Kenapa sekarang diukur pada tepi dalam, dan pada beberapa
    /// `fuzziness`.** Sampai siklus ini uji ini mengukur jarak **pusat** blob
    /// pada satu nilai fuzziness. Pusatnya tidak pernah bergerak — `buildDeepSky`
    /// menggeser skala lebar blob, bukan letaknya — jadi ukuran itu kebal
    /// terhadap satu-satunya hal yang bisa menutup pusat: blob yang membesar
    /// ke arah dalam. Tepi dalamnya menyusut dari 0.523 (fuzziness 0) ke
    /// 0.463 (fuzziness 1.0), dan nilai-nilai itulah yang menentukan apakah
    /// bagian tengah benar-benar kosong di layar.
    ///
    /// Cacatnya identik dengan yang ditemukan lebih dulu pada
    /// `testPlanetaryNebulaIsHollowAtTheCentre`, dan ditemukan dengan
    /// memeriksa uji sebelahnya setelah memperbaiki yang itu — kelas cacatnya
    /// ada pada **cara mengukur**, bukan pada morfologinya.
    func testOpenClusterHasNoCentralCore() {
        for fuzziness in [0.0, 0.5, 1.0] {
            let geometry = VisualFrame.deepSky(morphology: .openCluster,
                                               fuzziness: fuzziness)
            XCTAssertFalse(geometry.blobs.isEmpty, "gugus terbuka harus punya blob")
            // Tidak ada blob yang menempel di pusat: **tepi dalamnya**
            // yang diukur, bukan pusat blobnya (lihat catatan di atas).
            let innerEdge = geometry.blobs.map { blob in
                hypot(blob.offsetX, blob.offsetY) - max(blob.halfWidth, blob.halfHeight)
            }.min() ?? -1
            XCTAssertGreaterThan(innerEdge, 0.2,
                                 "gugus terbuka menutup pusatnya pada fuzziness \(fuzziness) (tepi dalam \(innerEdge)) — itu ciri gugus bola")
            // Dan rata-rata blob harus jauh dari pusat.
            let meanRadius = geometry.blobs.map { hypot($0.offsetX, $0.offsetY) }.reduce(0, +)
                / Double(geometry.blobs.count)
            XCTAssertGreaterThan(meanRadius, 0.4,
                                 "bintang gugus terbuka harus tersebar, bukan mengerumun di pusat")
        }
    }

    /// **Pembeda langsung** gugus bola vs gugus terbuka: seberapa memusat.
    ///
    /// Ini properti yang benar-benar memisahkan keduanya di layar. Menguji
    /// ukuran blob saja tidak cukup — yang membuat gugus bola terbaca sebagai
    /// "bola" adalah bintang-bintangnya **mengumpul ke pusat**, sedangkan
    /// gugus terbuka menyebar merata. Uji ini membandingkan keduanya, jadi ia
    /// tidak bisa hijau kalau keduanya sama-sama memusat atau sama-sama rata.
    func testGlobularIsMoreConcentratedThanOpenCluster() {
        func concentration(_ morphology: DeepSkyCatalogue.Morphology) -> Double {
            let blobs = VisualFrame.deepSky(morphology: morphology, fuzziness: 1.0).blobs
            return blobs.map { hypot($0.offsetX, $0.offsetY) }.reduce(0, +) / Double(blobs.count)
        }
        let globular = concentration(.globularCluster)
        let open = concentration(.openCluster)
        XCTAssertLessThan(globular, open,
                          "gugus bola harus lebih memusat daripada gugus terbuka (bola \(globular) vs terbuka \(open))")
    }

    /// Bentuk yang berbeda harus menghasilkan geometri yang **berbeda**.
    ///
    /// Ini uji paling langsung terhadap kelas cacatnya: kalau dua morfologi
    /// menghasilkan blob yang sama, layar menampilkan bentuk yang sama.
    ///
    /// **Kenapa daftarnya dari `allCases`, bukan ditulis di sini.** Sampai
    /// siklus ini daftarnya ditulis tangan (empat nama), jadi `.planetaryNebula`
    /// lahir tanpa ikut teruji oleh uji yang paling langsung mengawasi kelas
    /// cacat ini — persis drift yang `testEveryMorphologyIsUsedByTheCatalogue`
    /// ada untuk mencegah di sisi katalog. Daftar yang ditulis tangan di uji
    /// adalah daftar yang berhenti tumbuh tanpa ada yang diberitahu.
    func testDifferentMorphologiesProduceDifferentGeometry() {
        let shapes: [DeepSkyCatalogue.Morphology] = DeepSkyCatalogue.Morphology.allCases
        XCTAssertGreaterThan(shapes.count, 1, "uji ini tidak berguna tanpa minimal dua bentuk")
        let geometries = shapes.map { VisualFrame.deepSky(morphology: $0, fuzziness: 0.7) }
        for i in geometries.indices {
            for j in geometries.indices where j > i {
                XCTAssertNotEqual(
                    geometries[i].blobs, geometries[j].blobs,
                    "\(shapes[i]) dan \(shapes[j]) menghasilkan geometri identik — keduanya akan tampil sama")
            }
        }
    }

    /// Morfologi `nil` (id tak dikenal) harus jatuh ke kabut netral, **bukan**
    /// menebak salah satu bentuk.
    func testUnknownMorphologyFallsBackToNeutralNebula() {
        let unknown = VisualFrame.deepSky(morphology: nil, fuzziness: 0.6)
        let neutral = VisualFrame.nebula(fuzziness: 0.6)
        XCTAssertEqual(unknown.blobs, neutral.blobs,
                       "morfologi tak dikenal harus memakai kabut netral")
        // Dan bentuk netral itu tidak boleh sama dengan bentuk galaksi/gugus.
        let galaxy = VisualFrame.deepSky(morphology: .galaxy, fuzziness: 0.6)
        XCTAssertNotEqual(unknown.blobs, galaxy.blobs,
                          "kabut netral tidak boleh mengklaim bentuk galaksi")
    }

    /// `objectID` harus diteruskan dari objek engine ke model visual.
    ///
    /// Tanpa ini, view tidak bisa menanyakan morfologi — dan seluruh jalur
    /// bentuk kembali menjadi satu bentuk untuk semua, tanpa satu pun uji
    /// yang menangkapnya.
    func testDeepSkyVisualCarriesTheObjectID() {
        for object in DeepSkyCatalogue.objects {
            let visual = CelestialVisual(object: object)
            XCTAssertEqual(visual.objectID, object.id,
                           "id objek harus diteruskan supaya morfologinya bisa dicari")
        }
    }

    // MARK: - Bentuk objek langit dalam untuk VoiceOver

    /// Setiap morfologi punya **kata sendiri**.
    ///
    /// Diuji lewat `deepSkyMorphologyText` (murni) dan bukan
    /// `spokenDeepSkyMorphology`, karena yang terakhir memanggil
    /// `TextLocalization` — di Linux selalu nilai bawaan, jadi mengujinya
    /// langsung hanya menguji teksnya, bukan pemilihannya.
    ///
    /// Yang dijaga di sini bukan terjemahan, melainkan **pembedanya**: kalau
    /// dua jenis berbagi satu kata, pengguna VoiceOver mendengar bentuk yang
    /// sama untuk dua gambar yang berbeda — persis cacat yang ingin ditutup.
    func testEveryMorphologyHasItsOwnSpokenWord() {
        let words = DeepSkyCatalogue.Morphology.allCases.map {
            CelestialVisual.deepSkyMorphologyText($0).rawValue
        }
        XCTAssertEqual(Set(words).count, words.count,
                       "dua morfologi berbagi kata — keduanya akan terdengar sama")
    }

    /// Pemetaannya benar per jenis, bukan sekadar unik.
    func testMorphologyMapsToTheRightWord() {
        XCTAssertEqual(CelestialVisual.deepSkyMorphologyText(.nebula).rawValue,
                       LocalizedText.deepSkyMorphologyNebula.rawValue)
        XCTAssertEqual(CelestialVisual.deepSkyMorphologyText(.galaxy).rawValue,
                       LocalizedText.deepSkyMorphologyGalaxy.rawValue)
        XCTAssertEqual(CelestialVisual.deepSkyMorphologyText(.openCluster).rawValue,
                       LocalizedText.deepSkyMorphologyOpenCluster.rawValue)
        XCTAssertEqual(CelestialVisual.deepSkyMorphologyText(.globularCluster).rawValue,
                       LocalizedText.deepSkyMorphologyGlobularCluster.rawValue)
    }

    /// Objek langit dalam **yang ada di katalog** harus punya bentuk terdengar.
    ///
    /// Ini yang mengunci jalurnya: gambar memakai morfologi, jadi pengumuman
    /// harus memakainya juga. Kalau salah satu `nil`, artinya gambar dan
    /// suara berbeda pendapat tentang objek yang sama.
    func testEveryCatalogueDeepSkyObjectHasASpokenMorphology() {
        for object in DeepSkyCatalogue.objects {
            let visual = CelestialVisual(object: object)
            XCTAssertNotNil(visual.spokenDeepSkyMorphology(isConfirmed: true),
                            "\(object.id) punya bentuk di layar tapi tidak terdengar")
        }
    }

    /// **Pengunci pembeda nyata:** dua gugus dengan jenis yang sama harus
    /// terdengar berbeda.
    ///
    /// Ini cacat yang sesungguhnya — "Gugus Ptolemy" dan "Gugus Hercules"
    /// sama-sama `kind: .deepSky`, dan sebelum ini diumumkan dengan kalimat
    /// yang sama persis, padahal di layar keduanya digambar berbeda.
    func testTwoClustersWithTheSameKindSoundDifferent() {
        let ptolemy = DeepSkyCatalogue.objects.first { $0.id == "m7" }!
        let hercules = DeepSkyCatalogue.objects.first { $0.id == "m13" }!
        XCTAssertEqual(ptolemy.kind, hercules.kind,
                       "prasyarat: keduanya jenis yang sama, jadi jenisnya tidak membedakan")
        let a = CelestialVisual(object: ptolemy).spokenDeepSkyMorphology(isConfirmed: true)
        let b = CelestialVisual(object: hercules).spokenDeepSkyMorphology(isConfirmed: true)
        XCTAssertNotNil(a); XCTAssertNotNil(b)
        XCTAssertNotEqual(a, b,
                          "gugus terbuka dan gugus bola harus terdengar berbeda")
    }

    /// Bukan objek langit dalam → **tidak ada** bentuk yang diucapkan.
    ///
    /// Planet, Bulan, dan bintang punya bentuk yang sudah ditentukan
    /// jenisnya; mengucapkan morfologi untuk mereka berarti mengarang
    /// informasi yang tidak ada di layar.
    func testNonDeepSkyObjectsHaveNoSpokenMorphology() {
        let notDeepSky: [CelestialVisual] = [
            CelestialVisual(kind: .planet, planet: .jupiter, objectID: "jupiter"),
            CelestialVisual(kind: .star, objectID: "sirius"),
            CelestialVisual(kind: .sun, objectID: "sun"),
            CelestialVisual(kind: .moon, illuminationFraction: 0.5, isWaxing: true,
                            objectID: "moon")
        ]
        for visual in notDeepSky {
            XCTAssertNil(visual.spokenDeepSkyMorphology(isConfirmed: true),
                         "\(visual.kind) tidak boleh mengucapkan bentuk objek langit dalam")
        }
    }

    /// Id tak dikenal → **tidak ada** bentuk yang ditebak.
    ///
    /// Sama dengan `morphology(forObjectID:)` yang mengembalikan `nil`: gambar
    /// memakai kabut netral, dan pengumuman tidak menyebut bentuk apa pun.
    /// Kalau di sini menebak, suara akan mengklaim bentuk yang tidak ada di
    /// layar.
    func testUnknownDeepSkyIDDoesNotGuessASpokenMorphology() {
        let visual = CelestialVisual(kind: .deepSky, fuzziness: 0.6,
                                     objectID: "bukan-objek-nyata")
        XCTAssertNil(visual.spokenDeepSkyMorphology(isConfirmed: true),
                     "id tak dikenal tidak boleh menebak bentuk")
        // Dan objek langit dalam tanpa id sama sekali juga tidak menebak.
        let noID = CelestialVisual(kind: .deepSky, fuzziness: 0.6)
        XCTAssertNil(noID.spokenDeepSkyMorphology(isConfirmed: true))
    }

    /// **Saat engine ragu, bentuknya tidak diucapkan.**
    ///
    /// Ini pasangan suara dari aturan gambar: saat `isConfirmed == false`,
    /// gambar memakai kabut netral (lihat `DeepSkyCatalogue.drawableMorphology`),
    /// jadi pengumuman tidak boleh menyebut bentuk apa pun. Tanpa ini,
    /// pengguna VoiceOver mendengar "galaksi" di sebelah badge "Ragu" — suara
    /// yang lebih yakin daripada gambar yang menemani badge itu.
    func testUnconfirmedObjectDoesNotSpeakAShape() {
        for object in DeepSkyCatalogue.objects {
            let visual = CelestialVisual(object: object)
            XCTAssertNotNil(visual.spokenDeepSkyMorphology(isConfirmed: true),
                            "prasyarat: saat yakin, bentuknya terdengar")
            XCTAssertNil(visual.spokenDeepSkyMorphology(isConfirmed: false),
                         "\(object.name) mengucapkan bentuknya saat engine ragu")
        }
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

    // MARK: - Penanda kandidat: penanda keraguan tidak boleh ikut terpotong

    /// Geometri lencana versi lama: radius `0.22 · lebar`, pusat di
    /// `(0.846 · lebar, 0.154 · lebar)` — diukur dari pojok kiri atas.
    ///
    /// Dipakai sebagai **bukti merah**, bukan dokumentasi: `testCandidateMarkerOverflowedOnTwoSides`
    /// menghitung ulang angka ini dan membuktikan lencana lama benar-benar
    /// keluar frame, sehingga perbaikannya bukan sekadar perbedaan rasa
    /// tentang seberapa besar lencana yang pantas.
    private func legacyCandidateMarker() -> VisualFrame.CandidateMarker {
        // Konversi dari satuan "lebar" (0…1 dari pojok) ke satuan "radius"
        // (dari tengah frame): `r = 2 · (x − 0.5)`.
        let widthRadius = 0.22 * 2.0
        return VisualFrame.CandidateMarker(
            centerX: (0.846 - 0.5) * 2.0,
            centerY: (0.154 - 0.5) * 2.0,
            radius: widthRadius,
            glyphFraction: 0.52)
    }

    func testLegacyCandidateMarkerOverflowedOnTwoSides() {
        // **Pengunci cacat lama.** Lencana berada di **sudut**, jadi dua
        // sisinya dekat tepi frame sekaligus — bukan satu.
        let legacy = legacyCandidateMarker()
        let spill = legacy.overflow()
        XCTAssertGreaterThan(spill, 0.1,
                             "lencana lama harus terbukti keluar frame; spill=\(spill) R")
        // Sisi kanan **dan** sisi atas keduanya keluar: itulah sebabnya
        // lingkarannya tampil sebagai busur yang berhenti mendadak, bukan
        // sebagai lingkaran.
        XCTAssertGreaterThan(abs(legacy.centerX) + legacy.radius,
                             VisualFrame.halfExtent,
                             "sisi kanan lencana lama keluar dari frame")
        XCTAssertGreaterThan(abs(legacy.centerY) + legacy.radius,
                             VisualFrame.halfExtent,
                             "sisi atas lencana lama keluar dari frame")
    }

    func testCandidateMarkerStaysInsideTheFrame() {
        // Lencana adalah satu-satunya penanda di layar yang mengatakan
        // "engine ragu". Kalau ia terpotong tegak, yang tersisa hanya gambar
        // objek tanpa penanda — dan gambar tanpa penanda terbaca sebagai
        // identitas yang pasti. Cacat pada bentuk ini membatalkan alasan
        // bentuk ini ada.
        let marker = VisualFrame.candidateMarker()
        XCTAssertLessThanOrEqual(marker.overflow(), 1e-12,
                                 "lencana kandidat keluar \(marker.overflow()) R di luar frame")
    }

    func testCandidateMarkerStaysInsideForAnySize() {
        // Yang membuat batas ini konstruktif: `d + radius = corner`. Jadi
        // memperbesar lencana tidak bisa mendorongnya keluar — ia menempel
        // makin dekat ke tengah. Polanya sama dengan `star`, dan alasannya
        // sama: lencana ini dipakai di kartu jam 38pt dan panel iPhone
        // 132pt, jadi radiusnya tidak boleh bergantung pada siapa yang
        // menggambar.
        for fraction in [0.1, 0.34, 0.6, 1.0] {
            let marker = VisualFrame.candidateMarker(cornerFraction: fraction)
            XCTAssertLessThanOrEqual(marker.overflow(), 1e-12,
                                     "lencana \(fraction) keluar \(marker.overflow()) R dari frame")
        }
        for extent in [0.5, 1.0, 2.0] {
            let marker = VisualFrame.candidateMarker(frameHalfExtent: extent)
            let spill = marker.overflow(frameHalfExtent: extent)
            XCTAssertLessThanOrEqual(spill, 1e-12,
                                     "lencana pada frame \(extent) keluar \(spill) R")
        }
    }

    func testCandidateMarkerKeepsInsetFromTheEdge() {
        // Lencana yang menempel pada bingkai kartu tampak seperti cacat
        // render, bukan seperti penanda. Jaraknya harus nyata.
        // Diukur terhadap frame yang dipakai lencana itu, bukan terhadap
        // konstanta: kalau tidak, uji ini hanya kebetulan benar untuk frame 1.0.
        for extent in [0.5, 1.0, 2.0] {
            let marker = VisualFrame.candidateMarker(frameHalfExtent: extent)
            let gap = extent - (abs(marker.centerX) + marker.radius)
            XCTAssertGreaterThan(gap, 0.05 * extent,
                                 "lencana menempel pada tepi frame (jarak \(gap) R)")
        }
    }

    func testCandidateMarkerIsVisibleButDoesNotCoverTheObject() {
        // Dua batas yang saling menarik: lencana harus cukup besar untuk
        // terbaca sebagai tanda tanya di kartu jam 38pt, tapi tidak boleh
        // menutupi gambar objeknya — kalau menutupi, pengguna kehilangan
        // justru informasi yang masih boleh ditampilkan saat ragu (warna
        // bola tetap boleh tampil).
        let marker = VisualFrame.candidateMarker()
        XCTAssertGreaterThan(marker.radius, 0.15,
                             "lencana terlalu kecil untuk terbaca")
        XCTAssertLessThan(marker.radius, 0.45,
                          "lencana menutupi gambar objeknya")
        // Glif tanda tanya harus muat di dalam lingkarannya.
        XCTAssertLessThanOrEqual(marker.glyphRadius, marker.radius,
                                 "glif tanda tanya keluar dari lingkaran lencana")
    }

    func testCandidateMarkerSitsInTheTopRightCorner() {
        // Letaknya di sudut kanan atas, **bukan** di tengah: penanda di
        // tengah menutupi gambar dan membuat kelihatan rusak. Sudut cukup
        // jelas tanpa menutupi.
        let marker = VisualFrame.candidateMarker()
        XCTAssertGreaterThan(marker.centerX, 0, "lencana harus di sisi kanan")
        XCTAssertLessThan(marker.centerY, 0, "lencana harus di sisi atas")
    }

    // MARK: - Apakah gambar ini perlu denyut sama sekali

    /// **Kelas cacat: timer yang menggambar gambar yang sama 30 kali per
    /// detik.** `DiagnosticsView` membungkus panel kunci dalam
    /// `TimelineView(.animation(minimumInterval: 1/30))` supaya glow bintang
    /// bisa berdenyut. Tapi `pulse` hanya dibaca di `drawStar` — untuk planet,
    /// Bulan, Matahari, dan nebula, `Canvas` menggambar piksel yang persis
    /// sama setiap frame. Hasilnya bukan gambar yang lebih halus: itu 30
    /// render per detik untuk gambar diam, dan dua app tidak bisa tahu
    /// apakah objek yang tampil memang berdenyut.
    ///
    /// Yang dikunci di sini adalah properti **model**, bukan memindahkan
    /// `TimelineView`: apakah sebuah visual punya denyut adalah pertanyaan
    /// tentang bendanya, dan pertanyaan itu harus punya satu jawaban yang
    /// bisa diuji di Linux.
    func testOnlyStarsPulse() {
        for kind in [CelestialVisual.Kind.planet, .moon, .sun, .deepSky] {
            let visual = CelestialVisual(kind: kind)
            XCTAssertFalse(visual.hasPulse,
                           "\(kind.rawValue) tidak punya denyut; TimelineView akan tetap menggambar 30 frame per detik untuknya")
        }
        XCTAssertTrue(CelestialVisual(kind: .star).hasPulse,
                      "bintang satu-satunya jenis yang benar-benar berdenyut")
    }

    /// Properti ini harus ikut cara pembuatan dari objek engine, bukan hanya
    /// enum tangan: kalau ada cabang baru yang lupa, katalog penuh akan
    /// kegagalan diam-diam.
    func testPulseFollowsTheObjectKindForEveryCatalogueEntry() {
        for star in Catalogue.brightStars {
            let visual = CelestialVisual(object: star)
            XCTAssertEqual(visual.hasPulse, visual.kind == .star,
                           "katalog \(star.id) punya jenis \(visual.kind.rawValue) tapi hasPulse=\(visual.hasPulse)")
        }
        // Benda di luar katalog juga diperiksa, tapi dengan **jenisnya yang
        // sebenarnya** — katalog `brightStars` hanya berisi bintang, jadi
        // planet/Bulan/Matahari tidak akan pernah ikut loop di atas. Loop ini
        // memanggil `object(id:kind:)` dengan jenis yang benar; versi
        // pertamanya memakai `.planet` untuk semua id termasuk "moon" dan
        // "sun", jadi ia lulus tanpa pernah menguji apa pun.
        let outsideCatalogue: [(String, ObjectKind)] = [
            ("jupiter", .planet), ("saturn", .planet), ("mars", .planet),
            ("moon", .moon), ("sun", .sun), ("m42", .deepSky),
        ]
        for (id, kind) in outsideCatalogue {
            let visual = CelestialVisual(object: object(id: id, kind: kind))
            XCTAssertFalse(visual.hasPulse,
                           "\(id) (\(kind)) tidak berdenyut; jenis yang lebih baru harus ikut dijaga")
        }
    }

    // MARK: - Nama fase Bulan untuk VoiceOver

    /// Membangun visual Bulan dengan fraksi iluminasi tertentu.
    private func moon(fraction: Double, waxing: Bool?) -> CelestialVisual {
        CelestialVisual(object: object(id: "moon", kind: .moon),
                        moonIlluminationFraction: fraction,
                        isWaxing: waxing)
    }

    /// Ambang fase memilih nama yang benar, termasuk batasnya.
    ///
    /// Diuji lewat `moonPhaseText` (murni) dan bukan `spokenPhase`, karena
    /// `spokenPhase` memanggil `TextLocalization`, yang di Linux selalu
    /// mengembalikan nilai bawaan — jadi mengujinya langsung hanya akan
    /// menguji teksnya, bukan pemilihannya.
    func testMoonPhaseNamesFollowTheIlluminationThresholds() {
        // Purnama dan bulan baru simetris: arahnya tidak diperlukan.
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.99,
                                                      isWaxing: nil).rawValue,
                       LocalizedText.moonPhaseFull.rawValue)
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.01,
                                                      isWaxing: nil).rawValue,
                       LocalizedText.moonPhaseNew.rawValue)
        // Sabit: arah menentukan nama, dan tanpanya nama netral.
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.20,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseWaxingCrescent.rawValue)
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.20,
                                                      isWaxing: false).rawValue,
                       LocalizedText.moonPhaseWaningCrescent.rawValue)
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.20,
                                                      isWaxing: nil).rawValue,
                       LocalizedText.moonPhaseCrescent.rawValue)
        // Separuh.
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.50,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseFirstQuarter.rawValue)
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.50,
                                                      isWaxing: false).rawValue,
                       LocalizedText.moonPhaseLastQuarter.rawValue)
        // Cembung.
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.80,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseWaxingGibbous.rawValue)
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.80,
                                                      isWaxing: false).rawValue,
                       LocalizedText.moonPhaseWaningGibbous.rawValue)
    }

    /// Batasnya tepat, bukan "kira-kira": fraksi persis di ambang masuk
    /// golongan yang benar.
    ///
    /// Diuji karena ambang adalah satu-satunya tempat pemilihan fase bisa
    /// salah tanpa ada yang melihatnya: sabit tipis yang disebut "separuh"
    /// tetap terdengar masuk akal, dan tidak ada teks di layar yang bisa
    /// dipakai pengguna untuk membantahnya.
    ///
    /// Pita "separuh" **tertutup di kedua ujungnya** — 0.46 dan 0.54
    /// keduanya separuh — jadi ambangnya diuji dari kedua sisi, bukan hanya
    /// pada nilainya. Versi pertama uji ini menegaskan 0.54 = cembung dan
    /// 0.96 = purnama, dan keduanya gagal: itu memang bukan perilaku yang
    /// ditulis. Batas yang tidak diuji dari dua sisi adalah batas yang
    /// kebetulan.
    func testMoonPhaseThresholdsAreExact() {
        // 0.04 sudah bukan bulan baru lagi.
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.04,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseWaxingCrescent.rawValue)
        // 0.46 sudah bukan sabit lagi, dan masih separuh.
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.46,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseFirstQuarter.rawValue)
        // 0.539 masih separuh; 0.541 sudah cembung. Pita separuh = [0.46, 0.54].
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.539,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseFirstQuarter.rawValue)
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.541,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseWaxingGibbous.rawValue)
        // 0.96 masih cembung; di atasnya baru purnama.
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.96,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseWaxingGibbous.rawValue)
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 0.961,
                                                      isWaxing: true).rawValue,
                       LocalizedText.moonPhaseFull.rawValue)
    }

    /// Di luar rentang 0…1 tidak menghasilkan fase yang salah.
    func testMoonPhaseClampsOutOfRangeFractions() {
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: -0.5,
                                                      isWaxing: nil).rawValue,
                       LocalizedText.moonPhaseNew.rawValue)
        XCTAssertEqual(CelestialVisual.moonPhaseText(illuminationFraction: 1.7,
                                                      isWaxing: nil).rawValue,
                       LocalizedText.moonPhaseFull.rawValue)
    }

    /// Hanya Bulan yang punya fase untuk diucapkan.
    ///
    /// Planet dan bintang tidak menampilkan fase di layar, jadi mengucapkan
    /// fase untuk mereka akan memberi pengguna VoiceOver informasi yang
    /// **tidak** dimiliki pengguna yang melihat — kebalikan dari aksesibilitas.
    func testOnlyTheMoonSpeaksAPhase() {
        XCTAssertNil(CelestialVisual(object: object(id: "jupiter", kind: .planet))
            .spokenPhase)
        XCTAssertNil(CelestialVisual(object: object(id: "sirius", kind: .star))
            .spokenPhase)
        XCTAssertNil(CelestialVisual(object: object(id: "m42", kind: .deepSky))
            .spokenPhase)
        // Bulan tanpa fraksi iluminasi: tidak ada fase yang bisa diklaim.
        XCTAssertNil(CelestialVisual(object: object(id: "moon", kind: .moon))
            .spokenPhase)
        // Bulan dengan fraksi: ada.
        XCTAssertNotNil(moon(fraction: 0.5, waxing: true).spokenPhase)
    }

    /// Fase yang tidak diketahui tidak pernah menjadi tebakan yang pasti.
    ///
    /// Kalau arah waxing tidak diketahui, sabitnya **tidak** disebut "muda"
    /// maupun "tua" — dua nama itu mengklaim arah. Yang diucapkan adalah
    /// bentuk netralnya.
    func testUnknownDirectionNeverClaimsWaxingOrWaning() {
        let crescent = moon(fraction: 0.2, waxing: nil)
        XCTAssertEqual(crescent.spokenPhase, LocalizedText.moonPhaseCrescent.indonesian)
        XCTAssertNotEqual(crescent.spokenPhase, LocalizedText.moonPhaseWaxingCrescent.indonesian)
        XCTAssertNotEqual(crescent.spokenPhase, LocalizedText.moonPhaseWaningCrescent.indonesian)
        let gibbous = moon(fraction: 0.8, waxing: nil)
        XCTAssertEqual(gibbous.spokenPhase, LocalizedText.moonPhaseGibbous.indonesian)
        let quarter = moon(fraction: 0.5, waxing: nil)
        XCTAssertEqual(quarter.spokenPhase, LocalizedText.moonPhaseQuarter.indonesian)
    }

    // MARK: - Warna spektral bintang (VoiceOver)

    /// Pemetaan indeks B−V ke pita warna mengikuti kelas spektral nyata.
    ///
    /// Diuji lewat `starColorText` (murni) dan bukan `spokenStarColor`, karena
    /// `spokenStarColor` memanggil `TextLocalization`, yang di Linux selalu
    /// mengembalikan Bahasa Indonesia — maka uji langsung hanya menguji nilai
    /// bawaan. Yang benar-benar penting adalah **pemilihan** pita: batasnya
    /// tidak meleset, dan bintang di katalog jatuh ke pita yang benar.
    func testStarColorFollowsSpectralBands() {
        // Biru: kelas B ke awal A.
        XCTAssertEqual(CelestialVisual.starColorText(-0.30), .starColorBlue)
        XCTAssertEqual(CelestialVisual.starColorText(-0.10), .starColorBlue)
        // Putih kebiruan: kelas A ke awal F (Sirius, B−V 0,00).
        XCTAssertEqual(CelestialVisual.starColorText(-0.09), .starColorWhiteBlue)
        XCTAssertEqual(CelestialVisual.starColorText(0.00), .starColorWhiteBlue)
        XCTAssertEqual(CelestialVisual.starColorText(0.25), .starColorWhiteBlue)
        // Kuning: kelas F ke awal K (Polaris, B−V 0,60).
        XCTAssertEqual(CelestialVisual.starColorText(0.26), .starColorYellow)
        XCTAssertEqual(CelestialVisual.starColorText(0.95), .starColorYellow)
        // Jingga: kelas K (Arcturus, B−V 1,23).
        XCTAssertEqual(CelestialVisual.starColorText(0.96), .starColorOrange)
        XCTAssertEqual(CelestialVisual.starColorText(1.50), .starColorOrange)
        // Merah: kelas M (Betelgeuse, B−V 1,85).
        XCTAssertEqual(CelestialVisual.starColorText(1.51), .starColorRed)
        XCTAssertEqual(CelestialVisual.starColorText(2.00), .starColorRed)
    }

    /// Batas antar-pita eksak, supaya pembulatan tidak menyisipkan pita ekstra.
    func testStarColorBandBoundariesAreExact() {
        // −0,10 adalah batas biru↔putih-biru: di kiri biru, di kanan putih-biru.
        XCTAssertEqual(CelestialVisual.starColorText(-0.10), .starColorBlue)
        XCTAssertEqual(CelestialVisual.starColorText(-0.099), .starColorWhiteBlue)
        // 0,25 batas putih-biru↔kuning.
        XCTAssertEqual(CelestialVisual.starColorText(0.25), .starColorWhiteBlue)
        XCTAssertEqual(CelestialVisual.starColorText(0.251), .starColorYellow)
        // 0,95 batas kuning↔jingga.
        XCTAssertEqual(CelestialVisual.starColorText(0.95), .starColorYellow)
        XCTAssertEqual(CelestialVisual.starColorText(0.951), .starColorOrange)
        // 1,50 batas jingga↔merah.
        XCTAssertEqual(CelestialVisual.starColorText(1.50), .starColorOrange)
        XCTAssertEqual(CelestialVisual.starColorText(1.501), .starColorRed)
    }

    /// Setiap bintang di katalog jatuh ke pita yang konsisten dengan warna
    /// yang digambar UI-nya.
    ///
    /// UI mewarnai titik dari `colorIndex(forStarID:)`, yang nilainya bersumber
    /// dari tabel B−V yang sama — jadi ucapan tidak boleh berlawanan dengan
    /// gambar. Rigel (biru) dan Betelgeuse (merah) adalah ujung yang paling
    /// mudah salah: keduanya "bintang", dan tanpa warna yang diucapkan keduanya
    /// terdengar sama padahal di layar warnanya bertolak belakang.
    func testCatalogStarsGetConsistentSpokenColor() {
        let rigel = CelestialVisual(object: object(id: "rigel", kind: .star,
                                                   magnitude: 0.1))
        // Rigel B−V −0,03 → still in the white-blue band (biru murni hanya
        // kelas B paling awal, B−V ≤ −0,10). Ucapan sesuai warna yang digambar.
        XCTAssertEqual(rigel.spokenStarColor(isConfirmed: true), LocalizedText.starColorWhiteBlue.indonesian)
        let sirius = CelestialVisual(object: object(id: "sirius", kind: .star,
                                                    magnitude: -1.5))
        XCTAssertEqual(sirius.spokenStarColor(isConfirmed: true), LocalizedText.starColorWhiteBlue.indonesian)
        let betelgeuse = CelestialVisual(object: object(id: "betelgeuse", kind: .star,
                                                       magnitude: 0.5))
        XCTAssertEqual(betelgeuse.spokenStarColor(isConfirmed: true), LocalizedText.starColorRed.indonesian)
    }

    /// Hanya bintang yang diucapkan warnanya. Planet, Bulan, Matahari, dan
    /// objek langit dalam punya warna di gambar, tapi itu sifat render, bukan
    /// klaim spektral — dan tidak boleh diucapkan sebagai warna spektral
    /// bintang.
    func testOnlyStarsSpeakASpectralColor() {
        XCTAssertNil(CelestialVisual(object: object(id: "jupiter", kind: .planet))
            .spokenStarColor(isConfirmed: true))
        XCTAssertNil(CelestialVisual(object: object(id: "moon", kind: .moon))
            .spokenStarColor(isConfirmed: true))
        XCTAssertNil(CelestialVisual(object: object(id: "sun", kind: .sun))
            .spokenStarColor(isConfirmed: true))
        XCTAssertNil(CelestialVisual(object: object(id: "m42", kind: .deepSky))
            .spokenStarColor(isConfirmed: true))
        XCTAssertNotNil(CelestialVisual(object: object(id: "sirius", kind: .star))
            .spokenStarColor(isConfirmed: true))
    }

    // MARK: - Warna bintang adalah ciri pengenal

    /// Warna spektral bintang tidak boleh tampil saat engine belum pasti.
    ///
    /// **Kenapa ini kelas yang sama dengan cincin Saturnus.** Biru pada Rigel
    /// dan merah pada Betelgeuse adalah penanda yang sama meyakinkannya
    /// dengan cincin Saturnus atau bentuk galaksi berpalung — dan aturan itu
    /// sudah berlaku untuk keduanya. Bintang sempat tertinggal: pita planet
    /// dijaga `palette.feature`, bentuk objek langit dalam dijaga
    /// `drawableMorphology`, sementara warna bintang **tidak dijaga apa pun**.
    ///
    /// Yang membuatnya layak diuji, bukan sekadar diperbaiki: kesalahannya
    /// tidak terlihat. Badge di sebelah gambar bisa bertuliskan "Ragu"
    /// sementara titik di sebelahnya berwarna merah khas Betelgeuse, dan
    /// mata membaca gambar lebih dulu daripada badge. Tidak ada teks di layar
    /// yang bisa membuktikan titik merah itu tidak diklaim.
    func testStarColourIsNotAClaimWhenUncertain() {
        let betelgeuse = CelestialVisual.colorIndex(forStarID: "betelgeuse")
        let rigel = CelestialVisual.colorIndex(forStarID: "rigel")
        XCTAssertGreaterThan(betelgeuse, rigel, "prasyarat: keduanya warna berbeda")

        // Saat yakin: warnanya diteruskan apa adanya.
        XCTAssertEqual(
            CelestialVisual.drawableStarColorIndex(betelgeuse, isConfirmed: true),
            betelgeuse)
        XCTAssertEqual(
            CelestialVisual.drawableStarColorIndex(rigel, isConfirmed: true),
            rigel)

        // Saat ragu: **satu** warna untuk semua bintang, dan warna itu harus
        // netral — bukan warna salah satu kandidatnya.
        let uncertainBetelgeuse =
            CelestialVisual.drawableStarColorIndex(betelgeuse, isConfirmed: false)
        let uncertainRigel =
            CelestialVisual.drawableStarColorIndex(rigel, isConfirmed: false)
        XCTAssertEqual(uncertainBetelgeuse, uncertainRigel,
                       "dua bintang berbeda tidak boleh tetap berbeda saat ragu")
        XCTAssertNotEqual(uncertainBetelgeuse, betelgeuse,
                          "warna Betelgeuse tidak boleh tetap tampil saat ragu")
        XCTAssertNotEqual(uncertainRigel, rigel,
                          "warna Rigel tidak boleh tetap tampil saat ragu")
    }

    /// Nilai "tidak mengklaim" harus sama dengan yang sudah dipakai untuk
    /// bintang yang **tidak ada di katalog**.
    ///
    /// Bukan detail gaya: kalau warna ragu adalah nilai karangan baru, ia
    /// masih bisa berupa warna spektral yang khas. Memakai nilai yang sudah
    /// ada berarti "warna ragu" dan "warna bintang tak dikenal" adalah warna
    /// yang sama persis — dan bintang tak dikenal sudah lama dianggap tidak
    /// mengklaim apa pun.
    func testUncertainStarColourMatchesTheUnknownStarColour() {
        let unknown = CelestialVisual.colorIndex(forStarID: "bintang-yang-tidak-ada")
        XCTAssertEqual(
            CelestialVisual.drawableStarColorIndex(1.85, isConfirmed: false),
            unknown,
            "warna saat ragu harus sama dengan warna bintang tak dikenal")
    }

    /// Pengumuman warna bintang juga tidak boleh mengklaim saat engine ragu.
    ///
    /// Gambar sudah dijaga `drawableStarColorIndex`; suara belum. Padahal
    /// keduanya menggambarkan hal yang sama, dan `spokenDeepSkyMorphology`
    /// tepat di sebelahnya sudah menerima `isConfirmed` untuk alasan yang
    /// sama persis. Tanpa ini, pengguna VoiceOver mendengar "merah" di
    /// sebelah badge "Ragu" yang di layar justru tidak berwarna merah —
    /// pengumuman dan gambar jadi tidak lagi cocok.
    func testSpokenStarColourIsSilentWhenUncertain() {
        let betelgeuse = CelestialVisual(object: object(id: "betelgeuse", kind: .star,
                                                       magnitude: 0.5))
        XCTAssertEqual(betelgeuse.spokenStarColor(isConfirmed: true),
                       LocalizedText.starColorRed.indonesian)
        XCTAssertNil(betelgeuse.spokenStarColor(isConfirmed: false),
                     "warna tidak boleh diucapkan saat engine ragu")

        // Bukan-bintang tetap `nil` di kedua keadaan.
        let jupiter = CelestialVisual(object: object(id: "jupiter", kind: .planet))
        XCTAssertNil(jupiter.spokenStarColor(isConfirmed: true))
        XCTAssertNil(jupiter.spokenStarColor(isConfirmed: false))
    }
    // MARK: - Geometri pita Jupiter

    /// Pita Jupiter harus **berhenti tepat di tepi bola**, bukan di dalamnya.
    ///
    /// **Cacat yang ditutup uji ini.** View memakai
    /// `cos((t - 0.5) * .pi * 0.92)` sebagai separuh lebar pita, dan
    /// komentarnya sendiri menjanjikan bentuk yang lain: "pita mengikuti
    /// keliling bola: makin dekat kutub, makin pendek". Bola yang
    /// diproyeksikan berjari-jari `sqrt(1 - y^2)`; kosinus itu bukan
    /// aproksimasi yang baik untuknya. Diukur di kartu jam (radius 19 pt):
    ///
    ///     pita teratas (y = -0.857R)  tepi 0.326R, bola 0.515R  ->  3.6 pt pendek
    ///
    /// Yaitu **19% radius** — pita terluar berhenti jauh di dalam piringan,
    /// dan yang terlihat adalah bola berwarna polos di kedua kutub dengan
    /// pita mengambang di tengahnya. Tidak ada teks di layar yang bisa
    /// membuktikannya, dan "bola dengan pita" tetap terbaca sebagai Jupiter.
    ///
    /// Uji ini mengunci **satu** invarian yang tidak bisa dibaca dari kode:
    /// pita harus menyentuh tepi bola. Ambangnya longgar (tepi pita tidak
    /// boleh lebih dari 0.01R di dalam tepi bola) karena yang salah bukan
    /// pembulatan, melainkan bentuk yang berbeda.
    func testJupiterBandsReachTheLimb() {
        let geometry = CelestialVisual.jupiterBands()
        XCTAssertEqual(geometry.count, 7, "tujuh pita: lihat `bandCount` di view")
        for band in geometry {
            let y = band.centerY
            let sphere = (1 - y * y).squareRoot()
            // Tepi pita = separuh lebar; bola pada ketinggian itu = `sphere`.
            XCTAssertLessThanOrEqual(
                band.halfWidth - sphere, 0.01,
                "pita di y=\(y) berhenti \(sphere - band.halfWidth) R di dalam bola")
            XCTAssertGreaterThan(band.halfWidth, 0.05,
                                 "pita di y=\(y) tidak boleh menghilang")
        }
    }

    /// Pita harus **simetris** terhadap ekuator.
    ///
    /// Bukan kerapian: Jupiter yang pitanya lebih banyak di satu belahan
    /// terbaca sebagai planet yang berbeda, dan ketidak-simetrisan adalah
    /// bentuk cacat yang sudah pernah nyata di berkas ini (kutub Mars).
    func testJupiterBandsAreSymmetricAboutTheEquator() {
        let geometry = CelestialVisual.jupiterBands()
        for (upper, lower) in zip(geometry, geometry.reversed()) {
            XCTAssertEqual(upper.centerY, -lower.centerY, accuracy: 1e-12)
            XCTAssertEqual(upper.halfWidth, lower.halfWidth, accuracy: 1e-12)
        }
    }

    /// Pita teratas harus **lebih pendek** dari pita ekuator.
    ///
    /// Invarian arah: kalau pita teratas lebih lebar, gambarnya adalah bola
    /// dengan pita yang melebar ke kutub — bukan bola. Ini menjaga agar
    /// perbaikan "sampai ke tepi" tidak dilakukan dengan menyamakan semua
    /// pita menjadi satu lebar.
    func testJupiterBandWidthsShrinkTowardsThePoles() {
        let geometry = CelestialVisual.jupiterBands()
        guard let equator = geometry.min(by: { abs($0.centerY) < abs($1.centerY) }) else {
            return XCTFail("tidak ada pita")
        }
        for band in geometry where abs(band.centerY) > abs(equator.centerY) {
            XCTAssertLessThan(band.halfWidth, equator.halfWidth,
                              "pita di y=\(band.centerY) tidak lebih pendek dari ekuator")
        }
    }

    /// Kekuatan pemulihan peredupan limb harus **sebagian**, bukan 0 atau 1.
    ///
    /// **Cacat yang dijaga uji ini — diukur, bukan diperkirakan.** Pita Jupiter
    /// digambar sebagai elips warna **rata** di atas bola yang sudah dinaungi.
    /// Karena tiap pita menutupi 55% piksel di bawahnya, ia menghapus lengkung
    /// bola di situ: pada baris ekuator render 200 px, selisih terang
    /// pusat-ke-limb turun dari **50.6%** (bola polos) ke **20.8%** (bola
    /// ber-pita), dan di 0.96 R pitanya justru **+62.6** lebih terang daripada
    /// bola tanpa pita. Yang terlihat karena itu bukan bola berpita melainkan
    /// **stiker rata** yang ditempel di piringan.
    ///
    /// Kenapa batasnya bukan 0 dan bukan 1:
    ///
    ///   - **0** berarti tidak ada pemulihan — cacat di atas kembali utuh.
    ///   - **1** berarti gradien bola menutup pitanya sepenuhnya, dan pita
    ///     Jupiter hilang sama sekali. Diukur: kontras pita jatuh dari 24.7%
    ///     (tanpa pemulihan) ke 17.0%, dan pita berhenti terbaca.
    ///
    /// Nilai 0.6 memulihkan 75% lengkung sambil menyisakan 18.3% kontras pita —
    /// jadi **kedua** sisi diuji di sini, karena memperbaiki salah satu saja
    /// bisa merusak yang lain tanpa satu pun galat kompilasi.
    func testBandLimbShadingIsPartial() {
        let strength = CelestialVisual.bandLimbShadingStrength
        XCTAssertGreaterThan(strength, 0,
                             "tanpa pemulihan, pita menghapus lengkung bola (cacat 20.8% vs 50.6%)")
        XCTAssertLessThan(strength, 1,
                          "pemulihan penuh menutup pitanya sendiri (kontras pita 17.0% vs 24.7%)")
        XCTAssertEqual(strength, 0.6, accuracy: 1e-12,
                       "nilai ini diukur terhadap render: 75% lengkung, 18.3% kontras pita")
    }

    /// Gradien yang memulihkan lengkung harus **gradien yang sama** dengan bola.
    ///
    /// **Kenapa ini diuji, padahal ia "cuma angka yang sama".** Pemulihan di
    /// `drawBands` memanggil `drawSphere` yang sama, dan itu satu-satunya alasan
    /// daerah **di luar** pita tidak berubah: gradien yang ditumpuk di atas
    /// dirinya sendiri adalah identitas. Kalau pemulihan itu kelak diganti
    /// gradien yang dihitung sendiri, lengkung yang dipulihkan tidak akan sama
    /// dengan lengkung yang terhapus — dan selisihnya muncul sebagai pita yang
    /// lebih terang di tempat yang salah, bukan sebagai galat.
    ///
    /// Arah cahayanya juga harus satu sumber: `sphereLightOffset` dibaca oleh
    /// bola, oleh pemulihan, dan oleh bibir terang kawah.
    func testBandShadingReusesTheSphereLightDirection() {
        // Sumber cahaya harus punya arah: nol berarti setiap kawah mendapat
        // bibir terang di arah yang sama secara acak (lihat `craterRelief`).
        let light = CelestialVisual.sphereLightOffset
        XCTAssertGreaterThan(light.x * light.x + light.y * light.y, 0,
                             "arah cahaya nol: gradien bola & kawah jadi tak terdefinisi")
        // Dan ia menunjuk ke kiri-atas dalam koordinat layar (y ke bawah),
        // tempat gradien bola menaruh cahayanya.
        XCTAssertLessThan(light.x, 0, "cahaya harus dari kiri")
        XCTAssertLessThan(light.y, 0, "cahaya harus dari atas (y layar ke bawah)")
    }

    /// Bintik Merah Besar: angkanya **pusat**, dan view harus memperlakukannya
    /// begitu.
    ///
    /// **Cacat yang ditangkap uji ini (nyata, bukan bayangan).** Sampai siklus
    /// ini `CelestialVisual.jupiterSpot()` mengembalikan satu larik empat angka
    /// yang tafsirnya berbeda di dua tempat: port Python membacanya sebagai
    /// **pusat** elips, sementara view Swift menyalinnya langsung ke `CGRect`
    /// sehingga angkanya menjadi **sudut kiri-atas**. Kedua tafsir menggambar
    /// elips dengan ukuran yang sama, jadi tidak ada pemeriksaan bentuk yang
    /// bisa membedakannya — yang berbeda hanya **letaknya**, dan selisihnya
    /// setengah lebar bintik (0.26 R). Gerbang visual pun tidak menangkapnya:
    /// satu-satunya angka yang diperiksa kebetulan bernilai sama di kedua
    /// tafsir.
    ///
    /// Uji ini mengunci dua hal sekaligus: rumus pusat→sudut yang benar, dan
    /// fakta bahwa bintik itu **tidak menjulur keluar piringan** di tafsir
    /// mana pun. Yang kedua penting karena bintik yang keluar bola tergambar
    /// di atas latar, bukan di atas Jupiter — klaim yang salah tentang di mana
    /// ia berada.
    func testJupiterSpotIsCenteredNotCornered() {
        let spot = CelestialVisual.jupiterSpot()

        // Pusat yang dideklarasikan harus benar-benar jadi pusat: titik tengah
        // elips = centerX, bukan centerX + lebar (tafsir sudut).
        let corneredCenterX = spot.centerX + spot.width / 2
        XCTAssertNotEqual(spot.centerX, corneredCenterX, accuracy: 0.1,
                          "dua tafsir ini hanya berbeda kalau lebarnya tidak nol")
        XCTAssertEqual(spot.centerX, -0.10, accuracy: 1e-12)
        XCTAssertEqual(spot.centerY, 0.31, accuracy: 1e-12)
        XCTAssertGreaterThan(spot.centerY, 0,
                             "Bintik Merah Besar ada di belahan SELATAN (y positif = ke bawah)")

        // Rumus yang dipakai view: sudut = pusat − separuh ukuran.
        let rectOriginX = spot.centerX - spot.width / 2
        XCTAssertEqual(rectOriginX, -0.36, accuracy: 1e-12,
                       "sudut kiri-atas = pusat − separuh lebar")

        // Dan yang paling penting: seluruh elips tetap di dalam piringan.
        XCTAssertLessThan(spot.farthestCorner, 1.0,
                          "bintik terjauh \(spot.farthestCorner) R — keluar dari bola")
    }

    /// Pita cincin Saturnus: urut, tidak tumpang tindih, dan celahnya di
    /// tempat yang benar.
    ///
    /// **Kenapa ini diuji, padahal angkanya konstanta.** Cincin digambar dari
    /// larik batas, dan larik yang salah urut atau tumpang tindih tetap
    /// menghasilkan gambar — hanya gambar yang salah, tanpa satu pun galat.
    /// Tiga invarian di bawah adalah yang paling mudah rusak saat seseorang
    /// menyetel ulang angkanya:
    ///
    ///   1. **Urut naik.** Pita yang batasnya terbalik tergambar sebagai
    ///      cincin dengan lubang negatif — yaitu tidak tergambar sama sekali.
    ///   2. **Tidak tumpang tindih.** Pita yang saling menimpa membuat
    ///      opasitasnya bertambah, jadi pita B yang pekat bisa berubah
    ///      menjadi bidang putih rata di bagian yang menimpa.
    ///   3. **Celah Cassini ada di antara pita B dan A**, bukan di tepi luar.
    ///      Cacat lama menaruh celahnya di 0.34 R dari tepi luar, yang
    ///      memotong pita A dan bukan memisahkan B dari A.
    func testSaturnRingBandsAreOrderedAndLeaveACassiniGap() {
        let bands = VisualFrame.saturnRingBands()
        XCTAssertEqual(bands.count, 5, "D, C, B, celah Cassini, A")

        for band in bands {
            XCTAssertLessThan(band.innerRadius, band.outerRadius,
                              "pita terbalik: \(band.innerRadius)…\(band.outerRadius)")
            XCTAssertGreaterThan(band.width, 0, "pita tanpa lebar")
            XCTAssertGreaterThanOrEqual(band.opacity, 0)
            XCTAssertLessThanOrEqual(band.opacity, 1)
        }
        for (inner, outer) in zip(bands, bands.dropFirst()) {
            XCTAssertEqual(inner.outerRadius, outer.innerRadius, accuracy: 1e-12,
                           "pita tumpang tindih atau berlubang")
        }

        // Cincin mulai di tepi bola dan berakhir di tepi frame.
        XCTAssertEqual(bands.first!.innerRadius,
                       VisualFrame.saturnBodyRadius(for: VisualFrame.saturnRing()),
                       accuracy: 1e-12,
                       "tepi dalam cincin harus bertemu tepi bola")
        XCTAssertEqual(bands.last!.outerRadius, VisualFrame.halfExtent, accuracy: 1e-12,
                       "tepi luar cincin harus menyentuh tepi frame")

        // Celah Cassini: pita ke-4 (indeks 3), dan ia yang paling kosong.
        let gap = bands[3]
        XCTAssertEqual(gap.opacity, bands.map(\.opacity).min()!,
                       "celah Cassini harus pita paling kosong")
        XCTAssertLessThan(gap.opacity, 0.10, "celah harus hampir kosong")
        XCTAssertGreaterThan(gap.innerRadius, 0.8,
                             "celah Cassini ada di ≈0.886 R cincin, bukan di tepi luar")
        XCTAssertLessThan(gap.outerRadius, 0.98,
                          "celah Cassini bukan tepi luar cincin")
    }

    /// Cincin harus **punya struktur**, bukan bidang rata.
    ///
    /// Cacat lama menggambar satu elips pekat: tidak ada pita, jadi tidak ada
    /// yang bisa membedakan Saturnus dari piring. Uji ini mengunci bahwa
    /// opasitasnya benar-benar berbeda antar-pita, sehingga "meratakan"
    /// seluruh pita menjadi satu nilai tidak bisa ditulis ulang diam-diam.
    func testSaturnRingBandsHaveDistinctDensities() {
        let bands = VisualFrame.saturnRingBands()
        let opacities = bands.map(\.opacity)
        XCTAssertEqual(Set(opacities).count, opacities.count,
                       "setiap pita punya kepadatan sendiri: \(opacities)")

        // Pita B harus yang paling pekat, dan celah Cassini yang paling tipis
        // — bukan sebaliknya. Urutan itu yang membuat cincin terbaca sebagai
        // cincin Saturnus, bukan sebagai cincin bergaris acak.
        let brightest = bands.max(by: { $0.opacity < $1.opacity })!
        XCTAssertEqual(brightest.innerRadius, bands[2].innerRadius,
                       "pita B (indeks 2) harus yang paling pekat")
    }

    /// Paruh belakang cincin harus **lebih redup**, bukan sama.
    ///
    /// Kalau skalanya 1.0, cincin belakang sama terang dengan depan dan tidak
    /// ada lagi yang menunjukkan mana yang di belakang planet.
    func testRingBackHalfIsDimmerThanTheFront() {
        XCTAssertGreaterThan(VisualFrame.ringBackHalfOpacityScale, 0)
        XCTAssertLessThan(VisualFrame.ringBackHalfOpacityScale, 1,
                          "paruh belakang harus lebih redup dari paruh depan")
    }

    // MARK: - Profil radial Matahari

    /// Kelegapan profil Matahari **tidak boleh naik**.
    ///
    /// Inilah invarian yang membuat piringannya satu benda, bukan dua yang
    /// bertumpuk. Versi lama memakai dua piringan: fotosfer dengan kelegapan
    /// penuh selebar 0.72 R, lalu corona yang dimulai di 0.6 R dengan
    /// kelegapan 0.42 — dan karena piringan kedua digambar **di atas** yang
    /// pertama, kelegapan yang benar-benar sampai ke mata di tepi fotosfer
    /// **turun** dari 1.0 ke 0.42 dalam satu piksel.
    ///
    /// Diukur pada render 110 px: 175 dari 255 langkah antar-piksel
    /// bersebelahan, jauh di atas ambang persepsi. Yang terlihat bukan tepi
    /// Matahari melainkan dua benda bertumpuk.
    ///
    /// Uji ini mengunci **kedua** hal yang membuatnya hilang: opasitas yang
    /// monoton turun, dan piringan yang membentang sampai 1.0 R (kalau ia
    /// berhenti di 0.72 R, batas fotosfernya kembali menjadi tepi keras).
    func testSunProfileOpacityNeverIncreases() {
        let profile = VisualFrame.sunProfile(core: CelestialVisual.accents.sunCore,
                                             photosphere: CelestialVisual.accents.sunPhotosphere)
        XCTAssertGreaterThan(profile.count, 2, "satu gradient butuh lebih dari dua stop")

        for (previous, next) in zip(profile, profile.dropFirst()) {
            XCTAssertLessThan(previous.radiusFraction, next.radiusFraction,
                              "stop harus maju ke luar, bukan mundur: "
                              + "\(previous.radiusFraction) lalu \(next.radiusFraction)")
            XCTAssertLessThanOrEqual(next.opacity, previous.opacity,
                                     "kelegapan naik di \(next.radiusFraction) R: "
                                     + "\(previous.opacity) -> \(next.opacity). "
                                     + "Kenaikan itulah yang menggambar ulang tepi keras.")
        }
        XCTAssertEqual(profile.first?.opacity, 1.0, "inti harus sepenuhnya pekat")
        XCTAssertEqual(profile.last?.opacity, 0.0, "tepi harus benar-benar habis")
        XCTAssertEqual(profile.last?.radiusFraction, 1.0,
                       "piringan harus membentang sampai tepi frame")
    }

    /// Batas fotosfer **tidak boleh** menjadi lompatan kelegapan.
    ///
    /// 0.72 R adalah tempat yang dulu berakhir di tepi keras: piringan
    /// fotosfer habis di sana sementara corona yang lebih redup sudah mulai di
    /// 0.6 R. Karena itu uji ini menuntut penurunan antar-stop di sekitar
    /// batas itu tetap **landai** — bukan sekadar "turun", karena penurunan
    /// 1.0 -> 0.42 juga turun.
    ///
    /// Ambangnya 0.2: langkah terbesar yang tersisa di profil sekarang 0.48
    /// pada rentang 0.72 -> 0.80 R (0.8 lebar), yaitu 0.6 per satuan radius.
    /// Angka ini menjaga agar penurunan bertahap, bukan supaya pas.
    func testSunProfileHasNoCliffAtThePhotosphereBoundary() {
        let profile = VisualFrame.sunProfile(core: CelestialVisual.accents.sunCore,
                                             photosphere: CelestialVisual.accents.sunPhotosphere)
        let boundary = 0.72
        guard let index = profile.firstIndex(where: { $0.radiusFraction == boundary }) else {
            return XCTFail("batas fotosfer \(boundary) R harus jadi salah satu stop: "
                           + "\(profile.map(\.radiusFraction)). Kalau tidak, ia "
                           + "dilewati interpolasi dan lompatannya tidak terkendali.")
        }
        XCTAssertGreaterThan(index, 0, "harus ada stop sebelum batas")
        let before = profile[index - 1]
        let at = profile[index]
        XCTAssertLessThanOrEqual(before.opacity - at.opacity, 0.2,
                                 "lompatan \(before.opacity) -> \(at.opacity) di "
                                 + "\(boundary) R terlalu tajam; itu tepi keras yang lama")
    }

    /// Warna tepi harus **berbeda** dari warna inti.
    ///
    /// Tanpa ini, "satu gradient" bisa dipenuhi dengan satu warna rata dari
    /// pusat ke tepi — piringan yang terlihat seperti cakram datar, bukan
    /// fotosfer yang memudar. Versi lama juga punya pembedaan ini
    /// (`sunCore` -> `sunPhotosphere`), jadi yang dijaga di sini adalah bahwa
    /// perbaikan bentuk tidak menghapusnya.
    func testSunProfileEdgeIsWarmerThanTheCore() {
        let profile = VisualFrame.sunProfile(core: CelestialVisual.accents.sunCore,
                                             photosphere: CelestialVisual.accents.sunPhotosphere)
        let core = profile.first!.color
        let edge = profile.last!.color
        XCTAssertNotEqual(core, edge, "inti dan tepi harus warna yang berbeda")
        XCTAssertGreaterThan(core.blue, edge.blue,
                             "inti lebih pucat (biru lebih tinggi) daripada tepi")
    }

    // MARK: - Regresi: `CraterRelief` harus tetap bisa di-compare

    /// `CraterRelief` menyatakan model bibir kawah yang diuji di Linux. Ia
    /// **harus** `Equatable` — kalau tidak, modul `PointingKit` gagal
    /// dikompilasi (fatalError di emit-module), dan tidak ada satu pun uji
    /// yang bisa berjalan.
    ///
    /// Cacat yang ditutup: field arah bibir pernah ditulis sebagai tupel
    /// berlabel `(x: Double, y: Double)` sebagai *stored property*. Di Swift 6
    /// tupel berlabel tidak menyintesis `Equatable`, sehingga `public struct
    /// CraterRelief: Equatable` langsung menolak compile. Diperbaiki dengan
    /// memecahnya jadi dua `Double` (`rimDirectionX`/`rimDirectionY`) — alat
    /// Python membandingkan komponen secara langsung, jadi bentuk Swift murni
    /// internal. Uji ini menahan bentuk itu: kalau suatu saat ada yang kembali
    /// menulis tupel berlabel di sini (atau menurunkan visibilitas field
    /// hingga tidak bisa dibanding), compile akan merah — bukan diam.
    func testCraterReliefRemainsEquatableWithPlainDoubleFields() {
        let a = CelestialVisual.CraterRelief(centerX: -0.30, centerY: -0.22, radius: 0.20,
                                             rimDirectionX: -0.7071, rimDirectionY: -0.7071,
                                             rimStrength: 0.55, floorDepth: 0.22)
        let b = CelestialVisual.CraterRelief(centerX: -0.30, centerY: -0.22, radius: 0.20,
                                             rimDirectionX: -0.7071, rimDirectionY: -0.7071,
                                             rimStrength: 0.55, floorDepth: 0.22)
        let c = CelestialVisual.CraterRelief(centerX: 0.28, centerY: -0.05, radius: 0.15,
                                             rimDirectionX: 0.0, rimDirectionY: 1.0,
                                             rimStrength: 0.30, floorDepth: 0.11)
        XCTAssertEqual(a, b, "dua relief identik harus setara")
        XCTAssertNotEqual(a, c, "relief berbeda harus tidak setara")
    }

    /// Bibir yang lebih terang **selalu** menghadap sumber cahaya, dan arahnya
    /// diturunkan dari `sphereLightOffset` yang sama dengan gradien bola.
    ///
    /// Cacat yang ditutup: arahnya pernah ditulis dua kali — sekali sebagai
    /// pusat gradien di view, sekali di port Python — dan keduanya harus sama
    /// supaya bibir kawah yang terang menghadap sisi yang benar. Sekarang satu
    /// konstanta di model. Uji ini mengunci bahwa `craterRelief` memang
    /// memproduksi arah `-light` yang dinormalkan untuk **setiap** kawah, dan
    /// bahwa `sphereLightOffset` memiliki panjang yang tidak nol (kalau nol,
    /// arah tidak terdefinisi dan `craterRelief` harus mengembalikan kosong,
    /// bukan bibir acak).
    func testCraterReliefRimAlwaysFacesTheLight() {
        let craters = [(0.0, 0.0, 0.20), (-0.30, -0.22, 0.20), (0.28, 0.34, 0.11)]
        let relief = CelestialVisual.craterRelief(craters: craters)
        XCTAssertEqual(relief.count, craters.count, "satu relief per kawah")

        let light = CelestialVisual.sphereLightOffset
        let length = (light.x * light.x + light.y * light.y).squareRoot()
        XCTAssertGreaterThan(length, 1e-9, "arah cahaya bola tidak boleh nol panjangnya")
        let wantX = -light.x / length
        let wantY = -light.y / length

        for r in relief {
            XCTAssertEqual(r.rimDirectionX, wantX, accuracy: 1e-9,
                           "bibir kawah harus menghadap sumber cahaya (x)")
            XCTAssertEqual(r.rimDirectionY, wantY, accuracy: 1e-9,
                           "bibir kawah harus menghadap sumber cahaya (y)")
            XCTAssertGreaterThan(r.rimStrength, 0,
                                 "kekuatan bibir harus positif (pernah 0 = kawah hilang)")
        }
    }

    /// Cahaya nol panjangnya tidak boleh menghasilkan bibir yang arahnya
    /// sembarang. `craterRelief` harus mengembalikan kosong, bukan relief
    /// dengan arah yang tidak terdefinisi — itu yang membuat kawah tampak
    /// menonjol keluar alih-alih cekung saat vektor cahaya rusak.
    func testCraterReliefRefusesZeroLengthLight() {
        let relief = CelestialVisual.craterRelief(craters: [(0.0, 0.0, 0.20)],
                                                 lightDirection: (x: 0, y: 0))
        XCTAssertTrue(relief.isEmpty, "cahaya nol panjangnya tidak boleh menghasilkan bibir")
    }

    /// Kontras kawah di sisi gelap tidak boleh hilang, dan **perbandingannya**
    /// dengan sisi terang adalah pernyataan, bukan hiasan.
    ///
    /// `craterRelief` meredupkan bibir kawah yang membelakangi cahaya lewat
    /// `fade = 0.6 + 0.4 · alignment` — kekuatan penuh di sisi terang, 20% di
    /// sisi tergelap. Sampai siklus ini angka itu **hanya hidup sebagai
    /// komentar**: `testCraterReliefRimAlwaysFacesTheLight` hanya menuntut
    /// `rimStrength > 0`, jadi `0.6 + 0.4` bisa diganti apa saja selama
    /// hasilnya masih positif, dan tidak ada uji yang berbunyi.
    ///
    /// Buktinya diukur, bukan dikira: mengganti `0.6 + 0.4` menjadi
    /// `0.7 + 0.3` — tetap positif di semua kawah — membuat **seluruh** 124
    /// uji `CelestialVisualTests` tetap hijau. Yang menangkap versi
    /// `0.2 + 0.8` hanyalah akibat samping: kekuatannya jadi **negatif**, dan
    /// itu ditangkap pemeriksaan tanda, bukan pemeriksaan rumus. Jadi kelas
    /// cacat ini adalah kelas yang sama dengan urutan kecerahan palet dan fase
    /// Bulan: **niat yang hanya tertulis sebagai prosa adalah niat yang hilang
    /// saat angkanya disunting.**
    ///
    /// Yang diukur di sini bukan angkanya, melainkan artinya. Kawah di tepi
    /// piringan yang tepat menghadap cahaya harus **5×** lebih kuat daripada
    /// kawah yang tepat membelakanginya (1,0 lawan 0,2), dan tidak satu pun
    /// boleh nol. Angka 5 itu tidak ditulis sebagai konstanta bebas — ia
    /// lahir dari kedua ujungnya, jadi uji ini berbunyi kalau perbandingannya
    /// bergeser, dan tetap diam kalau kedua ujungnya ditulis ulang bersama.
    func testCraterShadingKeepsDarkSideCratersVisible() {
        let light = CelestialVisual.sphereLightOffset
        let length = (light.x * light.x + light.y * light.y).squareRoot()
        let ux = light.x / length, uy = light.y / length

        // Dua kawah di tepi piringan, satu tepat sejajar arah cahaya dan satu
        // tepat berlawanan. `distance` keduanya 1,0, jadi `limb` ikut sama dan
        // satu-satunya yang berbeda adalah `fade` — inilah yang membuat
        // perbandingan di bawah mengukur peredupan sisi gelap, bukan geometri.
        let facing = CelestialVisual.craterRelief(craters: [(ux, uy, 0.20)])
        let away = CelestialVisual.craterRelief(craters: [(-ux, -uy, 0.20)])
        XCTAssertEqual(facing.count, 1)
        XCTAssertEqual(away.count, 1)

        XCTAssertGreaterThan(away[0].rimStrength, 0,
                             "kawah di sisi tergelap tidak boleh hilang sama sekali")
        XCTAssertGreaterThan(facing[0].rimStrength, away[0].rimStrength,
                             "kawah yang menghadap cahaya harus lebih kuat")
        let ratio = facing[0].rimStrength / away[0].rimStrength
        XCTAssertEqual(ratio, 5.0, accuracy: 1e-6,
                       "sisi terang penuh (1,0) dan sisi tergelap 20% (0,2) — "
                       + "rasio 5, bukan angka bebas")

        // Dan arah peredupannya monoton: makin membelakangi cahaya, makin
        // redup. Tanpa ini, `fade` yang bukan fungsi naik dari `alignment`
        // (mis. memakai `abs`) bisa lolos dari kedua ujung di atas.
        //
        // **Jarak kawah harus dijaga tetap.** Versi pertama uji ini
        // memindahkan kawah ke `step · u` — jadi `distance` ikut turun
        // bersama `alignment`, dan `limb` (yang di tepi piringan bernilai
        // 0,4) tumbuh lebih cepat daripada `fade` yang mengecil. Akibatnya
        // kekuatannya **naik** saat `alignment` turun, pada kode yang benar
        // sekalipun: uji yang merah pada kode benar. Yang diisolasi di sini
        // adalah `fade`, jadi posisi kawah tetap di tepi piringan dan
        // **arah cahaya** yang diputar.
        let radius = 1.0
        let crater = (radius * ux, radius * uy, 0.20)
        var previous = Double.infinity
        for step in stride(from: 0.0, through: Double.pi, by: Double.pi / 8) {
            // Sudut `step` dari arah kawah: `alignment = cos(step)`, dan
            // `distance` selalu 1,0 sehingga `limb` sama di semua langkah.
            let light = (x: radius * cos(step) * ux - radius * sin(step) * uy,
                         y: radius * sin(step) * ux + radius * cos(step) * uy)
            let relief = CelestialVisual.craterRelief(craters: [crater],
                                                      lightDirection: light)
            XCTAssertLessThan(relief[0].rimStrength, previous,
                              "kekuatan bibir harus turun monoton pada sudut \(step)")
            XCTAssertGreaterThan(relief[0].rimStrength, 0,
                                 "tidak ada kawah yang boleh hilang (sudut \(step))")
            previous = relief[0].rimStrength
        }
    }

}

