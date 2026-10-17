import Foundation
import WatchKit
import PointingKit

/// Pemicu Taptic Engine.
///
/// Satu-satunya berkas yang memanggil `WKInterfaceDevice.play`. Pemetaan
/// peristiwa → pola getaran sengaja dibedakan tajam, karena getaran adalah
/// satu-satunya saluran yang tidak butuh mata saat jam diangkat:
///
/// - **sukses** → `.success` (pola jelas, terasa "selesai")
/// - **ragu** → `.retry` (pola berbeda, terasa "belum")
///
/// Perbedaan itu yang menjaga janji PRD: pengguna tidak boleh mengira engine
/// yakin saat engine sebenarnya ragu. Kalau keduanya berbunyi sama, "lock"
/// berhenti bermakna.
///
/// **Keputusan itu tidak lagi ditulis di berkas ini.** Peristiwa mana
/// mendapat pola mana hidup di `HapticPolicy` (PointingKit, teruji di Linux),
/// karena pemetaan `case .uncertain: device.play(.retry)` yang dulu tinggal
/// di sini memutuskan hal yang PRD larang dilanggar di `Apps/` — yang tidak
/// pernah dibangun `swift-test.sh`. Terukur: mengganti pola `.uncertain`
/// menjadi `.success` **tetap hijau** pada ke-46 aturan UI, padahal itu
/// membuat ragu terasa persis seperti berhasil bagi pengguna yang tidak
/// melihat layar.
///
/// Yang tersisa di sini hanya penerjemahan pola ke `WKHapticType` — satu
/// `switch` tanpa keputusan. Salah ketik di sini terlihat sebagai getaran
/// yang tidak berbunyi, bukan sebagai klaim yang salah.
///
/// Tidak ada pemeriksaan "apakah perangkat mendukung getaran": `WKInterfaceDevice`
/// tidak punya API seperti itu, dan di simulator `play(_:)` memang tidak
/// berbunyi. Memeriksa sesuatu yang tidak bisa diperiksa hanya akan
/// menghasilkan getaran yang diam-diam hilang di perangkat asli.
@MainActor
final class HapticEngine {

    /// Mainkan getaran untuk sekumpulan peristiwa.
    func play(_ events: [HapticEvent]) {
        for event in events { play(event) }
    }

    func play(_ event: HapticEvent) {
        guard let pattern = HapticPolicy.pattern(for: event) else { return }
        WKInterfaceDevice.current().play(type(for: pattern))
    }

    /// Terjemahan pola → `WKHapticType`. Tanpa keputusan: satu pola, satu tipe.
    private func type(for pattern: HapticPattern) -> WKHapticType {
        switch pattern {
        case .completed: return .success
        case .unsettled: return .retry
        case .failed:    return .failure
        case .tick:      return .click
        }
    }
}
