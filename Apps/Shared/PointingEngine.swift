import Foundation
import Combine
import CelestialEngine
import PointingKit

/// Penghubung antara logika (yang sudah diuji di Linux) dan SwiftUI.
///
/// Semua keadaan yang ditampilkan UI berasal dari sini, dan semuanya berasal
/// dari `PointingController` — UI tidak pernah menghitung arah, tidak pernah
/// menebak objek, dan tidak pernah "merapikan" hasil engine. Yang dilakukan UI
/// hanya membaca `snapshot`.
///
/// Dipakai bersama oleh app Watch dan app iPhone. Haptic disuntikkan sebagai
/// closure supaya kelas ini tidak perlu tahu `WatchKit` ada — iPhone tidak
/// punya Taptic Engine dan tetap bisa memakai kelas yang sama.
@MainActor
public final class PointingEngine: ObservableObject {

    /// Cuplikan alur terakhir — sumber tunggal kebenaran untuk tampilan.
    @Published public private(set) var snapshot: PointingSnapshot
    /// Lokasi yang sedang dipakai (sungguhan atau darurat yang berlabel).
    @Published public private(set) var location: ObserverLocation
    /// Pesan terakhir saat sensor bermasalah.
    @Published public private(set) var sensorNote: String?
    /// Objek terbaik terakhir, disimpan supaya panel detail tidak kosong saat
    /// pergelangan sedikit bergerak dan keadaan kembali ke `pointing`.
    @Published public private(set) var lastLockedObject: CelestialObject?
    /// Ringkasan langit untuk konteks (Matahari terbit/tenggelam, Bulan).
    @Published public private(set) var skyContext: SkyContext?
    /// Berapa kali engine berpindah **ke** `lock` — dipakai UI untuk animasi.
    @Published public private(set) var lockCount = 0
    /// Jumlah sampel sensor yang sudah diproses.
    @Published public private(set) var sampleCount = 0

    public let controller: PointingController
    /// Cara menyuarakan peristiwa haptic. `nil` = tidak ada haptic (iPhone).
    public var haptics: (([HapticEvent]) -> Void)?

    public init(location: ObserverLocation = .fallback,
                config: PointingControllerConfig = PointingControllerConfig()) {
        self.location = location
        self.controller = EngineFactory.makeController(location: location, config: config)
        self.snapshot = controller.snapshot
    }

    /// Pasang kalibrasi (dari `CalibrationSession`).
    public func apply(calibration: PointingCalibration) {
        controller.apply(calibration: calibration)
        snapshot = controller.snapshot
    }

    /// Perbarui lokasi. Mengubah lokasi menggeser seluruh langit, jadi alur
    /// dihentikan dulu supaya tidak ada jawaban yang dihitung dengan lokasi lama.
    public func update(location newValue: ObserverLocation) {
        guard newValue != location else { return }
        location = newValue
        controller.observer = newValue.observer
        // Kalibrasi dipertahankan: offset yaw adalah sifat pemasangan jam,
        // bukan sifat tempat. Yang dibuang hanyalah alur yang sedang berjalan.
        controller.apply(calibration: controller.calibration)
        snapshot = controller.snapshot
        lastLockedObject = nil
    }

    /// Dipanggil `MotionLogger` untuk setiap sampel sensor.
    public func ingest(_ update: PointingUpdate, at date: Date = Date()) {
        let wasLocked = snapshot.state == .lock
        sampleCount += 1
        snapshot = update.snapshot
        if !update.haptics.isEmpty { haptics?(update.haptics) }
        if update.snapshot.state == .lock {
            if !wasLocked { lockCount += 1 }
            lastLockedObject = update.snapshot.bestObject
        }
        refreshSkyContext(at: date)
    }

    /// Perbarui konteks langit (Matahari/Bulan). Dipanggil jarang — konteks
    /// berubah lambat dan efemeris tidak murah.
    public func refreshSkyContext(at date: Date = Date()) {
        skyContext = controller.resolver.skyContext(observer: location.observer, date: date)
    }

    /// Sensor hilang / tersedia.
    public func setSensorAvailable(_ available: Bool) {
        sensorNote = available ? nil : "Data gerak tidak tersedia."
        controller.setSensorAvailable(available)
        snapshot = controller.snapshot
    }

    /// Alur dihentikan (layar pergi, pergelangan diturunkan).
    public func stop() {
        controller.stop()
        snapshot = controller.snapshot
    }

    /// Objek yang ditampilkan di panel detail.
    ///
    /// Saat terkunci/ragu: jawaban engine. Saat mencari: objek terakhir yang
    /// pernah terkunci — tapi UI **wajib** membedakannya lewat `state`, karena
    /// `lastLockedObject` bisa berasal dari pandangan sebelumnya.
    public var displayedObject: CelestialObject? {
        snapshot.bestObject ?? (snapshot.state == .searching ? lastLockedObject : nil)
    }

    /// Apakah objek yang ditampilkan adalah sisa dari pandangan sebelumnya.
    public var isDisplayingStaleObject: Bool {
        snapshot.bestObject == nil && displayedObject != nil
    }

    /// Arah tunjuk terkalibrasi, untuk ditampilkan sebagai angka.
    public var pointing: HorizontalCoord? { snapshot.calibratedPointing }

    /// Jawaban engine yang berlaku untuk arah tunjuk **sekarang**.
    ///
    /// Dipakai Experiment 1 saat merekam. Lihat `PointingController.answeredIntent`
    /// untuk alasan mengapa `snapshot.intent` saja tidak cukup.
    public var answeredIntent: CelestialIntent? { controller.answeredIntent }
}
