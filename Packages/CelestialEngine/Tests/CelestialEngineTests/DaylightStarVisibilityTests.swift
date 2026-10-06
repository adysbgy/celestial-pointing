import XCTest
@testable import CelestialEngine

/// Siang hari: engine tidak boleh mengklaim bintang dengan keyakinan tinggi.
///
/// **Tempatnya di sini, dan bukan di `VisibilityTests`.** `VisibilityFilter`
/// sudah diuji sebagai fungsi murni — `testDaylightRejectsEverything` menyalakannya,
/// dan uji itu benar-benar menangkap mutasi (dicoba: cabangnya diganti jadi
/// `if false`; satu-satunya uji yang merah adalah `VisibilityTests` itu sendiri).
/// Yang **tidak** diuji adalah apakah penyaringan itu benar-benar berlaku di jalur
/// resolusi, ketika sebuah bintang memenuhi **semua** syarat selain "langit
/// harus gelap" — yaitu tepat satu hal yang sedang diuji di sini.
///
/// Utas sampai ke keyakinan `HIGH` milik lapisan lain; di resolver inilah
/// penyaringan terang/gelap pertama kali bertemu kandidat sungguhan.
final class DaylightStarVisibilityTests: XCTestCase {

    private let jakarta = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)

    /// Tengah hari Jakarta, 1 Januari 2026, 05:00 UTC (= 12:00 WIB).
    ///
    /// Tanggal ini dipilih karena **langitnya benar-benar terang**, bukan karena
    /// angka apa pun yang ditulis tangan: `AstronomyKit` dihitung langsung untuk
    /// tinggi Matahari, dan `testFixtureTimeIsActuallyDaylight` mengunci bahwa
    /// hasilnya benar-benar siang. Kalau tanggal ini nanti berubah, pengaruhnya
    /// terlihat sebagai kegagalan-prasyarat yang menyebut penyebabnya — bukan
    /// sebagai kunci yang tiba-tiba hilang.
    private let noon = ISO8601DateFormatter().date(from: "2026-01-01T05:00:00Z")!

    private func resolver(policy: VisibilityPolicy = VisibilityPolicy()) -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: policy,
                         ephemeris: AstronomyKitEphemeris())
    }

    private func direction(ofObjectID id: String,
                           observer: Observer,
                           date: Date) throws -> HorizontalCoord {
        try XCTUnwrap(
            resolver().horizontal(ofObjectID: id, observer: observer, date: date),
            "arah \(id) harus bisa dihitung")
    }

    // MARK: - Prasyarat: memang siang

    /// Pengaman prasyarat.
    ///
    /// Tanpa ini, semua pembuktian di bawah bisa hijau karena alasan yang salah:
    /// kalau `noon` ternyata bukan siang, "tidak ada HIGH" tetap benar dan uji ini
    /// tidak lagi membuktikan apa pun.
    func testFixtureTimeIsActuallyDaylight() {
        let context = resolver().skyContext(observer: jakarta, date: noon)
        XCTAssertFalse(context.isDark, "waktu uji harus siang, bukan malam")
        XCTAssertGreaterThan(context.sunAltitudeDeg, 60,
                             "Matahari harus tinggi, jauh di atas ambang gelap -6 derajat")
    }

    // MARK: - Bintang yang memenuhi semua syarat lain

    /// Prasyarat kedua: bintangnya **hanya** tersingkir karena terang.
    ///
    /// Kalau bintang ini ditolak karena `belowHorizon`, `tooFaint`, atau
    /// `tooCloseToSun`, maka "ditolak saat siang" di bawah bisa benar sepenuhnya
    /// karena salah satu sebab itu — dan utas yang sedang diuji tidak pernah
    /// tersentuh. Jadi tiap penyaringan lain diperiksa satu per satu, memakai
    /// nilai yang sama dengan yang dipakai resolver.
    func testFixtureStarPassesEveryFilterExceptDaylight() throws {
        let policy = VisibilityPolicy()
        let dir = try direction(ofObjectID: "arcturus", observer: jakarta, date: noon)
        let arcturus = try XCTUnwrap(
            Catalogue.brightStars.first { $0.id == "arcturus" },
            "bintang acuan harus ada di katalog")

        // Ketinggian: jauh di atas ambang.
        XCTAssertGreaterThan(dir.altitudeDeg, policy.minAltitudeDeg)

        // Magnitudo: di dalam batas dasar.
        XCTAssertLessThanOrEqual(
            arcturus.magnitude,
            VisibilityFilter.effectiveLimitingMagnitude(
                context: SkyContext(sunAltitudeDeg: -40, isDark: true), policy: policy))

        // Jarak dari Matahari: di luar radius pengaman.
        //
        // Matahari **tidak** bisa diambil lewat `horizontal(ofObjectID:)` —
        // ia sengaja `nil` karena tidak pernah boleh jadi target. Posisi yang
        // dipakai di sini dihitung persis seperti yang dilakukan
        // `PointingResolver.diagnose`: sampel efemeris lalu
        // `equatorialToHorizontal`. Kalau diambil dari jalur lain, uji ini
        // membandingkan dua definisi "separationFromSunDeg" yang berbeda
        // dan bisa menyimpang tanpa terlihat.
        let sunSample = try AstronomyKitEphemeris().apparent(.sun, at: noon, from: jakarta)
        let sun = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sunSample.raDeg, decDeg: sunSample.decDeg),
            observer: jakarta,
            jd: SkyMath.julianDate(from: noon))
        XCTAssertGreaterThan(SkyMath.angularSeparationHorizontalDeg(dir, sun),
                             policy.minSunSeparationDeg)

        // Bukti positif: dengan langit dipaksa gelap, bintang ini **lolos**.
        // Tanpa baris ini, "lolos semua penyaringan lain" hanya klaim.
        let night = resolver().diagnose(
            pointing: dir, observer: jakarta, date: noon, coneDeg: 5,
            overrideContext: SkyContext(sunAltitudeDeg: -90, isDark: true))
        XCTAssertTrue(night.intent.candidates.contains { $0.object.id == "arcturus" },
                      "bintang acuan harus benar-benar lolos di langit gelap")
        XCTAssertFalse(night.rejected.contains { $0.object.id == "arcturus" })
    }

    // MARK: - Bukti: penyaringan terang bekerja di jalur resolusi

    /// Titik yang diuji: **tunjuk tepat ke Arcturus saat tengah hari**.
    ///
    /// Beda dari uji yang sudah ada (`testDaylightProducesNoHighConfidenceStar`)
    /// ada pada arah tunjuknya. Uji lama menunjuk alt 60 / az 180 derajat, dan di
    /// dalam kerucut 40 derajat itu satu-satunya bintang katalog berjarak 15,9
    /// derajat — jauh dari ambang `maxSeparationDeg` (10 derajat pada
    /// `ConfidencePolicy()` bawaan). Artinya MEDIUM-nya berasal dari **tidak
    /// mengenai bintang**, sama sekali bukan dari penyaringan siang. Uji lama tetap
    /// hijau saat penyaringan siang dimatikan, karena ia tidak pernah mengujinya.
    ///
    /// Di sini jaraknya 0 derajat, jadi satu-satunya alasan penolakan adalah
    /// terang. Dan kalau penyaringannya hilang, bintang ini didekati pada 0 derajat
    /// dengan tetangga terdekat 32,8 derajat (jauh di atas ambiguitas 20 derajat) —
    /// yaitu **HIGH**: persis klaim "kita tahu apa yang kamu lihat" pada langit
    /// yang terang.
    func testNoHighConfidenceStarAtExactNoonPointing() throws {
        let dir = try direction(ofObjectID: "arcturus", observer: jakarta, date: noon)
        let resolution = resolver().diagnose(pointing: dir, observer: jakarta,
                                             date: noon, coneDeg: 5)

        XCTAssertNil(resolution.intent.best, "siang hari tidak boleh ada jawaban sama sekali")
        XCTAssertNotEqual(resolution.intent.level, .high)
        XCTAssertFalse(resolution.intent.candidates.contains { $0.object.id == "arcturus" },
                       "bintang terang tidak boleh jadi kandidat saat langit terang")
    }

    /// Penolakan harus **beralasan**, bukan sekadar tidak muncul.
    ///
    /// Tanpa alasan, "tidak ada kandidat" adalah hasil yang sama dengan katalog
    /// kosong atau kerucut yang salah arah — dan penyaringan siang bisa hilang
    /// sepenuhnya tanpa satu pun teks yang berubah. `Visibility.daylight` adalah
    /// yang membedakan "langit terang" dari "menuju tempat kosong".
    ///
    /// Terjemahannya ke kalimat pengguna **tidak** diuji di sini: `searchHint`
    /// tinggal di `PointingKit` (`SearchHint.swift`), dan aturan "hari terang
    /// didahulukan atas alasan per-benda" sudah dikunci di sana lewat
    /// `SearchHintTests.testDaylightWinsOverPerObjectReasons`. Menguji kalimatnya
    /// lagi dari paket engine hanya akan membuat dua salinan aturan yang bisa
    /// berbeda pendapat tanpa satu pun yang menyadarinya.
    func testNoonStarIsRejectedForDaylightNotForSomethingElse() throws {
        let dir = try direction(ofObjectID: "arcturus", observer: jakarta, date: noon)
        let resolution = resolver().diagnose(pointing: dir, observer: jakarta,
                                             date: noon, coneDeg: 5)
        let arcturus = resolution.rejected.first { $0.object.id == "arcturus" }
        XCTAssertEqual(arcturus?.visibility, .daylight,
                       "sebab penolakan harus 'langit terang', bukan sebab lain yang kebetulan berlaku")
        // Konteks yang dipakai resolver harus jujur soal terang/gelangnya,
        // kalau tidak `isDark` hanya benar karena kebetulan.
        XCTAssertFalse(resolution.context.isDark)
    }

    /// Efemeris wajib benar-benar dipakai, kalau tidak uji ini tidak membuktikan apa pun.
    ///
    /// Tanpa baris ini, penyaringan siang bisa lolos bukan karena ia bekerja,
    /// melainkan karena tidak ada benda tata surya yang ikut dihitung sehingga
    /// `skyContext` jatuh ke asumsi "langit gelap" — yang justru **meloloskan**
    /// bintang. Uji ini mengunci asumsi itu, sehingga dua pembuktian di atas
    /// berhenti bergantung pada hal yang sama.
    func testResolverWithoutEphemerisWouldHaveAcceptedTheStar() throws {
        let dir = try direction(ofObjectID: "arcturus", observer: jakarta, date: noon)
        let blind = PointingResolver(catalogue: Catalogue.brightStars,
                                     policy: VisibilityPolicy(),
                                     ephemeris: nil)
        let resolution = blind.diagnose(pointing: dir, observer: jakarta,
                                        date: noon, coneDeg: 5)
        XCTAssertTrue(resolution.intent.candidates.contains { $0.object.id == "arcturus" },
                      "tanpa efemeris bintang ini harus lolos — itulah yang membuat penyaringan siang berarti")
        XCTAssertFalse(resolution.rejected.contains { $0.object.id == "arcturus" })
    }
}
