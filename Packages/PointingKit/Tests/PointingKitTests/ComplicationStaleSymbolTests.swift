import XCTest
import CelestialEngine
@testable import PointingKit

/// Complication yang menampilkan **ikon** lock lama seolah masih hasil sekarang.
///
/// **Premis siklus ini.** `ComplicationDigest` sudah punya seluruh lapisan
/// basi: `isStale(at:)`, `confirmsIdentityNow(at:)`, dan
/// `sublineContent(at:)` yang mengembalikan `.staleMarker` (sudah teruji di
/// `ComplicationDigestStalenessTests`). Semuanya benar, dan semuanya diuji.
///
/// Tapi lapisan itu hanya menjangkau **satu** dari dua kanal yang dimiliki
/// complication. Kanal kedua adalah ikon, dan ikon dibaca lewat
/// `presentedSymbolName` — yang mengembalikan `state?.symbolName` **mentah**.
///
/// Kenapa itu bocor, secara konkret: cuplikan yang sudah basi masih punya
/// `stateRaw == "lock"`, jadi ikonnya tetap `checkmark.circle.fill`. Artinya
/// di `.accessoryCircular` — keluarga yang **tidak punya baris kedua** — yang
/// satu-satunya penanda adalah ikon dan nama; `.staleMarker` tidak pernah
/// dirender di sana. Pergelangan membaca:
/// centang hijau + "Sirius", persis seperti lock yang baru saja terjadi.
///
/// Yang membuat ini bertahan adalah bentuknya, bukan bug pemetaan:
/// `presentedSymbolName` punya dokumen yang panjang dan **benar** — ia
/// benar-benar memindahkan ikon "ikut keadaan" supaya `.uncertain` tak bisa
/// terbaca seperti `.lock`. Dokumen itu hanya berhenti satu kalimat sebelum
/// pertanyaan yang lebih besar: "keadaan **yang**?" `--text` belum pernah
/// ditanyakan, dan seluruh lapisan basi yang dibangun khusus untuk itu hanya
/// menyentuh kanal yang lebih mudah.
///
/// Satu kelas yang sama seperti `unanalyzableCount` dan `updatedAt`: nilai
/// dihitung, disimpan, lalu tidak dipakai untuk keputusan yang seharusnya ia
/// ambil.
final class ComplicationStaleSymbolTests: XCTestCase {

    private func digest(updatedMinutesAgo minutes: Double,
                        isConfirmed: Bool = true,
                        state: PointingState = .lock) -> ComplicationDigest {
        ComplicationDigest(stateRaw: state.rawValue,
                           objectName: "Sirius",
                           objectKindRaw: ObjectKind.star.rawValue,
                           isConfirmed: isConfirmed,
                           updatedAt: Date(timeIntervalSinceNow: -minutes * 60))
    }

    private func now() -> Date { Date() }

    // MARK: - Yang diuji

    /// Ikon basi **wajib berbeda** dari ikon lock segar.
    ///
    /// Ini uji inti siklus ini, dan ia menguji **perbedaan** — bukan nilai
    /// symbol tertentu — supaya perbaikan tidak bisa lolos hanya dengan
    /// mengganti `checkmark.circle.fill` ke symbol lain yang tetap berarti
    /// "berhasil". Yang dijaga adalah bentuk cacatnya: dua keadaan yang
    /// berbeda tampil sama persis.
    func testStaleDigestDoesNotPresentTheFreshLockSymbol() {
        let stale = digest(updatedMinutesAgo: 90)
        let fresh = digest(updatedMinutesAgo: 1)
        XCTAssertNotEqual(stale.presentedSymbolName(at: now()),
                          fresh.presentedSymbolName(at: now()),
                          "cuplikan basi tampil sama persis dengan lock yang baru")
    }

    /// Ikon basi tidak boleh accuses "berhasil".
    ///
    /// Dipisah dari uji di atas karena ia menjaga **arah**, bukan sekadar
    /// perbedaan: bentuk perbaikan yang salah adalah mengganti ikon dengan
    /// symbol lain yang tetap berbau sukses (`seal.fill`, `sparkles`). Perbedaan
    ///naik lolos, tapi penandanya tetap menipu. Yang dilarang di sini adalah
    /// lock yang masih terlihat seperti lock.
    func testStaleDigestNeverPresentsASuccessSymbol() {
        let freshLock = PointingState.lock.symbolName
        XCTAssertEqual(freshLock, "checkmark.circle.fill", "aslinya")
        XCTAssertNotEqual(digest(updatedMinutesAgo: 90).presentedSymbolName(at: now()),
                          freshLock,
                          "basi tetap memakai ikon lock")
    }

    // MARK: - Arah sebaliknya

    /// Lock segar **wajib** mempertahankan ikonnya.
    ///
    /// Tanpa ini, perbaikan yang berlebihan memperbaiki bug dengan mematikan
    /// semua lock — dan setiap uji di atas tetap hijau karena keduanya sama.
    /// Perbaikan harus bergerak hanya pada cuplikan yang sudah basi.
    func testFreshDigestKeepsItsFreshLockSymbol() {
        XCTAssertEqual(digest(updatedMinutesAgo: 1).presentedSymbolName(at: now()),
                       PointingState.lock.symbolName,
                       "lock yang baru saja terjadi harus tetap tampil sebagai lock")
    }

    /// Keadaan yang **tidak punya jawaban** tidak boleh ikut berubah oleh basi.
    ///
    /// `isStale` berlaku pada semua keadaan, bukan cuma yang punya jawaban.
    /// Kalau ikon ikut berubah untuk `searching`, yang baru terjadi adalah
    /// bug baru: "sedang mencari" memang tidak bisa basi, karena tidak ada
    /// nama yang bisa basi. Uji ini menjaga batasnya.
    func testStaleSearchingKeepsItsOwnSymbol() {
        let staleSearching = digest(updatedMinutesAgo: 90, state: .searching)
        XCTAssertFalse(staleSearching.hasAnswer, "tidak ada nama untuk basi")
        XCTAssertEqual(staleSearching.presentedSymbolName(at: now()),
                       PointingState.searching.symbolName,
                       "keadaan tanpa jawaban tidak boleh jadi 'basi'")
    }

    // MARK: - Bentuk tanpa waktu

    /// Bentuk tanpa waktu harus tetap ada dan tetap benar.
    ///
    /// `presentedSymbolName` tanpa parameter tetap dipakai pemanggil yang
    /// sedang menampilkan cuplikan itu. Menghapusnya akan memaksa setiap
    /// pemanggil memutuskan soal waktu, dan itu persis keputusan yang tidak
    /// boleh hidup di view. Versi tanpa waktu harus tetap == keadaan mentah.
    func testUnparameterisedSymbolFormStillReadsTheState() {
        let lock = digest(updatedMinutesAgo: 90)
        XCTAssertEqual(lock.presentedSymbolName, PointingState.lock.symbolName,
                       "bentuk tanpa waktu harus tetap membaca keadaan mentah")
    }

    /// Keadaan tak dikenal harus tetap punya ikon — jangan sampai `nil` jadi
    /// teks kosong di pergelangan.
    ///
    /// Kanal ikon adalah satu-satunya penanda pada `.accessoryCircular`;
    /// string kosong di sana membuat complication tampak rusak, bukan jujur.
    func testUnknownStateStillPresentsASymbol() {
        let unknown = ComplicationDigest(stateRaw: "entah",
                                         objectName: "Sirius",
                                         objectKindRaw: ObjectKind.star.rawValue,
                                         isConfirmed: true,
                                         updatedAt: now())
        XCTAssertFalse(unknown.presentedSymbolName(at: now()).isEmpty,
                       "keadaan tak dikenal tidak boleh menghapus ikon")
    }
}