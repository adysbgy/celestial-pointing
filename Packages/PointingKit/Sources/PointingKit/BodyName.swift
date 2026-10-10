import CelestialEngine

/// Nama benda tata surya untuk ditampilkan, **dalam bahasa aktif**.
///
/// **Kenapa berkas ini ada.** `EphemerisBody.displayName` mengembalikan
/// bentuk Bahasa Indonesia yang dibekukan — `"Saturnus"`, `"Bulan"`,
/// `"Merkurius"`, `"Matahari"` — sementara tiga nama lain kebetulan sama
/// di dua bahasa (`"Jupiter"`, `"Mars"`, `"Venus"`). Kata itu adalah
/// **paling menonjol di layar**: judul kartu jam tangan, versi
/// always-on, headline komplikasi, dan baris Diagnostics. Saat bahasa
/// perangkat English, app diam-diam mencampur `Moon` dengan `Saturnus`.
///
/// Bentuk Indonesian dikembalikan persis oleh `displayName`, jadi data
/// asli tak berubah — yang berubah hanya **salinannya di layar**.
///
/// Bintang dan objek langit dalam **tidak** ikut: `Sirius` dan `M42`
/// adalah nama bakunya, sama di semua bahasa.
public enum BodyName {

    /// Teks untuk `body` dalam bahasa aktif.
    ///
    /// Bentuk Bahasa Indonesia selalu tersedia di dalam paket (lihat
    /// `indonesian`), jadi fungsi ini **tidak pernah kosong** — penting
    /// karena seluruh test Linux berjalan tanpa berkas `.xcstrings`.
    public static func text(_ body: EphemerisBody) -> String {
        TextLocalization.text(declaration(for: body))
    }

    /// Deklarasi `LocalizedText` untuk `body`.
    ///
    /// Nilai Indonesianya diambil dari `displayName` **bukan ditulis ulang**,
    /// supaya mustahil ada kata yang melenceng dari basis data.
    public static func declaration(for body: EphemerisBody) -> LocalizedText {
        LocalizedText(key: catalogKey(for: body), id: body.displayName)
    }

    /// Kunci katalog untuk `body`.
    ///
    /// Namespaced dan tanpa spasi, mengikuti aturan yang sama seperti
    /// seluruh kunci lain di katalog.
    public static func catalogKey(for body: EphemerisBody) -> String {
        switch body {
        case .sun: return "object.body.sun.label"
        case .moon: return "object.body.moon.label"
        case .mercury: return "object.body.mercury.label"
        case .venus: return "object.body.venus.label"
        case .mars: return "object.body.mars.label"
        case .jupiter: return "object.body.jupiter.label"
        case .saturn: return "object.body.saturn.label"
        }
    }
}