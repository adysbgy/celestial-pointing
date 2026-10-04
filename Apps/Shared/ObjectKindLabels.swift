import CelestialEngine

/// Label jenis benda dalam Bahasa Indonesia, dipakai **jam dan iPhone**.
///
/// Kenapa satu tempat: label ini muncul di panel detail jam dan panel detail
/// iPhone, dan dua salinan akan cepat berbeda ("Planet" vs "Benda tata
/// surya") — lalu nama yang sama untuk benda yang sama akan tampil berbeda di
/// dua layar. Maka ini diletakkan di Shared, bukan di masing-masing view.
///
/// Sengaja **tidak** berupa `String(describing:)` atas enum: label enum
/// berbahasa Inggris ("deepSky") tidak boleh sampai ke layar, dan reflection
/// bisa berubah antar-bahasa sistem.
extension ObjectKind {

    /// Nama jenis untuk ditampilkan ke pengguna.
    var displayName: String {
        switch self {
        case .star: return "Bintang"
        case .planet: return "Planet"
        case .moon: return "Bulan"
        case .sun: return "Matahari"
        case .deepSky: return "Objek langit dalam"
        }
    }

    /// Label jenis untuk **diucapkan** (VoiceOver).
    ///
    /// Bedanya dengan `displayName`: "Objek langit dalam" adalah frasa
    /// majemuk yang terdengar janggal saat diucapkan, jadi pengucapannya
    /// ditulis eksplisit.
    var spokenName: String {
        switch self {
        case .deepSky: return "objek langit jauh"
        case .star: return "bintang"
        case .planet: return "planet"
        case .moon: return "bulan"
        case .sun: return "matahari"
        }
    }
}