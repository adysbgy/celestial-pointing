import XCTest
@testable import PointingKit

/// Menguji bentuk gerak "pop saat kunci" — angka yang dulu ditulis empat kali
/// di dua aplikasi.
///
/// Kenapa berkas ini ada.
///
/// `response: 0.42`, `dampingFraction: 0.82`, jeda `0.08`, skala puncak `1.04`,
/// skala akhir `1` — pasangan angka itu ditulis ulang di
/// `PointingView.swift` (jam) dan `DiagnosticsView.swift` (iPhone). Kedua
/// berkas tinggal di `Apps/`, yang tidak pernah dibangun `swift-test.sh` di
/// Linux, jadi tidak ada satu pun gerbang yang bisa membandingkannya.
///
/// Uji-uji di bawah tidak mengklaim angka itu paling enak. Yang diuji adalah
/// **hubungan** antar angkanya — hubungan yang, kalau rusak, membuat pop
/// berhenti terlihat atau membuat objek terkunci tinggal pada ukuran yang
/// salah selamanya.
final class LockArrivalMotionTests: XCTestCase {

    /// Skala akhir wajib 1.
    ///
    /// Kalau `settledScale` bukan 1, objek yang pernah terkunci akan tinggal
    /// 4% lebih besar daripada objek yang tidak — dan tidak ada teks yang
    /// bisa membacanya. Ini kesalahan yang tidak terlihat saat menulis, hanya
    /// saat membandingkan dua layar.
    func testSettledScaleIsExactlyOne() {
        XCTAssertEqual(MotionPolicy.LockArrival.settledScale, 1)
    }

    /// Skala puncak harus **di atas** skala akhir, kalau tidak tidak ada pop.
    ///
    /// `peakScale == settledScale` berarti tahap pertama tidak mengubah apa
    /// pun; animasinya berjalan, memakan waktu, dan tidak terlihat. Itu bentuk
    /// "kode ada tapi tidak bekerja" yang paling mudah lolos.
    func testPeakScaleIsLargerThanSettled() {
        XCTAssertGreaterThan(MotionPolicy.LockArrival.peakScale,
                             MotionPolicy.LockArrival.settledScale)
    }

    /// Ringkasannya sepakat dengan kedua angka di atas.
    func testSettlesBackToRestAgreesWithTheNumbers() {
        XCTAssertTrue(MotionPolicy.LockArrival.settlesBackToRest)
        XCTAssertEqual(
            MotionPolicy.LockArrival.settlesBackToRest,
            MotionPolicy.LockArrival.settledScale == 1
                && MotionPolicy.LockArrival.peakScale
                    > MotionPolicy.LockArrival.settledScale)
    }

    /// Kedua tahap punya durasi yang masuk akal, dan tahap kedua **sesudah**
    /// tahap pertama.
    ///
    /// Jeda negatif akan membuat tahap kedua mulai sebelum tahap pertama —
    /// pegas yang saling menimpa, dan hasil akhirnya bergantung pada urutan
    /// internal SwiftUI, bukan pada nilai yang ditulis di sini.
    func testSettleDelayIsPositiveAndShort() {
        XCTAssertGreaterThan(MotionPolicy.LockArrival.settleDelaySeconds, 0)
        // Jeda yang lebih panjang dari respons berarti pengguna melihat objek
        // membesar, berhenti, lalu mengecil — tiga tahap, bukan dua.
        XCTAssertLessThan(MotionPolicy.LockArrival.settleDelaySeconds,
                          MotionPolicy.LockArrival.responseSeconds)
    }

    /// Redaman di antara 0 dan 1: memantul sedikit, lalu tenang.
    ///
    /// Di atas 1 pegangannya kritis-berlebih dan pop-nya hilang; di 0 ia
    /// berosilasi tanpa henti — dan osilasi tanpa henti adalah gerak yang
    /// seharusnya dimatikan saat Reduce Motion, jadi ia tidak boleh jadi
    /// bawaan.
    func testDampingIsUnderdampedButPositive() {
        XCTAssertGreaterThan(MotionPolicy.LockArrival.dampingFraction, 0)
        XCTAssertLessThan(MotionPolicy.LockArrival.dampingFraction, 1)
    }

    /// Responsnya singkat — ini umpan balik, bukan transisi layar.
    ///
    /// Ambang 1 detik dipilih sebagai batas "masih terasa sebagai reaksi".
    /// Lebih dari itu, pengguna sudah mengalihkan pandangan sebelum pop
    /// selesai, dan yang tersisa hanya gerak yang tidak diminta.
    func testResponseIsBrief() {
        XCTAssertGreaterThan(MotionPolicy.LockArrival.responseSeconds, 0)
        XCTAssertLessThan(MotionPolicy.LockArrival.responseSeconds, 1)
    }
}
