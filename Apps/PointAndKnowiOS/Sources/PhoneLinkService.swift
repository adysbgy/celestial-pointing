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

    /// Aktifkan sesi. Aman dipanggil berkali-kali selama sesinya memang aktif.
    ///
    /// **Kenapa penjaganya bukan `!isActivated`.** `isActivated` sengaja
    /// dilaporkan ke UI ("Aktif" / "Belum aktif" di layar Tautan), dan nilainya
    /// hanya diubah dari `activationDidCompleteWith`. Kalau penjaganya memakai
    /// flag itu, pemanggil **tidak akan pernah bisa** mengaktifkan ulang sesi
    /// yang sudah pernah aktif lalu mati (`sessionDidDeactivate`) — `activate()`
    /// akan langsung `return` karena flag-nya masih `true`. Padahal justru
    /// itulah yang dibutuhkan: pasangan berpindah (jam baru dipasangkan) dan
    /// sesinya perlu diaktifkan lagi. Akibatnya iPhone menampilkan "Aktif"
    /// selamanya sementara tautannya sudah mati.
    ///
    /// Penjaganya sekarang memakai keadaan sesi yang sebenarnya
    /// (`activationState`), dan `sessionDidDeactivate` mengosongkan flag itu —
    /// jadi UI ikut jujur, dan pengaktifan ulang benar-benar dijalankan.
    public func activate() {
        guard let session, session.activationState != .activated else { return }
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
            lastNote = LinkStatusText.watchUnreachablePolicy
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
            lastNote = LinkStatusText.watchUnreachableMessage
            return
        }
        do {
            try session.updateApplicationContext(message.plist)
            lastNote = LinkStatusText.sent(message.kind.displayName)
        } catch {
            lastNote = LinkStatusText.sendFailed(error.localizedDescription)
        }
    }

    private func handle(_ message: PointingLinkMessage) {
        receivedCount += 1
        switch message.kind {
        case .pointingState:
            lastState = message
            lastNote = message.objectName.map { LinkStatusText.watchSaw($0) }
                ?? LinkStatusText.stateFromWatch
        case .calibrationReady:
            lastCalibration = message
            lastNote = LinkStatusText.calibrationFromWatch
        case .policyUpdate:
            lastNote = LinkStatusText.policyFromWatch
        case .stateRequest:
            // Jam meminta keadaan — balas dengan yang terakhir kita punya.
            // (Peran ini jarang terpakai, tapi harus ada supaya permintaan
            // tidak berakhir tanpa jawaban.)
            if let lastState { send(lastState) }
        case .acknowledgement:
            lastNote = LinkStatusText.acknowledgement
        }
        onMessage?(message)
    }
}

/// **Kenapa TIDAK ada `@preconcurrency` pada konformansnya.**
/// `WCSessionDelegate` tidak di-`@MainActor`, sedangkan kelas ini
/// di-`@MainActor`; atribut itu dulu dipakai untuk itu. Ternyata ia tidak
/// berpengaruh, karena **setiap** metode di bawah `nonisolated` dan menyerahkan
/// hasilnya ke main actor lewat `Task` — tidak ada persyaratan protokol yang
/// dilanggar isolasi. Compiler Xcode 16.4 mengatakannya sendiri
/// (`... to 'WCSessionDelegate' has no effect`) dan fix-it-nya membuang atribut
/// itu. Sengaja dibuang: dengan atribut itu, kesalahan isolasi baru di masa
/// depan diturunkan menjadi peringatan runtime; tanpanya ia menjadi galat
/// kompilasi.
extension PhoneLinkService: WCSessionDelegate {

    nonisolated public func session(_ session: WCSession,
                                    activationDidCompleteWith activationState: WCSessionActivationState,
                                    error: Error?) {
        let reachable = session.isReachable
        let activated = activationState == .activated
        let message = error?.localizedDescription
        Task { @MainActor in
            self.isReachable = reachable
            self.isActivated = activated
            if let message {
                // Pesan sistem dibungkus lewat katalog: ia mengikuti bahasa
                // perangkat, bukan bahasa katalog. Namanya tetap ikut (`%@`)
                // supaya dua kegagalan berbeda tidak terbaca sama.
                self.lastNote = LinkStatusText.activationFailed(message)
            }
        }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Sesi berhenti (pasangan berpindah — mis. jam baru dipasangkan).
    ///
    /// **Kenapa `isActivated` dikosongkan di sini.** Flag itu ditampilkan di
    /// layar Tautan sebagai "Aktif"/"Belum aktif". Tanpa mengosongkannya, ia
    /// tetap `true` setelah sesi benar-benar berhenti: iPhone terus mengklaim
    /// tautannya aktif padahal tidak ada pesan yang bisa lewat. Itu persis
    /// klaim tanpa dasar yang dilarang PRD, dan ia juga yang dulu membuat
    /// `activate()` tak bisa memulihkan sesinya (penjaganya `!isActivated`).
    /// Sekarang pengaktifan ulang dijalankan, dan layar ikut jujur.
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.isActivated = false
            self.isReachable = false
            self.activate()
        }
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
