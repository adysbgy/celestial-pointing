import Foundation

/// Layar mana yang **boleh** dirender saat watchOS meredupkan layar (Always-On).
///
/// **Kenapa keputusan ini ada di `PointingKit`, bukan di view.**
/// `NightAwareContainer` di app jam memilih satu dari dua isi: layar penuh
/// (`fullView`) atau versi hemat (`ReducedLuminanceView`). Pemilihan itu dulu
/// ditulis sebagai `if isLuminanceReduced` di `Apps/PointAndKnowWatch/Sources/
/// ReducedLuminanceView.swift` — berkas yang **tidak pernah dibangun**
/// `swift-test.sh` di Linux dan tidak dibaca badan satu pun dari 55 aturan UI.
///
/// Diukur pada salinan utuh, proses baru, sebelum tipe ini ada: mengganti
/// cabang redup dengan layar penuh, dengan `PointingEngine()` baru, atau dengan
/// `EmptyView()` membuat **seluruh 55 aturan tetap lulus (exit 0)**. Ketiganya
/// mengubah janji FASE A #2 secara total — layar Always-On kembali menjadi
/// layar interaktif penuh dengan animasi, atau menjadi kosong — dan tidak ada
/// satu pun teks di layar yang bisa dibaca untuk memeriksanya, karena
/// pengguna hanya melihat hasilnya saat pergelangan diturunkan.
///
/// **Kenapa bukan `Bool`.** Saklar `isLuminanceReduced` hanya memberi dua
/// jawaban, dan dua jawaban itu justru yang salah: yang perlu diputuskan
/// adalah **isi mana** yang tampil. Dengan enum, pemanggil tidak bisa
/// "menghapus" versi hemat tanpa menulis nama kasus yang tidak ada.
///
/// **Yang TIDAK diklaim.** Tipe ini memutuskan *pilihan* isi, bukan
/// kebenaran isinya: apakah `ReducedLuminanceView` benar-benar kontras tinggi,
/// tanpa animasi, dan membaca fakta yang berlaku — itu dijaga uji lain
/// (`ReducedLuminanceLabelTests`, `ReducedLuminanceVisualTests`,
/// `MotionPolicyTests`) dan oleh Aturan 35. Ia juga tidak menyentuh deteksi
/// `isLuminanceReduced` itu sendiri; nilainya tetap datang dari SwiftUI.
public enum AlwaysOnContent: Equatable, Sendable {

    /// Isi yang tampil saat layar **tidak** diredupkan: layar interaktif penuh.
    case full
    /// Isi yang tampil saat layar redup: versi sederhana + kontras tinggi.
    case reduced

    /// Pilih isi berdasarkan keadaan layar.
    ///
    /// Sengaja **tanpa** parameter lain. Setiap parameter tambahan adalah
    /// kesempatan kedua untuk memilih `full` pada layar redup (mis. "kecuali
    /// sedang terkunci"), dan setiap pengecualian semacam itu menghapus alasan
    /// layar redup ada: ia dibuat justru untuk keadaan paling penting.
    public static func choose(isLuminanceReduced: Bool) -> AlwaysOnContent {
        isLuminanceReduced ? .reduced : .full
    }

    /// Apakah isi ini boleh beranimasi.
    ///
    /// Selalu `false` untuk `.reduced`, dan itu bukan preferensi gaya:
    /// watchOS hanya menyegarkan layar redup sekali per detik, jadi animasi di
    /// sana membakar baterai untuk frame yang tidak pernah terlihat. Ini
    /// **aturan yang sama** dengan `MotionPolicy.allowsContinuousMotion`,
    /// dinyatakan sekali di sini supaya isi redup tidak bisa mendapat gerak
    /// lewat jalur lain.
    public var allowsMotion: Bool {
        self == .full
    }
}
