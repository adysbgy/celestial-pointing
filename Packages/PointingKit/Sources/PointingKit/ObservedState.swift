import Foundation

/// Menentukan nilai yang boleh menjadi **pemicu render** pada `PointingEngine`.
///
/// **Kenapa aturan ini ada, dan kenapa tidak cukup ditulis sebagai komentar.**
/// `PointingEngine` adalah `ObservableObject` yang di-observasi sembilan layar
/// (`PointingView`, `ReducedLuminanceView`, `CalibrationView`, `DiagnosticsView`,
/// `Experiment1View`, `LinkView`, `TelescopeHandoffView`, panel detail, dan
/// layar redup). Setiap properti `@Published` yang berubah memanggil
/// `objectWillChange` **untuk semua** layar itu. Jadi satu properti yang
/// berubah per sampel sensor membayar sembilan redraw — bukan satu.
///
/// Terukur sebelum aturan ini: `sampleCount` dinaikkan 20×/detik di `ingest`
/// dan **tidak dibaca layar mana pun** (baris "Sampel" di layar Diagnostik
/// membaca `motion.sampleCount`, objek yang berbeda). Ia tetap `@Published`,
/// sehingga setiap sampel memicu `objectWillChange` **dua kali** — sekali
/// untuknya, sekali untuk `snapshot` — dan layar redup (Always-On) ikut
/// menggambar ulang dua kali lipat untuk nilai yang tidak pernah muncul.
///
/// Cacatnya tidak bisa ditangkap satu pun dari 52 aturan UI: terukur, properti
/// itu bisa **dihapus seluruhnya** dan `swift-ui-lint.sh` tetap exit 0.
/// `swift-typecheck.sh` hanya `-parse`, dan `swift-test.sh` tidak membangun
/// `Apps/` sama sekali. Jadi angkanya tidak punya penjaga — dan yang tidak
/// punya penjaga akan kembali.
///
/// **Yang dijaga di sini.** Daftar peran properti `.published` milik engine.
/// Setiap properti `.published` yang **membaca** layar wajib berperan
/// `.renderInput`; yang tidak dibaca layar wajib `.bookkeeping`. Uji menuntut
/// daftar ini sama persis dengan kenyataan sumber `PointingEngine`, jadi
/// properti `@Published` baru tidak bisa ditambahkan tanpa memutuskan perannya
/// secara eksplisit — dan properti `.bookkeeping` yang tidak dibaca siapa pun
/// tidak bisa diam-diam berubah menjadi `.published` lagi.
public enum ObservedState {

    /// Peran sebuah properti di `PointingEngine`.
    public enum Role: Equatable, Sendable {
        /// Dibaca layar. Perubahannya **boleh** memicu render.
        case renderInput
        /// Statistik/pembukuan internal. **Tidak** dibaca layar, jadi
        /// perubahannya tidak boleh memicu `objectWillChange`.
        case bookkeeping
    }

    /// Properti `.published` milik `PointingEngine` beserta perannya.
    ///
    /// Urutan tidak bermakna; kumpulannya bermakna. Uji menyamakan ini dengan
    /// daftar `@Published` yang benar-benar ada di sumber.
    public static let roles: [String: Role] = [
        // Dibaca layar, langsung atau lewat aksesor engine.
        "snapshot": .renderInput,
        "location": .renderInput,
        "sensorNote": .renderInput,
        "lastLockedObject": .renderInput,
        "skyContext": .renderInput,
        "slewVerdict": .renderInput,
        "lockArrival": .renderInput,
        // Pembukuan. Tidak ada layar yang membacanya; baris "Sampel" di
        // Diagnostik membaca `MotionLogger.sampleCount`.
        "sampleCount": .bookkeeping,
    ]

    /// Apakah properti bernama `name` boleh memicu render.
    ///
    /// Nama yang tidak dikenal dijawab `false`, bukan `true`: properti baru
    /// yang belum diputuskan perannya harus **diam** sampai ada yang
    /// memutuskan, karena diamnya hanya kehilangan satu render — sementara
    /// berisiknya membayar sembilan redraw per sampel di layar jam.
    public static func canTriggerRender(_ name: String) -> Bool {
        roles[name] == .renderInput
    }

    /// Properti yang wajib **tidak** `@Published`.
    ///
    /// Diturunkan dari `roles`, bukan daftar kedua — dua daftar bisa berbeda
    /// pendapat, dan yang berbeda pendapat di sini tidak terlihat di layar.
    public static var mustNotBePublished: [String] {
        roles.filter { $0.value == .bookkeeping }.keys.sorted()
    }
}
