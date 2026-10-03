// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CelestialEngine",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "CelestialEngine", targets: ["CelestialEngine"])
    ],
    targets: [
        .target(name: "CelestialEngine"),
        .testTarget(name: "CelestialEngineTests", dependencies: ["CelestialEngine"])
    ]
)
