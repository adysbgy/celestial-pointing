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

    // MARK: - Opasitas pop (fade yang dulu tidak pernah terjadi)

    /// Kedua ujung pop opasitas wajib **berbeda**, kalau tidak tidak ada fade.
    ///
    /// **Cacat yang ditutup uji ini.** Kedua app memegang
    /// `@State private var appearOpacity: Double = 1` dan menulis
    /// `appearOpacity = 1` di dalam `withAnimation` — animasi yang kedua
    /// ujungnya sama persis. `.opacity(appearOpacity)` karena itu selalu 1,
    /// dan yang tersisa hanya `scaleEffect`: kartu membesar tanpa memudar.
    /// Docstring di kedua view menjanjikan "memudar + membesar", jadi
    /// dokumentasinya benar-benar menggambarkan perilaku yang tidak ada.
    ///
    /// Kenapa tidak ada gerbang yang menangkapnya: harness mutasi gerak
    /// (`bukti-mutasi-gerak-angka.py`) hanya memutasi `appearScale`, dan
    /// `swift-ui-lint.sh` tidak punya aturan yang membaca opasitas. Angka
    /// yang tidak pernah diperiksa adalah angka yang boleh berarti apa saja.
    func testPopActuallyMovesOpacity() {
        XCTAssertTrue(MotionPolicy.LockArrival.popMovesOpacity,
                      "peakOpacity == settledOpacity berarti withAnimation "
                      + "berjalan tanpa menggerakkan satu piksel")
        XCTAssertLessThan(MotionPolicy.LockArrival.peakOpacity,
                          MotionPolicy.LockArrival.settledOpacity)
    }

    /// Kartu yang sudah tenang wajib pekat penuh.
    ///
    /// Nilai akhir selain 1 meninggalkan kartu yang pernah terkunci lebih
    /// transparan daripada kartu yang tidak pernah — cacat yang sama bentuknya
    /// dengan `settledScale != 1`, dan sama tidak terbacanya dari teks.
    func testSettledOpacityIsExactlyOne() {
        XCTAssertEqual(MotionPolicy.LockArrival.settledOpacity, 1)
    }

    /// Opasitas puncak harus di dalam 0…1: ia opasitas, bukan angka bebas.
    ///
    /// Nilai di atas 1 dijepit diam-diam oleh Core Animation, jadi angkanya
    /// akan "bekerja" sambil berarti sesuatu yang lain — dan
    /// `popMovesOpacity` tetap benar. Yang diuji di sini adalah bahwa angka
    /// itu sah sebagai opasitas.
    func testPeakOpacityIsAValidOpacity() {
        XCTAssertGreaterThanOrEqual(MotionPolicy.LockArrival.peakOpacity, 0)
        XCTAssertLessThanOrEqual(MotionPolicy.LockArrival.peakOpacity, 1)
    }

    /// Ringkasannya sepakat dengan kedua angkanya — sama seperti
    /// `settlesBackToRest`, supaya penanda tidak bisa berbohong sendirian.
    func testPopMovesOpacityAgreesWithTheNumbers() {
        XCTAssertEqual(
            MotionPolicy.LockArrival.popMovesOpacity,
            MotionPolicy.LockArrival.peakOpacity
                < MotionPolicy.LockArrival.settledOpacity
                && MotionPolicy.LockArrival.peakOpacity >= 0)
    }
}
