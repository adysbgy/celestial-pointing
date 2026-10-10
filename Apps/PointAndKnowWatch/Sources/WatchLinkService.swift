import Foundation
import WatchConnectivity
import os
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
    /// iPhone meminta aliran arah tunjuk untuk cermin Stellarium (ADR-016).
    @Published public private(set) var mirrorRequested = false {
        didSet {
            if mirrorRequested != oldValue {
                Self.mirrorLog.info("mirror requested \(self.mirrorRequested)")
            }
        }
    }
    private static let mirrorLog = Logger(subsystem: "dev.celestial.pointandknow", category: "stellarium")
    private var mirrorThrottle = MirrorThrottle()

    // MARK: Pointing Lab (alat riset, ADR-004)

    /// Target manual dari iPhone. Disimpan supaya tetap ada saat iPhone jauh.
    @Published public private(set) var labTargets: [LabTarget] = WatchLinkService.storedLabTargets
    /// Hasil pengiriman berkas Lab terakhir (`nil` = belum ada).
    @Published public private(set) var labTransferSucceeded: Bool?
    @Published public private(set) var labTransfersInFlight = 0
    private static let labTargetsKey = "pointingLab.targets"

    // MARK: Keadaan teleskop dari iPhone (ADR-009)

    @Published public private(set) var telescopeStatus: TelescopeStatus?
    private var lastContextMessageSentAt: Date?

    func receiveTelescope(_ status: TelescopeStatus) {
        #if DEBUG
        if debugTelescopeTimer != nil { return }   // pose/teleskop debug menang
        #endif
        telescopeStatus = status
    }

    #if DEBUG
    private var debugTelescopeTimer: Timer?
    /// `-debugTelescope ready|slewing|off`: laporan teleskop sintetis untuk
    /// simulator. Juga memaksa "iPhone terjangkau" supaya tombol GoTo/Stop
    /// bisa dilihat; mengetuk GoTo tetap lewat kanal sungguhan (dan berakhir
    /// `.noReply` bila tidak ada iPhone).
    @Published public private(set) var debugForcesReachable = false

    public func startDebugTelescopeIfRequested() {
        guard let mode = UserDefaults.standard.string(forKey: "debugTelescope") else { return }
        // `slewing-silent`: satu laporan "bergerak" (seolah slew dimulai dari
        // iPhone), lalu laporan berhenti dan iPhone tidak terjangkau — untuk
        // memeriksa bahwa Stop tetap ada setelah keadaan menjadi basi.
        if mode == "slewing-silent" {
            telescopeStatus = TelescopeStatus(state: .slewing, at: Date(), detail: "debug-silent")
            debugTelescopeTimer = Timer(timeInterval: 3600, repeats: false) { _ in }
            return
        }
        let state: TelescopeStatusState = mode == "ready" ? .ready : mode == "slewing" ? .slewing : .disabled
        debugForcesReachable = true
        let tick = { [weak self] in self?.telescopeStatus = TelescopeStatus(state: state, at: Date(), detail: "debug") }
        tick()
        debugTelescopeTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
    }
    #endif

    /// Terjangkau menurut sesi (atau dipaksa oleh mode debug).
    public var isPhoneReachable: Bool {
        #if DEBUG
        if debugForcesReachable { return true }
        #endif
        return isReachable
    }

    // MARK: Kanal langsung (ADR-006)

    private static let liveIDKey = "live.lastID"
    /// Konfirmasi / status / GoTo / Stop lewat `sendMessage`. Penyelesaiannya
    /// bisa dipanggil di antrean latar; pemanggil UI pindah ke main sendiri.
    public private(set) lazy var live: LiveChannelClient = {
        let client = LiveChannelClient(
            session: WCLiveSession(),
            sequence: LiveIDSequence(last: UInt64(UserDefaults.standard.integer(forKey: Self.liveIDKey))))
        client.onSequenceAdvanced = { UserDefaults.standard.set(Int($0), forKey: WatchLinkService.liveIDKey) }
        return client
    }()

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

    /// Kirim pengaturan bersama ke iPhone (ADR-020): langsung (`sendMessage`)
    /// bila terjangkau supaya terasa seketika, **dan** antre
    /// (`transferUserInfo`) sebagai jaminan bila iPhone jauh. Dobel tidak
    /// masalah: iPhone hanya memakai yang terbaru.
    public func push(settings: SyncedSettings) {
        guard let session else { return }
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(settings.plist, replyHandler: nil, errorHandler: nil)
        }
        session.transferUserInfo(settings.plist)
    }

    /// Kirim arah tunjuk ke iPhone untuk Stellarium — hanya bila diminta dan
    /// terjangkau, paling sering 4×/dtk. Tanpa antre: arah lama tidak berguna.
    public func mirror(_ snapshot: PointingSnapshot) {
        guard mirrorRequested, isReachable, let session, let pointing = snapshot.calibratedPointing else { return }
        let locked = snapshot.state == .lock ? snapshot.intent?.best?.id : nil
        let sample = MirrorSample(pointing: pointing, lockedObjectID: locked, state: snapshot.state.rawValue)
        guard mirrorThrottle.shouldSend(sample) else { return }
        session.sendMessage(sample.plist, replyHandler: nil, errorHandler: nil)
    }

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
    ///
    /// - Returns: `true` bila pesannya benar-benar terkirim. Dipakai
    ///   `sendIfDecisionChanged` untuk memutuskan apakah keputusan ini boleh
    ///   dianggap sudah tersampaikan.
    @discardableResult
    public func send(state snapshot: PointingSnapshot,
                     at date: Date = Date(),
                     sigmaDeg: Double? = nil) -> Bool {
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
    /// **Kenapa lewat `deliver`, bukan `shouldReport` lalu `send`.** Kalau
    /// penyaringnya ditanya lebih dulu, keputusan ditandai "sudah dilaporkan"
    /// sebelum pengiriman dicoba. Kiriman yang gagal — dan yang paling sering
    /// di lapangan adalah jam yang belum tersambung ke iPhone — karena itu
    /// **tidak pernah dicoba lagi** untuk keputusan yang sama. iPhone terjebak
    /// di keadaan lama (mis. `lock`) sementara di jam sudah berubah, tanpa
    /// kiriman berikutnya yang membetulkannya. `deliver` menandai terkirim
    /// hanya setelah benar-benar berhasil, jadi percobaan berikutnya masih
    /// dianggap baru. Itu sekaligus memenuhi janji `send(_:)` bahwa kegagalan
    /// tidak diam: penghitungnya naik **dan** kiriman itu diulang.
    ///
    /// - Returns: `true` bila pesan benar-benar terkirim.
    @discardableResult
    public func sendIfDecisionChanged(state snapshot: PointingSnapshot,
                                      at date: Date = Date(),
                                      sigmaDeg: Double? = nil) -> Bool {
        reportGate.deliver(snapshot) { [weak self] snapshot in
            guard let self else { return false }
            return self.send(state: snapshot, at: date, sigmaDeg: sigmaDeg)
        }
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
            lastMessageNote = LinkStatusText.calibrationNotSent
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
    ///
    /// - Returns: `true` bila pesannya benar-benar terkirim. Kegagalan yang
    ///   terlihat saja tidak cukup: pemanggil (lewat `sendIfDecisionChanged`)
    ///   butuh jawaban ini untuk tahu bahwa keputusannya **belum** tersampaikan
    ///   dan masih harus diulang.
    @discardableResult
    public func send(_ message: PointingLinkMessage) -> Bool {
        guard let session, session.activationState == .activated else {
            sendFailureCount += 1
            lastMessageNote = LinkStatusText.messageNotSent
            return false
        }
        do {
            try session.updateApplicationContext(message.plist)
            return true
        } catch {
            sendFailureCount += 1
            lastMessageNote = LinkStatusText.sendFailed(error.localizedDescription)
            return false
        }
    }

    /// Minta keadaan terakhir dari jam (dipakai iPhone saat dibuka).
    /// Kirim berkas JSONL Lab ke iPhone. Antre di latar belakang dan sampai
    /// walau iPhone sedang tidak terjangkau — berbeda dari perintah teleskop,
    /// data riset memang boleh tertunda.
    @discardableResult
    public func transferLabFile(_ url: URL, sessionID: UUID, trialCount: Int) -> Bool {
        guard let session, session.activationState == .activated else {
            labTransferSucceeded = false
            return false
        }
        session.transferFile(url, metadata: [LabLinkKeys.fileMarker: true,
                                             LabLinkKeys.sessionID: sessionID.uuidString,
                                             LabLinkKeys.trialCount: trialCount])
        labTransfersInFlight = session.outstandingFileTransfers.count
        labTransferSucceeded = nil
        return true
    }

    private static var storedLabTargets: [LabTarget] {
        guard let data = UserDefaults.standard.data(forKey: labTargetsKey) else { return [] }
        return (try? JSONDecoder().decode([LabTarget].self, from: data)) ?? []
    }

    private func receiveLab(_ targets: [LabTarget]) {
        labTargets = targets
        if let data = try? JSONEncoder().encode(targets) {
            UserDefaults.standard.set(data, forKey: Self.labTargetsKey)
        }
    }

    public func requestState() {
        send(PointingLinkMessage(kind: .stateRequest))
    }

    private func handle(_ message: PointingLinkMessage) {
        lastMessageNote = message.calibrationNoteText
            ?? message.note
            ?? message.kind.displayName
        switch message.kind {
        case .policyUpdate:
            if let policy = message.confidencePolicy {
                lastPolicyFromPhone = policy
                onPolicyReceived?(policy)
            } else {
                // Ambang tidak masuk akal ditolak, bukan diterapkan diam-diam.
                lastMessageNote = LinkStatusText.invalidPolicyIgnored
            }
        case .stateRequest:
            // Balas dengan keadaan yang berlaku sekarang. Kalau app belum
            // menyediakan sumbernya, katakan terus terang — iPhone yang meminta
            // dan tidak menerima apa-apa akan mengira jam tidak menjawab.
            if let currentSnapshot {
                send(state: currentSnapshot())
            } else {
                lastMessageNote = LinkStatusText.stateRequestTooEarly
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
        // Konteks terakhir dari iPhone tetap ada setelah app jam dibuka ulang.
        let mirror = MirrorSample.isRequest(session.receivedApplicationContext)
        let settings = SyncedSettings(plist: session.receivedApplicationContext)
        Task { @MainActor in
            self.isReachable = reachable
            if let mirror { self.mirrorRequested = mirror }
            // Pengaturan: ambil yang terbaru dari iPhone, lalu kirim milik jam
            // supaya kedua perangkat bertemu di versi yang sama (ADR-020).
            if let settings { SettingsSyncStore.apply(settings) }
            if activationState == .activated { self.push(settings: SettingsSyncStore.local()) }
            if let error {
                // Pesan sistem dibungkus lewat katalog: ia mengikuti bahasa
                // perangkat, bukan bahasa katalog, jadi menampilkannya apa
                // adanya menyisipkan satu baris berbahasa lain di layar
                // Tautan. Namanya tetap ikut (`%@`) supaya dua kegagalan
                // berbeda tidak terbaca sama.
                self.lastMessageNote = LinkStatusText.activationFailed(
                    error.localizedDescription)
            }
        }
    }

    nonisolated public func session(_ session: WCSession,
                                    didReceiveApplicationContext applicationContext: [String: Any]) {
        let status = TelescopeStatus(plist: applicationContext)
        let message = PointingLinkMessage(plist: applicationContext)
        let mirror = MirrorSample.isRequest(applicationContext)
        let settings = SyncedSettings(plist: applicationContext)
        Task { @MainActor in
            if let settings { SettingsSyncStore.apply(settings) }
            if let mirror { self.mirrorRequested = mirror }
            if let status { self.receiveTelescope(status) }
            // Konteks yang sama dikirim ulang setiap laporan teleskop (2 dtk);
            // pesan keadaan yang sudah ditangani tidak boleh dijalankan lagi.
            if let message, message.sentAt != self.lastContextMessageSentAt {
                self.lastContextMessageSentAt = message.sentAt
                self.handle(message)
            }
        }
    }

    nonisolated public func session(_ session: WCSession,
                                    didReceiveMessage message: [String: Any]) {
        if let on = MirrorSample.isRequest(message) {
            Task { @MainActor in self.mirrorRequested = on }
            return
        }
        if let settings = SyncedSettings(plist: message) {
            Task { @MainActor in SettingsSyncStore.apply(settings) }
            return
        }
        guard let decoded = PointingLinkMessage(plist: message) else { return }
        Task { @MainActor in self.handle(decoded) }
    }

    /// Pesan antre dari iPhone (ambang keyakinan dikirim dengan
    /// `transferUserInfo`, jadi ia tiba di sini — bukan di
    /// `didReceiveApplicationContext`).
    nonisolated public func session(_ session: WCSession,
                                    didReceiveUserInfo userInfo: [String: Any]) {
        if let targets = LabLinkKeys.decodeTargets(userInfo) {
            Task { @MainActor in self.receiveLab(targets) }
            return
        }
        guard let decoded = PointingLinkMessage(plist: userInfo) else { return }
        Task { @MainActor in self.handle(decoded) }
    }

    nonisolated public func session(_ session: WCSession,
                                    didFinish fileTransfer: WCSessionFileTransfer,
                                    error: Error?) {
        let ok = error == nil
        let remaining = session.outstandingFileTransfers.count
        Task { @MainActor in
            self.labTransferSucceeded = ok
            self.labTransfersInFlight = remaining
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }
}

/// `WCSession` sebagai `LiveSession`. Tanpa sesi aktif, tidak terjangkau.
final class WCLiveSession: LiveSession {
    private var session: WCSession? {
        WCSession.isSupported() && WCSession.default.activationState == .activated ? WCSession.default : nil
    }

    var isReachable: Bool { session?.isReachable ?? false }

    func sendMessage(_ message: [String: Any],
                     replyHandler: @escaping ([String: Any]) -> Void,
                     errorHandler: @escaping (Error) -> Void) {
        guard let session else {
            errorHandler(NSError(domain: "WCLiveSession", code: 1))
            return
        }
        session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    func transferUserInfo(_ userInfo: [String: Any]) {
        session?.transferUserInfo(userInfo)
    }
}
