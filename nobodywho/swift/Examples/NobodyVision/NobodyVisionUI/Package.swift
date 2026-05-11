// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ValkyrieUI",
    platforms: [
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "ValkyrieUI",
            targets: ["ValkyrieUI"]
        ),
    ],
    dependencies: [
        .package(path: "../LLMStream"),
    ],
    targets: [
        .target(
            name: "ValkyrieUI",
            dependencies: [
                .product(name: "LLMStream", package: "LLMStream"),
            ],
            path: "Sources/ValkyrieUI"
        ),
    ]
)
