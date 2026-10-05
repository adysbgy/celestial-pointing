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
        TextLocalization.text(.objectSpeechMagnitude, value)
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
        TextLocalization.text(.objectSpeechConfidence,
               level.displayName)
    }

    /// "RA 101.3 derajat, deklinasi −16.7 derajat" — koordinat yang terbaca.
    ///
    /// `decDeg` memakai `%+.1f` supaya tandanya ikut diucapkan sebagai bagian
    /// dari angka; tanpa tanda, deklinasi selatan terbaca sama dengan utara.
    public static func coordinates(raDeg: Double, decDeg: Double) -> String {
        TextLocalization.text(.objectSpeechCoordinates,
               raDeg, decDeg)
    }

    /// "RA 101.3° Dec +16.7°" — bentuk **ringkas untuk layar**, bukan suara.
    ///
    /// **Kenapa ini ada padahal `coordinates` sudah ada.** Baris jenis objek di
    /// kartu jam merakit kalimatnya sendiri sebagai literal
    /// (`parts.append(String(format: "RA %.1f° Dec %+.1f°", …))`) — bentuk
    /// yang tidak bisa dijangkau Aturan 4 (bukan argumen `Text(...)`) maupun
    /// Aturan 6 (tanpa kunci). Akibatnya baris itu tampil dalam Bahasa
    /// Indonesia di semua bahasa, dan **tidak ada yang bisa melihatnya**:
    /// derajat sudut sama di mana-mana, jadi tidak ada yang terlihat salah.
    ///
    /// Bentuknya sengaja berbeda dari `coordinates`: layar memakai `°` (mata
    /// membacanya sebagai satuan), suara memakai kata "derajat" (`°` tidak
    /// diucapkan). Dua kunci, dua bentuk — bukan satu bentuk yang dipaksakan
    /// ke dua indera.
    public static func coordinatesDisplay(raDeg: Double, decDeg: Double) -> String {
        TextLocalization.text(.objectDisplayCoordinates,
               raDeg, decDeg)
    }

    /// "magnitudo 1.46" pada layar — bentuk ringkas, `mag` bukan kata.
    ///
    /// Pasangan layar dari `magnitude(_:)`. Dipakai baris jenis objek yang dulu
    /// menulis `String(format: "mag %.2f", …)` sebagai literal.
    public static func magnitudeDisplay(_ value: Double) -> String {
        TextLocalization.text(.objectDisplayMagnitude, value)
    }

    /// Penanda sisa **di layar**, dengan nama objeknya: `"Sirius — bukan hasil
    /// sekarang"`.
    ///
    /// **Kenapa ini ada padahal `staleNote` sudah ada.** `staleNote` adalah
    /// bentuk **suara**: kalimat utuh, tanpa nama, diucapkan sesudah nama
    /// objek. Di layar iPhone nama dan penandanya harus jadi **satu baris**,
    /// dan baris itu dulu dirakit di dalam view sebagai
    /// `"\(object.name) — bukan hasil sekarang"` — literal berinterpolasi.
    /// Aturan 4 melewatinya begitu saja (lihat komentar di
    /// `swift-ui-lint.sh`), jadi kalimat "bukan hasil sekarang" tampil dalam
    /// Bahasa Indonesia di semua bahasa tanpa satu pun gerbang merah.
    ///
    /// **Kenapa namanya ikut sebagai `%@`, bukan digabung di pemanggil.**
    /// Urutan bahasa: dalam bahasa lain penanda bisa harus di **depan** nama
    /// ("not a current result — Sirius"). Kalau penggabungnya di pemanggil,
    /// urutannya terkunci di kode dan terjemahan tidak bisa mengaturnya.
    ///
    /// Ini persis kalimat yang paling tidak boleh salah tempat: tanpa dia,
    /// objek basi terbaca sebagai hasil pengukuran sekarang.
    public static func staleDisplayName(_ name: String) -> String {
        TextLocalization.text(.objectDisplayStaleName, name)
    }

    /// Penanda sisa yang **pendek**, untuk layar yang sengaja miskin.
    ///
    /// Layar redup (Always-On) tidak punya ruang untuk kalimat penuh
    /// `staleNote`; versi ini menyatakan hal yang sama dengan tiga kata.
    /// Tetap punya kunci sendiri supaya tidak lahir sebagai literal di view —
    /// dan tetap **bukan** `"sisa"` satu kata: di layar yang tidak menampilkan
    /// panel peringatan, "sisa" sendirian tidak menjelaskan sisa **apa**.
    public static var staleShortNote: String {
        TextLocalization.text(.objectSpeechStaleShort)
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

    /// Koordinat dalam bentuk **ringkas untuk layar** (`°`, bukan "derajat").
    ///
    /// Dipisah dari `object.speech.coordinates` karena bentuknya berbeda
    /// menurut indera: mata membaca `°` sebagai satuan, suara tidak
    /// mengucapkannya. Baris jenis objek di kartu jam dulu menulis bentuk ini
    /// sebagai literal di dalam `String(format:)`, tempat tidak ada gerbang
    /// yang bisa melihatnya.
    static let objectDisplayCoordinates = LocalizedText(
        key: "object.display.coordinates",
        id: "RA %.1f° Dec %+.1f°")

    /// Magnitudo dalam bentuk **ringkas untuk layar** (`mag`, bukan
    /// "magnitudo"). Pasangan layar dari `object.speech.magnitude`.
    static let objectDisplayMagnitude = LocalizedText(
        key: "object.display.magnitude",
        id: "mag %.2f")

    /// Penanda sisa **di layar**, menggabung nama objek dengan penanda bahwa
    /// itu bukan hasil pengukuran sekarang.
    ///
    /// Nama dimasukkan sebagai `%@`, bukan digabung di pemanggil: urutan
    /// kata adalah milik bahasa, bukan milik kode. Dalam bahasa lain penanda
    /// mungkin harus mendahului nama ("not a current result — Sirius").
    ///
    /// Kunci ini lahir karena bentuknya dulu dirakit sebagai literal
    /// berinterpolasi di dalam view — bentuk yang dilewati Aturan 4 tanpa
    /// laporan, sehingga kalimat ini tidak punya padanan bahasa Inggris
    /// sementara seluruh gerbang hijau.
    static let objectDisplayStaleName = LocalizedText(
        key: "object.display.staleName",
        id: "%@ — bukan hasil sekarang")

    /// Penanda sisa versi pendek untuk layar redup (Always-On).
    ///
    /// Bukan `"sisa"` satu kata: di layar yang tidak punya panel peringatan,
    /// satu kata tidak menjelaskan sisa **apa**, dan yang dibaca pengguna
    /// adalah nama objek yang terlihat persis seperti hasil pengukuran
    /// sekarang — persis false confidence yang dilarang PRD.
    static let objectSpeechStaleShort = LocalizedText(
        key: "object.speech.staleShort",
        id: "sisa pandangan sebelumnya")
}
