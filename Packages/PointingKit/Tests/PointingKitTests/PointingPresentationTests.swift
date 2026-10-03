import XCTest
import CelestialEngine
@testable import PointingKit

/// Janji tampilan: engine yang ragu harus **terlihat** ragu.
///
/// Seluruh aturan anti-false-lock di engine bisa dibatalkan oleh UI yang
/// memakai warna/ikon sama untuk `lock` dan `uncertain`. Uji ini menjaga jarak
/// itu tetap ada.
final class PointingPresentationTests: XCTestCase {

    func testEveryStateHasDistinctTone() {
        XCTAssertEqual(PointingState.idle.tone, .neutral)
        XCTAssertEqual(PointingState.pointing.tone, .active)
        XCTAssertEqual(PointingState.searching.tone, .active)
        XCTAssertEqual(PointingState.lock.tone, .success)
        XCTAssertEqual(PointingState.uncertain.tone, .warning)
        XCTAssertEqual(PointingState.unavailable.tone, .danger)
    }

    /// Inti janji PRD: ragu tidak boleh tampil seperti yakin.
    func testUncertainLooksDifferentFromLock() {
        XCTAssertNotEqual(PointingState.lock.tone, PointingState.uncertain.tone)
        XCTAssertNotEqual(PointingState.lock.symbolName, PointingState.uncertain.symbolName)
        XCTAssertNotEqual(PointingState.lock.shortLabel, PointingState.uncertain.shortLabel)
        XCTAssertNotEqual(PointingState.lock.guidance, PointingState.uncertain.guidance)
        XCTAssertFalse(PointingState.uncertain.looksConfident)
        XCTAssertTrue(PointingState.lock.looksConfident)
    }

    /// Setiap keadaan harus punya simbol yang bisa dirender.
    func testAllStatesHaveSymbolsAndLabels() {
        let states: [PointingState] = [.idle, .pointing, .searching, .lock, .uncertain, .unavailable]
        for state in states {
            XCTAssertFalse(state.symbolName.isEmpty, "\(state) tanpa simbol")
            XCTAssertFalse(state.shortLabel.isEmpty, "\(state) tanpa label")
            XCTAssertFalse(state.guidance.isEmpty, "\(state) tanpa panduan")
        }
        let symbols = Set(states.map(\.symbolName))
        XCTAssertEqual(symbols.count, states.count, "simbol antar-keadaan harus berbeda")
    }

    func testConfidenceLevelPresentation() {
        XCTAssertEqual(ConfidenceLevel.high.tone, .success)
        XCTAssertEqual(ConfidenceLevel.medium.tone, .warning)
        XCTAssertEqual(ConfidenceLevel.low.tone, .danger)
        XCTAssertNotEqual(ConfidenceLevel.high.tone, ConfidenceLevel.medium.tone)
        XCTAssertEqual(ConfidenceLevel.high.displayName, "Yakin")
        XCTAssertEqual(ConfidenceLevel.medium.displayName, "Ragu")
    }

    /// Snapshot membawa teks status yang cocok dengan keadaannya.
    func testSnapshotStatusTextMatchesState() {
        for state in [PointingState.idle, .pointing, .searching, .lock, .uncertain, .unavailable] {
            let snapshot = PointingSnapshot(state: state)
            XCTAssertEqual(snapshot.statusText, state.shortLabel)
        }
    }

    func testSnapshotExposesBestObject() {
        let object = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                     raDeg: 279, decDeg: 38, magnitude: 0.03)
        let snapshot = PointingSnapshot(state: .lock,
                                        intent: CelestialIntent(level: .high, best: object, candidates: []))
        XCTAssertEqual(snapshot.bestObject?.id, "vega")
        XCTAssertEqual(PointingSnapshot(state: .idle).bestObject, nil)
    }

    // MARK: - Objek sisa (anti false-confidence di layar)

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279, decDeg: 38, magnitude: 0.03)

    /// Objek dari pandangan sebelumnya tidak boleh tampil sebagai hasil
    /// sekarang.
    ///
    /// Mesin keadaan sengaja mempertahankan `intent` supaya panel tidak
    /// berkedip saat pergelangan bergerak sedikit. Akibatnya `intent?.best`
    /// **tetap terisi** saat keadaan sudah kembali `pointing`. Menilai "basi"
    /// dari `intent?.best == nil` karena itu salah: ia melaporkan "bukan sisa"
    /// tepat pada objek yang paling basi, dan peringatan di layar tidak pernah
    /// bisa muncul. Yang menentukan adalah apakah keadaan punya jawaban.
    func testStaleObjectIsFlaggedWhenStateHasNoAnswer() {
        // Keadaan sudah tidak punya jawaban, tapi intent lama masih menempel —
        // inilah bentuk yang dulu lolos.
        let stale = PointingSnapshot(state: .pointing,
                                     intent: CelestialIntent(level: .high, best: vega, candidates: []))
        XCTAssertNotNil(stale.displayedObject(lastLocked: nil))
        XCTAssertTrue(stale.isDisplayingStaleObject(lastLocked: nil),
                      "objek dari arah tunjuk sebelumnya harus ditandai sisa")

        // Keadaan benar-benar punya jawaban → bukan sisa.
        for state in [PointingState.lock, .uncertain] {
            let live = PointingSnapshot(state: state,
                                        intent: CelestialIntent(level: .high, best: vega, candidates: []))
            XCTAssertFalse(live.isDisplayingStaleObject(lastLocked: nil),
                           "\(state) adalah jawaban sekarang, bukan sisa")
        }
    }

    /// Objek terakhir yang pernah terkunci boleh tetap tampil saat mencari —
    /// tapi **harus** ditandai sisa.
    func testLastLockedObjectShownWhileSearchingIsStale() {
        let searching = PointingSnapshot(state: .searching)
        XCTAssertEqual(searching.displayedObject(lastLocked: vega)?.id, "vega")
        XCTAssertTrue(searching.isDisplayingStaleObject(lastLocked: vega))

        // Tanpa intent tertinggal, idle/unavailable tidak menampilkan apa pun.
        for state in [PointingState.idle, .unavailable] {
            let snapshot = PointingSnapshot(state: state)
            XCTAssertNil(snapshot.displayedObject(lastLocked: vega),
                         "\(state) tidak boleh menampilkan objek apa pun")
            XCTAssertFalse(snapshot.isDisplayingStaleObject(lastLocked: vega))
        }
    }

    /// Sensor mati di tengah pandangan menyisakan objek lama — dan itu **wajib**
    /// tetap ditandai sisa.
    ///
    /// `refreshSnapshot(state: .unavailable)` sengaja tidak membuang
    /// `currentIntent` (mesin keadaan hanya membuangnya saat `stop()`), jadi
    /// keadaan ini benar-benar bisa membawa objek dari pandangan sebelumnya —
    /// bukan sekadar kemungkinan teoretis. Menyembunyikan panelnya bukan
    /// pilihan (panel yang hilang lalu muncul lagi terbaca sebagai pengukuran
    /// baru); yang tidak boleh adalah menampilkannya **tanpa** penanda, dan
    /// badge keyakinannya ikut hilang karena keadaan ini tidak punya jawaban.
    func testUnavailableWithRetainedIntentStillFlagsItAsStale() {
        let stale = PointingSnapshot(state: .unavailable,
                                     intent: CelestialIntent(level: .high, best: vega, candidates: []))
        XCTAssertEqual(stale.displayedObject(lastLocked: nil)?.id, "vega")
        XCTAssertTrue(stale.isDisplayingStaleObject(lastLocked: nil),
                      "objek dari pandangan sebelumnya harus ditandai sisa")
        XCTAssertNil(stale.answeredObject, "sensor mati tidak punya jawaban sekarang")
        XCTAssertNil(stale.answeredLevel, "keyakinan lama tidak berlaku saat sensor mati")
    }

    /// Jawaban yang berlaku sekarang dipisahkan dari objek yang ditampilkan.
    ///
    /// Yang **ditampilkan** sengaja mempertahankan objek terakhir (layar jam
    /// menandainya sisa). Yang **berlaku** hanya saat keadaan punya jawaban —
    /// itu yang boleh dikirim ke iPhone dan direkam ke riwayat, karena di sana
    /// tidak ada penanda "sisa" yang bisa menyelamatkan.
    func testAnsweredPredicatesIgnoreRetainedIntent() {
        let retained = CelestialIntent(
            level: .high, best: vega,
            candidates: [Candidate(object: vega, separationDeg: 0.7)])
        let stale = PointingSnapshot(state: .pointing, intent: retained)

        XCTAssertEqual(stale.bestObject?.id, "vega", "tampilan tetap mempertahankannya")
        XCTAssertNil(stale.answeredObject, "tapi itu bukan jawaban sekarang")
        XCTAssertNil(stale.answeredLevel)
        XCTAssertNil(stale.answeredSeparationDeg)

        for state in [PointingState.lock, .uncertain] {
            let live = PointingSnapshot(state: state, intent: retained)
            XCTAssertEqual(live.answeredObject?.id, "vega")
            XCTAssertEqual(live.answeredLevel, .high)
            XCTAssertEqual(live.answeredSeparationDeg, 0.7)
        }
    }
}
