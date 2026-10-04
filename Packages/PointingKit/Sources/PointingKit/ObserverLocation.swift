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

    /// Apakah ini lokasi darurat, bukan lokasi pengukuran.
    ///
    /// Dipakai UI untuk memperingatkan bahwa tinggi benda langit yang
    /// ditampilkan dihitung untuk tempat lain. Tanpa peringatan itu, daftar
    /// target yang salah tempat akan tampak sama normalnya dengan yang benar.
    public var isFallback: Bool { source == ObserverLocation.fallbackSource }

    /// Nilai `source` untuk lokasi darurat.
    public static let fallbackSource = "fallback"

    /// Apakah dua lokasi ini **tempat yang sama**, sejauh yang berarti bagi
    /// langit.
    ///
    /// Dipakai untuk membedakan perpindahan tempat yang sungguhan dari getaran
    /// GPS. `ObserverLocation` membawa `capturedAt`, jadi dua pembaruan dari
    /// tempat yang sama **tidak** pernah `==` — dan memperlakukannya sebagai
    /// perpindahan berarti seluruh langit dihitung ulang, alur dihentikan, dan
    /// jam tampak berubah pikiran tiap detik, padahal penggunanya diam.
    ///
    /// Ambang bawaannya dari geseran langit: 1° bujur menggeser langit 1°, jadi
    /// 0.01° ≈ 36″ — jauh di bawah sigma pointing mana pun yang masuk akal.
    /// Getaran GPS puluhan meter hanya ≈ 0.0005°, sepuluh kali lebih kecil dari
    /// ambang ini.
    public func isSamePlace(as other: ObserverLocation, toleranceDeg: Double = 0.01) -> Bool {
        guard isValid, other.isValid else { return false }
        return abs(latitudeDeg - other.latitudeDeg) <= toleranceDeg
            && abs(longitudeDeg - other.longitudeDeg) <= toleranceDeg
    }

    /// Lokasi darurat untuk simulator/CI: Jakarta.
    ///
    /// Hanya dipakai saat aplikasi benar-benar tidak punya lokasi. Sengaja
    /// diberi label yang mencolok supaya tidak ada yang salah mengira ini
    /// lokasi pengukuran.
    ///
    /// **Kenapa `var` computed, bukan `let`.** `label` ditampilkan apa adanya —
    /// `PointingView` menulis `Text("Lokasi: \(engine.location.label)")` dan
    /// baris rinciannya. Sebelumnya teksnya literal di sini, jadi pengguna
    /// Bahasa Inggris membaca "Jakarta (bawaan)" dalam Bahasa Indonesia;
    /// literalnya tak terlihat Aturan 4 (bukan argumen `Text(...)`) dan tak
    /// punya kunci untuk diperiksa Aturan 6 — celah yang sama seperti
    /// `LinkStatusText`.
    ///
    /// Kalau ini `static let`, labelnya **beku pada akses pertama**. Bridge
    /// terjemahan dipasang saat app diluncurkan; siapa pun yang menyentuh
    /// `.fallback` lebih dulu akan mengunci label Indonesia untuk selamanya.
    /// Karena itu nilainya dihitung ulang tiap akses — murah (satu struct
    /// kecil), dan selalu mengikuti bahasa yang sedang aktif.
    public static var fallback: ObserverLocation {
        ObserverLocation(
            latitudeDeg: -6.2,
            longitudeDeg: 106.8,
            label: TextLocalization.text(.locationFallbackLabel),
            source: fallbackSource
        )
    }
}

public extension LocalizedText {

    /// Label lokasi darurat. Nilai `id` sengaja **tetap** "Jakarta (bawaan)"
    /// supaya perilaku tanpa bridge (Linux, uji) persis seperti sebelumnya.
    static let locationFallbackLabel = LocalizedText(
        key: "location.fallback.label",
        id: "Jakarta (bawaan)")
}
