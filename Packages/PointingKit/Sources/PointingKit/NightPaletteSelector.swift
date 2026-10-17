import Foundation

/// Pemilih palet aktif — **satu** keputusan, di tempat yang bisa diuji.
///
/// Kenapa ini ada di `PointingKit`, bukan di badan `SurfacePalette.active`
/// yang dulu tinggal di `Apps/Shared/SurfaceTokens.swift`.
///
/// Properti itu memilih palet untuk **26 situs** di jam dan iPhone: latar
/// aplikasi, alas kartu, teks utama & sekunder, gradien aksen, garis rambut,
/// warna nada, isi badge, dan layar redup. Ia hidup di `Apps/`, yang **tidak
/// pernah dibangun** `./swift-test.sh` di Linux. Terukur (salinan utuh,
/// proses baru, ke-44 aturan UI dijalankan):
///
///     return NightMode.isOn ? .night : .day    ->  HIJAU
///     return .day                              ->  HIJAU  (buta)
///     return .night                            ->  HIJAU  (buta)
///     return NightMode.isOn ? .day : .night    ->  HIJAU  (buta)
///     return Bool.random() ? .night : .day     ->  HIJAU  (buta)
///
/// Empat keadaan, nol yang berbunyi. Yang paling sunyi bukan yang acak,
/// melainkan `.day` dan `.night`: dengan `.day`, mode malam — satu-satunya
/// mode yang rhodopsin izinkan (batang rod ~498–530nm, cahaya >620nm aman) —
/// **diam-diam memancarkan biru dan hijau penuh** sementara tombol bulan di
/// layar menyala seakan ia aktif. Pengguna yang mengamati bintang lemah lalu
/// kehilangan adaptasi gelapnya 20–40 menit karena satu baris yang tidak ada
/// gerbangnya. Dan tidak ada teks di layar yang membantahnya: labelnya
/// bertuliskan "mode malam", warnanya berkata lain.
///
/// Kenapa Aturan 38/42 tidak menangkapnya: keduanya menurunkan permukaan
/// yang **namanya ada sebagai anggota model**. `active` memang anggota
/// `SurfacePalette`, tetapi badannya tidak menyebut `NightMode` sebagai
/// syarat — ia menyebutnya sebagai **sumber nilai**, dan kedua aturan hanya
/// menuntut "faktanya disebut". `NightMode.isOn ? .day : .night` menyebut
/// `NightMode` dan tetap salah.
///
/// Karena itu kelasnya ditutup secara **struktural**, bukan dengan menambah
/// daftar: pemilihnya adalah fungsi murni yang tidak menerima palet, hanya
/// keadaan saklarnya, dan `Apps/` kehilangan kemampuan menulis cabang itu
/// sendiri.
public enum NightPaletteSelector {

    /// Palet untuk sebuah keadaan saklar mode malam.
    ///
    /// Satu-satunya tempat di repo ini yang boleh memetakan saklar → palet.
    /// `Apps/` memanggilnya; ia tidak bisa lagi mengarang pemetaannya sendiri
    /// tanpa menulis ulang fungsi ini — dan fungsi ini punya uji.
    public static func palette(isNightModeEnabled: Bool) -> SurfacePalette {
        isNightModeEnabled ? .night : .day
    }

    /// Apakah palet yang diberikan benar-benar palet malam.
    ///
    /// Diturunkan dari **isi**, bukan dari keadaan saklar yang menghasilkannya:
    /// kalau dua hal ini bisa berbeda pendapat, layar bisa menampilkan palet
    /// malam sambil mengira dirinya siang (atau sebaliknya), dan tidak ada
    /// gerbang yang akan memberitahu. Ini yang diuji
    /// `testTheSelectedPaletteAgreesWithItsOwnNightClaim`.
    public static func isNight(_ palette: SurfacePalette) -> Bool {
        palette.isNight
    }
}
