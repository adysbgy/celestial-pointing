import XCTest
import CelestialEngine
@testable import PointingKit

/// Pemilihan target dan arah benda di lapisan app.
final class TargetsTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private let sirius = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                         raDeg: 101.28715533, decDeg: -16.71611586,
                                         magnitude: -1.46)

    /// Katalog satu bintang: membuat uji pemilihan target deterministik
    /// (tidak bergantung bintang mana yang kebetulan sedang di atas horizon).
    private func resolver(ephemeris: Bool = false) -> PointingResolver {
        PointingResolver(catalogue: [sirius],
                         policy: .permissive,
                         ephemeris: ephemeris ? AstronomyKitEphemeris() : nil)
    }

    // MARK: - Daftar target

    func testTargetsAboveHorizonOnlyByDefault() {
        let r = PointingResolver(catalogue: Catalogue.brightStars, policy: .permissive)
        let targets = r.availableTargets(observer: observer, date: date)
        XCTAssertFalse(targets.isEmpty)
        XCTAssertTrue(targets.allSatisfy { $0.direction.altitudeDeg > 0 })
        XCTAssertTrue(targets.allSatisfy { !$0.isMoving }, "tanpa efemeris semua target adalah bintang")
    }

    /// Benda bergerak (Bulan/planet) harus ikut muncul saat efemeris tersedia,
    /// dan ditandai `isMoving` supaya UI tahu arahnya berubah.
    func testSolarSystemTargetsAppearWhenEphemerisAvailable() {
        let r = PointingResolver(catalogue: Catalogue.brightStars,
                                 policy: .permissive,
                                 ephemeris: AstronomyKitEphemeris())
        let targets = r.availableTargets(observer: observer, date: date)
        XCTAssertTrue(targets.contains { $0.isMoving })
        XCTAssertTrue(targets.allSatisfy { $0.id != "sun" }, "Matahari tidak pernah jadi target")
    }

    func testTargetsAreSortedBrightestFirst() {
        let r = PointingResolver(catalogue: Catalogue.brightStars, policy: .permissive)
        let magnitudes = r.availableTargets(observer: observer, date: date).map(\.magnitude)
        XCTAssertEqual(magnitudes, magnitudes.sorted())
    }

    func testTargetSeparationMatchesEngineMath() {
        let r = resolver()
        let target = r.availableTargets(observer: observer, date: date,
                                        aboveHorizonOnly: false).first!
        let other = HorizontalCoord(altitudeDeg: target.direction.altitudeDeg + 3,
                                    azimuthDeg: target.direction.azimuthDeg)
        XCTAssertEqual(target.separation(from: other),
                       SkyMath.angularSeparationHorizontalDeg(other, target.direction),
                       accuracy: 1e-12)
    }

    // MARK: - Target terdekat

    func testNearestTargetFindsExactDirection() {
        let r = resolver()
        let truth = r.horizontal(ofObjectID: "sirius", observer: observer, date: date)!
        let found = r.nearestTarget(to: truth, observer: observer, date: date,
                                    aboveHorizonOnly: false)
        XCTAssertEqual(found?.id, "sirius")
    }

    /// Dua kandidat yang nyaris sama dekatnya **tidak** boleh dipilih diam-diam:
    /// memilih yang salah membuat kalibrasi mengoreksi ke arah yang keliru.
    func testAmbiguousNearestTargetIsRefused() {
        let twin = CelestialObject(id: "sirius-twin", name: "Sirius Twin", kind: .star,
                                   raDeg: sirius.raDeg + 0.05, decDeg: sirius.decDeg,
                                   magnitude: 1.0)
        let r = PointingResolver(catalogue: [sirius, twin], policy: .permissive)
        let truth = r.horizontal(ofObjectID: "sirius", observer: observer, date: date)!

        XCTAssertNil(r.nearestTarget(to: truth, observer: observer, date: date,
                                     aboveHorizonOnly: false),
                     "kandidat berimpit harus ditolak, bukan dipilih yang terdekat")
    }

    func testNearestTargetRespectsSearchRadius() {
        let r = resolver()
        let truth = r.horizontal(ofObjectID: "sirius", observer: observer, date: date)!
        let far = HorizontalCoord(altitudeDeg: truth.altitudeDeg + 80,
                                  azimuthDeg: SkyMath.normalizeDeg(truth.azimuthDeg + 180))
        XCTAssertNil(r.nearestTarget(to: far, observer: observer, date: date, withinDeg: 5,
                                     aboveHorizonOnly: false))
    }

    func testNearestTargetSkipsBelowHorizon() {
        let r = resolver()
        // Arah di bawah horizon: tidak ada target yang boleh dipilih di sana.
        let below = HorizontalCoord(altitudeDeg: -40, azimuthDeg: 180)
        XCTAssertNil(r.nearestTarget(to: below, observer: observer, date: date))
    }

    /// Objek langit dalam **tidak boleh** menjadi acuan kalibrasi.
    ///
    /// `CalibrationSession.refreshReferenceTargets` sengaja menyaring
    /// `kind == .star`, dan alasannya ada di komentarnya: kebenaran kalibrasi
    /// diambil dari posisi katalog, dan objek langit dalam posisinya juga di
    /// katalog — yang salah adalah ia **tidak punya tepi**, jadi pengguna tidak
    /// bisa tahu bagian mana dari kabut Orion yang ia tunjuk, dan sampelnya
    /// jauh lebih berisik.
    ///
    /// Tapi `captureNearest` **tidak lewat daftar itu**: ia memanggil
    /// `nearestTarget` langsung, lalu `capture(objectID:)`, dan tidak satu pun
    /// memeriksa jenis benda. Jadi seluruh penjagaan "acuan harus bintang"
    /// bergantung pada daftar yang justru dilewati oleh jalur "tunjuk lalu
    /// catat". Selama tidak ada objek langit dalam di katalog mana pun, jalur
    /// ini tidak bisa dijangkau dan tidak ada yang tahu. Begitu katalog
    /// produksi memuatnya (lihat `DeepSkyCatalogue`), menunjuk ke arah M42 dan
    /// menekan "Catat" akan memakai kabut itu sebagai acuan kalibrasi.
    func testNearestTargetNeverResolvesToADeepSkyObject() {
        let r = PointingResolver(catalogue: DeepSkyCatalogue.objects,
                                 policy: .permissive)
        let nebula = DeepSkyCatalogue.objects.first { $0.id == "m42" }!
        let truth = r.horizontal(of: nebula, observer: observer, date: date)!

        // Arahnya **tepat** ke nebula: tanpa penyaringan, ini kandidat
        // sempurna dengan jarak nol dan pasti terpilih.
        XCTAssertNil(r.nearestTarget(to: truth, observer: observer, date: date,
                                     aboveHorizonOnly: false),
                     "nebula tidak punya tepi — tidak boleh jadi acuan kalibrasi")
    }

    // MARK: - Lokasi

    func testLocationValidity() {
        XCTAssertTrue(ObserverLocation.fallback.isValid)
        XCTAssertFalse(ObserverLocation(latitudeDeg: 120, longitudeDeg: 0,
                                        label: "x", source: "test").isValid)
        XCTAssertFalse(ObserverLocation(latitudeDeg: 0, longitudeDeg: 400,
                                        label: "x", source: "test").isValid)
    }

    func testLocationConvertsToObserver() {
        let location = ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                                        label: "Bandung", source: "test")
        XCTAssertEqual(location.observer, observer)
    }

    /// `isSamePlace` memisahkan perpindahan tempat yang sungguhan dari getaran
    /// GPS. `ObserverLocation` membawa `capturedAt` yang berubah tiap pembaruan,
    /// jadi `==` tidak bisa dipakai: ia akan menganggap tiap perbaikan GPS
    /// sebagai perpindahan, dan seluruh alur akan direset tiap detik.
    func testIsSamePlaceIgnoresTimestampAndJitter() {
        let first = ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                                     label: "a", source: "corelocation",
                                     capturedAt: Date(timeIntervalSince1970: 0))
        // Tempat yang sama, waktu berbeda — dan getaran GPS ~10 m.
        let later = ObserverLocation(latitudeDeg: -6.20003, longitudeDeg: 106.80004,
                                     label: "b", source: "corelocation",
                                     capturedAt: Date(timeIntervalSince1970: 600))

        XCTAssertNotEqual(first, later, "nilai lengkapnya memang berbeda")
        XCTAssertTrue(first.isSamePlace(as: later),
                      "getaran GPS puluhan meter bukan perpindahan tempat")

        // Perpindahan sungguhan harus terdeteksi.
        let elsewhere = ObserverLocation(latitudeDeg: -6.3, longitudeDeg: 106.8,
                                         label: "c", source: "corelocation")
        XCTAssertFalse(first.isSamePlace(as: elsewhere))

        // Perpindahan kecil tapi nyata (0.05° ≈ 5.5 km) juga harus terdeteksi,
        // supaya ambangnya tidak terlalu longgar.
        let nearbyCity = ObserverLocation(latitudeDeg: -6.25, longitudeDeg: 106.8,
                                          label: "d", source: "corelocation")
        XCTAssertFalse(first.isSamePlace(as: nearbyCity))
    }

    /// Lokasi yang tidak sah tidak boleh dianggap "tempat yang sama" dengan
    /// apa pun — menerimanya berarti memakai koordinat yang tidak masuk akal.
    func testInvalidLocationIsNeverSamePlace() {
        let valid = ObserverLocation(latitudeDeg: 0, longitudeDeg: 0,
                                     label: "ok", source: "manual")
        let invalid = ObserverLocation(latitudeDeg: 120, longitudeDeg: 0,
                                       label: "bad", source: "manual")
        XCTAssertFalse(invalid.isSamePlace(as: valid))
        XCTAssertFalse(valid.isSamePlace(as: invalid))
        XCTAssertFalse(invalid.isSamePlace(as: invalid))
    }

    /// Lokasi darurat harus jelas menandai dirinya supaya tidak salah dianggap
    /// lokasi pengukuran.
    ///
    /// Labelnya juga harus **lewat katalog**: ia ditampilkan apa adanya di
    /// layar utama jam (`Text("Lokasi: \(engine.location.label)")`). Selama
    /// teksnya literal di `ObserverLocation.fallback`, ia tak terlihat Aturan 4
    /// (bukan argumen `Text(...)`) dan tak punya kunci untuk diperiksa
    /// Aturan 6 — pengguna Bahasa Inggris membaca label Indonesia.
    ///
    /// Nilai `id` bawaan sengaja tetap "Jakarta (bawaan)" supaya perilaku tanpa
    /// bridge tidak berubah; yang berubah adalah **jalurnya**.
    func testFallbackIsLabelled() {
        XCTAssertEqual(ObserverLocation.fallback.source, "fallback")
        XCTAssertTrue(ObserverLocation.fallback.label.contains("bawaan"))
        XCTAssertEqual(ObserverLocation.fallback.label,
                       TextLocalization.text(.locationFallbackLabel))
    }

    /// Bridge benar-benar mengganti label darurat.
    ///
    /// Tanpa uji ini, kunci yang terdaftar tapi tidak pernah dibaca `fallback`
    /// akan tampak benar padahal tidak berpengaruh.
    func testFallbackLabelFollowsTheBridge() {
        TextLocalization.install { key in
            key == "location.fallback.label" ? "Jakarta (default)" : nil
        }
        defer { TextLocalization.reset() }
        XCTAssertEqual(ObserverLocation.fallback.label, "Jakarta (default)")
    }

    /// `isFallback` adalah pembeda yang dipakai UI untuk memperingatkan bahwa
    /// tinggi benda langit dihitung untuk tempat lain. Kalau ia salah menjawab,
    /// peringatannya hilang dan daftar target yang salah tempat tampak normal.
    func testIsFallbackDistinguishesMeasuredLocation() {
        XCTAssertTrue(ObserverLocation.fallback.isFallback)

        let measured = ObserverLocation(latitudeDeg: -6.2,
                                        longitudeDeg: 106.8,
                                        label: "Jakarta (bawaan)",
                                        source: "corelocation")
        XCTAssertFalse(measured.isFallback,
                       "label yang mirip tidak boleh membuat lokasi terukur dianggap darurat")

        // Bahkan koordinat yang persis sama dengan fallback tetap bukan
        // fallback bila asalnya pengukuran: yang menentukan adalah sumbernya.
        XCTAssertEqual(measured.latitudeDeg, ObserverLocation.fallback.latitudeDeg)
        XCTAssertEqual(measured.longitudeDeg, ObserverLocation.fallback.longitudeDeg)

        let manual = ObserverLocation(latitudeDeg: 0, longitudeDeg: 0,
                                      label: "manual", source: "manual")
        XCTAssertFalse(manual.isFallback)
    }
}
