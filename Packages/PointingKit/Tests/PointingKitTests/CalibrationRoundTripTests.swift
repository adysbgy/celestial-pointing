import XCTest
import CelestialEngine
@testable import PointingKit

/// Kalibrasi harus diterapkan TEPAT SEKALI.
///
/// Regresi ini mengunci bug yang pernah lolos ke suite: offset yaw kalibrasi
/// dipakai dua kali — sekali sebagai `rollAboutViewDeg` saat membangun
/// `DeviceAttitude`, sekali lagi sebagai koreksi azimut di `PointingCalibration`.
/// Akibatnya offset yang benar menghasilkan galat sisa ≈ 2×offset (bukan ≈ 0),
/// dan engine gagal mengunci objek yang ditunjuk tepat. Karena suite lama tidak
/// pernah menjalankan siklus kalibrasi penuh, bug ini tidak terdeteksi.
final class CalibrationRoundTripTests: XCTestCase {

    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private let sirius = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                         raDeg: 101.28715533, decDeg: -16.71611586,
                                         magnitude: -1.46)

    private func resolver() -> PointingResolver {
        PointingResolver(catalogue: [sirius], policy: .permissive)
    }

    private func at(_ s: Double) -> Date { date.addingTimeInterval(s) }

    /// Quaternion yang membuat sumbu pandang menunjuk ke `t`.
    private func quat(viewAt t: HorizontalCoord) -> Quaternion {
        // Sumbu bawaan controller (lengan bawah), konvensi CoreMotion — ADR-002.
        DeviceAttitude.synthetic(aim: PointingControllerConfig().aim, pointingAt: t).quaternion
    }

    /// Tahan satu orientasi cukup lama agar mesin keadaan keluar dari `.idle`.
    private func hold(_ c: PointingController, _ q: Quaternion) {
        for step in 0..<12 { c.feed(quaternion: q, timestamp: at(Double(step) * 0.1)) }
    }

    /// Offset yaw yang benar harus memulihkan arah tunjuk dan mengunci target.
    func testCalibrationOffsetAppliedExactlyOnce() {
        let r = resolver()
        let truth = r.horizontal(of: sirius, observer: observer, date: date)!

        // Sensor mentah menunjuk dengan azimut yang salah sebesar Δ — meniru yaw
        // yang tidak diketahui CoreMotion.
        let delta = 37.0
        let wrong = HorizontalCoord(altitudeDeg: truth.altitudeDeg,
                                    azimuthDeg: SkyMath.normalizeDeg(truth.azimuthDeg - delta))
        let q = quat(viewAt: wrong)

        let raw = PointingController(resolver: r, observer: observer,
                                     config: PointingControllerConfig(coneDeg: 5))
        hold(raw, q)
        let rawPointing = raw.snapshot.rawPointing!

        // Offset yang seharusnya benar = truth − terukur.
        let yaw = SkyMath.normalizeDeg(truth.azimuthDeg - rawPointing.azimuthDeg)
        XCTAssertEqual(yaw, delta, accuracy: 1e-6,
                       "Offset yang diharapkan harus sama dengan pergeseran yang disimulasikan.")

        let cal = PointingCalibration(yawOffsetDeg: yaw, residualSpreadDeg: 1, sampleCount: 3)
        let calibrated = PointingController(resolver: r, observer: observer,
                                            config: PointingControllerConfig(coneDeg: 5),
                                            calibration: cal)
        hold(calibrated, q)

        let cp = calibrated.snapshot.calibratedPointing!
        let err = SkyMath.angularSeparationHorizontalDeg(cp, truth)

        // Inti regresi: galat sisa harus praktis nol. Bila offset diterapkan dua
        // kali, galat ≈ |2·yaw| ≈ 74°, atau ≈ yaw bila hanya sebagian dobel.
        XCTAssertLessThan(err, 0.01,
                          "Kalibrasi diterapkan lebih dari sekali (galat sisa \(err)°).")

        // Kalibrasi hanya boleh menyentuh azimut, bukan altitude.
        XCTAssertEqual(cp.altitudeDeg, rawPointing.altitudeDeg, accuracy: 1e-9,
                       "Kalibrasi yaw tidak boleh mengubah altitude.")

        // Dan hasil akhirnya: engine harus mengunci target, bukan tersesat.
        XCTAssertEqual(calibrated.snapshot.state, .lock)
        XCTAssertEqual(calibrated.snapshot.bestObject?.id, "sirius")
    }

    /// Tanpa kalibrasi, arah tunjuk mentah tetap mentah: offset tidak boleh
    /// diterapkan diam-diam saat `yawOffsetDeg == 0`.
    func testZeroCalibrationLeavesPointingUntouched() {
        let r = resolver()
        let truth = r.horizontal(of: sirius, observer: observer, date: date)!
        let q = quat(viewAt: truth)

        let c = PointingController(resolver: r, observer: observer,
                                   config: PointingControllerConfig(coneDeg: 5))
        hold(c, q)

        let raw = c.snapshot.rawPointing!
        let cal = c.snapshot.calibratedPointing!
        XCTAssertEqual(cal.azimuthDeg, raw.azimuthDeg, accuracy: 1e-9)
        XCTAssertEqual(cal.altitudeDeg, raw.altitudeDeg, accuracy: 1e-9)
    }
}
