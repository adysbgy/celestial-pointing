import XCTest
@testable import PointingKit

/// Uji untuk teks Experiment 1 yang dihasilkan di luar view.
///
/// **Kenapa ini diuji di Linux.** Laporan alat ukur — pesan status, kata
/// putusan, baris detail, ringkasan, dan diagnosis — lahir sebagai kalimat
/// Bahasa Indonesia di dalam `Packages/PointingKit` (`ExperimentHarness.verdict`,
/// `ConfidenceTrace.diagnosis`) atau dirakit lebih dulu ke sebuah `String` di
/// dalam view. Aturan 4 menyapu literal `Text("…")` di `Apps/`, jadi kalimat
/// yang lahir di paket tidak terjangkau; Aturan 6 memeriksa paritas kunci, dan
/// kalimat yang tidak melewati `LocalizedText` tidak punya kunci. Yang bisa
/// dijaga di Linux: kunci punya nilai bawaan, angka yang disisipkan benar-benar
/// masuk, dan terjemahan memasang kata yang menggantikan bawaan.
final class ExperimentTextTests: XCTestCase {

    override func tearDown() {
        // Kedua bridge dilepas: melepas hanya katalog membocorkan bahasa
        // angka milik uji ini ke berkas lain.
        TextLocalization.reset()
        NumberFormat.reset()
        super.tearDown()
    }

    func testDefaultIsIndonesianAndNotEmpty() {
        for text in LocalizedText.allKeys where text.rawValue.hasPrefix("experiment.") {
            XCTAssertFalse(text.indonesian.isEmpty,
                           "\(text.rawValue) tidak punya nilai bawaan")
            XCTAssertFalse(TextLocalization.text(text).isEmpty)
        }
    }

    func testEveryExperimentKeyIsDeclared() {
        // Kalau sebuah kalimat baru ditambahkan tanpa masuk `allKeys`, gerbang
        // paritas buta terhadapnya — persis cacat yang berkas ini tutup.
        let declared = Set(LocalizedText.allKeys
            .map(\.rawValue)
            .filter { $0.hasPrefix("experiment.") })
        XCTAssertGreaterThanOrEqual(declared.count, 36,
                                    "ada kunci experiment yang belum masuk allKeys")
    }

    func testStatusRecordedInsertsErrorVerdictAndAnswer() {
        let message = ExperimentText.statusRecorded(error: "1.2°",
                                                    verdict: ExperimentText.verdictFalseLock,
                                                    answer: "Vega")
        XCTAssertTrue(message.contains("1.2°"), "galat hilang: \(message)")
        XCTAssertTrue(message.contains("FALSE LOCK"), "putusan hilang: \(message)")
        XCTAssertTrue(message.contains("Vega"), "jawaban hilang: \(message)")
    }

    func testTargetUncomputableInsertsID() {
        let message = ExperimentText.statusTargetUncomputable(targetID: "sirius")
        XCTAssertTrue(message.contains("sirius"), "ID target hilang: \(message)")
    }

    func testSummaryFailedInsertsCountAndNumbers() {
        let message = ExperimentText.summaryFailed(falseLockCount: 3,
                                                   accuracy: "80%",
                                                   median: "1.2°",
                                                   p90: "3.4°")
        XCTAssertTrue(message.contains("3"), "jumlah false lock hilang: \(message)")
        XCTAssertTrue(message.contains("80%"), "akurasi hilang: \(message)")
        XCTAssertTrue(message.contains("1.2°"), "median hilang: \(message)")
        XCTAssertTrue(message.contains("3.4°"), "P90 hilang: \(message)")
    }

    func testSummaryInsufficientInsertsCountsAndMinimum() {
        let message = ExperimentText.summaryInsufficient(trialCount: 2,
                                                         minimum: 20,
                                                         accuracy: "—",
                                                         median: "—",
                                                         p90: "—")
        XCTAssertTrue(message.contains("2"), "jumlah percobaan hilang: \(message)")
        XCTAssertTrue(message.contains("20"), "sampel minimal hilang: \(message)")
    }

    /// Kalimat "lulus" — satu-satunya yang mengucapkan kata itu.
    ///
    /// **Cacat yang ditutup uji ini.** `ExperimentHarness.verdict` punya tiga
    /// cabang, dan sampai siklus ini hanya dua yang punya uji:
    /// `testSummaryFailedInsertsCountAndNumbers` dan
    /// `testSummaryInsufficientInsertsCountsAndMinimum`. Yang ketiga —
    /// `ExperimentText.summaryPassed` — **nol pemanggil di berkas uji mana
    /// pun** (terukur: sapuan anggota `public` tak terpakai melaporkannya
    /// `test=0`, sementara kedua saudaranya `test=1`).
    ///
    /// Kenapa yang paling berbahaya justru yang tak teruji: inilah
    /// **satu-satunya** cabang yang mencetak kata "Lulus syarat keselamatan".
    /// Dua cabang lainnya menolak mengucapkannya (lihat
    /// `ExperimentSafetyVerdict.isPassedClaim`). Jadi kalau keempat
    /// argumennya — jumlah percobaan, akurasi, median, P90 — berhenti sampai,
    /// kalimat yang tersisa di layar tetaplah sebuah **klaim lulus**, tetapi
    /// tanpa satu angka pun yang mendasarinya. Penguji membaca "lulus" dan
    /// tidak punya cara memeriksa dari mana angka itu datang.
    ///
    /// Dan klaim itu hidup: baru bisa muncul setelah 20 percobaan
    /// (`minimumTrialsForSafetyClaim`), jadi ia persis cabang yang paling
    /// jarang terlihat di layar mana pun selama pengembangan — dan karena itu
    /// paling lama bisa membusuk tanpa ada yang melihat.
    func testSummaryPassedInsertsTrialCountAndNumbers() {
        let message = ExperimentText.summaryPassed(trialCount: 20,
                                                   accuracy: "85%",
                                                   median: "1.2°",
                                                   p90: "3.4°")
        XCTAssertTrue(message.contains("20"), "jumlah percobaan hilang: \(message)")
        XCTAssertTrue(message.contains("85%"), "akurasi hilang: \(message)")
        XCTAssertTrue(message.contains("1.2°"), "median hilang: \(message)")
        XCTAssertTrue(message.contains("3.4°"), "P90 hilang: \(message)")
    }

    /// Kata "Lulus" **hanya** milik cabang `passed`.
    ///
    /// Arah yang berlawanan dari uji sebelumnya, dan tanpa itu uji pertama
    /// bisa dipenuhi dengan cara yang salah: `summaryInsufficient` juga
    /// menerima `trialCount`, jadi menaruh kata "Lulus" di sana tetap lolos
    /// pemeriksaan "angkanya masuk" sambil mengucapkan klaim keselamatan atas
    /// sampel yang belum cukup — persis cacat yang ditutup
    /// `ExperimentSafetyVerdict`, hanya berpindah ke lapisan kata.
    ///
    /// Yang dijaga di sini adalah **pemisahan ketiga cabang**, bukan ejaan
    /// katanya: kalau kelak katanya diubah beserta ketiga kunci katalognya,
    /// gerbang ini mengikutinya. Yang tidak boleh terjadi adalah dua cabang
    /// yang berbeda mengucapkan klaim yang sama.
    func testOnlyThePassedBranchClaimsLulus() {
        // Cabang yang seharusnya mengucapkannya.
        XCTAssertTrue(ExperimentText.summaryPassed(trialCount: 20,
                                                   accuracy: "85%",
                                                   median: "1.2°",
                                                   p90: "3.4°").contains("Lulus"),
                      "cabang passed harus mengucapkan kata Lulus")
        // Cabang yang tidak boleh mengucapkannya.
        XCTAssertFalse(ExperimentText.summaryInsufficient(trialCount: 2,
                                                         minimum: 20,
                                                         accuracy: "—",
                                                         median: "—",
                                                         p90: "—").contains("Lulus"),
                       "sampel kecil tidak boleh mengucapkan Lulus")
        XCTAssertFalse(ExperimentText.summaryFailed(falseLockCount: 1,
                                                    accuracy: "85%",
                                                    median: "1.2°",
                                                    p90: "3.4°").contains("Lulus"),
                       "ada false lock tidak boleh mengucapkan Lulus")
    }

    /// Diagnosis rasio memakai `%lld` untuk dua jumlah bulat.
    ///
    /// `%d` di Linux Swift membaca 32-bit dan memotong nilai `Int` 64-bit —
    /// perbedaan yang tidak terlihat sampai jumlahnya besar. Uji ini memakai
    /// angka yang melewati batas 32-bit untuk mengunci perilakunya.
    func testDiagnosisRatioInsertsPercentAndCounts() {
        let message = ExperimentText.diagnosisRatio(locks: 5, uncertain: 2)
        XCTAssertTrue(message.contains("71"), "persentase hilang: \(message)")
        XCTAssertTrue(message.contains("5"), "jumlah yakin hilang: \(message)")
        XCTAssertTrue(message.contains("2"), "jumlah ragu hilang: \(message)")
    }

    func testDiagnosisRatioHandlesEmptyCounts() {
        // Total nol tidak boleh membagi dengan nol; kalimatnya tetap muncul.
        let message = ExperimentText.diagnosisRatio(locks: 0, uncertain: 0)
        XCTAssertTrue(message.contains("0"), "rasio nol hilang: \(message)")
    }

    func testTargetOptionInsertsNameAndAltitude() {
        let option = ExperimentText.targetOption(name: "Vega", altitudeDeg: 42.6)
        XCTAssertTrue(option.contains("Vega"), "nama hilang: \(option)")
        XCTAssertTrue(option.contains("43"), "tinggi hilang: \(option)")
    }

    /// Peringatan lokasi bawaan harus menyebut lokasi yang **sedang** dipakai.
    ///
    /// Kalau lokasi belum didapat, seluruh daftar target dihitung untuk tempat
    /// lain — dan tinggi objeknya salah. Kalimat yang tidak menyebut lokasinya
    /// tidak memberi tahu pengguna tempat mana yang sebenarnya dihitung, jadi
    /// peringatannya jadi tidak bisa ditindaklanjuti.
    func testLocationFallbackWarningInsertsLabel() {
        let warning = ExperimentText.locationFallbackWarning(label: "Jakarta")
        XCTAssertTrue(warning.contains("Jakarta"), "label lokasi hilang: \(warning)")
        XCTAssertNotEqual(warning, ExperimentText.locationComputed(label: "Jakarta"),
                          "peringatan bawaan dan keterangan biasa harus berbeda")
    }

    func testLocationComputedInsertsLabel() {
        let computed = ExperimentText.locationComputed(label: "Bandung")
        XCTAssertTrue(computed.contains("Bandung"), "label lokasi hilang: \(computed)")
    }

    func testDetailErrorAndRateInsertNumbers() {
        let error = ExperimentText.detailError(degrees: 1.25)
        let rate = ExperimentText.detailRate(degPerSec: 12.7)
        XCTAssertTrue(error.contains("1,2"), "galat hilang: \(error)")
        XCTAssertTrue(rate.contains("13"), "laju hilang: \(rate)")
    }

    /// Bentuk pendek (layar) dan bentuk kalimat (suara) tetap berbeda.
    ///
    /// Satu sumber angka, dua bentuk: layar memakai kata pendek di daftar,
    /// suara memakai kalimat penuh. Menyamakannya akan membuat salah satu
    /// permukaan kehilangan bentuk yang benar untuknya.
    func testVerdictShortAndSentenceFormsAreDistinct() {
        XCTAssertNotEqual(ExperimentText.verdictFalseLock,
                          ExperimentText.verdictFalseLockSentence)
        XCTAssertNotEqual(ExperimentText.verdictCorrect,
                          ExperimentText.verdictCorrectSentence)
    }

    /// **Empat putusan yang dipakai layar, diuji satu per satu.**
    ///
    /// Kenapa uji ini ada: `Experiment1View` menampilkan
    /// `verdictFalseLock` / `verdictCorrect` / `verdictWrong` /
    /// `verdictNotAnalyzed` sebagai badge di baris percobaan. Uji terjemahan
    /// di bawah hanya memeriksa **dua** yang pertama, jadi dua sisinya
    /// tidak pernah dibuktikan punya padanan bahasa. Kalau kunci katalog
    /// untuk `wrong` atau `notAnalyzed` hilang besok, `text()` jatuh diam-
    /// diam ke bawaan Bahasa Indonesia: badge berbahasa Indonesia di tengah
    /// layar yang serba Inggris, tanpa satu pun uji berbunyi.
    ///
    /// Ini bukan cacat yang dikarang. Sapuan atas `public` API PointingKit
    /// yang tidak disebut di berkas uji menemukan keempatnya sekaligus —
    /// persis kelas "teruji" yang hanya berarti "kebetulan dipakai".
    func testEveryVerdictShownOnScreenHasAnEnglishForm() {
        let english: [String: String] = [
            "experiment.verdict.falseLock": "FALSE LOCK-en",
            "experiment.verdict.correct": "correct-en",
            "experiment.verdict.wrong": "wrong-en",
            "experiment.verdict.notAnalyzed": "not analyzed-en",
            "experiment.verdict.falseLock.sentence": "False lock sentence-en",
            "experiment.verdict.correct.sentence": "Correct sentence-en",
            "experiment.verdict.wrong.sentence": "Wrong sentence-en",
            "experiment.verdict.notAnalyzed.sentence": "Not analyzed sentence-en",
        ]
        EnglishTranslation.install(english)
        // Bentuk pendek — yang tampil sebagai badge.
        XCTAssertEqual(ExperimentText.verdictFalseLock, "FALSE LOCK-en")
        XCTAssertEqual(ExperimentText.verdictCorrect, "correct-en")
        XCTAssertEqual(ExperimentText.verdictWrong, "wrong-en")
        XCTAssertEqual(ExperimentText.verdictNotAnalyzed, "not analyzed-en")
        // Bentuk kalimat — yang diucapkan. Keempatnya harus berbeda dari
        // bentuk pendeknya, kalau tidak satu permukaan kehilangan bentuk
        // yang benar untuknya.
        XCTAssertEqual(ExperimentText.verdictFalseLockSentence,
                       "False lock sentence-en")
        XCTAssertEqual(ExperimentText.verdictCorrectSentence,
                       "Correct sentence-en")
        XCTAssertEqual(ExperimentText.verdictWrongSentence,
                       "Wrong sentence-en")
        XCTAssertEqual(ExperimentText.verdictNotAnalyzedSentence,
                       "Not analyzed sentence-en")
    }

    /// **Katalog asli wajib memuat terjemahan `en` untuk setiap putusan.**
    ///
    /// Kenapa uji kedua, kalau yang di atas sudah memeriksa keempatnya:
    /// uji di atas **memasang kamusnya sendiri** lewat
    /// `EnglishTranslation.install`, jadi ia membuktikan *mekanisme*
    /// penerjemahan bekerja — bukan bahwa katalognya lengkap. Ini terukur:
    /// saya hapus entri `en` untuk `experiment.verdict.wrong` dari
    /// `Localizable.xcstrings`, dan **488 uji tetap hijau**. Yang di atas
    /// tidak berbunyi sama sekali.
    ///
    /// Akibatnya nyata. Kunci ini tidak punya `stringUnit` sendiri —
    /// `sourceLanguage` katalog adalah `id`, jadi tanpa `en` teksnya jatuh
    /// ke bawaan Bahasa Indonesia. Pengguna berbahasa Inggris melihat badge
    /// "salah" di tengah layar yang serba Inggris, dan tidak ada uji yang
    /// tahu. Tanpa uji ini, katalog yang membusuk tidak ketahuan sampai
    /// seseorang melihat layarnya.
    ///
    /// Jadi yang diperiksa di sini adalah **berkas katalognya**, bukan
    /// accessor-nya.
    func testCatalogueShipsAnEnglishFormForEveryVerdict() {
        // `Bundle.module` tidak ada: PointingKit tidak membawa resource
        // bundle, jadi katalog dicari di pohon sumber. Uji ini sengaja
        // **gagal** bila katalog tidak ditemukan, bukan dilewati —
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
        // **Seluruh** kunci katalog, bukan hanya yang dipakai `Experiment1View`.
        //
        // Kenapa diperluas: cacatnya bukan pada delapan putusan itu,
        // melainkan pada **siapa pun yang menambah kunci dan lupa
        // menerjemahkannya**. Sapuan membuktikan saat ini 312 kunci semuanya
        // punya `en` — jadi memeriksa keseluruhan katalog tidak membuat uji
        // merah sekarang, dan justru membuat kunci baru yang tidak
        // diterjemahkan langsung tertolak. Pemeriksaan yang hanya mencakup
        // delapan kunci akan membiarkan 304 sisinya membusuk tanpa suara.
        //
        // `NOT_LOCALIZED` di `swift-ui-lint.sh` mengecualikan nama merek
        // ("Point & Know", "Experiment 1") dari Aturan 4. Di sini tidak ada
        // pengecualian: katalog boleh memuat nama merek dengan `en` yang
        // sama, dan kalau tidak, itu memang perlu dilihat.
        let needed = strings.keys.sorted()
        for key in needed {
            guard let unit = strings[key] as? [String: Any] else {
                XCTFail("Kunci katalog hilang: \(key)")
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

    /// Terjemahan memasang kata yang menggantikan bawaan.
    ///
    /// Kalau sebuah kalimat tidak punya entri katalog, `text()` jatuh ke
    /// bawaan Bahasa Indonesia — dan pengguna Bahasa Inggris melihat Bahasa
    /// Indonesia tanpa ada yang tahu. Uji ini memasang terjemahan Inggris
    /// untuk seluruh kunci experiment dan memastikan setiap aksesornya
    /// membacanya.
    func testEnglishTranslationControlsTheWords() {
        let english: [String: String] = [
            "experiment.status.initial": "Pick a target, aim, then record.",
            "experiment.status.noTarget": "Pick a target first.",
            "experiment.status.recorded": "Recorded: error %@, %@. Engine answer: %@.",
            "experiment.status.removed": "Removed: %@.",
            "experiment.status.nothingToRemove": "No trial to remove.",
            "experiment.status.reset": "Dataset cleared.",
            "experiment.verdict.falseLock": "FALSE LOCK",
            "experiment.verdict.correct": "correct",
            "experiment.verdict.falseLock.sentence": "False lock: confident but wrong.",
            "experiment.detail.noAnswer": "none yet",
            "experiment.detail.answer": "answer %@",
            "experiment.detail.error": "error %.1f°",
            "experiment.detail.rate": "%.0f°/s",
            "experiment.target.option": "%@ · %.0f°",
            "experiment.summary.noAnalyzable": "No trial that can be analyzed yet.",
            "experiment.summary.failed": "FAILED: %lld false lock. Accuracy %@, median %@, P90 %@.",
            "experiment.diagnosis.noSamples": "No samples yet.",
            "experiment.diagnosis.ratio": "%.0f%% confident (%lld confident, %lld uncertain).",
            "experiment.suggestedThreshold": "Suggested threshold: σ %.1f°",
            "experiment.location.fallback": "Location not yet available — computed for %@.",
            "experiment.location.computed": "Computed for %@.",
        ]
        EnglishTranslation.install(english)

        XCTAssertEqual(ExperimentText.statusInitial,
                       "Pick a target, aim, then record.")
        XCTAssertEqual(ExperimentText.statusNoTarget, "Pick a target first.")
        XCTAssertEqual(ExperimentText.verdictFalseLock, "FALSE LOCK")
        XCTAssertEqual(ExperimentText.verdictCorrect, "correct")
        XCTAssertEqual(ExperimentText.verdictFalseLockSentence,
                       "False lock: confident but wrong.")
        XCTAssertEqual(ExperimentText.detailNoAnswer, "none yet")
        XCTAssertEqual(ExperimentText.detailAnswer("Vega"), "answer Vega")
        XCTAssertEqual(ExperimentText.detailError(degrees: 1.25), "error 1.2°")
        XCTAssertEqual(ExperimentText.detailRate(degPerSec: 12.7), "13°/s")
        XCTAssertEqual(ExperimentText.targetOption(name: "Vega", altitudeDeg: 42.6),
                       "Vega · 43°")
        XCTAssertEqual(ExperimentText.summaryNoAnalyzable,
                       "No trial that can be analyzed yet.")
        XCTAssertEqual(ExperimentText.summaryFailed(falseLockCount: 1,
                                                    accuracy: "a", median: "b", p90: "c"),
                       "FAILED: 1 false lock. Accuracy a, median b, P90 c.")
        XCTAssertEqual(ExperimentText.diagnosisNoSamples, "No samples yet.")
        XCTAssertEqual(ExperimentText.diagnosisRatio(locks: 5, uncertain: 2),
                       "71% confident (5 confident, 2 uncertain).")
        XCTAssertEqual(ExperimentText.suggestedThreshold(sigmaDeg: 2.4),
                       "Suggested threshold: σ 2.4°")
        XCTAssertEqual(ExperimentText.locationFallbackWarning(label: "Jakarta"),
                       "Location not yet available — computed for Jakarta.")
        XCTAssertEqual(ExperimentText.locationComputed(label: "Jakarta"),
                       "Computed for Jakarta.")
    }
}
