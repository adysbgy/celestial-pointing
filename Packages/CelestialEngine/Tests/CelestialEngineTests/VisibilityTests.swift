import XCTest
@testable import CelestialEngine

/// Uji penyaring visibilitas. Semua nilai ditulis tangan — tidak menyentuh
/// efemeris — supaya aturannya bisa diuji terpisah dari akurasi posisi.
final class VisibilityTests: XCTestCase {

    private let night = SkyContext(sunAltitudeDeg: -40, isDark: true)
    private let day = SkyContext(sunAltitudeDeg: 20, isDark: false)
    private let policy = VisibilityPolicy()

    // MARK: - Aturan dasar

    func testVisibleObjectIsCandidate() {
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 1.0, separationFromSunDeg: 120,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .visible)
        XCTAssertTrue(result.isCandidate)
    }

    func testBelowHorizonIsRejected() {
        let result = VisibilityFilter.classify(
            altitudeDeg: -3, magnitude: 1.0, separationFromSunDeg: 120,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .belowHorizon)
        XCTAssertFalse(result.isCandidate)
    }

    /// Ambang ketinggian bersifat inklusif: benda tepat di `minAltitudeDeg`
    /// masih lolos, yang di bawahnya dibuang.
    func testMinimumAltitudeBoundaryIsInclusive() {
        let atLimit = VisibilityFilter.classify(
            altitudeDeg: policy.minAltitudeDeg, magnitude: 1.0,
            separationFromSunDeg: 120, context: night, policy: policy
        )
        XCTAssertEqual(atLimit, .visible, "tepat di ambang masih terlihat")

        let below = VisibilityFilter.classify(
            altitudeDeg: policy.minAltitudeDeg - 0.1, magnitude: 1.0,
            separationFromSunDeg: 120, context: night, policy: policy
        )
        XCTAssertEqual(below, .belowHorizon)
    }

    func testTooFaintIsRejected() {
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 8.5, separationFromSunDeg: 120,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .tooFaint)
    }

    // MARK: - Objek langit dalam punya ambang sendiri

    /// Bintang titik dan objek langit dalam punya ambang magnitudo beda.
    ///
    /// **Cacat yang ditutup uji ini.** `classify` dulu hanya memakai
    /// `limitingMagnitude` (6.0) untuk segalanya. Katalog produksi memuat
    /// objek langit dalam sampai mag 8.8 (M57), dan seluruh jalur visualnya
    /// (bentuk per-morfologi, label, pengucapan) sudah ada — tapi keenam
    /// anggota yang melebihi 6.0 diklasifikasi `.tooFaint`, jadi resolver
    /// tidak pernah menghasilkan mereka dan kode gambarnya mati di produksi.
    /// Ini kelas cacat yang sama persis dengan yang dikejar
    /// `DeepSkyCatalogueTests`: tiap bagian benar sendiri, yang hilang adalah
    /// ambang yang membedakan bintang dari objek langit dalam.
    ///
    /// Yang diuji: di langit gelap, M57 (mag 8.8, nebula planetari) harus
    /// **terlihat** sebagai objek langit dalam, sementara bintang mag 8.5
    /// tetap **terlalu redup**. Satu ambang tidak boleh memenangkan keduanya.
    func testDeepSkyUsesItsOwnLimitingMagnitude() {
        let m57 = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 8.8, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .deepSky
        )
        XCTAssertEqual(m57, .visible,
                       "M57 (mag 8.8) harus terlihat sebagai objek langit dalam")

        let faintStar = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 8.5, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .star
        )
        XCTAssertEqual(faintStar, .tooFaint,
                       "bintang mag 8.5 tetap terlalu redup — ambang bintang tidak berubah")

        // Tanpa `kind` (bawaan .star) objek mag 8.8 harus tetap ditolak,
        // supaya keliru memanggil tanpa `kind` tidak membocorkan ambang DSO.
        let defaultKind = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 8.8, separationFromSunDeg: 120,
            context: night, policy: policy
        )
        XCTAssertEqual(defaultKind, .tooFaint,
                       "tanpa kind, mag 8.8 tetap di bawah ambang bintang")
    }

    /// Cahaya Bulan tetap mengketatkan ambang objek langit dalam — M57 yang
    /// lolos di langit gelap ditolak saat purnama tinggi.
    ///
    /// Ini yang menjaga ambang terpisah tetap jujur: nebula mag 8.8 memang
    /// tidak terlihat di langit terang Bulan, jadi penolakannya harus tetap
    /// berlaku, bukan dihapus oleh ambang DSO yang lebih longgar.
    func testMoonlightAlsoTightensTheDeepSkyLimit() {
        let fullMoon = SkyContext(sunAltitudeDeg: -40,
                                  moonAltitudeDeg: 30,
                                  moonIlluminationFraction: 1.0,
                                  isDark: true)
        let m57Dark = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 8.8, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .deepSky
        )
        let m57Moon = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 8.8, separationFromSunDeg: 120,
            context: fullMoon, policy: policy, kind: .deepSky
        )
        XCTAssertEqual(m57Dark, .visible, "M57 terlihat di langit gelap")
        XCTAssertEqual(m57Moon, .tooFaint,
                       "purnama mengetatkan ambang DSO: M57 ditolak di langit terang Bulan")
    }

    // MARK: - Planet luar punya ambang sendiri

    /// Planet teleskopik luar (Neptunus) punya ambang magnitudo sendiri.
    ///
    /// **Cacat yang ditutup uji ini.** Sebelum Uranus dan Neptunus masuk
    /// katalog, seluruh benda pointable adalah objek mata telanjang, sehingga
    /// ambang bintang 6.0 untuk segalanya tidak pernah salah. Neptunus
    /// (mag 7.8) mematahkannya: `classify` mengembalikannya `.tooFaint`
    /// **sebelum** ketinggiannya diperiksa, jadi "tunjuk ke arah Neptunus"
    /// selalu berakhir "tidak ada" — bukan kejujuran, melainkan engine yang
    /// diam-diam membuang benda yang memang ada di sana.
    ///
    /// Yang diuji, dua arah sekaligus: di langit gelap Neptunus harus
    /// **terlihat** sebagai planet, sementara bintang mag 7.8 tetap **terlalu
    /// redup** — ambang bintang tidak boleh ikut longgar, karena itu justru
    /// mengklaim bintang redup palsu sebagai terlihat.
    func testOuterPlanetUsesItsOwnLimitingMagnitude() {
        let neptune = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 7.8, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .planet
        )
        XCTAssertEqual(neptune, .visible,
                       "Neptunus (mag 7.8) harus terlihat sebagai planet")

        let faintStar = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 7.8, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .star
        )
        XCTAssertEqual(faintStar, .tooFaint,
                       "bintang mag 7.8 tetap terlalu redup — ambang bintang tidak berubah")

        // Tanpa `kind` (bawaan .star) planet mag 7.8 harus tetap ditolak,
        // supaya keliru memanggil tanpa `kind` tidak membocorkan ambang planet.
        let defaultKind = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 7.8, separationFromSunDeg: 120,
            context: night, policy: policy
        )
        XCTAssertEqual(defaultKind, .tooFaint,
                       "tanpa kind, mag 7.8 tetap di bawah ambang bintang")
    }

    /// Uranus (mag 5.8) **tidak** boleh bergantung pada ambang planet yang
    /// lebih longgar: ia benda mata telanjang, jadi ia harus terlihat lewat
    /// ambang bintang biasa juga.
    ///
    /// Ini menjaga ambang planet tetap menjadi **pengecualian untuk Neptunus**,
    /// bukan pintu belakang yang membuat seluruh planet lolos tanpa syarat.
    func testBrightOuterPlanetWouldPassEvenOnTheStarLimit() {
        let uranusAsPlanet = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 5.8, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .planet
        )
        let uranusAsStar = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 5.8, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .star
        )
        XCTAssertEqual(uranusAsPlanet, .visible)
        XCTAssertEqual(uranusAsStar, .visible,
                       "Uranus mag 5.8 terlihat mata telanjang; ia tidak butuh ambang planet")
    }

    /// Ambang planet harus menutup **seluruh** rentang magnitudo Neptunus,
    /// bukan magnitudo di sekitar oposisinya saja.
    ///
    /// **Cacat yang ditutup uji ini, dan kenapa uji sebelumnya melewatkannya.**
    /// `testOuterPlanetUsesItsOwnLimitingMagnitude` menguji mag **7.8** —
    /// angka yang kebetulan sama dengan ambangnya (`7.8 <= 7.8`), jadi ia hijau
    /// walau ambangnya persis sama dengan magnitudo yang diuji. Terukur di
    /// fixture Horizons repo ini (`horizons_reference.json`): Neptunus
    /// **7.853** pada 2000-01-01. Di atas ambang 7.8, jadi pada tanggal itu
    /// engine membuang Neptunus sebagai `.tooFaint` sebelum ketinggiannya
    /// diperiksa — persis kegagalan yang docstring `planetLimitingMagnitude`
    /// klaim sudah ditutup.
    ///
    /// Yang diuji di sini adalah **selisih**, bukan angka: seluruh sampel
    /// Neptunus di fixture harus terlihat, dan masing-masing harus terlihat
    /// dengan margin di atas nol. Uji yang hanya menuntut "terlihat" akan
    /// kembali hijau pada ambang yang pas-pasan, dan ambang yang pas-pasan
    /// adalah bentuk cacat yang baru saja diperbaiki.
    func testPlanetLimitCoversTheWholeNeptuneMagnitudeRange() {
        // Angka dari fixture, ditulis di sini apa adanya supaya uji ini tidak
        // bergantung pada pembacaan berkas JSON di dalam suite.
        let neptuneMagnitudes = [7.853, 7.775, 7.781]

        for magnitude in neptuneMagnitudes {
            let result = VisibilityFilter.classify(
                altitudeDeg: 45, magnitude: magnitude, separationFromSunDeg: 120,
                context: night, policy: policy, kind: .planet
            )
            XCTAssertEqual(result, .visible,
                           "Neptunus mag \(magnitude) harus terlihat, bukan \(result)")
            XCTAssertGreaterThan(policy.planetLimitingMagnitude, magnitude,
                                 "ambang planet harus longgar atas Neptunus yang diredup "
                                 + "oleh orbitnya, bukan hanya pada oposisi")
        }

        // Arah sebaliknya: ambangnya tetap **bukan** tak terbatas. Bintang
        // tetap di 6.0, dan ambang planet tidak boleh melar sampai menerima
        // benda yang jelas teleskopik.
        XCTAssertLessThan(policy.planetLimitingMagnitude, 9.0,
                          "ambang planet tidak boleh menyamai ambang langit dalam")
        let veryFaintPlanet = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 8.9, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .planet
        )
        XCTAssertEqual(veryFaintPlanet, .tooFaint,
                       "planet redup di luar rentang Neptunus tetap ditolak")
    }

    /// Cahaya Bulan tetap mengketatkan ambang planet — Neptunus yang lolos di
    /// langit gelap ditolak saat purnama tinggi.
    ///
    /// Tanpa ini, ambang planet yang lebih longgar akan menjadi klaim palsu:
    /// Neptunus **memang** tidak terlihat mata telanjang di langit berbulan
    /// terang, dan engine yang tetap menawarkannya berbohong dengan tenang.
    func testMoonlightAlsoTightensThePlanetLimit() {
        let fullMoon = SkyContext(sunAltitudeDeg: -40,
                                  moonAltitudeDeg: 30,
                                  moonIlluminationFraction: 1.0,
                                  isDark: true)
        let neptuneDark = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 7.8, separationFromSunDeg: 120,
            context: night, policy: policy, kind: .planet
        )
        let neptuneMoon = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 7.8, separationFromSunDeg: 120,
            context: fullMoon, policy: policy, kind: .planet
        )
        XCTAssertEqual(neptuneDark, .visible, "Neptunus terlihat di langit gelap")
        XCTAssertEqual(neptuneMoon, .tooFaint,
                       "purnama mengetatkan ambang planet: Neptunus ditolak di langit terang Bulan")
    }

    func testDaylightRejectsEverything() {
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: -1.0, separationFromSunDeg: 120,
            context: day, policy: policy
        )
        XCTAssertEqual(result, .daylight)
    }

    // MARK: - Pengaman Matahari

    /// Ini pengaman keras: benda yang terlalu dekat Matahari tidak boleh jadi
    /// target, karena GoTo ke arah Matahari merusak teleskop dan mata.
    func testTooCloseToSunIsRejectedEvenAtNight() {
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: -4.0, separationFromSunDeg: 12,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .tooCloseToSun)
        XCTAssertFalse(result.isCandidate)
    }

    func testSunItselfIsNeverRejectedForBeingCloseToItself() {
        // separationFromSunDeg == nil berarti "ini Matahari"; tidak boleh
        // ditolak oleh aturan jarak-Matahari (ia tetap ditolak sebagai target
        // lewat `pointableBodies`, bukan lewat aturan ini).
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: -26.7, separationFromSunDeg: nil,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .visible)
    }

    // MARK: - Urutan prioritas

    /// Benda di bawah horizon DAN redup harus dilaporkan sebagai di bawah
    /// horizon — alasannya lebih mendasar dan itu yang berguna untuk UI.
    func testBelowHorizonTakesPrecedenceOverFaintness() {
        let result = VisibilityFilter.classify(
            altitudeDeg: -20, magnitude: 12.0, separationFromSunDeg: 90,
            context: night, policy: policy
        )
        XCTAssertEqual(result, .belowHorizon)
    }

    // MARK: - Cahaya Bulan

    /// **Bulan menerangi langit, jadi ia harus menggeser batas magnitudo.**
    ///
    /// Fraksi iluminasi sudah dihitung (`SkyContext.moonIlluminationFraction`)
    /// dan sudah ditampilkan sebagai "Fase Bulan", tapi tidak pernah ikut
    /// memengaruhi penyaringan. Akibatnya ambang magnitudo tidak bergerak sama
    /// sekali antara langit tanpa Bulan dan langit purnama — padahal dua
    /// langit itu jelas tidak sama, dan pengamat yang sedang mengejar bintang
    /// redup akan dikecewakan.
    ///
    /// Yang diuji adalah **arah** pengaruh, bukan angkanya: fraksi besar harus
    /// membuat ambang **lebih ketat** — benda yang lolos tanpa Bulan menjadi
    /// terlalu redup bersamanya. Angka pastinya soal fisika; yang tidak bisa
    /// dibantah adalah arahnya, jadi itu yang dijaga di sini.
    func testMoonlightTightensTheLimitingMagnitude() {
        let withoutMoon = SkyContext(sunAltitudeDeg: -40, isDark: true)
        let withFullMoon = SkyContext(sunAltitudeDeg: -40,
                                      moonAltitudeDeg: 30,
                                      moonIlluminationFraction: 1.0,
                                      isDark: true)

        // Magnitudo 4.5: lolos di langit gelap, tidak lolos di bawah purnama.
        let dark = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 4.5, separationFromSunDeg: 120,
            context: withoutMoon, policy: policy
        )
        let moonlit = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 4.5, separationFromSunDeg: 120,
            context: withFullMoon, policy: policy
        )

        XCTAssertEqual(dark, .visible, "benda ini harus terlihat tanpa Bulan")
        XCTAssertEqual(moonlit, .tooFaint,
                       "purnama menerangi langit, jadi ambang magnitudo harus mengetat")
    }

    /// **Bulan yang sudah terbenam tidak boleh menerangi langit.**
    ///
    /// Ini kelas cacat yang dikejar terus di repo ini: penyaring menuntut
    /// "ada cahaya Bulan" tapi hanya memeriksa fraksi iluminasi, bukan apakah
    /// Bulan benar-benar masih di atas horizon. `moonAltitudeDeg` sudah ada di
    /// `SkyContext` — saat Bulan terbenam ia bernilai negatif, sementara
    /// `moonIlluminationFraction` tetap tidak `nil`. Akibatnya engine membuang
    /// bintang redup untuk Bulan yang pengguna sama sekali tidak bisa lihat:
    /// penolakan palsu, persis yang dilarang PRD v0.4.
    ///
    /// Semua uji cahaya Bulan lain di berkas ini memakai `moonAltitudeDeg: 30`
    /// (Bulan di atas horizon), jadi celah ini tidak pernah tersentuh. Uji ini
    /// yang menyetelnya: purnama tapi **terbenam** → ambang kembali ke dasar,
    /// dan bintang redup lolos seolah langit gelap.
    func testSetMoonDoesNotBrightenTheSky() {
        // Purnama, tapi Bulan sudah di -20° (di bawah horizon).
        let setFullMoon = SkyContext(sunAltitudeDeg: -40,
                                     moonAltitudeDeg: -20,
                                     moonIlluminationFraction: 1.0,
                                     isDark: true)

        // Di bawah purnama yang masih di atas, mag 4.5 ditolak. Di bawah purnama
        // yang sudah terbenam, mag 4.5 harus lolos seperti langit benar-benar gelap.
        let limit = VisibilityFilter.effectiveLimitingMagnitude(context: setFullMoon,
                                                                policy: policy)
        XCTAssertEqual(limit, policy.limitingMagnitude,
                       "Bulan terbenam tidak boleh mengetatkan ambang magnitudo")

        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 4.5, separationFromSunDeg: 120,
            context: setFullMoon, policy: policy
        )
        XCTAssertEqual(result, .visible,
                       "bintang redup harus terlihat saat Bulan sudah terbenam")
    }

    /// `moonAltitudeDeg` yang `nil` (Bulan tak diketahui letaknya) juga tidak
    /// boleh mengetatkan — sejalan dengan prinsip "tidak tahu = jangan anggap
    /// lebih buruk" yang sudah dipakai untuk fraksi `nil`.
    func testUnknownMoonAltitudeDoesNotBrighten() {
        let unknown = SkyContext(sunAltitudeDeg: -40,
                                 moonIlluminationFraction: 1.0,
                                 isDark: true)
        XCTAssertNil(unknown.moonAltitudeDeg)
        XCTAssertEqual(VisibilityFilter.effectiveLimitingMagnitude(context: unknown,
                                                                    policy: policy),
                       policy.limitingMagnitude,
                       "altitude Bulan tak diketahui = jangan anggap langit lebih terang")
    }

    // MARK: - Batas senja

    func testDarknessBoundary() {
        XCTAssertTrue(VisibilityFilter.isDark(sunAltitudeDeg: -18, policy: policy))
        XCTAssertFalse(VisibilityFilter.isDark(sunAltitudeDeg: 0, policy: policy))
        XCTAssertFalse(VisibilityFilter.isDark(sunAltitudeDeg: -6, policy: policy),
                       "batas senja sipil: tepat di -6° belum dianggap gelap")
        XCTAssertTrue(VisibilityFilter.isDark(sunAltitudeDeg: -6.1, policy: policy))
    }

    func testPermissivePolicyRejectsNothing() {
        for altitude in [-90.0, -1.0, 0.0, 45.0] {
            for magnitude in [-26.0, 6.0, 20.0] {
                let result = VisibilityFilter.classify(
                    altitudeDeg: altitude, magnitude: magnitude,
                    separationFromSunDeg: 0, context: day,
                    policy: .permissive
                )
                XCTAssertEqual(result, .visible,
                               "kebijakan permissive tidak boleh menolak apa pun")
            }
        }
    }

    /// **Permisif berarti permisif, termasuk di bawah purnama.**
    ///
    /// Policy pengujian dipakai untuk menyaring kode yang tidak boleh menyentuh
    /// visibilitas. Kalau `permissive` masih membawa penyaringan cahaya Bulan,
    /// ia bukan permisif — dan uji "permissive membuang apa pun" tetap hijau,
    /// karena uji lamanya hanya memeriksa konteks tanpa Bulan.
    ///
    /// Benda yang dipakai di sini sengaja **redup**: magnitudo 20 lolos begitu
    /// saja kalau tidak ada penyaringan bulan, jadi uji ini hanya bisa hijau
    /// kalau `moonBrighteningMagnitudes` benar-benar nol.
    func testPermissivePolicyIgnoresMoonlight() {
        let moonlit = SkyContext(sunAltitudeDeg: -40,
                                moonAltitudeDeg: 30,
                                moonIlluminationFraction: 1.0,
                                isDark: true)
        let result = VisibilityFilter.classify(
            altitudeDeg: 45, magnitude: 20, separationFromSunDeg: 0,
            context: moonlit, policy: .permissive
        )
        XCTAssertEqual(result, .visible,
                       "policy permisif harus tetap meloloskan apa pun meski purnama")
        XCTAssertEqual(VisibilityPolicy.permissive.moonBrighteningMagnitudes, 0)
    }

    /// **Bulan yang tidak diketahui tidak boleh membuat langit lebih buruk dari
    /// asumsi terbaik.**
    ///
    /// Fraksi `nil` berarti "tidak diketahui", bukan "tidak ada". Kalau `nil`
    /// diperlakukan sebagai langit paling terang, engine akan membuang bintang
    /// dengan alasan yang tidak pernah terjadi — dan penolakan palsu itu tidak
    /// bisa dibedakan dari penolakan yang benar oleh pengguna.
    func testUnknownMoonKeepsTheBaseMagnitudeLimit() {
        let unknown = SkyContext(sunAltitudeDeg: -40, isDark: true)
        XCTAssertNil(unknown.moonIlluminationFraction)
        XCTAssertEqual(VisibilityFilter.effectiveLimitingMagnitude(context: unknown,
                                                                    policy: policy),
                       policy.limitingMagnitude,
                       "tidak diketahui berarti batas dasar, bukan batas yang lebih ketat")
    }

    /// Cahaya Bulan mengetat secara **monoton**, bukan melompat-lompat.
    ///
    /// Fraksi yang lebih besar tidak boleh pernah memberi batas magnitudo yang
    /// lebih longgar. Ini yang menjaga bentuk koreksinya: kelonggaran adalah
    /// bentuk kesalahan yang paling halus, karena arahnya tetap "mengetat" dan
    /// masih terlihat masuk akal.
    func testBrighterMoonNeverLoosensTheLimit() {
        var previous = Double.infinity
        for step in 0...10 {
            let fraction = Double(step) / 10
            let context = SkyContext(sunAltitudeDeg: -40,
                                    moonAltitudeDeg: 30,
                                    moonIlluminationFraction: fraction,
                                    isDark: true)
            let limit = VisibilityFilter.effectiveLimitingMagnitude(context: context,
                                                                     policy: policy)
            XCTAssertLessThanOrEqual(limit, previous,
                                     "fraksi \(fraction) memberi batas lebih longgar dari sebelumnya")
            previous = limit
        }
        XCTAssertLessThan(previous, policy.limitingMagnitude,
                          "purnama harus mengetat dari batas dasar")
    }
}

// MARK: - Benda tata surya

final class EphemerisBodyTests: XCTestCase {

    /// Matahari tidak boleh pernah menjadi target pointing.
    func testSunIsNotPointable() {
        XCTAssertFalse(EphemerisBody.sun.isPointable)
        XCTAssertFalse(EphemerisBody.pointableBodies.contains(.sun))
        XCTAssertEqual(EphemerisBody.pointableBodies.count, EphemerisBody.allCases.count - 1)
    }

    func testPointableBodiesAreAllPointable() {
        for body in EphemerisBody.pointableBodies {
            XCTAssertTrue(body.isPointable, "\(body) seharusnya bisa ditunjuk")
        }
    }
}
