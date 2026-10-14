import UIKit
import PointingKit

/// Pemicu getaran di iPhone — padanan `HapticEngine` (jam) untuk app iPhone.
///
/// Setiap peristiwa dipetakan ke pola getaran yang **berbeda tajam**, supaya
/// "berhasil" dan "ragu" tidak berbunyi sama. Itu menjaga janji PRD: pengguna
/// tidak boleh mengira engine yakin saat engine sebenarnya ragu.
///
/// **Kenapa ini ada.** `DiagnosticsView` dulu menulis `engine.haptics = nil`
/// dengan alasan "iPhone tidak punya Taptic Engine". Itu salah secara fakta:
/// iPhone punya Taptic Engine sejak iPhone 7 (2016), dan `UIImpactFeedbackGenerator`
/// / `UINotificationFeedbackGenerator` tersedia di semua target iPhone produk
/// ini. Menonaktifkannya membuat iPhone hanya punya saluran multi-modal audio
/// (bunyi), sementara jam punya getaran + bunyi — tidak konsisten padahal
/// `PointingEngine` sudah menyediakan closure `haptics` yang sama untuk
/// kedua platform.
///
/// **Kenapa generator dibuat ulang per peristiwa, bukan disimpan.** Generator
/// haptic iOS idealnya dibuat sesaat sebelum `impactOccurred()` dan dibiarkan
/// di-*prepare* sesaat sebelum dipicu; menyimpan satu instance lintas banyak
/// peristiwa jarang mempercepat apa pun dan menambah state yang tidak perlu.
/// Peristiwa kunci jauh dari tiap sampel 20 Hz (lihat `PointingController`),
/// jadi biaya pembuatan generator bisa diabaikan.
@MainActor
final class PhoneHapticEngine {

    /// Mainkan getaran untuk sekumpulan peristiwa.
    func play(_ events: [HapticEvent]) {
        for event in events { play(event) }
    }

    func play(_ event: HapticEvent) {
        switch event {
        case .lockSucceeded:
            // "Selesai" — jelas terasa sebagai keberhasilan.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .uncertain:
            // Berbeda dari sukses: terasa "belum pasti", bukan "selesai".
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .sensorUnavailable:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
        case .returnedToIdle:
            // Transisi lembut kembali ke diam — bukan peringatan.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}
