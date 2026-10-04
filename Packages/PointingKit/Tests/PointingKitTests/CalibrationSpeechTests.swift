import XCTest
import CelestialEngine
@testable import PointingKit

/// Janji yang **diucapkan** untuk alur kalibrasi.
///
/// Alur kalibrasi adalah tempat di mana UI *tampak benar sambil berbohong*
/// paling mudah terjadi: tombol "Pakai" masih terlihat, kartu tahap masih
/// hijau, tapi boleh-tidaknya kalibrasi hanya ditentukan `isReady`. Kalau
/// VoiceOver membacakan label yang tidak ikut berubah, pengguna yang tidak
/// melihat layar diberi tahu "Pakai kalibrasi" untuk tombol yang **akan
/// ditolak**.
///
/// Semua keadaan di sini dibangun lewat alur sungguhan (`add`), bukan dengan
/// menyetel `phase` langsung: `phase` bersifat `private(set)` dan dihitung dari
/// sampel, jadi itulah satu-satunya cara mengujinya tanpa mengarang keadaan.
final class CalibrationSpeechTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let resolver = PointingResolver(catalogue: Catalogue.brightStars,
                                            policy: .permissive)

    /// Alur dengan tiga acuan yang **konsisten** → tahap `.ready`, siap dipakai.
    private func readyFlow() -> CalibrationFlow {
        var flow = CalibrationFlow()
        for id in ["sirius", "vega", "arcturus"] {
            flow.add(objectID: id,
                     measured: measured(id, yawError: 12.0),
                     resolver: resolver, observer: observer, date: date)
        }
        return flow
    }

    /// Alur dengan satu acuan saja → `.collecting`, belum boleh dipakai.
    private func collectingFlow() -> CalibrationFlow {
        var flow = CalibrationFlow()
        flow.add(objectID: "sirius",
                 measured: measured("sirius", yawError: 12.0),
                 resolver: resolver, observer: observer, date: date)
        return flow
    }

    private func truth(_ id: String) -> HorizontalCoord {
        resolver.horizontal(ofObjectID: id, observer: observer, date: date)!
    }

    private func measured(_ id: String, yawError: Double) -> HorizontalCoord {
        let t = truth(id)
        return HorizontalCoord(altitudeDeg: t.altitudeDeg,
                               azimuthDeg: SkyMath.normalizeDeg(t.azimuthDeg - yawError))
    }

    // MARK: - Label tombol "Pakai"

    /// Keadaan tombol **wajib** ikut diucapkan.
    ///
    /// Ini inti dari berkas ini: label yang sama untuk tombol hidup dan tombol
    /// mati berarti penolakan kalibrasi yang paling penting tidak pernah sampai
    /// ke pengguna VoiceOver.
    func testApplyButtonLabelDistinguishesReadyFromNotReady() {
        let notReady = collectingFlow().spokenApplyButtonLabel
        let ready = readyFlow().spokenApplyButtonLabel

        XCTAssertNotEqual(notReady, ready,
                          "tombol yang ditolak dan yang dipakai harus terdengar berbeda")
        XCTAssertTrue(notReady.contains("belum bisa dipakai"), notReady)
        XCTAssertTrue(ready.contains("Pakai kalibrasi ini"), ready)
    }

    /// `.applied` juga sudah boleh dipakai — `isReady` mencakupnya.
    ///
    /// Kalau ini tidak dijaga, "sudah dipakai" akan terdengar seperti belum
    /// bisa dipakai: label menolak aksi yang sebenarnya valid.
    func testAppliedPhaseIsAlsoUsable() {
        var flow = readyFlow()
        flow.markApplied()

        XCTAssertEqual(flow.phase, .applied)
        XCTAssertTrue(flow.isReady, "tahap 'sudah dipakai' tetap boleh dipakai lagi")
        XCTAssertEqual(flow.spokenApplyButtonLabel, readyFlow().spokenApplyButtonLabel,
                       "tahap 'sudah dipakai' tidak boleh terdengar seperti belum bisa dipakai")
    }

    // MARK: - Ringkasan tahap

    /// Tahap harus ikut diucapkan, bukan cuma angkanya.
    func testPhaseSummaryNamesThePhase() {
        XCTAssertTrue(collectingFlow().spokenPhaseSummary.contains("Mengumpulkan acuan"),
                      collectingFlow().spokenPhaseSummary)
        XCTAssertTrue(readyFlow().spokenPhaseSummary.contains("Siap dipakai"))
        XCTAssertTrue(CalibrationFlow().spokenPhaseSummary.contains("Belum ada acuan"))
    }

    /// Sebaran harus menyebut **batasnya**, bukan hanya angkanya.
    ///
    /// Angka sebaran tanpa batasnya tidak bisa ditafsirkan: 2° lebar atau
    /// sempit bergantung pada ambang yang berlaku, dan ambang itulah yang
    /// menentukan boleh-tidaknya kalibrasi dipakai.
    func testSpreadSummaryIncludesItsLimit() {
        let summary = readyFlow().spokenPhaseSummary
        XCTAssertTrue(summary.contains("Sebaran"), summary)
        XCTAssertTrue(summary.contains("batas"),
                      "sebaran tanpa batas tidak bisa ditafsirkan: \(summary)")
    }

    /// Angka harus diucapkan dengan satuan, bukan simbol derajat.
    func testDegreesAreSpokenNotSymbolised() {
        let summary = readyFlow().spokenPhaseSummary
        XCTAssertFalse(summary.contains("°"),
                       "derajat adalah singkatan visual, bukan kata: \(summary)")
        XCTAssertTrue(summary.contains("derajat"), summary)
    }

    /// Tanpa kalibrasi (belum cukup sampel) ringkasan **tidak boleh** mengarang
    /// angka offset atau sebaran.
    func testSummaryWithoutCalibrationInventsNoNumbers() {
        let summary = CalibrationFlow().spokenPhaseSummary
        XCTAssertFalse(summary.contains("Offset"),
                       "tidak boleh mengarang offset yang belum dihitung: \(summary)")
        XCTAssertFalse(summary.contains("Sebaran"),
                       "tidak boleh mengarang sebaran yang belum dihitung: \(summary)")
        XCTAssertTrue(summary.contains("0 acuan tercatat"), summary)
    }

    /// Jumlah acuan diucapkan dengan angka yang benar.
    func testSampleCountIsSpokenCorrectly() {
        XCTAssertTrue(CalibrationFlow().spokenPhaseSummary.contains("0 acuan tercatat"))
        XCTAssertTrue(collectingFlow().spokenPhaseSummary.contains("1 acuan tercatat"))
        XCTAssertTrue(readyFlow().spokenPhaseSummary.contains("3 acuan tercatat"))
    }

    /// Setiap tahap punya nama yang bisa diucapkan dan berbeda.
    func testEveryPhaseHasDistinctSpokenName() {
        let phases: [CalibrationPhase] = [.idle, .collecting, .ready, .applied]
        let names = phases.map(\.spokenName)
        for name in names {
            XCTAssertFalse(name.isEmpty)
        }
        XCTAssertEqual(Set(names).count, phases.count, "nama tahap harus berbeda")
    }

    // MARK: - Tombol acuan

    /// Label acuan menyebut **aksinya**, bukan hanya nama bintang.
    ///
    /// Di layar ini ada tombol lain yang juga mencatat; tanpa kata kerjanya
    /// keduanya terdengar sama dan pengguna tidak tahu tombol mana yang mana.
    func testCaptureLabelNamesTheAction() {
        let target = PointingTarget(id: "sirius", name: "Sirius", kind: .star,
                                    magnitude: -1.46,
                                    direction: HorizontalCoord(altitudeDeg: 41.2, azimuthDeg: 120),
                                    isMoving: false)
        let label = target.spokenCaptureLabel
        XCTAssertTrue(label.hasPrefix("Catat Sirius sebagai acuan"), label)
        XCTAssertTrue(label.contains("41 derajat tinggi"), label)
        XCTAssertFalse(label.contains("°"), "satuan harus berupa kata: \(label)")
    }
}