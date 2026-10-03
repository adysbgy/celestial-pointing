import SwiftUI
import CelestialEngine
import PointingKit

/// Palet warna per nada.
///
/// Sengaja hanya empat warna, dan `warning` (ragu) **tidak** memakai warna
/// sukses. Lihat `PointingPresentationTests` — jarak visual antara "yakin" dan
/// "ragu" adalah bagian dari janji produk, bukan hiasan.
extension PointingTone {
    var color: Color {
        switch self {
        case .neutral: return .secondary
        case .active: return .cyan
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }
}

/// Ukuran bersama supaya semua layar jam terasa satu aplikasi.
enum WatchMetrics {
    static let cornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 8
    static let statusSize: CGFloat = 22
    static let titleSize: CGFloat = 20
}
