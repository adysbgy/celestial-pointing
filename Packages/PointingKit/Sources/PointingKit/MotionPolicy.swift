import Foundation

/// Apakah animasi boleh berjalan — **satu aturan** untuk denyut kontinu dan
/// transisi sesaat.
///
/// **Kenapa ini ada di `PointingKit`, bukan di view.** Dua alasan yang saling
/// menguatkan:
///
/// 1. **Tidak bisa diuji di lapisan lain.** `accessibilityReduceMotion` dan
///    `isLuminanceReduced` hanya ada di SwiftUI, dan `Canvas`/`TimelineView`
///    tidak bisa dibangun di Linux. Kalau aturan ini tinggal di view, satu-
///   -satunya penjaganya adalah ingatan orang yang sedang menulis — persis
///    yang sudah terbukti gagal untuk Dynamic Type, `.system(size:)`, dan
///    font semantik.
/// 2. **Dua bentuk gerak, satu alasan.** "Gerak berulang tanpa akhir"
///    (denyut glow) dan "gerak sekali lalu berhenti" (pop saat kunci) punya
///    implementasi berbeda di SwiftUI — satu `TimelineView`, satu
///    `withAnimation` — tapi **jawaban accessibility-nya sama**: kalau
///    pengguna minta reduksi gerak, keduanya harus berhenti. Menghentikannya
///    di dua tempat berarti dua tempat yang bisa berbeda pendapat, dan
///    keduanya terlihat benar secara terpisah.
///
/// **Yang bukan bagian dari aturan ini.** `isSceneActive` hanya berlaku untuk
/// denyut: layar tidak aktif bukan alasan-accessibility, cuma alasan-baterai.
/// Pop saat kunci dipicu aksi pengguna yang sedang menatap, jadi layar harus
/// aktif saat itu terjadi — tapi pop tetap boleh jalan di layar yang normal.
/// Kalau keduanya memakai ambang yang sama, pop ikut hilang setiap kali app
/// kehilangan fokus, dan umpan balik "kunci berhasil" ikut hilang.
public struct MotionPolicy: Equatable, Sendable {

    /// Pengguna meminta pengurangan gerak (Settings > Accessibility).
    public var reduceMotion: Bool
    /// Layar redup Always-On.
    public var isLuminanceReduced: Bool
    /// Scene sedang aktif (terlihat di layar).
    public var isSceneActive: Bool

    public init(reduceMotion: Bool,
                isLuminanceReduced: Bool,
                isSceneActive: Bool) {
        self.reduceMotion = reduceMotion
        self.isLuminanceReduced = isLuminanceReduced
        self.isSceneActive = isSceneActive
    }

    /// Denyut berulang (glow bintang) boleh berjalan.
    ///
    /// Tidak boleh kalau pengguna meminta reduksi gerak, karena denyut tidak
    /// pernah benar-benar berhenti — ia berulang terus selama layar menyala,
    /// yang persis yang diminta untuk dihentikan.
    ///
    /// Layar tidak aktif ikut mematikan: denyut di latar belakang hanya
    /// membebani baterai tanpa pernah terlihat. Ini **alasan baterai**, bukan
    /// accessibility, dan itu sebabnya ia tidak ikut masuk ambang transisi.
    public var allowsContinuousMotion: Bool {
        !reduceMotion && !isLuminanceReduced && isSceneActive
    }

    /// Transisi sesaat (pop saat kunci) boleh berjalan.
    ///
    /// Hanya dua hal yang boleh menghentikannya, dan layar tidak aktif bukan
    /// salah satunya: transisi dipicu aksi pengguna, jadi saat transisi
    /// berjalan layarnya aktif.
    public var allowsTransitions: Bool {
        !reduceMotion && !isLuminanceReduced
    }

    /// Laju denyut, dalam radian per detik.
    ///
    /// Angka tunggal yang di sini supaya "seberapa cepat berdenyut" punya satu
    /// jawaban. Nilai bakunya **bukan** di view, karena perubahan laju di view
    /// tidak akan pernah bisa diuji di Linux.
    public static let pulseRateRadiansPerSecond: Double = 1.1

    /// Fase denyut untuk waktu yang sudah lewat, dalam radian.
    ///
    /// Mengembalikan **tepat nol** saat gerak kontinu tidak boleh berjalan,
    /// bukan amplitude kecil. Bolak-balik kecil itu kelihatan seperti pilihan:
    /// view membaca `sin(0) = 0`, jadi optiknya diam — tapi nilainya tidak nol,
    /// pemeriksaan mana pun yang berburu "apakah denyutnya benar-benar mati"
    /// akan melihat angka yang bergerak. Satu nilai, satu arti.
    ///
    /// - Parameter elapsedSeconds: waktu sejak denyut dimulai. Nilai
    ///   negatif dijepit ke nol supaya jam yang belum dimulai tidak berdenyut
    ///   ke belakang.
    public func pulsePhase(elapsedSeconds: Double) -> Double {
        guard allowsContinuousMotion else { return 0 }
        return max(0, elapsedSeconds) * Self.pulseRateRadiansPerSecond
    }
}