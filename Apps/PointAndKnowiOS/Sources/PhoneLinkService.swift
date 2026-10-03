import Foundation
import WatchConnectivity
import CelestialEngine
import PointingKit

/// Jembatan iPhone ↔ Watch (sisi telepon).
///
/// Yang diterima dari jam adalah **keputusan**, bukan sudut pergelangan. Itu
/// memang yang dibutuhkan iPhone: menampilkan keadaan terakhir dan mengirim
/// balik ambang keyakinan hasil Experiment 1. Sudut mentah sengaja tidak
/// pernah melintas, karena satu-satunya tempat sudut pergelangan boleh dipakai
/// adalah perhitungan galat di perangkat yang sama.
@MainActor
public final class PhoneLinkService: NSObject, ObservableObject {

    /// Pesan keadaan terakhir dari jam.
    @Published public private(set) var lastState: PointingLinkMessage?
    /// Kalibrasi terakhir dari jam.
    @Published public private(set) var lastCalibration: PointingLinkMessage?
    @Published public private(set) var isReachable = false
    @Published public private(set) var isActivated = false
    @Published public private(set) var lastNote: String?
    @Published public private(set) var receivedCount = 0

    /// Setiap pesan yang masuk, untuk direkam ke riwayat keyakinan.
    public var onMessage: ((PointingLinkMessage) -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    public override init() { super.init() }

    public func activate() {
        guard let session, !isActivated else { return }
        session.delegate = self
        session.activate()
    }

    /// Kirim ambang keyakinan baru ke jam.
    ///
    /// Lewat `transferUserInfo`, **bukan** `updateApplicationContext`: ambang
    /// ini peristiwa sekali-jadi, dan `updateApplicationContext` hanya menyimpan
    /// satu kamus — kalau pengguna menekan "Minta keadaan terakhir" sesudahnya,
    /// ambangnya tertimpa dan tidak pernah sampai ke jam, sementara di iPhone
    /// tampak terkirim.
    public func send(policy: ConfidencePolicy) {
        guard let session, session.activationState == .activated else {
            lastNote = "Jam belum terhubung — ambang belum terkirim."
            return
        }
        session.transferUserInfo(PointingLinkMessage.policy(policy).plist)
    }

    /// Minta keadaan terakhir dari jam.
    public func requestState() {
        send(PointingLinkMessage(kind: .stateRequest))
    }

    public func send(_ message: PointingLinkMessage) {
        guard let session, session.activationState == .activated else {
            lastNote = "Jam belum terhubung — pesan tidak terkirim."
            return
        }
        do {
            try session.updateApplicationContext(message.plist)
            lastNote = "Terkirim: \(message.kind.rawValue)"
        } catch {
            lastNote = "Gagal mengirim: \(error.localizedDescription)"
        }
    }

    private func handle(_ message: PointingLinkMessage) {
        receivedCount += 1
        switch message.kind {
        case .pointingState:
            lastState = message
            lastNote = message.objectName.map { "Jam melihat \($0)" } ?? "Keadaan dari jam"
        case .calibrationReady:
            lastCalibration = message
            lastNote = "Kalibrasi dari jam"
        case .policyUpdate:
            lastNote = "Jam mengirim ambang keyakinan"
        case .stateRequest:
            // Jam meminta keadaan — balas dengan yang terakhir kita punya.
            // (Peran ini jarang terpakai, tapi harus ada supaya permintaan
            // tidak berakhir tanpa jawaban.)
            if let lastState { send(lastState) }
        case .acknowledgement:
            lastNote = "Tanda terima"
        }
        onMessage?(message)
    }
}

/// `@preconcurrency`: `WCSessionDelegate` tidak di-`@MainActor`, sedangkan
/// kelas ini di-`@MainActor`. Setiap metode di bawah `nonisolated` dan
/// menyerahkan hasilnya ke main actor lewat `Task`.
extension PhoneLinkService: @preconcurrency WCSessionDelegate {

    nonisolated public func session(_ session: WCSession,
                                    activationDidCompleteWith activationState: WCSessionActivationState,
                                    error: Error?) {
        let reachable = session.isReachable
        let activated = activationState == .activated
        let message = error?.localizedDescription
        Task { @MainActor in
            self.isReachable = reachable
            self.isActivated = activated
            if let message { self.lastNote = message }
        }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        // Pasangan berpindah (mis. jam baru dipasangkan). Aktifkan ulang.
        Task { @MainActor in self.activate() }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated public func session(_ session: WCSession,
                                    didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let message = PointingLinkMessage(plist: applicationContext) else { return }
        Task { @MainActor in self.handle(message) }
    }

    nonisolated public func session(_ session: WCSession,
                                    didReceiveMessage message: [String: Any]) {
        guard let decoded = PointingLinkMessage(plist: message) else { return }
        Task { @MainActor in self.handle(decoded) }
    }

    /// Pesan antre dari jam. Kalibrasi dan permintaan keadaan dikirim jam
    /// dengan `transferUserInfo`, jadi keduanya tiba di sini — bukan di
    /// `didReceiveApplicationContext`.
    nonisolated public func session(_ session: WCSession,
                                    didReceiveUserInfo userInfo: [String: Any]) {
        guard let decoded = PointingLinkMessage(plist: userInfo) else { return }
        Task { @MainActor in self.handle(decoded) }
    }
}
