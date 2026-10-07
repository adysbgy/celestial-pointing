import Foundation

/// Kalibrasi pointing: koreksi sistematis dari arah tunjuk perangkat.
///
/// **Apa yang dikoreksi, dan kenapa hanya itu.**
/// Kerangka acuan `xArbitraryZVertical` menyelaraskan sumbu-Z dengan gravitasi,
/// jadi kemiringan (altitude) sudah absolut terhadap cakrawala. Yang tidak
/// diketahui adalah arah hadap pada bidang horizontal — CoreMotion tidak tahu
/// di mana Utara. Karena itu kalibrasi hanya menentukan **offset azimut**.
///
/// Mengoreksi altitude lewat kalibrasi akan menyembunyikan galat sensor di
/// balik angka yang terlihat benar; itu bertentangan dengan prinsip PRD
/// (uncertainty > false confidence). Altitude dibiarkan apa adanya dan
/// ketidakpastiannya dilaporkan lewat `residualSpreadDeg`.
public struct PointingCalibration: Equatable, Codable, Sendable {
    /// Offset yang ditambahkan ke azimut terukur (derajat).
    public var yawOffsetDeg: Double
    /// Sebaran sisa galat pointing setelah koreksi yaw (derajat, 1σ).
    ///
    /// Inilah **estimasi sigma pointing** yang selama ini diasumsikan di
    /// `ConfidencePolicy`. `nil` bila sampelnya kurang dari dua (satu titik
    /// tidak bisa memberi tahu seberapa konsisten kalibrasinya).
    public var residualSpreadDeg: Double?
    /// Jumlah pasangan titik acuan yang dipakai.
    public var sampleCount: Int

    public init(yawOffsetDeg: Double, residualSpreadDeg: Double?, sampleCount: Int) {
        self.yawOffsetDeg = yawOffsetDeg
        self.residualSpreadDeg = residualSpreadDeg
        self.sampleCount = sampleCount
    }

    /// Kalibrasi netral (tidak mengubah apa pun, tanpa estimasi sigma).
    public static let none = PointingCalibration(yawOffsetDeg: 0,
                                                 residualSpreadDeg: nil,
                                                 sampleCount: 0)

    /// Terapkan koreksi: azimut digeser, altitude **tidak** disentuh.
    ///
    /// Memutar mengelilingi zenith (sumbu-Up lokal) memang hanya mengubah
    /// azimut — arah tunjuk tidak boleh berubah kemiringannya karena kalibrasi.
    public func apply(to pointing: HorizontalCoord) -> HorizontalCoord {
        HorizontalCoord(
            altitudeDeg: pointing.altitudeDeg,
            azimuthDeg: SkyMath.normalizeDeg(pointing.azimuthDeg + yawOffsetDeg)
        )
    }

    /// Sigma pointing yang disarankan untuk `ConfidencePolicy`.
    ///
    /// Dipakai supaya ambang keyakinan engine otomatis mengikuti hasil
    /// pengukuran nyata, bukan angka tebakan. `nil` bila belum terukur —
    /// pemanggil harus tetap memakai nilai konservatif bawaan.
    public var suggestedPointingSigmaDeg: Double? { residualSpreadDeg }

    /// Bangun kebijakan keyakinan dari sigma terukur.
    ///
    /// Selama sigma belum terukur, mengembalikan `nil` — engine tidak boleh
    /// mengarang angka akurasi.
    public func confidencePolicy(ambiguitySigma: Double = 2.0,
                                 maxSeparationSigma: Double = 1.0) -> ConfidencePolicy? {
        guard let sigma = residualSpreadDeg, sigma > 0, sigma.isFinite else { return nil }
        return .measured(pointingSigmaDeg: sigma,
                         ambiguitySigma: ambiguitySigma,
                         maxSeparationSigma: maxSeparationSigma)
    }
}

/// Penyelesaian kalibrasi dari titik acuan yang diketahui.
public enum CalibrationSolver {

    /// Selesaikan offset yaw dari pasangan arah terukur dan arah sebenarnya.
    ///
    /// Kedua larik harus sejajar panjangnya. Offset dihitung sebagai **rata-rata
    /// sirkular** dari selisih azimut: rata-rata biasa akan salah di sekitar
    /// 0°/360° (mis. 359° dan 1° seharusnya rata-rata 0°, bukan 180°).
    ///
    /// - Returns: `nil` bila tidak ada sampel, panjang larik tidak sama, atau
    ///   nilai tidak berhingga.
    public static func solve(measured: [HorizontalCoord],
                             truth: [HorizontalCoord]) -> PointingCalibration? {
        guard !measured.isEmpty, measured.count == truth.count else { return nil }
        guard measured.allSatisfy({ $0.altitudeDeg.isFinite && $0.azimuthDeg.isFinite }),
              truth.allSatisfy({ $0.altitudeDeg.isFinite && $0.azimuthDeg.isFinite })
        else { return nil }

        // Selisih azimut terukur -> sebenarnya.
        let deltas = zip(measured, truth).map { m, t in
            SkyMath.normalizeDeg(t.azimuthDeg - m.azimuthDeg)
        }
        let yaw = circularMeanDeg(deltas) ?? 0

        // Sebaran sisa: galat sudut total setelah koreksi yaw diterapkan.
        var residual: Double?
        if measured.count >= 2 {
            let errors = zip(measured, truth).map { m, t -> Double in
                let corrected = HorizontalCoord(
                    altitudeDeg: m.altitudeDeg,
                    azimuthDeg: SkyMath.normalizeDeg(m.azimuthDeg + yaw)
                )
                return SkyMath.angularSeparationHorizontalDeg(corrected, t)
            }
            residual = rootMeanSquare(errors)
        }

        return PointingCalibration(yawOffsetDeg: yaw,
                                   residualSpreadDeg: residual,
                                   sampleCount: measured.count)
    }

    /// Rata-rata sirkular sekumpulan sudut (derajat). `nil` bila kosong.
    public static func circularMeanDeg(_ anglesDeg: [Double]) -> Double? {
        guard !anglesDeg.isEmpty else { return nil }
        var sumSin = 0.0, sumCos = 0.0
        for a in anglesDeg {
            let r = SkyMath.deg2rad(a)
            sumSin += sin(r)
            sumCos += cos(r)
        }
        if abs(sumSin) < 1e-15 && abs(sumCos) < 1e-15 { return nil } // arah tak terdefinisi
        return SkyMath.normalizeDeg(SkyMath.rad2deg(atan2(sumSin, sumCos)))
    }

    /// Akar rata-rata kuadrat. `nil` bila kosong.
    public static func rootMeanSquare(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let meanSquare = values.reduce(0) { $0 + $1 * $1 } / Double(values.count)
        return meanSquare.squareRoot()
    }
}
