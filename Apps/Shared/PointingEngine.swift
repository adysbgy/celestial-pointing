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

    /// Pasang ambang keyakinan baru (mis. hasil Experiment 1 dari iPhone).
    ///
    /// **Kenapa ini ada, bukan `controller.setConfidencePolicy(_:)` langsung.**
    /// Mengubah ambang menghentikan alur dan membuang resolusi terakhir, karena
    /// jawaban yang sudah ada dihitung dengan ambang **lama**. Kalau pemanggil
    /// menyentuh controller langsung, `snapshot` — satu-satunya sumber yang
    /// dibaca UI — tidak ikut berubah: jam tetap menampilkan objek terkunci
    /// yang diperoleh dengan ambang yang lebih longgar, di bawah ambang baru
    /// yang lebih ketat. Itu klaim yakin yang tidak lagi berlaku.
    ///
    /// - Returns: `true` bila ambangnya benar-benar berubah.
    @discardableResult
    public func setConfidencePolicy(_ policy: ConfidencePolicy) -> Bool {
        let changed = controller.setConfidencePolicy(policy)
        snapshot = controller.snapshot
        if changed {
            // Objek itu dikunci dengan ambang lama; ambangnya sudah tidak
            // berlaku, jadi jangan disimpan sebagai jawaban terakhir.
            lastLockedObject = nil
        }
        return changed
    }

    /// Perbarui lokasi. Mengubah lokasi menggeser seluruh langit, jadi jawaban
    /// yang sudah dihitung untuk langit lama **dibatalkan** — bukan dipertahankan.
    ///
    /// **Yang menentukan perpindahan adalah koordinatnya, bukan keseluruhan
    /// nilai.** `ObserverLocation` membawa `capturedAt` yang berubah di tiap
    /// pembaruan GPS, jadi membandingkan dengan `!=` akan menganggap tiap
    /// perbaikan GPS sebagai perpindahan: langit dihitung ulang, perata
    /// orientasi direset, dan alur dihentikan — tiap detik, selama app terbuka.
    /// Akibatnya jam tidak akan pernah sempat mengunci selama lokasi masih
    /// diperbarui, dan haptic "kembali ke idle" berbunyi berulang tanpa
    /// pengguna melakukan apa pun. Getaran GPS puluhan meter menggeser langit
    /// ~0.0005°, yang tidak berarti apa-apa dibanding sigma pointing.
    ///
    /// **Kenapa pembatalannya ada di `setObserver`.** Sebelumnya pembatalan
    /// ini menumpang pada `apply(calibration:)` — yang kebetulan menghentikan
    /// alur. Ketika pemasangan kalibrasi yang sama dijadikan tanpa-efek,
    /// tumpangan itu hilang dan perpindahan tempat berhenti membatalkan apa
    /// pun: objek dari langit lama tetap tampil seolah masih berlaku, tanpa
    /// satu pun bagian UI yang terlihat keliru. Sekarang lokasi membatalkan
    /// jawabannya sendiri, jadi tidak bergantung pada efek samping pemanggil
    /// lain. Kalibrasi tetap dipertahankan: offset yaw adalah sifat pemasangan
    /// jam, bukan sifat tempat.
    public func update(location newValue: ObserverLocation) {
        guard !newValue.isSamePlace(as: location) else { return }
        location = newValue
        controller.setObserver(newValue.observer)
        snapshot = controller.snapshot
        lastLockedObject = nil
        // Konteks langit (Matahari/Bulan) dihitung untuk **tempat**, jadi
        // konteks tempat lama tidak berlaku di tempat baru. Perhitungan ulang
        // dipaksa: penjagaan waktu di `refreshSkyContext` ada untuk membatasi
        // pemanggilan 20 Hz dari sampel sensor, bukan untuk menahan perubahan
        // lokasi.
        skyContextAt = nil
        refreshSkyContext()
    }

    /// Sambungkan sumber lokasi ke engine: lokasi yang sudah berlaku dipasang
    /// sekarang, dan **setiap** perubahan berikutnya diteruskan otomatis.
    ///
    /// **Kenapa pemanggil tidak boleh hanya memanggil `update(location:)`
    /// sekali.** Lokasi sungguhan datang beberapa detik setelah `start()` —
    /// setelah UI selesai dirender. Kalau penyambungan ini tidak ada, engine
    /// akan memakai lokasi bawaan selamanya sementara layar menampilkan
    /// koordinat sungguhan; seluruh langit bergeser ratusan derajat dan tidak
    /// ada satu pun bagian UI yang terlihat salah. Menaruh penyambungan di
    /// dalam engine membuat app tidak bisa "lupa" menyambungkannya.
    ///
    /// Sengaja `internal`, bukan `public`: `LocationProvider` adalah tipe
    /// internal modul app (ia menyentuh CoreLocation), jadi anggota publik
    /// tidak boleh mengeksposnya.
    func bind(location provider: LocationProvider) {
        provider.onLocationChanged = { [weak self] newValue in
            self?.update(location: newValue)
        }
        update(location: provider.effectiveLocation)
    }

    /// Dipanggil `MotionLogger` untuk setiap sampel sensor.
    public func ingest(_ update: PointingUpdate, at date: Date = Date()) {
        let wasLocked = snapshot.state == .lock
        sampleCount += 1
        snapshot = update.snapshot
        if !update.haptics.isEmpty { haptics?(update.haptics) }
        if update.snapshot.state == .lock {
            if !wasLocked { lockCount += 1 }
            // `answeredObject` — sama dengan yang dipakai pesan dan riwayat.
            // Di sini hasilnya identik (`lock` selalu punya jawaban), tapi
            // memakai satu predikat yang sama berarti "objek terakhir yang
            // terkunci" tidak bisa diam-diam menjadi objek yang dipertahankan
            // mesin keadaan kalau aturan `lock` berubah.
            lastLockedObject = update.snapshot.answeredObject
        }
        refreshSkyContext(at: date)
    }

    /// Perbarui konteks langit (Matahari/Bulan). Dipanggil jarang — konteks
    /// berubah lambat dan efemeris tidak murah.
    ///
    /// **Kenapa ada penjagaan waktu.** Metode ini dipanggil dari `ingest(_:)`,
    /// yaitu pada **setiap** sampel sensor — 20 kali per detik. Tanpa penjagaan
    /// ini, tiap sampel menjalankan efemeris Matahari dan Bulan penuh di main
    /// actor, membebani baterai dan membuat UI tersendat, sementara nilainya
    /// praktis tidak berubah dalam hitungan detik. Ambang bawaan mengikuti
    /// seberapa cepat konteks benar-benar bergerak: Bulan ~0.5°/jam.
    ///
    /// Perubahan **lokasi** melewati penjagaan ini: `PointingEngine` memanggil
    /// `refreshSkyContext` langsung saat lokasi baru dipasang, karena langit di
    /// tempat baru belum pernah dihitung.
    public func refreshSkyContext(at date: Date = Date()) {
        if let last = skyContextAt,
           date.timeIntervalSince(last) < Self.skyContextInterval {
            return
        }
        skyContextAt = date
        skyContext = controller.resolver.skyContext(observer: location.observer, date: date)
    }

    /// Jarak waktu minimum antar perhitungan konteks langit (detik).
    static let skyContextInterval: TimeInterval = 30

    private var skyContextAt: Date?

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
    /// pernah terkunci — tapi UI **wajib** membedakannya lewat
    /// `isDisplayingStaleObject`, karena `lastLockedObject` bisa berasal dari
    /// pandangan sebelumnya.
    ///
    /// Aturannya sendiri ada di `PointingKit`
    /// (`PointingSnapshot.displayedObject(lastLocked:)`) supaya bisa diuji di
    /// Linux — lihat `PointingPresentationTests`. Di sini hanya meneruskan.
    public var displayedObject: CelestialObject? {
        snapshot.displayedObject(lastLocked: lastLockedObject)
    }

    /// Apakah objek yang ditampilkan adalah sisa dari pandangan sebelumnya.
    ///
    /// **Kenapa bukan `snapshot.bestObject == nil`.** Mesin keadaan sengaja
    /// mempertahankan `currentIntent` supaya panel tidak berkedip saat
    /// pergelangan bergerak sedikit. Akibatnya `snapshot.bestObject` tetap
    /// berisi objek **dari arah tunjuk sebelumnya** saat keadaan sudah kembali
    /// `pointing` — jadi menilai "basi" dari `bestObject == nil` justru
    /// melaporkan "bukan sisa" untuk objek yang paling basi, dan peringatan
    /// "sisa pandangan sebelumnya" di layar jam tidak pernah bisa muncul.
    /// Yang menentukan adalah apakah keadaan **punya jawaban sekarang**.
    public var isDisplayingStaleObject: Bool {
        snapshot.isDisplayingStaleObject(lastLocked: lastLockedObject)
    }

    /// Arah tunjuk terkalibrasi, untuk ditampilkan sebagai angka.
    ///
    /// `nil` saat sensor tidak hidup: angka yang tersisa di cuplikan adalah
    /// arah **terakhir sebelum sensor hilang**, dan menampilkannya tanpa
    /// penanda membuat bacaan lama tampak seperti pengukuran sekarang —
    /// persis yang dilarang PRD. Saat sensor hidup, ini arah yang berlaku.
    public var pointing: HorizontalCoord? {
        snapshot.hasSensor ? snapshot.calibratedPointing : nil
    }

    /// Jawaban engine yang berlaku untuk arah tunjuk **sekarang**.
    ///
    /// Dipakai Experiment 1 saat merekam. Lihat `PointingController.answeredIntent`
    /// untuk alasan mengapa `snapshot.intent` saja tidak cukup.
    public var answeredIntent: CelestialIntent? { controller.answeredIntent }
}
