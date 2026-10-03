import XCTest
@testable import CelestialEngine

#if canImport(AstronomyKit)

/// Validasi efemeris terhadap **JPL Horizons**.
///
/// Ini adalah uji paling penting di paket ini: PRD v0.4 melarang mengasumsikan
/// akurasi. Fixture `Fixtures/horizons_reference.json` diambil dari Horizons
/// (DE441) dan di-commit ke repo — jadi uji ini deterministik dan tidak
/// membutuhkan jaringan.
///
/// Ambang 10″ dipilih jauh di bawah resolusi pointing manusia (derajat) tapi
/// tetap cukup ketat untuk menangkap kesalahan kerangka acuan (mis. J2000
/// dipakai padahal seharusnya of-date: Bulan akan meleset ~0.4° = 1400″).
final class EphemerisTests: XCTestCase {

    /// Batas simpangan terhadap Horizons, detik busur.
    ///
    /// 30″ ≈ 0.008° — sekitar 100× lebih kecil dari resolusi pointing manusia,
    /// jadi tidak relevan secara produk. Tapi cukup ketat untuk menangkap
    /// kesalahan kerangka acuan: memakai J2000 untuk Bulan meleset ~1400″,
    /// dan salah satuan tinggi observer geosentris meleset ~2900″.
    ///
    /// Tidak dibuat lebih ketat dari ini karena AstronomyKit memakai matematika
    /// native platform dan tidak menjamin identik lintas arsitektur/toolchain;
    /// simpangan terburuk yang teramati adalah Saturnus ~9″.
    private static let toleranceArcsec = 30.0

    struct Reference: Decodable {
        struct Sample: Decodable {
            let body: String
            let utc: String
            let raDeg: Double
            let decDeg: Double
            let magnitude: Double
        }
        let samples: [Sample]
    }

    private func loadReference() throws -> Reference {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "horizons_reference",
                withExtension: "json",
                subdirectory: "Fixtures"
            ),
            "fixture Horizons tidak ditemukan di bundle"
        )
        return try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
    }

    private func date(fromISO iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try XCTUnwrap(formatter.date(from: iso), "tanggal ISO tidak valid: \(iso)")
    }

    private func body(from name: String) throws -> EphemerisBody {
        try XCTUnwrap(EphemerisBody(rawValue: name), "benda tak dikenal: \(name)")
    }

    /// Selisih sudut (detik busur) antara dua koordinat ekuatorial.
    /// RA dikalikan cos(dec) supaya tidak melebih-lebihkan dekat kutub.
    private func separationArcsec(ra1: Double, dec1: Double, ra2: Double, dec2: Double) -> Double {
        let dRA = SkyMath.normalizeDeg(ra1 - ra2)
        let wrapped = min(dRA, 360.0 - dRA)
        let dDec = dec1 - dec2
        let scaledRA = wrapped * cos(SkyMath.deg2rad(dec2))
        return (scaledRA * scaledRA + dDec * dDec).squareRoot() * 3600.0
    }

    func testEphemerisMatchesHorizonsWithinTolerance() throws {
        let reference = try loadReference()
        let ephemeris = AstronomyKitEphemeris()
        XCTAssertGreaterThanOrEqual(reference.samples.count, 15, "fixture terlalu kecil")

        var worst = (name: "", arcsec: 0.0)
        for sample in reference.samples {
            let ephemerisBody = try body(from: sample.body)
            let when = try date(fromISO: sample.utc)
            let actual = try ephemeris.apparent(ephemerisBody, at: when, from: nil)

            let error = separationArcsec(
                ra1: actual.raDeg, dec1: actual.decDeg,
                ra2: sample.raDeg, dec2: sample.decDeg
            )
            if error > worst.arcsec {
                worst = ("\(sample.body) @ \(sample.utc)", error)
            }
            XCTAssertLessThanOrEqual(
                error, Self.toleranceArcsec,
                String(format: "%@ @ %@: meleset %.2f″ dari Horizons (toleransi %.0f″)",
                       sample.body, sample.utc, error, Self.toleranceArcsec)
            )
        }
        print("simpangan terburuk vs Horizons: \(worst.name) = \(String(format: "%.2f", worst.arcsec))″")
    }

    /// Magnitudo harus berada di orde besaran yang benar. Ambang lebar karena
    /// Astronomy Engine memakai model magnitudo sederhana, bukan fotometri
    /// presisi; ini hanya penjaga agar tidak ada nilai yang kacau total.
    func testEphemerisMagnitudeIsPlausible() throws {
        let reference = try loadReference()
        let ephemeris = AstronomyKitEphemeris()

        for sample in reference.samples {
            let actual = try ephemeris.apparent(
                try body(from: sample.body),
                at: try date(fromISO: sample.utc),
                from: nil
            )
            XCTAssertLessThanOrEqual(
                abs(actual.magnitude - sample.magnitude), 0.6,
                "\(sample.body) @ \(sample.utc): magnitude \(actual.magnitude) vs Horizons \(sample.magnitude)"
            )
        }
    }

    /// Bulan harus punya radius sudut ~0.25°, planet nyaris titik.
    /// Dipakai nanti untuk memutuskan apakah pointing "di dalam piringan Bulan".
    func testMoonAngularRadiusIsAboutQuarterDegree() throws {
        let ephemeris = AstronomyKitEphemeris()
        let sample = try ephemeris.apparent(.moon, at: Date(timeIntervalSince1970: 1_704_067_200))
        XCTAssertEqual(sample.angularRadiusDeg, 0.26, accuracy: 0.03)
    }

    func testPlanetsHaveNegligibleAngularRadius() throws {
        let ephemeris = AstronomyKitEphemeris()
        let sample = try ephemeris.apparent(.jupiter, at: Date(timeIntervalSince1970: 1_704_067_200))
        XCTAssertLessThan(sample.angularRadiusDeg, 0.001)
    }

    /// Bulan bergerak cepat: 1 jam harus menggeser posisinya beberapa derajat
    /// (bukan beberapa menit busur). Ini uji kewarasan gerak, bukan akurasi.
    func testMoonMovesRoughlyHalfDegreePerHour() throws {
        let ephemeris = AstronomyKitEphemeris()
        let t0 = Date(timeIntervalSince1970: 1_704_067_200)
        let t1 = t0.addingTimeInterval(3600)

        let a = try ephemeris.apparent(.moon, at: t0)
        let b = try ephemeris.apparent(.moon, at: t1)
        let moved = separationArcsec(ra1: a.raDeg, dec1: a.decDeg, ra2: b.raDeg, dec2: b.decDeg) / 3600.0

        XCTAssertGreaterThan(moved, 0.3, "Bulan seharusnya bergerak >0.3° per jam")
        XCTAssertLessThan(moved, 1.0, "Bulan seharusnya bergerak <1.0° per jam")
    }

    /// Efemeris tidak boleh memberi koordinat di luar rentang yang sah.
    func testCoordinatesAreInValidRange() throws {
        let ephemeris = AstronomyKitEphemeris()
        let when = Date(timeIntervalSince1970: 1_704_067_200)

        for body in EphemerisBody.allCases {
            let sample = try ephemeris.apparent(body, at: when, from: nil)
            XCTAssertTrue((0..<360).contains(sample.raDeg), "\(body) RA di luar 0..<360: \(sample.raDeg)")
            XCTAssertTrue((-90...90).contains(sample.decDeg), "\(body) Dec di luar -90...90: \(sample.decDeg)")
            XCTAssertTrue(sample.magnitude.isFinite, "\(body) magnitude bukan angka berhingga")
        }
    }
}

#endif
