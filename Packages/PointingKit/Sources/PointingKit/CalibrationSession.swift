import Foundation
import CelestialEngine

/// Satu langkah alur kalibrasi yang menyentuh controller sungguhan.
public struct CalibrationSessionStep: Equatable, Sendable {
    /// Keadaan kalibrasi setelah langkah ini.
    public var flow: CalibrationUpdate
    /// Target yang dipilih untuk langkah ini (kalau ada).
    public var selectedTarget: PointingTarget?
    /// Apakah kalibrasi sudah dipasang ke controller.
    public var applied: Bool
    /// Penjelasan untuk pengguna.
    public var message: String
}

/// Alur kalibrasi yang menyambungkan UI ke `PointingController`.
///
/// Bagian yang mudah salah ada di sini: **target mana yang dipakai sebagai
/// acuan**. Dua jalur bisa dipakai — pengguna memilih dari daftar, atau arah
/// tunjuk dicocokkan ke target terdekat. Keduanya berakhir di
/// `CalibrationFlow.add(objectID:...)`, yang menghitung kebenarannya dari
/// katalog. Yang **tidak pernah** dipakai sebagai kebenaran adalah jawaban
/// engine: kalau engine salah mengenali, kalibrasi akan ikut salah dan
/// kesalahannya tidak akan pernah ketahuan.
///
/// Kelas ini tidak menyentuh SwiftUI/Combine, jadi seluruh alurnya bisa diuji
/// di Linux.
public final class CalibrationSession {

    public private(set) var flow: CalibrationFlow
    /// Controller yang dikalibrasi.
    ///
    /// Sengaja **kuat**, bukan `unowned`: alur kalibrasi bisa hidup lebih lama
    /// dari pemanggil yang membuatnya (UI sering membuat controller di dalam
    /// ekspresi). Dengan `unowned`, urutan hidup yang tidak terduga membuat
    /// proses crash saat `capture`, bukan saat pemakaian — persis jenis
    /// kegagalan yang paling sulit dilacak di jam tangan.
    private let controller: PointingController

    /// Target acuan yang boleh dipilih pengguna saat ini.
    public private(set) var referenceTargets: [PointingTarget] = []
    /// Observer yang dipakai saat `referenceTargets` terakhir dihitung.
    ///
    /// Daftar acuan bergantung pada **lokasi** pengamat: bintang yang tampak di
    /// atas horizon di satu tempat bisa sudah terbenam di tempat lain. Kalau
    /// daftar dibiarkan dari tempat lama, pengguna memilih bintang yang
    /// sebenarnya tidak ada di langitnya — lalu `capture` memakai arah bintang
    /// itu sebagai kebenaran dan offset kalibrasinya salah tanpa terlihat.
    public private(set) var referenceObserver: Observer?
    /// Waktu (UTC) saat `referenceTargets` terakhir dihitung.
    ///
    /// Sengaja disimpan, bukan cuma lokasi: bintang bergerak ~15°/jam, jadi
    /// daftar yang dihitung sekali meleset ~2,5° dalam sepuluh menit. Daftar
    /// yang dibiarkan dari detik lalu menawarkan bintang yang sudah terbenam —
    /// dan `capture` memakai arah itu sebagai kebenaran, menghasilkan sampel
    /// hantu yang membalik offset kalibrasi tanpa terlihat. Waktu ikut
    /// menentukan kebasian, bukan lokasi saja.
    public private(set) var referenceDate: Date?
    /// Batas usia daftar acuan (detik) sebelum dianggap basi.
    ///
    /// 120 s: drift maksimum dalam jendela ini masih ~0,5° (di bawah sebaran
    /// siap 3°), sehingga daftar tetap bisa dipakai sebagai kebenaran sementara
    /// UI menyegarkannya berkala. Di luar jendela ini, `isReferenceListStale`
    /// memaksa perhitungan ulang sebelum pengguna memilih acuan.
    public var referenceMaxAge: TimeInterval = 120
    /// Target yang sedang dipilih pengguna (kalau UI memakai daftar).
    public var selectedTargetID: String?

    public init(controller: PointingController,
                flow: CalibrationFlow = CalibrationFlow()) {
        self.controller = controller
        self.flow = flow
        refreshReferenceTargets()
    }

    /// Perbarui daftar acuan (mis. lokasi/waktu berubah).
    ///
    /// Hanya acuan dari `flow.referenceObjects` yang ditawarkan. Sengaja tidak
    /// memakai seluruh katalog: menawarkan 25 bintang yang semuanya harus
    /// ditunjuk satu per satu membuat kalibrasi terasa mustahil.
    ///
    /// **Sengaja hanya bintang** (`kind == .star`), dan itu bukan sekadar
    /// menyaring daftar yang lebih pendek. Kebenaran kalibrasi diambil dari
    /// posisi katalog; objek langit dalam posisinya juga di katalog, tapi ia
    /// **tidak punya tepi** — pengguna tidak bisa tahu bagian mana dari kabut
    /// Orion yang sedang ia tunjuk, jadi sampel acuannya jauh lebih berisik
    /// daripada bintang. Memasukkan objek bertepi kabur ke daftar acuan akan
    /// memperlebar `residualSpreadDeg` dan membuat kalibrasi terlihat lebih
    /// buruk daripada sesungguhnya — atau, lebih buruk, terlihat "siap"
    /// dengan offset yang salah.
    public func refreshReferenceTargets(date: Date = Date()) {
        let wanted = Set(flow.referenceObjects.map(\.id))
        referenceTargets = controller.resolver
            .availableTargets(observer: controller.observer, date: date)
            .filter { $0.kind == .star && wanted.contains($0.id) }
        referenceObserver = controller.observer
        referenceDate = date
    }

    /// Apakah daftar acuan dihitung untuk langit yang berbeda dari sekarang.
    ///
    /// Dipakai UI untuk memaksa perhitungan ulang saat lokasi pengamat berubah
    /// **atau** saat daftar sudah terlalu tua. Lokasi sungguhan tiba beberapa
    /// detik setelah layar kalibrasi dibuka, jadi tanpa sinyal ini daftar acuan
    /// tetap berisi bintang tempat lama — dan daftar yang salah tempat tampak
    /// sama normalnya dengan yang benar. Waktu juga dihitung: bintang bergerak
    /// ~15°/jam, jadi daftar yang dibiarkan sepuluh menit meleset ~2,5° dan
    /// bisa menawarkan bintang yang sudah terbenam.
    public var isReferenceListStale: Bool {
        isReferenceListStale(asOf: Date())
    }

    /// Varian yang bisa diuji: kebasian dihitung terhadap `now` yang diberikan,
    /// bukan jam dinding, supaya uji tidak bergantung pada kecepatan eksekusi.
    public func isReferenceListStale(asOf now: Date) -> Bool {
        if referenceObserver != controller.observer { return true }
        guard let referenceDate else { return true }
        return now.timeIntervalSince(referenceDate) > referenceMaxAge
    }

    /// Langkah yang dilaporkan saat sensor mati.
    ///
    /// Dipakai bersama oleh kedua jalan masuk supaya pesannya sama: yang
    /// dicatat kalibrasi harus arah tunjuk **sekarang**, dan saat sensor mati
    /// tidak ada arah sekarang.
    private var sensorUnavailableStep: CalibrationSessionStep {
        CalibrationSessionStep(flow: flow.currentUpdate,
                               selectedTarget: nil,
                               applied: false,
                               message: CalibrationText.sensorUnavailableMessage)
    }

    /// Catat satu acuan yang dipilih pengguna dari daftar, memakai arah tunjuk
    /// **mentah** yang sedang ada di controller.
    ///
    /// Sengaja tidak menerima arah dari pemanggil: yang harus dicatat adalah
    /// arah **sebelum** koreksi. Kalau arah yang sudah terkalibrasi ikut
    /// dicatat saat kalibrasi ulang, offset lama akan terhitung dua kali dan
    /// kesalahannya justru terlihat seperti kalibrasi yang bagus.
    ///
    /// Sensor harus benar-benar hidup. Saat sensor mati, `rawPointing` yang
    /// tersisa di cuplikan adalah **nilai terakhir sebelum sensor hilang** —
    /// nilainya tetap terisi, jadi tanpa penjagaan ini kalibrasi akan memakai
    /// arah yang sudah tidak berlaku sebagai pengukuran, lalu memasang offset
    /// yang salah. Kesalahannya tersembunyi di balik sebaran yang terlihat
    /// bagus, dan seluruh pointing sesudahnya ikut salah tanpa terlihat.
    @discardableResult
    public func capture(objectID: String, date: Date = Date()) -> CalibrationSessionStep {
        guard controller.snapshot.hasSensor else { return sensorUnavailableStep }
        // Penjagaan horizon harus menilai ketinggian pada saat arah dicatat,
        // bukan saat tombol ditekan — pakai waktu feed terakhir bila ada.
        return capture(objectID: objectID,
                        measured: controller.snapshot.rawPointing,
                        date: controller.lastFeedTimestamp ?? date)
    }

    /// Catat satu acuan yang dipilih pengguna dari daftar.
    ///
    /// - Parameter measured: arah tunjuk **mentah** (sebelum kalibrasi) saat
    ///   tombol ditekan. `nil` berarti sensor belum memberi arah — jangan
    ///   mencatat apa pun.
    @discardableResult
    public func capture(objectID: String,
                        measured: HorizontalCoord?,
                        date: Date = Date()) -> CalibrationSessionStep {
        guard let measured else {
            return CalibrationSessionStep(flow: flow.currentUpdate,
                                          selectedTarget: nil,
                                          applied: false,
                                          message: CalibrationText.noPointingMessage)
        }
        // Kebenaran diambil dari katalog, bukan dari apa yang ditunjuk
        // pengguna. Dua kegagalan berbeda harus dijaga terpisah: objek tak
        // dikenal (arah tak bisa dihitung sama sekali) dan objek yang memang
        // sudah di bawah cakrawala. Yang kedua berbahaya: arahnya tetap bisa
        // dihitung, tapi memakainya sebagai acuan hanya menghasilkan sampel
        // hantu — pengguna menunjuk ke langit kosong, dan offset kalibrasi
        // terbalik tanpa terlihat. Daftar acuan memang menyaring horizon,
        // tapi daftar bisa basi (waktu), jadi penjagaan ini harus ada di sini,
        // di jalur pencatatan, bukan hanya di daftar.
        guard let truth = controller.resolver.horizontal(ofObjectID: objectID,
                                                        observer: controller.observer,
                                                        date: date) else {
            return CalibrationSessionStep(flow: flow.currentUpdate,
                                          selectedTarget: nil,
                                          applied: false,
                                          message: CalibrationText.directionUncomputableMessage(objectID: objectID))
        }
        guard truth.altitudeDeg > 0 else {
            return CalibrationSessionStep(flow: flow.currentUpdate,
                                          selectedTarget: nil,
                                          applied: false,
                                          message: CalibrationText.belowHorizonMessage(objectID: objectID))
        }
        guard let update = flow.add(objectID: objectID,
                                    measured: measured,
                                    resolver: controller.resolver,
                                    observer: controller.observer,
                                    date: date) else {
            return CalibrationSessionStep(flow: flow.currentUpdate,
                                          selectedTarget: nil,
                                          applied: false,
                                          message: CalibrationText.directionUncomputableMessage(objectID: objectID))
        }
        let target = target(forObjectID: objectID, date: date)
        return CalibrationSessionStep(flow: update,
                                      selectedTarget: target,
                                      applied: false,
                                      message: update.message)
    }

    /// Target lengkap untuk sebuah id, dihitung pada waktu yang diminta.
    ///
    /// Sengaja dihitung ulang, bukan diambil dari `referenceTargets`: daftar itu
    /// sudah disaring horizon pada waktu lain, dan `captureNearest` bisa memilih
    /// objek di luar daftar acuan. Memakai daftar itu akan membuat langkah yang
    /// berhasil dilaporkan sebagai `selectedTarget == nil` — laporan yang
    /// berlawanan dengan kenyataan bahwa sampelnya benar-benar tercatat.
    private func target(forObjectID id: String, date: Date) -> PointingTarget? {
        controller.resolver
            .availableTargets(observer: controller.observer,
                              date: date,
                              aboveHorizonOnly: false)
            .first { $0.id == id }
    }

    /// Catat acuan dari arah tunjuk **sekarang**, dengan mencocokkannya ke
    /// target terdekat.
    ///
    /// Sengaja memakai arah mentah yang sedang ada di controller, bukan arah
    /// yang dikirim pemanggil: yang dicatat harus arah **sebelum** koreksi.
    /// Sensor harus hidup — lihat `capture(objectID:date:)` untuk alasannya.
    @discardableResult
    public func captureNearest(date: Date = Date()) -> CalibrationSessionStep {
        guard controller.snapshot.hasSensor else { return sensorUnavailableStep }
        // Sama dengan `capture(objectID:)`: penjagaan horizon menilai ketinggian
        // pada saat arah dicatat, bukan saat tombol ditekan.
        return captureNearest(measured: controller.snapshot.rawPointing,
                              date: controller.lastFeedTimestamp ?? date)
    }

    /// Catat acuan dari arah tunjuk sekarang, dengan mencocokkannya ke target
    /// terdekat.
    ///
    /// Sengaja **gagal** kalau ada dua target yang nyaris sama dekatnya, atau
    /// kalau tidak ada target dalam radius 25°. Kalau di sini kita menebak,
    /// kalibrasi akan mengoreksi ke arah yang keliru dan kesalahannya tersembunyi
    /// di balik angka sebaran yang terlihat bagus.
    @discardableResult
    public func captureNearest(measured: HorizontalCoord?,
                               date: Date = Date()) -> CalibrationSessionStep {
        guard let measured else {
            return CalibrationSessionStep(flow: flow.currentUpdate,
                                          selectedTarget: nil,
                                          applied: false,
                                          message: CalibrationText.noPointingMessage)
        }
        guard let target = controller.resolver.nearestTarget(to: measured,
                                                            observer: controller.observer,
                                                            date: date) else {
            return CalibrationSessionStep(flow: flow.currentUpdate,
                                          selectedTarget: nil,
                                          applied: false,
                                          message: CalibrationText.noNearbyStarMessage)
        }
        return capture(objectID: target.id, measured: measured, date: date)
    }

    /// Buang acuan terakhir.
    @discardableResult
    public func removeLast() -> CalibrationSessionStep {
        let update = flow.removeLast()
        return CalibrationSessionStep(flow: update, selectedTarget: nil,
                                      applied: false, message: update.message)
    }

    /// Pasang kalibrasi ke controller — hanya bila sebarannya sudah cukup sempit.
    ///
    /// - Returns: `nil` bila belum siap; kalau tidak, kalibrasi yang dipasang.
    @discardableResult
    public func applyIfReady() -> PointingCalibration? {
        guard let calibration = flow.applicableCalibration else { return nil }
        controller.apply(calibration: calibration)
        flow.markApplied()
        return calibration
    }

    /// Mulai ulang dari nol.
    public func reset() {
        flow.reset()
        controller.apply(calibration: .none)
    }

    /// Kebijakan keyakinan yang disarankan dari kalibrasi ini, bila terukur.
    public var suggestedConfidencePolicy: ConfidencePolicy? {
        flow.calibration?.confidencePolicy()
    }
}
