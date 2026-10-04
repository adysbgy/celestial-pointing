import Foundation
import CelestialEngine

/// Kalimat pendek yang dipakai **hanya** oleh pengumuman VoiceOver untuk panel
/// objek.
///
/// **Kenapa ini ada.** Frasa-frasa ini dulu hidup sebagai literal di dalam
/// `PointingView` (jam) dan `DiagnosticsView` (iPhone). Keduanya tampil di
/// layar bagi pengguna VoiceOver, tetapi tidak satu pun bisa dijangkau katalog
/// string: aturan 4 menyapu literal `Text("…")` dan `row("…", …)`, sedangkan
/// frasa ini disusun lewat `String(format:)` dan `parts.append(…)` di dalam
/// helper — bentuk yang bukan argumen langsung mana pun. Akibatnya pengguna
/// Bahasa Inggris mendengar "magnitudo 1.46", "tingkat keyakinan Yakin", dan
/// "Sisa pandangan sebelumnya, bukan hasil sekarang." tanpa satu pun gerbang
/// merah.
///
/// **Kenapa di paket, bukan di view.** Frasa ini muncul di **dua** app. Versi
/// sebelumnya menyalinnya di kedua tempat, dan salinan itu sudah mulai
/// berbeda: `DiagnosticsView` memisahkan bagiannya dengan ". " sedangkan
/// `PointingView` memakai ", ". Perbedaan pemisah masih bisa dibaca; yang
/// berbahaya adalah kalimatnya sendiri — cukup satu salinan diperbaiki dan
/// pengguna kedua app mendengar dua kalimat berbeda untuk objek yang sama.
/// Lewat sini keduanya membaca frasa yang sama, dan katalognya satu.
///
/// **Batasnya.** Tipe ini hanya menyediakan **potongan** kalimat; urutan dan
/// pemisahnya tetap milik tiap layar, karena kedua panel memang disusun
/// berbeda (jam memasukkan RA/Dec dan tingkat keyakinan, iPhone memisahkan
/// detail teknis ke pembukaan panel). Yang dijaga di sini adalah bahannya,
/// bukan susunannya.
public enum ObjectSpeech {

    /// "magnitudo 1.46" — nilai magnitudo dengan katanya.
    ///
    /// Angka tidak pernah diucapkan sendirian: "1.46" tanpa "magnitudo" tidak
    /// memberi tahu apa pun, dan singkatan "mag" yang dipakai di layar tidak
    /// terbaca saat diucapkan.
    public static func magnitude(_ value: Double) -> String {
        String(format: TextLocalization.text(.objectSpeechMagnitude), value)
    }

    /// Penanda bahwa objek yang diumumkan berasal dari pandangan sebelumnya.
    ///
    /// Ini wajib ikut diucapkan: tanpa ia, gambar objek basi terdengar persis
    /// seperti hasil pengukuran sekarang — false confidence dalam bentuk audio.
    public static var staleNote: String {
        TextLocalization.text(.objectSpeechStale)
    }

    /// "tingkat keyakinan Yakin" — tingkat keyakinan dengan katanya.
    public static func confidence(_ level: ConfidenceLevel) -> String {
        String(format: TextLocalization.text(.objectSpeechConfidence),
               level.displayName)
    }

    /// "RA 101.3 derajat, deklinasi −16.7 derajat" — koordinat yang terbaca.
    ///
    /// `decDeg` memakai `%+.1f` supaya tandanya ikut diucapkan sebagai bagian
    /// dari angka; tanpa tanda, deklinasi selatan terbaca sama dengan utara.
    public static func coordinates(raDeg: Double, decDeg: Double) -> String {
        String(format: TextLocalization.text(.objectSpeechCoordinates),
               raDeg, decDeg)
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    /// Kunci dan nilai bawaan untuk frasa pengumuman panel objek.
    static let objectSpeechMagnitude = LocalizedText(
        key: "object.speech.magnitude",
        id: "magnitudo %.2f")
    static let objectSpeechStale = LocalizedText(
        key: "object.speech.stale",
        id: "Sisa pandangan sebelumnya, bukan hasil sekarang.")
    static let objectSpeechConfidence = LocalizedText(
        key: "object.speech.confidence",
        id: "tingkat keyakinan %@")
    static let objectSpeechCoordinates = LocalizedText(
        key: "object.speech.coordinates",
        id: "RA %.1f derajat, deklinasi %+.1f derajat")
}
