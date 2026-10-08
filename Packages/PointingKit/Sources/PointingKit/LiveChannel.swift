import Foundation
import CelestialEngine

// MARK: - Kanal langsung jam <-> iPhone (ADR-006)
//
// `PointingLinkMessage` memakai `updateApplicationContext`/`transferUserInfo`:
// keadaan terakhir dan antrean. Itu benar untuk keadaan, dan **salah** untuk
// tindakan: GoTo yang diantre bisa dieksekusi beberapa menit kemudian, saat
// pengguna sudah pergi dari teleskop. Kanal ini memakai `sendMessage` dengan
// balasan, dan aturannya ditegakkan di sini (teruji di Linux), bukan di app:
//
// - GoTo / Stop / status: hanya saat iPhone terjangkau. Tidak terjangkau =
//   gagal **sekarang**, terlihat. Tidak pernah diantre.
// - Konfirmasi objek: langsung bila terjangkau; bila tidak, dicatat lewat
//   `transferUserInfo` sebagai **riwayat saja** — catatan itu tidak pernah
//   membuka jalan untuk GoTo.
// - Setiap pesan punya id yang naik terus dan `sentAt`. iPhone menolak GoTo
//   yang lebih tua dari 3 dtk dan id yang tidak lebih baru dari yang terakhir.

public enum LiveKind: String, Codable, Equatable, Sendable {
    case confirmTarget
    case confirmRecord
    case telescopeStatus
    case goTo
    case stop
}

public struct LiveMessage: Equatable, Codable, Sendable {
    public static let plistKey = "live.v1"

    public var id: UInt64
    public var sentAt: Date
    public var kind: LiveKind
    public var objectID: String?
    public var objectName: String?

    public init(id: UInt64, sentAt: Date, kind: LiveKind,
                objectID: String? = nil, objectName: String? = nil) {
        self.id = id
        self.sentAt = sentAt
        self.kind = kind
        self.objectID = objectID
        self.objectName = objectName
    }

    public var plist: [String: Any] {
        [Self.plistKey: (try? LiveCoding.encoder.encode(self)) ?? Data()]
    }

    public init?(plist: [String: Any]) {
        guard let data = plist[Self.plistKey] as? Data,
              let m = try? LiveCoding.decoder.decode(LiveMessage.self, from: data) else { return nil }
        self = m
    }
}

public enum LiveRejection: String, Codable, Equatable, Sendable {
    /// iPhone tidak terjangkau saat tindakan diminta.
    case unreachable
    /// Pesan GoTo terlalu tua (atau dari masa depan) saat tiba.
    case stale
    /// id tidak lebih baru dari pesan terakhir yang diterima.
    case replayed
    /// GoTo untuk objek yang belum dikonfirmasi lewat kanal langsung.
    case notConfirmed
    /// Objek tidak dikenal katalog/efemeris iPhone.
    case unknownObject
    /// Teleskop tidak tersambung atau tidak siap.
    case telescopeUnavailable
    /// Pengaman slew menolak (Matahari, ketinggian, dsb.). Rincian di `detail`.
    case unsafe
    /// Pengiriman atau perintah transport gagal.
    case transportFailed
    /// Pesan tidak bisa dibaca.
    case badMessage
}

public struct LiveReply: Equatable, Codable, Sendable {
    public static let plistKey = "live.reply.v1"

    public var id: UInt64
    public var accepted: Bool
    public var rejection: LiveRejection?
    public var detail: String?
    public var telescope: TelescopeReadiness?

    public init(id: UInt64, accepted: Bool, rejection: LiveRejection? = nil,
                detail: String? = nil, telescope: TelescopeReadiness? = nil) {
        self.id = id
        self.accepted = accepted
        self.rejection = rejection
        self.detail = detail
        self.telescope = telescope
    }

    public var plist: [String: Any] {
        [Self.plistKey: (try? LiveCoding.encoder.encode(self)) ?? Data()]
    }

    public init?(plist: [String: Any]) {
        guard let data = plist[Self.plistKey] as? Data,
              let r = try? LiveCoding.decoder.decode(LiveReply.self, from: data) else { return nil }
        self = r
    }
}

enum LiveCoding {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }()
}

/// Penghitung id yang naik terus. App menyimpan `last` (mis. UserDefaults)
/// supaya id tetap naik setelah app dimulai ulang.
public struct LiveIDSequence: Equatable, Sendable {
    public private(set) var last: UInt64

    public init(last: UInt64 = 0) { self.last = last }

    public mutating func next() -> UInt64 {
        last &+= 1
        return last
    }
}

// MARK: - Sisi jam

/// Abstraksi `WCSession` yang dibutuhkan kanal, supaya bisa diuji dengan sesi
/// palsu.
public protocol LiveSession: AnyObject {
    var isReachable: Bool { get }
    func sendMessage(_ message: [String: Any],
                     replyHandler: @escaping ([String: Any]) -> Void,
                     errorHandler: @escaping (Error) -> Void)
    func transferUserInfo(_ userInfo: [String: Any])
}

public enum LiveSendResult: Equatable, Sendable {
    /// iPhone menjawab (diterima atau ditolak — lihat `LiveReply`).
    case replied(LiveReply)
    /// Konfirmasi tidak bisa dikirim langsung; dicatat sebagai riwayat saja.
    case recordedOnly
    /// Gagal tanpa jawaban. Untuk GoTo/Stop: tidak ada yang diantre.
    case failed(LiveRejection)
}

public final class LiveChannelClient {
    private let session: LiveSession
    private let now: () -> Date
    public private(set) var sequence: LiveIDSequence
    /// Dipanggil setiap id baru dipakai, supaya app bisa menyimpannya.
    public var onSequenceAdvanced: ((UInt64) -> Void)?

    public init(session: LiveSession, sequence: LiveIDSequence = LiveIDSequence(),
                now: @escaping () -> Date = Date.init) {
        self.session = session
        self.sequence = sequence
        self.now = now
    }

    private func make(_ kind: LiveKind, objectID: String? = nil, name: String? = nil) -> LiveMessage {
        let id = sequence.next()
        onSequenceAdvanced?(id)
        return LiveMessage(id: id, sentAt: now(), kind: kind, objectID: objectID, objectName: name)
    }

    /// Konfirmasi objek. Langsung bila iPhone terjangkau; bila tidak (atau
    /// gagal), dicatat sebagai riwayat lewat antrean — tanpa membuka GoTo.
    public func confirm(objectID: String, name: String,
                        completion: @escaping (LiveSendResult) -> Void) {
        let message = make(.confirmTarget, objectID: objectID, name: name)
        let record = { [session] in
            var r = message
            r.kind = .confirmRecord
            session.transferUserInfo(r.plist)
            completion(.recordedOnly)
        }
        guard session.isReachable else { record(); return }
        session.sendMessage(message.plist, replyHandler: { reply in
            if let r = LiveReply(plist: reply) { completion(.replied(r)) } else { completion(.failed(.badMessage)) }
        }, errorHandler: { _ in record() })
    }

    public func requestTelescopeStatus(completion: @escaping (LiveSendResult) -> Void) {
        sendLiveOnly(make(.telescopeStatus), completion: completion)
    }

    public func goTo(objectID: String, name: String,
                     completion: @escaping (LiveSendResult) -> Void) {
        sendLiveOnly(make(.goTo, objectID: objectID, name: name), completion: completion)
    }

    public func stop(completion: @escaping (LiveSendResult) -> Void) {
        sendLiveOnly(make(.stop), completion: completion)
    }

    /// Hanya `sendMessage`. Tidak terjangkau atau gagal = gagal sekarang;
    /// **tidak ada** jalur antrean di fungsi ini.
    private func sendLiveOnly(_ message: LiveMessage, completion: @escaping (LiveSendResult) -> Void) {
        guard session.isReachable else {
            completion(.failed(.unreachable))
            return
        }
        session.sendMessage(message.plist, replyHandler: { reply in
            if let r = LiveReply(plist: reply) { completion(.replied(r)) } else { completion(.failed(.badMessage)) }
        }, errorHandler: { _ in completion(.failed(.transportFailed)) })
    }
}

// MARK: - Sisi iPhone

/// Pelaksana teleskop di balik `TelescopeBridge`.
public protocol TelescopeExecutor: AnyObject {
    func readiness() -> TelescopeReadiness
    /// `nil` bila objek tidak dikenal.
    func goTo(objectID: String, now: Date) -> TelescopeAttempt?
    func stop(now: Date) -> TelescopeAttempt
}

public final class LiveChannelServer {
    /// Umur maksimum GoTo saat tiba (detik), ke dua arah (jam bisa sedikit
    /// berbeda dari iPhone).
    public var maxGoToAge: TimeInterval = 3

    private let executor: TelescopeExecutor
    private let now: () -> Date
    public private(set) var lastSeenID: UInt64 = 0
    /// Objek terakhir yang dikonfirmasi **lewat kanal langsung**.
    public private(set) var confirmedObjectID: String?
    /// Riwayat (termasuk catatan antrean); tidak pernah dieksekusi.
    public private(set) var history: [LiveMessage] = []
    public private(set) var attempts: [TelescopeAttempt] = []

    /// `WCSessionDelegate` dipanggil di antrean latar; satu kunci menjaga
    /// urutan id dan objek terkonfirmasi tetap konsisten.
    private let lock = NSLock()

    public init(executor: TelescopeExecutor, now: @escaping () -> Date = Date.init) {
        self.executor = executor
        self.now = now
    }

    /// Untuk `session(_:didReceiveMessage:replyHandler:)`.
    public func handle(_ plist: [String: Any]) -> [String: Any] {
        handle(message: LiveMessage(plist: plist)).plist
    }

    public func handle(message: LiveMessage?) -> LiveReply {
        lock.lock()
        defer { lock.unlock() }
        guard let m = message else { return LiveReply(id: 0, accepted: false, rejection: .badMessage) }
        history.append(m)

        // Stop selalu dijalankan: menghentikan motor adalah arah yang aman,
        // dan Stop yang ditolak karena urutan id lebih berbahaya daripada
        // Stop yang terlambat.
        if m.kind == .stop {
            lastSeenID = max(lastSeenID, m.id)
            let attempt = executor.stop(now: now())
            attempts.append(attempt)
            return attempt.outcome == .aborted
                ? LiveReply(id: m.id, accepted: true, telescope: executor.readiness())
                : LiveReply(id: m.id, accepted: false, rejection: .transportFailed,
                            detail: attempt.errorDescription)
        }

        guard m.id > lastSeenID else {
            return LiveReply(id: m.id, accepted: false, rejection: .replayed)
        }
        lastSeenID = m.id

        switch m.kind {
        case .confirmTarget:
            guard let id = m.objectID else { return LiveReply(id: m.id, accepted: false, rejection: .badMessage) }
            confirmedObjectID = id
            return LiveReply(id: m.id, accepted: true, telescope: executor.readiness())

        case .confirmRecord:
            // Catatan antrean yang kebetulan tiba lewat jalur langsung: tetap
            // hanya riwayat.
            return LiveReply(id: m.id, accepted: true)

        case .telescopeStatus:
            return LiveReply(id: m.id, accepted: true, telescope: executor.readiness())

        case .goTo:
            let age = now().timeIntervalSince(m.sentAt)
            guard abs(age) <= maxGoToAge else {
                return LiveReply(id: m.id, accepted: false, rejection: .stale,
                                 detail: String(format: "%.1f s", age))
            }
            guard let objectID = m.objectID, objectID == confirmedObjectID else {
                return LiveReply(id: m.id, accepted: false, rejection: .notConfirmed)
            }
            let readiness = executor.readiness()
            guard readiness == .ready else {
                return LiveReply(id: m.id, accepted: false, rejection: .telescopeUnavailable,
                                 telescope: readiness)
            }
            guard let attempt = executor.goTo(objectID: objectID, now: now()) else {
                return LiveReply(id: m.id, accepted: false, rejection: .unknownObject)
            }
            attempts.append(attempt)
            switch attempt.outcome {
            case .issued:
                return LiveReply(id: m.id, accepted: true, telescope: executor.readiness())
            case .refused:
                return LiveReply(id: m.id, accepted: false, rejection: .unsafe, detail: attempt.errorDescription)
            case .failed, .aborted:
                return LiveReply(id: m.id, accepted: false, rejection: .transportFailed,
                                 detail: attempt.errorDescription)
            }

        case .stop:
            return LiveReply(id: m.id, accepted: false, rejection: .badMessage) // ditangani di atas
        }
    }

    /// Untuk `session(_:didReceiveUserInfo:)`: hanya riwayat, tidak pernah
    /// mengubah objek terkonfirmasi atau menjalankan apa pun.
    public func record(_ plist: [String: Any]) {
        guard let m = LiveMessage(plist: plist) else { return }
        lock.lock()
        defer { lock.unlock() }
        history.append(m)
    }
}

// MARK: - Pelaksana lewat TelescopeBridge

/// Menjalankan GoTo untuk objek **yang sudah dikonfirmasi pengguna** lewat
/// `SlewPlanner` + `TelescopeSession`.
///
/// Konfirmasi pengguna menggantikan keyakinan pointing (identitasnya sudah
/// diputuskan manusia), jadi `intent.level` diisi `.high`. Pengaman geometris
/// — Matahari, ketinggian, kecerlangan, posisi Matahari tak diketahui — tetap
/// berlaku persis sama.
public final class BridgeTelescopeExecutor: TelescopeExecutor {
    private let resolver: PointingResolver
    private let session: TelescopeSession
    private let transport: TelescopeTransport
    private let observer: () -> Observer
    public var policy = SlewSafetyPolicy()

    public init(resolver: PointingResolver, session: TelescopeSession,
                transport: TelescopeTransport, observer: @escaping () -> Observer) {
        self.resolver = resolver
        self.session = session
        self.transport = transport
        self.observer = observer
    }

    public func readiness() -> TelescopeReadiness {
        (try? transport.readState()) ?? .disconnected
    }

    public func goTo(objectID: String, now: Date) -> TelescopeAttempt? {
        let obs = observer()
        guard let direction = resolver.horizontal(ofObjectID: objectID, observer: obs, date: now) else {
            return nil
        }
        var resolution = resolver.diagnose(pointing: direction, observer: obs, date: now, coneDeg: 1)
        guard let object = resolution.intent.candidates.first(where: { $0.object.id == objectID })?.object
                ?? (resolution.intent.best?.id == objectID ? resolution.intent.best : nil) else {
            return nil
        }
        resolution.intent = CelestialIntent(level: .high, best: object, candidates: [])
        let decision = SlewPlanner.plan(resolution: resolution, targetHorizontal: direction, policy: policy)
        return session.execute(decision, observer: obs, date: now)
    }

    public func stop(now: Date) -> TelescopeAttempt {
        session.abort(now: now)
    }
}

/// Transport tiruan: belum ada teleskop sungguhan di jalur ini (Seestar POC
/// menyusul, ADR-006). Mencatat perintah, tidak menggerakkan apa pun.
public final class MockTelescopeTransport: TelescopeTransport {
    public var firmwareVersion = "mock"
    public var state: TelescopeReadiness = .ready
    public var failNextGoTo = false
    public private(set) var commands: [TelescopeCommand] = []
    public private(set) var abortCount = 0

    public init() {}

    public func readState() throws -> TelescopeReadiness { state }

    public func goTo(_ command: TelescopeCommand) throws {
        if failNextGoTo {
            failNextGoTo = false
            throw NSError(domain: "MockTelescope", code: 1)
        }
        commands.append(command)
        state = .slewing
    }

    public func abort() throws {
        abortCount += 1
        state = .ready
    }
}
