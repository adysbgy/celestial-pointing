import Foundation
import WatchKit

/// Membuat app tetap berjalan saat layar jam berpaling (ADR-018).
///
/// **Kenapa ada.** Menunjuk langit dengan lengan bawah memalingkan layar dari
/// wajah; watchOS lalu meredupkan layar dan app menjadi `.inactive`. Dulu
/// app menghentikan sensor dan alur pada `.inactive`, jadi saat pengguna
/// mengikuti cincin petunjuk lalu melirik jam lagi, alurnya sudah kembali ke
/// awal ("Tunjuk ke langit") — persis laporan Ady 10 Okt 2026. Getaran
/// panas–dingin juga mati tepat saat paling dibutuhkan.
///
/// Sesi *physical therapy* (`WKBackgroundModes` sudah dideklarasikan untuk
/// Pointing Lab, ADR-004) membuat app tetap menerima data gerak dan memutar
/// haptic selama layar redup, paling lama satu jam per sesi. Sesi dimulai
/// saat app aktif dan diakhiri saat app benar-benar ke latar belakang.
@MainActor
final class PointingRuntimeSession: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    @Published private(set) var state = "idle"
    private var session: WKExtendedRuntimeSession?

    func start() {
        guard session == nil else { return }
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        session = s
        state = "starting"
        s.start()
    }

    func stop() {
        session?.invalidate()
        session = nil
        state = "idle"
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in self.state = "running" }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in self.state = "expiring" }
    }

    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                            didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                            error: Error?) {
        Task { @MainActor in
            // Sesi habis/ditolak: sesi berikutnya boleh dimulai saat app aktif lagi.
            if self.session === extendedRuntimeSession { self.session = nil }
            self.state = "invalidated(\(reason.rawValue))"
        }
    }
}
