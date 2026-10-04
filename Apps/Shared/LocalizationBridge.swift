import Foundation
import PointingKit

/// Menyambungkan katalog string app ke teks yang **dihasilkan** di `PointingKit`.
///
/// **Kenapa berkas ini ada, dan kenapa satu kalimat saja isinya.** Katalog
/// `Localizable.xcstrings` sudah ada dan sudah berisi 63 kunci, tapi semua
/// kuncinya berasal dari literal `Text("...")` di `Apps/`. Label yang paling
/// sering dibaca sekilas justru **tidak pernah melewati literal itu**:
/// "Siap", "Arahkan", "Terkunci", "Kurang yakin", "Sensor mati", kalimat
/// panduannya, "Yakin/Ragu/Tidak tahu" — semuanya di-*switch* di dalam
/// `PointingKit`, jadi tidak ada yang bisa melihatnya dari `Apps/`, dan
/// `SWIFT_EMIT_LOC_STRINGS: NO` membuat Xcode tidak akan mengisinya sendiri.
///
/// Akibatnya teks itu tampil dalam Bahasa Indonesia di **semua** bahasa, dan
/// gerbang aturan 4 tetap hijau karena memang tidak ada literal-nya.
///
/// `TextLocalization` di paket menyelesaikan bagian yang bisa diuji di Linux
/// (nilai bawaan + bentuk kunci). Bagian yang tidak bisa diuji di Linux adalah
/// tepat satu hal: apakah `Bundle` benar-benar membaca `.xcstrings` saat
/// perangkat berjalan. Untuk itu satu pasang baris ini.
///
/// Sengaja dipanggil **dari `App.init()`**, bukan `main` atau saat label
/// pertama dibutuhkan: label bisa dibaca sebelum `body` berjalan, dan Bridge
/// yang belum terpasang akan diam-diam jatuh ke Bahasa Indonesia.
enum LocalizationBridge {

    /// Pasang sumber terjemahan untuk seluruh app.
    ///
    /// `value:` sengaja diisi nama kuncinya sendiri, **bukan** string kosong.
    /// Itu pola yang benar untuk `Bundle.localizedString`: kalau kunci tidak
    /// ada di katalog, hasilnya adalah `value` — dan string kosong akan
    /// membuat baris terlihat kosong tanpa penjelasan saat ada kesalahan.
    ///
    /// **Konsekuensi yang harus diketahui, dan ditangani di `text()`.**
    /// Karena `value:` adalah nama kuncinya, kunci yang hilang dari katalog
    /// tidak muncul sebagai ketiadaan: ia kembali sebagai **nama kunci itu
    /// sendiri**, non-kosong, jadi pemeriksaan "terjemahan tidak kosong" saja
    /// tidak menahannya. `TextLocalization.text` karena itu menolak hasil yang
    /// sama dengan nama kuncinya dan jatuh ke nilai bawaan Bahasa Indonesia.
    /// Perbaikannya ada di paket, bukan di sini, supaya setiap bridge di masa
    /// depan otomatis ikut terlindungi — termasuk yang belum ada sekarang.
    ///
    /// `Bundle.localizedString(forKey:value:table:)` dipilih, bukan
    /// `String(localized:)`, karena yang terakhir tidak ada di Swift 6.0 Linux
    /// sementara yang pertama ada di kedua platform.
    static func install() {
        TextLocalization.install { key in
            Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
    }
}