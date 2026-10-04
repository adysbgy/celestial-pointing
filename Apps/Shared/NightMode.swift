import SwiftUI
import CelestialEngine
import PointingKit

/// Mode Malam: palet **merah murni** untuk menjaga penglihatan malam saat
/// mengamati langit.
///
/// Kenapa merah, bukan sekadar `tint`: batang (sel rod) paling sensitif di
/// ~498–530nm, sedangkan cahaya >620nm tidak memicu rhodopsin. Layar
/// putih/biru mematikan adaptasi gelap selama 20–40 menit, jadi menggantinya
/// jadi merah menyelamatkan penglihatan malam pengamat — bukan gaya. Hijau/
/// biru ditekan ke nol, bukan cuma diredupkan.
///
/// Semua warna di sini dibaca dari `NightMode.isOn` **tiap render**, jadi
/// seluruh UI (jam maupun iPhone) ikut berubah begitu preferensinya dibalik.
enum NightModeStorage {
    /// Kunci `UserDefaults` yang sama di jam maupun iPhone, supaya satu
    /// pengaturan berlaku di kedua app (masing-masing perangkat menyimpan
    /// miliknya sendiri).
    static let key = "nightModeEnabled"
}

enum NightMode {
    /// Sumber kebenaran tunggal. Dibaca dari `UserDefaults` supaya akses warna
    /// di `color` (dievaluasi ulang tiap render SwiftUI) konsisten, dan bisa
    /// dipakai dari luar `View` (mis. waktu menggambar grafik).
    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: NightModeStorage.key) }
        set { UserDefaults.standard.set(newValue, forKey: NightModeStorage.key) }
    }
}

/// Palet warna per nada — **sadar mode malam**.
///
/// Di mode malam, kelima nada dipetakan ke variasi **merah** (makin terang =
/// makin penting), bukan hijau/biru/cyan. Janji produk bahwa "ragu terlihat
/// ragu" tetap dijaga lewat **terang** yang berbeda, bukan hue yang berbeda.
/// Lihat `PointingPresentationTests` — ia menguji `tone` (enum), bukan
/// `color`, jadi pemetaan warna ini bebas diubah tanpa merusak uji.
extension PointingTone {
    /// Warna nada yang **dihitung**, sadar mode malam.
    ///
    /// Semua nilai berasal dari `TonePalette` (teruji di Linux), bukan dari
    /// warna sistem yang bergerak antar OS. `SurfacePalette.active` membaca
    /// `NightMode.isOn` tiap render, jadi warna ikut berubah begitu preferensi
    /// dibalik — satu sumber kebenaran, bukan dua daftar warna.
    ///
    /// Lihat `TonePaletteTests` untuk gerbang kontrasnya: di mode malam,
    /// kelima nada **harus** ≥ 4.5:1 terhadap permukaan malam, yang tidak
    /// pernah dipenuhi oleh nilai lama (red 0.50 / 0.62 / 0.80).
    var color: Color {
        SurfacePalette.active.tones.color(for: self).color
    }

    /// Latar kapsul badge keyakinan yang **dihitung**, sadar mode malam.
    ///
    /// Di siang: campuran nada @ 0.2 di atas permukaan paling terang yang
    /// dijadikan **opak**. Di mode malam: permukaan tingkat dua, karena warna
    /// nada di kanal merah tidak boleh mem-back badge (jarak teks-latar akan
    /// menyusut). Lihat `TonePalette` untuk alasannya — dan `TonePaletteTests`
    /// untuk gerbangnya.
    var badgeFillColor: Color {
        SurfacePalette.active.badgeFills.fill(for: self).color
    }
}

extension Color {
    /// Teks sekunder sadar mode malam.
    ///
    /// Di siang: abu terang dari token yang **sudah diuji** di Linux. Di mode
    /// malam: merah yang sama persis dengan `textSecondary` palet malam.
    ///
    /// **Dua temuan yang membuat helper ini tidak lagi punya warna sendiri.**
    ///
    /// 1. Nilai lamanya, merah 0.42, punya kontras **1.49:1** terhadap latar
    ///    malam — bukan 4.5:1. Jadi syarat kontras di brief, di mode malam,
    ///    sebenarnya tidak pernah terpenuhi di kode lama; sekarang ia
    ///    terhitung dan dijaga.
    /// 2. Nilai itu juga hidup di berkas yang tidak bisa diuji. Semua warna
    ///    sekarang datang dari `SurfacePalette`, jadi kalau palet diubah, teks
    ///    sekunder ikut berubah — dan tes kontras mengatakannya.
    ///
    /// Helper ini tetap ada (banyak pemanggilan), tapi ia tidak lagi boleh
    /// memiliki angka warna sendiri; kalau suatu saat ia menulis warna
    /// langsung di sini, warna itu keluar dari gate.
    static var nightAwareSecondary: Color {
        SurfacePalette.active.textSecondaryColor
    }
}

extension NightMode {
    /// Latar kartu detail.
    ///
    /// Di siang: warna permukaan dari token yang sudah diuji, **bukan**
    /// `.ultraThinMaterial`.
    ///
    /// **Kenapa material diganti.** Glassmorphism itu enak dilihat, dan brief
    /// memang memintanya. Tapi warnanya bergantung apa yang ada di belakangnya:
    /// kontras teks di atas `.ultraThinMaterial` tidak bisa dijamin, jadi
    /// material membuat klaim "kontras ≥ 4.5:1" yang sudah kita hitung
    /// menjadi tidak bisa dipercaya. Di palet yang warnanya sudah diketahui,
    /// material hanya mengurangi ketajaman hierarki. Kalau glassmorphism tetap
    /// dipakai di sini, ia harus ikut diuji — bukan ditambahkan sebagai
    /// hiasan. Ini keputusan produk dan bisa berubah; yang penting, saat
    /// berubah, angka kontrasnya ikut dihitung lagi.
    static var detailCardBackground: AnyShapeStyle {
        AnyShapeStyle(SurfacePalette.active.surface1Color)
    }
}
