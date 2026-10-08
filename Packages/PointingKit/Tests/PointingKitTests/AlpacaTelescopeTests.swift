import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PointingKit
@testable import CelestialEngine

/// Server Alpaca palsu di dalam proses (URLProtocol). Meniru cukup banyak
/// perilaku dudukan untuk alur GoTo: sambung, slew async yang berjalan
/// beberapa polling, abort, galat di tengah slew, perangkat terputus, dan
/// dudukan tanpa slew async.
final class FakeAlpacaServer: URLProtocol {
    struct Request: Equatable {
        var method: String
        var verb: String
        var params: [String: String]
    }

    final class State: @unchecked Sendable {
        let lock = NSLock()
        var connected = false
        var deviceOffline = false
        var canSlewAsync = true
        var equatorialSystem = 2
        var slewingPolls = 0
        var failMidSlew = false
        var slewStarted = false
        var trackingNotImplemented = false
        var requests: [Request] = []
    }

    nonisolated(unsafe) static var state = State()

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeAlpacaServer.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url!
        let method = url.lastPathComponent
        var params: [String: String] = [:]
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for i in items { params[i.name] = i.value }
        }
        if let body = request.httpBody ?? request.httpBodyStream.flatMap(Self.read),
           let text = String(data: body, encoding: .utf8) {
            for pair in text.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2 { params[kv[0]] = kv[1].removingPercentEncoding }
            }
        }
        let s = Self.state
        s.lock.lock()
        s.requests.append(Request(method: method, verb: request.httpMethod ?? "", params: params))
        var value: Any = NSNull()
        var error = 0
        var message = ""
        func notConnected() { error = AlpacaError.notConnected; message = "Not connected" }

        switch (request.httpMethod ?? "", method) {
        case ("PUT", "connected"):
            if s.deviceOffline { notConnected() } else { s.connected = true }
        case ("GET", "connected"):
            value = s.connected && !s.deviceOffline
        case ("GET", "canslewasync"):
            if s.connected { value = s.canSlewAsync } else { notConnected() }
        case ("GET", "equatorialsystem"):
            if s.connected { value = s.equatorialSystem } else { notConnected() }
        case ("PUT", "tracking"):
            if s.trackingNotImplemented { error = AlpacaError.notImplemented; message = "Not implemented" }
            else if !s.connected { notConnected() }
        case ("PUT", "slewtocoordinatesasync"):
            if !s.connected || s.deviceOffline { notConnected() }
            else if !s.canSlewAsync { error = AlpacaError.notImplemented; message = "SlewToCoordinatesAsync not implemented" }
            else { s.slewingPolls = 3; s.slewStarted = true }
        case ("GET", "slewing"):
            if s.deviceOffline { notConnected() }
            else if s.failMidSlew && s.slewStarted { error = 0x500; message = "Motor stalled" }
            else { value = s.slewingPolls > 0; s.slewingPolls = max(0, s.slewingPolls - 1) }
        case ("PUT", "abortslew"):
            if !s.connected { notConnected() } else { s.slewingPolls = 0; s.slewStarted = false }
        default:
            error = AlpacaError.notImplemented; message = "\(method) not implemented"
        }
        let tx = Int(params["ClientTransactionID"] ?? "0") ?? 0
        s.lock.unlock()

        let json: [String: Any] = ["Value": value, "ClientTransactionID": tx, "ServerTransactionID": tx,
                                   "ErrorNumber": error, "ErrorMessage": message]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func read(_ stream: InputStream) -> Data {
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}

final class AlpacaTelescopeTests: XCTestCase {

    override func setUp() { FakeAlpacaServer.state = FakeAlpacaServer.State() }

    private func telescope() throws -> AlpacaTelescope {
        AlpacaTelescope(client: try AlpacaClient(address: "192.168.0.50:32323", clientID: 77,
                                                 session: FakeAlpacaServer.session()))
    }

    private func command(frame: CoordinateFrame) -> TelescopeCommand {
        TelescopeCommand(objectID: "sirius", objectName: "Sirius",
                         target: .equatorial(EquatorialCoord(raDeg: 101.2872, decDeg: -16.7161), frame: frame),
                         confidence: .high, issuedAt: Date())
    }

    private func connectedTransport(system: Int = 2) async throws -> AlpacaTelescopeTransport {
        FakeAlpacaServer.state.equatorialSystem = system
        let t = try telescope()
        let mount = try await t.connect()
        return AlpacaTelescopeTransport(telescope: t, mount: mount)
    }

    func testConnectReadsCapabilitiesAndTagsEveryRequest() async throws {
        let t = try telescope()
        let mount = try await t.connect()
        XCTAssertEqual(mount, AlpacaMountInfo(canSlewAsync: true, equatorialSystem: .j2000))
        XCTAssertEqual(mount.capability(firmware: "x")?.supportedFrames, [.j2000])
        let requests = FakeAlpacaServer.state.requests
        XCTAssertEqual(requests.map(\.method), ["connected", "canslewasync", "equatorialsystem"])
        XCTAssertTrue(requests.allSatisfy { $0.params["ClientID"] == "77" })
        XCTAssertEqual(requests.compactMap { Int($0.params["ClientTransactionID"] ?? "") }, [1, 2, 3],
                       "ClientTransactionID harus naik terus")
        XCTAssertEqual(requests[0].params["Connected"], "True")
    }

    func testGoToSlewsUntilDone() async throws {
        let transport = try await connectedTransport()
        try transport.goTo(command(frame: .j2000))
        let slew = try XCTUnwrap(FakeAlpacaServer.state.requests.first { $0.method == "slewtocoordinatesasync" })
        XCTAssertEqual(Double(slew.params["RightAscension"]!)!, 101.2872 / 15, accuracy: 1e-6, "RA dalam jam")
        XCTAssertEqual(Double(slew.params["Declination"]!)!, -16.7161, accuracy: 1e-6)
        XCTAssertTrue(FakeAlpacaServer.state.requests.contains { $0.method == "tracking" },
                      "tracking dinyalakan sebelum slew")
        var states: [TelescopeReadiness] = []
        for _ in 0..<5 { states.append(try transport.readState()) }
        XCTAssertEqual(states, [.slewing, .slewing, .slewing, .ready, .ready])
    }

    func testAbortMidSlew() async throws {
        let transport = try await connectedTransport()
        try transport.goTo(command(frame: .j2000))
        XCTAssertEqual(try transport.readState(), .slewing)
        try transport.abort()
        XCTAssertEqual(try transport.readState(), .ready)
        XCTAssertTrue(FakeAlpacaServer.state.requests.contains { $0.method == "abortslew" && $0.verb == "PUT" })
    }

    func testDeviceErrorMidSlewSurfaces() async throws {
        let transport = try await connectedTransport()
        try transport.goTo(command(frame: .j2000))
        FakeAlpacaServer.state.failMidSlew = true
        XCTAssertThrowsError(try transport.readState()) { error in
            XCTAssertEqual(error as? AlpacaError, .device(number: 0x500, message: "Motor stalled"))
        }
    }

    func testDisconnectedDevice() async throws {
        let transport = try await connectedTransport()
        FakeAlpacaServer.state.deviceOffline = true
        XCTAssertEqual(try transport.readState(), .disconnected)
        XCTAssertThrowsError(try transport.goTo(command(frame: .j2000))) { error in
            guard case .device(let n, _) = error as? AlpacaError else { return XCTFail("\(error)") }
            XCTAssertEqual(n, AlpacaError.notConnected)
        }
    }

    /// Dudukan tanpa slew async: GoTo dimatikan (kemampuan `nil`), bukan dicoba.
    func testMountWithoutAsyncSlewDisablesGoTo() async throws {
        FakeAlpacaServer.state.canSlewAsync = false
        let mount = try await telescope().connect()
        XCTAssertNil(mount.capability(firmware: "x"))
    }

    /// Kerangka yang tidak didukung (mis. B1950) juga mematikan GoTo.
    func testUnsupportedEquatorialSystemDisablesGoTo() async throws {
        FakeAlpacaServer.state.equatorialSystem = 4
        let mount = try await telescope().connect()
        XCTAssertNil(mount.capability(firmware: "x"))
    }

    /// Koordinat dikirim dalam kerangka yang dinyatakan dudukan; kerangka lain
    /// ditolak sebelum menyentuh jaringan.
    func testFrameMismatchIsRefused() async throws {
        let transport = try await connectedTransport(system: 2)
        let before = FakeAlpacaServer.state.requests.count
        XCTAssertThrowsError(try transport.goTo(command(frame: .ofDate)))
        XCTAssertEqual(FakeAlpacaServer.state.requests.count, before)
    }

    func testTopocentricMountMapsToOfDate() async throws {
        let transport = try await connectedTransport(system: 1)
        XCTAssertEqual(transport.mount.capability(firmware: "x")?.supportedFrames, [.ofDate])
        XCTAssertNoThrow(try transport.goTo(command(frame: .ofDate)))
    }

    func testTrackingNotImplementedStillSlews() async throws {
        FakeAlpacaServer.state.trackingNotImplemented = true
        let transport = try await connectedTransport()
        XCTAssertNoThrow(try transport.goTo(command(frame: .j2000)))
        XCTAssertTrue(FakeAlpacaServer.state.slewStarted)
    }

    func testBadAddressIsRejected() {
        XCTAssertThrowsError(try AlpacaClient(address: "")) { XCTAssertEqual($0 as? AlpacaError, .badAddress) }
    }

    /// Pelaksana yang bisa ditukar: tanpa teleskop, tidak ada GoTo.
    func testSwitchableExecutorWithoutTelescope() {
        let s = SwitchableTelescopeExecutor()
        XCTAssertEqual(s.readiness(), .disconnected)
        XCTAssertNil(s.goTo(objectID: "sirius", now: Date()))
        XCTAssertEqual(s.stop(now: Date()).outcome, .failed)
    }
}
