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

public extension PointingSnapshot {

    /// Objek yang layak ditampilkan di panel detail.
    ///
    /// Saat keadaan punya jawaban (`lock`/`uncertain`) itu jawaban engine.
    /// Saat `searching`, objek terakhir yang pernah terkunci dipertahankan
    /// supaya panel tidak kosong hanya karena pergelangan bergerak sedikit —
    /// dan panel itu **wajib** ditandai lewat `isDisplayingStaleObject`.
    ///
    /// Logikanya ditaruh di sini, bukan di pembungkus UI, karena ia menegakkan
    /// aturan PRD: objek lama tidak boleh tampil seolah hasil pengukuran
    /// sekarang. Di sini ia bisa diuji di Linux bersama janji tampilan lain.
    func displayedObject(lastLocked: CelestialObject?) -> CelestialObject? {
        if let best = intent?.best { return best }
        return state == .searching ? lastLocked : nil
    }

    /// Apakah objek yang ditampilkan adalah sisa dari pandangan sebelumnya.
    ///
    /// **Yang menentukan adalah apakah keadaan punya jawaban sekarang**
    /// (`state.hasAnswer`), bukan dari mana objek itu diambil. Mesin keadaan
    /// sengaja mempertahankan `intent` supaya tampilan tidak berkedip, jadi
    /// `intent?.best` tetap terisi objek **dari arah tunjuk sebelumnya** saat
    /// keadaan sudah kembali `pointing`. Menilai "basi" dari `intent?.best ==
    /// nil` karena itu justru melaporkan "bukan sisa" untuk objek yang paling
    /// basi — dan peringatan di layar tidak pernah bisa muncul.
    func isDisplayingStaleObject(lastLocked: CelestialObject?) -> Bool {
        displayedObject(lastLocked: lastLocked) != nil && !state.hasAnswer
    }

    /// Objek yang berlaku **untuk arah tunjuk sekarang**.
    ///
    /// `bestObject` sengaja mempertahankan objek terakhir supaya panel jam tidak
    /// berkedip saat pergelangan bergerak sedikit — itu benar untuk tampilan,
    /// yang menandai objek sisa sebagai sisa. Untuk apa pun yang **mengirim atau
    /// merekam** "apa yang engine katakan sekarang" (pesan ke iPhone, riwayat
    /// keyakinan), objek yang dipertahankan itu bukan jawaban: ia berasal dari
    /// arah tunjuk sebelumnya. Yang berlaku hanya saat keadaan punya jawaban.
    var answeredObject: CelestialObject? { state.hasAnswer ? intent?.best : nil }

    /// Tingkat keyakinan yang berlaku untuk arah tunjuk sekarang.
    ///
    /// `nil` saat keadaan tidak punya jawaban — termasuk saat `intent` masih
    /// membawa keyakinan lama. Keyakinan yang menempel pada keadaan tanpa
    /// jawaban adalah klaim yang tidak berlaku.
    var answeredLevel: ConfidenceLevel? { state.hasAnswer ? intent?.level : nil }

    /// Jarak kandidat terbaik ke arah tunjuk, hanya bila ada jawaban sekarang.
    ///
    /// Ini angka yang dipakai `ConfidenceModel` untuk memutuskan; jarak dari
    /// resolusi lama bukan jarak sekarang, jadi ia tidak boleh ikut terekam.
    var answeredSeparationDeg: Double? {
        state.hasAnswer ? intent?.candidates.first?.separationDeg : nil
    }
}
