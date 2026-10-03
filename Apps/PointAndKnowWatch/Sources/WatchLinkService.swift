import Foundation
import WatchConnectivity
import CelestialEngine
import PointingKit

/// Jembatan Watch ↔ iPhone.
///
/// Yang dikirim sengaja **bukan** data sensor mentah, melainkan keputusan yang
/// sudah jadi: keadaan alur, objek teridentifikasi, keyakinan, dan hasil
/// kalibrasi. Alasannya ada di PRD: sudut pergelangan tidak boleh menjadi
/// masukan bagi apa pun selain pengukuran galat. Mengalirkannya ke perangkat
/// lain hanya menambah peluang ia dipakai untuk hal yang salah.
///
/// `updateApplicationContext` dipakai (bukan `sendMessage`) karena ia
/// menyimpan pesan terakhir dan mengirimkannya saat pasangan kembali terjangkau
/// — jam dan telepon sering tidak terhubung, dan keadaan terakhir itulah yang
/// berguna, bukan antrean peristiwa lama.
@MainActor
public final class WatchLinkService: NSObject, ObservableObject {

    /// Pesan terakhir dari iPhone (mis. ambang keyakinan baru).
    @Published public private(set) var lastPolicyFromPhone: ConfidencePolicy?
    @Published public private(set) var lastMessageNote: String?
    @Published public private(set) var isReachable = false
    /// Berapa pesan yang gagal dikirim (untuk terlihat saat pengujian).
    @Published public private(set) var sendFailureCount = 0

    /// Dijalankan saat iPhone mengirim ambang keyakinan baru.
    ///
    /// Ambang dari Experiment 1 dipasang ke resolver jam supaya kedua perangkat
    /// memakai angka yang sama — kalau tidak, hasil pengukuran di satu tempat
    /// tidak berlaku di tempat lain.
    public var onPolicyReceived: ((ConfidencePolicy) -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    public override init() { super.init() }

    public func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Kirim keadaan alur sekarang.
    public func send(state snapshot: PointingSnapshot, at date: Date = Date()) {
        send(PointingLinkMessage.state(from: snapshot, at: date))
    }

    /// Kirim hasil kalibrasi.
    public func send(calibration: PointingCalibration) {
        send(PointingLinkMessage.calibration(calibration))
    }

    /// Kirim pesan apa adanya. Gagal kirim **tidak** diam: penghitungnya naik
    /// supaya bisa dilihat saat pengujian lapangan.
    public func send(_ message: PointingLinkMessage) {
        guard let session, session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(message.plist)
        } catch {
            sendFailureCount += 1
            lastMessageNote = "Gagal mengirim: \(error.localizedDescription)"
        }
    }

    /// Minta keadaan terakhir dari jam (dipakai iPhone saat dibuka).
    public func requestState() {
        send(PointingLinkMessage(kind: .stateRequest))
    }

    private func handle(_ message: PointingLinkMessage) {
        lastMessageNote = message.note ?? message.kind.rawValue
        switch message.kind {
        case .policyUpdate:
            if let policy = message.confidencePolicy {
                lastPolicyFromPhone = policy
                onPolicyReceived?(policy)
            } else {
                // Ambang tidak masuk akal ditolak, bukan diterapkan diam-diam.
                lastMessageNote = "Ambang keyakinan dari iPhone tidak sah — diabaikan"
            }
        case .stateRequest:
            // Balasan disiapkan pemanggil; di sini cukup dicatat.
            break
        default:
            break
        }
    }
}

/// `@preconcurrency`: `WCSessionDelegate` tidak di-`@MainActor`, sedangkan
/// kelas ini di-`@MainActor`. Setiap metode di bawah `nonisolated` dan
/// menyerahkan hasilnya ke main actor lewat `Task`.
///
/// `sessionReachabilityDidChange` **wajib** ada di sini: `isReachable`
/// ditampilkan di layar jam ("iPhone terhubung" / "tidak terjangkau"), dan tanpa
/// metode itu nilainya hanya pernah ditetapkan sekali saat aktivasi — layar akan
/// terus berbohong tentang keadaan tautan yang sebenarnya. Jam yang menampilkan
/// "terhubung" padahal tidak adalah persis jenis klaim yang tidak boleh dibuat
/// tanpa dasar.
extension WatchLinkService: @preconcurrency WCSessionDelegate {

    nonisolated public func session(_ session: WCSession,
                                    activationDidCompleteWith activationState: WCSessionActivationState,
                                    error: Error?) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if let error { self.lastMessageNote = error.localizedDescription }
        }
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

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }
}
