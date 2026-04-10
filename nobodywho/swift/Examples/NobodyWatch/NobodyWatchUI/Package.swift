// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NobodyWatchUI",
    platforms: [
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "NobodyWatchUI",
            targets: ["NobodyWatchUI"]
        ),
    ],
    targets: [
        .target(
            name: "NobodyWatchUI",
            path: "Sources/NobodyWatchUI"
        ),
    ]
)
