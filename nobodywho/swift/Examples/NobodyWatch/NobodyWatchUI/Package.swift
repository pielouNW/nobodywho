// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ValkyrieUI",
    platforms: [
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "ValkyrieUI",
            targets: ["ValkyrieUI"]
        ),
    ],
    targets: [
        .target(
            name: "ValkyrieUI",
            path: "Sources/ValkyrieUI"
        ),
    ]
)
