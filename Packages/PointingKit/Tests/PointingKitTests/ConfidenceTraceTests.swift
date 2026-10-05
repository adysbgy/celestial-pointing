import XCTest
import CelestialEngine
@testable import PointingKit

/// Riwayat keyakinan: yang diuji adalah apakah grafiknya **jujur**.
///
/// Kalau riwayat ini salah menyimpan variabel keputusan, grafik diagnostik akan
/// menunjuk perbaikan yang salah — dan seluruh gunanya hilang.
final class ConfidenceTraceTests: XCTestCase {

    // MARK: - Variabel keputusan

    /// Rasio terhadap sigma harus ikut disimpan: 5° berarti berbeda pada sigma
    /// 10° dan sigma 1°.
    func testRatioToSigmaIsTheDecisionVariable() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "sirius", objectName: "Sirius",
                     separationDeg: 5, sigmaDeg: 10, at: Date())
        trace.record(state: .uncertain, level: .medium, objectID: "vega", objectName: "Vega",
                     separationDeg: 5, sigmaDeg: 1, at: Date())

        XCTAssertEqual(trace.samples[0].ratioToSigma, 0.5)
        XCTAssertEqual(trace.samples[1].ratioToSigma, 5.0)
        // Jarak mentahnya sama, tapi keputusannya harus berbeda.
        XCTAssertNotEqual(trace.samples[0].ratioToSigma, trace.samples[1].ratioToSigma)
    }

    /// Sigma nol tidak boleh menghasilkan pembagian tak berhingga yang tampak
    /// seperti "sangat dekat".
    func testZeroSigmaDoesNotProduceFakeRatio() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "sirius", objectName: "Sirius",
                     separationDeg: 5, sigmaDeg: 0, at: Date())
        XCTAssertNil(trace.samples[0].ratioToSigma)
    }

    // MARK: - Kapasitas

    func testCapacityKeepsTheMostRecentSamples() {
        let trace = ConfidenceTrace(capacity: 3)
        for index in 0..<5 {
            trace.record(state: .lock, level: .high, objectID: "obj\(index)",
                         objectName: "Obj\(index)", separationDeg: 1, sigmaDeg: 1, at: Date())
        }
        XCTAssertEqual(trace.samples.count, 3)
        XCTAssertEqual(trace.samples.map(\.objectID), ["obj2", "obj3", "obj4"])
    }

    func testRecordingCanBePaused() {
        let trace = ConfidenceTrace()
        trace.isRecording = false
        trace.record(state: .lock, level: .high, objectID: "sirius", objectName: "Sirius",
                     separationDeg: 1, sigmaDeg: 1, at: Date())
        XCTAssertTrue(trace.samples.isEmpty)
    }

    // MARK: - Sebab keraguan

    /// Dua sebab keraguan punya perbaikan yang berbeda dan **tidak boleh**
    /// dicampur: "terlalu jauh" berarti perbaiki kalibrasi, "ambigu" berarti
    /// batas akurasi.
    func testUncertainReasonsAreDistinguished() {
        let trace = ConfidenceTrace()
        let policy = ConfidencePolicy(pointingSigmaDeg: 10) // maxSeparation 10°, ambiguity 20°

        // Jauh: 25° = 2.5σ.
        trace.record(state: .uncertain, level: .medium, objectID: "a", objectName: "A",
                     separationDeg: 25, sigmaDeg: 10, nearestNeighbourDeg: 60, at: Date())
        // Ambigu: dekat (5° = 0.5σ), tapi tetangga 10° = 1σ ≤ 2σ.
        trace.record(state: .uncertain, level: .medium, objectID: "b", objectName: "B",
                     separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 10, at: Date())

        XCTAssertEqual(trace.uncertainReason(for: trace.samples[0], policy: policy), .tooFar)
        XCTAssertEqual(trace.uncertainReason(for: trace.samples[1], policy: policy), .ambiguous)

        let counts = trace.uncertainReasonCounts(policy: policy)
        XCTAssertEqual(counts[.tooFar], 1)
        XCTAssertEqual(counts[.ambiguous], 1)
    }

    func testDiagnosisPointsAtCalibrationWhenEverythingIsTooFar() {
        let trace = ConfidenceTrace()
        trace.record(state: .uncertain, level: .medium, objectID: "a", objectName: "A",
                     separationDeg: 30, sigmaDeg: 10, nearestNeighbourDeg: 90, at: Date())
        XCTAssertTrue(trace.diagnosis(policy: ConfidencePolicy(pointingSigmaDeg: 10))
            .contains("kalibrasi"))
    }

    func testDiagnosisSaysNothingRecordedWhenEmpty() {
        XCTAssertTrue(ConfidenceTrace().diagnosis().contains("Belum ada sampel"))
    }

    /// MARK: - Diagnosis saat hitungan seri
    //
    // Yang diuji di sini bukan kalimatnya, tapi **keputusan**nya: dua sebab
    // yang sama saingnya tidak boleh dipilih satu secara diam-diam.
    //
    // Bentuk cacatnya diukur, bukan Migration: `diagnosis` lama memakai
    // `counts.max { $0.value < $1.value }`, dan saat hitungan seri `max`
    // mengembalikan elemen pertama yang ditemukan — urutan iterasi
    // `Dictionary` tidak ditentukan di Swift (hash di-seed per proses).
    // Delapan kali peluncuran `swift test` pada data yang sama menghasilkan
    // "Perbaiki kalibrasi dulu." 5 kali dan "Ini keterbatasan akurasi." 3 kali.

    /// Dua sebab yang sama saingnya harus disebut **berdua**.
    ///
    /// Kalimat yang tampil harus memuat **kedua** petunjuk perbaikan. Kalau
    /// hanya satu, penguji tidak tahu ada masalah kedua yang juga perlu
    /// dibenahi — dan pada alat ukur repo ini sendiri, itu berarti
    /// memperbaiki separuh masalah lalu menyimpulkan alatnya selesai.
    func testTiedReasonsMustBeReportedTogether() {
        let trace = ConfidenceTrace()
        let policy = ConfidencePolicy(pointingSigmaDeg: 10)
        // 1 sampel tooFar (2.5 sigma, di atas maxSeparationSigma).
        trace.record(state: .uncertain, level: .low, objectID: "a", objectName: "A",
                     separationDeg: 25, sigmaDeg: 10, nearestNeighbourDeg: 60)
        // 1 sampel ambiguous (tetangga 1 sigma, di bawah ambiguitySigma).
        trace.record(state: .uncertain, level: .low, objectID: "b", objectName: "B",
                     separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 10)

        XCTAssertEqual(trace.tiedUncertainReasons(policy: policy).count, 2,
                       "dua sebab harus terdeteksi seri")

        let sentence = trace.diagnosis(policy: policy)
        XCTAssertTrue(sentence.contains("kalibrasi"),
                      "petunjuk kalibrasi harus ikut disebut: \(sentence)")
        XCTAssertTrue(sentence.contains("keterbatasan akurasi"),
                      "petunjuk akurasi harus ikut disebut: \(sentence)")
    }

    /// Kalimat yang sama harus **stabil** dalam satu proses, dan hanya itu yang
    /// bisa dijaga di sini.
    ///
    /// Batasnya jujur: stabilitas *antar* peluncuran tidak bisa diuji dari
    /// dalam satu proses, karena itu justru soal urutan iterasi Dictionary
    /// yang di-seed per proses. Yang bisa dijaga di sini adalah isi kalimatnya
    /// (test di atas), dan itulah yang membuat verifikasi antar peluncuran
    /// tidak perlu melihat dua kalimat berbeda lagi.
    func testDiagnosisIsRepeatableWithinOneProcess() {
        func build() -> ConfidenceTrace {
            let trace = ConfidenceTrace()
            trace.record(state: .uncertain, level: .low, objectID: "a", objectName: "A",
                         separationDeg: 25, sigmaDeg: 10, nearestNeighbourDeg: 60)
            trace.record(state: .uncertain, level: .low, objectID: "b", objectName: "B",
                         separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 10)
            return trace
        }
        let policy = ConfidencePolicy(pointingSigmaDeg: 10)
        let first = build().diagnosis(policy: policy)
        for _ in 0..<20 {
            XCTAssertEqual(build().diagnosis(policy: policy), first,
                           "data identik harus menghasilkan kalimat identik")
        }
    }

    /// Urutan sebab pada kalimat seri harus mengikuti **urutan enum**, bukan
    /// urutan acak dictionary.
    ///
    /// Ini yang menjaga kalimatnya sama setelah perbaikan: `allCases` punya
    /// urutan yang ditulis, sementara `Dictionary` tidak. Uji ini mengunci
    /// arahnya (terlalu jauh lebih dulu), karena urutan yang tidak ditulis
    /// akan menggantung pada apa yang kebetulan ditemukan lebih dulu.
    func testTiedReasonOrderFollowsTheEnumNotTheHash() {
        let trace = ConfidenceTrace()
        let policy = ConfidencePolicy(pointingSigmaDeg: 10)
        trace.record(state: .uncertain, level: .low, objectID: "b", objectName: "B",
                     separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 10)
        trace.record(state: .uncertain, level: .low, objectID: "a", objectName: "A",
                     separationDeg: 25, sigmaDeg: 10, nearestNeighbourDeg: 60)

        XCTAssertEqual(trace.tiedUncertainReasons(policy: policy), [.tooFar, .ambiguous])
    }

    /// Tiga sebab seri harus menyebut **ketiganya**, bukan dua.
    ///
    /// "Tanpa sebab terukur" sering dilupakan justru karena ia bukan penyebab,
    /// tapi catatan bahwa penyebabnya tidak terukur — dan itulah informasi yang
    /// paling sering dibutuhkan untuk deciding apakah menambah rekaman.
    func testAllThreeTiedReasonsAreNamed() {
        let trace = ConfidenceTrace()
        let policy = ConfidencePolicy(pointingSigmaDeg: 10)
        trace.record(state: .uncertain, level: .low, objectID: "a", objectName: "A",
                     separationDeg: 25, sigmaDeg: 10, nearestNeighbourDeg: 60)
        trace.record(state: .uncertain, level: .low, objectID: "b", objectName: "B",
                     separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 10)
        // Tidak ada sebab terukur: kandidat dekat, tapi tetra juga dekat.
        trace.record(state: .uncertain, level: .low, objectID: "c", objectName: "C",
                     separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 60)

        XCTAssertEqual(trace.tiedUncertainReasons(policy: policy).count, 3)

        let sentence = trace.diagnosis(policy: policy)
        XCTAssertTrue(sentence.contains("kalibrasi"), sentence)
        XCTAssertTrue(sentence.contains("keterbatasan akurasi"), sentence)
        XCTAssertTrue(sentence.contains("tanpa sebab terukur"), sentence)
    }

    /// Satu sebab yang **benar-benar mendominasi** boleh tampil sendiri.
    ///
    /// Tanpa ini, perbaikan di atas akan membuat kalimat selalu panjang —
    /// termasuk saat 9 dari 10 sampel ragu karena satu sebab, yang jauh lebih
    /// berguna dijawab langsung.
    func testADominatingReasonStillReportsAlone() {
        let trace = ConfidenceTrace()
        let policy = ConfidencePolicy(pointingSigmaDeg: 10)
        for _ in 0..<3 {
            trace.record(state: .uncertain, level: .low, objectID: "a", objectName: "A",
                         separationDeg: 25, sigmaDeg: 10, nearestNeighbourDeg: 60)
        }
        trace.record(state: .uncertain, level: .low, objectID: "b", objectName: "B",
                     separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 10)

        XCTAssertEqual(trace.tiedUncertainReasons(policy: policy), [.tooFar])
        let sentence = trace.diagnosis(policy: policy)
        XCTAssertTrue(sentence.contains("kalibrasi"), sentence)
        XCTAssertFalse(sentence.contains("Penyebab keraguan berbagi"),
                       "sebab tunggal tidak perlu kalimat seri: \(sentence)")
    }

    ///-Series tanpa ada yang seri berarti memang tidak ada yang bisa
    /// dituduhkan — itu kalimat "tanpa sebab terukur", bukan kalimat kosong.
    func testSingleUnmeasuredReasonIsNotASeries() {
        let trace = ConfidenceTrace()
        let policy = ConfidencePolicy(pointingSigmaDeg: 10)
        trace.record(state: .uncertain, level: .low, objectID: "c", objectName: "C",
                     separationDeg: 5, sigmaDeg: 10, nearestNeighbourDeg: 60)

        XCTAssertEqual(trace.tiedUncertainReasons(policy: policy), [.none])
        XCTAssertTrue(trace.diagnosis(policy: policy).contains("tanpa sebab terukur"))
    }

    // MARK: - Pesan dari jam

    /// Sampel dari jam tidak membawa jarak kandidat; itu harus tetap kosong,
    /// bukan diisi angka karangan.
    func testWatchMessageRecordsWithoutInventingSeparation() {
        let trace = ConfidenceTrace()
        let message = PointingLinkMessage(kind: .pointingState,
                                          sentAt: Date(),
                                          state: .lock,
                                          objectID: "sirius",
                                          objectName: "Sirius",
                                          level: .high)
        trace.record(message: message)

        XCTAssertEqual(trace.samples.count, 1)
        XCTAssertTrue(trace.samples[0].fromWatch)
        XCTAssertEqual(trace.samples[0].objectID, "sirius")
        XCTAssertNil(trace.samples[0].separationDeg)
        XCTAssertNil(trace.samples[0].ratioToSigma)
    }

    /// Pesan yang bukan keadaan pointing (mis. tanda terima) tidak boleh
    /// menghasilkan sampel.
    func testNonStateMessagesAreIgnored() {
        let trace = ConfidenceTrace()
        trace.record(message: PointingLinkMessage(kind: .acknowledgement))
        XCTAssertTrue(trace.samples.isEmpty)
    }

    func testCountsByStateAndLevel() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 1, sigmaDeg: 10, at: Date())
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 1, sigmaDeg: 10, at: Date())
        trace.record(state: .pointing, level: nil, objectID: nil, objectName: nil,
                     separationDeg: nil, sigmaDeg: 10, at: Date())

        XCTAssertEqual(trace.stateCounts[.lock], 2)
        XCTAssertEqual(trace.stateCounts[.pointing], 1)
        XCTAssertEqual(trace.levelCounts[.high], 2)
        XCTAssertEqual(trace.answered.count, 2)
    }

    func testResetClearsEverything() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 1, sigmaDeg: 10, at: Date())
        trace.reset()
        XCTAssertTrue(trace.samples.isEmpty)
    }

    // MARK: - Objek sisa tidak boleh terekam sebagai jawaban

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279, decDeg: 38, magnitude: 0.03)

    /// Riwayat harus mencatat jawaban yang **berlaku sekarang**, bukan objek
    /// yang sengaja dipertahankan mesin keadaan.
    ///
    /// `snapshot.intent` tetap terisi setelah keadaan kehilangan jawabannya
    /// (supaya layar jam tidak berkedip). Membacanya langsung akan menuliskan
    /// objek dan keyakinan dari arah tunjuk sebelumnya sebagai jawaban untuk
    /// arah sekarang: riwayat yang tampak normal sambil memuat false lock yang
    /// tidak pernah terjadi — dan grafik diagnostik akan menunjuk perbaikan
    /// yang salah.
    func testStaleObjectIsNotRecordedAsAnswer() {
        let trace = ConfidenceTrace()
        let stale = PointingSnapshot(state: .pointing,
                                     intent: CelestialIntent(
                                        level: .high,
                                        best: vega,
                                        candidates: [Candidate(object: vega, separationDeg: 0.4)]))
        trace.record(snapshot: stale, sigmaDeg: 2)

        let sample = try! XCTUnwrap(trace.samples.last)
        XCTAssertEqual(sample.state, .pointing, "keadaannya tetap dicatat apa adanya")
        XCTAssertNil(sample.objectID, "objek dari arah tunjuk sebelumnya bukan jawaban")
        XCTAssertNil(sample.level, "keyakinan lama tidak boleh menempel")
        XCTAssertNil(sample.separationDeg, "jarak resolusi lama bukan jarak sekarang")
        XCTAssertNil(sample.ratioToSigma)
    }

    /// Keadaan yang punya jawaban tetap merekam objek, keyakinan, dan jaraknya.
    func testLiveAnswerIsRecordedWithItsDecisionVariables() {
        let trace = ConfidenceTrace()
        let live = PointingSnapshot(state: .lock,
                                    intent: CelestialIntent(
                                        level: .high,
                                        best: vega,
                                        candidates: [Candidate(object: vega, separationDeg: 0.4)]))
        trace.record(snapshot: live, sigmaDeg: 2)

        let sample = try! XCTUnwrap(trace.samples.last)
        XCTAssertEqual(sample.objectID, "vega")
        XCTAssertEqual(sample.level, .high)
        XCTAssertEqual(try! XCTUnwrap(sample.separationDeg), 0.4, accuracy: 1e-12)
        XCTAssertEqual(try! XCTUnwrap(sample.ratioToSigma), 0.2, accuracy: 1e-12)
    }
}
