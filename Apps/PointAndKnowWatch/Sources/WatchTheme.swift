import SwiftUI
import CelestialEngine
import PointingKit

/// Ukuran bersama supaya semua layar jam terasa satu aplikasi.
///
/// Palet warna per nada (`PointingTone.color`) sudah dipindah ke
/// `Apps/Shared/NightMode.swift` supaya jam **dan** iPhone memakai satu sumber
/// yang sama — dan supaya mode malam bisa menimpanya di satu tempat.
enum WatchMetrics {
    static let cornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 8
    static let statusSize: CGFloat = 22
    static let titleSize: CGFloat = 20
}
