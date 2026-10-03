// swift-tools-version:6.0
import PackageDescription

/// Logika lapisan app yang **tidak** menyentuh API Apple apa pun.
///
/// Dipisahkan dari app supaya bisa diuji di Linux: transisi keadaan, pemicu
/// haptic, pencatatan percobaan Experiment 1, kalibrasi, dan perencanaan GoTo
/// semuanya logika murni. Yang tersisa untuk diuji di Mac hanyalah pembungkus
/// sensor (CoreMotion), UI SwiftUI, haptic Taptic Engine, dan WatchConnectivity.
let package = Package(
    name: "PointingKit",
    platforms: [.macOS(.v15), .iOS(.v18), .watchOS(.v11)],
    products: [
        .library(name: "PointingKit", targets: ["PointingKit"])
    ],
    dependencies: [
        .package(path: "../CelestialEngine")
    ],
    targets: [
        .target(
            name: "PointingKit",
            dependencies: ["CelestialEngine"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PointingKitTests",
            dependencies: ["PointingKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
