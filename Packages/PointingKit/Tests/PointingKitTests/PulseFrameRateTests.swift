import XCTest
@testable import PointingKit

/// Menguji angka **penyegaran** denyut — ongkos baterai, bukan rasa.
///
/// Kenapa berkas ini ada.
///
/// `TimelineView(.animation(minimumInterval: 1.0 / 30.0))` ditulis tangan di
/// tiga layar (`PointingView`, `OnboardingView`, `DiagnosticsView`). Angka itu
/// bukan angka tampilan: `TimelineView` menyegarkan **seluruh** `Canvas`, jadi
/// setiap frame menggambar ulang planet, pita, cincin, dan kabut yang
/// pikselnya tidak berubah. Di jam tangan, itu baterai.
///
/// Diukur sebelum aturan ini ditulis: mengubah `1.0 / 30.0` menjadi
/// `1.0 / 60.0` di `DiagnosticsView.swift` membuat **seluruh 47 aturan UI
/// lulus** (exit 0). Jadi tidak ada gerbang yang membaca angka ini, dan tidak
/// ada uji Linux yang bisa menjangkaunya — `Apps/` tidak pernah dibangun di
/// sini. Yang bisa dilakukan adalah memindahkan angkanya ke model yang diuji,
/// lalu menuntut `Apps/` membacanya (Aturan 48).
///
/// Uji-uji di bawah **tidak** mengklaim 30 fps terasa mulus di perangkat.
/// Yang diuji adalah hubungan antar angkanya: interval harus benar-benar
/// kebalikan lajunya, dan laju itu harus cukup rapat untuk denyut yang
/// lambat — bukan sebaliknya.
final class PulseFrameRateTests: XCTestCase {

    /// Interval adalah **kebalikan** laju, bukan angka kedua yang bisa
    /// menyimpang.
    ///
    /// Kalau keduanya ditulis terpisah (mis. `rate = 30` dan
    /// `interval = 1.0 / 24.0`), keduanya tetap "masuk akal" sendiri-sendiri
    /// dan tidak ada yang bisa membacanya. Yang menangkapnya hanya
    /// perkalian ini.
    func testFrameIntervalIsTheReciprocalOfTheRate() {
        XCTAssertEqual(MotionPolicy.pulseFrameInterval
                        * MotionPolicy.pulseFrameRateHertz,
                       1.0, accuracy: 1e-12,
                       "interval dan laju harus saling membatalkan tepat")
        XCTAssertEqual(MotionPolicy.pulseFrameInterval,
                       1.0 / MotionPolicy.pulseFrameRateHertz,
                       accuracy: 1e-12)
    }

    /// Intervalnya positif dan masuk akal sebagai periode frame.
    ///
    /// Interval nol berarti `TimelineView` diminta menyegarkan sesering
    /// mungkin — itu bukan 30 fps, itu seluruh CPU. Interval ≥ 1 detik berarti
    /// denyut yang diperbarui sekali per detik, yang terlihat sebagai lompatan.
    func testFrameIntervalIsAPlausibleFramePeriod() {
        XCTAssertGreaterThan(MotionPolicy.pulseFrameInterval, 0)
        XCTAssertLessThan(MotionPolicy.pulseFrameInterval, 1.0)
        XCTAssertGreaterThan(MotionPolicy.pulseFrameRateHertz, 0)
    }

    /// Laju frame harus cukup rapat untuk denyut yang **lambat**.
    ///
    /// Ini hubungan yang membuat kedua angka itu saling bergantung, dan
    /// satu-satunya alasan keduanya hidup di berkas yang sama. Denyut
    /// berjalan pada `pulseRateRadiansPerSecond`; satu siklus penuh butuh
    /// `2π / laju` detik. Kalau laju frame diturunkan jauh (mis. 2 fps untuk
    /// menghemat baterai), satu siklus hanya mendapat beberapa frame dan
    /// denyut berubah jadi kedipan — persis yang tidak boleh terjadi.
    ///
    /// Ambang 24 frame per siklus dipilih sebagai batas bawah \"masih terlihat
    /// sebagai gerak halus\"; nilai sebenarnya jauh di atasnya.
    func testFrameRateKeepsASlowPulseSmooth() {
        let cycleSeconds = 2 * Double.pi / MotionPolicy.pulseRateRadiansPerSecond
        let framesPerCycle = cycleSeconds * MotionPolicy.pulseFrameRateHertz
        XCTAssertGreaterThanOrEqual(framesPerCycle, 24,
                                    "denyut akan terlihat sebagai kedipan, "
                                    + "bukan denyut: hanya \(framesPerCycle) "
                                    + "frame per siklus")
    }

    /// Laju frame tidak boleh lebih tinggi dari yang bisa ditampilkan layar
    /// jam, karena frame di atas itu dibuang — baterai terpakai, gambar sama.
    ///
    /// 60 adalah batas atas yang dipakai repo ini untuk layar jam; angka di
    /// atasnya hanya masuk akal untuk perangkat yang benar-benar
    /// menyegarkan lebih cepat, dan tidak ada di sini.
    func testFrameRateStaysWithinWhatTheDisplayCanShow() {
        XCTAssertLessThanOrEqual(MotionPolicy.pulseFrameRateHertz, 60)
    }

    /// Angka ini **tidak** boleh ikut berubah saat gerak dimatikan.
    ///
    /// Interval frame adalah sifat penyegar, bukan keputusan aksesibilitas.
    /// Yang memutuskan berhenti adalah `allowsContinuousMotion` (yang
    /// melepas `TimelineView` seluruhnya); kalau intervalnya ikut bergantung
    /// pada `reduceMotion`, dua tempat memutuskan hal yang sama dan keduanya
    /// bisa berbeda pendapat.
    func testFrameIntervalDoesNotDependOnAccessibilityState() {
        let reduced = MotionPolicy(reduceMotion: true,
                                   isLuminanceReduced: true,
                                   isSceneActive: false)
        // Tidak ada API yang menerima policy di sini dengan sengaja: kalau
        // kelak ada, uji ini yang harus diubah lebih dulu, bukan diam-diam.
        XCTAssertEqual(MotionPolicy.pulseFrameInterval,
                       1.0 / MotionPolicy.pulseFrameRateHertz,
                       accuracy: 1e-12)
        // Dan policy yang mematikan gerak memang mematikan denyut — supaya
        // `TimelineView` tidak pernah terpasang di keadaan itu.
        XCTAssertFalse(reduced.allowsContinuousMotion)
    }
}
