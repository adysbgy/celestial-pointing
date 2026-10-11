import XCTest
import CelestialEngine
@testable import PointingKit

/// Kejujuran Experiment 1: target yang **tidak bisa jadi pengukuran** tidak
/// boleh dihitung sebagai bukti.
///
/// **Cacat yang ditutup berkas ini.** `ExperimentHarness.record` menghitung
/// kebenaran dari `resolver.horizontal(ofObjectID:)`, dan fungsi itu **tidak**
/// menyaring di bawah cakrawala. Satu-satunya penjaga ada di jalur kalibrasi
/// (`CalibrationSession.capture`, `CalibrationSession.swift:189`) dengan
/// alasan tertulis: target yang terbenam menghasilkan **sampel hantu** —
///
/// > "pengguna menunjuk ke langit kosong, dan offset kalibrasi terbalik tanpa
/// > terlihat."
///
/// Jalur Experiment 1 tidak punya penjaga itu, dan konsekuensinya lebih
/// serius daripada offset yang terbalik, karena di sini angkanya **memutus
/// keselamatan**.
///
/// Terukur (probe di Linux, fixture Bandung 6 Okt):
///
/// - 19 percobaan sah → `insufficientEvidence`
/// - +1 percobaan dengan target Polaris di **−6,18°** → **`passed`**
///
/// Jadi alat ukur yang ada untuk menguji hipotesis "apakah akurasi Watch
/// cukup" bisa dibuat **lulus** oleh satu rekaman yang tidak mungkin terjadi:
/// penguji menunjuk langit yang sudah kosong, sementara arah kebenarannya
/// menunjuk tempat yang tidak ada. Satu rekaman, satu vonis.
///
/// Dan jendelanya nyata, bukan teoretis: 15 dari 25 bintang katalog pernah
/// melewati pita "masih bisa dipilih tapi akan tenggelam" (5°–8°), dan Sirius
/// turun 0,2392°/menit — jadi dari 5,5° ke 5,0° hanya **2,1 menit**.
final class ExperimentGroundTruthHonestyTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let resolver = PointingResolver(catalogue: Catalogue.brightStars,
                                            policy: .permissive)
    private let location = ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                                            label: "Bandung", source: "test",
                                            capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

    private func harness() -> ExperimentHarness {
        ExperimentHarness(resolver: resolver, location: location)
    }

    private func star(_ id: String) -> CelestialObject {
        Catalogue.brightStars.first { $0.id == id }!
    }

    // MARK: - Prasyarat: fixture-nya benar-benar di bawah cakrawala

    /// Fixture tidak boleh dikarang: kalau Polaris ternyata di atas cakrawala,
    /// seluruh berkas ini lulus tanpa menguji apa pun.
    ///
    /// Nomor ini **diukur**, bukan diperkirakan: `polaris` alt = −6,18° pada
    /// fixture ini. Dikunci supaya penyuntingan katalog atau tanggal fixture
    /// membuat berkas ini merah alih-alih diam-diam kehilangan daya uji.
    func testTheFixtureIsActuallyBelowTheGeometricHorizon() throws {
        let alt = try XCTUnwrap(
            resolver.horizontal(ofObjectID: "polaris", observer: observer, date: date)
        ).altitudeDeg
        XCTAssertLessThan(alt, 0, "fixture harus di bawah cakrawala geometris")
        XCTAssertEqual(alt, -6.18, accuracy: 0.05,
                       "fixture bergeser: kalau ini berubah, diukur ulang")
    }

    // MARK: - Penolakan

    /// Target di bawah cakrawala **ditolak**, bukan dicatat.
    ///
    /// Yang direkam bukan pengukuran: yang ditunjuk langit kosong, sedangkan
    /// arah kebenarannya menunjuk tempat yang tidak ada.
    func testTargetBelowTheHorizonIsNotRecorded() throws {
        let h = harness()
        let truth = try XCTUnwrap(
            resolver.horizontal(ofObjectID: "polaris", observer: observer, date: date))

        let result = h.record(targetObjectID: "polaris",
                              rawPointing: truth,
                              calibratedPointing: nil,
                              intent: CelestialIntent(level: .high, best: star("polaris"),
                                                      candidates: []),
                              state: .lock,
                              angularRateDegPerSec: 0.1,
                              calibration: .none,
                              timestamp: date)

        XCTAssertNil(result, "target di bawah cakrawala bukan pengukuran")
        XCTAssertTrue(h.trials.isEmpty, "tidak boleh ada satu pun rekaman")
        XCTAssertEqual(h.summary.trialCount, 0)
    }

    /// Penolakan harus **menyebut sebabnya**.
    ///
    /// Tanpa ini, `ExperimentRecorder` menampilkan "arah tidak bisa
    /// dihitung" untuk target yang terbenam — kalimat yang benar untuk id
    /// yang tidak dikenal, tetapi mengarahkan pengguna mencari masalah
    /// perhitungan yang tidak ada. Yang sebenarnya terjadi adalah langit
    /// yang bergeser, dan IMS Con Platform yang perlu dipindai ulang.
    func testRefusalReportsTheHorizonAsTheReason() throws {
        let h = harness()
        let truth = try XCTUnwrap(
            resolver.horizontal(ofObjectID: "polaris", observer: observer, date: date))
        _ = h.record(targetObjectID: "polaris", rawPointing: truth,
                     calibratedPointing: nil,
                     intent: CelestialIntent(level: .high, best: star("polaris"), candidates: []),
                     state: .lock, angularRateDegPerSec: 0.1,
                     calibration: .none, timestamp: date)
        XCTAssertEqual(h.lastRefusal, .targetBelowHorizon)

        // Arah sebenarnya: `nil` untuk target yang tidak dikenal.
        _ = h.record(targetObjectID: "nebula-tidak-ada",
                     rawPointing: HorizontalCoord(altitudeDeg: 30, azimuthDeg: 90),
                     calibratedPointing: nil,
                     intent: CelestialIntent(level: .high, best: star("sirius"), candidates: []),
                     state: .lock, angularRateDegPerSec: 0.1,
                     calibration: .none, timestamp: date)
        XCTAssertEqual(h.lastRefusal, .targetUncomputable)
    }

    /// Penolakan **hanya** berlaku pada target terbenam. Tanpa arah ini,
    /// penjagaan bisa diselesaikan dengan membuang semua rekaman.
    func testTargetsAboveTheHorizonAreStillRecorded() throws {
        let h = harness()
        let t = try XCTUnwrap(resolver.horizontal(ofObjectID: "sirius",
                                                   observer: observer, date: date))
        XCTAssertGreaterThan(t.altitudeDeg, 0, "prasyarat: Sirius di atas cakrawala")

        let result = h.record(targetObjectID: "sirius", rawPointing: t,
                              calibratedPointing: nil,
                              intent: CelestialIntent(level: .high, best: star("sirius"),
                                                      candidates: []),
                              state: .lock, angularRateDegPerSec: 0.1,
                              calibration: .none, timestamp: date)
        XCTAssertNotNil(result, "target di atas cakrawala tetap pengukuran yang sah")
        XCTAssertEqual(h.trials.count, 1)
        XCTAssertNil(h.lastRefusal, "rekaman tersimpan berarti tidak ada penolakan")
    }

    // MARK: - Uji yang menjaga akibatnya, bukan hanya penolakannya

    /// **Inilah uji yang paling penting.** Penolakan satu rekaman saja tidak
    /// membuktikan apa pun tentang vonis; yang dijaga adalah bahwa
    /// `safetyVerdict` **tidak lagi bisa dibalik** oleh rekaman yang bukan
    /// pengukuran.
    ///
    /// Angka-angkanya diambil dari ambang yang sudah ada, bukan dipilih supaya
    /// ujinya enak. `minimumTrialsForSafetyClaim` = 20, jadi 19 percobaan
    /// sah **harus** menghasilkan `insufficientEvidence`. Kalau itu tidak
    /// berlaku, berkas ini menguji sesuatu yang tidak berlaku.
    func testASetBelowHorizonTrialCannotFlipTheSafetyVerdictToPassed() throws {
        let legitimate = Catalogue.brightStars.filter { object in
            guard let d = resolver.horizontal(ofObjectID: object.id,
                                               observer: observer, date: date) else { return false }
            return d.altitudeDeg > 5
        }
        // 18 bintang di atas gerbang engine (terukur) → 19 rekaman sah lewat
        // pengulangan. Ambangnya 20, jadi satu tekaman saja boleh membalikkan
        // vonis — itulah celahnya.
        XCTAssertGreaterThanOrEqual(legitimate.count, 2, "prasyarat fixture")

        let h = harness()
        let needed = ExperimentSummary.minimumTrialsForSafetyClaim - 1
        for i in 0..<needed {
            let object = legitimate[i % legitimate.count]
            let truth = try XCTUnwrap(resolver.horizontal(ofObjectID: object.id,
                                                            observer: observer, date: date))
            _ = h.record(targetObjectID: object.id,
                         rawPointing: HorizontalCoord(altitudeDeg: truth.altitudeDeg + 2,
                                                      azimuthDeg: truth.azimuthDeg),
                         calibratedPointing: nil,
                         intent: CelestialIntent(level: .high, best: object, candidates: []),
                         state: .lock, angularRateDegPerSec: 0.1,
                         calibration: .none,
                         timestamp: date.addingTimeInterval(Double(i)))
        }

        // Prasyarat yang harus benar sebelum apa pun diklaim: satu rekaman
        // kurang dari ambang = belum boleh menyimpulkan apa pun.
        XCTAssertEqual(h.summary.trialCount, needed)
        XCTAssertEqual(h.summary.safetyVerdict, .insufficientEvidence,
                       "prasyarat: sampel kurang dari ambang tidak boleh 'lulus'")

        // Sekarang ghost-nya: target terbenam, yang ditunjuk langit kosong.
        let ghostTruth = try XCTUnwrap(resolver.horizontal(ofObjectID: "polaris",
                                                            observer: observer, date: date))
        _ = h.record(targetObjectID: "polaris",
                     rawPointing: HorizontalCoord(altitudeDeg: 30,
                                                  azimuthDeg: ghostTruth.azimuthDeg),
                     calibratedPointing: nil,
                     intent: CelestialIntent(level: .high, best: star("polaris"), candidates: []),
                     state: .lock, angularRateDegPerSec: 0.1,
                     calibration: .none,
                     timestamp: date.addingTimeInterval(9_000))

        XCTAssertEqual(h.trials.count, needed,
                       "ghost tidak boleh menambah rekaman sama sekali")
        XCTAssertEqual(h.summary.trialCount, needed)
        XCTAssertFalse(h.summary.safetyVerdict.isPassedClaim,
                       "vonis 'lulus' tidak boleh bisa dibeli rekaman yang bukan pengukuran")
    }

    /// Jendelanya **nyata**, bukan teoretis — inilah yang membuat cacat ini
    /// bisa terjadi tanpa ada yang menyadarinya.
    ///
    /// Kalau tidak satu pun bintang pernah melewati "masih bisa dipilih tapi
    /// akan tenggelam", cacat di atas hanya bisa terjadi pada policy yang
    /// tidak pernah dipakai.
    func testTheSinkingWindowIsReachableForRealCatalogueStars() throws {
        let gate = VisibilityPolicy().minAltitudeDeg
        var starsInBand = 0

        for object in Catalogue.brightStars {
            var wasSelectable = false
            for minute in stride(from: 0.0, through: 360.0, by: 1.0) {
                let alt = try XCTUnwrap(resolver.horizontal(ofObjectID: object.id,
                                                              observer: observer,
                                                              date: date.addingTimeInterval(minute * 60))
                ).altitudeDeg
                // "Masih bisa dipilih": masih di atas ambang engine.
                if alt > gate { wasSelectable = true }
                // "Sudah tenggelam": di bawah **cakrawala geometris**, yang
                // sudah ditolak `record`.
                if wasSelectable && alt <= 0 { starsInBand += 1; break }
            }
        }
        XCTAssertGreaterThan(starsInBand, 0,
                             "bintang yang bisa dipilih lalu tenggelam harus ada")
    }
}