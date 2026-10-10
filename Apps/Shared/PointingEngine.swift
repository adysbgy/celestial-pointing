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
    /// Putusan GoTo terakhir yang dihitung, bila ada jawaban.
    ///
    /// **Kenapa disimpan di sini, bukan dihitung di `body`.** Aturan keras PRD
    /// "POINT → OBJECT ID → SAFE GOTO" sudah dihitung `SlewPlanner` sejak FASE 3,
    /// tetapi `PointingController.slewDecision(date:)` nol konsumen — jadi
    /// penolakan karena `sunProximity` (melindungi alat & mata) terlihat persis
    /// sama dengan penolakan karena `lowConfidence` (soal ketelitian): tidak
    /// terlihat sama sekali.
    ///
    /// Perhitungannya butuh efemeris (arah target), jadi ia mengikuti
    /// `skyContext` dan memakai penjagaan waktu yang sama — `body` dievaluasi
    /// ulang pada tiap sampel sensor 20 Hz, dan memanggil efemeris di sana
    /// berarti 20× per detik hanya untuk menggambar satu baris peringatan.
    @Published public private(set) var slewVerdict: SlewDecision?
    /// Kedatangan kunci **baru** — sinyal bagi UI untuk merayakan lock.
    ///
    /// Bukan `state == .lock`, dan bukan `lockCount`. Keduanya salah: yang
    /// pertama menyalakan animasi terus-menerus selama terkunci (cuplikan
    /// ditulis ulang 20 kali per detik), dan keduanya bisa merayakan **objek
    /// sisa** — jawaban dari pandangan sebelumnya yang sengaja
    /// dipertahankan mesin keadaan. Aturannya ada di `LockArrivalGate`
    /// (teruji di Linux); di sini hanya meneruskan.
    @Published public private(set) var lockArrival: LockArrival?
    /// Jumlah sampel sensor yang sudah diproses.
    @Published public private(set) var sampleCount = 0

    /// Gerbang kedatangan kunci.
    ///
    /// **Ada karena `snapshot` ditulis di enam tempat.** Setiap penulisan itu
    /// mengubah layar, jadi setiap penulisan itu juga harus memperbarui
    /// pertanyaan "sudah ada kabar baru?". Kalau aturan ini hidup di view
    /// sebagai `onChange`, enam pemanggil harus menyalinnya sendiri — dan itu
    /// persis cara aturan yang sama mulai berbeda pendapat antar tempat.
    /// `setSensorAvailable` dan `stop` bahkan tidak lewat `ingest`, jadi
    /// `onChange` di view tidak akan pernah melihat perubahan mereka.
    private var arrivalGate = LockArrivalGate()

    public let controller: PointingController
    /// Cara menyuarakan peristiwa haptic. `nil` = tidak ada haptic (iPhone).
    public var haptics: (([HapticEvent]) -> Void)?
    /// Cara menyuarakan **bunyi** opsional saat kejadian tertentu (mis. kunci).
    /// `nil` = tidak ada bunyi. Mirror `haptics`: keduanya dijaga dari satu
    /// jalur `ingest`, dan keduanya hanya memetakan peristiwa yang sudah
    /// dipilih engine — UI tidak pernah memilih peristiwa mana yang berbunyi.
    public var audioCue: (([HapticEvent]) -> Void)?

    /// Cara meminta complication (WidgetKit) membaca ulang ringkasan.
    /// `nil` = tidak ada complication (iPhone).
    ///
    /// **Kenapa disuntikkan, bukan dipanggil langsung.** `WidgetCenter` hanya
    /// ada di Apple platform, dan kelas ini diuji di Linux — persis alasan
    /// `haptics` juga berupa closure. Di sini alasan itu lebih keras lagi:
    /// menulis berkas snapshot **tidak** membuat watchOS menggambar ulang apa
    /// pun. Complication memakai `Timeline(entries:policy:.never)` — satu entri
    /// yang berlaku sampai ada yang memintanya berhenti — jadi tanpa panggilan
    /// ini ia membaca ringkasan sekali lalu membeku di objek pertama selamanya.
    /// Berkasnya selalu benar; layarnya yang tidak pernah menyegar.
    public var complicationReload: (() -> Void)?

    public init(location: ObserverLocation = .fallback,
                config: PointingControllerConfig = PointingControllerConfig()) {
        self.location = location
        self.controller = EngineFactory.makeController(location: location, config: config)
        self.snapshot = controller.snapshot
    }

    /// Pasang kalibrasi (dari `CalibrationSession`).
    public func apply(calibration: PointingCalibration) {
        controller.apply(calibration: calibration)
        publish(controller.snapshot)
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
        publish(controller.snapshot)
        if changed {
            // Objek itu dikunci dengan ambang lama; ambangnya sudah tidak
            // berlaku, jadi jangan disimpan sebagai jawaban terakhir.
            lastLockedObject = nil
        }
        return changed
    }

    /// Pasang kualitas langit (ADR-012). Jawaban lama dibatalkan bila
    /// penyaringnya berubah — sama seperti `setConfidencePolicy(_:)`.
    public func setSkyQuality(_ quality: SkyQuality) {
        if controller.setVisibilityPolicy(quality.visibilityPolicy) {
            lastLockedObject = nil
        }
        publish(controller.snapshot)
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
        publish(controller.snapshot)
        lastLockedObject = nil
        // Konteks langit (Matahari/Bulan) dihitung untuk **tempat**, jadi
        // konteks tempat lama tidak berlaku di tempat baru. Perhitungan ulang
        // dipaksa: penjagaan waktu di `refreshSkyContext` ada untuk membatasi
        // pemanggilan 20 Hz dari sampel sensor, bukan untuk menahan perubahan
        // lokasi.
        skyContextAt = nil
        refreshSkyContext()
        // Putusan GoTo dihitung untuk **langit di tempat itu**: arah Matahari
        // dan ketinggian target keduanya bergeser bersama lokasi. Tanda tangan
        // (keadaan, objek) tidak menangkap itu — objek yang sama di langit baru
        // tetap bertanda tangan sama — jadi gerbangnya direset supaya putusan
        // lama tidak bertahan di tempat baru.
        slewVerdictGate.reset()
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
        sampleCount += 1
        publish(update.snapshot)
        if !update.haptics.isEmpty { haptics?(update.haptics) }
        if !update.haptics.isEmpty { audioCue?(update.haptics) }
        if update.snapshot.state == .lock {
            // `answeredObject` — sama dengan yang dipakai pesan, riwayat, dan
            // gerbang kedatangan kunci. Memakai satu predikat yang sama
            // berarti "objek terakhir yang terkunci" tidak bisa diam-diam
            // menjadi objek yang dipertahankan mesin keadaan kalau aturan
            // `lock` berubah.
            lastLockedObject = update.snapshot.answeredObject
        }
        refreshSkyContext(at: date)
        onIngest?(update.snapshot)
    }

    /// Dipanggil setelah setiap `ingest`, dari sumber mana pun (sensor atau
    /// pose debug). Laporan keadaan ke iPhone menggantung di sini, bukan di
    /// `MotionLogger`, supaya semua jalur masuk ikut terlapor.
    public var onIngest: ((PointingSnapshot) -> Void)?

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
        // Arah fase dihitung **di sini**, sekali per perhitungan konteks —
        // bukan di `body` tiap render. `body` dievaluasi ulang pada setiap
        // sampel sensor, jadi menghitungnya di sana berarti memanggil efemeris
        // Matahari + Bulan 20× per detik hanya untuk menggambar satu sabit.
        // Disimpan bersama konteks supaya gambar dan angka "Fase Bulan" pada
        // layar Ketelitian berasal dari sampel yang sama.
        moonIsWaxing = controller.resolver.isMoonWaxing(at: date)
        // Sudut sisi terang juga dihitung di sini, dengan alasan yang sama:
        // ia butuh dua efemeris (Bulan dan Matahari), jadi menghitungnya di
        // `body` berarti 20x per detik. Bedanya dengan `isWaxing`: sudut ini
        // butuh **lokasi pengamat**, karena arah sabit di layar bergantung
        // lintang -- itulah cacat yang diperbaiki siklus ini.
        moonBrightLimbAngle = controller.resolver.moonBrightLimbAngle(
            at: date, observer: location.observer)
        // Fase planet dalam (Venus/Merkurius) juga di sini, dengan alasan
        // yang sama persis: efemeris tidak boleh dipanggil dari `body`.
        // Disimpan sebagai kamus kecil supaya tidak perlu lima properti
        // terpisah — hanya planet yang **berfase** yang pernah masuk.
        //
        // Sudut sisi terangnya dihitung **berpasangan** dengan fraksinya.
        // Kalau keduanya datang dari waktu yang berbeda, sabit Venus bisa
        // tergambar dengan lebar dari satu sampel dan arah dari sampel lain —
        // gambar yang tidak cocok dengan langit mana pun.
        var phases: [CelestialVisual.Planet: Double] = [:]
        var limbAngles: [CelestialVisual.Planet: Double] = [:]
        for planet in CelestialVisual.Planet.allCases where planet.showsPhase {
            if let fraction = controller.resolver.planetIlluminationFraction(
                for: planet, at: date) {
                phases[planet] = fraction
            }
            if let angle = controller.resolver.planetBrightLimbAngle(
                for: planet, at: date, observer: location.observer) {
                limbAngles[planet] = angle
            }
            // Arah membesar/mengecil dihitung **berpasangan** dengan fraksinya,
            // dan dari sampel efemeris yang sama. Tanpa arah, `phaseGeometry`
            // mengembalikan `nil` dan seluruh jalur fase planet dalam mati:
            // Venus tampil sebagai bola penuh di setiap keadaan, termasuk saat
            // iluminasinya baru saja dihitung 2%. Gambar itu menyatakan
            // kebalikan dari apa yang sedang dihitung engine.
            if let waxing = controller.resolver.isPlanetWaxing(planet, at: date) {
                planetWaxing[planet] = waxing
            }
        }
        planetPhases = phases
        planetBrightLimbAngles = limbAngles
    }

    /// Arah fase Bulan hasil perhitungan terakhir.
    ///
    /// `nil` berarti "tidak diketahui" — UI lalu menggambar piringan **tanpa
    /// fase**, bukan sabit yang memilih satu sisi.
    private var moonIsWaxing: Bool?

    /// Sudut sisi terang Bulan hasil perhitungan terakhir, radian.
    ///
    /// Terpisah dari `moonIsWaxing`, bukan menggantikannya: `isWaxing` tetap
    /// dipakai sebagai penentu sisi saat sudutnya tidak tersedia, dan
    /// keduanya bisa berbeda ketersediaannya (sudut butuh lokasi pengamat,
    /// `isWaxing` tidak).
    private var moonBrightLimbAngle: Double?

    /// Fraksi iluminasi planet dalam hasil perhitungan terakhir.
    ///
    /// Kamus, bukan lima properti: hanya planet yang **berfase**
    /// (`Planet.showsPhase`) yang bisa masuk, dan ketiadaannya di sini berarti
    /// "tidak diketahui" — sama artinya dengan `nil` pada properti lain.
    /// Menyimpannya sebagai satu nilai berarti menambah planet berfase di
    /// masa depan tidak perlu menyentuh berkas ini lagi.
    private var planetPhases: [CelestialVisual.Planet: Double] = [:]

    /// Arah fase planet dalam (membesar/mengecil) hasil perhitungan terakhir.
    ///
    /// Sejajar dengan `planetPhases`, dan diisi dari sampel efemeris yang sama.
    /// **Kenapa ia harus ada di sini, bukan diturunkan di `body`.** `isWaxing`
    /// menentukan **sisi piringan mana yang menyala** pada gambar dasar,
    /// sedangkan `planetBrightLimbAngles` menentukan **ke mana** gambar itu
    /// diputar. Dua hal yang berbeda, dan `phaseGeometry` menolak menggambar
    /// tanpa yang pertama — jadi menyimpulkan arah dari sudutnya bukan
    /// penyederhanaan, melainkan jalan yang mematikan seluruh fase planet.
    private var planetWaxing: [CelestialVisual.Planet: Bool] = [:]

    /// Sudut sisi terang planet dalam hasil perhitungan terakhir, radian.
    ///
    /// Sejajar dengan `planetPhases`, dan dihitung dari sampel efemeris yang
    /// sama. Ketidakcocokan keduanya menghasilkan sabit dengan lebar dan arah
    /// dari dua menit berbeda — karena itu keduanya selalu diisi bersamaan.
    private var planetBrightLimbAngles: [CelestialVisual.Planet: Double] = [:]

    /// Jarak waktu minimum antar perhitungan konteks langit (detik).
    static let skyContextInterval: TimeInterval = 30

    private var skyContextAt: Date?

    /// Tanda tangan snapshot complication terakhir yang ditulis.

    /// `publish` dipanggil 20×/dtk, tapi complication hanya peduli saat
    /// **keadaan atau objek berubah** — menulis berkas 20×/dtk cuma membuang
    /// baterai & memicu reload timeline yang tidak perlu. Tanda tangan ini
    /// membatasi tulis ke transisi sungguhan (kunci baru, berpindah objek,
    /// kembali ke "mencari").
    private var lastComplicationSignature: String?

    /// Sensor hilang / tersedia.
    public func setSensorAvailable(_ available: Bool) {
        sensorNote = available ? nil : SensorStatusText.motionUnavailable
        controller.setSensorAvailable(available)
        publish(controller.snapshot)
    }

    // MARK: - Satu-satunya jalan menulis snapshot

    /// Tulis cuplikan ke UI sekaligus memperbarui gerbang kedatangan kunci.
    ///
    /// **Kenapa keduanya harus di satu tempat.** `snapshot` adalah satu-satunya
    /// sumber yang dibaca semua layar, dan ia ditulis dari enam jalur berbeda.
    /// Kalau penulisan cuplikan dan pencatatan "kabar baru" dipisahkan, satu
    /// dari keduanya bisa terlewat — dan gejalanya tidak terlihat di layar:
    /// layar tetap menampilkan keadaan yang benar, hanya tanpa tanda arrival
    /// yang baru (atau dengan tanda yang salah). Kalau aturannya diduplikasi
    /// di tiap pemanggil, aturan yang sama mulai berbeda pendapat enam kali.
    ///
    /// Karena itu semua penulisan snapshot **wajib** lewat sini. Kalau
    /// `snapshot = ...` muncul lagi di berkas ini, itu bug.
    private func publish(_ value: PointingSnapshot) {
        snapshot = value
        lockArrival = arrivalGate.update(with: value)
        recordComplicationIfChanged()
        // Putusan GoTo ikut diperbarui di sini — **satu tempat**, bersama
        // snapshot yang ia jelaskan.
        //
        // **Kenapa di `publish`, bukan di `ingest`.** Putusan ini adalah
        // penjelasan atas sebuah jawaban, jadi ia harus berubah tepat saat
        // jawabannya berubah — dan jawaban berubah lewat enam jalur yang
        // menulis snapshot, bukan hanya lewat sampel sensor. Kalau ia dipasang
        // di `ingest` saja, `stop()` dan `setSensorAvailable` akan
        // meninggalkan peringatan atas benda yang sudah tidak ditunjuk lagi:
        // layar menampilkan "Tidak ada objek yang bisa diarahkan" di sebelah
        // keadaan "Sensor mati", dan tidak ada yang terlihat keliru.
        //
        // Peringatan keselamatan yang tertinggal bukan sekadar terlambat — ia
        // **salah**. Karena itu ia tidak boleh punya jalur hidup sendiri di
        // luar satu-satunya jalan tulis snapshot.
        refreshSlewVerdict(at: Date())
    }

    /// Gerbang penyegaran putusan GoTo.
    ///
    /// **Kenapa gerbang, bukan sekadar tanda tangan.** Perhitungannya butuh
    /// efemeris (arah target), jadi ia tidak boleh jalan di `body` — yang
    /// dievaluasi 20 kali per detik. Versi pertama membatasi dengan tanda tangan
    /// (keadaan, objek) saja, dan itu **membekukan** putusan selama pengguna
    /// menahan tunjukan: geometri Matahari & objek terus bergerak, tapi tanda
    /// tangannya tidak. Objek yang terkunci di 30.2° dari Matahari bisa
    /// melintasi ambang 30° tanpa satu pun perhitungan ulang, sehingga layar
    /// terus berkata "aman" atas langit yang sudah tidak ada.
    ///
    /// Gerbang ini menambahkan **umur** di samping tanda tangan, jadi putusan
    /// tidak bisa hidup lebih lama dari 30 detik — dan alasannya lengkap ada di
    /// `SlewVerdictRefreshGate` (teruji di Linux). Aturannya tinggal di sana
    /// supaya batas keterlambatannya bisa diuji tanpa jam sungguhan.
    private var slewVerdictGate = SlewVerdictRefreshGate()

    /// Hitung ulang putusan GoTo bila subjeknya berubah atau umurnya habis.
    private func refreshSlewVerdict(at date: Date) {
        // `answeredObject` — sama dengan yang dipakai pesan, riwayat, dan
        // gerbang kedatangan kunci. Memakai satu predikat yang sama berarti
        // putusan ini tidak bisa diam-diam menjadi putusan atas objek yang
        // dipertahankan mesin keadaan padahal keadaannya sudah tidak punya
        // jawaban.
        let objectID = snapshot.answeredObject?.id ?? "-"
        let signature = "\(snapshot.state.rawValue)|\(objectID)"
        guard slewVerdictGate.needsRecompute(signature: signature, at: date) else { return }
        slewVerdict = controller.slewDecision(date: date)
        // Dicatat **setelah** putusan benar-benar dihitung: kalau dicatat lebih
        // dulu, umur putusan lama akan diperpanjang tanpa isinya diperbarui.
        slewVerdictGate.record(signature: signature, at: date)
    }

    /// Tulis snapshot complication saat keadaan/objek benar-benar berubah.

    /// Dipanggil dari `publish` (satu-satunya jalan tulis snapshot). Hanya
    /// menulis bila tanda tangannya beda dari tulisan terakhir — jadi complication
    /// mendapat entri timeline baru tepat saat sesuatu berubah, bukan 20×/dtk.
    /// Complication membaca lewat `ComplicationStore.shared` (proses terpisah).
    private func recordComplicationIfChanged() {
        let digest = ComplicationDigest(snapshot: snapshot, lastLocked: lastLockedObject)
        // Bandingkan dengan tanda tangan dari digest yang **sudah dihitung**,
        // bukan menghitung ulang: `displayedObject`/`confirmsIdentity` cukup
        // dipanggil sekali untuk membentuk digest. Yang menentukan "perubahan"
        // hanyalah (keadaan, nama objek, konfirmasi).
        let signature = "\(digest.stateRaw)|\(digest.objectName ?? "")|\(digest.isConfirmed)"
        guard signature != lastComplicationSignature else { return }
        lastComplicationSignature = signature
        ComplicationStore.shared.record(digest)
        // Menulis berkas tidak membuat watchOS menggambar ulang complication:
        // timeline-nya `.never`, jadi ia membaca sekali lalu membeku. Panggilan
        // ini yang memintanya membaca ulang. Sengaja di dalam penjagaan
        // `signature` — reload adalah kerja sistem, dan memanggilnya 20×/detik
        // untuk ringkasan yang sama hanya membakar baterai.
        complicationReload?()
    }

    // MARK: - Alur

    /// Alur dihentikan (layar pergi, pergelangan diturunkan).
    public func stop() {
        controller.stop()
        publish(controller.snapshot)
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

    /// Apakah gambar boleh **mengklaim identitas** objek yang ditampilkan.
    ///
    /// **Kenapa ini bukan sekadar `!isDisplayingStaleObject`.** `isStale`
    /// dihitung dari `hasAnswer`, dan `hasAnswer` mencakup `.uncertain` —
    /// keadaan tempat engine menyatakan diri kurang yakin. Menurunkan
    /// `isConfirmed` dari `!isStale` meloloskan seluruh ciri pengenal (cincin
    /// Saturnus, pita Jupiter) tepat saat badge di sebelahnya bertuliskan
    /// "Ragu": gambar jadi lebih yakin daripada teksnya, dan mata membaca
    /// gambar lebih dulu daripada badge.
    ///
    /// Aturannya sendiri ada di `PointingKit`
    /// (`PointingSnapshot.confirmsIdentity(lastLocked:)`) supaya teruji di
    /// Linux bersama janji tampilan lain. Di sini hanya meneruskan.
    public var confirmsDisplayedIdentity: Bool {
        snapshot.confirmsIdentity(lastLocked: lastLockedObject)
    }

    /// Apakah nama yang ditampilkan **wajib** membawa penanda ragu.
    ///
    /// **Kenapa surface keempat ini butuh aturan sendiri.** Tiga permukaan
    /// lain sudah menandai ragu (complication lewat `Subline`, jam dan iPhone
    /// lewat badge keyakinan). Layar redup tidak punya ruang untuk badge,
    /// sehingga penandanya harus berupa frasa yang menempel pada nama —
    /// kalau tidak, nama kandidat tampil sebagai huruf terbesar di layar dan
    /// terbaca sebagai temuan, bukan kandidat.
    ///
    /// Aturannya sendiri ada di `PointingKit`
    /// (`PointingSnapshot.carriesUncertaintyMarker(lastLocked:)`) supaya
    /// ambangnya bisa diuji di Linux, bukan jadi syarat `if` di view yang
    /// tidak pernah dieksekusi di sini.
    public var carriesUncertaintyMarker: Bool {
        snapshot.carriesUncertaintyMarker(lastLocked: lastLockedObject)
    }

    /// Arah tunjuk terkalibrasi, untuk ditampilkan sebagai angka.
    ///
    /// `nil` saat sensor tidak hidup: angka yang tersisa di cuplikan adalah
    /// arah **terakhir sebelum sensor hilang**, dan menampilkannya tanpa
    /// penanda membuat bacaan lama tampak seperti pengukuran sekarang —
    /// persis yang dilarang PRD. Saat sensor hidup, ini arah yang berlaku.
    ///
    /// Aturannya ada di `PointingKit` (`PointingSnapshot.reportedPointing`)
    /// supaya jalur ini dan pesan ke iPhone tidak bisa berbeda pendapat.
    public var pointing: HorizontalCoord? {
        snapshot.reportedPointing
    }

    /// Jawaban engine yang berlaku untuk arah tunjuk **sekarang**.
    ///
    /// Dipakai Experiment 1 saat merekam. Lihat `PointingController.answeredIntent`
    /// untuk alasan mengapa `snapshot.intent` saja tidak cukup.
    public var answeredIntent: CelestialIntent? { controller.answeredIntent }

    /// Model visual prosedural untuk objek yang sedang ditampilkan.
    ///
    /// **Kenapa fraksi fase diambil dari `skyContext`, bukan dari
    /// `moonIlluminationFraction(at:)` langsung.** Konteks punya cache 30
    /// detik yang sengaja menjaga efemeris tetap murah, sementara pemanggilan
    /// langsung menghitung ulang tiap render — dan `body` dievaluasi ulang
    /// pada setiap sampel sensor. Yang lebih penting: `skyContext` adalah
    /// sumber yang **sama** dengan angka "Fase Bulan" yang tampil di layar
    /// Ketelitian. Gambar dan angka harus berasal dari sampel yang sama,
    /// kalau tidak layar bisa menunjukkan sabit 80% di sebelah teks 40%.
    ///
    /// `nil` bila tidak ada objek yang ditampilkan — **bukan** gambar
    /// generik. Visual tanpa nama akan menampilkan benda yang tidak
    /// ditentukan engine, dan itu klaim yang dilarang PRD.
    ///
    /// Fraksi & arah fase `nil` untuk benda selain Bulan: meneruskannya ke
    /// planet lain akan menggambar fase Bulan pada planet.
    ///
    /// **Fase planet dalam diteruskan terpisah.** Venus dan Merkurius berfase
    /// sungguhan, dan fraksinya datang dari `planetPhases` — bukan dari
    /// `moonIlluminationFraction`. Model yang memutuskan planet mana yang
    /// boleh memakainya (`Planet.showsPhase`), jadi planet luar tidak akan
    /// pernah mendapat sabit walau kamusnya keliru.
    public var visualForDisplayedObject: CelestialVisual? {
        guard let object = displayedObject else { return nil }
        let isMoon = object.kind == .moon
        let fraction = isMoon ? skyContext?.moonIlluminationFraction : nil
        // Arah fase (waxing/waning) diambil untuk **setiap benda yang
        // berfase**, bukan hanya Bulan.
        //
        // **Kenapa baris ini dulunya `isMoon ? moonIsWaxing : nil`, dan itu
        // cacat.** `phaseGeometry(waxing:)` mengembalikan `nil` bila arahnya
        // `nil`, jadi meneruskan `nil` untuk planet membuat seluruh jalur fase
        // planet dalam mati: `planetPhases` dan `planetBrightLimbAngles`
        // dihitung 30 detik sekali, lalu tidak pernah dipakai gambar apa pun.
        // Venus tampil sebagai bola penuh di setiap keadaan — termasuk saat
        // engine baru saja menghitung iluminasinya 2 persen. Gambar itu
        // menyatakan kebalikan dari apa yang dihitung engine, dan tidak ada
        // satu teks pun di layar yang bisa dibaca pengguna untuk memeriksanya.
        //
        // Tidak ada uji yang menangkapnya karena uji menguji **rumus**-nya
        // (`testInnerPlanetDrawsAPhaseFromItsOwnFraction`), bukan
        // **pengawat**-nya. Uji yang ditambahkan siklus ini mengunci
        // pengawatnya.
        // `planet` dideklarasikan di sini karena `waxing` di bawah butuh
        // menanyakannya; menunda deklarasinya ke bawah akan membaca variabel
        // lokal sebelum deklarasinya (galat kompilasi).
        let planet = CelestialVisual.Planet(objectID: object.id)
        let waxing = isMoon ? moonIsWaxing : planet.flatMap { planetWaxing[$0] }
        // Sudut sisi terang: hanya untuk Bulan, dan nil bila tidak diketahui.
        // Saat nil, model tidak berputar -- lebih baik sabit yang belum
        // berorientasi daripada sabit yang salah arah.
        let limbAngle = isMoon ? moonBrightLimbAngle : nil
        let planetPhase = planet.flatMap { planetPhases[$0] }
        // Sudut sisi terang planet: hanya planet berfase yang punya, dan
        // `nil` berarti gambar tidak diputar -- bukan diputar ke sudut
        // karangan. Bulan tetap memakai sudutnya sendiri; keduanya tidak
        // pernah terisi bersamaan karena `object.kind` hanya satu.
        let planetLimbAngle = planet.flatMap { planetBrightLimbAngles[$0] }
        return CelestialVisual(object: object,
                              moonIlluminationFraction: fraction,
                              isWaxing: waxing,
                              brightLimbAngleRadians: isMoon ? limbAngle : planetLimbAngle,
                              planetIlluminationFraction: planetPhase)
    }
}
