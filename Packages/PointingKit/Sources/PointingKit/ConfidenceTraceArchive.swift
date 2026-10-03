import Foundation
import CelestialEngine

/// Arsip riwayat keyakinan: sampel **beserta konteksnya**.
///
/// **Kenapa konteks ikut disimpan.** `ratioToSigma` hanya bisa ditafsirkan kalau
/// kita tahu sigma mana yang berlaku saat sampel itu diambil. Berkas yang hanya
/// berisi derajat/jarak adalah anekdot: 5° berarti "sangat dekat" pada sigma 10°
/// dan "jauh" pada sigma 1°. Karena itu lokasi, kalibrasi, dan sigma yang dipakai
/// ikut ditulis — supaya orang yang membuka berkas ini enam bulan lagi bisa
/// menyimpulkan hal yang sama seperti saat perekaman.
///
/// Sampel dari jam sengaja **tidak** diberi jarak kandidat karangan: jam tidak
/// mengirim sudut pergelangan ke perangkat lain, jadi `separationDeg`-nya memang
/// kosong. Mengisinya dengan angka apa pun akan membuat riwayat ini berbohong
/// tentang apa yang sebenarnya diukur.
public struct ConfidenceTraceExport: Codable, Equatable, Sendable {
    public var createdAt: Date
    /// Lokasi yang dipakai saat merekam. `nil` bila pemanggil tidak punya.
    public var location: ObserverLocation?
    /// Kalibrasi yang terpasang saat merekam.
    public var calibration: PointingCalibration
    /// Sigma pointing yang berlaku saat merekam (derajat).
    public var confidenceSigmaDeg: Double
    public var samples: [ConfidenceSample]

    public init(createdAt: Date = Date(),
                location: ObserverLocation?,
                calibration: PointingCalibration,
                confidenceSigmaDeg: Double,
                samples: [ConfidenceSample]) {
        self.createdAt = createdAt
        self.location = location
        self.calibration = calibration
        self.confidenceSigmaDeg = confidenceSigmaDeg
        self.samples = samples
    }

    /// Jumlah sampel yang punya jawaban (lock/uncertain).
    public var answeredCount: Int { samples.filter { $0.state.hasAnswer }.count }
    /// Jumlah sampel yang datang dari jam, bukan dari iPhone ini sendiri.
    public var watchSampleCount: Int { samples.filter { $0.fromWatch }.count }
    public var lockCount: Int { samples.filter { $0.state == .lock }.count }
    public var uncertainCount: Int { samples.filter { $0.state == .uncertain }.count }
}

/// Ekspor/impor riwayat keyakinan sebagai JSON.
///
/// Memakai pengekod arsip yang sama dengan `DatasetArchive`
/// (`JSONEncoder.pointingArchive()`), sehingga waktu berpecahan detik tidak
/// hilang dan urutan sampel tetap bisa direkonstruksi. Dua format ekspor yang
/// berbeda di satu proyek cepat atau lambat akan menghasilkan berkas yang salah
/// dibaca.
public enum ConfidenceTraceArchive {

    /// Bangun arsip dari riwayat + konteks yang berlaku sekarang.
    public static func export(from trace: ConfidenceTrace,
                              location: ObserverLocation?,
                              calibration: PointingCalibration,
                              confidenceSigmaDeg: Double,
                              at date: Date = Date()) -> ConfidenceTraceExport {
        ConfidenceTraceExport(createdAt: date,
                              location: location,
                              calibration: calibration,
                              confidenceSigmaDeg: confidenceSigmaDeg,
                              samples: trace.samples)
    }

    public static func encode(_ export: ConfidenceTraceExport) throws -> Data {
        try JSONEncoder.pointingArchive().encode(export)
    }

    public static func decode(_ data: Data) throws -> ConfidenceTraceExport {
        try JSONDecoder.pointingArchive().decode(ConfidenceTraceExport.self, from: data)
    }

    /// Nama berkas dengan stempel waktu UTC, supaya ekspor tidak saling menimpa.
    public static func suggestedFilename(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "confidence-trace-\(formatter.string(from: date))Z.json"
    }
}
