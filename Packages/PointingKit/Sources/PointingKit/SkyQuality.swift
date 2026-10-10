import Foundation
import CelestialEngine

/// Seberapa gelap langit pengguna (ADR-012).
///
/// **Kenapa ada.** Batas magnitudo bawaan 6.0 adalah angka langit gelap. Di
/// kota seperti Jakarta mata telanjang hanya melihat sampai sekitar
/// magnitudo 3. Dengan 6.0, gugus dan nebula yang **tidak terlihat** (Laguna,
/// Omega, Kupu-kupu) ikut menjadi kandidat: mereka membuat Antares yang jelas
/// terlihat menjadi "Mungkin salah satu ini", dan petunjuk arah bisa mengirim
/// pengguna ke nebula yang tidak bisa ia lihat. Gladi bersih 9 Okt 2026
/// (Docs/WATCH_NOT_SURE_ANALYSIS.md) menunjukkan keduanya.
public enum SkyQuality: String, CaseIterable, Equatable, Sendable {
    /// Langit kota: hanya bintang terang, planet, dan Bulan. Bawaan.
    case city
    /// Langit gelap (luar kota): sampai batas mata telanjang penuh.
    case dark

    public static let `default`: SkyQuality = .city

    /// Kebijakan visibilitas untuk langit ini. Ambang lain tetap bawaan.
    public var visibilityPolicy: VisibilityPolicy {
        switch self {
        case .city:
            // Cahaya kota sudah menenggelamkan bintang redup; cahaya Bulan
            // menambah lebih sedikit di atasnya daripada di langit gelap.
            return VisibilityPolicy(limitingMagnitude: 3.0, moonBrighteningMagnitudes: 0.5)
        case .dark:
            return VisibilityPolicy()
        }
    }
}

/// Penyimpanan pilihan langit (`@AppStorage`): `true` = langit gelap.
public enum SkyQualityStorage {
    public static let darkSkyKey = "skyQuality.darkSky"

    public static func quality(darkSky: Bool) -> SkyQuality { darkSky ? .dark : .city }
}
