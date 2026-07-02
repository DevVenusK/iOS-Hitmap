// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HitHitKit",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(name: "HitHitCore", targets: ["HitHitCore"]),
        .library(name: "HitHitKit", targets: ["HitHitKit"]),
    ],
    targets: [
        .target(
            name: "HitHitCore"
        ),
        .target(
            name: "HitHitKit",
            dependencies: ["HitHitCore"]
        ),
        .testTarget(
            name: "HitHitCoreTests",
            dependencies: ["HitHitCore"]
        ),
        .testTarget(
            name: "HitHitKitTests",
            dependencies: ["HitHitKit"]
        ),
    ]
)
