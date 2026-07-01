// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeatmapKit",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(name: "HeatmapCore", targets: ["HeatmapCore"]),
        .library(name: "HeatmapKit", targets: ["HeatmapKit"]),
    ],
    targets: [
        .target(
            name: "HeatmapCore"
        ),
        .target(
            name: "HeatmapKit",
            dependencies: ["HeatmapCore"]
        ),
        .testTarget(
            name: "HeatmapCoreTests",
            dependencies: ["HeatmapCore"]
        ),
        .testTarget(
            name: "HeatmapKitTests",
            dependencies: ["HeatmapKit"]
        ),
    ]
)
