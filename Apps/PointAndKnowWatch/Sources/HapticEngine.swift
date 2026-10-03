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
        let device = WKInterfaceDevice.current()
        switch event {
        case .lockSucceeded:
            device.play(.success)
        case .uncertain:
            device.play(.retry)
        case .sensorUnavailable:
            device.play(.failure)
        case .returnedToIdle:
            device.play(.click)
        }
    }
}
