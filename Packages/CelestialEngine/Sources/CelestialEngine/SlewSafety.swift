import Foundation

/// Bahaya yang ditemukan pada rencana GoTo.
public enum SlewHazard: String, Equatable, Codable, Sendable {
    /// Target terlalu dekat Matahari.
    case sunProximity
    /// Target di bawah batas ketinggian teleskop.
    case belowAltitudeLimit
    /// Target di bawah horizon (terbit belum terjadi).
    case belowHorizon
    /// Target terlalu redup untuk pengamatan.
    case tooFaint
    /// Tidak ada objek target.
    case noTarget
    /// Engine tidak yakin objek mana yang dimaksud.
    case lowConfidence
    /// Posisi Matahari tidak diketahui, sehingga pengaman tidak bisa dijalankan.
    case sunPositionUnknown
}

/// Perintah GoTo yang sudah diperiksa keamanannya.
///
/// **Aturan keras PRD yang ditegakkan di sini**: sudut pergelangan TIDAK PERNAH
/// menjadi gerak motor. Yang sampai ke teleskop hanyalah perintah GoTo yang
/// diturunkan dari objek yang sudah diidentifikasi dan lolos pemeriksaan.
/// Tipe ini hanya bisa dibangun oleh `SlewPlanner` yang menjalankan pemeriksaan.
public struct SlewCommand: Equatable, Sendable {
    /// Objek yang akan di-GoTo.
    public var object: CelestialObject
    /// Arah horizontal objek saat ini (bukan arah tunjuk pergelangan).
    public var target: HorizontalCoord
    /// Tingkat keyakinan identifikasi objek ini.
    public var confidence: ConfidenceLevel

    init(object: CelestialObject, target: HorizontalCoord, confidence: ConfidenceLevel) {
        self.object = object
        self.target = target
        self.confidence = confidence
    }
}

/// Hasil perencanaan slew: boleh GoTo, atau ditolak dengan alasan yang jelas.
public enum SlewDecision: Equatable, Sendable {
    /// Aman untuk di-GoTo.
    case allowed(SlewCommand)
    /// Ditolak; `hazards` tidak pernah kosong.
    case rejected(hazards: [SlewHazard])

    public var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    public var hazards: [SlewHazard] {
        switch self {
        case .allowed: return []
        case .rejected(let h): return h
        }
    }
}

/// Ambang keselamatan slew. Bisa dikonfigurasi per teleskop.
public struct SlewSafetyPolicy: Equatable, Sendable {
    /// Jarak minimum dari Matahari (derajat). Batas keras.
    public var minSunSeparationDeg: Double
    /// Ketinggian minimum teleskop (derajat). Teleskop tidak boleh diarahkan
    /// terlalu rendah (biasanya karena batas mekanis).
    public var minAltitudeDeg: Double
    /// Ketinggian maksimum teleskop (derajat) — batas mekanis meridian.
    public var maxAltitudeDeg: Double
    /// Batas magnitudo objek yang boleh di-GoTo.
    public var limitingMagnitude: Double
    /// Tingkat keyakinan minimum yang boleh memicu GoTo.
    public var requiredConfidence: ConfidenceLevel

    public init(minSunSeparationDeg: Double = 30.0,
                minAltitudeDeg: Double = 10.0,
                maxAltitudeDeg: Double = 89.0,
                limitingMagnitude: Double = 8.0,
                requiredConfidence: ConfidenceLevel = .high) {
        self.minSunSeparationDeg = minSunSeparationDeg
        self.minAltitudeDeg = minAltitudeDeg
        self.maxAltitudeDeg = maxAltitudeDeg
        self.limitingMagnitude = limitingMagnitude
        self.requiredConfidence = requiredConfidence
    }
}

/// Perencana slew: resolusi → perintah GoTo yang aman, atau penolakan beralasan.
///
/// Ini gerbang antara "engine tahu benda apa itu" dan "teleskop boleh bergerak".
/// Prinsip: gagal-tertutup. Apa pun yang tidak bisa diverifikasi — Matahari tak
/// diketahui, keyakinan rendah, tanpa target — menghasilkan penolakan.
public enum SlewPlanner {

    /// Periksa rencana GoTo untuk sebuah resolusi.
    ///
    /// - Parameters:
    ///   - resolution: hasil `PointingResolver.diagnose(...)`.
    ///   - targetHorizontal: arah horizontal objek terbaik saat ini. Kalau
    ///     `nil`, teleskop tidak tahu harus ke mana dan perintah ditolak.
    ///   - policy: ambang keselamatan.
    public static func plan(resolution: Resolution,
                            targetHorizontal: HorizontalCoord?,
                            policy: SlewSafetyPolicy = SlewSafetyPolicy()) -> SlewDecision {
        let intent = resolution.intent

        guard let object = intent.best else {
            return .rejected(hazards: [.noTarget])
        }
        guard confidenceIsSufficient(intent.level, policy: policy) else {
            return .rejected(hazards: [.lowConfidence])
        }
        guard let target = targetHorizontal else {
            // Keyakinan cukup tapi arah target tidak tersedia: tidak bisa
            // mengarahkan teleskop. Gagal-tertutup.
            return .rejected(hazards: [.noTarget])
        }

        var hazards: [SlewHazard] = []

        if target.altitudeDeg < policy.minAltitudeDeg { hazards.append(.belowAltitudeLimit) }
        if target.altitudeDeg < 0 { hazards.append(.belowHorizon) }
        if target.altitudeDeg > policy.maxAltitudeDeg { hazards.append(.belowAltitudeLimit) }
        if object.magnitude > policy.limitingMagnitude { hazards.append(.tooFaint) }

        // Pengaman Matahari. Kalau posisi Matahari tidak diketahui, JANGAN
        // menganggap aman — tolak.
        if let sun = resolution.sunHorizontal {
            let separation = SkyMath.angularSeparationHorizontalDeg(target, sun)
            if separation < policy.minSunSeparationDeg { hazards.append(.sunProximity) }
        } else {
            hazards.append(.sunPositionUnknown)
        }

        guard hazards.isEmpty else {
            return .rejected(hazards: Array(Set(hazards)).sorted { $0.rawValue < $1.rawValue })
        }
        return .allowed(SlewCommand(object: object, target: target, confidence: intent.level))
    }

    /// Apakah tingkat keyakinan memenuhi syarat minimum.
    public static func confidenceIsSufficient(_ level: ConfidenceLevel,
                                              policy: SlewSafetyPolicy) -> Bool {
        rank(level) >= rank(policy.requiredConfidence)
    }

    private static func rank(_ level: ConfidenceLevel) -> Int {
        switch level {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}
