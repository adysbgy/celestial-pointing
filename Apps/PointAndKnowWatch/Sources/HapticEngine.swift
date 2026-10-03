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
@MainActor
final class HapticEngine {

    /// Apakah getaran tersedia (tidak tersedia di pratinjau/simulator).
    var isAvailable: Bool { WKInterfaceDevice.current().isDeviceSupported }

    /// Mainkan getaran untuk sekumpulan peristiwa.
    func play(_ events: [HapticEvent]) {
        for event in events { play(event) }
    }

    func play(_ event: HapticEvent) {
        let device = WKInterfaceDevice.current()
        guard device.isDeviceSupported else { return }
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
