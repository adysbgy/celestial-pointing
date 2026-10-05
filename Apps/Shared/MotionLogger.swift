import Foundation
import CoreMotion
import CelestialEngine
import PointingKit

/// Pembungkus CoreMotion: `CMDeviceMotion` → `PointingController`.
///
/// Ini satu-satunya berkas yang membaca sensor gerak — di jam maupun di
/// iPhone. Dipakai bersama supaya kedua app tidak perlahan-lahan berbeda
/// perilaku, dan supaya iPhone bisa merekam Experiment 1 dengan jalur
/// pemrosesan yang **persis sama** dengan jam. Kalau jalurnya berbeda, hasil
/// eksperimen tidak lagi menggambarkan jam.
///
/// Tugasnya sempit: menyalakan device motion, meneruskan sampel apa adanya, dan
/// **jujur saat sensor tidak ada**. Tidak ada pemulusan, tidak ada tebak-tebakan
/// di sini — semua keputusan sudah ada di `PointingController` dan sudah diuji
/// di Linux.
///
/// Kenapa `xArbitraryZVertical`: kerangka itu membuat sumbu-Z sejajar gravitasi,
/// sehingga kemiringan (altitude) sudah absolut terhadap cakrawala. Yang tidak
/// diketahui CoreMotion adalah arah hadap pada bidang horizontal — itulah yang
/// diselesaikan kalibrasi. Memakai kerangka acuan lain (`xMagneticNorthZVertical`)
/// akan tampak lebih praktis, tapi mengandalkan magnetometer yang mudah
/// terganggu logam/meja; PRD melarang mengasumsikan akurasi seperti itu.
@MainActor
public final class MotionLogger: ObservableObject {

    /// Apakah device motion sedang menyala.
    @Published public private(set) var isRunning = false
    /// Pesan terakhir saat sensor tidak bisa dipakai.
    @Published public private(set) var unavailableReason: String?
    /// Jumlah sampel yang sudah diterima — untuk memastikan sensor benar hidup.
    @Published public private(set) var sampleCount = 0

    /// Interval sampel. 1/50 dtk = 20 Hz: cukup untuk mengukur "pergelangan
    /// diam" (ambang alur 0,4 dtk) tanpa membebani baterai.
    public var sampleInterval: TimeInterval = 1.0 / 50.0

    private let manager = CMMotionManager()
    private weak var controller: PointingController?
    /// Dijalankan setiap sampel dengan hasil pemrosesan controller.
    ///
    /// Haptic **tidak** dipicu di sini: controller sudah menentukan peristiwanya,
    /// dan memainkannya di dua tempat akan membuat getaran dobel. Penerima
    /// (biasanya `PointingEngine`) yang memutuskan cara menyuarakannya.
    public var onUpdate: ((PointingUpdate) -> Void)?

    public init() {}

    /// Apakah perangkat ini punya device motion sama sekali.
    public var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// Mulai mengalirkan sampel ke controller.
    ///
    /// Aman dipanggil berkali-kali. Kalau sensor tidak tersedia, controller
    /// diberi tahu supaya ia **berhenti menebak**, bukan diam-diam memakai
    /// sampel terakhir.
    public func start(controller: PointingController) {
        self.controller = controller
        guard manager.isDeviceMotionAvailable else {
            unavailableReason = SensorStatusText.motionMissing
            // Lewat saluran yang sama dengan sampel: cuplikan UI harus ikut
            // berubah, bukan hanya controller di belakangnya.
            publishSensorLoss()
            return
        }
        guard !manager.isDeviceMotionActive else { return }

        unavailableReason = nil
        manager.deviceMotionUpdateInterval = sampleInterval
        manager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                // Pesan sistem dibungkus lewat katalog: ia mengikuti bahasa
                // perangkat, bukan bahasa yang sedang membaca katalog, jadi
                // menampilkannya apa adanya akan menyisipkan satu baris
                // berbahasa lain di tengah layar. Namanya tetap ikut
                // ditampilkan (`%@`) supaya dua kegagalan berbeda tidak
                // terbaca sama.
                self.handleFailure(SensorStatusText.motionFailed(error.localizedDescription))
                return
            }
            guard let motion else { return }
            self.consume(motion)
        }
        isRunning = manager.isDeviceMotionActive
    }

    /// Hentikan sensor dan alur.
    ///
    /// **Kenapa tidak ada `pause()`.** Dulu ada metode bernama `pause()` yang
    /// isinya **persis sama** dengan `stop()` — sensor dimatikan, alur
    /// dihentikan. Tidak ada satu pun pemanggilnya. Namanya menjanjikan
    /// sesuatu yang tidak dilakukannya: "pause" berarti bisa dilanjutkan,
    /// sedangkan yang terjadi adalah penghentian penuh (`PointingStateMachine`
    /// kembali ke `idle`, perata orientasi direset). Pemanggil berikutnya yang
    /// menyambungkannya ke `scenePhase` akan mengira alurnya bisa dilanjutkan
    /// tanpa mengarahkan ulang, lalu mendapat perilaku sebaliknya — tepat kelas
    /// kesalahan siklus hidup yang tidak terlihat dari UI. Kalau jeda yang
    /// benar-benar bisa dilanjutkan dibutuhkan, ia harus **berbeda** dari
    /// `stop()` (mis. mempertahankan niat supaya pointing lanjut tanpa
    /// mengarah ulang), bukan sekadar nama lain untuk hal yang sama.
    public func stop() {
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        isRunning = false
        controller?.stop()
    }

    /// Proses satu sampel attitude tanpa CoreMotion (untuk uji/pratinjau).
    ///
    /// **Kenapa waktunya `Date()`, bukan `motion.timestamp`.** Properti itu
    /// bukan waktu Unix, melainkan detik sejak perangkat menyala. Memakainya
    /// akan membuat setiap sampel bertanggal 1970 — alur tidak akan pernah
    /// melihat "pergelangan diam" (karena jeda antar-sampel jadi nol), dan
    /// efemeris dihitung untuk tanggal yang salah. Waktu dinding dipakai
    /// supaya keputusan alur dan posisi benda langit mengacu ke saat yang sama.
    public func consume(_ motion: CMDeviceMotion, at date: Date = Date()) {
        guard let controller else { return }
        let q = motion.attitude.quaternion
        sampleCount += 1
        let update = controller.feed(cmX: q.x, cmY: q.y, cmZ: q.z, cmW: q.w,
                                     timestamp: date)
        onUpdate?(update)
    }

    // MARK: - Bantu

    /// Sensor mati di tengah pemakaian. **Ini harus terlihat di layar.**
    ///
    /// `controller.setSensorAvailable(false)` saja tidak cukup: ia menghentikan
    /// alur dan membuang jawaban, tapi `PointingEngine.snapshot` — satu-satunya
    /// sumber yang dibaca UI — tidak ikut berubah, karena sampel sudah berhenti
    /// mengalir dan `onUpdate` tidak pernah dipanggil lagi. Akibatnya jam tetap
    /// menampilkan objek terakhir **seolah masih terkonfirmasi**, padahal
    /// sensornya sudah mati. Itu persis yang dilarang PRD.
    ///
    /// Karena itu peristiwa ini dikirim lewat saluran yang sama dengan sampel:
    /// cuplikan yang sudah diperbarui + peristiwa haptic. Pemanggil (biasanya
    /// `PointingEngine`) yang memutuskan cara menyuarakannya.
    private func handleFailure(_ reason: String) {
        unavailableReason = reason
        isRunning = false
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        publishSensorLoss()
    }

    /// Beritahu pemanggil bahwa sensor hilang, memakai saluran yang sama dengan
    /// sampel sensor — supaya cuplikan di UI tidak tertinggal di keadaan lama.
    private func publishSensorLoss() {
        guard let controller else { return }
        let events = controller.setSensorAvailable(false)
        onUpdate?(PointingUpdate(snapshot: controller.snapshot, haptics: events))
    }
}
