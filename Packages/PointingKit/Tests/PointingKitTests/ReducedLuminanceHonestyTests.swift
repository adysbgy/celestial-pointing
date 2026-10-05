import XCTest
import CelestialEngine
@testable import PointingKit

/// Janji layar redup (Always-On): nama yang tampil **tidak boleh lebih yakin**
/// daripada yang sebenarnya.
///
/// **Premis siklus ini.** `ReducedLuminanceView` adalah layar yang paling
/// sering dibaca sekilas di app: hanya nama objek dan status, tanpa panel
/// peringatan, tanpa badge keyakinan, tanpa gambar. Di sinilah nama kandidat
/// (`.uncertain`) tampil sebagai **huruf terbesar di layar** dengan status
/// polos di bawahnya.
///
/// Perbandingan antarpermukaan yang membuat ini nyata. Empat permukaan dari
/// satu jawaban, tiga sudah jujur soal keraguan:
///
/// | Permukaan | Penanda ragu | Bentuk |
/// |---|---|---|
/// | complication | `Subline.uncertaintyMarker` | kata |
/// | jam (layar penuh) | badge keyakinan + gambar disamar | badge |
/// | iPhone | badge keyakinan + gambar disamar | badge |
/// | **layar redup** | **tidak ada** | **—** |
///
/// Yang membuatnya bertahan: di layar redup memang tidak ada ruang untuk
/// badge, jadi sedikit informasi yang hilang terasa wajar di sana. Dan
/// `shortLabel` memang berbeda dari `lock`, sehingga tidak ada layar yang
/// salah secara harfiah.
///
/// Tapi proporsi hierarkinya yang jadi masalah: nama kandidat memakai
/// `title2.bold()` -- huruf terbesar, tebal -- sementara label keadaan hanya
/// `.headline` tanpa penanda tambahan. Mata membaca nama lebih dulu dan lebih
/// besar, lalu membaca kata status yang tidak menempel pada nama itu. Hasilnya
/// kandidat tampil sebagai **temuan**, persis bentuk false confidence yang
/// PRD larang. Yang hilang bukan letter: yang hilang adalah hierarki.
///
/// Karena layar redup tidak punya ruang untuk badge, penandanya harus berupa
/// **frasa pendek yang menempel pada nama** -- bentuk yang sudah dipakai
/// complication (`confidence.uncertain.marker`).
final class ReducedLuminanceHonestyTests: XCTestCase {

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279, decDeg: 38, magnitude: 0.03)

    private func snapshot(state: PointingState,
                          best: CelestialObject?) -> PointingSnapshot {
        PointingSnapshot(state: state,
                         intent: CelestialIntent(level: state == .lock ? .high : .medium,
                                                 best: best,
                                                 candidates: []))
    }

    // MARK: - Penanda yang wajib ada pada kandidat

    /// **Regresi inti.** Kandidat `.uncertain` yang sedang ditampilkan
    /// **wajib** membawa penanda ragu di layar redup.
    ///
    /// Prasyaratnya ikut diuji karena tanpa itu, mutasi apa pun yang membuat
    /// nama tidak tampil sama sekali akan membuat pengujian ini tetap hijau:
    /// harus terbukti dulu bahwa kandidat memang tampil sebagai nama.
    func testUncertainCandidateMustCarryTheUncertaintyMarker() {
        let uncertain = snapshot(state: .uncertain, best: vega)

        XCTAssertEqual(uncertain.displayedObject(lastLocked: nil)?.id, "vega",
                       "kandidat harus tampil sebagai nama di layar redup")
        XCTAssertTrue(uncertain.carriesUncertaintyMarker(lastLocked: nil),
                      "nama yang ditampilkan adalah kandidat -- wajib ada penandanya")
    }

    /// Prasyarat yang sama diuji dari sisi yang berlawanan: `.uncertain`
    /// **bukan** objek sisa.
    ///
    /// Ini yang membedakan "ragu" dari "basi", dan tanpa itu penanda ragu
    /// bisa dipasang pada dua keadaan yang artinya berbeda. `hasAnswer`
    /// mencakup `.uncertain`, jadi `isDisplayingStaleObject` harus `false`.
    func testUncertainIsNotAStaleObject() {
        let uncertain = snapshot(state: .uncertain, best: vega)
        XCTAssertFalse(uncertain.isDisplayingStaleObject(lastLocked: nil))
        XCTAssertFalse(uncertain.confirmsIdentity(lastLocked: nil),
                       ".uncertain tidak boleh mengklaim identitas lewat gambar")
    }

    // MARK: - Arah sebaliknya (menjaga perbaikan yang terlalu=gurau)

    /// Nama yang **sudah terkunci** tidak boleh ikut diberi penanda ragu.
    ///
    /// Tanpa uji ini, perbaikan yang terlalu longgar (memberi penanda ke
    /// semua nama yang tampil) tetap hijau -- dan penanda yang selalu muncul
    /// bukan lagi penanda.
    func testALockedNameNeverCarriesTheUncertaintyMarker() {
        let locked = snapshot(state: .lock, best: vega)
        XCTAssertFalse(locked.carriesUncertaintyMarker(lastLocked: nil),
                       "nama yang sudah terkunci tampil tanpa catatan")
    }

    /// Keadaan tanpa jawaban **tidak boleh** memakai penanda ragu.
    ///
    /// Di `.pointing`, `displayedObject` mengembalikan `lastLocked`, jadi ada
    /// nama yang tampil dan `confirmsIdentity` sudah `false`. Kalau ambangnya
    /// `!confirmsIdentity`, objek **sisa** itu akan diberi penanda ragu --
    /// padahal yang perlu dinyatakan adalah "ini basi". Penanda ragu harus
    /// punya satu arti, dan uji ini menjaga itu.
    func testStaleObjectCarriesNoUncertaintyMarker() {
        let pointing = snapshot(state: .pointing, best: vega)
        XCTAssertEqual(pointing.displayedObject(lastLocked: vega)?.id, "vega",
                       "sisa dari pandangan sebelumnya memang masih tampil")
        XCTAssertTrue(pointing.isDisplayingStaleObject(lastLocked: vega))
        XCTAssertFalse(pointing.carriesUncertaintyMarker(lastLocked: vega),
                       "basi bukan ragu -- penandanya harus dibedakan")
    }

    /// Keadaan tanpa nama sama sekali tidak punya apa pun untuk ditandai.
    func testStatesWithoutAnAnswerCarryNoMarker() {
        for state in [PointingState.idle, .searching, .unavailable] {
            let s = snapshot(state: state, best: nil)
            XCTAssertFalse(s.carriesUncertaintyMarker(lastLocked: nil),
                           "\(state) tidak punya nama untuk ditandai")
        }
    }

    // MARK: - Bentuk frasa yang dipakai di layar

    /// Penandanya harus punya bentuk **pendek**: satu baris di layar redup
    /// hanya muat frasa, bukan kalimat.
    ///
    /// Bentuknya frasa, bukan kalimat -- dan itu yang diperiksa di sini,
    /// karena nama kandidat sudah memenuhi baris pertama dengan sendirinya.
    func testUncertaintyMarkerIsAPhraseNotASentence() {
        let marker = TextLocalization.text(.confidenceUncertainMarker)
        XCTAssertFalse(marker.isEmpty, "penanda ragu tidak boleh kosong")
        XCTAssertFalse(marker.contains("."),
                       "penanda layar redup itu frasa, bukan kalimat: \(marker)")
    }
}