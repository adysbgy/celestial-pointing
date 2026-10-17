import XCTest
import CelestialEngine
@testable import PointingKit

/// Visual yang menggambar **benda selain yang tertulis di sebelahnya**.
///
/// **Cacat yang dijaga di sini.** `PointingEngine.visualForDisplayedObject`
/// (di `Apps/`) merakit gambar dari `displayedObject` — tetapi tidak ada satu
/// pun gerbang yang membaca badannya. Terukur: mengganti
/// `guard let object = displayedObject` menjadi
/// `guard let object = lastLockedObject` membuat **seluruh 42 aturan UI
/// tetap hijau** (exit 0), karena Aturan 34/35/36 membaca *argumen pemanggil*
/// dan Aturan 42 hanya memeriksa penerusan satu-fakta yang namanya ada sebagai
/// anggota model — `visualForDisplayedObject` merakit banyak sumber, jadi ia
/// tidak masuk cakupan aturan itu.
///
/// Akibatnya bukan teoretis. Pada keadaan `.pointing`, `displayedObject`
/// mengembalikan `intent?.best` — objek dari arah tunjuk **sebelumnya** — dan
/// `lastLockedObject` bisa berisi benda yang sama sekali lain. Gambar yang
/// dihasilkan lalu milik `lastLockedObject` sementara nama, badge, dan baris
/// jenis di kartu milik `intent?.best`. Dua benda di satu kartu, dan yang
/// dibaca mata lebih dulu adalah gambarnya.
///
/// **Kenapa perbaikannya di `PointingKit`, bukan di `Apps/`.** Aturannya
/// dipindah ke sini sebagai fungsi murni (`visualForDisplayedObject`) supaya
/// bisa dieksekusi di Linux. Begitu ia bisa dieksekusi, ia bisa diuji — dan uji
/// di bawah ini gagal pada versi `lastLockedObject` tanpa memerlukan macOS.
final class VisualAssemblyTests: XCTestCase {

    // MARK: - Benda uji

    /// Planet luar: mengembalikan seluruh ciri pengenal (cincin Saturnus), jadi
    /// kalau visualnya salah benda, salahnya **terlihat**.
    private let saturn = CelestialObject(
        id: "saturn", name: "Saturnus", kind: .planet,
        raDeg: 340.0, decDeg: -10.0, magnitude: 0.6)

    /// Planet lain, supaya "benda lain" bukan jenis yang sama.
    private let jupiter = CelestialObject(
        id: "jupiter", name: "Jupiter", kind: .planet,
        raDeg: 40.0, decDeg: 15.0, magnitude: -2.2)

    private func intent(_ object: CelestialObject, level: ConfidenceLevel) -> CelestialIntent {
        CelestialIntent(level: level, best: object,
                        candidates: [Candidate(object: object, separationDeg: 0.5)])
    }

    // MARK: - Invarian

    /// Visual yang dikembalikan harus **selalu** milik objek yang ditampilkan,
    /// pada setiap kombinasi (keadaan × intent yang dipertahankan × kunci
    /// terakhir). Kombinasi itulah yang membuat cacat `lastLockedObject`
    /// bisa lolos: ia hanya salah pada baris yang `displayedObject == nil`
    /// atau `displayedObject != lastLockedObject`.
    func testVisualIsAlwaysForTheDisplayedObject() {
        let states: [PointingState] = [.idle, .pointing, .searching,
                                       .lock, .uncertain, .unavailable]
        // `nil` = mesin keadaan tidak membawa niat sama sekali.
        let intents: [CelestialIntent?] = [nil, intent(jupiter, level: .high)]
        // `nil` = belum pernah terkunci.
        let locks: [CelestialObject?] = [nil, saturn]

        var checked = 0
        for state in states {
            for held in intents {
                for locked in locks {
                    let snapshot = PointingSnapshot(state: state, intent: held)
                    let displayed = snapshot.displayedObject(lastLocked: locked)
                    let visual = snapshot.displayedVisual(lastLocked: locked)

                    if let displayed {
                        // Visual untuk galat identitas **wajib** memuat identitas
                        // objeknya. `nil` di sini bukan "tidak ada gambar":
                        // kartu akan menampilkan nama tanpa gambar, padahal
                        // sebelumnya gambar ada — dan selisih itu persis yang
                        // menjadikan `lastLockedObject` tampak masuk akal.
                        XCTAssertNotNil(visual,
                                        "\(state) intent=\(held?.best?.id ?? "-") "
                                        + "locked=\(locked?.id ?? "-"): "
                                        + "ada objek tampil (\(displayed.id)) tapi tidak ada visual")
                        XCTAssertEqual(identity(of: visual), identity(ofObject: displayed),
                                       "\(state) intent=\(held?.best?.id ?? "-") "
                                       + "locked=\(locked?.id ?? "-"): "
                                       + "visual menggambar \(identity(of: visual) ?? "-") "
                                       + "sementara kartu menampilkan \(displayed.id)")
                    } else {
                        XCTAssertNil(visual,
                                     "\(state) locked=\(locked?.id ?? "-"): tidak ada objek "
                                     + "yang ditampilkan, tapi visual menggambar "
                                     + "\(identity(of: visual) ?? "-")")
                    }
                    checked += 1
                }
            }
        }
        // Penjaga non-vakum: matriks kosong akan membuat seluruh perulangan di
        // atas lulus tanpa memeriksa apa pun.
        XCTAssertEqual(checked, states.count * intents.count * locks.count)
    }

    /// Identitas yang dinyatakan sebuah `CelestialVisual` tentang benda mana
    /// yang ia gambar.
    ///
    /// **Kenapa tidak ada satu properti `sourceObjectID`.** `CelestialVisual`
    /// menyimpan identitas dalam bentuk yang berbeda per jenis — `planet` untuk
    /// planet, `objectID` untuk bintang dan langit-dalam (dan **sengaja** `nil`
    /// untuk benda tata surya, lihat docstring-nya), `kind` selebihnya. Menambah
    /// satu properti baru khusus uji berarti menambah kanal identitas kedua yang
    /// bisa berbeda pendapat dengan tiga yang sudah ada. Yang dibaca di sini
    /// adalah kanal yang **sungguh dipakai view** saat menggambar.
    private func identity(of visual: CelestialVisual?) -> String? {
        guard let visual else { return nil }
        if let planet = visual.planet { return planet.rawValue }
        if let objectID = visual.objectID { return objectID }
        switch visual.kind {
        case .moon: return "moon"
        case .sun: return "sun"
        case .star: return "star"
        case .planet: return "planet?"
        case .deepSky: return "deepSky?"
        }
    }

    /// Identitas yang sama, dinyatakan oleh objek engine. Planet dipetakan lewat
    /// `Planet(objectID:)` — pemetaan yang **sama** dengan
    /// `CelestialVisual.init(object:)`, jadi perbandingan di atas tidak
    /// membandingkan dua tabel yang ditulis dua kali.
    private func identity(ofObject object: CelestialObject) -> String? {
        switch object.kind {
        case .planet:
            return CelestialVisual.Planet(objectID: object.id)?.rawValue
        case .moon: return "moon"
        case .sun: return "sun"
        case .star: return object.id
        case .deepSky: return object.id
        }
    }

    /// Kasus yang paling mudah lolos dari mata manusia, dan yang paling
    /// berbahaya: pergelangan bergerak setelah mengunci Saturnus, sehingga
    /// mesin keadaan menahan `intent` berisi **Jupiter** dari arah sebelumnya
    /// sementara `lastLockedObject` masih Saturnus.
    ///
    /// Yang benar: gambar Jupiter dengan badge "Ragu"/"sisa".
    /// Yang salah (dan hijau di seluruh 42 aturan): gambar **Saturnus** —
    /// cincinnya — di sebelah nama Jupiter.
    func testVisualFollowsTheShownObjectNotTheLastLock() {
        let snapshot = PointingSnapshot(state: .pointing,
                                        intent: intent(jupiter, level: .high))
        let visual = snapshot.displayedVisual(lastLocked: saturn)

        XCTAssertEqual(identity(of: visual), "jupiter",
                       "kartu menampilkan Jupiter; gambar cincin Saturnus di sebelahnya "
                       + "akan terbaca sebagai pengukuran sekarang")
        XCTAssertNotEqual(visual?.planet, .saturn)
    }

    /// Panjang cincin Saturnus tidak boleh muncul saat objeknya Jupiter — bukti
    /// bahwa yang dibandingkan bukan sekadar id, melainkan gambar yang
    /// benar-benar akan dirender.
    func testSaturnRingGeometryNeverReachesAJupiterCard() {
        let snapshot = PointingSnapshot(state: .pointing,
                                        intent: intent(jupiter, level: .high))
        let visual = snapshot.displayedVisual(lastLocked: saturn)
        XCTAssertEqual(visual?.planet, .jupiter)
    }

    /// Tanpa objek yang ditampilkan, tidak ada gambar — bukan gambar benda
    /// terakhir. Ini keadaan `idle`/`unavailable` setelah jam dipakai
    /// sebelumnya; gambar yang tinggal di layar akan terbaca sebagai temuan
    /// dari langit yang sudah tidak ditunjuk.
    func testNoDisplayedObjectMeansNoVisual() {
        for state in [PointingState.idle, .unavailable] {
            let snapshot = PointingSnapshot(state: state)
            XCTAssertNil(snapshot.displayedObject(lastLocked: saturn))
            XCTAssertNil(snapshot.displayedVisual(lastLocked: saturn))
        }
    }

    /// Bulan: fraksi, arah, dan sudutnya **hanya** diteruskan ke Bulan.
    /// Meneruskannya ke planet akan menggambar fase Bulan pada Saturnus, dan
    /// itu klaim bentuk yang tidak dimiliki benda itu.
    ///
    /// Diuji langsung pada `CelestialVisual(object:)` — kanal fakta, bukan
    /// kanal pemilihan objek. Pengambilan fakta fase dari `skyContext` hidup
    /// di `Apps/`, di mana Aturan 31 menelusuri tiap kabelnya sebagai nilai;
    /// yang dijaga di sini adalah **apa yang model lakukan** dengan fakta itu
    /// setelah ia diterimakan.
    func testMoonPhaseIsOnlyForwardedToTheMoon() {
        let moon = CelestialObject(id: "moon", name: "Bulan", kind: .moon,
                                   raDeg: 100.0, decDeg: 20.0, magnitude: -12.0)
        let moonVisual = CelestialVisual(object: moon,
                                         moonIlluminationFraction: 0.25,
                                         isWaxing: true,
                                         brightLimbAngleRadians: 1.1)
        XCTAssertEqual(moonVisual.illuminationFraction, 0.25)

        // Angka Bulan yang sama, ditawarkan kepada Saturnus.
        let saturnVisual = CelestialVisual(object: saturn,
                                          moonIlluminationFraction: 0.25,
                                          isWaxing: true,
                                          brightLimbAngleRadians: 1.1)
        XCTAssertNil(saturnVisual.planetPhaseFraction,
                     "fase Bulan tidak boleh menjadi fase planet luar")
        XCTAssertEqual(saturnVisual.planet, .saturn,
                       "cincin digambar karena ini Saturnus, bukan karena kebetulan")
    }
}
