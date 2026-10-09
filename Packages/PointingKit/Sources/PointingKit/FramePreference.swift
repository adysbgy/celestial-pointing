import Foundation
import CelestialEngine

/// Kerangka acuan yang dipakai jam untuk menunjuk (ADR-011).
///
/// **Kenapa bukan lagi `xArbitraryZVertical`.** Kerangka itu membuat arah
/// hadap (azimut) **sembarang dan berbeda tiap kali sensor dinyalakan**. Tanpa
/// kalibrasi di sesi yang sama, azimut yang dihitung bisa meleset berapa pun
/// sampai 180° — jam menunjuk Jupiter tapi engine mencari di sisi langit yang
/// lain, lalu berkata "Belum yakin" atau, lebih buruk, menyebut benda yang
/// salah. Itu salah satu akar masalah di Docs/WATCH_NOT_SURE_ANALYSIS.md.
///
/// Kompas jam (magnetometer) memang bisa terganggu logam; karena itu
/// kalibrasi tetap dipasang **di atas** kerangka berutara sebagai koreksi
/// azimut. Tetapi titik awal yang kira-kira benar jauh lebih baik daripada
/// titik awal yang acak.
public extension AttitudeReferenceFrame {

    /// Urutan pilihan: utara sebenarnya → utara magnetis → sembarang.
    static let preferenceOrder: [AttitudeReferenceFrame] = [
        .xTrueNorthZVertical, .xMagneticNorthZVertical,
        .xArbitraryCorrectedZVertical, .xArbitraryZVertical,
    ]

    /// Kerangka terbaik yang tersedia di perangkat ini.
    static func preferred(from available: [AttitudeReferenceFrame]) -> AttitudeReferenceFrame {
        preferenceOrder.first(where: available.contains) ?? .xArbitraryZVertical
    }

    /// Kerangka berikutnya bila kerangka ini ditolak saat berjalan (mis. utara
    /// sebenarnya butuh izin lokasi). `nil` untuk kerangka terakhir.
    func fallback(within available: [AttitudeReferenceFrame]) -> AttitudeReferenceFrame? {
        guard let index = Self.preferenceOrder.firstIndex(of: self) else { return nil }
        return Self.preferenceOrder.dropFirst(index + 1).first(where: available.contains)
    }
}
