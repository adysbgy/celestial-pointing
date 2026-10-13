import XCTest
@testable import PointingKit
import CelestialEngine

/// Baris koordinat layar serah-terima teleskop.
///
/// **Kenapa uji ini ada.** Baris ini adalah satu-satunya tempat pengguna bisa
/// memeriksa **bentuk apa** yang benar-benar akan dikirim ke mount. Sebelum
/// dipindahkan ke `PointingKit`, ia dirakit di dalam `body` SwiftUI — lapisan
/// yang tidak bisa dijalankan di Linux, dan yang tidak digambar
/// `check-visuals.py`. Artinya satu-satunya yang menjaganya adalah mata orang
/// yang membaca kode. Uji ini memindahkan penjagaan itu ke tempat yang bisa
/// gagal.
final class TelescopeDisplayTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Format angka bergantung pada bahasa aktif yang disimpan di satu
        // proses; uji yang memasangnya bocor ke berkas lain bila tidak
        // dilepas. Sama seperti `NumberFormatTests`.
        NumberFormat.reset()
        TextLocalization.reset()
    }

    override func tearDown() {
        NumberFormat.reset()
        TextLocalization.reset()
        super.tearDown()
    }

    /// Mount ekuatorial menerima **RA/Dek**, dan barisnya menyebut keduanya.
    func testEquatorialTargetPrintsRightAscensionAndDeclination() {
        let target = MountTarget.equatorial(
            EquatorialCoord(raDeg: 101.2872, decDeg: -16.7161), frame: .j2000)
        let line = TelescopeDisplay.coordinateLine(for: target)
        XCTAssertTrue(line.contains("101,2872"), "RA hilang atau salah: \(line)")
        XCTAssertTrue(line.contains("−16,7161") || line.contains("-16,7161"),
                      "Deklinasi negatif harus ikut tandanya: \(line)")
    }

    /// Mount alt-az menerima **Alt/Az**, dan **tidak** boleh menyebut RA/Dek.
    ///
    /// Ini yang membedakan serah-terima yang benar dari yang salah: mount
    /// alt-az tidak bisa menerima koordinat ekuatorial, jadi baris yang masih
    /// mencetak RA di sini akan menyatakan sesuatu yang tidak akan dikirim.
    func testHorizontalTargetPrintsAltitudeAndAzimuthOnly() {
        let target = MountTarget.horizontal(
            HorizontalCoord(altitudeDeg: 73.2213, azimuthDeg: 127.1546))
        let line = TelescopeDisplay.coordinateLine(for: target)
        XCTAssertTrue(line.contains("73,2213"), "Alt hilang atau salah: \(line)")
        XCTAssertTrue(line.contains("127,1546"), "Az hilang atau salah: \(line)")
        XCTAssertFalse(line.contains("RA"), "Alt-az tidak boleh menyebut RA: \(line)")
    }

    /// Bentuknya dibaca dari **targetnya**, bukan dari kemampuan mount.
    ///
    /// Kalau `TelescopeBridge` memutuskan sumbu yang berbeda dari yang kita
    /// kira, yang tercetak harus tetap apa yang benar-benar akan dikirim —
    /// jadi fungsi ini tidak boleh punya jalan lain untuk memilih bentuk.
    func testShapeComesFromTheTargetNotTheMount() {
        let equatorial = TelescopeDisplay.coordinateLine(
            for: .equatorial(EquatorialCoord(raDeg: 10, decDeg: 20), frame: .j2000))
        let horizontal = TelescopeDisplay.coordinateLine(
            for: .horizontal(HorizontalCoord(altitudeDeg: 10, azimuthDeg: 20)))
        XCTAssertNotEqual(equatorial, horizontal,
                          "Dua bentuk target yang berbeda tidak boleh tercetak sama")
    }

    /// Barisnya **tidak** membawa sudut pergelangan.
    ///
    /// Aturan keras PRD: sudut pergelangan tidak pernah menjadi gerak motor.
    /// `MountTarget` tidak punya anggota untuk sudut pergelangan sama sekali —
    /// uji ini mengunci itu pada tingkat tampilan: tidak ada angka ketiga yang
    /// bisa menyelinap sebagai "arah tunjuk".
    func testLineCarriesExactlyTwoNumbers() {
        let line = TelescopeDisplay.coordinateLine(
            for: .horizontal(HorizontalCoord(altitudeDeg: 73.2213, azimuthDeg: 127.1546)))
        let numbers = line.split(whereSeparator: { !$0.isNumber && $0 != "," })
        XCTAssertEqual(numbers.count, 2,
                       "Baris target harus dua angka (dua sumbu), bukan lebih: \(line)")
    }
}
