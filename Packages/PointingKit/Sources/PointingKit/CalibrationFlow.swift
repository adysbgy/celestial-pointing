import Foundation
import CelestialEngine

/// Satu titik acuan saat kalibrasi: apa yang **ditunjuk** pengguna, dan apa
/// yang sebenarnya ada di sana menurut katalog.
///
/// `trueDirection` sengaja dihitung dari katalog, bukan dari mata pengguna —
/// supaya yang terukur adalah galat sensor, bukan galat mata.
public struct CalibrationSample: Codable, Equatable, Sendable {
    /// Objek yang diklaim pengguna sedang ditunjuk.
    public var objectID: String
    /// Arah tunjuk mentah saat pengguna menekan tombol.
    public var measured: HorizontalCoord
    /// Arah objek yang sebenarnya saat itu (dari katalog/efemeris).
    public var trueDirection: HorizontalCoord
    /// Waktu pengambilan.
    public var timestamp: Date
    /// Selisih sudut antara keduanya (derajat) — galat mentah titik ini.
    public var separationDeg: Double

    public init(objectID: String,
                measured: HorizontalCoord,
                trueDirection: HorizontalCoord,
                timestamp: Date) {
        self.objectID = objectID
        self.measured = measured
        self.trueDirection = trueDirection
        self.timestamp = timestamp
        self.separationDeg = SkyMath.angularSeparationHorizontalDeg(measured, trueDirection)
    }
}

/// Tahap alur kalibrasi.
public enum CalibrationPhase: String, Equatable, Sendable {
    /// Belum mulai; belum ada sampel.
    case idle
    /// Sudah ada sampel, tapi sebarannya masih terlalu lebar untuk dipercaya.
    case collecting
    /// Sebaran sisa sudah cukup sempit; kalibrasi boleh dipakai.
    case ready
    /// Kalibrasi sudah dipakai oleh controller.
    case applied
}

/// Hasil satu langkah alur kalibrasi.
public struct CalibrationUpdate: Equatable, Sendable {
    public var phase: CalibrationPhase
    /// Kalibrasi yang dihitung dari sampel saat ini (kalau ada).
    public var calibration: PointingCalibration?
    /// Sampel yang sudah terkumpul.
    public var samples: [CalibrationSample]
    /// Penjelasan singkat untuk ditampilkan ke pengguna.
    public var message: String
}

/// Alur kalibrasi berbasis beberapa titik acuan.
///
/// **Kenapa lebih dari satu titik.** PRD melarang mengasumsikan akurasi Watch.
/// Satu titik acuan hanya memberi offset yaw, tanpa cara apa pun untuk tahu
/// seberapa konsisten pengukuran itu. Dengan dua titik atau lebih,
/// `CalibrationSolver` juga melaporkan `residualSpreadDeg` — estimasi sigma
/// pointing yang nyata — dan sigma itulah yang menyetel ambang keyakinan
/// engine. Kalau sebarannya masih lebar, alur menolak menyatakan "siap".
///
/// Alur ini juga sengaja **tidak** memakai objek terbaik dari engine sebagai
/// kebenaran: kalau engine salah mengenali, kalibrasi akan ikut salah dan
/// kesalahannya tak akan pernah ketahuan. Kebenaran diambil dari id objek yang
/// dipilih pengguna.
public struct CalibrationFlow {

    /// Objek yang boleh dipakai sebagai acuan.
    ///
    /// Hanya bintang: posisinya di katalog, jadi kebenarannya tidak bergantung
    /// pada efemeris yang bisa gagal. Bulan/planet boleh ditambahkan kalau
    /// efemerisnya tersedia — tapi itu keputusan pemanggil, lewat `add(...)`.
    public var referenceObjects: [CelestialObject]

    /// Sebaran sisa maksimum (derajat, 1σ) agar kalibrasi dinyatakan siap.
    ///
    /// Bawaan 3°: masih di bawah resolusi pointing manusia dan jauh di bawah
    /// ambang HIGH engine bawaan (sigma 10°). Kalau hasil Experiment 1
    /// menunjukkan sebaran lebih lebar, angka ini yang harus diubah — bukan
    /// ambang keyakinannya, supaya kualitas kalibrasi tetap terlihat.
    public var maxResidualSpreadDeg: Double

    /// Jumlah sampel minimum sebelum kalibrasi boleh dipakai.
    public var minimumSamples: Int

    public private(set) var samples: [CalibrationSample] = []
    public private(set) var calibration: PointingCalibration?
    public private(set) var phase: CalibrationPhase = .idle

    /// Jumlah **acuan berbeda** yang sudah tercatat — bukan jumlah ketukan.
    ///
    /// **Kenapa ini bukan `samples.count`.** Sigma pointing bermakna "seberapa
    /// galat arah tunjuk kita *di langit mana pun*", dan itu hanya bisa diukur
    /// dari beberapa arah yang berbeda. Dua ketukan pada Sirius mengukur satu
    /// arah dua kali: sebarannya jadi ~1e-6 derajat yang **tidak mengukur
    /// apa pun**, tapi tetap `> 0` dan berhingga sehingga semua penjaganya
    /// meloloskannya. Akibatnya alur menyatakan "Siap" dan `confidencePolicy()`
    /// mengarang ambang keyakinan dari noise — sigma ~0 membuat
    /// `maxSeparationDeg` ~0, jadi engine tidak pernah lagi boleh menjawab HIGH.
    ///
    /// Pengulangan tidak dihapus: `samples` tetap menyimpan semuanya, `removeLast`
    /// tetap berarti "buang ketukan terakhir", dan tidak ada satu pun pengukuran
    /// yang dibuang diam-diam. Yang dihitung ulang dari bagian independen
    /// hanyalah **klaim** — readiness dan sigma.
    ///
    /// Bisa dieduplikasi tanpa mengubah urutan: hanya perlu menghitung himpunan
    /// id, jadi tidak ada biaya yang terasa di layar.
    public var distinctReferenceCount: Int {
        Set(samples.map(\.objectID)).count
    }

    /// Acuan yang sudah tercatat lebih dari sekali.
    ///
    /// Kosong berarti tidak ada pengulangan — keadaan yang biasa.
    ///
    /// Yang dikembalikan **bukan** teks: nama bintangnya dari
    /// katalog/pemanggil, dan kalimatnya lahir di `CalibrationText` supaya
    /// bisa dilokalkan dan diuji di Linux.
    ///
    /// Dipakai untuk **menjelaskan** kenapa pengulangan tidak menambah bukti,
    /// bukan untuk membuang pengukurannya.
    public var repeatedReferenceIDs: [String] {
        var counts: [String: Int] = [:]
        for sample in samples { counts[sample.objectID, default: 0] += 1 }
        // `samples` urut pencatatan, jadi urutan keluaran ikut urutan itu —
        // stabil antar peluncuran, tidak seperti urutan `Dictionary`.
        var seen = Set<String>()
        return samples.compactMap { counts[$0.objectID, default: 0] > 1 && seen.insert($0.objectID).inserted
            ? $0.objectID : nil }
    }

    /// Ketukan yang **tidak menambah** pengukuran baru.
    ///
    /// Berbeda dengan `repeatedReferenceIDs`, yang menghitung **bintang**
    /// yang diulang: yang terbuang adalah **ketukan**. Ketukan pertama pada
    /// Sirius memang menambah bukti; ketukan kedua dan ketiga tidak. Untuk
    /// tiga ketukan pada satu bintang, angkanya 2 — bukan 3, karena ikut
    /// menghitung ketukan pertama akan menyalahkan pengguna atas sesuatu
    /// yang memang benar.
    ///
    /// Hubungannya dengan dua angka lain selalu tepat:
    /// `samples.count == distinctReferenceCount + redundantTapCount`, jadi
    /// catatan di layar bisa dibaca sebagai "sebagian ketukan saya terbuang"
    /// tanpa perlu menebak.
    public var redundantTapCount: Int {
        samples.count - distinctReferenceCount
    }

    /// Catatan kecil yang tampil di bawah hitungan acuan — `nil` saat tidak
    /// ada ketukan yang terbuang.
    ///
    /// **Kenapa ini accessor, bukan view yang menghitung sendiri.** Ada dua
    /// angka hidup berdampingan di tipe ini dan keduanya `Int`: jumlah
    /// **bintang** yang diulang (`repeatedReferenceIDs.count`) dan jumlah
    /// **ketukan** yang terbuang (`redundantTapCount`). Pemanggil yang memilih
    /// sendiri punya peluang memilih yang salah, dan pilihan yang salah itu
    /// tidak terlihat: dua-duanya bilangan yang masuk akal untuk kalimat yang
    /// sama.
    ///
    /// Yang terjadi nyata: kartu menampilkan "3 acuan tercatat" lalu "1
    /// ketukan tidak menambah pengukuran" untuk tiga ketukan pada Sirius.
    /// Dua angka itu **saling meniadakan** — pengguna menghitung 3+1 dan
    /// menyimpulkan ada 4 ketukan, padahal 3 yang terjadi — dan yang terbuang
    /// sebenarnya justru 2. Pada keadaan yang paling sering terjadi (satu
    /// bintang diketuk berulang), catatan itu selalu berbunyi "1", jadi ia
    /// tidak pernah memberi informasi apa pun.
    ///
    /// `nil` alih-alih catatan bernilai nol: "0 ketukan tidak menambah
    /// pengukuran" menyatakan sesuatu yang tidak terjadi, dan lapis kedua
    /// seperti itu adalah tempat layar mulai mengarang.
    ///
    /// Syaratnya `> 0`, bukan `> 1`: ketukan **kedua** pada satu bintang
    /// sudah tidak menambah apa pun, jadi sejak itu catatan wajib ada.
    public var repetitionHint: String? {
        redundantTapCount > 0
            ? CalibrationText.redundantTapHint(repeatedTapCount: redundantTapCount)
            : nil
    }

    public init(referenceObjects: [CelestialObject] = CalibrationFlow.defaultReferences,
                maxResidualSpreadDeg: Double = 3.0,
                minimumSamples: Int = 2) {
        self.referenceObjects = referenceObjects
        self.maxResidualSpreadDeg = maxResidualSpreadDeg
        self.minimumSamples = max(2, minimumSamples)
    }

    /// Bintang acuan bawaan: terang, dan tersebar di langit.
    ///
    /// Sebaran penting: dua acuan yang berdekatan memberi yaw yang sama-sama
    /// rapuh terhadap satu kesalahan kecil. Empat acuan ini (Sirius, Vega,
    /// Arcturus, Fomalhaut) tersebar di belahan langit yang berbeda.
    public static let defaultReferences: [CelestialObject] = {
        let wanted = ["sirius", "vega", "arcturus", "fomalhaut", "capella", "altair"]
        let byID = Dictionary(uniqueKeysWithValues: Catalogue.brightStars.map { ($0.id, $0) })
        return wanted.compactMap { byID[$0] }
    }()

    /// Tambahkan satu titik acuan.
    ///
    /// - Parameters:
    ///   - objectID: id objek yang dituju pengguna.
    ///   - measured: arah tunjuk mentah saat tombol ditekan.
    ///   - resolver: dipakai untuk menghitung arah objek yang sebenarnya.
    ///   - observer: lokasi pengamat.
    ///   - date: waktu pengambilan.
    /// - Returns: `nil` bila objek tidak dikenal atau arahnya tidak bisa
    ///   dihitung — sampel yang tidak bisa diverifikasi **tidak** disimpan.
    @discardableResult
    public mutating func add(objectID: String,
                             measured: HorizontalCoord,
                             resolver: PointingResolver,
                             observer: Observer,
                             date: Date) -> CalibrationUpdate? {
        guard let truth = resolver.horizontal(ofObjectID: objectID,
                                              observer: observer,
                                              date: date) else {
            return nil
        }
        samples.append(CalibrationSample(objectID: objectID,
                                         measured: measured,
                                         trueDirection: truth,
                                         timestamp: date))
        recompute()
        return currentUpdate
    }

    /// Buang sampel terakhir (mis. pengguna salah tekan).
    @discardableResult
    public mutating func removeLast() -> CalibrationUpdate {
        if !samples.isEmpty { samples.removeLast() }
        recompute()
        return currentUpdate
    }

    /// Lupakan semuanya, mulai dari nol.
    public mutating func reset() {
        samples = []
        calibration = nil
        phase = .idle
    }

    /// Cuplikan alur saat ini.
    public var currentUpdate: CalibrationUpdate {
        CalibrationUpdate(phase: phase,
                          calibration: calibration,
                          samples: samples,
                          message: message)
    }

    /// Apakah kalibrasi sudah layak dipakai.
    public var isReady: Bool { phase == .ready || phase == .applied }

    /// Kalibrasi untuk dipakai — hanya bila sudah siap.
    ///
    /// Sengaja mengembalikan `nil` saat belum siap: memasang kalibrasi setengah
    /// matang lebih berbahaya daripada tidak mengkalibrasi sama sekali, karena
    /// offsetnya bisa membalik jawaban engine tanpa terlihat.
    public var applicableCalibration: PointingCalibration? {
        isReady ? calibration : nil
    }

    /// Tandai kalibrasi sudah dipasang ke controller.
    public mutating func markApplied() {
        if isReady { phase = .applied }
    }

    // MARK: - Bantu

    private mutating func recompute() {
        // **Klaim dihitung dari acuan BERBEDA, bukan dari jumlah ketukan.**
        // Dua sampel untuk benda yang sama mengukur satu arah dua kali, jadi
        // keduanya tidak menambah informasi apa pun tentang galat arah tunjuk
        // di langit. `independentSamples` hanya memilih satu sampel per id —
        // bukan membuang pengukurannya: semuanya tetap tersimpan, dan yang
        // pertama menang supaya hasilnya tidak bergantung pada urutan acak
        // `Dictionary`.
        let independent = independentSamples
        guard independent.count >= minimumSamples else {
            // Satu acuan tetap dihitung: satu titik **tidak** bisa memberi tahu
            // seberapa konsisten kalibrasi, jadi `residualSpreadDeg` nil dan
            // tidak ada kebijakan yang bisa lahir darinya.
            calibration = independent.count == 1
                ? CalibrationSolver.solve(measured: independent.map(\.measured),
                                          truth: independent.map(\.trueDirection))
                : nil
            phase = samples.isEmpty ? .idle : .collecting
            return
        }
        calibration = CalibrationSolver.solve(measured: independent.map(\.measured),
                                              truth: independent.map(\.trueDirection))
        guard let spread = calibration?.residualSpreadDeg else {
            phase = .collecting
            return
        }
        phase = spread <= maxResidualSpreadDeg ? .ready : .collecting
    }

    /// Satu sampel per id acuan, sesuai urutan pencatatan.
    ///
    /// "Satu per id" bukan satu per *posisi*: bila pengulangan terjadi,
    /// ketukan pertama yang dipakai karena itulah yang paling dekat dengan
    /// waktu pengguna benar-benar menunjuk ke arah itu.
    private var independentSamples: [CalibrationSample] {
        var seen = Set<String>()
        return samples.filter { seen.insert($0.objectID).inserted }
    }

    private var message: String {
        // Pengulangan didahulukan: pertanyaan "kenapa tidak bertambah?" lebih
        // berguna dijawab sebelum pengguna menyadarinya, dan kalau dijawab
        // setelah "terlalu lebar" membingungkan karena sebarannya belum
        // bermakna sama sekali.
        if let repeated = repeatedReferenceIDs.first,
           distinctReferenceCount < minimumSamples {
            return CalibrationText.repeatedReferenceMessage(
                name: name(ofObjectID: repeated),
                distinctCount: distinctReferenceCount,
                minimum: minimumSamples)
        }
        switch phase {
        case .idle:
            return CalibrationText.idleMessage
        case .collecting:
            if distinctReferenceCount < minimumSamples {
                return CalibrationText.needMoreMessage(minimum: minimumSamples,
                                                       recorded: distinctReferenceCount)
            }
            let spread = calibration?.residualSpreadDeg ?? .nan
            return CalibrationText.spreadTooWideMessage(spreadDeg: spread,
                                                        maxDeg: maxResidualSpreadDeg)
        case .ready:
            let spread = calibration?.residualSpreadDeg ?? .nan
            return CalibrationText.readyMessage(spreadDeg: spread,
                                                sampleCount: distinctReferenceCount)
        case .applied:
            return CalibrationText.appliedMessage
        }
    }

    /// Nama tampilan untuk id acuan, dari katalog acuan alur ini.
    ///
    /// Sengaja memakai `referenceObjects` dan bukan katalog seluruh aplikasi:
    /// satu nama untuk satu fakta, supaya tidak ada daftar kedua yang bisa
    /// berbeda pendapat. Id yang tidak ada di daftar itu jatuh kembali ke
    /// id-nya sendiri — lebih jujur daripada menebak nama yang salah.
    private func name(ofObjectID id: String) -> String {
        referenceObjects.first { $0.id == id }?.name ?? id
    }
}
