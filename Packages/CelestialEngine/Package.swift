// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CelestialEngine",
    platforms: [.macOS(.v15), .iOS(.v18), .watchOS(.v11)],
    products: [
        .library(name: "CelestialEngine", targets: ["CelestialEngine"])
    ],
    dependencies: [
        // Efemeris Bulan & planet. Astronomy Engine (C) + pembungkus Swift.
        // Teruji jalan di Linux (swift test) maupun Apple SDK. Lisensi MIT.
        .package(url: "https://github.com/heirloomlogic/AstronomyKit", from: "0.2.3")
    ],
    targets: [
        .target(
            name: "CelestialEngine",
            dependencies: ["AstronomyKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CelestialEngineTests",
            dependencies: ["CelestialEngine"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
