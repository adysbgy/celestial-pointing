import Foundation
import WatchKit
import PointingKit

/// Getaran "panas–dingin" (ADR-014): ketukan haptik yang makin rapat saat
/// arah tunjuk mendekati benda yang dipandu cincin petunjuk.
///
/// Iramanya dari `HotCold.tickInterval` (teruji di PointingKit). Kelas ini
/// hanya menjadwalkan ketukan; ia berhenti sendiri saat `update(nil)` —
/// cincin hilang, layar meredup, app ke latar, atau pengguna mematikannya.
@MainActor
final class HotColdTicker: ObservableObject {
    static let enabledKey = "hotCold.enabled"

    private var separationDeg: Int?
    private var loop: Task<Void, Never>?

    func update(separationDeg: Int?) {
        self.separationDeg = separationDeg
        if separationDeg == nil {
            loop?.cancel()
            loop = nil
        } else if loop == nil {
            loop = Task { [weak self] in await self?.run() }
        }
    }

    private func run() async {
        while !Task.isCancelled {
            guard let sep = separationDeg,
                  let interval = HotCold.tickInterval(separationDeg: Double(sep)) else {
                // Terlalu jauh: tunggu sebentar tanpa berketuk.
                try? await Task.sleep(for: .milliseconds(500))
                continue
            }
            WKInterfaceDevice.current().play(.click)
            try? await Task.sleep(for: .seconds(interval))
        }
    }
}
