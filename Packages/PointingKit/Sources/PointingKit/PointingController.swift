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
    /// Jarak sudut kandidat terbaik ke tetangga terdekatnya di langit (derajat).
    /// `nil` = tidak ada kandidat lain, atau belum ada resolusi.
    ///
    /// Ini variabel keputusan kedua dari `ConfidenceModel`: kandidat boleh saja
    /// sangat dekat dengan arah tunjuk, tapi kalau ada tetangga di dalam
    /// `ambiguitySigma` σ, jawabannya tidak boleh HIGH. Tanpa angka ini di
    /// cuplikan, diagnostik tidak bisa membedakan "ragu karena jauh" dari "ragu
    /// karena ambigu" — padahal keduanya butuh perbaikan yang berbeda.
    public var nearestNeighbourDeg: Double?
    /// Sumbu badan yang dianggap "arah tunjuk".
    public var aim: DeviceAimAxis
    /// Orientasi perangkat **mentah** dari sampel terakhir, sebelum perataan.
    ///
    /// Dipakai Experiment 1 untuk mengarsipkan attitude mentah tiap percobaan
    /// (Lampiran A) — satu-satunya data yang membuat `rawPointing` bisa
    /// dihitung ulang dari nol. `nil` bila belum ada sampel.
    public var rawAttitudeQuaternion: Quaternion?
    /// Apakah sensor sedang tersedia.
    public var hasSensor: Bool
    /// Apakah kalibrasi sudah pernah diselesaikan.
    public var isCalibrated: Bool

    /// Mengapa engine tidak menemukan objek — hanya terisi saat keadaan
    /// `.searching`, `nil` selebihnya.
    ///
    /// **Kenapa hanya `.searching`.** Saat `.pointing` pergelangan masih
    /// bergerak dan resolusi terakhir berasal dari arah yang sudah ditinggalkan;
    /// menampilkan "semua objek di bawah horizon" untuk arah yang **lama** akan
    /// menjelaskan sesuatu yang tidak sedang ditunjuk. Saat ada jawaban
    /// (`lock`/`uncertain`) `Resolution.searchHint` sendiri sudah `nil`. Jadi
    /// hint hanya jujur di satu keadaan: diam, sudah diresolusi, tanpa kandidat.
    public var searchHint: SearchHint?

    public init(state: PointingState,
                intent: CelestialIntent? = nil,
                rawPointing: HorizontalCoord? = nil,
                calibratedPointing: HorizontalCoord? = nil,
                angularRateDegPerSec: Double? = nil,
                nearestNeighbourDeg: Double? = nil,
                aim: DeviceAimAxis = .defaultForearm,
                rawAttitudeQuaternion: Quaternion? = nil,
                hasSensor: Bool = true,
                isCalibrated: Bool = false,
                searchHint: SearchHint? = nil) {
        self.state = state
        self.intent = intent
        self.rawPointing = rawPointing
        self.calibratedPointing = calibratedPointing
        self.angularRateDegPerSec = angularRateDegPerSec
        self.nearestNeighbourDeg = nearestNeighbourDeg
        self.aim = aim
        self.rawAttitudeQuaternion = rawAttitudeQuaternion
        self.hasSensor = hasSensor
        self.isCalibrated = isCalibrated
        self.searchHint = searchHint
    }

    /// Objek terbaik yang sedang ditampilkan.
    public var bestObject: CelestialObject? { intent?.best }

    /// Teks status singkat untuk UI.
    ///
    /// Sengaja hanya meneruskan ke `PointingState.shortLabel` — kalau di sini
    /// ada kalimat sendiri, jam bisa menampilkan kata yang berbeda dari teks
    /// yang diuji, dan janji "engine yang ragu terlihat ragu" jadi tidak lagi
    /// berlaku di layar.
    public var statusText: String { state.shortLabel }
}

/// Hasil satu langkah: keadaan terbaru + peristiwa haptic yang harus dipicu.
public struct PointingUpdate: Equatable, Sendable {
    public var snapshot: PointingSnapshot
    public var haptics: [HapticEvent]

    /// Kenapa ini publik: perubahan keadaan tidak selalu datang dari sampel
    /// sensor. Sensor yang mati, ambang yang diganti, atau kalibrasi baru juga
    /// mengubah cuplikan — dan pemanggil di luar modul ini (app jam) perlu
    /// menyampaikan cuplikan itu ke UI lewat saluran yang sama dengan sampel.
    /// Tanpa inisialisasi publik, satu-satunya cara adalah menyentuh controller
    /// diam-diam, dan UI akan tertinggal di keadaan lama.
    public init(snapshot: PointingSnapshot, haptics: [HapticEvent]) {
        self.snapshot = snapshot
        self.haptics = haptics
    }
}

/// Parameter alur yang bisa diubah dari UI/pengaturan.
public struct PointingControllerConfig: Equatable, Sendable {
    /// Sumbu badan yang dianggap arah tunjuk. Bawaan: lengan bawah pada
    /// pemakaian bawaan watchOS (ADR-002). App jam menggantinya dari
    /// `WearConfiguration`; app iPhone memakai tepi atas (`.screenUp`).
    public var aim: DeviceAimAxis
    /// Kerangka acuan CoreMotion yang dipakai `MotionLogger`. Harus sama
    /// dengan kerangka sensor sungguhan, karena arti quaternion bergantung
    /// padanya.
    public var frame: AttitudeReferenceFrame
    /// Ambang "pergelangan diam" dan laju resolusi.
    public var policy: PointingPolicy
    /// Setengah sudut kerucut pencarian kandidat (derajat).
    public var coneDeg: Double
    /// Bobot perata orientasi: kecil = halus, besar = gesit.
    public var smootherBlend: Double

    public init(aim: DeviceAimAxis = .defaultForearm,
                frame: AttitudeReferenceFrame = .xArbitraryZVertical,
                policy: PointingPolicy = PointingPolicy(),
                coneDeg: Double = 20.0,
                smootherBlend: Double = 0.3) {
        self.aim = aim
        self.frame = frame
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
    ///
    /// `private(set)`: penggantian **wajib** lewat `setObserver(_:)`, karena
    /// mengubah lokasi membatalkan jawaban yang sudah dihitung untuk langit
    /// yang lama. Kalau pemanggil bisa menulisnya langsung, jawaban lama akan
    /// tetap tampil setelah langitnya bergeser.
    public private(set) var observer: Observer
    /// Kalibrasi yang sedang dipakai.
    public private(set) var calibration: PointingCalibration
    /// Parameter alur.
    public var config: PointingControllerConfig
    /// Resolver engine (katalog + efemeris).
    ///
    /// `private(set)`: resolver sengaja tidak bisa diganti setelah controller
    /// dibuat — menukar katalog/efemeris di tengah alur akan membuat jawaban
    /// lama dan baru tidak bisa dibandingkan. Yang **boleh** berubah adalah
    /// ambang keyakinannya, lewat `setConfidencePolicy(_:)`.
    public private(set) var resolver: PointingResolver

    /// Cuplikan terakhir, untuk dirender ulang tanpa sampel baru.
    public private(set) var snapshot: PointingSnapshot
    /// Waktu (epoch) terakhir `feed` memasukkan arah tunjuk. Dipakai sebagai
    /// default `capture`/`captureNearest` supaya penjagaan horizon menilai
    /// ketinggian objek pada **saat yang sama** dengan arah yang dicatat,
    /// bukan pada jam dinding saat tombol ditekan — keduanya bisa berbeda
    /// detik sampai jam, dan menilai horizon di waktu yang salah membuat
    /// objek tampak "di bawah cakrawala" padahal sedang ditunjuk.
    public private(set) var lastFeedTimestamp: Date?
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
    ///
    /// **Memasang kalibrasi yang sama bukan perubahan.** Tanpa penjagaan ini,
    /// pemanggil yang mengulang kalibrasi yang sedang berlaku — mis. UI yang
    /// menyegarkan tampilan setelah mencatat acuan — akan mereset perata
    /// orientasi dan menghentikan alur tanpa ada yang berubah. Akibatnya jam
    /// kehilangan kunci yang sudah benar, dan itu terjadi persis saat pengguna
    /// sedang mengkalibrasi. Reset hanya masuk akal bila kalibrasinya memang
    /// berubah, karena hanya perubahan yang membuat acuan lama tidak sebanding.
    public func apply(calibration newValue: PointingCalibration) {
        guard newValue != calibration else { return }
        calibration = newValue
        smoother.reset()
        machine.stop()
        refreshSnapshot()
    }

    /// Pasang pengamat baru. Mengubah lokasi menggeser seluruh langit.
    ///
    /// **Kenapa ini ada, bukan sekadar `observer = nilai`.** Jawaban engine
    /// disimpan di mesin keadaan (`currentIntent`) dan hanya dibuang saat alur
    /// dihentikan. Mengganti lokasi tanpa menghentikan alur akan menyisakan
    /// `snapshot.intent` berisi objek yang dihitung untuk langit **lama** —
    /// dan objek itu bisa berbeda dari yang benar-benar ada di arah tunjuk
    /// sekarang. Tidak ada bagian UI yang terlihat keliru, jadi kesalahan ini
    /// tidak akan ketahuan sampai pengguna memindahkan jam ke tempat lain dan
    /// melihat bintang yang salah.
    ///
    /// Memasang pengamat yang **sama** bukan perubahan: langitnya tidak
    /// bergeser, jadi jawaban yang sudah benar tidak boleh dibuang.
    public func setObserver(_ newValue: Observer) {
        guard newValue != observer else { return }
        observer = newValue
        machine.stop()
        lastResolution = nil
        refreshSnapshot()
    }

    /// Pasang ambang keyakinan baru.
    ///
    /// Dipakai saat hasil Experiment 1 (atau kalibrasi) mengubah sigma pointing
    /// yang kita akui. Alur dihentikan karena jawaban yang sudah ada dihitung
    /// dengan ambang lama — membiarkannya tampil setelah ambang berubah berarti
    /// mengklaim keyakinan yang tidak lagi berlaku.
    ///
    /// Ambang yang tidak masuk akal (nol, negatif, tak berhingga) **ditolak**,
    /// bukan diterapkan: sigma nol membuat engine selalu ragu, dan sigma tak
    /// berhingga membuatnya selalu yakin — dua-duanya melanggar prinsip
    /// "uncertainty > false confidence".
    @discardableResult
    public func setConfidencePolicy(_ policy: ConfidencePolicy) -> Bool {
        guard policy.pointingSigmaDeg.isFinite, policy.pointingSigmaDeg > 0 else { return false }
        guard policy != resolver.confidencePolicy else { return false }
        resolver.confidencePolicy = policy
        machine.stop()
        lastResolution = nil
        refreshSnapshot()
        return true
    }

    /// Ganti kebijakan visibilitas (mis. langit kota ↔ gelap, ADR-012).
    ///
    /// Alasannya sama dengan `setConfidencePolicy(_:)`: jawaban yang sudah
    /// ada dihitung dengan penyaring **lama**, jadi alur dihentikan dan
    /// resolusi terakhir dibuang.
    ///
    /// - Returns: `true` bila kebijakannya benar-benar berubah.
    @discardableResult
    public func setVisibilityPolicy(_ policy: VisibilityPolicy) -> Bool {
        guard policy != resolver.policy else { return false }
        resolver.policy = policy
        machine.stop()
        lastResolution = nil
        refreshSnapshot()
        return true
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
        // Arah tunjuk mentah harus murni dari sensor; kalibrasi diterapkan
        // sekali, di `feed(quaternion:timestamp:)`.
        guard let attitude = DeviceAttitude(cmX: cmX, cmY: cmY, cmZ: cmZ, cmW: cmW,
                                            frame: config.frame)
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

        lastFeedTimestamp = timestamp

        // 1. Perata: meredam gemetar tanpa menunda gerakan besar.
        let smoothed = smoother.update(raw) ?? raw

        // 2. Arah tunjuk dari attitude teredam, dalam kerangka acuan yang
        //    eksplisit (ADR-002). Kalibrasi diterapkan sekali, di langkah 3.
        let attitude = DeviceAttitude(quaternion: smoothed, frame: config.frame)
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
            nearestNeighbourDeg: lastResolution?.nearestNeighbourDeg,
            aim: config.aim,
            rawAttitudeQuaternion: machine.lastRawQuaternion,
            hasSensor: isSensorAvailable,
            isCalibrated: calibration.sampleCount > 0,
            // Alasan hanya jujur saat `.searching`: pergelangan sudah diam dan
            // resolusi memang untuk arah tunjuk sekarang. Lihat
            // `PointingSnapshot.searchHint`.
            searchHint: state == .searching ? lastResolution?.searchHint : nil
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

    /// Rencana GoTo teleskop untuk jawaban yang **berlaku sekarang**.
    ///
    /// Arah target diambil dari **posisi objek yang teridentifikasi**, bukan
    /// dari arah tunjuk pergelangan — aturan keras PRD, dan satu-satunya jalan
    /// agar tidak ada sudut pergelangan yang pernah sampai ke motor.
    ///
    /// **Kenapa keadaan harus punya jawaban, bukan sekadar ada resolusi.**
    /// `lastResolution` sengaja dipertahankan supaya cuplikan tetap membawa
    /// jarak tetangga untuk diagnostik, dan ia hanya dibuang saat alur
    /// dihentikan (atau saat lokasi/ambang berubah) — **bukan** saat arah
    /// tunjuk bergeser dan keadaan kehilangan jawabannya. Jadi begitu
    /// pergelangan bergerak menjauh, `lastResolution` masih berisi resolusi
    /// dari arah tunjuk **sebelumnya**. Membacanya mentah berarti teleskop
    /// diarahkan ke objek yang sudah tidak ada di arah tunjuk sekarang: langkah
    /// OBJECT ID dilewati dan GoTo dihitung dari niat lama. Itu kelas yang sama
    /// dengan objek sisa yang bocor ke iPhone — kali ini ke motor.
    ///
    /// - Returns: `nil` bila belum ada resolusi **atau** keadaan sekarang tidak
    ///   punya jawaban (`lock`/`uncertain`).
    public func slewDecision(date: Date,
                             policy: SlewSafetyPolicy = SlewSafetyPolicy()) -> SlewDecision? {
        guard snapshot.state.hasAnswer else { return nil }
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
        let resolved = state ?? machine.state
        snapshot = PointingSnapshot(
            state: resolved,
            intent: machine.currentIntent,
            rawPointing: snapshot.rawPointing,
            calibratedPointing: snapshot.calibratedPointing,
            angularRateDegPerSec: machine.angularRateDegPerSec,
            nearestNeighbourDeg: lastResolution?.nearestNeighbourDeg,
            aim: config.aim,
            rawAttitudeQuaternion: machine.lastRawQuaternion,
            hasSensor: isSensorAvailable,
            isCalibrated: calibration.sampleCount > 0,
            searchHint: resolved == .searching ? lastResolution?.searchHint : nil
        )
    }
}

public extension PointingController {

    /// Jawaban engine yang boleh dianggap berlaku **untuk arah tunjuk sekarang**.
    ///
    /// `nil` bila keadaan bukan `lock`/`uncertain`.
    ///
    /// Kenapa perlu: mesin keadaan sengaja mempertahankan `currentIntent` supaya
    /// UI tidak berkedip saat pergelangan bergerak sedikit. Akibatnya
    /// `snapshot.intent` bisa berisi jawaban dari arah tunjuk **sebelumnya**
    /// sementara pengguna sudah mengarah ke tempat lain.
    ///
    /// Bagi tampilan itu tidak berbahaya (keadaan sudah memberi tahu). Bagi
    /// Experiment 1 itu berbahaya: merekam jawaban lama sebagai jawaban untuk
    /// arah baru akan mencatat false lock yang tidak pernah terjadi — dan
    /// false lock adalah satu-satunya angka yang membuat eksperimen dinyatakan
    /// gagal. Kegagalan engine tidak boleh dikarang oleh alat ukurnya.
    var answeredIntent: CelestialIntent? {
        snapshot.state.hasAnswer ? snapshot.intent : nil
    }
}
