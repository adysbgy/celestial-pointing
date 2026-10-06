import XCTest
import CelestialEngine
@testable import PointingKit

/// Alasan "mengapa tidak ada objek" — dari `Resolution` ke kalimat yang dibaca
/// pengguna.
///
/// **Kenapa diuji.** `PointingResolver.diagnose` sudah menghitung alasan setiap
/// penolakan sejak awal, tetapi `Resolution.rejected` nol konsumen di seluruh
/// repo: satu-satunya kalimat yang pernah sampai ke layar adalah "Belum ada
/// objek di arah itu.", untuk situasi yang sangat berbeda. Uji di sini menjaga
/// bahwa perbedaan itu benar-benar sampai — dan, yang lebih penting, bahwa
/// **tidak ada** hint saat ada jawaban.
final class SearchHintTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private let sirius = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                         raDeg: 101.28715533, decDeg: -16.71611586,
                                         magnitude: -1.46)

    // MARK: - Helper murni

    /// **Kerucut 5 derajat** untuk seluruh fixture tangan di berkas ini.
    ///
    /// Tanpa kerucut berarti "cakupan tidak diketahui", dan
    /// `searchHint` yang jujur lalu jatuh ke `.noCandidates` — jadi fixture
    /// sekuat ini harus menyatakan kerucut yang dipakainya, seperti
    /// `PointingResolver.diagnose` selalu lakukan. Nilai `5` dipilih karena
    /// fixture di sini memakai jarak pisah `3`; memakai kerucut yang jauh
    /// lebih besar tidak mengubah apa pun, dan memakai yang lebih kecil akan
    /// membuat separator tidak ikut dan menguji hal yang berbeda.
    private let fixtureCone: Double = 5

    private func resolution(context: SkyContext,
                            rejected: [RejectedObject] = []) -> Resolution {
        Resolution(intent: CelestialIntent(level: .low, best: nil, candidates: []),
                   context: context,
                   rejected: rejected,
                   pointingConeDeg: fixtureCone)
    }

    private func rejected(_ visibility: Visibility,
                          id: String = "x") -> RejectedObject {
        RejectedObject(object: CelestialObject(id: id, name: id, kind: .star,
                                               raDeg: 0, decDeg: 0, magnitude: 5),
                       visibility: visibility,
                       separationDeg: 3)
    }

    // MARK: - Aturan inti: hint hanya saat TIDAK ada jawaban

    /// Ada objek -> tidak ada hint. Ini penjaga anti-false-confidence: sebuah
    /// hint adalah penjelasan atas **ketiadaan** jawaban, dan tidak boleh pernah
    /// menemani objek yang justru terkunci.
    func testNoHintWhenThereIsAnAnswer() {
        let withAnswer = Resolution(
            intent: CelestialIntent(level: .high, best: sirius, candidates: []),
            context: SkyContext(sunAltitudeDeg: -40, isDark: true),
            rejected: [rejected(.belowHorizon)],
            pointingConeDeg: fixtureCone
        )
        XCTAssertNil(withAnswer.searchHint)
    }

    // MARK: - Sebab tunggal

    /// Langit terang diutamakan: ia sifat langit, bukan sifat satu benda.
    func testDaylightWinsOverPerObjectReasons() {
        let r = resolution(context: SkyContext(sunAltitudeDeg: 10, isDark: false),
                           rejected: [rejected(.belowHorizon)])
        XCTAssertEqual(r.searchHint, .daylight)
    }

    /// Langit gelap + semua benda di bawah horizon.
    func testAllBelowHorizonWhenEveryRejectionAgrees() {
        let r = resolution(context: SkyContext(sunAltitudeDeg: -40, isDark: true),
                           rejected: [rejected(.belowHorizon, id: "a"),
                                      rejected(.belowHorizon, id: "b")])
        XCTAssertEqual(r.searchHint, .allBelowHorizon)
    }

    /// Langit gelap + semua benda terlalu redup.
    func testAllTooFaintWhenEveryRejectionAgrees() {
        let r = resolution(context: SkyContext(sunAltitudeDeg: -40, isDark: true),
                           rejected: [rejected(.tooFaint, id: "a"),
                                      rejected(.tooFaint, id: "b")])
        XCTAssertEqual(r.searchHint, .allTooFaint)
    }

    /// Langit gelap + semua benda terlalu dekat Matahari.
    func testAllTooCloseToSunWhenEveryRejectionAgrees() {
        let r = resolution(context: SkyContext(sunAltitudeDeg: -40, isDark: true),
                           rejected: [rejected(.tooCloseToSun, id: "a"),
                                      rejected(.tooCloseToSun, id: "b")])
        XCTAssertEqual(r.searchHint, .allTooCloseToSun)
    }

    // MARK: - Kejujuran saat alasan bercampur

    /// Alasan bercampur tidak punya satu kalimat jujur -> `noCandidates`,
    /// bukan menebak salah satu sebab.
    func testMixedReasonsFallBackToNoCandidates() {
        let r = resolution(context: SkyContext(sunAltitudeDeg: -40, isDark: true),
                           rejected: [rejected(.belowHorizon, id: "a"),
                                      rejected(.tooFaint, id: "b")])
        XCTAssertEqual(r.searchHint, .noCandidates)
    }

    /// Tidak ada yang ditolak (katalog kosong, atau tidak ada benda di kerucut)
    /// -> "tidak ada yang cocok", bukan sebab yang dikarang.
    func testNoRejectionsMeansNoCandidates() {
        let r = resolution(context: SkyContext(sunAltitudeDeg: -40, isDark: true))
        XCTAssertEqual(r.searchHint, .noCandidates)
    }

    // MARK: - Teks

    /// Setiap hint punya kalimat yang berbeda dan tidak kosong.
    func testEveryHintHasItsOwnMessage() {
        let messages = SearchHint.allCases.map(\.message)
        XCTAssertEqual(messages.count, Set(messages).count)
        XCTAssertFalse(messages.contains(where: \.isEmpty))
    }

    /// Kalimat yang ditampilkan tidak boleh sama dengan kunci katalognya.
    func testMessagesAreNotRawKeys() {
        for hint in SearchHint.allCases {
            XCTAssertNotEqual(hint.message, hint.text.rawValue)
        }
    }

    // MARK: - Kalimat panduan (satu sumber untuk semua layar)

    /// Saat mencari dengan alasan yang diketahui, `guidanceText` memakai
    /// alasan itu — bukan kalimat generik keadaan.
    func testGuidanceTextUsesHintWhileSearching() {
        let snapshot = PointingSnapshot(state: .searching, searchHint: .daylight)
        XCTAssertEqual(snapshot.guidanceText, SearchHint.daylight.message)
        XCTAssertNotEqual(snapshot.guidanceText, PointingState.searching.guidance)
    }

    /// Tanpa alasan, `guidanceText` jatuh ke panduan keadaan yang netral.
    func testGuidanceTextFallsBackWithoutHint() {
        let snapshot = PointingSnapshot(state: .searching, searchHint: nil)
        XCTAssertEqual(snapshot.guidanceText, PointingState.searching.guidance)
    }

    /// Keadaan selain `.searching` **selalu** memakai panduan keadaan, bahkan
    /// bila `searchHint` entah bagaimana terisi. Ini penjaga agar alasan tidak
    /// pernah bocor ke keadaan yang tidak memilikinya.
    func testGuidanceTextIgnoresHintOutsideSearching() {
        for state in [PointingState.idle, .pointing, .lock, .uncertain, .unavailable] {
            let snapshot = PointingSnapshot(state: state, searchHint: .daylight)
            XCTAssertEqual(snapshot.guidanceText, state.guidance,
                           "\(state) memakai hint padahal bukan .searching")
        }
    }

    // MARK: - Integrasi melalui controller

    /// Arah jauh dari satu-satunya bintang (katalog tanpa efemeris -> langit
    /// selalu gelap) harus membawa hint yang **jujur**: semua benda di bawah
    /// horizon, bukan "belum ada objek" yang seragam.
    func testControllerCarriesHonestHintWhileSearching() {
        // Bintang di deklinasi +89°: dari lintang -6,2° ia **selalu** di bawah
        // horizon (ketinggiannya ≈ −6°), jadi penolakannya deterministik tanpa
        // bergantung pada waktu sampel.
        let polaris = CelestialObject(id: "polaris", name: "Polaris", kind: .star,
                                      raDeg: 0, decDeg: 89, magnitude: 2.0)
        let policy = VisibilityPolicy(minAltitudeDeg: 5, limitingMagnitude: 6,
                                      sunAltitudeForDarknessDeg: -6,
                                      minSunSeparationDeg: 30)
        let resolver = PointingResolver(catalogue: [polaris], policy: policy)
        let c = PointingController(resolver: resolver, observer: observer,
                                   config: PointingControllerConfig(coneDeg: 5.0))

        // Arahkan **ke Polaris itu sendiri**, bukan ke zenith yang jauh dari
        // sana. Alasannya bukan sekadar agar fixture menyalakan penyaringan:
        // versi lama mengarahkan jam ke zenith sisi selatan — sekitar 80 derajat
        // dari Polaris — lalu tetap menuntut jawaban "semua di bawah horizon".
        //
        // Itu persis cacat yang ditutup `SearchHintConeScopeTests`: kerucut arah
        // tunjuk saat itu **kosong**, dan tidak ada benda di dalamnya yang bisa
        // diperiksa. Yang jujur untuk arah kosong adalah "belum ada objek yang
        // cocok", bukan "semua di bawah horizon". Jadi orientasi lama bukan
        // sekadar fixture yang ceroboh — ia adalah cacat yang sama, ditulis
        // sebagai expectations. Memakai arah Polaris membuat hint spesifik ini
        // **benar** kembali: ada benda di kerucut, dan benda itu di bawah horizon.
        let polarisDirection = resolver.horizontal(of: polaris, observer: observer,
                                                   date: date)!
        XCTAssertLessThan(polarisDirection.altitudeDeg, 5,
                          "Polaris harus di bawah horizon agar fixture ini menguji "
                          + "penolakan, bukan kandidat")
        let q = quaternion(viewPointingAt: polarisDirection)
        for step in 0..<12 {
            c.feed(quaternion: q, timestamp: date.addingTimeInterval(Double(step) * 0.1))
        }

        XCTAssertEqual(c.snapshot.state, .searching)
        XCTAssertEqual(c.snapshot.searchHint, .allBelowHorizon)
    }

    /// Saat terkunci, tidak ada hint — meskipun resolusi terakhir punya
    /// penolakan.
    func testControllerHasNoHintWhenLocked() {
        let resolver = PointingResolver(catalogue: [sirius], policy: .permissive)
        let c = PointingController(resolver: resolver, observer: observer,
                                   config: PointingControllerConfig(coneDeg: 5.0))
        let dir = resolver.horizontal(of: sirius, observer: observer, date: date)!
        let q = quaternion(viewPointingAt: dir)
        for step in 0..<12 {
            c.feed(quaternion: q, timestamp: date.addingTimeInterval(Double(step) * 0.1))
        }
        XCTAssertEqual(c.snapshot.state, .lock)
        XCTAssertNil(c.snapshot.searchHint)
    }

    /// Saat pergelangan **bergerak**, hint tidak boleh bocor dari resolusi lama.
    ///
    /// Resolusi terakhir berasal dari arah tunjuk yang sudah ditinggalkan; alasan
    /// yang dihitung untuk arah itu bukan penjelasan untuk arah sekarang. Kalau
    /// gerbang keadaan di `feed` dilepas, "semua objek di bawah horizon" akan
    /// muncul tepat saat pengguna menyapu jam ke tempat lain — menjelaskan
    /// sesuatu yang tidak sedang ditunjuk.
    func testControllerDropsHintWhileMoving() {
        let polaris = CelestialObject(id: "polaris", name: "Polaris", kind: .star,
                                      raDeg: 0, decDeg: 89, magnitude: 2.0)
        let policy = VisibilityPolicy(minAltitudeDeg: 5, limitingMagnitude: 6,
                                      sunAltitudeForDarknessDeg: -6,
                                      minSunSeparationDeg: 30)
        let resolver = PointingResolver(catalogue: [polaris], policy: policy)
        let c = PointingController(resolver: resolver, observer: observer,
                                   config: PointingControllerConfig(coneDeg: 5.0))

        // Diam dulu supaya resolusi terbentuk dan hint terisi.
        let still = quaternion(viewPointingAt: HorizontalCoord(altitudeDeg: 80, azimuthDeg: 180))
        for step in 0..<12 {
            c.feed(quaternion: still, timestamp: date.addingTimeInterval(Double(step) * 0.1))
        }
        XCTAssertEqual(c.snapshot.state, .searching)
        XCTAssertNotNil(c.snapshot.searchHint)

        // Sapuan cepat: keadaan menjadi `.pointing`, dan hint harus hilang.
        let swept = Quaternion.axisAngle(axis: Vector3.unitZ, radians: SkyMath.deg2rad(120))!
        let update = c.feed(quaternion: swept, timestamp: date.addingTimeInterval(2.0))
        XCTAssertEqual(update.snapshot.state, .pointing)
        XCTAssertNil(update.snapshot.searchHint)
    }

    // MARK: - Helper sensor

    /// Quaternion yang sumbu pandangnya mengarah ke `target` (sensor sempurna).
    private func quaternion(viewPointingAt target: HorizontalCoord) -> Quaternion {
        let v = LocalFrame.enuFromHorizontal(target)
        let d = Vector3(x: v.y, y: v.z, z: v.x)
        let from = Vector3.unitZ
        let axis = from.cross(d)
        if axis.magnitude < 1e-12 { return .identity }
        let angle = acos(max(-1.0, min(1.0, from.dot(d))))
        return Quaternion.axisAngle(axis: axis, radians: angle)!
    }
}
