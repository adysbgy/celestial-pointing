import XCTest
import CelestialEngine
@testable import PointingKit

/// Putusan GoTo — dari `SlewDecision` ke kalimat yang dibaca pengguna.
///
/// **Kenapa diuji.** `SlewPlanner` sudah menghitung putusan keselamatan sejak
/// FASE 3, dan `PointingController.slewDecision(date:)` menyambungkannya ke
/// engine — tetapi `slewDecision` nol pemanggil di seluruh `Apps/`. Aturan
/// keras PRD "POINT → OBJECT ID → SAFE GOTO" karena itu tidak punya wajah di
/// layar, dan penolakan karena `sunProximity` (melindungi alat & mata) terlihat
/// persis sama dengan penolakan karena `lowConfidence` (soal ketelitian).
///
/// Uji di sini menjaga dua hal: bahwa **alasan** setiap penolakan benar-benar
/// sampai ke kalimat, dan — yang lebih penting — bahwa **tidak ada** kalimat
/// saat GoTo aman. Yang terakhir itu penjaga anti-false-confidence: menuliskan
/// "ditolak" di sebelah GoTo yang justru berjalan adalah kebohongan yang sama
/// bentuknya dengan visual yang mengklaim identitas saat engine ragu.
///
/// **Kenapa perintah aman dibangun lewat perencana, bukan lewat
/// `SlewCommand(...)`.** `SlewCommand.init` sengaja `internal`: tipe itu hanya
/// boleh dibangun oleh perencana yang menjalankan pemeriksaan keselamatan, jadi
/// "perintah yang aman" tidak bisa dikarang dari luar modul. Membuka `init`-nya
/// demi kenyamanan uji akan melemahkan aturan keras PRD hanya supaya ujinya
/// lebih ringkas — uji yang mengalahkan aturan produk adalah uji yang salah.
/// Jalur di bawah justru menguji kontrak itu: perencana yang **sama** yang
/// memutuskan keamanan juga membangun perintahnya.
final class SlewVerdictTests: XCTestCase {

    // MARK: - Pembantu: putusan dibangun lewat perencana yang sebenarnya

    private func resolution(level: ConfidenceLevel,
                            best: CelestialObject?,
                            sun: HorizontalCoord?) -> Resolution {
        Resolution(
            intent: CelestialIntent(level: level, best: best, candidates: []),
            context: SkyContext(sunAltitudeDeg: -20),
            sunHorizontal: sun)
    }

    /// Matahari jauh di barat, target di timur — geometri yang aman.
    private let sun = HorizontalCoord(altitudeDeg: 30, azimuthDeg: 270)
    private let goodTarget = HorizontalCoord(altitudeDeg: 45, azimuthDeg: 90)

    private func allowedDecision(for object: CelestialObject) -> SlewDecision {
        SlewPlanner.plan(
            resolution: resolution(level: .high, best: object, sun: sun),
            targetHorizontal: goodTarget)
    }

    // MARK: - Aturan inti: tidak ada kalimat saat aman

    /// GoTo aman -> tidak ada kalimat. Sebuah putusan adalah penjelasan atas
    /// **masalah**; kalau ia bisa berbunyi saat aman, satu tempat yang lupa
    /// memeriksa akan menampilkan "ditolak" di sebelah GoTo yang berjalan.
    func testNoVerdictWhenAllowed() {
        let decision = allowedDecision(for: CelestialObject(
            id: "sirius", name: "Sirius", kind: .star,
            raDeg: 101.287, decDeg: -16.716, magnitude: -1.46))
        // Perencana dulu: tanpa ini uji bisa "lulus" karena putusannya kebetulan
        // ditolak, dan `verdictText` yang `nil` lalu bukan bukti apa pun.
        XCTAssertTrue(decision.isAllowed,
                      "rencana yang seharusnya aman justru ditolak: \(decision.hazards)")
        XCTAssertFalse(decision.hasVerdict)
        XCTAssertNil(decision.verdictText)
    }

    /// Ditolak -> ada kalimat, dan `hasVerdict` benar.
    func testVerdictAppearsWhenRejected() {
        let decision = SlewDecision.rejected(hazards: [.sunProximity])
        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.hasVerdict)
        XCTAssertNotNil(decision.verdictText)
    }

    // MARK: - Setiap bahaya punya kalimatnya sendiri

    /// Setiap bahaya punya kalimat yang berbeda dan tidak kosong. Dua sebab yang
    /// berbeda menuntut tindakan yang berbeda, jadi menyatukan kalimatnya
    /// menyembunyikan mana yang benar-benar menghalangi.
    func testEveryHazardHasItsOwnMessage() {
        let messages: [String] = SlewHazard.allCases.map(\.message)
        XCTAssertEqual(messages.count, Set(messages).count)
        XCTAssertFalse(messages.contains(where: { $0.isEmpty }))
    }

    /// Kalimat yang ditampilkan tidak boleh sama dengan kunci katalognya.
    func testMessagesAreNotRawKeys() {
        for hazard in SlewHazard.allCases {
            XCTAssertNotEqual(hazard.message, hazard.text.rawValue)
        }
    }

    /// Nama bahaya yang sensitif keselamatan harus menyebut Matahari secara
    /// eksplisit: `sunProximity` dan `sunPositionUnknown` melindungi peralatan
    /// dan mata, bukan sekadar soal ketelitian, dan pengguna berhak tahu
    /// mengapa teleskopnya menolak bergerak.
    func testSunHazardsMentionTheSun() {
        for hazard in [SlewHazard.sunProximity, .sunPositionUnknown] {
            XCTAssertTrue(hazard.message.lowercased().contains("matahari"),
                          "\(hazard) tidak menyebut Matahari: \(hazard.message)")
        }
    }

    // MARK: - Semua bahaya disebut, bukan hanya yang pertama

    /// Dua bahaya sekaligus -> keduanya muncul di kalimat. Menyebut salah
    /// satunya saja menyembunyikan sebab lain yang tetap menghalangi.
    func testAllHazardsAreMentioned() throws {
        let decision = SlewDecision.rejected(hazards: [.sunProximity, .lowConfidence])
        let text = try XCTUnwrap(decision.verdictText)
        XCTAssertTrue(text.contains(SlewHazard.sunProximity.message))
        XCTAssertTrue(text.contains(SlewHazard.lowConfidence.message))
    }

    /// Urutan bahaya dari perencana dipertahankan — kalimat mengikuti putusan,
    /// bukan mengurutkan ulang menurut seleranya sendiri.
    func testHazardOrderFollowsTheDecision() throws {
        let decision = SlewDecision.rejected(hazards: [.belowHorizon, .tooFaint])
        let text = try XCTUnwrap(decision.verdictText)
        let first = try XCTUnwrap(text.range(of: SlewHazard.belowHorizon.message))
        let second = try XCTUnwrap(text.range(of: SlewHazard.tooFaint.message))
        XCTAssertTrue(first.lowerBound < second.lowerBound)
    }

    /// Pembuka "ditolak" muncul sekali, bukan menempel di tiap bahaya.
    func testPrefixAppearsOnceAndOnlyWhenRejected() {
        let decision = SlewDecision.rejected(hazards: [.sunProximity, .tooFaint])
        let text = decision.verdictText ?? ""
        let prefix = LocalizedText.slewVerdictRejectedPrefix.indonesian
        let occurrences = text.components(separatedBy: prefix).count - 1
        XCTAssertEqual(occurrences, 1, "pembuka muncul \(occurrences)× — seharusnya sekali")
    }

    // MARK: - Penjaga: putusan tidak bisa dilunakkan

    /// Putusan yang ditolak **tidak pernah** punya `isAllowed` benar, dan
    /// putusan yang diizinkan tidak pernah punya bahaya. Ini mengunci kontrak
    /// yang dipakai `verdictText` untuk memutuskan apakah ada yang ditampilkan.
    func testRejectionAndAllowanceAreMutuallyExclusive() {
        let rejected = SlewDecision.rejected(hazards: [.noTarget])
        XCTAssertFalse(rejected.isAllowed)
        XCTAssertEqual(rejected.hazards, [.noTarget])
        XCTAssertNotNil(rejected.verdictText)

        let allowed = allowedDecision(for: CelestialObject(
            id: "m31", name: "Andromeda", kind: .deepSky,
            raDeg: 10.68, decDeg: 41.27, magnitude: 3.4))
        XCTAssertTrue(allowed.isAllowed)
        XCTAssertEqual(allowed.hazards, [])
        XCTAssertNil(allowed.verdictText)
    }

    // MARK: - Bobot visual: bahaya keselamatan ≠ sekadar mutu

    /// Setiap bahaya tergolong tepat satu kelas, dan klasifikasinya lengkap.
    ///
    /// Kalau sebuah `case` baru ditambahkan ke `SlewHazard` tapi lupa
    /// diklasifikasi, `switch` di `isSafety` berhenti meng-compile — itu
    /// pengaman yang benar. Uji ini menjaga sisi lain: bahwa hasilnya memang
    /// terbagi, bukan semuanya jatuh ke satu kelas karena kelalaian.
    func testSafetyClassificationCoversEveryHazard() {
        let safety = SlewHazard.allCases.filter(\.isSafety)
        let quality = SlewHazard.allCases.filter { !$0.isSafety }

        XCTAssertEqual(safety.count + quality.count, SlewHazard.allCases.count)
        XCTAssertFalse(safety.isEmpty, "tak ada satu pun bahaya keselamatan — klasifikasi salah")
        XCTAssertFalse(quality.isEmpty, "tak ada satu pun bahaya mutu — klasifikasi salah")

        // Ketiga bahaya yang melindungi alat & mata harus di kelas keselamatan.
        for hazard in [SlewHazard.sunProximity, .belowAltitudeLimit, .sunPositionUnknown] {
            XCTAssertTrue(hazard.isSafety, "\(hazard) seharusnya bahaya keselamatan")
        }
    }

    /// Bahaya keselamatan -> nada `danger`; bahaya mutu -> nada `warning`.
    ///
    /// Inilah pembeda yang dulu hilang: `SlewVerdictBanner` menggambar
    /// "terlalu dekat Matahari" dan "terlalu redup" dengan warna yang sama.
    func testSafetyHazardsAreDangerAndQualityHazardsAreWarning() {
        for hazard in SlewHazard.allCases {
            let decision = SlewDecision.rejected(hazards: [hazard])
            let expected: PointingTone = hazard.isSafety ? .danger : .warning
            XCTAssertEqual(decision.verdictTone, expected,
                           "\(hazard) memberi nada \(decision.verdictTone), seharusnya \(expected)")
        }
    }

    /// Campuran keselamatan + mutu -> keselamatan yang menang, **apa pun
    /// urutan array-nya**.
    ///
    /// Uji dua urutan, bukan satu: kalau `verdictTone` mengambil "bahaya
    /// pertama", ia akan lulus untuk satu urutan dan gagal untuk urutan lain —
    /// artinya warna bergantung pada urutan array, bukan pada bahaya yang
    /// paling serius.
    func testSafetyWinsOverQualityRegardlessOfOrder() {
        let safetyFirst = SlewDecision.rejected(hazards: [.sunProximity, .tooFaint])
        let qualityFirst = SlewDecision.rejected(hazards: [.tooFaint, .sunProximity])
        XCTAssertEqual(safetyFirst.verdictTone, .danger)
        XCTAssertEqual(qualityFirst.verdictTone, .danger)
    }

    /// Putusan aman -> nada `success`, dan **tidak** ada ikon peringatan.
    ///
    /// Menyalakan nada bahaya di sebelah GoTo yang justru berjalan adalah
    /// kebohongan yang sama bentuknya dengan visual yang mengklaim identitas
    /// saat engine ragu.
    func testAllowedDecisionIsSuccessTone() {
        let allowed = allowedDecision(for: CelestialObject(
            id: "vega", name: "Vega", kind: .star,
            raDeg: 279.234, decDeg: 38.784, magnitude: 0.03))
        XCTAssertTrue(allowed.isAllowed)
        XCTAssertEqual(allowed.verdictTone, .success)
        XCTAssertNil(allowed.verdictText)
    }

    /// `danger` dan `warning` memakai ikon yang **berbeda**.
    ///
    /// Di Mode Malam seluruh palet menyempit jadi satu merah, jadi warna tak
    /// lagi membedakan. Kalau ikonnya sama, pembeda terakhir ikut hilang tepat
    /// di mode yang paling sering dipakai saat mengamati langit.
    func testDangerAndWarningUseDifferentSymbols() {
        let danger = SlewDecision.rejected(hazards: [.sunProximity])
        let warning = SlewDecision.rejected(hazards: [.tooFaint])
        XCTAssertNotEqual(danger.verdictSymbolName, warning.verdictSymbolName)
        XCTAssertFalse(danger.verdictSymbolName.isEmpty)
        XCTAssertFalse(warning.verdictSymbolName.isEmpty)
    }

    // MARK: - Layar redup: hanya bahaya keselamatan yang lolos

    /// Bahaya keselamatan **tampil** di layar redup; bahaya mutu **tidak**.
    ///
    /// Layar Always-On hanya memuat yang tidak boleh terlewat. Kalau "terlalu
    /// dekat Matahari" hilang di sana, pengguna melihat nama objek terkunci
    /// tanpa satu pun tanda bahwa teleskop menolak bergerak.
    func testReducedScreenShowsSafetyHazardsOnly() {
        let safety = SlewDecision.rejected(hazards: [.sunProximity])
        XCTAssertNotNil(safety.safetyWarningText)
        XCTAssertEqual(safety.safetyWarningText, safety.verdictText,
                       "layar redup tidak boleh mengarang kalimat sendiri")

        let quality = SlewDecision.rejected(hazards: [.tooFaint])
        XCTAssertNil(quality.safetyWarningText)
    }

    /// Campuran keselamatan + mutu -> tetap tampil, karena keselamatan ada.
    func testReducedScreenShowsMixedRejectionBecauseOfSafety() {
        let mixed = SlewDecision.rejected(hazards: [.tooFaint, .sunProximity])
        XCTAssertNotNil(mixed.safetyWarningText)
    }

    /// GoTo aman -> tidak ada peringatan di layar redup, sama seperti di layar
    /// penuh.
    func testReducedScreenIsSilentWhenAllowed() {
        let allowed = allowedDecision(for: CelestialObject(
            id: "polaris", name: "Polaris", kind: .star,
            raDeg: 37.95, decDeg: 89.26, magnitude: 1.98))
        XCTAssertTrue(allowed.isAllowed)
        XCTAssertNil(allowed.safetyWarningText)
    }
}
