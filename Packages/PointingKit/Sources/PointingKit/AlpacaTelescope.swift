import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import CelestialEngine

// MARK: - ASCOM Alpaca Telescope v1 (ADR-008)
//
// Transport teleskop standar pertama. Alasannya di ADR-008: Seestar dengan
// firmware ≥ 7.18 butuh sertifikat klien dari app ZWO untuk jalur
// native-nya, sedangkan seestar_alp bisa menjembatani Seestar ke Alpaca. Jadi
// app berbicara Alpaca standar, dan jalur native menunggu.
//
// Hanya bagian Alpaca yang dibutuhkan alur GoTo yang diimplementasikan:
// connected, canslewasync, equatorialsystem, tracking, slewtocoordinatesasync,
// slewing, abortslew. Setiap permintaan membawa ClientID dan
// ClientTransactionID; `ErrorNumber` ≠ 0 menjadi `AlpacaError.device`.

public enum AlpacaError: Error, Equatable, Sendable {
    /// Galat yang dilaporkan perangkat (`ErrorNumber`, `ErrorMessage`).
    case device(number: Int, message: String)
    /// HTTP bukan 2xx.
    case http(status: Int)
    /// Jawaban tidak bisa dibaca sebagai JSON Alpaca.
    case badResponse
    /// Tidak ada jawaban dalam batas waktu.
    case timeout
    /// Alamat tidak sah.
    case badAddress

    /// Kode Alpaca yang dipakai di sini (ASCOM Alpaca API, "ErrorNumber").
    public static let notImplemented = 0x400
    public static let invalidValue = 0x401
    public static let notConnected = 0x407
    public static let invalidWhileParked = 0x408
    public static let invalidWhileSlaved = 0x409
}

/// `EquatorialSystem` Alpaca (`EquatorialCoordinateType`).
public enum AlpacaEquatorialSystem: Int, Equatable, Sendable {
    case other = 0
    /// Koordinat topocentric/apparent pada tanggal pengamatan (JNow).
    case topocentric = 1
    case j2000 = 2
    case j2050 = 3
    case b1950 = 4

    /// Kerangka `TelescopeBridge` yang setara, atau `nil` bila app belum
    /// mendukungnya (dan GoTo harus ditolak, bukan ditebak).
    public var bridgeFrame: CoordinateFrame? {
        switch self {
        case .topocentric: return .ofDate
        case .j2000: return .j2000
        case .other, .j2050, .b1950: return nil
        }
    }
}

/// Klien HTTP Alpaca untuk satu perangkat teleskop.
public final class AlpacaClient: @unchecked Sendable {
    public let baseURL: URL
    public let clientID: UInt32
    private let session: URLSession
    private let lock = NSLock()
    private var transactionID: UInt32 = 0

    /// - Parameters:
    ///   - address: "host:port" atau URL lengkap.
    ///   - deviceNumber: nomor perangkat Alpaca (biasanya 0).
    public init(address: String, deviceNumber: Int = 0, clientID: UInt32 = 1,
                session: URLSession = .shared) throws {
        let raw = address.contains("://") ? address : "http://\(address)"
        guard let root = URL(string: raw), root.host != nil else { throw AlpacaError.badAddress }
        baseURL = root.appendingPathComponent("api/v1/telescope/\(deviceNumber)")
        self.clientID = clientID
        self.session = session
    }

    private func nextTransaction() -> UInt32 {
        lock.lock(); defer { lock.unlock() }
        transactionID &+= 1
        return transactionID
    }

    struct Envelope: Decodable {
        let Value: AlpacaValue?
        let ErrorNumber: Int
        let ErrorMessage: String?
    }

    func get(_ method: String) async throws -> AlpacaValue? {
        var components = URLComponents(url: baseURL.appendingPathComponent(method), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "ClientID", value: String(clientID)),
                                 URLQueryItem(name: "ClientTransactionID", value: String(nextTransaction()))]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        return try await send(request)
    }

    func put(_ method: String, _ parameters: [String: String] = [:]) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(method))
        request.httpMethod = "PUT"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var all = parameters
        all["ClientID"] = String(clientID)
        all["ClientTransactionID"] = String(nextTransaction())
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        request.httpBody = all.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&").data(using: .utf8)
        _ = try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> AlpacaValue? {
        var request = request
        request.timeoutInterval = 5
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AlpacaError.http(status: http.statusCode)
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            throw AlpacaError.badResponse
        }
        guard envelope.ErrorNumber == 0 else {
            throw AlpacaError.device(number: envelope.ErrorNumber, message: envelope.ErrorMessage ?? "")
        }
        return envelope.Value
    }
}

/// Nilai `Value` Alpaca yang dipakai di sini.
enum AlpacaValue: Decodable, Equatable {
    case bool(Bool), int(Int), double(Double), string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else { self = .string(try c.decode(String.self)) }
    }

    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var int: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }
}

/// Apa yang dilaporkan dudukan saat tersambung.
public struct AlpacaMountInfo: Equatable, Sendable {
    public var canSlewAsync: Bool
    public var equatorialSystem: AlpacaEquatorialSystem

    /// Kemampuan untuk `TelescopeBridge`. `nil` bila dudukan tidak bisa
    /// dipakai untuk GoTo app ini (tidak ada slew async atau kerangka yang
    /// tidak didukung) — GoTo dimatikan, bukan dicoba.
    public func capability(firmware: String) -> TelescopeCapability? {
        guard canSlewAsync, let frame = equatorialSystem.bridgeFrame else { return nil }
        return TelescopeCapability(axes: .equatorial, supportedFrames: [frame],
                                   firmwareVersion: firmware, canAbort: true)
    }
}

/// Teleskop Alpaca (async).
public final class AlpacaTelescope: @unchecked Sendable {
    public let client: AlpacaClient

    public init(client: AlpacaClient) { self.client = client }

    /// Sambungkan dan baca kemampuan yang dibutuhkan GoTo.
    public func connect() async throws -> AlpacaMountInfo {
        try await client.put("connected", ["Connected": "True"])
        let canAsync = try await client.get("canslewasync")?.bool ?? false
        let system = AlpacaEquatorialSystem(rawValue: try await client.get("equatorialsystem")?.int ?? 0) ?? .other
        return AlpacaMountInfo(canSlewAsync: canAsync, equatorialSystem: system)
    }

    public func isConnected() async throws -> Bool {
        try await client.get("connected")?.bool ?? false
    }

    public func isSlewing() async throws -> Bool {
        try await client.get("slewing")?.bool ?? false
    }

    /// Mulai slew async ke RA (jam) / Dec (derajat) **dalam kerangka dudukan**.
    /// Tracking dinyalakan dulu; dudukan yang tidak mendukung pengaturan
    /// tracking (NotImplemented) tetap dicoba slew.
    public func slewAsync(raHours: Double, decDeg: Double) async throws {
        do {
            try await client.put("tracking", ["Tracking": "True"])
        } catch AlpacaError.device(let number, _) where number == AlpacaError.notImplemented {
        }
        try await client.put("slewtocoordinatesasync",
                             ["RightAscension": String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), raHours),
                              "Declination": String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), decDeg)])
    }

    public func abort() async throws {
        try await client.put("abortslew")
    }
}

/// `TelescopeTransport` (sinkron) di atas `AlpacaTelescope`.
///
/// Protokol transport sinkron karena dipanggil dari antrean delegate
/// WatchConnectivity, yang harus menjawab sebelum batas waktu jam (4 dtk,
/// ADR-006). Setiap panggilan HTTP dibatasi `timeout`; tidak pernah dipanggil
/// dari main thread.
public final class AlpacaTelescopeTransport: TelescopeTransport, @unchecked Sendable {
    public let telescope: AlpacaTelescope
    public let mount: AlpacaMountInfo
    public var timeout: TimeInterval = 2.5
    public let firmwareVersion: String

    public init(telescope: AlpacaTelescope, mount: AlpacaMountInfo, firmwareVersion: String = "alpaca") {
        self.telescope = telescope
        self.mount = mount
        self.firmwareVersion = firmwareVersion
    }

    public func readState() throws -> TelescopeReadiness {
        try blocking {
            guard try await self.telescope.isConnected() else { return .disconnected }
            return try await self.telescope.isSlewing() ? .slewing : .ready
        }
    }

    public func goTo(_ command: TelescopeCommand) throws {
        guard case .equatorial(let eq, let frame) = command.target,
              frame == mount.equatorialSystem.bridgeFrame else {
            throw AlpacaError.device(number: AlpacaError.invalidValue,
                                     message: "target frame does not match mount EquatorialSystem")
        }
        try blocking { try await self.telescope.slewAsync(raHours: eq.raDeg / 15, decDeg: eq.decDeg) }
    }

    public func abort() throws {
        try blocking { try await self.telescope.abort() }
    }

    private func blocking<T>(_ operation: @escaping @Sendable () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()
        Task.detached {
            do { box.result = .success(try await operation()) } catch { box.result = .failure(error) }
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success, let result = box.result else {
            throw AlpacaError.timeout
        }
        return try result.get()
    }
}

private final class ResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}

// MARK: - Pelaksana yang bisa diganti

/// Pelaksana yang bisa ditukar saat berjalan (tiruan ↔ Alpaca), aman dari
/// antrean delegate. Tanpa pelaksana: teleskop `disconnected`, GoTo ditolak.
public final class SwitchableTelescopeExecutor: TelescopeExecutor, @unchecked Sendable {
    private let lock = NSLock()
    private var inner: TelescopeExecutor?

    public init(_ inner: TelescopeExecutor? = nil) { self.inner = inner }

    public func use(_ executor: TelescopeExecutor?) {
        lock.lock(); inner = executor; lock.unlock()
    }

    private var current: TelescopeExecutor? {
        lock.lock(); defer { lock.unlock() }
        return inner
    }

    public func readiness() -> TelescopeReadiness { current?.readiness() ?? .disconnected }

    public func goTo(objectID: String, now: Date) -> TelescopeAttempt? {
        current?.goTo(objectID: objectID, now: now)
    }

    public func stop(now: Date) -> TelescopeAttempt {
        current?.stop(now: now) ?? TelescopeAttempt(
            objectID: "—", target: .horizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0)),
            confidence: .low, firmwareVersion: "none", commandPath: "none",
            outcome: .failed, errorDescription: "no telescope", timestamp: now)
    }
}
