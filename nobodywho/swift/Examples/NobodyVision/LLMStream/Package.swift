// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMStream",
    platforms: [
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "LLMStream",
            targets: ["LLMStream"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "LLMStream",
            dependencies: [
                .product(name: "Textual", package: "textual"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
