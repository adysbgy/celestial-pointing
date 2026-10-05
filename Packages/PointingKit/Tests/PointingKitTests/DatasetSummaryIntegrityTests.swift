import XCTest
import CelestialEngine
@testable import PointingKit

/// `ExperimentDataset` menyimpan dua bentuk kebenaran yang sama: `trials`
/// (rekaman) dan `summary` (hasil hitungannya). Keduanya ikut di arsip JSON.
///
/// **Premis siklus ini.** `summary` dihitung sekali di `init`, lalu disimpan.
/// `trials` bisa berubah — bukan hanya lewat `record`/`reset` milik harness,
/// tapi karena `trials` adalah `public var` pada struct yang `Codable`:
/// peny[`Decode` JSON bisa memberi `trials` dan `summary`
/// yang **saling bertentangan**, dan tidak ada yang mempermasalahkan.
///
/// Yang membuatnya berbahaya: `summary` yang bertentangan **tidak akan
/// terlihat sebagai crash atau kesalahan. `safetyVerdict` membaca
/// `falseLockCount` — angka hasil hitungan yang menyimpang — sehingga vonis
/// keselamatan bisa keluar dari data yang tidak pernah dihitung.
final class DatasetSummaryIntegrityTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let resolver = PointingResolver(catalogue: Catalogue.brightStars,
                                            policy: .permissive)
    private let location = ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                                            label: "Bandung", source: "test",
                                            capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

    private func intent(level: ConfidenceLevel, object: CelestialObject) -> CelestialIntent {
        CelestialIntent(level: level, best: object, candidates: [])
    }

    private func star(_ id: String) -> CelestialObject {
        Catalogue.brightStars.first { $0.id == id }!
    }

    /// Arsip yang menyetel ulang `summary` sehingga menyatakan "nol false
    /// lock" sementara `trials`-nya berisi satu false lock. Setelah decode,
    /// keduanya harus tetap konsisten.
    ///
    /// **Kenapa JSON-nya dibentuk, bukan ditulis tangan.** Percobaan pertama
    /// menuliskan JSON literal dengan `trials: []` dan `falseLockCount: 0`,
    /// lalu ujinya **hijau** — karena kedua angka itu memang sudah cocok. Uji
    /// itu terbukti tidak menanggung beban sama sekali. Bentuk sekarang
    /// mutate arsip sungguhan, sehingga isinya benar-benar bertentangan.
    func testDecodedSummaryCannotContradictItsOwnTrials() throws {
        let h = ExperimentHarness(resolver: resolver, location: location)
        let t = resolver.horizontal(ofObjectID: "vega", observer: observer, date: date)!
        _ = h.record(targetObjectID: "vega",
                     rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg,
                                                  azimuthDeg: t.azimuthDeg),
                     calibratedPointing: nil,
                     intent: intent(level: .high, object: star("sirius")),
                     state: .lock,
                     angularRateDegPerSec: 0.1,
                     calibration: .none,
                     timestamp: date)

        // Prasyarat: arsip asli memang berisi false lock.
        let honest = try DatasetArchive.encode(h.dataset(calibration: .none,
                                                         confidenceSigmaDeg: 10,
                                                         aim: "view"))
        XCTAssertEqual(try DatasetArchive.decode(honest).summary.falseLockCount, 1)

        // Lalu ringkasannya dihapus: percobaan tetap ada, ringkasan bilang nol.
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: honest) as? [String: Any])
        object["summary"] = ["trialCount": 0,
                             "correctCount": 0,
                             "falseLockCount": 0,
                             "accuracy": NSNull(),
                             "medianRawPointingErrorDeg": NSNull(),
                             "p90RawPointingErrorDeg": NSNull()]
        let tampered = try JSONSerialization.data(withJSONObject: object)

        let decoded = try DatasetArchive.decode(tampered)
        XCTAssertEqual(decoded.falseLocks.count, 1, "prasyarat: rekaman tetap ada")
        XCTAssertEqual(decoded.summary.falseLockCount, decoded.falseLocks.count,
                       "ringkasan harus menyatakan jumlah yang sama dengan "
                       + "percobaan yang benar-benar ada di arsip")
    }

    /// Sebaliknya: arsip yang sudah konsisten harus tetap dibaca utuh,
    /// ringkasan dan hitungannya.
    ///
    /// Arah kedua ini penting. Perbaikan yang membuang `summary` dari arsip
    /// dan selalu menghitung ulang juga akan membuat uji pertama hijau, tapi
    /// ia menghapus satu sumber kebenaran dari berkas ekspor — dan berkas
    /// ekspor justru alat bukti yang dibawa keluar dari app.
    func testConsistentArchiveStillDecodesWithItsOwnSummary() throws {
        let h = ExperimentHarness(resolver: resolver, location: location)
        let t = resolver.horizontal(ofObjectID: "vega", observer: observer, date: date)!
        _ = h.record(targetObjectID: "vega",
                     rawPointing: HorizontalCoord(altitudeDeg: t.altitudeDeg,
                                                  azimuthDeg: t.azimuthDeg),
                     calibratedPointing: nil,
                     intent: intent(level: .high, object: star("sirius")),
                     state: .lock,
                     angularRateDegPerSec: 0.1,
                     calibration: .none,
                     timestamp: date)

        let decoded = try DatasetArchive.decode(
            try DatasetArchive.encode(h.dataset(calibration: .none,
                                                 confidenceSigmaDeg: 10,
                                                 aim: "view")))

        XCTAssertEqual(decoded.summary.trialCount, 1)
        XCTAssertEqual(decoded.summary.falseLockCount, 1)
        XCTAssertEqual(decoded.summary.falseLockCount, decoded.falseLocks.count)
    }
}
