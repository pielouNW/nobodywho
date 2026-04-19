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
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "ValkyrieUI",
            dependencies: [
                .product(name: "Textual", package: "textual"),
            ],
            path: "Sources/ValkyrieUI"
        ),
    ]
)
