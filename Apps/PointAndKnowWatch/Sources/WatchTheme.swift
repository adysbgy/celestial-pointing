import SwiftUI

/// Ukuran bersama supaya semua layar jam terasa satu aplikasi.
///
/// Palet warna per nada (`PointingTone.color`) sudah dipindah ke
/// `Apps/Shared/NightMode.swift` supaya jam **dan** iPhone memakai satu sumber
/// yang sama — dan supaya mode malam bisa menimpanya di satu tempat. Token
/// permukaan ada di `Apps/Shared/SurfaceTokens.swift` dengan alasan yang lebih
/// kuat: palet itu **teruji** di Linux, dan ia tidak boleh hidup di berkas
/// yang hanya bisa dibaca satu app.
///
/// Catatan Dynamic Type: angka di sini hanya untuk hal yang **tidak** boleh
/// ikut scale — jarak, radius, lebar gambar. Ukuran **teks** memakai semantic
/// font (`.headline`, `.caption`, dan seterusnya), bukan angka. Itu bukan
/// urusan rasa: `.system(size:)` mengabaikan Dynamic Type, jadi pengguna yang
/// memperbesar teks akan mendapat label kecil yang sama sekali tidak
/// membesar, sementara label sistem di tempat lain ikut membesar.
enum WatchMetrics {
    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 10
    /// Lebar gambar benda langit di kartu jam. Metric, bukan teks — jadi
    /// tidak ikut Dynamic Type.
    static let visualDiameter: CGFloat = 38
    // Ukuran ikon status sengaja TIDAK ada di sini: ia harus ikut Dynamic
    // Type, jadi di `PointingView` ia dipegang sebagai `@ScaledMetric`
    // (relatif ke `.headline`) — bukan angka `static` yang mati saat teks
    // diperbesar. Angka tetap hanya untuk hal yang memang tak boleh scale.
}