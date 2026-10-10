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

// MARK: - Model kalibrasi 3D (eksperimen, ADR-003)

/// Model kalibrasi yang dibandingkan di eksperimen pointing.
///
/// `yawOnly` adalah bawaan dan satu-satunya yang dipakai alur kalibrasi
/// pengguna. `wahba` hanya dipakai bila diminta eksplisit (flag eksperimen),
/// sampai data lapangan menunjukkan ia memang mengurangi galat.
public enum CalibrationModel: String, CaseIterable, Codable, Equatable, Sendable {
    case none
    case yawOnly
    case wahba
}

/// Solusi masalah Wahba: rotasi `R` yang meminimalkan Σ wᵢ ‖tᵢ − R·mᵢ‖².
///
/// Dipakai metode quaternion Horn (1987) — eigenvektor nilai eigen terbesar
/// dari matriks 4×4 simetris — karena tetap stabil untuk dua acuan (matriks
/// korelasi berpangkat 2), kasus yang membuat jalur SVD naif gagal.
public enum WahbaSolver {

    public struct Solution: Equatable, Sendable {
        /// Rotasi aktif: `truth ≈ rotation.rotated(measured)`.
        public var rotation: Quaternion
        /// Galat sudut RMS setelah rotasi diterapkan (derajat).
        public var residualRMSDeg: Double
    }

    /// - Returns: `nil` bila kurang dari dua pasangan, panjang tak sama,
    ///   atau semua pasangan segaris (rotasi tak teramati).
    public static func solve(measured: [Vector3], truth: [Vector3],
                             weights: [Double]? = nil) -> Solution? {
        guard measured.count >= 2, measured.count == truth.count else { return nil }
        let w = weights ?? Array(repeating: 1.0, count: measured.count)
        guard w.count == measured.count else { return nil }
        let pairs = zip(measured, truth).compactMap { m, t -> (Vector3, Vector3)? in
            guard let mn = m.normalized, let tn = t.normalized else { return nil }
            return (mn, tn)
        }
        guard pairs.count == measured.count else { return nil }

        // Tak teramati bila semua arah terukur segaris.
        let first = pairs[0].0
        guard pairs.contains(where: { $0.0.cross(first).magnitude > 1e-6 }) else { return nil }

        // S_ab = Σ w · m_a · t_b
        var s = [[Double]](repeating: [0, 0, 0], count: 3)
        for (i, (m, t)) in pairs.enumerated() {
            let mv = [m.x, m.y, m.z], tv = [t.x, t.y, t.z]
            for a in 0..<3 { for b in 0..<3 { s[a][b] += w[i] * mv[a] * tv[b] } }
        }
        let (sxx, sxy, sxz) = (s[0][0], s[0][1], s[0][2])
        let (syx, syy, syz) = (s[1][0], s[1][1], s[1][2])
        let (szx, szy, szz) = (s[2][0], s[2][1], s[2][2])
        let n: [[Double]] = [
            [sxx + syy + szz, syz - szy, szx - sxz, sxy - syx],
            [syz - szy, sxx - syy - szz, sxy + syx, szx + sxz],
            [szx - sxz, sxy + syx, -sxx + syy - szz, syz + szy],
            [sxy - syx, szx + sxz, syz + szy, -sxx - syy + szz],
        ]
        guard let v = SymmetricEigen.largestEigenvector4(n),
              let q = Quaternion(w: v[0], x: v[1], y: v[2], z: v[3]).normalized
        else { return nil }

        let errors = pairs.map { m, t in q.rotated(m).angleDegrees(to: t) ?? 180 }
        let rms = CalibrationSolver.rootMeanSquare(errors) ?? 0
        return Solution(rotation: q, residualRMSDeg: rms)
    }
}

/// Nilai/vektor eigen matriks simetris kecil (Jacobi siklik), tanpa `simd`
/// supaya teruji di Linux.
enum SymmetricEigen {
    static func largestEigenvector4(_ input: [[Double]]) -> [Double]? {
        let n = 4
        guard input.count == n, input.allSatisfy({ $0.count == n }) else { return nil }
        var a = input
        var v = (0..<n).map { i in (0..<n).map { j in i == j ? 1.0 : 0.0 } }
        for _ in 0..<100 {
            var off = 0.0
            for p in 0..<n { for q in (p + 1)..<n { off += a[p][q] * a[p][q] } }
            if off < 1e-22 { break }
            for p in 0..<n {
                for q in (p + 1)..<n where abs(a[p][q]) > 1e-300 {
                    let theta = (a[q][q] - a[p][p]) / (2 * a[p][q])
                    let t = (theta >= 0 ? 1.0 : -1.0) / (abs(theta) + (theta * theta + 1).squareRoot())
                    let c = 1 / (t * t + 1).squareRoot(), s = t * c
                    for k in 0..<n {
                        let akp = a[k][p], akq = a[k][q]
                        a[k][p] = c * akp - s * akq
                        a[k][q] = s * akp + c * akq
                    }
                    for k in 0..<n {
                        let apk = a[p][k], aqk = a[q][k]
                        a[p][k] = c * apk - s * aqk
                        a[q][k] = s * apk + c * aqk
                    }
                    for k in 0..<n {
                        let vkp = v[k][p], vkq = v[k][q]
                        v[k][p] = c * vkp - s * vkq
                        v[k][q] = s * vkp + c * vkq
                    }
                }
            }
        }
        guard a.allSatisfy({ $0.allSatisfy(\.isFinite) }) else { return nil }
        let best = (0..<n).max { a[$0][$0] < a[$1][$1] }!
        return (0..<n).map { v[$0][best] }
    }
}

// MARK: - Pemilihan sumbu tunjuk dari data (ADR-002)

/// Satu sampel acuan: attitude mentah saat pengguna menunjuk target yang
/// arahnya diketahui.
public struct AxisSample: Equatable, Codable, Sendable {
    public var attitude: DeviceAttitude
    public var truth: HorizontalCoord

    public init(attitude: DeviceAttitude, truth: HorizontalCoord) {
        self.attitude = attitude
        self.truth = truth
    }
}

/// Skor satu sumbu kandidat terhadap sekumpulan sampel acuan.
public struct AxisScore: Equatable, Codable, Sendable {
    public var aim: DeviceAimAxis
    /// Offset yaw yang dipasang untuk sumbu ini (`nil` pada kerangka berutara).
    public var yawOffsetDeg: Double?
    public var rmsErrorDeg: Double
    public var medianErrorDeg: Double
    public var errorsDeg: [Double]
}

public enum AxisSelection {

    /// Nilai setiap kandidat, urut dari galat RMS terkecil.
    ///
    /// Pada kerangka sembarang, setiap sumbu mendapat offset yaw-nya sendiri
    /// sebelum dinilai — tanpa itu, sumbu yang benar bisa kalah hanya karena
    /// sumbu-X kerangka acuannya kebetulan tidak menghadap Utara.
    public static func evaluate(_ samples: [AxisSample],
                                candidates: [DeviceAimAxis] = DeviceAimAxis.selectionCandidates)
        -> [AxisScore] {
        guard !samples.isEmpty else { return [] }
        let absolute = samples.allSatisfy { $0.attitude.frame.hasAbsoluteHeading }
        var scores: [AxisScore] = []
        for aim in candidates {
            let measured = samples.compactMap { $0.attitude.horizontalPointing(aim: aim) }
            guard measured.count == samples.count else { continue }
            let truth = samples.map(\.truth)
            var yaw: Double?
            var corrected = measured
            if !absolute, let cal = CalibrationSolver.solve(measured: measured, truth: truth) {
                yaw = cal.yawOffsetDeg
                corrected = measured.map(cal.apply(to:))
            }
            let errors = zip(corrected, truth).map { SkyMath.angularSeparationHorizontalDeg($0, $1) }
            let sorted = errors.sorted()
            let median = sorted.count % 2 == 1
                ? sorted[sorted.count / 2]
                : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            scores.append(AxisScore(aim: aim, yawOffsetDeg: yaw,
                                    rmsErrorDeg: CalibrationSolver.rootMeanSquare(errors) ?? 0,
                                    medianErrorDeg: median, errorsDeg: errors))
        }
        return scores.sorted { $0.rmsErrorDeg < $1.rmsErrorDeg }
    }

    /// Arah tunjuk terbaik **di kerangka perangkat** (bukan hanya ±sumbu):
    /// rata-rata arah `R(q)ᵀ · t` dari semua sampel. Hanya bermakna pada
    /// kerangka berutara, karena azimut target harus absolut.
    public static func fittedDeviceAxis(_ samples: [AxisSample]) -> Vector3? {
        guard !samples.isEmpty,
              samples.allSatisfy({ $0.attitude.frame.hasAbsoluteHeading }) else { return nil }
        var sum = Vector3.zero
        for s in samples {
            guard let r = s.attitude.deviceToWorld else { return nil }
            sum = sum + r.transpose.multiplied(by: LocalFrame.enuFromHorizontal(s.truth))
        }
        return sum.normalized
    }
}
