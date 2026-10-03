import Foundation
import CelestialEngine

/// Nada visual untuk sebuah keadaan.
///
/// Dipisahkan dari SwiftUI supaya **janji tampilan bisa diuji**: PRD melarang
/// membuat engine terlihat lebih yakin daripada keadaannya. Kalau `uncertain`
/// dan `lock` memakai nada yang sama, seluruh aturan anti-false-lock di engine
/// jadi sia-sia di layar. Uji `PointingPresentationTests` menjaga itu.
public enum PointingTone: String, Equatable, Sendable {
    /// Belum ada apa-apa (idle).
    case neutral
    /// Sedang bekerja (pointing, searching).
    case active
    /// Jawaban yakin (lock).
    case success
    /// Ada jawaban tapi ragu (uncertain).
    case warning
    /// Tidak bisa dipakai (sensor hilang).
    case danger
}

public extension PointingState {

    /// Nada visual keadaan ini.
    var tone: PointingTone {
        switch self {
        case .idle: return .neutral
        case .pointing, .searching: return .active
        case .lock: return .success
        case .uncertain: return .warning
        case .unavailable: return .danger
        }
    }

    /// Nama SF Symbol untuk keadaan ini.
    var symbolName: String {
        switch self {
        case .idle: return "scope"
        case .pointing: return "location.north.line"
        case .searching: return "sparkle.magnifyingglass"
        case .lock: return "checkmark.circle.fill"
        case .uncertain: return "questionmark.circle"
        case .unavailable: return "exclamationmark.triangle"
        }
    }

    /// Label singkat untuk layar jam.
    var shortLabel: String {
        switch self {
        case .idle: return "Siap"
        case .pointing: return "Arahkan"
        case .searching: return "Mencari"
        case .lock: return "Terkunci"
        case .uncertain: return "Kurang yakin"
        case .unavailable: return "Sensor mati"
        }
    }

    /// Kalimat penjelasan — apa yang harus dilakukan pengguna.
    var guidance: String {
        switch self {
        case .idle: return "Angkat jam dan arahkan ke langit."
        case .pointing: return "Tahan arah tunjuk sampai jam berhenti bergerak."
        case .searching: return "Belum ada objek di arah itu."
        case .lock: return "Objek dikenali dengan keyakinan tinggi."
        case .uncertain: return "Ada kandidat, tapi belum cukup yakin untuk memastikan."
        case .unavailable: return "Jam tidak memberi data gerak. Coba lagi."
        }
    }

    /// Apakah keadaan ini boleh ditampilkan seolah pasti.
    var looksConfident: Bool { self == .lock }
}

public extension ConfidenceLevel {
    /// Label Indonesia untuk ditampilkan.
    var displayName: String {
        switch self {
        case .high: return "Yakin"
        case .medium: return "Ragu"
        case .low: return "Tidak tahu"
        }
    }

    /// Nada visual tingkat keyakinan.
    ///
    /// Medium sengaja `warning`, bukan `success`: engine yang ragu harus
    /// terlihat ragu.
    var tone: PointingTone {
        switch self {
        case .high: return .success
        case .medium: return .warning
        case .low: return .danger
        }
    }
}
