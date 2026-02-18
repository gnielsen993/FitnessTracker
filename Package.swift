// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FitnessTracker",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "FitnessTracker", targets: ["FitnessTracker"])
    ],
    dependencies: [
        .package(path: "../DesignKit")
    ],
    targets: [
        .executableTarget(
            name: "FitnessTracker",
            dependencies: [
                .product(name: "DesignKit", package: "DesignKit")
            ],
            path: "FitnessTracker",
            exclude: [
                "Docs",
                "Assets.xcassets"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FitnessTrackerTests",
            dependencies: ["FitnessTracker"],
            path: "FitnessTrackerTests"
        )
    ]
)
