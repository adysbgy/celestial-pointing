import XCTest
@testable import PointingKit

/// Sambungan & sinkron (ADR-020).
final class WatchSyncTests: XCTestCase {

    func testConnectionStateOrder() {
        XCTAssertEqual(WatchConnectionState(isPaired: false, isAppInstalled: true, isReachable: true, lastContact: nil), .notPaired)
        XCTAssertEqual(WatchConnectionState(isPaired: true, isAppInstalled: false, isReachable: true, lastContact: nil), .appNotInstalled)
        XCTAssertEqual(WatchConnectionState(isPaired: true, isAppInstalled: true, isReachable: true, lastContact: nil), .live)
        let t = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(WatchConnectionState(isPaired: true, isAppInstalled: true, isReachable: false, lastContact: t),
                       .standby(lastContact: t))
        XCTAssertTrue(WatchConnectionState.standby(lastContact: nil).isReady)
        XCTAssertFalse(WatchConnectionState.appNotInstalled.isReady)
    }

    func testStandbyDetailMentionsLastContact() {
        let now = Date(timeIntervalSince1970: 10_000)
        let text = WatchConnectionState.standby(lastContact: now.addingTimeInterval(-300)).detail(now: now)
        XCTAssertTrue(text.hasPrefix("Data terakhir"), text)
        XCTAssertTrue(text.contains("Konfirmasi tetap tersimpan"), text)
    }

    func testSettingsRoundTripAndLastWriterWins() {
        let old = SyncedSettings(darkSky: false, hotCold: true, updatedAt: Date(timeIntervalSince1970: 100))
        let new = SyncedSettings(darkSky: true, hotCold: false, updatedAt: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(SyncedSettings(plist: new.plist), new)
        XCTAssertEqual(old.merged(with: new), new)
        XCTAssertEqual(new.merged(with: old), new, "pesan lama yang terlambat tidak menimpa")
        XCTAssertNil(SyncedSettings(plist: ["x": 1]))
    }
}
