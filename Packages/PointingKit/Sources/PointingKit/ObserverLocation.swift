import Foundation
import CelestialEngine

/// Lokasi pengamat, beserta **asal-usulnya**.
///
/// PRD melarang mengasumsikan apa pun soal akurasi — dan itu berlaku juga untuk
/// lokasi. Resolver memakai garis bujur untuk menghitung waktu sidereal; garis
/// bujur yang salah 1° menggeser seluruh langit 1°. Karena itu lokasi tidak
/// pernah ditebak diam-diam: `source` mencatat dari mana angka ini datang, dan
/// percobaan Experiment 1 menyimpan lokasi yang benar-benar dipakai.
public struct ObserverLocation: Codable, Equatable, Sendable {
    public var latitudeDeg: Double
    public var longitudeDeg: Double
    /// Nama tempat, untuk ditampilkan di UI dan laporan.
    public var label: String
    /// Dari mana angka ini: "manual", "corelocation", "simulator".
    /// Rekaman tanpa keterangan asal tidak bisa dipercaya saat analisis.
    public var source: String
    /// Kapan lokasi ini ditetapkan.
    public var capturedAt: Date?

    public init(latitudeDeg: Double,
                longitudeDeg: Double,
                label: String,
                source: String,
                capturedAt: Date? = nil) {
        self.latitudeDeg = latitudeDeg
        self.longitudeDeg = longitudeDeg
        self.label = label
        self.source = source
        self.capturedAt = capturedAt
    }

    /// Bentuk yang dipakai engine.
    public var observer: Observer {
        Observer(latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg)
    }

    /// Apakah koordinatnya masuk akal.
    public var isValid: Bool {
        (-90...90).contains(latitudeDeg)
            && (-180...180).contains(longitudeDeg)
            && latitudeDeg.isFinite && longitudeDeg.isFinite
    }

    /// Lokasi darurat untuk simulator/CI: Jakarta.
    ///
    /// Hanya dipakai saat aplikasi benar-benar tidak punya lokasi. Sengaja
    /// diberi label yang mencolok supaya tidak ada yang salah mengira ini
    /// lokasi pengukuran.
    public static let fallback = ObserverLocation(
        latitudeDeg: -6.2,
        longitudeDeg: 106.8,
        label: "Jakarta (bawaan)",
        source: "fallback"
    )
}
