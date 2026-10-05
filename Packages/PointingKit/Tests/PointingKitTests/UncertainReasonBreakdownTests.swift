import XCTest
import CelestialEngine
@testable import PointingKit

/// Rincian **sebab** keraguan per sampel — yang sampai ke layar.
///
/// **Premis siklus ini.** `ConfidenceTrace.diagnosis` sengaja meringkas:
/// ia hanya menyebut sebab yang **mendominasi** (lebih dari separuh sampel
/// ragu), dan kalau tidak ada yang mendominasi ia menyebut semua sebab yang
/// seri di puncak. Itu keputusan yang benar untuk satu kalimat. Tapi
/// keputusan itu **membuang informasi yang bisa dipakai**:
///
/// - Saat satu sebab mendominasi, semua sebab **lain** hilang dari kalimat.
/// - `diagnosisNoMeasurableCause` ("belum ada sebab yang terukur") tampil
///   saat tidak ada yang mendominasi dan tidak ada seri — padahal
///   `tooFar`/`ambiguous` bisa tetap ada dengan hitungan kecil.
///
/// Jadi penguji yang hanya membaca diagnosis bisa menyimpulkan "ragunya
/// karena kalibrasi" padahal sebagian sampel ragu karena ambiguitas
/// katalog — dua petunjuk perbaikan yang saling meniadakan.
///
/// Yang ditambahkan di sini **bukan** perbaikan atas `diagnosis`; itu sudah
/// benar dan tidak boleh diubah. Yang ditambahkan adalah rincian yang menjaga
/// pertanyaan berbeda: *sebab mana yang muncul, seberapa sering, dan apakah
/// satu sebab benar-benar mendominasi.*
final class UncertainReasonBreakdownTests: XCTestCase {

    // MARK: - Pembantu

    /// Bangun jejak dengan hitungan ragu yang disengaja.
    ///
    /// Ketiganya sengaja dibedakan lewat **dua variabel** yang terpisah,
    /// karena itu justru yang sedang dijaga:
    ///
    /// - `tooFar` — kandidat terbaik **jauh**: 9° pada sigma 1° (rasio 9,
    ///   jauh di atas `maxSeparationSigma`).
    /// - `ambiguous` — kandidat terbaik **dekat** (4° pada sigma 10°, rasio
    ///   0,4) **dan** ada tetangga di dalam `ambiguitySigma` σ
    ///   (`nearestNeighbourDeg` 1° pada sigma 10° → rasio 0,1).
    /// - `none` — kandidat terbaik dekat **tanpa** tetangga: 4° pada sigma 10°
    ///   tanpa `nearestNeighbourDeg`.
    ///
    /// Kalau `nearestNeighbourDeg` diabaikan, `ambiguous` ikut berubah jadi
    /// `none` dan seluruh hitungan di bawah berubah bentuk — bukan hanya
    /// angkanya.
    private func trace(uncertainTooFar: Int, uncertainAmbiguous: Int,
                       uncertainNone: Int = 0) -> ConfidenceTrace {
        let trace = ConfidenceTrace()
        let at = Date()
        for _ in 0..<uncertainTooFar {
            trace.record(state: .uncertain, level: .low, objectID: "a",
                         objectName: "A", separationDeg: 9, sigmaDeg: 1,
                         nearestNeighbourDeg: 1, at: at)
        }
        for _ in 0..<uncertainAmbiguous {
            trace.record(state: .uncertain, level: .low, objectID: "a",
                         objectName: "A", separationDeg: 4, sigmaDeg: 10,
                         nearestNeighbourDeg: 1, at: at)
        }
        for _ in 0..<uncertainNone {
            trace.record(state: .uncertain, level: .low, objectID: "a",
                         objectName: "A", separationDeg: 4, sigmaDeg: 10,
                         nearestNeighbourDeg: nil, at: at)
        }
        return trace
    }

    private func breakdown(_ trace: ConfidenceTrace) -> UncertainReasonBreakdown {
        UncertainReasonBreakdown(counts: trace.uncertainReasonCounts(),
                                 policy: ConfidencePolicy())
    }

    // MARK: - Yang dijaga

    /// Rincian harus **tidak pernah kosong** saat ada sampel ragu, walau
    /// `diagnosis` meringkasnya jadi "sebab bercampur".
    ///
    /// Inilah inti siklus ini: `diagnosis` untuk data ini menyebut **dua**
    /// sebab dalam satu kalimat dan tidak menyebut jumlah sama sekali.
    /// Rincianlah yang membuat hitungan itu terlihat.
    func testEveryUncertainSampleIsAccountedFor() {
        let t = trace(uncertainTooFar: 2, uncertainAmbiguous: 2)
        let breakdown = self.breakdown(t)

        XCTAssertEqual(breakdown.totalUncertain, 4)
        // Tidak boleh ada sampel yang hilang dari rincian.
        XCTAssertEqual(breakdown.rows.reduce(0) { $0 + $1.count }, 4)
        // `diagnosis` untuk data yang sama tidak menyebut jumlah apa pun.
        XCTAssertFalse(t.diagnosis().contains("4"))
    }

    /// Urutan baris harus mengikuti **urutan deklarasi enum**, bukan urutan
    /// `Dictionary` — supaya tampilan tidak berubah-ubah antara dua
    /// peluncuran untuk data yang sama. Alasan yang sama dengan
    /// `tiedUncertainReasons`: alat ukur yang menunjuk perbaikan berbeda tiap
    /// kaliIJUK reopened tidak bisa dipercaya.
    func testRowOrderFollowsEnumDeclarationNotDictionaryOrder() {
        let t = trace(uncertainTooFar: 3, uncertainAmbiguous: 1, uncertainNone: 1)
        let declared: [ConfidenceTrace.UncertainReason] = [.tooFar, .ambiguous, .none]
        let expected = declared.filter { reason in
            t.uncertainReasonCounts()[reason].map { $0 > 0 } ?? false
        }

        // Dibangun ulang berkali-kali: `Dictionary` di-seed per proses, jadi
        // satu sampling bisa kebetulan berurutan. Yang dijaga adalah
        // kesetaraan dengan urutan deklarasi, bukan satu kali pengurutan.
        for _ in 0..<20 {
            XCTAssertEqual(self.breakdown(t).rows.map(\.reason), expected)
        }
        XCTAssertEqual(expected, [.tooFar, .ambiguous, .none])
    }

    /// Urutan **tidak boleh** ikut besar-kecilnya hitungan.
    ///
    /// Ini mutasi yang paling mungkin terjadi tanpa disengaja: "`sorted`
    /// supaya yang utama tampil dulu" terdengar seperti peningkatan UX. Tapi ia
    /// membuat urutan daftar ikut berubah setiap kali hitungan berubah — jadi
    /// rekaman yang sama menampilkan daftar berbeda, dan pengguna yang
    /// membandingkan dua tangkapan layar tidak bisa mencocokkan barisnya.
    ///
    /// Plus ia bertabrakan dengan `.none`: `.none` tidak pernah boleh jadi
    /// "penyebab utama", dan mengurutkan menurut hitungan membuatnya paling
    /// atas justru membuatnya terlihat paling penting.
    func testRowOrderDoesNotFollowMagnitude() {
        // `ambiguous` paling banyak, tapi `tooFar` yang ditulis pertama.
        let breakdown = self.breakdown(trace(uncertainTooFar: 1,
                                             uncertainAmbiguous: 4))
        XCTAssertEqual(breakdown.rows.map(\.reason), [.tooFar, .ambiguous])
        XCTAssertEqual(breakdown.rows.map(\.count), [1, 4])

        // `.none` paling banyak — dan tetap tidak boleh mendahului yang lain
        // hanya karena jumlahnya.
        let withNone = self.breakdown(trace(uncertainTooFar: 1,
                                            uncertainAmbiguous: 0,
                                            uncertainNone: 9))
        XCTAssertEqual(withNone.rows.map(\.reason), [.tooFar, .none])
    }

    /// Baris dengan hitungan nol **tidak boleh tampil**.
    ///
    /// "0× ambiguitas katalog" menyatakan ada kategori yang diperiksa dan
    /// kosong — padahal tidak ada bukti kategori itu pernah terjadi. Baris
    /// harus hanya berisi sebab yang benar-benar terlihat.
    func testZeroCountReasonsAreNotListed() {
        let t = trace(uncertainTooFar: 2, uncertainAmbiguous: 0)
        let breakdown = self.breakdown(t)

        XCTAssertEqual(breakdown.rows.map(\.reason), [.tooFar])
        XCTAssertFalse(breakdown.rows.contains { $0.count == 0 })
    }

    /// Tidak ada sampel ragu → tidak ada baris sama sekali.
    ///
    /// Tanpa syarat ini, rincian akan tampil sebagai daftar kosong tepat
    /// setelah kalimat diagnosis, dan kotak kosong di layar diagnostik
    /// terbaca sebagai "ada sesuatu yang belum bisa ditampilkan" — berbeda
    /// dari "tidak ada yang perlu ditampilkan".
    func testNoUncertainSamplesMeansNoRows() {
        let trace = ConfidenceTrace()
        trace.record(state: .lock, level: .high, objectID: "a", objectName: "A",
                     separationDeg: 1, sigmaDeg: 10, at: Date())
        let breakdown = self.breakdown(trace)

        XCTAssertTrue(breakdown.rows.isEmpty)
        XCTAssertEqual(breakdown.totalUncertain, 0)
        XCTAssertTrue(breakdown.isEmpty)
    }

    /// `hasDominantReason` harus mengikuti **ambang yang sama** dengan
    /// `diagnosis`, yaitu lebih dari separuh — bukan sekadar paling banyak.
    ///
    /// Bedanya nyata: 2 dari 2 adalah "paling banyak" tapi **seri**, dan seri
    /// justru keadaan yang tidak boleh menampilkan satu sebab sendirian.
    /// Kalau ambangnya melonggar, rincian menunjuk satu sebab sementara
    /// `diagnosis` menyebut dua — dua jawaban untuk data yang sama.
    func testDominanceUsesTheSameMoreThanHalfThresholdAsDiagnosis() {
        let tied = self.breakdown(trace(uncertainTooFar: 2, uncertainAmbiguous: 2))
        XCTAssertFalse(tied.hasDominantReason, "2 dari 2 adalah seri, bukan dominasi")

        let dominant = self.breakdown(trace(uncertainTooFar: 3, uncertainAmbiguous: 1))
        XCTAssertTrue(dominant.hasDominantReason)
        XCTAssertEqual(dominant.dominantReason, .tooFar)
    }

    /// `.none` ("tanpa sebab terukur") **tidak boleh** menjadi sebab yang
    /// mendominasi.
    ///
    /// Ia berbeda sifat: bukan sebab, melainkan ketiadaan sebab yang
    /// terukur. `diagnosis` dengan sengaja mengecualikannya dari dominasi;
    /// kalau rincian mengizinkan, layar akan menampilkan "tanpa sebab
    /// terukur: 3 dari 3" seolah-olah itu sebab yang paling besar.
    func testNoneIsNeverTheDominantReason() {
        let t = trace(uncertainTooFar: 0, uncertainAmbiguous: 0, uncertainNone: 3)
        let breakdown = self.breakdown(t)

        XCTAssertEqual(breakdown.rows.map(\.reason), [.none])
        XCTAssertFalse(breakdown.hasDominantReason)
        XCTAssertNil(breakdown.dominantReason)
    }

    /// Sepakat 1 dari 1 **adalah** dominan — mengunci arah ambang.
    ///
    /// Uji seri di atas sudah menyingkirkan batas bawah; uji ini menyingkirkan
    /// batas atas. Dengan keduanya, `>=` dan `>` sama-sama tidak bisa lolos.
    func testUnanimityIsDominant() {
        let breakdown = self.breakdown(trace(uncertainTooFar: 1, uncertainAmbiguous: 0))
        XCTAssertTrue(breakdown.hasDominantReason)
        XCTAssertEqual(breakdown.dominantReason, .tooFar)
    }

    /// Ambiguitas **hanya** berlaku bila ada tetangga di dalam
    /// `ambiguitySigma` σ. Tanpa tetangga, sampel itu **bukan** `ambiguous`.
    ///
    /// Ini menjaga klasifikasi yang jadi dasar semua hitungan di atas: kalau
    /// `nearestNeighbourDeg` diabaikan, setiap ragu jadi `tooFar`/`none`,
    /// `ambiguous` tidak pernah muncul — dan rincian menampilkan penyebab
    /// yang tidak pernah terjadi, tepat seperti `diagnosis` yang sudah
    /// ini.
    func testAmbiguityNeedsANeighbour() {
        let withNeighbour = self.breakdown(trace(uncertainTooFar: 0,
                                                 uncertainAmbiguous: 1))
        XCTAssertEqual(withNeighbour.rows.map(\.reason), [.ambiguous])

        // Tanpa tetangga, jarak kandidat terbaik **sama persis** — hanya
        // variabel tetangganya yang dibuang.
        let withoutNeighbour = self.breakdown(trace(uncertainTooFar: 0,
                                                    uncertainAmbiguous: 0,
                                                    uncertainNone: 1))
        XCTAssertEqual(withoutNeighbour.rows.map(\.reason), [.none])
        XCTAssertFalse(withoutNeighbour.rows.contains { $0.reason == .ambiguous })
    }

    // MARK: - Teks

    /// Nama tiap sebab harus lewat katalog, berbahasa Indonesia.
    func testReasonLabelsComeFromTheCatalog() {
        XCTAssertEqual(ConfidenceTrace.UncertainReason.tooFar.label,
                       "Kandidat terlalu jauh")
        XCTAssertEqual(ConfidenceTrace.UncertainReason.ambiguous.label,
                       "Tetangga terlalu dekat")
        XCTAssertEqual(ConfidenceTrace.UncertainReason.none.label,
                       "Tanpa sebab terukur")
    }

    /// Jumlah harus punya bentuk **satu kunci** "%lld dari %lld".
    ///
    /// Dua kunci terpisah (jumlah + kata "dari") akan memungkinkan
    /// terjemahan menyusun "2 of 4" atau "4 dari 2" — urutan harus
    /// dikendalikan satu tempat, bukan oleh dua string yang disambung view.
    func testCountTextUsesOneFormatKey() {
        XCTAssertEqual(RowCountText(2, of: 7).text, "2 dari 7")
        XCTAssertEqual(RowCountText(1, of: 3).text, "1 dari 3")
    }

    /// Baris rincian harus membawa jumlah **dan** penyebut, dan keduanya
    /// harus lewat `RowCountText` yang sama.
    ///
    /// Ini yang dipakai view: kalau baris hanya mengekspos `count`,
    /// pemanggil akan menyusun "2" tanpa penyebut — dan penyebut itu yang
    /// membuat "2" terbaca sebagai minoritas, bukan sebab utama.
    func testRowCarriesBothTheCountAndItsTotal() {
        let breakdown = UncertainReasonBreakdown(
            counts: [.tooFar: 2, .ambiguous: 5], policy: ConfidencePolicy())
        // Baris pertama adalah `tooFar` (urutan deklarasi), bukan yang
        // terbesarnya — dan itu justru hal yang harus terlihat di sini.
        // Kalau baris diurutkan menurut besar-kecilnya, urutannya ikut
        // berubah tiap kali hitungan berubah, dan rekaman yang sama
        // menampilkan daftar berbeda.
        XCTAssertEqual(breakdown.rows.map(\.count), [2, 5])
        let first = breakdown.rows[0]
        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(first.total, 7)
        XCTAssertEqual(first.countText.text, "2 dari 7")
    }
}