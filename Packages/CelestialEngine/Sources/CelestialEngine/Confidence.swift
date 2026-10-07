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
public struct ConfidencePolicy: Equatable, Sendable {
    /// Perkiraan galat pointing 1σ, derajat.
    ///
    /// **Nilainya harus berasal dari pengukuran, bukan tebakan.** Dokumen
    /// kelayakan §12 menutup jalan itu secara eksplisit: kerucut keyakinan
    /// harus dipakai dari *distribusi galat pointing yang empiris*, "bukan
    /// ambang '5°' yang dikarang". Sigma 10° di bawah adalah **nilai cadangan
    /// yang sengaja longgar** — bukan hasil ukur. Selama `isMeasured == false`,
    /// angka itu hanya berarti "kita belum tahu, jadi jangan berani-berani
    /// memberi HIGH".
    ///
    /// Angka ini harus diganti dengan hasil Experiment 1 (lihat
    /// `CalibrationFlow`/`ExperimentHarness.suggestedConfidencePolicy`).
    public var pointingSigmaDeg: Double

    /// Apakah `pointingSigmaDeg` berasal dari pengukuran.
    ///
    /// **Kenapa ini ada, terpisah dari nilainya.** Tanpa penanda ini, sigma
    /// cadangan 10° dan sigma hasil ukur 10° terlihat identik bagi seluruh
    /// kode di hilir — layar bisa menampilkan "akurasi ±10°" seolah itu hasil
    /// pengukuran, padahal itu justru tebakan yang dilarang dokumen §12.
    /// Pembeda ini yang membuat kejujuran itu bisa diuji, bukan hanya
    /// dijanjikan di komentar.
    public var isMeasured: Bool

    /// Dua kandidat yang berjarak kurang dari ini dianggap tidak terpisahkan
    /// oleh akurasi kita, sehingga tidak boleh diklaim pasti.
    public var ambiguitySigma: Double

    /// Kandidat terbaik harus sedekat ini dari arah tunjuk agar boleh HIGH.
    public var maxSeparationSigma: Double

    /// Kebijakan cadangan yang belum terukur.
    public init(pointingSigmaDeg: Double = 10.0,
                ambiguitySigma: Double = 2.0,
                maxSeparationSigma: Double = 1.0,
                isMeasured: Bool = false) {
        self.pointingSigmaDeg = pointingSigmaDeg
        self.ambiguitySigma = ambiguitySigma
        self.maxSeparationSigma = maxSeparationSigma
        self.isMeasured = isMeasured
    }

    /// Kebijakan dari sigma yang **sudah diukur**.
    ///
    /// Satu-satunya jalan membangun kebijakan terukur, supaya `isMeasured`
    /// tidak bisa lupa dipasang. Pembuat kebijakan cadangan tetap `init`
    /// bawaannya, dan itu sendirinya sudah menandai "belum terukur".
    public static func measured(pointingSigmaDeg: Double,
                                ambiguitySigma: Double = 2.0,
                                maxSeparationSigma: Double = 1.0) -> ConfidencePolicy {
        ConfidencePolicy(pointingSigmaDeg: pointingSigmaDeg,
                         ambiguitySigma: ambiguitySigma,
                         maxSeparationSigma: maxSeparationSigma,
                         isMeasured: true)
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
