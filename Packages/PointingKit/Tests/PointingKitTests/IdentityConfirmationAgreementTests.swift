import XCTest
import CelestialEngine
@testable import PointingKit

/// Dua jalur tampilan — layar utama (`PointingSnapshot.confirmsIdentity`) dan
/// complication (`ComplicationDigest.confirmsIdentityNow`) — harus **sepakat**
/// tentang kapan sebuah identitas boleh diklaim.
///
/// **Kenapa uji ini ada, terpisah dari `PointingPresentationTests`.** Kedua
/// predikat itu lahir dari dua fungsi berbeda: yang satu memakai
/// `state.looksConfident` (hanya `.lock`), yang lain memakai
/// `isConfirmed && !isStale(at:)` di atas sebuah cuplikan ber-timestamp. Sama
/// seperti `confirmsIdentity` vs `confirmsIdentityNow` di masa lalu, dua
/// rumus yang "sama secara intuisi" punya cara berbeda menangani batas, dan
/// complication adalah satu-satunya tempat `isStale(at:)` ikut dihitung.
///
/// Kalau suatu hari `ComplicationDigest` mulai membaca `hasAnswer` sebagai
/// ganti `isConfirmed` — atau `PointingSnapshot` mulai memotong umur — maka
/// complication akan menampilkan cincin Saturnus untuk kunci yang sudah
/// kedaluwarsa sementara layar utama tidak, **atau sebaliknya**. Pengguna
/// membaca complication tanpa membuka app, jadi persis di sanalah klaim palsu
/// paling tidak terlihat. Uji ini mengunci bahwa untuk *setiap* keadaan yang
/// memiliki jawaban, kedua jalur menghasilkan keputusan yang sama — dan bahwa
/// untuk `.uncertain` (kasus paling berisiko) keduanya **tolak** mengklaim
/// identitas, berapapun terang/besar kandidatnya.
final class IdentityConfirmationAgreementTests: XCTestCase {

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279, decDeg: 38, magnitude: 0.03)
    private let saturn = CelestialObject(id: "saturn", name: "Saturnus", kind: .planet,
                                         raDeg: 285, decDeg: -22, magnitude: 0.5)

    /// Fixture cuplikan berumur: complication menulis `updatedAt` saat ini,
    /// lalu kita periksa keputusannya "sekarang" (segar) dan "90 menit lagi"
    /// (basi).
    private func digest(for state: PointingState,
                        object: CelestialObject,
                        ageMinutes: Double = 0) -> ComplicationDigest {
        let snapshot = PointingSnapshot(
            state: state,
            intent: CelestialIntent(level: state == .lock ? .high : .medium,
                                   best: object, candidates: []))
        var digest = ComplicationDigest(snapshot: snapshot, lastLocked: nil)
        // `init(snapshot:lastLocked:)` men-stamp `updatedAt = Date()`; geser
        // mundur supaya `ageMinutes` dari sekarang jadi umur cuplikan.
        digest = ComplicationDigest(
            stateRaw: digest.stateRaw,
            objectName: digest.objectName,
            objectKindRaw: digest.objectKindRaw,
            isConfirmed: digest.isConfirmed,
            updatedAt: Date().addingTimeInterval(-ageMinutes * 60))
        return digest
    }

    /// Untuk `.uncertain` dengan kandidat terang dan terpisah jelas, kedua
    /// jalur harus **tolak** mengklaim identitas.
    ///
    /// Ini kasus paling berisiko: mata manusia "tahu" itu Saturnus (besar,
    /// jelas, di tengah kamera), tapi engine belum yakin. Kalau salah satu
    /// jalur memakai `hasAnswer` sebagai ambang, sabit/gambar Saturnus akan
    /// tampil penuh tanpa tanda tanya — false confidence persis yang dilarang
    /// PRD v0.4.
    func testUncertainWithBrightClearCandidateConfirmsOnNeitherPath() {
        let screen = PointingSnapshot(
            state: .uncertain,
            intent: CelestialIntent(level: .medium, best: saturn, candidates: []))
        XCTAssertFalse(screen.confirmsIdentity(lastLocked: nil),
                       "layar utama tidak boleh mengklaim identitas saat ragu")

        let complication = digest(for: .uncertain, object: saturn)
        XCTAssertFalse(complication.confirmsIdentityNow(at: Date()),
                       "complication tidak boleh mengklaim identitas saat ragu")
    }

    /// Keduanya **sepakat** untuk setiap keadaan berjawaban: `.lock` mengklaim,
    /// `.uncertain` tidak.
    ///
    /// Dijaga lewat objek terang (Saturnus) supaya tidak ada yang bisa
    /// menyalahkan keredupan kandidat — yang diuji murni keadaannya.
    func testScreenAndComplicationAgreeAcrossAnsweringStates() {
        for state in [PointingState.lock, .uncertain] {
            let screen = PointingSnapshot(
                state: state,
                intent: CelestialIntent(level: state == .lock ? .high : .medium,
                                       best: saturn, candidates: []))
            let complication = digest(for: state, object: saturn)

            let screenConfirms = screen.confirmsIdentity(lastLocked: nil)
            let complicationConfirms = complication.confirmsIdentityNow(at: Date())

            XCTAssertEqual(screenConfirms, complicationConfirms,
                           "\(state): layar (\(screenConfirms)) dan complication " +
                           "(\(complicationConfirms)) harus sepakat")
            if state == .lock {
                XCTAssertTrue(screenConfirms, ".lock harus mengklaim identitas di kedua jalur")
            } else {
                XCTAssertFalse(screenConfirms, ".uncertain tidak boleh di kedua jalur")
            }
        }
    }

    /// Komplikasi yang **basi** (90 menit lalu, jauh di atas ambang 15 menit)
    /// tidak boleh mengklaim identitas — walau `isConfirmed` mentahnya `true`.
    ///
    /// Ini bagian dari kontrak `confirmsIdentityNow(at:)`: umur cuplikan tidak
    /// boleh dibiarkan menyalahkan keadaan. Layar utama tidak punya pasangan
    /// ber-timestamp, tapi complication punya — dan inilah satu-satunya tempat
    /// batas 15 menit benar-benar dijalankan.
    func testStaleLockComplicationDoesNotConfirmIdentity() {
        let fresh = digest(for: .lock, object: saturn, ageMinutes: 0)
        XCTAssertTrue(fresh.confirmsIdentityNow(at: Date()),
                      "kunci segar boleh mengklaim identitas")

        let stale = digest(for: .lock, object: saturn, ageMinutes: 90)
        XCTAssertFalse(stale.confirmsIdentityNow(at: Date()),
                       "kunci kedaluwarsa (90 mnt) tidak boleh mengklaim identitas")
    }
}
