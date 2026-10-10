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

    // MARK: - Pose yang diketahui (dari definisi Apple, bukan dari kode)
    //
    // Konvensi lama memetakan identitas sebagai "+Z keluar layar -> Timur,
    // +Y atas layar -> Zenith". Uji lamanya berbunyi:
    //
    //     testIdentityAttitudeMapsViewToEast():
    //         let h = DeviceAttitude.identity.horizontalPointing(aim: .view)!
    //         XCTAssertEqual(h.altitudeDeg, 0, ...); XCTAssertEqual(h.azimuthDeg, 90, ...)
    //
    // Itu bertentangan dengan CoreMotion: attitude identitas berarti kerangka
    // perangkat = kerangka acuan, yaitu perangkat **terbaring mendatar, layar
    // ke atas** (sumbu-Z acuan vertikal). Layar yang menghadap zenith dibaca
    // sebagai "Timur di cakrawala". Setiap harapan di bawah diturunkan dari
    // definisi Apple (Z ke atas; X = Utara pada kerangka berutara; tangan
    // kanan ⇒ Y = Barat) dan dari pembacaan gravitasi yang didokumentasikan
    // Apple. Lihat Docs/DECISIONS.md ADR-002.

    /// Terbaring, layar ke atas: normal layar menunjuk zenith.
    /// (Dulu: Timur, alt 0° — salah.)
    func testIdentityMapsViewToZenith() {
        let h = DeviceAttitude.identity.horizontalPointing(aim: .view)!
        XCTAssertEqual(h.altitudeDeg, 90, accuracy: eps)
    }

    /// Lengan bawah mendatar menunjuk Utara, layar ke atas, pergelangan kiri
    /// (mahkota ke tangan): +X = sumbu-X acuan = Utara.
    /// (Dulu: +X -> Utara juga, tapi untuk alasan yang salah — lewat
    /// pemetaan yang menaruh Z di Timur.)
    func testIdentityMapsScreenRightToNorthHorizon() {
        let h = DeviceAttitude(quaternion: .identity, frame: .xTrueNorthZVertical)
            .horizontalPointing(aim: .screenRight)!
        XCTAssertEqual(h.altitudeDeg, 0, accuracy: eps)
        XCTAssertEqual(h.azimuthDeg, 0, accuracy: eps)
    }

    /// +Y pada identitas = sumbu-Y acuan = Barat (Z × X).
    /// (Dulu: +Y -> zenith.)
    func testIdentityMapsScreenUpToWest() {
        let h = DeviceAttitude(quaternion: .identity, frame: .xMagneticNorthZVertical)
            .horizontalPointing(aim: .screenUp)!
        XCTAssertEqual(h.altitudeDeg, 0, accuracy: eps)
        XCTAssertEqual(h.azimuthDeg, 270, accuracy: eps)
    }

    /// Terbaring, diputar 90° mengelilingi Z (berlawanan jarum jam dilihat
    /// dari atas): +X ikut berputar dari Utara ke Barat.
    func testYaw90AboutVerticalTurnsScreenRightWest() {
        let q = Quaternion.axisAngle(axis: .unitZ, radians: .pi / 2)!
        let h = DeviceAttitude(quaternion: q, frame: .xTrueNorthZVertical)
            .horizontalPointing(aim: .screenRight)!
        XCTAssertEqual(h.altitudeDeg, 0, accuracy: 1e-9)
        XCTAssertEqual(h.azimuthDeg, 270, accuracy: 1e-9)
    }

    /// Lengan diangkat 45°: putaran −45° mengelilingi Y acuan (Barat)
    /// mengangkat +X dari Utara ke alt 45°.
    func testArmRaised45PointsForearmAt45Altitude() {
        let q = Quaternion.axisAngle(axis: .unitY, radians: -.pi / 4)!
        let h = DeviceAttitude(quaternion: q, frame: .xTrueNorthZVertical)
            .horizontalPointing(aim: .screenRight)!
        XCTAssertEqual(h.altitudeDeg, 45, accuracy: 1e-9)
        XCTAssertEqual(h.azimuthDeg, 0, accuracy: 1e-9)
    }

    /// Kerangka sembarang: altitude tetap absolut (Z vertikal), hanya azimut
    /// yang bergantung pada X sembarang.
    func testArbitraryFrameKeepsAltitudeAbsolute() {
        let raise = Quaternion.axisAngle(axis: .unitY, radians: -SkyMath.deg2rad(30))!
        for yawDeg in [0.0, 73.0, 190.0] {
            let yaw = Quaternion.axisAngle(axis: .unitZ, radians: SkyMath.deg2rad(yawDeg))!
            let a = DeviceAttitude(quaternion: yaw.multiplied(by: raise), frame: .xArbitraryZVertical)
            XCTAssertEqual(a.horizontalPointing(aim: .screenRight)!.altitudeDeg, 30, accuracy: 1e-9)
        }
    }

    // MARK: - Gravitasi: cek konvensi yang bisa dijalankan di perangkat

    /// Apple: perangkat terbaring layar ke atas membaca gravitasi (0, 0, −1).
    func testPredictedGravityFlatFaceUp() {
        let g = DeviceAttitude.identity.predictedGravity!
        XCTAssertEqual(g.x, 0, accuracy: eps)
        XCTAssertEqual(g.y, 0, accuracy: eps)
        XCTAssertEqual(g.z, -1, accuracy: eps)
    }

    /// Apple: perangkat tegak (atas layar ke langit) membaca gravitasi
    /// (0, −1, 0). Pose itu = putaran +90° mengelilingi X (Y -> Z).
    func testPredictedGravityUpright() {
        let q = Quaternion.axisAngle(axis: .unitX, radians: .pi / 2)!
        let g = DeviceAttitude(quaternion: q).predictedGravity!
        XCTAssertEqual(g.x, 0, accuracy: 1e-12)
        XCTAssertEqual(g.y, -1, accuracy: 1e-12)
        XCTAssertEqual(g.z, 0, accuracy: 1e-12)
        XCTAssertEqual(DeviceAttitude(quaternion: q)
            .gravityMismatchDeg(measured: Vector3(x: 0, y: -1, z: 0))!, 0, accuracy: 1e-6)
    }

    /// Konvensi terbalik (memakai R alih-alih Rᵀ) harus terlihat sebagai
    /// selisih gravitasi yang besar — itulah gunanya cek ini di lapangan.
    func testTransposedConventionShowsGravityMismatch() {
        let q = Quaternion.axisAngle(axis: Vector3(x: 1, y: 1, z: 0), radians: 1.0)!
        let measuredIfTransposed = -(q.rotationMatrix.multiplied(by: .unitZ))
        let mismatch = DeviceAttitude(quaternion: q).gravityMismatchDeg(measured: measuredIfTransposed)!
        XCTAssertGreaterThan(mismatch, 30)
    }

    // MARK: - Pemakaian (pergelangan / mahkota)

    func testForearmAxisFromWearConfiguration() {
        XCTAssertEqual(WearConfiguration(wrist: .left, crown: .right).forearmAim, .screenRight)
        XCTAssertEqual(WearConfiguration(wrist: .right, crown: .left).forearmAim, .screenRight)
        XCTAssertEqual(WearConfiguration(wrist: .left, crown: .left).forearmAim, .screenLeft)
        XCTAssertEqual(WearConfiguration(wrist: .right, crown: .right).forearmAim, .screenLeft)
        XCTAssertEqual(WearConfiguration.default.forearmAim, DeviceAimAxis.defaultForearm)
    }

    func testAllAimAxesAreUnitAndDistinct() {
        let vectors = DeviceAimAxis.allCases.map(\.vector)
        for v in vectors { XCTAssertEqual(v.magnitude, 1, accuracy: eps) }
        XCTAssertEqual(Set(DeviceAimAxis.allCases.map(\.rawValue)).count, vectors.count)
    }

    func testReferenceToENUIsARotation() {
        XCTAssertTrue(AttitudeReferenceFrame.referenceToENU.isRotation())
        XCTAssertTrue(try! XCTUnwrap(DeviceAttitude.identity.deviceToWorld).isRotation())
    }

    func testOnlyNorthFramesHaveAbsoluteHeading() {
        XCTAssertFalse(AttitudeReferenceFrame.xArbitraryZVertical.hasAbsoluteHeading)
        XCTAssertFalse(AttitudeReferenceFrame.xArbitraryCorrectedZVertical.hasAbsoluteHeading)
        XCTAssertTrue(AttitudeReferenceFrame.xMagneticNorthZVertical.hasAbsoluteHeading)
        XCTAssertTrue(AttitudeReferenceFrame.xTrueNorthZVertical.hasAbsoluteHeading)
    }

    // MARK: - Attitude umum

    func testArbitraryQuaternionStillYieldsUnitRotation() {
        let q = Quaternion.axisAngle(axis: Vector3(x: 1, y: 2, z: 3), radians: 1.1)!
        let a = DeviceAttitude(quaternion: q)
        XCTAssertTrue(try! XCTUnwrap(a.deviceToWorld).isRotation())
        XCTAssertEqual(try! XCTUnwrap(a.pointingVector(aim: .view)).magnitude, 1, accuracy: 1e-12)
    }

    /// Attitude sintetis harus benar-benar menunjuk target untuk setiap
    /// sumbu, termasuk zenith dan arah yang berlawanan dengan sumbu itu.
    func testSyntheticAttitudePointsWhereIntendedForEveryAxis() {
        let targets = [HorizontalCoord(altitudeDeg: 35, azimuthDeg: 210),
                       HorizontalCoord(altitudeDeg: 70, azimuthDeg: 15),
                       HorizontalCoord(altitudeDeg: 10, azimuthDeg: 300),
                       HorizontalCoord(altitudeDeg: -90, azimuthDeg: 0)]
        for aim in DeviceAimAxis.allCases {
            for target in targets {
                let a = DeviceAttitude.synthetic(aim: aim, pointingAt: target)
                let v = a.pointingVector(aim: aim)!
                let expected = LocalFrame.enuFromHorizontal(target)
                XCTAssertLessThan(v.angleDegrees(to: expected)!, 1e-6, "\(aim) -> \(target)")
            }
        }
    }

    // MARK: - Rantai penuh: attitude -> resolver

    /// Ujung-ke-ujung: lengan bawah diarahkan ke Sirius, resolusi harus
    /// mengembalikan Sirius. Inti "POINT -> OBJECT ID".
    func testForearmPointingAtSiriusResolvesToSirius() {
        let obs = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let jd = SkyMath.julianDate(from: date)
        let sirius = EquatorialCoord(raDeg: 101.28715533, decDeg: -16.71611586)
        let horizontal = SkyMath.equatorialToHorizontal(
            SkyMath.precessJ2000ToDate(sirius, jd: jd), observer: obs, jd: jd
        )

        let attitude = DeviceAttitude.synthetic(aim: .defaultForearm, pointingAt: horizontal,
                                                frame: .xTrueNorthZVertical)
        let pointing = attitude.horizontalPointing(aim: .defaultForearm)!

        let resolver = PointingResolver(catalogue: Catalogue.brightStars, policy: .permissive)
        let intent = resolver.resolve(pointing: pointing, observer: obs, date: date, coneDeg: 10)
        XCTAssertEqual(intent.best?.id, "sirius")
    }
}
