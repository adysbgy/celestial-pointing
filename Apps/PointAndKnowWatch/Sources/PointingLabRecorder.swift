import Foundation
import CoreMotion
import WatchKit
import CelestialEngine
import PointingKit

/// Perekam Pointing Lab di jam (ADR-004).
///
/// Menjalankan **dua** aliran CoreMotion sekaligus bila perangkat
/// mengizinkan: satu di kerangka sembarang-terkoreksi (tanpa Utara) dan satu
/// di kerangka berutara (sebenarnya bila ada, magnetis bila tidak). Apple
/// menyarankan satu `CMMotionManager` per app karena instans ganda bisa
/// menurunkan laju sampel; karena itu laju **yang diterima** per aliran
/// direkam di setiap percobaan, dan mode satu aliran tersedia sebagai
/// pembanding.
///
/// Selama Lab terbuka, `MotionLogger` produk dimatikan oleh view supaya tidak
/// ada aliran ketiga.
@MainActor
final class PointingLabRecorder: NSObject, ObservableObject {

    struct Stream {
        let frame: AttitudeReferenceFrame
        let manager: CMMotionManager
        var buffer: [LabMotionSample] = []
    }

    // Keadaan yang ditampilkan.
    @Published private(set) var isRunning = false
    @Published private(set) var availableFrames: [AttitudeReferenceFrame] = []
    @Published private(set) var activeFrames: [AttitudeReferenceFrame] = []
    @Published private(set) var observedHz: [AttitudeReferenceFrame: Double] = [:]
    @Published private(set) var live: HorizontalCoord?
    @Published private(set) var liveFrame: AttitudeReferenceFrame?
    @Published private(set) var trialCount = 0
    @Published private(set) var lastResult: LabFrameSummary?
    @Published private(set) var runtimeState = "none"
    @Published private(set) var isMarking = false
    @Published var dualStream = true

    let wear = WearConfiguration.current
    var aim: DeviceAimAxis { wear.forearmAim }
    let sessionID = UUID()
    let requestedInterval: TimeInterval = 1.0 / 50.0
    /// Sampel yang disimpan per aliran: cukup untuk jendela ±0,5 dtk plus
    /// jeda menunggu separuh jendela sesudah penanda.
    private let bufferSeconds = 3.0

    private var streams: [Stream] = []
    private var runtimeSession: WKExtendedRuntimeSession?
    private var lastHzUpdate: Double = 0

    let fileURL: URL

    override init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PointingLab", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "")
        fileURL = dir.appendingPathComponent("lab-\(stamp)-\(sessionID.uuidString.prefix(8)).jsonl")
        super.init()
    }

    // MARK: Siklus hidup

    func start() {
        guard !isRunning else { return }
        let mask = CMMotionManager.availableAttitudeReferenceFrames()
        availableFrames = AttitudeReferenceFrame.allCases.filter {
            mask.contains(CMAttitudeReferenceFrame($0))
        }

        var wanted: [AttitudeReferenceFrame] = []
        if let north = [AttitudeReferenceFrame.xTrueNorthZVertical, .xMagneticNorthZVertical]
            .first(where: availableFrames.contains) {
            wanted.append(north)
        }
        if dualStream || wanted.isEmpty,
           let arbitrary = [AttitudeReferenceFrame.xArbitraryCorrectedZVertical, .xArbitraryZVertical]
            .first(where: availableFrames.contains) {
            wanted.append(arbitrary)
        }

        streams = wanted.map { Stream(frame: $0, manager: CMMotionManager()) }
        for index in streams.indices {
            let manager = streams[index].manager
            let frame = streams[index].frame
            guard manager.isDeviceMotionAvailable else { continue }
            manager.deviceMotionUpdateInterval = requestedInterval
            manager.showsDeviceMovementDisplay = frame.hasAbsoluteHeading
            manager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame(frame), to: .main) {
                [weak self] motion, _ in
                guard let self, let motion else { return }
                self.consume(motion, streamIndex: index)
            }
        }
        activeFrames = streams.map(\.frame)
        liveFrame = activeFrames.first
        isRunning = !streams.isEmpty
        startRuntimeSession()
    }

    func stop() {
        for s in streams { s.manager.stopDeviceMotionUpdates() }
        streams = []
        isRunning = false
        runtimeSession?.invalidate()
        runtimeSession = nil
    }

    func restart() {
        stop()
        start()
    }

    private func consume(_ motion: CMDeviceMotion, streamIndex: Int) {
        guard streams.indices.contains(streamIndex) else { return }
        let q = motion.attitude.quaternion
        let field = motion.magneticField
        let hasField = field.accuracy != .uncalibrated
        let sample = LabMotionSample(
            t: motion.timestamp,
            quaternion: Quaternion(cmX: q.x, cmY: q.y, cmZ: q.z, cmW: q.w),
            gravity: Vector3(x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z),
            rotationRate: Vector3(x: motion.rotationRate.x, y: motion.rotationRate.y,
                                  z: motion.rotationRate.z),
            userAcceleration: Vector3(x: motion.userAcceleration.x, y: motion.userAcceleration.y,
                                      z: motion.userAcceleration.z),
            magneticField: hasField ? Vector3(x: field.field.x, y: field.field.y, z: field.field.z) : nil,
            magneticAccuracy: Int(field.accuracy.rawValue),
            heading: motion.heading >= 0 ? motion.heading : nil
        )
        streams[streamIndex].buffer.append(sample)
        let cutoff = motion.timestamp - bufferSeconds
        if let firstKeep = streams[streamIndex].buffer.firstIndex(where: { $0.t >= cutoff }), firstKeep > 0 {
            streams[streamIndex].buffer.removeFirst(firstKeep)
        }

        if streamIndex == 0 {
            let attitude = DeviceAttitude(quaternion: sample.quaternion ?? .identity,
                                          frame: streams[0].frame)
            live = attitude.horizontalPointing(aim: aim)
            if motion.timestamp - lastHzUpdate > 1 {
                lastHzUpdate = motion.timestamp
                for s in streams {
                    observedHz[s.frame] = PointingLab.observedHz(
                        s.buffer.filter { $0.t >= motion.timestamp - 1 })
                }
            }
        }
    }

    // MARK: Percobaan

    /// Tandai satu percobaan: jendela ±0,5 dtk di sekitar saat ini. Rekaman
    /// ditulis setelah separuh jendela sesudahnya terkumpul.
    func mark(target: LabTarget,
              truth: HorizontalCoord?,
              observer: Observer?,
              locationIsFallback: Bool,
              environment: String,
              participant: String,
              luminanceReduced: Bool?,
              note: String = "") {
        guard isRunning, !isMarking else { return }
        isMarking = true
        let uptime = ProcessInfo.processInfo.systemUptime
        let date = Date()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((PointingLab.windowHalfWidthS + 0.1) * 1e9))
            let frames = streams.map { s -> LabFrameRecord in
                let window = PointingLab.window(s.buffer, aroundUptime: uptime)
                return LabFrameRecord(frame: s.frame, requestedIntervalS: requestedInterval,
                                      samples: window,
                                      summary: PointingLab.summarize(window, frame: s.frame,
                                                                     aim: aim, truth: truth))
            }
            let device = WKInterfaceDevice.current()
            let trial = LabTrial(sessionID: sessionID, participant: participant, markedAt: date,
                                 markedAtUptime: uptime, watchOS: device.systemVersion,
                                 deviceModel: device.model, wear: wear, aim: aim, target: target,
                                 truth: truth, observer: observer,
                                 locationIsFallback: locationIsFallback, frames: frames,
                                 extendedRuntime: runtimeState, luminanceReduced: luminanceReduced,
                                 environment: environment, note: note)
            append(trial)
            lastResult = frames.first?.summary
            isMarking = false
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func append(_ trial: LabTrial) {
        guard let line = try? PointingLab.jsonLine(trial) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: fileURL)
        }
        trialCount += 1
    }

    var hasFile: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    // MARK: Sesi runtime diperpanjang

    /// Menjaga app tetap berjalan saat layar meredup dengan lengan terangkat.
    /// Butuh `WKBackgroundModes = physical-therapy` di Info.plist. Hasilnya
    /// (berjalan/kedaluwarsa/gagal) ikut direkam di setiap percobaan, karena
    /// itu juga yang diuji.
    private func startRuntimeSession() {
        guard runtimeSession == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        runtimeSession = session
        runtimeState = "starting"
        session.start()
    }
}

extension PointingLabRecorder: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        Task { @MainActor in self.runtimeState = "running" }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        Task { @MainActor in self.runtimeState = "expiring" }
    }

    nonisolated func extendedRuntimeSession(_ session: WKExtendedRuntimeSession,
                                            didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                            error: Error?) {
        let text = "invalidated(\(reason.rawValue))" + (error.map { ": \($0.localizedDescription)" } ?? "")
        Task { @MainActor in
            self.runtimeState = text
            self.runtimeSession = nil
        }
    }
}
