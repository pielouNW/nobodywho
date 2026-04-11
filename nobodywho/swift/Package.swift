// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NobodyWho",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .visionOS(.v1),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "NobodyWho",
            targets: ["NobodyWho"]
        ),
        .executable(
            name: "NobodyWhoTestCLI",
            targets: ["NobodyWhoTestCLI"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NobodyWho",
            dependencies: ["nobodywhoFFI"],
            path: "Sources/NobodyWho",
            linkerSettings: [
                .linkedFramework("Accelerate"),
            ]
        ),
        .binaryTarget(
            name: "nobodywhoFFI",
            path: "NobodyWhoFFI.xcframework"
        ),
        .executableTarget(
            name: "NobodyWhoTestCLI",
            dependencies: ["NobodyWho"],
            path: "Sources/NobodyWhoTestCLI"
        ),
        .testTarget(
            name: "NobodyWhoTests",
            dependencies: ["NobodyWho"]
        ),
    ]
)
