import XCTest
import CelestialEngine
@testable import PointingKit

/// Label VoiceOver layar redup (Always-On) harus menyebut **setiap** hal yang
/// tampil di layar itu.
///
/// **Cacat yang dijaga di sini.** `ReducedLuminanceView` menampilkan satu baris
/// catatan sensor (`motionNote`) saat gerak tidak tersedia — "Data gerak tidak
/// tersedia." — tetapi `reducedAccessibilityLabel` tidak pernah menyebutnya.
/// Akibatnya pembaca layar mendengar nama objek lalu status, tanpa satu pun
/// alasan mengapa jam tidak menanggapi gerakan. Bagi pengguna VoiceOver layar
/// itu terdengar seperti **keberhasilan yang membeku**, dan tidak ada satu
/// teks yang bisa dibacanya untuk membedakan.
///
/// Kelasnya sama persis dengan alasan `safetyWarningText` ikut diucapkan di
/// berkas yang sama: layar redup sengaja miskin, jadi setiap baris yang lolos
/// ke sana sudah melewati seleksi "tidak boleh terlewat" — dan yang terlewat
/// justru pembaca layarnya.
///
/// **Kenapa labelnya dirakit di PointingKit.** Bentuknya (urutan, pemisah,
/// kapan penanda ragu mendahului nama) adalah janji produk, dan `Apps/` tidak
/// dibangun di Linux — sehingga setiap cacat di sana hijau selamanya. Di sini
/// ia bisa dieksekusi, dan uji di bawah merah pada versi yang melewatkan
/// catatan sensor.
final class ReducedLuminanceLabelTests: XCTestCase {

    private let saturn = CelestialObject(
        id: "saturn", name: "Saturnus", kind: .planet,
        raDeg: 340.0, decDeg: -10.0, magnitude: 0.6)

    /// Hal yang tampil di layar redup selalu ikut diucapkan.
    ///
    /// Parameternya **lengkap**: setiap masukan yang mengubah satu baris di
    /// layar ada di sini, supaya uji tidak hijau hanya karena keadaan yang
    /// paling sering kebetulan tidak memuat baris yang lupa diucapkan.
    func testEveryLineOnTheDimScreenIsSpoken() {
        let note = SensorStatusText.motionUnavailable
        let label = ReducedLuminanceLabel.text(
            isUncertain: false,
            objectName: saturn.name,
            stateLabel: PointingState.lock.shortLabel,
            safetyWarning: nil,
            sensorNote: note,
            isStale: false)

        XCTAssertTrue(label.contains(note),
                      "catatan sensor tampil di layar redup tetapi tidak diucapkan: "
                      + "label = \(label)")
        XCTAssertTrue(label.contains(saturn.name))
        XCTAssertTrue(label.contains(PointingState.lock.shortLabel))
    }

    /// Tanpa catatan sensor, labelnya tidak boleh menyisipkan pemisah kosong
    /// atau kata yang tidak ada di layar.
    func testNoSensorNoteMeansNoExtraWords() {
        let label = ReducedLuminanceLabel.text(
            isUncertain: false,
            objectName: saturn.name,
            stateLabel: PointingState.lock.shortLabel,
            safetyWarning: nil,
            sensorNote: nil,
            isStale: false)
        XCTAssertEqual(label, [saturn.name,
                               PointingState.lock.shortLabel].joined(separator: ". "))
    }

    /// Penanda ragu **mendahului** nama: nama kandidat adalah kata yang paling
    /// mudah dibaca sebagai temuan, jadi syaratnya harus terdengar lebih dulu.
    func testUncertaintyMarkerComesBeforeTheName() {
        let label = ReducedLuminanceLabel.text(
            isUncertain: true,
            objectName: saturn.name,
            stateLabel: PointingState.uncertain.shortLabel,
            safetyWarning: nil,
            sensorNote: nil,
            isStale: false)
        let marker = TextLocalization.text(.confidenceUncertainMarker)
        guard let markerRange = label.range(of: marker),
              let nameRange = label.range(of: saturn.name) else {
            return XCTFail("penanda ragu atau nama tidak diucapkan: \(label)")
        }
        XCTAssertLessThan(markerRange.lowerBound, nameRange.lowerBound,
                          "penanda ragu harus terdengar sebelum nama: \(label)")
    }

    /// Saat tidak ada objek, tidak ada nama yang dikarang — dan penanda ragu
    /// tidak boleh muncul sendirian tanpa nama yang disyaratkannya.
    func testNoObjectMeansNoInventedName() {
        let label = ReducedLuminanceLabel.text(
            isUncertain: true,
            objectName: nil,
            stateLabel: PointingState.searching.shortLabel,
            safetyWarning: nil,
            sensorNote: SensorStatusText.motionUnavailable,
            isStale: false)
        XCTAssertEqual(label, [PointingState.searching.shortLabel,
                               SensorStatusText.motionUnavailable]
                        .joined(separator: ". "),
                       "tanpa objek, labelnya hanya status dan catatan sensor")
    }

    /// Urutan di layar dan urutan di telinga harus sama: peringatan keselamatan
    /// datang setelah status, dan sebutan sisa paling akhir.
    func testScreenOrderIsSpokenOrder() {
        let warning = "Matahari terlalu dekat — gerak dibatalkan."
        let label = ReducedLuminanceLabel.text(
            isUncertain: false,
            objectName: saturn.name,
            stateLabel: PointingState.lock.shortLabel,
            safetyWarning: warning,
            sensorNote: nil,
            isStale: true)
        let stateRange = label.range(of: PointingState.lock.shortLabel)
        let warningRange = label.range(of: warning)
        let staleRange = label.range(of: ObjectSpeech.staleShortNote)
        XCTAssertNotNil(stateRange)
        XCTAssertNotNil(warningRange)
        XCTAssertNotNil(staleRange)
        if let stateRange, let warningRange, let staleRange {
            XCTAssertLessThan(stateRange.lowerBound, warningRange.lowerBound)
            XCTAssertLessThan(warningRange.lowerBound, staleRange.lowerBound)
        }
    }
}
