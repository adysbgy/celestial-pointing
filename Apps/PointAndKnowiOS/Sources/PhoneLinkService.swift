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
    /// Jam dipasangkan dengan iPhone ini / app jam terpasang (onboarding, ADR-019).
    @Published public private(set) var isPaired = false
    @Published public private(set) var isWatchAppInstalled = false
    @Published public private(set) var isActivated = false
    @Published public private(set) var lastNote: String?
    @Published public private(set) var receivedCount = 0

    /// Setiap pesan yang masuk, untuk direkam ke riwayat keyakinan.
    public var onMessage: ((PointingLinkMessage) -> Void)?
    /// Sampel arah tunjuk untuk cermin Stellarium (ADR-016).
    public var onMirrorSample: ((MirrorSample) -> Void)?
    /// Dipanggil saat jam menjadi terjangkau (mis. untuk meminta ulang cermin).
    public var onReachable: (() -> Void)?

    /// Minta jam memulai/menghentikan aliran arah tunjuk (ADR-016).
    public func requestMirror(_ on: Bool) {
        try? pushContext(mirror: MirrorSample.request(on))
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(MirrorSample.request(on), replyHandler: nil, errorHandler: nil)
    }

    // MARK: Kanal langsung (ADR-006)

    /// Lokasi pengamat untuk menghitung koordinat GoTo, dibaca dari antrean
    /// delegate. Diperbarui view akar dari engine iPhone lewat
    /// `updateObserver`; sampai itu, lokasi cadangan yang berlabel.
    private nonisolated let observerBox = LockedObserver(ObserverLocation.fallback.observer)

    public func updateObserver(_ observer: Observer) { observerBox.value = observer }

    /// Transport teleskop: **tiruan** sampai POC Seestar (ADR-006). Tidak ada
    /// motor yang bisa bergerak lewat jalur ini.
    public let telescopeTransport: MockTelescopeTransport

    /// Server kanal langsung; aman dipanggil dari antrean delegate.
    public nonisolated let liveServer: LiveChannelServer

    /// Peristiwa kanal langsung terakhir, untuk ditampilkan.
    @Published public private(set) var lastLiveReply: LiveReply?

    /// Objek terakhir yang dikonfirmasi di jam (ADR-007). `live` = lewat
    /// kanal langsung (membuka GoTo); `false` = catatan antrean yang tiba
    /// belakangan (riwayat saja).
    @Published public private(set) var lastConfirmed: (message: LiveMessage, live: Bool)?

    /// Berkas Pointing Lab yang sudah diterima (ADR-004).
    @Published public private(set) var labFiles: [URL] = PhoneLinkService.listLabFiles()

    /// Folder penyimpanan berkas Lab di iPhone.
    public nonisolated static var labDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PointingLab", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func listLabFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: labDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return urls.filter { $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    public func refreshLabFiles() { labFiles = Self.listLabFiles() }

    /// Kirim daftar target manual ke jam. Antre (`transferUserInfo`): target
    /// adalah konfigurasi, bukan perintah, jadi boleh sampai belakangan.
    @discardableResult
    public func send(labTargets: [LabTarget]) -> Bool {
        guard let session, session.activationState == .activated else { return false }
        session.transferUserInfo(LabLinkKeys.encodeTargets(labTargets))
        return true
    }

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    public override init() {
        let resolver = EngineFactory.makeResolver()
        let transport = MockTelescopeTransport()
        #if DEBUG
        // Simulator: `-debugMockSlewSeconds 60` memperpanjang slew tiruan
        // supaya Stop di tengah gerakan bisa dicoba.
        let debugSlew = UserDefaults.standard.double(forKey: "debugMockSlewSeconds")
        if debugSlew > 0 { transport.slewDuration = debugSlew }
        #endif
        telescopeTransport = transport
        self.resolver = resolver
        let switchable = SwitchableTelescopeExecutor()
        telescopeExecutor = switchable
        liveServer = LiveChannelServer(executor: switchable)
        super.init()
        useMockTelescope()
    }

    // MARK: Teleskop (ADR-008)

    private let resolver: PointingResolver
    private nonisolated let telescopeExecutor: SwitchableTelescopeExecutor

    public enum TelescopeLink: Equatable {
        /// Fitur Alpaca mati: transport tiruan, tidak ada motor.
        case mock
        /// Fitur Alpaca hidup tapi belum tersambung: **tidak ada** teleskop
        /// (bukan tiruan — tiruan melaporkan "siap" dan memunculkan GoTo).
        case notConnected
        case connecting
        case connected(AlpacaMountInfo)
        /// Tersambung, tapi dudukan tidak bisa dipakai GoTo app ini.
        case unsupported(AlpacaMountInfo)
        case failed(String)
    }

    @Published public private(set) var telescopeLink: TelescopeLink = .mock

    private func executor(for transport: TelescopeTransport,
                          capability: TelescopeCapability,
                          path: String) -> BridgeTelescopeExecutor {
        let preferred = capability.supportedFrames.contains(.j2000) ? CoordinateFrame.j2000 : .ofDate
        let bridge = TelescopeBridge(resolver: resolver, capability: capability, preferredFrame: preferred)
        let session = TelescopeSession(bridge: bridge, transport: transport, commandPath: path)
        let box = observerBox
        return BridgeTelescopeExecutor(resolver: resolver, session: session, transport: transport,
                                       observer: { box.value })
    }

    /// Fitur Alpaca mati. Di build Debug: teleskop tiruan (alur GoTo/Stop bisa
    /// dicoba di simulator). Di build Release: **tidak ada** pelaksana —
    /// tiruan yang melaporkan "siap" akan memunculkan GoTo palsu di jam.
    public func useMockTelescope() {
        #if DEBUG
        let capability = TelescopeCapability(axes: .equatorial, supportedFrames: [.j2000],
                                             firmwareVersion: telescopeTransport.firmwareVersion, canAbort: true)
        telescopeExecutor.use(executor(for: telescopeTransport, capability: capability, path: "mock"))
        #else
        telescopeExecutor.use(nil)
        #endif
        telescopeLink = .mock
    }

    /// Terapkan pengaturan dari Link tab: mati → tiruan (Debug) / tidak ada
    /// (Release); hidup → sambung bila ada alamat, kalau tidak "belum
    /// tersambung" tanpa pelaksana.
    public func applyTelescopeSettings(alpacaEnabled: Bool, address: String) async {
        guard alpacaEnabled else { useMockTelescope(); return }
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            telescopeExecutor.use(nil)
            telescopeLink = .notConnected
            return
        }
        await connectAlpaca(address: trimmed)
    }

    /// Sambungkan ke teleskop Alpaca di `address` ("host:port"). Sampai
    /// tersambung dan dudukannya didukung, tidak ada pelaksana: GoTo ditolak
    /// sebagai `telescopeUnavailable`.
    public func connectAlpaca(address: String) async {
        telescopeExecutor.use(nil)
        telescopeLink = .connecting
        do {
            let telescope = AlpacaTelescope(client: try AlpacaClient(address: address))
            let mount = try await telescope.connect()
            guard let capability = mount.capability(firmware: "alpaca") else {
                telescopeLink = .unsupported(mount)
                return
            }
            let transport = AlpacaTelescopeTransport(telescope: telescope, mount: mount)
            telescopeExecutor.use(executor(for: transport, capability: capability, path: "alpaca:\(address)"))
            telescopeLink = .connected(mount)
        } catch {
            telescopeLink = .failed(String(describing: error))
        }
    }

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
            try pushContext(pointing: message.plist)
            lastNote = LinkStatusText.sent(message.kind.displayName)
        } catch {
            lastNote = LinkStatusText.sendFailed(error.localizedDescription)
        }
    }

    /// `updateApplicationContext` menyimpan **satu** kamus; pesan keadaan dan
    /// laporan teleskop (ADR-009) masing-masing punya kunci sendiri, jadi
    /// keduanya digabung di sini — kalau tidak, yang satu menghapus yang lain.
    /// Dua bagian disimpan terpisah: pesan keadaan baru **mengganti** bagian
    /// pesan seluruhnya (kunci basi pesan lama tidak boleh menempel), laporan
    /// teleskop hanya mengganti kuncinya sendiri.
    private var pointingPart: [String: Any] = [:]
    private var telescopePart: [String: Any] = [:]
    /// Permintaan cermin Stellarium (ADR-016). Ikut konteks supaya jam yang
    /// baru dibuka ulang tetap tahu, tidak hanya pesan sekali kirim.
    private var mirrorPart: [String: Any] = [:]

    private func pushContext(pointing: [String: Any]? = nil, telescope: [String: Any]? = nil,
                             mirror: [String: Any]? = nil) throws {
        // Simpan bagiannya **dulu**, baru periksa sesi: permintaan yang datang
        // sebelum WCSession aktif (jembatan Stellarium tersambung ~150 ms
        // setelah app dibuka) tidak boleh hilang — ia ikut kiriman berikutnya.
        if let pointing { pointingPart = pointing }
        if let telescope { telescopePart = telescope }
        if let mirror { mirrorPart = mirror }
        guard let session, session.activationState == .activated else { return }
        try session.updateApplicationContext(
            pointingPart.merging(telescopePart) { _, t in t }.merging(mirrorPart) { _, m in m })
    }

    // MARK: Laporan keadaan teleskop ke jam (ADR-009)

    private var statusTimer: Timer?
    @Published public private(set) var lastTelescopeStatus: TelescopeStatus?

    /// Laporkan keadaan teleskop ke jam setiap 2 dtk (jam menganggap laporan
    /// > 10 dtk basi). Membaca keadaan Alpaca bisa memblok hingga 2,5 dtk, jadi
    /// dijalankan di luar main thread.
    public func startTelescopeStatusReports() {
        guard statusTimer == nil else { return }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportTelescopeStatus() }
        }
        reportTelescopeStatus()
    }

    private func reportTelescopeStatus() {
        let link = telescopeLink
        let executor = telescopeExecutor
        Task.detached {
            let status: TelescopeStatus
            switch link {
            case .mock:
                #if DEBUG
                // Tiruan dihitung "aktif" hanya di build Debug, supaya alur
                // GoTo/Stop bisa dicoba di simulator tanpa teleskop.
                status = TelescopeStatus(readiness: executor.readiness(), at: Date(), detail: "mock")
                #else
                status = TelescopeStatus(state: .disabled, at: Date())
                #endif
            case .notConnected, .connecting, .unsupported:
                status = TelescopeStatus(state: .disconnected, at: Date())
            case .failed(let why):
                status = TelescopeStatus(state: .error, at: Date(), detail: why)
            case .connected:
                status = TelescopeStatus(readiness: executor.readiness(), at: Date(), detail: "alpaca")
            }
            await self.publish(telescopeStatus: status)
        }
    }

    private func publish(telescopeStatus status: TelescopeStatus) {
        lastTelescopeStatus = status
        try? pushContext(telescope: status.plist)
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
    /// Berkas harus dipindah **sebelum** metode ini kembali: sistem menghapus
    /// berkas sementaranya setelah itu.
    nonisolated public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?[LabLinkKeys.fileMarker] as? Bool == true else { return }
        let destination = PhoneLinkService.labDirectory
            .appendingPathComponent(file.fileURL.lastPathComponent)
        let fm = FileManager.default
        try? fm.removeItem(at: destination)
        try? fm.moveItem(at: file.fileURL, to: destination)
        Task { @MainActor in self.refreshLabFiles() }
    }


    nonisolated public func session(_ session: WCSession,
                                    activationDidCompleteWith activationState: WCSessionActivationState,
                                    error: Error?) {
        let reachable = session.isReachable
        let activated = activationState == .activated
        let message = error?.localizedDescription
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            self.isReachable = reachable
            self.isActivated = activated
            self.isPaired = paired
            self.isWatchAppInstalled = installed
            // Bagian konteks yang tertahan sebelum sesi aktif ikut terkirim
            // sekarang, dan pemakai "terjangkau" (cermin Stellarium) diberi tahu
            // — `sessionReachabilityDidChange` tidak terpanggil bila sudah
            // terjangkau sejak awal.
            if activated { try? self.pushContext() }
            if reachable { self.onReachable?() }
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

    nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            self.isPaired = paired
            self.isWatchAppInstalled = installed
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if reachable { self.onReachable?() }
        }
    }

    nonisolated public func session(_ session: WCSession,
                                    didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let message = PointingLinkMessage(plist: applicationContext) else { return }
        Task { @MainActor in self.handle(message) }
    }

    nonisolated public func session(_ session: WCSession,
                                    didReceiveMessage message: [String: Any]) {
        if let sample = MirrorSample(plist: message) {
            Task { @MainActor in self.onMirrorSample?(sample) }
            return
        }
        guard let decoded = PointingLinkMessage(plist: message) else { return }
        Task { @MainActor in self.handle(decoded) }
    }

    /// Kanal langsung: dijawab **di sini**, sinkron, supaya jam tahu hasilnya
    /// selagi pengguna masih menunggu (ADR-006).
    nonisolated public func session(_ session: WCSession,
                                    didReceiveMessage message: [String: Any],
                                    replyHandler: @escaping ([String: Any]) -> Void) {
        guard LiveMessage(plist: message) != nil else {
            replyHandler([:])
            if let decoded = PointingLinkMessage(plist: message) {
                Task { @MainActor in self.handle(decoded) }
            }
            return
        }
        let reply = liveServer.handle(message)
        replyHandler(reply)
        let decoded = LiveReply(plist: reply)
        let incoming = LiveMessage(plist: message)
        Task { @MainActor in
            self.lastLiveReply = decoded
            if let incoming, incoming.kind == .confirmTarget, decoded?.accepted == true {
                self.lastConfirmed = (incoming, true)
            }
        }
    }

    #if DEBUG
    /// Simulator: `-debugConfirmed saturn` mengisi kartu "Dikonfirmasi" tanpa
    /// jam berpasangan, untuk tangkapan layar tab Langit (ADR-013).
    func injectDebugConfirmationIfRequested() {
        guard lastConfirmed == nil,
              let id = UserDefaults.standard.string(forKey: "debugConfirmed"), !id.isEmpty else { return }
        lastConfirmed = (LiveMessage(id: 1, sentAt: Date(), kind: .confirmTarget, objectID: id), true)
    }
    #endif

    /// Pesan antre dari jam. Kalibrasi dan permintaan keadaan dikirim jam
    /// dengan `transferUserInfo`, jadi keduanya tiba di sini — bukan di
    /// `didReceiveApplicationContext`.
    nonisolated public func session(_ session: WCSession,
                                    didReceiveUserInfo userInfo: [String: Any]) {
        // Catatan konfirmasi dari antrean: riwayat saja (ADR-006).
        if let record = LiveMessage(plist: userInfo) {
            liveServer.record(userInfo)
            Task { @MainActor in
                // Catatan yang lebih tua dari konfirmasi langsung terakhir
                // tidak menimpanya.
                if record.kind == .confirmRecord,
                   (self.lastConfirmed?.message.id ?? 0) < record.id {
                    self.lastConfirmed = (record, false)
                }
            }
            return
        }
        guard let decoded = PointingLinkMessage(plist: userInfo) else { return }
        Task { @MainActor in self.handle(decoded) }
    }
}

/// Kotak `Observer` yang aman dibaca dari antrean mana pun.
final class LockedObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Observer

    init(_ value: Observer) { stored = value }

    var value: Observer {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}
