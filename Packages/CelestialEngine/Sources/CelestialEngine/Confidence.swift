import Foundation

/// Kebijakan keyakinan.
///
/// Semua ambang dinyatakan sebagai kelipatan **sigma pointing** — perkiraan
/// galat 1σ dari arah tunjuk. Ini disengaja: PRD v0.4 melarang mengasumsikan
/// akurasi Apple Watch, jadi keyakinan harus dinyatakan relatif terhadap
/// ketidakpastian yang kita akui, bukan terhadap ukuran kerucut pencarian.
///
/// Konsekuensinya: kalau Experiment 1 nanti mengukur sigma yang lebih besar,
/// engine otomatis lebih pelit memberi HIGH — tanpa mengubah satu baris pun
/// logika keputusan.
public struct ConfidencePolicy: Equatable {
    /// Perkiraan galat pointing 1σ, derajat.
    ///
    /// Nilai awal 10° adalah **placeholder yang sengaja longgar**, bukan hasil
    /// pengukuran. Angka ini harus diganti dengan hasil Experiment 1. Selama
    /// belum diukur, lebih baik engine terlalu pelit memberi HIGH.
    public var pointingSigmaDeg: Double

    /// Dua kandidat yang berjarak kurang dari ini dianggap tidak terpisahkan
    /// oleh akurasi kita, sehingga tidak boleh diklaim pasti.
    public var ambiguitySigma: Double

    /// Kandidat terbaik harus sedekat ini dari arah tunjuk agar boleh HIGH.
    public var maxSeparationSigma: Double

    public init(pointingSigmaDeg: Double = 10.0,
                ambiguitySigma: Double = 2.0,
                maxSeparationSigma: Double = 1.0) {
        self.pointingSigmaDeg = pointingSigmaDeg
        self.ambiguitySigma = ambiguitySigma
        self.maxSeparationSigma = maxSeparationSigma
    }

    /// Ambang jarak kandidat terbaik ke arah tunjuk untuk boleh HIGH, derajat.
    public var maxSeparationDeg: Double { pointingSigmaDeg * maxSeparationSigma }
    /// Ambang jarak antar-kandidat agar dianggap ambigu, derajat.
    public var ambiguityDeg: Double { pointingSigmaDeg * ambiguitySigma }
}

/// Model keyakinan. Prinsip PRD: uncertainty > false confidence.
///
/// HIGH hanya diberikan kalau **kedua** syarat terpenuhi:
/// 1. kandidat terbaik cukup dekat dengan arah tunjuk (≤ `maxSeparationSigma` σ), dan
/// 2. kandidat terbaik cukup jauh dari kandidat lain (≥ `ambiguitySigma` σ).
///
/// Kalau salah satu gagal, hasilnya MEDIUM. Engine boleh ragu; engine tidak
/// boleh mengklaim pasti saat kandidat ambigu.
public enum ConfidenceModel {

    /// Evaluasi kandidat -> CelestialIntent.
    ///
    /// - Parameters:
    ///   - candidates: kandidat (tidak harus terurut; diurutkan di sini).
    ///   - coneDeg: setengah sudut kerucut pointing (derajat).
    ///   - nearestNeighbourDeg: jarak sudut terkecil antara kandidat terbaik
    ///     dan kandidat lain **di langit** (derajat). `nil` berarti tidak ada
    ///     kandidat lain. Ini harus jarak sesungguhnya antar dua posisi, bukan
    ///     selisih jarak mereka ke arah tunjuk — dua benda bisa sama-sama 5°
    ///     dari arah tunjuk tapi terpisah 10° satu sama lain.
    ///   - policy: ambang keyakinan.
    public static func evaluate(candidates: [Candidate],
                                coneDeg: Double,
                                nearestNeighbourDeg: Double? = nil,
                                policy: ConfidencePolicy = ConfidencePolicy()) -> CelestialIntent {
        let ordered = candidates.sorted { $0.separationDeg < $1.separationDeg }

        guard let best = ordered.first, best.separationDeg <= coneDeg else {
            return CelestialIntent(level: .low, best: nil, candidates: [])
        }

        let top = Array(ordered.prefix(3))

        // Syarat 1: kandidat terbaik cukup dekat dengan arah tunjuk.
        guard best.separationDeg <= policy.maxSeparationDeg else {
            return CelestialIntent(level: .medium, best: best.object, candidates: top)
        }

        // Syarat 2: tidak ada kandidat lain yang terlalu berdekatan.
        // Perbandingan inklusif: tetangga yang persis di ambang ambiguitas
        // masih dianggap ambigu. Ini arah yang aman — lebih baik ragu
        // daripada mengklaim pasti tepat di batas ketidakpastian kita.
        if let neighbour = nearestNeighbourDeg, neighbour <= policy.ambiguityDeg {
            return CelestialIntent(level: .medium, best: best.object, candidates: top)
        }

        return CelestialIntent(level: .high, best: best.object, candidates: top)
    }
}
