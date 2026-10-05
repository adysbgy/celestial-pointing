import XCTest
import CelestialEngine
@testable import PointingKit

/// Cacat: satu acuan yang diketuk beberapa kali dihitung sebagai beberapa acuan.
///
/// **Premis.** `CalibrationFlow` menghitung `residualSpreadDeg` dari **seluruh**
/// sampel, lalu angka itu jadi sigma pointing yang menyetel ambang keyakinan
/// engine. Tapi dua sampel untuk **benda yang sama** tidak menguji dua arah
/// berbeda — keduanya menguji arah yang sama. Sigma pointing justru bermakna
/// "seberapa galat arah tunjuk kita **di langit mana pun**", dan itu hanya
/// bisa diukur dari beberapa arah.
///
/// Dua akibat yang salah ke arah yang **berbeda**, jadi keduanya harus diuji:
///
/// 1. **Sigma jadi tidak bermakna.** Dua ketukan pada satu bintang
///    menghasilkan sebaran ~1e-6 derajat — bukan "sangat akurat", tapi "tidak
///    mengukur apa pun". Angka itu tetap `> 0` dan berhingga, jadi seluruh
///    penjaganya meloloskannya: alur menyatakan "Siap", dan
///    `confidencePolicy()` mengarang ambang keyakinan dari noise. Sigma ~0
///    membuat `maxSeparationDeg` ~0, jadi engine tidak pernah lagi boleh
///    menjawab HIGH — satu kalibrasi buruk mematikan seluruh pointing sesudahnya.
/// 2. **Pengenceran (dilution).** Mengulang satu bintang yang "murah" 20 kali
///    menurunkan RMS karena sampel didominasi arah yang sama, sehingga sigma
///    justru **meremehkan** galat yang ada. Ini `uncertainty > false confidence`
///    yang dilanggar PRD v0.4 — dan arahnya berlawanan dengan akibat pertama,
///    jadi penjaga yang terlalu ketat pada akibat pertama belum tentu
///    menangkap akibat kedua.
///
/// Dua ketukan pada satu bintang bukan kasus tepi: `captureNearest` memilih
/// bintang terdekat dari arah tunjuk, jadi pengguna yang mengarahkan jam ke
/// Sirius lalu menekan tombol dua kali menghasilkan keadaan ini tanpa apa pun
/// yang salah di sisi pengguna.
///
/// **Bentuk perbaikannya** mengikuti preseden yang sudah ada di repo ini
/// (`unanalyzableCount`): catat semua pengukuran — tidak ada yang dibuang
/// diam-diam, dan `removeLast` tetap berarti — tapi hitung **klaim** dari
/// bagian yang benar-benar independen, lalu katakan jumlahnya beserta
/// akibatnya.
final class CalibrationReferenceIndependenceTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let resolver = PointingResolver(catalogue: Catalogue.brightStars,
                                            policy: .permissive)

    /// Arah tunjuk yang meleset dari kebenaran dengan offset yaw tertentu.
    private func measured(_ id: String, yawError: Double) -> HorizontalCoord {
        let t = resolver.horizontal(ofObjectID: id, observer: observer, date: date)!
        return HorizontalCoord(altitudeDeg: t.altitudeDeg,
                               azimuthDeg: SkyMath.normalizeDeg(t.azimuthDeg - yawError))
    }

    private func add(_ flow: inout CalibrationFlow, _ id: String, yawError: Double) {
        flow.add(objectID: id,
                 measured: measured(id, yawError: yawError),
                 resolver: resolver, observer: observer, date: date)
    }

    // MARK: - Akibat 1: satu arah tidak pernah jadi dua acuan

    func testRepeatedReferenceIsNotASecondIndependentReference() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        add(&flow, "sirius", yawError: 11)

        XCTAssertFalse(flow.isReady,
                       "satu arah yang diukur dua kali tidak bisa mengukur galat lintas langit")
        XCTAssertNil(flow.applicableCalibration,
                     "kalibrasi siap dari satu arah memasang offset yang tak pernah terukur")
    }

    /// Pengulangan tidak memperbaiki apa pun: tiga ketukan tetap satu arah.
    func testManyTapsOnOneStarStillNeverBecomeReady() {
        var flow = CalibrationFlow()
        for _ in 0..<3 {
            add(&flow, "sirius", yawError: 11)
        }
        XCTAssertFalse(flow.isReady)
    }

    /// Sebaliknya, beberapa arah **tetap** boleh siap. Penjaga harus menyaring
    /// pengulangan saja — bukan menolak pengukuran kedua altogether. Uji ini
    /// yang menahan perbaikan yang terlalu gurau.
    func testDistinctReferencesStillBecomeReady() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        add(&flow, "vega", yawError: 11)
        XCTAssertTrue(flow.isReady, "dua arah berbeda tetap pengukuran yang sah")
    }

    // MARK: - Akibat 2: pengulangan tidak boleh mengencerkan sigma

    /// Mengulang satu bintang yang "murah" tidak boleh membuat sigma terlihat
    /// lebih baik daripada pengukuran dua arah yang jujur.
    ///
    /// Galat yaw sengaja dibuat berbeda antar langit (Sirius salah 0°, Vega
    /// salah 4°) — itulah yang terjadi pada sensor sungguhan, dan itulah yang
    /// justru harus terukur.
    func testRepeatingTheEasyStarMustNotUnderstateTheSigma() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 0)
        add(&flow, "vega", yawError: 4)

        let honest = try! XCTUnwrap(flow.calibration?.residualSpreadDeg)
        let honestPolicy = try! XCTUnwrap(flow.calibration?.confidencePolicy())

        for _ in 0..<20 {
            add(&flow, "sirius", yawError: 0)
        }

        let diluted = try! XCTUnwrap(flow.calibration?.residualSpreadDeg)
        // Tanpa `accuracy:` — perbandingan ini harus tepat, jadi toleransi hanya
        // untuk pembulatan floating point, bukan untuk melonggarkan syarat.
        XCTAssertGreaterThanOrEqual(diluted - honest, -1e-9,
                                    "20 pengulangan satu bintang membuat sigma terlihat lebih baik: "
                                    + "pengukuran baru saja jadi lebih akurat daripada pengukurannya")

        // Akibat yang lebih berbahaya: ambang keyakinan yang ikut terlalu
        // ketat — inilah yang benar-benar dipakai engine.
        let dilutedPolicy = try! XCTUnwrap(flow.calibration?.confidencePolicy())
        XCTAssertGreaterThanOrEqual(dilutedPolicy.pointingSigmaDeg - honestPolicy.pointingSigmaDeg,
                                    -1e-9)
    }

    // MARK: - Klaim yang tidak boleh lahir dari satu arah

    /// Sigma dari satu arah tidak boleh jadi kebijakan engine. `nil` berarti
    /// "belum terukur", dan pemanggil tetap memakai nilai konservatif bawaan —
    /// satu-satunya arah yang jujur.
    func testSingleDirectionCannotProduceAConfidencePolicy() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        add(&flow, "sirius", yawError: 11)
        XCTAssertNil(flow.calibration?.confidencePolicy(),
                     "satu arah tidak bisa mengukur pointing sigma — jangan mengarang ambang")
    }

    /// Sebaliknya, sigma dari beberapa arah **tetap** mengalir ke kebijakan.
    func testMeasuredSpreadFromDistinctDirectionsStillDrivesConfidencePolicy() {
        var flow = CalibrationFlow()
        for id in ["sirius", "vega", "arcturus"] {
            add(&flow, id, yawError: 11)
        }
        let calibration = try! XCTUnwrap(flow.applicableCalibration)
        let policy = try! XCTUnwrap(calibration.confidencePolicy())
        let spread = try! XCTUnwrap(calibration.residualSpreadDeg)
        XCTAssertEqual(policy.pointingSigmaDeg, spread, accuracy: 1e-12)
    }

    // MARK: - Kejujuran pada layar dan pada suara

    /// Hitungan yang tampil harus menghitung acuan **berbeda**, dan kalau
    /// pengulangan tidak menambah apa pun, kalimat itu harus mengatakannya.
    ///
    /// Tanpa ini, layar menampilkan "3 acuan tercatat" lalu "Butuh minimal 2"
    /// — dua kalimat yang saling meniadakan, dan yang salah keduanya hilang
    /// tak terlihat karena angka "3" memang benar (tiga ketukan terjadi).
    func testRepeatedTapsSayWhyTheyDidNotCount() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        let update = flow.add(objectID: "sirius",
                              measured: measured("sirius", yawError: 11),
                              resolver: resolver, observer: observer, date: date)

        let message = try! XCTUnwrap(update?.message)
        XCTAssertTrue(message.contains("Sirius"),
                      "pesan harus menyebut bintang mana yang sudah tercatat, bukan hanya hitungan")
        XCTAssertFalse(message.contains("terlalu lebar"),
                       "sebarannya belum bermakna, jadi jangan disebut lebar")
    }

    /// Suara punya syarat yang sama. `spokenPhaseSummary` adalah satu-satunya
    /// pengumuman di layar kalibrasi; kalau hitungannya salah, pengguna yang
    /// tidak melihat layar punya **tidak ada** jalan lain untuk mengetahuinya.
    func testSpokenSummaryCountsDistinctReferences() {
        var flow = CalibrationFlow()
        for _ in 0..<3 {
            add(&flow, "sirius", yawError: 11)
        }
        let spoken = flow.spokenPhaseSummary
        XCTAssertFalse(spoken.contains("3 acuan tercatat"),
                       "tiga ketukan pada satu bintang adalah satu acuan, bukan tiga")
    }

    /// Pengulangan tidak boleh dihapus diam-diam: `removeLast` harus tetap
    /// berarti "buang ketukan terakhir", dan setelahnya jumlah tetap jujur.
    func testRepeatedSamplesAreStillStoredAndRemovable() {
        var flow = CalibrationFlow()
        for _ in 0..<2 {
            add(&flow, "sirius", yawError: 11)
        }
        XCTAssertEqual(flow.samples.count, 2,
                       "pengukuran tidak boleh dibuang diam-diam — toh ia tetap tercatat")

        flow.removeLast()
        XCTAssertEqual(flow.samples.count, 1)
        XCTAssertFalse(flow.isReady)
    }

    // MARK: - Catatan yang tampil harus lahir dari angka yang sama

    /// **Regresi: catatan layar menghitung bintang, bukan ketukan.**
    ///
    /// Dua sumber angka hidup berdampingan di `CalibrationFlow` dan keduanya
    /// bertipe `Int`, jadi tidak ada satu pun gerbang yang bisa memilih yang
    /// benar:
    ///
    /// - `repeatedReferenceIDs.count` — berapa **bintang** yang diulang.
    /// - `redundantTapCount` — berapa **ketukan** yang terbuang.
    ///
    /// Yang dibutuhkan pengguna dari catatan itu adalah ketukan: "berapa
    /// ketukan saya yang tidak menambah apa pun". Untuk tiga ketukan pada satu
    /// bintang, jawabannya 2 — bukan 1. Memakai hitungan bintang membuat
    /// catatan ini selalu bernilai 1 pada keadaan yang paling sering terjadi
    /// (satu bintang diketuk berulang), jadi ia tidak pernah memberi informasi
    /// apa pun.
    ///
    /// Bentuk yang diuji sengaja memakai accessor **`CalibrationFlow`**,
    /// bukan `CalibrationText` yang menerima `Int` secara bebas: kalau view
    /// boleh mengirim `repeatedReferenceIDs.count` ke sana, pilihan yang salah
    /// ini bisa terjadi lagi tanpa ada yang melihat — persis cacat yang ada
    /// sekarang.
    func testOnScreenHintCountsTapsNotRepeatedStars() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        add(&flow, "sirius", yawError: 11)
        add(&flow, "sirius", yawError: 11)
        add(&flow, "vega", yawError: 9)

        let hint = try! XCTUnwrap(flow.repetitionHint)
        XCTAssertTrue(hint.contains("2"), "harus menyebut dua ketukan yang terbuang: \(hint)")
        XCTAssertFalse(hint.contains("1 ketukan"),
                       "jumlah bintang akan disalahartikan sebagai jumlah ketukan: \(hint)")
    }

    /// Tanpa pengulangan tidak ada catatan — bukan catatan yang berbunyi nol.
    ///
    /// "0 ketukan tidak menambah pengukuran" menyatakan sesuatu yang tidak
    /// terjadi, dan ia juga memenuhi syarat `redundantTapCount > 0` kalau
    /// penjaganya salah ditulis.
    func testNoRepetitionMeansNoHintAtAll() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        add(&flow, "vega", yawError: 9)

        XCTAssertNil(flow.repetitionHint)
        XCTAssertTrue(flow.repeatedReferenceIDs.isEmpty)
    }

    /// Identitas yang membuat catatan bisa dipercaya: jumlah yang tampil +
    /// jumlah yang terbuang = jumlah ketukan yang benar-benar ada.
    ///
    /// Tanpa ini, dua baris di kartu bisa sama-sama "benar" menurut
    /// hitungannya masing-masing lalu bersama-sama salah: baris atas menghitung
    /// acuan berbeda, baris bawah menghitung bintang yang diulang, dan
    /// penjumlahannya bukan apa pun yang terjadi di dunia.
    func testDisplayedNumbersAreInternallyConsistent() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        add(&flow, "sirius", yawError: 11)
        add(&flow, "arcturus", yawError: 9)

        XCTAssertEqual(flow.distinctReferenceCount, 2)
        XCTAssertEqual(flow.redundantTapCount, 1)
        XCTAssertEqual(flow.samples.count, 3)
        // Di sini kedua angka **kebetulan sama**, dan itu justru sebabnya
        // hitungan bintang lolos tanpa terlihat: untuk satu bintang yang
        // diketuk dua kali -- keadaan yang paling sering terjadi -- "1 ketukan
        // terbuang" memang kebetulan benar. Cacatnya baru terlihat pada ketukan
        // ketiga, dan tidak ada pengguna yang menunggu cukup lama untuk itu.
        XCTAssertEqual(flow.redundantTapCount, flow.repeatedReferenceIDs.count)
    }

    /// Catatan muncul sejak ketukan **kedua**, bukan sejak yang ketiga.
    ///
    /// Penjaga `> 1` alih-alih `> 0` akan lolos uji tiga ketukan di atas
    /// (karena 2 > 1) dan diam-diam menghilangkan keadaan yang paling sering:
    /// satu bintang, diketuk dua kali.
    func testHintAppearsFromTheFirstRedundantTap() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        XCTAssertNil(flow.repetitionHint, "satu ketukan memang menambah pengukuran")

        add(&flow, "sirius", yawError: 11)
        XCTAssertNotNil(flow.repetitionHint,
                        "ketukan kedua sudah tidak menambah apa pun — itu harus disebut")
    }

    /// Catatan harus bisa dibaca bareng baris hitungan di atasnya: kalau
    /// "2 acuan tercatat" + "2 ketukan terbuang", total ketukan yang terlihat
    /// di layar adalah 4, dan itu harus sama dengan yang benar-benar disimpan.
    func testTheHintAndTheCountLineAddUpToTheRealTapCount() {
        var flow = CalibrationFlow()
        for id in ["sirius", "sirius", "sirius", "vega", "deneb"] {
            add(&flow, id, yawError: 11)
        }

        XCTAssertNotNil(flow.repetitionHint)
        XCTAssertEqual(flow.distinctReferenceCount, 3)
        XCTAssertEqual(flow.redundantTapCount, 2)
        XCTAssertEqual(flow.samples.count, 5)
        XCTAssertEqual(flow.distinctReferenceCount + flow.redundantTapCount,
                       flow.samples.count)
    }

    /// Pengulangan tidak boleh diperlakukan sebagai tanda kesalahan kalau sudah siap.
    ///
    /// Setelah cukup acuan berbeda, catatan pengulangan tidak lagi berguna
    /// sebagai penanda masalah — tapi **tetap tampil**, bukan hilang, supaya
    /// kartu dan pengumuman tetap jujur.
    func testDisplayHintIsNotAnErrorWhenAlreadyReady() {
        var flow = CalibrationFlow()
        add(&flow, "sirius", yawError: 11)
        add(&flow, "vega", yawError: 9)
        add(&flow, "deneb", yawError: 13)

        XCTAssertTrue(flow.isReady)
        XCTAssertEqual(flow.distinctReferenceCount, 3)
        XCTAssertTrue(flow.repeatedReferenceIDs.isEmpty)
    }
}
