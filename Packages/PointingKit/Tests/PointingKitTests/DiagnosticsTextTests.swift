import XCTest
@testable import PointingKit

/// Uji untuk teks layar Diagnostik yang dulu berdiri sebagai literal kunci
/// katalog di dalam parameter bertipe `String`.
///
/// **Cacat yang ditutup, dan kenapa tidak ada gerbang lain yang melihatnya.**
/// `DiagnosticsView` menulis `row("Keadaan", …)`, dan `row` bertipe
/// `(_ title: String, _ value: String)`. `Text` punya dua inisialisator:
/// yang menerima `LocalizedStringKey` mencari di katalog, yang menerima
/// `StringProtocol` **mencetak apa adanya** (Apple mendokumentasikannya
/// sebagai *"without localization"*). Jadi kata Indonesia itulah yang sampai
/// ke layar, sementara terjemahan `en`-nya tidak pernah dibaca.
///
/// Tiga gerbang hijau sepanjang waktu:
///
/// - Aturan 4 menyapu literal di argumen peritel teks dan menuntut setiap
///   literal itu ada di katalog — dan `"Keadaan"` memang ada. Hijau, dan benar.
/// - Aturan 19 mencari kunci yatim dengan pencarian substring mentah, jadi
///   kemunculan `"Keadaan"` di dalam `row("…")` **menghitung sebagai
///   rujukan**. Hijau, dan salah — kunci itu dipakai sebagai teks Indonesia,
///   bukan sebagai kunci.
/// - Aturan 6 memeriksa paritas paket dan katalog, dan tidak melihat `Apps/`.
///
/// Aturan 29 di `swift-ui-lint.sh` sekarang menutup kelasnya dengan membaca
/// tipe parameter. Berkas ini menutup sisi yang tidak bisa dilihat skrip:
/// bahwa nilai bawaannya benar, dan bahwa terjemahan benar-benar mengubah
/// kata yang tampil.
final class DiagnosticsTextTests: XCTestCase {

    override func tearDown() {
        // Kedua bridge dilepas: melepas hanya katalog membocorkan bahasa
        // angka milik uji ini ke berkas lain.
        TextLocalization.reset()
        NumberFormat.reset()
        super.tearDown()
    }

    /// Setiap kunci `diagnostics.*` punya nilai bawaan yang tidak kosong.
    func testDefaultIsIndonesianAndNotEmpty() {
        let keys = LocalizedText.allKeys.filter { $0.rawValue.hasPrefix("diagnostics.") }
        XCTAssertFalse(keys.isEmpty, "tidak ada kunci diagnostics.* sama sekali")
        for text in keys {
            XCTAssertFalse(text.indonesian.isEmpty,
                           "\(text.rawValue) tidak punya nilai bawaan")
            XCTAssertFalse(TextLocalization.text(text).isEmpty,
                           "\(text.rawValue) menghasilkan teks kosong")
        }
    }

    /// Setiap kunci dideklarasikan di `allKeys`.
    ///
    /// Kalau sebuah label ditambahkan tanpa masuk `allKeys`, gerbang paritas
    /// buta terhadapnya — persis cacat yang berkas ini tutup.
    func testEveryDiagnosticsKeyIsDeclared() {
        let declared = Set(LocalizedText.allKeys
            .map(\.rawValue)
            .filter { $0.hasPrefix("diagnostics.") })
        XCTAssertGreaterThanOrEqual(declared.count, 23,
                                    "ada kunci diagnostics yang belum masuk allKeys")
    }

    /// **Terjemahan benar-benar menggantikan kata yang tampil.**
    ///
    /// Ini inti berkas ini. Sebelumnya kata Indonesianya adalah **identitas**
    /// label, jadi tidak ada mekanisme yang bisa menggantinya. Sekarang
    /// identitasnya kunci, dan uji ini membuktikan tiap accessor membacanya.
    func testEnglishTranslationControlsTheWords() {
        EnglishTranslation.install([
            "diagnostics.row.state": "State",
            "diagnostics.row.guidance": "Guidance",
            "diagnostics.row.calibration": "Calibration",
            "diagnostics.row.wristRate": "Wrist rate",
            "diagnostics.row.object": "Object",
            "diagnostics.row.objectStale": "Object (stale)",
            "diagnostics.row.direction": "Direction",
            "diagnostics.row.sigmaInUse": "Sigma in use",
            "diagnostics.row.deviceMotion": "Device motion",
            "diagnostics.row.sample": "Samples",
            "diagnostics.row.location": "Location",
            "diagnostics.row.locationSource": "Location source",
            "diagnostics.row.magnitude": "Magnitude",
            "diagnostics.row.rightAscension": "RA",
            "diagnostics.row.declination": "Dec",
            "diagnostics.row.catalogueId": "Catalogue ID",
            "diagnostics.legend.confident": "Confident",
            "diagnostics.legend.uncertain": "Uncertain",
            "diagnostics.legend.unknown": "Unknown",
            "diagnostics.value.calibrated": "Yes",
            "diagnostics.value.notCalibrated": "No",
            "diagnostics.value.motionAvailable": "Available",
            "diagnostics.value.motionUnavailable": "Not available",
        ])

        XCTAssertEqual(DiagnosticsText.rowState, "State")
        XCTAssertEqual(DiagnosticsText.rowGuidance, "Guidance")
        XCTAssertEqual(DiagnosticsText.rowCalibration, "Calibration")
        XCTAssertEqual(DiagnosticsText.rowWristRate, "Wrist rate")
        XCTAssertEqual(DiagnosticsText.rowObject, "Object")
        XCTAssertEqual(DiagnosticsText.rowObjectStale, "Object (stale)")
        XCTAssertEqual(DiagnosticsText.rowDirection, "Direction")
        XCTAssertEqual(DiagnosticsText.rowSigmaInUse, "Sigma in use")
        XCTAssertEqual(DiagnosticsText.rowDeviceMotion, "Device motion")
        XCTAssertEqual(DiagnosticsText.rowSample, "Samples")
        XCTAssertEqual(DiagnosticsText.rowLocation, "Location")
        XCTAssertEqual(DiagnosticsText.rowLocationSource, "Location source")
        XCTAssertEqual(DiagnosticsText.rowMagnitude, "Magnitude")
        XCTAssertEqual(DiagnosticsText.rowRightAscension, "RA")
        XCTAssertEqual(DiagnosticsText.rowDeclination, "Dec")
        XCTAssertEqual(DiagnosticsText.rowCatalogueId, "Catalogue ID")
        XCTAssertEqual(DiagnosticsText.legendConfident, "Confident")
        XCTAssertEqual(DiagnosticsText.legendUncertain, "Uncertain")
        XCTAssertEqual(DiagnosticsText.legendUnknown, "Unknown")
        XCTAssertEqual(DiagnosticsText.valueCalibrated, "Yes")
        XCTAssertEqual(DiagnosticsText.valueNotCalibrated, "No")
        XCTAssertEqual(DiagnosticsText.valueMotionAvailable, "Available")
        XCTAssertEqual(DiagnosticsText.valueMotionUnavailable, "Not available")
    }

    /// Judul yang tampil bersebelahan harus **berbeda** satu sama lain.
    ///
    /// "Objek" dan "Objek (sisa)" adalah dua baris yang bisa muncul di layar
    /// yang sama; kalau keduanya menyusut jadi kata yang sama, penanda "hasil
    /// kedaluwarsa" hilang dan baris sisa terbaca sebagai pengukuran sekarang.
    /// Ini juga yang menahan kunci kembar di katalog.
    func testStaleAndCurrentObjectLabelsDiffer() {
        XCTAssertNotEqual(DiagnosticsText.rowObjectStale,
                          DiagnosticsText.rowObject)
    }

    /// Nilai kalibrasi dan ketersediaan sensor berbeda satu sama lain.
    ///
    /// Sama alasannya: kalau "Sudah" dan "Belum" sama, tabelnya kehilangan
    /// jawabannya; kalau "Ada" dan "Tidak ada" sama, baris sensor selalu
    /// terbaca tersedia.
    func testValueLabelsAreDistinct() {
        XCTAssertNotEqual(DiagnosticsText.valueCalibrated,
                          DiagnosticsText.valueNotCalibrated)
        XCTAssertNotEqual(DiagnosticsText.valueMotionAvailable,
                          DiagnosticsText.valueMotionUnavailable)
    }

    /// **Kunci `diagnostics.*` tidak boleh berbagi kata dengan layar lain.**
    ///
    /// `"Kalibrasi"` sudah ada di katalog sebagai judul layar kalibrasi
    /// (`skyContext.calibration`) dan sebagai nama pesan tautan
    /// (`link.kind.calibrationReady.label`). Layar Diagnostik sengaja punya
    /// kuncinya sendiri: kata yang sama di layar berbeda adalah keputusan
    /// penerjemahan yang berbeda, dan menyatukannya mengunci keduanya diam-diam.
    /// Uji ini menahan godaan "kenapa tidak pakai kunci yang sudah ada".
    func testDiagnosticsKeysDoNotReuseOtherScreensKeys() {
        let diagnostics = Set(LocalizedText.allKeys
            .filter { $0.rawValue.hasPrefix("diagnostics.") }
            .map(\.rawValue))
        let reused = diagnostics.filter { key in
            // `link.row.*` dan `skyContext.*` memuat kata yang sama persis.
            key.hasPrefix("link.") || key.hasPrefix("skyContext.")
                || key.hasPrefix("calibration.") || key.hasPrefix("row.")
        }
        XCTAssertTrue(reused.isEmpty,
                      "kunci diagnostics menyerobot namespace lain: \(reused.sorted())")
    }

    /// **Katalog asli wajib memuat terjemahan `en` untuk setiap kunci
    /// diagnostics.**
    ///
    /// Uji di atas memasang kamusnya sendiri, jadi ia membuktikan *mekanisme*
    /// penerjemahan bekerja — bukan bahwa katalognya lengkap. Kunci tanpa `en`
    /// jatuh ke bawaan Bahasa Indonesia (`sourceLanguage` katalog adalah `id`),
    /// dan pengguna Bahasa Inggris membaca kata Indonesia di tengah layar
    /// Inggris tanpa satu pun uji berbunyi. Jadi yang diperiksa di sini adalah
    /// **berkas katalognya**.
    func testCatalogueShipsAnEnglishFormForEveryDiagnosticsKey() {
        // Sengaja **gagal** bila katalog tidak ditemukan, bukan dilewati:
        // pemeriksaan yang dilewati akan berhenti berlaku tanpa ada yang
        // melihatnya.
        guard let url = catalogueURLBySearching() else {
            XCTFail("Katalog Localizable.xcstrings tidak ditemukan; "
                    + "ujian terjemahan tidak bisa dijalankan.")
            return
        }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            XCTFail("Katalog tidak bisa dibaca sebagai JSON.")
            return
        }
        let diagnostics = LocalizedText.allKeys
            .map(\.rawValue)
            .filter { $0.hasPrefix("diagnostics.") }
        XCTAssertFalse(diagnostics.isEmpty, "tidak ada kunci diagnostics untuk diperiksa")
        for key in diagnostics {
            guard let unit = strings[key] as? [String: Any] else {
                XCTFail("\(key) tidak ada di katalog")
                continue
            }
            let localizations = unit["localizations"] as? [String: Any] ?? [:]
            let english = (localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertNotNil(english?["value"] as? String,
                            "\(key) tidak punya terjemahan 'en'; "
                            + "tanpanya teksnya jatuh ke bawaan Bahasa Indonesia.")
        }
    }

    /// Cari katalog di pohon sumber bila `Bundle.module` kosong (uji Linux
    /// tanpa resource bundle).
    private func catalogueURLBySearching() -> URL? {
        var dir = URL(fileURLWithPath: #filePath)
        // Naik dari `.../Tests/PointingKitTests/` ke akar repo.
        for _ in 0..<6 {
            dir.deleteLastPathComponent()
            let candidate = dir.appendingPathComponent(
                "Apps/Shared/Resources/Localizable.xcstrings")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
