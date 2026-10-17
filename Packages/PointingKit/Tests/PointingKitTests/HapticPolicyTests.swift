import XCTest
@testable import PointingKit

/// Menguji bahwa getaran **membedakan** yakin dari ragu.
///
/// Kenapa berkas ini ada.
///
/// `Apps/PointAndKnowWatch/Sources/HapticEngine.swift` memetakan peristiwa ke
/// pola `WKHapticType`. Pemetaan itu memutuskan satu hal yang PRD larang
/// dilanggar: "ragu" tidak boleh terasa seperti "berhasil". Getaran adalah
/// satu-satunya saluran yang tidak butuh mata saat jam diangkat — tepat
/// situasi produk ini — jadi pemetaan yang menyamakan keduanya menghapus
/// pembeda itu di saluran yang paling sering dipakai.
///
/// `Apps/` tidak pernah dibangun `swift-test.sh` di Linux. Diukur: mengganti
/// `case .uncertain: device.play(.retry)` menjadi `.success` **tetap hijau**
/// pada ke-46 aturan UI. Karena itu pemetaannya dipindah ke `HapticPolicy`
/// dan diuji di sini.
///
/// Uji-uji ini sengaja menuntut **kedua** arah: bahwa ragu berbeda dari
/// berhasil, *dan* bahwa peristiwa yang memang berbeda tidak semuanya
/// dikembalikan ke satu pola (yang akan membuat uji pertama lulus dengan
/// getaran yang seragam).
final class HapticPolicyTests: XCTestCase {

    /// **Inti cacatnya.** Ragu tidak boleh terasa seperti berhasil.
    func testUncertainDoesNotFeelLikeSuccess() {
        XCTAssertNotEqual(
            HapticPolicy.pattern(for: .uncertain),
            HapticPolicy.pattern(for: .lockSucceeded),
            "engine ragu terasa sama dengan engine yakin — pembeda satu-satunya "
            + "bagi pengguna yang tidak melihat layar hilang")
        XCTAssertTrue(HapticPolicy.feelDifferent(.lockSucceeded, .uncertain))
    }

    /// Arah positifnya: lock sukses memang punya pola, dan pola itu `.completed`.
    ///
    /// Tanpa ini, kebijakan yang mengembalikan `nil` untuk segalanya akan
    /// lulus uji di atas — dan tidak ada peristiwa yang bergetar sama sekali.
    func testLockSucceededMapsToCompleted() {
        XCTAssertEqual(HapticPolicy.pattern(for: .lockSucceeded), .completed)
    }

    /// Setiap peristiwa punya pola, dan tidak ada yang `nil`.
    ///
    /// `nil` hari ini berarti "tidak bergetar". Kalau suatu saat sebuah
    /// peristiwa menjadi `nil`, uji ini memerahkan dan memaksa keputusan itu
    /// ditulis — bukan terjadi diam-diam.
    func testEveryEventHasAPattern() {
        for event in HapticEvent.allTestCases {
            XCTAssertNotNil(HapticPolicy.pattern(for: event),
                            "\(event) tidak punya pola getaran")
        }
    }

    /// Pemetaannya **injektif** atas keempat peristiwa: tidak ada dua yang
    /// berbagi pola.
    ///
    /// Ini lebih kuat dari "ragu ≠ berhasil" dan sengaja begitu. Empat
    /// peristiwa ini adalah empat keadaan yang berbeda bagi pengguna; getaran
    /// yang sama untuk dua di antaranya berarti satu keadaan tidak bisa
    /// dikenali dari getaran. Kalau kelak ada peristiwa yang memang harus
    /// berbagi pola, uji ini yang harus diubah **dengan alasan tertulis** —
    /// bukan pemetaannya yang dilonggarkan diam-diam.
    func testAllFourEventsAreDistinguishable() {
        let events = HapticEvent.allTestCases
        for i in events.indices {
            for j in events.indices where j > i {
                XCTAssertNotEqual(
                    HapticPolicy.pattern(for: events[i]),
                    HapticPolicy.pattern(for: events[j]),
                    "\(events[i]) dan \(events[j]) bergetar sama — salah satunya "
                    + "tidak bisa dikenali dari getaran")
            }
        }
    }

    /// `feelDifferent` sepakat dengan `pattern` di seluruh pasangan.
    ///
    /// Dua jalur publik bisa menyimpang; uji ini menahannya.
    func testFeelDifferentAgreesWithPatternEverywhere() {
        let events = HapticEvent.allTestCases
        for a in events {
            for b in events {
                XCTAssertEqual(
                    HapticPolicy.feelDifferent(a, b),
                    HapticPolicy.pattern(for: a) != HapticPolicy.pattern(for: b),
                    "\(a)/\(b): feelDifferent tidak sepakat dengan pattern")
            }
        }
    }

    /// Daftar kasus uji harus memuat **setiap** kasus enum.
    ///
    /// `HapticEvent` bukan `CaseIterable`, jadi `allTestCases` ditulis tangan
    /// dan bisa ketinggalan kasus baru. Uji di atas hanya memeriksa apa yang
    /// ada di daftar itu; tanpa uji ini, kasus yang lupa didaftarkan tidak
    /// pernah diuji dan semuanya tetap hijau.
    ///
    /// Daftar acuan ditulis ulang di sini dengan sengaja — dua daftar yang
    /// harus sepakat lebih sulit lupa daripada satu daftar yang dipercaya.
    func testTheTestFixtureCoversEveryCase() {
        let expected: Set<String> = ["lockSucceeded", "uncertain",
                                     "sensorUnavailable", "returnedToIdle"]
        let actual = Set(HapticEvent.allTestCases.map(\.rawValue))
        XCTAssertEqual(actual, expected,
                       "allTestCases tidak lagi memuat setiap kasus HapticEvent")
    }
}
