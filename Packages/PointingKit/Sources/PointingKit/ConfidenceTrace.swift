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

    /// Sebab keraguan yang **berbagi hitungan tertinggi**, atau kosong bila
    /// ada satu sebab yang jelas mendominasi.
    ///
    /// **Kenapa ini harus jadi predikat, bukan `counts.max { $0.value < $1.value }`
    /// di dalam `diagnosis`.** Versi lama mengambil penyebab "teratas" dengan
    /// `max { $0.value < $1.value }` pada dictionary. Saat hitungannya **sama**,
    /// `max` mengembalikan elemen pertama yang ditemukan — dan urutan iterasi
    /// `Dictionary` **tidak ditentukan** di Swift (hash di-seed per proses).
    /// Akibatnya kalimat diagnosis yang sama, untuk data yang sama, berubah
    /// antara dua kali peluncuran app:
    ///
    /// | Hitungan | Kalimat yang bisa muncul |
    /// |---|---|
    /// | tooFar 1, ambiguous 1 | "Perbaiki kalibrasi dulu." **atau** "Ini keterbatasan akurasi." |
    ///
    /// Yang berubah bukan sekadar kalimat yang "varias sedikit": keduanya
    /// adalah **petunjuk perbaikan yang saling meniadakan**, dan hanya salah
    /// satu yang benar. Pada alat ukur repo ini sendiri, itu bukan cacat yang
    /// bisa diterima: penguji yang mengikuti satu petunjuk bisa membuat
    /// kalibrasi yang tidak diperlukan, atau menerima batas akurasi yang
    /// sebenarnya bisa diperbaiki.
    ///
    /// Urutan hasilnya mengikuti urutan deklarasi enum, jadi **stabil** — bukan
    /// stabil karena hash kebetulan sama, tapi karena urutan yang ditulis.
    public func tiedUncertainReasons(policy: ConfidencePolicy = ConfidencePolicy()) -> [UncertainReason] {
        let counts = uncertainReasonCounts(policy: policy)
        guard let top = counts.values.max(), top > 0 else { return [] }
        return UncertainReason.allCases.filter { counts[$0] == top }
    }

    /// Kalimat diagnostik untuk ditampilkan - apa yang harus diperbaiki.
    ///
    /// **Keputusan saat hitungan seri.** Kalau dua sebab berbagi hitungan
    /// tertinggi, kalimatnya harus menyatakan keduanya - bukan memilih satu
    /// secara diam-diam. Alasannya bukan sekadar agar kelihatan tegas:
    ///
    /// - Memilih satu berarti menyembunyikan sebab yang sama saingnya. Kalau
    ///   yang tampil hanya "perbaiki kalibrasi", penguji tidak tahu ada
    ///   ambiguitas katalog yang juga harus dibenahi.
    /// - Dan kalau pilihan itu berubah-ubah antar peluncuran (lihat
    ///   `tiedUncertainReasons`), diagnosis yang sama memberi petunjuk yang
    ///   saling meniadakan untuk data yang sama - persis cacat yang
    ///   ditutup di sini.
    ///
    /// Karena itu kalimat seri menyebut semua sebab yang berbagi hitungan
    /// tertinggi, dan hanya sebab yang benar-benar mendominasi (> separuh
    /// sampel ragu) boleh tampil sendiri tanpa menyebut yang lain.
    public func diagnosis(policy: ConfidencePolicy = ConfidencePolicy()) -> String {
        guard !samples.isEmpty else { return ExperimentText.diagnosisNoSamples }
        let counts = stateCounts
        let locks = counts[.lock] ?? 0
        let uncertain = counts[.uncertain] ?? 0
        let reasons = uncertainReasonCounts(policy: policy)

        if locks == 0 && uncertain == 0 {
            return ExperimentText.diagnosisNoAnswers
        }
        if locks == 0 {
            // Satu sebab yang benar-benar mendominasi boleh tampil sendiri.
            // Ambangnya lebih dari separuh sampel ragu, bukan sekadar paling
            // banyak: "paling banyak" bisa tetap seri (2 dari 2), dan itu
            // justru kasus yang tidak boleh memilih satu.
            let uncertainTotal = uncertain
            let dominant = reasons
                .filter { $0.key != .none
                    && Double($0.value) * 2 > Double(uncertainTotal) }
                .max { $0.value < $1.value }?.key
            if let dominant, dominant != .none {
                switch dominant {
                case .tooFar:
                    return ExperimentText.diagnosisTooFar
                case .ambiguous:
                    return ExperimentText.diagnosisAmbiguous
                case .none:
                    break
                }
            }

            // Tidak ada yang mendominasi: sebut semua sebab yang seri di
            // puncak. `.none` ikut disebut karena "tanpa sebab terukur"
            // adalah informasi berbeda dari dua sebab lain, dan diam-diam
            // membuangnya akan membuat kalimatnyabzclaimed satu penyebab.
            let tied = tiedUncertainReasons(policy: policy)
            guard tied.count > 1 else {
                // Tidak ada yang seri: sebab tunggal sudah tertangani di atas
                // sebagai `dominant`, jadi sisanya benar-benar "tanpa sebab
                // terukur".
                return ExperimentText.diagnosisNoMeasurableCause
            }
            // Map ordered by declaration order, not by dictionary order: that is
            // what makes this sentence stable across launches.
            let sentences = tied.map { reason -> String in
                switch reason {
                case .tooFar: return ExperimentText.diagnosisTooFar
                case .ambiguous: return ExperimentText.diagnosisAmbiguous
                case .none: return ExperimentText.diagnosisNoMeasurableCause
                }
            }
            return ExperimentText.diagnosisMixed(reasons: sentences)
        }
        return ExperimentText.diagnosisRatio(locks: locks, uncertain: uncertain)
    }
}
