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
    var color: Color {
        if NightMode.isOn {
            switch self {
            case .neutral:  return Color(red: 0.50, green: 0.00, blue: 0.00)
            case .active:   return Color(red: 0.80, green: 0.00, blue: 0.00)
            case .success:  return Color(red: 1.00, green: 0.00, blue: 0.00)
            case .warning:  return Color(red: 0.62, green: 0.00, blue: 0.00)
            case .danger:   return Color(red: 1.00, green: 0.00, blue: 0.00)
            }
        }
        switch self {
        case .neutral:  return .secondary
        case .active:   return .cyan
        case .success:  return .green
        case .warning:  return .orange
        case .danger:   return .red
        }
    }
}

extension Color {
    /// Teks sekunder sadar mode malam.
    ///
    /// Di siang: `.secondary` (kelabu yang menyesuaikan penampilan sistem).
    /// Di mode malam: merah redup, bukan kelabu/putih yang merusak rhodopsin.
    /// Ganti **setiap** `.secondary` di lapisan app dengan ini supaya teks
    /// sekunder ikut menjadi merah saat malam.
    static var nightAwareSecondary: Color {
        NightMode.isOn
            ? Color(red: 0.42, green: 0.00, blue: 0.00)
            : .secondary
    }
}

extension NightMode {
    /// Latar kartu detail.
    ///
    /// Di siang: material sistem (`.ultraThinMaterial`) seperti sebelumnya.
    /// Di mode malam: merah sangat redup — **bukan** material putih/translusan
    /// yang menyala dan menghancurkan penglihatan malam.
    static var detailCardBackground: AnyShapeStyle {
        isOn
            ? AnyShapeStyle(Color(red: 0.16, green: 0.00, blue: 0.00))
            : AnyShapeStyle(.ultraThinMaterial)
    }
}
