import Foundation

/// Apakah bunyi kunci menyala, dibaca dari nilai yang tersimpan.
///
/// **Kenapa ini ada di `PointingKit`, bukan di badan `AudioCue.isOn`.**
///
/// `AudioCue.isOn` di `Apps/Shared/AudioCue.swift` membaca `UserDefaults`
/// dengan aturan yang lebih halus daripada yang terlihat:
///
///     if UserDefaults.standard.object(forKey: key) == nil { return true }
///     return UserDefaults.standard.bool(forKey: key)
///
/// Dua baris itu memutuskan dua hal sekaligus: **nilai bawaan** (belum pernah
/// diset = nyala, karena bunyi kunci adalah aksesibilitas, bukan gangguan) dan
/// **kehormatan terhadap saklar** (sudah diset mati = mati). Keduanya adalah
/// politik, bukan penyimpanan — dan keduanya tinggal di `Apps/`, yang tidak
/// pernah dibangun `./swift-test.sh` di Linux dan tidak punya uji.
///
/// Terukur (`Tools/sapu-buta-apps.py`, salinan pohon utuh, proses baru):
/// badan lama itu bisa diganti menjadi `return true` — mengabaikan saklar
/// pengguna sepenuhnya, sehingga orang yang mematikan bunyi di toolbar tetap
/// mendengarnya di setiap kunci — **tanpa ditangkap kedua gerbang teks**.
///
/// **Koreksi (22 Okt 2026).** Kalimat di atas versi pertamanya berbunyi
/// "lolos seluruh gerbang", dan itu **salah**: `swift test` memerahkannya
/// lewat `PreferenceDefaultsTests`. Kesalahannya bukan di repo, melainkan di
/// alatnya — `sapu-buta-apps.py` menjalankan dua gerbang teks lalu mencetak
/// "LOLOS SELURUH GERBANG", padahal repo punya gerbang ketiga yang membaca
/// teks `Apps/`. Alatnya kini menjalankan ketiganya **dan** memasang kontrol
/// positif yang membuktikan gerbang ketiga benar-benar berbunyi sebelum satu
/// pun verdict "LOLOS" dipakai.
///
/// **Cacat yang tetap nyata setelah koreksi itu**, dan alasan modul ini tetap
/// ada: membalik nilai di dalam cabang (`== nil { return true }` menjadi
/// `return false`) — yaitu membuat "belum diset" berarti **mati** —
/// mengompilasi bersih, lolos kedua gerbang teks, dan lolos uji bentuk-teks
/// yang lama, karena uji itu memeriksa **keberadaan** cabangnya, bukan
/// perilakunya. Itu cacat yang tidak bisa ditangkap pembacaan teks sama
/// sekali: ia hanya terlihat dengan menjalankan keputusannya. Di sini ia
/// dijalankan.
///
/// Karena itu keputusannya dipindah ke sini sebagai fungsi murni atas nilai
/// yang **sudah dibaca**: `Apps/` tetap pemilik `UserDefaults` (ia yang tahu
/// kuncinya dan tahu bedanya "belum diset" dari "diset `false`"), dan yang
/// diuji adalah apa yang harus dilakukan dengan kedua keadaan itu.
public enum AudioPreference {

    /// Nilai bawaan saat pengguna belum pernah menyentuh saklarnya.
    ///
    /// **Nyala.** Bunyi kunci adalah saluran aksesibilitas untuk pengguna yang
    /// tidak melihat layar; default mati akan membuat saluran itu tidak pernah
    /// ditemukan orang yang paling membutuhkannya. Ini juga alasan
    /// `AudioCue.isOn` memakai `object(forKey:)`: `bool(forKey:)` membaca
    /// "belum diset" sebagai `false`, yang membalik default ini tanpa
    /// ada yang memintanya.
    public static let defaultEnabled = true

    /// Apakah bunyi harus berbunyi, dari nilai tersimpan yang mungkin kosong.
    ///
    /// - Parameter stored: nilai di `UserDefaults`, atau `nil` bila kuncinya
    ///   belum pernah diset. Pemanggil **wajib** membedakan kedua kasus itu
    ///   sebelum memanggil — `Bool?` di sini ada justru supaya perbedaan itu
    ///   tidak bisa hilang di perjalanan menjadi `false`.
    ///
    /// Mengembalikan `stored` apa adanya bila ada, dan `defaultEnabled` bila
    /// tidak. Tidak ada cabang lain: saklar pengguna tidak boleh ditimpa
    /// alasan apa pun, termasuk "aksesibilitas".
    public static func isEnabled(stored: Bool?) -> Bool {
        stored ?? defaultEnabled
    }
}
