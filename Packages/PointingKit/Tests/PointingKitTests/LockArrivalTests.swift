import XCTest
import CelestialEngine
@testable import PointingKit

/// Kedatangan kunci baru — sinyal yang **boleh** dirayakan di layar.
///
/// UI yang merayakan "ada kunci" perlu tahu saat kunci itu benar-benar baru,
/// bukan sekadar sedang ada. Kalau aturannya ditulis di view, satu-satunya
/// hal yang bisa dibandingkan adalah `state == .lock`, dan itu gagal dengan
/// dua cara sekaligus: menyala ulang terus-menerus selama terkunci (layar
/// di-render 20 kali per detik), dan ikut merayakan **objek sisa**, karena
/// panel sengaja mempertahankan objek dari pandangan sebelumnya.
///
/// Yang boleh dirayakan hanya **perpindahan masuk** `.lock`, dan hanya dengan
/// objek yang berlaku **sekarang**. Sisanya bukan kabar baik.
final class LockArrivalTests: XCTestCase {

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279, decDeg: 38, magnitude: 0.03)
    private let sirius = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                         raDeg: 101.28715533, decDeg: -16.71611586,
                                         magnitude: -1.46)

    private func locked(_ object: CelestialObject) -> PointingSnapshot {
        PointingSnapshot(state: .lock,
                         intent: CelestialIntent(level: .high, best: object, candidates: []))
    }

    /// `intent` yang sengaja **dipertahankan** mesin keadaan — inilah bentuk
    /// yang pernah bocor ke layar dan ke iPhone.
    private func retainedIntent(_ object: CelestialObject) -> PointingSnapshot {
        PointingSnapshot(state: .pointing,
                         intent: CelestialIntent(level: .high, best: object, candidates: []))
    }

    // MARK: - Yang boleh merayakan

    /// Berthubung di `.lock` boleh **membawa arrival yang sama**, bukan
    /// arrival baru.
    ///
    /// Ini berbeda dari "hanya saat masuk lock" — dan selisihnya menentukan
    /// apakah animasi berkedip atau tidak. Kalau latch ikut dilepas tiap sampel,
    /// `nil` akan flowing 20 kali per detik dan view yang memakai
    /// `id(token)` akan sleepless. Yang penting: token **tidak pernah naik**
    /// tanpa perpindahan keadaan yang nyata.
    func testStayingLockedKeepsSameTokenWithoutNewArrival() {
        var gate = LockArrivalGate()

        let first = gate.update(with: locked(vega))
        XCTAssertNotNil(first, "perpindahan masuk lock")

        for _ in 0..<10 {
            let again = gate.update(with: locked(vega))
            XCTAssertEqual(again, first,
                           "berada di lock tidak boleh membuat arrival baru")
        }
        // Token tidak boleh naik: hanya perpindahan keadaan yang menaikkan.
        XCTAssertEqual(gate.update(with: locked(vega))?.token, 1)
    }

    func testNoArrivalForNonLockStates() {
        for state in [PointingState.idle, .pointing, .searching,
                      .uncertain, .unavailable] {
            var gate = LockArrivalGate()
            let snapshot = PointingSnapshot(
                state: state,
                intent: CelestialIntent(level: .high, best: vega, candidates: []))
            XCTAssertNil(gate.update(with: snapshot),
                         "\(state) tidak boleh punya arrival")
        }
    }

    /// Inti aturan PRD: **objek sisa tidak pernah dirayakan.**
    ///
    /// Keadaan sudah kembali `pointing`, tapi mesin keadaan sengaja
    /// mempertahankan `intent` supaya panel tidak berkedip — jadi isinya
    /// masih objek berkeputusan tinggi. Kalau "ada kunci" dibaca dari
    /// `intent` alih-alih dari keadaan, kasus ini akan merayakan jawaban
    /// yang sudah tidak berlaku.
    func testStaleRetainedIntentIsNeverAnArrival() {
        var gate = LockArrivalGate()
        let stale = retainedIntent(vega)
        XCTAssertNotNil(stale.bestObject, "intent lama memang masih menempel")
        XCTAssertNil(stale.answeredObject, "tapi bukan jawaban sekarang")
        XCTAssertNil(gate.update(with: stale),
                     "objek dari pandangan sebelumnya tidak boleh punya arrival")
    }

    /// Keadaan `lock` tanpa objek **tidak** merayakan apa pun.
    ///
    /// `.lock` tanpa `intent` bisa muncul pada sampel pertama setelah
    /// pemulihan sensor. Merayakannya berarti Memorial celebrating untuk
    /// benda yang tidak ada.
    func testLockWithoutAnswerDoesNotCelebrate() {
        var gate = LockArrivalGate()
        XCTAssertNil(gate.update(with: PointingSnapshot(state: .lock)),
                     "tanpa objek yang berlaku tidak ada yang dirayakan")
    }

    // MARK: - Token

    /// Mengunci ulang objek yang **sama** tetap kabar baru: pengguna sempat
    /// kehilangan kunci itu. Kalau keduanya membawa token yang sama, `.id()`-nya
    /// tidak berubah dan animasi kedua dilewati diam-diam.
    func testRelockingSameObjectGetsFreshToken() {
        var gate = LockArrivalGate()

        let first = gate.update(with: locked(sirius))
        XCTAssertNil(gate.update(with: PointingSnapshot(state: .pointing)))
        let second = gate.update(with: locked(sirius))

        XCTAssertEqual(first?.objectID, "sirius")
        XCTAssertEqual(second?.objectID, "sirius")
        XCTAssertNotEqual(first?.token, second?.token,
                          "kunci kedua harus punya token sendiri")
    }

    /// Token harus **monoton**, supaya SwiftUI bisa memakainya sebagai
    /// `.id()`. Nilai yang sama untuk dua waktu berbeda membuat animasi
    /// dilewati tanpa satu pun bagian UI yang kelihatan salah.
    func testTokenIsMonotonicAcrossDifferentObjects() {
        var gate = LockArrivalGate()
        let a = gate.update(with: locked(vega))
        _ = gate.update(with: PointingSnapshot(state: .pointing))
        let b = gate.update(with: locked(sirius))

        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertGreaterThan(b!.token, a!.token)
    }

    // MARK: - Keadaan yang datang di luar jalur sampel

    /// Keadaan juga berubah di luar `feed`: sensor mati, alur dihentikan,
    /// ambang diganti. Semua itu **tetap mengubah layar**, jadi gerbang
    /// harus melihatnya — kalau tidak, `previous` masih `.lock` ketika kunci
    /// berikutnya terjadi dan kedatangan kedua hilang diam-diam.
    ///
    /// Ini bukan kasus teoretis: `setSensorAvailable(false)` saat terkunci
    /// persis seperti itu, dan `PointingEngine` meneruskannya lewat jalur
    /// yang tidak lewat `ingest`.
    func testLockAfterSensorLossStillArrives() {
        var gate = LockArrivalGate()
        XCTAssertNotNil(gate.update(with: locked(vega)))
        // Keadaan `unavailable` melepas latch: tidak ada yang boleh dirayakan
        // lagi kalau answers sudah tidak berlaku.
        XCTAssertNil(gate.update(with: PointingSnapshot(state: .unavailable)))

        let after = gate.update(with: locked(vega))
        XCTAssertNotNil(after, "pulih dari sensor mati harus bisa mengunci lagi")
        XCTAssertNotEqual(after?.token, 1, "dan itu arrival yang baru")
    }

    /// `stop()` mengembalikan ke `idle`; sesudahnya kunci berikutnya harus
    /// tetap terasa sebagai kedatangan baru.
    func testLockAfterStopStillArrives() {
        var gate = LockArrivalGate()
        XCTAssertNotNil(gate.update(with: locked(vega)))
        XCTAssertNil(gate.update(with: PointingSnapshot(state: .idle)))
        XCTAssertNotNil(gate.update(with: locked(vega)))
    }

    /// Gerbang harus idempoten terhadap pemanggilan berulang dengan cuplikan
    /// yang sama persis: `PointingEngine` menulis `snapshot` di beberapa
    /// tempat, dan pemanggil boleh memanggilnya berulang tanpa perubahan.
    ///
    /// Kalau gerbang ikut "mengingat" cuplikan itu sendiri, setiap penulisan
    /// ulang akan terhitung sebagai kedatangan — dan layar akan berkedip
    /// setiap kali state diperbarui tanpa benar-benar berubah.
    func testRepeatedIdenticalSnapshotDoesNotManufactureArrivals() {
        var gate = LockArrivalGate()
        let snapshot = locked(vega)

        let first = gate.update(with: snapshot)
        XCTAssertNotNil(first)
        for _ in 0..<5 {
            XCTAssertEqual(gate.update(with: snapshot), first,
                           "cuplikan yang sama tidak boleh membuat arrival baru")
        }
    }

    /// Latch harus **dilepas** begitu keadaan berubah, supaya layar berhenti
    /// merayakan sesuatu yang sudah tidak berlaku.
    func testLatchIsReleasedWhenLockIsLost() {
        var gate = LockArrivalGate()
        XCTAssertNotNil(gate.update(with: locked(vega)))
        XCTAssertNil(gate.update(with: PointingSnapshot(state: .searching)),
                     "sisa latch tidak boleh membuat layar terus merayakan")
    }
}