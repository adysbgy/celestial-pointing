import Foundation
import CelestialEngine

/// Umpan balik yang boleh dipicu ke Taptic Engine.
///
/// Haptic adalah satu-satunya saluran yang tidak butuh mata. Karena itu
/// pemetaannya di sini sengaja dibatasi: hanya **perpindahan keadaan** yang
/// memicu, bukan tiap sampel sensor (Watch akan bergetar terus), dan
/// `lockSucceeded` hanya untuk keyakinan HIGH. Merasa "berhasil" saat engine
/// sebenarnya ragu adalah bentuk false confidence yang dilarang PRD.
public enum HapticEvent: String, Equatable, Sendable {
    /// Engine mengunci objek dengan keyakinan tinggi.
    case lockSucceeded
    /// Ada kandidat tetapi engine tidak cukup yakin — getaran ragu, bukan sukses.
    case uncertain
    /// Sensor hilang; engine menolak menebak.
    case sensorUnavailable
    /// Kembali ke idle (alur dihentikan).
    case returnedToIdle
}

/// Cuplikan keadaan untuk dirender UI. Nilainya murni — tidak ada rujukan ke
/// objek sensor, jadi bisa diuji dan dibandingkan di Linux.
public struct PointingSnapshot: Equatable, Sendable {
    public var state: PointingState
    /// Niat terakhir dari engine (objek + tingkat keyakinan).
    public var intent: CelestialIntent?
    /// Arah tunjuk mentah dari sensor, sebelum kalibrasi.
    public var rawPointing: HorizontalCoord?
    /// Arah tunjuk setelah kalibrasi — yang dipakai engine.
    public var calibratedPointing: HorizontalCoord?
    /// Kecepatan sudut pergelangan terakhir (derajat/detik).
    public var angularRateDegPerSec: Double?
    /// Sumbu badan yang dianggap "arah tunjuk".
    public var aim: DeviceAimAxis
    /// Apakah sensor sedang tersedia.
    public var hasSensor: Bool
    /// Apakah kalibrasi sudah pernah diselesaikan.
    public var isCalibrated: Bool

    public init(state: PointingState,
                intent: CelestialIntent? = nil,
                rawPointing: HorizontalCoord? = nil,
                calibratedPointing: HorizontalCoord? = nil,
                angularRateDegPerSec: Double? = nil,
                aim: DeviceAimAxis = .view,
                hasSensor: Bool = true,
                isCalibrated: Bool = false) {
        self.state = state
        self.intent = intent
        self.rawPointing = rawPointing
        self.calibratedPointing = calibratedPointing
        self.angularRateDegPerSec = angularRateDegPerSec
        self.aim = aim
        self.hasSensor = hasSensor
        self.isCalibrated = isCalibrated
    }

    /// Objek terbaik yang sedang ditampilkan.
    public var bestObject: CelestialObject? { intent?.best }

    /// Teks status singkat untuk UI.
    public var statusText: String {
        switch state {
        case .idle: return "Siap"
        case .pointing: return "Arahkan…"
        case .searching: return "Mencari…"
        case .lock: return "Terkunci"
        case .uncertain: return "Kurang yakin"
        case .unavailable: return "Sensor tidak tersedia"
        }
    }
}

/// Hasil satu langkah: keadaan terbaru + peristiwa haptic yang harus dipicu.
public struct PointingUpdate: Equatable, Sendable {
    public var snapshot: PointingSnapshot
    public var haptics: [HapticEvent]
}

/// Parameter alur yang bisa diubah dari UI/pengaturan.
public struct PointingControllerConfig: Equatable, Sendable {
    /// Sumbu badan yang dianggap arah tunjuk.
    public var aim: DeviceAimAxis
    /// Ambang "pergelangan diam" dan laju resolusi.
    public var policy: PointingPolicy
    /// Setengah sudut kerucut pencarian kandidat (derajat).
    public var coneDeg: Double
    /// Bobot perata orientasi: kecil = halus, besar = gesit.
    public var smootherBlend: Double

    public init(aim: DeviceAimAxis = .view,
                policy: PointingPolicy = PointingPolicy(),
                coneDeg: Double = 20.0,
                smootherBlend: Double = 0.3) {
        self.aim = aim
        self.policy = policy
        self.coneDeg = coneDeg
        self.smootherBlend = smootherBlend
    }
}

/// Otak lapisan app: sensor mentah → arah tunjuk terkalibrasi → keadaan alur.
///
/// Kelas ini adalah satu-satunya tempat yang tahu urutan pemrosesan:
/// 1. perata orientasi (meredam gemetar tangan),
/// 2. attitude → arah tunjuk (`DeviceAttitude`),
/// 3. koreksi kalibrasi (hanya azimut),
/// 4. mesin keadaan (menunggu pergelangan diam, lalu resolusi),
/// 5. perpindahan keadaan → peristiwa haptic.
///
/// Tidak menyentuh CoreMotion, SwiftUI, atau WatchKit. Pembungkus platform
/// hanya perlu memanggil `feed(quaternion:timestamp:)` dan merender `snapshot`.
public final class PointingController {

    // MARK: - Keadaan

    /// Lokasi pengamat. Mengubah ini menggeser seluruh langit.
    public var observer: Observer
    /// Kalibrasi yang sedang dipakai.
    public private(set) var calibration: PointingCalibration
    /// Parameter alur.
    public var config: PointingControllerConfig
    /// Resolver engine (katalog + efemeris).
    public let resolver: PointingResolver

    /// Cuplikan terakhir, untuk dirender ulang tanpa sampel baru.
    public private(set) var snapshot: PointingSnapshot
    /// Resolusi lengkap terakhir, termasuk `sunHorizontal` untuk pengaman slew.
    public private(set) var lastResolution: Resolution?

    private var machine: PointingStateMachine
    private var smoother: PointingSmoother
    private var isSensorAvailable: Bool

    /// Jumlah peristiwa haptic yang dipicu, untuk audit.
    public private(set) var hapticLog: [(event: HapticEvent, at: Date)] = []

    // MARK: - Inisialisasi

    public init(resolver: PointingResolver,
                observer: Observer,
                config: PointingControllerConfig = PointingControllerConfig(),
                calibration: PointingCalibration = .none,
                isSensorAvailable: Bool = true) {
        self.resolver = resolver
        self.observer = observer
        self.config = config
        self.calibration = calibration
        self.isSensorAvailable = isSensorAvailable
        self.machine = PointingStateMachine(policy: config.policy,
                                            isSensorAvailable: isSensorAvailable)
        self.smoother = PointingSmoother(blendFactor: config.smootherBlend)
        self.snapshot = PointingSnapshot(
            state: isSensorAvailable ? .idle : .unavailable,
            aim: config.aim,
            hasSensor: isSensorAvailable,
            isCalibrated: calibration.sampleCount > 0
        )
    }

    // MARK: - Sensor

    /// Beri tahu controller bahwa sensor hilang/tersedia.
    ///
    /// Sensor hilang **tidak** boleh diam-diam menghentikan alur pada keadaan
    /// terakhir: itu akan membuat objek terakhir tetap terlihat seolah masih
    /// terkonfirmasi. Keadaan langsung menjadi `unavailable`.
    @discardableResult
    public func setSensorAvailable(_ available: Bool) -> [HapticEvent] {
        guard available != isSensorAvailable else { return [] }
        isSensorAvailable = available
        machine.isSensorAvailable = available

        var events: [HapticEvent] = []
        if !available {
            machine.stop()
            machine.isSensorAvailable = false
            machine.update(quaternion: .identity,
                           pointing: HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0),
                           timestamp: Date()) { _ in
                CelestialIntent(level: .low, best: nil, candidates: [])
            }
            events.append(.sensorUnavailable)
        } else {
            smoother.reset()
            machine.stop()
        }
        refreshSnapshot()
        record(events, at: Date())
        return events
    }

    // MARK: - Kalibrasi

    /// Pasang kalibrasi baru. Kalibrasi hanya menggeser azimut.
    ///
    /// Perata orientasi direset karena acuan sebelum/sesudah kalibrasi tidak
    /// sebanding — membiarkannya akan membuat arah tunjuk meluncur pelan ke
    /// posisi baru, dan peluncuran itu terbaca sebagai "pergelangan diam".
    public func apply(calibration newValue: PointingCalibration) {
        calibration = newValue
        smoother.reset()
        machine.stop()
        refreshSnapshot()
    }

    // MARK: - Sampel sensor

    /// Masukkan satu sampel `CMDeviceMotion`.
    ///
    /// Pemetaan `CMQuaternion` (x, y, z, w) → `Quaternion` (w, x, y, z) ada di
    /// `DeviceAttitude.init?(cmX:cmY:cmZ:cmW:)`, jadi lapisan app tidak perlu
    /// mengingat urutan komponennya.
    @discardableResult
    public func feed(cmX: Double, cmY: Double, cmZ: Double, cmW: Double,
                     timestamp: Date) -> PointingUpdate {
        guard let attitude = DeviceAttitude(cmX: cmX, cmY: cmY, cmZ: cmZ, cmW: cmW,
                                            rollAboutViewDeg: calibration.yawOffsetDeg)
        else {
            // Quaternion tidak sah: sensor rusak/nol. Jangan menebak arah.
            // Ini juga menandai sensor tidak tersedia, karena satu-satunya
            // sumber data attitude memang tidak bisa dipakai.
            let events = setSensorAvailable(false)
            return PointingUpdate(snapshot: snapshot, haptics: events)
        }
        // Sampel sah = sensor hidup. Kalau sebelumnya sempat mati, pulihkan.
        setSensorAvailable(true)
        return feed(quaternion: attitude.quaternion, timestamp: timestamp)
    }

    /// Masukkan satu sampel orientasi (sudah dalam bentuk quaternion engine).
    ///
    /// - Parameter quaternion: orientasi **mentah** perangkat. Dipakai untuk
    ///   mengukur kecepatan sudut, jadi harus belum teredam.
    @discardableResult
    public func feed(quaternion raw: Quaternion, timestamp: Date) -> PointingUpdate {
        guard isSensorAvailable else {
            refreshSnapshot()
            return PointingUpdate(snapshot: snapshot, haptics: [])
        }

        // 1. Perata: meredam gemetar tanpa menunda gerakan besar.
        let smoothed = smoother.update(raw) ?? raw

        // 2. Arah tunjuk dari attitude teredam.
        let attitude = DeviceAttitude(quaternion: smoothed,
                                      rollAboutViewDeg: calibration.yawOffsetDeg)
        guard let rawPointing = attitude.horizontalPointing(aim: config.aim) else {
            // Attitude tidak terdefinisi (mis. sensor memberi vektor nol).
            refreshSnapshot(state: .unavailable)
            return PointingUpdate(snapshot: snapshot, haptics: [])
        }

        // 3. Koreksi kalibrasi (hanya azimut; altitude tidak disentuh).
        let pointing = calibration.apply(to: rawPointing)

        let previous = machine.state
        let observer = self.observer
        let coneDeg = config.coneDeg
        let resolver = self.resolver

        // 4. Mesin keadaan. Laju sudut diukur dari quaternion **mentah**.
        let state = machine.update(quaternion: raw,
                                   pointing: pointing,
                                   timestamp: timestamp) { direction in
            let resolution = resolver.diagnose(pointing: direction,
                                               observer: observer,
                                               date: timestamp,
                                               coneDeg: coneDeg)
            self.lastResolution = resolution
            return resolution.intent
        }

        snapshot = PointingSnapshot(
            state: state,
            intent: machine.currentIntent,
            rawPointing: rawPointing,
            calibratedPointing: pointing,
            angularRateDegPerSec: machine.angularRateDegPerSec,
            aim: config.aim,
            hasSensor: isSensorAvailable,
            isCalibrated: calibration.sampleCount > 0
        )

        let events = hapticEvents(from: previous, to: state)
        record(events, at: timestamp)
        return PointingUpdate(snapshot: snapshot, haptics: events)
    }

    /// Hentikan alur (mis. layar pergi). Kembali ke idle.
    @discardableResult
    public func stop() -> [HapticEvent] {
        let previous = machine.state
        machine.stop()
        smoother.reset()
        lastResolution = nil
        refreshSnapshot()
        var events: [HapticEvent] = []
        if previous != .idle { events.append(.returnedToIdle) }
        record(events, at: Date())
        return events
    }

    // MARK: - Rencana GoTo

    /// Rencana GoTo teleskop untuk resolusi terakhir.
    ///
    /// Arah target diambil dari **posisi objek yang teridentifikasi**, bukan
    /// dari arah tunjuk pergelangan — aturan keras PRD, dan satu-satunya jalan
    /// agar tidak ada sudut pergelangan yang pernah sampai ke motor.
    ///
    /// - Returns: `nil` bila belum ada resolusi.
    public func slewDecision(date: Date,
                             policy: SlewSafetyPolicy = SlewSafetyPolicy()) -> SlewDecision? {
        guard let resolution = lastResolution else { return nil }
        let object = resolution.intent.best
        let target = object.flatMap {
            resolver.horizontal(of: $0, observer: observer, date: date)
        }
        return SlewPlanner.plan(resolution: resolution, targetHorizontal: target, policy: policy)
    }

    // MARK: - Bantu

    /// Peristiwa haptic dari perpindahan keadaan.
    ///
    /// Hanya perpindahan **ke** `.lock`/`.uncertain` yang berbunyi. Berada di
    /// keadaan yang sama pada sampel berikutnya tidak mengulang getaran.
    private func hapticEvents(from previous: PointingState, to current: PointingState) -> [HapticEvent] {
        guard previous != current else { return [] }
        switch current {
        case .lock: return [.lockSucceeded]
        case .uncertain: return [.uncertain]
        case .unavailable: return [.sensorUnavailable]
        default: return []
        }
    }

    private func record(_ events: [HapticEvent], at date: Date) {
        for event in events { hapticLog.append((event, date)) }
        // Batasi riwayat supaya tidak tumbuh tanpa batas di Watch.
        if hapticLog.count > 64 { hapticLog.removeFirst(hapticLog.count - 64) }
    }

    private func refreshSnapshot(state: PointingState? = nil) {
        snapshot = PointingSnapshot(
            state: state ?? machine.state,
            intent: machine.currentIntent,
            rawPointing: snapshot.rawPointing,
            calibratedPointing: snapshot.calibratedPointing,
            angularRateDegPerSec: machine.angularRateDegPerSec,
            aim: config.aim,
            hasSensor: isSensorAvailable,
            isCalibrated: calibration.sampleCount > 0
        )
    }
}
