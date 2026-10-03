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
/// **Dua saluran, dan bedanya penting.** `updateApplicationContext` hanya
/// menyimpan **satu** kamus: setiap kiriman menimpa yang sebelumnya. Itu
/// memang yang diinginkan untuk keadaan alur ("apa kabar terakhir?"), tapi
/// **salah** untuk kalibrasi: hasil kalibrasi akan tertimpa oleh pembaruan
/// keadaan berikutnya, dan iPhone bisa tidak pernah menerimanya sama sekali
/// sementara di jam kalibrasi tampak berhasil. Karena itu kalibrasi dikirim
/// lewat `transferUserInfo`, yang mengantre dan dikirim berurutan — termasuk
/// saat pasangan sedang tidak terjangkau.
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

    /// Keadaan alur yang berlaku sekarang, untuk menjawab permintaan iPhone.
    ///
    /// Diisi oleh app jam. Tanpa ini, permintaan "kirim keadaan terakhir" tidak
    /// bisa dijawab dan iPhone akan terus menampilkan keadaan lama tanpa tahu
    /// bahwa permintaannya tidak menghasilkan apa-apa.
    public var currentSnapshot: (() -> PointingSnapshot)?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    /// Penyaring kiriman: kirim saat keputusan berubah, bukan tiap sampel.
    private var reportGate = LinkReportGate()

    public override init() { super.init() }

    public func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Kirim keadaan alur sekarang.
    ///
    /// `sigmaDeg` sebaiknya diisi dengan sigma yang **berlaku di jam**, supaya
    /// sampel yang direkam iPhone membawa konteks yang benar. `nil` berarti
    /// penerima memakai bawaannya.
    public func send(state snapshot: PointingSnapshot,
                     at date: Date = Date(),
                     sigmaDeg: Double? = nil) {
        send(PointingLinkMessage.state(from: snapshot, at: date, sigmaDeg: sigmaDeg))
    }

    /// Kirim keadaan **bila keputusannya berubah** — dipakai pada tiap sampel
    /// sensor.
    ///
    /// Jam dan telepon sering tidak terhubung, dan `updateApplicationContext`
    /// hanya menyimpan satu kamus: mengirim 20 kali per detik tidak menambah
    /// informasi, hanya memakai radio dan baterai. Yang berguna di iPhone adalah
    /// keputusan terakhir.
    ///
    /// Menyaringnya dengan "apakah ada jawaban?" salah dua kali: selama terkunci
    /// syaratnya selalu benar (jadi tetap 20 Hz), dan tepat saat jawabannya
    /// **hilang** syaratnya salah — iPhone membeku di objek terakhir seolah
    /// masih berlaku. Aturannya ada di `LinkReportGate` (teruji di Linux); di
    /// sini hanya menjalankannya.
    ///
    /// - Returns: `true` bila pesan benar-benar dikirim.
    @discardableResult
    public func sendIfDecisionChanged(state snapshot: PointingSnapshot,
                                      at date: Date = Date(),
                                      sigmaDeg: Double? = nil) -> Bool {
        guard reportGate.shouldReport(snapshot) else { return false }
        send(state: snapshot, at: date, sigmaDeg: sigmaDeg)
        return true
    }

    /// Kirim hasil kalibrasi.
    ///
    /// Lewat `transferUserInfo`, **bukan** `updateApplicationContext`: hasil
    /// kalibrasi adalah peristiwa sekali-jadi, bukan keadaan yang boleh
    /// ditimpa. `residualSpreadDeg` di dalamnya adalah angka yang menyetel
    /// ambang keyakinan di iPhone — kalau hilang, Experiment 1 kehilangan
    /// satu-satunya pengukuran yang membuatnya berguna.
    public func send(calibration: PointingCalibration) {
        guard let session, session.activationState == .activated else {
            sendFailureCount += 1
            lastMessageNote = "Kalibrasi belum terkirim: sesi belum aktif."
            return
        }
        session.transferUserInfo(PointingLinkMessage.calibration(calibration).plist)
    }

    /// Kirim pesan apa adanya. Gagal kirim **tidak** diam: penghitungnya naik
    /// supaya bisa dilihat saat pengujian lapangan.
    ///
    /// Sesi yang belum aktif dihitung sebagai kegagalan, sama seperti
    /// `send(calibration:)`. Sebelumnya jalur ini `return` tanpa menaikkan
    /// penghitung, padahal komentarnya sendiri menjanjikan sebaliknya — jadi
    /// justru kegagalan yang **paling sering** terjadi (jam tidak terjangkau
    /// iPhone, sesi belum aktif) satu-satunya yang tidak terlihat. Di layar jam
    /// angka "N gagal" tetap nol, dan penguji menyimpulkan tautannya baik-baik
    /// saja sementara tidak ada satu pun keputusan yang sampai. Ini juga jalur
    /// yang dipakai `requestState()`, jadi permintaan iPhone yang tidak pernah
    /// dijawab pun tidak meninggalkan jejak.
    public func send(_ message: PointingLinkMessage) {
        guard let session, session.activationState == .activated else {
            sendFailureCount += 1
            lastMessageNote = "Pesan belum terkirim: sesi belum aktif."
            return
        }
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
            // Balas dengan keadaan yang berlaku sekarang. Kalau app belum
            // menyediakan sumbernya, katakan terus terang — iPhone yang meminta
            // dan tidak menerima apa-apa akan mengira jam tidak menjawab.
            if let currentSnapshot {
                send(state: currentSnapshot())
            } else {
                lastMessageNote = "Permintaan keadaan datang sebelum alur siap."
            }
        default:
            break
        }
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
///
/// `sessionReachabilityDidChange` **wajib** ada di sini: `isReachable`
/// ditampilkan di layar jam ("iPhone terhubung" / "tidak terjangkau"), dan tanpa
/// metode itu nilainya hanya pernah ditetapkan sekali saat aktivasi — layar akan
/// terus berbohong tentang keadaan tautan yang sebenarnya. Jam yang menampilkan
/// "terhubung" padahal tidak adalah persis jenis klaim yang tidak boleh dibuat
/// tanpa dasar.
extension WatchLinkService: WCSessionDelegate {

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

    /// Pesan antre dari iPhone (ambang keyakinan dikirim dengan
    /// `transferUserInfo`, jadi ia tiba di sini — bukan di
    /// `didReceiveApplicationContext`).
    nonisolated public func session(_ session: WCSession,
                                    didReceiveUserInfo userInfo: [String: Any]) {
        guard let decoded = PointingLinkMessage(plist: userInfo) else { return }
        Task { @MainActor in self.handle(decoded) }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }
}
