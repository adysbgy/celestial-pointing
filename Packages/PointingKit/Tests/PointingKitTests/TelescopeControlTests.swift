import XCTest
@testable import PointingKit
@testable import CelestialEngine

/// Aturan GoTo/Stop di jam (ADR-009).
final class TelescopeControlTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func model(_ state: TelescopeStatusState, age: TimeInterval = 1, reachable: Bool = true,
                       confirmed: Bool = true) -> TelescopeControlModel {
        var m = TelescopeControlModel(status: TelescopeStatus(state: state, at: t0.addingTimeInterval(-age)),
                                      isReachable: reachable)
        if confirmed { m.confirm(objectID: "saturn") }
        return m
    }

    // MARK: GoTo hanya setelah konfirmasi + siap + terjangkau + segar

    func testGoToRequiresConfirmation() {
        XCTAssertFalse(model(.ready, confirmed: false).canGoTo(now: t0))
        XCTAssertTrue(model(.ready).canGoTo(now: t0))
    }

    func testGoToRequiresReadyTelescope() {
        for s: TelescopeStatusState in [.disabled, .disconnected, .slewing, .error] {
            XCTAssertFalse(model(s).canGoTo(now: t0), "\(s)")
        }
    }

    func testGoToRequiresReachablePhoneAndSaysSo() {
        let m = model(.ready, reachable: false)
        XCTAssertFalse(m.canGoTo(now: t0))
        XCTAssertTrue(m.showsPhoneUnreachable(now: t0))
    }

    // MARK: Basi

    func testStatusOlderThanTenSecondsIsUnknown() {
        XCTAssertEqual(model(.ready, age: 9.9).effectiveState(now: t0), .ready)
        XCTAssertEqual(model(.ready, age: 10.1).effectiveState(now: t0), .unknown)
        XCTAssertFalse(model(.ready, age: 11).canGoTo(now: t0), "laporan basi tidak membuka GoTo")
        XCTAssertEqual(model(.ready, age: -30).effectiveState(now: t0), .unknown, "cap waktu masa depan")
        XCTAssertEqual(TelescopeControlModel().effectiveState(now: t0), .unknown)
    }

    // MARK: Bergerak → Stop saja

    func testSlewingShowsStopOnlyNoGoTo() {
        let m = model(.slewing)
        XCTAssertTrue(m.showsStop(now: t0))
        XCTAssertFalse(m.canGoTo(now: t0))
    }

    func testStopVisibleWhenGoToIssuedAndStateBecomesUnknown() {
        var m = model(.ready)
        XCTAssertTrue(m.beginGoTo(now: t0))
        m.finishGoTo(.replied(LiveReply(id: 1, accepted: true)))
        // Laporan berikutnya tidak datang: 15 dtk kemudian keadaan tidak diketahui.
        XCTAssertTrue(m.showsStop(now: t0.addingTimeInterval(15)))
        XCTAssertFalse(m.canGoTo(now: t0.addingTimeInterval(15)))
    }

    func testNoStopWhenNothingWasIssuedAndTelescopeIdle() {
        XCTAssertFalse(model(.ready).showsStop(now: t0))
        XCTAssertFalse(model(.ready, age: 30).showsStop(now: t0), "tidak diketahui tapi tidak pernah GoTo")
    }

    // MARK: Hasil kiriman

    func testGoToWithoutReplyIsNoReplyAndKeepsStop() {
        var m = model(.ready)
        XCTAssertTrue(m.beginGoTo(now: t0))
        XCTAssertFalse(m.canGoTo(now: t0), "tidak bisa dua kali saat sedang mengirim")
        m.finishGoTo(.failed(.noReply))
        XCTAssertEqual(m.lastAction, .goToFailed(.noReply))
        XCTAssertTrue(m.goToIssued, "tanpa jawaban: mungkin bergerak")
        XCTAssertTrue(m.showsStop(now: t0.addingTimeInterval(20)))
    }

    func testRejectedGoToMeansNotMoving() {
        var m = model(.ready)
        _ = m.beginGoTo(now: t0)
        m.finishGoTo(.replied(LiveReply(id: 1, accepted: false, rejection: .unsafe)))
        XCTAssertEqual(m.lastAction, .goToFailed(.unsafe))
        XCTAssertFalse(m.goToIssued)
        XCTAssertFalse(m.showsStop(now: t0))
    }

    func testBeginGoToRefusedWhenNotAllowedSendsNothing() {
        var m = model(.slewing)
        XCTAssertFalse(m.beginGoTo(now: t0))
        XCTAssertEqual(m.lastAction, .none)
    }

    func testStopResultClearsOrKeepsStop() {
        var m = model(.slewing)
        m.beginStop()
        XCTAssertTrue(m.showsStop(now: t0))
        m.finishStop(.failed(.unreachable))
        XCTAssertEqual(m.lastAction, .stopFailed(.unreachable))
        XCTAssertTrue(m.showsStop(now: t0), "Stop gagal: tombol tetap ada")
        m.beginStop()
        m.finishStop(.replied(LiveReply(id: 2, accepted: true)))
        XCTAssertEqual(m.lastAction, .stopAccepted)
    }

    func testNewConfirmationResetsActions() {
        var m = model(.ready)
        _ = m.beginGoTo(now: t0)
        m.confirm(objectID: "moon")
        XCTAssertEqual(m.lastAction, .none)
        XCTAssertFalse(m.goToIssued)
    }

    /// "Tunjuk lagi" setelah GoTo: tidak ada GoTo baru, tetapi Stop tetap ada.
    func testPointAgainAfterGoToKeepsStop() {
        var m = model(.ready)
        _ = m.beginGoTo(now: t0)
        m.finishGoTo(.replied(LiveReply(id: 1, accepted: true)))
        m.clearConfirmation()
        XCTAssertFalse(m.canGoTo(now: t0))
        XCTAssertTrue(m.showsStop(now: t0.addingTimeInterval(15)))
        m.beginStop()
        m.finishStop(.replied(LiveReply(id: 2, accepted: true)))
        XCTAssertFalse(m.showsStop(now: t0.addingTimeInterval(15)))
    }

    // MARK: Selesai

    /// Tidak pernah GoTo dan Stop berdampingan: selama mungkin bergerak, GoTo
    /// tersembunyi.
    func testGoToHiddenWhileStopShown() {
        var m = model(.ready)
        _ = m.beginGoTo(now: t0)
        m.finishGoTo(.replied(LiveReply(id: 1, accepted: true)), now: t0)
        XCTAssertTrue(m.showsStop(now: t0))
        XCTAssertFalse(m.canGoTo(now: t0), "laporan masih 'siap' tapi GoTo baru saja diterima")
    }

    func testSlewingThenReadyCompletesGoTo() {
        var m = model(.ready)
        _ = m.beginGoTo(now: t0)
        m.finishGoTo(.replied(LiveReply(id: 1, accepted: true)), now: t0)
        m.status = TelescopeStatus(state: .slewing, at: t0.addingTimeInterval(2))
        XCTAssertTrue(m.showsStop(now: t0.addingTimeInterval(2)))
        m.status = TelescopeStatus(state: .ready, at: t0.addingTimeInterval(6))
        XCTAssertEqual(m.lastAction, .goToCompleted)
        XCTAssertFalse(m.showsStop(now: t0.addingTimeInterval(6)))
        XCTAssertTrue(m.canGoTo(now: t0.addingTimeInterval(6)), "boleh GoTo lagi setelah sampai")
    }

    /// Slew pendek yang selesai di antara dua laporan: "siap" terus 20 dtk.
    func testReadyPersistingAfterAcceptCompletesGoTo() {
        var m = model(.ready)
        _ = m.beginGoTo(now: t0)
        m.finishGoTo(.replied(LiveReply(id: 1, accepted: true)), now: t0)
        m.status = TelescopeStatus(state: .ready, at: t0.addingTimeInterval(5))
        XCTAssertTrue(m.showsStop(now: t0.addingTimeInterval(5)))
        m.status = TelescopeStatus(state: .ready, at: t0.addingTimeInterval(21))
        XCTAssertEqual(m.lastAction, .goToCompleted)
    }

    /// Laporan antrean yang lebih tua tidak menimpa jawaban langsung yang lebih baru.
    func testOlderStatusIsIgnored() {
        var m = model(.slewing, age: 0)
        m.status = TelescopeStatus(state: .ready, at: t0.addingTimeInterval(-5))
        XCTAssertEqual(m.status?.state, .slewing)
    }

    func testMockTransportSlewsForItsDurationAndAbortStops() throws {
        var clock = t0
        let mock = MockTelescopeTransport()
        mock.now = { clock }
        try mock.goTo(TelescopeCommand(objectID: "x", objectName: "X",
                                       target: .horizontal(HorizontalCoord(altitudeDeg: 40, azimuthDeg: 0)),
                                       confidence: .high, issuedAt: t0))
        XCTAssertEqual(try mock.readState(), .slewing)
        clock = t0.addingTimeInterval(7.9)
        XCTAssertEqual(try mock.readState(), .slewing)
        clock = t0.addingTimeInterval(8)
        XCTAssertEqual(try mock.readState(), .ready)
        try mock.goTo(TelescopeCommand(objectID: "x", objectName: "X",
                                       target: .horizontal(HorizontalCoord(altitudeDeg: 40, azimuthDeg: 0)),
                                       confidence: .high, issuedAt: clock))
        try mock.abort()
        XCTAssertEqual(try mock.readState(), .ready)
    }

    // MARK: Pesan

    func testStatusRoundTripAndReadinessMapping() {
        let s = TelescopeStatus(state: .slewing, at: t0, detail: "mock")
        XCTAssertEqual(TelescopeStatus(plist: s.plist), s)
        XCTAssertNil(TelescopeStatus(plist: ["x": 1]))
        XCTAssertEqual(TelescopeStatus(readiness: .notReady, at: t0).state, .error)
        XCTAssertEqual(TelescopeStatus(readiness: .ready, at: t0).state, .ready)
    }

    /// GoTo lewat kanal langsung tanpa jawaban → `.noReply`, dan model
    /// menampilkan Stop (gabungan klien + model).
    func testLiveGoToTimeoutFlowsIntoModel() {
        final class Silent: LiveSession {
            var isReachable = true
            func sendMessage(_ m: [String: Any], replyHandler: @escaping ([String: Any]) -> Void,
                             errorHandler: @escaping (Error) -> Void) {}
            func transferUserInfo(_ u: [String: Any]) {}
        }
        var fire: (() -> Void)?
        let client = LiveChannelClient(session: Silent(), now: { self.t0 }, schedule: { _, w in fire = w })
        var m = model(.ready)
        XCTAssertTrue(m.beginGoTo(now: t0))
        client.goTo(objectID: "saturn", name: "Saturn") { m.finishGoTo($0) }
        fire?()
        XCTAssertEqual(m.lastAction, .goToFailed(.noReply))
        XCTAssertTrue(m.showsStop(now: t0))
    }
}
