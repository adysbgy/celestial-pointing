import XCTest
import CelestialEngine
@testable import PointingKit

/// Efemeris palsu: satu-satunya cara menguji **jembatan** dari resolver ke
/// fungsi geometri murni tanpa menuntut AstronomyKit (yang tidak ada di Linux).
///
/// Yang diuji di sini bukan rumusnya — rumus itu sudah dijaga
/// `CelestialVisualTests` lewat `brightLimbAngle`. Yang diuji adalah
/// **penyambungannya**: benda mana yang diambil, apakah pengamatnya diteruskan,
/// dan apakah penjaga "planet ini tidak berfase" benar-benar berbunyi. Ketiga
/// hal itu tidak bisa dilihat dari nilai keluarannya: sabit Venus yang salah
/// sisi tampak sama meyakinkannya dengan yang benar.
private struct StubEphemeris: SolarSystemEphemeris {
    var samples: [EphemerisBody: EphemerisSample] = [:]
    var failing: Set<EphemerisBody> = []

    func apparent(_ body: EphemerisBody,
                  at date: Date,
                  from observer: Observer?) throws -> EphemerisSample {
        if failing.contains(body) {
            throw EphemerisError.computationFailed("stub: \(body.rawValue)")
        }
        guard let sample = samples[body] else {
            throw EphemerisError.unsupportedBody(body.rawValue)
        }
        return sample
    }
}

/// Jembatan resolver → geometri fase: Bulan dan planet dalam.
///
/// **Kelas cacat yang dijaga di sini.** `moonBrightLimbAngle` dan
/// `planetBrightLimbAngle` adalah dua fungsi yang **dipakai layar**
/// (`PointingEngine` meneruskan hasilnya ke `CelestialVisual` sebagai
/// `brightLimbAngleRadians`) tetapi tidak diukur satu uji pun. Sapuan repo
/// melaporkannya `test=0`. Itu berarti seluruh penjagaan arah sabit —
/// termasuk kontrol negatif "waxing saja tidak cukup" — bisa dilewati dengan
/// mengganti benda yang diambil di dalam fungsi ini, dan tidak ada gerbang
/// yang berbunyi: rumus murninya tetap benar, hanya masukannya yang salah.
///
/// Empat sifat yang diukur, semuanya tentang penyambungan:
///   1. Tanpa efemeris (dan saat efemeris gagal) hasilnya `nil` — bukan
///      angka karangan. Ini aturan PRD: uncertainty > false confidence.
///   2. Benda yang **tidak berfase** (`showsPhase == false`) selalu `nil`,
///      sekalipun efemerisnya tersedia dan lengkap. Kalau penjaga ini lepas,
///      Mars digambar bersabit — gambar yang menyatakan sesuatu yang tidak
///      pernah terjadi di langit.
///   3. Fungsi ini mengambil **Bulan/planet**, bukan Matahari, untuk sisi
///      "benda": kalau benda dan Matahari berimpit, arahnya tak terdefinisi
///      dan hasilnya `nil`. Jadi benda yang berbeda posisi **wajib** memberi
///      sudut; kalau tidak, yang diambil adalah benda yang salah.
///   4. Arah membesar/mengecil mengikuti tanda elongasi, dengan ambang yang
///      sama untuk Bulan dan planet dalam.
final class PlanetPhaseOrientationTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    /// Bulan dan Matahari sengaja **berjauhan tapi tidak antipodal**.
    ///
    /// Berjauhan, karena kalau keduanya berimpit `brightLimbAngle`
    /// mengembalikan `nil` dan uji "ada sudutnya" akan lulus untuk alasan yang
    /// salah. Tetapi **tidak antipodal** — dan itu ditemukan dari uji ini
    /// sendiri: pasangan RA 100°/280° dengan deklinasi ±10° ternyata jatuh
    /// **tepat** di titik antisolar di kerangka horizontal pengamat
    /// (`alt/az` Bulan 52.6/295.4, Matahari −52.6/115.4 — persis −M), sehingga
    /// delta-nya terproyeksi ke nol dan sudutnya `nil` juga. Pasangan di bawah
    /// memberi geometri sabit yang wajar: sudut ≈ 68°.
    private let moonSample = EphemerisSample(raDeg: 100, decDeg: 10, magnitude: -12)
    private let sunSample = EphemerisSample(raDeg: 150, decDeg: 5, magnitude: -26.7)

    private func resolver(_ stub: StubEphemeris) -> PointingResolver {
        PointingResolver(catalogue: [], ephemeris: stub)
    }

    /// Resolver dengan benda-benda yang diberikan.
    private func resolver(extra: [EphemerisBody: EphemerisSample]) -> PointingResolver {
        var stub = StubEphemeris()
        stub.samples = extra
        return PointingResolver(catalogue: [], ephemeris: stub)
    }

    // MARK: - Bulan

    /// Tanpa efemeris tidak ada sudut — bukan sudut nol.
    ///
    /// Nol derajat berarti "sisi terang tepat di kanan": sebuah pernyataan
    /// tentang langit. `nil` berarti "tidak tahu", dan UI lalu menggambar fase
    /// tanpa putaran.
    func testMoonLimbAngleIsNilWithoutEphemeris() {
        let bare = PointingResolver(catalogue: [])
        XCTAssertNil(bare.moonBrightLimbAngle(at: date, observer: observer))
    }

    /// Efemeris yang gagal juga `nil`, bukan angka sisa.
    func testMoonLimbAngleIsNilWhenEphemerisFails() {
        var stub = StubEphemeris()
        stub.samples = [.moon: moonSample, .sun: sunSample]
        stub.failing = [.moon]
        XCTAssertNil(resolver(stub).moonBrightLimbAngle(at: date, observer: observer))
    }

    /// Efemeris yang bekerja **wajib** memberi sudut.
    ///
    /// Ini penjaga "benda yang salah": `brightLimbAngle` mengembalikan `nil`
    /// bila benda dan Matahari berimpit. Karena di sini keduanya sengaja
    /// berjauhan, `nil` hanya mungkin bila fungsi ini mengambil Matahari untuk
    /// kedua sisinya — persis mutasi yang tidak bisa ditangkap uji nilai.
    func testMoonLimbAngleIsDefinedWhenMoonAndSunDiffer() {
        let angle = resolver(extra: [.moon: moonSample, .sun: sunSample])
            .moonBrightLimbAngle(at: date, observer: observer)
        XCTAssertNotNil(angle,
                        "Bulan dan Matahari berjauhan: sudut harus terdefinisi — "
                        + "nil di sini berarti fungsi mengambil benda yang salah")
    }

    /// Bulan dan Matahari berimpit: arahnya tak terdefinisi, jadi `nil`.
    func testMoonLimbAngleIsNilWhenMoonAndSunCoincide() {
        let same = EphemerisSample(raDeg: 100, decDeg: 10, magnitude: -12)
        let angle = resolver(extra: [.moon: same, .sun: same])
            .moonBrightLimbAngle(at: date, observer: observer)
        XCTAssertNil(angle, "benda dan Matahari berimpit tidak punya arah sisi terang")
    }

    /// Fraksi iluminasi Bulan dijepit ke 0…1, bukan ditolak.
    ///
    /// Bulan **selalu** punya fraksi: nilai di luar rentang dari efemeris
    /// adalah galat pembulatan pada geometri tepi, dan menjepitnya ke ujung
    /// rentang adalah jawaban yang benar. Menolaknya jadi `nil` akan mematikan
    /// fase Bulan di momen yang justru paling terlihat.
    func testMoonIlluminationFractionIsClampedNotRejected() {
        let over = EphemerisSample(raDeg: 100, decDeg: 10, magnitude: -12,
                                   illuminationFraction: 1.5)
        XCTAssertEqual(resolver(extra: [.moon: over]).moonIlluminationFraction(at: date), 1)
        let under = EphemerisSample(raDeg: 100, decDeg: 10, magnitude: -12,
                                    illuminationFraction: -0.2)
        XCTAssertEqual(resolver(extra: [.moon: under]).moonIlluminationFraction(at: date), 0)
    }

    /// Tanpa efemeris, fraksi Bulan `nil` — bukan nol yang berarti "bulan baru".
    func testMoonIlluminationFractionIsNilWithoutEphemeris() {
        XCTAssertNil(PointingResolver(catalogue: []).moonIlluminationFraction(at: date))
    }

    // MARK: - Planet: penjaga "tidak berfase"

    /// Planet luar **tidak pernah** berfase — sekalipun efemerisnya lengkap.
    ///
    /// Ini penjaga terpenting di berkas ini. `showsPhase` sudah diuji, tetapi
    /// yang menentukan apakah sabit Mars benar-benar digambar adalah apakah
    /// `planetBrightLimbAngle`/`planetIlluminationFraction` **menghormatinya**.
    /// Kalau penjaganya lepas, keduanya mengembalikan angka untuk Mars, dan
    /// `CelestialVisual` akan menggambar sabit pada benda yang dari Bumi
    /// tampak ~85% penuh. Tidak ada teks di layar yang bisa membantahnya.
    func testOuterPlanetsHaveNoPhaseEvenWithEphemeris() {
        let mars = EphemerisSample(raDeg: 120, decDeg: 5, magnitude: -1,
                                   illuminationFraction: 0.85)
        let r = resolver(extra: [.mars: mars, .sun: sunSample])
        XCTAssertNil(r.planetBrightLimbAngle(for: .mars, at: date, observer: observer),
                     "Mars tidak berfase: sudut sisi terangnya harus nil")
        XCTAssertNil(r.planetIlluminationFraction(for: .mars, at: date),
                     "Mars tidak berfase: fraksinya harus nil, bukan 0.85")
    }

    /// Planet dalam berfase: sudutnya terdefinisi saat posisinya beda dari
    /// Matahari (mutasi "benda yang salah" yang sama seperti Bulan).
    func testInnerPlanetPhaseIsDefinedWhenItDiffersFromTheSun() {
        let venus = EphemerisSample(raDeg: 100, decDeg: 10, magnitude: -4,
                                    illuminationFraction: 0.4)
        let r = resolver(extra: [.venus: venus, .sun: sunSample])
        XCTAssertNotNil(r.planetBrightLimbAngle(for: .venus, at: date, observer: observer))
        XCTAssertEqual(r.planetIlluminationFraction(for: .venus, at: date), 0.4)
    }

    /// Fraksi planet di luar 0…1 **ditolak**, bukan dijepit.
    ///
    /// Berbeda dari Bulan dengan sengaja: fraksi planet hanya datang dari
    /// efemeris, dan nilai di luar rentang berarti perhitungannya rusak —
    /// bukan pembulatan di tepi. Menjepitnya diam-diam akan menampilkan Venus
    /// sebagai cakram penuh tepat ketika efemerisnya sedang salah.
    func testPlanetIlluminationFractionRejectsOutOfRange() {
        let broken = EphemerisSample(raDeg: 100, decDeg: 10, magnitude: -4,
                                     illuminationFraction: 1.5)
        let r = resolver(extra: [.venus: broken])
        XCTAssertNil(r.planetIlluminationFraction(for: .venus, at: date),
                     "fraksi 1.5 berarti efemerisnya rusak, bukan cakram penuh")
    }

    /// Planet tanpa sampel efemeris: `nil`, bukan nol.
    func testPlanetPhaseIsNilWhenTheSampleIsMissing() {
        let r = resolver(extra: [.moon: moonSample, .sun: sunSample])
        XCTAssertNil(r.planetIlluminationFraction(for: .venus, at: date))
        XCTAssertNil(r.planetBrightLimbAngle(for: .venus, at: date, observer: observer))
    }

    /// Matahari tidak tersedia → sisi terang tak bisa ditentukan → `nil`.
    ///
    /// Tanpa ini, planet tetap digambar bersabit dengan arah yang dikarang.
    func testPlanetLimbAngleIsNilWithoutTheSun() {
        var stub = StubEphemeris()
        stub.samples = [.venus: EphemerisSample(raDeg: 100, decDeg: 10, magnitude: -4,
                                                illuminationFraction: 0.4)]
        XCTAssertNil(resolver(stub).planetBrightLimbAngle(for: .venus, at: date,
                                                          observer: observer))
    }

    // MARK: - Arah membesar/mengecil

    /// Bulan dan planet dalam memakai **satu** aturan elongasi.
    ///
    /// Elongasi = bujur benda − bujur Matahari. 0°–180° membesar; sisanya
    /// mengecil. Kalau kedua fungsi memakai ambang yang berbeda, sabit Venus
    /// dan sabit Bulan bisa membesar ke arah berlawanan pada malam yang sama.
    func testWaxingDirectionFollowsElongationForBothMoonAndInnerPlanet() {
        let sunAtZero = EphemerisSample(raDeg: 0, decDeg: 0, magnitude: -26.7)
        let moonEast = EphemerisSample(raDeg: 45, decDeg: 0, magnitude: -12)
        let moonWest = EphemerisSample(raDeg: 200, decDeg: 0, magnitude: -12)

        XCTAssertEqual(resolver(extra: [.moon: moonEast, .sun: sunAtZero])
                        .isMoonWaxing(at: date), true,
                       "elongasi 45 derajat (timur Matahari) = membesar")

        XCTAssertEqual(resolver(extra: [.moon: moonWest, .sun: sunAtZero])
                        .isMoonWaxing(at: date), false,
                       "elongasi 200 derajat = mengecil")

        // Planet dalam memakai ambang yang sama.
        let venusEast = EphemerisSample(raDeg: 45, decDeg: 0, magnitude: -4,
                                        illuminationFraction: 0.4)
        XCTAssertEqual(resolver(extra: [.venus: venusEast, .sun: sunAtZero])
                        .isPlanetWaxing(.venus, at: date), true,
                       "Venus di timur Matahari harus membesar, seperti Bulan")
    }

    /// Planet luar tidak punya arah fase — sama seperti tidak punya fase.
    func testOuterPlanetHasNoWaxingDirection() {
        let mars = EphemerisSample(raDeg: 45, decDeg: 0, magnitude: -1)
        XCTAssertNil(resolver(extra: [.mars: mars, .sun: sunSample])
                        .isPlanetWaxing(.mars, at: date))
    }

    /// Elongasi dibungkus ke 0…360 sebelum dibandingkan dengan 180.
    ///
    /// Benda di barat Matahari dengan selisih bujur **negatif** (mis. −350°
    /// berarti +10° setelah dibungkus) harus terbaca **membesar**. Tanpa
    /// pembungkusan, −350 dibandingkan apa adanya dengan 180 dan jawabannya
    /// terbalik — sabit membesar digambar mengecil.
    func testNegativeElongationIsWrappedBeforeTheWaxingTest() {
        let sunAtZero = EphemerisSample(raDeg: 0, decDeg: 0, magnitude: -26.7)
        let moonAt350 = EphemerisSample(raDeg: 350, decDeg: 0, magnitude: -12)

        // 350 − 0 = 350 → tetap 350 → mengecil.
        XCTAssertEqual(resolver(extra: [.moon: moonAt350, .sun: sunAtZero])
                        .isMoonWaxing(at: date), false)

        // 0 − 350 = −350 → dibungkus jadi 10 → membesar.
        XCTAssertEqual(resolver(extra: [.moon: sunAtZero, .sun: moonAt350])
                        .isMoonWaxing(at: date), true,
                       "elongasi negatif harus dibungkus: −350 derajat = +10 derajat")
    }
}
