import XCTest

@testable import PointingKit

/// Satu aturan untuk dua bentuk gerak: denyut berulang dan transisi sesaat.
///
/// **Kelas cacat yang dijaga di sini.** Gerbang di repo ini sudah beberapa
/// kali menangkap "hijau yang tidak hijau" pada aturan yang tidak punya
/// penjaga: Dynamic Type kembali muncul di berkas yang ditambahkan belakangan,
/// `.system(size:)` lolos ke complication, aturan penyapu UI buta terhadap
/// metadata WidgetKit. Semuanya benar secara terpisah — aturannya ada,
/// penerapannya juga ada — tapi tidak ada satu pun laporan kalau ada yang
/// lupa.
///
/// Gerbang motion adalah contoh paling bersih dari kelas itu: denyut glow
/// sudah punya penjelasan baterainya (`isSceneActive`), dan
/// `ReducedLuminanceView` sudah punya percabangan Always-On-nya — tapi
/// `accessibilityReduceMotion` tidak pernah ada di mana pun. Jadi bentuk
/// yang paling berulang dan paling terlihat (glow berdenyut terus-menerus)
/// justru yang paling tidak bisa dihentikan oleh pengguna yang meminta
/// berhenti.
///
/// Yang tidak bisa diuji di view: `accessibilityReduceMotion` dan
/// `TimelineView` hanya ada di SwiftUI. Karena itu aturannya dipindah ke sini,
/// dan view tidak boleh punya ambangnya sendiri.
final class MotionPolicyTests: XCTestCase {

    private func policy(reduceMotion: Bool = false,
                        reduced: Bool = false,
                        active: Bool = true) -> MotionPolicy {
        MotionPolicy(reduceMotion: reduceMotion,
                     isLuminanceReduced: reduced,
                     isSceneActive: active)
    }

    // MARK: - Yang harus dihentikan

    /// Aturan dasar: pengguna minta reduksi gerak, denyut berhenti.
    func testReduceMotionStopsThePulse() {
        XCTAssertFalse(policy(reduceMotion: true).allowsContinuousMotion,
                       "denyut berulang adalah motion yang paling perlu dihentikan")
    }

    /// Redup (Always-On) ikut mematikan denyut — aturan ini sudah ada sebelum
    /// `MotionPolicy` ada, jadi dijaga agar tidak hilang saat dipindah.
    func testReducedLuminanceStopsThePulse() {
        XCTAssertFalse(policy(reduced: true).allowsContinuousMotion)
    }

    /// Layar tidak aktif mematikan denyut: alasan baterai, bukan accessibility.
    /// Dijaga eksplisit karena ia yang **boleh** jadi satu-satunya pembeda
    /// antara dua bentuk gerak.
    func testInactiveSceneStopsThePulse() {
        XCTAssertFalse(policy(active: false).allowsContinuousMotion)
    }

    /// Fase denyut harus **tepat nol**, bukan amplitude kecil.
    ///
    /// Ini yang membuat penyimpangan tersembunyi: `sin(0)` sudah nol, jadi
    /// view yang salah membaca "denyut" sebagai `sin(phase * kecil)` akan
    /// tetap berdenyut diam-diam. Menguji `allowsContinuousMotion` saja tidak
    /// menangkapnya — nilainya sudah benar sementara angka yang sampai ke
    /// `sin()` belum tentu.
    func testPulsePhaseIsExactlyZeroWhenContinuousMotionIsDenied() {
        let denied = [policy(reduceMotion: true),
                      policy(reduced: true),
                      policy(active: false)]
        for p in denied {
            for seconds in [0.0, 1.0, 17.3, 3600.0] {
                XCTAssertEqual(p.pulsePhase(elapsedSeconds: seconds), 0,
                               "fase denyut harus persis nol, bukan kecil")
            }
        }
    }

    // MARK: - Yang harus tetap jalan

    /// Kasus normal: denyut dan transisi boleh jalan.
    func testNormalScreenAllowsBothForms() {
        let p = policy()
        XCTAssertTrue(p.allowsContinuousMotion)
        XCTAssertTrue(p.allowsTransitions)
    }

    /// Transisi **tidak** boleh ikut hilang saat scene tidak aktif.
    ///
    /// Ini kesalahan yang paling mudah dibuat dengan "satu ambang untuk dua
    /// pertanyaan": `isSceneActive` benar untuk denyut, dan menerapkannya
    /// juga ke transisi terlihat logis — tapi efeknya umpan balik "kunci
    /// berhasil" ikut hilang tepat saat pengguna tidak melihat layar, dan
    /// tidak ada yang bisa mengetahuinya dari layar.
    func testInactiveSceneDoesNotKillTransitions() {
        let p = policy(active: false)
        XCTAssertFalse(p.allowsContinuousMotion,
                       "denyut di latar belakang hanya membebani baterai")
        XCTAssertTrue(p.allowsTransitions,
                      "transisi dipicu aksi pengguna, jadi layar aktif saat ia berjalan")
    }

    /// Redup mematikan kedua bentuk: transisi di layar yang system-nya sudah
    /// meredupkan hanya membuang baterai.
    func testReducedLuminanceStopsTransitionsToo() {
        XCTAssertFalse(policy(reduced: true).allowsTransitions)
    }

    // MARK: - Sifat fase denyut

    /// Fase denyut harus **monoton** saat boleh berdenyut: waktu lebih lama
    /// berarti fase lebih besar. Kalau tidak, view yang memotong fase (atau
    /// membungkusnya) bisa membuat denyut berhenti sendiri tanpa aturan
    /// apa pun yang berubah.
    func testPulsePhaseGrowsWithElapsedTime() {
        let p = policy()
        var previous = -1.0
        for seconds in [0.0, 0.5, 1.0, 4.0, 60.0] {
            let phase = p.pulsePhase(elapsedSeconds: seconds)
            XCTAssertGreaterThan(phase, previous,
                                 "fase harus naik monoton dengan waktu")
            previous = phase
        }
    }

    /// Laju denyut yang keliru diam-diam: 1,1 rad/dtk berarti satu denyut
    /// penuh tiap ~5,7 detik. Ini angka yang sampai ke mata pengguna setiap
    /// detik, jadi harus punya satu sumber, dan sumber itu harus diuji.
    func testPulseRateProducesOneFullBeatPerCycle() {
        let cycleSeconds = 2 * Double.pi / MotionPolicy.pulseRateRadiansPerSecond
        XCTAssertEqual(cycleSeconds, 5.712, accuracy: 0.01,
                       "satu denyut penuh harus ±0,01 detik agar tidak terasa lambat")
    }

    /// Waktu negatif dijepit ke nol: jam yang belum dimulai (atau jam device
    /// yang mundur) tidak boleh membuat denyut berputar ke belakang.
    func testNegativeElapsedTimeIsClamped() {
        let p = policy()
        XCTAssertEqual(p.pulsePhase(elapsedSeconds: -42.0),
                       p.pulsePhase(elapsedSeconds: 0.0))
    }

    /// Fase yang dihitung harus bisa diulang persis: denyut yang
    /// menggantung atau melompat karena jam hilang, lalu diputar ulang tiap
    /// frame, terlihat seperti kedipan — bukan denyut.
    func testPulsePhaseIsDeterministicForTheSameElapsedTime() {
        let p = policy()
        let a = p.pulsePhase(elapsedSeconds: 12.34)
        for _ in 0..<20 {
            XCTAssertEqual(p.pulsePhase(elapsedSeconds: 12.34), a)
        }
    }
}