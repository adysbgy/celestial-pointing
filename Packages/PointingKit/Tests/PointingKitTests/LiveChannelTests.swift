import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Aturan kanal langsung (ADR-006), diuji lewat sesi palsu yang meneruskan
/// pesan ke server iPhone sungguhan — jadi yang diuji adalah perjalanan
/// pesan utuh, bukan masing-masing sisi sendirian.
final class LiveChannelTests: XCTestCase {

    /// Sesi palsu: bila `isReachable`, `sendMessage` langsung diteruskan ke
    /// server (setelah `latency`); `transferUserInfo` hanya dicatat.
    final class FakeSession: LiveSession {
        var isReachable = true
        var failSend = false
        var latency: TimeInterval = 0
        var server: LiveChannelServer?
        var clock: Clock?
        private(set) var sent: [[String: Any]] = []
        private(set) var queued: [[String: Any]] = []

        func sendMessage(_ message: [String: Any],
                         replyHandler: @escaping ([String: Any]) -> Void,
                         errorHandler: @escaping (Error) -> Void) {
            sent.append(message)
            if failSend { errorHandler(NSError(domain: "fake", code: 1)); return }
            clock?.advance(latency)
            replyHandler(server!.handle(message))
        }

        func transferUserInfo(_ userInfo: [String: Any]) { queued.append(userInfo) }
    }

    final class Clock {
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        func advance(_ s: TimeInterval) { now = now.addingTimeInterval(s) }
    }

    final class FakeExecutor: TelescopeExecutor {
        var state: TelescopeReadiness = .ready
        var outcome: TelescopeOutcome = .issued
        var known: Set<String> = ["sirius"]
        private(set) var goTos: [String] = []
        private(set) var stops = 0

        func readiness() -> TelescopeReadiness { state }

        func goTo(objectID: String, now: Date) -> TelescopeAttempt? {
            guard known.contains(objectID) else { return nil }
            goTos.append(objectID)
            return TelescopeAttempt(objectID: objectID, target: .horizontal(HorizontalCoord(altitudeDeg: 40, azimuthDeg: 0)),
                                    confidence: .high, firmwareVersion: "fake", commandPath: "fake",
                                    outcome: outcome, timestamp: now)
        }

        func stop(now: Date) -> TelescopeAttempt {
            stops += 1
            return TelescopeAttempt(objectID: "—", target: .horizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0)),
                                    confidence: .low, firmwareVersion: "fake", commandPath: "fake",
                                    outcome: .aborted, timestamp: now)
        }
    }

    private var clock: Clock!
    private var session: FakeSession!
    private var executor: FakeExecutor!
    private var server: LiveChannelServer!
    private var client: LiveChannelClient!

    override func setUp() {
        clock = Clock()
        executor = FakeExecutor()
        server = LiveChannelServer(executor: executor, now: { [unowned self] in clock.now })
        session = FakeSession()
        session.server = server
        session.clock = clock
        client = LiveChannelClient(session: session, now: { [unowned self] in clock.now })
    }

    private func result(_ call: (@escaping (LiveSendResult) -> Void) -> Void) -> LiveSendResult {
        var out: LiveSendResult?
        call { out = $0 }
        return out!
    }

    private func confirmSirius() -> LiveSendResult {
        result { client.confirm(objectID: "sirius", name: "Sirius", completion: $0) }
    }

    // MARK: Jalur bahagia

    func testConfirmThenGoToExecutesOnce() {
        guard case .replied(let c) = confirmSirius(), c.accepted else { return XCTFail() }
        guard case .replied(let g) = result({ client.goTo(objectID: "sirius", name: "Sirius", completion: $0) })
        else { return XCTFail() }
        XCTAssertTrue(g.accepted)
        XCTAssertEqual(executor.goTos, ["sirius"])
    }

    // MARK: Tidak pernah diantre

    func testGoToAndStopFailVisiblyWhenUnreachableAndAreNeverQueued() {
        _ = confirmSirius()
        session.isReachable = false
        XCTAssertEqual(result { client.goTo(objectID: "sirius", name: "Sirius", completion: $0) },
                       .failed(.unreachable))
        XCTAssertEqual(result { client.stop(completion: $0) }, .failed(.unreachable))
        XCTAssertEqual(result { client.requestTelescopeStatus(completion: $0) }, .failed(.unreachable))
        XCTAssertTrue(session.queued.isEmpty, "perintah fisik tidak boleh masuk antrean")
        XCTAssertTrue(executor.goTos.isEmpty)
    }

    func testSendErrorIsAFailureNotAQueue() {
        _ = confirmSirius()
        session.failSend = true
        XCTAssertEqual(result { client.goTo(objectID: "sirius", name: "Sirius", completion: $0) },
                       .failed(.transportFailed))
        XCTAssertTrue(session.queued.isEmpty)
    }

    // MARK: Konfirmasi tanpa jangkauan = riwayat saja

    func testUnreachableConfirmIsRecordedOnlyAndNeverUnlocksGoTo() {
        session.isReachable = false
        XCTAssertEqual(confirmSirius(), .recordedOnly)
        XCTAssertEqual(session.queued.count, 1)
        // Catatan antrean akhirnya tiba di iPhone…
        server.record(session.queued[0])
        XCTAssertEqual(server.history.last?.kind, .confirmRecord)
        XCTAssertNil(server.confirmedObjectID, "catatan tidak boleh membuka GoTo")
        // …lalu iPhone terjangkau lagi: GoTo tetap ditolak sampai konfirmasi
        // langsung.
        session.isReachable = true
        guard case .replied(let g) = result({ client.goTo(objectID: "sirius", name: "Sirius", completion: $0) })
        else { return XCTFail() }
        XCTAssertEqual(g.rejection, .notConfirmed)
        XCTAssertTrue(executor.goTos.isEmpty)
    }

    func testGoToForADifferentObjectThanConfirmedIsRejected() {
        _ = confirmSirius()
        guard case .replied(let g) = result({ client.goTo(objectID: "vega", name: "Vega", completion: $0) })
        else { return XCTFail() }
        XCTAssertEqual(g.rejection, .notConfirmed)
    }

    // MARK: Basi, diputar ulang, id

    func testGoToOlderThanThreeSecondsIsRejected() {
        _ = confirmSirius()
        session.latency = 3.5
        guard case .replied(let g) = result({ client.goTo(objectID: "sirius", name: "Sirius", completion: $0) })
        else { return XCTFail() }
        XCTAssertEqual(g.rejection, .stale)
        XCTAssertTrue(executor.goTos.isEmpty)
    }

    func testGoToAtTheLimitIsAccepted() {
        _ = confirmSirius()
        session.latency = 2.9
        guard case .replied(let g) = result({ client.goTo(objectID: "sirius", name: "Sirius", completion: $0) })
        else { return XCTFail() }
        XCTAssertTrue(g.accepted)
    }

    func testReplayedMessageIsRejected() {
        _ = confirmSirius()
        let goTo = LiveMessage(id: 2, sentAt: clock.now, kind: .goTo, objectID: "sirius")
        XCTAssertTrue(server.handle(message: goTo).accepted)
        XCTAssertEqual(server.handle(message: goTo).rejection, .replayed)
        XCTAssertEqual(executor.goTos.count, 1, "pesan yang sama tidak boleh menggerakkan dua kali")
    }

    func testIDsAreMonotonicAndResumeFromStoredValue() {
        var stored: UInt64 = 0
        client.onSequenceAdvanced = { stored = $0 }
        _ = confirmSirius()
        _ = result { client.requestTelescopeStatus(completion: $0) }
        XCTAssertEqual(stored, 2)
        let resumed = LiveChannelClient(session: session, sequence: LiveIDSequence(last: stored),
                                        now: { [unowned self] in clock.now })
        _ = result { resumed.requestTelescopeStatus(completion: $0) }
        XCTAssertEqual(server.lastSeenID, 3)
    }

    // MARK: Stop

    func testStopAlwaysExecutesEvenOutOfOrder() {
        _ = confirmSirius()
        _ = result { client.requestTelescopeStatus(completion: $0) }   // id 2
        let lateStop = LiveMessage(id: 1, sentAt: clock.now.addingTimeInterval(-60), kind: .stop)
        XCTAssertTrue(server.handle(message: lateStop).accepted)
        XCTAssertEqual(executor.stops, 1)
    }

    // MARK: Teleskop

    func testGoToRefusedWhenTelescopeNotReady() {
        _ = confirmSirius()
        executor.state = .disconnected
        guard case .replied(let g) = result({ client.goTo(objectID: "sirius", name: "Sirius", completion: $0) })
        else { return XCTFail() }
        XCTAssertEqual(g.rejection, .telescopeUnavailable)
        XCTAssertEqual(g.telescope, .disconnected)
    }

    func testUnsafeAndFailedOutcomesAreReportedNotHidden() {
        _ = confirmSirius()
        executor.outcome = .refused
        guard case .replied(let r) = result({ client.goTo(objectID: "sirius", name: "Sirius", completion: $0) })
        else { return XCTFail() }
        XCTAssertEqual(r.rejection, .unsafe)
        executor.outcome = .failed
        guard case .replied(let f) = result({ client.goTo(objectID: "sirius", name: "Sirius", completion: $0) })
        else { return XCTFail() }
        XCTAssertEqual(f.rejection, .transportFailed)
    }

    func testBadPlistIsRejected() {
        let reply = LiveReply(plist: server.handle(["nope": 1]))
        XCTAssertEqual(reply?.rejection, .badMessage)
    }

    func testMessageAndReplyRoundTrip() {
        let m = LiveMessage(id: 7, sentAt: Date(timeIntervalSince1970: 1_700_000_000.123),
                            kind: .goTo, objectID: "moon", objectName: "Bulan")
        XCTAssertEqual(LiveMessage(plist: m.plist), m)
        let r = LiveReply(id: 7, accepted: false, rejection: .stale, detail: "4.0 s", telescope: .ready)
        XCTAssertEqual(LiveReply(plist: r.plist), r)
    }

    // MARK: Pelaksana nyata di balik TelescopeBridge (transport tiruan)

    func testBridgeExecutorAppliesSlewSafetyAndUsesCatalogCoordinates() {
        let resolver = EngineFactory.makeResolver()
        let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let transport = MockTelescopeTransport()
        let bridge = TelescopeBridge(resolver: resolver,
                                     capability: TelescopeCapability(axes: .equatorial, supportedFrames: [.j2000],
                                                                     firmwareVersion: "mock", canAbort: true))
        let session = TelescopeSession(bridge: bridge, transport: transport, commandPath: "mock")
        let executor = BridgeTelescopeExecutor(resolver: resolver, session: session,
                                               transport: transport, observer: { observer })

        // Jam saat Sirius tertinggi di Jakarta pada hari itu (Nov: dini hari,
        // jadi malam) — dicari, bukan ditebak.
        let night = stride(from: 0.0, to: 86_400, by: 900)
            .map { Date(timeIntervalSince1970: 1_700_000_000 + $0) }
            .max { resolver.horizontal(ofObjectID: "sirius", observer: observer, date: $0)!.altitudeDeg
                 < resolver.horizontal(ofObjectID: "sirius", observer: observer, date: $1)!.altitudeDeg }!
        let sirius = resolver.horizontal(ofObjectID: "sirius", observer: observer, date: night)!
        XCTAssertGreaterThan(sirius.altitudeDeg, 10, "prasyarat: Sirius di atas batas")
        let attempt = executor.goTo(objectID: "sirius", now: night)
        XCTAssertEqual(attempt?.outcome, .issued, attempt?.errorDescription ?? "")
        XCTAssertEqual(transport.commands.first?.objectID, "sirius")
        if case .equatorial(let eq, let frame) = transport.commands.first?.target {
            XCTAssertEqual(frame, .j2000)
            XCTAssertEqual(eq.raDeg, 101.287, accuracy: 0.05, "koordinat katalog, bukan arah pergelangan")
        } else {
            XCTFail("dudukan ekuatorial harus menerima RA/Dec")
        }

        XCTAssertEqual(executor.stop(now: night).outcome, .aborted)
        XCTAssertEqual(transport.abortCount, 1)
        XCTAssertNil(executor.goTo(objectID: "bukan-objek", now: night))
    }
}
