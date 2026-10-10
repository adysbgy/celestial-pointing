import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji untuk `ConfidenceChartSpeech` -- kalimat yang keluar dari grafik
/// keyakinan untuk VoiceOver.
///
/// Grafik confidence adalah **satu-satunya** `Chart` di app, dan sampai unit ini
/// ia tidak punya `.accessibilityLabel` sama sekali. Setiap elemen data lain di
/// `DiagnosticsView` punya pengumuman (lihat `RowSpeech` dan
/// `visualPanelLabel`), jadi ini bukan "grafik memang tidak bisa dibaca" --
/// ini satu-satunya tempat di layar itu yang diam.
///
/// Yang hilang bukan cuma angka. Yang hilang adalah **kesimpulan**: pembaca
/// layar bisa diberi "12 dari 14 sampel yakin" tapi tidak pernah diberi tahu
/// apakah ambangnya sedang dilanggar, dan itu justru yang membuat grafik ini
/// berguna saat lapangan.
///
/// Bentuknya kalimat, bukan daftar angka, karena yang ingin diketahui pembaca
/// layar adalah **pola**; pola itu dinyatakan lewat berapa sampel jatuh di
/// tiap pita ambang.
final class ConfidenceChartSpeechTests: XCTestCase {

    private let policy = ConfidencePolicy(pointingSigmaDeg: 10.0,
                                          ambiguitySigma: 2.0,
                                          maxSeparationSigma: 1.0)

    /// `ratios` mengembalikan opsional supaya view bisa membedakan "tidak ada
    /// yang bisa dikatakan". Di dalam uji yang memang sudah tahu ada isinya,
    /// memanggil `unwrap` supaya kegagalan uji menunjuk ke nilai yang salah,
    /// bukan ke optional yang belum dibuka.
    private func speech(_ ratios: [Double],
                        policy: ConfidencePolicy? = nil) -> ConfidenceChartSpeech {
        let speech = policy.map {
            ConfidenceChartSpeech.ratios(ratios, policy: $0)
        } ?? ConfidenceChartSpeech.ratios(ratios, policy: self.policy)
        return unwrap(speech)
    }

    /// Bawaan `file` sengaja `#file`, bukan `#filePath`: `XCTFail` di bawah
    /// memakai `#file` sebagai bawaannya, dan meneruskan `#filePath` ke
    /// parameter berdefault `#file` memicu peringatan compiler (dua bentuk
    /// lokasi yang berbeda). Menyamakannya menghilangkan peringatan **tanpa**
    /// membuang lokasi pemanggil dari laporan kegagalan.
    private func unwrap<Value>(_ value: Value?,
                               file: StaticString = #file,
                               line: UInt = #line) -> Value {
        guard let value else {
            XCTFail("diharapkan ada nilai, tapi dapat nil", file: file, line: line)
            // `XCTFail` masih melanjutkan: tanpa ini
            // kompilator tetap harus melihat jalur yang mengembalikan nilai.
            fatalError("nil diuji di atas", file: file, line: line)
        }
        return value
    }

    // MARK: - Pita ambang

    func testEverySampleLandsInExactlyOneBand() {
        // Batasnya sama dengan garis yang benar-benar tergambar di grafik:
        // `maxSeparationSigma` = 1.0 dan `ambiguitySigma` = 2.0.
        // 0.9 yakin, 1.4 di antara kedua garis, 3.2 di atas garis kedua.
        let summary = speech([0.9, 1.4, 3.2])
        XCTAssertEqual(summary.confident, 1)
        XCTAssertEqual(summary.middle, 1)
        XCTAssertEqual(summary.tooFar, 1)
        XCTAssertEqual(summary.total, 3)
        XCTAssertEqual(summary.confident + summary.middle + summary.tooFar, summary.total)
    }

    func testARatioExactlyOnTheFirstThresholdStillCountsAsConfident() {
        // `>` dan bukan `>=`. `maxSeparationSigma` adalah batas **tolak**, jadi
        // titik yang tepat di ambang masih diterima engine. Kalau ambang pita
        // di sini memakai `>=`, ringkasan suara dan engine akan berbeda pendapat
        // pada sampel yang persis sama -- dan selisihnya cuma satu sampel, jadi
        // tidak akan pernah terlihat mata.
        let summary = speech([1.0])
        XCTAssertEqual(summary.confident, 1)
        XCTAssertEqual(summary.middle, 0)
        XCTAssertEqual(summary.tooFar, 0)
    }

    func testTheSecondBandBoundaryIsTheLineActuallyDrawnOnTheChart() {
        // Grafik menggambar garis kedua di `ambiguitySigma`, jadi batas
        // pita tengah harus ke sana juga. Kalau tidak, penguji akan mendengar
        // "terlalu jauh" untuk titik yang jelas masih di bawah garis yang dia lihat.
        let summary = speech([2.0, 2.1])
        XCTAssertEqual(summary.middle, 1, summary.spokenSummary)
        XCTAssertEqual(summary.tooFar, 1, summary.spokenSummary)
    }

    func testASecondBoundaryBelowTheFirstIsNotUsedAsALowerBound() {
        // Kalibrasi bisa membuat `ambiguitySigma` lebih kecil dari
        // `maxSeparationSigma`. Kalau batas kedua diambil apa adanya, pita
        // akan tumpang tindih dan satu sampel bisa masuk dua pita -- sehingga
        // jumlah pita tidak lagi sama dengan jumlah sampel.
        let inverted = ConfidencePolicy(pointingSigmaDeg: 10.0,
                                        ambiguitySigma: 0.5,
                                        maxSeparationSigma: 1.0)
        let summary = speech([0.7, 1.5], policy: inverted)
        XCTAssertEqual(summary.confident + summary.middle + summary.tooFar, 2)
        XCTAssertEqual(summary.confident, 1)
        XCTAssertEqual(summary.tooFar, 1)
    }

    func testTheBandsFollowThePolicyActuallyInUse() {
        // Ambang yang lebih longgar harus menggeser titik ke pita lain. Kalau
        // tidak, penguji dengan kalibrasi longgar akan mendengar 3.2 sigma
        // masih dilaporkan "terlalu jauh", sementara engine menerimanya.
        let loose = ConfidencePolicy(pointingSigmaDeg: 10.0,
                                     ambiguitySigma: 20.0,
                                     maxSeparationSigma: 4.0)
        let summary = speech([3.2], policy: loose)
        XCTAssertEqual(summary.confident, 1, summary.spokenSummary)
        XCTAssertEqual(summary.tooFar, 0)
    }

    // MARK: - Sampel tanpa jarak terukur

    func testUnmeasuredSamplesAreNotSilentlyDroppedFromTheTotal() {
        // `ratioToSigma == nil` berarti jaraknya tidak terukur (sigma nol atau
        // tidak ada kandidat). Kurucut grafik memang tidak bisa menggambarnya,
        // tapi jumlahnya **tetap bagian** dari rekaman -- menghilangkannya
        // membuat "3 dari 5" terbaca seperti "3 dari 3".
        let summary = ConfidenceChartSpeech(samples: [1.0, 0.5, nil, 0.2], policy: policy)
        XCTAssertEqual(summary.total, 4, "sampel tanpa jarak ikut terhitung di total")
        XCTAssertEqual(summary.measured, 3)
        XCTAssertEqual(summary.unmeasured, 1)
        XCTAssertTrue(summary.spokenSummary.contains(
            TextLocalization.text(.chartSpeechUnmeasuredCount, 1)),
            summary.spokenSummary)
    }

    func testBandsCountOnlyMeasuredWhileTotalCountsEverySample() {
        let summary = ConfidenceChartSpeech(samples: [1.0, 0.5, nil], policy: policy)
        XCTAssertEqual(summary.confident, 2)
        XCTAssertEqual(summary.middle, 0)
        XCTAssertEqual(summary.tooFar, 0)
        XCTAssertEqual(summary.total, 3)
        XCTAssertEqual(summary.confident + summary.middle + summary.tooFar, summary.measured)
    }

    // MARK: - Bentuk kalimat

    func testEmptyTraceProducesNothingToSay() {
        // Tanpa sampel terukur tidak ada yang boleh diucapkan: kalimat kosong
        // lebih buruk daripada tidak ada pengumuman, karena pembaca layar akan
        // membacanya sebagai elemen yang sudah terbaca tapi tidak bermakna.
        XCTAssertNil(ConfidenceChartSpeech.ratios([], policy: policy))
    }

    func testTheSummaryNamesTheMeasuredCountAndEveryBand() {
        let summary = speech([0.2, 0.9, 1.4, 3.2])
        let spoken = summary.spokenSummary
        XCTAssertTrue(spoken.contains(
            TextLocalization.text(.chartSpeechMeasuredCount, 4)), spoken)
        // Ketiga pita disebut lengkap, bukan hanya yang tidak nol -- supaya
        // "tidak ada yang di antara dua batas" tetap terdengar.
        for part in [TextLocalization.text(.chartSpeechBandConfident, 2),
                     TextLocalization.text(.chartSpeechBandMiddle, 1),
                     TextLocalization.text(.chartSpeechBandTooFar, 1)] {
            XCTAssertTrue(spoken.contains(part), "bagian \(part) tidak muncul di: \(spoken)")
        }
    }

    func testEverySpokenPartComesFromTheCatalog() {
        // Aturan 13 menyapu `String(format:)` dan `append`; kalimat ini dirakit
        // dari beberapa bagian, jadi yang dijaga di sini adalah bahwa tidak
        // ada bagian yang lahir sebagai literal di dalam view.
        // Batas kedua = 2.0, jadi 2.5 masuk pita "terlalu jauh".
        let summary = ConfidenceChartSpeech(samples: [1.0, 0.5, nil, 2.5],
                                            policy: policy)
        let spoken = summary.spokenSummary
        for part in [TextLocalization.text(.chartSpeechMeasuredCount, 3),
                     TextLocalization.text(.chartSpeechUnmeasuredCount, 1),
                     TextLocalization.text(.chartSpeechBandConfident, 2),
                     TextLocalization.text(.chartSpeechBandMiddle, 0),
                     TextLocalization.text(.chartSpeechBandTooFar, 1)] {
            XCTAssertTrue(spoken.contains(part), "bagian \(part) tidak muncul di \(spoken)")
        }
    }

    func testTheSpokenSummaryIsStableForTheSameData() {
        // Kalimat ini dirakit dari beberapa bagian; kalau urutannya bergantung
        // pada iterasi dictionary atau set, pengumuman yang sama untuk rekaman
        // yang sama akan berbeda antara dua kali peluncuran app.
        let a = ConfidenceChartSpeech(samples: [1.0, 2.5, 0.3], policy: policy)
        let b = ConfidenceChartSpeech(samples: [1.0, 2.5, 0.3], policy: policy)
        XCTAssertEqual(a.spokenSummary, b.spokenSummary)
    }
}