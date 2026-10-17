import Foundation

/// Pola getaran yang boleh dipakai untuk tiap peristiwa — satu keputusan, di
/// tempat yang bisa diuji.
///
/// **Kenapa ini ada di `PointingKit`, bukan di `Apps/HapticEngine.swift`.**
/// Berkas itu memetakan peristiwa ke pola `WKHapticType`:
///
///     case .lockSucceeded:     device.play(.success)
///     case .uncertain:         device.play(.retry)
///
/// Perbedaan itu **bukan hiasan**. Getaran adalah satu-satunya saluran yang
/// tidak butuh mata saat jam diangkat — tepat situasi produk ini. Kalau
/// `.uncertain` berbunyi pola yang sama dengan `.lockSucceeded`, pengguna yang
/// mengandalkan getaran tidak punya cara apa pun membedakan "terkunci" dari
/// "kurang yakin", dan seluruh janji PRD bahwa keduanya berbeda berhenti
/// bermakna di saluran yang paling sering dipakai.
///
/// Diukur pada salinan utuh (proses baru, ke-46 aturan UI dijalankan atas
/// `Apps/`), dengan mutasi yang mengompilasi:
///
///     case .uncertain: device.play(.retry)     ->  HIJAU
///     case .uncertain: device.play(.success)   ->  HIJAU  (buta)
///
/// Dua keadaan, nol yang berbunyi. Kelasnya sama dengan `AudioEventPolicy`:
/// keputusan PRD yang hidup di `Apps/`, yang tidak pernah dibangun
/// `swift-test.sh` di Linux, dan tidak punya nama permukaan yang bisa
/// ditambat Aturan 38/42.
///
/// **Kenapa pola diwakili enum sendiri, bukan `WKHapticType`.** `WatchKit`
/// tidak ada di Linux, jadi tipe itu tidak bisa diuji di sini. Yang diuji
/// adalah **yang bisa salah**: peristiwa mana mendapat pola mana, dan bahwa
/// pola "ragu" tidak pernah sama dengan pola "berhasil". Pemetaan pola ke
/// `WKHapticType` tetap di `Apps/` — ia satu baris `switch` tanpa keputusan,
/// dan salah ketik di sana akan terlihat sebagai getaran yang tidak berbunyi.
///
/// **Kenapa nama kasusnya `completed`/`unsettled`/`failed`/`tick`, bukan
/// `success`/`retry`/`failure`/`click`.** Nama pertama yang dipakai adalah
/// `success` dan `failure` — dan gerbang Aturan 25 langsung memerah:
///
///     Apps/PointAndKnowiOS/Sources/TelescopeHandoffView.swift:99:
///     `switch result` melewatkan ['click', 'retry'] dari `['HapticPattern']`
///
/// `switch result` itu men-switch `Result<TelescopeCommand, Error>`, yang
/// kasusnya `success`/`failure`. Gerbangnya mencocokkan **himpunan label**
/// ke himpunan kasus enum yang dikenal, dan `{success, failure}` adalah
/// subset dari `HapticPattern` versi lama — jadi ia menyimpulkan (dengan
/// benar, menurut informasi yang ada) bahwa ada `switch` yang tidak lengkap.
///
/// Gerbangnya **tidak** dilonggarkan: ia baru saja menangkap kesalahan
/// kompilasi nyata yang hanya muncul di macOS. Yang diubah adalah nama, supaya
/// tidak ada dua enum berbeda yang berbagi himpunan label — `Result` sudah
/// memakai `success`/`failure` di seluruh `Apps/`, dan meminjamnya lagi berarti
/// setiap `switch` atas `Result` menjadi ambigu bagi pembaca maupun gerbang.
public enum HapticPattern: String, Equatable, Sendable {
    /// Pola jelas, terasa "selesai".
    case completed
    /// Pola berbeda, terasa "belum".
    case unsettled
    /// Pola kegagalan.
    case failed
    /// Ketukan ringan untuk perpindahan yang bukan hasil.
    case tick
}

/// Pemetaan peristiwa → pola getaran.
public enum HapticPolicy {

    /// Pola untuk satu peristiwa.
    ///
    /// `nil` berarti peristiwa ini **tidak** bergetar. Saat ini tidak ada
    /// peristiwa seperti itu — keempatnya bergetar — tetapi bentuknya
    /// opsional supaya penambahan peristiwa baru di masa depan harus
    /// memutuskan secara sadar, bukan mewarisi pola peristiwa terakhir.
    public static func pattern(for event: HapticEvent) -> HapticPattern? {
        switch event {
        case .lockSucceeded:
            // Satu-satunya pola yang boleh terasa "selesai".
            return .completed
        case .uncertain:
            // **Wajib berbeda dari `.success`.** Ini inti dari berkas ini:
            // kalau dua peristiwa ini bertemu di pola yang sama, pengguna
            // yang tidak melihat layar kehilangan satu-satunya pembeda yang
            // mereka punya.
            return .unsettled
        case .sensorUnavailable:
            return .failed
        case .returnedToIdle:
            return .tick
        }
    }

    /// Apakah dua peristiwa terasa berbeda saat diraba.
    ///
    /// Dipakai uji, dan sengaja menjadi **fungsi**, bukan pemeriksaan
    /// sebaris: pertanyaan "apakah ragu terasa seperti berhasil" adalah
    /// pertanyaan yang harus bisa ditanyakan tanpa menyalin pemetaannya.
    public static func feelDifferent(_ a: HapticEvent,
                                     _ b: HapticEvent) -> Bool {
        pattern(for: a) != pattern(for: b)
    }
}
