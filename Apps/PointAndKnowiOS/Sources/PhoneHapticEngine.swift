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
///
/// **Keputusan pola tidak lagi ditulis di sini.** Dulu berkas ini punya
/// `switch` sendiri yang memetakan `.lockSucceeded` → `.medium` dan
/// `.uncertain` → `.rigid`. Jam punya salinannya sendiri (`HapticEngine`).
/// Dua salinan dari satu politik PRD berarti keduanya bisa menyimpang tanpa
/// ada yang berbunyi — dan keduanya tinggal di `Apps/`, yang tidak pernah
/// dibangun `swift-test.sh` di Linux. Pemetaan itu kini di `HapticPolicy`
/// (PointingKit, diuji di Linux); yang tersisa di sini hanya terjemahan pola
/// ke API UIKit, satu pola satu efek, tanpa keputusan.
@MainActor
final class PhoneHapticEngine {

    /// Mainkan getaran untuk sekumpulan peristiwa.
    func play(_ events: [HapticEvent]) {
        for event in events { play(event) }
    }

    func play(_ event: HapticEvent) {
        guard let pattern = HapticPolicy.pattern(for: event) else { return }
        play(pattern)
    }

    /// Terjemahan pola → efek UIKit. Tanpa keputusan: satu pola, satu efek.
    ///
    /// Kenapa `.success` memakai `.medium` dan `.retry` memakai `.rigid`:
    /// keduanya terasa jelas berbeda di tangan. Itu satu-satunya syaratnya —
    /// bukan soal intensitas mana yang lebih enak.
    private func play(_ pattern: HapticPattern) {
        switch pattern {
        case .completed:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .unsettled:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .failed:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .tick:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}
