import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PointingKit
@testable import CelestialEngine

/// Pendamping Stellarium (ADR-016).
final class StellariumMirrorTests: XCTestCase {

    /// Konvensi diverifikasi terhadap Stellarium 26.3: az diukur dari Selatan.
    func testViewAnglesConvertNorthBasedAzimuthToStellarium() {
        func az(_ deg: Double) -> Double {
            StellariumMirror.viewAngles(HorizontalCoord(altitudeDeg: 30, azimuthDeg: deg)).azRad * 180 / .pi
        }
        XCTAssertEqual(az(0), 180, accuracy: 1e-9)   // Utara
        XCTAssertEqual(az(90), 90, accuracy: 1e-9)   // Timur tetap Timur
        XCTAssertEqual(az(180), 0, accuracy: 1e-9)   // Selatan
        XCTAssertEqual(az(270), 270, accuracy: 1e-9) // Barat
        XCTAssertEqual(StellariumMirror.viewAngles(HorizontalCoord(altitudeDeg: 30, azimuthDeg: 0)).altRad,
                       30 * .pi / 180, accuracy: 1e-12)
    }

    /// Bukti dari Stellarium sungguhan: Saturnus az 269.36° (dari Utara),
    /// alt −22.77° terbaca sebagai vektor (0.0104, −0.922, −0.387).
    func testMatchesRecordedStellariumVector() {
        let a = StellariumMirror.viewAngles(HorizontalCoord(altitudeDeg: -22.7685, azimuthDeg: 269.3565))
        XCTAssertEqual(cos(a.azRad) * cos(a.altRad), 0.0104, accuracy: 0.0005)
        XCTAssertEqual(sin(a.azRad) * cos(a.altRad), -0.922, accuracy: 0.001)
        XCTAssertEqual(sin(a.altRad), -0.387, accuracy: 0.001)
    }

    func testObjectNames() {
        XCTAssertEqual(StellariumMirror.objectName(forID: "m42"), "M42")
        XCTAssertEqual(StellariumMirror.objectName(forID: "m101"), "M101")
        XCTAssertEqual(StellariumMirror.objectName(forID: "saturn"), "Saturn")
        XCTAssertEqual(StellariumMirror.objectName(forID: "moon"), "Moon")
        XCTAssertEqual(StellariumMirror.objectName(forID: "betelgeuse"), "Betelgeuse")
    }

    func testBaseURL() {
        XCTAssertEqual(StellariumMirror.baseURL(from: "192.168.1.20")?.absoluteString, "http://192.168.1.20:8090/api")
        XCTAssertEqual(StellariumMirror.baseURL(from: " mac.local:9000 ")?.absoluteString, "http://mac.local:9000/api")
        XCTAssertNil(StellariumMirror.baseURL(from: ""))
        XCTAssertNil(StellariumMirror.baseURL(from: "http://"))
    }

    func testRequestsAreFormPosts() throws {
        let base = try XCTUnwrap(StellariumMirror.baseURL(from: "127.0.0.1"))
        let view = StellariumMirror.viewRequest(base: base, pointing: HorizontalCoord(altitudeDeg: 90, azimuthDeg: 180))
        XCTAssertEqual(view.httpMethod, "POST")
        XCTAssertEqual(view.url?.path, "/api/main/view")
        XCTAssertEqual(String(data: try XCTUnwrap(view.httpBody), encoding: .utf8), "alt=1.570796&az=0.000000")
        let focus = StellariumMirror.focusRequest(base: base, objectID: "m45")
        XCTAssertEqual(String(data: try XCTUnwrap(focus.httpBody), encoding: .utf8), "target=M45")
        let clear = StellariumMirror.focusRequest(base: base, objectID: nil)
        XCTAssertEqual(String(data: try XCTUnwrap(clear.httpBody), encoding: .utf8), "target=")
        let loc = StellariumMirror.locationRequest(base: base, observer: Observer(latitudeDeg: -6.2, longitudeDeg: 106.8),
                                                   name: "Point & Know")
        XCTAssertEqual(String(data: try XCTUnwrap(loc.httpBody), encoding: .utf8),
                       "latitude=-6.20000&longitude=106.80000&name=Point%20%26%20Know")
    }

    func testSampleRoundTripAndRequest() throws {
        let s = MirrorSample(pointing: HorizontalCoord(altitudeDeg: 41, azimuthDeg: 338),
                             sentAt: Date(timeIntervalSince1970: 1000), lockedObjectID: "vega")
        XCTAssertEqual(MirrorSample(plist: s.plist), s)
        XCTAssertNil(MirrorSample(plist: ["mirror.v1": ["alt": Double.nan, "az": 1.0, "t": 0.0]]))
        XCTAssertEqual(MirrorSample.isRequest(MirrorSample.request(true)), true)
        XCTAssertNil(MirrorSample.isRequest(s.plist))
    }

    func testThrottle() {
        var throttle = MirrorThrottle(minInterval: 0.25, minMoveDeg: 0.3, keepAlive: 2)
        let t0 = Date(timeIntervalSince1970: 0)
        func s(_ dt: Double, _ az: Double, _ obj: String? = nil) -> MirrorSample {
            MirrorSample(pointing: HorizontalCoord(altitudeDeg: 30, azimuthDeg: az),
                         sentAt: t0.addingTimeInterval(dt), lockedObjectID: obj)
        }
        XCTAssertTrue(throttle.shouldSend(s(0, 100)))
        XCTAssertFalse(throttle.shouldSend(s(0.1, 110)), "terlalu cepat")
        XCTAssertFalse(throttle.shouldSend(s(0.5, 100.1)), "tidak bergeser berarti")
        XCTAssertTrue(throttle.shouldSend(s(0.6, 102)))
        XCTAssertTrue(throttle.shouldSend(s(0.61, 102, "vega")), "objek terkunci berganti: langsung")
        XCTAssertFalse(throttle.shouldSend(s(1.5, 102, "vega")), "diam, belum waktunya")
        XCTAssertTrue(throttle.shouldSend(s(2.7, 102, "vega")), "diam terlalu lama: kirim ulang (keepAlive)")
    }

    /// Integrasi dengan Stellarium sungguhan bila sedang berjalan di mesin ini
    /// (port 8090). Dilewati di CI.
    func testLiveStellariumIfRunning() throws {
        let base = try XCTUnwrap(StellariumMirror.baseURL(from: "127.0.0.1"))
        let status = sync(StellariumMirror.statusRequest(base: base))
        try XCTSkipIf(status == nil, "Stellarium tidak berjalan di mesin ini")
        _ = sync(StellariumMirror.focusRequest(base: base, objectID: nil))
        let target = HorizontalCoord(altitudeDeg: 35, azimuthDeg: 120)
        XCTAssertNotNil(sync(StellariumMirror.viewRequest(base: base, pointing: target)))
        Thread.sleep(forTimeInterval: 1.5)
        let viewData = try XCTUnwrap(sync(URLRequest(url: base.appendingPathComponent("main/view"))))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: viewData) as? [String: Any])
        let vec = try XCTUnwrap((json["altAz"] as? String).flatMap {
            try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [Double]
        })
        // x = Selatan, y = Timur, z = zenit.
        let back = HorizontalCoord(altitudeDeg: asin(vec[2]) * 180 / .pi,
                                   azimuthDeg: SkyMath.normalizeDeg(atan2(vec[1], -vec[0]) * 180 / .pi))
        XCTAssertLessThan(SkyMath.angularSeparationHorizontalDeg(back, target), 0.5)
    }

    private func sync(_ request: URLRequest) -> Data? {
        let done = DispatchSemaphore(value: 0)
        var result: Data?
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if (response as? HTTPURLResponse)?.statusCode == 200 { result = data ?? Data() }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 5)
        return result
    }
}
