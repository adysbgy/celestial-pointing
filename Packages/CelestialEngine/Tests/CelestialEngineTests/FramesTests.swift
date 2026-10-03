import XCTest
@testable import CelestialEngine

/// Kerangka lokal (ENU), pemetaan attitude perangkat -> arah langit, dan roll.
///
/// Nilai harapan di sini dihitung tangan, bukan disalin dari keluaran kode.
final class FramesTests: XCTestCase {

    private let eps = 1e-9

    // MARK: - Konvensi ENU / azimuth

    func testCardinalDirectionsInENU() {
        let north = LocalFrame.enuFromHorizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0))
        XCTAssertEqual(north.x, 0, accuracy: eps)
        XCTAssertEqual(north.y, 1, accuracy: eps)
        XCTAssertEqual(north.z, 0, accuracy: eps)

        let east = LocalFrame.enuFromHorizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 90))
        XCTAssertEqual(east.x, 1, accuracy: eps)
        XCTAssertEqual(east.y, 0, accuracy: eps)

        let south = LocalFrame.enuFromHorizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 180))
        XCTAssertEqual(south.y, -1, accuracy: eps)

        let west = LocalFrame.enuFromHorizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 270))
        XCTAssertEqual(west.x, -1, accuracy: eps)
    }

    func testZenithIsUp() {
        let up = LocalFrame.enuFromHorizontal(HorizontalCoord(altitudeDeg: 90, azimuthDeg: 123))
        XCTAssertEqual(up.x, 0, accuracy: eps)
        XCTAssertEqual(up.y, 0, accuracy: eps)
        XCTAssertEqual(up.z, 1, accuracy: eps)
    }

    func testHorizontalRoundTrip() {
        for alt in stride(from: -80.0, through: 80.0, by: 20.0) {
            for az in stride(from: 0.0, to: 360.0, by: 45.0) {
                let original = HorizontalCoord(altitudeDeg: alt, azimuthDeg: az)
                let back = LocalFrame.horizontalFromENU(LocalFrame.enuFromHorizontal(original))!
                XCTAssertEqual(back.altitudeDeg, alt, accuracy: 1e-9)
                XCTAssertEqual(back.azimuthDeg, az, accuracy: 1e-9)
            }
        }
    }

    func testZeroVectorHasNoHorizontal() {
        XCTAssertNil(LocalFrame.horizontalFromENU(.zero))
    }

    // MARK: - Attitude identitas

    func testIdentityAttitudeMapsViewToEast() {
        let h = DeviceAttitude.identity.horizontalPointing(aim: .view)!
        XCTAssertEqual(h.altitudeDeg, 0, accuracy: eps)
        XCTAssertEqual(h.azimuthDeg, 90, accuracy: eps)
    }

    func testIdentityAttitudeMapsScreenUpToZenith() {
        let h = DeviceAttitude.identity.horizontalPointing(aim: .screenUp)!
        XCTAssertEqual(h.altitudeDeg, 90, accuracy: eps)
    }

    func testIdentityAttitudeMapsScreenRightToNorth() {
        let h = DeviceAttitude.identity.horizontalPointing(aim: .screenRight)!
        XCTAssertEqual(h.altitudeDeg, 0, accuracy: eps)
        XCTAssertEqual(h.azimuthDeg, 0, accuracy: eps)
    }

    func testIdentityDeviceToWorldIsARotation() {
        XCTAssertTrue(try! XCTUnwrap(DeviceAttitude.identity.deviceToWorld).isRotation())
    }

    // MARK: - Roll mengelilingi sumbu pandang

    /// Roll tidak boleh mengubah arah pandang keluar-layar bila sumbu itu
    /// mendatar. Ini fakta penting: kalibrasi yaw tetap diperlukan.
    func testRollDoesNotMoveViewAxis() {
        let rolled = DeviceAttitude(quaternion: .identity, rollAboutViewDeg: 90)
        let h = rolled.horizontalPointing(aim: .view)!
        XCTAssertEqual(h.altitudeDeg, 0, accuracy: 1e-9)
        XCTAssertEqual(h.azimuthDeg, 90, accuracy: 1e-9)
    }

    /// Roll 90° memutar "atas layar" dari zenith ke Selatan.
    func testRollRotatesScreenUpFromZenithToSouth() {
        let rolled = DeviceAttitude(quaternion: .identity, rollAboutViewDeg: 90)
        let h = rolled.horizontalPointing(aim: .screenUp)!
        XCTAssertEqual(h.altitudeDeg, 0, accuracy: 1e-9)
        XCTAssertEqual(h.azimuthDeg, 180, accuracy: 1e-9)
    }

    func testRollLeavesDeviceToWorldARotation() {
        let rolled = DeviceAttitude(quaternion: .identity, rollAboutViewDeg: 37)
        XCTAssertTrue(try! XCTUnwrap(rolled.deviceToWorld).isRotation())
    }

    // MARK: - Attitude umum

    func testArbitraryQuaternionStillYieldsUnitRotation() {
        let q = Quaternion.axisAngle(axis: Vector3(x: 1, y: 2, z: 3), radians: 1.1)!
        let a = DeviceAttitude(quaternion: q)
        XCTAssertTrue(try! XCTUnwrap(a.deviceToWorld).isRotation())
        // Arah pandang selalu vektor satuan.
        XCTAssertEqual(try! XCTUnwrap(a.pointingVector(aim: .view)).magnitude, 1, accuracy: 1e-12)
    }

    /// Attitude yang dibangun agar mengarah ke suatu alt-az harus benar-benar
    /// mengarah ke sana. Menguji pemetaan ENU <-> kerangka perangkat dua arah.
    func testConstructedAttitudePointsWhereIntended() {
        for target in [HorizontalCoord(altitudeDeg: 35, azimuthDeg: 210),
                       HorizontalCoord(altitudeDeg: 70, azimuthDeg: 15),
                       HorizontalCoord(altitudeDeg: 10, azimuthDeg: 300)] {
            let attitude = Self.attitude(viewPointingAt: target)
            let h = attitude.horizontalPointing(aim: .view)!
            XCTAssertEqual(h.altitudeDeg, target.altitudeDeg, accuracy: 1e-7)
            XCTAssertEqual(h.azimuthDeg, target.azimuthDeg, accuracy: 1e-7)
        }
    }

    // MARK: - Rantai penuh: attitude -> resolver

    /// Ujung-ke-ujung: arahkan perangkat ke bintang sungguhan, resolusi harus
    /// mengembalikan bintang itu. Inilah inti "POINT -> OBJECT ID".
    func testAttitudePointingAtSiriusResolvesToSirius() {
        let obs = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let jd = SkyMath.julianDate(from: date)
        let sirius = EquatorialCoord(raDeg: 101.28715533, decDeg: -16.71611586)
        let horizontal = SkyMath.equatorialToHorizontal(
            SkyMath.precessJ2000ToDate(sirius, jd: jd), observer: obs, jd: jd
        )

        let attitude = Self.attitude(viewPointingAt: horizontal)
        let pointing = attitude.horizontalPointing(aim: .view)!

        let resolver = PointingResolver(catalogue: Catalogue.brightStars, policy: .permissive)
        let intent = resolver.resolve(pointing: pointing, observer: obs, date: date, coneDeg: 10)
        XCTAssertEqual(intent.best?.id, "sirius")
    }

    // MARK: - Bantu

    /// Bangun attitude yang sumbu pandangnya mengarah ke `target`.
    ///
    /// Dipakai sebagai "sensor sempurna" untuk menguji rantai konversi.
    static func attitude(viewPointingAt target: HorizontalCoord) -> DeviceAttitude {
        let v = LocalFrame.enuFromHorizontal(target)          // arah pandang di ENU
        // Balik pemetaan roll=0: d = M^T v, M = [[0,0,1],[1,0,0],[0,1,0]].
        let d = Vector3(x: v.y, y: v.z, z: v.x)               // arah di kerangka perangkat
        let from = Vector3.unitZ
        let axis = from.cross(d)
        if axis.magnitude < 1e-12 { return DeviceAttitude(quaternion: .identity) }
        let angle = acos(max(-1.0, min(1.0, from.dot(d))))
        return DeviceAttitude(quaternion: Quaternion.axisAngle(axis: axis, radians: angle)!)
    }
}
