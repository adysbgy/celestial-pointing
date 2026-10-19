import Foundation

/// Nilai bawaan preferensi pengguna — **satu sumber**, bukan satu literal per
/// layar.
///
/// Kenapa modul ini ada.
///
/// Preferensi di app ini disimpan di `UserDefaults` lewat `@AppStorage`, dan
/// SwiftUI meminta nilai bawaannya **di setiap situs pemakaian**:
///
///     @AppStorage(NightModeStorage.key) private var nightMode = false
///     @AppStorage(AudioCueStorage.key) private var audioCueEnabled = true
///
/// Jadi satu preferensi punya *dua* sumber kebenaran: literal di layar, dan
/// perilaku aksesor modelnya bila kuncinya belum pernah diset. `AudioCue.isOn`
/// mengembalikan `true` untuk kunci yang tidak ada, sementara `NightMode.isOn`
/// mengembalikan `false`. Selama kedua sisi kebetulan sepakat, tidak ada yang
/// terlihat. Begitu tidak, pengguna mendapat app yang **berbeda perilakunya
/// tergantung layar mana yang membaca lebih dulu** — dan tidak satu pun layar
/// salah.
///
/// Terukur: empat mutasi yang masing-masing hanya membalik satu literal
/// bawaan di `Apps/` (termasuk Mode Malam menjadi nyala sejak pembukaan
/// pertama) semuanya **exit 0** pada seluruh 66 aturan UI. Aturan 57 menjaga
/// *kunci*-nya satu sumber; tidak ada yang menjaga *nilai bawaannya*.
///
/// Karena itu nilai bawaan pindah ke sini, dan layar menulis
/// `= PreferenceDefaults.nightMode` — bukan literal. Uji di Linux menuntut
/// tiap preferensi punya nilai bawaan yang dideklarasikan **dan** bahwa
/// aksesor modelnya di `Apps/` membaca kunci yang belum ada dengan nilai yang
/// sama. Aturan 67 di `swift-ui-lint.sh` menutup sisi yang tidak bisa
/// dieksekusi di Linux: literal `true`/`false` di `@AppStorage` tidak boleh
/// kembali.
///
/// **Yang TIDAK diklaim.** Modul ini tidak membaca `UserDefaults` dan tidak
/// tahu apa yang tersimpan di perangkat pengguna; ia hanya menetapkan apa yang
/// berlaku saat kunci **belum pernah diset**. Dan ia tidak menjamin tiga
/// platform (watchOS/iOS) berbagi satu `UserDefaults` — masing-masing
/// perangkat menyimpan sendiri, sesuai catatan `NightModeStorage`.
public enum PreferenceDefaults {

    /// Preferensi yang disimpan dengan `@AppStorage` di lebih dari satu layar.
    ///
    /// Enum, bukan `Bool` lepas: yang perlu diketahui adalah *preferensi mana*
    /// yang dimaksud, supaya daftar ini bisa dibandingkan terhadap situs
    /// pemakaiannya di `Apps/` — persis pola `ObservedState` untuk `@Published`.
    public enum Key: String, CaseIterable, Sendable {
        /// Mode malam (palet merah). **Mati** saat pertama dibuka: app harus
        /// tampil dalam bahasa visual normalnya dulu, dan merah dipilih
        /// pengguna secara sadar ketika ia keluar mengamati.
        case nightMode
        /// Bunyi pendek saat engine mengunci. **Nyala** — aksesibilitas
        /// multi-modal, bukan gangguan (lihat `AudioCue.isOn`).
        case audioCue
        /// Kartu perkenalan sudah dilihat. **Belum**, karena kalau nyala,
        /// pengguna baru tidak pernah bertemu app ini sama sekali.
        case onboardingSeen
    }

    /// Nama token penyimpanan di `Apps/`, untuk dipakai pesan galat dan
    /// aturan UI.
    ///
    /// Ditulis sebagai pemetaan, bukan dirakit dari nama kasus: kalau enum
    /// penyimpanan baru bernama lain, pemetaan ini yang harus disebut, dan
    /// uji di bawah menuntut **setiap kasus** punya nama token.
    public static func storageToken(for key: Key) -> String {
        switch key {
        case .nightMode: return "NightModeStorage.key"
        case .audioCue: return "AudioCueStorage.key"
        case .onboardingSeen: return "OnboardingStorage.key"
        }
    }

    /// Nama properti memori (`@AppStorage`/`@State`) yang dipakai layar untuk
    /// preferensi ini. Dipakai uji untuk mencari deklarasi di `Apps/`.
    public static func propertyName(for key: Key) -> String {
        switch key {
        case .nightMode: return "nightMode"
        case .audioCue: return "audioCueEnabled"
        case .onboardingSeen: return "onboardingSeen"
        }
    }

    /// Nilai bawaan yang **berlaku** saat kuncinya belum pernah diset.
    ///
    /// Satu-satunya tempat angka ini boleh ditulis. Layar menyebutnya lewat
    /// `@AppStorage(...) = PreferenceDefaults.nightMode`.
    public static func value(for key: Key) -> Bool {
        switch key {
        case .nightMode: return false
        case .audioCue: return true
        case .onboardingSeen: return false
        }
    }

    // MARK: - Pintasan per preferensi
    //
    // **Namanya wajib sama dengan `propertyName(for:)`**, dan itu bukan
    // kerapian: uji menurunkan nama yang diharapkan di layar dari
    // `propertyName`, jadi pintasan yang dinamai lain membuat layar dan uji
    // menunjuk dua nama berbeda untuk satu nilai — persis kelas cacat yang
    // modul ini tutup. Ditemukan oleh ujinya sendiri saat siklus pertama:
    // `audioCue` vs `audioCueEnabled` memerahkan dua situs yang sebenarnya
    // benar.

    public static var nightMode: Bool { value(for: .nightMode) }
    public static var audioCueEnabled: Bool { value(for: .audioCue) }
    public static var onboardingSeen: Bool { value(for: .onboardingSeen) }
}
