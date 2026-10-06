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
