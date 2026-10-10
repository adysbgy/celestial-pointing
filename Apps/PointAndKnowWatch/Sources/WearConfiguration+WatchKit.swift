import WatchKit
import CelestialEngine

extension WearConfiguration {
    /// Cara jam ini dipakai menurut pengaturan watchOS (Pengaturan → Umum →
    /// Orientasi). Dibaca saat dibutuhkan, karena pengguna bisa mengubahnya
    /// kapan saja.
    static var current: WearConfiguration {
        let device = WKInterfaceDevice.current()
        return WearConfiguration(
            wrist: device.wristLocation == .left ? .left : .right,
            crown: device.crownOrientation == .left ? .left : .right
        )
    }
}
