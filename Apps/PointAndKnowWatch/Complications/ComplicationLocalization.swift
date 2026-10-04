import Foundation
import PointingKit

/// Sumber terjemahan untuk **complication** jam.
///
/// **Kenapa ini bukan `LocalizationBridge` milik app.** Complication adalah
/// target terpisah: ia tidak menarik `Apps/Shared` sebagai sumber kode (hanya
/// `Apps/Shared/Complication`, yaitu store), jadi berkas bridge yang ada di
/// sana tidak ikut ter.build ke dalam bundelnya. Instalasi di sana adalah
/// keputusan yang benar untuk app — bridge harus siap sebelum label pertama
/// dibaca — tapi tidak menjangkau widget di sebelahnya.
///
/// **Yang sebenarnya hilang tanpa berkas ini** bukan cuma terjemahan.
/// `ComplicationDigest.headline` memanggil `PointingState.shortLabel`, dan
/// itu memanggil `TextLocalization.text` di dalam `PointingKit`. Tanpa
/// sumber terjemahan, teksnya jatuh ke nilai bawaan Bahasa Indonesia — jadi
/// complication **selalu** berbahasa Indonesia, untuk pengguna yang memilih
/// bahasa Inggris, dan tidak ada apa pun di layar yang menyatakan itu.
///
/// Catatan jujur soal urutannya: katalog saja tidak cukup. Katalog
/// harus ikut terbawa ke dalam bundel complication (lihat entri `sources`
/// di `project.yml`), dan `Bundle.main` di dalam proses extension menunjuk
/// ke bundel widget itu sendiri — bukan ke app jam. Dua hal itu harus
/// sama-sama benar; kalau hanya satu, hasilnya tetap Bahasa Indonesia
/// tanpa penjelasan.
///
/// Yang dijaga `TextLocalization.text`, bukan di sini: hasil lookup yang
/// sama dengan nama kuncinya ditolak di paket, jadi bentuk yang dipakai di
/// sini (`value: key`) aman bahkan kalau katalognya tidak ikut terbawa —
/// pemanggilnya jatuh ke Bahasa Indonesia, bukan ke pengenal mentah.
enum ComplicationLocalization {

    /// Pasang sumber terjemahan untuk widget.
    ///
    /// Dipanggil dari `ComplicationProvider.init()` — satu titik yang
    /// dijamin berjalan sebelum timeline dirender. `TextLocalization.install`
    /// aman dipanggil berkali-kali, jadi urutan pemanggilan tidak penting;
    /// yang penting bridge **sudah ada** saat label pertama dihitung.
    static func install() {
        TextLocalization.install { key in
            Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
    }
}
