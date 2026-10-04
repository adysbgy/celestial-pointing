import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji untuk kalimat pengumuman VoiceOver saat keadaan engine berubah.
///
/// **Kenapa ini diuji di Linux.** Kalimatnya dulu hidup sebagai literal di
/// dalam `PointingView` (app jam). Ia benar di sana — tetapi iPhone tidak
/// pernah mengumumkan apa pun, dan tidak ada satu pun gerbang yang bisa
/// melihatnya: aturan 4 menyapu literal `Apps/`, sedangkan ini teks yang
/// dihasilkan di paket, dan app iPhone hanya *tidak memanggil* apa pun.
///
/// Setelah dipindah ke `StateAnnouncement`, dua hal yang dulu tidak bisa
/// diperiksa menjadi bisa, dan keduanya di sini:
///
/// 1. **Satu kalimat untuk kedua app** — jam dan iPhone memanggil fungsi yang
///    sama, jadi keduanya tidak bisa menyebut hal berbeda untuk cuplikan yang
///    sama.
/// 2. **Kalimat itu punya kunci katalog** — `LocalizedText.allKeys` (dan
///    karena itu gerbang paritas Aturan 6) menjangkaunya, jadi pengguna Bahasa
///    Inggris tidak lagi mendengar kalimat Indonesia.
///
/// Yang **tidak** bisa diuji di sini: apakah VoiceOver benar-benar
/// mengucapkannya. Itu wilayah perangkat; yang diuji adalah kalimatnya dan
/// sumbernya.
final class StateAnnouncementTests: XCTestCase {

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279, decDeg: 38, magnitude: 0.03)

    private func locked(_ object: CelestialObject) -> PointingSnapshot {
        PointingSnapshot(state: .lock,
                         intent: CelestialIntent(level: .high, best: object,
                                                 candidates: []))
    }

    // MARK: - Kunci diumumkan dengan nama objeknya

    /// Terkunci **dengan** objek: nama objeknya ikut diucapkan.
    ///
    /// Ini satu-satunya momen yang ditunggu pengguna; mengumumkan "Terkunci"
    /// tanpa nama memaksanya mengusap layar untuk tahu terkunci pada apa.
    func testLockAnnouncesTheObjectName() {
        let text = StateAnnouncement.text(for: locked(vega))
        XCTAssertEqual(text, "Terkunci pada Vega.")
        XCTAssertTrue(text.contains("Vega"), "nama objek harus ikut diucapkan")
    }

    /// `.lock` **tanpa** objek tetap berbunyi, bukan diam.
    ///
    /// `.lock` tanpa `intent` bisa muncul pada sampel pertama setelah pemulihan
    /// sensor. Diam di sini terbaca sebagai "tidak ada kabar", padahal ada.
    func testLockWithoutObjectStillAnnounces() {
        let snapshot = PointingSnapshot(state: .lock)
        XCTAssertEqual(StateAnnouncement.text(for: snapshot), "Terkunci.")
    }

    /// Nama objek dibaca dari `answeredObject`, bukan `intent`.
    ///
    /// `intent` sengaja dipertahankan mesin keadaan saat kembali ke
    /// `.pointing`. Membacanya di sini akan mengumumkan objek lama persis
    /// seperti hasil pengukuran sekarang — false confidence dalam bentuk audio.
    func testRetainedIntentDoesNotLeakAnObjectName() {
        let snapshot = PointingSnapshot(
            state: .pointing,
            intent: CelestialIntent(level: .high, best: vega, candidates: []))
        let text = StateAnnouncement.text(for: snapshot)
        XCTAssertFalse(text.contains("Vega"),
                       "objek sisa tidak boleh diumumkan seolah hasil sekarang")
    }

    // MARK: - Keadaan lain tetap berbunyi

    /// Tiap keadaan punya kalimatnya sendiri, tidak ada yang kosong, dan tidak
    /// ada dua keadaan yang berbunyi sama persis.
    func testEveryStateHasItsOwnNonEmptyAnnouncement() {
        let states: [PointingState] = [.idle, .pointing, .searching,
                                       .uncertain, .unavailable]
        var seen: Set<String> = []
        for state in states {
            let snapshot = PointingSnapshot(state: state)
            let text = StateAnnouncement.text(for: snapshot)
            XCTAssertFalse(text.isEmpty, "\(state) tanpa pengumuman")
            XCTAssertFalse(text.contains("pointing.announce"),
                           "\(state): kunci katalog bocor ke layar/suara")
            XCTAssertTrue(seen.insert(text).inserted,
                          "\(state) berbunyi sama dengan keadaan lain")
        }
    }

    /// Ragu dan sensor mati menyebut **alasannya** (kalimat panduan yang sama
    /// dengan yang tampil di layar), supaya suara dan layar tidak menyimpang.
    func testUncertainAndUnavailableCarryTheGuidanceText() {
        for state in [PointingState.uncertain, .unavailable] {
            let snapshot = PointingSnapshot(state: state)
            let text = StateAnnouncement.text(for: snapshot)
            XCTAssertTrue(text.contains(snapshot.guidanceText),
                          "\(state): pengumuman harus memuat panduan yang sama "
                          + "dengan yang tampil di layar")
        }
    }

    /// Alasan jujur "mengapa tidak ada objek" ikut terdengar saat `.searching`.
    ///
    /// `guidanceText` — bukan `state.guidance` — yang membawa alasan dari
    /// engine. Tanpa ini, "Mencari" tidak pernah memberi tahu **kenapa**.
    func testSearchingAnnouncementCarriesTheSearchHint() {
        let snapshot = PointingSnapshot(state: .searching,
                                        searchHint: .daylight)
        let text = StateAnnouncement.text(for: snapshot)
        XCTAssertTrue(text.contains(SearchHint.daylight.message),
                      "alasan 'langit masih terang' harus ikut terdengar")
    }

    // MARK: - Kalimatnya ber-katalog

    /// Kelima kunci pengumuman ada di `allKeys`, jadi gerbang paritas
    /// (Aturan 6) memeriksanya terhadap `Localizable.xcstrings`.
    func testAnnouncementKeysAreDeclaredForTheCatalogParityGate() {
        let declared = Set(LocalizedText.allKeys.map(\.rawValue))
        for key in [LocalizedText.announceLockedOn,
                    .announceLocked,
                    .announceUncertain,
                    .announceUnavailable,
                    .announceState] {
            XCTAssertTrue(declared.contains(key.rawValue),
                          "\(key.rawValue) tidak ada di allKeys — gerbang "
                          + "paritas tidak akan melihatnya")
        }
    }

    /// Kalimat pengumuman memakai `%@`, bukan interpolasi Swift.
    ///
    /// Bagian yang disisipkan sudah diterjemahkan sendiri, jadi terjemahan
    /// Inggrisnya harus bisa menempatkannya sesuai tata bahasanya — dan itu
    /// tidak mungkin kalau posisinya dipaku di kode. Diuji dengan memasang
    /// terjemahan Inggris dan memastikan bagiannya benar-benar disisipkan.
    func testEnglishTranslationControlsWhereTheInsertedPartsGo() {
        TextLocalization.install { key in
            switch key {
            case "pointing.announce.lockedOn": return "Locked on %@."
            case "pointing.announce.uncertain": return "Not certain. %@"
            case "pointing.announce.unavailable": return "Sensor unavailable. %@"
            case "pointing.announce.state": return "%@. %@"
            case "pointing.announce.locked": return "Locked."
            default: return nil
            }
        }
        defer { TextLocalization.reset() }

        XCTAssertEqual(StateAnnouncement.text(for: locked(vega)),
                       "Locked on Vega.")
        let uncertain = PointingSnapshot(state: .uncertain)
        XCTAssertEqual(StateAnnouncement.text(for: uncertain),
                       "Not certain. \(uncertain.guidanceText)")
    }

    /// Tanpa katalog terpasang (Linux), kalimatnya tetap Bahasa Indonesia —
    /// dan tidak pernah kosong maupun nama kunci.
    func testDefaultsRemainIndonesianWithoutACatalog() {
        TextLocalization.reset()
        XCTAssertEqual(StateAnnouncement.text(for: locked(vega)),
                       "Terkunci pada Vega.")
        let idle = PointingSnapshot(state: .idle)
        XCTAssertEqual(StateAnnouncement.text(for: idle),
                       "\(idle.state.shortLabel). \(idle.guidanceText)")
    }
}
