import XCTest
@testable import CelestialEngine

/// Uji reduksi presesi J2000 -> of-date.
///
/// Kenapa penting: katalog menyimpan koordinat J2000, sementara langit
/// bergeser ~0.3° pada 2026. Tanpa reduksi ini resolver bisa memilih bintang
/// yang salah — persis jenis "false confidence" yang dilarang PRD.
final class PrecessionTests: XCTestCase {

    private let sirius = EquatorialCoord(raDeg: 101.28715533, decDeg: -16.71611586)
    private let regulus = EquatorialCoord(raDeg: 152.09296202, decDeg: 11.96720878)

    private func jd(year: Double) -> Double {
        2451545.0 + (year - 2000.0) * 365.25
    }

    /// Presesi ke epoch J2000 sendiri harus tidak mengubah apa pun.
    func testPrecessionToJ2000IsIdentity() {
        let same = SkyMath.precessJ2000ToDate(sirius, jd: 2451545.0)
        XCTAssertEqual(same.raDeg, sirius.raDeg, accuracy: 1e-9)
        XCTAssertEqual(same.decDeg, sirius.decDeg, accuracy: 1e-9)
    }

    /// Presesi harus monoton: makin jauh dari J2000, makin besar pergeserannya.
    /// Menangkap salah tanda pada koefisien zeta/z/theta.
    func testPrecessionGrowsWithEpoch() {
        let shifts = [2000.0, 2025.0, 2050.0, 2100.0].map { year -> Double in
            SkyMath.angularSeparationDeg(sirius, SkyMath.precessJ2000ToDate(sirius, jd: jd(year: year)))
        }

        XCTAssertEqual(shifts[0], 0, accuracy: 1e-6, "J2000 harus nol")
        for index in 1..<shifts.count {
            XCTAssertGreaterThan(shifts[index], shifts[index - 1],
                                 "pergeseran presesi harus makin besar seiring waktu")
        }

        // Presesi ~50.3″/tahun di sepanjang ekliptika. Untuk Sirius
        // (dec ≈ −16.7°) sedikit di bawah itu: ~1.2°/abad.
        XCTAssertEqual(shifts[3], 1.2, accuracy: 0.2, "presesi Sirius 2100 seharusnya ~1.2°")
    }

    /// Pergi ke of-date lalu kembali ke J2000 harus mendarat di titik awal.
    /// Ini menguji bahwa `precessDateToJ2000` benar-benar invers, bukan
    /// kebetulan memanggil fungsi yang sama dua kali.
    func testPrecessionRoundTrip() {
        let epoch = jd(year: 2050)
        let ofDate = SkyMath.precessJ2000ToDate(regulus, jd: epoch)
        XCTAssertGreaterThan(SkyMath.angularSeparationDeg(regulus, ofDate), 0.6,
                             "2050 seharusnya bergeser > 0.6°")

        let back = SkyMath.precessDateToJ2000(ofDate, jd: epoch)
        XCTAssertEqual(back.raDeg, regulus.raDeg, accuracy: 1e-6)
        XCTAssertEqual(back.decDeg, regulus.decDeg, accuracy: 1e-6)
    }

    /// Presesi mengubah posisi, bukan sekadar membalik tandanya.
    /// Koordinat of-date harus benar-benar berbeda dari J2000 pada 2026.
    func testPrecessionActuallyMovesCoordinates() {
        let ofDate = SkyMath.precessJ2000ToDate(regulus, jd: jd(year: 2026))
        XCTAssertNotEqual(ofDate.raDeg, regulus.raDeg)
        XCTAssertGreaterThan(SkyMath.angularSeparationDeg(regulus, ofDate), 0.3,
                             "presesi 2026 seharusnya > 0.3°")
        XCTAssertLessThan(SkyMath.angularSeparationDeg(regulus, ofDate), 0.5,
                          "presesi 2026 seharusnya < 0.5°")
    }
}

#if canImport(AstronomyKit)
import AstronomyKit

/// Validasi silang: presesi buatan sendiri vs matriks rotasi AstronomyKit.
///
/// AstronomyKit memakai IAU 2006 (Capitaine) sedangkan `SkyMath` memakai
/// IAU 1976 (Lieske); selisihnya kecil (orde detik busur) tapi nyata. Toleransi
/// di bawah dipilih untuk menangkap kesalahan logika, bukan perbedaan model.
final class PrecessionReferenceTests: XCTestCase {

    func testPrecessionMatchesAstronomyKit() throws {
        let samples: [(String, Double, Double)] = [
            ("Sirius", 101.28715533, -16.71611586),
            ("Vega", 279.23473479, 38.78368896),
            ("Regulus", 152.09296202, 11.96720878),
            ("Antares", 247.35191542, -26.43200266),
            ("Deneb", 310.35797975, 45.28033815),
        ]
        let epochs: [(Int, Int, Int, Int, Int)] = [
            (2000, 1, 1, 12, 0),
            (2026, 6, 15, 12, 0),
            (2050, 1, 1, 0, 0),
        ]

        var worst = (label: "", arcsec: 0.0)
        for (year, month, day, hour, minute) in epochs {
            let time = AstroTime(year: year, month: month, day: day, hour: hour, minute: minute)
            let jd = SkyMath.julianDate(from: time.date)
            let rotation = try RotationMatrix.equatorialJ2000ToEquatorialOfDate(at: time)

            for (name, raDeg, decDeg) in samples {
                // Arahkan vektor satuan bintang lewat matriks AstronomyKit.
                let ra = SkyMath.deg2rad(raDeg)
                let dec = SkyMath.deg2rad(decDeg)
                let unit = Vector3D(
                    x: cos(dec) * cos(ra),
                    y: cos(dec) * sin(ra),
                    z: sin(dec),
                    time: time
                )
                let rotated = try unit.rotated(by: rotation)
                let expected = EquatorialCoord(
                    raDeg: SkyMath.normalizeDeg(SkyMath.rad2deg(atan2(rotated.y, rotated.x))),
                    decDeg: SkyMath.rad2deg(asin(max(-1.0, min(1.0, rotated.z))))
                )

                let actual = SkyMath.precessJ2000ToDate(
                    EquatorialCoord(raDeg: raDeg, decDeg: decDeg),
                    jd: jd
                )
                let error = SkyMath.angularSeparationDeg(actual, expected) * 3600.0

                if error > worst.arcsec {
                    worst = ("\(name) @ \(year)", error)
                }
                XCTAssertLessThan(
                    error, 30.0,
                    String(format: "%@ @ %d: presesi meleset %.2f″ dari AstronomyKit", name, year, error)
                )
            }
        }
        print("simpangan presesi terburuk vs AstronomyKit: \(worst.label) = \(String(format: "%.2f", worst.arcsec))″")
    }

    /// Validasi silang arah sebaliknya: of-date -> J2000 vs matriks invers
    /// AstronomyKit. Menguji `precessDateToJ2000` secara independen, bukan
    /// hanya lewat bolak-balik dengan fungsi kita sendiri.
    func testInversePrecessionMatchesAstronomyKit() throws {
        let samples: [(String, Double, Double)] = [
            ("Sirius", 101.28715533, -16.71611586),
            ("Vega", 279.23473479, 38.78368896),
            ("Regulus", 152.09296202, 11.96720878),
            ("Antares", 247.35191542, -26.43200266),
            ("Deneb", 310.35797975, 45.28033815),
        ]
        let time = AstroTime(year: 2050, month: 1, day: 1, hour: 0, minute: 0)
        let jd = SkyMath.julianDate(from: time.date)
        let rotation = try RotationMatrix.equatorialOfDateToEquatorialJ2000(at: time)

        var worst = (label: "", arcsec: 0.0)
        for (name, raDeg, decDeg) in samples {
            // Mulai dari koordinat of-date, bawa kembali ke J2000.
            let ofDate = SkyMath.precessJ2000ToDate(
                EquatorialCoord(raDeg: raDeg, decDeg: decDeg), jd: jd
            )

            let ra = SkyMath.deg2rad(ofDate.raDeg)
            let dec = SkyMath.deg2rad(ofDate.decDeg)
            let unit = Vector3D(
                x: cos(dec) * cos(ra),
                y: cos(dec) * sin(ra),
                z: sin(dec),
                time: time
            )
            let rotated = try unit.rotated(by: rotation)
            let expected = EquatorialCoord(
                raDeg: SkyMath.normalizeDeg(SkyMath.rad2deg(atan2(rotated.y, rotated.x))),
                decDeg: SkyMath.rad2deg(asin(max(-1.0, min(1.0, rotated.z))))
            )

            let actual = SkyMath.precessDateToJ2000(ofDate, jd: jd)
            let error = SkyMath.angularSeparationDeg(actual, expected) * 3600.0

            if error > worst.arcsec {
                worst = ("\(name)", error)
            }
            XCTAssertLessThan(
                error, 30.0,
                String(format: "%@: invers presesi meleset %.2f″ dari AstronomyKit", name, error)
            )
        }
        print("simpangan invers-presesi terburuk vs AstronomyKit: \(worst.label) = \(String(format: "%.2f", worst.arcsec))″")
    }
}

#endif
