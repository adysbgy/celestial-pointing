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

    /// Label **untuk dibaca orang** bagi `source`.
    ///
    /// **Kenapa accessor ini harus ada, padahal `source` sudah ada.**
    /// `source` adalah bentuk kabel: ia diserialisasi ke JSON arsip
    /// (`ConfidenceTraceArchive`) dan dibandingkan dengan `==`. Menampilkannya
    /// apa adanya berarti pengguna membaca `corelocation` — pengenal mesin di
    /// baris yang justru ditulis untuk menjawab "langit ini dihitung untuk
    /// mana?". Itu cacat yang sama dengan `sirius` di headline Experiment 1 dan
    /// `stateRequest` di layar Tautan: nilai untuk mesin yang tersaji sebagai
    /// teks untuk orang.
    ///
    /// Sengaja **bukan** enum: `source` dibaca dari berkas ekspor yang sudah
    /// tersimpan, dan nilai yang tidak dikenal tidak boleh membuat lokasi gagal
    /// didekode. Karena itu yang tidak dikenal jatuh ke label "tidak
    /// diketahui", bukan ke `nil` dan bukan ke tebakan.
    ///
    /// Dihitung saat dibaca, bukan disimpan: `TextLocalization` bisa berganti
    /// bahasa setelah lokasi ini dibuat (alasan yang sama dengan
    /// `ObserverLocation.fallback` di bawah).
    public var sourceDisplayName: String {
        switch sourceText {
        case .locationSourceUnknown:
            // Satu-satunya bentuk berspecifier: nama sumbernya ikut ditampilkan
            // supaya dua sumber tak dikenal tidak tampak identik.
            return TextLocalization.text(sourceText, source)
        default:
            return TextLocalization.text(sourceText)
        }
    }

    /// Kunci katalog untuk label asal lokasi ini.
    ///
    /// Nilai bawaan sengaja memuat **nama sumbernya** untuk yang tak dikenal
    /// (`location.source.unknown` berisi `%@`): menyembunyikan sumber yang
    /// tidak dikenal di balik kata "Tidak diketahui" saja akan membuat dua
    /// sumber berbeda tampak identik persis pada baris yang dipakai untuk
    /// memutuskan apakah langitnya bisa dipercaya.
    public var sourceText: LocalizedText {
        switch source {
        case "corelocation":           return .locationSourceCoreLocation
        case ObserverLocation.fallbackSource: return .locationSourceFallback
        case "manual":                 return .locationSourceManual
        case "simulator":              return .locationSourceSimulator
        default:                       return .locationSourceUnknown
        }
    }

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
