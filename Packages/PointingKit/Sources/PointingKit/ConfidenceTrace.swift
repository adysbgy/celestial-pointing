import Foundation
import CelestialEngine

/// Satu pengamatan keyakinan yang direkam untuk diagnostik.
///
/// Yang disimpan bukan hanya jawabannya, melainkan **variabel keputusan**nya.
/// Model keyakinan membandingkan jarak kandidat terhadap sigma pointing
/// (`maxSeparationSigma` σ), jadi grafik jarak mentah dalam derajat tidak bisa
/// dibaca: 5° bisa berarti "sangat dekat" saat sigma 10°, dan "jauh" saat sigma
/// 1°. Karena itu `ratioToSigma` ikut direkam — itulah angka yang benar-benar
/// menentukan apakah engine berani berkata yakin.
public struct ConfidenceSample: Codable, Equatable, Sendable {
    public var timestamp: Date
    /// Keadaan alur saat sampel ini diambil.
    public var state: PointingState
    /// Tingkat keyakinan yang dilaporkan engine.
    public var level: ConfidenceLevel?
    public var objectID: String?
    public var objectName: String?
    /// Jarak kandidat terbaik ke arah tunjuk (derajat).
    public var separationDeg: Double?
    /// Sigma pointing yang berlaku saat itu (derajat).
    public var sigmaDeg: Double
    /// Jarak kandidat terbaik ke tetangga terdekatnya di langit (derajat).
    /// `nil` = tidak ada kandidat lain.
    public var nearestNeighbourDeg: Double?
    /// `separationDeg / sigmaDeg` — variabel keputusan sesungguhnya.
    public var ratioToSigma: Double?
    /// `nearestNeighbourDeg / sigmaDeg` — ambang ambiguitas.
    public var neighbourRatioToSigma: Double?
    /// Apakah sampel ini berasal dari jam (bukan dari iPhone ini sendiri).
    public var fromWatch: Bool

    public init(timestamp: Date,
                state: PointingState,
                level: ConfidenceLevel?,
                objectID: String?,
                objectName: String?,
                separationDeg: Double?,
                sigmaDeg: Double,
                nearestNeighbourDeg: Double?,
                fromWatch: Bool) {
        self.timestamp = timestamp
        self.state = state
        self.level = level
        self.objectID = objectID
        self.objectName = objectName
        self.separationDeg = separationDeg
        self.sigmaDeg = sigmaDeg
        self.nearestNeighbourDeg = nearestNeighbourDeg
        self.fromWatch = fromWatch
        self.ratioToSigma = separationDeg.flatMap { sigmaDeg > 0 ? $0 / sigmaDeg : nil }
        self.neighbourRatioToSigma = nearestNeighbourDeg.flatMap { sigmaDeg > 0 ? $0 / sigmaDeg : nil }
    }
}

/// Riwayat keyakinan yang bisa digambar dan diekspor.
///
/// Kenapa ada: satu angka ("akurasi 80%") tidak bisa dipakai untuk memperbaiki
/// ambang. Yang dibutuhkan adalah **di mana** engine ragu: apakah karena
/// kandidatnya terlalu jauh (masalah kalibrasi), atau karena ada dua kandidat
/// berdekatan (masalah katalog/langit). Dua penyebab itu punya perbaikan yang
/// berbeda, dan tanpa riwayat keduanya terlihat sama.
///
/// Kelas ini tidak menyentuh SwiftUI, jadi seluruh logikanya bisa diuji di
/// Linux. Yang dilakukan `Charts` di app hanya menggambar `samples`.
public final class ConfidenceTrace {

    public private(set) var samples: [ConfidenceSample] = []
    /// Batas jumlah sampel yang disimpan di memori. Grafik tidak butuh ribuan
    /// titik, dan iPhone/Watch tidak boleh tumbuh tanpa batas.
    public var capacity: Int
    /// Apakah sampel yang diterima ikut disimpan.
    public var isRecording = true

    public init(capacity: Int = 600) {
        self.capacity = max(2, capacity)
    }

    /// Rekam satu cuplikan keadaan.
    ///
    /// **Yang direkam adalah jawaban yang berlaku sekarang, bukan objek yang
    /// dipertahankan.** `snapshot.intent` sengaja tetap terisi setelah keadaan
    /// kehilangan jawabannya (supaya layar jam tidak berkedip), jadi membacanya
    /// langsung akan menuliskan objek dan keyakinan dari arah tunjuk sebelumnya
    /// sebagai jawaban untuk arah sekarang — riwayat yang tampak normal sambil
    /// memuat false lock yang tidak pernah terjadi. Cuplikan sudah membawa
    /// predikatnya (`answeredObject`/`answeredLevel`/`answeredSeparationDeg`),
    /// jadi aturannya satu tempat saja.
    ///
    /// - Parameters:
    ///   - snapshot: cuplikan controller.
    ///   - sigmaDeg: sigma pointing yang **berlaku saat itu**. Diambil dari
    ///     kebijakan resolver, bukan dari bawaan, supaya riwayat lama tetap
    ///     terbaca setelah ambangnya diperketat.
    ///   - nearestNeighbourDeg: jarak kandidat terbaik ke tetangga terdekat.
    ///     Bila `nil`, nilai diambil dari `snapshot.nearestNeighbourDeg` —
    ///     cuplikan itulah yang membawa variabel keputusan engine, jadi
    ///     pemanggil yang tidak punya alasan khusus tidak perlu mengisinya
    ///     sendiri. Mengisinya di sini secara manual berarti ada dua tempat
    ///     yang tahu dari mana angka itu berasal.
    ///   - fromWatch: `true` bila sampel datang dari jam.
    public func record(snapshot: PointingSnapshot,
                       sigmaDeg: Double,
                       nearestNeighbourDeg: Double? = nil,
                       fromWatch: Bool = false,
                       at date: Date = Date()) {
        record(state: snapshot.state,
               level: snapshot.answeredLevel,
               objectID: snapshot.answeredObject?.id,
               objectName: snapshot.answeredObject?.name,
               separationDeg: snapshot.answeredSeparationDeg,
               sigmaDeg: sigmaDeg,
               nearestNeighbourDeg: nearestNeighbourDeg ?? snapshot.nearestNeighbourDeg,
               fromWatch: fromWatch,
               at: date)
    }

    /// Perekam inti. Semua jalur masuk lewat sini supaya aturan penyimpanan
    /// (kapasitas, `isRecording`) tidak bisa berbeda antar jalur.
    public func record(state: PointingState,
                       level: ConfidenceLevel?,
                       objectID: String?,
                       objectName: String?,
                       separationDeg: Double?,
                       sigmaDeg: Double,
                       nearestNeighbourDeg: Double? = nil,
                       fromWatch: Bool = false,
                       at date: Date = Date()) {
        guard isRecording else { return }
        samples.append(ConfidenceSample(timestamp: date,
                                        state: state,
                                        level: level,
                                        objectID: objectID,
                                        objectName: objectName,
                                        separationDeg: separationDeg,
                                        sigmaDeg: sigmaDeg,
                                        nearestNeighbourDeg: nearestNeighbourDeg,
                                        fromWatch: fromWatch))
        if samples.count > capacity { samples.removeFirst(samples.count - capacity) }
    }

    /// Rekam dari pesan yang datang dari jam.
    ///
    /// Yang bisa direkam dari sini terbatas pada apa yang dikirim jam: keadaan,
    /// objek, dan keyakinan. Jarak kandidat **tidak** ikut dikirim (jam tidak
    /// mengirim sudut pergelangan ke perangkat lain), jadi `ratioToSigma` akan
    /// kosong — dan itu ditampilkan apa adanya, bukan diisi angka karangan.
    ///
    /// Sigma diambil dari pesannya. Kalau jam tidak menyertakannya, yang dicatat
    /// adalah **nol** — bukan sigma bawaan. Nol berarti "tidak terukur", dan
    /// `ratioToSigma` sengaja kosong untuk sigma nol. Memakai bawaan akan
    /// menuliskan angka yang tidak pernah berlaku di jam ke dalam berkas
    /// ekspor, dan pembacanya tidak punya cara mengetahui itu.
    public func record(message: PointingLinkMessage) {
        guard message.kind == .pointingState, let state = message.state else { return }
        record(state: state,
               level: message.level,
               objectID: message.objectID,
               objectName: message.objectName,
               separationDeg: nil,
               sigmaDeg: message.pointingSigmaDeg ?? 0,
               fromWatch: true,
               at: message.sentAt)
    }

    public func reset() { samples = [] }

    // MARK: - Ringkasan untuk diagnostik

    /// Berapa sampel per tingkat keyakinan.
    public var levelCounts: [ConfidenceLevel: Int] {
        var counts: [ConfidenceLevel: Int] = [:]
        for sample in samples {
            guard let level = sample.level else { continue }
            counts[level, default: 0] += 1
        }
        return counts
    }

    /// Berapa sampel per keadaan alur.
    public var stateCounts: [PointingState: Int] {
        var counts: [PointingState: Int] = [:]
        for sample in samples { counts[sample.state, default: 0] += 1 }
        return counts
    }

    /// Sampel yang punya jawaban (lock/uncertain) — yang bisa dianalisis.
    public var answered: [ConfidenceSample] {
        samples.filter { $0.state.hasAnswer }
    }

    /// Kenapa engine menolak yakin, dihitung dari sampel ragu.
    ///
    /// Dua sebab dibedakan tegas karena perbaikannya berbeda:
    /// - `tooFar`: kandidat terbaik melewati `maxSeparationSigma` σ → kalibrasi
    ///   atau kualitas pointing yang perlu diperbaiki.
    /// - `ambiguous`: kandidat terbaik dekat, tapi ada tetangga dalam
    ///   `ambiguitySigma` σ → keterbatasan katalog/akurasi, bukan kesalahan.
    /// - `none`: ragu tanpa sebab yang terukur (mis. kandidat di luar kerucut).
    public enum UncertainReason: String, Equatable, Sendable, CaseIterable {
        case tooFar
        case ambiguous
        case none
    }

    public func uncertainReason(for sample: ConfidenceSample,
                                policy: ConfidencePolicy = ConfidencePolicy()) -> UncertainReason {
        if let ratio = sample.ratioToSigma, ratio > policy.maxSeparationSigma { return .tooFar }
        if let neighbour = sample.neighbourRatioToSigma, neighbour <= policy.ambiguitySigma {
            return .ambiguous
        }
        return .none
    }

    /// Jumlah sampel ragu per sebab.
    public func uncertainReasonCounts(policy: ConfidencePolicy = ConfidencePolicy()) -> [UncertainReason: Int] {
        var counts: [UncertainReason: Int] = [:]
        for sample in samples where sample.state == .uncertain {
            counts[uncertainReason(for: sample, policy: policy), default: 0] += 1
        }
        return counts
    }

    /// Kalimat diagnostik untuk ditampilkan — apa yang harus diperbaiki.
    public func diagnosis(policy: ConfidencePolicy = ConfidencePolicy()) -> String {
        guard !samples.isEmpty else { return "Belum ada sampel." }
        let counts = stateCounts
        let locks = counts[.lock] ?? 0
        let uncertain = counts[.uncertain] ?? 0
        let reasons = uncertainReasonCounts(policy: policy)

        if locks == 0 && uncertain == 0 {
            return "Belum ada jawaban sama sekali. Arahkan ke langit dan tahan sampai pergelangan diam."
        }
        if locks == 0 {
            let dominant = reasons.max { $0.value < $1.value }?.key ?? .none
            switch dominant {
            case .tooFar:
                return "Semua jawaban ragu karena kandidat terlalu jauh dari arah tunjuk. Perbaiki kalibrasi dulu."
            case .ambiguous:
                return "Semua jawaban ragu karena ada dua kandidat berdekatan. Ini keterbatasan akurasi, bukan kesalahan kalibrasi."
            case .none:
                return "Jawaban ragu tanpa sebab terukur — periksa apakah arah tunjuk masuk akal."
            }
        }
        let ratio = Double(locks) / Double(locks + uncertain)
        return String(format: "%.0f%% jawaban yakin (%d yakin, %d ragu).",
                      ratio * 100, locks, uncertain)
    }
}
